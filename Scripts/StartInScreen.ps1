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

$StartLog = @()

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
        $StartLog += "Failed to get screen."
        $StartLog += "Result of `"$($ScreenCmd)`""
        if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
            Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd $ScreenCmd | Foreach-Object {$StartLog += $_}
            $OCDcount++
        } else {
            Invoke-Expression $ScreenCmd | Foreach-Object {$StartLog += $_}
        }
        $StartLog += "Result of `"screen -ls`""
        if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
            Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd "screen -ls" | Foreach-Object {$StartLog += $_}
            $OCDcount++
        } else {
            Invoke-Expression "screen -ls" | Foreach-Object {$StartLog += $_}
        }
    } else {

        $StartLog += "Success: got id $ScreenProcessId for screen $ScreenName"

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
            $StartLog += "Success: got id $($Process.Id) for $MinerExecutable in screen $ScreenName"
        } else {
            $StartLog += "Failed to get process for $ScreenName with id $ScreenProcessId"
            $StartLog += "List of processes:"
            Get-Process | Foreach-Object {$StartLog += "$($_.Name)`t$($_.Id)`t$($_.Parent.Id)"}
        }

    }
    $StopWatch.Stop()
}

if (-not $Process) {
    [PSCustomObject]@{ProcessId = $null;StartLog = $StartLog}
    return
}

[PSCustomObject]@{ProcessId = $Process.Id;StartLog = $StartLog}

$ControllerProcess.Handle >$null
$Process.Handle >$null
$ProcessName = $Process.Name

do {
    if ($ControllerProcess.WaitForExit(1000)) {
        $ToKill = @()
        $ToKill += $Process
        $ToKill += Get-Process | Where-Object {$_.Parent.Id -eq $Process.Id -and $_.Name -eq $Process.Name}

        $ArgumentList = "-S $($ScreenName) -X stuff `^C"
        if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
            Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd "screen $ArgumentList" -Quiet > $null
            $OCDcount++
        } else {
            $Screen_Process = Start-Process "screen" -ArgumentList $ArgumentList -PassThru
            $Screen_Process.WaitForExit(5000) > $null
        }

        $StopWatch.Restart()
        while (($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) -and $StopWatch.Elapsed.Seconds -le 10) {
            Start-Sleep -Milliseconds 500
        }

        if (-not $Process.HasExited -and $StartStopDaemon) {
            $ArgumentList = "--stop --name $ProcessName --pidfile $PIDPath --retry 5"
            if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
                Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd "start-stop-daemon $ArgumentList" -Quiet > $null
                $OCDcount++
            } else {
                $StartStopDaemon_Process = Start-Process "start-stop-daemon" -ArgumentList $ArgumentList -PassThru
                $StartStopDaemon_Process.WaitForExit(10000) > $null
            }
        }
                
        $ToKill | Where-Object {-not $_.HasExited} | Foreach-Object {
            if (Test-OCDaemon) {
                Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd "kill -9 $($_.Id)" -Quiet > $null
                $OCDcount++
            } else {
                Stop-Process -InputObject $_ -Force -ErrorAction Ignore
            }
        }

        if ($ScreenProcessId) {
            $ArgumentList = "-S $($ScreenName) -X quit"
            if ($EnableMinersAsRoot -and (Test-OCDaemon)) {
                Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.$OCDcount.$ScreenName" -Cmd "screen $ArgumentList" -Quiet > $null
                $OCDcount++
            } else {
                $Screen_Process = Start-Process "screen" -ArgumentList $ArgumentList -PassThru
                $Screen_Process.WaitForExit(5000) > $null
            }
        }
    }
    $StopWatch = $null
    if ($Error.Count) {$Error | Foreach-Object {Write-ToFile -FilePath (Join-Path $CurrentPwd "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").jobs.txt") -Message "$($_.Exception.Message)" -Append -Timestamp}}
    $Error.Clear()
}
while ($Process.HasExited -eq $false)
