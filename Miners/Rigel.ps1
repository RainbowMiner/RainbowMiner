using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://github.com/rigelminer/rigel/releases"
$Port = "324{0:d2}"
$DevFee = 0.7
$Version = "1.3.9"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Rigel\rigel"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.9-rigel/rigel-1.3.9-linux.tar.gz"
            Cuda = "8.0"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Rigel\rigel.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.9-rigel/rigel-1.3.9-win.zip"
            Cuda = "8.0"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD/NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    # Single mining
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA")} #Etchash (ETC)
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA")} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 3; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 4; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); Algorithm = "ethash"} #Ethash (ETH) for low memory coins
    [PSCustomObject]@{MainAlgorithm = "kheavyhash";                 MinMemGB = 2; Params = "";   Vendor = @("NVIDIA")} #kheavyhash/KASPA
    [PSCustomObject]@{MainAlgorithm = "nexapow";           DAG = $true; MinMemGB = 2; Params = "";   Vendor = @("NVIDIA"); Fee = 2.0} #NexaPoW/NEXA

    # Dual mining
    [PSCustomObject]@{MainAlgorithm = "etchash";         DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"} #Etchash (ETC)
    [PSCustomObject]@{MainAlgorithm = "ethash";          DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGB = 2; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGB = 3; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGB = 4; Params = ""; ExtendInterval = 2;   Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"; Algorithm = "ethash"} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 1; Params = ""; ExtendInterval = 2; Vendor = @("NVIDIA"); SecondaryAlgorithm = "kheavyhash"; Algorithm = "ethash"} #Ethash (ETH) for low memory coins
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

        $ZilAlgorithm = ""
        $ZilParams2   = ""
        $ZilParams3   = ""

        if ($Session.Config.Pools.FlexPool.EnableRigelDual -and $Pools.ZilliqaFP) {
            if ($ZilWallet = $Pools.ZilliqaFP.Wallet) {
                $ZilAlgorithm = "+zil"
                $ZilParams2   = " -o [2]$($Pools.ZilliqaFP.Protocol)://$($Pools.ZilliqaFP.Host) -u [2]$($Pools.ZilliqaFP.User)$(if ($Pools.ZilliqaFP.Worker -and $Pools.ZilliqaFP.User -eq $Pools.ZilliqaFP.Wallet) {" -w [2]$($Pools.ZilliqaFP.Worker)"})"
                $ZilParams3   = " -o [3]$($Pools.ZilliqaFP.Protocol)://$($Pools.ZilliqaFP.Host) -u [3]$($Pools.ZilliqaFP.User)$(if ($Pools.ZilliqaFP.Worker -and $Pools.ZilliqaFP.User -eq $Pools.ZilliqaFP.Wallet) {" -w [3]$($Pools.ZilliqaFP.Worker)"})"
            }
        }

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

            $ZilParams = ""

            if ($ZilParams2 -ne "") {
                $ZilParams = if ($SecondAlgorithm_Norm_0) {$ZilParams3} else {$ZilParams2}
            }

            foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
                if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
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
                                $IntensityParams = " --dual-mode $(@("a12:r$($Intensity)") * ($Miner_Device | Measure-Object).Count) -join ",")"
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                                $IntensityParams = ''
                            }

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}

                                    [PSCustomObject]@{
                                        Name            = $Miner_Name_Dual
                                        DeviceName      = $Miner_Device.Name
                                        DeviceModel     = $Miner_Model
                                        Path            = $Path
                                        Arguments       = "--api-bind 127.0.0.1:`$mport -d $($DeviceIDsAll)$($IntensityParams) -a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm})+$($_.SecondaryAlgorithm)$($ZilAlgorithm) -o [1]$($Miner_Protocol)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u [1]$($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p [1]$($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" -w [1]$($Pools.$MainAlgorithm_Norm.Worker)"}) -o [2]$($Pools.$SecondAlgorithm_Norm.Protocol)://$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port) -u [2]$($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" -p [2]$($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker -and $Pools.$SecondAlgorithm_Norm.User -eq $Pools.$SecondAlgorithm_Norm.Wallet) {" -w [2]$($Pools.$SecondAlgorithm_Norm.Worker)"})$($ZilParams) --no-tui --no-watchdog $($_.Params)"
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
                                        DualZIL         = $ZilParams -ne ""
                                    }
                                }
                            }
                        }

                    } else {
                        $o1_count = "$(if ($ZilParams -ne '') {"[1]"})"
                        [PSCustomObject]@{
                            Name            = $Miner_Name
                            DeviceName      = $Miner_Device.Name
                            DeviceModel     = $Miner_Model
                            Path            = $Path
                            Arguments       = "--api-bind 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm})$($ZilAlgorithm) -o $($o1_count)$($Miner_Protocol)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($o1_count)$($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($o1_count)$($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" -w $($o1_count)$($Pools.$MainAlgorithm_Norm.Worker)"})$($ZilParams) --no-tui --no-watchdog $($_.Params)"
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
                            DualZIL         = $ZilParams -ne ""
                        }
                    }
                }
            }
        })
    }
}
