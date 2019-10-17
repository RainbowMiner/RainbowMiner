using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\ANY-Nanominer\nanominer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.6.1-nanominer/nanominer-linux-1.6.1.tar.gz"
} else {
    $Path = ".\Bin\ANY-Nanominer\nanominer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.6.1-nanominer/nanominer-windows-1.6.1.zip"
}
$ManualURI = "https://github.com/nanopool/nanominer/releases"
$Port = "534{0:d2}"
$Cuda = "8.0"
$DevFee = 3.0
$Version = "1.6.1"

if (-not $Session.DevicesByTypes.AMD -and -not $Session.DevicesByTypes.CPU -and -not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29";              Params = ""; MinMemGb = 6; MinMemGbW10 = 8; Vendor = @("AMD");          NH = $true; ExtendInterval = 2; DevFee = 2.0} #Cuckaroo29
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";             Params = ""; MinMemGb = 6; MinMemGbW10 = 8; Vendor = @("AMD");          NH = $true; ExtendInterval = 2; DevFee = 2.0} #Cuckarood29
    #[PSCustomObject]@{MainAlgorithm = "CryptonightR";            Params = ""; MinMemGb = 4; MinMemGbW10 = 8; Vendor = @("AMD","NVIDIA"); NH = $true; ExtendInterval = 2; DevFee = 1.0} #CryptonightR
    [PSCustomObject]@{MainAlgorithm = "CryptoNightReverseWaltz"; Params = ""; MinMemGb = 4; MinMemGbW10 = 4; Vendor = @("AMD","NVIDIA"); NH = $true; ExtendInterval = 2; DevFee = 1.0} #CryptonightRwz
    [PSCustomObject]@{MainAlgorithm = "Ethash";                  Params = ""; MinMemGb = 4; MinMemGbW10 = 4; Vendor = @("AMD");          NH = $true; ExtendInterval = 2; DevFee = 1.0} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "RandomHash";              Params = ""; MinMemGb = 4; MinMemGbW10 = 4; Vendor = @("CPU");          NH = $true; ExtendInterval = 2; DevFee = 5.0} #RandomHash/PASCcoin
    [PSCustomObject]@{MainAlgorithm = "RandomHash2";             Params = ""; MinMemGb = 4; MinMemGbW10 = 4; Vendor = @("CPU");          NH = $true; ExtendInterval = 2; DevFee = 5.0} #RandomHash2/PASCcoin
    [PSCustomObject]@{MainAlgorithm = "RandomX";                 Params = ""; MinMemGb = 4; MinMemGbW10 = 4; Vendor = @("CPU");          NH = $true; ExtendInterval = 2; DevFee = 5.0} #RandomX
    #[PSCustomObject]@{MainAlgorithm = "UbqHash";                 Params = ""; MinMemGb = 4; MinMemGbW10 = 4; Vendor = @("AMD","NVIDIA"); NH = $true; ExtendInterval = 2; DevFee = 1.0} #UbqHash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
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

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
    $Session.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $DeviceParams = if ($Miner_Vendor -eq "CPU") {"$(if ($Session.Config.CPUMiningThreads){" -cputhreads $($Session.Config.CPUMiningThreads)"})$(if ($Session.Config.CPUMiningAffinity -ne ''){" -processorsaffinity $((ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity) -join ",")"})"} else {""}
    
        $Commands |  Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
            $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
            if ($_.MainAlgorithm -eq "Ethash" -and $Pools.$Algorithm_Norm.CoinSymbol -eq "ETP") {$MinMemGB = 3}
            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		    foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "Nicehash") -and ($Algorithm_Norm -ne "Ethash" -or $Pools.$Algorithm_Norm.Name -notmatch "F2Pool")) {
					$Pool_Port = if ($Miner_Vendor -ne "CPU" -and $Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

                    $Wallet    = if ($Pools.$Algorithm_Norm.Wallet) {$Pools.$Algorithm_Norm.Wallet} else {$Pools.$Algorithm_Norm.User}
                    $PaymentId = $null
                    if ($Algorithm_Norm -match "^RandomHash" -or $Algorithm_Norm -match "^Cryptonight") {
                        if ($Wallet -match "^(.+?)[\.\+]([0-9a-f]{16,})") {
                            $Wallet    = $Matches[1]
                            $PaymentId = $Matches[2]
                        } elseif ($Algorithm_Norm -match "^RandomHash") {
                            $PaymentId = "0"
                        }
                    }

				    $Arguments = [PSCustomObject]@{
                        Algo      = $_.MainAlgorithm
					    Host      = $Pools.$Algorithm_Norm.Host
					    Port      = $Pools.$Algorithm_Norm.Port
					    SSL       = $Pools.$Algorithm_Norm.SSL
					    Wallet    = $Wallet
                        PaymentId = $PaymentId
                        Worker    = "{workername:$($Pools.$Algorithm_Norm.Worker)}"
                        Pass      = $Pools.$Algorithm_Norm.Pass
                        Email     = $Pools.$Algorithm_Norm.Email
                        Threads   = if ($Miner_Vendor -eq "CPU") {$Session.Config.CPUMiningThreads} else {$null}
                        Devices   = if ($Miner_Vendor -ne "CPU") {$Miner_Device.Type_Index} else {$null} 
				    }

                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = $Arguments
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					    API            = "Nanominer"
					    Port           = $Miner_Port
					    Uri            = $Uri
					    FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = $_.DevFee
					    ManualUri      = $ManualUri
                        MiningAffinity = if ($Miner_Vendor -eq "CPU") {$Session.Config.CPUMiningAffinity} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				    }
			    }
		    }
        }
    }
}