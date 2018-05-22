using module ..\Include.psm1

$Threads = 1

$Path = ".\Bin\Excavator\excavator.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.4a-excavator/excavator_v1.4.4a_NVIDIA_Win64.zip"

$Commands = [PSCustomObject]@{
    #"blake2s" = @() #Blake2s
    #"cryptonight" = @() #Cryptonight
    #"decred" = @() #Decred
    #"daggerhashimoto" = @() #Ethash
    #"equihash" = @() #Equihash
    #"keccak" = @() #Keccak
    #"lbry" = @() #Lbry
    #"lyra2rev2" = @() #Lyra2RE2
    "neoscrypt" = @() #NeoScrypt
    #"nist5" = @() #Nist5
    #"pascal" = @() #Pascal
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3456 + (2 * 10000)

$GPUlist = Get-GPUlist "NVIDIA"

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    try {

        $Algorithm_Norm = Get-Algorithm $_

        $nh = ""
        if ($Algorithm_Norm -eq "Decred" -or $Algorithm_Norm -eq "Sia") { $nh = "NiceHash" }

        if ( -not (Test-Path (Split-Path $Path)) ) { New-Item (Split-Path $Path) -ItemType "directory" | Out-Null }

        if ( $Pools."$Algorithm_Norm$nh".Host) {
            $res = @()
            $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$([Net.DNS]::Resolve($Pools."$Algorithm_Norm$nh".Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools."$Algorithm_Norm$nh".Port)", "$($Pools."$Algorithm_Norm$nh".User):$($Pools."$Algorithm_Norm$nh".Pass)")})}
            foreach( $gpu in $GPUlist ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$gpu") + $Commands.$_}) * $Threads}}
            $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})}
            for( $worker_id=0; $worker_id -le 32; $worker_id++ ) { $res += [PSCustomObject]@{time = 13; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

            $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Pools."$Algorithm_Norm$nh".Name)_$($Algorithm_Norm)_$($Pools."$Algorithm_Norm$nh".User)_$($Threads)_Nvidia.json" -Force -ErrorAction Stop

            [PSCustomObject]@{
                Type = "NVIDIA"
                Path = $Path
                Arguments = "-p $Port -c $($Pools."$Algorithm_Norm$nh".Name)_$($Algorithm_Norm)_$($Pools."$Algorithm_Norm$nh".User)_$($Threads)_Nvidia.json -na"
                HashRates = [PSCustomObject]@{"$Algorithm_Norm$nh" = $Stats."$($Name)_$($Algorithm_Norm)$($nh)_HashRate".Week}
                API = "Excavator"
                Port = $Port
                URI = $Uri
                PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                MSIAprofile = if ( $_ -eq "neoscrypt" ) { 3 } else { 2 }
                ShowMinerWindow = $True
            }
        }
    }
    catch {
    }
}