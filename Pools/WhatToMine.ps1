using module ..\Include.psm1

param(
    $Wallets,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync (Get-WhatToMineUrl) -tag $Name -cycletime 120 | Select-Object -ExpandProperty coins
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API1 ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request.PSObject.Properties.Name | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API1 ($Name) returned nothing. "
    return
}

[hashtable]$Pool_Algorithms = @{}

$Pool_Coins = @($Wallets.CoinSymbol | Select-Object)

$Pool_Request.PSObject.Properties.Name | Where-Object {$Pool_Coins -icontains $Pool_Request.$_.tag} | ForEach-Object {
    $Pool_Currency   = $Pool_Request.$_.tag
    $Pool_Algorithm  = $Pool_Request.$_.algorithm -replace "[^a-z0-9]+"
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Divisor = Get-WhatToMineFactor $Pool_Algorithm_Norm

    if ($Divisor -and ($Wallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

        $Wallets = $Wallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}

        if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit") {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.$_.btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $true -Quiet
        } else {
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_Request.$_.btc_revenue24 / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
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

if (-not ($Wallets | Measure-Object).Count) {return}

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://whattomine.com/calculators.json" -tag $Name -cycletime (12*3600) | Select-Object -ExpandProperty coins
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API2 ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request.PSObject.Properties.Name | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API2 ($Name) returned nothing. "
    return
}

$Pool_Coins = @($Wallets.CoinSymbol | Select-Object)

$Pool_Request.PSObject.Properties.Name | Where-Object {$Pool_Coins -icontains $Pool_Request.$_.tag} | ForEach-Object {
    $Pool_Currency   = $Pool_Request.$_.tag
    $Pool_Algorithm  = $Pool_Request.$_.algorithm -replace "[^a-z0-9]+"
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Divisor = Get-WhatToMineFactor $Pool_Algorithm_Norm

    if ($Divisor -and ($Wallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

        $Wallets = $Wallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}

        $Pool_CoinRequest = [PSCustomObject]@{}
        try {
            $Pool_CoinRequest = Invoke-RestMethodAsync "https://whattomine.com/coins/$($Pool_Request.$_.id).json?hr=10&p=0&fee=0.0&cost=0.0&hcost=0.0" -tag $Name -cycletime 120
        } catch {
           if ($Error.Count){$Error.RemoveAt(0)} 
        }

        if ($Pool_CoinRequest -and $Pool_CoinRequest.tag) {
            if (-not [double]$Pool_CoinRequest.btc_revenue) {
                $lastSatPrice = Get-LastSatPrice $Pool_CoinRequest.tag ([double]$Pool_CoinRequest.exchange_rate)
                $Pool_CoinRequest | Add-Member btc_revenue ($lastSatPrice * [double]$Pool_CoinRequest.estimated_rewards) -Force
            }
            $Pool_CoinRequest | Add-Member btc_revenue24 $Pool_CoinRequest.btc_revenue

            if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit") {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_CoinRequest.btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $true -Quiet
            } else {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ([Double]$Pool_CoinRequest.btc_revenue24 / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
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

if (-not ($Wallets | Measure-Object).Count) {return}

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

$Pool_Coins = @($Wallets.CoinSymbol | Select-Object)

$Pool_Request | Where-Object {$Pool_Coins -eq $_.coin1 -and -not $_.coin2} | ForEach-Object {
    $Pool_Currency   = $_.coin1
    $Pool_Algorithm  = $_.algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    if (($Wallets | Where-Object {$_.Algorithm -eq $Pool_Algorithm_Norm -and $_.CoinSymbol -eq $Pool_Currency} | Measure-Object).Count) {

        $Wallets = $Wallets | Where-Object {$_.Algorithm -ne $Pool_Algorithm_Norm -or $_.CoinSymbol -ne $Pool_Currency}

        $Pool_CoinRequest = [PSCustomObject]@{}
        try {
            (Invoke-RestMethodAsync "https://minerstat.com/coin/$($_.coin1)" -tag $Name -cycletime 120) -split "icon_coins\s+" | Select-Object -Skip 1 | Where-Object {$_ -match "(reward|revenue)"} | Foreach-Object {
                $cod = $Matches[1]
                $dat = ([regex]'(?smi)>([\d\.\,E+-]+)\s+([\w]+)<.+for\s([\d\.\,]+)\s*(.+?)<').Matches($_)
                if ($dat -and $dat.Groups -and $dat.Groups.Count -eq 5) {
                    $Pool_CoinRequest | Add-Member $cod ([PSCustomObject]@{value=[decimal]($dat.Groups[1].Value -replace ',');currency=$dat.Groups[2].Value;fact=[decimal]($dat.Groups[3].Value -replace ',');unit=$dat.Groups[4].Value}) -Force
                }
            }
        } catch {
           if ($Error.Count){$Error.RemoveAt(0)} 
        }

        if ($Pool_CoinRequest.reward -and $Pool_CoinRequest.revenue -and ($Divisor = ConvertFrom-Hash "$($Pool_CoinRequest.reward.fact) $($Pool_CoinRequest.reward.unit)")) {
            if (-not ($lastSatPrice = Get-LastSatPrice $Pool_CoinRequest.reward.currency)) {
                $lastSatPrice = if ($Session.Rates."$($Pool_CoinRequest.revenue.currency)") {$Pool_CoinRequest.revenue.value / $Session.Rates."$($Pool_CoinRequest.revenue.currency)" * 1e8} else {0}
            }

            $revenue = $Pool_CoinRequest.reward.value * $lastSatPrice / 1e8
            
            $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_$($Pool_Currency)_Profit" -Value ($revenue / $Divisor) -Duration $StatSpan -ChangeDetection $true -Quiet

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

