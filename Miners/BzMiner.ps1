using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No devices present in system

# this miner module is currently disabled.
# return

$ManualUri = "https://github.com/bzminer/bzminer/releases"
$Port = "332{0:d2}"
$DevFee = 0.5
$Cuda = "11.2"
$Version = "23.0.2"

if ($IsLinux) {
    $Path = ".\Bin\GPU-BzMiner\bzminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v23.0.2-bzminer/bzminer_v23.0.2_linux.tar.gz"
} else {
    $Path = ".\Bin\GPU-BzMiner\bzminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v23.0.2-bzminer/bzminer_v23.0.2_windows.zip"
}

$ExcludePoolName = "prohashing|miningrigrentals"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "alph";                         MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #Blake3/Alephium
    [PSCustomObject]@{MainAlgorithm = "blocx";                        MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #BLOCX/BlocxAutolykos2
    [PSCustomObject]@{MainAlgorithm = "dynex";                        MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 2.00} #DynexSolve/DNX
    [PSCustomObject]@{MainAlgorithm = "ergo";            DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #ERG/Autolykos2
    [PSCustomObject]@{MainAlgorithm = "ergo";            DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA"); ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; Fee = 1.0} #ERG/Autolykos2+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ergo";            DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA"); ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Fee = 1.0} #ERG/Autolykos2+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2} #Etchash
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"} #Etchash+Blake3
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"} #Etchash+FishHash
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"} #Etchash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"} #Etchash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"} #Ethash+IronFish
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"} #Etchash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"; Algorithm = "ethash"} #Ethash+IronFish
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash2g";        DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"; Algorithm = "ethash"} #Ethash+IronFish
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash3g";        DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"; Algorithm = "ethash"} #Ethash+IronFish
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"; Algorithm = "ethash"} #Ethash+IronFish
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethash5g";        DAG = $true; MinMemGb = 4; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Algorithm = "ethash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "alph"; Algorithm = "ethash"} #Ethash+Blake3
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "ironfish"; Algorithm = "ethash"} #Ethash+IronFish
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "kaspa"; Algorithm = "ethash"} #Ethash+kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; MinMemGb = 1; Params = ""; Vendor = @("NVIDIA");       ExtendInterval = 2; SecondaryAlgorithm = "radiant"; Algorithm = "ethash"} #Ethash+SHA512256d
    [PSCustomObject]@{MainAlgorithm = "ironfish";                     MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #FishHash/IRON
    [PSCustomObject]@{MainAlgorithm = "ixi";                          MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #Argon2Ixi/Ixian
    [PSCustomObject]@{MainAlgorithm = "karlsen";                      MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #KarlsenHash
    [PSCustomObject]@{MainAlgorithm = "kaspa";                        MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "nexa";                         MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 2.0} #NexaPow/NEXA
    [PSCustomObject]@{MainAlgorithm = "SHA256dt";                     MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "novo"} #SHA256dt/NOVO
    [PSCustomObject]@{MainAlgorithm = "radiant";                      MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #SHA512256d/RAD
    [PSCustomObject]@{MainAlgorithm = "kawpow";          DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #KawPow
    [PSCustomObject]@{MainAlgorithm = "kawpow2g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow2g
    [PSCustomObject]@{MainAlgorithm = "kawpow3g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow3g
    [PSCustomObject]@{MainAlgorithm = "kawpow4g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow4g
    [PSCustomObject]@{MainAlgorithm = "kawpow5g";        DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0; Algorithm = "kawpow"} #KawPow5g
    [PSCustomObject]@{MainAlgorithm = "olhash";                       MinMemGb = 2; Params = ""; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #Olhash/Overline
    [PSCustomObject]@{MainAlgorithm = "rethereum";       DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #Rethereum/RTH
    [PSCustomObject]@{MainAlgorithm = "verus";                        MinMemGb = 1; Params = ""; Vendor = @("CPU");                  ExtendInterval = 2; Fee = 1.0} #VerusHash/VRSC
    [PSCustomObject]@{MainAlgorithm = "warthog";                      MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 2.0; NoCPUMining = $true} #Warthog/WART
    [PSCustomObject]@{MainAlgorithm = "woodcoin";                     MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #Skein2/WoodCoin LOG
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","INTEL","NVIDIA")
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

$CommonParams =  "-c config_`$mport.txt --http_enabled 1 --http_address localhost --http_port `$mport --no_watchdog --hide_disabled_devices --cpu_validate 0 --nc 1 -o bzminer_`$mport.log --clear_log_file 1 --oc_enable 0"

foreach ($Miner_Vendor in @("AMD","CPU","INTEL","NVIDIA")) {

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

        if (-not $Device -or ($Miner_Vendor -eq "NVIDIA" -and $Miner_Model -match "-" -and ($Device | Where-Object {$_.IsLHR} | Measure-Object).Count -gt 0)) {return}

        $Device_BusId = @($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq $Miner_Vendor} | Select-Object -ExpandProperty BusId -Unique)

        $VendorParams = Switch ($Miner_Vendor) {
            "AMD" {"--amd 1 --intel 0 --nvidia 0"}
            "CPU" {"--amd 0 --intel 0 --nvidia 0 --cpu 1"}
            "INTEL" {"--amd 0 --intel 1 --nvidia 0"}
            "NVIDIA" {"--amd 0 --intel 0 --nvidia 1"}
        }

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)} | ForEach-Object {
            $First = $true

            $MainAlgorithm_0  = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
            $SecondAlgorithm_0 = $_.SecondaryAlgorithm

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($SecondAlgorithm_0) {Get-Algorithm $SecondAlgorithm_0} else {$null}

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            $DynexParams = if ($_.MainAlgorithm -eq "dynex") {
                $DynexVal = "2.0"
                "--dynex_pow_ratio $("$($DynexVal) "*($Miner_Device | Measure-Object).Count)$(if ($IsWindows) {"-i 59 "})--hung_gpu_ms 10000 "
            } elseif ($Miner_Vendor -eq "CPU") {
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
                "--cpu-affinity $($CPUAffinity.ToUpper() -replace "^0X") "
            }

            foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}
                if ($MainAlgorithm_0 -eq "kaspa" -and $Pools.$MainAlgorithm_Norm.User -notmatch "^kaspa") {continue}

                if ($Pools.$MainAlgorithm_Norm.CoinSymbol) {
                    $check_algo = $false
                    if ($MainAlgorithm_0 -eq "kawpow") {
                        Switch ($Pools.$MainAlgorithm_Norm.CoinSymbol) {
                            "AIDEPIN" { $MainAlgorithm_0 = "aidepin" }
                            "AIPG"  { $MainAlgorithm_0 = "aipg" }
                            "DINT"  { $MainAlgorithm_0 = "dint" }
                            "CLORE" { $MainAlgorithm_0 = "clore" }
                            "GPN"   { $MainAlgorithm_0 = "gamepass" }
                            "NEOX"  { $MainAlgorithm_0 = "neox" }
                            "MEWC"  { $MainAlgorithm_0 = "meowcoin" }
                            "RVN"   { $MainAlgorithm_0 = "rvn" }
                            "XNA"   { $MainAlgorithm_0 = "xna" }
                        }
                        $check_algo = $true
                    } elseif ($MainAlgorith_0 -eq "ethash") {
                        switch ($Pools.$MainAlgorithm_Norm.CoinSymbol) {
                            "CAU"   { $MainAlgorithm_0 = "canxium" }
                            "ETHW"  { $MainAlgorithm_0 = "ethw" }
                            "LRS"   { $MainAlgorithm_0 = "larissa" }
                            "OCTA"  { $MainAlgorithm_0 = "octa" }
                        }
                        $check_algo = $true
                    } elseif ($MainAlgorith_0 -eq "karlsen") {
                        switch ($Pools.$MainAlgorithm_Norm.CoinSymbol) {
                            "NXL"   { $MainAlgorithm_0 = "nexellia" }
                        }
                    }

                    if ($check_algo) {
                        $Miner_Coin = Get-Coin $Pools.$MainAlgorithm_Norm.CoinSymbol
                        if ($Miner_Coin.Algo -ne $MainAlgorithm_Norm_0) {continue}
                    }
                }

                if ($Miner_Vendor -ne "CPU") {
                    $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}            
                    $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}
                    $DisableDevices = @(Compare-Object $Device_BusId @($Miner_Device | Select-Object -ExpandProperty BusId -Unique) | Where-Object {$_.SideIndicator -eq "<="} | Foreach-Object {($_.InputObject -split ':' | Foreach-Object {[uint32]"0x$_"}) -join ':'}) -join ' '
                } else {
                    $Miner_Device = $Device
                    $DisableDevices = $null
                }

                if ($Miner_Device -and (-not $ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and ($Pools.$MainAlgorithm_Norm.User -notmatch "@")) {
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
                                if ($SecondAlgorithm_0 -eq "kaspa" -and $Pools.$SecondAlgorithm_Norm.User -notmatch "^kaspa") {continue}
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
                                        Arguments       = "-a $($MainAlgorithm_0) --a2 $($SecondAlgorithm_0) $VendorParams$(if ($DisableDevices) {" --disable $($DisableDevices)"}) -p $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"}) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pool_password $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" -r $($Pools.$MainAlgorithm_Norm.Worker)"}) --p2 $($SecondPool_Protocol)://$($Pools.$SecondAlgorithm_Norm.Host)$(if ($SecondPool_Port -and $Pools.$SecondAlgorithm_Norm.Host -notmatch "/") {":$($SecondPool_Port)"}) --w2 $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --pool_password2 $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker) {" --r2 $($Pools.$SecondAlgorithm_Norm.Worker)"}) $($DynexParams)$($CommonParams) --oc_enable2 0 $($_.Params)"
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
                            Arguments       = "-a $($MainAlgorithm_0) $VendorParams$(if ($DisableDevices) {" --disable $($DisableDevices)"}) -p $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"}) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pool_password $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" -r $($Pools.$MainAlgorithm_Norm.Worker)"}) $($DynexParams)$($CommonParams) $($_.Params)"
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
                            MultiProcess    = 1
                        }
                    }
                }
            }
        }
    }
}
