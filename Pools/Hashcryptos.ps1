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

$Pool_Request = [PSCustomObject]@{}

$headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://www.hashcryptos.com/api/status" -headers $headers -retry 3 -retrywait 500 -tag $Name -cycletime 120
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}

@("us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(

    [PSCustomObject]@{algo = "blake2s";   port = 4001; stratum = "stratum3.hashcryptos.com"; factor = 1e15}
    [PSCustomObject]@{algo = "c11";       port = 4002; stratum = "stratum4.hashcryptos.com"; factor = 1e12}
    [PSCustomObject]@{algo = "equihash";  port = 4003; stratum = "stratum4.hashcryptos.com"; factor = 1e6}
    [PSCustomObject]@{algo = "groestl";   port = 4004; stratum = "stratum3.hashcryptos.com"; factor = 1e12}
    [PSCustomObject]@{algo = "keccak";    port = 4005; stratum = "stratum3.hashcryptos.com"; factor = 1e12}
    [PSCustomObject]@{algo = "lyra2rev2"; port = 4006; stratum = "stratum3.hashcryptos.com"; factor = 1e9}
    [PSCustomObject]@{algo = "myrgro";    port = 4009; stratum = "stratum3.hashcryptos.com"; factor = 1e12}
    [PSCustomObject]@{algo = "neoscrypt"; port = 4010; stratum = "stratum1.hashcryptos.com"; factor = 1e6}
    [PSCustomObject]@{algo = "odocrypt";  port = 4029; stratum = "stratum2.hashcryptos.com"; factor = 1e6}
    [PSCustomObject]@{algo = "phi2";      port = 4030; stratum = "stratum4.hashcryptos.com"; factor = 1e6}
    [PSCustomObject]@{algo = "quark";     port = 4012; stratum = "stratum3.hashcryptos.com"; factor = 1e9}
    [PSCustomObject]@{algo = "qubit";     port = 4013; stratum = "stratum3.hashcryptos.com"; factor = 1e9}
    [PSCustomObject]@{algo = "scrypt";    port = 4000; stratum = "stratum2.hashcryptos.com"; factor = 1e9}
    [PSCustomObject]@{algo = "skein";     port = 4015; stratum = "stratum3.hashcryptos.com"; factor = 1e9}
    [PSCustomObject]@{algo = "x11";       port = 4018; stratum = "stratum1.hashcryptos.com"; factor = 1e12}
    [PSCustomObject]@{algo = "x11gost";   port = 4016; stratum = "stratum3.hashcryptos.com"; factor = 1e9}
    [PSCustomObject]@{algo = "yescrypt";  port = 4024; stratum = "stratum4.hashcryptos.com"; factor = 1e3}
)

$Pool_Currencies = @("BCH","BSV","BTC","DASH","DGB","DOGE","FTC","GRS","HATCH","LTC","MONA","NLG","RVN","SIB","XMY","XVG","ZEC") | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {([Double]$Pool_Request.$_.estimate_current  -gt 0) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $Pool_Request.$_.name
    if (-not ($Pool_Data = $Pools_Data | Where-Object {$_.algo -eq $Pool_Algorithm})) {
        Write-Log -Level Info "$($Name): no data avail for algorithm $Pool_Algorithm. "
        return
    }

    $Pool_Host = $Pool_Data.stratum
    $Pool_Port = $Pool_Data.port

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees

    $Pool_Factor = [Double]$Pool_Request.$_.mbtc_mh_factor
    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    if (-not $InfoOnly) {
        $NewStat = $false; if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$NewStat = $true; $DataWindow = "actual_last24h"}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $DataWindow -Factor $Pool_Factor -ActualDivisor 1
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $(-not $NewStat) -Actual24h $([double]$Pool_Request.$_.actual_last24h/1000) -Estimate24h $([double]$Pool_Request.$_.estimate_last24h) -HashRate ([Double]$Pool_Request.$_.hashrate * $Pool_Data.factor) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_RegionsTable.Keys) {
        foreach($Pool_Currency in $Pool_Currencies) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = ""
                CoinSymbol    = ""
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $Pool_Host
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "{diff:d=`$difficulty}$Pool_Params"
                Region        = $Pool_RegionsTable.$Pool_Region
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_PoolFee
                DataWindow    = $DataWindow
                Workers       = [int]$Pool_Request.$_.workers
                Hashrate      = $Stat.HashRate_Live
				ErrorRatio    = $Stat.ErrorRatio
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
