Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-Type -Path .\OpenCL\*.cs

function Get-Balance {
    [CmdletBinding()]
    param($Config, $Rates, $NewRates)

    # If rates weren't specified, just use 1 BTC = 1 BTC
    if ($Rates -eq $Null) {
        $Rates = [PSCustomObject]@{BTC = [Double]1}
    }
    if ($NewRates -eq $Null) {
        try {
            Write-Log "Updating exchange rates from Coinbase. "
            $NewRates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
            $Config.Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Rates | Add-Member $_ ([Double]$NewRates.$_) -Force}
        }
        catch {
            Write-Log -Level Warn "Coinbase is down. "
        }
    }

    $Balances = @()

    try {
        if (Test-Path "Balances") {        
            @($Balances = Get-ChildItem "Balances" -File | Where-Object {@($Config.Pools.PSObject.Properties.Name | Where-Object {$Config.ExcludePoolName -inotcontains $_}) -like "$($_.BaseName)*"} | ForEach-Object {
                Get-ChildItemContent "Balances\$($_.Name)" -Parameters @{Config = $Config}
            } | Foreach-Object {$_.Content | Add-Member Name $_.Name -PassThru})

            $Balances.PSObject.Properties.Value.currency | Select-Object -Unique | Where-Object {-not $Rates.$_} | Foreach-Object {
                    if ($NewRates.$_) {$Value=$NewRates.$_}
                    else {$Value = [Double]1/(Get-Ticker -Symbol $_ | Select-Object -ExpandProperty BTC | Select-Object -ExpandProperty price)}                
                    $Rates | Add-Member $_ ([Double]$Value) -Force
            }

            # Add total of totals
            $Total = ($Balances | ForEach-Object {$_.total/$Rates."$($_.currency)"} | Measure-Object -Sum).Sum
            $Balances += [PSCustomObject]@{
                currency = "BTC"
                total = $Total
                Name  = "*Total*"
            }

            # Add local currency values
            $Balances | Foreach-Object {
                Foreach($Rate in ($Rates.PSObject.Properties)) {
                    $Value = $Rate.Value
                    if ($_.currency -ne "BTC") {$Value = if ($Rate.Name -eq $_.currency){[Double]1}else{[Double]($Value/$Rates."$($_.currency)")}}
                    # Round BTC to 8 decimals, everything else is based on BTC value
                    if ($Rate.Name -eq "BTC") {
                        $_ | Add-Member "Total_BTC" ("{0:N8}" -f ([Double]$Value * $_.total)) -Force
                    } 
                    else {
                        $_ | Add-Member "Total_$($Rate.Name)" (ConvertTo-LocalCurrency $($_.total) $Value -Offset 4) -Force
                    }
                }
            }
        }
    }
    catch {
        Write-Log -Level Warn "Trouble fetching Balances. "
    }
    Return $Balances
}

function Get-Ticker {
    [CmdletBinding()]
    param($Symbol, $Convert)

    if (-not $Convert) {$Convert="BTC"}

    if (-not (Test-Path Variable:Script:CoinmarketCapList)) {
        try {
            $Request = Invoke-RestMethod "https://api.coinmarketcap.com/v2/listings/" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        }
        catch {
            Write-Log -Level Warn "Coinmarketcap API (listings) has failed. "
        }

        if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
            Write-Log -Level Warn "Coinmarketcap API (listings) returned nothing. "
            return
        }
        $Script:CoinmarketCapList = $Request
    }

    $Symbol_ID = $Script:CoinmarketCapList.PSObject.Properties.Value | Where-Object {$_.symbol -eq $Symbol} | Select -ExpandProperty id
    if ( -not $Symbol_ID ) {
        Write-Log -Level Warn "$($Symbol) not found on Coinmarketcap "
        return
    }


    try {
        $Request = Invoke-RestMethod "https://api.coinmarketcap.com/v2/ticker/$($Symbol_ID)/?convert=$($Convert)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    }
    catch {
        Write-Log -Level Warn "Coinmarketcap API (ticker) has failed. "
    }

    if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
        Write-Log -Level Warn "Coinmarketcap API (ticker) returned nothing. "
        return
    }

    $Request | Select -ExpandProperty data | Select -ExpandProperty quotes        
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
        if (-not $PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference') }

        # Get mutex named MPMWriteLog. Mutexes are shared across all threads and processes.
        # This lets us ensure only one thread is trying to write to the file at a time.
        $mutex = New-Object System.Threading.Mutex($false, "MPMWriteLog")

        $filename = ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd").txt"
        $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}

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
            "$date $LevelText $Message" | Out-File -FilePath $filename -Append -Encoding utf8
            $mutex.ReleaseMutex()
        }
        else {
            Write-Error -Message "Log file is locked, unable to write message to $FileName."
        }
    }
    End {}
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
        [Double]$FaultTolerance = 0.1
    )

    $Updated = $Updated.ToUniversalTime()

    $Path = "Stats\$Name.txt"
    $SmallestValue = 1E-20

    try {
        $Stat = Get-Content $Path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

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
            Week = [Double]$Stat.Week
            Week_Fluctuation = [Double]$Stat.Week_Fluctuation
            Duration = [TimeSpan]$Stat.Duration
            Updated = [DateTime]$Stat.Updated
        }

        $ToleranceMin = $Value
        $ToleranceMax = $Value

        if ($FaultDetection) {
            if ( $FaultTolerance -eq $null ) { $FaultTolerance = 0.1 }
            $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance), 0.9))
            $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance), 0.9))
        }

        if ($ChangeDetection -and [Decimal]$Value -eq [Decimal]$Stat.Live) {$Updated = $Stat.updated}

        if ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax) {
            Write-Log -Level Warn "Stat file ($Name) was not updated because the value ($([Decimal]$Value)) is outside fault tolerance ($([Int]$ToleranceMin) to $([Int]$ToleranceMax)). "
        }
        else {
            $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
            $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
            $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
            $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
            $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
            $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

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
                Week = ((1 - $Span_Week) * $Stat.Week) + ($Span_Week * $Value)
                Week_Fluctuation = ((1 - $Span_Week) * $Stat.Week_Fluctuation) + 
                ($Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue)))
                Duration = $Stat.Duration + $Duration
                Updated = $Updated
            }
        }
    }
    catch {
        if (Test-Path $Path) {Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. $($error) "}

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
            Week = $Value
            Week_Fluctuation = 0
            Duration = $Duration
            Updated = $Updated
        }
    }

    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}
    [PSCustomObject]@{
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
        Week = [Decimal]$Stat.Week
        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
        Duration = [String]$Stat.Duration
        Updated = [DateTime]$Stat.Updated
    } | ConvertTo-Json | Set-Content $Path

    $Stat
}

