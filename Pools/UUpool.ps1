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
    [String]$StatAverage = "Minute_10",
    [String]$Email = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

[hashtable]$Pool_RegionsTable = @{}

@("CN","EU","US") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = (Invoke-RestMethodAsync "https://uupool.cn/getCoins" -retry 3 -retrywait 500 -tag $Name -cycletime 3600).pow
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or -not ($Pool_Request | Measure-Object).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_DataRequest = [PSCustomObject]@{}
try {
    $Pool_DataRequest = Invoke-RestMethodAsync "https://uupool.cn/api/getAllInfo.php" -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_DataRequest -or ($Pool_DataRequest | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request | Where-Object {$Pool_Currency = $_.coin -replace "(29|31)" -replace "^VDS$","VOLLAR" -replace "^ULORD$","UT";$Wallets.$Pool_Currency -or $Wallets."$($_.coin)" -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $_.algorithm
    $Pool_Algorithm_Norm = Get-Algorithm $_.algorithm
    $Pool_Id = $_.coin.ToLower()

    if ($Pool_DataRequest.$Pool_Id) {
        $hr = $Pool_DataRequest.$Pool_Id.hr  -split "\s+"
        $est= $Pool_DataRequest.$Pool_Id.est -split "[\s/]+"

        $Pool_User   = if ($Wallets.$Pool_Currency) {$Wallets.$Pool_Currency} else {$Wallets."$($_.coin)"}

        $Pool_Hashrate = [Double]$hr[0]  * $(Switch ($hr[1])  {"K" {1e3};"M" {1e6};"G" {1e9};"T" {1e12};"P" {1e15};default {1}})
        $Pool_Estimate = [Double]$est[0] / $(Switch ($est[2]) {"K" {1e3};"M" {1e6};"G" {1e9};"T" {1e12};"P" {1e15};default {1}})

        $lastBTCPrice = if ($Session.Rates.$Pool_Currency) {1/[double]$Session.Rates.$Pool_Currency}
                        elseif ($Session.Rates."$($_.coin)") {1/[double]$Session.Rates."$($_.coin)"}
                        elseif ($_.usd -and $Session.Rates.USD) {$_.usd/$Session.Rates.USD}
                        elseif ($_.cny -and $Session.Rates.CNY) {$_.cny/$Session.Rates.CNY}
                        else {0}

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($Pool_Estimate * $lastBTCPrice) -Duration $StatSpan -HashRate $Pool_Hashrate -ChangeDetection $true -Quiet

        if ($Pool_Hashrate -or $AllowZero -or $InfoOnly) {
            foreach($Pool_Host in @($_.address -split ',')) {
                if ($Pool_Host -match "^(.+?):(\d+)") {
                    [PSCustomObject]@{
                        PoolEstimate  = $Pool_Estimate
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = if ($Pool_DataRequest.$Pool_Id.name) {$Pool_DataRequest.$Pool_Id.name} else {$_.coin}
                        CoinSymbol    = $Pool_Currency
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+tcp"
                        Host          = "$($Matches[1].Trim())"
                        Port          = "$($Matches[2].Trim())"
                        User          = "$($Pool_User).{workername:$Worker}"
                        Pass          = "x"
                        Region        = Switch -Regex ($Pool_Host) {"\(EU\)" {$Pool_RegionsTable.EU};"\(US\)" {$Pool_RegionsTable.US};default {$Pool_RegionsTable.CN}}
                        SSL           = $false
                        Updated       = $Stat.Updated
                        PoolFee       = $_.rates -replace "[^\d\.]+"
                        DataWindow    = $DataWindow
                        Workers       = $Pool_RequestWorkers.data
                        Hashrate      = $Stat.HashRate_Live
                        EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethproxy"} else {$null}
                        AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Wallet        = $Pool_User
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
        }
    }
}
