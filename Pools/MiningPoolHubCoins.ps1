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

#defines minimum memory required per coin, default is 4gb
$MinMem = [PSCustomObject]@{
    "Expanse"  = "2gb"
    "Soilcoin" = "2gb"
    "Ubiq"     = "2gb"
    "Musicoin" = "3gb"
}

try {
    $Pool_Request = Invoke-RestMethodAsync "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&{timestamp}"
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

$Pool_Request.return | Where-Object {$_.pool_hash -gt 0 -or $InfoOnly} | ForEach-Object {
    $Pool_Host = $_.host
    $Pool_Hosts = $_.host_list.split(";")
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = $_.coin_name
    $Pool_Symbol = Get-CoinSymbol $_.coin_name
    if (-not $Pool_Symbol -and $_.coin_name -match '-') {
        $Pool_Symbol = Get-CoinSymbol ($_.coin_name -split '-' | Select-Object -Index 0)
    }

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaClaymore"} #temp fix

    if ($Pool_Symbol -and $Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Symbol")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    $Divisor = 1000000000

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Coin)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region ($Pool_Region -replace "^us-east$", "us")


        if ($User -or $InfoOnly) {
            $Pool_Algorithm_All | ForEach-Object {
                $Pool_Algorithm_Norm = $_
                [PSCustomObject]@{
                    Algorithm     = "$($Pool_Algorithm_Norm)$(if ($Pool_Algorithm_Norm -EQ "Ethash"){$MinMem.$Pool_Coin})"
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
                }

                [PSCustomObject]@{
                    Algorithm     = "$($Pool_Algorithm_Norm)$(if ($Pool_Algorithm_Norm -EQ "Ethash"){$MinMem.$Pool_Coin})"
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
                }
            }
        }
    }
}