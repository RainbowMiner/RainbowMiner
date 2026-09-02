param($ControllerProcessID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $CurrentPwd, $Comm = $null)

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

if ($Priority -ge 10) {$Priority = 0}

$PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]

# kill-on-close job object: once the miner is assigned, the kernel terminates
# it and its children as soon as the process holding the job handle dies -
# RainbowMiner itself, since the monitor runs on its pooled runspace. This
# covers X-close, crash and taskkill; the regular teardown terminates the job
# explicitly (see the tail of the watch loop), which also takes down worker
# processes the miner forked.
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

    // kills every process still assigned to the job - the miner's forked
    // workers included - and releases the handle
    public static bool Terminate(IntPtr hJob) {
        if (hJob == IntPtr.Zero) return false;
        bool ok = TerminateJobObject(hJob, 1);
        CloseHandle(hJob);
        return ok;
    }
}
'@
}

# CreateNoWindow gives the miner its own hidden console: nothing for Win11 to
# hand to Windows Terminal, and no direct console writes into the main screen.
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $FilePath
$psi.Arguments              = $ArgumentList
$psi.UseShellExecute        = $false
$psi.CreateNoWindow         = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
# stdin must be a private pipe: without this the miner inherits the console
# input handle and a hotkey-polling miner (e.g. SRBMiner) silently consumes
# the keystrokes meant for RainbowMiner - and the .NET KeyAvailable peek/read
# race can then block the core loop forever inside ReadConsoleInput
$psi.RedirectStandardInput  = $true
if ($WorkingDirectory) {$psi.WorkingDirectory = $WorkingDirectory}

# per-miner environment variables (NAME=value)
$EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {
    $psi.EnvironmentVariables[$matches[1]] = $matches[2]
}

$MiningProcess = New-Object System.Diagnostics.Process
$MiningProcess.StartInfo = $psi

# stdout/stderr are queued on the .NET event thread and drained to the log by
# the watch loop, so a filled redirect pipe can never stall the miner.
# A null line marks EOF on a stream (the last handle to its pipe was closed);
# it is counted so the tail wait after the exit can be bounded
$OutputQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
$Streams = [hashtable]::Synchronized(@{Queue = $OutputQueue; Eof = 0})
$OutEvent = Register-ObjectEvent -InputObject $MiningProcess -EventName OutputDataReceived -MessageData $Streams -Action {
    if ($EventArgs.Data -ne $null) {$Event.MessageData.Queue.Enqueue($EventArgs.Data)} else {$Event.MessageData.Eof++}
}
$ErrEvent = Register-ObjectEvent -InputObject $MiningProcess -EventName ErrorDataReceived -MessageData $Streams -Action {
    if ($EventArgs.Data -ne $null) {$Event.MessageData.Queue.Enqueue($EventArgs.Data)} else {$Event.MessageData.Eof++}
}

try {
    [void]$MiningProcess.Start()
} catch {
    if ($Comm -ne $null) {$Comm["StartFailed"] = "$($_.Exception.Message)"}
    if ($LogPath) {Add-Content -LiteralPath $LogPath -Value "Failed to start $($FilePath): $($_.Exception.Message)" -ErrorAction Ignore}
    Unregister-Event -SourceIdentifier $OutEvent.Name -ErrorAction Ignore
    Unregister-Event -SourceIdentifier $ErrEvent.Name -ErrorAction Ignore
    Remove-Job $OutEvent -Force -ErrorAction Ignore
    Remove-Job $ErrEvent -Force -ErrorAction Ignore
    $MiningProcess.Dispose()
    return
}

# hand the PID back to Start-SubProcessInBackground: single-process miners
# then need no CIM-based discovery at all
if ($Comm -ne $null) {$Comm["ProcessId"] = $MiningProcess.Id}
$MinerStartTime = Get-Date
try {$MinerStartTime = $MiningProcess.StartTime} catch {}

$JobHandle = [IntPtr]::Zero
try {if ("RBMJob" -as [type]) {$JobHandle = [RBMJob]::Guard($MiningProcess.Handle)}} catch {}
if ($JobHandle -eq [IntPtr]::Zero -and $LogPath) {Add-Content -LiteralPath $LogPath -Value "Warning: kill-on-close job guard not active for $($FilePath)" -ErrorAction Ignore}

# the cleanup lives in a finally: if the pipeline is stopped from the outside
# (PowerShell.Stop() on a pooled runspace), the event subscriptions and a
# still-running miner must not leak into a runspace that gets reused
try {
    $MiningProcess.BeginOutputReadLine()
    $MiningProcess.BeginErrorReadLine()

    # Set-SubProcessPriority in ProcLib re-applies this to all discovered PIDs
    try {$MiningProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]$PriorityClass} catch {}

    # must never throw: if the watch loop died, the event subscriptions would keep
    # queueing miner output unread until Stop-SubProcess removes the job.
    # Lines are always emitted to the pipeline output stream as well: the *Wrapper
    # APIs parse them via Read-MinerJobOutput on Windows (EndOfRoundCleanup
    # null-drains them for all other miners).
    $DrainToLog = {
        param($Queue, $Path)
        $line  = $null
        $lines = New-Object System.Collections.Generic.List[string]
        while ($Queue.TryDequeue([ref]$line)) {[void]$lines.Add($line)}
        if ($lines.Count) {
            if ($Path) {Add-Content -LiteralPath $Path -Value $lines -ErrorAction Ignore}
            $lines
        }
    }

    # fallback for a miner outside the job guard: kill the process tree below
    # the main PID. Only processes younger than the miner qualify, so a
    # recycled PID can never match
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
        try {& $DrainToLog $OutputQueue $LogPath} catch {}
        if ($Done -and -not $MiningProcess.HasExited) {
            try {$MiningProcess.Kill()} catch {}
        }
    } until ($Done -or $MiningProcess.HasExited)

    # bounded wait for a killed miner
    try {if (-not $MiningProcess.HasExited) {[void]$MiningProcess.WaitForExit(5000)}} catch {}

    # Never WaitForExit() without a timeout here: it returns only once the
    # async readers hit EOF, and a miner that forks worker processes (BzMiner
    # v100+) leaves them holding the inherited stdout/stderr pipe after the
    # main PID is killed - the call would never return, and PowerShell.Stop()
    # on the core loop would freeze with it. Terminate the job object first
    # (the workers die and the pipe closes), then wait for EOF with a limit
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
    try {& $DrainToLog $OutputQueue $LogPath} catch {}
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
    try {$MiningProcess.CancelOutputRead()} catch {}
    try {$MiningProcess.CancelErrorRead()} catch {}
    Unregister-Event -SourceIdentifier $OutEvent.Name -ErrorAction Ignore
    Unregister-Event -SourceIdentifier $ErrEvent.Name -ErrorAction Ignore
    # the -Action subscriptions are PSEventJobs: without Remove-Job they pile
    # up in the reused pooled runspace's job table (2 per miner start)
    Remove-Job $OutEvent -Force -ErrorAction Ignore
    Remove-Job $ErrEvent -Force -ErrorAction Ignore

    $MiningProcess.Dispose()
    $MiningProcess = $null
}
