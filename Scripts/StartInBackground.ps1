param($ControllerProcessID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $CurrentPwd)

$EnvParams = @($EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {"`$env:$($matches[1])=`"$($matches[2].Replace('"','``"'))`";"}) -join " "

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

$PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]

$MiningProcess = [PowerShell]::Create()
$MiningProcess.AddScript("Set-Location `"$($WorkingDirectory)`"; $EnvParams (Get-Process -Id `$PID).PriorityClass = `"$($PriorityClass)`"; & `"$($FilePath)`" $($ArgumentList.Replace('"','``"')) *>&1 | Write-Verbose -Verbose")
$Result = $MiningProcess.BeginInvoke()
do {
    Start-Sleep -S 1
    $MiningProcess.Streams.Verbose.ReadAll() | Foreach-Object {
        if ($LogPath) {Out-File -InputObject $_ -FilePath $LogPath -Append -Encoding UTF8}
        $_
    }
    $MiningProcess.Streams.ClearStreams()
    if (-not (Get-Process -Id $ControllerProcessID -ErrorAction Ignore)) {$MiningProcess.Stop() > $null}
} until ($MiningProcess.IsCompleted)