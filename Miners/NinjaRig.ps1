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

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "chukwa"; MinMemGb = 1; ExtendInterval = 2} #Argon2/Chukwa
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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.ForEach({
            $First = $true
            $Miner_Device = $Device | Where-Object {$_.Model -eq "CPU" -or (Test-VRAM $_ $MinMemGb)}

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

                $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity"})"
                $Miner_Type   = "CPU"

                $All_Algorithms = @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")
            } else {
                $DeviceParams = ""
                $Miner_Type   = "GPU"

                $All_Algorithms = @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")
            }

		    foreach($Algorithm_Norm in $All_Algorithms) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = ($Miner_Device | % {'[{0:d}]' -f ($_.Type_Vendor_Index+1)} ) -join ','
            
                        $DeviceParamsGlobal = Switch ($Miner_Vendor) {
                            "CPU"    {"$($f=$Global:GlobalCPUInfo.Features;if($f.avx2 -and $f.aes){" --cpu-optimization AVX2"})"}
                            "AMD"    {" -t 0 --use-gpu=OPENCL --gpu-filter=$DeviceIDsAll"}
                            "NVIDIA" {" -t 0 --use-gpu=CUDA --gpu-filter=$DeviceIDsAll"}
                        }
                        $First = $false
                    }
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.$Miner_Type) {$Pools.$Algorithm_Norm.Ports.$Miner_Type} else {$Pools.$Algorithm_Norm.Port}
				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
                        Arguments      = "--api-port=`$mport -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass=$($Pools.$Algorithm_Norm.Pass)"})$($DeviceParamsGlobal)$($DeviceParams)$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"}) $($_.Params) -c params.json --donate-level=1"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
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
                        BaseAlgorithm  = $Algorithm_Norm_0
				    }
			    }
		    }
        })
    }
}