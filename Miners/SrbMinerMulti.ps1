using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=5190081.0"
$Port = "349{0:d2}"
$DevFee = 0.85
$Version = "1.0.1"

if ($IsLinux) {
    $Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.1-srbminermulti/SRBMiner-Multi-1-0-1-Linux.tar.xz"
} else {
    $Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.1-srbminermulti/SRBMiner-Multi-1-0-1-win64.zip"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No AMD nor CPU present in system

$Commands = [PSCustomObject[]]@(

    #CPU only mining

    #[PSCustomObject]@{MainAlgorithm = "astrobwt"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Astrobwt/DERO
    [PSCustomObject]@{MainAlgorithm = "balloon_zentoshi" ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #BalloonZentoshi
    [PSCustomObject]@{MainAlgorithm = "cosa"             ;              Params = ""; Fee = 2.00;               Vendor = @("CPU")} #Cosanta/COSA
    [PSCustomObject]@{MainAlgorithm = "cpupower"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "ghostrider"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU"); FaultTolerance = 0.9; ExtendInterval = 3; ExcludePoolName = "C3pool|MoneroOcean"} #Ghostrider/RPT
    [PSCustomObject]@{MainAlgorithm = "heavyhash"        ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "minotaur"         ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #Minotaur/RING Coin
    [PSCustomObject]@{MainAlgorithm = "minotaurx"        ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Minotaurx/LCC
    [PSCustomObject]@{MainAlgorithm = "panthera"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Panthera
    [PSCustomObject]@{MainAlgorithm = "randomarq"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomArq
    [PSCustomObject]@{MainAlgorithm = "randomepic"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomEPIC
    [PSCustomObject]@{MainAlgorithm = "randomgrft"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomGRFT
    [PSCustomObject]@{MainAlgorithm = "randomhash2"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomHash2/PASC
    [PSCustomObject]@{MainAlgorithm = "randomkeva"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomKEVA
    [PSCustomObject]@{MainAlgorithm = "randoml"          ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomL/LOZZ
    [PSCustomObject]@{MainAlgorithm = "randomsfx"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomSFX
    [PSCustomObject]@{MainAlgorithm = "randomwow"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.00; Vendor = @("CPU")} #RandomWow
    [PSCustomObject]@{MainAlgorithm = "randomx"          ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomX
    [PSCustomObject]@{MainAlgorithm = "randomxl"         ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomXL
    [PSCustomObject]@{MainAlgorithm = "randomyada"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomYada
    [PSCustomObject]@{MainAlgorithm = "scryptn2"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #scyptn2/Verium
    [PSCustomObject]@{MainAlgorithm = "xdag"             ;              Params = ""; Fee = 1.00;               Vendor = @("CPU")} #Xdag/Daggercoin
    [PSCustomObject]@{MainAlgorithm = "yespower"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespower
    [PSCustomObject]@{MainAlgorithm = "yespower2b"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespower2b
    [PSCustomObject]@{MainAlgorithm = "yespowerarwn"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerARWN/ArowanaCoin
    [PSCustomObject]@{MainAlgorithm = "yespoweric"       ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespoweric
    [PSCustomObject]@{MainAlgorithm = "yespoweriots"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespoweriots
    [PSCustomObject]@{MainAlgorithm = "yespoweritc"      ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespoweritc
    [PSCustomObject]@{MainAlgorithm = "yespowerlitb"     ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespowerlitb
    [PSCustomObject]@{MainAlgorithm = "yespowerltncg"    ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerltncg
    [PSCustomObject]@{MainAlgorithm = "yespowermgpc"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #YespowerMGPC/MagPieCoin
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerr16
    [PSCustomObject]@{MainAlgorithm = "yespowerres"      ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespowerRES
    [PSCustomObject]@{MainAlgorithm = "yespowersugar"    ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowersugar
    [PSCustomObject]@{MainAlgorithm = "yespowertide"     ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowertide
    [PSCustomObject]@{MainAlgorithm = "yespowerurx"      ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespowerurx

    #CPU and GPU mining

    [PSCustomObject]@{MainAlgorithm = "0x10"             ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Chainox/CHOX
    [PSCustomObject]@{MainAlgorithm = "argon2d_16000"    ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2d16000/ADOT
    [PSCustomObject]@{MainAlgorithm = "argon2d_dynamic"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Dyn
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Chukwa
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa2" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Chukwa2
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","CPU")} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "blake2b"          ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD"); CoinSymbols = @("TNET")} #blake2b
    #[PSCustomObject]@{MainAlgorithm = "blake2s"         ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD","CPU")} #blake2s
    [PSCustomObject]@{MainAlgorithm = "blake3_alephium"  ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU")} #Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "circcash"         ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Circcash/CIRC
    [PSCustomObject]@{MainAlgorithm = "cryptonight_ccx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightCCX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_gpu"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cryptonight_talleo";             Params = ""; Fee = 0.00;               Vendor = @("AMD","CPU")} #CryptonightTalleo
    [PSCustomObject]@{MainAlgorithm = "cryptonight_turtle";             Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightTurtle
    [PSCustomObject]@{MainAlgorithm = "cryptonight_upx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightUPX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_xhv"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightXHV
    [PSCustomObject]@{MainAlgorithm = "curvehash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Curvehash
    [PSCustomObject]@{MainAlgorithm = "dynamo"           ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","CPU"); ExcludeYiimp = $true} #Dynamo/DYNAMO
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); ExcludePoolName="Nicehash"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD"); ExcludePoolName="Nicehash"; Algorithm = "ethash"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "firepow"          ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #FiroPow/FIRO
    [PSCustomObject]@{MainAlgorithm = "frkhash"          ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Frkhash/EXP
    [PSCustomObject]@{MainAlgorithm = "heavyhash"        ;              Params = ""; Fee = 1.00;               Vendor = @("AMD")} #HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "k12"              ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD","CPU")} #kangaroo12/AEON from 2019-10-25
    [PSCustomObject]@{MainAlgorithm = "kaspa"            ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","CPU")} #Kaspa/KAS
    [PSCustomObject]@{MainAlgorithm = "kawpow"           ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "keccak"           ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #keccak
    [PSCustomObject]@{MainAlgorithm = "lyra2v2_webchain" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Mintme.com/MINTME
    [PSCustomObject]@{MainAlgorithm = "progpow_epic"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #ProgPowEPIC/EPIC
    [PSCustomObject]@{MainAlgorithm = "progpow_sero"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #ProgPowSERO/SERO
    [PSCustomObject]@{MainAlgorithm = "progpow_veil"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #ProgPowVEIL/VEIL
    [PSCustomObject]@{MainAlgorithm = "progpow_veriblock"; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #vProgPow/VBLK
    [PSCustomObject]@{MainAlgorithm = "progpow_zano"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU"); ExcludePoolName="Nicehash"} #ProgPowZANO/ZANO
    [PSCustomObject]@{MainAlgorithm = "sha3d"            ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #SHA3d/KCN,YCN
    [PSCustomObject]@{MainAlgorithm = "ubqhash"          ;              Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD")} #ubqhash
    [PSCustomObject]@{MainAlgorithm = "verthash"         ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","CPU")} #Verthash
    [PSCustomObject]@{MainAlgorithm = "verushash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Verushash
    [PSCustomObject]@{MainAlgorithm = "yescrypt"         ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"      ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #yescryptr16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"      ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #yescryptr32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"       ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #yescryptr8

    #GPU Dualmining
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD"); SecondaryAlgorithm = "kaspa"} #Autolykos2/ERGO + Kaspa
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD"); SecondaryAlgorithm = "blake3_alephium"} #Autolykos2/ERGO + Alephium/ALPH

    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); SecondaryAlgorithm = "kaspa"; ExcludePoolName="Nicehash"} #ethash + Kaspa
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName="Nicehash"} #ethash + Alephium/ALPH

    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); SecondaryAlgorithm = "kaspa"; ExcludePoolName="Nicehash"} #ethash + Kaspa
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName="Nicehash"} #ethash + Alephium/ALPH

    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD"); SecondaryAlgorithm = "kaspa"; ExcludePoolName="Nicehash"; Algorithm = "ethash"} #ethash for low memory coins + Kaspa
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName="Nicehash"; Algorithm = "ethash"} #ethash for low memory coins + Alephium/ALPH
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

$InValidArchitecture = @("Pitcairn","Tahiti","Hawaii","Fiji","Tonga","gfx600","gfx601","gfx701","gfx702","gfx802","gfx803")

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

    $WatchdogParams = if ($Miner_Vendor -eq "AMD" -and $Session.Config.RebootOnGPUFailure -and $Session.Config.EnableRestartComputer) {" --reboot-script-gpu-watchdog '$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")'"}

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model -and ($Miner_Vendor -eq "CPU" -or $_.OpenCL.Architecture -notin $InValidArchitecture)})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and $Device.Count}).ForEach({
            $First = $true

            $MainAlgorithm = $_.MainAlgorithm
            $SecondAlgorithm = $_.SecondaryAlgorithm

            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $DeviceParams = ""

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

                $DeviceParams = "$(if ($CPUThreads){" --cpu-threads $CPUThreads"})$(if ($CPUAffinity -and ($CPUThreads -le 64)){" --cpu-affinity $CPUAffinity"})"
            }

            if ($MainAlgorithm -eq "verthash" -and $VerthashDatFile) {
                $DeviceParams = "  --verthash-dat-path '$($VerthashDatFile)'$($DeviceParams)"
            }

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
        
            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

            $All_MainAlgorithms = if ($Miner_Vendor -eq "CPU") {@($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")} else {@($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")}
            $All_SecondAlgorithms = if ($SecondAlgorithm_Norm_0) {if ($Miner_Vendor -eq "CPU") {@($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)")} else {@($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")}} else {$null}

		    foreach($MainAlgorithm_Norm in $All_MainAlgorithms) {
			    if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.CoinSymbols -or $Pools.$MainAlgorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.ExcludeYiimp -or -not $Session.PoolsConfigDefault."$($Pools.$MainAlgorithm_Norm.Name)".Yiimp)) {
                    if ($First) {
				        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				    	$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join '!'
                        $DeviceIntensity = ($Miner_Device | % {"0"}) -join '!'
                        $First = $false
                    }

                    $Miner_Protocol = Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                        "ethproxy"         {"--esm 0"}
                        "minerproxy"       {"--esm 1"}
						"ethstratumnh"     {""}
						default            {""}
					}

                    $Pool_Port_Index = if ($Miner_Vendor -eq "CPU") {"CPU"} else {"GPU"}
				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$MainAlgorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$MainAlgorithm_Norm.Port}

                    #--disable-extranonce-subscribe
                    #--extended-log --log-file Logs\$($_.MainAlgorithm)-$((get-date).toString("yyyyMMdd-HHmmss")).txt

                    $Miner_HR = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week
                    if ($_.MaxRejectedShareRatio) {
                        $Miner_HR *= 1-$Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Ratio_Live
                    }

                    if ($All_SecondAlgorithms) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {$Miner_Intensity = @(1,5,10)}

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -gt 0) {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                            }

	        			    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$SecondAlgorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$SecondAlgorithm_Norm.Port}

                            foreach($SecondAlgorithm_Norm in $All_SecondAlgorithms) {
			                    if ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.CoinSymbols -or $Pools.$SecondAlgorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.ExcludeYiimp -or -not $Session.PoolsConfigDefault."$($Pools.$SecondAlgorithm_Norm.Name)".Yiimp)) {
				                    [PSCustomObject]@{
					                    Name           = $Miner_Name_Dual
					                    DeviceName     = $Miner_Device.Name
					                    DeviceModel    = $Miner_Model
					                    Path           = $Path
                                        Arguments      = "--disable-cpu --api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$MainAlgorithm_Norm.Name).Worker) $(if ($Miner_Protocol) {"$($Miner_Protocol) "})--gpu-id $DeviceIDsAll $WatchdogParams --gpu-auto-tune 1 --gpu-dual-max-loss $($Intensity) --algorithm $(if ($_.Algorithm) {$_.Algorithm} else {$MainAlgorithm});$(if ($_.Algorithm2) {$_.Algorithm2} else {$SecondAlgorithm}) --gpu-intensity $DeviceIntensity;$DeviceIntensity --pool $($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) --pool $($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port) --wallet $($Pools.$MainAlgorithm_Norm.User) --wallet $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Worker -or $Pools.$SecondAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker);$($Pools.$SecondAlgorithm_Norm.Worker)"})$(if ($Pools.$MainAlgorithm_Norm.Pass -or $Pools.$SecondAlgorithm_Norm.Pass) {" --password $(if ($Pools.$MainAlgorithm_Norm.Pass) {$Pools.$MainAlgorithm_Norm.Pass -replace "([;!])","#`$1"} else {"x"}) --password $(if ($Pools.$SecondAlgorithm_Norm.Pass) {$Pools.$SecondAlgorithm_Norm.Pass -replace "([;!])","#`$1"} else {"x"})"}) --tls $(if ($Pools.$MainAlgorithm_Norm.SSL) {"true"} else {"false"}) --tls $(if ($Pools.$SecondAlgorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$MainAlgorithm_Norm.Host -match 'NiceHash') {"true"} else {"false"}) --nicehash $(if ($Pools.$SecondAlgorithm_Norm.Host -match 'NiceHash') {"true"} else {"false"}) --keepalive --retry-time 10 --disable-startup-monitor $($_.Params)"
					                    HashRates      = [PSCustomObject]@{
                                                            $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                            $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                        }
					                    API            = "SrbMinerMulti"
					                    Port           = $Miner_Port
					                    Uri            = $Uri
                                        FaultTolerance = $_.FaultTolerance
					                    ExtendInterval = if ($_.ExtendInterval) {$_.ExtendInterval} elseif ($Miner_Vendor -eq "CPU") {2} else {$null}
                                        MaxRejectedShareRatio = if ($_.MaxRejectedShareRatio) {$_.MaxRejectedShareRatio} else {$null}
                                        Penalty        = 0
					                    DevFee         = [PSCustomObject]@{
								                            ($MainAlgorithm_Norm) = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
								                            ($SecondAlgorithm_Norm) = 0
                                                          }
                                        ManualUri      = $ManualUri
					                    EnvVars        = if ($Miner_Vendor -eq "AMD" -and $IsLinux) {@("GPU_MAX_WORKGROUP_SIZE=1024")} else {$null}
                                        Version        = $Version
                                        PowerDraw      = 0
                                        BaseName       = $Name
                                        BaseAlgorithm  = $MainAlgorithm_Norm_0
                                        Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        SetLDLIBRARYPATH = $false
                                        ListDevices    = "--list-devices"
                                        ExcludePoolName = $_.ExcludePoolName
				                    }
                                }
                            }
                        }

                    } else {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--algorithm $(if ($_.Algorithm) {$_.Algorithm} else {$MainAlgorithm}) --api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$MainAlgorithm_Norm.Name).Worker) $(if ($Miner_Protocol) {"$($Miner_Protocol) "})$(if ($Miner_Vendor -eq "CPU") {"--disable-gpu$DeviceParams"} else {"--gpu-id $DeviceIDsAll --gpu-intensity $DeviceIntensity --disable-cpu $WatchdogParams"}) --pool $($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) --wallet $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --password $($Pools.$MainAlgorithm_Norm.Pass -replace "([;!])","#`$1")"}) --tls $(if ($Pools.$MainAlgorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$MainAlgorithm_Norm.Host -match 'NiceHash') {"true"} else {"false"}) --keepalive --retry-time 10 --disable-startup-monitor $($_.Params)" # --disable-worker-watchdog
					        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Miner_HR}
					        API            = "SrbMinerMulti"
					        Port           = $Miner_Port
					        Uri            = $Uri
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = if ($_.ExtendInterval) {$_.ExtendInterval} elseif ($Miner_Vendor -eq "CPU") {2} else {$null}
                            MaxRejectedShareRatio = if ($_.MaxRejectedShareRatio) {$_.MaxRejectedShareRatio} else {$null}
                            Penalty        = 0
					        DevFee         = $_.Fee
					        ManualUri      = $ManualUri
					        EnvVars        = if ($Miner_Vendor -eq "AMD" -and $IsLinux) {@("GPU_MAX_WORKGROUP_SIZE=1024")} else {$null}
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            SetLDLIBRARYPATH = $false
                            ListDevices    = "--list-devices"
                            ExcludePoolName = $_.ExcludePoolName
				        }
                    }
			    }
		    }
        })
    }
}
