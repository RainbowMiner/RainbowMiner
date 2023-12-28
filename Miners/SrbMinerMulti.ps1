﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA nor CPU present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5190081.0"
$Port = "349{0:d2}"
$DevFee = 0.85
$Version = "2.4.3"
$Cuda = "11.7"

if ($IsLinux) {
    $Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.4.3-srbminermulti/SRBMiner-Multi-2-4-3-Linux.tar.xz"
} else {
    $Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.4.3-srbminermulti/SRBMiner-Multi-2-4-3-win64.zip"
}

$Commands = [PSCustomObject[]]@(

    #CPU only mining

    #[PSCustomObject]@{MainAlgorithm = "astrobwt"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Astrobwt/DERO
    #[PSCustomObject]@{MainAlgorithm = "balloon_zentoshi" ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #BalloonZentoshi
    #[PSCustomObject]@{MainAlgorithm = "cosa"             ;              Params = ""; Fee = 2.00;               Vendor = @("CPU")} #Cosanta/COSA
    [PSCustomObject]@{MainAlgorithm = "cpupower"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "ghostrider"       ;              Params = ""; Fee = 0.85;               Vendor = @("CPU"); FaultTolerance = 0.9; ExtendInterval = 3; ExcludePoolName = "C3pool|MoneroOcean"} #Ghostrider/RPT
    #[PSCustomObject]@{MainAlgorithm = "memehash_apepepow";              Params = ""; Fee = 2.00;               Vendor = @("CPU")} #MemeHash/APEPEPOW
    [PSCustomObject]@{MainAlgorithm = "mike"             ;              Params = ""; Fee = 0.85;               Vendor = @("CPU"); FaultTolerance = 8; ExtendInterval = 3} #Mike/VKAX
    [PSCustomObject]@{MainAlgorithm = "minotaur"         ;              Params = ""; Fee = 0.00;               Vendor = @("CPU")} #Minotaur/RING Coin
    [PSCustomObject]@{MainAlgorithm = "minotaurx"        ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Minotaurx/LCC
    [PSCustomObject]@{MainAlgorithm = "panthera"         ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #Panthera
    [PSCustomObject]@{MainAlgorithm = "randomarq"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomArq
    [PSCustomObject]@{MainAlgorithm = "randomepic"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomEPIC
    [PSCustomObject]@{MainAlgorithm = "randomgrft"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomGRFT
    [PSCustomObject]@{MainAlgorithm = "randomhash2"      ;              Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomHash2/PASC
    [PSCustomObject]@{MainAlgorithm = "randomkeva"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomKEVA
    [PSCustomObject]@{MainAlgorithm = "randoml"          ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomL/LOZZ
    [PSCustomObject]@{MainAlgorithm = "randomnevo"       ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomNEVO
    [PSCustomObject]@{MainAlgorithm = "randomsfx"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomSFX
    #[PSCustomObject]@{MainAlgorithm = "randomwow"        ;              Params = "--randomx-use-1gb-pages"; Fee = 0.00; Vendor = @("CPU")} #RandomWow
    [PSCustomObject]@{MainAlgorithm = "randomx"          ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomX
    #[PSCustomObject]@{MainAlgorithm = "randomxl"         ;              Params = "--randomx-use-1gb-pages"; Fee = 0.85; Vendor = @("CPU")} #RandomXL
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

    #[PSCustomObject]@{MainAlgorithm = "0x10"             ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Chainox/CHOX
    [PSCustomObject]@{MainAlgorithm = "argon2d_16000"    ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2d16000/ADOT
    [PSCustomObject]@{MainAlgorithm = "argon2d_dynamic"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Dyn
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Chukwa
    [PSCustomObject]@{MainAlgorithm = "argon2id_chukwa2" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Argon2Chukwa2
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","INTEL","NVIDIA"); ExcludePoolName="Nicehash"} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "blake2b"          ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD"); CoinSymbols = @("TNET")} #blake2b
    #[PSCustomObject]@{MainAlgorithm = "blake2s"         ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #blake2s
    [PSCustomObject]@{MainAlgorithm = "blake3_alephium"  ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","INTEL","NVIDIA")} #Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "blake3_ironfish"  ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","INTEL","NVIDIA")} #Ironfish/IRON
    #[PSCustomObject]@{MainAlgorithm = "circcash"         ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Circcash/CIRC
    [PSCustomObject]@{MainAlgorithm = "cryptonight_ccx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightCCX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_gpu"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","NVIDIA")} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cryptonight_talleo";             Params = ""; Fee = 0.00;               Vendor = @("AMD","CPU")} #CryptonightTalleo
    [PSCustomObject]@{MainAlgorithm = "cryptonight_turtle";             Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightTurtle
    [PSCustomObject]@{MainAlgorithm = "cryptonight_upx"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #CryptonightUPX
    [PSCustomObject]@{MainAlgorithm = "cryptonight_xhv"  ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU","NVIDIA")} #CryptonightXHV
    [PSCustomObject]@{MainAlgorithm = "curvehash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD")} #Curvehash
    [PSCustomObject]@{MainAlgorithm = "dynamo"           ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","CPU","NVIDIA"); ExcludeYiimp = $true} #Dynamo/DYNAMO
    #[PSCustomObject]@{MainAlgorithm = "dynex"            ;              Params = ""; Fee = 2.00;               Vendor = @("AMD","NVIDIA")} #DynexSolve/DNX removed 2.4.0
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA"); ExcludePoolName = "Gteh"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA"); ExcludePoolName = "Gteh"} #ethash
    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 1; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 4; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethashb3"         ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA")} #ethashb3/RTH
    [PSCustomObject]@{MainAlgorithm = "evrprogpow"       ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","NVIDIA")} #EvrProgPow/EVR
    [PSCustomObject]@{MainAlgorithm = "firopow"          ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","NVIDIA")} #FiroPow/FIRO
    #[PSCustomObject]@{MainAlgorithm = "frkhash"          ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #Frkhash/EXP
    [PSCustomObject]@{MainAlgorithm = "heavyhash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","INTEL","NVIDIA")} #HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "k12"              ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #kangaroo12/AEON from 2019-10-25
    [PSCustomObject]@{MainAlgorithm = "karlsenhash"      ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","INTEL","NVIDIA")} #KarlsenHash/
    [PSCustomObject]@{MainAlgorithm = "kaspa"            ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","INTEL","NVIDIA")} #kHeavyHash/KAS
    [PSCustomObject]@{MainAlgorithm = "kawpow"           ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","NVIDIA")} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "kawpow2g"         ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); Algorithm = "kawpow"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "kawpow3g"         ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); Algorithm = "kawpow"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "kawpow4g"         ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); Algorithm = "kawpow"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "kawpow5g"         ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); Algorithm = "kawpow"} #KawPow/RVN
    [PSCustomObject]@{MainAlgorithm = "keccak"           ;              Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #keccak
    [PSCustomObject]@{MainAlgorithm = "lyra2v2_webchain" ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","NVIDIA")} #Mintme.com/MINTME
    [PSCustomObject]@{MainAlgorithm = "memehash"         ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU","INTEL","NVIDIA")} #MemeHash/PEPEPOW
    [PSCustomObject]@{MainAlgorithm = "progpow_epic"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","NVIDIA")} #ProgPowEPIC/EPIC
    [PSCustomObject]@{MainAlgorithm = "progpow_sero"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","NVIDIA")} #ProgPowSERO/SERO
    [PSCustomObject]@{MainAlgorithm = "progpow_veil"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","NVIDIA")} #ProgPowVEIL/VEIL
    [PSCustomObject]@{MainAlgorithm = "progpow_veriblock"; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","NVIDIA")} #vProgPow/VBLK
    [PSCustomObject]@{MainAlgorithm = "progpow_zano"     ; DAG = $true; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","NVIDIA")} #ProgPowZANO/ZANO
    [PSCustomObject]@{MainAlgorithm = "pufferfish2bmb"   ;              Params = ""; Fee = 1.00;               Vendor = @("AMD","CPU")} #Pufferfishbmb/BMB
    [PSCustomObject]@{MainAlgorithm = "sha256dt";                       Params = ""; Fee = 0.85;               Vendor = @("AMD","INTEL","NVIDIA")} #SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "sha3d"            ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","INTEL","NVIDIA")} #SHA3d/KCN,YCN
    [PSCustomObject]@{MainAlgorithm = "sha512_256d_radiant";            Params = ""; Fee = 0.85;               Vendor = @("AMD","INTEL","NVIDIA")} #SHA512256d/RAD
    [PSCustomObject]@{MainAlgorithm = "ubqhash"          ;              Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA"); ExcludePoolName = "Gteh"} #ubqhash
    [PSCustomObject]@{MainAlgorithm = "verthash"         ;              Params = ""; Fee = 1.00;               Vendor = @("AMD")} #Verthash
    [PSCustomObject]@{MainAlgorithm = "verushash"        ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU","INTEL","NVIDIA"); ExcludePoolName="LuckPool"; FaultTolerance = 0.5; ExtendInterval = 2} #Verushash
    [PSCustomObject]@{MainAlgorithm = "yescrypt"         ;              Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU")} #yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"      ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #yescryptr16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"      ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #yescryptr32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"       ;              Params = ""; Fee = 0.85;               Vendor = @("AMD","CPU")} #yescryptr8

    #GPU Dualmining
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "heavyhash"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL"); SecondaryAlgorithm = "karlsenhash"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + KarlsenHash
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "kaspa"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "sha256dt"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "autolykos2"       ;              Params = ""; Fee = 1.50;               Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; ExcludePoolName="Nicehash"} #Autolykos2/ERGO + Radiant

    [PSCustomObject]@{MainAlgorithm = "dynex"            ;              Params = ""; Fee = 2.50;               Vendor = @("AMD","INTEL"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName="Nicehash"} #DynexSolve/DNX + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "dynex"            ;              Params = ""; Fee = 2.50;               Vendor = @("AMD","INTEL"); SecondaryAlgorithm = "blake3_ironfish"; ExcludePoolName="Nicehash"} #DynexSolve/DNX + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "dynex"            ;              Params = ""; Fee = 2.50;               Vendor = @("AMD","INTEL"); SecondaryAlgorithm = "kaspa"; ExcludePoolName="Nicehash"} #DynexSolve/DNX + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "dynex"            ;              Params = ""; Fee = 2.50;               Vendor = @("AMD","INTEL"); SecondaryAlgorithm = "sha256dt"; ExcludePoolName="Nicehash"} #DynexSolve/DNX + SHA256dt/NOVO 

    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName = "Gteh"} #etchash + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; ExcludePoolName = "Gteh"} #etchash + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; ExcludePoolName = "Gteh"} #etchash + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; ExcludePoolName = "Gteh"} #etchash + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; ExcludePoolName = "Gteh"} #etchash + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "etchash"          ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; ExcludePoolName = "Gteh"} #etchash + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName = "Gteh"} #ethash + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; ExcludePoolName = "Gteh"} #ethash + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; ExcludePoolName = "Gteh"} #ethash + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; ExcludePoolName = "Gteh"} #ethash + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; ExcludePoolName = "Gteh"} #ethash + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "ethash"           ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; ExcludePoolName = "Gteh"} #ethash + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 1; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 1; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 1; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 1; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "ethash2g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 1; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "ethash3g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "ethash4g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 4; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 4; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 4; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 4; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "ethash5g"         ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 4; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethashb3"         ; DAG = $true; Params = ""; Fee = 1.00; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; ExcludePoolName = "Gteh"} #ethashb3 + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethashb3"         ; DAG = $true; Params = ""; Fee = 1.00; MinMemGb = 3; Vendor = @("AMD","INTEL"); SecondaryAlgorithm = "karlsenhash"; ExcludePoolName = "Gteh"} #ethashb3 + KLS
    [PSCustomObject]@{MainAlgorithm = "ethashb3"         ; DAG = $true; Params = ""; Fee = 1.00; MinMemGb = 3; Vendor = @("AMD","INTEL","NVIDIA"); SecondaryAlgorithm = "sha256dt"; ExcludePoolName = "Gteh"} #ethashb3 + NOVO
    [PSCustomObject]@{MainAlgorithm = "ethashb3"         ; DAG = $true; Params = ""; Fee = 1.00; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; ExcludePoolName = "Gteh"} #ethashb3 + Radiant

    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_alephium"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "blake3_ironfish"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Ironfish/IRON
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "heavyhash"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + HeavyHash/OBTC
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 3; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha256dt"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"  ; DAG = $true; Params = ""; Fee = 0.65; MinMemGb = 2; Vendor = @("AMD","NVIDIA"); SecondaryAlgorithm = "sha512_256d_radiant"; Algorithm = "ethash"; ExcludePoolName = "Gteh"} #ethash for low memory coins + Radiant
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type = @("AMD","CPU","NVIDIA")
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

$ValidCompute_AMD    = @("RDNA3","RDNA2","RDNA1","GCN51","GCN50","GCN4")
$ValidCompute_NVIDIA = @("Pascal","Turing","Ampere","Ada","Hopper")

if (-not (Test-Path "$(Join-Path $Session.MainPath "Bin\ANY-SRBMinerMulti\Cache\verthash.dat")")) {
    $VerthashDatFile = if ($IsLinux) {"$env:HOME/.vertcoin/verthash.dat"} else {"$env:APPDATA\Vertcoin\verthash.dat"}
    if (-not (Test-Path $VerthashDatFile) -or (Get-Item $VerthashDatFile).length -lt 1.19GB) {
        $VerthashDatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
        if (-not (Test-Path $VerthashDatFile) -or (Get-Item $VerthashDatFile).length -lt 1.19GB) {
            $VerthashDatFile = $null
        }
    }
}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {

    $WatchdogParams = if ($Miner_Vendor -ne "CPU" -and $Session.Config.RebootOnGPUFailure -and $Session.Config.EnableRestartComputer -and $false) {" --reboot-script-gpu-watchdog '$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")'"}

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model -and (($Miner_Vendor -in @("CPU","INTEL","NVIDIA")) -or ($Miner_Vendor -eq "AMD" -and $_.OpenCL.DeviceCapability -in $ValidCompute_AMD))})

        $ZilParams    = ""

        if ($Miner_Vendor -ne "CPU" -and $Session.Config.Pools.CrazyPool.EnableSrbMinerMultiDual -and $Pools.ZilliqaCP) {
            if ($ZilWallet = $Pools.ZilliqaCP.Wallet) {
                            
                $ZilMiner_Protocol = Switch ($Pools.ZilliqaCP.EthMode) {
                    "ethproxy"         {" --zil-esm 0"}
                    "minerproxy"       {" --zil-esm 1"}
					"ethstratum"       {" --zil-esm 2"}
					"ethstratum1"      {" --zil-esm 2"}
                    "ethstratum2"      {" --zil-esm 2"}
					"ethstratumnh"     {" --zil-esm 2"}
					default            {""}
				}
                $ZilParams = " --zil-enable --zil-pool $($Pools.ZilliqaCP.Host):$($Pools.ZilliqaCP.Port) --zil-wallet $($Pools.ZilliqaCP.User)$($ZilMiner_Protocol)"
            }
        }       

        $Pool_Port_Index = if ($Miner_Vendor -eq "CPU") {"CPU"} else {"GPU"}

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and $Device.Count}).ForEach({
            $First = $true

            $MainAlgorithm = $_.MainAlgorithm
            $SecondAlgorithm = $_.SecondaryAlgorithm

            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $Compute = $_.Compute

            $DeviceParams = ""

            Switch ($Miner_Vendor) {
                "CPU" {
                    $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                    $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

                    $DeviceParams = " --disable-gpu$(if ($CPUThreads){" --cpu-threads $CPUThreads"})$(if ($CPUAffinity -and ($CPUThreads -le 64)){" --cpu-affinity $CPUAffinity"})$(if (($Device | Select-Object -First 1).Data.Threads -le $CPUThreads) {" --cpu-threads-priority 1"})"
                }
                "AMD" {
                    $DeviceParams = " --disable-cpu --disable-gpu-nvidia --disable-gpu-intel"
                }
                "INTEL" {
                    $DeviceParams = " --disable-cpu --disable-gpu-amd --disable-gpu-nvidia"
                }
                "NVIDIA" {
                    $DeviceParams = " --disable-cpu --disable-gpu-amd --disable-gpu-intel"
                }
            }

            if ($MainAlgorithm -eq "verthash" -and $VerthashDatFile) {
                $DeviceParams = " --verthash-dat-path '$($VerthashDatFile)'$($DeviceParams)"
            }

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
        
            $Miner_Device = $Device.Where({$Miner_Vendor -eq "CPU" -or ((-not $MinMemGB -or (Test-VRAM $_ $MinMemGB)) -and (-not $Compute -or $_.OpenCL.DeviceCapability -in $Compute))})

            $All_MainAlgorithms = if ($Miner_Vendor -eq "CPU") {@($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")} else {@($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")}
            $All_SecondAlgorithms = if ($SecondAlgorithm_Norm_0) {if ($Miner_Vendor -eq "CPU") {@($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)")} else {@($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")}} else {$null}

		    foreach($MainAlgorithm_Norm in $All_MainAlgorithms) {
			    if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.CoinSymbols -or $Pools.$MainAlgorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.ExcludeYiimp -or -not $Session.PoolsConfigDefault."$($Pools.$MainAlgorithm_Norm_0.Name)".Yiimp)) {
                    if ($First) {
				        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				    	$Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join ','
                        $DeviceIntensity = ($Miner_Device | % {"0"}) -join ','
                        $MallobParam = "$(if ($Pools.$MainAlgorithm_Norm.Mallob) {" --mallob-endpoint $($Pools.$MainAlgorithm_Norm.Mallob)"})"
                        $Miner_HR = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week
                        if ($_.MaxRejectedShareRatio) {
                            $Miner_HR *= 1-$Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Ratio_Live
                        }
                        $First = $false
                    }

                    $Miner_Protocol = Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                        "ethproxy"         {" --esm 0"}
                        "minerproxy"       {" --esm 1"}
                        "ethstratum"       {" --esm 2"}
                        "ethstratum1"      {" --esm 2"}
                        "ethstratum2"      {""}
						"ethstratumnh"     {" --esm 2"}
						default            {""}
					}

				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$MainAlgorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$MainAlgorithm_Norm.Port}

                    #--disable-extranonce-subscribe
                    #--extended-log --log-file Logs\$($_.MainAlgorithm)-$((get-date).toString("yyyyMMdd-HHmmss")).txt


                    if ($All_SecondAlgorithms) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {
                            if ($Miner_Vendor -eq "NVIDIA") {
                                $Miner_Intensity = @(0)
                            } else {
                                $Miner_Intensity = @(0)
                            }
                        }

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -gt 0) {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                            }

                            foreach($SecondAlgorithm_Norm in $All_SecondAlgorithms) {
			                    if ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.CoinSymbols -or $Pools.$SecondAlgorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.ExcludeYiimp -or -not $Session.PoolsConfigDefault."$($Pools.$SecondAlgorithm_Norm_0.Name)".Yiimp)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$SecondAlgorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$SecondAlgorithm_Norm.Port}

				                    [PSCustomObject]@{
					                    Name           = $Miner_Name_Dual
					                    DeviceName     = $Miner_Device.Name
					                    DeviceModel    = $Miner_Model
					                    Path           = $Path
                                        Arguments      = "--api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$MainAlgorithm_Norm.Name).Worker)$Miner_Protocol --gpu-id $DeviceIDsAll$DeviceParams$WatchdogParams$(if ($Miner_Vendor -ne "NVIDIA") {" --gpu-auto-tune 1"}) --gpu-dual-max-loss $($Intensity) --algorithm $(if ($_.Algorithm) {$_.Algorithm} else {$MainAlgorithm})$(if ($IsLinux) {"\"});$(if ($_.Algorithm2) {$_.Algorithm2} else {$SecondAlgorithm}) --pool $($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) --pool $($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port) --wallet $($Pools.$MainAlgorithm_Norm.User) --wallet $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.Password -eq "x" -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" --worker $($Pools.$MainAlgorithm_Norm.Worker);$($Pools.$SecondAlgorithm_Norm.Worker)"})$(if ($Pools.$MainAlgorithm_Norm.Pass -or $Pools.$SecondAlgorithm_Norm.Pass) {" --password $(if ($Pools.$MainAlgorithm_Norm.Pass) {$Pools.$MainAlgorithm_Norm.Pass -replace "([;!])","#`$1"} else {"x"}) --password $(if ($Pools.$SecondAlgorithm_Norm.Pass) {$Pools.$SecondAlgorithm_Norm.Pass -replace "([;!])","#`$1"} else {"x"})"}) --tls $(if ($Pools.$MainAlgorithm_Norm.SSL) {"true"} else {"false"}) --tls $(if ($Pools.$SecondAlgorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$MainAlgorithm_Norm.Host -match 'Gteh|NiceHash') {"true"} else {"false"}) --nicehash $(if ($Pools.$SecondAlgorithm_Norm.Host -match 'Gteh|NiceHash') {"true"} else {"false"})$($MallobParam)$($ZilParams) --keepalive --retry-time 10 --disable-startup-monitor $($_.Params)"
					                    HashRates      = [PSCustomObject]@{
                                                            $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                            $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                        }
					                    API            = "SrbMinerMulti"
					                    Port           = $Miner_Port
					                    Uri            = $Uri
                                        FaultTolerance = 0.7
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
                                        BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                        Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        SetLDLIBRARYPATH = $false
                                        ListDevices    = "--list-devices"
                                        ExcludePoolName = $_.ExcludePoolName
                                        ShowMinerWindow = $true
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
					        Arguments      = "--algorithm $(if ($_.Algorithm) {$_.Algorithm} else {$MainAlgorithm}) --api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$MainAlgorithm_Norm.Name).Worker)$Miner_Protocol $(if ($Miner_Vendor -ne "CPU") {"--gpu-id $DeviceIDsAll$WatchdogParams"})$DeviceParams --pool $($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) --wallet $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.Password -eq "x" -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --password $($Pools.$MainAlgorithm_Norm.Pass -replace "([;!])","#`$1")"}) --tls $(if ($Pools.$MainAlgorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$MainAlgorithm_Norm.Host -match 'Gteh|NiceHash') {"true"} else {"false"})$($MallobParam)$($ZilParams) --keepalive --retry-time 10 --disable-startup-monitor $($_.Params)" # --disable-worker-watchdog
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
