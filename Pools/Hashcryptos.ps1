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

$Pool_Request = [PSCustomObject]@{}

$headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://hashcryptos.com/api/status" -headers $headers -retry 3 -retrywait 1000 -tag $Name -cycletime 120
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

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{algo = "blake2s";   port = 4001; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "equihash";  port = 4003; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "equihash192";  port = 6660; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "ghostrider";  port = 9997; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "groestl";   port = 4004; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "kawpow";  port = 9985; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "keccak";    port = 4005; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "lbry";  port = 9988; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "lyra2rev2"; port = 4006; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "memehash";  port = 9978; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "myrgro";    port = 4009; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "neoscrypt"; port = 4010; stratum = "stratum1.hashcryptos.com"}
    [PSCustomObject]@{algo = "odocrypt";  port = 4029; stratum = "stratum2.hashcryptos.com"}
    [PSCustomObject]@{algo = "qubit";     port = 4013; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "randomx";   port = 3339; stratum = "stratum1.hashcryptos.com"; factor = 1e-3}
    [PSCustomObject]@{algo = "scrypt";    port = 4000; stratum = "stratum2.hashcryptos.com"}
    [PSCustomObject]@{algo = "sha256";  port = 4014; stratum = "stratum1.hashcryptos.com"}
    [PSCustomObject]@{algo = "verthash";  port = 9991; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "x11";       port = 4018; stratum = "stratum1.hashcryptos.com"}
    [PSCustomObject]@{algo = "x11gost";   port = 4016; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "x13";   port = 9980; stratum = "stratum3.hashcryptos.com"}
    [PSCustomObject]@{algo = "yescrypt";  port = 4024; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "yescryptr16";  port = 4025; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "yescryptr32";  port = 9993; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "yespower";  port = 9986; stratum = "stratum4.hashcryptos.com"}
    [PSCustomObject]@{algo = "yespowerr16";  port = 9987; stratum = "stratum4.hashcryptos.com"}
)

#"`"$(@(([Regex]'value="(\w+)"').Matches('<select class="form-control"id="WalletCurrency"><option value="BCH">BCH BitcoinCashNode</option><option value="BSV">BSV BitcoinSV</option><option value="BTC" selected >BTC Bitcoin</option><option value="DASH">DASH Dash</option><option value="DGB">DGB Digibyte</option><option value="DOGE">DOGE Dogecoin</option><option value="FTC">FTC FeatherCoin</option><option value="GRS">GRS GroestlCoin</option><option value="LTC">LTC Litecoin</option><option value="MONA">MONA MonaCoin</option><option value="PEPEW">PEPEW PepePow</option><option value="RVN">RVN Ravencoin</option><option value="VTC">VTC Vertcoin</option><option value="XEC">XEC Ecash</option><option value="XMR">XMR Monero</option><option value="XMY">XMY Myriadcoin</option><option value="XVG">XVG Verge</option><option value="ZEC">ZEC Zcash</option></select>') | Foreach-Object {$_.Groups[1].Value}) -join '","')`""
#([Regex]'<strong>([^<]+)</strong> :</div><div class="col">([^<]+)').Matches('<div id="hashrates" class="col-10 my-auto d-block" style="white-space: nowrap;overflow-x: hidden; "><div id="hashratesInner" class="row d-block my-auto" style="overflow-x: hidden; width: 13998.4px; margin-left: 1330px;"><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Blake2s</strong> :</div><div class="col">3.16Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Equihash</strong> :</div><div class="col">68.67Msol/s<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Equihash192</strong> :</div><div class="col">-<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Ghostrider</strong> :</div><div class="col">144Khs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Groestl</strong> :</div><div class="col">9.79Ths<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Kawpow</strong> :</div><div class="col">3.81Ghs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Keccak</strong> :</div><div class="col">1.99Ths<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Lbry</strong> :</div><div class="col">36.06Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Lyra2rev2</strong> :</div><div class="col">54.82Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Memehash</strong> :</div><div class="col">25.37Mhs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Myrgro</strong> :</div><div class="col">782Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Neoscrypt</strong> :</div><div class="col">114Mhs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Odocrypt</strong> :</div><div class="col">160Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Qubit</strong> :</div><div class="col">1.16Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Randomx</strong> :</div><div class="col">91.96Khs<b class="text-danger"> NEW</b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Scrypt</strong> :</div><div class="col">4.97Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Sha256</strong> :</div><div class="col">1,258Phs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Verthash</strong> :</div><div class="col">5.16Mhs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X11</strong> :</div><div class="col">249Ths<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X11gost</strong> :</div><div class="col">336Mhs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X13</strong> :</div><div class="col">44.98Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yescrypt</strong> :</div><div class="col">45.78Khs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yescryptr16</strong> :</div><div class="col">655hs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yescryptr32</strong> :</div><div class="col">274hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yespower</strong> :</div><div class="col">4.85Khs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yespowerr16</strong> :</div><div class="col">10.80Khs<b class="text-danger"> </b></div></div></div></div></div>') | Foreach-Object {$Name = $_.Groups[1].Value;$Hashrate=ConvertFrom-Hash $_.Groups[2].Value;$Pool_Request.PSObject.Properties.Value | Where-Object {$_.name -eq $Name} | Foreach-Object {"$($Name) = $($_.hashrate_last24h) vs. $Hashrate vs. $($_.mbtc_mh_factor)"}}

