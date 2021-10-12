
function Initialize-Session {

    Set-OsFlags

    if (-not (Test-Path Variable:Global:Session)) {
        $Global:Session = [hashtable]::Synchronized(@{})

        if ($IsWindows) {
            $Session.WindowsVersion = [System.Environment]::OSVersion.Version
            $Session.IsWin10        = [System.Environment]::OSVersion.Version -ge (Get-Version "10.0")
        } elseif ($IsLinux) {
            try {
                Get-ChildItem ".\IncludesLinux\bin\libc_version" -File -ErrorAction Stop | Foreach-Object {
                    & chmod +x "$($_.FullName)" > $null
                    $Session.LibCVersion = Get-Version "$(& $_.FullName)"
                }
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }
        $Session.IsAdmin            = Test-IsElevated
        $Session.IsCore             = $PSVersionTable.PSVersion -ge (Get-Version "6.1")
        $Session.IsPS7              = $PSVersionTable.PSVersion -ge (Get-Version "7.0")
        $Session.MachineName        = [System.Environment]::MachineName
        $Session.MyIP               = Get-MyIP
        $Session.MainPath           = "$PWD"

        Set-Variable RegexAlgoHasEthproxy -Option Constant -Scope Global -Value "^Etc?hash|ProgPow|UbqHash"
        Set-Variable RegexAlgoHasDAGSize -Option Constant -Scope Global -Value "^Etc?hash|^KawPow|ProgPow|^FiroPow|UbqHash|Octopus"
        Set-Variable RegexAlgoIsEthash -Option Constant -Scope Global -Value "^Etc?hash|UbqHash"
        Set-Variable RegexAlgoIsProgPow -Option Constant -Scope Global -Value "^KawPow|ProgPow|^FiroPow"
    }
}

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
    $ver1 = ($Version1 -Split '-' -Replace "[^0-9.]")[0] -split '\.'
    $ver2 = ($Version2 -Split '-' -Replace "[^0-9.]")[0] -split '\.'
    $max = [Math]::min($ver1.Count,$ver2.Count)
    if ($revs -gt 0 -and $revs -lt $max) {$max = $revs}

    for($i=0;$i -lt $max;$i++) {
        if ([int]$ver1[$i] -lt [int]$ver2[$i]) {return -1}
        if ([int]$ver1[$i] -gt [int]$ver2[$i]) {return 1}
    }
    return 0
}

function Confirm-Version {
    [CmdletBinding()]
    param($RBMVersion, [Switch]$Force = $false, [Switch]$Silent = $false)

    $Name = "RainbowMiner"
    if ($Force -or -not (Test-Path Variable:Global:GlobalVersion) -or (Get-Date).ToUniversalTime() -ge $Global:GlobalVersion.NextCheck) {

        $RBMVersion = $Version = Get-Version($RBMVersion)
        $Uri = ""
        $NextCheck = (Get-Date).ToUniversalTime()

        try {
            $ReposURI = "https://api.github.com/repos/rainbowminer/$Name/releases/latest"
            if ($Force) {
                $Request = Invoke-GetUrl $ReposURI -timeout 20
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
        $Global:GlobalVersion = [PSCustomObject]@{
            Version = $RBMVersion
            RemoteVersion = $Version
            DownloadURI = $Uri
            ManualURI = "https://github.com/RainbowMiner/$Name/releases"
            NextCheck = $NextCheck
        }
    }

    if (-not $Silent) {
        if ($Global:GlobalVersion.RemoteVersion -gt $Global:GlobalVersion.Version) {
            Write-Log -Level Warn "$Name is out of date: lastest release version v$($Global:GlobalVersion.RemoteVersion) is available."
        } elseif ($Global:GlobalVersion.RemoteVersion -lt $Global:GlobalVersion.Version) {
            Write-Log -Level Warn "You are running $Name prerelease v$RBMVersion. Use at your own risk."
        }
    }
    $Global:GlobalVersion
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
        {$_ -match "^RTX30\d{2}"                             -or $_ -match "^AM"} {"Ampere";Break}
        {$_ -match "^RTX20\d{2}" -or $_ -match "^GTX16\d{2}" -or $_ -match "^TU"} {"Turing";Break}
        {$_ -match "^GTX10\d{2}" -or $_ -match "^GTXTitanX" -or $_ -match "^GP" -or $_ -match "^P"} {"Pascal";Break}
        default {"Other"}
    }
}

function Get-PoolPayoutCurrencies {
    param($Pool)
    $Payout_Currencies = [PSCustomObject]@{}
    if (-not (Test-Path Variable:Global:GlobalPoolFields)) {
        $Setup = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1"
        $Global:GlobalPoolFields = @($Setup.PSObject.Properties.Value | Where-Object {$_.Fields} | Foreach-Object {$_.Fields.PSObject.Properties.Name} | Select-Object) + @("Worker","DataWindow","Penalty","Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","MinerName","ExcludeMinerName","FocusWallet","Wallets","EnableAutoCoin","EnablePostBlockMining") | Sort-Object -Unique
    }
    @($Pool.PSObject.Properties) | Where-Object Membertype -eq "NoteProperty" | Where-Object {$_.Value -is [string] -and ($_.Value.Length -gt 2 -or $_.Value -eq "`$Wallet" -or $_.Value -eq "`$$($_.Name)") -and $Global:GlobalPoolFields -inotcontains $_.Name -and $_.Name -notmatch "-Params$" -and $_.Name -notmatch "^#"} | Select-Object Name,Value -Unique | Sort-Object Name,Value | Foreach-Object{$Payout_Currencies | Add-Member $_.Name $_.Value}
    $Payout_Currencies
}

function Get-UnprofitableAlgos {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-GetUrlAsync "https://rbminer.net/api/data/unprofitable3.json" -cycletime 3600 -Jobkey "unprofitable3"
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Unprofitable algo API failed. "
    }

    if ($Request.Algorithms -and $Request.Algorithms.Count -gt 10) {
        Set-ContentJson -PathToFile ".\Data\unprofitable.json" -Data $Request -MD5hash $Global:GlobalUnprofitableAlgosHash > $null
    } elseif (Test-Path ".\Data\unprofitable.json") {
        try{
            $Request = Get-ContentByStreamReader ".\Data\unprofitable.json" | ConvertFrom-Json -ErrorAction Ignore
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Unprofitable database is corrupt. "
        }
    }
    $Global:GlobalUnprofitableAlgosHash = Get-ContentDataMD5hash $Request
    $Request
}

function Get-UnprofitableCpuAlgos {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-GetUrlAsync "https://rbminer.net/api/data/unprofitable-cpu.json" -cycletime 3600 -Jobkey "unprofitablecpu"
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Unprofitable Cpu algo API failed. "
    }

    if ($Request -and $Request.Count -gt 10) {
        Set-ContentJson -PathToFile ".\Data\unprofitable-cpu.json" -Data $Request -MD5hash $Global:GlobalUnprofitableCpuAlgosHash > $null
    } elseif (Test-Path ".\Data\unprofitable.json") {
        try{
            $Request = Get-ContentByStreamReader ".\Data\unprofitable-cpu.json" | ConvertFrom-Json -ErrorAction Ignore
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Unprofitable Cpu database is corrupt. "
        }
    }
    $Global:GlobalUnprofitableCpuAlgosHash = Get-ContentDataMD5hash $Request
    $Request
}

function Get-CoinSymbol {
    [CmdletBinding()]
    param($CoinName = "Bitcoin",[Switch]$Silent,[Switch]$Reverse)
    
    if (-not (Test-Path Variable:Global:GlobalCoinNames) -or -not $Global:GlobalCoinNames.Count) {
        try {
            $Request = Invoke-GetUrlAsync "https://rbminer.net/api/data/coins.json" -cycletime 86400 -Jobkey "coins"
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Coins API failed. "
        }
        if (-not $Request -or $Request.PSObject.Properties.Name.Count -le 100) {
            $Request = $null
            if (Test-Path "Data\coins.json") {try {$Request = Get-ContentByStreamReader "Data\coins.json" | ConvertFrom-Json -ErrorAction Stop} catch {$Request = $null}}
            if (-not $Request) {Write-Log -Level Warn "Coins API return empty string. ";return}
        } else {Set-ContentJson -PathToFile "Data\coins.json" -Data $Request > $null}
        [hashtable]$Global:GlobalCoinNames = @{}
        $Request.PSObject.Properties | Foreach-Object {$Global:GlobalCoinNames[$_.Name] = $_.Value}
    }
    if (-not $Silent) {
        if ($Reverse) {
            $CoinName = $CoinName.ToUpper()
            (Get-Culture).TextInfo.ToTitleCase("$($Global:GlobalCoinNames.GetEnumerator() | Where-Object {$_.Value -eq $CoinName} | Select-Object -ExpandProperty Name -First 1)")
        } else {
            $Global:GlobalCoinNames[$CoinName.ToLower() -replace "[^a-z0-9]+"]
        }
    }
}

function Get-WhatToMineData {
    [CmdletBinding()]
    param([Switch]$Silent)
    
    if (-not (Test-Path ".\Data\wtmdata.json") -or (Get-ChildItem ".\Data\wtmdata.json").LastWriteTime.ToUniversalTime() -lt (Get-Date).AddHours(-12).ToUniversalTime()) {
        try {
            $WtmUrl  = Invoke-GetUrlAsync "https://www.whattomine.com" -cycletime (12*3600) -retry 3 -timeout 10 -method "WEB"
            [System.Collections.Generic.List[PSCustomObject]]$WtmKeys = ([regex]'(?smi)data-content="Include (.+?)".+?factor_([a-z0-9]+?)_hr.+?>([hkMG]+)/s<').Matches($WtmUrl) | Foreach-Object {
                    [PSCustomObject]@{
                        algo   = (Get-Algorithm ($_.Groups | Where-Object Name -eq 1 | Select-Object -ExpandProperty Value)) -replace "Cuckaroo29","Cuckarood29"
                        id     = $_.Groups | Where-Object Name -eq 2 | Select-Object -ExpandProperty Value
                        factor = $_.Groups | Where-Object Name -eq 3 | Select-Object -ExpandProperty Value | Foreach-Object {Switch($_) {"Gh" {1e9;Break};"Mh" {1e6;Break};"kh" {1e3;Break};default {1}}}
                    }
                }
            if ($WtmKeys -and $WtmKeys.count -gt 10) {
                $WtmFactors = Get-ContentByStreamReader ".\Data\wtmfactors.json" | ConvertFrom-Json -ErrorAction Ignore
                if ($WtmFactors) {
                    $WtmFactors.PSObject.Properties.Name | Where-Object {@($WtmKeys.algo) -inotcontains $_} | Foreach-Object {
                        $WtmKeys.Add([PSCustomObject]@{algo = $_;factor = $WtmFactors.$_}) > $null
                    }
                }
                Set-ContentJson ".\Data\wtmdata.json" -Data $WtmKeys > $null
                $Global:GlobalWTMData = $null
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "WhatToMiner datagrabber failed. "
            return
        }
    }

    if (-not (Test-Path Variable:Global:GlobalWTMData) -or $Global:GlobalWTMData -eq $null) {
        $Global:GlobalWTMData = Get-ContentByStreamReader ".\Data\wtmdata.json" | ConvertFrom-Json -ErrorAction Ignore
    }

    if (-not $Silent) {$Global:GlobalWTMData}
}

function Get-WhatToMineUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [int]$Factor = 10
    )
    "https://whattomine.com/coins.json?$(@(Get-WhatToMineData | Where-Object {$_.id} | Foreach-Object {"$($_.id)=true&factor[$($_.id)_hr]=$Factor&factor[$($_.id)_p]=0"}) -join '&')"
}

function Get-WhatToMineFactor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Algo,
        [Parameter(Mandatory = $false)]
        [int]$Factor = 10
    )
    if ($Algo) {
        if (-not (Test-Path Variable:Global:GlobalWTMData) -or $Global:GlobalWTMData -eq $null) {Get-WhatToMineData -Silent}
        $Global:GlobalWTMData | Where-Object {$_.algo -eq $Algo} | Foreach-Object {$_.factor * $Factor}
    }
}

function Write-ToFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$FilePath,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
        [Parameter(Mandatory = $False)]
        [switch]$Append = $false,
        [Parameter(Mandatory = $False)]
        [switch]$Timestamp = $false,
        [Parameter(Mandatory = $False)]
        [switch]$NoCR = $false,
        [Parameter(Mandatory = $False)]
        [switch]$ThrowError = $false
    )
    Begin {
        $ErrorMessage = $null
        try {
            $FilePath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
            $file = New-Object System.IO.StreamWriter($FilePath, $Append, [System.Text.Encoding]::UTF8)
        } catch {if ($Error.Count){$Error.RemoveAt(0)};$ErrorMessage = "$($_.Exception.Message)"}
    }
    Process {
        if ($file) {
            try {
                if ($Timestamp) {
                    if ($NoCR) {
                        $file.Write("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $Message")
                    } else {
                        $file.WriteLine("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $Message")
                    }
                } else {
                    if ($NoCR) {
                        $file.Write($Message)
                    } else {
                        $file.WriteLine($Message)
                    }
                }
            } catch {if ($Error.Count){$Error.RemoveAt(0)};$ErrorMessage = "$($_.Exception.Message)"}
        }
    }
    End {
        if ($file) {
            try {
                $file.Close()
                $file.Dispose()
            } catch {if ($Error.Count){$Error.RemoveAt(0)};$ErrorMessage = "$($_.Exception.Message)"}
        }
        if ($ThrowError -and $ErrorMessage) {throw $ErrorMessage}
    }
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

        $filename = ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd").txt"

        if (-not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}

        switch ($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                Write-Error -Message $Message
                Break
            }
            'Warn' {
                $LevelText = 'WARNING:'
                Write-Warning -Message $Message
                Break
            }
            'Info' {
                $LevelText = 'INFO:'
                #Write-Information -MessageData $Message
                Break
            }
            'Verbose' {
                $LevelText = 'VERBOSE:'
                Write-Verbose -Message $Message
                Break
            }
            'Debug' {
                $LevelText = 'DEBUG:'
                Write-Debug -Message $Message
                Break
            }
        }

        $NoLog = Switch ($Session.LogLevel) {
                    "Silent" {$true;Break}
                    "Info"   {$Level -eq "Debug";Break}
                    "Warn"   {@("Info","Debug") -icontains $Level;Break}
                    "Error"  {@("Warn","Info","Debug") -icontains $Level;Break}
                }

        if (-not $NoLog) {
            # Get mutex named RBMWriteLog. Mutexes are shared across all threads and processes.
            # This lets us ensure only one thread is trying to write to the file at a time.
            $mutex = New-Object System.Threading.Mutex($false, "RBM$(Get-MD5Hash ([io.fileinfo](".\Logs")).FullName)")
            # Attempt to aquire mutex, waiting up to 2 second if necessary.  If aquired, write to the log file and release mutex.  Otherwise, display an error.
            if ($mutex.WaitOne(2000)) {
                #$proc = Get-Process -id $PID
                #Write-ToFile -FilePath $filename -Message "[$("{0:n2}" -f ($proc.WorkingSet64/1MB)) $("{0:n2}" -f ($proc.PrivateMemorySize64/1MB))] $LevelText $Message" -Append -Timestamp
                "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $LevelText $Message" | Out-File $filename -Append -Encoding utf8
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

    Begin {
        $ActiveStart = $Miner.GetActiveStart()
        if (-not $ActiveStart) {return}
    }
    Process {
        $Now = Get-Date
        if ($Crashed) {
            $Runtime = $Miner.GetRunningTime()
            $Global:CrashCounter += [PSCustomObject]@{
                Timestamp      = $Now
                Start          = $ActiveStart
                End            = $Miner.GetActiveLast()
                Runtime        = $Runtime.TotalSeconds
                Name           = $Miner.BaseName
                Device         = @($Miner.DeviceModel)
                Algorithm      = @($Miner.BaseAlgorithm)
                Pool           = @($Miner.Pool)
            }
        }
        $Global:CrashCounter = $Global:CrashCounter.Where({$_.Timestamp -gt $Now.AddHours(-1)})

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
                Donation       = $Session.IsDonationRun
            } | ConvertTo-Json -Depth 10 -Compress)," | Out-File $filename -Append -Encoding utf8
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
                Currency    = "$($Miner.Currency -join '+')"
                Rate        = [Math]::Round($Global:Rates.USD,2)
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
            $CsvLine | Export-ToCsvFile $PathCsv
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (Test-Path $Path) {Write-Log -Level $(if ($Quiet) {"Info"} else {"Warn"}) "Could not write to $($PathCsv_Name) "}
    }

    $Stat = Get-ContentByStreamReader $Path

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
    $Stat | ConvertTo-Json -Depth 10 | Set-Content $Path
}

function Set-TotalsAvg {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [Switch]$CleanupOnly = $false
    )

    $Updated        = (Get-Date).ToUniversalTime()
    $Path0          = "Stats\Totals"

    $LastValid      = (Get-Date).AddDays(-30)
    $LastValid_File = "Totals_$("{0:yyyy-MM-dd}" -f $LastValid)"
    $Last1w_File    = "Totals_$("{0:yyyy-MM-dd}" -f $((Get-Date).AddDays(-8)))"

    $Last1d = (Get-Date).AddDays(-1)
    $Last1w = (Get-Date).AddDays(-7)

    Get-ChildItem "Stats\Totals" -Filter "Totals_*.csv" | Where-Object {$_.BaseName -lt $LastValid_File} | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}

    if ($CleanupOnly) {return}

    $Totals = [PSCustomObject]@{}
    Get-ChildItem "Stats\Totals" -Filter "*_TotalAvg.txt" | Foreach-Object {
        $PoolName = $_.BaseName -replace "_TotalAvg"
        $Started = (Get-ContentByStreamReader $_.FullName | ConvertFrom-Json -ErrorAction Ignore).Started
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

    $Stat = Get-ContentByStreamReader $Path

    $Balance_Total = [Decimal]$Balance.Balance
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

            $Rate = [Decimal]$Global:Rates."$($Balance.Currency)"
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
            $CsvLine | Export-ToCsvFile "$($Path0)\Earnings_Localized.csv" -UseCulture
            $CsvLine.PSObject.Properties | Foreach-Object {$_.Value = "$($_.Value)"}
            $CsvLine | Export-ToCsvFile "$($Path0)\Earnings.csv"
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

function Export-ToCsvFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $True)]
        $InputObject,
        [Parameter(Mandatory = $false)]
        [Switch]$UseCulture = $false
    )
    $Skip = if (Test-Path $FilePath) {1} else {0}
    if ($UseCulture) {
        $InputObject | ConvertTo-Csv -NoTypeInformation -UseCulture -ErrorAction Ignore | Select-Object -Skip $Skip | Write-ToFile -FilePath $FilePath -Append
    } else {
        $InputObject | ConvertTo-Csv -NoTypeInformation -ErrorAction Ignore | Select-Object -Skip $Skip | Write-ToFile -FilePath $FilePath -Append
    }
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
        [Parameter(Mandatory = $false)]
        [DateTime]$StartTime = (Get-Date).ToUniversalTime(),
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
        [String]$LogFile = "",
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Updated = $Updated.ToUniversalTime()

    $Mode     = ""
    $LogLevel = if ($Quiet) {"Info"} else {"Warn"}
    $Cached   = $true

    if ($Name -match '_Profit$')       {$Path0 = "Stats\Pools";    $Mode = "Pools"}
    elseif ($Name -match '_Hashrate$') {$Path0 = "Stats\Miners";   $Mode = "Miners"}
    else                               {$Path0 = "Stats";          $Mode = "Profit"; $Cached = $false}

    $Path = if ($Sub) {"$Path0\$Sub-$Name.txt"} else {"$Path0\$Name.txt"}

    $SmallestValue = 1E-20

    if ($Stat = Get-StatFromFile -Path $Path -Name $Name -Cached:$Cached) {
        try {
            if ($Mode -in @("Pools","Profit") -and $Stat.Week_Fluctuation -and [Double]$Stat.Week_Fluctuation -ge 0.8) {throw "Fluctuation out of range"}

            if ($Mode -eq "Miners") {
                $Benchmarked = if ($Stat.Benchmarked -ne $null) {$Stat.Benchmarked} else {[DateTime]$Stat.Updated - [TimeSpan]$Stat.Duration}
            }

            $Stat = Switch ($Mode) {
                "Miners" {
                    [PSCustomObject]@{
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

                        # Miners Part
                        PowerDraw_Live     = [Double]$Stat.PowerDraw_Live
                        PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                        Diff_Live          = [Double]$Stat.Diff_Live
                        Diff_Average       = [Double]$Stat.Diff_Average
                        Ratio_Live         = [Double]$Stat.Ratio_Live
                        Benchmarked        = $Benchmarked
                        LogFile            = $LogFile
                        #Ratio_Average      = [Double]$Stat.Ratio_Average
                    }
                    Break
                }
                "Pools" {
                    [PSCustomObject]@{
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

                        # Pools part
                        HashRate_Live      = [Double]$Stat.HashRate_Live
                        HashRate_Average   = [Double]$Stat.HashRate_Average
                        BlockRate_Live     = [Double]$Stat.BlockRate_Live
                        BlockRate_Average  = [Double]$Stat.BlockRate_Average
                        Actual24h_Week     = [Double]$Stat.Actual24h_Week
                        Estimate24h_Week   = [Double]$Stat.Estimate24h_Week
                        ErrorRatio         = [Double]$Stat.ErrorRatio
                    }
                    Break
                }
                default {
                    [PSCustomObject]@{
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

                        # Profit Part
                        PowerDraw_Live     = [Double]$Stat.PowerDraw_Live
                        PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                    }
                }
            }

            $ToleranceMin = $Value
            $ToleranceMax = $Value

            if ($FaultDetection) {
                if ($FaultTolerance -eq $null) {$FaultTolerance = 0.1}
                if ($FaultTolerance -lt 1) {
                    $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance + $Stat.Failed/100), 0.9))
                    $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance + $Stat.Failed/100 + 0.1), 1.0))
                } elseif ($Stat.Hour -gt 0) {
                    if ($FaultTolerance -lt 2) {$FaultTolerance = 2}
                    $ToleranceMin = $Stat.Hour / $FaultTolerance
                    $ToleranceMax = $Stat.Hour * $FaultTolerance
                }
            } elseif ($Stat.Hour -gt 0 -and $UplimProtection -gt 1.0) {            
                $ToleranceMax = $Stat.Hour * $UplimProtection
            }

            if ($ChangeDetection -and [Decimal]$Value -eq [Decimal]$Stat.Live -and ($Mode -ne "Pools" -or [Decimal]$Hashrate -eq [Decimal]$Stat.HashRate_Live)) {$Updated = $Stat.Updated}
        
            if ($Value -gt 0 -and $ToleranceMax -eq 0) {$ToleranceMax = $Value}

            if ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax) {
                if (-not $Quiet) {
                    if ($mode -eq "Miners") {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value | ConvertTo-Hash) is outside fault tolerance $($ToleranceMin | ConvertTo-Hash) to $($ToleranceMax | ConvertTo-Hash). "}
                    elseif ($UplimProtection -gt 1.0) {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString()) is at least $($UplimProtection.ToString()) times above the hourly average. "}
                    else {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString()) is outside fault tolerance $($ToleranceMin.ToString()) to $($ToleranceMax.ToString()). "}
                }
                $Stat.Failed += 10
                if ($Stat.Failed -gt 30) {$Stat.Failed = 30}
            } else {
                $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
                $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
                $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
                $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
                $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
                $Span_ThreeDay = [Math]::Min(($Duration.TotalDays / 3) / [Math]::Min(($Stat.Duration.TotalDays / 3), 1), 1)
                $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

                $Stat = Switch ($Mode) {
                    "Miners" {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)

                            # Miners part
                            PowerDraw_Live     = $PowerDraw
                            PowerDraw_Average  = if ($Stat.PowerDraw_Average -gt 0) {$Stat.PowerDraw_Average + $Span_Week * ($PowerDraw - $Stat.PowerDraw_Average)} else {$PowerDraw}
                            Diff_Live          = $Difficulty
                            Diff_Average       = $Stat.Diff_Average + $Span_Day * ($Difficulty - $Stat.Diff_Average)
                            Ratio_Live         = $Ratio
                            Benchmarked        = $Benchmarked
                            LogFile            = $LogFile
                            #Ratio_Average      = if ($Stat.Ratio_Average -gt 0) {[Math]::Round($Stat.Ratio_Average - $Span_Hour * ($Ratio - $Stat.Ratio_Average),4)} else {$Ratio}
                        }
                        Break
                    }
                    "Pools" {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)

                            # Pools part
                            HashRate_Live      = $HashRate
                            HashRate_Average   = if ($Stat.HashRate_Average -gt 0) {$Stat.HashRate_Average + $Span_Hour * ($HashRate - $Stat.HashRate_Average)} else {$HashRate}
                            BlockRate_Live     = $BlockRate
                            BlockRate_Average  = if ($Stat.BlockRate_Average -gt 0) {$Stat.BlockRate_Average + $Span_Hour * ($BlockRate - $Stat.BlockRate_Average)} else {$BlockRate}
                            Actual24h_Week     = $Stat.Actual24h_Week + $Span_Day * ($Actual24h - $Stat.Actual24h_Week)
                            Estimate24h_Week   = $Stat.Estimate24h_Week + $Span_Day * ($Estimate24h - $Stat.Estimate24h_Week)
                            ErrorRatio         = $Stat.ErrorRatio
                        }
                        Break
                    }
                    default {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)

                            # Profit part
                            PowerDraw_Live     = $PowerDraw
                            PowerDraw_Average  = if ($Stat.PowerDraw_Average -gt 0) {$Stat.PowerDraw_Average + $Span_Day * ($PowerDraw - $Stat.PowerDraw_Average)} else {$PowerDraw}
                        }
                    }
                }
                $Stat.PSObject.Properties.Name | Where-Object {$_ -match "Fluctuation" -and $Stat.$_ -gt 1} | Foreach-Object {$Stat.$_ = 0}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            if (-not $Quiet -and (Test-Path $Path)) {Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. "}
            $Stat = $null
        }
    }

    if (-not $Stat) {
        $Stat = Switch($Mode) {
            "Miners" {
                [PSCustomObject]@{
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

                    # Miners part
                    PowerDraw_Live     = $PowerDraw
                    PowerDraw_Average  = $PowerDraw
                    Diff_Live          = $Difficulty
                    Diff_Average       = $Difficulty
                    Ratio_Live         = $Ratio
                    Benchmarked        = $StartTime
                    LogFile            = $LogFile
                    #Ratio_Average      = $Ratio
                }
                Break
            }
            "Pools" {
                [PSCustomObject]@{
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

                    # Pools part
                    HashRate_Live      = $HashRate
                    HashRate_Average   = $HashRate
                    BlockRate_Live     = $BlockRate
                    BlockRate_Average  = $BlockRate
                    Actual24h_Week     = 0
                    Estimate24h_Week   = 0
                    ErrorRatio         = 0
                }
                Break
            }
            default {
                [PSCustomObject]@{
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

                    # Profit part
                    PowerDraw_Live     = $PowerDraw
                    PowerDraw_Average  = $PowerDraw
                }
            }
        }
    }

    if ($Mode -eq "Pools") {
        $Stat.ErrorRatio = [Math]::Min(1+$(if ($Stat.Estimate24h_Week) {($Stat.Actual24h_Week/$Stat.Estimate24h_Week-1) * $(if ($Stat.Duration.TotalDays -lt 7) {$Stat.Duration.TotalDays/7*(2 - $Stat.Duration.TotalDays/7)} else {1})}),[Math]::Max($Stat.Duration.TotalDays,1))
        if ($Session.Config.MaxErrorRatio -and $Stat.ErrorRatio -gt $Session.Config.MaxErrorRatio) {
            $Stat.ErrorRatio = $Session.Config.MaxErrorRatio
        }
    }

    if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}

    if ($Stat.Duration -ne 0) {
        $(Switch($Mode) {
            "Miners" {
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
                    ThreeDay = [Decimal]$Stat.ThreeDay
                    ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                    Week = [Decimal]$Stat.Week
                    Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                    Duration = [String]$Stat.Duration
                    Updated = [DateTime]$Stat.Updated
                    Failed = [Int]$Stat.Failed

                    # Miners part
                    PowerDraw_Live     = [Decimal]$Stat.PowerDraw_Live
                    PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                    Diff_Live          = [Double]$Stat.Diff_Live
                    Diff_Average       = [Double]$Stat.Diff_Average
                    Ratio_Live         = [Double]$Stat.Ratio_Live
                    Benchmarked        = [DateTime]$Stat.Benchmarked
                    LogFile            = [String]$Stat.LogFile
                    #Ratio_Average      = [Double]$Stat.Ratio_Average
                }
                Break
            }
            "Pools" {
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
                    ThreeDay = [Decimal]$Stat.ThreeDay
                    ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                    Week = [Decimal]$Stat.Week
                    Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                    Duration = [String]$Stat.Duration
                    Updated = [DateTime]$Stat.Updated
                    Failed = [Int]$Stat.Failed

                    # Pools part
                    HashRate_Live      = [Decimal]$Stat.HashRate_Live
                    HashRate_Average   = [Double]$Stat.HashRate_Average
                    BlockRate_Live     = [Decimal]$Stat.BlockRate_Live
                    BlockRate_Average  = [Double]$Stat.BlockRate_Average
                    Actual24h_Week     = [Decimal]$Stat.Actual24h_Week
                    Estimate24h_Week   = [Decimal]$Stat.Estimate24h_Week
                    ErrorRatio         = [Decimal]$Stat.ErrorRatio
                }
                Break
            }
            default {
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
                    ThreeDay = [Decimal]$Stat.ThreeDay
                    ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                    Week = [Decimal]$Stat.Week
                    Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                    Duration = [String]$Stat.Duration
                    Updated = [DateTime]$Stat.Updated
                    Failed = [Int]$Stat.Failed

                    # Profit part
                    PowerDraw_Live     = [Decimal]$Stat.PowerDraw_Live
                    PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                }
            }
        }) | ConvertTo-Json -Depth 10 | Set-Content $Path
    }

    if ($Cached) {$Global:StatsCache[$Name] = $Stat}

    $Stat
}

