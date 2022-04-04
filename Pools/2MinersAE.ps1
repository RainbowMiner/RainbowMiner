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
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region_Default = "eu"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_HostStatus = [PSCustomObject]@{}

try {
    $Pool_HostStatus = Invoke-RestMethodAsync "https://status-api.2miners.com/" -tag $Name -retry 5 -retrywait 250 -cycletime 120
    if ($Pool_HostStatus.code -ne $null) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pools_Data = @(
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";   port = 1010; fee = 1.0; divisor = 1e18; currencies = @("BTC","ETC")}
    [PSCustomObject]@{rpc = "eth";   symbol = "ETH";   port = 2020; fee = 1.0; divisor = 1e18; currencies = @("BTC","NANO","ETH")}
)

$Pools_Data | ForEach-Object {

    $Pool_Currencies = $_.currencies | Where-Object {$Wallets.$_ -or $InfoOnly}

    if (-not $InfoOnly -and $Pool_Currencies.Count -gt 1) {
        if ($AECurrency -eq "" -or $AECurrency -notin $Pool_Currencies) {$AECurrency = $Pool_Currencies | Select-Object -First 1}
        $Pool_Currencies = $Pool_Currencies | Where-Object {$_ -eq $AECurrency}
    }

    if (-not $Pool_Currencies -and -not $InfoOnly) {
        return
    }

    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_Host = "$($_.rpc).2miners.com"
    $Pool_Fee = $_.fee
    $Pool_Divisor = $_.divisor
    $Pool_FixBigInt = $Pool_Divisor -ge 1e18
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}
    $Pool_SSL = $_.ssl

    $ok = ($Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)"} | Measure-Object).Count -gt 0
    if ($ok -and -not $InfoOnly) {
        $Pool_Blocks = [PSCustomObject]@{}

        try {
            $Pool_Blocks = Invoke-RestMethodAsync "https://$($Pool_Host)/api/blocks" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250 -fixbigint:$Pool_FixBigInt
            if ($Pool_Blocks.code -ne $null) {$ok=$false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Coin.Symbol) has failed. "
            return
        }

        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_Host)/api/stats" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
            if ($Pool_Request.code -ne $null -or $Pool_Request.nodes -eq $null -or -not $Pool_Request.nodes) {$ok=$false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Coin.Symbol) has failed. "
            return
        }

        $timestamp    = [int]($Pool_Request.now / 1000)
        $timestamp24h = $timestamp - 24*3600
            
        $blocks = @($Pool_Blocks.candidates | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.immature | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.matured | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) | Select-Object

        $blocks_measure = $blocks | Measure-Object timestamp -Minimum -Maximum
        $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
        $Pool_BLK       = [int]$(if ($avgTime) {86400/$avgTime})
        $Pool_TSL       = $timestamp - $Pool_Request.stats.lastBlockFound
        $reward         = $(if ($blocks) {($blocks | Where-Object {$_.reward -gt 0}| Measure-Object reward -Average).Average} else {0})/$Pool_Divisor
        $btcPrice       = if ($Global:Rates."$($Pool_Coin.Symbol)") {1/[double]$Global:Rates."$($Pool_Coin.Symbol)"} else {0}

        if ($_.cycles) {
            $addName         = $Pool_Algorithm_Norm -replace "[^\d]"
            $PBR  = (86400 / $_.cycles) * ($(if ($_.symbol -match "-PRI$") {$Pool_Request.nodes."primaryWeight$($addName)"} else {$Pool_Request.nodes.secondaryScale})/$Pool_Request.nodes.difficulty)
            $btcRewardLive   = $PBR * $reward * $btcPrice
            $Divisor         = 1
            $Hashrate        = $Pool_Request.hashrates.$addName
        } else {
            $btcRewardLive   = if ($Pool_Request.hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Pool_Request.hashrate} else {0}
            $addName         = ""
            $Divisor         = 1
            $Hashrate        = $Pool_Request.hashrate
        }
        $Stat = Set-Stat -Name "$($Name)_$($_.symbol)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok) {
        foreach($Pool_Currency in $Pool_Currencies) {
            [System.Collections.Generic.List[string]]$Pool_Hosts = @()
            $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.'
            $Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)"} | Select-Object host,port | Sort-Object -Descending:$($Pool_Coin.Symbol -eq "FIRO") {[int]$_.port} | Foreach-Object {
                $Pool_SSL_0 = $Pool_SSL -or ([int]$_.port -ge 10000)
                if (-not $Pool_Hosts.Contains("$($_.host)$($Pool_SSL_0)")) {
                    $Pool_Hosts.Add("$($_.host)$($Pool_SSL_0)")
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin.Name
                        CoinSymbol    = $Pool_Coin.Symbol
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.$StatAverageStable
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = if ($Pool_SSL_0) {"stratum+ssl"} else {"stratum+tcp"}
                        Host          = "$($_.host)"
                        Port          = [int]$_.port
                        User          = "$($Pool_Wallet).{workername:$Worker}"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable."$(if ($_.host -match "^(asia|us)-") {$Matches[1]} else {"eu"})"
                        SSL           = $Pool_SSL_0
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        DataWindow    = $DataWindow
                        Workers       = $Pool_Request.workersTotal
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_TSL
                        BLK           = $Stat.BlockRate_Average
                        EthMode       = $Pool_EthProxy
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Disabled      = $false
                        HasMinerExclusions = $false
                        Price_0       = 0.0
                        Price_Bias    = 0.0
                        Price_Unbias  = 0.0
                        Wallet        = $Pool_Wallet
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
        }
    }
}
