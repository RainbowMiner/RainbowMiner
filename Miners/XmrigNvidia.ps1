using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-Xmrig\xmrig-nvidia.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.14.1-xmrig/xmrig-nvidia-2.14.1-msvc-win64-rbm.7z"
$ManualUri = "https://github.com/xmrig/xmrig-nvidia/releases"
$Port = "303{0:d2}"
$DevFee = 0.0
$Cuda = "10.0"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1";          MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/2";          MinMemGb = 2; Params = "--bfactor=12"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/double";     MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/gpu";        MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/half";       MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast";       MinMemGb = 2; Params = ""; Algorithm = "cryptonight/msr"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/r";          MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rwz";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/wow";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/zls";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     MinMemGb = 1; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     MinMemGb = 1; Params = ""}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-turtle";     MinMemGb = 4; Params = ""}
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

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params

        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
				$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

				$DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

				$xmrig_algo = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name = $Miner_Name
					DeviceName = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path      = $Path
					Arguments = "-R 1 --cuda-devices=$($DeviceIDsAll) --api-port $($Miner_Port) -a $($xmrig_algo) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --keepalive $(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") {"--nicehash"}) --donate-level=0 $($Params)"
					HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API       = "XMRig"
					Port      = $Miner_Port
					Uri       = $Uri
					DevFee    = $DevFee
					ManualUri = $ManualUri
				}
			}
		}
    }
}