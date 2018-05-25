using module ..\Include.psm1

$Path = ".\Bin\Xevan-AMD\sgminer.exe"
$Uri = "https://github.com/LIMXTEC/Xevan-GPU-Miner/releases/download/1/sgminer-xevan-5.5.0-nicehash-1-windows-amd64.zip"

$Type = "AMD"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
    "xevan-mod" = " --intensity 15" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = $Type
        Path = $Path
        Arguments = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Xgminer"
        Port = 4028
        URI = $Uri
    }
}