using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/fireice-uk/xmr-stak/releases/download/2.4.4/xmr-stak-win64.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3335

$Commands = [PSCustomObject]@{
    #"cryptonight" = "" #CryptoNight
    "cryptonight_heavy" = "" # CryptoNight-Heavy
    "cryptonight_lite" = "" # CryptoNight-Lite
    "cryptonight_V7" = "" #CryptoNightV7
}

$Platforms = @()

if ($Devices.NVIDIA -and -not $Config.InfoOnly) {
    $Platforms += [PSCustomObject]@{
        Devices = "Nvidia"
        DeviceIDs = Get-GPUIDs $Devices.NVIDIA
        Arguments = "--noUAC --noAMD --noCPU"
        Port = 3335
    }
}

if ($Devices.AMD -and -not $Config.InfoOnly) {
    $Platforms += [PSCustomObject]@{
        Devices = "Amd"
        DeviceIDs = Get-GPUIDs $Devices.AMD
        Arguments = "--noUAC --noCPU --noNVIDIA"
        Port = 3336
    }
}

if ($Devices.CPU -and -not $Config.InfoOnly) {
    $Platforms += [PSCustomObject]@{
        Devices = "Cpu"
        Arguments = "--noUAC --noAMD --noNVIDIA"
        Port = 3334
    }
}

$Platforms | Foreach-Object {
    $Platform = $_

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

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
                httpd_port      = $Platform.Port
                http_login      = ""
                http_pass       = ""
                prefer_ipv4     = $true
            } | ConvertTo-Json -Depth 10
        ) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_$($Platform.Devices).txt" -Force -ErrorAction SilentlyContinue

        $Miner_Name = "$($Name)$($Platform.Devices)"

        [PSCustomObject]@{
            Name      = $Miner_Name
            DeviceName= $Devices.($Platform.Devices).Name
            Path      = $Path
            Arguments = "-C $($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_$($Platform.Devices).txt $($Platform.Arguments) -i $($Platform.Port)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API       = "XMRig"
            Port      = $Platform.Port
            URI       = $Uri
            DevFee    = 2.0
        }
    }
}