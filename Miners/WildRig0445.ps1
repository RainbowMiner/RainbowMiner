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
$Port = "420{0:d2}"
$DevFee = 0.00
$Cuda = "11.0"
$Version = "0.44.5"

if ($IsLinux) {
    $Path = ".\Bin\GPU-WildRig0445\wildrig-multi"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.44.5-wildrigmulti/wildrig-multi-linux-0.44.5.tar.xz"
} else {
    $Path = ".\Bin\GPU-WildRig0445\wildrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.44.5-wildrigmulti/wildrig-multi-windows-0.44.5.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "heavyhash";                 Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 2; FaultTolerance = 0.4} #Heavyhash/OBTC
    #[PSCustomObject]@{MainAlgorithm = "phihash";      DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; MinMemGB = 4} #PhiHash/PHI
    [PSCustomObject]@{MainAlgorithm = "progpow-veil"; DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.75} #ProgPowVeil
    [PSCustomObject]@{MainAlgorithm = "vprogpow";     DAG = $true; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; ExcludePoolName = "Beepool"} #vProgPoW
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
                    if ($_.MainAlgorithm -eq "qhash" -and $Miner_Device.OpenCL.Architecture -in @("Volta","Turing","Ampere") -and $Miner_Device.Model_Base -match "^CMP") {
                        $QhashParams = " --qhash-kernel 2"
                    }
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
