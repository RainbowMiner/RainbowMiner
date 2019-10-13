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

if (-not $InfoOnly) {
    if (-not $Wallets.BTC) {return}
    if ($Platform -notin @("2","v2","new")) {
        Write-Log -Level Warn "Nicehash has disabled it's old platform. Please update your Nicehash wallet and set `"Platform`" to `"v2`", in your pools.config.txt"
        return
    }
}

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

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

@("eu", "usa", "hk", "jp", "in", "br") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_PoolFee = 2.0

$Pool_Request.miningAlgorithms | Where-Object {([Double]$_.paying -gt 0.00) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $_.algorithm
    $Pool_Data = $Pool_MiningRequest.miningAlgorithms | Where-Object {$_.Enabled -and $_.algorithm -eq $Pool_Algorithm}
    $Pool_Port = $Pool_Data.port

    $Pool_Algorithm = $Pool_Algorithm.ToLower()

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_Coin = ""

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaNiceHash"} #temp fix
    if ($Pool_Algorithm_Norm -eq "Decred") {$Pool_Algorithm_Norm = "DecredNiceHash"} #temp fix

    $Pool_Host = ".nicehash.com"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.paying / 1e8) -Duration $StatSpan -ChangeDetection $true -Quiet
    }

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        if ($Wallets.BTC -or $InfoOnly) {
            $This_Host = "$Pool_Algorithm.$Pool_Region$Pool_Host"
            $Pool_Failover = @($Pool_RegionsTable.Keys | Where-Object {$_ -ne $Pool_Region} | Foreach-Object {"$Pool_Algorithm.$_$Pool_Host"})
            foreach($Pool_Protocol in @("stratum+tcp","stratum+ssl")) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin
                    CoinSymbol    = ""
                    Currency      = "BTC"
                    Price         = $Stat.$StatAverage
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Protocol
                    Host          = $This_Host
                    Port          = $Pool_Port
                    User          = "$($Wallets.BTC).{workername:$Worker}"
                    Pass          = "x"
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $Pool_Protocol -match "ssl"
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    PPS           = $true
                    Failover      = @($Pool_Failover | Select-Object | Foreach-Object {
                        [PSCustomObject]@{
                            Protocol = $Pool_Protocol
                            Host     = $_
                            Port     = $Pool_Port
                            User     = "$($Wallets.BTC).{workername:$Worker}"
                            Pass     = "x"
                        }
                    })
                    EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"ethstratumnh"} else {$null}
                    AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
                    Wallet        = $Wallets.BTC
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}