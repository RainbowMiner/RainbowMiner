using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.4.7-fireice/xmr-stak-win64.zip"
$Port = "308{0:d2}"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = ""} #CryptoNight
    [PSCustomObject]@{MainAlgorithm = "cryptonight_bittube2"; Params = ""} # CryptoNightBittube2
    [PSCustomObject]@{MainAlgorithm = "cryptonight_haven"; Params = ""} # CryptoNightHaven
    [PSCustomObject]@{MainAlgorithm = "cryptonight_heavy"; Params = ""} # CryptoNightHeavy
    [PSCustomObject]@{MainAlgorithm = "cryptonight_lite"; Params = ""} # CryptoNightLite
    [PSCustomObject]@{MainAlgorithm = "cryptonight_lite_v7"; Params = ""} # CryptoNightLiteV7
    [PSCustomObject]@{MainAlgorithm = "cryptonight_lite_v7_xor"; Params = ""} # CryptoNightLiteV7Xor
    [PSCustomObject]@{MainAlgorithm = "cryptonight_masari"; Params = ""} # CryptoNightMasari
    #[PSCustomObject]@{MainAlgorithm = "cryptonight_v7"; Params = ""} #CryptoNightV7
    [PSCustomObject]@{MainAlgorithm = "cryptonight_v7_stellite"; Params = ""} #CryptoNightV7Stellite
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Devices.NVIDIA -and -not $Devices.AMD -and -not $Devices.CPU -and -not $Config.InfoOnly) {return} # No GPU present in system

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
#    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
#    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
#    $Miner_Vendor = Get-DeviceVendor $_
#    $Miner_Model = $_.Model
#    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

#    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index

@($Devices.FullComboModels.PSObject.Properties.Name) | Foreach-Object {
    $Miner_Vendor = $_  
    @($Devices.$Miner_Vendor) | Where-Object {$_.Model -eq $Devices.FullComboModels.$Miner_Vendor} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Device = $Devices.$Miner_Vendor | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)        
        $Miner_Model = $_.Model
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            
        switch($Miner_Vendor) {
            "NVIDIA" {$Miner_Deviceparams = "--noUAC --noAMD --noCPU"}
            "AMD" {$Miner_Deviceparams = "--noUAC --noCPU --noNVIDIA"}
            Default {$Miner_Deviceparams = "--noUAC --noAMD --noNVIDIA"}
        }

        $Commands | ForEach-Object {

            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

            if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                $Miner_ConfigFileName = "$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_$(if ($Pools.$Algorithm_Norm.SSL){"ssl_"})$($Miner_Port).txt"

                ([PSCustomObject]@{
                        pool_list       = @([PSCustomObject]@{
                                pool_address    = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                                wallet_address  = "$($Pools.$Algorithm_Norm.User)"
                                pool_password   = "$($Pools.$Algorithm_Norm.Pass)"
                                use_nicehash    = $true
                                use_tls         = $Pools.$Algorithm_Norm.SSL
                                tls_fingerprint = ""
                                pool_weight     = 1
                                rig_id = ""
                            }
                        )
                        currency        = if ($Pools.$Algorithm_Norm.Info) {"$($Pools.$Algorithm_Norm.Info -replace '^monero$', 'monero7' -replace '^aeon$', 'aeon7')"} else {"$($_.MainAlgorithm)"}
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
                    } | ConvertTo-Json -Depth 10
                ) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Miner_ConfigFileName)" -Force -ErrorAction SilentlyContinue

                [PSCustomObject]@{
                    Name      = $Miner_Name
                    DeviceName= $Miner_Device.Name
                    DeviceModel=$Miner_Model
                    Path      = $Path
                    Arguments = "-C $($Miner_ConfigFileName) $($Miner_Deviceparams) -i $($Miner_Port) $($_.Params)"
                    HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API       = "XMRig"
                    Port      = $Miner_Port
                    URI       = $Uri
                    DevFee    = 0.0
                    ManualUri = $ManualUri
                }
            }
        }
    }
}