Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\DotNet\OpenCL\*.cs

function Get-Version {
    [CmdletBinding()]
    param($Version)
    # System.Version objects can be compared with -gt and -lt properly
    # This strips out anything that doens't belong in a version, eg. v at the beginning, or -preview1 at the end, and returns a version object
    [System.Version]($Version -Split '-' -Replace "[^0-9.]")[0]
}

function Compare-Version {
    [CmdletBinding()]
    param($Version1,$Version2,[int]$revs = -1)
    $ver1 = $Version1 -split '\.'
    $ver2 = $Version2 -split '\.'
    $max = [Math]::min($ver1.Count,$ver2.Count)
    if ($revs -gt 0 -and $revs -lt $max) {$max = $revs}

    for($i=0;$i -lt $max;$i++) {
        if ($ver1[$i] -lt $ver2[$i]) {return -1}
        if ($ver1[$i] -gt $ver2[$i]) {return 1}
    }
    return 0
}

function Confirm-Version {
    [CmdletBinding()]
    param($RBMVersion, [Switch]$Force = $false, [Switch]$Silent = $false)

    $Name = "RainbowMiner"
    if ($Force -or -not (Test-Path Variable:Script:GlobalVersion) -or (Get-Date).ToUniversalTime() -ge $Script:GlobalVersion.NextCheck) {

        $RBMVersion = $Version = Get-Version($RBMVersion)
        $Uri = ""
        $NextCheck = (Get-Date).ToUniversalTime()

        try {
            $ReposURI = "https://api.github.com/repos/rainbowminer/$Name/releases/latest"
            if ($Force) {
                $Request = Invoke-GetUrl $ReposURI
            } else {
                $Request = Invoke-RestMethodAsync $ReposURI -cycletime 3600 -noquickstart
            }
            $RemoteVersion = ($Request.tag_name -replace '^v')
            if ($RemoteVersion) {
                if ($IsWindows) {
                    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion)_win.zip" | Select-Object -ExpandProperty browser_download_url
                } elseif ($IsLinux) {
                    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion)_linux.zip" | Select-Object -ExpandProperty browser_download_url
                }
                if (-not $Uri) {
                    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion).zip" | Select-Object -ExpandProperty browser_download_url
                }
                $Version  = Get-Version($RemoteVersion)
            }
            $NextCheck = $NextCheck.AddHours(1)
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Github could not be reached. "
        }
        $Script:GlobalVersion = [PSCustomObject]@{
            Version = $RBMVersion
            RemoteVersion = $Version
            DownloadURI = $Uri
            ManualURI = "https://github.com/RainbowMiner/$Name/releases"
            NextCheck = $NextCheck
        }
    }

    if (-not $Silent) {
        if ($Script:GlobalVersion.RemoteVersion -gt $Script:GlobalVersion.Version) {
            Write-Log -Level Warn "$Name is out of date: lastest release version v$($Script:GlobalVersion.RemoteVersion) is available."
        } elseif ($Script:GlobalVersion.RemoteVersion -lt $Script:GlobalVersion.Version) {
            Write-Log -Level Warn "You are running $Name prerelease v$RBMVersion. Use at your own risk."
        }
    }
    $Script:GlobalVersion
}

function Confirm-Cuda {
   [CmdletBinding()]
   param($ActualVersion,$RequiredVersion,$Warning = "")
   if (-not $RequiredVersion) {return $true}
    $ver1 = $ActualVersion -split '\.'
    $ver2 = $RequiredVersion -split '\.'
    $max = [Math]::min($ver1.Count,$ver2.Count)

    for($i=0;$i -lt $max;$i++) {
        if ([int]$ver1[$i] -lt [int]$ver2[$i]) {if ($Warning -ne "") {Write-Log -Level Info "$($Warning) requires CUDA version $($RequiredVersion) or above (installed version is $($ActualVersion)). Please update your Nvidia drivers."};return $false}
        if ([int]$ver1[$i] -gt [int]$ver2[$i]) {return $true}
    }
    $true
}

function Get-NvidiaArchitecture {
    [CmdLetBinding()]
    param($Model)
    Switch ($Model) {
        {$_ -match "^RTX20\d{2}" -or $_ -match "^GTX16\d{2}" -or $_ -match "^TU"} {"Turing"}
        {$_ -match "^GTX10\d{2}" -or $_ -match "^GTXTitanX" -or $_ -match "^GP" -or $_ -match "^P"} {"Pascal"}
        default {"Other"}
    }
}

function Get-PoolPayoutCurrencies {
    param($Pool)
    $Payout_Currencies = [PSCustomObject]@{}
    if (-not (Test-Path Variable:Global:PoolFields)) {
        $Setup = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1" | Select-Object -ExpandProperty Content
        $Global:PoolFields = @($Setup.PSObject.Properties.Value | Where-Object {$_.Fields} | Foreach-Object {$_.Fields.PSObject.Properties.Name} | Select-Object -Unique) + @("Worker","DataWindow","Penalty","Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","MinerName","ExcludeMinerName","FocusWallet","Wallets","EnableAutoCoin","EnablePostBlockMining") | Select-Object -Unique | Sort-Object
    }
    @($Pool.PSObject.Properties) | Where-Object Membertype -eq "NoteProperty" | Where-Object {$_.Value -is [string] -and ($_.Value.Length -gt 2 -or $_.Value -eq "`$Wallet" -or $_.Value -eq "`$$($_.Name)") -and $Global:PoolFields -inotcontains $_.Name -and $_.Name -notmatch "-Params$"} | Select-Object Name,Value -Unique | Sort-Object Name,Value | Foreach-Object{$Payout_Currencies | Add-Member $_.Name $_.Value}
    $Payout_Currencies
}

function Get-Balance {
    [CmdletBinding()]
    param($Config, [Bool]$Refresh = $false, [Bool]$Details = $false)
    
    if (-not (Test-Path Variable:Script:CachedPoolBalances) -or $Refresh) {
        $Script:CachedPoolBalances = @(Get-BalancesContent -Config $Config | Group-Object -Property Caption | Foreach-Object {
            if ($_.Count -gt 1){foreach ($p in @("Balance","Pending","Total","Paid","Earned","Payouts")) {if (Get-Member -InputObject $_.Group[0] -Name $p) {if ($p -eq "Payouts") {$_.Group[0].$p = @($_.Group.$p | Select-Object)} else {$_.Group[0].$p = ($_.Group.$p | Measure-Object -Sum).Sum}}}}
            $_.Group[0]
        })
    }

    $Balances = $Script:CachedPoolBalances | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json -ErrorAction Ignore

    if (-not $Balances) {return}

    #Get exchange rates for all payout currencies
    $CurrenciesWithBalances = @()
    $CurrenciesToExchange   = @()
    $CurrenciesMissing = @()

    $RatesAPI = [PSCustomObject]@{}
    
    $Balances.currency | Select-Object -Unique | Sort-Object | Foreach-Object {$CurrenciesWithBalances += $_}
    @("BTC") + $Config.Currency | Select-Object -Unique | Sort-Object | Foreach-Object {$CurrenciesToExchange += $_}
    $CurrenciesWithBalances + $CurrenciesToExchange | Where-Object {-not $Session.Rates.ContainsKey($_)} | Foreach-Object {$CurrenciesMissing += $_}

    if ($CurrenciesMissing.Count) {Update-Rates $CurrenciesMissing}

    $CurrenciesWithBalances | Foreach-Object {
        $Currency = $_
        if ($Session.Rates.ContainsKey($Currency) -and $Session.Rates[$Currency]) {
            $RatesAPI | Add-Member "$($Currency)" ([PSCustomObject]@{})
            $CurrenciesToExchange | Where-Object {$Session.Rates.ContainsKey($_)} | Foreach-Object {
                $RatesAPI.$Currency | Add-Member $_ ($Session.Rates.$_/$Session.Rates.$Currency)
            }
        }
    }

    #Add total of totals
    $Totals = [PSCustomObject]@{
        Name    = "*Total*"
        Caption = "*Total*"
    }

    Get-WorldCurrencies -Silent

    [hashtable]$Digits = @{}
    $CurrenciesWithBalances + $Config.Currency | Where-Object {$_} | Select-Object -Unique | Foreach-Object {$Digits[$_] = if ($Global:GlobalWorldCurrencies -icontains $_) {2} else {8}}

    $CurrenciesWithBalances | ForEach-Object {
        $Currency = $_.ToUpper()
        $Balances | Where-Object Currency -eq $Currency | Foreach-Object {$_ | Add-Member "Balance ($Currency)" $_.Total -Force}
        if (($Balances."Balance ($Currency)" | Measure-Object -Sum).sum) {$Totals | Add-Member "Balance ($Currency)" ($Balances."Balance ($Currency)" | Measure-Object -Sum).sum -Force}
    }

    #Add converted values
    $Config.Currency | Sort-Object | ForEach-Object {
        $Currency = $_.ToUpper()
        $Balances | Foreach-Object {
            $Balance = $_
            $Balance | Add-Member "Value in $Currency" $(if ($RatesAPI.$($Balance.Currency).$Currency -ne $null) {$Balance.Total * $RatesAPI.$($Balance.Currency).$Currency}elseif($RatesAPI.$Currency.$($Balance.Currency)) {$Balance.Total / $RatesAPI.$Currency.$($Balance.Currency)}else{"-"}) -Force
        }
        if (($Balances."Value in $Currency" | Where-Object {$_ -ne "-"} | Measure-Object -Sum -ErrorAction Ignore).sum)  {$Totals | Add-Member "Value in $Currency" ($Balances."Value in $Currency" | Where-Object {$_ -ne "-"} | Measure-Object -Sum -ErrorAction Ignore).sum -Force}
    }

    if (-not $Details) {
        #Consolidate result
        $Balances = $Balances | Group-Object -Property Name | Foreach-Object {
            $_.Group | Sort-Object @{Expression={$_.Currency -eq "BTC"};Descending=$true},Caption | Select-Object -First 1 | Foreach-Object {
                $Balance = [PSCustomObject]@{
                    Caption = $_.Caption
                    Currency = "BTC"
                    Name = $_.Name
                    Payouts = @(if ($_.Currency -eq "BTC") {$_.Payouts})
                }
                $_.PSObject.Properties.Name | Where-Object {$_ -match "^Value in"} | Foreach-Object {
                    $Field = $_
                    $Balance | Add-Member $Field ($Balances | Where-Object {$_.Name -eq $Balance.Name -and $_.$Field -and $_.$Field -ne "-"} | Measure-Object -Property $Field -Sum -ErrorAction Ignore).sum
                }
                $Balance
            }
        }
    }

    $Balances = @($Balances | Where-Object {$_.Total} | Select-Object) + $Totals

    $Balances | Foreach-Object {
        $Balance = $_
        $Balance.PSObject.Properties.Name | Where-Object {$_ -match "^(Value in |Balance \()(\w+)"} | Foreach-Object {if ($Balance.$_ -eq "" -or $Balance.$_ -eq $null) {$Balance.$_=0};$Balance.$_ = "{0:N$($n = if ($Balance.$_ -ge 10 -and $Digits[$Matches[2]] -eq 8) {[Math]::Min([Math]::Ceiling([Math]::Log10($Balance.$_)),8)} else {1};$Digits[$Matches[2]]-$n+1)}" -f $Balance.$_}
    }
    
    $Balances

    Remove-Variable "Balances"
    Remove-Variable "Totals"
}

function Set-UnprofitableAlgos {
    if ($Session.UnprofitableAlgos -eq $null) {
        $Session.UnprofitableAlgos = try{Get-Content ".\Data\unprofitable.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore} catch {@()}
    }

    if (-not $Session.UnprofitableAlgos -or -not (Test-Path ".\Data\unprofitable.json") -or (Get-ChildItem ".\Data\unprofitable.json").LastWriteTime.ToUniversalTime() -lt (Get-Date).AddHours(-1).ToUniversalTime()) {
        $Key = Get-ContentDataMD5hash $Session.UnprofitableAlgos
        try {
            $Request = Invoke-GetUrlAsync "http://rbminer.net/api/data/unprofitable2.json" -cycletime 3600 -Jobkey "unprofitable2"
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Unprofitable algo API failed. "
        }
        if ($Request.Algorithms -and $Request.Algorithms -gt 10) {
            $Session.UnprofitableAlgos = $Request
            Set-ContentJson -PathToFile ".\Data\unprofitable.json" -Data $Session.UnprofitableAlgos -MD5hash $Key > $null
        }
    }
}

function Get-CoinSymbol {
    [CmdletBinding()]
    param($CoinName = "Bitcoin",[Switch]$Silent,[Switch]$Reverse)
    
    if (-not (Test-Path Variable:Global:GlobalCoinNames) -or -not $Global:GlobalCoinNames.Count) {
        try {
            $Request = Invoke-GetUrlAsync "http://rbminer.net/api/data/coins.json" -cycletime 86400 -Jobkey "coins"
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Coins API failed. "
        }
        if (-not $Request -or $Request.PSObject.Properties.Name.Count -le 100) {
            $Request = $null
            if (Test-Path "Data\coins.json") {try {$Request = Get-Content "Data\coins.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop} catch {$Request = $null}}
            if (-not $Request) {Write-Log -Level Warn "Coins API return empty string. ";return}
        } else {Set-ContentJson -PathToFile "Data\coins.json" -Data $Request > $null}
        [hashtable]$Global:GlobalCoinNames = @{}
        $Request.PSObject.Properties | Foreach-Object {$Global:GlobalCoinNames[$_.Name] = $_.Value}
    }
    if (-not $Silent) {
        if ($Reverse) {
            (Get-Culture).TextInfo.ToTitleCase("$($Global:GlobalCoinNames.GetEnumerator() | Where-Object {$_.Value -eq $CoinName.ToUpper()} | Select-Object -ExpandProperty Name -First 1)")
        } else {
            $Global:GlobalCoinNames[$CoinName.ToLower() -replace "[^a-z0-9]+"]
        }
    }
}

function Update-Rates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Symbols
    )

    $NewRatesFound = $false

    if (-not (Test-Path Variable:Script:NewRates)) {[hashtable]$Script:NewRates = @{}}

    if (-not $Symbols) {
        $Symbols = @($Session.Config.Currency | Select-Object) + @("USD") + @($Session.Config.Pools.PSObject.Properties.Name | Foreach-Object {$Session.Config.Pools.$_.Wallets.PSObject.Properties.Name} | Select-Object -Unique) | Select-Object -Unique
        $Script:NewRates.Clear()
        try {Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -Jobkey "coinbase" | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$Script:NewRates[$_.Name] = [Double]$_.Value}}} catch {if ($Error.Count){$Error.RemoveAt(0)};$Script:NewRates.Clear()}

        if (-not $Script:NewRates.Count) {
            Write-Log -Level Info "Coinbase is down, using fallback. "
            try {Invoke-GetUrl "http://rbminer.net/api/data/coinbase.json" | Select-Object | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$Script:NewRates[$_.Name] = [Double]$_.Value}}} catch {if ($Error.Count){$Error.RemoveAt(0)};$Script:NewRates.Clear();Write-Log -Level Warn "Coinbase down. "}
        }

        $Session.Rates["BTC"] = $Script:NewRates["BTC"] = [Double]1

        $NewRatesFound = $true
    } else {
        $Symbols = @($Symbols | Select-Object -Unique)
    }

    Compare-Object $Symbols @($Script:NewRates.Keys) -IncludeEqual | Where-Object {$_.SideIndicator -ne "=>" -and $_.InputObject} | Foreach-Object {
        if ($_.SideIndicator -eq "==") {$Session.Rates[$_.InputObject] = [Double]$Script:NewRates[$_.InputObject]}
        elseif ($Session.GlobalGetTicker -inotcontains $_.InputObject) {$Session.GlobalGetTicker += $_.InputObject.ToUpper();$NewRatesFound = $true}
    }

    if ($NewRatesFound -and $Session.GlobalGetTicker.Count -gt 0) {
        try {
            $SymbolStr = "$(($Session.GlobalGetTicker | Sort-Object) -join ',')".ToUpper()
            $RatesAPI = Invoke-RestMethodAsync "https://rbminer.net/api/cmc.php?symbols=$($SymbolStr)" -Jobkey "morerates" -cycletime 600
            if (-not $RatesAPI.status) {
                Write-Log -Level Info "Rbminer.net/cmc failed for $($SymbolStr)"
            } elseif ($RatesAPI.data -and $RatesAPI -is [object]) {
                $RatesAPI.data.PSObject.Properties | Foreach-Object {$Session.Rates[$_.Name] = if ($_.Value -gt 0) {[double](1e8/$_.Value)} else {0}}                    
            }
            if ($RatesAPI) {Remove-Variable "RatesAPI"}
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Rbminer.net/cmc API for $($SymbolStr) has failed. "
        }
    }

    Get-WorldCurrencies -Silent
    Compare-Object $Global:GlobalWorldCurrencies @($Session.Rates.Keys) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject | Foreach-Object {$Session.Rates[$_] = [Math]::Round($Session.Rates[$_],3)}
}

function Get-WhatToMineData {
    [CmdletBinding()]
    param([Switch]$Silent)
    
    if (-not (Test-Path ".\Data\wtmdata.json") -or (Get-ChildItem ".\Data\wtmdata.json").LastWriteTime.ToUniversalTime() -lt (Get-Date).AddHours(-12).ToUniversalTime()) {
        try {
            $WtmUrl  = Invoke-GetUrlAsync "https://www.whattomine.com" -cycletime (12*3600) -retry 3 -timeout 10
            $WtmKeys = ([regex]'(?smi)data-content="Include (.+?)".+?factor_([a-z0-9]+?)_hr.+?>([hkMG]+)/s<').Matches($WtmUrl) | Foreach-Object {
                [PSCustomObject]@{
                    algo   = (Get-Algorithm ($_.Groups | Where-Object Name -eq 1 | Select-Object -ExpandProperty Value)) -replace "Cuckaroo29","Cuckarood29"
                    id     = $_.Groups | Where-Object Name -eq 2 | Select-Object -ExpandProperty Value
                    factor = $_.Groups | Where-Object Name -eq 3 | Select-Object -ExpandProperty Value | Foreach-Object {Switch($_) {"Gh" {1e9};"Mh" {1e6};"kh" {1e3};default {1}}}
                }
            }
            if ($WtmKeys -and $WtmKeys.count -gt 10) {
                $WtmFactors = Get-Content ".\Data\wtmfactors.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
                if ($WtmFactors) {
                    $WtmFactors.PSObject.Properties.Name | Where-Object {@($WtmKeys.algo) -inotcontains $_} | Foreach-Object {
                        $WtmKeys += [PSCustomObject]@{
                            algo = $_
                            factor = $WtmFactors.$_
                        }
                    }
                }
                Set-ContentJson ".\Data\wtmdata.json" -Data $WtmKeys > $null
                if (Test-Path Variable:Global:WTMData) {Remove-Variable "WTMData" -Force -ErrorAction Ignore}
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "WhatToMiner datagrabber failed. "
            return
        }
    }

    if (-not (Test-Path Variable:Global:WTMData)) {
        $Global:WTMData = Get-Content ".\Data\wtmdata.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
    }

    if (-not $Silent) {$Global:WTMData}
}

function Get-WhatToMineUrl {
    "https://whattomine.com/coins.json?$(@(Get-WhatToMineData | Where-Object {$_.id} | Foreach-Object {"$($_.id)=true&factor[$($_.id)_hr]=10&factor[$($_.id)_p]=0"}) -join '&')"
}

function Get-WhatToMineFactor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Algo
    )
    if ($Algo) {
        if (-not (Test-Path Variable:Global:WTMData)) {Get-WhatToMineData -Silent}
        $Global:WTMData | Where-Object {$_.algo -eq $Algo} | Foreach-Object {$_.factor * 10}
    }
}

function Update-WatchdogLevels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Reset = $false,
        [Parameter(Mandatory = $false)]
        [Int]$Interval = 0
    )
    if ($Interval -lt $Session.Config.BenchmarkInterval) {$Interval = $Session.Config.BenchmarkInterval}
    if ($Session.CurrentInterval -lt 2*$Interval) {$Interval = [Math]::Max($Session.CurrentInterval,$Interval)}
    $Session.WatchdogInterval    = ($Session.WatchdogInterval / $Session.Strikes * ($Session.Strikes - 1))*(-not $Reset) + $Interval
    $Session.WatchdogReset = ($Session.WatchdogReset / ($Session.Strikes * $Session.Strikes * $Session.Strikes) * (($Session.Strikes * $Session.Strikes * $Session.Strikes) - 1))*(-not $Reset) + $Interval
}

function Set-MinerStats {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [TimeSpan]$StatSpan,
        [Parameter(Mandatory = $false)]
        [Switch]$Watchdog = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Miner_Failed_Total = 0
    $Session.ActiveMiners | Foreach-Object {
        $Miner = $_

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Sub $Session.DevicesToVendors[$Miner.DeviceModel])})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if ($Miner.GetStatus() -eq [Minerstatus]::Running -or $Miner.New) {
            $Miner.Speed_Live = [Double[]]@()            

            $Miner_PowerDraw = $Miner.GetPowerDraw()

            $Statset = 0
            $Miner_Index = 0
            $Miner_Failed= $false
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $Miner_Speed = $Miner.GetHashRate($Miner_Algorithm,$true)
                $Miner_Diff  = $Miner.GetDifficulty($Miner_Algorithm)

                $Miner.Speed_Live += [Double]$Miner_Speed

                Write-Log "$($Miner.BaseName) $(if ($Miner.IsBenchmarking()) {"benchmarking"} else {"mining"}) $($Miner_Algorithm) on $($Miner.DeviceModel): $($Miner.GetMinerDataCount()) samples / round $(if ($Miner.IsBenchmarking()) {"$($Miner.Benchmarked) / variance $("{0:f2}" -f ($Miner.Variance[$Miner.Algorithm.IndexOf($Miner_Algorithm)]*100))%"} else {$Miner.Rounds})"

                $Stat = $null
                if (-not $Miner.IsBenchmarking() -or $Miner_Speed) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($Miner_Algorithm -replace '\-.*$')_HashRate" -Value $Miner_Speed -Difficulty $Miner_Diff -Ratio $Miner.RejectedShareRatio[$Miner_Index] -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $Session.DevicesToVendors[$Miner.DeviceModel] -Quiet:$($Quiet -or ($Miner.GetRunningTime() -lt (New-TimeSpan -Seconds 30)) -or $Miner.IsWrapper())
                    $Statset++
                }

                #Update watchdog timer
                if ($WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner.Name -and $_.PoolName -eq $Miner.Pool[$Miner_Index] -and $_.Algorithm -eq $Miner_Algorithm}) {
                    if ($Stat -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                        $WatchdogTimer.Kicked = $Stat.Updated
                        $Miner.CrashCount = 0
                    } elseif ($Miner.IsBenchmarking() -or ($Miner_Speed -and $Miner.Rounds -lt [Math]::Max($Miner.ExtendedInterval,1)-1)) {
                        $WatchdogTimer.Kicked = (Get-Date).ToUniversalTime()
                        $Miner.CrashCount = 0
                    } elseif ($Watchdog -and $WatchdogTimer.Kicked -lt $Session.Timer.AddSeconds( - $Session.WatchdogInterval)) {
                        $Miner_Failed = $true
                    }
                }
                $Miner_PowerDraw = 0
                $Miner_Index++
            }

            if ($Statset -eq $Miner.Algorithm.Count) {$Miner.Benchmarked = 0}

            $Miner.EndOfRoundCleanup()            

            Write-ActivityLog $Miner -Crashed $(if ($Miner_Failed) {2} else {0})
            if ($Miner_Failed) {
                $Miner.SetStatus([MinerStatus]::Failed)
                $Miner.Stopped = $true
                Write-Log -Level Warn "Miner $($Miner.Name) mining $($Miner.Algorithm -join '/') on pool $($Miner.Pool -join '/') temporarily disabled. "
                $Miner_Failed_Total++
            } else {
                if (-not $Miner.Donator) {Set-Total $Miner -Quiet}
            }            
        }
    }
    if ($Watchdog) {-not $Miner_Failed_Total}
}

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("Error", "Warn", "Info", "Verbose", "Debug")][string]$Level = "Info"
    )

    Begin {
        if ($Session.SetupOnly) {return}
    }
    Process {
        # Inherit the same verbosity settings as the script importing this
        if (-not $PSBoundParameters.ContainsKey('InformationPreference')) { $InformationPreference = $PSCmdlet.GetVariableValue('InformationPreference') }
        if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
        if (-not $PSBoundParameters.ContainsKey('Debug')) {$DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')}

        # Get mutex named RBMWriteLog. Mutexes are shared across all threads and processes.
        # This lets us ensure only one thread is trying to write to the file at a time.
        $mutex = New-Object System.Threading.Mutex($false, "RBM$(Get-MD5Hash ([io.fileinfo](".\Logs")).FullName)")

        $filename = ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd").txt"
        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if (-not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}

        switch ($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                Write-Error -Message $Message
            }
            'Warn' {
                $LevelText = 'WARNING:'
                Write-Warning -Message $Message
            }
            'Info' {
                $LevelText = 'INFO:'
                Write-Information -MessageData $Message
            }
            'Verbose' {
                $LevelText = 'VERBOSE:'
                Write-Verbose -Message $Message
            }
            'Debug' {
                $LevelText = 'DEBUG:'
                Write-Debug -Message $Message
            }
        }

        # Attempt to aquire mutex, waiting up to 2 second if necessary.  If aquired, write to the log file and release mutex.  Otherwise, display an error.
        $NoLog = Switch ($Session.LogLevel) {
                    "Silent" {$true}
                    "Info"   {$Level -eq "Debug"}
                    "Warn"   {@("Info","Debug") -icontains $Level}
                    "Error"  {@("Warn","Info","Debug") -icontains $Level}
                }

        if (-not $NoLog) {
            if ($mutex.WaitOne(2000)) {
                $proc = Get-Process -id $PID
                "$date [$("{0:n2}" -f ($proc.WorkingSet64/1MB)) $("{0:n2}" -f ($proc.PrivateMemorySize64/1MB))] $LevelText $Message" | Out-File -FilePath $filename -Append -Encoding utf8
                $mutex.ReleaseMutex()
            }
            else {
                Write-Warning -Message "Log file is locked, unable to write message to $FileName."
            }
        }
    }
    End {}
}

Function Write-ActivityLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()]$Miner,
        [Parameter(Mandatory = $false)][Int]$Crashed = 0
    )

    Begin { }
    Process {
        $ActiveStart = $Miner.GetActiveStart()

        if (-not $ActiveStart) {return}

        $mutex = New-Object System.Threading.Mutex($false, "RBMWriteActivityLog")

        $filename = ".\Logs\Activity_$(Get-Date -Format "yyyy-MM-dd").txt"

        # Attempt to aquire mutex, waiting up to 1 second if necessary.  If aquired, write to the log file and release mutex.  Otherwise, display an error.
        if ($mutex.WaitOne(1000)) {
            $ocmode = if ($Miner.DeviceModel -notmatch "^CPU") {$Session.OCmode} else {"off"}
            "$([PSCustomObject]@{
                ActiveStart    = "{0:yyyy-MM-dd HH:mm:ss}" -f $ActiveStart
                ActiveLast     = "{0:yyyy-MM-dd HH:mm:ss}" -f $Miner.GetActiveLast()
                Name           = $Miner.BaseName
                Device         = @($Miner.DeviceModel)
                Algorithm      = @($Miner.BaseAlgorithm)
                Pool           = @($Miner.Pool)
                Speed          = @($Miner.Speed_Live)
                Profit         = $Miner.Profit
                PowerDraw      = $Miner.PowerDraw
                Ratio          = $Miner.RejectedShareRatio
                Crashed        = $Crashed
                OCmode         = $ocmode
                OCP            = if ($ocmode -eq "ocp") {$Miner.OCprofile} elseif ($ocmode -eq "msia") {$Miner.MSIAprofile} else {$null}
            } | ConvertTo-Json -Compress)," | Out-File -FilePath $filename -Append -Encoding utf8
            $mutex.ReleaseMutex()
        }
        else {
            Write-Error -Message "Activity log file is locked, unable to write message to $FileName."
        }
    }
    End {}
}

function Set-Total {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Miner,
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date),
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Updated_UTC  = $Updated.ToUniversalTime()

    $Path0        = "Stats\Totals"
    $Path_Name    = "$($Miner.Pool[0])_Total.txt"
    $PathCsv_Name = "Totals_$("{0:yyyy-MM-dd}" -f (Get-Date)).csv"

    $Path    = "$Path0\$Path_Name"
    $PathCsv = "$Path0\$PathCsv_Name"

    try {
        $Duration = $Miner.GetRunningTime($true)

        $TotalProfit    = ($Miner.Profit + $(if ($Session.Config.UsePowerPrice -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {$Miner.Profit_Cost} else {0}))*$Duration.TotalDays 
        $TotalCost      = $Miner.Profit_Cost * $Duration.TotalDays
        $TotalPower     = $Miner.PowerDraw * $Duration.TotalDays
        $Penalty        = [double]($Miner.PoolPenalty | Select-Object -First 1)
        $PenaltyFactor  = 1-$Penalty/100
        $TotalProfitApi = if ($PenaltyFactor -gt 0) {$TotalProfit/$PenaltyFactor} else {0}

        if ($TotalProfit -gt 0) {
            $CsvLine = [PSCustomObject]@{
                Date        = $Updated
                Date_UTC    = $Updated_UTC
                PoolName    = "$($Miner.Pool | Select-Object -First 1)"
                Algorithm   = "$($Miner.BaseAlgorithm | Select-Object -First 1)"
                Currency    = $Miner.Currency
                Rate        = [Math]::Round($Session.Rates.USD,2)
                Profit      = [Math]::Round($TotalProfit*1e8,4)
                ProfitApi   = [Math]::Round($TotalProfitApi*1e8,4)
                Cost        = [Math]::Round($TotalCost*1e8,4)
                Power       = [Math]::Round($TotalPower,3)
                Penalty     = $Penalty
                Duration    = [Math]::Round($Duration.TotalMinutes,3)
                Donation    = "$(if ($Miner.Donator) {"1"} else {"0"})"
            }
            $CsvLine.PSObject.Properties | Foreach-Object {$_.Value = "$($_.Value)"}
            if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}
            $CsvLine | Export-Csv $PathCsv -NoTypeInformation -ErrorAction Ignore -Append
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (Test-Path $Path) {Write-Log -Level $(if ($Quiet) {"Info"} else {"Warn"}) "Could not write to $($PathCsv_Name) "}
    }

    $Stat = Get-Content $Path -ErrorAction Ignore -Raw

    try {
        $Stat = $Stat | ConvertFrom-Json -ErrorAction Stop
        if ($Stat.ProfitApi -eq $null) {$Stat | Add-Member ProfitApi 0 -Force}
        $Stat.Duration  += $Duration.TotalMinutes
        $Stat.Cost      += $TotalCost
        $Stat.Profit    += $TotalProfit
        $Stat.ProfitApi += $TotalProfitApi
        $Stat.Power     += $TotalPower
        $Stat.Updated    = $Updated_UTC
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (Test-Path $Path) {Write-Log -Level $(if ($Quiet) {"Info"} else {"Warn"}) "Totals file ($Path_Name) is corrupt and will be reset. "}
        $Stat = [PSCustomObject]@{
                    Pool          = $Miner.Pool[0]
                    Duration      = $Duration.TotalMinutes
                    Cost          = $TotalCost
                    Profit        = $TotalProfit
                    ProfitApi     = $TotalProfitApi
                    Power         = $TotalPower
                    Started       = $Updated_UTC
                    Updated       = $Updated_UTC
                }
    }

    if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}
    $Stat | ConvertTo-Json | Set-Content $Path
}

function Set-TotalsAvg {

    $Updated        = (Get-Date).ToUniversalTime()
    $Path0          = "Stats\Totals"

    $LastValid      = (Get-Date).AddDays(-30)
    $LastValid_File = "Totals_$("{0:yyyy-MM-dd}" -f $LastValid)"
    $Last1w_File    = "Totals_$("{0:yyyy-MM-dd}" -f $((Get-Date).AddDays(-8)))"

    $Last1d = (Get-Date).AddDays(-1)
    $Last1w = (Get-Date).AddDays(-7)

    Get-ChildItem "Stats\Totals" -Filter "Totals_*.csv" | Where-Object {$_.BaseName -lt $LastValid_File} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}

    $Totals = [PSCustomObject]@{}
    Get-ChildItem "Stats\Totals" -Filter "*_TotalAvg.txt" | Foreach-Object {
        $PoolName = $_.BaseName -replace "_TotalAvg"
        $Started = (Get-Content $_.FullName -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).Started
        $Totals | Add-Member $PoolName ([PSCustomObject]@{
                            Pool          = $PoolName
                            Cost_1d       = 0
                            Cost_1w       = 0
                            Cost_Avg      = 0
                            Profit_1d     = 0
                            Profit_1w     = 0
                            Profit_Avg    = 0
                            ProfitApi_1d  = 0
                            ProfitApi_1w  = 0
                            ProfitApi_Avg = 0
                            Power_1d      = 0
                            Power_1w      = 0
                            Power_Avg     = 0
                            Started       = if ($Started) {$Started} else {$Updated}
                            Updated       = $Updated
                        })
    }

    try {
        $FirstDate = $CurrentDate = ""
        Get-ChildItem "Stats\Totals" -Filter "Totals_*.csv" | Where-Object {$_.BaseName -ge $Last1w_File} | Sort-Object BaseName | Foreach-Object {
            Import-Csv $_.FullName -ErrorAction Ignore | Where-Object {$_.Date -ge $Last1w -and [decimal]$_.Profit -gt 0 -and $_.Donation -ne "1" -and $Totals."$($_.PoolName)" -ne $null} | Foreach-Object {
                if (-not $FirstDate) {$FirstDate = $_.Date}
                $CurrentDate = $_.Date
                $Totals."$($_.PoolName)".ProfitApi_1w += [decimal]$_.ProfitApi
                $Totals."$($_.PoolName)".Profit_1w    += [decimal]$_.Profit
                $Totals."$($_.PoolName)".Power_1w     += [decimal]$_.Power
                $Totals."$($_.PoolName)".Cost_1w      += [decimal]$_.Cost
                if ($_.Date -ge $Last1d) {
                    $Totals."$($_.PoolName)".ProfitApi_1d += [decimal]$_.Profit
                    $Totals."$($_.PoolName)".Profit_1d    += [decimal]$_.Profit
                    $Totals."$($_.PoolName)".Power_1d     += [decimal]$_.Power
                    $Totals."$($_.PoolName)".Cost_1d      += [decimal]$_.Cost
                }
            }
        }
    } catch {
        if ($Error.Count) {$Error.RemoveAt(0)}
    }

    if ($CurrentDate -gt $FirstDate) {
        $Duration = [DateTime]$CurrentDate - [DateTime]$FirstDate
        $Totals.PSObject.Properties | Foreach-Object {
            try {
                if ($Duration.TotalDays -le 1) {
                    $_.Value.Profit_Avg    = $_.Value.Profit_1d
                    $_.Value.ProfitApi_Avg = $_.Value.ProfitApi_1d
                    $_.Value.Cost_Avg      = $_.Value.Cost_1d
                    $_.Value.Power_Avg     = $_.Value.Power_1d
                } else {
                    $_.Value.Profit_Avg    = ($_.Value.Profit_1w / $Duration.TotalDays)
                    $_.Value.ProfitApi_Avg = ($_.Value.ProfitApi_1w / $Duration.TotalDays)
                    $_.Value.Cost_Avg      = ($_.Value.Cost_1w / $Duration.TotalDays)
                    $_.Value.Power_Avg     = ($_.Value.Power_1w / $Duration.TotalDays)
                }

                if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}
                $_.Value | ConvertTo-Json -Depth 10 | Set-Content "$Path0/$($_.Name)_TotalAvg.txt" -Force
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }
    }
}

