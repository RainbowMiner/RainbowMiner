﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/trexminer/T-Rex/releases"
$Port = "319{0:d2}"
$DevFee = 1.0
$Version = "0.19.14"
$DeviceCapability = "5.0"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Trex19\t-rex"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.19.14-trex/t-rex-0.19.14-linux-cuda11.1.tar.gz"
            Cuda   = "11.1"
        },
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.19.14-trex/t-rex-0.19.14-linux-cuda10.0.tar.gz"
            Cuda   = "10.0"
            IsGtx  = $true
        },
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.19.14-trex/t-rex-0.19.14-linux-cuda9.2.tar.gz"
            Cuda   = "9.2"
            IsGtx  = $true
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Trex19\t-rex.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.19.14-trex/t-rex-0.19.14-win-cuda11.1.zip"
            Cuda   = "11.1"
        },
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.19.14-trex/t-rex-0.19.14-win-cuda10.0.zip"
            Cuda   = "10.0"
            IsGtx  = $true
        },
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.19.14-trex/t-rex-0.19.14-win-cuda9.2.zip"
            Cuda   = "9.2"
            IsGtx  = $true
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "astralhash"; Params = ""} #GLTAstralHash (new with v0.8.6)
    [PSCustomObject]@{MainAlgorithm = "balloon"; Params = ""} #Balloon
    [PSCustomObject]@{MainAlgorithm = "bcd"; Params = ""} #Bcd
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "dedal"; Params = ""} #Dedal (re-added with v0.13.0)
    [PSCustomObject]@{MainAlgorithm = "geek"; Params = ""} #Geek (new with v0.7.5)
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""} #HMQ1725 (new with v0.6.4)
    [PSCustomObject]@{MainAlgorithm = "honeycomb"; Params = ""} #Honeycomb (new with v0.12.0)
    [PSCustomObject]@{MainAlgorithm = "hsr"; Params = ""} #HSR
    [PSCustomObject]@{MainAlgorithm = "jeonghash"; Params = ""} #GLTJeongHash  (new with v0.8.6)
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""; IsGtx = $true} #Lyra2z, fails to validate on CPU
    [PSCustomObject]@{MainAlgorithm = "megabtx"; Params = ""; IsGtx = $true} #MegaBTX (Bitcore) (new with v0.18.1)
    [PSCustomObject]@{MainAlgorithm = "padihash"; Params = ""} #GLTPadiHash  (new with v0.8.6)
    [PSCustomObject]@{MainAlgorithm = "pawelhash"; Params = ""} #GLTPawelHash  (new with v0.8.6)
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = ""} #Polytimos
    [PSCustomObject]@{MainAlgorithm = "renesis"; Params = ""} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sha256q"; Params = ""; IsGtx = $true} #SHA256q (Pyrite)
    [PSCustomObject]@{MainAlgorithm = "sha256t"; Params = ""; IsGtx = $true} #SHA256t
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r (fastest)
    [PSCustomObject]@{MainAlgorithm = "x16rv2"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rv2 (fastest)
    [PSCustomObject]@{MainAlgorithm = "x16rt"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt (Veil)
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""; FaultTolerance = 0.5} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} #X17
    [PSCustomObject]@{MainAlgorithm = "x21s"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X21s (broken in v0.8.6, fixed in v0.8.8)
    [PSCustomObject]@{MainAlgorithm = "x22i"; Params = ""} #X22i
    [PSCustomObject]@{MainAlgorithm = "x25x"; Params = ""; FaultTolerance = 0.5} #X25X
    [PSCustomObject]@{MainAlgorithm = "x33"; Params = ""} #X33 (new with v0.17.3)
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
        $IsGtx= $UriCuda[$i].IsGtx
    }
}

if (-not $Cuda) {return}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model -and (-not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)})

    if (-not $Device) {return}

    $Commands.ForEach({
        $First = $True
        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        
        $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

        #Zombie-mode since v0.18.3
        if ($_.DAG -and $Algorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
            $MinMemGB = $_.MinMemGB
        }

        $Miner_IsGtx = $_.IsGtx

        $Miner_Device = $Device.Where({($IsGtx -or -not $Miner_IsGtx -or $_.OpenCL.Architecture -notin @("Other","Pascal","Turing")) -and (Test-VRAM $_ $MinMemGB)})

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
            if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                if ($First) {
                    $Miner_Port   = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name   = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $False
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                $Pool_Protocol = if ($Algorithm_Norm_0 -in @("Octopus")) {
                                    $Pools.$Algorithm_Norm.Protocol
                                 } else {
                                    Switch($Pools.$Algorithm_Norm.EthMode) {
                                        "qtminer"       {"stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratumnh"  {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethlocalproxy" {"stratum+http"}
                                        default {$Pools.$Algorithm_Norm.Protocol}
                                    }
                                }
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-N 10 -r 5 --api-bind-http 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) -o $($Pool_Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Worker) {" -w $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"})$(if ($Pools.$Algorithm_Norm.SSL) {" --no-strict-ssl"})$(if (-not $Session.Config.ShowMinerWindow){" --no-color"}) --no-watchdog -b 0 $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					API            = "Trex"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = if ($_.DevFee) {$_.DevFee} else {$DevFee}
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    ExcludePoolName = $_.ExcludePoolName
				}
			}
		}
    })
}