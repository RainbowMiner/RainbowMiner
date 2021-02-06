using module ..\Modules\Include.psm1

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

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics&{timestamp}" -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("europe", "us-east", "asia")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
$Pool_RegionsTable."hub" = $Pool_RegionsTable."us-east"

$Pool_Fee = 0.9 + 0.2

$Pool_Currency = if ($AEcurrency) {$AEcurrency} else {"BTC"}

#temp. fix VTC on port 17032 doesn't work 2021/02/06
$Pool_Request.return | Where-Object {$_.current_mining_coin_symbol -and $_.current_mining_coin_symbol -ne "VTC"} | ForEach-Object {
    $Pool_Hosts     = $_.all_host_list.split(";")
    $Pool_Port      = $_.algo_switch_port
    $Pool_CoinSymbol= $_.current_mining_coin_symbol

    $Pool_Coin      = Get-Coin "$($Pool_CoinSymbol)$(if ($_.current_mining_coin -match '-') {"-$($_.algo)"})"
    if ($Pool_Coin) {
        $Pool_Algorithm = $Pool_Coin.algo
        $Pool_CoinName  = $Pool_Coin.name
    } else {
        $Pool_Algorithm = $_.algo
        $Pool_CoinName  = (Get-Culture).TextInfo.ToTitleCase($_.coin_name -replace "-.+$")
    }

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaClaymore"} #temp fix

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethstratumnh"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Divisor = 1e9

    if ($Pool_CoinSymbol -eq "ZCL") {$Divisor *= 12.5/0.78} #temp fix "tripple halving of ZCL"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $false -FaultDetection $true -FaultTolerance 5 -Quiet
    }

    foreach($Pool_Host in $Pool_Hosts) {
        if ($User -or $InfoOnly) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
				Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $Pool_Host
                Port          = $Pool_Port
                User          = "$User.{workername:$Worker}"
                Pass          = "x{diff:,d=`$difficulty}"
                Region        = $Pool_RegionsTable."$($Pool_Host -replace "\..+$")"
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
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
        }
    }
}