using module ..\Include.psm1

param(
    [alias("UserName")]
    [String]$User, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHub_Request = [PSCustomObject]@{}
$MiningPoolHubCoins_Request = [PSCustomObject]@{}

try {
    $MiningPoolHub_Request = Invoke-RestMethodAsync "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics&{timestamp}"
    $MiningPoolHubCoins_Request = Invoke-RestMethodAsync "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&{timestamp}"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($MiningPoolHub_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

#temp fix: use additional mining currencies
$MiningPoolHubCoins_Request.return | Where-Object {$_.pool_hash -gt 0 -and @("equihash-btg") -contains $_.algo} | ForEach-Object {
    $MiningPoolHubCoins_Hosts = $_.host_list
    if ($_.algo -eq "equihash-btg") { #temp fix for wrong host url in API
        $MiningPoolHubCoins_Hosts = $_.host_list -replace ".hub.miningpoolhub", ".equihash-hub.miningpoolhub"
    }
    $MiningPoolHub_Request.return += [PSCustomObject]@{
        all_host_list = $MiningPoolHubCoins_Hosts
        algo_switch_port = $_.port
        algo = $_.algo
        current_mining_coin = $_.coin_name
        profit = $_.profit
    }
}

$MiningPoolHub_Regions = "europe", "us-east", "asia"

$MiningPoolHub_Request.return | ForEach-Object {
    $MiningPoolHub_Hosts = $_.all_host_list.split(";")
    $MiningPoolHub_Port = $_.algo_switch_port
    $MiningPoolHub_Algorithm = $_.algo
    $MiningPoolHub_Algorithm_Norm = Get-Algorithm $MiningPoolHub_Algorithm
    $MiningPoolHub_Coin = Get-CoinName $_.current_mining_coin
    $MiningPoolHub_Fee = 0.9 + 0.2
    
    if ($MiningPoolHub_Algorithm_Norm -eq "Sia") {$MiningPoolHub_Algorithm_Norm = "SiaClaymore"} #temp fix

    $Divisor = 1000000000

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $false
    }

    $MiningPoolHub_Regions | ForEach-Object {
        $MiningPoolHub_Region = $_
        $MiningPoolHub_Region_Norm = Get-Region ($MiningPoolHub_Region -replace "^us-east$", "us")

        if ($User -or $InfoOnly) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm_Norm
                CoinName      = $MiningPoolHub_Coin
                Currency      = ""
                Price         = $Stat.Hour #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $MiningPoolHub_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $MiningPoolHub_Fee
            }

            if ($MiningPoolHub_Algorithm_Norm -eq "CryptonightV7" -or $MiningPoolHub_Algorithm_Norm -like "Equihash*") {
                [PSCustomObject]@{
                    Algorithm     = $MiningPoolHub_Algorithm_Norm
                    CoinName      = $MiningPoolHub_Coin
                    Currency      = ""
                    Price         = $Stat.Hour #instead of .Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+ssl"
                    Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                    Port          = $MiningPoolHub_Port
                    User          = "$User.$Worker"
                    Pass          = "x"
                    Region        = $MiningPoolHub_Region_Norm
                    SSL           = $true
                    Updated       = $Stat.Updated
                    PoolFee       = $MiningPoolHub_Fee
                }
            }
        }
    }
}