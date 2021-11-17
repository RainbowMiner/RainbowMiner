using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=5190081.0"
$Port = "349{0:d2}"
$DevFee = 0.85
$Version = "0.8.3"

if ($IsLinux) {
    $Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.8.3-srbminermulti/SRBMiner-Multi-0-8-3-Linux.tar.xz"
} else {
    $Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.8.3-srbminermulti/SRBMiner-Multi-0-8-3-win64.zip"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No AMD nor CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "astrobwt"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Astrobwt/DERO
    [PSCustomObject]@{MainAlgorithm = "balloon_zentoshi" ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #BalloonZentoshi
    [PSCustomObject]@{MainAlgorithm = "cosa"             ;              Params = ""; Fee = 2.00;               Vendor = @("CPU")} #Cosanta/COSA
    [PSCustomObject]@{MainAlgorithm = "cpupower"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "curvehash"        ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Curvehash
    [PSCustomObject]@{MainAlgorithm = "ghostrider"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU"); FaultTolerance = 0.9; ExtendInterval = 3} #Ghostrider/RPT
    [PSCustomObject]@{MainAlgorithm = "heavyhash"        ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "minotaur"         ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #Minotaur/RING Coin
    [PSCustomObject]@{MainAlgorithm = "minotaurx"        ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Minotaurx/LCC
    [PSCustomObject]@{MainAlgorithm = "panthera"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Panthera
    [PSCustomObject]@{MainAlgorithm = "randomarq"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomArq
    [PSCustomObject]@{MainAlgorithm = "randomepic"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomEPIC
    [PSCustomObject]@{MainAlgorithm = "randomgrft"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomGRFT
    [PSCustomObject]@{MainAlgorithm = "randomhash2"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomHash2/PASC
    [PSCustomObject]@{MainAlgorithm = "randomkeva"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomKEVA
    [PSCustomObject]@{MainAlgorithm = "randomsfx"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomSFX
    [PSCustomObject]@{MainAlgorithm = "randomwow"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.00; Vendor = @("CPU")} #RandomWow
    [PSCustomObject]@{MainAlgorithm = "randomx"          ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomX
    [PSCustomObject]@{MainAlgorithm = "randomxl"         ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomXL
    [PSCustomObject]@{MainAlgorithm = "randomyada"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomYada
    [PSCustomObject]@{MainAlgorithm = "rx2"              ;              Params = ""; Fee = 1.00;               Vendor = @("CPU")} #RX2/Luxcoin
    [PSCustomObject]@{MainAlgorithm = "scryptn2"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #scyptn2/Verium
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yescryptr16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yescryptr32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yescryptr8
    [PSCustomObject]@{MainAlgorithm = "yespower"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespower
    [PSCustomObject]@{MainAlgorithm = "yespower2b"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespower2b
    [PSCustomObject]@{MainAlgorithm = "yespowerarwn"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerARWN/ArowanaCoin
    [PSCustomObject]@{MainAlgorithm = "yespoweric"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespoweric
    [PSCustomObject]@{MainAlgorithm = "yespoweriots"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespoweriots
    [PSCustomObject]@{MainAlgorithm = "yespoweritc"      ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespoweritc
    [PSCustomObject]@{MainAlgorithm = "yespowerlitb"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerlitb
    [PSCustomObject]@{MainAlgorithm = "yespowerltncg"    ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerltncg
    [PSCustomObject]@{MainAlgorithm = "yespowermgpc"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #YespowerMGPC/MagPieCoin
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerr16
    [PSCustomObject]@{MainAlgorithm = "yespowerres"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerRES
    [PSCustomObject]@{MainAlgorithm = "yespowersugar"    ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowersugar
    [PSCustomObject]@{MainAlgorithm = "yespowertide"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowertide
    [PSCustomObject]@{MainAlgorithm = "yespowerurx"      ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespowerurx

    [PSCustomObject]@{MainAlgorithm = "argon2d_dynamic"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Dyn
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Chukwa
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa2" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Chukwa2
    [PSCustomObject]@{MainAlgorithm = "argon2id_ninja"   ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Ninja
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 2.00;               Vendor = @("AMD","CPU")} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "bl2bsha3"         ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD","CPU")} #blake2b+sha3/HNS
    [PSCustomObject]@{MainAlgorithm = "blake2b"          ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD"); CoinSymbols = @("TNET")} #blake2b
    #[PSCustomObject]@{MainAlgorithm = "blake2s"         ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD","CPU")} #blake2s
    [PSCustomObject]@{MainAlgorithm = "circcash"         ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Circcash/CIRC
    [PSCustomObject]@{MainAlgorithm = "cryptonight_cache";              Params = ""; Fee = 0.00;               Vendor = @("AMD","CPU")} #CryptonightCache
    [PSCustomObject]@{MainAlgorithm = "cryptonight_ccx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightCCX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_gpu"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cryptonight_heavyx";             Params = ""; Fee = 0.00;               Vendor = @("AMD","CPU")} #CryptonightHeavyX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_talleo";             Params = ""; Fee = 0.00;               Vendor = @("AMD","CPU")} #CryptonightTalleo
    [PSCustomObject]@{MainAlgorithm = "cryptonight_turtle";             Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightTurtle
    [PSCustomObject]@{MainAlgorithm = "cryptonight_upx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightUPX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_xhv"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightXHV
    [PSCustomObject]@{MainAlgorithm = "eaglesong"        ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #eaglesong
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = "--enable-ethash-leak-fix"; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="^Nicehash"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = "--enable-ethash-leak-fix"; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="^Nicehash"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = "--enable-ethash-leak-fix"; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="^Nicehash"; Algorithm = "ethash"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "firepow"          ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #FiroPow/FIRO
    [PSCustomObject]@{MainAlgorithm = "heavyhash"        ;              Params = ""; Fee = 1.00;               Vendor = @("AMD")} #HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "k12"              ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD","CPU")} #kangaroo12/AEON from 2019-10-25
    [PSCustomObject]@{MainAlgorithm = "kadena"           ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); CoinSymbols = @("KDA")} #blake2s / Kadena
    [PSCustomObject]@{MainAlgorithm = "kawpow"           ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "keccak"           ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #keccak
    [PSCustomObject]@{MainAlgorithm = "lyra2v2_webchain" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Mintme.com/MINTME
    [PSCustomObject]@{MainAlgorithm = "progpow_epic"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #ProgPowEPIC/EPIC
    [PSCustomObject]@{MainAlgorithm = "progpow_sero"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #ProgPowSERO/SERO
    [PSCustomObject]@{MainAlgorithm = "progpow_veil"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #ProgPowVEIL/VEIL
    [PSCustomObject]@{MainAlgorithm = "progpow_veriblock"; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #vProgPow/VBLK
    [PSCustomObject]@{MainAlgorithm = "progpow_zano"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="^Nicehash"} #ProgPowZANO/ZANO
    [PSCustomObject]@{MainAlgorithm = "phi5"             ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #PHI5/CBE
    [PSCustomObject]@{MainAlgorithm = "ubqhash"          ;              Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD")} #ubqhash
    [PSCustomObject]@{MainAlgorithm = "verthash"         ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","CPU")} #Verthash
    [PSCustomObject]@{MainAlgorithm = "verushash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Verushash
    [PSCustomObject]@{MainAlgorithm = "yescrypt"         ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #yescrypt
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type = @("AMD","CPU")
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

if (-not (Test-Path "$(Join-Path $Session.MainPath "Bin\ANY-SRBMinerMulti\Cache\verthash.dat")")) {
    $VerthashDatFile = if ($IsLinux) {"$env:HOME/.vertcoin/verthash.dat"} else {"$env:APPDATA\Vertcoin\verthash.dat"}
    if (-not (Test-Path $VerthashDatFile) -or (Get-Item $VerthashDatFile).length -lt 1.19GB) {
        $VerthashDatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
        if (-not (Test-Path $VerthashDatFile) -or (Get-Item $VerthashDatFile).length -lt 1.19GB) {
            $VerthashDatFile = $null
        }
    }
}

foreach ($Miner_Vendor in @("AMD","CPU")) {

    $WatchdogAction = if ($Miner_Vendor -eq "AMD" -and $Session.Config.RebootOnGPUFailure -and $Session.Config.$Session.Config.EnableRestartComputer) {" --reboot-script-gpu-watchdog '$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")'"}

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true
            $Algorithm = $_.MainAlgorithm
            $Algorithm_Norm_0 = Get-Algorithm $Algorithm

            $DeviceParams = ""

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

                $DeviceParams = "$(if ($CPUThreads){" --cpu-threads $CPUThreads"})$(if ($CPUAffinity -and ($CPUThreads -le 64)){" --cpu-affinity $CPUAffinity"})"
            }

            if ($Algorithm -eq "verthash" -and $VerthashDatFile) {
                $DeviceParams = "  --verthash-dat-path '$($VerthashDatFile)'$($DeviceParams)"
            }

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
        
            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

            $All_Algorithms = if ($Miner_Vendor -eq "CPU") {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")} else {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")}

		    foreach($Algorithm_Norm in $All_Algorithms) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                    if ($First) {
				        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				    	$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join '!'
                        $DeviceIntensity = ($Miner_Device | % {"0"}) -join '!'
                        $First = $false
                    }

                    $Miner_Protocol = Switch ($Pools.$Algorithm_Norm.EthMode) {
                        "ethproxy"         {"--esm 0"}
                        "minerproxy"       {"--esm 1"}
						"ethstratumnh"     {""}
						default            {""}
					}

                    $Pool_Port_Index = if ($Miner_Vendor -eq "CPU") {"CPU"} else {"GPU"}
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$Algorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$Algorithm_Norm.Port}

                    #--disable-extranonce-subscribe
                    #--extended-log --log-file Logs\$($_.MainAlgorithm)-$((get-date).toString("yyyyMMdd-HHmmss")).txt

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--algorithm $(if ($_.Algorithm) {$_.Algorithm} else {$Algorithm}) --api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker) $(if ($Miner_Protocol) {"$($Miner_Protocol) "})$(if ($Miner_Vendor -eq "CPU") {"--disable-gpu$DeviceParams"} else {"--gpu-id $DeviceIDsAll --gpu-intensity $DeviceIntensity --disable-cpu $WatchdogAction"}) --pool $($Pools.$Algorithm_Norm.Host):$($Pool_Port) --wallet $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Worker) {" --worker $($Pools.$Algorithm_Norm.Worker)"}) --password $($Pools.$Algorithm_Norm.Pass) --tls $(if ($Pools.$Algorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$Algorithm_Norm.Name -match 'NiceHash') {"true"} else {"false"}) --keepalive --retry-time 10 --disable-startup-monitor $($_.Params)" # --disable-worker-watchdog
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API            = "SrbMinerMulti"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = if ($_.ExtendInterval) {$_.ExtendInterval} elseif ($Miner_Vendor -eq "CPU") {2} else {$null}
                        Penalty        = 0
					    DevFee         = $_.Fee
					    ManualUri      = $ManualUri
					    EnvVars        = if ($Miner_Vendor -eq "AMD" -and $IsLinux) {@("GPU_MAX_WORKGROUP_SIZE=1024")} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        SetLDLIBRARYPATH = $false
                        ListDevices    = "--list-devices"
				    }
			    }
		    }
        })
    }
}
