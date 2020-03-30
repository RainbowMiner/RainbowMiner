using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-NBMiner\nbminer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v28.1-nbminer/NBMiner_28.1_Linux.tgz"
} else {
    $Path = ".\Bin\GPU-NBMiner\nbminer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v28.1-nbminer/NBMiner_28.1_Win.zip"
}
$ManualURI = "https://github.com/NebuTech/NBMiner/releases"
$Port = "340{0:d2}"
$DevFee = 2.0
$Cuda = "9.1"
$Version = "28.1"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$CuckooIntensity = if ($Global:GlobalCPUInfo.Cores -eq 1 -or $Global:GlobalCPUInfo.Threads -lt 4 -or $Global:GlobalCPUInfo.Name -match "Celeron") {4} else {2}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Aeternity";    SecondaryAlgorithm = ""; Params = "-a cuckoo_ae --cuckoo-intensity $CuckooIntensity";     NH = $true;  MinMemGb = 5; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckoo29/Aeternity
    [PSCustomObject]@{MainAlgorithm = "CuckooBFC";    SecondaryAlgorithm = ""; Params = "-a bfc --cuckoo-intensity $CuckooIntensity";           NH = $true;  MinMemGb = 5; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckoo29/BFC
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29";   SecondaryAlgorithm = ""; Params = "-a cuckaroo --cuckoo-intensity $CuckooIntensity";      NH = $true;  MinMemGb = 5; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckaroo29/BitGRIN
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";  SecondaryAlgorithm = ""; Params = "-a cuckarood --cuckoo-intensity $CuckooIntensity";     NH = $true;  MinMemGb = 5; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckarood29/GRIN
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";  SecondaryAlgorithm = ""; Params = "-a cuckaroo_swap --cuckoo-intensity $CuckooIntensity"; NH = $true;  MinMemGb = 5; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckaroo29s/SWAP
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";   SecondaryAlgorithm = ""; Params = "-a cuckatoo --cuckoo-intensity $CuckooIntensity";      NH = $true;  MinMemGb = 8; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Eaglesong";    SecondaryAlgorithm = ""; Params = "-a eaglesong";     NH = $true; MinMemGb = 4; DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #CKB
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 1;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 2;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 3;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 4;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 5;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 6;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 7;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 8;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 9;  Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Intensity = 10; Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = ""; Params = "-a ethash";        NH = $true; MinMemGb = 3;  DevFee = 0.65; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ProgPowSero";  SecondaryAlgorithm = ""; Params = "-a progpow_sero";  NH = $true; MinMemGb = 3;  DevFee = 0.65; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #ProgPowSero
    [PSCustomObject]@{MainAlgorithm = "ScryptSIPC";   SecondaryAlgorithm = ""; Params = "-a sipc";          NH = $true; MinMemGb = 1;  DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 1;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 2;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 3;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 4;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    #[PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 5;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 6;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 7;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 8;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 9;  Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Intensity = 10; Params = "-a tensority_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Tensority";    SecondaryAlgorithm = ""; Params = "-a tensority";     NH = $true; MinMemGb = 1;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #BTM
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 1;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 2;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 3;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 4;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 5;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 6;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 7;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 8;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 9;  Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Blake2bSHA3"; Intensity = 10; Params = "-a hns_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + HNS
    [PSCustomObject]@{MainAlgorithm = "Blake2bSHA3";  SecondaryAlgorithm = ""; Params = "-a hns";     NH = $true; MinMemGb = 1;  DevFee = 2.0;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #HNS
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 1;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 2;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 3;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 4;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 5;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 6;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 7;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 8;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 9;  Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tellor"; Intensity = 10; Params = "-a trb_ethash"; NH = $true; MinMemGb = 3; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + TRB
    [PSCustomObject]@{MainAlgorithm = "Tellor";  SecondaryAlgorithm = ""; Params = "-a trb";     NH = $true; MinMemGb = 1;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #TRB
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
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true

            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm

			$SecondAlgorithm = $_.SecondaryAlgorithm
			$SecondAlgorithm_Norm = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $DualIntensity = $_.Intensity

            $MinMemGB = if ($MainAlgorithm_Norm_0 -eq "Ethash") {if ($Pools.$MainAlgorithm_Norm_0.EthDAGSize) {$Pools.$MainAlgorithm_Norm_0.EthDAGSize} else {Get-EthDAGSize $Pools.$MainAlgorithm_Norm_0.CoinSymbol}} else {$_.MinMemGb}

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

            if ($SecondAlgorithm_Norm) {
                $Miner_Config = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)".Intensity
                if ($Miner_Config -and $Miner_Config -notcontains $DualIntensity) {$Miner_Device = $null}
            }

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and 
                        #($MainAlgorithm -ne "Ethash" -or $Pools.$MainAlgorithm_Norm.Name -ne "MiningRigRentals") -and 
                        ($_.NH -or ($Pools.$MainAlgorithm_Norm.Name -notmatch "Nicehash" -and ($SecondAlgorithm -eq '' -or $Pools.$SecondAlgorithm_Norm.Name -notmatch "Nicehash"))) -and
                        ($SecondAlgorithm -eq '' -or $Pools.$MainAlgorithm_Norm.Host -notmatch "MiningPoolHub")
                    ) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)$(if ($DualIntensity -ne $null) {"-$($DualIntensity)"})"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $offset = if ($Miner_Vendor -eq "AMD") {($Session.AllDevices | Where-Object Vendor -eq "NVIDIA" | Measure-Object).Count} else {0}
                        $DeviceIDsAll = ($Miner_Device | % {'{0:d}' -f ($_.Type_Vendor_Index + $offset)}) -join ','
                        if ($_.Intensity -ne $null) {
                            $DeviceIntensitiesAll = ",$($DualIntensity)"*($Miner_Device | Measure-Object).Count -replace '^,',' '
                        }
                        $First = $false
                    }
					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

                    $Stratum = $Pools.$MainAlgorithm_Norm.Protocol
                    if ($MainAlgorithm_Norm -match "^Ethash") {
                        Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                            "ethproxy" {$Stratum = $Stratum -replace "stratum","ethproxy"}
                            "ethstratumnh" {$Stratum = $Stratum -replace "stratum","nicehash"}
                        }
                    }

					if ($SecondAlgorithm -eq '') {
                        $FailoverMain = if ($Pools.$MainAlgorithm_Norm.Failover) {
                            $i=1;
                            @($Pools.$MainAlgorithm_Norm.Failover | Select-Object -First ([Math]::Min(2,$Pools.$MainAlgorithm_Norm.Failover.Count)) | Foreach-Object {
                                "-o$i $($Stratum)://$($_.Host):$($_.Port) -u$i $($_.User)$(if ($_.User -match '^solo:') {"."})$(if ($_.Pass) {":$($_.Pass)"})"
                                $i++
                            }) -join ' '
                        }
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "--api 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.User -match '^solo:') {"."})$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($FailoverMain) {" $FailoverMain"}) --no-watchdog --no-nvml $($_.Params)"
							HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
							API            = "NBminer"
							Port           = $Miner_Port
							Uri            = $Uri
							DevFee         = $_.DevFee
					        FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            EnvVars        = if ($IsLinux -and $MainAlgorithm_Norm_0 -match "^ProgPow" -and @($env:LD_LIBRARY_PATH -split ':' | Select-Object) -inotcontains "/tmp") {@("LD_LIBRARY_PATH=$(if ($env:LD_LIBRARY_PATH) {"$($env:LD_LIBRARY_PATH):"})/tmp")}
						}
					} else {
                        $Pool_Port2 = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                        $Stratum2 = $Pools.$SecondAlgorithm_Norm.Protocol
                        if ($SecondAlgorithm_Norm -match "^(Ethash|ProgPow)") {
                            Switch ($Pools.$SecondAlgorithm_Norm.EthMode) {
                                "ethproxy" {$Stratum2 = $Stratum2 -replace "stratum","ethproxy"}
                                "ethstratumnh" {$Stratum2 = $Stratum2 -replace "stratum","nicehash"}
                            }
                        }
                        $FailoverMain = if ($Pools.$MainAlgorithm_Norm.Failover) {
                            $i=1;
                            @($Pools.$MainAlgorithm_Norm.Failover | Select-Object -First ([Math]::Min(2,$Pools.$MainAlgorithm_Norm.Failover.Count)) | Foreach-Object {
                                "-do$i $($Stratum)://$($_.Host):$($_.Port) -du$i $($_.User)$(if ($_.User -match '^solo:') {"."})$(if ($_.Pass) {":$($_.Pass)"})"
                                $i++
                            }) -join ' '
                        }
                        $FailoverSecondary = if ($Pools.$SecondAlgorithm_Norm.Failover) {
                            $i=1;
                            @($Pools.$SecondAlgorithm_Norm.Failover | Select-Object -First ([Math]::Min(2,$Pools.$SecondAlgorithm_Norm.Failover.Count)) | Foreach-Object {
                                "-o$i $($Stratum2)://$($_.Host):$($_.Port) -u$i $($_.User)$(if ($_.User -match '^solo:') {"."})$(if ($_.Pass) {":$($_.Pass)"})"
                                $i++
                            }) -join ' '
                        }
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "--api 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Stratum2)://$($Pools.$SecondAlgorithm_Norm.Host):$($Pool_Port2) -u $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {":$($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($FailoverSecondary) {" $FailoverSecondary"}) -do $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -du $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.User -match '^solo:') {"."})$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($FailoverMain) {" $FailoverMain"}) -di$($DeviceIntensitiesAll) --no-watchdog --no-nvml $($_.Params)"
							HashRates      = [PSCustomObject]@{
                                                $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                							}
							API            = "NBminer"
							Port           = $Miner_Port
							Uri            = $Uri
							DevFee         = [PSCustomObject]@{
                                                ($MainAlgorithm_Norm) = $_.DevFee
                                                ($SecondAlgorithm_Norm) = 0
							                }
					        FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
                            EnvVars        = if ($Miner_Vendor -eq "AMD") {@("GPU_FORCE_64BIT_PTR=0")}
						}
					}
				}
			}
        }
    }
}