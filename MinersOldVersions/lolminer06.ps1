using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\Equihash-lolMiner06\lolMiner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6-lolminer/lolMiner_v06_Win64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "336{0:d2}"
$Cuda = "10.0"
$DevFee = 2.0

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash16x5"; MinMemGB = 1; Params = "--coin MNX --workbatch VERYHIGH"; Fee=1}  #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9"; MinMemGB = 1; Params = "--coin AION"; Fee=2} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5"; MinMemGB = 2; Params = "--coin AUTO144_5"; Fee=1.5} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7"; MinMemGB = 3; Params = "--coin AUTO192_7"; Fee=2} #Equihash 192,7
    #[PSCustomObject]@{MainAlgorithm = "Equihash25x5"; MinMemGB = 4; Params = "--coin BEAM"; Fee=2} #Equihash 150,5
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
        $Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | ForEach-Object {            
            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
            $MinMemGB = $_.MinMemGB
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb)}

			foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Algorithm_Norm -notmatch "Equihash25x5" -or $Pools.$Algorithm_Norm.Name -ne "Nicehash")) {
					$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
					$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                
					[PSCustomObject]@{
						Name        = $Miner_Name
						DeviceName  = $Miner_Device.Name
						DeviceModel = $Miner_Model
						Path        = $Path
						Arguments   = "--pool $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"}) --devices $($Miner_Device.Type_Vendor_Index -join ',') --apiport $($Miner_Port) --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 $($_.Params)"
						HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
						API         = "Lol"
						Port        = $Miner_Port
						DevFee      = $_.Fee
						Uri         = $Uri
						ExtendInterval = $_.ExtendInterval
						ManualUri   = $ManualUri
					}
				}
			}
        }
    }
}
