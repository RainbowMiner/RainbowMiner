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

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us-west","us-east","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "C64"      ; rpc = "c64"     ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=@(6464,6469);host="c64"},[PSCustomObject]@{region="us-east";port=@(6464,6469);host="stratum-us"},[PSCustomObject]@{region="asia";port=@(6464,6469);host="stratum-apac"})}
    [PSCustomObject]@{symbol = "DCR"      ; rpc = "dcr"     ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=@(9332,9336);host="dcr"},[PSCustomObject]@{region="us-east";port=@(9332,9336);host="stratum-us"},[PSCustomObject]@{region="asia";port=@(9332,9336);host="stratum-apac"})}
    [PSCustomObject]@{symbol = "DGB-Qubit"; rpc = "dgbq"    ; fee = 1.0; port = 8531}
    [PSCustomObject]@{symbol = "FAIR"     ; rpc = "fair"    ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=@(3833,3834);host="fair"},[PSCustomObject]@{region="asia";port=@(3833,3834);host="stratum-apac"})}
	[PSCustomObject]@{symbol = "GAP"      ; rpc = "gap"     ; fee = 1.0; port = 2433}
	[PSCustomObject]@{symbol = "GRS"      ; rpc = "grs"     ; fee = 0.0; stratum = @([PSCustomObject]@{region="eu";port=5544;host="grs"},[PSCustomObject]@{region="us-east";port=5544;host="stratum-us"})}
    [PSCustomObject]@{symbol = "JUNO"     ; rpc = "juno"    ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=8383;host="juno"},[PSCustomObject]@{region="us-east";port=8383;host="stratum-us"})}
    [PSCustomObject]@{symbol = "LPEPE"    ; rpc = "lpepe"   ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=@(3633,3634);host="lpepe"},[PSCustomObject]@{region="asia";port=@(3633,3634);host="stratum-apac"})}
    [PSCustomObject]@{symbol = "OBTC"     ; rpc = "obtc"    ; fee = 1.0; port = [PSCustomObject]@{CPU=4074;GPU=4075}}
    [PSCustomObject]@{symbol = "PXC"      ; rpc = "pxc"     ; fee = 1.0; port = @(2026,2027)}
	[PSCustomObject]@{symbol = "RIC"      ; rpc = "ric"     ; fee = 1.0; port = 5000}
    [PSCustomObject]@{symbol = "RTM"      ; rpc = "rtm"     ; fee = 1.0; port = 6273}
    [PSCustomObject]@{symbol = "RVN"      ; rpc = "rvn"     ; fee = 0.5; port = @(8888,8889)}
    [PSCustomObject]@{symbol = "VTC"      ; rpc = "vtc"     ; fee = 1.0; port = @(1777,1780)}
    [PSCustomObject]@{symbol = "XEL"      ; rpc = "xel"     ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=3333;host="xel"},[PSCustomObject]@{region="us-east";port=3333;host="stratum-us"},[PSCustomObject]@{region="asia";port=3333;host="stratum-apac"})}
	[PSCustomObject]@{symbol = "ZEC"      ; rpc = "zec"     ; fee = 1.0; port = 3732}
    [PSCustomObject]@{symbol = "XMR"      ; rpc = "xmr"     ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=@(6665,6666);host="xmr"},[PSCustomObject]@{region="us-east";port=@(6665,6666);host="stratum-us"})}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol -replace "-.+")" -or $InfoOnly} | ForEach-Object {
    $Pool_Fee  = $_.fee
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Currency = $Pool_Coin.Symbol
    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

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
            Write-Log -Level Warn "Pool API ($Name) for $($_.symbol) has failed. "        
        }
    }

    if ($_.stratum) {
        $Pool_Stratums = $_.stratum
    } else {
        $Pool_Stratums = @([PSCustomObject]@{region="eu";port=$_.port;host=$_.rpc})
    }

    foreach ($Pool_Stratum in $Pool_Stratums) {
        $Pool_SSL = $false
        foreach ($Port in @($Pool_Stratum.port | Select-Object)) {
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
                Host          = "$($Pool_Stratum.host).suprnova.cc"
                Port          = if ($Port.CPU) {$Port.CPU} else {$Port}
                Ports         = if ($Port.CPU) {$Port} else {$null}
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable[$Pool_Stratum.region]
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