function Get-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name
    )

    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}

    if ($Name) {
        # Return single requested stat
        Get-ChildItem "Stats" -File | Where-Object BaseName -EQ $Name | Get-Content | ConvertFrom-Json
    } else {
        # Return all stats
        $Stats = [PSCustomObject]@{}
        Get-ChildItem "Stats" | ForEach-Object {
            $BaseName = $_.BaseName
            $_ | Get-Content | ConvertFrom-Json -ErrorAction SilentlyContinue | ForEach-Object {
                $Stats | Add-Member $BaseName $_
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
        [Switch]$Force = $false
    )

    function Invoke-ExpressionRecursive ($Expression) {
        if ($Expression -is [String]) {
            if ($Expression -match '(\$|")') {
                try {$Expression = Invoke-Expression $Expression}
                catch {$Expression = Invoke-Expression "`"$Expression`""}
            }
        }
        elseif ($Expression -is [PSCustomObject]) {
            $Expression | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                $Expression.$_ = Invoke-ExpressionRecursive $Expression.$_
            }
        }
        return $Expression
    }

    Get-ChildItem $Path -File -ErrorAction SilentlyContinue | ForEach-Object {
        $Name = $_.BaseName
        $Content = @()
        if ($_.Extension -eq ".ps1") {
            $Content = & {
                $Parameters.Keys | ForEach-Object {Set-Variable $_ $Parameters.$_}
                & $_.FullName @Parameters
            }
        }
        else {
            $Content = & {
                $Parameters.Keys | ForEach-Object {Set-Variable $_ $Parameters.$_}
                try {
                    ($_ | Get-Content | ConvertFrom-Json) | ForEach-Object {Invoke-ExpressionRecursive $_}
                }
                catch [ArgumentException] {
                    $null
                }
            }
            if ($Content -eq $null) {$Content = $_ | Get-Content}
        }
        $Content | ForEach-Object {
            if ($_.Name) {
                [PSCustomObject]@{Name = $_.Name; BaseName = $Name; Content = $_}
            }
            else {
                [PSCustomObject]@{Name = $Name; BaseName = $Name; Content = $_}
            }
        }
        if ( $Force ) {
            $Parameters.Keys | ForEach-Object {
                if ( -not (Get-Member -InputObject $Content -Name $_ -Membertype Properties) ) {
                    $Content | Add-Member $_ $Parameters.$_ -Force 
                }
            }
        }
    }
}

filter ConvertTo-Hash { 
    [CmdletBinding()]
    $Hash = $_
    switch ([math]::truncate([math]::log($Hash, 1000))) {
        "-Infinity" {"0  H"}
        0 {"{0:n2}  H" -f ($Hash / 1)}
        1 {"{0:n2} KH" -f ($Hash / 1000)}
        2 {"{0:n2} MH" -f ($Hash / 1000000)}
        3 {"{0:n2} GH" -f ($Hash / 1000000000)}
        4 {"{0:n2} TH" -f ($Hash / 1000000000000)}
        Default {"{0:n2} PH" -f ($Hash / 1000000000000000)}
    }
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
        [String]$ProcessName = "",
        [Parameter(Mandatory = $false)]
        [Bool]$ShowMinerWindow = $false
    )

    if ( $ShowMinerWindow ) {
        Start-SubProcessInConsole -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -ProcessName $ProcessName
    } else {
        Start-SubProcessInBackground -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -ProcessName $ProcessName
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
        [String]$ProcessName = ""
    )

    $ExecName = ([io.fileinfo]($FilePath | Split-Path -Leaf -ErrorAction Ignore)).BaseName
    if ( $ProcessName -ne "" -and $ProcessName -ne $ExecName ) { $ExecName = $ProcessName }
    $Running = @(Get-Process | Where-Object { $_.Name -eq $ExecName } | Select-Object -ExpandProperty Id)


    $ScriptBlock = "Set-Location '$WorkingDirectory'; (Get-Process -Id `$PID).PriorityClass = '$(@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority])'; "
    $ScriptBlock += "& '$FilePath'"
    if ($ArgumentList) {$ScriptBlock += " $ArgumentList"}
    $ScriptBlock += " *>&1"
    $ScriptBlock += " | Write-Output"
    if ($LogPath) {$ScriptBlock += " | Tee-Object '$LogPath'"}

    $Job = Start-Job ([ScriptBlock]::Create($ScriptBlock))

    $wait_count = 0;
    do{
        Start-Sleep 1;
        $Process = Get-Process | Where-Object { $_.Name -eq $ExecName -and $Running -notcontains $_.Id } | Select-Object -First 1
        $wait_count++
    } while ($Process -eq $null -and $wait_count -le 5)

    if ( $Process ) {
        $Process.PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]
        $Job | Add-Member MiningProcess $Process -Force -ErrorAction Ignore
    }
    $Job
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
        [String]$ProcessName = ""
    )

    $ExecName = ([io.fileinfo]($FilePath | Split-Path -Leaf -ErrorAction Ignore)).BaseName
    if ( $ProcessName -eq $ExecName ) { $ProcessName = "" }

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $ProcessName {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $ProcessName)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        if ($ProcessName -ne "") {
            $Running = @(Get-Process | Where-Object { $_.Name -eq $ProcessName } | Select-Object -ExpandProperty Id)
        }

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        $ProcessParam.Add("WindowStyle", 'Minimized')
        if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
        if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
        #if ($LogPath -ne "") {$ProcessParam.Add("RedirectStandardOutput", $LogPath);}

        $Process = Start-Process @ProcessParam -PassThru
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

       if ( $ProcessName -ne "" ) {
            $wait_count = 0;
            do{
                Start-Sleep 1;
                $Process = Get-Process | Where-Object { $_.Name -eq $ProcessName -and $Running -notcontains $_.Id } | Select-Object -First 1
                $wait_count++;
            } while ($Process -eq $null -and $wait_count -le 5);
        }
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -eq $JobOutput.ProcessId

    if ($Process) {
        $Process.PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]
        $Job | Add-Member MiningProcess $Process -Force -ErrorAction Ignore
    }

    $Job
}

function Expand-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $false)]
        [String]$Path = ""
    )

    # Set current path used by .net methods to the same as the script's path
    [Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads")) {New-Item "Downloads" -ItemType "directory" | Out-Null}
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName) {Remove-Item $FileName}
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        Start-Process $FileName "-qb" -Wait
    }
    else {
        $Path_Old = (Join-Path (Split-Path $Path) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
        $Path_New = (Join-Path (Split-Path $Path) (Split-Path $Path -Leaf))

        if (Test-Path $Path_Old) {Remove-Item $Path_Old -Recurse -Force}
        Start-Process "7z" "x `"$([IO.Path]::GetFullPath($FileName))`" -o`"$([IO.Path]::GetFullPath($Path_Old))`" -y -spe" -Wait

        if (Test-Path $Path_New) {Remove-Item $Path_New -Recurse -Force}
        if (Get-ChildItem $Path_Old | Where-Object PSIsContainer -EQ $false) {
            Rename-Item $Path_Old (Split-Path $Path -Leaf)
        }
        else {
            Get-ChildItem $Path_Old | Where-Object PSIsContainer -EQ $true | ForEach-Object {Move-Item (Join-Path $Path_Old $_) $Path_New}
            Remove-Item $Path_Old
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
        [Parameter(Mandatory = $true)]
        [String]$Request, 
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        $Response = $Reader.ReadLine()
    }
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }

    $Response
}

