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

[hashtable]$Pool_RegionsTable = @{}
@("de","fi","ca","hk","sg") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AEON";  port = 10651; fee = 0.9; rpc = "aeon"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "ARQ";   port = 10641; fee = 0.9; rpc = "arqma"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "TUBE";  port = 10281; fee = 0.9; rpc = "bittube"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "BLOC";  port = 10431; fee = 0.9; rpc = "bloc"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "CCX";   port = 10361; fee = 0.9; rpc = "conceal"; region = @("fi","de","ca","hk","sg")}
    [PSCustomObject]@{symbol = "DERO";  port = 10121; fee = 0.9; rpc = "dero"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "GRFT";  port = 10101; fee = 0.9; rpc = "graft"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XHV";   port = 10451; fee = 0.9; rpc = "haven"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "LOKI";  port = 10111; fee = 0.9; rpc = "loki"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "MSR";   port = 10151; fee = 0.9; rpc = "masari"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "XMR";   port = 10191; fee = 0.9; rpc = "monero"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "QRL";   port = 10371; fee = 0.9; rpc = "qrl"; region = @("de")}
    [PSCustomObject]@{symbol = "RYO";   port = 10271; fee = 0.9; rpc = "ryo"; region = @("de","fi")}
    [PSCustomObject]@{symbol = "XLA";   port = 10131; fee = 0.9; rpc = "scala"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "SUMO";  port = 10611; fee = 0.9; rpc = "sumo"; region = @("de","fi")}
    [PSCustomObject]@{symbol = "XWP";   port = 10441; fee = 0.9; rpc = "swap"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "TRTL";  port = 10381; fee = 0.9; rpc = "turtlecoin"; region = @("de","fi","ca","hk","sg")}
    [PSCustomObject]@{symbol = "UPX";   port = 10471; fee = 0.9; rpc = "uplexa"; region = @("fi","de","ca","hk","sg")}
    [PSCustomObject]@{symbol = "WOW";   port = 10661; fee = 0.9; rpc = "wownero"; region = @("de","fi","hk")}
    [PSCustomObject]@{symbol = "XCASH"; port = 10491; fee = 0.9; rpc = "xcash"; region = @("fi","de","ca","hk","sg")}
)

$Pools_Data | Where-Object {($Wallets."$($_.symbol)" -and (-not $_.symbol2 -or $Wallets."$($_.symbol2)")) -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Coin2     = if ($_.symbol2) {Get-Coin $_.symbol2}
    $Pool_Currency  = $_.symbol
    $Pool_Currency2 = $_.symbol2
    $Pool_Units2    = $_.units2
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    $Pool_Divisor   = 1
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "(multi|high)" -mRIG "(cloud|very high|nicehash)"
            if ($Pool_Request.config.cycleLength) {$Pool_Divisor = $Pool_Request.config.cycleLength}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }

        if (-not ($Pool_Ports | Where-Object {$_} | Measure-Object).Count) {$ok = $false}
    }

    if ($ok -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        $timestamp  = Get-UnixTimestamp

        $Pool_StatFn = "$($Name)_$($Pool_Currency)$(if ($Pool_Currency2) {$Pool_Currency2})_Profit"
        $dayData     = -not (Test-Path "Stats\Pools\$($Pool_StatFn).txt")
        $Pool_Reward = "Live" #if ($dayData) {"Day"} else {"Live"}
        $Pool_Data   = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -addBlockData

        if ($Pool_Currency2) {
            $Pool_Data2 = Get-PoolDataFromRequest $Pool_Request -Currency $Pool_Currency2 -Divisor $Pool_Divisor -Timestamp $timestamp -addDay:$dayData -NetworkField "childnetwork" -LastblockField "lastchildblock" -coinUnits $Pool_Units2 -priceFromSession -forceCoinUnits
            $Pool_Data.$Pool_Reward.reward += $Pool_Data2.$Pool_Reward.reward
        }

        $Stat = Set-Stat -Name $Pool_StatFn -Value ($Pool_Data.$Pool_Reward.reward/1e8) -Duration $(if ($dayData) {New-TimeSpan -Days 1} else {$StatSpan}) -HashRate $Pool_Data.$Pool_Reward.hashrate -BlockRate $Pool_Data.BLK -ChangeDetection $dayData -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                $First = $true
                foreach ($Pool_Region in $Pool_Regions) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
						Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = "$($Pool_Coin.Name)$(if ($Pool_Coin2) {"+$($Pool_Coin2.Name)"})"
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = "$(if (-not $First) {"$($Pool_Region)."})$($Pool_HostPath).herominers.com"
                        Port          = if ($Pool_Port.CPU -ne $null) {$Pool_Port.CPU} else {$_.port}
                        Ports         = if ($Pool_Port.CPU -ne $null) {$Pool_Port} else {$null}
                        User          = "$($Pool_Wallet.wallet)$(if ($Pool_Request.config.fixedDiffEnabled) {if ($Pool_Wallet.difficulty) {"$($Pool_Request.config.fixedDiffSeparator)$($Pool_Wallet.difficulty)"} else {"{diff:$($Pool_Request.config.fixedDiffSeparator)`$difficulty}"}})"
                        Pass          = "$(if ($Pool_Currency2) {"$(Get-WalletWithPaymentId $Wallets.$Pool_Currency2)@"}){workername:$Worker}"
                        Region        = $Pool_RegionsTable[$Pool_Region]
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Workers       = $Pool_Data.Workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_Data.TSL
                        BLK           = $Stat.BlockRate_Average
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
                    $First = $false
                }
            }
            $Pool_SSL = $true
        }
    }
}
