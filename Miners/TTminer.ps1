using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-TTminer\TT-Miner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.1.8-ttminer/TT-Miner-2.1.8.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"
$Port = "333{0:d2}"
$DevFee = 1.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "ETHASH2gb"  ; MinMemGB = 2; Params = ""} #Ethash2GB 
    #[PSCustomObject]@{MainAlgorithm = "ETHASH3gb"  ; MinMemGB = 3; Params = ""} #Ethash3GB 
    #[PSCustomObject]@{MainAlgorithm = "ETHASH"     ; MinMemGB = 4; Params = ""} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "MTP"        ; MinMemGB = 6; Params = ""} #MTP 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW2gb" ; MinMemGB = 2; Params = ""; ExtendInterval = 2} #ProgPoW2gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW3gb" ; MinMemGB = 3; Params = ""; ExtendInterval = 2} #ProgPoW3gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW"    ; MinMemGB = 4; Params = ""; ExtendInterval = 2} #ProgPoW 
    [PSCustomObject]@{MainAlgorithm = "UBQHASH"    ; MinMemGB = 2; Params = ""} #Ubqhash 
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$AlgorithmCuda = if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion "10.0") {"100"} else {"92"}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB        
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb)}
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name           = $Miner_Name
                DeviceName     = $Miner_Device.Name
                DeviceModel    = $Miner_Model
                Path           = $Path
                Arguments      = "--api-bind 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -A $($_.MainAlgorithm -replace "\d{1}gb$")-$AlgorithmCuda -P $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$($Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -RH $($_.Params)"
                HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API            = "Claymore"
                Port           = $Miner_Port
                DevFee         = $DevFee
                Uri            = $Uri
                ExtendInterval = $_.ExtendInterval
                ManualUri      = $ManualUri
            }
        }
    }
}