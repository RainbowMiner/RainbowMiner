param($ControllerProcessID, $ProcessId, $LogPath)

$ControllerProcess = Get-Process -Id $ControllerProcessID
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

$LogPath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath)

# Wait 30 seconds for logfile to appear
$StopWatch = [System.Diagnostics.Stopwatch]::New()
$StopWatch.Restart()
do {
    Start-Sleep -Milliseconds 500
} while (-not (Test-Path $LogPath) -and $StopWatch.Elapsed.TotalSeconds -lt 30)
$StopWatch.Stop()

if (Test-Path $LogPath) {
    $TailJob = Start-Job([ScriptBlock]::Create("Get-Content '$LogPath' -Tail 30 -Wait *>&1 | Write-Output"))

    if ($TailJob) {
        do {
            $Process = Get-Process -Id $ProcessId
            if ($TailJob.HasMoreData) {$TailJob | Receive-Job | ForEach-Object {$Line = $_ -replace "`n|`r", "";$Line -replace "\x1B\[[0-?]*[ -/]*[@-~]"}}
        }
        while (-not $ControllerProcess.WaitForExit(10000) -and $Process -and -not $Process.HasExited -and $TailJob.State -eq "Running")
        if ($TailJob.State -eq "Running") {$TailJob | Stop-Job}
        $TailJob | Remove-Job -Force
    }
}
