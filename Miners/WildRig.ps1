using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 0.75
$Cuda = "8.0"
$Version = "0.39.2"

if ($IsLinux) {
    $Path = ".\Bin\GPU-WildRig\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.39.2-wildrigmulti/wildrig-multi-linux-0.39.2.tar.xz"
} else {
    $Path = ".\Bin\GPU-WildRig\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.39.2-wildrigmulti/wildrig-multi-windows-0.39.2.7z"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo";                     Vendor = @("AMD","INTEL");          Params = ""} #Aergo
    [PSCustomObject]@{MainAlgorithm = "anime";                     Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Anime
    [PSCustomObject]@{MainAlgorithm = "bcd";                       Vendor = @("AMD","INTEL");          Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";                   Vendor = @("AMD","INTEL");          Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "blake2b-btcc";              Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; CoinSymbols = @("BCHC","TNET")} #Blake2b-TNET/BTCC
    [PSCustomObject]@{MainAlgorithm = "blake2b-glt";               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; CoinSymbols = @("GLT")} #Blake2b-GLT
    [PSCustomObject]@{MainAlgorithm = "bmw512";                    Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #BMW512
    [PSCustomObject]@{MainAlgorithm = "c11";                       Vendor = @("AMD","INTEL");          Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "curvehash";                 Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 1.0; ExtendInterval = 3} #CurveHash
    [PSCustomObject]@{MainAlgorithm = "dedal";                     Vendor = @("AMD","INTEL");          Params = ""} #Dedal
    [PSCustomObject]@{MainAlgorithm = "evrprogpow"; DAG = $true;   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #EvrProgPow / Evrmore Coin
    [PSCustomObject]@{MainAlgorithm = "firopow"; DAG = $true;      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #FiroPow
    [PSCustomObject]@{MainAlgorithm = "ghostrider";                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; FaultTolerance = 8; ExcludePoolName = "C3pool|MoneroOcean"} #Ghostrider
    [PSCustomObject]@{MainAlgorithm = "glt-astralhash";            Vendor = @("AMD","INTEL");        Params = ""} #GLT-AstralHash
    [PSCustomObject]@{MainAlgorithm = "glt-globalhash";            Vendor = @("AMD","INTEL");        Params = ""} #GLT-GlobalHash, new in v0.18.0 beta
    [PSCustomObject]@{MainAlgorithm = "glt-jeonghash";             Vendor = @("AMD","INTEL");        Params = ""} #GLT-JeongHash
    [PSCustomObject]@{MainAlgorithm = "glt-padihash";              Vendor = @("AMD","INTEL");        Params = ""} #GLT-PadiHash
    [PSCustomObject]@{MainAlgorithm = "glt-pawelhash";             Vendor = @("AMD","INTEL");        Params = ""} #GLT-PawelHash
    [PSCustomObject]@{MainAlgorithm = "heavyhash";                 Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 2; FaultTolerance = 0.4} #Heavyhash/OBTC
    [PSCustomObject]@{MainAlgorithm = "hex";                       Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725";                   Vendor = @("AMD","INTEL");          Params = ""} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "kawpow";       DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "unMineable"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow2g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow3g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow4g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow5g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "lyra2tdc";                  Vendor = @("AMD","INTEL");          Params = ""} #Lyra2TDC
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";                   Vendor = @("AMD","INTEL");          Params = ""} #Lyra2RE3
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban";               Vendor = @("AMD","INTEL");          Params = ""} #Lyra2vc0ban
    [PSCustomObject]@{MainAlgorithm = "megabtx";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "memehash";                  Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Memehash/PEPE
    [PSCustomObject]@{MainAlgorithm = "memehashv2";                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #MemehashV2/PEPE2, new in v0.36.7
    [PSCustomObject]@{MainAlgorithm = "mike";                      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 1.0; FaultTolerance = 8; ExtendInterval = 3} #Mike
    [PSCustomObject]@{MainAlgorithm = "minotaur";                  Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "nexapow"; DAG = $true;      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #NexaPow/NEXA
    [PSCustomObject]@{MainAlgorithm = "phi";                       Vendor = @("AMD","INTEL");          Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi5";                      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #PHI5
    [PSCustomObject]@{MainAlgorithm = "progpow-ethercore"; DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #ProgPowEthercore
    [PSCustomObject]@{MainAlgorithm = "progpow-sero"; DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #ProgPowSero
    [PSCustomObject]@{MainAlgorithm = "progpow-veil"; DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #ProgPowVeil
    [PSCustomObject]@{MainAlgorithm = "progpowz";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "Fairpool"} #ProgPowZ
    [PSCustomObject]@{MainAlgorithm = "pufferfish2";               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 1.0} #Pufferfish2/BMB
    [PSCustomObject]@{MainAlgorithm = "rwahash";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 2.0} #RWAHash
    [PSCustomObject]@{MainAlgorithm = "sha512256d";                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA512256d
    [PSCustomObject]@{MainAlgorithm = "sha256csm";                 Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 2.0} #SHA256csm
    [PSCustomObject]@{MainAlgorithm = "sha256q";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA256q
    [PSCustomObject]@{MainAlgorithm = "sha256t";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA256t
    [PSCustomObject]@{MainAlgorithm = "skein2";                    Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Skein2
    [PSCustomObject]@{MainAlgorithm = "skunkhash";                 Vendor = @("AMD","INTEL");          Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "skydoge";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 2.0; ExtendInterval = 3} #SkyDoge/SKY
    [PSCustomObject]@{MainAlgorithm = "timetravel";                Vendor = @("AMD","INTEL");          Params = ""} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus";                    Vendor = @("AMD","INTEL");          Params = ""} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "veil";                      Vendor = @("AMD","INTEL");          Params = ""; Algorithm = "x16rt"; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt-VEIL
    [PSCustomObject]@{MainAlgorithm = "vprogpow";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "Beepool"} #vProgPoW
    [PSCustomObject]@{MainAlgorithm = "x11k";                      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #X11k
    [PSCustomObject]@{MainAlgorithm = "x16r";                      Vendor = @("AMD","INTEL");          Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16rt";                     Vendor = @("AMD","INTEL");          Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16rv2";                    Vendor = @("AMD","INTEL");          Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rv2
    [PSCustomObject]@{MainAlgorithm = "x16s";                      Vendor = @("AMD","INTEL");          Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";                       Vendor = @("AMD","INTEL");          Params = ""} #X17
    [PSCustomObject]@{MainAlgorithm = "x18";                       Vendor = @("AMD","INTEL");          Params = ""} #X18
    [PSCustomObject]@{MainAlgorithm = "x20r";                      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #X20r
    [PSCustomObject]@{MainAlgorithm = "x21s";                      Vendor = @("AMD","INTEL");          Params = ""} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";                      Vendor = @("AMD","INTEL");          Params = ""} #X22i
    [PSCustomObject]@{MainAlgorithm = "x25x";                      Vendor = @("AMD","INTEL");          Params = ""; ExtendInterval = 2} #X25x
    [PSCustomObject]@{MainAlgorithm = "x33";                       Vendor = @("AMD","INTEL");          Params = ""} #X33
    [PSCustomObject]@{MainAlgorithm = "xevan";                     Vendor = @("AMD","INTEL");          Params = ""} #Xevan
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

$WatchdogParams = "$(if ($Session.Config.RebootOnGPUFailure -and $Session.Config.EnableRestartComputer) {"--watchdog-script='$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")' "})"

foreach ($Miner_Vendor in @("AMD","INTEL","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $DeviceParams = Switch ($Miner_Vendor) {
            "AMD"    {"--opencl-platforms amd"}
            "INTEL"  {"--opencl-platforms intel"}
            "NVIDIA" {"--opencl-platforms nvidia"}
        }

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or (Compare-Version $Version $_.Version) -ge 0)}).ForEach({
            $First = $True

            $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            $Miner_Device = $Device.Where({Test-VRAM $_ $MinMemGB})

            $Params = "$($WatchdogParams)$(if ($Pools.$Algorithm_Norm_0.ScratchPadUrl) {"--scratchpad-url $($Pools.$Algorithm_Norm_0.ScratchPadUrl) --scratchpad-file scratchpad-$($Pools.$Algorithm_Norm_0.CoinSymbol.ToLower()).bin "})$($_.Params)"

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join ','
                        $First = $false
                    }

				    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--api-port `$mport -a $($Algorithm) -o stratum+tcp$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User -replace "^nexa:")$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -r 4 -R 5 --max-rejects 10 --multiple-instance --opencl-devices $($DeviceIDsAll) $($DeviceParams) --opencl-threads auto --opencl-launch auto --gpu-temp-limit=95 $($Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
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
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        ListDevices    = "--print-devices"
                        ListPlatforms  = "--print-platforms"
                        ExcludePoolName = $_.ExcludePoolName
				    }
			    }
		    }
        })
    }
}