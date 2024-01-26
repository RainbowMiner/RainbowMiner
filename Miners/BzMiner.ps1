using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

# this miner module is currently disabled.
# return

$ManualUri = "https://github.com/bzminer/bzminer/releases"
$Port = "332{0:d2}"
$DevFee = 0.5
$Cuda = "11.2"
$Version = "19.3.0"

if ($IsLinux) {
    $Path = ".\Bin\GPU-BzMiner\bzminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v19.3.0-bzminer/bzminer_v19.3.0_linux.tar.gz"
} else {
    $Path = ".\Bin\GPU-BzMiner\bzminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v19.3.0-bzminer/bzminer_v19.3.0_windows.zip"
}

$ExcludePoolName = "prohashing|miningrigrentals"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "alph";                         MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.00} #Blake3/Alephium
    [PSCustomObject]@{MainAlgorithm = "canxium";         DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; CoinSymbol = @("CAU"); Algorithm = "Ethash2g"} #Ethash/ETHW
    [PSCustomObject]@{MainAlgorithm = "dynex";                        MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 2.00} #DynexSolve/DNX
    [PSCustomObject]@{MainAlgorithm = "ergo";                         MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #ERG/Autolykos2
    [PSCustomObject]@{MainAlgorithm = "ergo";                         MinMemGb = 2; Params = ""; Vendor = @("NVIDIA"); ExtendInterval = 2; SecondaryAlgorithm = "kaspa"} #ERG/Autolykos2+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ergo";                         MinMemGb = 2; Params = ""; Vendor = @("NVIDIA"); ExtendInterval = 2; SecondaryAlgorithm = "radiant"} #ERG/Autolykos2+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #Etchash
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"} #Etchash+Blake3
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"} #Etchash+Ironfish
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"} #Etchash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"} #Etchash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludeCoinSymbol = @("CAU","ETHW")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; ExcludeCoinSymbol = @("CAU","ETHW")} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; ExcludeCoinSymbol = @("CAU","ETHW")} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; ExcludeCoinSymbol = @("CAU","ETHW")} #Etchash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; ExcludeCoinSymbol = @("CAU","ETHW"); Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethw";            DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; CoinSymbol = @("ETHW"); Algorithm = "Ethash"} #Ethash/ETHW
    [PSCustomObject]@{MainAlgorithm = "ethw";            DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; CoinSymbol = @("ETHW"); Algorithm = "Ethash"} #Ethash+Blake3/ETHW
    [PSCustomObject]@{MainAlgorithm = "ethw";            DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"; CoinSymbol = @("ETHW"); Algorithm = "Ethash"} #Ethash+Ironfish/ETHW
    [PSCustomObject]@{MainAlgorithm = "ethw";            DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; CoinSymbol = @("ETHW"); Algorithm = "Ethash"} #Ethash+kHeavyHash/ETHW
    [PSCustomObject]@{MainAlgorithm = "ethw";            DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; CoinSymbol = @("ETHW"); Algorithm = "Ethash"} #Ethash+SHA512256d/ETHW
    [PSCustomObject]@{MainAlgorithm = "ironfish";                     MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.00} #Ironfish
    [PSCustomObject]@{MainAlgorithm = "ixi";                          MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.00} #Argon2Ixi/Ixian
    [PSCustomObject]@{MainAlgorithm = "karlsen";                      MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #KarlsenHash
    [PSCustomObject]@{MainAlgorithm = "kaspa";                        MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "kylacoin";                     MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "SHA3d"} #SHA3d/KCN
    [PSCustomObject]@{MainAlgorithm = "nexa";                         MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 2.0; Algorithm = "NexaPoW"} #NexaPow/NEXA
    [PSCustomObject]@{MainAlgorithm = "novo";                         MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 2.0; Algorithm = "SHA256dt"} #SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "radiant";                      MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #SHA512256d/RAD
    [PSCustomObject]@{MainAlgorithm = "kawpow";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #KawPow
    [PSCustomObject]@{MainAlgorithm = "kawpow2g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow2g
    [PSCustomObject]@{MainAlgorithm = "kawpow3g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow3g
    [PSCustomObject]@{MainAlgorithm = "kawpow4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow4g
    [PSCustomObject]@{MainAlgorithm = "kawpow5g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow5g
    [PSCustomObject]@{MainAlgorithm = "olhash";                       MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 1.00} #Olhash/Overline
    [PSCustomObject]@{MainAlgorithm = "rethereum";       DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.00} #Rethereum/RTH
    [PSCustomObject]@{MainAlgorithm = "rethereum";       DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA"); ExtendInterval = 2; SecondaryAlgorithm = "alph"; Fee = 1.00} #Rethereum/ALPH
    [PSCustomObject]@{MainAlgorithm = "rethereum";       DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Fee = 1.00} #Rethereum/RTH
    [PSCustomObject]@{MainAlgorithm = "woodcoin";                     MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.00} #Skein2/WoodCoin LOG
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","INTEL","NVIDIA")
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


if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

$CommonParams =  "-c config_`$mport.txt --http_enabled 1 --http_address localhost --http_port `$mport --no_watchdog --community_fund 0 --hide_disabled_devices --cpu_validate 0 --nc 1 -o bzminer_`$mport.log --clear_log_file 1 --oc_enable 0"

foreach ($Miner_Vendor in @("AMD","INTEL","NVIDIA")) {

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

        if (-not $Device -or ($Miner_Vendor -eq "NVIDIA" -and $Miner_Model -match "-" -and ($Device | Where-Object {$_.IsLHR} | Measure-Object).Count -gt 0)) {return}

        $Device_BusId = @($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq $Miner_Vendor} | Select-Object -ExpandProperty BusId -Unique)

        $VendorParams = Switch ($Miner_Vendor) {
            "AMD" {"--amd 1 --intel 0 --nvidia 0"}
            "INTEL" {"--amd 0 --intel 1 --nvidia 0"}
            "NVIDIA" {"--amd 0 --intel 0 --nvidia 1"}
        }

        $ZilParams2 = ""
        $ZilParams3 = ""

        if ($Miner_Vendor -ne "INTEL" -and $Session.Config.Pools.CrazyPool.EnableBzminerDual -and $Pools.ZilliqaCP) {
            if ($ZilWallet = $Pools.ZilliqaCP.Wallet) {
                $ZilParams2 = "--a2 zil --w2 $($Pools.ZilliqaCP.User) --p2 $($Pools.ZilliqaCP.Protocol)://$($Pools.ZilliqaCP.Host):$($Pools.ZilliqaCP.Port) --oc_enable2 0 "
                $ZilParams3 = "--a3 zil --w3 $($Pools.ZilliqaCP.User) --p3 $($Pools.ZilliqaCP.Protocol)://$($Pools.ZilliqaCP.Host):$($Pools.ZilliqaCP.Port) --oc_enable3 0 "
            }
        }

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)}).ForEach({
            $First = $true

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $MainAlgorithm_0  = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            if ($MainAlgorithm_0 -eq "kawpow") {
                Switch ($Pools.$MainAlgorithm_Norm_0.CoinSymbol) {
                    "CLORE" { $MainAlgorithm_0 = "clore" }
                    "GPN"   { $MainAlgorithm_0 = "gamepass" }
                    "NEOX"  { $MainAlgorithm_0 = "neox" }
                    "MEWC"  { $MainAlgorithm_0 = "meowcoin" }
                    "RVN"   { $MainAlgorithm_0 = "rvn" }
                    "XNA"   { $MainAlgorithm_0 = "xna" }
                }
            } elseif ($MainAlgorith_0 -eq "ethash") {
                if ($Pools.$MainAlgorithm_Norm_0.CoinSymbol -eq "CAU") {$MainAlgorithm_0 = "canxium"}
            }

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
            $Miner_Device = $Device.Where({Test-VRAM $_ $MinMemGB})

            $DisableDevices = @(Compare-Object $Device_BusId @($Miner_Device | Select-Object -ExpandProperty BusId -Unique) | Where-Object {$_.SideIndicator -eq "<="} | Foreach-Object {($_.InputObject -split ':' | Foreach-Object {[uint32]"0x$_"}) -join ':'}) -join ' '

            $ZilParams = if ($ZilParams2 -ne "" -and $_.MainAlgorithm -ne "dynex") {
                if ($SecondAlgorithm_Norm_0 -ne $null) {$ZilParams3} else {$ZilParams2}
            }

            $DynexParams = if ($_.MainAlgorithm -eq "dynex") {
                $DynexVal = "2.0"
                "--dynex_pow_ratio $("$($DynexVal) "*($Miner_Device | Measure-Object).Count)$(if ($IsWindows) {"-i 59 "})--hung_gpu_ms 10000 "
            }

            foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and ($Pools.$MainAlgorithm_Norm.User -notmatch "@")) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                    }

                    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                    $Pool_Protocol = Switch($Pools.$MainAlgorithm_Norm.EthMode) {
                                        "ethproxy"      {"ethproxy+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum1"   {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratumnh"  {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum2"   {"ethstratum2+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        default         {$Pools.$MainAlgorithm_Norm.Protocol}
                                     }

                    if ($SecondAlgorithm_Norm_0) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {$Miner_Intensity = 0}

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -gt 0) {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                                $DeviceIntensitiesAll = " $($Intensity)"*($Miner_Device | Measure-Object).Count
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                                $DeviceIntensitiesAll = $null
                            }

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and (-not $ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $ExcludePoolName) -and (-not $_.CoinSymbol2 -or $_.CoinSymbol2 -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol2 -or $_.ExcludeCoinSymbol2 -inotcontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                    $SecondPool_Protocol = Switch($Pools.$SecondAlgorithm_Norm.EthMode) {
                                        "ethproxy"      {"ethproxy+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum1"   {"ethstratum+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratumnh"  {"ethstratum+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum2"   {"ethstratum2+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        default         {$Pools.$SecondAlgorithm_Norm.Protocol}
                                    }

                                    [PSCustomObject]@{
                                        Name            = $Miner_Name_Dual
                                        DeviceName      = $Miner_Device.Name
                                        DeviceModel     = $Miner_Model
                                        Path            = $Path
                                        Arguments       = "-a $($MainAlgorithm_0) --a2 $($_.SecondaryAlgorithm) $VendorParams $(if ($DisableDevices) {" --disable $($DisableDevices)"}) -p $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"}) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pool_password $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" -r $($Pools.$MainAlgorithm_Norm.Worker)"}) --p2 $($SecondPool_Protocol)://$($Pools.$SecondAlgorithm_Norm.Host)$(if ($SecondPool_Port -and $Pools.$SecondAlgorithm_Norm.Host -notmatch "/") {":$($SecondPool_Port)"}) --w2 $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --pool_password2 $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker) {" --r2 $($Pools.$SecondAlgorithm_Norm.Worker)"}) $($ZilParams)$($DynexParams)$($CommonParams) --oc_enable2 0 $($_.Params)"
                                        HashRates       = [PSCustomObject]@{
                                                             $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                             $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                          }
                                        API             = "BzMiner"
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
                                        BaseAlgorithm   = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
                                        Benchmarked     = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile         = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        ExcludePoolName = $ExcludePoolName
                                        DualZIL         = $ZilParams -ne $null
                                        MultiProcess    = 1
                                    }
                                }
                            }
                        }
                    } else {
                        [PSCustomObject]@{
                            Name            = $Miner_Name
                            DeviceName      = $Miner_Device.Name
                            DeviceModel     = $Miner_Model
                            Path            = $Path
                            Arguments       = "-a $($MainAlgorithm_0) $VendorParams $(if ($DisableDevices) {" --disable $($DisableDevices)"})  -p $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"}) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pool_password $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" -r $($Pools.$MainAlgorithm_Norm.Worker)"}) $($ZilParams)$($DynexParams)$($CommonParams) $($_.Params)"
                            HashRates       = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
                            API             = "BzMiner"
                            Port            = $Miner_Port
                            FaultTolerance  = $_.FaultTolerance
                            ExtendInterval  = $_.ExtendInterval
                            Penalty         = 0
                            DevFee          = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
                            Uri             = $Uri
                            ManualUri       = $ManualUri
                            NoCPUMining     = $_.NoCPUMining
                            Version         = $Version
                            PowerDraw       = 0
                            BaseName        = $Name
                            BaseAlgorithm   = $MainAlgorithm_Norm_0
                            Benchmarked     = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile         = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            ExcludePoolName = $ExcludePoolName
                            DualZIL         = $ZilParams -ne $null
                            MultiProcess    = 1
                        }
                    }
                }
            }
        })
    }
}
