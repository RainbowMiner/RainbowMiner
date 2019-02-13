using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
    [PSCustomObject]@{id = "eth"; coin = "Ethereum"; algo = "Ethash"; symbol = "ETH"; port = 2020; fee = 1}
    [PSCustomObject]@{id = "etc"; coin = "Ethereum Classic"; algo = "Ethash"; symbol = "ETC"; port = 1010; fee = 1}
    [PSCustomObject]@{id = "clo"; coin = "Callisto"; algo = "Ethash"; symbol = "CLO"; port = 3030; fee = 1}
    [PSCustomObject]@{id = "moac"; coin = "MOAC"; algo = "Ethash"; symbol = "MOAC"; port = 5050; fee = 1}
    [PSCustomObject]@{id = "exp"; coin = "Expanse"; algo = "Ethash"; symbol = "EXP"; port = 3030; fee = 1}
    [PSCustomObject]@{id = "music"; coin = "Musicoin"; algo = "Ethash"; symbol = "MUSIC"; port = 4040; fee = 1}
    [PSCustomObject]@{id = "pirl"; coin = "Pirl"; algo = "Ethash"; symbol = "PIRL"; port = 6060; fee = 1}
    [PSCustomObject]@{id = "etp"; coin = "Metaverse ETP"; algo = "Ethash"; symbol = "ETP"; port = 9292; fee = 1}
    [PSCustomObject]@{id = "ella"; coin = "Ellaism"; algo = "Ethash"; symbol = "ELLA"; port = 3030; fee = 1}
    [PSCustomObject]@{id = "yoc"; coin = "Yocoin"; algo = "Ethash"; symbol = "YOC"; port = 4040; fee = 1}
    [PSCustomObject]@{id = "aka"; coin = "Akroma"; algo = "Ethash"; symbol = "AKA"; port = 5050; fee = 1}
    [PSCustomObject]@{id = "zec"; coin = "Zcash"; algo = "Equihash"; symbol = "ZEC"; port = 1010; fee = 1}
    [PSCustomObject]@{id = "zcl"; coin = "Zclassic"; algo = "Equihash"; symbol = "ZCL"; port = 2020; fee = 1}
    [PSCustomObject]@{id = "zen"; coin = "Zencash"; algo = "Equihash"; symbol = "ZEN"; port = 3030; fee = 1}
    [PSCustomObject]@{id = "hush"; coin = "Hush"; algo = "Equihash"; symbol = "HUSH"; port = 7070; fee = 1}
    [PSCustomObject]@{id = "btcp"; coin = "Bitcoin Private"; algo = "Equihash"; symbol = "BTCP"; port = 1010; fee = 1}
    [PSCustomObject]@{id = "btg"; coin = "Bitcoin GOLD"; algo = "Equihash24x5"; symbol = "BTG"; port = 4040; fee = 1}
    [PSCustomObject]@{id = "btcz"; coin = "BitcoinZ"; algo = "Equihash24x5"; symbol = "BTCZ"; port = 2020; fee = 1}
    [PSCustomObject]@{id = "zel"; coin = "ZelCash"; algo = "Equihash24x5"; symbol = "ZEL"; port = 9090; fee = 1}
    [PSCustomObject]@{id = "xmr"; coin = "Monero"; algo = "Monero"; symbol = "XMR"; port = 2222; fee = 1}
    [PSCustomObject]@{id = "xzc"; coin = "Zсoin"; algo = "MTP"; symbol = "XZC"; port = 8080; fee = 1}
    [PSCustomObject]@{id = "progpow-eth"; coin = "Ethereum ProgPoW"; algo = "ProgPoW"; symbol = "ETH"; port = 2020; fee = 1}
)

$Pool_Currencies = @($Pools_Data | Select-Object -ExpandProperty symbol | Where-Object {$Wallets."$($_)"} | Select-Object -Unique)

if (($Pool_Currencies | Measure-Object).Count) {$Pool_Ticker = Get-TickerGlobal $Pool_Currencies}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_Currency = $_.symbol
    $Pool_Coin = $_.coin
    $Pool_Host = "$($_.id).2miners.com"
    $Pool_Fee = $_.fee

    $ok = ($Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)"} | Measure-Object).Count -gt 0
    if ($ok -and -not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_Host)/api/stats" -tag $Name -retry 5 -retrywait 200 -cycletime 120 -delay 200
            if ($Pool_Request.code -ne $null) {throw}
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
            
            $diffLive     = [Double]$Pool_Request.nodes[0].difficulty
            $reward       = [Double]$Pool_Blocks."$(if ($Pool_Blocks.candidatesTotal) {"candidates"} elseif ($Pool_Blocks.immatureTotal) {"immature"} else {"matured"})"[0].reward
            $profitLive   = 86400/$diffLive*$reward
            $coinUnits    = 1e10
            $amountLive   = $profitLive / $coinUnits

            $lastSatPrice = [Double]$Pool_Ticker.$Pool_Currency.BTC
            $satRewardLive = $amountLive * $lastSatPrice

            $Divisor = 1e8
            
            $blocks = $Pool_Blocks.candidates.timestamp + $Pool_Blocks.immature.timestamp + $Pool_Blocks.matured.timestamp
            $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
            $Pool_BLK = [int]$(if ($blocks_measure.Maximum - $blocks_measure.Minimum) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)*$blocks_measure.Count})
            $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0]}

            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Quiet

        }
    }

    if ($ok) {
        $Pool_Hosts = @()
        $Pool_HostStatus | Where-Object {$_.host -notmatch 'solo-' -and $_.host -match "$($Pool_Host)" -and $Pool_Hosts -notcontains $Pool_Host} | Select-Object host,port | Foreach-Object {
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
                User          = "$($Wallets."$($Pool_Currency)").{workername:$Worker}"
                Pass          = "x"
                Region        = Get-Region $(if ($_.host -match "^(asia|us)-") {$Matches[1]} else {"eu"})
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.workersTotal
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
            }
        }
    }
}
