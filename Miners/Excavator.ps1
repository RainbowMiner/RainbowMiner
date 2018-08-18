using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-Excavator\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.5.11a/excavator_v1.5.11a_Win64.zip"
$ManualUri = "https://github.com/nicehash/excavator/releases"
$Port = "31100"

if (-not $Devices.NVIDIA -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #1 Thread
    [PSCustomObject]@{Algorithm = "cryptonightV7"; Threads = 1; MinMemGB = 2; ExtendInterval = 1; Params = @()} #CryptonightV7
    #[PSCustomObject]@{Algorithm = "daggerhashimoto"; Threads = 1; MinMemGB = 4; ExtendInterval = 1; Params = @()} #Ethash
    [PSCustomObject]@{Algorithm = "equihash"; Threads = 1; MinMemGB = 2; ExtendInterval = 1; Params = @()} #Equihash
    #[PSCustomObject]@{Algorithm = "lyra2rev2"; Threads = 1; MinMemGB = 1; ExtendInterval = 1; Params = @()} #Lyra2RE2
    [PSCustomObject]@{Algorithm = "lyra2z"; Threads = 1; MinMemGB = 1; ExtendInterval = 1; Params = @()} #Lyra2z
    [PSCustomObject]@{Algorithm = "neoscrypt"; Threads = 1; MinMemGB = 2; ExtendInterval = 1; Params = @()} #NeoScrypt
    #[PSCustomObject]@{Algorithm = "x16r"; Threads = 1; MinMemGB = 2; ExtendInterval = 4; FaultTolerance = 0.5; Params = @()} #X16R
    #[PSCustomObject]@{Algorithm = "daggerhashimoto_decred"; Threads = 1; MinMemGB = 4; ExtendInterval = 2; Params = @()} #Dual mining
    #[PSCustomObject]@{Algorithm = "daggerhashimoto_pascal"; Threads = 1; MinMemGB = 4; ExtendInterval = 2; Params = @()} #Dual mining

    #2 Threads
    #[PSCustomObject]@{Algorithm = "cryptonightV7"; Threads = 2; MinMemGB = 2*6; ExtendInterval = 1; Params = @()} #CryptonightV7
    #[PSCustomObject]@{Algorithm = "daggerhashimoto"; Threads = 2; MinMemGB = 2*4; ExtendInterval = 1; Params = @()} #Ethash
    #[PSCustomObject]@{Algorithm = "equihash"; Threads = 2; MinMemGB = 2*2; ExtendInterval = 1; Params = @()} #Equihash
    #[PSCustomObject]@{Algorithm = "lyra2rev2"; Threads = 2; MinMemGB = 2*1; ExtendInterval = 1; Params = @()} #Lyra2RE2
    #[PSCustomObject]@{Algorithm = "lyra2z"; Threads = 2; MinMemGB = 2*1; ExtendInterval = 1; Params = @()} #Lyra2z
    #[PSCustomObject]@{Algorithm = "neoscrypt"; Threads = 2; MinMemGB = 2*2; ExtendInterval = 1; Params = @()} #NeoScrypt 2 threads crashes
    #[PSCustomObject]@{Algorithm = "x16r"; Threads = 2; MinMemGB = 2*6; ExtendInterval = 3; FaultTolerance = 0.5; Params = @()} #X16R 2 threads out-of memory
    #[PSCustomObject]@{Algorithm = "daggerhashimoto_decred"; Threads = 2; MinMemGB = 2*4; ExtendInterval = 2; Params = @()} #Dual mining
    #[PSCustomObject]@{Algorithm = "daggerhashimoto_pascal"; Threads = 2; MinMemGB = 2*4; ExtendInterval = 2; Params = @()} #Dual mining

    #ASIC mining only 2018/06/11
    #[PSCustomObject]@{Algorithm = "blake2s"; Threads = 1; MinMemGB = 1; ExtendInterval = 1; Params = @()} #Blake2s
    #[PSCustomObject]@{Algorithm = "decred"; Threads = 1; MinMemGB = 1; ExtendInterval = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "keccak"; Threads = 1; MinMemGB = 1; ExtendInterval = 1; Params = @()} #Pascal
    #[PSCustomObject]@{Algorithm = "pascal"; Threads = 1; MinMemGB = 1; ExtendInterval = 1; Params = @()} #Pascal
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Devices = $Devices.NVIDIA

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm = $_.Algorithm
        $MinMemGB = $_.MinMemGB
        $Main_Algorithm = $Algorithm -Split "_" | Select-Object -Index 0
        $Main_Algorithm_Norm = "$(Get-Algorithm $Main_Algorithm)-NHMP"
        $Secondary_Algorithm = $Algorithm -Split "_" | Select-Object -Index 1
        $Secondary_Algorithm_Norm = "$(Get-Algorithm $Secondary_Algorithm)-NHMP"
        $Threads = $_.Threads
        $Params = $_.Params
        $ExtendInterval = $_.ExtendInterval
        $FaultTolerance = $_.FaultTolerance
        
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1Gb)})

        if ($Pools.$Main_Algorithm_Norm.Name -eq "Nicehash" -and $Miner_Device) {
            if (-not $Secondary_Algorithm) {
                #Single algo mining
                $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                [PSCustomObject]@{
                    Name                 = $Miner_Name
                    DeviceName           = $Miner_Device.Name
                    DeviceModel          = $Miner_Model
                    Path                 = $Path
                    Arguments            = @(`
                        [PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)"; "$($Pools.$Main_Algorithm_Norm.User)")},`
                        [PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm")},`
                        [PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_Vendor_Index | ForEach-Object {@("alg-$($Algorithm)", "$_") + $Params} | Select-Object) * $Threads)}
                    )
                    HashRates            = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                    API                  = "Excavator"
                    Port                 = $Miner_Port
                    URI                  = $Uri
                    ShowMinerWindow      = $True
                    FaultTolerance       = $FaultTolerance
                    ExtendInterval       = $ExtendInterval
                    PrerequisitePath     = "$env:SystemRoot\System32\msvcr120.dll"
                    PrerequisiteURI      = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                    ManualUri            = $ManualUri
                }
            }
            else {
                #Dual algo mining
                if ($Pools.$Secondary_Algorithm_Norm.Host -and $Pools.$Secondary_Algorithm_Norm.Name -eq "Nicehash" ) {
                    $Miner_Name = (@($Name) + @($Threads) + @("$Secondary_Algorithm_Norm" -replace "-NHMP") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                    [PSCustomObject]@{
                        Name                 = $Miner_Name
                        DeviceName           = $Miner_Device.Name
                        DeviceModel          = $Miner_Model
                        Path                 = $Path
                        Arguments            = @(`
                            [PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)"; "$($Pools.$Main_Algorithm_Norm.User)")},`
                            [PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Main_Algorithm")};[PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$Secondary_Algorithm")},`
                            [PSCustomObject]@{id = 1; method = "workers.add"; params = @(@($Miner_Device.Type_Vendor_Index | ForEach-Object {@("alg-$($Algorithm)", "$_") + $Params} | Select-Object) * $Threads)}
                        )
                        HashRates            = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}
                        API                  = "Excavator"
                        Port                 = $Miner_Port
                        URI                  = $Uri
                        ShowMinerWindow      = $True
                        FaultTolerance       = $FaultTolerance
                        ExtendInterval       = $ExtendInterval
                        PrerequisitePath     = "$env:SystemRoot\System32\msvcr120.dll"
                        PrerequisiteURI      = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                        ManualUri            = $ManualUri
                    }
                }
            }
        }
    }
}