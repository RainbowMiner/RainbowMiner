using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-SpModX16\ccminer.exe"
$Uri = "https://github.com/sp-hash/suprminer/releases/download/spmod-git4a/raven_spmodgit4_fix.7z"

$Commands = [PSCustomObject]@{
    "x16r"  = " -N 10" #X16R RavenCoin
    #"x16s"  = " -N 10" #X16S PigeonCoin
}

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "x16r" = 4
    "x16s" = 4
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUlist "NVIDIA"

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-d $($DeviceIDsAll -join ',') -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Hour}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
        FaultTolerance = 0.5
    }
}