param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if (!$PoolConfig.GRIN) {
    Write-Log -Level Verbose "Pool Balance API ($Name) has failed - no wallet address specified."
    return
}

$Request = [PSCustomObject]@{}

try {
    if ($Request = Invoke-RestMethodAsync "https://api.grinmint.com/v1/user/$($PoolConfig.GRIN)/userStats" -cycletime ($Config.BalanceUpdateMinutes*60)) {
        if ($Request.status) {
            $Unpaid   = $Request.unpaid_balance / 1e9
            $Immature = $Request.immature_balance / 1e9
            [PSCustomObject]@{
                    Caption     = $Name
                    Info        = ""
                    Currency    = "GRIN"
                    Balance     = $Unpaid
                    Pending     = $Immature
                    Total       = $Unpaid + $Immature
                    Paid        = 0
                    Earned      = 0
                    Payouts     = @()
                    LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}
