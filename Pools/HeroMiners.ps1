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

$Pool_Region_Default = @("eu")

[hashtable]$Pool_RegionsTable = @{}
@("de","ca","eu","sg","hk") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ARQ";   port = 10641; fee = 0.9; rpc = "arqma"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "ARQ";   port = 10641; fee = 0.9; rpc = "iridium";    symbol2 = "IRD";  units2=1e8; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "ARQ";   port = 10630; fee = 0.9; rpc = "arqple";     symbol2 = "PLE";  units2=1e8}
    [PSCustomObject]@{symbol = "ARQ";   port = 10671; fee = 0.9; rpc = "cypruscoin"; symbol2 = "XCY";  units2=1e6}
    [PSCustomObject]@{symbol = "BLOC";  port = 10430; fee = 0.9; rpc = "bloc"}
    [PSCustomObject]@{symbol = "CCX";   port = 10361; fee = 0.9; rpc = "conceal"; region = @("de","ca","sg","hk")}
    [PSCustomObject]@{symbol = "GRFT";  port = 10100; fee = 0.9; rpc = "graft"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "LOKI";  port = 10111; fee = 0.9; rpc = "loki"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "MSR";   port = 10150; fee = 0.9; rpc = "masari"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "QRL";   port = 10370; fee = 0.9; rpc = "qrl"}
    [PSCustomObject]@{symbol = "RYO";   port = 10270; fee = 0.9; rpc = "ryo"}
    [PSCustomObject]@{symbol = "SUMO";  port = 10610; fee = 0.9; rpc = "sumo"}
    [PSCustomObject]@{symbol = "TRTL";  port = 10380; fee = 0.9; rpc = "turtlecoin"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "TUBE";  port = 10280; fee = 0.9; rpc = "tube"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "UPX";   port = 10470; fee = 0.9; rpc = "uplexa"; region = @("de","ca","sg","hk")}
    [PSCustomObject]@{symbol = "WOW";   port = 10660; fee = 0.9; rpc = "wownero"; region = @("eu","hk")}
    [PSCustomObject]@{symbol = "XCASH"; port = 10440; fee = 0.9; rpc = "xcash"; region = @("de","ca","sg","hk")}
    [PSCustomObject]@{symbol = "XEQ";   port = 10600; fee = 0.9; rpc = "equilibria"; region = @("eu","hk")}
    [PSCustomObject]@{symbol = "XEQ";   port = 10600; fee = 0.9; rpc = "equilibria"; symbol2 = "NBX"; units2=1e2; region = @("eu","hk")}
    [PSCustomObject]@{symbol = "XHV";   port = 10140; fee = 0.9; rpc = "haven"; region = @("eu","ca","sg","hk")}
    [PSCustomObject]@{symbol = "XLA";   port = 10130; fee = 0.9; rpc = "scala"; region = @("eu","hk")}
    [PSCustomObject]@{symbol = "XMR";   port = 10190; fee = 0.9; rpc = "monero"; region = @("eu","ca","hk")}
    [PSCustomObject]@{symbol = "XWP";   port = 10441; fee = 0.9; rpc = "swap"; divisor = 32; region = @("eu","ca","sg","hk")}
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
    $Pool_Regions   = if ($_.region) {$_.region} else {$Pool_Default_Region}

    $Pool_Divisor   = if ($_.divisor) {$_.divisor} else {1}
    $Pool_HostPath  = if ($_.host) {$_.host} else {$Pool_RpcPath}

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_Ports    = @([PSCustomObject]@{})

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).herominers.com/api/stats" -tag $Name -timeout 15 -cycletime 120
            $Pool_Ports   = Get-PoolPortsFromRequest $Pool_Request -mCPU "" -mGPU "(multi|high)" -mRIG "(cloud|very high|nicehash)"
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
    }
    
    if (($ok -and ($AllowZero -or $Pool_Data.Live.hashrate -gt 0)) -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            if ($Pool_Port) {
                foreach ($Pool_Region in $Pool_Regions) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = "$($Pool_Coin.Name)$(if ($Pool_Coin2) {"+$($Pool_Coin2.Name)"})"
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = "$(if ($Pool_Region -ne "eu") {"$($Pool_Region)."})$($Pool_HostPath).herominers.com"
                        Port          = $Pool_Port.CPU
                        Ports         = $Pool_Port
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
                        AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Wallet        = $Pool_Wallet.wallet
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
            $Pool_SSL = $true
        }
    }
}
