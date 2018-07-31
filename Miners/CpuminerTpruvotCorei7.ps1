using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CPU-TPruvot\cpuminer-gw64-corei7.exe"
$Uri = "https://github.com/tpruvot/cpuminer-multi/releases/download/v1.3.1-multi/cpuminer-multi-rel1.3.1-x64.zip"
$Port = "512{0:d2}"

$Devices = $Devices.CPU
if (-not $Devices -or $Config.InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    # CPU Only algos 3/27/2018
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt
    #[PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""} #axiom

    # CPU & GPU - still profitable 27/03/2018
    [PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = ""} #CryptoNight
    [PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""} #shavite3

    #GPU - never profitable 27/03/2018
    #[PSCustomObject]@{MainAlgorithm = "bastion"; Params = ""} #bastion
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #blake
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #bmw
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = ""} #C11
    #[PSCustomObject]@{MainAlgorithm = "cryptolight"; Params = ""} #cryptolight
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""} #dmd-gr
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""} #Groestl
    #[PSCustomObject]@{MainAlgorithm = "jha"; Params = ""} #JHA
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""} #keccakc
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "lyra2re"; Params = ""} #lyra2re
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2RE2
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #NeoScrypt
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = ""} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""} #pentablake
    #[PSCustomObject]@{MainAlgorithm = "pluck"; Params = ""} #pluck
    #[PSCustomObject]@{MainAlgorithm = "scrypt:N"; Params = ""} #scrypt:N
    #[PSCustomObject]@{MainAlgorithm = "scryptjane:nf"; Params = ""} #scryptjane:nf
    #[PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""} #sha256d
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""} #Sib
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""} #skein2
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""} #Veltor
    #[PSCustomObject]@{MainAlgorithm = "x11"; Params = ""} #X11
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""} #X11evo
    #[PSCustomObject]@{MainAlgorithm = "x13"; Params = ""} #x13
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""} #x14
    #[PSCustomObject]@{MainAlgorithm = "x15"; Params = ""} #x15
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""} #x16r
    #[PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #zr5
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
                Arguments = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Ccminer"
                Port = $Miner_Port
                URI = $Uri
            }
        }
    }
}