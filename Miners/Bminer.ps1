using module ..\Include.psm1

$Path = ".\Bin\Equihash-BMiner\bminer.exe"
$URI = "https://www.bminercontent.com/releases/bminer-lite-v9.0.0-199ca8c-amd64.zip"
$ManualURI = "https://bminer.me"
$Port = "307{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "equihash"; SecondaryAlgorithm = ""; Params = ""; DevFee = 2.0} #" -nofee" #Equihash (bminer v7.0.0 is faster)
    #[PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = ""; Params = ""; DevFee = 0.65} #Ethash (ethminer is faster and no dev fee)
    #[PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "blake2s"; Params = ""; DevFee = 1.3} #Ethash + Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; SecondaryAlgorithm = "blake14r"; Params = ""; DevFee = 1.3} #Ethash + Decred
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | ForEach-Object {

        $MainAlgorithm = $_.MainAlgorithm
        $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

        $SecondAlgorithm = $_.SecondaryAlgorithm
        if ($SecondAlgorithm -ne '') {
            $SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
        }

        switch ($MainAlgorithm_Norm) {
            "Equihash" {$Stratum = if ($Pools.$MainAlgorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'}}
            "Ethash" {$Stratum = if ($Pools.$MainAlgorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'}}
        }

        if ($SecondAlgorithm -eq '') {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $($Stratum)://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -watchdog=false -no-runtime-info -gpucheck=0 $($_.Params)"
                HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week}
                API = "Bminer"
                Port = $Miner_Port
                URI = $Uri
                DevFee = $_.DevFee
            }
        } else {
            $Miner_Name = (@("$($Name)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondAlgorithm_Norm)") + @($Miner_Device.Name | Sort-Object)) -join '-'
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $($Stratum)://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -uri2 $($SecondAlgorithm)://$([System.Web.HttpUtility]::UrlEncode($Pools.$SecondAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$SecondAlgorithm_Norm.Pass))@$($Pools.$SecondAlgorithm_Norm.Host):$($Pools.$SecondAlgorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                HashRates = [PSCustomObject]@{
                    $MainAlgorithm_Norm = $($Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week)
                    $SecondAlgorithm_Norm = $($Stats."$($MinerName)_$($SecondAlgorithm_Norm)_HashRate".Week)
                }
                API = "Bminer"
                Port = $Miner_Port
                URI = $Uri
                DevFee = [PSCustomObject]@{
                    ($MainAlgorithm_Norm) = $_.DevFee
                    ($SecondAlgorithm_Norm) = 0
                }
            }
        }
    }
}