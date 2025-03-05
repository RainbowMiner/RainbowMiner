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

            if ($Linux_Libs = Get-ContentByStreamReader ".\IncludesLinux\libs.json" | ConvertFrom-Json -ErrorAction Ignore) {

                $Linux_LibRunas = (Test-Path "/opt/rainbowminer/lib") -and ((Test-OCDaemon) -or (Test-IsElevated))

                $Linux_LibDir   = "$Pwd/IncludesLinux/lib"
                $Linux_LibDir2  = if ($Linux_LibRunas) {"/opt/rainbowminer/lib"} else {$Linux_LibDir}

                $Linux_BinDir   = "$Pwd/IncludesLinux/bin"
                $Linux_BinDir2  = if ($Linux_LibRunas) {"/opt/rainbowminer/bin"} else {$Linux_BinDir}

                $Linux_Libs.PSObject.Properties | Foreach-Object {
                    $Lib_Source = Join-Path $Linux_LibDir  $_.Value
                    $Lib_Dest   = Join-Path $Linux_LibDir2 $_.Value
                    $Lib_Link   = Join-Path $Linux_LibDir2 $_.Name

                    if ($Linux_LibRunas -and (Test-Path $Lib_Source) -and -not (Test-Path $Lib_Dest)) {
                        Invoke-Exe -FilePath "cp" -ArgumentList "$($Lib_Source) $($Lib_Dest)" -Runas > $null
                    }

                    if ((Test-Path $Lib_Dest) -and (-not (Test-Path $Lib_Link) -or (Get-Item $Lib_Link).LinkTarget -ne $Lib_Dest)) {
                        Invoke-Exe -FilePath "ln" -ArgumentList "-sf $($Lib_Dest) $($Lib_Link)" -Runas:$Linux_LibRunas > $null
                    }

                    if ($Linux_LibDir -ne $Linux_LibDir2) {
                        $Lib_Dest   = Join-Path $Linux_LibDir $_.Value
                        $Lib_Link   = Join-Path $Linux_LibDir $_.Name
                        if ((Test-Path $Lib_Dest) -and (-not (Test-Path $Lib_Link) -or (Get-Item $Lib_Link).LinkTarget -ne $Lib_Dest)) {
                            Invoke-Exe -FilePath "ln" -ArgumentList "-sf $($Lib_Dest) $($Lib_Link)" > $null
                        }
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
            Write-Log $PSUpdateMessage
            Write-Host " "
        }


        #Setup Core variables that are used in Runspaces
        $Global:StatsCache     = [System.Collections.Hashtable]::Synchronized(@{})
        $Global:Rates          = [System.Collections.Hashtable]::Synchronized(@{})

        #Setup Core global variables
        $Global:DeviceCache    = [hashtable]@{}
        $Global:MinerInfo      = [hashtable]@{}
        $Global:MinerSpeeds    = [hashtable]@{}
        $Global:ActiveMiners   = [System.Collections.ArrayList]::new()
        $Global:WatchdogTimers = [System.Collections.Generic.List[PSCustomObject]]::new()
        $Global:CrashCounter   = [System.Collections.Generic.List[PSCustomObject]]::new()
        $Global:AlgorithmMinerName = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        $Global:Rates["BTC"] = [Double]1

        $Global:PauseMiners = [PauseMiners]::new()

        #Setup session variables
        $Session.ConfigFiles = [hashtable]@{
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
            MRRAlgorithms = @{Path='';LastWriteTime=0;Healthy=$true}
        }

        $Session.GetTicker = [System.Collections.Generic.List[string]]::new()

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
        $Session.ReportUnclean = $false
        $Session.TimeDiff = 0
        $Session.PhysicalCPUs = 0
        $Session.LastDonated = $null
        $Session.CUDAversion = $false
        $Session.DotNETRuntimeVersion = $(try {[String]$(if ($cmd = (Get-Command dotnet -ErrorAction Ignore)) {(dir $cmd.Path.Replace('dotnet.exe', 'shared/Microsoft.NETCore.App')).Name | Where-Object {$_ -match "^([\d\.]+)$"} | Foreach-Object {Get-Version $_} | Sort-Object | Select-Object -Last 1})} catch {})

        #$Session.Debug = $true

        try {$Session.EnableColors = [System.Environment]::OSVersion.Version -ge (Get-Version "10.0") -and $PSVersionTable.PSVersion -ge (Get-Version "5.1")} catch {$Session.EnableColors = $false}

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
        Write-Log -Level Error "Cannot run RainbowMiner: $($_.Exception.Message)"
        $false
    }

    if ($IsWindows) {
        Write-Host "Unblocking files .. " -NoNewline
        try {
            Get-ChildItem ".\Includes" -Recurse | Unblock-File -ErrorAction Stop
            Write-Host "ok" -ForegroundColor Green
        } catch {
            Write-Log "Unblocking files failed: $($_.Exception.Message)"
            Write-Host "failed" -ForegroundColor Red
        }
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
            $CurlTest = Invoke-Exe $CurlPath -ArgumentList "--version" -WaitForExit 10
            if ($CurlTest -match "curl\s+\d+") {$TestOk = $true}
            else {
                $CurlTest = Invoke-Exe $CurlPath -ArgumentList "-G `"https://httpbin.org/status/200`" -H `"accept: text/plain`" --max-time 5 --connect-timeout 3 --ssl-allow-beast --ssl-no-revoke --max-redirs 5 -s -L -q -w `"%{response_code}`"" -WaitForExit 10
                if ($CurlTest -eq "200") {$TestOk = $true}
                else {
                    $CurlTest = Invoke-Exe $CurlPath -ArgumentList "-G `"https://api.rbminer.net/data/hello.txt`" --max-time 5 --connect-timeout 3 --ssl-allow-beast --ssl-no-revoke --max-redirs 5 -s -L -q" -WaitForExit 10
                    if ("$($CurlTest)".Trim() -eq "world") {$TestOk = $true}
                }
            }
            if ($TestOk) {$Session.Curl = $CurlPath}
        }
    } catch {
    }

    if ($Session.Curl) {
        Write-Host "ok$(if (Test-Path ".\curl.txt") {" (permanently enabled by curl.txt file)";$Session.EnableCurl = $true})" -ForegroundColor Green
        Write-Log "Curl $($IsCurl): $($Session.Curl)"
    } else {
        Write-Host "not found" -ForegroundColor Red
        $Session.EnableCurl = $false
    }

    $PauseByError = $false

    try {
        Write-Host "Detecting devices .. " -NoNewline
        $Global:DeviceCache.AllDevices = @(Get-Device "cpu","gpu" -IgnoreOpenCL -Refresh | Where-Object { $_ })
        $Session.PhysicalCPUs = $Global:GlobalCPUInfo.PhysicalCPUs
        $Session.IsARM        = $Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM
        $CPUFound   = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "CPU"} | Measure-Object).Count
        $NVFound    = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "NVIDIA"} | Measure-Object).Count
        $AMDFound   = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "AMD"} | Measure-Object).Count
        $INTELFound = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "INTEL"} | Measure-Object).Count
        if ($CPUFound -or $NVFound -or $AMDFound -or $INTELFound) {
            $DevicesFound = @()
            if ($CPUFound)   {$DevicesFound += "$($CPUFound) CPU"}
            if ($NVFound)    {
                $CUDAVersion = $null
                foreach ($Device in $Global:GlobalCachedDevices) {
                    if ($Device.Type -eq "Gpu" -and $Device.Vendor -eq "NVIDIA" -and $Device.OpenCL.PlatformVersion -match "CUDA\s+([\d\.]+)") {
                        $CUDAVersion = $Matches[1]
                        break
                    }
                }
                $Session.CUDAVersion = if ($CUDAVersion -ne "") {$CUDAVersion}else{$false}
                $DevicesFound += "$($NVFound) Nvidia CUDA $($CUDAVersion)"
            }
            if ($AMDFound)   {$DevicesFound += "$($AMDFound) AMD"}
            if ($INTELFound) {$DevicesFound += "$($IntelFound) Intel"}
            Write-Host "$($DevicesFound -join ", ") found" -ForegroundColor Green
        } else {
            Write-Host "none found!" -ForegroundColor Red
        }
    }
    catch {
        Write-Log -Level Error "Device detection failed: $($_.Exception.Message)"
        $PauseByError = $true
    }

    if ($IsWindows -and ($Session.MineOnCPU -ne $false -or $Session.MineOnGPU -ne $false)) {
        $GpuMemSizeMB = if ($Session.MineOnGPU -eq $false) {0} else {(($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -in @("AMD","INTEL","NVIDIA")}).OpenCL.GlobalMemSizeGB | Measure-Object -Sum).Sum*1100}
        $CpuMemSizeMB = if ($Session.MineOnCPU -eq $false) {0} else {[Math]::Max(0,32-(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum/1GB)*1100}
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
                    Write-Log "$($_.Name) is set to initial size $($_.InitialSize) MB and maximum size $($_.MaximumSize) MB"
                }
                $PageFileMaxSize = ($PageFileInfo | Measure-Object -Property MaximumSize -Sum).Sum

                if ($PageFileMaxSize -lt ($GpuMemSizeMB + $CpuMemSizeMB)) {
                    if ($Session.MineOnCPU -eq $null -and $CpuMemSizeMB -gt 0 -and $GpuMemSizeMB -gt 0) {
                        $PageFile_Warn += "Pagefiles may be too small ($($PageFileMaxSize) MB). Set them to a total minimum:"
                        $PageFile_Warn += "- if mining on CPU, only: $($CpuMemSizeMB) MB$(if ($PageFileMaxSize -ge $CpuMemSizeMB) {" (current pagefile is large enough)"})"
                        $PageFile_Warn += "- if mining on GPU, only: $($GpuMemSizeMB) MB$(if ($PageFileMaxSize -ge $GpuMemSizeMB) {" (current pagefile is large enough)"})"
                        $PageFile_Warn += "- if mining on CPU + GPU: $($GpuMemSizeMB + $CpuMemSizeMB) MB"
                    } else {
                        $PageFile_Warn += "Pagefiles are too small ($($PageFileMaxSize) MB). Set them to a total minimum of $($CpuMemSizeMB + $GpuMemSizeMB) MB"
                    }
                }
            } else {
                $PageFile_Warn += "No pagefile found"
            }
            if ($PageFile_Warn) {
                Write-Host "Problem!" -ForegroundColor Red
                $PageFile_Warn | Where-Object {$_} | Foreach-Object {Write-Log -Level Warn "$_"}
                Write-Host " "
                Write-Host "To adjust your pagefile settings:" -BackgroundColor Yellow -ForegroundColor Black
                Write-Host "1. goto Computer Properties -> Advanced System Settings -> Performance -> Advanced -> Virtual Memory" -ForegroundColor Yellow
                Write-Host "2. uncheck `"Automatically manage paging file size for all drives`"" -ForegroundColor Yellow
                Write-Host "3. select `"Custom size`"" -ForegroundColor Yellow
                Write-Host "4. enter $($CpuMemSizeMB + $GpuMemSizeMB) into the fields `"Initial Size (MB)`" and `"Maximum Size (MB)`"" -ForegroundColor Yellow
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
                    try {$InstallNVSMI_Job | Stop-Job -PassThru | Receive-Job > $null} catch {}
                } else {
                    try {
                        $InstallNVSMI_Result = Receive-Job -Job $InstallNVSMI_Job
                        if ($InstallNVSMI_Result) {
                            $InstallNVSMI_Result | Foreach-Object {
                                if ($_ -match "^WARNING:\s*(.+)$") {
                                    Write-Log -Level Warn $Matches[1]
                                } elseif ($_ -match "^SUCCESS:\s*(.+)$") {
                                    Write-Host $Matches[1] -ForegroundColor Green
                                    Write-Log $Matches[1]
                                } else {
                                    Write-Host $_
                                    Write-Log $_
                                }
                            }
                        }
                    } catch {}
                }
                try {Remove-Job $InstallNVSMI_Job -Force} catch {}
            }
        } catch {
            Write-Log -Level Warn "Failed to check NVSMI: $($_.Exception.Message)"
        }
    }

    try {
        Write-Host "Initialize configuration .."

        Set-PresetDefault

        if (-not (Test-Path $ConfigFile)) {
            $Parameters = [PSCustomObject]@{VersionCompatibility=$Session.Version}
            $Session.DefaultValues.Keys | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction Ignore -Force}
            Set-ContentJson -PathToFile $ConfigFile -Data $Parameters > $null        
        } else {
            @($ConfigFile) + @(Get-ChildItem $ConfigPath -Directory | Where-Object {$ConfigFileSub = Join-Path $_.FullName "config.txt";$_.Name -ne "Backup" -and $ConfigFileSub -and (Test-Path $ConfigFileSub)} | Foreach-Object {$ConfigFileSub} | Select-Object) | Foreach-Object {
                $ConfigForUpdate = $null
                $ConfigFileForUpdate = $_
                try {
                    $ConfigForUpdate = Get-ContentByStreamReader $ConfigFileForUpdate | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-Log -Level Warn "The file $ConfigFileForUpdate contains JSON syntax errors: $($_.Exception.Message)"
                    $ConfigForUpdate = $null
                }
                if ($ConfigForUpdate -is [PSCustomObject]) {
                    $ConfigForUpdate_changed = $false
                    if ($ConfigForUpdate.PSObject.Properties.Name -icontains "LocalAPIport") {$ConfigForUpdate | Add-Member APIport $ConfigForUpdate.LocalAPIport -Force}
                    $MPHLegacyUpdate = if ($ConfigForUpdate.PSObject.Properties.Name -icontains "API_ID") {@{UserName=$ConfigForUpdate.UserName;API_ID=$ConfigForUpdate.API_ID;API_Key=$ConfigForUpdate.API_Key}}
                    Compare-Object @($ConfigForUpdate.PSObject.Properties.Name | Select-Object) @($Session.DefaultValues.Keys) | Foreach-Object {
                        if ($_.SideIndicator -eq "=>") {$ConfigForUpdate | Add-Member $_.InputObject "`$$($_.InputObject)";$ConfigForUpdate_changed=$true}
                        elseif ($_.SideIndicator -eq "<=" -and @("API_ID","API_Key","UserName","LocalAPIport","RemoteAPI","ConfigFile","ExcludeNegativeProfit","DisableAutoUpdate","Regin","Debug","Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable") -icontains $_.InputObject) {[void]$ConfigForUpdate.PSObject.Properties.Remove($_.InputObject);$ConfigForUpdate_changed=$true}
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

    }
    catch {
        Write-Log -Level Error "Please check your configuration: $($_.Exception.Message)"
        $PauseByError = $true
    }

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
                            try {$Cleanup_Job | Stop-Job -PassThru | Receive-Job > $null} catch {}
                        } else {
                            try {
                                $Cleanup_Result = Receive-Job -Job $Cleanup_Job
                                if ($Cleanup_Result) {
                                    $Cleanup_Result | Foreach-Object {
                                        if ($_ -match "^WARNING:\s*(.+)$") {
                                            Write-Log -Level Warn $Matches[1]
                                        } elseif ($_ -match "^SUCCESS:\s*(.+)$") {
                                            Write-Host $Matches[1] -ForegroundColor Green
                                            Write-Log $Matches[1]
                                        } else {
                                            Write-Host $_
                                            Write-Log $_
                                        }
                                    }
                                }
                            } catch {}
                        }
                        try {Remove-Job $Cleanup_Job -Force} catch {}
                    }
                }
            }
    } catch {
        Write-Log -Level Warn "Cleanup failed: $($_.Exception.Message)"
    }

    try {
        #if linux and running as root re-install libraries and binaries
        if ($IsLinux -and (Test-Path ".\IncludesLinux\linux.updated") -and (Test-Path ".\install.sh")) {
            if ($Session.IsAdmin) {
                Write-Host "Re-installing libraries and binaries .."
                bash -c "./install.sh"
            } else {
                foreach ($Linux_Path in @("bash","bin")) {
                    $Linux_Path = Join-Path "./IncludesLinux" $Linux_Path
                    if (Test-Path $Linux_Path) {
                        Get-ChildItem $Linux_Path -Filter "*" -File | Foreach-Object {
                            (Start-Process "chmod" -ArgumentList "+x", $_.FullName -PassThru).WaitForExit(1000) > $null
                        }
                    } else {
                        Write-Log -Level Error "$($Linux_Path) is missing! Please re-install RainbowMiner!"
                    }
                }
                Write-Log -Level Warn "RainbowMiner has updated some linux libraries/binaries. Please run ./install.sh as soon as possible!"
            }
        }
    } catch {
        Write-Log -Level Warn "Re-install failed: $($_.Exception.Message)"
    }

    try {
        if ($IsLinux -and $Linux_Libs -and $Session.CUDAVersion) {

            $CUDAVersion = "$(if ($Session.CUDAVersion -match "^(\d+\.\d+)") {$Matches[1]} else {$Session.CUDAversion})"

            Write-Host "Checking for local CUDA $($CUDAVersion) libraries .. "

            $Linux_CudaLatest = @{}

            $Linux_Libs.PSObject.Properties | Where-Object {$_.Name -match "^(libcudart|libnvrtc|libnvrtc-builtins)\.so\.(\d+).(\d+)$"} | Foreach-Object {
                $Cuda_MainVer = "$($Matches[1]).so.$($Matches[2])"
                $Cuda_CurrVer = "$($Matches[2]).$($Matches[3])"
                if (-not $Linux_CudaLatest.$Cuda_MainVer) {$Linux_CudaLatest[$Cuda_MainVer] = [PSCustomObject]@{CUDAVersion = $Cuda_CurrVer; Library = $_.Value}}
                if ($Linux_CudaLatest[$Cuda_MainVer].CUDAVersion -ne $CUDAVersion -and ($Cuda_CurrVer -eq $CUDAVersion -or (Get-Version $Linux_CudaLatest[$Cuda_MainVer].CUDAVersion) -lt (Get-Version $Cuda_CurrVer))) {
                    $Linux_CudaLatest[$Cuda_MainVer].CUDAVersion = $Cuda_CurrVer
                    $Linux_CudaLatest[$Cuda_MainVer].Library     = $_.Value
                }
            }

            $Linux_CudaLatest.GetEnumerator() | Foreach-Object {
                $Lib_Dest   = Join-Path $Linux_LibDir2 $_.Value.Library
                $Lib_Link   = Join-Path $Linux_LibDir2 $_.Name
                                                     
                if (-not (Test-Path $Lib_Link) -or (Get-Item $Lib_Link).LinkTarget -ne $Lib_Dest) {
                    $errmsg = "failed"
                    try {
                        Invoke-Exe -FilePath "ln" -ArgumentList "-sf $($Lib_Dest) $($Lib_Link)" -Runas:$Linux_LibRunas > $null
                    } catch {
                        $errmsg = $_.Exception.Message
                    }
                    if ((Test-Path $Lib_Link) -and (Get-Item $Lib_Link).LinkTarget -eq $Lib_Dest) {$errmsg = "ok"}
                    Write-Host ".. create link $($Lib_Link) -> $($Lib_Dest) " -NoNewline
                    Write-Host $errmsg -ForegroundColor "$(if ($errmsg -eq "ok") {"green"} else {"red"})"
                    Write-Log -Level Info "Create link $($Lib_Link) -> $($Lib_Dest) $($errmsg)"
                }

                if ($CUDAVersion -eq $_.Value.CUDAVersion) {
                    $Lib_Link2 = $Lib_Link -replace "\.\d+$"
                    if ($Lib_Link2 -ne $Lib_Link -and (-not (Test-Path $Lib_Link2) -or (Get-Item $Lib_Link2).LinkTarget -ne $Lib_Dest)) {
                        $errmsg = "failed"
                        try {
                            Invoke-Exe -FilePath "ln" -ArgumentList "-sf $($Lib_Dest) $($Lib_Link2)" -Runas:$Linux_LibRunas > $null
                        } catch {
                            $errmsg = $_.Exception.Message
                        }
                        if ((Test-Path $Lib_Link2) -and (Get-Item $Lib_Link2).LinkTarget -eq $Lib_Dest) {$errmsg = "ok"}
                        Write-Host ".. create link $($Lib_Link2) -> $($Lib_Dest) " -NoNewline
                        Write-Host $errmsg -ForegroundColor "$(if ($errmsg -eq "ok") {"green"} else {"red"})"
                        Write-Log -Level Info "Create link $($Lib_Link2) -> $($Lib_Dest) $($errmsg)"
                    }
                }
            }
        }
    } catch {
        Write-Log -Level Warn "Installation of local CUDA libraries failed: $($_.Exception.Message)"
    }

    try {
        #Remove stuck update
        if (Test-Path "Start.bat.saved") {Remove-Item "Start.bat.saved" -Force -ErrorAction Ignore}
    }
    catch {
    }

    try {
        #Read miner info
        if (Test-Path ".\Data\minerinfo.json") {try {(Get-ContentByStreamReader ".\Data\minerinfo.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Foreach-Object {$Global:MinerInfo[$_.Name] = $_.Value}} catch {}}
        if (Test-Path ".\Data\minerspeeds.json") {try {(Get-ContentByStreamReader ".\Data\minerspeeds.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Foreach-Object {$Global:MinerSpeeds[$_.Name] = $_.Value}} catch {}}

        #write version to data
        Set-ContentJson -PathToFile ".\Data\version.json" -Data ([PSCustomObject]@{Version=$Session.Version}) > $null
    }
    catch {
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
    $Session.Updatetracker = [hashtable]@{
        Balances   = 0
        TimeDiff   = 0
        MinerSave  = if (Test-Path ".\Data\minerdata.json") {Get-ChildItem ".\Data\minerdata.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
        PoolsSave  = if (Test-Path ".\Data\poolsdata.json") {Get-ChildItem ".\Data\poolsdata.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
        SpeedsSave = if (Test-Path ".\Data\minerspeeds.json") {Get-ChildItem ".\Data\minerspeeds.json" | Select-Object -ExpandProperty LastWriteTime} else {0}
        ReportDeviceData = 0
    }

    #Load databases, that only need updates once in a while
    Get-WorldCurrencies -Silent -EnableRemoteUpdate

    if (-not $Session.SetupOnly) {
        #Check for unclean shutdown
        try {
            Write-Host "Checking last shutdown .. " -NoNewline
            if (Test-Path ".\Data\rbm.pid") {
                Write-Host "crashed" -ForegroundColor Red
                $Session.ReportUnclean = $true
            } else {
                Write-Host "ok" -ForegroundColor Green
            }

            $PID | Out-File ".\Data\rbm.pid"
        } catch {
        }

        #Cleanup database
        @("newpools.json") | Foreach-Object {
            Get-ChildItem ".\Data" -Filter $_ -File | Foreach-Object { Remove-Item $_.FullName -Force }
        }
    }

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

    #Update databases every 40 rounds
    if (-not ($Session.RoundCounter % 40)) {
        Get-AlgorithmMap -Silent
        Get-AlgoVariants -Silent
        Get-Algorithms -Silent
        Get-CoinsDB -Silent
        Get-EquihashCoins -Silent
        Get-EthDAGSizes -Silent -EnableRemoteUpdate:($Session.RoundCounter -gt 0)
        Get-NimqHashrates -Silent
        Get-Regions -Silent
        Get-Regions2 -Silent

        #cleanup Active Miners
        #$activeTime = (Get-Date).AddHours(-12)
        #$Global:ActiveMiners.RemoveAll({ param($m) $m.AccessLast -and $m.AccessLast -lt $activeTime }) > $null

        #cleanup cache
        if ($Session.RoundCounter -gt 0) {
            try {
                $bindingType = [System.Management.Automation.PSObject].Assembly.GetType("System.Management.Automation.Language.PSInvokeMemberBinder")
                if ($bindingType) {
                    $cacheField = $bindingType.GetField("s_binderCache", "NonPublic, Static")
                    if ($cacheField) {
                        $cache = $cacheField.GetValue($null)
                        if ($cache -is [object] -and $cache.PSObject.Methods["Clear"]) {
                            $cache.Clear()
                            Write-Log -Level Info "Cache cleared :)"
                        }
                    }
                }
            } catch {
                Write-Log -Level Info "Cache clear failed :("
            }
        }
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
                    [void]$Parameters.Add($_ , $val)
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

                $ConfigSetup = $null
                $Parameters = $null
                Remove-Variable -Name ConfigSetup, Parameters -ErrorAction Ignore

                if (-not $Session.Config.WorkerName) {
                    $Session.RunSetup = $true
                } else {
                    if (Set-Proxy -Proxy "$($Session.Config.Proxy -replace "^`$Proxy$")" -Username "$($Session.Config.ProxyUsername -replace "^`$ProxyUsername$")" -Password "$($Session.Config.ProxyPassword -replace "^`$ProxyPassword$")") {
                        if ($Session.RoundCounter -gt 0 -and (Test-Path Variable:Global:AsyncLoader)) {
                            if ((Test-Path Variable:Global:AsyncLoader) -and -not $AsyncLoader.Pause) {$AsyncLoader.Pause = $true}
                            $RestartRunspaces = $true
                        }
                        Write-Log "Proxy settings have changed: Restarting HttpClient$(if ($RestartRunspaces) {" and Runspaces"})"
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
        if ($Session.RoundCounter -ne 0) {Write-Log "Updating config data"}

        #begin backwards compatibility
        if ($Session.Config.Type -ne $null) {$Session.Config | Add-Member DeviceName $Session.Config.Type -Force;$Session.Config | Add-Member ExcludeDeviceName @() -Force}
        if ($Session.Config.GPUs -ne $null -and $Session.Config.GPUs) {
            if ($Session.Config.GPUs -is [string]) {$Session.Config.GPUs = [regex]::split($Session.Config.GPUs,"\s*[,;]+\s*")}
            $Session.Config | Add-Member DeviceName @() -Force
            $Session.Config | Add-Member ExcludeDeviceName @() -Force
            Get-Device "nvidia" | Where-Object {$Session.Config.GPUs -contains $_.Type_Vendor_Index} | Foreach-Object {$Session.Config.DeviceName += [string]("GPU#{0:d2}" -f $_.Type_Vendor_Index)}
        }
        if ("$($Session.Config.SSL)" -ne '' -and "$($Session.Config.SSL)" -notmatch "^[012]$") {$Session.Config.SSL = [int](Get-Yes $Session.Config.SSL)}
        #end backwards compatibility

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
        if ($Session.Config.EnableAlgorithmVariants) {
            if ($Session.Config.Algorithm.Count) {
                $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Algorithm} | Foreach-Object {
                    $Session.Config.Algorithm = @($Session.Config.Algorithm + $_.Value | Select-Object -Unique)
                }
            }
            if ($Session.Config.ExcludeAlgorithm.Count) {
                $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.ExcludeAlgorithm} | Foreach-Object {
                    $Session.Config.ExcludeAlgorithm = @($Session.Config.ExcludeAlgorithm + $_.Value | Select-Object -Unique)
                }
            }
        }
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
        $Session.Config.FastlaneBenchmarkTypeGPU = if ($Session.Config.FastlaneBenchmarkTypeGPU -in @("avg","min","max")) {$Session.Config.FastlaneBenchmarkTypeGPU} else {"avg"}
        $Session.Config.RestartRBMTimespan = ConvertFrom-Time $Session.Config.RestartRBMTimespan
        $Session.Config.RestartRBMMemory   = ConvertFrom-Bytes $Session.Config.RestartRBMMemory
        if ($Session.Config.BenchmarkInterval -lt 60) {$Session.Config.BenchmarkInterval = 60}
        if ($Session.Config.OCResetInterval -gt 0 -and $Session.Config.OCResetInterval -lt 600) {$Session.Config.OCResetInterval = 600}
        if (-not $Session.Config.APIport) {$Session.Config | Add-Member APIport 4000 -Force}
        if ($Session.Config.RestartRBMTimespan -lt 3600) {$Session.Config.RestartRBMTimespan = 0}
        if ($Session.Config.RestartRBMMemory -lt 367001600) {$Session.Config.RestartRBMMemory = 0}

        if ($IsLinux) {
            if ($Session.Config.LinuxMinerTerminal -notin @("auto","screen","tmux")) {
                $Session.Config.LinuxMinerTerminal = "auto"
            } 
            
            if ($Session.Config.LinuxMinerTerminal -ne "auto") {
                foreach ( $lxterm in @("screen","tmux") ) {
                    if ($Session.Config.LinuxMinerTerminal -eq $lxterm -and -not (Get-Command $lxterm -ErrorAction Ignore)) {
                        Write-Log -Level Warn "config.txt: LinuxMinerTerminal=`"$($lxterm)`" but $($lxterm) command not available, switching to auto"
                        $Session.Config.LinuxMinerTerminal = "auto"
                    }
                }
            }
        }

        Set-ContentJson -PathToFile ".\Data\localapiport.json" -Data @{LocalAPIport = $Session.Config.APIport} > $null

        #For backwards compatibility        
        if ($Session.Config.LegacyMode -ne $null) {$Session.Config.MiningMode = if (Get-Yes $Session.Config.LegacyMode){"legacy"}else{"device"}}
        if (-not $Session.CurrentInterval) {$Session.CurrentInterval = $Session.Config.Interval}
        if ($Session.Config.MaxRejectedShareRatio -eq $null) {$Session.Config | Add-Member MaxRejectedShareRatio $Session.DefaultValues["MaxRejectedShareRatio"] -Force}
        elseif ($Session.Config.MaxRejectedShareRatio -lt 0) {$Session.Config.MaxRejectedShareRatio = 0}
        elseif ($Session.Config.MaxRejectedShareRatio -gt 1) {$Session.Config.MaxRejectedShareRatio = 1}

        #Speed up restart
        if (-not $Session.RoundCounter -and -not $Session.Config.Quickstart -and (Test-Path ".\Logs\timerpools.json") -and (Get-ChildItem ".\Logs\timerpools.json" -ErrorAction Ignore | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-3)} | Measure-Object).Count) {$Session.Config.Quickstart = $true}

        if ($Session.CurrentPowerPrice -eq $null) {$Session.CurrentPowerPrice = Get-PowerPrice}

        $Session.LogLevel = $Session.Config.LogLevel

        $EnableCurl = $Session.EnableCurl
        $Session.EnableCurl = $Session.Curl -and ($Session.Config.EnableCurl -or (Test-Path ".\curl.txt"))
        if ($EnableCurl -ne $Session.EnableCurl) {
            Write-Log "cURL $(if ($Session.EnableCurl) {"enabled"} else {"disabled"})"
        }

        #crosscheck for invalid cpu mining parameters to avoid system overload
        if ($Session.Config.DeviceName -match "^CPU") {
            $CPUAffinityInt = (ConvertFrom-CPUAffinity "$($Session.Config.CPUMiningAffinity)" -ToInt) -band (Get-CPUAffinity $Global:GlobalCPUInfo.Threads -ToInt)
            if ($CPUAffinityInt -eq 0) {
                $CPUThreads = if ($Session.Config.CPUMiningThreads -gt 0) {$Session.Config.CPUMiningThreads} else {$Global:GlobalCPUInfo.RealCores.Count}
                $CPUAffinityInt = Get-CPUAffinity $CPUThreads -ToInt
                Write-Log -Level "$(if ($Session.RoundCounter -eq 0) {"Warn"} else {"Info"})" "Parameter CPUMiningAffinity (config.txt) is empty or contains errors. Falling back to $(Get-CPUAffinity $CPUThreads -ToHex)"
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
    if ($Session.Config.DisableInternetCheck) {
        $Internet_ok = $true
    } else {
        $Internet_ok = Test-Internet -CheckDomains $Session.Config.WebsitesForOnlineCheck
    }

    if (-not $RestartRunspaces) {
        if (-not $Internet_ok) {
            Write-Log "Internet is down"

            if ((Test-Path Variable:Global:AsyncLoader) -and -not $AsyncLoader.Pause) {$AsyncLoader.Pause = $true}

            $StopWatch_Outer = [System.Diagnostics.StopWatch]::New()
            $StopWatch_Inner = [System.Diagnostics.StopWatch]::New()

            $WarnedConsole = $false

            do {                
                Write-Log -Level Warn "Waiting 30s for internet connection. Press [X] to exit RainbowMiner"

                $StopWatch_Outer.Restart()
                $StopWatch_Inner.Restart()

                do {
                    $keyPressedValue = if (-not $WarnedConsole) {
                        try {
                            if ([console]::KeyAvailable) {
                                $([System.Console]::ReadKey($true)).key
                            }
                        } catch {
                            $WarnedConsole = $true
                        }
                    }
                    if ($StopWatch_Inner.Elapsed.TotalSeconds -ge 10) {
                        $Internet_ok = Test-Internet -CheckDomains $Session.Config.WebsitesForOnlineCheck
                        $StopWatch_Inner.Restart()
                    }
                    Start-Sleep -Milliseconds 250
                } until ($Internet_ok -or $keyPressedValue -eq "X" -or $StopWatch_Outer.Elapsed.Seconds -ge 30)

            } until ($Internet_ok -or $keyPressedValue -eq "X")

            if ($keyPressedValue -eq "X") {
                Write-Log "User requests to stop script. "
                Write-Host "[X] pressed - stopping script."
                break
            }
            if ($i -gt $Session.Config.BenchmarkInterval*2) {
                Update-WatchdogLevels -Reset
                $Global:WatchdogTimers.Clear()
            }

            $StopWatch_Inner.Stop()
            $StopWatch_Outer.Stop()

            $StopWatch_Inner = $null
            $StopWatch_Outer = $null
        }

        if ($Internet_ok) {
            if ($Session.Config.DisableInternetCheck) {
                Write-Log "Internet check is disabled"
            } else {
                Write-Log "Internet is ok"
            }
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
    if ($Session.RoundCounter -eq 0 -or $Session.Config.PowerCPUtdp -ne $ConfigBackup.PowerCPUtdp) {
        if ($Session.RoundCounter -eq 0) {
            Write-Host "Starting sysinfo .. " -NoNewline
        }
        $SysInfo_Ok = Start-SysInfo
        if ($Session.RoundCounter -eq 0) {
            if ($SysInfo_Ok) {Write-Host "ok" -ForegroundColor Green}
            else {Write-Host "error" -ForegroundColor Red}
        }
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
        $API.MaxLoginAttemps = $Session.Config.APImaxLoginAttemps
        $API.BlockLoginAttemptsTime = ConvertFrom-Time $Session.Config.APIblockLoginAttemptsTime
        $API.AllowIPs = $Session.Config.APIallowIPs
        $API.MachineName = $Session.MachineName
    }

    if ($CheckConfig -or $Session.RoundCounter -eq 0) {Set-APIConfig}

    $API.PauseMiners.Pause       = $Global:PauseMiners.Test()
    $API.PauseMiners.PauseIA     = $Global:PauseMiners.TestIA()
    $API.PauseMiners.PauseIAOnly = $Global:PauseMiners.TestIAOnly()

    $API.CmdKey = ''

    if (Test-Path ".\Data\sysinfo.json") {
        try {
            $Session.SysInfo = Get-ContentByStreamReader ".\Data\sysinfo.json" | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Log "SysInfo.json contains syntax error: $($_.Exception.Message)"
        }
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

    $PowerPriceCurrency = if ($Session.Config.OctopusTariffCode -ne '') {"GBP"} else {$Session.Config.PowerPriceCurrency}

    if ($CheckConfig) {
        $PoolSetup = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1"
        $AutoexPools = [PSCustomObject]@{}
        $PoolSetup.PSObject.Properties | Where-Object {$_.Value.Autoexchange} | Foreach-Object {
            $AutoexPools | Add-Member $_.Name $_.Value.Autoexchange
        }
        $API.Info = ConvertTo-Json ([PSCustomObject]@{
                                Version                = $ConfirmedVersion.Version
                                RemoteVersion          = $ConfirmedVersion.RemoteVersion
                                ManualURI              = $ConfirmedVersion.ManualURI
                                WorkerName             = $Session.Config.WorkerName
                                EnableAlgorithmMapping = $Session.Config.EnableAlgorithmMapping
                                AlgorithmMap           = (Get-AlgorithmMap)
                                AutoexPools            = $AutoexPools
                                OCmode                 = $Session.OCmode
                                UsePowerPrice          = $Session.Config.UsePowerPrice
                                PowerPriceCurrency     = $PowerPriceCurrency
                                FixedCostPerDay        = $Session.Config.FixedCostPerDay
                                DecSep                 = (Get-Culture).NumberFormat.NumberDecimalSeparator
                                IsWindows              = $Global:IsWindows
                                IsLinux                = $Global:IsLinux
                                IsLocked               = $Session.Config.APIlockConfig
                                IsServer               = $Session.Config.RunMode -eq "Server"
                            }) -Depth 10
        $API.CPUInfo = ConvertTo-Json $Global:GlobalCPUInfo -Depth 10
        $PoolSetup = $null
        $AutoexPools = $null
    }

    #automatic fork detection
    if (Test-Path ".\Data\forksdb.json") {
        try {

            $ForksDB = Get-ContentByStreamReader ".\Data\forksdb.json" | ConvertFrom-Json -ErrorAction Stop

            $ForksDB_changed = $false

            $ForksDB | Where-Object {$_.active} | Foreach-Object {
                $Fork_Meets_Target = $false
                if ($_.date) {
                    $Fork_Meets_Target = (Get-Date) -ge [datetime]::Parse($_.date)
                } elseif ($_.height) {
                    $Fork_Request = [PSCustomObject]@{}
                    try {
                        $Fork_Request = Invoke-RestMethodAsync $_.rpc -Timeout 15 -cycletime 120 -JobKey "fork$($_.symbol)"
                        if ($Fork_Request -is [string] -and $Fork_Request -match "^{.+}$") {
                            $Fork_Request = ConvertFrom-Json "$($Fork_Request.ToLower())" -ErrorAction Stop
                        }

                        if ($_.verify -eq $null -or "$(Invoke-Expression "`$Fork_Request.$($_.verify)")" -eq $_.verify_value) {
                            $val = $null

                            if ($_.data -eq $null) {
                                $val = $Fork_Request
                            } else {
                                $_.data -split "\." | Foreach-Object {
                                    if ($_ -match '^(.+)\[([^\]]+)\]$') {
                                        $val = if ($val -ne $null) {$val."$($Matches[1])"} else {$Fork_Request."$($Matches[1])"}
                                        $arrp = [RBMToolBox]::Split($Matches[2],"=",2)
                                        if ($arrp[0] -match '^\d+$') {
                                            $val = $val[[int]$arrp[0]]
                                        } else {
                                            $val = $val | ?{$_."$($arrp[0])" -eq $arrp[1]}
                                        }
                                    } else {
                                        $val = if ($val -ne $null) {$val.$_} else {$Fork_Request.$_}
                                    }
                                }
                            }
                            if ("$($val)".Trim() -match "^\d+$") {
                                $Fork_Meets_Target = [int64]$val -ge $_.height
                            }
                        }
                    } catch {
                    }
                    $Fork_Request = $null
                }

                if ($Fork_Meets_Target) {
                    $CoinsDB = Get-ContentByStreamReader ".\Data\coinsdb.json" | ConvertFrom-Json -ErrorAction Ignore
                    if ($CoinsDB.PSObject.Properties.Name.Contains($_.symbol)) {
                        $CoinsDB."$($_.symbol)".Algo = Get-Algorithm $_.algorithm
                        $CoinsDB | ConvertTo-Json -Compress | Set-Content ".\Data\coinsdb.json"
                        Get-CoinsDB -Silent -Force
                        Stop-AsyncJob "fork$($_.symbol)"
                        $_.active = $false
                        $ForksDB_changed = $true
                        Write-Log -Level Warn "Alert: coin $($_.symbol) forked! CoinsDB successfully updated."
                    }
                    $CoinsDB = $null
                }
            }

            if ($ForksDB_changed) {
                $ForksDB | ConvertTo-Json -ErrorAction Stop | Set-Content ".\Data\forksdb.json"
            }

            if (-not ($ForksDB | Where-Object {$_.active} | Measure-Object).Count -and (Test-Path ".\Data\forksdb.json")) {
                Remove-Item “.\Data\forksdb.json" -Force
            }
        } catch {
        }
    }

    #manual fork detection
    if ((Test-Path ".\Data\coinsdb-fork.json") -or (Test-Path ".\Data\algorithms.json")) {
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

                #$Request = Invoke-RestMethodAsync "https://explorer.ironfish.network/api/blocks/head" -tag "fork" -timeout 15 -cycletime 120
                #if ([int64]$Request.sequence -ge 503338) {
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
                    [void]$Session.ConfigFiles.Remove("$Folder_Name/$_")
                }
            }
        }
    }

    #Check for algorithms config
    if (Set-ConfigDefault "Algorithms") {
        if ($CheckConfig -or -not $Session.Config.Algorithms -or (Test-Config "Algorithms" -LastWriteTime) -or ($ConfigBackup.Algorithms -and -not [RBMToolBox]::CompareObject($Session.Config.Algorithms,$ConfigBackup.Algorithms))) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating algorithms config data"}
            $AllAlgorithms = Get-ConfigContent "Algorithms" -UpdateLastWriteTime
            if (Test-Config "Algorithms" -Health) {
                $Session.Config | Add-Member Algorithms ([PSCustomObject]@{}) -Force
                $Global:AlgorithmMinerName.Clear()

                $EmptyObject = $null

                foreach ( $a in $AllAlgorithms.PSObject.Properties.Name ) {
                    if ($Session.Config.Algorithm.Count -and $Session.Config.Algorithm -notcontains $a) { continue }
                    #$Algo_MRRPriceModifierPercent = "$($AllAlgorithms.$a.MRRPriceModifierPercent -replace "[^\d\.\-]+")"
                    $Algo_MaxTimeToFind           = (ConvertFrom-Time $AllAlgorithms.$a.MaxTimeToFind)
                    $newAlgo = $null
                    $newAlgo = [PSCustomObject]@{
                        Penalty                 = ([Math]::Round([double]($AllAlgorithms.$a.Penalty -replace "[^\d\.\-]+"),2))
                        MinHashrate             = (ConvertFrom-Hash $AllAlgorithms.$a.MinHashrate)
                        MinHashrateSolo         = (ConvertFrom-Hash $AllAlgorithms.$a.MinHashrateSolo)
                        MinWorkers              = (ConvertFrom-Hash $AllAlgorithms.$a.MinWorkers)
                        MaxTimeToFind           = $Algo_MaxTimeToFind
                        MSIAprofile             = ([int]$AllAlgorithms.$a.MSIAprofile)
                        OCProfile               = "$($AllAlgorithms.$a.OCProfile)".Trim()
                        MinBLKRate              = $(if ($Algo_MaxTimeToFind) {86400/$Algo_MaxTimeToFind} else {0})
                        #MRREnable               = $(if ($AllAlgorithms.$a.MRREnable -ne $null) {Get-Yes $AllAlgorithms.$a.MRREnable} else {$true})
                        #MRRAllowExtensions      = $(if ($AllAlgorithms.$a.MRRAllowExtensions -ne "" -and $AllAlgorithms.$a.MRRAllowExtensions -ne $null) {Get-Yes $AllAlgorithms.$a.MRRAllowExtensions} else {$null})
                        #MRRPriceModifierPercent = $(if ($Algo_MRRPriceModifierPercent -ne "") {[Math]::Max(-30,[Math]::Min(30,[Math]::Round([double]$Algo_MRRPriceModifierPercent,2)))} else {$null})
                        MinerName               = @(if ($AllAlgorithms.$a.MinerName){[regex]::split("$($AllAlgorithms.$a.MinerName)".Trim(),"\s*[,;]+\s*") | Where-Object {$_}})
                        ExcludeMinerName        = @(if ($AllAlgorithms.$a.ExcludeMinerName){[regex]::split("$($AllAlgorithms.$a.ExcludeMinerName)".Trim(),"\s*[,;]+\s*") | Where-Object {$_}})
                    }

                    if ($EmptyObject -eq $null) {
                        $isEmpty = $true
                        foreach( $prop in $newAlgo.PSObject.Properties.Name ) {
                            if ($newAlgo.$prop) {
                                $isEmpty = $false
                                break
                            }
                        }

                        if ($isEmpty) {
                            $EmptyObject = $newAlgo
                        }

                    } elseif ([RBMToolBox]::CompareObject($EmptyObject,$newAlgo)) {
                        $newAlgo = $null
                        $newAlgo = $EmptyObject
                    }

                    $Session.Config.Algorithms | Add-Member $a $newAlgo -Force
                    
                    if ($Session.Config.Algorithms.$a.MinerName.Count -or $Session.Config.Algorithms.$a.ExcludeMinerName.Count) {
                        [void]$Global:AlgorithmMinerName.Add($a)
                    }
                }
            }

            $AllAlgorithms = $EmptyObject = $newAlgo = $null
            Remove-Variable -Name AllAlgorithms,EmptyObject,newAlgo -ErrorAction Ignore
        }
    }

    #Check for coins config
    $CheckCoins = $false
    if (Set-ConfigDefault "Coins") {
        if ($CheckConfig -or -not $Session.Config.Coins -or (Test-Config "Coins" -LastWriteTime) -or ($ConfigBackup.Coins -and -not [RBMToolBox]::CompareObject($Session.Config.Coins,$ConfigBackup.Coins))) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating coins config data"}
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
                        MinHashrateSolo  = (ConvertFrom-Hash $Session.Config.Coins.$c.MinHashrateSolo)
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
            $AllCoins = $null
            Remove-Variable -Name AllCoins -ErrorAction Ignore
        }
    }

    #Check for oc profile config
    if (Set-ConfigDefault "OCProfiles") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.OCProfiles -or (Test-Config "OCProfiles" -LastWriteTime))) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating ocprofiles config data"}
            $AllOCProfiles = Get-ConfigContent "OCProfiles" -UpdateLastWriteTime
            if (Test-Config "OCProfiles" -Health) {
                $Session.Config | Add-Member OCProfiles $AllOCProfiles -Force
            }

            $AllOCProfiles = $null
            Remove-Variable -Name AllOCProfiles -ErrorAction Ignore
        }
    }

    #Check for scheduler config
    if (Set-ConfigDefault "Scheduler") {
        if ($CheckConfig -or $Session.Config.Scheduler -eq $null -or (Test-Config "Scheduler" -LastWriteTime)) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating scheduler config data"}
            $AllScheduler = Get-ConfigContent "Scheduler" -UpdateLastWriteTime
            if (Test-Config "Scheduler" -Health) {
                if ($AllScheduler -isnot [array] -and $AllScheduler.value -ne $null) {$AllScheduler = $AllScheduler.value}
                $Session.Config | Add-Member Scheduler ([System.Collections.Generic.List[PSCustomObject]]::new()) -Force
                $AllScheduler | Foreach-Object {
                    $_ | Add-Member Name "$($_.Name)" -Force
                    $_ | Add-Member DayOfWeek $([string]("$($_.DayOfWeek -replace "[^0-6\*]+")"[0])) -Force
                    $_ | Add-Member From $(Get-HourMinStr $_.From) -Force
                    $_ | Add-Member To   $(Get-HourMinStr $_.To -to) -Force
                    $_ | Add-Member PowerPrice "$($_.PowerPrice -replace ",","." -replace "[^0-9\.]+")" -Force
                    $_ | Add-Member Enable $(Get-Yes $_.Enable) -Force
                    $_ | Add-Member Pause  $(Get-Yes $_.Pause)  -Force
                    $_ | Add-Member EnableUpdate  $(Get-Yes $_.EnableUpdate)  -Force
                    $_ | Add-Member PauseRentals $(Get-Yes $_.PauseRentals) -Force
                    $_ | Add-Member MRRPriceFactor "$($_.MRRPriceFactor -replace ",","." -replace "[^0-9\.]+")" -Force
                    $_ | Add-Member EnableMiningHeatControl $(if ($_.EnableMiningHeatControl -eq "") {$Session.Config.EnableMiningHeatControl} else {Get-Yes $_.EnableMiningHeatControl}) -Force
                    $_ | Add-Member MiningHeatControl "$($_.MiningHeatControl -replace ",","." -replace "[^0-9\.]+")" -Force

                    foreach($q in @("Algorithm","ExcludeAlgorithm","CoinSymbol","ExcludeCoinSymbol","PoolName","ExcludePoolName")) {
                        if ($_.$q -is [string]) {$_.$q = @($_.$q -replace "[^A-Z0-9,;]+" -split "[,;]+" | Where-Object {$_} | Select-Object)}
                        $_ | Add-Member $q @(($_.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
                    }

                    foreach($q in @("Month")) {
                        if ($_.$q -is [string]) {$_.$q = @($_.$q -replace "[^0-9,;\*]+" -split "[,;]+" | Where-Object {$_} | Select-Object)}
                        $_ | Add-Member $q @(($_.$q | Select-Object) | Where-Object {$_} | Foreach-Object {$_} | Select-Object -Unique) -Force
                        if ($_.$q -contains "*" -and $_.$q.Count -gt 1) {$_.$q = @("*")}
                    }

                    if ($Session.Config.EnableAlgorithmVariants) {
                        if ($_.Algorithm.Count) {
                            $SchedulerAlgorithm = $_.Algorithm
                            $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $SchedulerAlgorithm} | Foreach-Object {
                                $SchedulerAlgorithm = @($SchedulerAlgorithm + $_.Value | Select-Object -Unique)
                            }
                            $_.Algorithm = $SchedulerAlgorithm
                        }
                        if ($_.ExcludeAlgorithm.Count) {
                            $SchedulerExcludeAlgorithm = $_.ExcludeAlgorithm
                            $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $SchedulerExcludeAlgorithm} | Foreach-Object {
                                $SchedulerExcludeAlgorithm = @($SchedulerExcludeAlgorithm + $_.Value | Select-Object -Unique)
                            }
                            $_.ExcludeAlgorithm = $SchedulerExcludeAlgorithm
                        }
                    }

                    $PowerPrice = if ($_.PowerPrice -eq "") {Get-PowerPrice} else {$_.PowerPrice}
                    try {$PowerPrice = [Double]$PowerPrice} catch {$PowerPrice = Get-PowerPrice}
                    $_.PowerPrice = $PowerPrice
                    $MiningHeatControl = if ($_.MiningHeatControl -eq "") {$Session.Config.MiningHeatControl} else {$_.MiningHeatControl}
                    try {$MiningHeatControl = [Double]$MiningHeatControl} catch {$MiningHeatControl = $Session.Config.MiningHeatControl}
                    $MiningHeatControl = [Math]::Round([Math]::Max([Math]::Min($MiningHeatControl,5.0),0.0),1)
                    $_.MiningHeatControl = $MiningHeatControl
                    try {$_.MRRPriceFactor = [Double]$_.MRRPriceFactor} catch {$_.MRRPriceFactor = 0}
                    [void]$Session.Config.Scheduler.Add($_)
                }
            }

            $AllScheduler = $null
            Remove-Variable -Name AllScheduler -ErrorAction Ignore
        }
    }

    #Check for devices config
    if (Set-ConfigDefault "Devices") {
        if (-not $Session.IsDonationRun -and ($CheckConfig -or -not $Session.Config.Devices -or (Test-Config "Devices" -LastWriteTime))) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating devices config data"}
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
                    $Session.Config.Devices.$p | Add-Member EnableLHR $(if ("$($Session.Config.Devices.$p.EnableLHR)" -ne "") {Get-Yes $Session.Config.Devices.$p.EnableLHR} else {$null}) -Force
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

                    if ($Session.Config.EnableAlgorithmVariants) {
                        if ($Session.Config.Devices.$p.Algorithm.Count) {
                            $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Devices.$p.Algorithm} | Foreach-Object {
                                $Session.Config.Devices.$p.Algorithm = @($Session.Config.Devices.$p.Algorithm + $_.Value | Select-Object -Unique)
                            }
                        }
                        if ($Session.Config.Devices.$p.ExcludeAlgorithm.Count) {
                            $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Devices.$p.ExcludeAlgorithm} | Foreach-Object {
                                $Session.Config.Devices.$p.ExcludeAlgorithm = @($Session.Config.Devices.$p.ExcludeAlgorithm + $_.Value | Select-Object -Unique)
                            }
                        }
                    }
                }
            }

            $AllDevices = $null
            Remove-Variable -Name AllDevices -ErrorAction Ignore
        }
    }

    #Check for gpugroups config
    if (Set-ConfigDefault "GpuGroups") {
        if ($CheckConfig -or -not $Session.Config.GpuGroups -or (Test-Config "GpuGroups" -LastWriteTime) -or ($ConfigBackup.GpuGroups -and -not [RBMToolBox]::CompareObject($Session.Config.GpuGroups,$ConfigBackup.GpuGroups))) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating gpugroups config data"}
            $AllGpuGroups = Get-ConfigContent "GpuGroups" -UpdateLastWriteTime
            if (Test-Config "GpuGroups" -Health) {
                $Session.Config | Add-Member GpuGroups ([PSCustomObject]@{})  -Force
                $AllGpuGroups.PSObject.Properties.Name | Select-Object | Foreach-Object {
                    $Session.Config.GpuGroups | Add-Member $_ $AllGpuGroups.$_ -Force
                    $CheckGpuGroups = $true
                }
            }
            $AllGpuGroups = $null
            Remove-Variable -Name AllGpuGroups -ErrorAction Ignore
        }
    }

    #Check for combos config
    if (Set-ConfigDefault "Combos") {
        if ($CheckGpuGroups -or -not $Session.Config.Combos -or (Test-Config "Combos" -LastWriteTime) -or ($ConfigBackup.Combos -and -not [RBMToolBox]::CompareObject($Session.Config.Combos,$ConfigBackup.Combos))) {
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
            $AllCombos = $null
            Remove-Variable -Name AllCombos -ErrorAction Ignore
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

                    foreach ($q in @("CoinSymbol","Currency","Host")) {
                        if ("$($UPool.$q)" -eq "") {$UPool.Enable = $false;Break}
                    }
                    $UPool
                }) -Force
                $CheckPools = $true
            }
            $UserPoolsConfig = $null
            Remove-Variable -Name UserPoolsConfig -ErrorAction Ignore
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
            $AllPoolsConfig = $null
            Remove-Variable -Name AllPoolsConfig -ErrorAction Ignore
        }
    }

    $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_} | ForEach-Object {
        Write-Log "Alas! Missing pool $_ will be added to config manually"
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
        if ($Session.RoundCounter -ne 0) {Write-Log "Updating pools config data"}
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
                DataWindow            = "$(Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow)"
                Penalty               = ([Math]::Round([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+"),2))
                MaxMarginOfError      = ([Math]::Round([double]($Session.Config.Pools.$p.MaxMarginOfError -replace "[^\d\.\-]+"),2))
                SwitchingHysteresis   = $(if ($Pool_SwHyst) {[Math]::Max([Math]::Min([double]$Pool_SwHyst,100.0),0.0)} else {$null})
                StatAverage           = (Get-StatAverage $Session.Config.Pools.$p.StatAverage -Default $Session.Config.PoolStatAverage)
                StatAverageStable     = (Get-StatAverage $Session.Config.Pools.$p.StatAverageStable -Default $Session.Config.PoolStatAverageStable)
                MaxAllowedLuck        = $(if ($Pool_MaxAllowedLuck) {[Math]::Max([double]$Pool_MaxAllowedLuck,0.0)} else {$null})
                MaxTimeSinceLastBlock = $(if ($Pool_MaxTimeSinceLastBlock) {ConvertFrom-Time $Pool_MaxTimeSinceLastBlock} else {$null})
                MaxTimeToFind         = $Pool_MaxTimeToFind
                Region                = $(if ($Session.Config.Pools.$p.Region) {Get-Region $Session.Config.Pools.$p.Region} else {$null})
                SSL                   = $(if ("$($Session.Config.Pools.$p.SSL)" -ne '') {if ("$($Session.Config.Pools.$p.SSL)" -match "^[012]$") {[int]$Session.Config.Pools.$p.SSL} else {[int](Get-Yes $Session.Config.Pools.$p.SSL)}} else {$Session.Config.SSL})
                BalancesKeepAlive     = $(if ($Pool_BalancesKeepAlive) {ConvertFrom-Time $Pool_BalancesKeepAlive} else {$null})
                MinBLKRate            = $(if ($Pool_MaxTimeToFind) {86400/$Pool_MaxTimeToFind} else {0})
            }).GetEnumerator() | Foreach-Object {
                if ([bool]$Session.Config.Pools.$p.PSObject.Properties["$($_.Name)"]) {
                    $Session.Config.Pools.$p."$($_.Name)" = $_.Value
                } else {
                    $Session.Config.Pools.$p | Add-Member "$($_.Name)" $_.Value -Force
                }
            }

            if ($Session.Config.EnableAlgorithmVariants) {
                if ($Session.Config.Pools.$p.Algorithm.Count) {
                    $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Pools.$p.Algorithm} | Foreach-Object {
                        $Session.Config.Pools.$p.Algorithm = @($Session.Config.Pools.$p.Algorithm + $_.Value | Select-Object -Unique)
                    }
                }
                if ($Session.Config.Pools.$p.ExcludeAlgorithm.Count) {
                    $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Pools.$p.ExcludeAlgorithm} | Foreach-Object {
                        $Session.Config.Pools.$p.ExcludeAlgorithm = @($Session.Config.Pools.$p.ExcludeAlgorithm + $_.Value | Select-Object -Unique)
                    }
                }
            }
        }
    }

    #Check for diverse per-mining events
    $Global:PauseMiners.Set([PauseStatus]::ByBattery,$Session.Config.EnablePauseOnBattery -and (Test-IsOnBattery))

    #Get PowerPrice and Scheduler events
    $PauseByScheduler        = $false
    $PowerPrice              = [Double](Get-PowerPrice)
    $EnableMiningHeatControl = $Session.Config.EnableMiningHeatControl
    $MiningHeatControl       = $Session.Config.MiningHeatControl
    $PauseRentals            = $false
    $MRRPriceFactor          = 0
    $GetDate = Get-Date
    $TimeOfDay = $GetDate.TimeOfDay.ToString("hh\:mm")
    $DayOfWeek = "$([int]$GetDate.DayOfWeek)"
    $CurMonth  = "$([int]$GetDate.Month)"
    $Scheduler = $null

    $Session.Config.Scheduler | Where-Object {$_.Enable -and ($_.DayOfWeek -eq "*" -or $_.DayOfWeek -eq $DayOfWeek) -and ($_.Month -contains "*" -or $_.Month -contains $CurMonth) -and $TimeOfDay -ge $_.From -and $TimeOfDay -le $_.To} | Foreach-Object {$PowerPrice = [Double]$_.PowerPrice;$EnableMiningHeatControl = $_.EnableMiningHeatControl;$MiningHeatControl = $_.MiningHeatControl;$PauseByScheduler = $_.Pause -and -not $Session.IsExclusiveRun;$PauseRentals = $_.PauseRentals;$MRRPriceFactor = $_.MRRPriceFactor;$Scheduler = $_}

    $Global:PauseMiners.Set([PauseStatus]::ByScheduler,$PauseByScheduler)

    if ($Scheduler) {
        Write-Log "Scheduler profile $($Scheduler.Name) currently active: DayOfWeek=$($Scheduler.DayOfWeek), From=$($Scheduler.From), To=$($Scheduler.To), Month=$($Scheduler.Month -join ",")"
    }

    $Session.CurrentPowerPrice              = $PowerPrice
    $Session.CurrentEnableMiningHeatControl = $EnableMiningHeatControl
    $Session.CurrentMiningHeatControl       = $MiningHeatControl
    $Session.PauseRentals                   = $PauseRentals
    $Session.MRRPriceFactor                 = $MRRPriceFactor

    $API.CurrentPowerPrice                  = $Session.CurrentPowerPrice
    $API.CurrentEnableMiningHeatControl     = $Session.CurrentEnableMiningHeatControl
    $API.CurrentMiningHeatControl           = $Session.CurrentMiningHeatControl

    #Versioncheck for automatic updates
    $Session.AutoUpdate = $false
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version -and $Session.Config.EnableAutoUpdate -and -not $Session.IsExclusiveRun -and -not $Global:PauseMiners.Test([PauseStatus]::ByActivity) -and (-not $Session.Config.EnableUpdateWhenScheduled -or $Scheduler.EnableUpdate) -and ($Session.Config.EnableUpdateDuringPause -or -not $Global:PauseMiners.Test())) {
        if (Test-Path ".\Logs\autoupdate.txt") {try {$Last_Autoupdate = Get-ContentByStreamReader ".\Logs\autoupdate.txt" | ConvertFrom-Json -ErrorAction Stop} catch {$Last_Autoupdate = $null}}
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
    $ServerDonationRun = $false
    $ServerPoolNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if (-not $Session.IsDonationRun -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and $Session.Config.EnableServerPools) {
        $ServerConnected = Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 2
        if ($ServerConnected) {

            try {
                $Request = Invoke-RestMethodAsync "server://allpools" -cycletime 120 -Timeout 20
                $Pool_WorkerNames = @{}
    
                $ServerPools = [System.Collections.Generic.List[PSCustomObject]]::new()
    
                foreach ($Pool in $Request) {
                    if ($Pool.Name -and $Pool.Algorithm -and $Pool.Name -ne "MiningRigRentals") {

                        if (-not $ServerDonationRun) {
                            if (-not $Pool_WorkerNames.ContainsKey($Pool.Name)) {
                                if ("$($Pool.Worker)$($Pool.User)$($Pool.Pass)" -match "{workername:mpx}") {
                                    $ServerDonationRun = $true
                                } else {
                                    $Pool_WorkerNames[$Pool.Name] = "{workername:$(if ($Session.Config.Pools."$($Pool.Name)".Worker) {$Session.Config.Pools."$($Pool.Name)".Worker} else {$Session.Config.WorkerName})}"
                                }
                            }
                            $Pool_Worker = $Pool.Worker = $Pool_WorkerNames[$Pool.Name]
                            $Pool.User = $Pool.User -replace "{workername:.+}",$Pool_Worker
                            $Pool.Pass = $Pool.Pass -replace "{workername:.+}",$Pool_Worker
                            if ($Pool.Failover) {
                                foreach ($Failover in $Pool.Failover) {
                                    $Failover.User = $Failover.User -replace "{workername:.+}",$Pool_Worker
                                    $Failover.Pass = $Failover.Pass -replace "{workername:.+}",$Pool_Worker
                                }
                            }
                        }
                        $Pool.Updated = [DateTime]$Pool.Updated
                        [void]$ServerPools.Add($Pool)
                    }
                }

                foreach ($Pool in $ServerPools) {
                    [void]$ServerPoolNames.Add($Pool.Name)
                }

            } catch {

                $ServerDonationRun = $false

                if ($ServerPools) { $ServerPools.Clear() }
                if ($ServerPoolNames) { $ServerPoolNames.Clear() }
                $Request = $ServerPools = $null
                Remove-Variable -Name Request, ServerPools
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
        $Session.Config = $Session.UserConfig
        $Session.UserConfig = $null
        [void]$Session.Remove("UserConfig")
        $Global:AllPools = $null
        Remove-Variable -Name AllPools -Scope Global
        $Global:WatchdogTimers.Clear()
        Update-WatchdogLevels -Reset
        Write-Log "Donation run finished. "
    }

    if ($Session.Timer.AddHours(-$DonateDelayHours).AddMinutes($DonateMinutes) -ge $Session.LastDonated -and $Session.AvailPools.Count -gt 0) {
        if ($Session.RoundCounter -gt 0 -and -not $Session.IsDonationRun -and -not $Session.UserConfig) {
            try {$DonationData = Invoke-GetUrl "https://api.rbminer.net/dconf.php";Set-ContentJson -PathToFile ".\Data\dconf.json" -Data $DonationData -Compress > $null} catch {Write-Log -Level Warn "api.rbminer.net/dconf.php could not be reached"}
            if (-not $DonationData -or -not $DonationData.Wallets) {try {$DonationData = Get-ContentByStreamReader ".\Data\dconf.json" | ConvertFrom-Json -ErrorAction Stop} catch {}}
            if (-not $DonationData -or -not $DonationData.Wallets) {$DonationData = Get-Unzip 'H4sIAAAAAAAEAL2U227iMBCG3yXXvSBOCIW7QAJogTYUKD2oWk0SJwR8SB0HEqq++9p01S2RKq22q955PJ6Zb36P/WIEgocQZiSTtdEzW60LYw2EYFkYvRcDzTKGxWnpL8dro2e0qjg2zRh7dssyu0MzslHi2JZlDoeh2UmcTtezrL5tdbuGysTFDgsVRfNKmR5IWGcs5ge1hQuZUZD4Z1QKgZlU/gAzIBpDQSwWU6OXACnw64UxxoL/IZm4CxW/gyKH3rNw0mdna1cbhBxSo6i47FTssqaIltVhAwTaUWrtUJrQBO3THesi59hOd0dJreQ/Es64ouPXEQamEe9mNyqBba+852PShtEDtGVWoH76wzpOR5uZlHy+DUpz2J6at/JhxNxw0gd+uXEwuzPjLuZ5O7fHbrDao2pmw3S+va870dj0TZcNF2uaXq3n/4APRXHgIlbeqtGNX0WkjLFLUi4yuaHqyKCMdiA4R93CaLR7lUV4DMVG99pfDtRhK0hWq6W53LGkju0Fuxf+4ZCvfHfuH9cx6pfe19QOCMiEC821R8o3gyqjJZ2BSDN2nfhCcJ241SRV461BM5Zq1gbAqjgZIqQ6TIJ091hAitUyJFh5PKgbHK4/OPFFyjSmqvVGvQcs0oBz8kEZr7rxl3mf302E359XwxCNi4COHMirMZ3QVfUFZUz0Sf0Bz1jxjRC63qKmoe7c+EyUBSf8G5k+DjPt0CaVhxMoifwa0NkI/T2dc8ai51TJo+7r8f3LPfv13l7cRr+45hWf/z1nA/90JsHj0/srP2W9Aop1wZHI2IiT+LSpEmg7+F35VJht4SZLtXoHyN+2n15/AWQQEz05BgAA' | ConvertFrom-Json}
            if (-not $Session.IsDonationRun) {Write-Log "Donation run started for the next $(($Session.LastDonated-($Session.Timer.AddHours(-$DonateDelayHours))).Minutes +1) minutes. "}
            $Session.UserConfig = $Session.Config
            $Session.Config = $null
            [void]$Session.Remove("Config")
            $Session.Config = $Session.UserConfig | ConvertTo-Json -Depth 10 | ConvertFrom-Json -ErrorAction Ignore
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
                $Session.Config.Pools.$p | Add-Member DataWindow "$(Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow)" -Force
                $Session.Config.Pools.$p | Add-Member Penalty ([Math]::Round([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.\-]+"),2)) -Force
                $Session.Config.Pools.$p | Add-Member MaxMarginOfError $(if ($Session.Config.Pools.$p.MaxMarginOfError -eq $null) {if ($p -eq "NiceHash") {[double]0} else {[double]100}} else {[Math]::Round([double]($Session.Config.Pools.$p.MaxMarginOfError -replace "[^\d\.\-]+"),2)}) -Force
                $Session.Config.Pools.$p | Add-Member SSL ([int]$Session.Config.Pools.$p.SSL) -Force

                if ($Session.Config.EnableAlgorithmVariants) {
                    if ($Session.Config.Pools.$p.Algorithm.Count) {
                        $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Pools.$p.Algorithm} | Foreach-Object {
                            $Session.Config.Pools.$p.Algorithm = @($Session.Config.Pools.$p.Algorithm + $_.Value | Select-Object -Unique)
                        }
                    }
                    if ($Session.Config.Pools.$p.ExcludeAlgorithm.Count) {
                        $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Pools.$p.ExcludeAlgorithm} | Foreach-Object {
                            $Session.Config.Pools.$p.ExcludeAlgorithm = @($Session.Config.Pools.$p.ExcludeAlgorithm + $_.Value | Select-Object -Unique)
                        }
                    }
                }
            }
            if ($DonationData.ExcludeAlgorithm) {
                $Session.Config | Add-Member ExcludeAlgorithm @($Session.Config.ExcludeAlgorithm + (Compare-Object $DonationData.ExcludeAlgorithm $Session.Config.Algorithm | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) | Select-Object -Unique) -Force
            }
            if ($DonationData.ExcludeMinerName) {
                $Session.Config | Add-Member ExcludeMinerName @($Session.Config.ExcludeMinerName + (Compare-Object $DonationData.ExcludeMinerName $Session.Config.MinerName | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject) | Select-Object -Unique) -Force
            }
            $Session.Config | Add-Member DisableExtendInterval $true -Force
            $Session.Config | Add-Member Userpools @() -Force

            if ($Session.Config.EnableAlgorithmVariants) {
                if ($Session.Config.Algorithm -and $Session.Config.Algorithm.Count) {
                    $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.Algorithm} | Foreach-Object {
                        $Session.Config.Algorithm = @($Session.Config.Algorithm + $_.Value | Select-Object -Unique)
                    }
                }
                if ($Session.Config.ExcludeAlgorithm -and $Session.Config.ExcludeAlgorithm.Count) {
                    $Global:GlobalAlgoVariants.PSObject.Properties | Where-Object {$_.Name -in $Session.Config.ExcludeAlgorithm} | Foreach-Object {
                        $Session.Config.ExcludeAlgorithm = @($Session.Config.ExcludeAlgorithm + $_.Value | Select-Object -Unique)
                    }
                }
            }

            $Global:AllPools = $null
            Remove-Variable -Name AllPools -Scope Global
        }
    } else {
        Write-Log ("Next donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($Session.LastDonated.AddHours($DonateDelayHours) - ($Session.Timer.AddMinutes($DonateMinutes))))
    }

    $UserConfig = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

    #Clear pool cache if the pool configuration has changed
    if ($Global:AllPools -ne $null -and (($ConfigBackup.Pools | ConvertTo-Json -Compress -Depth 10) -ne ($Session.Config.Pools | ConvertTo-Json -Compress -Depth 10) -or (Compare-Object @($ConfigBackup.PoolName) @($Session.Config.PoolName)) -or (Compare-Object @($ConfigBackup.ExcludePoolName) @($Session.Config.ExcludePoolName)))) {
        Write-Log "Resetting AllPools data store"
        $Global:AllPools = $null
        Remove-Variable -Name AllPools -Scope Global
    }

    #load device(s) information and device combos
    if ($CheckConfig -or $CheckCombos -or $ConfigBackup.MiningMode -ne $Session.Config.MiningMode -or (Compare-Object $Session.Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0 -or (Compare-Object $Session.Config.ExcludeDeviceName $ConfigBackup.ExcludeDeviceName | Measure-Object).Count -gt 0) {
        if ($Session.RoundCounter -ne 0) {Write-Log "Device configuration changed. Refreshing now."}

        #Load information about the devices
        $Global:DeviceCache.Devices = @()
        if (($Session.Config.DeviceName | Measure-Object).Count) {$Global:DeviceCache.Devices = @(Get-Device $Session.Config.DeviceName $Session.Config.ExcludeDeviceName)}
        $Global:DeviceCache.DevicesByTypes = [PSCustomObject]@{
            AMD    = @($Global:DeviceCache.Devices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "AMD"})
            INTEL  = @($Global:DeviceCache.Devices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "INTEL"})
            NVIDIA = @($Global:DeviceCache.Devices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "NVIDIA"})
            CPU    = @($Global:DeviceCache.Devices | Where-Object {$_.Type -eq "Cpu"})
            Combos = [PSCustomObject]@{}
            FullComboModels = [PSCustomObject]@{}
        }
        $Global:DeviceCache.DevicesToVendors = [hashtable]@{}

        $Session.Config | Add-Member DeviceModel @($Global:DeviceCache.Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object) -Force
        $Session.Config | Add-Member CUDAVersion $Session.CUDAVersion -Force
        $Session.Config | Add-Member DotNETRuntimeVersion $Session.DotNETRuntimeVersion -Force

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

        $Global:DeviceCache.DeviceNames = [hashtable]@{}
        @("AMD","INTEL","NVIDIA","CPU") | Foreach-Object {
            $Global:DeviceCache.DevicesByTypes.$_ | Group-Object Model | Foreach-Object {$Global:DeviceCache.DeviceNames[$_.Name] = @($_.Group | Select-Object -ExpandProperty Name | Sort-Object)}
        }

        $Global:DeviceCache.DeviceCombos = @($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name | ForEach-Object {$Global:DeviceCache.DevicesByTypes.$_ | Select-Object -ExpandProperty Model -Unique} | Sort-Object | Where-Object {$_})
        $Global:DeviceCache.DevicesNames = @($Global:DeviceCache.Devices.Name | Select-Object -Unique | Sort-Object | Where-Object {$_})

        $API.DeviceCombos = $API.DevicesToVendors = $API.AllDevices = $API.Devices = $null
        $API.DeviceCombos     = $Global:DeviceCache.DeviceCombos
        $API.DevicesToVendors = $Global:DeviceCache.DevicesToVendors
        $API.AllDevices = $Global:DeviceCache.AllDevices
        $API.Devices    = $Global:DeviceCache.Devices

        #Update device information for the first time
        Update-DeviceInformation $Global:DeviceCache.DevicesNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -DeviceConfig $Session.Config.Devices
    }
    
    $ConfigBackup = $null
    Remove-Variable -Name ConfigBackup -ErrorAction Ignore

    if ($IsLinux -and $Global:DeviceCache.DevicesByTypes.NVIDIA -and $Session.Config.EnableOCProfiles -and $Session.Config.EnableOCLinuxForcePState -and -not (Get-Process | Where-Object Name -eq "forcePstate") -and (Test-Path ".\IncludesLinux\bin\forcePstate")) {
        Set-OCDaemon "$($Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\IncludesLinux\bin\forcePstate")) &" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
        Invoke-OCDaemon -FilePath ".\IncludesLinux\bash\forcePstate.sh" -Quiet > $null
    }

    $Global:DeviceCache.ConfigFullComboModelNames = @($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name | Where-Object {$_})

    if (-not $Global:DeviceCache.Devices) {
        $Global:PauseMiners.Set([PauseStatus]::ByError)
    }

    #Check for miner config
    if (Set-ConfigDefault "Miners") {
        if ($CheckConfig -or -not $Session.Config.Miners -or (Test-Config "Miners" -LastWriteTime)) {
            if ($Session.RoundCounter -ne 0) {Write-Log "Updating miners config data"}
            $MinersConfig = Get-ConfigContent "Miners" -UpdateLastWriteTime
            if (Test-Config "Miners" -Health) {
                $Session.Config | Add-Member Miners ([PSCustomObject]@{}) -Force
                $CPU_GlobalAffinityMask = Get-CPUAffinity $Global:GlobalCPUInfo.Threads -ToInt
                
                $EmptyObjects       = @{CPU=$null;GPU=$null;GPUDUAL=$null}
                $EmptyObjectsString = @("Params","OCprofile","MSIAprofile","Penalty","HashAdjust","Difficulty","ShareCheck")

                foreach ($CcMiner in @($MinersConfig.PSObject.Properties)) {
                    $CcMinerName = $CcMiner.Name
                    [String[]]$CcMinerName_Array = @($CcMinerName -split '-')
                    if ($CcMinerName_Array.Count -gt 1 -and ($Global:DeviceCache.ConfigFullComboModelNames -icontains $CcMinerName_Array[1]) -and ($Global:DeviceCache.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")) {$CcMinerName = "$($CcMinerName_Array[0])-$($Global:DeviceCache.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")";$CcMinerName_Array = @($CcMinerName -split '-')}                
                    $CcMinerOk = $true
                    for($i=1;($i -lt $CcMinerName_Array.Count) -and $CcMinerOk;$i++) {if ($Session.Config.DeviceModel -inotcontains $CcMinerName_Array[$i]) {$CcMinerOk=$false}}
                    if ($CcMinerOk) {
                        foreach($p in @($CcMiner.Value)) {
                            $Disable = Get-Yes $p.Disable
                            $Tuning  = Get-Yes $p.Tuning
                            if ($(foreach($q in $p.PSObject.Properties.Name) {if (($q -notin @("MainAlgorithm","SecondaryAlgorithm","Disable","Tuning") -and ($p.$q -isnot [string] -or $p.$q.Trim() -ne "")) -or ($Disable -and $q -eq "Disable") -or ($Tuning -and $q -eq "Tuning")) {$true;break}})) {
                                $CcMinerNameToAdd = $CcMinerName

                                $newMiner = $null

                                $newMiner = $p | Select-Object -ExcludeProperty MainAlgorithm, SecondaryAlgorithm

                                if ($p.MainAlgorithm -ne '*') {
                                    $CcMinerNameToAdd = "$CcMinerNameToAdd-$(Get-Algorithm $p.MainAlgorithm)"
                                    if ($p.SecondaryAlgorithm) {
                                        $CcMinerNameToAdd = "$CcMinerNameToAdd-$(Get-Algorithm $p.SecondaryAlgorithm)"
                                        $Intensity = @($p.Intensity -replace "[^0-9\.,;]+" -split "[,;]+" | Where-Object {"$_" -ne ""} | Select-Object -Unique)
                                        if ($newMiner.Intensity -ne $null) {$newMiner.Intensity = $Intensity} else {$newMiner | Add-Member Intensity $Intensity -Force}
                                    }
                                }
                                if ($newMiner.MSIAprofile -ne $null -and $newMiner.MSIAprofile -and $newMiner.MSIAprofile -notmatch "^[1-5]$") {
                                    Write-Log -Level Warn "Invalid MSIAprofile for $($CcMinerNameToAdd) in miners.config.txt: `"$($newMiner.MSIAprofile)`" (empty or 1-5 allowed, only)"
                                    $newMiner.MSIAprofile = ""
                                }
                                if ($newMiner.Difficulty -ne $null) {$newMiner.Difficulty = $newMiner.Difficulty -replace "[^\d\.]"}
                                if ($newMiner.Affinity) {
                                    $CPUAffinityInt = (ConvertFrom-CPUAffinity $newMiner.Affinity -ToInt) -band $CPU_GlobalAffinityMask
                                    if ($CPUAffinityInt) {
                                        $newMiner.Affinity = "0x{0:x$(if($CPUAffinityInt -lt 65536){4}else{8})}" -f $CPUAffinityInt
                                        if (-not $newMiner.Threads) {
                                            $CPUThreads = @(ConvertFrom-CPUAffinity $newMiner.Affinity).Count
                                            if ($newMiner.Threads -eq $null) {$newMiner | Add-Member Threads $Threads -Force} else {$newMiner.Threads = $CPUThreads}
                                        }
                                    } else {
                                        $newMiner.Affinity = ""
                                    }
                                }
                                if ($newMiner.Threads -ne $null) {$newMiner.Threads = [int]($newMiner.Threads -replace "[^\d]")}
                                if ($newMiner.ShareCheck -ne $null -and $newMiner.ShareCheck -ne "") {$newMiner.ShareCheck = ConvertFrom-Time $p.ShareCheck}
                                if ($newMiner.Disable -ne $null) {$newMiner.Disable = $Disable} else {$newMiner | Add-Member Disable $Disable -Force}
                                if ($newMiner.Tuning -ne $null) {$newMiner.Tuning = $Tuning} else {$newMiner | Add-Member Tuning $Tuning -Force}

                                $minerType = if ($newMiner.Threads -ne $null) {"CPU"} elseif ($newMiner.Hash2Adjust -ne $null) {"GPUDUAL"} else {"GPU"}

                                if ($EmptyObjects[$minerType] -eq $null) {
                                    if (-not $newMiner.Disable -and -not $newMiner.Tuning) {
                                        $isEmpty = $true
                                        foreach ( $prop in $EmptyObjectsString ) {
                                            if ($newMiner.$prop -ne "") {
                                                $isEmpty = $false
                                                break
                                            }
                                        }
                                        if ($isEmpty -and $minerType -ne "GPU") {
                                            if ($minerType -eq "CPU" -and ($newMiner.Affinity -ne "" -or $newMiner.Threads)) { $isEmpty = $false }
                                            elseif ($minerType -eq "GPUDUAL" -and ($newMiner.Hash2Adjust -ne "" -or $newMiner.Intensity)) { $isEmpty = $false }
                                        }

                                        if ($isEmpty) {
                                            $EmptyObjects[$minerType] = $newMiner
                                        }
                                    }
                                } elseif ([RBMToolBox]::CompareObject($newMiner,$EmptyObjects[$minerType])) {
                                    $newMiner = $null
                                    $newMiner = $EmptyObjects[$minerType]
                                }

                                $Session.Config.Miners | Add-Member -Name $CcMinerNameToAdd -Value $newMiner -MemberType NoteProperty -Force
                            }
                        }
                    }
                }
            }
            $MinersConfig = $EmptyObjects = $newMiner = $null
            Remove-Variable -Name MinersConfig,EmptyObjects,newMiner -ErrorAction Ignore
        }
    }

    $MinerInfoChanged = $false
    if (-not (Test-Path ".\Data\minerinfo.json")) {$Global:MinerInfo = [hashtable]@{}}
    Compare-Object @($Session.AvailMiners) @($Global:MinerInfo.Keys) | Foreach-Object {
        $CcMinerName = $_.InputObject
        Switch ($_.SideIndicator) {
            "<=" {$Global:MinerInfo[$CcMinerName] = @(Get-MinersContent -MinerName $CcMinerName -Parameters @{InfoOnly = $true} | Select-Object -ExpandProperty Type);Break}
            "=>" {[void]$Global:MinerInfo.Remove($CcMinerName);Break}
        }
        $MinerInfoChanged = $true
    }
    if ($MinerInfoChanged) {Set-ContentJson -PathToFile ".\Data\minerinfo.json" -Data $Global:MinerInfo -Compress > $null}

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

    #$API.Rates = ConvertTo-Json $Global:Rates -Depth 10
    #ConvertTo-Json $Global:Rates -Depth 10 | Set-Content ".\Data\rates.json" -ErrorAction Ignore
    $ActualRates = [PSCustomObject]@{}
    $Global:Rates.Keys | Where-Object {$Session.Config.Currency -icontains $_} | Foreach-Object {$ActualRates | Add-Member $_ $Global:Rates.$_}
    $API.ActualRates = $ActualRates

    #PowerPrice check
    $Session.PowerPriceBTC        = 0
    $Session.FixedCostPerDayBTC   = 0
    $Session.CurrentPowerPriceBTC = 0

    if ($PowerPriceCurrency) {
        if ($PowerPrice_Rate = [Double]$Global:Rates."$($PowerPriceCurrency)") {
            $Session.PowerPriceBTC        = [Double]$Session.Config.PowerPrice/$PowerPrice_Rate
            $Session.FixedCostPerDayBTC   = [Double]$Session.Config.FixedCostPerDay/$PowerPrice_Rate
            $Session.CurrentPowerPriceBTC = [Double]$Session.CurrentPowerPrice/$PowerPrice_Rate
        } elseif ($Session.CurrentPowerPrice) {
            Write-Log -Level Warn "Powerprice currency $($PowerPriceCurrency) not found. Cost of electricity will be ignored."
        }
    }

    $API.PowerPriceBTC = $Session.PowerPriceBTC
    $API.FixedCostPerDayBTC = $Session.FixedCostPerDayBTC
    $API.CurrentPowerPriceBTC = $Session.CurrentPowerPriceBTC

    #Load the stats
    Write-Log "Loading saved statistics. "

    Get-Stat -Miners -Quiet
    [hashtable]$Disabled = Get-Stat -Disabled

    #$API.Stats = $Global:StatsCache
    #ConvertTo-Json $Global:StatsCache -Depth 10 -ErrorAction Ignore | Set-Content ".\Data\stats.json" -ErrorAction Ignore

    #Validate Minerspeeds
    foreach($Miner_Key in @($Global:MinerSpeeds.Keys)) {
        $Miner_Remove = $false
        if (Compare-Object $Global:MinerSpeeds[$Miner_Key].Miner $Session.AvailMiners | Where-Object SideIndicator -eq "<=") {
            $Miner_Remove = $true
        } else {
            foreach($Miner_Name in $Global:MinerSpeeds[$Miner_Key].Names) {
                if (-not $Global:StatsCache.ContainsKey($Miner_Name)) {
                    $Miner_Remove = $true
                    Break
                }
            }
        }
        if ($Miner_Remove) {[void]$Global:MinerSpeeds.Remove($Miner_Key)}
    }

    #Load information about the pools
    Write-Log "Loading pool information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading pool modules .."}

    $SelectedPoolNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $NewPools          = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StopWatch         = [System.Diagnostics.StopWatch]::New()

    $TimerPools = @{}

    if (Test-Path "Pools") {
        $AvailablePools = $Session.AvailPools + "Userpools"

        foreach ($Pool in $AvailablePools) {
            if (-not $ServerPools -or $Pool -eq "MiningRigRentals") {
                if (
                    (
                        $Session.Config.Pools.$Pool -and 
                        ($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -contains $Pool) -and 
                        ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -notcontains $Pool)
                    ) -or (
                        $Pool -eq "Userpools" -and $Session.Config.Userpools
                    )
                ) {
                    if ($Session.RoundCounter -eq 0) { Write-Host ".. loading $Pool " -NoNewline }
                    $StopWatch.Restart()

                    if ($Pool -eq "Userpools") {
                        foreach ($UserPool in $Session.Config.Userpools) {
                            $UserPool_Name = $UserPool.Name
                            if ($UserPool.Name -and -not $SelectedPoolNames.Contains($UserPool_Name) -and -not $ServerPoolNames.Contains($UserPool_Name)) {
                                $Pool_Parameters = @{ StatSpan = $RoundSpan; InfoOnly = $false; Name = $UserPool_Name }
                                foreach ($Property in $Session.Config.Pools.$UserPool_Name.PSObject.Properties) {
                                    $Pool_Parameters[$Property.Name] = $Property.Value
                                }
                                Get-PoolsContent "Userpools" -Parameters $Pool_Parameters -Disabled $Disabled | Foreach-Object { [void]$NewPools.Add($_) }
                                [void]$SelectedPoolNames.Add($UserPool_Name)
                            }
                        }
                    } else {
                        $Pool_Parameters = @{ StatSpan = $RoundSpan; InfoOnly = $false }
                        foreach ($Property in $Session.Config.Pools.$Pool.PSObject.Properties) {
                            $Pool_Parameters[$Property.Name] = $Property.Value
                        }
                        Get-PoolsContent $Pool -Parameters $Pool_Parameters -Disabled $Disabled | Foreach-Object { [void]$NewPools.Add($_)  }
                        [void]$SelectedPoolNames.Add($Pool)
                    }

                    $TimerPools[$Pool] = [Math]::Round($StopWatch.Elapsed.TotalSeconds, 3)
                    if ($Session.RoundCounter -eq 0) { Write-Host "done ($($TimerPools[$Pool])s) " }
                    Write-Log "$Pool loaded in $($TimerPools[$Pool])s "
                }
            }
        }
    }

    $TimerPools | ConvertTo-Json | Set-Content ".\Logs\timerpools.json" -Force

    $StopWatch = $TimerPools = $null
    Remove-Variable -Name StopWatch, TimerPools -ErrorAction Ignore

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
            #ConvertTo-Json $BalancesData -Depth 10 -ErrorAction Ignore | Set-Content ".\Data\balances.json" -ErrorAction Ignore

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
        [void]$NewPools.AddRange($ServerPools)
    }
    $SelectedPoolNames = $null
    Remove-Variable -Name SelectedPoolNames -ErrorAction Ignore

    if ($Session.RoundCounter -eq 0) {Write-Host "Selecting best pools .."}

    $LockMiners = $Session.LockMiners.Locked -and -not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun

    #This finds any pools that were already in $Global:AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.

    $Test_Algorithm = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Test_ExcludeAlgorithm = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Test_CoinSymbol = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Test_ExcludeCoin = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Test_ExcludeCoinSymbol = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Test_PoolName = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Test_ExcludePoolName = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($Session.Config.Algorithm.Count) { $Test_Algorithm.UnionWith([string[]]@($Session.Config.Algorithm)) }
    if ($Session.Config.ExcludeAlgorithm.Count) { $Test_ExcludeAlgorithm.UnionWith([string[]]@($Session.Config.ExcludeAlgorithm)) }
    if ($Session.Config.CoinSymbol.Count) { $Test_CoinSymbol.UnionWith([string[]]@($Session.Config.CoinSymbol)) }
    if ($Session.Config.ExcludeCoin.Count) { $Test_ExcludeCoin.UnionWith([string[]]@($Session.Config.ExcludeCoin)) }
    if ($Session.Config.ExcludeCoinSymbol.Count) { $Test_ExcludeCoinSymbol.UnionWith([string[]]@($Session.Config.ExcludeCoinSymbol)) }
    if ($Session.Config.PoolName.Count) { $Test_PoolName.UnionWith([string[]]@($Session.Config.PoolName)) }
    if ($Session.Config.ExcludePoolName.Count) { $Test_ExcludePoolName.UnionWith([string[]]@($Session.Config.ExcludePoolName)) }

    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and $Scheduler) {
        if ($Scheduler.Algorithm.Count) { $Test_Algorithm.UnionWith([string[]]@($Scheduler.Algorithm)) }
        if ($Scheduler.ExcludeAlgorithm.Count) { $Test_ExcludeAlgorithm.UnionWith([string[]]@($Scheduler.ExcludeAlgorithm)) }
        if ($Scheduler.CoinSymbol.Count) { $Test_CoinSymbol.UnionWith([string[]]@($Scheduler.CoinSymbol)) }
        if ($Scheduler.ExcludeCoinSymbol.Count) { $Test_ExcludeCoinSymbol.UnionWith([string[]]@($Scheduler.ExcludeCoinSymbol)) }
        if ($Scheduler.PoolName.Count) { $Test_PoolName.UnionWith([string[]]@($Scheduler.PoolName)) }
        if ($Scheduler.ExcludePoolName.Count) { $Test_ExcludePoolName.UnionWith([string[]]@($Scheduler.ExcludePoolName)) }
    }

    if ($Global:AllPools.Count) {
        $PoolsToBeReaddedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        Compare-Object @($NewPools.Name | Select-Object -Unique) @($Global:AllPools.Name | Select-Object -Unique) |
            Where-Object { $_.SideIndicator -eq "=>" -and $_.InputObject -ne "MiningRigRentals" } |
            ForEach-Object { [void]$PoolsToBeReaddedSet.Add($_.InputObject) }

        if ($PoolsToBeReaddedSet.Count) {
            Write-Log "Re-Adding currently failed pools: $($PoolsToBeReaddedSet -join ", ")"
            foreach ( $Pool in $Global:AllPools ) {
                if ( $PoolsToBeReaddedSet.Contains($_.Name) ) { [void]$NewPools.Add($_) }
            }
        }
        $PoolsToBeReaddedSet = $null
    }
    
    $Global:AllPools = $null #will be set to NewPools later
    Remove-Variable -Name AllPools -Scope Global

    if ($Session.Config.EnableDebugMode) {
        #$API.NewPools = $NewPools | ConvertTo-Json -Depth 10
        ConvertTo-Json $NewPools -Depth 10 -ErrorAction Ignore | Set-Content ".\Data\newpools.json" -ErrorAction Ignore
    }

    [void]$NewPools.RemoveAll({
        param($Pool)

        $Pool_Name = $Pool.Name
        $Pool_Algo = [string[]]$Pool.Algorithm0
        $Pool_CoinSymbol = $Pool.CoinSymbol
        $Pool_CoinName = $Pool.CoinName

        $Pool_CheckForUnprofitableAlgo = -not $Session.Config.DisableUnprofitableAlgolist -and -not ($Pool.Exclusive -and -not $Pool.Idle)
        if ($Pool_CoinSymbol) { $Pool_Algo = [string[]]@($Pool_Algo, "$($Pool_Algo)-$($Pool_CoinSymbol)") }

        return -not (
            (
                $Pool.SSL -or $Session.Config.Pools.$Pool_Name.SSL -ne 2
            ) -and
            (
                ($ServerPoolNames.Count -and $ServerPoolNames.Contains($Pool_Name)) -or (
                    -not ( (-not $Session.Config.Pools.$Pool_Name) -or
                        ($Test_PoolName.Count -and -not $Test_PoolName.Contains($Pool_Name)) -or
                        ($Test_ExcludePoolName.Count -and $Test_ExcludePoolName.Contains($Pool_Name)) -or
                        ($Test_Algorithm.Count -and -not $Test_Algorithm.Overlaps($Pool_Algo)) -or
                        ($Test_ExcludeAlgorithm.Count -and $Test_ExcludeAlgorithm.Overlaps($Pool_Algo)) -or
                        ($Pool_CheckForUnprofitableAlgo -and $UnprofitableAlgos.Algorithms -and $UnprofitableAlgos.Algorithms.Count -and (Test-Intersect $UnprofitableAlgos.Algorithms $Pool_Algo)) -or
                        ($Pool_CheckForUnprofitableAlgo -and $UnprofitableAlgos.Pools.$Pool_Name.Algorithms -and $UnprofitableAlgos.Pools.$Pool_Name.Algorithms.Count -and (Test-Intersect $UnprofitableAlgos.Pools.$Pool_Name.Algorithms $Pool_Algo)) -or
                        ($Pool_CheckForUnprofitableAlgo -and $Pool_CoinSymbol -and $UnprofitableAlgos.Coins -and $UnprofitableAlgos.Coins.Count -and $UnprofitableAlgos.Coins -contains $Pool_CoinSymbol) -or
                        ($Pool_CheckForUnprofitableAlgo -and $Pool_CoinSymbol -and $UnprofitableAlgos.Pools.$Pool_Name.Coins -and $UnprofitableAlgos.Pools.$Pool_Name.Coins.Count -and $UnprofitableAlgos.Pools.$Pool_Name.Coins -contains $Pool_CoinSymbol) -or
                        ($Test_CoinSymbol.Count -and $Pool_CoinSymbol -and -not $Test_CoinSymbol.Contains($Pool_CoinSymbol)) -or
                        ($Test_ExcludeCoin.Count -and $Pool_CoinName -and $Test_ExcludeCoin.Contains($Pool_CoinName)) -or
                        ($Test_ExcludeCoinSymbol.Count -and $Pool_CoinSymbol -and $Test_ExcludeCoinSymbol.Contains($Pool_CoinSymbol)) -or
                        ($Session.Config.Pools.$Pool_Name.Algorithm.Count -and -not (Test-Intersect $Session.Config.Pools.$Pool_Name.Algorithm $Pool_Algo)) -or
                        ($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Test-Intersect $Session.Config.Pools.$Pool_Name.ExcludeAlgorithm $Pool_Algo)) -or
                        ($Pool_CoinName -and $Session.Config.Pools.$Pool_Name.CoinName.Count -and $Session.Config.Pools.$Pool_Name.CoinName -notcontains $Pool_CoinName) -or
                        ($Pool_CoinName -and $Session.Config.Pools.$Pool_Name.ExcludeCoin.Count -and $Session.Config.Pools.$Pool_Name.ExcludeCoin -contains $Pool_CoinName) -or
                        ($Pool_CoinSymbol -and $Session.Config.Pools.$Pool_Name.CoinSymbol.Count -and $Session.Config.Pools.$Pool_Name.CoinSymbol -notcontains $Pool_CoinSymbol) -or
                        ($Pool_CoinSymbol -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol -contains $Pool_CoinSymbol)
                    ) -and (
                        ($Pool.Exclusive -and -not $Pool.Idle) -or -not (
                            ($Pool.Idle) -or
                            (-not $Pool.SoloMining -and $Pool.Hashrate -ne $null -and $Session.Config.Algorithms."$($Pool.Algorithm)".MinHashrate -and $Pool.Hashrate -lt $Session.Config.Algorithms."$($Pool.Algorithm)".MinHashrate) -or
                            ($Pool.SoloMining -and $Pool.Hashrate -ne $null -and $Session.Config.Algorithms."$($Pool.Algorithm)".MinHashrateSolo -and $Pool.Hashrate -lt $Session.Config.Algorithms."$($Pool.Algorithm)".MinHashrateSolo) -or
                            ($Pool.Workers -ne $null -and $Session.Config.Algorithms."$($Pool.Algorithm)".MinWorkers -and $Pool.Workers -lt $Session.Config.Algorithms."$($Pool.Algorithm)".MinWorkers) -or
                            ($Pool.BLK -ne $null -and $Session.Config.Algorithms."$($Pool.Algorithm)".MinBLKRate -and ($Pool.BLK -lt $Session.Config.Algorithms."$($Pool.Algorithm)".MinBLKRate)) -or
                            ($Pool.BLK -ne $null -and $Session.Config.Pools.$Pool_Name.MinBLKRate -and ($Pool.BLK -lt $Session.Config.Pools.$Pool_Name.MinBLKRate)) -or
                            (-not $Pool.SoloMining -and $Pool_CoinSymbol -and $Pool.Hashrate -ne $null -and $Session.Config.Coins."$($Pool_CoinSymbol)".MinHashrate -and $Pool.Hashrate -lt $Session.Config.Coins."$($Pool_CoinSymbol)".MinHashrate) -or
                            ($Pool.SoloMining -and $Pool_CoinSymbol -and $Pool.Hashrate -ne $null -and $Session.Config.Coins."$($Pool_CoinSymbol)".MinHashrateSolo -and $Pool.Hashrate -lt $Session.Config.Coins."$($Pool_CoinSymbol)".MinHashrateSolo) -or
                            ($Pool_CoinSymbol -and $Pool.Workers -ne $null -and $Session.Config.Coins."$($Pool_CoinSymbol)".MinWorkers -and $Pool.Workers -lt $Session.Config.Coins."$($Pool_CoinSymbol)".MinWorkers) -or
                            ($Pool_CoinSymbol -and $Pool.BLK -ne $null -and $Session.Config.Coins."$($Pool_CoinSymbol)".MinBLKRate -and ($Pool.BLK -lt $Session.Config.Coins."$($Pool_CoinSymbol)".MinBLKRate))
                        )
                    )
                )
            )
        )
    })

    $AllPools_BeforeWD_Count = $NewPools.Count

    $API.AllPools   = ConvertTo-Json $NewPools -Depth 10 -ErrorAction Ignore
    #ConvertTo-Json $NewPools -Depth 10 -ErrorAction Ignore | Set-Content ".\Data\allpools.json" -ErrorAction Ignore
    $API.Algorithms = @($NewPools.Algorithm | Sort-Object -Unique) 


    #Setup and reset Watchdog
    $WDIntervalTime = $Session.Timer.AddSeconds( - $Session.WatchdogInterval)
    $WDResetTime    = $Session.Timer.AddSeconds( - $Session.WatchdogReset)

    if ($Session.WatchdogReset -gt $Session.WatchdogInterval) {
        [void]$Global:WatchdogTimers.RemoveAll({ param($c) $c.Kicked -le $WDResetTime -and $c.Active -le $WDIntervalTime })
    }

    # Apply watchdog filtering only if multiple pools are selected
    if (($NewPools.Name | Select-Object -Unique | Measure-Object).Count -gt 1) {
        [void]$NewPools.RemoveAll({
            param ($Pool)
            if ($Pool.Disabled) { return $true }
            if (-not $Pool.Exclusive) {
                $Pool_WatchdogTimers = $Global:WatchdogTimers.Where({$_.PoolName -eq $Pool.Name -and $_.Kicked -lt $WDIntervalTime -and $_.Kicked -gt $WDResetTime})
                if ($Pool_WatchdogTimers.Count -ge 3) { return $true }
                if ($Pool_WatchdogTimers.Where({ $_.Algorithm -in $Pool.Algorithm }).Count -ge 2) { return $true }
            }
        })
    }


    #Update the active pools
    $Pools = [PSCustomObject]@{}
    
    if ($NewPools.Count -gt 0) {

        $Pools_WTM = $NewPools.Where({$_.WTM})

        if ($Pools_WTM.Count -gt 0) {
            if ($Session.RoundCounter -eq 0) { Write-Host ".. loading WhatToMine " -NoNewline }
            $start = Get-UnixTimestamp -Milliseconds

            Get-PoolsContent "WhatToMine" -Parameters @{
                Pools            = $Pools_WTM
                StatSpan         = $RoundSpan
                InfoOnly         = $false
                StatAverage      = $UserConfig.Pools.WhatToMine.StatAverage
                StatAverageStable = $UserConfig.Pools.WhatToMine.StatAverageStable
            } | ForEach-Object {
                $Pool_WTM = $_

                foreach ($Pool in $Pools_WTM) {
                    if ($Pool.Price -eq 0 -and $Pool.Algorithm -eq $Pool_WTM.Algorithm -and 
                        $Pool.CoinSymbol -eq $Pool_WTM.CoinSymbol -and 
                        (-not $Pool.WTMMode -or $Pool.WTMMode -eq $Pool_WTM.Mode)) {
                
                        $Pool.Price_0       = $Pool_WTM.Price
                        $Pool.Price         = $Pool_WTM.Price * $Pool.PenaltyFactor
                        $Pool.StablePrice   = $Pool_WTM.StablePrice * $Pool.PenaltyFactor
                        $Pool.MarginOfError = $Pool_WTM.MarginOfError
                        $Pool.Updated       = $Pool_WTM.Updated
                    }
                }
            }

            $done = [Math]::Round(((Get-UnixTimestamp -Milliseconds) - $start) / 1000, 3)
            if ($Session.RoundCounter -eq 0) { Write-Host "done ($($done)s) " }
            Write-Log "WhatToMine loaded in $($done)s "
        }

        #Decrease compare prices, if out of sync window
        # \frac{\left(\frac{\ln\left(60-x\right)}{\ln\left(50\right)}+1\right)}{2}
        $OutOfSyncTimer = $null
        foreach ($Pool in $NewPools) {
            if ($null -eq $OutOfSyncTimer -or $Pool.Updated -gt $OutOfSyncTimer) {
                $OutOfSyncTimer = $Pool.Updated
            }
        }
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

        $NewPools | Where-Object {-not $_.SoloMining} | Select-Object Algorithm0,CoinSymbol,Hashrate,StablePrice | Group-Object -Property {"$($_.Algorithm0)-$($_.CoinSymbol)"} | Foreach-Object {$Pools_Hashrates[$_.Name] = ($_.Group | Where-Object StablePrice | Select-Object -ExpandProperty Hashrate | Measure-Object -Maximum).Maximum;if (-not $Pools_Hashrates[$_.Name]) {$Pools_Hashrates[$_.Name]=1}}
        $NewPools | Where-Object {-not $_.SoloMining -and $_.TSL -ne $null -and $Session.Config.Pools."$($_.Name)".EnablePostBlockMining -and $_.CoinSymbol -and ($_.TSL -lt $Session.Config.Coins."$($_.CoinSymbol)".PostBlockMining)} | Foreach-Object {$_ | Add-Member PostBlockMining $true -Force}

        $ActiveRunningMiners = [System.Collections.Generic.List[PSCustomObject]]::new()

        $Global:ActiveMiners | Where-Object { $_.Status -eq [MinerStatus]::Running } | Foreach-Object { [void]$ActiveRunningMiners.Add($_) }

        foreach ($Miner in $ActiveRunningMiners) {
            for ($i = 0; $i -lt $Miner.Pool.Count; $i++) {
                $Pool_Ix = "$($Miner.Pool | Select-Object -Index $i)-$($Miner.BaseAlgorithm | Select-Object -Index $i)-$($Miner.CoinSymbol | Select-Object -Index $i)"

                if (-not $Pools_Running.ContainsKey($Pool_Ix) -or $Pools_Running[$Pool_Ix] -gt $Miner.Rounds) {
                    $Pools_Running[$Pool_Ix] = $Miner.Rounds
                }

                $Pools_Benchmarking[$Pool_Ix] = $Pools_Benchmarking[$Pool_Ix] -or $Miner.NeedsBenchmark
            }
        }

        $Session.DecayFact = [Math]::Min($Session.Config.SwitchingPrevention,1) * [Math]::Pow($Session.DecayBase, [int](($Session.Timer - $Session.DecayStart).TotalSeconds / $Session.DecayPeriod) / ([Math]::Max($Session.Config.SwitchingPrevention,1)))

        Write-Log "Calculating pool compare prices. "
        foreach ( $Pool in $NewPools ) {
            $Pool_Ix = "$($Pool.Name)-$($Pool.Algorithm0)-$($Pool.CoinSymbol)"
            if ($Pools_PriceCmp[$Pool_Ix] -eq $null) {
                $Price_Cmp = $Pool."$(if (-not $Session.Config.EnableFastSwitching -and ($Session.Config.ForceStablePrice -or -not $Pool.PaysLive)) {"Stable"})Price"
                if (-not $Pool.Exclusive) {
                    $Pool_Rounds = $Pools_Running[$Pool_Ix]
                    if ($Pool_Rounds -ne $null -and ($Session.IsBenchmarkingRun -and $Pools_Benchmarking[$Pool_Ix] -or $Pool_Rounds -lt $Session.Config.MinimumMiningIntervals)) {
                        $Price_Cmp *= 100
                    } elseif (-not $Pool.PostBlockMining -and $Pool.CoinSymbol -and $Session.Config.Pools."$($Pool.Name)".CoinSymbolPBM -icontains $Pool.CoinSymbol) {
                        $Price_Cmp = 0
                        $Pool | Add-Member DisabledDueToCoinSymbolPBM $true -Force
                    } else {
                        $Price_Cmp *= [Math]::Min(([Math]::Log([Math]::Max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $Pool.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)
                        if (-not ($Session.Config.EnableFastSwitching -or $Session.SkipSwitchingPrevention)) {
                            if ($Pool_Rounds -eq $null) {
                                if ($Session.Config.Pools."$($Pool.Name)".MaxMarginOfError) {
                                    $Price_Cmp *= 1-([Math]::Floor(([Math]::Min($Pool.MarginOfError,$Session.Config.Pools."$($Pool.Name)".MaxMarginOfError/100) * $Session.DecayFact) * 100.00) / 100.00) * $PoolAccuracyWeight
                                }
                            } elseif ($Session.Config.Pools."$($Pool.Name)".SwitchingHysteresis -ne $null) {
                                $Price_Cmp *= 1 + ($Session.Config.Pools."$($Pool.Name)".SwitchingHysteresis/100)
                            } elseif ($Session.Config.PoolSwitchingHystereis -ne 1) {
                                $Price_Cmp *= $PoolSwitchingHysteresis
                            }
                        }
                        if (-not $Pool.SoloMining -and $Pool.HashRate -ne $null -and $Session.Config.HashrateWeightStrength) {
                            $Price_Cmp *= 1 - (1 - [Math]::Pow($Pool.Hashrate/$Pools_Hashrates["$($Pool.Algorithm0)-$($Pool.CoinSymbol)"],$HashrateWeightStrength)) * $HashrateWeight
                        }
                    }
                }
                $Pools_PriceCmp[$Pool_Ix] = $Price_Cmp
            }
        }

        Write-Log "Selecting best pool for each algorithm. "
        $SortedPools = [System.Collections.Generic.List[PSCustomObject]]::new()
        $NewPools | Sort-Object -Descending {$_.Exclusive -and -not $_.Idle}, {$Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and $Session.Config.Pools."$($_.Name)".FocusWallet -icontains $_.Currency}, {$LockMiners -and $Session.LockMiners.Pools -icontains "$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"}, {$_.PostBlockMining}, {$Pools_PriceCmp["$($_.Name)-$($_.Algorithm0)-$($_.CoinSymbol)"]}, {$_.Region -eq $Session.Config.Region}, {$ix = $Session.Config.DefaultPoolRegion.IndexOf($_.Region);[int]($ix -ge 0)*(100-$ix)}, {$_.SSL -eq $Session.Config.Pools."$($_.Name)".SSL} | Foreach-Object { [void]$SortedPools.Add($_) }

        $NewPoolAlgorithms = @($NewPools | Foreach-Object {$_.Algorithm.ToLower()} | Select-Object -Unique)

        foreach($Algorithm_Name in $NewPoolAlgorithms) {
            $FirstMatch = $null

            foreach ($Pool in $SortedPools) {
                if ($Pool.Algorithm -eq $Algorithm_Name -and -not $Pool.DisabledDueToCoinSymbolPBM) {
                    $FirstMatch = $Pool
                    break   # Stop once we find the first match
                }
            }

            if ($FirstMatch) {
                $Pools | Add-Member -MemberType NoteProperty -Name $Algorithm_Name -Value $FirstMatch
            }
        }
        
        $Pools_OutOfSyncMinutes = 0
        if ($Pools.PSObject.Properties.Name.Count -gt 1) {
            try {
                $Pools_OutOfSyncMinutes = [double]($Pools.PSObject.Properties.Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {($NewPools | Where-Object Name -eq $_ | Where-Object Updated -ge $OutOfSyncTime | Measure-Object Updated -Maximum).Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum}).TotalMinutes
                if ($Pools_OutOfSyncMinutes -gt $Session.SyncWindow) {
                    Write-Log "Pool prices are out of sync ($([int]$Pools_OutOfSyncMinutes) minutes). "
                }
            } catch {
            }
        }

        $Pools.PSObject.Properties.Name | ForEach-Object {
            $Pool_Price = $Pools.$_.Price
            $Pool_Name  = $Pools.$_.Name
            if (-not $Pools.$_.Exclusive) {
                $Pool_Price *= [Math]::Min(([Math]::Log([Math]::Max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $Pools.$_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)
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
    $FilteredPools = foreach ($Pool in $Pools.PSObject.Properties.Value) {
        if (-not $Pool.SoloMining -or $Pool.BLK) {
            $Pool
        }
    }
    if (-not $FilteredPools) { $FilteredPools = @() }
    elseif ($FilteredPools.Count -eq 1) { $FilteredPools = @($FilteredPools) }

    $API.Pools = ConvertTo-Json $FilteredPools -Depth 10 -ErrorAction Ignore
 
    $FilteredPools = $null

    #Load information about the miners
    Write-Log -Level Info "Getting miner information. "

    if ($Session.RoundCounter -eq 0) {Write-Host "Loading miner modules .."}

    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Session.Config.MinerName, if specified, and don't match $Session.Config.ExcludeMinerName

    $Miner_DontCheckForUnprofitableCpuAlgos = -not $Global:DeviceCache.DevicesByTypes.CPU -or $Session.Config.DisableUnprofitableCpuAlgolist -or $Session.Conifg.EnableNeverprofitableAlgos

    $AllMiners = [System.Collections.Generic.List[PSCustomObject]]::new()
    if ($NewPools.Count -and (Test-Path "Miners")) {

        Get-MinersContent -Parameters @{Pools = $Pools; InfoOnly = $false} | Foreach-Object {
            $Miner = $_

            $Miner_Name = $Miner.BaseName

            if (-not $Miner.DeviceName -or ($Miner.DeviceModel -match '-' -and (Compare-Object $Miner.DeviceName $Global:DeviceCache.DeviceNames."$($Miner.DeviceModel)"))) { return }
            if (-not $Miner_DontCheckForUnprofitableCpuAlgos -and $Miner.DeviceModel -eq "CPU" -and $Miner.BaseAlgorithm -in $UnprofitableCpuAlgos) { return }
            if ($Session.Config.DisableDualMining -and $Miner.HashRates.PSObject.Properties.Name.Count -gt 1) { return }
            if (Compare-Object $Global:DeviceCache.DevicesNames $Miner.DeviceName | Where-Object SideIndicator -EQ "=>") { return }
            if ($Session.Config.Miners."$($Miner_Name)-$($Miner.DeviceModel)-$($Miner.BaseAlgorithm)".Disable) { return }

            foreach ($Algo in $Miner.HashRates.PSObject.Properties.Name) {
                if ($Pools.$Algo.HasMinerExclusions) {
                    $Pool_Name = $Pools.$Algo.Name
                    if (($Session.Config.Pools.$Pool_Name.MinerName.Count -and $Session.Config.Pools.$Pool_Name.MinerName -notcontains $Miner_Name) -or
                        ($Session.Config.Pools.$Pool_Name.ExcludeMinerName.Count -and $Session.Config.Pools.$Pool_Name.ExcludeMinerName -contains $Miner_Name)) {
                        return
                    }
                }
            }

            $BaseAlgos = $Miner.BaseAlgorithm -split '-'
            if ($Global:AlgorithmMinerName.Count) {
                foreach ($Algo in $BaseAlgos) {
                    if ($Global:AlgorithmMinerName.Contains($Algo) -and (
                        ($Session.Config.Algorithms.$Algo.MinerName.Count -and $Session.Config.Algorithms.$Algo.MinerName -notcontains $Miner_Name) -or
                        ($Session.Config.Algorithms.$Algo.ExcludeMinerName.Count -and $Session.Config.Algorithms.$Algo.ExcludeMinerName -contains $Miner_Name))) {
                        return
                    }
                }
            }

            foreach ($Device in $Miner.DeviceModel -split '-') {
                if ($Session.Config.Miners."$($Miner_Name)-$Device-$($Miner.BaseAlgorithm)".Disable) { return }

                if ($Session.Config.Devices.$Device) {
                    $DeviceConfig = $Session.Config.Devices.$Device
                    if (($DeviceConfig.DisableDualMining -and $Miner.HashRates.PSObject.Properties.Name.Count -gt 1) -or
                        ($DeviceConfig.Algorithm.Count -gt 0 -and -not (Test-Intersect $DeviceConfig.Algorithm $BaseAlgos)) -or
                        ($DeviceConfig.ExcludeAlgorithm.Count -gt 0 -and (Test-Intersect $DeviceConfig.ExcludeAlgorithm $BaseAlgos)) -or
                        ($DeviceConfig.MinerName.Count -gt 0 -and $DeviceConfig.MinerName -notcontains $Miner_Name) -or
                        ($DeviceConfig.ExcludeMinerName.Count -gt 0 -and $DeviceConfig.ExcludeMinerName -contains $Miner_Name)) {
                        return
                    }
                }
            }


            if ($Miner.DotNetRuntime -and (Compare-Version $Miner.DotNetRuntime $Session.Config.DotNETRuntimeVersion) -gt 0) {
                Write-Log -Level Warn "$Miner_Name requires .NET Core Runtime (min. version $($Miner.DotNetRuntime)) to be installed! Find the installer here: https://dotnet.microsoft.com/download"
                return
            }

            [void]$AllMiners.Add($Miner)
        }
    }

    if ($Session.Config.MiningMode -eq "combo") {

        Write-Log -Level Info "Start add missing combos"

        $Remove_Combos = $false

        # Check if benchmarking is still ongoing on non-combo miners

        foreach( $Miner in $AllMiners ) {
            if ($Miner.DeviceModel -ne "CPU" -and $Miner.HashRates.PSObject.Properties.Value -contains $null -and $Miner.DeviceModel -notmatch '-') {

                # Benchmarking still ongoing (1/2) - make sure no combo stat is left over

                $ComboAlgos = $Miner.BaseAlgorithm -split '-'
                foreach( $cbMiner in $AllMiners ) {
                    if ($cbMiner.BaseName -eq $Miner.BaseName -and 
                        $cbMiner.BaseAlgorithm -eq $Miner.BaseAlgorithm -and 
                        $cbMiner.DeviceModel -match '-' -and 
                        $cbMiner.HashRates.PSObject.Properties.Value -notcontains $null -and
                        @($cbMiner.DeviceModel -split '-') -contains $Miner.DeviceModel) {

                        foreach ( $cbAlgo in $ComboAlgos ) {
                            $Miner_StatKey = "$($cbMiner.Name)_$($cbAlgo)_HashRate"
                            Get-ChildItem ".\Stats\Miners\*-$($Miner_StatKey).txt" | Remove-Item -ErrorAction Ignore
                            if ($Global:StatsCache.ContainsKey($Miner_StatKey)) {
                                [void]$Global:StatsCache.Remove($Miner_StatKey)
                            }
                        }
                    }
                }

                $Remove_Combos = $true
            }
        }

        if ($Remove_Combos) {

            # Benchmarking is still ongoing (2/2) - remove device combos
            [void]$AllMiners.RemoveAll({
                param ($Miner)
                -not ($Miner.DeviceModel -eq "CPU" -or $Miner.DeviceModel -notmatch '-')
            })

        } else {

            # Remove device combos, where the parameter-preset is different and there does not exist an own definition

            [void]$AllMiners.RemoveAll({
                param ($Miner)
                if ($Miner.DeviceModel -eq "CPU") { return }
                if ($Miner.DeviceModel -notmatch '-') { return }
                if ($null -ne $Session.Config.Miners.PSObject.Properties["$($Miner.BaseName)-$($Miner.DeviceModel)-$($Miner.BaseAlgorithm)"]) {
                    return
                }
                $ConfigCount = ($Miner.DeviceModel -split '-' | ForEach-Object {
                    $Miner_ConfigName = "$($Miner.BaseName)-$_-$($Miner.BaseAlgorithm)"
                    if ($null -ne $Session.Config.Miners.PSObject.Properties[$Miner_ConfigName]) {
                        $Session.Config.Miners.$Miner_ConfigName.Params
                    }
                } | Select-Object -Unique | Measure-Object).Count

                if ($ConfigCount -le 1) { return }

                return $true
            })

            Write-Log "Gather mining statistics for fresh combos"

            # Gather mining statistics for fresh combos

            foreach ( $Miner in $AllMiners ) {
                if ($Miner.DeviceModel -ne "CPU" -and $Miner.HashRates.PSObject.Properties.Value -contains $null -and $Miner.DeviceModel -match '-') {

                    $Miner.PowerDraw = 0

                    $Miner.DeviceModel -split '-' | Foreach-Object {

                        $ComboDevice = $_

                        foreach ($cbMiner in $AllMiners) {
                            if ($cbMiner.BaseName -eq $Miner.BaseName -and $cbMiner.BaseAlgorithm -eq $Miner.BaseAlgorithm -and $cbMiner.DeviceModel -eq $ComboDevice) {
                                $ComboHash = [PSCustomObject]@{}
                                foreach ($HashProp in $cbMiner.HashRates.PSObject.Properties) {
                                    $ComboHash | Add-Member "$($HashProp.Name -replace "-.+$")" $HashProp.Value
                                }
                                $Miner.PowerDraw += $cbMiner.PowerDraw
                                $ComboHash
                                break
                            }
                        }

                    } | Measure-Object -Sum @($Miner.BaseAlgorithm -split '-') | Foreach-Object {
                        $ComboValue = $_
                        $Miner.HashRates.PSObject.Properties.Name | Where-Object {$_ -eq $ComboValue.Property -or $_ -match "^$($ComboValue.Property)-"} | Foreach-Object {
                            $Miner.HashRates.$_ = $ComboValue.Sum * 1.02
                            # we exagerate a bit to prefer combos over single miners for startup. If the combo runs less good, later, it will fall back by itself
                        }
                    }
                }
            }
        }

        # avoid benchmarks of combo miners

        [void]$AllMiners.RemoveAll({
            param ($Miner)

            if ($Miner.DeviceModel -eq "CPU") { return }
            if ($Miner.DeviceModel -notmatch '-') { return }
            if ($Miner.HashRates.PSObject.Properties.Value -notcontains $null) { return }

            return $true
        })

        Write-Log -Level Info "End add missing combos"
        #ConvertTo-Json $AllMiners -Depth 10 | Set-Content ".\Cache\allminers.json"
    }

    #Handle fastlane benchmarks
    if (-not ($Session.RoundCounter % 50) -and $Session.Config.EnableFastlaneBenchmark) {
        $SkipBenchmarksData = [PSCustomObject]@{}
        $SkipBenchmarksCount = 0
        foreach( $Miner in $AllMiners ) {
            if ($Miner.HashRates.PSObject.Properties.Value -contains $null -and $Miner.HashRates.PSObject.Properties.Name.Count -eq 1) {
                $Miner.DeviceModel -split "-" | Foreach-Object {
                    if (-not [bool]$SkipBenchmarksData.PSObject.Properties[$_]) {$SkipBenchmarksData | Add-Member $_ ([System.Collections.Generic.List[PSCustomObject]]::new()) -Force}

                    $Miner_Name = $Miner.BaseName
                    $Miner_Ver = $Miner.Version

                    $MatchFound = $false
                    foreach ($Item in $SkipBenchmarksData.$_) {
                        if ($Item.name -eq $Miner_Name -and $Item.ver -eq $Miner_Ver) {
                            $MatchFound = $true
                            break
                        }
                    }

                    if (-not $MatchFound) {
                        [void]$SkipBenchmarksData.$_.Add([PSCustomObject]@{
                            name = $Miner_Name
                            ver  = $Miner_Ver
                        })
                        $SkipBenchmarksCount++
                    }
                }
            }
        }

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

                $Response = Invoke-GetUrl "https://api.rbminer.net/qbench.php" -body @{q=$Request} -timeout 10
            } catch {
            }

            if ($Response.status) {
                $Miner_Models = @{}
                foreach ( $Device in $Global:DeviceCache.Devices ) {
                    $Miner_Models[$Device.Name] = $Device.Model_Base
                }

                foreach ($Miner in $AllMiners) {
                    if ($Miner.HashRates.PSObject.Properties.Value -contains $null -and $Miner.HashRates.PSObject.Properties.Name.Count -eq 1) {
        
                        $Miner_Name = $Miner.BaseName
                        $Miner_Algo = "$($Miner.HashRates.PSObject.Properties.Name -replace '\-.*$')"
                        $Miner_HR   = 0
        
                        foreach ($Device in $Miner.DeviceName) {
                            $Miner_HR += $Response.data."$($Miner_Models[$Device])".$Miner_Name.$Miner_Algo.hr
                        }
        
                        if (($Miner_HR -gt 0) -or -not $Session.Config.EnableFastlaneBenchmarkMissing) {
                            $Miner.HashRates."$($Miner.HashRates.PSObject.Properties.Name)" = $Miner_HR
                            $Miner.PowerDraw = 0

                            foreach ($Device in $Miner.DeviceName) {
                                $Miner.PowerDraw += $Response.data."$($Miner_Models[$Device])".$Miner_Name.$Miner_Algo.pd
                            }

                            if ($Miner.HashRates.PSObject.Properties.Name -eq $Miner_Algo) {
                                Set-Stat -Name "$($Miner.Name)_$($Miner_Algo)_HashRate" `
                                         -Value $Miner_HR `
                                         -Duration (New-TimeSpan -Seconds 10) `
                                         -FaultDetection $false `
                                         -PowerDraw $Miner.PowerDraw `
                                         -Sub $Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel] `
                                         -Version "$(Get-MinerVersion $Miner.Version)" `
                                         -IsFastlaneValue `
                                         -Quiet > $null
                            }
                        }

                        if ($Miner_HR -gt 0) { $Fastlane_Success++ } else { $Fastlane_Failed++ }
                    }
                }

                Write-Log "Fastlane benchmarks: $Fastlane_Success x success, $Fastlane_Failed x failed"
                if ($Session.RoundCounter -eq 0) {Write-Host "ok ($Fastlane_Success x success, $Fastlane_Failed x failed)" -ForegroundColor Green}
            } else {
                Write-Log "Failed to get fastlane benchmark results from api.rbminer.net"
                if ($Session.RoundCounter -eq 0) {Write-Host "failed" -ForegroundColor Red}
            }
        }

        $Response = $null
        $Request = $null
        $SkipBenchmarksData = $null
        Remove-Variable -Name Response, Request, SkipBenchmarksData -ErrorAction Ignore
    }

    if ($Session.RoundCounter -eq 0) {Write-Host "Selecting best miners .."}

    #Remove all miners, that need benchmarks during donation run
    if ($Session.IsDonationRun -or $Session.IsServerDonationRun) {
        [void]$AllMiners.RemoveAll({
            param ($Miner)
            return $Miner.HashRates.PSObject.Properties.Value -contains $null
        })
    }

    Write-Log "Calculating profit for each miner. "

    $HmF = if ($EnableMiningHeatControl) {3-$MiningHeatControl} else {1.0}

    $MinerFaultToleranceCPU = $Session.Config.MinerFaultToleranceCPU/100
    $MinerFaultToleranceGPU = $Session.Config.MinerFaultToleranceGPU/100
    $MinerPowerPrice        = (100+$Session.Config.PowerOffsetPercent)*24/100000 * $Session.CurrentPowerPriceBTC

    $AllMiners_VersionCheck = [hashtable]@{}
    $Miner_Arguments_List   = [System.Collections.Generic.List[string]]::new()

    $MinerUpdateDB = $null

    foreach ( $Miner in $AllMiners ) {

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
            BenchmarkOnly = $Pools.$($Miner_AlgoNames[0]).BenchmarkOnly -or ($Miner_AlgoNames.Count -gt 1 -and $Pools.$($Miner_AlgoNames[1]).BenchmarkOnly)
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
            $Miner_HashAdjust = $Miner_Hash2Adjust = -111
            $Miner_CommonCommands_found = $false
            $Miner_CommonCommands_array = [System.Collections.Generic.List[string]]::new()
            [void]$Miner_CommonCommands_array.AddRange([string[]]@($Miner.BaseName,$Miner.DeviceModel))
            [void]$Miner_CommonCommands_array.AddRange([string[]]@($Miner.BaseAlgorithm -split '-' | Select-Object))
            for($i=$Miner_CommonCommands_array.Count;$i -gt 0; $i--) {
                $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                    if ($Session.Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Session.Config.Miners.$Miner_CommonCommands.Params}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Difficulty -and $Miner_Difficulty -eq '') {$Miner_Difficulty = $Session.Config.Miners.$Miner_CommonCommands.Difficulty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -eq 0) {$Miner_MSIAprofile = [int]$Session.Config.Miners.$Miner_CommonCommands.MSIAprofile}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and $Miner_Penalty -eq -1) {$Miner_Penalty = [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.HashAdjust -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.HashAdjust -ne '' -and $Miner_HashAdjust -eq -111) {$Miner_HashAdjust = [double]$Session.Config.Miners.$Miner_CommonCommands.HashAdjust}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Hash2Adjust -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Hash2Adjust -ne '' -and $Miner_Hash2Adjust -eq -111) {$Miner_Hash2Adjust = [double]$Session.Config.Miners.$Miner_CommonCommands.Hash2Adjust}
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
                    if ($Session.Config.Miners.$Miner_CommonCommands.HashAdjust -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.HashAdjust -ne '' -and $Miner_HashAdjust -eq -111) {$Miner_HashAdjust = [double]$Session.Config.Miners.$Miner_CommonCommands.HashAdjust}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Hash2Adjust -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Hash2Adjust -ne '' -and $Miner_Hash2Adjust -eq -111) {$Miner_Hash2Adjust = [double]$Session.Config.Miners.$Miner_CommonCommands.Hash2Adjust}
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
                                [void]$Miner_Arguments_List.Add("$($pcmd)$(if ($parg) {"$($pdiv)$($parg)"})")
                            }
                        } else {
                            [void]$Miner_Arguments_List.Add($p)
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

        if (-not $Miner.MSIAprofile -and $Miner_AlgoNames.Count -eq 1 -and $Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".MSIAprofile -gt 0) {$Miner | Add-Member -Name MSIAprofile -Value $Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".MSIAprofile -MemberType NoteProperty -Force}

        foreach($p in @($Miner.DeviceModel -split '-')) {if ($Miner.OCprofile[$p] -eq '') {$Miner.OCprofile[$p]=if ($Miner_AlgoNames.Count -eq 1 -and $Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".OCprofile -ne "") {$Session.Config.Algorithms."$($Miner.BaseAlgorithm -replace '-.*$')".OCprofile} else {$Session.Config.Devices.$p.DefaultOCprofile}}}

        $Miner.DeviceName = @($Miner.DeviceName | Select-Object -Unique | Sort-Object)

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $AllMiners_VersionCheck.ContainsKey($Miner.BaseName)) {

            $Miner_Version = Get-MinerVersion $Miner.Version

            $AllMiners_VersionCheck[$Miner.BaseName] = [PSCustomObject]@{
                Ok      = $false
                Version = "$($Miner_Version)"
                Algos   = @{}
                Date    = $null
                MVC     = $null
            }

            $Miner_UriJson = Join-Path (Get-MinerInstPath $Miner.Path) "_uri.json"

            if ((Test-Path $Miner.Path) -and (Test-Path $Miner_UriJson)) {

                $Miner_Uri = Get-ContentByStreamReader $Miner_UriJson | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty URI

                if ($Miner_Uri) {
                    if ($Miner_Uri -eq $Miner.URI) {
                        $AllMiners_VersionCheck[$Miner.BaseName].Ok = $true
                    } elseif ($Session.Config.AutoBenchmarkMode -ne "all") { # -eq "updated"
                        $Miner_FromVersion = Get-MinerVersion $Miner_Uri

                        if ($MinerUpdateDB -eq $null -and (Test-Path "Data\minerupdatedb.json")) {
                            $AlgoVariants = Get-AlgoVariants
                            $MinerUpdateDB = Get-ContentByStreamReader "Data\minerupdatedb.json" | ConvertFrom-Json -ErrorAction Ignore
                            $MinerUpdateDB | Foreach-Object {
                                $_.FromVersion = Get-MinerVersion $_.FromVersion
                                $_.ToVersion   = Get-MinerVersion $_.ToVersion
                                $_.Algorithm   = $_.Algorithm.Foreach({$algo = Get-Algorithm $_;if ($AlgoVariants.$algo) {$AlgoVariants.$algo} else {$algo}})
                                if ($_.Driver) {
                                    $_.Driver | Foreach-Object {
                                        $_.Algorithm   = $_.Algorithm.Foreach({$algo = Get-Algorithm $_;if ($AlgoVariants.$algo) {$AlgoVariants.$algo} else {$algo}})
                                    }
                                }
                            }
                        }

                        $Miner_VersionCheck = $MinerUpdateDB | Where-Object {$_.MinerName -eq $Miner.BaseName -and $_.FromVersion -ge $Miner_FromVersion -and $_.ToVersion -le $Miner_Version}

                        if ($Miner_VersionCheck -and ($Miner_VersionCheck | Where-Object {$_.ToVersion -eq $Miner_Version} | Measure-Object).Count) {
                            $AllMiners_VersionCheck[$Miner.BaseName].MVC = $Miner_VersionCheck                            
                        }
                    }
                }
                
                $AllMiners_VersionCheck[$Miner.BaseName].Date  = (Get-ChildItem $Miner_UriJson).LastWriteTimeUtc
            }

        }
        
        if ($AllMiners_VersionCheck[$Miner.BaseName].MVC -and -not $AllMiners_VersionCheck[$Miner.BaseName].Algos.ContainsKey($Miner.DeviceModel)) {

            $Miner_CheckAlgos = $AllMiners_VersionCheck[$Miner.BaseName].MVC | Foreach-Object {
                $Miner_CheckAlgo = $_.Algorithm

                if ($_.Driver) {
                    foreach ($Driver in $_.Driver) {
                        $Driver_Vendor      = $Driver.Vendor
                        $Driver_FromVersion = if ($Driver.FromVersion) { Get-Version $Driver.FromVersion }
                        $Driver_ToVersion   = if ($Driver.ToVersion) { Get-Version $Driver.ToVersion }
                        $Driver_Arch        = $Driver.Arch

                        $Driver_Compatible = $false
                        foreach ($Device in $Global:DeviceCache.Devices) {
                            if (
                                $Device.Vendor -eq $Driver_Vendor -and
                                $Device.Type -eq "Gpu" -and
                                $Device.Name -in $Miner.DeviceName -and
                                (-not $Driver_Arch -or $Device.OpenCL.Architecture -in $Driver_Arch) -and
                                (-not $Driver_FromVersion -or $Driver_FromVersion -le (Get-Version $Device.OpenCL.DriverVersion)) -and
                                (-not $Driver_ToVersion -or $Driver_ToVersion -ge (Get-Version $Device.OpenCL.DriverVersion))
                            ) {
                                $Driver_Compatible = $true
                                break
                            }
                        }

                        if ($Driver_Compatible) {
                            $Miner_CheckAlgo = $Driver.Algorithm
                        }
                    }
                }

                $Miner_CheckAlgo
            } | Select-Object -Unique
                                
            $AllMiners_VersionCheck[$Miner.BaseName].Algos[$Miner.DeviceModel] = if ($Miner_CheckAlgos -notcontains '*') {$Miner_CheckAlgos} else {$null}

        }

        $NeedsReset = $false
        if ($Session.Config.EnableAutoBenchmark -and ($Session.Config.MiningMode -eq "legacy" -or $Miner.DeviceModel -notmatch '-') -and $AllMiners_VersionCheck[$Miner.BaseName].Date -ne $null) {

            $Miner_BaseAlgorithm = $Miner.BaseAlgorithm -split '-'

            $Miner_StatKey = "$($Miner.Name)_$($Miner_BaseAlgorithm[0])_HashRate"

            if ($Global:StatsCache.ContainsKey($Miner_StatKey) -and (($Global:StatsCache[$Miner_StatKey].Version -ne $null -and $Global:StatsCache[$Miner_StatKey].Version -ne $AllMiners_VersionCheck[$Miner.BaseName].Version) -or ($Global:StatsCache[$Miner_StatKey].Version -eq $null -and $Global:StatsCache[$Miner_StatKey].Updated -lt $AllMiners_VersionCheck[$Miner.BaseName].Date))) {
            
                if (-not $AllMiners_VersionCheck[$Miner.BaseName].Algos[$Miner.DeviceModel] -or (Test-Intersect $AllMiners_VersionCheck[$Miner.BaseName].Algos[$Miner.DeviceModel] $Miner_BaseAlgorithm)) {

                    [void]$Global:StatsCache.Remove($Miner_StatKey)

                    Get-ChildItem ".\Stats\Miners\*-$($Miner.Name -replace "-(CPU|GPU)#.+")-$($Miner.DeviceName -join '*')*_$($Miner_BaseAlgorithm[0])_HashRate.txt" | Remove-Item -ErrorAction Ignore

                    if ($Miner_BaseAlgorithm.Count -gt 1) {
                        $Miner_StatKey = "$($Miner.Name)_$($Miner_BaseAlgorithm[1])_HashRate"
                        if ($Global:StatsCache.ContainsKey($Miner_StatKey)) {
                            [void]$Global:StatsCache.Remove($Miner_StatKey)
                        }
                        Get-ChildItem ".\Stats\Miners\*-$($Miner.Name -replace "-(CPU|GPU)#.+")-$($Miner.DeviceName -join '*')*_$($Miner_BaseAlgorithm[1])_HashRate.txt" | Remove-Item -ErrorAction Ignore
                    }
                    $NeedsReset = $true

                } else {

                    $Miner_Version = $AllMiners_VersionCheck[$Miner.BaseName].Version

                    if ([bool]$Global:StatsCache[$Miner_StatKey].PSObject.Properties["Version"]) {                            
                        $Global:StatsCache[$Miner_StatKey].Version = $Miner_Version
                    } else {
                        $Global:StatsCache[$Miner_StatKey] | Add-Member Version $Miner_Version -Force
                    }

                    try {
                        $Miner_Stat = $Global:StatsCache[$Miner_StatKey] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -ErrorAction Ignore
                        $Miner_Stat.Duration = [string]$Miner_Stat.Duration
                        $Miner_Stat.IsFL     = [bool]$Miner_Stat.IsFL
                        $Miner_Stat | ConvertTo-Json -Depth 10 | Set-Content ".\Stats\Miners\$($Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel])-$($Miner_StatKey).txt"

                        if ($Miner_BaseAlgorithm.Count -gt 1) {
                            $Miner_StatKey = "$($Miner.Name)_$($Miner_BaseAlgorithm[1])_HashRate"
                            if ($Global:StatsCache.ContainsKey($Miner_StatKey)) {
                                if ([bool]$Global:StatsCache[$Miner_StatKey].PSObject.Properties["Version"]) {                            
                                    $Global:StatsCache[$Miner_StatKey].Version = $Miner_Version
                                } else {
                                    $Global:StatsCache[$Miner_StatKey] | Add-Member Version $Miner_Version -Force
                                }

                                $Miner_Stat = $Global:StatsCache[$Miner_StatKey] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -ErrorAction Ignore
                                $Miner_Stat.Duration = [string]$Miner_Stat.Duration
                                $Miner_Stat.IsFL     = [bool]$Miner_Stat.IsFL
                                $Miner_Stat | ConvertTo-Json -Depth 10 | Set-Content ".\Stats\Miners\$($Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel])-$($Miner_StatKey).txt"
                            }
                        }
                        $Miner_Stat = $null
                    } catch {
                        Write-Log -Level Info "Problem updating version number in $($Miner_StatKey).txt"
                    }
                }
            }
        }

        $NoResult = $false
        $BadDualMiner = $false
        $i = 0
        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object {
            $Miner.DevFee.$_ = ([Double]$(if (-not $Session.Config.IgnoreFees) {$Miner.DevFee.$_} else {0}))

            if (-not [String]$Miner.HashRates.$_ -or $NeedsReset) {
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
                $Miner_HashAdjustFactor   = if ($i) {$Miner_Hash2Adjust} else {$Miner_HashAdjust}
                if ($Miner_HashAdjustFactor -ne -111) {
                    $Miner.HashRates.$_ *= 1 + $Miner_HashAdjustFactor/100
                }
                $Miner.Difficulties[$_]   = ([Double]$Global:StatsCache.$Miner_Name.Diff_Average)
                $Miner.Ratios[$_]         = ([Double]$Global:StatsCache.$Miner_Name.Ratio_Live)
                $Miner_Profits[$_]        = ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * $Miner_DevFeeFactor)
                $Miner_Profits_Bias[$_]   = ([Double]$Miner.HashRates.$_ * ($Pools.$_.Price_Bias+1e-32) * $Miner_DevFeeFactor)
                $Miner_Profits_Unbias[$_] = ([Double]$Miner.HashRates.$_ * ($Pools.$_.Price_Unbias+1e-32) * $Miner_DevFeeFactor)

                if ($i -and $Miner.HashRates.$_ -le 0) {$BadDualMiner = $true}

                $i++
            }
        }

        if ($NoResult) {
            $Miner.Profit        = $null
            $Miner.Profit_Bias   = $null
            $Miner.Profit_Unbias = $null
            $Miner.Profit_Cost   = $null
        } elseif ($BadDualMiner) {
            $Miner.Profit        = 0
            $Miner.Profit_Bias   = 0
            $Miner.Profit_Unbias = 0
            $Miner.Profit_Cost   = 0
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

        if ($Miner.Arguments -is [string]) {$Miner.Arguments = ($Miner.Arguments -replace "\s+"," ").trim()}
        else {
            if ($Miner.Arguments.Params -is [string]) {$Miner.Arguments.Params = ($Miner.Arguments.Params -replace "\s+"," ").trim()}
            $Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress
        }
        try {$Miner_Difficulty = [double]($Miner_Difficulty -replace ",","." -replace "[^\d\.]")} catch {$Miner_Difficulty=0.0}
        if ($Miner.Arguments) {$Miner.Arguments = $Miner.Arguments -replace "\`$difficulty",$Miner_Difficulty -replace "{diff:(.+?)}","$(if ($Miner_Difficulty -gt 0){"`$1"})" -replace "{workername}|{workername:$($Session.Config.WorkerName)}",$(@($Miner.DeviceModel -split '\-' | Foreach-Object {if ($Session.Config.Devices.$_.Worker) {$Session.Config.Devices.$_.Worker} else {$Session.Config.WorkerName}} | Select-Object -Unique) -join '_') -replace "{workername:(.+?)}","`$1"}

        if (-not $Miner.ExtendInterval -or $Session.Config.DisableExtendInterval) {$Miner.ExtendInterval = 1}
        if (-not $Miner.Penalty) {$Miner.Penalty = 0}
    }

    $MinerUpdateDB = $AlgoVariants = $null

    $Miners_DownloadList    = @()
    $Miners_DownloadListPrq = @()
    $Miners_DownloadMsgPrq  = $null

    $Miners = [System.Collections.Generic.List[PSCustomObject]]::new()

    $AllMiners.Where({ 
        (Test-Path $_.Path) -and 
        ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath)) -and 
        $AllMiners_VersionCheck[$_.BaseName].Ok
    }).ForEach({ [void]$Miners.Add($_) })

    if (($AllMiners.Count -ne $Miners.Count) -or $Session.StartDownloader) {

        $Miners_DownloadList    = @($AllMiners | Where-Object {$AllMiners_VersionCheck[$_.BaseName].Ok -ne $true} | Sort-Object {$_.ExtendInterval} -Descending | Select-Object -Unique @{name = "URI"; expression = {$_.URI}}, @{name = "Path"; expression = {$_.Path}}, @{name = "IsMiner"; expression = {$true}})
        $Miners_DownloadListPrq = @($AllMiners | Where-Object {$_.PrerequisitePath -and -not (Test-Path "$($_.PrerequisitePath)")} | Select-Object -Unique @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "IsMiner"; expression = {$false}})

        if ($Miners_DownloadList.Count -gt 0) {
            if ($Global:Downloader.State -ne "Running") {
                Clear-Host
                Write-Log "Starting download of $($Miners_DownloadList.Count) miners."
                if ($Session.RoundCounter -eq 0) {Write-Host "Starting downloader ($($Miners_DownloadList.Count) miners) .."}
                $Global:Downloader = Start-ThreadJob -InitializationScript ([scriptblock]::Create("Set-Location `"$((Get-Location).Path -replace '"','``"')`"")) -ArgumentList ($Miners_DownloadList) -FilePath .\Scripts\Downloader.ps1
            }
        } elseif ($Miners_DownloadListPrq.Count -gt 0) {
            $Miners_DownloadMsgPrq = @($AllMiners | Where-Object {$_.PrerequisitePath -and $_.PrerequisiteMsg -and -not (Test-Path $_.PrerequisitePath)} | Select-Object -Unique PrerequisiteMsg | Foreach-Object {$_.PrerequisiteMsg})
            if ($Global:Downloader.State -ne "Running" -and $Global:DownloaderPrq.State -ne "Running") {
                Write-Log "Starting download of $($Miners_DownloadListPrq.Count) pre-requisites."
                if ($Session.RoundCounter -eq 0) {Write-Host "Starting downloader ($($Miners_DownloadListPrq.Count) pre-requisites) .."}
                $Global:DownloaderPrq = Start-ThreadJob -InitializationScript ([scriptblock]::Create("Set-Location `"$((Get-Location).Path -replace '"','``"')`"")) -ArgumentList ($Miners_DownloadListPrq) -FilePath .\Scripts\Downloader.ps1
            }
        }

        $Session.StartDownloader = $false
    }

    $API.DownloadList      = $Miners_DownloadList + $Miners_DownloadListPrq
    $Miners_Downloading    = $Miners_DownloadList.Count
    $Miners_DownloadingPrq = $Miners_DownloadListPrq.Count

    $AllMiners = $null
    Remove-Variable -Name AllMiners -ErrorAction Ignore

    #$Global:StatsCache = $null

    #Open firewall ports for all miners
    if ($IsWindows) {
        try {
            if (Get-Command "Get-MpPreference" -ErrorAction Ignore) {
                if (Get-Command "Get-NetFirewallRule" -ErrorAction Ignore) {
                    if ($Global:MinerFirewalls -eq $null) {$Global:MinerFirewalls = Get-NetFirewallApplicationFilter | Where-Object {$_.Program -like "$(Get-Location)\Bin\*"} | Select-Object -ExpandProperty Program}
                    $OpenFirewallFor = "$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($Global:MinerFirewalls | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Depth 10 -Compress)"
                    if ($OpenFirewallFor -ne "") {
                        Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'$(if ($Session.IsCore) {" -SkipEditionCheck"}); ('$OpenFirewallFor' | ConvertFrom-Json -ErrorAction Ignore) | ForEach {New-NetFirewallRule -DisplayName 'RainbowMiner' -Program `$_}" -replace '"', '\"') -Verb runAs -WindowStyle Hidden
                        $Global:MinerFirewalls = $null
                        $OpenFirewallFor = $null
                        Remove-Variable -Name OpenFirewallFor -ErrorAction Ignore
                    }
                }
            }
        } catch {}
    }

    # Remove miners with developer fee
    if ($Session.Config.ExcludeMinersWithFee) {
        [void]$Miners.RemoveAll({
            param ($Miner)
            $TotalDevFee = 0
            foreach ($Fee in $Miner.DevFee.PSObject.Properties.Value) {
                $TotalDevFee += [Double]$Fee
            }
            return $TotalDevFee -ne 0  # Remove if DevFee > 0
        })
    }

    $Miners_BeforeWD_Count = $Miners.Count

    #Store miners to file and speeds to variable, if not DonationRUn
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {
        if (-not $Session.Benchmarking -and (-not $Session.Updatetracker.MinerSave -or $Session.Updatetracker.MinerSave -lt (Get-Date).AddHours(-6) -or -not (Test-Path ".\Data\minerdata.json"))) {
            $Session.Updatetracker.MinerSave = Get-Date
            Set-ContentJson ".\Data\minerdata.json" ([PSCustomObject]@{Miners = @($Miners | Where-Object {$_.BaseAlgorithm -notmatch "\-"} | Select-Object @{Name="Name";Expression={$_.BaseName}}, Version, @{Name="Algorithm";Expression={$_.BaseAlgorithm -replace '-.*$'}}, @{Name="DeviceName";Expression={$_.DeviceName -join '-'}}, DeviceModel, @{Name="HashRate"; Expression={$_.HashRates.PSObject.Properties.Value | Select-Object -First 1}}, PowerDraw, @{Name="OCProfile"; Expression={if ($Session.Config.EnableOCProfiles -and $_.DeviceModel -ne "CPU" -and $_.DeviceModel -notmatch '-') {$_.OCprofile.Values | Select-Object -First 1} else {""}}} -Unique); OCprofiles=$Session.Config.OCprofiles; CPU=$Global:DeviceCache.DevicesByTypes.CPU.Model_Name | Select-Object -Unique}) -Compress > $null
            $Session.ReportMinerData = $true
        }

        $Miners | Group-Object -Property BaseAlgorithm,DeviceModel | Foreach-Object {
            $Miner_Algo  = $_.Values[0] -replace "-.+$"
            $Miner_Key   = "$($Miner_Algo)-$($_.Values[1])"
            $Miner_Names = @($_.Group | Foreach-Object {"$($_.Name)_$($Miner_Algo)_Hashrate"} | Select-Object -Unique)
            $Miner_Miner = @($_.Group.BaseName | Select-Object -Unique)
            $_.Group | Sort-Object -Descending {$_.Profit -eq $null}, Profit_Bias | Select-Object -First 1 | Foreach-Object {
                $Miner_Hashrate = $_.Hashrates.PSObject.Properties.Value | Select-Object -First 1
                if ($Miner_Hashrate -eq $null) {
                    if ($Global:MinerSpeeds.ContainsKey($Miner_Key)) {
                        [void]$Global:MinerSpeeds.Remove($Miner_Key)
                    }
                } else {
                    $Miner_Hashrate = [Math]::Round($Miner_Hashrate,2)
                    if (-not $Global:MinerSpeeds.ContainsKey($Miner_Key)) {
                        $Global:MinerSpeeds[$Miner_Key] = [PSCustomObject]@{Hashrate=$Miner_Hashrate;Names=$Miner_Names;Miner=$Miner_Miner}
                    } else {
                        if ($Global:MinerSpeeds[$Miner_Key].Hashrate -ne $Miner_Hashrate) {
                            $Global:MinerSpeeds[$Miner_Key].Hashrate = $Miner_Hashrate
                        }
                        if (Compare-Object $Global:MinerSpeeds[$Miner_Key].Names $Miner_Names) {
                            $Global:MinerSpeeds[$Miner_Key].Names = $Miner_Names
                        }
                        if (Compare-Object $Global:MinerSpeeds[$Miner_Key].Miner $Miner_Miner) {
                            $Global:MinerSpeeds[$Miner_Key].Miner = $Miner_Miner
                        }
                    }
                }
            }
        }

        if (-not $Session.Updatetracker.SpeedsSave -or $Session.Updatetracker.SpeedsSave -lt (Get-Date).AddMinutes(-10) -or -not (Test-Path ".\Data\minerspeeds.json")) {
            $Session.Updatetracker.SpeedsSave = Get-Date
            Set-ContentJson ".\Data\minerspeeds.json" $Global:MinerSpeeds -Compress > $null
        }
    }

    [void]$Miners.RemoveAll({
        param ($Miner)

        # Check dual mining configuration
        if (-not ($Session.Config.DisableDualMining -or $Session.Config.EnableDualMiningDuringRentals -or
                  $Miner.HashRates.PSObject.Properties.Name.Count -eq 1 -or
                  -not $Miner.Pools.PSObject.Properties.Value.Where({ $_.Exclusive }).Count)) {
            return $true
        }

        # Apply Watchdog filters
        $Miner_WatchdogTimers = $Global:WatchdogTimers.Where({ $_.MinerName -eq $Miner.Name -and $_.Kicked -lt $WDIntervalTime -and $_.Kicked -gt $WDResetTime })    
        if ($Miner_WatchdogTimers.Count -ge 2) { return $true }
        if ($Miner_WatchdogTimers.Where({ $Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm }).Count -ge 1) { return $true }
    })

    #Give API access to the miners information
    ConvertTo-Json $Miners -Depth 10 -ErrorAction Ignore | Set-Content ".\Data\miners.json"

    # Remove all failed and disabled miners
    [void]$Miners.RemoveAll({
        param ($Miner)

        # Remove if miner is disabled or has 0 hashrates
        if ($Miner.Disabled -or $Miner.HashRates.PSObject.Properties.Value -contains 0) { return $true }

        # Optionally remove miners with 0 Watt
        if ($Session.Config.DisableZeroWattMiners -and
            (-not $Miner.PowerDraw -or $Miner.HashRates.PSObject.Properties.Value -contains $null)) {
            return $true  # Remove miner
        }
    })

    Write-Log "Reset active miners."

    #Reset the active miners
    foreach ( $Miner in $Global:ActiveMiners ) {
        $Miner.Profit = 0
        $Miner.Profit_Bias = 0
        $Miner.Profit_Unbias = 0
        $Miner.Profit_Cost = 0
        $Miner.Profit_Cost_Bias = 0
        $Miner.Best = $false
        $Miner.Stopped = $false
        $Miner.Enabled = $false
        $Miner.IsFocusWalletMiner = $false
        $Miner.IsExclusiveMiner = $false
        $Miner.IsLocked = $false
        $Miner.BenchmarkOnly = $false
        $Miner.PostBlockMining = 0
        $Miner.IsRunningFirstRounds = $Miner.Status -eq [MinerStatus]::Running -and $Miner.Rounds -lt $Session.Config.MinimumMiningIntervals -and -not $Session.IsBenchmarkingRun
    }

    #If either SkipSwitchingPrevention or EnableFastSwitching is set, simply ignore ErrorMargins
    if ($Session.SkipSwitchingPrevention -or $Session.Config.EnableFastSwitching) {
        foreach ( $Miner in $Miners ) {
            $Miner.Profit_Bias = $Miner.Profit_Unbias
        }
    }

    #Don't penalize active miners and apply switching hysteresis, also make sure FirstRounds is respected 
    $MinerSwitchingHysteresis = 1 + $Session.Config.MinerSwitchingHysteresis/100

    foreach ( $Miner in $Global:ActiveMiners ) {
        if ($Miner.Status -eq [MinerStatus]::Running) {
            foreach ( $m in $Miners ) {
                if ($m.Name -eq $Miner.Name -and
                    $m.Path -eq $Miner.Path -and
                    $m.Arguments -eq $Miner.Arguments -and
                    $m.API -eq $Miner.API -and
                    (Compare-Object $Miner.Algorithm ($m.HashRates.PSObject.Properties.Name | Select-Object) | Measure-Object).Count -eq 0) {

                    $m.Profit_Bias = $m.Profit_Unbias * $MinerSwitchingHysteresis
                    if ($Miner.IsRunningFirstRounds) {$m.Profit_Bias *= 100}
                    break
                }
            }
        }
    }

    #Apply preferred miner margin
    if (($Session.Config.PreferMinerName | Measure-Object).Count -and $Session.Config.PreferMinerMargin) {
        $PreferMinerMargin = 1 - $Session.Config.PreferMinerMargin/100
        foreach ( $Miner in $Miners ) {
            if ($Session.Config.PreferMinerName -notcontains $_.BaseName) {
                $Miner.Profit_Bias *= $PreferMinerMargin
            }
        }
    }

    # Use only the fastest miner per algo and device index
    if ($Session.Config.FastestMinerOnly) {
        #$GroupedMiners = $Miners | Sort-Object -Descending {$_.DeviceName -join ''}, {$_.BaseAlgorithm}, {if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name}}, {$_.Profit -eq $null}, {[double]$_.Profit_Bias - $_.Profit_Cost_Bias}, {$_.Profit -ne 0} | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm)$(if($_.HashRates.PSObject.Properties.Value -contains $null) {$_.Name})"}
        $GroupedMiners = $Miners | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm)$(if($_.HashRates.PSObject.Properties.Value -contains $null) {"$($_.Name)"})"}

        # Filter only the fastest miner per group
        $Miners = foreach ($Group in $GroupedMiners) {
            if ($Group.Group.Count -eq 1) {
                $Group.Group[0]
            } else {
                $SortedGroup = $Group.Group | Sort-Object -Descending {$_.Profit -eq $null}, {[double]$_.Profit_Bias - $_.Profit_Cost_Bias}, {$_.Profit -ne 0}
                $TopBaseName = $SortedGroup[0].BaseName
                $SortedGroup.Where({ $_.BaseName -eq $TopBaseName })
            }
        }
    }
 
    if (-not $Miners) { $Miners = @() }
    elseif ($Miners.Count -eq 1) {$Miners = @($Miners)}

    #Give API access to the fasted miners information
    ConvertTo-Json $Miners -Depth 10 -ErrorAction Ignore | Set-Content ".\Data\fastestminers.json"

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used
    $MinersNeedingBenchmark = $Miners.Where({ $_.HashRates.PSObject.Properties.Value -contains $null })
    $MinersNeedingBenchmarkCount = $MinersNeedingBenchmark.Count
    
    $API.MinersNeedingBenchmark = ConvertTo-Json $MinersNeedingBenchmark -Depth 2 -WarningAction Ignore -ErrorAction Ignore
    if ($Session.Debug) {
        $API.MinersNeedingBenchmark | Set-Content ".\Cache\minersneedingbenchmark.json"
    }

    Write-Log "Update active miners."
    
    #Update the active miners
    foreach ( $Miner in $Miners ) {

        $ActiveMiner = $null
        foreach ($m in $Global:ActiveMiners) {
            if (
                $m.Name -eq $Miner.Name -and
                $m.Path -eq $Miner.Path -and
                $m.Arguments -eq $Miner.Arguments -and
                $m.API -eq $Miner.API -and
                (Compare-Object $m.Algorithm ($Miner.HashRates.PSObject.Properties.Name | Select-Object) | Measure-Object).Count -eq 0
            ) {
                $ActiveMiner = $m
                break
            }
        }

        $FirstAlgoName            = "$($Miner.HashRates.PSObject.Properties.Name | Select-Object -First 1)"

        $Miner_MinSamples         = if ($Miner.MinSamples) {$Miner.MinSamples} else {3} #min. 10 seconds, 3 samples needed
        $Miner_IsLocked           = ($LockMiners -and $Session.LockMiners.Pools -and -not (Compare-Object $Session.LockMiners.Pools @($Miner.Pools.PSObject.Properties.Name | Foreach-Object {"$($Miner.Pools.$_.Name)-$($Miner.Pools.$_.Algorithm0)-$($Miner.Pools.$_.CoinSymbol)"} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>"))
        $Miner_IsFocusWalletMiner = $false
        $Miner_IsExclusiveMiner   = $false
        $Miner_Pools = $Miner.Pools.PSObject.Properties.Value
        $Miner_Pools | Foreach-Object {
            $Miner_IsFocusWalletMiner = $Miner_IsFocusWalletMiner -or ($Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet.Count -gt 0 -and (Test-Intersect $Session.Config.Pools."$($_.Name)".FocusWallet $_.Currency))
            $Miner_IsExclusiveMiner   = $Miner_IsExclusiveMiner -or $_.Exclusive
        }

        $Miner_CoinSymbol         = $Miner.Pools.$FirstAlgoName.CoinSymbol
        $Miner_PostBlockMining    = if (-not $Miner.Pools.$FirstAlgoName.SoloMining -and $Miner.Pools.$FirstAlgoName.TSL -ne $null -and $Session.Config.Pools."$($Miner.Pools.$FirstAlgoName.Name)".EnablePostBlockMining -and $Miner_CoinSymbol -and $Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining -and ($Miner.Pools.$FirstAlgoName.TSL -lt $Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining)) {$Session.Config.Coins.$Miner_CoinSymbol.PostBlockMining - $Miner.Pools.$FirstAlgoName.TSL} else {0}

        $Miner_ManualUri          = if (-not $Miner.ManualUri -and $Miner.Uri -notmatch "RainbowMiner" -and $Miner.Uri -match "^(.+?github.com/.+?/releases)") {$Matches[1]} else {$Miner.ManualUri}

        $Miner_MaxRejectedShareRatio = [Double]$(if ($Miner.MaxRejectedShareRatio -eq $null) {$Session.Config.MaxRejectedShareRatio} else {$Miner.MaxRejectedShareRatio})
        if ($Miner_MaxRejectedShareRatio -lt 0) {$Miner_MaxRejectedShareRatio = 0}
        elseif ($Miner_MaxRejectedShareRatio -gt 1) {$Miner_MaxRejectedShareRatio = 1}

        $accessNow = (Get-Date).ToUniversalTime()

        if ($ActiveMiner) {
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
            $ActiveMiner.ShowMinerWindow    = ($Session.Config.ShowMinerWindow -or $IsLinux -or $Miner.ShowMinerWindow)
            $ActiveMiner.MSIAprofile        = $Miner.MSIAprofile
            $ActiveMiner.DevFee             = $Miner.DevFee
            $ActiveMiner.OCprofile          = $Miner.OCprofile
            $ActiveMiner.EnableOCprofile    = $Session.Config.EnableOCProfiles
            $ActiveMiner.ExtendInterval     = $Miner.ExtendInterval
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
            $ActiveMiner.CoinName           = $Miner_Pools.CoinName
            $ActiveMiner.CoinSymbol         = $Miner_Pools.CoinSymbol
            $ActiveMiner.PoolPenalty        = $Miner_Pools.Penalty
            $ActiveMiner.BLK                = $Miner_Pools.BLK
            $ActiveMiner.NoCPUMining        = [bool]$Miner.NoCPUMining
            $ActiveMiner.NeedsBenchmark     = $Miner.HashRates.PSObject.Properties.Value -contains $null
            $ActiveMiner.BenchmarkOnly      = $Miner.BenchmarkOnly
            $ActiveMiner.MaxRejectedShareRatio = $Miner_MaxRejectedShareRatio
            $ActiveMiner.MiningPriority     = $Miner.MiningPriority
            $ActiveMiner.MiningAffinity     = $Miner.MiningAffinity
            $ActiveMiner.MultiProcess       = [int]$Miner.MultiProcess
            $ActiveMiner.Executables        = $Miner.Executables
            $ActiveMiner.SetLDLIBRARYPATH   = $Miner.SetLDLIBRARYPATH -eq $null -or $Miner.SetLDLIBRARYPATH
            $ActiveMiner.ShareCheck         = [int]$Miner.ShareCheck
            $ActiveMiner.AccessLast         = $accessNow

            #$Miner.HashRates.PSObject.Properties.Name | Foreach-Object {
            #    $ActiveMiner.DevFee.$_ = $Miner.DevFee.$_
            #}
            #$Miner.OCprofile.Keys | Foreach-Object {$ActiveMiner.OCprofile[$_] = $Miner.OCprofile[$_]}
        }
        else {
            Write-Log "New miner object $($Miner.BaseName): $($Miner.HashRates.PSObject.Properties.Name -join '+')"
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
                    Currency             = $Miner_Pools.Currency
                    CoinName             = $Miner_Pools.CoinName
                    CoinSymbol           = $Miner_Pools.CoinSymbol
                    Wallet               = $Miner_Pools.Wallet
                    PoolPenalty          = $Miner_Pools.Penalty
                    BLK                  = $Miner_Pools.BLK
                    Pool                 = $Miner_Pools.Name
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
                    MSIAprofile          = $Miner.MSIAprofile
                    DevFee               = $Miner.DevFee
                    OCprofile            = $Miner.OCprofile
                    EnableOCprofile      = $Session.Config.EnableOCProfiles
                    ExtendInterval       = $Miner.ExtendInterval
                    ShowMinerWindow      = ($Session.Config.ShowMinerWindow -or $IsLinux -or $Miner.ShowMinerWindow)
                    FaultTolerance       = $Miner.FaultTolerance
                    Penalty              = $Miner.Penalty
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
                    BenchmarkOnly        = $Miner.BenchmarkOnly
                    MaxRejectedShareRatio= $Miner_MaxRejectedShareRatio
                    MiningPriority       = $Miner.MiningPriority
                    MiningAffinity       = $Miner.MiningAffinity
                    MultiProcess         = [int]$Miner.MultiProcess
                    Executables          = $Miner.Executables
                    SetLDLIBRARYPATH     = $Miner.SetLDLIBRARYPATH -eq $null -or $Miner.SetLDLIBRARYPATH
                    ShareCheck           = [int]$Miner.ShareCheck
                    ExcludePoolName      = $Miner.ExcludePoolName
                    AccessLast           = $accessNow
                }
                if ($ActiveMiner) {
                    [void]$Global:ActiveMiners.Add($ActiveMiner)
                }
            } catch {
                Write-Log -Level Warn "Failed to create miner object $($Miner.BaseName): $($Miner.HashRates.PSObject.Properties.Name -join '+') $($_.Exception.Message)"
            }
            #$Miner.OCprofile.Keys | Foreach-Object {$ActiveMiner.OCprofile[$_] = $Miner.OCprofile[$_]}
        }
    }

    $ActiveMiners_DeviceNames = @(($Global:ActiveMiners | Where-Object {$_.Enabled}).DeviceName | Select-Object -Unique | Sort-Object)

    foreach ( $Miner in $Global:ActiveMiners ) {
        if ($Miner.Profit_Cost_Bias -gt 0) {
            $Miner.Profit_Bias -= $Miner.Profit_Cost_Bias
        }
    }

    $Session.Profitable = $true

    $PowerOffset_Watt = [Double]0
    $PowerOffset_Cost = [Double]0

    $MinersRunning = $false

    if ($Miners.Count -gt 0) {
        
        #Get most profitable miner combination

        $ActiveMiners_Sorted = @($Global:ActiveMiners | Where-Object {$_.Enabled -and ($_.NeedsBenchmark -or -not $_.BenchmarkOnly)} | Sort-Object -Descending {$_.IsExclusiveMiner}, {$_.IsLocked}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$_.IsFocusWalletMiner}, {$_.PostBlockMining -gt 0}, {$_.IsRunningFirstRounds -and -not $_.NeedsBenchmark}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {$_.Benchmarked}, {$_.ExtendInterval}, {$_.Algorithm[0] -eq $_.BaseAlgorithm[0]})

        $BestMiners = @()

        $ActiveMiners_Sorted | Select-Object DeviceName -Unique | ForEach-Object {
            $Miner_GPU = $_
            if ($BestMiner = $ActiveMiners_Sorted | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Select-Object -First 1) {
                $BestMiners += $BestMiner[0]
            }
        }

        #If post block mining: check for minimum profit
        if ($Miners_PBM = $BestMiners | Where-Object {$_.PostBlockMining -gt 0 -and -not $_.IsExclusiveMiner -and -not $_.IsLocked -and -not $_.IsFocusWalletMiner -and -not $_.NeedsBenchmark -and -not $_.IsRunningFirstRounds -and $Session.Config.Coins."$($_.CoinSymbol)".MinProfitPercent -gt 0}) {
            $Miners_PBM_Remove = @()
            $Miners_PBM | Foreach-Object {
                $Miner_PBM = $_
                if ($BestMiner = $ActiveMiners_Sorted | Where-Object {$_.PostBlockMining -eq 0 -and (Compare-Object $Miner_PBM.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Select-Object -First 1) {
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
        }
        

        $NoCPUMining = $Session.Config.EnableCheckMiningConflict -and $MinersNeedingBenchmarkCount -eq 0 -and ($BestMiners | Where-Object DeviceModel -eq "CPU" | Measure-Object).Count -and ($BestMiners | Where-Object NoCPUMining -eq $true | Measure-Object).Count
        if ($NoCPUMining) {
            $BestMiners2 = @()
            $ActiveMiners_Sorted | Select-Object DeviceName -Unique | ForEach-Object {
                $Miner_GPU = $_
                if ($BestMiner = $ActiveMiners_Sorted | Where-Object {-not $_.NoCPUMining -and (Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Select-Object -First 1) {
                    $BestMiners2 += $BestMiner[0]
                }
            }
        }

        #Remove no longer profitable miners
        $Check_Profitability = $false
        if ($Session.Config.UsePowerPrice -and $MinersNeedingBenchmarkCount -eq 0) {
            if ($Session.Config.CheckProfitability) {
                $BestMiners = @($BestMiners | Where-Object {$_.Profit -gt $Session.Config.ProfitabilityLevel -or $_.IsExclusiveMiner -or $_.IsLocked})
                if ($BestMiners2) {$BestMiners2 = @($BestMiners2 | Where {$_.Profit -gt $Session.Config.ProfitabilityLevel -or $_.IsExclusiveMiner -or $_.IsLocked})}
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
                    $BestMiners | Where-Object {"$($_.Name -replace '-.+$')$($_.Vendor)$($_.Pool -join '')$($_.Algorithm -join '')$($_.Currency)$($_.CoinSymbol)" -eq $Combo_Name -and (Compare-Object $_.DeviceName $Combo_Devices | Measure-Object).Count -eq 0} | Sort-Object Profit_Bias -Descending | Select-Object -First 1
                }
                if ($BestMiners_Multi -and (($_.Group.Profit_Bias | Measure-Object -Sum).Sum*$Session.Config.MinComboOverSingleRatio -lt $BestMiners_Multi.Profit_Bias)) {$BestMiners_Multi} else {$_.Group}
            }
        }

        if ($NewPools.Count -gt 0 -and $Check_Profitability) {
            $PowerOffset_Watt = $Session.Config.PowerOffset
            $PowerOffset_Cost = [Double]($PowerOffset_Watt*24/1000 * $Session.CurrentPowerPriceBTC) + $Session.FixedCostPerDayBTC
            if ((($BestMiners_Combo.Profit | Measure-Object -Sum).Sum - $PowerOffset_Cost) -le $Session.Config.ProfitabilityLevel) {
                if ($Session.Config.CheckProfitability -and ($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner -or $_.IsLocked} | Measure-Object).Count -eq 0) {$Session.Profitable = $false}
                if (-not $Session.Profitable -or -not $Session.Config.CheckProfitability) {
                    Write-Log -Level Warn "No more miners are profitable. $(if ($Session.Config.CheckProfitability) {" Waiting for profitability."})"
                }
            }
        }

        $ExclusiveBestMiners_Count = ($BestMiners_Combo | Where-Object {$_.IsExclusiveMiner} | Measure-Object).Count

        if ($Global:PauseMiners.Test([PauseStatus]::ByScheduler) -and ($ExclusiveBestMiners_Count -or $Session.IsExclusiveRun)) {$Global:PauseMiners.Reset([PauseStatus]::ByScheduler)}

        if ((-not $Global:PauseMiners.Test() -or $ExclusiveBestMiners_Count) -and -not $Session.AutoUpdate -and $Session.Profitable) {
            $BestMiners_Combo | Where-Object {-not $Global:PauseMiners.Test() -or $_.IsExclusiveMiner} | ForEach-Object {$_.Best = $true; $MinersRunning = $true}
        }
    }

    if ($Session.RoundCounter -eq 0) {Write-Host "Starting mining operation .."}

    #Stop failed miners
    foreach ($Miner in $Global:ActiveMiners) {
        if ($Miner.GetStatus() -eq [MinerStatus]::RunningFailed) {
            Write-Log "Stopping crashed miner ($($Miner.Name)) "
            $Miner.CrashCount++
            Write-ActivityLog $Miner -Crashed 1
            $Miner.SetStatus([MinerStatus]::Idle)
        }
    }

    # Stop miners in the active list depending on profitability
    foreach ($Miner in $Global:ActiveMiners) {
        if ((-not $Miner.Best -or $Session.RestartMiners -or $Miner.Restart) -and 
            $Miner.Activated -gt 0 -and 
            $Miner.Status -eq [MinerStatus]::Running) {

            Write-Log "Stopping miner $($Miner.Name) on pool $($Miner.Pool -join '/')."
            $Miner.SetStatus([MinerStatus]::Idle)
            $Miner.Stopped = $true
            $Miner.Restart = $false

            # Remove watchdog timer if enabled
            if ($Session.Config.Watchdog -and $Global:WatchdogTimers.Count -gt 0) {
                $Miner_Name = $Miner.Name
                $Miner_Index = 0

                foreach ($Miner_Algorithm in $Miner.Algorithm) {
                    $Miner_Pool = $Miner.Pool[$Miner_Index]

                    # Find the corresponding WatchdogTimer
                    $WatchdogTimer = $Global:WatchdogTimers | Where-Object {
                        $_.MinerName -eq $Miner_Name -and
                        $_.PoolName -eq $Miner_Pool -and
                        $_.Algorithm -eq $Miner_Algorithm
                    }

                    if ($WatchdogTimer) {
                        if (($WatchdogTimer.Kicked -lt $WDIntervalTime) -and -not $Session.RestartMiners) {
                            Write-ActivityLog $Miner -Crashed 2
                            $Miner.SetStatus([MinerStatus]::Failed)
                            Write-Log -Level Warn "Miner $Miner_Name mining $Miner_Algorithm on pool $Miner_Pool temporarily disabled."
                        } else {
                            $Global:WatchdogTimers.RemoveAll({ param($w) 
                                $w.MinerName -eq $Miner_Name -and 
                                $w.PoolName -eq $Miner_Pool -and 
                                $w.Algorithm -eq $Miner_Algorithm
                            }) > $null
                        }
                    }
                    $Miner_Index++
                }
            }
        }
    }

    #Kill maroding miners
    $Running_ProcessIds = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($Miner in $Global:ActiveMiners) {
        foreach ($ProcessId in $Miner.GetProcessIds()) {
            if ($ProcessId) { [void]$Running_ProcessIds.Add($ProcessId) }
        }
    }

    $Running_MinerPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Miner in $Global:ActiveMiners) {
        if ($Miner.Path) {
            $MinerPath = Split-Path -Leaf $Miner.Path
            if ($MinerPath) { [void]$Running_MinerPaths.Add($MinerPath) }
        }
        if ($Miner.Executables) {
            foreach ($Exe in [System.Collections.Generic.List[string]]$Miner.Executables) { 
                if ($Exe) { [void]$Running_MinerPaths.Add($Exe) }
            }
        }
    }

    if ($IsWindows) {
        Get-CIMInstance CIM_Process | Where-Object {
            $_.ExecutablePath -and
            $_.ExecutablePath -like "$(Get-Location)\Bin\*" -and
            -not $Running_ProcessIds.Contains($_.ProcessId) -and
            $Running_MinerPaths.Contains($_.ProcessName)
        } | ForEach-Object {
            Write-Log -Level Warn "Stopping Process: $($_.ProcessName) with Id $($_.ProcessId)"
            Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore
        }
    }
    elseif ($IsLinux) {
        Get-Process | Where-Object {
            $_.Path -and
            $_.Path -like "$(Get-Location)/Bin/*" -and
            -not (Test-Intersect $Running_ProcessIds @($_.Id, $_.Parent.Id)) -and
            $Running_MinerPaths.Contains($_.ProcessName)
        } | ForEach-Object {
            Write-Log -Level Warn "Stopping Process: $($_.ProcessName) with Id $($_.Id)"
            if (Test-OCDaemon) {
                Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null
            } else {
                Stop-Process -Id $_.Id -Force -ErrorAction Ignore
            }
        }
    }


    # Kill marauding EthPills
    if ($Session.Config.EthPillEnable -ne "disable") {
        $Running_ProcessIds = [System.Collections.Generic.List[int]]::new()

        foreach ($Miner in $Global:ActiveMiners) {
            if ($Miner.EthPillJob) {
                [void]$Running_ProcessIds.Add($Miner.EthPillJob.ProcessId)
            }
        }

        if ($IsWindows) {
            Get-CIMInstance CIM_Process | Where-Object {
                $_.ProcessName -eq "OhGodAnETHlargementPill-r2.exe" -and
                -not $Running_ProcessIds.Contains($_.ProcessId)
            } | ForEach-Object {
                Write-Log -Level Warn "Stopping Process: $($_.ProcessName) with Id $($_.ProcessId)"
                Stop-Process -Id $_.ProcessId -Force -ErrorAction Ignore
            }
        }
        elseif ($IsLinux) {
            Get-Process | Where-Object {
                $_.ProcessName -eq "OhGodAnETHlargementPill-r2" -and
                -not (Test-Intersect $Running_ProcessIds @($_.Id, $_.Parent.Id))
            } | ForEach-Object {
                Write-Log -Level Warn "Stopping Process: $($_.ProcessName) with Id $($_.Id)"
                if (Test-OCDaemon) {
                    Invoke-OCDaemon -Cmd "kill $($_.Id)" -Quiet > $null
                } else {
                    Stop-Process -Id $_.Id -Force -ErrorAction Ignore
                }
            }
        }
    }

    if ($Global:Downloader.HasMoreData) {$Global:Downloader | Receive-Job | Out-Host}
    if ($Global:DownloaderPrq.HasMoreData) {$Global:DownloaderPrq | Receive-Job | Out-Host}
    if ($Session.Config.Delay -gt 0) {Start-Sleep $Session.Config.Delay} #Wait to prevent BSOD

    # Process Active Miners that should start
    foreach ($Miner in $Global:ActiveMiners) {
        if ($Miner.Best -eq $true -and $Miner.Status -ne [MinerStatus]::Running) {

            if ($Miner.DeviceModel -ne "CPU") {
                if ($Session.Config.EnableResetVega) { Reset-Vega $Miner.DeviceName }

                # Set MSI Afterburner profile
                if ($MSIAenabled) {
                    $MSIAplannedprofile = [System.Collections.Generic.HashSet[int]]::new()

                    foreach ($Miner in $Global:ActiveMiners) {
                        if ($Miner.Best -eq $true -and $Miner.MSIAprofile -ne $null -and $Miner.MSIAprofile -gt 0) {
                            [void]$MSIAplannedprofile.Add($Miner.MSIAprofile)
                        }
                    }

                    $MSIAplannedprofile = if ($MSIAplannedprofile.Count) { $MSIAplannedprofile[0] } else { $Session.Config.MSIAprofile }

                    Start-Process -FilePath "$($Session.Config.MSIApath)" -ArgumentList "-Profile$($MSIAplannedprofile)" -Verb RunAs

                    if ($MSIAplannedprofile -ne $Session.MSIAcurrentprofile) {
                        Write-Log "New MSI Afterburner profile set: $($MSIAplannedprofile)"
                        $Session.MSIAcurrentprofile = $MSIAplannedprofile
                        Start-Sleep 1
                    }
                } elseif ($Session.Config.EnableOCprofiles) {
                    $Miner.SetOCprofile($Session.Config, 500)
                    if ($IsLinux) { Invoke-OCDaemon -Miner $Miner -Quiet > $null }
                }

                $Miner.SetStaticPort($Session.Config.StaticGPUMinerPort)
            } else {
                $Miner.SetStaticPort($Session.Config.StaticCPUMinerPort)
            }

            # Logging
            if ($Miner.Speed -contains $null) {
                Write-Log "Benchmarking miner ($($Miner.Name)): '$($Miner.Path) $($Miner.Arguments)' (Extend Interval $($Miner.ExtendInterval))"
            } else {
                Write-Log "Starting miner ($($Miner.Name)): '$($Miner.Path) $($Miner.Arguments)'"
            }

            $Session.DecayStart = $Session.Timer

            $Miner.SetPriorities(
                $(if ($Miner.MiningPriority -ne $null) { $Miner.MiningPriority } else { $Session.Config.MiningPriorityCPU }),
                $(if ($Miner.MiningPriority -ne $null) { $Miner.MiningPriority } else { $Session.Config.MiningPriorityGPU }),
                $(if ($Miner.MiningAffinity -ne $null) { $Miner.MiningAffinity } elseif ($Miner.DeviceModel -ne "CPU") { $Session.Config.GPUMiningAffinity })
            )

            $Session.DecayStart = (Get-Date).ToUniversalTime()

            $Miner.SetStatus([MinerStatus]::Running)

            # Add watchdog timer
            if ($Session.Config.Watchdog -and $Miner.Profit -ne $null) {
                $Miner_Name = $Miner.Name
                $Miner_DeviceModel = $Miner.DeviceModel
                $TimersToAdd = [System.Collections.Generic.List[PSCustomObject]]::new()

                foreach ($Miner_Algorithm in $Miner.Algorithm) {
                    $Miner_Pool = $Pools.$Miner_Algorithm.Name

                    if (Test-Intersect @($Miner_Name,$Miner_Algorithm,$Miner_Pool) $Session.Config.ExcludeFromWatchdog) {
                        continue
                    }

                    # Check if the Watchdog Timer already exists
                    $WatchdogTimer = $null
                    foreach ($wdTimer in $Global:WatchdogTimers) {
                        if ($wdTimer.MinerName -eq $Miner_Name -and 
                            $wdTimer.PoolName -eq $Miner_Pool -and 
                            $wdTimer.Algorithm -eq $Miner_Algorithm) {

                            $WatchdogTimer = $wdTimer
                            break
                        }
                    }

                    if (-not $WatchdogTimer) {
                        [void]$TimersToAdd.Add([PSCustomObject]@{
                            MinerName   = $Miner_Name
                            DeviceModel = $Miner_DeviceModel
                            PoolName    = $Miner_Pool
                            Algorithm   = $Miner_Algorithm
                            Kicked      = $Session.Timer
                            Active      = $Session.Timer
                        })
                    } elseif ($WatchdogTimer.Kicked -le $WDResetTime) {
                        # Update existing Watchdog Timer
                        $WatchdogTimer.Kicked = $Session.Timer
                        $WatchdogTimer.Active = $Session.Timer
                    }
                }

                # Add all new Watchdog timers at once
                if ($TimersToAdd.Count -gt 0) {
                    $Global:WatchdogTimers.AddRange($TimersToAdd)
                }
                $TimersToAdd = $null
            }
        }
    }

    $Pools = $null
    Remove-Variable -Name Pools -ErrorAction Ignore

    $IsExclusiveRun = $Session.IsExclusiveRun

    $NextIsExclusiveRun = $false
    foreach ($Miner in $Global:ActiveMiners) {
        if ($Miner.IsExclusiveMiner -and $Miner.Status -eq [MinerStatus]::Running) {
            $NextIsExclusiveRun = $true
            break
        }
    }
    $Session.IsExclusiveRun = $NextIsExclusiveRun

    #Move donation run into the future, if benchmarks are ongoing
    if ((-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun -and $MinersNeedingBenchmarkCount -gt 0) -or $Session.IsExclusiveRun) {
        $ShiftDonationRun = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)
        if (-not $Session.LastDonated -or $Session.LastDonated -lt $ShiftDonationRun) {$Session.LastDonated = Set-LastDrun $ShiftDonationRun}
    }

    #Update API miner information
    $API.WatchdogTimers = [System.Collections.Generic.List[PSCustomObject]]$Global:WatchdogTimers
    $API.CrashCounter   = [System.Collections.Generic.List[PSCustomObject]]$Global:CrashCounter

    $API.ActiveMiners   = ConvertTo-Json @($Global:ActiveMiners | Where-Object {$_.Status -eq [MinerStatus]::Running -or $_.Profit -or $_.IsFocusWalletMiner} | Foreach-Object {$_ | Select-Object -Property * -ExcludeProperty *Job}) -Depth 10 -ErrorAction Ignore
    $API.RunningMiners  = ConvertTo-Json @($Global:ActiveMiners | Where-Object {$_.Status -eq [MinerStatus]::Running} | Foreach-Object {$_ | Select-Object -Property * -ExcludeProperty *Job}) -Depth 10 -ErrorAction Ignore
    $API.FailedMiners   = ConvertTo-Json @($Global:ActiveMiners | Where-Object {$_.Status -eq [MinerStatus]::Failed} | Foreach-Object {$_ | Select-Object -Property * -ExcludeProperty *Job}) -Depth 10 -ErrorAction Ignore

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
    } elseif ($NewPools.Count -eq 0) {
        Write-Host " "
        Write-Log -Level Warn "No pools available: $(if ($AllPools_BeforeWD_Count -gt 0 ) {"disabled by Watchdog"} else {"check your configuration"})"
        Write-Host " "
    } elseif ($Miners.Count -eq 0) {
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

        $Miner_Table = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($col in $Session.Config.UIProfitColumns) {
            Switch ($col) {
                "Miner"     {[void]$Miner_Table.Add(@{Label = "Miner"; Expression = {$_.Name -replace '\-.*$'}})}
                "Fee"       {[void]$Miner_Table.Add(@{Label = "Fee"; Expression = {$m = $_;($m.HashRates.PSObject.Properties.Name | ForEach-Object {if ($m.DevFee.$_) {'{0:p2}' -f ($m.DevFee.$_/100) -replace ",*0+\s%"," %"}else {"-"}}) -join ','}; Align = 'right'})}
                "Algorithm" {[void]$Miner_Table.Add(@{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.HashRates.PSObject.Properties.Name}})}
                "Speed"     {[void]$Miner_Table.Add(@{Label = "Speed"; Expression = {$_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"} elseif ($Session.Benchmarking) {"Benchmarking"} else {"Waiting"}}}; Align = 'right'})}
                "Diff"      {[void]$Miner_Table.Add(@{Label = "Diff"; Expression = {$m = $_;($m.HashRates.PSObject.Properties.Name | ForEach-Object {if ($m.Difficulties.$_) {($m.Difficulties.$_ | ConvertTo-Float) -replace " "} else {"-"}}) -join ','}; Align = 'right'})}
                "Power"     {[void]$Miner_Table.Add(@{Label = "Power$(if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}; Align = 'right'})}
                "Profit"    {foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {[void]$Miner_Table.Add(@{Label = "$Miner_Currency/Day"; Expression = [scriptblock]::Create("if (`$_.Profit -and `"$($Global:Rates.$Miner_Currency)`") {ConvertTo-LocalCurrency `$(`$_.Profit) $($Global:Rates.$Miner_Currency) -Offset 2} else {`"Unknown`"}"); Align = "right"})}}
                "TTF"       {[void]$Miner_Table.Add(@{Label = "TTF"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.BLK) {86400/$_.BLK | ConvertTo-TTF} else {"-"}}}; Align = 'right'})}
                "Accuracy"  {[void]$Miner_Table.Add(@{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}}; Align = 'right'})}
                "Pool"      {[void]$Miner_Table.Add(@{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.CoinName -match "^\d+") {"-$($_.CoinName)"} elseif ($_.CoinSymbol) {"-$($_.CoinSymbol)"})"}}})}
                "PoolFee"   {[void]$Miner_Table.Add(@{Label = "PoolFee"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.PoolFee) {'{0:p2}' -f ($_.PoolFee/100) -replace ",*0+\s%"," %"}else {"-"}}}; Align = 'right'})}
                "Wallet"    {[void]$Miner_Table.Add(@{Label = "Wallet"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.Wallet) {if ($_.Wallet.Length -le 8) {"$($_.Wallet)"} else {"$($_.Wallet.Substring(0,3))..$($_.Wallet.Substring($_.Wallet.Length-3,3))"}} else {"-"}}}})}
            }
        }

        $Miners_Count = 0
        $Miners | Where-Object {$_.DeviceModel -eq $Miner_DeviceModel -and ($_.HashRates.PSObject.Properties.Value -gt 0 -or $_.Profit -eq $null)} | Sort-Object @{Expression = {if ($Session.Benchmarking -and $Session.Config.UIsorting -ne "profit") {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($Session.Benchmarking -or $Session.Config.UIsorting -eq "profit") {$_.Profit}}; Descending = $true}, @{Expression = {if ($Session.Benchmarking -and $Session.Config.UIsorting -eq "profit") {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if ($Session.IsExclusiveRun -or $Session.IsDonationRun -or $Session.IsServerDonationRun -or $MinersNeedingBenchmarkCount -lt 1) {[double]$_.Profit_Bias}}; Descending = $true} | Where-Object {$Miners_Count -lt [Math]::Min($LimitMiners,5) -or ($Session.Config.UIstyle -ne "full" -and $_.HashRates.PSObject.Properties.Value -gt 0) -or ($_.Profit+$(if ($Session.Config.UsePowerPrice -and $_.Profit_Cost -ne $null -and $_.Profit_Cost -gt 0) {$_.Profit_Cost})) -ge $Miner_ProfitMin -or $_.Profit -eq $null;$Miners_Count++} | Select-Object -First $($LimitMiners) | Format-Table $Miner_Table | Out-Host
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
            if ($Session.Config.UIFullBenchmarkList -or $MinersNeedingBenchmarkWithEI -gt 0) {
                $BenchmarkMinutes = [Math]::Ceiling($Session.Config.BenchmarkInterval/60)
                Write-Host " "
                Write-Host "Please be patient!" -BackgroundColor Yellow -ForegroundColor Black
                if ($MinersNeedingBenchmarkWithEI -gt 0) {
                    Write-Host "RainbowMiner will benchmark $($MinersNeedingBenchmarkWithEI) out of $($MinersNeedingBenchmarkCount) miner$(if ($MinersNeedingBenchmarkCount -gt 1){'s'}) with extended intervals!" -ForegroundColor Yellow
                    Write-Host "These algorithms need a longer time to reach an accurate average hashrate." -ForegroundColor Yellow
                    Write-Host "After that, benchmarking will be much faster ($($BenchmarkMinutes)-$($BenchmarkMinutes*2) minutes per miner)." -ForegroundColor Yellow
                    Write-Host "If you do not want that accuracy, set DisableExtendInterval to 1 in your config.txt." -ForegroundColor Yellow
                }
                $OldForegroundColor = [console]::ForegroundColor
                [console]::ForegroundColor = "Yellow"
                $MinersNeedingBenchmark | Where-Object {$Session.Config.UIFullBenchmarkList -or ($_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null)} | Group-Object BaseName, BaseAlgorithm, DeviceModel, ExtendInterval | Sort-Object -Property @{Expression = {if ($_.Values[3]) {$_.Values[3]} else {1}}; Descending = $True},@{Expression = {$_.Name}; Descending = $False} | Format-Table (
                    @{Label = "Miner"; Expression = {$_.Values[0]}},
                    @{Label = "Version"; Expression = {$_.Group[0].Version}},
                    @{Label = "Algorithms"; Expression = {$_.Values[1]}},
                    @{Label = "Device"; Expression = {$_.Values[2]}},
                    @{Label = "OC-Profile"; Expression = {if ($_.Group[0].DeviceModel -ne "CPU") {@(foreach($p in @($_.Group[0].DeviceModel -split '-')) {if ($_.Group[0].OCProfile[$p] -ne '') {$_.Group[0].OCProfile[$p]} else {"-"}}) -join "/"} else {"-"}}},
                    @{Label = "Aprox. Time"; Expression = {if ($_.Values[3]) {"$($BenchmarkMinutes*$_.Values[3])-$($BenchmarkMinutes*$_.Values[3]*2) minutes"} else {"$($BenchmarkMinutes)-$($BenchmarkMinutes*2) minutes"}}}
                ) | Out-Host

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
    $FilteredMiners = foreach ($Miner in $Global:ActiveMiners) {
        if (
            $Miner.Activated -gt 0 -and
            (
                $Miner.Status -eq [MinerStatus]::Running -or
                (
                    -not $Miner.Donator -and
                    ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) -and
                    ($Miner.GetActiveLast() -gt (Get-Date).AddSeconds(-5 * $Session.Config.Interval))
                )
            )
        ) {
            $Miner
        }
    }

    $FilteredMiners | Sort-Object -Property @{Expression = { $_.Status }; Descending = $False }, @{Expression = { $_.GetActiveLast() }; Descending = $True } | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = { $_.Status }} -Wrap (
        @{Label = "Last Speed"; Expression = { $_.Speed_Live | ForEach-Object { "$($_ | ConvertTo-Hash)/s" } }; Align = 'right' }, 
        @{Label = "Active"; Expression = { "{0:dd}d/{0:hh}h/{0:mm}m" -f $_.GetActiveTime() } }, 
        @{Label = "Started"; Expression = { Switch ($_.Activated) { 0 { "Never"; Break } 1 { "Once"; Break } Default { "$_ Times" } } } },      
        @{Label = "Miner"; Expression = {"$($_.Name -replace '\-.*$')$(if ($_.IsFocusWalletMiner -or $_.IsExclusiveMiner) {"(!)"} elseif ($_.PostBlockMining -gt 0) {"($($_.PostBlockMining)s)"} elseif ($Session.Config.MinimumMiningIntervals -gt 1 -and $MinersNeedingBenchmarkCount -eq 0 -and ($_.IsRunningFirstRounds -or ($_.Rounds -eq 0 -and $_.Status -eq [MinerStatus]::Running))) {"($($_.Rounds+1)/$($Session.Config.MinimumMiningIntervals))"})"}},
        @{Label = "Algorithm"; Expression = { Get-MappedAlgorithm $_.BaseAlgorithm }},
        @{Label = "Coin"; Expression = { for ($i = 0; $i -lt $_.CoinSymbol.Count; $i++) { if ($_.CoinName[$i] -match "^\d+") { $_.CoinName[$i] } elseif ($_.CoinSymbol[$i]) { $_.CoinSymbol[$i] } else { "-" } } }},
        @{Label = "Device"; Expression = { @(Get-DeviceModelName $Global:DeviceCache.Devices -Name @($_.DeviceName) -Short) -join ',' }},
        @{Label = "Pool"; Expression = { $_.Pool }},
        @{Label = "Power$(if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)){"*"})"; Expression = { "{0:d}W" -f [int]$_.PowerDraw }},
        @{Label = "Command"; Expression = { "$($_.Path.TrimStart((Convert-Path ".\"))) $($_.GetArguments())" }}
    ) | Out-Host

    $FilteredMiners = $null

    if ($Session.Config.UIstyle -eq "full" -or $Session.Benchmarking) {
        $FilteredWatchdogTimers = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($wdTimer in $Global:WatchdogTimers) {
            if ($wdTimer.Kicked -gt $WDResetTime) {
                [void]$FilteredWatchdogTimers.Add($wdTimer)
            }
        }

        #Display watchdog timers
        $FilteredWatchdogTimers | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName -replace '\-.*$'}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Global:DeviceCache.Devices -Name @($_.DeviceName) -Short) -join ','}}, 
            @{Label = "Pool"; Expression = {$_.PoolName}}, 
            @{Label = "Algorithm"; Expression = {Get-MappedAlgorithm $_.Algorithm}}, 
            @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Session.Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
        ) | Out-Host

        $FilteredWatchdogTimers = $null
    }

    if ($Session.Config.UsePowerPrice -and ($Session.Config.PowerOffset -gt 0 -or $Session.Config.PowerOffsetPercent -gt 0)) {Write-Host "* net power consumption. A base power offset of $(if ($Session.Config.PowerOffsetPercent -gt 0) {"{0:f1}%" -f $Session.Config.PowerOffsetPercent})$(if ($Session.Config.PowerOffset -gt 0) {if ($Session.Config.PowerOffsetPercent -gt 0) {" +"};"{0:d}W" -f [int]$Session.Config.PowerOffset}) is being added to calculate the final profit$(if ($PowerOffset_Watt -gt 0) { " (currently {0:d}W)" -f [int]$PowerOffset_Watt})."; Write-Host " "}

    #Display pool balances, formatting it to show all the user specified currencies
    if ($Session.Config.ShowPoolBalances -and $BalancesData -and $BalancesData.Count -gt 1) {
        $ColumnMark = if ($Session.EnableColors) {"$([char]27)[93m{value}$([char]27)[0m"} else {"{value}"}
        $NextBalances = $Session.Config.BalanceUpdateMinutes-[int]((Get-Date).ToUniversalTime()-$Session.Updatetracker.Balances).TotalMinutes
        $NextBalances = if ($NextBalances -gt 0){"in $($NextBalances) minutes"}else{"now"}
        Write-Host "Pool Balances as of $([System.Timezone]::CurrentTimeZone.ToLocalTime($Session.Updatetracker.Balances)) (next update $($NextBalances)): "        
        $ColumnFormat = [System.Collections.Generic.List[hashtable]]::new()
        [void]$ColumnFormat.Add(@{Name = "Name"; Expression = {if ($_.Name -match "^\*") {$ColumnMark -replace "{value}","$($_.Name)"} else {$_.Name}}})
        if (($BalancesData.Currency | Select-Object -Unique | Measure-Object).Count -gt 1) {
            [void]$ColumnFormat.Add(@{Name = "Sym"; Expression = {if ($_.BaseName -ne "Wallet" -and $_.Currency -and (-not $Session.Config.Pools."$($_.Name)".AECurrency -or $Session.Config.Pools."$($_.Name)".AECurrency -eq $_.Currency)) {$ColumnMark -replace "{value}","$($_.Currency)"} else {$_.Currency}}})
            [void]$ColumnFormat.Add(@{Name = "Balance"; Expression = {$_."Balance ($($_.Currency))"}})
            [void]$ColumnFormat.Add(@{Name = "Pending"; Expression = {if ($_.Pending) {$_."Pending ($($_.Currency))"} else {"-"}}})
        }
        $BalancesData | Foreach-Object {$_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name} | Where-Object {$_ -like "Value in *"} | Sort-Object -Unique | Foreach-Object {$Value = $_;[void]$ColumnFormat.Add(@{Name = "$($Value -replace "Value in\s+")"; Expression = [ScriptBlock]::Create("`$(if (`$_.Name -match `"^\*`") {`$ColumnMark -replace `"{value}`",`$_.`"$Value`"} else {`$_.`"$Value`"})"); Align = "right"})}
        $BalancesData | Format-Table -Wrap -Property $ColumnFormat | Out-Host

        $ColumnFormat = $null
        $BalancesData = $null
        Remove-Variable -Name ColumnFormat, BalancesData -ErrorAction Ignore
    }

    #Get worker specific profits without cost
    $CurrentProfitTotal = 0
    $CurrentProfitWithoutCostTotal = 0
    $CurrentPowerDrawCPU = 0
    $CurrentPowerDrawGPU = 0

    foreach ($Miner in $Global:ActiveMiners) {
        if ($Miner.Status -eq [MinerStatus]::Running) {
            $CurrentProfitTotal += $Miner.Profit
            if ($Session.Config.UsePowerPrice) {
                $CurrentProfitWithoutCostTotal += $Miner.Profit_Cost
            }
            if ($Miner.DeviceModel -eq "CPU") {
                $CurrentPowerDrawCPU += $Miner.PowerDraw
            } else {
                $CurrentPowerDrawGPU += $Miner.PowerDraw
            } 
        }
    }

    if ($Session.Config.UsePowerPrice) {
        $CurrentProfitTotal -= $PowerOffset_Cost
    }

    #Display exchange rates
    $StatusLine = [System.Collections.Generic.List[string]]::new()
    foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Currency_Out = $Miner_Currency
            $CurrentProfitTotal_Out = $CurrentProfitTotal
            $CurrentProfitWithoutCostTotal_Out = $CurrentProfitWithoutCostTotal
            $CurrentProfit_Offset = 2
            if ($Miner_Currency -eq "BTC" -and $CurrentProfitWithoutCostTotal -ne 0) {
                switch ([Math]::Truncate([Math]::Log([Math]::Abs($CurrentProfitWithoutCostTotal), 1000))) {
                    -1 {$Miner_Currency_Out = "mBTC";$CurrentProfitTotal_Out*=1e3;$CurrentProfitWithoutCostTotal_Out*=1e3;$CurrentProfit_Offset = 5;Break}
                    -2 {$Miner_Currency_Out = "µBTC";$CurrentProfitTotal_Out*=1e6;$CurrentProfitWithoutCostTotal_Out*=1e6;$CurrentProfit_Offset = 8;Break}
                    -3 {$Miner_Currency_Out = "sat"; $CurrentProfitTotal_Out*=1e8;$CurrentProfitWithoutCostTotal_Out*=1e8;$CurrentProfit_Offset = 10;Break}
                }
            }
            if ($Global:Rates.$Miner_Currency) {[void]$StatusLine.Add("$(ConvertTo-LocalCurrency $CurrentProfitTotal_Out $($Global:Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)$(if ($Session.Config.UsePowerPrice) {"/$(ConvertTo-LocalCurrency $CurrentProfitWithoutCostTotal_Out $($Global:Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)"}) $Miner_Currency_Out/Day")}
    }
    if ($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $Global:Rates.$_}) {[void]$StatusLine.Add("1 BTC = $(($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $Global:Rates.$_} | Sort-Object | ForEach-Object { "$($_) $($Global:Rates.$_)"})  -join ' = ')")}

    $API.CurrentProfit = $CurrentProfitTotal
    $API.CurrentPower = [PSCustomObject]@{
        CPU = [Math]::Round($CurrentPowerDrawCPU,2)
        GPU = [Math]::Round($CurrentPowerDrawGPU,2)
        Offset = 0
    }
    $API.CurrentPower.Offset = [Math]::Round(($API.CurrentPower.CPU + $API.CurrentPower.GPU) * ($Session.Config.PowerOffsetPercent/100) + $Session.Config.PowerOffset,2)

    if ($Session.Config.UsePowerPrice) {[void]$StatusLine.Add("E-Price = $($Session.Config.PowerPriceCurrency) $([Math]::Round($Session.CurrentPowerPrice,3))")}

    Write-Host " [$(Get-Date)] Profit = $($StatusLine -join ' | ') " -BackgroundColor White -ForegroundColor Black
    Write-Host " "

    $StatusLine = $null
    Remove-Variable -Name StatusLine -ErrorAction Ignore

    #Check if server is up
    if ($UserConfig.RunMode -eq "Client" -and $UserConfig.ServerName -and $UserConfig.ServerPort) {
        $ServerConnected = Test-TcpServer $UserConfig.ServerName -Port $UserConfig.ServerPort -Timeout 2
        if ($ServerConnected) {            
            Write-Host "[Client-Mode] Connected to $($UserConfig.ServerName):$($UserConfig.ServerPort)" -ForegroundColor Green
        } else {
            Write-Host "[Client-Mode] Server $($UserConfig.ServerName):$($UserConfig.ServerPort) does not respond." -ForegroundColor Red
        }
        Write-Host " "
        Write-Log "Client-Mode: $(if ($ServerConnected) {"Connected"} else {"Not connected"}) to $($UserConfig.ServerName):$($UserConfig.ServerPort)"
    }
    if ($UserConfig.RunMode -eq "Server") {
        if ($API.RemoteAPI) {
            Write-Host "[Server-Mode] Name=$($Session.MachineName) IP=$($Session.MyIP) Port=$($UserConfig.APIport) " -ForegroundColor Green
            if ($APIClients) {
                Write-Host " "
                Write-Host "Clients: " -NoNewLine
                $lookup = @{}
                $dropsome = $false
                foreach ($obj in $APIClients) {
                    $key = "$($obj.workername)|$($obj.machinename)" 
                    if (-not $lookup.ContainsKey($key) -or $obj.timestamp -gt $lookup[$key].timestamp) {
                        $lookup[$key] = $obj
                        $lastseen = [Math]::Round((Get-UnixTimestamp)-$obj.timestamp,0)
                        Write-Host "[$($obj.workername)@$(if ($obj.machinename) {$obj.machinename} else {$obj.machineip})]" -ForegroundColor "$(if ($lastseen -gt 300) {"Red"} else {"Green"}) " -NoNewline
                    } else {
                        $dropsome = $true
                    }
                }
                if ($dropsome) {
                    $APIClients.Clear()
                    $APIClients.AddRange($lookup.Values)
                }
                $lookup = $null
                Write-Host " "
            }
        } else {
            Write-Host "[Server-Mode] Server has not been started. Run RainbowMiner with admin privileges." -ForegroundColor Red
        }
        Write-Host " "
        Write-Log "Server-Mode: $(if ($API.RemoteAPI) {"Name=$($Session.MachineName) IP=$($Session.MyIP) Port=$($UserConfig.APIport)"} else {"not started!"})"
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
    if ($ServerPools) { $ServerPools.Clear() }
    $Miner = $Miner_Table = $Miners = $Pool = $UserPool = $Pool_Parameters = $AvailablePools = $Result = $NewPools = $ServerPools = $null
    Remove-Variable -Name Miner, Miner_Table, Miners, Pool, UserPool, Pool_Parameters, AvailablePools, Result, NewPools, ServerPools -ErrorAction Ignore

    if ($Global:Error.Count) {
        $logDate = Get-Date -Format "yyyy-MM-dd"
        foreach ($err in $Global:Error) {
            if ($err.Exception.Message) {
                Write-ToFile -FilePath "Logs\errors_$logDate.main.txt" -Message "$($err.Exception.Message)" -Append -Timestamp
            }
        }
        $Global:Error.Clear()
    }

    Get-Job | Where-Object {$_.State -in @("Completed","Stopped","Failed") -and $_.Name -notmatch "^WebRequest-"} | Foreach-Object {
        if ($_.HasMoreData) {Receive-Job $_ > $null}
        Remove-Job $_ -Force -ErrorAction Ignore
    }

    if ($Global:GlobalSysInfoJob -and $Global:GlobalSysInfoJob.State -eq "Running") {$Global:GlobalSysInfoJob | Receive-Job > $null}

    #[System.GC]::Collect()

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
        Write-Log "Runtime interval changed from $($Session.CurrentInterval) to $NextInterval seconds. "
        $RoundEnd = $RoundEnd.AddSeconds($NextInterval-$Session.CurrentInterval)
        $Session.CurrentInterval = $NextInterval
    }

    Update-WatchdogLevels -Interval $(if ($NextInterval -gt $NextIntervalPreset) {$NextInterval})

    $WaitSeconds = [int]($RoundEnd - $Session.Timer).TotalSeconds

    Write-Log "Start waiting $($WaitSeconds) seconds before next run. "

    if ($IsWindows) {$Host.UI.RawUI.FlushInputBuffer()}

    $cursorPosition = $host.UI.RawUI.CursorPosition
    $cmdMenu = [System.Collections.Generic.List[string]]::new()
    [void]$cmdMenu.AddRange([string[]]@("E[x]it","[R]estart","[B]alance update","[S]kip SP","[W]D reset"))
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {[void]$cmdMenu.Insert(0,"[U]pdate RainbowMiner")}
    if (-not $Session.IsDonationRun -and -not $Session.IsServerDonationRun){[void]$cmdMenu.Add("[C]onfiguration")}
    [void]$cmdMenu.Add("[V]erbose$(if ($Session.Config.UIstyle -eq "full"){" off"})")
    if (-not $Global:PauseMiners.Test() -or $Global:PauseMiners.TestIA()) {[void]$cmdMenu.Add("[P]ause$(if ($Global:PauseMiners.Test()){" off"})")}
    if (-not $Session.IsExclusiveRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {[void]$cmdMenu.Add("$(if ($LockMiners){"Un[l]ock"} else {"[L]ock"})")}
    Write-Host "Waiting $($WaitSeconds)s until next run: $($cmdMenu -join ", ")"

    $API.CmdMenu = $cmdMenu

    $SamplesPicked = 0
    $WaitRound = 0
    $SomeMinersFailed = $false
    $MinerStart = $Session.Timer
    $WarnedConsole = $false
    $UpdateToMaster = $false
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
                            elseif ($Session.Config.RestartRBMTimespan -gt 0 -and $Session.StartTimeCore.AddSeconds($Session.Config.RestartRBMTimespan) -le (Get-Date).ToUniversalTime()) {"RT"}
                            elseif ($Session.Config.RestartRBMMemory -gt 0 -and $Global:last_memory_usage_byte -and $Session.Config.RestartRBMMemory -lt $Global:last_memory_usage_byte) {"RM"}
                            elseif (-not $WarnedConsole) {
                                try {
                                    if ([System.Console]::KeyAvailable) {
                                        $key = [System.Console]::ReadKey($true)
                                        if (-not $key.Modifiers) {$key.key}
                                        elseif ($key.Modifiers -eq "Control") {
                                            if ($key.key -eq "C") {"X"}
                                            elseif ($key.key -eq "U") {"c-U"}
                                        }
                                    }
                                } catch {
                                    Write-Log -Level Warn "Console not available. Please use the web console. ($($_.Exception.Message))"
                                    $WarnedConsole = $true
                                }
                            }


        if ($keyPressedValue) {

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
                            $Session.LockMiners.Pools = @($Global:ActiveMiners | Where-Object {$_.Status -eq [MinerStatus]::Running} | Foreach-Object {for($i=0;$i -lt $_.Pool.Count;$i++) {"$($_.Pool | Select-Object -Index $i)-$($_.BaseAlgorithm | Select-Object -Index $i)-$($_.CoinSymbol | Select-Object -Index $i)"}} | Select-Object -Unique)
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
                "c-U" {
                    $Session.AutoUpdate = $true
                    $UpdateToMaster = $true
                    $API.Update = $false
                    Write-Log "User requests to update to MASTER"
                    Write-Host -NoNewline "[Ctrl-U] pressed - automatic update of Rainbowminer will be started "
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
                "RT" {
                    $Session.Restart = $true
                    Write-Log "Maximum running time reached: RainbowMiner restarts"
                    Write-Host -NoNewline "[RT] running time limit reached, restarting RainbowMiner."
                    $keyPressed = $true
                    Break
                }
                "RM" {
                    $Session.Restart = $true
                    Write-Log "Maximum memory usage reached: RainbowMiner restarts"
                    Write-Host -NoNewline "[RM] memory usage limit reached, restarting RainbowMiner."
                    $keyPressed = $true
                    Break
                }
                "W" {
                    $API.WatchdogReset = $false
                    Write-Host -NoNewline "[W] pressed - resetting WatchDog."
                    $Global:WatchdogTimers.Clear()
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

            $API.CmdKey = "$(if ($keyPressed) {$keyPressedValue})"

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
    foreach ( $Miner in $Global:ActiveMiners ) {
        if ($Miner.Stopped) {
            $Miner.StopMiningPostCleanup()
        }
    }
        
    if ($Session.Restart -or $Session.AutoUpdate) {
        $Session.Stopp = $false
        try {
            if ($IsWindows) {
                $CurrentProcess = Get-CimInstance Win32_Process -filter "ProcessID=$PID" | Select-Object CommandLine,ExecutablePath
                if ($CurrentProcess.CommandLine -and $CurrentProcess.ExecutablePath) {
                    if ($Session.AutoUpdate) {$Update_Parameters = @{calledfrom="core";UpdateToMaster=$UpdateToMaster};& .\Updater.ps1 @Update_Parameters}
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
                if ($Session.AutoUpdate) {$Update_Parameters = @{calledfrom="core";UpdateToMaster=$UpdateToMaster};& .\Updater.ps1 @Update_Parameters}
                $Session.Stopp = $true
            }
        }
        catch {
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
    $ExcavatorWindowsClosed = [System.Collections.Generic.List[string]]::new()
    foreach ( $Miner in $Global:ActiveMiners ) {
        if ($Miner.Activated -gt 0 -or $Miner.GetStatus() -eq [MinerStatus]::Running) {
            if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
                Write-Log "Closing miner $($Miner.Name)"
                $Miner.StopMining()
            }
            if ($Miner.BaseName -like "Excavator*" -and -not $ExcavatorWindowsClosed.Contains($Miner.BaseName)) {
                $Miner.ShutDownMiner()
                [void]$ExcavatorWindowsClosed.Add($Miner.BaseName)
            }
        }
    }
    if ($IsWindows) {
        Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {$_.ExecutablePath -like "$(Get-Location)\Bin\*"} | Stop-Process -Force -ErrorAction Ignore
    } elseif ($IsLinux) {
        try {
            $BinPath = "$(Get-Location)/Bin/*"
            $BinPathIncludes = "$(Get-Location)/IncludesLinux/bin/*"
            ps -eo pid,user,comm,args --no-headers | ForEach-Object {
                $fields = [RBMToolBox]::Split([RBMToolBox]::Trim($_), " ", 4)
                [PSCustomObject]@{
                    PID  = $fields[0]
                    User = $fields[1]
                    Command = $fields[2]
                    Args = if ($fields.Count -gt 3) { $fields[3] } else { "" }
                }
            } | Where-Object {$_.Args -like $BinPath -or $_.Args -like $BinPathIncludes} | Foreach-Object {
                if (Test-OCDaemon) {
                    $Cmd = "kill $($_.PID)"
                    Invoke-OCDaemon -Cmd $Cmd -Quiet > $null

                    if ($_.User -eq "root" -and $_.Args -like $BinPath -and -not (Test-IsElevated)) {
                        $exeCandidate = [RBMToolBox]::Split($_.Args," ",2,$false)[0]
                        if ($exeCandidate -like $BinPath -and (Test-Path $exeCandidate)) {
                            $exePath = (Get-Item $exeCandidate).FullName
                            $cmdDir  = Split-Path $exePath -Parent
                            try {
                                Invoke-OCDaemon -Cmd "$(Get-Location)/IncludesLinux/bash/setperms.sh `"$($cmdDir)`" root" -Quiet > $null
                            } catch {
                                Write-Log -Level Warn "Problem setting permissions inside $($Job.WorkingDir): $($_.Exception.Message)"
                            }
                        }
                    }

                } else {
                    Stop-Process -Id $_.PID -Force -ErrorAction Ignore
                }
            }
        } catch {
            Write-Log -Level Warn "Problem shutting down leftover processes: $($_.Exception.Message)"
        }
        if (Get-Command "screen" -ErrorAction Ignore) {

            $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()
            if (Test-OCDaemon) {
                $Cmd = [System.Collections.Generic.List[string]]::new()
                [void]$Cmd.Add("screen -ls `"$WorkerName`" |  grep '[0-9].$($WorkerName)_' | (")
                [void]$Cmd.Add("  IFS=`$(printf '\t');")
                [void]$Cmd.Add("  sed `"s/^`$IFS//`" |")
                [void]$Cmd.Add("  while read -r name stuff; do")
                [void]$Cmd.Add("    screen -S `"`$name`" -X stuff `^C >/dev/null 2>&1")
                [void]$Cmd.Add("    sleep .1 >/dev/null 2>&1")
                [void]$Cmd.Add("    screen -S `"`$name`" -X stuff `^C >/dev/null 2>&1")
                [void]$Cmd.Add("    sleep .1 >/dev/null 2>&1")
                [void]$Cmd.Add("    screen -S `"`$name`" -X quit  >/dev/null 2>&1")
                [void]$Cmd.Add("    screen -S `"`$name`" -X quit  >/dev/null 2>&1")
                [void]$Cmd.Add("  done")
                [void]$Cmd.Add(")")
                Invoke-OCDaemon -Cmd $Cmd > $null
            }

            Invoke-Exe "screen" -ArgumentList "-ls" -ExpandLines | Where-Object {$_ -match "(\d+\.$($WorkerName)_[a-z0-9_-]+)"} | Foreach-Object {
                Invoke-Exe "screen" -ArgumentList "-S $($Matches[1]) -X stuff `^C" > $null
                Start-Sleep -Milliseconds 250
                Invoke-Exe "screen" -ArgumentList "-S $($Matches[1]) -X quit" > $null
            }
        }
        if (Get-Command "tmux" -ErrorAction Ignore) {

            $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()

            if (Test-OCDaemon) {
                $Cmd = [System.Collections.Generic.List[string]]::new()
                [void]$Cmd.Add("if tmux has-session 2>/dev/null; then")
                [void]$Cmd.Add("  tmux list-sessions -F '#{session_name}' | grep '$($WorkerName)_' | (")
                [void]$Cmd.Add("    while read -r name; do")
                [void]$Cmd.Add("      tmux send-keys -t `"`$name`" C-c >/dev/null 2>&1")
                [void]$Cmd.Add("      sleep 0.1 >/dev/null 2>&1")
                [void]$Cmd.Add("      tmux send-keys -t `"`$name`" C-c >/dev/null 2>&1")
                [void]$Cmd.Add("      sleep 0.1 >/dev/null 2>&1")
                [void]$Cmd.Add("      tmux kill-session -t `"`$name`" >/dev/null 2>&1")
                [void]$Cmd.Add("    done")
                [void]$Cmd.Add("  )")
                [void]$Cmd.Add("fi")

                Invoke-OCDaemon -Cmd $Cmd > $null
            }

            Invoke-Exe "tmux" -ArgumentList "list-sessions -F '#{session_name}' 2>/dev/null" -ExpandLines | Where-Object { $_ -match "($($WorkerName)_[a-z0-9_-]+)" } | ForEach-Object {
                $SessionName = $Matches[1]       
                Invoke-Exe "tmux" -ArgumentList "send-keys -t $SessionName C-c" > $null
                Start-Sleep -Milliseconds 250
                Invoke-Exe "tmux" -ArgumentList "kill-session -t $SessionName" > $null
            }
        }
    }

    if (-not $Session.SetupOnly -and (Test-Path ".\Data\rbm.pid")) {Remove-Item ".\Data\rbm.pid" -Force -ErrorAction Ignore}

    Stop-SysInfo
    Stop-Autoexec

    [console]::TreatControlCAsInput = $false
}

##
## Utility functions
##

##
## Sysinfo functions
##

function Start-SysInfo {
    if ($Global:GlobalSysInfoJob) {Stop-SysInfo}

    $Global:GlobalSysInfoJob = $null

    $CPU_tdp = if ($Session.Config.PowerCPUtdp) {$Session.Config.PowerCPUtdp} else {$Global:GlobalCPUInfo.TDP}
    try {
        $Global:GlobalSysInfoJob = Start-ThreadJob -InitializationScript ([scriptblock]::Create("Set-Location `"$((Get-Location).Path -replace '"','``"')`"")) -FilePath ".\Scripts\SysInfo.ps1" -Name "SysInfo" -ArgumentList $PID, $Session.PhysicalCPUs, $CPU_tdp, $Session.IsARM -ErrorAction Stop
    } catch {
        Write-Log -Level Info "Could not start SysInfo job"
    }
    $Global:GlobalSysInfoJob -ne $null
}

function Stop-SysInfo {
    if ($Global:GlobalSysInfoJob) {
        try {
            if ($Global:GlobalSysInfoJob.HasMoreData) {Receive-Job $_ > $null}
            Remove-Job $Global:GlobalSysInfoJob -Force
        } catch {
        }
    }
    $Global:GlobalSysInfoJob = $null
}

##
## GET functions
##

function Get-Balance {
    [CmdletBinding()]
    param($Config,[Bool]$Refresh = $false)
    
    if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and $Config.EnableServerPools) {
        if (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2) {
            try {
                Invoke-RestMethodAsync "server://balances?raw=1" -cycletime ($Config.BalanceUpdateMinutes*60) -Timeout 20
            } catch {}
        }
    }

    if (-not (Test-Path Variable:Global:CachedPoolBalances) -or $Refresh) {
        $Global:CachedPoolBalances = [System.Collections.Generic.List[PSCustomObject]]::new()
        Get-BalancesContent -Config $Config | Where-Object {-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains $_.Currency} | Group-Object -Property Caption | Foreach-Object {
            if ($_.Count -gt 1){foreach ($p in @("Balance","Pending","Total","Paid","Earned","Payouts")) {if (Get-Member -InputObject $_.Group[0] -Name $p) {if ($p -eq "Payouts") {$_.Group[0].$p = @($_.Group.$p | Select-Object)} else {$_.Group[0].$p = ($_.Group.$p | Measure-Object -Sum).Sum}}}}
            [void]$Global:CachedPoolBalances.AddRange([PSCustomObject[]]$_.Group[0])
        }
    }

    $Balances = $Global:CachedPoolBalances | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json -ErrorAction Ignore
    if (-not $Session.Config.ShowWalletBalances) {
        $Balances = $Balances | Where-Object {$_.BaseName -ne "Wallet"}
    }

    if (-not $Balances) {return}

    #Get exchange rates for all payout currencies
    $CurrenciesWithBalances = [System.Collections.Generic.List[string]]::new()
    $CurrenciesToExchange   = [System.Collections.Generic.List[string]]::new()
    $CurrenciesMissing      = [System.Collections.Generic.List[string]]::new()

    $RatesAPI = [PSCustomObject]@{}
    
    $Balances.currency | Select-Object -Unique | Sort-Object | Foreach-Object {[void]$CurrenciesWithBalances.Add($_)}
    @("BTC") + $Config.Currency | Select-Object -Unique | Sort-Object | Foreach-Object {[void]$CurrenciesToExchange.Add($_)}
    $CurrenciesWithBalances + $CurrenciesToExchange | Where-Object {-not $Global:Rates.ContainsKey($_)} | Foreach-Object {[void]$CurrenciesMissing.Add($_)}

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

    $Digits = [hashtable]@{}
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
    $Earnings = $null
    Remove-Variable -Name Earnings -ErrorAction Ignore
    
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
    foreach ( $Miner in $Global:ActiveMiners ) {

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.BaseAlgorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_)_HashRate" -Sub $Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel])})}

        if ($Miner.New) {
            if (-not $Miner.Benchmarked) {$Miner.CrashCount = 0}
            $Miner.Benchmarked++
        }

        if (($Miner.Status -eq [Minerstatus]::Running) -or $Miner.New) { #GetStatus() check?
            $Miner_PowerDraw = $Miner.GetPowerDraw()

            $Statset = 0
            $Miner_Index = 0
            $Miner_Failed= $false
            foreach ($Miner_Algorithm in $Miner.Algorithm) {
                $Miner_Speed = $Miner.GetHashRate($Miner_Algorithm,$true)
                $Miner_Diff  = $Miner.GetDifficulty($Miner_Algorithm)
                $Miner_Benchmarking = $Miner.IsBenchmarking()

                $Miner.Speed_Live[$Miner_Index] = [Double]$Miner_Speed

                Write-Log "$($Miner.BaseName) $(if ($Miner_Benchmarking) {"benchmarking"} else {"mining"}) $($Miner_Algorithm) on $($Miner.DeviceModel): $($Miner.GetMinerDataCount()) samples / round $(if ($Miner_Benchmarking) {"$($Miner.Benchmarked) / variance $("{0:f2}" -f ($Miner.Variance[$Miner.Algorithm.IndexOf($Miner_Algorithm)]*100))%"} else {$Miner.Rounds})"

                $Stat = $null
                if ($Miner_Speed -or -not $Miner_Benchmarking -or $Miner.CrashCount -ge $Session.Config.MaxCrashesDuringBenchmark) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($Miner_Algorithm -replace '\-.*$')_HashRate" -Value $Miner_Speed -Difficulty $Miner_Diff -Ratio $Miner.RejectedShareRatio[$Miner_Index] -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $Global:DeviceCache.DevicesToVendors[$Miner.DeviceModel] -StartTime $Miner.StartTime -Version "$(Get-MinerVersion $Miner.Version)" -LogFile "$(Split-Path -Leaf $Miner.LogFile)" -Quiet:$($Quiet -or ($Miner.GetRunningTime() -lt (New-TimeSpan -Seconds 30)) -or $Miner.IsWrapper())
                    $Statset++
                }

                # Find the WatchdogTimer without using Where-Object
                $WatchdogTimer = $null
                foreach ($wdTimer in $Global:WatchdogTimers) {
                    if ($wdTimer.MinerName -eq $Miner.Name -and 
                        $wdTimer.PoolName -eq $Miner.Pool[$Miner_Index] -and 
                        $wdTimer.Algorithm -eq $Miner_Algorithm) {
                        $WatchdogTimer = $wdTimer
                        break  # Stop searching once found
                    }
                }

                # Update WatchdogTimer if found
                if ($WatchdogTimer) {
                    $wdTime = (Get-Date).ToUniversalTime()
                    $WatchdogTimer.Active = $wdTime
                    if ($Stat -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                        $WatchdogTimer.Kicked = $Stat.Updated
                    } elseif ($Miner_Benchmarking -or ($Miner_Speed -and $Miner.Rounds -lt [Math]::Max($Miner.ExtendedInterval,1)-1)) {
                        $WatchdogTimer.Kicked = $wdTime
                    } elseif ($Watchdog -and $WatchdogTimer.Kicked -lt $Session.Timer.AddSeconds(-$Session.WatchdogInterval)) {
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

    if (-not $Session.Benchmarking -and -not $Session.IsBenchmarkingRun -and -not $Session.IsDonationRun -and -not $Session.IsServerDonationRun) {

        $CurrentProfitGPU    = 0
        $CurrentPowerDrawGPU = 0
        $DeviceNameCountGPU  = 0

        foreach ($CurrentModel in $Session.Config.DeviceModel) {
            if ($CurrentModel -notmatch "-") {
                $BestMiner = $null
                foreach ($Miner in $Global:ActiveMiners) {
                    if ($Miner.Profit -ne $null -and $Miner.DeviceModel -eq $CurrentModel -and $Miner.Pool -notcontains "MiningRigRentals") {
                        if (-not $BestMiner -or $Miner.Profit -gt $BestMiner.Profit) {
                            $BestMiner = $Miner
                        }
                    }
                }

                if ($BestMiner) {
                    $CurrentProfit = $BestMiner.Profit + $(if ($Session.Config.UsePowerPrice -and $BestMiner.Profit_Cost) { $BestMiner.Profit_Cost } else { 0 })
                    if ($CurrentProfit -gt 0) {
                        if ($CurrentModel -ne "CPU") {
                            $CurrentProfitGPU    += $CurrentProfit
                            $CurrentPowerDrawGPU += $BestMiner.PowerDraw
                            if ($DeviceNameCountGPU -lt $BestMiner.DeviceName.Count) {
                                $DeviceNameCountGPU = $BestMiner.DeviceName.Count
                            }
                        }
                        Set-Stat -Name "Profit-$($Global:DeviceCache.DeviceNames.$CurrentModel -join "-")" `
                                 -Value $CurrentProfit `
                                 -PowerDraw $BestMiner.PowerDraw `
                                 -Duration $StatSpan `
                                 -UplimProtection $Session.Config.ProfitSpikeProtection > $null
                    }
                }
            }
        }

        if ($CurrentProfitGPU -gt 0) {
            $DeviceNameGPU = @()
            foreach ($Device in $Global:DeviceCache.Devices) {
                if ($Device.Type -eq "Gpu") {
                    $DeviceNameGPU += $Device.Name
                }
            }
            $DeviceNameGPU = $DeviceNameGPU | Sort-Object

            if ($DeviceNameGPU.Count -gt $DeviceNameCountGPU) {
                Set-Stat -Name "Profit-$($DeviceNameGPU -join "-")" `
                         -Value $CurrentProfitGPU `
                         -PowerDraw $CurrentPowerDrawGPU `
                         -Duration $StatSpan `
                         -UplimProtection $Session.Config.ProfitSpikeProtection > $null
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

    $Version      = "RainbowMiner $($Session.Version.ToString())"
    $Status       = if ($Global:PauseMiners.Test()) {"Paused"} elseif (-not $Session.Profitable) {"Waiting"} else {"Running"}
    $UncleanAlert = if ($Session.ReportUnclean) {$Session.ReportUnclean = $false; $true} else {$false}
    $ReportRates  = [PSCustomObject]@{}

    $Session.Config.Currency | Where-Object {$Global:Rates.ContainsKey($_)} | Foreach-Object {$ReportRates | Add-Member $_ $Global:Rates.$_ -Force}

    $Including_Strings = [System.Collections.Generic.List[string]]::new()
    if ($Session.ReportTotals)    {[void]$Including_Strings.Add("totals")}
    if ($Session.ReportMinerData) {[void]$Including_Strings.Add("minerdata")}
    if ($Session.ReportPoolsData) {[void]$Including_Strings.Add("poolsdata")}
    if ($Session.ReportDeviceData){[void]$Including_Strings.Add("devicedata")}
    Write-Log "Pinging monitoring server$(if ($Including_Strings.Count) {" (including $($Including_Strings -join ", "))"}). "

    $Profit = 0.0
    $PowerDraw = 0.0
    $TempAlert = 0

    $minerreport = ConvertTo-Json @(
        $Global:ActiveMiners | Where-Object {$_.Activated -GT 0 -and $_.Status -eq [MinerStatus]::Running} | ForEach-Object {
            $Miner = $_
            $Miner_PowerDraw = $Miner.GetPowerDraw()
            $Profit += [Double]$Miner.Profit
            $PowerDraw += [Double]$Miner_PowerDraw

            $Devices = [System.Collections.Generic.List[PSCustomObject]]::new()
            Get-Device $Miner.DeviceName | Foreach-Object {
                if ($_.Type -eq "GPU") {
                    if ($_.Data.Temperature -gt $Session.Config.MinerStatusMaxTemp) {$TempAlert++}
                    [void]$Devices.Add([PSCustomObject]@{
                        Id    = $_.Type_PlatformId_Index
                        Name  = $_.Model
                        Mem   = [int]($_.OpenCL.GlobalMemSize / 1GB)
                        Temp  = $_.Data.Temperature
                        Fan   = $_.Data.FanSpeed
                        Watt  = $_.Data.PowerDraw
                        Core  = $_.Data.Clock
                        MemC  = $_.Data.ClockMem
                        MaxTemp = $_.DataMax.Temperature
                    })
                } else {
                    [void]$Devices.Add([PSCustomObject]@{
                        Id    = $_.Type_PlatformId_Index
                        Name  = $_.Model_Name
                        Watt  = $_.Data.PowerDraw
                        Temp  = $_.Data.Temperature
                    })
                }
            }

            # Create a custom object to convert to json. Type, Pool, CurrentSpeed and EstimatedSpeed are all forced to be arrays, since they sometimes have multiple values.
            [PSCustomObject]@{
                Name           = $Miner.BaseName
                Version        = $Miner.Version
                Path           = (Resolve-Path -Relative $Miner.Path).Path
                Type           = @($Miner.DeviceModel)
                Active         = "{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $Miner.GetActiveTime()
                Algorithm      = @($Miner.BaseAlgorithm)
                BLK            = @($Miner.BLK)
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
        }
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

    if (Test-Path ".\Data\reportapi.json") {try {$ReportAPI = Get-ContentByStreamReader ".\Data\reportapi.json" | ConvertFrom-Json -ErrorAction Stop} catch {$ReportAPI=$null}}
    if (-not $ReportAPI) {$ReportAPI = @([PSCustomObject]@{match    = "rbminer.net";apiurl   = "https://api.rbminer.net/report.php"})}

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
            Write-Log "Miner Status $($ReportUrl) failed to create crash alerts. "
        }
    }

    # Create out-of-space alert
    $DiskMinGBAlert = ConvertTo-Json @($Session.SysInfo.Disks | Where-Object {($IsLinux -or "$PWD" -match "^$($_.Drive)") -and ($_.TotalGB - $_.UsedGB) -lt $Session.Config.DiskMinGB} | Select-Object) -Compress

    # Add current console.txt
    $Console = $null
    if ($Session.IsCore -or $Session.EnableCurl) {
        try {
            if (Test-Path ".\Logs\console.txt") {
                @(Get-ContentByStreamReader -FilePath ".\Logs\console.txt" -ExpandLines) | Foreach-Object {$_ -replace "\x1B\[[;\d]+m"} | Set-Content -Path ".\Cache\console.txt" -Encoding Utf8
                $Console = Get-Item ".\Cache\console.txt"
                if ($Console.Length -le 100) {$Console = $null}
            }
        } catch {
            Write-Log "Miner Status $($ReportUrl) failed to add current console.txt. "
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
            Write-Log "Miner Status $($ReportUrl) failed to create device data. "
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

            Write-Log "Go report, go! $($ReportUrl)"

            $Response = Invoke-GetUrl $ReportUrl -body @{
                            user           = $Session.Config.MinerStatusKey
                            email          = $Session.Config.MinerStatusEmail
                            pushoverkey    = $Session.Config.PushOverUserKey
                            worker         = $Session.Config.WorkerName
                            machinename    = $Session.MachineName
                            machineip      = $Session.MyIP
                            cpu            = "$($Global:DeviceCache.DevicesByTypes.CPU.Model_Name | Select-Object -Unique)"
                            cputemp        = "$(($Session.SysInfo.Cpus.Temperature | Measure-Object -Average).Average)"
                            cpuload        = "$($Session.SysInfo.CpuLoad)"
                            cpupower       = "$(($Session.SysInfo.Cpus.PowerDraw | Measure-Object -Sum).Sum)"
                            version        = $Version
                            status         = $Status
                            profit         = "$Profit"
                            powerdraw      = "$PowerDraw"
                            earnings_avg   = "$($Session.Earnings_Avg)"
                            earnings_1d    = "$($Session.Earnings_1d)"
                            pool_totals    = ConvertTo-Json @($Pool_Totals | Select-Object) -Depth 10 -Compress
                            rates          = ConvertTo-Json $ReportRates -Depth 10 -Compress
                            interval       = $ReportInterval
                            uptime         = "$((Get-Uptime).TotalSeconds)"
                            sysuptime      = "$((Get-Uptime -System).TotalSeconds)"
                            maxtemp        = "$($Session.Config.MinerStatusMaxTemp)"
                            tempalert      = $TempAlert
                            maxcrashes     = "$($Session.Config.MinerStatusMaxCrashesPerHour)"
                            crashalert     = $CrashAlert
                            crashdata      = $CrashData
                            diskmingbalert = $DiskMinGBAlert
                            uncleanalert   = $UncleanAlert
                            console        = $Console
                            devices        = $DeviceData
                            data           = $minerreport
                        }

            Write-Log "Done report, done."

            if ($Response -is [string] -or $Response.Status -eq $null) {$ReportStatus = $Response -split "[\r\n]+" | Select-Object -first 1}
            else {
                $ReportStatus = $Response.Status
                if ($Response.Actions -ne $null) {
                    $Response.Actions | Foreach-Object {
                        $Action = $_
                        # do something :)
                        Write-Log "Executing action `"$($Action.Action)`""
                        Switch($Action.Action) {
                            "resetfailedbenchmarks" {
                                $Action_Response = & ".\web\scripts\resetzerohashrateminers"
                                $Action_Response = $Action_Response | Where-Object {$_ -and $_ -notmatch "<.+?>"}
                                Break
                             }
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
                    $LastSeen_Min = (Get-UnixTimestamp) - 300
                    $OtherWorkers | Where-Object {$LastSeen_Min -lt $_.lastseen} | Foreach-Object {$Profit += [decimal]$_.profit;$Earnings_Avg = [Math]::Max($Earnings_Avg,[decimal]$_.earnings_avg);$Earnings_1d = [Math]::Max($Earnings_1d,[decimal]$_.earnings_1d)}
                    $API.RemoteMiners = $OtherWorkers
                    $API.RemoteMinersProfit = $Profit
                    $API.RemoteMinersEarnings_Avg = $Earnings_Avg
                    $API.RemoteMinersEarnings_1d  = $Earnings_1d
                }
                if ($Response.Compare -ne $null) {
                    $API.CompareMiners = ConvertTo-Json @($Response.Compare | Select-Object) -Depth 10
                }
                if ($Response.IP -ne $null) {
                    $API.RemoteIP = $Response.IP
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
        Write-Log "Miner Status $($ReportUrl) has failed. "
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
    foreach ( $Miner in $Global:ActiveMiners ) {
        if ($Miner.Best) {
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
        }
    }

    if ($MinersFailed) {
        $API.RunningMiners = ConvertTo-Json @($Global:ActiveMiners | Where-Object {$_.Status -eq [MinerStatus]::Running} | ForEach-Object {$_ | Select-Object -Property * -ExcludeProperty *Job}) -Depth 10 -ErrorAction Ignore 
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
    
    $NewRates    = [hashtable]@{}
    try {
        $NewCoinbase = (Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -Jobkey "coinbase").data.rates
        if ($NewCoinbase.BTC) {
            $NewCoinbase.PSObject.Properties | Where-Object {($_.Name -notin $WCSymbols -or $_.Name -in $BaseSymbols) -and $_.Name -ne "BIT"} | Foreach-Object {$NewRates[$_.Name] = [Double]$_.Value}
        }
    } catch {}

    if (-not $NewRates.Count) {
        Write-Log "Coinbase is down, using fallback. "
        try {
            $AltCoinbase = Invoke-GetUrl "https://api.rbminer.net/data/coinbase.json"
            if ($AltCoinbase.BTC) {
                $AltCoinbase.PSObject.Properties | Where-Object {$_.Name -notin $WCSymbols -or $_.Name -in $BaseSymbols} | Foreach-Object {$NewRates[$_.Name] = [Double]$_.Value}
            }
        } catch {Write-Log -Level Warn "Coinbase down. "}
    }

    $Global:Rates["BTC"] = $NewRates["BTC"] = [Double]1

    Compare-Object @($GetSymbols) @($NewRates.Keys) -IncludeEqual | Where-Object {$_.SideIndicator -ne "=>" -and $_.InputObject} | Foreach-Object {
        if ($_.SideIndicator -eq "==") {$Global:Rates[$_.InputObject] = [Double]$NewRates[$_.InputObject]}
        elseif ($Session.GetTicker -inotcontains $_.InputObject) {[void]$Session.GetTicker.Add($_.InputObject.ToUpper())}
    }

    Compare-Object @($WCSymbols) @($Global:Rates.Keys) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject | Foreach-Object {$Global:Rates[$_] = [Math]::Round($Global:Rates[$_],3)}

    if ($Session.GetTicker.Count -gt 0) {
        try {
            $SymbolStr = "$(($Session.GetTicker | Sort-Object) -join ',')".ToUpper()
            $RatesAPI = Invoke-RestMethodAsync "https://api.rbminer.net/cmc.php?symbols=$($SymbolStr)" -Jobkey "morerates" -cycletime 600
            if (-not $RatesAPI.status) {
                Write-Log "api.rbminer.net/cmc failed for $($SymbolStr)"
            } elseif ($RatesAPI.data -and $RatesAPI -is [object]) {
                $RatesAPI.data.PSObject.Properties | Foreach-Object {$Global:Rates[$_.Name] = if ($_.Value -gt 0) {[double](1e8/$_.Value)} else {0}}
                if ($RatesAPI.ip -ne $null) {
                    $API.RemoteIP = $RatesAPI.ip
                }
            }
        }
        catch {
            Write-Log "api.rbminer.net/cmc API for $($SymbolStr) has failed. "
        }
    }
}

#
# Stats functions
#

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
        if (Test-Path $Path) {Write-Log -Level $(if ($Quiet) {"Info"} else {"Warn"}) "Balances file ($Name) is corrupt and will be reset. "}
        $Stat = [PSCustomObject]@{
                    PoolName = $Balance.Namedown
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

#
# General functions
#

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
            $NewCrash = [PSCustomObject]@{
                Timestamp      = $Now
                Start          = $ActiveStart
                End            = $Miner.GetActiveLast()
                Runtime        = $Runtime.TotalSeconds
                Name           = $Miner.BaseName
                Device         = @($Miner.DeviceModel)
                Algorithm      = @($Miner.BaseAlgorithm)
                Pool           = @($Miner.Pool)
            }
            [void]$Global:CrashCounter.Add($NewCrash)
        }
        $CrashTimeLimit = $Now.AddHours(-1)
        $Global:CrashCounter.RemoveAll({ param($c) $c.Timestamp -le $CrashTimeLimit }) > $null

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

function Get-LastDrun {
    if (Test-Path ".\Data\lastdrun.json") {try {[DateTime](Get-ContentByStreamReader ".\Data\lastdrun.json" | ConvertFrom-Json -ErrorAction Stop).lastdrun} catch {}}
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
        try {[DateTime](Get-ContentByStreamReader ".\Data\starttime.json" | ConvertFrom-Json -ErrorAction Stop).starttime} catch {}
        Remove-Item ".\Data\starttime.json" -Force -ErrorAction Ignore
    }
}

function Set-LastStartTime {
    Set-ContentJson -Data ([PSCustomObject]@{starttime=[DateTime]$Session.StartTime}) -PathToFile ".\Data\starttime.json" > $null
}

function Start-Autoexec {
[cmdletbinding()]
param(
    [ValidateRange(-2, 10)]
    [Parameter(Mandatory = $false)]
    [Int]$Priority = 0
)
    if (-not (Test-Path ".\Config\autoexec.txt") -and (Test-Path ".\Data\autoexec.default.txt")) {Copy-Item ".\Data\autoexec.default.txt" ".\Config\autoexec.txt" -Force -ErrorAction Ignore}
    $Global:AutoexecCommands = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach($cmd in @(Get-ContentByStreamReader ".\Config\autoexec.txt" -ExpandLines | Select-Object)) {
        if ($cmd -match "^[\s\t]*`"(.+?)`"(.*)$") {
            if (Test-Path $Matches[1]) {                
                try {
                    $FilePath     = [IO.Path]::GetFullPath("$($Matches[1])")
                    $FileDir      = Split-Path $FilePath
                    $FileName     = Split-Path -Leaf $FilePath
                    $ArgumentList = "$($Matches[2].Trim())"
                    
                    # find and kill maroding processes
                    $FileLike = "$(Join-Path $FileDir "*")"
                    $ArgsLike = "* $($ArgumentList)"
                    if ($IsWindows) {
                        $processes = Get-CIMInstance CIM_Process | Where-Object {
                            $_.ExecutablePath -and $_.ExecutablePath -like $FileLike -and 
                            $_.ProcessName -like $FileName -and 
                            (-not $ArgumentList -or $_.CommandLine -like $ArgsLike)
                        }
                        
                        foreach($process in $processes) {
                            Write-Log -Level Warn "Stop-Process $($process.ProcessName) with Id $($process.ProcessId)"
                            Stop-Process -Id $process.ProcessId -Force -ErrorAction Ignore
                        }
                    } elseif ($IsLinux) {
                        $processes = Get-Process | Where-Object {
                            $_.Path -and 
                            $_.Path -like $FileLike -and 
                            $_.ProcessName -like $FileName -and 
                            (-not $ArgumentList -or $_.CommandLine -like $ArgsLike)
                        }

                        foreach($process in $processes) {
                            Write-Log -Level Warn "Stop-Process $($process.ProcessName) with Id $($process.Id)"
                            if (Test-OCDaemon) {Invoke-OCDaemon -Cmd "kill $($process.Id)" -Quiet > $null}
                            else {Stop-Process -Id $process.Id -Force -ErrorAction Ignore}
                        }
                    }
                    $processses = $null

                    $Job = Start-SubProcess -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $FileDir -ShowMinerWindow $true -Priority $Priority -SetLDLIBRARYPATH -WinTitle "$FilePath $ArgumentList".Trim() -Quiet
                    if ($Job) {
                        $Job | Add-Member FilePath $FilePath -Force
                        $Job | Add-Member Arguments $ArgumentList -Force
                        Write-Log "Autoexec command started: $FilePath $ArgumentList"
                        [void]$Global:AutoexecCommands.Add($Job)
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
    $Global:AutoexecCommands | Where-Object {$_.ProcessId -or $_.Name} | Foreach-Object {
        Stop-SubProcess -Job $_ -Title "Autoexec command" -Name "$($_.FilePath) $($_.Arguments)" -SkipWait
    }
}

function Test-IsOnBattery {
    [bool]$(if ($IsWindows) {
        try {
            -not (Get-CimInstance -classname BatteryStatus -namespace "root\wmi" -ErrorAction Stop).PowerOnline
        } catch {
        }
    })
}

function Test-Internet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string[]]$CheckDomains = @("www.google.com","www.amazon.com","www.coinbase.com","www.sina.com")
    )

    $tested = $false
    $ok     = $false

    try {
        if ($CheckDomains -and $CheckDomains.Count) {
            $Proxy = Get-Proxy

            if ($IsWindows -and -not $Proxy.Proxy -and (Get-Command "Test-Connection" -ErrorAction Ignore)) {
                $tested = $true
                $oldProgressPreference = $Global:ProgressPreference
                $Global:ProgressPreference = "SilentlyContinue"
                Foreach ($url in $CheckDomains) {if (Test-Connection -ComputerName $url -Count 1 -ErrorAction Ignore -Quiet -InformationAction Ignore) {$ok = $true;break}}
                $Global:ProgressPreference = $oldProgressPreference
            }

            if (-not $ok -and $Session.Curl) {
                $tested = $true
                $curlproxy = ""
                if ($Proxy.Proxy) {
                    $curlproxy = "-x `"$($Proxy.Proxy)`" "
                    if ($Proxy.Username -and $Proxy.Password) {
                        $curlproxy = "$($curlproxy)-U `"$($Proxy.Username):$($Proxy.Password)`" "
                    }
                }
                Foreach ($url in $CheckDomains) {
                    $Data = (Invoke-Exe $Session.Curl -ArgumentList "--head `"http://$($url)`" $($curlproxy)-m 1 --connect-timeout 1 -A `"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36`" -q -w `"#~#%{response_code}`"" -WaitForExit 5) -split "#~#"
                    if ($Data -and $Data.Count -gt 1 -and $Global:LASTEXEEXITCODE -eq 0 -and $Data[-1] -match "^[23]\d\d") {$ok = $true;break}
                }
            }
        }
    } catch {}

    $ok -or -not $tested
}

function Test-CacheGrow {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory = $False)]
      [String]$Title = "",
      [Parameter(Mandatory = $False)]
      [String[]]$Name
    )

    if ($Session.Debug -and $Title -ne "") {
        Write-Log $Title
        return
    }

    if ($Name.Count -eq 0) {
        $Name = @("Where","min","ContainsKey","Substring","Foreach","Append","Contains","split","Replace","Pow","Insert","IndexOf","Log","Floor","EndsWith","IsNullOrEmpty","IsNullOrWhiteSpace")
    }

    if ($Script:CacheCount -eq $null) {
        $Script:CacheCount = @{}
    }

    $bindingType = [System.Management.Automation.PSObject].Assembly.GetType("System.Management.Automation.Language.PSInvokeMemberBinder")
    if ($bindingType) {
        $cacheField = $bindingType.GetField("s_binderCache", [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Static)
        if ($cacheField) {
            $cache = $cacheField.GetValue($null)
            if ($cache) {
                $currentCount = @{}
                foreach ($key in $cache.Keys) {
                    $cacheName = $cache[$key].Name
                    if ($cacheName -in $Name) {
                        if ($currentCount.ContainsKey($cacheName)) {
                            $currentCount[$cacheName]++
                        } else {
                            $currentCount[$cacheName]=1
                        }
                    }
                }

                foreach ($key in $currentCount.Keys) {
                    if ( $Script:CacheCount.ContainsKey($Key) ) {
                        if ( $currentCount[$key] -gt $Script:CacheCount[$key] ) {
                            $diff = $currentCount[$key] - $Script:CacheCount[$key]
                            if ($Title -ne "") {
                                if (-not $Session.Debug) {
                                    Write-Log "$($Title) CACHE $($key) increased $(if ($diff -ge 0) {"+"})$($diff)"
                                }
                            } else {
                                [PSCustomObject]@{
                                    Name = $key
                                    Count = $currentCount[$key]
                                    OldCount = $Script:CacheCount[$key]
                                    Diff = $diff
                                }
                            }
                        }
                    }
                    $Script:CacheCount[$key] = $currentCount[$key]
                }
            }
        }
    }
}

function Get-PowerPrice {
    $PowerPrice = $Session.Config.PowerPrice

    if ($Session.Config.OctopusTariffCode -ne '') {
        if ($Session.Config.OctopusTariffCode -match "^E-[12]R-([A-Z0-9-]+)-[A-Z]$") {
            $ProductCode = $Matches[1]
            try {
                $fromto = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")
                $OctopusRequest = Invoke-RestMethodAsync "https://api.octopus.energy/v1/products/$($ProductCode)/electricity-tariffs/$($Session.Config.OctopusTariffCode)/standard-unit-rates/?period_from={iso8601timestamp}" -timeout 10 -cycletime 600 -tag "octopuspower"
                if ($OctopusRequest.count) {
                    $OctopusRequest.results | Where-Object {(-not $_.valid_from -or $_.valid_from -le $fromto) -and (-not $_.valid_to -or $_.valid_to -gt $fromto)} | Foreach-Object {$PowerPrice = ([double]$_.value_inc_vat) / 100}
                }
            } catch {
                Write-Log -Level Info "Octopus tariff code $($Session.Config.OctopusTariffCode) is not in the Octopus database. Sometimes the letter code part is correct, but the date part isn't. Try AGILE-18-02-21 or GO-18-06-12 or SILVER-2017-1"
            }
        } else {
            Write-Log -Level Warn "Octopus tariff code has the wrong syntax. Use E-1R-{product_code}-{region_code}"
        }
    }
    $PowerPrice
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