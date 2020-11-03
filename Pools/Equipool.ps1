param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

$ok = $false
try {
    $Pool_Request = Invoke-RestMethodAsync "https://equipool.1ds.us/api/stats" -tag $Name -cycletime 120
    if ($Pool_Request.time -and ($Pool_Request.pools.PSObject.Properties.Name | Measure-Object).Count) {$ok = $true}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
}

if (-not $ok) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

[hashtable]$Pool_Algorithms = @{}

[hashtable]$Pool_RegionsTable = @{}
@("na","eu","asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

#port strategy:
#   na = port      na-ssl = port+1
#   eu = port+3    eu-ssl = port+4
# asia = port+6  asia-ssl = port+7
#stratum strategy:
#  coinsymbol(lowercase)-region.equipool.1ds.us

$Pools_Data =  @(
    [PSCustomObject]@{symbol = "ANON"; port = @(35140,35141); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "BTCZ"; port = @(35060,35061); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "BTCZ"; port = @(35063,35064); fee = 1.0; region = "eu"}
    [PSCustomObject]@{symbol = "BTCZ"; port = @(35066,35067); fee = 1.0; region = "asia"}
    [PSCustomObject]@{symbol = "BUCK"; port = @(35100,35101); fee = 5.0; region = "na"}
    [PSCustomObject]@{symbol = "GENX"; port = @(35130,35131); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "GENX"; port = @(35133,35134); fee = 1.0; region = "eu"}
    [PSCustomObject]@{symbol = "GENX"; port = @(35136,35137); fee = 1.0; region = "asia"}
    [PSCustomObject]@{symbol = "LTZ";  port = @(35090,35091); fee = 5.0; region = "na"}
    [PSCustomObject]@{symbol = "LTZ";  port = @(35093,35094); fee = 5.0; region = "eu"}
    [PSCustomObject]@{symbol = "SAFE"; port = @(35110,35111); fee = 0.99; region = "na"}
    [PSCustomObject]@{symbol = "SAFE"; port = @(35113,35114); fee = 0.99; region = "na"}
    [PSCustomObject]@{symbol = "SAFE"; port = @(35116,35117); fee = 0.99; region = "na"}
    [PSCustomObject]@{symbol = "XSG";  port = @(35080,35081); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "XSG";  port = @(35083,35084); fee = 1.0; region = "eu"}
    [PSCustomObject]@{symbol = "XSG";  port = @(35086,35087); fee = 1.0; region = "asia"}
    [PSCustomObject]@{symbol = "VOT";  port = @(35070,50071); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "YEC";  port = @(35150,35151); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "ZEC";  port = @(35000,35001); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "ZEL";  port = @(35050,35051); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "ZEL";  port = @(35053,35054); fee = 1.0; region = "eu"}
    [PSCustomObject]@{symbol = "ZEL";  port = @(35056,35057); fee = 1.0; region = "asia"}
    [PSCustomObject]@{symbol = "ZEN";  port = @(35040,35041); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "ZER";  port = @(35020,35021); fee = 1.0; region = "na"}
    [PSCustomObject]@{symbol = "ZER";  port = @(35023,35024); fee = 1.0; region = "eu"}
)
	
$Pool_Request.pools.PSObject.Properties.Value | Where-Object {($Wallets."$($_.symbol)" -and ($_.hashrate -gt 0 -or $AllowZero)) -or $InfoOnly} | ForEach-Object {

    $Pool_CoinSymbol = $_.symbol

    $Pool_Data = $Pools_Data | Where-Object {$_.symbol -eq $Pool_CoinSymbol}

    if (-not $Pool_Data) {Write-Log -Level Warn "No pooldata for $Pool_CoinSymbol found"; return}

    $Pool_Coin = Get-Coin $Pool_CoinSymbol

    if (-not $Pool_Coin) {Write-Log -Level Warn "Coin $Pool_CoinSymbol not found"; return}

    $Pool_Algorithm = $Pool_Coin.Algo
    if (-not $Pool_Algorithms.ContainsKey($Pool_Algorithm)) {$Pool_Algorithms.$Pool_Algorithm = Get-Algorithm $Pool_Algorithm}
    $Pool_Algorithm_Norm = $Pool_Algorithms.$Pool_Algorithm

    $Pool_DataWindow = $DataWindow

    $Pool_Fee = [double]($_.poolFee.PSObject.Properties.Value | Measure-Object -Sum).Sum

    if (-not $InfoOnly) {
        $Pool_BLK = if ($_.maxRoundTime -gt 0) {86400/$_.maxRoundTime}
        $Stat = Set-Stat -Name "$($Name)_$($Pool_CoinSymbol)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $_.hashrate -BlockRate $Pool_BLK -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    foreach($Data in @($Pool_Data)) {
        $Pool_Ssl = $false
        foreach($Pool_Port in $Data.port) {
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                Algorithm0    = $Pool_Algorithm_Norm
                CoinName      = $Pool_Coin.Name
                CoinSymbol    = $Pool_CoinSymbol
                Currency      = $Pool_CoinSymbol
                Price         = 0
                StablePrice   = 0
                MarginOfError = 0
                Protocol      = "stratum+tcp"
                Host          = "$($Pool_CoinSymbol.ToLower())-$($Data.region).equipool.1ds.us"
                Port          = $Pool_Port
                User          = "$($Wallets.$Pool_CoinSymbol).{workername:$Worker}"
                Pass          = "x"
                Region        = $Pool_RegionsTable[$Data.region]
                SSL           = $Pool_Ssl
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = $Pool_Fee
                DataWindow    = $Pool_DataWindow
                Workers       = $_.workerCount
                Hashrate      = $Stat.HashRate_Live
                BLK           = $Stat.BlockRate_Average
                TSL           = $null
		        ErrorRatio    = $Stat.ErrorRatio
                WTM           = $true
                Name          = $Name
                Penalty       = 0
                PenaltyFactor = 1
                Disabled      = $false
                HasMinerExclusions = $false
                Price_Bias    = 0.0
                Price_Unbias  = 0.0
                Wallet        = $Pool_User
                Worker        = "{workername:$Worker}"
                Email         = $Email
            }
            $Pool_Ssl = $true
        }
    }
}
