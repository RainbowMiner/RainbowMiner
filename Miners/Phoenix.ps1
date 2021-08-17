using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$ManualURI = "https://bitcointalk.org/index.php?topic=2647654.0"
$Port = "308{0:d2}"
$DevFee = 0.65
$Cuda = "8.0"
$Version = "5.7b"

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-Phoenix\PhoenixMiner"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.7b-phoenix/PhoenixMiner_5.7b_Linux.tar.gz"
} else {
    $Path = ".\Bin\GPU-Phoenix\PhoenixMiner.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.7b-phoenix/PhoenixMiner_5.7b_Windows.7z"
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "etchash"    ; MinMemGB = 3; Vendor = @("AMD","NVIDIA"); Params = @()} #Etchash
    [PSCustomObject]@{MainAlgorithm = "ethash"     ; MinMemGB = 3; Vendor = @("AMD","NVIDIA"); Params = @()} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory" ; MinMemGB = 2; Vendor = @("AMD","NVIDIA"); Params = @()} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "progpow"    ; MinMemGB = 3; Vendor = @("AMD","NVIDIA"); Params = @(); ExcludePoolName = "^SuprNova"} #ProgPow
    [PSCustomObject]@{MainAlgorithm = "ubqhash"    ; MinMemGB = 2; Vendor = @("AMD","NVIDIA"); Params = @()} #UbqHash
)
$CommonParams = "-allpools 0 -cdm 1 -leaveoc -log 0 -rmode 0 -wdog 1 -gbase 0"

$CoinXlat = [PSCustomObject]@{
    "AKA" = "akroma"
    "ATH" = "ath"
    "AURA" = "aura"
    "B2G" = "b2g"
    "BCI" = "bci"
    "CLO" = "clo"
    "DBIX" = "dbix"
    "EGEM" = "egem"
    "ELLA" = "ella"
    "ESN" = "esn"
    "ETC" = "etc"
    "ETCC" = "etcc"
    "ETH" = "eth"
    "ETHO" = "etho"
    "ETP" = "etp"
    "ETZ" = "etz"
    "EXP" = "exp"
    "GEN" = "gen"
    "HBC" = "hbc"
    "MIX" = "mix"
    "MOAC" = "moac"
    "MUSIC" = "music"
    "NUKO" = "nuko"
    "PGC" = "pgc"
    "PIRL" = "pirl"
    "QKC" = "qkc"
    "REOSC" = "reosc"
    "UBQ" = "ubq"
    "VIC" = "vic"
    "WHL" = "whale"
    "YOC" = "yoc"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
		$Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

		switch($_.Vendor) {
			"NVIDIA" {$Miner_Deviceparams = "-nvidia -nvdo 1"}
			"AMD" {$Miner_Deviceparams = "-amd"}
			Default {$Miner_Deviceparams = ""}
		}

		$Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true
			$Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

			$MinMemGB = Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

			foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
			            $DeviceIDsAll = ($Miner_Device | % {'{0:d}' -f $_.BusId_Type_Vendor_Index}) -join ","
                        $First = $false
                    }
                    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

					$Miner_Protocol_Params = Switch ($Pools.$Algorithm_Norm.EthMode) {
                        "minerproxy"       {"-proto 1"}
                        "ethproxy"         {"-proto 2"}
                        "qtminer"          {"-proto 3"}
                        "ethstratum"       {"-proto 4"}
                        "ethstratum1"      {"-proto 4"}
						"ethstratumnh"     {"-proto 4 -stales 0"}
                        "ethstratum2"      {"-proto 5"}
						default            {"-proto 1"}
					}

                    if ($Pools.$Algorithm_Norm.Name -eq "F2pool" -and $Pools.$Algorithm_Norm.User -match "^0x[0-9a-f]{40}") {$Pool_Port = 8008}

                    $CoinSymbol = $Pools.$Algorithm_Norm.CoinSymbol
                    $Coin = if ($Algorithm_Norm -match "ProgPow") {"bci"}
                            elseif ($CoinSymbol -and $CoinXlat.$CoinSymbol) {$CoinXlat.$CoinSymbol}
                            elseif ($Algorithm_Norm_0 -eq "EtcHash") {"etc"}
                            elseif ($Algorithm_Norm_0 -eq "UbqHash") {"ubq"}
                            else {"auto"}

					[PSCustomObject]@{
						Name           = $Miner_Name
						DeviceName     = $Miner_Device.Name
						DeviceModel    = $Miner_Model
						Path           = $Path
						Arguments      = "-cdmport `$mport -coin $($Coin) -di $($DeviceIDsAll) -pool $(if($Pools.$Algorithm_Norm.SSL){"ssl://"})$($Pools.$Algorithm_Norm.Host):$($Pool_Port) $(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Name -notmatch "nicehash") {"-wal $($Pools.$Algorithm_Norm.Wallet) -worker $($Pools.$Algorithm_Norm.Worker)"} else {"-wal $($Pools.$Algorithm_Norm.User)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -pass $($Pools.$Algorithm_Norm.Pass)"}) $($Miner_Protocol_Params) $($Miner_Deviceparams) $($CommonParams) $($_.Params)"
						HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
						API            = "Claymore"
						Port           = $Miner_Port
						Uri            = $Uri
					    FaultTolerance = $_.FaultTolerance
					    ExtendInterval = 2
                        Penalty        = 0
						DevFee         = $DevFee
						ManualUri      = $ManualUri
                        StartCommand   = "Get-ChildItem `"$(Join-Path ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) | Split-Path) "*pools.txt")`" | Remove-Item -Force"
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
					}
				}
			}
		})
	}
}