using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\ANY-6miner\6miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.0.5-6miner/6miner-v0.0.5-amd64-linux.tar.gz"
} else {
    $Path = ".\Bin\ANY-6miner\6miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.0.5-6miner/6miner-v0.0.5-x64-windows.zip"
}
$Port = "356{0:d2}"
$ManualURI = "https://github.com/6block/6miner/releases"
$DevFee = 3.0
$Version = "0.0.5"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "bl2bsha3"; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU")} #Blake2b+SHA3 / HNS (NBminer lot's faster for NVIDIA)
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

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Select-Object Vendor, Model -Unique | ForEach-Object {
        $First = $true
        $Miner_Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$Miner_Vendor -in $_.Vendor} | ForEach-Object {

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

                $DeviceParams = "$(if ($CPUThreads){" --threads=$CPUThreads"})$(if ($false -and $CPUAffinity){" --cpu-affinity $CPUAffinity"})"
            }

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
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
                        Arguments      = "-a hns/bl2bsha3 -o $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $(if ($Miner_Vendor -eq "CPU") {"-m cpu$DeviceParams"} else {"-m opencl --opcl-vendor=$($Miner_Vendor.ToLower()) --opcl-no-cuda-fix --devices=$DeviceIDsAll"})"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week }
					    API            = "SixMinerWrapper"
					    Port           = $Miner_Port
					    Uri            = $Uri
					    FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = $DevFee
					    ManualUri      = $ManualUri
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
				    }
			    }
		    }
        }
    }
}