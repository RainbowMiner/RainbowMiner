using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 1.5

$Pool_Request = [PSCustomObject]@{}
try {
    $Pool_Request = Invoke-RestMethodAsync "https://stats.solopool.org" -tag $Name -cycletime 120
}
catch {
    if ($Global:Error.Count){$Global:Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}
@("eu","us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request.PSObject.Properties.Name | Where-Object {$Pool_Currency = $_.ToUpper();($Wallets.$Pool_Currency -or ($Pool_Currency -eq "FIRO" -and $Wallets.XZC) -or $InfoOnly) -and $_ -notmatch "^dgb-"} | ForEach-Object {

    $Pool_Coin = Get-Coin $Pool_Currency

    $Pool_Algorithm_Norm = $Pool_Coin.Algo
    $Pool_CoinName  = $Pool_Coin.Name

    if (-not ($Pool_Wallet = $Wallets.$Pool_Currency)) {
        $Pool_Wallet = $Wallets.XZC
    }

    $ok = $false
    try {
        $Pool_HelpPage = Invoke-WebRequestAsync "https://$($_).solopool.org/help" -tag $Name -cycletime 86400
        if ($Pool_HelpPage -match 'meta\s+name="\w+/config/environment"\s+content="(.+?)"') {
            $Pool_MetaVars = [System.Web.HttpUtility]::UrlDecode($Matches[1]) | ConvertFrom-Json -ErrorAction Stop
            $ok = $true
            if (-not $Pool_Coin) {
                $Pool_Algorithm_Norm = Get-Algorithm $Pool_MetaVars.TEMPLATE.algoTitle -CoinSymbol $Pool_Currency
                $Pool_CoinName  = $Pool_MetaVars.TEMPLATE.title
            }
        }
    } catch {
        Write-Log -Level Warn "$($Name): $($Pool_Currency) help page not readable"
    }

    if (-not $Pool_Algorithm_Norm) {
        Write-Log -Level Warn "Pool $($Name) missing coin $($Pool_Currency)"
        return
    }

    $Pool_User = "$Pool_Wallet.{workername:$Worker}"
    $Pool_Pass = "x"

    $Pool_PoolFee   = $Pool_Request.$_.fee

    $Pool_EthProxy  = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsProgPow) {"stratum"} else {$null}

    $Pool_Hosts = $Pool_RegionsTable.Keys | Where-Object {$Pool_MetaVars.TEMPLATE."stratumHost$($_.toUpper())"} | Foreach-Object {[PSCustomObject]@{region=$_;host=$Pool_MetaVars.TEMPLATE."stratumHost$($_.toUpper())";port=$Pool_MetaVars.TEMPLATE."stratumPort$(if ($Pool_MetaVars.TEMPLATE.stratumPortGpu) {"Gpu"} else {"Low"})"}}

    if ($ok -and -not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -Difficulty $Pool_Request.$_.difficulty -Quiet
    }

    if ($ok -or $InfoOnly) {
        foreach($Pool_Host in $Pool_Hosts) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = $Pool_Host.host
                Port          = $Pool_Host.port
                User          = $Pool_User
                Pass          = $Pool_Pass
                Region        = $Pool_RegionsTable[$Pool_Host.region]
                SSL           = $false
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_PoolFee
                Workers       = $null
                Hashrate      = $null
                BLK           = $null
                TSL           = $null
                Difficulty    = $Stat.Diff_Average
                SoloMining    = $true
                WTM           = $true
                EthMode       = $Pool_EthProxy
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_Wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
