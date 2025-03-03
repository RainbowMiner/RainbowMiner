#
# Get-PoolsContent
#
function Get-PoolsContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$PoolName,
        [Parameter(Mandatory = $true)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [Hashtable]$Disabled = $null
    )

    $EnableErrorRatio = $PoolName -ne "WhatToMine" -and -not $Parameters.InfoOnly -and $Session.Config.EnableErrorRatio

    if ($Parameters.InfoOnly -eq $null) {$Parameters.InfoOnly = $false}

    $UsePoolName = if ($Parameters.Name) {$Parameters.Name} else {$PoolName}

    $DiffFactor = 86400 / 4294967296 #[Math]::Pow(2,32)

    $ParametersHaveName = $Parameters.ContainsKey("Name")

    Get-ChildItem "Pools\$($PoolName).ps1" -File -ErrorAction Ignore | Foreach-Object {
        $scriptPath = $_.FullName
        $scriptName = $_.BaseName

        if (-not $ParametersHaveName) { $Parameters["Name"] = $scriptName }

        & $scriptPath @Parameters | Foreach-Object {
            $c = $_
            if ($PoolName -ne "WhatToMine") {
                if (-not $Parameters.InfoOnly -and $Parameters.Region -and ($c.Region -ne $Parameters.Region)) {
                    return
                }
                $Penalty = [Double]$Parameters.Penalty
                if (-not $Parameters.InfoOnly) {
                    $Penalty += [Double]$Session.Config.Algorithms."$($c.Algorithm)".Penalty + [Double]$Session.Config.Coins."$($c.CoinSymbol)".Penalty
                }

                $c.Penalty = $Penalty

                if (-not $Parameters.InfoOnly) {
                    if (-not $Session.Config.IgnoreFees -and $c.PoolFee) {$Penalty += $c.PoolFee}
                    if (-not $c.SoloMining -and $c.TSL -ne $null) {
                        # check for MaxAllowedLuck, if BLK is set + the block rate is greater than or equal 10 minutes
                        if ($c.BLK -ne $null -and $c.BLK -le 144) {
                            $Pool_MaxAllowedLuck = if ($Parameters.MaxAllowedLuck -ne $null) {$Parameters.MaxAllowedLuck} else {$Session.Config.MaxAllowedLuck}
                            if ($Pool_MaxAllowedLuck -gt 0) {
                                $Luck = if ($c.BLK -gt 0) {$c.TSL * $c.BLK / 86400} else {1}
                                if ($Luck -gt $Pool_MaxAllowedLuck) {
                                    $Penalty += [Math]::Exp([Math]::Min($Luck - $Pool_MaxAllowedLuck,0.385)*12)-1
                                }
                            }
                        }
                        # check for MaxTimeSinceLastBlock
                        $Pool_MaxTimeSinceLastBlock = if ($Parameters.MaxTimeSinceLastBlock -ne $null) {$Parameters.MaxTimeSinceLastBlock} else {$Session.Config.MaxTimeSinceLastBlock}
                        if ($Pool_MaxTimeSinceLastBlock -gt 0 -and $c.TSL -gt $Pool_MaxTimeSinceLastBlock) {
                            $Penalty += [Math]::Exp([Math]::Min($c.TSL - $Pool_MaxTimeSinceLastBlock,554)/120)-1
                        }
                    }
                }

                $Pool_Factor = [Math]::Max(1-$Penalty/100,0)

                if ($EnableErrorRatio -and $c.ErrorRatio) {$Pool_Factor *= $c.ErrorRatio}

                if ($c.Price -eq $null)       {$c.Price = 0}
                if ($c.StablePrice -eq $null) {$c.StablePrice = 0}

                $c.Price_0       = $c.Price
                $c.Price        *= $Pool_Factor
                $c.StablePrice  *= $Pool_Factor
                $c.PenaltyFactor = $Pool_Factor

                if ($Disabled -and $Disabled.ContainsKey("$($UsePoolName)_$(if ($c.CoinSymbol) {$c.CoinSymbol} else {$c.Algorithm})_Profit")) {
                    $c.Disabled = $true
                }
            }
            if (-not $InfoOnly -and $c.SoloMining -and $c.Difficulty) {
                $BLKFactor = [double]$DiffFactor / [double]$c.Difficulty
                foreach ($Model in $Global:DeviceCache.DeviceCombos) {
                    $d = $c | ConvertTo-Json -Depth 10 | ConvertFrom-Json -ErrorAction Ignore
                    $d.Algorithm = "$($d.Algorithm0)-$($Model)"
                    $d.Hashrate  = [double]$Global:MinerSpeeds[$d.Algorithm].Hashrate
                    $d.BLK       = $d.Hashrate * $BLKFactor
                    $d
                }
            } else {
                $c
            }
        }
    }
}

