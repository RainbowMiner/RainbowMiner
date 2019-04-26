Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\OpenCL\*.cs

function Get-Version {
    [CmdletBinding()]
    param($Version)
    # System.Version objects can be compared with -gt and -lt properly
    # This strips out anything that doens't belong in a version, eg. v at the beginning, or -preview1 at the end, and returns a version object
    [System.Version]($Version -Split '-' -Replace "[^0-9.]")[0]
}

function Compare-Version {
    [CmdletBinding()]
    param($Version1,$Version2)
    $ver1 = $Version1 -split '\.'
    $ver2 = $Version2 -split '\.'
    $max = [Math]::min($ver1.Count,$ver2.Count)

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
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $RBMVersion = $Version = Get-Version($RBMVersion)
        $Uri = ""
        $NextCheck = (Get-Date).ToUniversalTime()

        try {
            $ReposURI = "https://api.github.com/repos/rainbowminer/$Name/releases/latest"
            if ($Force) {
                $Request = Invoke-RestMethod $ReposURI -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            } else {
                $Request = Invoke-RestMethodAsync $ReposURI -cycletime 3600 -noquickstart
            }
            $RemoteVersion = ($Request.tag_name -replace '^v')
            if ($RemoteVersion) {
                $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion).zip" | Select-Object -ExpandProperty browser_download_url
                $Version = Get-Version($RemoteVersion)
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
        {$_ -match "^RTX20\d{2}"} {"Turing"}
        {$_ -match "^GTX10\d{2}" -or $_ -match "^GTXTitanX"} {"Pascal"}
        default {"Other"}
    }
}

function Get-PoolPayoutCurrencies {
    param($Pool)
    $Payout_Currencies = [PSCustomObject]@{}
    if (-not (Test-Path Variable:Global:PoolFields)) {
        $Global:PoolFields = @("API_Key","API_ID","API_Secret","AECurrency","User","Worker","DataWindow","Penalty","Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","MinerName","ExcludeMinerName","FocusWallet","Wallets","AllowZero","StatAverage","Email","Password","PartyPassword","EnableAutoCoin","EnablePostBlockMining","EnableMining")
    }
    @($Pool.PSObject.Properties) | Where-Object Membertype -eq "NoteProperty" | Where-Object {$_.Value -is [string] -and ($_.Value.Length -gt 2 -or $_.Value -eq "`$Wallet" -or $_.Value -eq "`$$($_.Name)") -and $Global:PoolFields -inotcontains $_.Name -and $_.Name -notmatch "-Params$"} | Select-Object Name,Value -Unique | Sort-Object Name,Value | Foreach-Object{$Payout_Currencies | Add-Member $_.Name $_.Value}
    $Payout_Currencies
}

function Get-Balance {
    [CmdletBinding()]
    param($Config, $NewRates, [Bool]$Refresh = $false, [Bool]$Details = $false)
    
    if (-not (Test-Path Variable:Script:CachedPoolBalances) -or $Refresh) {
        $Script:CachedPoolBalances = @(Get-BalancesContent -Config $Config | Group-Object -Property Caption | Foreach-Object {
            if ($_.Count -gt 1){foreach ($p in @("Balance","Pending","Total","Paid","Earned","Payouts")) {if (Get-Member -InputObject $_.Group[0] -Name $p) {if ($p -eq "Payouts") {$_.Group[0].$p = @($_.Group.$p | Select-Object)} else {$_.Group[0].$p = ($_.Group.$p | Measure-Object -Sum).Sum}}}}
            $_.Group[0]
        })
    }

    $Balances = $Script:CachedPoolBalances | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json

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
}

function Get-CoinSymbol {
    [CmdletBinding()]
    param($CoinName = "Bitcoin",[Switch]$Silent)
    
    if (-not (Test-Path Variable:Global:GlobalCoinNames) -or -not $Global:GlobalCoinNames.Count) {
        try {
            $Request = Invoke-GetUrl "http://rbminer.net/api/data/coins.json"
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Coins API failed. "
        }
        if (-not $Request -or $Request.PSObject.Properties.Name.Count -le 100) {
            $Request = $null
            if (Test-Path "Data\Coins.json") {try {$Request = Get-Content "Data\Coins.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop} catch {$Request = $null}}
            if (-not $Request) {Write-Log -Level Warn "Coins API return empty string. ";return}
        } else {Set-ContentJson -PathToFile "Data\Coins.json" -Data $Request > $null}
        [hashtable]$Global:GlobalCoinNames = @{}
        $Request.PSObject.Properties | Foreach-Object {$Global:GlobalCoinNames[$_.Name] = $_.Value}
    }
    if (-not $Silent) {$Global:GlobalCoinNames[$CoinName.ToLower() -replace "[^a-z0-9]+"]}
}

function Update-Rates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Symbols
    )

    if (-not $Symbols) {
        $Symbols = $Session.Config.Currency + @("USD") + @($Session.Config.Pools.PSObject.Properties.Name | Foreach-Object {$Session.Config.Pools.$_.Wallets.PSObject.Properties.Name} | Select-Object -Unique) | Select-Object -Unique
    }

    [hashtable]$NewRates = @{}
    try {Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -Jobkey "coinbase" | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$NewRates[$_.Name] = [Double]$_.Value}}} catch {if ($Error.Count){$Error.RemoveAt(0)};$NewRates.Clear()}

    if (-not $NewRates.Count) {
        Write-Log -Level Info "Coinbase is down, using fallback. "
        try {Invoke-GetUrl "http://rbminer.net/api/data/coinbase.json" | Select-Object | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$NewRates[$_.Name] = [Double]$_.Value}}} catch {if ($Error.Count){$Error.RemoveAt(0)};$NewRates.Clear();Write-Log -Level Warn "Coinbase down. "}
    }

    $Session.Rates["BTC"] = $NewRates["BTC"] = [Double]1

    if (-not (Test-Path Variable:Global:GlobalGetTicker)) {$Global:GlobalGetTicker = @()}
    Compare-Object $Symbols @($NewRates.Keys) -IncludeEqual | Where-Object {$_.SideIndicator -ne "=>" -and $_.InputObject} | Foreach-Object {
        if ($_.SideIndicator -eq "==") {$Session.Rates[$_.InputObject] = [Double]$NewRates[$_.InputObject]}
        elseif ($Global:GlobalGetTicker -inotcontains $_.InputObject) {$Global:GlobalGetTicker += $_.InputObject.ToUpper()}
    }
    Remove-Variable "NewRates" -Force

    if ($Global:GlobalGetTicker.Count -gt 0) {
        try {
            $SymbolStr = (@($Global:GlobalGetTicker | Sort-Object) -join ',').ToUpper()
            $RatesAPI = Invoke-RestMethodAsync "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$($SymbolStr)&tsyms=BTC&extraParams=https://rbminer.net" -Jobkey "rates"
            if ($RatesAPI.Response -eq "Error") {
                Write-Log -Level Info "Cryptocompare says $($RatesAPI.Message)"
            } else {
                $RatesAPI.PSObject.Properties | Foreach-Object {$Session.Rates[$_.Name] = if ($_.Value.BTC -gt 0) {[double](1/$_.Value.BTC)} else {0}}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Cryptocompare API for $($SymbolStr) to BTC has failed. "
        }
    }

    Get-WorldCurrencies -Silent
    Compare-Object $Global:GlobalWorldCurrencies @($Session.Rates.Keys) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject | Foreach-Object {$Session.Rates[$_] = [Math]::Round($Session.Rates[$_],3)}
}

function Get-Ticker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Symbol,
        [Parameter(Mandatory = $false)]
        $Convert = "BTC",
        [Parameter(Mandatory = $false)]
        $Jobkey = $null
    )

    if (-not $Convert) {$Convert="BTC"}
    $Convert = $Convert.ToUpper()
    #eventually consult crypto-bridge: https://api.crypto-bridge.org/api/v1/ticker
    #eventually consult crex24: https://api.crex24.com/CryptoExchangeService/BotPublic/ReturnTicker

    try {
        $SymbolStr = (@($Symbol | Sort-Object) -join ',').ToUpper()
        if ($SymbolStr -match ',') {
            $RatesAPI = Invoke-RestMethodAsync "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$($SymbolStr)&tsyms=$($Convert)&extraParams=https://github.com/rainbowminer/RainbowMiner" -Jobkey $Jobkey -cycletime 1800
            if ($RatesAPI.Response -eq "Error") {
                Write-Log -Level Warn "Cryptocompare says $($RatesAPI.Message)"
            } else {
                $RatesAPI
            }
        } else {
            $RatesAPI = Invoke-RestMethodAsync "https://min-api.cryptocompare.com/data/price?fsym=$($SymbolStr)&tsyms=$($Convert)&extraParams=https://github.com/rainbowminer/RainbowMiner" -Jobkey $Jobkey -cycletime 1800
            if ($RatesAPI.Response -eq "Error") {
                Write-Log -Level Warn "Cryptocompare says $($RatesAPI.Message)"
            } else {
                [PSCustomObject]@{$SymbolStr = $RatesAPI}
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Cryptocompare API for $($SymbolStr) to $($Convert) has failed. "
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

                $Miner.Speed_Live += [Double]$Miner_Speed

                Write-Log "$($Miner.BaseName) $(if ($Miner.IsBenchmarking()) {"benchmarking"} else {"mining"}) $($Miner_Algorithm) on $($Miner.DeviceModel): $($Miner.GetMinerDataCount()) samples / round $(if ($Miner.IsBenchmarking()) {"$($Miner.Benchmarked) / variance $("{0:f2}" -f ($Miner.Variance[$Miner.Algorithm.IndexOf($Miner_Algorithm)]*100))%"} else {$Miner.Rounds})"

                $Stat = $null
                if (-not $Miner.IsBenchmarking() -or $Miner_Speed) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($Miner_Algorithm -replace '\-.*$')_HashRate" -Value $Miner_Speed -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $Session.DevicesToVendors[$Miner.DeviceModel] -Quiet:$($Quiet -or $Miner.GetRunningTime() -lt (New-TimeSpan -Seconds 30))
                    $Statset++
                }

                #Update watchdog timer
                if ($WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner.Name -and $_.PoolName -eq $Miner.Pool[$Miner_Index] -and $_.Algorithm -eq $Miner_Algorithm}) {
                    if ($Stat -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                        $WatchdogTimer.Kicked = $Stat.Updated
                    } elseif ($Miner.IsBenchmarking() -or ($Miner_Speed -and $Miner.Rounds -lt [Math]::Max($Miner.ExtendedInterval,1)-1)) {
                        $WatchdogTimer.Kicked = (Get-Date).ToUniversalTime()
                    } elseif ($Watchdog -and $WatchdogTimer.Kicked -lt $Session.Timer.AddSeconds( - $Session.WatchdogInterval)) {
                        $Miner_Failed = $true
                    }
                }
                $Miner_PowerDraw = 0
                $Miner_Index++
            }

            if ($Statset -eq $Miner.Algorithm.Count) {$Miner.Benchmarked = 0}

            $Miner.EndOfRoundCleanup()            

            if ($Miner_Failed) {
                $Miner.SetStatus([MinerStatus]::Failed)
                $Miner.Stopped = $true
                Write-Log -Level Warn "Miner $($Miner.Name) mining $($Miner.Algorithm -join '/') on pool $($Miner.Pool -join '/') temporarily disabled. "
                $Miner_Failed_Total++
            } else {
                Write-ActivityLog $Miner
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

    Begin { }
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

        # Attempt to aquire mutex, waiting up to 1 second if necessary.  If aquired, write to the log file and release mutex.  Otherwise, display an error.
        if ($mutex.WaitOne(1000)) {
            $proc = Get-Process -id $PID
            "$date [$("{0:n2}" -f ($proc.WorkingSet64/1MB)) $("{0:n2}" -f ($proc.PrivateMemorySize64/1MB))] $LevelText $Message" | Out-File -FilePath $filename -Append -Encoding utf8
            $mutex.ReleaseMutex()
        }
        else {
            Write-Error -Message "Log file is locked, unable to write message to $FileName."
        }
    }
    End {}
}

