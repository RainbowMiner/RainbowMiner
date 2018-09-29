using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\Ethash-Ethminer\ethminer.exe"
$URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.16.0/ethminer-0.16.0-windows-amd64.zip"
$ManualUri = "https://github.com/ethereum-mining/ethminer/releases"
$Port = "301{0:d2}"
$DevFee = 0.0
$Cuda = "6.5"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; Params = @(); ExtendInterval = 2} #Ethash2GB
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; Params = @(); ExtendInterval = 2} #Ethash3GB
    [PSCustomObject]@{MainAlgorithm = "ethash"   ; MinMemGB = 4; Params = @(); ExtendInterval = 2} #Ethash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

$Session.Devices | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    switch($_.Vendor) {
        "NVIDIA" {$Miner_Deviceparams = "--cuda --cuda-devices"}
        "AMD" {$Miner_Deviceparams = "--opencl --opencl-platform $($Device | Select-Object -First 1 -ExpandProperty PlatformId) --opencl-devices"}
        Default {$Miner_Deviceparams = ""}
    }

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB
        $Miner_ExtendInterval = $_.ExtendInterval

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1Gb})) {            
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

            $Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-')  -replace "-+", "-"
            $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '

            $Miner_Protocol = $Pools.$Algorithm_Norm.Protocol
            if ($Pools.$Algorithm_Norm.Name -eq 'NiceHash') {$Miner_Protocol = $Miner_Protocol -replace "stratum","stratum2"}
        
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api-port $($Miner_Port) $($Miner_Deviceparams) $($DeviceIDsAll) -P $($Miner_Protocol)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Claymore"
                Port = $Miner_Port
                Uri = $Uri
                ManualUri = $ManualUri
                ExtendInterval = $Miner_ExtendInterval
            }
        }
    }
}
