using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$Port = "358{0:d2}"
$ManualURI = "https://github.com/RavenCommunity/kawpowminer/releases"
$DevFee = 0.0
$Version = "1.2.3"

if ($IsLinux) {

    if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.25")) {return}

    $Path = ".\Bin\GPU-KawPOWMiner\kawpowminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.3-kawpowminer/kawpowminer-ubuntu18-1.2.3.zip"
            Cuda = "10.2"
        }
    )
    #https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.3-kawpowminer/kawpowminer-ubuntu16-1.2.3.zip
} else {
    $Path = ".\Bin\GPU-KawPOWMiner\kawpowminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.3-kawpowminer/kawpowminer-windows-1.2.3.zip"
            Cuda = "10.2"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "kawpow"; MinMemGB = 3; Params = ""; ExtendInterval = 2} #KawPOW
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Uri = $UriCuda[0].Uri

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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {
    $Cuda = 0
    for($i=0;$i -le $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri = $UriCuda[$i].Uri
            $Cuda= $UriCuda[$i].Cuda
            if ($UriCuda[$i].Version -ne $null) {
                $Version = $UriCuda[$i].Version
            }
        }
    }
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

            $CoinSymbol = if ($Pools.$Algorithm_Norm_0.CoinSymbol) {$Pools.$Algorithm_Norm_0.CoinSymbol} else {"RVN"}

            $MinMemGB = if ($Pools.$Algorithm_Norm_0.EthDAGSize) {$Pools.$Algorithm_Norm_0.EthDAGSize} else {Get-EthDAGSize $CoinSymbol}

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
                        $First = $false
                    }

				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                    $Miner_Protocol = Switch ($Pools.$Algorithm_Norm.EthMode) {
                        "stratum"          {"stratum+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                        "ethproxy"         {"stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
						"ethstratumnh"     {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
						default            {"stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})"}
					}

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--api-port -`$mport $($Miner_Deviceparams) $($DeviceIDsAll) -P $($Miner_Protocol)://$(Get-UrlEncode $Pools.$Algorithm_Norm.User -ConvertDot:$($Pools.$Algorithm_Norm.EthMode -ne "ethproxy"))$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass -ConvertDot)"})@$($Pools.$Algorithm_Norm.Host):$($Pool_Port) --HWMON 0 $($_.Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week }
					    API            = "Claymore"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        ManualUri      = $ManualUri
					    FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = $DevFee
                        EnvVars        = if ($Miner_Vendor -eq "AMD") {@("GPU_FORCE_64BIT_PTR=0")} else {$null}
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