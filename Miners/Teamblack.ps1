using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualURI = "https://github.com/sp-hash/TeamBlackMiner"
$Port = "365{0:d2}"
$Version = "1.66"

if ($IsLinux) {
    $Path     = ".\Bin\GPU-Teamblack\TBMiner"

    $DatFile = "$env:HOME/.vertcoin/verthash.dat"

    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.66-teamblack/TeamBlackMiner_1_66_Ubuntu_18_04_Cuda_11_5.tar.xz"
            Cuda = "11.5"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.66-teamblack/TeamBlackMiner_1_66_Ubuntu_18_04_Cuda_11_5.tar.xz"
            Cuda = "11.4"
        }
    )
} else {
    $Path     = ".\Bin\GPU-Teamblack\TBMiner.exe"

    $DatFile = "$env:APPDATA\Vertcoin\verthash.dat"

    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.66-teamblack/TeamBlackMiner_1_66_cuda_11_7.7z"
            Cuda = "11.7"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.65-teamblack/TeamBlackMiner_1_65_cuda_11_5.7z"
            Cuda = "11.5"
            Version = "1.65"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.65-teamblack/TeamBlackMiner_1_65_cuda_11_4.7z"
            Cuda = "11.4"
            Version = "1.65"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$ExcludePools = "MiningDutch|MoneroOcean|Nicehash|PoolSexy|SuprNova|Zpool"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash";     DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5; ExcludePoolName = $ExcludePools} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5; ExcludePoolName = $ExcludePools} #Ethash for low memory DAG
    [PSCustomObject]@{MainAlgorithm = "etchash";    DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5; ExcludePoolName = $ExcludePools} #EtcHash
    [PSCustomObject]@{MainAlgorithm = "ethashnh";   DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5} #Ethash Nicehash type
    [PSCustomObject]@{MainAlgorithm = "ethashfp";   DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 0.5} #Ethash Flexpool type
    [PSCustomObject]@{MainAlgorithm = "verthash";                Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 3; DevFee = 1} #Verthash/VTC
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

$Miner_DatFile = $DatFile
if ($Miner_DatFile -match " ") {$Miner_DatFile = "`"$($Miner_DatFile)`""}

foreach ($Miner_Vendor in @("AMD","INTEL","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and ($IsLinux -or -not $_.Xintensity)}).ForEach({
            $First = $true
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

            $LHRCUDA = if (($Miner_Device | Where-Object {$_.IsLHR -or $Session.Config.Devices."$($_.Model_Base)".EnableLHR -ne $null} | Measure-Object).Count -gt 0) {
                ($Miner_Device | Foreach-Object {"$(if (($_.IsLHR -and $Session.Config.Devices."$($_.Model_Base)".EnableLHR -eq $null) -or $Session.Config.Devices."$($_.Model_Base)".EnableLHR) {1} else {0})"}) -join ','
            }

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.IncludePoolName -or $Pools.$Algorithm_Norm.Host -match $_.IncludePoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAllOpenCl = $Miner_Device.Type_Index -join ','
                        $DeviceIDsAllCUDA   = $Miner_Device.Type_Vendor_Index -join ','
                        $Xintensity = if ($_.Xintensity) {$_.Xintensity} else {-1}
                        $First = $false
                    }
				    $Pool_Port   = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                    $Pool_Wallet = if ($Pools.$Algorithm_Norm.Wallet) {$Pools.$Algorithm_Norm.Wallet} else {$Pools.$Algorithm_Norm.User}
                    if ($Pools.$Algorithm_Norm.Host -match "MiningRigRentals") {$Pool_Wallet = $Pool_Wallet -replace "\.","*"}

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--algo $($_.MainAlgorithm -replace "^(Etc?hash).+","`$1")$(if ($Pools.$Algorithm_Norm.SSL) {" --ssl"}) --hostname $($Pools.$Algorithm_Norm.Host) $(if ($Pools.$Algorithm_Norm.SSL) {"--ssl-port"} else {"--port"}) $($Pool_Port) --wallet $($Pool_Wallet) --worker-name $($Pools.$Algorithm_Norm.Worker)$(if ($Pools.$Algorithm_Norm.Pass) {" --server-passwd $($Pools.$Algorithm_Norm.Pass)"}) $(if ($Miner_Vendor -eq "NVIDIA") {"--cuda-devices [$($DeviceIDsAllCUDA)]"} else {"--cl-devices [$($DeviceIDsAllOpenCl)]"})$(if ($_.MainAlgorithm -eq "verthash") {" --verthash-data $($Miner_DatFile)"})$(if ($Miner_Vendor -eq "NVIDIA") {" --xintensity $($Xintensity)"})$(if ($LHRCUDA) {" --lhr-unlock [$($LHRCUDA)]"}) --api --api-port $($Miner_Port) --no-ansi --no-cpu $($_.Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
					    API            = "TBMiner"
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
                        ExcludePoolName = $_.ExcludePoolName
				    }
			    }
		    }
        })
    }
}