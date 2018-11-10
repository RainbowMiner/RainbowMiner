using module .\Include.psm1

$Version = Get-Version $Version

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$SavedFiles = @("Start.bat")

$MinersConfigCleanup = $true
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

    if ($Version -le (Get-Version "3.8.8.7")) {
        $Changes = 0
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($ConfigActual.MinerStatusUrl -and $ConfigActual.MinerStatusUrl -match "httpsrbminernet") {$ConfigActual.MinerStatusUrl = "https://rbminer.net";$Changes++}
        if ($ConfigActual.MinerStatusKey -and $ConfigActual.MinerStatusKey -match "^[0-9a-f]{32}$") {
            $ConfigActual.MinerStatusKey = "$($ConfigActual.MinerStatusKey.Substring(0,8))-$($ConfigActual.MinerStatusKey.Substring(8,4))-$($ConfigActual.MinerStatusKey.Substring(12,4))-$($ConfigActual.MinerStatusKey.Substring(16,4))-$($ConfigActual.MinerStatusKey.Substring(20,12))"
            $Changes++
        }

        if ($Changes) {       
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal += $Changes
        }
    }

    if ($Version -le (Get-Version "3.8.8.17")) {
        if (Test-Path "ReportStatus.ps1") {Remove-Item "ReportStatus.ps1" -Force -ErrorAction Ignore;$ChangesTotal++}
    }

    if ($Version -le (Get-Version "3.8.9.1")) {
        if (Test-Path "Stats\Pools") {
            Get-ChildItem "Stats\Pools" | Where-Object BaseName -match "_(BLK|HSR|TTF)$" | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force}
        }
    }

    if ($Version -le (Get-Version "3.8.10.1")) {
        $MinersConfigCleanup = $true
    }

    if ($Version -le (Get-Version "3.8.10.3")) {
        if ($AlgorithmsConfigFile -and (Test-Path $AlgorithmsConfigFile)) {
            $AlgorithmsActual = Get-Content "$AlgorithmsConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $AlgorithmsActualSave = [PSCustomObject]@{}
            $AlgorithmsActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {$AlgorithmsActualSave | Add-Member $_ ([PSCustomObject]@{Penalty = "$($AlgorithmsActual.$_.Penalty)";MinHashrate = "$($AlgorithmsActual.$_.MinHashrate)";MinWorkers = "$($AlgorithmsActual.$_.MinWorkers)"}) -Force}
            Set-ContentJson -PathToFile $AlgorithmsConfigFile -Data $AlgorithmsActualSave > $null
        }
    }

    if ($Version -le (Get-Version "3.8.11.3")) {       
        if (Test-Path ".\Data\minerinfo.json") {$ChangesTotal++; Remove-Item ".\Data\minerinfo.json" -Force}
        $StatTouch = @()
        $UrisTouch = '[{"Name":"CcminerDumax","Path":".\\Bin\\NVIDIA-ccminerDumax","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4-dumax/ccminer-dumax-0.9.4-win64.zip"},{"Name":"CcminerKlaust","Path":".\\Bin\\NVIDIA-KlausT","URI":["https://github.com/RainbowMiner/miner-binaries/releases/download/v8.23-klaust/ccminer-823-cuda10-x64.zip","https://github.com/RainbowMiner/miner-binaries/releases/download/v8.23-klaust/ccminer-823-cuda92-x64.zip"]},{"Name":"CcminerPigeoncoin","Path":".\\Bin\\NVIDIA-Pigeoncoin","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v2.6-pigeoncoin/Pigeoncoin-Miner.32bit.2.6.zip"},{"Name":"CcminerSkunk","Path":".\\Bin\\NVIDIA-Skunk","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2r1-ccminerskunk/2.2-mod-r1.zip"},{"Name":"CcminerSupr","Path":".\\Bin\\NVIDIA-CcminerSupr","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/git11-spmod/spmodgit11.7z"},{"Name":"CcminerTpruvot","Path":".\\Bin\\NVIDIA-TPruvot","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2.5-tpruvot/ccminer-x86-2.2.5-cuda9.7z"},{"Name":"CcminerTpruvotx64","Path":".\\Bin\\NVIDIA-TPruvotx64","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-tpruvot/ccminer-2.3-cuda9.7z"},{"Name":"CcminerX22i","Path":".\\Bin\\NVIDIA-CcminerX22i","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.0-ccminerx22i/ccminer-x22i-bin-w64-v1.2.0.7z"},{"Name":"CpuminerJayddee","Path":".\\Bin\\CPU-JayDDee","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.8.1-jayddee/cpuminer-opt-3.8.8.1-windows.zip"},{"Name":"CpuminerTpruvotAvx2","Path":".\\Bin\\CPU-TPruvot","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.1-cpuminermulti/cpuminer-multi-rel1.3.1-x64.zip"},{"Name":"CpuminerTpruvotCore2","Path":".\\Bin\\CPU-TPruvot","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.1-cpuminermulti/cpuminer-multi-rel1.3.1-x64.zip"},{"Name":"CpuminerTpruvotCorei7","Path":".\\Bin\\CPU-TPruvot","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.1-cpuminermulti/cpuminer-multi-rel1.3.1-x64.zip"},{"Name":"CpuminerYespower","Path":".\\Bin\\CPU-Yespower","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.8.3-bubasik/cpuminer-opt-cryply-yespower-ver2.zip"},{"Name":"Eminer","Path":".\\Bin\\Ethash-Eminer","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6.1rc2-eminer/eminer.v0.6.1-rc2.win64.zip"},{"Name":"Ethminer","Path":".\\Bin\\Ethash-Ethminer","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v0.17.0-alpha.1-ethminer/ethminer-0.17.0-alpha.1-cuda10.0-windows-amd64.zip"},{"Name":"Excavator","Path":".\\Bin\\NVIDIA-Excavator","URI":"https://github.com/nicehash/excavator/releases/download/v1.5.13a/excavator_v1.5.13a_Win64_CUDA_10.zip"},{"Name":"Sgminer","Path":".\\Bin\\AMD-NiceHash","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v5.6.1-sgminer/sgminer-5.6.1-nicehash-51-windows-amd64.zip"},{"Name":"SgminerKl","Path":".\\Bin\\AMD-SgminerKl","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.6-sgminerkl/sgminer-kl-1.0.6-windows.zip"},{"Name":"SgminerLyra2z","Path":".\\Bin\\AMD-Lyra2z","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v0.3-sgminerlyra2z/kernel.rar"},{"Name":"SgminerSkein","Path":".\\Bin\\Skein-AMD","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v5.3.1-sgminerskein/Release.zip"},{"Name":"SgminerXevan","Path":".\\Bin\\Xevan-AMD","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v5.5.0-sgminerxevan/sgminer-xevan-5.5.0-nicehash-1-windows-amd64.zip"},{"Name":"ZjazzAmd","Path":".\\Bin\\AMD-Zjazz","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2-zjazz/zjazz_amd_win64_1.2.zip"},{"Name":"ZjazzNvidia","Path":".\\Bin\\NVIDIA-Zjazz","URI":"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2-zjazz/zjazz_cuda_win64_1.2.zip"}]' | ConvertFrom-Json
        $UrisTouch | Foreach-Object {
            $UriJson = Join-Path $_.Path "_uri.json"
            if (Test-Path $UriJson) {
                if ($_.URI -is [array] -and $_.URI.Count -gt 1) {
                    $UriNew = $null
                    $CurrentURI = Get-Content $UriJson -Raw | ConvertFrom-Json | Select-Object -ExpandProperty URI
                    $UriNew = $_.URI | Where-Object {$CurrentURI -and (Split-Path $CurrentURI -Leaf) -eq (Split-Path $_ -Leaf)} | Select-Object -First 1
                    if (-not $UriNew) {$UriNew = $_.URI[0]}
                } else {
                    $UriNew = $_.URI
                }
                $ChangesTotal++;$StatTouch += $_.Name;[PSCustomObject]@{URI = $UriNew} | ConvertTo-Json | Set-Content $UriJson -Encoding UTF8
            }
        }
        $StatTouch | Foreach-Object {Get-ChildItem "Stats\Miners\*-$($_)-*_HashRate.txt" | Foreach-Object {$_.LastWriteTime = Get-Date}}

        Get-ChildItem "MinersOldVersions" -Filter "*.ps1" | Foreach-Object {
            if (Test-Path "Miners\$($_.Name)") {Copy-Item "MinersOldVersions\$($_.Name)" "Miners" -Force -ErrorAction Ignore;$ChangesTotal++}
        }
    }

    if ($Version -le (Get-Version "3.8.12.0")) {       
        if (Test-Path "RainbowMinerV3.8.12.0.zip") {$ChangesTotal++; Remove-Item "RainbowMinerV3.8.12.0.zip" -Force -ErrorAction Ignore}
    }

    if ($MinersConfigCleanup) {
        $MinersSave = [PSCustomObject]@{}
        $MinersActual = Get-Content "$MinersConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $MinersActual.PSObject.Properties | Where-Object {$_.MemberType -eq "NoteProperty"} | Foreach-Object {
            $MinerSaveArray = [PSCustomObject[]]@()
            @($_.Value) | Foreach-Object {
                if ($(foreach($q in $_.PSObject.Properties.Name) {if ($q -ne "MainAlgorithm" -and $q -ne "SecondaryAlgorithm" -and ($_.$q -isnot [string] -or $_.$q.Trim() -ne "")) {$true;break}})) {
                    $MinerSaveArray += $_
                }
            }
            if ($MinerSaveArray.Count) {
                $MinersSave | Add-Member $_.Name $MinerSaveArray
            }
        }
        $MinersActualSave = [PSCustomObject]@{}
        $MinersSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersSave.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
        Set-ContentJson -PathToFile $MinersConfigFile -Data $MinersActualSave > $null
        $ChangesTotal++
    }

    $SavedFiles | Where-Object {Test-Path "$($_).saved"} | Foreach-Object {Move-Item "$($_).saved" $_ -Force -ErrorAction Ignore;$ChangesTotal++}

    "Cleaned $ChangesTotal elements"
}
catch {
    "Cleanup failed $($_.Exception.Message)"
}

