using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\CPU-Jceminer\jce_cn_cpu_miner$($f = $Global:GlobalCPUInfo.Features; if($f.'64bit'){'64'}else{'32'}).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.33q-jceminer/jce_cn_cpu_miner.windows.033q.zip"
$Port = "320{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=3281187.0"
$DevFee = 1.5
$Version = "0.33q"

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "cryptonight/1";          Threads = 1; ScratchPadMb = 2; Params = "--variation 3"}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight/2";          Threads = 1; ScratchPadMb = 2; Params = "--variation 15"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xfh";        Threads = 1; ScratchPadMb = 2; Params = "--variation 18"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/mkt";        Threads = 1; ScratchPadMb = 2; Params = "--variation 9"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast";       Threads = 1; ScratchPadMb = 2; Params = "--variation 11"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast2";      Threads = 1; ScratchPadMb = 2; Params = "--variation 21"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto";        Threads = 1; ScratchPadMb = 2; Params = "--variation 10"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rwz";        Threads = 1; ScratchPadMb = 2; Params = "--variation 22"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao";        Threads = 1; ScratchPadMb = 2; Params = "--variation 8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        Threads = 1; ScratchPadMb = 2; Params = "--variation 7"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     Threads = 1; ScratchPadMb = 1; Params = "--variation 2"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     Threads = 1; ScratchPadMb = 1; Params = "--variation 4"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  Threads = 1; ScratchPadMb = 1; Params = "--variation 6"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/dark";  Threads = 1; ScratchPadMb = 1; Params = "--variation 17"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/red";   Threads = 1; ScratchPadMb = 1; Params = "--variation 14"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/turtle";Threads = 1; ScratchPadMb = 1; Params = "--variation 20"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/upx";   Threads = 1; ScratchPadMb = 1; Params = "--variation 19"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      Threads = 1; ScratchPadMb = 4; Params = "--variation 5"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; Threads = 1; ScratchPadMb = 4; Params = "--variation 13"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  Threads = 1; ScratchPadMb = 4; Params = "--variation 12"}
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
#N=22 Cryptonight-Waltz/Graft

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Model = $_.Model

    $Miner_Threads = @()
    if ($Session.Config.CPUMiningAffinity -ne '') {$Miner_Threads = ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity}
    if (-not $Miner_Threads) {$Miner_Threads = $Global:GlobalCPUInfo.RealCores}

    $DevFee = if($GLobal:GlobalCPUInfo.Features.aes -and $Global:GlobalCPUInfo.Features.'64bit'){1.5}else{3.0}

    $Commands | ForEach-Object {        
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
       
        $Arguments = [PSCustomObject]@{Params = "--low --mport $($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --ssl"}) --stakjson --any $($_.Params)"}

        if ($Session.Config.CPUMiningThreads) {
            $Arguments | Add-Member Config ([PSCustomObject]@{cpu_threads_conf = @($Miner_Threads | Foreach-Object {[PSCustomObject]@{cpu_architecture="auto";affine_to_cpu=$_;use_cache=$true;multi_hash=6}} | Select-Object)})
        } else {
            $Arguments.Params = "--auto $($Arguments.Params)"
        }

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
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