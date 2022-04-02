using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://github.com/tecracoin/ccminer/releases"
$Port = "127{0:d2}"
$DevFee = 0.0

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CcminerMTP10\ccminer_linux_cuda"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-linux-cuda102.7z"
            Cuda = "10.2"
            Version = "1.2.10"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-linux-cuda100.7z"
            Cuda = "10.0"
            Version = "1.2.10"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-linux-cuda92.7z"
            Cuda = "9.2"
            Version = "1.2.10"
        }
    )
    $UseCPUAffinity = $true
} else {
    $Path = ".\Bin\NVIDIA-CcminerMTP10\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-win.7z"
            Cuda = "10.2"
            Version = "1.2.10"
        }
    )
    $UseCPUAffinity = $false
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "mtp-classic"; MinMemGB = 5; Params = ""; ExtendInterval = 2; ExcludePoolName = "(MiningRigRentals|NiceHash)"} #MTP
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr"; MinMemGB = 5; Params = ""; ExtendInterval = 2; ExcludePoolName = "(MiningRigRentals|NiceHash)"} #MTPTcr
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
        $Version = $UriCuda[$i].Version
    }
}

if (-not $Cuda) {return}

if ($IsLinux) {$Path += $Cuda -replace "\."}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({
        $First = $true
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB
        $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGB) -and $_.OpenCL.Architecture -in @("Other","Pascal","Turing")}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if (-not $Pools.$Algorithm_Norm.SSL -and $Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Miner_Device | Measure-Object).Count -le 6 -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
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
					Arguments      = "-R 1 -N 3 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($UseCPUAffinity) {" --cpu-affinity 1"}) --no-donation $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = 0.0
					ManualUri      = $ManualUri
                    MiningPriority = 2
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    ExcludePoolName= $_.ExcludePoolName
				}
			}
		}
    })
}