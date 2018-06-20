using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.4.5-fireice/xmr-stak-2.4.5.zip"
$Port = "308{0:d2}"

$Commands = [PSCustomObject]@{
    #"cryptonight" = "" #CryptoNight
    "cryptonight_heavy" = "" # CryptoNight-Heavy
    "cryptonight_lite" = "" # CryptoNight-Lite
    "cryptonight_V7" = "" #CryptoNightV7
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Devices.NVIDIA -and -not $Devices.AMD -and -not $Devices.CPU -and -not $Config.InfoOnly) {return} # No GPU present in system

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
#    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
#    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
#    $Miner_Vendor = Get-DeviceVendor $_
#    $Miner_Model = $_.Model
#    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

#    $DeviceIDsAll = Get-GPUIDs $Miner_Device

@($Devices.FullComboModels.PSObject.Properties.Name) | Foreach-Object {
    $Miner_Vendor = $_    
    @($Devices.$Miner_Vendor) | Where-Object {$_.Model -eq $Devices.FullComboModels.$Miner_Vendor} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)        
        $Miner_Model = $_.Model
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            
        switch($Miner_Vendor) {
            "NVIDIA" {$Miner_Deviceparams = "--noUAC --noAMD --noCPU"}
            "AMD" {$Miner_Deviceparams = "--noUAC --noCPU --noNVIDIA"}
            Default {$Miner_Deviceparams = "--noUAC --noAMD --noNVIDIA"}
        }

        $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {Get-Member -inputobject $Pools -name (Get-Algorithm $_) -Membertype Properties} | ForEach-Object {

            $Algorithm_Norm = Get-Algorithm $_
            $Miner_ConfigFileName = "$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_$(@($Miner_Device.Name | Sort-Object) -join '-').txt"

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
                    currency        = if ($Pools.$Algorithm_Norm.Info) {"$($Pools.$Algorithm_Norm.Info -replace '^monero$', 'monero7' -replace '^aeon$', 'aeon7')"} else {"$_"}
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
                Arguments = "-C $($Miner_ConfigFileName) $($Miner_Deviceparams) -i $($Miner_Port)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API       = "XMRig"
                Port      = $Miner_Port
                URI       = $Uri
                DevFee    = 0.0
            }
        }
    }
}