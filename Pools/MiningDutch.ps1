using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [alias("UserName")]
    [String]$User,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$AEcurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $User -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}

$headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.mining-dutch.nl/api/status/" -retry 3 -retrywait 500 -tag $Name -cycletime 120 -headers $headers
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request.PSObject.Properties.Name | Measure-Object).Count -le 5) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

@("americas","asia","eu") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee = 2

$Pool_Currency = if ($AEcurrency) {$AEcurrency} else {"BTC"}

$Pool_Request.PSObject.Properties | Where-Object {[int]$_.Value.workers_shared -gt 0 -or $AllowZero} | ForEach-Object {

    $Pool_Algorithm = $_.Value.name
    $Pool_Algorithm_Norm = Get-Algorithm $_.Value.name
    $Pool_Coin = ''
    $Pool_Fee = [double]$_.Value.fees
    $Pool_Symbol = ''
    $Pool_Port = [int]$_.Value.port
    $Pool_Host = "$($_.Value.name).mining-dutch.nl"
        
    $Pool_Factor = [double]$_.Value.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    #$Pool_TSL = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object timesincelast_shared -Minimum).Minimum
    #$Pool_BLK = ($PoolCoins_Request.PSObject.Properties.Value | Where-Object algo -eq $Pool_Algorithm | Measure-Object "24h_blocks_shared" -Maximum).Maximum

    if (-not $InfoOnly) {
        $Pool_Price = Get-YiiMPValue $_.Value -DataWindow $DataWindow -Factor $Pool_Factor -ActualDivisor 1
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $StatSpan -ChangeDetection $false -FaultDetection $true -FaultTolerance 5 -HashRate ([double]$_.Value.hashrate_shared * 1e6) -BlockRate $Pool_BLK -Quiet
    }

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        if ($User -or $InfoOnly) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin
                CoinSymbol    = $Pool_Symbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$(if ($Pool_Region -ne "eu") {"$($Pool_Region)."})$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$User.{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                DataWindow    = $DataWindow
                Workers       = [int]$_.Value.workers_shared
                Hashrate      = $Stat.HashRate_Live
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethstratumnh"} else {$null}
                AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}