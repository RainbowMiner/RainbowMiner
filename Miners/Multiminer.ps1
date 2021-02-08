﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\Argon2d-Multiminer\multiminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha){'avx2-sha'}elseif($f.avx2){'avx2'}elseif($f.aes -and $f.avx){'aes-avx'}elseif($f.aes -and $f.sse42){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'})).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.1.0-multiminer/multiminer_v1.1.0_24.01.2019.zip"
$ManualUri = "https://github.com/bogdanadnan/multiminer/releases"
$Port = "339{0:d2}"
$DevFee = 1.0
$Cuda = "10.0"
$Version = "1.1.0"

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "argon2ad";    MinMemGb = 2; Params = "--gpu-batchsize=512 -t 1"} #Argon2ad
    #[PSCustomObject]@{MainAlgorithm = "argon2d250";  MinMemGb = 2; Params = "--gpu-batchsize=2048 -t 1"} #Argon2d250
    #[PSCustomObject]@{MainAlgorithm = "argon2d500";  MinMemGb = 2; Params = "--gpu-batchsize=1024 -t 1"} #Argon2d500
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; MinMemGb = 2; Params = "--gpu-batchsize=256 -t 1"; ExtendInterval = 3} #Argon2d4096
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

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Miner_Vendor = $_.Vendor
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({
        $First = $true
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB        
        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = ($Miner_Device | ForEach-Object {$_.Type_Vendor_Index +1}) -join ','
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-R 1 -b `$mport -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --gpu-id=$($DeviceIDsAll) --use-gpu=$(if ($Miner_Vendor -eq "AMD") {"OpenCL"} else {"CUDA"}) -q $($_.Params)"
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
				}
			}
		}
    })
}