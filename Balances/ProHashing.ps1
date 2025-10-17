using module ..\Modules\Include.psm1

param(
    [String]$Name,
    $Config,
    $UsePools
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Users = @(foreach($PoolExt in @("","Coins","CoinsSolo")) {
    if (-not $UsePools -or "$($Name)$($PoolExt)" -in $UsePools) {
        if ($Config.Pools."$($Name)$($PoolExt)".User -and $Config.Pools."$($Name)$($PoolExt)".API_Key) {
            [PSCustomObject]@{User=$Config.Pools."$($Name)$($PoolExt)".User;API_Key=$Config.Pools."$($Name)$($PoolExt)".API_Key}
        }
    }
}) | Sort-Object User,API_Key -Unique

if (-not $Pool_Users) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no usernames specified. "
    return
}

$Pool_Users | Foreach-Object {

    $Pool_User = $_.User

    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-RestMethodAsync "https://prohashing.com/api/v1/wallet?apiKey=$($_.API_Key)" -tag $Name -cycletime 120
    }
    catch {
    }

    if ($Request.code -ne 200) {
        Write-Log -Level Warn "Pool API ($Name) has failed for user $($Pool_User). "
        return
    }

    $Info =  "$(if (($Pool_Users | Measure-Object).Count -gt 1) {$Pool_User})"
    $Request.data.balances.PSObject.Properties | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name} | Foreach-Object {
        [PSCustomObject]@{
            Caption     = "$($Name) $($Pool_User) ($($_.Name))"
            BaseName    = $Name
            Name        = $Name + $Info
            Info        = $Info
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
}
