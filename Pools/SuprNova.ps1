using module ..\Modules\Include.psm1

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

[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu","us-west","us-east","asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "BCI"     ; rpc = "bci"     ; fee = 1.0; port = 9166}
    [PSCustomObject]@{symbol = "BTG"     ; rpc = "btg"     ; fee = 1.0; port = @(8866,8817)}
    [PSCustomObject]@{symbol = "BUTK-Take2"     ; rpc = "butk-gr"    ; fee = 1.0; port = 8382}
    [PSCustomObject]@{symbol = "BUTK-Lyra2z330" ; rpc = "butk-lyra2" ; fee = 1.0; port = 4020}
	[PSCustomObject]@{symbol = "DASH"    ; rpc = "dash"    ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=@(80,443);host="dash80"})}
    [PSCustomObject]@{symbol = "DGB-Qubit"      ; rpc = "dgbq"       ; fee = 1.0; port = 8531}
    [PSCustomObject]@{symbol = "DGB-Skein"      ; rpc = "dgbs"       ; fee = 1.0; port = 5226}
	[PSCustomObject]@{symbol = "DYN"     ; rpc = "dyn"     ; fee = 1.0; port = 5960}
	[PSCustomObject]@{symbol = "GAP"     ; rpc = "gap"     ; fee = 1.0; port = 2433}
	[PSCustomObject]@{symbol = "GRS"     ; rpc = "grs"     ; fee = 0.0; port = 5544}
    [PSCustomObject]@{symbol = "LUX"     ; rpc = "lux"     ; fee = 1.0; port = 5722}
    [PSCustomObject]@{symbol = "MONA"    ; rpc = "mona"    ; fee = 1.0; port = 2995}
    [PSCustomObject]@{symbol = "OBTC"    ; rpc = "obtc"    ; fee = 1.0; port = [PSCustomObject]@{CPU=4074;GPU=4075}}
	[PSCustomObject]@{symbol = "RIC"     ; rpc = "ric"     ; fee = 1.0; port = 5000}
    [PSCustomObject]@{symbol = "ROI"     ; rpc = "roi"     ; fee = 1.0; port = 4699}
    [PSCustomObject]@{symbol = "RTM"     ; rpc = "rtm"     ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=6273;host="rtm"},[PSCustomObject]@{region="us-east";port=6273;host="stratum.us-ny1"},[PSCustomObject]@{region="us-west";port=6273;host="stratum.us-la1"},[PSCustomObject]@{region="asia";port=6273;host="stratum.apac-hkg1"})}
    [PSCustomObject]@{symbol = "RVN"     ; rpc = "rvn"     ; fee = 0.5; stratum = @([PSCustomObject]@{region="eu";port=8888;host="rvn"},[PSCustomObject]@{region="us-east";port=8855;host="stratum.us-ny1"},[PSCustomObject]@{region="us-west";port=8855;host="stratum.us-la1"},[PSCustomObject]@{region="asia";port=8855;host="stratum.apac-hkg1"})}
    [PSCustomObject]@{symbol = "VTC"     ; rpc = "vtc"     ; fee = 1.0; stratum = @([PSCustomObject]@{region="eu";port=1777;host="vtc"},[PSCustomObject]@{region="us-west";port=1777;host="stratum.us-la1"})}
	[PSCustomObject]@{symbol = "XCN"     ; rpc = "xcn"     ; fee = 1.0; port = 8008}
    [PSCustomObject]@{symbol = "YTN"     ; rpc = "ytn"     ; fee = 1.0; port = 4932}
	[PSCustomObject]@{symbol = "ZEN"     ; rpc = "zen"     ; fee = 1.0; port = @(3618,3621)}
    [PSCustomObject]@{symbol = "ZER"     ; rpc = "zero"    ; fee = 1.0; port = @(6568,6569)}

    #Currently disabled
    #[PSCustomObject]@{symbol = "BEAM"    ; rpc = "beam"    ; fee = 1.0; port = @(7786,7787)}
    #[PSCustomObject]@{symbol = "BTX"     ; rpc = "btx"     ; fee = 1.0; port = 3629}
    #[PSCustomObject]@{symbol = "BSD"     ; rpc = "bsd"     ; fee = 1.0; port = 8686}
    #[PSCustomObject]@{symbol = "ERC"     ; rpc = "erc"     ; fee = 1.0; port = 7674}
    #[PSCustomObject]@{symbol = "GRLC"    ; rpc = "grlc"    ; fee = 1.0; port = 8600}
    #[PSCustomObject]@{symbol = "HODL"    ; rpc = "hodl"    ; fee = 1.0; port = 4693}
    #[PSCustomObject]@{symbol = "MNX"     ; rpc = "mnx"     ; fee = 1.0; port = @(7077,7078)}
    #[pscustomobject]@{symbol = "VEIL"    ; rpc = "veil"    ; fee = 1.0; port = 7220}
    #[pscustomobject]@{symbol = "XVG-X17" ; rpc = "xvg-x17" ; fee = 1.0; port = 7477}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol -replace "-.+")" -or $InfoOnly} | ForEach-Object {
    $Pool_Fee  = $_.fee
    $Pool_Coin = Get-Coin $_.symbol
    $Pool_Currency = $Pool_Coin.Symbol
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
