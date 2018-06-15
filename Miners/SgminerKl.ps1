using module ..\Include.psm1

$Path = ".\Bin\AMD-SgminerKl\sgminer.exe"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.5fix/sgminer-kl-1.0.5_fix-windows_x64.zip"
$ManualUri = "https://github.com/KL0nLutiy"
$Port = "402{0:d2}"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
  "aergo"     = " -X 256 -g 2" #Aergo
  "blake"     = "" #Blake
  "bmw"       = "" #Bmw
  "echo"      = "" #Echo
  "hamsi"     = "" #Hamsi
  "keccak"    = "" #Keccak
  "phi"       = " -X 256 -g 2 -w 256" # Phi
  "skein"     = "" #Skein
  "tribus"    = " -X 256 -g 2" #Tribus
  "whirlpool" = "" #Whirlpool
  "xevan"     = " -X 256 -g 2" #Xevan
  "x16s"      = " -X 256 -g 2" #X16S Pigeoncoin
  "x16r"      = " -X 256 -g 2" #X16R Ravencoin
  "x17"       = " -X 256 -g 2"
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
            Path       = $Path
            Arguments  = "--device $($DeviceIDsAll) --api-port $($Miner_Port) --api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $($Miner_PlatformId)"
            HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API        = "Xgminer"
            Port       = $Miner_Port
            URI        = $Uri
            DevFee     = 1.0
        }
    }
}