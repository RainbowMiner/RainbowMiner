using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "317{0:d2}"
$Cuda = "10.0"
$DevFee = 1.0
$Version = "1.95a"

if ($IsLinux) {
    $Path = ".\Bin\GPU-lolMiner\lolMiner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.95a-lolminer/lolMiner_v1.95a_Lin64.tar.gz"
} else {
    $Path = ".\Bin\GPU-lolMiner\lolMiner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.95a-lolminer/lolMiner_v1.95a_Win64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 2;   Params = "--algo AUTOLYKOS2"; Pers=$false; Fee=1.5; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 2;   Params = "--algo AUTOLYKOS2 --dualmode PYRINV2DUAL"; Pers=$false; Fee=1.5; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "PyrinHashV2"} #Autolykos2/ERGO + PyrinHashV2/PYI
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 2;   Params = "--algo AUTOLYKOS2 --dualmode TONDUAL"; Pers=$false; Fee=1.5; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"} #Autolykos2/ERGO + SHA256ton/GRAM
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                    MinMemGb = 3;   Params = "--algo BEAM-III";   Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #BeamHash III
    [PSCustomObject]@{MainAlgorithm = "Blake3Alephium";               MinMemGB = 2;   Params = "--algo ALEPH";      Pers=$false; Fee=0.75; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #Blake3/ALPH
    [PSCustomObject]@{MainAlgorithm = "BlocxAutolykos2"; DAG = $true; MinMemGb = 2;   Params = "--algo AUTOLYKOS2"; Pers=$false; Fee=1.5; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Autolykos2/BLOCX
    [PSCustomObject]@{MainAlgorithm = "BlocxAutolykos2"; DAG = $true; MinMemGb = 2;   Params = "--algo AUTOLYKOS2 --dualmode TONDUAL"; Pers=$false; Fee=1.5; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"} #Autolykos2/BLOCX
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29b";                  MinMemGb = 6;   Params = "--algo CR29-40";    Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckaroo29b
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";                  MinMemGb = 6;   Params = "--algo CR29-32";    Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckaroo29s
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo30";                   MinMemGb = 7.6; Params = "--algo C30CTX";     Pers=$false; Fee=2.5; ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo30
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";                   MinMemGb = 4;   Params = "--algo C31";        Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo32";                   MinMemGb = 4;   Params = "--algo C32";        Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckatoo32
    [PSCustomObject]@{MainAlgorithm = "CuckooCycle";                  MinMemGb = 6;   Params = "--algo C29AE";      Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #CuckooCycle/AEternity
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";                 MinMemGb = 1;   Params = "--algo EQUI210_9";  Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";                 MinMemGb = 2;   Params = "--algo EQUI144_5";  ParamsAutoPers = "--coin AUTO144_5"; Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD","INTEL")} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";                 MinMemGb = 3;   Params = "--algo EQUI192_7";  ParamsAutoPers = "--coin AUTO192_7"; Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";                MinMemGb = 3;   Params = "--algo FLUX";       Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA")} #Equihash 125,4,0
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1";   Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA")} #Etchash
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Etchash + Blake3
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ethash + Blake3
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ethash + Blake3
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ethash + Blake3
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 3;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 3;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ethash + Blake3
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 4;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 4;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ethash + Blake3
    [PSCustomObject]@{MainAlgorithm = "EthashB3";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASHB3 --disable-dag-verify 1";  Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #EthashB3/RTH
    [PSCustomObject]@{MainAlgorithm = "EtHashB3";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASHB3 --disable-dag-verify 1 --dualmode ALEPHDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #EthashB3/RTH + Blake3
    [PSCustomObject]@{MainAlgorithm = "EtHashB3";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASHB3 --disable-dag-verify 1 --dualmode KARLSENDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "KarlsenHash"; CUDAArch = "P"} #EthashB3/RTH + KarlsenHash
    [PSCustomObject]@{MainAlgorithm = "EtHashB3";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASHB3 --disable-dag-verify 1 --dualmode PYRINDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "HeavyHashPyrin"; CUDAArch = "P"} #EthashB3/RTH + Pyrin
    [PSCustomObject]@{MainAlgorithm = "EtHashB3";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASHB3 --disable-dag-verify 1 --dualmode RXDDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA512256d"; CUDAArch = "P"} #EthashB3/RTH + SHA512256d
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ethash for low memory coins + Blake3
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1";  Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #FishHash/IRON
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #FishHash/IRON + Blake3
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1 --dualmode KARLSENDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "KarlsenHash"; CUDAArch = "P"} #FishHash/IRON + KarlsenHash
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1 --dualmode PYRINDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "HeavyHashPyrin"; CUDAArch = "P"} #FishHash/IRON + Pyrin
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1 --dualmode PYRINV2DUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "PyrinHashV2"; CUDAArch = "P"} #FishHash/IRON + Pyrin
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1 --dualmode RXDDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA512256d"; CUDAArch = "P"} #FishHash/IRON + SHA512256d
    [PSCustomObject]@{MainAlgorithm = "FishHash";        DAG = $true; MinMemGB = 2;   Params = "--algo FISHHASH --disable-dag-verify 1 --dualmode TONDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; CUDAArch = "P"} #FishHash/IRON + SHA256ton
    [PSCustomObject]@{MainAlgorithm = "HeavyHashPyrin";               MinMemGB = 2;   Params = "--algo PYRIN";                                                Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #HeavyHashPyrin/PYI
    [PSCustomObject]@{MainAlgorithm = "KarlsenHash";                  MinMemGb = 2;   Params = "--algo KARLSEN";                                              Pers=$false; Fee=1.0;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #KarlsenHash
    [PSCustomObject]@{MainAlgorithm = "KarlsenHashV2";                MinMemGb = 2;   Params = "--algo KARLSENV2";                                            Pers=$false; Fee=1.0;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #KarlsenHashV2
    [PSCustomObject]@{MainAlgorithm = "KarlsenHashV2";                MinMemGb = 2;   Params = "--algo KARLSENV2 --dualmode PYRINV2DUAL";                     Pers=$false; Fee=1.0;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "PyrinHashV2"; CUDAArch = "P"} #KarlsenHashV2
    [PSCustomObject]@{MainAlgorithm = "KarlsenHashV2";                MinMemGb = 2;   Params = "--algo KARLSENV2 --dualmode TONDUAL";                         Pers=$false; Fee=1.0;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; CUDAArch = "P"} #KarlsenHashV2
    [PSCustomObject]@{MainAlgorithm = "NexaPoW";         DAG = $true; MinMemGb = 2;   Params = "--algo NEXA";                             Pers=$false; Fee=2; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #NexaPow/NEOX
    [PSCustomObject]@{MainAlgorithm = "Octopus";         DAG = $true; MinMemGb = 6;   Params = "--algo OCTOPUS";                          Pers=$false; Fee=2; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); ZombieMode = @("NVIDIA")} #Octopus/CTXC
    [PSCustomObject]@{MainAlgorithm = "PyrinHashV2";                  MinMemGb = 2;   Params = "--algo PYRINV2";                                              Pers=$false; Fee=1.0;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #KarlsenHashV2
    [PSCustomObject]@{MainAlgorithm = "SHA256ton";                    MinMemGb = 2;   Params = "--algo GRAM";        Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #SHA256ton/GRAM
    [PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1";   Pers=$false; Fee=0.7; ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Ubqhash
    [PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3Alephium"; CUDAArch = "P"} #Ubqhash + Blake3

    #[PSCustomObject]@{MainAlgorithm = "Cuckarood29";                  MinMemGb = 6;   Params = "--algo C29D";       Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckarood29
    #[PSCustomObject]@{MainAlgorithm = "Cuckaroom29";                  MinMemGb = 6;   Params = "--algo C29M";       Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroom29
    #[PSCustomObject]@{MainAlgorithm = "EquihashR25x5";                MinMemGb = 3;   Params = "--algo BEAM-I";     Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 150,5
    #[PSCustomObject]@{MainAlgorithm = "EquihashR25x5x3";              MinMemGb = 3;   Params = "--algo BEAM-II";    Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","INTEL")} #Equihash 150,5,3
    #[PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Etchash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "EtHash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Ethash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "EtHash2g";        DAG = $true; MinMemGB = 1;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Ethash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "EtHash3g";        DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Ethash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "EtHash4g";        DAG = $true; MinMemGB = 3;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Ethash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "EtHash5g";        DAG = $true; MinMemGB = 4;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Ethash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "EtHashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "P"} #Ethash for low memory coins + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "kHeavyHash";                   MinMemGB = 2;   Params = "--algo KASPA";                                                Pers=$false; Fee=0.75; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1 --dualmode KASPADUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "kHeavyHash"; CUDAArch = "T"} #Ubqhash + kHeavyHash
    #[PSCustomObject]@{MainAlgorithm = "SHA512256d";                   MinMemGb = 2;   Params = "--algo RADIANT";                           Pers=$false; Fee=0.75; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); CUDAArch = "P"} #SHA512256d/RAD
    #[PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1 --dualmode TONDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; CUDAArch = "P"} #Etchash + SHA256ton
    #[PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode TONDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; CUDAArch = "P"} #Ethash + SHA256ton
    #[PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode TONDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; CUDAArch = "P"} #Ethash for low memory coins + SHA256ton
    #[PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1 --dualmode TONDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 2; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; CUDAArch = "P"} #Ubqhash + SHA256ton
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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

$CUDAArch_Types = [PSCustomObject]@{
    "A" = @("Ampere","Ada","Hopper","Blackwell")
    "T" = @("Turing","Ampere","Ada","Hopper","Blackwell")
    "P" = @("Pascal","Turing","Ampere","Ada","Hopper","Blackwell")
}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

$WatchdogParams = if ($Session.Config.RebootOnGPUFailure -and $Session.Config.EnableRestartComputer) {"--watchdog script --watchdogscript '$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")'"} else {"--watchdog exit"}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $SecondAlgorithm = $_.SecondAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondAlgorithm) {Get-Algorithm $_.SecondAlgorithm} else {$null}

            if ($_.CUDAArch -ne $null -and $_.Vendor -eq "NVIDIA") {
                $CUDAArch = $CUDAArch_Types."$($_.CUDAArch)"
                if (-not ($Miner_Device | Where-Object {$_.OpenCL.Architecture -in $CUDAArch})) {
                    #no mining, if not at least one GPU is available
                    $Miner_Device = $null
                }
            }

            $DeviceParams = "$(if ($Global:IsWindows -and $MainAlgorithm_Norm_0 -eq "NexaPoW") {" --keepfree 1024"})"

            foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
                #Zombie-Mode since v1.11
                if ($_.DAG -and ($MinMemGB -gt $_.MinMemGb) -and (($MainAlgorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $Session.Config.EnableEthashZombieMode) -or ($_.ZombieMode -and $Miner_Vendor -in $_.ZombieMode))) {
                    $MinMemGB = $_.MinMemGb
                }
                $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

                if ($Miner_Device -and $Pools.$MainAlgorithm_Norm.Host -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll  = $Miner_Device.BusId_Type_Mineable_Index -join ',' #"$($Miner_Device.BusId -join ',') --devicesbypcie"
                        $DeviceLHRsAll = if ($Miner_Vendor -eq "NVIDIA") {($Miner_Device | Foreach-Object {if ($_.IsLHR) {"auto"} else {"off"}}) -join ','}
                        $First = $false
                    }
                    $PersCoin = if ($_.Pers) {Get-EquihashCoinPers $Pools.$MainAlgorithm_Norm.CoinSymbol -Default "auto"}

                    $EthStratum = if ($MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy) {
                        Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                            "ethproxy" {"ETHPROXY"}
                            "qtminer" {if ($Pools.$MainAlgorithm_Norm.Host -match "miningrigrentals") {"ETHPROXY"} else {"ETHV1"}}
                            default {"ETHV1"}
                        }
                    }

                    if (-not $_.Pers -or $PersCoin -or $_.ParamsAutoPers) {

                        $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                        $Pool_Host = if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "^[^/]+/.+$") {"$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)"} else {$Pools.$MainAlgorithm_Norm.Host}
                        $Pool_User = if ($Pools.$MainAlgorithm_Norm.Host -match "miningrigrentals") {$Pools.$MainAlgorithm_Norm.User -replace "\.","*"} else {$Pools.$MainAlgorithm_Norm.User}
                        #$Pool_User = $Pool_User -replace "@","%40"

                        $Pool_Arguments = "--pool $(if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.Protocol) {"$($Pools.$MainAlgorithm_Norm.Protocol)://"})$($Pool_Host) --user $($Pool_User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($MainAlgorithm_Norm_0 -ne "SHA256ton") {" --tls $(if ($Pools.$MainAlgorithm_Norm.SSL) {"on"} else {"off"})"})"

                        if ($SecondAlgorithm_Norm_0) {

                            $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                            if (-not $Miner_Intensity) {$Miner_Intensity = @(2)}

                            foreach($Intensity in @($Miner_Intensity)) {

                                if ($Intensity -gt 0) {
                                    $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                                    $DeviceIntensitiesAll = " --dualfactor $($Intensity)"
                                } else {
                                    $Miner_Name_Dual = $Miner_Name
                                    $DeviceIntensitiesAll = ""
                                }

                                foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                    if ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {

                                        $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                        $SecondPool_Host = if ($SecondPool_Port -and $Pools.$SecondAlgorithm_Norm.Host -notmatch "^[^/]+/.+$") {"$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port)"} else {$Pools.$SecondAlgorithm_Norm.Host}

                                        $SecondPool_Arguments = "--dualpool $(if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.Protocol) {"$($Pools.$SecondAlgorithm_Norm.Protocol)://"})$($SecondPool_Host) --dualuser $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --dualpass $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($SecondAlgorithm_Norm_0 -ne "SHA256ton") {" --dualtls $(if ($Pools.$SecondAlgorithm_Norm.SSL) {"on"} else {"off"})"})$($DeviceIntensitiesAll)"

                                        $TonMode = if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.EthMode) {
                                            Switch ($Pools.$SecondAlgorithm_Norm.EthMode) {
                                                "icemining" {6}
                                                "toncoinpool" {3}
                                                "tonpool" {2}
                                            }
                                        }

                                        [PSCustomObject]@{
                                            Name           = $Miner_Name_Dual
                                            DeviceName     = $Miner_Device.Name
                                            DeviceModel    = $Miner_Model
                                            Path           = $Path
                                            Arguments      = "$($Pool_Arguments)$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) $($SecondPool_Arguments)$(if ($TonMode) {" --ton-mode $($TonMode)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker) {" --dualworker $($Pools.$SecondAlgorithm_Norm.Worker)"}) --devices $($DeviceIDsAll) --apiport `$mport --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 $(if ($DeviceLHRsAll) {"--lhrtune $($DeviceLHRsAll) "})$(if ($EthStratum) {"--ethstratum $($EthStratum) "})$(if ($PersCoin -and $PersCoin -ne "auto") {"--pers $($PersCoin) "})$($WatchdogParams)$($DeviceParams) $(if ($PersCoin -eq "auto" -and $_.ParamsAutoPers) {$_.ParamsAutoPers} else {$_.Params})"
                                            HashRates      = [PSCustomObject]@{
                                                                $MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week
                                                                $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week
                                                             }
                                            API            = "Lol"
                                            Port           = $Miner_Port
                                            FaultTolerance = $_.FaultTolerance
                                            ExtendInterval = $_.ExtendInterval
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
                                            ExcludePoolName = $_.ExcludePoolName
                                        }
                                    }
                                }

                            }

                        } else {

                            $TonMode = if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.EthMode) {
                                Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                                    "icemining" {6}
                                    "toncoinpool" {3}
                                    "tonpool" {2}
                                }
                            }

                            [PSCustomObject]@{
                                Name           = $Miner_Name
                                DeviceName     = $Miner_Device.Name
                                DeviceModel    = $Miner_Model
                                Path           = $Path
                                Arguments      = "$($Pool_Arguments)$(if ($TonMode) {" --ton-mode $($TonMode)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) --devices $($DeviceIDsAll) --apiport `$mport --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 $(if ($DeviceLHRsAll) {"--lhrtune $($DeviceLHRsAll) "})$(if ($EthStratum) {"--ethstratum $($EthStratum) "})$(if ($PersCoin -and $PersCoin -ne "auto") {"--pers $($PersCoin) "})$($WatchdogParams)$($DeviceParams) $(if ($PersCoin -eq "auto" -and $_.ParamsAutoPers) {$_.ParamsAutoPers} else {$_.Params})"
                                HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
                                API            = "Lol"
                                Port           = $Miner_Port
                                FaultTolerance = $_.FaultTolerance
                                ExtendInterval = $_.ExtendInterval
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
                                ListDevices    = "--list-devices"
                                ExcludePoolName = $_.ExcludePoolName
                            }
                        }
                    }
                }
            }
        }
    }
}
