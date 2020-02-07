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
    [String]$StatAverage = "Minute_10",
    [String]$Password
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}
@("us","eu","sgp") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "VRM";   port = @(3032); fee = 1.9; rpc = "vrm"; region = @("us","eu","sgp")}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Ports     = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Regions   = $_.region

    if (-not $InfoOnly -and $Wallets.$Pool_Currency -notmatch "\.") {
        Write-Log -Level Warn "$Name's $Pool_Currency wallet must be in the form xxx.yyy - check the pool's `"My Workers`" page."
        return
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    if (-not $InfoOnly) {
        $Pool_Stats = [PSCustomObject]@{}

        try {
            $Network_Request = Invoke-RestMethodAsync "https://veriumstats.vericoin.info/stats.json" -tag "veriumstats" -timeout 15 -cycletime 120
            $Pool_Request = ((Invoke-RestMethodAsync "https://www.mining-pool.ovh/index.php?page=statistics&action=pool" -tag $Name -timeout 15 -cycletime 120) -split 'General Statistics' | Select-Object -Last 1) -split '</table>' | Select-Object -First 1
            ([regex]'(?si)id="b-(\w+)".*?>[\s\r\n]*([\d.,]+)(.*?)</td>').Matches($Pool_Request) | Foreach-Object {
                $match = $_
                Switch ($match.Groups[1].value) {
                    "hashrate" {
                        if ($Pool_Stats.hashrate -eq $null -or $match.Groups[3].value -match "/m") {
                            if ($match.Groups[3].value -match "(\wH)/([sm])") {$unit = ConvertFrom-Hash "1$($Matches[1])";if ($Matches[2] -eq "m") {$unit/=60}} else {$unit = 1000}
                            $Pool_Stats | Add-Member hashrate ([double]($match.Groups[2].value -replace ",")*$unit) -Force
                        }
                    }
                    "workers"  {$Pool_Stats | Add-Member workers  ([int]($match.Groups[2].value -replace ",")) -Force}
                    "diff"     {$Pool_Stats | Add-Member difficulty ([double]($match.Groups[2].value -replace ",")) -Force}
                }
            }
            ([regex]'(?si)<th>([^<]*Time[^<]*)</th>.*?<td.*?>([^<]+)<').Matches($Pool_Request) | Where-Object {$_.Groups[1].value -notmatch "network"} | Foreach-Object {
                $match = $_
                $fragments = $match.Groups[2].value.Trim() -split "\s+"
                if ($fragments.Count -gt 1 -and -not ($fragments.Count % 2)) {
                    $seconds = 0
                    for($i=0; $i -lt $fragments.Count; $i+=2) {
                        $seconds += $(Switch -Regex ($fragments[$i+1]) {
                            "day" {86400;break}
                            "min" {60;break}
                            "sec" {1;break}
                            default {0}
                        }) * [int]$fragments[$i]
                    }
                    Switch -Regex ($match.Groups[1].value) {
                        "round" {$Pool_Stats | Add-Member blocktime $seconds -Force}
                        "last"  {$Pool_Stats | Add-Member timesincelast $seconds -Force}
                    }
                }
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) has failed. "
            return
        }
        if ($Pool_Stats.blocktime -gt 0) {
            $Pool_BLK   = 86400 / $Pool_Stats.blocktime
            $rewardBtc  = if ($Global:Rates.$Pool_Currency) {$Pool_BLK * $Network_Request.blockreward / $Global:Rates.$Pool_Currency} else {0}
            $profitLive = $rewardBtc / $Pool_Stats.hashrate
        } else {
            $Pool_BLK   = $profitLive = 0
        }
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $profitLive -Duration $StatSpan -HashRate $Pool_Stats.hashrate -BlockRate $Pool_BLK -ChangeDetection $($profitLive -gt 0) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }
    
    foreach ($Pool_Region in $Pool_Regions) {
        $Pool_SSL = $false
        foreach ($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
				Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$Pool_Region.$Pool_RpcPath.mining-pool.ovh"
                Port          = $Pool_Port
                User          = $Wallets.$Pool_Currency
                Pass          = "$(if ($Password) {$Password} else {"x"})"
                Region        = $Pool_RegionsTable[$Pool_Region]
                SSL           = $Pool_SSL
                WTM           = $profitLive -eq 0
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Stats.workers
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_Stats.timesincelast
                BLK           = $Stat.BlockRate_Average
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
				Disabled      = $false
				HasMinerExclusions = $false
				Price_Bias    = 0.0
				Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency -replace "\..+$"
                Worker        = $Wallets.$Pool_Currency -replace "^.+\."
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
