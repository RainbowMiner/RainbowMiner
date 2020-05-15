using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\AMD-WildRig\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.23.2-wildrigmulti/wildrig-multi-linux-0.23.2.1.tar.gz"
    $Version = "0.23.2"
} else {
    $Path = ".\Bin\AMD-WildRig\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.23.2-wildrigmulti/wildrig-multi-windows-0.23.2.1.7z"
    $Version = "0.23.2"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 1.0


if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo";      Params = ""} #Aergo
    [PSCustomObject]@{MainAlgorithm = "anime";      Params = ""} #Anime
    [PSCustomObject]@{MainAlgorithm = "bcd";        Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";    Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "blake2b-btcc"; Params = ""} #Blake2b
    [PSCustomObject]@{MainAlgorithm = "blake2b-glt";  Params = ""} #Blake2b-GLT
    [PSCustomObject]@{MainAlgorithm = "bmw512";     Params = ""} #BMW512
    [PSCustomObject]@{MainAlgorithm = "c11";        Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "dedal";      Params = ""} #Dedal
    [PSCustomObject]@{MainAlgorithm = "exosis";     Params = ""} #Exosis
    [PSCustomObject]@{MainAlgorithm = "geek";       Params = ""} #Geek
    [PSCustomObject]@{MainAlgorithm = "glt-astralhash"; Params = ""} #GLT-AstralHash
    [PSCustomObject]@{MainAlgorithm = "glt-globalhash"; Params = ""} #GLT-GlobalHash, new in v0.18.0 beta
    [PSCustomObject]@{MainAlgorithm = "glt-jeonghash";  Params = ""} #GLT-JeongHash
    [PSCustomObject]@{MainAlgorithm = "glt-padihash";   Params = ""} #GLT-PadiHash
    [PSCustomObject]@{MainAlgorithm = "glt-pawelhash";  Params = ""} #GLT-PawelHash
    [PSCustomObject]@{MainAlgorithm = "hex";        Params = ""} #Hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725";    Params = ""} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "honeycomb";  Params = ""} #Honeycomb
    [PSCustomObject]@{MainAlgorithm = "kawpow"; Params = ""; ExtendInterval = 2; Version = "0.22.0"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "lyra2tdc";   Params = ""} #Lyra2TDC
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";    Params = ""} #Lyra2RE3
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban";Params = ""} #Lyra2vc0ban
    [PSCustomObject]@{MainAlgorithm = "mtp";        Params = ""} #MTP, new in v0.20.0 beta
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr";    Params = ""} #MTPTcr, new in v0.20.0 beta, --split-job 4
    [PSCustomObject]@{MainAlgorithm = "phi";        Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "progpow-ethercore"; Params = ""; ExtendInterval = 2; Version = "0.21.0"} #ProgPowEthercore
    [PSCustomObject]@{MainAlgorithm = "progpow-sero"; Params = ""; ExtendInterval = 2; Version = "0.23.0"} #ProgPowSero
    [PSCustomObject]@{MainAlgorithm = "progpowz"; Params = ""; ExtendInterval = 2; Version = "0.21.0"; ExcludePoolName = @("Fairpool")} #ProgPowZ
    #[PSCustomObject]@{MainAlgorithm = "rainforest"; Params = ""} #Rainforest
    [PSCustomObject]@{MainAlgorithm = "renesis";    Params = ""} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sha256csm";  Params = ""; Version = "0.20.6"} #SHA256csm
    [PSCustomObject]@{MainAlgorithm = "sha256q";    Params = ""} #SHA256q
    [PSCustomObject]@{MainAlgorithm = "sha256t";    Params = ""} #SHA256t
    [PSCustomObject]@{MainAlgorithm = "skein2";     Params = ""} #Skein2
    [PSCustomObject]@{MainAlgorithm = "skunkhash";  Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa";      Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus";     Params = ""} #Tribus
    [PSCustomObject]@{MainAlgorithm = "veil";       Params = ""; Algorithm = "x16rt"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt-VEIL
    [PSCustomObject]@{MainAlgorithm = "wildkeccak"; Params = ""; ExtendInterval = 3; DevFee = 2.0} #Wildkeccak
    [PSCustomObject]@{MainAlgorithm = "x16r";       Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16rt";      Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16rv2";     Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rv2
    [PSCustomObject]@{MainAlgorithm = "x16s";       Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";        Params = ""} #X17
    [PSCustomObject]@{MainAlgorithm = "x17r";       Params = ""} #X17r
    [PSCustomObject]@{MainAlgorithm = "x17r-protocol2";       Params = ""} #X17r-protocol2
    [PSCustomObject]@{MainAlgorithm = "x18";        Params = ""} #X18
    [PSCustomObject]@{MainAlgorithm = "x20r";       Params = ""} #X20r
    [PSCustomObject]@{MainAlgorithm = "x21s";       Params = ""} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";       Params = ""} #X22i
    [PSCustomObject]@{MainAlgorithm = "x25x";       Params = ""} #X25x
    [PSCustomObject]@{MainAlgorithm = "xevan";      Params = ""} #Xevan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $True
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.Where({-not $_.Version -or (Compare-Version $Version $_.Version) -ge 0}).ForEach({
        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = if ($Algorithm_Norm_0 -match "^(Ethash|KawPow|ProgPow)") {if ($Pools.$Algorithm_Norm_0.EthDAGSize) {$Pools.$Algorithm_Norm_0.EthDAGSize} else {Get-EthDAGSize $Pools.$Algorithm_Norm_0.CoinSymbol}} else {$_.MinMemGB}

        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

        $Params = "$(if ($Pools.$Algorithm_Norm_0.ScratchPadUrl) {"--scratchpad-url $($Pools.$Algorithm_Norm_0.ScratchPadUrl) --scratchpad-file scratchpad-$($Pools.$Algorithm_Norm_0.CoinSymbol.ToLower()).bin "})$($_.Params)"

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch "^$($_.ExcludePoolName -join "|")") -and ($Algorithm -notmatch "^blake2b" -or ($Algorithm -eq "blake2b-btcc" -and $Pools.$Algorithm_Norm.CoinSymbol -ne "GLT") -or ($Algorithm -eq "blake2b-glt" -and $Pools.$Algorithm_Norm.CoinSymbol -eq "GLT"))) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $Miner_PlatformId = $Miner_Device | Select -Unique -ExpandProperty PlatformId
                    $First = $false
                }

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api-port `$mport --algo $($Algorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -r 4 -R 10 --send-stale --donate-level 1 --multiple-instance --opencl-devices $($DeviceIDsAll) --opencl-platform $($Miner_PlatformId) --opencl-threads auto --opencl-launch auto $($Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					API            = "XMRig"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = if ($_.DevFee) {$_.DevFee} else {$DevFee}
					ManualUri      = $ManualUri
					EnvVars        = @("GPU_MAX_WORKGROUP_SIZE=256")
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    })
}