using module .\MinerAPIs.psm1
using module .\PauseMiners.psm1

##
## Core functions
##

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

        if ((Compare-Version $PSVersionTable.PSVersion $Session.SupportedPSVersion) -lt 0) {
            $CurrentPSVersion = Get-Version $PSVersionTable.PSVersion
            Write-Host "RainbowMiner recommends PowerShell Core Version $($Session.SupportedPSVersion) (vs. v$($CurrentPSVersion.Major).$($CurrentPSVersion.Minor).$($CurrentPSVersion.Build))" -ForegroundColor Yellow
            if ($CurrentPSVersion.Major -eq 7 -and $CurrentPSVersion.Minor -eq 1 -and $CurrentPSVersion.Build -eq 0) {
                Write-Host "The v7.1.0 contains a serious bug, consider updating your PowerShell" -ForegroundColor Yellow
            } else {
                Write-Host "Everything will run fine with the current version, but consider updating your PowerShell" -ForegroundColor Yellow
            }
            Write-Host " "
            if ($IsWindows) {
                $PSUpdateMessage = "Link for PowerShell: https://github.com/PowerShell/PowerShell/releases/tag/v$($Session.SupportedPSVersion)"
            } else {
                $PSUpdateMessage = "To update, run `"sudo ./install.sh -pu`" in folder $($PWD)"
            }
            Write-Host $PSUpdateMessage -BackgroundColor Yellow -ForegroundColor Black
            Write-Log -Level Info $PSUpdateMessage
            Write-Host " "
        }

        #Setup Core script variables
        [hashtable]$Global:StatsCache   = @{}
        [hashtable]$Global:DeviceCache  = @{}
        [hashtable]$Global:Rates        = @{BTC = [Double]1}
        [hashtable]$Global:MinerInfo    = @{}

        [System.Collections.ArrayList]$Global:ActiveMiners   = @()
        $Global:WatchdogTimers  = @()
        $Global:CrashCounter    = @()
        $Global:AlgorithmMinerName = @()

        $Global:PauseMiners = [PauseMiners]::new()

        $Global:AllPools = $null

        #Setup session variables
        [hashtable]$Session.ConfigFiles = @{
            Config        = @{Path='';LastWriteTime=0;Healthy=$false}
            Devices       = @{Path='';LastWriteTime=0;Healthy=$false}
            Miners        = @{Path='';LastWriteTime=0;Healthy=$false}
            OCProfiles    = @{Path='';LastWriteTime=0;Healthy=$false}
            Userpools     = @{Path='';LastWriteTime=0;Healthy=$false}
            Pools         = @{Path='';LastWriteTime=0;Healthy=$false}
            Algorithms    = @{Path='';LastWriteTime=0;Healthy=$false}
            Coins         = @{Path='';LastWriteTime=0;Healthy=$false}
            GpuGroups     = @{Path='';LastWriteTime=0;Healthy=$false}
            Scheduler     = @{Path='';LastWriteTime=0;Healthy=$false}
            Combos        = @{Path='';LastWriteTime=0;Healthy=$false}
            MRR           = @{Path='';LastWriteTime=0;Healthy=$true}
        }

        [System.Collections.Generic.List[string]]$Session.GetTicker = @()

        $Session.StartTime         = if ($LastStartTime = (Get-LastStartTime)) {$LastStartTime} else {(Get-Date).ToUniversalTime()}
        $Session.StartTimeCore     = (Get-Date).ToUniversalTime()

        $Session.Strikes           = 3
        $Session.SyncWindow        = 10 #minutes, after that time, the pools bias price will start to decay
        $Session.OutofsyncWindow   = 60 #minutes, after that time, the pools price bias will be 0
        $Session.DecayPeriod       = 60 #seconds
        $Session.DecayBase         = 1 - 0.1 #decimal percentage

        $Session.RoundCounter = 0

        $Session.SkipSwitchingPrevention = $false
        $Session.StartDownloader = $false
        $Session.RestartMiners = $false
        $Session.Restart = $false
        $Session.LockMiners = [PSCustomObject]@{Locked=$false;Enabled=$false;Pools=@()}
        $Session.AutoUpdate = $false
        $Session.RestartComputer = $false
        $Session.MSIAcurrentprofile = -1
        $Session.RunSetup = Get-Yes $SetupOnly
        $Session.SetupOnly = Get-Yes $SetupOnly
        $Session.IsBenchmarkingRun = $false
        $Session.IsDonationRun = $false
        $Session.IsServerDonationRun = $false
        $Session.IsExclusiveRun = $false
        $Session.IsInitialSetup = $false
        $Session.Stopp = $false
        $Session.Benchmarking = $false
        $Session.ReportTotals = $false
        $Session.ReportMinerData = $false
        $Session.ReportPoolsData = $false
        $Session.ReportDeviceData = $false
        $Session.TimeDiff = 0
        $Session.PhysicalCPUs = 0
        $Session.UserConfig = $null
        $Session.LastDonated = $null

        try {$Session.EnableColors = [System.Environment]::OSVersion.Version -ge (Get-Version "10.0") -and $PSVersionTable.PSVersion -ge (Get-Version "5.1")} catch {if ($Error.Count){$Error.RemoveAt(0)};$Session.EnableColors = $false}

        if ($Session.IsAdmin) {Write-Log "Run as administrator"}

        #Set env variables
        if ($env:GPU_FORCE_64BIT_PTR -ne 1)          {$env:GPU_FORCE_64BIT_PTR = 1}
        if ($env:GPU_MAX_HEAP_SIZE -ne 100)          {$env:GPU_MAX_HEAP_SIZE = 100}
        if ($env:GPU_USE_SYNC_OBJECTS -ne 1)         {$env:GPU_USE_SYNC_OBJECTS = 1}
        if ($env:GPU_MAX_ALLOC_PERCENT -ne 100)      {$env:GPU_MAX_ALLOC_PERCENT = 100}
        if ($env:GPU_SINGLE_ALLOC_PERCENT -ne 100)   {$env:GPU_SINGLE_ALLOC_PERCENT = 100}
        if ($env:GPU_MAX_WORKGROUP_SIZE -ne 256)     {$env:GPU_MAX_WORKGROUP_SIZE = 256}
        if ($env:CUDA_DEVICE_ORDER -ne 'PCI_BUS_ID') {$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID'}
    } 
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "Cannot run RainbowMiner: $($_.Exception.Message)"
        $false
    }


    Write-Host "Checking for VM .. " -NoNewline
    try {
        if ($IsLinux) {
            if (((Test-IsElevated) -or (Test-OCDaemon)) -and (Get-Command "virt-what" -ErrorAction Ignore)) {
                    $Session.IsVM = (Invoke-Exe "virt-what" -Runas -ExcludeEmptyLines -ExpandLines | Measure-Object).Count -gt 0
            }
        } elseif ($IsWindows) {
            $VM_Match = "^Bochs|^KVM|^HVM|^QEMU|^UML|^Xen|ARAnyM|red hat|virtual|vmware|vmxnet"
            $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Ignore
            $Session.IsVM = (@($ComputerSystem.Manufacturer,$ComputerSystem.Model) | Where-Object {$_ -match $VM_Match} | Measure-Object).Count -gt 0
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "VM detection failed: $($_.Exception.Message)"
    }
    if ($Session.IsVM) {
        Write-Host "found (some miners will be excluded)" -ForegroundColor Red
    } else {
        Write-Host "ok (not in a VM)" -ForegroundColor Green
    }

    try {
        $Session.Curl = $null
        Write-Host "Checking for cURL .. " -NoNewline
        if ($IsWindows) {
            #if ($CurlCmd = Get-Command "curl.exe" -ErrorAction Ignore) {
            #    $CurlPath = $CurlCmd.Source
            #} else {
                $CurlPath = ".\Includes\curl\$(if ([Environment]::Is64BitOperatingSystem) {"x64"} else {"x32"})\curl.exe"
            #}
        } else {
            if ($CurlCmd = Get-Command "curl" -ErrorAction Ignore) {
                if ($CurlCmd.CommandType -eq "Application") {
                    $CurlPath = $CurlCmd.Source
                }
            }
        }

        if ($CurlPath -and (Test-Path $CurlPath)) {
            $TestOk = $false
            $CurlTest = Invoke-Exe $CurlPath -ArgumentList "-G `"https://rbminer.net/api/data/hello.txt`" --max-time 5 --connect-timeout 3 --ssl-allow-beast --ssl-no-revoke --max-redirs 5 -s -L -q" -WaitForExit 10
            if ("$($CurlTest)".Trim() -eq "world") {$TestOk = $true}
            else {
                $CurlTest = Invoke-Exe $CurlPath -ArgumentList "-G `"https://httpbin.org/status/200`" -H `"accept: text/plain`" --max-time 5 --connect-timeout 3 --ssl-allow-beast --ssl-no-revoke --max-redirs 5 -s -L -q -w `"%{response_code}`"" -WaitForExit 10
                if ($CurlTest -eq "200") {$TestOk = $true}
                else {
                    $CurlTest = Invoke-Exe $CurlPath -ArgumentList "--version" -WaitForExit 10
                    if ($CurlTest -match "curl\s+\d+") {$TestOk = $true}
                }
            }
            if ($TestOk) {$Session.Curl = $CurlPath}
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    if ($Session.Curl) {
        Write-Host "ok$(if (Test-Path ".\curl.txt") {" (permanently enabled by curl.txt file)";$Session.EnableCurl = $true})" -ForegroundColor Green
        Write-Log -Level Info "Curl $($IsCurl): $($Session.Curl)"
    } else {
        Write-Host "not found" -ForegroundColor Red
        $Session.EnableCurl = $false
    }

    $PauseByError = $false

    try {
        Write-Host "Detecting devices .. " -NoNewline
        $Global:DeviceCache.AllDevices = @(Get-Device "cpu","gpu" -IgnoreOpenCL -Refresh).Where({$_})
        $Session.PhysicalCPUs = $Global:GlobalCPUInfo.PhysicalCPUs
        $CPUFound   = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "CPU"} | Measure-Object).Count
        $NVFound    = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "NVIDIA"} | Measure-Object).Count
        $AMDFound   = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "AMD"} | Measure-Object).Count
        $INTELFound = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "INTEL"} | Measure-Object).Count
        if ($CPUFound -or $NVFound -or $AMDFound -or $INTELFound) {
            $DevicesFound = @()
            if ($CPUFound)   {$DevicesFound += "$($CPUFound) CPU"}
            if ($NVFound)    {$DevicesFound += "$($NVFound) Nvidia"}
            if ($AMDFound)   {$DevicesFound += "$($AMDFound) AMD"}
            if ($INTELFound) {$DevicesFound += "$($IntelFound) Intel"}
            Write-Host "$($DevicesFound -join ", ") found" -ForegroundColor Green
        } else {
            Write-Host "none found!" -ForegroundColor Red
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "Device detection failed: $($_.Exception.Message)"
        $PauseByError = $true
    }

    Write-Host "Starting sysinfo .. " -NoNewline
    try {
        $Global:GlobalSysInfoJob = Start-ThreadJob -InitializationScript ([scriptblock]::Create("Set-Location `"$((Get-Location).Path -replace '"','``"')`"")) -FilePath ".\Scripts\SysInfo.ps1" -Name "SysInfo" -ArgumentList $PID, $Session.PhysicalCPUs -ErrorAction Stop
        Write-Host "ok" -ForegroundColor Green
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Host "error" -ForegroundColor Red
    }

    if ($IsWindows -and ($GpuMemSizeMB = (($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -in @("AMD","INTEL","NVIDIA")}).OpenCL.GlobalMemSizeGB | Measure-Object -Sum).Sum*1100)) {
        try {
            Write-Host "Checking Windows pagefile/virtual memory .. " -NoNewline

            $PageFile_Warn = @()
            
            if ((Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile) {
                $PageFile_Warn += "Pagefile is set to manage automatically. This is NOT recommended!"
            } elseif ($PageFileInfo = Get-CimInstance Win32_PageFileSetting -ErrorAction Ignore) {
                $PageFileInfo | Foreach-Object {
                    $PageFileLetter = "$("$([IO.Path]::GetPathRoot($_.Name) -split ':' | Select-Object -First 1)".ToUpper()):"
                    if (-not $_.InitialSize -and -not $_.MaximumSize) {
                        $PageFile_Warn += "Pagefile on $($PageFileLetter) is set to system managed"
                    } else {
                        if ($_.InitialSize -ne $_.MaximumSize) {
                            $PageFile_Warn += "Pagefile on $($PageFileLetter) initial size is not equal maximum size."
                        }
                    }
                    Write-Log -Level Info "$($_.Name) is set to initial size $($_.InitialSize) MB and maximum size $($_.MaximumSize) MB"
                }
                $PageFileMaxSize = ($PageFileInfo | Measure-Object -Property MaximumSize -Sum).Sum
                if ($PageFileMaxSize -lt $GpuMemSizeMB) {
                    $PageFile_Warn += "Pagefiles are too small ($($PageFileMaxSize) MB). Set them to a total minimum of $($GpuMemSizeMB) MB"
                }
            } else {
                $PageFile_Warn += "No pagefile found"
            }
            if ($PageFile_Warn) {
                Write-Host "problem!" -ForegroundColor Red
                $PageFile_Warn | Where-Object {$_} | Foreach-Object {Write-Log -Level Warn "$_"}
                Write-Host " "
                Write-Host "To adjust your pagefile settings:" -BackgroundColor Yellow -ForegroundColor Black
                Write-Host "1. goto Computer Properties -> Advanced System Settings -> Performance -> Advanced -> Virtual Memory" -ForegroundColor Yellow
                Write-Host "2. uncheck `"Automatically manage paging file size for all drives`"" -ForegroundColor Yellow
                Write-Host "3. select `"Custom size`"" -ForegroundColor Yellow
                Write-Host "4. enter $($GpuMemSizeMB) into the fields `"Initial Size (MB)`" and `"Maximum Size (MB)`"" -ForegroundColor Yellow
                Write-Host "5. click onto `"Set`" and then `"OK`"" -ForegroundColor Yellow
                Write-Host " "
            } else {
                Write-Host "ok" -ForegroundColor Green
            }
        } catch {
            Write-Log -Level Warn "Failed to check Windows pagefile: $($_.Exception.Message)"
        }
    }

    if ($IsWindows -and ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "NVIDIA"} | Measure-Object).Count) {
        try {
            $InstallNVSMI_Job = Start-Job -InitializationScript ([ScriptBlock]::Create("Set-Location `"$($PWD.Path -replace '"','``"')`"")) -FilePath .\Scripts\InstallNVSMI.ps1
            if ($InstallNVSMI_Job) {
                $InstallNVSMI_Job | Wait-Job -Timeout 60 > $null
                if ($InstallNVSMI_Job.State -eq 'Running') {
                    Write-Log -Level Warn "Time-out while loading .\Scripts\InstallNVSMI.ps1"
                    try {$InstallNVSMI_Job | Stop-Job -PassThru | Receive-Job > $null} catch {if ($Error.Count){$Error.RemoveAt(0)}}
                } else {
                    try {
                        $InstallNVSMI_Result = Receive-Job -Job $InstallNVSMI_Job
                        if ($InstallNVSMI_Result) {
                            $InstallNVSMI_Result | Foreach-Object {
                                if ($_ -match "^WARNING:\s*(.+)$") {
                                    Write-Log -Level Warn $Matches[1]
                                } elseif ($_ -match "^SUCCESS:\s*(.+)$") {
                                    Write-Host $Matches[1] -ForegroundColor Green
                                    Write-Log -Level Info $Matches[1]
                                } else {
                                    Write-Host $_
                                    Write-Log -Level Info $_
                                }
                            }
                        }
                    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                }
                try {Remove-Job $InstallNVSMI_Job -Force} catch {if ($Error.Count){$Error.RemoveAt(0)}}
            }
        } catch {
            Write-Log -Level Warn "Failed to check NVSMI: $($_.Exception.Message)"
        }
    }

    try {
        Write-Host "Initialize configuration .."

        Set-PresetDefault

        if (-not (Test-Path $ConfigFile)) {
            $Parameters = @{VersionCompatibility=$Session.Version}
            $Session.DefaultValues.Keys | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction Ignore -Force}
            Set-ContentJson -PathToFile $ConfigFile -Data $Parameters > $null        
        } else {
            @($ConfigFile) + @(Get-ChildItem $ConfigPath -Directory | Where-Object {$ConfigFileSub = Join-Path $_.FullName "config.txt";$_.Name -ne "Backup" -and $ConfigFileSub -and (Test-Path $ConfigFileSub)} | Foreach-Object {$ConfigFileSub} | Select-Object) | Foreach-Object {
                $ConfigForUpdate = $null
                $ConfigFileForUpdate = $_
                try {
                    $ConfigForUpdate = Get-ContentByStreamReader $ConfigFileForUpdate | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "The file $ConfigFileForUpdate contains JSON syntax errors: $($_.Exception.Message)"
                    $ConfigForUpdate = $null
                }
                if ($ConfigForUpdate) {
                    $ConfigForUpdate_changed = $false
                    if ($ConfigForUpdate.PSObject.Properties.Name -icontains "LocalAPIport") {$ConfigForUpdate | Add-Member APIport $ConfigForUpdate.LocalAPIport -Force}
                    $MPHLegacyUpdate = if ($ConfigForUpdate.PSObject.Properties.Name -icontains "API_ID") {@{UserName=$ConfigForUpdate.UserName;API_ID=$ConfigForUpdate.API_ID;API_Key=$ConfigForUpdate.API_Key}}
                    Compare-Object @($ConfigForUpdate.PSObject.Properties.Name) @($Session.DefaultValues.Keys) | Foreach-Object {
                        if ($_.SideIndicator -eq "=>") {$ConfigForUpdate | Add-Member $_.InputObject "`$$($_.InputObject)";$ConfigForUpdate_changed=$true}
                        elseif ($_.SideIndicator -eq "<=" -and @("API_ID","API_Key","UserName","LocalAPIport","RemoteAPI","ConfigFile","ExcludeNegativeProfit","DisableAutoUpdate","Regin","Debug","Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable") -icontains $_.InputObject) {$ConfigForUpdate.PSObject.Properties.Remove($_.InputObject);$ConfigForUpdate_changed=$true}
                    }
                    if ($ConfigForUpdate_changed) {Set-ContentJson -PathToFile $_ -Data $ConfigForUpdate > $null}
                } else {
                    if (-not $ConfigForUpdate -and $_ -eq $ConfigFile) {throw "ALAS! The main config file contains JSON errors. Can't continue!"}
                }
            }
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

            $Session.ConfigFiles.Keys | Sort-Object -Descending {if ($_ -eq "Config") {2} elseif ($_ -eq "Userpools") {1} else {0}}  | Foreach-Object {
                $FNtmp   = "$(if ($_ -ne "Config") {"$($_.ToLower())."})$ConfigFile_Name"
                $Session.ConfigFiles[$_].Path = Join-Path $ConfigFile_Path $FNtmp
                if (-not $psISE -and (Test-Path $Session.ConfigFiles[$_].Path)) {Copy-Item $Session.ConfigFiles[$_].Path -Destination (Join-Path (Join-Path $ConfigFile_Path "Backup") "$($BackupDate)_$($FNtmp)")}
                Set-ConfigDefault $_ -Force > $null
                if (Test-Path $Session.ConfigFiles[$_].Path) {$Session.ConfigFiles[$_].Path = $Session.ConfigFiles[$_].Path | Resolve-Path -Relative}
            }
        }

        #create special config files
        if (-not (Test-Path ".\Config\minerconfigfiles.txt") -and (Test-Path ".\Data\minerconfigfiles.default.txt")) {Copy-Item ".\Data\minerconfigfiles.default.txt" ".\Config\minerconfigfiles.txt" -Force -ErrorAction Ignore}

        try {
            #cleanup legacy data
            if ((Test-Path ".\Scripts\Cleanup.ps1") -and (Test-Path ".\Data\version.json")) {
                $LastVersion = (Get-ContentByStreamReader ".\Data\version.json" | ConvertFrom-Json -ErrorAction Ignore).Version
                if ($RunCleanup -and $LastVersion -and (Compare-Version $LastVersion $Session.Version) -lt 0) {
                    Write-Host "Cleanup legacy data .."
                    $Cleanup_Parameters = [PSCustomObject]@{
                        AllDevices          = $Global:DeviceCache.AllDevices
                        MyCommandParameters = $Session.DefaultValues.Keys
                        Version             = $LastVersion
                        ConfigFiles         = $Session.ConfigFiles
                    }
                    $Cleanup_Job = Start-Job -InitializationScript ([ScriptBlock]::Create("Set-Location `"$($PWD.Path -replace '"','``"')`"")) -FilePath .\Scripts\Cleanup.ps1 -ArgumentList $Cleanup_Parameters.AllDevices,$Cleanup_Parameters.Version,$Cleanup_Parameters.MyCommandParameters,$Cleanup_Parameters.ConfigFiles
                    if ($Cleanup_Job) {
                        $Cleanup_Job | Wait-Job -Timeout 60 > $null
                        if ($Cleanup_Job.State -eq 'Running') {
                            Write-Log -Level Warn "Time-out while loading .\Scripts\Cleanup.ps1"
                            try {$Cleanup_Job | Stop-Job -PassThru | Receive-Job > $null} catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        } else {
                            try {
                                $Cleanup_Result = Receive-Job -Job $Cleanup_Job
                                if ($Cleanup_Result) {
                                    $Cleanup_Result | Foreach-Object {
                                        if ($_ -match "^WARNING:\s*(.+)$") {
                                            Write-Log -Level Warn $Matches[1]
                                        } elseif ($_ -match "^SUCCESS:\s*(.+)$") {
                                            Write-Host $Matches[1] -ForegroundColor Green
                                            Write-Log -Level Info $Matches[1]
                                        } else {
                                            Write-Host $_
                                            Write-Log -Level Info $_
                                        }
                                    }
                                }
                            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        }
                        try {Remove-Job $Cleanup_Job -Force} catch {if ($Error.Count){$Error.RemoveAt(0)}}
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
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "Please check your configuration: $($_.Exception.Message)"
        $PauseByError = $true
    }

    try {
        #Read miner info
        if (Test-Path ".\Data\minerinfo.json") {try {(Get-ContentByStreamReader ".\Data\minerinfo.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Foreach-Object {$Global:MinerInfo[$_.Name] = $_.Value}} catch {if ($Error.Count){$Error.RemoveAt(0)}}}

        #write version to data
        Set-ContentJson -PathToFile ".\Data\version.json" -Data ([PSCustomObject]@{Version=$Session.Version}) > $null
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Error "Error writing version: $($_.Exception.Message)"
    }

    $Global:PauseMiners.Set([PauseStatus]::ByError,$PauseByError)

    #Remove trigger files
    if (Test-Path ".\stopp.txt")  {Remove-Item ".\stopp.txt" -Force -ErrorAction Ignore}
    if (Test-Path ".\reboot.txt") {Remove-Item ".\reboot.txt" -Force -ErrorAction Ignore}

    #Initialize timers and trackers
    $Session.Timer      = (Get-Date).ToUniversalTime()
    $Session.NextReport = (Get-Date).ToUniversalTime()
    $Session.DecayStart = (Get-Date).ToUniversalTime()
    [hashtable]$Session.Updatetracker = @{
        Balances = 0
        TimeDiff = 0
        MinerSave = if (Test-Path ".\Data\minerdata.json") {Get-ChildItem ".\Data\minerdata.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
        PoolsSave = if (Test-Path ".\Data\poolsdata.json") {Get-ChildItem ".\Data\poolsdata.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
        ReportDeviceData = 0
    }

    #Load databases, that only need updates once in a while
    Get-WorldCurrencies -Silent -EnableRemoteUpdate

    $true
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

    $RestartRunspaces = $false
    
    [string[]]$Session.AvailPools  = @(Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Where-Object {$_ -notin @("Userpools","WhatToMine")} | Sort-Object)
    [string[]]$Session.AvailMiners = @(Get-ChildItem ".\Miners\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object)

    #Fork detection
    if ((Test-Path ".\Data\coinsdb-fork.json“) -or (Test-Path ".\Data\algorithms-fork.json“)) {
        $Fork_Meets_Target = $false
        try {
            if ($true) {
                #DateTime target

                #$Fork_Meets_Target = (Get-Date) -ge [datetime]"October 31, 2020 5:00 PM GMT"
                #$Fork_Meets_Target = (Get-Date) -ge [datetime]::Parse("October 26, 2021 06:00:00 AM GMT")
            } else {
                #Blockchain target

                #$Request = Invoke-RestMethodAsync "https://blockscout.com/etc/mainnet/api?module=block&action=eth_block_number" -Timeout 15 -tag "fork"
                #if ([int64]$Request.result -ge 11700000) {
                #    $Fork_Meets_Target = $true
                #}

                #$Request = Invoke-RestMethodAsync "https://mainnet-explorer.beam.mw/explorer/status/?format=json" -Timeout 15 -tag "fork"
                #if ([int64]$Request.height -ge 777777) {
                #    $Fork_Meets_Target = $true
                #}

                #$Request = Invoke-RestMethodAsync "https://api.grinmint.com/v2/networkStats" -Timeout 15 -tag "fork"
                #if ([int64]$Request.height -ge 786240) {
                #    $Fork_Meets_Target = $true
                #}

                #$Request = Invoke-RestMethodAsync "https://mining.bittube.app:8120/stats" -tag "fork" -timeout 15 -cycletime 120
                #if ([int64]$Request.network.height -ge 654000) {
                #    $Fork_Meets_Target = $true
                #}

                #$Request = Invoke-RestMethodAsync "https://blockapi.turtlepay.io/block/header/top" -tag "fork" -timeout 15 -cycletime 120
                #if ([int64]$Request.height -ge 3000000) {
                #    $Fork_Meets_Target = $true
                #}

            }
        }
        catch {}

        if ($Fork_Meets_Target) {
            try {
                if (Test-Path ".\Data\coinsdb-fork.json“) {
                    Remove-Item “.\Data\coinsdb.json" -Force
                    Rename-Item ".\Data\coinsdb-fork.json" "coinsdb.json"
                    Get-CoinsDB -Silent -Force
                }
                if (Test-Path ".\Data\algorithms-fork.json“) {
                    Remove-Item “.\Data\algorithms.json" -Force
                    Rename-Item ".\Data\algorithms-fork.json" "algorithms.json"
                    Get-Algorithms -Silent -Force
                }
                Stop-AsyncJob "fork"
            }
            catch {}
        }
    }

    #Update databases every 40 rounds
    if (-not ($Session.RoundCounter % 40)) {
        Get-AlgorithmMap -Silent
        Get-Algorithms -Silent
        Get-CoinsDB -Silent
        Get-EquihashCoins -Silent
        Get-EthDAGSizes -Silent -EnableRemoteUpdate:($Session.RoundCounter -gt 0)
        Get-NimqHashrates -Silent
        Get-Regions -Silent
        Get-Regions2 -Silent
    }

    if (Test-Path $Session.ConfigFiles["Config"].Path) {

        if (-not $Session.IsDonationRun) {Get-SessionServerConfig}

        if (-not $Session.IsDonationRun -and (-not $Session.Config -or $Session.RunSetup -or (Test-Config "Config" -LastWriteTime))) {

            do {
                if ($Session.Config -eq $null) {Write-Host "Read configuration .."}
                $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1"
                $Session.ConfigFiles["Config"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Config"].Path).LastWriteTimeUtc
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
                $Session.Config | Add-Member Userpools @() -Force

                Remove-Variable "ConfigSetup"
                Remove-Variable "Parameters"

                if (-not $Session.Config.WorkerName -or -not $Session.Config.PoolName) {
                    $Session.RunSetup = $true
                } else {
                    if (Set-Proxy -Proxy "$($Session.Config.Proxy -replace "^`$Proxy$")" -Username "$($Session.Config.ProxyUsername -replace "^`$ProxyUsername$")" -Password "$($Session.Config.ProxyPassword -replace "^`$ProxyPassword$")") {
                        if ($Session.RoundCounter -gt 0 -and (Test-Path Variable:Global:AsyncLoader)) {
                            if ((Test-Path Variable:Global:AsyncLoader) -and -not $AsyncLoader.Pause) {$AsyncLoader.Pause = $true}
                            $RestartRunspaces = $true
                        }
                        Write-Log -Level Info "Proxy settings have changed: Restarting HttpClient$(if ($RestartRunspaces) {" and Runspaces"})"
                        Initialize-HttpClient -Restart > $null
                    }
                }

                $ReReadConfig = $false
                if ($Session.RunSetup) {
                    Import-Module .\Modules\Setup.psm1
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
        if (-not $Session.Config.Region) {$Session.Config | Add-Member Region "US" -Force}
        $Session.Config.Region = Get-Region $Session.Config.Region
        $Session.Config.DefaultPoolRegion = @($Session.Config.DefaultPoolRegion | ForEach-Object {Get-Region $_} | Where-Object {$_} | Select-Object -Unique)
        if ($WiderRegion = Get-Region2 $Session.Config.Region) {
            $Session.Config.DefaultPoolRegion = @($WiderRegion | Select-Object) + @($Session.Config.DefaultPoolRegion | Where-Object {$_ -notin $WiderRegion} | Select-Object)
        }
        #make sure the following regions are always part of DefaultPoolRegion to avoid erratic sorting of pools
        @("US","CentralEurope","Asia","Russia") | Foreach-Object {
            $MissingRegion = Get-Region $_
            if ($Session.Config.DefaultPoolRegion -inotcontains $MissingRegion) {
                $Session.Config.DefaultPoolRegion += $MissingRegion
            }
        }
        $Session.Config.Currency = @($Session.Config.Currency | ForEach-Object {$_.ToUpper()} | Where-Object {$_})
        if ($Session.Config.Currency -notcontains "BTC") {$Session.Config.Currency += "BTC"}
        $Session.Config.UIstyle = if ($Session.Config.UIstyle -like "f*") {"full"} else {"lite"}
        $Session.Config.UIsorting = if ($Session.Config.UIsorting -like "p*") {"profit"} else {"biased"}
        $Session.Config.PowerPriceCurrency = $Session.Config.PowerPriceCurrency | ForEach-Object {$_.ToUpper()}
        $Session.Config.OpenCLPlatformSorting = @($Session.Config.OpenCLPlatformSorting | ForEach-Object {$_.ToUpper()} | Where-Object {$_ -in @("AMD","INTEL","NVIDIA")})
        $Session.Config.MiningHeatControl = [Math]::Round([Math]::Max([Math]::Min([double]($Session.Config.MiningHeatControl -replace ",","." -replace "[^\d\.]+"),5.0),0.0),1)
        $Session.Config.PoolSwitchingHysteresis = [Math]::Max([Math]::Min([double]($Session.Config.PoolSwitchingHysteresis -replace ",","." -replace "[^\d\.\-]+"),100.0),0.0)
        $Session.Config.MinerSwitchingHysteresis = [Math]::Max([Math]::Min([double]($Session.Config.MinerSwitchingHysteresis -replace ",","." -replace "[^\d\.\-]+"),100.0),0.0)
        $Session.Config.MaxErrorRatio = [Math]::Max([double]($Session.Config.MaxErrorRatio -replace ",","." -replace "[^\d\.\-]+"),1.0)
        $Session.Config.PreferMinerMargin = [Math]::Max([Math]::Min([double]($Session.Config.PreferMinerMargin -replace ",","." -replace "[^\d\.\-]+"),100.0),0.0)
        $Session.Config.PoolStatAverage =  Get-StatAverage $Session.Config.PoolStatAverage
        $Session.Config.PoolStatAverageStable =  Get-StatAverage $Session.Config.PoolStatAverageStable -Default "Week"
        $Session.Config.MaxTimeSinceLastBlock = ConvertFrom-Time $Session.Config.MaxTimeSinceLastBlock
        $Session.Config.FastlaneBenchmarkTypeCPU = if ($Session.Config.FastlaneBenchmarkTypeCPU -in @("avg","min","max")) {$Session.Config.FastlaneBenchmarkTypeCPU} else {"avg"}
        $Session.Config.FastlaneBenchmarkTypeCPU = if ($Session.Config.FastlaneBenchmarkTypeCPU -in @("avg","min","max")) {$Session.Config.FastlaneBenchmarkTypeCPU} else {"avg"}
        if ($Session.Config.BenchmarkInterval -lt 60) {$Session.Config.BenchmarkInterval = 60}
        if ($Session.Config.OCResetInterval -gt 0 -and $Session.Config.OCResetInterval -lt 600) {$Session.Config.OCResetInterval = 600}
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

        if ($Session.CurrentPowerPrice -eq $null) {$Session.CurrentPowerPrice = $Session.Config.PowerPrice}

        $Session.LogLevel = $Session.Config.LogLevel

        $EnableCurl = $Session.EnableCurl
        $Session.EnableCurl = $Session.Curl -and ($Session.Config.EnableCurl -or (Test-Path ".\curl.txt"))
        if ($EnableCurl -ne $Session.EnableCurl) {
            Write-Log -Level Info "cURL $(if ($Session.EnableCurl) {"enabled"} else {"disabled"})"
        }

        #crosscheck for invalid cpu mining parameters to avoid system overload
        if ($Session.Config.DeviceName -match "^CPU") {
            $CPUAffinityInt = (ConvertFrom-CPUAffinity "$($Session.Config.CPUMiningAffinity)" -ToInt) -band (Get-CPUAffinity $Global:GlobalCPUInfo.Threads -ToInt)
            if ($CPUAffinityInt -eq 0) {
                $CPUAffinityInt = Get-CPUAffinity $Global:GlobalCPUInfo.RealCores.Count -ToInt
                Write-Log -Level "$(if ($Session.RoundCounter -eq 0) {"Warn"} else {"Info"})" "Parameter CPUMiningAffinity (config.txt) is empty or contains errors. Falling back to $(Get-CPUAffinity $Global:GlobalCPUInfo.RealCores.Count -ToHex)"
            }
            if ($Session.Config.EnableAutoAdjustAffinity -and $Global:GlobalCPUInfo.Threads -gt 1 -and $CPUAffinityInt -eq (Get-CPUAffinity $Global:GlobalCPUInfo.Threads -ToInt)) {
                $CPUThreads = ($Global:GlobalCPUInfo.Threads - [Math]::Min(2,[int]($Global:GlobalCPUInfo.Threads/2)))
                $CPUAffinityInt = Get-CPUAffinity $CPUThreads -ToInt
                Write-Log -Level "$(if ($Session.RoundCounter -eq 0) {"Warn"} else {"Info"})" "All threads selected for CPU mining! This will overload your system, auto-adjusting affinity to $(Get-CPUAffinity $CPUThreads -ToHex))"
            }
            $Session.Config.CPUMiningAffinity = "0x$(([bigint]$CPUAffinityInt).ToString("x") -replace "^0")"
            $Session.Config.CPUMiningThreads  = [Math]::Max(@(ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity).Count,1)
        }
    }


    #Check if internet is online
    $Internet_ok = Test-Internet -CheckDomains $Session.Config.WebsitesForOnlineCheck

    if (-not $RestartRunspaces) {
        if (-not $Internet_ok) {
            Write-Log -Level Info "Internet is down"

            $i = 0

            if ((Test-Path Variable:Global:AsyncLoader) -and -not $AsyncLoader.Pause) {$AsyncLoader.Pause = $true}

            do {
                if (-not ($i % 60)) {Write-Log -Level Warn "Waiting 30s for internet connection. Press [X] to exit RainbowMiner"}
                Start-Sleep -Milliseconds 500
                if ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}
                $i++
                if (-not ($i % 20)) {$Internet_ok = Test-Internet -CheckDomains $Session.Config.WebsitesForOnlineCheck}
            } until ($Internet_ok -or $keyPressedValue -eq "X")

            if ($keyPressedValue -eq "X") {
                Write-Log "User requests to stop script. "
                Write-Host "[X] pressed - stopping script."
                break
            }
            if ($i -gt $Session.Config.BenchmarkInterval*2) {
                Update-WatchdogLevels -Reset
                $Global:WatchdogTimers = @()
            }
        }

        if ($Internet_ok) {
            Write-Log -Level Info "Internet is ok"
            if ((Test-Path Variable:Global:AsyncLoader) -and $AsyncLoader.Pause) {$AsyncLoader.Pause = $false}
        }
    }

    #Check for system time vs. NTP services
    if (-not $Session.Updatetracker.TimeDiff -or $Session.Updatetracker.TimeDiff -lt (Get-Date).AddMinutes(-60)) {
        $Session.Updatetracker.TimeDiff = Get-Date
        $TimeDiff = ((Get-Date)-(Get-NtpTime)).TotalSeconds
        $Session.TimeDiff = [Math]::Sign($TimeDiff)*[Math]::Floor([Math]::Abs($TimeDiff))
    }

    #Start/stop services
    if ($Session.RoundCounter -eq 0) {
        Start-Autoexec -Priority $Session.Config.AutoexecPriority
    }
    if (($RestartRunspaces -or $Session.Config.DisableAsyncLoader -or $Session.Config.Interval -ne $ConfigBackup.Interval) -and (Test-Path Variable:Global:Asyncloader)) {Stop-AsyncLoader}
    if (-not $Session.Config.DisableAsyncLoader -and -not (Test-Path Variable:Global:AsyncLoader)) {Start-AsyncLoader -Interval $Session.Config.Interval -Quickstart $Session.Config.Quickstart}
    if (-not $Session.Config.DisableMSIAmonitor -and (Test-Afterburner) -eq -1 -and ($Session.RoundCounter -eq 0 -or $Session.Config.DisableMSIAmonitor -ne $ConfigBackup.DisableMSIAmonitor)) {Start-Afterburner}
    if (-not $psISE -and ($RestartRunspaces -or $Session.Config.DisableAPI -or $Session.Config.APIport -ne $ConfigBackup.APIport -or $Session.Config.APIauth -ne $ConfigBackup.APIauth -or $Session.Config.APIuser -ne $ConfigBackup.APIuser -or $Session.Config.APIpassword -ne $ConfigBackup.APIpassword -or $Session.Config.APIthreads -ne $ConfigBackup.APIthreads) -and (Test-Path Variable:Global:API) -and -not $API.IsVirtual) {Stop-APIServer}
    if (-not $psISE -and -not $Session.Config.DisableAPI -and -not (Test-Path Variable:Global:API)) {Start-APIServer}
    if($psISE -or -not (Test-Path Variable:Global:API)) {
        $Global:API = [hashtable]@{}
        $API.Stop = $false
        $API.Pause = $false
        $API.Update = $false
        $API.Reboot = $false
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
        $API.LockConfig = $Session.Config.APIlockConfig
        $API.MaxLoginAttemps = $Session.Config.APImaxLoginAttemps
        $API.BlockLoginAttemptsTime = ConvertFrom-Time $Session.Config.APIblockLoginAttemptsTime
        $API.MachineName = $Session.MachineName
    }

    $API.PauseMiners.Pause       = $Global:PauseMiners.Test()
    $API.PauseMiners.PauseIA     = $Global:PauseMiners.TestIA()
    $API.PauseMiners.PauseIAOnly = $Global:PauseMiners.TestIAOnly()

    $API.CmdKey = ''

    if (Test-Path ".\Data\sysinfo.json") {
        $Session.SysInfo = Get-ContentByStreamReader ".\Data\sysinfo.json" -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
    }

    if ($CheckConfig) {Update-WatchdogLevels -Reset}

    #Cleanup
    if (-not (Test-Path Variable:Global:GlobalLastCleanup) -or (Get-Date).AddHours(-12).ToUniversalTime() -lt $Global:GlobalLastCleanup) {
        if (Test-Path ".\Logs"){Get-ChildItem -Path ".\Logs" -Filter "*" -File | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$Session.Config.MaxLogfileDays)} | Remove-Item -ErrorAction Ignore} else {New-Item ".\Logs" -ItemType "directory" -Force > $null}
        if (Test-Path ".\Cache"){Get-ChildItem -Path ".\Cache" -Filter "*" -File | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$Session.Config.MaxCachefileDays)} | Remove-Item -ErrorAction Ignore} else {New-Item ".\Cache" -ItemType "directory" -Force > $null}
        if (Test-Path ".\Downloads"){Get-ChildItem -Path ".\Downloads" -Filter "*" -File | Where-Object {$_.Name -ne "config.json" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$Session.Config.MaxDownloadfileDays)} | Remove-Item -ErrorAction Ignore} else {New-Item ".\Downloads" -ItemType "directory" -Force > $null}
        $Global:GlobalLastCleanup = (Get-Date).ToUniversalTime()
    }

    if ($CheckConfig) {
        if (-not (Test-Path ".\Downloads")){New-Item ".\Downloads" -ItemType "directory" -Force > $null}
        Set-ContentJson -PathToFile ".\Downloads\config.json" -Data ([PSCustomObject]@{
            EnableMinerBackups  = $Session.Config.EnableMinerBackups
            EnableKeepDownloads = $Session.Config.EnableKeepDownloads
        }) > $null
    }

    $ConfirmedVersion = Confirm-Version $Session.Version
    $API.Version = $ConfirmedVersion

    $MSIAenabled = $IsWindows -and -not $Session.Config.EnableOCProfiles -and $Session.Config.MSIAprofile -gt 0 -and (Test-Path $Session.Config.MSIApath)
    $Session.OCmode = if ($MSIAenabled) {"msia"} elseif ($Session.Config.EnableOCProfiles) {"ocp"} else {"off"}

    if ($CheckConfig) {
        $API.Info = ConvertTo-Json ([PSCustomObject]@{
                                Version                = $ConfirmedVersion.Version
                                RemoteVersion          = $ConfirmedVersion.RemoteVersion
                                ManualURI              = $ConfirmedVersion.ManualURI
                                WorkerName             = $Session.Config.WorkerName
                                EnableAlgorithmMapping = $Session.Config.EnableAlgorithmMapping
                                AlgorithmMap           = (Get-AlgorithmMap)
                                OCmode                 = $Session.OCmode
                                UsePowerPrice          = $Session.Config.UsePowerPrice
                                PowerPriceCurrency     = $Session.Config.PowerPriceCurrency
                                FixedCostPerDay        = $Session.Config.FixedCostPerDay
                                DecSep                 = (Get-Culture).NumberFormat.NumberDecimalSeparator
                                IsWindows              = $Global:IsWindows
                                IsLinux                = $Global:IsLinux
                                IsLocked               = $Session.Config.APIlockConfig
                            }) -Depth 10
    }

    if ($Session.RoundCounter -eq 0 -and ($Session.Config.StartPaused -or $Global:PauseMiners.Test())) {$Global:PauseMiners.SetIA()}

    #Update defaults for all subfolders, if in Server-mode
    if (-not $Session.IsDonationRun -and $Session.Config.RunMode -eq "Server") {
        $ConfigFile = Get-ConfigPath "Config"
        $ConfigFile_Name = Split-Path $ConfigFile -Leaf
        $ConfigFile_Path = Split-Path $ConfigFile
        Get-ChildItem $ConfigFile_Path -Directory | Where-Object {$_.Name -ne "Backup"} | Foreach-Object {
            $Folder_Name = $_.Name
            $Folder_Path = Join-Path $ConfigFile_Path $Folder_Name
            @($Session.ConfigFiles.Keys | Select-Object) | Foreach-Object {
                $FolderConfigFile = Join-Path $Folder_Path "$($_.ToLower()).$($ConfigFile_Name)"
                if (Test-Path $FolderConfigFile) {
                    if (-not (Test-Config "$Folder_Name/$_") -or $Session.ConfigFiles["$Folder_Name/$_"].Path -ne $FolderConfigFile) {
                        $Session.ConfigFiles["$Folder_Name/$_"] = @{Path=$FolderConfigFile;LastWriteTime=0;Healthy=$false}
                    }
                    $FolderConfigFileNeedsUpdate = ($Session.RoundCounter -eq 0) -or (Test-Config "$Folder_Name/$_" -LastWriteTime)
                    if (Set-ConfigDefault -ConfigName $_ -Folder $Folder_Name -Force:$FolderConfigFileNeedsUpdate) {
                        Set-ConfigLastWriteTime "$Folder_Name/$_"
                    }
                } elseif (Test-Config "$Folder_Name/$_") {
                    $Session.ConfigFiles.Remove("$Folder_Name/$_")
                }
            }
        }
    }

    #Check for algorithms config
    if (Set-ConfigDefault "Algorithms") {
        if ($CheckConfig -or -not $Session.Config.Algorithms -or (Test-Config "Algorithms" -LastWriteTime) -or ($ConfigBackup.Algorithms -and (Compare-Object $Session.Config.Algorithms $ConfigBackup.Algorithms | Measure-Object).Count)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating algorithms config data"}
            $AllAlgorithms = Get-ConfigContent "Algorithms" -UpdateLastWriteTime
            if (Test-Config "Algorithms" -Health) {
                $Session.Config | Add-Member Algorithms ([PSCustomObject]@{}) -Force
                $AllAlgorithms.PSObject.Properties.Name | Where-Object {-not $Session.Config.Algorithm.Count -or $Session.Config.Algorithm -icontains $_} | Foreach-Object {
                    $a = $_
                    $Session.Config.Algorithms | Add-Member $a $AllAlgorithms.$a -Force
                    $Algo_MRRPriceModifierPercent = "$($Session.Config.Algorithms.$a.MRRPriceModifierPercent -replace "[^\d\.\-]+")"
                    $Algo_MaxTimeToFInd           = (ConvertFrom-Time $Session.Config.Algorithms.$a.MaxTimeToFind)
                    ([ordered]@{
                        Penalty                 = ([Math]::Round([double]($Session.Config.Algorithms.$a.Penalty -replace "[^\d\.\-]+"),2))
                        MinHashrate             = (ConvertFrom-Hash $Session.Config.Algorithms.$a.MinHashrate)
                        MinWorkers              = (ConvertFrom-Hash $Session.Config.Algorithms.$a.MinWorkers)
                        MaxTimeToFind           = $Algo_MaxTimeToFind
                        MSIAprofile             = ([int]$Session.Config.Algorithms.$a.MSIAprofile)
                        MinBLKRate              = $(if ($Algo_MaxTimeToFind) {86400/$Algo_MaxTimeToFind} else {0})
                        MRREnable               = $(if ($Session.Config.Algorithms.$a.MRREnable -ne $null) {Get-Yes $Session.Config.Algorithms.$a.MRREnable} else {$true})
                        MRRAllowExtensions      = $(if ($Session.Config.Algorithms.$a.MRRAllowExtensions -ne "" -and $Session.Config.Algorithms.$a.MRRAllowExtensions -ne $null) {Get-Yes $Session.Config.Algorithms.$a.MRRAllowExtensions} else {$null})
                        MRRPriceModifierPercent = $(if ($Algo_MRRPriceModifierPercent -ne "") {[Math]::Max(-30,[Math]::Min(30,[Math]::Round([double]$Algo_MRRPriceModifierPercent,2)))} else {$null})
                        MinerName               = @(if ($Session.Config.Algorithms.$a.MinerName){[regex]::split("$($Session.Config.Algorithms.$a.MinerName)".Trim(),"\s*[,;]+\s*") | Where-Object {$_}})
                        ExcludeMinerName        = @(if ($Session.Config.Algorithms.$a.ExcludeMinerName){[regex]::split("$($Session.Config.Algorithms.$a.ExcludeMinerName)".Trim(),"\s*[,;]+\s*") | Where-Object {$_}})
                    }).GetEnumerator() | Foreach-Object {
                        if ([bool]$Session.Config.Algorithms.$a.PSObject.Properties["$($_.Name)"]) {
                            $Session.Config.Algorithms.$a."$($_.Name)" = $_.Value
                        } else {
                            $Session.Config.Algorithms.$a | Add-Member "$($_.Name)" $_.Value -Force
                        }
                        if ($Session.Config.Algorithms.$a.MinerName.Count -or $Session.Config.Algorithms.$a.ExcludeMinerName.Count) {
                            $Global:AlgorithmMinerName += $a
                        }
                    }
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
                    $c = $_
                    $Session.Config.Coins | Add-Member $c $AllCoins.$c -Force
                    $Coin_MaxTimeToFind = (ConvertFrom-Time $Session.Config.Coins.$c.MaxTimeToFind)
                    ([ordered]@{
                        Penalty          = ([Math]::Round([double]($Session.Config.Coins.$c.Penalty -replace "[^\d\.\-]+"),2))
                        MinHashrate      = (ConvertFrom-Hash $Session.Config.Coins.$c.MinHashrate)
                        MinWorkers       = (ConvertFrom-Hash $Session.Config.Coins.$c.MinWorkers)
                        MaxTimeToFind    = $Coin_MaxTimeToFind
                        Wallet           = ($Session.Config.Coins.$c.Wallet -replace "\s+")
                        EnableAutoPool   = (Get-Yes $Session.Config.Coins.$c.EnableAutoPool)
                        PostBlockMining  = (ConvertFrom-Time $Session.Config.Coins.$c.PostBlockMining)
                        MinProfitPercent = ([double]($Session.Config.Coins.$c.MinProfitPercent -replace "[^\d\.]+"))
                        MinBLKRate       = $(if ($Coin_MaxTimeToFind) {86400/$Coin_MaxTimeToFind} else {0})
                    }).GetEnumerator() | Foreach-Object {
                        if ([bool]$Session.Config.Coins.$c.PSObject.Properties["$($_.Name)"]) {
                            $Session.Config.Coins.$c."$($_.Name)" = $_.Value
                        } else {
                            $Session.Config.Coins.$c | Add-Member "$($_.Name)" $_.Value -Force
                        }
                    }
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

    #Check for scheduler config
    if (Set-ConfigDefault "Scheduler") {
        if ($CheckConfig -or $Session.Config.Scheduler -eq $null -or (Test-Config "Scheduler" -LastWriteTime)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating scheduler config data"}
            $AllScheduler = Get-ConfigContent "Scheduler" -UpdateLastWriteTime
            if (Test-Config "Scheduler" -Health) {
                if ($AllScheduler -isnot [array] -and $AllScheduler.value -ne $null) {$AllScheduler = $AllScheduler.value}
                $Session.Config | Add-Member Scheduler ([System.Collections.Generic.List[PSCustomObject]]@()) -Force
                $AllScheduler | Foreach-Object {
                    $_ | Add-Member Name "$($_.Name)" -Force
                    $_ | Add-Member DayOfWeek $([string]("$($_.DayOfWeek -replace "[^0-6\*]+")"[0])) -Force
                    $_ | Add-Member From $(Get-HourMinStr $_.From) -Force
                    $_ | Add-Member To   $(Get-HourMinStr $_.To -to) -Force
                    $_ | Add-Member PowerPrice $($_.PowerPrice -replace ",","." -replace "[^0-9\.]+") -Force
                    $_ | Add-Member Enable $(Get-Yes $_.Enable) -Force
                    $_ | Add-Member Pause  $(Get-Yes $_.Pause)  -Force
                    $_ | Add-Member EnableUpdate  $(Get-Yes $_.EnableUpdate)  -Force
                    $_ | Add-Member EnableMiningHeatControl $(if ($_.EnableMiningHeatControl -eq "") {$Session.Config.EnableMiningHeatControl} else {Get-Yes $_.EnableMiningHeatControl}) -Force
                    $_ | Add-Member MiningHeatControl "$($_.MiningHeatControl -replace ",","." -replace "[^0-9\.]+")" -Force

                    foreach($q in @("Algorithm","ExcludeAlgorithm","CoinSymbol","ExcludeCoinSymbol","PoolName","ExcludePoolName")) {
                        if ($_.$q -is [string]) {$_.$q = @($_.$q -replace "[^A-Z0-9,;]+" -split "[,;]+" | Where-Object {$_} | Select-Object)}
                        $_ | Add-Member $q @(($_.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
                    }

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
                        if ($Session.Config.Devices.$p.$q -is [string]){$Session.Config.Devices.$p.$q = @(if ($Session.Config.Devices.$p.$q.Trim() -ne ""){[regex]::split($Session.Config.Devices.$p.$q.Trim(),"\s*[,;]+\s*")})}
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
                    if ($p -eq "CPU" -and -not $Session.Config.Devices.$p.Worker) {
                        $Session.Config.Devices.$p | Add-Member Worker "$($Session.Config.WorkerName)cpu" -Force
                    }
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

    #Check for userpools config
    if (Set-ConfigDefault "Userpools") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.Userpools -or (Test-Config "Userpools" -LastWriteTime))) {
            $UserpoolsConfig = Get-ConfigContent "Userpools" -UpdateLastWriteTime -ConserveUnkownParameters
            if (Test-Config "Userpools" -Health) {
                $Session.Config | Add-Member Userpools @($UserpoolsConfig | Where-Object {"$($_.Name)" -ne ""} | Foreach-Object {
                    $UPool = $_

                    ([ordered]@{
                        Enable        = Get-Yes $UPool.Enable
                        SSL           = Get-Yes $UPool.SSL
                        PoolFee       = [double]"$($Upool.PoolFee -replace ",","." -replace "[^\d\.]")"
                        Currency      = "$(if ($UPool.Currency) {$UPool.Currency} else {$UPool.CoinSymbol})".ToUpper()
                        CoinSymbol    = "$(if ($UPool.CoinSymbol) {$UPool.CoinSymbol} else {$UPool.Currency})".ToUpper()
                    }).GetEnumerator() | Foreach-Object {
                        if ([bool]$UPool.PSObject.Properties["$($_.Name)"]) {
                            $UPool."$($_.Name)" = $_.Value
                        } else {
                            $UPool | Add-Member "$($_.Name)" $_.Value -Force
                        }
                    }

                    foreach ($q in @("CoinSymbol","Currency","Host","Port")) {
                        if ("$($UPool.$q)" -eq "") {$UPool.Enable = $false;Break}
                    }
                    $UPool
                }) -Force
                $CheckPools = $true
            }
            if ($UserPoolsConfig -ne $null) {Remove-Variable "UserPoolsConfig"}
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
                $v = @(($Session.Config.Pools.$p.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object)
                if ([bool]$Session.Config.Pools.$p.PSObject.Properties[$q]) {
                    $Session.Config.Pools.$p.$q = $v
                } else {
                    $Session.Config.Pools.$p | Add-Member $q $v -Force
                }
            }

            $Session.Config.Pools.$p.PSObject.Properties | Where-Object {$_.Name -match "^(Allow|Enable)" -and $_.Value -isnot [bool]} | Foreach-Object {
                $Session.Config.Pools.$p."$($_.Name)" = Get-Yes $_.Value
            }

            if ($Session.Config.Pools.$p.EnableAutoCoin) {
                $Session.Config.Coins.PSObject.Properties | Where-Object {$_.Value.EnableAutoPool -and $_.Value.Wallet} | Sort-Object Name | Foreach-Object {
                    if (-not $Session.Config.Pools.$p."$($_.Name)") {
                        if ([bool]$Session.Config.Pools.$p.PSObject.Properties["$($_.Name)"]) {
                            $Session.Config.Pools.$p."$($_.Name)" = $_.Value.Wallet
                        } else {
                            $Session.Config.Pools.$p | Add-Member $_.Name $_.Value.Wallet -Force
                        }
                    }
                }
            }
            $cparams = [PSCustomObject]@{}
            $Session.Config.Pools.$p.PSObject.Properties.Name | Where-Object {$_ -notmatch "^#" -and $_ -match "^(.+)-Params$"} | Foreach-Object {$cparams | Add-Member $Matches[1] $Session.Config.Pools.$p.$_ -Force}
            $Session.Config.Pools.$p | Add-Member Wallets $(Get-PoolPayoutCurrencies $Session.Config.Pools.$p) -Force
            $Session.Config.Pools.$p | Add-Member Params $cparams -Force

            $Pool_SwHyst                = "$($Session.Config.Pools.$p.SwitchingHysteresis -replace "[^\d\.\-]+")"
            $Pool_MaxAllowedLuck        = "$($Session.Config.Pools.$p.MaxAllowedLuck -replace "[^\d\.]+")"
            $Pool_MaxTimeSinceLastBlock = "$($Session.Config.Pools.$p.MaxTimeSinceLastBlock -replace "[^\d\.mhdw]+")"
            $Pool_BalancesKeepAlive     = "$($Session.Config.Pools.$p.BalancesKeepAlive -replace "[^\d]+")"
            $Pool_MaxTimeToFind         = "$($Session.Config.Pools.$p.MaxTimeToFind -replace "[^\d\.mhdw]+")"            
            $Pool_MaxTimeToFind         = if ($Pool_MaxTimeToFind -ne "") {ConvertFrom-Time $Pool_MaxTimeToFind} else {$null}

            ([ordered]@{
                DataWindow            = (Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow)
                Penalty               = ([Math]::Round([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+"),2))
                MaxMarginOfError      = ([Math]::Round([double]($Session.Config.Pools.$p.MaxMarginOfError -replace "[^\d\.\-]+"),2))
                SwitchingHysteresis   = $(if ($Pool_SwHyst) {[Math]::Max([Math]::Min([double]$Pool_SwHyst,100.0),0.0)} else {$null})
                StatAverage           = (Get-StatAverage $Session.Config.Pools.$p.StatAverage -Default $Session.Config.PoolStatAverage)
                StatAverageStable     = (Get-StatAverage $Session.Config.Pools.$p.StatAverageStable -Default $Session.Config.PoolStatAverageStable)
                MaxAllowedLuck        = $(if ($Pool_MaxAllowedLuck) {[Math]::Max([double]$Pool_MaxAllowedLuck,0.0)} else {$null})
                MaxTimeSinceLastBlock = $(if ($Pool_MaxTimeSinceLastBlock) {ConvertFrom-Time $Pool_MaxTimeSinceLastBlock} else {$null})
                MaxTimeToFind         = $Pool_MaxTimeToFind
                Region                = $(if ($Session.Config.Pools.$p.Region) {Get-Region $Session.Config.Pools.$p.Region} else {$null})
                SSL                   = $(if ("$($Session.Config.Pools.$p.SSL)" -ne '') {Get-Yes $Session.Config.Pools.$p.SSL} else {$Session.Config.SSL})
                BalancesKeepAlive     = $(if ($Pool_BalancesKeepAlive) {ConvertFrom-Time $Pool_BalancesKeepAlive} else {$null})
                MinBLKRate            = $(if ($Pool_MaxTimeToFind) {86400/$Pool_MaxTimeToFind} else {0})
            }).GetEnumerator() | Foreach-Object {
                if ([bool]$Session.Config.Pools.$p.PSObject.Properties["$($_.Name)"]) {
                    $Session.Config.Pools.$p."$($_.Name)" = $_.Value
                } else {
                    $Session.Config.Pools.$p | Add-Member "$($_.Name)" $_.Value -Force
                }
            }
        }
    }

    #Check for diverse per-mining events
    $Global:PauseMiners.Set([PauseStatus]::ByBattery,$Session.Config.EnablePauseOnBattery -and (Test-IsOnBattery))

    #Get PowerPrice and Scheduler events
    $PauseByScheduler        = $false
    $PowerPrice              = [Double]$Session.Config.PowerPrice
    $EnableMiningHeatControl = $Session.Config.EnableMiningHeatControl
    $MiningHeatControl       = $Session.Config.MiningHeatControl
    $TimeOfDay = (Get-Date).TimeOfDay.ToString("hh\:mm")
    $DayOfWeek = "$([int](Get-Date).DayOfWeek)"
    $Scheduler = $null
    $Session.Config.Scheduler.Where({$_.Enable -and $_.DayOfWeek -eq "*" -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To}).ForEach({$PowerPrice = [Double]$_.PowerPrice;$EnableMiningHeatControl = $_.EnableMiningHeatControl;$MiningHeatControl = $_.MiningHeatControl;$PauseByScheduler = $_.Pause -and -not $Session.IsExclusiveRun;$Scheduler = $_})
    $Session.Config.Scheduler.Where({$_.Enable -and $_.DayOfWeek -match "^\d$" -and $DayOfWeek -eq $_.DayOfWeek -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To}).ForEach({$PowerPrice = [Double]$_.PowerPrice;$EnableMiningHeatControl = $_.EnableMiningHeatControl;$MiningHeatControl = $_.MiningHeatControl;$PauseByScheduler = $_.Pause -and -not $Session.IsExclusiveRun;$Scheduler = $_})

    $Global:PauseMiners.Set([PauseStatus]::ByScheduler,$PauseByScheduler)

    if ($Scheduler) {
        Write-Log -Level Info "Scheduler profile $($Scheduler.Name) currently active: DayOfWeek=$($Scheduler.DayOfWeek), From=$($Scheduler.From), To=$($Scheduler.To)"
    }

    $Session.CurrentPowerPrice              = $PowerPrice
    $Session.CurrentEnableMiningHeatControl = $EnableMiningHeatControl
    $Session.CurrentMiningHeatControl       = $MiningHeatControl

    $API.CurrentPowerPrice                  = $Session.CurrentPowerPrice
    $API.CurrentEnableMiningHeatControl     = $Session.CurrentEnableMiningHeatControl
    $API.CurrentMiningHeatControl           = $Session.CurrentMiningHeatControl

    #Versioncheck for automatic updates
    $Session.AutoUpdate = $false
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version -and $Session.Config.EnableAutoUpdate -and -not $Session.IsExclusiveRun -and -not $Global:PauseMiners.Test([PauseStatus]::ByActivity) -and (-not $Session.Config.EnableUpdateWhenScheduled -or $Scheduler.EnableUpdate) -and ($Session.Config.EnableUpdateDuringPause -or -not $Global:PauseMiners.Test())) {
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

    #load server pools
    [System.Collections.Generic.List[string]]$ServerPoolNames = @()
    $ServerPools       = $null
    $ServerDonationRun = $false

    if (-not $Session.IsDonationRun -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and $Session.Config.EnableServerPools) {
        $ServerConnected = Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 2
        if ($ServerConnected) {
            try {
                $Request = Invoke-RestMethodAsync "server://allpools" -cycletime 120 -Timeout 20
                $Pool_WorkerNames = [hashtable]@{}
                $ServerPools = $Request | Where-Object {$_.Name -and $_.Algorithm -and $_.Name -ne "MiningRigRentals"} | Foreach-Object {
                    if (-not $ServerDonationRun) {
                        if (-not $Pool_WorkerNames.ContainsKey($_.Name)) {
                            if ("$($_.Worker)$($_.User)$($_.Pass)" -match "{workername:mpx}") {$ServerDonationRun = $true}
                            else {
                                $Pool_WorkerNames[$_.Name] = "{workername:$(if ($Session.Config.Pools."$($_.Name)".Worker) {$Session.Config.Pools."$($_.Name)".Worker} else {$Session.Config.WorkerName})}"
                            }
                        }
                        $Pool_Worker = $_.Worker = $Pool_WorkerNames[$_.Name]
                        $_.User = $_.User -replace "{workername:.+}",$Pool_Worker
                        $_.Pass = $_.Pass -replace "{workername:.+}",$Pool_Worker
                        if ($_.Failover) {
                            $_.Failover | Foreach-Object {
                                $_.User = $_.User -replace "{workername:.+}",$Pool_Worker
                                $_.Pass = $_.Pass -replace "{workername:.+}",$Pool_Worker
                            }
                        }
                    }
                    $_.Updated = [DateTime]$_.Updated
                    $_
                }
                $ServerPools.Name | Select-Object -Unique | Foreach-Object {
                    $ServerPoolNames.Add($_) > $null
                }
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $ServerPools = $null
                $ServerPoolNames.Clear()
                $ServerDonationRun = $false
            }
        }
    }

    $Session.IsServerDonationRun = $ServerDonationRun

    #Activate or deactivate donation  
    $DonateMinutes = if ($Session.Config.Donate -lt 10) {10} else {$Session.Config.Donate}
    $DonateDelayHours = 24
    if ($DonateMinutes -gt 15) {
        $DonateMinutes /= 2
        $DonateDelayHours /= 2
    }

    if (-not $Session.LastDonated -or $Global:PauseMiners.Test()) {
        if (-not $Session.LastDonated) {$Session.LastDonated = Get-LastDrun}
        $ShiftDonationHours = if ($Session.RoundCounter -eq 0) {(Get-Random -Minimum 100 -Maximum 200)/100} else {1}
        $ShiftDonationRun = $Session.Timer.AddHours($ShiftDonationHours - $DonateDelayHours).AddMinutes($DonateMinutes)
        if (-not $Session.LastDonated -or $Session.LastDonated -lt $ShiftDonationRun -or $Global:PauseMiners.Test()) {
            $Session.IsDonationRun = $false
            $Session.LastDonated   = Set-LastDrun $ShiftDonationRun
        }
    }

    if ($Session.IsServerDonationRun -or ($Session.Timer.AddHours(-$DonateDelayHours) -ge $Session.LastDonated.AddSeconds(59))) {
        $Session.IsDonationRun = $false
        $Session.LastDonated   = Set-LastDrun $Session.Timer
    }

    if (-not $Session.IsDonationRun -and $Session.UserConfig) {
        $Session.Config = $Session.UserConfig | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $Session.UserConfig = $null
        $API.UserConfig = $null
        $Global:AllPools = $null
        $Global:WatchdogTimers = @()
        Update-WatchdogLevels -Reset
        Write-Log "Donation run finished. "
    }

    if ($Session.Timer.AddHours(-$DonateDelayHours).AddMinutes($DonateMinutes) -ge $Session.LastDonated -and $Session.AvailPools.Count -gt 0) {
        if ($Session.RoundCounter -gt 0 -and -not $Session.IsDonationRun -and -not $Session.UserConfig) {
            try {$DonationData = Invoke-GetUrl "https://rbminer.net/api/dconf.php";Set-ContentJson -PathToFile ".\Data\dconf.json" -Data $DonationData -Compress > $null} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Rbminer.net/api/dconf.php could not be reached"}
            if (-not $DonationData -or -not $DonationData.Wallets) {try {$DonationData = Get-ContentByStreamReader ".\Data\dconf.json" | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
            if (-not $DonationData -or -not $DonationData.Wallets) {$DonationData = Get-Unzip 'H4sIAAAAAAAEAL2VW3OiMBTH33dmvwTPfYAIiL6BotbbYtW1dcfpJBAwlSRugArt9Ltvwt4qM529ONM3TpI553f+58KzFgiOICIpySuta+j6lbaBaYrzTOs+a2BGGBb15+22p3U1ODlhMCdzNDBAObbcKnG2rGidphtik3I8GDNNOuDigIV8TY+lNPswhxvCIn6SRzjLCYU5vg8LITDL5X2AGUzr6M6VtlxOtW4M0wy/XGl+vseCSgQF4K8UgF6245ZvA2whpNu6gVwLxLpjtHrIMRzQ7sSmDj3D9HoXgOgNjhmXKvBPIYaslmJ2Ix2Y5rr/9Sm24HALrZxkwEvGrafpcD/Lc754CApjYE2Nz/l2yFw08SB39jZmt0bUwfxoHc2RG6wfQTkz4XTxcFe1w5HhGy4bLDc0mW8W/4EPs+zERSRvy0Y2fhmmRYTdNOGC5Hsqn/SK8AAF56CTaY105yTEI5jtVa5erXoriNfrlbE6sLiKzCW7E/7pdFz77sJ/2kTAK/qXqR2kMI+5UFyPQN7NYEloQWdQJIR9in0huHKsN0llexKWBJynowIp3AbDOqsNgag03OD6/rqvKgeA2bF/nExwpfhiMzYcZMamE1kd2wyt2AQ26ugmMCPdcULDskOsh5EOoY46jmM6nVYIUWwj3LJ0/E9tDmTk35X4otG6veST7ICJGiBaCQKjRHDpJtV2jaTlxKrqyMT/lPEyh7n7iAVMsPxEqZwjiVk1xHf9Xg0ZKiGmq15T5C0WtcSv2qFf3viro8dvJ8L3FuUAgVEW0KENj+WITui6vGQLgDfi9zhh2TtCqHjLiiKVufaWKEue8ndkej3BtE2bVH0cwyLNLwM6a6G/p7PPWFSfSnky1d9qn+zVPmnW8vWGP9+yZ12+O5+X3a99Vv+d5pBiFWUoCBvyNKoPpQNlSyc/zTlhD/CGJEqyEzx+P969fPzwDah1LfsDBwAA' | ConvertFrom-Json}
            if (-not $Session.IsDonationRun) {Write-Log "Donation run started for the next $(($Session.LastDonated-($Session.Timer.AddHours(-$DonateDelayHours))).Minutes +1) minutes. "}
            $API.UserConfig = $Session.Config | ConvertTo-Json -Depth 10
            $Session.UserConfig = $API.UserConfig | ConvertFrom-Json -ErrorAction Ignore
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
                $Session.Config.Pools.$p | Add-Member SSL ([bool]$Session.Config.Pools.$p.SSL) -Force
            }
            if ($DonationData.ExcludeAlgorithm) {
                $Session.Config | Add-Member ExcludeAlgorithm @($Session.Config.ExcludeAlgorithm + (Compare-Object $DonationData.ExcludeAlgorithm $Session.Config.Algorithm | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) | Select-Object -Unique) -Force
            }
            if ($DonationData.ExcludeMinerName) {
                $Session.Config | Add-Member ExcludeMinerName @($Session.Config.ExcludeMinerName + (Compare-Object $DonationData.ExcludeMinerName $Session.Config.MinerName | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) | Select-Object -Unique) -Force
            }
            $Session.Config | Add-Member DisableExtendInterval $true -Force
            $Session.Config | Add-Member Userpools @() -Force
            $Global:AllPools = $null
        }
    } else {
        Write-Log ("Next donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($Session.LastDonated.AddHours($DonateDelayHours) - ($Session.Timer.AddMinutes($DonateMinutes))))
    }

    $UserConfig = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

    #Clear pool cache if the pool configuration has changed
    if ($Global:AllPools -ne $null -and (($ConfigBackup.Pools | ConvertTo-Json -Compress -Depth 10) -ne ($Session.Config.Pools | ConvertTo-Json -Compress -Depth 10) -or (Compare-Object @($ConfigBackup.PoolName) @($Session.Config.PoolName)) -or (Compare-Object @($ConfigBackup.ExcludePoolName) @($Session.Config.ExcludePoolName)))) {
        Write-Log -Level Info "Resetting AllPools data store"
        $Global:AllPools = $null
    }

    #load device(s) information and device combos
    if ($CheckConfig -or $CheckCombos -or $ConfigBackup.MiningMode -ne $Session.Config.MiningMode -or (Compare-Object $Session.Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0 -or (Compare-Object $Session.Config.ExcludeDeviceName $ConfigBackup.ExcludeDeviceName | Measure-Object).Count -gt 0) {
        if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Device configuration changed. Refreshing now."}

        #Load information about the devices
        $Global:DeviceCache.Devices = @()
        if (($Session.Config.DeviceName | Measure-Object).Count) {$Global:DeviceCache.Devices = @(Get-Device $Session.Config.DeviceName $Session.Config.ExcludeDeviceName).ForEach({$_})}
        $Global:DeviceCache.DevicesByTypes = [PSCustomObject]@{
            AMD    = $Global:DeviceCache.Devices.Where({$_.Type -eq "Gpu" -and $_.Vendor -eq "AMD"})
            INTEL  = $Global:DeviceCache.Devices.Where({$_.Type -eq "Gpu" -and $_.Vendor -eq "INTEL"})
            NVIDIA = $Global:DeviceCache.Devices.Where({$_.Type -eq "Gpu" -and $_.Vendor -eq "NVIDIA"})
            CPU    = $Global:DeviceCache.Devices.Where({$_.Type -eq "Cpu"})
            Combos = [PSCustomObject]@{}
            FullComboModels = [PSCustomObject]@{}
        }
        [hashtable]$Global:DeviceCache.DevicesToVendors = @{}

        $CUDAVersion = "$($Global:GlobalCachedDevices.Where({$_.Type -eq "Gpu" -and $_.Vendor -eq "NVIDIA" -and $_.OpenCL.PlatformVersion -match "CUDA\s+([\d\.]+)"},"First").ForEach({$Matches[1]}))"

        $Session.Config | Add-Member DeviceModel @($Global:DeviceCache.Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object) -Force
        $Session.Config | Add-Member CUDAVersion $(if ($CUDAVersion -ne "") {$CUDAVersion}else{$false}) -Force
        $Session.Config | Add-Member DotNETRuntimeVersion $(try {[String]$(if ($cmd = (Get-Command dotnet -ErrorAction Ignore)) {(dir $cmd.Path.Replace('dotnet.exe', 'shared/Microsoft.NETCore.App')).Name | Where-Object {$_ -match "^([\d\.]+)$"} | Foreach-Object {Get-Version $_} | Sort-Object | Select-Object -Last 1})} catch {if ($Error.Count){$Error.RemoveAt(0)}}) -Force

        if ($IsLinux) {
            $Session.OCDaemonOnEmptyAdd = @()

            if ($Session.Config.EnableLinuxHeadless) {
                if ($Session.Config.LinuxDisplay) {
                    $Session.OCDaemonOnEmptyAdd += "export DISPLAY=$($Session.Config.LinuxDisplay)"
                }
                if ($Session.Config.LinuxXAuthority) {
                    $Session.OCDaemonOnEmptyAdd += "export XAUTHORITY=$($Session.Config.LinuxXAuthority)"
                }
            }

            if ($Global:DeviceCache.DevicesByTypes.NVIDIA -and $Session.Config.EnableOCProfiles) {
                $Session.OCDaemonOnEmptyAdd += "export CUDA_DEVICE_ORDER=PCI_BUS_ID"
                Invoke-NvidiaSmi -Arguments "-pm 1" -Runas > $null
                Invoke-NvidiaSmi -Arguments "--gom=COMPUTE" -Runas > $null
                Set-OCDaemon "sleep 1" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
                Invoke-NvidiaSettings -SetPowerMizer
                Invoke-OCDaemon -FilePath ".\IncludesLinux\bash\oc_init.sh" -Quiet > $null
            }
        }

        #Create combos
        @($Global:DeviceCache.DevicesByTypes.PSObject.Properties.Name) | Where {@("Combos","FullComboModels") -inotcontains $_} | Foreach-Object {
            $SubsetType = [String]$_
            $Global:DeviceCache.DevicesByTypes.Combos | Add-Member $SubsetType @() -Force
            $Global:DeviceCache.DevicesByTypes.FullComboModels | Add-Member $SubsetType $(@($Global:DeviceCache.DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique | Sort-Object) -join '-') -Force
            $Global:DeviceCache.DevicesByTypes.FullComboModels.$SubsetType | Where-Object {$_ -match '-' -and $Session.Config.Combos.$SubsetType.$_ -ne $null} | Foreach-Object {
                # always force enable full combos
                $Session.Config.Combos.$SubsetType | Add-Member $_ $true -Force
            }
            Get-DeviceSubSets $Global:DeviceCache.DevicesByTypes.$SubsetType | Where-Object {$Session.Config.Combos.$SubsetType."$($_.Model -join '-')"} | Foreach-Object {                       
                $SubsetModel= $_
                $Global:DeviceCache.DevicesByTypes.Combos.$SubsetType += @($Global:DeviceCache.DevicesByTypes.$SubsetType | Where-Object {$SubsetModel.Model -icontains $_.Model} | Foreach-Object {$SubsetNew = $_ | ConvertTo-Json -Depth 10 | ConvertFrom-Json;$SubsetNew.Model = $($SubsetModel.Model -join '-');$SubsetNew.Model_Name = $($SubsetModel.Model_Name -join '+');$SubsetNew})
            }
            if ($Global:DeviceCache.DevicesByTypes.$SubsetType) {
                @($Global:DeviceCache.DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique) + @($Global:DeviceCache.DevicesByTypes.Combos.$SubsetType | Select-Object -ExpandProperty Model) | Where-Object {$_} | Foreach-Object {$Global:DeviceCache.DevicesToVendors[$_] = $SubsetType}
            }
        }

        if ($Session.Config.MiningMode -eq "legacy") {
            @($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {
                $Device_LegacyModel = $_
                if ($Global:DeviceCache.DevicesByTypes.FullComboModels.$Device_LegacyModel -match '-') {
                    $Global:DeviceCache.DevicesByTypes.$Device_LegacyModel = $Global:DeviceCache.DevicesByTypes.Combos.$Device_LegacyModel | Where-Object Model -eq $Global:DeviceCache.DevicesByTypes.FullComboModels.$Device_LegacyModel
                }
            }
        } elseif ($Session.Config.MiningMode -eq "combo") {
            #add combos to DevicesbyTypes
            @("AMD","INTEL","NVIDIA","CPU") | Foreach-Object {$Global:DeviceCache.DevicesByTypes.$_ += $Global:DeviceCache.DevicesByTypes.Combos.$_}
        }

        [hashtable]$Global:DeviceCache.DeviceNames = @{}
        @("AMD","INTEL","NVIDIA","CPU") | Foreach-Object {
            $Global:DeviceCache.DevicesByTypes.$_ | Group-Object Model | Foreach-Object {$Global:DeviceCache.DeviceNames[$_.Name] = @($_.Group | Select-Object -ExpandProperty Name | Sort-Object)}
        }

        $Global:DeviceCache.DeviceCombos = @($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name | ForEach-Object {$Global:DeviceCache.DevicesByTypes.$_ | Select-Object -ExpandProperty Model -Unique} | Sort-Object).Where({$_})
        $Global:DeviceCache.DevicesNames = @($Global:DeviceCache.Devices.Name | Select-Object -Unique | Sort-Object).Where({$_})

        $API.DeviceCombos     = $Global:DeviceCache.DeviceCombos
        $API.DevicesToVendors = $Global:DeviceCache.DevicesToVendors

        #Update device information for the first time
        Update-DeviceInformation $Global:DeviceCache.DevicesNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    }
    
    if ($ConfigBackup -ne $null) {Remove-Variable "ConfigBackup"}


    if ($IsLinux -and $Global:DeviceCache.DevicesByTypes.NVIDIA -and $Session.Config.EnableOCProfiles -and $Session.Config.EnableOCLinuxForcePState -and -not (Get-Process | Where-Object Name -eq "forcePstate") -and (Test-Path ".\IncludesLinux\bin\forcePstate")) {
        Set-OCDaemon "$($Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\IncludesLinux\bin\forcePstate")) &" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
        Invoke-OCDaemon -FilePath ".\IncludesLinux\bash\forcePstate.sh" -Quiet > $null
    }

    $Global:DeviceCache.ConfigFullComboModelNames = @($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name).Where({$_})

    if (-not $Global:DeviceCache.Devices) {
        $Global:PauseMiners.Set([PauseStatus]::ByError)
    }

    $API.AllDevices = $Global:DeviceCache.AllDevices
    $API.Devices    = $Global:DeviceCache.Devices

    #Check for miner config
    if (Set-ConfigDefault "Miners") {
        if ($CheckConfig -or -not $Session.Config.Miners -or (Test-Config "Miners" -LastWriteTime)) {
            if ($Session.RoundCounter -ne 0) {Write-Log -Level Info "Updating miners config data"}
            $MinersConfig = Get-ConfigContent "Miners" -UpdateLastWriteTime
            if (Test-Config "Miners" -Health) {
                $Session.Config | Add-Member Miners ([PSCustomObject]@{}) -Force
                $CPU_GlobalAffinityMask = Get-CPUAffinity $Global:GlobalCPUInfo.Threads -ToInt
                foreach ($CcMiner in @($MinersConfig.PSObject.Properties)) {
                    $CcMinerName = $CcMiner.Name
                    [String[]]$CcMinerName_Array = @($CcMinerName -split '-')
                    if ($CcMinerName_Array.Count -gt 1 -and ($Global:DeviceCache.ConfigFullComboModelNames -icontains $CcMinerName_Array[1]) -and ($Global:DeviceCache.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")) {$CcMinerName = "$($CcMinerName_Array[0])-$($Global:DeviceCache.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")";$CcMinerName_Array = @($CcMinerName -split '-')}                
                    $CcMinerOk = $true
                    for($i=1;($i -lt $CcMinerName_Array.Count) -and $CcMinerOk;$i++) {if ($Session.Config.DeviceModel -inotcontains $CcMinerName_Array[$i]) {$CcMinerOk=$false}}
                    if ($CcMinerOk) {
                        foreach($p in @($CcMiner.Value)) {
                            $p | Add-Member Disable $(Get-Yes $p.Disable) -Force
                            if ($p.SecondaryAlgorithm) {
                                $p | Add-Member Intensity @($p.Intensity -replace "[^0-9,;]+" -split "[,;]+" | Where-Object {"$_" -ne ""} | Select-Object -Unique) -Force
                            }
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
                                if ($p.Affinity) {
                                    $CPUAffinityInt = (ConvertFrom-CPUAffinity $p.Affinity -ToInt) -band $CPU_GlobalAffinityMask
                                    if ($CPUAffinityInt) {
                                        $p.Affinity = "0x{0:x$(if($CPUAffinityInt -lt 65536){4}else{8})}" -f $CPUAffinityInt
                                        if (-not $p.Threads) {
                                            $CPUThreads = @(ConvertFrom-CPUAffinity $p.Affinity).Count
                                            if ($p.Threads -eq $null) {$p | Add-Member Threads $Threads -Force} else {$p.Threads = $CPUThreads}
                                        }
                                    } else {
                                        $p.Affinity = ""
                                    }
                                }
                                if ($p.Threads -ne $null) {$p.Threads = [int]($p.Threads -replace "[^\d]")}
                                if ($p.ShareCheck -ne $null -and $p.ShareCheck -ne "") {$p.ShareCheck = ConvertFrom-Time $p.ShareCheck}
                                $Session.Config.Miners | Add-Member -Name $CcMinerNameToAdd -Value $p -MemberType NoteProperty -Force
                                $Session.Config.Miners.$CcMinerNameToAdd.Disable = Get-Yes $Session.Config.Miners.$CcMinerNameToAdd.Disable
                            }
                        }
                    }
                }
            }
            if ($MinersConfig -ne $null) {Remove-Variable "MinersConfig"}
        }
    }

    #$API.Config     = ConvertTo-Json $Session.Config -Depth 10

    $MinerInfoChanged = $false
    if (-not (Test-Path ".\Data\minerinfo.json")) {$Global:MinerInfo = @{}}
    Compare-Object @($Session.AvailMiners | Select-Object) @($Global:MinerInfo.Keys | Select-Object) | Foreach-Object {
        $CcMinerName = $_.InputObject
        Switch ($_.SideIndicator) {
            "<=" {$Global:MinerInfo[$CcMinerName] = @(Get-MinersContent -MinerName $CcMinerName -Parameters @{InfoOnly = $true} | Select-Object -ExpandProperty Type);Break}
            "=>" {$Global:MinerInfo.Remove($CcMinerName);Break}
        }
        $MinerInfoChanged = $true
    }
    if ($MinerInfoChanged) {Set-ContentJson -PathToFile ".\Data\minerinfo.json" -Data $Global:MinerInfo -Compress > $null}

    $API.MinerInfo = $Global:MinerInfo

    #Check for GPU failure and reboot, if needed
    if ($Session.Config.RebootOnGPUFailure) { 
        Write-Log "Testing for GPU failure. "
        Test-GPU
    }

    if ($UseTimeSync) {Test-TimeSync}
    $Session.Timer = (Get-Date).ToUniversalTime()

    $RoundSpan = if ($Session.RoundStart) {New-TimeSpan $Session.RoundStart $Session.Timer} else {New-TimeSpan -Seconds $Session.Config.BenchmarkInterval}
    $Session.RoundStart = $Session.Timer
    $RoundEnd = $Session.Timer.AddSeconds($Session.CurrentInterval)

    $UnprofitableAlgos = Get-UnprofitableAlgos
    $UnprofitableCpuAlgos = Get-UnprofitableCpuAlgos

    #Update the exchange rates
    Write-Log "Updating exchange rates. "
    Update-Rates

    $API.Rates = ConvertTo-Json $Global:Rates -Depth 10
    $ActualRates = [PSCustomObject]@{}
    $Global:Rates.Keys | Where-Object {$Session.Config.Currency -icontains $_} | Foreach-Object {$ActualRates | Add-Member $_ $Global:Rates.$_}
    $API.ActualRates = $ActualRates

    #PowerPrice check
    $Session.PowerPriceBTC = 0
    if ($Session.Config.PowerPrice -gt 0 -and $Session.Config.PowerPriceCurrency) {
        if ($Global:Rates."$($Session.Config.PowerPriceCurrency)") {
            $Session.PowerPriceBTC = [Double]$Session.Config.PowerPrice/[Double]$Global:Rates."$($Session.Config.PowerPriceCurrency)"
        }
    }
    $API.PowerPriceBTC = $Session.PowerPriceBTC

    $Session.CurrentPowerPriceBTC = 0
    if ($Session.CurrentPowerPrice -gt 0 -and $Session.Config.PowerPriceCurrency) {
        if ($Global:Rates."$($Session.Config.PowerPriceCurrency)") {
            $Session.CurrentPowerPriceBTC = [Double]$Session.CurrentPowerPrice/[Double]$Global:Rates."$($Session.Config.PowerPriceCurrency)"
        } else {
            Write-Log -Level Warn "Powerprice currency $($Session.Config.PowerPriceCurreny) not found. Cost of electricity will be ignored."
        }
    }
    $API.CurrentPowerPriceBTC = $Session.CurrentPowerPriceBTC

    #Load the stats
    Write-Log "Loading saved statistics. "

    Get-Stat -Miners -Quiet
    [hashtable]$Disabled      = Get-Stat -Disabled

    $API.Stats = $Global:StatsCache

    #Load information about the pools
    Write-Log "Loading pool information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading pool modules .."}

    [System.Collections.Generic.List[string]]$SelectedPoolNames = @()
    $NewPools = @()
    $TimerPools = @{}
    $StopWatch = [System.Diagnostics.StopWatch]::New()

    if (Test-Path "Pools") {
        $NewPools = $Session.AvailPools + "Userpools" | Where-Object {-not $ServerPools -or $_ -eq "MiningRigRentals"} | Where-Object {($Session.Config.Pools.$_ -and ($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_)) -or ($_ -eq "Userpools" -and $Session.Config.Userpools)} | Foreach-Object {
            if ($Session.RoundCounter -eq 0) {Write-Host ".. loading $($_) " -NoNewline}
            $StopWatch.Restart()
            if ($_ -eq "Userpools") {
                $Session.Config.Userpools | Where-Object {$_.Name} | Foreach-Object {$_.Name} | Select-Object -Unique | Sort-Object | Foreach-Object {
                    if (-not $SelectedPoolNames.Contains($_) -and -not $ServerPoolNames.Contains($_)) {
                        $Pool_Parameters = @{StatSpan = $RoundSpan; InfoOnly = $false; Name = $_}
                        $Session.Config.Pools.$_.PSObject.Properties | Foreach-Object {$Pool_Parameters[$_.Name] = $_.Value}
                        Get-PoolsContent "Userpools" -Parameters $Pool_Parameters -Disabled $Disabled
                        $SelectedPoolNames.Add($_) > $null
                        Remove-Variable "Pool_Parameters"
                    }
                }
            } else {
                $Pool_Parameters = @{StatSpan = $RoundSpan; InfoOnly = $false}
                $Session.Config.Pools.$_.PSObject.Properties | Foreach-Object {$Pool_Parameters[$_.Name] = $_.Value}
                Get-PoolsContent $_ -Parameters $Pool_Parameters -Disabled $Disabled
                $SelectedPoolNames.Add($_) > $null
                Remove-Variable "Pool_Parameters"
            }
            $TimerPools[$_] = [Math]::Round($StopWatch.Elapsed.TotalSeconds,3)
            if ($Session.RoundCounter -eq 0) {Write-Host "done ($($TimerPools[$_])s) "}
            Write-Log "$($_) loaded in $($TimerPools[$_])s "
        }
    }
    $TimerPools | ConvertTo-Json | Set-Content ".\Logs\timerpools.json" -Force
    Remove-Variable "StopWatch"
    Remove-Variable "TimerPools"

    #Store pools to file
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and (-not $Session.Updatetracker.PoolsSave -or $Session.Updatetracker.PoolsSave -lt (Get-Date).AddHours(-6) -or -not (Test-Path ".\Data\poolsdata.json"))) {
        $Session.Updatetracker.PoolsSave = Get-Date
        Set-ContentJson ".\Data\poolsdata.json" @($NewPools | Select-Object Name,Algorithm,CoinSymbol,Price,StablePrice,PenaltyFactor,ErrorRatio -Unique) -Compress > $null
        $Session.ReportPoolsData = $true
    }

    #Report devices
    if (-not $Session.Updatetracker.ReportDeviceData -or $Session.Updatetracker.ReportDeviceData -lt (Get-Date).AddDays(-1)) {
        $Session.Updatetracker.ReportDeviceData = Get-Date
        $Session.ReportDeviceData = $true
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

        $BalancesData = Get-Balance -Config $UserConfig -Refresh $RefreshBalances

        if (-not $BalancesData) {$Session.Updatetracker.Balances = 0}
        else {
            $API.Balances = ConvertTo-Json $BalancesData -Depth 10
            $Session.Earnings_Avg = $API.Earnings_Avg = ($BalancesData | Where-Object {$_.Name -notmatch "^\*" -and $_.BaseName -ne "Wallet" -and $Global:Rates."$($_.Currency)"} | Foreach-Object {$_.Earnings_Avg / $Global:Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
            $Session.Earnings_1d  = $API.Earnings_1d  = ($BalancesData | Where-Object {$_.Name -notmatch "^\*" -and $_.BaseName -ne "Wallet" -and $Global:Rates."$($_.Currency)"} | Foreach-Object {$_.Earnings_1d / $Global:Rates."$($_.Currency)"} | Measure-Object -Sum).Sum

            if ($RefreshBalances) {$Session.ReportTotals = $true}
        }
    }

    #Stop async jobs for no longer needed pools (will restart automatically, if pool pops in again)
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and $Session.Config.RunMode -ne "Server") {
        $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_ -or -not (($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_)) -or $ServerPoolNames.Contains($_)} | Foreach-Object {Stop-AsyncJob -tag $_}
    }

    #Remove stats from pools & miners not longer in use
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and (Test-Path "Stats")) {
        if ($SelectedPoolNames -and $SelectedPoolNames.Count -gt 0) {Compare-Object @($SelectedPoolNames | Select-Object) @($Global:StatsCache.Keys | Where-Object {$_ -match '^(.+?)_.+Profit$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Pools\$($_.InputObject)_*_Profit.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Foreach-Object{Remove-Item $_.FullName -Force}}}
        if ($Session.AvailMiners -and $Session.AvailMiners.Count -gt 0) {Compare-Object @($Session.AvailMiners | Select-Object) @($Global:StatsCache.Keys | Where-Object {$_ -match '^(.+?)-.+Hashrate$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Miners\*-$($_.InputObject)-*_Hashrate.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Foreach-Object {Remove-Item $_.FullName -Force}}}
    }

    if ($ServerPools -and $ServerPoolNames.Count) {
        $NewPools = @($NewPools) + @($ServerPools)
    }
    Remove-Variable "SelectedPoolNames"

    if ($Session.RoundCounter -eq 0) {Write-Host "Selecting best pools .."}

    $LockMiners = $Session.LockMiners.Locked -and -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun

    #This finds any pools that were already in $Global:AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    $Test_Algorithm = @($Session.Config.Algorithm | Select-Object)
    $Test_ExcludeAlgorithm = @($Session.Config.ExcludeAlgorithm | Select-Object)
    $Test_CoinSymbol = @($Session.Config.CoinSymbol | Select-Object)
    $Test_ExcludeCoinSymbol = @($Session.Config.ExcludeCoinSymbol | Select-Object)
    $Test_PoolName = @($Session.Config.PoolName | Select-Object)
    $Test_ExcludePoolName = @($Session.Config.ExcludePoolName | Select-Object)

    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and $Scheduler) {
        if ($Scheduler.Algorithm.Count) {$Test_Algorithm = @($Test_Algorithm + $Scheduler.Algorithm | Select-Object -Unique)}
        if ($Scheduler.ExcludeAlgorithm.Count) {$Test_ExcludeAlgorithm = @($Test_ExcludeAlgorithm + $Scheduler.ExcludeAlgorithm | Select-Object -Unique)}
        if ($Scheduler.CoinSymbol.Count) {$Test_CoinSymbol = @($Test_CoinSymbol + $Scheduler.CoinSymbol | Select-Object -Unique)}
        if ($Scheduler.ExcludeCoinSymbol.Count) {$Test_ExcludeCoinSymbol = @($Test_ExcludeCoinSymbol + $Scheduler.ExcludeCoinSymbol | Select-Object -Unique)}
        if ($Scheduler.PoolName.Count) {$Test_PoolName = @($Test_PoolName + $Scheduler.PoolName | Select-Object -Unique)}
        if ($Scheduler.ExcludePoolName.Count) {$Test_ExcludePoolName = @($Test_ExcludePoolName + $Scheduler.ExcludePoolName | Select-Object -Unique)}
    }

    if ($PoolsToBeReadded = Compare-Object @($NewPools.Name | Select-Object -Unique) @($Global:AllPools.Name | Select-Object -Unique) | Where-Object {$_.SideIndicator -EQ "=>" -and $_.InputObject -ne "MiningRigRentals"} | Select-Object -ExpandProperty InputObject) {
        Write-Log -Level Info "Re-Adding currently failed pools: $($PoolsToBeReadded -join ", ")"
        $NewPools = @($NewPools | Select-Object) + ($Global:AllPools | Where-Object {$PoolsToBeReadded -icontains $_.Name} | Foreach-Object {$_ | ConvertTo-Json -Depth 10 | ConvertFrom-Json} | Select-Object)
    }

    $Global:AllPools = $null #will be set to NewPools later

    if ($Session.Config.EnableDebugMode) {
        $API.NewPools = $NewPools
    }

    $NewPools = $NewPools.Where({
        $Pool_Name = $_.Name
        $Pool_Algo = $_.Algorithm0
        $Pool_CheckForUnprofitableAlgo = -not $Session.Config.DisableUnprofitableAlgolist -and -not ($_.Exclusive -and -not $_.Idle)
        if ($_.CoinSymbol) {$Pool_Algo = @($Pool_Algo,"$($Pool_Algo)-$($_.CoinSymbol)")}
        ($ServerPoolNames.Count -and $ServerPoolNames.Contains($Pool_Name)) -or (
            -not ( (-not $Session.Config.Pools.$Pool_Name) -or
                ($Test_PoolName.Count -and $Test_PoolName -inotcontains $Pool_Name) -or
                ($Test_ExcludePoolName.Count -and $Test_ExcludePoolName -icontains $Pool_Name) -or
                ($Test_Algorithm.Count -and -not (Compare-Object $Test_Algorithm $Pool_Algo -IncludeEqual -ExcludeDifferent)) -or
                ($Test_ExcludeAlgorithm.Count -and (Compare-Object $Test_ExcludeAlgorithm $Pool_Algo -IncludeEqual -ExcludeDifferent)) -or
                ($Pool_CheckForUnprofitableAlgo -and $UnprofitableAlgos.Algorithms -and $UnprofitableAlgos.Algorithms.Count -and (Compare-Object $UnprofitableAlgos.Algorithms $Pool_Algo -IncludeEqual -ExcludeDifferent)) -or
                ($Pool_CheckForUnprofitableAlgo -and $UnprofitableAlgos.Pools.$Pool_Name.Algorithms -and $UnprofitableAlgos.Pools.$Pool_Name.Algorithms.Count -and (Compare-Object $UnprofitableAlgos.Pools.$Pool_Name.Algorithms $Pool_Algo -IncludeEqual -ExcludeDifferent)) -or
                ($Pool_CheckForUnprofitableAlgo -and $_.CoinSymbol -and $UnprofitableAlgos.Coins -and $UnprofitableAlgos.Coins.Count -and $UnprofitableAlgos.Coins -icontains $_.CoinSymbol) -or
                ($Pool_CheckForUnprofitableAlgo -and $_.CoinSymbol -and $UnprofitableAlgos.Pools.$Pool_Name.Coins -and $UnprofitableAlgos.Pools.$Pool_Name.Coins.Count -and $UnprofitableAlgos.Pools.$Pool_Name.Coins -icontains $_.CoinSymbol) -or
                ($Session.Config.ExcludeCoin.Count -and $_.CoinName -and $Session.Config.ExcludeCoin -icontains $_.CoinName) -or
                ($Test_CoinSymbol.Count -and $_.CoinSymbol -and $Test_CoinSymbol -inotcontains $_.CoinSymbol) -or
                ($Test_ExcludeCoinSymbol.Count -and $_.CoinSymbol -and $Test_ExcludeCoinSymbol -icontains $_.CoinSymbol) -or
                ($Session.Config.Pools.$Pool_Name.Algorithm.Count -and -not (Compare-Object $Session.Config.Pools.$Pool_Name.Algorithm $Pool_Algo -IncludeEqual -ExcludeDifferent)) -or
                ($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Compare-Object $Session.Config.Pools.$Pool_Name.ExcludeAlgorithm $Pool_Algo -IncludeEqual -ExcludeDifferent)) -or
                ($_.CoinName -and $Session.Config.Pools.$Pool_Name.CoinName.Count -and $Session.Config.Pools.$Pool_Name.CoinName -inotcontains $_.CoinName) -or
                ($_.CoinName -and $Session.Config.Pools.$Pool_Name.ExcludeCoin.Count -and $Session.Config.Pools.$Pool_Name.ExcludeCoin -icontains $_.CoinName) -or
                ($_.CoinSymbol -and $Session.Config.Pools.$Pool_Name.CoinSymbol.Count -and $Session.Config.Pools.$Pool_Name.CoinSymbol -inotcontains $_.CoinSymbol) -or
                ($_.CoinSymbol -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol -icontains $_.CoinSymbol)
            ) -and (
                ($_.Exclusive -and -not $_.Idle) -or -not (
                    ($_.Idle) -or
                    ($_.Hashrate -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinHashrate -and $_.Hashrate -lt $Session.Config.Algorithms."$($_.Algorithm)".MinHashrate) -or
                    ($_.Workers -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinWorkers -and $_.Workers -lt $Session.Config.Algorithms."$($_.Algorithm)".MinWorkers) -or
                    ($_.BLK -ne $null -and $Session.Config.Algorithms."$($_.Algorithm)".MinBLKRate -and ($_.BLK -lt $Session.Config.Algorithms."$($_.Algorithm)".MinBLKRate)) -or
                    ($_.BLK -ne $null -and $Session.Config.Pools.$Pool_Name.MinBLKRate -and ($_.BLK -lt $Session.Config.Pools.$Pool_Name.MinBLKRate)) -or
                    ($_.CoinSymbol -and $_.Hashrate -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinHashrate -and $_.Hashrate -lt $Session.Config.Coins."$($_.CoinSymbol)".MinHashrate) -or
                    ($_.CoinSymbol -and $_.Workers -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinWorkers -and $_.Workers -lt $Session.Config.Coins."$($_.CoinSymbol)".MinWorkers) -or
                    ($_.CoinSymbol -and $_.BLK -ne $null -and $Session.Config.Coins."$($_.CoinSymbol)".MinBLKRate -and ($_.BLK -lt $Session.Config.Coins."$($_.CoinSymbol)".MinBLKRate))
                )
            )
        )
    })
    Remove-Variable "Test_Algorithm"
    Remove-Variable "Test_ExcludeAlgorithm"
    Remove-Variable "Test_CoinSymbol"
    Remove-Variable "Test_ExcludeCoinSymbol"

    $AllPools_BeforeWD_Count = $NewPools.Count

    $API.AllPools   = $NewPools
    $API.Algorithms = @($NewPools.Algorithm | Sort-Object -Unique) 

    #Setup and reset Watchdog
    $WDIntervalTime = $Session.Timer.AddSeconds( - $Session.WatchdogInterval)
    $WDResetTime    = $Session.Timer.AddSeconds( - $Session.WatchdogReset)

    if ($Session.WatchdogReset -gt $Session.WatchdogInterval) {
        $WDRemoveTimers = $Global:WatchdogTimers.Where({$_.Kicked -le $WDResetTime})
        if ($WDRemoveTimers.Count) {
            $Global:WatchdogTimers = @($Global:WatchdogTimers | Where-Object {$_ -notin $WDRemoveTimers})
        }
        Remove-Variable "WDRemoveTimers"
    }

    #Apply watchdog to pools, only if there is more than one pool selected
    if (($NewPools.Name | Select-Object -Unique | Measure-Object).Count -gt 1) {
        $NewPools = $NewPools.Where({-not $_.Disabled}).Where({
            $Pool = $_
            $Pool_WatchdogTimers = $Global:WatchdogTimers.Where({($_.PoolName -eq $Pool.Name) -and ($_.Kicked -lt $WDIntervalTime) -and ($_.Kicked -gt $WDResetTime)})
            $Pool.Exclusive -or ($Pool_WatchdogTimers.Count -lt <#stage#>3 -and $Pool_WatchdogTimers.Where({$Pool.Algorithm -contains $_.Algorithm}).Count -lt <#statge#>2)
        })
    }
    if ($Pool_WatchdogTimers -ne $null) {Remove-Variable "Pool_WatchdogTimers"}

    #Update the active pools
    $Pools = [PSCustomObject]@{}
    
    if ($NewPools.Count -gt 0) {

        $Pools_WTM = $NewPools | Where-Object {$_.WTM}
        if (($Pools_WTM | Measure-Object).Count) {
            if ($Session.RoundCounter -eq 0) {Write-Host ".. loading WhatToMine " -NoNewline}
            $start = Get-UnixTimestamp -Milliseconds
            Get-PoolsContent "WhatToMine" -Parameters @{Pools = $Pools_WTM; StatSpan = $RoundSpan; InfoOnly = $false; StatAverage = $UserConfig.Pools.WhatToMine.StatAverage; StatAverageStable = $UserConfig.Pools.WhatToMine.StatAverageStable} | Foreach-Object {
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
            Remove-Variable "Pools_WTM"
        }

        #Decrease compare prices, if out of sync window
        # \frac{\left(\frac{\ln\left(60-x\right)}{\ln\left(50\right)}+1\right)}{2}
        $OutOfSyncTimer    = ($NewPools | Select-Object -ExpandProperty Updated | Measure-Object -Maximum).Maximum
        $OutOfSyncTime     = $OutOfSyncTimer.AddMinutes(-$Session.OutofsyncWindow)
        $OutOfSyncDivisor  = [Math]::Log($Session.OutofsyncWindow-$Session.SyncWindow) #precalc for sync decay method
        $OutOfSyncLimit    = 1/($Session.OutofsyncWindow-$Session.SyncWindow)

        $PoolSwitchingHysteresis = 1 + $Session.Config.PoolSwitchingHysteresis/100
        $PoolAccuracyWeight      = $Session.Config.PoolAccuracyWeight/100
        $HashrateWeightStrength  = $Session.Config.HashrateWeightStrength/100
        $HashrateWeight          = $Session.Config.HashrateWeight/100

        $Pools_Hashrates   = @{}
        $Pools_Running     = @{}
        $Pools_Benchmarking= @{}
        $Pools_PriceCmp    = @{}

        $NewPools | Select-Object Algorithm0,CoinSymbol,Hashrate,StablePrice | Group-Object -Property {"$($_.Algorithm0)-$($_.CoinSymbol)"} | Foreach-Object {$Pools_Hashrates[$_.Name] = ($_.Group | Where-Object StablePrice | Select-Object -ExpandProperty Hashrate | Measure-Object -Maximum).Maximum;if (-not $Pools_Hashrates[$_.Name]) {$Pools_Hashrates[$_.Name]=1}}
        $NewPools | Where-Object {-not $_.SoloMining -and $_.TSL -ne $null -and $Session.Config.Pools."$($_.Name)".EnablePostBlockMining -and $_.CoinSymbol -and ($_.TSL -lt $Session.Config.Coins."$($_.CoinSymbol)".PostBlockMining)} | Foreach-Object {$_ | Add-Member PostBlockMining $true -Force}

        $Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running}).ForEach({
            for($i=0;$i -lt $_.Pool.Count;$i++) {
                $Pool_Ix = "$($_.Pool | Select-Object -Index $i)-$($_.BaseAlgorithm | Select-Object -Index $i)-$($_.CoinSymbol | Select-Object -Index $i)"
                if (-not $Pools_Running.ContainsKey($Pool_Ix) -or $Pools_Running[$Pool_Ix] -gt $_.Rounds) {$Pools_Running[$Pool_Ix] = $_.Rounds}
                $Pools_Benchmarking[$Pool_Ix]=$Pools_Benchmarking[$Pool_Ix] -or $_.NeedsBenchmark
            }
        })

        $Session.DecayFact = [Math]::Min($Session.Config.SwitchingPrevention,1) * [Math]::Pow($Session.DecayBase, [int](($Session.Timer - $Session.DecayStart).TotalSeconds / $Session.DecayPeriod) / ([Math]::Max($Session.Config.SwitchingPrevention,1)))

        Write-Log "Calculating pool compare prices. "
        $NewPools.ForEach({
            $Pool_Ix = "$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"
            if ($Pools_PriceCmp[$Pool_Ix] -eq $null) {
                $Price_Cmp  =  $_."$(if (-not $Session.Config.EnableFastSwitching -and ($Session.Config.ForceStablePrice -or -not $_.PaysLive)) {"Stable"})Price"
                if (-not $_.Exclusive) {
                    $Pool_Rounds = $Pools_Running[$Pool_Ix]
                    if ($Pool_Rounds -ne $null -and ($Session.IsBenchmarkingRun -and $Pools_Benchmarking[$Pool_Ix] -or $Pool_Rounds -lt $Session.Config.MinimumMiningIntervals)) {
                        $Price_Cmp *= 100
                    } elseif (-not $_.PostBlockMining -and $_.CoinSymbol -and $Session.Config.Pools."$($_.Name)".CoinSymbolPBM -icontains $_.CoinSymbol) {
                        $Price_Cmp = 0
                        $_ | Add-Member DisabledDueToCoinSymbolPBM $true -Force
                    } else {
                        $Price_Cmp *= [Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)
                        if (-not ($Session.Config.EnableFastSwitching -or $Session.SkipSwitchingPrevention)) {
                            if ($Pool_Rounds -eq $null) {
                                if ($Session.Config.Pools."$($_.Name)".MaxMarginOfError) {
                                    $Price_Cmp *= 1-([Math]::Floor(([Math]::Min($_.MarginOfError,$Session.Config.Pools."$($_.Name)".MaxMarginOfError/100) * $Session.DecayFact) * 100.00) / 100.00) * $PoolAccuracyWeight
                                }
                            } elseif ($Session.Config.Pools."$($_.Name)".SwitchingHysteresis -ne $null) {
                                $Price_Cmp *= 1+($Session.Config.Pools."$($_.Name)".SwitchingHysteresis/100)
                            } elseif ($Session.Config.PoolSwitchingHystereis -ne 1) {
                                $Price_Cmp *= $PoolSwitchingHysteresis
                            }
                        }
                        if ($_.HashRate -ne $null -and $Session.Config.HashrateWeightStrength) {
                            $Price_Cmp *= 1-(1-[Math]::Pow($_.Hashrate/$Pools_Hashrates["$($_.Algorithm0)-$($_.CoinSymbol)"],$HashrateWeightStrength)) * $HashrateWeight
                        }
                    }
                }
                $Pools_PriceCmp[$Pool_Ix] = $Price_Cmp
            }
        })

        #$(if ($Session.Config.EnableFastSwitching -or $_.PaysLive) {$_.Price} else {$_.StablePrice * (1 - $_.MarginOfError*($Session.Config.PoolAccuracyWeight/100))}) * $(if ($_.Hashrate -eq $null -or -not $Session.Config.HashrateWeightStrength) {1} else {1-(1-[Math]::Pow($_.Hashrate/$Pools_Hashrates["$($_.Algorithm)$($_.CoinSymbol)"],$Session.Config.HashrateWeightStrength/100))*$Session.Config.HashrateWeight/100}) * ([Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1))

        Write-Log "Selecting best pool for each algorithm. "
        $SortedPools = @($NewPools | Sort-Object -Descending {$_.Exclusive -and -not $_.Idle}, {$Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and $Session.Config.Pools."$($_.Name)".FocusWallet -icontains $_.Currency}, {$LockMiners -and $Session.LockMiners.Pools -icontains "$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"}, {$_.PostBlockMining}, {$Pools_PriceCmp["$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"]}, {$_.Region -eq $Session.Config.Region}, {$ix = $Session.Config.DefaultPoolRegion.IndexOf($_.Region);[int]($ix -ge 0)*(100-$ix)}, {$_.SSL -eq $Session.Config.Pools."$($_.Name)".SSL})
        foreach($Algorithm_Name in @($NewPools.ForEach({$_.Algorithm.ToLower()}) | Select-Object -Unique)) {
            $SortedPools.Where({$_.Algorithm -eq $Algorithm_Name -and -not $_.DisabledDueToCoinSymbolPBM},'First').ForEach({$Pools | Add-Member $Algorithm_Name $_})
        }
        if ($SortedPools -ne $null) {Remove-Variable "SortedPools"}

        #$NewPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($NewPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending {$_.Exclusive -and -not $_.Idle}, {$Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and $Session.Config.Pools."$($_.Name)".FocusWallet -icontains $_.Currency}, {$LockMiners -and $Session.LockMiners.Pools -icontains "$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"}, {$_.PostBlockMining}, {-not $_.PostBlockMining -and (-not $_.CoinSymbol -or $Session.Config.Pools."$($_.Name)".CoinSymbolPBM -inotcontains $_.CoinSymbol)}, {$Pools_PriceCmp["$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"]}, {$_.Region -eq $Session.Config.Region}, {[int](($ix = $Session.Config.DefaultPoolRegion.IndexOf($_.Region)) -ge 0)*(100-$ix)}, {$_.SSL -eq $Session.Config.SSL} | Select-Object -First 1)}
        $Pools_OutOfSyncMinutes = ($Pools.PSObject.Properties.Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {$NewPools | Where-Object Name -EQ $_ | Where-Object Updated -ge $OutOfSyncTime | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)
        if ($Pools_OutOfSyncMinutes -gt $Session.SyncWindow) {
            Write-Log "Pool prices are out of sync ($([int]$Pools_OutOfSyncMinutes) minutes). "
        }

        if ($Pools_Hashrates -ne $null) {Remove-Variable "Pools_Hashrates"}
        if ($Pools_Running   -ne $null) {Remove-Variable "Pools_Running"}
        if ($Pools_Benchmarking -ne $null) {Remove-Variable "Pools_Benchmarking"}
        if ($Pools_PriceCmp  -ne $null) {Remove-Variable "Pools_PriceCmp"}

        $Pools.PSObject.Properties.Name | ForEach-Object {
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
            $Pools.$_.Price_Bias = $Pool_Price_Bias
            $Pools.$_.Price_Unbias = $Pool_Price
            $Pools.$_.HasMinerExclusions = $Session.Config.Pools.$Pool_Name.MinerName.Count -or $Session.Config.Pools.$Pool_Name.ExcludeMinerName.Count
        }
    } else {
        $API.AllPools   = $null
        $API.Algorithms = $null
    }

    #Give API access to the pools information
    $API.Pools = @($Pools.PSObject.Properties | Select-Object -ExpandProperty Value)
 
    #Load information about the miners
    Write-Log "Getting miner information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading miner modules .."}

    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Session.Config.MinerName, if specified, and don't match $Session.Config.ExcludeMinerName

    $Miner_DontCheckForUnprofitableCpuAlgos = -not $Global:DeviceCache.DevicesByTypes.CPU -or $Session.Config.DisableUnprofitableCpuAlgolist

    $AllMiner_Warnings = @()
    $AllMiners = @(if (($NewPools | Measure-Object).Count -gt 0 -and (Test-Path "Miners")) {
        Get-MinersContent -Parameters @{Pools = $Pools; InfoOnly = $false} | 
            Where-Object {$_.DeviceName -and ($_.DeviceModel -notmatch '-' -or -not (Compare-Object $_.DeviceName $Global:DeviceCache.DeviceNames."$($_.DeviceModel)"))} | #filter miners for non-present hardware
            Where-Object {$Miner_DontCheckForUnprofitableCpuAlgos -or ($_.DeviceModel -ne "CPU") -or ($_.BaseAlgorithm -notin $UnprofitableCpuAlgos)} |
            Where-Object {-not $Session.Config.DisableDualMining -or $_.HashRates.PSObject.Properties.Name.Count -eq 1} | #filter dual algo miners
            Where-Object {(Compare-Object $Global:DeviceCache.DevicesNames @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} |
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
                $BaseAlgo = $_.BaseAlgorithm -split '-'
                if ($Global:AlgorithmMinerName.Count) {
                    foreach ($p in @($BaseAlgo)) {
                        if (
                                ($Global:AlgorithmMinerName -contains $p) -and (
                                    ($Session.Config.Algorithms.$p.MinerName.Count -and ($Session.Config.Algorithms.$p.MinerName -notcontains $_.BaseName)) -or
                                    ($Session.Config.Algorithms.$p.ExcludeMinerName.Count -and ($Session.Config.Algorithms.$p.ExcludeMinerName -contains $_.BaseName))
                                )
                        ) {
                            $MinerOk = $false
                            break
                        }
                    }
                }
                if ($MinerOk) {
                    foreach ($p in @($_.DeviceModel -split '-')) {
                        if ($Session.Config.Miners."$($_.BaseName)-$($p)-$($_.BaseAlgorithm)".Disable -or 
                            $Session.Config.Devices.$p -and
                            (
                                ($Session.Config.Devices.$p.DisableDualMining -and $_.HashRates.PSObject.Properties.Name.Count -gt 1) -or
                                ($Session.Config.Devices.$p.Algorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.Algorithm $BaseAlgo -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0) -or
                                ($Session.Config.Devices.$p.ExcludeAlgorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.ExcludeAlgorithm $BaseAlgo -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
                                ($Session.Config.Devices.$p.MinerName.Count -gt 0 -and ($Session.Config.Devices.$p.MinerName -inotcontains $_.Basename)) -or
                                ($Session.Config.Devices.$p.ExcludeMinerName.Count -gt 0 -and ($Session.Config.Devices.$p.ExcludeMinerName -icontains $_.Basename))
                            )
                        ) {
                            $MinerOk=$false
                            break
                        }
                    }
                }
                $MinerOk
            }
    })

    #Check if .NET Core Runtime is installed
    $MinersNeedSdk = $AllMiners.Where({$_.DotNetRuntime -and (Compare-Version $_.DotNetRuntime $Session.Config.DotNETRuntimeVersion) -gt 0})
    if ($MinersNeedSdk.Count) {
        $MinersNeedSdk.ForEach({Write-Log -Level Warn "$($_.BaseName) requires .NET Core Runtime (min. version $($_.DotNetRuntime)) to be installed! Find the installer here: https://dotnet.microsoft.com/download"})
        $AllMiners = $AllMiners.Where({$MinersNeedSdk -notcontains $_})
        Start-Sleep 2
    }
    if ($MinersNeedSdk -ne $null) {Remove-Variable "MinersNeedSdk"}

    if ($Session.Config.MiningMode -eq "combo") {
        if ($AllMiners.Where({$_.HashRates.PSObject.Properties.Value -contains $null -and $_.DeviceModel -notmatch '-'})) {
            #Benchmarking is still ongoing - remove device combos from miners and make sure no combo stat is left over
            $AllMiners.Where({$_.HashRates.PSObject.Properties.Value -contains $null -and $_.DeviceModel -notmatch '-'}).ForEach({
                $Miner = $_
                $ComboAlgos = $Miner.HashRates.PSObject.Properties.Name
                $AllMiners.Where({$_.BaseName -eq $Miner.BaseName -and $_.HashRates.PSObject.Properties.Value -notcontains $null -and $_.DeviceModel -match '-' -and $($Miner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($_.DeviceModel -split '-') -icontains $Miner.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0}).ForEach({
                    $Name = $_.Name
                    $ComboAlgos | Foreach-Object {Get-ChildItem ".\Stats\Miners\*-$($Name)_$($_)_HashRate.txt" | Remove-Item -ErrorAction Ignore}
                })
            })
            $AllMiners = $AllMiners.Where({$_.DeviceModel -notmatch '-'})
        } else {
            #Remove device combos, where the parameter-preset is different and there does not exist an own definition
            $AllMiners = $AllMiners.Where({
                $_.DeviceModel -notmatch '-' -or 
                (Get-Member -InputObject $Session.Config.Miners -Name $(@($_.BaseName | Select-Object) + @($_.DeviceModel | Select-Object) + @($_.BaseAlgorithm | Select-Object) -join '-') -MemberType NoteProperty) -or 
                $($Miner = $_; (@($Miner.DeviceModel -split '-') | Foreach-Object {
                    $Miner_ConfigName = @($Miner.BaseName | Select-Object) + @($_ | Select-Object) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
                    if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_ConfigName -MemberType NoteProperty){$Session.Config.Miners.$Miner_ConfigName.Params}
                } | Select-Object -Unique | Measure-Object).Count -le 1)
            })

            #Gather mining statistics for fresh combos
            $AllMiners.Where({$_.HashRates.PSObject.Properties.Value -contains $null -and $_.DeviceModel -match '-'}).ForEach({
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
            })
        }
    }

    if ($ComboAlgos -ne $null) {Remove-Variable "ComboAlgos"}

    #Handle fastlane benchmarks
    if (-not ($Session.RoundCounter % 10) -and $Session.Config.EnableFastlaneBenchmark) {
        $SkipBenchmarksData = [PSCustomObject]@{}
        $SkipBenchmarksCount = 0
        $AllMiners.Where({$_.HashRates.PSObject.Properties.Value -contains $null -and $_.HashRates.PSObject.Properties.Name.Count -eq 1}).ForEach({
            $Miner = $_
            $Miner.DeviceModel -split "-" | Foreach-Object {
                if (-not [bool]$SkipBenchmarksData.PSObject.Properties[$_]) {$SkipBenchmarksData | Add-Member $_ @() -Force}
                if (-not ($SkipBenchmarksData.$_.Where({$_.name -eq $Miner.BaseName -and $_.ver -eq $Miner.Version}) | Measure-Object).Count) {
                    $SkipBenchmarksData.$_ += [PSCustomObject]@{
                        name    = $Miner.BaseName
                        ver     = $Miner.Version
                    }
                    $SkipBenchmarksCount++
                }
            }
        })

        if ($SkipBenchmarksCount) {
            if ($Session.RoundCounter -eq 0) {Write-Host "Downloading fastlane benchmarks .. " -NoNewline}
            $Response = [PSCustomObject]@{}
            $Fastlane_Success = 0
            $Fastlane_Failed  = 0
            try {
                $Request = ConvertTo-Json @($SkipBenchmarksData.PSObject.Properties | Foreach-Object {
                    [PSCustomObject]@{
                        device = "$(if ($_.Name -eq "CPU") {$Global:DeviceCache.DevicesByTypes.CPU.Model_Name | Select-Object -Unique} else {$_.Name})"
                        isgpu  = $_.Name -ne "CPU"
                        type   = if ($_.Name -eq "CPU") {$Session.Config.FastlaneBenchmarkTypeCPU} else {$Session.Config.FastlaneBenchmarkTypeGPU}
                        miners = @($_.Value | Select-Object)
                    }
                } | Select-Object) -Compress -Depth 10

                $Response = Invoke-GetUrl "https://rbminer.net/api/qbench.php" -body @{q=$Request} -timeout 10
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }

            if ($Response.status) {
                $Miner_Models = @{}
                $Global:DeviceCache.Devices.ForEach({$Miner_Models[$_.Name] = $_.Model_Base})

                $AllMiners.Where({$_.HashRates.PSObject.Properties.Value -contains $null -and $_.HashRates.PSObject.Properties.Name.Count -eq 1}).ForEach({
                    $Miner_Name = $_.BaseName
                    $Miner_Algo = "$($_.HashRates.PSObject.Properties.Name -replace '\-.*$')"
                    $Miner_HR   = ($_.DeviceName | Foreach-Object {$Response.data."$($Miner_Models[$_])".$Miner_Name.$Miner_Algo.hr} | Measure-Object -Sum).Sum

                    if (($Miner_HR -gt 0) -or -not $Session.Config.EnableFastlaneBenchmarkMissing) {
                        $_.HashRates."$($_.HashRates.PSObject.Properties.Name)" = $Miner_HR
                        $_.PowerDraw             = ($DeviceName | Foreach-Object {$Response.data."$($Miner_Models[$_])".$Miner_Name.$Miner_Algo.pd} | Measure-Object -Sum).Sum
                        Set-Stat -Name "$($_.Name)_$($Miner_Algo)_HashRate" -Value $Miner_HR -Duration (New-TimeSpan -Seconds 10) -FaultDetection $false -PowerDraw $_.PowerDraw -Sub $Global:DeviceCache.DevicesToVendors[$_.DeviceModel] -Quiet > $null
                    }
                    if ($Miner_HR -gt 0) {$Fastlane_Success++} else {$Fastlane_Failed++}
                })
                Write-Log -Level Info "Fastlane benchmarks: $Fastlane_Success x success, $Fastlane_Failed x failed"
                if ($Session.RoundCounter -eq 0) {Write-Host "ok ($Fastlane_Success x success, $Fastlane_Failed x failed)" -ForegroundColor Green}
            } else {
                Write-Log -Level Info "Failed to get fastlane benchmark results from rbminer.net"
                if ($Session.RoundCounter -eq 0) {Write-Host "failed" -ForegroundColor Red}
            }

            if ($Response -ne $null) {Remove-Variable "Response"}
            if ($Request -ne $null)  {Remove-Variable "Request"}
        }

        Remove-Variable "SkipBenchmarksData"
    }

    if ($Session.RoundCounter -eq 0) {Write-Host "Selecting best miners .."}

    #Remove all miners, that need benchmarks during donation run
    if ($Session.IsDonationRun -or $Session.IsServerDonationRun) {
        $AllMiners = $AllMiners.Where({$_.HashRates.PSObject.Properties.Value -notcontains $null})
    }

    Write-Log "Calculating profit for each miner. "

    $HmF = if ($EnableMiningHeatControl) {3-$MiningHeatControl} else {1.0}

    $MinerFaultToleranceCPU = $Session.Config.MinerFaultToleranceCPU/100
    $MinerFaultToleranceGPU = $Session.Config.MinerFaultToleranceGPU/100
    $MinerPowerPrice        = (100+$Session.Config.PowerOffsetPercent)*24/100000 * $Session.CurrentPowerPriceBTC

    [hashtable]$AllMiners_VersionCheck = @{}
    [hashtable]$AllMiners_VersionDate  = @{}
    [System.Collections.Generic.List[string]]$Miner_Arguments_List = @()
    $AllMiners.ForEach({
        $Miner = $_

        $Miner_AlgoNames = @($Miner.HashRates.PSObject.Properties.Name | Select-Object)

        $Miner_Setup = @{
            Pools         = $(if ($Miner_AlgoNames.Count -eq 1) {[PSCustomObject]@{$Miner_AlgoNames[0] = $Pools.$($Miner_AlgoNames[0])}} else {[PSCustomObject]@{$Miner_AlgoNames[0] = $Pools.$($Miner_AlgoNames[0]);$Miner_AlgoNames[1] = $Pools.$($Miner_AlgoNames[1])}})
            Difficulties  = [hashtable]@{}
            Ratios        = [hashtable]@{}
            OCprofile     = [hashtable]@{}
            Profit        = 0.0
            Profit_Bias   = 0.0
            Profit_Unbias = 0.0
            Profit_Cost   = 0.0
            Profit_Cost_Bias = 0.0
            Disabled      = $false
        }

        if ($Miner.DevFee -eq $null -or $Miner.DevFee -isnot [PSCustomObject]) {$Miner_Setup.DevFee = $(if ($Miner_AlgoNames.Count -eq 1) {[PSCustomObject]@{$Miner_AlgoNames[0] = $Miner.DevFee}} else {[PSCustomObject]@{$Miner_AlgoNames[0] = $Miner.DevFee;$Miner_AlgoNames[1] = 0}})}
        if (-not $Miner.API)            {$Miner_Setup.API = "Miner"}
        if ($Miner.EnvVars -eq $null)   {$Miner_Setup.EnvVars = @()}

        $Miner | Add-Member -NotePropertyMembers $Miner_Setup -Force

        $Miner_Profits        = [hashtable]@{}
        $Miner_Profits_Bias   = [hashtable]@{}
        $Miner_Profits_Unbias = [hashtable]@{}

        $Miner_IsCPU = $Miner.DeviceModel -eq "CPU"

        foreach($p in @($Miner.DeviceModel -split '-')) {$Miner.OCprofile[$p] = ""}

        $Miner_FaultTolerance = if ($Miner_IsCPU) {$MinerFaultToleranceCPU} else {$MinerFaultToleranceGPU}
        $Miner.FaultTolerance = if ($Miner.FaultTolerance) {[Math]::Max($Miner.FaultTolerance,$Miner_FaultTolerance)} else {$Miner_FaultTolerance}

        if ($Session.Config.Miners) {
            $Miner_CommonCommands = $Miner_Arguments = $Miner_Difficulty = ''
            $Miner_MSIAprofile = 0
            $Miner_Penalty = $Miner_ExtendInterval = $Miner_FaultTolerance = $Miner_ShareCheck = -1
            $Miner_CommonCommands_found = $false
            [System.Collections.Generic.List[string]]$Miner_CommonCommands_array = @($Miner.BaseName,$Miner.DeviceModel)
            $Miner_CommonCommands_array.AddRange([System.Collections.Generic.List[string]]@($Miner.BaseAlgorithm -split '-' | Select-Object))
            for($i=$Miner_CommonCommands_array.Count;$i -gt 0; $i--) {
                $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                    if ($Session.Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Session.Config.Miners.$Miner_CommonCommands.Params}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Difficulty -and $Miner_Difficulty -eq '') {$Miner_Difficulty = $Session.Config.Miners.$Miner_CommonCommands.Difficulty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -eq 0) {$Miner_MSIAprofile = [int]$Session.Config.Miners.$Miner_CommonCommands.MSIAprofile}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and $Miner_Penalty -eq -1) {$Miner_Penalty = [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.ShareCheck -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.ShareCheck -ne '' -and $Miner_ShareCheck -eq -1) {$Miner_ShareCheck = [int]$Session.Config.Miners.$Miner_CommonCommands.ShareCheck}
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
                    if ($Session.Config.Miners.$Miner_CommonCommands.ShareCheck -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.ShareCheck -ne '' -and $Session.Config.Miners.$Miner_CommonCommands.ShareCheck -ne $Miner_ShareCheck) {$Miner_ShareCheck = [int]$Session.Config.Miners.$Miner_CommonCommands.ShareCheck}
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
                        if ($p -match "^([-\w]+)(=|\s)?(.*)$") {
                            $pcmd = $matches[1]
                            $pdiv = "$($matches[2])".Trim(); if ($pdiv -eq "") {$pdiv = " "}
                            $parg = $matches[3].Trim()

                            $Current_Miner_Arguments = "$(if ($Miner.Arguments -is [string]) {$Miner.Arguments} else {$Miner.Arguments.Params})"

                            $psub = $Current_Miner_Arguments -replace "$($pcmd)(=|\s)[^-\s][^\s]*\s*"
                            if ($psub -match "$($pcmd)=?(\s+|$)") {
                                $psub = $psub -replace "$($pcmd)=?(\s+|$)"
                            }
                            $psub = $psub -replace "\s+$"

                            if ($psub -ne $Current_Miner_Arguments) {
                                if ($Miner.Arguments -is [string]) {$Miner.Arguments = $psub} else {$Miner.Arguments.Params = $psub}
                            }

                            if ($parg -ne "#") {
                                $Miner_Arguments_List.Add("$($pcmd)$(if ($parg) {"$($pdiv)$($parg)"})")>$null
                            }
                        } else {
                            $Miner_Arguments_List.Add($p)>$null
                        }
                    }
                    $Miner_Arguments = "$(if ($Miner_Arguments_List.Count) {" $($Miner_Arguments_List -join ' ')"})"
                    if ($Miner.Arguments -is [string]) {$Miner.Arguments = "$($Miner.Arguments.Trim())$($Miner_Arguments)"}
                    else {$Miner.Arguments.Params = "$($Miner.Arguments.Params.Trim())$($Miner_Arguments)"}                
                }
            }

            if ($Miner_MSIAprofile -ne 0)     {$Miner | Add-Member -Name MSIAprofile -Value $Miner_MSIAprofile -MemberType NoteProperty -Force}           
            if ($Miner_Penalty -ne -1)        {$Miner.Penalty = $Miner_Penalty}
            if ($Miner_ExtendInterval -ne -1) {$Miner.ExtendInterval = $Miner_ExtendInterval}
            if ($Miner_FaultTolerance -ne -1) {$Miner.FaultTolerance = $Miner_FaultTolerance}
            if ($Miner_ShareCheck -ne -1)     {$Miner | Add-Member -Name ShareCheck -Value $Miner_ShareCheck -MemberType NoteProperty -Force}
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
                $Miner.Difficulties[$_]   = ([Double]$Global:StatsCache.$Miner_Name.Diff_Average)
                $Miner.Ratios[$_]         = ([Double]$Global:StatsCache.$Miner_Name.Ratio_Live)
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
            $Miner.Profit_Cost   = if ($Miner_IsCPU -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)) {0} else {
                [Double]($Miner.PowerDraw*$MinerPowerPrice)
            }
        }

        if (($Session.Config.UsePowerPrice -or (-not $Miner_IsCPU -and $EnableMiningHeatControl -and $Miner.PowerDraw)) -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {
            if ($Session.Config.UsePowerPrice) {
                $Miner.Profit -= $Miner.Profit_Cost
            }
            $Miner.Profit_Cost_Bias = $Miner.Profit_Cost * $HmF
        }

        $Miner.DeviceName = @($Miner.DeviceName | Select-Object -Unique | Sort-Object)

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $AllMiners_VersionCheck.ContainsKey($Miner.BaseName)) {
            $Miner_UriJson = Join-Path (Get-MinerInstPath $Miner.Path) "_uri.json"
            $Miner_Uri = ""
            if ((Test-Path $Miner.Path) -and (Test-Path $Miner_UriJson)) {$Miner_Uri = Get-ContentByStreamReader $Miner_UriJson | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty URI; $AllMiners_VersionDate[$Miner.BaseName] = (Get-ChildItem $Miner_UriJson).LastWriteTimeUtc}
            $AllMiners_VersionCheck[$Miner.BaseName] = $Miner_Uri -eq $Miner.URI            
        }

        if ($Session.Config.EnableAutoBenchmark -and ($Session.Config.MiningMode -eq "legacy" -or $Miner.DeviceModel -notmatch '-') -and $AllMiners_VersionDate[$Miner.BaseName] -ne $null -and $Global:StatsCache.ContainsKey("$($Miner.Name)_$($Miner.BaseAlgorithm -replace '-.*$')_HashRate") -and $Global:StatsCache["$($Miner.Name)_$($Miner.BaseAlgorithm -replace '-.*$')_HashRate"].Updated -lt $AllMiners_VersionDate[$Miner.BaseName]) {
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
        if (-not $Miner.Penalty)        {$Miner.Penalty = 0}
    })

    if ($Miner_CommonCommands_array -ne $null) {Remove-Variable "Miner_CommonCommands_array"}
    if ($Miner_AlgoNames -ne $null) {Remove-Variable "Miner_AlgoNames"}
    if ($Miner_Setup -ne $null) {Remove-Variable "Miner_Setup"}
    if ($Miner_Profits -ne $null) {Remove-Variable "Miner_Profits"}
    if ($Miner_Profits -ne $null) {Remove-Variable "Miner_Profits_Bias"}
    if ($Miner_Profits_Unbias -ne $null) {Remove-Variable "Miner_Profits_Unbias"}
    if ($Miner_Arguments_List -ne $null) {Remove-Variable "Miner_Arguments_List"}

    $Miners_DownloadList    = @()
    $Miners_DownloadListPrq = @()
    $Miners_DownloadMsgPrq  = $null
    $Miners = $AllMiners.Where({(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath)) -and $AllMiners_VersionCheck[$_.BaseName]})
    if ((($AllMiners | Measure-Object).Count -ne ($Miners | Measure-Object).Count) -or $Session.StartDownloader) {

        $Miners_DownloadList = @($AllMiners.Where({$AllMiners_VersionCheck[$_.BaseName] -ne $true}) | Sort-Object {$_.ExtendInterval} -Descending | Select-Object -Unique @{name = "URI"; expression = {$_.URI}}, @{name = "Path"; expression = {$_.Path}}, @{name = "IsMiner"; expression = {$true}})
        if ($Miners_DownloadList.Count -gt 0 -and $Global:Downloader.State -ne "Running") {
            Clear-Host
            Write-Log -Level Info "Starting download of $($Miners_DownloadList.Count) miners."
            if ($Session.RoundCounter -eq 0) {Write-Host "Starting downloader ($($Miners_DownloadList.Count) miners) .."}
            $Global:Downloader = Start-ThreadJob -InitializationScript ([scriptblock]::Create("Set-Location `"$((Get-Location).Path -replace '"','``"')`"")) -ArgumentList ($Miners_DownloadList) -FilePath .\Scripts\Downloader.ps1
        }

        $Miners_DownloadListPrq = @($AllMiners.Where({$_.PrerequisitePath}) | Select-Object -Unique PrerequisiteURI,PrerequisitePath | Where-Object {-not (Test-Path "$($_.PrerequisitePath)")} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "IsMiner"; expression = {$false}})
        if ($Miners_DownloadListPrq.Count -gt 0 -and $Miners_DownloadList.Count -eq 0) {
            $Miners_DownloadMsgPrq = @($AllMiners.Where({$_.PrerequisitePath -and $_.PrerequisiteMsg}).Where({-not (Test-Path $_.PrerequisitePath)}) | Select-Object -Unique PrerequisiteMsg | Foreach-Object {$_.PrerequisiteMsg})
            if ($Global:Downloader.State -ne "Running" -and $Global:DownloaderPrq.State -ne "Running") {
                Write-Log -Level Info "Starting download of $($Miners_DownloadListPrq.Count) pre-requisites."
                if ($Session.RoundCounter -eq 0) {Write-Host "Starting downloader ($($Miners_DownloadListPrq.Count) pre-requisites) .."}
                $Global:DownloaderPrq = Start-ThreadJob -InitializationScript ([scriptblock]::Create("Set-Location `"$((Get-Location).Path -replace '"','``"')`"")) -ArgumentList ($Miners_DownloadListPrq) -FilePath .\Scripts\Downloader.ps1
            }
        }

        $Session.StartDownloader = $false
    }
    $API.DownloadList      = $Miners_DownloadList + $Miners_DownloadListPrq
    $Miners_Downloading    = $Miners_DownloadList.Count
    $Miners_DownloadingPrq = $Miners_DownloadListPrq.Count
    if ($AllMiners_VersionCheck -ne $null) {Remove-Variable "AllMiners_VersionCheck"}
    if ($AllMiners_VersionDate -ne $null) {Remove-Variable "AllMiners_VersionDate"}
    if ($Miners_DownloadList -ne $null) {Remove-Variable "Miners_DownloadList"}
    if ($Disabled -ne $null) {Remove-Variable "Disabled"}
    #$Global:StatsCache = $null

    #Open firewall ports for all miners
    try {
        if ($IsWindows -and (Get-Command "Get-MpPreference" -ErrorAction Ignore)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction Ignore) {
                if ($Global:MinerFirewalls -eq $null) {$Global:MinerFirewalls = Get-NetFirewallApplicationFilter | Where-Object {$_.Program -like "$(Get-Location)\Bin\*"} | Select-Object -ExpandProperty Program}
                $OpenFirewallFor = "$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($Global:MinerFirewalls | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Depth 10 -Compress)"
                if ($OpenFirewallFor -ne "") {
                    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'$(if ($Session.IsCore) {" -SkipEditionCheck"}); ('$OpenFirewallFor' | ConvertFrom-Json -ErrorAction Ignore) | ForEach {New-NetFirewallRule -DisplayName 'RainbowMiner' -Program `$_}" -replace '"', '\"') -Verb runAs -WindowStyle Hidden
                    $Global:MinerFirewalls = $null
                    Remove-Variable "OpenFirewallFor"
                }
            }
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
    if ($AllMiners -ne $null) {Remove-Variable "AllMiners"}

    #Remove miners with developer fee
    if ($Session.Config.ExcludeMinersWithFee) {$Miners = $Miners.Where({($_.DevFee.PSObject.Properties.Value | Foreach-Object {[Double]$_} | Measure-Object -Sum).Sum -eq 0})}

    $Miners_BeforeWD_Count = ($Miners | Measure-Object).Count

    #Store miners to file
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and -not $Session.Benchmarking -and (-not $Session.Updatetracker.MinerSave -or $Session.Updatetracker.MinerSave -lt (Get-Date).AddHours(-6) -or -not (Test-Path ".\Data\minerdata.json"))) {
        $Session.Updatetracker.MinerSave = Get-Date
        Set-ContentJson ".\Data\minerdata.json" ([PSCustomObject]@{Miners = @($Miners.Where({$_.BaseAlgorithm -notmatch "\-"}) | Select-Object @{Name="Name";Expression={$_.BaseName}}, Version, @{Name="Algorithm";Expression={$_.BaseAlgorithm -replace '-.*$'}}, @{Name="DeviceName";Expression={$_.DeviceName -join '-'}}, DeviceModel, @{Name="HashRate"; Expression={$_.HashRates.PSObject.Properties.Value | Select-Object -First 1}}, PowerDraw, @{Name="OCProfile"; Expression={if ($Session.Config.EnableOCProfiles -and $_.DeviceModel -ne "CPU" -and $_.DeviceModel -notmatch '-') {$_.OCprofile.Values | Select-Object -First 1} else {""}}} -Unique); OCprofiles=$Session.Config.OCprofiles; CPU=$Global:DeviceCache.DevicesByTypes.CPU.Model_Name | Select-Object -Unique}) -Compress > $null
        $Session.ReportMinerData = $true
    }

    #Apply watchdog to miners
    $Miners = $Miners.Where({
        $Miner = $_
        $Miner_WatchdogTimers = $Global:WatchdogTimers.Where({$_.MinerName -eq $Miner.Name -and $_.Kicked -lt $WDIntervalTime -and $_.Kicked -gt $WDResetTime})
        $Miner_WatchdogTimers.Count -lt <#stage#>2 -and $Miner_WatchdogTimers.Where({$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm}).Count -lt <#stage#>1 -and ($Session.Config.DisableDualMining -or $Miner.HashRates.PSObject.Properties.Name.Count -eq 1 -or -not $Miner.Pools.PSObject.Properties.Value.Where({$_.Exclusive}).Count)
    })
    if ($Miner_WatchdogTimers -ne $null) {Remove-Variable "Miner_WatchdogTimers"}

    #Give API access to the miners information
    $API.Miners = $Miners

    #Remove all failed and disabled miners
    $Miners = $Miners.Where({-not $_.Disabled -and $_.HashRates.PSObject.Properties.Value -notcontains 0})

    #Reset the active miners
    $Global:ActiveMiners.ForEach({
        $_.Profit = 0
        $_.Profit_Bias = 0
        $_.Profit_Unbias = 0
        $_.Profit_Cost = 0
        $_.Profit_Cost_Bias = 0
        $_.Best = $false
        $_.Stopped = $false
        $_.Enabled = $false
        $_.IsFocusWalletMiner = $false
        $_.IsExclusiveMiner = $false
        $_.IsLocked = $false
        $_.PostBlockMining = 0
        $_.IsRunningFirstRounds = $_.Status -eq [MinerStatus]::Running -and $_.Rounds -lt $Session.Config.MinimumMiningIntervals -and -not $Session.IsBenchmarkingRun
    })

    #If either SkipSwitchingPrevention or EnableFastSwitching is set, simply ignore ErrorMargins
    if ($Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching) {
        $Miners.Foreach({$_.Profit_Bias = $_.Profit_Unbias})
    }

    #Don't penalize active miners and apply switching hysteresis, also make sure FirstRounds is respected 
    $MinerSwitchingHysteresis = 1 + $Session.Config.MinerSwitchingHysteresis/100
    $Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running}).ForEach({
        $Miner = $_
        $Miners.Where({
                $_.Name -eq $Miner.Name -and
                $_.Path -eq $Miner.Path -and
                $_.Arguments -eq $Miner.Arguments -and
                $_.API -eq $Miner.API -and
                (Compare-Object $Miner.Algorithm ($_.HashRates.PSObject.Properties.Name | Select-Object) | Measure-Object).Count -eq 0
            },'First').Foreach({
                $_.Profit_Bias = $_.Profit_Unbias * $MinerSwitchingHysteresis
                if ($Miner.IsRunningFirstRounds) {$_.Profit_Bias *= 100}
            })
    })

    #Apply preferred miner margin
    if (($Session.Config.PreferMinerName | Measure-Object).Count -and $Session.Config.PreferMinerMargin) {
        $PreferMinerMargin = 1 - $Session.Config.PreferMinerMargin/100
        $Miners.Where({$Session.Config.PreferMinerName -notcontains $_.BaseName}).Foreach({
            $_.Profit_Bias *= $PreferMinerMargin
        })
    }

    #Use only fastest miner per algo and device index, if one miner handles multiple intensities, all intensity instances of the fastest miner will be used
    if ($Session.Config.FastestMinerOnly) {
        $Miners = @($Miners | Sort-Object -Descending {"$($_.DeviceName -join '')$($_.BaseAlgorithm -replace '-')$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {[double]$_.Profit_Bias - $_.Profit_Cost_Bias}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm -replace '-')$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"} | Foreach-Object {
            if ($_.Group.Count -eq 1) {$_.Group[0]}
            else {
                $BaseName = $_.Group[0].BaseName 
                $_.Group | Where-Object {$_.BaseName -eq $BaseName}
            }
        }).Where({$_})
    }
 
    #Give API access to the fasted miners information
    $API.FastestMiners = $Miners

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used
    $MinersNeedingBenchmark = $Miners.Where({$_.HashRates.PSObject.Properties.Value -contains $null})
    $MinersNeedingBenchmarkCount = ($MinersNeedingBenchmark | Measure-Object).Count
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark

    #Update the active miners
    $Miners.ForEach({
        $Miner = $_
        $ActiveMiner = $Global:ActiveMiners.Where({
            $_.Name -eq $Miner.Name -and
            $_.Path -eq $Miner.Path -and
            $_.Arguments -eq $Miner.Arguments -and
            $_.API -eq $Miner.API -and
            (Compare-Object $_.Algorithm ($Miner.HashRates.PSObject.Properties.Name | Select-Object) | Measure-Object).Count -eq 0
        },'First')

        $FirstAlgoName            = "$($Miner.HashRates.PSObject.Properties.Name | Select-Object -First 1)"

        $Miner_MinSamples         = if ($Miner.MinSamples) {$Miner.MinSamples} else {3} #min. 10 seconds, 3 samples needed
        $Miner_IsLocked           = ($LockMiners -and $Session.LockMiners.Pools -and -not (Compare-Object $Session.LockMiners.Pools @($Miner.Pools.PSObject.Properties.Name | Foreach-Object {"$($Miner.Pools.$_.Name)-$($Miner.Pools.$_.Algorithm0)-$($Miner.Pools.$_.CoinSymbol)"} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>"))
        $Miner_IsFocusWalletMiner = $false
        $Miner_IsExclusiveMiner   = $false
        $Miner.Pools.PSObject.Properties.Value | Foreach-Object {
            $Miner_IsFocusWalletMiner = $Miner_IsFocusWalletMiner -or ($Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and (Compare-Object $Session.Config.Pools."$($_.Name)".FocusWallet $_.Currency -IncludeEqual -ExcludeDifferent))
            $Miner_IsExclusiveMiner   = $Miner_IsExclusiveMiner -or $_.Exclusive
        }

        $Miner_CoinSymbol         = $Miner.Pools.$FirstAlgoName.CoinSymbol
        $Miner_PostBlockMining    = if (-not $Miner.Pools.$FirstAlgoName.SoloMining -and $Miner.Pools.$FirstAlgoName.TSL -ne $null -and $Session.Config.Pools."$($Miner.Pools.$FirstAlgoName.Name)".EnablePostBlockMining -and $Miner_CoinSymbol -and $Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining -and ($Miner.Pools.$FirstAlgoName.TSL -lt $Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining)) {$Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining - $Miner.Pools.$FirstAlgoName.TSL} else {0}

        $Miner_ManualUri          = if (-not $Miner.ManualUri -and $Miner.Uri -notmatch "RainbowMiner" -and $Miner.Uri -match "^(.+?github.com/.+?/releases)") {$Matches[1]} else {$Miner.ManualUri}

        $Miner_MaxRejectedShareRatio = [Double]$(if ($Miner.MaxRejectedShareRatio -eq $null) {$Session.Config.MaxRejectedShareRatio} else {$Miner.MaxRejectedShareRatio})
        if ($Miner_MaxRejectedShareRatio -lt 0) {$Miner_MaxRejectedShareRatio = 0}
        elseif ($Miner_MaxRejectedShareRatio -gt 1) {$Miner_MaxRejectedShareRatio = 1}

        if ($ActiveMiner.Count) {
            $ActiveMiner = $ActiveMiner[0]
            $ActiveMiner.Version            = $Miner.Version
            $ActiveMiner.Profit             = $Miner.Profit
            $ActiveMiner.Profit_Bias        = $Miner.Profit_Bias
            $ActiveMiner.Profit_Unbias      = $Miner.Profit_Unbias
            $ActiveMiner.Profit_Cost        = $Miner.Profit_Cost
            $ActiveMiner.Profit_Cost_Bias   = $Miner.Profit_Cost_Bias
            $ActiveMiner.PowerDraw          = $Miner.PowerDraw
            $ActiveMiner.Speed              = $Miner.HashRates.PSObject.Properties.Value
            #$ActiveMiner.DeviceName         = $Miner.DeviceName
            #$ActiveMiner.DeviceModel        = $Miner.DeviceModel
            $ActiveMiner.ShowMinerWindow    = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow -or $IsLinux)
            $ActiveMiner.MSIAprofile        = $Miner.MSIAprofile
            $ActiveMiner.DevFee             = $Miner.DevFee
            $ActiveMiner.OCprofile          = $Miner.OCprofile
            $ActiveMiner.EnableOCprofile    = $Session.Config.EnableOCProfiles
            $ActiveMiner.FaultTolerance     = $Miner.FaultTolerance
            $ActiveMiner.Penalty            = $Miner.Penalty
            $ActiveMiner.ManualUri          = "$Miner_ManualUri"
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
            $ActiveMiner.PoolPenalty        = $Miner.Pools.PSObject.Properties.Value.Penalty
            $ActiveMiner.NoCPUMining        = [bool]$Miner.NoCPUMining
            $ActiveMiner.NeedsBenchmark     = $Miner.HashRates.PSObject.Properties.Value -contains $null
            $ActiveMiner.MaxRejectedShareRatio = $Miner_MaxRejectedShareRatio
            $ActiveMiner.MiningPriority     = $Miner.MiningPriority
            $ActiveMiner.MiningAffinity     = $Miner.MiningAffinity
            $ActiveMiner.MultiProcess       = [int]$Miner.MultiProcess
            $ActiveMiner.SetLDLIBRARYPATH   = $Miner.SetLDLIBRARYPATH -eq $null -or $Miner.SetLDLIBRARYPATH
            $ActiveMiner.ShareCheck         = [int]$Miner.ShareCheck

            #$Miner.HashRates.PSObject.Properties.Name | Foreach-Object {
            #    $ActiveMiner.DevFee.$_ = $Miner.DevFee.$_
            #}
            #$Miner.OCprofile.Keys | Foreach-Object {$ActiveMiner.OCprofile[$_] = $Miner.OCprofile[$_]}
        }
        else {
            Write-Log -Level Info "New miner object $($Miner.BaseName): $($Miner.HashRates.PSObject.Properties.Name -join '+')"
            try {
                $ActiveMiner = New-Object $Miner.API -Property @{
                    Name                 = $Miner.Name
                    Version              = $Miner.Version
                    BaseName             = $Miner.BaseName
                    Path                 = $Miner.Path
                    Arguments            = $Miner.Arguments
                    API                  = $Miner.API
                    Port                 = $Miner.Port
                    Algorithm            = $Miner.HashRates.PSObject.Properties.Name
                    BaseAlgorithm        = $Miner.BaseAlgorithm -split '-'
                    Currency             = $Miner.Pools.PSObject.Properties.Value.Currency
                    CoinName             = $Miner.Pools.PSObject.Properties.Value.CoinName
                    CoinSymbol           = $Miner.Pools.PSObject.Properties.Value.CoinSymbol
                    Wallet               = $Miner.Pools.PSObject.Properties.Value.Wallet
                    DeviceName           = $Miner.DeviceName
                    DeviceModel          = $Miner.DeviceModel
                    Profit               = $Miner.Profit
                    Profit_Bias          = $Miner.Profit_Bias
                    Profit_Unbias        = $Miner.Profit_Unbias
                    Profit_Cost          = $Miner.Profit_Cost
                    Profit_Cost_Bias     = $Miner.Profit_Cost_Bias
                    PowerDraw            = $Miner.PowerDraw
                    Speed                = $Miner.HashRates.PSObject.Properties.Value
                    Speed_Live           = @(0.0) * $Miner.HashRates.PSObject.Properties.Name.Count
                    Variance             = @(0.0) * $Miner.Hashrates.PSObject.Properties.Name.Count
                    StartCommand         = $Miner.StartCommand
                    StopCommand          = $Miner.StopCommand
                    Best                 = $false
                    New                  = $false
                    Benchmarked          = 0
                    Pool                 = $Miner.Pools.PSObject.Properties.Value.Name
                    MSIAprofile          = $Miner.MSIAprofile
                    DevFee               = $Miner.DevFee
                    OCprofile            = $Miner.OCprofile
                    EnableOCprofile      = $Session.Config.EnableOCProfiles
                    ExtendInterval       = $Miner.ExtendInterval
                    ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow -or $IsLinux)
                    FaultTolerance       = $Miner.FaultTolerance
                    Penalty              = $Miner.Penalty
                    PoolPenalty          = $Miner.Pools.PSObject.Properties.Value.Penalty
                    ManualUri            = $Miner_ManualUri
                    EthPillEnable        = $Session.Config.EthPillEnable
                    EthPillEnableMTP     = $Session.Config.EthPillEnableMTP
                    DataInterval         = $Session.Config.BenchmarkInterval
                    Donator              = ($Session.IsDonationRun -or $Session.IsServerDonationRun)
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
                    SetLDLIBRARYPATH     = $Miner.SetLDLIBRARYPATH -eq $null -or $Miner.SetLDLIBRARYPATH
                    ShareCheck           = [int]$Miner.ShareCheck
                    ExcludePoolName      = $Miner.ExcludePoolName
                }
                if ($ActiveMiner) {
                    $Global:ActiveMiners.Add($ActiveMiner) > $null
                }
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "Failed to create miner object $($Miner.BaseName): $($Miner.HashRates.PSObject.Properties.Name -join '+')"
            }
            #$Miner.OCprofile.Keys | Foreach-Object {$ActiveMiner.OCprofile[$_] = $Miner.OCprofile[$_]}
        }
    })

    if ($Miner -ne $null)        {Remove-Variable "Miner"}
    if ($ActiveMiner -ne $null)  {Remove-Variable "ActiveMiner"}
    if ($Miner_DevFee -ne $null) {Remove-Variable "Miner_DevFee"}

    $ActiveMiners_DeviceNames = @(($Global:ActiveMiners | Where-Object {$_.Enabled}).DeviceName | Select-Object -Unique | Sort-Object)

    $Global:ActiveMiners.Where({$_.Profit_Cost_Bias -gt 0}).ForEach({$_.Profit_Bias -= $_.Profit_Cost_Bias})

    $Session.Profitable = $true

    $PowerOffset_Watt = [Double]0
    $PowerOffset_Cost = [Double]0

    $MinersRunning = $false

    if (($Miners | Measure-Object).Count -gt 0) {
        
        #Get most profitable miner combination

        $ActiveMiners_Sorted = @($Global:ActiveMiners.Where({$_.Enabled}) | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {$(if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval})}, {$_.Algorithm[0] -eq $_.BaseAlgorithm[0]})

        $BestMiners = @()

        $ActiveMiners_Sorted | Select-Object DeviceName -Unique | ForEach-Object {
            $Miner_GPU = $_
            if ($BestMiner = $ActiveMiners_Sorted.Where({(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0},'First')) {
                $BestMiners += $BestMiner[0]
            }
        }

        #If post block mining: check for minimum profit
        if ($Miners_PBM = $BestMiners.Where({$_.PostBlockMining -gt 0 -and -not $_.IsExclusiveMiner -and -not $_.IsLocked -and -not $_.IsFocusWalletMiner -and -not $_.NeedsBenchmark -and -not $_.IsRunningFirstRounds -and $Session.Config.Coins."$($_.CoinSymbol)".MinProfitPercent -gt 0})) {
            $Miners_PBM_Remove = @()
            $Miners_PBM | Foreach-Object {
                $Miner_PBM = $_
                if ($BestMiner = $ActiveMiners_Sorted.Where({$_.PostBlockMining -eq 0 -and (Compare-Object $Miner_PBM.DeviceName $_.DeviceName | Measure-Object).Count -eq 0},'First')) {
                    $BestMiner = $BestMiner[0]
                }
                $BestMiner_Profit = $BestMiner.Profit + $(if ($Session.Config.UsePowerPrice -and $BestMiner.Profit_Cost -ne $null -and $BestMiner.Profit_Cost -gt 0) {$BestMiner.Profit_Cost})
                $Miner_PBM_Profit = $Miner_PBM.Profit + $(if ($Session.Config.UsePowerPrice -and $Miner_PBM.Profit_Cost -ne $null -and $Miner_PBM.Profit_Cost -gt 0) {$Miner_PBM.Profit_Cost})
                if ($BestMiner -and ($BestMiner_Profit * $Session.Config.Coins."$($Miner_PBM.CoinSymbol)".MinProfitPercent / 100 -gt $Miner_PBM_Profit)) {
                    $BestMiners += $BestMiner
                    $Miners_PBM_Remove += $Miner_PBM
                }
            }
            if ($Miners_PBM_Remove.Count) {
                $BestMiners = @($BestMiners | Where-Object {$_ -notin $Miners_PBM_Remove})
            }

            #Cleanup
            Remove-Variable "Miners_PBM"
            Remove-Variable "Miners_PBM_Remove"
            if ($Miner_PBM  -ne $null) {Remove-Variable "Miner_PBM"}
        }
        

        $NoCPUMining = $Session.Config.EnableCheckMiningConflict -and $MinersNeedingBenchmarkCount -eq 0 -and ($BestMiners | Where-Object DeviceModel -eq "CPU" | Measure-Object).Count -and ($BestMiners | Where-Object NoCPUMining -eq $true | Measure-Object).Count
        if ($NoCPUMining) {
            $BestMiners2 = @()
            $ActiveMiners_Sorted | Select-Object DeviceName -Unique | ForEach-Object {
                $Miner_GPU = $_
                if ($BestMiner = $ActiveMiners_Sorted.Where({-not $_.NoCPUMining -and (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0},'First')) {
                    $BestMiners2 += $BestMiner[0]
                }
            }
        }
        if ($BestMiner  -ne $null) {Remove-Variable "BestMiner"}

        $Check_Profitability = $false
        if ($Session.Config.UsePowerPrice -and $MinersNeedingBenchmarkCount -eq 0) {
            #Remove no longer profitable miners
            if ($Session.Config.CheckProfitability) {
                $BestMiners = @($BestMiners | Where-Object {$_.Profit -gt 0 -or $_.IsExclusiveMiner -or $_.IsLocked})
                if ($BestMiners2) {$BestMiners2 = @($BestMiners2 | Where {$_.Profit -gt 0 -or $_.IsExclusiveMiner -or $_.IsLocked})}
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
        if ($Session.Config.MiningMode -eq "combo" -and $MinersNeedingBenchmarkCount -eq 0 -and ($Global:DeviceCache.DeviceCombos -match '-' | Measure-Object).Count) {
            $BestMiners_Combo = $BestMiners_Combo | Group-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.Algorithm -join '')$($_.Currency)$($_.CoinSymbol)"} | Foreach-Object {
                $Combo_Name    = $_.Name
                $Combo_Devices = @($_.Group.DeviceName | Select-Object -Unique | Sort-Object)
                $BestMiners_Multi = if ($_.Count -gt 1) {
                    @($BestMiners | Where-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.Algorithm -join '')$($_.Currency)$($_.CoinSymbol)" -eq $Combo_Name -and (Compare-Object $_.DeviceName $Combo_Devices | Measure-Object).Count -eq 0} | Sort-Object Profit_Bias -Descending).Where({$_},'First')[0]
                }
                if ($BestMiners_Multi -and (($_.Group.Profit_Bias | Measure-Object -Sum).Sum*$Session.Config.MinComboOverSingleRatio -lt $BestMiners_Multi.Profit_Bias)) {$BestMiners_Multi} else {$_.Group}
            }
        }

        if (($NewPools | Measure-Object).Count -gt 0 -and $Check_Profitability) {
            $PowerOffset_Watt = $Session.Config.PowerOffset
            $PowerOffset_Cost = [Double]($PowerOffset_Watt*24/1000 * $Session.CurrentPowerPriceBTC) + $Session.Config.FixedCostPerDay
            if ((($BestMiners_Combo.Profit | Measure-Object -Sum).Sum - $PowerOffset_Cost) -le 0) {
                if ($Session.Config.CheckProfitability -and ($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner -or $_.IsLocked} | Measure-Object).Count -eq 0) {$Session.Profitable = $false}
                if (-not $Session.Profitable -or -not $Session.Config.CheckProfitability) {
                    Write-Log -Level Warn "No more miners are profitable. $(if ($Session.Config.CheckProfitability) {" Waiting for profitability."})"
                }
            }
        }

        if ($Global:PauseMiners.Test([PauseStatus]::ByScheduler) -and (($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner} | Measure-Object).Count -or $Session.IsExclusiveRun)) {$Global:PauseMiners.Reset([PauseStatus]::ByScheduler)}

        if (-not $Global:PauseMiners.Test() -and -not $Session.AutoUpdate -and $Session.Profitable) {
            $MinersRunning = $true
            $BestMiners_Combo | ForEach-Object {$_.Best = $true}
        }

        #Cleanup
        Remove-Variable "ActiveMiners_Sorted"
        if ($BestMiners -ne $null) {Remove-Variable "BestMiners"}
        if ($BestMiners2 -ne $null) {Remove-Variable "BestMiners2"}
        if ($BestMiners_Combo -ne $null) {Remove-Variable "BestMiners_Combo"}
        if ($BestMiners_Combo2 -ne $null) {Remove-Variable "BestMiners_Combo2"}
    }

    if ($Session.RoundCounter -eq 0) {Write-Host "Starting mining operation .."}

    #Stop failed miners
    $Global:ActiveMiners.ForEach({
        if ($_.GetStatus() -eq [MinerStatus]::RunningFailed) {
            Write-Log -Level Info "Stopping crashed miner ($($_.Name)) "
            $_.CrashCount++
            Write-ActivityLog $_ -Crashed 1
            $_.SetStatus([MinerStatus]::Idle)
        }
    })

    #Stop miners in the active list depending on if they are the most profitable
    $Global:ActiveMiners.Where({(-not $_.Best -or $Session.RestartMiners -or $_.Restart) -and $_.Activated -gt 0 -and $_.Status -eq [MinerStatus]::Running}).ForEach({
        $Miner = $_
        Write-Log -Level Info "Stopping miner $($Miner.Name) on pool $($Miner.Pool -join '/'). "
        $Miner.SetStatus([MinerStatus]::Idle)
        $Miner.Stopped = $true
        $Miner.Restart = $false

        #Remove watchdog timer
        if ($Session.Config.Watchdog -and $Global:WatchdogTimers.Count) {
            $Miner_Name = $Miner.Name
            $Miner_Index = 0
            $Miner.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $Miner_Pool = $Miner.Pool[$Miner_Index]                
                if ($WatchdogTimer = $Global:WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Miner_Pool -and $_.Algorithm -eq $Miner_Algorithm}) {
                    if (($WatchdogTimer.Kicked -lt $WDIntervalTime) -and -not $Session.RestartMiners) {
                        Write-ActivityLog $Miner -Crashed 2
                        $Miner.SetStatus([MinerStatus]::Failed)
                        Write-Log -Level Warn "Miner $Miner_Name mining $($Miner_Algorithm) on pool $($Miner_Pool) temporarily disabled. "
                    }
                    else {
                        $Global:WatchdogTimers = @($Global:WatchdogTimers | Where-Object {$_ -ne $WatchdogTimer})
                    }
                }
                $Miner_Index++
            }
        }
    })

    #Kill maroding miners
    $Running_ProcessIds = @($Global:ActiveMiners | Foreach-Object {$_.GetProcessIds()} | Where-Object {$_} | Select-Object -Unique)
    $Running_MinerPaths = @($Global:ActiveMiners | Foreach-Object {Split-Path -Leaf $_.Path} | Select-Object -Unique)
    if ($IsWindows) {
        @(Get-CIMInstance CIM_Process).Where({$_.ExecutablePath -and $_.ExecutablePath -like "$(Get-Location)\Bin\*" -and $Running_ProcessIds -notcontains $_.ProcessId -and $Running_MinerPaths -icontains $_.ProcessName}) | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore}
    } elseif ($IsLinux) {
        @(Get-Process).Where({$_.Path -and $_.Path -like "$(Get-Location)/Bin/*" -and -not (Compare-Object $Running_ProcessIds @($_.Id,$_.Parent.Id) -ExcludeDifferent -IncludeEqual) -and $Running_MinerPaths -icontains $_.ProcessName}) | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.Id)"; if (Test-OCDaemon) {Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null} else {Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }

    #Kill maroding EthPills
    if ($Session.Config.EthPillEnable -ne "disable") {
        $Running_ProcessIds = $Global:ActiveMiners.Where({$_.EthPillJob}).ForEach({$_.EthPillJob.ProcessId})
        if ($IsWindows) {
            @(Get-CIMInstance CIM_Process).Where({$_.ProcessName -eq "OhGodAnETHlargementPill-r2.exe" -and $Running_ProcessIds -notcontains $_.ProcessId}) | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore}
        } elseif ($IsLinux) {
            @(Get-Process).Where({$_.ProcessName -eq "OhGodAnETHlargementPill-r2" -and -not (Compare-Object $Running_ProcessIds @($_.Id,$_.Parent.Id) -ExcludeDifferent -IncludeEqual)}) | Foreach-Object {Write-Log -Level Warn "Stop-Process $($_.ProcessName) with Id $($_.Id)"; if (Test-OCDaemon) {Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null} else {Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
        }
    }
    Remove-Variable "Running_ProcessIds"
    Remove-Variable "Running_MinerPaths"

    if ($Global:Downloader.HasMoreData) {$Global:Downloader | Receive-Job | Out-Host}
    if ($Global:DownloaderPrq.HasMoreData) {$Global:DownloaderPrq | Receive-Job | Out-Host}
    if ($Session.Config.Delay -gt 0) {Start-Sleep $Session.Config.Delay} #Wait to prevent BSOD

    $Global:ActiveMiners.Where({$_.Best -EQ $true -and $_.Status -ne [MinerStatus]::Running}).ForEach({

        if ($_.DeviceModel -ne "CPU") {
            if ($Session.Config.EnableResetVega) {Reset-Vega $_.DeviceName}

            #Set MSI Afterburner profile
            if ($MSIAenabled) {
                $MSIAplannedprofile = $Global:ActiveMiners.Where({$_.Best -eq $true -and $_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0}).ForEach({$_.MSIAprofile}) | Select-Object -Unique
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
                if ($IsLinux) {Invoke-OCDaemon -Miner $_ -Quiet > $null}
            }

            $_.SetStaticPort($Session.Config.StaticGPUMinerPort)
        } else {
            $_.SetStaticPort($Session.Config.StaticCPUMinerPort)
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
            $_.Algorithm | Where-Object {-not (Compare-Object @($Miner_Name,$_,$Pools.$_.Name) $Session.Config.ExcludeFromWatchdog -IncludeEqual -ExcludeDifferent)} | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $Global:WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if (-not $WatchdogTimer) {
                    $Global:WatchdogTimers += [PSCustomObject]@{
                        MinerName = $Miner_Name
                        DeviceModel= $Miner_DeviceModel
                        PoolName  = $Pools.$Miner_Algorithm.Name
                        Algorithm = $Miner_Algorithm
                        Kicked    = $Session.Timer
                    }
                }
                elseif ($WatchdogTimer.Kicked -le $WDResetTime) {
                    $WatchdogTimer.Kicked = $Session.Timer
                }
            }
        }
    })

    if ($Pools -ne $null) {Remove-Variable "Pools"}

    $IsExclusiveRun = $Session.IsExclusiveRun
    $Session.IsExclusiveRun = $Global:ActiveMiners.Where({$_.IsExclusiveMiner -and $_.Status -eq [MinerStatus]::Running}).Count -gt 0

    #Move donation run into the future, if benchmarks are ongoing
    if ((-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and $MinersNeedingBenchmarkCount -gt 0) -or $Session.IsExclusiveRun) {
        $ShiftDonationRun = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)
        if (-not $Session.LastDonated -or $Session.LastDonated -lt $ShiftDonationRun) {$Session.LastDonated = Set-LastDrun $ShiftDonationRun}
    }

    #Update API miner information
    #$RunningMiners = $Global:ActiveMiners | Where-Object {$_.Status -eq [MinerStatus]::Running} | Foreach-Object {$_ | Add-Member ActiveTime $_.GetActiveTime() -Force -PassThru}
    $API.WatchdogTimers = $Global:WatchdogTimers.Where({$_})
    $API.CrashCounter   = $Global:CrashCounter.Where({$_})
    $API.ActiveMiners   = $Global:ActiveMiners.Where({$_.Profit -or $_.IsFocusWalletMiner})
    $API.RunningMiners  = $Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running})
    $API.FailedMiners   = $Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Failed})

    #
    #Start output to host
    #
    Clear-Host

    if (-not $Session.ConsoleCapture) {
        #Begin capture of the current console output
        Start-Transcript ".\Logs\console.txt" -Force > $null
        $Session.ConsoleCapture = $true
    }

    if ([Math]::Abs($Session.TimeDiff) -gt 60) {
        Write-Host " "
        Write-Log -Level Warn "This rig's system time is off by $($Session.TimeDiff) seconds. Please adjust and restart RainbowMiner!"
        Write-Host " "
    }

    $Session.Benchmarking = -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and $MinersNeedingBenchmarkCount -gt 0
    if ($Session.Benchmarking) {$Session.IsBenchmarkingRun = $true}

    $LimitMiners = if ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) {100} else {3}

    if ($Session.Benchmarking) {$Session.Updatetracker.MinerSave = 0}

    #Display mining information
    $Running = $false
    if (($Global:DeviceCache.Devices | Measure-Object).Count -eq 0) {
        Write-Host " "
        Write-Log -Level Warn "No devices available. Running in pause mode, only. "
        Write-Host " "
    } elseif (($NewPools | Measure-Object).Count -eq 0) {
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
        $Session.ConfigFiles.Keys | Where-Object {-not $Session.ConfigFiles.$_.Healthy} | Foreach-Object {
            Write-Log -Level Warn "Invalid JSON format in $($Session.ConfigFiles.$_.Path)"
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
        $Miner_DeviceTitle = @($Global:DeviceCache.Devices | Where-Object {$Miner_DeviceModels -icontains $_.Model} | Select-Object Model,Model_Name -Unique | Sort-Object -Property Model_Name,Model | Foreach-Object {$Model = $_.Model;"$($_.Model_Name) ($(@($Global:DeviceCache.Devices | Where-Object Model -eq $Model | Select-Object -ExpandProperty Name | Sort-Object) -join ','))"}) -join ', '
        Write-Host $Miner_DeviceTitle
        Write-Host $("=" * $Miner_DeviceTitle.Length)

        [System.Collections.Generic.List[hashtable]]$Miner_Table = @(
            @{Label = "Miner"; Expression = {$_.Name -replace '\-.*$'}},
            @{Label = "Fee"; Expression = {$m = $_;($m.HashRates.PSObject.Properties.Name | ForEach-Object {if ($m.DevFee.$_) {'{0:p2}' -f ($m.DevFee.$_/100) -replace ",*0+\s%"," %"}else {"-"}}) -join ','}; Align = 'right'},
            @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.HashRates.PSObject.Properties.Name}},
            @{Label = "Speed"; Expression = {$_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"} elseif ($Session.Benchmarking) {"Benchmarking"} else {"Waiting"}}}; Align = 'right'},
            @{Label = "Diff"; Expression = {$m = $_;($m.HashRates.PSObject.Properties.Name | ForEach-Object {if ($m.Difficulties.$_) {($m.Difficulties.$_ | ConvertTo-Float) -replace " "} else {"-"}}) -join ','}; Align = 'right'},
            @{Label = "Power$(if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}; Align = 'right'}
        )
        foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Table.Add(@{Label = "$Miner_Currency/Day $($_.Profit)"; Expression = [scriptblock]::Create("if (`$_.Profit -and `"$($Global:Rates.$Miner_Currency)`") {ConvertTo-LocalCurrency `$(`$_.Profit) $($Global:Rates.$Miner_Currency) -Offset 2} else {`"Unknown`"}"); Align = "right"}) > $null
        }
        $Miner_Table.AddRange([System.Collections.Generic.List[hashtable]]@(
            @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}}; Align = 'right'}, 
            @{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.CoinName) {"-$($_.CoinName)"})"}}}
            @{Label = "PoolFee"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.PoolFee) {'{0:p2}' -f ($_.PoolFee/100) -replace ",*0+\s%"," %"}else {"-"}}}; Align = 'right'}
        )) > $null

        $Miners_Count = 0
        $Miners.Where({$_.DeviceModel -eq $Miner_DeviceModel -and ($_.HashRates.PSObject.Properties.Value -gt 0 -or $_.Profit -eq $null)}) | Sort-Object @{Expression = {if ($Session.Benchmarking -and $Session.Config.UIsorting -ne "profit") {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($Session.Benchmarking -or $Session.Config.UIsorting -eq "profit") {$_.Profit}}; Descending = $true}, @{Expression = {if ($Session.Benchmarking -and $Session.Config.UIsorting -eq "profit") {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($Session.IsExclusiveRun -or $Session.IsDonationRun -or $Session.IsServerDonationRun -or $MinersNeedingBenchmarkCount -lt 1) {[double]$_.Profit_Bias}}; Descending = $true} | Where-Object {$Miners_Count -lt [Math]::Min($LimitMiners,5) -or ($Session.Config.UIstyle -ne "full" -and $_.HashRates.PSObject.Properties.Value -gt 0) -or ($_.Profit+$(if ($Session.Config.UsePowerPrice -and $_.Profit_Cost -ne $null -and $_.Profit_Cost -gt 0) {$_.Profit_Cost})) -ge $Miner_ProfitMin -or $_.Profit -eq $null;$Miners_Count++} | Select-Object -First $($LimitMiners) | Format-Table $Miner_Table | Out-Host
    }

    if ($Session.RestartMiners) {
        Write-Host "Miners have been restarted!" -ForegroundColor Yellow
        Write-Host " "
        $Session.RestartMiners = $false
    }
    if ($Global:PauseMiners.Test([PauseStatus]::ByScheduler)) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED BY SCHEDULER" -ForegroundColor Red
        Write-Host " (edit scheduler.config.txt to change)"
        Write-Host " "
    } elseif ($Global:PauseMiners.Test([PauseStatus]::ByActivity)) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED BY ACTIVITY" -ForegroundColor Red
        Write-Host " (edit config.txt to change)"
        Write-Host " "
    } elseif ($Global:PauseMiners.Test([PauseStatus]::ByBattery)) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED BY BATTERY" -ForegroundColor Red
        Write-Host " (edit config.txt to change)"
        Write-Host " "
    } elseif ($Global:PauseMiners.Test()) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED $($Global:PauseMiners.Status -join ",")" -ForegroundColor Red
        Write-Host " (press P to resume)"
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

        if ($Session.Benchmarking -or $Miners_Downloading -gt 0 -or $Miners_DownloadingPrq -gt 0) {Write-Host " "}
        #Display benchmarking progress
        if ($Session.Benchmarking) {
            Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmarkCount) miner$(if ($MinersNeedingBenchmarkCount -gt 1){'s'}) left, interval is set to $($Session.Config.BenchmarkInterval) seconds."
            $MinersNeedingBenchmarkWithEI = ($MinersNeedingBenchmark | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Measure-Object).Count
            if (-not $Session.Config.DisableExtendInterval -and $MinersNeedingBenchmarkWithEI -gt 0) {
                $BenchmarkMinutes = [Math]::Ceiling($Session.Config.BenchmarkInterval/60)
                Write-Host " "
                Write-Host "Please be patient!" -BackgroundColor Yellow -ForegroundColor Black
                Write-Host "RainbowMiner will benchmark the following $($MinersNeedingBenchmarkWithEI) miner$(if ($MinersNeedingBenchmarkWithEI -gt 1){'s'}) with extended intervals!" -ForegroundColor Yellow
                Write-Host "These algorithms need a longer time to reach an accurate average hashrate." -ForegroundColor Yellow
                Write-Host "After that, benchmarking will be much faster ($($BenchmarkMinutes)-$($BenchmarkMinutes*2) minutes per miner)." -ForegroundColor Yellow
                Write-Host "If you do not want that accuracy, set DisableExtendInterval to 0 in your config.txt." -ForegroundColor Yellow
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
            Write-Log -Level Warn "Download in progress: $($Miners_Downloading) miner$(if($Miners_Downloading -gt 1){"s"}) left. Command windows might popup during extraction."
        }
        if ($Miners_DownloadingPrq -gt 0) {
            Write-Log -Level Warn "Download in progress: $($Miners_DownloadingPrq) mining pre-requisite$(if($Miners_DownloadingPrq -gt 1){"s"}) left."
            if ($Miners_DownloadMsgPrq) {
                $Miners_DownloadMsgPrq | Foreach-Object {
                    Write-Log -Level Warn "-> $($_)"
                }
            }
        }
        if ($NoCPUMining) {
            Write-Log -Level Warn $BestMiners_Message
        }
    }

    #Display active miners list
    $Global:ActiveMiners.Where({$_.Activated -gt 0 -and ($_.Status -eq [MinerStatus]::Running -or (-not $_.Donator -and ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) -and ($_.GetActiveLast() -gt (Get-Date).AddSeconds(-5*$Session.Config.Interval))))}) | Sort-Object -Property @{Expression = {$_.Status}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.Status}} -Wrap (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd}d/{0:hh}h/{0:mm}m" -f $_.GetActiveTime()}}, 
        @{Label = "Started"; Expression = {Switch ($_.Activated) {0 {"Never";Break} 1 {"Once";Break} Default {"$_ Times"}}}},      
        @{Label = "Miner"; Expression = {"$($_.Name -replace '\-.*$')$(if ($_.IsFocusWalletMiner -or $_.IsExclusiveMiner) {"(!)"} elseif ($_.PostBlockMining -gt 0) {"($($_.PostBlockMining)s)"} elseif ($Session.Config.MinimumMiningIntervals -gt 1 -and $MinersNeedingBenchmarkCount -eq 0 -and ($_.IsRunningFirstRounds -or ($_.Rounds -eq 0 -and $_.Status -eq [MinerStatus]::Running))) {"($($_.Rounds+1)/$($Session.Config.MinimumMiningIntervals))"})"}},
        @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.BaseAlgorithm}},
        @{Label = "Coin"; Expression = {$_.CoinName | Foreach-Object {if ($_) {$_} else {"-"}}}},
        @{Label = "Device"; Expression = {@(Get-DeviceModelName $Global:DeviceCache.Devices -Name @($_.DeviceName) -Short) -join ','}},
        @{Label = "Power$(if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}},
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.GetArguments())"}}
    ) | Out-Host

    if ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) {
        #Display watchdog timers
        $Global:WatchdogTimers.Where({$_.Kicked -gt $Session.Timer.AddSeconds( - $Session.WatchdogReset)}) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName -replace '\-.*$'}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Global:DeviceCache.Devices -Name @($_.DeviceName) -Short) -join ','}}, 
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
        [System.Collections.Generic.List[hashtable]]$ColumnFormat = @()
        $ColumnFormat.Add(@{Name = "Name"; Expression = {if ($_.Name -match "^\*") {$ColumnMark -replace "{value}","$($_.Name)"} else {$_.Name}}}) > $null
        if (($BalancesData.Currency | Select-Object -Unique | Measure-Object).Count -gt 1) {
            $ColumnFormat.Add(@{Name = "Sym"; Expression = {if ($_.BaseName -ne "Wallet" -and $_.Currency -and (-not $Session.Config.Pools."$($_.Name)".AECurrency -or $Session.Config.Pools."$($_.Name)".AECurrency -eq $_.Currency)) {$ColumnMark -replace "{value}","$($_.Currency)"} else {$_.Currency}}}) > $null
            $ColumnFormat.Add(@{Name = "Balance"; Expression = {$_."Balance ($($_.Currency))"}}) > $null
            $ColumnFormat.Add(@{Name = "Pending"; Expression = {if ($_.Pending) {$_."Pending ($($_.Currency))"} else {"-"}}}) > $null
        }
        $BalancesData | Foreach-Object {$_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name} | Where-Object {$_ -like "Value in *"} | Sort-Object -Unique | Foreach-Object {$Value = $_;$ColumnFormat.Add(@{Name = "$($Value -replace "Value in\s+")"; Expression = [ScriptBlock]::Create("`$(if (`$_.Name -match `"^\*`") {`$ColumnMark -replace `"{value}`",`$_.`"$Value`"} else {`$_.`"$Value`"})"); Align = "right"}) > $null}
        $BalancesData | Format-Table -Wrap -Property $ColumnFormat | Out-Host
        if ($ColumnFormat -ne $null) {Remove-Variable "ColumnFormat"}
        if ($BalancesData -ne $null) {Remove-Variable "BalancesData"}
    }

    #Get worker specific profits without cost

    $CurrentProfitTotal = $CurrentProfitWithoutCostTotal = ($Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running}).Profit | Measure-Object -Sum).Sum
    if ($Session.Config.UsePowerPrice) {$CurrentProfitTotal -= $PowerOffset_Cost + $Session.Config.FixedCostPerDay;$CurrentProfitWithoutCostTotal += ($Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running}).Profit_Cost | Measure-Object -Sum).Sum}

    #Display exchange rates
    [System.Collections.Generic.List[string]]$StatusLine = @()
    foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Currency_Out = $Miner_Currency
            $CurrentProfitTotal_Out = $CurrentProfitTotal
            $CurrentProfitWithoutCostTotal_Out = $CurrentProfitWithoutCostTotal
            $CurrentProfit_Offset = 2
            if ($Miner_Currency -eq "BTC" -and $CurrentProfitWithoutCostTotal -ne 0) {
                switch ([math]::truncate([math]::log([math]::Abs($CurrentProfitWithoutCostTotal), 1000))) {
                    -1 {$Miner_Currency_Out = "mBTC";$CurrentProfitTotal_Out*=1e3;$CurrentProfitWithoutCostTotal_Out*=1e3;$CurrentProfit_Offset = 5;Break}
                    -2 {$Miner_Currency_Out = "µBTC";$CurrentProfitTotal_Out*=1e6;$CurrentProfitWithoutCostTotal_Out*=1e6;$CurrentProfit_Offset = 8;Break}
                    -3 {$Miner_Currency_Out = "sat"; $CurrentProfitTotal_Out*=1e8;$CurrentProfitWithoutCostTotal_Out*=1e8;$CurrentProfit_Offset = 10;Break}
                }
            }
            if ($Global:Rates.$Miner_Currency) {$StatusLine.Add("$(ConvertTo-LocalCurrency $CurrentProfitTotal_Out $($Global:Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)$(if ($Session.Config.UsePowerPrice) {"/$(ConvertTo-LocalCurrency $CurrentProfitWithoutCostTotal_Out $($Global:Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)"}) $Miner_Currency_Out/Day") > $null}
    }
    if ($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $Global:Rates.$_}) {$StatusLine.Add("1 BTC = $(($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $Global:Rates.$_} | Sort-Object | ForEach-Object { "$($_) $($Global:Rates.$_)"})  -join ' = ')") > $null}

    $API.CurrentProfit = $CurrentProfitTotal
    $API.CurrentPower = [PSCustomObject]@{
        CPU = [Math]::Round(($Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running -and $_.DeviceModel -eq "CPU"}).PowerDraw | Measure-Object -Sum).Sum,2)
        GPU = [Math]::Round(($Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running -and $_.DeviceModel -ne "CPU"}).PowerDraw | Measure-Object -Sum).Sum,2)
        Offset = 0
    }
    $API.CurrentPower.Offset = [Math]::Round(($API.CurrentPower.CPU + $API.CurrentPower.GPU) * ($Session.Config.PowerOffsetPercent/100) + $Session.Config.PowerOffset,2)

    if ($Session.Config.UsePowerPrice) {$StatusLine.Add("E-Price = $($Session.Config.PowerPriceCurrency) $([Math]::Round($Session.CurrentPowerPrice,3))") > $null}

    Write-Host " [$(Get-Date)] Profit = $($StatusLine -join ' | ') " -BackgroundColor White -ForegroundColor Black
    Write-Host " "
    if ($StatusLine -ne $null) {Remove-Variable "StatusLine"}

    #Check if server is up
    if ($UserConfig.RunMode -eq "Client" -and $UserConfig.ServerName -and $UserConfig.ServerPort) {
        $ServerConnected = Test-TcpServer $UserConfig.ServerName -Port $UserConfig.ServerPort -Timeout 2
        if ($ServerConnected) {            
            Write-Host "[Client-Mode] Connected to $($UserConfig.ServerName):$($UserConfig.ServerPort)" -ForegroundColor Green
        } else {
            Write-Host "[Client-Mode] Server $($UserConfig.ServerName):$($UserConfig.ServerPort) does not respond." -ForegroundColor Red
        }
        Write-Host " "
        Write-Log -Level Info "Client-Mode: $(if ($ServerConnected) {"Connected"} else {"Not connected"}) to $($UserConfig.ServerName):$($UserConfig.ServerPort)"
    }
    if ($UserConfig.RunMode -eq "Server") {
        if ($API.RemoteAPI) {
            Write-Host "[Server-Mode] Name=$($Session.MachineName) IP=$($Session.MyIP) Port=$($UserConfig.APIport) " -ForegroundColor Green
            if ($APIClients) {
                Write-Host " "
                Write-Host "Clients: " -NoNewLine
                $APIClients | Foreach-Object {
                    $lastseen = [Math]::Round((Get-UnixTimestamp)-$_.timestamp,0)
                    Write-Host "[$($_.workername)@$(if ($_.machinename) {$_.machinename} else {$_.machineip})]" -ForegroundColor "$(if ($lastseen -gt 300) {"Red"} else {"Green"}) " -NoNewline
                }
                Write-Host " "
            }
        } else {
            Write-Host "[Server-Mode] Server has not been started. Run RainbowMiner with admin privileges." -ForegroundColor Red
        }
        Write-Host " "
        Write-Log -Level Info "Server-Mode: $(if ($API.RemoteAPI) {"Name=$($Session.MachineName) IP=$($Session.MyIP) Port=$($UserConfig.APIport)"} else {"not started!"})"
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
            } elseif ($Global:PauseMiners.Test()) {
                Write-Host "Automatic update to v$($ConfirmedVersion.RemoteVersion) starts as soon as mining op will be resumed" -ForegroundColor Yellow
            } else {
                Write-Host "Automatic update failed! Please exit RainbowMiner and start Updater.bat manually to proceed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "To start update, press key `"U`"" -ForegroundColor Yellow            
        }
        Write-Host " "
    }

    $Global:AllPools = $NewPools

    #Reduce Memory
    if ($Miner -ne $null)  {Remove-Variable "Miner"}
    if ($Miner_Table -ne $null) {Remove-Variable "Miner_Table"}
    if ($Miners -ne $null) {Remove-Variable "Miners"}
    if ($Pool -ne $null)   {Remove-Variable "Pool"}
    if ($NewPools -ne $null) {Remove-Variable "NewPools"}
    if ($ServerPools -ne $null) {Remove-Variable "ServerPools"}

    if ($Error.Count) {
        $Error.Where({$_.Exception.Message}).ForEach({Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").main.txt" -Message "$($_.Exception.Message)" -Append -Timestamp})
        $Error.Clear()
    }

    Get-Job -State Completed | Where-Object {$_.Name -notmatch "^WebRequest-" -and $_.HasMoreData} | Receive-Job | Out-Host
    Get-Job -State Completed | Where-Object {$_.Name -notmatch "^WebRequest-"} | Remove-Job -Force
    if ($Global:GlobalSysInfoJob -and $Global:GlobalSysInfoJob.State -eq "Running") {$Global:GlobalSysInfoJob | Receive-Job > $null}

    [System.GC]::Collect()

    $Session.Timer = (Get-Date).ToUniversalTime()

    #Pause/Restart Asyncloader if internet status changes
    if (Test-Path Variable:Global:AsyncLoader) {
        if ($AsyncLoader.Timestamp -and ($AsyncLoader.Timestamp -lt $Session.Timer.AddHours(-1))) {
            Write-Log -Level Warn "Asyncloader seems to be crashed. Please press [Y] to restart it."
        }
    }

    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    $Session.SkipSwitchingPrevention = $Session.Stopp = $Session.RestartComputer = $keyPressed = $false

    #Dynamically adapt current interval
    $NextIntervalPreset = if ($Running) {$Session.Config."$(if ($Session.Benchmarking -or $Session.IsBenchmarkingRun) {"Benchmark"})Interval"} else {[Math]::Min($Session.Config.Interval,$Session.Config.BenchmarkInterval)}
    if (($Session.IsDonationRun -or $Session.IsServerDonationRun) -and $NextIntervalPreset -gt $DonateMinutes*60) {$NextIntervalPreset = $DonateMinutes*60}
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
    [System.Collections.Generic.List[string]]$cmdMenu = @("E[x]it","[R]estart","[B]alance update","[S]kip SP","[W]D reset")
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {$cmdMenu.Insert(0,"[U]pdate RainbowMiner") > $null}
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun){$cmdMenu.Add("[C]onfiguration") > $null}
    $cmdMenu.Add("[V]erbose$(if ($Session.Config.UIstyle -eq "full"){" off"})") > $null
    if (-not $Global:PauseMiners.Test() -or $Global:PauseMiners.TestIA()) {$cmdMenu.Add("[P]ause$(if ($Global:PauseMiners.Test()){" off"})") > $null}
    if (-not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {$cmdMenu.Add("$(if ($LockMiners){"Un[l]ock"} else {"[L]ock"})") > $null}
    Write-Host "Waiting $($WaitSeconds)s until next run: $($cmdMenu -join ", ")"

    $API.CmdMenu = $cmdMenu

    $SamplesPicked = 0
    $WaitRound = 0
    $SomeMinersFailed = $false
    $MinerStart = $Session.Timer
    do {        
        $TimerBackup = $Session.Timer

        $AllMinersFailed = $false

        if ($WaitRound % 3 -eq 0) {
            $MinersUpdateStatus = Update-ActiveMiners -ActiveMiners_DeviceNames $ActiveMiners_DeviceNames -FirstRound (-not $WaitRound) -UpdateDeviceInformation:$($WaitRound % 12 -eq 0)

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

        $CurrentPause = $Global:PauseMiners.Test()

        if ($Session.Config.EnablePauseOnActivity -and $Session.RoundCounter -gt 0) {
            if ($ActivityTimer = Get-LastUserInput) {
                if ($Global:PauseMiners.Test([PauseStatus]::ByActivity)) {
                    if ($Session.Config.ResumeOnInactivitySeconds -and $ActivityTimer.IdleTime.TotalSeconds -ge $Session.Config.ResumeOnInactivitySeconds) {
                        $Global:PauseMiners.Reset([PauseStatus]::ByActivity)
                    }
                } elseif ($ActivityTimer.IdleTime -lt ((Get-Date).ToUniversalTime() - $Session.RoundStart)) {
                    $Global:PauseMiners.Set([PauseStatus]::ByActivity)
                }
            } else {
                $Global:PauseMiners.Reset([PauseStatus]::ByActivity)
            }
        } else {
            $Global:PauseMiners.Reset([PauseStatus]::ByActivity)
        }

        $Global:PauseMiners.Set([PauseStatus]::ByBattery,$Session.Config.EnablePauseOnBattery -and (Test-IsOnBattery))

        if ($CurrentPause -ne $Global:PauseMiners.Test()) {
            $keyPressed = $true
            Write-Log "Mining will be $(if ($Global:PauseMiners.Test()) {"PAUSED $($Global:PauseMiners.Status -join ",")"} else {"UNPAUSED"})"
            $API.PauseMiners.Pause       = $Global:PauseMiners.Test()
            $API.PauseMiners.PauseIA     = $Global:PauseMiners.TestIA()
            $API.PauseMiners.PauseIAOnly = $Global:PauseMiners.TestIAOnly()
        }
 
        $keyPressedValue =  if ((Test-Path ".\stopp.txt") -or $API.Stop) {"X"}
                            elseif ((Test-Path ".\reboot.txt") -or $API.Reboot) {"Q"}
                            elseif ($API.Pause) {"P"}
                            elseif ($API.LockMiners -ne $Session.LockMiners.Locked -and -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {"L"}
                            elseif ($API.Update) {"U"}
                            elseif ($API.UpdateBalance) {"B"}
                            elseif ($API.WatchdogReset) {"W"}
                            elseif ($API.CmdKey -ne '') {$API.CmdKey}
                            else {
                                try {
                                    if ([System.Console]::KeyAvailable) {
                                        $key = [System.Console]::ReadKey($true)
                                        if (-not $key.Modifiers) {$key.key} elseif ($key.Modifiers -eq "Control" -and $key.key -eq "C") {"X"}
                                    }
                                } catch {
                                    if ($Error.Count) {$Error.RemoveAt(0)}
                                    Write-Log -Level Warn "Console not available. Please use the web console. ($($_.Exception.Message))"
                                }
                            }

        if ($keyPressedValue) {
            $API.CmdKey = $keyPressedValue
            switch ($keyPressedValue) {
                "S" { 
                    $Session.SkipSwitchingPrevention = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to skip switching prevention. "
                    Write-Host -NoNewline "[S] pressed - skip switching prevention in next run. "
                    $keyPressed = $true
                    Break
                }
                "N" {                     
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to start next round immediatly. "
                    Write-Host -NoNewline "[N] pressed - next run will start immediatly. "
                    $keyPressed = $true
                    Break
                }
                "X" {
                    $Session.Stopp = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to stop script. "
                    Write-Host -NoNewline "[X] pressed - stopping script."
                    $keyPressed = $true
                    Break
                }
                "D" {
                    $Session.StartDownloader = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to start downloader. "
                    Write-Host -NoNewline "[D] pressed - starting downloader in next run. "
                    $keyPressed = $true
                    Break
                }
                "V" {
                    $Session.Config.UIstyle = if ( $Session.Config.UIstyle -eq "full" ) {"lite"} else {"full"}
                    Write-Host -NoNewline "[V] pressed - UI will be set to $($Session.Config.UIstyle) in next run. "
                    $keyPressed = $true
                    Break
                }
                "P" {
                    $API.Pause = $false
                    if ($Global:PauseMiners.TestIA()) {$Global:PauseMiners.ResetIA()} else {$Global:PauseMiners.SetIA()}
                    Write-Host -NoNewline "[P] pressed - mining will be $(if ($Global:PauseMiners.Test()) {"PAUSED $($Global:PauseMiners.Status -join ",")"} else {"UNPAUSED"})"
                    $API.PauseMiners.Pause       = $Global:PauseMiners.Test()
                    $API.PauseMiners.PauseIA     = $Global:PauseMiners.TestIA()
                    $API.PauseMiners.PauseIAOnly = $Global:PauseMiners.TestIAOnly()
                    $keyPressed = $true
                    Break
                }
                "L" {
                    if (-not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {
                        $Session.LockMiners.Locked = -not $Session.LockMiners.Locked
                        if ($Session.LockMiners.Locked) {
                            $Session.LockMiners.Pools = @($Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running}) | Foreach-Object {for($i=0;$i -lt $_.Pool.Count;$i++) {"$($_.Pool | Select-Object -Index $i)-$($_.BaseAlgorithm | Select-Object -Index $i)-$($_.CoinSymbol | Select-Object -Index $i)"}} | Select-Object -Unique)
                        }
                        $API.LockMiners = $Session.LockMiners.Locked
                        Write-Host -NoNewline "[L] pressed - switching will be $(if ($Session.LockMiners.Locked) {"LOCKED"} else {"UNLOCKED"})"
                        $keyPressed = $true
                    }
                    Break
                }
                "C" {
                    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {
                        $Session.RunSetup = $true
                        Write-Host -NoNewline "[C] pressed - configuration setup will be started"
                        $keyPressed = $true
                    }
                    Break
                }
                "U" {
                    $Session.AutoUpdate = $true
                    $API.Update = $false
                    Write-Log "User requests to update to v$($ConfirmedVersion.RemoteVersion)"
                    Write-Host -NoNewline "[U] pressed - automatic update of Rainbowminer will be started "
                    $keyPressed = $true
                    Break
                }
                "R" {
                    $Session.Restart = $true
                    Write-Log "User requests to restart RainbowMiner."
                    Write-Host -NoNewline "[R] pressed - restarting RainbowMiner."
                    $keyPressed = $true
                    Break
                }
                "W" {
                    $API.WatchdogReset = $false
                    Write-Host -NoNewline "[W] pressed - resetting WatchDog."
                    $Global:WatchdogTimers = @()
                    Update-WatchdogLevels -Reset
                    Write-Log "Watchdog reset."
                    $keyPressed = $true
                    Break
                }
                "B" {
                    $API.UpdateBalance = $false
                    Write-Host -NoNewline "[B] pressed - updating Balance."
                    $Session.Updatetracker.Balances = 0
                    Write-Log "User request to update balance."
                    $keyPressed = $true
                    Break
                }
                "Y" {
                    Stop-AsyncLoader
                    Start-Sleep 2
                    Start-AsyncLoader -Interval $Session.Config.Interval -Quickstart $Session.Config.Quickstart
                    Write-Host -NoNewline "[Y] pressed - Asyncloader yanked."
                    Write-Log "Asyncloader yanked."
                    Break
                }
                "Q" {
                    $Session.RestartComputer = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to reboot the computer. "
                    Write-Host -NoNewline "[Q] pressed - reboot computer."
                    $keyPressed = $true
                    Break
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

    if ($SamplesPicked -eq 0) {Update-ActiveMiners -ActiveMiners_DeviceNames $ActiveMiners_DeviceNames -UpdateDeviceInformation > $null;$Session.Timer = (Get-Date).ToUniversalTime();$SamplesPicked++}

    if ($Global:Downloader.HasMoreData) {$Global:Downloader | Receive-Job | Out-Host}
    if ($Global:DownloaderPrq.HasMoreData) {$Global:DownloaderPrq | Receive-Job | Out-Host}

    if (-not $keyPressed) {
        $host.UI.RawUI.CursorPosition = $CursorPosition
        Write-Log "Finish waiting before next run. "
        Write-Host -NoNewline "Finished waiting - starting next run "
    }

    Write-Host (" " * 120)

    #Save current hash rates
    Write-Log "Saving hash rates. "

    #Store CPU/GPU statitics
    Set-MinerStats ($Session.Timer - $MinerStart)

    #Cleanup stopped miners    
    $Global:ActiveMiners.Where({$_.Stopped}).ForEach({$_.StopMiningPostCleanup()})
        
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
                    $NewKid = Invoke-CimMethod Win32_Process -MethodName Create -Arguments @{CommandLine=$StartCommand;CurrentDirectory=$PWD.Path;ProcessStartupInformation=New-CimInstance -CimClass (Get-CimClass Win32_ProcessStartup) -Property @{ShowWindow=if ($StartWindowState -eq "normal"){5}else{3}} -Local}
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

    if ($Session.Config.EnableRestartComputer -and ($Session.RestartComputer -or $Session.Config.RestartComputerHours -gt 0 -and $Session.StartTimeCore.AddHours($Session.Config.RestartComputerHours) -le (Get-Date).ToUniversalTime())) {
        Write-Log -Level Warn "Restarting computer in 10 seconds."
        1..10 | Foreach-Object {Start-Sleep -Seconds 1;Write-Log -Level Warn "$(10-$_)"}
        try {
            Invoke-Reboot
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Failed to restart computer: $($_.Exception.Message) on item $($_.Exception.ItemName)"
        }
        $API.Reboot = $Session.RestartComputer = $false
    }

    if ($Session.IsBenchmarkingRun -and -not $Session.Benchmarking) {$Session.IsBenchmarkingRun = $false}

    $Session.RoundCounter++
}

function Stop-Core {

    #Stop services
    if (-not $Session.Config.DisableAPI)         {Stop-APIServer}
    if (-not $Session.Config.DisableAsyncLoader) {Stop-AsyncLoader}

    if (Test-Path ".\stopp.txt")  {Remove-Item ".\stopp.txt" -Force -ErrorAction Ignore}
    if (Test-Path ".\reboot.txt") {Remove-Item ".\reboot.txt" -Force -ErrorAction Ignore}

    Write-Log "Gracefully halting RainbowMiner"
    [System.Collections.Generic.List[string]]$ExcavatorWindowsClosed = @()
    $Global:ActiveMiners.Where({$_.Activated -gt 0 -or $_.GetStatus() -eq [MinerStatus]::Running}).ForEach({
        $Miner = $_
        if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
            Write-Log "Closing miner $($Miner.Name)"
            $Miner.StopMining()
        }
        if ($Miner.BaseName -like "Excavator*" -and -not $ExcavatorWindowsClosed.Contains($Miner.BaseName)) {
            $Miner.ShutDownMiner()
            $ExcavatorWindowsClosed.Add($Miner.BaseName) > $null
        }
    })
    if ($IsWindows) {
        Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {$_.ExecutablePath -like "$(Get-Location)\Bin\*"} | Stop-Process -Force -ErrorAction Ignore
    } elseif ($IsLinux) {
        Get-Process | Where-Object Path | Where-Object {$_.Path -like "$(Get-Location)/Bin/*" -or $_.Path -like "$(Get-Location)/IncludesLinux/bin/*"} | Foreach-Object {
            if (Test-OCDaemon) {
                $Cmd = @()
                @($_.Id,$_.Parent.Id) | Select-Object -Unique | % {$Cmd += "kill $($_)"}
                Invoke-OCDaemon -Cmd $Cmd -Quiet > $null
            } else {
                @($_.Id,$_.Parent.Id) | Select-Object -Unique | % {Stop-Process -Id $_ -Force -ErrorAction Ignore}
            }
        }
        if (Get-Command "screen" -ErrorAction Ignore) {

            $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()
            if (Test-OCDaemon) {
                [System.Collections.Generic.List[string]]$Cmd = @()
                $Cmd.Add("screen -ls `"$WorkerName`" |  grep '[0-9].$($WorkerName)_' | (") > $null
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
                Invoke-OCDaemon -Cmd $Cmd > $null
            }

            Invoke-Exe "screen" -ArgumentList "-ls" -ExpandLines | Where-Object {$_ -match "(\d+\.$($WorkerName)_[a-z0-9_-]+)"} | Foreach-Object {
                Invoke-Exe "screen" -ArgumentList "-S $($Matches[1]) -X stuff `^C" > $null
                Start-Sleep -Milliseconds 250
                Invoke-Exe "screen" -ArgumentList "-S $($Matches[1]) -X quit" > $null
            }
        }
    }
    Stop-Autoexec
    [console]::TreatControlCAsInput = $false
}

##
## Utility functions
##

##
## GET functions
##

function Get-Balance {
    [CmdletBinding()]
    param($Config,[Bool]$Refresh = $false)
    
    if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and $Config.EnableServerPools) {
        $ServerConnected = Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2
        if ($ServerConnected) {
            try {
                Invoke-RestMethodAsync "server://balances?raw=1" -cycletime ($Config.BalanceUpdateMinutes*60) -Timeout 20
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
            return
        }
    }

    if (-not (Test-Path Variable:Global:CachedPoolBalances) -or $Refresh) {
        $Global:CachedPoolBalances = @(Get-BalancesContent -Config $Config | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Currency} | Group-Object -Property Caption | Foreach-Object {
            if ($_.Count -gt 1){foreach ($p in @("Balance","Pending","Total","Paid","Earned","Payouts")) {if (Get-Member -InputObject $_.Group[0] -Name $p) {if ($p -eq "Payouts") {$_.Group[0].$p = @($_.Group.$p | Select-Object)} else {$_.Group[0].$p = ($_.Group.$p | Measure-Object -Sum).Sum}}}}
            $_.Group[0]
        })
    }

    $Balances = $Global:CachedPoolBalances | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json -ErrorAction Ignore
    if (-not $Session.Config.ShowWalletBalances) {
        $Balances = $Balances | Where-Object {$_.BaseName -ne "Wallet"}
    }

    if (-not $Balances) {return}

    #Get exchange rates for all payout currencies
    [System.Collections.Generic.List[string]]$CurrenciesWithBalances = @()
    [System.Collections.Generic.List[string]]$CurrenciesToExchange   = @()
    [System.Collections.Generic.List[string]]$CurrenciesMissing = @()

    $RatesAPI = [PSCustomObject]@{}
    
    $Balances.currency | Select-Object -Unique | Sort-Object | Foreach-Object {$CurrenciesWithBalances.Add($_) > $null}
    @("BTC") + $Config.Currency | Select-Object -Unique | Sort-Object | Foreach-Object {$CurrenciesToExchange.Add($_) > $null}
    $CurrenciesWithBalances + $CurrenciesToExchange | Where-Object {-not $Global:Rates.ContainsKey($_)} | Foreach-Object {$CurrenciesMissing.Add($_) > $null}

    if ($CurrenciesMissing.Count) {Update-Rates $CurrenciesMissing}

    $CurrenciesWithBalances | Foreach-Object {
        $Currency = $_
        if ($Global:Rates.ContainsKey($Currency) -and $Global:Rates[$Currency]) {
            $RatesAPI | Add-Member "$($Currency)" ([PSCustomObject]@{})
            $CurrenciesToExchange | Where-Object {$Global:Rates.ContainsKey($_)} | Foreach-Object {
                $RatesAPI.$Currency | Add-Member $_ ($Global:Rates.$_/$Global:Rates.$Currency)
            }
        }
    }

    #Add total of totals
    $Totals_Pools = [PSCustomObject]@{
        Name    = "*Total Pools*"
        BaseName= "TotalPools"
        Caption = "*Total Pools*"
    }

    $Totals_Wallets = [PSCustomObject]@{
        Name    = "*Total Wallets*"
        BaseName= "TotalWallets"
        Caption = "*Total Wallets*"
    }

    #Add total of totals
    $Totals = [PSCustomObject]@{
        Name    = "*Total*"
        BaseName= "Total"
        Caption = "*Total*"
    }

    $WorldCurrencies = Get-WorldCurrencies

    [hashtable]$Digits = @{}
    $CurrenciesWithBalances + $Config.Currency | Where-Object {$_} | Select-Object -Unique | Foreach-Object {$Digits[$_] = if ($WorldCurrencies -icontains $_) {2} else {8}}

    $CurrenciesWithBalances | ForEach-Object {
        $Currency = $_.ToUpper()
        $Balances | Where-Object Currency -eq $Currency | Foreach-Object {$_ | Add-Member "Balance ($Currency)" $_.Total -Force;$_ | Add-Member "Pending ($Currency)" $_.Pending -Force}
        $Balance_Sum = ($Balances."Balance ($Currency)" | Measure-Object -Sum).Sum
        $Pending_Sum = ($Balances."Pending ($Currency)" | Measure-Object -Sum).Sum
        if ($Balance_Sum) {
            $Totals | Add-Member "Balance ($Currency)" $Balance_Sum -Force
        }
        if ($Pending_Sum) {
            $Totals | Add-Member "Pending ($Currency)" $Pending_Sum -Force
        }
        if ($Session.Config.ShowWalletBalances) {
            $Balance_Sum2 = ($Balances | Where-Object {$_.BaseName -ne "Wallet" -and $_."Balance ($Currency)"} | Select-Object -ExpandProperty "Balance ($Currency)" | Measure-Object -Sum).Sum
            if ($Balance_Sum2) {
                $Totals_Pools | Add-Member "Balance ($Currency)" $Balance_Sum2 -Force
            }
            if ($Balance_Sum -gt $Balance_Sum2) {
                $Totals_Wallets | Add-Member "Balance ($Currency)" ($Balance_Sum - $Balance_Sum2) -Force
            }
        }
    }

    #Add converted values
    $Config.Currency | Sort-Object | ForEach-Object {
        $Currency = $_.ToUpper()
        $Balances | Foreach-Object {
            $Balance = $_
            $Balance | Add-Member "Value in $Currency" $(if ($RatesAPI.$($Balance.Currency).$Currency -ne $null) {$Balance.Total * $RatesAPI.$($Balance.Currency).$Currency}elseif($RatesAPI.$Currency.$($Balance.Currency)) {$Balance.Total / $RatesAPI.$Currency.$($Balance.Currency)}else{"-"}) -Force
        }
        $Balance_Sum = ($Balances."Value in $Currency" | Where-Object {$_ -ne "-"} | Measure-Object -Sum -ErrorAction Ignore).Sum
        if ($Balance_Sum)  {
            $Totals | Add-Member "Value in $Currency" $Balance_Sum -Force
        }
        if ($Session.Config.ShowWalletBalances) {
            $Balance_Sum2 = ($Balances | Where-Object {$_.BaseName -ne "Wallet" -and $_."Value in $Currency"} | Select-Object -ExpandProperty "Value in $Currency" | Where-Object {$_ -ne "-"} | Measure-Object -Sum -ErrorAction Ignore).Sum
            if ($Balance_Sum2)  {
                $Totals_Pools | Add-Member "Value in $Currency" $Balance_Sum2 -Force
            }
            if ($Balance_Sum -gt $Balance_Sum2) {
                $Totals_Wallets | Add-Member "Value in $Currency" ($Balance_Sum - $Balance_Sum2) -Force
            }
        }
    }

    if (-not $Config.ShowPoolBalancesDetails) {
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

    if ($Session.Config.ShowWalletBalances -and ($Balances | Where-Object {$_.BaseName -eq "Wallet" -and $_.Total} | Measure-Object).Count) {
        $Balances = @($Balances | Where-Object {$_.BaseName -ne "Wallet" -and $_.Total} | Select-Object) + $Totals_Pools + @($Balances | Where-Object {$_.BaseName -eq "Wallet" -and $_.Total} | Select-Object) + $Totals_Wallets + $Totals
    } else {
        $Balances = @($Balances | Where-Object {$_.Total} | Select-Object) + $Totals
    }

    $Balances | Foreach-Object {
        $Balance = $_
        $Balance.PSObject.Properties.Name | Where-Object {$_ -match "^(Value in |Balance \(|Pending \()(\w+)"} | Foreach-Object {if ($Balance.$_ -eq "" -or $Balance.$_ -eq $null) {$Balance.$_=0};$Balance.$_ = "{0:N$($n = if ($Balance.$_ -ge 10 -and $Digits[$Matches[2]] -eq 8) {[Math]::Min([Math]::Ceiling([Math]::Log10($Balance.$_)),8)} else {1};$Digits[$Matches[2]]-$n+1)}" -f $Balance.$_}
    }

    $Balances_DateTime = Get-Date
    $Balances | Where-Object {$_.Name -notmatch "^\*" -and $_.BaseName -ne "Wallet"} | Foreach-Object {
        $Balance = $_
        $Earnings = Set-Balance $Balance -Updated $Balances_DateTime
        $Earnings.PSObject.Properties.Name | Where-Object {$_ -match "^Earnings" -or $_ -eq "Started"} | Foreach-Object {
            $Balance | Add-Member $_ $Earnings.$_ -Force
        }
    }
    if ($Earnings -ne $null) {Remove-Variable "Earnings"}
    
    $Balances
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
        $BestMiners_DeviceNames = @($BestMiners | Foreach-Object {$_.DeviceName} | Select-Object -Unique | Sort-Object)
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

##
## SET functions
##

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
    $Global:ActiveMiners.ForEach({
        $Miner = $_

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.BaseAlgorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Sub $Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel])})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if (($Miner.Status -eq [Minerstatus]::Running) -or $Miner.New) { #GetStatus() check?
            $Miner_PowerDraw = $Miner.GetPowerDraw()

            $Statset = 0
            $Miner_Index = 0
            $Miner_Failed= $false
            foreach ($Miner_Algorithm in $Miner.Algorithm) {
                $Miner_Speed = $Miner.GetHashRate($Miner_Algorithm,$true)
                $Miner_Diff  = $Miner.GetDifficulty($Miner_Algorithm)

                $Miner.Speed_Live[$Miner_Index] = [Double]$Miner_Speed

                Write-Log -Level Info "$($Miner.BaseName) $(if ($Miner.IsBenchmarking()) {"benchmarking"} else {"mining"}) $($Miner_Algorithm) on $($Miner.DeviceModel): $($Miner.GetMinerDataCount()) samples / round $(if ($Miner.IsBenchmarking()) {"$($Miner.Benchmarked) / variance $("{0:f2}" -f ($Miner.Variance[$Miner.Algorithm.IndexOf($Miner_Algorithm)]*100))%"} else {$Miner.Rounds})"

                $Stat = $null
                if (-not $Miner.IsBenchmarking() -or $Miner_Speed) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($Miner_Algorithm -replace '\-.*$')_HashRate" -Value $Miner_Speed -Difficulty $Miner_Diff -Ratio $Miner.RejectedShareRatio[$Miner_Index] -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel] -StartTime $Miner.StartTime -LogFile "$(Split-Path -Leaf $Miner.LogFile)" -Quiet:$($Quiet -or ($Miner.GetRunningTime() -lt (New-TimeSpan -Seconds 30)) -or $Miner.IsWrapper())
                    $Statset++
                }

                #Update watchdog timer
                if ($WatchdogTimer = $Global:WatchdogTimers | Where-Object {$_.MinerName -eq $Miner.Name -and $_.PoolName -eq $Miner.Pool[$Miner_Index] -and $_.Algorithm -eq $Miner_Algorithm}) {
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
    })
    if ($Watchdog) {-not $Miner_Failed_Total}

    if (-not $Session.Benchmarking -and -not $Session.IsBenchmarkingRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {
        $CurrentProfitGPU    = 0
        $CurrentPowerDrawGPU = 0
        $DeviceNameCountGPU  = 0
        foreach ($CurrentModel in $Session.Config.DeviceModel.Where({$_ -notmatch "-"})) {
            $Global:ActiveMiners.Where({$_.Profit -ne $null -and $_.DeviceModel -eq $CurrentModel -and $_.Pool -notcontains "MiningRigRentals"}) | Select-Object -Property Profit,Profit_Cost,PowerDraw,DeviceName | Sort-Object -Property Profit | Select-Object -Last 1 | Foreach-Object {
                $CurrentProfit = $_.Profit + $(if ($Session.Config.UsePowerPrice -and $_.Profit_Cost) {$_.Profit_Cost})
                if ($CurrentProfit -gt 0) {
                    if ($CurrentModel -ne "CPU") {
                        $CurrentProfitGPU    += $CurrentProfit
                        $CurrentPowerDrawGPU += $_.PowerDraw
                        if ($DeviceNameCountGPU -lt $_.DeviceName.Count) {$DeviceNameCountGPU = $_.DeviceName.Count}
                    }
                    Set-Stat -Name "Profit-$($Global:DeviceCache.DeviceNames.$CurrentModel -join "-")" -Value $CurrentProfit -PowerDraw $_.PowerDraw -Duration $StatSpan -UplimProtection $Session.Config.ProfitSpikeProtection > $null
                }
            }
        }

        if ($CurrentProfitGPU -gt 0) {
            $DeviceNameGPU = @($Global:DeviceCache.Devices.Where({$_.Type -eq "Gpu"}) | Select-Object -ExpandProperty Name | Sort-Object)
            if ($DeviceNameGPU -and $DeviceNameGPU.Count -gt $DeviceNameCountGPU) {
                Set-Stat -Name "Profit-$($DeviceNameGPU -join "-")" -Value $CurrentProfitGPU -PowerDraw $CurrentPowerDrawGPU -Duration $StatSpan -UplimProtection $Session.Config.ProfitSpikeProtection > $null
            }
        }
    }
}

##
## INVOKE functions
##

function Invoke-ReportMinerStatus {

    if (-not $Session.Config.MinerStatusURL -or -not $Session.Config.MinerStatusKey) {return}

    #Stop the console capture
    if ($Session.ConsoleCapture) {
        Stop-Transcript > $null
        $Session.ConsoleCapture = $false
    }

    $Version = "RainbowMiner $($Session.Version.ToString())"
    $Status = if ($Global:PauseMiners.Test()) {"Paused"} elseif (-not $Session.Profitable) {"Waiting"} else {"Running"}
    $ReportRates = [PSCustomObject]@{}
    $Session.Config.Currency | Where-Object {$Global:Rates.ContainsKey($_)} | Foreach-Object {$ReportRates | Add-Member $_ $Global:Rates.$_ -Force}

    [System.Collections.Generic.List[string]]$Including_Strings = @()
    if ($Session.ReportTotals)    {$Including_Strings.Add("totals") > $null}
    if ($Session.ReportMinerData) {$Including_Strings.Add("minerdata") > $null}
    if ($Session.ReportPoolsData) {$Including_Strings.Add("poolsdata") > $null}
    if ($Session.ReportDeviceData){$Including_Strings.Add("devicedata") > $null}
    Write-Log -Level Info "Pinging monitoring server$(if ($Including_Strings.Count) {" (including $($Including_Strings -join ", "))"}). "

    $Profit = 0.0
    $PowerDraw = 0.0
    $TempAlert = 0

    $minerreport = ConvertTo-Json @(
        $Global:ActiveMiners.Where({$_.Activated -GT 0 -and $_.Status -eq [MinerStatus]::Running}).ForEach({
            $Miner = $_
            $Miner_PowerDraw = $Miner.GetPowerDraw()
            $Profit += [Double]$Miner.Profit
            $PowerDraw += [Double]$Miner_PowerDraw

            [System.Collections.Generic.List[PSCustomObject]]$Devices = @()
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
                        Temp  = $_.Data.Temperature
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
                CoinName       = @($Miner.CoinName | Where-Object {$_} | Select-Object)
                CoinSymbol     = @($Miner.CoinSymbol | Where-Object {$_} | Select-Object)
                Pool           = @($Miner.Pool)
                CurrentSpeed   = @($Miner.Speed_Live)
                EstimatedSpeed = @($Miner.Speed)
                Accepted       = @($Miner.Stratum | Foreach-Object {$_.Accepted} | Select-Object)
                Rejected       = @($Miner.Stratum | Foreach-Object {$_.Rejected} | Select-Object)
                Stale          = @($Miner.Stratum | Foreach-Object {$_.Stale} | Select-Object)
                PowerDraw      = $Miner_PowerDraw
                'BTC/day'      = $Miner.Profit
                Profit         = $Miner.Profit
                Donator        = $Miner.Donator
                Benchmarking   = $Miner.Speed -contains $null
                Devices        = $Devices
            }
            $Devices = $null
        })
    ) -Depth 10 -Compress
    
    $Profit = [Math]::Round($Profit, 8) | ConvertTo-Json
    $PowerDraw = [Math]::Round($PowerDraw, 2) | ConvertTo-Json

    $Pool_Totals = if ($Session.ReportTotals) {
        Set-TotalsAvg -CleanupOnly
        $Session.ReportTotals = $false
    }

    if ($Pool_Totals) {
        Set-ContentJson -PathToFile ".\Data\pool_totals.json" -Data $Pool_Totals > $null
    }

    if (Test-Path ".\Data\reportapi.json") {try {$ReportAPI = Get-ContentByStreamReader ".\Data\reportapi.json" | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)};$ReportAPI=$null}}
    if (-not $ReportAPI) {$ReportAPI = @([PSCustomObject]@{match    = "rbminer.net";apiurl   = "https://rbminer.net/api/report.php"})}

    # Create crash alerts
    $CrashData = $null
    if ($Session.IsCore -or $Session.EnableCurl) {
        try {
            ConvertTo-Json @($Global:CrashCounter | Foreach-Object {[PSCustomObject]@{
                Timestamp      = "{0:yyyy-MM-dd HH:mm:ss}" -f $_.TimeStamp
                Start          = "{0:yyyy-MM-dd HH:mm:ss}" -f $_.Start
                End            = "{0:yyyy-MM-dd HH:mm:ss}" -f $_.End
                Runtime        = $_.Runtime
                Name           = $_.Name
                Device         = $_.Device
                Algorithm      = $_.Algorithm
                Pool           = $_.Pool
            }}) -Depth 10 -Compress | Set-Content ".\Data\crashdata.json"
            if (Test-Path ".\Data\crashdata.json") {
                $CrashData = Get-Item ".\Data\crashdata.json"
                if ($CrashData.Length -le 4) {$CrashData = $null}
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Miner Status $($ReportUrl) failed to create crash alerts. "
        }
    }

    # Create out-of-space alert
    $DiskMinGBAlert = ConvertTo-Json @($Session.SysInfo.Disks | Where-Object {($IsLinux -or "$PWD" -match "^$($_.Drive)") -and ($_.TotalGB - $_.UsedGB) -lt $Session.Config.DiskMinGB} | Select-Object) -Compress

    # Add current console.txt
    $Console = $null
    if ($Session.IsCore -or $Session.EnableCurl) {
        try {
            if (Test-Path ".\Logs\console.txt") {
                @(Get-ContentByStreamReader -FilePath ".\Logs\console.txt" -ExpandLines) | Foreach-Object {$_ -replace "$([char]27)\[\d+m"} | Set-Content -Path ".\Cache\console.txt" -Encoding Utf8
                $Console = Get-Item ".\Cache\console.txt"
                if ($Console.Length -le 100) {$Console = $null}
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Miner Status $($ReportUrl) failed to add current console.txt. "
        }
    }


    $CrashAlert = if ($Session.Config.MinerStatusMaxCrashesPerHour -ge 0 -and $Global:CrashCounter.Count -gt $Session.Config.MinerStatusMaxCrashesPerHour) {$Global:CrashCounter.Count} else {0}

    # All device data
    $DeviceData = $null
    if ($Session.ReportDeviceData) {
        try {
            ConvertTo-Json $Global:GlobalCachedDevices -Depth 10 -Compress | Set-Content ".\Data\devicedata.json"
            if (Test-Path ".\Data\devicedata.json") {
                if ($Session.IsCore -or $Session.EnableCurl) {
                    $DeviceData = Get-Item ".\Data\devicedata.json"
                } else {
                    $DeviceData = Get-ContentByStreamReader ".\Data\devicedata.json"
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Miner Status $($ReportUrl) failed to create device data. "
        }
        $Session.ReportDeviceData = $false
    }

    # Send the request
    try {
        $ReportUrl = $Session.Config.MinerStatusURL
        $ReportStatus = "Error"
        $ReportDone = $false

        $ReportInterval = if ($Session.CurrentInterval -gt $Session.Config.Interval -and $Session.CurrentInterval -gt $Session.Config.BenchmarkInterval) {$Session.CurrentInterval} else {$Session.Config.BenchmarkInterval}

        $ReportAPI | Where-Object {-not $ReportDone -and $ReportUrl -match $_.match} | Foreach-Object {
            $ReportUrl = $_.apiurl
            Write-Log -Level Info "Go report, go! $($ReportUrl)"
            $Response = Invoke-GetUrl $ReportUrl -body @{user = $Session.Config.MinerStatusKey; email = $Session.Config.MinerStatusEmail; pushoverkey = $Session.Config.PushOverUserKey; worker = $Session.Config.WorkerName; machinename = $Session.MachineName; machineip = $Session.MyIP; cpu = "$($Global:DeviceCache.DevicesByTypes.CPU.Model_Name | Select-Object -Unique)"; cputemp = "$(($Session.SysInfo.Cpus.Temperature | Measure-Object -Average).Average)"; cpuload = "$($Session.SysInfo.CpuLoad)"; cpupower = "$(($Session.SysInfo.Cpus.PowerDraw | Measure-Object -Sum).Sum)"; version = $Version; status = $Status; profit = "$Profit"; powerdraw = "$PowerDraw"; earnings_avg = "$($Session.Earnings_Avg)"; earnings_1d = "$($Session.Earnings_1d)"; pool_totals = ConvertTo-Json @($Pool_Totals | Select-Object) -Depth 10 -Compress; rates = ConvertTo-Json $ReportRates -Depth 10 -Compress; interval = $ReportInterval; uptime = "$((Get-Uptime).TotalSeconds)"; sysuptime = "$((Get-Uptime -System).TotalSeconds)";maxtemp = "$($Session.Config.MinerStatusMaxTemp)"; tempalert=$TempAlert; maxcrashes = "$($Session.Config.MinerStatusMaxCrashesPerHour)"; crashalert=$CrashAlert; crashdata=$CrashData; diskmingbalert=$DiskMinGBAlert; console=$Console; devices=$DeviceData; data = $minerreport}
            Write-Log -Level Info "Done report, done."
            if ($Response -is [string] -or $Response.Status -eq $null) {$ReportStatus = $Response -split "[\r\n]+" | Select-Object -first 1}
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
                                Break
                             }
                        }                        
                    }
                }
                if ($Response.Workers -ne $null) {
                    $OtherWorkers = @($Response.Workers | Where-Object worker -ne $Session.Config.WorkerName | Select-Object)
                    $Profit       = 0.0
                    $Earnings_Avg = 0.0
                    $Earnings_1d  = 0.0
                    $OtherWorkers | Where-Object {[Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc')).TotalSeconds)-5*60 -lt $_.lastseen} | Foreach-Object {$Profit += [decimal]$_.profit;$Earnings_Avg = [Math]::Max($Earnings_Avg,[decimal]$_.earnings_avg);$Earnings_1d = [Math]::Max($Earnings_1d,[decimal]$_.earnings_1d)}
                    $API.RemoteMiners = $OtherWorkers
                    $API.RemoteMinersProfit = $Profit
                    $API.RemoteMinersEarnings_Avg = $Earnings_Avg
                    $API.RemoteMinersEarnings_1d  = $Earnings_1d
                }
                if ($Response.Compare -ne $null) {
                    $API.CompareMiners = ConvertTo-Json @($Response.Compare | Select-Object) -Depth 10
                }
            }
            $ReportDone = $true
            
            #Upload statistics as separate files
            if ($Session.IsCore -or $Session.EnableCurl) {
                if ($Session.ReportMinerData -and (Test-Path ".\Data\minerdata.json")) {
                    $Response = Invoke-GetUrl $ReportUrl -body @{user = $Session.Config.MinerStatusKey; worker = $Session.Config.WorkerName; version = $Version; minerdata = Get-Item ".\Data\minerdata.json"}
                    $Session.ReportMinerData = $false
                }
                if ($Session.ReportPoolsData -and (Test-Path ".\Data\poolsdata.json")) {
                    $Response = Invoke-GetUrl $ReportUrl -body @{user = $Session.Config.MinerStatusKey; worker = $Session.Config.WorkerName; version = $Version; poolsdata = Get-Item ".\Data\poolsdata.json"}
                    $Session.ReportPoolsData = $false
                }
            }
        }
        if (-not $ReportDone) {
            $Response = Invoke-GetUrl $ReportUrl -Body @{address = $Session.Config.MinerStatusKey; workername = $Session.Config.WorkerName; version = $Version; status = $Status; profit = $Profit; miners = $minerreport}
            if ($Response) {$ReportStatus = $Response -split "[\r\n]+" | Select-Object -first 1} 
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Info "Miner Status $($ReportUrl) has failed. "
    }
}

##
## UPDATE functions
##

function Update-ActiveMiners {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Array]$ActiveMiners_DeviceNames = @(),
        [Parameter(Mandatory = $false)]
        [Bool]$FirstRound = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$UpdateDeviceInformation = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )

    if ($UpdateDeviceInformation) {
        Update-DeviceInformation $ActiveMiners_DeviceNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    }
    $MinersUpdated = 0
    $MinersFailed  = 0
    $ExclusiveMinersFailed = 0
    $Global:ActiveMiners.Where({$_.Best}).ForEach({
        $Miner = $_
        $Miner_Status = $Miner.GetStatus()
        if ($Miner_Status -eq [MinerStatus]::Running) {
            if (-not $FirstRound -or $Miner.Rounds) {
                $Miner.UpdateMinerData() > $null
                if (-not $Miner.CheckShareRatio() -and -not ($Miner.BaseAlgorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Sub $Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel])})) {
                    Write-Log "Too many rejected shares for miner $($Miner.Name)"
                    $Miner.ResetMinerData()
                } elseif ($Miner.ShareCheck -gt 0 -and $Miner.ShareCheck -lt $Miner.GetLastAcceptedSeconds()) {
                    Write-Log "Miner $($Miner.Name) will restart because last accepted share is older than $($Miner.ShareCheck) seconds"
                    $Miner.Restart = $true
                }
            }
        }

        Switch ("$($Miner_Status)") {
            "Running"       {if ($Session.Config.EnableOCprofiles -and ($Miner.DeviceName -notlike "CPU*") -and ($Session.Config.OCResetInterval -gt 0) -and ($Miner.GetLastSetOCTime() -lt (Get-Date).AddSeconds(-$Session.Config.OCResetInterval).ToUniversalTime() -or $API.ApplyOC)) {$Miner.SetOCprofile($Session.Config,500);if ($IsLinux) {Invoke-OCDaemon -Miner $Miner -Quiet > $null};$API.ApplyOC=$false};$MinersUpdated++;Break}
            "RunningFailed" {$Miner.ResetMinerData();$MinersFailed++;if ($Miner.IsExclusiveMiner) {$ExclusiveMinersFailed++};Break}
        }
    })
    if ($MinersFailed) {
        $API.RunningMiners  = $Global:ActiveMiners.Where({$_.Status -eq [MinerStatus]::Running})
    }
    if (-not $Silent) {
        [PSCustomObject]@{
            MinersUpdated = $MinersUpdated
            MinersFailed  = $MinersFailed
            ExclusiveMinersFailed = $ExclusiveMinersFailed
        }
    }
}