$Pool_Currencies = @("BCH","BSV","BTC","DASH","DGB","DOGE","FTC","GRS","LTC","MONA","PEPEW","RVN","VTC","XEC","XMR","XMY","XVG","ZEC") | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {([Double]$Pool_Request.$_.estimate_current  -gt 0) -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $Pool_Request.$_.name
    if (-not ($Pool_Data = $Pools_Data | Where-Object {$_.algo -eq $Pool_Algorithm})) {
        Write-Log -Level Info "$($Name): no data avail for algorithm $Pool_Algorithm. "
        return
    }

    $Pool_Host = $Pool_Data.stratum
    $Pool_Port = $Pool_Request.$_.port

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees

    $Pool_Factor = [Double]$Pool_Request.$_.mbtc_mh_factor
    if ($Pool_Data.factor) {$Pool_Factor /= $Pool_Data.factor}

    if ($Pool_Factor -le 0) {
        Write-Log -Level Info "$($Name): Unable to determine divisor for algorithm $Pool_Algorithm. "
        return
    }

    if (-not $InfoOnly) {
        $OldStat = $true
        $Pool_DataWindow = if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$OldStat=$false;"actual_last24h"} else {$DataWindow}
        $Pool_Price = Get-YiiMPValue $Pool_Request.$_ -DataWindow $Pool_DataWindow -Factor $Pool_Factor -ActualDivisor 1
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value $Pool_Price -Duration $(if ($NewStat) {New-TimeSpan -Days 1} else {$StatSpan}) -ChangeDetection $OldStat -Actual24h $Pool_Request.$_.actual_last24h -Estimate24h $Pool_Request.$_.estimate_last24h -HashRate $Pool_Request.$_.hashrate -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Pool_Region in $Pool_Regions) {
        foreach($Pool_Currency in $Pool_Currencies) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = ""
                CoinSymbol    = ""
                Currency      = $Pool_Currency
                Price         = $Stat.$StatAverage #instead of .Live
                StablePrice   = $Stat.$StatAverageStable
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $Pool_Host
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_Currency).{workername:$Worker}"
                Pass          = "n={workername:$Worker}{diff:,d=`$difficulty}$Pool_Params"
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
                Disabled      = $false
                HasMinerExclusions = $false
                Price_0       = 0.0
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Wallets.$Pool_Currency
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
        }
    }
}
