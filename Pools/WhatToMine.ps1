using module ..\Modules\Include.psm1

param(
    $Pools,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync (Get-WhatToMineUrl) -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API1 ($Name) has failed. "
    return
}

if (-not $Pool_Request.coins -or ($Pool_Request.coins.PSObject.Properties.Name | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API1 ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$WTMWallets = $Pools | Where-Object {$_.Algorithm -notmatch '-'} | Foreach-Object {[PSCustomObject]@{Algorithm=$_.Algorithm;CoinSymbol=$_.CoinSymbol}} | Select-Object Algorithm,CoinSymbol -Unique

$Pool_Coins = @($WTMWallets.CoinSymbol | Select-Object)

$Pool_Request.coins.PSObject.Properties.Name | Where-Object {$Pool_Coins -icontains $Pool_Request.coins.$_.tag} | ForEach-Object {
    $Pool_Currency   = $Pool_Request.coins.$_.tag
    $Pool_Algorithm  = $Pool_Request.coins.$_.algorithm -replace "[^a-z0-9]+"
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Divisor = Get-WhatToMineFactor $Pool_Algorithm_Norm

    if ($Divisor -and ($WTMWallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

        $WTMWallets = $WTMWallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}

        if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit") {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.coins.$_.btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $false -Quiet
        } else {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.coins.$_.btc_revenue24 / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
        }

        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinSymbol    = $Pool_Currency
            Price         = $Stat.Minute_10 #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Updated       = $Stat.Updated
        }
    }
}

if (-not ($WTMWallets | Measure-Object).Count) {return}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://whattomine.com/calculators.json" -tag $Name -cycletime (12*3600)
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API2 ($Name) has failed. "
    return
}

if (-not $Pool_Request.coins -or ($Pool_Request.coins.PSObject.Properties.Name | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API2 ($Name) returned nothing. "
    return
}

$Pool_Coins = @($WTMWallets.CoinSymbol | Select-Object)

$Pool_Request.coins.PSObject.Properties.Name | Where-Object {$Pool_Coins -icontains $Pool_Request.coins.$_.tag} | ForEach-Object {
    $Pool_Currency   = $Pool_Request.coins.$_.tag
    $Pool_Algorithm  = $Pool_Request.coins.$_.algorithm -replace "[^a-z0-9]+"
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Divisor = Get-WhatToMineFactor $Pool_Algorithm_Norm

    if ($Divisor -and ($WTMWallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

        $WTMWallets = $WTMWallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}

        $Pool_CoinRequest = [PSCustomObject]@{}
        try {
            $Pool_CoinRequest = Invoke-RestMethodAsync "https://whattomine.com/coins/$($Pool_Request.coins.$_.id).json?hr=10&p=0&fee=0.0&cost=0.0&hcost=0.0" -tag $Name -cycletime 120
        } catch {
           if ($Error.Count){$Error.RemoveAt(0)} 
        }

        if ($Pool_CoinRequest -and $Pool_CoinRequest.tag) {
            $btc_revenue = [double]$Pool_CoinRequest.btc_revenue
            if (-not $btc_revenue) {
                $lastSatPrice = Get-LastSatPrice $Pool_CoinRequest.tag ([double]$Pool_CoinRequest.exchange_rate)
                $btc_revenue = $lastSatPrice * [double]$Pool_CoinRequest.estimated_rewards
            }
            $btc_revenue24 = $btc_revenue

            if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit") {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $false -Quiet
            } else {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($btc_revenue24 / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
            }

            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinSymbol    = $Pool_Currency
                Price         = $Stat.Minute_10 #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Updated       = $Stat.Updated
            }
        }
    }
}

if (-not ($WTMWallets | Measure-Object).Count) {return}

$Pool_Request = @()
try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/minerstat.json" -tag $Name -cycletime (12*3600)
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API3 ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API3 ($Name) returned nothing. "
    return
}

$Pool_Coins = @($WTMWallets.CoinSymbol | Select-Object)

$Pool_Request | Where-Object {$Pool_Coins -eq $_.coin} | Foreach-Object {
    $Pool_Currency   = $_.coin
    $Pool_Algorithm  = $_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    if (($WTMWallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

        $WTMWallets = $WTMWallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}

        if (-not ($lastSatPrice = Get-LastSatPrice $_.coin)) {
            $lastSatPrice = if ($Global:Rates.USD -and $_.price -gt 0) {$_.price / $Global:Rates.USD * 1e8} else {0}
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($_.reward * $lastSatPrice / 1e8) -Duration $StatSpan -ChangeDetection $false -Quiet

        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinSymbol    = $Pool_Currency
            Price         = $Stat.Minute_10 #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Updated       = $Stat.Updated
        }
    }
}

if ($WTMWallets -ne $null) {Remove-Variable "WTMWallets"}
