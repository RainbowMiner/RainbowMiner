using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$ManualUri = "https://github.com/Kudaraidee/cpuminer-opt-kudaraidee/releases"
$Port = "206{0:d2}"
$DevFee = 0.0
$Version = "1.2.4"

$Path = $null

if ($IsLinux) {
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        if ($Global:GlobalCPUInfo.Architecture -eq 8) {
            $Path = ".\Bin\CPU-Kudaraidee\cpuminer-armv8$($f=$Global:GlobalCPUInfo.Features;$(if($f.sha3 -and $f.sve2 -and $f.aes){'.5-crypto-sha3-sve2'}elseif($f.sha3 -and $f.aes){'.4-crypto-sha3'}elseif($f.sha2 -and $f.aes){'-crypto'}))"
            $Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.4-kudaraidee/cpuminer-opt-kudaraidee-1.2.4-arm.7z"
        } elseif ($Global:GlobalCPUInfo.Architecture -eq 9) {
            $Path = ".\Bin\CPU-Kudaraidee\cpuminer-armv9$($f=$Global:GlobalCPUInfo.Features;$(if($f.sha3 -and $f.aes){'-crypto-sha3'}elseif($f.sha2 -and $f.aes){'-crypto'}))"
            $Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.4-kudaraidee/cpuminer-opt-kudaraidee-1.2.4-arm.7z"
        }
    } else {
        $Path = ".\Bin\CPU-Kudaraidee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$v=$Global:GlobalCPUInfo.Vendor;$(if($f.avx512 -and $f.sha -and $f.vaes) {'avx512-sha-vaes'}elseif($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.vaes) {"avx2-sha-vaes"}elseif($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.avx){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}elseif($f.sse42){'sse42'}elseif($f.ssse3){"ssse3"}else{'sse2'}))"
        $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.4-kudaraidee/cpuminer-opt-kudaraidee-1.2.4-linux.7z"
    }
} else {
    $Path = ".\Bin\CPU-Kudaraidee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx512 -and $f.sha -and $f.vaes){'avx512-sha-vaes'}elseif($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.vaes){'avx2-sha-vaes'}elseif($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.avx){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.4-kudaraidee/cpuminer-opt-kudaraidee-1.2.4-win.7z"
}

if ($Path -eq $null) {return}

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "argon2d1000";  Params = ""} #Argon2d1000
    #[PSCustomObject]@{MainAlgorithm = "argon2d16000";  Params = ""} #Argon2d16000
    #[PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""} #CpuPower
    #[PSCustomObject]@{MainAlgorithm = "flex"; Params = ""} #Flex, disabled, very slow and memory leak
    [PSCustomObject]@{MainAlgorithm = "rinhash"; Params = ""} #RinHash
    [PSCustomObject]@{MainAlgorithm = "x11k"; Params = ""} #x11k
    [PSCustomObject]@{MainAlgorithm = "x11kvs"; Params = ""} #x11kvs
    [PSCustomObject]@{MainAlgorithm = "XelisV2Pepew"; Params = ""; Algorithm = "xelisv2"} #XelisV2Pepew/PEPEW
    [PSCustomObject]@{MainAlgorithm = "Yespoweradvc"; Params = ""} #YespowerADVC
    [PSCustomObject]@{MainAlgorithm = "yespowermgpc"; Params = ""} #Magpiecoin
    #[PSCustomObject]@{MainAlgorithm = "Yespowereqpay"; Params = ""} #YespowerEQPAY
    [PSCustomObject]@{MainAlgorithm = "yespowerarwn"; Params = ""} #Arrowana
    [PSCustomObject]@{MainAlgorithm = "yespowersugar"; Params = ""} #Yespower SugarChain (SUGAR)
    #[PSCustomObject]@{MainAlgorithm = "yespowerurx"; Params = ""} #Yespower Uranium-X (URX)
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU","ARMCPU")
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

$Global:DeviceCache.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU | Where-Object {$_.Model -eq $Miner_Model}

    $Commands | Where-Object {-not $_.NeverProfitable -or $Session.Config.EnableNeverprofitableAlgos} | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
        $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

        $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity"})"

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = if ($_.Path) {$_.Path} else {$Path}
					Arguments      = "-b 127.0.0.1:`$mport -a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) -q $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    PrerequisitePath = $null
                    PrerequisiteURI  = ""
                    PrerequisiteMsg  = ""
                    ExcludePoolName = $_.ExcludePoolName
				}
			}
		}
    }
}
