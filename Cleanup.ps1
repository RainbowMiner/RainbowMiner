using module .\Include.psm1

$Version = Get-Version $Version

if ($script:MyInvocation.MyCommand.Path) {Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)}

$SavedFiles = @("Start.bat")

Set-OsFlags

$DownloadsCleanup = $true
$MinersConfigCleanup = $true
$PoolsConfigCleanup = $true
$CacheCleanup = $false
$OverridePoolPenalties = $false
$ChangesTotal = 0
$AddAlgorithm = @()
$RemoveMinerStats = @()
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
    if ($Version -le (Get-Version "3.8.4.4") -and $IsWindows) {
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

    if ($Version -le (Get-Version "3.8.13.4")) {
        $CacheCleanup = $true
    }

    if ($Version -le (Get-Version "3.8.13.6")) {
        #CcminerAlexis78x64 -> CcminerAlexis78
        #CcminerTpruvotx64 -> CcminerTpruvot
        
        if (Test-Path "Stats\Miners") {
            Get-ChildItem "Stats\Miners" -Filter "NVIDIA-CcminerAlexis78-*txt" | Foreach-Object {$ChangesTotal++; Remove-Item $_.FullName -Force -ErrorAction Ignore}
            Get-ChildItem "Stats\Miners" -Filter "NVIDIA-CcminerAlexis78x64-*txt" | Foreach-Object {$ChangesTotal++; Move-Item $_.FullName -Destination "$($_.DirectoryName)\$($_.Name -replace "78x64","78")" -Force}
            Get-ChildItem "Stats\Miners" -Filter "NVIDIA-CcminerTpruvot-*txt" | Foreach-Object {$ChangesTotal++; Remove-Item $_.FullName -Force -ErrorAction Ignore}
            Get-ChildItem "Stats\Miners" -Filter "NVIDIA-CcminerTpruvotx64-*txt" | Foreach-Object {$ChangesTotal++; Move-Item $_.FullName -Destination "$($_.DirectoryName)\$($_.Name -replace "otx64","ot")" -Force}
        }

        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $ConfigActual.MinerName = $ConfigActual.MinerName -replace "(CcminerAlexis78|CcminerTpruvot)\s*(,\s*|$)" -replace "[,\s]+$" -replace "(CcminerAlexis78|CcminerTpruvot)x64","`$1"
        $ConfigActual.ExcludeMinerName = $ConfigActual.ExcludeMinerName -replace "(CcminerAlexis78|CcminerTpruvot)\s*(,\s*|$)" -replace "[,\s]+$" -replace "(CcminerAlexis78|CcminerTpruvot)x64","`$1"
        $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
        $ChangesTotal++

        $MinersSave = [PSCustomObject]@{}
        $MinersActual = Get-Content "$MinersConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $MinersActual.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {
            if (($_.Name -match "CcminerAlexis78x64" -or $_.Name -match "CcminerTpruvotx64") -or ($_.Name -notmatch "CcminerAlexis78" -and $_.Name -notmatch "CcminerTpruvot")) {                
                $MinersSave | Add-Member $(if ($_.Name -match "CcminerAlexis78x64") {$_.Name -replace "78x64","78"} elseif ($_.Name -match "CcminerTpruvotx64") {$_.Name -replace "otx64","ot"} else {$_.Name}) $_.Value -ErrorAction Ignore -Force
            }
        }        
        $MinersActualSave = [PSCustomObject]@{}
        $MinersSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersSave.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
        $MinersActualSave | ConvertTo-Json | Set-Content $MinersConfigFile -Encoding Utf8
        $ChangesTotal++

        $DevicesSave = [PSCustomObject]@{}
        $DevicesActual = Get-Content "$DevicesConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $DevicesActual.PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {
            $_.Value.MinerName = $_.Value.MinerName -replace "(CcminerAlexis78|CcminerTpruvot)\s*(,\s*|$)" -replace "[,\s]+$" -replace "(CcminerAlexis78|CcminerTpruvot)x64","`$1"
            $_.Value.ExcludeMinerName = $_.Value.ExcludeMinerName -replace "(CcminerAlexis78|CcminerTpruvot)\s*(,\s*|$)" -replace "[,\s]+$" -replace "(CcminerAlexis78|CcminerTpruvot)x64","`$1"
            $DevicesSave | Add-Member $_.Name $_.Value -ErrorAction Ignore
        }
        $DevicesActualSave = [PSCustomObject]@{}
        $DevicesSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$DevicesActualSave | Add-Member $_ $DevicesSave.$_}
        $DevicesActualSave | ConvertTo-Json | Set-Content $DevicesConfigFile -Encoding Utf8
        $ChangesTotal++
    }

    if ($Version -le (Get-Version "3.8.13.9")) {
        #remove combos from stats
        $AllDevices | Where-Object {$_.Model -ne "CPU" -and ($_.Vendor -eq "NVIDIA" -or $_.Vendor -eq "AMD")} | Select-Object -ExpandProperty Model -Unique | Foreach-Object {
            $Model = $_
            $ModelName = ($AllDevices | Where-Object Model -eq $Model | Select-Object -ExpandProperty Name | Sort-Object) -join '-'
            Get-ChildItem "Stats\Miners\*$($ModelName -replace '-','*')*_*_HashRate.txt" | Foreach-Object {
                if ($_.BaseName -match "^.+?(GPU.+?)_" -and $Matches[1] -ne $ModelName) {
                    Remove-Item $_.FullName -Force -ErrorAction Ignore
                    $ChangesTotal++
                }
            }
        }        
    }

    if ($Version -le (Get-Version "3.8.13.14")) {
        $AddAlgorithm += @("cnfreehaven","dedal","exosis","lyra2vc0banhash","pipe","x21s")
    }

    if ($Version -le (Get-Version "3.9.0.1")) {
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $Algorithms = $ConfigActual.Algorithm
        if ($Algorithms -is [string]) {$Algorithms = $Algorithms.Trim(); $Algorithms = @(if ($Algorithms -ne ''){@([regex]::split($Algorithms.Trim(),"\s*[,;:]+\s*") | Where-Object {$_})})}
        if ($Algorithms -and $Algorithms.Count -le 7 -and (-not (Compare-Object $Algorithms @("cnfreehaven","dedal","exosis","lyra2vc0banhash","pipe","x21s")) -or -not (Compare-Object $Algorithms @("cnfreehaven","dedal","exosis","lyra2vc0banhash","pipe","x21s","x20r")))) {
            $ConfigActual.Algorithm = ""
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal++
        }
        $AddAlgorithm += @("x20r")
    }

    if ($Version -le (Get-Version "3.9.0.2")) {
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $Algorithms = $ConfigActual.Algorithm
        if ($Algorithms -is [string]) {$Algorithms = $Algorithms.Trim(); $Algorithms = @(if ($Algorithms -ne ''){@([regex]::split($Algorithms.Trim(),"\s*[,;:]+\s*") | Where-Object {$_})})}
        if ($Algorithms -and $Algorithms.Count -le 7 -and (-not (Compare-Object $Algorithms @("cnfreehaven","dedal","exosis","lyra2vc0banhash","pipe","x21s")) -or -not (Compare-Object $Algorithms @("cnfreehaven","dedal","exosis","lyra2vc0banhash","pipe","x21s","x20r")))) {
            $ConfigActual.Algorithm = ""
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal++
        }
    }

    if ($Version -le (Get-Version "3.9.0.3")) {
        $AddAlgorithm += @("lyra2v3","gltastralhash","gltjeonghash","gltpadihash","gltpawelhash")
    }

    if ($Version -le (Get-Version "3.9.0.6")) {
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $Algorithms = $ConfigActual.Algorithm
        if ($Algorithms -is [string]) {$Algorithms = $Algorithms.Trim(); $Algorithms = @(if ($Algorithms -ne ''){@([regex]::split($Algorithms.Trim(),"\s*[,;:]+\s*") | Where-Object {$_})})}
        if ($Algorithms | Where-Object {$_ -eq "System.Object[]"}) {
            $Algorithms = $Algorithms | Where-Object {$_ -ne "System.Object[]"}
            $ConfigActual.Algorithm = $Algorithms -join ','
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal++
        }
    }

    if ($Version -le (Get-Version "3.9.0.9")) {
        $AddAlgorithm += @("cnupx","cnhycon","binarium")
    }

    if ($Version -le (Get-Version "3.9.1.3")) {
        $AddAlgorithm += @("mtp","cnturtle","cnwebchain")
    }

    if ($Version -le (Get-Version "3.9.1.7")) {
        $AddAlgorithm += @("x16rt")
    }

    if ($Version -le (Get-Version "3.9.1.8")) {
        $AddAlgorithm += @("beam","lyra2zz")
    }

    if ($Version -le (Get-Version "3.9.1.9")) {
        $AddAlgorithm += @("sha256q")
    }

    if ($Version -le (Get-Version "3.9.2.0")) {
        if (Test-Path "Bin\Cryptonight-Fireice250") {
            Get-ChildItem "Bin\Cryptonight-Fireice250\*.txt" | Foreach-Object {
                if ($_.BaseName -match "^(amd|nvidia)_.+?(-GPU.+)$") {                    
                    if ((Get-Content $_) -match "platform_index") {
                        Remove-Item $_.FullName -Force -ErrorAction Ignore
                        $ChangesTotal++
                    }
                }
            }
        }
    }

    if ($Version -le (Get-Version "3.9.2.5")) {
        $AddAlgorithm += @("cuckaroo29")
    }

    if ($Version -le (Get-Version "3.9.2.7")) {
        $AddAlgorithm += @("progpow")
    }

    if ($Version -le (Get-Version "3.9.2.8")) {
        $AddAlgorithm += @("argon2ddyn")
    }

    if ($Version -le (Get-Version "3.9.3.5")) {
        $AddAlgorithm += @("nrghash")
    }

    if ($Version -le (Get-Version "3.9.3.6")) {
        $AddAlgorithm += @("aeternity")
    }

    if ($Version -le (Get-Version "3.9.3.7")) {
        Get-ChildItem "Stats\Pools\NLpool_Cuckoo_Profit.txt" -ErrorAction Ignore | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
        $RemoveMinerStats += @("*Zjazz*Cuckoo_HashRate.txt")
    }

    if ($Version -le (Get-Version "3.9.3.9")) {
        Get-ChildItem "Stats\Miners" -Filter "*Excavator*_HashRate.txt" -ErrorAction Ignore | Foreach-Object {
            try {$tmp = Get-Content $_.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop} catch {$tmp = $null}
            if (-not $tmp -or $tmp.Live -eq 0) {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
        }
    }

    if ($Version -le (Get-Version "3.9.4.7")) {
        $AddAlgorithm += @("Cuckatoo31")
    }

    if ($Version -le (Get-Version "3.9.5.0")) {
        $AddAlgorithm += @("BMW512")
    }

    if ($Version -le (Get-Version "3.9.6.9")) {
        $AddAlgorithm += @("CryptonightConceal","CryptonightR")
    }

    if ($Version -le (Get-Version "3.9.7.1")) {
        $AddAlgorithm += @("Cuckaroo29s")
    }

    if ($Version -le (Get-Version "3.9.7.8")) {
        Get-ChildItem "Stats\Pools\CryptoKnight_XWP_Profit.txt" -ErrorAction Ignore | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
        $AddAlgorithm += @("CryptonightHeavyX","CryptonightZelerius")
    }

    if ($Version -le (Get-Version "3.9.8.7")) {
        $AddAlgorithm += @("CryptonightReverseWaltz")
    }

    if ($Version -le (Get-Version "3.9.9.0")) {
        Get-ChildItem "Data\f2pool.json" -ErrorAction Ignore | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
    }

    if ($Version -le (Get-Version "3.9.9.1")) {
        $AddAlgorithm += @("RandomHash")
    }

    if ($Version -le (Get-Version "3.9.9.6")) {
        Get-ChildItem "Stats\Pools\*_X16R_Profit.txt" -ErrorAction Ignore | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
        Get-ChildItem "Cache\CF6B480CCADD0F94919E433BCFB39B6A.asy" -ErrorAction Ignore | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
        Get-ChildItem "Cache\9B8D3F77FF714598BCE6AC505C91A328.asy" -ErrorAction Ignore | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
    }

    if ($Version -le (Get-Version "3.9.9.7")) {
        $AddAlgorithm += @("RainForest")
    }

    if ($Version -le (Get-Version "4.0.0.3")) {
        $AddAlgorithm += @("YespowerR16")
    }

    if ($Version -le (Get-Version "4.0.0.8")) {
        $OverridePoolPenalties = $true
    }

    if ($Version -le (Get-Version "4.2.0.6")) {
        if (Test-Path ".\Stats\Pools\Zpool_Equihash16x5_Profit.txt") {
            Remove-Item ".\Stats\Pools\Zpool_Equihash16x5_Profit.txt" -Force -ErrorAction Ignore
            $ChangesTotal++
        }
    }

    if ($Version -le (Get-Version "4.3.0.1")) {
        $AddAlgorithm += @("CuckooCycle")
    }

    if ($Version -le (Get-Version "4.3.0.3")) {
        $AddAlgorithm += @("ProgPoWZ","Rainforest2")
    }

    if ($Version -le (Get-Version "4.3.1.2")) {
        $AddAlgorithm += @("X25x")
    }

    if ($Version -le (Get-Version "4.3.1.5")) {
        $AddAlgorithm += @("ProgPow092","ProgPowH","TEThashV1")
    }

    if ($Version -le (Get-Version "4.3.1.8")) {
        $AddAlgorithm += @("Lux")
    }

    if ($Version -le (Get-Version "4.3.2.8")) {
        $AddAlgorithm += @("Blake2b")
    }

    if ($Version -le (Get-Version "4.3.3.4")) {
        $CacheCleanup = $true
    }

    if ($Version -le (Get-Version "4.3.4.1")) {
        $AddAlgorithm += @("EquihashVds")
    }

    if ($Version -le (Get-Version "4.3.5.0")) {
        $AddAlgorithm += @("Cuckarood29","RandomWow")
    }

    if ($Version -le (Get-Version "4.3.5.4")) {
        $AddAlgorithm += @("Scrypt8k")
        $CacheCleanup = $true
    }

    if ($Version -le (Get-Version "4.3.5.9")) {
        $CacheCleanup = $true
    }

    if ($Version -le (Get-Version "4.3.6.5")) {
        $AddAlgorithm += @("RandomXL")
    }

    if ($Version -le (Get-Version "4.3.8.4")) {
        $RemoveMinerStats += @("*-Gminer-*_Equihash25x5_HashRate.txt")
        if (Test-Path "Stats\Balances") {Get-ChildItem ".\Stats\Balances" -File | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}}
    }

    if ($Version -le (Get-Version "4.3.8.5")) {
        if (Test-Path ".\Stats\Balances\Earnings_Localized.csv") {
            (Get-Content ".\Stats\Balances\Earnings_Localized.csv" -Raw -ErrorAction Ignore) -replace "`",`"","`"$((Get-Culture).TextInfo.ListSeparator)`"" | Set-Content ".\Stats\Balances\Earnings_Localized.csv" -Force
        }
        if (Test-Path ".\Data\mrrinfo.json") {Remove-Item ".\Data\mrrinfo.json" -Force -ErrorAction Ignore; $ChangesTotal++}
    }

    if ($Version -le (Get-Version "4.3.9.1")) {
        $Changes = 0
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($ConfigActual.EthPillEnalbeMTP -ne $null) {
            $ConfigActual | Add-Member EthPillEnableMTP $($ConfigActual.EthPillEnalbeMTP -replace "Enalbe","Enable") -Force
            $ConfigActual.PSObject.Properties.Remove("EthPillEnalbeMTP")
            $Changes++;
        }
        if ($Changes) {       
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal += $Changes
        }
    }

    if ($Version -le (Get-Version "4.3.9.2")) {
        $AddAlgorithm += @("EquihashR150x5x3","RandomX")
        Get-ChildItem ".\Stats\Miners" -Filter "*_EquihashR25x4x0_HashRate.txt" -File | Foreach-Object {$ChangesTotal++;Rename-Item $_.FullName ($_.Name -replace "Equihash25x4x0","EquihashR25x4") -Force -ErrorAction Ignore}
        Get-ChildItem ".\Stats\Miners" -Filter "*_EquihashR25x5x0_HashRate.txt" -File | Foreach-Object {$ChangesTotal++;Rename-Item $_.FullName ($_.Name -replace "Equihash25x5x0","EquihashR25x5") -Force -ErrorAction Ignore}
        Get-ChildItem ".\Stats\Miners" -Filter "*_Equihash25x4_HashRate.txt" -File | Foreach-Object {$ChangesTotal++;Rename-Item $_.FullName ($_.Name -replace "Equihash25x4","EquihashR25x4") -Force -ErrorAction Ignore}
        Get-ChildItem ".\Stats\Miners" -Filter "*_Equihash25x5_HashRate.txt" -File | Foreach-Object {$ChangesTotal++;Rename-Item $_.FullName ($_.Name -replace "Equihash25x5","EquihashR25x5") -Force -ErrorAction Ignore}
        $Changes = 0
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($ConfigActual.EnableAlgorithmMapping -eq "`$EnableAlgorithmMapping" -or $ConfigActual.EnableAlgorithmMapping -eq $null) {
            $ConfigActual | Add-Member EnableAlgorithmMapping "1" -Force
            $Changes++;
        }
        if ($Changes) {       
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal += $Changes
        }
    }

    if ($Version -le (Get-Version "4.3.9.5")) {
        $RemoveMinerStats += @("*-MiniZ-*_EquihashR25x5x3_HashRate.txt","*-CcminerMTP-*_MTP_HashRate.txt")
        $AddAlgorithm += @("RandomX","ScryptSIPC")
    }

    if ($Version -le (Get-Version "4.3.9.6")) {
        Get-ChildItem "Stats\Totals" -Filter "Totals_*.csv" | Foreach-Object {
            @(Import-Csv $_.FullName -ErrorAction Ignore | Foreach-Object {
                            [PSCustomObject]@{
                                Date      = $_.Date
                                Date_UTC  = $_.Date_UTC
                                PoolName  = $_.PoolName
                                Algorithm = $_.Algorithm
                                Currency  = $_.Currency
                                Rate      = $_.Rate
                                Profit    = $_.Profit
                                ProfitApi = if ($_.ProfitApi -eq $null) {$_.Profit} else {$_.ProfitApi}
                                Cost      = $_.Cost
                                Power     = $_.Power
                                Penalty   = if ($_.Penalty -eq $null) {"0"} else {$_.Penalty}
                                Duration  = $_.Duration
                                Donation  = $_.Donation
                            }
                        } | Select-Object) | Export-Csv $_.FullName -NoTypeInformation -ErrorAction Ignore
            $ChangesTotal++
        }

        Get-ChildItem "Stats\Totals" -Filter "*_Total.txt" | Foreach-Object {
            $Stat = Get-Content $_.FullName -ErrorAction Ignore -Raw | ConvertFrom-Json -ErrorAction Ignore

            Set-ContentJson "$($_.FullName -replace "_Total.txt","_TotalAvg.txt")" $([PSCustomObject]@{
                Pool          = $Stat.Pool
                Cost_1d       = [double]$Stat.Cost_1d
                Cost_1w       = [double]$Stat.Cost_1w
                Cost_Avg      = [double]$Stat.Cost_Avg
                Profit_1d     = [double]$Stat.Profit_1d
                Profit_1w     = [double]$Stat.Profit_1w
                Profit_Avg    = [double]$Stat.Profit_Avg
                ProfitApi_1d  = [double]$Stat.Profit_1d
                ProfitApi_1w  = [double]$Stat.Profit_1w
                ProfitApi_Avg = [double]$Stat.Profit_Avg
                Power_1d      = [double]$Stat.Power_1d
                Power_1w      = [double]$Stat.Power_1w
                Power_Avg     = [double]$Stat.Power_Avg
                Started       = $Stat.Started
                Updated       = $Stat.Updated
            }) > $null

            Set-ContentJson $_.FullName $([PSCustomObject]@{
                Pool          = $Stat.Pool
                Duration      = [double]$Stat.Duration
                Cost          = [double]$Stat.Cost
                Profit        = [double]$Stat.Profit
                ProfitApi     = [double]$Stat.Profit
                Power         = [double]$Stat.Power
                Started       = $Stat.Started
                Updated       = $Stat.Updated
            }) > $null

            $ChangesTotal += 2
        }
    }

    if ($Version -le (Get-Version "4.3.9.7")) {
        $AddAlgorithm += @("Argon2Chukwa","Argon2Wkrz")
    }

    if ($Version -le (Get-Version "4.4.0.1")) {
        $AddAlgorithm += @("CryptoNightLiteUpx2","DefyX")
    }

    if ($Version -le (Get-Version "4.4.1.7")) {
        $AddAlgorithm += @("X16rv2")
        $AlgorithmsActual = Get-Content "$AlgorithmsConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($AlgorithmsActual.X16rv2 -ne $null -and $AlgorithmsActual.X16rv2.OCProfile -eq "") {
            $AlgorithmsActual.X16rv2 | Add-Member MSIAprofile 4 -Force
            $AlgorithmsActual.X16rv2 | Add-Member OCProfile "Profile4" -Force
            Set-ContentJson -PathToFile $AlgorithmsConfigFile -Data $AlgorithmsActual > $null
        }
    }

    if ($Version -le (Get-Version "4.4.1.8")) {
        Get-ChildItem "Stats\Pools" -Filter "*_TRTL_*" -File | Foreach-Object {Remove-Item $_.FullName -Force;$ChangesTotal++}
        Get-ChildItem "Stats\Pools" -Filter "*_VOLLAR_*" -File | Foreach-Object {Remove-Item $_.FullName -Force;$ChangesTotal++}
    }

    if ($Version -le (Get-Version "4.4.2.4")) {
        $AddAlgorithm += @("Eaglesong")
        Get-ChildItem "Stats\Pools" -Filter "*_Profit.txt" -File | Foreach-Object {Remove-Item $_.FullName -Force;$ChangesTotal++}
    }

    if ($Version -le (Get-Version "4.4.3.1")) {
        Get-ChildItem "Stats\Miners" -Filter "*x16rv2_HashRate.txt" -File | Foreach-Object {Remove-Item $_.FullName -Force;$ChangesTotal++}
    }

    if ($Version -le (Get-Version "4.4.3.5")) {
        Get-ChildItem "Stats\Pools" -Filter "Zpool_BMW512_Profit.txt" -File | Foreach-Object {Remove-Item $_.FullName -Force;$ChangesTotal++}
    }

    if ($Version -le (Get-Version "4.4.3.9")) {
        $AddAlgorithm += @("Yespower2b")
    }

    if ($Version -le (Get-Version "4.4.4.7")) {
        $AddAlgorithm += @("Kangaroo12")
    }

    if ($Version -le (Get-Version "4.4.4.8")) {
        $Changes = 0
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($ConfigActual.ExcludeServerConfigVars -ne "`$ExcludeServerConfigVars" -and (Get-ConfigArray $ConfigActual.ExcludeServerConfigVars) -inotcontains "GroupName") {
            $ConfigActual | Add-Member ExcludeServerConfigVars "$((@(Get-ConfigArray $ConfigActual.ExcludeServerConfigVars | Select-Object) + "GroupName") -join ',')" -Force
            $Changes++;
        }
        if ($Changes) {
            $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
            $ChangesTotal += $Changes
        }
    }

    if ($OverridePoolPenalties) {
        if (Test-Path "Data\PoolsConfigDefault.ps1") {
            $PoolsDefault = Get-ChildItemContent "Data\PoolsConfigDefault.ps1" -Quick
            $PoolsActual  = Get-Content "$PoolsConfigFile" -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            if ($PoolsActual -and $PoolsDefault.Content) {
                $Changes = 0
                $PoolsDefault.Content.PSObject.Properties.Name | Where-Object {$PoolsDefault.Content.$_.Fields.Penalty} | Foreach-Object {
                    $Penalty = [int]$PoolsDefault.Content.$_.Fields.Penalty
                    try {$OldPenalty = [int]$PoolsActual.$_.Penalty} catch {$OldPenalty = 0}
                    if ($PoolsActual.$_ -and (-not $PoolsActual.$_.Penalty -or ($OldPenalty -lt $Penalty))) {$PoolsActual.$_ | Add-Member Penalty $Penalty -Force;$Changes++}
                }
                if ($Changes) {
                    Set-ContentJson -PathToFile $PoolsConfigFile -Data $PoolsActual > $null
                    $ChangesTotal += $Changes
                }
            }
        }
    }

    if ($PoolsConfigCleanup) {
        if (Test-Path "Data\PoolsConfigDefault.ps1") {
            $PoolsDefault = Get-ChildItemContent "Data\PoolsConfigDefault.ps1" -Quick
            $PoolsActual  = Get-Content "$PoolsConfigFile" -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            if ($PoolsActual -and $PoolsDefault.Content) {
                $Changes = 0
                foreach ($rapi in @("API_ID","API_Key","User")) {
                    $PoolsDefault.Content.PSObject.Properties.Name | Where-Object {$PoolsActual.$_ -and $PoolsActual.$_.PSObject.Properties.Name -icontains $rapi} | Where-Object {-not $PoolsDefault.Content.$_.Fields -or $PoolsDefault.Content.$_.Fields.PSObject.Properties.Name -inotcontains $rapi} | Foreach-Object {
                        $PoolsActual.$_.PSObject.Properties.Remove($rapi)
                        $Changes++
                    }
                }
                if ($Changes) {
                    Set-ContentJson -PathToFile $PoolsConfigFile -Data $PoolsActual > $null
                    $ChangesTotal += $Changes
                }
            }
        }
    }

    if ($AddAlgorithm.Count -gt 0) {
        $ConfigActual = Get-Content "$ConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($ConfigActual.EnableAutoAlgorithmAdd -ne "`$EnableAutoAlgorithmAdd" -and (Get-Yes $ConfigActual.EnableAutoAlgorithmAdd)) {
            $Algorithms = $ConfigActual.Algorithm
            $Algorithms_Hash = [hashtable]@{}
            if ($Algorithms -is [string]) {$Algorithms = $Algorithms.Trim(); $Algorithms = @(if ($Algorithms -ne ''){@([regex]::split($Algorithms.Trim(),"\s*[,;:]+\s*") | Where-Object {$_})})}
            $Algorithms | Foreach-Object {$Algorithms_Hash[$(Get-Algorithm $_)] = $true}
            $Changes = 0
            if ($Algorithms -and $Algorithms.Count -gt 0) {
                $AddAlgorithm | Where-Object {-not $Algorithms_Hash.ContainsKey($(Get-Algorithm $_))} | Foreach-Object {$Algorithms += $_;$Algorithms_Hash[$(Get-Algorithm $_)] = $true;$Changes++}
                if ($Changes -gt 0) {
                    $ConfigActual.Algorithm = ($Algorithms | Sort-Object) -join ","
                    $ConfigActual | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
                    $ChangesTotal+=$Changes
                }
            }
        }
    }

    $MinersContent = Get-MinersContent -InfoOnly

    if ($RemoveMinerStats.Count -gt 0) {
        $RemoveMinerStats | Foreach-Object {
            Get-ChildItem ".\Stats\Miners" -Filter $_ -File | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}
        }
    }

    if ($MinersConfigCleanup) {
        $MinersContentBaseNames = @($MinersContent | Where-Object {$_.BaseName} | Select-Object -ExpandProperty BaseName)
        $AllDevicesModels = @(Get-DeviceSubsets $AllDevices | Select-Object -ExpandProperty Model -Unique)
        $MinersSave = [PSCustomObject]@{}
        $MinersActual = Get-Content "$MinersConfigFile" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $MinersActual.PSObject.Properties | Where-Object {$_.MemberType -eq "NoteProperty"} | Foreach-Object {
            $BaseName = $_.Name -replace "-.+$"
            $Models = $_.Name -replace "^.+-" -split '-'
            if ($MinersContentBaseNames -icontains $BaseName -and ($BaseName -eq $Models -or -not (Compare-Object $AllDevicesModels $Models | Where-Object SideIndicator -eq "=>" | Measure-Object).Count)) {
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
        }
        $MinersActualSave = [PSCustomObject]@{}
        $MinersSave.PSObject.Properties.Name | Sort-Object | Foreach-Object {$MinersActualSave | Add-Member $_ @($MinersSave.$_ | Sort-Object MainAlgorithm,SecondaryAlgorithm)}
        Set-ContentJson -PathToFile $MinersConfigFile -Data $MinersActualSave > $null
        $ChangesTotal++
    }

    if ($CacheCleanup) {if (Test-Path "Cache") {Get-ChildItem "Cache" -Filter "*.asy" | Foreach-Object {$ChangesTotal++;Remove-Item $_.FullName -Force -ErrorAction Ignore}}}

    $SavedFiles | Where-Object {Test-Path "$($_).saved"} | Foreach-Object {Move-Item "$($_).saved" $_ -Force -ErrorAction Ignore;$ChangesTotal++}

    if ($DownloadsCleanup) {
        if (Test-Path "Downloads"){
            $AllMinersArchives = $MinersContent | Where-Object {$_.Uri} | Foreach-Object {Split-Path $_.Uri -Leaf} | Sort-Object
            Get-ChildItem -Path "Downloads" -Filter "*" -File | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-5) -and $AllMinersArchives -notcontains $_.Name} | Foreach-Object {
                Remove-Item $_.FullName -Force -ErrorAction Ignore
                $ChangesTotal++
            }
        }
    }

    if (Test-Path ".\Data\minerinfo.json") {Remove-Item ".\Data\minerinfo.json" -Force -ErrorAction Ignore; $ChangesTotal++}

    "Cleaned $ChangesTotal elements"
}
catch {
    "Cleanup failed $($_.Exception.Message)"
}

