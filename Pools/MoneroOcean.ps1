using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_5",
    [String]$Password = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly -and -not $Wallets.XMR -and -not $Password) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/moneroocean.json" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_PoolFee = 0.68

$Pool_Request | Where-Object {($_.profit -gt 0.00 -and ($AllowZero -or $_.hashrate -gt 0)) -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_CoinSymbol = $_.coin
    $Pool_Coin = Get-Coin $Pool_CoinSymbol
    $Pool_Algorithm_Norm = $Pool_Coin.Algo

    if (-not $InfoOnly) {
        $Pool_TSL = if ($_.tsl -ge 0) {$_.tsl} else {$null}
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value $_.profit -Duration $StatSpan -ChangeDetection $false -Difficulty $_.diff -HashRate $_.hashrate -Quiet
    }

    foreach($Pool_Protocol in @("stratum+tcp","stratum+ssl")) {
        $Port = if ($Pool_Protocol -match "ssl") {20001} else {10001}
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_CoinSymbol
            Currency      = "XMR"
            Price         = $Stat.$StatAverage
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = $Pool_Protocol
            Host          = "gulf.moneroocean.stream"
            Port          = $Port
            Ports         = [PSCustomObject]@{CPU=$Port; GPU=$Port+1; RIG=$Port+31}
            User          = "$($Wallets.XMR)"
            Pass          = "{workername:$Worker}:$($Password)~$($_.algo)"
            Region        = Get-Region "US"
            SSL           = $Pool_Protocol -match "ssl"
            Updated       = $Stat.Updated
            #WTM           = $true
            PoolFee       = $Pool_PoolFee
            Workers       = $_.worker
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            #BLK           = $Stat.BlockRate_Average
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.XMR
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}