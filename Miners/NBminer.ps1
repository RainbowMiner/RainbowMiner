using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-NBMiner\nbminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v22.3-nbminer/NBMiner_22.3_Win.zip"
$ManualURI = "https://github.com/NebuTech/NBMiner/releases"
$Port = "340{0:d2}"
$DevFee = 2.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Aeternity";    SecondaryAlgorithm = ""; Params = "-a cuckoo_ae --cuckoo-intensity 1";     NH = $true; MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Aeternity
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29";   SecondaryAlgorithm = ""; Params = "-a cuckaroo --cuckoo-intensity 1";      NH = $true; MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckaroo29
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";  SecondaryAlgorithm = ""; Params = "-a cuckaroo_swap --cuckoo-intensity 1"; NH = $true; MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckaroo29
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";   SecondaryAlgorithm = ""; Params = "-a cuckatoo --cuckoo-intensity 1";      NH = $true; MinMemGb = 8;  MinMemGbW10 = 10; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = ""; Params = "-a ethash";        NH = $true; MinMemGb = 4;  DevFee = 0.65; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Tensority";    SecondaryAlgorithm = "Ethash"; Params = "-a tensority_ethash"; NH = $true; MinMemGb = 4; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Tensority";    SecondaryAlgorithm = ""; Params = "-a tensority";     NH = $true; MinMemGb = 1;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #BTM
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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

foreach ($Miner_Vendor in @("NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm,"$($MainAlgorithm_Norm)-$($Miner_Model)")) {
				$SecondAlgorithm = $_.SecondaryAlgorithm
				if ($SecondAlgorithm -ne '') {
					$SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
				}
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and ($_.NH -or ($Pools.$MainAlgorithm_Norm.Name -ne "Nicehash" -and ($SecondAlgorithm -eq '' -or $Pools.$SecondAlgorithm_Norm.Name -ne "Nicehash")))) {
					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

					$DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

                    $Stratum = $Pools.$MainAlgorithm_Norm.Protocol
                    if ($MainAlgorithm_Norm -eq "Ethash") {$Stratum = $Stratum -replace "stratum","$(if ($Pools.$MainAlgorithm_Norm.Name -eq "Nicehash") {"ethnh"} else {"ethproxy"})"}

					if ($SecondAlgorithm -eq '') {
						$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
						[PSCustomObject]@{
							Name = $Miner_Name
							DeviceName = $Miner_Device.Name
							DeviceModel = $Miner_Model
							Path = $Path
							Arguments = "--api 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -o $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"}) $($_.Params)"
							HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $Session.Stats."$($Miner_Name)_$($MainAlgorithm_Norm -replace '\-.*$')_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
							API = "NBminer"
							Port = $Miner_Port
							Uri = $Uri
							DevFee = $_.DevFee
							FaultTolerance = $_.FaultTolerance
							ExtendInterval = $_.ExtendInterval
							ManualUri = $ManualUri
							NoCPUMining = $_.NoCPUMining
                            MultiProcess = 1
						}
					} else {
						$Miner_Name = (@($Name) + @($MainAlgorithm_Norm) + @($SecondAlgorithm_Norm) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $Stratum2 = $Pools.$SecondAlgorithm_Norm.Protocol
                        if ($SecondAlgorithm_Norm -eq "Ethash") {$Stratum2 = $Stratum2 -replace "stratum","$(if ($Pools.$SecondAlgorithm_Norm.Name -eq "Nicehash") {"ethnh"} else {"ethproxy"})"}
						[PSCustomObject]@{
							Name = $Miner_Name
							DeviceName = $Miner_Device.Name
							DeviceModel = $Miner_Model
							Path = $Path
							Arguments = "--api 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -o $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"}) -do $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -du $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"}) $($_.Params)"
							HashRates = [PSCustomObject]@{
								$MainAlgorithm_Norm = $($Session.Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
								$SecondAlgorithm_Norm = $($Session.Stats."$($MinerName)_$($SecondAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
							}
							API = "NBminer"
							Port = $Miner_Port
							Uri = $Uri
							DevFee = [PSCustomObject]@{
								($MainAlgorithm_Norm) = $_.DevFee
								($SecondAlgorithm_Norm) = 0
							}
							FaultTolerance = $_.FaultTolerance
							ExtendInterval = $_.ExtendInterval
							ManualUri = $ManualUri
							NoCPUMining = $_.NoCPUMining
                            MultiProcess = 1
						}
					}
				}
			}
        }
    }
}