using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://pool.kryptex.com/api/v1/rates" -tag $Name -cycletime 120 -retry 5 -retrywait 250
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request.crypto) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","ru","sg","us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_NotMineable = @("BLOCX","BTC","DGB","DOGE","NIR","PYI","SDR","UBQ")

$Pool_Request.crypto.PSObject.Properties.Name | Where-Object {$_ -notin $Pool_NotMineable -and ($Wallets.$_ -or $InfoOnly)} | Foreach-Object {
    if ($_ -eq "XTM") {
        [PSCustomObject]@{symbol=$_; algo="Cuckaroo29"; rpc="xtm-c29"}
        [PSCustomObject]@{symbol=$_; algo="RandomX"; rpc="xtm-rx"}
        [PSCustomObject]@{symbol=$_; algo="SHA3x"; rpc="xtm-sha3x"}
    } else {
        [PSCustomObject]@{symbol=$_; algo=$null; rpc=$_.ToLower()}
    }
} | ForEach-Object {
    
    if ($Pool_Coin = Get-Coin $_.symbol -Algorithm $_.algo) {
        $Pool_Currency = $Pool_Coin.Symbol
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
    } else {
        Write-Log -Level Warn "$($Name): $($_.symbol) not found in CoinsDB"
        return
    }

    $Pool_Rpc    = $_.rpc
    $Pool_Wallet = "solo:$($Wallets.$Pool_Currency -replace "^solo:")"

    $PoolCoin_Request = [PSCustomObject]@{}
    $Network_Request  = [PSCustomObject]@{}

    try {
        $PoolCoin_Request = Invoke-RestMethodAsync "https://pool.kryptex.com/$($Pool_Rpc)/api/v1/pool/stats" -tag $Name -cycletime 120 -retry 5 -retrywait 250 -delay 200
    }
    catch {
        Write-Log -Level Warn "Pool coin API ($Name) for $($Pool_Coin.Symbol) has failed. "
        return
    }

    if ($PoolCoin_Request.modes -notcontains "solo") { return }

    $Pool_PoolFee = [Double]$PoolCoin_Request.commission.SOLO * 100

    if (-not $InfoOnly) {
        try {
            $Network_Request  = Invoke-RestMethodAsync "https://pool.kryptex.com/api/v1/net/stats/$($Pool_Rpc)" -tag $Name -cycletime 120 -retry 5 -retrywait 250 -delay 200
        }
        catch {
            Write-Log -Level Info "Network coin API ($Name) for $($Pool_Coin.Symbol) has failed. "
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty ([decimal]($Network_Request.day | Select-Object -last 1).net_difficulty) -Quiet
    }


    foreach($Pool_Region in $Pool_Regions) {
        foreach($ssl in @("","ssl_")) {
            foreach($url in $PoolCoin_Request.servers."$($ssl)urls") {
                if ($url -match "^(.+?-$($Pool_Region).+?):(\d+)$") {
                    $Pool_Host = $Matches[1]
                    $Pool_Port = $Matches[2]
                    $Pool_SSL  = $ssl -ne ""

                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin.Name
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = 0
                        StablePrice   = 0
                        MarginOfError = 0
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = $Pool_Host
                        Port          = $Pool_Port
                        User          = "$($Pool_Wallet)/{workername:$Worker}"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $Pool_SSL
                        Updated       = (Get-Date).ToUniversalTime()
                        PoolFee       = $Pool_PoolFee
                        Workers       = $null
                        Hashrate      = $null
                        BLK           = $null
                        TSL           = $null
                        Difficulty    = $Stat.Diff_Average
                        SoloMining    = $true
                        WTM           = $true
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
