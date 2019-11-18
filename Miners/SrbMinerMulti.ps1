using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\ANY-SRBMinerMulti\SRBMiner-MULTI.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.1.7-srbminermulti/SRBMiner-Multi-0-1-7.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5190081.0"
$Port = "349{0:d2}"
$DevFee = 0.85
$Version = "0.1.7"

if (-not $Session.DevicesByTypes.AMD -and -not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No AMD nor CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cpupower"      ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "m7mv2"         ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #m7m
    [PSCustomObject]@{MainAlgorithm = "randomarq"     ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomArq
    [PSCustomObject]@{MainAlgorithm = "randomwow"     ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomWow
    [PSCustomObject]@{MainAlgorithm = "randomx"       ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomX
    [PSCustomObject]@{MainAlgorithm = "randomxl"      ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #RandomXL
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"   ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yescryptr16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"   ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yescryptr32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"    ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yescryptr8
    [PSCustomObject]@{MainAlgorithm = "yespower"      ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespower
    [PSCustomObject]@{MainAlgorithm = "yespower2b"    ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespower2b
    [PSCustomObject]@{MainAlgorithm = "yespowerlitb"  ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerlitb
    [PSCustomObject]@{MainAlgorithm = "yespowerltncg" ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerltncg
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"   ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowerr16
    [PSCustomObject]@{MainAlgorithm = "yespowersugar" ; Params = ""; Fee = 0.85;               Vendor = @("CPU")} #yespowersugar
    [PSCustomObject]@{MainAlgorithm = "yespowerurx"   ; Params = ""; Fee = 0.00;               Vendor = @("CPU")} #yespowerurx
    [PSCustomObject]@{MainAlgorithm = "blake2b"       ; Params = ""; Fee = 0.00; MinMemGb = 2; Vendor = @("AMD")} #blake2b
    #[PSCustomObject]@{MainAlgorithm = "blake2s"       ; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD","CPU")} #blake2s
    [PSCustomObject]@{MainAlgorithm = "eaglesong"     ; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #eaglesong
    [PSCustomObject]@{MainAlgorithm = "k12"           ; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #kangaroo12/AEON from 2019-10-25
    [PSCustomObject]@{MainAlgorithm = "keccak"        ; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #keccak
    [PSCustomObject]@{MainAlgorithm = "mtp"           ; Params = ""; Fee = 0.85; MinMemGb = 6; Vendor = @("AMD")} #mtp
    [PSCustomObject]@{MainAlgorithm = "rainforestv2"  ; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #rainforestv2
    [PSCustomObject]@{MainAlgorithm = "yescrypt"      ; Params = ""; Fee = 0.85; MinMemGb = 2; Vendor = @("AMD")} #yescrypt
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type = @("AMD","CPU")
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

foreach ($Miner_Vendor in @("AMD","CPU")) {
    $Session.DevicesByTypes.$Miner_Vendor | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true
            $Algorithm = $_.MainAlgorithm
            $Algorithm_Norm_0 = Get-Algorithm $Algorithm
            $MinMemGb = $_.MinMemGb
        
            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
				        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				    	$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                        $DeviceIntensity = ($Miner_Device | % {"0"}) -join ','
                        $First = $false
                    }

                    $Pool_Port_Index = if ($Miner_Vendor -eq "CPU") {"CPU"} else {"GPU"}
				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$Algorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$Algorithm_Norm.Port}

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--algorithm $Algorithm --api-enable --api-port `$mport --api-rig-name $($Session.Config.Pools.$($Pools.$Algorithm_Norm.Name).Worker) $(if ($Miner_Vendor -eq "CPU") {"--disable-gpu$(if ($Session.Config.CPUMiningThreads){" --cpu-threads $($Session.Config.CPUMiningThreads)"})$(if ($Session.Config.CPUMiningAffinity -ne ''){" --cpu-affinity $($Session.Config.CPUMiningAffinity)"})"} else {"--gpu-id $DeviceIDsAll --gpu-intensity $DeviceIntensity --disable-cpu --disable-gpu-watchdog --max-no-share-sent 120"}) --pool $($Pools.$Algorithm_Norm.Host):$($Pool_Port) --wallet $($Pools.$Algorithm_Norm.User) --password $($Pools.$Algorithm_Norm.Pass) --tls $(if ($Pools.$Algorithm_Norm.SSL) {"true"} else {"false"}) --nicehash $(if ($Pools.$Algorithm_Norm.Name -match 'NiceHash') {"true"} else {"false"}) --keepalive --retry-time 10 $($_.Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API            = "SrbMiner"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = if ($_.ExtendInterval) {$_.ExtendInterval} elseif ($Miner_Vendor -eq "CPU") {2} else {$null}
                        Penalty        = 0
					    DevFee         = $_.Fee
					    ManualUri      = $ManualUri
					    EnvVars        = if ($Miner_Vendor -ne "CPU") {@("GPU_MAX_SINGLE_ALLOC_PERCENT=100","GPU_FORCE_64BIT_PTR=0")} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
				    }
			    }
		    }
        }
    }
}