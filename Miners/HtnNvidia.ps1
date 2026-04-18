using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux) {return}
if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {return} # No ARM binaries available
if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.30")) {return}

$ManualUri = "https://htn.foztor.net/"
$Port = "379{0:d2}"
$DevFee = 1.5
$Version = "1.4.9"

$Path = ".\Bin\NVIDIA-Htn\hoo_gpu"
$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.9-htm/hoo_gpu-1.4.9.tar.gz"
        Cuda = "12.0"
    }
)

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "hoohashpepew"; MinMemGB = 2; Params = "--pepepow"; Vendor = @("NVIDIA")} #PEPEW/HoohashPepeW
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
    }
}

if (-not $Cuda) {return}

$Miner_EnvVars = "LD_LIBRARY_PATH=./libs"

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

    $Commands | ForEach-Object {
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $false
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = if ($_.Path) {$_.Path} else {$Path}
					Arguments      = "-b 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) -q $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    PrerequisitePath = $null
                    PrerequisiteURI  = $null
                    PrerequisiteMsg  = $null
                    ExcludePoolName = $_.ExcludePoolName
                    EnvVars        = $Miner_EnvVars
				}
			}
		}
    }
}
