using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=simplemultialgo.info"
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.result.simplemultialgo | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_Regions = "eu", "usa", "hk", "jp", "in", "br"
$Pool_PoolFee = 2.0

$Pool_Request.result.simplemultialgo | Where-Object {[Double]$_.paying -gt 0.00 -or $InfoOnly} | ForEach-Object {
    $Pool_Host = "nicehash.com"
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.name
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms[$Pool_Algorithm] = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    $Pool_Coin = ""

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaNiceHash"} #temp fix
    if ($Pool_Algorithm_Norm -eq "Decred") {$Pool_Algorithm_Norm = "DecredNiceHash"} #temp fix

    $Divisor = 1000000000

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.paying / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region $Pool_Region

        if ($BTC -or $InfoOnly) {
            @($Pool_Algorithm_Norm,"$($Pool_Algorithm_Norm)-NHMP") | Foreach-Object {
                if ($_ -match "-NHMP") {
                    $This_Port = 3200
                    $This_Host = "nhmp.$Pool_Region.$Pool_Host"
                } else {
                    $This_Port = $Pool_Port
                    $This_Host = "$Pool_Algorithm.$Pool_Region.$Pool_Host"
                }
                [PSCustomObject]@{
                    Algorithm     = $_
                    CoinName      = $Pool_Coin
                    CoinSymbol    = ""
                    Currency      = "BTC"
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Day #instead of .Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = $This_Host
                    Port          = $This_Port
                    User          = "$BTC.$Worker"
                    Pass          = "x"
                    Region        = $Pool_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                }

                if ($_ -like "Cryptonight*" -or $_ -eq "Equihash") {
                    [PSCustomObject]@{
                        Algorithm     = $_
                        CoinName      = $Pool_Coin
                        CoinSymbol    = ""
                        Price         = $Stat.Live
                        StablePrice   = $Stat.Day #instead of .Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+ssl"
                        Host          = $This_Host
                        Port          = $This_Port + 30000
                        User          = "$BTC.$Worker"
                        Pass          = "x"
                        Region        = $Pool_Region_Norm
                        SSL           = $true
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_PoolFee
                    }
                }
            }
        }
    }
}