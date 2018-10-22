using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-Zjazz\zjazz_cuda.exe"
$Port = "324{0:d2}"
$DevFee = 2.0

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/zjazz/zjazz_cuda_miner/releases/download/1.2/zjazz_cuda_win64_1.2.zip"
        Cuda = "9.1"
    }
)

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "bitcash"; CoinSymbol = "BITC";  Params = ""} #Cuckoo/Bitcash
    [PSCustomObject]@{MainAlgorithm = "merit";   CoinSymbol = "MERIT"; Params = ""} #Cuckoo/Merit
    [PSCustomObject]@{MainAlgorithm = "x22i";    CoinSymbol = "";      Params = ""} #X22i
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda[0].Uri
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
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' -d '

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($_.CoinSymbol -eq "" -or $_.CoinSymbol -eq $Pools.$Algorithm_Norm.CoinSymbol)) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -R 5 --hide-hashrate-per-gpu --disable-restart-on-gpu-error $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Ccminer"
                Port = $Miner_Port
                Uri = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
                DevFee = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}