function Get-PoolsContentRS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$PoolName,
        [Parameter(Mandatory = $true)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [Hashtable]$Disabled = $null,
        [Parameter(Mandatory = $false)]
        [int]$DelayMilliseconds = 100
    )

    if ($Parameters.InfoOnly -eq $null) { $Parameters.InfoOnly = $false }

    $GlobalVars = [System.Collections.Generic.List[String]]@("Session")
    if (-not $Parameters.InfoOnly) {
        [void]$GlobalVars.AddRange([string[]]@("DeviceCache","GlobalCPUInfo","Rates","StatsCache"))

        if ($PoolName -eq "*" -or $PoolName -eq "MiningRigRentals") {
            $CurrentConfig = if ($Session.UserConfig) {$Session.UserConfig} else {$Session.Config}
            if ($CurrentConfig.PoolName -contains "MiningRigRentals" -and ($CurrentConfig.ExcludePoolName.Count -eq 0 -or $CurrentConfig.ExcludePoolName -notcontains "MiningRigRentals")) {
                [void]$GlobalVars.AddRange([string[]]@("ActiveMiners","PauseMiners"))
                if ($Global:AllPools) {
                    [void]$GlobalVars.Add("AllPools")
                }
            }
        }
    }

    if (Test-Path Variable:Global:Asyncloader) { [void]$GlobalVars.Add("Asyncloader") }
    if (Initialize-HttpClient) { [void]$GlobalVars.Add("GlobalHttpClient") }

    foreach ($Var in $GlobalVars) {
        if (-not (Test-Path Variable:Global:$Var)) { Write-Log -Level Error "Get-MinersContentRS needs `$$Var variable"; return }
    }

    $runspace = $null
    $psCmd = $null

    try {
        $runspace = [runspacefactory]::CreateRunspace()
        if (-not $runspace) { throw "Failed to create Runspace!" }
        $runspace.Open()

        foreach ($Var in $GlobalVars) {
            $VarRef = Get-Variable -Scope Global $Var -ValueOnly
            $runspace.SessionStateProxy.SetVariable($Var, $VarRef)
        }

        $psCmd = [powershell]::Create()
        if (-not $psCmd) { throw "Failed to create PowerShell instance!" }
        $psCmd.Runspace = $runspace

        [void]$psCmd.AddScript({
            param ($Parameters, $PoolName, $Disabled)
            Set-Location $Session.MainPath
            try {
                Import-Module .\Modules\Include.psm1 -Force
                Import-Module .\Modules\PoolsLib.psm1 -Force
                Import-Module .\Modules\WebLib.psm1 -Force
                if (-not $Parameters.InfoOnly) {
                    Import-Module .\Modules\StatLib.psm1
                }
                if ($PoolName -eq "*" -or $PoolName -eq "MiningRigRentals") {
                    Import-Module .\Modules\ConfigLib.psm1 -Force
                    Import-Module .\Modules\MiningRigRentals.psm1 -Force
                }
                if ($PoolName -eq "*" -or $PoolName -eq "WhatToMine") {
                    Import-Module .\Modules\WhatToMineLib.psm1 -Force
                }
                Set-OsFlags -Mini
                Get-PoolsContent -Parameters $Parameters -PoolName $PoolName -Disabled $Disabled
            } catch {
                Write-Log -Level Error "Error in Get-PoolsContent: $_"
            }
        }).AddArgument($Parameters).AddArgument($PoolName).AddArgument($Disabled)

        $inputCollection = [System.Management.Automation.PSDataCollection[PSObject]]::new()
        $outputCollection = [System.Management.Automation.PSDataCollection[PSObject]]::new()

        $asyncResult = $psCmd.BeginInvoke($inputCollection, $outputCollection)

        while (-not $asyncResult.IsCompleted -or $outputCollection.Count -gt 0) {
            if ($outputCollection.Count -gt 0) { $outputCollection.ReadAll() }
            if (-not $asyncResult.IsCompleted) { Start-Sleep -Milliseconds $DelayMilliseconds }
        }

        if ($outputCollection.Count -gt 0) {
            $outputCollection.ReadAll()
        }
        
        [void]$psCmd.EndInvoke($asyncResult)
    } catch {
        Write-Log -Level Error "Critical error in Get-PoolsContentPS: $_"
    } finally {
        if ($inputCollection) { $inputCollection.Dispose() }
        if ($outputCollection) { $outputCollection.Dispose() }
        if ($psCmd) { $psCmd.Dispose() }
        if ($runspace) {
            if ($runspace.RunspaceStateInfo.State -ne 'Closed') { $runspace.Close() }
            $runspace.Dispose()
        }
        $inputCollection = $outputCollection = $psCmd = $runspace = $null
    }
}

