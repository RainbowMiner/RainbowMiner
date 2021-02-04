param($ControllerProcessID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority)

$EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {Set-Item -force -path "env:$($matches[1])" -value $matches[2]}

Set-Location $WorkingDirectory

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

(Get-Process -Id $PID).PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]

$MiningProcess = [PowerShell]::Create()
$MiningProcess.AddScript("& `"$($FilePath)`" $($ArgumentList.Replace('"','``"')) *>&1 | Write-Verbose -Verbose")
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