Function Write-ActivityLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()]$Miner
    )

    Begin { }
    Process {
        $mutex = New-Object System.Threading.Mutex($false, "RBMWriteActivityLog")

        $filename = ".\Logs\Activity_$(Get-Date -Format "yyyy-MM-dd").txt"

        # Attempt to aquire mutex, waiting up to 1 second if necessary.  If aquired, write to the log file and release mutex.  Otherwise, display an error.
        if ($mutex.WaitOne(1000)) {
            "$([PSCustomObject]@{
                ActiveStart    = "{0:yyyy-MM-dd HH:mm:ss}" -f $Miner.GetActiveStart()
                ActiveLast     = "{0:yyyy-MM-dd HH:mm:ss}" -f $Miner.GetActiveLast()
                Name           = $Miner.BaseName
                Device         = @($Miner.DeviceModel)
                Algorithm      = @($Miner.BaseAlgorithm)
                Pool           = @($Miner.Pool)
                Speed          = @($Miner.Speed_Live)
                Profit         = $Miner.Profit
                PowerDraw      = $Miner.PowerDraw
            } | ConvertTo-Json -Compress)," | Out-File -FilePath $filename -Append -Encoding utf8
            $mutex.ReleaseMutex()
        }
        else {
            Write-Error -Message "Activity log file is locked, unable to write message to $FileName."
        }
    }
    End {}
}

Function Set-Total {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        $Miner,
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date).ToUniversalTime(),
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $LogLevel = if ($Quiet) {"Info"} else {"Warn"}

    $Path0 = "Stats\Totals"
    $Path = "$Path0\$($Miner.Pool[0])_Total.txt"

    $Duration = $Miner.GetRunningTime($true)

    $TotalProfit = ($Miner.Profit + $(if ($Session.Config.UsePowerPrice -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {$Miner.Profit_Cost} else {0}))*$Duration.TotalDays 
    $TotalCost   = $Miner.Profit_Cost * $Duration.TotalDays
    $TotalPower  = $Miner.PowerDraw * $Duration.TotalDays

    $Stat = Get-Content $Path -ErrorAction Ignore -Raw

    try {
        $Stat = $Stat | ConvertFrom-Json -ErrorAction Stop
        $Stat.Duration += $Duration.TotalMinutes
        $Stat.Cost     += $TotalCost
        $Stat.Profit   += $TotalProfit
        $Stat.Power    += $TotalPower
        $Stat.Updated   = $Updated
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (-not $Quiet -and (Test-Path $Path)) {Write-Log -Level Warn "Totals file ($Name) is corrupt and will be reset. "}
        $Stat = [PSCustomObject]@{
                    Pool     = $Miner.Pool[0]
                    Duration = $Duration.TotalMinutes
                    Cost     = $TotalCost
                    Profit   = $TotalProfit
                    Power    = $TotalPower
                    Started  = $Updated
                    Updated  = $Updated
                }
    }

    if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}
    $Stat | ConvertTo-Json | Set-Content $Path
}

