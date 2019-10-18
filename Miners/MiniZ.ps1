using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=4767892.0"
$Port = "330{0:d2}"
$DevFee = 2.0
$Version = "1.5r"

if ($IsLinux) {
    $Path = ".\Bin\Equihash-MiniZ\miniZ"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.5r-miniz/miniZ_v1.5r_cuda10_linux-x64.tar.gz"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.5r-miniz/miniZ_v1.5r_linux-x64.tar.gz"
            Cuda = "8.0"
        }
    )
} else {
    $Path = ".\Bin\Equihash-MiniZ\miniZ.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.5r-miniz/miniZ_v1.5r_cuda10_win-x64.zip"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.5r-miniz/miniZ_v1.5r_win-x64.zip"
            Cuda = "8.0"
        }
    )
}

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash16x5";    MinMemGB = 1;                  Params = "--par=96,5";  ExtendInterval = 2; AutoPers = $true}  #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";    MinMemGB = 2;                  Params = "--par=144,5"; ExtendInterval = 2; AutoPers = $true} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x7";    MinMemGB = 2;                  Params = "--par=192,7"; ExtendInterval = 2; AutoPers = $true} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";   MinMemGB = 3;                  Params = "--par=125,4"; ExtendInterval = 3; AutoPers = $true} #Equihash 125,4,0 (ZelCash)
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5";   MinMemGB = 3; MinMemGbW10 = 4; Params = "--par=150,5"; ExtendInterval = 3; AutoPers = $true} #Equihash 150,5,0 (GRIMM)
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5x3"; MinMemGB = 3; MinMemGbW10 = 4; Params = "--par=beam";  ExtendInterval = 3; AutoPers = $false} #Equihash 150,5,3 (BEAM)
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";    MinMemGB = 4;                  Params = "--par=210,9"; ExtendInterval = 2; AutoPers = $true} #Equihash 210,9 (AION)
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

$Uri = ""
for($i=0;$i -le $UriCuda.Count -and -not $Uri;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri = $UriCuda[$i].Uri
        $Cuda= $UriCuda[$i].Cuda
    }
}
if (-not $Uri) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}        
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb - 0.25gb)}
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                $PersCoin = Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto"
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--telemetry $($Miner_Port) -cd $($DeviceIDsAll) --server $(if ($Pools.$Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"}) --gpu-line --nonvml --extra --latency$(if (-not $Session.Config.ShowMinerWindow) {" --nocolor"})$(if ($Pools.$Algorithm_Norm.Name -eq "MiningRigRentals" -and $PersCoin -ne "auto") {" --smart-pers"}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
					API            = "MiniZ"
					Port           = $Miner_Port
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					Uri            = $Uri
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}