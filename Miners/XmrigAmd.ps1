using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-AMD\xmrig-amd.exe"
$Uri = "https://github.com/xmrig/xmrig-amd/releases/download/v2.6.1/xmrig-amd-2.6.1-win64.zip"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject]@{
    "cryptonightv7" = ""
    "cryptonight-lite" = ""
    "cryptonight-heavy" = ""    
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUIDs $Devices -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $xmrig_algo = if ( $_ -eq "cryptonightv7" ) {"cryptonight"} else {$_}
    [PSCustomObject]@{
        DeviceName= $Devices.Name
        Path      = $Path
        Arguments = "--cuda-devices=$($DeviceIDsAll) --api-port 3336 -a $($xmrig_algo) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --keepalive --nicehash --donate-level=1$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API       = "XMRig"
        Port      = 3336
        URI       = $Uri
        DevFee    = 1.0
    }
}