#
# Pool module functions
#

function Get-PoolsData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$PoolName
    )
    if (Test-Path ".\Data\Pools\$($PoolName).json") {
        if (Test-IsPS7) {
            Get-ContentByStreamReader ".\Data\Pools\$($PoolName).json" | ConvertFrom-Json -ErrorAction Ignore
        } else {
            $Data = Get-ContentByStreamReader ".\Data\Pools\$($PoolName).json" | ConvertFrom-Json -ErrorAction Ignore
            $Data
        }
    }
}

function Get-PoolPortsFromRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        $Request,
        [Parameter(Mandatory = $False)]
        [String]$mCPU = "",
        [Parameter(Mandatory = $False)]
        [String]$mGPU = "",
        [Parameter(Mandatory = $False)]
        [String]$mRIG = "",
        [Parameter(Mandatory = $False)]
        [String]$mAvoid = "",
        [Parameter(Mandatory = $False)]
        [String]$descField = "desc",
        [Parameter(Mandatory = $False)]
        [String]$portField = "port"
    )

    $Portlist = if ($Request.config.ports) {$Request.config.ports | Where-Object {$_.Disabled -ne $true -and $_.Virtual -ne $true -and (-not $mAvoid -or $_.$descField -notmatch $mAvoid)}}
                                      else {$Request | Where-Object {$_.Disabled -ne $true -and $_.Virtual -ne $true -and (-not $mAvoid -or $_.$descField -notmatch $mAvoid)}}

    for($ssl=0; $ssl -lt 2; $ssl++) {
        $Ports = $Portlist | Where-Object {[int]$ssl -eq [int]$_.ssl}
        if ($Ports) {
            $result = [PSCustomObject]@{}
            foreach($PortType in @("CPU","GPU","RIG")) {
                $Port = Switch ($PortType) {
                    "CPU" {$Ports | Where-Object {$mCPU -and $_.$descField -match $mCPU} | Select-Object -First 1;Break}
                    "GPU" {$Ports | Where-Object {$mGPU -and $_.$descField -match $mGPU} | Select-Object -First 1;Break}
                    "RIG" {$Ports | Where-Object {$mRIG -and $_.$descField -match $mRIG} | Select-Object -First 1;Break}
                }
                if (-not $Port) {$Port = $Ports | Select-Object -First 1}
                $result | Add-Member $PortType $Port.$portField -Force
            }
            $result
        } else {$false}
    }
}

