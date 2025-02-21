using module ..\Modules\Include.psm1

param(
    $Config
)

if (-not $Config.Pools.$Name.API_Key -or -not $Config.Pools.$Name.User) {
    Write-Log -Level Verbose "$($Name): Please set your username and an API_Key in pools.config.txt (on luxor.tech, sign in, then click `"API Keys`" and create)"
    return
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "ARRR";    port = 700; fee = 5.0; rpc = "arrr"}
    [PSCustomObject]@{symbol = "DASH";    port = 700; fee = 3.0; rpc = "dash"}
    [PSCustomObject]@{symbol = "SC";      port = 700; fee = 3.0; rpc = "sc"}
    [PSCustomObject]@{symbol = "ZEC";     port = 700; fee = 3.0; rpc = "zec"}
    [PSCustomObject]@{symbol = "ZEN";     port = 700; fee = 3.0; rpc = "zen"}
)

$Pools_Data | Where-Object {($Config.Pools.$Name.Wallets."$($_.symbol)" -or $Config.Pools.$Name.User) -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://api.beta.luxor.tech/graphql" -tag $Name -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15  -headers @{'x-lux-api-key'=$Config.Pools.$Name.API_Key} -body @{query = "query MyQuery { getWallet(coinId: $($Pool_Currency), uname: `"$($Config.Pools.$Name.User)`") { pendingBalance remainingFreezingTime paymentThreshold paymentIntervalHours isFrozen currencyProfileName address}}"}

        if (-not $Request.data.getWallet) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.getWallet.pendingBalance
                Pending     = 0
                Total       = [Decimal]$Request.data.getWallet.pendingBalance
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }

    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}