function Get-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @()
    )

    $Devices = Get-Content "Devices.txt" | ConvertFrom-Json

    if ($Name) {
        $Name_Devices = $Name | ForEach-Object {
            $Name_Split = $_ -split '#'
            $Name_Split = @($Name_Split | Select-Object -First 1) + @($Name_Split | Select-Object -Skip 1 | ForEach-Object {[Int]$_})
            $Name_Split += @("*") * (100 - $Name_Split.Count)

            $Name_Device = $Devices.("{0}" -f $Name_Split) | Select-Object *
            $Name_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}

            $Name_Device
        }
    }

    $PlatformId = 0
    $Index = 0
    $PlatformId_Index = @{}
    $Type_PlatformId_Index = @{}
    $Vendor_Index = @{}
    $Type_Vendor_Index = @{}
    $Type_Index = @{}

    try {
        [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
            [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | ForEach-Object {
                $Device_OpenCL = $_ | ConvertTo-Json | ConvertFrom-Json
                $Device = [PSCustomObject]@{
                    Index = [Int]$Index
                    PlatformId = [Int]$PlatformId
                    PlatformId_Index = [Int]$PlatformId_Index.($PlatformId)
                    Type_PlatformId_Index = [Int]$Type_PlatformId_Index.($Device_OpenCL.Type).($PlatformId)
                    Vendor = [String]$Device_OpenCL.Vendor
                    Vendor_Index = [Int]$Vendor_Index.($Device_OpenCL.Vendor)
                    Type_Vendor_Index = [Int]$Type_Vendor_Index.($Device_OpenCL.Type).($Device_OpenCL.Vendor)
                    Type = [String]$Device_OpenCL.Type
                    Type_Index = [Int]$Type_Index.($Device_OpenCL.Type)
                    OpenCL = $Device_OpenCL
                    Model = [String]$(if ($Device_OpenCL.Type -eq "Cpu"){"CPU"}else{$Device_OpenCL.Name -replace "[^A-Za-z0-9]+","" -replace "GeForce|(R)|Intel",""})
                    Model_Name = [String]$Device_OpenCL.Name
                }

                if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) {
                    $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
                }

                if (-not $Type_PlatformId_Index.($Device_OpenCL.Type)) {
                    $Type_PlatformId_Index.($Device_OpenCL.Type) = @{}
                }
                if (-not $Type_Vendor_Index.($Device_OpenCL.Type)) {
                    $Type_Vendor_Index.($Device_OpenCL.Type) = @{}
                }

                $Index++
                $PlatformId_Index.($PlatformId)++
                $Type_PlatformId_Index.($Device_OpenCL.Type).($PlatformId)++
                $Vendor_Index.($Device_OpenCL.Vendor)++
                $Type_Vendor_Index.($Device_OpenCL.Type).($Device_OpenCL.Vendor)++
                $Type_Index.($Device_OpenCL.Type)++
            }

            $PlatformId++
        }
    }
    catch {
        Write-Log -Level Warn "OpenCL device detection has failed. "
    }

    if (-not $Index) {
        $Device = [PSCustomObject]@{
            Index = [Int]$null
            PlatformId = [Int]$null
            PlatformId_Index = [Int]$null
            Type_PlatformId_Index = [Int]$null
            Vendor = [String]$null
            Vendor_Index = [Int]$null
            Type_Vendor_Index = [Int]$null
            Type = [String]"Cpu"
            Type_Index = [Int]$null
            OpenCL = $null
            Model = [String]"CPU"
        }

        $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
    }
}

