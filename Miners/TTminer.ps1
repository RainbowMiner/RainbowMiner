using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-TTminer\TT-Miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.0.10-ttminer/TT-Miner-3.0.10.tar.xz"
} else {
    $Path = ".\Bin\NVIDIA-TTminer\TT-Miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.0.10-ttminer/TT-Miner-3.0.10.zip"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"
$Port = "333{0:d2}"
$DevFee = 1.0
$Cuda = "9.2"
$Version = "3.0.10"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "ETHASH2gb"    ; MinMemGB = 2; NH = $false; Params = "-A ETHASH%CUDA%"} #Ethash2GB 
    #[PSCustomObject]@{MainAlgorithm = "ETHASH3gb"    ; MinMemGB = 3; NH = $false; Params = "-A ETHASH%CUDA%"} #Ethash3GB 
    #[PSCustomObject]@{MainAlgorithm = "ETHASH"       ; MinMemGB = 4; NH = $false;  Params = "-A ETHASH%CUDA%"} #Ethash 
    #[PSCustomObject]@{MainAlgorithm = "HONEYCOMB"     ; MinMemGB = 2; NH = $false; Params = "-A HONEYCOMB%CUDA%"; ExtendInterval = 2} #HoneyComb
    [PSCustomObject]@{MainAlgorithm = "LYRA2V3"       ; MinMemGB = 2; NH = $true;  Params = "-A LYRA2V3%CUDA%"; ExtendInterval = 2} #LYRA2V3
    [PSCustomObject]@{MainAlgorithm = "MTP"           ; MinMemGB = 6; NH = $true;  Params = "-A MTP%CUDA%"; ExtendInterval = 2} #MTP
    #[PSCustomObject]@{MainAlgorithm = "MYRGR"        ; MinMemGB = 2; NH = $true;  Params = "-A MYRGR%CUDA%"; ExtendInterval = 2} #MYRGR    
    [PSCustomObject]@{MainAlgorithm = "PROGPOW2gb"    ; MinMemGB = 2; NH = $false; Params = "-A PROGPOW%CUDA%"; ExtendInterval = 2} #ProgPoW2gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW3gb"    ; MinMemGB = 3; NH = $false; Params = "-A PROGPOW%CUDA%"; ExtendInterval = 2} #ProgPoW3gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW"       ; MinMemGB = 4; NH = $false; Params = "-A PROGPOW%CUDA%"; ExtendInterval = 2} #ProgPoW (BCI)
    [PSCustomObject]@{MainAlgorithm = "PROGPOW2gb"    ; MinMemGB = 2; NH = $false; Params = "-A PROGPOW092%CUDA%"; Coins = @("BNA","HORA","SERO"); ExtendInterval = 2; Cuda ="10.1"} #ProgPoW2gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW3gb"    ; MinMemGB = 3; NH = $false; Params = "-A PROGPOW092%CUDA%"; Coins = @("BNA","HORA","SERO"); ExtendInterval = 2; Cuda ="10.1"} #ProgPoW3gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOW"       ; MinMemGB = 4; NH = $false; Params = "-A PROGPOW092%CUDA%"; Coins = @("BNA","HORA","SERO"); ExtendInterval = 2; Cuda ="10.1"} #ProgPoW (BNA,HORA,SERO)
    [PSCustomObject]@{MainAlgorithm = "PROGPOWZ2gb"   ; MinMemGB = 2; NH = $false; Params = "-A PROGPOWZ%CUDA%"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWZ2gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOWZ3gb"   ; MinMemGB = 3; NH = $false; Params = "-A PROGPOWZ%CUDA%"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWZ3gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOWZ"      ; MinMemGB = 4; NH = $false; Params = "-A PROGPOWZ%CUDA%"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWZ (ZANO)
    [PSCustomObject]@{MainAlgorithm = "TETHASHV1"     ; MinMemGB = 3; NH = $false; Params = "-A TETHASHV1%CUDA%"; ExtendInterval = 2} #TEThash 
    [PSCustomObject]@{MainAlgorithm = "UBQHASH"       ; MinMemGB = 3; NH = $false; Params = "-A UBQHASH%CUDA%"; ExtendInterval = 2} #Ubqhash 
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Cuda = ""
if ($IsLinux) {
    $Cuda = "-$(if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion "10.1") {"101"} elseif (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion "10.0") {"100"} else {"92"})"
}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | Where-Object {$_.Cuda -eq $null -or (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $_.Cuda -Warning "$($Name)-$($_.MainAlgorithm)")} | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB
        if ($_.MainAlgorithm -eq "Ethash" -and $Pools.$Algorithm_Norm.CoinSymbol -eq "ETP") {$MinMemGB = 3}
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb - 0.25gb)}
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        if ($Algorithm_Norm -match "^(Ethash|ProgPow)" -and $Pools.$Algorithm_Norm.EthMode -eq "ethproxy" -and ($Pools.$Algorithm_Norm.Name -ne "MiningRigRentals" -or $Algorithm_Norm -ne "ProgPow")) {
            $Miner_Protocol = "stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})://"
        } else {
            $Miner_Protocol = ""
        }

        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
        
		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "Nicehash") -and (-not $_.Coins -or $_.Coins -icontains $Pools.$Algorithm_Norm.CoinSymbol) -and $Miner_Device) {
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api-bind 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -P $($Miner_Protocol)$($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$($Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -PRHRI 1 -nui $($_.Params -replace '%CUDA%',$Cuda)$(if ($_.Coins) {"-coin $($Pools.$Algorithm_Norm.CoinSymbol)"})"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
					API            = "Claymore"
					Port           = $Miner_Port                
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    StopCommand    = "Sleep 5"
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}