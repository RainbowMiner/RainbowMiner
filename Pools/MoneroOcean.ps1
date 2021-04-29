using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$Password = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly -and -not $Wallets.XMR -and -not $Password) {return}

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://rbminer.net/api/data/moneroocean.json" -tag $Name
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_PoolFee = 0.68 # cost for exchange

$Pool_CPUPort_Test = $Global:GlobalCPUInfo.Cores * $Global:GlobalCPUInfo.MaxClockSpeed * 4 / 1000
$Pool_CPUPort_Base = if ($Pool_CPUPort_Test -gt 0) {[Math]::Min([Math]::Pow(2,1+[Math]::Floor([Math]::Log($Pool_CPUPort_Test,2))),8192)} else {16}
$Pool_GPUPost_Test = $Global:DeviceCache.Devices.Where({$_.type -eq "gpu"}).Count
$Pool_GPUPort_Base = if ($Pool_GPUPost_Test -gt 1) {8192} else {1024}

$Pool_Request | Where-Object {($_.profit -gt 0.00 -and ($AllowZero -or $_.hashrate -gt 0)) -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_CoinSymbol = $_.coin
    $Pool_Coin = Get-Coin $Pool_CoinSymbol
    $Pool_Algorithm_Norm = if ($Pool_Coin) {$Pool_Coin.Algo} else {Get-Algorithm $_.algo}

    if (-not $InfoOnly) {
        $Pool_TSL = if ($_.tsl -ge 0) {$_.tsl} else {$null}
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value $_.profit -Duration $StatSpan -ChangeDetection $false -Difficulty $_.diff -HashRate $_.hashrate -BlockRate $_.blk24h -Quiet
    }

    $CPUPort_Base = if ($Pool_Algorithm_Norm -match "^Cucka") {1} else {$Pool_CPUPort_Base}
    $GPUPort_Base = if ($Pool_Algorithm_Norm -match "^Cucka") {1} else {$Pool_GPUPort_Base}

    foreach($Pool_Protocol in @("stratum+tcp","stratum+ssl")) {
        $Port = if ($Pool_Protocol -match "ssl") {20000} else {10000}
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = if ($Pool_Coin) {$Pool_Coin.Name} else {$Pool_CoinSymbol}
            CoinSymbol    = $Pool_CoinSymbol
            Currency      = "XMR"
            Price         = $Stat.$StatAverage
            StablePrice   = $Stat.$StatAverageStable
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = $Pool_Protocol
            Host          = "gulf.moneroocean.stream"
            Port          = $Port+$Pool_CPUPort_Base
            Ports         = [PSCustomObject]@{CPU=$Port+$CPUPort_Base; GPU=$Port+$GPUPort_Base; RIG=$Port+8192}
            User          = "$($Wallets.XMR)"
            Pass          = "{workername:$Worker}:$($Password)~$($_.algo)"
            Region        = Get-Region "US"
            SSL           = $Pool_Protocol -match "ssl"
            Updated       = $Stat.Updated
            #WTM           = $true
            PoolFee       = $Pool_PoolFee + $_.fee
            Workers       = $_.worker
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoIsEthash) {"ethstratumnh"} else {$null}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Wallets.XMR
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}