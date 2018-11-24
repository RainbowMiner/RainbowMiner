using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Region = "us"

$Pools_Data = @(
    [PSCustomObject]@{coin = "FreeHaven"; symbol = "XFH"; algo = "CnFreeHaven"; port = 33022; fee = 0.5; livestats = "freehaven.pocketwhale.info:8099"; host = "freehaven.pocketwhale.info"}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath = $_.livestats
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm

    $Pool_Port = 0
    $Pool_Fee  = $_.fee

    $Pool_Request = [PSCustomObject]@{}
    $Pool_Ports   = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath)/live_stats" -tag $Name -timeout 15
            $Pool_Port = $Pool_Request.config.ports | Where-Object desc -match '(Mid|High)' | Select-Object -First 1 -ExpandProperty port
            @("CPU","GPU","RIG") | Foreach-Object {
                $PortType = $_
                $PortMatch = Switch ($PortType) {
                    "CPU" {"Mid"}
                    "GPU" {"High"}
                    "RIG" {"Very High"}
                    default {"Mid"}
                }
                $Pool_Request.config.ports | Where-Object desc -match $PortMatch | Select-Object -First 1 -ExpandProperty port | Foreach-Object {$Pool_Ports | Add-Member $PortType $_ -Force}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
            $ok = $false
        }
    }

    if ($ok -and $Pool_Port -and -not $InfoOnly) {
        $Pool_Fee = $Pool_Request.config.fee

        $timestamp    = Get-UnixTimestamp
        $timestamp24h = $timestamp - 24*3600

        $diffLive     = $Pool_Request.network.difficulty
        $reward       = $Pool_Request.network.reward
        $profitLive   = 86400/$diffLive*$reward
        $coinUnits    = $Pool_Request.config.coinUnits
        $amountLive   = $profitLive / $coinUnits

        $lastSatPrice = [Double]@($Pool_Request.charts.price | Select-Object -Last 1)[1]
        $satRewardLive = $amountLive * $lastSatPrice

        $amountDay = 0.0
        $satRewardDay = 0.0

        $Divisor = 1e8

        $averageDifficulties = ($Pool_Request.charts.difficulty | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average
        if ($averageDifficulties) {
            $averagePrices = ($Pool_Request.charts.price | Select-Object | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average
            if ($averagePrices) {
                $profitDay = 86400/$averageDifficulties * $reward
                $amountDay = $profitDay/$coinUnits
                $satRewardDay = $amountDay * $averagePrices
            }
        }

        $blocks = $Pool_Request.pool.blocks | Where-Object {$_ -match '^.*?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
        $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $Pool_BLK = [int]$(if ($blocks_measure.Maximum - $blocks_measure.Minimum) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)*$blocks_measure.Count})
        $Pool_TSL = if ($blocks.Count) {$timestamp - $blocks[0]}
            
        if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Currency)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardDay/$Divisor) -Duration (New-TimeSpan -Days 1) -HashRate ($Pool_Request.charts.hashrate | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average -BlockRate $Pool_BLK -Quiet}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value ($satRewardLive/$Divisor) -Duration $StatSpan -ChangeDetection $false -HashRate $Pool_Request.pool.hashrate -BlockRate $Pool_BLK -Quiet}
    }
    
    if (($ok -and $Pool_Port -and ($AllowZero -or $Pool_Request.pool.hashrate -gt 0)) -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $_.coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $_.host
            Port          = if (-not $Pool_Port) {$_.port} else {$Pool_Port}
            Ports         = $Pool_Ports
            User          = "$($Wallets.$($_.symbol)){diff:.`$difficulty}"
            Pass          = "{workername:$Worker}"
            Region        = $Pool_Region
            SSL           = $False
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Request.pool.miners
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
        }
    }
}
