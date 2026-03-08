using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$PoolConfig = $Config.Pools.$Name

if ($PoolConfig.API_Key -and $PoolConfig.API_Secret) {

    $Request = [PSCustomObject]@{}

    try {
        $Request = Invoke-RestMethodAsync "https://api.epicmine.io/user/getbalances" -cycletime ($Config.BalanceUpdateMinutes*60) -headers @{Authorization="Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($PoolConfig.API_Key):$($PoolConfig.API_Secret)")))"}
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
            Pending     = [Decimal]$RequestUnpaid.locked + [Decimal]$RequestUnpaid.pending
            Total       = [Decimal]$Request.available + [Decimal]$RequestUnpaid.locked + [Decimal]$RequestUnpaid.pending
            Payouts     = @()
            LastUpdated = (Get-Date).ToUniversalTime()
        }        
    }
}
