using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\CryptoNight-SRBMiner\srbminer-cn.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.9.3-srbminer/SRBMiner-CN-V1-9-3.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3167363.0"
$Port = "315{0:d2}"
$DevFee = 0.85
$Version = "1.9.3"

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    # Note: For fine tuning directly edit Config_[MinerName]-[Algorithm]-[Port].txt in the miner binary directory
    [PSCustomObject]@{MainAlgorithm = "alloy"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Alloy 2 threads
    [PSCustomObject]@{MainAlgorithm = "artocash"   ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-ArtoCash 2 threads
    [PSCustomObject]@{MainAlgorithm = "b2n"        ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-B2N 2 threads
    [PSCustomObject]@{MainAlgorithm = "bittubev2"  ; Threads = 2; MinMemGb = 4; Params = ""} # CryptoNight-BittypeV2 2 thread
    [PSCustomObject]@{MainAlgorithm = "conceal"    ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Conceal 2 threads
    [PSCustomObject]@{MainAlgorithm = "dark"       ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-Dark (Cryo) thread
    [PSCustomObject]@{MainAlgorithm = "fast"       ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Fast 2 threads (upto #359.999)
    [PSCustomObject]@{MainAlgorithm = "fast2"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Fast2 (Masari) 2 threads (at #360.000)
    [PSCustomObject]@{MainAlgorithm = "fest"       ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Festival 2 thread
    [PSCustomObject]@{MainAlgorithm = "gpu"        ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-GPU (Ryo)
    [PSCustomObject]@{MainAlgorithm = "lite"       ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-Lite 2 threads
    [PSCustomObject]@{MainAlgorithm = "litev7"     ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-LiteV7 2 threads
    [PSCustomObject]@{MainAlgorithm = "haven"      ; Threads = 2; MinMemGb = 4; Params = ""} # CryptoNight-Haven 2 threads
    [PSCustomObject]@{MainAlgorithm = "heavy"      ; Threads = 2; MinMemGb = 4; Params = ""} # CryptoNight-Heavy 2 threads
    [PSCustomObject]@{MainAlgorithm = "hospital"   ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Hospital 2 thread
    [PSCustomObject]@{MainAlgorithm = "hycon"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Hycon 2 thread
    #[PSCustomObject]@{MainAlgorithm = "italo"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Italo 2 threads
    [PSCustomObject]@{MainAlgorithm = "marketcash" ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-MarketCash 2 threads
    [PSCustomObject]@{MainAlgorithm = "mox"        ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Mox/Red 2 thread
    [PSCustomObject]@{MainAlgorithm = "normalv4"   ; Threads = 2; MinMemGb = 2; Params = ""; ExtendInterval = 2} # CryptoNightV4/R 2 thread
    [PSCustomObject]@{MainAlgorithm = "normalv4_64"; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNightV4_64 2 thread
    [PSCustomObject]@{MainAlgorithm = "normalv7"   ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNightV7 2 thread
    [PSCustomObject]@{MainAlgorithm = "normalv8"   ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNightV8 2 thread
    [PSCustomObject]@{MainAlgorithm = "graft"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Graft/ReverseWaltz 2 thread
    [PSCustomObject]@{MainAlgorithm = "stellitev4" ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-StelliteV4 2 threads
    [PSCustomObject]@{MainAlgorithm = "stellitev8" ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-StelliteV8 2 threads
    #[PSCustomObject]@{MainAlgorithm = "swap"       ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Swap 2 thread
    [PSCustomObject]@{MainAlgorithm = "turtle"     ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Turtle 2 thread
    [PSCustomObject]@{MainAlgorithm = "upx"        ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-Uplexa 2 threads
    [PSCustomObject]@{MainAlgorithm = "upx2"       ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-Uplexa2 2 threads
    #[PSCustomObject]@{MainAlgorithm = "webchain"   ; Threads = 2; MinMemGb = 1; Params = ""} # CryptoNight-Webchain 2 threads    
    [PSCustomObject]@{MainAlgorithm = "xcash"      ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-HeavyX/Xcash 2 thread
    [PSCustomObject]@{MainAlgorithm = "zelerius"   ; Threads = 2; MinMemGb = 2; Params = ""} # CryptoNight-Zelerius thread
)

#- Cryptonight Alloy 			[alloy]
#- Cryptonight ArtoCash 		[artocash]
#- Cryptonight B2N 				[b2n]
#- Cryptonight BitTubeV2 		[bittubev2]
#- Cryptonight Conceal 			[conceal]
#- Cryptonight Dark 			[dark]
#- Cryptonight Fast 			[fast]
#- Cryptonight Fast2 			[fast2]
#- Cryptonight Fest 			[festival]
#- Cryptonight GPU 				[gpu]
#- Cryptonight Graft			[graft]
#- Cryptonight Haven 			[haven]
#- Cryptonight Heavy			[heavy]
#- Cryptonight Hospital 		[hospital]
#- Cryptonight Hycon 			[hycon]
#- Cryptonight Italo 			[italo]
#- Cryptonight Lite 			[lite]
#- Cryptonight Lite V7 			[litev7]
#- Cryptonight MarketCash 		[marketcash]
#- Cryptonight Red 				[mox]
#- Cryptonight 					[normal]
#- Cryptonight V4/R				[normalv4]
#- Cryptonight V4_64			[normalv4_64]
#- Cryptonight V7 				[normalv7]
#- Cryptonight V8 				[normalv8]
#- Cryptonight StelliteV4 		[stellitev4]
#- Cryptonight StelliteV5-V8-V9 [stellitev8]
#- Cryptonight Swap				[swap]
#- Cryptonight Turtle 			[turtle]
#- Cryptonight Upx 				[upx]
#- Cryptonight Upx2 			[upx2]
#- Cryptonight Webchain 		[webchain]
#- Cryptonight Wownero			[wownero]
#- Cryptonight Xcash			[xcash]
#- Cryptonight Zelerius 		[zelerius]

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
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm = $_.MainAlgorithm
        $Algorithm_Norm = Get-Algorithm "cryptonight$($Algorithm)"
        $Threads = $_.Threads
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params
        
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
				$Miner_Name = (@($Name) + @($Threads) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
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
								pool = "$($Pools.$Algorithm_Norm.Host):$($Pool_Port)"
								wallet = $($Pools.$Algorithm_Norm.User)
								password = "$($Pools.$Algorithm_Norm.Pass)"
								pool_use_tls = $($Pools.$Algorithm_Norm.SSL)
								nicehash = $($Pools.$Algorithm_Norm.Name -match 'NiceHash')
							})
						}
						Params = "--apienable --apiport $($Miner_Port) --apirigname $($Session.Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker) --disabletweaking --disablegpuwatchdog --enablecoinforking --maxnosharesent 120 $($Params)".Trim()
				}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "SrbMiner"
					Port           = $Miner_Port
					Uri            = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
					EnvVars        = @("GPU_MAX_SINGLE_ALLOC_PERCENT=100","GPU_FORCE_64BIT_PTR=0")
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}