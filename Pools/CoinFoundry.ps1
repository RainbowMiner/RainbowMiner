using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region_Default = Get-Region "eu"

$Pools_Request       = [PSCustomObject]@{}
try {
    $Pools_Request = Invoke-RestMethodAsync "https://coinfoundry.org/api/pools" -tag $Name -timeout 15 -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
    return
}

$Pools_Ports = [PSCustomObject]@{
    bcd1 = @([PSCustomObject]@{CPU=3056;GPU=3056;RIG=3056})
    btg1 = @([PSCustomObject]@{CPU=3064;GPU=3064;RIG=3065})
    mona1= @([PSCustomObject]@{CPU=3092;GPU=3093;RIG=3094})
    rvn1 = @([PSCustomObject]@{CPU=3172;GPU=3172;RIG=3173})
    sin1 = @([PSCustomObject]@{CPU=3250;GPU=3251;RIG=3252})
    tube1= @([PSCustomObject]@{CPU=3150;GPU=3151;RIG=3152},[PSCustomObject]@{CPU=3153;GPU=3154;RIG=3155})
    vtc1 = @([PSCustomObject]@{CPU=3096;GPU=3097;RIG=3098})
    xmr1 = @([PSCustomObject]@{CPU=3032;GPU=3033;RIG=3034},[PSCustomObject]@{CPU=3132;GPU=3133;RIG=3134})
    zec1 = @([PSCustomObject]@{CPU=3036;GPU=3036;RIG=3037})
}

$Pools_Request | Where-Object {$Pools_Ports."$($_.id)"} | Where-Object {($Wallets."$($_.coin)" -and ($_.hashrate -or $AllowZero)) -or $InfoOnly} | ForEach-Object {
    $Pool_Currency       = $_.coin
    $Pool_RpcPath        = $_.id
    $Pool_Algorithm      = if ($_.algorithm -eq "x16r") {"x16rv2"} else {$_.algorithm}
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Ports          = $Pools_Ports."$($_.id)"
    $Pool_Fee            = $_.fee

    $Pool_Divisor        = 1

    $PoolBlocks_Request = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $PoolBlocks_Request = Invoke-RestMethodAsync "https://coinfoundry.org/api/pools/$($Pool_RpcPath)/blocks?page=0&pageSize=50" -body @{page=0;pageSize=50} -tag $Name -timeout 15 -delay 250 -cycletime 120
            if (-not $PoolBlocks_Request.success) {throw}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and -not $InfoOnly) {

        $timestamp      = (Get-Date).ToUniversalTime()
        $timestamp24h   = (Get-Date).AddHours(-24).ToUniversalTime()

        $Pool_Blocks    = $PoolBlocks_Request.result.created | Foreach-Object {Get-Date -date $_} | Sort-Object -Descending date
        $reward         = ($PoolBlocks_Request.result.reward | Where-Object {$_ -gt 0} | Select-Object -First 10 | Measure-Object -Average).Average
        $blocks_measure = $Pool_Blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $Pool_BLK       = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum).TotalDays) {1/($blocks_measure.Maximum - $blocks_measure.Minimum).TotalDays} else {1})*$blocks_measure.Count)            
        $Pool_TSL       = if ($Pool_Blocks.Count) {($timestamp - $Pool_Blocks[0]).TotalSeconds}

        $blocks         = $Pool_BLK
        $hashrate       = [int64]$_.hashrate

        $lastBTCPrice   = if ($Session.Rates.$Pool_Currency) {1/$Session.Rates.$Pool_Currency}

        if ($Stat = Get-Stat -Name "$($Name)_$($Pool_Currency)_Profit") {
            if ($Stat.BlockRate_Average) {$blocks   = $Stat.BlockRate_Average}
            if ($Stat.HashRate_Average)  {$hashrate = $Stat.HashRate_Average}
        }

        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($blocks*$reward*$lastBTCPrice/$hashrate) -Duration $StatSpan -ChangeDetection $false -HashRate ([int64]$_.hashrate) -BlockRate $Pool_BLK -Quiet
    }
    
    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        $Pool_Wallet = Get-WalletWithPaymentId $Wallets."$($_.coin)" -pidchar '#' -asobject
        foreach ($Pool_Port in $Pool_Ports) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $_.name
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_RpcPath -replace "\d").coinfoundry.org"
                Port          = $Pool_Port.CPU
                Ports         = $Pool_Port
                User          = "$($Pool_Wallet.wallet).{workername:$Worker}"
                Pass          = if ($Pool_Wallet.difficulty) {"d=$($Pool_Wallet.difficulty)"} else {"{diff:d=`$difficulty}"}
                Region        = $Pool_Region_Default
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $_.miners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                EthMode       = if ($Pool_Algorithm_Norm -match "^(Ethash|ProgPow)") {"minerproxy"} else {$null}
                AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Pool_Wallet.wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_SSL = $true
        }
    }
}
