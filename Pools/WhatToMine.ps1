using module ..\Modules\Include.psm1

param(
    $Pools,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_Algorithms = @{}

$WTMWallets = $Pools | Where-Object {$_.Algorithm -notmatch '-'} | Foreach-Object {[PSCustomObject]@{Algorithm=$_.Algorithm;CoinSymbol=$_.CoinSymbol}} | Select-Object Algorithm,CoinSymbol -Unique

if (-not ($WTMWallets | Measure-Object).Count) {return}

$ok = $false
$Pool_Request = @()
try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/minerstat.json" -tag $Name -cycletime 240
    if ($Pool_Request -and ($Pool_Request | Measure-Object).Count -ge 10) {
        $ok = $true
    } else {
        Write-Log -Level Warn "Pool API Minerstat ($Name) returned nothing. "
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API Minerstat ($Name) has failed. "
}


if ($ok) {

    $Pool_Coins = @($WTMWallets.CoinSymbol | Select-Object)

    $Pool_Request | Where-Object {$Pool_Coins -eq $_.coin} | Foreach-Object {
        $Pool_Currency   = $_.coin
        $Pool_Algorithm  = $_.algo
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
        $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

        if (($WTMWallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

            if (-not ($lastSatPrice = Get-LastSatPrice $_.coin)) {
                $lastSatPrice = if ($Global:Rates.USD -and $_.price -gt 0) {$_.price / $Global:Rates.USD * 1e8} else {0}
            }

            $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($_.reward * $lastSatPrice / 1e8) -Duration $StatSpan -ChangeDetection $false -Quiet

            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinSymbol    = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Updated       = $Stat.Updated
            }

            $WTMWallets = $WTMWallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}
        }
    }
}

if (-not ($WTMWallets | Measure-Object).Count) {return}

$ok = $false
$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync (Get-WhatToMineUrl -Factor 1000) -tag $Name -cycletime 120
    if ($Pool_Request.coins -and ($Pool_Request.coins.PSObject.Properties.Name | Measure-Object).Count -ge 10) {
        $ok = $true
    } else {
        Write-Log -Level Warn "Pool API WTM-main ($Name) returned nothing. "
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API WTM-main ($Name) has failed. "
}

if ($ok) {

    $Pool_Coins = @($WTMWallets.CoinSymbol | Select-Object)

    $Pool_Request.coins.PSObject.Properties.Name | Where-Object {$Pool_Coins -icontains $Pool_Request.coins.$_.tag} | ForEach-Object {
        $Pool_Currency   = $Pool_Request.coins.$_.tag
        $Pool_Algorithm  = $Pool_Request.coins.$_.algorithm -replace "[^a-z0-9]+"
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}

        $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
        $Divisor = Get-WhatToMineFactor $Pool_Algorithm_Norm -Factor 1000

        if ($Pool_Algorithm -eq "ProgPow") {
            $Pool_Algorithm = "ProgPow$($Pool_Currency)"
            if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
            $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
        }

        if ($Divisor -and ($WTMWallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

            $lastSatPrice = Get-LastSatPrice $Pool_Currency

            if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit") {
                if ($lastSatPrice) {
                    $btc_revenue = $lastSatPrice * [double]$Pool_Request.coins.$_.estimated_rewards / 1e8
                } else {
                    $btc_revenue = [double]$Pool_Request.coins.$_.btc_revenue
                    if (-not $btc_revenue) {
                        $ExCurrency = $Pool_Request.coins.$_.exchange_rate_curr
                        if ($Global:Rates.$ExCurrency) {
                            $lastSatPrice = Get-LastSatPrice $Pool_Currency ([double]$Pool_Request.coins.$_.exchange_rate / $Global:Rates.$ExCurrency * 1e8)
                            $btc_revenue = $lastSatPrice * [double]$Pool_Request.coins.$_.estimated_rewards / 1e8
                        }
                    }
                }
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $false -Quiet
            } else {
                if ($lastSatPrice) {
                    $btc_revenue = $lastSatPrice * [double]$Pool_Request.coins.$_.estimated_rewards24 / 1e8
                } else {
                    $btc_revenue = [double]$Pool_Request.coins.$_.btc_revenue24
                    if (-not $btc_revenue) {
                        $ExCurrency = $Pool_Request.coins.$_.exchange_rate_curr
                        if ($Global:Rates.$ExCurrency) {
                            $lastSatPrice = Get-LastSatPrice $Pool_Currency ([double]$Pool_Request.coins.$_.exchange_rate24 / $Global:Rates.$ExCurrency * 1e8)
                            $btc_revenue = $lastSatPrice * [double]$Pool_Request.coins.$_.estimated_rewards24 / 1e8
                        }
                    }
                }
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($btc_revenue / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
            }

            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinSymbol    = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Updated       = $Stat.Updated
            }

            $WTMWallets = $WTMWallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}
        }
    }
}

