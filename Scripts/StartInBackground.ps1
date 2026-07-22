param($ControllerProcessID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $CurrentPwd)

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

if ($Priority -ge 10) {$Priority = 0}

$PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]

# kill-on-close job object: once the miner is assigned, the kernel terminates
# it and its children as soon as the process holding the job handle dies -
# RainbowMiner itself with ThreadJob, the Start-Job child otherwise. This
# covers X-close, crash and taskkill; the handle is intentionally never closed.
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
if ($WorkingDirectory) {$psi.WorkingDirectory = $WorkingDirectory}

# per-miner environment variables (NAME=value)
$EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {
    $psi.EnvironmentVariables[$matches[1]] = $matches[2]
}

$MiningProcess = New-Object System.Diagnostics.Process
$MiningProcess.StartInfo = $psi

# stdout/stderr are queued on the .NET event thread and drained to the log by
# the watch loop, so a filled redirect pipe can never stall the miner
$OutputQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
$OutEvent = Register-ObjectEvent -InputObject $MiningProcess -EventName OutputDataReceived -MessageData $OutputQueue -Action {
    if ($EventArgs.Data -ne $null) {$Event.MessageData.Enqueue($EventArgs.Data)}
}
$ErrEvent = Register-ObjectEvent -InputObject $MiningProcess -EventName ErrorDataReceived -MessageData $OutputQueue -Action {
    if ($EventArgs.Data -ne $null) {$Event.MessageData.Enqueue($EventArgs.Data)}
}

try {
    [void]$MiningProcess.Start()
} catch {
    if ($LogPath) {Add-Content -LiteralPath $LogPath -Value "Failed to start $($FilePath): $($_.Exception.Message)" -ErrorAction Ignore}
    Unregister-Event -SourceIdentifier $OutEvent.Name -ErrorAction Ignore
    Unregister-Event -SourceIdentifier $ErrEvent.Name -ErrorAction Ignore
    $MiningProcess.Dispose()
    return
}

$JobHandle = [IntPtr]::Zero
try {if ("RBMJob" -as [type]) {$JobHandle = [RBMJob]::Guard($MiningProcess.Handle)}} catch {}
if ($JobHandle -eq [IntPtr]::Zero -and $LogPath) {Add-Content -LiteralPath $LogPath -Value "Warning: kill-on-close job guard not active for $($FilePath)" -ErrorAction Ignore}

$MiningProcess.BeginOutputReadLine()
$MiningProcess.BeginErrorReadLine()

# Set-SubProcessPriority in ProcLib re-applies this to all discovered PIDs
try {$MiningProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]$PriorityClass} catch {}

# must never throw: if the watch loop died, the event subscriptions would keep
# queueing miner output unread until Stop-SubProcess removes the job.
# Lines are always emitted to the job output stream as well: the *Wrapper APIs
# parse them via Receive-Job on Windows (EndOfRoundCleanup null-drains them
# for all other miners).
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

do {
    $Done = $ControllerProcess.WaitForExit(1000)
    try {& $DrainToLog $OutputQueue $LogPath} catch {}
    if ($Done -and -not $MiningProcess.HasExited) {
        try {$MiningProcess.Kill()} catch {}
    }
} until ($Done -or $MiningProcess.HasExited)

# bounded wait for a killed miner, then WaitForExit() flushes the async
# readers to EOF so no tail lines are lost
try {
    if (-not $MiningProcess.HasExited) {[void]$MiningProcess.WaitForExit(5000)}
    if ($MiningProcess.HasExited) {$MiningProcess.WaitForExit()}
} catch {}
Start-Sleep -Milliseconds 100
try {& $DrainToLog $OutputQueue $LogPath} catch {}

try {$MiningProcess.CancelOutputRead()} catch {}
try {$MiningProcess.CancelErrorRead()} catch {}
Unregister-Event -SourceIdentifier $OutEvent.Name -ErrorAction Ignore
Unregister-Event -SourceIdentifier $ErrEvent.Name -ErrorAction Ignore

$MiningProcess.Dispose()
$MiningProcess = $null