function Set-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name, 
        [Parameter(Mandatory = $true)]
        [Double]$Value, 
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
        [Double]$ErrorRatio = 0,
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

    if ($Name -match '_Profit$')       {$Path0 = "Stats\Pools";  $Mode = "Pools"}
    elseif ($Name -match '_Hashrate$') {$Path0 = "Stats\Miners"; $Mode = "Miners"}
    else                               {$Path0 = "Stats";        $Mode = "Profit"}

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

        if ($Stat.Week_Fluctuation -and [Double]$Stat.Week_Fluctuation -ge 0.8) {throw "Fluctuation out of range"}

        $AddStat = Switch($Mode) {
            "Miners" {
                @{
                    PowerDraw_Live = [Double]$Stat.PowerDraw_Live
                    PowerDraw_Average = [Double]$Stat.PowerDraw_Average
                }
            }
            "Pools" {
                @{
                    HashRate_Live = [Double]$Stat.HashRate_Live
                    HashRate_Average = [Double]$Stat.HashRate_Average
                    BlockRate_Live = [Double]$Stat.BlockRate_Live
                    BlockRate_Average = [Double]$Stat.BlockRate_Average
                    ErrorRatio = if ($Stat.ErrorRatio -eq $null) {$ErrorRatio} else {[Double]$Stat.ErrorRatio}
                    ErrorRatio_Average = if ($Stat.ErrorRatio_Average -eq $null) {$ErrorRatio} else {[Double]$Stat.ErrorRatio_Average}
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
                        PowerDraw_Live = $PowerDraw
                        PowerDraw_Average = ((1 - $Span_Week) * $Stat.PowerDraw_Average) + ($Span_Week * $PowerDraw)
                    }
                }
                "Pools" {
                    $AddStat = @{
                        HashRate_Live = $HashRate
                        HashRate_Average = ((1 - $Span_Hour) * $Stat.HashRate_Average) + ($Span_Hour * [Double]$HashRate)
                        BlockRate_Live = $BlockRate
                        BlockRate_Average = ((1 - $Span_Hour) * $Stat.BlockRate_Average) + ($Span_Hour * [Double]$BlockRate)
                        ErrorRatio_Live = $ErrorRatio
                        ErrorRatio_Average = ((1 - $Span_ThreeDay) * $Stat.ErrorRatio_Average) + ($Span_ThreeDay * [Double]$ErrorRatio)
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
                    PowerDraw_Live = $PowerDraw
                    PowerDraw_Average = $PowerDraw
                }
            }
            "Pools" {
                $Stat | Add-Member -NotePropertyMembers @{
                    HashRate_Live = $HashRate
                    HashRate_Average = $HashRate
                    BlockRate_Live = $BlockRate
                    BlockRate_Average = $BlockRate
                    ErrorRatio = $ErrorRatio
                    ErrorRatio_Average = $ErrorRatio
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
                    PowerDraw_Live = [Decimal]$Stat.PowerDraw_Live
                    PowerDraw_Average = [Decimal]$Stat.PowerDraw_Average
                }
            }
            "Pools" {
                $OutStat | Add-Member -NotePropertyMembers @{
                    HashRate_Live = [Decimal]$Stat.HashRate_Live
                    HashRate_Average = [Decimal]$Stat.HashRate_Average
                    BlockRate_Live = [Decimal]$Stat.BlockRate_Live
                    BlockRate_Average = [Decimal]$Stat.BlockRate_Average
                    ErrorRatio_Live = [Decimal]$Stat.ErrorRatio_Live
                    ErrorRatio_Average = [Decimal]$Stat.ErrorRatio_Average
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
        [Switch]$All = $false
    )

    if ($Name) {
        # Return single requested stat
        if ($Name -match '_Profit$') {$Path = "Stats\Pools"}
        elseif ($Name -match '_Hashrate$') {$Path = "Stats\Miners"}
        elseif ($Name -match '_Total$') {$Path = "Stats\Totals"}
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
        if (($Totals -or $All) -and -not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}

        $Match = @()
        if ($Miners) {$Match += "Hashrate"}
        if ($Pools)  {$Match += "Profit|BLK|HSR|TTF"}
        if ($Totals) {$Match += "Total"}

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
            $Content = try {$_ | Get-Content | ConvertFrom-Json} catch {if ($Error.Count){$Error.RemoveAt(0)};$null}
            if ($Content -eq $null) {$Content = $_ | Get-Content}
        }
        else {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}                
                try {
                    ($_ | Get-Content | ConvertFrom-Json) | ForEach-Object {Invoke-ExpressionRecursive $_}
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
        [Bool]$InfoOnly = $false,
        [Parameter(Mandatory = $false)]
        [Bool]$IgnoreFees = $false
    )
        
    Get-ChildItem "Pools\$($PoolName).ps1" -File -ErrorAction Ignore | ForEach-Object {
        $Pool_Name = $_.BaseName

        [Hashtable]$Parameters = @{
            StatSpan = $StatSpan
            InfoOnly = $InfoOnly
        }
        foreach($p in $Config.PSObject.Properties.Name) {$Parameters.$p = $Config.$p}

        foreach($Pool in @(& $_.FullName @Parameters)) {
            $Pool_Factor = 1-([Double]$Config.Penalty + [Double]$(if (-not $IgnoreFees){$Pool.PoolFee}) + [Double]$Algorithms."$($Pool.Algorithm)".Penalty)/100
            if ($Pool_Factor -lt 0) {$Pool_Factor = 0}
            $Pool.Price *= $Pool_Factor
            $Pool.StablePrice *= $Pool_Factor
            $Pool | Add-Member -NotePropertyMembers @{
                AlgorithmList = if ($Pool.Algorithm -match "-") {@((Get-Algorithm $Pool.Algorithm), ($Pool.Algorithm -replace '\-.*$'))}else{@($Pool.Algorithm)}
                Name          = $Pool_Name
                Penalty       = $Config.Penalty
                Wallet        = $Config.Wallets."$($Pool.Currency)"
                Worker        = $Config.Worker
                Email         = $Config.Email
            } -Force -PassThru
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

    foreach($Miner in @(Get-ChildItem "Miners\$($MinerName).ps1" -File -ErrorAction Ignore)) {
        $Name = $Miner.BaseName
        if ($InfoOnly -or ((Compare-Object @($Session.DevicesToVendors.Values | Select-Object) @($Session.MinerInfo.$Name | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0)) {
            foreach($c in @(& $Miner.FullName @Parameters)) {
                $p = @($c.HashRates.PSObject.Properties.Name | Foreach-Object {$_ -replace '\-.*$'} | Select-Object)
                $c | Add-Member -NotePropertyMembers @{
                    Name = if ($c.Name) {$c.Name} else {$Name}
                    BaseName = $Name
                    BaseAlgorithm = $p
                    DeviceModel = if (@($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name) -icontains $c.DeviceModel) {$Session.DevicesByTypes.FullComboModels."$($c.DeviceModel)"} else {$c.DeviceModel}
                    PowerDraw = $Session.Stats."$($c.Name)_$($p[0])_HashRate".PowerDraw_Average
                } -Force -PassThru
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

filter ConvertTo-Hash { 
    [CmdletBinding()]
    $Hash = $_
    switch ([math]::truncate([math]::log($Hash, 1e3))) {
        "-Infinity" {"0  H"}
        0 {"{0:n2}  H" -f ($Hash / 1)}
        1 {"{0:n2} kH" -f ($Hash / 1e3)}
        2 {"{0:n2} MH" -f ($Hash / 1e6)}
        3 {"{0:n2} GH" -f ($Hash / 1e9)}
        4 {"{0:n2} TH" -f ($Hash / 1e12)}
        Default {"{0:n2} PH" -f ($Hash / 1e15)}
    }
}

function ConvertFrom-Hash {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Hash
    )
    try {$Num = [double]($Hash -replace "[^0-9`.]")} catch {$Num=0}
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
    try {$Num = [double]($Time -replace "[^0-9`.]")} catch {$Num=0}
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
        [Parameter(Mandatory = $true)]
        $BestMiners,
        [Parameter(Mandatory = $false)]
        [String]$SortBy = "Profit_Bias"
    )
    
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
        [Int]$MultiProcess = 0
    )

    if (($ShowMinerWindow -and -not $IsWrapper) -or -not $IsWindows) {
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
        Process   = $Job
        ProcessId = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
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

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars)

        $EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {Set-Item -force -path "env:$($matches[1])" -value $matches[2]}

        $CurrentPwd = $pwd

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        if ($IsWindows) {
            Add-Type -TypeDefinition @"
            // http://www.daveamenta.com/2013-08/powershell-start-process-without-taking-focus/
            using System;
            using System.Diagnostics;
            using System.Runtime.InteropServices;
             
            [StructLayout(LayoutKind.Sequential)]
            public struct PROCESS_INFORMATION {
                public IntPtr hProcess;
                public IntPtr hThread;
                public uint dwProcessId;
                public uint dwThreadId;
            }
             
            [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
            public struct STARTUPINFO {
                public uint cb;
                public string lpReserved;
                public string lpDesktop;
                public string lpTitle;
                public uint dwX;
                public uint dwY;
                public uint dwXSize;
                public uint dwYSize;
                public uint dwXCountChars;
                public uint dwYCountChars;
                public uint dwFillAttribute;
                public STARTF dwFlags;
                public ShowWindow wShowWindow;
                public short cbReserved2;
                public IntPtr lpReserved2;
                public IntPtr hStdInput;
                public IntPtr hStdOutput;
                public IntPtr hStdError;
            }
             
            [StructLayout(LayoutKind.Sequential)]
            public struct SECURITY_ATTRIBUTES {
                public int length;
                public IntPtr lpSecurityDescriptor;
                public bool bInheritHandle;
            }
             
            [Flags]
            public enum CreationFlags : int {
                NONE = 0,
                DEBUG_PROCESS = 0x00000001,
                DEBUG_ONLY_THIS_PROCESS = 0x00000002,
                CREATE_SUSPENDED = 0x00000004,
                DETACHED_PROCESS = 0x00000008,
                CREATE_NEW_CONSOLE = 0x00000010,
                CREATE_NEW_PROCESS_GROUP = 0x00000200,
                CREATE_UNICODE_ENVIRONMENT = 0x00000400,
                CREATE_SEPARATE_WOW_VDM = 0x00000800,
                CREATE_SHARED_WOW_VDM = 0x00001000,
                CREATE_PROTECTED_PROCESS = 0x00040000,
                EXTENDED_STARTUPINFO_PRESENT = 0x00080000,
                CREATE_BREAKAWAY_FROM_JOB = 0x01000000,
                CREATE_PRESERVE_CODE_AUTHZ_LEVEL = 0x02000000,
                CREATE_DEFAULT_ERROR_MODE = 0x04000000,
                CREATE_NO_WINDOW = 0x08000000,
            }
             
            [Flags]
            public enum STARTF : uint {
                STARTF_USESHOWWINDOW = 0x00000001,
                STARTF_USESIZE = 0x00000002,
                STARTF_USEPOSITION = 0x00000004,
                STARTF_USECOUNTCHARS = 0x00000008,
                STARTF_USEFILLATTRIBUTE = 0x00000010,
                STARTF_RUNFULLSCREEN = 0x00000020,  // ignored for non-x86 platforms
                STARTF_FORCEONFEEDBACK = 0x00000040,
                STARTF_FORCEOFFFEEDBACK = 0x00000080,
                STARTF_USESTDHANDLES = 0x00000100,
            }
             
            public enum ShowWindow : short {
                SW_HIDE = 0,
                SW_SHOWNORMAL = 1,
                SW_NORMAL = 1,
                SW_SHOWMINIMIZED = 2,
                SW_SHOWMAXIMIZED = 3,
                SW_MAXIMIZE = 3,
                SW_SHOWNOACTIVATE = 4,
                SW_SHOW = 5,
                SW_MINIMIZE = 6,
                SW_SHOWMINNOACTIVE = 7,
                SW_SHOWNA = 8,
                SW_RESTORE = 9,
                SW_SHOWDEFAULT = 10,
                SW_FORCEMINIMIZE = 11,
                SW_MAX = 11
            }
             
            public static class Kernel32 {
                [DllImport("kernel32.dll", SetLastError=true)]
                public static extern bool CreateProcess(
                    string lpApplicationName, 
                    string lpCommandLine, 
                    ref SECURITY_ATTRIBUTES lpProcessAttributes, 
                    ref SECURITY_ATTRIBUTES lpThreadAttributes,
                    bool bInheritHandles, 
                    CreationFlags dwCreationFlags, 
                    IntPtr lpEnvironment,
                    string lpCurrentDirectory, 
                    ref STARTUPINFO lpStartupInfo, 
                    out PROCESS_INFORMATION lpProcessInformation);
            }
"@
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
            if ($WorkingDirectory -ne "") {$lpCurrentDirectory = $WorkingDirectory} else {$lpCurrentDirectory = $pwd}
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
                & chmod +x $FilePath > $null

                # Set lib path to local
                $env:LD_LIBRARY_PATH = $env:LD_LIBRARY_PATH + ":./"
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
        Process   = $Job
        ProcessId = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
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
            $Process = Get-Process -Id $_
            $Process.PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]
            if ($CPUAffinity -gt 0) {$Process.ProcessorAffinity = $CPUAffinity}
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
                $Process.CloseMainWindow() > $null
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
                    $Process.Kill()
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
        [String]$Sha256 = ""
    )

    # Set current path used by .net methods to the same as the script's path
    [Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" > $null}
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName) {Remove-Item $FileName}
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $oldProgressPreference = $Global:ProgressPreference
    $Global:ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    $Global:ProgressPreference = $oldProgressPreference

    if ($Sha256 -and (Test-Path $FileName)) {if ($Sha256 -ne (Get-FileHash $FileName -Algorithm SHA256).Hash) {Remove-Item $FileName; throw "Downloadfile $FileName has wrong hash! Please open an issue at github.com."}}

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        (Start-Process $FileName "-qb" -PassThru).WaitForExit()>$null
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
        if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}

        $psi = $null
        $process.Dispose()
        $process = $null
    } catch {Write-Log -Level Warn "Could not execute $FilePath $ArgumentList"}
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

function Get-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @(),
        [Parameter(Mandatory = $false)]
        [Switch]$Refresh = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$IgnoreOpenCL = $false
    )

    if ($Name) {
        if (-not (Test-Path Variable:Script:GlobalDataDeviceList) -or -not $Script:GlobalDataDeviceList) {$Script:GlobalDataDeviceList = Get-Content ".\Data\devices.json" -Raw | ConvertFrom-Json}        
        $Name_Devices = $Name | ForEach-Object {
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
            if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) {
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

    $Platform_Devices = try {
        [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
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
                    PCIBusId        = if ($_.bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
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
                $Device_OpenCL = $_ | ConvertTo-Json -Depth 1 | ConvertFrom-Json

                $Device_Name = [String]$Device_OpenCL.Name -replace '\(TM\)|\(R\)'
                $Vendor_Name = [String]$Device_OpenCL.Vendor
                $InstanceId  = ''
                $SubId = ''

                if ($GPUVendorLists.NVIDIA -icontains $Vendor_Name) {
                    $Vendor_Name = "NVIDIA"
                } elseif ($GPUVendorLists.AMD -icontains $Vendor_Name) {
                    $Vendor_Name = "AMD"
                    if (-not $GPUDeviceNames[$Vendor_Name]) {$GPUDeviceNames[$Vendor_Name] = Get-DeviceName $Vendor_Name -UseAfterburner ($OpenCL_DeviceIDs.Count -lt 7)}
                    $GPUDeviceNames[$Vendor_Name] | Where-Object Index -eq ([Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)") | Foreach-Object {$Device_Name = $_.DeviceName; $InstanceId = $_.InstanceId; $SubId = $_.SubId}
                    if ($SubId -eq "687F" -or $Device_Name -eq "Radeon RX Vega" -or $Device_Name -eq "gfx900") {
                        if ($Device_OpenCL.MaxComputeUnits -eq 56) {$Device_Name = "Radeon Vega 56"}
                        elseif ($Device_OpenCL.MaxComputeUnits -eq 64) {$Device_Name = "Radeon Vega 64"}
                    }
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
                }

                if ($Device.Type -ne "Cpu" -and ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_}))) {
                    $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
                    if ($Device.Vendor -eq "AMD" -and $AmdModelsEx -notcontains $Device.Model) {
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
                try {$Global:GlobalCPUInfo | Add-Member Features $($feat = @{}; switch -regex ((Invoke-Exe ".\Includes\CHKCPU32.exe" -ArgumentList "/x" -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines) -split "</\w+>") {"^\s*<_?(\w+)>(\d+).*" {if ($feat.($matches[1]) -eq $null) {$feat.($matches[1]) = [int]$matches[2]}}; "^\s*<_?(cpu_\w+)>(.+)" {if ($feat.($matches[1]) -eq $null) {$feat.($matches[1]) = $matches[2]}}}; $feat)} catch {if ($Error.Count){$Error.RemoveAt(0)}}
                if ($Global:GlobalCPUInfo.Features -eq $null) {
                    $CIM_CPU = Get-CimInstance -ClassName CIM_Processor
                    $Global:GlobalCPUInfo | Add-Member Features ([PSCustomObject]@{
                        physical_cpus = $CIM_CPU.Count
                        cores         = ($CIM_CPU.NumberOfCores | Measure-Object -Sum).Sum
                        threads       = ($CIM_CPU.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
                        l3            = $CIM_CPU[0].L3CacheSize
                        cpu_speed     = $CIM_CPU[0].MaxClockSpeed
                        cpu_name      = $CIM_CPU[0].Name
                        cpu_vendor    = $CIM_CPU[0].Manufacturer
                        tryall        = 1
                    }) -Force
                    if ($CIM_CPU) {Remove-Variable "CIM_CPU" -Force}
                }
            } elseif ($IsLinux) {
                $Data = Get-Content "/proc/cpuinfo"
                if ($Data) {
                    $Global:GlobalCPUInfo | Add-Member Features $($feat = @{}; (($Data | Where-Object {$_ -like "flags*"})[0] -split ":")[1].Trim() -split "\s+" | ForEach-Object {$feat.$_ = 1}; $feat)
                    $Global:GlobalCPUInfo | Add-Member Features ([PSCustomObject]@{
                        physical_cpus = [int]  ($Data | Where-Object {$_ -match 'physical id'} | Foreach-Object {[int]($_ -split ":")[1].Trim()} | Select-Object -Unique).Count
                        cores         = [int] (($Data | Where-Object {$_ -match 'cpu cores'}  | Select-Object -First 1) -split ":")[1].Trim()
                        threads       = [int] (($Data | Where-Object {$_ -match 'siblings'}   | Select-Object -First 1) -split ":")[1].Trim()
                        l3            = [int]((($Data | Where-Object {$_ -match 'cache size'} | Select-Object -First 1) -split ":")[1].Trim() -split "\s+")[0].Trim()
                        cpu_speed     = [int] (($Data | Where-Object {$_ -match 'cpu MHz'}    | Select-Object -First 1) -split ":")[1].Trim()
                        cpu_name      =       (($Data | Where-Object {$_ -match 'model name'} | Select-Object -First 1) -split ":")[1].Trim()
                        cpu_vendor    =       (($Data | Where-Object {$_ -match 'vendor_id'}  | Select-Object -First 1) -split ":")[1].Trim()
                    }) -Force
                }
            }

            if ($Global:GlobalCPUInfo.Vendor -eq $null) {
                $Global:GlobalCPUInfo | Add-Member Name          $Global:GlobalCPUInfo.Features.cpu_name
                $Global:GlobalCPUInfo | Add-Member Vendor        $(if ($GPUVendorLists.INTEL -icontains $Global:GlobalCPUInfo.Features.cpu_vendor){"INTEL"}else{$Global:GlobalCPUInfo.Features.cpu_vendor.ToUpper()}) -Force
                $Global:GlobalCPUInfo | Add-Member Manufacturer  $Global:GlobalCPUInfo.Features.cpu_vendor
                $Global:GlobalCPUInfo | Add-Member Cores         $Global:GlobalCPUInfo.Features.cores
                $Global:GlobalCPUInfo | Add-Member Threads       $Global:GlobalCPUInfo.Features.threads
                $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  $Global:GlobalCPUInfo.Features.physical_cpus
                $Global:GlobalCPUInfo | Add-Member L3CacheSize   $Global:GlobalCPUInfo.Features.l3
                $Global:GlobalCPUInfo | Add-Member MaxClockSpeed $Global:GlobalCPUInfo.Features.cpu_speed

                if (-not $IsWindows -and $Global:GlobalCPUInfo.PhysicalCPUs -gt 1) {
                    $Global:GlobalCPUInfo.Cores   *= $Global:GlobalCPUInfo.PhysicalCPUs
                    $Global:GlobalCPUInfo.Threads *= $Global:GlobalCPUInfo.PhysicalCPUs
                    $Global:GlobalCPUInfo.PhysicalCPUs = 1
                }

                $Global:GlobalCPUInfo | Add-Member RealCores     ([int[]](0..($Global:GlobalCPUInfo.Threads - 1))) -Force
                if ($Global:GlobalCPUInfo.Threads -gt $Global:GlobalCPUInfo.Cores) {$Global:GlobalCPUInfo.RealCores = $Global:GlobalCPUInfo.RealCores | Where-Object {-not ($_ % [int]($Global:GlobalCPUInfo.Threads/$Global:GlobalCPUInfo.Cores))}}
            }
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
        $Vendor_Cards = if (Test-Path ".\Data\$($Vendor.ToLower())-cards.json") {try {Get-Content ".\Data\$($Vendor.ToLower())-cards.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop}catch{}}

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
                        }
                        $DeviceId++
                    }
                }
            }

            if ($Vendor -eq "NVIDIA") {
                Invoke-NvidiaSmi "index","gpu_name","pci.device_id" | ForEach-Object {
                    $DeviceName = $_.gpu_name.Trim()
                    $SubId = if ($AdlResultSplit.Count -gt 1 -and $AdlResultSplit[1] -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                    if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                    [PSCustomObject]@{
                        Index      = $_.index
                        DeviceName = $DeviceName
                        SubId      = if ($_.pci_device_id -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
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

        if ($IsWindows) {
            try { #AMD
                if ($UseAfterburner -and $Script:abMonitor -and $Script:abControl -and $Vendor -eq "AMD") {
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

                        if (-not (Test-Path Variable:Script:AmdCardsTDP)) {$Script:AmdCardsTDP = Get-Content ".\Data\amd-cards-tdp.json" -Raw | ConvertFrom-Json}

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
                        }
                        $DeviceId++
                    }
                } else {

                    if ($Vendor -eq 'AMD') {
                        $DeviceId = 0

                        $AdlResult = Invoke-Exe '.\Includes\OverdriveN.exe' -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed" -and $_ -ne "Failed to load ADL library"}

                        if (-not (Test-Path Variable:Script:AmdCardsTDP)) {$Script:AmdCardsTDP = Get-Content ".\Data\amd-cards-tdp.json" -Raw | ConvertFrom-Json}

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
                                }
                                $DeviceId++
                            }
                        }
                    }
                }
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Could not read power data from AMD"
            }
        }

        try { #NVIDIA        
            if ($Vendor -eq 'NVIDIA') {
                #NVIDIA
                $DeviceId = 0
                if (-not (Test-Path Variable:Script:NvidiaCardsTDP)) {$Script:NvidiaCardsTDP = Get-Content ".\Data\nvidia-cards-tdp.json" -Raw | ConvertFrom-Json}

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
            if (-not (Test-Path Variable:Script:CpuTDP)) {$Script:CpuTDP = Get-Content ".\Data\cpu-tdp.json" -Raw | ConvertFrom-Json}
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

                    [int]$Utilization = [math]::min((((& ps -A -o pcpu) -match "\d" | Measure-Object -Sum).Sum / $Global:GlobalCPUInfo.Threads), 100)

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
        (Get-Content "Data\algorithms.json" -Raw | ConvertFrom-Json).PSObject.Properties | %{$Global:GlobalAlgorithms[$_.Name]=$_.Value}
        $Global:GlobalAlgorithmsTimeStamp = (Get-ChildItem "Data\algorithms.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {
        if ($Values) {$Global:GlobalAlgorithms.Values | Select-Object -Unique | Sort-Object}
        else {$Global:GlobalAlgorithms.Keys | Sort-Object}
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
        (Get-Content "Data\equihashcoins.json" -Raw | ConvertFrom-Json).PSObject.Properties | %{$Global:GlobalEquihashCoins[$_.Name]=$_.Value}
    }
    if (-not $Silent) {$Global:GlobalEquihashCoins.Keys}
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
        $Global:GlobalPoolsInfo = Get-Content "Data\poolsinfo.json" -Raw | ConvertFrom-Json
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
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalRegions)) {
        [hashtable]$Global:GlobalRegions = @{}
        (Get-Content "Data\regions.json" -Raw | ConvertFrom-Json).PSObject.Properties | %{$Global:GlobalRegions[$_.Name]=$_.Value}
    }
    if (-not $Silent) {$Global:GlobalRegions.Keys}
}

function Get-WorldCurrencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalWorldCurrencies)) {
        $Global:GlobalWorldCurrencies = if (Test-Path ".\Data\worldcurrencies.json") {Get-Content ".\Data\worldcurrencies.json" | ConvertFrom-Json} else {@("USD","INR","RUB","EUR","GBP")}
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
    $Profit_Comparison
    $Profit_MarginOfError
    $Profit_Bias
    $Profit_Unbias
    $Profit_Cost
    $PowerDraw
    $Shares
    $Speed
    $Speed_Live
    [double[]]$Variance = @()
    $StartCommand
    $StopCommand
    $Best
    $Best_Comparison
    $New
    $Benchmarked
    $LogFile    
    [Bool]$ShowMinerWindow = $false
    $MSIAprofile
    $OCprofile
    $DevFee
    $BaseName = $null
    $FaultTolerance = 0.1
    $ExtendInterval = 0
    $Penalty = 0
    $PostBlockMining = 0
    $Rounds = 0
    $MinSamples = 1
    $ZeroRounds = 0
    $MaxBenchmarkRounds = 3
    $MaxRejectedShareRatio = 0.3
    $MiningPriority
    $MiningAffinity
    $ManualUri
    [String]$EthPillEnable = "disable"
    $DataInterval
    [String[]]$EnvVars = @()
    [Hashtable]$Priorities = @{"CPU"=-2;"GPU"=-1;"CPUAffinity"=0}
    [Bool]$Stopped = $false
    [Bool]$Donator = $false
    [Bool]$IsFocusWalletMiner = $false
    [Bool]$IsExclusiveMiner = $false
    [Bool]$IsRunningFirstRounds = $false
    [Bool]$NoCPUMining = $false
    [Bool]$NeedsBenchmark = $false
    [Int]$MultiProcess = 0
    hidden [System.Management.Automation.Job]$Process = $null
    [Int[]]$ProcessId = @()
    hidden [TimeSpan]$Active = [TimeSpan]::Zero
    hidden [Int]$Activated = 0
    hidden [MinerStatus]$Status = [MinerStatus]::Idle
    hidden [Array]$Data = @()
    hidden [Bool]$HasOwnMinerWindow = $false    
    hidden [Array]$OCprofileBackup = @()
    hidden [Int]$EthPill = 0
    hidden [DateTime]$IntervalBegin = 0

    [String[]]GetProcessNames() {
        return @(([IO.FileInfo]($this.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName)
    }

    [String]GetArguments() {
        return $this.Arguments
    }

    [String]GetMinerDeviceName() {
        return "$($this.BaseName)-$(($this.DeviceName | Sort-Object) -join '-')"
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
            if ($this.EthPillEnable -ne "disable" -and (Compare-Object $this.BaseAlgorithm @("Ethash") -IncludeEqual -ExcludeDifferent | Measure-Object).Count) {
                $Prescription_Device = @(Get-Device $this.DeviceName) | Where-Object Model -in @("GTX1080","GTX1080Ti","TITANXP")
                $Prescription = ""
                switch ($this.EthPillEnable) {
                    "RevA" {$Prescription = "revA"}
                    "RevB" {$Prescription = "revB"}
                }
                if ($Prescription -ne "" -and $Prescription_Device) {
                    Write-Log "Starting OhGodAnETHlargementPill $($Prescription) on $($Prescription_Device.Name -join ',')"
                    if ($Global:IsLinux) {
                        $Command = ".\IncludesLinux\OhGodAnETHlargementPill-r2"
                        if (Test-Path $Command) {& chmod +x $Command > $null}
                    } else {
                        $Command = ".\Includes\OhGodAnETHlargementPill-r2.exe"
                    }

                    $this.EthPill = [int](Start-Process -FilePath $Command -PassThru -Verb RunAs -ArgumentList "--$($Prescription) $($Prescription_Device.Type_Vendor_Index -join ',')").Id
                    Start-Sleep -Milliseconds 250 #wait 1/4 second
                }
            }
            $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $this.GetArguments() -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -CPUAffinity $this.Priorities.CPUAffinity -ShowMinerWindow $this.ShowMinerWindow -IsWrapper ($this.API -eq "Wrapper" -or $this.API -eq "SwapMiner") -EnvVars $this.EnvVars -MultiProcess $this.MultiProcess
            $this.Process   = $Job.Process
            $this.ProcessId = $Job.ProcessId
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
                if ($EthPillProcess = Get-Process -Id $this.EthPill) {
                    Write-Log "Stopping OhGodAnETHlargementPill"
                    $EthPillProcess.CloseMainWindow() > $null
                    if(-not $EthPillProcess.WaitForExit(1000)) {if(-not $EthPillProcess.HasExited) {$EthPillProcess.Kill()}}
                    $this.EthPill = 0
                    Start-Sleep -Milliseconds 250 #Sleep for 1/4 second
                }
            }
        }
        if ($this.StopCommand) {try {Invoke-Expression $this.StopCommand} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "StopCommand failed for miner $($this.Name)"}}
        $this.ProcessId = [int[]]@()
    }

    hidden StartMiningPreProcess() {
        $this.Shares = @()
        $this.Algorithm | Foreach-Object {$this.Shares += [PSCustomObject]@{Accepted=0;Rejected=0}}
    }

    hidden StartMiningPostProcess() { }

    hidden StopMiningPreProcess() { }

    hidden StopMiningPostProcess() {
        Start-Sleep -Milliseconds 500
        $this.ResetOCprofile() #reset all overclocking
        Start-Sleep -Milliseconds 500        
        $this.New = $false
    }

    StopMiningPostCleanup() {
        $this.Stopped = $false
    }

    EndOfRoundCleanup() {
        if ($this.API -ne "Wrapper" -and $this.API -ne "SwapMiner" -and $this.Process.HasMoreData) {$this.Process | Receive-Job > $null}
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
        $this.Shares[$Index].Accepted = $Accepted
        $this.Shares[$Index].Rejected = $Rejected
    }

    [Int64]GetShareCount([Int]$Index) {
        return [Int64]($this.Shares[$Index].Accepted + $this.Shares[$Index].Rejected)
    }

    [Double]GetRejectedShareRatio([Int]$Index) {
        return [Double]$(if ($this.GetShareCount($Index) -ge 10) {$this.Shares[$Index].Rejected / $this.GetShareCount($Index)})
    }

    [Double]GetMaxRejectedShareRatio() {
        $Index = 0
        return ($this.Algorithm | Foreach-Object {$this.GetRejectedShareRatio($Index);$Index++} | Measure-Object -Maximum).Maximum
    }

    [Bool]CheckShareRatio() {
        return $this.MaxRejectedShareRatio -le 0 -or $this.GetMaxRejectedShareRatio() -le $this.MaxRejectedShareRatio
    }

    [String[]]UpdateMinerData () {

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

        return @()
    }

    AddMinerData($data) {
        $data | Add-Member Date (Get-Date).ToUniversalTime() -Force
        $data | Add-Member PowerDraw $(Get-DevicePowerDraw -DeviceName $this.DeviceName) -Force
        $data | Add-Member Round $this.Rounds -Force
        $this.Data += $data
        if ($this.Data.Count -gt $this.MinSamples) {
            $DataMinTime = (Get-Date).ToUniversalTime().AddSeconds( - $this.DataInterval*[Math]::max($this.ExtendInterval,1)*2)
            $i=0; $this.Data = @($this.Data | Foreach-Object {if ($_.Date -ge $DataMinTime -or ($this.Data.Count - $i) -le $this.MinSamples) {$_};$i++} | Select-Object)
        }
    }

    [Int]GetMinerDataCount() {
        return $this.Data.Count
    }

    CleanupMinerData() {
    }

    ResetMinerData() {
        $this.Data = @()
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

    ResetOCprofile() {
        if ($this.OCprofile.Count -eq 0 -or $this.OCprofileBackup.Count -eq 0) {return}

        try {
            $Script:abMonitor.ReloadAll()
            $Script:abControl.ReloadAll()
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Failed to communicate with MSI Afterburner"
            return
        }
        foreach($Profile in $this.OCprofileBackup) {foreach($Name in $Profile.Keys) {if ($Name -ne "Index") {$Script:abControl.GpuEntries[$Profile.Index].$Name = $Profile.$Name}}}
        $Script:abControl.CommitChanges()
        $this.OCprofileBackup = @()
        Write-Log "OC reset for $($this.BaseName)"
    }

    SetOCprofile($Config) {        
        if ($this.OCprofile.Count -eq 0 -or $this.DeviceModel -like 'CPU*') {return}

        [System.Collections.ArrayList]$applied = @()
        [System.Collections.ArrayList]$NvCmd = @()

        $this.OCprofileBackup = @()
        $Vendor = $Script:GlobalCachedDevices | Where-Object {@($this.OCprofile.PSObject.Properties.Name) -icontains $_.Model} | Select-Object -ExpandProperty Vendor -Unique

        if ($Vendor -ne "NVIDIA") {
            if (-not $Global:IsWindows) {return}
            try {
                $Script:abMonitor.ReloadAll()
                $Script:abControl.ReloadAll()
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Failed to communicate with MSI Afterburner"
                return
            }
        }

        $Pattern = @{
            AMD    = "*Radeon*"
            NVIDIA = "*GeForce*"
            Intel  = "*Intel*"
        }

        foreach ($DeviceModel in @($this.OCprofile.PSObject.Properties.Name)) {            
            if ($Profile = if ($Config.OCprofiles."$($this.OCprofile.$DeviceModel)-$($DeviceModel)" -ne $null) {$Config.OCprofiles."$($this.OCprofile.$DeviceModel)-$($DeviceModel)"} elseif ($Config.OCprofiles."$($this.OCprofile.$DeviceModel)" -ne $null) {$Config.OCprofiles."$($this.OCprofile.$DeviceModel)"}) {
                $DeviceIds = @($Script:GlobalCachedDevices | Where-Object Model -eq $DeviceModel | Select-Object -ExpandProperty Type_Vendor_Index)                
                $Profile.CoreClockBoost   = $Profile.CoreClockBoost -replace '[^0-9\-]+'
                $Profile.MemoryClockBoost = $Profile.MemoryClockBoost -replace '[^0-9\-]+'
                $Profile.LockVoltagePoint = $Profile.LockVoltagePoint -replace '[^0-9]+'
                if (-not $Config.EnableOCVoltage) {$Profile.LockVoltagePoint = ''}

                $applied_any = $false

                if ($Vendor -eq "NVIDIA") {
                    $x = Switch -Regex ($DeviceModel) {
                        "1050" {2}
                        "P106-?100" {2}
                        "P106-?090" {1}
                        "P104-?100" {1}
                        "P102-?100" {1}
                        "1660" {4}
                        default {3}
                    }
                    foreach($DeviceId in $DeviceIds) {
                        if ($Profile.PowerLimit -gt 0) {$val=[math]::max([math]::min($Profile.PowerLimit,200),20);if ($Global:IsLinux) {Set-NvidiaPowerLimit $DeviceId $val} else {$NvCmd.Add("-setPowerTarget:$($DeviceId),$($val)") >$null};$applied_any=$true}
                        if (-not $Global:IsLinux) {
                            if ($Profile.ThermalLimit -gt 0) {$val=[math]::max([math]::min($Profile.ThermalLimit,95),50);$NvCmd.Add("-setTempTarget:$($DeviceId),0,$($val)") >$null;$applied_any=$true}
                            if ($Profile.LockVoltagePoint-match '^\-*[0-9]+$') {$val=[int]([Convert]::ToInt32($Profile.LockVoltagePoint)/12500)*12500;$NvCmd.Add("-lockVoltagePoint:$($DeviceId),$($val)") >$null;$applied_any=$true}
                        }
                        if ($Profile.CoreClockBoost -match '^\-*[0-9]+$') {$val=[Convert]::ToInt32($Profile.CoreClockBoost);$NvCmd.Add("$(if ($Global:IsLinux) {"-a '[gpu:$($DeviceId)]/GPUGraphicsClockOffset[$($x)]=$($val)'"} else {"-setBaseClockOffset:$($DeviceId),0,$($val)"})") >$null;$applied_any=$true}
                        if ($Profile.MemoryClockBoost -match '^\-*[0-9]+$') {$val = [Convert]::ToInt32($Profile.MemoryClockBoost);$NvCmd.Add("$(if ($Global:IsLinux) {"-a '[gpu:$($DeviceId)]/GPUMemoryTransferRateOffset[$($x)]=$($val)'"} else {"-setMemoryClockOffset:$($DeviceId),0,$($val)"})") >$null;$applied_any=$true}
                        $NvCmd.Add("-a '[gpu:$($DeviceId)]/GPUPowerMizerMode=1'")
                    }
                } elseif ($Pattern.$Vendor -ne $null) {
                    $DeviceId = 0
                    $Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Vendor | Select-Object -ExpandProperty Index | Foreach-Object {
                        if ($DeviceId -in $DeviceIds) {
                            $GpuEntry = $Script:abControl.GpuEntries[$_]
                            $ProfileBackup = [hashtable]@{}
                            try {if (-not ($GpuEntry.PowerLimitMin -eq 0 -and $GpuEntry.PowerLimitMax -eq 0) -and $Profile.PowerLimit -gt 0) {$ProfileBackup.PowerLimitCur = $GpuEntry.PowerLimitCur;$Script:abControl.GpuEntries[$_].PowerLimitCur = [math]::max([math]::min($Profile.PowerLimit,$GpuEntry.PowerLimitMax),$GpuEntry.PowerLimitMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                            try {if (-not ($GpuEntry.ThermalLimitMin -eq 0 -and $GpuEntry.ThermalLimitMax -eq 0) -and $Profile.ThermalLimit -gt 0) {$ProfileBackup.ThermalLimitCur = $GpuEntry.ThermalLimitCur;$Script:abControl.GpuEntries[$_].ThermalLimitCur = [math]::max([math]::min($Profile.ThermalLimit,$GpuEntry.ThermalLimitMax),$GpuEntry.ThermalLimitMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                            try {if (-not ($GpuEntry.CoreClockBoostMin -eq 0 -and $GpuEntry.CoreClockBoostMax -eq 0) -and $Profile.CoreClockBoost -match '^\-*[0-9]+$') {$ProfileBackup.CoreClockBoostCur = $GpuEntry.CoreClockBoostCur;$Script:abControl.GpuEntries[$_].CoreClockBoostCur = [math]::max([math]::min([convert]::ToInt32($Profile.CoreClockBoost) * 1000,$GpuEntry.CoreClockBoostMax),$GpuEntry.CoreClockBoostMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                            try {if (-not ($GpuEntry.MemoryClockBoostMin -eq 0 -and $GpuEntry.MemoryClockBoostMax -eq 0) -and $Profile.MemoryClockBoost -match '^\-*[0-9]+$') {$ProfileBackup.MemoryClockBoostCur = $GpuEntry.MemoryClockBoostCur;$Script:abControl.GpuEntries[$_].MemoryClockBoostCur = [math]::max([math]::min([convert]::ToInt32($Profile.MemoryClockBoost) * 1000,$GpuEntry.MemoryClockBoostMax),$GpuEntry.MemoryClockBoostMin)}} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn $_.Exception.Message}
                            if ($Profile.LockVoltagePoint-match '^\-*[0-9]+$') {Write-Log -Level Warn "$DeviceModel does not support LockVoltagePoint overclocking"}
                            if ($ProfileBackup.Count) {$ProfileBackup.Index = $_;$this.OCprofileBackup += $ProfileBackup > $null;$applied_any=$true}
                        }
                        $DeviceId++
                    }                 
                }
                if ($applied_any) {$applied.Add("OC set for $($this.BaseName)-$($DeviceModel)-$($this.BaseAlgorithm -join '-'): PL=$(if ($Profile.PowerLimit) {"$($Profile.PowerLimit)%"} else {"-"}), TL=$(if ($Profile.ThermalLimit) {"$($Profile.ThermalLimit)°C"} else {"-"}), MEM=$(if ($Profile.MemoryClockBoost -ne '') {"$($Profile.MemoryClockBoost)"} else {"-"}), CORE=$(if ($Profile.CoreClockBoost -ne '') {"$($Profile.CoreClockBoost)"} else {"-"}), LVP=$(if ($Profile.LockVoltagePoint -ne '') {"$($Profile.LockVoltagePoint)µV"} else {"-"})") > $null}
            }
        }

        if ($applied.Count) {
            if ($Vendor -eq "NVIDIA") {
                if ($Global:IsLinux) {Invoke-NvidiaSettings $NvCmd}
                else {& ".\Includes\NvidiaInspector\nvidiaInspector.exe" $NvCmd}
            } else {$Script:abControl.CommitChanges()}
            $applied.GetEnumerator() | Foreach-Object {Write-Log $_}
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
            Invoke-Exe -FilePath "nvidia-settings" -ArgumentList ($NvCmd -join ' ') -Runas >$null
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
                -Name 'NtpServer' -ErrorAction SilentlyContinue |
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
        [Int]$Length = 0
    )
    if ($Valid.Count -eq 1 -and $Valid[0] -match "[,;:]") {[Array]$Valid = [regex]::split($Valid[0].Trim(),"\s*[,;:]+\s*")}
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result.Trim()}
        if ("exit","cancel","back","<" -icontains $Result){$Result;return}
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
        $Max = $null
    )        
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default -ne $null){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result.Trim()}
        if ("exit","cancel","back","<" -icontains $Result){$Result;return}
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
        $Max = $null
    )    
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default -ne $null){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result.Trim()}
        if ("exit","cancel","back","<" -icontains $Result){$Result;return}
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
        [Switch]$AllowDuplicates = $False
    )
    if ($Default.Count -eq 1 -and $Default[0] -match "[,;:]") {[Array]$Default = @([regex]::split($Default[0].Trim(),"\s*[,;:]+\s*") | Where-Object {$_ -ne ""} | Select-Object)}
    if ($Valid.Count -eq 1 -and $Valid[0] -match "[,;:]") {[Array]$Valid = @([regex]::split($Valid[0].Trim(),"\s*[,;:]+\s*") | Where-Object {$_ -ne ""} | Select-Object)}
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default.Count){" [default=$($Default -join ",")]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default -join ","}else{$Result.Trim()}
        if ("exit","cancel","back","<" -icontains $Result){$Result;return}
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
            [Array]$Result = @($Result -replace "[^$($Characters),;:]+","" -split "\s*[,;:]+\s*" | Where-Object {$_ -ne ""} | Select-Object)
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
        $Default = $false
    )
    $Default = if (Get-Yes $Default){"yes"}else{"no"}
    $Result = if (([String]$Result=(Read-Host "$($Prompt) (yes/no) [default=$($Default)]").Trim()) -eq ''){$Default}else{$Result.Trim()}
    if ("exit","cancel","back","<" -icontains $Result){$Result;return}
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
                if ($Compress) {$Data | ConvertTo-Json -Compress | Set-Content $PathToFile -Encoding utf8 -Force}
                else {$Data | ConvertTo-Json | Set-Content $PathToFile -Encoding utf8 -Force}
            } elseif ($Exists) {
                (Get-ChildItem $PathToFile).LastWriteTime = Get-Date
                Write-Log -Level Verbose "No changes in $(([IO.FileInfo]$PathToFile).Name)"
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
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $False)]
        [Switch]$UseDefaultParams = $false
    )
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\MinersConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        $Algo = [hashtable]@{}
        $Done = [PSCustomObject]@{}
        $ChangeTag = $null
        if (Test-Path $PathToFile) {
            try {
                $PresetTmp = Get-Content $PathToFile -Raw | ConvertFrom-Json
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
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
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
}

function Set-AlgorithmsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\AlgorithmsConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            try {$Preset = Get-Content $PathToFile -Raw | ConvertFrom-Json}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
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
}

function Set-PresetDefault {
    if (Test-Path ".\Data\PresetDefault.ps1") {
        $Setup = Get-ChildItemContent ".\Data\PresetDefault.ps1" | Select-Object -ExpandProperty Content
        $Setup.PSObject.Properties.Name | Foreach-Object {
            $Session.DefaultValues[$_] = $Setup.$_
        }
    }
}

function Set-CoinsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\CoinsConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            try {$Preset = Get-Content $PathToFile -Raw | ConvertFrom-Json}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind="0";PostBlockMining="0";Wallet="";EnableAutoPool="0"}
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
}

function Set-GpuGroupsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            try {$Preset = Get-Content $PathToFile -Raw | ConvertFrom-Json}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $GpuNames = Get-Device "nvidia","amd" -IgnoreOpenCL | Select-Object -ExpandProperty Name -Unique
            foreach ($GpuName in $GpuNames) {
                if ($Preset.$GpuName -eq $null) {$Preset | Add-Member $GpuName "" -Force}
                elseif ($Preset.$GpuName -ne "") {$Script:GlobalCachedDevices | Where-Object Name -eq $GpuName | Foreach-Object {$_.Model += $Preset.$GpuName.ToUpper()}}
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
}

function Set-DevicesConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\DevicesConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            try {$Preset = Get-Content $PathToFile -Raw | ConvertFrom-Json}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
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
}

function Set-PoolsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\PoolsConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            try {$Preset = Get-Content $PathToFile -Raw | ConvertFrom-Json}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
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
}