function Get-StatFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [Switch]$Cached = $false
    )

    if (-not $Cached -or $Global:StatsCache[$Name] -eq $null -or -not (Test-Path $Path)) {
        try {
            $Stat = ConvertFrom-Json "$(Get-ContentByStreamReader $Path)" -ErrorAction Stop
            if ($Cached) {
                if ($Stat) {
                    $Global:StatsCache[$Name] = $Stat
                } else {
                    $RemoveKey = $true
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            if (Test-Path $Path) {
                Write-Log -Level Warn "Stat file ($([IO.Path]::GetFileName($Path)) is corrupt and will be removed. "
                Remove-Item -Path $Path -Force -Confirm:$false
            }
            if ($Cached) {$RemoveKey = $true}
        }
        if ($RemoveKey) {
            if ($Global:StatsCache.ContainsKey($Name)) {
                $Global:StatsCache.Remove($Name)
            }
        }
    }

    if ($Cached) {
        $Global:StatsCache[$Name]
    } else {
        $Stat
    }
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
        [Switch]$Disabled = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Totals = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$TotalAvgs = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Balances = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Poolstats = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$All = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Cached = $false

    if ($Name) {
        # Return single requested stat
        if ($Name -match '_Profit$') {$Path = "Stats\Pools"; $Cached = $true}
        elseif ($Name -match '_Hashrate$') {$Path = "Stats\Miners"; $Cached = $true}
        elseif ($Name -match '_(Total|TotalAvg)$') {$Path = "Stats\Totals"}
        elseif ($Name -match '_Balance$') {$Path = "Stats\Balances"}
        elseif ($Name -match '_Poolstats$') {$Path = "Stats\Pools"}
        else {$Path = "Stats"}

        if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

        if ($Sub) {
            $Path = "$Path\$Sub-$Name.txt"
        } else {
            $Path = "$Path\$Name.txt"
        }

        Get-StatFromFile -Path $Path -Name $Name -Cached:$Cached
    } else {
        # Return all stats
        [hashtable]$NewStats = @{}

        if (($Miners -or $All) -and -not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        if (($Disabled -or $All) -and -not (Test-Path "Stats\Disabled")) {New-Item "Stats\Disabled" -ItemType "directory" > $null}
        if (($Pools -or $Poolstats -or $All) -and -not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (($Totals -or $TotalAvgs -or $All) -and -not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}
        if (($Balances -or $All) -and -not (Test-Path "Stats\Balances")) {New-Item "Stats\Balances" -ItemType "directory" > $null}

        [System.Collections.Generic.List[string]]$MatchArray = @()
        if ($Miners)    {$MatchArray.Add("Hashrate") > $null;$Path = "Stats\Miners";$Cached = $true}
        if ($Disabled)  {$MatchArray.Add("Hashrate|Profit") > $null;$Path = "Stats\Disabled"}
        if ($Pools)     {$MatchArray.Add("Profit") > $null;$Path = "Stats\Pools"; $Cached = $true}
        if ($Poolstats) {$MatchArray.Add("Poolstats") > $null;$Path = "Stats\Pools"}
        if ($Totals)    {$MatchArray.Add("Total") > $null;$Path = "Stats\Totals"}
        if ($TotalAvgs) {$MatchArray.Add("TotalAvg") > $null;$Path = "Stats\Totals"}
        if ($Balances)  {$MatchArray.Add("Balance") > $null;$Path = "Stats\Balances"}
        if (-not $Path -or $All -or $MatchArray.Count -gt 1) {$Path = "Stats"; $Cached = $false}

        $MatchStr = if ($MatchArray.Count -gt 1) {$MatchArray -join "|"} else {$MatchArray}
        if ($MatchStr -match "|") {$MatchStr = "($MatchStr)"}

        foreach($p in (Get-ChildItem -Recurse $Path -File -Filter "*.txt")) {
            $BaseName = $p.BaseName
            $FullName = $p.FullName
            if (-not $All -and $BaseName -notmatch "_$MatchStr$") {continue}

            $NewStatsKey = $BaseName -replace "^(AMD|CPU|INTEL|NVIDIA)-"

            if ($Stat = Get-StatFromFile -Path $FullName -Name $NewStatsKey -Cached:$Cached) {
                $NewStats[$NewStatsKey] = $Stat
            }
        }
        if ($Cached) {
            $RemoveKeys = (Compare-Object @($NewStats.Keys | Select-Object) @($Global:StatsCache.Keys | Where {$_ -match "_$MatchStr$"} | Select-Object)) | Where-Object {$_.SideIndicator -eq "=>"} | Foreach-Object {$_.InputObject}
            $RemoveKeys | Foreach-Object {$Global:StatsCache.Remove($_)}
        }
        if (-not $Quiet) {$NewStats}
    }
}

function Confirm-ConfigHealth {
    $Ok = $true
    $Session.ConfigFiles.Keys | Where-Object {$Session.ConfigFiles.$_.Path -and (Test-Path $Session.ConfigFiles.$_.Path)} | Where-Object {(Get-ChildItem $Session.ConfigFiles.$_.Path).LastWriteTime.ToUniversalTime() -gt $_.Value.LastWriteTime} | Foreach-Object {
        $Name = $_
        $File = $Session.ConfigFiles.$_
        try {
            Get-ContentByStreamReader $File.Path | ConvertFrom-Json -ErrorAction Stop > $null
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
        if ($_.Extension -eq ".ps1") {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}
                & $_.FullName @Parameters                
            }
        }
        elseif ($Quick) {
            $Content = $null
            try {
                $Content = Get-ContentByStreamReader $_.FullName | ConvertFrom-Json -ErrorAction Stop
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
            if ($Content -eq $null) {$Content = Get-ContentByStreamReader $_.FullName}
        }
        else {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}                
                try {
                    (Get-ContentByStreamReader $_.FullName | ConvertFrom-Json -ErrorAction Stop) | ForEach-Object {Invoke-ExpressionRecursive $_}
                }
                catch {if ($Error.Count){$Error.RemoveAt(0)}}
            }
            if ($Content -eq $null) {$Content = Get-ContentByStreamReader $_.FullName}
        }
        if ($Force -and $Content) {
            foreach ($k in $Parameters.Keys) {
                if ($Member = Get-Member -InputObject $Content -Name $k -Membertype Properties) {
                    if ($Member.Name -and ($Member.Name -cne $k)) {
                        $Value = $Content.$k
                        $Content | Add-Member $k $Value -Force
                    }
                } else {
                    $Content | Add-Member $k $Parameters.$k -Force 
                }
            }
        }
        $Content
    }
}

function Get-ContentByStreamReader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $True)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [Switch]$ExpandLines = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$ThrowError = $false
    )
    $ErrorString = $null
    try {
        if (-not (Test-Path $FilePath)) {return}
        $FilePath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
        $FileMode = [System.IO.FileMode]::Open
        $FileAccess = [System.IO.FileAccess]::Read
        $FileShare = [System.IO.FileShare]::ReadWrite
        $FileStream = New-Object System.IO.FileStream $FilePath, $FileMode, $FileAccess, $FileShare
        $reader = New-Object System.IO.StreamReader($FileStream)
        if ($ExpandLines) {
            while (-not $reader.EndOfStream) {$reader.ReadLine()}
        } else {
            $reader.ReadToEnd()
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $ErrorString = "$($_.Exception.Message)"
    }
    finally {
        if ($reader) {$reader.Close();$reader.Dispose()}
    }
    if ($ThrowError -and $ErrorString) {throw $ErrorString}
}

function Get-PoolsData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$PoolName
    )
    if (Test-Path ".\Data\Pools\$($PoolName).json") {
        if (Test-IsCore) {
            Get-ContentByStreamReader ".\Data\Pools\$($PoolName).json" | ConvertFrom-Json -ErrorAction Ignore
        } else {
            $Data = Get-ContentByStreamReader ".\Data\Pools\$($PoolName).json" | ConvertFrom-Json -ErrorAction Ignore
            $Data
        }
    }
}

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

    Get-ChildItem "Pools\$($PoolName).ps1" -File -ErrorAction Ignore | ForEach-Object {

        $Content = & {
                $Parameters.Keys | ForEach-Object { Set-Variable $_ $Parameters.$_ }
                & $_.FullName @Parameters
        }

        foreach($c in @($Content)) {
            if ($PoolName -ne "WhatToMine") {
                if ($Parameters.Region -and ($c.Region -ne $Parameters.Region)) {
                    continue
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
                                $Luck = $c.TSL / $(if ($c.BLK -gt 0) {86400/$c.BLK} else {86400})
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

                $c.Price        *= $Pool_Factor
                $c.StablePrice  *= $Pool_Factor
                $c.PenaltyFactor = $Pool_Factor

                if ($Disabled -and $Disabled.ContainsKey("$($UsePoolName)_$(if ($c.CoinSymbol) {$c.CoinSymbol} else {$c.Algorithm})_Profit")) {
                    $c.Disabled = $true
                }
            }
            $c
        }
    }
}

