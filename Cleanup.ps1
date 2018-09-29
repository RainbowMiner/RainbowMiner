using module .\Include.psm1

$Version = Get-Version $Version

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$SavedFiles = @("Start.bat")

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
            $MinersSave | Add-Member ($_.Name -replace "($($cpus -join '|'))","CPU") $_.Value -ErrorAction Ignore
        }
        $MinersActualSave = [PSCustomObject]@{}
        $MinersSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersSave.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
        $MinersActualSave | ConvertTo-Json | Set-Content $MinersConfigFile -Encoding Utf8

        $DevicesSave = [PSCustomObject]@{}
        $DevicesActual = Get-Content "$DevicesConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $DevicesActual.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {
            $DevicesSave | Add-Member ($_.Name -replace "($($cpus -join '|'))","CPU") $_.Value -ErrorAction Ignore
        }
        $DevicesActualSave = [PSCustomObject]@{}
        $DevicesSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$DevicesActualSave | Add-Member $_ $DevicesSave.$_}
        $DevicesActualSave | ConvertTo-Json | Set-Content $DevicesConfigFile -Encoding Utf8

        $OCprofilesActual = Get-Content "$OCprofilesConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $OCprofilesActual.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {
            if (-not (Get-Member -inputobject $_.Value -name "LockVoltagePoint" -Membertype Properties)) {$_.Value | Add-Member LockVoltagePoint "*" -Force}
        }
        $OCprofilesActualSave = [PSCustomObject]@{}
        $OCprofilesActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$OCprofilesActualSave | Add-Member $_ $OCprofilesActual.$_}
        $OCprofilesActualSave | ConvertTo-Json | Set-Content $OCprofilesConfigFile -Encoding Utf8
    }
    if ($Version -le (Get-Version "3.8.5.5")) {
        if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        try {
            Copy-Item "Stats\*_Profit.txt" "Stats\Pools" -Force
            Remove-Item "Stats\*_Profit.txt"
            $ChangesTotal++
        } catch { }
        try {
            Copy-Item "Stats\*_Hashrate.txt" "Stats\Miners" -Force
            Remove-Item "Stats\*_Hashrate.txt"
            $ChangesTotal++
        } catch { }
    }
    if ($Version -le (Get-Version "3.8.5.15")) {
        [hashtable]$DevicesToVendors = @{}
        $AllDevices | Select-Object Vendor,Name,Type | Foreach-Object {
            $Stat_Name = $_.Name
            $Stat_Vendor = if ($_.Type -eq "GPU") {$_.Vendor}else{"CPU"}
            Get-ChildItem "Stats\Miners" | Where-Object BaseName -notmatch "^(AMD|CPU|NVIDIA)-" | Where-Object BaseName -match "-$($Stat_Name)" | Foreach-Object {Move-Item $_.FullName -Destination "$($_.DirectoryName)\$($Stat_Vendor)-$($_.Name)" -Force;$ChangesTotal++}
        }
    }

    if ($Version -le (Get-Version "3.8.7.5")) {
        if (Test-Path "Setup.ps1") {Remove-Item "Setup.ps1" -Force -ErrorAction Ignore;$ChangesTotal++}
    }

    if ($Version -le (Get-Version "3.8.8.0")) {
        if (Test-Path "Includes\nvml.dll") {Remove-Item "Includes\nvml.dll" -Force -ErrorAction Ignore;$ChangesTotal++}
    }

    $SavedFiles | Where-Object {Test-Path "$($_).saved"} | Foreach-Object {Move-Item "$($_).saved" $_ -Force -ErrorAction Ignore;$ChangesTotal++}

    "Cleaned $ChangesTotal elements"
}
catch {
    "Cleanup failed $($_.Exception.Message)"
}

