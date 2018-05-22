using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-NVIDIA\xmrig-nvidia.exe"
$Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.6.1/xmrig-nvidia-2.6.1-cuda9-win64.zip"

$Commands = [PSCustomObject]@{
    "cryptonightv7" = "" # --cuda-bfactor=12" #--cuda-launch=15x96 " #Cryptonight
	"cryptonight-lite" = "" #" --cuda-bfactor=12" #--cuda-launch=15x96 " #Cryptonight-lite
	"cryptonight-heavy" = "" #" --cuda-bfactor=12" #--cuda-launch=15x96 " #Cryptonight-heavy
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $xmrig_algo = if ( $_ -eq "cryptonightv7" ) {"cryptonight"} else {$_}
    [PSCustomObject]@{
        Type      = "NVIDIA"
        Path      = $Path
        Arguments = "--cuda-devices=$((Get-GPUlist "NVIDIA") -join ',') --api-port 3335 -a $($xmrig_algo) -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --keepalive --nicehash --donate-level=1$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API       = "XMRig"
        Port      = 3335
        URI       = $Uri
        DevFee    = 1.0
    }
}