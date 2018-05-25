using module ..\Include.psm1

$Path = ".\Bin\AMD-Bitcore\sgminer-x64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.6.1.9-sgminerbitcore/sgminer-bitcore-5.6.1.9.zip"

$Type = "AMD"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
    "timetravel10" = " --intensity 19" #Bitcore
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type       = $Type
        Path       = $Path
        Arguments  = "--api-listen -k $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --text-only --gpu-platform $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))"
        HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API        = "Xgminer"
        Port       = 4028
        URI        = $Uri
    }
}