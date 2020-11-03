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

[hashtable]$Pool_RegionsTable = @{}
@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "GRIMM";   port = 3333; fee = 1.0; rpc = "grimm"; region = @("us")}
    [PSCustomObject]@{symbol = "XGM";     port = 3333; fee = 1.0; rpc = "defis"; region = @("us"); altsymbol = "DEFIS"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or ($_.altsymbol -and $Wallets."$($_.altsymbol)") -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region
    $Pool_Wallet    = if ($Wallets.$Pool_Currency) {$Wallets.$Pool_Currency} else {$Wallets."$($_.altsymbol)"}

    $Pool_Divisor   = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_RequestBlocks = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath)-api.ravepool.com/v2/poolStats" -tag $Name -timeout 15 -cycletime 120
            if (-not $Pool_Request.pools.$Pool_RpcPath) {$ok = $false}
            else {
                $Pool_RequestBlocks = Invoke-RestMethodAsync "https://$($Pool_RpcPath)-api.ravepool.com/v2/poolBlockStats" -tag $Name -timeout 15 -cycletime 120
                if (-not $Pool_RequestBlocks.result) {$ok = $false}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }
        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        }
    }

    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.pools.$Pool_RpcPath.poolFee

        $Pool_TSL = [Math]::Round($Pool_Request.time - $Pool_Request.pools.$Pool_RpcPath.poolStats.poolLastBlockTime/1000)

        $Pool_BLK = [int]$(if ($Pool_RequestBlocks.ttfbDays -ne "NaN") {
                        86400/$Pool_RequestBlocks.ttfbDays
                    } else {
                        $timestamp24h = ($Pool_Request.time - 86400)*1000
                        $blocks_measure = ($Pool_RequestBlocks.confirmed.blocks.ForEach({($_ -split ':')[2]})+ $Pool_RequestBlocks.pending.blocks.ForEach({($_ -split ':')[2]})).Where({$_ -ge $timestamp24h}) | Measure-Object -Minimum -Maximum
                        $(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400000/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count
                    })

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate $Pool_Request.pools.$Pool_RpcPath.hashrate -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $true
        $Pool_Wallet = Get-WalletWithPaymentId $Pool_Wallet -asobject
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
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$($Pool_HostPath)-$($Pool_Region).ravepool.com"
                Port          = $Pool_Port
                User          = "$($Pool_Wallet.wallet).{workername:$Worker}"
                Pass          = "$(if ($Email) {$Email} else {"x"})"
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pools.$Pool_RpcPath.workerCount
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                WTM           = $true
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
				Disabled      = $false
				HasMinerExclusions = $false
				Price_Bias    = 0.0
				Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet.wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
