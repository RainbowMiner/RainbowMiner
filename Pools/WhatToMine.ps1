using module ..\Include.psm1

param(
    $Wallets,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync (Get-WhatToMinerUrl) -tag $Name -cycletime 120 | Select-Object -ExpandProperty coins
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request.PSObject.Properties.Name | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
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
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_Request -or ($Pool_Request.PSObject.Properties.Name | Measure-Object).Count -lt 10) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
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

            if (Test-Path ".\Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit") {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_CoinRequest.btc_revenue / $Divisor) -Duration $StatSpan -ChangeDetection $true -Quiet
            } else {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_CoinRequest.btc_revenue24 / $Divisor) -Duration (New-TimeSpan -Days 1) -ChangeDetection $false -Quiet
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
