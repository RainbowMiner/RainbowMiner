using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/RainbowMiner/xmr-stak/releases/download/v2.4.7-nodevfee/xmr-stak-2.4.7-nodevfee.zip"
$Port = "309{0:d2}"
$DevFee = 0.0

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "cryptonight";            Threads = 1; MinMemGb = 2; Params = ""} #CryptoNight
    [PSCustomObject]@{MainAlgorithm = "cryptonight_bittube2";    Threads = 1; MinMemGb = 4; Params = ""} # CryptoNightBittube2
    [PSCustomObject]@{MainAlgorithm = "cryptonight_haven";       Threads = 1; MinMemGb = 4; Params = ""} # CryptoNightHaven
    [PSCustomObject]@{MainAlgorithm = "cryptonight_heavy";       Threads = 1; MinMemGb = 4; Params = ""} # CryptoNightHeavy
    [PSCustomObject]@{MainAlgorithm = "cryptonight_lite";        Threads = 1; MinMemGb = 1; Params = ""} # CryptoNightLite
    [PSCustomObject]@{MainAlgorithm = "cryptonight_lite_v7";     Threads = 1; MinMemGb = 1; Params = ""} # CryptoNightLiteV7
    [PSCustomObject]@{MainAlgorithm = "cryptonight_lite_v7_xor"; Threads = 1; MinMemGb = 1; Params = ""} # CryptoNightLiteV7Xor
    [PSCustomObject]@{MainAlgorithm = "cryptonight_masari";      Threads = 1; MinMemGb = 2; Params = ""} # CryptoNightMasari
    [PSCustomObject]@{MainAlgorithm = "cryptonight_v7";          Threads = 1; MinMemGb = 2; Params = ""} #CryptoNightV7
    [PSCustomObject]@{MainAlgorithm = "cryptonight_v7_stellite"; Threads = 1; MinMemGb = 2; Params = ""} #CryptoNightV7Stellite
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
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

if (-not $Devices.NVIDIA -and -not $Devices.AMD -and -not $Devices.CPU -and -not $Config.InfoOnly) {return} # No GPU present in system

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
#    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
#    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
#    $Miner_Vendor = $_.Vendor
#    $Miner_Model = $_.Model
#    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

#    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index

@($Devices.FullComboModels.PSObject.Properties.Name) | Foreach-Object {
    $Miner_Vendor = $_  
    @($Devices.$Miner_Vendor) | Where-Object {$_.Model -eq $Devices.FullComboModels.$Miner_Vendor} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Devices.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model
            
        switch($Miner_Vendor) {
            "NVIDIA" {$Miner_Deviceparams = "--noUAC --noAMD --noCPU"}
            "AMD" {$Miner_Deviceparams = "--noUAC --noCPU --noNVIDIA"}
            Default {$Miner_Deviceparams = "--noUAC --noAMD --noNVIDIA"}
        }

        $Commands | ForEach-Object {
            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
            $MinMemGb = $_.MinMemGb
            $Params = $_.Params
        
            $Miner_Device = @($Device | Where-Object {$_.Model -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)})

            if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
                $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

                if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                    $Arguments = [PSCustomObject]@{
                        Params = "-i $($Miner_Port) $($Miner_Deviceparams) $($_.Params)".Trim()
                        Config = [PSCustomObject]@{
                            pool_list       = @([PSCustomObject]@{
                                    pool_address    = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                                    wallet_address  = "$($Pools.$Algorithm_Norm.User)"
                                    pool_password   = "$($Pools.$Algorithm_Norm.Pass)"
                                    use_nicehash    = $true
                                    use_tls         = $Pools.$Algorithm_Norm.SSL
                                    tls_fingerprint = ""
                                    pool_weight     = 1
                                    rig_id = "$($Config.Pools."$($Pools.$Algorithm_Norm.Name)".Worker)"
                                }
                            )
                            currency        = if ($Pools.$Algorithm_Norm.Info) {"$($Pools.$Algorithm_Norm.Info -replace '^monero$', 'monero7' -replace '^aeon$', 'aeon7')"} else {$_.MainAlgorithm}
                            call_timeout    = 10
                            retry_time      = 10
                            giveup_limit    = 0
                            verbose_level   = 3
                            print_motd      = $true
                            h_print_time    = 60
                            aes_override    = $null
                            use_slow_memory = "warn"
                            tls_secure_algo = $true
                            daemon_mode     = $false
                            flush_stdout    = $false
                            output_file     = ""
                            httpd_port      = $Miner_Port
                            http_login      = ""
                            http_pass       = ""
                            prefer_ipv4     = $true
                        }
                    }

                    [PSCustomObject]@{
                        Name      = $Miner_Name
                        DeviceName= $Miner_Device.Name
                        DeviceModel=$Miner_Model
                        Path      = $Path
                        Arguments = $Arguments
                        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                        API       = "Fireice"
                        Port      = $Miner_Port
                        Uri       = $Uri
                        DevFee    = $DevFee
                        ManualUri = $ManualUri
                    }
                }
            }
        }
    }
}