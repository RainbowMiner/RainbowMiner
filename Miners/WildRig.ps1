using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-WildRig\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.27.4-wildrigmulti/wildrig-multi-linux-0.27.4.tar.gz"
} else {
    $Path = ".\Bin\GPU-WildRig\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.27.4-wildrigmulti/wildrig-multi-windows-0.27.4.7z"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 1.0
$Cuda = "8.0"
$Version = "0.27.4"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo";        Vendor = @("AMD");          Params = ""} #Aergo
    [PSCustomObject]@{MainAlgorithm = "anime";        Vendor = @("AMD");          Params = ""} #Anime
    [PSCustomObject]@{MainAlgorithm = "bcd";          Vendor = @("AMD");          Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";      Vendor = @("AMD");          Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "blake2b-btcc"; Vendor = @("AMD","NVIDIA"); Params = ""} #Blake2b
    [PSCustomObject]@{MainAlgorithm = "blake2b-glt";  Vendor = @("AMD","NVIDIA"); Params = ""} #Blake2b-GLT
    [PSCustomObject]@{MainAlgorithm = "bmw512";       Vendor = @("AMD","NVIDIA"); Params = ""} #BMW512
    [PSCustomObject]@{MainAlgorithm = "c11";          Vendor = @("AMD");          Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "dedal";        Vendor = @("AMD");          Params = ""} #Dedal
    [PSCustomObject]@{MainAlgorithm = "exosis";       Vendor = @("AMD");          Params = ""} #Exosis
    [PSCustomObject]@{MainAlgorithm = "geek";         Vendor = @("AMD");          Params = ""} #Geek
    [PSCustomObject]@{MainAlgorithm = "glt-astralhash"; Vendor = @("AMD");        Params = ""} #GLT-AstralHash
    [PSCustomObject]@{MainAlgorithm = "glt-globalhash"; Vendor = @("AMD");        Params = ""} #GLT-GlobalHash, new in v0.18.0 beta
    [PSCustomObject]@{MainAlgorithm = "glt-jeonghash";  Vendor = @("AMD");        Params = ""} #GLT-JeongHash
    [PSCustomObject]@{MainAlgorithm = "glt-padihash";   Vendor = @("AMD");        Params = ""} #GLT-PadiHash
    [PSCustomObject]@{MainAlgorithm = "glt-pawelhash";  Vendor = @("AMD");        Params = ""} #GLT-PawelHash
    [PSCustomObject]@{MainAlgorithm = "hex";          Vendor = @("AMD","NVIDIA"); Params = ""} #Hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725";      Vendor = @("AMD");          Params = ""} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "honeycomb";    Vendor = @("AMD");          Params = ""} #Honeycomb
    [PSCustomObject]@{MainAlgorithm = "kawpow";       Vendor = @("AMD","NVIDIA"); Params = ""; ExtendInterval = 2; Version = "0.22.0"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "lyra2tdc";     Vendor = @("AMD");          Params = ""; DevFee = 2.0} #Lyra2TDC
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";      Vendor = @("AMD");          Params = ""} #Lyra2RE3
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban";  Vendor = @("AMD");          Params = ""} #Lyra2vc0ban
    [PSCustomObject]@{MainAlgorithm = "megabtx";      Vendor = @("AMD","NVIDIA"); Params = ""; DevFee = 2.0} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "megamec";      Vendor = @("AMD","NVIDIA"); Params = ""} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "minotaur";     Vendor = @("AMD","NVIDIA"); Params = ""; DevFee = 5.0} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "mtp";          Vendor = @("AMD");          Params = ""} #MTP, new in v0.20.0 beta
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr";      Vendor = @("AMD");          Params = ""} #MTPTcr, new in v0.20.0 beta, --split-job 4
    [PSCustomObject]@{MainAlgorithm = "phi";          Vendor = @("AMD");          Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "progpow-ethercore"; Vendor = @("AMD","NVIDIA"); Params = ""; ExtendInterval = 2; Version = "0.21.0"} #ProgPowEthercore
    [PSCustomObject]@{MainAlgorithm = "progpow-sero"; Vendor = @("AMD","NVIDIA"); Params = ""; ExtendInterval = 2; Version = "0.23.0"; ExcludePoolName = "^Beepool"} #ProgPowSero
    [PSCustomObject]@{MainAlgorithm = "progpowz";     Vendor = @("AMD","NVIDIA"); Params = ""; ExtendInterval = 2; Version = "0.21.0"; ExcludePoolName = "^Fairpool"} #ProgPowZ
    #[PSCustomObject]@{MainAlgorithm = "rainforest";   Vendor = @("AMD","NVIDIA"); Params = ""} #Rainforest
    [PSCustomObject]@{MainAlgorithm = "renesis";      Vendor = @("AMD");          Params = ""} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sha256csm";    Vendor = @("AMD","NVIDIA"); Params = ""; DevFee = 2.0; Version = "0.20.6"} #SHA256csm
    [PSCustomObject]@{MainAlgorithm = "sha256q";      Vendor = @("AMD","NVIDIA"); Params = ""} #SHA256q
    [PSCustomObject]@{MainAlgorithm = "sha256t";      Vendor = @("AMD","NVIDIA"); Params = ""} #SHA256t
    [PSCustomObject]@{MainAlgorithm = "skein2";       Vendor = @("AMD");          Params = ""} #Skein2
    [PSCustomObject]@{MainAlgorithm = "skunkhash";    Vendor = @("AMD");          Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa";        Vendor = @("AMD");          Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "timetravel";   Vendor = @("AMD");          Params = ""} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus";       Vendor = @("AMD");          Params = ""} #Tribus
    [PSCustomObject]@{MainAlgorithm = "veil";         Vendor = @("AMD");          Params = ""; Algorithm = "x16rt"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt-VEIL
    [PSCustomObject]@{MainAlgorithm = "vprogpow";     Vendor = @("AMD","NVIDIA"); Params = ""; ExtendInterval = 2; ExcludePoolName = "^Beepool"} #vProgPoW
    [PSCustomObject]@{MainAlgorithm = "wildkeccak";   Vendor = @("AMD");          Params = ""; ExtendInterval = 3; DevFee = 2.0} #Wildkeccak
    [PSCustomObject]@{MainAlgorithm = "x11k";         Vendor = @("AMD","NVIDIA"); Params = ""} #X11k
    [PSCustomObject]@{MainAlgorithm = "x16r";         Vendor = @("AMD");          Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16rt";        Vendor = @("AMD");          Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16rv2";       Vendor = @("AMD");          Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rv2
    [PSCustomObject]@{MainAlgorithm = "x16s";         Vendor = @("AMD");          Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";          Vendor = @("AMD");          Params = ""} #X17
    [PSCustomObject]@{MainAlgorithm = "x17r";         Vendor = @("AMD");          Params = "--protocol ufo2"; DevFee = 2.0} #X17r
    [PSCustomObject]@{MainAlgorithm = "x18";          Vendor = @("AMD");          Params = ""} #X18
    [PSCustomObject]@{MainAlgorithm = "x20r";         Vendor = @("AMD");          Params = ""} #X20r
    [PSCustomObject]@{MainAlgorithm = "x21s";         Vendor = @("AMD");          Params = ""} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";         Vendor = @("AMD");          Params = ""} #X22i
    [PSCustomObject]@{MainAlgorithm = "x25x";         Vendor = @("AMD");          Params = ""} #X25x
    [PSCustomObject]@{MainAlgorithm = "x33";          Vendor = @("AMD");          Params = ""} #X33
    [PSCustomObject]@{MainAlgorithm = "xevan";        Vendor = @("AMD");          Params = ""} #Xevan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $DeviceParams = Switch ($Miner_Vendor) {
            "AMD"    {"--opencl-platforms amd"}
            "NVIDIA" {"--opencl-platforms nvidia"}
        }

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or (Compare-Version $Version $_.Version) -ge 0)}).ForEach({
            $First = $True

            $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $MinMemGB = if ($Algorithm_Norm_0 -match "^(Ethash|KawPow|ProgPow|vProgPow)") {if ($Pools.$Algorithm_Norm_0.EthDAGSize) {$Pools.$Algorithm_Norm_0.EthDAGSize} else {Get-EthDAGSize $Pools.$Algorithm_Norm_0.CoinSymbol}} else {$_.MinMemGB}

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

            $Params = "$(if ($Pools.$Algorithm_Norm_0.ScratchPadUrl) {"--scratchpad-url $($Pools.$Algorithm_Norm_0.ScratchPadUrl) --scratchpad-file scratchpad-$($Pools.$Algorithm_Norm_0.CoinSymbol.ToLower()).bin "})$($_.Params)"

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName) -and ($Algorithm -notmatch "^blake2b" -or ($Algorithm -eq "blake2b-btcc" -and $Pools.$Algorithm_Norm.CoinSymbol -ne "GLT") -or ($Algorithm -eq "blake2b-glt" -and $Pools.$Algorithm_Norm.CoinSymbol -eq "GLT"))) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                        $First = $false
                    }

				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--api-port `$mport -a $($Algorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -r 4 -R 5 --max-rejects 10 --send-stale --donate-level 1 --multiple-instance --opencl-devices $($DeviceIDsAll) $($DeviceParams) --opencl-threads auto --opencl-launch auto $($Params)"
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
}