function Get-ComputeData {

#UselessGuru: reads current GPU compute usage and power draw and from device
#
# returned values are:
#         PowerDraw:    0 - max (in watts)
#         ComputeUsage: 0 - 100 (percent)
#  Requirements for Nvidia:  nvidia-smi.exe (part of driver package)
#  Requirements for AMD:     unknown

[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String[]]$MinerType,
        [Parameter(Mandatory = $false)]
        [String]$Index
    )

    # Write-Log -Level "Debug" -Message "Entering $($MyInvocation.MyCommand): '`$MinerType=$($MinerType)', '`$Index=$($Index)'"

    $ComputerUsageSum = 0
    $ComputeUsageCount = 0

    $PowerDrawSum = 0
    $Temperature = [Decimal[]]@()
    
    switch ($MinerType) {
        "NVIDIA" {
            $NvidiaSMI = "$Env:SystemDrive\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
            if (Test-Path $NvidiaSMI) {
                if ($Index -notmatch "^[0-9].*") { <# Index must start with a number, otherwise read cumulated power#>
                    $Index = ((&$NvidiaSMI -L) | ForEach {$_.Split(" ")[1].Split(":")[0]}) -join ","
                }
                $Index.Split(",") | ForEach {
                    $idx = $_
                    $Loop = 1
                    do {
                        $Readout = (&$NvidiaSMI -i $idx --format=csv,noheader,nounits --query-gpu=utilization.gpu)
                        # Write-Log -Level "Debug" -Message "$($MyInvocation.MyCommand) reading GPU usage [Try $($Loop) of 3]: '`$MinerType=$($MinerType)', '`$Index=$($Index)', '`$Idx=$($Idx)', '`$Readout=$($Readout)'"
                        Try {
                            $ComputeUsageSum += [Decimal]$Readout
                            if ($Readout -gt 0) {$ComputeUsageCount++}
                        }
                        catch {}
                        $Loop++
                    }
                    until ($Readout -gt 0 -or $Loop -gt 3)
                    
                    if ($Readout -gt 0) {
                        $Loop = 1
                        do {
                            $Readout = (&$NvidiaSMI -i $idx --format=csv,noheader,nounits --query-gpu=power.draw)
                            # Write-Log -Level "Debug" -Message "$($MyInvocation.MyCommand) reading power draw [Try $($Loop) of 3]: '`$MinerType=$($MinerType)', '`$Index=$($Index)', '`$Idx=$($Idx)', '`$Readout=$($Readout)'"
                            try {
                                $PowerDrawSum += [Decimal]$Readout
                            }
                            catch {}
                            $Loop ++
                        }
                        until ($Readout -gt 0 -or $Loop -gt 3)
                    }

                    if ($Readout -gt 0) {
                        $Loop = 1
                        do {
                            $Readout = (&$NvidiaSMI -i $idx --format=csv,noheader,nounits --query-gpu=temperature.gpu)
                            # Write-Log -Level "Debug" -Message  "$($MyInvocation.MyCommand) reading temperature [Try $($Loop) of 3]: '`$MinerType=$($MinerType)', '`$Index=$($Index)', '`$Idx=$($Idx)', '`$Readout=$($Readout)'"
                            try {
                                $Temperature += [Decimal]$Readout
                            }
                            catch {
                                if ($Loop -eq 3) {$Temperature += [Decimal]-1}
                            }
                            $Loop ++
                        }
                        until ($Readout -gt 0 -or $Loop -gt 3)
                    }
                }
            }
        }
#        "AMD" { # To be implemented
#            for ($i = 0; $i -lt (&$NvidiaSMI -L).Count; $i++) {
#                $PowerDraw =+ [Double](&$NvidiaSMI -i $i --format=csv,noheader,nounits --query-gpu=power.draw)
#                $ComputeUsageSum =+ [Double](&$NvidiaSMI -i $i --format=csv,noheader,nounits --query-gpu=utilization.gpu)
#            }
#            $ComputeUsageCount += $i
#        }
        "CPU"  {
            $PowerDrawSum += $CPU_PowerDraw
            $ComputeUsageSum += 100
            $ComputeUsageCount++
        }
    }

    if ($ComputeUsageSum -gt 0 -and $ComputeUsageSum -gt 0) {$ComputeUsage = $ComputeUsageSum / $ComputeUsageCount} else {$ComputeUsage = 0}

    $ComputeData = [PSCustomObject]@{
        PowerDraw    = [Decimal]$PowerDrawSum
        ComputeUsage = [Decimal]$ComputeUsage
        Temperature = [Decimal[]]$Temperature
    }

    # Write-Log -Level "Debug" -Message "Exiting $($MyInvocation.MyCommand): '`$ComputeData=$($ComputeData)'"

    $ComputeData
}

