using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-CPU\xmrig.exe"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.6.2/xmrig-2.6.2-msvc-win64.zip"

$Devices = $Devices.CPU

$Commands = [PSCustomObject]@{
    "cryptonightv7" = ""
    "cryptonight-lite" = ""
    "cryptonight-heavy" = ""    
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $xmrig_algo = if ( $_ -eq "cryptonightv7" ) {"cryptonight"} else {$_}
    [PSCustomObject]@{
        DeviceName= $Devices.Name
        Path      = $Path
        Arguments = "--api-port 3334 -a $($xmrig_algo) -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --keepalive --nicehash --donate-level=1$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API       = "XMRig"
        Port      = 3334
        URI       = $Uri
        DevFee    = 1.0
    }
}