function Set-OCProfilesConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\OCProfilesConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            try {$Preset = Get-Content $PathToFile -Raw | ConvertFrom-Json}
            catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.`r`n$($_.Exception.Message)"; return}
        }

        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*";LockVoltagePoint = "*"}
            if (-not $Preset.PSObject.Properties.Name) {
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
        [Switch]$IncludeErrorRatio = $false
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
    if (-not $hasdetails -and $values.ContainsKey("actual_last24h")) {$values["actual_last24h"]/=1000}
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
    if ($IncludeErrorRatio) {
        $Base = if ($Values["actual_last24h"]) {$Values["actual_last24h"]} else {$Values["estimate_last24h"]}
        [PSCustomObject]@{
            Price = $Value
            ErrorRatio = if ($Base -and $Values["estimate_current"]) {$Values["estimate_current"]/$Base - 1} else {0}
        }
    } else {$Value}
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
    [Switch]$ForceFullCollection
)
    $memusagebyte = [System.GC]::GetTotalMemory($ForceFullCollection)
    $memdiff = $memusagebyte - [int64]$script:last_memory_usage_byte
    [PSCustomObject]@{
        MemUsage   = $memusagebyte
        MemDiff    = $memdiff
        MemText    = "Memory usage: {0:n1} MB ({1:n0} Bytes {2})" -f  ($memusagebyte/1MB), $memusagebyte, "$(if ($memdiff -gt 0){"+"})$($memdiff)"
    }
    $script:last_memory_usage_byte = $memusagebyte
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
        [int]$timeout = 10,
    [Parameter(Mandatory = $False)]
        [hashtable]$body
)
    $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36"
    if ($url -match "^https" -and [Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {[Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12}

    $RequestMethod = if ($body) {"Post"} else {"Get"}
    $RequestUrl = $url -replace "{timestamp}",(Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    if ($method -eq "REST") {
        Invoke-RestMethod $RequestUrl -UseBasicParsing -UserAgent $ua -TimeoutSec $timeout -ErrorAction Stop -Method $RequestMethod -Headers @{"Cache-Control" = "no-cache"} -Body $body
    } else {
        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $ua -TimeoutSec $timeout -ErrorAction Stop -Method $RequestMethod -Headers @{"Cache-Control" = "no-cache"} -Body $body
        $Global:ProgressPreference = $oldProgressPreference
    }
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
        [hashtable]$body
)
    Invoke-GetUrlAsync $url -method "REST" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body
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
        [hashtable]$body
)
    Invoke-GetUrlAsync $url -method "WEB" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body
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
        [hashtable]$body
)
    if (-not (Test-Path Variable:Global:Asyncloader)) {
        if ($delay) {Start-Sleep -Milliseconds $delay}
        Invoke-GetUrl $url -method $method -body $body
        return
    }

    if (-not $url -and -not $Jobkey) {return}
    
    if (-not $Jobkey) {$Jobkey = Get-MD5Hash "$($url)$(if ($body) {$body | ConvertTo-Json -Compress})"}
    elseif ($url -and $AsyncLoader.Jobs.$Jobkey -and ($AsyncLoader.Jobs.$Jobkey.Url -ne $url -or ($AsyncLoader.Jobs.$Jobkey.Body | ConvertTo-Json -Compress) -ne ($body | ConvertTo-Json -Compress))) {$force = $true;$AsyncLoader.Jobs.$Jobkey.Url = $url;$AsyncLoader.Jobs.$Jobkey.Body = $body}

    if ($cycletime -le 0) {$cycletime = $AsyncLoader.Interval}

    if (-not (Test-Path ".\Cache")) {New-Item "Cache" -ItemType "directory" -ErrorAction Ignore > $null}

    if ($force -or -not $AsyncLoader.Jobs.$Jobkey -or $AsyncLoader.Jobs.$Jobkey.Paused -or -not (Test-Path ".\Cache\$($Jobkey).asy")) {
        $Quickstart = $false
        if (-not $AsyncLoader.Jobs.$Jobkey) {
            $Quickstart = -not $nocache -and -not $noquickstart -and $AsyncLoader.Quickstart -ne -1 -and (Test-Path ".\Cache\$($Jobkey).asy")
            if (-not $Quickstart -and $delay) {Start-Sleep -Milliseconds $delay}
            $AsyncLoader.Jobs.$Jobkey = [PSCustomObject]@{Url=$url;Error=$null;Running=$true;Paused=$false;Method=$method;Body=$body;Success=0;Fail=0;Prefail=0;LastRequest=(Get-Date).ToUniversalTime();CycleTime=$cycletime;Retry=$retry;RetryWait=$retrywait;Tag=$tag;Timeout=$timeout}
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

        do {
            $Request = $RequestError = $null            
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
                    $Request = Invoke-GetUrl $AsyncLoader.Jobs.$Jobkey.Url -method $AsyncLoader.Jobs.$Jobkey.Method -body $AsyncLoader.Jobs.$Jobkey.Body -timeout $AsyncLoader.Jobs.$Jobkey.Timeout                    
                }
                if (-not $Request) {throw "Empty request"}
                $AsyncLoader.Jobs.$Jobkey.Success++
                $AsyncLoader.Jobs.$Jobkey.Prefail=0                
            }
            catch {
                $RequestError = "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Problem fetching $($AsyncLoader.Jobs.$Jobkey.Url) using $($AsyncLoader.Jobs.$Jobkey.Method): $($_.Exception.Message)"
                #Write-Log -Level Info "GetUrl Failed $RequestError"
            }
            finally {
                $Error.Clear()
            }
            if (-not $Quickstart) {$AsyncLoader.Jobs.$Jobkey.LastRequest=(Get-Date).ToUniversalTime()}

            $retry--
            if ($retry) {
                if (-not $RequestError) {$retry = 0}
                else {Start-Sleep -Milliseconds $AsyncLoader.Jobs.$Jobkey.RetryWait}
            }
        } until ($retry -le 0)

        if ($RequestError -or -not $Request) {
            $AsyncLoader.Jobs.$Jobkey.Prefail++
            if ($AsyncLoader.Jobs.$Jobkey.Prefail -gt 5) {$AsyncLoader.Jobs.$Jobkey.Fail++;$AsyncLoader.Jobs.$Jobkey.Prefail=0}            
        } elseif (-not $Quickstart) {
            $Request | ConvertTo-Json -Compress -Depth 10 | Out-File ".\Cache\$($Jobkey).asy" -Encoding utf8 -ErrorAction Ignore -Force
            Remove-Variable "Request"
        }
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
            catch {Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore;throw "Job $Jobkey contains clutter."}
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
        Write-Log -Level Warn "Miner Status $($Session.Config.MinerStatusURL) has failed. "
    }
}

