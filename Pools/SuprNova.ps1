﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
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

$Pool_Fee = 1
$Pool_Region = Get-Region "US"

$Pool_Request = [PSCustomObject]@{}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BCI"     ; rpc = "bci"     ; port = 9166}
    [PSCustomObject]@{symbol = "BEAM"    ; rpc = "beam"    ; port = @(7786,7787)}
    [PSCustomObject]@{symbol = "BTG"     ; rpc = "btg"     ; port = @(8866,8817)}
    [PSCustomObject]@{symbol = "BTX"     ; rpc = "btx"     ; port = 3629}
    [PSCustomObject]@{symbol = "BSD"     ; rpc = "bsd"     ; port = 8686}
	[PSCustomObject]@{symbol = "DASH"    ; rpc = "dash"    ; port = 443}
	[PSCustomObject]@{symbol = "DYN"     ; rpc = "dyn"     ; port = 5960}
    [PSCustomObject]@{symbol = "ERC"     ; rpc = "erc"     ; port = 7674}
	[PSCustomObject]@{symbol = "GAP"     ; rpc = "gap"     ; port = 2433}
    [PSCustomObject]@{symbol = "GRLC"    ; rpc = "grlc"    ; port = 8600}
	[PSCustomObject]@{symbol = "GRS"     ; rpc = "grs"     ; port = 5544}
    [PSCustomObject]@{symbol = "HODL"    ; rpc = "hodl"    ; port = 4693}
    [PSCustomObject]@{symbol = "MNX"     ; rpc = "mnx"     ; port = @(7077,7078)}
    [PSCustomObject]@{symbol = "OBTC"    ; rpc = "obtc"    ; port = [PSCustomObject]@{CPU=4074;GPU=4075}}
	[PSCustomObject]@{symbol = "RIC"     ; rpc = "ric"     ; port = 5000}
    [PSCustomObject]@{symbol = "ROI"     ; rpc = "roi"     ; port = 4699}
    [PSCustomObject]@{symbol = "RVN"     ; rpc = "rvn"     ; port = 8888}
    [pscustomobject]@{symbol = "VEIL"    ; rpc = "veil"    ; port = 7220}
    [pscustomobject]@{symbol = "XVG-X17" ; rpc = "xvg-x17" ; port = 7477}
    [PSCustomObject]@{symbol = "VTC"     ; rpc = "vtc"     ; port = 1777}
	[PSCustomObject]@{symbol = "XCN"     ; rpc = "xcn"     ; port = 8008}
    [PSCustomObject]@{symbol = "YTN"     ; rpc = "ytn"     ; port = 4932}
	[PSCustomObject]@{symbol = "ZEN"     ; rpc = "zen"     ; port = @(3618,3621)}
    [PSCustomObject]@{symbol = "ZER"     ; rpc = "zero"    ; port = @(6568,6569)}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol -replace "-.+")" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Currency = $_.symbol -replace "-.+"
    $Pool_Port = $_.port
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Pool_Hashrate = $Pool_Workers = $null

    if (-not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-WebRequestAsync "https://$($_.rpc).suprnova.cc/index.php" -tag $Name -retry 3 -timeout 15
            if ($Pool_Request -match "b-poolhashrate.+?>([a-z0-9,\.\s]+?)<.+overview-mhs.+?>(.+?)/s") {
                $Pool_Hashrate = [double]($Matches[1] -replace "[,\s]+") * $(Switch -Regex ($Matches[2] -replace "\s+") {"^k" {1e3};"^M" {1e6};"^G" {1e9};"^T" {1e12};"^P" {1e15};default {1}})
            }
            if ($Pool_Request -match "b-poolworkers.+?>([0-9,\s]+?)<") {
                $Pool_Workers = [int]($Matches[1] -replace "[,\s]+")
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($_.symbol) has failed. "        
        }
    }

    $Pool_SSL = $false
    foreach ($Port in @($Pool_Port | Select-Object)) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency 
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = if ($Pool_SSL) {"ssl"} else {"stratum+tcp"}
            Host          = "$($_.rpc).suprnova.cc"
            Port          = if ($Port.CPU) {$Port.CPU} else {$Port}
            Ports         = if ($Port.CPU) {$Port} else {$null}
            User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region
            SSL           = $Pool_SSL
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Workers
            Hashrate      = $Pool_Hashrate
            DataWindow    = $DataWindow
            WTM           = $true
            EthMode       = $Pool_EthProxy
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.$Pool_Currency
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
        $Pool_SSL = $true
    }
}
