using module ..\Include.psm1

$Path = ".\Bin\AMD-NiceHash\sgminer.exe"
$Uri = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"
$Port = "400{0:d2}"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "groestlcoin"; Params = "--gpu-threads 2 --worksize 128 --intensity d"} #Groestl
    [PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    [PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Params = "--gpu-threads 2 --worksize 128 --intensity d"} #Lyra2RE2
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = "--gpu-threads 1 --worksize 64 --intensity 15"} #NeoScrypt
    [PSCustomObject]@{MainAlgorithm = "sibcoin-mod"; Params = ""} #Sib
    [PSCustomObject]@{MainAlgorithm = "skeincoin"; Params = "--gpu-threads 2 --worksize 256 --intensity d"} #Skein
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = "--worksize 4 --rawintensity 256"} #Yescrypt

    # ASIC - never profitable 23/05/2018
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = " --gpu-threads 1 --worksize 8 --rawintensity 896"} #CryptoNight
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "maxcoin"; Params = ""} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "myriadcoin-groestl"; Params = " --gpu-threads 2 --worksize 64 --intensity d"} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = ""} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = " --intensity d"} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','
    $Miner_PlatformId = $Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.MainAlgorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "--device $($DeviceIDsAll) --api-port $($Miner_Port) --api-listen -k $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --text-only --gpu-platform $($Miner_PlatformId) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "Xgminer"
            Port = $Miner_Port
            URI = $Uri
            DevFee = 1.0
        }
    }
}