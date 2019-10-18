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
                if ($Libs = Get-Content ".\IncludesLinux\libs.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore) {
                    $Dir = "$Pwd/IncludesLinux/lib"

                    $Libs.PSObject.Properties | Where-Object {-not (Test-Path "$($Dir)/$($_.Name)")} | Foreach-Object {
                        Invoke-Exe -FilePath "ln" -ArgumentList "-s $($Dir)/$($_.Value) $($Dir)/$($_.Name)" > $null
                    }
                }
                Remove-Variable "Libs"
            }
        }

        $Session.ConfigName = [IO.Path]::GetFileNameWithoutExtension($ConfigFile)

        #Setup console and display logo
        $host.UI.RawUI.WindowTitle = $Session.MainWindowTitle
        if ($false -and -not $psISE -and $IsWindows) {
            $ColorConfigPath = Join-Path $ConfigPath "colors.$(Split-Path $ConfigFile -Leaf)"
            if (Test-Path $ColorConfigPath) {
                try {
                    $Colors = Get-Content $ColorConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
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

        #Setup session variables
        $Session.ActiveMiners = @()
        $Session.AllPools = $null
        $Session.WatchdogTimers = @()
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

        $Session.StartTime         = if ($LastStartTime = (Get-LastStartTime)) {$LastStartTime} else {(Get-Date).ToUniversalTime()}

        $Session.Strikes           = 3
        $Session.SyncWindow        = 10 #minutes, after that time, the pools bias price will start to decay
        $Session.OutofsyncWindow   = 60 #minutes, after that time, the pools price bias will be 0
        $Session.DecayPeriod       = 60 #seconds
        $Session.DecayBase         = 1 - 0.1 #decimal percentage

        $Session.GlobalGetTicker = @()
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
        $Session.IsAdmin = Test-IsElevated
        $Session.MachineName = [System.Environment]::MachineName
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
            $ConfigForUpdate = Get-Content $ConfigFile | ConvertFrom-Json
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
                $LastVersion = (Get-Content ".\Data\version.json" -Raw | ConvertFrom-Json -ErrorAction Ignore).Version
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
                if (Test-IsElevated) {
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
        if (Test-Path ".\Data\minerinfo.json") {try {(Get-Content ".\Data\minerinfo.json" -Raw | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Foreach-Object {$Session.MinerInfo[$_.Name] = $_.Value}} catch {if ($Error.Count){$Error.RemoveAt(0)}}}

        #write version to data
        Set-ContentJson -PathToFile ".\Data\version.json" -Data ([PSCustomObject]@{Version=$Session.Version}) > $null
        $true
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "$($_) Cannot run RainbowMiner. "
        $false
    }

    $Session.Timer = (Get-Date).ToUniversalTime()
    $Session.NextReport = $Session.Timer
    $Session.DecayStart = $Session.Timer
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

    Update-DeviceInformation $Session.ActiveMiners_DeviceNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    $MinersUpdated = 0
    $MinersFailed  = 0
    $ExclusiveMinersFailed = 0
    $Session.ActiveMiners | Where-Object Best |  Foreach-Object {
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
        $API.RunningMiners = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running}
    }
    if (-not $Silent) {
        [PSCustomObject]@{
            MinersUpdated = $MinersUpdated
            MinersFailed  = $MinersFailed
            ExclusiveMinersFailed = $ExclusiveMinersFailed
        }
    }
}

function Invoke-Core {

    #Validate version file
    if (-not (Test-Path ".\Data\version.json") -or -not (Get-Content ".\Data\version.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).Version) {
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
                $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1" | Select-Object -ExpandProperty Content
                $Session.ConfigFiles["Config"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Config"].Path).LastWriteTime.ToUniversalTime()
                $Parameters = @{}
                $Session.DefaultValues.Keys | Where-Object {$_ -ne "SetupOnly"} | ForEach-Object {
                    $val = $Session.DefaultValues[$_]
                    if ($ConfigSetup.$_ -ne $null) {$val = $ConfigSetup.$_}
                    if ($val -is [array]) {$val = $val -join ','}
                    $Parameters.Add($_ , $val)
                }
                $Session.Config = Get-ChildItemContent $Session.ConfigFiles["Config"].Path -Force -Parameters $Parameters | Select-Object -ExpandProperty Content
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
        do {
            if (-not ($i % 60)) {Write-Log -Level Warn "Waiting 30s for internet connection. Press [X] to exit RainbowMiner"}
            Start-Sleep -Milliseconds 500
            if ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}
            $i++
            if (-not ($i % 20)) {$Internet_ok = Test-Internet}
        } until ($Internet_ok -or $keyPressedValue -eq "X")

        if ($keyPressedValue -eq "X") {
            Write-Log "User requests to stop script. "
            Write-Host "[X] pressed - stopping script."
            break
        }
        if ($i -gt $Session.Config.BenchmarkInterval*2) {
            Update-WatchdogLevels -Reset
            $Session.WatchdogTimers = @()
        }
    }

    if (-not $Session.Updatetracker.TimeDiff -or $Session.Updatetracker.TimeDiff -lt (Get-Date).AddMinutes(-60)) {
        $Session.Updatetracker.TimeDiff = Get-Date
        $TimeDiff = ((Get-Date)-(Get-NtpTime)).TotalSeconds
        $Session.TimeDiff = [Math]::Sign($TimeDiff)*[Math]::Floor([Math]::Abs($TimeDiff))
    }

    #Convert to array, if needed and check contents of some fields, if Config has been reread or reset
    if ($CheckConfig) {
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
        $Session.Config.EnableHeatMyFlat = [Math]::Max(0,[Math]::Min(10,$Session.Config.EnableHeatMyFlat))
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
        $API.LockMiners = $false
        $API.RemoteAPI = $true
        $API.ApplyOC = $false
        $API.IsVirtual = $true
        $API.APIport = $Session.Config.APIport
        $API.APIAuth = $Session.Config.APIAuth
        $API.APIport = $Session.Config.APIport
        $API.APIUser = $Session.Config.APIUser
        $API.APIPassword = $Session.Config.APIPassword
    }

    if ($CheckConfig) {Update-WatchdogLevels -Reset}

    #Versioncheck
    $ConfirmedVersion = Confirm-Version $Session.Version
    $API.Version = $ConfirmedVersion | ConvertTo-Json -Compress
    $Session.AutoUpdate = $false
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version -and $Session.Config.EnableAutoUpdate -and -not $Session.IsExclusiveRun) {
        if (Test-Path ".\Logs\autoupdate.txt") {try {$Last_Autoupdate = Get-Content ".\Logs\autoupdate.txt" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)};$Last_Autoupdate = $null}}
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
            $AllAlgorithms = Get-ConfigContent "Algorithms" -UpdateLastWriteTime
            if (Test-Config "Algorithms" -Health) {
                $Session.Config | Add-Member Algorithms ([PSCustomObject]@{}) -Force
                $AllAlgorithms.PSObject.Properties.Name | Where-Object {-not $Session.Config.Algorithm.Count -or $Session.Config.Algorithm -icontains $_} | Foreach-Object {
                    $Session.Config.Algorithms | Add-Member $_ $AllAlgorithms.$_ -Force
                    $Session.Config.Algorithms.$_ | Add-Member Penalty ([double]($Session.Config.Algorithms.$_.Penalty -replace "[^\d\.\-]+")) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MinHashrate (ConvertFrom-Hash $Session.Config.Algorithms.$_.MinHashrate) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MinWorkers (ConvertFrom-Hash $Session.Config.Algorithms.$_.MinWorkers) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MaxTimeToFind (ConvertFrom-Time $Session.Config.Algorithms.$_.MaxTimeToFind) -Force
                    $Session.Config.Algorithms.$_ | Add-Member MSIAprofile ([int]$Session.Config.Algorithms.$_.MSIAprofile) -Force
                }
            }
            if ($AllAlgorithms) {Remove-Variable "AllAlgorithms" -Force}
        }
    }

    #Check for coins config
    $CheckCoins = $false
    if (Set-ConfigDefault "Coins") {
        if ($CheckConfig -or -not $Session.Config.Coins -or (Test-Config "Coins" -LastWriteTime) -or ($ConfigBackup.Coins -and (Compare-Object $Session.Config.Coins $ConfigBackup.Coins | Measure-Object).Count)) {
            $AllCoins = Get-ConfigContent "Coins" -UpdateLastWriteTime
            if (Test-Config "Coins" -Health) {
                $Session.Config | Add-Member Coins ([PSCustomObject]@{})  -Force
                $AllCoins.PSObject.Properties.Name | Select-Object | Foreach-Object {
                    $Session.Config.Coins | Add-Member $_ $AllCoins.$_ -Force
                    $Session.Config.Coins.$_ | Add-Member Penalty ([double]($Session.Config.Coins.$_.Penalty -replace "[^\d\.\-]+")) -Force
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
            if ($AllCoins) {Remove-Variable "AllCoins" -Force}
        }
    }

    #Check for oc profile config
    if (Set-ConfigDefault "OCProfiles") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.OCProfiles -or (Test-Config "OCProfiles" -LastWriteTime))) {
            $AllOCProfiles = Get-ConfigContent "OCProfiles" -UpdateLastWriteTime
            if (Test-Config "OCProfiles" -Health) {
                $Session.Config | Add-Member OCProfiles $AllOCProfiles -Force
            }
            if ($AllOCProfiles) {Remove-Variable "AllOCProfiles" -Force}
        }
    }

    #Check for powerprice config
    if (Set-ConfigDefault "Scheduler") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or $Session.Config.Scheduler -eq $null -or (Test-Config "Scheduler" -LastWriteTime))) {
            $AllScheduler = Get-ConfigContent "Scheduler" -UpdateLastWriteTime
            if (Test-Config "Scheduler" -Health) {
                $Session.Config | Add-Member Scheduler @() -Force
                $AllScheduler | Foreach-Object {
                    $_ | Add-Member DayOfWeek "$($_.DayOfWeek -replace "[^0-6\*]+")"[0] -Force
                    $_ | Add-Member From $(Get-HourMinStr $_.From) -Force
                    $_ | Add-Member To   $(Get-HourMinStr $_.To -to) -Force
                    $_ | Add-Member PowerPrice $($_.PowerPrice -replace ",","." -replace "[^0-9\.]+") -Force
                    $_ | Add-Member Enable $(Get-Yes $_.Enable) -Force
                    $_ | Add-Member Pause  $(Get-Yes $_.Pause)  -Force
                    $PowerPrice = if ($_.PowerPrice -eq "") {$Session.Config.PowerPrice} else {$_.PowerPrice}
                    try {$PowerPrice = [Double]$PowerPrice} catch {if ($Error.Count){$Error.RemoveAt(0)};$PowerPrice = $Session.Config.PowerPrice}
                    $_.PowerPrice = $PowerPrice
                    $Session.Config.Scheduler += $_
                }
            }
            if ($AllScheduler) {Remove-Variable "AllScheduler" -Force}
        }
    }

    #Check for devices config
    if (Set-ConfigDefault "Devices") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.Devices -or (Test-Config "Devices" -LastWriteTime))) {
            $AllDevices = Get-ConfigContent "Devices" -UpdateLastWriteTime
            if (Test-Config "Devices" -Health) {
                $Session.Config | Add-Member Devices $AllDevices -Force
                $OCprofileFirst = $Session.Config.OCProfiles.PSObject.Properties.Name | Foreach-Object {$_ -replace "-.+$"} | Select-Object -Unique -First 1
                foreach ($p in @($Session.Config.Devices.PSObject.Properties.Name)) {
                    $Session.Config.Devices.$p | Add-Member Algorithm @(($Session.Config.Devices.$p.Algorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                    $Session.Config.Devices.$p | Add-Member ExcludeAlgorithm @(($Session.Config.Devices.$p.ExcludeAlgorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                    foreach ($q in @("MinerName","PoolName","ExcludeMinerName","ExcludePoolName")) {
                        if ($Session.Config.Devices.$p.$q -is [string]){$Session.Config.Devices.$p.$q = if ($Session.Config.Devices.$p.$q.Trim() -eq ""){@()}else{[regex]::split($Session.Config.Devices.$p.$q.Trim(),"\s*[,;]+\s*")}}
                    }
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
            if ($AllDevices) {Remove-Variable "AllDevices" -Force}
        }
    }

    #Check for gpugroups config
    if (Set-ConfigDefault "GpuGroups") {
        if ($CheckConfig -or -not $Session.Config.GpuGroups -or (Test-Config "GpuGroups" -LastWriteTime) -or ($ConfigBackup.GpuGroups -and (Compare-Object $Session.Config.GpuGroups $ConfigBackup.GpuGroups | Measure-Object).Count)) {
            $AllGpuGroups = Get-ConfigContent "GpuGroups" -UpdateLastWriteTime
            if (Test-Config "GpuGroups" -Health) {
                $Session.Config | Add-Member GpuGroups ([PSCustomObject]@{})  -Force
                $AllGpuGroups.PSObject.Properties.Name | Select-Object | Foreach-Object {
                    $Session.Config.GpuGroups | Add-Member $_ $AllGpuGroups.$_ -Force
                    $CheckGpuGroups = $true
                }
            }
            if ($AllGpuGroups) {Remove-Variable "AllGpuGroups" -Force}
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
            if ($AllCombos) {Remove-Variable "AllCombos" -Force}
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
            $AllPools = Get-ConfigContent "Pools" -Parameters $PoolParams -UpdateLastWriteTime
            if (Test-Config "Pools" -Health) {
                $Session.Config | Add-Member Pools $AllPools -Force
                $CheckPools = $true
            }
            if ($AllPools) {Remove-Variable "AllPools" -Force}
        }
    }

    $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_} | ForEach-Object {
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
            $c = Get-PoolPayoutCurrencies $Session.Config.Pools.$p
            $cparams = [PSCustomObject]@{}
            $c.PSObject.Properties.Name | Where-Object {$Session.Config.Pools.$p."$($_)-Params"} | Foreach-Object {$cparams | Add-Member $_ $Session.Config.Pools.$p."$($_)-Params" -Force}
            $Session.Config.Pools.$p | Add-Member Wallets $c -Force
            $Session.Config.Pools.$p | Add-Member Params $cparams -Force
            $Session.Config.Pools.$p | Add-Member DataWindow (Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow) -Force
            $Session.Config.Pools.$p | Add-Member Penalty ([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+")) -Force
            $Session.Config.Pools.$p | Add-Member StatAverage (Get-StatAverage $Session.Config.Pools.$p.StatAverage -Default $Session.Config.PoolStatAverage) -Force
        }
    }

    #Get PowerPrice and Scheduler events
    $Session.PauseMinersByScheduler = $false
    [Double]$PowerPrice = $Session.Config.PowerPrice
    $TimeOfDay = (Get-Date).TimeOfDay.ToString("hh\:mm")
    $DayOfWeek = (Get-Date).DayOfWeek
    $Session.Config.Scheduler | Where-Object {$_.Enable -and $_.DayOfWeek -eq "*" -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To} | Foreach-Object {$PowerPrice = [Double]$_.PowerPrice;$Session.PauseMinersByScheduler = $_.Pause}
    $Session.Config.Scheduler | Where-Object {$_.Enable -and $_.DayOfWeek -match "^\d$" -and $DayOfWeek -eq [int]$_.DayOfWeek -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To} | Foreach-Object {$PowerPrice = [Double]$_.PowerPrice;$Session.PauseMinersByScheduler = $_.Pause}

    $Session.CurrentPowerPrice = $PowerPrice

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
        $Session.AllPools = $null
        Write-Log "Donation run finished. "
    }
    if ($Session.Timer.AddHours(-$DonateDelayHours).AddMinutes($DonateMinutes) -ge $Session.LastDonated -and $Session.AvailPools.Count -gt 0) {
        if (-not $Session.IsDonationRun -or $CheckConfig) {
            try {$DonationData = Invoke-GetUrl "http://rbminer.net/api/dconf.php"} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Rbminer.net/api/dconf.php could not be reached"}
            if (-not $DonationData -or -not $DonationData.Wallets) {$DonationData = '{"Probability":100,"Wallets":{"2Miners":{"XZC":"aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM","Worker":"mpx","DataWindow":"estimate_current","Penalty":18},"Blockcruncher":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"BlockMasters":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","DataWindow":"average-2e","Penalty":50},"Bsod":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"CryptoKnight":{"XWP":"fh33cEdhKgx3rC6v931rEW3PQgoUJtuBuXT6ZN98tZii2jKtxkk67WBN93LjdngKuSUyWYBkagtQd4ajuZ7ZxoHs1HEPHZJVb","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"EthashPool":{"ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Ethermine":{"ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"F2Pool":{"XZC":"aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM","ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"FairPool":{"WOW":"So2ifgjqGMZJhCrqpFMotQQAiJAiATuJLNAK2HrPLoNzK8hkqNbf9t8gmx6bzAQrXRMnWnoELoiD6GTv8guPBRwH5yoTVNomwVR2oNYDPRua","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"HeroMiners":{"XWP":"fh33cEdhKgx3rC6v931rEW3PQgoUJtuBuXT6ZN98tZii2jKtxkk67WBN93LjdngKuSUyWYBkagtQd4ajuZ7ZxoHs1HEPHZJVb","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"Icemining":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"Luckypool":{"XWP":"fh33cEdhKgx3rC6v931rEW3PQgoUJtuBuXT6ZN98tZii2jKtxkk67WBN93LjdngKuSUyWYBkagtQd4ajuZ7ZxoHs1HEPHZJVb","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Mintpond":{"XZC":"aKB3gmAiNe3c4SasGbSo35sNoA3mAqrxtM","Worker":"mpx","DataWindow":"estimate_current","Penalty":18},"Nanopool":{"ETH":"0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"NiceHash":{"BTC":"3PfUUT1Tknfyd4SnYrEwwpUEAQEzWd2BuD","Worker":"mpx","DataWindow":"estimate_current","Penalty":0,"Platform":"v2"},"NiceHashV2":{"BTC":"3PfUUT1Tknfyd4SnYrEwwpUEAQEzWd2BuD","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"PocketWhale":{"XWP":"fh33cEdhKgx3rC6v931rEW3PQgoUJtuBuXT6ZN98tZii2jKtxkk67WBN93LjdngKuSUyWYBkagtQd4ajuZ7ZxoHs1HEPHZJVb","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"Ravenminer":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"RavenminerEu":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"Uupool":{"VOLLAR":"VcSq7vHRb9ymPj1jbeHNfX2fdVTJK75xndX","Worker":"mpx","DataWindow":"estimate_current","Penalty":0},"MiningPoolHub":{"Worker":"mpx","User":"rbm","API_ID":"422496","API_Key":"ef4f18b4f48d5964c5f426b90424d088c156ce0cd0aa0b9884893cabf6be350e","DataWindow":"average-2e","Penalty":12,"Algorithm":["monero","skein","myriadgroestl"]},"MiningPoolHubCoins":{"Worker":"mpx","User":"rbm","API_ID":"422496","API_Key":"ef4f18b4f48d5964c5f426b90424d088c156ce0cd0aa0b9884893cabf6be350e","DataWindow":"average-2e","Penalty":12,"Algorithm":["monero","skein","myriadgroestl"]},"ZergPool":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","DataWindow":"average-2e","Penalty":12},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","User":"rbm","DataWindow":"average-2e","Penalty":16}},"Pools":["2Miners","Fairpool","NicehashV2","NLpool","Uupool","ZergPool"],"Algorithm":[],"ExcludeMinerName":["GrinGoldMiner","GrinProMiner","SwapMiner"]}' | ConvertFrom-Json}
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
                $Session.Config.Pools.$p | Add-Member Penalty ([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+")) -Force
            }
            if ($DonationData.ExcludeMinerName) {
                $Session.Config | Add-Member ExcludeMinerName @($Session.Config.ExcludeMinerName + (Compare-Object $DonationData.ExcludeMinerName $Session.Config.MinerName | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) | Select-Object -Unique) -Force
            }
            $Session.Config | Add-Member DisableExtendInterval $true -Force
            $Session.AllPools = $null
        }
    } else {
        Write-Log ("Next donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($Session.LastDonated.AddHours($DonateDelayHours) - ($Session.Timer.AddMinutes($DonateMinutes))))
    }

    #Clear pool cache if the pool configuration has changed
    if ($Session.AllPools -ne $null -and (($ConfigBackup.Pools | ConvertTo-Json -Compress -Depth 10) -ne ($Session.Config.Pools | ConvertTo-Json -Compress -Depth 10) -or (Compare-Object @($ConfigBackup.PoolName) @($Session.Config.PoolName)) -or (Compare-Object @($ConfigBackup.ExcludePoolName) @($Session.Config.ExcludePoolName)))) {$Session.AllPools = $null}

    #load device(s) information and device combos
    if ($CheckConfig -or $CheckCombos -or $ConfigBackup.MiningMode -ne $Session.Config.MiningMode -or (Compare-Object $Session.Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0 -or (Compare-Object $Session.Config.ExcludeDeviceName $ConfigBackup.ExcludeDeviceName | Measure-Object).Count -gt 0) {
        Write-Log "Device configuration changed. Refreshing now. "

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

        #Update device information for the first time
        Update-DeviceInformation @($Session.Devices.Name | Select-Object -Unique) -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    }
    
    $Session.ConfigFullComboModelNames = @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name)

    if (-not $Session.Devices) {
        $Session.PauseMiners = $API.Pause = $true
    }

    #Check for miner config
    if (Set-ConfigDefault "Miners") {
        if ($CheckConfig -or -not $Session.Config.Miners -or (Test-Config "Miners" -LastWriteTime)) {
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
                                    $CcMinerNameToAdd += "-$(Get-Algorithm $p.MainAlgorithm)"
                                    if ($p.SecondaryAlgorithm) {$CcMinerNameToAdd += "-$(Get-Algorithm $p.SecondaryAlgorithm)"}
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
            if ($AllMiners) {Remove-Variable "AllMiners" -Force}
        }
    }

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

    $DecayExponent = [int](($Session.Timer - $Session.DecayStart).TotalSeconds / $Session.DecayPeriod)

    #Update the exchange rates
    Write-Log "Updating exchange rates. "
    Update-Rates

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

    #Load information about the pools
    Write-Log "Loading pool information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading pool modules .."}

    $SelectedPoolNames = @()
    $NewPools = @()
    $TimerPools = @{}
    $StopWatch = New-Object -TypeName System.Diagnostics.StopWatch
    if (Test-Path "Pools") {
        $NewPools = $Session.AvailPools | Where-Object {$Session.Config.Pools.$_ -and ($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_)} | Foreach-Object {
            $SelectedPoolNames += $_
            if ($Session.RoundCounter -eq 0) {Write-Host ".. loading $($_) " -NoNewline}
            $StopWatch.Restart()
            Get-PoolsContent $_ -Config $Session.Config.Pools.$_ -StatSpan $RoundSpan -InfoOnly $false -IgnoreFees $Session.Config.IgnoreFees -Algorithms $Session.Config.Algorithms -Coins $Session.Config.Coins -EnableErrorRatio:$Session.Config.EnableErrorRatio
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
                Remove-Variable "Earnings"
            }
            $API.Balances = $BalancesData | ConvertTo-Json -Depth 10
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

    #This finds any pools that were already in $Session.AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    $Session.AllPools = @($NewPools) + @(Compare-Object @($NewPools.Name | Select-Object -Unique) @($Session.AllPools.Name | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$Session.AllPools | Where-Object Name -EQ $_}) | Where-Object {
        $Pool = $_
        $Pool_Name = $Pool.Name
        $Pool_Algo = @($Pool.Algorithm)
        if ($Pool.CoinSymbol) {$Pool_Algo += "$($Pool.Algorithm)-$($Pool.CoinSymbol)"}
        -not (
                (-not $Session.Config.Pools.$Pool_Name) -or
                ($Session.Config.PoolName.Count -and $Session.Config.PoolName -inotcontains $Pool_Name) -or
                ($Session.Config.ExcludePoolName.Count -and $Session.Config.ExcludePoolName -icontains $Pool_Name) -or
                ($Session.Config.Algorithm.Count -and -not (Compare-Object @($Session.Config.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.ExcludeAlgorithm.Count -and (Compare-Object @($Session.Config.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                (-not $Session.Config.DisableUnprofitableAlgolist -and $Session.UnprofitableAlgos.Algorithms -and $Session.UnprofitableAlgos.Algorithms.Count -and (Compare-Object @($Session.UnprofitableAlgos.Algorithms | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                (-not $Session.Config.DisableUnprofitableAlgolist -and $Session.UnprofitableAlgos.Pools.$Pool_Name -and $Session.UnprofitableAlgos.Pools.$Pool_Name.Count -and (Compare-Object @($Session.UnprofitableAlgos.Pools.$Pool_Name | Select-Object) $Pool_Algo -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.ExcludeCoin.Count -and $Pool.CoinName -and @($Session.Config.ExcludeCoin) -icontains $Pool.CoinName) -or
                ($Session.Config.ExcludeCoinSymbol.Count -and $Pool.CoinSymbol -and @($Session.Config.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol) -or
                ($Session.Config.Pools.$Pool_Name.Algorithm.Count -and -not (Compare-Object @($Session.Config.Pools.$Pool_Name.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Compare-Object @($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Pool.CoinName -and $Session.Config.Pools.$Pool_Name.CoinName.Count -and @($Session.Config.Pools.$Pool_Name.CoinName) -inotcontains $Pool.CoinName) -or
                ($Pool.CoinName -and $Session.Config.Pools.$Pool_Name.ExcludeCoin.Count -and @($Session.Config.Pools.$Pool_Name.ExcludeCoin) -icontains $Pool.CoinName) -or
                ($Pool.CoinSymbol -and $Session.Config.Pools.$Pool_Name.CoinSymbol.Count -and @($Session.Config.Pools.$Pool_Name.CoinSymbol) -inotcontains $Pool.CoinSymbol) -or
                ($Pool.CoinSymbol -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and @($Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol)
            )}
    Remove-Variable "NewPools" -Force

    #Blend out pools, that do not pass minimum algorithm settings or have idle set
    $Session.AllPools = $Session.AllPools | Where-Object {($_.Exclusive -and -not $_.Idle) -or -not (
                ($_.Idle) -or
                ($_.Hashrate -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinHashrate -and $_.Hashrate -lt $Session.Config.Algorithms."$($_.Algorithm)".MinHashrate) -or
                ($_.Workers -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinWorkers -and $_.Workers -lt $Session.Config.Algorithms."$($_.Algorithm)".MinWorkers) -or
                ($_.BLK -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MaxTimeToFind -and ($_.BLK -eq 0 -or ($_.BLK -gt 0 -and (24/$_.BLK*3600) -gt $Session.Config.Algorithms."$($_.Algorithm)".MaxTimeToFind))) -or
                ($_.CoinSymbol -and $_.Hashrate -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinHashrate -and $_.Hashrate -lt $Session.Config.Coins."$($_.CoinSymbol)".MinHashrate) -or
                ($_.CoinSymbol -and $_.Workers -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinWorkers -and $_.Workers -lt $Session.Config.Coins."$($_.CoinSymbol)".MinWorkers) -or
                ($_.CoinSymbol -and $_.BLK -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MaxTimeToFind -and ($_.BLK -eq 0 -or ($_.BLK -gt 0 -and (24/$_.BLK*3600) -gt $Session.Config.Coins."$($_.CoinSymbol)".MaxTimeToFind)))
            )}

    $AllPools_BeforeWD_Count = ($Session.AllPools | Measure-Object).Count

    #Apply watchdog to pools, only if there is more than one pool selected
    if (($Session.AllPools.Name | Select-Object -Unique | Measure-Object).Count -gt 1) {
        $Session.AllPools = $Session.AllPools | Where-Object {
            $Pool = $_
            $Pool_WatchdogTimers = $Session.WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Session.Timer.AddSeconds( - $Session.WatchdogInterval) | Where-Object Kicked -GT $Session.Timer.AddSeconds( - $Session.WatchdogReset)
            ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
        }
    }

    #Update the active pools
    $Pools = [PSCustomObject]@{}
    
    if (($Session.AllPools | Measure-Object).Count -gt 0) {

        $Pools_WTM = $Session.AllPools | Where-Object {$_.WTM}
        if (($Pools_WTM | Measure-Object).Count) {
            $Pools_WTM_Coins = $Pools_WTM | Where-Object {$_.Algorithm -notmatch '-'} | Foreach-Object {[PSCustomObject]@{Algorithm=$_.Algorithm;CoinSymbol=$_.CoinSymbol}} | Select-Object Algorithm,CoinSymbol -Unique

            if ($Session.RoundCounter -eq 0) {Write-Host ".. loading WhatToMine " -NoNewline}
            $start = Get-UnixTimestamp -Milliseconds
            Get-PoolsContent "WhatToMine" -Config ([PSCustomObject]@{Wallets = $Pools_WTM_Coins}) -StatSpan $RoundSpan -InfoOnly $false | Foreach-Object {
                $Pool_WTM = $_
                $Pool_WTM_Algo = @($Pool_WTM.Algorithm)
                if ($Pool_WTM.Algorithm -match "^Equihash") {$Pool_WTM_Algo += "$($Pool_WTM.Algorithm)-$($Pool_WTM.Coinsymbol)"}
                $Pools_WTM | Where-Object {$_.Algorithm -in $Pool_WTM_Algo -and $_.CoinSymbol -eq $Pool_WTM.CoinSymbol} | Foreach-Object {
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
        $OutOfSyncTimer = ($Session.AllPools | Select-Object -ExpandProperty Updated | Measure-Object -Maximum).Maximum
        $OutOfSyncTime = $OutOfSyncTimer.AddMinutes(-$Session.OutofsyncWindow)
        $OutOfSyncDivisor = [Math]::Log($Session.OutofsyncWindow-$Session.SyncWindow) #precalc for sync decay method
        $OutOfSyncLimit = 1/($Session.OutofsyncWindow-$Session.SyncWindow)

        $Pools_Hashrates = @{}
        $Session.AllPools | Select-Object Algorithm,CoinSymbol,Hashrate,StablePrice | Group-Object -Property {"$($_.Algorithm)$($_.CoinSymbol)"} | Foreach-Object {$Pools_Hashrates[$_.Name] = ($_.Group | Where-Object StablePrice | Select-Object -ExpandProperty Hashrate | Measure-Object -Maximum).Maximum;if (-not $Pools_Hashrates[$_.Name]) {$Pools_Hashrates[$_.Name]=1}}
        $Session.AllPools | Where-Object {$_.TSL -ne $null -and $Session.Config.Pools."$($_.Name)".EnablePostBlockMining -and $_.CoinSymbol -and ($_.TSL -lt $Session.Config.Coins."$($_.CoinSymbol)".PostBlockMining)} | Foreach-Object {$_ | Add-Member PostBlockMining $true -Force}

        Write-Log "Selecting best pool for each algorithm. "
        $Session.AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($Session.AllPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending {$Session.Config.PoolName.Count -eq 0 -or (Compare-Object $Session.Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}, {$_.Exclusive -and -not $_.Idle}, {$Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and $Session.Config.Pools."$($_.Name)".FocusWallet -icontains $_.Currency}, {$LockMiners -and $Session.LockMiners.Pools -icontains "$($_.Name)-$($_.Algorithm)"}, {$_.PostBlockMining}, {-not $_.PostBlockMining -and (-not $_.CoinSymbol -or $Session.Config.Pools."$($_.Name)".CoinSymbolPBM -inotcontains $_.CoinSymbol)}, {$(if ($Session.Config.EnableFastSwitching -or $_.PPS) {$_.Price} else {$_.StablePrice * (1 - $_.MarginOfError*($Session.Config.PoolAccuracyWeight/100))}) * $(if ($_.Hashrate -eq $null -or -not $Session.Config.HashrateWeightStrength) {1} else {1-(1-[Math]::Pow($_.Hashrate/$Pools_Hashrates["$($_.Algorithm)$($_.CoinSymbol)"],$Session.Config.HashrateWeightStrength/100))*$Session.Config.HashrateWeight/100}) * ([Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1))}, {$_.Region -EQ $Session.Config.Region}, {[int](($ix = $Session.Config.DefaultPoolRegion.IndexOf($_.Region)) -ge 0)*(100-$ix)}, {$_.SSL -EQ $Session.Config.SSL} | Select-Object -First 1)}
        $Pools_OutOfSyncMinutes = ($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {$Session.AllPools | Where-Object Name -EQ $_ | Where-Object Updated -ge $OutOfSyncTime | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)
        if ($Pools_OutOfSyncMinutes -gt $Session.SyncWindow) {
            Write-Log "Pool prices are out of sync ($([int]$Pools_OutOfSyncMinutes) minutes). "
        }
        $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
            $Pools.$_ | Add-Member Price_SyncDecay ([Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $Pools.$_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)) -Force
            $Pool_Price = $Pools.$_.Price * $Pools.$_.Price_SyncDecay
            $Pool_Name  = $Pools.$_.Name
            $Pools.$_ | Add-Member Price_Bias ($Pool_Price * (1 - ([Math]::Floor(($Pools.$_.MarginOfError * [Math]::Min($Session.Config.SwitchingPrevention,1) * [Math]::Pow($Session.DecayBase, $DecayExponent / ([Math]::Max($Session.Config.SwitchingPrevention,1)))) * 100.00) / 100.00) * (-not $Pools.$_.PPS))) -Force
            $Pools.$_ | Add-Member Price_Unbias $Pool_Price -Force
            $Pools.$_ | Add-Member HasMinerExclusions ($Session.Config.Pools.$Pool_Name.MinerName.Count -or $Session.Config.Pools.$Pool_Name.ExcludeMinerName.Count) -Force
        }
        Remove-Variable "Pools_Hashrates"
    }

    #Give API access to the pools information
    $API.Pools = $Pools | ConvertTo-Json -Depth 10 -Compress
 
    #Load information about the miners
    Write-Log "Getting miner information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading miner modules .."}

    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Session.Config.MinerName, if specified, and don't match $Session.Config.ExcludeMinerName    
    if ($Session.Config.EnableAutoMinerPorts) {Set-ActiveMinerPorts @($Session.ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | Select-Object);Set-ActiveTcpPorts} else {Set-ActiveTcpPorts -Disable}
    $AllMiner_Warnings = @()
    $AllMiners = if (($Session.AllPools | Measure-Object).Count -gt 0 -and (Test-Path "Miners")) {
        Get-MinersContent -Pools $Pools | 
            Where-Object {$_.DeviceName -and ($_.DeviceModel -notmatch '-' -or -not (Compare-Object $_.DeviceName $Session.DeviceNames."$($_.DeviceModel)"))} | #filter miners for non-present hardware
            Where-Object {-not $Session.Config.DisableDualMining -or $_.HashRates.PSObject.Properties.Name.Count -eq 1} | #filter dual algo miners
            Where-Object {(Compare-Object @($Session.Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
            Where-Object {(Compare-Object @($Pools.PSObject.Properties.Name | Select-Object) @($_.HashRates.PSObject.Properties.Name | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} |             
            Where-Object {-not $Session.Config.Miners."$($_.BaseName)-$($_.DeviceModel)-$($_.BaseAlgorithm -join '-')".Disable} |
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
                    if ($Session.Config.Miners."$($_.BaseName)-$($p)-$($_.BaseAlgorithm -join '-')".Disable -or 
                        $Session.Config.Devices.$p -and
                        (
                            ($Session.Config.Devices.$p.DisableDualMining -and $_.HashRates.PSObject.Properties.Name.Count -gt 1) -or
                            ($Session.Config.Devices.$p.Algorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.Algorithm $_.BaseAlgorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0) -or
                            ($Session.Config.Devices.$p.ExcludeAlgorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.ExcludeAlgorithm $_.BaseAlgorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
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
    Remove-Variable "MinersNeedSdk"

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

    Write-Log "Calculating profit for each miner. "

    [hashtable]$AllMiners_VersionCheck = @{}
    [hashtable]$AllMiners_VersionDate  = @{}
    [System.Collections.ArrayList]$Miner_Arguments_List = @()
    $AllMiners | ForEach-Object {
        $Miner = $_

        $Miner | Add-Member Pools        ([PSCustomObject]@{})

        $Miner | Add-Member Difficulties ([hashtable]@{}) -Force
        $Miner | Add-Member Ratios       ([hashtable]@{}) -Force
        $Miner | Add-Member OCprofile    ([hashtable]@{}) -Force

        $Miner_Profits        = [hashtable]@{}
        $Miner_Profits_Bias   = [hashtable]@{}
        $Miner_Profits_Unbias = [hashtable]@{}
        $Miner_DevFees        = [hashtable]@{}

        foreach($p in @($Miner.DeviceModel -split '-')) {$Miner.OCprofile[$p] = ""}

        if ($Session.Config.Miners) {
            $Miner_CommonCommands = $Miner_Arguments = $Miner_Difficulty = ''
            $Miner_MSIAprofile = 0
            $Miner_Penalty = $Miner_ExtendInterval = $Miner_FaultTolerance = -1
            $Miner_CommonCommands_found = $false
            [System.Collections.ArrayList]$Miner_CommonCommands_array = @($Miner.BaseName,$Miner.DeviceModel)
            $Miner_CommonCommands_array.AddRange(@($Miner.BaseAlgorithm | Select-Object))
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

            Remove-Variable "Miner_CommonCommands_array"

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

        if (-not $Miner.MSIAprofile -and $Session.Config.Algorithms."$($Miner.BaseAlgorithm | Select-Object -First 1)".MSIAprofile -gt 0) {$Miner | Add-Member -Name MSIAprofile -Value $Session.Config.Algorithms."$($Miner.BaseAlgorithm | Select-Object -First 1)".MSIAprofile -MemberType NoteProperty -Force}

        foreach($p in @($Miner.DeviceModel -split '-')) {if ($Miner.OCprofile[$p] -eq '') {$Miner.OCprofile[$p]=if ($Session.Config.Algorithms."$($Miner.BaseAlgorithm | Select-Object -First 1)".OCprofile -ne "") {$Session.Config.Algorithms."$($Miner.BaseAlgorithm | Select-Object -First 1)".OCprofile} else {$Session.Config.Devices.$p.DefaultOCprofile}}}
        $FirstAlgoName = ""
        $NoResult = $false
        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object {
            if (-not $FirstAlgoName) {$FirstAlgoName = $_}

            $Miner.Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)

            $Miner_DevFees[$_] = ([Double]$(if (-not $Session.Config.IgnoreFees -and $Miner.DevFee) {[Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.DevFee.GetType().Name) {$Miner.DevFee.$_} else {$Miner.DevFee})} else {0}))

            if (-not [String]$Miner.HashRates.$_) {
                $Miner.HashRates.$_       = $null
                $Miner.Difficulties[$_]   = $null
                $Miner.Ratios[$_]         = $null
                $NoResult = $true
            } else {
                $Miner_DevFeeFactor = (1-$Miner_DevFees[$_]/100)
                if ($Miner.Penalty) {$Miner_DevFeeFactor -= [Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.Penalty.GetType().Name) {$Miner.Penalty.$_} else {$Miner.Penalty})/100;if ($Miner_DevFeeFactor -lt 0){$Miner_DevFeeFactor=0}}
                $Miner.HashRates.$_       = [Double]$Miner.HashRates.$_
                $Miner.Difficulties[$_]   = ([Double]$Session.Stats."$($Miner.Name)_$($_ -replace '\-.*$')_HashRate".Diff_Average)
                $Miner.Ratios[$_]         = ([Double]$Session.Stats."$($Miner.Name)_$($_ -replace '\-.*$')_HashRate".Ratio_Live)
                $Miner_Profits[$_]        = ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * $Miner_DevFeeFactor)
                $Miner_Profits_Bias[$_]   = ([Double]$Miner.HashRates.$_ * ($Pools.$_.Price_Bias+1e-32) * $Miner_DevFeeFactor)
                $Miner_Profits_Unbias[$_] = ([Double]$Miner.HashRates.$_ * ($Pools.$_.Price_Unbias+1e-32) * $Miner_DevFeeFactor)
            }
        }

        if ($NoResult) {
            $Miner_Profit        = $null
            $Miner_Profit_Bias   = $null
            $Miner_Profit_Unbias = $null
            $Miner_Profit_Cost   = $null
        } else {
            $Miner_Profit        = [Double]($Miner_Profits.Values | Measure-Object -Sum).Sum
            $Miner_Profit_Bias   = [Double]($Miner_Profits_Bias.Values | Measure-Object -Sum).Sum
            $Miner_Profit_Unbias = [Double]($Miner_Profits_Unbias.Values | Measure-Object -Sum).Sum
            $Miner_Profit_Cost   = [Double]($Miner.PowerDraw*24/1000 * $PowerPriceBTC)
            if ($Miner.DeviceName -match "^CPU" -and $Session.Config.PowerOffset -gt 0) {$Miner_Profit_Cost=0}
        }

        Remove-Variable "Miner_Profits"
        Remove-Variable "Miner_Profits_Bias"
        Remove-Variable "Miner_Profits_Unbias"

        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Bias $Miner_Profit_Bias
        $Miner | Add-Member Profit_Unbias $Miner_Profit_Unbias
        $Miner | Add-Member Profit_Cost $Miner_Profit_Cost
        if ($Miner.PSObject.Properties.Name -contains "DevFee") {
            $Miner.DevFee = $Miner_DevFees
        } else {
            $Miner | Add-Member DevFee $Miner_DevFees -Force
        }

        $HmF = $Miner.DeviceModel -ne "CPU" -and $Session.Config.EnableHeatMyFlat -and $Miner.PowerDraw

        if (($Session.Config.UsePowerPrice -or $HmF) -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {
            if ($Session.Config.UsePowerPrice) {
                $Miner.Profit -= $Miner.Profit_Cost
            }
            $Hmf = if ($HmF) {0.5 - $Session.Config.EnableHeatMyFlat/10} else {1.0}
            $Miner.Profit_Bias -= $Miner.Profit_Cost * $HmF
            $Miner.Profit_Unbias -= $Miner.Profit_Cost * $HmF
        }

        $Miner.DeviceName = @($Miner.DeviceName | Select-Object -Unique | Sort-Object)

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $AllMiners_VersionCheck.ContainsKey($Miner.BaseName)) {
            $Miner_UriJson = Join-Path (Get-MinerInstPath $Miner.Path) "_uri.json"
            $Miner_Uri = ""
            if ((Test-Path $Miner.Path) -and (Test-Path $Miner_UriJson)) {$Miner_Uri = Get-Content $Miner_UriJson -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty URI; $AllMiners_VersionDate[$Miner.BaseName] = (Get-ChildItem $Miner_UriJson).LastWriteTime.ToUniversalTime()}
            $AllMiners_VersionCheck[$Miner.BaseName] = $Miner_Uri -eq $Miner.URI            
        }

        if ($Session.Config.EnableAutoBenchmark -and ($Session.Config.MiningMode -eq "legacy" -or $Miner.DeviceModel -notmatch '-') -and $AllMiners_VersionDate[$Miner.BaseName] -ne $null -and $Session.Stats.ContainsKey("$($Miner.Name)_$($Miner.BaseAlgorithm[0])_HashRate") -and $Session.Stats["$($Miner.Name)_$($Miner.BaseAlgorithm[0])_HashRate"].Updated -lt $AllMiners_VersionDate[$Miner.BaseName]) {
            Get-ChildItem ".\Stats\Miners\*-$($Miner.Name -replace "-(CPU|GPU)#.+")-$($Miner.DeviceName -join '*')*_$($Miner.BaseAlgorithm[0])_HashRate.txt" | Remove-Item -ErrorAction Ignore
            if ($Miner.BaseAlgorithm[1]) {
                Get-ChildItem ".\Stats\Miners\*-$($Miner.Name -replace "-(CPU|GPU)#.+")-$($Miner.DeviceName -join '*')*_$($Miner.BaseAlgorithm[1])_HashRate.txt" | Remove-Item -ErrorAction Ignore
            }
        }

        if ($Miner.Arguments -is [string]) {$Miner.Arguments = ($Miner.Arguments -replace "\s+"," ").trim()}
        else {
            if ($Miners.Arguments.Params -is [string]) {$Miners.Arguments.Params = ($Miner.Arguments.Params -replace "\s+"," ").trim()}
            $Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress
        }
        try {$Miner_Difficulty = [double]($Miner_Difficulty -replace ",","." -replace "[^\d\.]")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Miner_Difficulty=0.0}
        if ($Miner.Arguments) {$Miner.Arguments = $Miner.Arguments -replace "\`$difficulty",$Miner_Difficulty -replace "{diff:(.+?)}","$(if ($Miner_Difficulty -gt 0){"`$1"})" -replace "{workername}|{workername:$($Session.Config.WorkerName)}",$(@($Miner.DeviceModel -split '\-' | Foreach-Object {if ($Session.Config.Devices.$_.Worker) {$Session.Config.Devices.$_.Worker} else {$Session.Config.WorkerName}} | Select-Object -Unique) -join '_') -replace "{workername:(.+?)}","`$1"}
                
        if (-not $Miner.ExtendInterval) {$Miner.ExtendInterval = 1}
        if (-not $Miner.FaultTolerance) {$Miner.FaultTolerance = if ($Miner.DeviceName -match "^CPU") {0.25} else {0.1}}
        if (-not $Miner.Penalty)        {$Miner.Penalty = 0}
        if (-not $Miner.API)            {$Miner | Add-Member API "Miner" -Force}
        if ($Miner.EnvVars -eq $null)   {$Miner | Add-Member EnvVars @() -Force}
    }
    Remove-Variable "Miner_Arguments_List" -Force

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
    $API.DownloadList = $Miners_DownloadList | ConvertTo-Json -Depth 10 -Compress
    $Miners_Downloading = $Miners_DownloadList.Count
    Remove-Variable "AllMiners_VersionCheck" -Force
    Remove-Variable "AllMiners_VersionDate" -Force
    Remove-Variable "Miners_DownloadList" -Force
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
                }
                Remove-Variable "OpenFirewallFor"
            }
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
    Remove-Variable "AllMiners"

    #Remove miners with developer fee
    if ($Session.Config.ExcludeMinersWithFee) {$Miners = $Miners | Where-Object {($_.DevFee.PSObject.Properties.Value | Foreach-Object {[Double]$_} | Measure-Object -Sum).Sum -eq 0}}

    $Miners_BeforeWD_Count = ($Miners | Measure-Object).Count

    #Store miners to file
    if (-not $Session.IsDonationRun -and -not $Session.Benchmarking -and (-not $Session.Updatetracker.MinerSave -or $Session.Updatetracker.MinerSave -lt (Get-Date).AddHours(-6) -or -not (Test-Path ".\Data\minerdata.json"))) {
        $Session.Updatetracker.MinerSave = Get-Date
        Set-ContentJson ".\Data\minerdata.json" ([PSObject]@{Miners = @($Miners | Select-Object @{Name="Name";Expression={$_.BaseName}}, Version, @{Name="Algorithm";Expression={$_.BaseAlgorithm | Select-Object -First 1}}, @{Name="DeviceName";Expression={$_.DeviceName -join '-'}}, DeviceModel, @{Name="HashRate"; Expression={$_.HashRates.PSObject.Properties.Value | Select-Object -First 1}}, PowerDraw, @{Name="OCProfile"; Expression={if ($Session.Config.EnableOCProfiles -and $_.DeviceModel -ne "CPU" -and $_.DeviceModel -notmatch '-') {$_.OCprofile.Values | Select-Object -First 1} else {""}}} -Unique); OCprofiles=$Session.Config.OCprofiles; CPU=$Session.DevicesByTypes.CPU.Model_Name | Select-Object -Unique}) -Compress > $null
        $Session.ReportMinerData = $true
    }

    #Apply watchdog to miners
    $Miners = $Miners | Where-Object {
        $Miner = $_
        $Miner_WatchdogTimers = $Session.WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Session.Timer.AddSeconds( - $Session.WatchdogInterval) | Where-Object Kicked -GT $Session.Timer.AddSeconds( - $Session.WatchdogReset)
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
    }

    #Give API access to the miners information
    $API.Miners = $Miners | ConvertTo-Json -Depth 10 -Compress

    #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    if ($Session.Config.FastestMinerOnly) {$Miners = $Miners | Sort-Object -Descending {"$($_.DeviceName -join '')$($_.BaseAlgorithm -join '')$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {([Double]($_ | Measure-Object Profit_Bias -Sum).Sum)}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm -join '')$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"} | Foreach-Object {$_.Group[0]}}
 
    #Give API access to the fasted miners information
    $API.FastestMiners = $Miners | ConvertTo-Json -Depth 10 -Compress

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used
    $MinersNeedingBenchmark = $Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null}
    $MinersNeedingBenchmarkCount = ($MinersNeedingBenchmark | Measure-Object).Count
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark | ConvertTo-Json -Depth 10 -Compress

    #Update the active miners
    $Session.ActiveMiners | Foreach-Object {
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
        $ActiveMiner = $Session.ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and
            $_.Path -eq $Miner.Path -and
            $_.Arguments -eq $Miner.Arguments -and
            $_.API -eq $Miner.API -and
            $_.Port -eq $Miner.Port -and
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }

        $FirstAlgoName            = $Miner.HashRates.PSObject.Properties.Name | Select-Object -First 1

        $Miner_MinSamples         = if ($Miner.MinSamples) {$Miner.MinSamples} else {3} #min. 10 seconds, 3 samples needed
        $Miner_IsFocusWalletMiner = ($Session.Config.Pools."$($Miner.Pools.PSObject.Properties.Value.Name)".FocusWallet -and $Session.Config.Pools."$($Miner.Pools.PSObject.Properties.Value.Name)".FocusWallet.Count -gt 0 -and (Compare-Object $Session.Config.Pools."$($Miner.Pools.PSObject.Properties.Value.Name)".FocusWallet $Miner.Pools.PSObject.Properties.Value.Currency -IncludeEqual -ExcludeDifferent))
        $Miner_IsExclusiveMiner   = (($Miner.Pools.PSObject.Properties.Value | Where-Object Exclusive | Measure-Object).Count -gt 0)
        $Miner_IsLocked           = ($LockMiners -and $Session.LockMiners.Pools -icontains "$($Miner.Pools.$FirstAlgoName.Name)-$($FirstAlgoName)")

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
            $ActiveMiner.DevFee             = $Miner.DevFee
            $ActiveMiner.MSIAprofile        = $Miner.MSIAprofile
            $ActiveMiner.OCprofile          = $Miner.OCprofile
            $ActiveMiner.FaultTolerance     = $Miner.FaultTolerance
            $ActiveMiner.Penalty            = $Miner.Penalty
            $ActiveMiner.PoolPenalty        = $Miner.Pools.PSObject.Properties.Value.Penalty
            $ActiveMiner.ManualUri          = $Miner_ManualUri
            $ActiveMiner.EthPillEnable      = $Session.Config.EthPillEnable
            $ActiveMiner.EthPillEnableMTP   = $Session.Config.EthPillEnableMTP
            $ActiveMiner.DataInterval       = $Session.Config.BenchmarkInterval
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
        }
        else {
            #Write-Log "New miner object for $($Miner.BaseName)"
            $Session.ActiveMiners += New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                Version              = $Miner.Version
                BaseName             = $Miner.BaseName
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                BaseAlgorithm        = $Miner.BaseAlgorithm
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
                OCprofile            = $Miner.OCprofile
                ExtendInterval       = $Miner.ExtendInterval
                ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow -or $IsLinux)
                DevFee               = $Miner.DevFee
                FaultTolerance       = $Miner.FaultTolerance
                Penalty              = $Miner.Penalty
                PoolPenalty          = $Miner.Pools.PSObject.Properties.Value.Penalty
                ManualUri            = $Miner_ManualUri
                EthPillEnable        = $Session.Config.EthPillEnable
                EthPillEnableMTP     = $Session.Config.EthPillEnableMTP
                DataInterval         = $Session.Config.BenchmarkInterval
                Donator              = $Session.IsDonationRun
                MaxBenchmarkRounds   = $Session.Strikes
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
        }
    }

    $Session.ActiveMiners_DeviceNames = @($Session.ActiveMiners | Where-Object Enabled | Select-Object -ExpandProperty DeviceName -Unique | Sort-Object)

    #Don't penalize active miners and control round behavior
    $Session.ActiveMiners | Where-Object {$Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching -or ($_.GetStatus() -eq [MinerStatus]::Running)} | Foreach-Object {
        $_.Profit_Bias = $_.Profit_Unbias
        if (-not ($Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching) -or ($_.GetStatus() -eq [MinerStatus]::Running)) {
            if ($_.Rounds -lt $Session.Config.MinimumMiningIntervals -and -not $Session.IsBenchmarkingRun) {$_.IsRunningFirstRounds=$true}
        }
    }

    $Session.Profitable = $true

    if (($Miners | Measure-Object).Count -gt 0) {
        #Get most profitable miner combination
        $BestMiners             = $Session.ActiveMiners | Where-Object Enabled | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($Session.ActiveMiners | Where-Object {$_.Enabled -and (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}

        #If post block mining: check for minimum profit
        if ($Miners_PBM = $BestMiners | Where-Object {$_.PostBlockMining -gt 0 -and -not $_.IsExclusiveMiner -and -not $_.IsLocked -and -not $_.IsFocusWalletMiner -and -not $_.NeedsBenchmark -and -not $_.IsRunningFirstRounds -and $Session.Config.Coins."$($_.CoinSymbol)".MinProfitPercent -gt 0}) {
            $Miners_PBM | Foreach-Object {
                $Miner_PBM = $_
                $BestMiner = $Session.ActiveMiners | Where-Object {$_.Enabled -and $_.PostBlockMining -eq 0 -and (Compare-Object $Miner_PBM.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1
                $BestMiner_Profit = $BestMiner.Profit + $(if ($Session.Config.UsePowerPrice -and $BestMiner.Profit_Cost -ne $null -and $BestMiner.Profit_Cost -gt 0) {$BestMiner.Profit_Cost})
                $Miner_PBM_Profit = $Miner_PBM.Profit + $(if ($Session.Config.UsePowerPrice -and $Miner_PBM.Profit_Cost -ne $null -and $Miner_PBM.Profit_Cost -gt 0) {$Miner_PBM.Profit_Cost})
                if ($BestMiner -and ($BestMiner_Profit * $Session.Config.Coins."$($Miner_PBM.CoinSymbol)".MinProfitPercent / 100 -gt $Miner_PBM_Profit)) {
                    $BestMiners = (@($BestMiners | Select-Object) + $BestMiner) | Where-Object {$_ -ne $Miner_PBM}
                }
            }
        }
        Remove-Variable "Miners_PBM" -Force

        $NoCPUMining = $Session.Config.EnableCheckMiningConflict -and $MinersNeedingBenchmarkCount -eq 0 -and ($BestMiners | Where-Object DeviceModel -eq "CPU" | Measure-Object).Count -and ($BestMiners | Where-Object NoCPUMining -eq $true | Measure-Object).Count
        if ($NoCPUMining) {$BestMiners2 = $Session.ActiveMiners | Where-Object Enabled | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($Session.ActiveMiners | Where-Object {-not $_.NoCPUMining -and $_.Enabled -and (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}}

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
            $BestMiners_Combo = $BestMiners_Combo | Group-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.BaseAlgorithm -join '')$($_.Currency)$($_.CoinSymbol)"} | Foreach-Object {
                $Combo_Name    = $_.Name
                $Combo_Devices = @($_.Group.DeviceName | Select-Object -Unique | Sort-Object)
                $BestMiners_Multi = if ($_.Count -gt 1) {$BestMiners | Where-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.BaseAlgorithm -join '')$($_.Currency)$($_.CoinSymbol)" -eq $Combo_Name -and (Compare-Object $_.DeviceName $Combo_Devices | Measure-Object).Count -eq 0} | Sort-Object Profit_Bias -Descending | Select-Object -First 1}
                if ($BestMiners_Multi -and (($_.Group.Profit_Bias | Measure-Object -Sum).Sum*$Session.Config.MinComboOverSingleRatio -lt $BestMiners_Multi.Profit_Bias)) {$BestMiners_Multi} else {$_.Group}
            }
        }

        $PowerOffset_Cost = [Double]0
        if (($Session.AllPools | Measure-Object).Count -gt 0 -and $Check_Profitability) {
            $PowerOffset_Cost = [Double]($Session.Config.PowerOffset*24/1000 * $PowerPriceBTC)
            if ((($BestMiners_Combo.Profit | Measure-Object -Sum).Sum - $PowerOffset_Cost) -le 0) {
                Write-Log -Level Warn "No more miners are profitable. $(if ($Session.Config.CheckProfitability) {" Waiting for profitability."})"
                if ($Session.Config.CheckProfitability -and ($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner -or $_.IsLocked} | Measure-Object).Count -eq 0) {$Session.Profitable = $false}
            }
        }

        if ($Session.PauseMinersByScheduler -and $Session.IsExclusiveRun) {$Session.PauseMinersByScheduler = $false}

        if (-not $Session.PauseMiners -and -not $Session.PauseMinersByScheduler -and -not $Session.AutoUpdate -and $Session.Profitable) {
            $BestMiners_Combo | ForEach-Object {$_.Best = $true}
        }
    }

    if ($Session.RoundCounter -eq 0) {Write-Host "Starting mining operation .."}

    #Stop failed miners
    $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::RunningFailed} | Foreach-Object {
        Write-Log -Level Info "Stopping crashed miner ($($_.Name)) "
        $_.CrashCount++
        Write-ActivityLog $_ -Crashed 1
        $_.SetStatus([MinerStatus]::Idle)
    }

    #Stop or start miners in the active list depending on if they are the most profitable
    $Session.ActiveMiners | Where-Object {(($_.Best -EQ $false) -or $Session.RestartMiners) -and $_.GetActivateCount() -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {
        $Miner = $_
        Write-Log -Level Info "Stopping miner $($Miner.Name) on pool $($Miner.Pool -join '/'). "
        $Miner.SetStatus([MinerStatus]::Idle)
        $Miner.Stopped = $true

        #Remove watchdog timer
        if ($Session.Config.Watchdog -and $Session.WatchdogTimers) {
            $Miner_Name = $Miner.Name
            $Miner_Index = 0
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $Miner_Pool = $Miner.Pool[$Miner_Index]
                $WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Miner_Pool -and $_.Algorithm -eq $Miner_Algorithm}
                if ($WatchdogTimer) {
                    if (($WatchdogTimer.Kicked -lt $Session.Timer.AddSeconds( - $Session.WatchdogInterval)) -and -not $Session.RestartMiners) {
                        Write-ActivityLog $Miner -Crashed 2
                        $Miner.SetStatus([MinerStatus]::Failed)
                        Write-Log -Level Warn "Miner $Miner_Name mining $($Miner_Algorithm) on pool $($Miner_Pool) temporarily disabled. "
                    }
                    else {
                        $Session.WatchdogTimers = $Session.WatchdogTimers -ne $WatchdogTimer
                    }
                }
                $Miner_Index++
            }
        }
    }
    
    if ($IsWindows) {
        Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {$_.ExecutablePath -like "$(Get-Location)\Bin\*"} | Where-Object {@($Session.ActiveMiners | Foreach-Object {$_.GetProcessIds()} | Where-Object {$_} | Select-Object -Unique) -notcontains $_.ProcessId -and @($Session.ActiveMiners | Select-Object -ExpandProperty Path | Split-Path -Leaf | Select-Object -unique) -icontains $_.ProcessName} | Select-Object ProcessId,ProcessName | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore}
    } elseif ($IsLinux) {
        Get-Process | Where-Object Path | Where-Object {$_.Path -like "$(Get-Location)/bin/*"} | Where-Object {-not (Compare-Object @($Session.ActiveMiners | Foreach-Object {$_.GetProcessIds()} | Where-Object {$_} | Select-Object -Unique) @($_.Id,$_.Parent.Id) -ExcludeDifferent -IncludeEqual) -and @($Session.ActiveMiners | Select-Object -ExpandProperty Path | Split-Path -Leaf | Select-Object -unique) -icontains $_.ProcessName} | Select-Object Id,ProcessName | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.Id)"; if (Test-OCDaemon) {Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null} else {Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }

    if ($Session.Downloader.HasMoreData) {$Session.Downloader | Receive-Job}
    if ($Session.Config.Delay -gt 0) {Start-Sleep $Session.Config.Delay} #Wait to prevent BSOD

    $Session.ActiveMiners | Where-Object {$_.Best -EQ $true -and $_.GetStatus() -ne [MinerStatus]::Running} | ForEach-Object {

        if ($_.DeviceModel -ne "CPU") {
            if ($Session.Config.EnableResetVega) {Reset-Vega $_.DeviceName}

            #Set MSI Afterburner profile
            if ($MSIAenabled) {
                $MSIAplannedprofile = $Session.ActiveMiners | Where-Object {$_.Best -eq $true -and $_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0} | Select-Object -ExpandProperty MSIAprofile -Unique
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

        $_.SetStatus([MinerStatus]::Running)

        #Add watchdog timer
        if ($Session.Config.Watchdog -and $_.Profit -ne $null) {
            $Miner_Name = $_.Name
            $Miner_DeviceModel = $_.DeviceModel
            $_.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if (-not $WatchdogTimer) {
                    $Session.WatchdogTimers += [PSCustomObject]@{
                        MinerName = $Miner_Name
                        DeviceModel= $Miner_DeviceModel
                        PoolName  = $Pools.$Miner_Algorithm.Name
                        Algorithm = $Miner_Algorithm
                        Kicked    = $Session.Timer
                    }
                }
                elseif (-not ($WatchdogTimer.Kicked -GT $Session.Timer.AddSeconds( - $Session.WatchdogReset))) {
                    $WatchdogTimer.Kicked = $Session.Timer
                }
            }
        }
    }

    $IsExclusiveRun = $Session.IsExclusiveRun
    $Session.IsExclusiveRun = ($Session.ActiveMiners | Where-Object {$_.IsExclusiveMiner -and $_.GetStatus() -eq [MinerStatus]::Running} | Measure-Object).Count -gt 0

    #Move donation run into the future, if benchmarks are ongoing
    if ((-not $Session.IsDonationRun -and $MinersNeedingBenchmarkCount -gt 0) -or $Session.IsExclusiveRun) {
        $ShiftDonationRun = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)
        if (-not $Session.LastDonated -or $Session.LastDonated -lt $ShiftDonationRun) {$Session.LastDonated = Set-LastDrun $ShiftDonationRun}
    }

    #Update API miner information
    #$RunningMiners = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {$_ | Add-Member ActiveTime $_.GetActiveTime() -Force -PassThru}
    $API.ActiveMiners  = $Session.ActiveMiners | Where-Object {$_.Profit -or $_.IsFocusWalletMiner}
    $API.RunningMiners = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running}
    $API.FailedMiners  = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Failed}

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
    } elseif (($Session.AllPools | Measure-Object).Count -eq 0) {
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
            @{Label = "Power$(if ($Session.Config.UsePowerPrice -and $Session.Config.PowerOffset -gt 0){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}; Align = 'right'}
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
                $MinersNeedingBenchmark | Select-Object BaseName,BaseAlgorithm,ExtendInterval | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Sort-Object -Property @{Expression = {$_.ExtendInterval}; Descending = $True},@{Expression = {$_.BaseName + $_.BaseAlgorithm -join '-'}; Descending = $False} | Format-Table (
                    @{Label = "Miner"; Expression = {$_.BaseName}},
                    @{Label = "Algorithms"; Expression = {$_.BaseAlgorithm -join '-'}},
                    @{Label = "Aprox. Time"; Expression = {"$($BenchmarkMinutes*$_.ExtendInterval)-$($BenchmarkMinutes*$_.ExtendInterval*2) minutes"}}
                )
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
    $Session.ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and ($_.GetStatus() -eq [MinerStatus]::Running -or (-not $_.Donator -and ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) -and ($_.GetActiveLast() -gt (Get-Date).AddSeconds(-5*$Session.Config.Interval))))} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} -Wrap (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd}d/{0:hh}h/{0:mm}m" -f $_.GetActiveTime()}}, 
        @{Label = "Started"; Expression = {Switch ($_.GetActivateCount()) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}},      
        @{Label = "Miner"; Expression = {"$($_.Name -replace '\-.*$')$(if ($_.IsFocusWalletMiner -or $_.IsExclusiveMiner) {"(!)"} elseif ($_.PostBlockMining -gt 0) {"($($_.PostBlockMining)s)"} elseif ($Session.Config.MinimumMiningIntervals -gt 1 -and $MinersNeedingBenchmarkCount -eq 0 -and ($_.IsRunningFirstRounds -or ($_.Rounds -eq 0 -and $_.GetStatus() -eq [MinerStatus]::Running))) {"($($_.Rounds+1)/$($Session.Config.MinimumMiningIntervals))"})"}},
        @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.BaseAlgorithm}},
        @{Label = "Coin"; Expression = {$_.CoinName | Foreach-Object {if ($_) {$_} else {"-"}}}},
        @{Label = "Device"; Expression = {@(Get-DeviceModelName $Session.Devices -Name @($_.DeviceName) -Short) -join ','}},
        @{Label = "Power$(if ($Session.Config.UsePowerPrice -and $Session.Config.PowerOffset -gt 0){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}},
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host

    if ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) {
        #Display watchdog timers
        $Session.WatchdogTimers | Where-Object Kicked -gt $Session.Timer.AddSeconds( - $Session.WatchdogReset) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName -replace '\-.*$'}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Session.Devices -Name @($_.DeviceName) -Short) -join ','}}, 
            @{Label = "Pool"; Expression = {$_.PoolName}}, 
            @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.Algorithm}}, 
            @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Session.Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
        ) | Out-Host
    }

    if ($Session.Config.UsePowerPrice -and $Session.Config.PowerOffset -gt 0) {Write-Host "* net power consumption. A base power offset of $("{0:d}" -f [int]$Session.Config.PowerOffset)W is being added to calculate the final profit."; Write-Host " "}

    #Display pool balances, formatting it to show all the user specified currencies
    if ($Session.Config.ShowPoolBalances -and $BalancesData -and $BalancesData.Count -gt 1) {
        $ColumnMark = if ($Session.EnableColors) {"$([char]27)[93m{value}$([char]27)[0m"} else {"{value}"}
        $NextBalances = $Session.Config.BalanceUpdateMinutes-[int]((Get-Date).ToUniversalTime()-$Session.Updatetracker.Balances).TotalMinutes
        $NextBalances = if ($NextBalances -gt 0){"in $($NextBalances) minutes"}else{"now"}
        Write-Host "Pool Balances as of $([System.Timezone]::CurrentTimeZone.ToLocalTime($Session.Updatetracker.Balances)) (next update $($NextBalances)): "        
        $Columns = @()
        $ColumnFormat = [Array]@{Name = "Name"; Expression = "Name"}
        if (($BalancesData.Currency | Select-Object -Unique | Measure-Object).Count -gt 1) {
            $ColumnFormat += @{Name = "Sym"; Expression = {if ($_.Currency -and (-not $Session.Config.Pools."$($_.Name)".AECurrency -or $Session.Config.Pools."$($_.Name)".AECurrency -eq $_.Currency)) {$ColumnMark -replace "{value}","$($_.Currency)"} else {$_.Currency}}}
            $ColumnFormat += @{Name = "Balance"; Expression = {$_."Balance ($($_.Currency))"}}            
        }
        $Columns += $BalancesData | Foreach-Object {$_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name} | Where-Object {$_ -like "Value in *"} | Sort-Object -Unique
        $ColumnFormat += $Columns | Foreach-Object {@{Name = "$($_ -replace "Value in\s+")"; Expression = "$_"; Align = "right"}}
        $BalancesData | Format-Table -Wrap -Property $ColumnFormat
        Remove-Variable "Columns" -Force
        Remove-Variable "ColumnFormat" -Force
        Remove-Variable "BalancesData" -Force
    }

    #Display exchange rates
    $CurrentProfitTotal = $CurrentProfitWithoutCostTotal = $($Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty Profit | Measure-Object -Sum).Sum
    if ($Session.Config.UsePowerPrice) {$CurrentProfitTotal -= $PowerOffset_Cost;$CurrentProfitWithoutCostTotal += $($Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty Profit_Cost | Measure-Object -Sum).Sum}
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
    Remove-Variable "StatusLine"

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
    @("BalancesData","BestMiners_Combo","BestMiners_Combo2","CcMiner","CcMinerNameToAdd","ComboAlgos","ConfigBackup","Miner","Miner_Table","Miners","Miners_Device_Combos","AllCurrencies","MissingCurrencies","MissingCurrenciesTicker","p","Pool","Pools","Pool_Config","Pool_Parameters","Pool_WatchdogTimers","q") | Foreach-Object {Remove-Variable $_ -ErrorAction Ignore}
    if ($Error.Count) {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").main.txt" -Append -Encoding utf8}
    $Error.Clear()
    $Global:Error.Clear()
    Get-Job -State Completed | Remove-Job -Force

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    Get-MemoryUsage -ForceFullCollection >$null

    $Session.Timer = (Get-Date).ToUniversalTime()

    #Start asyncloader after first run
    if (Test-Path Variable:Global:AsyncLoader) {$AsyncLoader.Pause = $false}

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
    Remove-Variable "cmdMenu"
        
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
                            $Session.LockMiners.Pools = @($Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {"$($_.Pool | Select-Object -First 1)-$($_.BaseAlgorithm | Select-Object -First 1)"} | Select-Object)
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
                    Write-Host -NoNewline "[W] pressed - resetting WatchDog."
                    $Session.WatchdogTimers = @()
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
    $Session.ActiveMiners | Where-Object {$_.Stopped} | Foreach-Object {$_.StopMiningPostCleanup()}
        
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
    $Session.ActiveMiners | Where-Object {$_.GetActivateCount() -gt 0 -or $_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {
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