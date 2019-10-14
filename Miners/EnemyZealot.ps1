using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"
$Port = "302{0:d2}"
$DevFee = 1.0
$Version = "2.3"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-enemyz\z-enemy"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-linux-cuda101-libcurl4.tar.gz"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-linux-cuda100-libcurl4.tar.gz"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-linux-cuda92.tar.gz"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-linux-cuda91.tar.gz"
            Cuda = "9.1"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-enemyz\z-enemy.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-win-cuda10.1.zip"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-win-cuda10.0.zip"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-win-cuda9.2.zip"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-zenemy/z-enemy-2.3-win-cuda9.1.zip"
            Cuda = "9.1"
        }
    )
}

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo"; Params = "-N 1"} #AeriumX, new in 1.11
    #[PSCustomObject]@{MainAlgorithm = "bcd"; Params = "-N 1"} #Bcd, new in 1.20
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = "-N 1"} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = "-N 1"} # New in 1.11
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = "-N 1"; ExtendInterval = 3; FaultTolerance = 0.5; HashrateDuration = "Day"} #HEX/XDNA, new in 1.15a
    #[PSCustomObject]@{MainAlgorithm = "hsr"; Params = "-N 1"} #HSR
    #[PSCustomObject]@{MainAlgorithm = "phi"; Params = "-N 1"; ExtendInterval = 2} #PHI
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = "-N 1"} #PHI2, new in 1.12
    #[PSCustomObject]@{MainAlgorithm = "poly"; Params = "-N 1"} #Polytimos
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = "-N 1"} #Skunk, new in 1.11
    #[PSCustomObject]@{MainAlgorithm = "sonoa"; Params = "-N 1"} #Sonoa, new in 1.12 (testing)
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = "-N 1"} #Timetravel8
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-N 1"} #Tribus, new in 1.10
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-N 10"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16R
    [PSCustomObject]@{MainAlgorithm = "x16rv2"; Params = "-N 10"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16Rv2
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-N 1"; FaultTolerance = 0.5} #X16S (T-Rex faster)
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = "-N 1"} #X17 (T-Rex has better numbers at the pool)
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-N 1"} #Xevan, new in 1.09a
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

$Uri = ""
for($i=0;$i -le $UriCuda.Count -and -not $Uri;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
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

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

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
					Arguments      = "-R 1 --api-bind=0 --api-bind-http=$($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"}) --no-cert-verify $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					API            = "EnemyZ"
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