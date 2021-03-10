using module ..\Modules\Include.psm1

param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

if (-not $Config.Pools.$Name.User -or -not $Config.Pools.$Name.API_Key) {return}

$Request = [PSCustomObject]@{}
try {
    $Request = Invoke-RestMethodAsync "https://prohashing.com/api/v1/wallet?apiKey=$($Config.Pools.$Name.API_Key)" -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if ($Request.code -eq 200) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

 $Request.data.balances.PSObject.Properties | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name} | Foreach-Object {
    [PSCustomObject]@{
        Caption     = "$($Name) ($($_.Name))"
        Currency    = $_.Name
        Balance     = [decimal]$_.Value.balance
        Pending     = 0
        Total       = [decimal]$_.Value.total
        Paid        = [decimal]$_.Value.paid
        Paid24h     = [decimal]$_.Value.paid24h
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
    }
}
