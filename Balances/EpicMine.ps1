using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

$API_Key    = "$($PoolConfig.API_Key)".Trim()
$API_Secret = "$($PoolConfig.API_Secret)".Trim()

if ($API_Key -and $API_Secret) {

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://api.epicmine.io/user/getbalances" -cycletime ($Config.BalanceUpdateMinutes*60) -headers @{Authorization="Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($API_Key):$($API_Secret)")))"}
    }
    catch {
        Write-Log -Level Warn "Pool Balance API ($Name) has failed. "
        return
    }

    if ($Request.error) {
        Write-Log -Level Warn "Pool Balance API ($Name) has failed: $($Request.error)"
        return
    }

    if ($Request) {
        [PSCustomObject]@{
            Caption     = "$($Name) (EPIC)"
            BaseName    = $Name
            Name        = $Name
            Currency    = "EPIC"
            Balance     = [Decimal]$Request.available
            Pending     = [Decimal]$Request.locked + [Decimal]$Request.pending
            Total       = [Decimal]$Request.available + [Decimal]$Request.locked + [Decimal]$Request.pending
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }        
    }
}