function Invoke-ReportMinerStatus {
    if (-not $Session.Config.MinerStatusURL -or -not $Session.Config.MinerStatusKey) {return}

    $Version = "RainbowMiner $($Session.Version.ToString())"
    $Status = if ($Session.Paused) {"Paused"} else {"Running"}
    $Rates = [PSCustomObject]@{}
    $Session.Rates.Keys | Where-Object {$Session.Config.Currency -icontains $_} | Foreach-Object {$Rates | Add-Member $_ $Session.Rates.$_ -Force}

    Write-Log "Pinging monitoring server. "

    $Profit = 0.0
    $PowerDraw = 0.0

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

            # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
            [PSCustomObject]@{
                Name           = $Miner.BaseName
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
            }
        }
    )
    
    $Profit = [Math]::Round($Profit, 8) | ConvertTo-Json
    $PowerDraw = [Math]::Round($PowerDraw, 2) | ConvertTo-Json
     
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (Test-Path ".\Data\reportapi.json") {try {$ReportAPI = Get-Content ".\Data\reportapi.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop} catch {$ReportAPI=$null}}
    if (-not $ReportAPI) {$ReportAPI = @([PSCustomObject]@{match    = "rbminer.net";apiurl   = "https://rbminer.net/api/report.php"})}

    # Send the request
    try {
        $ReportUrl = $Session.Config.MinerStatusURL
        $ReportStatus = "Error"
        $ReportDone = $false
        $ReportAPI | Where-Object {-not $ReportDone -and $ReportUrl -match $_.match} | Foreach-Object {
            $ReportUrl = $_.apiurl
            $Valid = (Get-UnixTimestamp) + $Session.Config.BenchmarkInterval
            $Response = Invoke-RestMethod -Uri $ReportUrl -Method Post -Body @{user = $Session.Config.MinerStatusKey; email = $Session.Config.MinerStatusEmail; pushoverkey = $Session.Config.PushOverUserKey; worker = $Session.Config.WorkerName; version = $Version; status = $Status; profit = $Profit; powerdraw = $PowerDraw; rates = ConvertTo-Json $Rates; valid = $Valid; data = $minerreport} -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
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
                    $API.RemoteMiners = @($Response.Workers | Where-Object worker -ne $Session.Config.WorkerName | Select-Object) | ConvertTo-Json -Depth 10                    
                }
            }
            $ReportDone = $true
        }
        if (-not $ReportDone) {
            $Response = Invoke-RestMethod -Uri $ReportUrl -Method Post -Body @{address = $Session.Config.MinerStatusKey; workername = $Session.Config.WorkerName; version = $Version; status = $Status; profit = $Profit; miners = $minerreport} -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            if ($Response) {$ReportStatus = $Response -split "[\r\n]+" | select-object -first 1} 
        }
    }
    catch {
        Write-Log -Level Info "Miner Status $($ReportUrl) has failed. "
    }
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
    } catch {"maximized"}
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
    } catch {}
}

