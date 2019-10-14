using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [alias("UserName")]
    [String]$User,
    [TimeSpan]$StatSpan,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$AEcurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $User -and -not $InfoOnly) {return}

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/miningdutchcoins.json" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request.PSObject.Properties.Name | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

@("americas","asia","eu") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee = 2

$PoolCoins_Request.PSObject.Properties | Where-Object {[int]$_.Value.port -and $_.Value.status -eq "online" -and $_.Value.algorithm -and (([double]$_.Value.poolhashrate -or $AllowZero) -and ($Wallets."$($_.Value.symbol)" -ne $null) -or $InfoOnly)} | ForEach-Object {

    $Pool_Algorithm = $_.Value.algorithm
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Currency = $_.Value.symbol
    $Pool_User = if ($Wallets.$Pool_Currency) {$Wallets.$Pool_Currency} else {$User}
    $Pool_Fee = [double]$_.Value.fee
    $Pool_Port = [int]$_.Value.port
    $Pool_Host = "$($_.Value.algorithm).mining-dutch.nl"

    $Pool_Factor = Switch -Regex ($_.Value.hashes) {
        "^k" {1e3}
        "^M" {1e6}
        "^G" {1e9}
        "^T" {1e12}
        default {1}
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate ([double]$_.Value.poolhashrate * $Pool_Factor) -BlockRate $_.Value.blocks24h -Quiet
    }

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        if ($Pool_User -or $InfoOnly) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.Value.currency
                CoinSymbol    = $Pool_Currency
                Currency      = if ($AECurrency) {$AECurrency} else {$Pool_Currency}
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = "$(if ($Pool_Region -ne "eu") {"$($Pool_Region)."})$($Pool_Host)"
                Port          = $Pool_Port
                User          = "$Pool_User.{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_Fee
                Workers       = [int]$_.Value.poolworkers
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = [int]$_.Value.timesincelast
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethstratumnh"} else {$null}
                WTM           = $true
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