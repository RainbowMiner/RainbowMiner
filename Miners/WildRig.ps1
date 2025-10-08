using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 0.00
$Cuda = "11.0"
$Version = "0.45.7"

if ($IsLinux) {
    $Path = ".\Bin\GPU-WildRig\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.45.7-wildrigmulti/wildrig-multi-linux-0.45.7.tar.xz"
} else {
    $Path = ".\Bin\GPU-WildRig\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.45.7-wildrigmulti/wildrig-multi-windows-0.45.7.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "anime";                     Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Anime
    [PSCustomObject]@{MainAlgorithm = "bitcore";                   Vendor = @("AMD","INTEL");          Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "bmw512";                    Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #BMW512
    [PSCustomObject]@{MainAlgorithm = "c11";                       Vendor = @("AMD","INTEL");          Params = ""} #C11
    #[PSCustomObject]@{MainAlgorithm = "clchash";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 3.00; AmdCompute="RDNA"} #ClcHash/CLC, removed with v0.43.3
    [PSCustomObject]@{MainAlgorithm = "curvehash";                 Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00} #CurveHash
    [PSCustomObject]@{MainAlgorithm = "evohash";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; AmdCompute="RDNA"} #Evohash/EVOAI
    [PSCustomObject]@{MainAlgorithm = "evrprogpow"; DAG = $true;   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #EvrProgPow / Evrmore Coin
    [PSCustomObject]@{MainAlgorithm = "firopow"; DAG = $true;      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #FiroPow
    [PSCustomObject]@{MainAlgorithm = "ghostrider";                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; FaultTolerance = 8; ExcludePoolName = "C3pool|MoneroOcean"} #Ghostrider
    [PSCustomObject]@{MainAlgorithm = "hashx7";                    Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; Algorithm = "x7"} #HashX7/6ZIP
    [PSCustomObject]@{MainAlgorithm = "hex";                       Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725";                   Vendor = @("AMD","INTEL");          Params = ""} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "kawpow";       DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75; ExcludePoolName = "unMineable"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow2g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow3g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow4g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow5g";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "megabtx";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "memehash";                  Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Memehash/PEPE
    [PSCustomObject]@{MainAlgorithm = "memehashv2";                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #MemehashV2/PEPE2, new in v0.36.7
    [PSCustomObject]@{MainAlgorithm = "meowpow"; DAG = $true;      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #MeowPow/MEWC
    [PSCustomObject]@{MainAlgorithm = "mike";                      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; FaultTolerance = 8} #Mike
    [PSCustomObject]@{MainAlgorithm = "minotaur";                  Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "nexapow"; DAG = $true;      Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #NexaPow/NEXA
    [PSCustomObject]@{MainAlgorithm = "phi";                       Vendor = @("AMD","INTEL");          Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "progpow-ethercore"; DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3} #ProgPowEthercore
    [PSCustomObject]@{MainAlgorithm = "progpow-quai";      DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #ProgPowQuai
    [PSCustomObject]@{MainAlgorithm = "progpow-sero";      DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #ProgPowSero
    [PSCustomObject]@{MainAlgorithm = "progpow-telestai";  DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #Meraki/TLS
    [PSCustomObject]@{MainAlgorithm = "progpowz";          DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75; ExcludePoolName = "Fairpool"} #ProgPowZ
    [PSCustomObject]@{MainAlgorithm = "qhash";                     Vendor = @("AMD","NVIDIA"); Params = ""; DevFee = 5.00; FaultTolerance = 0.4} #Qhash/QTC, new in v0.43.3
    [PSCustomObject]@{MainAlgorithm = "sha512256d";                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA512256d
    [PSCustomObject]@{MainAlgorithm = "sha256csm";                 Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA256csm
    [PSCustomObject]@{MainAlgorithm = "sha256q";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA256q
    [PSCustomObject]@{MainAlgorithm = "sha256t";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #SHA256t
    [PSCustomObject]@{MainAlgorithm = "skein2";                    Vendor = @("AMD","INTEL","NVIDIA"); Params = ""} #Skein2
    [PSCustomObject]@{MainAlgorithm = "skunkhash";                 Vendor = @("AMD","INTEL");          Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "skydoge";                   Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 2.00} #SkyDoge/SKY
    [PSCustomObject]@{MainAlgorithm = "timetravel";                Vendor = @("AMD","INTEL");          Params = ""} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus";                    Vendor = @("AMD","INTEL");          Params = ""} #Tribus
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
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","INTEL","NVIDIA")
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
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model}

        $DeviceParams = Switch ($Miner_Vendor) {
            "AMD"    {"--opencl-platforms amd"}
            "INTEL"  {"--opencl-platforms intel"}
            "NVIDIA" {"--opencl-platforms nvidia"}
        }

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or (Compare-Version $Version $_.Version) -ge 0)} | ForEach-Object {
            $First = $True

            $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
                if (-not $Pools.$Algorithm_Norm.Host) {continue}

                $QhashParams = ""

                $MinMemGB = if ($_.DAG) {if ($Pools.$Algorithm_Norm.DagSizeMax) {$Pools.$Algorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}
                if ($Miner_Vendor -eq "AMD" -and $_.AmdCompute) {
                    $AmdCompute = $_.AmdCompute
                    $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.DeviceCapability -match $AmdCompute}
                } 
                if ($Miner_Vendor -eq "NVIDIA") {
                    if ($_.NvCompute) {
                        $NvCompute = $_.NvCompute
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.Architecture -match $NvCompute}
                    }
                    if ($_.ExcludeNvCompute) {
                        $NvCompute = $_.ExcludeNvCompute
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.Architecture -notmatch $NvCompute}
                    }
                    #if ($_.MainAlgorithm -eq "qhash" -and $Miner_Device.OpenCL.Architecture -in @("Volta","Turing","Ampere") -and $Miner_Device.Model_Base -match "^CMP") {
                    #    $QhashParams = " --qhash-kernel 2"
                    #}
                } elseif ($Miner_Vendor -eq "AMD") {
                    if ($_.AmdCapability) {
                        $AmdCapability = $_.AmdCapability
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.DeviceCapability -match $AmdCapability}
                    }
                    if ($_.ExcludeAmdCapability) {
                        $AmdCapability = $_.ExcludeAmdCapability
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.DeviceCapability -notmatch $AmdCapability}
                    }
                }

			    if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols)) {
                    $Params = "$($WatchdogParams)$(if ($Pools.$Algorithm_Norm.ScratchPadUrl) {"--scratchpad-url $($Pools.$Algorithm_Norm.ScratchPadUrl) --scratchpad-file scratchpad-$($Pools.$Algorithm_Norm.CoinSymbol.ToLower()).bin "})$($_.Params)"
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
					    Arguments      = "--api-port `$mport -a $($Algorithm) -o stratum+tcp$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User -replace "^nexa:")$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -r 4 -R 5 --max-rejects 10 --multiple-instance --opencl-devices $($DeviceIDsAll) $($DeviceParams)$($QhashParams) --opencl-threads auto --gpu-temp-limit=95 $($Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					    API            = "Xmrig"
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
        }
    }
}
