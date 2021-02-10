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
    [String]$StatAverage = "Minute_10"
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$CoinXlat = [PSCustomObject]@{
    PM = "PMEER"
    ERGO = "ERG"
    VDS = "VOLLAR"
}

try {
    $Request = (((Invoke-RestMethodAsync "https://www.666pool.cn/pool2/" -tag $Name -cycletime 120) -split '<tbody>' | Select-Object -Last 1) -split '</tbody>' | Select-Object -First 1) -replace '<!--.+-->'
    $Pools_Data = $Request -replace '<!--.+?-->' -split '<tr>' | Foreach-Object {
        if ($Data = ([regex]'(?si)pool2/block/([-\w]+?)[^-\w].+?(\w+?).666pool.cn:(\d+)<').Matches($_)) {
            $Columns = $_ -replace '</td>' -split '[\s\r\n]*<td[^>]*>[\s\r\n]*'
            if ($Data[0].Groups.Count -gt 3 -and $Columns.Count -ge 6) {
                $Symbol = $Data[0].Groups[1].Value -replace "-.+$"
                $Algo   = "$($Data[0].Groups[1].value -replace "^.+-")"
                if ($Symbol -ne "PM" -or $Algo -ne "KecK") {
                    [PSCustomObject]@{
                        id       = "$($Data[0].Groups[1].Value)"
                        symbol   = "$(if ($CoinXlat.$Symbol) {$CoinXlat.$Symbol} else {$Symbol})"
                        rpc      = $Data[0].Groups[2].Value
                        port     = $Data[0].Groups[3].Value
                        hashrate = ConvertFrom-Hash "$($Columns[3])"
                        workers  = [int]"$($Columns[4])"
                        profit   = "$(if (($Columns[5] -replace "&nbsp;"," ") -match "([\d\.]+)[\s\w\/]+(\w)") {[double]$Matches[1]/(ConvertFrom-Hash "1$($Matches[2])")} else {$null})"
                        fee      = [double]"$(if ($Columns[6] -match "(\d+)%$") {$Matches[1]})"
                    }
                }
            }
        }
    }
} catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

$Pool_Region_Default = "asia"

[hashtable]$Pool_RegionsTable = @{}
@("asia") | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$TZ_China_Standard_Time = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object {$_.Id -match "Shanghai" -or $_.Id -match "^China" -or $_.StandardName -match "^China"} | Select-Object -First 1

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Coin      = Get-Coin $_.symbol
    $Pool_Currency  = $_.symbol
    $Pool_Fee       = $_.fee
    $Pool_Port      = $_.port
    $Pool_RpcPath   = $_.rpc
    $Pool_Workers   = $_.workers
    $Pool_Wallet    = "$($Wallets.$Pool_Currency)"
    $Pool_PP        = "@pplns"

    if ($Pool_Wallet -match "@(pps|pplns)$") {
        if ($Matches[1] -eq "pps") {$Pool_PP = ""}
        $Pool_Wallet = $Pool_Wallet -replace "@(pps|pplns)$"
    }

    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Coin.algo

    $Pool_EthProxy = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasEthproxy) {"ethproxy"} elseif ($Pool_Algorithm_Norm -eq "KawPOW") {"stratum"} else {$null}

    $Pool_BlocksRequest  = [PSCustomObject]@{}

    $ok = $true
    if (-not $InfoOnly) {
        try {
            $Pool_BlocksRequest = (Invoke-RestMethodAsync "https://www.666pool.cn/pool2/block/$($_.id)" -tag $Name -timeout 15 -cycletime 120) -split '</*table[^>]*>'
            if ($Pool_BlocksRequest.Count -ne 3) {$ok = $false}
            else {
                $Pool_BLK = [int]"$(if ($Pool_BlocksRequest[0] -match "green[^>]+>(\d+)<") {$Matches[1]} else {0})"
                $Pool_BlocksRequest = $Pool_BlocksRequest[1] -split "<tbody[^>]*>"
                $Pool_TSL = if ($TZ_China_Standard_Time -and $Pool_BlocksRequest.Count -ge 2 -and (($Pool_BlocksRequest[1] -split "<tr>")[1] -match "(\d+-\d+-\d+\s+\d+:\d+)")) {
                                ((Get-Date).ToUniversalTime() - [System.TimeZoneInfo]::ConvertTimeToUtc($Matches[1], $TZ_China_Standard_Time)).TotalSeconds
                            }
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
        $Pool_Rate = if ($Global:Rates.$Pool_Currency) {$_.profit / $Global:Rates.$Pool_Currency} else {0}
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value $Pool_Rate -Duration $StatSpan -HashRate $_.hashrate -BlockRate $Pool_BLK -ChangeDetection ($Pool_Rate -gt 0) -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    if ($ok -or $InfoOnly) {
        $Pool_SSL = $false
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin.Name
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.$StatAverage #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
            Host          = "$Pool_RpcPath.666pool.cn"
            Port          = $Pool_Port
            User          = "$($Pool_Wallet)$($Pool_PP).{workername:$Worker}"
            Pass          = "x{diff:,d=`$difficulty}"
            Region        = $Pool_RegionsTable[$Pool_Region_Default]
            SSL           = $Pool_SSL
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Workers
            Hashrate      = $Stat.HashRate_Live
            TSL           = $Pool_TSL
            BLK           = $Stat.BlockRate_Average
            EthMode       = $Pool_EthProxy
            WTM           = -not $Pool_Rate
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
    }
}
