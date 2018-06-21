using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Xevan75\ccminer.exe"
$Uri = "https://github.com/nemosminer/ccminer-xevan/releases/download/Alexis78xevan/ccminerAlexis78Xevan.7z"
$Port = "119{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = " -N 1 -i 21"}, #c11
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""}, #Keccak
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = " -N 1"}, #Lyra2RE2 (alexis78 is faster)
    [PSCustomObject]@{MainAlgorithm = "skein"; Params = " -N 1"}, #Skein
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = " -N 1"} #Xevan

    # ASIC - never profitable 12/05/2018
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""}, #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""}, #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""}, #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""}, #Lbry
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""}, #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""}, #Nist5
    #[PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""}, #Qubit
    #[PSCustomObject]@{MainAlgorithm = "quark"; Params = ""}, #Quark
    #[PSCustomObject]@{MainAlgorithm = "x12"; Params = ""}, #X12
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""} #X14
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.MainAlgorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
        }
    }
}