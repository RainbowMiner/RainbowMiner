using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = Get-PoolsData $Name

$Pool_Currencies = $Pools_Data.symbol | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}
if (-not $Pool_Currencies -and -not $InfoOnly) {return}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Ports = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo
    $Pool_Currency = $_.symbol
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"qtminer"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Request = [PSCustomObject]@{}

    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/stats" -tag $Name -cycletime 120
            if (-not $Pool_Request -or $Pool_Request.nodes -eq $null) {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) has failed. "
        }

        $difficulty = ($Pool_Request.nodes | Where-Object name -eq "main").difficulty / [Math]::Pow(2,32)

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty $difficulty -Quiet
    }
    
    foreach($Pool_Region in $_.regions) {
        $Pool_Ssl = $false
        foreach($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $_.coin
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+$(if ($Pool_Ssl) {"ssl"} else {"tcp"})"
                Host          = $_.host
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_Ssl
                Updated       = $Stat.Updated
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $null
                Hashrate      = $null
                TSL           = $null
                BLK           = $null
                Difficulty    = $Stat.Diff_Average
                SoloMining    = $true
                WTM           = $true
                EthMode       = $Pool_EthProxy
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_Ssl = $true
        }
    }
}

Remove-Variable "Pools_Data"
