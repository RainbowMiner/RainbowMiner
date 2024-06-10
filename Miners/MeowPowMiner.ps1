using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Version = "2.0.0"
$ManualUri = "https://github.com/Meowcoin-Foundation/meowpowminer/releases"
$Port = "336{0:d2}"
$DevFee = 0.0

if ($IsLinux) {

    if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.25")) {return}

    $Path = ".\Bin\NVIDIA-MeowPow\meowpowminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.0.0-meowpowminer/meopowminer_2.0.0_linux.7z"
            Cuda = "12.0"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-MeowPow\meowpowminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.0.0-meowpowminer/meopowminer_2.0.0_win.7z"
            Cuda = "12.0"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "meowpow"    ; MinMemGB = 4; Params = @(); ExtendInterval = 3} #Ethash DAG >= 4GB
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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
if ($Session.Config.CUDAVersion) {
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if (($i -lt $UriCuda.Count-1) -or -not $Global:DeviceCache.DevicesByTypes.NVIDIA) {""}else{$Name})) {
            $Uri  = $UriCuda[$i].Uri
            $Cuda = $UriCuda[$i].Cuda
        }
    }
}

if (-not $Cuda) {
    $Uri = $UriCuda[0].Uri
}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
		$Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

		switch($_.Vendor) {
			"NVIDIA" {$Miner_Deviceparams = "--cuda --cuda-devices"}
			"AMD" {$Miner_Deviceparams = "--opencl --opencl-devices"}
			Default {$Miner_Deviceparams = ""}
		}

		$Commands.ForEach({
            $First = $true
			$Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

			$MinMemGB = Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb

            $Miner_Device = $Device.Where({Test-VRAM $_ $MinMemGB})

			foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
			            $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join ' '
                        $First = $false
                    }
					$Miner_Protocol = "stratum"

					$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                    $Miner_Protocol_Auto = $false
                    $Miner_Protocol = Switch ($Pools.$Algorithm_Norm.EthMode) {
                        "stratum"          {"stratum+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethproxy"         {"stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethstratum2"      {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
						"ethstratumnh"     {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
						default            {"stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})";$Miner_Protocol_Auto = $true}
					}

                    if ($Pools.$Algorithm_Norm.Host -match "F2pool" -and $Pools.$Algorithm_Norm.User -match "^0x[0-9a-f]{40}") {$Pool_Port = 8008}

                    $EnvVars = @()
                    if ($Pools.$Algorithm_Norm.SSL) {
                        $EnvVars += "SSL_NOVERIFY=1"
                    }

                    if ($Miner_Vendor -eq "AMD") {
                        $EnvVars += "GPU_FORCE_64BIT_PTR=0"
                    }


					[PSCustomObject]@{
						Name           = $Miner_Name
						DeviceName     = $Miner_Device.Name
						DeviceModel    = $Miner_Model
						Path           = $Path
						Arguments      = "--api-port `$mport $($Miner_Deviceparams) $($DeviceIDsAll) -P $($Miner_Protocol)://$(Get-UrlEncode $Pools.$Algorithm_Norm.User -ConvertDot:$($Pools.$Algorithm_Norm.EthMode -ne "ethproxy"))$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass -ConvertDot)"})@$($Pools.$Algorithm_Norm.Host):$($Pool_Port) --HWMON 2$(if (-not $Miner_Protocol_Auto) {" --farm-recheck 3000 --farm-retries 20 --work-timeout 900 --response-timeout 180"}) --exit $($_.Params)"
						HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
						API            = "Ethminer"
						Port           = $Miner_Port
						Uri            = $Uri
						ManualUri      = $ManualUri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
                        DevFee         = 0
                        EnvVars        = if ($EnvVars.Count) {$EnvVars} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        ListDevices    = "--list-devices"
					}
				}
			}
		})
	}
}