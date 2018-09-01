using module .\Include.psm1

$Version = Get-Version $Version

$ChangesTotal = 0
try {
    if ($Version -le (Get-Version "3.8.3.7")) {
        $Changes = 0
        $PoolsActual = Get-Content "$PoolsConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($PoolsActual) {
            if ($PoolsActual.BlazePool.DataWindow -and (Get-YiiMPDataWindow $PoolsActual.BlazePool.DataWindow) -eq (Get-YiiMPDataWindow "average")) {$PoolsActual.BlazePool.DataWindow = "";$Changes++}
            if ($PoolsActual.Bsod.DataWindow -and (Get-YiiMPDataWindow $PoolsActual.Bsod.DataWindow) -eq (Get-YiiMPDataWindow "actual_last24h")) {$PoolsActual.Bsod.DataWindow = "";$Changes++}
            if ($PoolsActual.Ravenminer.DataWindow -and (Get-YiiMPDataWindow $PoolsActual.Ravenminer.DataWindow) -eq (Get-YiiMPDataWindow "actual_last24h")) {$PoolsActual.Ravenminer.DataWindow = "";$Changes++}
            if ($PoolsActual.ZergPool.DataWindow -and (Get-YiiMPDataWindow $PoolsActual.ZergPool.DataWindow) -eq (Get-YiiMPDataWindow "minimum")) {$PoolsActual.ZergPool.DataWindow = "";$Changes++}
            if ($PoolsActual.ZergPoolCoins.DataWindow -and (Get-YiiMPDataWindow $PoolsActual.ZergPoolCoins.DataWindow) -eq (Get-YiiMPDataWindow "minimum")) {$PoolsActual.ZergPoolCoins.DataWindow = "";$Changes++}
            if ($Changes) {
                $PoolsActual | ConvertTo-Json | Set-Content $PoolsConfigFile -Encoding UTF8
                $ChangesTotal += $Changes
            }
        }
    }
    if ($Version -le (Get-Version "3.8.3.8")) {
        $Remove = @(Get-ChildItem "Stats\*_Balloon_Profit.txt" | Select-Object)
        $ChangesTotal += $Remove.Count
        $Remove | Remove-Item -Force
    }
    if ($Version -le (Get-Version "3.8.3.9")) {
        $Remove = @(Get-ChildItem "Stats\Bsod_*_Profit.txt" | Select-Object)
        $ChangesTotal += $Remove.Count
        $Remove | Remove-Item -Force
    }
    if ($Version -le (Get-Version "3.8.3.13")) {
        $MinersSave = [PSCustomObject]@{}
        $MinersActual = Get-Content "$MinersConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $MinersActual.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {
            $MinerSaveArray = [PSCustomObject[]]@()
            @($_.Value) | Foreach-Object {
                $MinerSave = [PSCustomObject]@{}
                $_.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {$MinerSave | Add-Member $(if ($_.Name -eq "Profile"){$ChangesTotal++;"MSIAprofile"}else{$_.Name}) $_.Value}
                $MinerSaveArray += $MinerSave
            }
            $MinersSave | Add-Member $_.Name $MinerSaveArray

            $MinersActualSave = [PSCustomObject]@{}
            $MinersSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersSave.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
            $MinersActualSave | ConvertTo-Json | Set-Content $MinersConfigFile -Encoding Utf8
        }
    }
    if ($Version -le (Get-Version "3.8.4.4")) {       
        $cpus = @(Get-CimInstance -ClassName CIM_Processor | Select-Object -Unique -ExpandProperty Name | Foreach-Object {[String]$($_ -replace '\(TM\)|\(R\)|([a-z]+?-Core)' -replace "[^A-Za-z0-9]+" -replace "Intel|AMD|CPU|Processor")})
        $MinersSave = [PSCustomObject]@{}
        $MinersActual = Get-Content "$MinersConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $MinersActual.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {            
            $MinersSave | Add-Member ($_.Name -replace "($($cpus -join '|'))","CPU") $_.Value
        }
        $MinersActualSave = [PSCustomObject]@{}
        $MinersSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersSave.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
        $MinersActualSave | ConvertTo-Json | Set-Content $MinersConfigFile -Encoding Utf8
    }
    "Cleaned $ChangesTotal elements"
}
catch {
    "Cleanup failed $($_.Exception.Message)"
}

