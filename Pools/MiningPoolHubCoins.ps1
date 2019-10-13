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

$Pool_Request = [PSCustomObject]@{}

#defines minimum memory required per coin, default is 4gb
$MinMem = [PSCustomObject]@{
    "Expanse"  = "2gb"
    "Soilcoin" = "2gb"
    "Ubiq"     = "2gb"
    "Musicoin" = "3gb"
}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&{timestamp}" -tag $Name -cycletime 120
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

@("europe", "us-east", "asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Fee = 0.9 + 0.2

$Pool_Currency = if ($AEcurrency) {$AEcurrency} else {"BTC"}

$Pool_Request.return | Where-Object {($_.pool_hash -ne '-' -and $_.pool_hash) -or $InfoOnly -or $AllowZero} | ForEach-Object {
    $Pool_Host = $_.host
    $Pool_Hosts = $_.host_list.split(";")
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = $_.coin_name
    $Pool_Symbol = Get-CoinSymbol $_.coin_name
    if (-not $Pool_Symbol -and $_.coin_name -match '-') {
        $Pool_Symbol = Get-CoinSymbol ($_.coin_name -split '-' | Select-Object -Index 0)
    }

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaClaymore"} #temp fix

    if ($Pool_Symbol -and $Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Symbol")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Divisor = 1e9

    $Pool_Hashrate = $_.pool_hash
    if ($Pool_Hashrate -match "^([\d\.]+)([KMGTP])$") {
        $Pool_Hashrate = [double]$Matches[1]
        Switch($Matches[2]) {
            "K" {$Pool_Hashrate *= 1e3}
            "M" {$Pool_Hashrate *= 1e6}
            "G" {$Pool_Hashrate *= 1e9}
            "T" {$Pool_Hashrate *= 1e12}
            "P" {$Pool_Hashrate *= 1e15}
        }
    } elseif ($Pool_Hashrate -notmatch "^[\d\.]+$") {$Pool_Hashrate = 0}

    $Pool_Hashrate = [int64]$Pool_Hashrate
    $Pool_TSL = if ($_.time_since_last_block -eq "-") {$null} else {[int64]$_.time_since_last_block}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Coin)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true -HashRate $Pool_HashRate -FaultDetection $true -FaultTolerance 5 -Quiet
    }

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        if ($User -or $InfoOnly) {
            foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
                $Pool_Algorithm1 = "$($Pool_Algorithm_Norm)$(if ($Pool_Algorithm_Norm -EQ "Ethash"){$MinMem.$Pool_Coin})"
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm1
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_Symbol
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $Pool_Hosts | Sort-Object -Descending {$_ -ilike "$Pool_Region*"} | Select-Object -First 1
                    Port          = $Pool_Port
                    User          = "$User.{workername:$Worker}"
                    Pass          = "x{diff:,d=`$difficulty}"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethstratumnh"} else {$null}
                    AlgorithmList = if ($Pool_Algorithm1 -match "-") {@($Pool_Algorithm1, ($Pool_Algorithm1 -replace '\-.*$'))}else{@($Pool_Algorithm1)}
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Wallet        = $Wallets.$Pool_Currency
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }

                if ($Pool_Algorithm_Norm -like "Cryptonight*" -or $Pool_Algorithm_Norm -like "Equihash*") {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm1
                        CoinName      = $Pool_Coin
                        CoinSymbol    = $Pool_Symbol
                        Currency      = $Pool_Currency
                        Price         = $Stat.$StatAverage #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+ssl"
                        Host          = $Pool_Hosts | Sort-Object -Descending {$_ -ilike "$Pool_Region*"} | Select-Object -First 1
                        Port          = $Pool_Port
                        User          = "$User.{workername:$Worker}"
                        Pass          = "x{diff:,d=`$difficulty}"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $true
                        Updated       = $Stat.Updated                        
                        PoolFee       = $Pool_Fee
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_TSL
                        AlgorithmList = if ($Pool_Algorithm1 -match "-") {@($Pool_Algorithm1, ($Pool_Algorithm1 -replace '\-.*$'))}else{@($Pool_Algorithm1)}
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Wallet        = $Wallets.$Pool_Currency
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
            }
        }
    }
}