using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_5"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.nicehash.com/api?method=simplemultialgo.info" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.result.simplemultialgo | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu", "usa", "hk") #, "jp", "in", "br")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_PoolFee = 2.0

$Pool_Request.result.simplemultialgo | Where-Object {([Double]$_.paying -gt 0.00) -or $InfoOnly} | ForEach-Object {
    $Pool_Host = "nicehash.com"
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.name
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = ""

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaNiceHash"} #temp fix
    if ($Pool_Algorithm_Norm -eq "Decred") {$Pool_Algorithm_Norm = "DecredNiceHash"} #temp fix

    $Divisor = 1e9

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.paying / $Divisor) -Duration $StatSpan -ChangeDetection $true -Quiet
    }

    $Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$($Pool_Algorithm_Norm)-NHMP")

    foreach($Pool_Region in $Pool_Regions) {
        if ($Wallets.BTC -or $InfoOnly) {
            foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
                if ($Pool_Algorithm_Norm -match "-NHMP") {
                    $This_Port = 3200
                    $This_Host = "nhmp.$Pool_Region.$Pool_Host"
                } else {
                    $This_Port = $Pool_Port
                    $This_Host = "$Pool_Algorithm.$Pool_Region.$Pool_Host"
                }
                if ($Pool_Algorithm_Norm -ne "Equihash25x5" -or $Pool_Region -ne "eu") {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
                        CoinName      = $Pool_Coin
                        CoinSymbol    = ""
                        Currency      = "BTC"
                        Price         = $Stat.$StatAverage
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+tcp"
                        Host          = $This_Host
                        Port          = $This_Port
                        User          = "$($Wallets.BTC).{workername:$Worker}"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable.$Pool_Region
                        SSL           = $false
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_PoolFee
                        PPS           = $true
                    }

                    if (@("CryptonightV7","Equihash","Equihash25x5") -icontains $Pool_Algorithm_Norm) {
                        [PSCustomObject]@{
                            Algorithm     = $Pool_Algorithm_Norm
                            CoinName      = $Pool_Coin
                            CoinSymbol    = ""
                            Currency      = "BTC"
                            Price         = $Stat.Minute_5
                            StablePrice   = $Stat.Day #instead of .Week
                            MarginOfError = $Stat.Week_Fluctuation
                            Protocol      = "stratum+ssl"
                            Host          = $This_Host
                            Port          = $This_Port + 30000
                            User          = "$($Wallets.BTC).{workername:$Worker}"
                            Pass          = "x"
                            Region        = $Pool_RegionsTable.$Pool_Region
                            SSL           = $true
                            Updated       = $Stat.Updated
                            PoolFee       = $Pool_PoolFee
                            PPS           = $true
                        }
                    }
                }
            }
        }
    }
}