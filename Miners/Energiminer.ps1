using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-NVIDIA-Energiminer\energiminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2.1-energiminer/energiminer-2.2.1-Windows.zip"
$ManualUri = "https://github.com/energicryptocurrency/energiminer/releases"
$Port = "334{0:d2}"
$DevFee = 0.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "nrghash"; Params = ""} #Nrghash
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
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Model = $_.Model
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '

        $Commands | ForEach-Object {

            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

			foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
					$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
					[PSCustomObject]@{
						Name = $Miner_Name
						DeviceName = $Miner_Device.Name
						DeviceModel = $Miner_Model
						Path = $Path
						Arguments = "$(if ($Miner_Vendor -eq "AMD") {"-G --opencl-platform $($Miner_Device | Select -Unique -ExpandProperty PlatformId) --opencl-devices"} else {"-U --cuda-devices"}) $($DeviceIDsAll) -P stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$(Get-UrlEncode $Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pool_Port) --exit --nocolor $($_.Params)"
						HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
						API = "Wrapper"
						Port = $Miner_Port
						Uri = $Uri
						DevFee = $DevFee
						FaultTolerance = $_.FaultTolerance
						ExtendInterval = $_.ExtendInterval
						ManualUri = $ManualUri
						ShowMinerWindow = $false
					}
				}
			}
        }
    }
}