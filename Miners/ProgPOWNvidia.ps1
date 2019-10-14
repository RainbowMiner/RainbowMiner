using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$Port = "331{0:d2}"
$ManualURI = "https://github.com/BitcoinInterestOfficial/BitcoinInterest/releases"
$DevFee = 0.0
$Version = "0.16"

if ($IsLinux) {
    $UriCuda = @(
        [PSCustomObject]@{
            Path = ".\Bin\NVIDIA-ProgPOW\progpowminer_cuda10"
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16-progpowminer/progpow_linux_0.16_final.7z"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Path = ".\Bin\NVIDIA-ProgPOW\progpowminer_cuda9.2"
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16-progpowminer/progpow_linux_0.16_final.7z"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Path = ".\Bin\NVIDIA-ProgPOW\progpowminer_cuda9.1"
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16-progpowminer/progpow_linux_0.16_final.7z"
            Cuda = "9.1"
        }
    )
} else {
    $UriCuda = @(
        [PSCustomObject]@{
            Path = ".\Bin\NVIDIA-ProgPOW\progpowminer-cuda.exe"
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16-progpowminer/progpowminer-cuda10.0-windows-0.16_final.7z"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Path = ".\Bin\NVIDIA-ProgPOW\progpowminer-cuda.exe"
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16-progpowminer/progpowminer-cuda9.2-windows-0.16_final.7z"
            Cuda = "9.2"
        }
    )
}

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "progpow"; Params = ""; ExtendInterval = 2} #ProgPOW
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $UriCuda.Path | Select-Object -First 1
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Uri = $Path = ""
for($i=0;$i -le $UriCuda.Count -and -not $Uri;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Path= $UriCuda[$i].Path
        $Uri = $UriCuda[$i].Uri
        $Cuda= $UriCuda[$i].Cuda
    }
}
if (-not $Uri) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
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
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api-port -$($Miner_Port) -P stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$(Get-UrlEncode $Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --cuda --cuda-devices $($DeviceIDsAll) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week }
					API            = "Claymore"
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
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}