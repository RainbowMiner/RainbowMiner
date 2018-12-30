using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\Equihash-MiniZ\miner.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=4767892.0"
$Port = "330{0:d2}"
$DevFee = 2.0

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0i-miniz/miniZ_v1.0i_win-x64.zip"
        Cuda = "9.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0i-miniz/miniZ_v1.0i_cuda8_win-x64.zip"
        Cuda = "8.0"
    }
)

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash1445"; MinMemGB = 2; Params = "--par=144,5"} #Equihash 144,5
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

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB        
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb)}
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--telemetry 0.0.0.0:$($Miner_Port) --cuda-devices $($DeviceIDsAll) --server $(if ($Pools.$Algorithm_Norm.SSL) {"ssl://"})$($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) --pers $(Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto") --gpu-line --extra $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "MiniZ"
                Port = $Miner_Port
                DevFee = $DevFee
                Uri = $Uri
                ExtendInterval = 2
                ManualUri = $ManualUri
            }
        }
    }
}