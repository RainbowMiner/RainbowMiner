using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "419{0:d2}"
$DevFee = 1.0
$Cuda = "8.0"
$Version = "0.34.0"

if ($IsLinux) {
    $Path = ".\Bin\GPU-WildRig0340\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.34.0-wildrigmulti/wildrig-multi-linux-0.34.0.tar.xz"
} else {
    $Path = ".\Bin\GPU-WildRig0340\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.34.0-wildrigmulti/wildrig-multi-windows-0.34.0.7z"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "0x10";                      Vendor = @("AMD","NVIDIA"); Params = ""; ExtendInterval = 2} #0x10/CHOX
    [PSCustomObject]@{MainAlgorithm = "exosis";                    Vendor = @("AMD");          Params = ""} #Exosis
    [PSCustomObject]@{MainAlgorithm = "geek";                      Vendor = @("AMD");          Params = ""} #Geek
    #[PSCustomObject]@{MainAlgorithm = "honeycomb";                 Vendor = @("AMD");          Params = ""} #Honeycomb broken since v0.17.6
    [PSCustomObject]@{MainAlgorithm = "megamec";                   Vendor = @("AMD","NVIDIA"); Params = ""} #, new in v0.26.0
    [PSCustomObject]@{MainAlgorithm = "mtp";                       Vendor = @("AMD");          Params = ""} #MTP, new in v0.20.0 beta
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr";                   Vendor = @("AMD");          Params = ""} #MTPTcr, new in v0.20.0 beta, --split-job 4
    [PSCustomObject]@{MainAlgorithm = "renesis";                   Vendor = @("AMD");          Params = ""} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sonoa";                     Vendor = @("AMD");          Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "wildkeccak";                Vendor = @("AMD");          Params = ""; ExtendInterval = 3; DevFee = 2.0} #Wildkeccak
    [PSCustomObject]@{MainAlgorithm = "x17r";                      Vendor = @("AMD");          Params = "--protocol ufo2"; DevFee = 2.0} #X17r
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

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
                if (-not $Pools.$Algorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
                $Miner_Device = $Device.Where({Test-VRAM $_ $MinMemGB})
                $Params = "$($WatchdogParams)$(if ($Pools.$Algorithm_Norm.ScratchPadUrl) {"--scratchpad-url $($Pools.$Algorithm_Norm.ScratchPadUrl) --scratchpad-file scratchpad-$($Pools.$Algorithm_Norm.CoinSymbol.ToLower()).bin "})$($_.Params)"

			    if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols)) {
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
					    Arguments      = "--api-port `$mport -a $($Algorithm) -o stratum+tcp$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -r 4 -R 5 --max-rejects 10 --donate-level 1 --multiple-instance --opencl-devices $($DeviceIDsAll) $($DeviceParams) --opencl-threads auto --opencl-launch auto --gpu-temp-limit=95 $($Params)"
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