function Set-Balance {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Balance,
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date),
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Updated_UTC = $Updated.ToUniversalTime()

    $Name = "$($Balance.Name)_$($Balance.Currency)_Balance"

    $Path0 = "Stats\Balances"
    $Path = "$Path0\$($Name).txt"

    $Stat = Get-Content $Path -ErrorAction Ignore -Raw

    $Balance_Total = [Decimal]$Balance.Total
    $Balance_Paid  = [Decimal]$Balance.Paid

    try {
        $Stat = $Stat | ConvertFrom-Json -ErrorAction Stop

        $Stat = [PSCustomObject]@{
                    PoolName = $Balance.Name
                    Currency = $Balance.Currency
                    Balance  = [Decimal]$Stat.Balance
                    Paid     = [Decimal]$Stat.Paid
                    Earnings = [Decimal]$Stat.Earnings
                    Earnings_1h   = [Decimal]$Stat.Earnings_1h
                    Earnings_1d   = [Decimal]$Stat.Earnings_1d
                    Earnings_1w   = [Decimal]$Stat.Earnings_1w
                    Earnings_Avg  = [Decimal]$Stat.Earnings_Avg
                    Last_Earnings = @($Stat.Last_Earnings | Foreach-Object {[PSCustomObject]@{Date = [DateTime]$_.Date;Value = [Decimal]$_.Value}} | Select-Object)
                    Started  = [DateTime]$Stat.Started
                    Updated  = [DateTime]$Stat.Updated
        }

        if ($Balance.Paid -ne $null) {
            $Earnings = [Decimal]($Balance_Total - $Stat.Balance + $Balance_Paid - $Stat.Paid)
        } else {
            $Earnings = [Decimal]($Balance_Total - $Stat.Balance)
            if ($Earnings -lt 0) {$Earnings = $Balance_Total}
        }

        if ($Earnings -gt 0) {
            $Stat.Balance   = $Balance_Total
            $Stat.Paid      = $Balance_Paid
            $Stat.Earnings += $Earnings
            $Stat.Updated   = $Updated_UTC

            $Stat.Last_Earnings += [PSCustomObject]@{Date=$Updated_UTC;Value=$Earnings}

            $Rate = [Decimal]$Session.Rates."$($Balance.Currency)"
            if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}
            
            $CsvLine = [PSCustomObject]@{
                Date      = $Updated
                Date_UTC  = $Updated_UTC
                PoolName  = $Balance.Name
                Currency  = $Balance.Currency
                Rate      = $Rate
                Balance   = $Stat.Balance
                Paid      = $Stat.Paid
                Earnings  = $Stat.Earnings
                Value     = $Earnings
                Balance_Sat = if ($Rate -gt 0) {[int64]($Stat.Balance / $Rate * 1e8)} else {0}
                Paid_Sat  = if ($Rate -gt 0) {[int64]($Stat.Paid  / $Rate * 1e8)} else {0}
                Earnings_Sat = if ($Rate -gt 0) {[int64]($Stat.Earnings / $Rate * 1e8)} else {0}
                Value_Sat  = if ($Rate -gt 0) {[int64]($Earnings  / $Rate * 1e8)} else {0}
            }
            $CsvLine | Export-Csv "$($Path0)\Earnings_Localized.csv" -NoTypeInformation -UseCulture -Append -ErrorAction Ignore
            $CsvLine.PSObject.Properties | Foreach-Object {$_.Value = "$($_.Value)"}
            $CsvLine | Export-Csv "$($Path0)\Earnings.csv" -NoTypeInformation -Append -ErrorAction Ignore
            Remove-Variable "CsvLine" -Force
        }

        $Stat.Last_Earnings = @($Stat.Last_Earnings | Where-Object Date -gt ($Updated_UTC.AddDays(-7)) | Select-Object)

        $Stat.Earnings_1h = [Decimal]($Stat.Last_Earnings | Where-Object Date -ge ($Updated_UTC.AddHours(-1)) | Measure-Object -Property Value -Sum).Sum
        $Stat.Earnings_1d = [Decimal]($Stat.Last_Earnings | Where-Object Date -ge ($Updated_UTC.AddDays(-1)) | Measure-Object -Property Value -Sum).Sum
        $Stat.Earnings_1w = [Decimal]($Stat.Last_Earnings | Where-Object Date -ge ($Updated_UTC.AddDays(-7)) | Measure-Object -Property Value -Sum).Sum

        if ($Stat.Earnings_1w) {
            $Duration = ($Updated_UTC - ($Stat.Last_Earnings | Select-Object -First 1).Date).TotalDays
            if ($Duration -gt 1) {
                $Stat.Earnings_Avg = [Decimal](($Stat.Last_Earnings | Measure-Object -Property Value -Sum).Sum / $Duration)
            } else {
                $Stat.Earnings_Avg = $Stat.Earnings_1d
            }
        } else {
            $Stat.Earnings_Avg = 0
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (Test-Path $Path) {Write-Log -Level $(if ($Quiet) {"Info"} else {"Warn"}) "Balances file ($Name) is corrupt and will be reset. "}
        $Stat = [PSCustomObject]@{
                    PoolName = $Balance.Name
                    Currency = $Balance.Currency
                    Balance  = $Balance_Total
                    Paid     = $Balance_Paid
                    Earnings = 0
                    Earnings_1h   = 0
                    Earnings_1d   = 0
                    Earnings_1w   = 0
                    Earnings_Avg  = 0
                    Last_Earnings = @()
                    Started  = $Updated_UTC
                    Updated  = $Updated_UTC
                }
    }

    if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}
    $Stat | ConvertTo-Json -Depth 10 | Set-Content $Path
    $Stat
}

function Set-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $true)]
        [Double]$Value,
        [Parameter(Mandatory = $false)]
        [Double]$Actual24h = 0,
        [Parameter(Mandatory = $false)]
        [Double]$Estimate24h = 0,
        [Parameter(Mandatory = $false)]
        [Double]$Difficulty = 0.0,
        [Parameter(Mandatory = $false)]
        [Double]$Ratio = 0.0,
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date).ToUniversalTime(), 
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration, 
        [Parameter(Mandatory = $false)]
        [Bool]$FaultDetection = $false,
        [Parameter(Mandatory = $false)]
        [Bool]$ChangeDetection = $false,
        [Parameter(Mandatory = $false)]
        [Double]$FaultTolerance = 0.1,
        [Parameter(Mandatory = $false)]
        [Double]$PowerDraw = 0,
        [Parameter(Mandatory = $false)]
        [Double]$HashRate = 0,
        [Parameter(Mandatory = $false)]
        [Double]$BlockRate = 0,
        [Parameter(Mandatory = $false)]
        [Double]$UplimProtection = 0,
        [Parameter(Mandatory = $false)]
        [String]$Sub = "",
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Updated = $Updated.ToUniversalTime()

    $Mode     = ""
    $LogLevel = if ($Quiet) {"Info"} else {"Warn"}

    if ($Name -match '_Profit$')       {$Path0 = "Stats\Pools";    $Mode = "Pools"}
    elseif ($Name -match '_Hashrate$') {$Path0 = "Stats\Miners";   $Mode = "Miners"}
    else                               {$Path0 = "Stats";          $Mode = "Profit"}

    if ($Sub) {
        #legacy
        if (Test-Path ("$Path0\$Name.txt")) {Move-Item "$Path0\$Name.txt" "$Path0\$Sub-$Name.txt" -Force}
        $Path = "$Path0\$Sub-$Name.txt"
    } else {
        $Path = "$Path0\$Name.txt"
    }

    $SmallestValue = 1E-20

    $Stat = Get-Content $Path -ErrorAction Ignore -Raw
   
    try {
        $Stat = $Stat | ConvertFrom-Json -ErrorAction Stop

        if ($Mode -in @("Pools","Profit") -and $Stat.Week_Fluctuation -and [Double]$Stat.Week_Fluctuation -ge 0.8) {throw "Fluctuation out of range"}

        $AddStat = Switch($Mode) {
            "Miners" {
                @{
                    PowerDraw_Live     = [Double]$Stat.PowerDraw_Live
                    PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                    Diff_Live          = [Double]$Stat.Diff_Live
                    Diff_Average       = [Double]$Stat.Diff_Average
                    Ratio_Live         = [Double]$Stat.Ratio_Live
                    Ratio_Average      = [Double]$Stat.Ratio_Average
                }
            }
            "Pools" {
                @{
                    HashRate_Live      = [Double]$Stat.HashRate_Live
                    HashRate_Average   = [Double]$Stat.HashRate_Average
                    BlockRate_Live     = [Double]$Stat.BlockRate_Live
                    BlockRate_Average  = [Double]$Stat.BlockRate_Average
                    Actual24h_Week     = [Double]$Stat.Actual24h_Week
                    Estimate24h_Week   = [Double]$Stat.Estimate24h_Week
                    ErrorRatio         = [Double]$Stat.ErrorRatio
                }
            }
        }

        $Stat = [PSCustomObject]@{
            Live = [Double]$Stat.Live
            Minute = [Double]$Stat.Minute
            Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
            Minute_5 = [Double]$Stat.Minute_5
            Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
            Minute_10 = [Double]$Stat.Minute_10
            Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
            Hour = [Double]$Stat.Hour
            Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
            Day = [Double]$Stat.Day
            Day_Fluctuation = [Double]$Stat.Day_Fluctuation
            ThreeDay = [Double]$Stat.ThreeDay
            ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
            Week = [Double]$Stat.Week
            Week_Fluctuation = [Double]$Stat.Week_Fluctuation
            Duration = [TimeSpan]$Stat.Duration
            Updated = [DateTime]$Stat.Updated
            Failed = [Int]$Stat.Failed
        }
        if ($AddStat) {$Stat | Add-Member -NotePropertyMembers $AddStat}

        if ($Stat.Day -and -not $Stat.ThreeDay) {$Stat.ThreeDay=($Stat.Day+$Stat.Week)/2;$Stat.ThreeDay_Fluctuation=($Stat.Day_Fluctuation+$Stat.Week_Fluctuation)/2} #backward compatibility

        $ToleranceMin = $Value
        $ToleranceMax = $Value

        if ($FaultDetection) {
            if ($FaultTolerance -eq $null) {$FaultTolerance = 0.1}
            if ($FaultTolerance -lt 1) {
                $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance + $Stat.Failed/100), 0.9))
                $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance + $Stat.Failed/100 + 0.1), 0.9))
            } elseif ($Stat.Hour -gt 0) {
                if ($FaultTolerance -lt 2) {$FaultTolerance = 2}
                $ToleranceMin = $Stat.Hour / $FaultTolerance
                $ToleranceMax = $Stat.Hour * $FaultTolerance
            }
        } elseif ($Stat.Hour -gt 0 -and $UplimProtection -gt 1.0) {            
            $ToleranceMax = $Stat.Hour * $UplimProtection
        }

        if ($ChangeDetection -and [Decimal]$Value -eq [Decimal]$Stat.Live) {$Updated = $Stat.updated}
        
        if ($Value -gt 0 -and $ToleranceMax -eq 0) {$ToleranceMax = $Value}

        if ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax) {
            if (-not $Quiet) {
                if ($mode -eq "Miners") {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value | ConvertTo-Hash) is outside fault tolerance $($ToleranceMin | ConvertTo-Hash) to $($ToleranceMax | ConvertTo-Hash). "}
                else {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString("N2")) is outside fault tolerance $($ToleranceMin.ToString("N2")) to $($ToleranceMax.ToString("N2")). "}
            }
            $Stat.Failed += 10
            if ($Stat.Failed > 30) {$Stat.Failed = 30}
        } else {
            $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
            $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
            $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
            $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
            $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
            $Span_ThreeDay = [Math]::Min(($Duration.TotalDays / 3) / [Math]::Min(($Stat.Duration.TotalDays / 3), 1), 1)
            $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

            $AddStat = $null
            Switch($Mode) {
                "Miners" {
                    $AddStat = @{
                        PowerDraw_Live     = $PowerDraw
                        PowerDraw_Average  = if ($Stat.PowerDraw_Average -gt 0) {((1 - $Span_Week) * $Stat.PowerDraw_Average) + ($Span_Week * $PowerDraw)} else {$PowerDraw}
                        Diff_Live          = $Difficulty
                        Diff_Average       = if ($Stat.Diff_Average -gt 0) {((1 - $Span_Day) * $Stat.Diff_Average) + ($Span_Day * $Difficulty)} else {$Difficulty}
                        Ratio_Live         = $Ratio
                        Ratio_Average      = if ($Stat.Ratio_Average -gt 0) {[Math]::Round(((1 - $Span_Hour) * $Stat.Ratio_Average) + ($Span_Hour * $Ratio),4)} else {$Ratio}
                    }
                }
                "Pools" {
                    $AddStat = @{
                        HashRate_Live      = $HashRate
                        HashRate_Average   = if ($Stat.HashRate_Average -gt 0) {((1 - $Span_Hour) * $Stat.HashRate_Average) + ($Span_Hour * [Double]$HashRate)} else {$HashRate}
                        BlockRate_Live     = $BlockRate
                        BlockRate_Average  = if ($Stat.BlockRate_Average -gt 0) {((1 - $Span_Hour) * $Stat.BlockRate_Average) + ($Span_Hour * [Double]$BlockRate)} else {$BlockRate}
                        Actual24h_Week     = if ($Stat.Actual24h_Week -gt 0) {((1 - $Span_Week) * $Stat.Actual24h_Week) + ($Span_Week * $Actual24h)} else {$Actual24h}
                        Estimate24h_Week   = if ($Stat.Estimate24h_Week -gt 0) {((1 - $Span_Week) * $Stat.Estimate24h_Week) + ($Span_Week * $Estimate24h)} else {$Estimate24h}
                        ErrorRatio         = $Stat.ErrorRatio
                    }
                }
            }

            $Stat = [PSCustomObject]@{
                Live = $Value
                Minute = ((1 - $Span_Minute) * $Stat.Minute) + ($Span_Minute * $Value)
                Minute_Fluctuation = ((1 - $Span_Minute) * $Stat.Minute_Fluctuation) + 
                ($Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue)))
                Minute_5 = ((1 - $Span_Minute_5) * $Stat.Minute_5) + ($Span_Minute_5 * $Value)
                Minute_5_Fluctuation = ((1 - $Span_Minute_5) * $Stat.Minute_5_Fluctuation) + 
                ($Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue)))
                Minute_10 = ((1 - $Span_Minute_10) * $Stat.Minute_10) + ($Span_Minute_10 * $Value)
                Minute_10_Fluctuation = ((1 - $Span_Minute_10) * $Stat.Minute_10_Fluctuation) + 
                ($Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue)))
                Hour = ((1 - $Span_Hour) * $Stat.Hour) + ($Span_Hour * $Value)
                Hour_Fluctuation = ((1 - $Span_Hour) * $Stat.Hour_Fluctuation) + 
                ($Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue)))
                Day = ((1 - $Span_Day) * $Stat.Day) + ($Span_Day * $Value)
                Day_Fluctuation = ((1 - $Span_Day) * $Stat.Day_Fluctuation) + 
                ($Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue)))
                ThreeDay = ((1 - $Span_ThreeDay) * $Stat.ThreeDay) + ($Span_ThreeDay * $Value)
                ThreeDay_Fluctuation = ((1 - $Span_ThreeDay) * $Stat.ThreeDay_Fluctuation) + 
                ($Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue)))
                Week = ((1 - $Span_Week) * $Stat.Week) + ($Span_Week * $Value)
                Week_Fluctuation = ((1 - $Span_Week) * $Stat.Week_Fluctuation) + 
                ($Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue)))
                Duration = $Stat.Duration + $Duration
                Updated = $Updated
                Failed = [Math]::Max($Stat.Failed-1,0)
            }
            $Stat.PSObject.Properties.Name | Where-Object {$_ -match "Fluctuation" -and $Stat.$_ -gt 1} | Foreach-Object {$Stat.$_ = 0}
            if ($AddStat) {$Stat | Add-Member -NotePropertyMembers $AddStat}
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (-not $Quiet -and (Test-Path $Path)) {Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. "}

        $Stat = [PSCustomObject]@{
            Live = $Value
            Minute = $Value
            Minute_Fluctuation = 0
            Minute_5 = $Value
            Minute_5_Fluctuation = 0
            Minute_10 = $Value
            Minute_10_Fluctuation = 0
            Hour = $Value
            Hour_Fluctuation = 0
            Day = $Value
            Day_Fluctuation = 0
            ThreeDay = $Value
            ThreeDay_Fluctuation = 0
            Week = $Value
            Week_Fluctuation = 0
            Duration = $Duration
            Updated = $Updated
            Failed = 0
        }

        Switch($Mode) {
            "Miners" {
                $Stat | Add-Member -NotePropertyMembers @{
                    PowerDraw_Live     = $PowerDraw
                    PowerDraw_Average  = $PowerDraw
                    Diff_Live          = $Difficulty
                    Diff_Average       = $Difficulty
                    Ratio_Live         = $Ratio
                    Ratio_Average      = $Ratio
                }
            }
            "Pools" {
                $Stat | Add-Member -NotePropertyMembers @{
                    HashRate_Live      = $HashRate
                    HashRate_Average   = $HashRate
                    BlockRate_Live     = $BlockRate
                    BlockRate_Average  = $BlockRate
                    Actual24h_Week     = $Actual24h
                    Estimate24h_Week   = $Estimate24h
                    ErrorRatio         = 0
                }
            }
        }
    }

    if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}

    if ($Stat.Duration -ne 0) {
        $OutStat = [PSCustomObject]@{
            Live = [Decimal]$Stat.Live
            Minute = [Decimal]$Stat.Minute
            Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
            Minute_5 = [Decimal]$Stat.Minute_5
            Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
            Minute_10 = [Decimal]$Stat.Minute_10
            Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
            Hour = [Decimal]$Stat.Hour
            Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
            Day = [Decimal]$Stat.Day
            Day_Fluctuation = [Double]$Stat.Day_Fluctuation
            ThreeDay = [Decimal]$Stat.ThreeDay
            ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
            Week = [Decimal]$Stat.Week
            Week_Fluctuation = [Double]$Stat.Week_Fluctuation
            Duration = [String]$Stat.Duration
            Updated = [DateTime]$Stat.Updated
            Failed = [Int]$Stat.Failed
        }
        Switch($Mode) {
            "Miners" {
                $OutStat | Add-Member -NotePropertyMembers @{
                    PowerDraw_Live     = [Decimal]$Stat.PowerDraw_Live
                    PowerDraw_Average  = [Decimal]$Stat.PowerDraw_Average
                    Diff_Live          = [Decimal]$Stat.Diff_Live
                    Diff_Average       = [Decimal]$Stat.Diff_Average
                    Ratio_Live         = [Decimal]$Stat.Ratio_Live
                    Ratio_Average      = [Decimal]$Stat.Ratio_Average
                }
            }
            "Pools" {
                $OutStat | Add-Member -NotePropertyMembers @{
                    HashRate_Live      = [Decimal]$Stat.HashRate_Live
                    HashRate_Average   = [Decimal]$Stat.HashRate_Average
                    BlockRate_Live     = [Decimal]$Stat.BlockRate_Live
                    BlockRate_Average  = [Decimal]$Stat.BlockRate_Average
                    Actual24h_Week     = [Decimal]$Stat.Actual24h_Week
                    Estimate24h_Week   = [Decimal]$Stat.Estimate24h_Week
                    ErrorRatio         = [Decimal](1+$(if ($Stat.Estimate24h_Week) {($Stat.Actual24h_Week/$Stat.Estimate24h_Week-1) * $(if ($Stat.Duration.TotalDays -lt 7) {$Stat.Duration.TotalDays/7*(2 - $Stat.Duration.TotalDays/7)} else {1})}))
                }
            }
        }
        $OutStat | ConvertTo-Json | Set-Content $Path
    }

    $Stat
}

function Get-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [String]$Sub = "",
        [Parameter(Mandatory = $false)]
        [Switch]$Pools = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Miners = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Totals = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$TotalAvgs = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Balances = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$All = $false
    )

    if ($Name) {
        # Return single requested stat
        if ($Name -match '_Profit$') {$Path = "Stats\Pools"}
        elseif ($Name -match '_Hashrate$') {$Path = "Stats\Miners"}
        elseif ($Name -match '_(Total|TotalAvg)$') {$Path = "Stats\Totals"}
        elseif ($Name -match '_Balance$') {$Path = "Stats\Balances"}
        else {$Path = "Stats"}

        if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

        if ($Sub) {
            #legacy
            if (Test-Path ("$Path\$Name.txt")) {Move-Item "$Path\$Name.txt" "$Path\$Sub-$Name.txt" -Force}
            $Path = "$Path\$Sub-$Name.txt"
        } else {
            $Path = "$Path\$Name.txt"
        }
        if (Test-Path $Path) {ConvertFrom-Json (Get-Content $Path -ErrorAction Ignore -Raw) -ErrorAction Ignore}
    } else {
        # Return all stats
        [hashtable]$Stats = @{}

        if (($Miners -or $All) -and -not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        if (($Pools  -or $All) -and -not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (($Totals -or $TotalAvgs -or $All) -and -not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}
        if (($Balances -or $All) -and -not (Test-Path "Stats\Balances")) {New-Item "Stats\Balances" -ItemType "directory" > $null}

        $Match = @()
        if ($Miners)    {$Match += "Hashrate"}
        if ($Pools)     {$Match += "Profit|BLK|HSR|TTF"}
        if ($Totals)    {$Match += "Total"}
        if ($TotalAvgs) {$Match += "TotalAvg"}
        if ($Balances)  {$Match += "Balance"}

        $MatchStr = $Match -join "|"

        foreach($p in (Get-ChildItem -Recurse "Stats" -File)) {
            $BaseName = $p.BaseName
            $FullName = $p.FullName
            if (-not $All -and $BaseName -notmatch "_($MatchStr)$") {continue}
            try {
                $Stats[$BaseName -replace "^(AMD|CPU|NVIDIA)-"] = ConvertFrom-Json (Get-Content $FullName -ErrorAction Stop -Raw) -ErrorAction Stop
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                #Remove broken stat file
                Write-Log -Level Warn "Stat file ($BaseName) is corrupt and will be removed. "
                if (Test-Path $FullName) {Remove-Item -Path  $FullName -Force -Confirm:$false}
            }
        }
        Return $Stats
    }
}

function Confirm-ConfigHealth {
    $Ok = $true
    $Session.ConfigFiles.GetEnumerator() | Where-Object {$_.Value.Path -and (Test-Path $_.Value.Path)} | Where-Object {(Get-ChildItem $_.Value.Path).LastWriteTime.ToUniversalTime() -gt $_.Value.LastWriteTime} | Foreach-Object {
        $Name = $_.Name
        $File = $_.Value
        try {
            Get-Content $File.Path -ErrorAction Stop -Raw | ConvertFrom-Json -ErrorAction Stop > $null
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "$($Name) configfile $(Split-Path $File.Path -Leaf) has invalid JSON syntax!"
            $Ok = $false
        }
    }
    $Ok
}

function Get-ChildItemContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path, 
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quick = $false
    )

    function Invoke-ExpressionRecursive ($Expression) {
        if ($Expression -is [String]) {
            if ($Expression -match '(\$|")') {
                try {$Expression = Invoke-Expression $Expression}
                catch {if ($Error.Count){$Error.RemoveAt(0)};$Expression = Invoke-Expression "`"$Expression`""}
            }
        }
        elseif ($Expression -is [PSCustomObject]) {
            $Expression | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                $Expression.$_ = Invoke-ExpressionRecursive $Expression.$_
            }
        }
        return $Expression
    }

    Get-ChildItem $Path -File -ErrorAction Ignore | ForEach-Object {
        $Name = $_.BaseName
        $Content = @()
        if ($_.Extension -eq ".ps1") {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}
                & $_.FullName @Parameters                
            }
        }
        elseif ($Quick) {
            $Content = try {$_ | Get-Content -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)};$null}
            if ($Content -eq $null) {$Content = $_ | Get-Content}
        }
        else {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}                
                try {
                    ($_ | Get-Content -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop) | ForEach-Object {Invoke-ExpressionRecursive $_}
                }
                catch [ArgumentException] {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    $null
                }
            }
            if ($Content -eq $null) {$Content = $_ | Get-Content}
        }
        foreach ($c in $Content) {
            if ($c.Name) {
                [PSCustomObject]@{Name = $c.Name; BaseName = $Name; Content = $c}
            }
            else {
                [PSCustomObject]@{Name = $Name; BaseName = $Name; Content = $c}
            }
        }
        if ($Force -and $Content) {
            foreach ($k in $Parameters.Keys) {
                if (-not (Get-Member -InputObject $Content -Name $k -Membertype Properties)) {
                    $Content | Add-Member $k $Parameters.$k -Force 
                }
            }
        }
    }
}

function Get-PoolsData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$PoolName
    )
    if (Test-Path ".\Data\Pools\$($PoolName).json") {
        Get-Content ".\Data\Pools\$($PoolName).json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
    }
}

function Get-PoolsContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$PoolName, 
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,        
        [Parameter(Mandatory = $true)]
        [TimeSpan]$StatSpan,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Algorithms = $null,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Coins = $null,
        [Parameter(Mandatory = $false)]
        [Bool]$InfoOnly = $false,
        [Parameter(Mandatory = $false)]
        [Bool]$IgnoreFees = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableErrorRatio = $false
    )
        
    Get-ChildItem "Pools\$($PoolName).ps1" -File -ErrorAction Ignore | ForEach-Object {
        $Pool_Name = $_.BaseName

        if ($EnableErrorRatio -and $Config.DataWindow -in @("actual_last24h","minimum-3","minimum-2h")) {$EnableErrorRatio = $false}

        [Hashtable]$Parameters = @{
            StatSpan = $StatSpan
            InfoOnly = $InfoOnly
        }
        foreach($p in $Config.PSObject.Properties.Name) {$Parameters.$p = $Config.$p}

        foreach($Pool in @(& $_.FullName @Parameters)) {
            if ($PoolName -ne "WhatToMine") {
                $Penalty = [Double]$Config.Penalty + [Double]$Algorithms."$($Pool.Algorithm)".Penalty + [Double]$Coins."$($Pool.CoinSymbol)".Penalty
                $Pool_Factor = 1-($Penalty + [Double]$(if (-not $IgnoreFees){$Pool.PoolFee}) )/100
                if ($EnableErrorRatio -and $Pool.ErrorRatio) {$Pool_Factor *= $Pool.ErrorRatio}
                if ($Pool_Factor -lt 0) {$Pool_Factor = 0}
                if ($Pool.Price -eq $null) {$Pool.Price = 0}
                if ($Pool.StablePrice -eq $null) {$Pool.StablePrice = 0}
                $Pool.Price *= $Pool_Factor
                $Pool.StablePrice *= $Pool_Factor
                $Pool.Penalty = $Penalty
                $Pool.PenaltyFactor = $Pool_Factor
            }
            $Pool
        }
    }
}

function Get-MinersContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Pools = @{},
        [Parameter(Mandatory = $false)]
        [Switch]$InfoOnly,
        [Parameter(Mandatory = $false)]
        [String]$MinerName = "*"
    )

    [Hashtable]$Parameters = @{
        Pools    = $Pools
        InfoOnly = $InfoOnly
    }

    foreach($Miner in @(Get-ChildItem "Miners\$($MinerName).ps1" -File -ErrorAction Ignore | Where-Object {$InfoOnly -or $Session.Config.MinerName.Count -eq 0 -or (Compare-Object $Session.Config.MinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | Where-Object {$InfoOnly -or $Session.Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Session.Config.ExcludeMinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0})) {
        $Name = $Miner.BaseName
        if ($InfoOnly -or ((Compare-Object @($Session.DevicesToVendors.Values | Select-Object) @($Session.MinerInfo.$Name | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0)) {
            foreach($c in @(& $Miner.FullName @Parameters)) {
                if ($InfoOnly) {
                    $c | Add-Member -NotePropertyMembers @{
                        Name     = if ($c.Name) {$c.Name} else {$Name}
                        BaseName = $Name
                    } -Force -PassThru
                } else {
                    $c.PowerDraw = $Session.Stats."$($c.Name)_$($c.BaseAlgorithm[0])_HashRate".PowerDraw_Average
                    if (@($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name) -icontains $c.DeviceModel) {$c.DeviceModel = $Session.DevicesByTypes.FullComboModels."$($c.DeviceModel)"}
                    $c
                }
            }
        }
    }
}

function Get-BalancesContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    [Hashtable]$Parameters = @{
        Config  = $Config
    }

    $UsePools = Get-ChildItem "Pools" -File -ErrorAction Ignore | Select-Object -ExpandProperty BaseName | Where-Object {($Config.PoolName.Count -eq 0 -or $Config.PoolName -icontains $_) -and ($Config.ExcludePoolName -eq 0 -or $Config.ExcludePoolName -inotcontains $_)}
    foreach($Balance in @(Get-ChildItem "Balances" -File -ErrorAction Ignore | Where-Object {$UsePools -match "^$($_.BaseName)`(Coins|Party|Solo`)?$" -or $Config.ShowPoolBalancesExcludedPools})) {
        $Name = $Balance.BaseName 
        foreach($c in @(& $Balance.FullName @Parameters)) {
            $c | Add-Member -NotePropertyMembers @{
                Name = "$(if ($c.Name) {$c.Name} else {$Name})$(if ($c.Info) {$c.Info})"
                BaseName = $Name
            } -Force -PassThru
        }
    }
}

filter ConvertTo-Float {
    [CmdletBinding()]
    $Num = $_

    switch ([math]::floor([math]::log($Num, 1e3))) {
        "-Infinity" {"0  "}
        -2 {"{0:n2} µ" -f ($Num * 1e6)}
        -1 {"{0:n2} m" -f ($Num * 1e3)}
         0 {"{0:n2}  " -f ($Num / 1)}
         1 {"{0:n2} k" -f ($Num / 1e3)}
         2 {"{0:n2} M" -f ($Num / 1e6)}
         3 {"{0:n2} G" -f ($Num / 1e9)}
         4 {"{0:n2} T" -f ($Num / 1e12)}
         Default {"{0:n2} P" -f ($Num / 1e15)}
    }
}

filter ConvertTo-Hash { 
    "$($_ | ConvertTo-Float)H"
}

function ConvertFrom-Hash {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Hash
    )
    try {$Num = [double]($Hash -replace "[^0-9`.]")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Num=0}
    [int64]$(switch (($Hash -replace "[^kMGHTP]")[0]) {
        "k" {$Num*1e3}
        "M" {$Num*1e6}
        "G" {$Num*1e9}
        "T" {$Num*1e12}
        "P" {$Num*1e15}
        default {$Num}
    })
}

function ConvertFrom-Time {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Time
    )
    try {$Num = [double]($Time -replace "[^0-9`.]")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Num=0}
    [int64]$(switch (($Time -replace "[^mhdw]")[0]) {
        "m" {$Num*60}
        "h" {$Num*3600}
        "d" {$Num*86400}
        "w" {$Num*604800}
        default {$Num}
    })
}

function ConvertTo-LocalCurrency { 
    [CmdletBinding()]
    # To get same numbering scheme regardless of value BTC value (size) to determine formatting
    # Use $Offset to add/remove decimal places

    param(
        [Parameter(Mandatory = $true)]
        [Double]$Number, 
        [Parameter(Mandatory = $true)]
        [Double]$BTCRate,
        [Parameter(Mandatory = $false)]
        [Int]$Offset = 2
    )

    ($Number * $BTCRate).ToString("N$([math]::max([math]::min([math]::truncate(10 - $Offset - [math]::log10($BTCRate)),9),0))")
}

function ConvertTo-BTC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Double]$Number, 
        [Parameter(Mandatory = $false)]
        [Int]$Offset = 2
    )

    $Currency = "BTC"
    if ($Number -ne 0) {
        switch ([math]::truncate([math]::log([math]::Abs($Number), 1000))) {
            -1 {$Currency = "mBTC";$Number*=1e3;$Offset = 5}
            -2 {$Currency = "µBTC";$Number*=1e6;$Offset = 8}
            -3 {$Currency = "sat"; $Number*=1e8;$Offset = 10}
        }
    }

    "$(ConvertTo-LocalCurrency $Number -BTCRate 1 -Offset $Offset) $Currency"
}

function Get-Combination {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Array]$Value, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMax = $Value.Count, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMin = 1
    )

    $Combination = [PSCustomObject]@{}

    for ($i = 0; $i -lt $Value.Count; $i++) {
        $Combination | Add-Member @{[Math]::Pow(2, $i) = $Value[$i]}
    }

    $Combination_Keys = $Combination | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    for ($i = $SizeMin; $i -le $SizeMax; $i++) {
        $x = [Math]::Pow(2, $i) - 1

        while ($x -le [Math]::Pow(2, $Value.Count) - 1) {
            [PSCustomObject]@{Combination = $Combination_Keys | Where-Object {$_ -band $x} | ForEach-Object {$Combination.$_}}
            $smallest = ($x -band - $x)
            $ripple = $x + $smallest
            $new_smallest = ($ripple -band - $ripple)
            $ones = (($new_smallest / $smallest) -shr 1) - 1
            $x = $ripple -bor $ones
        }
    }
}

function Get-BestMinerDeviceCombos {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $BestMiners = @(),
        [Parameter(Mandatory = $false)]
        [String]$SortBy = "Profit_Bias"
    )
    if ($BestMiners) {
        $BestMiners_DeviceNames = @($BestMiners | Select-Object -ExpandProperty DeviceName -Unique | Sort-Object)
        $Miners_Device_Combos   = (Get-Combination ($BestMiners | Select-Object DeviceName -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty DeviceName) $BestMiners_DeviceNames | Measure-Object).Count -eq 0})
        $Miners_Device_Combos | ForEach-Object {
            $Miner_Device_Combo = $_.Combination
            [PSCustomObject]@{
                Combination = $Miner_Device_Combo | ForEach-Object {
                    $Miner_Device_Count = $_.DeviceName.Count
                    [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                    $BestMiners | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
                }
            }
        } | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object $SortBy -Sum).Sum} | Select-Object -First 1 | Select-Object -ExpandProperty Combination
    }
}

function Start-SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Bool]$ShowMinerWindow = $false,
        [Parameter(Mandatory = $false)]
        [Bool]$IsWrapper = $false,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [Int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String]$ScreenName = ""
    )

    if ($IsLinux -and (Get-Command "screen" -ErrorAction Ignore) -and (Get-Command "start-stop-daemon" -ErrorAction Ignore)) {
        Start-SubProcessInScreen -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -ScreenName $ScreenName
    } elseif (($ShowMinerWindow -and -not $IsWrapper) -or -not $IsWindows) {
        Start-SubProcessInConsole -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess
    } else {
        Start-SubProcessInBackground -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess
    }
}

