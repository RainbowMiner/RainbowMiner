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

$Pool_Type = "solo"
$Pool_Fee  = 1.0

[hashtable]$Pool_RegionsTable = @{}
@("Netherlands","Moscow") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://baikalmine.com/api/pool/menu/getTopMenu" -tag "BaikalMine" -cycletime 3600 -retry 5 -retrywait 250 | Where {$_.alias -eq $Pool_Type}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request.coins | Where-Object {$Wallets."$($_.name)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.name

    if ($Pool_Coin = Get-Coin $Pool_Currency) {
        $Pool_Algorithm_Norm = $Pool_Coin.Algo
    } else {
        Write-Log -Level Warn "Pool $($Name): missing coin $($Pool_Currency) in db"
        return
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $PoolInfo_Request  = [PSCustomObject]@{}

    try {
        $PoolInfo_Request   = Invoke-RestMethodAsync "https://baikalmine.com/api/pool/info/getInfo"  -tag $Name -cycletime 120 -delay 250 -body @{type = $Pool_Type; coin = $_.alias}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool $($Name): Info API for $($Pool_Currency) has failed. "
        return
    }

    $Pool_RPC      = ($PoolInfo_Request.ports | Where-Object {$_.location -eq "Moscow"} | Select-Object -First 1).server

    $Pool_Hashrate = $null
    $Pool_Workers  = $null
    $Pool_TSL      = $null
    $Pool_BLK      = $null

    $PoolStats_Request  = [PSCustomObject]@{}
    $PoolBlocks_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        try {
            $PoolStats_Request  = Invoke-RestMethodAsync "https://$($Pool_RPC)/api/stats"  -tag $Name -cycletime 120 -delay 250
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool $($Name): Stats API for $($Pool_Currency) has failed. "
        }

        $difficulty = ($PoolStats_Request.nodes | Where-Object name -eq "main").difficulty / [Math]::Pow(2,32)

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty $difficulty -Quiet
    }
    
    foreach($Pool_Info in $PoolInfo_Request.ports) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = "stratum+$(if ($Pool_Info.ssl) {"ssl"} else {"tcp"})"
            Host          = $Pool_Info.server
            Port          = $Pool_Info.port
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_RegionsTable."$($Pool_Info.location)"
            SSL           = $Pool_Info.ssl
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            Workers       = $null
            Hashrate      = $null
            BLK           = $null
            TSL           = $null
            Difficulty    = $Stat.Diff_Average
            SoloMining    = $true
            WTM           = $true
            Mallob        = if ($Pool_Info.additionally -match "(http.+?)$") {$Matches[1]} else {$null}
            EthMode       = $Pool_EthProxy
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_0       = 0.0
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
