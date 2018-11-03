param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

if (-not $Config.Pools.$Name.API_Key -or -not $Config.Pools.$Name.API_Secret) {return}

$Request = Invoke-MiningRigRentalRequest "/account/balance" $Config.Pools.$Name.API_Key $Config.Pools.$Name.API_Secret
if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool Balance API ($Name) for $($_.Name) returned nothing. "
}

$Request.PSObject.Properties.Name | Foreach-Object {
    [PSCustomObject]@{
        Caption     = "$($Name) ($($_))"
        Currency    = $_
        Balance     = [Double]$Request.$_.confirmed
        Pending     = [Double]$Request.$_.unconfirmed
        Total       = [Double]$Request.$_.confirmed + [Double]$Request.$_.unconfirmed
        Payed       = 0
        Earned      = 0
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
     }
}
