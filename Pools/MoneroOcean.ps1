using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_5",
    [String]$Password = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly -and -not $Wallets.XMR -and -not $Password) {return}

$Pool_Request = [PSCustomObject]@{}
$Pool_RequestNetwork = [PSCustomObject]@{}
$Pool_RequestStats = [PSCustomObject]@{}

try {
    $Pool_Request = (Invoke-RestMethodAsync "https://api.moneroocean.stream/pool/stats/pplns" -tag $Name).pool_statistics
    $Pool_RequestNetwork = Invoke-RestMethodAsync "https://api.moneroocean.stream/network/stats" -tag $Name
    $Pool_RequestStats = Invoke-RestMethodAsync "https://data.miningpoolstats.stream/data/list/moneroocean.stream.js?t={unixtimestamp}" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.portCoinAlgo.PSObject.Properties | Measure-Object).Count -le 10) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_PoolFee = 0.68
$Pools_Data = '{18081:{name:"XMR",active:true,algo_class:"cn/r",divisor:1e12,url:"https://xmrchain.net",time:120},26968:{name:"ETN",active:false,algo_class:"cn/0",divisor:100,url:"https://blockexplorer.electroneum.com",time:120},19734:{name:"SUMO",active:true,algo_class:"cn/r",divisor:1e9,url:"https://explorer.sumokoin.com",time:240},12211:{name:"RYO",active:true,algo_class:"cn/gpu",divisor:1e9,url:"https://explorer.ryo-currency.com",time:240},18981:{name:"GRFT",active:true,algo_class:"cn/rwz",divisor:1e10,url:"https://blockexplorer.graft.network",time:120},38081:{name:"MSR",active:true,algo_class:"cn/half",divisor:1e12,url:"https://msrchain.net",time:60},48782:{name:"LTHN",active:true,algo_class:"cn/r",divisor:1e8,url:"https://lethean.io/explorer",time:120},34568:{name:"WOW",active:true,algo_class:"rx/wow",divisor:1e11,url:"http://explore.wownero.com",time:300},19281:{name:"XMV",active:true,algo_class:"c29v",divisor:1e11,url:"https://explorer.monerov.online",time:60,unit:"G",factor:16},19950:{name:"XWP",active:true,algo_class:"c29s",divisor:1e12,url:"https://explorer.xwp.one",time:15,unit:"G",factor:32},11181:{name:"AEON",active:true,algo_class:"cn-lite/1",divisor:1e12,url:"https://aeonblocks.com",time:240},17750:{name:"XHV",active:true,algo_class:"cn-heavy/xhv",divisor:1e12,url:"https://explorer.havenprotocol.org",time:120},9231:{name:"XEQ",active:true,algo_class:"cn/gpu",divisor:1e4,url:"https://explorer.equilibria.network",time:120},24182:{name:"TUBE",active:true,algo_class:"cn-heavy/tube",divisor:1e8,url:"https://explorer.ipbc.io",time:120},20189:{name:"XLA",active:true,algo_class:"defyx",divisor:100,url:"https://explorer.torque.cash",time:300},22023:{name:"LOKI",active:true,algo_class:"rx/loki",divisor:1e9,url:"https://lokiblocks.com",time:120},33124:{name:"XTNC",active:true,algo_class:"c29s",divisor:1e9,url:"https://explorer.xtendcash.com",time:120,unit:"G",factor:32},11898:{name:"TRTL",active:true,algo_class:"argon2/chukwa",divisor:100,url:"https://explorer.turtlecoin.lol",time:30},13007:{name:"IRD",active:true,algo_class:"cn-pico/trtl",divisor:1e8,url:"https://explorer.ird.cash",time:175},19994:{name:"ARQ",active:true,algo_class:"cn-pico/trtl",divisor:1e9,url:"https://explorer.arqma.com",time:120}}' | ConvertFrom-Json

$Pool_Port_XMR = $Pools_Data.PSObject.Properties | Where-Object {$_.Value.name -eq "XMR"} | Foreach-Object {$_.Name}

$Pools_Data.PSObject.Properties | Where-Object {$Pool_Port=$_.Name;([Double]$Pool_Request.coinProfit.$Pool_Port -gt 0.00 -and ($AllowZero -or [Int]$Pool_Request.portMinerCount.$Pool_Port -gt 0)) -or $InfoOnly} | ForEach-Object {
    $Pool_CoinSymbol = $_.Value.name
    $Pool_Coin = Get-Coin $Pool_CoinSymbol
    $Pool_Algorithm_Norm = $Pool_Coin.Algo

    if (-not $InfoOnly) {
        $Pool_Stats = $Pool_RequestStats.data | Where-Object {$_.symbol -eq $Pool_CoinSymbol}
        $Pool_Factor = if ($_.Value.factor) {$_.Value.factor} else {1}
        $Pool_TSL = if ($Pool_Stats) {$Pool_RequestStats.time - $Pool_Stats.lastblocktime} else {$null}
        $Stat = Set-Stat -Name "$($Name)_$($_.Value.name)_Profit" -Value ($Pool_Request.coinProfit.$Pool_Port*$Pool_Request.price.btc/$Pool_Factor) -Duration $StatSpan -ChangeDetection $false -Difficulty $Pool_RequestNetwork.$Pool_Port.difficulty -HashRate ($Pool_Request.portHash.$Pool_Port*$Pool_Factor) -Quiet
    }

    foreach($Pool_Protocol in @("stratum+tcp","stratum+ssl")) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $_.Value.name
            Currency      = "XMR"
            Price         = $Stat.$StatAverage
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = $Pool_Protocol
            Host          = "gulf.moneroocean.stream"
            Port          = if ($Pool_Protocol -match "ssl") {20001} else {10001}
            User          = "$($Wallets.XMR)"
            Pass          = "{workername:$Worker}:$($Password)~$($Pool_Request.portCoinAlgo.$Pool_Port)"
            Region        = Get-Region "US"
            SSL           = $Pool_Protocol -match "ssl"
            Updated       = $Stat.Updated
            #WTM           = $true
            PoolFee       = $Pool_PoolFee
            Workers       = $Pool_Request.portMinerCount.$Pool_Port
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            #BLK           = $Stat.BlockRate_Average
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.XMR
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}