function Get-UnixTimestamp {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [Switch]$Milliseconds = $false
)
    [Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc'))."$(if ($Milliseconds) {"TotalMilliseconds"} else {"TotalSeconds"})")
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
    } catch {$s}
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
    } catch {$s}
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
    if (Test-Path ".\Data\lastdrun.json") {try {[DateTime](Get-Content ".\Data\lastdrun.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop).lastdrun} catch {}}
}

function Set-LastDrun {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [DateTime]$Timer = (Get-Date).ToUniversalTime()
)
    $Timer = $Timer.ToUniversalTime();Set-ContentJson -Data ([PSCustomObject]@{lastdrun=[DateTime]$Timer}) -PathToFile ".\Data\lastdrun.json" > $null;$Timer
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
    } catch {}
}

function Invoke-MiningRigRentalRequest {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    $params = @{},
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://www.miningrigrentals.com/api/v2",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 10,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0
)
    $keystr = Get-MD5Hash "$($endpoint)$($params | ConvertTo-Json -Depth 10 -Compress)"
    if (-not (Test-Path Variable:Global:MRRCache)) {$Global:MRRCache = [hashtable]::Synchronized(@{})}
    if (-not $Cache -or -not $Global:MRRCache[$keystr] -or -not $Global:MRRCache[$keystr].request -or $Global:MRRCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {
        $nonce = Get-UnixTimestamp -Milliseconds
        $str = "$key$nonce$endpoint"
        $sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HMACSHA1")
        $sha.key = [System.Text.Encoding]::UTF8.Getbytes($secret)
        $sign = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${str})))    
        $headers = [hashtable]@{
	        'x-api-sign' = ($sign -replace '\-').ToLower()
	        'x-api-key'  = $key
	        'x-api-nonce'= $nonce
            'Cache-Control' = 'no-cache'
        }
        $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36"
        try {
            $body = Switch($method) {
                "PUT" {$params | ConvertTo-Json -Depth 10}
                "GET" {if ($params.Count) {$params} else {$null}}
            }
            $Request = Invoke-RestMethod "$base$endpoint" -UseBasicParsing -UserAgent $ua -TimeoutSec $Timeout -ErrorAction Stop -Headers $headers -Method $method -Body $body
        } catch {            
            Write-Log -Level Info "MiningRigRental call: $($_.Exception.Message)"
        }
        if ($Request.success -ne $null -and -not $Request.success) {
            Write-Log -Level Warn "MiningRigRental error: $(if ($Request.data.message) {$Request.data.message} else {"unknown"})"
        }

        if (-not $Global:MRRCache[$keystr] -or ($Request -and $Request.success)) {
            $Global:MRRCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request}
        }
    }
    if ($Global:MRRCache[$keystr].request -and $Global:MRRCache[$keystr].request.success) {$Global:MRRCache[$keystr].request.data}
}