function Get-PoolDataFromRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        $Request,
        [Parameter(Mandatory = $False)]
        [String]$Currency = "",
        [Parameter(Mandatory = $False)]
        [String]$chartCurrency = "",
        [Parameter(Mandatory = $False)]
        [int64]$coinUnits = 1,
        [Parameter(Mandatory = $False)]
        [int64]$Divisor = 1,
        [Parameter(Mandatory = $False)]
        [String]$HashrateField = "hashrate",
        [Parameter(Mandatory = $False)]
        [String]$NetworkField = "network",
        [Parameter(Mandatory = $False)]
        [String]$LastblockField = "lastblock",
        [Parameter(Mandatory = $False)]
        $Timestamp = (Get-UnixTimestamp),
        [Parameter(Mandatory = $False)]
        [Switch]$addBlockData,
        [Parameter(Mandatory = $False)]
        [Switch]$addDay,
        [Parameter(Mandatory = $False)]
        [Switch]$priceFromSession,
        [Parameter(Mandatory = $False)]
        [Switch]$forceCoinUnits
    )

    $rewards = [PSCustomObject]@{
            Live    = @{reward=0.0;hashrate=$Request.pool.$HashrateField}
            Day     = @{reward=0.0;hashrate=0.0}
            Workers = if ($Request.pool.workers) {$Request.pool.workers} else {$Request.pool.miners}
            BLK     = 0
            TSL     = 0
    }

    $timestamp24h = $timestamp - 86400

    $diffLive     = [decimal]$Request.$NetworkField.difficulty
    $reward       = if ($Request.$NetworkField.reward) {[decimal]$Request.$NetworkField.reward} else {[decimal]$Request.$LastblockField.reward}
    $profitLive   = if ($diffLive) {86400/$diffLive*$reward/$Divisor} else {0}
    if ($Request.config.coinUnits -and -not $forceCoinUnits) {$coinUnits = [decimal]$Request.config.coinUnits}
    $amountLive   = $profitLive / $coinUnits

    if (-not $Currency) {$Currency = $Request.config.symbol}
    if (-not $chartCurrency -and $Request.config.priceCurrency) {$chartCurrency = $Request.config.priceCurrency}

    $lastSatPrice = if ($Global:Rates.$Currency) {1/$Global:Rates.$Currency*1e8} else {0}

    if (-not $priceFromSession -and -not $lastSatPrice) {
        if     ($Request.price.btc)           {$lastSatPrice = 1e8*[decimal]$Request.price.btc}
        elseif ($Request.coinPrice.priceSats) {$lastSatPrice = [decimal]$Request.coinPrice.priceSats}
        elseif ($Request.coinPrice.price)     {$lastSatPrice = 1e8*[decimal]$Request.coinPrice.price}
        elseif ($Request.coinPrice."coin-btc"){$lastSatPrice = 1e8*[decimal]$Request.coinPrice."coin-btc"}
        else {
            $lastSatPrice = if ($Request.charts.price) {[decimal]($Request.charts.price | Select-Object -Last 1)[1]} else {0}
            if ($chartCurrency -and $chartCurrency -ne "BTC" -and $Global:Rates.$chartCurrency) {$lastSatPrice *= 1e8/$Global:Rates.$chartCurrency}
            elseif ($chartCurrency -eq "BTC" -and $lastSatPrice -lt 1.0) {$lastSatPrice*=1e8}
            if (-not $lastSatPrice -and $Global:Rates.$Currency) {$lastSatPrice = 1/$Global:Rates.$Currency*1e8}
        }
    }

    $rewards.Live.reward = $amountLive * $lastSatPrice

    if ($addDay) {
        $averageDifficulties = if ($Request.pool.stats.diffs.wavg24h) {$Request.pool.stats.diffs.wavg24h} elseif ($Request.charts.difficulty_1d) {$Request.charts.difficulty_1d} else {($Request.charts.difficulty | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average}
        if ($averageDifficulties) {
            $averagePrices = if ($Request.charts.price_1d) {$Request.charts.price_1d} elseif ($Request.charts.price) {($Request.charts.price | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average} else {0}
            if ($chartCurrency -and $chartCurrency -ne "BTC" -and $Global:Rates.$chartCurrency) {$averagePrices *= 1e8/$Global:Rates.$chartCurrency}
            elseif ($chartCurrency -eq "BTC" -and $averagePrices -lt 1.0) {$averagePrices*=1e8}
            if (-not $averagePrices) {$averagePrices = $lastSatPrice}
            $profitDay = 86400/$averageDifficulties*$reward/$Divisor
            $amountDay = $profitDay/$coinUnits
            $rewardsDay = $amountDay * $averagePrices
        }
        $rewards.Day.reward   = if ($rewardsDay) {$rewardsDay} else {$rewards.Live.reward}
        $rewards.Day.hashrate = if ($Request.charts.hashrate_1d) {$Request.charts.hashrate_1d} elseif ($Request.charts.hashrate_daily) {$Request.charts.hashrate_daily} else {($Request.charts.hashrate | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average}
        if (-not $rewards.Day.hashrate) {$rewards.Day.hashrate = $rewards.Live.hashrate}
    }

    if ($addBlockData) {
        $blocks = $Request.pool.blocks | Where-Object {$_ -match '^.*?\:(\d+?)\:'} | Foreach-Object {$Matches[1]} | Sort-Object -Descending
        $blocks_measure = $blocks | Where-Object {$_ -gt $timestamp24h} | Measure-Object -Minimum -Maximum
        $rewards.BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {86400/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $rewards.TSL = if ($blocks.Count) {$timestamp - $blocks[0]}
    }
    $rewards
}

function Get-WalletWithPaymentId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string]$wallet = "",
        [Parameter(Mandatory = $False)]
        [string]$paymentid = "",
        [Parameter(Mandatory = $False)]
        [string]$difficulty = "",
        [Parameter(Mandatory = $False)]
        [string]$pidchar = "+",
        [Parameter(Mandatory = $False)]
        [string]$diffchar = ".",
        [Parameter(Mandatory = $False)]
        [switch]$asobject,
        [Parameter(Mandatory = $False)]
        [switch]$withdiff
    )
    if ($wallet -notmatch "@" -and $wallet -match "[\+\.\/]") {
        if ($wallet -match "[\+\.\/]([a-f0-9]{16,})") {$paymentid = $Matches[1];$wallet = $wallet -replace "[\+\.\/][a-f0-9]{16,}"}
        if ($wallet -match "[\+\.\/](\d{1,15})$") {$difficulty = $Matches[1];$wallet = $wallet -replace "[\+\.\/]\d{1,15}$"}
    }
    if ($asobject) {
        [PSCustomObject]@{
            wallet = "$($wallet)$(if ($paymentid -and $pidchar) {"$($pidchar)$($paymentid)"})"
            paymentid = $paymentid
            difficulty = $difficulty
        }
    } else {
        "$($wallet)$(if ($paymentid -and $pidchar) {"$($pidchar)$($paymentid)"})$(if ($difficulty -and $withdiff) {"$($diffchar)$($difficulty)"})"
    }
}

