using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.1-cryptodredge/CryptoDredge_0.9.1_cuda_9.2_windows.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4807821"
$Port = "313{0:d2}"
$DevFee = 1.0
$Cuda = "9.2"

$Devices = $Devices.NVIDIA
if (-not $Devices -and -not $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeon"; Params = ""} #Cryptolightv7 / Aeon
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #Allium
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s, ASIC domain. no longer profitable
    [PSCustomObject]@{MainAlgorithm = "cnfast"; Params = ""} #CryptonightFast / Masari
    [PSCustomObject]@{MainAlgorithm = "cnhaven"; Params = ""} #Cryptonighthaven
    [PSCustomObject]@{MainAlgorithm = "cnheavy"; Params = ""} #Cryptonightheavy
    [PSCustomObject]@{MainAlgorithm = "cnv7"; Params = ""; ExtendInterval = 2} #CryptonightV7 / Monero
    [PSCustomObject]@{MainAlgorithm = "lbk3"; Params = ""} #LBK3
    [PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2Re2
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""} #Lyra2z
    #[PSCustomObject]@{MainAlgorithm = "masari"; Params = ""} #Cryptonightfast / Masari
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #Neoscrypt
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""} #PHI2
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "stellite"; Params = ""} #Stellite
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""; ExtendInterval = 2} #Tribus
)


$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.InfoOnly) {
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

if (-not (Confirm-Cuda $Cuda $Name)) {return}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--retry-pause 1 -b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --log log_$($Miner_Port).txt $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "CryptoDredge"
                Port = $Miner_Port
                Uri = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
                DevFee = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}