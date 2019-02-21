using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\GRIN-GrinPro\GrinProMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.1-grinprominer/GrinPro_1_1.zip"
$ManualURI = "https://grinpro.io"
$Port = "335{0:d2}"
$DevFee = 2.0
$Cuda = "10.0"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cuckaroo29"; MinMemGb = 4; Params = ""; DevFee = 2.0; ExtendInterval = 3; FaultTolerance = 0.3; Penalty = 0; Vendor = @("AMD"); NoCPUMining = $true} #GRIN/Cuckaroo29
    #[PSCustomObject]@{MainAlgorithm = "cuckaroo29"; MinMemGb = 8; Params = ""; DevFee = 2.0; ExtendInterval = 2; FaultTolerance = 0.3; Penalty = 0; Vendor = @("NVIDIA"); NoCPUMining = $true} #GRIN/Cuckaroo29
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $MinMemGb = $_.MinMemGb
            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)}

            if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and $Pools.$MainAlgorithm_Norm.Name -notmatch "nicehash") {
                $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
                
                $Arguments = [PSCustomObject]@{
                    Params = "api-port=$($Miner_Port) $($_.Params)".Trim()
                    Config = [PSCustomObject]@{
                        Host = $Pools.$MainAlgorithm_Norm.Host
                        Port = $Pool_Port
                        SSL  = $Pools.$MainAlgorithm_Norm.SSL
                        User = $Pools.$MainAlgorithm_Norm.User
                        Pass = $Pools.$MainAlgorithm_Norm.Pass
                    }
                    Device = @($Miner_Device | Foreach-Object {[PSCustomObject]@{Name=$_.Model_Name;Vendor=$_.Vendor;Index=$_.Type_Vendor_Index;PlatformId=$_.PlatformId}})
                }

                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    #Arguments = "ignore-config=true $($DeviceIDsAll) api-port=$($Miner_Port) stratum-address=$($Pools.$MainAlgorithm_Norm.Host) stratum-port=$($Pools.$MainAlgorithm_Norm.Port) stratum-login=$($Pools.$MainAlgorithm_Norm.User) $(if ($Pools.$MainAlgorithm_Norm.Pass) {"stratum-password=$($Pools.$MainAlgorithm_Norm.Pass)"}) $($_.Params)"
                    Arguments = $Arguments
                    HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $Session.Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
                    API = "GrinPro"
                    Port = $Miner_Port
                    Uri = $Uri
                    DevFee = $_.DevFee
                    FaultTolerance = $_.FaultTolerance
                    ExtendInterval = $_.ExtendInterval
                    ManualUri = $ManualUri
                    StopCommand = "Sleep 15; Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {`$_.ExecutablePath -like `"$([IO.Path]::GetFullPath($Path) | Split-Path)\*`"} | Select-Object ProcessId,ProcessName | Foreach-Object {Stop-Process -Id `$_.ProcessId -Force -ErrorAction Ignore}"
                    NoCPUMining = $_.NoCPUMining
                    DotNetRuntime = "2.0"
                }
            }
        }
    }
}