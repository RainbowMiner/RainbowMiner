using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\AMD-ProgPOWZ\progminer-zano-opencl.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.1.2-progminerzano/progminer-zano-win-1.1.2.7z"
$Port = "413{0:d2}"
$ManualURI = "https://github.com/hyle-team/zano/releases"
$DevFee = 0.0
$Version = "1.1.2"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "progpowz"; Params = ""; ExtendInterval = 2; MinMemGB = 3} #ProgPOWZ
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $UriCuda.Path | Select-Object -First 1
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

    $Miner_PlatformId = $Device | Select-Object -ExpandProperty PlatformId -Unique
    if ($Miner_PlatformId -isnot [int]) {return}

    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
            if (-not $Pools.$Algorithm_Norm.Host) {continue}

            $CoinSymbol = if ($Pools.$Algorithm_Norm.CoinSymbol) {$Pools.$Algorithm_Norm.CoinSymbol} else {"ZANO"}
            $MinMemGB = if ($Pools.$Algorithm_Norm.DagSizeMax) {$Pools.$Algorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb}
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

			if ($Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index -join ' '
                    $First = $false
                }

                $Miner_Protocol = Switch ($Pools.$Algorithm_Norm.EthMode) {
                    "stratum"          {"stratum+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                    "ethproxy"         {"stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
					"ethstratumnh"     {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
					default            {"stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})"}
				}

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api-port -`$mport -P $($Miner_Protocol)://$(Get-UrlEncode $Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --opencl --cl-devices $($DeviceIDsAll) --exit $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week }
					API            = "EthminerWrapper"
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
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				}
			}
		}
    }
}
