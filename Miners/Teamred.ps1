using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$Port = "409{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=5059817.0"
$DevFee = 3.0
$Version = "0.9.4.2"

if ($IsLinux) {
    $Path = ".\Bin\AMD-Teamred\teamredminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4.2-teamred/teamredminer-v0.9.4.2-linux.tgz"
    $DatFile = "$env:HOME/.vertcoin/verthash.dat"
} else {
    $Path = ".\Bin\AMD-Teamred\teamredminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4.2-teamred/teamredminer-v0.9.4.2-win.zip"
    $DatFile = "$env:APPDATA\Vertcoin\verthash.dat"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "autolykos2";                    MinMemGb = 1.5; Params = ""; DevFee = 2.0; ExtendInterval = 2} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "cn_conceal";                    MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_haven";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_heavy";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_saber";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnr";                           MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8";                          MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_dbl";                      MinMemGb = 3.3; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_half";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_rwz";                      MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_trtl";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_upx2";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cuckarood29_grin";              MinMemGb = 6;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cuckatoo31_grin";               MinMemGb = 8;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "etchash";          DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3}
    [PSCustomObject]@{MainAlgorithm = "ethash";           DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "ton"; SecondPoolName = "hashrate|toncoinpool|ton-pool|whalestonpool"}
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory";  DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; Algorithm = "ethash"}
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory";  DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; SecondAlgorithm = "ton"; SecondPoolName = "hashrate|toncoinpool|ton-pool|whalestonpool"}
    [PSCustomObject]@{MainAlgorithm = "firopow";          DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3}
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";                        MinMemGb = 1.5; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "mtp";                           MinMemGb = 5;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "nimiq";                         MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "phi2";                          MinMemGb = 1.5; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "ton";                           MinMemGb = 1.5; Params = ""; DevFee = 3.0; ExtendInterval = 2; PoolName = "hashrate|toncoinpool|ton-pool|whalestonpool"}
    [PSCustomObject]@{MainAlgorithm = "trtl_chukwa";                   MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "verthash";                      MinMemGb = 1.5; Params = ""; DevFee = 2.0}
    [PSCustomObject]@{MainAlgorithm = "trtl_chukwa2";                  MinMemGb = 1.5; Params = ""; DevFee = 2.5; ExcludeArchitecture = @("gfx1010","gfx1011","gfx1012","gfx1030","gfx1031","gfx1032")}
    [PSCustomObject]@{MainAlgorithm = "x16r";                          MinMemGb = 3.3; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16rt";                         MinMemGb = 1.5; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16rv2";                        MinMemGb = 1.5; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16s";                          MinMemGb = 1.5; Params = ""; DevFee = 2.5}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if (-not (Test-Path $DatFile) -or (Get-Item $DatFile).length -lt 1.19GB) {
    $DatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
}

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Miner_PlatformId = $Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands.ForEach({
        $First = $True
        $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $SecondAlgorithm_Norm_0 = if ($_.SecondAlgorithm) {Get-Algorithm $_.SecondAlgorithm} else {$null}

        $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

        #Zombie-mode since v0.7.14
        if ($_.DAG -and $MainAlgorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
            $MinMemGB = $_.MinMemGB
        }

        $Miner_ExcludeArch = $_.ExcludeArchitecture
        $Miner_Arch = $_.Architecture

        $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGB) -and (-not $Miner_ExcludeArch -or $_.OpenCL.Architecture -notin $Miner_ExcludeArch)}
        $Miner_Device_Dual = if ($SecondAlgorithm_Norm_0) {$Miner_Device | Where-Object {-not $Miner_Arch -or $_.OpenCL.Architecture -in $Miner_Arch}}

        if ($SecondAlgorithm_Norm_0 -and $Miner_Arch -and (-not ($Miner_Device_Dual | Measure-Object).Count)) {
            $Miner_Device = $null
        }

        $Miner_DevFee = $_.DevFee

        if ($_.MainAlgorithm -match "^ethash" -and (($Miner_Model -split '-') -notmatch "(Baffin|Ellesmere|RX\d)" | Measure-Object).Count) {
            $Miner_DevFee = 1.0
        }

		foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
			if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and
                (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and
                (-not $_.PoolName -or $Pools.$MainAlgorithm_Norm.Host -match $_.PoolName)) {
                if ($First) {
				    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
					$Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)_$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll  = $Miner_Device.Type_Vendor_Index -join ','
                    $DeviceIDsDual = if ($SecondAlgorithm_Norm_0) {$Miner_Device_Dual.Type_Vendor_Index -join ','}
                    $First = $False
                }

                $Pool_User = $Pools.$MainAlgorithm_Norm.User
                $Pool_Protocol = if ($Pools.$MainAlgorithm_Norm.Protocol -eq "wss") {"stratum+tcp"} else {$Pools.$MainAlgorithm_Norm.Protocol}
                $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                $Pool_Host = if ($Pool_Port) {if ($Pools.$MainAlgorithm_Norm.Host -match "^([^/]+)/(.+)$") {"$($Matches[1]):$($Pool_Port)/$($Matches[2])"} else {"$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)"}} else {$Pools.$MainAlgorithm_Norm.Host}

                $IsVerthash = $MainAlgorithm_Norm_0 -eq "Verthash"

                [System.Collections.Generic.List[string]]$AdditionalParams = @("--watchdog_disabled")
                if ($Pools.$MainAlgorithm_Norm.Host -match "bsod" -and $MainAlgorithm_Norm_0 -eq "x16rt") {
                    $AdditionalParams.Add("--no_ntime_roll")
                }
                if ($IsLinux -and $MainAlgorithm_Norm_0 -match "^cn") {
                    $AdditionalParams.Add("--allow_large_alloc")
                }
                if ($_.MainAlgorithm -eq "nimiq") {
                    $Pool_User = $Pools.$MainAlgorithm_Norm.Wallet
                    $Pool_Protocol = "stratum+tcp"
                    $AdditionalParams.Add("--nimiq_worker=$($Pools.$MainAlgorithm_Norm.Worker)")
                    #if ($Pools.$MainAlgorithm_Norm_0.Name -match "Icemining") {
                    #    $Pool_Host = $Pool_Host -replace "^nimiq","nimiq-trm"
                    #}
                } elseif ($IsVerthash) {
                    $AdditionalParams.Add("--verthash_file='$($DatFile)'")
                }

                if ($SecondAlgorithm_Norm_0) {

                    $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                    if (-not $Miner_Intensity) {$Miner_Intensity = 0}

                    foreach($Intensity in @($Miner_Intensity)) {

                        $Intensity = try {[double]$Intensity} catch {if ($Error.Count){$Error.RemoveAt(0)};0}

                        if ($Intensity -gt 0) {
                            $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$([int]($Intensity*100))") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                            $DeviceIntensitiesAll = (",$($Intensity)"*($Miner_Device | Measure-Object).Count) -replace "^,"
                        } else {
                            $Miner_Name_Dual = $Miner_Name
                            $DeviceIntensitiesAll = $null
                        }

                        foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                            if ($Pools.$SecondAlgorithm_Norm.Host -and
                                (-not $_.SecondExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.SecondExcludePoolName) -and
                                (-not $_.SecondPoolName -or $Pools.$SecondAlgorithm_Norm.Host -match $_.SecondPoolName)) {

                                $TonMode = if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.EthMode) {$Pools.$SecondAlgorithm_Norm.EthMode} else {$null}

                                $SecondPool_Protocol  = if ($Pools.$SecondAlgorithm_Norm.Protocol -eq "wss") {"stratum+tcp"} else {$Pools.$SecondAlgorithm_Norm.Protocol}
                                if ($SecondPool_Protocol -eq "") {$SecondPool_Protocol = "stratum+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                $SecondPool_Port      = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                $SecondPool_Host      = if ($SecondPool_Port) {if ($Pools.$SecondAlgorithm_Norm.Host -match "^([^/]+)/(.+)$") {"$($Matches[1]):$($SecondPool_Port)/$($Matches[2])"} else {"$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port)"}} else {$Pools.$SecondAlgorithm_Norm.Host}
                                $SecondPool_Arguments = "--$($_.SecondAlgorithm) -d $($DeviceIDsDual) -o $($SecondPool_Protocol)://$($SecondPool_Host) -u $($Pools.$SecondAlgorithm_Norm.Wallet).$($Pools.$SecondAlgorithm_Norm.Worker)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" -p $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($TonMode) {" --ton_pool_mode=$($TonMode)"}) --$($_.SecondAlgorithm)_end"

				                [PSCustomObject]@{
					                Name           = $Miner_Name_Dual
					                DeviceName     = $Miner_Device.Name
					                DeviceModel    = $Miner_Model
					                Path           = $Path
					                Arguments      = "-a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}) -d $($DeviceIDsAll) --opencl_order -o $($Pool_Protocol)://$($Pool_Host) -u $($Pool_User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"}) $($SecondPool_Arguments)$(if ($DeviceIntensitiesAll) {"  --dual_intensity=$($DeviceIntensitiesAll)"}) --api_listen=`$mport --platform=$($Miner_PlatformId) $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					                HashRates      = [PSCustomObject]@{
                                                        $MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week
                                                        $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week
                                                     }
					                API            = "Xgminer"
					                Port           = $Miner_Port
					                Uri            = $Uri
                                    FaultTolerance = $_.FaultTolerance
					                ExtendInterval = $_.ExtendInterval
                                    Penalty        = 0
					                DevFee         = [PSCustomObject]@{
                                                        $MainAlgorithm_Norm = $Miner_DevFee
                                                        $SecondAlgorithm_Norm = 0
                                                     }
					                ManualUri      = $ManualUri
                                    Version        = $Version
                                    PowerDraw      = 0
                                    BaseName       = $Name
                                    BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                    Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                    LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                    PrerequisitePath = if ($IsVerthash) {$DatFile} else {$null}
                                    PrerequisiteURI  = "$(if ($IsVerthash) {"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"})"
                                    PrerequisiteMsg  = "$(if ($IsVerthash) {"Downloading verthash.dat (1.2GB) in the background, please wait!"})"
                                    ExcludePoolName = $_.ExcludePoolName
				                }
                            }
                        }
                    }

                } else {

                    $TonMode = if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.EthMode) {$Pools.$MainAlgorithm_Norm.EthMode} else {$null}

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "-a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}) -d $($DeviceIDsAll) --opencl_order -o $($Pool_Protocol)://$($Pool_Host) -u $($Pool_User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($TonMode) {" --ton_pool_mode=$($TonMode)"}) --api_listen=`$mport --platform=$($Miner_PlatformId) $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					    HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
					    API            = "Xgminer"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = $Miner_DevFee
					    ManualUri      = $ManualUri
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $MainAlgorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                        PrerequisitePath = if ($IsVerthash) {$DatFile} else {$null}
                        PrerequisiteURI  = "$(if ($IsVerthash) {"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"})"
                        PrerequisiteMsg  = "$(if ($IsVerthash) {"Downloading verthash.dat (1.2GB) in the background, please wait!"})"
                        ListDevices    = "--list_devices"
                        ExcludePoolName = $_.ExcludePoolName
				    }
                }
			}
		}
    })
}