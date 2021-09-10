using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualURI = "https://github.com/sp-hash/TeamBlackMiner"
$Port = "365{0:d2}"
$Version = "1.01"

if ($IsLinux) {
    $Path     = ".\Bin\GPU-Teamblack\TBMiner"
    $Path_VTC = ".\Bin\GPU-Teamblack\SPMiner"

    $DatFile = "$env:HOME/verthash.dat"

    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.01-teamblack/TeamBlackMiner_1_01_Ubuntu_18_04_Cuda_11_4_beta.zip"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-teamblack/TeamBlackMiner_1_0_Cuda_11_2-Linux.zip"
            Cuda = "11.2"
            Version = "1.0"
        }
    )
} else {
    $Path     = ".\Bin\GPU-Teamblack\TBMiner.exe"
    $Path_VTC = ".\Bin\GPU-Teamblack\SPMiner.exe"

    $DatFile = "$env:APPDATA\verthash.dat"

    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.01-teamblack/TeamBlackMiner_1_01_cuda_11_4.7z"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-teamblack/TeamBlackMiner_1_0_Cuda_11_2.7z"
            Cuda = "11.2"
            Version = "1.0"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system


$ExcludePools = "^666Pool|^BeePool|^Hellominer|^HeroMiners|^MiningDutch|^MiningRigRentals|^MoneroOcean|^Poolin|^PoolSexy|^ProHashing|^ProHashingCoins|^SuprNova|^unMineable|^Zpool"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash";     DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5; ExcludePoolName = $ExcludePools} #Ethash
    [PSCustomObject]@{MainAlgorithm = "etchash";    DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5; ExcludePoolName = $ExcludePools} #EtcHash
    [PSCustomObject]@{MainAlgorithm = "verthash";                Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 1.0; ExcludePoolName = $ExcludePools} #VertHash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","INTEL","NVIDIA")
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
            if ($UriCuda[$i].Version) {$Version = $UriCuda[$i].Version}
        }
    }
}

if (-not $Cuda) {
    $Uri = $UriCuda[0].Uri
    if ($UriCuda[0].Version) {$Version = $UriCuda[0].Version}
}

if (-not (Test-Path $DatFile) -or (Get-Item $DatFile).length -lt 1.19GB) {
    $DatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
}

foreach ($Miner_Vendor in @("AMD","INTEL","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Codec_Index -join ','
                        $First = $false
                    }
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                    if ($_.MainAlgorithm -ne "verthash") {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--algo $($_.MainAlgorithm) --hostname $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --wallet $($Pools.$Algorithm_Norm.Wallet) --worker_name $($Pools.$Algorithm_Norm.Worker)$(if ($Pools.$Algorithm_Norm.Pass) {" --server-password $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.SSL) {" --ssl"}) $(if ($Miner_Vendor -eq "NVIDIA") {"--cuda-devices"} else {"-cl-devices"}) [$($DeviceIDsAll)] $($_.Params)"
					        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
					        API            = "TeamblackWrapper"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = $_.DevFee
					        Uri            = $Uri
					        ManualUri      = $ManualUri
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $Algorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				        }
                    } else {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path_VTC
                            Arguments      = "-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $(if ($Miner_Vendor -eq "NVIDIA") {"--cu-devices"} else {"--cl-devices"}) $($DeviceIDsAll) --verthash-data '$($DatFile)' $($_.Params)"
					        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
					        API            = "SPMinerWrapper"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = $_.DevFee
					        Uri            = $Uri
					        ManualUri      = $ManualUri
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $Algorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                            PrerequisitePath = $DatFile
                            PrerequisiteURI  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"
                            PrerequisiteMsg  = "Downloading verthash.dat (1.2GB) in the background, please wait!"
				        }
                    }
			    }
		    }
        })
    }
}