using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.5.8a/excavator_v1.5.8a_NVIDIA_Win64.zip"
$Port = "311{0:d2}"

if (-not $Devices.NVIDIA -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonightV7"; SecondaryAlgorithm = ""; Params = @(); Threads = 1},
    #[PSCustomObject]@{MainAlgorithm = "daggerhashimoto"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Ethash (Ethminer is fastest)
    #[PSCustomObject]@{MainAlgorithm = "daggerhashimoto"; SecondaryAlgorithm = "decred"; Params = @(); Threads = 1; Intensity = @("0:0","16:3","16:4","16:5")} #Ethash+Decred (Claymore Dual is fastest)
    #[PSCustomObject]@{MainAlgorithm = "daggerhashimoto"; SecondaryAlgorithm = "pascal"; Params = @(); Threads = 1; Intensity = @("0:0")} #Ethash+Pascal (Claymore Dual is fastest)
    [PSCustomObject]@{MainAlgorithm = "equihash"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Equihash (bminer7 is fastest)
    [PSCustomObject]@{MainAlgorithm = "equihash";  SecondaryAlgorithm = ""; Params = @(); Threads = 2} #Equihash (bminer7 is fastest)
    [PSCustomObject]@{MainAlgorithm = "keccak";  SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Keccak (fastest, but running on nicehash, only!)
    [PSCustomObject]@{MainAlgorithm = "lyra2rev2"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Lyra2RE2 (Alexis78 is fastest)
    [PSCustomObject]@{MainAlgorithm = "lyra2rev2";  SecondaryAlgorithm = ""; Params = @(); Threads = 2} #Lyra2RE2 (Alexis78 is fastest)
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Lyra2z (Tpruvot is fastest)
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #NeoScrypt (fastest, but running on nicehash, only)
    [PSCustomObject]@{MainAlgorithm = "x16r"; SecondaryAlgorithm = ""; Params = @(); Threads = 1; ExtendInterval = 10; FaultTolerance = 0.5; HashrateDuration = "Day"} #X16r

    # ASIC - never profitable 20/04/2018
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "decred"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "pascal"; SecondaryAlgorithm = ""; Params = @(); Threads = 1} #Pascal
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
$Devices.NVIDIA | Where-Object {$_.Model -eq $Devices.FullComboModels.NVIDIA} | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices.NVIDIA | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model

    $DeviceIDsAll = Get-GPUIDs $Miner_Device

    $Commands | ForEach-Object {
        try {            
            $nhBaseAlgorithm = $_.MainAlgorithm
            $nhSecondAlgorithm = $_.SecondaryAlgorithm

            $nhThreads = $_.Threads
            if (-not $nhThreads) {$nhThreads=1}

            $nhParams = $_.Params

            $nhBaseAlgorithm_Norm = @(Get-Algorithm $nhBaseAlgorithm | Select-Object) + @("NHMP") -join "-"

            if (-not (Test-Path (Split-Path $Path))) {New-Item (Split-Path $Path) -ItemType "directory" | Out-Null}

            if ($Pools.$nhBaseAlgorithm_Norm.Host) {

                if ($nhSecondAlgorithm -eq '') {
                    $res = @()
                    $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$nhBaseAlgorithm_Norm.Host -replace '^[^\.]+\.','nhmp.'):3200", "$($Pools.$nhBaseAlgorithm_Norm.User):$($Pools.$nhBaseAlgorithm_Norm.Pass)")})}
                    $res += [PSCustomObject]@{time = 1; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$nhBaseAlgorithm")})}
                    foreach($gpu in $DeviceIDsAll) {$res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("$nhBaseAlgorithm", "$gpu") + $nhParams}) * $nhThreads}}
                    $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @()})}
                    for($worker_id=0; $worker_id -lt ($gpus.count * $nhThreads); $worker_id++) {$res += [PSCustomObject]@{time = 15; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                    $nhConfig = "$($Pools.$nhBaseAlgorithm_Norm.Name)_$($nhBaseAlgorithm_Norm)_$($Pools.$nhBaseAlgorithm_Norm.User)_$($nhThreads)_$(@($Miner_Device.Name | Sort-Object) -join '_').json"

                    $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($nhConfig)" -Force -ErrorAction Stop

                    $Miner_Name = (@($Name) + @($nhThreads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                    [PSCustomObject]@{
                        Name = $Miner_Name
                        DeviceName = $Miner_Device.Name
                        DeviceModel = $Miner_Model
                        Path = $Path
                        Arguments = "-p $($Miner_Port) -c $($nhConfig) -na"
                        HashRates = [PSCustomObject]@{$nhBaseAlgorithm_Norm = $Stats."$($Miner_Name)_$($nhBaseAlgorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
                        API = "Excavator"
                        Port = $Miner_Port
                        URI = $Uri
                        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                        PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"                        
                        ShowMinerWindow = $True
                        FaultTolerance = $_.FaultTolerance
                        ExtendInterval = $_.ExtendInterval
                    }
                } else {

                    $nhSecondAlgorithm_Norm = @(Get-Algorithm $nhSecondAlgorithm_Norm | Select-Object) + @("NHMP") -join "-"

                    $_.Intensity | Foreach-Object {
                        $Dcri = $_
                        $DcriArray = $Dcri -split ":"

                        $res = @()
                        $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$nhBaseAlgorithm_Norm.Host -replace '^[^\.]+\.','nhmp.'):3200", "$($Pools.$nhBaseAlgorithm_Norm.User):$($Pools.$nhBaseAlgorithm_Norm.Pass)")})}
                        $res += [PSCustomObject]@{time = 1; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$nhBaseAlgorithm")}) + @([PSCustomObject]@{id = 2; method = "algorithm.add"; params = @("$($nhAlgorithms[1])")})}
                        foreach($gpu in $DeviceIDsAll) {$res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("$($nhBaseAlgorithm);$($nhSecondAlgorithm)", "$gpu", "R_0=$($DcriArray[0])", "R_1=$($DcriArray[1])") + $nhParams}) * $nhThreads}}
                        $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @()})}
                        for($worker_id=0; $worker_id -lt ($gpus.count * $nhThreads); $worker_id++) {$res += [PSCustomObject]@{time = 15; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                        $nhConfig = "$($Pools.$nhBaseAlgorithm_Norm.Name)_$($nhBaseAlgorithm_Norm)$($nhSecondAlgorithm_Norm)$($Dcri -replace ":","x")_$($Pools.$nhBaseAlgorithm_Norm.User)_$($nhThreads)_$(@($Miner_Device.Name | Sort-Object) -join '_').json"
                        $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($nhConfig)" -Force -ErrorAction Stop

                        $Miner_Name = (@($Name) + @($nhBaseAlgorithm_Norm) + @($nhSecondAlgorithmNorm) + @($Dcri -replace ":","x") + @($nhThreads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                        [PSCustomObject]@{
                            Name = $Miner_Name
                            DeviceName = $Miner_Device.Name
                            DeviceModel = $Miner_Model
                            Path = $Path
                            Arguments = "-p $($Miner_Port) -c $($nhConfig) -na"
                            HashRates = [PSCustomObject]@{
                                $nhBaseAlgorithm_Norm = $Stats."$($Miner_Name)_$($nhBaseAlgorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"
                                $nhSecondAlgorithm_Norm = $Stats."$($Miner_Name)_$($nhSecondAlgorithm_Norm)_HashRate".Week
                            }
                            API = "Excavator"
                            Port = $Miner_Port
                            URI = $Uri
                            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                            PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"                            
                            ShowMinerWindow = $True
                            FaultTolerance = $_.FaultTolerance
                            ExtendInterval = $_.ExtendInterval
                        }
                    }
                }
            }
        }
        catch {
        }
    }
}