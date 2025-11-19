using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD/NVIDIA present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=4767892.0"
$Port = "330{0:d2}"
$DevFee = 2.0
$Version = "2.5e3"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-MiniZ\miniZ"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.5e3-miniz/miniZ_v2.5e3_linux-x64.tar.gz"
            Cuda = "8.0"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-MiniZ\miniZ.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.5e3-miniz/miniZ_v2.5e3_win-x64.7z"
            Cuda = "8.0"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                  MinMemGB = 5; Params = "--par=beam3";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = $DevFee;               Compute = @("RDNA2","RDNA3")} #BeamHash3 (BEAM)
    [PSCustomObject]@{MainAlgorithm = "EtcHash";       DAG = $true; MinMemGB = 2; Params = "--par=etchash --pers=etchash"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;    Compute = @("RDNA2","RDNA3")} #Etchash (ETC)
    [PSCustomObject]@{MainAlgorithm = "Ethash";        DAG = $true; MinMemGB = 2; Params = "--par=ethash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";      DAG = $true; MinMemGB = 1; Params = "--par=ethash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";      DAG = $true; MinMemGB = 2; Params = "--par=ethash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";      DAG = $true; MinMemGB = 3; Params = "--par=ethash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";      DAG = $true; MinMemGB = 4; Params = "--par=ethash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = "--par=ethash";   Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #Ethash (ETH) for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EthashB3";      DAG = $true; MinMemGB = 2; Params = "--par=ethashb3";   Vendor = @("AMD","NVIDIA"); ExtendInterval = 1; AutoPers = $false; Fee = 1.00;                  Compute = @("RDNA2","RDNA3")} #EthashB3 (RTH)
    #[PSCustomObject]@{MainAlgorithm = "Equihash16x5";               MinMemGB = 1; Params = "--par=96,5";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("RDNA2","RDNA3")} #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";               MinMemGB = 2; Params = "--par=144,5";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3")} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";               MinMemGB = 2; Params = "--par=192,7";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("RDNA2","RDNA3")} #Equihash 192,7 
    #[PSCustomObject]@{MainAlgorithm = "EquihashR25x4";              MinMemGB = 2; Params = "--par=125,4";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3")} #Equihash 125,4,0 (ZelCash)
    #[PSCustomObject]@{MainAlgorithm = "EquihashR25x5";              MinMemGB = 3; Params = "--par=150,5";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3")} #Equihash 150,5,0 (GRIMM)
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";               MinMemGB = 2; Params = "--par=210,9";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3")} #Equihash 210,9 (AION)
    [PSCustomObject]@{MainAlgorithm = "EvrProgPow";    DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=EVRMORE-PROGPOW"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #EvrProgPow (EVR)
    [PSCustomObject]@{MainAlgorithm = "FishHash";      DAG = $true; MinMemGB = 4; Params = "--par=fishhash";   Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.0;                   Compute = @("RDNA2","RDNA3")} #FishHash/IRON
    [PSCustomObject]@{MainAlgorithm = "KarlsenHashV2";              MinMemGB = 2; Params = "--par=karlsenhashv2";  Vendor = @("AMD","NVIDIA"); ExtendInterval = 1; AutoPers = $false; Fee = 0.95;                   Compute = @("RDNA2","RDNA3")} #KarlsenHashV2/KLS
    [PSCustomObject]@{MainAlgorithm = "KawPoW";        DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #KawPow (RVN)
    [PSCustomObject]@{MainAlgorithm = "KawPoW2g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #KawPow (RVN)
    [PSCustomObject]@{MainAlgorithm = "KawPoW3g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #KawPow (RVN)
    [PSCustomObject]@{MainAlgorithm = "KawPoW4g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #KawPow (RVN)
    [PSCustomObject]@{MainAlgorithm = "KawPoW5g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #KawPow (RVN)
    [PSCustomObject]@{MainAlgorithm = "kHeavyHash";                 MinMemGB = 2; Params = "--par=kaspa";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.8;                   Compute = @("RDNA2","RDNA3")} #kHeavyHash/KAS
    [PSCustomObject]@{MainAlgorithm = "Meraki";        DAG = $true; MinMemGB = 1; Params = "--par=meraki";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.0;                   Compute = @("RDNA2","RDNA3")} #Meraki/TLS
    [PSCustomObject]@{MainAlgorithm = "MeowPoW";       DAG = $true; MinMemGB = 2; Params = "--par=meowpow";    Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #MeowPow/MEWC
    [PSCustomObject]@{MainAlgorithm = "NxlHash";                    MinMemGB = 1; Params = "--par=nxlhash";    Vendor = @("AMD","NVIDIA"); ExtendInterval = 1; AutoPers = $false; Fee = 1.0;                   Compute = @("RDNA2","RDNA3")} #NxlHash/NXL
    [PSCustomObject]@{MainAlgorithm = "Octopus";       DAG = $true; MinMemGB = 2; Params = "--par=octopus";    Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = $DevFee;                     Compute = @()} #Octopus (CFX)
    [PSCustomObject]@{MainAlgorithm = "ProgPowSero";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=sero";  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #ProgPowSero (SERO)
    [PSCustomObject]@{MainAlgorithm = "ProgPowVeil";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=veil";  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #ProgPowVeil (VEIL)
    [PSCustomObject]@{MainAlgorithm = "ProgPowZ";      DAG = $true; MinMemGB = 2; Params = "--par=ProgPowZ --pers=zano"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #ProgPowZano (ZANO)
    #[PSCustomObject]@{MainAlgorithm = "PyrinHash";                  MinMemGB = 2; Params = "--par=pyrin";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 1; AutoPers = $false; Fee = 0.8;                   Compute = @("RDNA2","RDNA3")} #PyrinHash/PYI
    [PSCustomObject]@{MainAlgorithm = "UbqHash";       DAG = $true; MinMemGB = 2; Params = "--par=ubqhash";    Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3")} #UbqHash (UBQ)
    [PSCustomObject]@{MainAlgorithm = "vProgPow";      DAG = $true; MinMemGB = 2; Params = "--par=vProgPow --pers=VeriBlock"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;   Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"} #vProgPow (VBK)

    #[PSCustomObject]@{MainAlgorithm = "FiroPow";       DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=firo";  ExtendInterval = 3; AutoPers = $false; Fee = 1.00} #FiroPow (FIRO)

    #Dual Mining KarlsenHash

    ###[PSCustomObject]@{MainAlgorithm = "BeamHash3";                  MinMemGB = 5; Params = "--par=beam3";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = $DevFee;               Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #BeamHash3 (BEAM) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "EtcHash";       DAG = $true; MinMemGB = 2; Params = "--par=etchash --pers=etchash"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;      Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Etchash (ETC) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash";        DAG = $true; MinMemGB = 2; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Ethash (ETH) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash2g";      DAG = $true; MinMemGB = 1; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Ethash (ETH) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash3g";      DAG = $true; MinMemGB = 2; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Ethash (ETH) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash4g";      DAG = $true; MinMemGB = 3; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Ethash (ETH) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash5g";      DAG = $true; MinMemGB = 4; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Ethash (ETH) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = "--par=ethash";   Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Ethash (ETH) for low memory coins + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Equihash24x5";               MinMemGB = 2; Params = "--par=144,5";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Equihash 144,5 + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Equihash24x7";               MinMemGB = 2; Params = "--par=192,7";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Equihash 192,7  + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "EquihashR25x4";              MinMemGB = 2; Params = "--par=125,4";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Equihash 125,4,0 (ZelCash) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "EquihashR25x5";              MinMemGB = 3; Params = "--par=150,5";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Equihash 150,5,0 (GRIMM) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Equihash21x9";               MinMemGB = 2; Params = "--par=210,9";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #Equihash 210,9 (AION) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "EvrProgPow";    DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=EVRMORE-PROGPOW"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #EvrProgPow (EVR) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW";        DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #KawPow (RVN) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW2g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #KawPow (RVN) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW3g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #KawPow (RVN) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW4g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #KawPow (RVN) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW5g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #KawPow (RVN) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "Octopus";       DAG = $true; MinMemGB = 2; Params = "--par=octopus";    Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = $DevFee;                     Compute = @(); SecondaryAlgorithm = "KarlsenHash"} #Octopus (CFX) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "ProgPowSero";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=sero";  Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #ProgPowSero (SERO) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "ProgPowVeil";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=veil";  Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #ProgPowVeil (VEIL) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "ProgPowZ";      DAG = $true; MinMemGB = 2; Params = "--par=ProgPowZ --pers=zano"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #ProgPowZano (ZANO) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "EthashB3";      DAG = $true; MinMemGB = 2; Params = "--par=ethashb3";   Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #EthashB3 (RTH) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "UbqHash";       DAG = $true; MinMemGB = 2; Params = "--par=ubqhash";    Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "KarlsenHash"} #UbqHash (UBQ) + KarlsenHash
    ###[PSCustomObject]@{MainAlgorithm = "vProgPow";      DAG = $true; MinMemGB = 2; Params = "--par=vProgPow --pers=VeriBlock"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;   Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "KarlsenHash"} #vProgPow (VBK) + KarlsenHash

    #Dual Mining PyrinHash

    ###[PSCustomObject]@{MainAlgorithm = "BeamHash3";                  MinMemGB = 5; Params = "--par=beam3";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = $DevFee;               Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #BeamHash3 (BEAM) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "EtcHash";       DAG = $true; MinMemGB = 2; Params = "--par=etchash --pers=etchash"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;      Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Etchash (ETC) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash";        DAG = $true; MinMemGB = 2; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Ethash (ETH) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash2g";      DAG = $true; MinMemGB = 1; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Ethash (ETH) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash3g";      DAG = $true; MinMemGB = 2; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Ethash (ETH) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash4g";      DAG = $true; MinMemGB = 3; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Ethash (ETH) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Ethash5g";      DAG = $true; MinMemGB = 4; Params = "--par=ethash";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Ethash (ETH) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = "--par=ethash";   Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Ethash (ETH) for low memory coins + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Equihash24x5";               MinMemGB = 2; Params = "--par=144,5";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Equihash 144,5 + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Equihash24x7";               MinMemGB = 2; Params = "--par=192,7";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Equihash 192,7  + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "EquihashR25x4";              MinMemGB = 2; Params = "--par=125,4";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Equihash 125,4,0 (ZelCash) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "EquihashR25x5";              MinMemGB = 3; Params = "--par=150,5";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Equihash 150,5,0 (GRIMM) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Equihash21x9";               MinMemGB = 2; Params = "--par=210,9";      Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee;               Compute = @("GCN4","RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #Equihash 210,9 (AION) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "EvrProgPow";    DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=EVRMORE-PROGPOW"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #EvrProgPow (EVR) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW";        DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #KawPow (RVN) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW2g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #KawPow (RVN) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW3g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #KawPow (RVN) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW4g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #KawPow (RVN) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "KawPoW5g";      DAG = $true; MinMemGB = 2; Params = "--par=kawpow";     Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00; Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #KawPow (RVN) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "Octopus";       DAG = $true; MinMemGB = 2; Params = "--par=octopus";    Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = $DevFee;                     Compute = @(); SecondaryAlgorithm = "PyrinHash"} #Octopus (CFX) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "ProgPowSero";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=sero";  Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #ProgPowSero (SERO) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "ProgPowVeil";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow --pers=veil";  Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #ProgPowVeil (VEIL) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "ProgPowZ";      DAG = $true; MinMemGB = 2; Params = "--par=ProgPowZ --pers=zano"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;        Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #ProgPowZano (ZANO) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "EthashB3";      DAG = $true; MinMemGB = 2; Params = "--par=ethashb3";   Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #EthashB3 (RTH) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "UbqHash";       DAG = $true; MinMemGB = 2; Params = "--par=ubqhash";    Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 0.75;                  Compute = @("RDNA2","RDNA3"); SecondaryAlgorithm = "PyrinHash"} #UbqHash (UBQ) + PyrinHash
    ###[PSCustomObject]@{MainAlgorithm = "vProgPow";      DAG = $true; MinMemGB = 2; Params = "--par=vProgPow --pers=VeriBlock"; Vendor = @("NVIDIA"); ExtendInterval = 3; AutoPers = $false; Fee = 1.00;   Compute = @("RDNA2","RDNA3"); ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "PyrinHash"} #vProgPow (VBK) + PyrinHash

)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Cuda = $null
if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri  = $UriCuda[$i].Uri
            $Cuda = $UriCuda[$i].Cuda
        }
    }
}

if (-not $Cuda) {
    $Uri = ($UriCuda | Select-Object -Last 1).Uri
}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $ExcludeCompute = if ($Miner_Vendor -eq "AMD") {$_.ExcludeCompute}
            $Compute = if ($Miner_Vendor -eq "AMD") {$_.Compute}
            
		    foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGB) -and (-not $ExcludeCompute -or $_.OpenCL.DeviceCapability -notin $ExcludeCompute) -and (-not $Compute -or $_.OpenCL.DeviceCapability -in $Compute)}

			    if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and $Pools.$MainAlgorithm_Norm.User -notmatch "@") {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = if ($Miner_Vendor -eq "NVIDIA") {$Miner_Device.Type_Vendor_Index -join ' '} else {$Miner_Device.BusId_Type_Vendor_Index -join ' '}
                        $First = $false
                    }
                    $PersCoin = Get-EquihashCoinPers $Pools.$MainAlgorithm_Norm.CoinSymbol -Default "auto"
				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                    $Stratum = [System.Collections.Generic.List[string]]::new()
                    if ($Pools.$MainAlgorithm_Norm.SSL) {[void]$Stratum.Add("ssl")}
                    if ($Pools.$MainAlgorithm_Norm.Host -match "miningrigrentals" -and $MainAlgorithm_Norm_0 -match "^etc?hash") {[void]$Stratum.Add("stratum2")}

                    if ($SecondAlgorithm_Norm_0) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {$Miner_Intensity = 0}

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -gt 0) {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                                $DeviceIntensitiesAll = "--dualw=$($Intensity)"
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                                $DeviceIntensitiesAll = ""
                            }

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                    $Stratum2 = [System.Collections.Generic.List[string]]::new()
                                    if ($Pools.$SecondAlgorithm_Norm.SSL) {[void]$Stratum2.Add("ssl")}
                                    if ($Pools.$SecondAlgorithm_Norm.Host -match "miningrigrentals" -and $SecondAlgorithm_Norm_0 -match "^etc?hash") {[void]$Stratum2.Add("stratum2")}

				                    [PSCustomObject]@{
					                    Name           = $Miner_Name_Dual
					                    DeviceName     = $Miner_Device.Name
					                    DeviceModel    = $Miner_Model
					                    Path           = $Path
					                    Arguments      = "--$($Miner_Vendor.ToLower()) --telemetry=`$mport -cd $($DeviceIDsAll) --url=$(if ($Stratum) {"$($Stratum -join '+')://"})$($Pools.$MainAlgorithm_Norm.User -replace "@","%40")@$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" --worker=$($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers=$($PersCoin)"}) --gpu-line --minimal --extra --latency$(if (-not $Session.Config.ShowMinerWindow) {" --nocolor"})$(if ($Pools.$MainAlgorithm_Norm.Host -notmatch "xxxMiningRigRentals" -and $PersCoin -ne "auto") {" --smart-pers"}) $($_.Params) --nohttpheaders --url2=$(if ($Stratum2) {"$($Stratum2 -join '+')://"})$($Pools.$SecondAlgorithm_Norm.User -replace "@","%40")@$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port) $($DeviceIntensitiesAll)"
					                    HashRates      = [PSCustomObject]@{
                                                            $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                            $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                        }
					                    API            = "MiniZ"
					                    Port           = $Miner_Port
                                        FaultTolerance = $_.FaultTolerance
					                    ExtendInterval = $_.ExtendInterval
                                        SkipSeconds    = 40
                                        Penalty        = 0
					                    DevFee         = [PSCustomObject]@{
								                            ($MainAlgorithm_Norm) = $_.Fee
								                            ($SecondAlgorithm_Norm) = 0
                                                          }
					                    Uri            = $Uri
					                    ManualUri      = $ManualUri
                                        Version        = $Version
                                        PowerDraw      = 0
                                        BaseName       = $Name
                                        BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                        Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        ExcludePoolName= $_.ExcludePoolName
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
					        Arguments      = "--$($Miner_Vendor.ToLower()) --telemetry=`$mport -cd $($DeviceIDsAll) --url=$(if ($Stratum) {"$($Stratum -join '+')://"})$($Pools.$MainAlgorithm_Norm.User -replace "@","%40")@$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" --worker=$($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers=$($PersCoin)"}) --gpu-line --minimal --extra --latency$(if (-not $Session.Config.ShowMinerWindow) {" --nocolor"})$(if ($Pools.$MainAlgorithm_Norm.Host -notmatch "xxxMiningRigRentals" -and $PersCoin -ne "auto") {" --smart-pers"}) $($_.Params) --nohttpheaders"
					        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week)}
					        API            = "MiniZ"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            SkipSeconds    = 40
                            Penalty        = 0
					        DevFee         = $_.Fee
					        Uri            = $Uri
					        ManualUri      = $ManualUri
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            ExcludePoolName = $_.ExcludePoolName
				        }
                    }
			    }
		    }
        }
    }
}
