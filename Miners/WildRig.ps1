using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\AMD-WildRig\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.15.5-wildrigmulti/wildrig-multi-linux-0.15.5.tar.gz"
} else {
    $Path = ".\Bin\AMD-WildRig\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.15.5-wildrigmulti/wildrig-multi-windows-0.15.5.7z"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 1.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo";      Params = ""} #Aergo
    [PSCustomObject]@{MainAlgorithm = "bcd";        Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";    Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "bmw512";     Params = ""} #BMW512
    [PSCustomObject]@{MainAlgorithm = "c11";        Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "dedal";      Params = ""} #Dedal
    [PSCustomObject]@{MainAlgorithm = "geek";       Params = ""} #Geek
    [PSCustomObject]@{MainAlgorithm = "glt-astralhash"; Params = ""} #GLT-AstralHash
    [PSCustomObject]@{MainAlgorithm = "glt-jeonghash";  Params = ""} #GLT-JeongHash
    [PSCustomObject]@{MainAlgorithm = "glt-padihash";   Params = ""} #GLT-PadiHash
    [PSCustomObject]@{MainAlgorithm = "glt-pawelhash";  Params = ""} #GLT-PawelHash
    [PSCustomObject]@{MainAlgorithm = "hex";        Params = ""} #Hex
    #[PSCustomObject]@{MainAlgorithm = "honeycomb"; Params = ""} #Honeycomb
    [PSCustomObject]@{MainAlgorithm = "hmq1725";    Params = ""} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";    Params = ""} #Lyra2RE3
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban";Params = ""} #Lyra2vc0ban
    [PSCustomObject]@{MainAlgorithm = "phi";        Params = ""} #PHI
    #[PSCustomObject]@{MainAlgorithm = "rainforest"; Params = ""} #Rainforest
    [PSCustomObject]@{MainAlgorithm = "renesis";    Params = ""} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sha256q";    Params = ""} #SHA256q
    [PSCustomObject]@{MainAlgorithm = "sha256t";    Params = ""} #SHA256t
    [PSCustomObject]@{MainAlgorithm = "skunkhash";  Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa";      Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus";     Params = ""} #Tribus
    [PSCustomObject]@{MainAlgorithm = "veil";       Params = ""; Algorithm = "x16rt"} #X16rt-VEIL
    [PSCustomObject]@{MainAlgorithm = "x16r";       Params = ""} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16rt";      Params = ""} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16s";       Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";        Params = ""} #X17
    [PSCustomObject]@{MainAlgorithm = "x18";        Params = ""} #X18
    [PSCustomObject]@{MainAlgorithm = "x20r";       Params = ""} #X20r
    [PSCustomObject]@{MainAlgorithm = "x21s";       Params = ""} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";       Params = ""} #X22i
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
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

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_GPU  = $Miner_Device.OpenCL.Name | Select-Object -First 1
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port    

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
    $Miner_PlatformId = $Miner_Device | Select -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {
        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name        = $Miner_Name
					DeviceName  = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path        = $Path
					Arguments   = "--api-port $($Miner_Port) --algo $($Algorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -r 4 -R 10 --send-stale --donate-level 1 --multiple-instance --opencl-devices $($DeviceIDsAll) --opencl-platform $($Miner_PlatformId) --opencl-threads auto --opencl-launch auto $($Params)"
					HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API         = "XMRig"
					Port        = $Miner_Port
					Uri         = $Uri
					DevFee      = $DevFee
					ManualUri   = $ManualUri
					EnvVars     = @("GPU_MAX_WORKGROUP_SIZE=256")
				}
			}
		}
    }
}