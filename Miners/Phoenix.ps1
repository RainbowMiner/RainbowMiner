using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\Ethash-Phoenix\PhoenixMiner"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.2c-phoenix/PhoenixMiner_4.2c_Linux.tar.gz"
} else {
    $Path = ".\Bin\Ethash-Phoenix\PhoenixMiner.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.2c-phoenix/PhoenixMiner_4.2c_Windows.zip"
}
$ManualURI = "https://bitcointalk.org/index.php?topic=2647654.0"
$Port = "308{0:d2}"
$DevFee = 0.65
$Cuda = "8.0"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"  ; MinMemGB = 2; Vendor = @("AMD","NVIDIA"); Params = @()} #Ethash2GB
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"  ; MinMemGB = 3; Vendor = @("AMD","NVIDIA"); Params = @()} #Ethash3GB
    [PSCustomObject]@{MainAlgorithm = "ethash"     ; MinMemGB = 4; Vendor = @("AMD","NVIDIA"); Params = @()} #Ethash
    [PSCustomObject]@{MainAlgorithm = "progpow2gb" ; MinMemGB = 2; Vendor = @("AMD"); Params = @()} #ProgPow2GB
    [PSCustomObject]@{MainAlgorithm = "progpow3gb" ; MinMemGB = 3; Vendor = @("AMD"); Params = @()} #ProgPow3GB
    [PSCustomObject]@{MainAlgorithm = "progpow"    ; MinMemGB = 4; Vendor = @("AMD"); Params = @()} #ProgPow
)
$CommonParams = "-allpools 0 -cdm 1 -leaveoc -log 0 -rmode 0 -wdog 1 -rmode 0"

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

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
		$Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
		$Miner_Model = $_.Model

		switch($_.Vendor) {
			"NVIDIA" {$Miner_Deviceparams = "-nvidia -nvdo 1"}
			"AMD" {$Miner_Deviceparams = "-amd"}
			Default {$Miner_Deviceparams = ""}
		}

		$Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
			$Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
			$MinMemGB = $_.MinMemGB
            if ($_.MainAlgorithm -eq "Ethash" -and $Pools.$Algorithm_Norm.CoinSymbol -eq "ETP") {$MinMemGB = 3}
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1Gb - 0.25gb)}

			foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

					$Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^(ethash|progpow)', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-')  -replace "-+", "-"            
					$DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f $_.Type_Vendor_Index}) -join ''

                    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

					$Miner_Protocol_Params = Switch ($Pools.$Algorithm_Norm.EthMode) {
                        "minerproxy"       {"-proto 1"}
                        "ethproxy"         {"-proto 2"}
                        "qtminer"          {"-proto 3"}
						"ethstratumnh"     {"-proto 4 -stales 0"}
						default            {"-proto 1"}
					}

                    if ($Pools.$Algorithm_Norm.Name -eq "F2pool" -and $Pools.$Algorithm_Norm.User -match "^0x[0-9a-f]{40}") {$Pool_Port = 8008}

                    $Coin = if ($Algorithm_Norm -eq "ProgPow") {"bci"}
                            elseif ($Pools.$Algorithm_Norm.CoinSymbol -eq "UBQ" -or $Pools.$Algorithm_Norm.CoinName -like "ubiq") {"ubq"}
                            else {"auto"}

					[PSCustomObject]@{
						Name = $Miner_Name
						DeviceName = $Miner_Device.Name
						DeviceModel = $Miner_Model
						Path = $Path
						Arguments = "-cdmport $($Miner_Port) -coin $($Coin) -di $($DeviceIDsAll) -pool $(if($Pools.$Algorithm_Norm.SSL){"ssl://"})$($Pools.$Algorithm_Norm.Host):$($Pool_Port) $(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Name -notmatch "nicehash") {"-wal $($Pools.$Algorithm_Norm.Wallet) -worker $($Pools.$Algorithm_Norm.Worker)"} else {"-wal $($Pools.$Algorithm_Norm.User)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -pass $($Pools.$Algorithm_Norm.Pass)"}) $($Miner_Protocol_Params) $($Miner_Deviceparams) $($CommonParams) $($_.Params)"
						HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
						API = "Claymore"
						Port = $Miner_Port
						Uri = $Uri
						DevFee = $DevFee
						ManualUri = $ManualUri
                        StartCommand = "Get-ChildItem `"$(Join-Path ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) | Split-Path) "*pools.txt")`" | Remove-Item -Force"
                        ExtendInterval = 2
					}
				}
			}
		}
	}
}