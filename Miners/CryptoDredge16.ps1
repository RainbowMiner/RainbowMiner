﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -or $Session.IsVM) {return}

$Path = ".\Bin\NVIDIA-CryptoDredge16\CryptoDredge.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=4807821"
$Port = "338{0:d2}"
$DevFee = 1.0
$Version = "0.16.0"
$Enable_Logfile = $false
$DeviceCapability = "5.0"

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16.0-cryptodredge/CryptoDredge_0.16.0_cuda_10.0_windows.zip"
        Cuda = "10.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16.0-cryptodredge/CryptoDredge_0.16.0_cuda_9.2_windows.zip"
        Cuda = "9.2"
    }
)

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium";      MinMemGb = 1; Params = ""} #Allium
    [PSCustomObject]@{MainAlgorithm = "bitcore";     MinMemGb = 1; Params = ""} #BitCore
    #[PSCustomObject]@{MainAlgorithm = "exosis";      MinMemGb = 1; Params = ""} #Exosis (EXO is x16r)
    #[PSCustomObject]@{MainAlgorithm = "hmq1725";     MinMemGb = 1; Params = ""} #HMQ1725 (CD 0.23.0 faster)
    #[PSCustomObject]@{MainAlgorithm = "lyra2z";      MinMemGb = 1; Params = ""} #Lyra2z
    #[PSCustomObject]@{MainAlgorithm = "lyra2v3";     MinMemGb = 1; Params = ""} #Lyra2Re3 (CD 0.22.0 faster)
    [PSCustomObject]@{MainAlgorithm = "phi2";        MinMemGb = 1; Params = ""} #PHI2
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
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
    }
}

if (-not $Cuda) {return}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model -and (-not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)})

    if (-not $Device) {return}

    $Commands.ForEach({
        $First = $true

        $Miner_Device = $Device | Where-Object {$_.OpenCL.Architecture -in @("Other","Pascal","Turing")}

        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        
		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                if ($First) {
		            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
	                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-r 10 -R 1 -b 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Enable_Logfile) {" --log log_`$mport.txt"}) $($_.Params) --no-nvml"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = if ($_.DevFee -ne $null) {$_.DevFee} else {$DevFee}
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    MiningPriority = -2
                    MiningAffinity = "0x1"
				}
			}
		}
    })
}