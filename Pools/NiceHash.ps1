using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$Platform = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$Pool_MiningRequest = [PSCustomObject]@{}

if (-not (Test-Path "Variable:Global:NHWallets")) {$Global:NHWallets = [hashtable]@{}}

if (-not $InfoOnly) {
    if (-not $Wallets.BTC) {return}

    if (-not $Global:NHWallets.ContainsKey($Wallets.BTC)) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-GetUrl "https://api2.nicehash.com/main/api/v2/mining/external/$($Wallets.BTC)/rigs2/"
            $Global:NHWallets[$Wallets.BTC] = $Request.externalAddress
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Pool Mining API ($Name) has failed. "
        }
    }
}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info/" -tag $Name -timeout 20
    $Pool_MiningRequest = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/algorithms/" -tag $Name -cycle 3600 -timeout 20
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
[hashtable]$Pool_FailoverRegionsTable = @{}

$Pool_Regions = @("eu", "usa", "hk", "jp", "in", "br")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}
foreach($Pool_Region in $Pool_Regions) {
    $Pool_FailoverRegions = @(Get-Region2 $Pool_RegionsTable.$Pool_Region | Where-Object {$Pool_RegionsTable.ContainsValue($_)})
    [array]::Reverse($Pool_FailoverRegions)
    $Pool_FailoverRegionsTable.$Pool_Region = $Pool_Regions | Where-Object {$_ -ne $Pool_Region} | Sort-Object -Descending {$Pool_FailoverRegions.IndexOf($Pool_RegionsTable.$_)} | Select-Object -Unique -First 3
}

$Pool_PoolFee = if (-not $InfoOnly -and $Global:NHWallets[$Wallets.BTC]) {5.0} else {2.0}

$Grin29_Algorithm = (Get-Coin "GRIN").algo

$Pool_Request.miningAlgorithms | Where-Object {([Double]$_.paying -gt 0.00 -and [Double]$_.speed -gt 0) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $_.algorithm
    $Pool_Data = $Pool_MiningRequest.miningAlgorithms | Where-Object {$_.Enabled -and $_.algorithm -eq $Pool_Algorithm}
    $Pool_Port = $Pool_Data.port

    $Pool_Algorithm = $Pool_Algorithm.ToLower()

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
    $Pool_CoinSymbol = Switch ($Pool_Algorithm_Norm) {
        "Autolykos2"        {"ERG"}
        "BeamHash3"         {"BEAM"}
        "CuckooCycle"       {"AE"}
        "Cuckaroo29"        {"XBG"}
        "Cuckarood29"       {"MWC"}
        "$Grin29_Algorithm" {"GRIN"}
        "Eaglesong"         {"CKB"}
        "EquihashR25x5x3"   {"BEAM"}
        "Lbry"              {"LBC"}
        "RandomX"           {"XMR"}
        "Octopus"           {"CFX"}
    }
    
    $Pool_Coin = if ($Pool_CoinSymbol) {Get-Coin $Pool_CoinSymbol}

    if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaNiceHash"} #temp fix
    if ($Pool_Algorithm_Norm -eq "Decred") {$Pool_Algorithm_Norm = "DecredNiceHash"} #temp fix

    $Pool_EthProxy = $null

    if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
        $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratumnh"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}
    }

    $Pool_Host = ".nicehash.com"

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.paying / 1e8) -Duration $StatSpan -ChangeDetection $true -Quiet
    }

    foreach($Pool_Region in $Pool_Regions) {
        if ($Wallets.BTC -or $InfoOnly) {
            $This_Host = "$Pool_Algorithm.$Pool_Region$Pool_Host"
            $Pool_Failover = @($Pool_FailoverRegionsTable.$Pool_Region | Foreach-Object {"$Pool_Algorithm.$_$Pool_Host"})

            foreach($Pool_Protocol in @("stratum+tcp","stratum+ssl")) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
					Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = "$($Pool_Coin.Name)"
                    CoinSymbol    = "$Pool_CoinSymbol"
                    Currency      = "BTC"
                    Price         = $Stat.$StatAverage
                    StablePrice   = $Stat.$StatAverageStable
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
                    PaysLive      = $true
                    Failover      = @($Pool_Failover | Select-Object | Foreach-Object {
                                        [PSCustomObject]@{
                                            Protocol = $Pool_Protocol
                                            Host     = $_
                                            Port     = $Pool_Port
                                            User     = "$($Wallets.BTC).{workername:$Worker}"
                                            Pass     = "x"
                                        }
                                    })
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
					Disabled      = $false
					HasMinerExclusions = $false
					Price_Bias    = 0.0
					Price_Unbias  = 0.0
                    Wallet        = $Wallets.BTC
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}