using module ..\Modules\Include.psm1

param(
    [String]$Name,
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

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$Pool_MiningRequest = [PSCustomObject]@{}

$Pool_Wallet = $Wallets.BTC

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/public/stats/global/current" -tag $Name -timeout 20
    #$Pool_Request = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info" -tag $Name -timeout 20
    $Pool_MiningRequest = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/mining/algorithms/" -tag $Name -cycle 3600 -timeout 20
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request.algos | Measure-Object).Count -le 10 -or ($Pool_MiningRequest.miningAlgorithms | Measure-Object).Count -le 10) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_PoolFee = 2.0

$Pool_Request.algos | Where-Object {([Double]$_.p -gt 0.00 -and [Double]$_.s -gt 0) -or $InfoOnly} | ForEach-Object {
    $Pool_Algo_Id   = $_.a
    $Pool_Data      = $Pool_MiningRequest.miningAlgorithms | Where-Object {$_.Enabled -and $_.order -eq $Pool_Algo_Id}

    if (-not $Pool_Data) {return}

    $Pool_Algorithm = $Pool_Data.algorithm.ToLower()

    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    if (-not $InfoOnly -and (($Algorithm -and $Pool_Algorithm_Norm -notin $Algorithm) -or ($ExcludeAlgorithm -and $Pool_Algorithm_Norm -in $ExcludeAlgorithm))) {return}

    #if ($Pool_Algorithm_Norm -eq "Sia") {$Pool_Algorithm_Norm = "SiaNiceHash"} #temp fix
    #if ($Pool_Algorithm_Norm -eq "Decred") {$Pool_Algorithm_Norm = "DecredNiceHash"} #temp fix

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$_.p / 1e8) -Duration $StatSpan -HashRate ([Double]$_.s) -ChangeDetection $true -Quiet
    }

    if (($Pool_Wallet -and [int]$_.o -gt 0) -or $InfoOnly) {

        $Pool_CoinSymbol = Switch ($Pool_Algorithm_Norm) {
            "BeamHash3"         {"BEAM"}
            "Blake3Alephium"    {"ALPH"}
            "CuckooCycle"       {"AE"}
            "Eaglesong"         {"CKB"}
            "Fishhash"          {"IRON"}
            "HeavyHashPyrin"    {"PYI"}
            "Lbry"              {"LBC"}
            "NexaPow"           {"NEXA"}
            "RandomX"           {"XMR"}
            "Octopus"           {"CFX"}
            "Verushash"         {"VRSC"}
        }
    
        $Pool_Coin = if ($Pool_CoinSymbol) {Get-Coin $Pool_CoinSymbol}

        $Pool_EthProxy = $Pool_DagSizeMax = $Pool_CoinSymbolMax = $null

        if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {
            $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratumnh"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}
            if (-not $Pool_CoinSymbol) {
                $Pool_CoinSymbolMax = Switch ($Pool_Algorithm_Norm) {
                    "Etchash" {"ETC"}
                    "Ethash"  {"ETHW"}
                    "KawPow"  {"RVN"}
                }
                if ($Pool_CoinSymbolMax) {
                    $Pool_DagSizeMax = Get-EthDAGSize -Algorithm $Pool_Algorithm -CoinSymbol $Pool_CoinSymbolMax
                }
            }
        }

        $Pool_IsEthash = $Pool_Algorithm_Norm -match "^Etc?hash"

        $Pool_Host      = "$($Pool_Algorithm).auto.nicehash.com"

        foreach($Pool_SSL in @($false,$true)) {
            if ($Pool_SSL) {
                $Pool_Protocol = "stratum+ssl"
                $Pool_Port     = 443
            } else {
                $Pool_Protocol = "stratum+tcp"
                $Pool_Port     = 9200
            }
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
                Host          = $Pool_Host
                Port          = $Pool_Port
                User          = "$($Pool_Wallet).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                Workers       = $null
                Hashrate      = $Stat.HashRate_Live
                TSL           = $null
                BLK           = $null
                PaysLive      = $true
                EthMode       = $Pool_EthProxy
                CoinSymbolMax = $Pool_CoinSymbolMax
                DagSizeMax    = $Pool_DagSizeMax
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
				Disabled      = $false
				HasMinerExclusions = $false
                Price_0       = 0.0
				Price_Bias    = 0.0
				Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            if ($Pool_IsEthash) {
                [PSCustomObject]@{
                    Algorithm     = "$($Pool_Algorithm_Norm)NH"
					Algorithm0    = "$($Pool_Algorithm_Norm)NH"
                    CoinName      = "$($Pool_Coin.Name)"
                    CoinSymbol    = "$Pool_CoinSymbol"
                    Currency      = "BTC"
                    Price         = $Stat.$StatAverage
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = $Pool_Protocol
                    Host          = $Pool_Host
                    Port          = $Pool_Port
                    User          = "$($Pool_Wallet).{workername:$Worker}"
                    Pass          = "x"
                    Region        = "US"
                    SSL           = $Pool_SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_PoolFee
                    Workers       = $null
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $null
                    BLK           = $null
                    PaysLive      = $true
                    EthMode       = $Pool_EthProxy
                    CoinSymbolMax = $Pool_CoinSymbolMax
                    DagSizeMax    = $Pool_DagSizeMax
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
					Disabled      = $false
					HasMinerExclusions = $false
                    Price_0       = 0.0
					Price_Bias    = 0.0
					Price_Unbias  = 0.0
                    Wallet        = $Pool_Wallet
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}
