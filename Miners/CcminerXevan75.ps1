using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Xevan75\ccminer.exe"
$Uri = "https://github.com/nemosminer/ccminer-xevan/releases/download/Alexis78xevan/ccminerAlexis78Xevan.7z"
$Port = "119{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #"c11" = " -N 1 -i 21" #c11
    #"keccak"    = "" #Keccak
    #"lyra2v2"   = " -N 1" #Lyra2RE2 (alexis78 is faster)
    "skein"     = " -N 1" #Skein
    "xevan"     = " -N 1" #Xevan
    
    # ASIC - never profitable 12/05/2018
    #"blake2s"   = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"decred"   = "" #Decred
    #"lbry"     = "" #Lbry
    #"myr-gr"   = "" #MyriadGroestl
    #"nist5"    = "" #Nist5
    #"qubit"    = "" #Qubit
    #"quark"    = "" #Quark
    #"x12"      = "" #X12
    #"x14"      = "" #X14
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

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
        }
    }
}