function Get-Algorithm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = ""
    )

    if (-not (Test-Path Variable:Script:Algorithms)) {
        $Script:Algorithms = Get-Content "Algorithms.txt" | ConvertFrom-Json
    }

    $Algorithm = (Get-Culture).TextInfo.ToTitleCase(($Algorithm -replace "-", " " -replace "_", " ")) -replace " "

    if ($Script:Algorithms.$Algorithm) {$Script:Algorithms.$Algorithm}
    else {$Algorithm}
}

function Get-Region {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )

    if (-not (Test-Path Variable:Script:Regions)) {
        $Script:Regions = Get-Content "Regions.txt" | ConvertFrom-Json
    }
    
    $Region = (Get-Culture).TextInfo.ToTitleCase(($Region -replace "-", " " -replace "_", " ")) -replace " "

    if ($Script:Regions.$Region) {$Script:Regions.$Region}
    else {$Region}
}

function Get-Algorithms {
    if (-not (Test-Path Variable:Script:Algorithms)) {
        $Script:Algorithms = Get-Content "Algorithms.txt" | ConvertFrom-Json
    }
    $Script:Algorithms.PSObject.Properties | Where-Object MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
}

function Get-Regions {
    if (-not (Test-Path Variable:Script:Regions)) {
        $Script:Regions = Get-Content "Regions.txt" | ConvertFrom-Json
    }
    $Script:Regions.PSObject.Properties | Where-Object MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
}

enum MinerStatus {
    Running
    Idle
    Failed
}

class Miner {
    $Name
    $Path
    $Arguments
    $Wrap
    $API
    $Port
    [string[]]$Algorithm = @()
    $DeviceName
    $DeviceModel
    $Profit
    $Profit_Comparison
    $Profit_MarginOfError
    $Profit_Bias
    $Profit_Unbias
    $Speed
    $Speed_Live
    $Best
    $Best_Comparison
    hidden [System.Management.Automation.Job]$Process = $null
    $New
    hidden [TimeSpan]$Active = [TimeSpan]::Zero
    hidden [Int]$Activated = 0
    hidden [MinerStatus]$Status = [MinerStatus]::Idle
    $Benchmarked
    $LogFile
    $Pool
    hidden [Array]$Data = @()
    [Bool]$ShowMinerWindow = $false
    $MSIAprofile
    $BenchmarkIntervals = 1
    $DevFee
    $BaseName = $null
    $ExecName = $null
    $FaultTolerance = 0.1

