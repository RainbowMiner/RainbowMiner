using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}
@("asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "CFX";  port = @(9555,9556); fee = 2.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "ETH";  port = @(9530);      fee = 1.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "ETC";  port = @(9518);      fee = 1.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "AE";   port = @(9505);      fee = 1.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "SERO"; port = @(9515);      fee = 2.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "BEAM"; port = @(9507);      fee = 2.0; fee_pplns = 1.0}
    #[PSCustomObject]@{symbol = "GRIN29"; port = @(9510);    fee = 2.0}
    #[PSCustomObject]@{symbol = "GRIN31"; port = @(9510);    fee = 2.0}
    #[PSCustomObject]@{symbol = "GRIN32"; port = @(9510);    fee = 2.0}
    [PSCustomObject]@{symbol = "RVN";  port = @(9531);      fee = 2.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "PGN";  port = @(9560);      fee = 2.0; fee_pplns = 1.0}
    [PSCustomObject]@{symbol = "MOAC"; port = @(9540);      fee = 1.0; fee_pplns = 1.0}
)

$Pool_Request = [PSCustomObject]@{}
$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.beepool.org/pool_status" -tag $Name -cycletime 120 -timeout 20
    $ok = "$($Pool_Request.code)" -eq "0"
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$TZ_China_Standard_Time = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object {$_.Id -match "Shanghai" -or $_.Id -match "^China" -or $_.StandardName -match "^China"} | Select-Object -First 1

$Pools_Data | Where-Object {$Pool_Currency = "$($_.symbol -replace "\d+$")";$Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {

    if (-not ($Pool_Data = $Pool_Request.data.data | Where-Object {$_.coin -eq $Pool_Currency})) {return}

    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_RpcPath   = $Pool_Data.coin
    $Pool_Fee       = $_.fee
    $Pool_Ports     = $_.port
    $Pool_Wallet    = "$($Wallets.$Pool_Currency)"
    $Pool_PP        = ""

    if ($Pool_Wallet -match "@(pps|pplns)$") {        
        if ($Matches[1] -ne "pplns" -or $_.fee_pplns -ne $null) {
            $Pool_PP = $Matches[1]
            if ($Matches[1] -eq "pplns") {$Pool_Fee = $_.fee_pplns}
        }
        $Pool_Wallet = $Pool_Wallet -replace "@(pps|pplns)$"
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    if (-not $InfoOnly) {
        $Pool_TSL = $null
        if ($TZ_China_Standard_Time) {
            $Pool_Blocks = [PSCustomObject]@{}
            try {
                $Pool_Blocks = Invoke-RestMethodAsync "https://www.beepool.org/detail/get_blocks" -tag $Name -cycletime 120 -body @{coin=$Pool_Data.coin} -timeout 20
                if ("$($Pool_Blocks.code)" -eq "0" -and ($Pool_Blocks.data.blocks | Measure-Object).Count) {
                    $Pool_TSL = ((Get-Date).ToUniversalTime() - [System.TimeZoneInfo]::ConvertTimeToUtc("$((Get-Date).Year)-$(($Pool_Blocks.data.blocks | Select-Object -First 1).time)", $TZ_China_Standard_Time)).TotalSeconds
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }

        $Pool_Rate = 0
        if ($Pool_PP -and $Pool_Data."$($Pool_PP)_value" -and $Pool_Currency -ne "GRIN") {
            $Divisor  = ConvertFrom-Hash "1$($Pool_Data."$($Pool_PP)_unit".Substring(0,1))"
            $Pool_Rate = if ($Global:Rates.$Pool_Currency) {$Pool_Data."$($Pool_PP)_value" / $Global:Rates.$Pool_Currency / $Divisor} else {0}
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Rate -Duration $StatSpan -HashRate (ConvertFrom-Hash $Pool_Data.poolhash) -BlockRate ([int]$Pool_Blocks.data.last_24_total) -ChangeDetection (-not $Pool_Rate) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_Worker = [int]$Pool_Data.pool_worker
    if ($Stat.HashRate_Live -gt 0 -and -not $Pool_Data.pool_worker) {$Pool_Worker = 5}

    $Pool_SSL = $false
    foreach($Pool_Port in $Pool_Ports) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = "$($Pool_Data.coin)-pool.beepool.org"
            Port          = $Pool_Port
            User          = "$($Pool_Wallet)$(if ($Pool_Currency -eq "GRIN") {"/"} else {"."}){workername:$Worker}$(if ($Pool_PP) {"@$Pool_PP"})"
            Pass          = "x"
            Region        = $Pool_RegionsTable.$Pool_Region_Default
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            DataWindow    = $DataWindow
            Workers       = $Pool_Worker
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $Pool_TSL
            EthMode       = if ($Session.RegexAlgoHasEthproxy.Matches($Pool_Algorithm_Norm)) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}
            WTM           = -not $Pool_Rate
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Pool_Wallet
            Worker        = "{workername:$Worker}$(if ($Pool_PP) {"@$Pool_PP"})"
            Email         = $Email
        }
        $Pool_SSL = $true
    }
}
