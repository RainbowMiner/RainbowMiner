param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Request = [PSCustomObject]@{}

if (-not $Config.Pools.$Name.API_Key -or -not $Config.Pools.$Name.API_Secret) {return}

$Request = Invoke-MiningRigRentalRequest "/account/balance" $Config.Pools.$Name.API_Key $Config.Pools.$Name.API_Secret
if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
}

$Request.PSObject.Properties.Name | Foreach-Object {
    [PSCustomObject]@{
        Caption     = "$($Name) ($($_))"
		BaseName    = $Name
        Currency    = $_
        Balance     = [Decimal]$Request.$_.confirmed
        Pending     = [Decimal]$Request.$_.unconfirmed
        Total       = [Decimal]$Request.$_.confirmed + [Decimal]$Request.$_.unconfirmed
        Paid        = [Decimal]0
        Earned      = [Decimal]0
        Payouts     = @()
        LastUpdated = (Get-Date).ToUniversalTime()
     }
}