function Get-YiiMPDataWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$DataWindow = '',
        [Parameter(Mandatory = $False)]
        [String]$Default = $Session.Config.PoolDataWindow
    )
    Switch ($DataWindow -replace "[^A-Za-z0-9]+") {
        {"1","e1","e","ec","ecurrent","current","default","estimatecurrent" -icontains $_} {"estimate_current";Break}
        {"2","e2","e24","e24h","last24","estimate24h","24h","estimatelast24h" -icontains $_} {"estimate_last24h";Break}
        {"3","a2","a","a24","a24h","actual","actual24h","actuallast24h" -icontains $_} {"actual_last24h";Break}
        {"4","min","min2","minimum","minimum2" -icontains $_} {"minimum-2";Break}
        {"5","max","max2","maximum","maximum2" -icontains $_} {"maximum-2";Break}
        {"6","avg","avg2","average","average2" -icontains $_} {"average-2";Break}
        {"7","min3","minimum3","minall","minimumall" -icontains $_} {"minimum-3";Break}
        {"8","max3","maximum3","maxall","maximumall" -icontains $_} {"maximum-3";Break}
        {"9","avg3","average3","avgall","averageall" -icontains $_} {"average-3";Break}
        {"10","mine","min2e","minimume","minimum2e" -icontains $_} {"minimum-2e";Break}
        {"11","maxe","max2e","maximume","maximum2e" -icontains $_} {"maximum-2e";Break}
        {"12","avge","avg2e","averagee","average2e" -icontains $_} {"average-2e";Break}
        {"13","minh","min2h","minimumh","minimum2h" -icontains $_} {"minimum-2h";Break}
        {"14","maxh","max2h","maximumh","maximum2h" -icontains $_} {"maximum-2h";Break}
        {"15","avgh","avg2h","averageh","average2h" -icontains $_} {"average-2h";Break}
        default {if ($Default) {$Default} else {"estimate_current"}}
    }
}

