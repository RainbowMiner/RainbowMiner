param($ControllerProcessID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $CurrentPwd)

$EnvParams = @($EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {"`$env:$($matches[1])=`"$($matches[2].Replace('"','``"'))`";"}) -join " "

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

$PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]

$MiningProcess = [PowerShell]::Create().AddScript("Set-Location `"$($WorkingDirectory)`"; $EnvParams (Get-Process -Id `$PID).PriorityClass = `"$($PriorityClass)`"; & `"$($FilePath)`" $($ArgumentList.Replace('"','``"')) *>&1 | Write-Verbose -Verbose")
$MiningStatus  = $MiningProcess.BeginInvoke()

do {
    if ($ControllerProcess.WaitForExit(1000)) {
        $MiningProcess.Streams.ClearStreams() > $null
        $MiningProcess.Stop() > $null
    } else {
        if ($LogPath) {
            $MiningProcess.Streams.Verbose.ReadAll() | Tee-Object $LogPath -Append
        } else {
            $MiningProcess.Streams.Verbose.ReadAll()
        }
        $MiningProcess.Streams.ClearStreams() > $null
    }
} until ($MiningStatus.IsCompleted)

$MiningProcess.Dispose()