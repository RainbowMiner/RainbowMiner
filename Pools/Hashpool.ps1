using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

$ok = $false
try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://hashpool.com/api/coins" -tag $Name -cycletime 120
    if ($PoolCoins_Request.code -eq 0 -and ($PoolCoins_Request.data | Measure-Object).Count) {$ok = $true}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_DefaultRegion = Get-Region "Asia"
	
$Pools_Data =  @(
    [PSCustomObject]@{symbol = "TRB"; port = 8208; fee = 5.0; rpc = "pplns.trb"}
    #[PSCustomObject]@{symbol = "TRB"; port = 8208; fee = 5.0; rpc = "solo.trb"}
    [PSCustomObject]@{symbol = "HNS"; port = 6000; fee = 1.0; rpc = "hns"}
    [PSCustomObject]@{symbol = "FCH"; port = 3001; fee = 1.0; rpc = "fch"}
    [PSCustomObject]@{symbol = "KDA"; port = 3700; fee = 1.0; rpc = "kda"}
    [PSCustomObject]@{symbol = "CKB"; port = 4300; fee = 1.0; rpc = "ckb"}
    [PSCustomObject]@{symbol = "BST"; port = 3335; fee = 0.0; rpc = "bst"}
    [PSCustomObject]@{symbol = "NXS"; port = 9012; fee = 1.0; rpc = "nxs"}
    [PSCustomObject]@{symbol = "HDAC"; port = 5770; fee = 1.0; rpc = "hdac"}
    [PSCustomObject]@{symbol = "DGBODO"; port = 11116; fee = 0.0; rpc = "dgbodo"; algo = "Odocrypt"}
    [PSCustomObject]@{symbol = "BSHA3"; port = 21879; fee = 0.0; rpc = "bsha3"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol -replace "DGBODO","DGB")" -or $InfoOnly} | ForEach-Object {

    $Pool_CoinSymbol = $_.symbol
    $Pool_Currency   = $_.symbol -replace "DGBODO","DGB"

    $Pool_Data = $PoolCoins_Request.data | Where-Object {$_.coin -eq $Pool_CoinSymbol}

    if (-not $Pool_Data) {return}

    $Pool_Coin = Get-Coin "$($Pool_Currency)$(if ($_.algo) {"-$($_.algo)"})"

    if (-not $Pool_Coin) {Write-Log -Level Warn "Coin $Pool_Currency not found"; return}

    $Pool_Port = $_.port
    $Pool_Fee  = if ($Pool_Data.fee -ne $null) {$Pool_Data.fee} else {$_.fee}

    $Pool_Algorithm = $Pool_Coin.Algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Pool_DataWindow = $DataWindow

    $Pool_TSL = Get-UnixTimestamp
    $Pool_BLK = $null

    if (-not $InfoOnly) {
        $ok = $false
        try {
            $PoolBlocks_Request = Invoke-RestMethodAsync "https://hashpool.com/api/blocks/$($Pool_Currency)?offset=0&limit=50" -tag $Name -cycletime 120
            if ($PoolBlocks_Request.code -ne $null -and $PoolBlocks_Request.code -eq 0) {$ok = $true}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
        if ($ok) {
            $blocks = $PoolBlocks_Request.data.data | Select-Object -ExpandProperty dateTime | Sort-Object -Descending
            if (($blocks | Measure-Object).Count) {
                $timestamp24h = $Pool_TSL - 24*3600
                $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
                $Pool_TSL = if ($Pool_TSL -gt $blocks[0]/1000) {$Pool_TSL - $blocks[0] / 1000} else {0}
                $Pool_BLK  = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600000/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
            }
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate (ConvertFrom-Hash "$($Pool_Data.poolHashrate)$($Pool_Data.poolHashrateUnit)") -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
        Algorithm0    = $Pool_Algorithm_Norm
        CoinName      = $Pool_Coin.Name
        CoinSymbol    = $Pool_Currency
        Currency      = $Pool_Currency
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "stratum+tcp"
        Host          = "$($_.rpc).stratum.hashpool.com"
        Port          = $Pool_Port
        User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
        Pass          = "x{diff:,d=`$difficulty}"
        Region        = $Pool_DefaultRegion
        SSL           = $false
        Updated       = (Get-Date).ToUniversalTime()
        PoolFee       = $Pool_Fee
        DataWindow    = $Pool_DataWindow
        Hashrate      = $Stat.HashRate_Live
        BLK           = $Stat.BlockRate_Average
        TSL           = $Pool_TSL
		ErrorRatio    = $Stat.ErrorRatio
        WTM           = $true
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_0       = 0.0
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = $Pool_User
        Worker        = "{workername:$Worker}"
        Email         = $Email
    }
}