function Start-SubProcessInBackground {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [Int]$MultiProcess = 0
    )

    [int[]]$Running = @()
    Get-SubProcessRunningIds $FilePath | Foreach-Object {$Running += $_}

    $ScriptBlock = "Set-Location '$WorkingDirectory'; (Get-Process -Id `$PID).PriorityClass = '$(@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority])'; "
    $ScriptBlock += "& '$FilePath'"
    if ($ArgumentList) {$ScriptBlock += " $ArgumentList"}
    $ScriptBlock += " *>&1"
    $ScriptBlock += " | Write-Output"
    if ($LogPath) {$ScriptBlock += " | Tee-Object '$LogPath'"}

    $Job = Start-Job ([ScriptBlock]::Create("$(($EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {"`$env:$($Matches[1])=$($Matches[2]); "}))$($ScriptBlock)"))
    
    [int[]]$ProcessIds = @()
    
    if ($Job) {
        Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $Running | Foreach-Object {$ProcessIds += $_}
    }
    
    Set-SubProcessPriority $ProcessIds -Priority $Priority -CPUAffinity $CPUAffinity

    [PSCustomObject]@{
        ScreenName = ""
        Process    = $Job
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Start-SubProcessInConsole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0
    )

    [int[]]$Running = @()
    Get-SubProcessRunningIds $FilePath | Foreach-Object {$Running += $_}

    $LDExp = if ($IsLinux) {if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")}} else {""}
    $Job = Start-Job -ArgumentList $PID, (Resolve-Path ".\DotNet\Tools\CreateProcess.cs"), $LDExp, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars, $IsWindows, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation {
        param($ControllerProcessID, $CreateProcessPath, $LDExportPath, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars, $StartWithoutTakingFocus, $CurrentPwd)

        $EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {Set-Item -force -path "env:$($matches[1])" -value $matches[2]}

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        if ($StartWithoutTakingFocus) {
            Add-Type -Path $CreateProcessPath
            $lpApplicationName = $FilePath;
            $lpCommandLine = '"' + $FilePath + '"' #Windows paths cannot contain ", so there is no need to escape
            if ($ArgumentList -ne "") {$lpCommandLine += " " + $ArgumentList}
            $lpProcessAttributes = New-Object SECURITY_ATTRIBUTES
            $lpProcessAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpProcessAttributes)
            $lpThreadAttributes = New-Object SECURITY_ATTRIBUTES
            $lpThreadAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpThreadAttributes)
            $bInheritHandles = $false
            $dwCreationFlags = [CreationFlags]::CREATE_NEW_CONSOLE
            $lpEnvironment = [IntPtr]::Zero
            if ($WorkingDirectory -ne "") {$lpCurrentDirectory = $WorkingDirectory} else {$lpCurrentDirectory = $using:pwd}
            $lpStartupInfo = New-Object STARTUPINFO
            $lpStartupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($lpStartupInfo)
            $lpStartupInfo.wShowWindow = [ShowWindow]::SW_SHOWMINNOACTIVE
            $lpStartupInfo.dwFlags = [STARTF]::STARTF_USESHOWWINDOW
            $lpProcessInformation = New-Object PROCESS_INFORMATION

            [Kernel32]::CreateProcess($lpApplicationName, $lpCommandLine, [ref] $lpProcessAttributes, [ref] $lpThreadAttributes, $bInheritHandles, $dwCreationFlags, $lpEnvironment, $lpCurrentDirectory, [ref] $lpStartupInfo, [ref] $lpProcessInformation)
            $Process = Get-Process -Id $lpProcessInformation.dwProcessID
        } else {
            $ProcessParams = @{
                FilePath         = $FilePath
                ArgumentList     = $ArgumentList
                WorkingDirectory = $WorkingDirectory
                PassThru         = $true
            }

            if ($IsLinux) {
                # Linux requires output redirection, otherwise Receive-Job fails
                $ProcessParams.RedirectStandardOutput = $LogPath
                $ProcessParams.RedirectStandardError  = $LogPath -replace ".txt","-err.txt"

                # Fix executable permissions
                (Start-Process "chmod" -ArgumentList "+x $FilePath" -PassThru).WaitForExit() > $null

                # Set lib path to local
                #$BE = "/usr/lib/x86_64-linux-gnu/libcurl-compat.so.3.0.0"
                $env:LD_LIBRARY_PATH = "$($LDExportPath)"
            }

            $Process = Start-Process @ProcessParams
        }
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

        $ControllerProcess.Handle >$null
        $Process.Handle >$null

        do {
            if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow()>$null}
            if ($Error.Count) {$Error | Out-File (Join-Path $CurrentPwd "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").jobs.txt") -Append -Encoding utf8}
            $Error.Clear()
        }
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    [int[]]$ProcessIds = @()
    
    if ($JobOutput) {
        Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $Running | Foreach-Object {$ProcessIds += $_}
     }

    if (-not $ProcessIds.Count -and $JobOutput.ProcessId) {$ProcessIds += $JobOutput.ProcessId}

    Set-SubProcessPriority $ProcessIds -Priority $Priority -CPUAffinity $CPUAffinity
    
    [PSCustomObject]@{
        ScreenName = ""
        Process    = $Job
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Start-SubProcessInScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String]$ScreenName = ""
    )

    $ScreenName = ($ScreenName -replace "[^A-Z0-9_-]").ToLower()

    if (-not $ScreenName) {$ScreenName = Get-MD5Hash "$FilePath $ArgumentList";$ScreenName = "$($ScreenName.SubString(0,3))$($ScreenName.SubString(28,3))".ToLower()}

    if (-not (Test-Path ".\Data\pid")) {New-Item ".\Data\pid" -ItemType "directory" -force > $null}

    $PIDPath = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_pid.txt"
    $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_info.txt"
    $PIDBash = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName).sh"
    $PIDTest = Join-Path $WorkingDirectory "start_$($ScreenName).sh"

    if (Test-Path $PIDPath) { Remove-Item $PIDPath -Force }
    if (Test-Path $PIDInfo) { Remove-Item $PIDInfo -Force }
    if (Test-Path $PIDBash) { Remove-Item $PIDBash -Force }

    if ($LogPath) {
        $ArgumentList = "$ArgumentList 2>&1 | tee `'$($LogPath)`'"
    }

    Set-ContentJson -Data @{miner_exec = "$FilePath"; start_date = "$(Get-Date)"; pid_path = "$PIDPath" } -PathToFile $PIDInfo > $null

    $Stuff = @()
    $Stuff += "cd /"
    $Stuff += "cd '$WorkingDirectory'"

    $Stuff += "export GPU_FORCE_64BIT_PTR=1"
    $Stuff += "export GPU_MAX_HEAP_SIZE=100"
    $Stuff += "export GPU_USE_SYNC_OBJECTS=1"
    $Stuff += "export GPU_MAX_ALLOC_PERCENT=100"
    $Stuff += "export GPU_SINGLE_ALLOC_PERCENT=100"
    $Stuff += "export GPU_MAX_WORKGROUP_SIZE=256"
    $Stuff += "export CUDA_DEVICE_ORDER=PCI_BUS_ID"

    $EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {$Stuff += "export $($matches[1])=$($matches[2])"}

    $Stuff += "export LD_LIBRARY_PATH=./:$(if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")})"
    $Stuff += "start-stop-daemon --start --make-pidfile --chdir '$WorkingDirectory' --pidfile '$PIDPath' --exec '$FilePath' -- $ArgumentList"

    $Cmd = @()
    $Cmd += "screen -ls `"$ScreenName`" | ("
    $Cmd += "  IFS=`$(printf '\t');"
    $Cmd += "  sed `"s/^`$IFS//`" |"
    $Cmd += "  while read -r name stuff; do"
    $Cmd += "    screen -S `"`$name`" -X quit  >/dev/null 2>&1"
    $Cmd += "    screen -S `"`$name`" -X quit  >/dev/null 2>&1"
    $Cmd += "  done"
    $Cmd += ")"
    $Cmd += "screen -S $($ScreenName) -d -m", "sleep .1"

    $Stuff | Foreach-Object {$Cmd += "screen -S $($ScreenName) -X stuff $`"$_\n`"", "sleep .1"}

    Set-BashFile -FilePath $PIDbash -Cmd $Cmd
    Set-BashFile -FilePath $PIDtest -Cmd $Stuff

    (Start-Process "chmod" -ArgumentList "+x $FilePath" -PassThru).WaitForExit() > $null
    (Start-Process "chmod" -ArgumentList "+x $PIDBash" -PassThru).WaitForExit() > $null
    (Start-Process "chmod" -ArgumentList "+x $PIDTest" -PassThru).WaitForExit() > $null

    $Job = Start-Job -ArgumentList $PID, $WorkingDirectory, $Session.OCDaemonPrefix,$PIDPath, $PIDBash, $ScreenName, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation, $Session.IsAdmin {
        param($ControllerProcessID, $WorkingDirectory, $OCDaemonPrefix, $PIDPath, $PIDBash, $ScreenName, $CurrentPwd, $IsAdmin)

        Import-Module "$(Join-Path $CurrentPwd "OCDaemon.psm1")"

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        $StopWatch = New-Object -TypeName System.Diagnostics.StopWatch

        $Process  = $null
        $BashProc = $null
        $started  = $false

        if (Test-OCDaemon) {
            $started = Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.0.$ScreenName" -FilePath $PIDBash -Move -Quiet
        } else {
            $ProcessParams = @{
                FilePath         = $PIDBash
                ArgumentList     = ""
                WorkingDirectory = $WorkingDirectory
                PassThru         = $true
            }
            if ($null -ne ($BashProc = Start-Process @ProcessParams)) {
                $started = $BashProc.WaitForExit(60000)
                Remove-Variable "BashProc" -Force
            }
        }
        if ($started) {
            $StopWatch.Restart()
            do {
                Start-Sleep -Milliseconds 500
                if (Test-Path $PIDPath) {
                    $ProcessId = [int](Get-Content $PIDPath -Raw -ErrorAction Ignore | Select-Object -First 1)
                    if ($ProcessId) {$Process = Get-Process -Id $ProcessId -ErrorAction Ignore}
                }
            } until ($Process -ne $null -or ($StopWatch.Elapsed.TotalSeconds) -ge 10)
            $StopWatch.Stop()
        }

        Remove-Variable "StopWatch"

        if (-not $Process) {
            [PSCustomObject]@{ProcessId = $null}
            return
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

        $ControllerProcess.Handle >$null
        $Process.Handle >$null
        $ProcessName = $Process.Name

        do {
            if ($ControllerProcess.WaitForExit(1000)) {
                $ArgumentList = "--stop --name $ProcessName --pidfile $PIDPath --retry 5"
                if (Test-OCDaemon) {
                    Invoke-OCDaemonWithName -Name "$OCDaemonPrefix.1.$ScreenName" -Cmd "start-stop-daemon $ArgumentList" -Quiet > $null
                } else {
                    (Start-Process "start-stop-daemon" -ArgumentList $ArgumentList -PassThru).WaitForExit() > $null
                }
            }
            if ($Error.Count) {$Error | Out-File (Join-Path $CurrentPwd "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").jobs.txt") -Append -Encoding utf8}
            $Error.Clear()
        }
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    [int[]]$ProcessIds = @()
    
    if ($JobOutput.ProcessId) {$ProcessIds += $JobOutput.ProcessId}
    
    [PSCustomObject]@{
        ScreenName = $ScreenName
        Process    = $Job
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Get-SubProcessRunningIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath
    )
    if ($IsWindows) {Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $FilePath} | Select-Object -ExpandProperty ProcessId}
    elseif ($IsLinux) {Get-Process | Where-Object {$_.Path -eq $FilePath} | Select-Object -ExpandProperty Id}
}

function Get-SubProcessIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "",
        [Parameter(Mandatory = $false)]
        [int[]]$Running = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0
    )

    if (-not $IsWindows) {return}

    $WaitCount = 0
    $ProcessFound = 0
    do {
        Start-Sleep -Milliseconds 100
        Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $FilePath -and $_.CommandLine -like "*$($ArgumentList)*" -and $Running -inotcontains $_.ProcessId} | Foreach-Object {
            $Running += $_.ProcessId
            $ProcessFound++
            $_.ProcessId
            Write-Log -Level Info "$($_.ProcessId) found for $FilePath"
        }
        $WaitCount++
    } until (($WaitCount -gt 100) -or ($ProcessFound -gt $MultiProcess))
}

function Set-SubProcessPriority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $ProcessId,
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0
    )
    $ProcessId | Where-Object {$_} | Foreach-Object {
        try {
            if ($Process = Get-Process -Id $_ -ErrorAction Stop) {
                $Process.PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]
                if ($CPUAffinity) {$Process.ProcessorAffinity = $CPUAffinity}
            }
        } catch {
            Write-Log -Level Warn "Could not set process priority/affinity: $($_.Exception.Message)"
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    }
}

function Stop-SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Job,
        [Parameter(Mandatory = $false)]
        [String]$Title = "Process",
        [Parameter(Mandatory = $false)]
        [String]$Name = ""
    )
    if ($Job.HasOwnMinerWindow -and $Job.ProcessId) {
        $Job.ProcessId | Select-Object -First 1 | Foreach-Object {
            if ($Process = Get-Process -Id $_ -ErrorAction Ignore) {
                if ($IsLinux) {
                    if ($Job.ScreenName) {
                        try {
                            $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($Job.ScreenName)_info.txt"
                            if ($MI = Get-Content $PIDInfo -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore) {
                                $ArgumentList = "--stop --name $($Process.Name) --pidfile $($MI.pid_path) --retry 5"
                                if (Test-OCDaemon) {
                                    $Msg = Invoke-OCDaemon -Cmd "start-stop-daemon $ArgumentList"
                                    if ($Msg) {Write-Log -Level Info "OCDaemon reports: $Msg"}
                                } else {
                                    (Start-Process "start-stop-daemon" -ArgumentList $ArgumentList -PassThru).WaitForExit() > $null
                                }
                                if (Test-Path $MI.pid_path) {Remove-Item -Path $MI.pid_path -ErrorAction Ignore -Force}
                                if (Test-Path $PIDInfo) {Remove-Item -Path $PIDInfo -ErrorAction Ignore -Force}
                            }
                        } catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            Write-Log -Level Warn "Problem killing screen process $($Job.ScreenName): $($_.Exception.Message)"
                        }
                    } else {
                        Stop-Process -id $Process.Id -Force -ErrorAction Ignore
                    }
                }
                else {$Process.CloseMainWindow() > $null}
                # Wait up to 10 seconds for the miner to close gracefully
                if($Process.WaitForExit(10000)) { 
                    Write-Log "$($Title) closed gracefully$(if ($Name) {": $($Name)"})"
                    Start-Sleep 1
                } else {
                    Write-Log -Level Warn "$($Title) failed to close within 10 seconds$(if ($Name) {": $($Name)"})"
                }
            }
        }
    }
    if ($Job.ProcessId) {
        $Job.ProcessId | Foreach-Object {
            if ($Process = Get-Process -Id $_ -ErrorAction Ignore) {
                if (-not $Process.HasExited) {
                    Write-Log -Level Info "Attempting to kill $($Title) PID $($_)$(if ($Name) {": $($Name)"})"
                    Stop-Process -InputObject $Process -ErrorAction Ignore -Force
                }
            }
        }
        $Job.ProcessId = [int[]]@()
    }
    if ($Job.Process | Get-Job -ErrorAction Ignore) {
        $Job.Process | Remove-Job -Force
    }
}

function Expand-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $false)]
        [String]$Path = "",
        [Parameter(Mandatory = $false)]
        [String[]]$ProtectedFiles = @(),
        [Parameter(Mandatory = $false)]
        [String]$Sha256 = "",
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "-qb"
    )

    # Set current path used by .net methods to the same as the script's path
    [Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" > $null}
    if (-not (Test-Path ".\Bin"))       {New-Item "Bin" -ItemType "directory" > $null}
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName) {Remove-Item $FileName}
    $oldProgressPreference = $Global:ProgressPreference
    $Global:ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    $Global:ProgressPreference = $oldProgressPreference

    if ($Sha256 -and (Test-Path $FileName)) {if ($Sha256 -ne (Get-FileHash $FileName -Algorithm SHA256).Hash) {Remove-Item $FileName; throw "Downloadfile $FileName has wrong hash! Please open an issue at github.com."}}

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        (Start-Process $FileName $ArgumentList -PassThru).WaitForExit()>$null
    }
    else {
        $Path_Old = (Join-Path (Split-Path $Path) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
        $Path_New = (Join-Path (Split-Path $Path) (Split-Path $Path -Leaf))
        $Path_Bak = (Join-Path (Split-Path $Path) "$(Split-Path $Path -Leaf).$(Get-Date -Format "yyyyMMdd_HHmmss")")

        if (Test-Path $Path_Old) {Remove-Item $Path_Old -Recurse -Force}

        $FromFullPath = [IO.Path]::GetFullPath($FileName)
        $ToFullPath   = [IO.Path]::GetFullPath($Path_Old)
        if ($IsLinux) {
            if (-not (Test-Path $ToFullPath)) {New-Item $ToFullPath -ItemType "directory" > $null}
            if (($FileName -split '\.')[-2] -eq 'tar') {
                $Params = @{
                    FilePath     = "tar"
                    ArgumentList = "-xa -f $FromFullPath -C $ToFullPath"
                }
            } elseif (($FileName -split '\.')[-1] -in @('tgz')) {
                $Params = @{
                    FilePath     = "tar"
                    ArgumentList = "-xz -f $FromFullPath -C $ToFullPath"
                }
            } else {
                $Params = @{
                    FilePath     = "7z"
                    ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y"
                    RedirectStandardOutput = Join-Path ".\Logs" "7z-console.log"
                    RedirectStandardError  = Join-Path ".\Logs" "7z-error.log"
                }
            }
        } else {
            $Params = @{
                FilePath     = "7z"
                ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y -spe"
                WindowStyle  = "Hidden"
            }
        }

        $Params.PassThru = $true
        (Start-Process @Params).WaitForExit()>$null

        if (Test-Path $Path_Bak) {Remove-Item $Path_Bak -Recurse -Force}
        if (Test-Path $Path_New) {Rename-Item $Path_New (Split-Path $Path_Bak -Leaf) -Force}
        if (Get-ChildItem $Path_Old -File) {
            Rename-Item $Path_Old (Split-Path $Path -Leaf)
        }
        else {
            Get-ChildItem $Path_Old -Directory | ForEach-Object {Move-Item (Join-Path $Path_Old $_.Name) $Path_New}
            Remove-Item $Path_Old -Recurse -Force
        }
        if (Test-Path $Path_Bak) {
            $ProtectedFiles | Foreach-Object {Get-ChildItem (Join-Path $Path_Bak $_) -ErrorAction Ignore -File | Where-Object {[IO.Path]::GetExtension($_) -notmatch "(dll|exe|bin)$"} | Foreach-Object {Copy-Item $_ $Path_New -Force}}
            Get-ChildItem (Join-Path (Split-Path $Path) "$(Split-Path $Path -Leaf).*") -Directory | Sort-Object Name -Descending | Select-Object -Skip 3 | Foreach-Object {Remove-Item $_ -Recurse -Force}
        }
    }
}

function Invoke-Exe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,ValueFromPipeline = $True)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [Parameter(Mandatory = $false)]
        [Int]$WaitForExit = 5,
        [Parameter(Mandatory = $false)]
        [Switch]$ExpandLines,
        [Parameter(Mandatory = $false)]
        [Switch]$ExcludeEmptyLines,
        [Parameter(Mandatory = $false)]
        [Switch]$AutoWorkingDirectory = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Runas = $false
        )
    try {
        if ($WorkingDirectory -eq '' -and $AutoWorkingDirectory) {$WorkingDirectory = Get-Item $FilePath | Select-Object -ExpandProperty FullName | Split-path}

        if ($IsWindows -or -not $Runas -or (Test-IsElevated)) {
            if ($IsLinux) {
                $psi = New-object System.Diagnostics.ProcessStartInfo $FilePath
            } else {
                $psi = New-object System.Diagnostics.ProcessStartInfo
                $psi.FileName = Resolve-Path $FilePath
            }
            $psi.CreateNoWindow = $true
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.Arguments = $ArgumentList
            $psi.WorkingDirectory = $WorkingDirectory
            if ($Runas) {$psi.Verb = "runas"}
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            [void]$process.Start()
            $out = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit($WaitForExit*1000)>$null
        } else {
            if ($FilePath -match "IncludesLinux") {$FilePath = Get-Item $FilePath | Select-Object -ExpandProperty FullName}
            $out = Invoke-OCDaemon "$FilePath $ArgumentList"
        }

        if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}

    } catch {
        if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Could not execute $FilePath $($ArgumentList): $($_.Exception.Message)"
    } finally {
        if ($psi) {
            $process.Dispose()
            Remove-Variable "psi" -ErrorAction Ignore -Force
            Remove-Variable "process" -ErrorAction Ignore -Force
        }
    }
}

function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $true)]
        [String]$Port, 
        [Parameter(Mandatory = $false)]
        [String]$Request = "",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$DoNotSendNewline,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet,
        [Parameter(Mandatory = $false)]
        [Switch]$WriteOnly,
        [Parameter(Mandatory = $false)]
        [Switch]$ReadToEnd
    )
    $Response = $null
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    #try {$ipaddress = [ipaddress]$Server} catch {$ipaddress = [system.Net.Dns]::GetHostByName($Server).AddressList | select-object -index 0}
    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        if (-not $WriteOnly) {$Reader = New-Object System.IO.StreamReader $Stream}
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        if ($Request) {if ($DoNotSendNewline) {$Writer.Write($Request)} else {$Writer.WriteLine($Request)}}
        if (-not $WriteOnly) {$Response = if ($ReadToEnd) {$Reader.ReadToEnd()} else {$Reader.ReadLine()}}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "Could not request from $($Server):$($Port)"
    }
    finally {
        if ($Reader) {$Reader.Close();$Reader.Dispose()}
        if ($Writer) {$Writer.Close();$Writer.Dispose()}
        if ($Stream) {$Stream.Close();$Stream.Dispose()}
        if ($Client) {$Client.Close();$Client.Dispose()}
    }

    $Response
}

function Invoke-TcpRead {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $true)]
        [String]$Port, 
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet
    )
    $Response = $null
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    #try {$ipaddress = [ipaddress]$Server} catch {$ipaddress = [system.Net.Dns]::GetHostByName($Server).AddressList | select-object -index 0}
    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Response = $Reader.ReadToEnd()
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "Could not read from $($Server):$($Port)"
    }
    finally {
        if ($Reader) {$Reader.Close();$Reader.Dispose()}
        if ($Stream) {$Stream.Close();$Stream.Dispose()}
        if ($Client) {$Client.Close();$Client.Dispose()}
    }

    $Response
}

function Test-TcpServer {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $false)]
        [String]$Port = 4000, 
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 1, #seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$ConvertToIP
    )
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    elseif ($ConvertToIP) {      
        try {$Server = [ipaddress]$Server}
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            try {
                $Server = [system.Net.Dns]::GetHostByName($Server).AddressList | Where-Object {$_.IPAddressToString -match "^\d+\.\d+\.\d+\.\d+$"} | select-object -index 0
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                return $false
            }
        }
    }
    try {
        $Client = New-Object system.Net.Sockets.TcpClient -ErrorAction Stop
        $Conn   = $Client.BeginConnect($Server,$Port,$null,$null)
        $Result = $Conn.AsyncWaitHandle.WaitOne($Timeout*1000,$false)
        if ($Result) {$Client.EndConnect($Conn)>$null}
        $Client.Close()
    } catch {
        if ($Error.Count){if ($Verbose) {Write-Log -Level Warn $Error[0]};$Error.RemoveAt(0)}
        $Result = $false
    }
    $Result
}

function Get-MyIP {
    if ($IsWindows -and ($cmd = Get-Command "ipconfig" -ErrorAction Ignore)) {
        $IpcResult = Invoke-Exe $cmd.Source -ExpandLines | Where-Object {$_ -match 'IPv4.+\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'} | Foreach-Object {$Matches[1]}
        if ($IpcResult.Count -gt 1 -and (Get-Command "Get-NetRoute" -ErrorAction Ignore) -and ($Trunc = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Select-Object -ExpandProperty NextHop | Where-Object {$_ -match '^(\d{1,3}\.\d{1,3}\.)'} | Foreach-Object {$Matches[1]})) {
            $IpcResult = $IpcResult | Where-Object {$_ -match "^$($Trunc)"}
        }
        $IpcResult | Select-Object -First 1
    } elseif ($IsLinux) {
        try {ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'} catch {if ($Error.Count){$Error.RemoveAt(0)};try {hostname -I} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
    }
}

function Get-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @(),
        [Parameter(Mandatory = $false)]
        [String[]]$ExcludeName = @(),
        [Parameter(Mandatory = $false)]
        [Switch]$Refresh = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$IgnoreOpenCL = $false
    )

    if (-not (Test-Path Variable:Script:GlobalDataDeviceList) -or -not $Script:GlobalDataDeviceList) {$Script:GlobalDataDeviceList = Get-Content ".\Data\devices.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}

    if ($Name) {
        $Name_Devices = $Name | ForEach-Object {
            $Name_Split = $_ -split '#'
            $Name_Split = @($Name_Split | Select-Object -First 1) + @($Name_Split | Select-Object -Skip 1 | ForEach-Object {[Int]$_})
            $Name_Split += @("*") * (100 - $Name_Split.Count)

            $Name_Device = $Script:GlobalDataDeviceList.("{0}" -f $Name_Split) | Select-Object *
            $Name_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}

            $Name_Device
        }
    }

    if ($ExcludeName) {
        $ExcludeName_Devices = $ExcludeName | ForEach-Object {
            $Name_Split = $_ -split '#'
            $Name_Split = @($Name_Split | Select-Object -First 1) + @($Name_Split | Select-Object -Skip 1 | ForEach-Object {[Int]$_})
            $Name_Split += @("*") * (100 - $Name_Split.Count)

            $Name_Device = $Script:GlobalDataDeviceList.("{0}" -f $Name_Split) | Select-Object *
            $Name_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}

            $Name_Device
        }
    }

    # Try to get cached devices first to improve performance
    if ((Test-Path Variable:Script:GlobalCachedDevices) -and -not $Refresh) {
        $Script:GlobalCachedDevices | Foreach-Object {
            $Device = $_
            if (
                ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) -and
                ((-not $ExcludeName) -or (-not ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -and -not ($ExcludeName | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})))
             ) {
                $Device
            }
        }
        return
    }

    $Devices = @()
    $PlatformId = 0
    $Index = 0
    $PlatformId_Index = @{}
    $Type_PlatformId_Index = @{}
    $Vendor_Index = @{}
    $Type_Vendor_Index = @{}
    $Type_Index = @{}
    $Type_Mineable_Index = @{}
    $GPUVendorLists = @{}
    $GPUDeviceNames = @{}
    foreach ($GPUVendor in @("NVIDIA","AMD","INTEL")) {$GPUVendorLists | Add-Member $GPUVendor @(Get-GPUVendorList $GPUVendor)}

    $AllPlatforms = @()
    $Platform_Devices = try {
        [OpenCl.Platform]::GetPlatformIDs() | Where-Object {$AllPlatforms -inotcontains "$($_.Name) $($_.Version)"} | ForEach-Object {
            $AllPlatforms +=  "$($_.Name) $($_.Version)"
            $Device_Index = 0
            [PSCustomObject]@{
                PlatformId=$PlatformId
                Devices=[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | Foreach-Object {
                    [PSCustomObject]@{
                        DeviceIndex     = $Device_Index
                        Name            = $_.Name
                        Type            = $_.Type
                        Vendor          = $_.Vendor
                        GlobalMemSize   = $_.GlobalMemSize
                        MaxComputeUnits = $_.MaxComputeUnits
                        PlatformVersion = $_.Platform.Version
                        PCIBusId        = if ($_.Vendor -match "NVIDIA") {"{0:X2}:{1:X2}" -f [int]$_.PCIBusId,[int]$_.PCISlotId} else {$_.PCITopology}
                        CardId          = -1
                    }
                    $Device_Index++
                }
            }
            $PlatformId++
         }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Cuda = Get-NvidiaSmi | Where-Object {$_} | Foreach-Object {Invoke-Exe $_ -ExcludeEmptyLines -ExpandLines | Where-Object {$_ -match "CUDA.+?:\s*(\d+\.\d+)"} | Foreach-Object {$Matches[1]} | Select-Object -First 1 | Foreach-Object {"$_.0"}}
        if ($Cuda) {
            $OpenCL_Devices = Invoke-NvidiaSmi "index","gpu_name","memory.total","pci.bus_id" | Where-Object {$_.index -match "^\d+$"} | Sort-Object index | Foreach-Object {
                [PSCustomObject]@{
                    DeviceIndex     = $_.index
                    Name            = $_.gpu_name
                    Type            = "Gpu"
                    Vendor          = "NVIDIA Corporation"
                    GlobalMemSize   = 1MB * [int64]$_.memory_total
                    PlatformVersion = "CUDA $Cuda"
                    PCIBusId        = if ($_.pci_bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                    CardId          = -1
                }
            }
            if ($OpenCL_Devices) {[PSCustomObject]@{PlatformId=$PlatformId;Devices=$OpenCL_Devices}}
        } else {
            Write-Log -Level $(if ($IgnoreOpenCL) {"Info"} else {"Warn"}) "OpenCL device detection has failed: $($_.Exception.Message)"
        }
    }

    try {
        $AmdModels   = @{}
        $AmdModelsEx = @()
        $Platform_Devices | Foreach-Object {
            $PlatformId = $_.PlatformId
            $_.Devices | Foreach-Object {    
                $Device_OpenCL = $_

                $Device_Name = [String]$Device_OpenCL.Name -replace '\(TM\)|\(R\)'
                $Vendor_Name = [String]$Device_OpenCL.Vendor
                $InstanceId  = ''
                $SubId = ''
                $PCIBusId = $null
                $CardId = -1

                if ($GPUVendorLists.NVIDIA -icontains $Vendor_Name) {
                    $Vendor_Name = "NVIDIA"
                } elseif ($GPUVendorLists.AMD -icontains $Vendor_Name) {
                    $Vendor_Name = "AMD"
                    if (-not $GPUDeviceNames[$Vendor_Name]) {
                        $GPUDeviceNames[$Vendor_Name] = if ($IsLinux) {
                            if ((Test-OCDaemon) -or (Test-IsElevated)) {
                                try {
                                    $data = @(Get-DeviceName "amd" -UseAfterburner $false | Select-Object)
                                    if (($data | Measure-Object).Count) {Set-ContentJson ".\Data\amd-names.json" -Data $data > $null}
                                } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                            }
                            if (Test-Path ".\Data\amd-names.json") {Get-Content ".\Data\amd-names.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}
                        }
                        if (-not $GPUDeviceNames[$Vendor_Name]) {
                            $GPUDeviceNames[$Vendor_Name] = Get-DeviceName $Vendor_Name -UseAfterburner ($OpenCL_DeviceIDs.Count -lt 7)
                        }
                    }
                    $GPUDeviceNames[$Vendor_Name] | Where-Object Index -eq ([Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)") | Foreach-Object {$Device_Name = $_.DeviceName; $InstanceId = $_.InstanceId; $SubId = $_.SubId; $PCIBusId = $_.PCIBusId; $CardId = $_.CardId}
                    if ($SubId -eq "687F" -or $Device_Name -eq "Radeon RX Vega" -or $Device_Name -eq "gfx900") {
                        if ($Device_OpenCL.MaxComputeUnits -eq 56) {$Device_Name = "Radeon Vega 56"}
                        elseif ($Device_OpenCL.MaxComputeUnits -eq 64) {$Device_Name = "Radeon Vega 64"}
                    } elseif ($Device_Name -eq "gfx906") {
                        $Device_Name = "Radeon VII"
                    }
                    if ($PCIBusId) {$Device_OpenCL.PCIBusId = $PCIBusId}
                } elseif ($GPUVendorLists.INTEL -icontains $Vendor_Name) {
                    $Vendor_Name = "INTEL"
                }

                $Device = [PSCustomObject]@{
                    Index = [Int]$Index
                    PlatformId = [Int]$PlatformId
                    PlatformId_Index = [Int]$PlatformId_Index."$($PlatformId)"
                    Type_PlatformId_Index = [Int]$Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"
                    Vendor = [String]$Vendor_Name
                    Vendor_Name = [String]$Device_OpenCL.Vendor                    
                    Vendor_Index = [Int]$Vendor_Index."$($Device_OpenCL.Vendor)"
                    Type_Vendor_Index = [Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"
                    Type = [String]$Device_OpenCL.Type
                    Type_Index = [Int]$Type_Index."$($Device_OpenCL.Type)"
                    Type_Mineable_Index = [Int]$Type_Mineable_Index."$($Device_OpenCL.Type)"
                    OpenCL = $Device_OpenCL
                    Model = [String]$($Device_Name -replace "[^A-Za-z0-9]+" -replace "GeForce|Radeon|Intel")
                    Model_Name = [String]$Device_Name
                    InstanceId = [String]$InstanceId
                    CardId = $CardId
                    GpuGroup = ""
                }

                if ($Device.Type -ne "Cpu" -and 
                    ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) -and
                    ((-not $ExcludeName) -or (-not ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -and -not ($ExcludeName | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})))
                ) {
                    $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
                    if ($AmdModelsEx -notcontains $Device.Model) {
                        $AmdGb = [int]($Device.OpenCL.GlobalMemSize / 1GB)
                        if ($AmdModels.ContainsKey($Device.Model) -and $AmdModels[$Device.Model] -ne $AmdGb) {$AmdModelsEx+=$Device.Model}
                        else {$AmdModels[$Device.Model]=$AmdGb}
                    }
                    $Index++
                }

                if (-not $Type_PlatformId_Index."$($Device_OpenCL.Type)") {
                    $Type_PlatformId_Index."$($Device_OpenCL.Type)" = @{}
                }
                if (-not $Type_Vendor_Index."$($Device_OpenCL.Type)") {
                    $Type_Vendor_Index."$($Device_OpenCL.Type)" = @{}
                }
                
                $PlatformId_Index."$($PlatformId)"++
                $Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"++
                $Vendor_Index."$($Device_OpenCL.Vendor)"++
                $Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"++
                $Type_Index."$($Device_OpenCL.Type)"++
                if (@("NVIDIA","AMD") -icontains $Vendor_Name) {$Type_Mineable_Index."$($Device_OpenCL.Type)"++}
            }
        }

        $AmdModelsEx | Foreach-Object {
            $Model = $_
            $Devices | Where-Object Model -eq $Model | Foreach-Object {
                $AmdGb = "$([int]($_.OpenCL.GlobalMemSize / 1GB))GB"
                $_.Model = "$($_.Model)$AmdGb"
                $_.Model_Name = "$($_.Model_Name) $AmdGb"
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level $(if ($IgnoreOpenCL) {"Info"} else {"Warn"}) "GPU detection has failed: $($_.Exception.Message)"
    }

    #CPU detection
    try {
        if ($Refresh -or -not (Test-Path Variable:Global:GlobalCPUInfo)) {

            $Global:GlobalCPUInfo = [PSCustomObject]@{}

            if ($IsWindows) {
                try {$chkcpu = @{};([xml](Invoke-Exe ".\Includes\CHKCPU32.exe" -ArgumentList "/x" -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines)).chkcpu32.ChildNodes | Foreach-Object {$chkcpu[$_.Name] = if ($_.'#text' -match "^(\d+)") {[int]$Matches[1]} else {$_.'#text'}}} catch {if ($Error.Count){$Error.RemoveAt(0)}}
                if ($chkcpu.physical_cpus) {
                    $Global:GlobalCPUInfo | Add-Member Name          $chkcpu.cpu_name
                    $Global:GlobalCPUInfo | Add-Member Manufacturer  $chkcpu.cpu_vendor
                    $Global:GlobalCPUInfo | Add-Member Cores         $chkcpu.cores
                    $Global:GlobalCPUInfo | Add-Member Threads       $chkcpu.threads
                    $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  $chkcpu.physical_cpus
                    $Global:GlobalCPUInfo | Add-Member L3CacheSize   $chkcpu.l3
                    $Global:GlobalCPUInfo | Add-Member MaxClockSpeed $chkcpu.cpu_speed
                    $Global:GlobalCPUInfo | Add-Member Features      @{}
                    $chkcpu.GetEnumerator() | Where-Object {"$($_.Value)" -eq "1" -and $_.Name -notmatch '_' -and $_.Name -notmatch "^l\d$"} | Foreach-Object {$Global:GlobalCPUInfo.Features."$($_.Name)" = $true}
                } else {
                    $CIM_CPU = Get-CimInstance -ClassName CIM_Processor
                    $Global:GlobalCPUInfo | Add-Member Name          $CIM_CPU[0].Name
                    $Global:GlobalCPUInfo | Add-Member Manufacturer  $CIM_CPU[0].Manufacturer
                    $Global:GlobalCPUInfo | Add-Member Cores         ($CIM_CPU.NumberOfCores | Measure-Object -Sum).Sum
                    $Global:GlobalCPUInfo | Add-Member Threads       ($CIM_CPU.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
                    $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ($CIM_CPU | Measure-Object).Count
                    $Global:GlobalCPUInfo | Add-Member L3CacheSize   $CIM_CPU[0].L3CacheSize
                    $Global:GlobalCPUInfo | Add-Member MaxClockSpeed $CIM_CPU[0].MaxClockSpeed
                    $Global:GlobalCPUInfo | Add-Member Features      @{}
                    Get-CPUFeatures | Foreach-Object {$Global:GlobalCPUInfo.Features.$_ = $true}
                    if ($CIM_CPU) {Remove-Variable "CIM_CPU" -Force}
                }
            } elseif ($IsLinux) {
                $Data = Get-Content "/proc/cpuinfo"
                if ($Data) {
                    $Global:GlobalCPUInfo | Add-Member Name          (($Data | Where-Object {$_ -match 'model name'} | Select-Object -First 1) -split ":")[1].Trim()
                    $Global:GlobalCPUInfo | Add-Member Manufacturer  (($Data | Where-Object {$_ -match 'vendor_id'}  | Select-Object -First 1) -split ":")[1].Trim()
                    $Global:GlobalCPUInfo | Add-Member Cores         ([int](($Data | Where-Object {$_ -match 'cpu cores'}  | Select-Object -First 1) -split ":")[1].Trim())
                    $Global:GlobalCPUInfo | Add-Member Threads       ([int] (($Data | Where-Object {$_ -match 'siblings'}   | Select-Object -First 1) -split ":")[1].Trim())
                    $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ($Data | Where-Object {$_ -match 'physical id'} | Foreach-Object {[int]($_ -split ":")[1].Trim()} | Select-Object -Unique).Count
                    $Global:GlobalCPUInfo | Add-Member L3CacheSize   ([int]((($Data | Where-Object {$_ -match 'cache size'} | Select-Object -First 1) -split ":")[1].Trim() -split "\s+")[0].Trim())
                    $Global:GlobalCPUInfo | Add-Member MaxClockSpeed ([int](($Data | Where-Object {$_ -match 'cpu MHz'}    | Select-Object -First 1) -split ":")[1].Trim())
                    $Global:GlobalCPUInfo | Add-Member Features      @{}
                    (($Data | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1].Trim() -split "\s+" | ForEach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]+")" = $true}
                }
            }

            $Global:GlobalCPUInfo | Add-Member Vendor $(if ($GPUVendorLists.INTEL -icontains $Global:GlobalCPUInfo.Manufacturer){"INTEL"}else{$Global:GlobalCPUInfo.Manufacturer.ToUpper()})

            if ($IsLinux -and $Global:GlobalCPUInfo.PhysicalCPUs -gt 1) {
                $Global:GlobalCPUInfo.Cores   *= $Global:GlobalCPUInfo.PhysicalCPUs
                $Global:GlobalCPUInfo.Threads *= $Global:GlobalCPUInfo.PhysicalCPUs
                $Global:GlobalCPUInfo.PhysicalCPUs = 1
            }

            $Global:GlobalCPUInfo | Add-Member RealCores ([int[]](0..($Global:GlobalCPUInfo.Threads - 1))) -Force
            if ($Global:GlobalCPUInfo.Threads -gt $Global:GlobalCPUInfo.Cores) {$Global:GlobalCPUInfo.RealCores = $Global:GlobalCPUInfo.RealCores | Where-Object {-not ($_ % [int]($Global:GlobalCPUInfo.Threads/$Global:GlobalCPUInfo.Cores))}}
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "CIM CPU detection has failed. "
    }
   
    try {
        for ($CPUIndex=0;$CPUIndex -lt $Global:GlobalCPUInfo.PhysicalCPUs;$CPUIndex++) {
            # Vendor and type the same for all CPUs, so there is no need to actually track the extra indexes.  Include them only for compatibility.
            $Device = [PSCustomObject]@{
                Index = [Int]$Index
                Vendor = $Global:GlobalCPUInfo.Vendor
                Vendor_Name = $Global:GlobalCPUInfo.Manufacturer
                Type_PlatformId_Index = $CPUIndex
                Type_Vendor_Index = $CPUIndex
                Type = "Cpu"
                Type_Index = $CPUIndex
                Type_Mineable_Index = $CPUIndex
                Model = "CPU"
                Model_Name = $Global:GlobalCPUInfo.Name
                Features = $Global:GlobalCPUInfo.Features.Keys
            }

            if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
            }
            $Index++
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "CPU detection has failed. "
    }

    $Script:GlobalCachedDevices = $Devices
    $Devices
}

function Get-CPUFeatures { 

    Add-Type -Path .\DotNet\Tools\CPUID.cs

    $features = @{}
    $info = [CpuID]::Invoke(0)
    #convert 16 bytes to 4 ints for compatibility with existing code
    $info = [int[]]@(
        [BitConverter]::ToInt32($info, 0 * 4)
        [BitConverter]::ToInt32($info, 1 * 4)
        [BitConverter]::ToInt32($info, 2 * 4)
        [BitConverter]::ToInt32($info, 3 * 4)
    )

    $nIds = $info[0]

    $info = [CpuID]::Invoke(0x80000000)
    $nExIds = [BitConverter]::ToUInt32($info, 0 * 4) #not sure as to why 'nExIds' is unsigned; may not be necessary
    #convert 16 bytes to 4 ints for compatibility with existing code
    $info = [int[]]@(
        [BitConverter]::ToInt32($info, 0 * 4)
        [BitConverter]::ToInt32($info, 1 * 4)
        [BitConverter]::ToInt32($info, 2 * 4)
        [BitConverter]::ToInt32($info, 3 * 4)
    )

    #Detect Features
    if ($nIds -ge 0x00000001) { 

        $info = [CpuID]::Invoke(0x00000001)
        #convert 16 bytes to 4 ints for compatibility with existing code
        $info = [int[]]@(
            [BitConverter]::ToInt32($info, 0 * 4)
            [BitConverter]::ToInt32($info, 1 * 4)
            [BitConverter]::ToInt32($info, 2 * 4)
            [BitConverter]::ToInt32($info, 3 * 4)
        )

        $features.mmx = ($info[3] -band ([int]1 -shl 23)) -ne 0
        $features.sse = ($info[3] -band ([int]1 -shl 25)) -ne 0
        $features.sse2 = ($info[3] -band ([int]1 -shl 26)) -ne 0
        $features.sse3 = ($info[2] -band ([int]1 -shl 00)) -ne 0

        $features.ssse3 = ($info[2] -band ([int]1 -shl 09)) -ne 0
        $features.sse41 = ($info[2] -band ([int]1 -shl 19)) -ne 0
        $features.sse42 = ($info[2] -band ([int]1 -shl 20)) -ne 0
        $features.aes = ($info[2] -band ([int]1 -shl 25)) -ne 0

        $features.avx = ($info[2] -band ([int]1 -shl 28)) -ne 0
        $features.fma3 = ($info[2] -band ([int]1 -shl 12)) -ne 0

        $features.rdrand = ($info[2] -band ([int]1 -shl 30)) -ne 0
    }

    if ($nIds -ge 0x00000007) { 

        $info = [CpuID]::Invoke(0x00000007)
        #convert 16 bytes to 4 ints for compatibility with existing code
        $info = [int[]]@(
            [BitConverter]::ToInt32($info, 0 * 4)
            [BitConverter]::ToInt32($info, 1 * 4)
            [BitConverter]::ToInt32($info, 2 * 4)
            [BitConverter]::ToInt32($info, 3 * 4)
        )

        $features.avx2 = ($info[1] -band ([int]1 -shl 05)) -ne 0

        $features.bmi1 = ($info[1] -band ([int]1 -shl 03)) -ne 0
        $features.bmi2 = ($info[1] -band ([int]1 -shl 08)) -ne 0
        $features.adx = ($info[1] -band ([int]1 -shl 19)) -ne 0
        $features.mpx = ($info[1] -band ([int]1 -shl 14)) -ne 0
        $features.sha = ($info[1] -band ([int]1 -shl 29)) -ne 0
        $features.prefetchwt1 = ($info[2] -band ([int]1 -shl 00)) -ne 0

        $features.avx512_f = ($info[1] -band ([int]1 -shl 16)) -ne 0
        $features.avx512_cd = ($info[1] -band ([int]1 -shl 28)) -ne 0
        $features.avx512_pf = ($info[1] -band ([int]1 -shl 26)) -ne 0
        $features.avx512_er = ($info[1] -band ([int]1 -shl 27)) -ne 0
        $features.avx512_vl = ($info[1] -band ([int]1 -shl 31)) -ne 0
        $features.avx512_bw = ($info[1] -band ([int]1 -shl 30)) -ne 0
        $features.avx512_dq = ($info[1] -band ([int]1 -shl 17)) -ne 0
        $features.avx512_ifma = ($info[1] -band ([int]1 -shl 21)) -ne 0
        $features.avx512_vbmi = ($info[2] -band ([int]1 -shl 01)) -ne 0
    }

    if ($nExIds -ge 0x80000001) { 

        $info = [CpuID]::Invoke(0x80000001)
        #convert 16 bytes to 4 ints for compatibility with existing code
        $info = [int[]]@(
            [BitConverter]::ToInt32($info, 0 * 4)
            [BitConverter]::ToInt32($info, 1 * 4)
            [BitConverter]::ToInt32($info, 2 * 4)
            [BitConverter]::ToInt32($info, 3 * 4)
        )

        $features.x64 = ($info[3] -band ([int]1 -shl 29)) -ne 0
        $features.abm = ($info[2] -band ([int]1 -shl 05)) -ne 0
        $features.sse4a = ($info[2] -band ([int]1 -shl 06)) -ne 0
        $features.fma4 = ($info[2] -band ([int]1 -shl 16)) -ne 0
        $features.xop = ($info[2] -band ([int]1 -shl 11)) -ne 0
    }
    $features.GetEnumerator() | Where-Object Value | Select-Object -ExpandProperty Name
}

function Get-DevicePowerDraw {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$DeviceName = @()
    )
    (($Script:GlobalCachedDevices | Where-Object {-not $DeviceName -or $DeviceName -icontains $_.Name}).Data.PowerDraw | Measure-Object -Sum).Sum
}

function Start-Afterburner {
    if (-not $IsWindows) {return}
    try {
        Add-Type -Path ".\Includes\MSIAfterburner.NET.dll"
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log "Failed to load Afterburner interface library"
        $Script:abMonitor = $false
        $Script:abControl = $false
        return
    }
   
    try {
        $Script:abMonitor = New-Object MSI.Afterburner.HardwareMonitor
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log "Failed to create MSI Afterburner Monitor object. Falling back to standard monitoring."
        $Script:abMonitor = $false
    }
    try {
        $Script:abControl = New-Object MSI.Afterburner.ControlMemory
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log "Failed to create MSI Afterburner Control object. Overclocking non-NVIDIA devices will not be available."
        $Script:abControl = $false
    }

    if ($Script:abControl) {
        $Script:abControlBackup = @($Script:abControl.GpuEntries | Select-Object Index,PowerLimitCur,ThermalLimitCur,CoreClockBoostCur,MemoryClockBoostCur)
    }
}

function Test-Afterburner {
    if (-not $IsWindows) {0}
    else {
        if (-not (Test-Path Variable:Script:abMonitor)) {return -1}
        if ($Script:abMonitor -and $Script:abControl) {1} else {0}
    }
}

function Get-AfterburnerDevices ($Type) {
    if (-not $Script:abControl) {return}

    try {
        $Script:abControl.ReloadAll()
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Failed to communicate with MSI Afterburner"
        return
    }

    if ($Type -in @('AMD', 'NVIDIA', 'INTEL')) {
        $Pattern = @{
            AMD    = "*Radeon*"
            NVIDIA = "*GeForce*"
            Intel  = "*Intel*"
        }
        @($Script:abMonitor.GpuEntries) | Where-Object Device -like $Pattern.$Type | ForEach-Object {
            $abIndex = $_.Index
            $Script:abMonitor.Entries | Where-Object {
                $_.GPU -eq $abIndex -and
                $_.SrcName -match "(GPU\d+ )?" -and
                $_.SrcName -notmatch "CPU"
            } | Format-Table
            @($Script:abControl.GpuEntries)[$abIndex]            
        }
        @($Script:abMonitor.GpuEntries)
    } elseif ($Type -eq 'CPU') {
        $Script:abMonitor.Entries | Where-Object {
            $_.GPU -eq [uint32]"0xffffffff" -and
            $_.SrcName -match "CPU"
        } | Format-Table
    }
}

function Get-NormalizedDeviceName {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$DeviceName,
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "AMD"
    )
    if ($Vendor -ne "AMD") {return $DeviceName}

    $DeviceName = $($DeviceName `
            -replace 'ASUS' `
            -replace 'AMD' `
            -replace '\(?TM\)?' `
            -replace 'Series' `
            -replace 'Graphics' `
            -replace "\s+", ' '
    ).Trim()

    $DeviceName = $DeviceName -replace '.*Radeon.*([4-5]\d0).*', 'Radeon RX $1'     # RX 400/500 series
    $DeviceName = $DeviceName -replace '.*\s(Vega).*(56|64).*', 'Radeon Vega $2'    # Vega series
    $DeviceName = $DeviceName -replace '.*\s(R\d)\s(\w+).*', 'Radeon $1 $2'         # R3/R5/R7/R9 series
    $DeviceName -replace '.*\s(HD)\s?(\w+).*', 'Radeon HD $2'                       # HD series
}

function Get-DeviceName {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "AMD",
        [Parameter(Mandatory = $false)]
        [Bool]$UseAfterburner = $true
    )
    try {
        $Vendor_Cards = if (Test-Path ".\Data\$($Vendor.ToLower())-cards.json") {try {Get-Content ".\Data\$($Vendor.ToLower())-cards.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop}catch{if ($Error.Count){$Error.RemoveAt(0)}}}

        if ($IsWindows -and $UseAfterburner -and $Script:abMonitor) {
            if ($Script:abMonitor) {$Script:abMonitor.ReloadAll()}
            $DeviceId = 0
            $Pattern = @{
                AMD    = '*Radeon*'
                NVIDIA = '*GeForce*'
                Intel  = '*Intel*'
            }
            @($Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Vendor) | ForEach-Object {
                $DeviceName = Get-NormalizedDeviceName $_.Device -Vendor $Vendor
                $SubId = if ($_.GpuId -match "&DEV_([0-9A-F]+?)&") {$Matches[1]} else {"noid"}
                if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                [PSCustomObject]@{
                    Index = $DeviceId
                    DeviceName = $DeviceName
                    InstanceId = $_.GpuId
                    SubId = $SubId
                    PCIBusId = if ($_.GpuId -match "&BUS_(\d+)") {"$("{0:x2}" -f [int]$Matches[1]):00"}
                }
                $DeviceId++
            }
        } else {
            if ($IsWindows -and $Vendor -eq 'AMD') {
                $DeviceId = 0
                
                $AdlResult = Invoke-Exe '.\Includes\OverdriveN.exe' -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed" -and $_ -ne "Failed to load ADL library"}
                $AdlResult | Foreach-Object {
                    $AdlResultSplit = @($_ -split ',' | Select-Object)
                    if ($AdlResultSplit.Count -ge 9) {
                        $DeviceName = Get-NormalizedDeviceName $AdlResultSplit[8] -Vendor $Vendor
                        $SubId = if ($AdlResultSplit.Count -ge 10 -and $AdlResultSplit[9] -match "&DEV_([0-9A-F]+?)&") {$Matches[1]} else {"noid"}
                        if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                        [PSCustomObject]@{
                            Index = $DeviceId
                            DeviceName = $DeviceName
                            InstanceId = $AdlResultSplit[9]
                            SubId = $SubId
                            CardId = -1
                        }
                        $DeviceId++
                    }
                }
            }

            if ($IsLinux -and $Vendor -eq 'AMD') {
                try {
                    $RocmInfo = [PSCustomObject]@{}
                    if (Get-Command "rocm-smi" -ErrorAction Ignore) {
                        $RocmFields = $false
                        Invoke-Exe "rocm-smi" -ArgumentList "--showhw" -ExpandLines -ExcludeEmptyLines | Where-Object {$_ -notmatch "==="} | Foreach-Object {
                            if (-not $RocmFields) {$RocmFields = $_ -split "\s\s+" | Foreach-Object {$_.Trim()};$GpuIx = $RocmFields.IndexOf("GPU");$BusIx = $RocmFields.IndexOf("BUS")} else {
                                $RocmVals = $_ -split "\s\s+" | Foreach-Object {$_.Trim()}
                                if ($RocmVals -and $RocmVals.Count -eq $RocmFields.Count -and $RocmVals[$BusIx] -match "([A-F0-9]+:[A-F0-9]+)\.") {
                                    $RocmInfo | Add-Member $($Matches[1] -replace "\.+$") $RocmVals[$GpuIx] -Force
                                }
                            }
                        }
                    }
                    $DeviceId = 0
                    $Cmd = if (Get-Command "amdmeminfo" -ErrorAction Ignore) {"amdmeminfo"} else {".\IncludesLinux\bin\amdmeminfo"}
                    Invoke-Exe $Cmd -ArgumentList "-o -q" -ExpandLines -Runas | Select-String "------", "Found Card:", "PCI:", "OpenCL ID", "Memory Model" | Foreach-Object {
                        Switch -Regex ($_) {
                            "------" {
                                $PCIdata = [PSCustomObject]@{
                                    Index      = $DeviceId
                                    DeviceName = ""
                                    SubId      = "noid"
                                    PCIBusId   = $null
                                    CardId     = -1
                                }
                                break
                            }
                            "Found Card:\s*[A-F0-9]{4}:([A-F0-9]{4}).+\((.+)\)" {$PCIdata.DeviceName = Get-NormalizedDeviceName $Matches[2] -Vendor $Vendor; $PCIdata.SubId = $Matches[1];break}
                            "Found Card:.+\((.+)\)" {$PCIdata.DeviceName = Get-NormalizedDeviceName $Matches[1] -Vendor $Vendor; break}
                            "OpenCL ID:\s*(\d+)" {$PCIdata.Index = [int]$Matches[1]; break}
                            "PCI:\s*([A-F0-9\:]+)" {$PCIdata.PCIBusId = $Matches[1] -replace "\.+$";if ($RocmInfo."$($PCIdata.PCIBusId)") {$PCIdata.CardId = [int]$RocmInfo."$($PCIdata.PCIBusId)"};break}
                            "Memory Model" {$PCIdata;$DeviceId++;break}
                        }
                    }
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "Call to amdmeminfo failed. Did you start as sudo or `"ocdaemon start`"?"
                }
            }

            if ($Vendor -eq "NVIDIA") {
                Invoke-NvidiaSmi "index","gpu_name","pci.device_id","pci.bus_id" | ForEach-Object {
                    $DeviceName = $_.gpu_name.Trim()
                    $SubId = if ($AdlResultSplit.Count -gt 1 -and $AdlResultSplit[1] -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                    if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                    [PSCustomObject]@{
                        Index      = $_.index
                        DeviceName = $DeviceName
                        SubId      = if ($_.pci_device_id -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                        PCIBusId   = if ($_.pci_bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                        CardId     = -1
                    }
                }
            }
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Info "Could not read GPU data for vendor $($Vendor). "
    }
}

function Update-DeviceInformation {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$DeviceName = @(),
        [Parameter(Mandatory = $false)]
        [Bool]$UseAfterburner = $true,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$DeviceConfig = @{}        
    )
    $abReload = $true

    $PowerAdjust = @{}
    $Script:GlobalCachedDevices | Foreach-Object {
        $Model = $_.Model
        $PowerAdjust[$Model] = 100
        if ($DeviceConfig -and $DeviceConfig.$Model -ne $null -and $DeviceConfig.$Model.PowerAdjust -ne $null -and $DeviceConfig.$Model.PowerAdjust -ne "") {$PowerAdjust[$Model] = $DeviceConfig.$Model.PowerAdjust}
    }

    $Script:GlobalCachedDevices | Where-Object {$_.Type -eq "GPU" -and $DeviceName -icontains $_.Name} | Group-Object Vendor | Foreach-Object {
        $Devices = $_.Group
        $Vendor = $_.Name

        try { #AMD
            if ($Vendor -eq 'AMD') {
                if ($IsWindows -and $UseAfterburner -and $Script:abMonitor -and $Script:abControl) {
                    if ($abReload) {
                        if ($Script:abMonitor) {$Script:abMonitor.ReloadAll()}
                        if ($Script:abControl) {$Script:abControl.ReloadAll()}
                        $abReload = $false
                    }
                    $DeviceId = 0
                    $Pattern = @{
                        AMD    = '*Radeon*'
                        NVIDIA = '*GeForce*'
                        Intel  = '*Intel*'
                    }
                    @($Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Vendor) | ForEach-Object {
                        $CardData = $Script:abMonitor.Entries | Where-Object GPU -eq $_.Index
                        $PowerLimitPercent = [int]$($Script:abControl.GpuEntries[$_.Index].PowerLimitCur)
                        $Utilization = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage$").Data
                        $AdapterId = $_.Index

                        if (-not (Test-Path Variable:Script:AmdCardsTDP)) {$Script:AmdCardsTDP = Get-Content ".\Data\amd-cards-tdp.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}

                        $Devices | Where-Object {$_.Vendor -eq $Vendor -and $_.Type_Vendor_Index -eq $DeviceId} | Foreach-Object {
                            $_ | Add-Member Data ([PSCustomObject]@{
                                    AdapterId         = [int]$AdapterId
                                    Utilization       = $Utilization
                                    UtilizationMem    = [int]$($mem = $CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage$"; if ($mem.MaxLimit) {$mem.Data / $mem.MaxLimit * 100})
                                    Clock             = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock$").Data
                                    ClockMem          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock$").Data
                                    FanSpeed          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed$").Data
                                    Temperature       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature$").Data
                                    PowerDraw         = $Script:AmdCardsTDP."$($_.Model_Name)" * ((100 + $PowerLimitPercent) / 100) * ($Utilization / 100) * ($PowerAdjust[$_.Model] / 100)
                                    PowerLimitPercent = $PowerLimitPercent
                                    #PCIBus            = [int]$($null = $_.GpuId -match "&BUS_(\d+)&"; $matches[1])
                                    Method            = "ab"
                                }) -Force

                            $DataMax = [PSCustomObject]@{
                                Clock       = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)
                                ClockMem    = [Math]::Max([int]$_.DataMax.ClockMem,$_.Data.ClockMem)
                                Temperature = [Math]::Max([int]$_.DataMax.Temperature,$_.Data.Temperature)
                                FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$_.Data.FanSpeed)
                                PowerDraw   = [Math]::Max([decimal]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                            }

                            $_ | Add-Member DataMax $DataMax -Force
                        }
                        $DeviceId++
                    }
                } else {

                    if ($IsWindows) {
                        Invoke-Exe ".\Includes\odvii.exe" -ArgumentList "s" -WorkingDirectory $Pwd | Tee-Object -Variable AdlResult | Out-Null

                        if ($AdlResult -match "Gpu" -and $AdlResult -notmatch "Failed") {
                            $AdlStats = $AdlResult | ConvertFrom-StringData

                            $Data = @{}
                            $AdlStats.GetEnumerator() | Where-Object {$_.Name -match "Gpu (\d+)"} | Foreach-Object {
                                $DeviceId = [int]$Matches[1]
                                if (-not $Data.ContainsKey($DeviceId)) {$Data[$DeviceId] = [PSCustomObject]@{}}
                                $Data[$DeviceId] | Add-Member ($_.Name -replace "Gpu\s+\d+\s*") ($_.Value) -Force
                            }

                            $Devices | Where-Object {$Data.ContainsKey($_.Type_Vendor_Index)} | Foreach-Object {
                                $DeviceId = $_.Type_Vendor_Index
                                $_ | Add-Member Data ([PSCustomObject]@{
                                        AdapterId         = ''
                                        FanSpeed          = [int]($Data[$DeviceId].Fan)
                                        Clock             = [int]($Data[$DeviceId].PSObject.Properties | Where-Object {$_.Name -match "Core Clock"} | Foreach-Object {[int]$_.Value} | Measure-Object -Maximum).Maximum
                                        ClockMem          = [int]($Data[$DeviceId].PSObject.Properties | Where-Object {$_.Name -match "Mem Clock"} | Foreach-Object {[int]$_.Value} | Measure-Object -Maximum).Maximum
                                        Temperature       = [int]($Data[$DeviceId].Temp)
                                        PowerDraw         = [int]($Data[$DeviceId].Watts)
                                        Method            = "odvii"
                                    }) -Force

                                $DataMax = [PSCustomObject]@{
                                    Clock       = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)
                                    ClockMem    = [Math]::Max([int]$_.DataMax.ClockMem,$_.Data.ClockMem)
                                    Temperature = [Math]::Max([int]$_.DataMax.Temperature,$_.Data.Temperature)
                                    FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$_.Data.FanSpeed)
                                    PowerDraw   = [Math]::Max([decimal]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                                }

                                $_ | Add-Member DataMax $DataMax -Force
                            }
                        } else {
                            $DeviceId = 0

                            $AdlResult = Invoke-Exe '.\Includes\OverdriveN.exe' -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed" -and $_ -ne "Failed to load ADL library"}

                            if (-not (Test-Path Variable:Script:AmdCardsTDP)) {$Script:AmdCardsTDP = Get-Content ".\Data\amd-cards-tdp.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}

                            if ($null -ne $AdlResult) {
                                $AdlResult | ForEach-Object {
                                    [System.Collections.ArrayList]$AdlResultSplit = @('noid',0,1,0,0,100,0,0,'')
                                    $i=0
                                    foreach($v in @($_ -split ',')) {
                                        if ($i -ge $AdlResultSplit.Count) {break}
                                        if ($i -eq 0) {
                                            $AdlResultSplit[0] = $v
                                        } elseif ($i -lt 8) {
                                            $v = $v -replace "[^\-\d\.]"
                                            if ($v -match "^-?(\d+|\.\d+|\d+\.\d+)$") {
                                                $ibak = $AdlResultSplit[$i]
                                                try {
                                                    if ($i -eq 5 -or $i -eq 7){$AdlResultSplit[$i]=[double]$v}else{$AdlResultSplit[$i]=[int]$v}
                                                } catch {
                                                    if ($Error.Count){$Error.RemoveAt(0)}
                                                    $AdlResultSplit[$i] = $ibak
                                                }
                                            }
                                        }
                                        $i++
                                    }
                                    if (-not $AdlResultSplit[2]) {$AdlResultSplit[1]=0;$AdlResultSplit[2]=1}

                                    $Devices | Where-Object Type_Vendor_Index -eq $DeviceId | Foreach-Object {
                                        $_ | Add-Member Data ([PSCustomObject]@{
                                                AdapterId         = $AdlResultSplit[0]
                                                FanSpeed          = [int]($AdlResultSplit[1] / $AdlResultSplit[2] * 100)
                                                Clock             = [int]($AdlResultSplit[3] / 100)
                                                ClockMem          = [int]($AdlResultSplit[4] / 100)
                                                Utilization       = [int]$AdlResultSplit[5]
                                                Temperature       = [int]$AdlResultSplit[6] / 1000
                                                PowerLimitPercent = 100 + [int]$AdlResultSplit[7]
                                                PowerDraw         = $Script:AmdCardsTDP."$($_.Model_Name)" * ((100 + $AdlResultSplit[7]) / 100) * ($AdlResultSplit[5] / 100) * ($PowerAdjust[$_.Model] / 100)
                                                Method            = "tdp"
                                            }) -Force

                                        $DataMax = [PSCustomObject]@{
                                            Clock       = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)
                                            ClockMem    = [Math]::Max([int]$_.DataMax.ClockMem,$_.Data.ClockMem)
                                            Temperature = [Math]::Max([int]$_.DataMax.Temperature,$_.Data.Temperature)
                                            FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$_.Data.FanSpeed)
                                            PowerDraw   = [Math]::Max([decimal]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                                        }

                                        $_ | Add-Member DataMax $DataMax -Force
                                    }
                                }
                                $DeviceId++
                            }
                        }
                    }
                    elseif ($IsLinux) {
                        if (Get-Command "rocm-smi" -ErrorAction Ignore) {
                            try {
                                $Rocm = Invoke-Exe -FilePath "rocm-smi" -ArgumentList "-f -t -P --json" | ConvertFrom-Json -ErrorAction Ignore
                            } catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                            }
                            if ($Rocm) {
                                $DeviceId = 0

                                $Rocm.Psobject.Properties | Sort-Object -Property {[int]($_.Name -replace "[^\d]")} | Foreach-Object {
                                    $Data = $_.Value
                                    $Card = [int]($_.Name -replace "[^\d]")
                                    $Devices | Where-Object {$_.CardId -eq $Card -or ($_.CardId -eq -1 -and $_.Type_Vendor_Index -eq $DeviceId)} | Foreach-Object {
                                        $_ | Add-Member Data ([PSCustomObject]@{
                                                Temperature       = [decimal]($Data.PSObject.Properties | Where-Object {$_.Name -match "Temperature"} | Select-Object -ExpandProperty Value)
                                                PowerDraw         = [decimal]($Data.PSObject.Properties | Where-Object {$_.Name -match "Power"} | Select-Object -ExpandProperty Value)
                                                FanSpeed          = [int]($Data.PSObject.Properties | Where-Object {$_.Name -match "Fan.+%"} | Select-Object -ExpandProperty Value)
                                                Method            = "rocm"
                                        }) -Force

                                        $DataMax = [PSCustomObject]@{
                                            Temperature = [Math]::Max([decimal]$_.DataMax.Temperature,$_.Data.Temperature)
                                            FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$_.Data.FanSpeed)
                                            PowerDraw   = [Math]::Max([decimal]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                                        }

                                        $_ | Add-Member DataMax $DataMax -Force
                                    }
                                    $DeviceId++
                                }
                                Remove-Variable "Rocm" -ErrorAction Ignore -For
                            }
                        }
                    }
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not read power data from AMD"
        }

        try { #NVIDIA        
            if ($Vendor -eq 'NVIDIA') {
                #NVIDIA
                $DeviceId = 0
                if (-not (Test-Path Variable:Script:NvidiaCardsTDP)) {$Script:NvidiaCardsTDP = Get-Content ".\Data\nvidia-cards-tdp.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}

                Invoke-NvidiaSmi "index","utilization.gpu","utilization.memory","temperature.gpu","power.draw","power.limit","fan.speed","pstate","clocks.current.graphics","clocks.current.memory","power.max_limit","power.default_limit" | ForEach-Object {
                    $Smi = $_
                    $Devices | Where-Object Type_Vendor_Index -eq $DeviceId | Foreach-Object {
                        $Data = [PSCustomObject]@{
                            Utilization       = if ($smi.utilization_gpu -ne $null) {$smi.utilization_gpu} else {100}
                            UtilizationMem    = $smi.utilization_memory
                            Temperature       = $smi.temperature_gpu
                            PowerDraw         = $smi.power_draw
                            PowerLimit        = $smi.power_limit
                            FanSpeed          = $smi.fan_speed
                            Pstate            = $smi.pstate
                            Clock             = $smi.clocks_current_graphics
                            ClockMem          = $smi.clocks_current_memory
                            PowerMaxLimit     = $smi.power_max_limit
                            PowerDefaultLimit = $smi.power_default_limit
                            Method            = "smi"
                        }
                        if ($Data.PowerDefaultLimit) {$Data | Add-Member PowerLimitPercent ([math]::Floor(($Data.PowerLimit * 100) / $Data.PowerDefaultLimit))}
                        if (-not $Data.PowerDraw -and $Script:NvidiaCardsTDP."$($_.Model_Name)") {$Data.PowerDraw = $Script:NvidiaCardsTDP."$($_.Model_Name)" * ([double]$Data.PowerLimitPercent / 100) * ([double]$Data.Utilization / 100)}
                        if ($Data.PowerDraw) {$Data.PowerDraw *= ($PowerAdjust[$_.Model] / 100)}
                        $_ | Add-Member Data $Data -Force

                        $DataMax = [PSCustomObject]@{
                            Clock       = [Math]::Max([int]$_.DataMax.Clock,$Data.Clock)
                            ClockMem    = [Math]::Max([int]$_.DataMax.ClockMem,$Data.ClockMem)
                            Temperature = [Math]::Max([int]$_.DataMax.Temperature,$Data.Temperature)
                            FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$Data.FanSpeed)
                            PowerDraw   = [Math]::Max([decimal]$_.DataMax.PowerDraw,$Data.PowerDraw)
                        }

                        $_ | Add-Member DataMax $DataMax -Force

                        $DeviceId++
                    }
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not read power data from NVIDIA"
        }
    }

    try { #CPU
        if (-not $DeviceName -or $DeviceName -like "CPU*") {
            if (-not (Test-Path Variable:Script:CpuTDP)) {$Script:CpuTDP = Get-Content ".\Data\cpu-tdp.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}
            if ($IsWindows) {
                $CPU_count = ($Script:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Measure-Object).Count
                if ($CPU_count -gt 0) {$CIM_CPU = Get-CimInstance -ClassName CIM_Processor}
                $Script:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                    $Device = $_
                    $CIM_CPU | Select-Object -Index $Device.Type_Index | ForEach-Object {
                        if ($UseAfterburner -and $Script:abMonitor -and $CPU_count -eq 1) {
                            if ($Script:abMonitor -and $abReload) {$Script:abMonitor.ReloadAll();$abReload=$false}
                            $CpuData = @{                            
                                Clock       = $($Script:abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )clock' | Measure-Object -Property Data -Maximum).Maximum
                                Utilization = $($Script:abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )usage'| Measure-Object -Property Data -Average).Average
                                PowerDraw   = $($Script:abMonitor.Entries | Where-Object SrcName -eq 'CPU power').Data
                                Temperature = $($Script:abMonitor.Entries | Where-Object SrcName -match "^(CPU\d* )temperature" | Measure-Object -Property Data -Maximum).Maximum
                                Method      = "ab"
                            }
                        } else {
                            $CpuData = @{Clock=0;Utilization=0;PowerDraw=0;Temperature=0;Method="tdp"}
                        }
                        if (-not $CpuData.Clock)       {$CpuData.Clock = $_.MaxClockSpeed}                
                        if (-not $CpuData.Utilization) {$CpuData.Utilization = $_.LoadPercentage}
                        if (-not $CpuData.Utilization) {$CpuData.Utilization = 100}
                        if (-not $CpuData.PowerDraw) {
                            $CpuName = $_.Name.Trim()
                            if (-not ($CPU_tdp = $Script:CpuTDP.PSObject.Properties | Where-Object {$CpuName -match $_.Name} | Select-Object -First 1 -ExpandProperty Value)) {$CPU_tdp = ($Script:CpuTDP.PSObject.Properties.Value | Measure-Object -Average).Average}
                            $CpuData.PowerDraw = $CPU_tdp * ($CpuData.Utilization / 100) * ($PowerAdjust[$Device.Model] / 100)
                        }                    

                        $Device | Add-Member Data ([PSCustomObject]@{
                            Cores       = [int]$_.NumberOfCores
                            Threads     = [int]$_.NumberOfLogicalProcessors
                            CacheL3     = [int]($_.L3CacheSize / 1024)
                            Clock       = [int]$CpuData.Clock
                            Utilization = [int]$CpuData.Utilization
                            PowerDraw   = [int]$CpuData.PowerDraw
                            Temperature = [int]$CpuData.Temperature
                            Method      = $CpuData.Method
                        }) -Force
                    }
                }
                if ($CIM_CPU) {Remove-Variable "CIM_CPU" -Force}
            } 
            elseif ($IsLinux) {
                $Script:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                    $Device = $_

                    [int]$Utilization = [math]::min((((Invoke-Exe "ps" -ArgumentList "-A -o pcpu" -ExpandLines) -match "\d" | Measure-Object -Sum).Sum / $Global:GlobalCPUInfo.Threads), 100)

                    $CpuName = $Global:GlobalCPUInfo.Name.Trim()
                    if (-not ($CPU_tdp = $Script:CpuTDP.PSObject.Properties | Where-Object {$CpuName -match $_.Name} | Select-Object -First 1 -ExpandProperty Value)) {$CPU_tdp = ($Script:CpuTDP.PSObject.Properties.Value | Measure-Object -Average).Average}

                    $Device | Add-Member Data ([PSCustomObject]@{
                        Cores       = [int]$Global:GlobalCPUInfo.Cores
                        Threads     = [int]$Global:GlobalCPUInfo.Threads
                        CacheL3     = [int]($Global:GlobalCPUInfo.L3CacheSize / 1024)
                        Clock       = [int]$Global:GlobalCPUInfo.MaxClockSpeed
                        Utilization = [int]$Utilization
                        PowerDraw   = [int]($CPU_tdp * $Utilization / 100)
                        Method      = "tdp"
                    }) -Force
                }
            }

            $Script:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                $ClockMax       = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)
                $PowerDrawMax   = [Math]::Max([int]$_.DataMax.PowerDraw,$_.Data.PowerDraw)

                $_ | Add-Member DataMax ([PSCustomObject]@{
                    Clock       = $ClockMax
                    PowerDraw   = $PowerDrawMax
                }) -Force
            }
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Could not read power data from CPU"
    }
}

function Get-CoinName {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,   
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$CoinName = ""
    )
    if ($CoinName -match "[,;]") {@($CoinName -split "\s*[,;]+\s*") | Foreach-Object {Get-CoinName $_}}
    else {
        ((Get-Culture).TextInfo.ToTitleCase($CoinName -replace "[^`$a-z0-9\s\-]+")).Trim()        
    }
}

