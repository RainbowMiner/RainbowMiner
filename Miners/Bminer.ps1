using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
#if (-not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-BMiner\bminer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v15.7.6-bminer/bminer-v15.7.6-f585663-amd64.tar.xz"
} else {
    $Path = ".\Bin\GPU-BMiner\bminer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v15.7.6-bminer/bminer-lite-v15.7.6-f585663-amd64.zip"
}
$ManualURI = "https://www.bminer.me/releases/"
$Port = "307{0:d2}"
$DevFee = 2.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeternity";    SecondaryAlgorithm = ""; NH = $false; MinMemGb = 6; Params = "--fast"; DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; NoCPUMining = $true} #" -nofee" #Aeternity
    [PSCustomObject]@{MainAlgorithm = "beam";         SecondaryAlgorithm = ""; NH = $false; MinMemGb = 6; MinMemGbW10 = 7; Params = ""; DevFee = 2.0; Vendor = @("AMD"); ExtendInterval = 2} #" -nofee" #Beam
    [PSCustomObject]@{MainAlgorithm = "cuckaroo29d";  SecondaryAlgorithm = ""; NH = $true;  MinMemGb = 4; MinMemGbW10 = 6; Params = "--fast"; DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #" -nofee" #Beam
    [PSCustomObject]@{MainAlgorithm = "cuckatoo31";   SecondaryAlgorithm = ""; NH = $true; MinMemGb = 8; MinMemGbW10 = 11; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #" -nofee" #Beam
    #[PSCustomObject]@{MainAlgorithm = "equihash";     SecondaryAlgorithm = ""; NH = $true; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #Equihash
    #[PSCustomObject]@{MainAlgorithm = "equihash1445"; SecondaryAlgorithm = ""; NH = $true; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = ""; NH = $false; MinMemGb = 4; Params = ""; DevFee = 0.65; Vendor = @("NVIDIA")} #Ethash (ethminer is faster and no dev fee)
    [PSCustomObject]@{MainAlgorithm = "tensority";    SecondaryAlgorithm = ""; NH = $false; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2} #" -nofee" #Bytom
    #[PSCustomObject]@{MainAlgorithm = "zhash";        SecondaryAlgorithm = ""; NH = $true; MinMemGb = 1; Params = ""; DevFee = 2.0; Vendor = @("NVIDIA")} #" -nofee" #Zhash
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "blake2s";  NH = $false; MinMemGb = 4; Params = ""; DevFee = 1.3; Vendor = @("NVIDIA"); ExtendInterval = 2} #Ethash + Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "blake14r"; NH = $false; MinMemGb = 4; Params = ""; DevFee = 1.3; Vendor = @("NVIDIA"); ExtendInterval = 2} #Ethash + Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "tensority"; NH = $false; MinMemGb = 4; Params = ""; DevFee = 1.3; Vendor = @("NVIDIA"); ExtendInterval = 2} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "ethash";       SecondaryAlgorithm = "vbk"; NH = $false; MinMemGb = 4; Params = ""; DevFee = 1.3; Vendor = @("NVIDIA"); ExtendInterval = 2} #Ethash + VeriBlock
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

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm,"$($MainAlgorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$MainAlgorithm_Norm.Name -notmatch "Nicehash") -and ($MainAlgorithm_Norm -ne "Ethash" -or $Pools.$MainAlgorithm_Norm.Name -ne "MiningRigRentals")) {
					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

					$DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
					if ($Miner_Vendor -eq "AMD") {$DeviceIDsAll = "amd:$($DeviceIDsAll -replace ',',',amd:')"}

					$SecondAlgorithm = $_.SecondaryAlgorithm
					if ($SecondAlgorithm -ne '') {
						$SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
					}
   
                    $Stratum = if ($MainAlgorithm -eq "equihash") {"stratum"}
                               elseif ($MainAlgorithm -eq "ethash") {
                                    Switch($Pools.$MainAlgorithm_Norm.EthMode) {
                                        "minerproxy" {"ethstratum"}
                                        "ethproxy"   {"ethproxy"}
                                        default {"ethash"}
                                    }
                               }
                               else {$MainAlgorithm}

					$Stratum = "$($Stratum)$(if ($Pools.$MainAlgorithm_Norm.SSL) {"+ssl"})"

					if ($SecondAlgorithm -eq '') {
						$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $($Stratum)://$(Get-UrlEncode $Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$MainAlgorithm_Norm.Pass)"})@$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)$(if ($MainAlgorithm_Norm -eq "Equihash24x5") {" -pers $(Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto")"}) -watchdog=false -no-runtime-info -gpucheck=0 $($_.Params)"
							HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Session.Stats."$($Miner_Name)_$($MainAlgorithm_Norm -replace '\-.*$')_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
							API            = "Bminer"
							Port           = $Miner_Port
							Uri            = $Uri
							DevFee         = $_.DevFee
							FaultTolerance = $_.FaultTolerance
							ExtendInterval = $_.ExtendInterval
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
						}
					} else {
						$Miner_Name = (@($Name) + @($MainAlgorithm_Norm) + @($SecondAlgorithm_Norm) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $($Stratum)://$(Get-UrlEncode $Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$MainAlgorithm_Norm.Pass)"})@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -uri2 $($SecondAlgorithm)://$(Get-UrlEncode $Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$SecondAlgorithm_Norm.Pass)"})@$($Pools.$SecondAlgorithm_Norm.Host):$($Pools.$SecondAlgorithm_Norm.Port) -watchdog=false -no-runtime-info -gpucheck=0 $($_.Params)"
							HashRates      = [PSCustomObject]@{
								                $MainAlgorithm_Norm = $($Session.Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
								                $SecondAlgorithm_Norm = $($Session.Stats."$($MinerName)_$($SecondAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
							                 }
							API            = "Bminer"
							Port           = $Miner_Port
							Uri            = $Uri
							DevFee         = [PSCustomObject]@{
								                ($MainAlgorithm_Norm) = $_.DevFee
								                ($SecondAlgorithm_Norm) = 0
							                 }
							FaultTolerance = $_.FaultTolerance
							ExtendInterval = $_.ExtendInterval
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
						}
					}
				}
			}
        }
    }
}