function Get-MinersContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [String]$MinerName = "*"
    )

    if ($Parameters.InfoOnly -eq $null) {$Parameters.InfoOnly = $false}

    foreach($Miner in @(Get-ChildItem "Miners\$($MinerName).ps1" -File -ErrorAction Ignore | Where-Object {$Parameters.InfoOnly -or $Session.Config.MinerName.Count -eq 0 -or (Compare-Object $Session.Config.MinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | Where-Object {$Parameters.InfoOnly -or $Session.Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Session.Config.ExcludeMinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} | Select-Object)) {
        $Name = $Miner.BaseName
        if ($Parameters.InfoOnly -or ((Compare-Object @($Global:DeviceCache.DevicesToVendors.Values | Select-Object) @($Global:MinerInfo.$Name | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0)) {
            $Content = & { 
                    $Parameters.Keys | ForEach-Object { Set-Variable $_ $Parameters.$_ }
                    & $Miner.FullName @Parameters
            }
            foreach($c in @($Content)) {
                if ($Parameters.InfoOnly) {
                    $c | Add-Member -NotePropertyMembers @{
                        Name     = if ($c.Name) {$c.Name} else {$Name}
                        BaseName = $Name
                    } -Force -PassThru
                } elseif ($c.PowerDraw -eq 0) {
                    $c.PowerDraw = $Global:StatsCache."$($c.Name)_$($c.BaseAlgorithm -replace '\-.*$')_HashRate".PowerDraw_Average
                    if (@($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name) -icontains $c.DeviceModel) {$c.DeviceModel = $Global:DeviceCache.DevicesByTypes.FullComboModels."$($c.DeviceModel)"}
                    $c
                } else {
                    Write-Log -Level Warn "Miner module $($Name) returned invalid object. Please open an issue at https://github.com/rainbowminer/RainbowMiner/issues"
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
    foreach($Balance in @(Get-ChildItem "Balances" -File -ErrorAction Ignore | Where-Object {$UsePools -match "^$($_.BaseName)`(Coins|Party|Solo`)?$" -or $Config.ShowPoolBalancesExcludedPools -or $_.BaseName -eq "Wallet"})) {
        $Name = $Balance.BaseName 
        foreach($c in @(& $Balance.FullName @Parameters)) {
            $c | Add-Member Name "$(if ($c.Name) {$c.Name} else {$Name})$(if ($c.Info) {$c.Info})" -Force -PassThru
        }
    }
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
                    Date     = $(if ($DateTime -is [DateTime]) {$DateTime.ToUniversalTime()} elseif ($DateTime -match "^\d+$") {[DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc') + [TimeSpan]::FromSeconds($DateTime)} else {(Get-Date $DateTime).ToUniversalTime()})
                    Amount   = [Double]$Amount / $Divisor
                    Txid     = "$(if ($TxField) {$_.$TxField} elseif ($_.tx) {$_.tx} elseif ($_.txid) {$_.txid}  elseif ($_.tx_id) {$_.tx_id} elseif ($_.txHash) {$_.txHash} elseif ($_.transactionId) {$_.transactionId} elseif ($_.hash) {$_.hash})"
                }
            }
        }
    }
}

filter ConvertTo-Float {
    [CmdletBinding()]
    $Num = $_

    switch ([math]::floor([math]::log($Num, 1e3))) {
        "-Infinity" {"0  ";Break}
        -2 {"{0:n2} µ" -f ($Num * 1e6);Break}
        -1 {"{0:n2} m" -f ($Num * 1e3);Break}
         0 {"{0:n2}  " -f ($Num / 1);Break}
         1 {"{0:n2} k" -f ($Num / 1e3);Break}
         2 {"{0:n2} M" -f ($Num / 1e6);Break}
         3 {"{0:n2} G" -f ($Num / 1e9);Break}
         4 {"{0:n2} T" -f ($Num / 1e12);Break}
         5 {"{0:n2} P" -f ($Num / 1e15);Break}
         6 {"{0:n2} E" -f ($Num / 1e18);Break}
         7 {"{0:n2} Z" -f ($Num / 1e21);Break}
         Default {"{0:n2} Y" -f ($Num / 1e24)}
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
    switch (($Hash -replace "[^kMGHTPEZY]")[0]) {
        "k" {$Num*1e3;Break}
        "M" {$Num*1e6;Break}
        "G" {$Num*1e9;Break}
        "T" {$Num*1e12;Break}
        "P" {$Num*1e15;Break}
        "E" {$Num*1e18;Break}
        "Z" {$Num*1e21;Break}
        "Y" {$Num*1e24;Break}
        default {$Num}
    }
}

function ConvertFrom-Bytes {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Hash
    )
    try {$Num = [double]($Hash -replace "[^0-9`.]")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Num=0}
    switch (($Hash -replace "[^kMGHTPEZY]")[0]) {
        "k" {[int64]$Num*1024;Break}
        "M" {[int64]$Num*1048576;Break}
        "G" {[int64]$Num*1073741824;Break}
        "T" {[int64]$Num*1099511627776;Break}
        "P" {[int64]$Num*1.12589990684262e15;Break}
        "E" {if ($Num -lt 8.67) {[int64]$Num*1.15292150460684e18} else {[bigint]$Num*1.15292150460684e18};Break}
        "Z" {[bigint]$Num*1.18059162071741e21;Break}
        "Y" {[bigint]$Num*1.20892581961462e24;Break}
        default {[int64]$Num}
    }
}

function ConvertFrom-Time {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Time
    )
    try {$Num = [double]($Time -replace "[^0-9`.]")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Num=0}
    [int64]$(switch (($Time -replace "[^mhdw]")[0]) {
        "m" {$Num*60;Break}
        "h" {$Num*3600;Break}
        "d" {$Num*86400;Break}
        "w" {$Num*604800;Break}
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
            -1 {$Currency = "mBTC";$Number*=1e3;$Offset = 5;Break}
            -2 {$Currency = "µBTC";$Number*=1e6;$Offset = 8;Break}
            -3 {$Currency = "sat"; $Number*=1e8;$Offset = 10;Break}
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
        [String]$ScreenName = "",
        [Parameter(Mandatory = $false)]
        [String]$BashFileName = "",
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "",
        [Parameter(Mandatory = $false)]
        [String]$WinTitle = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false
    )

    if ($IsLinux -and (Get-Command "screen" -ErrorAction Ignore)) {
        Start-SubProcessInScreen -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -ScreenName $ScreenName -BashFileName $BashFileName -Vendor $Vendor -SetLDLIBRARYPATH:$SetLDLIBRARYPATH
    } elseif (($ShowMinerWindow -and -not $IsWrapper) -or -not $IsWindows) {
        Start-SubProcessInConsole -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -SetLDLIBRARYPATH:$SetLDLIBRARYPATH -WinTitle $WinTitle
    } else {
        Start-SubProcessInBackground -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -SetLDLIBRARYPATH:$SetLDLIBRARYPATH
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
        [Int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false
    )

    [int[]]$Running = @()
    Get-SubProcessRunningIds $FilePath | Foreach-Object {$Running += $_}

    if ($ArgumentList) {
        $ArgumentListToBlock = $ArgumentList
        ([regex]"\s-+[\w\-_]+[\s=]+([^'`"][^\s]*,[^\s]+)").Matches(" $ArgumentListToBlock") | Foreach-Object {$ArgumentListToBlock=$ArgumentListToBlock -replace [regex]::Escape($_.Groups[1].Value),"'$($_.Groups[1].Value -replace "'","``'")'"}
        ([regex]"\s-+[\w\-_]+[\s=]+([\[][^\s]+)").Matches(" $ArgumentListToBlock") | Foreach-Object {$ArgumentListToBlock=$ArgumentListToBlock -replace [regex]::Escape($_.Groups[1].Value),"'$($_.Groups[1].Value -replace "'","``'")'"}
        if ($ArgumentList -ne $ArgumentListToBlock) {
            Write-Log -Level Info "Start-SubProcessInBackground argumentlist: $($ArgumentListToBlock)"
            $ArgumentList = $ArgumentListToBlock
        }
    }

    $Job = Start-ThreadJob -FilePath .\Scripts\StartInBackground.ps1 -ArgumentList $PID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $PWD

    [int[]]$ProcessIds = @()
    
    if ($Job) {
        Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $Running | Foreach-Object {$ProcessIds += $_}
    }
    
    Set-SubProcessPriority $ProcessIds -Priority $Priority -CPUAffinity $CPUAffinity

    [PSCustomObject]@{
        ScreenName = ""
        Name       = $Job.Name
        XJob       = $Job
        OwnWindow  = $false
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
        [int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String]$WinTitle = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false
    )

    [int[]]$Running = @()
    Get-SubProcessRunningIds $FilePath | Foreach-Object {$Running += $_}

    $LDExp = ""
    $LinuxDisplay = ""
    if ($IsLinux) {
        $LDExp = if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")}
        $LinuxDisplay = "$(if ($Session.Config.EnableLinuxHeadless) {$Session.Config.LinuxDisplay})"
    }

    $Job = Start-Job -FilePath .\Scripts\StartInConsole.ps1 -ArgumentList $PID, (Resolve-Path ".\DotNet\Tools\CreateProcess.cs"), $LDExp, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars, $IsWindows, $LinuxDisplay, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation, $SetLDLIBRARYPATH

    $cnt = 30
    do {Start-Sleep 1; $JobOutput = Receive-Job $Job;$cnt--}
    while ($JobOutput -eq $null -and $cnt -gt 0)

    [int[]]$ProcessIds = @()
    
    if ($JobOutput) {
        Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $Running | Foreach-Object {$ProcessIds += $_}
     }

    if (-not $ProcessIds.Count -and $JobOutput.ProcessId) {$ProcessIds += $JobOutput.ProcessId}

    Set-SubProcessPriority $ProcessIds -Priority $Priority -CPUAffinity $CPUAffinity

    if ($IsWindows -and $JobOutput.ProcessId -and $WinTitle -ne "") {
        try {
            if ($Process = Get-Process -Id $JobOutput.ProcessId -ErrorAction Stop) {
                Initialize-User32Dll
                [User32.WindowManagement]::SetWindowText($Process.mainWindowHandle, $WinTitle) > $null
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not set process window title: $($_.Exception.Message)"
        }
    }
    
    [PSCustomObject]@{
        ScreenName = ""
        Name       = $Job.Name
        XJob       = $Job
        OwnWindow  = $true
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
        [String]$ScreenName = "",
        [Parameter(Mandatory = $false)]
        [String]$BashFileName = "",
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false
    )

    $StartStopDaemon = Get-Command "start-stop-daemon" -ErrorAction Ignore

    $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()
    $ScreenName = ($ScreenName -replace "[^A-Z0-9_-]").ToLower()
    $BashFileName = ($BashFileName -replace "[^A-Z0-9_-]").ToLower()

    if (-not $ScreenName) {$ScreenName = Get-MD5Hash "$FilePath $ArgumentList";$ScreenName = "$($ScreenName.SubString(0,3))$($ScreenName.SubString(28,3))".ToLower()}

    $ScreenName = "$($WorkerName)_$($ScreenName)"

    if (-not (Test-Path ".\Data\pid")) {New-Item ".\Data\pid" -ItemType "directory" -force > $null}

    $PIDPath = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_pid.txt"
    $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_info.txt"
    $PIDBash = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName).sh"
    $PIDTest = Join-Path $WorkingDirectory "$(if ($BashFileName) {$BashFileName} else {"start_$($ScreenName)"}).sh"
    $PIDDebug= Join-Path $WorkingDirectory "$(if ($BashFileName) {"debug_$BashFileName"} else {"debug_start_$($ScreenName)"}).sh"

    if (Test-Path $PIDPath) { Remove-Item $PIDPath -Force }
    if (Test-Path $PIDInfo) { Remove-Item $PIDInfo -Force }
    if (Test-Path $PIDBash) { Remove-Item $PIDBash -Force }
    if (Test-Path $PIDDebug){ Remove-Item $PIDDebug -Force }

    $TestArgumentList = "$ArgumentList"

    if ($LogPath) {
        $ArgumentList = "$ArgumentList 2>&1 | tee `'$($LogPath)`'"
    }

    Set-ContentJson -Data @{miner_exec = "$FilePath"; start_date = "$(Get-Date)"; pid_path = "$PIDPath" } -PathToFile $PIDInfo > $null

    [System.Collections.Generic.List[string]]$Stuff = @()
    $Stuff.Add("export DISPLAY=:0") > $null
    $Stuff.Add("cd /") > $null
    $Stuff.Add("cd '$WorkingDirectory'") > $null

    $StuffEnv = Switch ($Vendor) {
        "AMD" {
            [ordered]@{
                GPU_MAX_HEAP_SIZE=100
                GPU_MAX_USE_SYNC_OBJECTS=1
                GPU_SINGLE_ALLOC_PERCENT=100
                GPU_MAX_ALLOC_PERCENT=100
                GPU_MAX_SINGLE_ALLOC_PERCENT=100
                GPU_ENABLE_LARGE_ALLOCATION=100
                GPU_MAX_WORKGROUP_SIZE=256
            }
        }
        "INTEL" {
            [ordered]@{
                GPU_MAX_HEAP_SIZE=100
                GPU_MAX_USE_SYNC_OBJECTS=1
                GPU_SINGLE_ALLOC_PERCENT=100
                GPU_MAX_ALLOC_PERCENT=100
                GPU_MAX_SINGLE_ALLOC_PERCENT=100
                GPU_ENABLE_LARGE_ALLOCATION=100
                GPU_MAX_WORKGROUP_SIZE=256
            }
        }
        "NVIDIA" {
            [ordered]@{
                CUDA_DEVICE_ORDER="PCI_BUS_ID"
            }
        }
        default {
            [ordered]@{}
        }
    }

    $EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {$StuffEnv[$matches[1]]=$matches[2]}

    $StuffEnv.GetEnumerator() | Foreach-Object {
        $Stuff.Add("export $($_.Name)=$($_.Value)") > $null
    }

    if ($SetLDLIBRARYPATH) {
        $Stuff.Add("export LD_LIBRARY_PATH=./:$(if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")})") > $null
    }

    [System.Collections.Generic.List[string]]$Test  = @()
    $Stuff | Foreach-Object {$Test.Add($_) > $null}
    $Test.Add("$FilePath $TestArgumentList") > $null

    if ($StartStopDaemon) {
        $Stuff.Add("start-stop-daemon --start --make-pidfile --chdir '$WorkingDirectory' --pidfile '$PIDPath' --exec '$FilePath' -- $ArgumentList") > $null
    } else {
        $Stuff.Add("$FilePath $ArgumentList") > $null
    }

    [System.Collections.Generic.List[string]]$Cmd = @()
    $Cmd.Add("screen -ls `"$ScreenName`" |  grep '[0-9].$ScreenName' | (") > $null
    $Cmd.Add("  IFS=`$(printf '\t');") > $null
    $Cmd.Add("  sed `"s/^`$IFS//`" |") > $null
    $Cmd.Add("  while read -r name stuff; do") > $null
    $Cmd.Add("    screen -S `"`$name`" -X stuff `^C >/dev/null 2>&1") > $null
    $Cmd.Add("    sleep .1 >/dev/null 2>&1") > $null
    $Cmd.Add("    screen -S `"`$name`" -X stuff `^C >/dev/null 2>&1") > $null
    $Cmd.Add("    sleep .1 >/dev/null 2>&1") > $null
    $Cmd.Add("    screen -S `"`$name`" -X quit  >/dev/null 2>&1") > $null
    $Cmd.Add("    screen -S `"`$name`" -X quit  >/dev/null 2>&1") > $null
    $Cmd.Add("  done") > $null
    $Cmd.Add(")") > $null
    $Cmd.Add("screen -S $($ScreenName) -d -m") > $null
    $Cmd.Add("sleep .1") > $null

    $StringChunkSize = 500

    $Stuff | Foreach-Object {
        $str = $_
        while ($str) {
            $substr = $str.substring(0,[Math]::Min($str.length,$StringChunkSize))
            if ($str.length -gt $substr.length) {
                $Cmd.Add("screen -S $($ScreenName) -X stuff $`"$($substr -replace '"','\"')`"") > $null
                $str = $str.substring($substr.length)
            } else {
                $Cmd.Add("screen -S $($ScreenName) -X stuff $`"$($substr -replace '"','\"')\n`"") > $null
                $str = ""
            }
            $Cmd.Add("sleep .1") > $null
        }
    }

    Set-BashFile -FilePath $PIDBash -Cmd $Cmd
    Set-BashFile -FilePath $PIDTest -Cmd $Test

    if ($Session.Config.EnableDebugMode -and (Test-Path $PIDBash)) {
        Copy-Item -Path $PIDBash -Destination $PIDDebug -ErrorAction Ignore
        $Chmod_Process = Start-Process "chmod" -ArgumentList "+x $PIDDebug" -PassThru
        $Chmod_Process.WaitForExit(1000) > $null
    }

    $Chmod_Process = Start-Process "chmod" -ArgumentList "+x $FilePath" -PassThru
    $Chmod_Process.WaitForExit(1000) > $null
    $Chmod_Process = Start-Process "chmod" -ArgumentList "+x $PIDBash" -PassThru
    $Chmod_Process.WaitForExit(1000) > $null
    $Chmod_Process = Start-Process "chmod" -ArgumentList "+x $PIDTest" -PassThru
    $Chmod_Process.WaitForExit(1000) > $null

    $Job = Start-Job -FilePath .\Scripts\StartInScreen.ps1 -ArgumentList $PID, $WorkingDirectory, $FilePath, $Session.OCDaemonPrefix, $Session.Config.EnableMinersAsRoot, $PIDPath, $PIDBash, $ScreenName, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation, $Session.IsAdmin

    $cnt = 30;
    do {Start-Sleep 1; $JobOutput = Receive-Job $Job;$cnt--}
    while ($JobOutput -eq $null -and $cnt -gt 0)

    [int[]]$ProcessIds = @()
    
    if ($JobOutput.ProcessId) {$ProcessIds += $JobOutput.ProcessId}

    $JobOutput.StartLog | Where-Object {$_} | Foreach-Object {Write-Log -Level Info "$_"}
    
    [PSCustomObject]@{
        ScreenName = $ScreenName
        Name       = $Job.Name
        XJob       = $Job
        OwnWindow  = $true
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Get-SubProcessRunningIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath
    )
    if ($IsWindows) {(Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $FilePath}).ProcessId}
    elseif ($IsLinux) {(Get-Process | Where-Object {$_.Path -eq $FilePath}).Id}
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

    $StopWatch = [System.Diagnostics.Stopwatch]::New()

    $StopWatch.Restart()

    $WaitCount = 0
    $ProcessFound = 0
    $ArgumentList = "*$($ArgumentList.Replace("'","*").Replace('"',"*"))*" -replace "\*+","*"
    do {
        Start-Sleep -Milliseconds 100
        Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -eq $FilePath -and $_.CommandLine -like $ArgumentList -and $Running -inotcontains $_.ProcessId} | Foreach-Object {
            $Running += $_.ProcessId
            $ProcessFound++
            $_.ProcessId
            Write-Log -Level Info "$($_.ProcessId) found for $FilePath"
        }
        $WaitCount++
    } until (($StopWatch.Elapsed.TotalSeconds -gt 10) -or ($ProcessFound -gt $MultiProcess))
    $StopWatch = $null
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
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not set process priority/affinity: $($_.Exception.Message)"
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
        [String]$Name = "",
        [Parameter(Mandatory = $false)]
        [String]$ShutdownUrl = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SkipWait = $false
    )

    $WaitForExit = if ($SkipWait) {0} elseif ($IsWindows) {20} else {120}

    if ($Job.ProcessId) {
        $Job.ProcessId | Select-Object -First 1 | Foreach-Object {
            if ($Process = Get-Process -Id $_ -ErrorAction Ignore) {

                $StopWatch = [System.Diagnostics.Stopwatch]::New()

                $StopWatch.Start()

                $ToKill  = @()
                $ToKill += $Process

                if ($IsLinux) {
                    $ToKill += Get-Process | Where-Object {$_.Parent.Id -eq $Process.Id -and $_.Name -eq $Process.Name}
                }

                if ($ShutdownUrl -ne "") {
                    Write-Log -Level Info "Trying to shutdown $($Title) via API$(if ($Name) {": $($Name)"})"
                    $oldProgressPreference = $Global:ProgressPreference
                    $Global:ProgressPreference = "SilentlyContinue"
                    try {
                        $Response = Invoke-GetUrl $ShutdownUrl -Timeout 20 -ErrorAction Stop

                        $StopWatch.Restart()
                        while (($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) -and $StopWatch.Elapsed.TotalSeconds -le 20) {
                            Start-Sleep -Milliseconds 500
                        }
                        if ($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) {
                            Write-Log -Level Warn "$($Title) failed to close within 20 seconds via API $(if ($Name) {": $($Name)"})"
                        }
                        $StopWatch.Restart()
                    }
                    catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                        Write-Log -Level Warn "Failed to shutdown process $($Title) via API$(if ($Name) {": $($Name)"})"
                    }
                    $Global:ProgressPreference = $oldProgressPreference
                }

                if ($IsWindows) {

                    #
                    # shutdown Windows miners
                    #

                    if ($Job.OwnWindow) {
                        $Process.CloseMainWindow() > $null
                    } else {
                        if (-not $Process.HasExited) {
                            Write-Log -Level Info "Attempting to kill $($Title) PID $($_)$(if ($Name) {": $($Name)"})"
                            Stop-Process -InputObject $Process -ErrorAction Ignore -Force
                        }
                    }

                } else {

                    #
                    # shutdown Linux miners
                    #

                    if ($Job.ScreenName) {
                        try {
                            if ($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) {
                                Write-Log -Level Info "Send ^C to $($Title)'s screen $($Job.ScreenName)"

                                $ArgumentList = "-S $($Job.ScreenName) -X stuff `^C"
                                if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                                    $Cmd = "screen $ArgumentList"
                                    $Msg = Invoke-OCDaemon -Cmd $Cmd
                                    if ($Msg) {Write-Log -Level Info "OCDaemon for `"$Cmd`" reports: $Msg"}
                                } else {
                                    $Screen_Process = Start-Process "screen" -ArgumentList $ArgumentList -PassThru
                                    $Screen_Process.WaitForExit(5000) > $null
                                }

                                $StopWatch.Restart()
                                while (($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) -and $StopWatch.Elapsed.TotalSeconds -le 10) {
                                    Start-Sleep -Milliseconds 500
                                }

                                if ($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) {
                                    Write-Log -Level Warn "$($Title) failed to close within 10 seconds$(if ($Name) {": $($Name)"})"
                                }
                            }

                            $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($Job.ScreenName)_info.txt"
                            if ($MI = Get-Content $PIDInfo -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore) {
                                if (-not $Process.HasExited -and (Get-Command "start-stop-daemon" -ErrorAction Ignore)) {
                                    Write-Log -Level Info "Call start-stop-daemon to kill $($Title)"
                                    $ArgumentList = "--stop --name $($Process.Name) --pidfile $($MI.pid_path) --retry 5"
                                    if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                                        $Cmd = "start-stop-daemon $ArgumentList"
                                        $Msg = Invoke-OCDaemon -Cmd $Cmd
                                        if ($Msg) {Write-Log -Level Info "OCDaemon for $Cmd reports: $Msg"}
                                    } else {
                                        $StartStopDaemon_Process = Start-Process "start-stop-daemon" -ArgumentList $ArgumentList -PassThru
                                        if (-not $StartStopDaemon_Process.WaitForExit(10000)) {
                                            Write-Log -Level Info "start-stop-daemon failed to close $($Title) within 10 seconds$(if ($Name) {": $($Name)"})"
                                        }
                                    }
                                }
                                if (Test-Path $MI.pid_path) {Remove-Item -Path $MI.pid_path -ErrorAction Ignore -Force}
                                if (Test-Path $PIDInfo) {Remove-Item -Path $PIDInfo -ErrorAction Ignore -Force}
                            }

                        } catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            Write-Log -Level Warn "Problem killing screen process $($Job.ScreenName): $($_.Exception.Message)"
                        }
                    } else {
                        $ToKill | Where-Object {-not $_.HasExited} | Foreach-Object {
                            Write-Log -Level Info "Attempting to kill $($Title) PID $($_.Id)$(if ($Name) {": $($Name)"})"
                            if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                                Invoke-OCDaemon -Cmd "kill $($_.Id)" > $null
                            } else {
                                Stop-Process -InputObject $_ -Force -ErrorAction Ignore
                            }
                        }
                    }

                }

                #
                # Wait for miner to shutdown
                #

                while (($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) -and $StopWatch.Elapsed.TotalSeconds -le $WaitForExit) {
                    Write-Log -Level Info "Wait for exit of $($Title) PID $($_) ($($StopWatch.Elapsed.TotalSeconds)s elapsed)$(if ($Name) {": $($Name)"})"
                    Start-Sleep -Seconds 1
                }

                if ($WaitForExit -gt 0) {
                    if ($null -in $ToKill.HasExited -or $false -in $ToKill.HasExited) {
                        Write-Log -Level Warn "Alas! $($Title) failed to close within $WaitForExit seconds$(if ($Name) {": $($Name)"}) - $(if ($Session.Config.EnableRestartComputer) {"REBOOTING COMPUTER NOW"} else {"PLEASE REBOOT COMPUTER!"})"
                        if ($Session.Config.EnableRestartComputer) {$Session.RestartComputer = $true}
                    } else {
                        Write-Log "$($Title) closed gracefully$(if ($Name) {": $($Name)"})"
                        Start-Sleep -Seconds 1
                    }
                }
            }
        }
    }

    #
    # Second round - kill
    #
    if ($Job.ProcessId) {
        $Job.ProcessId | Foreach-Object {
            if ($Process = Get-Process -Id $_ -ErrorAction Ignore) {
                if (-not $Process.HasExited) {
                    Write-Log -Level Info "Attempting to kill $($Title) PID $($_)$(if ($Name) {": $($Name)"})"
                    #if ($IsLinux -and (Test-OCDaemon)) {
                    #    Invoke-OCDaemon -Cmd "kill -9 $($_.Id)" > $null
                    #} else {
                        Stop-Process -InputObject $Process -ErrorAction Ignore -Force
                    #}
                }
            }
        }
        $Job.ProcessId = [int[]]@()
    }

    if ($Job.XJob) {
        Remove-Job $Job.XJob -Force -ErrorAction Ignore
        $Job.Name = $null
        $Job.XJob = $null
    }

    if ($IsLinux -and $Job.ScreenName) {
        try {
            $ScreenCmd = "screen -ls | grep $($Job.ScreenName) | cut -f1 -d'.' | sed 's/\W//g'"
            if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                [int]$ScreenProcessId = Invoke-OCDaemon -Cmd $ScreenCmd
                $OCDcount++
            } else {
                [int]$ScreenProcessId = Invoke-Expression $ScreenCmd
            }
            if ($ScreenProcessId) {
                $ArgumentList = "-S $($Job.ScreenName) -X quit"
                if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                    $Cmd = "screen $ArgumentList"
                    $Msg = Invoke-OCDaemon -Cmd $Cmd
                    if ($Msg) {Write-Log -Level Info "OCDaemon for `"$Cmd`" reports: $Msg"}
                } else {
                    $Screen_Process = Start-Process "screen" -ArgumentList $ArgumentList -PassThru
                    $Screen_Process.WaitForExit(5000) > $null
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Problem killing bash screen $($Job.ScreenName): $($_.Exception.Message)"
        }
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
        [String]$ArgumentList = "-qb",
        [Parameter(Mandatory = $false)]
        [Switch]$EnableMinerBackups = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableKeepDownloads = $false
    )

    # Set current path used by .net methods to the same as the script's path
    [Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads"))  {New-Item "Downloads" -ItemType "directory" > $null}
    if (-not (Test-Path ".\Bin"))        {New-Item "Bin" -ItemType "directory" > $null}
    if (-not (Test-Path ".\Bin\Common")) {New-Item "Bin\Common" -ItemType "directory" > $null}
    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    if (Test-Path $FileName) {Remove-Item $FileName}
    $oldProgressPreference = $Global:ProgressPreference
    $Global:ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing -DisableKeepAlive
    $Global:ProgressPreference = $oldProgressPreference

    if ($Sha256 -and (Test-Path $FileName)) {if ($Sha256 -ne (Get-FileHash $FileName -Algorithm SHA256).Hash) {Remove-Item $FileName; throw "Downloadfile $FileName has wrong hash! Please open an issue at github.com."}}

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        $Run_Process = Start-Process $FileName $ArgumentList -PassThru
        $Run_Process.WaitForExit()>$null
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
        $Extract_Process = Start-Process @Params
        $Extract_Process.WaitForExit()>$null

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
            $ProtectedFiles | Foreach-Object {
                $CheckForFile_Path = Split-Path $_
                $CheckForFile_Name = Split-Path $_ -Leaf
                Get-ChildItem (Join-Path $Path_Bak $_) -ErrorAction Ignore -File | Where-Object {[IO.Path]::GetExtension($_) -notmatch "(dll|exe|bin)$"} | Foreach-Object {
                    if ($CheckForFile_Path) {
                        $CopyToPath = Join-Path $Path_New $CheckForFile_Path
                        if (-not (Test-Path $CopyToPath)) {
                            New-Item $CopyToPath -ItemType Directory -ErrorAction Ignore > $null
                        }
                    } else {
                        $CopyToPath = $Path_New
                    }
                    if ($_.Length -lt 10MB) {
                        Copy-Item $_ $CopyToPath -Force
                    } else {
                        Move-Item $_ $CopyToPath -Force
                    }
                }
            }
            $SkipBackups = if ($EnableMinerBackups) {3} else {0}
            Get-ChildItem (Join-Path (Split-Path $Path) "$(Split-Path $Path -Leaf).*") -Directory | Sort-Object Name -Descending | Select-Object -Skip $SkipBackups | Foreach-Object {
                try {
                    Remove-Item $_ -Recurse -Force
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "Downloader: Could not to remove backup path $_. Please do this manually, root might be needed ($($_.Exception.Message))"
                }
            }
        }
    }
    if (-not $EnableKeepDownloads -and (Test-Path $FileName)) {
        Get-ChildItem $FileName -File | Foreach-Object {Remove-Item $_}
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
            #$out = [RBMTools.process]::exec("$(if ($NewFilePath = Resolve-Path $FilePath -ErrorAction Ignore) {$NewFilePath} else {$FilePath})",$ArgumentList,$WorkingDirectory,"$(if ($Runas) {"runas"})",[int]$WaitForExit)
            #if ($ExpandLines) {foreach ($line in $out) {if (-not $ExcludeEmptyLines -or "$line".Trim() -ne ''){"$line" -replace "[`r`n]+"}}} else {$out -join [Environment]::NewLine}
            $psi = [System.Diagnostics.ProcessStartInfo]::New()
            $psi.FileName               = if ($NewFilePath = Resolve-Path $FilePath -ErrorAction Ignore) {$NewFilePath} else {$FilePath}
            $psi.CreateNoWindow         = $true
            $psi.UseShellExecute        = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.Arguments              = $ArgumentList
            $psi.WorkingDirectory       = $WorkingDirectory
            if ($Runas) {$psi.Verb = "runas"}
            $process = [System.Diagnostics.Process]::New()
            $process.StartInfo = $psi
            [void]$process.Start()
            $out = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit($WaitForExit*1000)>$null
            if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}
            $Global:LASTEXEEXITCODE = $process.ExitCode
        } else {
            if ($FilePath -match "IncludesLinux") {$FilePath = Get-Item $FilePath | Select-Object -ExpandProperty FullName}
            if (Test-OCDaemon) {
                $out = Invoke-OCDaemon -Cmd "$FilePath $ArgumentList".Trim()
            } else {
                Write-Log -Level Warn "Could not execute sudo $("$FilePath $ArgumentList".Trim()) (ocdaemon is not running. Please stop RainbowMiner and run `"./install.sh`")"
            }
            if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}
        }

    } catch {
        if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Could not execute $FilePath $($ArgumentList): $($_.Exception.Message)"
    } finally {
        if ($psi) {
            $process.Dispose()
        }
    }
}

function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $false)]
        [String]$Port, 
        [Parameter(Mandatory = $false)]
        [String]$Request = "",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds,
        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},
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
    try {
        if ($Server -match "^http") {
            $Uri = [System.Uri]::New($Server)
            $Server = $Uri.Host
            $Port   = $Uri.Port
        }
        $Client = [System.Net.Sockets.TcpClient]::new($Server, $Port)
        #$Client.LingerState = [System.Net.Sockets.LingerOption]::new($true, 0)
        $Stream = $Client.GetStream()
        $Writer = [System.IO.StreamWriter]::new($Stream)
        if (-not $WriteOnly -or $Uri) {$Reader = [System.IO.StreamReader]::new($Stream)}
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        if ($Uri) {
            $Writer.NewLine = "`r`n"
            $Writer.WriteLine("GET $($Uri.PathAndQuery) HTTP/1.1")
            $Writer.WriteLine("Host: $($Server):$($Port)")
            $Writer.WriteLine("Cache-Control: no-cache")
            if ($headers -and $headers.Keys) {
                $headers.Keys | Foreach-Object {$Writer.WriteLine("$($_): $($headers[$_])")}
            }
            $Writer.WriteLine("Connection: close")
            $Writer.WriteLine("")

            $cnt = 0
            $closed = $false
            while ($cnt -lt 20 -and -not $Reader.EndOfStream -and ($line = $Reader.ReadLine())) {
                $line = $line.Trim()
                if ($line -match "HTTP/[0-9\.]+\s+(\d{3}.*)") {$HttpCheck = $Matches[1]}
                elseif ($line -match "Connection:\s+close") {$closed = $true}
                $cnt++
            }

            if ($line -eq $null) {throw "empty response"}
            if (-not $HttpCheck) {throw "invalid response"}
            if ($HttpCheck -notmatch "^2") {throw $HttpCheck}

            $Response = $Reader.ReadToEnd()
        } else {
            if ($Request) {if ($DoNotSendNewline) {$Writer.Write($Request)} else {$Writer.WriteLine($Request)}}
            if (-not $WriteOnly) {$Response = if ($ReadToEnd) {$Reader.ReadToEnd()} else {$Reader.ReadLine()}}
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "TCP request to $($Server):$($Port) failed: $($_.Exception.Message)"
    }
    finally {
        if ($Client) {$Client.Close();$Client.Dispose()}
        if ($Reader) {$Reader.Dispose()}
        if ($Writer) {$Writer.Dispose()}
        if ($Stream) {$Stream.Dispose()}
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
        $Client = [System.Net.Sockets.TcpClient]::new($Server, $Port)
        $Stream = $Client.GetStream()
        $Reader = [System.IO.StreamReader]::new($Stream)
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Response = $Reader.ReadToEnd()
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "Could not read from $($Server):$($Port)"
    }
    finally {
        if ($Client) {$Client.Close();$Client.Dispose()}
        if ($Reader) {$Reader.Dispose()}
        if ($Stream) {$Stream.Dispose()}
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
        $Client.Dispose()
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

    if ($Name) {
        $DeviceList = Get-ContentByStreamReader ".\Data\devices.json" | ConvertFrom-Json -ErrorAction Ignore
        $Name_Devices = $Name | ForEach-Object {
            $Name_Split = @("*","*","*")
            $ix = 0;foreach ($a in ($_ -split '#' | Select-Object -First 3)) {$Name_Split[$ix] = if ($ix -gt 0) {[int]$a} else {$a};$ix++}
            if ($DeviceList.("{0}" -f $Name_Split)) {
                $Name_Device = $DeviceList.("{0}" -f $Name_Split) | Select-Object *
                $Name_Device.PSObject.Properties.Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}
                $Name_Device
            }
        }
    }

    if ($ExcludeName) {
        if (-not $DeviceList) {$DeviceList = Get-ContentByStreamReader ".\Data\devices.json" | ConvertFrom-Json -ErrorAction Ignore}
        $ExcludeName_Devices = $ExcludeName | ForEach-Object {
            $Name_Split = @("*","*","*")
            $ix = 0;foreach ($a in ($_ -split '#' | Select-Object -First 3)) {$Name_Split[$ix] = if ($ix -gt 0) {[int]$a} else {$a};$ix++}
            if ($DeviceList.("{0}" -f $Name_Split)) {
                $Name_Device = $DeviceList.("{0}" -f $Name_Split) | Select-Object *
                $Name_Device.PSObject.Properties.Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}
                $Name_Device
            }
        }
    }

    if (-not (Test-Path Variable:Global:GlobalCachedDevices) -or $Refresh) {
        $Global:GlobalCachedDevices = @()

        $PlatformId = 0
        $Index = 0
        $PlatformId_Index = @{}
        $Type_PlatformId_Index = @{}
        $Vendor_Index = @{}
        $Type_Vendor_Index = @{}
        $Type_Index = @{}
        $Type_Mineable_Index = @{}
        $Type_Codec_Index = @{}
        $GPUVendorLists = @{}
        $GPUDeviceNames = @{}

        $KnownVendors = @("AMD","INTEL","NVIDIA")

        foreach ($GPUVendor in $KnownVendors) {$GPUVendorLists | Add-Member $GPUVendor @(Get-GPUVendorList $GPUVendor)}
        
        if ($IsWindows) {
            #Get WDDM data               
            $Global:WDDM_Devices = try {
                Get-CimInstance CIM_VideoController | ForEach-Object {
                    $PnpDevice = Get-PnpDevice $_.PNPDeviceId
                    $BusId         = ($PnpDevice | Get-PnpDeviceProperty "DEVPKEY_Device_BusNumber" -ErrorAction Ignore).Data
                    $DeviceAddress = ($PnpDevice | Get-PnpDeviceProperty "DEVPKEY_Device_Address" -ErrorAction Ignore).Data
                    if ($DeviceAddress -eq $null) {$DeviceAddress = 0}
                    [PSCustomObject]@{
                        Name        = $_.Name
                        InstanceId  = $_.PNPDeviceId
                        BusId       = $(if ($BusId -ne $null -and $BusId.GetType() -match "int") {"{0:x2}:{1:x2}" -f $BusId,([int]$DeviceAddress -shr 16)})
                        Vendor      = switch -Regex ([String]$_.AdapterCompatibility) { 
                                        "Advanced Micro Devices" {"AMD"}
                                        "Intel"  {"INTEL"}
                                        "NVIDIA" {"NVIDIA"}
                                        "AMD"    {"AMD"}
                                        default {$_.AdapterCompatibility -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                            }
                    }
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "WDDM device detection has failed. "
            }
            $Global:WDDM_Devices = @($Global:WDDM_Devices | Sort-Object {[int]"0x0$($_.BusId -replace "[^0-9A-F]+")"})
        }

        [System.Collections.Generic.List[string]]$AllPlatforms = @()
        $Platform_Devices = try {
            [OpenCl.Platform]::GetPlatformIDs() | Where-Object {$AllPlatforms -inotcontains "$($_.Name) $($_.Version)"} | ForEach-Object {
                $AllPlatforms.Add("$($_.Name) $($_.Version)") > $null
                $Device_Index = 0
                $PlatformVendor = switch -Regex ([String]$_.Vendor) { 
                                        "Advanced Micro Devices" {"AMD"}
                                        "Intel"  {"INTEL"}
                                        "NVIDIA" {"NVIDIA"}
                                        "AMD"    {"AMD"}
                                        default {$_.Vendor -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                            }
                [PSCustomObject]@{
                    PlatformId=$PlatformId
                    Vendor=$PlatformVendor
                    Devices=[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | Foreach-Object {
                        [PSCustomObject]@{
                            DeviceIndex      = $Device_Index
                            Name             = $_.Name
                            Architecture     = $_.Architecture
                            Type             = $_.Type
                            Vendor           = $_.Vendor
                            GlobalMemSize    = $_.GlobalMemSize
                            GlobalMemSizeGB  = [int]($_.GlobalMemSize/1GB)
                            MaxComputeUnits  = $_.MaxComputeUnits
                            PlatformVersion  = $_.Platform.Version
                            DriverVersion    = $_.DriverVersion
                            PCIBusId         = $_.PCIBusId
                            DeviceCapability = $_.DeviceCapability
                            CardId           = -1
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
                        Architecture    = $_.gpu_name
                        Type            = "Gpu"
                        Vendor          = "NVIDIA Corporation"
                        GlobalMemSize   = 1MB * [int64]$_.memory_total
                        GlobalMemSizeGB = [int]($_.memory_total/1kB)
                        PlatformVersion = "CUDA $Cuda"
                        PCIBusId        = if ($_.pci_bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                        CardId          = -1
                    }
                }
                if ($OpenCL_Devices) {[PSCustomObject]@{PlatformId=$PlatformId;Vendor="NVIDIA";Devices=$OpenCL_Devices}}
            } else {
                Write-Log -Level $(if ($IgnoreOpenCL) {"Info"} else {"Warn"}) "OpenCL device detection has failed: $($_.Exception.Message)"
            }
        }

        try {
            $AmdModels   = @{}
            [System.Collections.Generic.List[string]]$AmdModelsEx = @()
            $Platform_Devices | Foreach-Object {
                $PlatformId = $_.PlatformId
                $PlatformVendor = $_.Vendor
                $_.Devices | Where-Object {$_} | Foreach-Object {    
                    $Device_OpenCL = $_

                    $Vendor_Name = [String]$Device_OpenCL.Vendor

                    if ($GPUVendorLists.NVIDIA -icontains $Vendor_Name) {
                        $Vendor_Name = "NVIDIA"
                    } elseif ($GPUVendorLists.AMD -icontains $Vendor_Name) {
                        $Vendor_Name = "AMD"
                    } elseif ($GPUVendorLists.INTEL -icontains $Vendor_Name) {
                        $Vendor_Name = "INTEL"
                    }

                    $Device_Name = Get-NormalizedDeviceName $Device_OpenCL.Name -Vendor $Vendor_Name
                    $InstanceId  = ''
                    $SubId = ''
                    $PCIBusId = $null
                    $CardId = -1

                    if ($Vendor_Name -eq "AMD") {
                        if (-not $GPUDeviceNames[$Vendor_Name]) {
                            $GPUDeviceNames[$Vendor_Name] = if ($IsLinux) {
                                if ((Test-OCDaemon) -or (Test-IsElevated)) {
                                    try {
                                        $data = @(Get-DeviceName "amd" -UseAfterburner $false | Select-Object)
                                        if (($data | Measure-Object).Count) {Set-ContentJson ".\Data\amd-names.json" -Data $data > $null}
                                    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                                }
                                if (Test-Path ".\Data\amd-names.json") {Get-ContentByStreamReader ".\Data\amd-names.json" | ConvertFrom-Json -ErrorAction Ignore}
                            }
                            if (-not $GPUDeviceNames[$Vendor_Name]) {
                                $GPUDeviceNames[$Vendor_Name] = Get-DeviceName $Vendor_Name -UseAfterburner ($OpenCL_DeviceIDs.Count -lt 7)
                            }
                        }

                        $GPUDeviceNameFound = $null
                        if ($Device_OpenCL.PCIBusId -match "[A-F0-9]+:[A-F0-9]+$") {
                            $GPUDeviceNameFound = $GPUDeviceNames[$Vendor_Name] | Where-Object PCIBusId -eq $Device_OpenCL.PCIBusId | Select-Object -First 1
                        }
                        if (-not $GPUDeviceNameFound) {
                            $GPUDeviceNameFound = $GPUDeviceNames[$Vendor_Name] | Where-Object Index -eq ([Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)") | Select-Object -First 1
                        }
                        
                        if ($GPUDeviceNameFound) {
                            $Device_Name = $GPUDeviceNameFound.DeviceName
                            $InstanceId  = $GPUDeviceNameFound.InstanceId
                            $SubId       = $GPUDeviceNameFound.SubId
                            $PCIBusId    = $GPUDeviceNameFound.PCIBusId
                            $CardId      = $GPUDeviceNameFound.CardId
                        }

                        # fix some AMD names
                        if ($SubId -eq "687F" -or $Device_Name -eq "Radeon RX Vega" -or $Device_Name -eq "gfx900") {
                            if ($Device_OpenCL.MaxComputeUnits -eq 56) {$Device_Name = "Radeon Vega 56"}
                            elseif ($Device_OpenCL.MaxComputeUnits -eq 64) {$Device_Name = "Radeon Vega 64"}
                        } elseif ($Device_Name -eq "gfx906" -or $Device_Name -eq "gfx907") {
                            $Device_Name = "Radeon VII"
                        } elseif ($Device_Name -eq "gfx1010") {
                            $Device_Name = "Radeon RX 5700 XT"
                        }

                        # fix PCIBusId
                        if ($PCIBusId) {$Device_OpenCL.PCIBusId = $PCIBusId}
                    }

                    $Model = [String]$($Device_Name -replace "[^A-Za-z0-9]+" -replace "GeForce|Radeon|Intel")

                    if ($Model -eq "") { #alas! empty
                        if ($Device_OpenCL.Architecture) {
                            $Model = "$($Device_OpenCL.Architecture)"
                            $Device_Name = "$($Device_Name)$(if ($Device_Name) {" "})$($Model)"
                        } elseif ($InstanceId -and $InstanceId -match "VEN_([0-9A-F]{4}).+DEV_([0-9A-F]{4}).+SUBSYS_([0-9A-F]{4,8})") {
                            try {
                                $Result = Invoke-GetUrl "https://rbminer.net/api/pciids.php?ven=$($Matches[1])&dev=$($Matches[2])&subsys=$($Matches[3])"
                                if ($Result.status) {
                                    $Device_Name = if ($Result.data -match "\[(.+)\]") {$Matches[1]} else {$Result.data}
                                    if ($Vendor_Name -eq "AMD" -and $Device_Name -notmatch "Radeon") {$Device_Name = "Radeon $($Device_Name)"}
                                    $Model = [String]$($Device_Name -replace "[^A-Za-z0-9]+" -replace "GeForce|Radeon|Intel")
                                }
                            } catch {
                            }
                        }
                        if ($Model -eq "") {
                            $Model = "Unknown"
                            $Device_Name = "$($Device_Name)$(if ($Device_Name) {" "})$($Model)"
                        }
                    }

                    if ($Vendor_Name -eq "NVIDIA") {
                        $Codec = "CUDA"
                        $Device_OpenCL.Architecture = Get-NvidiaArchitecture $Model
                    } else {
                        $Codec = "OpenCL"
                    }

                    $Device = [PSCustomObject]@{
                        Name = ""
                        Index = [Int]$Index
                        PlatformId = [Int]$PlatformId
                        PlatformId_Index = [Int]$PlatformId_Index."$($PlatformId)"
                        Type_PlatformId_Index = [Int]$Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"
                        Platform_Vendor = $PlatformVendor
                        Vendor = [String]$Vendor_Name
                        Vendor_Name = [String]$Device_OpenCL.Vendor
                        Vendor_Index = [Int]$Vendor_Index."$($Device_OpenCL.Vendor)"
                        Type = [String]$Device_OpenCL.Type
                        Type_Index = [Int]$Type_Index."$($Device_OpenCL.Type)"
                        Type_Codec_Index = [Int]$Type_Codec_Index."$($Device_OpenCL.Type)".$Codec
                        Type_Mineable_Index = [Int]$Type_Mineable_Index."$($Device_OpenCL.Type)"
                        Type_Vendor_Index = [Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"
                        BusId_Index               = 0
                        BusId_Type_Index          = 0
                        BusId_Type_Vendor_Index   = 0
                        BusId_Type_Mineable_Index = 0
                        BusId_Vendor_Index        = 0

                        OpenCL = $Device_OpenCL
                        Codec = $Codec
                        Model = $Model
                        Model_Base = $Model
                        Model_Name = [String]$Device_Name
                        InstanceId = [String]$InstanceId
                        CardId = $CardId
                        BusId = $null
                        GpuGroup = ""

                        Data = [PSCustomObject]@{
                                        AdapterId         = 0  #amd
                                        Utilization       = 0  #amd/nvidia
                                        UtilizationMem    = 0  #amd/nvidia
                                        Clock             = 0  #amd/nvidia
                                        ClockMem          = 0  #amd/nvidia
                                        FanSpeed          = 0  #amd/nvidia
                                        Temperature       = 0  #amd/nvidia
                                        PowerDraw         = 0  #amd/nvidia
                                        PowerLimit        = 0  #nvidia
                                        PowerLimitPercent = 0  #amd/nvidia
                                        PowerMaxLimit     = 0  #nvidia
                                        PowerDefaultLimit = 0  #nvidia
                                        Pstate            = "" #nvidia
                                        Method            = "" #amd/nvidia
                        }
                        DataMax = [PSCustomObject]@{
                                    Clock       = 0
                                    ClockMem    = 0
                                    Temperature = 0
                                    FanSpeed    = 0
                                    PowerDraw   = 0
                        }
                    }

                    if ($Device.Type -ne "Cpu") {
                        $Device.Name = ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper()
                        $Global:GlobalCachedDevices += $Device
                        if ($AmdModelsEx -notcontains $Device.Model) {
                            $AmdGb = $Device.OpenCL.GlobalMemSizeGB
                            if ($AmdModels.ContainsKey($Device.Model) -and $AmdModels[$Device.Model] -ne $AmdGb) {$AmdModelsEx.Add($Device.Model) > $null}
                            else {$AmdModels[$Device.Model]=$AmdGb}
                        }
                        $Index++
                        if ($Vendor_Name -in @("NVIDIA","AMD")) {$Type_Mineable_Index."$($Device_OpenCL.Type)"++}
                        if ($Device_OpenCL.PCIBusId -match "([A-F0-9]+:[A-F0-9]+)$") {
                            $Device.BusId = $Matches[1]
                        }
                        if ($IsWindows) {
                            $Global:WDDM_Devices | Where-Object {$_.Vendor -eq $Vendor_Name} | Select-Object -Index $Device.Type_Vendor_Index | Foreach-Object {
                                if ($_.BusId -ne $null -and $Device.BusId -eq $null) {$Device.BusId = $_.BusId}
                                if ($_.InstanceId -and $Device.InstanceId -eq "")    {$Device.InstanceId = $_.InstanceId}
                            }
                        }
                    }

                    if (-not $Type_Codec_Index."$($Device_OpenCL.Type)") {
                        $Type_Codec_Index."$($Device_OpenCL.Type)" = @{}
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
                    $Type_Index."$($Device_OpenCL.Type)"++
                    $Type_Codec_Index."$($Device_OpenCL.Type)".$Codec++
                    $Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"++
                }
            }

            $AmdModelsEx | Foreach-Object {
                $Model = $_
                $Global:GlobalCachedDevices | Where-Object Model -eq $Model | Foreach-Object {
                    $AmdGb = "$($_.OpenCL.GlobalMemSizeGB)GB"
                    $_.Model = "$($_.Model)$AmdGb"
                    $_.Model_Base = "$($_.Model_Base)$AmdGb"
                    $_.Model_Name = "$($_.Model_Name) $AmdGb"
                }
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level $(if ($IgnoreOpenCL) {"Info"} else {"Warn"}) "GPU detection has failed: $($_.Exception.Message)"
        }

        #re-index in case the OpenCL platforms have shifted positions
        if ($Platform_Devices) {
            try {
                if ($Session.OpenCLPlatformSorting) {
                    $OpenCL_Platforms = $Session.OpenCLPlatformSorting
                } elseif (Test-Path ".\Data\openclplatforms.json") {
                    $OpenCL_Platforms = Get-ContentByStreamReader ".\Data\openclplatforms.json" | ConvertFrom-Json -ErrorAction Ignore
                }

                if (-not $OpenCL_Platforms) {
                    $OpenCL_Platforms = @()
                }

                $OpenCL_Platforms_Current = @($Platform_Devices | Sort-Object {$_.Vendor -notin $KnownVendors},PlatformId | Foreach-Object {"$($_.Vendor)"})

                if (Compare-Object $OpenCL_Platforms $OpenCL_Platforms_Current | Where-Object SideIndicator -eq "=>") {
                    $OpenCL_Platforms_Current | Where-Object {$_ -notin $OpenCL_Platforms} | Foreach-Object {$OpenCL_Platforms += $_}
                    if (-not $Session.OpenCLPlatformSorting -or -not (Test-Path ".\Data\openclplatforms.json")) {
                        Set-ContentJson -PathToFile ".\Data\openclplatforms.json" -Data $OpenCL_Platforms > $null
                    }
                }

                $Index = 0
                $Need_Sort = $false
                $Global:GlobalCachedDevices | Sort-Object {$OpenCL_Platforms.IndexOf($_.Platform_Vendor)},Index | Foreach-Object {
                    if ($_.Index -ne $Index) {
                        $Need_Sort = $true
                        $_.Index = $Index
                        $_.Name = ("{0}#{1:d2}" -f $_.Type, $Index).ToUpper()
                    }
                    $Index++
                }

                if ($Need_Sort) {
                    Write-Log -Level Info "OpenCL platforms have changed from initial run. Resorting indices."
                    $Global:GlobalCachedDevices = @($Global:GlobalCachedDevices | Sort-Object Index | Select-Object)
                }

            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "OpenCL platform detection failed: $($_.Exception.Message)"
            }
        }

        #Roundup and add sort order by PCI busid
        $BusId_Index = 0
        $BusId_Type_Index = @{}
        $BusId_Type_Vendor_Index = @{}
        $BusId_Type_Mineable_Index = @{}
        $BusId_Vendor_Index = @{}

        $Global:GlobalCachedDevices | Sort-Object {[int]"0x0$($_.BusId -replace "[^0-9A-F]+")"},Index | Foreach-Object {
            $_.BusId_Index               = $BusId_Index++
            $_.BusId_Type_Index          = [int]$BusId_Type_Index."$($_.Type)"
            $_.BusId_Type_Vendor_Index   = [int]$BusId_Type_Vendor_Index."$($_.Type)"."$($_.Vendor)"
            $_.BusId_Type_Mineable_Index = [int]$BusId_Type_Mineable_Index."$($_.Type)"
            $_.BusId_Vendor_Index        = [int]$BusId_Vendor_Index."$($_.Vendor)"

            if (-not $BusId_Type_Vendor_Index."$($_.Type)") { 
                $BusId_Type_Vendor_Index."$($_.Type)" = @{}
            }

            $BusId_Type_Index."$($_.Type)"++
            $BusId_Type_Vendor_Index."$($_.Type)"."$($_.Vendor)"++
            $BusId_Vendor_Index."$($_.Vendor)"++
            if ($_.Vendor -in @("AMD","NVIDIA")) {$BusId_Type_Mineable_Index."$($_.Type)"++}
        }

        #CPU detection
        try {
            if ($Refresh -or -not (Test-Path Variable:Global:GlobalCPUInfo)) {

                $Global:GlobalCPUInfo = [PSCustomObject]@{}

                if ($IsWindows) {
                    $CIM_CPU = Get-CimInstance -ClassName CIM_Processor
                    $Global:GlobalCPUInfo | Add-Member Name          $CIM_CPU[0].Name
                    $Global:GlobalCPUInfo | Add-Member Manufacturer  $CIM_CPU[0].Manufacturer
                    $Global:GlobalCPUInfo | Add-Member Cores         ($CIM_CPU.NumberOfCores | Measure-Object -Sum).Sum
                    $Global:GlobalCPUInfo | Add-Member Threads       ($CIM_CPU.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
                    $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ($CIM_CPU | Measure-Object).Count
                    $Global:GlobalCPUInfo | Add-Member L3CacheSize   $CIM_CPU[0].L3CacheSize
                    $Global:GlobalCPUInfo | Add-Member MaxClockSpeed $CIM_CPU[0].MaxClockSpeed
                    $Global:GlobalCPUInfo | Add-Member Features      @{}

                    try {
                        (Invoke-Exe ".\Includes\list_cpu_features.exe" -ArgumentList "--json" -WorkingDirectory $Pwd | ConvertFrom-Json -ErrorAction Stop).flags | Foreach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]")" = $true}
                    } catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                    }

                    if (-not $Global:GlobalCPUInfo.Features.Count) {
                        $chkcpu = @{}
                        try {([xml](Invoke-Exe ".\Includes\CHKCPU32.exe" -ArgumentList "/x" -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines)).chkcpu32.ChildNodes | Foreach-Object {$chkcpu[$_.Name] = if ($_.'#text' -match "^(\d+)") {[int]$Matches[1]} else {$_.'#text'}}} catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        $chkcpu.Keys | Where-Object {"$($chkcpu.$_)" -eq "1" -and $_ -notmatch '_' -and $_ -notmatch "^l\d$"} | Foreach-Object {$Global:GlobalCPUInfo.Features.$_ = $true}
                    }

                    $Global:GlobalCPUInfo.Features."$(if ([Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"})" = $true

                } elseif ($IsLinux) {
                    try {
                        Write-ToFile -FilePath ".\Data\lscpu.txt" -Message "$(Invoke-Exe "lscpu")" -NoCR > $null
                    } catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                    }
                    $Data = Get-Content "/proc/cpuinfo"
                    if ($Data) {
                        $Global:GlobalCPUInfo | Add-Member Name          "$((($Data | Where-Object {$_ -match 'model name'} | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Manufacturer  "$((($Data | Where-Object {$_ -match 'vendor_id'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Cores         ([int]"$((($Data | Where-Object {$_ -match 'cpu cores'}  | Select-Object -First 1) -split ":")[1])".Trim())
                        $Global:GlobalCPUInfo | Add-Member Threads       ([int]"$((($Data | Where-Object {$_ -match 'siblings'}   | Select-Object -First 1) -split ":")[1])".Trim())
                        $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ($Data | Where-Object {$_ -match 'physical id'} | Select-Object -Unique | Measure-Object).Count
                        $Global:GlobalCPUInfo | Add-Member L3CacheSize   ([int](ConvertFrom-Bytes "$((($Data | Where-Object {$_ -match 'cache size'} | Select-Object -First 1) -split ":")[1])".Trim())/1024)
                        $Global:GlobalCPUInfo | Add-Member MaxClockSpeed ([int]"$((($Data | Where-Object {$_ -match 'cpu MHz'}    | Select-Object -First 1) -split ":")[1])".Trim())
                        $Global:GlobalCPUInfo | Add-Member Features      @{}

                        "$((($Data | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]+")" = $true}

                        $Processors = ($Data | Where-Object {$_ -match "^processor"} | Measure-Object).Count

                        if ($Global:GlobalCPUInfo.PhysicalCPUs -gt 1) {
                            $Global:GlobalCPUInfo.Cores   *= $Global:GlobalCPUInfo.PhysicalCPUs
                            $Global:GlobalCPUInfo.Threads *= $Global:GlobalCPUInfo.PhysicalCPUs
                            $Global:GlobalCPUInfo.PhysicalCPUs = 1
                        }

                        #adapt to virtual CPUs
                        if ($Processors -gt $Global:GlobalCPUInfo.Threads -and $Global:GlobalCPUInfo.Threads -eq 1) {
                            $Global:GlobalCPUInfo.Cores   = $Processors
                            $Global:GlobalCPUInfo.Threads = $Processors
                        }
                    }
                }

                if ($Global:GlobalCPUInfo.Features.avx512f -and $Global:GlobalCPUInfo.Features.avx512vl -and $Global:GlobalCPUInfo.Features.avx512dq -and $Global:GlobalCPUInfo.Features.avx512bw) {$Global:GlobalCPUInfo.Features.avx512 = $true}

                $Global:GlobalCPUInfo | Add-Member Vendor $(Switch -Regex ("$($Global:GlobalCPUInfo.Manufacturer)") {
                            "(AMD|Advanced Micro Devices)" {"AMD"}
                            "Intel" {"INTEL"}
                            default {"$($Global:GlobalCPUInfo.Manufacturer)".ToUpper() -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                        })

                if (-not $Global:GlobalCPUInfo.Vendor) {$Global:GlobalCPUInfo.Vendor = "OTHER"}

                $Global:GlobalCPUInfo | Add-Member RealCores ([int[]](0..($Global:GlobalCPUInfo.Threads - 1))) -Force
                if ($Global:GlobalCPUInfo.Threads -gt $Global:GlobalCPUInfo.Cores) {$Global:GlobalCPUInfo.RealCores = $Global:GlobalCPUInfo.RealCores | Where-Object {-not ($_ % [int]($Global:GlobalCPUInfo.Threads/$Global:GlobalCPUInfo.Cores))}}
            }
            $Global:GlobalCPUInfo | Add-Member IsRyzen ($Global:GlobalCPUInfo.Vendor -eq "AMD" -and $Global:GlobalCPUInfo.Name -match "Ryzen")
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "CIM CPU detection has failed. "
        }
   
        try {
            for ($CPUIndex=0;$CPUIndex -lt $Global:GlobalCPUInfo.PhysicalCPUs;$CPUIndex++) {
                # Vendor and type the same for all CPUs, so there is no need to actually track the extra indexes.  Include them only for compatibility.
                $Device = [PSCustomObject]@{
                    Name = ""
                    Index = [Int]$Index
                    Vendor = $Global:GlobalCPUInfo.Vendor
                    Vendor_Name = $Global:GlobalCPUInfo.Manufacturer
                    Type_PlatformId_Index = $CPUIndex
                    Type_Vendor_Index = $CPUIndex
                    Type = "Cpu"
                    Type_Index = $CPUIndex
                    Type_Mineable_Index = $CPUIndex
                    Type_Codec_Index = $CPUIndex
                    Model = "CPU"
                    Model_Base = "CPU"
                    Model_Name = $Global:GlobalCPUInfo.Name
                    Features = $Global:GlobalCPUInfo.Features.Keys
                    Data = [PSCustomObject]@{
                                Cores       = [int]($Global:GlobalCPUInfo.Cores / $Global:GlobalCPUInfo.PhysicalCPUs)
                                Threads     = [int]($Global:GlobalCPUInfo.Threads / $Global:GlobalCPUInfo.PhysicalCPUs)
                                CacheL3     = $Global:GlobalCPUInfo.L3CacheSize
                                Clock       = 0
                                Utilization = 0
                                PowerDraw   = 0
                                Temperature = 0
                                Method      = ""
                    }
                    DataMax = [PSCustomObject]@{
                                Clock       = 0
                                Utilization = 0
                                PowerDraw   = 0
                                Temperature = 0
                    }
                }

                $Device.Name = ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper()
                $Global:GlobalCachedDevices += $Device
                $Index++
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "CPU detection has failed. "
        }
    }

    $Global:GlobalCachedDevices | Foreach-Object {
        $Device = $_
        if (
            ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) -and
            ((-not $ExcludeName) -or (-not ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -and -not ($ExcludeName | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})))
            ) {
            $Device
        }
    }
}

function Get-DevicePowerDraw {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$DeviceName = @()
    )
    (($Global:GlobalCachedDevices | Where-Object {-not $DeviceName -or $DeviceName -icontains $_.Name}).Data.PowerDraw | Measure-Object -Sum).Sum
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

    $DeviceName = "$($DeviceName -replace '\([A-Z0-9 ]+\)?')"

    if ($Vendor -eq "AMD") {
        $DeviceName = "$($DeviceName `
                -replace 'ASUS' `
                -replace 'AMD' `
                -replace 'Series' `
                -replace 'Graphics' `
                -replace 'Adapter' `
                -replace '\d+GB$' `
                -replace "\s+", ' '
        )".Trim()

        if ($DeviceName -match '.*\s(HD)\s?(\w+).*') {"Radeon HD $($Matches[2])"}                 # HD series
        elseif ($DeviceName -match '.*\s(Vega).*(56|64).*') {"Radeon Vega $($Matches[2])"}        # Vega series
        elseif ($DeviceName -match '.*\s(R\d)\s(\w+).*') {"Radeon $($Matches[1]) $($Matches[2])"} # R3/R5/R7/R9 series
        elseif ($DeviceName -match '.*Radeon.*(5[567]00[\w\s]*)') {"Radeon RX $($Matches[1])"}         # RX 5000 series
        elseif ($DeviceName -match '.*Radeon.*([4-5]\d0).*') {"Radeon RX $($Matches[1])"}         # RX 400/500 series
        else {$DeviceName}
    } elseif ($Vendor) {
        "$($DeviceName `
                -replace $Vendor `
                -replace "\s+", ' '
        )".Trim()
    } else {
        "$($DeviceName `
                -replace "\s+", ' '
        )".Trim()
    }
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
        $Vendor_Cards = if (Test-Path ".\Data\$($Vendor.ToLower())-cards.json") {try {Get-ContentByStreamReader ".\Data\$($Vendor.ToLower())-cards.json" | ConvertFrom-Json -ErrorAction Stop}catch{if ($Error.Count){$Error.RemoveAt(0)}}}

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
                    Index      = $DeviceId
                    DeviceName = $DeviceName
                    InstanceId = $_.GpuId
                    SubId      = $SubId
                    PCIBusId   = if ($_.GpuId -match "&BUS_(\d+)&DEV_(\d+)") {"{0:x2}:{1:x2}" -f [int]$Matches[1],[int]$Matches[2]} else {$null}
                }
                $DeviceId++
            }
        } else {
            if ($IsWindows -and $Vendor -eq 'AMD') {

                $AdlStats = $null

                try {
                    $AdlResult = Invoke-Exe ".\Includes\odvii_$(if ([System.Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}).exe" -WorkingDirectory $Pwd
                    if ($AdlResult -notmatch "Failed") {
                        $AdlStats = $AdlResult | ConvertFrom-Json -ErrorAction Stop
                    }
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                }
                        
                if ($AdlStats -and $AdlStats.Count) {

                    $DeviceId = 0

                    $AdlStats | Foreach-Object {
                        $DeviceName = Get-NormalizedDeviceName $_."Adatper Name" -Vendor $Vendor
                        [PSCustomObject]@{
                            Index = $DeviceId
                            DeviceName = $DeviceName
                            SubId = 'noid'
                            PCIBusId = if ($_."Bus Id" -match "^([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
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
                Invoke-NvidiaSmi "index","gpu_name","pci.device_id","pci.bus_id","driver_version" -CheckForErrors | ForEach-Object {
                    $DeviceName = $_.gpu_name.Trim()
                    $SubId = if ($AdlResultSplit.Count -gt 1 -and $AdlResultSplit[1] -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                    if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                    [PSCustomObject]@{
                        Index         = $_.index
                        DeviceName    = $DeviceName
                        SubId         = if ($_.pci_device_id -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                        PCIBusId      = if ($_.pci_bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                        CardId        = -1
                        DriverVersion = "$($_.driver_version)"
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
    $Global:GlobalCachedDevices | Foreach-Object {
        $Model = $_.Model
        $PowerAdjust[$Model] = 100
        if ($DeviceConfig -and $DeviceConfig.$Model -ne $null -and $DeviceConfig.$Model.PowerAdjust -ne $null -and $DeviceConfig.$Model.PowerAdjust -ne "") {$PowerAdjust[$Model] = $DeviceConfig.$Model.PowerAdjust}
    }

    if (-not (Test-Path "Variable:Global:GlobalGPUMethod")) {
        $Global:GlobalGPUMethod = @{}
    }

    $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "GPU" -and $DeviceName -icontains $_.Name} | Group-Object Vendor | Foreach-Object {
        $Devices = $_.Group
        $Vendor = $_.Name

        try { #AMD
            if ($Vendor -eq 'AMD') {

                if ($Script:AmdCardsTDP -eq $null) {$Script:AmdCardsTDP = Get-ContentByStreamReader ".\Data\amd-cards-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}

                $Devices | Foreach-Object {$_.Data.Method = "";$_.Data.Clock = $_.Data.ClockMem = $_.Data.FanSpeed = $_.Data.Temperature = $_.Data.PowerDraw = 0}

                if ($IsWindows) {

                    $Success = 0

                    foreach ($Method in @("Afterburner","odvii8")) {

                        if (-not $Global:GlobalGPUMethod.ContainsKey($Method)) {$Global:GlobalGPUMethod.$Method = ""}

                        if ($Global:GlobalGPUMethod.$Method -eq "fail") {Continue}
                        if ($Method -eq "Afterburner" -and -not ($UseAfterburner -and $Script:abMonitor -and $Script:abControl)) {Continue}

                        try {

                            Switch ($Method) {

                                "Afterburner" {
                                    #
                                    # try Afterburner
                                    #
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
                                        $CardData    = $Script:abMonitor.Entries | Where-Object GPU -eq $_.Index
                                        $PowerLimitPercent = [int]$($Script:abControl.GpuEntries[$_.Index].PowerLimitCur)
                                        $Utilization = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage$").Data
                                        $PCIBusId    = if ($_.GpuId -match "&BUS_(\d+)&DEV_(\d+)") {"{0:x2}:{1:x2}" -f [int]$Matches[1],[int]$Matches[2]} else {$null}

                                        $Data = [PSCustomObject]@{
                                            Clock       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock$").Data
                                            ClockMem    = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock$").Data
                                            FanSpeed    = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed$").Data
                                            Temperature = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature$").Data
                                            PowerDraw   = $Script:AmdCardsTDP."$($_.Model_Name)" * ((100 + $PowerLimitPercent) / 100) * ($Utilization / 100)
                                        }

                                        $Devices | Where-Object {($_.BusId -and $PCIBusId -and ($_.BusId -eq $PCIBusId)) -or ((-not $_.BusId -or -not $PCIBusId) -and ($_.BusId_Type_Vendor_Index -eq $DeviceId))} | Foreach-Object {
                                            $NF = $_.Data.Method -eq ""
                                            $Changed = $false
                                            foreach($Value in @($Data.PSObject.Properties.Name)) {
                                                if ($NF -or $_.Data.$Value -le 0 -or ($Value -match "^Clock" -and $Data.$Value -gt 0)) {$_.Data.$Value = $Data.$Value;$Changed = $true}
                                            }

                                            if ($Changed) {
                                                $_.Data.Method = "$(if ($_.Data.Method) {";"})ab"
                                            }
                                        }
                                        $DeviceId++
                                    }
                                    if ($DeviceId) {
                                        $Global:GlobalGPUMethod.$Method = "ok"
                                        $Success++
                                    }
                                }

                                "odvii8" {
                                    #
                                    # try odvii8
                                    #

                                    $AdlStats = $null

                                    $AdlResult = Invoke-Exe ".\Includes\odvii_$(if ([System.Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}).exe" -WorkingDirectory $Pwd
                                    if ($AdlResult -notmatch "Failed") {
                                        $AdlStats = $AdlResult | ConvertFrom-Json -ErrorAction Stop
                                    }
                        
                                    if ($AdlStats -and $AdlStats.Count) {

                                        $DeviceId = 0

                                        $AdlStats | Foreach-Object {
                                            $CPstateMax = [Math]::max([int]($_."Core P_States")-1,0)
                                            $MPstateMax = [Math]::max([int]($_."Memory P_States")-1,0)
                                            $PCIBusId   = "$($_."Bus Id" -replace "\..+$")"

                                            $Data = [PSCustomObject]@{
                                                Clock       = [int]($_."Clock Defaults"."Clock P_State $CPstatemax")
                                                ClockMem    = [int]($_."Memory Defaults"."Clock P_State $MPstatemax")
                                                FanSpeed    = [int]($_."Fan Speed %")
                                                Temperature = [int]($_.Temperature)
                                                PowerDraw   = [int]($_.Wattage)
                                            }

                                            $Devices | Where-Object {($_.BusId -and $PCIBusId -and ($_.BusId -eq $PCIBusId)) -or ((-not $_.BusId -or -not $PCIBusId) -and ($_.BusId_Type_Vendor_Index -eq $DeviceId))} | Foreach-Object {
                                                $NF = $_.Data.Method -eq ""
                                                $Changed = $false
                                                foreach($Value in @($Data.PSObject.Properties.Name)) {
                                                    if ($NF -or $_.Data.$Value -le 0 -or ($Value -notmatch "^Clock" -and $Data.$Value -gt 0)) {$_.Data.$Value = $Data.$Value;$Changed = $true}
                                                }

                                                if ($Changed) {
                                                    $_.Data.Method = "$(if ($_.Data.Method) {";"})odvii8"
                                                }
                                            }

                                            $DeviceId++
                                        }
                                        if ($DeviceId) {
                                            $Global:GlobalGPUMethod.$Method = "ok"
                                            $Success++
                                        }
                                    }
                                }

                            }

                        } catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                        }

                        if ($Global:GlobalGPUMethod.$Method -eq "") {$Global:GlobalGPUMethod.$Method = "fail"}
                    }

                    if (-not $Success) {
                        Write-Log -Level Warn "Could not read power data from AMD"
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
                                    $_.Data.Temperature       = [decimal]($Data.PSObject.Properties | Where-Object {$_.Name -match "Temperature" -and $_.Name -notmatch "junction"} | Foreach-Object {[decimal]$_.Value} | Measure-Object -Average).Average
                                    $_.Data.PowerDraw         = [decimal]($Data.PSObject.Properties | Where-Object {$_.Name -match "Power"} | Select-Object -First 1 -ExpandProperty Value)
                                    $_.Data.FanSpeed          = [int]($Data.PSObject.Properties | Where-Object {$_.Name -match "Fan.+%"} | Select-Object -First 1 -ExpandProperty Value)
                                    $_.Data.Method            = "rocm"
                                }
                                $DeviceId++
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
                if ($Script:NvidiaCardsTDP -eq $null) {$Script:NvidiaCardsTDP = Get-ContentByStreamReader ".\Data\nvidia-cards-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}

                Invoke-NvidiaSmi "index","utilization.gpu","utilization.memory","temperature.gpu","power.draw","power.limit","fan.speed","pstate","clocks.current.graphics","clocks.current.memory","power.max_limit","power.default_limit" -CheckForErrors | ForEach-Object {
                    $Smi = $_
                    $Devices | Where-Object Type_Vendor_Index -eq $DeviceId | Foreach-Object {
                        $_.Data.Utilization       = if ($smi.utilization_gpu -ne $null) {$smi.utilization_gpu} else {100}
                        $_.Data.UtilizationMem    = $smi.utilization_memory
                        $_.Data.Temperature       = $smi.temperature_gpu
                        $_.Data.PowerDraw         = $smi.power_draw
                        $_.Data.PowerLimit        = $smi.power_limit
                        $_.Data.FanSpeed          = $smi.fan_speed
                        $_.Data.Pstate            = $smi.pstate
                        $_.Data.Clock             = $smi.clocks_current_graphics
                        $_.Data.ClockMem          = $smi.clocks_current_memory
                        $_.Data.PowerMaxLimit     = $smi.power_max_limit
                        $_.Data.PowerDefaultLimit = $smi.power_default_limit
                        $_.Data.Method            = "smi"

                        if ($_.Data.PowerDefaultLimit) {$_.Data.PowerLimitPercent = [math]::Floor(($_.Data.PowerLimit * 100) / $_.Data.PowerDefaultLimit)}
                        if (-not $_.Data.PowerDraw -and $Script:NvidiaCardsTDP."$($_.Model_Name)") {$_.Data.PowerDraw = $Script:NvidiaCardsTDP."$($_.Model_Name)" * ([double]$_.Data.PowerLimitPercent / 100) * ([double]$_.Data.Utilization / 100)}
                    }
                    $DeviceId++
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not read power data from NVIDIA"
        }

        try {
            $Devices | Foreach-Object {
                if ($_.Data.Clock -ne $null)       {$_.DataMax.Clock    = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)}
                if ($_.Data.ClockMem -ne $null)    {$_.DataMax.ClockMem = [Math]::Max([int]$_.DataMax.ClockMem,$_.Data.ClockMem)}
                if ($_.Data.Temperature -ne $null) {$_.DataMax.Temperature = [Math]::Max([decimal]$_.DataMax.Temperature,$_.Data.Temperature)}
                if ($_.Data.FanSpeed -ne $null)    {$_.DataMax.FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$_.Data.FanSpeed)}
                if ($_.Data.PowerDraw -ne $null)   {
                    $_.Data.PowerDraw    *= ($PowerAdjust[$_.Model] / 100)
                    $_.DataMax.PowerDraw  = [Math]::Max([decimal]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not calculate GPU maxium values"
        }
    }

    try { #CPU
        if (-not $DeviceName -or $DeviceName -like "CPU*") {
            if (-not $Session.SysInfo.Cpus) {$Session.SysInfo = Get-SysInfo}
            if ($IsWindows) {
                $CPU_count = ($Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Measure-Object).Count
                $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                    $Device = $_

                    $Session.SysInfo.Cpus | Select-Object -Index $Device.Type_Index | Foreach-Object {
                        $Device.Data.Clock       = [int]$_.Clock
                        $Device.Data.Utilization = [int]$_.Utilization
                        $Device.Data.PowerDraw   = [int]$_.PowerDraw
                        $Device.Data.Temperature = [int]$_.Temperature
                        $Device.Data.Method      = $_.Method
                    }
                }
            }
            elseif ($IsLinux) {
                if ($Script:CpuTDP -eq $null) {$Script:CpuTDP = Get-ContentByStreamReader ".\Data\cpu-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}

                $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                    [int]$Utilization = [math]::min((((Invoke-Exe "ps" -ArgumentList "-A -o pcpu" -ExpandLines) -match "\d" | Measure-Object -Sum).Sum / $Global:GlobalCPUInfo.Threads), 100)

                    $CpuName = $Global:GlobalCPUInfo.Name.Trim()
                    if (-not ($CPU_tdp = $Script:CpuTDP.PSObject.Properties | Where-Object {$CpuName -match $_.Name} | Select-Object -First 1 -ExpandProperty Value)) {$CPU_tdp = ($Script:CpuTDP.PSObject.Properties.Value | Measure-Object -Average).Average}

                    $_.Data.Clock       = [int]$(if ($Session.SysInfo.Cpus -and $Session.SysInfo.Cpus[0].Clock) {$Session.SysInfo.Cpus[0].Clock} else {$Global:GlobalCPUInfo.MaxClockSpeed})
                    $_.Data.Utilization = [int]$Utilization
                    $_.Data.PowerDraw   = [int]($CPU_tdp * $Utilization / 100)
                    $_.Data.Temperature = [int]$(if ($Session.SysInfo.Cpus -and $Session.SysInfo.Cpus[0].Temperature) {$Session.SysInfo.Cpus[0].Temperature} else {0})
                    $_.Data.Method      = "tdp"
                }
            }
            $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                $_.DataMax.Clock       = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)
                $_.DataMax.Utilization = [Math]::Max([int]$_.DataMax.Utilization,$_.Data.Utilization)
                $_.DataMax.PowerDraw   = [Math]::Max([int]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                $_.DataMax.Temperature = [Math]::Max([int]$_.DataMax.Temperature,$_.Data.Temperature)
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
        if (-not (Test-Path Variable:Global:GlobalAlgorithms)) {Get-Algorithms -Silent}
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
        [String]$CoinSymbol = "",
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = ""
    )
    if ($CoinSymbol -eq '*') {$CoinSymbol}
    elseif ($CoinSymbol -match "[,;]") {@($CoinSymbol -split "\s*[,;]+\s*") | Foreach-Object {Get-Coin $_}}
    else {
        if (-not (Test-Path Variable:Global:GlobalCoinsDB)) {Get-CoinsDB -Silent}
        $CoinSymbol = ($CoinSymbol -replace "[^A-Z0-9`$-]+").ToUpper()
        if ($Global:GlobalCoinsDB.ContainsKey($CoinSymbol)) {$Global:GlobalCoinsDB[$CoinSymbol]}
        elseif ($Algorithm -ne "" -and $Global:GlobalCoinsDB.ContainsKey("$CoinSymbol-$Algorithm")) {$Global:GlobalCoinsDB["$CoinSymbol-$Algorithm"]}
    }
}

function Get-HttpStatusCode {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$Code = ""
    )
    if (-not (Test-Path Variable:Global:GlobalHttpStatusCodes)) {Get-HttpStatusCodes -Silent}
    $Global:GlobalHttpStatusCodes | Where StatusCode -eq $Code
}

function Get-MappedAlgorithm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Algorithm
    )
    if (-not $Session.Config.EnableAlgorithmMapping) {return $Algorithm}
    if (-not (Test-Path Variable:Global:GlobalAlgorithmMap)) {Get-AlgorithmMap -Silent}
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
        (Get-ContentByStreamReader "Data\algorithmmap.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalAlgorithmMap[$_.Name]=$_.Value}
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

function Get-EthDAGSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$CoinSymbol = "",
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = "",
        [Parameter(Mandatory = $false)]
        [Double]$Minimum = 3
    )
    if (-not (Test-Path Variable:Global:GlobalEthDAGSizes)) {Get-EthDAGSizes -Silent}
    if     ($CoinSymbol -and $Global:GlobalEthDAGSizes.$CoinSymbol -ne $null)          {$Global:GlobalEthDAGSizes.$CoinSymbol} 
    elseif ($Algorithm -and $Global:GlobalAlgorithms2EthDagSizes.$Algorithm -ne $null) {$Global:GlobalAlgorithms2EthDagSizes.$Algorithm}
    else   {$Minimum}
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
        [Switch]$Force = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Values = $false
    )
    if ($Force -or -not (Test-Path Variable:Global:GlobalAlgorithms) -or (Get-ChildItem "Data\algorithms.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalAlgorithmsTimeStamp) {
        [hashtable]$Global:GlobalAlgorithms = @{}
        (Get-ContentByStreamReader "Data\algorithms.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalAlgorithms[$_.Name]=$_.Value}
        $Global:GlobalAlgorithmsTimeStamp = (Get-ChildItem "Data\algorithms.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {
        if ($Values) {$Global:GlobalAlgorithms.Values | Sort-Object -Unique}
        else {$Global:GlobalAlgorithms.Keys | Sort-Object}
    }
}

function Get-CoinsDB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Values = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false
    )
    if ($Force -or -not (Test-Path Variable:Global:GlobalCoinsDB) -or (Get-ChildItem "Data\coinsdb.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalCoinsDBTimeStamp) {
        [hashtable]$Global:GlobalCoinsDB = @{}
        (Get-ContentByStreamReader "Data\coinsdb.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalCoinsDB[$_.Name]=$_.Value}
        $Global:GlobalCoinsDBTimeStamp = (Get-ChildItem "Data\coinsdb.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {
        if ($Values) {$Global:GlobalCoinsDB.Values | Sort-Object -Unique}
        else {$Global:GlobalCoinsDB.Keys | Sort-Object}
    }
}

function Get-EquihashCoins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalEquihashCoins) -or (Get-ChildItem "Data\equihashcoins.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalEquihashCoinsTimeStamp) {
        [hashtable]$Global:GlobalEquihashCoins = @{}
        (Get-ContentByStreamReader "Data\equihashcoins.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalEquihashCoins[$_.Name]=$_.Value}
        $Global:GlobalEquihashCoinsTimeStamp = (Get-ChildItem "Data\equihashcoins.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {$Global:GlobalEquihashCoins.Keys}
}

function Get-EthDAGSizes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableRemoteUpdate = $false
    )

    if (-not (Test-Path Variable:Global:GlobalCoinsDB)) {Get-CoinsDB -Silent}

    if ($EnableRemoteUpdate) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-GetUrlAsync "https://rbminer.net/api/data/ethdagsizes.json" -cycletime 3600 -Jobkey "ethdagsizes"
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "EthDAGsize API failed. "
        }
    }

    if ($Request -and ($Request.PSObject.Properties | Measure-Object).Count -gt 10) {
        Set-ContentJson -PathToFile ".\Data\ethdagsizes.json" -Data $Request -MD5hash (Get-ContentDataMD5hash $Global:GlobalEthDAGSizes) > $null
    } else {
        $Request = Get-ContentByStreamReader ".\Data\ethdagsizes.json" | ConvertFrom-Json -ErrorAction Ignore
    }
    $Global:GlobalEthDAGSizes = [PSCustomObject]@{}
    $Request.PSObject.Properties | Foreach-Object {$Global:GlobalEthDAGSizes | Add-Member $_.Name ($_.Value/1Gb)}

    $Global:GlobalAlgorithms2EthDagSizes = [PSCustomObject]@{}
    $Global:GlobalCoinsDB.GetEnumerator() | Where-Object {$Coin = $_.Name -replace "-.+$";$Global:GlobalEthDAGSizes.$Coin} | Where-Object {$Algo = Get-Algorithm $_.Value.Algo;$Algo -match $Global:RegexAlgoHasDAGSize -and $_.Value.Name -notmatch "Testnet"} | Foreach-Object {
        if ($Global:GlobalAlgorithms2EthDagSizes.$Algo -eq $null) {
            $Global:GlobalAlgorithms2EthDagSizes | Add-Member $Algo $Global:GlobalEthDAGSizes.$Coin -Force
        } elseif ($Global:GlobalAlgorithms2EthDagSizes.$Algo -lt $Global:GlobalEthDAGSizes.$Coin) {
            $Global:GlobalAlgorithms2EthDagSizes.$Algo = $Global:GlobalEthDAGSizes.$Coin
        }
    }

    if (-not $Silent) {$Global:GlobalEthDAGSizes}
}

function Get-HttpStatusCodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalHttpStatusCodes)) {
        $Global:GlobalHttpStatusCodes = Get-ContentByStreamReader "Data\httpstatuscodes.json" | ConvertFrom-Json -ErrorAction Ignore
    }
    if (-not $Silent) {
        $Global:GlobalHttpStatusCodes
    }
}

function Get-NimqHashrates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalNimqHashrates) -or (Get-ChildItem "Data\nimqhashrates.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalNimqHashratesTimeStamp) {
        [hashtable]$Global:GlobalNimqHashrates = @{}
        (Get-ContentByStreamReader "Data\nimqhashrates.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalNimqHashrates[$_.Name]=$_.Value}
        $Global:GlobalNimqHashratesTimeStamp = (Get-ChildItem "Data\nimqhashrates.json").LastWriteTime.ToUniversalTime()

    }
    if (-not $Silent) {$Global:GlobalNimqHashrates.Keys}
}

function Test-VRAM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Device,
        [Parameter(Mandatory = $false)]
        $MinMemGB = 0.0
    )
    if ($IsWindows -and $Session.IsWin10) {
        $Device.OpenCL.GlobalMemsize*0.865 -ge ($MinMemGB * 1Gb)
    } else {
        $Device.OpenCL.GlobalMemsize -ge ($MinMemGB * 1Gb)
    }
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
    
    if (-not (Test-Path Variable:Global:GlobalPoolsInfo) -or $Global:GlobalPoolsInfo -eq $null) {
        $Global:GlobalPoolsInfo = Get-ContentByStreamReader "Data\poolsinfo.json" | ConvertFrom-Json -ErrorAction Ignore
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
    if ($Clear) {$Global:GlobalPoolsInfo = $null}
}

function Get-Regions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Switch]$AsHash = $false
    )
    if (-not (Test-Path Variable:Global:GlobalRegions) -or (Get-ChildItem "Data\regions.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalRegionsTimeStamp) {
        [hashtable]$Global:GlobalRegions = @{}
        (Get-ContentByStreamReader "Data\regions.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalRegions[$_.Name]=$_.Value}
        $Global:GlobalRegionsTimeStamp = (Get-ChildItem "Data\regions.json").LastWriteTime.ToUniversalTime()
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
    if (-not (Test-Path Variable:Global:GlobalRegions2) -or (Get-ChildItem "Data\regions2.json").LastWriteTime.ToUniversalTime() -gt $Global:GlobalRegions2TimeStamp) {
        [hashtable]$Global:GlobalRegions2 = @{}
        (Get-ContentByStreamReader "Data\regions2.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Global:GlobalRegions2[$_.Name]=$_.Value}
        $Global:GlobalRegions2TimeStamp = (Get-ChildItem "Data\regions2.json").LastWriteTime.ToUniversalTime()
    }
    if (-not $Silent) {$Global:GlobalRegions2.Keys}
}

function Get-WorldCurrencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableRemoteUpdate = $false
    )

    if (-not (Test-Path Variable:Global:GlobalWorldCurrencies)) {
        $Global:GlobalWorldCurrencies = if (Test-Path ".\Data\worldcurrencies.json") {Get-ContentByStreamReader ".\Data\worldcurrencies.json" | ConvertFrom-Json -ErrorAction Ignore} else {@("USD","INR","RUB","EUR","GBP")}
    }

    if ($EnableRemoteUpdate) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-GetUrlAsync "https://api.coinbase.com/v2/currencies" -cycletime 86400 -Jobkey "worldcurrencies"
            if ($Request.data -and ($Request.data | Measure-Object).Count -gt 100) {
                Set-ContentJson -PathToFile ".\Data\worldcurrencies.json" -Data $Request.data.id -MD5hash (Get-ContentDataMD5hash $Global:GlobalWorldCurrencies) > $null
                $Global:GlobalWorldCurrencies = if (Test-Path ".\Data\worldcurrencies.json") {Get-ContentByStreamReader ".\Data\worldcurrencies.json" | ConvertFrom-Json -ErrorAction Ignore} else {@("USD","INR","RUB","EUR","GBP")}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Worldcurrencies API failed. "
        }
    }

    if (-not $Silent) {$Global:GlobalWorldCurrencies}
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
        $Cmd = "$($NvCmd -join ' ')"
        if ($SetPowerMizer) {
            Get-Device "nvidia" | Select-Object -ExpandProperty Type_Vendor_index | Foreach-Object {$Cmd = "$Cmd -a '[gpu:$($_)]/GPUPowerMizerMode=1'"}
        }
        $Cmd = $Cmd.Trim()
        if ($Cmd) {
            Set-OCDaemon "nvidia-settings $Cmd" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
        }
    } elseif ($IsWindows -and $NvCmd) {
        & ".\Includes\NvidiaInspector\nvidiaInspector.exe" $NvCmd
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
        [Array]$Type = @() #AMD/INTEL/NVIDIA
    )
    if (-not $Type.Count) {$Type = "AMD","INTEL","NVIDIA"}
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
        $Device,
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
        [Switch]$AllowWildcards = $False,
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
            if ($AllowWildcards -and $Valid.Count) {
                [Array]$Result = @($Result -replace "[^$($Characters)\*\?,;]+","" -split "\s*[,;]+\s*" | Where-Object {$_ -ne ""} | Foreach-Object {
                    $m = $_
                    if ($found = $Valid | Where-Object {$_ -like $m} | Select-Object) {$found} else {$m}
                } | Select-Object)
            } else {
                [Array]$Result = @($Result -replace "[^$($Characters),;]+","" -split "\s*[,;]+\s*" | Where-Object {$_ -ne ""} | Select-Object)
            }
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
    Get-MD5Hash ($Data | ConvertTo-Json -Depth 10 -Compress)
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
                    if ((Get-ChildItem $PathToFile -File).IsReadOnly) {
                        Write-Log -Level Warn "Unable to write to read-only file $PathToFile"
                        return $false
                    }
                    $FileStream = [System.IO.File]::Open($PathToFile,'Open','Write')
                    $FileStream.Close()
                    $FileStream.Dispose()
                    $Exists = $true
            }
            if (-not $Exists -or $MD5hash -eq '' -or ($MD5hash -ne (Get-ContentDataMD5hash($Data)))) {
                if ($Session.IsCore -or ($PSVersionTable.PSVersion -ge (Get-Version "6.1"))) {
                    if ($Data -is [array]) {
                        ConvertTo-Json -InputObject @($Data | Select-Object) -Compress:$Compress -Depth 10 | Set-Content $PathToFile -Encoding utf8 -Force
                    } else {
                        ConvertTo-Json -InputObject $Data -Compress:$Compress -Depth 10 | Set-Content $PathToFile -Encoding utf8 -Force
                    }
                } else {
                    $JsonOut = if ($Data -is [array]) {
                        ConvertTo-Json -InputObject @($Data | Select-Object) -Compress:$Compress -Depth 10
                    } else {
                        ConvertTo-Json -InputObject $Data -Compress:$Compress -Depth 10
                    }
                    $utf8 = New-Object System.Text.UTF8Encoding $false
                    Set-Content -Value $utf8.GetBytes($JsonOut) -Encoding Byte -Path $PathToFile
                }
            } elseif ($Exists) {
                (Get-ChildItem $PathToFile -File).LastWriteTime = Get-Date
            }
            return $true
        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        $retry--
        Start-Sleep -Seconds 1
    } until ($retry -le 0)
    Write-Log -Level Warn "Unable to write to file $PathToFile"
    return $false
}

function Set-PresetDefault {
    if (Test-Path ".\Data\PresetDefault.ps1") {
        $Setup = Get-ChildItemContent ".\Data\PresetDefault.ps1"
        $Setup.PSObject.Properties.Name | Foreach-Object {
            $Session.DefaultValues[$_] = $Setup.$_
        }
    }
}

function Set-AlgorithmsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Algorithms"
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
            $Default = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinWorkers = "0";MaxTimeToFind = "0";MSIAprofile = 0;OCprofile="";MRRPriceModifierPercent="";MRREnable="1";MRRAllowExtensions="";MinerName="";ExcludeMinerName=""}
            $Setup = Get-ChildItemContent ".\Data\AlgorithmsConfigDefault.ps1"
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

function Set-CoinsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Coins"
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
            $Setup = Get-ChildItemContent ".\Data\CoinsConfigDefault.ps1"
            
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
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})GpuGroups"
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
            $GpuNames = Get-Device "amd","intel","nvidia" -IgnoreOpenCL | Select-Object -ExpandProperty Name -Unique
            foreach ($GpuName in $GpuNames) {
                if ($Preset.$GpuName -eq $null) {$Preset | Add-Member $GpuName "" -Force}
                elseif ($Preset.$GpuName -ne "") {$Global:GlobalCachedDevices | Where-Object Name -eq $GpuName | Foreach-Object {$_.Model += $Preset.$GpuName.ToUpper();$_.GpuGroup = $Preset.$GpuName.ToUpper()}}
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
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Combos"
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
            Foreach($SubsetType in @("AMD","INTEL","NVIDIA")) {
                if ($Preset.$SubsetType -eq $null) {$Preset | Add-Member $SubsetType ([PSCustomObject]@{}) -Force}
                if ($Sorted.$SubsetType -eq $null) {$Sorted | Add-Member $SubsetType ([PSCustomObject]@{}) -Force}

                $NewSubsetModels = @()

                $SubsetDevices = @($Global:GlobalCachedDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq $SubsetType})

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
                            $Mem = $_.OpenCL.GlobalMemSizeGB
                            Switch ($SubsetType) {
                                "AMD"    {"$($Model.SubString(0,2))$($Mem)GB";Break}
                                "INTEL"  {"$($Model.SubString(0,2))$($Mem)GB";Break}
                                "NVIDIA" {"$(
                                    Switch ($_.OpenCL.Architecture) {
                                        "Pascal" {Switch -Regex ($Model) {"105" {"GTX5";Break};"106" {"GTX6";Break};"(104|107|108)" {"GTX7";Break};default {$Model}};Break}
                                        "Turing" {"RTX";Break}
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
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Devices"
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
            $Setup = Get-ChildItemContent ".\Data\DevicesConfigDefault.ps1"
            $Devices = Get-Device "amd","intel","nvidia","cpu" -IgnoreOpenCL
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

function Set-MinersConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $False)]
        [Switch]$UseDefaultParams = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Miners"
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

            #autofix json array in array for count one
            $PresetTmp.PSObject.Properties.Name | Where-Object {$PresetTmp.$_ -is [array] -and $PresetTmp.$_.Count -eq 1 -and $PresetTmp.$_[0].value -is [array]} | Foreach-Object {$PresetTmp.$_ = $PresetTmp.$_[0].value}

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
            if (-not (Test-Path ".\nopresets.txt")) {$Setup = Get-ChildItemContent ".\Data\MinersConfigDefault.ps1"}
            $AllDevices = Get-Device "cpu","gpu" -IgnoreOpenCL
            $AllMiners = if (Test-Path "Miners") {@(Get-MinersContent -Parameters @{InfoOnly = $true})}

            $MiningMode = $Session.Config.MiningMode
            if ($MiningMode -eq $null) {
                try {
                    $MiningMode = (Get-Content $Session.ConfigFiles["Config"].Path -Raw | ConvertFrom-Json -ErrorAction Stop).MiningMode
                    if ($MiningMode -eq "`$MiningMode") {
                        $MiningMode = $Session.DefaultValues["MiningMode"]
                    }
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "Set-MinersConfigDefault: Problem reading MiningMode from config (assuming combo)"
                    $MiningMode = $null
                }
            }
            if (-not $MiningMode) {
                $MiningMode = "combo"
            }

            foreach ($a in @("CPU","AMD","INTEL","NVIDIA")) {
                if ($a -eq "CPU") {[System.Collections.ArrayList]$SetupDevices = @("CPU")}
                else {
                    $Devices = @($AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq $a} | Select-Object Model,Model_Name,Name)
                    [System.Collections.ArrayList]$SetupDevices = @($Devices | Select-Object -ExpandProperty Model -Unique)
                    if ($SetupDevices.Count -gt 1 -and $MiningMode -eq "combo") {
                        Get-DeviceSubsets $Devices | Foreach-Object {$SetupDevices.Add($_.Model -join '-') > $null}
                    }
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
                                if (-not $MinerCheck.Contains($k)) {
                                    if ($SetupDevice -eq "CPU") {
                                        [PSCustomObject]@{MainAlgorithm=$m;SecondaryAlgorithm=$s;Params = "";MSIAprofile = "";OCprofile = "";Difficulty = "";Penalty = "";Disable = "0";ShareCheck = "";Affinity = "";Threads = ""}
                                    } else {
                                        [PSCustomObject]@{MainAlgorithm=$m;SecondaryAlgorithm=$s;Params = "";MSIAprofile = "";OCprofile = "";Difficulty = "";Penalty = "";Disable = "0";ShareCheck = ""}
                                    }
                                    $MinerCheck.Add($k)>$null
                                }
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

            $Default     = [PSCustomObject]@{Params = "";MSIAprofile = "";OCprofile = "";Difficulty="";Penalty="";Disable="0";ShareCheck=""}
            $DefaultCPU  = [PSCustomObject]@{Params = "";MSIAprofile = "";OCprofile = "";Difficulty="";Penalty="";Disable="0";ShareCheck="";Affinity="";Threads=""}
            $DefaultDual = [PSCustomObject]@{Params = "";MSIAprofile = "";OCprofile = "";Difficulty="";Penalty="";Disable="0";ShareCheck="";Intensity=""}
            $DoneSave = [PSCustomObject]@{}
            $Done.PSObject.Properties.Name | Sort-Object | Foreach-Object {
                $Name = $_
                if ($Done.$Name.Count) {
                    $Done.$Name | Foreach-Object {
                        $Done1 = $_
                        $DefaultHandler = if ($_.SecondaryAlgorithm) {$DefaultDual} elseif ($Name -match "-CPU$") {$DefaultCPU} else {$Default}
                        $DefaultHandler.PSObject.Properties.Name | Where-Object {$Done1.$_ -eq $null} | Foreach-Object {$Done1 | Add-Member $_ $DefaultHandler.$_ -Force}
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

function Set-PoolsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Pools"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $UserpoolsUpdated = $false
    $UserpoolsPathToFile = ""

    $UserpoolsConfigName = "$(if ($Folder -and $Session.ConfigFiles.ContainsKey("$Folder/Userpools")) {"$Folder/"})Userpools"
    if ($UserpoolsConfigName -and $Session.ConfigFiles.ContainsKey($UserpoolsConfigName)) {
        $UserpoolsPathToFile = $Session.ConfigFiles[$UserpoolsConfigName].Path
        if (Test-Path $UserpoolsPathToFile) {
            $UserpoolsUpdated = ((Test-Path $PathToFile) -and (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem $UserpoolsPathToFile).LastWriteTime.ToUniversalTime())
        } else {
            $UserpoolsPathToFile = ""
        }
    }

    if ($Force -or -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\PoolsConfigDefault.ps1").LastWriteTime.ToUniversalTime() -or $UserpoolsUpdated) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = $null}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Done = [PSCustomObject]@{}
            $Default = [PSCustomObject]@{Worker = "`$WorkerName";Penalty = "0";Algorithm = "";ExcludeAlgorithm = "";CoinName = "";ExcludeCoin = "";CoinSymbol = "";ExcludeCoinSymbol = "";MinerName = "";ExcludeMinerName = "";FocusWallet = "";AllowZero = "0";EnableAutoCoin = "0";EnablePostBlockMining = "0";CoinSymbolPBM = "";DataWindow = "";StatAverage = "";StatAverageStable = "";MaxMarginOfError = "100";SwitchingHysteresis="";MaxAllowedLuck="";MaxTimeSinceLastBlock="";Region="";SSL="";BalancesKeepAlive=""}
            $Setup = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1"
            $Pools = @(Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Where-Object {$_ -notin @("Userpools")})
            $Userpools = @()
            if ($UserpoolsPathToFile) {
                $UserpoolsConfig = Get-ConfigContent $UserpoolsConfigName
                if ($UserpoolsConfig -isnot [array] -and $UserpoolsConfig.value -ne $null) {
                    $UserpoolsConfig = $UserpoolsConfig.value
                }
                if ($Session.ConfigFiles[$UserpoolsConfigName].Healthy) {
                    $Userpools = @($UserpoolsConfig | Where-Object {$_.Name} | Foreach-Object {$_.Name} | Select-Object -Unique)
                }
            }
            $Global:GlobalPoolFields = @("Wallets") + $Default.PSObject.Properties.Name + @($Setup.PSObject.Properties.Value | Where-Object Fields | Foreach-Object {$_.Fields.PSObject.Properties.Name} | Select-Object -Unique) | Select-Object -Unique
            if ($Pools.Count -gt 0 -or $Userpools.Count -gt 0) {
                $Pools + $Userpools | Sort-Object -Unique | Foreach-Object {
                    $Pool_Name = $_
                    if ($Preset -and $Preset.PSObject.Properties.Name -icontains $Pool_Name) {
                        $Setup_Content = $Preset.$Pool_Name
                    } else {
                        $Setup_Content = [PSCustomObject]@{}
                        if ($Pool_Name -ne "WhatToMine") {
                            if ($Pool_Name -in $Userpools) {
                                $Setup_Currencies = @($UserpoolsConfig | Where-Object {$_.Name -eq $Pool_Name} | Select-Object -ExpandProperty Currency -Unique)
                                if (-not $Setup_Currencies) {$Setup_Currencies = @("BTC")}
                            } else {
                                $Setup_Currencies = @("BTC")
                                if ($Setup.$Pool_Name) {
                                    if ($Setup.$Pool_Name.Fields) {$Setup_Content = $Setup.$Pool_Name.Fields}
                                    $Setup_Currencies = @($Setup.$Pool_Name.Currencies)            
                                }
                            }
                            $Setup_Currencies | Foreach-Object {
                                $Setup_Content | Add-Member $_ "$(if ($_ -eq "BTC"){"`$Wallet"})" -Force
                                $Setup_Content | Add-Member "$($_)-Params" "" -Force
                            }
                        }
                    }
                    if ($Setup.$Pool_Name.Fields -ne $null) {
                        foreach($SetupName in $Setup.$Pool_Name.Fields.PSObject.Properties.Name) {if ($Setup_Content.$SetupName -eq $null){$Setup_Content | Add-Member $SetupName $Setup.$Pool_Name.Fields.$SetupName -Force}}
                    }
                    foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Setup_Content.$SetupName -eq $null){$Setup_Content | Add-Member $SetupName $Default.$SetupName -Force}}
                    if ($Setup.$Pool_Name.Autoexchange -and (Get-Yes $Setup_Content.EnableAutoCoin)) {
                        $Setup_Content.EnableAutoCoin = "0" # do not allow EnableAutoCoin for pools with autoexchange feature
                    }
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
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})OCProfiles"
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
            $Default = [PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;PriorizeThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*";LockVoltagePoint = "*";PreCmd="";PreCmdArguments="";PostCmd="";PostCmdArguments=""}
            if ($true -or -not $Preset.PSObject.Properties.Name) {
                $Setup = Get-ChildItemContent ".\Data\OCProfilesConfigDefault.ps1"
                $Devices = Get-Device "amd","intel","nvidia" -IgnoreOpenCL
                $Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object | Foreach-Object {
                    $Model = $_
                    For($i=1;$i -le 7;$i++) {
                        $Profile = "Profile$($i)-$($Model)"
                        if (-not $Preset.$Profile) {$Preset | Add-Member $Profile $(if ($Setup.$Profile -ne $null) {$Setup.$Profile} else {$Default}) -Force}
                    }
                }
                if (-not $Devices) {
                    For($i=1;$i -le 7;$i++) {
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
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Scheduler"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            $Default = Get-ChildItemContent ".\Data\SchedulerConfigDefault.ps1"
            if ($Preset -is [string] -or $Preset -eq $null) {
                $Preset = @($Default) + @((0..6) | Foreach-Object {$a=$Default | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore;$a.DayOfWeek = "$_";$a})
            }
            $ChangeTag = Get-ContentDataMD5hash($Preset)

            if ($Preset -isnot [array] -and $Preset.value -ne $null) {
                $Preset = $Preset.value
            }
            
            $Preset | Foreach-Object {
                foreach($SetupName in @($Default.PSObject.Properties.Name | Select-Object)) {
                    if ($_.$SetupName -eq $null) {$_ | Add-Member $SetupName $Default.$SetupName -Force}
                }
                if (-not $_.Name) {
                    if ($_.DayOfWeek -eq "*") {$_.Name = "All"}
                    elseif ($_.DayOfWeek -match "^[0-6]$") {$_.Name = "$([DayOfWeek]$_.DayOfWeek)"}
                }
            }

            Set-ContentJson -PathToFile $PathToFile -Data @($Preset | Select-Object) -MD5hash $ChangeTag > $null
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). Is the file openend by an editor?"
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-UserpoolsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Userpools"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile)) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            $Default = Get-ChildItemContent ".\Data\UserpoolsConfigDefault.ps1"
            if ($Preset -is [string] -or $Preset -eq $null) {
                $Preset = 1..5 | Foreach-Object {$Default | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}
            }
            $ChangeTag = Get-ContentDataMD5hash($Preset)

            if ($Preset -isnot [array] -and $Preset.value -ne $null) {
                $Preset = $Preset.value
            }
            
            $Preset | Foreach-Object {
                foreach($SetupName in @($Default.PSObject.Properties.Name | Select-Object)) {
                    if ($_.$SetupName -eq $null) {$_ | Add-Member $SetupName $Default.$SetupName -Force}
                }
            }

            Set-ContentJson -PathToFile $PathToFile -Data @($Preset | Select-Object) -MD5hash $ChangeTag > $null
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
        [string]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )

    Switch ($ConfigName) {
        "Algorithms"  {Set-AlgorithmsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Coins"       {Set-CoinsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Combos"      {Set-CombosConfigDefault -Folder $Folder -Force:$Force;Break}
        "Devices"     {Set-DevicesConfigDefault -Folder $Folder -Force:$Force;Break}
        "GpuGroups"   {Set-GpuGroupsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Miners"      {Set-MinersConfigDefault -Folder $Folder -Force:$Force;Break}
        "OCProfiles"  {Set-OCProfilesConfigDefault -Folder $Folder -Force:$Force;Break}
        "Pools"       {Set-PoolsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Scheduler"   {Set-SchedulerConfigDefault -Folder $Folder -Force:$Force;Break}
        "Userpools"   {Set-UserpoolsConfigDefault -Folder $Folder -Force:$Force;Break}
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
            $Result = Get-ContentByStreamReader $PathToFile
            if ($Parameters.Count) {
                $Parameters.Keys | Foreach-Object {$Result = $Result -replace "\`$$($_)","$($Parameters.$_)"}
                if (-not $ConserveUnkownParameters) {
                    $Result = $Result -replace "\`$[A-Z0-9_]+"
                }
            }
            if (Test-IsCore) {
                $Result | ConvertFrom-Json -ErrorAction Stop
            } else {
                $Data = $Result | ConvertFrom-Json -ErrorAction Stop
                $Data
            }
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
        $ErrorMessage = ""
        if (-not (Test-Path ".\Data\serverlwt")) {New-Item ".\Data\serverlwt" -ItemType "directory" -ErrorAction Ignore > $null}
        $ServerLWTFile = Join-Path ".\Data\serverlwt" "$(if ($GroupName) {$GroupName} elseif ($WorkerName) {$WorkerName} else {"this"})_$($Server.ToLower() -replace '\.','-')_$($Port).json"
        $ServerLWT = if (Test-Path $ServerLWTFile) {try {Get-ContentByStreamReader $ServerLWTFile | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
        if (-not $ServerLWT) {$ServerLWT = [PSCustomObject]@{}}
        $Params = ($ConfigName | Foreach-Object {$PathToFile = $ConfigFiles[$_].Path;"$($_)ZZZ$(if ($Force -or -not (Test-Path $PathToFile) -or -not $ServerLWT.$_) {"0"} else {$ServerLWT.$_})"}) -join ','
        $Uri = "http://$($Server):$($Port)/getconfig?config=$($Params)&workername=$($WorkerName)&groupname=$($GroupName)&machinename=$($Session.MachineName)&myip=$($Session.MyIP)&version=$($Session.Version)"
        try {
            $Result = Invoke-GetUrl $Uri -user $Username -password $Password -ForceLocal -Timeout 30
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ErrorMessage = "$($_.Exception.Message)"
        }
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
            Write-Log -Level Warn "Get-ServerConfig failed $(if ($Result.Content) {$Result.Content} else {$ErrorMessage})"
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
    try {$AffinityInt = [System.Numerics.BigInteger]::Parse("0$($Affinity -replace "[^0-9A-Fx]" -replace "^[0x]+")", 'AllowHexSpecifier')}catch{if ($Error.Count){$Error.RemoveAt(0)};$AffinityInt=[bigint]0}
    if ($ToInt) {$AffinityInt}
    else {@(for($a=0;$AffinityInt -gt 0;$a++) {if (($AffinityInt -band 1) -eq 1){$a};$AffinityInt=$AffinityInt -shr 1})}
}

function ConvertTo-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [int[]]$Threads = @(),
        [Parameter(Mandatory = $False)]
        [switch]$ToHex
    )
    [bigint]$a=0;foreach($b in $Threads){$a+=[bigint]1 -shl $b};
    if ($ToHex) {
        if ($a -gt 0) {"0x$($a.ToString("x") -replace "^0")"}
        else {"0x00"}
    }else{$a}
}

function Get-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [int]$Threads = 0,
        [Parameter(Mandatory = $False)]
        [switch]$ToHex,
        [Parameter(Mandatory = $False)]
        [switch]$ToInt
    )
    if ($ToHex) {ConvertTo-CPUAffinity @(Get-CPUAffinity $Threads) -ToHex}
    elseif ($ToInt) {ConvertTo-CPUAffinity @(Get-CPUAffinity $Threads)}
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
        {"Live","Minute_5","Minute_10","Hour","Day","ThreeDay","Week" -icontains $_} {$_;Break}
        {"Minute5","Min5","Min_5","5Minute","5_Minute","5" -icontains $_} {"Minute_5";Break}
        {"Minute10","Min10","Min_10","10Minute","10_Minute","10" -icontains $_} {"Minute_10";Break}
        {"3Day","3_Day","Three_Day" -icontains $_} {"ThreeDay";Break}
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
        [Switch]$CheckDataWindow = $false,
        [Parameter(Mandatory = $False)]
        [Double]$ActualDivisor = 1000
    )    
    [Double]$Value = 0
    [System.Collections.Generic.List[string]]$allfields = @("estimate_current","estimate_last24h","actual_last24h")
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
                "2"  {[System.Collections.Generic.List[string]]$fields = @("actual_last24h","estimate_current");Break}
                "2e" {[System.Collections.Generic.List[string]]$fields = @("estimate_last24h","estimate_current");Break}
                "2h" {[System.Collections.Generic.List[string]]$fields = @("actual_last24h","estimate_last24h");Break}
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

function Get-DeviceSubsets($Device) {
    $Models = @($Device | Select-Object Model,Model_Name -Unique)
    if ($Models.Count) {
        [System.Collections.Generic.List[string]]$a = @();0..$($Models.Count-1) | Foreach-Object {$a.Add('{0:x}' -f $_) > $null}
        @(Get-Subsets $a | Where-Object {$_.Length -gt 1} | Foreach-Object{
            [PSCustomObject[]]$x = @($_.ToCharArray() | Foreach-Object {$Models[[int]"0x$_"]}) | Sort-Object -Property Model
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
    [System.Collections.ArrayList]$l = @()
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
        $l.Add(-join $out) > $null
    }
    #group the subsets by length, iterate through them and sort
    $l | Group-Object -Property Length | %{$_.Group | sort}
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
    $memdiff = $memusagebyte - [int64]$Global:last_memory_usage_byte
    [PSCustomObject]@{
        MemUsage   = $memusagebyte
        MemDiff    = $memdiff
        MemText    = "Memory usage: {0:n1} MB ({1:n0} Bytes {2})" -f  ($memusagebyte/1MB), $memusagebyte, "$(if ($memdiff -gt 0){"+"})$($memdiff)"
    }
    if ($Reset) {
        $Global:last_memory_usage_byte = $memusagebyte
    }
}

function Write-MemoryUsageToLog {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    [String]$Message = ""
)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    Get-MemoryUsage -ForceFullCollection >$null
    Write-Log "$($Message) $((Get-MemoryUsage -Reset).MemText)"
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
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        $body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers,
    [Parameter(Mandatory = $False)]
        [string]$user = "",
    [Parameter(Mandatory = $False)]
        [string]$password = "",
    [Parameter(Mandatory = $False)]
        [string]$useragent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36",
    [Parameter(Mandatory = $False)]
        [bool]$fixbigint = $false,
    [Parameter(Mandatory = $False)]
        $JobData,
    [Parameter(Mandatory = $False)]
        [string]$JobKey = "",
    [Parameter(Mandatory = $False)]
        [switch]$ForceLocal,
    [Parameter(Mandatory = $False)]
        [switch]$NoExtraHeaderData
)
    if ($JobKey -and $JobData) {
        if (-not $ForceLocal -and $JobData.url -notmatch "^server://") {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}
            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                $serverbody = @{
                    url       = $JobData.url
                    method    = $JobData.method
                    timeout   = $JobData.timeout
                    body      = $JobData.body | ConvertTo-Json -Depth 10 -Compress
                    headers   = $JobData.headers | ConvertTo-Json -Depth 10 -Compress
                    cycletime = $JobData.cycletime
                    retry     = $JobData.retry
                    retrywait = $JobData.retrywait
                    delay     = $JobData.delay
                    tag       = $JobData.tag
                    user      = $JobData.user
                    password  = $JobData.password
                    fixbigint = [bool]$JobData.fixbigint
                    jobkey    = $JobKey
                    machinename = $Session.MachineName
                    myip      = $Session.MyIP
                }
                #Write-ToFile -FilePath "Logs\geturl_$(Get-Date -Format "yyyy-MM-dd").txt" -Message "http://$($Config.ServerName):$($Config.ServerPort)/getjob $(ConvertTo-Json $serverbody)" -Append -Timestamp
                $Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getjob" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                #Write-ToFile -FilePath "Logs\geturl_$(Get-Date -Format "yyyy-MM-dd").txt" -Message ".. $(if ($Result.Status) {"ok!"} else {"failed"})" -Append -Timestamp
                if ($Result.Status) {return $Result.Content}
            }
        }

        $url      = $JobData.url
        $method   = $JobData.method
        $timeout  = $JobData.timeout
        $body     = $JobData.body
        $headers  = $JobData.headers
        $user     = $JobData.user
        $password = $JobData.password
        $fixbigint= [bool]$JobData.fixbigint
    }

    if ($url -match "^server://(.+)$") {
        $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}
        if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
            $url           = "http://$($Config.ServerName):$($Config.ServerPort)/$($Matches[1])"
            $user          = $Config.ServerUser
            $password      = $Config.ServerPassword
        } else {
            return
        }
    }

    if (-not $requestmethod) {$requestmethod = if ($body) {"POST"} else {"GET"}}
    $RequestUrl = $url -replace "{timestamp}",(Get-Date -Format "yyyy-MM-dd_HH-mm-ss") -replace "{unixtimestamp}",(Get-UnixTimestamp)

    $headers_local = @{}
    if ($headers) {$headers.Keys | Foreach-Object {$headers_local[$_] = $headers[$_]}}
    if (-not $NoExtraHeaderData) {
        if ($method -eq "REST" -and -not $headers_local.ContainsKey("Accept")) {$headers_local["Accept"] = "application/json"}
        if (-not $headers_local.ContainsKey("Cache-Control")) {$headers_local["Cache-Control"] = "no-cache"}
    }
    if ($user) {$headers_local["Authorization"] = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($user):$($password)")))"}

    $ErrorMessage = ''

    if ($Session.EnableCurl) {

        $TmpFile = $null

        try {
            $CurlHeaders = [String]::Join(" ",@($headers_local.GetEnumerator() | Sort-Object Name | Foreach-Object {"-H `"$($_.Name): $($_.Value)`""}))
            $CurlBody    = ""

            if (($pos = $url.IndexOf('?')) -gt 0) {
                $body = $url.Substring($pos+1)
                $url  = $url.Substring(0,$pos)
            }

            if ($body -and ($body -isnot [hashtable] -or $body.Count)) {
                if ($body -is [hashtable]) {
                    $out = [ordered]@{}
                    if (($body.GetEnumerator() | Where-Object {$_.Value -is [object] -and $_.Value.FullName} | Measure-Object).Count) {
                        $body.GetEnumerator() | Sort-Object Name | Foreach-Object {
                            $out[$_.Name] = if ($_.Value -is [object] -and $_.Value.FullName) {"@$($_.Value.FullName)"} else {$_.Value -replace '"','\"'}
                        }
                        $outcmd = if ($requestmethod -eq "GET") {"-d"} else {"-F"}
                        $CurlBody = [String]::Join(" ",@($out.GetEnumerator() | Foreach-Object {"$($outcmd) `"$($_.Name)=$($_.Value)`""}))
                        $CurlBody = "$CurlBody "
                    } else {
                        $body = [String]::Join('&',($body.GetEnumerator() | Sort-Object Name | Foreach-Object {"$($_.Name)=$([System.Web.HttpUtility]::UrlEncode($_.Value))"}))
                    }
                } 
                if ($body -isnot [hashtable]) {
                    if ($body.Length -gt 30000) {
                        $TmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "$([System.Guid]::NewGuid()).txt"
                        Set-Content -Value $body -Path $TmpFile
                        $body = "@$($TmpFile)"
                    }
                    $CurlBody = "-d `"$($body -replace '"','\"')`" "
                }
            }

            if ($useragent -ne "") {$useragent = "-A `"$($useragent)`" "}

            $CurlCommand = "$(if ($requestmethod -ne "GET") {"-X $($requestmethod)"} else {"-G"}) `"$($url)`" $($CurlBody)$($CurlHeaders) $($useragent)-m $($timeout+5) --connect-timeout $($timeout) --ssl-allow-beast --ssl-no-revoke --max-redirs 5 -k -s -L -q -w `"#~#%{response_code}`""

            $Data = (Invoke-Exe $Session.Curl -ArgumentList $CurlCommand -WaitForExit $Timeout) -split "#~#"

            if ($Session.LogLevel -eq "Debug") {
                Write-Log -Level Info "CURL[$($Global:LASTEXEEXITCODE)][$($Data[-1])] $($CurlCommand)"
            }

            if ($Data -and $Data.Count -gt 1 -and $Global:LASTEXEEXITCODE -eq 0 -and $Data[-1] -match "^2\d\d") {
                $Data = if ($Data.Count -eq 2) {$Data[0]} else {$Data[0..($Data.Count-2)] -join '#~#'}
                if ($method -eq "REST") {
                    if ($fixbigint) {
                        try {
                            $Data = ([regex]"(?si):\s*(\d{19,})[`r`n,\s\]\}]").Replace($Data,{param($m) $m.Groups[0].Value -replace $m.Groups[1].Value,"$([double]$m.Groups[1].Value)"})
                        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                    }
                    try {$Data = ConvertFrom-Json $Data -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}; $method = "WEB"}
                }
                if ($Data -and $Data.unlocked -ne $null) {$Data.PSObject.Properties.Remove("unlocked")}
            } else {
                $ErrorMessage = "cURL $($Global:LASTEXEEXITCODE) / $(if ($Data -and $Data.Count -gt 1){"HTTP $($Data[-1])"} else {"Timeout after $($timeout)s"})"
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $ErrorMessage = "$($_.Exception.Message)"
        } finally {
            if ($TmpFile -and (Test-Path $TmpFile)) {
                Remove-Item $TmpFile -Force -ErrorAction Ignore
            }
        }

    } else {

        $IsForm = $false

        try {
            if ($body -and ($body -isnot [hashtable] -or $body.Count)) {
                if ($body -is [hashtable]) {
                    $IsForm = ($body.GetEnumerator() | Where-Object {$_.Value -is [object] -and $_.Value.FullName} | Measure-Object).Count -gt 0
                } elseif ($requestmethod -eq "GET") {
                    $RequestUrl = "$($RequestUrl)$(if ($RequestUrl.IndexOf('?') -gt 0) {'&'} else {'?'})$body"
                    $body = $null
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }

        $StatusCode = $null
        $Data       = $null

        do {
            $CallJobName = "WebRequest-$(Get-UnixTimestamp -Milliseconds)"
        } While (Get-Job -Name $CallJobName -ErrorAction Ignore)

        $CallJob = Start-ThreadJob .\Scripts\WebRequest.ps1 -Name $CallJobName -ArgumentList $RequestUrl, $useragent, $timeout, $requestmethod, $method, $headers_local, $body, $IsForm, (Test-IsPS7), (Test-IsCore), $fixbigint

        if ($CallJob) {
            if (Wait-Job -Job $CallJob -Timeout ([Math]::Min($timeout,30))) {
                $Result = Receive-Job -Job $CallJob
                if ($Result.Status -ne $null) {
                    $StatusCode   = $Result.StatusCode
                    $Data         = $Result.Data
                    $ErrorMessage = $Result.ErrorMessage

                    if (Test-IsCore) {
                        if ($ErrorMessage -eq '' -and $StatusCode -ne 200) {
                            if ($StatusCodeObject = Get-HttpStatusCode $StatusCode) {
                                if ($StatusCodeObject.Type -ne "Success") {
                                    $ErrorMessage = "$StatusCode $($StatusCodeObject.Description) ($($StatusCodeObject.Type))"
                                }
                            } else {
                                $ErrorMessage = "$StatusCode Very bad! Code not found :("
                            }
                        }
                    }
                } else {
                    $ErrorMessage = "Could not receive data from $($RequestUrl)"
                }
                $Result = $null
            } else {
                $ErrorMessage = "Call to $($RequestUrl) timed out"
            }
            Remove-Job -Job $CallJob -Force
            $CallJob = $null
        } else {
            $ErrorMessage = "WebRequest failed for $($RequestUrl)"
        }
    }

    if ($ErrorMessage -eq '') {$Data}
    if ($ErrorMessage -ne '') {throw $ErrorMessage}
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
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        [switch]$fixbigint,
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
    Invoke-GetUrlAsync $url -method "REST" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body -headers $headers -fixbigint $fixbigint
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
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        [switch]$fixbigint,
    [Parameter(Mandatory = $False)]
        [switch]$nocache,
    [Parameter(Mandatory = $False)]
        [switch]$noquickstart,
    [Parameter(Mandatory = $False)]
        [hashtable]$body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    Invoke-GetUrlAsync $url -method "WEB" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body -headers $headers -fixbigint $fixbigint
}

function Get-HashtableAsJson {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    [hashtable]$hashtable = @{}
)
    "{$(@($hashtable.Keys | Sort-Object | Foreach-Object {"$($_):$(if ($hashtable.$_ -is [hashtable]) {Get-HashtableAsJson $hashtable.$_} else {ConvertTo-Json $hashtable.$_ -Depth 10})"}) -join ",")}"
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
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        [bool]$fixbigint = $False,
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

    if (-not $Jobkey) {$Jobkey = Get-MD5Hash "$($url)$(Get-HashtableAsJson $body)$(Get-HashtableAsJson $headers)";$StaticJobKey = $false} else {$StaticJobKey = $true}

    $IsNewJob   = -not $AsyncLoader.Jobs.$Jobkey

    $retry     = [Math]::Min([Math]::Max($retry,0),5)
    $retrywait = [Math]::Min([Math]::Max($retrywait,0),5000)
    $delay     = [Math]::Min([Math]::Max($delay,0),5000)

    if (-not (Test-Path Variable:Global:Asyncloader) -or $IsNewJob) {
        $JobHost = if ($url -notmatch "^server://") {try{([System.Uri]$url).Host}catch{if ($Error.Count){$Error.RemoveAt(0)}}} else {"server"}
        $JobData = [PSCustomObject]@{Url=$url;Host=$JobHost;Error=$null;Running=$true;Paused=$false;Method=$method;Body=$body;Headers=$headers;Success=0;Fail=0;Prefail=0;LastRequest=(Get-Date).ToUniversalTime();LastCacheWrite=$null;LastFailRetry=$null;LastFailCount=0;CycleTime=$cycletime;Retry=$retry;RetryWait=$retrywait;Delay=$delay;Tag=$tag;Timeout=$timeout;FixBigInt=$fixbigint;Index=0}
    }

    if (-not (Test-Path Variable:Global:Asyncloader)) {
        if ($delay) {Start-Sleep -Milliseconds $delay}
        Invoke-GetUrl -JobData $JobData -JobKey $JobKey
        $JobData.LastCacheWrite = (Get-Date).ToUniversalTime()
        return
    }

    if ($StaticJobKey -and $url -and $AsyncLoader.Jobs.$Jobkey -and ($AsyncLoader.Jobs.$Jobkey.Url -ne $url -or (Get-HashtableAsJson $AsyncLoader.Jobs.$Jobkey.Body) -ne (Get-HashtableAsJson $body) -or (Get-HashtableAsJson $AsyncLoader.Jobs.$Jobkey.Headers) -ne (Get-HashtableAsJson $headers))) {$force = $true;$AsyncLoader.Jobs.$Jobkey.Url = $url;$AsyncLoader.Jobs.$Jobkey.Body = $body;$AsyncLoader.Jobs.$Jobkey.Headers = $headers}

    if ($JobHost) {
        if ($JobHost -eq "rbminer.net" -and $AsyncLoader.HostDelays.$JobHost -eq $null) {$AsyncLoader.HostDelays.$JobHost = 200}
        if ($AsyncLoader.HostDelays.$JobHost -eq $null -or $delay -gt $AsyncLoader.HostDelays.$JobHost) {
            $AsyncLoader.HostDelays.$JobHost = $delay
        }

        if ($AsyncLoader.HostTags.$JobHost -eq $null) {
            $AsyncLoader.HostTags.$JobHost = @($tag)
        } elseif ($AsyncLoader.HostTags.$JobHost -notcontains $tag) {
            $AsyncLoader.HostTags.$JobHost += $tag
        }
    }

    if (-not (Test-Path ".\Cache")) {New-Item "Cache" -ItemType "directory" -ErrorAction Ignore > $null}

    if ($force -or $IsNewJob -or $AsyncLoader.Jobs.$Jobkey.Paused -or -not (Test-Path ".\Cache\$($Jobkey).asy")) {
        $Quickstart = $false
        if ($IsNewJob) {
            $Quickstart = -not $nocache -and -not $noquickstart -and $AsyncLoader.Quickstart -and (Test-Path ".\Cache\$($Jobkey).asy")
            $AsyncLoader.Jobs.$Jobkey = $JobData
            $AsyncLoader.Jobs.$Jobkey.Index = $AsyncLoader.Jobs.Count
            #Write-Log -Level Info "New job $($Jobkey): $($JobData.Url)" 
        } else {
            $AsyncLoader.Jobs.$Jobkey.Running=$true
            $AsyncLoader.Jobs.$JobKey.LastRequest=(Get-Date).ToUniversalTime()
            $AsyncLoader.Jobs.$Jobkey.Paused=$false
        }

        $retry = $AsyncLoader.Jobs.$Jobkey.Retry + 1

        $StopWatch = [System.Diagnostics.Stopwatch]::New()
        do {
            $Request = $RequestError = $null
            $StopWatch.Restart()
            try {                
                if ($Quickstart) {
                    if (-not ($Request = Get-ContentByStreamReader ".\Cache\$($Jobkey).asy")) {
                        if (Test-Path ".\Cache\$($Jobkey).asy") {
                            try {Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore} catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        }
                        $Quickstart = $false
                    }
                }
                if (-not $Quickstart) {
                    if ($delay -gt 0) {Start-Sleep -Milliseconds $delay}
                    $Request = Invoke-GetUrl -JobData $AsyncLoader.Jobs.$Jobkey -JobKey $JobKey
                }
                if ($Request) {
                    $AsyncLoader.Jobs.$Jobkey.Success++
                    $AsyncLoader.Jobs.$Jobkey.Prefail=0
                } else {
                    $RequestError = "Empty request"
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $RequestError = "$($_.Exception.Message)"
            } finally {
                if ($RequestError) {$RequestError = "Problem fetching $($AsyncLoader.Jobs.$Jobkey.Url) using $($AsyncLoader.Jobs.$Jobkey.Method): $($RequestError)"}
            }

            if (-not $Quickstart) {$AsyncLoader.Jobs.$Jobkey.LastRequest=(Get-Date).ToUniversalTime()}

            $retry--
            if ($retry -gt 0) {
                if (-not $RequestError) {$retry = 0}
                else {
                    $RetryWait_Time = [Math]::Min($AsyncLoader.Jobs.$Jobkey.RetryWait - $StopWatch.ElapsedMilliseconds,5000)
                    if ($RetryWait_Time -gt 50) {
                        Start-Sleep -Milliseconds $RetryWait_Time
                    }
                }
            }
        } until ($retry -le 0)

        $StopWatch.Stop()
        $StopWatch = $null

        if (-not $Quickstart -and -not $RequestError -and $Request) {
            if ($AsyncLoader.Jobs.$JobKey.Method -eq "REST") {
                try {
                    $Request = $Request | ConvertTo-Json -Compress -Depth 10 -ErrorAction Stop
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    $RequestError = "$($_.Exception.Message)"
                } finally {
                    if ($RequestError) {$RequestError = "JSON problem: $($RequestError)"}
                }
            }
        }

        $CacheWriteOk = $false

        if ($RequestError -or -not $Request) {
            $AsyncLoader.Jobs.$Jobkey.Prefail++
            if ($AsyncLoader.Jobs.$Jobkey.Prefail -gt 5) {$AsyncLoader.Jobs.$Jobkey.Fail++;$AsyncLoader.Jobs.$Jobkey.Prefail=0}            
        } elseif ($Quickstart) {
            $CacheWriteOk = $true
        } else {
            $retry = 3
            do {
                $RequestError = $null
                try {
                    Write-ToFile -FilePath ".\Cache\$($Jobkey).asy" -Message $Request -NoCR -ThrowError
                    $CacheWriteOk = $true
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    $RequestError = "$($_.Exception.Message)"                
                }
                $retry--
                if ($retry -gt 0) {
                    if (-not $RequestError) {$retry = 0}
                    else {
                        Start-Sleep -Milliseconds 500
                    }
                }
            } until ($retry -le 0)
        }

        if ($CacheWriteOk) {
            $AsyncLoader.Jobs.$Jobkey.LastCacheWrite=(Get-Date).ToUniversalTime()
        }

        if (-not (Test-Path ".\Cache\$($Jobkey).asy")) {
            try {New-Item ".\Cache\$($Jobkey).asy" -ItemType File > $null} catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
        $AsyncLoader.Jobs.$Jobkey.Error = $RequestError
        $AsyncLoader.Jobs.$Jobkey.Running = $false
    }
    if (-not $quiet) {
        if ($AsyncLoader.Jobs.$Jobkey.Error -and $AsyncLoader.Jobs.$Jobkey.Prefail -eq 0 -and -not (Test-Path ".\Cache\$($Jobkey).asy")) {throw $AsyncLoader.Jobs.$Jobkey.Error}
        if (Test-Path ".\Cache\$($Jobkey).asy") {
            try {
                if ($AsyncLoader.Jobs.$JobKey.Method -eq "REST") {
                    if (Test-IsCore) {
                        Get-ContentByStreamReader ".\Cache\$($Jobkey).asy" | ConvertFrom-Json -ErrorAction Stop
                    } else {
                        $Data = Get-ContentByStreamReader ".\Cache\$($Jobkey).asy" | ConvertFrom-Json -ErrorAction Stop
                        $Data
                    }
                } else {
                    Get-ContentByStreamReader ".\Cache\$($Jobkey).asy"
                }
            }
            catch {if ($Error.Count){$Error.RemoveAt(0)};Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore;throw "Job $Jobkey contains clutter."}
        }
    }
}

function Get-MinerStatusKey {
    $Response = [guid]::NewGuid().ToString()
    Write-Log "Miner Status key created: $Response"
    $Response
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
        [DllImport("user32.dll")]
        public static extern int SetWindowText(IntPtr hWnd, string strTitle);
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
        $sw.Close()
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
    [System.Collections.Generic.List[string]]$Uri2 = @()
    while ($Uri -match "^(.*?)({[^}]+})(.*?)$") {
        if ($Matches[1].Length) {$Uri2.Add([System.Web.HttpUtility]::UrlEncode($Matches[1])) > $null}
        $Tmp=$Matches[2]
        $Uri=$Matches[3]
        if ($Tmp -match "^{(\w+):(.*?)}$") {$Tmp = "{$($Matches[1]):$([System.Web.HttpUtility]::UrlEncode($($Matches[2] -replace "\$","*dollar*")) -replace "\*dollar\*","$")}"}
        $Uri2.Add($Tmp) > $null
    }
    if ($Uri.Length) {$Uri2.Add([System.Web.HttpUtility]::UrlEncode($Uri)) > $null}
    $Uri = $Uri2 -join ''
    if ($ConvertDot) {$Uri -replace "\.","%2e"} else {$Uri}
}

function Get-LastDrun {
    if (Test-Path ".\Data\lastdrun.json") {try {[DateTime](Get-ContentByStreamReader ".\Data\lastdrun.json" | ConvertFrom-Json -ErrorAction Stop).lastdrun} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
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
        try {[DateTime](Get-ContentByStreamReader ".\Data\starttime.json" | ConvertFrom-Json -ErrorAction Stop).starttime} catch {if ($Error.Count){$Error.RemoveAt(0)}}
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
    [System.Collections.Generic.List[PSCustomObject]]$Global:AutoexecCommands = @()
    foreach($cmd in @(Get-ContentByStreamReader ".\Config\autoexec.txt" -ExpandLines | Select-Object)) {
        if ($cmd -match "^[\s\t]*`"(.+?)`"(.*)$") {
            if (Test-Path $Matches[1]) {                
                try {
                    $FilePath     = [IO.Path]::GetFullPath("$($Matches[1])")
                    $FileDir      = Split-Path $FilePath
                    $FileName     = Split-Path -Leaf $FilePath
                    $ArgumentList = "$($Matches[2].Trim())"
                    
                    # find and kill maroding processes
                    if ($IsWindows) {
                        @(Get-CIMInstance CIM_Process).Where({$_.ExecutablePath -and $_.ExecutablePath -like "$(Join-Path $FileDir "*")" -and $_.ProcessName -like $FileName -and (-not $ArgumentList -or $_.CommandLine -like "* $($ArgumentList)")}) | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore}
                    } elseif ($IsLinux) {
                        @(Get-Process).Where({$_.Path -and $_.Path -like "$(Join-Path $FileDir "*")" -and $_.ProcessName -like $FileName -and (-not $ArgumentList -or $_.CommandLine -like "* $($ArgumentList)")}) | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.Id)"; if (Test-OCDaemon) {Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null} else {Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
                    }

                    $Job = Start-SubProcess -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $FileDir -ShowMinerWindow $true -Priority $Priority -SetLDLIBRARYPATH -WinTitle "$FilePath $ArgumentList".Trim()
                    if ($Job) {
                        $Job | Add-Member FilePath $FilePath -Force
                        $Job | Add-Member Arguments $ArgumentList -Force
                        Write-Log "Autoexec command started: $FilePath $ArgumentList"
                        $Global:AutoexecCommands.Add($Job) >$null
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
    $Global:AutoexecCommands | Where-Object {$_.ProcessId -or $_.Name} | Foreach-Object {
        Stop-SubProcess -Job $_ -Title "Autoexec command" -Name "$($_.FilePath) $($_.Arguments)" -SkipWait
    }
}

function Start-Wrapper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$ProcessId = 0,
        [Parameter(Mandatory = $false)]
        [String]$LogPath = ""
    )
    if (-not $ProcessId -or -not $LogPath) {return}

    Start-Job -FilePath .\Scripts\Wrapper.ps1 -ArgumentList $PID, $ProcessId, $LogPath
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
                elseif ($Session.DefaultValues.NVSMIpath -and (Test-Path ($NVSMI = Join-Path $Session.DefaultValues.NVSMIpath "nvidia-smi.exe"))) {$NVSMI}
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
    [Switch]$Runas,
    [Parameter(Mandatory = $False)]
    [Switch]$CheckForErrors
)

    if (-not ($NVSMI = Get-NvidiaSmi)) {return}

    $ArgumentsString = "$($Arguments -join ' ')"

    if ($CheckForErrors -and $ArgumentsString -notmatch "-i ") {
        if (-not (Test-Path Variable:Global:GlobalNvidiaSMIList)) {
            $Global:GlobalNvidiaSMIList = @(Invoke-NvidiaSmi -Arguments "--list-gpus" | Foreach-Object {if ($_ -match "UUID:\s+([A-Z0-9\-]+)") {$Matches[1]} else {"error"}} | Select-Object)
        }
        $DeviceId = 0
        $GoodDevices = $Global:GlobalNvidiaSMIList | Foreach-Object {if ($_ -ne "error") {$DeviceId};$DeviceId++}
        $Arguments += "-i $($GoodDevices -join ",")"
        $SMI_Result = Invoke-NvidiaSmi -Query $Query -Arguments $Arguments -Runas:$Runas
        $DeviceId = 0
        $Global:GlobalNvidiaSMIList | Foreach-Object {
            if ($_ -ne "error") {$SMI_Result[$DeviceId];$DeviceId++}
            else {[PSCustomObject]@{}}
        }
    } else {

        if ($Query) {
            $ArgumentsString = "$ArgumentsString --query-gpu=$($Query -join ',') --format=csv,noheader,nounits"
            $CsvParams =  @{Header = @($Query | Foreach-Object {$_ -replace "[^a-z_-]","_" -replace "_+","_"} | Select-Object)}
            Invoke-Exe -FilePath $NVSMI -ArgumentList $ArgumentsString.Trim() -ExcludeEmptyLines -ExpandLines -Runas:$Runas | ConvertFrom-Csv @CsvParams | Foreach-Object {
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
            if ($IsLinux -and $Runas) {
                Set-OCDaemon "$NVSMI $ArgumentsString" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
            } else {
                Invoke-Exe -FilePath $NVSMI -ArgumentList $ArgumentsString -ExcludeEmptyLines -ExpandLines -Runas:$Runas
            }
        }
    }
}

function Get-LinuxXAuthority {
    if ($IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
        Get-ChildItem ".\IncludesLinux\bash" -Filter "getxauth.sh" -File | Foreach-Object {
            try {
                & chmod +x "$($_.FullName)" > $null
                Invoke-exe $_.FullName -ExpandLines | Where-Object {$_ -match "XAUTHORITY=(.+)"} | Foreach-Object {$Matches[1]}
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
    }
}

function Get-LinuxDisplay {
    if ($IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
        Get-ChildItem ".\IncludesLinux\bash" -Filter "getdisplay.sh" -File | Foreach-Object {
            try {
                & chmod +x "$($_.FullName)" > $null
                Invoke-exe $_.FullName -ExpandLines | Where-Object {$_ -match "DISPLAY=(.+)"} | Foreach-Object {$Matches[1]}
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
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
        for($i=0;$i -lt $Device.Count;$i++) {$Device[$i] = [int]$Device[$i]}
        Invoke-NvidiaSmi "index","power.default_limit","power.min_limit","power.max_limit","power.limit" -Arguments "-i $($Device -join ',')" | Where-Object {$_.index -match "^\d+$"} | Foreach-Object {
            $index = $Device.IndexOf([int]$_.index)
            if ($index -ge 0) {
                $PLim = [Math]::Round([double]($_.power_default_limit -replace '[^\d,\.]')*($PowerLimitPercent[[Math]::Min($index,$PowerLimitPercent.Count)]/100),2)
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
    $Device = $Global:DeviceCache.DevicesByTypes.AMD | Where-Object {$DeviceName -icontains $_.Name -and $_.Model -match "Vega"}
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
            (Get-NetConnectionProfile -IPv4Connectivity Internet -ErrorAction Ignore | Measure-Object).Count -gt 0 -or (Get-NetConnectionProfile -IPv6Connectivity Internet -ErrorAction Ignore | Measure-Object).Count -gt 0
        } else {
            $true
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)};$true}
}

function Test-IsOnBattery {
    [bool]$(if ($IsWindows) {
        try {
            -not (Get-CimInstance -classname BatteryStatus -namespace "root\wmi" -ErrorAction Stop).PowerOnline
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    })
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
    if ($Session.IsAdmin -ne $null) {
        $Session.IsAdmin
    } else {
        if ($IsWindows) {
            ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        } else {
            (whoami) -match "root"
        }
    }
}

function Test-IsCore
{
    $Session.IsCore -or ($Session.IsCore -eq $null -and $PSVersionTable.PSVersion -ge (Get-Version "6.1"))
}

function Test-IsPS7
{
    $Session.IsPS7 -or ($Session.IsPS7 -eq $null -and $PSVersionTable.PSVersion -ge (Get-Version "7.0"))
}

function Set-OsFlags {
    if ($Global:IsWindows -eq $null) {
        $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
        $Global:IsLinux   = -not $IsWindows
        $Global:IsMacOS   = $false
    }

    if ("$((Get-Culture).NumberFormat.NumberGroupSeparator)$((Get-Culture).NumberFormat.NumberDecimalSeparator)" -notmatch "^[,.]{2}$") {
        [CultureInfo]::CurrentCulture = 'en-US'
    }

    if (-not (Get-Command "Start-ThreadJob" -ErrorAction SilentlyContinue)) {Set-Alias -Scope Global Start-ThreadJob Start-Job}

    if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
       [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
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

function Get-LastSatPrice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [String]$Currency = "",
        [Parameter(Mandatory = $False)]
        [Double]$lastSatPrice = 0
    )

    if ($Global:Rates.$Currency -and -not $lastSatPrice) {$lastSatPrice = 1/$Global:Rates.$Currency*1e8}
    if (-not $Global:Rates.$Currency -and $lastSatPrice) {$Global:Rates.$Currency = 1/$lastSatPrice*1e8}
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
    $ts = $null
    if ($System) {
        try {
            if ($IsWindows) {
                $ts = (Get-Date) - (Get-CimInstance Win32_OperatingSystem -Property LastBootUpTime -ErrorAction Ignore | Select-Object -ExpandProperty LastBootUpTime)
            } elseif ($IsLinux) {
                $ts = New-TimeSpan -Seconds ([double]((cat /proc/uptime) -split "\s+" | Select-Object -First 1))
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not get system uptime: $($_.Exception.Message)"
            $ts = $null
        }
    }
    if (-not $ts) {
        try {
            $ts = (Get-Date).ToUniversalTime() - $Session.StartTime
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not get script uptime: $($_.Exception.Message)"
            $ts = $null
        }
    }
    if ($ts) {$ts} else {New-TimeSpan -Seconds 0}
}

function Get-SysInfo {
    if ($Script:CpuTDP -eq $null) {$Script:CpuTDP = Get-ContentByStreamReader ".\Data\cpu-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}
    if ($IsWindows) {

        $CIM_CPU = $null

        $CPUs = @(1..$Session.PhysicalCPUs | Foreach-Object {
            [PSCustomObject]@{
                    Clock       = 0
                    Utilization = 0
                    PowerDraw   = 0
                    Temperature = 0
                    Method      = "ohm"
            }
        } | Select-Object)

        $GetCPU_Data = if (Test-IsElevated) {
            try {
                Invoke-Exe ".\Includes\getcpu\GetCPU.exe" | ConvertFrom-Json -ErrorAction Stop
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
        }
        
        try {
            $Index = 0
            $CPUs | Foreach-Object {
                $CPU = $_

                if ($GetCPU_Data -and $GetCPU_Data[$Index] -ne $null) {
                    $CPU.Clock = $GetCPU_Data[$Index].Clock
                    $CPU.Utilization = $GetCPU_Data[$Index].Utilization
                    $CPU.PowerDraw = $GetCPU_Data[$Index].PowerDraw
                    $CPU.Temperature = $GetCPU_Data[$Index].Temperature
                } else {
                    if (-not $CIM_CPU) {
                        $CIM_CPU = Get-CimInstance -ClassName CIM_Processor
                    }
                    $CPU.Method = "cim"
                    $CIM_CPU | Select-Object -Index $Index | Foreach-Object {
                        if (-not $CPU.Clock)       {$CPU.Clock = $_.MaxClockSpeed}
                        if (-not $CPU.Utilization) {$CPU.Utilization = $_.LoadPercentage}
                        if (-not $CPU.Utilization) {$CPU.Utilization = 100}
                        if (-not $CPU.PowerDraw) {
                            $CpuName = "$($_.Name.Trim()) "
                            if (-not ($CPU_tdp = $Script:CpuTDP.PSObject.Properties | Where-Object {$CpuName -match $_.Name} | Select-Object -First 1 -ExpandProperty Value)) {$CPU_tdp = ($Script:CpuTDP.PSObject.Properties.Value | Measure-Object -Average).Average}
                            $CPU.PowerDraw = $CPU_tdp * ($CPU.Utilization / 100)
                            $CPU.Method = "tdp"
                        }
                    }
                }

                $Index++
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }

        try {
            $CPULoad = ($CPUs | Measure-Object -Property Utilization -Average).Average
            $OSData  = Get-CimInstance -Class Win32_OperatingSystem -ErrorAction Ignore
            $HDData  = Get-CimInstance -class Win32_LogicalDisk -namespace "root\CIMV2" -ErrorAction Ignore
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }

        [PSCustomObject]@{
            CpuLoad = $CPULoad
            Cpus    = $CPUs
            Memory  = [PSCustomObject]@{
                TotalGB = [decimal][Math]::Round($OSData.TotalVisibleMemorySize/1MB,1)
                UsedGB  = [decimal][Math]::Round(($OSData.TotalVisibleMemorySize - $OSData.FreePhysicalMemory)/1MB,1)
                UsedPercent = if ($OSData.TotalVisibleMemorySize -gt 0) {[Math]::Round(($OSData.TotalVisibleMemorySize - $OSData.FreePhysicalMemory)/$OSData.TotalVisibleMemorySize * 100,2)} else {0}
            }
            Disks   = @(
                $HDData | Where-Object {$_.Size -gt 0} | Foreach-Object {             
                    [PSCustomObject]@{ 
                        Drive = $_.Name 
                        Name = $_.VolumeName
                        TotalGB = [decimal][Math]::Round($_.Size/1GB,1)
                        UsedGB  = [decimal][Math]::Round(($_.Size-$_.FreeSpace)/1GB,1)
                        UsedPercent = if ($_.Size -gt 0) {[decimal][Math]::Round(($_.Size-$_.FreeSpace)/$_.Size * 100,2)} else {0}
                    }
                } | Select-Object
            )
        }
    } elseif ($IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
        Get-ChildItem ".\IncludesLinux\bash" -Filter "sysinfo.sh" -File | Foreach-Object {
            try {
                & chmod +x "$($_.FullName)" > $null
                Invoke-exe $_.FullName | ConvertFrom-Json -ErrorAction Stop
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
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
        for ($i=0; $i -lt $key.Length; $i+=32) {$s="$s$($key.Substring($i,8))-$($key.Substring($i+4,4))-$($key.Substring($i+8,4))-$($key.Substring($i+12,4))-$($key.Substring($i+16,12))"}
        $s
    }
}

function Get-HMACSignature {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]$string,
    [Parameter(Mandatory = $true)]
    [String]$secret,
    [Parameter(Mandatory = $false)]
    [String]$hash = "HMACSHA256"
)

    $sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create($hash)
    $sha.key = [System.Text.Encoding]::UTF8.Getbytes($secret)
    [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${string}))).ToLower() -replace "[^0-9a-z]"
}

function Invoke-BinanceRequest {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $False)]
    [String]$key,
    [Parameter(Mandatory = $False)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    $params = @{},
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://api.binance.com",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0,
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal
)

    $keystr = Get-MD5Hash "$($endpoint)$(Get-HashtableAsJson $params)"
    if (-not (Test-Path Variable:Global:BinanceCache)) {$Global:BinanceCache = [hashtable]@{}}
    if (-not $Cache -or -not $Global:BinanceCache[$keystr] -or -not $Global:BinanceCache[$keystr].request -or $Global:BinanceCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

        $Remote = $false

        if (-not $ForceLocal) {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                $serverbody = @{
                    endpoint  = $endpoint
                    key       = $key
                    secret    = $secret
                    params    = $params | ConvertTo-Json -Depth 10 -Compress
                    method    = $method
                    base      = $base
                    timeout   = $timeout
                    machinename = $Session.MachineName
                    workername  = $Config.Workername
                    myip      = $Session.MyIP
                }
                try {
                    $Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getbinance" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                    if ($Result.Status) {$Request = $Result.Content;$Remote = $true}
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Info "Binance server call: $($_.Exception.Message)"
                }
            }
        }

        if (-not $Remote -and $key -and $secret) {
            $timestamp = 0
            try {$timestamp = (Invoke-GetUrl "$($base)/api/v3/time" -timeout 3).serverTime} catch {if ($Error.Count){$Error.RemoveAt(0)}}
            if (-not $timestamp) {$timestamp = Get-UnixTimestamp -Milliseconds}

            $params["timestamp"] = $timestamp
            $paramstr = "$(($params.Keys | Sort-Object | Foreach-Object {"$($_)=$([System.Web.HttpUtility]::UrlEncode($params.$_))"}) -join '&')"

            $headers = [hashtable]@{
                'X-MBX-APIKEY'  = $key
            }
            try {
                $Request = Invoke-GetUrl "$base$endpoint" -timeout $Timeout -headers $headers -requestmethod $method -body "$($paramstr)&signature=$(Get-HMACSignature $paramstr $secret)"
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                "Binance API call: $($_.Exception.Message)"
                Write-Log -Level Info "Binance API call: $($_.Exception.Message)"
            }
        }

        if (-not $Global:BinanceCache[$keystr] -or $Request) {
            $Global:BinanceCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request}
        }
    }
    $Global:BinanceCache[$keystr].request
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

    $keystr = Get-MD5Hash "$($endpoint)$(Get-HashtableAsJson $params)"
    if (-not (Test-Path Variable:Global:NHCache)) {$Global:NHCache = [hashtable]@{}}
    if (-not $Cache -or -not $Global:NHCache[$keystr] -or -not $Global:NHCache[$keystr].request -or $Global:NHCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

        $Remote = $false

        if (-not $ForceLocal) {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
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
                    workername  = $Config.Workername
                    myip      = $Session.MyIP
                }
                try {
                    $Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getnh" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                    if ($Result.Status) {$Request = $Result.Content;$Remote = $true}
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Info "Nicehash server call: $($_.Exception.Message)"
                }
            }
        }

        if (-not $Remote -and $key -and $secret -and $organizationid) {
            $uuid = [string]([guid]::NewGuid())
            $timestamp = 0
            try {$timestamp = (Invoke-GetUrl "$($base)/api/v2/time" -timeout 3).serverTime} catch {if ($Error.Count){$Error.RemoveAt(0)}}
            if (-not $timestamp) {$timestamp = Get-UnixTimestamp -Milliseconds}

            $paramstr = "$(($params.Keys | Foreach-Object {"$($_)=$([System.Web.HttpUtility]::UrlEncode($params.$_))"}) -join '&')"
            $str = "$key`0$timestamp`0$uuid`0`0$organizationid`0`0$($method.ToUpper())`0$endpoint`0$(if ($method -eq "GET") {$paramstr} else {"`0$($params | ConvertTo-Json -Depth 10 -Compress)"})"

            $headers = [hashtable]@{
                'X-Time'            = $timestamp
                'X-Nonce'           = $uuid
                'X-Organization-Id' = $organizationid
                'X-Auth'            = "$($key):$(Get-HMACSignature $str $secret)"
                'Cache-Control'     = 'no-cache'
            }
            try {
                $body = Switch($method) {
                    "GET" {if ($params.Count) {$params} else {$null};Break}
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

function Invoke-Reboot {
    if ($IsLinux) {
        if ((Get-Command "Test-OCDaemon" -ErrorAction Ignore) -and (Test-OCDaemon)) {
            Invoke-OCDaemon -Cmd "reboot" -Quiet > $null
        } elseif (Test-IsElevated) {
            Invoke-Exe -FilePath "reboot" -RunAs > $null
        } else {
            throw "need to be root to reboot $($Session.MachineName)"
        }
    } else {
        try {
            Restart-Computer -Force -ErrorAction Stop
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Restart-Computer command failed. Falling back to shutdown."
            shutdown /r /f /t 10 /c "RainbowMiner scheduled restart" 2>$null
            if ($LastExitCode -ne 0) {
                throw "shutdown cannot reboot $($Session.MachineName) ($LastExitCode)"
            }
        }
    }
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

function Get-LastUserInput {
    try {
        if ($IsWindows) {
            Add-Type -Path .\DotNet\Tools\UserInput.cs
            [PSCustomObject]@{
                IdleTime  = [PInvoke.Win32.UserInput]::IdleTime
                LastInput = [PInvoke.Win32.UserInput]::LastInput
            }
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }
}

