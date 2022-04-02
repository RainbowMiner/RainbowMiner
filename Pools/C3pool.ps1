using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$Password = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly -and -not $Wallets.XMR -and -not $Password) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/c3pool.json" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_PoolFee = 0.68 # cost for exchange
$Pool_Region  = Get-Region "CN"

$Pool_Request | Group-Object -Property algo | ForEach-Object {
    $IsFirst = $true
    $_.Group | Sort-Object -Property profit -Descending | Foreach-Object {
        $Pool_Port = $_.port
        $Pool_CoinSymbol = $_.coin
        $Pool_Coin = Get-Coin $Pool_CoinSymbol
        $Pool_Algorithm_Norm = if ($Pool_Coin) {$Pool_Coin.Algo} else {Get-Algorithm $_.algo}

        if (-not $InfoOnly) {
            $Pool_TSL = if ($_.tsl -ge 0) {$_.tsl} else {$null}
            if ($_.profit -eq 0.0) {return}
            $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value $_.profit -Duration $StatSpan -ChangeDetection $false -Difficulty $_.diff -HashRate $_.hashrate -BlockRate $(if ($_.ttf -gt 0) {86400/$_.ttf} else {0}) -Quiet
            if (-not $IsFirst -or ($_.hashrate -eq 0 -and -not $AllowZero)) {return}
        }

        $IsFirst = $false

        foreach($Pool_SSL in @($false,$true)) {
            if ($Pool_SSL) {
                $Pool_Protocol = "stratum+ssl"
                $Port = 33333
            } else {
                $Pool_Protocol = "stratum+tcp"
                $Port = 15555
            }
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
			    Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = if ($Pool_Coin) {$Pool_Coin.Name} else {$Pool_CoinSymbol}
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = "XMR"
                Price         = $Stat.$StatAverage
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = $Pool_Protocol
                Host          = "mine.c3pool.com"
                Port          = $Port
                User          = "$($Wallets.XMR)"
                Pass          = "{workername:$Worker}:$($Password)~$($_.algo)"
                Region        = $Pool_Region
                SSL           = $Pool_SSL
                SSLSelfSigned = $Pool_SSL
                Updated       = $Stat.Updated
                #WTM           = $true
                PoolFee       = $Pool_PoolFee + $_.fee
                Workers       = $_.worker
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratumnh"} else {$null}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.XMR
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}