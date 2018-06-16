using module ..\Include.psm1

$Path = ".\Bin\Equihash-BMiner\bminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.0.0-bminer/bminer-v8.0.0-32928c5-amd64.zip"
$ManualURI = "https://bminer.me"
$Port = "307{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$DevFee = [PSCustomObject]@{
    "equihash" = 2.0
    "ethash" = 0.65
    "ethash;blake2s" = 1.3
    "ethash;blake14r" = 1.3
}

$Commands = [PSCustomObject]@{
    #"equihash" = "" #" -nofee" #Equihash (bminer v7.0.0 is faster)
    #"ethash" = "" #Ethash (ethminer is faster and no dev fee)
    #"ethash;blake2s" = "" #Ethash + Blake2s
    #"ethash;blake14r" = "" #Ethash + Decred
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Model_Norm = Get-DeviceModel $_
    $Miner_Name = (@($Name) + @($Miner_Model_Norm)) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

        $MinerAlgorithms = $_.Split(";")

        $MainAlgorithm = $MinerAlgorithms[0]
        $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

        if ( $MinerAlgorithms.Count -gt 1 ) {
            $SecondAlgorithm = $MinerAlgorithms[1]
            $SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
        } else {
            $SecondAlgorithm = $false
        }

        if ( $MainAlgorithm -eq "equihash" ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $(if ($Pools.$MainAlgorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -watchdog=false -no-runtime-info -gpucheck=0$($Commands.$_)"
                HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week)}
                API = "Bminer"
                Port = $Miner_Port
                DevFee = $DevFee.$_
                URI = $Uri
            }
        } elseif ( $MainAlgorithm -eq "ethash" ) {
            if ( -not $SecondAlgorithm ) {               
                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $(if ($Pools.$MainAlgorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                    HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week)}
                    API = "Bminer"
                    Port = $Miner_Port
                    DevFee = $DevFee.$_
                    URI = $Uri
                }
            } else {
                $Miner_Name = (@("$($Name)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondAlgorithm_Norm)") + @($Miner_Model_Norm)) -join '-'
                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $(if ($Pools.$MainAlgorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -uri2 $($SecondAlgorithm)://$([System.Web.HttpUtility]::UrlEncode($Pools.$SecondAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$SecondAlgorithm_Norm.Pass))@$($Pools.$SecondAlgorithm_Norm.Host):$($Pools.$SecondAlgorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                    HashRates = [PSCustomObject]@{
                        $MainAlgorithm_Norm = $($Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week)
                        $SecondAlgorithm_Norm = $($Stats."$($MinerName)_$($SecondAlgorithm_Norm)_HashRate".Week)
                    }
                    API = "Bminer"
                    Port = $Miner_Port
                    DevFee = [PSCustomObject]@{
                        ($MainAlgorithm_Norm) = $DevFee.$_
                        ($SecondAlgorithm_Norm) = 0
                    }
                    URI = $Uri
                }
            }
        }
    }
}