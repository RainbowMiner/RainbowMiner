using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\AMD-Jceminer\jce_cn_gpu_miner64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.33b18-jceminer/jce_cn_gpu_miner.033b18.zip"
$Port = "321{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=3281187.0"
$DevFee = 0.9
$Version = "0.33-beta18"

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1";          Threads = 1; MinMemGb = 2; Params = "--variation 3"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/2";          Threads = 1; MinMemGb = 2; Params = "--variation 15"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xfh";        Threads = 1; MinMemGb = 2; Params = "--variation 18"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/mkt";        Threads = 1; MinMemGb = 2; Params = "--variation 9"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast";       Threads = 1; MinMemGb = 2; Params = "--variation 11"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast2";      Threads = 1; MinMemGb = 2; Params = "--variation 21"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto";        Threads = 1; MinMemGb = 2; Params = "--variation 10"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rwz";        Threads = 1; MinMemMb = 2; Params = "--variation 22"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao";        Threads = 1; MinMemGb = 2; Params = "--variation 8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        Threads = 1; MinMemGb = 2; Params = "--variation 7"}    
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     Threads = 1; MinMemGb = 1; Params = "--variation 2"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     Threads = 1; MinMemGb = 1; Params = "--variation 4"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  Threads = 1; MinMemGb = 1; Params = "--variation 6"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/dark";  Threads = 1; MinMemGb = 1; Params = "--variation 17"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/red";   Threads = 1; MinMemGb = 1; Params = "--variation 14"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/turtle";Threads = 1; MinMemGb = 1; Params = "--variation 20"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/upx";   Threads = 1; MinMemGb = 1; Params = "--variation 19"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      Threads = 1; MinMemGb = 4; Params = "--variation 5"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; Threads = 1; MinMemGb = 4; Params = "--variation 13"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  Threads = 1; MinMemGb = 4; Params = "--variation 12"}
)

#N=1 Original Cryptonight
#N=2 Original Cryptolight
#N=3 Cryptonight V7 fork of April-2018
#N=4 Cryptolight V7 fork of April-2018
#N=5 Cryptonight-Heavy
#N=6 Cryptolight-IPBC
#N=7 Cryptonight-XTL
#N=8 Cryptonight-Alloy
#N=9 Cryptonight-MKT/B2N
#N=10 Cryptonight-ArtoCash
#N=11 Cryptonight-Fast (Masari)
#N=12 Cryptonight-Haven
#N=13 Cryptonight-Bittube v2
#N=14 Cryptolight-Red
#N=15 Cryptonight V8 fork of Oct-2018
#N=16 Pool-managed Autoswitch
#N=17 Cryptolight-Dark
#N=18 Cryptonight-Swap
#N=19 Cryptolight-Uplexa
#N=20 Cryptolight-Turtle v2
#N=21 Cryptonight-Stellite v8

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
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

$Model_Defaults = @(
    [PSCustomObject]@{model = "HD7950"; algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 464   ; minmemgb = 3},
    [PSCustomObject]@{model = "HD7990"; algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = @(208,224)  ; minmemgb = 1},
    [PSCustomObject]@{model = "HD7850"; algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 464   ; minmemgb = 2},
    [PSCustomObject]@{model = "HD7870"; algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 464   ; minmemgb = 2},
    [PSCustomObject]@{model = "RX550";  algogb = 2; worksize = 16; alpha = 64;  beta = 8;  multi_hash = 432   ; minmemgb = 2},
    [PSCustomObject]@{model = "RX560";  algogb = 2; worksize = 8;  alpha = 128; beta = 8;  multi_hash = 464   ; minmemgb = 2},
    [PSCustomObject]@{model = "RX570";  algogb = 2; worksize = 8;  alpha = 128; beta = 8;  multi_hash = 1008  ; minmemgb = 8},
    [PSCustomObject]@{model = "RX580";  algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 944   ; minmemgb = 4},
    [PSCustomObject]@{model = "GTX1070";  algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 944   ; minmemgb = 4},
    [PSCustomObject]@{model = "RX580";  algogb = 2; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 1696  ; minmemgb = 8},
    [PSCustomObject]@{model = "RX580";  algogb = 4; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 832   ; minmemgb = 8},
    [PSCustomObject]@{model = "VEGA56"; algogb = 4; worksize = 8;  alpha = 64;  beta = 16; multi_hash = 896   ; minmemgb = 8},
    [PSCustomObject]@{model = "VEGA64"; algogb = 2; worksize = 8;  alpha = 64;  beta = 16; multi_hash = 1920  ; minmemgb = 8},
    [PSCustomObject]@{model = "other";  algogb = 1; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = @(208,224)   ; minmemgb = 1}
    [PSCustomObject]@{model = "other";  algogb = 1; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 464   ; minmemgb = 2}
    [PSCustomObject]@{model = "other";  algogb = 1; worksize = 8;  alpha = 64;  beta = 8;  multi_hash = 944   ; minmemgb = 4}
)

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $DevFee = 0.9

    $Commands | ForEach-Object {        
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
				$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				$DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

				$Model_Configs = @()
				$Miner_Device | Foreach-Object {
					$Model_Default = $Model_Defaults | Where-Object {$_.name -eq $Miner_Model -and $_.minmemgb -le $_.OpenCL.GlobalMemsize -and $_.algogb -le $MinMemGb} | Select-Object -Last 1
					if (-not $Model_Default) {$Model_Default = $Model_Defaults | Where-Object {$_.name -eq "other" -and $_.minmemgb -le $_.OpenCL.GlobalMemsize -and $_.algogb -le $MinMemGb} | Select-Object -Last 1}
					if (-not $Model_Default) {$Model_Default = $Model_Defaults | Select-Object -First 1}
					$Model_Configs += [PSCustomObject]@{mode="GPU";worksize=$Model_Default.worksize;alpha=$Model_Default.alpha;beta=$Model_Default.beta;index=$_.Type_Vendor_Index;multi_hash=if ($Model_Default.multi_hash -is [array]) {$Model_Default.multi_hash[0]} else {$Model_Default.multi_hash}}
					$Model_Configs += [PSCustomObject]@{mode="GPU";worksize=$Model_Default.worksize;alpha=$Model_Default.alpha;beta=$Model_Default.beta;index=$_.Type_Vendor_Index;multi_hash=if ($Model_Default.multi_hash -is [array]) {$Model_Default.multi_hash[1]} else {$Model_Default.multi_hash}}
				}

				$Arguments = [PSCustomObject]@{
					Config = [PSCustomObject]@{gpu_threads_conf = $Model_Configs}
					Params = "-g $($DeviceIDsAll) --no-cpu --doublecheck --mport $($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --ssl"}) --stakjson --any $($_.Params)"
				}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Jceminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}