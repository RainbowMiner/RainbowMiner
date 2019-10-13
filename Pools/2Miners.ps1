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
    $Pool_HostStatus = Invoke-RestMethodAsync "https://status-api.2miners.com/" -tag $Name -retry 5 -retrywait 250 -cycletime 120
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
    [PSCustomObject]@{rpc = "eth";   symbol = "ETH";   port = 2020; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";   port = 1010; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "clo";   symbol = "CLO";   port = 3030; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "moac";  symbol = "MOAC";  port = 5050; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "exp";   symbol = "EXP";   port = 3030; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "music"; symbol = "MUSIC"; port = 4040; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "pirl";  symbol = "PIRL";  port = 6060; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etp";   symbol = "ETP";   port = 9292; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "ella";  symbol = "ELLA";  port = 3030; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "dbix";  symbol = "DBIX";  port = 2020; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "yoc";   symbol = "YOC";   port = 4040; fee = 1.0; divisor = 1e18}
    #[PSCustomObject]@{rpc = "aka";   symbol = "AKA";   port = 5050; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "zec";   symbol = "ZEC";   port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zcl";   symbol = "ZCL";   port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zen";   symbol = "ZEN";   port = 3030; fee = 1.0; divisor = 1e8}
    #[PSCustomObject]@{rpc = "hush";  symbol = "HUSH";  port = 7070; fee = 1.0; divisor = 1e8}
    #[PSCustomObject]@{rpc = "btcp";  symbol = "BTCP";  port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btg";   symbol = "BTG";   port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btcz";  symbol = "BTCZ";  port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   symbol = "ZEL";   port = 9090; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   symbol = "XMR";   port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "xzc";   symbol = "XZC";   port = 8080; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN";  port = 3030; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "ae";    symbol = "AE";    port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "rvn";   symbol = "RVN";   port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam";  symbol = "BEAM";  port = 5252; fee = 1.0; divisor = 1e8}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol
    $Pool_Host = "$($_.rpc).2miners.com"
    $Pool_Fee = $_.fee
    $Pool_Divisor = $_.divisor

    $ok = ($Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)"} | Measure-Object).Count -gt 0
    if ($ok -and -not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_Host)/api/stats" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
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
                $Pool_Blocks = Invoke-RestMethodAsync "https://$($Pool_Host)/api/blocks" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
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
            if ($Pool_Blocks.candidatesTotal) {$blocks += $Pool_Blocks.candidates | Select-Object timestamp,reward,difficulty}
            if ($Pool_Blocks.immatureTotal)   {$blocks += $Pool_Blocks.immature   | Select-Object timestamp,reward,difficulty}
            if ($Pool_Blocks.maturedTotal)    {$blocks += $Pool_Blocks.matured    | Select-Object timestamp,reward,difficulty}

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
        $Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)" -and $Pool_Hosts -notcontains $Pool_Host} | Select-Object host,port | Foreach-Object {
            $Pool_Hosts += $_.host
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
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
                AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