function Update-Rates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Symbols
    )

    $WCSymbols   = Get-WorldCurrencies
    $BaseSymbols = @($Session.Config.Currency | Select-Object) + @("USD") | Select-Object -Unique
    $GetSymbols  = @($Symbols | Select-Object) + @($Session.Config.Currency | Select-Object) + @("USD") + @($Session.Config.Pools.PSObject.Properties.Name | Foreach-Object {$Session.Config.Pools.$_.Wallets.PSObject.Properties.Name} | Select-Object) + @($Global:Rates.Keys) | Select-Object -Unique
    
    [hashtable]$NewRates   = @{}
    try {
        $NewCoinbase = (Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -Jobkey "coinbase").data.rates
        if ($NewCoinbase.BTC) {
            $NewCoinbase.PSObject.Properties | Where-Object {$_.Name -notin $WCSymbols -or $_.Name -in $BaseSymbols} | Foreach-Object {$NewRates[$_.Name] = [Double]$_.Value}
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}

    if (-not $NewRates.Count) {
        Write-Log -Level Info "Coinbase is down, using fallback. "
        try {
            $AltCoinbase = Invoke-GetUrl "https://rbminer.net/api/data/coinbase.json"
            if ($AltCoinbase.BTC) {
                $AltCoinbase.PSObject.Properties | Where-Object {$_.Name -notin $WCSymbols -or $_.Name -in $BaseSymbols} | Foreach-Object {$NewRates[$_.Name] = [Double]$_.Value}
            }
        } catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Coinbase down. "}
    }

    $Global:Rates["BTC"] = $NewRates["BTC"] = [Double]1

    Compare-Object @($GetSymbols) @($NewRates.Keys) -IncludeEqual | Where-Object {$_.SideIndicator -ne "=>" -and $_.InputObject} | Foreach-Object {
        if ($_.SideIndicator -eq "==") {$Global:Rates[$_.InputObject] = [Double]$NewRates[$_.InputObject]}
        elseif ($Session.GetTicker -inotcontains $_.InputObject) {$Session.GetTicker.Add($_.InputObject.ToUpper()) > $null}
    }

    Compare-Object @($WCSymbols) @($Global:Rates.Keys) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject | Foreach-Object {$Global:Rates[$_] = [Math]::Round($Global:Rates[$_],3)}

    if ($Session.GetTicker.Count -gt 0) {
        try {
            $SymbolStr = "$(($Session.GetTicker | Sort-Object) -join ',')".ToUpper()
            $RatesAPI = Invoke-RestMethodAsync "https://rbminer.net/api/cmc.php?symbols=$($SymbolStr)" -Jobkey "morerates" -cycletime 600
            if (-not $RatesAPI.status) {
                Write-Log -Level Info "Rbminer.net/cmc failed for $($SymbolStr)"
            } elseif ($RatesAPI.data -and $RatesAPI -is [object]) {
                $RatesAPI.data.PSObject.Properties | Foreach-Object {$Global:Rates[$_.Name] = if ($_.Value -gt 0) {[double](1e8/$_.Value)} else {0}}
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Info "Rbminer.net/cmc API for $($SymbolStr) has failed. "
        }
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