function Get-MiningRigRentalAlgorithm {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$Name
)
    Get-Algorithm $(Switch ($Name) {
            "x16rt"             {"Veil"}
            "x16rtgin"          {"X16rt"}
            "cuckoocycle"       {"Cuckaroo29"}
            "cuckoocycle29swap" {"Cuckaroo29s"}
            "cuckoocycle31"     {"Cuckatoo31"}
            "hashimotos"        {"Ethash"}
            default             {$Name}
        }
    )
}

function Get-MiningRigInfo {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    $id,
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret
)
    if (-not $id) {return}

    if (-not (Test-Path Variable:Global:MRRInfoCache)) {
        $Global:MRRInfoCache = [hashtable]::Synchronized(@{})
        if (Test-Path ".\Data\mrrinfo.json") {
            try {
                $MrrInfo = Get-Content ".\Data\mrrinfo.json" -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $MrrInfo = @()
            }
            $MrrInfo | Foreach-Object {$MrrInfoCache[$_.rigid] = $_}
        }
    }

    if ($Rigs_Ids = $id | Where-Object {-not $MrrInfoCache.ContainsKey($_) -or $MrrInfoCache.$_.updated -lt (Get-Date).AddHours(-24).ToUniversalTime()}) {
        $Updated = 0
        @(Invoke-MiningRigRentalRequest "/rig/$($Rigs_Ids -join ";")/port" $API_Key $API_Secret -Timeout 60 | Select-Object) | Foreach-Object {
            $MrrInfoCache[$_.rigid] = $_ | Add-Member updated (Get-Date).ToUniversalTime() -Force -PassThru
            $Updated++
        }
        if ($Updated) {Set-ContentJson -PathToFile ".\Data\mrrinfo.json" -Data $MrrInfoCache.Values -Compress > $null}
    }
    $id | Where-Object {$MrrInfoCache.ContainsKey($_)} | Foreach-Object {$MrrInfoCache.$_}
}

