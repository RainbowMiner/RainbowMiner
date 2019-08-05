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

$Pool_Region_Default = "eu"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_HostStatus = [PSCustomObject]@{}

try {
    $Pool_HostStatus = Invoke-RestMethodAsync "https://status-api.2miners.com/" -tag $Name -retry 5 -retrywait 200 -cycletime 120
    if ($Pool_HostStatus.code -ne $null) {throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

# Create basic structure
#$Pool_Home = Invoke-WebRequest "https://2miners.com" -UseBasicParsing -TimeoutSec 10
#$Pool_Home.Links | Where {$_.class -eq "link pools-list__item" -and $_.href -notmatch "solo-" -and $_.outerHTML -match "/(.+?)-mining-pool.+?>(.+?)<"} | Foreach-Object {
#    $Short = $Matches[1]
#    $Name  = $Matches[2]
#    $Pool_Request | where {$_.host -match "^$($Short).2miners.com"} | select-object -first 1 | foreach {"[PSCustomObject]@{host = `"$($_.host)`"; coin = `"$($Name)`"; algo = `"`"; symbol = `"$(($_.host -split '\.' | Select -First 1).ToUpper())`"; port = $($_.port); fee = 1}"}
#}

$Pools_Data = @(
    [PSCustomObject]@{rpc = "eth";   coin = "Ethereum";        algo = "Ethash";       symbol = "ETH";   port = 2020; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "etc";   coin = "EthereumClassic"; algo = "Ethash";       symbol = "ETC";   port = 1010; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "clo";   coin = "Callisto";        algo = "Ethash";       symbol = "CLO";   port = 3030; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "moac";  coin = "MOAC";            algo = "Ethash";       symbol = "MOAC";  port = 5050; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "exp";   coin = "Expanse";         algo = "Ethash";       symbol = "EXP";   port = 3030; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "music"; coin = "Musicoin";        algo = "Ethash";       symbol = "MUSIC"; port = 4040; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "pirl";  coin = "Pirl";            algo = "Ethash";       symbol = "PIRL";  port = 6060; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "etp";   coin = "Metaverse ETP";   algo = "Ethash";       symbol = "ETP";   port = 9292; fee = 1.5; divisor = 1e18}
    #[PSCustomObject]@{rpc = "ella";  coin = "Ellaism";         algo = "Ethash";       symbol = "ELLA";  port = 3030; fee = 1.5; divisor = 1e18}
    #[PSCustomObject]@{rpc = "dbix";  coin = "Dubaicoin";       algo = "Ethash";       symbol = "DBIX";  port = 2020; fee = 1.5; divisor = 1e18}
    #[PSCustomObject]@{rpc = "yoc";   coin = "Yocoin";          algo = "Ethash";       symbol = "YOC";   port = 4040; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "aka";   coin = "Akroma";          algo = "Ethash";       symbol = "AKA";   port = 5050; fee = 1.5; divisor = 1e18}
    [PSCustomObject]@{rpc = "zec";   coin = "Zcash";           algo = "Equihash";     symbol = "ZEC";   port = 1010; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "zcl";   coin = "Zclassic";        algo = "Equihash";     symbol = "ZCL";   port = 2020; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "zen";   coin = "Zencash";         algo = "Equihash";     symbol = "ZEN";   port = 3030; fee = 1.5; divisor = 1e8}
    #[PSCustomObject]@{rpc = "hush";  coin = "Hush";            algo = "Equihash";     symbol = "HUSH";  port = 7070; fee = 1.5; divisor = 1e8}
    #[PSCustomObject]@{rpc = "btcp";  coin = "BitcoinPrivate";  algo = "Equihash";     symbol = "BTCP";  port = 1010; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "btg";   coin = "BitcoinGold";     algo = "Equihash24x5"; symbol = "BTG";   port = 4040; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "btcz";  coin = "BitcoinZ";        algo = "Equihash24x5"; symbol = "BTCZ";  port = 2020; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   coin = "ZelCash";         algo = "Equihash25x4"; symbol = "ZEL";   port = 9090; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   coin = "Monero";          algo = "Monero";       symbol = "XMR";   port = 2222; fee = 1.5; divisor = 1e12}
    [PSCustomObject]@{rpc = "xzc";   coin = "Zсoin";           algo = "MTP";          symbol = "XZC";   port = 8080; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "grin";  coin = "GRIN";            algo = "Cuckarood29";  symbol = "GRIN";  port = 3030; fee = 1.5; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "ae";    coin = "AEternity";       algo = "Aeternity";    symbol = "AE";    port = 4040; fee = 1.5; divisor = 1e8}
    [PSCustomObject]@{rpc = "rvn";   coin = "RavenCoin";       algo = "X16R";         symbol = "RVN";   port = 6060; fee = 1.5; divisor = 1e8}

    #[PSCustomObject]@{rpc = "grin";  coin = "GRIN";            algo = "Cuckatoo31";   symbol = "GRIN";  port = 3030; fee = 1.5; divisor = 1e9; cycles = 42; primary = $true}
    #[PSCustomObject]@{rpc = "progpow-eth"; coin = "Ethereum ProgPoW"; algo = "ProgPoW"; symbol = "ETH"; port = 2020; fee = 1.5; divisor = 1e18}
)

$Pool_Currencies = @($Pools_Data | Select-Object -ExpandProperty symbol | Where-Object {$Wallets."$($_)"} | Select-Object -Unique)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_Currency = $_.symbol
    $Pool_Coin = $_.coin
    $Pool_Host = "solo-$($_.rpc).2miners.com"
    $Pool_Fee = $_.fee
    $Pool_Divisor = $_.divisor

    $ok = ($Pool_HostStatus | Where-Object {$_.host -match "$($Pool_Host)"} | Measure-Object).Count -gt 0
    if ($ok -and -not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_Host)/api/stats" -tag $Name -retry 5 -retrywait 200 -cycletime 120 -delay 200
            if ($Pool_Request.code -ne $null -or $Pool_Request.nodes -eq $null -or -not $Pool_Request.nodes) {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            $ok = $false
        }

        if ($ok) {
            $Pool_Blocks = [PSCustomObject]@{}

            try {
                $Pool_Blocks = Invoke-RestMethodAsync "https://$($Pool_Host)/api/blocks" -tag $Name -retry 5 -retrywait 200 -cycletime 120 -delay 200
                if ($Pool_Blocks.code -ne $null) {throw}
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
                $ok = $false
            }


            $timestamp    = Get-UnixTimestamp
            $timestamp24h = $timestamp - 24*3600

            $blocks = @()
            if ($Pool_Blocks.candidatesTotal) {$blocks += $Pool_Blocks.candidates | Select-Object timestamp,reward}
            if ($Pool_Blocks.immatureTotal)   {$blocks += $Pool_Blocks.immature   | Select-Object timestamp,reward}
            if ($Pool_Blocks.maturedTotal)    {$blocks += $Pool_Blocks.matured    | Select-Object timestamp,reward}
            
            $blocks_measure = $blocks | Where-Object {$_.timestamp -gt $timestamp24h} | Measure-Object timestamp -Minimum -Maximum
            $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
            $Pool_BLK       = [int]$(if ($avgTime) {86400/$avgTime})
            $Pool_TSL       = $timestamp - $Pool_Request.stats.lastBlockFound            
            $reward         = $(if ($blocks) {$blocks | Sort-Object timestamp | Select-Object -Last 1 -ExpandProperty reward} else {0})/$Pool_Divisor
            $btcPrice       = if ($Session.Rates.$Pool_Currency) {1/[double]$Session.Rates.$Pool_Currency} else {0}

            if ($_.cycles) {
                $PBR  = (86400 / $_.cycles) * ($(if ($_.primary) {$Pool_Request.nodes.primaryWeight} else {$Pool_Request.nodes.secondaryScale})/$Pool_Request.nodes.difficulty)
                $btcRewardLive   = $PBR * $reward * $btcPrice
                $addName         = $_.algo -replace "[^\d]"
                $Divisor         = 1
            } else {
                $btcRewardLive   = if ($Pool_Request.hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Pool_Request.hashrate} else {0}
                $addName         = ""
                $Divisor         = 1
            }
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)$($addName)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Quiet
        }
    }

    if ($ok) {
        $Pool_Hosts = @()
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.'
        $Pool_HostStatus | Where-Object {$_.host -match "$($Pool_Host)" -and $Pool_Hosts -notcontains $Pool_Host} | Select-Object host,port | Foreach-Object {
            $Pool_Hosts += $_.host
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($_.host)"
                Port          = $_.port
                User          = "$($Pool_Wallet).{workername:$Worker}"
                Pass          = "x"
                Worker        = "{workername:$Worker}"
                Region        = $Pool_RegionsTable."$(if ($_.host -match "^(asia|us)-") {$Matches[1]} else {"eu"})"
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.workersTotal
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
            }
        }
    }
}
