using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if ((-not $IsWindows -or -not $Session.IsWin10) -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-BMiner\bminer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v16.3.0-bminer/bminer-v16.3.0-bab438a-amd64.tar.xz"
} else {
    $Path = ".\Bin\GPU-BMiner\bminer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v16.3.0-bminer/bminer-lite-v16.3.0-bab438a-amd64.zip"
}
$Version = "16.3.0"
$ManualURI = "https://www.bminer.me/releases/"
$Port = "307{0:d2}"
$DevFee = 2.0
$Cuda = "9.2"

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "aeternity";    SecondaryAlgorithm = ""; MinMemGb = 5;  Params = ""; DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; NoCPUMining = $true; ExcludePoolName = "^Nicehash"} #" -nofee" #Aeternity
    #[PSCustomObject]@{MainAlgorithm = "beamhash2";    SecondaryAlgorithm = ""; MinMemGb = 5;  Params = ""; DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "^Nicehash"} #" -nofee" #Old
    #[PSCustomObject]@{MainAlgorithm = "beam";         SecondaryAlgorithm = ""; MinMemGb = 5;  Params = ""; DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "^Nicehash"} #" -nofee" #BEAM
    #[PSCustomObject]@{MainAlgorithm = "bfc";          SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #BFC
    #[PSCustomObject]@{MainAlgorithm = "cuckaroo29m";  SecondaryAlgorithm = ""; MinMemGb = 5; Params = ""; DevFee = 1.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true; ExcludePoolName = "^EthashPool"} #" -nofee" #Cuckaroom29/GRIN
    #[PSCustomObject]@{MainAlgorithm = "cuckatoo31";   SecondaryAlgorithm = ""; MinMemGb = 8; Params = ""; DevFee = 1.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #" -nofee" #Cuckatoo31
    #[PSCustomObject]@{MainAlgorithm = "cuckatoo32";   SecondaryAlgorithm = ""; MinMemGb = 6; Params = ""; DevFee = 1.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #" -nofee" #Cuckatoo32
    #[PSCustomObject]@{MainAlgorithm = "equihash1445"; SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = ""; MinMemGb = 3; Params = ""; DevFee = 0.65; Vendor = @("AMD","NVIDIA")} #Ethash (ethminer is faster and no dev fee)
    #[PSCustomObject]@{MainAlgorithm = "qitmeer";      SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 1.0; Vendor = @("AMD","NVIDIA")} #" -nofee" #QitMeer
    #[PSCustomObject]@{MainAlgorithm = "raven"; SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #KawPOW (RVN)
    #[PSCustomObject]@{MainAlgorithm = "sero"; SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #ProgPOW (SERO)
    #[PSCustomObject]@{MainAlgorithm = "tensority";    SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; ExcludePoolName = "^(MiningRigRentals|Nicehash)"} #" -nofee" #Bytom
    ##[PSCustomObject]@{MainAlgorithm = "zhash";        SecondaryAlgorithm = ""; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #Zhash
    ##[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "eaglesong"; MinMemGb = 3; Params = ""; DevFee = 1.3; Vendor = @("NVIDIA"); ExtendInterval = 2; ExcludePoolName = "^MiningRigRentals"} #Ethash + Eaglesong
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "tensority"; MinMemGb = 3; Params = ""; DevFee = 1.3; Vendor = @("NVIDIA"); ExtendInterval = 2; ExcludePoolName = "^(MiningRigRentals|Nicehash)"} #Ethash + BTM
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "handshake"; MinMemGb = 3; Params = ""; DevFee = 1.3; Vendor = @("AMD"); ExtendInterval = 2; ExcludePoolName = "^(MiningRigRentals|Nicehash)"} #Ethash + HNS
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true
            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm
			$SecondAlgorithm = $_.SecondaryAlgorithm

            $MinMemGb = if ($Session.RegexAlgoHasDAGSize.Matches($MainAlgorithm_Norm_0)) {if ($Pools.$MainAlgorithm_Norm_0.EthDAGSize) {$Pools.$MainAlgorithm_Norm_0.EthDAGSize} else {Get-EthDAGSize $Pools.$MainAlgorithm_Norm_0.CoinSymbol}} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            if ($SecondAlgorithm -ne '') {
				            $SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
                            $Miner_Name = (@($Name) + @($MainAlgorithm_Norm_0) + @($SecondAlgorithm_Norm) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
			            } else {
                            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        }
			            $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
			            if ($Miner_Vendor -eq "AMD") {$DeviceIDsAll = "amd:$($DeviceIDsAll -replace ',',',amd:')"}

                        $First = $false
                    }
					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
   
                    $Stratum = if ($MainAlgorithm -eq "equihash") {"stratum"}
                               elseif ($Session.RegexAlgoHasEthproxy.Matches($MainAlgorithm)) {
                                    Switch($Pools.$MainAlgorithm_Norm.EthMode) {
                                        "minerproxy" {"ethstratum"}
                                        "ethproxy"   {"ethproxy"}
                                        default {"ethash"}
                                    }
                               }
                               else {$MainAlgorithm}

					$Stratum = "$($Stratum)$(if ($Pools.$MainAlgorithm_Norm.SSL) {"+ssl"})"

                    if ($Pools.$MainAlgorithm_Norm.Name -eq "F2pool" -and $Pools.$MainAlgorithm_Norm.User -match "^0x[0-9a-f]{40}") {$Pool_Port = 8008}

                    $Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:`$mport -uri $($Stratum)://$(Get-UrlEncode $Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$MainAlgorithm_Norm.Pass)"})@$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)$(if ($MainAlgorithm_Norm -eq "Equihash24x5") {" -pers $(Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto")"}) -watchdog=false -no-runtime-info -gpucheck=0 $($_.Params)"

					if ($SecondAlgorithm -eq '') {
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = $Arguments
							HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
							API            = "Bminer"
							Port           = $Miner_Port
							Uri            = $Uri
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
							DevFee         = $_.DevFee
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            ExcludePoolName= $_.ExcludePoolName
						}
					} else {
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "$($Arguments) -uri2 $($SecondAlgorithm)://$(Get-UrlEncode $Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$SecondAlgorithm_Norm.Pass)"})@$($Pools.$SecondAlgorithm_Norm.Host):$($Pools.$SecondAlgorithm_Norm.Port)"
							HashRates      = [PSCustomObject]@{
								                "$MainAlgorithm_Norm" = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week
								                "$SecondAlgorithm_Norm" = $Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm)_HashRate".Week
							                 }
							API            = "Bminer"
							Port           = $Miner_Port
							Uri            = $Uri
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
							DevFee         = [PSCustomObject]@{
								                "$MainAlgorithm_Norm" = $_.DevFee
								                "$SecondAlgorithm_Norm" = 0
							                 }
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
                            ExcludePoolName= $_.ExcludePoolName
						}
					}
				}
			}
        })
    }
}