function Get-Algorithm {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$Algorithm = ""
    )
    if ($Algorithm -eq '*') {$Algorithm}
    elseif ($Algorithm -match "[,;]") {@($Algorithm -split "\s*[,;]+\s*") | Foreach-Object {Get-Algorithm $_}}
    else {
        if (-not (Test-Path Variable:Global:GlobalAlgorithms) -or (Get-ChildItem "Data\algorithms.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalAlgorithmsTimeStamp) {Get-Algorithms -Silent}
        $Algorithm = (Get-Culture).TextInfo.ToTitleCase(($Algorithm -replace "[^a-z0-9]+", " ")) -replace " "
        if ($Global:GlobalAlgorithms.ContainsKey($Algorithm)) {$Global:GlobalAlgorithms[$Algorithm]} else {$Algorithm}
    }
}

function Get-Coin {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$CoinSymbol = ""
    )
    if ($CoinSymbol -eq '*') {$CoinSymbol}
    elseif ($CoinSymbol -match "[,;]") {@($CoinSymbol -split "\s*[,;]+\s*") | Foreach-Object {Get-Coin $_}}
    else {
        if (-not (Test-Path Variable:Global:GlobalCoinsDB) -or (Get-ChildItem "Data\coinsdb.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalCoinsDBTimeStamp) {Get-CoinsDB -Silent}
        $CoinSymbol = ($CoinSymbol -replace "[^A-Z0-9`$-]+").ToUpper()
        if ($Global:GlobalCoinsDB.ContainsKey($CoinSymbol)) {$Global:GlobalCoinsDB[$CoinSymbol]}
    }
}

function Get-MappedAlgorithm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Algorithm
    )
    if (-not $Session.Config.EnableAlgorithmMapping) {return $Algorithm}
    if (-not (Test-Path Variable:Global:GlobalAlgorithmMap) -or (Get-ChildItem "Data\algorithmmap.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalAlgorithmMapTimeStamp) {Get-AlgorithmMap -Silent}
    $Algorithm | Foreach-Object {if ($Global:GlobalAlgorithmMap.ContainsKey($_)) {$Global:GlobalAlgorithmMap[$_]} else {$_}}
}

function Get-AlgorithmMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalAlgorithmMap) -or (Get-ChildItem "Data\algorithmmap.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalAlgorithmMapTimeStamp) {
        [hashtable]$Global:GlobalAlgorithmMap = @{}
        (Get-Content "Data\algorithmmap.json" -Raw  -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalAlgorithmMap[$_.Name]=$_.Value}
        $Global:GlobalAlgorithmMapTimeStamp = (Get-ChildItem "Data\algorithmmap.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {
        $Global:GlobalAlgorithmMap
    }
}

function Get-EquihashCoinPers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Coin = "",
        [Parameter(Mandatory = $false)]
        [String]$Default = "auto"
    )
    if (-not (Test-Path Variable:Global:GlobalEquihashCoins)) {Get-EquihashCoins -Silent}        
    if ($Coin -and $Global:GlobalEquihashCoins.ContainsKey($Coin)) {$Global:GlobalEquihashCoins[$Coin]} else {$Default}
}

function Get-NimqHashrate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$GPU = "",
        [Parameter(Mandatory = $false)]
        [Int]$Default = 100
    )
    if (-not (Test-Path Variable:Global:GlobalNimqHashrates)) {Get-NimqHashrates -Silent}        
    if ($GPU -and $Global:GlobalNimqHashrates.ContainsKey($GPU)) {$Global:GlobalNimqHashrates[$GPU]} else {$Default}
}

function Get-Region {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )
    if (-not (Test-Path Variable:Global:GlobalRegions)) {Get-Regions -Silent}
    $Region = (Get-Culture).TextInfo.ToTitleCase(($Region -replace "-", " " -replace "_", " ")) -replace " "
    if ($Global:GlobalRegions.ContainsKey($Region)) {$Global:GlobalRegions[$Region]} else {foreach($r in @($Global:GlobalRegions.Keys)) {if ($Region -match "^$($r)") {$Global:GlobalRegions[$r];return}};$Region}
}

