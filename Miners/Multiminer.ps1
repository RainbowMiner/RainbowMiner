using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Path = ".\Bin\GPU-Multiminer\multiminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.0-multiminerrbm/multiminer-rbm-v1.2.0a-win64.7z"
$ManualUri = "https://github.com/RainbowMiner/multiminer/releases"
$Port = "339{0:d2}"
$DevFee = 0.0
$Cuda = "10.2"
$Version = "1.2.0a"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2ad";    MinMemGb = 2;  Params = ""; Blocksize = 8192;  ExtendInterval = 3; Vendor = ("AMD","NVIDIA")} #Argon2ad
    [PSCustomObject]@{MainAlgorithm = "argon2d250";  MinMemGb = 2;  Params = ""; Blocksize = 250;   ExtendInterval = 3; Vendor = ("AMD","NVIDIA")} #Argon2d250
    [PSCustomObject]@{MainAlgorithm = "argon2d500";  MinMemGb = 2;  Params = ""; Blocksize = 500;   ExtendInterval = 3; Vendor = ("AMD","NVIDIA")} #Argon2d500
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; MinMemGb = 2;  Params = ""; Blocksize = 4096;  ExtendInterval = 3; Vendor = ("AMD","NVIDIA")} #Argon2d4096
    [PSCustomObject]@{MainAlgorithm = "argon2d16000"; MinMemGb = 2; Params = ""; Blocksize = 16000; ExtendInterval = 3; Vendor = ("AMD","NVIDIA")} #Argon2d16000
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
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Miner_Vendor = $_.Vendor
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

        $DeviceIndex = if ($Miner_Vendor -eq "AMD") {"Type_Index"} else {"Type_Vendor_Index"}

        $Commands.Where({$Miner_Vendor -in $_.Vendor}).ForEach({
            $First = $true
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $Blocksize = 32*$_.Blocksize/0.865/1MB

            $MinMemGB = $_.MinMemGB        
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = ($Miner_Device | ForEach-Object {$_.$DeviceIndex +1}) -join ','
                        $BatchSize    = ($Miner_Device | Foreach-Object {[Math]::Floor($_.OpenCL.GlobalMemsizeGB/$Blocksize)} | Measure-Object -Minimum).Minimum*32
                        $First = $false
                    }
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "-R 1 -b `$mport -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --gpu-id=$($DeviceIDsAll) --use-gpu=$(if ($Miner_Vendor -eq "AMD") {"OpenCL"} else {"CUDA"}) -q --gpu-batchsize=$($BatchSize) -t 1 $($_.Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API            = "Ccminer"
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
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				    }
			    }
		    }
        })
    }
}