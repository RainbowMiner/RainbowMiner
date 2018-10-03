using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

[hashtable]$Pool_Regions = @{
    "eu"   = "-eu1.nanopool.org"
    "us"   = "-us-east1.nanopool.org"
    "asia" = "-asia1.nanopool.org"
}

$Pools_Data = @()
$Pools_Data += [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash";        symbol = "ETC"; port = 19999; fee = 1; divisor = 1000000; ssl = $false; protocol = "stratum+tcp"};
$Pools_Data += [PSCustomObject]@{coin = "Ethereum";        algo = "Ethash";        symbol = "ETH"; port = 9999;  fee = 1; divisor = 1000000; ssl = $false; protocol = "stratum+tcp"};
$Pools_Data += [PSCustomObject]@{coin = "Zcash";           algo = "Equihash";      symbol = "ZEC"; port = 6666;  fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"};
$Pools_Data += [PSCustomObject]@{coin = "Monero";          algo = "CrypotnightV7"; symbol = "XMR"; port = 14444; fee = 1; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"};
$Pools_Data += [PSCustomObject]@{coin = "Electroneum";     algo = "Cryptonight";   symbol = "ETN"; port = 13333; fee = 2; divisor = 1;       ssl = $true;  protocol = "stratum+ssl"};

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync $("https://api.nanopool.org/v1/" + $_.symbol.ToLower() + "/approximated_earnings/1000") -cycletime ([Math]::Min(120,$Session.Config.Interval)) -tag $Name
            if ($Pool_Request.status -ne "OK") {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($_.symbol) has failed. "
            $ok = $false
        }

        if ($ok) {
            $Pool_ExpectedEarning = [double]($Pool_Request | Select-Object -ExpandProperty data | Select-Object -ExpandProperty day | Select-Object -ExpandProperty bitcoins) / $_.divisor / 1000    
            $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value $Pool_ExpectedEarning -Duration $StatSpan -ChangeDetection $true
        }
    }

    if ($ok) {
        foreach($Pool_Region in $Pool_Regions.Keys) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $_.symbol
                Currency      = $_.symbol
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $_.protocol
                Host          = "$($_.symbol.ToLower())$($Pool_Regions.$Pool_Region)"
                Port          = $_.port
                User          = "$($Wallets."$($_.symbol)")/$($Worker)"
                Pass          = "x"
                Region        = $Pool_Region
                SSL           = $_.ssl
                Updated       = $Stat.Updated
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
            }
        }
    }
}
