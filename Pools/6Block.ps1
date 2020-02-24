using module ..\Include.psm1

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

[hashtable]$Pool_RegionsTable = @{}
@("hk","us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "HNS";  port = 7701; fee = 2.0; region = @("hk","us")}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_Regions   = $_.region

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo
    $Pool_Request = [PSCustomObject]@{}

    $Pool_TSL  = 0

    $priceBTC = if ($Global:Rates.$Pool_Currency) {1/$Global:Rates.$Pool_Currency} else {0}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $WebRequest = Invoke-RestMethodAsync "https://6block.com/en" -tag $Name -timeout 15 -cycletime 120
            $WebParams = if ($WebRequest -match "}}\(([^\)]+)\)") {$Matches[1] -split ',' | Foreach-Object {$_  -replace '^"' -replace '"$'}} else {@()}
            foreach ($c in @("statPool","found24H","activeMiners")) {
                if ($WebRequest -match "$($c):(.+?)[,}]") {
                    $Pool_Request | Add-Member $c ($Matches[1] -replace '^"' -replace '"$') -Force
                    if ($Pool_Request.$c -match "^[a-zA-Z]$") {
                        $Base_Ord = if ($Pool_Request.$c -cmatch "^[a-z]$") {[int]('a'[0])} else {[int]('A'[0])-26}
                        $Pool_Request.$c = $WebParams[[int]($Pool_Request.$c[0]) - $Base_Ord]
                    }
                } else {
                    $ok = $false
                }
            } 
            $TimeStamp = Get-UnixTimestamp
            if ($WebRequest -match "blocks:[\s\r\n]*\[{(.+?)}") {
                if ($Matches[1] -match "timestamp:(\d+)") {
                    if ([int]$Matches[1] -lt $TimeStamp) {$Pool_TSL = $TimeStamp - [int]$Matches[1]}
                }
            }
            if ($WebRequest -match "([\d\.]+)[\s\r\n]*HNS/(\w+)") {
                $Pool_Request | Add-Member profit ([double]$Matches[1])
                $Pool_Request | Add-Member unit $Matches[2]
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
        if (-not $priceBTC) {
            try {
                $Ticker_Request = Invoke-RestMethodAsync "https://www.namebase.io/api/v0/ticker/price?symbol=HNSBTC" -tag $Name -timeout 15 -cycletime 120
                if ($Ticker_Request.price) {
                    $priceBTC = [double]$Ticker_Request.price
                }            
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }
    }

    if ($ok -and -not $InfoOnly) {
        $divisor  = ConvertFrom-Hash "1$($Pool_Request.unit)"
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($Pool_Request.profit*$priceBTC/$divisor) -Duration $StatSpan -HashRate ([int64]$Pool_Request.statPool) -BlockRate ([int]$Pool_Request.found24H) -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
        foreach ($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
				Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "handshake$(if ($Pool_Region -ne "hk") {"-$Pool_Region"}).6block.com"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $false
                WTM           = $true
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = [int]$Pool_Request.activeMiners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
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
        }
    }
}
