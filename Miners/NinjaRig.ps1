using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\ANY-NinjaRig\ninjarig"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.3-ninjarig/ninjarig-v1.0.3-linux.7z"
    $Version = "1.0.3"
} else {
    $Path = ".\Bin\ANY-NinjaRig\ninjarig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.3-ninjarig/ninjarig-v1.0.3-win64.7z"
    $Version = "1.0.3"
}
$ManualUri = "https://github.com/turtlecoin/ninjarig/releases"
$Port = "348{0:d2}"
$DevFee = 1.0
$Cuda = "10.1"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "chukwa"; MinMemGb = 1; NH = $true; ExtendInterval = 2} #Argon2/Chukwa
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
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

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | ForEach-Object {
            $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {$_.Model -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

            $DeviceIDsAll = ($Miner_Device | % {'[{0:d}]' -f ($_.Type_Vendor_Index+1)} ) -join ','
            
            $DeviceParams = Switch ($Miner_Vendor) {
                "CPU"    {"$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"})$(if ($Session.Config.CPUMiningAffinity -ne ''){" --cpu-affinity $($Session.Config.CPUMiningAffinity)"})$($f=$Global:GlobalCPUInfo.Features;if($f.avx2 -and $f.aes){" --cpu-optimization AVX2"})"}
                "AMD"    {"-t 0 --use-gpu=OPENCL --gpu-filter=$DeviceIDsAll"}
                "NVIDIA" {"-t 0 --use-gpu=CUDA --gpu-filter=$DeviceIDsAll"}
            }

            $Miner_Type = if ($Miner_Vendor -eq "CPU") {"CPU"} else {"GPU"}

		    foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "Nicehash")) {
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.$Miner_Type) {$Pools.$Algorithm_Norm.Ports.$Miner_Type} else {$Pools.$Algorithm_Norm.Port}
				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
                        Arguments      = "--api-port=$($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams)$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"}) $($_.Params) -c params.json --donate-level=1"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
					    API            = "XMRig"
					    Port           = $Miner_Port
					    DevFee         = $DevFee
					    Uri            = $Uri
					    FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    ManualUri      = $ManualUri
					    NoCPUMining    = $_.NoCPUMining
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				    }
			    }
		    }
        }
    }
}