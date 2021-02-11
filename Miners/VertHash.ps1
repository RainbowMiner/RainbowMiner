using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$Port = "364{0:d2}"
$ManualURI = "https://github.com/CryptoGraphics/VerthashMiner/releases"
$DevFee = 0.0
$Version = "0.6.2"

if ($IsLinux) {
    $Path = ".\Bin\GPU-Verthash\VerthashMiner"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6.2-verthash/VerthashMiner-0.6.2-CUDA11-linux.tar.gz"
            DatFile = "$env:HOME/.vertcoin/verthash.dat"
            Cuda = "11.0"
        }
    )
} else {
    $Path = ".\Bin\GPU-Verthash\VerthashMiner.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6.2-verthash/VerthashMiner-0.6.2-CUDA11-windows.zip"
            DatFile = "$env:APPDATA\Vertcoin\verthash.dat"
            Cuda = "11.0"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "verthash"; MinMemGB = 2; Params = ""; ExtendInterval = 2} #VertHash
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
if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri     = $UriCuda[$i].Uri
            $Cuda    = $UriCuda[$i].Cuda
            $DatFile = $UriCuda[$i].DatFile
        }
    }
}

if (-not $Cuda) {
    $Uri     = $UriCuda[0].Uri
    $DatFile = $UriCuda[0].DatFile
}

if (-not (Test-Path $DatFile) -or (Get-Item $DatFile).length -lt 1.19GB) {
    $DatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
    if ((Test-Path $DatFile) -and (Get-Item $DatFile).length -lt 1.19GB) {
        Remove-Item $DatFile -ErrorAction Ignore
    }
}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
		$Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

		switch($_.Vendor) {
			"NVIDIA" {$Miner_Deviceparams = "--cu-devices"; $Miner_DeviceIndex = "Type_Vendor_Index"}
			"AMD" {$Miner_Deviceparams = "--cl-devices"; $Miner_DeviceIndex = "BusId_Index"}
			Default {$Miner_Deviceparams = "";$Miner_DeviceIndex = "BusId_Index"}
		}

        $Commands.ForEach({
            $First = $true
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $CoinSymbol = if ($Pools.$Algorithm_Norm_0.CoinSymbol) {$Pools.$Algorithm_Norm_0.CoinSymbol} else {"VTC"}

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.$Miner_DeviceIndex -join ','
                        $First = $false
                    }

				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				    [PSCustomObject]@{
					    Name             = $Miner_Name
					    DeviceName       = $Miner_Device.Name
					    DeviceModel      = $Miner_Model
					    Path             = $Path
					    Arguments        = "$($Miner_Deviceparams) $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --verthash-data '$($DatFile)' $($_.Params)"
					    HashRates        = [PSCustomObject]@{$Algorithm_Norm   = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week }
					    API              = "VerthashWrapper"
					    Port             = $Miner_Port
					    Uri              = $Uri
                        ManualUri        = $ManualUri
					    FaultTolerance   = $_.FaultTolerance
					    ExtendInterval   = $_.ExtendInterval
                        Penalty          = 0
					    DevFee           = $DevFee
                        EnvVars          = if ($Miner_Vendor -eq "AMD") {@("GPU_FORCE_64BIT_PTR=0")} else {$null}
                        Version          = $Version
                        PowerDraw        = 0
                        BaseName         = $Name
                        BaseAlgorithm    = $Algorithm_Norm_0
                        PrerequisitePath = $DatFile
                        PrerequisiteURI  = "https://vtc.suprnova.cc/verthash.dat"
                        PrerequisiteMsg  = "$($Name): Downloading verthash.dat (1.2GB) in the background, please wait!"
				    }
			    }
		    }
        })
    }
}