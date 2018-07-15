using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-x16s\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.5-ccminerx16rx16s/ccminerx16rx16s64-bit.7z"
$Port = "117{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "phi"; Params = ""} #Phi
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "jha"; Params = ""} #Jha
    #[PSCustomObject]@{MainAlgorithm = "hsr"; Params = "-N 1"} #Hsr (Alexis78 is fastest)
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = ""} #Cryptonight
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""} #Groestl
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""} #hmq1725
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2RE2
    #[PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""} #Lyra2z
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #NeoScrypt
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = ""} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""} #Qubit
    #[PSCustomObject]@{MainAlgorithm = "scrypt"; Params = ""} #Scrypt
    #[PSCustomObject]@{MainAlgorithm = "sia"; Params = ""} #Sia
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""} #Sib
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "x11"; Params = ""} #X11
    #[PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""} #Veltor
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""} #X11evo
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} #X17
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-N 10"; ExtendInterval = 10; FaultTolerance = 0.5; HashrateDuration = "Day"} #X16r(stable, ccminerx16r faster)
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""} #X16s(CcminerPigencoin is faster)
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index -join ','

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm        

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
                API = "Ccminer"
                Port = $Miner_Port
                URI = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
            }
        }
    }
}