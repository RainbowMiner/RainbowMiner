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
    [String]$StatAverageStable = "Week",
    [String]$Password = "x"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

[hashtable]$Pool_RegionsTable = @{}
@("eu","us") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pools_Data = @(
    [PSCustomObject]@{symbol = "FLUX"; port = @(7011); fee = 1.0; rpc = "flux";  stratum = "flux.fluxpools.net"; regions = @("eu","us"); altsymbol = "ZEL"}
)

$Pools_Requests = [hashtable]@{}

if (-not $Password) {$Password = "x"}

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or ($_.altsymbol -and $Wallets."$($_.altsymbol)") -or $InfoOnly} | ForEach-Object {
    $Pool_Coin          = Get-Coin $_.symbol
    $Pool_Currency      = $_.symbol
    $Pool_Fee           = $_.fee
    $Pool_RpcPath       = $_.rpc
    $Pool_Name          = $Pool_RpcPath

    if (-not ($Pool_Wallet = $Wallets."$($_.symbol)")) {
        $Pool_Wallet = $Wallets."$($_.altsymbol)"
    }

    $Pool_Regions       = $_.regions

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.Algo

    $Pool_Request  = [PSCustomObject]@{}
    $Pool_BLK      = $null
    $Pool_TSL      = $null

    $ok = $true

    if ($ok -and -not $InfoOnly) {
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($Pool_RpcPath).fluxpools.net/api/homestats" -tag $Name -cycletime 240 -timeout 30
            if ($Pool_Request -is [string]) {
                $Pool_Request = $Pool_Request -replace '"currentRoundShares":{[^}]+},*' | ConvertFrom-Json -ErrorAction Stop
            }
            if (-not ($Pool_Request.pools.PSObject.Properties.Name | Measure-Object).Count) {$ok = $false}
            else {
                $Pool_Name      = "$($Pool_Request.pools.PSObject.Properties.Name | Select-Object -First 1)"
                $timestamp      = Get-UnixTimestamp
                $timestamp24h   = ($timestamp - 24*3600)*1000
                $blocks         = @($Pool_Request.pools.$Pool_Name.block.blocktable.pendingblocks | Foreach-Object {($_ -split ":")[4]} | Where-Object {$_ -ge $timestamp24h}) + @($Pool_Request.pools.$Pool_Name.block.blocktable.confirmedblocks | Foreach-Object {($_ -split ":")[4]} | Where-Object {$_ -ge $timestamp24h}) | Sort-Object -Descending
                $blocks_measure = $blocks | Measure-Object -Minimum -Maximum
                $Pool_BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600000/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
                $Pool_TSL = if ($blocks.Count) {[int]($timestamp - $blocks[0]/1000)}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ok = $false
        }
        if (-not $ok) {
            Write-Log -Level Warn "Pool API ($Name) for $Pool_Currency has failed. "
        }
    }

    if ($ok -and -not $InfoOnly) {
        $Pool_Hashrate = ConvertFrom-Hash "$($Pool_Request.pools.$Pool_Name.hashrateString)"
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -HashRate ([double]$Pool_Hashrate) -BlockRate $Pool_BLK -ChangeDetection $false -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok -or $InfoOnly) {
        foreach($Pool_Region in $Pool_Regions) {
            $SSL = $false
            foreach($Pool_Port in $_.port) {
                [PSCustomObject]@{
                    Algorithm     = $Pool_Algorithm_Norm
				    Algorithm0    = $Pool_Algorithm_Norm
                    CoinName      = $Pool_Coin.Name
                    CoinSymbol    = $Pool_Currency
                    Currency      = $Pool_Currency
                    Price         = 0
                    StablePrice   = 0
                    MarginOfError = 0
                    Protocol      = "stratum+$(if ($SSL) {"ssl"} else {"tcp"})"
                    Host          = "$($Pool_Region)-$($_.stratum)"
                    Port          = $Pool_Port
                    User          = "$($Pool_Wallet).{workername:$Worker}"
                    Pass          = $Password
                    Region        = $Pool_RegionsTable.$Pool_Region
                    SSL           = $SSL
                    Updated       = $Stat.Updated
                    PoolFee       = $Pool_Fee
                    Workers       = $Pool_Request.pools.$Pool_Name.workerCount
                    Hashrate      = $Stat.HashRate_Live
                    TSL           = $Pool_TSL
                    BLK           = $Stat.BlockRate_Average
                    WTM           = $true
                    WTMMode       = if ($Pool_Currency -eq "FLUX") {"WTM"} else {$null}
                    Name          = $Name
                    Penalty       = 0
                    PenaltyFactor = 1
				    Disabled      = $false
				    HasMinerExclusions = $false
				    Price_Bias    = 0.0
				    Price_Unbias  = 0.0
                    Wallet        = $Pool_Wallet
                    Worker        = "{workername:$Worker}"
                    Email         = $Email
                }
                $SSL = $true
            }
        }
    }
}
