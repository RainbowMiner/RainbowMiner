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

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}
@("eu","us","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

if (Test-Path ".\Data\f2pool.json") {
    try {
        $Pools_Data = Get-Content ".\Data\f2pool.json" -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Remove-Item ".\Data\f2pool.json" -Force -ErrorAction Ignore
    }
}

if (-not (Test-Path ".\Data\f2pool.json")) {
    $Pool_Request = [PSCustomObject]@{}
    try {
        $Pool_Request = Invoke-GetUrl "https://www.f2pool.com" -timeout 20
        $Pools_Data = "$(($Pool_Request -split 'id="tab-content-main"' | Select-Object -Last 1) -split '</tbody>' | Select-Object -First 1)$(($Pool_Request -split 'id="tab-content-labs"' | Select-Object -Last 1) -split '</tbody>' | Select-Object -First 1)" -split '</tr>' |
          Where-Object {$_ -match '<div.+?data-code="(.+?)"'} |
          Where-Object {$id = $Matches[1];$id -notmatch '-address' -and $_ -match 'address-item'} |
          Where-Object {$Matches[1] -notmatch '-address'} |
          Foreach-Object {
            $Data = [PSCustomObject]@{id = $id; currency = ($id -replace 'bchabc','bch' -replace '-.+$').ToUpper(); algo = ''; host = ''; port = 0; fee = 0; region = @("asia")}
            $urls = ([regex]"<span>(.+?\.f2pool.com:\d+?)</span>").Matches($_)
            ($urls.Groups | Where Name -eq 1).Value | Foreach-Object {
                $url = $_ -replace '^.+?//' -split ':'
                if ($url[0] -match "-(eu|us)") {$Data.region += $Matches[1]}
                elseif (-not $Data.host) {$Data.host = $url[0] -replace '.f2pool.com';$Data.port = [Int]$url[1]}
            }
            $Info = ($_ -split '<div class="col-12 col-lg-6 item d-block d-lg-none">' | Select-Object -Index 4) -split '</div>'    
            if ($Info[0] -replace '[\r\n]+' -match 'info-value">(.*?)<') {$Data.algo = ($Matches[1] -replace '\(.*').Trim(); $Data.algo = Get-Algorithm "$(Switch($id) {"grin-29" {"Cuckaroo29"};"grin-31" {"Cuckatoo31"};default {$Data.algo}})$(if ($Data.algo -eq "Equihash") {$Data.currency})"}
            if ($Info[6] -replace '[\r\n]+' -match 'info-value">(.*?)<') {$Data.fee  = [Double]($Matches[1] -replace '%.*').Trim()}
            $Data
        }
        $Pools_Data | ConvertTo-Json -Compress | Out-File ".\Data\f2pool.json" -Force
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) has failed. "
    }
}

$Pools_Data | Where-Object {$Pool_Currency = $_.currency; $Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {

    $Pool_Request = [PSCustomObject]@{}

    $ok = $true

    if (-not $InfoOnly) {

        try {
            $Pool_Request = Invoke-RestMethodAsync "https://www.f2pool.com/coins-chart" -Body @{currency_code=$_.id -replace "(dgb|xmy|xvg)-.+?$","`$1";history_days = "7d";interval = "60m"} -tag $Name -cycletime 120 -retry 3 -retrywait 250
            if (-not $Pool_Request.data) {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($Pool_Currency) has failed. "
            $ok = $false
        }

        $Pool_BLK = $Pool_Request.data.output24h / $Pool_Request.data.blockreward
        $Divisor  = Switch($Pool_Request.data.profit_per_hash) {"K" {1e3}; "M" {1e6}; "G" {1e9}; "T" {1e12}; default {1}}
        if (-not $Session.Rates.$Pool_Currency -and $Pool_Request.data.price -and $Session.Rates.USD) {$Session.Rates.$Pool_Currency = $Session.Rates.USD / $Pool_Request.data.price}
                          
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $(if ($Session.Rates.$Pool_Currency) {$Pool_Request.data.estimated_profit / $Divisor / $Session.Rates.$Pool_Currency} else {0}) -Duration $StatSpan -ChangeDetection $false -HashRate ($Pool_Request.data.chart_data | select-object -last 1 | Select-Object -ExpandProperty hashrate) -BlockRate $Pool_BLK -Quiet
    }

    if ($ok) {
        $Pool_Algorithm_Norm = Get-Algorithm $_.algo
        foreach($Region in $_.region) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_Request.data.name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($_.host)$(if ($Region -ne "asia") {"-$($Region)"}).f2pool.com"
                Port          = $_.port
                User          = "$($Wallets."$($Pool_Currency)").{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Region
                SSL           = $Pool_Algorithm_Norm -match "Equihash"
                Updated       = $Stat.Updated
                PoolFee       = $_.fee
                DataWindow    = $DataWindow
                Workers       = $Pool_Request.workersTotal
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
            }
        }
    }
}