function Get-Region2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )
    if (-not (Test-Path Variable:Global:GlobalRegions2)) {Get-Regions2 -Silent}
    if ($Global:GlobalRegions2.ContainsKey($Region)) {$Global:GlobalRegions2[$Region]}
}

function Get-Algorithms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Values = $false
    )
    if (-not (Test-Path Variable:Global:GlobalAlgorithms) -or (Get-ChildItem "Data\algorithms.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalAlgorithmsTimeStamp) {
        [hashtable]$Global:GlobalAlgorithms = @{}
        (Get-Content "Data\algorithms.json" -Raw  -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalAlgorithms[$_.Name]=$_.Value}
        $Global:GlobalAlgorithmsTimeStamp = (Get-ChildItem "Data\algorithms.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {
        if ($Values) {$Global:GlobalAlgorithms.Values | Select-Object -Unique | Sort-Object}
        else {$Global:GlobalAlgorithms.Keys | Sort-Object}
    }
}

function Get-CoinsDB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Values = $false
    )
    if (-not (Test-Path Variable:Global:GlobalCoinsDB) -or (Get-ChildItem "Data\coinsdb.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalCoinsDBTimeStamp) {
        [hashtable]$Global:GlobalCoinsDB = @{}
        (Get-Content "Data\coinsdb.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalCoinsDB[$_.Name]=$_.Value}
        $Global:GlobalCoinsDBTimeStamp = (Get-ChildItem "Data\coinsdb.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {
        if ($Values) {$Global:GlobalCoinsDB.Values | Select-Object -Unique | Sort-Object}
        else {$Global:GlobalCoinsDB.Keys | Sort-Object}
    }
}

function Get-EquihashCoins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalEquihashCoins)) {
        [hashtable]$Global:GlobalEquihashCoins = @{}
        (Get-Content "Data\equihashcoins.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalEquihashCoins[$_.Name]=$_.Value}
    }
    if (-not $Silent) {$Global:GlobalEquihashCoins.Keys}
}

function Get-NimqHashrates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalNimqHashrates)) {
        [hashtable]$Global:GlobalNimqHashrates = @{}
        (Get-Content "Data\nimqhashrates.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalNimqHashrates[$_.Name]=$_.Value}
    }
    if (-not $Silent) {$Global:GlobalNimqHashrates.Keys}
}

function Get-PoolsInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name = "",
        [Parameter(Mandatory = $false)]
        [String[]]$Values = @(),
        [Parameter(Mandatory = $false)]
        [Switch]$AsObjects = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Clear = $false
    )
    
    if (-not (Test-Path Variables:Global:GlobalPoolsInfo)) {
        $Global:GlobalPoolsInfo = Get-Content "Data\poolsinfo.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
        $Global:GlobalPoolsInfo.PSObject.Properties | Foreach-Object {
            $_.Value | Add-Member Minable @(Compare-Object $_.Value.Currency $_.Value.CoinSymbol -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject) -Force
        }
    }
    if ($Name -and @("Algorithm","Currency","CoinSymbol","CoinName","Minable") -icontains $Name) {
        if ($Values.Count) {
            if ($AsObjects) {
                $Global:GlobalPoolsInfo.PSObject.Properties | Foreach-Object {[PSCustomObject]@{Pool=$_.Name;Currencies = @(Compare-Object $_.Value.$Name $Values -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject | Select-Object -Unique | Sort-Object)}} | Where-Object {($_.Currencies | Measure-Object).Count} | Sort-Object Name
            } else {
                $Global:GlobalPoolsInfo.PSObject.Properties | Where-Object {Compare-Object $_.Value.$Name $Values -IncludeEqual -ExcludeDifferent} | Select-Object -ExpandProperty Name | Sort-Object
            }
        } else {
            $Global:GlobalPoolsInfo.PSObject.Properties.Value.$Name | Select-Object -Unique | Sort-Object
        }
    } else {
        $Global:GlobalPoolsInfo.$Name
    }
    if ($Clear) {Remove-Variable "GlobalPoolsInfo" -Scope Global -Force}
}

function Get-Regions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Switch]$AsHash = $false
    )
    if (-not (Test-Path Variable:Global:GlobalRegions)) {
        [hashtable]$Global:GlobalRegions = @{}
        (Get-Content "Data\regions.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalRegions[$_.Name]=$_.Value}
    }
    if (-not $Silent) {
        if ($AsHash) {$Global:GlobalRegions}
        else {$Global:GlobalRegions.Keys}
    }
}

function Get-Regions2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalRegions2)) {
        [hashtable]$Global:GlobalRegions2 = @{}
        (Get-Content "Data\regions2.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalRegions2[$_.Name]=$_.Value}
    }
    if (-not $Silent) {$Global:GlobalRegions2.Keys}
}


function Get-WorldCurrencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalWorldCurrencies)) {
        $Global:GlobalWorldCurrencies = if (Test-Path ".\Data\worldcurrencies.json") {Get-Content ".\Data\worldcurrencies.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore} else {@("USD","INR","RUB","EUR","GBP")}
    }
    if (-not $Silent) {$Global:GlobalWorldCurrencies}
}

enum MinerStatus {
    Running
    Idle
    Failed
    RunningFailed
}

class Miner {
    $Name
    $Version
    $Path
    $Arguments
    $API
    $Port
    $Type
    [string[]]$Algorithm = @()
    [string[]]$BaseAlgorithm = @()
    $Currency
    $CoinName
    $CoinSymbol
    $DeviceName
    $DeviceModel
    [Bool]$Enabled = $false
    [string[]]$Pool = @()
    $Profit
    $Profit_Bias
    $Profit_Unbias
    $Profit_Cost
    $PowerDraw
    $Stratum
    $Speed
    $Speed_Live
    [double[]]$Variance = @()
    $StartCommand
    $StopCommand
    $Best
    $New
    $Benchmarked
    $LogFile    
    [Bool]$ShowMinerWindow = $false
    $MSIAprofile
    [hashtable]$OCprofile = @{}
    $DevFee
    $BaseName = $null
    $FaultTolerance = 0.1
    $ExtendInterval = 0
    $Penalty = 0
    $PoolPenalty
    $PostBlockMining = 0
    $Rounds = 0
    $MinSamples = 1
    $ZeroRounds = 0
    $CrashCount = 0
    $MaxBenchmarkRounds = 3
    $MaxRejectedShareRatio = 0.3
    $MiningPriority
    $MiningAffinity
    $ManualUri
    [Double[]]$RejectedShareRatio = @()
    [String]$EthPillEnable = "disable"
    [String]$EthPillEnableMTP = "disable"
    $DataInterval
    [String[]]$EnvVars = @()
    [Hashtable]$Priorities = @{"CPU"=-2;"GPU"=-1;"CPUAffinity"=0}
    [Bool]$Stopped = $false
    [Bool]$Donator = $false
    [Bool]$IsFocusWalletMiner = $false
    [Bool]$IsExclusiveMiner = $false
    [Bool]$IsLocked = $false
    [Bool]$IsRunningFirstRounds = $false
    [Bool]$NoCPUMining = $false
    [Bool]$NeedsBenchmark = $false
    [Int]$MultiProcess = 0
    [DateTime]$ActiveLast = [DateTime]::MinValue
    hidden [System.Management.Automation.Job]$Process = $null
    [Int[]]$ProcessId = @()
    [String]$ScreenName = ""
    hidden [TimeSpan]$Active = [TimeSpan]::Zero
    hidden [Int]$Activated = 0
    hidden [MinerStatus]$Status = [MinerStatus]::Idle
    hidden [Array]$Data = @()
    hidden [Bool]$HasOwnMinerWindow = $false    
    hidden [Array]$OCprofileBackup = @()
    hidden [PSCustomObject]$EthPill = $null
    hidden [DateTime]$IntervalBegin = 0
    hidden [DateTime]$LastSetOCTime = 0

    [String[]]GetProcessNames() {
        return @(([IO.FileInfo]($this.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName)
    }

    [String]GetArguments() {
        return $this.Arguments
    }

    [String]GetMinerDeviceName() {
        return "$($this.BaseName)-$(($this.DeviceName | Sort-Object) -join '-')"
    }

    [Bool]IsWrapper() {
        return $this.API -match "Wrapper"
    }

    hidden StartMining() {
        $this.StopMining();

        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++
        $this.Rounds = 0
        $this.IntervalBegin = 0

        if (-not $this.Process) {
            if ($this.StartCommand) {try {Invoke-Expression $this.StartCommand} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "StartCommand failed for miner $($this.Name)"}}
            $ArgumentList = $this.GetArguments()
            
            $Prescription = if ($this.EthPillEnable    -ne "disable" -and (Compare-Object $this.BaseAlgorithm @("Ethash") -IncludeEqual -ExcludeDifferent | Measure-Object).Count) {$this.EthPillEnable}
                        elseif ($this.EthPillEnableMTP -ne "disable" -and (Compare-Object $this.BaseAlgorithm @("MTP")    -IncludeEqual -ExcludeDifferent | Measure-Object).Count) {$this.EthPillEnableMTP}

            if ($Prescription -and -not ($this.Name -match "^ClaymoreDual" -and $ArgumentList -match "-strap")) {
                $Prescription_Device = @(Get-Device $this.DeviceName) | Where-Object Model -in @("GTX1080","GTX1080Ti","TITANXP")
                $Prescription = switch ($Prescription) {
                    "RevA" {$Prescription = "revA"}
                    "RevB" {$Prescription = "revB"}
                }
                if ($Prescription -ne "" -and $Prescription_Device) {
                    Write-Log "Starting OhGodAnETHlargementPill $($Prescription) on $($Prescription_Device.Name -join ',')"
                    if ($Global:IsLinux) {
                        $Command = ".\IncludesLinux\bin\OhGodAnETHlargementPill-r2"
                    } else {
                        $Command = ".\Includes\OhGodAnETHlargementPill-r2.exe"
                    }
                    $Command = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Command)
                    #$this.EthPill = [int](Start-Process -FilePath $Command -PassThru -Verb RunAs -ArgumentList "--$($Prescription) $($Prescription_Device.Type_Vendor_Index -join ',')").Id
                    $this.EthPill = Start-SubProcess -FilePath $Command -ArgumentList "--$($Prescription) $($Prescription_Device.Type_Vendor_Index -join ',')" -WorkingDirectory (Split-Path $Command) -ShowMinerWindow $true -IsWrapper $false -ScreenName "ethpill_$($Prescription)_$($Prescription_Device.Type_Vendor_Index -join '_')"
                    Start-Sleep -Milliseconds 250 #wait 1/4 second
                }
            }
            $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -CPUAffinity $this.Priorities.CPUAffinity -ShowMinerWindow $this.ShowMinerWindow -IsWrapper $this.IsWrapper() -EnvVars $this.EnvVars -MultiProcess $this.MultiProcess -ScreenName "$($this.DeviceName -join '_')"
            $this.Process    = $Job.Process
            $this.ProcessId  = $Job.ProcessId
            $this.ScreenName = $Job.ScreenName
            $this.HasOwnMinerWindow = $this.ShowMinerWindow

            if ($this.Process | Get-Job -ErrorAction Ignore) {
                $this.Status = [MinerStatus]::Running
            }
        }
    }

    hidden StopMining() {
        $this.Status = [MinerStatus]::Failed

        $this.ResetMinerData()

        if ($this.Process) {
            Stop-SubProcess -Job $this -Title "Miner $($this.Name)"

            if (-not ($this.Process | Get-Job -ErrorAction Ignore)) {
                $this.Active = $this.GetActiveTime();
                $this.Process = $null
                $this.Status = [MinerStatus]::Idle
            }
            if ($this.EthPill) {
                Write-Log "Stopping OhGodAnETHlargementPill"
                Stop-SubProcess $this.EthPill -Title "OhGodAnETHlargementPill"
                $this.EthPill = $null
            }
        }
        if ($this.StopCommand) {try {Invoke-Expression $this.StopCommand} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "StopCommand failed for miner $($this.Name)"}}
        $this.ProcessId = [int[]]@()
    }

    hidden StartMiningPreProcess() {
        $this.Stratum = @()
        $this.Algorithm | Foreach-Object {
            $this.Stratum += [PSCustomObject]@{Accepted=0;Rejected=0}
            $this.RejectedShareRatio += 0.0
        }
        $this.ActiveLast = Get-Date
    }

    hidden StartMiningPostProcess() { }

    hidden StopMiningPreProcess() { }

    hidden StopMiningPostProcess() {
        $this.ResetOCprofile(500) #reset all overclocking
        $this.New = $false
    }

    StopMiningPostCleanup() {
        $this.Stopped = $false
    }

    EndOfRoundCleanup() {
        if ($this.API -notmatch "Wrapper" -and $this.Process.HasMoreData) {$this.Process | Receive-Job > $null}
        if (($this.Speed_Live | Measure-Object -Sum).Sum) {$this.ZeroRounds = 0} else {$this.ZeroRounds++}
        $this.Rounds++
    }

    [DateTime]GetActiveStart() {
        $MiningProcess = if ($this.HasOwnMinerWindow -and $this.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime}
        $Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Process.PSBeginTime}

        if ($Begin) {
            return $Begin
        }
        else {
            return [DateTime]::MinValue
        }
    }

    [DateTime]GetActiveLast() {
        $MiningProcess = if ($this.HasOwnMinerWindow -and $this.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime,ExitTime}

        if (-not $MiningProcess -and -not $this.Process) {
            return $this.ActiveLast
        }

        $Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Process.PSBeginTime}
        $End   = if ($MiningProcess) {$MiningProcess.ExitTime} else {$this.Process.PSEndTime}

        if ($Begin -and $End) {
            return $End
        }
        elseif ($Begin) {
            return Get-Date
        }
        else {
            return [DateTime]::MinValue
        }
    }

    [TimeSpan]GetActiveTime() {
        $MiningProcess = if ($this.HasOwnMinerWindow -and $this.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime,ExitTime}
        $Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Process.PSBeginTime}
        $End   = if ($MiningProcess) {$MiningProcess.ExitTime} else {$this.Process.PSEndTime}
        
        if ($Begin -and $End) {
            return $this.Active + ($End - $Begin)
        }
        elseif ($Begin) {
            return $this.Active + ((Get-Date) - $Begin)
        }
        else {
            return $this.Active
        }
    }

    [Int]GetActivateCount() {
        return $this.Activated
    }

    [TimeSpan]GetRunningTime() {
        return $this.GetRunningTime($false)
    }

    [TimeSpan]GetRunningTime([Bool]$MeasureInterval = $false) {
        $MiningProcess = if ($this.HasOwnMinerWindow -and $this.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime,ExitTime}
        $Begin = if ($MeasureInterval) {$this.IntervalBegin}
        if (-not $MeasureInterval -or $Begin -eq 0) {$Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Process.PSBeginTime}}
        $End   = if ($MiningProcess) {$MiningProcess.ExitTime} else {$this.Process.PSEndTime}
        
        if ($Begin -and $End) {
            if ($MeasureInterval) {$this.IntervalBegin = $End}
            return ($End - $Begin)
        }
        elseif ($Begin) {
            if ($MeasureInterval) {$this.IntervalBegin = Get-Date}
            return ((Get-Date) - $Begin)
        }
        else {
            return [Timespan]0
        }
    }

    [MinerStatus]GetStatus() {
        $MiningProcess = $this.ProcessId | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore | Select-Object Id,HasExited}

        if ((-not $MiningProcess -and $this.Process.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq $(if ($Global:IsLinux) {1} else {$this.MultiProcess+1}))) {
            return [MinerStatus]::Running
        }
        elseif ($this.Status -eq [MinerStatus]::Running) {
            return [MinerStatus]::RunningFailed
        }
        else {
            return $this.Status
        }
    }

    [Int]GetProcessId() {
        return $this.ProcessId | Select-Object -First 1
    }

    [Int[]]GetProcessIds() {
        return $this.ProcessId
    }

    SetPriorities([int]$cpu=-2,[int]$gpu=-1,[string]$affinity="") {
        if ($cpu -lt -2) {$cpu=-2} elseif ($cpu -gt 3) {$cpu=3}
        if ($gpu -lt -2) {$gpu=-2} elseif ($gpu -gt 3) {$gpu=3}
        $this.Priorities.CPU = $cpu
        $this.Priorities.GPU = $gpu
        $this.Priorities.CPUAffinity = ConvertFrom-CPUAffinity $affinity -ToInt
    }

    SetStatusRaw([MinerStatus]$Status) {
        $this.Status = [MinerStatus]$Status
    }

    SetStatus([MinerStatus]$Status) {
        if ($Status -eq $this.GetStatus()) {return}

        switch ($Status) {
            Running {
                $this.StartMiningPreProcess()
                $this.StartMining()
                $this.StartMiningPostProcess()
            }
            Idle {
                $this.StopMiningPreProcess()
                $this.StopMining()
                $this.StopMiningPostProcess()
            }
            Default {
                $this.StopMiningPreProcess()
                $this.StopMining()
                $this.StopMiningPostProcess()
                $this.Status = [MinerStatus]$Status
            }
        }
    }

    UpdateShares([Int]$Index,[Double]$Accepted,[Double]$Rejected) {
        $this.Stratum[$Index].Accepted = $Accepted
        $this.Stratum[$Index].Rejected = $Rejected
        if ($Accepted + $Rejected) {
            $this.RejectedShareRatio[$Index] = [Math]::Round($Rejected / ($Accepted + $Rejected),4)
        }
    }

    [Int64]GetShareCount([Int]$Index) {
        return [Int64]($this.Stratum[$Index].Accepted + $this.Stratum[$Index].Rejected)
    }

    [Double]GetRejectedShareRatio([Int]$Index,[Int]$minShares) {
        return [Double]$(if ($this.GetShareCount($Index) -ge $minShares) {$this.Stratum[$Index].Rejected / $this.GetShareCount($Index)})
    }

    [Double]GetMaxRejectedShareRatio([Int]$minShares) {
        $Index = 0
        return ($this.Algorithm | Foreach-Object {$this.GetRejectedShareRatio($Index,$minShares);$Index++} | Measure-Object -Maximum).Maximum
    }

    [Double]GetMaxRejectedShareRatio() {
        return $this.GetMaxRejectedShareRatio(10)
    }

    [Bool]CheckShareRatio() {
        return $this.MaxRejectedShareRatio -le 0 -or $this.GetMaxRejectedShareRatio() -le $this.MaxRejectedShareRatio
    }

    [Void]UpdateMinerData () {

        if ($this.Process.HasMoreData) {
            $Date = (Get-Date).ToUniversalTime()

            $this.Process | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple) {
                    $HashRates = @()
                    $Devices = @()

                    if ($Line_Simple -match "/s") {
                        $Words = $Line_Simple -split "\s+"

                        $Words -match "/s$" | ForEach-Object {
                            $Index = $Words.IndexOf($_)
                            if (($Words | Select-Object -Index $Index) -match "^((?:\d*[\.,])?\d+)(.*)$") {
                                $HashRate = ($Matches | Select-Object -Index 1) -replace ',','.' -as [Decimal]
                                $HashRate_Unit = ($Matches | Select-Object -Index 2)
                            }
                            else {
                                $HashRate = ($Words | Select-Object -Index ($Index - 1)) -replace ',','.' -as [Decimal]
                                $HashRate_Unit = ($Words | Select-Object -Index $Index)
                            }

                            switch -wildcard ($HashRate_Unit) {
                                "kh/s*" {$HashRate *= 1E+3}
                                "mh/s*" {$HashRate *= 1E+6}
                                "gh/s*" {$HashRate *= 1E+9}
                                "th/s*" {$HashRate *= 1E+12}
                                "ph/s*" {$HashRate *= 1E+15}
                            }

                            $HashRates += $HashRate
                        }
                    }

                    if (($HashRates | Measure-Object -Sum).Sum -gt 0) {
                        if ($Line_Simple -match "\b(gpu|cpu|device)([^s]|\b)") {
                            $Words = $Line_Simple -replace "[#:]" -split "[\s/]+"

                            for($i=0;$i -lt $Words.Count;$i++) {
                                if ($Words[$i] -match "^(gpu|cpu|device)([^s]|$)") {                                   
                                    if (($Words | Select-Object -Index $i) -match "^(.*)((?:\d*[\.,])?\d+)$") {
                                        $Device = ($Matches | Select-Object -Index 2) -as [Int]
                                        $Device_Type = ($Matches | Select-Object -Index 1)
                                    }
                                    else {
                                        $Device = ($Words | Select-Object -Index ($i + 1)) -as [Int]
                                        $Device_Type = ($Words | Select-Object -Index $i)
                                    }

                                    $Devices += "{0}#{1:d2}" -f $Device_Type, $Device
                                }
                            }
                        }

                        $this.AddMinerData([PSCustomObject]@{
                            Date = $Date
                            Raw = $Line_Simple
                            HashRate = [PSCustomObject]@{[String]$this.Algorithm = $HashRates} 
                            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName                           
                            Device = $Devices
                        })
                    }
                }
            }

            $this.CleanupMinerData()
        }
    }

    AddMinerData($data) {
        $this.Data += $data | Add-Member -NotePropertyMembers @{
            Date = (Get-Date).ToUniversalTime()
            PowerDraw = $(Get-DevicePowerDraw -DeviceName $this.DeviceName)
            Round = $this.Rounds
        } -Force -PassThru
        $this.ActiveLast = Get-Date
    }

    [Int]GetMinerDataCount() {
        return $this.Data.Count
    }

    CleanupMinerData() {
        if ($this.Data.Count -gt $this.MinSamples) {
            $DataMinTime = (Get-Date).ToUniversalTime().AddSeconds( - $this.DataInterval*[Math]::max($this.ExtendInterval,1)*2)
            $i=0; $this.Data = @($this.Data | Foreach-Object {if ($_.Date -ge $DataMinTime -or ($this.Data.Count - $i) -le $this.MinSamples) {$_};$i++} | Select-Object)
        }
    }

    ResetMinerData() {
        $this.Data = @()
    }

    [Double]GetDifficulty([String]$Algorithm = [String]$this.Algorithm) {
        $Intervals  = [Math]::Max($this.ExtendInterval,1)
        $Timeframe  = (Get-Date).ToUniversalTime().AddSeconds( - $this.DataInterval * $Intervals)
        return ($this.Data | Where-Object {$_.Difficulty -and ($_.Difficulty.$Algorithm -or $_.Difficulty."$($Algorithm -replace '\-.*$')")} | Where-Object {$_.Date -ge $Timeframe} | Foreach-Object {$_.Difficulty."$($Algorithm -replace '\-.*$')"} | Measure-Object -Average).Average
    }

    [Double]GetCurrentDifficulty([String]$Algorithm = [String]$this.Algorithm) {
        return $this.Data | Where-Object {$_.Difficulty -and ($_.Difficulty.$Algorithm -or $_.Difficulty."$($Algorithm -replace '\-.*$')")} | Select-Object -Last 1 | Foreach-Object {$_.Difficulty."$($Algorithm -replace '\-.*$')"}
    }

    [Double]GetHashRate([String]$Algorithm = [String]$this.Algorithm,[Bool]$Safe = $true) {
        $HashRates_Devices = @($this.Data | Where-Object Device | Select-Object -ExpandProperty Device -Unique)
        if (-not $HashRates_Devices) {$HashRates_Devices = @("Device")}

        $Intervals = [Math]::Max($this.ExtendInterval,1)
        $Timeframe = (Get-Date).ToUniversalTime().AddSeconds( - $this.DataInterval * $Intervals)
        $HashData  = $this.Data | Where-Object {$_.HashRate -and ($_.HashRate.$Algorithm -or $_.HashRate."$($Algorithm -replace '\-.*$')")} | Where-Object {$_.Date -ge $Timeframe}
        $MaxVariance = if ($this.FaultTolerance) {$this.FaultTolerance} else {0.075}
        $MinHashRate = 1-[Math]::Min($MaxVariance/2,0.1)

        $HashRates_Count = $HashRates_Average = $HashRates_Variance = 0

        $Steps = if ($this.Rounds -ge 2*$Intervals) {1} else {2}
        for ($Step = 0; $HashData -and ($Step -lt $Steps); $Step++) {
            $HashRates_Counts = @{}
            $HashRates_Averages = @{}
            $HashRates_Variances = @{}

            $HashData | ForEach-Object {
                $Data_HashRates = $_.HashRate.$Algorithm
                if (-not $Data_HashRates -and $Algorithm -match "-") {$Data_HashRates = $_.HashRate."$($Algorithm -replace '\-.*$')"}

                $Data_Devices = $_.Device
                if (-not $Data_Devices) {$Data_Devices = $HashRates_Devices}

                $HashRate = $Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                if ($HashRates_Variances."$($Data_Devices -join '-')" -or ($HashRate -gt $HashRates_Average * $MinHashRate)) {
                    $Data_Devices | ForEach-Object {$HashRates_Counts.$_++}
                    $Data_Devices | ForEach-Object {$HashRates_Averages.$_ += @($HashRate / $Data_Devices.Count)}
                    $HashRates_Variances."$($Data_Devices -join '-')" += @($HashRate)
                }
            }

            $HashRates_Count    = $HashRates_Counts.Values | ForEach-Object {$_} | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
            $HashRates_Average  = ($HashRates_Averages.Values | ForEach-Object {$_} | Measure-Object -Average | Select-Object -ExpandProperty Average) * $HashRates_Averages.Keys.Count
            $HashRates_Variance = if ($HashRates_Average -and $HashRates_Count -gt 2) {($HashRates_Variances.Keys | ForEach-Object {$_} | ForEach-Object {Get-Sigma $HashRates_Variances.$_ | Measure-Object -Maximum} | Select-Object -ExpandProperty Maximum) / $HashRates_Average} else {1}
            Write-Log "GetHashrate $Algorithm #$($Step) smpl:$HashRates_Count, avg:$([Math]::Round($HashRates_Average,2)), var:$([Math]::Round($HashRates_Variance,3)*100)"
        }

        $this.Variance[$this.Algorithm.IndexOf($Algorithm)] = $HashRates_Variance
        
        if ($Safe -and $this.IsBenchmarking() -and ($this.Benchmarked -lt $Intervals -or $HashRates_Count -lt $this.MinSamples -or $HashRates_Variance -gt $MaxVariance)) {
            return 0
        }
        else {
            return $HashRates_Average
        }
    }

    [Bool]IsBenchmarking() {
        return $this.New -and $this.Benchmarked -lt ($this.MaxBenchmarkRounds + [Math]::Max($this.ExtendInterval,1) - 1)
    }

    [Int64]GetPowerDraw() {
        $Seconds = $this.DataInterval * [Math]::Max($this.ExtendInterval,1)
        return ($this.Data | Where-Object PowerDraw | Where-Object Date -GE (Get-Date).ToUniversalTime().AddSeconds( - $Seconds) | Select-Object -ExpandProperty PowerDraw | Measure-Object -Average).Average
    }

    [bool]HasDevFees() {
        return $this.DevFee -and ($this.Algorithm.PSObject.Properties.Value | Measure-Object -Sum).Sum
    }

    [array]GetDevFees() {
        return @($this.HashRates.PSObject.Properties.Name | Foreach-Object {$this.DevFee.$_})
    }

    [bool]HasOCprofile() {
        foreach ($model in @($this.DeviceModel -split '-' | Select-Object)) {if ($this.OCProfile.$model) {return $true}}
        return $false
    }

    ResetOCprofile([int]$Sleep=500) {
        if ($this.OCprofileBackup.Count -eq 0 -or -not $this.HasOCprofile()) {return}

        try {
            $Script:abMonitor.ReloadAll()
            $Script:abControl.ReloadAll()
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Failed to communicate with MSI Afterburner"
            $this.OCprofileBackup = @()
            return
        }
        if ($Sleep -gt 0) {Start-Sleep -Milliseconds $Sleep}
        foreach($Profile in $this.OCprofileBackup) {foreach($Name in $Profile.Keys) {if ($Name -ne "Index") {$Script:abControl.GpuEntries[$Profile.Index].$Name = $Profile.$Name}}}
        $Script:abControl.CommitChanges()
        $this.OCprofileBackup = @()
        Write-Log "OC reset for $($this.BaseName)"
        if ($Sleep -gt 0) {Start-Sleep -Milliseconds $Sleep}
    }

    [DateTime]GetLastSetOCTime() {
        return $this.LastSetOCTime
    }

    SetOCprofile($Config,[int]$Sleep=500) {

        $this.LastSetOCTime = (Get-Date).ToUniversalTime()

        $this.OCprofileBackup = @()

        if (-not $this.HasOCprofile()) {return}

        [System.Collections.ArrayList]$applied = @()
        [System.Collections.ArrayList]$NvCmd = @()
        [System.Collections.ArrayList]$AmdCmd = @()

        $Vendor = $Script:GlobalCachedDevices | Where-Object {$this.OCprofile.ContainsKey($_.Model)} | Select-Object -ExpandProperty Vendor -Unique

        if ($Global:IsWindows) {
            if ($Vendor -ne "NVIDIA") {
                try {
                    $Script:abMonitor.ReloadAll()
                    $Script:abControl.ReloadAll()
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "Failed to communicate with MSI Afterburner"
                    return
                }
            }
        }

        $Pattern = @{
            AMD    = "*Radeon*"
            NVIDIA = "*GeForce*"
            Intel  = "*Intel*"
        }

        $Profiles = [PSCustomObject]@{}
        foreach ($DeviceModel in @($this.OCprofile.Keys)) {
            $x = Switch -Regex ($DeviceModel) {
                "1050" {2}
                "P106-?100" {2}
                "P106-?090" {1}
                "P104-?100" {1}
                "P102-?100" {1}
                "1660" {4}
                default {3}
            }

            $DeviceIds = @()
            $CardIds = @()
            $Script:GlobalCachedDevices | Where-Object Model -eq $DeviceModel | Foreach-Object {
                $VendorIndex = $_.Type_Vendor_Index
                $CardId = $_.CardId
                $Id = if ($Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($_.Index)" -ne $null) {$_.Index} elseif ($Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($_.Name)" -ne $null) {$_.Name} elseif ($Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($_.OpenCL.PCIBusId)" -ne $null) {$_.OpenCL.PCIBusId}
                if ($Id) {
                    $Profiles | Add-Member "$($DeviceModel)[$($Id)]" ([PSCustomObject]@{Index = @($VendorIndex); CardId = @($CardId); Profile = $Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($Id)"; x = $x}) -Force
                } else {
                    $DeviceIds += $VendorIndex
                    $CardIds += $CardId
                }
            }
            if ($DeviceIds.Count -gt 0) {
                $Profile = if ($Config.OCprofiles."$($this.OCprofile.$DeviceModel)-$($DeviceModel)" -ne $null) {$Config.OCprofiles."$($this.OCprofile.$DeviceModel)-$($DeviceModel)"} elseif ($Config.OCprofiles."$($this.OCprofile.$DeviceModel)" -ne $null) {$Config.OCprofiles."$($this.OCprofile.$DeviceModel)"} else {[PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*";LockVoltagePoint = "*"}}
                if ($Profile) {
                    $Profiles | Add-Member $DeviceModel ([PSCustomObject]@{Index = $DeviceIds; CardId = $CardIds; Profile = $Profile; x = $x}) -Force
                }
            }
        }

        foreach ($DeviceModel in @($Profiles.PSObject.Properties.Name | Select-Object)) {            
            $Profile   = $Profiles.$DeviceModel.Profile

            $Profile.CoreClockBoost   = $Profile.CoreClockBoost -replace '[^0-9\-]+'
            $Profile.MemoryClockBoost = $Profile.MemoryClockBoost -replace '[^0-9\-]+'
            $Profile.LockVoltagePoint = $Profile.LockVoltagePoint -replace '[^0-9]+'
            if (-not $Config.EnableOCVoltage) {$Profile.LockVoltagePoint = ''}

            $applied_any = $false

            if ($Vendor -eq "NVIDIA") {

                foreach($DeviceId in $Profiles.$DeviceModel.Index) {
                    if ($Profile.PowerLimit -gt 0) {$val=[math]::max([math]::min($Profile.PowerLimit,200),20);if ($Global:IsLinux) {Set-NvidiaPowerLimit $DeviceId $val} else {$NvCmd.Add("-setPowerTarget:$($DeviceId),$($val)") >$null};$applied_any=$true}
                    if (-not $Global:IsLinux) {
                        if ($Profile.ThermalLimit -gt 0) {$val=[math]::max([math]::min($Profile.ThermalLimit,95),50);$NvCmd.Add("-setTempTarget:$($DeviceId),0,$($val)") >$null;$applied_any=$true}
                        if ($Profile.LockVoltagePoint-match '^\-*[0-9]+$') {$val=[int]([Convert]::ToInt32($Profile.LockVoltagePoint)/12500)*12500;$NvCmd.Add("-lockVoltagePoint:$($DeviceId),$($val)") >$null;$applied_any=$true}
                    } else {
                        $NvCmd.Add("-a '[gpu:$($DeviceId)]/GPUPowerMizerMode=1'")
                    }
                    if ($Profile.CoreClockBoost -match '^\-*[0-9]+$') {$val=[Convert]::ToInt32($Profile.CoreClockBoost);$NvCmd.Add("$(if ($Global:IsLinux) {"-a '[gpu:$($DeviceId)]/GPUGraphicsClockOffset[$($Profiles.$DeviceModel.x)]=$($val)'"} else {"-setBaseClockOffset:$($DeviceId),0,$($val)"})") >$null;$applied_any=$true}
                    if ($Profile.MemoryClockBoost -match '^\-*[0-9]+$') {$val = [Convert]::ToInt32($Profile.MemoryClockBoost);$NvCmd.Add("$(if ($Global:IsLinux) {"-a '[gpu:$($DeviceId)]/GPUMemoryTransferRateOffset[$($Profiles.$DeviceModel.x)]=$($val)'"} else {"-setMemoryClockOffset:$($DeviceId),0,$($val)"})") >$null;$applied_any=$true}
                }

            } elseif ($Vendor -eq "AMD" -and $Global:IsLinux) {

                foreach($CardId in $Profiles.$DeviceModel.CardId) {
                    #if ($Profile.PowerLimit -gt 0) {$val=[math]::max([math]::min($Profile.PowerLimit,200),20);if ($Global:IsLinux) {Set-NvidiaPowerLimit $DeviceId $val} else {$NvCmd.Add("-setPowerTarget:$($DeviceId),$($val)") >$null};$applied_any=$true}
                }
            
            } elseif ($Pattern.$Vendor -ne $null) {
                $DeviceId = 0
                $Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Vendor | Select-Object -ExpandProperty Index | Foreach-Object {
                    if ($DeviceId -in $Profiles.$DeviceModel.Index) {
                        $GpuEntry = $Script:abControl.GpuEntries[$_]
                        $ProfileBackup = [hashtable]@{}
                        try {if (-not ($GpuEntry.PowerLimitMin -eq 0 -and $GpuEntry.PowerLimitMax -eq 0) -and $Profile.PowerLimit -gt 0) {$ProfileBackup.PowerLimitCur = $GpuEntry.PowerLimitCur;$Script:abControl.GpuEntries[$_].PowerLimitCur = [math]::max([math]::min($Profile.PowerLimit,$GpuEntry.PowerLimitMax),$GpuEntry.PowerLimitMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                        try {if (-not ($GpuEntry.ThermalLimitMin -eq 0 -and $GpuEntry.ThermalLimitMax -eq 0) -and $Profile.ThermalLimit -gt 0) {$ProfileBackup.ThermalLimitCur = $GpuEntry.ThermalLimitCur;$Script:abControl.GpuEntries[$_].ThermalLimitCur = [math]::max([math]::min($Profile.ThermalLimit,$GpuEntry.ThermalLimitMax),$GpuEntry.ThermalLimitMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                        try {if (-not ($GpuEntry.CoreClockBoostMin -eq 0 -and $GpuEntry.CoreClockBoostMax -eq 0) -and $Profile.CoreClockBoost -match '^\-*[0-9]+$') {$ProfileBackup.CoreClockBoostCur = $GpuEntry.CoreClockBoostCur;$Script:abControl.GpuEntries[$_].CoreClockBoostCur = [math]::max([math]::min([convert]::ToInt32($Profile.CoreClockBoost) * 1000,$GpuEntry.CoreClockBoostMax),$GpuEntry.CoreClockBoostMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                        try {if (-not ($GpuEntry.MemoryClockBoostMin -eq 0 -and $GpuEntry.MemoryClockBoostMax -eq 0) -and $Profile.MemoryClockBoost -match '^\-*[0-9]+$') {$ProfileBackup.MemoryClockBoostCur = $GpuEntry.MemoryClockBoostCur;$Script:abControl.GpuEntries[$_].MemoryClockBoostCur = [math]::max([math]::min([convert]::ToInt32($Profile.MemoryClockBoost) * 1000,$GpuEntry.MemoryClockBoostMax),$GpuEntry.MemoryClockBoostMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                        if ($Profile.LockVoltagePoint -match '^\-*[0-9]+$') {Write-Log -Level Warn "$DeviceModel does not support LockVoltagePoint overclocking"}
                        if ($ProfileBackup.Count) {$ProfileBackup.Index = $_;$this.OCprofileBackup += $ProfileBackup;$applied_any=$true}
                    }
                    $DeviceId++
                }                 
            }
            if ($applied_any) {$applied.Add("OC set for $($this.BaseName)-$($DeviceModel)-$($this.BaseAlgorithm -join '-'): PL=$(if ($Profile.PowerLimit) {"$($Profile.PowerLimit)%"} else {"-"}), TL=$(if ($Profile.ThermalLimit) {"$($Profile.ThermalLimit)°C"} else {"-"}), MEM=$(if ($Profile.MemoryClockBoost -ne '') {"$($Profile.MemoryClockBoost)"} else {"-"}), CORE=$(if ($Profile.CoreClockBoost -ne '') {"$($Profile.CoreClockBoost)"} else {"-"}), LVP=$(if ($Profile.LockVoltagePoint -ne '') {"$($Profile.LockVoltagePoint)µV"} else {"-"})") > $null}
        }

        if ($applied.Count) {
            if ($Sleep -gt 0) {Start-Sleep -Milliseconds $Sleep}
            if ($Vendor -eq "NVIDIA") {
                if ($Global:IsLinux) {Invoke-NvidiaSettings $NvCmd}
                else {& ".\Includes\NvidiaInspector\nvidiaInspector.exe" $NvCmd}
            } elseif ($Vendor -eq "AMD" -and $AmdCmd.Count) {
                if ($Global:IsLinux) {}
                else {}
            } else {$Script:abControl.CommitChanges()}
            $applied.GetEnumerator() | Foreach-Object {Write-Log $_}
            if ($Sleep -gt 0) {Start-Sleep -Milliseconds $Sleep}
        }
    }
}

function Invoke-NvidiaSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$NvCmd = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$SetPowerMizer
    )
    if ($IsLinux) {
        if ($SetPowerMizer) {
            $Devices = Get-Device "nvidia" | Select-Object -ExpandProperty Type_Vendor_index | Foreach-Object {"-a '[gpu:$($_)]/GPUPowerMizerMode=1'"}
            if ($Devices) {$NvCmd += $Devices}
        }
        if ($NvCmd) {
            if (Test-OCDaemon) {
                Set-OCDaemon "nvidia-settings $($NvCmd -join ' ')" -OnEmptyAdd "export CUDA_DEVICE_ORDER=PCI_BUS_ID"
            } else {
                Invoke-Exe -FilePath "nvidia-settings" -ArgumentList ($NvCmd -join ' ') -Runas > $null
            }
        }
    }
}

function Get-Sigma {
    [CmdletBinding()]
    param($data)

    if ($data -and $data.count -gt 1) {
        $mean  = ($data | measure-object -Average).Average
        $bias  = $data.Count-1.5+1/(8*($data.Count-1))
        [Math]::Sqrt(($data | Foreach-Object {[Math]::Pow(($_ - $mean),2)} | Measure-Object -Sum).Sum/$bias)
    } else {0}
}

function Get-GPUVendorList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$Type = @() #AMD/NVIDIA
    )
    if (-not $Type.Count) {$Type = "AMD","NVIDIA"}
    $Type | Foreach-Object {if ($_ -like "*AMD*" -or $_ -like "*Advanced Micro*"){"AMD","Advanced Micro Devices","Advanced Micro Devices, Inc."}elseif($_ -like "*NVIDIA*" ){"NVIDIA","NVIDIA Corporation"}elseif($_ -like "*INTEL*"){"INTEL","Intel(R) Corporation","GenuineIntel"}else{$_}} | Select-Object -Unique
}

function Select-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$Devices = @(),
        [Parameter(Mandatory = $False)]
        [Array]$Type = @(), #CPU/AMD/NVIDIA
        [Parameter(Mandatory = $False)]
        [Long]$MinMemSize = 0
    )
    $Devices | Where-Object {($_.Type -eq "CPU" -and $Type -contains "CPU") -or ($_.Type -eq "GPU" -and $_.OpenCL.GlobalMemsize -ge $MinMemSize -and $Type -icontains $_.Vendor)}
}

function Get-DeviceModelName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Device,
        [Parameter(Mandatory = $False)]
        [Array]$Name = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$Short
    )
    $Device | Where-Object {$Name.Count -eq 0 -or $Name -icontains $_.Name} | Foreach-Object {if ($_.Type -eq "Cpu") {"CPU"} else {$_.Model_Name}} | Select-Object -Unique | Foreach-Object {if ($Short){($_ -replace "geforce|radeon|intel|\(r\)","").Trim()}else {$_}}
}

function Get-GPUIDs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject[]]$Devices,
        [Parameter(Mandatory = $False)]
        [Int]$Offset = 0,
        [Parameter(Mandatory = $False)]
        [Switch]$ToHex = $False,
        [Parameter(Mandatory = $False)]
        [String]$Join
    )
    $GPUIDs = $Devices | Select -ExpandProperty Type_PlatformId_Index -ErrorAction Ignore | Foreach-Object {if ($ToHex) {[Convert]::ToString($_ + $Offset,16)} else {$_ + $Offset}}
    if ($PSBoundParameters.ContainsKey("Join")) {$GPUIDs -join $Join} else {$GPUIDs}    
}

function Test-GPU {
    #$VideoCardsAvail = Get-GPUs
    $GPUfail = 0
    #Get-GPUobjects | Foreach-Object { if ( $VideoCardsAvail.DeviceID -notcontains $_.DeviceID ) { $GPUfail++ } }
    if ($GPUfail -ge 1) {
        Write-Log -Level Error "$($GPUfail) failing GPU(s)! PC will reboot in 5 seconds"
        Start-Sleep 5
        $reboot = @("-r", "-f", "-t", 0)
        & shutdown $reboot        
    }
}

function Test-TimeSync {

    if (-not $IsWindows) {return}

    try {
        if ((Get-Service -Name W32Time).Status -ne 'Running')
        {
            Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq "W32Time" -and $_.Status -ne "Running" } | Set-Service -StartupType Manual -Status Running
            Write-Log 'Start service W32Time (Windows Time)'
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "[Test-TimeSync] W32Time Service is not running and could not be started!"
        return
    }


    try {
        $configuredNtpServerNameRegistryPolicy = $null
        if (Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters -PathType Container)
        {
            $configuredNtpServerNameRegistryPolicy = Get-ItemProperty `
                -Path HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters `
                -Name 'NtpServer' -ErrorAction Ignore |
                Select-Object -ExpandProperty NtpServer
        }

        if ($configuredNtpServerNameRegistryPolicy)
        {
            # Policy override
            $ConfiguredNTPServerNameRaw = $configuredNtpServerNameRegistryPolicy.Trim()
        }
        else
        {
            # Exception if not exists
            $ConfiguredNTPServerNameRaw = ((Get-ItemProperty `
                -Path HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters -Name 'NtpServer').NtpServer).Trim()
        }

        if ($ConfiguredNTPServerNameRaw)
        {
            $ConfiguredNTPServerNames = $ConfiguredNTPServerNameRaw.Split(' ') -replace ',.+$'
        }
        else {
            $ConfiguredNTPServerNames = @("pool.ntp.org","time.windows.com")
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "[Test-TimeSync] No configured nameservers found in registry"
        return
    }


    try {
        if ( (w32tm /stripchart /computer:$($ConfiguredNTPServerNames[0]) /dataonly /samples:1 | Select-Object -Last 1 | Out-String).Split(",")[1] -match '([\d\.\-\+]+)' ) {
            $b = [double]$matches[1]
            if ( $b*$b -gt 4.0 ) {
                Write-Log -Level Warn "[Test-TimeSync] Time is out of sync by $($b.ToString('f3'))s! $((get-date).ToString('HH:mm:ss')) - syncing now with $($ConfiguredNTPServerNames[0])"
                $s = w32tm /resync /update | Select-Object -Last 1 | Out-String                
                Write-Log "[Test-TimeSync] $($s)"
            }
        } else {
            Write-Log -Level Warn "[Test-TimeSync] Could not read w32tm statistics from $($w32tmSource)"
        }
    }
    catch { 
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "[Test-TimeSync] Something went wrong"
    }

}

function Get-Yes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $Argument = $false
    )
    if ($Argument -eq $null) {$false}
    elseif ($Argument -is [bool]) {$Argument} else {[Bool](0,$false,"no","n","not","niet","non","nein","never","0" -inotcontains $Argument)}
}

function Read-HostString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt,
        [Parameter(Mandatory = $False)]
        [String]$Default = '',
        [Parameter(Mandatory = $False)]
        [Switch]$Mandatory = $False,
        [Parameter(Mandatory = $False)]
        [String]$Characters = "A-Z0-9",
        [Parameter(Mandatory = $False)]
        [Array]$Valid = @(),
        [Parameter(Mandatory = $False)]
        [Int]$MinLength = 0,
        [Parameter(Mandatory = $False)]
        [Int]$MaxLength = 0,
        [Parameter(Mandatory = $False)]
        [Int]$Length = 0,
        [Parameter(Mandatory = $False)]
        [Array]$Controls = @("exit","cancel","back","save","done","<")
    )
    if ($Valid.Count -eq 1 -and $Valid[0] -match "[,;]") {[Array]$Valid = [regex]::split($Valid[0].Trim(),"\s*[,;]+\s*")}
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result.Trim()}
        if ($Controls -icontains $Result){$Result;return}
        if ("del","delete","dele","clr","cls","clear","cl" -icontains $Result){$Result=''}                
        if ("help","list" -icontains $Result) {
            if ($Valid.Count -gt 0) {Write-Host "Valid inputs are from the following list:";Write-Host $($Valid -join ",");Write-Host " "}
            else {Write-Host "Every input will be valid. So, take care :)";Write-Host " "}
            $Repeat = $true
        }
        else {
            if ($Characters -ne $null -and $Characters -ne $false -and $Characters.Length) {[String]$Result = $Result -replace "[^$($Characters)]+",""}
            if ($Mandatory -or $Result.Length -gt 0) {
                if ($Length -gt 0 -and $Result.Length -ne $Length) {Write-Host "The input must be exactly $($Length) characters long";Write-Host " ";$Repeat = $true}
                if ($MinLength -gt 0 -and $Result.Length -lt $MinLength) {Write-Host "The input is shorter than the minimum of $($MinLength) characters";Write-Host " ";$Repeat = $true}
                if ($MaxLength -gt 0 -and $Result.Length -gt $MaxLength) {Write-Host "The input is longer than the maximum of $($MaxLength) characters";Write-Host " ";$Repeat = $true}
                if ($Valid.Count -gt 0) {
                    if ($Valid -inotcontains $Result) {
                        Write-Host "Invalid input (type `"list`" to show all valid)";
                        Write-Host " ";
                        $Repeat = $true
                    } else {
                        [String]$Result = Compare-Object $Valid @($Result) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject | Select-Object -Index 0
                    }
                }
            }
        }
    } until (-not $Repeat -and ($Result.Length -gt 0 -or -not $Mandatory))
    $Result
}

function Read-HostDouble {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt,
        [Parameter(Mandatory = $False)]
        $Default = $null,
        [Parameter(Mandatory = $False)]
        [Switch]$Mandatory = $False,
        [Parameter(Mandatory = $False)]
        $Min = $null,
        [Parameter(Mandatory = $False)]
        $Max = $null,
        [Parameter(Mandatory = $False)]
        [Array]$Controls = @("exit","cancel","back","save","done","<")
    )        
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default -ne $null){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result.Trim()}
        if ($Controls -icontains $Result){$Result;return}
        [Double]$Result = $Result -replace "[^0-9\.,\-]","" -replace ",","."
        if ($Mandatory -or $Result) {            
            if ($Min -ne $null -and $Result -lt $Min) {Write-Host "The input is lower than the minimum of $($Min)";Write-Host " ";$Repeat = $true}
            if ($Max -ne $null -and $Result -gt $Max) {Write-Host "The input is higher than the maximum of $($Max)";Write-Host " ";$Repeat = $true}
        }
    } until (-not $Repeat -and ($Result -or -not $Mandatory))
    $Result
}

