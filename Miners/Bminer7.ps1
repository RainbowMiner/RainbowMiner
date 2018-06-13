using module ..\Include.psm1

$Path = ".\Bin\Equihash-BMiner7\bminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v7.0.0-bminer/bminer-v7.0.0-9c7291b-amd64.zip"
$Port = "300{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$DevFee = [PSCustomObject]@{
    "equihash" = 2.0
    "ethash" = 0.65
}

$Commands = [PSCustomObject]@{
    "equihash" = "" #" -nofee" #Equihash (fastest)
    #"ethash" = "" #Ethash (ethminer is faster and no dev fee)
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @(Get-DeviceModel $_)) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        if ( $_ -eq "equihash" ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $(if ($Pools.$Algorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "Bminer"
                Port = $Miner_Port
                DevFee = $DevFee.$_
                URI = $Uri
            }
        } elseif ( $_ -eq "ethash" ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $(if ($Pools.$Algorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "Bminer"
                Port = $Miner_Port
                DevFee = $DevFee.$_
                URI = $Uri
            }
        }
    }
}