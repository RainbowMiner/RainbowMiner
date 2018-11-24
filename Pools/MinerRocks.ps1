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

$Pools_Data = @(
    [PSCustomObject]@{coin = "Boolberry"; symbol = "BBR"; algo = "wildkeccak"; port = 5555; fee = 0.9; walletSymbol = "boolberry"; host = "boolberry.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Purk"; symbol = "PURK"; algo = "wildkeccak"; port = 5555; fee = 0.9; walletSymbol = "purk"; host = "purk.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Graft"; symbol = "GRFT"; algo = "CnV7"; port = 9111; fee = 0.9; walletSymbol = "graft"; host = "graft.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "QRL"; symbol = "QRL"; algo = "CnV7"; port = 9111; fee = 0.9; walletSymbol = "qrl"; host = "qrl.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CnXTL"; port = 4005; fee = 0.9; walletSymbol = "stellite"; host = "stellite.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CnXTL"; port = 4005; fee = 0.9; walletSymbol = "stellite"; host = "sg.stellite.miner.rocks"; region = "asia"}
    [PSCustomObject]@{coin = "Monero"; symbol = "XMR"; algo = "CnV8"; port = 5555; fee = 0.9; walletSymbol = "monero"; host = "monero.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 5555; fee = 0.9; walletSymbol = "loki"; host = "ca.loki.miner.rocks"; region = "us"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 5555; fee = 0.9; walletSymbol = "loki"; host = "loki.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 5555; fee = 0.9; walletSymbol = "loki"; host = "sg.loki.miner.rocks"; region = "asia"}
    [PSCustomObject]@{coin = "Ryo"; symbol = "RYO"; algo = "CnHeavy"; port = 5555; fee = 0.9; walletSymbol = "ryo"; host = "ryo.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 4005; fee = 0.9; walletSymbol = "haven"; host = "ca.haven.miner.rocks"; region = "us"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 4005; fee = 0.9; walletSymbol = "haven"; host = "haven.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHaven"; port = 4005; fee = 0.9; walletSymbol = "haven"; host = "sg.haven.miner.rocks"; region = "asia"}
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 5555; fee = 0.9; walletSymbol = "bittube"; host = "ca.bittube.miner.rocks"; region = "us"}
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 5555; fee = 0.9; walletSymbol = "bittube"; host = "bittube.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 5555; fee = 0.9; walletSymbol = "bittube"; host = "sg.bittube.miner.rocks"; region = "asia"}
    [PSCustomObject]@{coin = "Aeon"; symbol = "AEON"; algo = "CnLiteV7"; port = 5555; fee = 0.9; walletSymbol = "aeon"; host = "aeon.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnFast"; port = 5555; fee = 0.9; walletSymbol = "masari"; host = "masari.miner.rocks"; region = "eu"}
    [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnFast"; port = 5555; fee = 0.9; walletSymbol = "masari"; host = "sg.masari.miner.rocks"; region = "asia"}
)

$Pools_Requests = [hashtable]@{}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.walletSymbol.ToLower()
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Port = $_.port
    $Pool_Fee  = $_.fee
    $Pool_Ports= [PSCustomObject]@{}

    if (-not $Pools_Requests.ContainsKey($Pool_RpcPath)) {
        $Pool_Request = [PSCustomObject]@{}

        $ok = $true
        if (-not $InfoOnly) {
            try {
                $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).miner.rocks/api/stats" -tag $Name
                $Pool_Port = $Pool_Request.config.ports | Where-Object desc -match '(CPU|GPU)' | Select-Object -First 1 -ExpandProperty port
                @("CPU","GPU","RIG") | Foreach-Object {
                    $PortType = $_
                    $Pool_Request.config.ports | Where-Object desc -match $(if ($PortType -eq "RIG") {"farm"} else {$PortType}) | Select-Object -First 1 -ExpandProperty port | Foreach-Object {$Pool_Ports | Add-Member $PortType $_ -Force}
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
                $ok = $false
            }
        }

        if ($ok -and $Pool_Port -and -not $InfoOnly) {
            $Pool_Fee = $Pool_Request.config.fee

            $timestamp    = Get-UnixTimestamp
            $timestamp24h = $timestamp - 24*3600

            $diffDay      = $Pool_Request.pool.stats.diffs.wavg24h
            $diffLive     = $Pool_Request.network.difficulty
            $reward       = $Pool_Request.network.reward

            $profitDay    = 86400/$diffDay*$reward
            $profitLive   = 86400/$diffLive*$reward

            $coinUnits    = $Pool_Request.config.coinUnits
            $amountDay    = $profitDay / $coinUnits
            $amountLive   = $profitLive / $coinUnits

            $btcPrice     = $Pool_Request.coinPrice."coin-btc"
            $btcRewardDay = $amountDay*$btcPrice
            $btcRewardLive= $amountLive*$btcPrice

            $Divisor      = 1

            $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.+?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
            $Pool_BLK = ($blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object).Count
            $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[1]}
    
            if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate ($Pool_Request.pool.hashrate | Where-Object {$timestamp - $_[0] -gt 24*3600} | Foreach-Object {$_[1]} | Measure-Object -Average).Average -BlockRate $Pool_BLK -Quiet}
            else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($btcRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet}
        }
        if (($ok -and $Pool_Port -and ($AllowZero -or $Pool_Request.pool.hashrate -gt 0)) -or $InfoOnly) {
            $Pools_Requests[$Pool_RpcPath] = [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = ""
                Port          = if (-not $Pool_Port) {$_.port} else {$Pool_Port}
                Ports         = $Pool_Ports
                User          = "$($Wallets.$($_.symbol)){diff:.`$difficulty}"
                Pass          = "w={workername:$Worker}"
                Region        = ""
                SSL           = $False
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pool.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
            }
        }
    }

    if ($Pools_Requests.ContainsKey($Pool_RpcPath)) {
        $Pools_Requests[$Pool_RpcPath] | Add-Member -NotePropertyMembers @{Region=(Get-Region $_.region);Host=$_.host} -Force -PassThru | ConvertTo-Json | ConvertFrom-Json
    }
}

Remove-Variable "Pools_Requests"