function Read-HostInt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt,
        [Parameter(Mandatory = $False)]
        $Default = $null,
        [Parameter(Mandatory = $False)]
        [Switch]$Mandatory = $False,
        [Parameter(Mandatory = $False)]
        $Min = $null,
        [Parameter(Mandatory = $False)]
        $Max = $null,
        [Parameter(Mandatory = $False)]
        [Array]$Controls = @("exit","cancel","back","save","done","<")
    )    
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default -ne $null){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result.Trim()}
        if ($Controls -icontains $Result){$Result;return}
        [Int]$Result = $Result -replace "[^0-9\-]",""
        if ($Mandatory -or $Result) {            
            if ($Min -ne $null -and $Result -lt $Min) {Write-Host "The input is lower than the minimum of $($Min)";Write-Host " ";$Repeat = $true}
            if ($Max -ne $null -and $Result -gt $Max) {Write-Host "The input is higher than the maximum of $($Max)";Write-Host " ";$Repeat = $true}
        }
    } until (-not $Repeat -and ($Result -or -not $Mandatory))
    $Result
}

function Read-HostArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt,
        [Parameter(Mandatory = $False)]
        [Array]$Default = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$Mandatory = $False,
        [Parameter(Mandatory = $False)]
        [String]$Characters = "A-Z0-9",
        [Parameter(Mandatory = $False)]
        [Array]$Valid = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$AllowDuplicates = $False,
        [Parameter(Mandatory = $False)]
        [Array]$Controls = @("exit","cancel","back","save","done","<")
    )
    if ($Default.Count -eq 1 -and $Default[0] -match "[,;]") {[Array]$Default = @([regex]::split($Default[0].Trim(),"\s*[,;]+\s*") | Where-Object {$_ -ne ""} | Select-Object)}
    if ($Valid.Count -eq 1 -and $Valid[0] -match "[,;]") {[Array]$Valid = @([regex]::split($Valid[0].Trim(),"\s*[,;]+\s*") | Where-Object {$_ -ne ""} | Select-Object)}
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default.Count){" [default=$($Default -join ",")]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default -join ","}else{$Result.Trim()}
        if ($Controls -icontains $Result){$Result;return}
        if ("del","delete","dele","clr","cls","clear","cl" -icontains $Result){$Result=''}        
        if ("help","list" -icontains $Result) {
            if ($Valid.Count -gt 0) {Write-Host "Valid inputs are from the following list:";Write-Host $($Valid -join ",")}
            else {Write-Host "Every input will be valid. So, take care :)";Write-Host " "}
            $Repeat = $true
        } else {
            $Mode = "v";
            if ($Result -match "^([\-\+])(.+)$") {
                $Mode = $Matches[1]
                $Result = $Matches[2]
            }
            if ($Characters -eq $null -or $Characters -eq $false) {[String]$Characters=''}
            [Array]$Result = @($Result -replace "[^$($Characters),;]+","" -split "\s*[,;]+\s*" | Where-Object {$_ -ne ""} | Select-Object)
            Switch ($Mode) {
                "+" {$Result = @($Default | Select-Object) + @($Result | Select-Object); break}
                "-" {$Result = @($Default | Where-Object {$Result -inotcontains $_}); break}
            }
            if (-not $AllowDuplicates) {$Result = $Result | Select-Object -Unique}
            if ($Valid.Count -gt 0) {
                if ($Invalid = Compare-Object @($Result | Select-Object -Unique) @($Valid | Select-Object -Unique) | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) {
                    Write-Host "The following entries are invalid (type `"list`" to show all valid):"
                    Write-Host $($Invalid -join ",")
                    Write-Host " "
                    $Repeat = $true
                }
            }
        }
    } until (-not $Repeat -and ($Result.Count -gt 0 -or -not $Mandatory))
    $Result
}

function Read-HostBool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt,
        [Parameter(Mandatory = $False)]
        $Default = $false,
        [Parameter(Mandatory = $False)]
        [Array]$Controls = @("exit","cancel","back","save","done","<")
    )
    $Default = if (Get-Yes $Default){"yes"}else{"no"}
    $Result = if (([String]$Result=(Read-Host "$($Prompt) (yes/no) [default=$($Default)]").Trim()) -eq ''){$Default}else{$Result.Trim()}
    if ($Controls -icontains $Result){$Result;return}
    Get-Yes $Result
}

function Read-HostKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt
    )    
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("$Prompt")
    }
    else
    {
        Write-Host "$Prompt" -ForegroundColor Yellow
        [void]($Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'))
    }
}

function Get-ContentDataMD5hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $Data
    )
    if ($Data -eq $null) {$Data = ''}
    Get-MD5Hash ($Data | ConvertTo-Json -Compress)
}

function Set-ContentJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $True)]
        $Data,
        [Parameter(Mandatory = $False)]
        $MD5hash = '',
        [Parameter(Mandatory = $False)]
        [Switch]$Compress
    )
    $retry = 3
    do {
        try {
            $Exists = $false
            if ([System.IO.File]::Exists($PathToFile)) {
                    $FileStream = [System.IO.File]::Open($PathToFile,'Open','Write')
                    $FileStream.Close()
                    $FileStream.Dispose()
                    $Exists = $true
            }
            if (-not $Exists -or $MD5hash -eq '' -or ($MD5hash -ne (Get-ContentDataMD5hash($Data)))) {
                ConvertTo-Json -InputObject $Data -Compress:$Compress -Depth 10 | Set-Content $PathToFile -Encoding utf8 -Force
            } elseif ($Exists) {
                (Get-ChildItem $PathToFile).LastWriteTime = Get-Date
            }
            return $true
        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        $retry--
        Start-Sleep -Seconds 1
    } until ($retry -le 0)
    Write-Log -Level Warn "Unable to write to file $PathToFile"
    return $false
}

function Set-MinersConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $False)]
        [Switch]$UseDefaultParams = $false
    )
    $ConfigName = "Miners"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\MinersConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        $Algo = [hashtable]@{}
        $Done = [PSCustomObject]@{}
        $ChangeTag = $null
        if (Test-Path $PathToFile) {
            $PresetTmp = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
            $ChangeTag = Get-ContentDataMD5hash($PresetTmp)
            #cleanup duplicates in algorithm lists
            $Preset = [PSCustomObject]@{}
            if ($PresetTmp.PSObject.Properties.Name.Count -gt 0 ) {
                foreach($Name in @($PresetTmp.PSObject.Properties.Name)) {
                    if (-not $Name -or (Get-Member -inputobject $Preset -name $Name -Membertype Properties)) {continue}
                    $Preset | Add-Member $Name @(
                        [System.Collections.ArrayList]$MinerCheck = @()
                        foreach($cmd in $PresetTmp.$Name) {
                            $m = $(if (-not $Algo[$cmd.MainAlgorithm]) {$Algo[$cmd.MainAlgorithm]=Get-Algorithm $cmd.MainAlgorithm};$Algo[$cmd.MainAlgorithm])
                            $s = $(if ($cmd.SecondaryAlgorithm) {if (-not $Algo[$cmd.SecondaryAlgorithm]) {$Algo[$cmd.SecondaryAlgorithm]=Get-Algorithm $cmd.SecondaryAlgorithm};$Algo[$cmd.SecondaryAlgorithm]}else{""})
                            $k = "$m-$s"
                            if (-not $MinerCheck.Contains($k)) {$cmd.MainAlgorithm=$m;$cmd.SecondaryAlgorithm=$s;$cmd;$MinerCheck.Add($k)>$null}
                        }) -Force
                }
            }
        }

        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = $null}
            if (-not (Test-Path ".\nopresets.txt")) {$Setup = Get-ChildItemContent ".\Data\MinersConfigDefault.ps1" | Select-Object -ExpandProperty Content}
            $AllDevices = Get-Device "cpu","gpu" -IgnoreOpenCL
            $AllMiners = if (Test-Path "Miners") {@(Get-MinersContent -InfoOnly)}
            foreach ($a in @("CPU","NVIDIA","AMD")) {
                if ($a -eq "CPU") {[System.Collections.ArrayList]$SetupDevices = @("CPU")}
                else {
                    $Devices = @($AllDevices | Where-Object {$_.Vendor -eq $a} | Select-Object Model,Model_Name,Name)
                    [System.Collections.ArrayList]$SetupDevices = @($Devices | Select-Object -ExpandProperty Model -Unique)
                    if ($SetupDevices.Count -gt 1) {Get-DeviceSubsets $Devices | Foreach-Object {$SetupDevices.Add($_.Model -join '-') > $null}}
                }
                
                [System.Collections.ArrayList]$Miners = @($AllMiners | Where-Object Type -icontains $a)
                [System.Collections.ArrayList]$MinerNames = @($Miners | Select-Object -ExpandProperty Name -Unique)                
                foreach ($Miner in $Miners) {
                    foreach ($SetupDevice in $SetupDevices) {                        
                        $Done | Add-Member "$($Miner.Name)-$($SetupDevice)" @(
                            [System.Collections.ArrayList]$MinerCheck = @()
                            foreach($cmd in $Miner.Commands) {
                                $m = $(if (-not $Algo[$cmd.MainAlgorithm]) {$Algo[$cmd.MainAlgorithm]=Get-Algorithm $cmd.MainAlgorithm};$Algo[$cmd.MainAlgorithm])
                                $s = $(if ($cmd.SecondaryAlgorithm) {if (-not $Algo[$cmd.SecondaryAlgorithm]) {$Algo[$cmd.SecondaryAlgorithm]=Get-Algorithm $cmd.SecondaryAlgorithm};$Algo[$cmd.SecondaryAlgorithm]}else{""})
                                $k = "$m-$s"                                
                                if (-not $MinerCheck.Contains($k)) {[PSCustomObject]@{MainAlgorithm=$m;SecondaryAlgorithm=$s;Params = "";MSIAprofile = "";OCprofile = "";Difficulty="";Penalty="";Disable="0"};$MinerCheck.Add($k)>$null}
                            }
                        )
                    }
                }

                if ($Setup) {
                    foreach ($Name in @($Setup.PSObject.Properties.Name)) {
                        if ($MinerNames.Contains($Name)) {
                            [System.Collections.ArrayList]$Value = @(foreach ($v in $Setup.$Name) {if (-not $UseDefaultParams) {$v.Params = ''};if ($v.MainAlgorithm -ne '*') {$v.MainAlgorithm=$(if (-not $Algo[$v.MainAlgorithm]) {$Algo[$v.MainAlgorithm]=Get-Algorithm $v.MainAlgorithm};$Algo[$v.MainAlgorithm]);$v.SecondaryAlgorithm=$(if ($v.SecondaryAlgorithm) {if (-not $Algo[$v.SecondaryAlgorithm]) {$Algo[$v.SecondaryAlgorithm]=Get-Algorithm $v.SecondaryAlgorithm};$Algo[$v.SecondaryAlgorithm]}else{""})};$v})
                            foreach ($SetupDevice in $SetupDevices) {
                                $NameKey = "$($Name)-$($SetupDevice)"
                                [System.Collections.ArrayList]$ValueTmp = $Value.Clone()
                                if (Get-Member -inputobject $Done -name $NameKey -Membertype Properties) {
                                    [System.Collections.ArrayList]$NewValues = @(Compare-Object @($Done.$NameKey) @($Setup.$Name) -Property MainAlgorithm,SecondaryAlgorithm | Where-Object SideIndicator -eq '<=' | Foreach-Object {$m=$_.MainAlgorithm;$s=$_.SecondaryAlgorithm;$Done.$NameKey | Where-Object {$_.MainAlgorithm -eq $m -and $_.SecondaryAlgorithm -eq $s}} | Select-Object)
                                    if ($NewValues.count) {$ValueTmp.AddRange($NewValues) > $null}
                                    $Done | Add-Member $NameKey $ValueTmp -Force
                                }
                            }
                        }
                    }
                }
            }

            if ($Preset) {
                foreach ($Name in @($Preset.PSObject.Properties.Name)) {
                    [System.Collections.ArrayList]$Value = @(foreach ($v in $Preset.$Name) {if ($v.MainAlgorithm -ne '*') {$v.MainAlgorithm=$(if (-not $Algo[$v.MainAlgorithm]) {$Algo[$v.MainAlgorithm]=Get-Algorithm $v.MainAlgorithm};$Algo[$v.MainAlgorithm]);$v.SecondaryAlgorithm=$(if ($v.SecondaryAlgorithm) {if (-not $Algo[$v.SecondaryAlgorithm]) {$Algo[$v.SecondaryAlgorithm]=Get-Algorithm $v.SecondaryAlgorithm};$Algo[$v.SecondaryAlgorithm]}else{""})};$v})
                    if (Get-Member -inputobject $Done -name $Name -Membertype Properties) {
                        [System.Collections.ArrayList]$NewValues = @(Compare-Object $Done.$Name $Preset.$Name -Property MainAlgorithm,SecondaryAlgorithm | Where-Object SideIndicator -eq '<=' | Foreach-Object {$m=$_.MainAlgorithm;$s=$_.SecondaryAlgorithm;$Done.$Name | Where-Object {$_.MainAlgorithm -eq $m -and $_.SecondaryAlgorithm -eq $s}} | Select-Object)
                        if ($NewValues.Count) {$Value.AddRange($NewValues) > $null}
                    }
                    $Done | Add-Member $Name $Value.ToArray() -Force
                }
            }

            $Default = [PSCustomObject]@{Params = "";MSIAprofile = "";OCprofile = "";Difficulty="";Penalty="";Disable="0"}
            $DoneSave = [PSCustomObject]@{}
            $Done.PSObject.Properties.Name | Sort-Object | Foreach-Object {
                $Name = $_
                if ($Done.$Name.Count) {
                    $Done.$Name | Foreach-Object {
                        $Done1 = $_
                        $Default.PSObject.Properties.Name | Where-Object {$Done1.$_ -eq $null} | Foreach-Object {$Done1 | Add-Member $_ $Default.$_ -Force}
                    }
                    $DoneSave | Add-Member $Name @($Done.$Name | Sort-Object MainAlgorithm,SecondaryAlgorithm)
                }
            }
            Set-ContentJson -PathToFile $PathToFile -Data $DoneSave -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-AlgorithmsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Algorithms"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\AlgorithmsConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind = "0";MSIAprofile = 0;OCprofile=""}
            $Setup = Get-ChildItemContent ".\Data\AlgorithmsConfigDefault.ps1" | Select-Object -ExpandProperty Content
            $AllAlgorithms = Get-Algorithms -Values
            foreach ($Algorithm in $AllAlgorithms) {
                if (-not $Preset.$Algorithm) {$Preset | Add-Member $Algorithm $(if ($Setup.$Algorithm) {$Setup.$Algorithm} else {[PSCustomObject]@{}}) -Force}
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$Algorithm.$SetupName -eq $null){$Preset.$Algorithm | Add-Member $SetupName $Default.$SetupName -Force}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-PresetDefault {
    if (Test-Path ".\Data\PresetDefault.ps1") {
        $Setup = Get-ChildItemContent ".\Data\PresetDefault.ps1" | Select-Object -ExpandProperty Content
        $Setup.PSObject.Properties.Name | Foreach-Object {
            $Session.DefaultValues[$_] = $Setup.$_
        }
    }
}

function Set-ColorsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Colors"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {$Preset = [PSCustomObject]@{}}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Host.UI.RawUI.PSObject.Properties.Name    | Where-Object {$_ -match "Color$" -and $Preset.PSObject.Properties.Name -inotcontains $_} | Foreach-Object {$Preset | Add-Member $_ "$($Host.UI.RawUI.$_)" -Force}
            $Host.PrivateData.PSObject.Properties.Name | Where-Object {$_ -match "Color$" -and $Preset.PSObject.Properties.Name -inotcontains $_} | Foreach-Object {$Preset | Add-Member $_ "$($Host.PrivateData.$_)" -Force}
            $Preset.PSObject.Properties.Name | Where-Object {@($Host.UI.RawUI.PSObject.Properties.Name)+@($Host.PrivateData.PSObject.Properties.Name) -inotcontains $_} | Foreach-Object {$Preset.PSObject.Properties.Remove($_)}
            Set-ContentJson -PathToFile $PathToFile -Data $Preset -MD5hash $ChangeTag > $null
            $Session.ConfigFiles[$ConfigName].Healthy = $true
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-CoinsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Coins"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\CoinsConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind="0";PostBlockMining="0";MinProfitPercent="0";Wallet="";EnableAutoPool="0";Comment=""}
            $Setup = Get-ChildItemContent ".\Data\CoinsConfigDefault.ps1" | Select-Object -ExpandProperty Content
            
            foreach ($Coin in @($Setup.PSObject.Properties.Name | Select-Object)) {
                if (-not $Preset.$Coin) {$Preset | Add-Member $Coin $(if ($Setup.$Coin) {$Setup.$Coin} else {[PSCustomObject]@{}}) -Force}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {                
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$_.$SetupName -eq $null){$Preset.$_ | Add-Member $SetupName $Default.$SetupName -Force}}
                $Sorted | Add-Member $_ $Preset.$_ -Force
            }
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-GpuGroupsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "GpuGroups"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $GpuNames = Get-Device "nvidia","amd" -IgnoreOpenCL | Select-Object -ExpandProperty Name -Unique
            foreach ($GpuName in $GpuNames) {
                if ($Preset.$GpuName -eq $null) {$Preset | Add-Member $GpuName "" -Force}
                elseif ($Preset.$GpuName -ne "") {$Script:GlobalCachedDevices | Where-Object Name -eq $GpuName | Foreach-Object {$_.Model += $Preset.$GpuName.ToUpper();$_.GpuGroup = $Preset.$GpuName.ToUpper()}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-CombosConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Combos"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)

            $Sorted = [PSCustomObject]@{}
            Foreach($SubsetType in @("AMD","NVIDIA")) {
                if ($Preset.$SubsetType -eq $null) {$Preset | Add-Member $SubsetType ([PSCustomObject]@{}) -Force}
                if ($Sorted.$SubsetType -eq $null) {$Sorted | Add-Member $SubsetType ([PSCustomObject]@{}) -Force}

                $NewSubsetModels = @()

                $SubsetDevices = @($Script:GlobalCachedDevices | Where-Object {$_.Vendor -eq $SubsetType} | Select-Object)

                if (($SubsetDevices.Model | Select-Object -Unique).Count -gt 1) {

                    # gpugroups never combine against each other, if same gpu. Except full group
                    $GpuGroups = @()
                    $FullGpuGroups = $SubsetDevices | Where-Object GpuGroup -ne "" | Group-Object {$_.Model -replace "$($_.GpuGroup)$"} | Where-Object {$_.Count -gt 1} | Foreach-Object {$GpuGroups += $_.Group.Model;($_.Group.Model | Select-Object -Unique | Sort-Object) -join '-'}

                    # count groups
                    $GpuCount = ($SubsetDevices | Where-Object GpuGroup -eq "" | Select-Object -Property Model -Unique | Measure-Object).Count + $FullGpuGroups.Count

                    # collect full combos for gpu categories
                    $FullCombosByCategory = @{}
                    if ($GpuCount -gt 3) {
                        $SubsetDevices | Group-Object {
                            $Model = $_.Model
                            $Mem = [int]($_.OpenCL.GlobalMemSize / 1GB)
                            Switch ($SubsetType) {
                                "AMD"    {"$($Model.SubString(0,2))$($Mem)GB"}
                                "NVIDIA" {"$(
                                    Switch (Get-NvidiaArchitecture $Model) {
                                        "Pascal" {Switch -Regex ($Model) {"105" {"GTX5"};"106" {"GTX6"};"(104|107|108)" {"GTX7"};default {$Model}}}
                                        "Turing" {"RTX"}
                                        default  {$Model}
                                    })$(if ($Mem -lt 6) {"$($Mem)GB"})"}
                            }
                        } | Foreach-Object {$FullCombosByCategory[$_.Name] = @($_.Group.Model | Select-Object -Unique | Sort-Object | Select-Object)}
                    }

                    $DisplayWarning = $false
                    Get-DeviceSubSets $SubsetDevices | Foreach-Object {
                        $Subset = $_.Model
                        $SubsetModel= $Subset -join '-'
                        if ($Preset.$SubsetType.$SubsetModel -eq $null) {
                            $SubsetDefault = -not $GpuGroups.Count -or ($FullGpuGroups | Where-Object {$SubsetModel -match $_} | Measure-Object).Count -or -not (Compare-Object $GpuGroups $_.Model -ExcludeDifferent -IncludeEqual | Measure-Object).Count
                            if ($SubsetDefault -and $GpuCount -gt 3) {
                                if (($FullCombosByCategory.GetEnumerator() | Where-Object {(Compare-Object $Subset $_.Value -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq $_.Value.Count} | Foreach-Object {$_.Value.Count} | Measure-Object -Sum).Sum -ne $Subset.Count) {
                                    $SubsetDefault = "0"
                                }
                                $DisplayWarning = $true
                            }
                            $Preset.$SubsetType | Add-Member $SubsetModel "$([int]$SubsetDefault)" -Force
                        }
                        $NewSubsetModels += $SubsetModel
                    }

                    if ($DisplayWarning) {
                        Write-Log -Level Warn "More than 3 different GPUs will slow down the combo mode significantly. Automatically reducing combinations in combos.config.txt."
                    }

                    # always allow fullcombomodel
                    $Preset.$SubsetType.$SubsetModel = "1"
                }

                $Preset.$SubsetType.PSObject.Properties.Name | Where-Object {$NewSubsetModels -icontains $_} | Sort-Object | Foreach-Object {$Sorted.$SubsetType | Add-Member $_ "$(if (Get-Yes $Preset.$SubsetType.$_) {1} else {0})" -Force}
            }
            
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-DevicesConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Devices"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\DevicesConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{Algorithm="";ExcludeAlgorithm="";MinerName="";ExcludeMinerName="";DisableDualMining="";DefaultOCprofile="";PowerAdjust="100";Worker=""}
            $Setup = Get-ChildItemContent ".\Data\DevicesConfigDefault.ps1" | Select-Object -ExpandProperty Content
            $Devices = Get-Device "cpu","nvidia","amd" -IgnoreOpenCL
            $Devices | Select-Object -Unique Type,Model | Foreach-Object {
                $DeviceModel = $_.Model
                $DeviceType  = $_.Type
                if (-not $Preset.$DeviceModel) {$Preset | Add-Member $DeviceModel $(if ($Setup.$DeviceType) {$Setup.$DeviceType} else {[PSCustomObject]@{}}) -Force}
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$DeviceModel.$SetupName -eq $null){$Preset.$DeviceModel | Add-Member $SetupName $Default.$SetupName -Force}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-PoolsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Pools"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\PoolsConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = $null}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Done = [PSCustomObject]@{}
            $Default = [PSCustomObject]@{Worker = "`$WorkerName";Penalty = 0;Algorithm = "";ExcludeAlgorithm = "";CoinName = "";ExcludeCoin = "";CoinSymbol = "";ExcludeCoinSymbol = "";MinerName = "";ExcludeMinerName = "";FocusWallet = "";AllowZero = "0";EnableAutoCoin = "0";EnablePostBlockMining = "0";CoinSymbolPBM = "";DataWindow = "";StatAverage = ""}
            $Setup = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1" | Select-Object -ExpandProperty Content
            $Pools = @(Get-ChildItem ".\Pools\*.ps1" -ErrorAction Ignore | Select-Object -ExpandProperty BaseName)
            $Global:PoolFields = @("Wallets") + $Default.PSObject.Properties.Name + @($Setup.PSObject.Properties.Value | Where-Object Fields | Foreach-Object {$_.Fields.PSObject.Properties.Name} | Select-Object -Unique) | Select-Object -Unique
            if ($Pools.Count -gt 0) {
                $Pools | Foreach-Object {
                    $Pool_Name = $_
                    if ($Preset -and $Preset.PSObject.Properties.Name -icontains $Pool_Name) {
                        $Setup_Content = $Preset.$Pool_Name
                    } else {
                        $Setup_Content = [PSCustomObject]@{}
                        $Setup_Currencies = @("BTC")
                        if ($Setup.$Pool_Name) {
                            if ($Setup.$Pool_Name.Fields) {$Setup_Content = $Setup.$Pool_Name.Fields}
                            $Setup_Currencies = @($Setup.$Pool_Name.Currencies)            
                        }
                        $Setup_Currencies | Foreach-Object {
                            $Setup_Content | Add-Member $_ "$(if ($_ -eq "BTC"){"`$Wallet"})" -Force
                            $Setup_Content | Add-Member "$($_)-Params" "" -Force
                        }
                    }
                    if ($Setup.$Pool_Name.Fields -ne $null) {
                        foreach($SetupName in $Setup.$Pool_Name.Fields.PSObject.Properties.Name) {if ($Setup_Content.$SetupName -eq $null){$Setup_Content | Add-Member $SetupName $Setup.$Pool_Name.Fields.$SetupName -Force}}
                    }
                    foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Setup_Content.$SetupName -eq $null){$Setup_Content | Add-Member $SetupName $Default.$SetupName -Force}}
                    $Done | Add-Member $Pool_Name $Setup_Content
                }
                Set-ContentJson -PathToFile $PathToFile -Data $Done -MD5hash $ChangeTag > $null
            } else {
                Write-Log -Level Error "No pools found!"
            }
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-OCProfilesConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "OCProfiles"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\OCProfilesConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*";LockVoltagePoint = "*"}
            if ($true -or -not $Preset.PSObject.Properties.Name) {
                $Setup = Get-ChildItemContent ".\Data\OCProfilesConfigDefault.ps1" | Select-Object -ExpandProperty Content
                $Devices = Get-Device "amd","nvidia" -IgnoreOpenCL
                $Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object | Foreach-Object {
                    $Model = $_
                    For($i=1;$i -le 5;$i++) {
                        $Profile = "Profile$($i)-$($Model)"
                        if (-not $Preset.$Profile) {$Preset | Add-Member $Profile $(if ($Setup.$Profile -ne $null) {$Setup.$Profile} else {$Default}) -Force}
                    }
                }
                if (-not $Devices) {
                    For($i=1;$i -le 5;$i++) {
                        $Profile = "Profile$($i)"
                        if (-not $Preset.$Profile) {$Preset | Add-Member $Profile $(if ($Setup.$Profile -ne $null) {$Setup.$Profile} else {$Default}) -Force}
                    }
                }
            }
            $Preset.PSObject.Properties.Name | Foreach-Object {
                $PresetName = $_
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$PresetName.$SetupName -eq $null){$Preset.$PresetName | Add-Member $SetupName $Default.$SetupName -Force}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-SchedulerConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "Scheduler"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            $Default = Get-ChildItemContent ".\Data\SchedulerConfigDefault.ps1" -Quick | Select-Object -ExpandProperty Content
            if ($Preset -is [string] -or $Preset -eq $null) {
                $Preset = @($Default) + @((0..6) | Foreach-Object {$a=$Default | ConvertTo-Json -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore;$a.DayOfWeek = "$_";$a})
            }
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            
            $Preset | Foreach-Object {
                foreach($SetupName in @($Default.PSObject.Properties.Name | Select-Object)) {
                    if ($_.$SetupName -eq $null) {$_ | Add-Member $SetupName $Default.$SetupName -Force}
                }
            }

            Set-ContentJson -PathToFile $PathToFile -Data $Preset -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Test-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$ConfigName,
        [Parameter(Mandatory = $False)]
        [Switch]$Exists,
        [Parameter(Mandatory = $False)]
        [Switch]$Health,
        [Parameter(Mandatory = $False)]
        [Switch]$LastWriteTime
    )
    if (-not $Exists -and ($Health -or $LastWriteTime)) {$Exists = $true}
    $Session.ConfigFiles.ContainsKey($ConfigName) -and $Session.ConfigFiles[$ConfigName].Path -and (-not $Exists -or (Test-Path $Session.ConfigFiles[$ConfigName].Path)) -and (-not $Health -or $Session.ConfigFiles[$ConfigName].Healthy) -and (-not $LastWriteTime -or (Get-ChildItem $Session.ConfigFiles[$ConfigName].Path).LastWriteTime.ToUniversalTime() -gt $Session.ConfigFiles[$ConfigName].LastWriteTime)
}

function Set-ConfigLastWriteTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName
    )
    if (Test-Config $ConfigName -Exists) {
        $Session.ConfigFiles[$ConfigName].LastWriteTime = (Get-ChildItem $Session.ConfigFiles[$ConfigName].Path).LastWriteTime.ToUniversalTime()        
    }
}

function Set-ConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )

    Switch ($ConfigName) {
        "Algorithms"  {Set-AlgorithmsConfigDefault -Force:$Force}
        "Coins"       {Set-CoinsConfigDefault -Force:$Force}
        "Colors"      {Set-ColorsConfigDefault -Force:$Force}
        "Combos"      {Set-CombosConfigDefault -Force:$Force}
        "Devices"     {Set-DevicesConfigDefault -Force:$Force}
        "GpuGroups"   {Set-GpuGroupsConfigDefault -Force:$Force}
        "Miners"      {Set-MinersConfigDefault -Force:$Force}
        "OCProfiles"  {Set-OCProfilesConfigDefault -Force:$Force}
        "Pools"       {Set-PoolsConfigDefault -Force:$Force}
        "Scheduler"   {Set-SchedulerConfigDefault -Force:$Force}
    }
}

function Get-ConfigArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        $Config,
        [Parameter(Mandatory = $False)]
        $Split = ",;",
        [Parameter(Mandatory = $False)]
        $Characters = ""
    )
    if ($Config -isnot [array]) {
        $Config = "$Config".Trim()
        if ($Characters -ne "") {$Config = $Config -replace "[^$Characters$Split]+"}
        @($Config -split "\s*[$Split]+\s*" | Where-Object {$_} | Select-Object)
    } else {$Config}
}

function Get-ConfigPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName,
        [Parameter(Mandatory = $False)]
        [string]$WorkerName = "",
        [Parameter(Mandatory = $False)]
        [string]$GroupName = ""
    )
    if (Test-Config $ConfigName -Exists) {
        $PathToFile = $Session.ConfigFiles[$ConfigName].Path
        if ($WorkerName -or $GroupName) {
            $FileName = Split-Path -Leaf $PathToFile
            $FilePath = Split-Path $PathToFile
            if ($WorkerName) {
                $PathToFileM = Join-Path (Join-Path $FilePath $WorkerName.ToLower()) $FileName
                if (Test-Path $PathToFileM) {$PathToFile = $PathToFileM}
            }
            if ($GroupName) {
                $PathToFileM = Join-Path (Join-Path $FilePath $GroupName.ToLower()) $FileName
                if (Test-Path $PathToFileM) {$PathToFile = $PathToFileM}
            }
        }
        $PathToFile
    }
}

function Get-ConfigContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName,
        [Parameter(Mandatory = $False)]
        [hashtable]$Parameters = @{},
        [Parameter(Mandatory = $False)]
        [string]$WorkerName = "",
        [Parameter(Mandatory = $False)]
        [string]$GroupName = "",
        [Parameter(Mandatory = $False)]
        [Switch]$UpdateLastWriteTime,
        [Parameter(Mandatory = $False)]
        [Switch]$ConserveUnkownParameters
    )
    if ($UpdateLastWriteTime) {$WorkerName = ""}
    if ($PathToFile = Get-ConfigPath -ConfigName $ConfigName -WorkerName $WorkerName -GroupName $GroupName) {
        try {
            if ($UpdateLastWriteTime) {
                $Session.ConfigFiles[$ConfigName].LastWriteTime = (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime()
            }
            $Result = Get-Content $PathToFile -Raw -ErrorAction Stop
            if ($Parameters.Count) {
                $Parameters.GetEnumerator() | Foreach-Object {$Result = $Result -replace "\`$$($_.Name)",$_.Value}
                if (-not $ConserveUnkownParameters) {
                    $Result = $Result -replace "\`$[A-Z0-9_]+"
                }
            }
            $Result | ConvertFrom-Json -ErrorAction Stop
            if (-not $WorkerName) {
                $Session.ConfigFiles[$ConfigName].Healthy=$true
            }
        }
        catch {if ($Error.Count){$Error.RemoveAt(0)}; Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.";Write-Log -Level Info "Your $(([IO.FileInfo]$PathToFile).Name) error: `r`n$($_.Exception.Message)"; if (-not $WorkerName) {$Session.ConfigFiles[$ConfigName].Healthy=$false}}
    }
}

function Get-SessionServerConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [switch]$Force
    )
    if (-not (Test-Config "Config" -Exists)) {return}

    $CurrentConfig = if ($Session.Config) {$Session.Config} else {
        $Result = Get-ConfigContent "Config"
        @("RunMode","ServerName","ServerPort","ServerUser","ServerPassword","EnableServerConfig","ServerConfigName","ExcludeServerConfigVars","EnableServerExcludeList","WorkerName","GroupName") | Where-Object {$Session.DefaultValues.ContainsKey($_) -and $Result.$_ -eq "`$$_"} | ForEach-Object {
            $val = $Session.DefaultValues[$_]
            if ($val -is [array]) {$val = $val -join ','}
            $Result.$_ = $val
        }
        $Result
    }

    if ($CurrentConfig -and $CurrentConfig.RunMode -eq "client" -and $CurrentConfig.ServerName -and $CurrentConfig.ServerPort -and (Get-Yes $CurrentConfig.EnableServerConfig)) {
        $ServerConfigName = if ($CurrentConfig.ServerConfigName) {Get-ConfigArray $CurrentConfig.ServerConfigName}
        if (($ServerConfigName | Measure-Object).Count) {
            Get-ServerConfig -ConfigFiles $Session.ConfigFiles -ConfigName $ServerConfigName -ExcludeConfigVars (Get-ConfigArray $CurrentConfig.ExcludeServerConfigVars) -Server $CurrentConfig.ServerName -Port $CurrentConfig.ServerPort -WorkerName $CurrentConfig.WorkerName -GroupName $CurrentConfig.GroupName -Username $CurrentConfig.ServerUser -Password $CurrentConfig.ServerPassword -Force:$Force -EnableServerExcludeList:(Get-Yes $CurrentConfig.EnableServerExcludeList) > $null
        }
    }
}

function Get-ServerConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigFiles,
        [Parameter(Mandatory = $False)]
        [array]$ConfigName = @(),
        [Parameter(Mandatory = $False)]
        [array]$ExcludeConfigVars = @(),
        [Parameter(Mandatory = $False)]
        [string]$Server = "",
        [Parameter(Mandatory = $False)]
        [int]$Port = 0,
        [Parameter(Mandatory = $False)]
        [string]$WorkerName = "",
        [Parameter(Mandatory = $False)]
        [string]$GroupName = "",
        [Parameter(Mandatory = $False)]
        [string]$Username = "",
        [Parameter(Mandatory = $False)]
        [string]$Password = "",
        [Parameter(Mandatory = $False)]
        [switch]$EnableServerExcludeList,
        [Parameter(Mandatory = $False)]
        [switch]$Force
    )
    $rv = $true
    $ConfigName = $ConfigName | Where-Object {Test-Config $_ -Exists}
    if (($ConfigName | Measure-Object).Count -and $Server -and $Port -and (Test-TcpServer -Server $Server -Port $Port -Timeout 2)) {
        if (-not (Test-Path ".\Data\serverlwt")) {New-Item ".\Data\serverlwt" -ItemType "directory" -ErrorAction Ignore > $null}
        $ServerLWTFile = Join-Path ".\Data\serverlwt" "$(if ($GroupName) {$GroupName} elseif ($WorkerName) {$WorkerName} else {"this"})_$($Server.ToLower() -replace '\.','-')_$($Port).json"
        $ServerLWT = if (Test-Path $ServerLWTFile) {try {Get-Content $ServerLWTFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
        if (-not $ServerLWT) {$ServerLWT = [PSCustomObject]@{}}
        $Params = ($ConfigName | Foreach-Object {$PathToFile = $ConfigFiles[$_].Path;"$($_)ZZZ$(if ($Force -or -not (Test-Path $PathToFile) -or -not $ServerLWT.$_) {"0"} else {$ServerLWT.$_})"}) -join ','
        $Uri = "http://$($Server):$($Port)/getconfig?config=$($Params)&workername=$($WorkerName)&groupname=$($GroupName)&machinename=$($Session.MachineName)&myip=$($Session.MyIP)&version=$(if ($Session.Version -match "^4\.4") {"4.3.9.9"} else {$Session.Version})"
        $Result = Invoke-GetUrl $Uri -user $Username -password $Password -ForceLocal -timeout 8
        if ($Result.Status -and $Result.Content) {
            if ($EnableServerExcludeList -and $Result.ExcludeList) {$ExcludeConfigVars = $Result.ExcludeList}
            $ChangeTag = Get-ContentDataMD5hash($ServerLWT) 
            $ConfigName | Where-Object {$Result.Content.$_.isnew -and $Result.Content.$_.data} | Foreach-Object {
                $PathToFile = $ConfigFiles[$_].Path
                $Data = $Result.Content.$_.data
                if ($_ -eq "config") {
                    $Preset = Get-ConfigContent "config"
                    $Data.PSObject.Properties.Name | Where-Object {$ExcludeConfigVars -inotcontains $_} | Foreach-Object {$Preset | Add-Member $_ $Data.$_ -Force}
                    $Data = $Preset
                } elseif ($_ -eq "pools") {
                    $Preset = Get-ConfigContent "pools"
                    $Preset.PSObject.Properties.Name | Where-Object {$Data.$_ -eq $null -or $ExcludeConfigVars -match "^pools:$($_)$"} | Foreach-Object {$Data | Add-Member $_ $Preset.$_ -Force}
                    $ExcludeConfigVars -match "^pools:.+:.+$" | Foreach-Object {
                        $PoolName = ($_ -split ":")[1]
                        $PoolKey  = ($_ -split ":")[2]
                        if ($Preset.$PoolName.$PoolKey -ne $null) {
                            $Data.$PoolName | Add-Member $PoolKey $Preset.$PoolName.$PoolKey -Force
                        }
                    }
                }
                Set-ContentJson -PathToFile $PathToFile -Data $Data > $null
                $ServerLWT | Add-Member $_ $Result.Content.$_.lwt -Force
            }
            if ($ChangeTag -ne (Get-ContentDataMD5hash($ServerLWT))) {Set-ContentJson $ServerLWTFile -Data $ServerLWT > $null}
        } elseif (-not $Result.Status) {
            Write-Log -Level Warn "$(if ($Result.Content) {$Result.Content} else {"Unknown download error"})"
            $rv = $false
        }
    }
    $rv
}


function ConvertFrom-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [string]$Affinity = '',
        [Parameter(Mandatory = $False)]
        [switch]$ToInt
    )
    try {$AffinityInt = [Convert]::ToInt32($Affinity,16)}catch{if ($Error.Count){$Error.RemoveAt(0)};$AffinityInt=0}
    if ($ToInt) {$AffinityInt}
    else {@(for($a=0;$AffinityInt -gt 0;$a++) {if ($AffinityInt -band 1){$a};$AffinityInt=$AffinityInt -shr 1})}
}

function ConvertTo-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [int[]]$Threads = @(),
        [Parameter(Mandatory = $False)]
        [switch]$ToHex
    )
    $a=0;foreach($b in $Threads){$a+=1 -shl $b};
    if ($ToHex) {"0x{0:x$(if($a -lt 65536){4}else{8})}" -f $a}else{$a}
}

function Get-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [int]$Threads = 0,
        [Parameter(Mandatory = $False)]
        [switch]$Hex
    )
    if ($Hex) {ConvertTo-CPUAffinity @(Get-CPUAffinity $Threads) -ToHex}
    else {
        @(if ($Threads -and $Threads -ne $Global:GlobalCPUInfo.RealCores.Count) {
            $a = $r = 0; $b = [Math]::max(1,[int]($Global:GlobalCPUInfo.Threads/$Global:GlobalCPUInfo.Cores));
            for($i=0;$i -lt [Math]::min($Threads,$Global:GlobalCPUInfo.Threads);$i++) {$a;$c=($a+$b)%$Global:GlobalCPUInfo.Threads;if ($c -lt $a) {$r++;$a=$c+$r}else{$a=$c}}
        } else {$Global:GlobalCPUInfo.RealCores}) | Sort-Object
    }
}

