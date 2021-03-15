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

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://hiveon.net/api/v1/stats/pool" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Request.cryptoCurrencies | Where-Object {$Wallets."$($_.name)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency  = $_.name
    $Pool_Coin      = Get-Coin $Pool_Currency

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    if (-not $InfoOnly) {
        $Pool_Profit   = 0
        $Pool_Workers  = $null
        $Pool_BLK      = [int]$Pool_Request.stats.$Pool_Currency.blocksFound
        $Pool_Reward   = [decimal]$Pool_Request.stats.$Pool_Currency.expectedReward24H
        $Pool_Hashrate = [decimal]$Pool_Request.stats.$Pool_Currency.hashrate
        $Pool_Divisor  = [decimal]$_.profitPerPower

        $Pool_TSL      = if ($Pool_BLK) {43200/$Pool_BLK} else {0}

        if ($Pool_Currency -eq "ETH") {
            $Pool_Request_Eth = [PSCustomObject]@{}
            try {
                $Pool_Request_Eth = Invoke-RestMethodAsync "https://hiveon.net/api/v1/pool/stats"  -tag $Name -cycletime 120
                if ($Pool_Request_Eth.stats) {
                    $Pool_Workers  = [int]($Pool_Request_Eth.stats | Select-Object -First 1).workers
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Pool API ($Name/legacy) has failed. "
            }
        }

        $Pool_Profit = if ($Pool_Divisor -and $Global:Rates.$Pool_Currency) {$Pool_Reward / $Pool_Divisor / $Global:Rates.$Pool_Currency} else {0}

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Profit -Duration $StatSpan -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($Pool_Hashrate -or $InfoOnly) {
        foreach($Pool_Server in $_.servers) {
            $Pool_SSL = $false
            foreach($Pool_Port in @("ports","ssl_ports")) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
		            Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                    Host          = $Pool_Server.host
                    Port          = $Pool_Server.$Pool_Port | Select-Object -First 1
                    User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                    Pass          = "x"
                    Region        = Get-Region $Pool_Server.region
                    SSL           = $Pool_SSL
                    Updated       = (Get-Date).ToUniversalTime()
                    PoolFee       = 0
                    Workers       = $Pool_Workers
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    WTM           = -not $Pool_Profit
                    EthMode       = "ethproxy"
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Disabled      = $false
                    HasMinerExclusions = $false
                    Price_Bias    = 0.0
                    Price_Unbias  = 0.0
                    Wallet        = $Wallets.$Pool_Currency
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
                $Pool_SSL = $true
            }
        }
    }
}
