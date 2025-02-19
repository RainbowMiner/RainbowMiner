using module ..\Modules\Include.psm1

param(
    $Config,
    $UsePools
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Users = @([PSCustomObject]@{User=$Config.Pools.$Name.User;API_Key=$Config.Pools.$Name.API_Key}) + [PSCustomObject]@{User=$Config.Pools."$($Name)Coins".User;API_Key=$Config.Pools."$($Name)Coins".API_Key} + [PSCustomObject]@{User=$Config.Pools."$($Name)CoinsSolo".User;API_Key=$Config.Pools."$($Name)CoinsSolo".API_Key} | Where-Object {$_.User -and $_.API_Key} | Select-Object User,API_Key -Unique | Sort-Object User 


$Pool_Users = @()
foreach($PoolExt in @("","Coins","CoinsSolo")) {
    if (-not $UsePools -or "$($Name)$($PoolExt)" -in $UsePools) {
        $Pool_Users += [PSCustomObject]@{User=$Config.Pools."$($Name)$($PoolExt)".User;API_Key=$Config.Pools."$($Name)$($PoolExt)".API_Key}
    }
}

$Pool_Users = $Pool_Users | Where-Object {$_.User -and $_.API_Key} | Select-Object User,API_Key -Unique | Sort-Object User 

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
        if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    }

    if ($Request.code -ne 200) {
        Write-Log -Level Warn "Pool API ($Name) has failed for user $($Pool_User). "
        return
    }

     $Request.data.balances.PSObject.Properties | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Name} | Foreach-Object {
        [PSCustomObject]@{
            Caption     = "$($Name) $($Pool_User) ($($_.Name))"
            Info        = "$(if (($Pool_Users | Measure-Object).Count -gt 1) {$Pool_User})"
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