function Get-StatAverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Average = '',
        [Parameter(Mandatory = $False)]
        [String]$Default = ''
    )
    Switch ($Average -replace "[^A-Za-z0-9_]+") {
        {"Live","Minute_5","Minute_10","Hour","Day","ThreeDay","Week" -icontains $_} {$_}
        {"Minute5","Min5","Min_5","5Minute","5_Minute","5" -icontains $_} {"Minute_5"}
        {"Minute10","Min10","Min_10","10Minute","10_Minute","10" -icontains $_} {"Minute_10"}
        {"3Day","3_Day","Three_Day" -icontains $_} {"ThreeDay"}
        default {if ($Default) {$Default} else {"Minute_10"}}
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
        {"1","e1","e","ec","ecurrent","current","default","estimatecurrent" -icontains $_} {"estimate_current"}
        {"2","e2","e24","e24h","last24","estimate24h","24h","estimatelast24h" -icontains $_} {"estimate_last24h"}
        {"3","a2","a","a24","a24h","actual","actual24h","actuallast24h" -icontains $_} {"actual_last24h"}                
        {"4","min","min2","minimum","minimum2" -icontains $_} {"minimum-2"}
        {"5","max","max2","maximum","maximum2" -icontains $_} {"maximum-2"}
        {"6","avg","avg2","average","average2" -icontains $_} {"average-2"}
        {"7","min3","minimum3","minall","minimumall" -icontains $_} {"minimum-3"}
        {"8","max3","maximum3","maxall","maximumall" -icontains $_} {"maximum-3"}
        {"9","avg3","average3","avgall","averageall" -icontains $_} {"average-3"}
        {"10","mine","min2e","minimume","minimum2e" -icontains $_} {"minimum-2e"}
        {"11","maxe","max2e","maximume","maximum2e" -icontains $_} {"maximum-2e"}
        {"12","avge","avg2e","averagee","average2e" -icontains $_} {"average-2e"}
        {"13","minh","min2h","minimumh","minimum2h" -icontains $_} {"minimum-2h"}
        {"14","maxh","max2h","maximumh","maximum2h" -icontains $_} {"maximum-2h"}
        {"15","avgh","avg2h","averageh","average2h" -icontains $_} {"average-2h"}
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
        [Switch]$CheckDataWindow = $false,
        [Parameter(Mandatory = $False)]
        [Double]$ActualDivisor = 1000
    )    
    [Double]$Value = 0
    [System.Collections.ArrayList]$allfields = @("estimate_current","estimate_last24h","actual_last24h")
    [hashtable]$values = @{}
    [bool]$hasdetails=$false
    [bool]$containszero = $false
     foreach ($field in $allfields) {
        if ($Request.$field -ne $null) {
            $values[$field] = if ($Request."$($field)_in_btc_per_hash_per_day" -ne $null){$hasdetails=$true;[double]$Request."$($field)_in_btc_per_hash_per_day"}else{[double]$Request.$field}
            if ($values[$field] -eq [double]0) {$containszero=$true}
        }
    }
    if (-not $hasdetails -and $values.ContainsKey("actual_last24h") -and $ActualDivisor) {$values["actual_last24h"]/=$ActualDivisor}
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
                "2"  {[System.Collections.ArrayList]$fields = @("actual_last24h","estimate_current")}
                "2e" {[System.Collections.ArrayList]$fields = @("estimate_last24h","estimate_current")}
                "2h" {[System.Collections.ArrayList]$fields = @("actual_last24h","estimate_last24h")}
                "3"  {[System.Collections.ArrayList]$fields = $allfields}
            }
            Switch ($Matches[1]) {
                "minimum" {
                    $set = $true
                    foreach ($field in $fields) {
                        if(-not $values.ContainsKey($field)) {continue}
                        $v = $values[$field]
                        if ($set -or $v -lt $Value) {$Value = $v;$set=$false}
                    }
                }
                "maximum" {
                    $set = $true
                    foreach ($field in $fields) {
                        if(-not $values.ContainsKey($field)) {continue}
                        $v = $values[$field]
                        if ($set -or $v -gt $Value) {$Value = $v;$set=$false}
                    }
                }
                "average" {
                    $c=0
                    foreach ($field in $fields) {                
                        if(-not $values.ContainsKey($field)) {continue}
                        $Value+=$values[$field]
                        $c++
                    }
                    if ($c) {$Value/=$c}
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

function Get-DeviceSubsets($Device) {
    $Models = @($Device | Select-Object Model,Model_Name -Unique)
    if ($Models.Count) {
        $a = @();0..$($Models.Count-1) | Foreach-Object {$a+=$_}
        @(Get-Subsets $a | Where-Object {$_.Length -gt 1} | Foreach-Object{
            [PSCustomObject[]]$x = @($_.ToCharArray() | Foreach-Object {$Models[[string]$_/1]}) | Sort-Object -Property Model
            [PSCustomObject]@{
                Model = @($x.Model)
                Model_Name = @($x.Model_Name)
                Name = @($Device | Where-Object {$x.Model -icontains $_.Model} | Select-Object -ExpandProperty Name -Unique | Sort-Object)
            }
        })
    }
}

function Get-Subsets($a){
    #uncomment following to ensure only unique inputs are parsed
    #e.g. 'B','C','D','E','E' would become 'B','C','D','E'
    $a = $a | Select-Object -Unique
    #create an array to store output
    $l = @()
    #for any set of length n the maximum number of subsets is 2^n
    for ($i = 0; $i -lt [Math]::Pow(2,$a.Length); $i++)
    { 
        #temporary array to hold output
        [string[]]$out = New-Object string[] $a.length
        #iterate through each element
        for ($j = 0; $j -lt $a.Length; $j++)
        { 
            #start at the end of the array take elements, work your way towards the front
            if (($i -band (1 -shl ($a.Length - $j - 1))) -ne 0)
            {
                #store the subset in a temp array
                $out[$j] = $a[$j]
            }
        }
        #stick subset into an array
        $l += -join $out
    }
    #group the subsets by length, iterate through them and sort
    $l | Group-Object -Property Length | %{$_.Group | sort}
}

function Set-ActiveMinerPorts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $RunningMiners
    )
    if (-not (Test-Path Variable:Global:GlobalActiveMinerPorts) -or $Global:GlobalActiveMinerPorts -eq $null) {[hashtable]$Global:GlobalActiveMinerPorts = @{}}
    $Global:GlobalActiveMinerPorts.Clear()
    if ($RunningMiners) {foreach($m in $RunningMiners) {$Global:GlobalActiveMinerPorts[$m.GetMinerDeviceName()] = $m.Port}}
}

function Set-ActiveTcpPorts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Disable = $false
    )
    if ($Disable) {$Global:GlobalActiveTcpPorts=$null;return}
    if (-not (Test-Path Variable:Global:GlobalActiveTcpPorts) -or $Global:GlobalActiveTcpPorts -eq $null) {[System.Collections.ArrayList]$Global:GlobalActiveTcpPorts = @()}
    $Global:GlobalActiveTcpPorts.Clear()
    try {
        $NewPorts = @(([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()).GetActiveTcpListeners() | Select-Object -ExpandProperty Port -Unique)
        if ($NewPorts.Count -gt 0 ) {$Global:GlobalActiveTcpPorts.AddRange($NewPorts)>$null}
        $NewPorts = $null
    } catch {if ($Error.Count){$Error.RemoveAt(0)};$Global:GlobalActiveTcpPorts=$null}
}

function Get-MinerPort{
    [cmdletbinding()]
    Param(   
        [Parameter(Mandatory = $True)]
        [string]$MinerName,
        [Parameter(Mandatory = $False)]
        [string[]]$DeviceName = @(),
        [Parameter(Mandatory = $False)]
        $Port = 30000
    )
    if (-not (Test-Path Variable:Global:GlobalActiveTcpPorts) -or $Global:GlobalActiveTcpPorts -eq $null) {return $Port}

    if ($DeviceName -and $DeviceName.Count) {$MinerName = "$($MinerName)-$(($DeviceName | Sort-Object) -join '-')"}
    if ($Global:GlobalActiveMinerPorts -and $Global:GlobalActiveMinerPorts.ContainsKey($MinerName)) {return $Global:GlobalActiveMinerPorts[$MinerName]}
    if (-not (Test-Path Variable:Global:GlobalMinerPorts)) {[hashtable]$Global:GlobalMinerPorts = @{};$API.MinerPorts = $Global:GlobalMinerPorts}
    $Port = [int]($Port -replace "[^\d]")
    $portin  = [int]$Port
    if ($Global:GlobalActiveTcpPorts.Contains($portin)) {
        $portmax = [math]::min($portin+9999,65535)
        do {$portin+=20} until ($portin -gt $portmax -or -not $Global:GlobalActiveTcpPorts.Contains($portin))
        if ($portin -gt $portmax) {$portin=[int]$Port}
    }
    if (-not $Global:GlobalMinerPorts.ContainsKey($MinerName) -or $portin -ne $Global:GlobalMinerPorts[$MinerName]) {Write-Log "Assigning port $portin to $MinerName"}
    $Global:GlobalMinerPorts[$MinerName]=$portin
    $portin
}

function Get-MemoryUsage
{
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    [Switch]$ForceFullCollection,
    [Parameter(Mandatory = $False)]
    [Switch]$Reset
)
    $memusagebyte = [System.GC]::GetTotalMemory($ForceFullCollection)
    $memdiff = $memusagebyte - [int64]$script:last_memory_usage_byte
    [PSCustomObject]@{
        MemUsage   = $memusagebyte
        MemDiff    = $memdiff
        MemText    = "Memory usage: {0:n1} MB ({1:n0} Bytes {2})" -f  ($memusagebyte/1MB), $memusagebyte, "$(if ($memdiff -gt 0){"+"})$($memdiff)"
    }
    if ($Reset) {
        $script:last_memory_usage_byte = $memusagebyte
    }
}

function Get-MD5Hash {
[cmdletbinding()]
Param(   
    [Parameter(
        Mandatory = $True,   
        Position = 0,   
        ParameterSetName = '',   
        ValueFromPipeline = $True)]   
        [string]$value
)
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = new-object -TypeName System.Text.UTF8Encoding
    [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($value))).ToUpper() -replace '-'
}

function Invoke-GetUrl {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]   
        [string]$url = "",
    [Parameter(Mandatory = $False)]   
        [string]$method = "REST",
    [Parameter(Mandatory = $False)]   
        [string]$requestmethod = "",
    [Parameter(Mandatory = $False)]
        [int]$timeout = 10,
    [Parameter(Mandatory = $False)]
        [hashtable]$body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers,
    [Parameter(Mandatory = $False)]
        [string]$user = "",
    [Parameter(Mandatory = $False)]
        [string]$password = "",
    [Parameter(Mandatory = $False)]
        [string]$useragent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36",
    [Parameter(Mandatory = $False)]
        $JobData,
    [Parameter(Mandatory = $False)]
        [string]$JobKey = "",
    [Parameter(Mandatory = $False)]
        [switch]$ForceLocal
)
    if ($JobKey -and $JobData) {
        if (-not $ForceLocal -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and (Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 1)) {
            $serverbody = @{
                url       = $JobData.url
                method    = $JobData.method
                timeout   = $JobData.timeout
                body      = $JobData.body | ConvertTo-Json -Depth 10 -Compress
                headers   = $JobData.headers | ConvertTo-Json -Depth 10 -Compress
                cycletime = $JobData.cycletime
                retry     = $JobData.retry
                retrywait = $Jobdata.retrywait
                tag       = $JobData.tag
                user      = $JobData.user
                password  = $JobData.password
                jobkey    = $JobKey
                machinename = $Session.MachineName
                myip      = $Session.MyIP
            }
            $Result = Invoke-GetUrl "http://$($Session.Config.ServerName):$($Session.Config.ServerPort)/getjob" -body $serverbody -user $Session.Config.ServerUser -password $Session.Config.ServerPassword -ForceLocal
            if ($Result.Status) {$Result.Content;Remove-Variable "Result";return}
        }

        $url      = $JobData.url
        $method   = $JobData.method
        $timeout  = $JobData.timeout
        $body     = $JobData.body
        $headers  = $JobData.headers
        $user     = $JobData.user
        $password = $JobData.password
    }

    if (-not $requestmethod) {$requestmethod = if ($body) {"POST"} else {"GET"}}
    $RequestUrl = $url -replace "{timestamp}",(Get-Date -Format "yyyy-MM-dd_HH-mm-ss")

    if (-not $headers) {$headers = @{}}
    if (-not $headers.ContainsKey("Cache-Control")) {$headers["Cache-Control"] = "no-cache"}
    if ($user) {$headers["Authorization"] = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($user):$($password)")))"}
    if ($method -eq "REST") {
        Invoke-RestMethod $RequestUrl -UseBasicParsing -DisableKeepAlive -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body
    } else {
        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest $RequestUrl -UseBasicParsing -DisableKeepAlive -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body
        $Global:ProgressPreference = $oldProgressPreference
    }
    Remove-Variable "headers"
}