    [String[]]GetProcessNames() {
        return @(([IO.FileInfo]($this.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName)
    }

    hidden StartMining() {
        $this.StopMining();

        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++

        if (-not $this.Process) {
            $this.LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            $this.Process = Start-SubProcess -FilePath $this.Path -ArgumentList $this.Arguments -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {-2}else {1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $this.ShowMinerWindow -ProcessName $this.ExecName

            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Status = [MinerStatus]::Running
            }
        }
    }

    hidden StopMining() {
        $this.Status = [MinerStatus]::Failed

        $this.Data = @()

        if ($this.Process) {
            if ( $this.ShowMinerWindow -and $this.Process.MiningProcess ) {
                $this.Process.MiningProcess.CloseMainWindow() | Out-Null
                # Wait up to 10 seconds for the miner to close gracefully
                $closedgracefully = $this.Process.MiningProcess.WaitForExit(10000)
                if($closedgracefully) { 
                    Write-Log "$($this.Type) miner $($this.Name) closed gracefully" 
                } else {
                    Write-Log -Level Warning "$($this.Type) miner $($this.Name) failed to close within 10 seconds"
                    if(!$this.Process.MiningProcess.HasExited) {
                        Write-Log -Level Warning "Attempting to kill $($this.Type) miner $($this.Name) PID $($this.Process.Id)"
                        $this.Process.MiningProcess.Kill()
                    }
                }
            }
            if ($this.Process | Get-Job -ErrorAction SilentlyContinue) {
                $this.Process | Remove-Job -Force
            }

            if (-not ($this.Process | Get-Job -ErrorAction SilentlyContinue)) {
                $this.Active = $this.GetActiveTime();
                $this.Process = $null
                $this.Status = [MinerStatus]::Idle
            }
        }
    }

    [DateTime]GetActiveStart() {
        $Begin = if ( $this.Process.MiningProcess ) {$this.Process.MiningProcess.StartTime} else {$this.Process.PSBeginTime}

        if ($Begin) {
            return $Begin
        }
        else {
            return [DateTime]::MinValue
        }
    }

    [DateTime]GetActiveLast() {
        $Begin = if ( $this.Process.MiningProcess ) {$this.Process.MiningProcess.StartTime} else {$this.Process.PSBeginTime}
        $End   = if ( $this.Process.MiningProcess ) {$this.Process.MiningProcess.ExitTime} else {$this.Process.PSEndTime}

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
        $Begin = if ( $this.Process.MiningProcess ) {$this.Process.MiningProcess.StartTime} else {$this.Process.PSBeginTime}
        $End   = if ( $this.Process.MiningProcess ) {$this.Process.MiningProcess.ExitTime} else {$this.Process.PSEndTime}
        
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

    [MinerStatus]GetStatus() {
        if ((-not $this.Process.MiningProcess -and $this.Process.State -eq "Running") -or ($this.Process.MiningProcess -and -not $this.Process.MiningProcess.HasExited) ) {
            return [MinerStatus]::Running
        }
        elseif ($this.Status -eq [MinerStatus]::Running) {
            return [MinerStatus]::Failed
        }
        else {
            return $this.Status
        }
    }

    [Int]GetProcessId() {
        if ( $this.Process.MiningProcess ) {
            return $this.Process.MiningProcess.Id;
        } else {
            return 0;
        }
    }

    SetStatus([MinerStatus]$Status) {
        if ($Status -eq $this.GetStatus()) {return}

        switch ($Status) {
            Running {
                $this.StartMining()
            }
            Idle {
                $this.StopMining()
            }
            Default {
                $this.StopMining()
                $this.Status = [MinerStatus]$Status
            }
        }
    }

    [String[]]UpdateMinerData () {
        $Lines = @()

        if ($this.Process.HasMoreData) {
            $Date = (Get-Date).ToUniversalTime()

            $this.Process | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""

                if ($Line_Simple) {
                    $HashRates = @()
                    $Devices = @()

                    if ($Line_Simple -match "/s") {
                        $Words = $Line_Simple -split " "

                        $Words -match "/s$" | ForEach-Object {
                            if (($Words | Select-Object -Index $Words.IndexOf($_)) -match "^((?:\d*\.)?\d+)(.*)$") {
                                $HashRate = ($matches | Select-Object -Index 1) -as [Decimal]
                                $HashRate_Unit = ($matches | Select-Object -Index 2)
                            }
                            else {
                                $HashRate = ($Words | Select-Object -Index ($Words.IndexOf($_) - 1)) -as [Decimal]
                                $HashRate_Unit = ($Words | Select-Object -Index $Words.IndexOf($_))
                            }

                            switch -wildcard ($HashRate_Unit) {
                                "kh/s*" {$HashRate *= [Math]::Pow(1000, 1)}
                                "mh/s*" {$HashRate *= [Math]::Pow(1000, 2)}
                                "gh/s*" {$HashRate *= [Math]::Pow(1000, 3)}
                                "th/s*" {$HashRate *= [Math]::Pow(1000, 4)}
                                "ph/s*" {$HashRate *= [Math]::Pow(1000, 5)}
                            }

                            $HashRates += $HashRate
                        }
                    }

                    if ($Line_Simple -match "gpu|cpu|device") {
                        $Words = $Line_Simple -replace "#", "" -replace ":", "" -split " "

                        $Words -match "^gpu|^cpu|^device" | ForEach-Object {
                            if (($Words | Select-Object -Index $Words.IndexOf($_)) -match "^(.*)((?:\d*\.)?\d+)$") {
                                $Device = ($matches | Select-Object -Index 2) -as [Int]
                                $Device_Type = ($matches | Select-Object -Index 1)
                            }
                            else {
                                $Device = ($Words | Select-Object -Index ($Words.IndexOf($_) + 1)) -as [Int]
                                $Device_Type = ($Words | Select-Object -Index $Words.IndexOf($_))
                            }

                            $Devices += "{0}#{1:d2}" -f $Device_Type, $Device
                        }
                    }

                    $Lines += $Line

                    $this.Data += [PSCustomObject]@{
                        Date = $Date
                        Raw = $Line_Simple
                        HashRate = [PSCustomObject]@{[String]$this.Algorithm = $HashRates}
                        Device = $Devices
                    }
                }
            }

            $this.Data = @($this.Data | Select-Object -Last 10000)
        }

        return $Lines
    }

    [Int64]GetHashRate([String]$Algorithm = [String]$this.Algorithm, [Int]$Seconds = 60, [Boolean]$Safe = $this.New) {
        $HashRates_Devices = @($this.Data | Where-Object Device | Select-Object -ExpandProperty Device -Unique)
        if (-not $HashRates_Devices) {$HashRates_Devices = @("Device")}

        $HashRates_Counts = @{}
        $HashRates_Averages = @{}
        $HashRates_Variances = @{}

        $this.Data | Where-Object HashRate | Where-Object Date -GE (Get-Date).ToUniversalTime().AddSeconds( - $Seconds) | ForEach-Object {
            $Data_Devices = $_.Device
            if (-not $Data_Devices) {$Data_Devices = $HashRates_Devices}

            $Data_HashRates = $_.HashRate.$Algorithm

            $Data_Devices | ForEach-Object {$HashRates_Counts.$_++}
            $Data_Devices | ForEach-Object {$HashRates_Averages.$_ += @(($Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum) / $Data_Devices.Count)}
            $HashRates_Variances."$($Data_Devices | ConvertTo-Json)" += @($Data_HashRates | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
        }

        $HashRates_Count = $HashRates_Counts.Values | ForEach-Object {$_} | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $HashRates_Average = ($HashRates_Averages.Values | ForEach-Object {$_} | Measure-Object -Average | Select-Object -ExpandProperty Average) * $HashRates_Averages.Keys.Count
        $HashRates_Variance = $HashRates_Variances.Keys | ForEach-Object {$_} | ForEach-Object {$HashRates_Variances.$_ | Measure-Object -Average -Minimum -Maximum} | ForEach-Object {if ($_.Average) {($_.Maximum - $_.Minimum) / $_.Average}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

        if ($Safe) {
            if ($HashRates_Count -lt 3 -or $HashRates_Variance -gt 0.05) {
                return 0
            }
            else {
                return $HashRates_Average * (1 + ($HashRates_Variance / 2))
            }
        }
        else {
            return $HashRates_Average
        }
    }

    [bool]HasDevFees() {
        return $this.DevFee -and ($this.Algorithm.PSObject.Properties.Value | Measure-Object -Sum).Sum
    }

    [array]GetDevFees() {
        return @($this.HashRates.PSObject.Properties.Name | Foreach-Object {$this.DevFee.$_})
    }
}

function Get-GPUtypeslist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$Type = @() #AMD/NVIDIA
    )
    if ( -not $Type.Count ) { $Type = "AMD","NVIDIA" }
    $Type | Foreach-Object {if ($_ -like "*AMD*" -or $_ -like "*Advanced Micro*"){"AMD","Advanced Micro Devices","Advanced Micro Devices, Inc."}elseif($_ -like "*NVIDIA*" ){"NVIDIA","NVIDIA Corporation"}elseif($_ -like "*INTEL*"){"INTEL","Intel(R) Corporation"}else{$_}} | Select-Object -Unique
}

function Get-GPUplatformID {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Type = "" #AMD/NVIDIA
    )
    $Types = Get-GPUtypeslist $Type
    $IxFound = -1
    $Ix = -1
    [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object { $Ix++; if ( Compare-Object $_.Vendor $Types -IncludeEqual -ExcludeDifferent ) { $IxFound = $Ix } }
    $IxFound
}

function Select-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject[]]$Devices,
        [Parameter(Mandatory = $False)]
        [Array]$Type = @(), #CPU/AMD/NVIDIA
        [Parameter(Mandatory = $False)]
        [Long]$MinMemSize = 0
    )
    $GPUVendors = Get-GPUtypeslist $Type
    $Devices | Where-Object { ($_.Type -eq "CPU" -and $Type -contains "CPU") -or ($_.Type -eq "GPU" -and $_.OpenCL.GlobalMemsize -ge $MinMemSize -and (Compare-Object $_.Vendor $GPUVendors -IncludeEqual -ExcludeDifferent)) }
}

