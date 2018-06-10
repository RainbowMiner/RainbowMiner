using module ..\Include.psm1

$Path = ".\Bin\AMD-SgminerKl\sgminer.exe"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.5fix/sgminer-kl-1.0.5_fix-windows_x64.zip"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
    "Aergo" = " -X 256 -g 2" #aergo
	"Phi" = "  -X 256 -g 2 -w 256" #phi
	"Tribus" = "  -X 256 -g 2" #tribus
	"x16r" = "  -X 256 -g 2" #x16r
	"x16s" = "  -X 256 -g 2" #x16s
	"X17" = "  -X 256 -g 2" #x17
	"Xevan" = "  -X 256 -g 2" #xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUIDs $Devices -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        DeviceName= $Devices.Name
        Path       = $Path
        Arguments  = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $($Devices | select -Property Platformid -Unique -ExpandProperty PlatformId)"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Xgminer"
        Port       = 4028
        URI        = $Uri
    }
}