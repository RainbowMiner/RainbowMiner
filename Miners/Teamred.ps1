using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$Port = "409{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=5059817.0"
$DevFee = 3.0
$Version = "0.8.5"

if ($IsLinux) {
    $Path = ".\Bin\AMD-Teamred\teamredminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.8.5-teamred/teamredminer-v0.8.5-linux.tgz"
    $DatFile = "$env:HOME/.vertcoin/verthash.dat"
} else {
    $Path = ".\Bin\AMD-Teamred\teamredminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.8.5-teamred/teamredminer-v0.8.5-win.zip"
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
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory";  DAG = $true; MinMemGb = 2;   Params = ""; DevFee = 0.75; ExtendInterval = 3; Algorithm = "ethash"}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           DAG = $true; MinMemGb = 3;   Params = ""; DevFee = 2.0;  ExtendInterval = 3}
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3";                     MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";                        MinMemGb = 1.5; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "mtp";                           MinMemGb = 5;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "nimiq";                         MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "phi2";                          MinMemGb = 1.5; Params = ""; DevFee = 3.0}
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
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

        $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGB) -and (-not $_.ExcludeArchitecture -or $_.OpenCL.Architecture -notin $_.ExcludeArchitecture)}

        #Zombie-mode since v0.7.14
        if ($_.DAG -and $Algorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
            $MinMemGB = $_.MinMemGB
        }

        $Miner_DevFee = $_.DevFee

        if ($_.MainAlgorithm -match "^ethash" -and (($Miner_Model -split '-') -notmatch "(Baffin|Ellesmere|RX\d)" | Measure-Object).Count) {
            $Miner_DevFee = 1.0
        }

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
				    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
					$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Device.Type_Vendor_Index -join ','

                    $Pool_Host = $Pools.$Algorithm_Norm_0.Host
                    $Pool_User = $Pools.$Algorithm_Norm_0.User
                    $Pool_Protocol = $Pools.$Algorithm_Norm_0.Protocol

                    $IsVerthash = $Algorithm_Norm_0 -eq "Verthash"

                    $AdditionalParams = @("--watchdog_disabled")
                    if ($Pools.$Algorithm_Norm_0.Name -match "^bsod" -and $Algorithm_Norm_0 -eq "x16rt") {
                        $AdditionalParams += "--no_ntime_roll"
                    }
                    if ($IsLinux -and $Algorithm_Norm_0 -match "^cn") {
                        $AdditionalParams += "--allow_large_alloc"
                    }
                    if ($_.MainAlgorithm -eq "nimiq") {
                        $Pool_User = $Pools.$Algorithm_Norm_0.Wallet
                        $Pool_Protocol = "stratum+tcp"
                        $AdditionalParams += "--nimiq_worker=$($Pools.$Algorithm_Norm_0.Worker)"
                        #if ($Pools.$Algorithm_Norm_0.Name -match "Icemining") {
                        #    $Pool_Host = $Pool_Host -replace "^nimiq","nimiq-trm"
                        #}
                    } elseif ($IsVerthash) {
                        $AdditionalParams += "--verthash_file='$($DatFile)'"
                    }
                    $First = $False
                }

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}) -d $($DeviceIDsAll) --opencl_order -o $($Pool_Protocol)://$($Pool_Host):$($Pool_Port) -u $($Pool_User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --api_listen=`$mport --platform=$($Miner_PlatformId) $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
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
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    PrerequisitePath = if ($IsVerthash) {$DatFile} else {$null}
                    PrerequisiteURI  = "$(if ($IsVerthash) {"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"})"
                    PrerequisiteMsg  = "$(if ($IsVerthash) {"Downloading verthash.dat (1.2GB) in the background, please wait!"})"
                    ListDevices    = "--list_devices"
				}
			}
		}
    })
}