function Get-DeviceVendor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Device
    )
    @("AMD","NVIDIA","INTEL") | Foreach-Object {
        $GPUVendors = Get-GPUtypeslist $_
        if (Compare-Object $Device.Vendor $GPUVendors -IncludeEqual -ExcludeDifferent){$_}
    }
}

function Get-DeviceModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Device
    )
    ($Device | Select-Object -Index 0) | Where-Object {"NVIDIA","AMD","CPU" -inotcontains $_.Model} | Select-Object -ExcludeProperty Model
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
    $GPUIDs = $Devices | Select -ExpandProperty PlatformId_Index -ErrorAction Ignore | Foreach-Object { if ($ToHex) {[Convert]::ToString($_ + $Offset,16)} else {$_ + $Offset} }
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
        Write-Log -Level Warn "[Test-TimeSync] Something went wrong"
    }

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
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default){" [default=$($Default)]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result -replace "[^$($Characters)]+",""}
        if ("del","delete","dele","clr","cls","clear","cl" -icontains $Result){$Result=''}
        if (@("help","list") -icontains $Result) {
            if ($Valid.Count -gt 0) {Write-Host "Valid inputs are from the following list:";Write-Host $($Valid -join ",");Write-Host " "}
            else {Write-Host "Every input will be valid. So, take care :)";Write-Host " "}
            $Repeat = $true
        }
        elseif ($Mandatory -or $Result.Length -gt 0) {
            if ($Length -gt 0 -and $Result.Length -ne $Length) {Write-Host "The input must be exactly $($Length) characters long";Write-Host " ";$Repeat = $true}
            if ($MinLength -gt 0 -and $Result.Length -lt $MinLength) {Write-Host "The input is shorter than the minimum of $($Length) characters";Write-Host " ";$Repeat = $true}
            if ($MaxLength -gt 0 -and $Result.Length -gt $MaxLength) {Write-Host "The input is longer than the maximum of $($Length) characters";Write-Host " ";$Repeat = $true}
            if ($Valid.Count -gt 0 -and $Valid -inotcontains $Result) {Write-Host "Invalid input (type `"list`" to show all valid)";Write-Host " ";$Repeat = $true}
        }
    } until (-not $Repeat -and ($Result.Length -gt 0 -or -not $Mandatory))
    $Result
}

function Read-HostArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Prompt,
        [Parameter(Mandatory = $False)]
        $Default = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$Mandatory = $False,
        [Parameter(Mandatory = $False)]
        [String]$Characters = "A-Z0-9",
        [Parameter(Mandatory = $False)]
        [Array]$Valid = @()
    )
    if ($Default -is [String]) {$Default = $Default.Trim(); $Default = if ($Default -ne ''){[regex]::split($Default,"[,;:\s]+")}else{@()}}
    do{
        $Repeat = $false
        $Result = if (([String]$Result=(Read-Host "$($Prompt)$(if ($Default){" [default=$($Default -join ",")]"})$(if ($Mandatory){"*"})").Trim()) -eq ''){$Default}else{$Result -replace "[^$($Characters),;\s]+","" -split "[,;\s]+"}
        if ("del","delete","dele","clr","cls","clear","cl" -icontains $Result){$Result=@()}
        if (Compare-Object $Result @("help","list") -ExcludeDifferent -IncludeEqual) {
            if ($Valid.Count -gt 0) {Write-Host "Valid inputs are from the following list:";Write-Host $($Valid -join ",")}
            else {Write-Host "Every input will be valid. So, take care :)";Write-Host " "}
            $Repeat = $true
        } elseif ($Valid.Count -gt 0) {
            if ($Invalid = Compare-Object $Result $Valid | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) {
                Write-Host "The following entries are invalid (type `"list`" to show all valid):"
                Write-Host $($Invalid -join ",")
                Write-Host " "
                $Repeat = $true
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
    if ($Default -isnot [bool]){$Default = "yes","y","1","j","ja","oui","si","da" -icontains $Default}
    [Bool]$(if (([String]$Result=(Read-Host "$($Prompt) (yes/no) [default=$(if($Default){"yes"}else{"no"})]").Trim()) -eq ''){$Default}else{"yes","y","1","j","ja","oui","si","da" -icontains $Result})
}

