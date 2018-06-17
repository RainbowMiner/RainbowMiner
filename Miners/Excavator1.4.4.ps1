using module ..\Include.psm1

$Path = ".\Bin\Excavator1.4.4\excavator.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.4a-excavator/excavator_v1.4.4a_NVIDIA_Win64.zip"
$Port = "310{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #"daggerhashimoto" = @() #Ethash
    #"equihash" = @() #Equihash
    #"equihash:2" = @() #Equihash
    #"keccak" = @() #Keccak
    #"lyra2rev2" = @() #Lyra2RE2
    "neoscrypt" = @() #NeoScrypt (fastest for all pools)

    # ASIC - never profitable 20/04/2018
    #"blake2s" = @() #Blake2s
    #"cryptonight" = @() #Cryptonight
    #"decred" = @() #Decred
    #"lbry" = @() #Lbry
    #"nist5" = @() #Nist5
    #"pascal" = @() #Pascal
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
#    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
#    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
#    $Miner_Model = $_.Model

$Devices | Select-Object Vendor -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = "NVIDIA"

    $DeviceIDsAll = Get-GPUIDs $Miner_Device

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
        try {        
            $Algorithm_Norm = Get-Algorithm ($_ -split ":" | Select-Object -Index 0)
            $Threads = $_ -split ":" | Select-Object -Index 1
            if ( -not $Threads ) {$Threads=1}

            $nh = ""
            if ($Algorithm_Norm -eq "Decred" -or $Algorithm_Norm -eq "Sia") { $nh = "NiceHash" }

            if ( -not (Test-Path (Split-Path $Path)) ) { New-Item (Split-Path $Path) -ItemType "directory" | Out-Null }

            if ( $Pools."$Algorithm_Norm$nh".Host) {
                $Miner_ConfigFileName = "$($Pools."$Algorithm_Norm$nh".Name)_$($Algorithm_Norm)_$($Pools."$Algorithm_Norm$nh".User)_$($Threads)_$(@($Miner_Device.Name | Sort-Object) -join '_').json"
                $res = @()
                $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$_", "$([Net.DNS]::Resolve($Pools."$Algorithm_Norm$nh".Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools."$Algorithm_Norm$nh".Port)", "$($Pools."$Algorithm_Norm$nh".User):$($Pools."$Algorithm_Norm$nh".Pass)")})}
                foreach( $gpu in $DeviceIDsAll ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("0", "$gpu") + $Commands.$_}) * $Threads}}
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
                    MSIAprofile = if ( $_ -eq "neoscrypt" ) { 3 } else { 2 }
                    ShowMinerWindow = $True
                }
            }
        }
        catch {
        }
    }
}