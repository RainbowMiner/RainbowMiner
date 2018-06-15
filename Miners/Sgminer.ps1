using module ..\Include.psm1

$Path = ".\Bin\AMD-NiceHash\sgminer.exe"
$Uri = "https://github.com/nicehash/sgminer/releases/download/5.6.1/sgminer-5.6.1-nicehash-51-windows-amd64.zip"
$Port = "400{0:d2}"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
    "groestlcoin"  = " --gpu-threads 2 --worksize 128 --intensity d" #Groestl
    "lbry"         = "" #Lbry
    "lyra2rev2"    = " --gpu-threads 2 --worksize 128 --intensity d" #Lyra2RE2
    "neoscrypt"    = " --gpu-threads 1 --worksize 64 --intensity 15" #NeoScrypt
    "sibcoin-mod"  = "" #Sib
    "skeincoin"    = " --gpu-threads 2 --worksize 256 --intensity d" #Skein
    "yescrypt"     = " --worksize 4 --rawintensity 256" #Yescrypt

    # ASIC - never profitable 23/05/2018    
    #"blake2s"     = "" #Blake2s
    #"blake"       = "" #Blakecoin
    #"cryptonight" = " --gpu-threads 1 --worksize 8 --rawintensity 896" #CryptoNight
    #"decred"      = "" #Decred
    #"lbry"        = "" #Lbry
    #"maxcoin"     = "" #Keccak
    #"myriadcoin-groestl" = " --gpu-threads 2 --worksize 64 --intensity d" #MyriadGroestl
    #"nist5"       = "" #Nist5
    #"pascal"      = "" #Pascal
    #"vanilla"     = " --intensity d" #BlakeVanilla
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @(Get-DeviceModel $_)) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','
    $Miner_PlatformId = $Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "--device $($DeviceIDsAll) --api-port $($Miner_Port) --api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $($Miner_PlatformId)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "Xgminer"
            Port = $Miner_Port
            URI = $Uri
        }
    }
}