#
# Get-BalancesContent
#

function Get-BalancesContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    [Hashtable]$Parameters = @{
        Config  = $Config
    }

    $possiblePools = Get-ChildItem "Pools" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | Where-Object {($Config.PoolName.Count -eq 0 -or $Config.PoolName -icontains $_) -and ($Config.ExcludePoolName -eq 0 -or $Config.ExcludePoolName -inotcontains $_)}

    Get-ChildItem "Balances" -File -ErrorAction Ignore | Where-Object {
        $possiblePools -match "^$($_.BaseName)`(AE|Coins|CoinsSolo|CoinsParty|Party|PPS|Solo`)?$" -or $Config.ShowPoolBalancesExcludedPools -or $_.BaseName -eq "Wallet"
    } | Foreach-Object {
        $scriptPath = $_.FullName
        $scriptName = $_.BaseName

        if (-not $Config.ShowPoolBalancesExcludedPools -and $scriptName -ne "Wallet") {
            $Parameters["UsePools"] = $possiblePools -match "^$($scriptName)`(AE|Coins|CoinsSolo|CoinsParty|Party|PPS|Solo`)?$"
        } else {
            $Parameters["UsePools"] = $null
        }

        $Parameters["Name"] = $scriptName

        & $scriptPath @Parameters
    }
}