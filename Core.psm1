function Start-Core {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$ConfigFile = ".\Config\config.txt",
        [Parameter(Mandatory = $false)]
        [Switch]$SetupOnly = $false
    )

    try {
        #Setup config file name and path
        $RunCleanup = $true
        $ConfigPath = [IO.Path]::GetDirectoryName($ConfigFile)
        if (-not $ConfigPath) {$ConfigPath = ".\Config"; $ConfigFile = "$($ConfigPath)\$($ConfigFile)"}
        if (-not (Test-Path $ConfigPath)) {$RunCleanup = $false;New-Item $ConfigPath -ItemType "directory" -Force > $null}
        if (-not (Test-Path "$ConfigPath\Backup")) {New-Item "$ConfigPath\Backup" -ItemType "directory" -Force > $null}
        if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}

        if ($IsLinux) {
            [Console]::TreatControlCAsInput = $True

            Initialize-OCDaemon

            if (-not (Test-Path "/opt/rainbowminer/lib")) {
                if ($Libs = Get-ContentByStreamReader ".\IncludesLinux\libs.json" | ConvertFrom-Json -ErrorAction Ignore) {
                    $Dir = "$Pwd/IncludesLinux/lib"

                    $Libs.PSObject.Properties | Where-Object {-not (Test-Path "$($Dir)/$($_.Name)")} | Foreach-Object {
                        Invoke-Exe -FilePath "ln" -ArgumentList "-s $($Dir)/$($_.Value) $($Dir)/$($_.Name)" > $null
                    }
                }
            }
        }

        $Session.ConfigName = [IO.Path]::GetFileNameWithoutExtension($ConfigFile)

        #Setup console and display logo
        $host.UI.RawUI.WindowTitle = $Session.MainWindowTitle
        if ($false -and -not $psISE -and $IsWindows) {
            $ColorConfigPath = Join-Path $ConfigPath "colors.$(Split-Path $ConfigFile -Leaf)"
            if (Test-Path $ColorConfigPath) {
                try {
                    $Colors = Get-ContentByStreamReader $ColorConfigPath | ConvertFrom-Json -ErrorAction Stop
                    $Colors.PSObject.Properties.Name | Where-Object {$_ -match    "^(Fore|Back)" -and $Colors.$_ -and $Colors.$_ -ne -1 -and $Host.UI.RawUI.PSObject.Properties.Name -icontains $_} | Foreach-Object {$Host.UI.RawUI.$_ = $Colors.$_}
                    $Colors.PSObject.Properties.Name | Where-Object {$_ -notmatch "^(Fore|Back)" -and $Colors.$_ -and $Colors.$_ -ne -1 -and $Host.PrivateData.PSObject.Properties.Name -icontains $_} | Foreach-Object {$Host.PrivateData.$_ = $Colors.$_}
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "Your $ColorConfigPath file is corrupted. Resetting to defaults."
                    if (Test-Path $ColorConfigPath) {Remove-Item $ColorConfigPath -Force}
                }
            }
        }

        Clear-Host

        Write-Host "__________        .__      ___.                   _____  .__                     " -ForegroundColor Red
        Write-Host "\______   \_____  |__| ____\_ |__   ______  _  __/     \ |__| ____   ___________ " -ForegroundColor DarkYellow
        Write-Host " |       _/\__  \ |  |/    \| __ \ /  _ \ \/ \/ /  \ /  \|  |/    \_/ __ \_  __ \" -ForegroundColor Yellow
        Write-Host " |    |   \ / __ \|  |   |  \ \_\ (  <_> )     /    Y    \  |   |  \  ___/|  | \/" -ForegroundColor Green
        Write-Host " |____|_  /(____  /__|___|  /___  /\____/ \/\_/\____|__  /__|___|  /\___  >__|   " -ForegroundColor Blue
        Write-Host "        \/      \/        \/    \/                     \/        \/     \/       " -ForegroundColor DarkMagenta
        Write-Host " "
        Write-Host "Starting $(if ($SetupOnly) {"setup for "})v$($Session.Version)! Please wait.."
        Write-Host " "

        #Setup Core script variables
        $Script:AllPools = $null
        [System.Collections.ArrayList]$Script:ActiveMiners   = @()
        [System.Collections.ArrayList]$Script:WatchdogTimers = @()

        #Setup session variables
        [hashtable]$Session.Rates = @{BTC = [Double]1}
        [hashtable]$Session.ConfigFiles = @{
            Config     = @{Path='';LastWriteTime=0;Healthy=$false}
            Colors     = @{Path='';LastWriteTime=0;Healthy=$false}
            Devices    = @{Path='';LastWriteTime=0;Healthy=$false}
            Miners     = @{Path='';LastWriteTime=0;Healthy=$false}
            OCProfiles = @{Path='';LastWriteTime=0;Healthy=$false}
            Pools      = @{Path='';LastWriteTime=0;Healthy=$false}
            Algorithms = @{Path='';LastWriteTime=0;Healthy=$false}
            Coins      = @{Path='';LastWriteTime=0;Healthy=$false}
            GpuGroups  = @{Path='';LastWriteTime=0;Healthy=$false}
            Scheduler  = @{Path='';LastWriteTime=0;Healthy=$false}
            Combos     = @{Path='';LastWriteTime=0;Healthy=$false}
            MRR        = @{Path='';LastWriteTime=0;Healthy=$true}
        }
        [hashtable]$Session.MinerInfo = @{}

        [System.Collections.ArrayList]$Session.GC.GetTicker = @()

        $Session.StartTime         = if ($LastStartTime = (Get-LastStartTime)) {$LastStartTime} else {(Get-Date).ToUniversalTime()}

        $Session.Strikes           = 3
        $Session.SyncWindow        = 10 #minutes, after that time, the pools bias price will start to decay
        $Session.OutofsyncWindow   = 60 #minutes, after that time, the pools price bias will be 0
        $Session.DecayPeriod       = 60 #seconds
        $Session.DecayBase         = 1 - 0.1 #decimal percentage

        $Session.RoundCounter = 0

        $Session.SkipSwitchingPrevention = $false
        $Session.StartDownloader = $false
        $Session.PauseMiners = $false
        $Session.PauseMinersByScheduler = $false
        $Session.RestartMiners = $false
        $Session.Restart = $false
        $Session.LockMiners = [PSCustomObject]@{Locked=$false;Enabled=$false;Pools=@()}
        $Session.AutoUpdate = $false
        $Session.MSIAcurrentprofile = -1
        $Session.RunSetup = $SetupOnly
        $Session.SetupOnly = $SetupOnly
        $Session.IsBenchmarkingRun = $false
        $Session.IsDonationRun = $false
        $Session.IsExclusiveRun = $false
        $Session.IsInitialSetup = $false
        $Session.Stopp = $false
        $Session.Benchmarking = $false
        $Session.ReportTotals = $false
        $Session.ReportMinerData = $false
        $Session.ReportPoolsData = $false
        $Session.TimeDiff = 0

        try {$Session.EnableColors = [System.Environment]::OSVersion.Version -ge (Get-Version "10.0") -and $PSVersionTable.PSVersion -ge (Get-Version "5.1")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Session.EnableColors = $false}

        if ($Session.IsAdmin) {Write-Log "Run as administrator"}

        #Cleanup the log and cache
        if (Test-Path ".\Logs"){Get-ChildItem -Path ".\Logs" -Filter "*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-5)} | Remove-Item -ErrorAction Ignore} else {New-Item ".\Logs" -ItemType "directory" -Force > $null}
        if (Test-Path ".\Cache"){Get-ChildItem -Path ".\Cache" -Filter "*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-14)} | Remove-Item -ErrorAction Ignore} else {New-Item ".\Cache" -ItemType "directory" -Force > $null}

        #Set env variables
        if ($env:GPU_FORCE_64BIT_PTR -ne 1)          {$env:GPU_FORCE_64BIT_PTR = 1}
        if ($env:GPU_MAX_HEAP_SIZE -ne 100)          {$env:GPU_MAX_HEAP_SIZE = 100}
        if ($env:GPU_USE_SYNC_OBJECTS -ne 1)         {$env:GPU_USE_SYNC_OBJECTS = 1}
        if ($env:GPU_MAX_ALLOC_PERCENT -ne 100)      {$env:GPU_MAX_ALLOC_PERCENT = 100}
        if ($env:GPU_SINGLE_ALLOC_PERCENT -ne 100)   {$env:GPU_SINGLE_ALLOC_PERCENT = 100}
        if ($env:GPU_MAX_WORKGROUP_SIZE -ne 256)     {$env:GPU_MAX_WORKGROUP_SIZE = 256}
        if ($env:CUDA_DEVICE_ORDER -ne 'PCI_BUS_ID') {$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID'}

        Write-Host "Detecting devices .."

        $Session.AllDevices = Get-Device "cpu","gpu" -IgnoreOpenCL

        Write-Host "Initialize configuration .."

        Set-PresetDefault

        if (-not (Test-Path $ConfigFile)) {
            $Parameters = @{VersionCompatibility=$Session.Version}
            $Session.DefaultValues.Keys | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction Ignore -Force}
            Set-ContentJson -PathToFile $ConfigFile -Data $Parameters > $null        
        } else {
            $ConfigForUpdate = Get-ContentByStreamReader $ConfigFile | ConvertFrom-Json -ErrorAction Stop
            if (-not $ConfigForUpdate) {throw "Config file is empty"}
            $ConfigForUpdate_changed = $false
            if ($ConfigForUpdate.PSObject.Properties.Name -icontains "LocalAPIport") {$ConfigForUpdate | Add-Member APIport $ConfigForUpdate.LocalAPIport -Force}
            $MPHLegacyUpdate = if ($ConfigForUpdate.PSObject.Properties.Name -icontains "API_ID") {@{UserName=$ConfigForUpdate.UserName;API_ID=$ConfigForUpdate.API_ID;API_Key=$ConfigForUpdate.API_Key}}
            Compare-Object @($ConfigForUpdate.PSObject.Properties.Name) @($Session.DefaultValues.Keys) | Foreach-Object {
                if ($_.SideIndicator -eq "=>") {$ConfigForUpdate | Add-Member $_.InputObject "`$$($_.InputObject)";$ConfigForUpdate_changed=$true}
                elseif ($_.SideIndicator -eq "<=" -and @("API_ID","API_Key","UserName","LocalAPIport","RemoteAPI","ConfigFile","ExcludeNegativeProfit","DisableAutoUpdate","Regin","Debug","Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable") -icontains $_.InputObject) {$ConfigForUpdate.PSObject.Properties.Remove($_.InputObject);$ConfigForUpdate_changed=$true}
            }
            if ($ConfigForUpdate_changed) {Set-ContentJson -PathToFile $ConfigFile -Data $ConfigForUpdate > $null}
        }
        $Session.ConfigFiles["Config"].Healthy = $true
        Get-Item $ConfigFile | Foreach-Object {
            $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName | Resolve-Path -Relative
            $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name

            if (-not $psISE) {
                $BackupDate = Get-Date -Format "yyyyMMddHHmmss"
                $BackupDateDelete = (Get-Date).AddMonths(-1).ToString("yyyyMMddHHmmss")
                Get-ChildItem "$($ConfigFile_Path)\Backup" -Filter "*" | Where-Object {$_.BaseName -match "^(\d{14})" -and $Matches[1] -le $BackupDateDelete} | Remove-Item -Force -ErrorAction Ignore
            }

            $Session.ConfigFiles.Keys | Foreach-Object {
                $FNtmp   = "$(if ($_ -ne "Config") {"$($_.ToLower())."})$ConfigFile_Name"
                $Session.ConfigFiles[$_].Path = Join-Path $ConfigFile_Path $FNtmp
                if (-not $psISE -and (Test-Path $Session.ConfigFiles[$_].Path)) {Copy-Item $Session.ConfigFiles[$_].Path -Destination (Join-Path (Join-Path $ConfigFile_Path "Backup") "$($BackupDate)_$($FNtmp)")}
                Set-ConfigDefault $_ -Force > $null
                if (Test-Path $Session.ConfigFiles[$_].Path) {$Session.ConfigFiles[$_].Path = $Session.ConfigFiles[$_].Path | Resolve-Path -Relative}
            }

            if ($false -and $MPHLegacyUpdate -and ($PoolsPath = Get-ConfigPath "pools")) {
                $PoolsData = Get-ConfigContent "pools" -Parameters $MPHLegacyUpdate -ConserveUnkownParameters
                Set-ContentJson -PathToFile $PoolsPath -Data $PoolsData > $null
            }
        }

        #create special config files
        if (-not (Test-Path ".\Config\minerconfigfiles.txt") -and (Test-Path ".\Data\minerconfigfiles.default.txt")) {Copy-Item ".\Data\minerconfigfiles.default.txt" ".\Config\minerconfigfiles.txt" -Force -ErrorAction Ignore}

        try {
            #cleanup legacy data
            if ((Test-Path ".\Cleanup.ps1") -and (Test-Path ".\Data\version.json")) {
                $LastVersion = (Get-ContentByStreamReader ".\Data\version.json" | ConvertFrom-Json -ErrorAction Ignore).Version
                if ($RunCleanup -and $LastVersion -and (Compare-Version $LastVersion $Session.Version) -lt 0) {
                    Write-Host "Cleanup legacy data .."
                    [hashtable]$Cleanup_Parameters = @{
                        AllDevices = $Session.AllDevices
                        MyCommandParameters = $Session.DefaultValues.Keys
                        Version = $LastVersion
                    }
                    $Session.ConfigFiles.Keys | Foreach-Object {$Cleanup_Parameters["$(if ($_ -ne "Config") {$_})ConfigFile"] = $Session.ConfigFiles[$_].Path}
                    Get-Item ".\Cleanup.ps1" | Foreach-Object {
                        $Cleanup_Result = & {
                            foreach ($k in $Cleanup_Parameters.Keys) {Set-Variable $k $Cleanup_Parameters.$k}
                            & $_.FullName @Cleanup_Parameters
                        }
                        if ($Cleanup_Result) {Write-Host $Cleanup_Result}
                    }
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Cleanup failed: $($_.Exception.Message)"
        }

        try {
            #if linux and running as root re-install libraries and binaries
            if ($IsLinux -and (Test-Path ".\IncludesLinux\linux.updated") -and (Test-Path ".\install.sh")) {
                if ($Session.IsAdmin) {
                    Write-Host "Re-installing libraries and binaries .."
                    bash -c "./install.sh"
                } else {
                    Write-Log -Level Warn "RainbowMiner has updated some linux libraries/binaries. Please run ./install.sh as soon as possible!"
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Re-install failed: $($_.Exception.Message)"
        }

        #Remove stuck update
        if (Test-Path "Start.bat.saved") {Remove-Item "Start.bat.saved" -Force -ErrorAction Ignore}

        #Read miner info
        if (Test-Path ".\Data\minerinfo.json") {try {(Get-ContentByStreamReader ".\Data\minerinfo.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Foreach-Object {$Session.MinerInfo[$_.Name] = $_.Value}} catch {if ($Error.Count){$Error.RemoveAt(0)}}}

        #write version to data
        Set-ContentJson -PathToFile ".\Data\version.json" -Data ([PSCustomObject]@{Version=$Session.Version}) > $null
        $true
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "$($_) Cannot run RainbowMiner. "
        $false
    }

    $Session.Timer      = (Get-Date).ToUniversalTime()
    $Session.NextReport = (Get-Date).ToUniversalTime()
    $Session.DecayStart = (Get-Date).ToUniversalTime()
    [hashtable]$Session.Updatetracker = @{
        Balances = 0
        TimeDiff = 0
        MinerSave = if (Test-Path ".\Data\minerdata.json") {Get-ChildItem ".\Data\minerdata.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
        PoolsSave = if (Test-Path ".\Data\poolsdata.json") {Get-ChildItem ".\Data\poolsdata.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
    }
}

function Update-ActiveMiners {
    [CmdletBinding()]
    param([Bool]$FirstRound = $false, [Switch]$Silent = $false)

    Update-DeviceInformation $Script:ActiveMiners_DeviceNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    $MinersUpdated = 0
    $MinersFailed  = 0
    $ExclusiveMinersFailed = 0
    $Script:ActiveMiners | Where-Object Best |  Foreach-Object {
        $Miner = $_
        if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
            if (-not $FirstRound -or $Miner.Rounds) {
                $Miner.UpdateMinerData() > $null
                if (-not $Miner.CheckShareRatio() -and -not ($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Sub $Session.DevicesToVendors[$Miner.DeviceModel])})) {
                    Write-Log "Too many rejected shares for miner $($Miner.Name)"
                    $Miner.ResetMinerData()
                }
            }
        }

        Switch ($Miner.GetStatus()) {
            "Running"       {if ($Session.Config.EnableOCprofiles -and ($Miner.DeviceName -notlike "CPU*") -and ($Miner.GetLastSetOCTime() -lt (Get-Date).AddMinutes(-10).ToUniversalTime() -or $API.ApplyOC)) {$Miner.SetOCprofile($Session.Config,500);$API.ApplyOC=$false};$MinersUpdated++}
            "RunningFailed" {$Miner.ResetMinerData();$MinersFailed++;if ($Miner.IsExclusiveMiner) {$ExclusiveMinersFailed++}}
        }        
    }
    if ($MinersFailed) {
        $API.RunningMiners = $Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running}
    }
    if (-not $Silent) {
        [PSCustomObject]@{
            MinersUpdated = $MinersUpdated
            MinersFailed  = $MinersFailed
            ExclusiveMinersFailed = $ExclusiveMinersFailed
        }
    }
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
    $Script:ActiveMiners | Foreach-Object {
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

                Write-Log -Level Info "$($Miner.BaseName) $(if ($Miner.IsBenchmarking()) {"benchmarking"} else {"mining"}) $($Miner_Algorithm) on $($Miner.DeviceModel): $($Miner.GetMinerDataCount()) samples / round $(if ($Miner.IsBenchmarking()) {"$($Miner.Benchmarked) / variance $("{0:f2}" -f ($Miner.Variance[$Miner.Algorithm.IndexOf($Miner_Algorithm)]*100))%"} else {$Miner.Rounds})"

                $Stat = $null
                if (-not $Miner.IsBenchmarking() -or $Miner_Speed) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($Miner_Algorithm -replace '\-.*$')_HashRate" -Value $Miner_Speed -Difficulty $Miner_Diff -Ratio $Miner.RejectedShareRatio[$Miner_Index] -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $Session.DevicesToVendors[$Miner.DeviceModel] -Quiet:$($Quiet -or ($Miner.GetRunningTime() -lt (New-TimeSpan -Seconds 30)) -or $Miner.IsWrapper())
                    $Statset++
                }

                #Update watchdog timer
                if ($WatchdogTimer = $Script:WatchdogTimers | Where-Object {$_.MinerName -eq $Miner.Name -and $_.PoolName -eq $Miner.Pool[$Miner_Index] -and $_.Algorithm -eq $Miner_Algorithm}) {
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

function Invoke-ReportMinerStatus {

    if (-not $Session.Config.MinerStatusURL -or -not $Session.Config.MinerStatusKey) {return}

    $Version = "RainbowMiner $($Session.Version.ToString())"
    $Status = if ($Session.Paused) {"Paused"} elseif (-not $Session.Profitable) {"Waiting"} else {"Running"}
    $Rates = [PSCustomObject]@{}
    $Session.Rates.Keys | Where-Object {$Session.Config.Currency -icontains $_} | Foreach-Object {$Rates | Add-Member $_ $Session.Rates.$_ -Force}

    [System.Collections.ArrayList]$Including_Strings = @()
    if ($Session.ReportTotals)    {$Including_Strings.Add("totals") > $null}
    if ($Session.ReportMinerData) {$Including_Strings.Add("minerdata") > $null}
    if ($Session.ReportPoolsData) {$Including_Strings.Add("poolsdata") > $null}
    Write-Log -Level Info "Pinging monitoring server$(if ($Including_Strings.Count) {" (including $($Including_Strings -join ", "))"}). "

    $Profit = 0.0
    $PowerDraw = 0.0
    $TempAlert = 0

    $minerreport = ConvertTo-Json @(
        $Script:ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {
            $Miner = $_
            $Miner_PowerDraw = $Miner.GetPowerDraw()
            $Profit += [Double]$Miner.Profit
            $PowerDraw += [Double]$Miner_PowerDraw

            [System.Collections.ArrayList]$Devices = @()
            Get-Device $Miner.DeviceName | Foreach-Object {
                if ($_.Type -eq "GPU") {
                    if ($_.Data.Temperature -gt $Session.Config.MinerStatusMaxTemp) {$TempAlert++}
                    $Devices.Add([PSCustomObject]@{
                        Id    = $_.Type_PlatformId_Index
                        Name  = $_.Model
                        Mem   = [int]($_.OpenCL.GlobalMemSize / 1GB)
                        Temp  = $_.Data.Temperature
                        Fan   = $_.Data.FanSpeed
                        Watt  = $_.Data.PowerDraw
                        Core  = $_.Data.Clock
                        MemC  = $_.Data.ClockMem
                        MaxTemp = $_.DataMax.Temperature
                    }) > $null
                } else {
                    $Devices.Add([PSCustomObject]@{
                        Id    = $_.Type_PlatformId_Index
                        Name  = $_.Model_Name
                        Watt  = $_.Data.PowerDraw
                    }) > $null
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
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Miner Status get pool stats has failed. "
        }
    }

    if (Test-Path ".\Data\reportapi.json") {try {$ReportAPI = Get-ContentByStreamReader ".\Data\reportapi.json" | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)};$ReportAPI=$null}}
    if (-not $ReportAPI) {$ReportAPI = @([PSCustomObject]@{match    = "rbminer.net";apiurl   = "https://rbminer.net/api/report.php"})}

    # Send the request
    try {
        $ReportUrl = $Session.Config.MinerStatusURL
        $ReportStatus = "Error"
        $ReportDone = $false

        $ReportInterval = if ($Session.CurrentInterval -gt $Session.Config.Interval -and $Session.CurrentInterval -gt $Session.Config.BenchmarkInterval) {$Session.CurrentInterval} else {$Session.Config.BenchmarkInterval}

        $ReportAPI | Where-Object {-not $ReportDone -and $ReportUrl -match $_.match} | Foreach-Object {
            $ReportUrl = $_.apiurl
            $Response = Invoke-GetUrl $ReportUrl -body @{user = $Session.Config.MinerStatusKey; email = $Session.Config.MinerStatusEmail; pushoverkey = $Session.Config.PushOverUserKey; worker = $Session.Config.WorkerName; machinename = $Session.MachineName; machineip = $Session.MyIP; cpu = "$($Session.DevicesByTypes.CPU.Model_Name | Select-Object -Unique)";version = $Version; status = $Status; profit = "$Profit"; powerdraw = "$PowerDraw"; earnings_avg = "$($Session.Earnings_Avg)"; earnings_1d = "$($Session.Earnings_1d)"; pool_totals = ConvertTo-Json @($Pool_Totals | Select-Object) -Compress; minerdata = "$(if ($Session.ReportMinerData -and (Test-Path ".\Data\minerdata.json")) {Get-ContentByStreamReader ".\Data\minerdata.json"};$Session.ReportMinerData=$false)"; poolsdata = "$(if ($Session.ReportPoolsData -and (Test-Path ".\Data\poolsdata.json")) {Get-ContentByStreamReader ".\Data\poolsdata.json"};$Session.ReportPoolsData=$false)"; rates = ConvertTo-Json $Rates -Compress; interval = $ReportInterval; uptime = "$((Get-Uptime).TotalSeconds)"; sysuptime = "$((Get-Uptime -System).TotalSeconds)";maxtemp = "$($Session.Config.MinerStatusMaxTemp)"; tempalert=$TempAlert; data = $minerreport}
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
                    $API.RemoteMiners = $Response.Workers | Where-Object worker -ne $Session.Config.WorkerName
                }
                if ($Response.Compare -ne $null) {
                    $API.CompareMiners = $Response.Compare
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
    [System.Collections.ArrayList]$CurrenciesWithBalances = @()
    [System.Collections.ArrayList]$CurrenciesToExchange   = @()
    [System.Collections.ArrayList]$CurrenciesMissing = @()

    $RatesAPI = [PSCustomObject]@{}
    
    $Balances.currency | Select-Object -Unique | Sort-Object | Foreach-Object {$CurrenciesWithBalances.Add($_) > $null}
    @("BTC") + $Config.Currency | Select-Object -Unique | Sort-Object | Foreach-Object {$CurrenciesToExchange.Add($_) > $null}
    $CurrenciesWithBalances + $CurrenciesToExchange | Where-Object {-not $Session.Rates.ContainsKey($_)} | Foreach-Object {$CurrenciesMissing.Add($_) > $null}

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
    $CurrenciesWithBalances + $Config.Currency | Where-Object {$_} | Select-Object -Unique | Foreach-Object {$Digits[$_] = if ($Session.WorldCurrencies -icontains $_) {2} else {8}}

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

function Invoke-Core {

    #Validate version file
    if (-not (Test-Path ".\Data\version.json") -or -not (Get-ContentByStreamReader ".\Data\version.json" | ConvertFrom-Json -ErrorAction Ignore).Version) {
        Set-ContentJson -PathToFile ".\Data\version.json" -Data ([PSCustomObject]@{Version=$Session.Version}) > $null
    }

    #Load the config    
    $ConfigBackup = if ($Session.Config -is [object]){$Session.Config | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json -ErrorAction Ignore}else{$null}
    $CheckConfig = $true
    $CheckPools = $false
    $CheckGpuGroups = $false
    $CheckCombos = $false
    
    [string[]]$Session.AvailPools = Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Where-Object {$_ -notmatch "WhatToMine"} | Sort-Object
    [string[]]$Session.AvailMiners = Get-ChildItem ".\Miners\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object

    $Session.MyIP = Get-MyIP

    if (Test-Path $Session.ConfigFiles["Config"].Path) {

        if (-not $Session.IsDonationRun) {Get-SessionServerConfig}

        if (-not $Session.IsDonationRun -and (-not $Session.Config -or $Session.RunSetup -or (Test-Config "Config" -LastWriteTime))) {

            do {
                if ($Session.Config -eq $null) {Write-Host "Read configuration .."}
                $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1"
                $Session.ConfigFiles["Config"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Config"].Path).LastWriteTime.ToUniversalTime()
                $Parameters = @{}
                $Session.DefaultValues.Keys | Where-Object {$_ -ne "SetupOnly"} | ForEach-Object {
                    $val = $Session.DefaultValues[$_]
                    if ($ConfigSetup.$_ -ne $null) {$val = $ConfigSetup.$_}
                    if ($val -is [array]) {$val = $val -join ','}
                    $Parameters.Add($_ , $val)
                }
                $Session.Config = Get-ChildItemContent $Session.ConfigFiles["Config"].Path -Force -Parameters $Parameters
                $Session.Config | Add-Member Pools ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member Miners ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member OCProfiles ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member Algorithms ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member Coins ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member GpuGroups ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member Combos ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member Scheduler @() -Force

                Remove-Variable "ConfigSetup"
                Remove-Variable "Parameters"

                if (-not $Session.Config.Wallet -or -not $Session.Config.WorkerName -or -not $Session.Config.PoolName) {
                    $Session.RunSetup = $true
                }

                $ReReadConfig = $false
                if ($Session.RunSetup) {
                    Import-Module .\Setup.psm1
                    Start-Setup -Config $Session.Config -ConfigFiles $Session.ConfigFiles -SetupOnly:$Session.SetupOnly
                    Remove-Module "Setup" -ErrorAction Ignore
                    $Session.RestartMiners = $true
                    $ReReadConfig = $true
                    $Session.RunSetup = $false
                    $Session.RoundStart = $null

                    Write-Host " "
                    Write-Host "Exiting configuration setup - $(if ($Session.SetupOnly) {"now run $(if ($IsWindows) {"Start.bat"} else {"start.sh"}). Happy mining!"} else {"all miners will be restarted. Please be patient!"})" -ForegroundColor Yellow
                    Write-Host " "
                }
            } until (-not $ReReadConfig)
        } else {
            $CheckConfig = $false
        }
    }
    
    #Error in Config.txt
    if ($Session.Config -isnot [PSCustomObject]) {
        Write-Log -Level Error "$($Session.ConfigFiles["Config"].Path) is invalid. Cannot continue. "
        Start-Sleep 10
        Break
    }

    if ($Session.SetupOnly) {Break}

    $Session.ConfigFiles["Config"].Healthy = $true

    if (-not (Test-Internet)) {
        $i = 0
        $Internet_ok = $false

        if (Test-Path Variable:Global:AsyncLoader) {$AsyncLoader.Pause = $false}

        do {
            if (-not ($i % 60)) {Write-Log -Level Warn "Waiting 30s for internet connection. Press [X] to exit RainbowMiner"}
            Start-Sleep -Milliseconds 500
            if ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}
            $i++
            if (-not ($i % 20)) {$Internet_ok = Test-Internet}
        } until ($Internet_ok -or $keyPressedValue -eq "X")

        if (Test-Path Variable:Global:AsyncLoader) {$AsyncLoader.Pause = -not $Internet_ok}

        if ($keyPressedValue -eq "X") {
            Write-Log "User requests to stop script. "
            Write-Host "[X] pressed - stopping script."
            break
        }
        if ($i -gt $Session.Config.BenchmarkInterval*2) {
            Update-WatchdogLevels -Reset
            $Script:WatchdogTimers.Clear()
        }
    }

    if (-not $Session.Updatetracker.TimeDiff -or $Session.Updatetracker.TimeDiff -lt (Get-Date).AddMinutes(-60)) {
        $Session.Updatetracker.TimeDiff = Get-Date
        $TimeDiff = ((Get-Date)-(Get-NtpTime)).TotalSeconds
        $Session.TimeDiff = [Math]::Sign($TimeDiff)*[Math]::Floor([Math]::Abs($TimeDiff))
    }

    #Convert to array, if needed and check contents of some fields, if Config has been reread or reset
    if ($CheckConfig) {
        if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating config data"}
        #for backwards compatibility
        if ($Session.Config.Type -ne $null) {$Session.Config | Add-Member DeviceName $Session.Config.Type -Force;$Session.Config | Add-Member ExcludeDeviceName @() -Force}
        if ($Session.Config.GPUs -ne $null -and $Session.Config.GPUs) {
            if ($Session.Config.GPUs -is [string]) {$Session.Config.GPUs = [regex]::split($Session.Config.GPUs,"\s*[,;]+\s*")}
            $Session.Config | Add-Member DeviceName @() -Force
            $Session.Config | Add-Member ExcludeDeviceName @() -Force
            Get-Device "nvidia" | Where-Object {$Session.Config.GPUs -contains $_.Type_Vendor_Index} | Foreach-Object {$Session.Config.DeviceName += [string]("GPU#{0:d2}" -f $_.Type_Vendor_Index)}
        }

        $Session.Config.PSObject.Properties | Where-Object {$_.TypeNameOfValue -ne "System.Object" -and $_.MemberType -eq "NoteProperty"} | Select-Object Name,Value | Foreach-Object {
            $name = $_.Name;
            $var = $Session.DefaultValues[$name]
            if ($var -is [array] -and $Session.Config.$name -is [string]) {$Session.Config.$name = $Session.Config.$name.Trim(); $Session.Config.$name = @(if ($Session.Config.$name -ne ''){@([regex]::split($Session.Config.$name.Trim(),"\s*[,;]+\s*") | Where-Object {$_})})}
            elseif (($var -is [bool] -or $var -is [switch]) -and $Session.Config.$name -isnot [bool]) {$Session.Config.$name = Get-Yes $Session.Config.$name}
            elseif ($var -is [int] -and $Session.Config.$name -isnot [int]) {$Session.Config.$name = [int]$Session.Config.$name}
            elseif ($var -is [double] -and $Session.Config.$name -isnot [double]) {$Session.Config.$name = [double]$session.Config.$name}
        }
        $Session.Config.Algorithm = @($Session.Config.Algorithm | ForEach-Object {Get-Algorithm $_} | Where-Object {$_} | Select-Object -Unique)
        $Session.Config.ExcludeAlgorithm = @($Session.Config.ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_} | Where-Object {$_} | Select-Object -Unique)
        $Session.Config.Region = Get-Region $Session.Config.Region
        $Session.Config.DefaultPoolRegion = @($Session.Config.DefaultPoolRegion | ForEach-Object {Get-Region $_} | Where-Object {$_} | Select-Object -Unique)
        if ($WiderRegion = Get-Region2 $Session.Config.Region) {
            $Session.Config.DefaultPoolRegion = @($WiderRegion | Select-Object) + @($Session.Config.DefaultPoolRegion | Where-Object {$_ -notin $WiderRegion} | Select-Object)
        }
        $Session.Config.Currency = @($Session.Config.Currency | ForEach-Object {$_.ToUpper()} | Where-Object {$_})
        $Session.Config.UIstyle = if ($Session.Config.UIstyle -ne "full" -and $Session.Config.UIstyle -ne "lite") {"full"} else {$Session.Config.UIstyle}
        $Session.Config.PowerPriceCurrency = $Session.Config.PowerPriceCurrency | ForEach-Object {$_.ToUpper()}
        $Session.Config.MiningHeatControl = [Math]::Round([Math]::Max([Math]::Min([double]($Session.Config.MiningHeatControl -replace ",","." -replace "[^\d\.]+"),5.0),0.0),1)
        $Session.Config.PoolSwitchingHysteresis = [Math]::Max([Math]::Min([double]($Session.Config.PoolSwitchingHysteresis -replace ",","." -replace "[^\d\.\-]+"),100.0),0.0)
        $Session.Config.MinerSwitchingHysteresis = [Math]::Max([Math]::Min([double]($Session.Config.MinerSwitchingHysteresis -replace ",","." -replace "[^\d\.\-]+"),100.0),0.0)
        $Session.Config.PoolStatAverage =  Get-StatAverage $Session.Config.PoolStatAverage
        if ($Session.Config.BenchmarkInterval -lt 60) {$Session.Config.BenchmarkInterval = 60}
        if (-not $Session.Config.APIport) {$Session.Config | Add-Member APIport 4000 -Force}
        Set-ContentJson -PathToFile ".\Data\localapiport.json" -Data @{LocalAPIport = $Session.Config.APIport} > $null

        #For backwards compatibility        
        if ($Session.Config.LegacyMode -ne $null) {$Session.Config.MiningMode = if (Get-Yes $Session.Config.LegacyMode){"legacy"}else{"device"}}
        if (-not $Session.CurrentInterval) {$Session.CurrentInterval = $Session.Config.Interval}
        if ($Session.Config.MaxRejectedShareRatio -eq $null) {$Session.Config | Add-Member MaxRejectedShareRatio $Session.DefaultValues["MaxRejectedShareRatio"] -Force}
        elseif ($Session.Config.MaxRejectedShareRatio -lt 0) {$Session.Config.MaxRejectedShareRatio = 0}
        elseif ($Session.Config.MaxRejectedShareRatio -gt 1) {$Session.Config.MaxRejectedShareRatio = 1}

        #Speed up restart
        if (-not $Session.RoundCounter -and -not $Session.Config.Quickstart -and (Test-Path ".\Logs\timerpools.json") -and (Get-ChildItem ".\Logs\timerpools.json" -ErrorAction Ignore | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-3)} | Measure-Object).Count) {$Session.Config.Quickstart = $true}

        #Add some global arrays
        $Session.Config | Add-Member AlgorithmMap (Get-AlgorithmMap) -Force
        $Session.Config | Add-Member EquihashCoins (Get-EquihashCoins) -Force
        if ($Session.CurrentPowerPrice -eq $null) {$Session.CurrentPowerPrice = $Session.Config.PowerPrice}

        $Session.LogLevel = $Session.Config.LogLevel
    }

    #Start/stop services
    if ($Session.RoundCounter -eq 0) {Start-Autoexec -Priority $Session.Config.AutoexecPriority}
    if (($Session.Config.DisableAsyncLoader -or $Session.Config.Interval -ne $ConfigBackup.Interval) -and (Test-Path Variable:Global:Asyncloader)) {Stop-AsyncLoader}
    if (-not $Session.Config.DisableAsyncLoader -and -not (Test-Path Variable:Global:AsyncLoader)) {Start-AsyncLoader -Interval $Session.Config.Interval -Quickstart $Session.Config.Quickstart}
    if (-not $Session.Config.DisableMSIAmonitor -and (Test-Afterburner) -eq -1 -and ($Session.RoundCounter -eq 0 -or $Session.Config.DisableMSIAmonitor -ne $ConfigBackup.DisableMSIAmonitor)) {Start-Afterburner}
    if (-not $psISE -and ($Session.Config.DisableAPI -or $Session.Config.APIport -ne $ConfigBackup.APIport -or $Session.Config.APIauth -ne $ConfigBackup.APIauth -or $Session.Config.APIuser -ne $ConfigBackup.APIuser -or $Session.Config.APIpassword -ne $ConfigBackup.APIpassword) -and (Test-Path Variable:Global:API) -and -not $API.IsVirtual) {Stop-APIServer}
    if (-not $psISE -and -not $Session.Config.DisableAPI -and -not (Test-Path Variable:Global:API)) {Start-APIServer}
    if($psISE -or -not (Test-Path Variable:Global:API)) {
        $Global:API = [hashtable]@{}
        $API.Stop = $false
        $API.Pause = $false
        $API.Update = $false
        $API.UpdateBalance = $false
        $API.WatchdogReset = $false
        $API.LockMiners = $false
        $API.RemoteAPI = $true
        $API.ApplyOC = $false
        $API.IsVirtual = $true
        $API.APIport = $Session.Config.APIport
        $API.APIAuth = $Session.Config.APIAuth
        $API.APIport = $Session.Config.APIport
        $API.APIUser = $Session.Config.APIUser
        $API.APIPassword = $Session.Config.APIPassword
        $API.MachineName = $Session.MachineName
    }

    if ($CheckConfig) {Update-WatchdogLevels -Reset}

    #Versioncheck
    $ConfirmedVersion = Confirm-Version $Session.Version
    $API.Version = $ConfirmedVersion
    $Session.AutoUpdate = $false
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version -and $Session.Config.EnableAutoUpdate -and -not $Session.IsExclusiveRun) {
        if (Test-Path ".\Logs\autoupdate.txt") {try {$Last_Autoupdate = Get-ContentByStreamReader ".\Logs\autoupdate.txt" | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)};$Last_Autoupdate = $null}}
        if (-not $Last_Autoupdate -or $ConfirmedVersion.RemoteVersion -ne (Get-Version $Last_Autoupdate.RemoteVersion) -or $ConfirmedVersion.Version -ne (Get-Version $Last_Autoupdate.Version)) {
            $Last_Autoupdate = [PSCustomObject]@{
                                    RemoteVersion = $ConfirmedVersion.RemoteVersion.ToString()
                                    Version = $ConfirmedVersion.Version.ToString()
                                    Timestamp = (Get-Date).ToUniversalTime().ToString()
                                    Attempts = 0
                                }
        }
        if ($Last_Autoupdate.Attempts -lt 3) {
            $Last_Autoupdate.Timestamp = (Get-Date).ToUniversalTime().ToString()
            $Last_Autoupdate.Attempts++
            Set-ContentJson -PathToFile ".\Logs\autoupdate.txt" -Data $Last_Autoupdate > $null
            $Session.AutoUpdate = $true
        }
    }

    $MSIAenabled = $IsWindows -and -not $Session.Config.EnableOCProfiles -and $Session.Config.MSIAprofile -gt 0 -and (Test-Path $Session.Config.MSIApath)
    $Session.OCmode = if ($MSIAenabled) {"msia"} elseif ($Session.Config.EnableOCProfiles) {"ocp"} else {"off"}

    if ($CheckConfig) {
        $API.Info = [PSCustomObject]@{
                                Version                = $ConfirmedVersion.Version
                                RemoteVersion          = $ConfirmedVersion.RemoteVersion
                                ManualURI              = $ConfirmedVersion.ManualURI
                                WorkerName             = $Session.Config.WorkerName
                                EnableAlgorithmMapping = $Session.Config.EnableAlgorithmMapping
                                AlgorithmMap           = $Session.Config.AlgorithmMap
                                OCmode                 = $Session.OCmode
                                UsePowerPrice          = $Session.Config.UsePowerPrice
                                PowerPriceCurrency     = $Session.Config.PowerPriceCurrency
                                DecSep                 = (Get-Culture).NumberFormat.NumberDecimalSeparator
                            }
    }
    if ($Session.RoundCounter -eq 0 -and $Session.Config.StartPaused) {$Session.PauseMiners = $API.Pause = $true}

    #Check for algorithms config
    if (Set-ConfigDefault "Algorithms") {
        if ($CheckConfig -or -not $Session.Config.Algorithms -or (Test-Config "Algorithms" -LastWriteTime) -or ($ConfigBackup.Algorithms -and (Compare-Object $Session.Config.Algorithms $ConfigBackup.Algorithms | Measure-Object).Count)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating algorithms config data"}
            $AllAlgorithms = Get-ConfigContent "Algorithms" -UpdateLastWriteTime
            if (Test-Config "Algorithms" -Health) {
                $Session.Config | Add-Member Algorithms ([PSCustomObject]@{}) -Force
                $AllAlgorithms.PSObject.Properties.Name | Where-Object {-not $Session.Config.Algorithm.Count -or $Session.Config.Algorithm -icontains $_} | Foreach-Object {
                    $Session.Config.Algorithms | Add-Member $_ $AllAlgorithms.$_ -Force
                    $Session.Config.Algorithms.$_ | Add-Member Penalty ([Math]::Round([double]($Session.Config.Algorithms.$_.Penalty -replace "[^\d\.\-]+"),2)) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MinHashrate (ConvertFrom-Hash $Session.Config.Algorithms.$_.MinHashrate) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MinWorkers (ConvertFrom-Hash $Session.Config.Algorithms.$_.MinWorkers) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MaxTimeToFind (ConvertFrom-Time $Session.Config.Algorithms.$_.MaxTimeToFind) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MSIAprofile ([int]$Session.Config.Algorithms.$_.MSIAprofile) -Force
                }
            }
            if ($AllAlgorithms -ne $null) {Remove-Variable "AllAlgorithms"}
        }
    }

    #Check for coins config
    $CheckCoins = $false
    if (Set-ConfigDefault "Coins") {
        if ($CheckConfig -or -not $Session.Config.Coins -or (Test-Config "Coins" -LastWriteTime) -or ($ConfigBackup.Coins -and (Compare-Object $Session.Config.Coins $ConfigBackup.Coins | Measure-Object).Count)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating coins config data"}
            $AllCoins = Get-ConfigContent "Coins" -UpdateLastWriteTime
            if (Test-Config "Coins" -Health) {
                $Session.Config | Add-Member Coins ([PSCustomObject]@{})  -Force
                $AllCoins.PSObject.Properties.Name | Select-Object | Foreach-Object {
                    $Session.Config.Coins | Add-Member $_ $AllCoins.$_ -Force
                    $Session.Config.Coins.$_ | Add-Member Penalty ([Math]::Round([double]($Session.Config.Coins.$_.Penalty -replace "[^\d\.\-]+"),2)) -Force
                    $Session.Config.Coins.$_ | Add-Member MinHashrate (ConvertFrom-Hash $Session.Config.Coins.$_.MinHashrate) -Force
                    $Session.Config.Coins.$_ | Add-Member MinWorkers (ConvertFrom-Hash $Session.Config.Coins.$_.MinWorkers) -Force
                    $Session.Config.Coins.$_ | Add-Member MaxTimeToFind (ConvertFrom-Time $Session.Config.Coins.$_.MaxTimeToFind) -Force
                    $Session.Config.Coins.$_ | Add-Member Wallet ($Session.Config.Coins.$_.Wallet -replace "\s+") -Force
                    $Session.Config.Coins.$_ | Add-Member EnableAutoPool (Get-Yes $Session.Config.Coins.$_.EnableAutoPool) -Force
                    $Session.Config.Coins.$_ | Add-Member PostBlockMining (ConvertFrom-Time $Session.Config.Coins.$_.PostBlockMining) -Force
                    $Session.Config.Coins.$_ | Add-Member MinProfitPercent ([double]($Session.Config.Coins.$_.MinProfitPercent -replace "[^\d\.]+")) -Force
                }
                $CheckCoins = $true
            }
            if ($AllCoins -ne $null) {Remove-Variable "AllCoins"}
        }
    }

    #Check for oc profile config
    if (Set-ConfigDefault "OCProfiles") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.OCProfiles -or (Test-Config "OCProfiles" -LastWriteTime))) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating ocprofiles config data"}
            $AllOCProfiles = Get-ConfigContent "OCProfiles" -UpdateLastWriteTime
            if (Test-Config "OCProfiles" -Health) {
                $Session.Config | Add-Member OCProfiles $AllOCProfiles -Force
            }
            if ($AllOCProfiles -ne $null) {Remove-Variable "AllOCProfiles"}
        }
    }

    #Check for powerprice config
    if (Set-ConfigDefault "Scheduler") {
        if ($CheckConfig -or $Session.Config.Scheduler -eq $null -or (Test-Config "Scheduler" -LastWriteTime)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating scheduler config data"}
            $AllScheduler = Get-ConfigContent "Scheduler" -UpdateLastWriteTime
            if (Test-Config "Scheduler" -Health) {
                if ($AllScheduler -isnot [array] -and $AllScheduler.value -ne $null) {$AllScheduler = $AllScheduler.value}
                $Session.Config | Add-Member Scheduler ([System.Collections.ArrayList]@()) -Force
                $AllScheduler | Foreach-Object {
                    $_ | Add-Member Name "$($_.Name)" -Force
                    $_ | Add-Member DayOfWeek $([string]("$($_.DayOfWeek -replace "[^0-6\*]+")"[0])) -Force
                    $_ | Add-Member From $(Get-HourMinStr $_.From) -Force
                    $_ | Add-Member To   $(Get-HourMinStr $_.To -to) -Force
                    $_ | Add-Member PowerPrice $($_.PowerPrice -replace ",","." -replace "[^0-9\.]+") -Force
                    $_ | Add-Member Enable $(Get-Yes $_.Enable) -Force
                    $_ | Add-Member Pause  $(Get-Yes $_.Pause)  -Force
                    $_ | Add-Member EnableMiningHeatControl $(if ($_.EnableMiningHeatControl -eq "") {$Session.Config.EnableMiningHeatControl} else {Get-Yes $_.EnableMiningHeatControl}) -Force
                    $_ | Add-Member MiningHeatControl "$($_.MiningHeatControl -replace ",","." -replace "[^0-9\.]+")" -Force
                    $PowerPrice = if ($_.PowerPrice -eq "") {$Session.Config.PowerPrice} else {$_.PowerPrice}
                    try {$PowerPrice = [Double]$PowerPrice} catch {if ($Error.Count){$Error.RemoveAt(0)};$PowerPrice = $Session.Config.PowerPrice}
                    $_.PowerPrice = $PowerPrice
                    $MiningHeatControl = if ($_.MiningHeatControl -eq "") {$Session.Config.MiningHeatControl} else {$_.MiningHeatControl}
                    try {$MiningHeatControl = [Double]$MiningHeatControl} catch {if ($Error.Count){$Error.RemoveAt(0)};$MiningHeatControl = $Session.Config.MiningHeatControl}
                    $MiningHeatControl = [Math]::Round([Math]::Max([Math]::Min($MiningHeatControl,5.0),0.0),1)
                    $_.MiningHeatControl = $MiningHeatControl
                    $Session.Config.Scheduler.Add($_) > $null
                }
            }
            if ($AllScheduler -ne $null) {Remove-Variable "AllScheduler"}
        }
    }

    #Check for devices config
    if (Set-ConfigDefault "Devices") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.Devices -or (Test-Config "Devices" -LastWriteTime))) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating devices config data"}
            $AllDevices = Get-ConfigContent "Devices" -UpdateLastWriteTime
            if (Test-Config "Devices" -Health) {
                $Session.Config | Add-Member Devices $AllDevices -Force
                $OCprofileFirst = $Session.Config.OCProfiles.PSObject.Properties.Name | Foreach-Object {$_ -replace "-.+$"} | Select-Object -Unique -First 1
                foreach ($p in @($Session.Config.Devices.PSObject.Properties.Name)) {
                    foreach ($q in @("Algorithm","MinerName","ExcludeAlgorithm","ExcludeMinerName")) {
                        if ($Session.Config.Devices.$p.$q -is [string]){$Session.Config.Devices.$p.$q = if ($Session.Config.Devices.$p.$q.Trim() -eq ""){@()}else{[regex]::split($Session.Config.Devices.$p.$q.Trim(),"\s*[,;]+\s*")}}
                    }
                    $Session.Config.Devices.$p | Add-Member Algorithm @(($Session.Config.Devices.$p.Algorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                    $Session.Config.Devices.$p | Add-Member ExcludeAlgorithm @(($Session.Config.Devices.$p.ExcludeAlgorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                    $Session.Config.Devices.$p | Add-Member DisableDualMining ($Session.Config.Devices.$p.DisableDualMining -and (Get-Yes $Session.Config.Devices.$p.DisableDualMining)) -Force
                    if ($p -ne "CPU" -and -not $Session.Config.Devices.$p.DefaultOCprofile) {
                        $Session.Config.Devices.$p | Add-Member DefaultOCprofile $OCprofileFirst -Force
                        if ($Session.Config.EnableOCprofiles) {
                            Write-Log -Level Warn "No default overclocking profile defined for `"$p`" in $($Session.ConfigFiles["OCProfiles"].Path). Using `"$OCprofileFirst`" for now!"
                        }
                    }
                    $Session.Config.Devices.$p | Add-Member PowerAdjust ([double]($Session.Config.Devices.$p.PowerAdjust -replace "[^0-9`.]+")) -Force
                }
            }
            if ($AllDevices -ne $null) {Remove-Variable "AllDevices"}
        }
    }

    #Check for gpugroups config
    if (Set-ConfigDefault "GpuGroups") {
        if ($CheckConfig -or -not $Session.Config.GpuGroups -or (Test-Config "GpuGroups" -LastWriteTime) -or ($ConfigBackup.GpuGroups -and (Compare-Object $Session.Config.GpuGroups $ConfigBackup.GpuGroups | Measure-Object).Count)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating gpugroups config data"}
            $AllGpuGroups = Get-ConfigContent "GpuGroups" -UpdateLastWriteTime
            if (Test-Config "GpuGroups" -Health) {
                $Session.Config | Add-Member GpuGroups ([PSCustomObject]@{})  -Force
                $AllGpuGroups.PSObject.Properties.Name | Select-Object | Foreach-Object {
                    $Session.Config.GpuGroups | Add-Member $_ $AllGpuGroups.$_ -Force
                    $CheckGpuGroups = $true
                }
            }
            if ($AllGpuGroups -ne $null) {Remove-Variable "AllGpuGroups"}
        }
    }

    #Check for combos config
    if (Set-ConfigDefault "Combos") {
        if ($CheckGpuGroups -or -not $Session.Config.Combos -or (Test-Config "Combos" -LastWriteTime) -or ($ConfigBackup.Combos -and (Compare-Object $Session.Config.Combos $ConfigBackup.Combos | Measure-Object).Count)) {
            $AllCombos = Get-ConfigContent "Combos" -UpdateLastWriteTime
            if (Test-Config "Combos" -Health) {
                $Session.Config | Add-Member Combos ([PSCustomObject]@{})  -Force
                $AllCombos.PSObject.Properties.Name | Select-Object | Foreach-Object {
                    $SubsetType = $_
                    $Session.Config.Combos | Add-Member $_ ([PSCustomObject]@{}) -Force
                    $AllCombos.$SubsetType.PSObject.Properties.Name | Select-Object | Foreach-Object {
                         $Session.Config.Combos.$SubsetType | Add-Member $_ (Get-Yes $AllCombos.$SubsetType.$_) -Force
                    }
                    $CheckCombos = $true
                }
            }
            if ($AllCombos -ne $null) {Remove-Variable "AllCombos"}
        }
    }

    #Check for pool config
    if (Set-ConfigDefault "Pools") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or $CheckCoins -or -not $Session.Config.Pools -or (Test-Config "Pools" -LastWriteTime))) {
            $PoolParams = @{
                Wallet              = $Session.Config.Wallet
                UserName            = $Session.Config.UserName
                WorkerName          = $Session.Config.WorkerName
                API_ID              = $Session.Config.API_ID
                API_Key             = $Session.Config.API_Key
            }
            $Session.Config.Coins.PSObject.Properties | Where-Object {$_.Value.Wallet -and -not $PoolParams.ContainsKey($_.Name)} | Foreach-Object {$PoolParams[$_.Name] = $_.Value.Wallet}
            $AllPoolsConfig = Get-ConfigContent "Pools" -Parameters $PoolParams -UpdateLastWriteTime
            if (Test-Config "Pools" -Health) {
                $Session.Config | Add-Member Pools $AllPoolsConfig -Force
                $CheckPools = $true
            }
            if ($AllPoolsConfig -ne $null) {Remove-Variable "AllPoolsConfig"}
        }
    }

    $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_} | ForEach-Object {
        Write-Log -Level Info "Alas! Missing pool $_ will be added to config manually"
        $Session.Config.Pools | Add-Member $_ (
            [PSCustomObject]@{
                BTC     = $Session.Config.Wallet
                User    = $Session.Config.UserName
                Worker  = $Session.Config.WorkerName
                API_ID  = $Session.Config.API_ID
                API_Key = $Session.Config.API_Key
            }
        )
        $CheckPools = $true
    }

    if ($CheckPools) {
        if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating pools config data"}
        foreach ($p in @($Session.Config.Pools.PSObject.Properties.Name)) {
            foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","CoinSymbolPBM","ExcludeCoinSymbol","MinerName","ExcludeMinerName","FocusWallet")) {
                if ($Session.Config.Pools.$p.$q -is [string]) {$Session.Config.Pools.$p.$q = @($Session.Config.Pools.$p.$q -replace "[^A-Z0-9,;]+" -split "[,;]+" | Where-Object {$_} | Select-Object)}
                if ($q -eq "FocusWallet" -and $Session.Config.Pools.$p.$q.Count) {
                    $Session.Config.Pools.$p.$q = @(Compare-Object $Session.Config.Pools.$p.$q $Session.Config.Pools.$p.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject -Unique)
                }
                $Session.Config.Pools.$p | Add-Member $q @(($Session.Config.Pools.$p.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
            }

            $Session.Config.Pools.$p.PSObject.Properties | Where-Object {$_.Name -match "^(Allow|Enable)" -and $_.Value -isnot [bool]} | Foreach-Object {
                $AddEnable = $_
                $Session.Config.Pools.$p | Add-Member $AddEnable.Name (Get-Yes $AddEnable.Value) -Force
            }

            if ($Session.Config.Pools.$p.EnableAutoCoin) {
                $Session.Config.Coins.PSObject.Properties | Where-Object {$_.Value.EnableAutoPool -and $_.Value.Wallet} | Sort-Object Name | Foreach-Object {
                    if (-not $Session.Config.Pools.$p."$($_.Name)") {$Session.Config.Pools.$p | Add-Member $_.Name $_.Value.Wallet -Force}
                }
            }
            $cparams = [PSCustomObject]@{}
            $Session.Config.Pools.$p.PSObject.Properties.Name | Where-Object {$_ -notmatch "^#" -and $_ -match "^(.+)-Params$"} | Foreach-Object {$cparams | Add-Member $Matches[1] $Session.Config.Pools.$p.$_ -Force}
            $Session.Config.Pools.$p | Add-Member Wallets $(Get-PoolPayoutCurrencies $Session.Config.Pools.$p) -Force
            $Session.Config.Pools.$p | Add-Member Params $cparams -Force
            $Session.Config.Pools.$p | Add-Member DataWindow (Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow) -Force
            $Session.Config.Pools.$p | Add-Member Penalty ([Math]::Round([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+"),2)) -Force
            $Session.Config.Pools.$p | Add-Member MaxMarginOfError ([Math]::Round([double]($Session.Config.Pools.$p.MaxMarginOfError -replace "[^\d\.\-]+"),2)) -Force
            $Pool_SwHyst = $Session.Config.Pools.$p.SwitchingHysteresis -replace "[^\d\.\-]+"
            $Session.Config.Pools.$p | Add-Member SwitchingHysteresis $(if ("$Pool_SwHyst") {[Math]::Max([Math]::Min([double]$Pool_SwHyst,100.0),0.0)} else {$null}) -Force
            $Session.Config.Pools.$p | Add-Member StatAverage (Get-StatAverage $Session.Config.Pools.$p.StatAverage -Default $Session.Config.PoolStatAverage) -Force
        }
    }

    #Get PowerPrice and Scheduler events
    $Session.PauseMinersByScheduler = $false
    $PowerPrice              = [Double]$Session.Config.PowerPrice
    $EnableMiningHeatControl = $Session.Config.EnableMiningHeatControl
    $MiningHeatControl       = $Session.Config.MiningHeatControl
    $TimeOfDay = (Get-Date).TimeOfDay.ToString("hh\:mm")
    $DayOfWeek = "$([int](Get-Date).DayOfWeek)"
    $Session.Config.Scheduler | Where-Object {$_.Enable -and $_.DayOfWeek -eq "*" -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To} | Foreach-Object {$PowerPrice = [Double]$_.PowerPrice;$EnableMiningHeatControl = $_.EnableMiningHeatControl;$MiningHeatControl = $_.MiningHeatControl;$Session.PauseMinersByScheduler = $_.Pause -and -not $Session.IsExclusiveRun}
    $Session.Config.Scheduler | Where-Object {$_.Enable -and $_.DayOfWeek -match "^\d$" -and $DayOfWeek -eq $_.DayOfWeek -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To} | Foreach-Object {$PowerPrice = [Double]$_.PowerPrice;$EnableMiningHeatControl = $_.EnableMiningHeatControl;$MiningHeatControl = $_.MiningHeatControl;$Session.PauseMinersByScheduler = $_.Pause -and -not $Session.IsExclusiveRun}

    $Session.CurrentPowerPrice              = $PowerPrice
    $Session.CurrentEnableMiningHeatControl = $EnableMiningHeatControl
    $Session.CurrentMiningHeatControl       = $MiningHeatControl

    $API.CurrentPowerPrice                  = $Session.CurrentPowerPrice
    $API.CurrentEnableMiningHeatControl     = $Session.CurrentEnableMiningHeatControl
    $API.CurrentMiningHeatControl           = $Session.CurrentMiningHeatControl

    #Activate or deactivate donation  
    $DonateMinutes = if ($Session.Config.Donate -lt 10) {10} else {$Session.Config.Donate}
    $DonateDelayHours = 24
    if ($DonateMinutes -gt 15) {
        $DonateMinutes /= 2
        $DonateDelayHours /= 2
    }
    if (-not $Session.LastDonated -or $Session.PauseMiners -or $Session.PauseMinersByScheduler) {
        if (-not $Session.LastDonated) {$Session.LastDonated = Get-LastDrun}
        $ShiftDonationRun = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)
        if (-not $Session.LastDonated -or $Session.LastDonated -lt $ShiftDonationRun -or $Session.PauseMiners -or $Session.PauseMinersByScheduler) {$Session.LastDonated = Set-LastDrun $ShiftDonationRun}
    }
    if ($Session.Timer.AddHours(-$DonateDelayHours) -ge $Session.LastDonated.AddSeconds(59)) {
        $Session.IsDonationRun = $false
        $Session.LastDonated = Set-LastDrun $Session.Timer
        $Session.Config = $Session.UserConfig | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $Session.UserConfig = $null
        $Script:AllPools = $null
        Write-Log "Donation run finished. "
    }
    if ($Session.Timer.AddHours(-$DonateDelayHours).AddMinutes($DonateMinutes) -ge $Session.LastDonated -and $Session.AvailPools.Count -gt 0) {
        if (-not $Session.IsDonationRun -or $CheckConfig) {
            try {$DonationData = Invoke-GetUrl "https://rbminer.net/api/dconf.php";Set-ContentJson -PathToFile ".\Data\dconf.json" -Data $DonationData -Compress > $null} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Rbminer.net/api/dconf.php could not be reached"}
            if (-not $DonationData -or -not $DonationData.Wallets) {try {$DonationData = Get-ContentByStreamReader ".\Data\dconf.json" | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
            if (-not $DonationData -or -not $DonationData.Wallets) {$DonationData = '{"Probability":100,"Wallets":{"2Miners":{"XZC":"aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM","Worker":"mpx","DataWindow":"estimate_current","Penalty":18},"Blockcruncher":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"BlockMasters":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","DataWindow":"estimate_current","Penalty":50},"Bsod":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"CryptoKnight":{"XWP":"fi371vX9nG9fUFD4DEGHMC8axwSBbUhy8Eqr7r1zYbVUcYLaEdgeqeLj24DYzoQb26TodLoEoa484TqP1VtwTzrP3CtitfoXhVM1JCH8RPby","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"EthashPool":{"ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Ethermine":{"ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"F2Pool":{"XZC":"aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM","ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"FairPool":{"WOW":"So2ifgjqGMZJhCrqpFMotQQAiJAiATuJLNAK2HrPLoNzK8hkqNbf9t8gmx6bzAQrXRMnWnoELoiD6GTv8guPBRwH5yoTVNomwVR2oNYDPRua","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"HeroMiners":{"XWP":"fi371vX9nG9fUFD4DEGHMC8axwSBbUhy8Eqr7r1zYbVUcYLaEdgeqeLj24DYzoQb26TodLoEoa484TqP1VtwTzrP3CtitfoXhVM1JCH8RPby","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Icemining":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Luckypool":{"XWP":"fi371vX9nG9fUFD4DEGHMC8axwSBbUhy8Eqr7r1zYbVUcYLaEdgeqeLj24DYzoQb26TodLoEoa484TqP1VtwTzrP3CtitfoXhVM1JCH8RPby","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Mintpond":{"XZC":"aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM","Worker":"mpx","DataWindow":"estimate_current","Penalty":18},"Nanopool":{"ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"NiceHash":{"BTC":"3PfUUT1Tknfyd4SnYrEwwpUEAQEzWd2BuD","Worker":"mpx","DataWindow":"estimate_current","Penalty":0,"Platform":"v2","MaximumMarginOfError":"0"},"NiceHashV2":{"BTC":"3PfUUT1Tknfyd4SnYrEwwpUEAQEzWd2BuD","Worker":"mpx","DataWindow":"estimate_current","Penalty":0,"MaximumMarginOfError":"0"},"PocketWhale":{"XWP":"fi371vX9nG9fUFD4DEGHMC8axwSBbUhy8Eqr7r1zYbVUcYLaEdgeqeLj24DYzoQb26TodLoEoa484TqP1VtwTzrP3CtitfoXhVM1JCH8RPby","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Ravenminer":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"RavenminerEu":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"SparkPool":{"CKB":"sp_rbm","Algorithm":"Eaglesong","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Uupool":{"VOLLAR":"VcSq7vHRb9ymPj1jbeHNfX2fdVTJK75xndX","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"MiningPoolHub":{"Worker":"mpx","User":"rbm","API_ID":"422496","API_Key":"ef4f18b4f48d5964c5f426b90424d088c156ce0cd0aa0b9884893cabf6be350e","DataWindow":"estimate_current","Penalty":12,"Algorithm":["monero","skein","myriadgroestl"]},"MiningPoolHubCoins":{"Worker":"mpx","User":"rbm","API_ID":"422496","API_Key":"ef4f18b4f48d5964c5f426b90424d088c156ce0cd0aa0b9884893cabf6be350e","DataWindow":"estimate_current","Penalty":12,"Algorithm":["monero","skein","myriadgroestl"]},"ZergPool":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","DataWindow":"estimate_current","Penalty":12},"ZergPoolCoins":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","DataWindow":"estimate_current","Penalty":12,"CoinSymbol":"CPU,DMS,MBC,RITO,SAFE,XMG"},"ZergPoolSolo":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","DataWindow":"estimate_current","Penalty":12,"Algorithm":"m7m"},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","User":"rbm","DataWindow":"estimate_current","Penalty":16}},"Pools":["HeroMiners","Nicehash","SparkPool","ZergPoolCoins"],"Algorithm":[],"ExcludeMinerName":["GrinGoldMiner","GrinProMiner","SwapMiner"]}' | ConvertFrom-Json}
            if (-not $Session.IsDonationRun) {Write-Log "Donation run started for the next $(($Session.LastDonated-($Session.Timer.AddHours(-$DonateDelayHours))).Minutes +1) minutes. "}
            $Session.UserConfig = $Session.Config | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $Session.IsDonationRun = $true            
            $Session.AvailPools | ForEach-Object {
                $DonationData1 = if (Get-Member -InputObject ($DonationData.Wallets) -Name $_ -MemberType NoteProperty) {$DonationData.Wallets.$_} else {$DonationData.Wallets.Default};
                $Session.Config.Pools | Add-Member $_ $DonationData1 -Force
            }
            #$Session.ConfigFiles["Config"].LastWriteTime = 0
            $DonationPoolsAvail = Compare-Object @($DonationData.Pools) @($Session.AvailPools) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject
            $DonationAlgorithm = @($DonationData.Algorithm | ForEach-Object {Get-Algorithm $_} | Select-Object)
            if ($Session.UserConfig.Algorithm.Count -gt 0 -and $DonationAlgorithm.Count -gt 0) {$Session.Config | Add-Member Algorithm @(@($Session.UserConfig.Algorithm | Select-Object) + @($DonationAlgorithm) | Sort-Object -Unique)  -Force}
            if ($Session.UserConfig.ExcludeAlgorithm.Count -gt 0) {$Session.Config | Add-Member ExcludeAlgorithm @(Compare-Object @($Session.UserConfig.ExcludeAlgorithm | Select-Object) @($DonationAlgorithm) | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject | Sort-Object -Unique) -Force}
            $Session.Config | Add-Member ExcludeCoin @() -Force
            $Session.Config | Add-Member ExcludeCoinSymbol @() -Force        
            if (-not $DonationPoolsAvail.Count) {
                $Session.Config | Add-Member ExcludePoolName @() -Force
            } else {
                $Session.Config | Add-Member PoolName $DonationPoolsAvail -Force
                $Session.Config | Add-Member ExcludePoolName @(Compare-Object @($Session.AvailPools) @($DonationPoolsAvail) | Select-Object -ExpandProperty InputObject) -Force
            }
            foreach ($p in @($Session.Config.Pools.PSObject.Properties.Name)) {
                foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","CoinSymbolPBM","ExcludeCoinSymbol","MinerName","ExcludeMinerName","FocusWallet")) {
                    if ($Session.Config.Pools.$p.$q -is [string]) {$Session.Config.Pools.$p.$q = @($Session.Config.Pools.$p.$q -replace "[^A-Z0-9,;]+" -split "[,;]+" | Where-Object {$_} | Select-Object)}
                    $Session.Config.Pools.$p | Add-Member $q @(($Session.Config.Pools.$p.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
                }
                $c = Get-PoolPayoutCurrencies $Session.Config.Pools.$p
                $cparams = [PSCustomObject]@{}
                $c.PSObject.Properties.Name | Where-Object {$Session.Config.Pools.$p."$($_)-Params"} | Foreach-Object {$cparams | Add-Member $_ $Session.Config.Pools.$p."$($_)-Params" -Force}
                $Session.Config.Pools.$p | Add-Member Wallets $c -Force
                $Session.Config.Pools.$p | Add-Member Params $cparams -Force
                $Session.Config.Pools.$p | Add-Member DataWindow (Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow) -Force
                $Session.Config.Pools.$p | Add-Member Penalty ([Math]::Round([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+"),2)) -Force
                $Session.Config.Pools.$p | Add-Member MaxMarginOfError $(if ($Session.Config.Pools.$p.MaxMarginOfError -eq $null) {if ($p -eq "NiceHash") {[double]0} else {[double]100}} else {[Math]::Round([double]($Session.Config.Pools.$p.MaxMarginOfError -replace "[^\d\.\-]+"),2)}) -Force
            }
            if ($DonationData.ExcludeMinerName) {
                $Session.Config | Add-Member ExcludeMinerName @($Session.Config.ExcludeMinerName + (Compare-Object $DonationData.ExcludeMinerName $Session.Config.MinerName | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) | Select-Object -Unique) -Force
            }
            $Session.Config | Add-Member DisableExtendInterval $true -Force
            $Script:AllPools = $null
        }
    } else {
        Write-Log ("Next donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($Session.LastDonated.AddHours($DonateDelayHours) - ($Session.Timer.AddMinutes($DonateMinutes))))
    }

    #Clear pool cache if the pool configuration has changed
    if ($Script:AllPools -ne $null -and (($ConfigBackup.Pools | ConvertTo-Json -Compress -Depth 10) -ne ($Session.Config.Pools | ConvertTo-Json -Compress -Depth 10) -or (Compare-Object @($ConfigBackup.PoolName) @($Session.Config.PoolName)) -or (Compare-Object @($ConfigBackup.ExcludePoolName) @($Session.Config.ExcludePoolName)))) {
        Write-Log -Level Info "Resetting AllPools data store"
        $Script:AllPools = $null
    }

    #load device(s) information and device combos
    if ($CheckConfig -or $CheckCombos -or $ConfigBackup.MiningMode -ne $Session.Config.MiningMode -or (Compare-Object $Session.Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0 -or (Compare-Object $Session.Config.ExcludeDeviceName $ConfigBackup.ExcludeDeviceName | Measure-Object).Count -gt 0) {
        if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Device configuration changed. Refreshing now."}

        #Load information about the devices
        $Session.Devices = @()
        if (($Session.Config.DeviceName | Measure-Object).Count) {$Session.Devices = @(Get-Device $Session.Config.DeviceName $Session.Config.ExcludeDeviceName | Select-Object)}
        $Session.DevicesByTypes = [PSCustomObject]@{
            NVIDIA = @($Session.Devices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "NVIDIA"} | Select-Object)
            AMD    = @($Session.Devices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "AMD"} | Select-Object)
            CPU    = @($Session.Devices | Where-Object Type -eq "CPU" | Select-Object)
            Combos = [PSCustomObject]@{}
            FullComboModels = [PSCustomObject]@{}
        }
        [hashtable]$Session.DevicesToVendors = @{}

        $Session.Config | Add-Member DeviceModel @($Session.Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object) -Force
        $Session.Config | Add-Member CUDAVersion $(if (($Session.DevicesByTypes.NVIDIA | Select-Object -First 1).OpenCL.PlatformVersion -match "CUDA\s+([\d\.]+)") {$Matches[1]}else{$false}) -Force
        $Session.Config | Add-Member DotNETRuntimeVersion $(try {[String]$(if ($cmd = (Get-Command dotnet -ErrorAction Ignore)) {(dir $cmd.Path.Replace('dotnet.exe', 'shared/Microsoft.NETCore.App')).Name | Where-Object {$_ -match "^([\d\.]+)$"} | Foreach-Object {Get-Version $_} | Sort-Object | Select-Object -Last 1})} catch {if ($Error.Count){$Error.RemoveAt(0)}}) -Force

        if ($IsLinux -and $Session.DevicesByTypes.NVIDIA -and $Session.Config.EnableOCProfiles) {
            Invoke-NvidiaSmi -Arguments "-pm 1" -Runas > $null
            Invoke-NvidiaSmi -Arguments "--gom=COMPUTE" -Runas > $null
            if (Test-OCDaemon) {Set-OCDaemon "sleep 1"} else {Start-Sleep 1}
            Invoke-NvidiaSettings -SetPowerMizer
            Invoke-OCDaemon -Quiet
        }

        #Create combos
        @($Session.DevicesByTypes.PSObject.Properties.Name) | Where {@("Combos","FullComboModels") -inotcontains $_} | Foreach-Object {
            $SubsetType = [String]$_
            $Session.DevicesByTypes.Combos | Add-Member $SubsetType @() -Force
            $Session.DevicesByTypes.FullComboModels | Add-Member $SubsetType $(@($Session.DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique | Sort-Object) -join '-') -Force
            $Session.DevicesByTypes.FullComboModels.$SubsetType | Where-Object {$_ -match '-' -and $Session.Config.Combos.$SubsetType.$_ -ne $null} | Foreach-Object {
                # always force enable full combos
                $Session.Config.Combos.$SubsetType | Add-Member $_ $true -Force
            }
            Get-DeviceSubSets @($Session.DevicesByTypes.$SubsetType) | Where-Object {$Session.Config.Combos.$SubsetType."$($_.Model -join '-')"} | Foreach-Object {                       
                $SubsetModel= $_
                $Session.DevicesByTypes.Combos.$SubsetType += @($Session.DevicesByTypes.$SubsetType | Where-Object {$SubsetModel.Model -icontains $_.Model} | Foreach-Object {$SubsetNew = $_.PSObject.Copy();$SubsetNew.Model = $($SubsetModel.Model -join '-');$SubsetNew.Model_Name = $($SubsetModel.Model_Name -join '+');$SubsetNew})
            }
            if ($Session.DevicesByTypes.$SubsetType) {
                @($Session.DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique) + @($Session.DevicesByTypes.Combos.$SubsetType | Select-Object -ExpandProperty Model) | Where-Object {$_} | Foreach-Object {$Session.DevicesToVendors[$_] = $SubsetType}
            }
        }

        if ($Session.Config.MiningMode -eq "legacy") {
            @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {
                $Device_LegacyModel = $_
                if ($Session.DevicesByTypes.FullComboModels.$Device_LegacyModel -match '-') {
                    $Session.DevicesByTypes.$Device_LegacyModel = $Session.DevicesByTypes.Combos.$Device_LegacyModel | Where-Object Model -eq $Session.DevicesByTypes.FullComboModels.$Device_LegacyModel
                }
            }
        } elseif ($Session.Config.MiningMode -eq "combo") {
            #add combos to DevicesbyTypes
            @("NVIDIA","AMD","CPU") | Foreach-Object {$Session.DevicesByTypes.$_ += $Session.DevicesByTypes.Combos.$_}
        }

        [hashtable]$Session.DeviceNames = @{}
        @("NVIDIA","AMD","CPU") | Foreach-Object {
            $Session.DevicesByTypes.$_ | Group-Object Model | Foreach-Object {$Session.DeviceNames[$_.Name] = @($_.Group | Select-Object -ExpandProperty Name | Sort-Object)}
        }

        $Session.DeviceCombos = @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {$Session.DevicesByTypes.$_ | Select-Object -ExpandProperty Model -Unique} | Sort-Object

        $API.DeviceCombos     = $Session.DeviceCombos
        $API.DevicesToVendors = $Session.DevicesToVendors

        #Update device information for the first time
        Update-DeviceInformation @($Session.Devices.Name | Select-Object -Unique) -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    }
    
    if ($ConfigBackup -ne $null) {Remove-Variable "ConfigBackup"}

    $Session.ConfigFullComboModelNames = @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name)

    if (-not $Session.Devices) {
        $Session.PauseMiners = $API.Pause = $true
    }

    $API.AllDevices = $Session.AllDevices
    $API.Devices    = $Session.Devices

    #Check for miner config
    if (Set-ConfigDefault "Miners") {
        if ($CheckConfig -or -not $Session.Config.Miners -or (Test-Config "Miners" -LastWriteTime)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating miners config data"}
            $AllMiners = Get-ConfigContent "Miners" -UpdateLastWriteTime
            if (Test-Config "Miners" -Health) {
                $Session.Config | Add-Member Miners ([PSCustomObject]@{}) -Force
                foreach ($CcMiner in @($AllMiners.PSObject.Properties)) {
                    $CcMinerName = $CcMiner.Name
                    [String[]]$CcMinerName_Array = @($CcMinerName -split '-')
                    if ($CcMinerName_Array.Count -gt 1 -and ($Session.ConfigFullComboModelNames -icontains $CcMinerName_Array[1]) -and ($Session.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")) {$CcMinerName = "$($CcMinerName_Array[0])-$($Session.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")";$CcMinerName_Array = @($CcMinerName -split '-')}                
                    $CcMinerOk = $true
                    for($i=1;($i -lt $CcMinerName_Array.Count) -and $CcMinerOk;$i++) {if ($Session.Config.DeviceModel -inotcontains $CcMinerName_Array[$i]) {$CcMinerOk=$false}}
                    if ($CcMinerOk) {
                        foreach($p in @($CcMiner.Value)) {
                            $p | Add-Member Disable $(Get-Yes $p.Disable) -Force
                            if ($(foreach($q in $p.PSObject.Properties.Name) {if (($q -ne "MainAlgorithm" -and $q -ne "SecondaryAlgorithm" -and $q -ne "Disable" -and ($p.$q -isnot [string] -or $p.$q.Trim() -ne "")) -or ($q -eq "Disable" -and $p.Disable)) {$true;break}})) {
                                $CcMinerNameToAdd = $CcMinerName
                                if ($p.MainAlgorithm -ne '*') {
                                    $CcMinerNameToAdd = "$CcMinerNameToAdd-$(Get-Algorithm $p.MainAlgorithm)"
                                    if ($p.SecondaryAlgorithm) {$CcMinerNameToAdd = "$CcMinerNameToAdd-$(Get-Algorithm $p.SecondaryAlgorithm)"}
                                }
                                if ($p.MSIAprofile -ne $null -and $p.MSIAprofile -and $p.MSIAprofile -notmatch "^[1-5]$") {
                                    Write-Log -Level Warn "Invalid MSIAprofile for $($CcMinerNameToAdd) in miners.config.txt: `"$($p.MSIAprofile)`" (empty or 1-5 allowed, only)"
                                    $p.MSIAprofile = ""
                                }
                                if ($p.Difficulty -ne $null) {$p.Difficulty = $p.Difficulty -replace "[^\d]"}
                                $Session.Config.Miners | Add-Member -Name $CcMinerNameToAdd -Value $p -MemberType NoteProperty -Force
                                $Session.Config.Miners.$CcMinerNameToAdd.Disable = Get-Yes $Session.Config.Miners.$CcMinerNameToAdd.Disable
                            }
                        }
                    }
                }
            }
            if ($AllMiners -ne $null) {Remove-Variable "AllMiners"}
        }
    }

    $API.Config = $Session.Config
    $API.UserConfig = $Session.UserConfig

    $MinerInfoChanged = $false
    if (-not (Test-Path ".\Data\minerinfo.json")) {$Session.MinerInfo = @{}}
    Compare-Object @($Session.AvailMiners | Select-Object) @($Session.MinerInfo.Keys | Select-Object) | Foreach-Object {
        $CcMinerName = $_.InputObject
        Switch ($_.SideIndicator) {
            "<=" {$Session.MinerInfo[$CcMinerName] = @(Get-MinersContent -MinerName $CcMinerName -InfoOnly | Select-Object -ExpandProperty Type)}
            "=>" {$Session.MinerInfo.Remove($CcMinerName)}
        }
        $MinerInfoChanged = $true
    }
    if ($MinerInfoChanged) {Set-ContentJson -PathToFile ".\Data\minerinfo.json" -Data $Session.MinerInfo -Compress > $null}

    $API.MinerInfo = $Session.MinerInfo

    #Check for GPU failure and reboot, if needed
    if ($Session.Config.RebootOnGPUFailure) { 
        Write-Log "Testing for GPU failure. "
        Test-GPU
    }

    if ($Session.Config.Proxy) {$PSDefaultParameterValues["*:Proxy"] = $Session.Config.Proxy}
    else {$PSDefaultParameterValues.Remove("*:Proxy")}

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading API modules .."}

    Get-ChildItem "APIs" -File | Foreach-Object {. $_.FullName}

    if ($UseTimeSync) {Test-TimeSync}
    $Session.Timer = (Get-Date).ToUniversalTime()

    $RoundSpan = if ($Session.RoundStart) {New-TimeSpan $Session.RoundStart $Session.Timer} else {New-TimeSpan -Seconds $Session.Config.BenchmarkInterval}
    $Session.RoundStart = $Session.Timer
    $RoundEnd = $Session.Timer.AddSeconds($Session.CurrentInterval)

    #Update the exchange rates
    Write-Log "Updating exchange rates. "
    Update-Rates

    $API.Rates = $Session.Rates

    #PowerPrice check
    [Double]$PowerPriceBTC = 0
    if ($Session.CurrentPowerPrice -gt 0 -and $Session.Config.PowerPriceCurrency) {
        if ($Session.Rates."$($Session.Config.PowerPriceCurrency)") {
            $PowerPriceBTC = [Double]$Session.CurrentPowerPrice/[Double]$Session.Rates."$($Session.Config.PowerPriceCurrency)"
        } else {
            Write-Log -Level Warn "Powerprice currency $($Session.Config.PowerPriceCurreny) not found. Cost of electricity will be ignored."
        }
    }

    #Load the stats
    Write-Log "Loading saved statistics. "

    [hashtable]$Session.Stats = Get-Stat -Miners
    [hashtable]$Disabled      = Get-Stat -Disabled

    $API.Stats = $Session.Stats

    #Load information about the pools
    Write-Log "Loading pool information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading pool modules .."}

    [System.Collections.ArrayList]$SelectedPoolNames = @()
    $NewPools = @()
    $TimerPools = @{}
    $StopWatch = New-Object -TypeName System.Diagnostics.StopWatch
    if (Test-Path "Pools") {
        $NewPools = $Session.AvailPools | Where-Object {$Session.Config.Pools.$_ -and ($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_)} | Foreach-Object {
            $SelectedPoolNames.Add($_) > $null
            if ($Session.RoundCounter -eq 0) {Write-Host ".. loading $($_) " -NoNewline}
            $StopWatch.Restart()
            Get-PoolsContent $_ -Config $Session.Config.Pools.$_ -StatSpan $RoundSpan -InfoOnly $false -IgnoreFees $Session.Config.IgnoreFees -Algorithms $Session.Config.Algorithms -Coins $Session.Config.Coins -EnableErrorRatio:$Session.Config.EnableErrorRatio -Disabled $Disabled
            $TimerPools[$_] = [Math]::Round($StopWatch.ElapsedMilliseconds/1000,3)
            if ($Session.RoundCounter -eq 0) {Write-Host "done ($($TimerPools[$_])s) "}
            Write-Log "$($_) loaded in $($TimerPools[$_])s "
        }
    }
    $TimerPools | ConvertTo-Json | Set-Content ".\Logs\timerpools.json" -Force
    Remove-Variable "StopWatch"
    Remove-Variable "TimerPools"

    #Store pools to file
    if (-not $Session.IsDonationRun -and (-not $Session.Updatetracker.PoolsSave -or $Session.Updatetracker.PoolsSave -lt (Get-Date).AddHours(-6) -or -not (Test-Path ".\Data\poolsdata.json"))) {
        $Session.Updatetracker.PoolsSave = Get-Date
        Set-ContentJson ".\Data\poolsdata.json" @($NewPools | Select-Object Name,Algorithm,CoinSymbol,Price,StablePrice,PenaltyFactor,ErrorRatio -Unique) -Compress > $null
        $Session.ReportPoolsData = $true
    }

    #Update the pool balances every "BalanceUpdateMinutes" minutes
    if ($Session.Config.ShowPoolBalances) {
        $RefreshBalances = (-not $Session.Updatetracker.Balances -or $Session.Updatetracker.Balances -lt $Session.Timer.AddMinutes(-$Session.Config.BalanceUpdateMinutes))
        if ($RefreshBalances) {
            Write-Log "Getting pool balances. "
            $Session.Updatetracker.Balances = $Session.Timer
        } else {
            Write-Log "Updating pool balances. "
        }

        if ($Session.RoundCounter -eq 0) {Write-Host "Loading balance modules .."}

        $BalancesData = Get-Balance -Config $(if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}) -Refresh $RefreshBalances -Details $Session.Config.ShowPoolBalancesDetails

        if (-not $BalancesData) {$Session.Updatetracker.Balances = 0}
        else {
            $BalancesData_DateTime = Get-Date
            $BalancesData | Where-Object Name -ne "*Total*" | Foreach-Object {
                $Balance = $_
                $Earnings = Set-Balance $Balance -Updated $BalancesData_DateTime
                $Earnings.PSObject.Properties.Name | Where-Object {$_ -match "^Earnings" -or $_ -eq "Started"} | Foreach-Object {
                    $Balance | Add-Member $_ $Earnings.$_ -Force
                }
            }
            if ($Earnings -ne $null) {Remove-Variable "Earnings"}
            $API.Balances = $BalancesData
            $Session.Earnings_Avg = $API.Earnings_Avg = ($BalancesData | Where-Object {$_.Name -ne "*Total*" -and $Session.Rates."$($_.Currency)"} | Foreach-Object {$_.Earnings_Avg / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
            $Session.Earnings_1d  = $API.Earnings_1d  = ($BalancesData | Where-Object {$_.Name -ne "*Total*" -and $Session.Rates."$($_.Currency)"} | Foreach-Object {$_.Earnings_1d / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum

            if ($RefreshBalances) {$Session.ReportTotals = $true}
        }
    }

    #Stop async jobs for no longer needed pools (will restart automatically, if pool pops in again)
    if ($Session.Config.RunMode -ne "Server") {
        $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_ -or -not (($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_))} | Foreach-Object {Stop-AsyncJob -tag $_}
    }

    #Remove stats from pools & miners not longer in use
    if (-not $Session.IsDonationRun -and (Test-Path "Stats")) {
        if ($SelectedPoolNames -and $SelectedPoolNames.Count -gt 0) {Compare-Object @($SelectedPoolNames | Select-Object) @($Session.Stats.Keys | Where-Object {$_ -match '^(.+?)_.+Profit$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Pools\$($_.InputObject)_*_Profit.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
        if ($Session.AvailMiners -and $Session.AvailMiners.Count -gt 0) {Compare-Object @($Session.AvailMiners | Select-Object) @($Session.Stats.Keys | Where-Object {$_ -match '^(.+?)-.+Hashrate$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Miners\$($_.InputObject)-*_Hashrate.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
    }
    Remove-Variable "SelectedPoolNames"

    if ($Session.RoundCounter -eq 0) {Write-Host "Selecting best pools .."}

    Set-UnprofitableAlgos

    $LockMiners = $Session.LockMiners.Locked -and -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun

    #This finds any pools that were already in $Script:AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    $Script:AllPools = @($NewPools) + @(Compare-Object @($NewPools.Name | Select-Object -Unique) @($Script:AllPools.Name | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$Script:AllPools | Where-Object Name -EQ $_ | Foreach-Object {$_ | ConvertTo-Json -Depth 10 -Compress -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore}}) | Where-Object {
        $Pool_Name = $_.Name
        $Pool_Algo = $_.Algorithm -replace '\-.+$'
        if ($_.CoinSymbol) {$Pool_Algo = @($Pool_Algo,"$($Pool_Algo)-$($_.CoinSymbol)")}
        -not (
                (-not $Session.Config.Pools.$Pool_Name) -or
                ($Session.Config.PoolName.Count -and $Session.Config.PoolName -inotcontains $Pool_Name) -or
                ($Session.Config.ExcludePoolName.Count -and $Session.Config.ExcludePoolName -icontains $Pool_Name) -or
                ($Session.Config.Algorithm.Count -and -not (Compare-Object @($Session.Config.Algorithm | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.ExcludeAlgorithm.Count -and (Compare-Object @($Session.Config.ExcludeAlgorithm | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                (-not $Session.Config.DisableUnprofitableAlgolist -and $Session.UnprofitableAlgos.Algorithms -and $Session.UnprofitableAlgos.Algorithms.Count -and (Compare-Object @($Session.UnprofitableAlgos.Algorithms | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                (-not $Session.Config.DisableUnprofitableAlgolist -and $Session.UnprofitableAlgos.Pools.$Pool_Name -and $Session.UnprofitableAlgos.Pools.$Pool_Name.Count -and (Compare-Object @($Session.UnprofitableAlgos.Pools.$Pool_Name | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.ExcludeCoin.Count -and $_.CoinName -and @($Session.Config.ExcludeCoin) -icontains $_.CoinName) -or
                ($Session.Config.ExcludeCoinSymbol.Count -and $_.CoinSymbol -and @($Session.Config.ExcludeCoinSymbol) -icontains $_.CoinSymbol) -or
                ($Session.Config.Pools.$Pool_Name.Algorithm.Count -and -not (Compare-Object @($Session.Config.Pools.$Pool_Name.Algorithm | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Compare-Object @($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($_.CoinName -and $Session.Config.Pools.$Pool_Name.CoinName.Count -and @($Session.Config.Pools.$Pool_Name.CoinName) -inotcontains $_.CoinName) -or
                ($_.CoinName -and $Session.Config.Pools.$Pool_Name.ExcludeCoin.Count -and @($Session.Config.Pools.$Pool_Name.ExcludeCoin) -icontains $_.CoinName) -or
                ($_.CoinSymbol -and $Session.Config.Pools.$Pool_Name.CoinSymbol.Count -and @($Session.Config.Pools.$Pool_Name.CoinSymbol) -inotcontains $_.CoinSymbol) -or
                ($_.CoinSymbol -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and @($Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol) -icontains $_.CoinSymbol)
            ) -and (
                ($_.Exclusive -and -not $_.Idle) -or -not (
                    ($_.Idle) -or
                    ($_.Hashrate -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinHashrate -and $_.Hashrate -lt $Session.Config.Algorithms."$($_.Algorithm)".MinHashrate) -or
                    ($_.Workers -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinWorkers -and $_.Workers -lt $Session.Config.Algorithms."$($_.Algorithm)".MinWorkers) -or
                    ($_.BLK -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MaxTimeToFind -and ($_.BLK -eq 0 -or ($_.BLK -gt 0 -and (24/$_.BLK*3600) -gt $Session.Config.Algorithms."$($_.Algorithm)".MaxTimeToFind))) -or
                    ($_.CoinSymbol -and $_.Hashrate -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinHashrate -and $_.Hashrate -lt $Session.Config.Coins."$($_.CoinSymbol)".MinHashrate) -or
                    ($_.CoinSymbol -and $_.Workers -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinWorkers -and $_.Workers -lt $Session.Config.Coins."$($_.CoinSymbol)".MinWorkers) -or
                    ($_.CoinSymbol -and $_.BLK -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MaxTimeToFind -and ($_.BLK -eq 0 -or ($_.BLK -gt 0 -and (24/$_.BLK*3600) -gt $Session.Config.Coins."$($_.CoinSymbol)".MaxTimeToFind)))
                )                
            )}
    if ($NewPools -ne $null) {Remove-Variable "NewPools"}

    $API.AllPools = $Script:AllPools

    $AllPools_BeforeWD_Count = ($Script:AllPools | Measure-Object).Count

    #Apply watchdog to pools, only if there is more than one pool selected
    if (($Script:AllPools.Name | Select-Object -Unique | Measure-Object).Count -gt 1) {
        $Script:AllPools = $Script:AllPools | Where-Object {-not $_.Disabled} | Where-Object {
            $Pool = $_
            $Pool_WatchdogTimers = $Script:WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Session.Timer.AddSeconds( - $Session.WatchdogInterval) | Where-Object Kicked -GT $Session.Timer.AddSeconds( - $Session.WatchdogReset)
            $Pool.Exclusive -or (($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2)
        }
    }
    if ($Pool_WatchdogTimers -ne $null) {Remove-Variable "Pool_WatchdogTimers"}

    #Update the active pools
    $Pools = [PSCustomObject]@{}
    
    if (($Script:AllPools | Measure-Object).Count -gt 0) {

        $Pools_WTM = $Script:AllPools | Where-Object {$_.WTM}
        if (($Pools_WTM | Measure-Object).Count) {
            if ($Session.RoundCounter -eq 0) {Write-Host ".. loading WhatToMine " -NoNewline}
            $start = Get-UnixTimestamp -Milliseconds
            Get-PoolsContent "WhatToMine" -Config ([PSCustomObject]@{Pools = $Pools_WTM}) -StatSpan $RoundSpan -InfoOnly $false | Foreach-Object {
                $Pool_WTM = $_
                $Pools_WTM | Where-Object {$_.Algorithm -eq $Pool_WTM.Algorithm -and $_.CoinSymbol -eq $Pool_WTM.CoinSymbol} | Foreach-Object {
                   $_.Price         = $Pool_WTM.Price * $_.PenaltyFactor
                   $_.StablePrice   = $Pool_WTM.StablePrice * $_.PenaltyFactor
                   $_.MarginOfError = $Pool_WTM.MarginOfError
                   $_.Updated       = $Pool_WTM.Updated
                }
            }
            $done = [Math]::Round(((Get-UnixTimestamp -Milliseconds) - $start)/1000,3)
            if ($Session.RoundCounter -eq 0) {Write-Host "done ($($done)s) "}
            Write-Log "WhatToMine loaded in $($done)s "
        }

        #Decrease compare prices, if out of sync window
        # \frac{\left(\frac{\ln\left(60-x\right)}{\ln\left(50\right)}+1\right)}{2}
        $OutOfSyncTimer    = ($Script:AllPools | Select-Object -ExpandProperty Updated | Measure-Object -Maximum).Maximum
        $OutOfSyncTime     = $OutOfSyncTimer.AddMinutes(-$Session.OutofsyncWindow)
        $OutOfSyncDivisor  = [Math]::Log($Session.OutofsyncWindow-$Session.SyncWindow) #precalc for sync decay method
        $OutOfSyncLimit    = 1/($Session.OutofsyncWindow-$Session.SyncWindow)

        $Pools_Hashrates   = @{}
        $Pools_Running     = @{}
        $Pools_Benchmarking= @{}
        $Pools_PriceCmp    = @{}

        $Script:AllPools | Select-Object Algorithm,CoinSymbol,Hashrate,StablePrice | Group-Object -Property {"$($_.Algorithm -replace "\-.+$")-$($_.CoinSymbol)"} | Foreach-Object {$Pools_Hashrates[$_.Name] = ($_.Group | Where-Object StablePrice | Select-Object -ExpandProperty Hashrate | Measure-Object -Maximum).Maximum;if (-not $Pools_Hashrates[$_.Name]) {$Pools_Hashrates[$_.Name]=1}}
        $Script:AllPools | Where-Object {$_.TSL -ne $null -and $Session.Config.Pools."$($_.Name)".EnablePostBlockMining -and $_.CoinSymbol -and ($_.TSL -lt $Session.Config.Coins."$($_.CoinSymbol)".PostBlockMining)} | Foreach-Object {$_ | Add-Member PostBlockMining $true -Force}

        $Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {
            for($i=0;$i -lt $_.Pool.Count;$i++) {
                $Pool_Ix = "$($_.Pool | Select-Object -Index $i)-$($_.BaseAlgorithm | Select-Object -Index $i)-$($_.CoinSymbol | Select-Object -Index $i)"
                if (-not $Pools_Running.ContainsKey($Pool_Ix) -or $Pools_Running[$Pool_Ix] -gt $_.Rounds) {$Pools_Running[$Pool_Ix] = $_.Rounds}
                $Pools_Benchmarking[$Pool_Ix]=$Pools_Benchmarking[$Pool_Ix] -or $_.NeedsBenchmark
            }
        }
        $Session.DecayFact = [Math]::Min($Session.Config.SwitchingPrevention,1) * [Math]::Pow($Session.DecayBase, [int](($Session.Timer - $Session.DecayStart).TotalSeconds / $Session.DecayPeriod) / ([Math]::Max($Session.Config.SwitchingPrevention,1)))

        Write-Log "Calculating pool compare prices. "
        $Script:AllPools | Foreach-Object {
            $Pool_Ix = "$($_.Name)-$($_.Algorithm -replace "\-.+$")-$($_.CoinSymbol)"
            if (-not $Pools_PriceCmp.ContainsKey($Pool_Ix)) {
                $Price_Cmp =  $_."$(if (-not $Session.Config.EnableFastSwitching -and -not $_.PaysLive) {"Stable"})Price"
                if (-not $_.Exclusive) {
                    $Pool_Rounds = $Pools_Running[$Pool_Ix]
                    if ($Pool_Rounds -ne $null -and ($Session.IsBenchmarkingRun -and $Pools_Benchmarking[$Pool_Ix] -or $Pool_Rounds -lt $Session.Config.MinimumMiningIntervals)) {
                        $Price_Cmp *= 100
                    } else {
                        $Price_Cmp *= [Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)
                        if (-not ($Session.Config.EnableFastSwitching -or $Session.SkipSwitchingPrevention)) {
                            if ($Pool_Rounds -eq $null) {
                                if ($Session.Config.Pools."$($_.Name)".MaxMarginOfError) {
                                    $Price_Cmp *= 1-([Math]::Floor(([Math]::Min($_.MarginOfError,$Session.Config.Pools."$($_.Name)".MaxMarginOfError/100) * $Session.DecayFact) * 100.00) / 100.00) * ($Session.Config.PoolAccuracyWeight/100)
                                }
                            } elseif ($Session.Config.Pools."$($_.Name)".SwitchingHysteresis -ne $null) {
                                $Price_Cmp *= 1+($Session.Config.Pools."$($_.Name)".SwitchingHysteresis)
                            } elseif ($Session.Config.PoolSwitchingHystereis) {
                                $Price_Cmp *= 1+($Session.Config.PoolSwitchingHysteresis/100)
                            }
                        }
                        if ($_.HashRate -ne $null -and $Session.Config.HashrateWeightStrength) {
                            $Price_Cmp *= 1-(1-[Math]::Pow($_.Hashrate/$Pools_Hashrates["$($_.Algorithm -replace "\-.+$")-$($_.CoinSymbol)"],$Session.Config.HashrateWeightStrength/100)) * ($Session.Config.HashrateWeight/100)
                        }
                    }
                }
                $Pools_PriceCmp[$Pool_Ix] = $Price_Cmp
            }
        }

        #$(if ($Session.Config.EnableFastSwitching -or $_.PaysLive) {$_.Price} else {$_.StablePrice * (1 - $_.MarginOfError*($Session.Config.PoolAccuracyWeight/100))}) * $(if ($_.Hashrate -eq $null -or -not $Session.Config.HashrateWeightStrength) {1} else {1-(1-[Math]::Pow($_.Hashrate/$Pools_Hashrates["$($_.Algorithm)$($_.CoinSymbol)"],$Session.Config.HashrateWeightStrength/100))*$Session.Config.HashrateWeight/100}) * ([Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1))

        Write-Log "Selecting best pool for each algorithm. "
        $Script:AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($Script:AllPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending {$_.Exclusive -and -not $_.Idle}, {$Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and $Session.Config.Pools."$($_.Name)".FocusWallet -icontains $_.Currency}, {$LockMiners -and $Session.LockMiners.Pools -icontains "$($_.Name)-$($_.Algorithm -replace "\-.+$")-$($_.CoinSymbol)"}, {$_.PostBlockMining}, {-not $_.PostBlockMining -and (-not $_.CoinSymbol -or $Session.Config.Pools."$($_.Name)".CoinSymbolPBM -inotcontains $_.CoinSymbol)}, {$Pools_PriceCmp["$($_.Name)-$($_.Algorithm -replace "\-.+$")-$($_.CoinSymbol)"]}, {$_.Region -eq $Session.Config.Region}, {[int](($ix = $Session.Config.DefaultPoolRegion.IndexOf($_.Region)) -ge 0)*(100-$ix)}, {$_.SSL -eq $Session.Config.SSL} | Select-Object -First 1)}
        $Pools_OutOfSyncMinutes = ($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {$Script:AllPools | Where-Object Name -EQ $_ | Where-Object Updated -ge $OutOfSyncTime | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)
        if ($Pools_OutOfSyncMinutes -gt $Session.SyncWindow) {
            Write-Log "Pool prices are out of sync ($([int]$Pools_OutOfSyncMinutes) minutes). "
        }

        if ($false) {
            $API.PoolsCalculations = [PSCustomObject]@{
                Hashrates = $Pools_Hashrates
                Running   = $Pools_Running
                Benchmarking = $Pools_Benchmarking
                PriceCmp  = $Pools_PriceCmp
            }
        }

        if ($Pools_Hashrates -ne $null) {Remove-Variable "Pools_Hashrates"}
        if ($Pools_Running   -ne $null) {Remove-Variable "Pools_Running"}
        if ($Pools_Benchmarking -ne $null) {Remove-Variable "Pools_Benchmarking"}
        if ($Pools_PriceCmp  -ne $null) {Remove-Variable "Pools_PriceCmp"}

        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
            $Pool_Price = $Pools.$_.Price
            $Pool_Name  = $Pools.$_.Name
            if (-not $Pools.$_.Exclusive) {
                $Pool_Price *= [Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $Pools.$_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)
                $Pool_Price_Bias = $Pool_Price
                if (-not $Session.Config.EnableFastSwitching -and $Session.Config.Pools.$Pool_Name.MaxMarginOfError) {
                    $Pool_Price_Bias *= 1-([Math]::Floor(([Math]::Min($Pools.$_.MarginOfError,$Session.Config.Pools.$Pool_Name.MaxMarginOfError/100) * $Session.DecayFact) * 100.00) / 100.00)
                }
            } else {
                $Pool_Price_Bias = $Pool_Price
            }
            $Pool_Name  = $Pools.$_.Name
            $Pools.$_ | Add-Member -NotePropertyMembers @{
                Price_Bias   = $Pool_Price_Bias
                Price_Unbias = $Pool_Price
                HasMinerExclusions = ($Session.Config.Pools.$Pool_Name.MinerName.Count -or $Session.Config.Pools.$Pool_Name.ExcludeMinerName.Count)
            } -Force
        }
    }

    #Give API access to the pools information
    $API.Pools = $Pools
 
    #Load information about the miners
    Write-Log "Getting miner information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading miner modules .."}

    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Session.Config.MinerName, if specified, and don't match $Session.Config.ExcludeMinerName    
    $AllMiner_Warnings = @()
    $AllMiners = if (($Script:AllPools | Measure-Object).Count -gt 0 -and (Test-Path "Miners")) {
        Get-MinersContent -Pools $Pools | 
            Where-Object {$_.DeviceName -and ($_.DeviceModel -notmatch '-' -or -not (Compare-Object $_.DeviceName $Session.DeviceNames."$($_.DeviceModel)"))} | #filter miners for non-present hardware
            Where-Object {-not $Session.Config.DisableDualMining -or $_.HashRates.PSObject.Properties.Name.Count -eq 1} | #filter dual algo miners
            Where-Object {(Compare-Object @($Session.Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
            Where-Object {(Compare-Object @($Pools.PSObject.Properties.Name | Select-Object) @($_.HashRates.PSObject.Properties.Name | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} |             
            Where-Object {-not $Session.Config.Miners."$($_.BaseName)-$($_.DeviceModel)-$($_.BaseAlgorithm)".Disable} |
            Where-Object {$Miner_Name = $_.BaseName
                            ($_.HashRates.PSObject.Properties.Name | Where-Object {$Pools.$_.HasMinerExclusions} | Where-Object {
                                $Pool_Name = $Pools.$_.Name
                                ($Session.Config.Pools.$Pool_Name.MinerName.Count -and $Session.Config.Pools.$Pool_Name.MinerName -inotcontains $Miner_Name) -or
                                ($Session.Config.Pools.$Pool_Name.ExcludeMinerName.Count -and $Session.Config.Pools.$Pool_Name.ExcludeMinerName -icontains $Miner_Name)
                            } | Measure-Object).Count -eq 0
            } |
            Where-Object {
                $MinerOk = $true
                foreach ($p in @($_.DeviceModel -split '-')) {
                    $BaseAlgo = $_.BaseAlgorithm -split '-'
                    if ($Session.Config.Miners."$($_.BaseName)-$($p)-$($_.BaseAlgorithm)".Disable -or 
                        $Session.Config.Devices.$p -and
                        (
                            ($Session.Config.Devices.$p.DisableDualMining -and $_.HashRates.PSObject.Properties.Name.Count -gt 1) -or
                            ($Session.Config.Devices.$p.Algorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.Algorithm $BaseAlgo -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0) -or
                            ($Session.Config.Devices.$p.ExcludeAlgorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.ExcludeAlgorithm $BaseAlgo -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
                            ($Session.Config.Devices.$p.MinerName.Count -gt 0 -and ($Session.Config.Devices.$p.MinerName -inotcontains $_.Basename)) -or
                            ($Session.Config.Devices.$p.ExcludeMinerName.Count -gt 0 -and ($Session.Config.Devices.$p.ExcludeMinerName -icontains $_.Basename))
                        )
                    ) {$MinerOk=$false;break}
                }
                $MinerOk
            }
    }

    #Check if .NET Core Runtime is installed
    $MinersNeedSdk = $AllMiners | Where-Object {$_.DotNetRuntime -and (Compare-Version $_.DotNetRuntime $Session.Config.DotNETRuntimeVersion) -gt 0}
    if ($MinersNeedSdk) {
        $MinersNeedSdk | Foreach-Object {Write-Log -Level Warn "$($_.BaseName) requires .NET Core Runtime (min. version $($_.DotNetRuntime)) to be installed! Find the installer here: https://dotnet.microsoft.com/download"}
        $AllMiners = $AllMiners | Where-Object {@($MinersNeedSdk) -notcontains $_}
        Start-Sleep 2
    }
    if ($MinersNeedSdk -ne $null) {Remove-Variable "MinersNeedSdk"}

    if ($Session.RoundCounter -eq 0) {Write-Host "Selecting best miners .."}

    if ($Session.Config.MiningMode -eq "combo") {
        if (($AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null -and $_.DeviceModel -notmatch '-'} | Measure-Object).Count -gt 0) {
            #Benchmarking is still ongoing - remove device combos from miners and make sure no combo stat is left over
            $AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null -and $_.DeviceModel -notmatch '-'} | Foreach-Object {
                $Miner = $_
                $ComboAlgos = $Miner.HashRates.PSObject.Properties.Name
                $AllMiners | 
                    Where-Object {$_.BaseName -eq $Miner.BaseName -and $_.HashRates.PSObject.Properties.Value -notcontains $null -and $_.DeviceModel -match '-' -and $($Miner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($_.DeviceModel -split '-') -icontains $Miner.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} |
                    Foreach-Object {
                        $Name = $_.Name
                        $ComboAlgos | Foreach-Object {Get-ChildItem ".\Stats\Miners\*-$($Name)_$($_)_HashRate.txt" | Remove-Item -ErrorAction Ignore}
                    }
            }
            $AllMiners = $AllMiners | Where-Object {$_.DeviceModel -notmatch '-'}
        } else {
            #Remove device combos, where the parameter-preset is different and there does not exist an own definition
            $AllMiners = $AllMiners | Where-Object {
                $_.DeviceModel -notmatch '-' -or 
                (Get-Member -InputObject $Session.Config.Miners -Name $(@($_.BaseName | Select-Object) + @($_.DeviceModel | Select-Object) + @($_.BaseAlgorithm | Select-Object) -join '-') -MemberType NoteProperty) -or 
                $($Miner = $_; (@($Miner.DeviceModel -split '-') | Foreach-Object {
                    $Miner_ConfigName = @($Miner.BaseName | Select-Object) + @($_ | Select-Object) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
                    if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_ConfigName -MemberType NoteProperty){$Session.Config.Miners.$Miner_ConfigName.Params}
                } | Select-Object -Unique | Measure-Object).Count -le 1)
            }

            #Gather mining statistics for fresh combos
            $AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null -and $_.DeviceModel -match '-'} | Foreach-Object {
                $Miner = $_
                $ComboAlgos = $Miner.HashRates.PSObject.Properties.Name
                $AllMiners | 
                    Where-Object {$_.BaseName -eq $Miner.BaseName -and $_.DeviceModel -notmatch '-' -and $($Miner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($Miner.DeviceModel -split '-') -icontains $_.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} |
                    Select-Object -ExpandProperty HashRates |
                    Measure-Object -Sum @($ComboAlgos) |
                    Foreach-Object {$Miner.HashRates."$($_.Property)" = $_.Sum * 1.02} 
                    #we exagerate a bit to prefer combos over single miners for startup. If the combo runs less good, later, it will fall back by itself

                $Miner.PowerDraw = ($AllMiners | 
                    Where-Object {$_.BaseName -eq $Miner.BaseName -and $_.DeviceModel -notmatch '-' -and $($Miner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($Miner.DeviceModel -split '-') -icontains $_.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} |
                    Select-Object -ExpandProperty PowerDraw |
                    Measure-Object -Sum).Sum
            }
        }
    }

    if ($ComboAlgos -ne $null) {Remove-Variable "ComboAlgos"}

    Write-Log "Calculating profit for each miner. "
    
    [hashtable]$AllMiners_VersionCheck = @{}
    [hashtable]$AllMiners_VersionDate  = @{}
    [System.Collections.ArrayList]$Miner_Arguments_List = @()
    $AllMiners | ForEach-Object {
        $Miner = $_

        $Miner_AlgoNames = @($Miner.HashRates.PSObject.Properties.Name | Select-Object)

        $Miner_Setup = @{
            Pools         = if ($Miner_AlgoNames.Count -eq 1) {[PSCustomObject]@{$Miner_AlgoNames[0] = $Pools.$($Miner_AlgoNames[0])}} else {[PSCustomObject]@{$Miner_AlgoNames[0] = $Pools.$($Miner_AlgoNames[0]);$Miner_AlgoNames[1] = $Pools.$($Miner_AlgoNames[1])}}
            Difficulties  = [hashtable]@{}
            Ratios        = [hashtable]@{}
            OCprofile     = [hashtable]@{}
            Profit        = 0.0
            Profit_Bias   = 0.0
            Profit_Unbias = 0.0
            Profit_Cost   = 0.0
            Disabled      = $false
        }

        if ($Miner.DevFee -eq $null -or $Miner.DevFee -isnot [PSCustomObject]) {$Miner_Setup.DevFee = if ($Miner_AlgoNames.Count -eq 1) {[PSCustomObject]@{$Miner_AlgoNames[0] = $Miner.DevFee}} else {[PSCustomObject]@{$Miner_AlgoNames[0] = $Miner.DevFee;$Miner_AlgoNames[1] = 0}}}
        if (-not $Miner.API)            {$Miner_Setup.API = "Miner"}
        if ($Miner.EnvVars -eq $null)   {$Miner_Setup.EnvVars = @()}

        $Miner | Add-Member -NotePropertyMembers $Miner_Setup -Force

        $Miner_Profits        = [hashtable]@{}
        $Miner_Profits_Bias   = [hashtable]@{}
        $Miner_Profits_Unbias = [hashtable]@{}

        foreach($p in @($Miner.DeviceModel -split '-')) {$Miner.OCprofile[$p] = ""}

        if ($Session.Config.Miners) {
            $Miner_CommonCommands = $Miner_Arguments = $Miner_Difficulty = ''
            $Miner_MSIAprofile = 0
            $Miner_Penalty = $Miner_ExtendInterval = $Miner_FaultTolerance = -1
            $Miner_CommonCommands_found = $false
            [System.Collections.ArrayList]$Miner_CommonCommands_array = @($Miner.BaseName,$Miner.DeviceModel)
            $Miner_CommonCommands_array.AddRange(@($Miner.BaseAlgorithm -split '-' | Select-Object))
            for($i=$Miner_CommonCommands_array.Count;$i -gt 0; $i--) {
                $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                    if ($Session.Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Session.Config.Miners.$Miner_CommonCommands.Params}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Difficulty -and $Miner_Difficulty -eq '') {$Miner_Difficulty = $Session.Config.Miners.$Miner_CommonCommands.Difficulty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -eq 0) {$Miner_MSIAprofile = [int]$Session.Config.Miners.$Miner_CommonCommands.MSIAprofile}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and $Miner_Penalty -eq -1) {$Miner_Penalty = [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.ExtendInterval -and $Miner_ExtendInterval -eq -1) {$Miner_ExtendInterval = [int]$Session.Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Session.Config.Miners.$Miner_CommonCommands.FaultTolerance -and $Miner_FaultTolerance -eq -1) {$Miner_FaultTolerance = [double]$Session.Config.Miners.$Miner_CommonCommands.FaultTolerance}
                    if ($Session.Config.Miners.$Miner_CommonCommands.OCprofile -and $i -gt 1) {foreach ($p in @($Miner.DeviceModel -split '-')) {if (-not $Miner.OCprofile[$p]) {$Miner.OCprofile[$p]=$Session.Config.Miners.$Miner_CommonCommands.OCprofile}}}
                    $Miner_CommonCommands_found = $true
                }
            }
            if (-not $Miner_CommonCommands_found -and $Session.Config.MiningMode -eq "combo" -and $Miner.DeviceModel -match '-') {
                #combo handling - we know that combos always have equal params, because we preselected them, already
                foreach($p in @($Miner.DeviceModel -split '-')) {
                    $Miner_CommonCommands_array[1] = $p
                    $Miner_CommonCommands = $Miner_CommonCommands_array -join '-'
                    if ($Session.Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Session.Config.Miners.$Miner_CommonCommands.Params}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Difficulty -and $Miner_Difficulty -eq '') {$Miner_Difficulty = $Session.Config.Miners.$Miner_CommonCommands.Difficulty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -ge 0 -and $Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -ne $Miner_MSIAprofile) {$Miner_MSIAprofile = if (-not $Miner_MSIAprofile){[int]$Session.Config.Miners.$Miner_CommonCommands.MSIAprofile}else{-1}}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty -gt $Miner_Penalty) {$Miner_Penalty = [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.ExtendInterval -and [int]$Session.Config.Miners.$Miner_CommonCommands.ExtendInterval -gt $Miner_ExtendInterval) {$Miner_ExtendInterval = [int]$Session.Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Session.Config.Miners.$Miner_CommonCommands.FaultTolerance -and [double]$Session.Config.Miners.$Miner_CommonCommands.FaultTolerance -gt $Miner_FaultTolerance) {$Miner_FaultTolerance = [double]$Session.Config.Miners.$Miner_CommonCommands.FaultTolerance}
                }
            }           

            #overclocking is different
            foreach($p in @($Miner.DeviceModel -split '-')) {
                if ($Miner.OCprofile[$p] -ne '') {continue}
                $Miner_CommonCommands_array[1] = $p
                for($i=$Miner_CommonCommands_array.Count;$i -gt 1; $i--) {
                    $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                    if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                        if ($Session.Config.Miners.$Miner_CommonCommands.OCprofile) {$Miner.OCprofile[$p]=$Session.Config.Miners.$Miner_CommonCommands.OCprofile}
                    }
                }
            }

            if ($Miner.Arguments -is [string] -or $Miner.Arguments.Params -is [string]) {
                if ($Miner_Arguments -ne '') {
                    $Miner_Arguments_List.Clear()
                    foreach ($p in @(" $Miner_Arguments" -split '\s+-')) {
                        if (-not $p) {continue}
                        $p="-$p"
                        if ($p -match "([\s=]+)") {
                            $pdiv = $matches[1].Trim()
                            if ($pdiv -eq ''){$pdiv=" "}
                            $q = $p -split "[\s=]+"
                            if ($Miner.Arguments -is [string]) {$Miner.Arguments = $Miner.Arguments -replace "$($q[0])[\s=]+[^\s=]+\s*"}
                            else {$Miner.Arguments.Params = $Miner.Arguments.Params -replace "$($q[0])[\s=]+[^\s=]+\s*"}
                            $Miner_Arguments_List.Add($q -join $pdiv)>$null
                        } else {
                            $Miner_Arguments_List.Add($p)>$null
                        }
                    }
                    if ($Miner.Arguments -is [string]) {$Miner.Arguments = "$($Miner.Arguments.Trim()) $($Miner_Arguments_List -join ' ')"}
                    else {$Miner.Arguments.Params = "$($Miner.Arguments.Params.Trim()) $($Miner_Arguments_List -join ' ')"}                
                }
            }

            if ($Miner_MSIAprofile -ne 0)     {$Miner | Add-Member -Name MSIAprofile -Value $($Miner_MSIAprofile) -MemberType NoteProperty -Force}           
            if ($Miner_Penalty -ne -1)        {$Miner.Penalty = $Miner_Penalty}
            if ($Miner_ExtendInterval -ne -1) {$Miner.ExtendInterval = $Miner_ExtendInterval}
            if ($Miner_FaultTolerance -ne -1) {$Miner.FaultTolerance = $Miner_FaultTolerance}
        }

        if (-not $Miner.MSIAprofile -and $Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".MSIAprofile -gt 0) {$Miner | Add-Member -Name MSIAprofile -Value $Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".MSIAprofile -MemberType NoteProperty -Force}

        foreach($p in @($Miner.DeviceModel -split '-')) {if ($Miner.OCprofile[$p] -eq '') {$Miner.OCprofile[$p]=if ($Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".OCprofile -ne "") {$Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".OCprofile} else {$Session.Config.Devices.$p.DefaultOCprofile}}}

        $NoResult = $false
        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object {
            $Miner.DevFee.$_ = ([Double]$(if (-not $Session.Config.IgnoreFees) {$Miner.DevFee.$_} else {0}))

            if (-not [String]$Miner.HashRates.$_) {
                $Miner.HashRates.$_       = $null
                $Miner.Difficulties[$_]   = $null
                $Miner.Ratios[$_]         = $null
                $NoResult = $true
            } else {
                $Miner_Name = "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate"
                $Miner_DevFeeFactor = (1-$Miner.DevFee.$_/100)
                if ($Miner.Penalty) {$Miner_DevFeeFactor -= [Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.Penalty.GetType().Name) {$Miner.Penalty.$_} else {$Miner.Penalty})/100;if ($Miner_DevFeeFactor -lt 0){$Miner_DevFeeFactor=0}}
                if (-not $Miner.Disabled -and $Disabled.ContainsKey($Miner_Name)) {$Miner.Disabled = $true}
                $Miner.HashRates.$_       = [Double]$Miner.HashRates.$_
                $Miner.Difficulties[$_]   = ([Double]$Session.Stats.$Miner_Name.Diff_Average)
                $Miner.Ratios[$_]         = ([Double]$Session.Stats.$Miner_Name.Ratio_Live)
                $Miner_Profits[$_]        = ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * $Miner_DevFeeFactor)
                $Miner_Profits_Bias[$_]   = ([Double]$Miner.HashRates.$_ * ($Pools.$_.Price_Bias+1e-32) * $Miner_DevFeeFactor)
                $Miner_Profits_Unbias[$_] = ([Double]$Miner.HashRates.$_ * ($Pools.$_.Price_Unbias+1e-32) * $Miner_DevFeeFactor)
            }
        }

        if ($NoResult) {
            $Miner.Profit        = $null
            $Miner.Profit_Bias   = $null
            $Miner.Profit_Unbias = $null
            $Miner.Profit_Cost   = $null
        } else {
            $Miner.Profit        = [Double]($Miner_Profits.Values | Measure-Object -Sum).Sum
            $Miner.Profit_Bias   = [Double]($Miner_Profits_Bias.Values | Measure-Object -Sum).Sum
            $Miner.Profit_Unbias = [Double]($Miner_Profits_Unbias.Values | Measure-Object -Sum).Sum
            $Miner.Profit_Cost   = [Double]($Miner.PowerDraw*24/1000 * $PowerPriceBTC)
            if ($Miner.DeviceName -match "^CPU" -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)) {$Miner.Profit_Cost=0}
        }

        $HmF = $Miner.DeviceModel -ne "CPU" -and $EnableMiningHeatControl -and $Miner.PowerDraw

        if (($Session.Config.UsePowerPrice -or $HmF) -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {
            if ($Session.Config.UsePowerPrice) {
                $Miner.Profit -= $Miner.Profit_Cost
            }
            $HmF = if ($EnableMiningHeatControl) {3-$MiningHeatControl} else {1.0}
            $Miner.Profit_Bias -= $Miner.Profit_Cost * $HmF
            $Miner.Profit_Unbias -= $Miner.Profit_Cost * $HmF
        }

        $Miner.DeviceName = @($Miner.DeviceName | Select-Object -Unique | Sort-Object)

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $AllMiners_VersionCheck.ContainsKey($Miner.BaseName)) {
            $Miner_UriJson = Join-Path (Get-MinerInstPath $Miner.Path) "_uri.json"
            $Miner_Uri = ""
            if ((Test-Path $Miner.Path) -and (Test-Path $Miner_UriJson)) {$Miner_Uri = Get-ContentByStreamReader $Miner_UriJson | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty URI; $AllMiners_VersionDate[$Miner.BaseName] = (Get-ChildItem $Miner_UriJson).LastWriteTime.ToUniversalTime()}
            $AllMiners_VersionCheck[$Miner.BaseName] = $Miner_Uri -eq $Miner.URI            
        }

        if ($Session.Config.EnableAutoBenchmark -and ($Session.Config.MiningMode -eq "legacy" -or $Miner.DeviceModel -notmatch '-') -and $AllMiners_VersionDate[$Miner.BaseName] -ne $null -and $Session.Stats.ContainsKey("$($Miner.Name)_$($Miner.BaseAlgorithm -replace '-.*$')_HashRate") -and $Session.Stats["$($Miner.Name)_$($Miner.BaseAlgorithm -replace '-.*$')_HashRate"].Updated -lt $AllMiners_VersionDate[$Miner.BaseName]) {
            Get-ChildItem ".\Stats\Miners\*-$($Miner.Name -replace "-(CPU|GPU)#.+")-$($Miner.DeviceName -join '*')*_$($Miner.BaseAlgorithm -replace '-.*$')_HashRate.txt" | Remove-Item -ErrorAction Ignore
            if ($Miner.BaseAlgorithm -match '-') {
                Get-ChildItem ".\Stats\Miners\*-$($Miner.Name -replace "-(CPU|GPU)#.+")-$($Miner.DeviceName -join '*')*_$($Miner.BaseAlgorithm -replace '^.*-')_HashRate.txt" | Remove-Item -ErrorAction Ignore
            }
        }

        if ($Miner.Arguments -is [string]) {$Miner.Arguments = ($Miner.Arguments -replace "\s+"," ").trim()}
        else {
            if ($Miner.Arguments.Params -is [string]) {$Miner.Arguments.Params = ($Miner.Arguments.Params -replace "\s+"," ").trim()}
            $Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress
        }
        try {$Miner_Difficulty = [double]($Miner_Difficulty -replace ",","." -replace "[^\d\.]")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Miner_Difficulty=0.0}
        if ($Miner.Arguments) {$Miner.Arguments = $Miner.Arguments -replace "\`$difficulty",$Miner_Difficulty -replace "{diff:(.+?)}","$(if ($Miner_Difficulty -gt 0){"`$1"})" -replace "{workername}|{workername:$($Session.Config.WorkerName)}",$(@($Miner.DeviceModel -split '\-' | Foreach-Object {if ($Session.Config.Devices.$_.Worker) {$Session.Config.Devices.$_.Worker} else {$Session.Config.WorkerName}} | Select-Object -Unique) -join '_') -replace "{workername:(.+?)}","`$1"}
                
        if (-not $Miner.ExtendInterval) {$Miner.ExtendInterval = 1}
        if (-not $Miner.FaultTolerance) {$Miner.FaultTolerance = if ($Miner.DeviceName -match "^CPU") {0.25} else {0.1}}
        if (-not $Miner.Penalty)        {$Miner.Penalty = 0}
    }
    if ($Miner_CommonCommands_array -ne $null) {Remove-Variable "Miner_CommonCommands_array"}
    if ($Miner_AlgoNames -ne $null) {Remove-Variable "Miner_AlgoNames"}
    if ($Miner_Setup -ne $null) {Remove-Variable "Miner_Setup"}
    if ($Miner_Profits -ne $null) {Remove-Variable "Miner_Profits"}
    if ($Miner_Profits -ne $null) {Remove-Variable "Miner_Profits_Bias"}
    if ($Miner_Profits_Unbias -ne $null) {Remove-Variable "Miner_Profits_Unbias"}
    if ($Miner_Arguments_List -ne $null) {Remove-Variable "Miner_Arguments_List"}

    $Miners_DownloadList = @()
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath)) -and $AllMiners_VersionCheck[$_.BaseName]}
    if ((($AllMiners | Measure-Object).Count -ne ($Miners | Measure-Object).Count) -or $Session.StartDownloader) {
        $Miners_DownloadList = @($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object -Unique PrerequisiteURI,PrerequisitePath | Where-Object {-not (Test-Path $_.PrerequisitePath)} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}, @{name = "IsMiner"; expression = {$false}}) + @($AllMiners | Where-Object {$AllMiners_VersionCheck[$_.BaseName] -ne $true} | Sort-Object {$_.ExtendInterval} -Descending | Select-Object -Unique @{name = "URI"; expression = {$_.URI}}, @{name = "Path"; expression = {$_.Path}}, @{name = "Searchable"; expression = {$true}}, @{name = "IsMiner"; expression = {$true}})
        if ($Miners_DownloadList.Count -gt 0 -and $Session.Downloader.State -ne "Running") {
            Clear-Host
            Write-Log "Starting download of $($Miners_DownloadList.Count) files."
            if ($Session.RoundCounter -eq 0) {Write-Host "Starting downloader ($($Miners_DownloadList.Count) files) .."}
            $Session.Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ($Miners_DownloadList) -FilePath .\Downloader.ps1
        }
        $Session.StartDownloader = $false
    }
    $API.DownloadList = $Miners_DownloadList
    $Miners_Downloading = $Miners_DownloadList.Count
    if ($AllMiners_VersionCheck -ne $null) {Remove-Variable "AllMiners_VersionCheck"}
    if ($AllMiners_VersionDate -ne $null) {Remove-Variable "AllMiners_VersionDate"}
    if ($Miners_DownloadList -ne $null) {Remove-Variable "Miners_DownloadList"}
    if ($Disabled -ne $null) {Remove-Variable "Disabled"}
    $Session.Stats = $null

    #Open firewall ports for all miners
    try {
        if ($IsWindows -and (Get-Command "Get-MpPreference" -ErrorAction Ignore)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction Ignore) {
                if ($Session.MinerFirewalls -eq $null) {$Session.MinerFirewalls = Get-NetFirewallApplicationFilter | Where-Object {$_.Program -like "$(Get-Location)\Bin\*"} | Select-Object -ExpandProperty Program}
                $OpenFirewallFor = "$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($Session.MinerFirewalls | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)"
                if ($OpenFirewallFor -ne "") {
                    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'$(if ($PSVersionTable.PSVersion -ge (Get-Version "6.1")) {" -SkipEditionCheck"}); ('$OpenFirewallFor' | ConvertFrom-Json -ErrorAction Ignore) | ForEach {New-NetFirewallRule -DisplayName 'RainbowMiner' -Program `$_}" -replace '"', '\"') -Verb runAs -WindowStyle Hidden
                    $Session.MinerFirewalls = $null
                    Remove-Variable "OpenFirewallFor"
                }
            }
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
    if ($AllMiners -ne $null) {Remove-Variable "AllMiners"}

    #Remove miners with developer fee
    if ($Session.Config.ExcludeMinersWithFee) {$Miners = $Miners | Where-Object {($_.DevFee.PSObject.Properties.Value | Foreach-Object {[Double]$_} | Measure-Object -Sum).Sum -eq 0}}

    $Miners_BeforeWD_Count = ($Miners | Measure-Object).Count

    #Store miners to file
    if (-not $Session.IsDonationRun -and -not $Session.Benchmarking -and (-not $Session.Updatetracker.MinerSave -or $Session.Updatetracker.MinerSave -lt (Get-Date).AddHours(-6) -or -not (Test-Path ".\Data\minerdata.json"))) {
        $Session.Updatetracker.MinerSave = Get-Date
        Set-ContentJson ".\Data\minerdata.json" ([PSObject]@{Miners = @($Miners | Where-Object {$_.BaseAlgorithm -notmatch "\-"} | Select-Object @{Name="Name";Expression={$_.BaseName}}, Version, @{Name="Algorithm";Expression={$_.BaseAlgorithm -replace '-.*$'}}, @{Name="DeviceName";Expression={$_.DeviceName -join '-'}}, DeviceModel, @{Name="HashRate"; Expression={$_.HashRates.PSObject.Properties.Value | Select-Object -First 1}}, PowerDraw, @{Name="OCProfile"; Expression={if ($Session.Config.EnableOCProfiles -and $_.DeviceModel -ne "CPU" -and $_.DeviceModel -notmatch '-') {$_.OCprofile.Values | Select-Object -First 1} else {""}}} -Unique); OCprofiles=$Session.Config.OCprofiles; CPU=$Session.DevicesByTypes.CPU.Model_Name | Select-Object -Unique}) -Compress > $null
        $Session.ReportMinerData = $true
    }

    #Apply watchdog to miners
    $Miners = $Miners | Where-Object {
        $Miner = $_
        $Miner_WatchdogTimers = $Script:WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Session.Timer.AddSeconds( - $Session.WatchdogInterval) | Where-Object Kicked -GT $Session.Timer.AddSeconds( - $Session.WatchdogReset)
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1 -and ($Session.Config.DisableDualMining -or $Miner.HashRates.PSObject.Properties.Name.Count -eq 1 -or -not ($Miner.Pools.PSObject.Properties.Value | Where-Object Exclusive))
    }
    if ($Miner_WatchdogTimers -ne $null) {Remove-Variable "Miner_WatchdogTimers"}

    #Give API access to the miners information
    $API.Miners = $Miners

    #Remove all failed and disabled miners
    $Miners = $Miners | Where-Object {-not $_.Disabled -and $_.HashRates.PSObject.Properties.Value -notcontains 0}

    #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    if ($Session.Config.FastestMinerOnly) {$Miners = $Miners | Sort-Object -Descending {"$($_.DeviceName -join '')$($_.BaseAlgorithm -replace '-')$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {([Double]($_ | Measure-Object Profit_Bias -Sum).Sum)}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm -replace '-')$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"} | Foreach-Object {$_.Group[0]}}
 
    #Give API access to the fasted miners information
    $API.FastestMiners = $Miners

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used
    $MinersNeedingBenchmark = $Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null}
    $MinersNeedingBenchmarkCount = ($MinersNeedingBenchmark | Measure-Object).Count
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark

    #Update the active miners
    $Script:ActiveMiners | Foreach-Object {
        $_.Profit = 0
        $_.Profit_Bias = 0
        $_.Profit_Unbias = 0
        $_.Profit_Cost = 0
        $_.Best = $false
        $_.Stopped = $false
        $_.Enabled = $false
        $_.IsFocusWalletMiner = $false
        $_.IsExclusiveMiner = $false
        $_.IsLocked = $false
        $_.PostBlockMining = 0
        $_.IsRunningFirstRounds = $false
    }
    $Miners | ForEach-Object {
        $Miner = $_
        $ActiveMiner = $Script:ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and
            $_.Path -eq $Miner.Path -and
            $_.Arguments -eq $Miner.Arguments -and
            $_.API -eq $Miner.API -and
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }

        $FirstAlgoName            = $Miner.HashRates.PSObject.Properties.Name | Select-Object -First 1

        $Miner_MinSamples         = if ($Miner.MinSamples) {$Miner.MinSamples} else {3} #min. 10 seconds, 3 samples needed
        $Miner_IsFocusWalletMiner = ($Session.Config.Pools."$($Miner.Pools.PSObject.Properties.Value.Name)".FocusWallet -and $Session.Config.Pools."$($Miner.Pools.PSObject.Properties.Value.Name)".FocusWallet.Count -gt 0 -and (Compare-Object $Session.Config.Pools."$($Miner.Pools.PSObject.Properties.Value.Name)".FocusWallet $Miner.Pools.PSObject.Properties.Value.Currency -IncludeEqual -ExcludeDifferent))
        $Miner_IsExclusiveMiner   = (($Miner.Pools.PSObject.Properties.Value | Where-Object Exclusive | Measure-Object).Count -gt 0)
        $Miner_IsLocked           = ($LockMiners -and $Session.LockMiners.Pools -and -not (Compare-Object $Session.LockMiners.Pools @($Miner.Pools.PSObject.Properties.Name | Foreach-Object {"$($Miner.Pools.$_.Name)-$($Miner.Pools.$_.Algorithm -replace "\-.+$")-$($Miner.Pools.$_.CoinSymbol)"} | Select-Object -Unique)))

        $Miner_CoinSymbol         = $Miner.Pools.$FirstAlgoName.CoinSymbol
        $Miner_PostBlockMining    = $(if ($Miner.Pools.$FirstAlgoName.TSL -ne $null -and $Session.Config.Pools."$($Miner.Pools.$FirstAlgoName.Name)".EnablePostBlockMining -and $Miner_CoinSymbol -and $Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining -and ($Miner.Pools.$FirstAlgoName.TSL -lt $Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining)) {$Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining - $Miner.Pools.$FirstAlgoName.TSL} else {0})

        $Miner_ManualUri          = if (-not $Miner.ManualUri -and $Miner.Uri -notmatch "RainbowMiner" -and $Miner.Uri -match "^(.+?github.com/.+?/releases)") {$Matches[1]} else {$Miner.ManualUri}

        $Miner_MaxRejectedShareRatio = [Double]$(if ($Miner.MaxRejectedShareRatio -eq $null) {$Session.Config.MaxRejectedShareRatio} else {$Miner.MaxRejectedShareRatio})
        if ($Miner_MaxRejectedShareRatio -lt 0) {$Miner_MaxRejectedShareRatio = 0}
        elseif ($Miner_MaxRejectedShareRatio -gt 1) {$Miner_MaxRejectedShareRatio = 1}

        if ($ActiveMiner) {
            $ActiveMiner.Version            = $Miner.Version
            $ActiveMiner.Profit             = $Miner.Profit
            $ActiveMiner.Profit_Bias        = $Miner.Profit_Bias
            $ActiveMiner.Profit_Unbias      = $Miner.Profit_Unbias
            $ActiveMiner.Profit_Cost        = $Miner.Profit_Cost
            $ActiveMiner.PowerDraw          = $Miner.PowerDraw
            $ActiveMiner.Speed              = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            $ActiveMiner.DeviceName         = $Miner.DeviceName
            $ActiveMiner.DeviceModel        = $Miner.DeviceModel
            $ActiveMiner.ShowMinerWindow    = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow -or $IsLinux)
            $ActiveMiner.MSIAprofile        = $Miner.MSIAprofile
            $ActiveMiner.FaultTolerance     = $Miner.FaultTolerance
            $ActiveMiner.Penalty            = $Miner.Penalty
            $ActiveMiner.PoolPenalty        = $Miner.Pools.PSObject.Properties.Value.Penalty
            $ActiveMiner.ManualUri          = $Miner_ManualUri
            $ActiveMiner.EthPillEnable      = $Session.Config.EthPillEnable
            $ActiveMiner.EthPillEnableMTP   = $Session.Config.EthPillEnableMTP
            $ActiveMiner.DataInterval       = $Session.Config.BenchmarkInterval
            $ActiveMiner.EnableAutoPort     = $Session.Config.EnableAutoMinerPorts
            $ActiveMiner.Enabled            = $true
            $ActiveMiner.IsFocusWalletMiner = $Miner_IsFocusWalletMiner
            $ActiveMiner.IsExclusiveMiner   = $Miner_IsExclusiveMiner
            $ActiveMiner.IsLocked           = $Miner_IsLocked
            $ActiveMiner.PostBlockMining    = $Miner_PostBlockMining
            $ActiveMiner.MinSamples         = $Miner_MinSamples
            $ActiveMiner.CoinName           = $Miner.Pools.PSObject.Properties.Value.CoinName
            $ActiveMiner.CoinSymbol         = $Miner.Pools.PSObject.Properties.Value.CoinSymbol
            $ActiveMiner.EnvVars            = $Miner.EnvVars
            $ActiveMiner.StartCommand       = $Miner.StartCommand
            $ActiveMiner.StopCommand        = $Miner.StopCommand
            $ActiveMiner.NoCPUMining        = [bool]$Miner.NoCPUMining
            $ActiveMiner.NeedsBenchmark     = $Miner.HashRates.PSObject.Properties.Value -contains $null
            $ActiveMiner.MaxRejectedShareRatio = $Miner_MaxRejectedShareRatio
            $ActiveMiner.MiningPriority     = $Miner.MiningPriority
            $ActiveMiner.MiningAffinity     = $Miner.MiningAffinity
            $ActiveMiner.MultiProcess       = [int]$Miner.MultiProcess

            $Miner_DevFee = $Miner.DevFee | ConvertTo-Json -Depth 10 -Compress -ErrorAction Ignore
            if (($ActiveMiner.DevFee | ConvertTo-Json -Depth 10 -Compress -ErrorAction Ignore) -ne $Miner_DevFee) {
                $ActiveMiner.DevFee         = $Miner_DevFee | ConvertFrom-Json -ErrorAction Ignore
            }

            if (Compare-Object @($ActiveMiner.OCprofile.GetEnumerator() | Foreach-Object {"$($_.Name):$($_.Value)"}) @($Miner.OCprofile.GetEnumerator() | Foreach-Object {"$($_.Name):$($_.Value)"})) {
                $ActiveMiner.OCprofile      = $Miner.OCprofile.Clone()
            }
        }
        else {
            Write-Log -Level Info "New miner object $($Miner.BaseName): $($Miner.HashRates.PSObject.Properties.Name -join '+')"
            $NewMiner = New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                Version              = $Miner.Version
                BaseName             = $Miner.BaseName
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                BaseAlgorithm        = @($Miner.BaseAlgorithm -split '-' | Select-Object)
                Currency             = $Miner.Pools.PSObject.Properties.Value.Currency
                CoinName             = $Miner.Pools.PSObject.Properties.Value.CoinName
                CoinSymbol           = $Miner.Pools.PSObject.Properties.Value.CoinSymbol
                DeviceName           = $Miner.DeviceName
                DeviceModel          = $Miner.DeviceModel
                Profit               = $Miner.Profit
                Profit_Bias          = $Miner.Profit_Bias
                Profit_Unbias        = $Miner.Profit_Unbias
                Profit_Cost          = $Miner.Profit_Cost
                PowerDraw            = $Miner.PowerDraw
                Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                Speed_Live           = 0
                Variance             = $Miner.Hashrates.PSObject.Properties.Name | Foreach-Object {0.0}
                StartCommand         = $Miner.StartCommand
                StopCommand          = $Miner.StopCommand
                Best                 = $false
                New                  = $false
                Benchmarked          = 0
                Pool                 = $Miner.Pools.PSObject.Properties.Value.Name
                MSIAprofile          = $Miner.MSIAprofile
                OCprofile            = $Miner.OCprofile.Clone()
                DevFee               = $Miner.DevFee | ConvertTo-Json -Depth 10 -Compress -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
                ExtendInterval       = $Miner.ExtendInterval
                ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow -or $IsLinux)
                FaultTolerance       = $Miner.FaultTolerance
                Penalty              = $Miner.Penalty
                PoolPenalty          = $Miner.Pools.PSObject.Properties.Value.Penalty
                ManualUri            = $Miner_ManualUri
                EthPillEnable        = $Session.Config.EthPillEnable
                EthPillEnableMTP     = $Session.Config.EthPillEnableMTP
                DataInterval         = $Session.Config.BenchmarkInterval
                Donator              = $Session.IsDonationRun
                MaxBenchmarkRounds   = $Session.Strikes
                EnableAutoPort       = $Session.Config.EnableAutoMinerPorts
                Enabled              = $true
                IsFocusWalletMiner   = $Miner_IsFocusWalletMiner
                IsExclusiveMiner     = $Miner_IsExclusiveMiner
                IsLocked             = $Miner_IsLocked
                PostBlockMining      = $Miner_PostBlockMining
                MinSamples           = $Miner_MinSamples
                EnvVars              = $Miner.EnvVars
                NoCPUMining          = [bool]$Miner.NoCPUMining
                NeedsBenchmark       = $Miner.HashRates.PSObject.Properties.Value -contains $null
                MaxRejectedShareRatio= $Miner_MaxRejectedShareRatio
                MiningPriority       = $Miner.MiningPriority
                MiningAffinity       = $Miner.MiningAffinity
                MultiProcess         = [int]$Miner.MultiProcess
            }
            $Script:ActiveMiners.Add($NewMiner) > $null
        }
    }

    if ($Miner_DevFee -ne $null) {Remove-Variable "Miner_DevFee"}

    $Script:ActiveMiners_DeviceNames = @($Script:ActiveMiners | Where-Object Enabled | Select-Object -ExpandProperty DeviceName -Unique | Sort-Object)

    #Don't penalize active miners and control round behavior
    $Script:ActiveMiners | Where-Object {$Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching -or ($_.GetStatus() -eq [MinerStatus]::Running)} | Foreach-Object {
        $_.Profit_Bias = $_.Profit_Unbias
        if (-not ($Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching) -or ($_.GetStatus() -eq [MinerStatus]::Running)) {
            if ($_.Rounds -lt $Session.Config.MinimumMiningIntervals -and -not $Session.IsBenchmarkingRun) {$_.IsRunningFirstRounds=$true}
            if (-not ($Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching) -and $Session.Config.MinerSwitchingHysteresis) {
                $_.Profit_Bias *= 1+($Session.Config.MinerSwitchingHysteresis/100)
            }
        }
    }

    $Session.Profitable = $true

    $PowerOffset_Watt = [Double]0
    $PowerOffset_Cost = [Double]0

    if (($Miners | Measure-Object).Count -gt 0) {
        #Get most profitable miner combination
        $BestMiners             = $Script:ActiveMiners | Where-Object Enabled | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($Script:ActiveMiners | Where-Object {$_.Enabled -and (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}

        #If post block mining: check for minimum profit
        if ($Miners_PBM = $BestMiners | Where-Object {$_.PostBlockMining -gt 0 -and -not $_.IsExclusiveMiner -and -not $_.IsLocked -and -not $_.IsFocusWalletMiner -and -not $_.NeedsBenchmark -and -not $_.IsRunningFirstRounds -and $Session.Config.Coins."$($_.CoinSymbol)".MinProfitPercent -gt 0}) {
            $Miners_PBM | Foreach-Object {
                $Miner_PBM = $_
                $BestMiner = $Script:ActiveMiners | Where-Object {$_.Enabled -and $_.PostBlockMining -eq 0 -and (Compare-Object $Miner_PBM.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1
                $BestMiner_Profit = $BestMiner.Profit + $(if ($Session.Config.UsePowerPrice -and $BestMiner.Profit_Cost -ne $null -and $BestMiner.Profit_Cost -gt 0) {$BestMiner.Profit_Cost})
                $Miner_PBM_Profit = $Miner_PBM.Profit + $(if ($Session.Config.UsePowerPrice -and $Miner_PBM.Profit_Cost -ne $null -and $Miner_PBM.Profit_Cost -gt 0) {$Miner_PBM.Profit_Cost})
                if ($BestMiner -and ($BestMiner_Profit * $Session.Config.Coins."$($Miner_PBM.CoinSymbol)".MinProfitPercent / 100 -gt $Miner_PBM_Profit)) {
                    $BestMiners = (@($BestMiners | Select-Object) + $BestMiner) | Where-Object {$_ -ne $Miner_PBM}
                }
            }
        }
        if ($Miners_PBM -ne $null) {Remove-Variable "Miners_PBM"}

        $NoCPUMining = $Session.Config.EnableCheckMiningConflict -and $MinersNeedingBenchmarkCount -eq 0 -and ($BestMiners | Where-Object DeviceModel -eq "CPU" | Measure-Object).Count -and ($BestMiners | Where-Object NoCPUMining -eq $true | Measure-Object).Count
        if ($NoCPUMining) {$BestMiners2 = $Script:ActiveMiners | Where-Object Enabled | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($Script:ActiveMiners | Where-Object {-not $_.NoCPUMining -and $_.Enabled -and (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}}

        $Check_Profitability = $false
        if ($Session.Config.UsePowerPrice -and $MinersNeedingBenchmarkCount -eq 0) {
            #Remove no longer profitable miners
            if ($Session.Config.CheckProfitability) {
                $BestMiners = $BestMiners | Where {$_.Profit -gt 0 -or $_.IsExclusiveMiner -or $_.IsLocked}
                if ($BestMiners2) {$BestMiners2 = $BestMiners2 | Where {$_.Profit -gt 0 -or $_.IsExclusiveMiner -or $_.IsLocked}}
            }
            $Check_Profitability = $true
        }

        if ($NoCPUMining) {        
            $BestMiners_Message = "CPU"
            $BestMiners_Combo  = Get-BestMinerDeviceCombos @($BestMiners | Where-Object DeviceModel -ne "CPU") -SortBy "Profit_Bias"
            if ($MinersNeedingBenchmarkCount -eq 0) {
                $BestMiners_Combo2 = Get-BestMinerDeviceCombos $BestMiners2 -SortBy "Profit_Bias"
                if (($BestMiners_Combo.Profit | Measure-Object -Sum).Sum -lt ($BestMiners_Combo2.Profit | Measure-Object -Sum).Sum) {
                    $BestMiners_Message = "GPU-only"
                    $BestMiners_Combo = $BestMiners_Combo2
                }
            }
            $BestMiners_Message = "GPU/CPU mining conflict: $($BestMiners_Message) will not be started for best profit"
        } else {
            $BestMiners_Combo = Get-BestMinerDeviceCombos $BestMiners -SortBy "Profit_Bias"        
        }

        #Prefer multi-miner over single-miners
        if ($Session.Config.MiningMode -eq "combo" -and $MinersNeedingBenchmarkCount -eq 0 -and ($Session.DeviceCombos -match '-' | Measure-Object).Count) {
            $BestMiners_Combo = $BestMiners_Combo | Group-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.Algorithm -join '')$($_.Currency)$($_.CoinSymbol)"} | Foreach-Object {
                $Combo_Name    = $_.Name
                $Combo_Devices = @($_.Group.DeviceName | Select-Object -Unique | Sort-Object)
                $BestMiners_Multi = if ($_.Count -gt 1) {$BestMiners | Where-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.Algorithm -join '')$($_.Currency)$($_.CoinSymbol)" -eq $Combo_Name -and (Compare-Object $_.DeviceName $Combo_Devices | Measure-Object).Count -eq 0} | Sort-Object Profit_Bias -Descending | Select-Object -First 1}
                if ($BestMiners_Multi -and (($_.Group.Profit_Bias | Measure-Object -Sum).Sum*$Session.Config.MinComboOverSingleRatio -lt $BestMiners_Multi.Profit_Bias)) {$BestMiners_Multi} else {$_.Group}
            }
        }

        if (($Script:AllPools | Measure-Object).Count -gt 0 -and $Check_Profitability) {
            $PowerOffset_Watt = $Session.Config.PowerOffset
            if ($Session.Config.PowerOffsetPercent -gt 0) {
                $PowerOffset_Watt += ($BestMiners_Combo.PowerDraw | Measure-Object -Sum).Sum * $Session.Config.PowerOffsetPercent / 100
            }
            $PowerOffset_Cost = [Double]($PowerOffset_Watt*24/1000 * $PowerPriceBTC)
            if ((($BestMiners_Combo.Profit | Measure-Object -Sum).Sum - $PowerOffset_Cost) -le 0) {
                if ($Session.Config.CheckProfitability -and ($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner -or $_.IsLocked} | Measure-Object).Count -eq 0) {$Session.Profitable = $false}
                if (-not $Session.Profitable -or -not $Session.Config.CheckProfitability) {
                    Write-Log -Level Warn "No more miners are profitable. $(if ($Session.Config.CheckProfitability) {" Waiting for profitability."})"
                }
            }
        }

        if ($Session.PauseMinersByScheduler -and ($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner} | Measure-Object).Count) {$Session.PauseMinersByScheduler = $false}

        if (-not $Session.PauseMiners -and -not $Session.PauseMinersByScheduler -and -not $Session.AutoUpdate -and $Session.Profitable) {
            $BestMiners_Combo | ForEach-Object {$_.Best = $true}
        }
    }

    if ($BestMiners_Combo -ne $null) {Remove-Variable "BestMiners_Combo"}
    if ($BestMiners_Combo2 -ne $null) {Remove-Variable "BestMiners_Combo2"}


    if ($Session.RoundCounter -eq 0) {Write-Host "Starting mining operation .."}

    #Stop failed miners
    $Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::RunningFailed} | Foreach-Object {
        Write-Log -Level Info "Stopping crashed miner ($($_.Name)) "
        $_.CrashCount++
        Write-ActivityLog $_ -Crashed 1
        $_.SetStatus([MinerStatus]::Idle)
    }

    #Stop or start miners in the active list depending on if they are the most profitable
    $Script:ActiveMiners | Where-Object {(($_.Best -EQ $false) -or $Session.RestartMiners) -and $_.GetActivateCount() -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {
        $Miner = $_
        Write-Log -Level Info "Stopping miner $($Miner.Name) on pool $($Miner.Pool -join '/'). "
        $Miner.SetStatus([MinerStatus]::Idle)
        $Miner.Stopped = $true

        #Remove watchdog timer
        if ($Session.Config.Watchdog -and $Script:WatchdogTimers.Count) {
            $Miner_Name = $Miner.Name
            $Miner_Index = 0
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $Miner_Pool = $Miner.Pool[$Miner_Index]
                $WatchdogTimer = $Script:WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Miner_Pool -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if (($WatchdogTimer.Kicked -lt $Session.Timer.AddSeconds( - $Session.WatchdogInterval)) -and -not $Session.RestartMiners) {
                        Write-ActivityLog $Miner -Crashed 2
                        $Miner.SetStatus([MinerStatus]::Failed)
                        Write-Log -Level Warn "Miner $Miner_Name mining $($Miner_Algorithm) on pool $($Miner_Pool) temporarily disabled. "
                    }
                    else {
                        $Script:WatchdogTimers.Remove($WatchdogTimer)
                    }
                }
                $Miner_Index++
            }
        }
    }
    
    if ($IsWindows) {
        Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {$_.ExecutablePath -like "$(Get-Location)\Bin\*"} | Where-Object {@($Script:ActiveMiners | Foreach-Object {$_.GetProcessIds()} | Where-Object {$_} | Select-Object -Unique) -notcontains $_.ProcessId -and @($Script:ActiveMiners | Select-Object -ExpandProperty Path | Split-Path -Leaf | Select-Object -unique) -icontains $_.ProcessName} | Select-Object ProcessId,ProcessName | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore}
    } elseif ($IsLinux) {
        Get-Process | Where-Object Path | Where-Object {$_.Path -like "$(Get-Location)/bin/*"} | Where-Object {-not (Compare-Object @($Script:ActiveMiners | Foreach-Object {$_.GetProcessIds()} | Where-Object {$_} | Select-Object -Unique) @($_.Id,$_.Parent.Id) -ExcludeDifferent -IncludeEqual) -and @($Script:ActiveMiners | Select-Object -ExpandProperty Path | Split-Path -Leaf | Select-Object -unique) -icontains $_.ProcessName} | Select-Object Id,ProcessName | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.Id)"; if (Test-OCDaemon) {Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null} else {Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }

    if ($Session.Downloader.HasMoreData) {$Session.Downloader | Receive-Job}
    if ($Session.Config.Delay -gt 0) {Start-Sleep $Session.Config.Delay} #Wait to prevent BSOD

    $Script:ActiveMiners | Where-Object {$_.Best -EQ $true -and $_.GetStatus() -ne [MinerStatus]::Running} | ForEach-Object {

        if ($_.DeviceModel -ne "CPU") {
            if ($Session.Config.EnableResetVega) {Reset-Vega $_.DeviceName}

            #Set MSI Afterburner profile
            if ($MSIAenabled) {
                $MSIAplannedprofile = $Script:ActiveMiners | Where-Object {$_.Best -eq $true -and $_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0} | Select-Object -ExpandProperty MSIAprofile -Unique
                if (-not $MSIAplannedprofile.Count) {$MSIAplannedprofile = $Session.Config.MSIAprofile}                
                else {$MSIAplannedprofile = $MSIAplannedprofile | Select-Object -Index 0}
                Start-Process -FilePath "$($Session.Config.MSIApath)" -ArgumentList "-Profile$($MSIAplannedprofile)" -Verb RunAs
                if ($MSIAplannedprofile -ne $Session.MSIAcurrentprofile) {
                    Write-Log "New MSI Afterburner profile set: $($MSIAplannedprofile)"                
                    $Session.MSIAcurrentprofile = $MSIAplannedprofile
                    Start-Sleep 1
                }
            } elseif ($Session.Config.EnableOCprofiles) {
                $_.SetOCprofile($Session.Config,500)
                if ($IsLinux) {Invoke-OCDaemon -Quiet}
            }
        }

        if ($_.Speed -contains $null) {
            Write-Log "Benchmarking miner ($($_.Name)): '$($_.Path) $($_.Arguments)' (Extend Interval $($_.ExtendInterval))"
        }
        else {
            Write-Log "Starting miner ($($_.Name)): '$($_.Path) $($_.Arguments)'"
        }            
        $Session.DecayStart = $Session.Timer

        $_.SetPriorities(
            $(if ($_.MiningPriority -ne $null) {$_.MiningPriority} else {$Session.Config.MiningPriorityCPU}),
            $(if ($_.MiningPriority -ne $null) {$_.MiningPriority} else {$Session.Config.MiningPriorityGPU}),
            $(if ($_.MiningAffinity -ne $null) {$_.MiningAffinity} elseif ($_.DeviceModel -ne "CPU") {$Session.Config.GPUMiningAffinity})
        )

        $Session.DecayStart = (Get-Date).ToUniversalTime()

        $_.SetStatus([MinerStatus]::Running)

        #Add watchdog timer
        if ($Session.Config.Watchdog -and $_.Profit -ne $null) {
            $Miner_Name = $_.Name
            $Miner_DeviceModel = $_.DeviceModel
            $_.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $Script:WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if (-not $WatchdogTimer) {
                    $Script:WatchdogTimers.Add([PSCustomObject]@{
                        MinerName = $Miner_Name
                        DeviceModel= $Miner_DeviceModel
                        PoolName  = $Pools.$Miner_Algorithm.Name
                        Algorithm = $Miner_Algorithm
                        Kicked    = $Session.Timer
                    }) > $null
                }
                elseif (-not ($WatchdogTimer.Kicked -GT $Session.Timer.AddSeconds( - $Session.WatchdogReset))) {
                    $WatchdogTimer.Kicked = $Session.Timer
                }
            }
        }
    }

    if ($Pools -ne $null) {Remove-Variable "Pools"}

    $IsExclusiveRun = $Session.IsExclusiveRun
    $Session.IsExclusiveRun = ($Script:ActiveMiners | Where-Object {$_.IsExclusiveMiner -and $_.GetStatus() -eq [MinerStatus]::Running} | Measure-Object).Count -gt 0

    #Move donation run into the future, if benchmarks are ongoing
    if ((-not $Session.IsDonationRun -and $MinersNeedingBenchmarkCount -gt 0) -or $Session.IsExclusiveRun) {
        $ShiftDonationRun = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)
        if (-not $Session.LastDonated -or $Session.LastDonated -lt $ShiftDonationRun) {$Session.LastDonated = Set-LastDrun $ShiftDonationRun}
    }

    #Update API miner information
    #$RunningMiners = $Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {$_ | Add-Member ActiveTime $_.GetActiveTime() -Force -PassThru}
    $API.WatchdogTimers = $Script:WatchdogTimers
    $API.ActiveMiners   = $Script:ActiveMiners | Where-Object {$_.Profit -or $_.IsFocusWalletMiner}
    $API.RunningMiners  = $Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running}
    $API.FailedMiners   = $Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Failed}

    #
    #Start output to host
    #
    Clear-Host

    if ([Math]::Abs($Session.TimeDiff) -gt 60) {
        Write-Host " "
        Write-Log -Level Warn "This rig's system time is off by $($Session.TimeDiff) seconds. Please adjust and restart RainbowMiner!"
        Write-Host " "
    }

    $Session.Benchmarking = -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and $MinersNeedingBenchmarkCount -gt 0
    if ($Session.Benchmarking) {$Session.IsBenchmarkingRun = $true}

    $LimitMiners = if ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) {100} else {3}

    if ($Session.Benchmarking) {$Session.Updatetracker.MinerSave = 0}

    #Display mining information
    $Running = $false
    if (($Session.Devices | Measure-Object).Count -eq 0) {
        Write-Host " "
        Write-Log -Level Warn "No devices available. Running in pause mode, only. "
        Write-Host " "
    } elseif (($Script:AllPools | Measure-Object).Count -eq 0) {
        Write-Host " "
        Write-Log -Level Warn "No pools available: $(if ($AllPools_BeforeWD_Count -gt 0 ) {"disabled by Watchdog"} else {"check your configuration"})"
        Write-Host " "
    } elseif (($Miners | Measure-Object).Count -eq 0) {
        Write-Host " "
        Write-Log -Level Warn "No miners available: $(if ($Miners_Downloading -gt 0) {"Downloading miners, please be patient"} elseif ($Miners_BeforeWD_Count -gt 0) {"disabled by Watchdog"} else {"check your configuration"})"
        Write-Host " "
    } else {
        $Running = $true
    }
    if ($Session.ConfigFiles.Values.Healthy -contains $false) {
        Write-Host " "
        $Session.ConfigFiles.GetEnumerator() | Where-Object {-not $_.Value.Healthy} | Foreach-Object {
            Write-Log -Level Warn "Invalid JSON format in $($_.Value.Path)"
        }
        Write-Host " "
        Write-Host "Correct or delete the invalid config files! E.g. use https://jsonlint.com to validate " -ForegroundColor Yellow
        Write-Host " "
    }

    $Miners | Select-Object DeviceName, DeviceModel -Unique | Sort-Object DeviceModel | ForEach-Object {
        $Miner_DeviceName = $_.DeviceName
        $Miner_DeviceModel = $_.DeviceModel
        $Miner_DeviceModels = $Miner_DeviceModel -split '-'
        $Miner_ProfitMin = if ($Miner_DeviceModel -match "CPU") {1E-9} else {1E-7}
        $Miner_DeviceTitle = @($Session.Devices | Where-Object {$Miner_DeviceModels -icontains $_.Model} | Select-Object -ExpandProperty Model_Name -Unique | Sort-Object | Foreach-Object {"$($_) ($(@($Session.Devices | Where-Object Model_Name -eq $_ | Select-Object -ExpandProperty Name | Sort-Object) -join ','))"}) -join ', '
        Write-Host $Miner_DeviceTitle
        Write-Host $("=" * $Miner_DeviceTitle.Length)

        [System.Collections.ArrayList]$Miner_Table = @(
            @{Label = "Miner"; Expression = {$_.Name -replace '\-.*$'}},
            @{Label = "Fee"; Expression = {$m = $_;($m.HashRates.PSObject.Properties.Name | ForEach-Object {if ($m.DevFee.$_) {'{0:p2}' -f ($m.DevFee.$_/100) -replace ",*0+\s%"," %"}else {"-"}}) -join ','}; Align = 'right'},
            @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.HashRates.PSObject.Properties.Name}},
            @{Label = "Speed"; Expression = {$_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"} elseif ($Session.Benchmarking) {"Benchmarking"} else {"Waiting"}}}; Align = 'right'},
            @{Label = "Diff"; Expression = {$m = $_;($m.HashRates.PSObject.Properties.Name | ForEach-Object {if ($m.Difficulties.$_) {($m.Difficulties.$_ | ConvertTo-Float) -replace " "} else {"-"}}) -join ','}; Align = 'right'},
            @{Label = "Power$(if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}; Align = 'right'}
        )
        foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Table.Add(@{Label = "$Miner_Currency/Day $($_.Profit)"; Expression = [scriptblock]::Create("if (`$_.Profit -and `"$($Session.Rates.$Miner_Currency)`") {ConvertTo-LocalCurrency `$(`$_.Profit) $($Session.Rates.$Miner_Currency) -Offset 2} else {`"Unknown`"}"); Align = "right"}) > $null
        }
        $Miner_Table.AddRange(@(
            @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}}; Align = 'right'}, 
            @{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.CoinName) {"-$($_.CoinName)"})"}}}
            @{Label = "PoolFee"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.PoolFee) {'{0:p2}' -f ($_.PoolFee/100) -replace ",*0+\s%"," %"}else {"-"}}}; Align = 'right'}
        )) > $null

        $Miners | Where-Object {$_.DeviceModel -eq $Miner_DeviceModel} | Where-Object {($Session.Config.UIstyle -ne "full" -and $_.Speed -gt 0) -or ($_.Profit+$(if ($Session.Config.UsePowerPrice -and $_.Profit_Cost -ne $null -and $_.Profit_Cost -gt 0) {$_.Profit_Cost})) -ge $Miner_ProfitMin -or $_.Profit -eq $null} | Sort-Object DeviceModel, @{Expression = {if ($Session.Benchmarking) {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($Session.Benchmarking) {$_.Profit}}; Descending = $true}, @{Expression = {if ($Session.IsExclusiveRun -or $Session.IsDonationRun -or $MinersNeedingBenchmarkCount -lt 1) {[double]$_.Profit_Bias}}; Descending = $true} | Select-Object -First $($LimitMiners) | Format-Table $Miner_Table | Out-Host        
    }

    if ($Session.RestartMiners) {
        Write-Host "Miners have been restarted!" -ForegroundColor Yellow
        Write-Host " "
        $Session.RestartMiners = $false
    }
    if ($Session.PauseMiners) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED" -ForegroundColor Red
        Write-Host " (press P to resume)"
        Write-Host " "
    } elseif ($Session.PauseMinersByScheduler) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED BY SCHEDULER" -ForegroundColor Red
        Write-Host " (edit scheduler.config.txt to change)"
        Write-Host " "
    } elseif (-not $Session.Profitable) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "WAITING FOR PROFITABILITY" -ForegroundColor Red
        Write-Host " (be patient or set CheckProfitability to 0 to resume)"
        Write-Host " "
    } else {

        if ($LockMiners) {
            Write-Host -NoNewline "Status: "
            Write-Host -NoNewLine "LOCKED" -ForegroundColor Cyan
            Write-Host -NoNewline " to $($Session.LockMiners.Pools -join ", ")"
            Write-Host " (press L to unlock)"
            Write-Host " "
        }

        if ($Session.Benchmarking -or $Miners_Downloading -gt 0) {Write-Host " "}
        #Display benchmarking progress
        if ($Session.Benchmarking) {
            Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmarkCount) miner$(if ($MinersNeedingBenchmarkCount -gt 1){'s'}) left, interval is set to $($Session.Config.BenchmarkInterval) seconds."
            $MinersNeedingBenchmarkWithEI = ($MinersNeedingBenchmark | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Measure-Object).Count
            if (-not $Session.Config.DisableExtendInterval -and $MinersNeedingBenchmarkWithEI -gt 0) {
                $BenchmarkMinutes = [Math]::Ceiling($Session.Config.BenchmarkInterval/60)
                Write-Host " "
                Write-Host "Please be patient!" -BackgroundColor Yellow -ForegroundColor Black
                Write-Host "RainbowMiner will benchmark the following $($MinersNeedingBenchmarkWithEI) miner$(if ($MinersNeedingBenchmarkWithEI -gt 1){'s'}) with extended intervals!" -ForegroundColor Yellow
                Write-Host "These algorithm need a longer time to reach an accurate average hashrate." -ForegroundColor Yellow
                Write-Host "After that, benchmarking will be much faster ($($BenchmarkMinutes)-$($BenchmarkMinutes*2) minutes per miner)." -ForegroundColor Yellow
                Write-Host "If you do not want that accuracy, set DisableExtendInterval to 0 in your config.txt" -ForegroundColor Yellow
                $OldForegroundColor = [console]::ForegroundColor
                [console]::ForegroundColor = "Yellow"
                $MinersNeedingBenchmark | Select-Object BaseName,BaseAlgorithm,ExtendInterval | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Sort-Object -Property @{Expression = {$_.ExtendInterval}; Descending = $True},@{Expression = {"$($_.BaseName)-$($_.BaseAlgorithm)"}; Descending = $False} | Format-Table (
                    @{Label = "Miner"; Expression = {$_.BaseName}},
                    @{Label = "Algorithms"; Expression = {$_.BaseAlgorithm}},
                    @{Label = "Aprox. Time"; Expression = {"$($BenchmarkMinutes*$_.ExtendInterval)-$($BenchmarkMinutes*$_.ExtendInterval*2) minutes"}}
                ) | Out-Host

                if ($MinersNeedingBenchmark -ne $null) {Remove-Variable "MinersNeedingBenchmark"}

                [console]::ForegroundColor = $OldForegroundColor
            }
        }
        if ($Miners_Downloading -gt 0) {
            Write-Log -Level Warn "Download in progress: $($Miners_Downloading) miner$(if($Miners_Downloading -gt 1){"s"}) left. Command windows will popup during extraction."
        }
        if ($NoCPUMining) {
            Write-Log -Level Warn $BestMiners_Message
        }
    }

    #Display active miners list
    $Script:ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and ($_.GetStatus() -eq [MinerStatus]::Running -or (-not $_.Donator -and ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) -and ($_.GetActiveLast() -gt (Get-Date).AddSeconds(-5*$Session.Config.Interval))))} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} -Wrap (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd}d/{0:hh}h/{0:mm}m" -f $_.GetActiveTime()}}, 
        @{Label = "Started"; Expression = {Switch ($_.GetActivateCount()) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}},      
        @{Label = "Miner"; Expression = {"$($_.Name -replace '\-.*$')$(if ($_.IsFocusWalletMiner -or $_.IsExclusiveMiner) {"(!)"} elseif ($_.PostBlockMining -gt 0) {"($($_.PostBlockMining)s)"} elseif ($Session.Config.MinimumMiningIntervals -gt 1 -and $MinersNeedingBenchmarkCount -eq 0 -and ($_.IsRunningFirstRounds -or ($_.Rounds -eq 0 -and $_.GetStatus() -eq [MinerStatus]::Running))) {"($($_.Rounds+1)/$($Session.Config.MinimumMiningIntervals))"})"}},
        @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.BaseAlgorithm}},
        @{Label = "Coin"; Expression = {$_.CoinName | Foreach-Object {if ($_) {$_} else {"-"}}}},
        @{Label = "Device"; Expression = {@(Get-DeviceModelName $Session.Devices -Name @($_.DeviceName) -Short) -join ','}},
        @{Label = "Power$(if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}},
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.GetArguments())"}}
    ) | Out-Host

    if ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) {
        #Display watchdog timers
        $Script:WatchdogTimers | Where-Object Kicked -gt $Session.Timer.AddSeconds( - $Session.WatchdogReset) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName -replace '\-.*$'}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Session.Devices -Name @($_.DeviceName) -Short) -join ','}}, 
            @{Label = "Pool"; Expression = {$_.PoolName}}, 
            @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.Algorithm}}, 
            @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Session.Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
        ) | Out-Host
    }

    if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)) {Write-Host "* net power consumption. A base power offset of $(if ($Session.Config.PowerOffsetPercent -gt 0) {"{0:f1}%" -f $Session.Config.PowerOffsetPercent})$(if ($Session.Config.PowerOffset -gt 0) {if ($Session.Config.PowerOffsetPercent -gt 0) {" +"};"{0:d}W" -f [int]$Session.Config.PowerOffset}) is being added to calculate the final profit$(if ($PowerOffset_Watt -gt 0) { " (currently {0:d}W)" -f [int]$PowerOffset_Watt})."; Write-Host " "}

    #Display pool balances, formatting it to show all the user specified currencies
    if ($Session.Config.ShowPoolBalances -and $BalancesData -and $BalancesData.Count -gt 1) {
        $ColumnMark = if ($Session.EnableColors) {"$([char]27)[93m{value}$([char]27)[0m"} else {"{value}"}
        $NextBalances = $Session.Config.BalanceUpdateMinutes-[int]((Get-Date).ToUniversalTime()-$Session.Updatetracker.Balances).TotalMinutes
        $NextBalances = if ($NextBalances -gt 0){"in $($NextBalances) minutes"}else{"now"}
        Write-Host "Pool Balances as of $([System.Timezone]::CurrentTimeZone.ToLocalTime($Session.Updatetracker.Balances)) (next update $($NextBalances)): "        
        [System.Collections.ArrayList]$ColumnFormat = @()
        $ColumnFormat.Add(@{Name = "Name"; Expression = "Name"}) > $null
        if (($BalancesData.Currency | Select-Object -Unique | Measure-Object).Count -gt 1) {
            $ColumnFormat.Add(@{Name = "Sym"; Expression = {if ($_.Currency -and (-not $Session.Config.Pools."$($_.Name)".AECurrency -or $Session.Config.Pools."$($_.Name)".AECurrency -eq $_.Currency)) {$ColumnMark -replace "{value}","$($_.Currency)"} else {$_.Currency}}}) > $null
            $ColumnFormat.Add(@{Name = "Balance"; Expression = {$_."Balance ($($_.Currency))"}}) > $null
        }
        $BalancesData | Foreach-Object {$_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name} | Where-Object {$_ -like "Value in *"} | Sort-Object -Unique | Foreach-Object {$ColumnFormat.Add(@{Name = "$($_ -replace "Value in\s+")"; Expression = "$_"; Align = "right"}) > $null}
        $BalancesData | Format-Table -Wrap -Property $ColumnFormat | Out-Host
        if ($ColumnFormat -ne $null) {Remove-Variable "ColumnFormat"}
        if ($BalancesData -ne $null) {Remove-Variable "BalancesData"}
    }

    #Display exchange rates
    $CurrentProfitTotal = $CurrentProfitWithoutCostTotal = $($Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty Profit | Measure-Object -Sum).Sum
    if ($Session.Config.UsePowerPrice) {$CurrentProfitTotal -= $PowerOffset_Cost;$CurrentProfitWithoutCostTotal += $($Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty Profit_Cost | Measure-Object -Sum).Sum}
    [System.Collections.ArrayList]$StatusLine = @()
    foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Currency_Out = $Miner_Currency
            $CurrentProfitTotal_Out = $CurrentProfitTotal
            $CurrentProfitWithoutCostTotal_Out = $CurrentProfitWithoutCostTotal
            $CurrentProfit_Offset = 2
            if ($Miner_Currency -eq "BTC" -and $CurrentProfitWithoutCostTotal -ne 0) {
                switch ([math]::truncate([math]::log([math]::Abs($CurrentProfitWithoutCostTotal), 1000))) {
                    -1 {$Miner_Currency_Out = "mBTC";$CurrentProfitTotal_Out*=1e3;$CurrentProfitWithoutCostTotal_Out*=1e3;$CurrentProfit_Offset = 5}
                    -2 {$Miner_Currency_Out = "µBTC";$CurrentProfitTotal_Out*=1e6;$CurrentProfitWithoutCostTotal_Out*=1e6;$CurrentProfit_Offset = 8}
                    -3 {$Miner_Currency_Out = "sat"; $CurrentProfitTotal_Out*=1e8;$CurrentProfitWithoutCostTotal_Out*=1e8;$CurrentProfit_Offset = 10}
                }
            }
            if ($Session.Rates.$Miner_Currency) {$StatusLine.Add("$(ConvertTo-LocalCurrency $CurrentProfitTotal_Out $($Session.Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)$(if ($Session.Config.UsePowerPrice) {"/$(ConvertTo-LocalCurrency $CurrentProfitWithoutCostTotal_Out $($Session.Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)"}) $Miner_Currency_Out/Day") > $null}
    }
    if ($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $Session.Rates.$_}) {$StatusLine.Add("1 BTC = $(($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $Session.Rates.$_} | Sort-Object | ForEach-Object { "$($_) $($Session.Rates.$_)"})  -join ' = ')") > $null}

    $API.CurrentProfit = $CurrentProfitTotal

    if ($Session.Config.UsePowerPrice) {$StatusLine.Add("E-Price = $($Session.Config.PowerPriceCurrency) $([Math]::Round($Session.CurrentPowerPrice,3))") > $null}

    Write-Host " Profit = $($StatusLine -join ' | ') " -BackgroundColor White -ForegroundColor Black
    Write-Host " "
    if ($StatusLine -ne $null) {Remove-Variable "StatusLine"}

    #Check if server is up
    if ($Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort) {
        $ServerConnected = Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 1
        if ($ServerConnected) {            
            Write-Host "[Client-Mode] Connected to $($Session.Config.ServerName):$($Session.Config.ServerPort)" -ForegroundColor Green
        } else {
            Write-Host "[Client-Mode] Server $($Session.Config.ServerName):$($Session.Config.ServerPort) does not respond." -ForegroundColor Red
        }
        Write-Host " "
        Write-Log -Level Info "Client-Mode: $(if ($ServerConnected) {"Connected"} else {"Not connected"}) to $($Session.Config.ServerName):$($Session.Config.ServerPort)"
    }
    if ($Session.Config.RunMode -eq "Server") {
        if ($API.RemoteAPI) {
            Write-Host "[Server-Mode] Name=$($Session.MachineName) IP=$($Session.MyIP) Port=$($Session.Config.APIport) " -ForegroundColor Green
        } else {
            Write-Host "[Server-Mode] Server has not been started. Run RainbowMiner with admin privileges." -ForegroundColor Red
        }
        Write-Host " "
        Write-Log -Level Info "Server-Mode: $(if ($API.RemoteAPI) {"Name=$($Session.MachineName) IP=$($Session.MyIP) Port=$($Session.Config.APIport)"} else {"not started!"})"
    }

    #Check for updated RainbowMiner
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {
        if ($Session.Config.EnableAutoUpdate) {
            if ($Session.AutoUpdate) {
                Write-Host "Automatic update to v$($ConfirmedVersion.RemoteVersion) starts in some seconds" -ForegroundColor Yellow
            } elseif ($Session.IsExclusiveRun) {
                Write-Host "Automatic update to v$($ConfirmedVersion.RemoteVersion) starts as soon as exclusive mining ends" -ForegroundColor Yellow
            } elseif ($IsExclusiveRun) {
                Write-Host "Exclusive run finished. Automatic update to v$($ConfirmedVersion.RemoteVersion) starts after the next round" -ForegroundColor Yellow
            } else {
                Write-Host "Automatic update failed! Please exit RainbowMiner and start Updater.bat manually to proceed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "To start update, press key `"U`"" -ForegroundColor Yellow            
        }
        Write-Host " "
    }

    #Reduce Memory
    if ($Miners -ne $null) {Remove-Variable "Miners"}
    if ($Miner -ne $null)  {Remove-Variable "Miner"}
    if ($Pool -ne $null)   {Remove-Variable "Pool"}
    if ($Miner_Table -ne $null) {Remove-Variable "Miner_Table"}

    if ($Error.Count) {
        $Error | Foreach-Object {Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").main.txt" -Message "$($_.Exception.Message)" -Append -Timestamp}
        $Error.Clear()
    }

    Get-Job -State Completed | Remove-Job -Force

    [System.GC]::Collect()

    $Session.Timer = (Get-Date).ToUniversalTime()

    #Start asyncloader after first run
    if (Test-Path Variable:Global:AsyncLoader) {$AsyncLoader.Pause = -not (Test-Internet)}

    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    $Session.SkipSwitchingPrevention = $Session.Stopp = $keyPressed = $false

    #Dynamically adapt current interval
    $NextIntervalPreset = if ($Running) {$Session.Config."$(if ($Session.Benchmarking -or $Session.IsBenchmarkingRun) {"Benchmark"})Interval"} else {[Math]::Min($Session.Config.Interval,$Session.Config.BenchmarkInterval)}
    if ($Session.IsDonationRun -and $NextIntervalPreset -gt $DonateMinutes*60) {$NextIntervalPreset = $DonateMinutes*60}
    $NextInterval = [Math]::Max($NextIntervalPreset,$Session.CurrentInterval + [int]($Session.Timer - $RoundEnd.AddSeconds(-20)).TotalSeconds)

    #Apply current interval if changed
    if ($NextInterval -ne $Session.CurrentInterval) {
        Write-Log -Level Info "Runtime interval changed from $($Session.CurrentInterval) to $NextInterval seconds. "
        $RoundEnd = $RoundEnd.AddSeconds($NextInterval-$Session.CurrentInterval)
        $Session.CurrentInterval = $NextInterval
    }

    Update-WatchdogLevels -Interval $(if ($NextInterval -gt $NextIntervalPreset) {$NextInterval})

    $WaitSeconds = [int]($RoundEnd - $Session.Timer).TotalSeconds

    Write-Log "Start waiting $($WaitSeconds) seconds before next run. "

    if ($IsWindows) {$Host.UI.RawUI.FlushInputBuffer()}

    $cursorPosition = $host.UI.RawUI.CursorPosition
    [System.Collections.ArrayList]$cmdMenu = @("E[x]it","[R]estart","[B]alance update","[S]kip SP","[W]D reset")
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {$cmdMenu.Insert(0,"[U]pdate RainbowMiner") > $null}
    if (-not $Session.IsDonationRun){$cmdMenu.Add("[C]onfiguration") > $null}
    $cmdMenu.Add("[V]erbose$(if ($Session.Config.UIstyle -eq "full"){" off"})") > $null
    $cmdMenu.Add("[P]ause$(if ($Session.PauseMiners){" off"})") > $null
    if (-not $Session.IsExclusiveRun -and -not $Session.IsDonationRun) {$cmdMenu.Add("$(if ($LockMiners){"Un[l]ock"} else {"[L]ock"})") > $null}
    Write-Host "Waiting $($WaitSeconds)s until next run: $($cmdMenu -join ", ")"
        
    $SamplesPicked = 0
    $WaitRound = 0
    $SomeMinersFailed = $false
    $MinerStart = $Session.Timer
    do {        
        $TimerBackup = $Session.Timer

        $AllMinersFailed = $false
        if ($WaitRound % 3 -eq 0) {
            $MinersUpdateStatus = Update-ActiveMiners -FirstRound (-not $WaitRound)

            $LoopWarn = ""
            if ((-not $MinersUpdateStatus.MinersUpdated -and $MinersUpdateStatus.MinersFailed) -or $MinersUpdateStatus.ExclusiveMinersFailed) {
                $RoundEnd = $Session.Timer.AddSeconds(0)
                $LoopWarn = "$(if (-not $MinersUpdateStatus.MinersUpdated) {"All"} else {"Exclusive"}) miners crashed. Immediately restarting loop. "
            } elseif ($MinersUpdateStatus.MinersFailed -and -not $SomeMinersFailed) {
                if (-not $Session.Benchmarking -and -not $Session.IsBenchmarkingRun) {
                    $NextRoundEnd = $Session.Timer.AddSeconds([Math]::Max(0,$Session.Config.BenchmarkInterval - [int]($Session.Timer-$Session.RoundStart).TotalSeconds))
                    if ($NextRoundEnd -lt $RoundEnd) {$RoundEnd = $NextRoundEnd}
                }
                $SomeMinersFailed = $true
                $LoopWarn = "$($MinersUpdateStatus.MinersFailed) miner$(if ($MinersUpdateStatus.MinersFailed -gt 1) {"s"}) crashed. Restarting loop asap. $(" " * 71)"
            }
            if ($LoopWarn -ne "") {
                $host.UI.RawUI.CursorPosition = $CursorPosition
                Write-Log -Level Warn $LoopWarn                
            }

            $SamplesPicked++
        }

        if (-not $MinersNeedingBenchmarkCount -and ($Session.Timer - $MinerStart).TotalSeconds -ge $Session.Config.BenchmarkInterval) {
            Write-Log "Saving hash rates. "
            if (-not (Set-MinerStats ($Session.Timer-$MinerStart) -Watchdog -Quiet)) {$RoundEnd = $Session.Timer.AddSeconds(0)}            
            $MinerStart = $Session.Timer
        }

        if ($Session.Config.EnableMinerStatus -and $Session.Config.MinerStatusURL -and $Session.Config.MinerStatusKey) {
            if ($Session.Timer -gt $Session.NextReport) {
                Invoke-ReportMinerStatus
                $Session.NextReport = $Session.Timer.AddSeconds(60)
            }
        }
 
        $keyPressedValue =  if ((Test-Path ".\stopp.txt") -or $API.Stop) {"X"}
                            elseif ($API.Pause -ne $Session.PauseMiners) {"P"}
                            elseif ($API.LockMiners -ne $Session.LockMiners.Locked -and -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun) {"L"}
                            elseif ($API.Update) {"U"}
                            elseif ($API.UpdateBalance) {"B"}
                            elseif ($API.WatchdogReset) {"W"}
                            elseif ($(try {[console]::KeyAvailable} catch {if ($Error.Count) {$Error.RemoveAt(0)}})) {
                                $key = [System.Console]::ReadKey($true)
                                if (-not $key.Modifiers) {$key.key} elseif ($key.Modifiers -eq "Control" -and $key.key -eq "C") {"X"}
                            }

        if ($keyPressedValue) {
            switch ($keyPressedValue) {
                "S" { 
                    $Session.SkipSwitchingPrevention = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to skip switching prevention. "
                    Write-Host -NoNewline "[S] pressed - skip switching prevention in next run. "
                    $keyPressed = $true
                }
                "N" {                     
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to start next round immediatly. "
                    Write-Host -NoNewline "[N] pressed - next run will start immediatly. "
                    $keyPressed = $true
                }
                "X" {
                    $Session.Stopp = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to stop script. "
                    Write-Host -NoNewline "[X] pressed - stopping script."
                    $keyPressed = $true
                }
                "D" {
                    $Session.StartDownloader = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to start downloader. "
                    Write-Host -NoNewline "[D] pressed - starting downloader in next run. "
                    $keyPressed = $true
                }
                "V" {
                    $Session.Config.UIstyle = if ( $Session.Config.UIstyle -eq "full" ) {"lite"} else {"full"}
                    Write-Host -NoNewline "[V] pressed - UI will be set to $($Session.Config.UIstyle) in next run. "
                    $keyPressed = $true
                }
                "P" {
                    $Session.PauseMiners = -not $Session.PauseMiners
                    $API.Pause = $Session.PauseMiners
                    Write-Host -NoNewline "[P] pressed - miner script will be $(if ($Session.PauseMiners) {"PAUSED"} else {"RESTARTED"})"
                    $keyPressed = $true
                }
                "L" {
                    if (-not $Session.IsExclusiveRun -and -not $Session.IsDonationRun) {
                        $Session.LockMiners.Locked = -not $Session.LockMiners.Locked
                        if ($Session.LockMiners.Locked) {
                            $Session.LockMiners.Pools = @($Script:ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {for($i=0;$i -lt $_.Pool.Count;$i++) {"$($_.Pool | Select-Object -Index $i)-$($_.BaseAlgorithm | Select-Object -Index $i)-$($_.CoinSymbol | Select-Object -Index $i)"}} | Select-Object -Unique)
                        }
                        $API.LockMiners = $Session.LockMiners.Locked
                        Write-Host -NoNewline "[L] pressed - switching will be $(if ($Session.LockMiners.Locked) {"LOCKED"} else {"UNLOCKED"})"
                        $keyPressed = $true
                    }
                }
                "C" {
                    if (-not $Session.IsDonationRun) {
                        $Session.RunSetup = $true
                        Write-Host -NoNewline "[C] pressed - configuration setup will be started"
                        $keyPressed = $true
                    }
                }
                "U" {
                    $Session.AutoUpdate = $true
                    $API.Update = $false
                    Write-Log "User requests to update to v$($ConfirmedVersion.RemoteVersion)"
                    Write-Host -NoNewline "[U] pressed - automatic update of Rainbowminer will be started "
                    $keyPressed = $true
                }
                "R" {
                    $Session.Restart = $true
                    Write-Log "User requests to restart RainbowMiner."
                    Write-Host -NoNewline "[R] pressed - restarting RainbowMiner."
                    $keyPressed = $true
                }
                "W" {
                    $API.WatchdogReset = $false
                    Write-Host -NoNewline "[W] pressed - resetting WatchDog."
                    $Script:WatchdogTimers.Clear()
                    Update-WatchdogLevels -Reset
                    Write-Log "Watchdog reset."
                    $keyPressed = $true
                }
                "B" {
                    $API.UpdateBalance = $false
                    Write-Host -NoNewline "[B] pressed - updating Balance."
                    $Session.Updatetracker.Balances = 0
                    Write-Log "User request to update balance."
                    $keyPressed = $true
                }
                "Y" {
                    Stop-AsyncLoader
                    Start-Sleep 2
                    Start-AsyncLoader -Interval $Session.Config.Interval -Quickstart $Session.Config.Quickstart
                    Write-Host -NoNewline "[Y] pressed - Asyncloader yanked."
                    Write-Log "Asyncloader yanked."
                }
            }
        }
        $WaitRound++

        $Session.Timer = (Get-Date).ToUniversalTime()
        if ($UseTimeSync -and $Session.Timer -le $TimerBackup) {Test-TimeSync;$Session.Timer = (Get-Date).ToUniversalTime()}

        if (-not $keyPressed) {
            $Waitms = 1000 - ($Session.Timer - $TimerBackup).TotalMilliseconds
            if ($Waitms -gt 0) {Start-Sleep -Milliseconds $Waitms}
        }
    } until ($keyPressed -or $Session.SkipSwitchingPrevention -or $Session.StartDownloader -or $Session.Stopp -or $Session.AutoUpdate -or ($Session.Timer -ge $RoundEnd))

    if ($SamplesPicked -eq 0) {Update-ActiveMiners > $null;$Session.Timer = (Get-Date).ToUniversalTime();$SamplesPicked++}

    if ($Session.Downloader.HasMoreData) {$Session.Downloader | Receive-Job}

    if (-not $keyPressed) {
        $host.UI.RawUI.CursorPosition = $CursorPosition
        Write-Log "Finish waiting before next run. "
        Write-Host -NoNewline "Finished waiting - starting next run "
    }

    Write-Host (" " * 120)

    #Save current hash rates
    Write-Log "Saving hash rates. "
    Set-MinerStats ($Session.Timer - $MinerStart)

    #Cleanup stopped miners    
    $Script:ActiveMiners | Where-Object {$_.Stopped} | Foreach-Object {$_.StopMiningPostCleanup()}
        
    if ($Session.Restart -or $Session.AutoUpdate) {
        $Session.Stopp = $false
        try {
            if ($IsWindows) {
                $CurrentProcess = Get-CimInstance Win32_Process -filter "ProcessID=$PID" | Select-Object CommandLine,ExecutablePath
                if ($CurrentProcess.CommandLine -and $CurrentProcess.ExecutablePath) {
                    if ($Session.AutoUpdate) {$Update_Parameters = @{calledfrom="core"};& .\Updater.ps1 @Update_Parameters}
                    $StartWindowState = Get-WindowState -Title $Session.MainWindowTitle
                    $StartCommand = $CurrentProcess.CommandLine -replace "^pwsh\s+","$($CurrentProcess.ExecutablePath) "
                    if ($StartCommand -match "-windowstyle") {$StartCommand = $StartCommand -replace "-windowstyle (minimized|maximized|normal)","-windowstyle $($StartWindowState)"}
                    else {$StartCommand = $StartCommand -replace "-command ","-windowstyle $($StartWindowState) -command "}
                    if ($StartCommand -notmatch "-quickstart") {$StartCommand = $StartCommand -replace "rainbowminer.ps1","rainbowminer.ps1 -quickstart"}
                    Write-Log "Restarting $($StartWindowState) $($StartCommand)"
                    Set-LastStartTime
                    $NewKid = Invoke-CimMethod Win32_Process -MethodName Create -Arguments @{CommandLine=$StartCommand;CurrentDirectory=(Split-Path $script:MyInvocation.MyCommand.Path);ProcessStartupInformation=New-CimInstance -CimClass (Get-CimClass Win32_ProcessStartup) -Property @{ShowWindow=if ($StartWindowState -eq "normal"){5}else{3}} -Local}
                    if ($NewKid -and $NewKid.ReturnValue -eq 0) {
                        Write-Host "Restarting now, please wait!" -BackgroundColor Yellow -ForegroundColor Black                
                        $wait = 0;while ((-not $NewKid.ProcessId -or -not (Get-Process -id $NewKid.ProcessId -ErrorAction Stop)) -and $wait -lt 20) {Write-Host -NoNewline "."; Start-Sleep -Milliseconds 500;$wait++}
                        Write-Host " "
                        if ($NewKid.ProcessId -and (Get-Process -id $NewKid.ProcessId -ErrorAction Ignore)) {$Session.Stopp = $true;$Session.AutoUpdate = $false}
                    }
                }
            } else {
                if ($Session.AutoUpdate) {$Update_Parameters = @{calledfrom="core"};& .\Updater.ps1 @Update_Parameters}
                $Session.Stopp = $true
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log "Autoupdate failed: $($_.Exception.Message) on item $($_.Exception.ItemName)"
        }
        if (-not $Session.Stopp) { #fallback to old updater
            if ($Session.AutoUpdate) {
                Write-Log -Level Warn "Failed to start new instance of RainbowMiner. Switching to legacy update."                
                $Session.Stopp = $true
            } else {
                Write-Log -Level Warn "Restart not possible, $(if ($Session.IsAdmin) {"something went wrong."} else {"since RainbowMiner has not been started with administrator rights"})"
                $Session.Restart = $false
            }
        }
        if ($Session.Stopp -and ($Session.AutoUpdate -or $Session.Restart)) {Set-LastStartTime}
    }

    if ($Session.IsBenchmarkingRun -and -not $Session.Benchmarking) {$Session.IsBenchmarkingRun = $false}

    $Session.RoundCounter++
}

function Stop-Core {

    #Stop services
    if (-not $Session.Config.DisableAPI)         {Stop-APIServer}
    if (-not $Session.Config.DisableAsyncLoader) {Stop-AsyncLoader}

    Remove-Item ".\stopp.txt" -Force -ErrorAction Ignore
    Write-Log "Gracefully halting RainbowMiner"
    [System.Collections.ArrayList]$ExcavatorWindowsClosed = @()
    $Script:ActiveMiners | Where-Object {$_.GetActivateCount() -gt 0 -or $_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {
        $Miner = $_
        if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
            Write-Log "Closing $($Miner.Type) miner $($Miner.Name)"
            $Miner.StopMining()
        }
        if ($Miner.BaseName -like "Excavator*" -and -not $ExcavatorWindowsClosed.Contains($Miner.BaseName)) {
            $Miner.ShutDownMiner()
            $ExcavatorWindowsClosed.Add($Miner.BaseName) > $null
        }
    }
    if ($IsWindows) {
        Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {$_.ExecutablePath -like "$(Get-Location)\Bin\*"} | Stop-Process -Force -ErrorAction Ignore
    } elseif ($IsLinux) {
        Get-Process | Where-Object Path | Where-Object {$_.Path -like "$(Get-Location)/bin/*"} | Foreach-Object {
            if (Test-OCDaemon) {
                $Cmd = @()
                @($_.Id,$_.Parent.Id) | Select-Object -Unique | % {$Cmd += "kill $($_)"}
                Invoke-OCDaemon -Cmd $Cmd -Quiet > $null
            } else {
                @($_.Id,$_.Parent.Id) | Select-Object -Unique | % {Stop-Process $_ -Force -ErrorAction Ignore}
            }
        }
    }
    Stop-Autoexec
    [console]::TreatControlCAsInput = $false
}