function Get-MiningRigRentalsDivisor {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$unit
)
    Switch (($unit -split "\*")[0]) {
        "kh" {1e3}
        "mh" {1e6}
        "gh" {1e9}
        "th" {1e12}
        default {1}
    }
}

function Set-MiningRigRentalStatus {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [Int]$RigId,
    [Parameter(Mandatory = $False)]
    [Switch]$Stop,
    [Parameter(Mandatory = $False)]
    [String]$Status = ""
)
    if (-not (Test-Path Variable:Global:MRRStatus)) {$Global:MRRStatus = [hashtable]::Synchronized(@{})}
    $time = (Get-Date).ToUniversalTime()
    if ($MRRStatus.ContainsKey($RigId)) {
        if ($Stop) {$MRRStatus.Remove($RigId)}
        elseif ($Status -eq "online") {$MRRStatus[$RigId].next = $time;$MRRStatus[$RigId].wait = $false;$MRRStatus[$RigId].enable = $true}
        elseif ($time -ge $MRRStatus[$RigId].next) {
            if ($MRRStatus[$RigId].wait) {$MRRStatus[$RigId].next = $time.AddMinutes(15);$MRRStatus[$RigId].wait = $MRRStatus[$RigId].enable = $false}
            else {$MRRStatus[$RigId].next = $time.AddMinutes(3);$MRRStatus[$RigId].wait = $MRRStatus[$RigId].enable = $true}
        }
    } else {$MRRStatus[$RigId] = [PSCustomObject]@{next = $time.AddMinutes(3); wait = $true; enable = $true}}
    if (-not $Stop) {$MRRStatus[$RigId].enable}
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
        Invoke-Exe -FilePath $NVSMI -ArgumentList ($Arguments -join ' ') -ExcludeEmptyLines -ExpandLines -Runas:$Runas
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
    } catch {}
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
    } catch {$true}
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
        [String]$mAvoid = ""
    )

    $Portlist = $Request.config.ports | Where-Object {$_.Disabled -ne $true -and $_.Virtual -ne $true -and (-not $mAvoid -or $_.desc -notmatch $mAvoid)}

    for($ssl=0; $ssl -lt 2; $ssl++) {
        $Ports = $Portlist | Where-Object {[int]$ssl -eq [int]$_.ssl}
        if ($Ports) {
            $result = [PSCustomObject]@{}
            foreach($PortType in @("CPU","GPU","RIG")) {
                $Port = Switch ($PortType) {
                    "CPU" {$Ports | Where-Object {$mCPU -and $_.desc -match $mCPU} | Select-Object -First 1}
                    "GPU" {$Ports | Where-Object {$mGPU -and $_.desc -match $mGPU} | Select-Object -First 1}
                    "RIG" {$Ports | Where-Object {$mRIG -and $_.desc -match $mRIG} | Select-Object -First 1}
                }
                if (-not $Port) {$Port = $Ports | Select-Object -First 1}
                $result | Add-Member $PortType $Port.port -Force
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
        $Timestamp = (Get-UnixTimestamp),
        [Parameter(Mandatory = $False)]
        [Switch]$addBlockData,
        [Parameter(Mandatory = $False)]
        [Switch]$addDay
    )

    $rewards = [PSCustomObject]@{
            Live    = @{reward=0.0;hashrate=$Request.pool.$HashrateField}
            Day     = @{reward=0.0;hashrate=0.0}
            Workers = if ($Request.pool.workers) {$Request.pool.workers} else {$Request.pool.miners}
            BLK     = 0
            TSL     = 0
    }

    $timestamp24h = $timestamp - 24*3600

    $diffLive     = $Request.network.difficulty
    $reward       = if ($Request.network.reward) {$Request.network.reward} else {$Request.lastblock.reward}
    $profitLive   = 86400/$diffLive*$reward/$Divisor
    if ($Request.config.coinUnits) {$coinUnits = $Request.config.coinUnits}
    $amountLive   = $profitLive / $coinUnits

    if (-not $Currency) {$Currency = $Request.config.symbol}
    if (-not $chartCurrency -and $Request.config.priceCurrency) {$chartCurrency = $Request.config.priceCurrency}

    if     ($Request.price.btc)           {$lastSatPrice = 1e8*[Double]$Request.price.btc}
    elseif ($Request.coinPrice.priceSats) {$lastSatPrice = [Double]$Request.coinPrice.priceSats}
    elseif ($Request.coinPrice.price)     {$lastSatPrice = 1e8*[Double]$Request.coinPrice.price}
    elseif ($Request.coinPrice."coin-btc"){$lastSatPrice = 1e8*[Double]$Request.coinPrice."coin-btc"}
    else {
        $lastSatPrice = if ($Request.charts.price) {[Double]($Request.charts.price | Select-Object -Last 1)[1]} else {0}
        if ($chartCurrency -and $chartCurrency -ne "BTC" -and $Session.Rates.$chartCurrency) {$lastSatPrice *= 1e8/$Session.Rates.$chartCurrency}
        elseif ($chartCurrency -eq "BTC" -and $lastSatPrice -lt 1.0) {$lastSatPrice*=1e8}
        if (-not $lastSatPrice -and $Session.Rates.$Currency) {$lastSatPrice = 1/$Session.Rates.$Currency*1e8}
    }
    if ($lastSatPrice -and $Session.Rates -and -not $Session.Rates.$Currency) {$Session.Rates.$Currency = 1/$lastSatPrice*1e8}

    $rewards.Live.reward = $amountLive * $lastSatPrice        

    if ($addDay) {
        $averageDifficulties = if ($Request.pool.stats.diffs.wavg24h) {$Request.pool.stats.diffs.wavg24h} else {($Request.charts.difficulty | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average}
        if ($averageDifficulties) {
            $averagePrices = if ($Request.charts.price) {($Request.charts.price | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average} else {0}
            if ($chartCurrency -and $chartCurrency -ne "BTC" -and $Session.Rates.$chartCurrency) {$averagePrices *= 1e8/$Session.Rates.$chartCurrency}
            elseif ($chartCurrency -eq "BTC" -and $averagePrices -lt 1.0) {$averagePrices*=1e8}
            if (-not $averagePrices) {$averagePrices = $lastSatPrice}
            $profitDay = 86400/$averageDifficulties*$reward/$Divisor
            $amountDay = $profitDay/$coinUnits
            $rewardsDay = $amountDay * $averagePrices
        }
        $rewards.Day.reward   = if ($rewardsDay) {$rewardsDay} else {$rewards.Live.reward}
        $rewards.Day.hashrate = ($Request.charts.hashrate | Where-Object {$_[0] -gt $timestamp24h} | Foreach-Object {$_[1]} | Measure-Object -Average).Average
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