function Invoke-RestMethodAsync {
[cmdletbinding()]   
Param(   
    [Parameter(Mandatory = $True)]
        [string]$url,
    [Parameter(Mandatory = $False)]   
        [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]
        [int]$retry = 0,
    [Parameter(Mandatory = $False)]
        [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]
        [string]$tag = "",
    [Parameter(Mandatory = $False)]
        [int]$delay = 0,
    [Parameter(Mandatory = $False)]
        [int]$timeout = 10,
    [Parameter(Mandatory = $False)]
        [switch]$nocache,
    [Parameter(Mandatory = $False)]
        [switch]$noquickstart,
    [Parameter(Mandatory = $False)]
        [string]$Jobkey = $null,
    [Parameter(Mandatory = $False)]
        [hashtable]$body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    Invoke-GetUrlAsync $url -method "REST" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body -headers $headers
}

function Invoke-WebRequestAsync {
[cmdletbinding()]   
Param(   
    [Parameter(Mandatory = $True)]
        [string]$url,
    [Parameter(Mandatory = $False)]
        [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]
        [int]$retry = 0,
    [Parameter(Mandatory = $False)]
        [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]
        [string]$Jobkey = $null,
    [Parameter(Mandatory = $False)]
        [string]$tag = "",
    [Parameter(Mandatory = $False)]
        [int]$delay = 0,
    [Parameter(Mandatory = $False)]
        [int]$timeout = 10,
    [Parameter(Mandatory = $False)]
        [switch]$nocache,
    [Parameter(Mandatory = $False)]
        [switch]$noquickstart,
    [Parameter(Mandatory = $False)]
        [hashtable]$body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    Invoke-GetUrlAsync $url -method "WEB" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body -headers $headers
}

function Invoke-GetUrlAsync {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]   
        [string]$url = "",
    [Parameter(Mandatory = $False)]   
        [string]$method = "REST",
    [Parameter(Mandatory = $False)]   
        [switch]$force = $false,
    [Parameter(Mandatory = $False)]   
        [switch]$quiet = $false,
    [Parameter(Mandatory = $False)]   
        [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]
        [int]$retry = 0,
    [Parameter(Mandatory = $False)]
        [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]   
        [string]$Jobkey = $null,
    [Parameter(Mandatory = $False)]
        [string]$tag = "",
    [Parameter(Mandatory = $False)]
        [int]$delay = 0,
    [Parameter(Mandatory = $False)]
        [int]$timeout = 10,
    [Parameter(Mandatory = $False)]
        [bool]$nocache = $false,
    [Parameter(Mandatory = $False)]
        [bool]$noquickstart = $false,
    [Parameter(Mandatory = $False)]
        [hashtable]$body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    if (-not $url -and -not $Jobkey) {return}

    $JobData = [PSCustomObject]@{Url=$url;Error=$null;Running=$true;Paused=$false;Method=$method;Body=$body;Headers=$headers;Success=0;Fail=0;Prefail=0;LastRequest=(Get-Date).ToUniversalTime();CycleTime=$cycletime;Retry=$retry;RetryWait=$retrywait;Tag=$tag;Timeout=$timeout}

    if (-not $Jobkey) {$Jobkey = Get-MD5Hash "$($url)$(if ($body) {$body | ConvertTo-Json -Compress})$(if ($headers) {$headers | ConvertTo-Json -Compress})";$StaticJobKey = $false} else {$StaticJobKey = $true}

    if (-not (Test-Path Variable:Global:Asyncloader)) {
        if ($delay) {Start-Sleep -Milliseconds $delay}
        Invoke-GetUrl -JobData $JobData -JobKey $JobKey
        return
    }
    
    if ($StaticJobKey -and $url -and $AsyncLoader.Jobs.$Jobkey -and ($AsyncLoader.Jobs.$Jobkey.Url -ne $url -or ($AsyncLoader.Jobs.$Jobkey.Body | ConvertTo-Json -Compress) -ne ($body | ConvertTo-Json -Compress)-or ($AsyncLoader.Jobs.$Jobkey.Headers | ConvertTo-Json -Compress) -ne ($headers | ConvertTo-Json -Compress))) {$force = $true;$AsyncLoader.Jobs.$Jobkey.Url = $url;$AsyncLoader.Jobs.$Jobkey.Body = $body;$AsyncLoader.Jobs.$Jobkey.Headers = $headers}

    if (-not (Test-Path ".\Cache")) {New-Item "Cache" -ItemType "directory" -ErrorAction Ignore > $null}

    if ($force -or -not $AsyncLoader.Jobs.$Jobkey -or $AsyncLoader.Jobs.$Jobkey.Paused -or -not (Test-Path ".\Cache\$($Jobkey).asy")) {
        $Quickstart = $false
        if (-not $AsyncLoader.Jobs.$Jobkey) {
            $Quickstart = -not $nocache -and -not $noquickstart -and $AsyncLoader.Quickstart -ne -1 -and (Test-Path ".\Cache\$($Jobkey).asy")
            if (-not $Quickstart -and $delay) {Start-Sleep -Milliseconds $delay}
            $AsyncLoader.Jobs.$Jobkey = $JobData
            if ($Quickstart) {
                $AsyncLoader.Quickstart += $delay
                if ($AsyncLoader.Quickstart -gt 0) {$AsyncLoader.Jobs.$Jobkey.LastRequest = $AsyncLoader.Jobs.$Jobkey.LastRequest.AddMilliseconds($AsyncLoader.Quickstart)}
            }
        } else {
            $AsyncLoader.Jobs.$Jobkey.Running=$true
            $AsyncLoader.Jobs.$Jobkey.LastRequest=(Get-Date).ToUniversalTime()
            $AsyncLoader.Jobs.$Jobkey.Paused=$false
        }

        $retry = $AsyncLoader.Jobs.$Jobkey.Retry + 1

        $StopWatch = New-Object -TypeName System.Diagnostics.StopWatch
        do {
            $Request = $RequestError = $null
            $StopWatch.Restart()
            try {                
                if ($Quickstart) {
                    if (-not ($Request = Get-Content ".\Cache\$($Jobkey).asy" -Raw -ErrorAction Ignore)) {
                        Remove-Item ".\Cache\$($Jobkey).asy" -Force
                        $Quickstart = $false                        
                        if ($delay -gt 0) {$AsyncLoader.Quickstart -= $delay;Start-Sleep -Milliseconds $delay}
                    }
                }
                if (-not $Quickstart) {
                    #Write-Log -Level Info "GetUrl $($AsyncLoader.Jobs.$Jobkey.Url)" 
                    $Request = Invoke-GetUrl -JobData $AsyncLoader.Jobs.$Jobkey -JobKey $JobKey
                }
                if (-not $Request) {throw "Empty request"}
                $AsyncLoader.Jobs.$Jobkey.Success++
                $AsyncLoader.Jobs.$Jobkey.Prefail=0                
            }
            catch {
                $RequestError = "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Problem fetching $($AsyncLoader.Jobs.$Jobkey.Url) using $($AsyncLoader.Jobs.$Jobkey.Method): $($_.Exception.Message)"
                if ($Error.Count){$Error.RemoveAt(0)}
                #Write-Log -Level Info "GetUrl Failed $RequestError"
            }
            finally {
                $Error.Clear()
            }
            if (-not $Quickstart) {$AsyncLoader.Jobs.$Jobkey.LastRequest=(Get-Date).ToUniversalTime()}

            $retry--
            if ($retry) {
                if (-not $RequestError) {$retry = 0}
                else {
                    $Passed = $StopWatch.ElapsedMilliseconds
                    if ($AsyncLoader.Jobs.$Jobkey.RetryWait -gt $Passed) {
                        Start-Sleep -Milliseconds ($AsyncLoader.Jobs.$Jobkey.RetryWait - $Passed)
                    }
                }
            }
        } until ($retry -le 0)

        $StopWatch.Stop()
        Remove-Variable "StopWatch"

        if ($RequestError -or -not $Request) {
            $AsyncLoader.Jobs.$Jobkey.Prefail++
            if ($AsyncLoader.Jobs.$Jobkey.Prefail -gt 5) {$AsyncLoader.Jobs.$Jobkey.Fail++;$AsyncLoader.Jobs.$Jobkey.Prefail=0}            
        } elseif (-not $Quickstart) {
            $Request | ConvertTo-Json -Compress -Depth 10 | Out-File ".\Cache\$($Jobkey).asy" -Encoding utf8 -ErrorAction Ignore -Force
        }
        if ($Request) {Remove-Variable "Request"}
        if (-not (Test-Path ".\Cache\$($Jobkey).asy")) {New-Item ".\Cache\$($Jobkey).asy" -ItemType File > $null}
        $AsyncLoader.Jobs.$Jobkey.Error = $RequestError
        $AsyncLoader.Jobs.$Jobkey.Running = $false
        $Error.Clear()
    }
    if (-not $quiet) {
        if ($AsyncLoader.Jobs.$Jobkey.Error -and $AsyncLoader.Jobs.$Jobkey.Prefail -eq 0) {
            if (Test-Path ".\Cache\$($Jobkey).asy") {Write-Log -Level Warn $AsyncLoader.Jobs.$Jobkey.Error} else {throw $AsyncLoader.Jobs.$Jobkey.Error}
        }
        if (Test-Path ".\Cache\$($Jobkey).asy") {
            try {Get-Content ".\Cache\$($Jobkey).asy" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore;throw "Job $Jobkey contains clutter."}
        }
    }
}

function Get-MinerStatusKey {    
    try {
        $Response = Invoke-GetUrl "https://rbminer.net/api/getuserid.php"
        if ($Response) {$Response = $Response -split "[\r\n]+" | select-object -first 1}
        Write-Log "Miner Status key created: $Response"
        $Response
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Miner Status $($Session.Config.MinerStatusURL) has failed. "
    }
}

function Invoke-ReportMinerStatus {

    if (-not $Session.Config.MinerStatusURL -or -not $Session.Config.MinerStatusKey) {return}

    $Version = "RainbowMiner $($Session.Version.ToString())"
    $Status = if ($Session.Paused) {"Paused"} elseif (-not $Session.Profitable) {"Waiting"} else {"Running"}
    $Rates = [PSCustomObject]@{}
    $Session.Rates.Keys | Where-Object {$Session.Config.Currency -icontains $_} | Foreach-Object {$Rates | Add-Member $_ $Session.Rates.$_ -Force}

    Write-Log "Pinging monitoring server. "

    $Profit = 0.0
    $PowerDraw = 0.0
    $TempAlert = 0

    $minerreport = ConvertTo-Json @(
        $Session.ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {
            $Miner = $_
            $Miner.Speed_Live = [Double[]]@()           
            $Miner.Algorithm | ForEach-Object {
                $Miner_Speed = $Miner.GetHashRate($_,$false)
                $Miner.Speed_Live += [Double]$Miner_Speed
            }
            $Miner_PowerDraw = $Miner.GetPowerDraw()

            $Profit += [Double]$Miner.Profit
            $PowerDraw += [Double]$Miner_PowerDraw

            $Devices = @()
            Get-Device $Miner.DeviceName | Foreach-Object {
                if ($_.Type -eq "GPU") {
                    if ($_.Data.Temperature -gt $Session.Config.MinerStatusMaxTemp) {$TempAlert++}
                    $Devices += [PSCustomObject]@{
                        Id    = $_.Type_PlatformId_Index
                        Name  = $_.Model
                        Mem   = [int]($_.OpenCL.GlobalMemSize / 1GB)
                        Temp  = $_.Data.Temperature
                        Fan   = $_.Data.FanSpeed
                        Watt  = $_.Data.PowerDraw
                        Core  = $_.Data.Clock
                        MemC  = $_.Data.ClockMem
                        MaxTemp = $_.DataMax.Temperature
                    }
                } else {
                    $Devices += [PSCustomObject]@{
                        Id    = $_.Type_PlatformId_Index
                        Name  = $_.Model_Name
                        Watt  = $_.Data.PowerDraw
                    }
                }
            }

            # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
            [PSCustomObject]@{
                Name           = $Miner.BaseName
                Version        = $Miner.Version
                Path           = Resolve-Path -Relative $Miner.Path
                Type           = @($Miner.DeviceModel)
                Active         = "{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $Miner.GetActiveTime()
                Algorithm      = @($Miner.BaseAlgorithm)
                Currency       = $Miner.Currency
                CoinName       = @($Miner.CoinName | Where-Object {$Miner} | Select-Object)
                CoinSymbol     = @($Miner.CoinSymbol | Where-Object {$Miner} | Select-Object)
                Pool           = @($Miner.Pool)
                CurrentSpeed   = @($Miner.Speed_Live)
                EstimatedSpeed = @($Miner.Speed)
                PowerDraw      = $Miner_PowerDraw
                'BTC/day'      = $Miner.Profit
                Profit         = $Miner.Profit
                Donator        = $Miner.Donator
                Benchmarking   = $Miner.Speed -contains $null
                Devices        = $Devices
            }
        }
    ) -Depth 10 -Compress
    
    $Profit = [Math]::Round($Profit, 8) | ConvertTo-Json
    $PowerDraw = [Math]::Round($PowerDraw, 2) | ConvertTo-Json

    $Pool_Totals = if ($Session.ReportTotals) {
        Set-TotalsAvg
        try {
            $Session.ReportTotals = $false

            $Pool_Stats = Get-Stat -TotalAvgs
            $Earn_Stats = Get-Stat -Balances

            if ($Pool_Stats) {
                $Pool_Stats_Consolidated = @{}
                $Pool_Stats.GetEnumerator() | Foreach-Object {
                    $StatName = $_.Name -replace "(Coins|Party|Solo)_","_"
                    if ($Pool_Stats_Consolidated.ContainsKey($StatName)) {
                        $Pool_Stats_Consolidated[$StatName].Profit_Avg += $_.Value.Profit_Avg
                        $Pool_Stats_Consolidated[$StatName].ProfitApi_Avg += $_.Value.ProfitApi_Avg
                        $Pool_Stats_Consolidated[$StatName].Cost_Avg += $_.Value.Cost_Avg
                        $Pool_Stats_Consolidated[$StatName].Power_Avg += $_.Value.Power_Avg
                    } else {
                        $Pool_Stats_Consolidated[$StatName] = [PSCustomObject]@{
                            Pool = $_.Value.Pool -replace "(Coins|Party|Solo)$"
                            Profit_Avg = $_.Value.Profit_Avg
                            ProfitApi_Avg = $_.Value.ProfitApi_Avg
                            Cost_Avg = $_.Value.Cost_Avg
                            Power_Avg = $_.Value.Power_Avg
                        }
                    }
                }

                $Pool_Stats_Consolidated.GetEnumerator() | Foreach-Object {
                    $PoolName = $_.Value.Pool                    
                    [PSCustomObject]@{
                        Name      = $PoolName
                        Profit    = "$([Math]::Round($_.Value.Profit_Avg,5))"
                        ProfitApi = "$([Math]::Round($_.Value.ProfitApi_Avg,5))"
                        Cost      = "$([Math]::Round($_.Value.Cost_Avg,5))"
                        Power     = "$([Math]::Round($_.Value.Power_Avg,2))"
                        Earnings  = "$(if ($Earn_Stats) {[Math]::Round(($Earn_Stats.GetEnumerator() | Where-Object {$_.Value.PoolName -eq $PoolName -and $Session.Rates."$($_.Value.Currency)"} | Foreach-Object {$_.Value.Earnings_Avg / $Session.Rates."$($_.Value.Currency)"} | Measure-Object -Sum).Sum *1e8,5)} else {0})"
                    }
                } | Where-Object {$_.Profit -gt 0 -and $_.Earnings -gt 0}
            }

            if ($Pool_Stats) {Remove-Variable "Pool_Stats" -Force}
            if ($Earn_Stats) {Remove-Variable "Earn_Stats" -Force}
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Miner Status get pool stats has failed. "
        }
    }

    if (Test-Path ".\Data\reportapi.json") {try {$ReportAPI = Get-Content ".\Data\reportapi.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)};$ReportAPI=$null}}
    if (-not $ReportAPI) {$ReportAPI = @([PSCustomObject]@{match    = "rbminer.net";apiurl   = "https://rbminer.net/api/report.php"})}

    # Send the request
    try {
        $ReportUrl = $Session.Config.MinerStatusURL
        $ReportStatus = "Error"
        $ReportDone = $false

        $ReportInterval = if ($Session.CurrentInterval -gt $Session.Config.Interval -and $Session.CurrentInterval -gt $Session.Config.BenchmarkInterval) {$Session.CurrentInterval} else {$Session.Config.BenchmarkInterval}

        $ReportAPI | Where-Object {-not $ReportDone -and $ReportUrl -match $_.match} | Foreach-Object {
            $ReportUrl = $_.apiurl
            $Response = Invoke-GetUrl $ReportUrl -body @{user = $Session.Config.MinerStatusKey; email = $Session.Config.MinerStatusEmail; pushoverkey = $Session.Config.PushOverUserKey; worker = $Session.Config.WorkerName; machinename = $Session.MachineName; machineip = $Session.MyIP; cpu = "$($Session.DevicesByTypes.CPU.Model_Name | Select-Object -Unique)";version = $Version; status = $Status; profit = "$Profit"; powerdraw = "$PowerDraw"; earnings_avg = "$($Session.Earnings_Avg)"; earnings_1d = "$($Session.Earnings_1d)"; pool_totals = ConvertTo-Json @($Pool_Totals | Select-Object) -Compress; minerdata = "$(if ($Session.ReportMinerData -and (Test-Path ".\Data\minerdata.json")) {Get-Content ".\Data\minerdata.json" -Raw -ErrorAction Ignore};$Session.ReportMinerData=$false)"; poolsdata = "$(if ($Session.ReportPoolsData -and (Test-Path ".\Data\poolsdata.json")) {Get-Content ".\Data\poolsdata.json" -Raw -ErrorAction Ignore};$Session.ReportPoolsData=$false)"; rates = ConvertTo-Json $Rates -Compress; interval = $ReportInterval; uptime = "$((Get-Uptime).TotalSeconds)"; sysuptime = "$((Get-Uptime -System).TotalSeconds)";maxtemp = "$($Session.Config.MinerStatusMaxTemp)"; tempalert=$TempAlert; data = $minerreport}
            if ($Response -is [string] -or $Response.Status -eq $null) {$ReportStatus = $Response -split "[\r\n]+" | select-object -first 1}
            else {
                $ReportStatus = $Response.Status
                if ($Response.Actions -ne $null) {
                    $Response.Actions | Foreach-Object {
                        $Action = $_
                        # do something :)
                        Write-Log "Executing action `"$($Action.Action)`""
                        Switch($Action.Action) {
                            "resetneededbenchmarks" {
                                $Action_Response = & ".\web\scripts\resetneededbenchmarks"
                                $Action_Response = $Action_Response | Where-Object {$_ -and $_ -notmatch "<.+?>"}
                             }
                        }                        
                    }
                }
                if ($Response.Workers -ne $null) {
                    $API.RemoteMiners = ConvertTo-Json @($Response.Workers | Where-Object worker -ne $Session.Config.WorkerName | Select-Object) -Depth 10
                }
                if ($Response.Compare -ne $null) {
                    $API.CompareMiners = ConvertTo-Json @($Response.Compare  | Select-Object) -Depth 10
                }
            }
            $ReportDone = $true
        }
        if (-not $ReportDone) {
            $Response = Invoke-GetUrl $ReportUrl -Body @{address = $Session.Config.MinerStatusKey; workername = $Session.Config.WorkerName; version = $Version; status = $Status; profit = $Profit; miners = $minerreport}
            if ($Response) {$ReportStatus = $Response -split "[\r\n]+" | select-object -first 1} 
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Info "Miner Status $($ReportUrl) has failed. "
    }
    if ($Pool_Totals -ne $null) {Remove-Variable "Pool_Totals"}
}

function Initialize-User32Dll {
    try {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace User32
{
    public class WindowManagement {
        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")]
        public static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, IntPtr lclassName, string windowTitle);
        [DllImport("user32.dll")] 
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    }
}
"@
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Error initializing User32.dll functions"
    }
}

function Get-WindowState {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $False)]
    [int64]$Id = $PID,
    [Parameter(Mandatory = $False)]
    [String]$Title = ""
)
    Initialize-User32Dll
    try {
        $hwnd = (ps -Id $Id)[0].MainWindowHandle
        if ($hwnd -eq 0) {
            $zero = [IntPtr]::Zero
            $hwnd = [User32.WindowManagement]::FindWindowEx($zero,$zero,$zero,$Title)
        }
        $state = [User32.WindowManagement]::GetWindowLong($hwnd, -16)
        # mask of 0x20000000 = minimized; 2 = minimize; 4 = restore
        if ($state -band 0x20000000)    {"minimized"}
        elseif ($state -band 0x1000000) {"maximized"}
        else                            {"normal"}
    } catch {if ($Error.Count){$Error.RemoveAt(0)};"maximized"}
}

function Set-WindowStyle {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $Style = 'SHOW',
    [Parameter(Mandatory = $False)]
    [int64]$Id = $PID,
    [Parameter(Mandatory = $False)]
    [String]$Title = ""
)
    $WindowStates = @{
        FORCEMINIMIZE   = 11; HIDE            = 0
        MAXIMIZE        = 3;  MINIMIZE        = 6
        RESTORE         = 9;  SHOW            = 5
        SHOWDEFAULT     = 10; SHOWMAXIMIZED   = 3
        SHOWMINIMIZED   = 2;  SHOWMINNOACTIVE = 7
        SHOWNA          = 8;  SHOWNOACTIVATE  = 4
        SHOWNORMAL      = 1
    }
    Initialize-User32Dll
    try {
        $hwnd = (ps -Id $Id)[0].MainWindowHandle
        if ($hwnd -eq 0) {
            $zero = [IntPtr]::Zero
            $hwnd = [User32.WindowManagement]::FindWindowEx($zero,$zero,$zero,$Title)
        }
        [User32.WindowManagement]::ShowWindowAsync($hwnd, $WindowStates[$Style])>$null        
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
}

function Get-NtpTime {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [String]$NTPServer = "time.google.com",
    [Parameter(Mandatory = $False)]
    [Switch]$Quiet = $false
)

    $NTPData    = New-Object byte[] 48  # Array of 48 bytes set to zero
    $NTPData[0] = 27                    # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

    try {
        $Socket = New-Object Net.Sockets.Socket ( 'InterNetwork', 'Dgram', 'Udp' )
        $Socket.SendTimeOut    = 2000  # ms
        $Socket.ReceiveTimeOut = 2000  # ms
        $Socket.Connect( $NTPServer, 123 )
        $Null = $Socket.Send(    $NTPData )
        $Null = $Socket.Receive( $NTPData )
        $Socket.Shutdown( 'Both' )
        $Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "Could not read time from $($NTPServer)"
    }
    finally {
        if ($Socket) {$Socket.Close();$Socket.Dispose()}
    }

    if ($Seconds) {( [datetime]'1/1/1900' ).AddSeconds( $Seconds ).ToLocalTime()} else {Get-Date}
}

function Get-UnixTimestamp {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [DateTime]$DateTime = [DateTime]::UtcNow,
    [Parameter(Mandatory = $False)]
    [Switch]$Milliseconds = $false
)
    [Math]::Floor(($DateTime - [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc'))."$(if ($Milliseconds) {"TotalMilliseconds"} else {"TotalSeconds"})" - $(if ($Milliseconds) {1000} else {1})*[int]$Session.TimeDiff)
}

function Get-UnixToUTC {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [Int64]$UnixTimestamp = 0
)
    [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc') + ([TimeSpan]::FromSeconds($UnixTimestamp))
}

function Get-Zip {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [String]$s = ""
)
    if (-not $s) {return ""}
    try {
        $ms = New-Object System.IO.MemoryStream
        $cs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
        $sw = New-Object System.IO.StreamWriter($cs)
        $sw.Write($s)
        $sw.Close();
        [System.Convert]::ToBase64String($ms.ToArray())
    } catch {if ($Error.Count){$Error.RemoveAt(0)};$s}
}

function Get-Unzip {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [String]$s = ""
)
    if (-not $s) {return ""}
    try {
        $data = [System.Convert]::FromBase64String($s)
        $ms = New-Object System.IO.MemoryStream
        $ms.Write($data, 0, $data.Length)
        $ms.Seek(0,0) | Out-Null
        $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress))
        $sr.ReadToEnd()
        $sr.Close()
    } catch {if ($Error.Count){$Error.RemoveAt(0)};$s}
}

function Get-UrlEncode {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [string]$Uri = "",
    [Parameter(Mandatory = $false)]
    [switch]$ConvertDot = $false
)
    $Uri2 = @()
    while ($Uri -match "^(.*?)({[^}]+})(.*?)$") {
        if ($Matches[1].Length) {$Uri2+=[System.Web.HttpUtility]::UrlEncode($Matches[1])}
        $Tmp=$Matches[2]
        $Uri=$Matches[3]
        if ($Tmp -match "^{(\w+):(.*?)}$") {$Tmp = "{$($Matches[1]):$([System.Web.HttpUtility]::UrlEncode($($Matches[2] -replace "\$","*dollar*")) -replace "\*dollar\*","$")}"}
        $Uri2+=$Tmp
    }
    if ($Uri.Length) {$Uri2+=[System.Web.HttpUtility]::UrlEncode($Uri)}
    $Uri = $Uri2 -join ''
    if ($ConvertDot) {$Uri -replace "\.","%2e"} else {$Uri}
}

function Get-LastDrun {
    if (Test-Path ".\Data\lastdrun.json") {try {[DateTime](Get-Content ".\Data\lastdrun.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop).lastdrun} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
}

function Set-LastDrun {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [DateTime]$Timer = (Get-Date).ToUniversalTime()
)
    $Timer = $Timer.ToUniversalTime();Set-ContentJson -Data ([PSCustomObject]@{lastdrun=[DateTime]$Timer}) -PathToFile ".\Data\lastdrun.json" > $null;$Timer
}

function Get-LastStartTime {
    if (Test-Path ".\Data\starttime.json") {
        try {[DateTime](Get-Content ".\Data\starttime.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop).starttime} catch {if ($Error.Count){$Error.RemoveAt(0)}}
        Remove-Item ".\Data\starttime.json" -Force -ErrorAction Ignore
    }
}

function Set-LastStartTime {
    Set-ContentJson -Data ([PSCustomObject]@{starttime=[DateTime]$Session.StartTime}) -PathToFile ".\Data\starttime.json" > $null
}

function Start-Autoexec {
[cmdletbinding()]
param(
    [ValidateRange(-2, 3)]
    [Parameter(Mandatory = $false)]
    [Int]$Priority = 0
)
    if (-not (Test-Path ".\Config\autoexec.txt") -and (Test-Path ".\Data\autoexec.default.txt")) {Copy-Item ".\Data\autoexec.default.txt" ".\Config\autoexec.txt" -Force -ErrorAction Ignore}
    [System.Collections.ArrayList]$Script:AutoexecCommands = @()
    foreach($cmd in @(Get-Content ".\Config\autoexec.txt" -ErrorAction Ignore | Select-Object)) {
        if ($cmd -match "^[\s\t]*`"(.+?)`"(.*)$") {
            if (Test-Path $Matches[1]) {
                try {
                    $Job = Start-SubProcess -FilePath "$($Matches[1])" -ArgumentList "$($Matches[2].Trim())" -WorkingDirectory (Split-Path "$($Matches[1])") -ShowMinerWindow $true -Priority $Priority
                    if ($Job) {
                        $Job | Add-Member FilePath "$($Matches[1])" -Force
                        $Job | Add-Member Arguments "$($Matches[2].Trim())" -Force
                        $Job | Add-Member HasOwnMinerWindow $true -Force
                        Write-Log "Autoexec command started: $($Matches[1]) $($Matches[2].Trim())"
                        $Script:AutoexecCommands.Add($Job) >$null
                    }
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "Command could not be started in autoexec.txt: $($Matches[1]) $($Matches[2])"
                }
            } else {
                Write-Log -Level Warn "Command not found in autoexec.txt: $($Matches[1])"
            }
        }
    }
}

function Stop-Autoexec {
    $Script:AutoexecCommands | Where-Object Process | Foreach-Object {
        Stop-SubProcess -Job $_ -Title "Autoexec command" -Name "$($_.FilePath) $($_.Arguments)"
    }
}

function Invoke-PingStratum {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [String]$Server,
    [Parameter(Mandatory = $True)]
    [Int]$Port,
    [Parameter(Mandatory = $False)]
    [String]$User="",
    [Parameter(Mandatory = $False)]
    [String]$Pass="x",
    [Parameter(Mandatory = $False)]
    [String]$Worker=$Session.Config.WorkerName,
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 3,
    [Parameter(Mandatory = $False)]
    [bool]$WaitForResponse = $False,
    [Parameter(Mandatory = $False)]
    [ValidateSet("Stratum","EthProxy")]
    [string]$Method = "Stratum"
)    
    $Request = if ($Method -eq "EthProxy") {"{`"id`": 1, `"method`": `"login`", `"params`": {`"login`": `"$($User)`", `"pass`": `"$($Pass)`", `"rigid`": `"$($Worker)`", `"agent`": `"RainbowMiner/$($Session.Version)`"}}"} else {"{`"id`": 1, `"method`": `"mining.subscribe`", `"params`": [`"RainbowMiner/$($Session.Version)`"]}"}
    try {
        if ($WaitForResponse) {
            $Result = Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -Quiet
            if ($Result) {
                $Result = ConvertFrom-Json $Result -ErrorAction Stop
                if ($Result.id -eq 1 -and -not $Result.error) {$true}
            }
        } else {
            Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -Quiet -WriteOnly > $null
            $true
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
}

function Get-NvidiaSmi {
    $Command =  if ($IsLinux) {"nvidia-smi"}
                elseif ($Session.Config.NVSMIpath -and (Test-Path ($NVSMI = Join-Path $Session.Config.NVSMIpath "nvidia-smi.exe"))) {$NVSMI}
                else {".\Includes\nvidia-smi.exe"}
    if (Get-Command $Command -ErrorAction Ignore) {$Command}
}

function Invoke-NvidiaSmi {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $False)]
    [String[]]$Query = @(),
    [Parameter(Mandatory = $False)]
    [String[]]$Arguments = @(),
    [Parameter(Mandatory = $False)]
    [Switch]$Runas
)
    if (-not ($NVSMI = Get-NvidiaSmi)) {return}

    if ($Query) {
        $Arguments += @(
            "--query-gpu=$($Query -join ',')"
            "--format=csv,noheader,nounits"
        )
        $CsvParams =  @{Header = @($Query | Foreach-Object {$_ -replace "[^a-z_-]","_" -replace "_+","_"} | Select-Object)}
        Invoke-Exe -FilePath $NVSMI -ArgumentList ($Arguments -join ' ') -ExcludeEmptyLines -ExpandLines -Runas:$Runas | ConvertFrom-Csv @CsvParams | Foreach-Object {
            $obj = $_
            $obj.PSObject.Properties.Name | Foreach-Object {
                $v = $obj.$_
                if ($v -match '(error|supported)') {$v = $null}
                elseif ($_ -match "^(clocks|fan|index|memory|temperature|utilization)") {
                    $v = $v -replace "[^\d\.]"
                    if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") {$v = $null}
                    else {$v = [int]$v}
                }
                elseif ($_ -match "^(power)") {
                    $v = $v -replace "[^\d\.]"
                    if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") {$v = $null}
                    else {$v = [double]$v}
                }
                $obj.$_ = $v
            }
            $obj
        }
    } else {
        if ($IsLinux -and $Runas -and (Test-OCDaemon)) {
            Set-OCDaemon "$NVSMI $($Arguments -join ' ')" -OnEmptyAdd "export CUDA_DEVICE_ORDER=PCI_BUS_ID"
        } else {
            Invoke-Exe -FilePath $NVSMI -ArgumentList ($Arguments -join ' ') -ExcludeEmptyLines -ExpandLines -Runas:$Runas
        }
    }
}

function Set-NvidiaPowerLimit {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [Int[]]$Device,
    [Parameter(Mandatory = $true)]
    [Int[]]$PowerLimitPercent

)
    if (-not $PowerLimitPercent.Count -or -not $Device.Count) {return}
    try {
        While ($PowerLimitPercent.Count -lt $Device.Count) {$PowerLimitPercent += $PowerLimitPercent | Select-Object -Last 1}
        for($i=0;$i -lt $Device.Count;$i++) {$Device[$i] = [int]$Device[$i]}
        Invoke-NvidiaSmi "index","power.default_limit","power.min_limit","power.max_limit","power.limit" -Arguments "-i $($Device -join ',')" | Where-Object {$_.index -match "^\d+$"} | Foreach-Object {
            $index = $Device.IndexOf([int]$_.index)
            if ($index -ge 0) {
                $PLim = [Math]::Round([double]($_.power_default_limit -replace '[^\d,\.]')*($PowerLimitPercent[$index]/100),2)
                $PCur = [Math]::Round([double]($_.power_limit -replace '[^\d,\.]'))
                if ($lim = [int]($_.power_min_limit -replace '[^\d,\.]')) {$PLim = [Math]::max($PLim, $lim)}
                if ($lim = [int]($_.power_max_limit -replace '[^\d,\.]')) {$PLim = [Math]::min($PLim, $lim)}
                if ($PLim -ne $PCur) {
                    Invoke-NvidiaSmi -Arguments "-i $($_.index)","-pl $($Plim.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture))" -Runas > $null
                }
            }
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
}

function Reset-Vega {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String[]]$DeviceName
)
    if (-not $IsWindows) {return}
    $Device = $Session.DevicesByTypes.AMD | Where-Object {$DeviceName -icontains $_.Name -and $_.Model -match "Vega"}
    if ($Device) {
        $DeviceId   = $Device.Type_Vendor_Index -join ','
        $PlatformId = $Device | Select -Property Platformid -Unique -ExpandProperty PlatformId
        $Arguments = "--opencl $($PlatformId) --gpu $($DeviceId) --hbcc %onoff% --admin fullrestart"
        try {
            Invoke-Exe ".\Includes\switch-radeon-gpu.exe" -ArgumentList ($Arguments -replace "%onoff%","on") -AutoWorkingDirectory >$null
            Start-Sleep 1
            Invoke-Exe ".\Includes\switch-radeon-gpu.exe" -ArgumentList ($Arguments -replace "%onoff%","off") -AutoWorkingDirectory >$null
            Start-Sleep 1
            Write-Log -Level Info "Disabled/Enabled device(s) $DeviceId"
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Failed to disable/enable device(s) $($DeviceId): $($_.Exception.Message)"
        }
    }
}

function Test-Internet {
    try {
        if (Get-Command "Test-Connection" -ErrorAction Ignore) {
            $oldProgressPreference = $Global:ProgressPreference
            $Global:ProgressPreference = "SilentlyContinue"
            Foreach ($url in @("www.google.com","www.amazon.com","www.baidu.com","www.coinbase.com","www.rbminer.net")) {if (Test-Connection -ComputerName $url -Count 1 -ErrorAction Ignore -Quiet -InformationAction Ignore) {$true;break}}
            $Global:ProgressPreference = $oldProgressPreference
        } elseif (Get-Command "Get-NetConnectionProfile" -ErrorAction Ignore) {
            (Get-NetConnectionProfile -IPv4Connectivity Internet | Measure-Object).Count -gt 0
        } else {
            $true
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)};$true}
}

function Wait-UntilTrue
{
    [CmdletBinding()]
    param (
        [ScriptBlock]$sb,
        [int]$TimeoutInMilliseconds = 10000,
        [int]$IntervalInMilliseconds = 1000
        )
    # Get the current time
    $startTime = [DateTime]::Now

    # Loop until the script block evaluates to true
    while (-not ($sb.Invoke())) {
        # If the timeout period has passed, return false
        if (([DateTime]::Now - $startTime).TotalMilliseconds -gt $timeoutInMilliseconds) {
            return $false
        }
        # Sleep for the specified interval
        Start-Sleep -Milliseconds $intervalInMilliseconds
    }
    return $true
}

function Wait-FileToBePresent
{
    [CmdletBinding()]
    param (
        [string]$File,
        [int]$TimeoutInSeconds = 10,
        [int]$IntervalInMilliseconds = 100
    )

    Wait-UntilTrue -sb { Test-Path $File } -TimeoutInMilliseconds ($TimeoutInSeconds*1000) -IntervalInMilliseconds $IntervalInMilliseconds > $null
}

function Test-IsElevated
{
    if ($IsWindows) {
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    } else {
        (whoami) -match "root"
    }
}

function Set-OsFlags {
    if ($IsWindows -eq $null) {
        $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
        $Global:IsLinux   = -not $Global:IsWindows
        $Global:IsMacOS   = $false
    }
}

function Get-RandomFileName
{
    [System.IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetRandomFileName())
}

function Get-MinerInstPath {
    [CmdletBinding()]
    param (
        [string]$Path
    )
    if ($Path -match "^(\.[/\\]Bin[/\\][^/\\]+)") {$Matches[1]}
    else {
        if (-not (Test-Path Variable:Global:MinersInstallationPath)) {$Global:MinersInstallationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Bin")}
        if ($Path.StartsWith($Global:MinersInstallationPath) -and $Path.Substring($Global:MinersInstallationPath.Length) -match "^([/\\][^/\\]+)") {"$($Global:MinersInstallationPath)$($Matches[1])"}
        else {Split-Path $Path}
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
                    "CPU" {$Ports | Where-Object {$mCPU -and $_.$descField -match $mCPU} | Select-Object -First 1}
                    "GPU" {$Ports | Where-Object {$mGPU -and $_.$descField -match $mGPU} | Select-Object -First 1}
                    "RIG" {$Ports | Where-Object {$mRIG -and $_.$descField -match $mRIG} | Select-Object -First 1}
                }
                if (-not $Port) {$Port = $Ports | Select-Object -First 1}
                $result | Add-Member $PortType $Port.$portField -Force
            }
            $result
        } else {$false}
    }
}

function Get-LastSatPrice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [String]$Currency = "",
        [Parameter(Mandatory = $False)]
        [Double]$lastSatPrice = 0
    )

    if ($Session.Rates.$Currency -and -not $lastSatPrice) {$lastSatPrice = 1/$Session.Rates.$Currency*1e8}
    if (-not $Session.Rates.$Currency -and $lastSatPrice) {$Session.Rates.$Currency = 1/$lastSatPrice*1e8}
    $lastSatPrice
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

    $timestamp24h = $timestamp - 24*3600

    $diffLive     = [decimal]$Request.$NetworkField.difficulty
    $reward       = if ($Request.$NetworkField.reward) {[decimal]$Request.$NetworkField.reward} else {[decimal]$Request.$LastblockField.reward}
    $profitLive   = if ($diffLive) {86400/$diffLive*$reward/$Divisor} else {0}
    if ($Request.config.coinUnits -and -not $forceCoinUnits) {$coinUnits = [decimal]$Request.config.coinUnits}
    $amountLive   = $profitLive / $coinUnits

    if (-not $Currency) {$Currency = $Request.config.symbol}
    if (-not $chartCurrency -and $Request.config.priceCurrency) {$chartCurrency = $Request.config.priceCurrency}

    $lastSatPrice = if ($Session.Rates.$Currency) {1/$Session.Rates.$Currency*1e8} else {0}

    if (-not $priceFromSession -and -not $lastSatPrice) {
        if     ($Request.price.btc)           {$lastSatPrice = 1e8*[decimal]$Request.price.btc}
        elseif ($Request.coinPrice.priceSats) {$lastSatPrice = [decimal]$Request.coinPrice.priceSats}
        elseif ($Request.coinPrice.price)     {$lastSatPrice = 1e8*[decimal]$Request.coinPrice.price}
        elseif ($Request.coinPrice."coin-btc"){$lastSatPrice = 1e8*[decimal]$Request.coinPrice."coin-btc"}
        else {
            $lastSatPrice = if ($Request.charts.price) {[decimal]($Request.charts.price | Select-Object -Last 1)[1]} else {0}
            if ($chartCurrency -and $chartCurrency -ne "BTC" -and $Session.Rates.$chartCurrency) {$lastSatPrice *= 1e8/$Session.Rates.$chartCurrency}
            elseif ($chartCurrency -eq "BTC" -and $lastSatPrice -lt 1.0) {$lastSatPrice*=1e8}
            if (-not $lastSatPrice -and $Session.Rates.$Currency) {$lastSatPrice = 1/$Session.Rates.$Currency*1e8}
        }
    }

    $rewards.Live.reward = $amountLive * $lastSatPrice        

    if ($addDay) {
        $averageDifficulties = if ($Request.pool.stats.diffs.wavg24h) {$Request.pool.stats.diffs.wavg24h} elseif ($Request.charts.difficulty_1d) {$Request.charts.difficulty_1d} else {($Request.charts.difficulty | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average}
        if ($averageDifficulties) {
            $averagePrices = if ($Request.charts.price_1d) {$Request.charts.price_1d} elseif ($Request.charts.price) {($Request.charts.price | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average} else {0}
            if ($chartCurrency -and $chartCurrency -ne "BTC" -and $Session.Rates.$chartCurrency) {$averagePrices *= 1e8/$Session.Rates.$chartCurrency}
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
        $rewards.BLK = [int]$($(if ($blocks_measure.Count -gt 1 -and ($blocks_measure.Maximum - $blocks_measure.Minimum)) {24*3600/($blocks_measure.Maximum - $blocks_measure.Minimum)} else {1})*$blocks_measure.Count)
        $rewards.TSL = if ($blocks.Count) {$timestamp - $blocks[0]}
    }
    $rewards
}

function Get-HourMinStr {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string]$Str,
        [Parameter(Mandatory = $False)]
        [switch]$to,
        [Parameter(Mandatory = $False)]
        [switch]$addseconds
    )
    $add = 0
    if ($Str -match "p") {$add = 12}
    $Str = $Str -replace "[^\d:]+"
    $Str = if ($Str -match "^\d+$") {"{0:d2}:{1}" -f (([int]$Str+$add) % 24),$(if ($to) {"59:59"} else {"00:00"})}
    elseif ($Str -match "^(\d+):(\d+)") {"{0:d2}:{1:d2}:{2}" -f (([int]$Matches[1]+$add) % 24),([int]$Matches[2] % 60),$(if ($to) {"59"} else {"00"})}
    elseif ($to) {"23:59:59"}
    else {"00:00:00"}
    if (-not $addseconds) {$Str.Substring(0,5)} else {$Str}
}

function Get-Uptime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [switch]$System
    )
    if ($System) {
        try {
            if ($IsWindows) {
                (Get-Date) - (Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime)
            } elseif ($IsLinux) {
                New-TimeSpan -Seconds ([double]((cat /proc/uptime) -split "\s+" | Select-Object -First 1))
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not get system uptime: $($_.Exception.Message)"
            $System = $false
        }
    }
    if (-not $System) {
        (Get-Date).ToUniversalTime() - $Session.StartTime
    }
}

function Get-ReadableHex32 {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    [String]$key
)
    if ($key.Length % 32) {
        $key
    } else {
        $s = ""
        for ($i=0; $i -lt $key.Length; $i+=32) {$s+="$($key.Substring($i,8))-$($key.Substring($i+4,4))-$($key.Substring($i+8,4))-$($key.Substring($i+12,4))-$($key.Substring($i+16,12))"}
        $s
    }
}

function Invoke-NHRequest {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $False)]
    [String]$key,
    [Parameter(Mandatory = $False)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    [String]$organizationid,
    [Parameter(Mandatory = $False)]
    $params = @{},
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://api2.nicehash.com",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0,
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal
)
    #autofix key/secret/organizationid
    if ($key) {$key = Get-ReadableHex32 $key}
    if ($secret) {$secret = Get-ReadableHex32 $secret}
    if ($organizationid) {$organizationid = Get-ReadableHex32 $organizationid}

    $keystr = Get-MD5Hash "$($endpoint)$($params | ConvertTo-Json -Depth 10 -Compress)"
    if (-not (Test-Path Variable:Global:NHCache)) {$Global:NHCache = [hashtable]::Synchronized(@{})}
    if (-not $Cache -or -not $Global:NHCache[$keystr] -or -not $Global:NHCache[$keystr].request -or $Global:NHCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

       $Remote = $false

       if (-not $ForceLocal -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and (Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 1)) {
            $serverbody = @{
                endpoint  = $endpoint
                key       = $key
                secret    = $secret
                orgid     = $organizationid
                params    = $params | ConvertTo-Json -Depth 10 -Compress
                method    = $method
                base      = $base
                timeout   = $timeout
                machinename = $Session.MachineName
                workername  = $Session.Config.Workername
                myip      = $Session.MyIP
            }
            try {
                $Result = Invoke-GetUrl "http://$($Session.Config.ServerName):$($Session.Config.ServerPort)/getnh" -body $serverbody -user $Session.Config.ServerUser -password $Session.Config.ServerPassword -ForceLocal
                if ($Result.Status) {$Request = $Result.Content;$Remote = $true}
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "Nicehash server call: $($_.Exception.Message)"
            }
            Remove-Variable "Result" -ErrorAction Ignore -Force
        }

        if (-not $Remote -and $key -and $secret -and $organizationid) {
            $uuid = [string]([guid]::NewGuid())
            $timestamp = Get-UnixTimestamp -Milliseconds
            #$timestamp_nh = Invoke-GetUrl "$($base)/main/api/v2/time" -timeout $Timeout | Select-Object -ExpandProperty serverTime
            #if ([Math]::Abs($timestamp_nh - $timestamp) -gt 3000) {$timestamp = $timestamp_nh}
            $paramstr = "$(($params.GetEnumerator() | Foreach-Object {"$($_.Name)=$([System.Web.HttpUtility]::UrlEncode($_.Value))"}) -join '&')"
            $str = "$key`0$timestamp`0$uuid`0`0$organizationid`0`0$($method.ToUpper())`0$endpoint`0$(if ($method -eq "GET") {$paramstr} else {"`0$($params | ConvertTo-Json -Depth 10 -Compress)"})"
            $sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HMACSHA256")
            $sha.key = [System.Text.Encoding]::UTF8.Getbytes($secret)
            $sign = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${str})))

            $headers = [hashtable]@{
                'X-Time'            = $timestamp
                'X-Nonce'           = $uuid
                'X-Organization-Id' = $organizationid
                'X-Auth'            = "$($key):$(($sign -replace '\-').ToLower())"
                'Cache-Control'     = 'no-cache'
            }
            try {
                $body = Switch($method) {
                    "GET" {if ($params.Count) {$params} else {$null}}
                    default {$params | ConvertTo-Json -Depth 10}
                }

                $Request = Invoke-GetUrl "$base$endpoint" -timeout $Timeout -headers $headers -requestmethod $method -body $body
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "Nicehash API call: $($_.Exception.Message)"
            }
        }

        if (-not $Global:NHCache[$keystr] -or $Request) {
            $Global:NHCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request}
        }
    }
    $Global:NHCache[$keystr].request
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