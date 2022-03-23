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

$Pool_Regions = @("us")
$Pool_Regions | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

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

#"`"$(@(([Regex]'value="(\w+)"').Matches('<select class="form-control"id="WalletCurrency"><option value="BCH">BCH BitcoinCashABC</option><option value="BSV">BSV BitcoinSV</option><option value="BTC" selected >BTC Bitcoin</option><option value="DASH">DASH Dash</option><option value="DGB">DGB Digibyte</option><option value="DOGE">DOGE Dogecoin</option><option value="FTC">FTC FeatherCoin</option><option value="GRS">GRS GroestlCoin</option><option value="HATCH">HATCH Hatch</option><option value="LTC">LTC Litecoin</option><option value="MONA">MONA MonaCoin</option><option value="NLG">NLG Gulden</option><option value="RVN">RVN Ravencoin</option><option value="SIB">SIB Siberianchervonets</option><option value="XMY">XMY Myriadcoin</option><option value="XVG">XVG Verge</option><option value="ZEC">ZEC Zcash</option></select>') | Foreach-Object {$_.Groups[1].Value}) -join '","')`""
#([Regex]'<strong>([^<]+)</strong> :</div><div class="col">([^<]+)').Matches('<div id="hashrates" class="col-10 my-auto d-block" style="white-space: nowrap;overflow-x: hidden; "><div id="hashratesInner" class="row d-block my-auto" style="overflow-x: hidden; width: 19368px; margin-left: 475.053px;"><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Blake2s</strong> :</div><div class="col">159Ths<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>C11</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Cryptonight</strong> :</div><div class="col">2.76Mhs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Equihash</strong> :</div><div class="col">136Msol/s<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Equihash192</strong> :</div><div class="col">-<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Groestl</strong> :</div><div class="col">3.34Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Kawpow</strong> :</div><div class="col">11.28Ghs<b class="text-danger"> New</b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Keccak</strong> :</div><div class="col">1.20Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Lbry</strong> :</div><div class="col">17.26Ths<b class="text-danger"> New</b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Lyra2rev2</strong> :</div><div class="col">563Ghs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Lyra2rev3</strong> :</div><div class="col">16.22Mhs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Myrgro</strong> :</div><div class="col">31.85Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Neoscrypt</strong> :</div><div class="col">8.58Mhs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Nist5</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Odocrypt</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Phi2</strong> :</div><div class="col">-<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Quark</strong> :</div><div class="col">1.67Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Qubit</strong> :</div><div class="col">6.76Ths<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Scrypt</strong> :</div><div class="col">842Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Sha256</strong> :</div><div class="col">68.79Phs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Skein</strong> :</div><div class="col">50.72Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Skunk</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Tribus</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Verthash</strong> :</div><div class="col">-<b class="text-danger"> New</b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X11</strong> :</div><div class="col">25.65Ths<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X11gost</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X13</strong> :</div><div class="col">9.28Ghs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X13bcd</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X16r</strong> :</div><div class="col">125Mhs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X16s</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>X17</strong> :</div><div class="col">0.00hs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yescrypt</strong> :</div><div class="col">441Khs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yescryptr16</strong> :</div><div class="col">1.07Khs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yescryptr32</strong> :</div><div class="col">42.35hs<b class="text-danger"> </b></div></div></div><div class="hashrateEl col-2 fs-8 border-right" style="display: inline-block;float: none;max-width:300px!important"><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yespower</strong> :</div><div class="col">8.25Khs<b class="text-danger"> </b></div></div><div class="row" style="font-size:0.85em;"><div class="col text-right"><strong>Yespowerr16</strong> :</div><div class="col">4.85Khs<b class="text-danger"> </b></div></div></div></div></div>') | Foreach-Object {$Name = $_.Groups[1].Value;$Hashrate=ConvertFrom-Hash $_.Groups[2].Value;$Pool_Request.PSObject.Properties.Value | Where-Object {$_.name -eq $Name} | Foreach-Object {"$($Name) = $($_.hashrate_last24h) vs. $Hashrate vs. $($_.mbtc_mh_factor)"}}

$Pool_Currencies = @("BCH","BSV","BTC","DASH","DGB","DOGE","FTC","GRS","HATCH","LTC","MONA","NLG","RVN","SIB","VTC","XMY","XVG","ZEC") | Select-Object -Unique | Where-Object {$Wallets.$_ -or $InfoOnly}

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
