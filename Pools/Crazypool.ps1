using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
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

$Pool_Regions = @("sg","eu","us")

[hashtable]$Pool_RegionsTable = @{}
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{rpc = "etc.crazypool.org";  symbol = "ETC";  port = @(7000,7777);   fee = 1; region = $Pool_Regions; region_prefix = "etc-"}
    [PSCustomObject]@{rpc = "ethw.crazypool.org"; symbol = "ETHW"; port = @(3333,5555);   fee = 1; region = $Pool_Regions; region_prefix = "ethw-"}
    [PSCustomObject]@{rpc = "kas.crazypool.org";  symbol = "KAS";  port = @(25101);       fee = 1; region = $Pool_Regions; region_prefix = "kas-"}
    [PSCustomObject]@{rpc = "lrs.crazypool.org";  symbol = "LRS";  port = @(25001,26001); fee = 1; region = $Pool_Regions; region_prefix = "lrs-"}
    [PSCustomObject]@{rpc = "octa.crazypool.org"; symbol = "OCTA"; port = @(5225,5885);   fee = 1; region = $Pool_Regions; region_prefix = "octa-"}
    #[PSCustomObject]@{rpc = "pac.crazypool.org";  symbol = "PAC";  port = @();            fee = 1; region = $Pool_Regions; region_prefix = "pac-"}
    [PSCustomObject]@{rpc = "sdr.crazypool.org";  symbol = "SDR";  port = @(25101);       fee = 1; region = $Pool_Regions; region_prefix = "sdr-"}
    [PSCustomObject]@{rpc = "zil.crazypool.org";  symbol = "ZIL";  port = @(5005,5995);   fee = 1; region = $Pool_Regions; region_prefix = "zil-"}
    [PSCustomObject]@{rpc = "zth.crazypool.org";  symbol = "ZTH";  port = @(25002,26002); fee = 1; region = $Pool_Regions; region_prefix = "zth-"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin  = Get-Coin $_.symbol
    $Pool_Ports = $_.port
    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_Currency = $_.symbol

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratum"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request = [PSCustomObject]@{}
    $PoolBlocks_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {

        $ok = $false
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/stats" -tag $Name -cycletime 120 -fixbigint
            if ($Pool_Request.now) {
                $PoolBlocks_Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/blocks" -tag $Name -cycletime 120 -fixbigint
                $ok = $PoolBlocks_Request.luck -ne $null
            }
        }
        catch {
        }
        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) has failed for $($Pool_Currency)"
            return
        }

        $timestamp      = Get-UnixTimestamp
        $timestamp24h   = $timestamp - 24*3600

        $Pool_TSL       = $timestamp - $Pool_Request.stats.lastBlockFound
        
        $blocks         = @($PoolBlocks_Request.matured.timestamp | Where-Object {$_ -ge $timestamp24h}) + @($PoolBlocks_Request.immature.timestamp | Where-Object {$_ -ge $timestamp24h}) | Sort-Object -Descending
        $blocks_measure = $blocks | Measure-Object -Minimum -Maximum
        $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count) 

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    foreach($Pool_Region in $_.region) {
        if ($Pool_Currency -ne "ZIL" -or $EnableBzminerDual -or $EnableGminerDual -or $EnableMiniZDual -or $EnableSrbminerMultiDual -or $EnableOneZeroMinerDual -or $EnableTTminerDual -or $EnableRigelDual) {
            $Pool_Ssl = $false
            foreach($Pool_Port in $Pool_Ports) {
                [PSCustomObject]@{
                    Algorithm     = "$(if ($Pool_Currency -eq "ZIL") {"ZilliqaCP"} else {$Pool_Algorithm_Norm})"
                    Algorithm0    = "$(if ($Pool_Currency -eq "ZIL") {"ZilliqaCP"} else {$Pool_Algorithm_Norm})"
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = if ($Pool_Currency -eq "ZIL") {1e-15} else {0}
                    StablePrice   = if ($Pool_Currency -eq "ZIL") {1e-15} else {0}
                    MarginOfError = 0
                    Protocol      = "stratum+$(if ($Pool_Ssl) {"ssl"} else {"tcp"})"
                    Host          = "$($_.region_prefix)$($Pool_Region).crazypool.org"
                    Port          = $Pool_Port
                    User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_Ssl
                    Updated       = (Get-Date).ToUniversalTime()
                    PoolFee       = $_.fee
                    DataWindow    = $DataWindow
                    Workers       = $Pool_Request.minersTotal
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    WTM           = $Pool_Currency -ne "ZIL"
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
                $Pool_Ssl = $true
            }
        }
    }
}
