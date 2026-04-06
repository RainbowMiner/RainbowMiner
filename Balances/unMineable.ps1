using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

#https://api.unminable.com/v3/stats/0xaaD1d2972f99A99248464cdb075B28697d4d8EEd?tz=1&coin=c
# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_CoinsRequest = [PSCustomObject]@{}
$PoolConfig = $Config.Pools.$Name

try {
    $Pool_CoinsRequest = Invoke-RestMethodAsync "https://api.unmineable.com/v4/coin" -tag $Name -cycletime 21600
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not $Pool_CoinsRequest.success) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Legacy_Coins = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$Pool_CoinsRequest.data | Where-Object {$PoolConfig.Wallets."$($_.symbol)" -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.symbol)")} | Foreach-Object {
    $Pool_Currency = $_.symbol

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-WebRequestAsync "https://api.unminable.com/v4/address/$($PoolConfig.Wallets.$Pool_Currency)?coin=$($Pool_Currency)" -cycletime ($Config.BalanceUpdateMinutes*60)
        $Request = ConvertFrom-Json "$($Request -replace ',"hashrate".+$','}}')" -ErrorAction Stop

        if (-not $Request.success) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
				BaseName    = $Name
                Info        = "leg."
                Name        = "$Name leg."
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.data.balance
                Pending     = 0
                Total       = [Decimal]$Request.data.balance
                Paid        = [Decimal]$Request.data.total_paid
                Paid24h     = [Decimal]$Request.data.total_24h
                Payouts     = @()
                LastUpdated = (Get-Date).ToUniversalTime()
            }
            $Pool_Legacy_Coins.Add($Pool_Currency) > $null
        }
    }
    catch {
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}

if ($PoolConfig.User -and $PoolConfig.API_Key -and $PoolConfig.API_Secret) {
    try {
        $Pool_CoinsRequest = Invoke-UnMineableRequest "/v1/assets" $PoolConfig.API_Key $PoolConfig.API_Secret -params @{is_active="true";sort="coin";dir="asc"} -cache ($Config.BalanceUpdateMinutes*60)
        if ($Pool_CoinsRequest.success) {
            $Pool_CoinsRequest.data.list | Where-Object {$_.amount -gt 0 -and ($_.type -eq "coin" -or -not $Pool_Legacy_Coins.Contains($_.coin))} | Foreach-Object {
                $Pool_Currency = $_.coin
                $Paid    = 0
                if ($_.type -eq "coin") {
                    try {
                        $Pool_CoinStatRequest = Invoke-UnMineableRequest "/v1/assets/$($Pool_Currency)/stats" $PoolConfig.API_Key $PoolConfig.API_Secret -cache ($Config.BalanceUpdateMinutes*60)
                        if ($Pool_CoinStatRequest.success) {
                            $Paid = $Pool_CoinStatRequest.data.paid
                        }
                    } catch {}
                }
                [PSCustomObject]@{
                    Caption     = "$($Name) ($Pool_Currency)$(if ($_.is_active) {"*"})"
				    BaseName    = $Name
                    Info        = if ($_.type -ne "coin") {"leg."} else {$null}
                    Name        = "$Name$(if ($_.type -ne "coin") {" leg."})"
                    Currency    = $Pool_Currency
                    Balance     = [Decimal]$_.amount
                    Pending     = 0
                    Total       = [Decimal]$_.amount
                    Paid        = [Decimal]$Paid
                    Paid24h     = 0
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
    }
    catch {
        Write-Log -Level Warn "Pool asset API ($Name) has failed. "
    }

}

$Pool_Legacy_Coins = $null
