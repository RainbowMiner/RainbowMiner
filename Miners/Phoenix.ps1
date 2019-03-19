using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\Ethash-Phoenix\PhoenixMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.1c-phoenix/PhoenixMiner_4.1c_Windows.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=2647654.0"
$Port = "308{0:d2}"
$DevFee = 0.65
$Cuda = "6.5"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    [PSCustomObject]@{MainAlgorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)

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
			"NVIDIA" {$Miner_Deviceparams = "-nvidia"}
			"AMD" {$Miner_Deviceparams = "-amd"}
			Default {$Miner_Deviceparams = ""}
		}

		$Commands | ForEach-Object {
			$Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
			$MinMemGB = $_.MinMemGB
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1Gb - 0.25gb)}

			foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

					$Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-')  -replace "-+", "-"            
					$DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f $_.Type_Vendor_Index}) -join ''

                    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

					switch($Pools.$Algorithm_Norm.Name) {
                        "F2pool"    {$Miner_Protocol_Params = "";if ($Pools.$Algorithm_Norm.User -match "^0x[0-9a-f]{40}") {$Pool_Port = 8008}}
						"Ethermine" {$Miner_Protocol_Params = "-proto 3"}
						"Nanopool"  {$Miner_Protocol_Params = "-proto 2"}
						"NiceHash"  {$Miner_Protocol_Params = "-proto 4 -stales 0"}
						default {$Miner_Protocol_Params = "-proto 1"}
					}

					[PSCustomObject]@{
						Name = $Miner_Name
						DeviceName = $Miner_Device.Name
						DeviceModel = $Miner_Model
						Path = $Path
						Arguments = "-rmode 0 -cdmport $($Miner_Port) -cdm 1 -log 0 -allpools 0 -leaveoc -coin $(if ($Pools.$Algorithm_Norm.CoinSymbol -eq "UBQ" -or $Pools.$Algorithm_Norm.CoinName -like "ubiq") {"ubq"} else {"auto"}) -di $($DeviceIDsAll) -pool $(if($Pools.$Algorithm_Norm.SSL){"ssl://"})$($Pools.$Algorithm_Norm.Host):$($Pool_Port) $(if ($Pools.$Algorithm_Norm.Wallet) {"-ewal $($Pools.$Algorithm_Norm.Wallet) -worker $($Pools.$Algorithm_Norm.Worker)"} else {"-wal $($Pools.$Algorithm_Norm.User)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -pass $($Pools.$Algorithm_Norm.Pass)"}) $($Miner_Protocol_Params) $($Miner_Deviceparams) $($_.Params)"
						HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
						API = "Claymore"
						Port = $Miner_Port
						Uri = $Uri
						DevFee = $DevFee
						ManualUri = $ManualUri
					}
				}
			}
		}
	}
}