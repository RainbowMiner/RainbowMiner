using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Sib\ccminer_x11gost.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-ccminersib/ccminer_x11gost_1.0.7z"
$Port = "108{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "blake2s"; Params = "-N 1"} #Blake2s
    [PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = "-N 1"} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = ""} #C11 (alexis78 is fastest)
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""} #Keccak (alexis78 is fastest)
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2RE2 (alexis78 is fastest)
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #NeoScrypt (excavator is fastest)
    [PSCustomObject]@{MainAlgorithm = "sib"; Params = "-N 1"} #Sib
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein (alexis78 is fastest)
    [PSCustomObject]@{MainAlgorithm = "x11evo"; Params = "-N 1"} #X11evo

    # ASIC - never profitable 12/05/2018
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""} #Sib
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
            FaultTolerance = $_.FaultTolerance
            ExtendInterval = $_.ExtendInterval
            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
            PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
        }
    }
}