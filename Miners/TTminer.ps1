using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\NVIDIA-TTminer\TT-Miner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2.6-ttminer/TT-Miner-2.2.6.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"
$Port = "333{0:d2}"
$DevFee = 1.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "ETHASH2gb"    ; MinMemGB = 2; NH = $false; Params = "-A ETHASH"} #Ethash2GB 
    #[PSCustomObject]@{MainAlgorithm = "ETHASH3gb"    ; MinMemGB = 3; NH = $false; Params = "-A ETHASH"} #Ethash3GB 
    #[PSCustomObject]@{MainAlgorithm = "ETHASH"       ; MinMemGB = 4; NH = $false;  Params = "-A ETHASH"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "LYRA2V3"       ; MinMemGB = 2; NH = $true;  Params = "-A LYRA2V3"; ExtendInterval = 2} #LYRA2V3
    [PSCustomObject]@{MainAlgorithm = "MTP"           ; MinMemGB = 6; NH = $true;  Params = "-A MTP"; ExtendInterval = 2} #MTP
    #[PSCustomObject]@{MainAlgorithm = "MYRGR"        ; MinMemGB = 2; NH = $true;  Params = "-A MYRGR"; ExtendInterval = 2} #MYRGR    
    [PSCustomObject]@{MainAlgorithm = "PROGPOW2gb"    ; MinMemGB = 2; NH = $false; Params = "-A PROGPOW"; ExtendInterval = 2} #ProgPoW2gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW3gb"    ; MinMemGB = 3; NH = $false; Params = "-A PROGPOW"; ExtendInterval = 2} #ProgPoW3gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOW"       ; MinMemGB = 4; NH = $false; Params = "-A PROGPOW"; ExtendInterval = 2} #ProgPoW
    [PSCustomObject]@{MainAlgorithm = "PROGPOW0922gb" ; MinMemGB = 2; NH = $false; Params = "-A PROGPOW092"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoW0922gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOW0923gb" ; MinMemGB = 3; NH = $false; Params = "-A PROGPOW092"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoW0923gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOW092"    ; MinMemGB = 4; NH = $false; Params = "-A PROGPOW092"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoW092
    [PSCustomObject]@{MainAlgorithm = "PROGPOWH2gb"   ; MinMemGB = 2; NH = $false; Params = "-A PROGPOW092 -coin HORA"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWH2gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOWH3gb"   ; MinMemGB = 3; NH = $false; Params = "-A PROGPOW092 -coin HORA"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWH3gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOWH"      ; MinMemGB = 4; NH = $false; Params = "-A PROGPOW092 -coin HORA"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWH
    [PSCustomObject]@{MainAlgorithm = "PROGPOWSERO2gb"; MinMemGB = 2; NH = $false; Params = "-A PROGPOW092 -coin SERO"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWSero2gb 
    [PSCustomObject]@{MainAlgorithm = "PROGPOWSERO3gb"; MinMemGB = 3; NH = $false; Params = "-A PROGPOW092 -coin SERO"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWSero3gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOWSERO"   ; MinMemGB = 4; NH = $false; Params = "-A PROGPOW092 -coin SERO"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWSero
    [PSCustomObject]@{MainAlgorithm = "PROGPOWZ2gb"   ; MinMemGB = 2; NH = $false; Params = "-A PROGPOWZ"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWZ2gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOWZ3gb"   ; MinMemGB = 3; NH = $false; Params = "-A PROGPOWZ"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWZ3gb
    [PSCustomObject]@{MainAlgorithm = "PROGPOWZ"      ; MinMemGB = 4; NH = $false; Params = "-A PROGPOWZ"; ExtendInterval = 2; Cuda ="10.1"} #ProgPoWZ
    [PSCustomObject]@{MainAlgorithm = "TETHASHV1"     ; MinMemGB = 3; NH = $false; Params = "-A TETHASHV1"; ExtendInterval = 2} #TEThash 
    [PSCustomObject]@{MainAlgorithm = "UBQHASH"       ; MinMemGB = 3; NH = $false; Params = "-A UBQHASH"; ExtendInterval = 2} #Ubqhash 
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
			if ($Pools.$Algorithm_Norm.Host -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "Nicehash") -and $Miner_Device) {
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api-bind 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -P $($Miner_Protocol)$($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$($Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -PRHRI 1 -nui $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
					API            = "Claymore"
					Port           = $Miner_Port                
					Uri            = $Uri
					DevFee         = $DevFee
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
					ManualUri      = $ManualUri
                    StopCommand    = "Sleep 5"
				}
			}
		}
    }
}