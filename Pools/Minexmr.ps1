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

$Pool_Currency  = "XMR"
$Pool_CoinName  = "Monero"
$Pool_Algorithm_Norm = Get-Algorithm "Monero"
$Pool_Fee       = 1.0

if (-not $Wallets.$Pool_Currency -and -not $InfoOnly) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}

@("eu","ca","sg") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request = [PSCustomObject]@{}
$Pool_Ports   = @([PSCustomObject]@{})

if (-not $InfoOnly) {
    $Pool_Ports_Ok = $false
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://minexmr.com/api/pool/stats" -tag $Name -timeout 15 -cycletime 120
        @("CPU","GPU","RIG","CPU-SSL","GPU-SSL","RIG-SSL") | Foreach-Object {
            $PortType = $_ -replace '-.*$'
            $Ports = if ($_ -match 'SSL') {$Pool_Request.config.ports | Where-Object {$_.ssl -or $_.desc -match "SSL"}} else {$Pool_Request.config.ports | Where-Object {-not $_.ssl -and $_.desc -notmatch "SSL"}}
            if ($Ports) {
                $PortIndex = if ($_ -match 'SSL') {1} else {0}
                $Port = Switch ($PortType) {
                    "GPU" {$Ports | Where-Object desc -match 'Mid' | Select-Object -First 1}
                    "RIG" {$Ports | Where-Object desc -match 'High' | Select-Object -First 1}
                }
                if (-not $Port) {$Port = $Ports | Select-Object -First 1}
                if ($Pool_Ports.Count -eq 1 -and $PortIndex -eq 1) {$Pool_Ports += [PSCustomObject]@{}}
                $Pool_Ports[$PortIndex] | Add-Member $PortType ($Port.port -replace ',.+$') -Force
                $Pool_Ports_Ok = $true
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        return
    }
    if (-not $Pool_Ports_Ok) {
        $Pool_Ports = @([PSCustomObject]@{CPU=4444;GPU=7777;RIG=3333},[PSCustomObject]@{CPU=6666;GPU=6666;RIG=6666})
    }
    $Pool_Fee = $Pool_Request.config.fee + $(if ($Pool_Request.config.doDonations) {$Pool_Request.config.coreDonation} else {0})
}

if (-not $InfoOnly) {

    $timestamp    = Get-UnixTimestamp
    $timestamp24h = $timestamp - 24*3600

    $coinUnits    = 1e12
    $Divisor      = 1e8

    $lastSatPrice = if ($Session.Rates.$Pool_Currency) {1/$Session.Rates.$Pool_Currency*1e8} elseif ($Pool_Request.charts.price) {[Double]($Pool_Request.charts.price | Select-Object -Last 1)[1]} else {0}

    $diffLive     = $Pool_Request.network.difficulty
    $reward       = $Pool_Request.network.reward
    $profitLive   = 86400/$diffLive * $reward/$coinUnits
    $satRewardLive= $profitLive * $lastSatPrice

    $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.*?\:(\d+?)\:(\d+?)\:.*?(\d+?)\:(\d+?)$'} | Foreach-Object {[PSCustomObject]@{Time=[int64]$Matches[1];Diff=[int64]$Matches[2];Reward=if($Matches[3] -ne "0"){[int64]$Matches[4]} else {$reward}}} | Where-Object {$_.Time -gt $timestamp24h} | Sort-Object Time -Descending
    $blocks_measure = $blocks | Select-Object -ExpandProperty Time | Measure-Object -Minimum -Maximum
    $Pool_BLK = [int]$(if ($blocks_measure.Maximum - $blocks_measure.Minimum) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)*$blocks_measure.Count})
    $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0].Time}
    
    if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {
        $satRewardDay = 0.0
        $diffDay = ($blocks | Select-Object -ExpandProperty Diff | Measure-Object -Average).Average
        if ($diffDay) {
            $reward      = ($blocks | Select-Object -ExpandProperty Reward | Measure-Object -Average).Average
            $profitDay   = 86400/$diffDay * $reward/$coinUnits
            $satRewardDay= $profitDay * $lastSatPrice
        }
        if (-not $satRewardDay) {$satRewardDay=$satRewardLive}
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet
    } else {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet
    }
}

if ($AllowZero -or $Pool_Request.pool.hashrate -gt 0 -or $InfoOnly) {
    $Pool_SSL = $false
    $Pool_Wallet = Get-WalletWithPaymentId $Wallets.$Pool_Currency -pidchar '.'
    foreach ($Pool_Port in $Pool_Ports) {
        foreach($Pool_Region in $Pool_RegionsTable.Keys) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = $Pool_CoinName
                CoinSymbol    = $Pool_Currency
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                Host          = "$(if ($Pool_Region -eq "eu") {"pool"} else {$Pool_Region}).minexmr.com"
                Port          = $Pool_Port.CPU
                Ports         = $Pool_Port
                User          = "$($Pool_Wallet.wallet).{workername:$Worker}$(if ($Pool_Wallet.difficulty) {"+$($Pool_Wallet.difficulty)"} else {"{diff:+`$difficulty}"})"
                Pass          = "x"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $Pool_SSL
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Workers       = $Pool_Request.pool.miners
                Hashrate      = $Stat.HashRate_Live
                TSL           = $Pool_TSL
                BLK           = $Stat.BlockRate_Average
                AlgorithmList = if ($Pool_Algorithm_Norm -match "-") {@($Pool_Algorithm_Norm, ($Pool_Algorithm_Norm -replace '\-.*$'))}else{@($Pool_Algorithm_Norm)}
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Pool_Wallet.wallet
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
        $Pool_SSL = $true
    }
}
