using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\CryptoNight-SRBMiner\srbminer-cn.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.6.8-srbminer/SRBMiner-CN-V1-6-8.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3167363.0"
$Port = "315{0:d2}"
$DevFee = 0.85

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit Config_[MinerName]-[Algorithm]-[Port].txt in the miner binary directory
    [PSCustomObject]@{MainAlgorithm = "alloy"     ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-Alloy 1 thread
    [PSCustomObject]@{MainAlgorithm = "artocash"  ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-ArtoCash 1 thread
    [PSCustomObject]@{MainAlgorithm = "b2n"       ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-B2N 1 thread
    [PSCustomObject]@{MainAlgorithm = "bittubev2" ; Threads = 1; MinMemGb = 4; Params = ""} # CryptoNight-BittypeV2 1 thread
    [PSCustomObject]@{MainAlgorithm = "fast"      ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-Fast (Masari) 1 thread
    [PSCustomObject]@{MainAlgorithm = "lite"      ; Threads = 1; MinMemGb = 1; Params = ""} # CryptoNight-Lite 1 thread
    [PSCustomObject]@{MainAlgorithm = "litev7"    ; Threads = 1; MinMemGb = 1; Params = ""} # CryptoNight-LiteV7 2 threads
    [PSCustomObject]@{MainAlgorithm = "haven"     ; Threads = 1; MinMemGb = 4; Params = ""} # CryptoNight-Haven 1 thread
    [PSCustomObject]@{MainAlgorithm = "heavy"     ; Threads = 1; MinMemGb = 4; Params = ""} # CryptoNight-Heavy 1 thread
    [PSCustomObject]@{MainAlgorithm = "italo"     ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-Italo 1 thread
    [PSCustomObject]@{MainAlgorithm = "marketcash"; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-MarketCash 1 thread
    [PSCustomObject]@{MainAlgorithm = "mox"       ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-Mox/Red 1 thread
    [PSCustomObject]@{MainAlgorithm = "normalv7"  ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNightV7 1 thread
    [PSCustomObject]@{MainAlgorithm = "normalv8"  ; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNightV8 1 thread
    [PSCustomObject]@{MainAlgorithm = "stellitev4"; Threads = 1; MinMemGb = 2; Params = ""} # CryptoNight-Stellite 1 thread
    [PSCustomObject]@{MainAlgorithm = "alloy"     ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Alloy 2 threads
    [PSCustomObject]@{MainAlgorithm = "artocash"  ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-ArtoCash 2 threads
    [PSCustomObject]@{MainAlgorithm = "b2n"       ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-B2N 2 threads
    [PSCustomObject]@{MainAlgorithm = "bittubev2" ; Threads = 2; MinMemGb = 4; Params = ""} # CryptoNight-BittypeV2 2 thread
    [PSCustomObject]@{MainAlgorithm = "fast"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Fast (Masari) 2 threads
    [PSCustomObject]@{MainAlgorithm = "lite"      ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-Lite 2 threads
    [PSCustomObject]@{MainAlgorithm = "litev7"    ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-LiteV7 2 threads
    [PSCustomObject]@{MainAlgorithm = "haven"     ; Threads = 2; MinMemGb = 4; Params = ""} # CryptoNight-Haven 2 threads
    [PSCustomObject]@{MainAlgorithm = "heavy"     ; Threads = 2; MinMemGb = 4; Params = ""} # CryptoNight-Heavy 2 threads
    [PSCustomObject]@{MainAlgorithm = "italo"     ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Italo 2 threads
    [PSCustomObject]@{MainAlgorithm = "marketcash"; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-MarketCash 2 threads
    [PSCustomObject]@{MainAlgorithm = "mox"       ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Mox/Red 2 thread
    [PSCustomObject]@{MainAlgorithm = "normalv7"  ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNightV7 2 thread
    [PSCustomObject]@{MainAlgorithm = "normalv8"  ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNightV8 2 thread
    [PSCustomObject]@{MainAlgorithm = "stellitev4"; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Stellite 2 threads
)
#- Cryptonight Lite [lite]
#- Cryptonight V7 [normalv7]
#- Cryptonight Lite V7 [litev7]
#- Cryptonight Heavy [heavy]
#- Cryptonight Haven [haven]
#- Cryptonight Fast [fast]
#- Cryptonight BitTubeV2 [bittubev2]
#- Cryptonight StelliteV4 [stellitev4]
#- Cryptonight ArtoCash [artocash]
#- Cryptonight Alloy [alloy]
#- Cryptonight B2N [b2n]
#- Cryptonight MarketCash [marketcash]
#- Cryptonight Italo [italo]
#- Cryptonight Red [mox]

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm = $_.MainAlgorithm
        $Algorithm_Norm = Get-Algorithm "cryptonight$($Algorithm)"
        $Threads = $_.Threads
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params
        
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)})

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
            $Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

            $Arguments = [PSCustomObject]@{
                    Config = [PSCustomObject]@{
                        cryptonight_type = $Algorithm
                        intensity        = 0
                        double_threads   = $false
                        timeout          = 10
                        retry_time       = 10
                        gpu_conf         = @($Miner_Device.Type_Vendor_Index | Foreach-Object {
                            [PSCustomObject]@{
                                "id"        = $_  
                                "intensity" = 0
                                "threads"   = [Int]$Threads
                                "platform"  = "OpenCL"
                                #"worksize"  = [Int]8
                            }
                        })
                    }
                    Pools = [PSCustomObject]@{
                        pools = @([PSCustomObject]@{
                            pool = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                            wallet = $($Pools.$Algorithm_Norm.User)
                            password = $($Pools.$Algorithm_Norm.Pass)
                            pool_use_tls = $($Pools.$Algorithm_Norm.SSL)
                            nicehash = $($Pools.$Algorithm_Norm.Name -eq 'NiceHash')
                        })
                    }
                    Params = "--apienable --apiport $($Miner_Port) --apirigname $($Session.Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker) --disablegpuwatchdog $($Params)".Trim()
            }

            [PSCustomObject]@{
                Name        = $Miner_Name
                DeviceName  = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path        = $Path
                Arguments   = $Arguments
                HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API         = "SrbMiner"
                Port        = $Miner_Port
                Uri         = $Uri
                DevFee      = $DevFee
                ManualUri   = $ManualUri
            }
        }
    }
}