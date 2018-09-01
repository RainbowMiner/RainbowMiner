using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-Excavator1.4.4\excavator.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.4a-excavator/excavator_v1.4.4a_NVIDIA_Win64.zip"
$Port = "31000"

if (-not $Devices.NVIDIA -and -not $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto"; Threads = 1; Params = @()} #Ethash
#    [PSCustomObject]@{MainAlgorithm = "equihash"; Threads = 1; Params = @()} #Equihash
#    [PSCustomObject]@{MainAlgorithm = "lbry"; Threads = 1; Params = @()} #Lbry
#    [PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Threads = 1; Params = @()} #Lyra2RE2
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Threads = 1; Params = @()} #NeoScrypt
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto"; Threads = 2; Params = @()} #Ethash
#    [PSCustomObject]@{MainAlgorithm = "equihash"; Threads = 2; Params = @()} #Equihash
#    [PSCustomObject]@{MainAlgorithm = "lbry"; Threads = 2; Params = @()} #Lbry
#    [PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Threads = 2; Params = @()} #Lyra2RE2
#    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Threads = 2; Params = @()} #NeoScrypt
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto_decred"; SecondaryAlgorithm = "decred"; Threads = 1; Params = @()} #Dual mining 1 thread
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto_pascal"; SecondaryAlgorithm = "pascal"; Threads = 1; Params = @()} #Dual mining 1 thread
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto_sia"; SecondaryAlgorithm = "sia"; Threads = 1; Params = @()} #Dual mining 1 thread
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto_decred"; SecondaryAlgorithm = "decred"; Threads = 2; Params = @()} #Dual mining 2 threads
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto_pascal"; SecondaryAlgorithm = "pascal"; Threads = 2; Params = @()} #Dual mining 2 threads
#    [PSCustomObject]@{MainAlgorithm = "daggerhashimoto_sia"; SecondaryAlgorithm = "sia"; Threads = 2; Params = @()} #Dual mining 2 threads

    #ASIC mining only 2018/06/11
    #[PSCustomObject]@{MainAlgorithm = "decred"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "decred"; Threads = 2; Params = @()} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Threads = 2; Params = @()} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "sia"; Threads = 1; Params = @()} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "sia"; Threads = 2; Params = @()} #Pascal
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.InfoOnly) {
    [PSCustomObject]@{
        Vendor = @("NVIDIA")
        Name = $Name
        Path = $Path
        Uri = $Uri
        Port = $Port
        Commands = $Commands
    }
    return
}

$Devices = $Devices.NVIDIA

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Main_Algorithm = $_.MainAlgorithm
        $Main_Algorithm_Norm = Get-Algorithm $Main_Algorithm
        $Secondary_Algorithm = $_.SecondaryAlgorithm
        $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm
        $Threads = $_.Threads
        $Params = $_.Params

        if ($Pools.$Main_Algorithm_Norm.Host) {
            if (-not $Secondary_Algorithm) {
                #Single algo mining
                $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                [PSCustomObject]@{
                    Name             = $Miner_Name
                    DeviceName       = $Miner_Device.Name
                    DeviceModel      = $Miner_Model
                    Path             = $Path
                    Arguments        = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm", "$([Net.DNS]::Resolve($Pools.$Main_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Main_Algorithm_Norm.Port)", "$($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_Vendor_Index | ForEach-Object {@("alg-0", "$_")} | Select-Object) * $Threads) + $Params})
                    HashRates        = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                    API              = "Excavator144"
                    Port             = $Miner_Port
                    URI              = $Uri
                    ShowMinerWindow  = $True
                    PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                    ManualUri        = $ManualUri
                }
            }
            else {
                #Dual algo mining
                if ($Pools.$Secondary_Algorithm_Norm.Host ) {
                    $Miner_Name = (@($Name) + @("$Secondary_Algorithm_Norm") + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                    [PSCustomObject]@{
                        Name             = $Miner_Name
                        DeviceName       = $Miner_Device.Name
                        DeviceModel      = $Miner_Model
                        Path             = $Path
                        Arguments        = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$($Main_Algorithm)_$($Secondary_Algorithm)", "$([Net.DNS]::Resolve($Pools.$Main_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Main_Algorithm_Norm.Port)", "$($Pools.$Main_Algorithm_Norm.User):$($Pools.$Main_Algorithm_Norm.Pass)", "$([Net.DNS]::Resolve($Pools.$Secondary_Algorithm_Norm.Host).AddressList.IPAddressToString | Select-Object -First 1):$($Pools.$Secondary_Algorithm_Norm.Port)", "$($Pools.$Secondary_Algorithm_Norm.User):$($Pools.$Secondary_Algorithm_Norm.Pass)")}) + @([PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_Vendor_Index | ForEach-Object {@("alg-0", "$_")} | Select-Object) * $Threads) + $Params})
                        HashRates        = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                        API              = "Excavator144"
                        Port             = $Miner_Port
                        URI              = $Uri
                        ShowMinerWindow  = $True
                        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                        PrerequisiteURI  = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                        ManualUri        = $ManualUri
                    }
                }
            }
        }
    }
}