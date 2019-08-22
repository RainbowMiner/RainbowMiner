using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_5",
    [String]$Platform = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

$Platform_Version = 2

if (-not $InfoOnly) {
    if (-not $Wallets.BTC) {return}
}

if ($Platform_Version -eq 2) {
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info/" -tag $Name
        $Pool_MiningRequest = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/algorithms/" -tag $Name -cycle 3600
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }

    if (($Pool_Request.miningAlgorithms | Measure-Object).Count -le 10 -or ($Pool_MiningRequest.miningAlgorithms | Measure-Object).Count -le 10) {
        Write-Log -Level Warn "Pool API ($Name) returned nothing. "
        return
    }
    $Pool_MiningRequest.miningAlgorithms | Where-Object {$_.Enabled} | Foreach-Object {
        $Pool_Port = $_.port
        $Pool_Algo = $_.algorithm
        $Pool_Request.miningAlgorithms | Where-Object algorithm -eq $Pool_Algo | Foreach-Object {$_ | Add-Member port $Pool_Port -Force}
    }

    $Pool_Request = $Pool_Request.miningAlgorithms

} else {
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

    $Pool_Request = $Pool_Request.result.simplemultialgo
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("eu", "usa", "hk") #, "jp", "in", "br")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_PoolFee = 2.0

$Pool_Request | Where-Object {([Double]$_.paying -gt 0.00 -and ($Platform_Version -lt 2 -or [Double]$_.speed -gt 0)) -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = if ($_.name) {$_.name} else {$_.algorithm.ToLower()}
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    if ($Pool_Algorithm -eq "beam") {$Pool_Algorithm_Norm = "EquihashR25x5"}
    $Pool_Coin = ""

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaNiceHash"} #temp fix
    if ($Pool_Algorithm_Norm -eq "Decred") {$Pool_Algorithm_Norm = "DecredNiceHash"} #temp fix

    Switch($Platform_Version) {
        1 {$Divisor = 1e9; $Pool_Host = ".nicehash.com"}
        2 {$Divisor = 1e8; $Pool_Host = "-new.nicehash.com"}
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.paying / $Divisor) -Duration $StatSpan -ChangeDetection $true -Quiet
    }

    $Pool_Algorithm_All = @($Pool_Algorithm_Norm) #,"$($Pool_Algorithm_Norm)-NHMP")

    foreach($Pool_Region in $Pool_Regions) {
        if ($Wallets.BTC -or $InfoOnly) {
            foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
                if ($Pool_Algorithm_Norm -match "-NHMP") {
                    $This_Port = 3200
                    $This_Host = "nhmp.$Pool_Region.$Pool_Host"
                } else {
                    $This_Port = $Pool_Port
                    $This_Host = "$Pool_Algorithm.$Pool_Region$Pool_Host"
                }
                $Pool_Failover = @($Pool_Regions | Where-Object {$_ -ne $Pool_Region} | Foreach-Object {if ($Pool_Algorithm_Norm -match "-NHMP") {"nhmp.$_.$Pool_Host"} else {"$Pool_Algorithm.$_$Pool_Host"}})
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
                    Failover      = @($Pool_Failover | Select-Object | Foreach-Object {
                        [PSCustomObject]@{
                            Protocol = "stratum+tcp"
                            Host     = $_
                            Port     = $This_Port
                            User     = "$($Wallets.BTC).{workername:$Worker}"
                            Pass     = "x"
                        }
                    })
                    EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethstratumnh"} else {$null}
                }

                if (@("Cryptonight","Equihash","Equihash25x5") -icontains $Pool_Algorithm_Norm) {
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
                        Failover      = @($Pool_Failover | Select-Object | Foreach-Object {
                            [PSCustomObject]@{
                                Protocol = "stratum+ssl"
                                Host     = $_
                                Port     = $This_Port + 30000
                                User     = "$($Wallets.BTC).{workername:$Worker}"
                                Pass     = "x"
                            }
                        })
                    }
                }
            }
        }
    }
}