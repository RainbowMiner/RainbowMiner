﻿using module ..\Include.psm1

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
# List of coins
#$Pool_HostStatus | where-object {$_.host -notmatch "^solo" -and $_.host -match "^([a-z]+)\."} | Foreach-Object {$Matches[1]} | select-object -unique | sort-object

$Pools_Data = @(
    [PSCustomObject]@{rpc = "ae";    symbol = "AE";    port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "beam";  symbol = "BEAM";  port = 5252; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btcz";  symbol = "BTCZ";  port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "btg";   symbol = "BTG";   port = 4040; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "ckb";   symbol = "CKB";   port = 6464; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "clo";   symbol = "CLO";   port = 3030; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etc";   symbol = "ETC";   port = 1010; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "eth";   symbol = "ETH";   port = 2020; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "etp";   symbol = "ETP";   port = 9292; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "exp";   symbol = "EXP";   port = 3030; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN29";  port = 3030; fee = 1.0; divisor = 1e9; cycles = 42}
    [PSCustomObject]@{rpc = "grin";  symbol = "GRIN31";  port = 3030; fee = 1.0; divisor = 1e9; cycles = 42; primary = $true}
    [PSCustomObject]@{rpc = "moac";  symbol = "MOAC";  port = 5050; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "pirl";  symbol = "PIRL";  port = 6060; fee = 1.0; divisor = 1e18}
    [PSCustomObject]@{rpc = "rvn";   symbol = "RVN";   port = 6060; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "xmr";   symbol = "XMR";   port = 2222; fee = 1.0; divisor = 1e12}
    [PSCustomObject]@{rpc = "xzc";   symbol = "XZC";   port = 8080; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zcl";   symbol = "ZCL";   port = 2020; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zec";   symbol = "ZEC";   port = 1010; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zel";   symbol = "ZEL";   port = 9090; fee = 1.0; divisor = 1e8}
    [PSCustomObject]@{rpc = "zen";   symbol = "ZEN";   port = 3030; fee = 1.0; divisor = 1e8}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol -replace "\d")" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_Currency = $_.symbol -replace "\d"
    $Pool_Host = "$($_.rpc).2miners.com"
    $Pool_Fee = $_.fee
    $Pool_Divisor = $_.divisor

    $ok = ($Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)"} | Measure-Object).Count -gt 0
    if ($ok -and -not $InfoOnly) {
        $Pool_Blocks = [PSCustomObject]@{}

        try {
            $Pool_Blocks = Invoke-RestMethodAsync "https://$($Pool_Host)/api/blocks" -tag $Name -retry 5 -retrywait 250 -cycletime 120 -delay 250
            if ($Pool_Blocks.code -ne $null) {$ok=$false}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }

        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
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
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            return
        }

        $timestamp    = [int]($Pool_Request.now / 1000)
        $timestamp24h = $timestamp - 24*3600
            
        $blocks = @($Pool_Blocks.candidates | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.immature | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.matured | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) | Select-Object

        $blocks_measure = $blocks | Measure-Object timestamp -Minimum -Maximum
        $avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
        $Pool_BLK       = [int]$(if ($avgTime) {86400/$avgTime})
        $Pool_TSL       = $timestamp - $Pool_Request.stats.lastBlockFound
        $reward         = $(if ($blocks) {($blocks | Measure-Object reward -Average).Average} else {0})/$Pool_Divisor
        $btcPrice       = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency} else {0}

        if ($_.cycles) {
            $PBR  = (86400 / $_.cycles) * ($(if ($_.primary) {$Pool_Request.nodes.primaryWeight} else {$Pool_Request.nodes.secondaryScale})/$Pool_Request.nodes.difficulty)
            $btcRewardLive   = $PBR * $reward * $btcPrice
            $addName         = $_.symbol -replace "[^\d]"
            $Divisor         = 1
            $Hashrate        = $Pool_Request.hashrates.$addName
        } else {
            $btcRewardLive   = if ($Pool_Request.hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Pool_Request.hashrate} else {0}
            $addName         = ""
            $Divisor         = 1
            $Hashrate        = $Pool_Request.hashrate
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)$($addName)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok) {
        $Pool_Hosts = @()
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.'
        $Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)" -and $Pool_Hosts -notcontains "$($_.host)$([int]$_.port -ge 10000)"} | Select-Object host,port | Foreach-Object {
            $SSL = [int]$_.port -ge 10000
            $Pool_Hosts += "$($_.host)$($SSL)"
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = if ($SSL) {"stratum+ssl"} else {"stratum+tcp"}
                Host          = "$($_.host)"
                Port          = [int]$_.port
                User          = "$($Pool_Wallet).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable."$(if ($_.host -match "^(asia|us)-") {$Matches[1]} else {"eu"})"
                SSL           = $SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.workersTotal
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
