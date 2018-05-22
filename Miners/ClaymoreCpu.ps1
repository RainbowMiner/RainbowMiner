using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-Claymore-Cpu\NsCpuCNMiner64.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0-claymorecpu/claymore_cryptonight_cpu_4.0.zip"

$Commands = [PSCustomObject]@{
    "cryptonight" = "" #CryptoNight
    "cryptonightv7" = "" #CryptoNightV7
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    if ( $_ -eq "cryptonight" ) {
        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = "-r -1 -mport 3333 -pow7 0 -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"            
            HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $(if (Get-GPUlist "NVIDIA" 3GB) { $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week } else { 0 })}
            API = "Claymore"
            Port = 3333
            URI = $Uri
        }
    } elseif ( $_ -eq "cryptonightv7" ) {
        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = "-r -1 -mport 3333 -pow7 1 -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"            
            HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $(if (Get-GPUlist "NVIDIA" 3GB) { $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week } else { 0 })}
            API = "Claymore"
            Port = 3333
            URI = $Uri
        }
    }
}