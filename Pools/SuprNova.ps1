using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee_Percent = 1.0

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.suprnova.cc/api.php" -tag $Name -cycletime 120 -delay 750 -timeout 30
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if ($Pool_Request.status -ne "ok") {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}


$Pools_Region_Stratums = @{
    "us-east" = "stratum-us"
    "asia"    = "stratum-apac"
}

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us-west","us-east","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "C64"    ; port = @(6464,6469)                                   ; regions = @("eu","us-east","asia")}
    [PSCustomObject]@{symbol = "DCR"    ; port = @(9332,9336)                                   ; regions = @("eu","us-east","asia")}
    [PSCustomObject]@{symbol = "DGB";   ; port = @(8531)                                        ; regions = @("eu")}
    [PSCustomObject]@{symbol = "FAIR"   ; port = @(3833,3834)                                   ; regions = @("eu","asia")}
	[PSCustomObject]@{symbol = "GAP"    ; port = @(2433)                                        ; regions = @("eu")}
	[PSCustomObject]@{symbol = "GRS"    ; port = @(5544)                                        ; regions = @("eu","us-east")}
    [PSCustomObject]@{symbol = "JUNO"   ; port = @(8383)                                        ; regions = @("eu","us-east")}
    [PSCustomObject]@{symbol = "LPEPE"  ; port = @(3633,3634)                                   ; regions = @("eu","asia")}
    [PSCustomObject]@{symbol = "NPT"    ; port = @([PSCustomObject]@{CPU=@(3832);GPU=@(3833)})  ; regions = @("eu")}
    [PSCustomObject]@{symbol = "OBTC"   ; port = @([PSCustomObject]@{CPU=@(4074);GPU=@(4075)})  ; regions = @("eu")}
    [PSCustomObject]@{symbol = "PXC"    ; port = @(2026,2027)                                   ; regions = @("eu")}
    [PSCustomObject]@{symbol = "QTC"    ; port = @(5555,5557)                                   ; regions = @("eu","us-east","asia")}
	[PSCustomObject]@{symbol = "RIC"    ; port = @(5000)                                        ; regions = @("eu")}
    [PSCustomObject]@{symbol = "RTM"    ; port = @(6273)                                        ; regions = @("eu")}
    [PSCustomObject]@{symbol = "RVN"    ; port = @(8888,8889)                                   ; regions = @("eu")}
    [PSCustomObject]@{symbol = "VTC"    ; port = @(1777,1780)                                   ; regions = @("eu")}
    [PSCustomObject]@{symbol = "XEL"    ; port = @(3333)                                        ; regions = @("eu","us-east","asia")}
    [PSCustomObject]@{symbol = "XNT"    ; port = @([PSCustomObject]@{CPU=@(3832);GPU=@(3833)})  ; regions = @("eu")}
	[PSCustomObject]@{symbol = "ZEC"    ; port = @(3732)                                        ; regions = @("eu")}
    [PSCustomObject]@{symbol = "XMR"    ; port = @(6665,6666)                                   ; regions = @("eu","us-east")}
)

$Pool_Request.pools | Where-Object {-not $_.coming_soon} | Where-Object {$Wallets."$($_.coin.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Fee  = if ($_.mining.pool_fee_percent -eq $null) {$Pool_Fee_Percent} else {[double]$_.mining.pool_fee_percent}

    if (-not ($Pool_Coin = Get-Coin $_.coin.symbol -Algorithm $_.coin.algorithm)) {
        Write-Log -Level Warn "Pool $($Name): missing coin $($_.coin.symbol) in db"
        return
    }

    $Pool_Currency = $Pool_Coin.Symbol
    $Pool_Algorithm_Norm = $Pool_Coin.Algo

    if (-not ($Pool_Data = $Pools_Data | Where-Object {$_.symbol -eq $Pool_Currency})) {
        Write-Log -Level Warn "Pool $($Name): missing coindata $($Pool_Currency)"
        return
    }

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Hashrate = $_.stats.hashrate.pool
    $Pool_Workers  = $_.stats.workers

    foreach ($Pool_Region in $Pool_Data.regions) {
        $Pool_Stratum = "$(if ($Pools_Region_Stratums[$Pool_Region]) {$Pools_Region_Stratums[$Pool_Region]} else {$_.id}).suprnova.cc"
        $Pool_SSL = $false
        foreach ($Port in @($Pool_Data.port | Select-Object)) {
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
                Host          = $Pool_Stratum
                Port          = if ($Port.CPU) {$Port.CPU} else {$Port}
                Ports         = if ($Port.CPU) {$Port} else {$null}
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable[$Pool_Region]
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
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
