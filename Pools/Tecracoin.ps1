using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://pool-mtp.tecracoin.io/api/status" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "http://pool-mtp.tecracoin.io/api/currencies" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Info "Pool Currency API ($Name) has failed. "
}

[hashtable]$Pool_RegionsTable = @{}

@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Coin = "Tecracoin"
$Pool_Currency = "TCR"
$Pool_Host = "pool-mtp.tecracoin.io"
$Pool_Algorithm = "MTPTcr"
$Pool_Port = 4556

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$_ -eq "mtp"} | Where-Object {$Pool_Request.$_.hashrate -gt 0 -or $InfoOnly -or $AllowZero} | ForEach-Object {
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees
    $Pool_User = $Wallets.$Pool_Currency

    $Pool_Factor = $Pool_Request.$_.mbtc_mh_factor

    $Pool_TSL = if ($PoolCoins_Request) {$PoolCoins_Request.TCR_MTP.timesincelast}else{$null}
    $Pool_BLK = $PoolCoins_Request.TCR_MTP."24h_blocks"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Actual24h $($Pool_Request.$_.actual_last24h/1000) -Estimate24h $($Pool_Request.$_.estimate_last24h) -HashRate $Pool_Request.$_.hashrate -BlockRate $Pool_BLK -Quiet
    }

    $Pool_Params = if ($Params.$Pool_Currency) {",$($Params.$Pool_Currency)"}

    if ($Pool_User -or $InfoOnly) {
        foreach($Pool_Region in $Pool_RegionsTable.Keys) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_Region).$($Pool_Host)"
                Port          = $Pool_Port
                User          = $Pool_User
                Pass          = "{workername:$Worker},c=$Pool_Currency{diff:,d=`$difficulty}$Pool_Params"
                Region        = $Pool_Regions.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.$_.workers
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $Pool_TSL
				ErrorRatio    = $Stat.ErrorRatio
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
                WTM           = $true
            }
        }
    }
}
