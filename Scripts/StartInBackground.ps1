param($ControllerProcessID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $CurrentPwd, $Comm = $null, $CPUAffinity = 0, $PipeToLog = $true, $IsWrapper = $false)

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

if ($Priority -ge 10) {$Priority = 0}

$PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]

# kill-on-close job object: the kernel kills the miner and its children when
# RainbowMiner dies (X-close, crash, taskkill); the regular teardown terminates
# the job explicitly, which also takes down forked worker processes
if (-not ("RBMJob" -as [type])) {
    Add-Type -ErrorAction Ignore -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class RBMJob {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetInformationJobObject(IntPtr hJob, int infoClass, IntPtr lpInfo, uint cbInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool TerminateJobObject(IntPtr hJob, uint uExitCode);

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct IO_COUNTERS {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    public static IntPtr Guard(IntPtr hProcess) {
        IntPtr hJob = CreateJobObject(IntPtr.Zero, null);
        if (hJob == IntPtr.Zero) return IntPtr.Zero;
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        info.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr p = Marshal.AllocHGlobal(size);
        Marshal.StructureToPtr(info, p, false);
        bool ok = SetInformationJobObject(hJob, 9, p, (uint)size); // JobObjectExtendedLimitInformation
        Marshal.FreeHGlobal(p);
        if (ok) ok = AssignProcessToJobObject(hJob, hProcess);
        if (!ok) { CloseHandle(hJob); return IntPtr.Zero; }
        return hJob;
    }

    static bool Apply(IntPtr hJob, uint priorityClass, ulong affinity) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        info.BasicLimitInformation.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if (priorityClass != 0) {
            info.BasicLimitInformation.LimitFlags |= 0x20; // JOB_OBJECT_LIMIT_PRIORITY_CLASS
            info.BasicLimitInformation.PriorityClass = priorityClass;
        }
        if (affinity != 0) {
            info.BasicLimitInformation.LimitFlags |= 0x10; // JOB_OBJECT_LIMIT_AFFINITY
            info.BasicLimitInformation.Affinity = (UIntPtr)affinity;
        }
        int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr p = Marshal.AllocHGlobal(size);
        Marshal.StructureToPtr(info, p, false);
        bool ok = SetInformationJobObject(hJob, 9, p, (uint)size);
        Marshal.FreeHGlobal(p);
        return ok;
    }

    // priority class and affinity mask (0 = leave alone) as job limits, so they
    // reach every process in the job. Returns 0 = applied, 1 = affinity
    // rejected (priority applied), 2 = nothing applied
    public static int Limit(IntPtr hJob, uint priorityClass, ulong affinity) {
        if (hJob == IntPtr.Zero) return 2;
        if (Apply(hJob, priorityClass, affinity)) return 0;
        if (affinity != 0 && Apply(hJob, priorityClass, 0)) return 1;
        return 2;
    }

    // kills every process in the job, forked workers included, and releases the handle
    public static bool Terminate(IntPtr hJob) {
        if (hJob == IntPtr.Zero) return false;
        bool ok = TerminateJobObject(hJob, 1);
        CloseHandle(hJob);
        return ok;
    }
}
'@
}

# own hidden console: nothing for Win11 to hand to Windows Terminal
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $FilePath
$psi.Arguments              = $ArgumentList
$psi.UseShellExecute        = $false
$psi.CreateNoWindow         = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
# private stdin pipe: a hotkey-polling miner would otherwise eat RainbowMiner's
# keystrokes and can block the core loop inside ReadConsoleInput
$psi.RedirectStandardInput  = $true
if ($WorkingDirectory) {$psi.WorkingDirectory = $WorkingDirectory}

# per-miner environment variables (NAME=value)
$EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {
    $psi.EnvironmentVariables[$matches[1]] = $matches[2]
}

$MiningProcess = New-Object System.Diagnostics.Process
$MiningProcess.StartInfo = $psi

# stdout/stderr are read by two dedicated threads and drained to the log by the
# watch loop. No BeginOutputReadLine: on Windows each pending read blocks a
# thread-pool worker for the miner's lifetime and starves HttpClient. No
# Register-ObjectEvent -Action either: colliding engine pulses on this pooled
# runspace crash the process (0xE0434352); it stays only as compile fallback.
if (-not ("RBMOutputPump" -as [type])) {
    Add-Type -ErrorAction Ignore -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Threading;

public class RBMOutputPump {
    public readonly ConcurrentQueue<string> Queue = new ConcurrentQueue<string>();
    // a miner looping on an error prints the same line millions of times a
    // minute: consecutive repeats are counted, not queued, and the queue is
    // capped, so the output can never inflate the process faster than the
    // monitor drains it
    public int MaxQueue = 50000;
    public int RepeatFlushMs = 10000;
    private int eof;
    private volatile bool stopped;
    private StreamReader stdout;
    private StreamReader stderr;
    private readonly Process process;
    private readonly DataReceivedEventHandler handler;

    public RBMOutputPump(Process p) {
        process = p;
        handler = OnData;
        p.OutputDataReceived += handler;
        p.ErrorDataReceived += handler;
    }

    // a null line marks EOF on one of the two streams
    public int Eof { get { return Interlocked.CompareExchange(ref eof, 0, 0); } }

    private void OnData(object sender, DataReceivedEventArgs e) {
        if (e.Data != null) Queue.Enqueue(e.Data); else Interlocked.Increment(ref eof);
    }

    // call after Process.Start instead of BeginOutputReadLine/BeginErrorReadLine
    public void Start() {
        Detach();
        stdout = process.StandardOutput;
        stderr = process.StandardError;
        StartReader(stdout, "stdout");
        StartReader(stderr, "stderr");
    }

    // after the final drain: drop further lines and dispose the streams, so a
    // reader blocked on a pipe held by a foreign process ends on its next write
    public void Stop() {
        stopped = true;
        try { if (stdout != null) stdout.Dispose(); } catch { }
        try { if (stderr != null) stderr.Dispose(); } catch { }
    }

    private void StartReader(StreamReader reader, string stream) {
        Thread thread = new Thread(() => Read(reader), 256 * 1024);
        thread.IsBackground = true;
        thread.Name = "RBMOutputPump " + stream;
        thread.Start();
    }

    // ends at EOF; disposed here because Process.Dispose leaves an accessed
    // stream open until the finalizer runs
    private void Read(StreamReader reader) {
        string last = null;
        long repeats = 0, dropped = 0;
        int since = Environment.TickCount;
        try {
            string line;
            while ((line = reader.ReadLine()) != null) {
                if (stopped) continue;
                if (line == last) {
                    repeats++;
                    // a marker now and then keeps a looping miner visible in the log
                    if (Environment.TickCount - since >= RepeatFlushMs) FlushRepeats(ref repeats, ref since, ref dropped);
                    continue;
                }
                if (repeats > 0) FlushRepeats(ref repeats, ref since, ref dropped);
                last = line;
                since = Environment.TickCount;
                Enqueue(line, ref dropped);
            }
        } catch {
        } finally {
            try { reader.Dispose(); } catch { }
        }
        if (repeats > 0) FlushRepeats(ref repeats, ref since, ref dropped);
        if (dropped > 0) Queue.Enqueue("[RBM] " + dropped + " lines dropped, the miner printed faster than the output is read");
        Interlocked.Increment(ref eof);
    }

    private void FlushRepeats(ref long repeats, ref int since, ref long dropped) {
        Enqueue("[RBM] previous line repeated " + repeats + " times", ref dropped);
        repeats = 0;
        since = Environment.TickCount;
    }

    private void Enqueue(string line, ref long dropped) {
        if (dropped > 0) {
            // resume only once the monitor has caught up: one marker per burst, not per slot
            if (Queue.Count > MaxQueue / 2) { dropped++; return; }
            Queue.Enqueue("[RBM] " + dropped + " lines dropped, the miner printed faster than the output is read");
            dropped = 0;
        } else if (Queue.Count >= MaxQueue) { dropped++; return; }
        Queue.Enqueue(line);
    }

    public void Detach() {
        process.OutputDataReceived -= handler;
        process.ErrorDataReceived -= handler;
    }
}
'@
}

$OutputPump = $OutEvent = $ErrEvent = $null
if ("RBMOutputPump" -as [type]) {
    $OutputPump  = [RBMOutputPump]::new($MiningProcess)
    $OutputQueue = $OutputPump.Queue
    $Streams     = $OutputPump
} else {
    $OutputQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
    $Streams = [hashtable]::Synchronized(@{Queue = $OutputQueue; Eof = 0})
    $OutEvent = Register-ObjectEvent -InputObject $MiningProcess -EventName OutputDataReceived -MessageData $Streams -Action {
        if ($EventArgs.Data -ne $null) {$Event.MessageData.Queue.Enqueue($EventArgs.Data)} else {$Event.MessageData.Eof++}
    }
    $ErrEvent = Register-ObjectEvent -InputObject $MiningProcess -EventName ErrorDataReceived -MessageData $Streams -Action {
        if ($EventArgs.Data -ne $null) {$Event.MessageData.Queue.Enqueue($EventArgs.Data)} else {$Event.MessageData.Eof++}
    }
}

try {
    [void]$MiningProcess.Start()
} catch {
    if ($Comm -ne $null) {$Comm["StartFailed"] = "$($_.Exception.Message)"}
    if ($LogPath) {Add-Content -LiteralPath $LogPath -Value "Failed to start $($FilePath): $($_.Exception.Message)" -ErrorAction Ignore}
    if ($OutputPump) {$OutputPump.Detach()}
    foreach ($Event_Job in @($OutEvent, $ErrEvent)) {
        if ($Event_Job) {
            Unregister-Event -SourceIdentifier $Event_Job.Name -ErrorAction Ignore
            Remove-Job $Event_Job -Force -ErrorAction Ignore
        }
    }
    $MiningProcess.Dispose()
    return
}

# hand the PID back: single-process miners then need no CIM discovery
if ($Comm -ne $null) {$Comm["ProcessId"] = $MiningProcess.Id}
$MinerStartTime = Get-Date
try {$MinerStartTime = $MiningProcess.StartTime} catch {}

$JobHandle = [IntPtr]::Zero
try {if ("RBMJob" -as [type]) {$JobHandle = [RBMJob]::Guard($MiningProcess.Handle)}} catch {}
if ($JobHandle -eq [IntPtr]::Zero -and $LogPath) {Add-Content -LiteralPath $LogPath -Value "Warning: kill-on-close job guard not active for $($FilePath)" -ErrorAction Ignore}

# priority and affinity as job limits: a per-PID call never reaches forked
# workers. JobLimits = 0 lets the caller skip its per-PID pass
if ($JobHandle -ne [IntPtr]::Zero) {
    $Win32PriorityClass = @{-2 = 0x40; -1 = 0x4000; 0 = 0x20; 1 = 0x8000; 2 = 0x80; 3 = 0x100}[[int]$Priority]
    $JobLimits = 2
    try {$JobLimits = [RBMJob]::Limit($JobHandle, [uint32]$Win32PriorityClass, [uint64]([int64]$CPUAffinity -band 0xFFFFFFFF))} catch {}
    if ($Comm -ne $null) {$Comm["JobLimits"] = $JobLimits}
    if ($JobLimits -ne 0 -and $LogPath) {Add-Content -LiteralPath $LogPath -Value "Warning: job limits for $($FilePath) $(if ($JobLimits -eq 1) {"applied without the CPU affinity mask $('0x{0:X}' -f $CPUAffinity) - it is not a subset of the available processors"} else {"could not be applied (priority $($Priority), affinity $('0x{0:X}' -f $CPUAffinity)) - falling back to per-process settings"})" -ErrorAction Ignore}
}

# cleanup in finally: a PowerShell.Stop() must not leak subscriptions or a
# running miner into the reused runspace.
# a type compiled by an older script version in this process has no Start
$AsyncReads = -not ($OutputPump -and $OutputPump.GetType().GetMethod("Start"))
try {
    if ($AsyncReads) {
        $MiningProcess.BeginOutputReadLine()
        $MiningProcess.BeginErrorReadLine()
    } else {
        $OutputPump.Start()
    }

    # Set-SubProcessPriority in ProcLib re-applies this to all discovered PIDs
    try {$MiningProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]$PriorityClass} catch {}

    # must never throw. Lines go to the output stream only for the *Wrapper APIs,
    # which parse them: nobody reads the stream of any other miner before the
    # round ends, the lines would only pile up in the core process.
    # MaxLines per call keeps a flooding miner from starving the watch loop.
    # PipeToLog = false: the miner writes its log itself, the pipe is only drained
    $PipeLogPath = if ($PipeToLog) {$LogPath} else {""}

    $DrainToLog = {
        param($Queue, $Path, $Emit, $MaxLines = 10000)
        $line  = $null
        $lines = New-Object System.Collections.Generic.List[string]
        while ($lines.Count -lt $MaxLines -and $Queue.TryDequeue([ref]$line)) {[void]$lines.Add($line)}
        if ($lines.Count) {
            if ($Path) {Add-Content -LiteralPath $Path -Value $lines -ErrorAction Ignore}
            if ($Emit) {$lines}
        }
    }

    # fallback without job guard: kill the tree below the main PID, only
    # processes younger than the miner (recycled PIDs never match)
    $KillDescendants = {
        param($RootId, $NotBefore)
        $Procs = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Ignore | Select-Object ProcessId, ParentProcessId, CreationDate)
        $Parents = [System.Collections.Generic.Queue[int]]::new()
        $Parents.Enqueue([int]$RootId)
        while ($Parents.Count) {
            $ParentId = $Parents.Dequeue()
            foreach ($p in $Procs) {
                if ($p.ParentProcessId -eq $ParentId -and $p.ProcessId -ne $ParentId -and (-not $p.CreationDate -or $p.CreationDate -ge $NotBefore)) {
                    $Parents.Enqueue([int]$p.ProcessId)
                    Stop-Process -Id $p.ProcessId -Force -ErrorAction Ignore
                }
            }
        }
    }

    do {
        $Done = $ControllerProcess.WaitForExit(1000)
        try {& $DrainToLog $OutputQueue $PipeLogPath $IsWrapper} catch {}
        if ($Done -and -not $MiningProcess.HasExited) {
            try {$MiningProcess.Kill()} catch {}
        }
    } until ($Done -or $MiningProcess.HasExited)

    # bounded wait for a killed miner
    try {if (-not $MiningProcess.HasExited) {[void]$MiningProcess.WaitForExit(5000)}} catch {}

    # never WaitForExit() without timeout: forked workers keep the pipe open and
    # it would never return. Terminate the job first, then wait for EOF bounded
    if ($JobHandle -ne [IntPtr]::Zero) {
        try {[RBMJob]::Terminate($JobHandle) > $null} catch {}
        $JobHandle = [IntPtr]::Zero
    } else {
        try {& $KillDescendants $MiningProcess.Id $MinerStartTime} catch {}
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $Swept = $false
    while ($Streams.Eof -lt 2 -and $sw.Elapsed.TotalSeconds -lt 10) {
        Start-Sleep -Milliseconds 100
        if (-not $Swept -and $sw.Elapsed.TotalSeconds -gt 2) {
            # a process outside the job still holds the pipe: sweep the tree
            $Swept = $true
            try {& $KillDescendants $MiningProcess.Id $MinerStartTime} catch {}
        }
    }
    if ($Streams.Eof -lt 2 -and $LogPath) {Add-Content -LiteralPath $LogPath -Value "Warning: output streams of $($FilePath) did not reach EOF within 10s - a foreign process still holds them" -ErrorAction Ignore}
    # drain the tail until empty, time-bounded against a foreign writer
    $sw.Restart()
    do {
        try {& $DrainToLog $OutputQueue $PipeLogPath $IsWrapper} catch {}
    } while (-not $OutputQueue.IsEmpty -and $sw.Elapsed.TotalSeconds -lt 5)
} finally {
    try {if (-not $MiningProcess.HasExited) {$MiningProcess.Kill()}} catch {}
    if ($JobHandle -ne [IntPtr]::Zero) {
        try {[RBMJob]::Terminate($JobHandle) > $null} catch {}
        $JobHandle = [IntPtr]::Zero
    }
    if ($Comm -ne $null) {
        $Comm["ExitTime"] = Get-Date
        try {if ($MiningProcess.HasExited) {$Comm["ExitCode"] = $MiningProcess.ExitCode}} catch {}
    }
    if ($AsyncReads) {
        try {$MiningProcess.CancelOutputRead()} catch {}
        try {$MiningProcess.CancelErrorRead()} catch {}
    }
    if ($OutputPump) {
        $OutputPump.Detach()
        if (-not $AsyncReads) {$OutputPump.Stop()}
        $OutputPump = $null
    }
    # the fallback subscriptions are PSEventJobs and pile up without Remove-Job
    foreach ($Event_Job in @($OutEvent, $ErrEvent)) {
        if ($Event_Job) {
            Unregister-Event -SourceIdentifier $Event_Job.Name -ErrorAction Ignore
            Remove-Job $Event_Job -Force -ErrorAction Ignore
        }
    }

    $MiningProcess.Dispose()
    $MiningProcess = $null
}
