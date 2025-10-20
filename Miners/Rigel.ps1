using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD/NVIDIA present in system

$ManualUri = "https://github.com/rigelminer/rigel/releases"
$Port = "324{0:d2}"
$DevFee = 0.7
$Version = "1.22.3"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Rigel\rigel"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.22.3-rigel/rigel-1.22.3-linux.tar.gz"
            Cuda = "8.0"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Rigel\rigel.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.22.3-rigel/rigel-1.22.3-win.zip"
            Cuda = "8.0"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    # Single mining
    [PSCustomObject]@{MainAlgorithm = "abelian";         DAG = $true; MinMemGB = 5; Params = "";                     Vendor = @("NVIDIA")} #Abelian/ABEL
    [PSCustomObject]@{MainAlgorithm = "alephium";                     MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA")} #Alephium/ALPH
    [PSCustomObject]@{MainAlgorithm = "autolykos2";      DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0} #Autolykos2/ERG
    [PSCustomObject]@{MainAlgorithm = "BlocxAutolykos2"; DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Algorithm = "autolykos2"; Fee = 1.0} #BlocxAutolykos2/BLOCX
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA")} #Etchash (ETC)
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 3; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 4; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH) for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethashb3";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA")} #Ethash3B (RTH)
    [PSCustomObject]@{MainAlgorithm = "fishhash";        DAG = $true; MinMemGB = 5; Params = "";                     Vendor = @("NVIDIA")} #Fishhash/IRON from 2. April 2024
    [PSCustomObject]@{MainAlgorithm = "karlsenhashv2";                MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0} #KarlsenHashV2/KLS
    [PSCustomObject]@{MainAlgorithm = "nexapow";         DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 2.0} #NexaPoW/NEXA
    [PSCustomObject]@{MainAlgorithm = "octopus";         DAG = $true; MinMemGB = 4; Params = "";                     Vendor = @("NVIDIA"); Fee = 2.0; ZombieMode = @("NVIDIA")} #Octopus/CFX
    [PSCustomObject]@{MainAlgorithm = "KawPOW";          DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Algorithm = "kawpow"; Fee = 1.0} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW2g";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Algorithm = "kawpow"; Fee = 1.0; ExcludePoolName = "MiningRigRentals"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW3g";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Algorithm = "kawpow"; Fee = 1.0; ExcludePoolName = "MiningRigRentals"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW4g";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Algorithm = "kawpow"; Fee = 1.0; ExcludePoolName = "MiningRigRentals"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW5g";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Algorithm = "kawpow"; Fee = 1.0; ExcludePoolName = "MiningRigRentals"} #KayPOW
    [PSCustomObject]@{MainAlgorithm = "quai";            DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0} #ProgPowQuai/QUAI
    [PSCustomObject]@{MainAlgorithm = "progpowz";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0} #ProgPowZ/ZANO
    [PSCustomObject]@{MainAlgorithm = "sha256ton";                    MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0; PoolName = "Icemining"} #SHA256ton/GRAM+CHAPA
    [PSCustomObject]@{MainAlgorithm = "sha3x";                        MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0} #SHA3x/XTM
    [PSCustomObject]@{MainAlgorithm = "sha512256d";                   MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 1.0} #SHA512256d/RAD
    [PSCustomObject]@{MainAlgorithm = "xelishashv2";                  MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); Fee = 3.0; ExtendInterval = 3} #XelisHashv2/XEL

    # Dual mining
    [PSCustomObject]@{MainAlgorithm = "abelian";         DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"} #Abelian/ABEL + ALPH
    [PSCustomObject]@{MainAlgorithm = "abelian";         DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha256ton"; SecondaryPoolName = "Icemining"} #Abelian/ABEL + GRAM/CHAPA
    [PSCustomObject]@{MainAlgorithm = "abelian";         DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha3x"} #Abelian/ABEL + XTM
    [PSCustomObject]@{MainAlgorithm = "abelian";         DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"} #Abelian/ABEL + RXD

    [PSCustomObject]@{MainAlgorithm = "autolykos2";      DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Fee = 1.0} #Autolykos2/ERG + ALPH
    [PSCustomObject]@{MainAlgorithm = "autolykos2";      DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha256ton"; Fee = 1.0; SecondaryPoolName = "Icemining"} #Autolykos2/ERG + GRAM/CHAPA
    [PSCustomObject]@{MainAlgorithm = "autolykos2";      DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha3x"; Fee = 1.0} #Autolykos2/ERG + XTM
    [PSCustomObject]@{MainAlgorithm = "autolykos2";      DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Fee = 1.0} #Autolykos2/ERG + RXD

    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"} #Etchash (ETC)
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"} #Etchash (ETC)

    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"} #Ethash (ETH)

    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Algorithm = "ethash"} #Ethash (ETH)

    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Algorithm = "ethash"} #Ethash (ETH)

    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 3; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Algorithm = "ethash"} #Ethash (ETH)

    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 4; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Algorithm = "ethash"} #Ethash (ETH)

    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Algorithm = "ethash"} #Ethash (ETH) for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Algorithm = "ethash"} #Ethash (ETH)

    [PSCustomObject]@{MainAlgorithm = "ethashb3";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"}   #BlakeB3/HYP + ALPH
    [PSCustomObject]@{MainAlgorithm = "ethashb3";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha256ton"; SecondaryPoolName = "Icemining"} #BlakeB3/HYP + GRAM/CHAPA
    [PSCustomObject]@{MainAlgorithm = "ethashb3";        DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"} #BlakeB3/HYP + RXD

    [PSCustomObject]@{MainAlgorithm = "fishhash";        DAG = $true; MinMemGB = 5; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"}   #FishHash/IRON + ALPH
    [PSCustomObject]@{MainAlgorithm = "fishhash";        DAG = $true; MinMemGB = 5; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha256ton"; SecondaryPoolName = "Icemining"} #FishHash/IRON + GRAM/CHAPA
    [PSCustomObject]@{MainAlgorithm = "fishhash";        DAG = $true; MinMemGB = 5; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha3x"} #FishHash/IRON + XTM
    [PSCustomObject]@{MainAlgorithm = "fishhash";        DAG = $true; MinMemGB = 5; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"} #FishHash/IRON + RXD

    [PSCustomObject]@{MainAlgorithm = "karlsenhashv2";   DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha256ton"; SecondaryPoolName = "Icemining"} #KarlsenHashV2/KLS + GRAM/CHAPA
    [PSCustomObject]@{MainAlgorithm = "karlsenhashv2";   DAG = $true; MinMemGB = 2; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha3x"} #KarlsenHashV2/KLS + XTM

    [PSCustomObject]@{MainAlgorithm = "octopus";         DAG = $true; MinMemGB = 4; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "alephium"; Fee = 2.0; ZombieMode = @("NVIDIA")} #Octopus/CFX + ALPH
    [PSCustomObject]@{MainAlgorithm = "octopus";         DAG = $true; MinMemGB = 4; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha256ton"; Fee = 2.0; SecondaryPoolName = "Icemining"; ZombieMode = @("NVIDIA")} #Octopus/CFX + GRAM/CHAPA
    [PSCustomObject]@{MainAlgorithm = "octopus";         DAG = $true; MinMemGB = 4; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha3x"; Fee = 2.0; ZombieMode = @("NVIDIA")} #Octopus/CFX + XTM
    [PSCustomObject]@{MainAlgorithm = "octopus";         DAG = $true; MinMemGB = 4; Params = "";                     Vendor = @("NVIDIA"); SecondaryAlgorithm = "sha512256d"; Fee = 2.0; ZombieMode = @("NVIDIA")} #Octopus/CFX + RXD
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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

foreach ($Miner_Vendor in @("NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $MainAlgorithm_0  = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                if ($_.DAG -and ($MinMemGB -gt $_.MinMemGb) -and ($_.ZombieMode -and $Miner_Vendor -in $_.ZombieMode)) {
                    $MinMemGB = $_.MinMemGb
                }
                $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

                $CoinParams = ""

                if ($MainAlgorithm_0 -eq "kawpow") {
                    if ($Pools.$MainAlgorithm_Norm.CoinSymbol -eq "AIPG")      {$CoinParams = " --coin aipg"}
                    elseif ($Pools.$MainAlgorithm_Norm.CoinSymbol -eq "NEOX")  {$CoinParams = " --coin neox"}
                    elseif ($Pools.$MainAlgorithm_Norm.CoinSymbol -ne "RVN")   {$CoinParams = " --coin ravencoin"}
                    elseif ($Pools.$MainAlgorithm_Norm.CoinSymbol -eq "CLORE") {$CoinParams = " --coin clore"}
                    elseif ($Pools.$MainAlgorithm_Norm.CoinSymbol -eq "XNA")   {$CoinParams = " --coin xnaget-coin octa"}
                
                } elseif ($MainAlgorithm_0 -eq "ethash") {
                    if ($Pools.$MainAlgorithm_Norm.CoinSymbol -eq "OCTA")      {$CoinParams = " --coin octa"}
                    elseif ($Pools.$MainAlgorithm_Norm.CoinSymbol -eq "XPB")   {$CoinParams = " --coin xpb"}
                } elseif ($MainAlgorithm0 -eq "BlocxAutolykos2") {
                    $CoinParams = " --coin blocx"
                }

                if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Name -notmatch $_.ExcludePoolName) -and (-not $_.PoolName -or $Pools.$MainAlgorithm_Norm.Name -match $_.PoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                        $First = $false
                    }

                    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

                    $Miner_Protocol = Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                        "ethproxy"     {"ethproxy+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethstratum"   {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethstratum1"  {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethstratum2"  {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethstratumnh" {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        default        {"stratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                    }

                    if ($SecondAlgorithm_Norm_0) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {$Miner_Intensity = 0}

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -gt 0) {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                                $IntensityParams = " --dual-mode $((@("a12:r$($Intensity)") * ($Miner_Device | Measure-Object).Count) -join ",")"
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                                $IntensityParams = ''
                            }

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and (-not $_.SecondaryExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Name -notmatch $_.SecondaryExcludePoolName) -and (-not $_.SecondaryPoolName -or $Pools.$SecondAlgorithm_Norm.Name -match $_.SecondaryPoolName)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}

                                    [PSCustomObject]@{
                                        Name            = $Miner_Name_Dual
                                        DeviceName      = $Miner_Device.Name
                                        DeviceModel     = $Miner_Model
                                        Path            = $Path
                                        Arguments       = "--api-bind 127.0.0.1:`$mport -d $($DeviceIDsAll)$($IntensityParams) -a $($MainAlgorithm_0)+$($_.SecondaryAlgorithm)$($CoinParams) -o [1]$($Miner_Protocol)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u [1]$($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p [1]$($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" -w [1]$($Pools.$MainAlgorithm_Norm.Worker)"}) -o [2]$($Pools.$SecondAlgorithm_Norm.Protocol)://$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port) -u [2]$($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" -p [2]$($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker -and $Pools.$SecondAlgorithm_Norm.User -eq $Pools.$SecondAlgorithm_Norm.Wallet) {" -w [2]$($Pools.$SecondAlgorithm_Norm.Worker)"}) --no-tui --no-watchdog --dag-reset-mclock off $($_.Params)"
                                        HashRates       = [PSCustomObject]@{
                                                             $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                             $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                         }
                                        API             = "Rigel"
                                        Port            = $Miner_Port
                                        FaultTolerance  = $_.FaultTolerance
                                        ExtendInterval  = $_.ExtendInterval
                                        Penalty         = 0
                                        DevFee          = [PSCustomObject]@{
                                                             ($MainAlgorithm_Norm) = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
                                                             ($SecondAlgorithm_Norm) = 0
                                                           }
                                        Uri             = $Uri
                                        ManualUri       = $ManualUri
                                        NoCPUMining     = $_.NoCPUMining
                                        Version         = $Version
                                        PowerDraw       = 0
                                        BaseName        = $Name
                                        BaseAlgorithm   = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                        Benchmarked     = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile         = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        ExcludePoolName = $_.ExcludePoolName
                                    }
                                }
                            }
                        }

                    } else {
                        $o1_count = ""
                        [PSCustomObject]@{
                            Name            = $Miner_Name
                            DeviceName      = $Miner_Device.Name
                            DeviceModel     = $Miner_Model
                            Path            = $Path
                            Arguments       = "--api-bind 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($MainAlgorithm_0)$($CoinParams) -o $($o1_count)$($Miner_Protocol)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($o1_count)$($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($o1_count)$($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" -w $($o1_count)$($Pools.$MainAlgorithm_Norm.Worker)"}) --no-tui --no-watchdog --dag-reset-mclock off $($_.Params)"
                            HashRates       = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week)}
                            API             = "Rigel"
                            Port            = $Miner_Port
                            FaultTolerance  = $_.FaultTolerance
                            ExtendInterval  = $_.ExtendInterval
                            Penalty         = 0
                            DevFee          = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
                            Uri             = $Uri
                            ManualUri       = $ManualUri
                            Version         = $Version
                            PowerDraw       = 0
                            BaseName        = $Name
                            BaseAlgorithm   = $MainAlgorithm_Norm_0
                            Benchmarked     = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile         = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            ExcludePoolName = $_.ExcludePoolName
                        }
                    }
                }
            }
        }
    }
}
