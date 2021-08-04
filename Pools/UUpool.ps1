﻿using module ..\Modules\Include.psm1

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
    [String]$StatAverageStable = "Week",
    [String]$Email = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

[hashtable]$Pool_RegionsTable = @{}

@("CN","EU","US") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = @()
try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/uupool.json" -retry 3 -retrywait 200 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or -not ($Pool_Request | Measure-Object).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request | Where-Object {$Pool_Currency = $_.coin -replace "(29|31)" -replace "^VDS$","VOLLAR" -replace "^ULORD$","UT";$Wallets.$Pool_Currency -or $Wallets."$($_.coin)" -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $_.algorithm
    $Pool_Algorithm_Norm = Get-Algorithm $_.algorithm
    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    if ($_.hr) {
        $hr = $_.hr  -split "\s+"
        $est= $_.est -split "[\s/]+"

        $Pool_User   = if ($Wallets.$Pool_Currency) {$Wallets.$Pool_Currency} else {$Wallets."$($_.coin)"}

        $hr_value  = [Double]($hr[0] -replace "[^\d\.]+")
        $est_value = [Double]($est[0] -replace "[^\d\.]+")

        $Pool_Hashrate = [Double]$hr_value  * $(Switch ($hr[1])  {"K" {1e3};"M" {1e6};"G" {1e9};"T" {1e12};"P" {1e15};default {1}})
        $Pool_Estimate = [Double]$est_value / $(Switch ($est[2]) {"K" {1e3};"M" {1e6};"G" {1e9};"T" {1e12};"P" {1e15};default {1}})

        $lastBTCPrice = if ($Global:Rates.$Pool_Currency) {1/[double]$Global:Rates.$Pool_Currency}
                        elseif ($Global:Rates."$($_.coin)") {1/[double]$Global:Rates."$($_.coin)"}
                        elseif ($_.usd -and $Global:Rates.USD) {$_.usd/$Global:Rates.USD}
                        elseif ($_.cny -and $Global:Rates.CNY) {$_.cny/$Global:Rates.CNY}
                        else {0}

        if (-not $InfoOnly) {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($Pool_Estimate * $lastBTCPrice) -Duration $StatSpan -HashRate $Pool_Hashrate -ChangeDetection $true -Quiet
            if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
        }

        foreach($Pool_Host in @($_.address -split ',')) {
            if ($Pool_Host -match "^(.+?):(\d+)") {
                [PSCustomObject]@{
                    PoolEstimate  = $Pool_Estimate
                    Algorithm     = $Pool_Algorithm_Norm
					Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $_.name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = "$($Matches[1].Trim())"
                    Port          = "$($Matches[2].Trim())"
                    User          = "$($Pool_User).{workername:$Worker}"
                    Pass          = "x"
                    Region        = Switch -Regex ($Pool_Host) {"\(EU\)" {$Pool_RegionsTable.EU};"\(US\)" {$Pool_RegionsTable.US};default {$Pool_RegionsTable.CN}}
                    SSL           = $false
                    Updated       = $Stat.Updated
                    PoolFee       = $_.rates -replace "[^\d\.]+"
                    DataWindow    = $DataWindow
                    Workers       = $Pool_RequestWorkers.data
                    Hashrate      = $Stat.HashRate_Live
                    EthMode       = $Pool_EthProxy
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
					Disabled      = $false
					HasMinerExclusions = $false
					Price_Bias    = 0.0
					Price_Unbias  = 0.0
                    Wallet        = $Pool_User
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
            }
        }
    }
}