if (-not ($WTMWallets | Measure-Object).Count) {return}

$ok = $false
$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://whattomine.com/calculators.json" -tag $Name -cycletime (12*3600)
    if ($Pool_Request.coins -and ($Pool_Request.coins.PSObject.Properties.Name | Measure-Object).Count -ge 10) {
        $ok = $true
    } else {
        Write-Log -Level Warn "Pool API WTM-calc ($Name) returned nothing. "
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API WTM-calc ($Name) has failed. "
}

if ($ok) {

    $Pool_Coins = @($WTMWallets.CoinSymbol | Select-Object)

    $Pool_Request.coins.PSObject.Properties.Name | Where-Object {$Pool_Request.coins.$_.status -eq "Active" -and $Pool_Coins -icontains $Pool_Request.coins.$_.tag} | ForEach-Object {
        $Pool_Currency   = $Pool_Request.coins.$_.tag
        $Pool_Algorithm  = $Pool_Request.coins.$_.algorithm -replace "[^a-z0-9]+"
        if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}

        $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
        $Divisor = Get-WhatToMineFactor $Pool_Algorithm_Norm -Factor 1000

        if ($Pool_Algorithm -eq "ProgPow") {
            $Pool_Algorithm = "ProgPow$($Pool_Currency)"
            if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
            $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm
        }

        if ($Divisor -and ($WTMWallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

            $Pool_CoinRequest = [PSCustomObject]@{}
            try {
                $Pool_CoinRequest = Invoke-RestMethodAsync "https://whattomine.com/coins/$($Pool_Request.coins.$_.id).json?hr=1000&p=0&fee=0.0&cost=0.0&hcost=0.0" -tag $Name -cycletime 120
            } catch {
               if ($Error.Count){$Error.RemoveAt(0)}
            }

            if ($Pool_CoinRequest -and $Pool_CoinRequest.tag) {

                $lastSatPrice = Get-LastSatPrice $Pool_CoinRequest.tag

                if ($lastSatPrice) {
                    $btc_revenue = $lastSatPrice * [double]$Pool_CoinRequest.estimated_rewards / 1e8
                } else {
                    $btc_revenue = [double]$Pool_CoinRequest.btc_revenue
                    if (-not $btc_revenue) {
                        $ExCurrency = $Pool_CoinRequest.exchange_rate_curr
                        if ($Global:Rates.$ExCurrency) {
                            $lastSatPrice = Get-LastSatPrice $Pool_CoinRequest.tag ([double]$Pool_CoinRequest.exchange_rate / $Global:Rates.$ExCurrency * 1e8)
                            $btc_revenue = $lastSatPrice * [double]$Pool_CoinRequest.estimated_rewards
                        }
                    }
                }

                if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit") {
                    $diff   = [decimal]$Pool_CoinRequest.difficulty
                    $diff24 = [decimal]$Pool_CoinRequest.difficulty24
                    if ($diff24 -gt 0 -and $diff -gt 0) {
                        $btc_revenue *=  $diff/$diff24
                    }
                    $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $false -Quiet
                } else {
                    $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($btc_revenue / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
                }

                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
                    CoinSymbol    = $Pool_Currency
                    Price         = $Stat.$StatAverage #instead of .Live
                    StablePrice   = $Stat.$StatAverageStable
                    MarginOfError = $Stat.Week_Fluctuation
                    Updated       = $Stat.Updated
                }

                $WTMWallets = $WTMWallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}
            }
        }
    }
}

if ($WTMWallets -ne $null) {Remove-Variable "WTMWallets"}
