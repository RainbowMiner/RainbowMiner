using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [alias("UserName")]
    [String]$User,
    [String]$API_Key,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ARRR";    port = 700; fee = 5.0; rpc = "arrr"}
    [PSCustomObject]@{symbol = "DASH";    port = 700; fee = 3.0; rpc = "dash"}
    [PSCustomObject]@{symbol = "SC";      port = 700; fee = 3.0; rpc = "sc"}
    [PSCustomObject]@{symbol = "ZEC";     port = 700; fee = 3.0; rpc = "zec"}
    [PSCustomObject]@{symbol = "ZEN";     port = 700; fee = 3.0; rpc = "zen"}
)

if (-not $InfoOnly -and -not $API_Key) {
    Write-Log -Level Warn "$($Name): Please set an API_Key in pools.config.txt (on luxor.tech, sign in, then click `"API Keys`" and create)"
}

$Pools_Data | Where-Object {$Pool_Currency = $_.symbol -replace "(29|31)$";$User -or $Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc

    $Pool_Algorithm_Norm = $Pool_Coin.algo

    $Pool_Hashrate_Request = [PSCustomObject]@{}
    $Pool_Request_Blocks = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        $Pool_Hashrate = $null
        if ($API_Key) {
            try {
                $Pool_Hashrate_Request = Invoke-RestMethodAsync "https://api.beta.luxor.tech/graphql" -tag $Name -timeout 15 -cycletime 120 -headers @{'x-lux-api-key'=$API_Key} -body @{query = "query getPoolHashrate { getPoolHashrate(mpn: $($Pool_Currency), orgSlug: `"luxor`") }"}
                $Pool_Hashrate = $Pool_Hashrate_Request.data.getPoolHashrate
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "Pool API ($Name) for $Pool_Currency has failed. "
            }
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Hashrate -ChangeDetection $false -Quiet
        if ($Pool_Hashrate -ne $null -and -not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    $Pool_Wallet = if ($Wallets.$Pool_Currency) {$Wallets.$Pool_Currency} else {$User}

    foreach ($Pool_Region in $Pool_Regions) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+tcp"
            Host          = "$($Pool_RpcPath).global.luxor.tech"
            Port          = $Pool_Port
            User          = "$($Pool_Wallet).{workername:$Worker}"
            Pass          = "123"
            Region        = $Pool_RegionsTable[$Pool_Region]
            SSL           = $false
            Updated       = $Stat.Updated
            WTM           = $true
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Request.totalMiners
            Hashrate      = $Pool_Hashrate
            TSL           = $null
            BLK           = $null
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
