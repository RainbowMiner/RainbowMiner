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
    [String]$AECurrency = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
$PoolCoins_Request = [PSCustomObject]@{}

try {
    $PoolCoins_Request = Invoke-RestMethodAsync "https://pool.phalanxmine.com/api/currencies" -tag $Name -cycletime 120 -timeout 20 -delay 500
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($PoolCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}
[hashtable]$Pool_RegionsTable = @{}

$Pool_Regions = @("se","sg","us","aus","ru","br","de","jp")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$PoolCoins_Request.psobject.Properties | Foreach-Object {$_.Value.algo} | Select-Object -Unique | Foreach-Object {$Pool_Algorithms[$_] = Get-Algorithm $_}

$PoolCoins_Request.PSObject.Properties.Name | Where-Object {$Wallet.$_ -or $InfoOnly} | ForEach-Object {
    $Pool_CoinSymbol = $_

    $Pool_CoinName  = $PoolCoins_Request.$Pool_CoinSymbol.name
    $Pool_Algorithm = $PoolCoins_Request.$Pool_CoinSymbol.algo
    $Pool_Algorithm_Norm = $Pool_Algorithms[$Pool_Algorithm]
    
    $Pool_PoolFee = [double]$PoolCoins_Request.$Pool_CoinSymbol.fees_solo
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratum2"} else {"stratum"}} else {$null}
    $Pool_TSL = if ($PoolCoins_Request.$Pool_CoinSymbol.timesincelast_solo -ne $null) {$PoolCoins_Request.$Pool_CoinSymbol.timesincelast_solo} else {$PoolCoins_Request.$Pool_CoinSymbol.timesincelast}

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -HashRate $PoolCoins_Request.$Pool_CoinSymbol.hashrate_solo -BlockRate $PoolCoins_Request.$Pool_CoinSymbol."24h_blocks_solo" -Difficulty $PoolCoins_Request.$Pool_CoinSymbol.difficulty -ChangeDetection $false -Quiet
    }

    foreach($Pool_SSL in ($false,$true)) {
        if ($Pool_SSL) {
            $Pool_Port_SSL = [int]$PoolCoins_Request.$Pool_CoinSymbol.port + 20000
            $Pool_Protocol = "stratum+ssl"
        } else {
            $Pool_Port_SSL = [int]$PoolCoins_Request.$Pool_CoinSymbol.port
            $Pool_Protocol = "stratum+tcp"
        }
        foreach($Pool_Region in $Pool_Regions) {
            [PSCustomObject]@{
                Algorithm          = $Pool_Algorithm_Norm
                Algorithm0         = $Pool_Algorithm_Norm
                CoinName           = $Pool_CoinName
                CoinSymbol         = $Pool_CoinSymbol
                Currency           = $Pool_CoinSymbol
                Price              = 0
                StablePrice        = 0
                MarginOfError      = 0
                Protocol           = $Pool_Protocol
                Host               = "$($Pool_Region)-stratum.phalanxmine.com"
                Port               = $Pool_Port_SSL
                User               = "$($Wallets.$Pool_CoinSymbol).{workername:$Worker}"
                Pass               = "x,m=solo{diff:,d=`$difficulty}$Pool_Params"
                Region             = $Pool_RegionsTable.$Pool_Region
                SSL                = $Pool_SSL
                SSLSelfSigned      = $Pool_SSL
                Updated            = $Stat.Updated
                PoolFee            = $Pool_PoolFee
                Workers            = $PoolCoins_Request.$Pool_CoinSymbol.workers_shared
                Hashrate           = $Stat.HashRate_Live
                BLK                = $Stat.BlockRate_Average
                TSL                = $Pool_TSL
                Difficulty         = $Stat.Diff_Average
                SoloMining         = $true
                WTM                = $true
                EthMode            = $Pool_EthProxy
                ErrorRatio         = 0
                Name               = $Name
                Penalty            = 0
                PenaltyFactor      = 1
                Disabled           = $false
                HasMinerExclusions = $false
                Price_0            = 0.0
                Price_Bias         = 0.0
                Price_Unbias       = 0.0
                Wallet             = $Wallets.$Pool_ExCurrency
                Worker             = "{workername:$Worker}"
                Email              = $Email
            }
        }
    }
}
