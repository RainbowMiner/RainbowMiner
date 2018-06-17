using module ..\Include.psm1

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.5.4a/excavator_v1.5.4a_NVIDIA_Win64.zip"
$Port = "311{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "cryptonightV7" = @()
    #"daggerhashimoto" = @() #Ethash (Ethminer is fastest)
    #"daggerhashimoto;decred" = @() #Ethash+Decred (Claymore Dual is fastest)
    #"daggerhashimoto;pascal" = @() #Ethash+Pascal (Claymore Dual is fastest)
    #"equihash" = @() #Equihash (bminer7 is fastest)
    #"equihash:2" = @() #Equihash (bminer7 is fastest)
    "keccak" = @() #Keccak (fastest, but running on nicehash, only!)
    #"lyra2rev2" = @() #Lyra2RE2 (Alexis78 is fastest)
    #"lyra2rev2:2" = @() #Lyra2RE2 (Alexis78 is fastest)
    #"lyra2z" = @() #Lyra2z (Tpruvot is fastest)
    "neoscrypt" = @() #NeoScrypt (fastest, but running on nicehash, only)

    # ASIC - never profitable 20/04/2018
    #"blake2s" = @() #Blake2s
    #"decred" = @() #Decred
    #"lbry" = @() #Lbry
    #"pascal" = @() #Pascal
}

$Dcris = [PSCustomObject]@{
    "daggerhashimoto;pascal" = "0:0"
    "daggerhashimoto;decred" = "0:0","16:3","16:4","16:5"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
#    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
#    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
#    $Miner_Model = $_.Model

$Devices | Select-Object Vendor -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = "NVIDIA"

    $DeviceIDsAll = Get-GPUIDs $Miner_Device

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
        try {
            $nhAlgorithm = $_
            $nhAlgorithms = @($_ -split ";")
            $nhBaseAlgorithm = $nhAlgorithms[0] -split ":" | Select-Object -Index 0
            $nhThreads = $nhAlgorithms[0] -split ":" | Select-Object -Index 1
            if ( -not $nhThreads ) {$nhThreads=1}

            $nhBaseAlgorithm_Norm = Get-Algorithm $nhBaseAlgorithm

            $Threads.$nhAlgorithm | Foreach-Object {
                if ( -not (Test-Path (Split-Path $Path)) ) { New-Item (Split-Path $Path) -ItemType "directory" | Out-Null }

                if ($Pools.$nhBaseAlgorithm_Norm.Host -and $Pools.$nhBaseAlgorithm_Norm.Name -like "Nicehash") {

                    if ( $nhAlgorithms.Count -eq 1 ) {
                        $res = @()
                        $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$nhBaseAlgorithm_Norm.Host -replace '^[^\.]+\.','nhmp.'):3200", "$($Pools.$nhBaseAlgorithm_Norm.User):$($Pools.$nhBaseAlgorithm_Norm.Pass)")})}
                        $res += [PSCustomObject]@{time = 1; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$nhBaseAlgorithm")})}
                        foreach( $gpu in $DeviceIDsAll ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("$nhAlgorithm", "$gpu") + $Commands.$nhAlgorithm}) * $nhThreads}}
                        $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @()})}
                        for( $worker_id=0; $worker_id -lt ($gpus.count * $nhThreads); $worker_id++ ) { $res += [PSCustomObject]@{time = 15; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                        $nhConfig = "$($Pools.$nhBaseAlgorithm_Norm.Name)_$($nhBaseAlgorithm_Norm)_$($Pools.$nhBaseAlgorithm_Norm.User)_$($nhThreads)_$(@($Miner_Device.Name | Sort-Object) -join '_').json"

                        $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($nhConfig)" -Force -ErrorAction Stop

                        $Miner_Name = (@($Name) + @($nhThreads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                        [PSCustomObject]@{
                            Name = $Miner_Name
                            DeviceName = $Miner_Device.Name
                            DeviceModel = $Miner_Model
                            Path = $Path
                            Arguments = "-p $($Miner_Port) -c $($nhConfig) -na"
                            HashRates = [PSCustomObject]@{$nhBaseAlgorithm_Norm = $Stats."$($Miner_Name)_$($nhBaseAlgorithm_Norm)_HashRate".Week}
                            API = "Excavator"
                            Port = $Miner_Port
                            URI = $Uri
                            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                            PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                            MSIAprofile = if ( $nhBaseAlgorithm -eq "neoscrypt" ) { 3 } else { 2 }
                            ShowMinerWindow = $True
                        }
                    } else {

                        $nhSecondAlgorithm_Norm = Get-Algorithm $nhAlgorithms[1]

                        $Dcris.$nhAlgorithm | Foreach-Object {
                            $Dcri = $_
                            $DcriArray = $Dcri -split ":"

                            $res = @()
                            $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$nhBaseAlgorithm_Norm.Host -replace '^[^\.]+\.','nhmp.'):3200", "$($Pools.$nhBaseAlgorithm_Norm.User):$($Pools.$nhBaseAlgorithm_Norm.Pass)")})}
                            $res += [PSCustomObject]@{time = 1; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$nhBaseAlgorithm")}) + @([PSCustomObject]@{id = 2; method = "algorithm.add"; params = @("$($nhAlgorithms[1])")})}
                            foreach( $gpu in $DeviceIDsAll ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("$nhAlgorithm", "$gpu", "R_0=$($DcriArray[0])", "R_1=$($DcriArray[1])") + $Commands.$nhAlgorithm}) * $nhThreads}}
                            $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @()})}
                            for( $worker_id=0; $worker_id -lt ($gpus.count * $nhThreads); $worker_id++ ) { $res += [PSCustomObject]@{time = 15; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                            $nhConfig = "$($Pools.$nhBaseAlgorithm_Norm.Name)_$($nhBaseAlgorithm_Norm)$($nhSecondAlgorithm_Norm)$($Dcri -replace ":","x")_$($Pools.$nhBaseAlgorithm_Norm.User)_$($nhThreads)_$(@($Miner_Device.Name | Sort-Object) -join '_').json"
                            $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($nhConfig)" -Force -ErrorAction Stop

                            $Miner_Name = (@("$($Name)$($nhBaseAlgorithm_Norm)$($nhSecondAlgorithmNorm)$($Dcri -replace ":","x")") + @($nhThreads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                            [PSCustomObject]@{
                                Name = $Miner_Name
                                DeviceName = $Miner_Device.Name
                                DeviceModel = $Miner_Model
                                Path = $Path
                                Arguments = "-p $($Miner_Port) -c $($nhConfig) -na"
                                HashRates = [PSCustomObject]@{
                                    $nhBaseAlgorithm_Norm = $Stats."$($Miner_Name)_$($nhBaseAlgorithm_Norm)_HashRate".Week
                                    $nhSecondAlgorithm_Norm = $Stats."$($Miner_Name)_$($nhSecondAlgorithm_Norm)_HashRate".Week
                                }
                                API = "Excavator"
                                Port = $Miner_Port
                                URI = $Uri
                                PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                                PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                                MSIAprofile = if ( $nhBaseAlgorithm -eq "neoscrypt" ) { 3 } else { 2 }
                                ShowMinerWindow = $True
                            }
                        }
                    }
                }
            }
        }
        catch {
        }
    }
}