using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Path = ".\Bin\Excavator1.4.4\excavator.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.4a-excavator/excavator_v1.4.4a_NVIDIA_Win64.zip"
$Port = "310{0:d2}"

if (-not $Devices.NVIDIA -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "daggerhashimoto"; Params = @(); Threads = 1} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = @(); Threads = 1} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = @(); Threads = 2} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = @(); Threads = 1} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Params = @(); Threads = 1} #Lyra2RE2
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = @(); Threads = 1} #NeoScrypt (fastest for all pools)

    # ASIC - never profitable 20/04/2018
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = @(); Threads = 1} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = @(); Threads = 1} #Cryptonight
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = @(); Threads = 1} #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = @(); Threads = 1} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = @(); Threads = 1} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = @(); Threads = 1} #Pascal
)
$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
$Devices.NVIDIA | Where-Object {$_.Model -eq $Devices.FullComboModels.NVIDIA} | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices.NVIDIA | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model

    $DeviceIDsAll = Get-GPUIDs $Miner_Device

    $Commands | ForEach-Object {
        try {        
            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
            $Threads = $_.Threads
            if (-not $Threads) {$Threads=1}

            $nh = ""
            if ($Algorithm_Norm -eq "Decred" -or $Algorithm_Norm -eq "Sia") { $nh = "NiceHash" }

            if ( -not (Test-Path (Split-Path $Path)) ) { New-Item (Split-Path $Path) -ItemType "directory" | Out-Null }

            if ( $Pools."$Algorithm_Norm$nh".Host) {
                $Miner_ConfigFileName = "$($Pools."$Algorithm_Norm$nh".Name)_$($Algorithm_Norm)_$($Pools."$Algorithm_Norm$nh".User)_$($Threads)_$(@($Miner_Device.Name | Sort-Object) -join '_').json"
                $res = @()
                $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$($_.MainAlgorithm)", "$([Net.DNS]::Resolve($Pools."$Algorithm_Norm$nh".Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools."$Algorithm_Norm$nh".Port)", "$($Pools."$Algorithm_Norm$nh".User):$($Pools."$Algorithm_Norm$nh".Pass)")})}
                foreach( $gpu in $DeviceIDsAll ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$gpu") + $_.Params}) * $Threads}}
                $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @("0")})}
                for( $worker_id=0; $worker_id -le 32; $worker_id++ ) { $res += [PSCustomObject]@{time = 13; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$($Miner_ConfigFileName)" -Force -ErrorAction Stop

                $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    Arguments = "-p $($Miner_Port) -c $($Miner_ConfigFileName) -na"
                    HashRates = [PSCustomObject]@{"$Algorithm_Norm$nh" = $Stats."$($Miner_Name)_$($Algorithm_Norm)$($nh)_HashRate".Week}
                    API = "Excavator"
                    Port = $Miner_Port
                    URI = $Uri
                    PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                    ShowMinerWindow = $True
                }
            }
        }
        catch {
        }
    }
}