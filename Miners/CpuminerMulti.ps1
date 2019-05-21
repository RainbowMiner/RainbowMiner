using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\CPU-Multi\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha){'avx2-sha'}elseif($f.avx2){'avx2'}elseif($f.avx){'avx'}elseif($f.aes -and $f.sse42){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'})).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.6.2-cpuminermulti/cpuminer-multi-1.3.6.2.7z"
$ManualUri = "https://github.com/tpruvot/cpuminer-multi/releases"
$Port = "513{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "allium"; Params = ""; ExtendInterval = 2} #allium, CpuminerJayddee faster
    #[PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""; ExtendInterval = 2} #axiom
    #[PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""; ExtendInterval = 2} #BMW
    #[PSCustomObject]@{MainAlgorithm = "drop"; Params = ""; ExtendInterval = 2} #Drop
    #[PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""; ExtendInterval = 2} #Fresh
    #[PSCustomObject]@{MainAlgorithm = "heavy"; Params = ""; ExtendInterval = 2} #Heavy
    #[PSCustomObject]@{MainAlgorithm = "jha"; Params = ""; ExtendInterval = 2} #JHA
    #[PSCustomObject]@{MainAlgorithm = "luffa"; Params = ""; ExtendInterval = 2} #Luffa
    #[PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""; ExtendInterval = 2} #Pentablake
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""; ExtendInterval = 2} #PHI2
    #[PSCustomObject]@{MainAlgorithm = "pluck"; Params = ""; ExtendInterval = 2} #Pluck
    [PSCustomObject]@{MainAlgorithm = "rfv2"; Params = ""; ExtendInterval = 2} #Rainforest2
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""; ExtendInterval = 2} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "scrypt:2048"; Params = ""; ExtendInterval = 2} #ScryptN
    #[PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""; ExtendInterval = 2} #SHAvite3
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""; ExtendInterval = 2} #Skein2
    [PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""; ExtendInterval = 2} #Verium
    #[PSCustomObject]@{MainAlgorithm = "x12"; Params = ""; ExtendInterval = 2} #X12
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""; ExtendInterval = 2} #Yescrypt, CpuminerJayddee faster
    #[PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""; ExtendInterval = 2} #ZR5

    #GPU or ASIC - never profitable
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""; ExtendInterval = 2} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""; ExtendInterval = 2} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = ""; ExtendInterval = 2} #C11
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""; ExtendInterval = 2} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""; ExtendInterval = 2} #KeccakC
    #[PSCustomObject]@{MainAlgorithm = "lyra2re"; Params = ""; ExtendInterval = 2} #Lyra2RE
    #[PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Params = ""; ExtendInterval = 2} #Lyra2REV2
    #[PSCustomObject]@{MainAlgorithm = "phi"; Params = ""; ExtendInterval = 2} #PHI
    #[PSCustomObject]@{MainAlgorithm = "s3"; Params = ""; ExtendInterval = 2} #S3
    #[PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""; ExtendInterval = 2} #SonoA
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""; ExtendInterval = 2} #Timetravel
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""; ExtendInterval = 2} #X11evo
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""; ExtendInterval = 2} #X16r
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""; ExtendInterval = 2} #X16s
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""; ExtendInterval = 2} #X17
    #[PSCustomObject]@{MainAlgorithm = "xevan"; Params = ""; ExtendInterval = 2} #Xevan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				[PSCustomObject]@{
					Name = $Miner_Name
					DeviceName = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path = $Path
					Arguments = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams) $($_.Params)"
					HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API = "Ccminer"
					Port = $Miner_Port
					Uri = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
					DevFee = $DevFee
					ManualUri = $ManualUri
				}
			}
		}
    }
}