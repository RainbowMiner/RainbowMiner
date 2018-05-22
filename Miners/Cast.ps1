using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
$Uri = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_092.zip"

$Commands = [PSCustomObject]@{
    "cryptonightv7" = ""
    "cryptonight-lite" = ""
    "cryptonight-heavy" = "" 
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type      = "AMD"
        Path      = $Path
        Arguments = "--remoteaccess -S $($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass) --forcecompute --fastjobswitch -G $((Get-GPUlist "AMD") -join ',')"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API       = "Cast"
        Port      = 7777
        URI       = $Uri
        DevFee    = 1.5
    }
}