function Get-YiiMPValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Request,
        [Parameter(Mandatory = $False)]
        [Double]$Factor = 1,
        [Parameter(Mandatory = $False)]
        [String]$DataWindow = '',
        [Parameter(Mandatory = $False)]
        [String]$ActualLast24h = 'actual_last24h',
        [Parameter(Mandatory = $False)]
        [String]$EstimateCurrent = 'estimate_current',
        [Parameter(Mandatory = $False)]
        [String]$EstimateLast24h = 'estimate_last24h',
        [Parameter(Mandatory = $False)]
        [Switch]$CheckDataWindow = $false,
        [Parameter(Mandatory = $False)]
        [Double]$ActualDivisor = 1000
    )
    [Double]$Value = 0
    [System.Collections.Generic.List[string]]$allfields = @($EstimateCurrent,$EstimateLast24h,$ActualLast24h)
    [hashtable]$values = @{}
    [bool]$hasdetails=$false
    [bool]$containszero = $false
     foreach ($field in $allfields) {
        if ($Request.$field -ne $null) {
            $values[$field] = if ($Request."$($field)_in_btc_per_hash_per_day" -ne $null){$hasdetails=$true;[double]$Request."$($field)_in_btc_per_hash_per_day"}else{[double]$Request.$field}
            if ($values[$field] -eq [double]0) {$containszero=$true}
        }
    }
    if (-not $hasdetails -and $values.ContainsKey($ActualLast24h) -and $ActualDivisor) {$values[$ActualLast24h]/=$ActualDivisor}
    if ($CheckDataWindow) {$DataWindow = Get-YiiMPDataWindow $DataWindow}

    if ($values.count -eq 3 -and -not $containszero) {
        $set = $true
        foreach ($field in $allfields) {
            $v = $values[$field]
            if ($set) {$max = $min = $v;$maxf = $minf = "";$set = $false}
            else {
                if ($v -lt $min) {$min = $v;$minf = $field}
                if ($v -gt $max) {$max = $v;$maxf = $field}
            }
        }
        if (($max / $min) -gt 10) {
            foreach ($field in $allfields) {
                if (($values[$field] / $min) -gt 10) {$values[$field] = $min}
            }
        }
    }

    if ($Value -eq 0) {
        if ($DataWindow -match '^(.+)-(.+)$') {
            Switch ($Matches[2]) {
                "2"  {[System.Collections.Generic.List[string]]$fields = @($ActualLast24h,$EstimateCurrent);Break}
                "2e" {[System.Collections.Generic.List[string]]$fields = @($EstimateLast24h,$EstimateCurrent);Break}
                "2h" {[System.Collections.Generic.List[string]]$fields = @($ActualLast24h,$EstimateLast24h);Break}
                "3"  {[System.Collections.Generic.List[string]]$fields = $allfields;Break}
            }
            Switch ($Matches[1]) {
                "minimum" {
                    $set = $true
                    foreach ($field in $fields) {
                        if(-not $values.ContainsKey($field)) {continue}
                        $v = $values[$field]
                        if ($set -or $v -lt $Value) {$Value = $v;$set=$false}
                    }
                    Break
                }
                "maximum" {
                    $set = $true
                    foreach ($field in $fields) {
                        if(-not $values.ContainsKey($field)) {continue}
                        $v = $values[$field]
                        if ($set -or $v -gt $Value) {$Value = $v;$set=$false}
                    }
                    Break
                }
                "average" {
                    $c=0
                    foreach ($field in $fields) {                
                        if(-not $values.ContainsKey($field)) {continue}
                        $Value+=$values[$field]
                        $c++
                    }
                    if ($c) {$Value/=$c}
                    Break
                }
            }
        } else {
            if (-not $DataWindow -or -not $values.ContainsKey($DataWindow)) {foreach ($field in $allfields) {if ($values.ContainsKey($field)) {$DataWindow = $field;break}}}
            if ($DataWindow -and $values.ContainsKey($DataWindow)) {$Value = $values[$DataWindow]}
        }
    }
    if (-not $hasdetails){$Value*=1e-6/$Factor}
    $Value
}

function Get-BalancesPayouts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Payouts,
        [Parameter(Mandatory = $false)]
        [Decimal]$Divisor = 1,
        [Parameter(Mandatory = $false)]
        [String]$DateTimeField,
        [Parameter(Mandatory = $false)]
        [String]$AmountField,
        [Parameter(Mandatory = $false)]
        [String]$TxField
    )

    $Payouts | Foreach-Object {
        $DateTime = if ($DateTimeField) {$_.$DateTimeField} elseif ($_.time) {$_.time} elseif ($_.date) {$_.date} elseif ($_.datetime) {$_.datetime} elseif ($_.timestamp) {$_.timestamp} elseif ($_.createdAt) {$_.createdAt} elseif ($_.pay_time) {$_.pay_time}
        if ($DateTime -isnot [DateTime]) {$DateTime = "$($DateTime)"}
        if ($DateTime) {
            $Amount = if ($AmountField) {$_.$AmountField} elseif ($_.amount -ne $null) {$_.amount} elseif ($_.value -ne $null) {$_.value} else {$null}
            if ($Amount -ne $null) {
                [PSCustomObject]@{
                    Date     = $(if ($DateTime -is [DateTime]) {$DateTime.ToUniversalTime()} elseif ($DateTime -match "^\d+$") {$Session.UnixEpoch + [TimeSpan]::FromSeconds($DateTime)} else {(Get-Date $DateTime).ToUniversalTime()})
                    Amount   = [Double]$Amount / $Divisor
                    Txid     = "$(if ($TxField) {$_.$TxField} elseif ($_.tx) {$_.tx} elseif ($_.txid) {$_.txid}  elseif ($_.tx_id) {$_.tx_id} elseif ($_.txHash) {$_.txHash} elseif ($_.transactionId) {$_.transactionId} elseif ($_.hash) {$_.hash})".Trim()
                }
            }
        }
    }
}