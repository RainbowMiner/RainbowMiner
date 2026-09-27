param($ControllerProcessID, $WorkingDirectory, $FilePath, $OCDaemonPrefix, $EnableMinersAsRoot, $PIDPath, $PIDBash, $ScreenName, $CurrentPwd, $IsAdmin)

Import-Module "$(Join-Path "$(Join-Path $CurrentPwd "Modules")" "OCDaemon.psm1")"

$ControllerProcess = Get-Process -Id $ControllerProcessID
if ($ControllerProcess -eq $null) {return}

$StopWatch = [System.Diagnostics.Stopwatch]::New()

$Process  = $null
$BashProc = $null
$started  = $false
$OCDcount = 0
$ScreenProcessId = 0
$StartStopDaemon = Get-Command "start-stop-daemon" -ErrorAction Ignore

if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
    $started = Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -FilePath $PIDBash -Move -Quiet
    $OCDcount++
} else {
    $ProcessParams = @{
        FilePath         = $PIDBash
        ArgumentList     = ""
        WorkingDirectory = $WorkingDirectory
        PassThru         = $true
    }
    if ($null -ne ($BashProc = Start-Process @ProcessParams)) {
        $started = $BashProc.WaitForExit(60000)
    }
}

$StartLog = [System.Collections.Generic.List[string]]@()

if ($started) {
    $StopWatch.Restart()

    do {
        Start-Sleep -Milliseconds 500
        $ScreenCmd = "screen -ls | grep $ScreenName | cut -f1 -d'.' | sed 's/\W//g'"
        if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
            [int]$ScreenProcessId = Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd $ScreenCmd
            $OCDcount++            
        } else {
            [int]$ScreenProcessId = Invoke-Expression $ScreenCmd
        }
    } until ($ScreenProcessId -or ($StopWatch.Elapsed.TotalSeconds) -ge 5)

    if (-not $ScreenProcessId) {
        [void]$StartLog.Add("Failed to get screen.")
        [void]$StartLog.Add("Result of `"screen -ls`"")
        if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
            Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd "screen -ls" | Foreach-Object {[void]$StartLog.Add($_)}
            $OCDcount++
        } else {
            Invoke-Expression "screen -ls" | Foreach-Object {[void]$StartLog.Add($_)}
        }
    } else {

        [void]$StartLog.Add("Success: got id $ScreenProcessId for screen $ScreenName")

        $MinerExecutable = Split-Path $FilePath -Leaf

        $StopWatch.Restart()
        do {
            Start-Sleep -Milliseconds 500
            if ($StartStopDaemon) {
                if (Test-Path $PIDPath) {
                    $ProcessId = [int](Get-Content $PIDPath -Raw -ErrorAction Ignore | Select-Object -First 1)
                    if ($ProcessId) {$Process = Get-Process -Id $ProcessId -ErrorAction Ignore}
                }
            } else {
                $Process = Get-Process | Where-Object {$_.Name -eq $MinerExecutable -and $($_.Parent).Parent.Id -eq $ScreenProcessId}
                if ($Process) {$Process.Id | Set-Content $PIDPath -ErrorAction Ignore}
            }
        } until ($Process -or ($StopWatch.Elapsed.TotalSeconds) -ge 10)

        if ($Process) {
            [void]$StartLog.Add("Success: got id $($Process.Id) for $MinerExecutable in screen $ScreenName")
        } else {
            [void]$StartLog.Add("Failed to get process for $ScreenName with id $ScreenProcessId")
            [void]$StartLog.Add("List of processes:")
            Get-Process | Where-Object {$_.Path -and $_.Path -like "$($CurrentPwd)/Bin/*"} | Foreach-Object {[void]$StartLog.Add("$($_.Name)`t$($_.Id)`t$($_.Parent.Id)")}
        }

    }
    $StopWatch.Stop()
}

if (-not $Process) {
    [PSCustomObject]@{ProcessId = $null;StartLog = $StartLog}
    return
}

# hand the watch over to the bash guard: it stops the miner when RainbowMiner dies without a
# clean shutdown, and it costs a few hundred KB instead of a pwsh job host per running miner
$GuardScript = Join-Path (Join-Path $CurrentPwd "IncludesLinux") "bash/minerguard.sh"
if (Test-Path $GuardScript) {
    $GuardArgs = @($ControllerProcessID, $Process.Id, $Process.Name, "screen", $ScreenName, $PIDPath)
    $Quote = {param($s) "'" + ("$s" -replace "'","'\''") + "'"}
    $GuardCmd = "setsid bash $(& $Quote $GuardScript) $(@($GuardArgs | Foreach-Object {& $Quote $_}) -join ' ') </dev/null >/dev/null 2>&1 &"
    try {
        & chmod +x $GuardScript 2>$null
        if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
            # a root miner lives in the ocdaemon's cgroup: start the guard there as well, so that a
            # service manager stopping RainbowMiner's own cgroup cannot take the guard with it
            Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd $GuardCmd -Quiet > $null
            $OCDcount++
        } else {
            & bash -c $GuardCmd
        }
        [void]$StartLog.Add("Guard started for $($Process.Name) with id $($Process.Id)")
    } catch {
        [void]$StartLog.Add("Failed to start the miner guard: $($_.Exception.Message)")
    }
}

# the flush must never keep the result from the caller: Write-ToFile lives in Include.psm1, which this job does not import
if ($Global:Error.Count -and (Get-Command Write-ToFile -ErrorAction Ignore)) {
    $errPath = Join-Path $CurrentPwd "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").jobs.txt"
    foreach ($err in $Global:Error) {
        if ($err.Exception.Message) {
            Write-ToFile -FilePath $errPath -Message "Error during $($FilePath): $($err.Exception.Message)" -Append -Timestamp
        }
    }
    $Global:Error.Clear()
}

[PSCustomObject]@{ProcessId = $Process.Id;StartLog = $StartLog}
