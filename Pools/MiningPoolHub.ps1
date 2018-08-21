using module ..\Include.psm1

param(
    [alias("UserName")]
    [String]$User, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics&{timestamp}" -retry 3 -retrywait 500
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_Regions = "europe", "us-east", "asia"
$Pool_Fee = 0.9 + 0.2

$Pool_Request.return | ForEach-Object {
    $Pool_Hosts = $_.all_host_list.split(";")
    $Pool_Port = $_.algo_switch_port
    $Pool_Algorithm = $_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    if ($_.current_mining_coin) {
        $Pool_Coin = Get-CoinName $_.current_mining_coin
        $Pool_Symbol = Get-CoinSymbol $_.current_mining_coin
        if (-not $Pool_Symbol -and $_.current_mining_coin -match '-') {
            $Pool_Symbol = Get-CoinSymbol ($_.current_mining_coin -replace '\-.*$')
        }
    } else {
        $Pool_Symbol = $Pool_Coin = ''
    }

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaClaymore"} #temp fix

    if ($Pool_Symbol -and $Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Symbol")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}
    
    $Divisor = 1000000000

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $false
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region ($Pool_Region -replace "^us-east$", "us")

        if ($User -or $InfoOnly) {
            $Pool_Algorithm_All | ForEach-Object {
                $Pool_Algorithm_Norm = $_
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = $Pool_Symbol
                    Currency      = ""
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $Pool_Hosts | Sort-Object -Descending {$_ -ilike "$Pool_Region*"} | Select-Object -First 1
                    Port          = $Pool_Port
                    User          = "$User.$Worker"
                    Pass          = "x"
                    Region        = $Pool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                }

                if ($Pool_Algorithm_Norm -eq "CryptonightV7" -or $Pool_Algorithm_Norm -like "Equihash*") {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin
                        Currency      = ""
                        Price         = $Stat.Hour #instead of .Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+ssl"
                        Host          = $Pool_Hosts | Sort-Object -Descending {$_ -ilike "$Pool_Region*"} | Select-Object -First 1
                        Port          = $Pool_Port
                        User          = "$User.$Worker"
                        Pass          = "x"
                        Region        = $Pool_Region_Norm
                        SSL           = $true
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                    }
                }
            }
        }
    }
}