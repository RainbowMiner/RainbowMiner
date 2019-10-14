using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
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

    $Pool_Request = [PSCustomObject]@{}

    $Pool_Hashrate = $null
    $Pool_Workers  = $null
    $Pool_TSL      = $null

    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/stats" -tag $Name -cycletime 120
            if (-not $Pool_Request -or ($Pool_Request.mainStats -eq $null -and $Pool_Request.hashrate -eq $null)) {throw}
            $PoolBlocks_Request = Invoke-RestMethodAsync "https://$($_.rpc)/api/blocks" -tag $Name -cycletime 120 -delay 250
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) has failed. "
        }

        if ($Pool_Request.mainStats) {
            $Pool_Hashrate = $Pool_Request.mainStats.hashrate
            $Pool_Workers  = [int]($Pool_Request.charts.workers | Select-Object -Last 1)
            $Pool_TSL      = (Get-UnixTimestamp) - $Pool_Request.mainStats.lastBlockFound
        } else {
            $Pool_Hashrate = $Pool_Request.hashrate
            $Pool_Workers  = $Pool_Request.minersTotal
            $Pool_TSL      = (Get-UnixTimestamp) - $Pool_Request.stats.lastBlockFound
        }
        $Timestamp_24h = (Get-UnixTimestamp) - 24*3600
        $Pool_BLK = ($PoolBlocks_Request.candidates | Where-Object {$_.timestamp -ge $Timestamp_24h -and -not $_.orphan} | Measure-Object).Count + ($PoolBlocks_Request.immature | Where-Object {$_.timestamp -ge $Timestamp_24h -and -not $_.orphan} | Measure-Object).Count + ($PoolBlocks_Request.matured | Where-Object {$_.timestamp -ge $Timestamp_24h -and -not $_.orphan} | Measure-Object).Count

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Hashrate -BlockRate $Pool_BLK -Quiet
    }
    
    if ($Pool_Algorithm_Norm -ne "Equihash" -and $Pool_Algorithm_Norm -like "Equihash*") {$Pool_Algorithm_All = @($Pool_Algorithm_Norm,"$Pool_Algorithm_Norm-$Pool_Currency")} else {$Pool_Algorithm_All = @($Pool_Algorithm_Norm)}

    if ($AllowZero -or $Pool_Hashrate -gt 0 -or $InfoOnly) {
        foreach($Pool_Region in $_.regions) {
            $Pool_Ssl = $false
            foreach($Pool_Port in $Pool_Ports) {
                foreach($Pool_Algorithm_Norm in $Pool_Algorithm_All) {
                    [PSCustomObject]@{
                        Algorithm     = $Pool_Algorithm_Norm
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
                        Updated       = (Get-Date).ToUniversalTime()
                        PoolFee       = $_.fee
                        DataWindow    = $DataWindow
                        Workers       = $Pool_Workers
                        Hashrate      = $Stat.HashRate_Live
                        TSL           = $Pool_TSL
                        BLK           = $Stat.BlockRate_Average
                        WTM           = $true
                        EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"qtminer"} else {$null}
                        AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
                        Wallet        = $Wallets.$Pool_Currency
                        Worker        = "{workername:$Worker}"
                        Email         = $Email
                    }
                }
                $Pool_Ssl = $true
            }
        }
    }
}

Remove-Variable "Pools_Data"