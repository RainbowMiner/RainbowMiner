﻿enum MinerStatus {
    Running
    Idle
    Failed
    RunningFailed
}


class Miner {
    [string]$Name
    [string]$Version
    [string]$Path
    [string]$Arguments
    [string]$API
    [int]$Port
    [string[]]$Algorithm
    [string[]]$BaseAlgorithm
    [string[]]$Currency
    [string[]]$CoinName
    [string[]]$CoinSymbol
    [string[]]$DeviceName
    [string]$DeviceModel
    [Bool]$Enabled = $false
    [string[]]$Pool
    [string[]]$Wallet
    $Profit
    $Profit_Bias
    $Profit_Unbias
    [double]$Profit_Cost
    [double]$Profit_Cost_Bias
    [double]$PowerDraw
    $Stratum
    [double[]]$Speed
    [double[]]$Speed_Live
    [double[]]$Speed_Last = @(0,0)
    [double[]]$BLK
    [double[]]$Variance
    [string]$StartCommand
    [string]$StopCommand
    [Bool]$Best
    [Bool]$New
    [Int]$Benchmarked
    [string]$LogFile    
    [Bool]$ShowMinerWindow = $false
    [int]$MSIAprofile
    $OCprofile
    $OCprofileSet
    [Bool]$EnableOCprofile
    $DevFee
    [string]$BaseName
    [double]$FaultTolerance = 0.1
    [int]$ExtendInterval = 0
    [double]$Penalty = 0
    [double[]]$PoolPenalty
    [int]$PostBlockMining = 0
    [int]$Rounds = 0
    [int]$MinSamples = 1
    [int]$ZeroRounds = 0
    [int]$CrashCount = 0
    [int]$MaxBenchmarkRounds = 3
    [double]$MaxRejectedShareRatio = 0.3
    [int]$MiningPriority
    [string]$MiningAffinity
    [int]$ShareCheck = 0
    [int]$StaticPort = 0
    [int]$MemSizeGB = 0
    [string]$ManualUri
    [Double[]]$RejectedShareRatio
    [String]$EthPillEnable = "disable"
    [String]$EthPillEnableMTP = "disable"
    [string]$DataInterval
    [string]$ExcludePoolName
    [string]$Vendor = ""
    [String[]]$EnvVars
    [Hashtable]$Priorities = @{"CPU"=-2;"GPU"=-1;"CPUAffinity"=0}
    [Bool]$Stopped = $false
    [Bool]$Donator = $false
    [Bool]$Restart = $false
    [Bool]$IsFocusWalletMiner = $false
    [Bool]$IsExclusiveMiner = $false
    [Bool]$IsLocked = $false
    [Bool]$IsRunningFirstRounds = $false
    [Bool]$EnableAutoPort = $false
    [Bool]$NoCPUMining = $false
    [Bool]$NeedsBenchmark = $false
    [Bool]$BenchmarkOnly = $false
    [Bool]$SetLDLIBRARYPATH = $false
    [Bool]$SkipWaitOnShutDown = $false
    [Int]$MultiProcess = 0
    [String[]]$Executables
    [DateTime]$StartTime = [DateTime]::MinValue
    [DateTime]$ActiveLast = [DateTime]::MinValue
    [DateTime]$AccessLast = [DateTime]::MinValue
    [TimeSpan]$RunningTime = [TimeSpan]::Zero
    [MinerStatus]$Status = [MinerStatus]::Idle
    $Profiles
    [TimeSpan]$Active = [TimeSpan]::Zero
    [Int]$Activated = 0
    [DateTime]$IntervalBegin = 0
    [DateTime]$LastSetOCTime = 0
    [Int]$StartPort = 0
    $Job
    $EthPillJob
    $WrapperJob

    hidden $Data = $null

    Miner() {
        $this.ResetMinerData()
    }

    [String]GetArguments() {
        return $this.Arguments -replace "\`$mport",$this.Port -replace "\`$memsizegb",$this.MemSizeGB
    }

    [String]GetMinerDeviceName() {
        return "$($this.BaseName)-$(($this.DeviceName | Sort-Object) -join '-')"
    }

    [String]GetVendor() {
        if ($this.Vendor -eq "") {
            $Devices = @($this.DeviceModel -split '-')
            $this.Vendor  = $Global:GlobalCachedDevices | Where-Object {$Devices -contains $_.Model} | Foreach-Object {$_.Vendor} | Select-Object -Unique
        }
        return $this.Vendor
    }

    [Bool]IsWrapper() {
        return $this.API -match "Wrapper"
    }

    [System.Management.Automation.Job]GetMiningJob() {
        return $this.Job.XJob
    }

    [System.Management.Automation.Job]GetWrapperJob() {
        if ($Global:IsLinux) {
            return $this.WrapperJob
        } else {
            return $this.Job.XJob
        }
    }

    [String]GetShutdownUrl() {
        return ""
    }

    hidden StartMining() {
        $this.StopMining()

        $this.Status = [MinerStatus]::Failed

        $this.New = $true
        $this.Activated++
        $this.Rounds = 0
        $this.IntervalBegin = 0
        if (-not $this.StartPort) {$this.StartPort = $this.Port}

        if (-not $this.Job.XJob) {
            if ($this.StartCommand) {try {Invoke-Expression $this.StartCommand} catch {Write-Log -Level Warn "StartCommand failed for miner $($this.Name)"}}

            $Miner_Port = if ($this.StaticPort) {$this.StaticPort} else {$this.StartPort}

            $this.Port = $Miner_Port

            if ($this.EnableAutoPort) {

                [int[]]$PortsInUse = try {
                    $ipProperties = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
                    @($ipProperties.GetActiveTcpListeners().Port) + @($ipProperties.GetActiveTcpConnections().LocalEndPoint.Port) | Where-Object {$_} | Sort-Object -Unique
                } catch {

                    try {
                        if ($Global:IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
                            Get-ChildItem ".\IncludesLinux\bash" -Filter "getports.sh" -File | Foreach-Object {
                                try {
                                    (Start-Process "chmod" -ArgumentList "+x",$_.FullName -PassThru).WaitForExit() > $null
                                    Invoke-exe $_.FullName -ExpandLines
                                } catch {}
                            }
                        } elseif ($Global:IsWindows) {
                            if (Get-Command "Get-NetTCPConnection" -ErrorAction Ignore) {
                                (Get-NetTCPConnection -ErrorAction Stop).LocalPort | Sort-Object -Unique
                            } else {
                                netstat -anp TCP | Foreach-Object {"$($_)".Trim() -split "\s+" | Select-Object -Index 1} | Where-Object {$_ -match ":(\d+)$"} | Foreach-Object {[int]$Matches[1]} | Sort-Object -Unique
                            }
                        }
                    } catch {
                        Write-Log -Level Warn "Auto-Port failed for $($this.Name): $($_.Exception.Message)"
                    }
                }

                if ($PortsInUse) {
                    $portmax = [Math]::Min($this.Port+9999,65535)
                    while ($this.Port -le $portmax -and $PortsInUse.Contains($this.Port)) {$this.Port+=20}
                    if ($this.Port -gt $portmax) {$this.Port=$Miner_Port}
                }
            }

            Write-Log -Level Info "Start mining $($this.BaseAlgorithm[0]) on $($this.Pool[0])$(if ($this.BaseAlgorithm.Count -eq 2) {" and $($this.BaseAlgorithm[1]) on $($this.Pool[1])"}) with miner $($this.BaseName) using API on port $($this.Port)"

            $Device = Get-Device -Name $this.DeviceName
            $this.MemSizeGB = ($Device | Where-Object {$_.Type -eq "Gpu"} | Foreach-Object {$_.OpenCL.GlobalMemSizeGB} | Measure-Object -Maximum).Maximum

            $DeviceVendor = $this.GetVendor()

            $ArgumentList = $this.GetArguments()
            
            $Prescription = if ($this.EthPillEnable    -ne "disable" -and ($this.BaseAlgorithm -match "^Etc?hash|^UbqHash|^Verthash" | Measure-Object).Count) {$this.EthPillEnable}
                        elseif ($this.EthPillEnableMTP -ne "disable" -and (Compare-Object $this.BaseAlgorithm @("MTP")               -IncludeEqual -ExcludeDifferent | Measure-Object).Count) {$this.EthPillEnableMTP}

            if ($Prescription -and -not ($this.Name -match "^ClaymoreDual" -and $ArgumentList -match "-strap")) {
                $Prescription_Device = $Device | Where-Object {$_.Model_Base -in @("GTX1080","GTX1080Ti","TITANXP")}
                $Prescription = switch ($Prescription) {
                    "RevA" {"revA";Break}
                    "RevB" {"revB";Break}
                }
                if ("$Prescription" -ne "" -and $Prescription_Device) {
                    Write-Log "Starting OhGodAnETHlargementPill $($Prescription) on $($Prescription_Device.Name -join ',')"
                    if ($Global:IsLinux) {
                        $Command = ".\IncludesLinux\bin\OhGodAnETHlargementPill-r2"
                    } else {
                        $Command = ".\Includes\OhGodAnETHlargementPill-r2.exe"
                    }
                    $Command = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Command)
                    $this.EthPillJob = Start-SubProcess -FilePath $Command -ArgumentList "--$($Prescription) $($Prescription_Device.Type_Vendor_Index -join ',')" -WorkingDirectory (Split-Path $Command) -ShowMinerWindow $true -IsWrapper $false -ScreenName "ethpill_$($Prescription)_$($Prescription_Device.Type_Vendor_Index -join '_')" -Vendor $DeviceVendor -SetLDLIBRARYPATH -WinTitle "OhGodAnETHlargementPill-r2 --$($Prescription) $($Prescription_Device.Type_Vendor_Index -join ',')"
                    Start-Sleep -Milliseconds 250 #wait 1/4 second
                }
                $Prescription_Device = $null
            }

            $Now = Get-Date
            $this.StartTime = $Now.ToUniversalTime()
            $this.LogFile   = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\$($this.Name)-$($this.Port)_$($Now.ToString("yyyy-MM-dd_HH-mm-ss")).txt")
            $this.Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -CPUAffinity $this.Priorities.CPUAffinity -ShowMinerWindow $this.ShowMinerWindow -IsWrapper $this.IsWrapper() -EnvVars $this.EnvVars -MultiProcess $this.MultiProcess -Executables $this.Executables -ScreenName "$($this.DeviceName -join '_')" -BashFileName "start_$($this.DeviceName -join '_')_$($this.Pool -join '_')_$($this.BaseAlgorithm -join '_')" -Vendor $DeviceVendor -SetLDLIBRARYPATH:$this.SetLDLIBRARYPATH -WinTitle "$($this.Name -replace "-.+$") on $($this.DeviceModel) at $($this.Pool -join '+') with $($this.BaseAlgorithm -join '+')".Trim()

            if ($this.Job.XJob) {
                $this.Status = [MinerStatus]::Running
                if ($Global:IsLinux -and $this.IsWrapper()) {
                    Write-Log "Starting WrapperJob"
                    $this.WrapperJob = Start-Wrapper -ProcessId $this.GetProcessId() -LogPath $this.LogFile
                }
            }

            $Device = $null
        }
    }

    hidden StopMining() {
        $this.Status = [MinerStatus]::Failed

        $this.ResetMinerData()

        if ($this.Job) {
            Stop-SubProcess -Job $this.Job -Title "Miner $($this.Name)" -ShutdownUrl $this.GetShutdownUrl() -SkipWait:$this.SkipWaitOnShutDown

            $this.Active = $this.GetActiveTime()
            $this.Job    = $null
            $this.Status = [MinerStatus]::Idle
        }

        if ($this.EthPillJob) {
            Write-Log "Stopping OhGodAnETHlargementPill"
            Stop-SubProcess -Job $this.EthPillJob -Title "OhGodAnETHlargementPill" -SkipWait:$this.SkipWaitOnShutDown
            $this.EthPillJob = $null
        }

        if ($this.WrapperJob) {
            Write-Log "Stopping WrapperJob"
            if ($this.WrapperJob.State -eq "Running") {$this.WrapperJob | Stop-Job}
            $this.WrapperJob | Remove-Job -Force
            $this.WrapperJob = $null
        }

        if ($this.StopCommand) {try {Invoke-Expression $this.StopCommand} catch {Write-Log -Level Warn "StopCommand failed for miner $($this.Name)"}}
    }

    hidden StartMiningPreProcess() {
        $this.Stratum = @()
        while ($this.Stratum.Count -lt $this.Algorithm.Count) {$this.Stratum += [PSCustomObject]@{Accepted=0;Rejected=0;Stale=0;LastAcceptedTime=$null;LastRejectedTime=$null;LastStaleTime=$null}}
        $this.RejectedShareRatio = @(0.0) * $this.Algorithm.Count
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
        if ($Global:IsLinux -or ($this.API -notmatch "Wrapper")) {
            if ($this.Job.XJob.HasMoreData) {$this.Job.XJob | Receive-Job > $null}
        }
        if (($this.Speed_Live | Measure-Object -Sum).Sum) {$this.ZeroRounds = 0} else {$this.ZeroRounds++}
        $this.Rounds++
        $this.RunningTime = (Get-Date).ToUniversalTime() - $this.StartTime
    }

    [DateTime]GetActiveStart() {
        $MiningProcess = if ($this.Job.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime}
        $Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Job.XJob.PSBeginTime}

        if ($Begin) {
            return $Begin
        }
        else {
            return [DateTime]::MinValue
        }
    }

    [DateTime]GetActiveLast() {
        $MiningProcess = if ($this.Job.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime,ExitTime}

        if (-not $MiningProcess -and -not $this.Job.XJob) {
            return $this.ActiveLast
        }

        $Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Job.XJob.PSBeginTime}
        $End   = if ($MiningProcess) {$MiningProcess.ExitTime} else {$this.Job.XJob.PSEndTime}

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
        $MiningProcess = if ($this.Job.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime,ExitTime}
        $Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Job.XJob.PSBeginTime}
        $End   = if ($MiningProcess) {$MiningProcess.ExitTime} else {$this.Job.XJob.PSEndTime}
        
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

    [TimeSpan]GetRunningTime([Bool]$MeasureInterval = $false) {
        $MiningProcess = if ($this.Job.ProcessId) {Get-Process -Id $this.GetProcessId() -ErrorAction Ignore | Select-Object StartTime,ExitTime}
        $Begin = if ($MeasureInterval) {$this.IntervalBegin}
        if (-not $MeasureInterval -or $Begin -eq 0) {$Begin = if ($MiningProcess) {$MiningProcess.StartTime} else {$this.Job.XJob.PSBeginTime}}
        $End   = if ($MiningProcess) {$MiningProcess.ExitTime} else {$this.Job.XJob.PSEndTime}
        
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

    [TimeSpan]GetRunningTime() {
        return $this.GetRunningTime($false)
    }

    [MinerStatus]GetStatus() {
        $MiningProcess = $this.Job.ProcessId | Where-Object {$_} | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore}

        $WaitProc = $this.MultiProcess + 1

        if ((-not $MiningProcess -and $this.Job.XJob.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq $WaitProc)) {
            return [MinerStatus]::Running
        }
        elseif ($this.Status -eq [MinerStatus]::Running) {
            $this.Status = [MinerStatus]::RunningFailed
        }
        return $this.Status
    }

    [Int]GetProcessId() {
        return $this.Job.ProcessId | Select-Object -First 1
    }

    [Int[]]GetProcessIds() {
        return @($this.Job.ProcessId | Where-Object {$_} | Select-Object)
    }

    SetPriorities([int]$cpu=-2,[int]$gpu=-1,[string]$affinity="") {
        if ($cpu -lt -2) {$cpu=-2} elseif ($cpu -gt 3) {$cpu=3}
        if ($gpu -lt -2) {$gpu=-2} elseif ($gpu -gt 3) {$gpu=3}
        $this.Priorities.CPU = $cpu
        $this.Priorities.GPU = $gpu
        $this.Priorities.CPUAffinity = ConvertFrom-CPUAffinity $affinity -ToInt
    }

    SetStaticPort([int]$port=0) {
        $this.StaticPort = $port
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
                Break
            }
            Idle {
                $this.StopMiningPreProcess()
                $this.StopMining()
                $this.StopMiningPostProcess()
                Break
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
        $this.UpdateShares($Index,$Accepted,$Rejected,0)
    }

    UpdateShares([Int]$Index,[Double]$Accepted,[Double]$Rejected,[Double]$Stale) {
        if ($this.Stratum[$Index].Accepted -ne $Accepted) {$this.Stratum[$Index].LastAcceptedTime = Get-Date}
        if ($this.Stratum[$Index].Rejected -ne $Rejected) {$this.Stratum[$Index].LastRejectedTime = Get-Date}
        if ($this.Stratum[$Index].Stale -ne $Stale) {$this.Stratum[$Index].LastStaleTime = Get-Date}
        $this.Stratum[$Index].Accepted = $Accepted
        $this.Stratum[$Index].Rejected = $Rejected
        $this.Stratum[$Index].Stale = $Stale
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
        $MaxRatio = 0
        foreach($Algorithm in $this.Algorithm) {
            $Ratio = $this.GetRejectedShareRatio($Index,$minShares)
            if ($Ratio -gt $MaxRatio) {
                $MaxRatio = $Ratio
            }
            $Index++
        }
        return $MaxRatio
        #return ($this.Algorithm | Foreach-Object {$this.GetRejectedShareRatio($Index,$minShares);$Index++} | Measure-Object -Maximum).Maximum
    }

    [Double]GetMaxRejectedShareRatio() {
        return $this.GetMaxRejectedShareRatio(10)
    }

    [Bool]CheckShareRatio() {
        return $this.MaxRejectedShareRatio -le 0 -or $this.GetMaxRejectedShareRatio() -le $this.MaxRejectedShareRatio
    }

    [Int]GetLastAcceptedSeconds() {
        if ($this.Stratum[0].LastAcceptedTime) {
            return [int]((Get-Date) - $this.Stratum[0].LastAcceptedTime).TotalSeconds
        }
        return -1
    }

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $Date = (Get-Date).ToUniversalTime()

            $MJob | Receive-Job | ForEach-Object {
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
                                "kh/s*" {$HashRate *= 1E+3;Break}
                                "mh/s*" {$HashRate *= 1E+6;Break}
                                "gh/s*" {$HashRate *= 1E+9;Break}
                                "th/s*" {$HashRate *= 1E+12;Break}
                                "ph/s*" {$HashRate *= 1E+15;Break}
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

                        $this.AddMinerData($Line_Simple,[PSCustomObject]@{[String]$this.Algorithm[0] = $HashRates},$null,$null,$Devices)
                    }
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }

    AddMinerData($Raw,$HashRate,$Difficulty,$PowerDraw,$Devices) {
        [void]$this.Data.Add([PSCustomObject]@{
                Raw        = if ($Global:Session.LogLevel -eq "Debug") {$Raw} else {$null}
                HashRate   = $HashRate
                Difficulty = $Difficulty
                Devices    = $Devices
                Date       = (Get-Date).ToUniversalTime()
                PowerDraw  = if ($PowerDraw) {$PowerDraw} else {Get-DevicePowerDraw -DeviceName $this.DeviceName}
                Round      = $this.Rounds
            })
        $this.ActiveLast = Get-Date
    }

    AddMinerData($Raw,$HashRate) {
        $this.AddMinerData($Raw,$HashRate,$null,$null,$null)
    }

    AddMinerData($Raw,$HashRate,$Difficulty) {
        $this.AddMinerData($Raw,$HashRate,$Difficulty,$null,$null)
    }

    AddMinerData($Raw,$HashRate,$Difficulty,$PowerDraw) {
        $this.AddMinerData($Raw,$HashRate,$Difficulty,$PowerDraw,$null)
    }

    [Int]GetMinerDataCount() {
        return $this.Data.Count
    }

    CleanupMinerData() {
        if ($this.Data.Count -gt $this.MinSamples) {
            $DataMinTime = (Get-Date).ToUniversalTime().AddSeconds(-$this.DataInterval * [Math]::Max($this.ExtendInterval, 1) * 2)    
            for ($i = 0; $i -lt $this.Data.Count; $i++) {
                if ($this.Data[$i].Date -ge $DataMinTime -or ($this.Data.Count - $i) -le $this.MinSamples) { break }
            }
            if ($i -gt 0) { [void]$this.Data.RemoveRange(0, $i) }
        }
    }

    ResetMinerData() {
        if ($this.Data -eq $null) {
            $this.Data = [System.Collections.Generic.List[PSCustomObject]]::new()
        } else {
            [void]$this.Data.Clear()
        }
    }


    [Double]GetDifficulty([String]$Algorithm = [String]$this.Algorithm[0]) {
        $Intervals = [Math]::Max($this.ExtendInterval, 1)
        $Timeframe = (Get-Date).ToUniversalTime().AddSeconds(-$this.DataInterval * $Intervals)
        $AlgosDiffer = $Algorithm -match '-'
        $AlgorithmBase = $Algorithm -replace '\-.*$'

        $sum = 0
        $count = 0

        foreach ($item in $this.Data) {
            if ($item.Date -lt $Timeframe) { continue }

            if ($item.Difficulty -and ($item.Difficulty.$Algorithm -or ($AlgosDiffer -and $item.Difficulty.$AlgorithmBase))) {
                $diff = $item.Difficulty.$Algorithm
                if (-not $diff -and $AlgosDiffer) {
                    $diff = $item.Difficulty.$AlgorithmBase
                }

                if ($diff) {
                    $sum += $diff
                    $count++
                }
            }
        }

        if ($count -gt 0) { $sum /= $count }
        return $sum
    }

    [Double]GetCurrentDifficulty([String]$Algorithm = [String]$this.Algorithm[0]) {
        $AlgosDiffer = $Algorithm -match '-'
        $AlgorithmBase = $Algorithm -replace '\-.*$'

        for ($i = $this.Data.Count - 1; $i -ge 0; $i--) {
            $item = $this.Data[$i]

            if ($item.Difficulty -and ($item.Difficulty.$Algorithm -or ($AlgosDiffer -and $item.Difficulty.$AlgorithmBase))) {
                $diff = $item.Difficulty.$Algorithm
                if (-not $diff -and $AlgosDiffer) {
                    $diff = $item.Difficulty.$AlgorithmBase
                }

                if ($diff) {
                    return $diff
                }
            }
        }

        return 0
    }

    [Double]GetHashRate([String]$Algorithm = [String]$this.Algorithm[0],[Bool]$Safe = $true) {
        $AlgosDiffer = $Algorithm -match '-'
        $AlgorithmBase = $Algorithm -replace '\-.*$'


        if (($this.Data | Where-Object Device | Measure-Object).Count) {
            $HashRates_Devices = @($this.Data | Where-Object Device | Select-Object -ExpandProperty Device -Unique)
        } else {
            $HashRates_Devices = @("Device")
        }

        $Intervals = [Math]::Max($this.ExtendInterval,1)
        $Timeframe = (Get-Date).ToUniversalTime().AddSeconds( - $this.DataInterval * $Intervals)
        $HashData  = $this.Data | Where-Object {$_.HashRate -and ($_.HashRate.$Algorithm -or ($AlgosDiffer -and $_.HashRate.$AlgorithmBase)) -and ($_.Date -ge $Timeframe)}
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
                if (-not $Data_HashRates -and $AlgosDiffer) {$Data_HashRates = $_.HashRate.$AlgorithmBase}

                $Data_Devices = $_.Device
                if (-not $Data_Devices) {$Data_Devices = $HashRates_Devices}

                $HashRate = ($Data_HashRates | Measure-Object -Sum).Sum
                if ($HashRates_Variances."$($Data_Devices -join '-')" -or ($HashRate -gt $HashRates_Average * $MinHashRate)) {
                    $Data_Devices | ForEach-Object {$HashRates_Counts.$_++}
                    $Data_Devices | ForEach-Object {$HashRates_Averages.$_ += @($HashRate / $Data_Devices.Count)}
                    $HashRates_Variances."$($Data_Devices -join '-')" += @($HashRate)
                }
            }

            $HashRates_Count    = ($HashRates_Counts.Values | ForEach-Object {$_} | Measure-Object -Minimum).Minimum
            $HashRates_Average  = ($HashRates_Averages.Values | ForEach-Object {$_} | Measure-Object -Average).Average * $HashRates_Averages.Keys.Count
            $HashRates_Variance = if ($HashRates_Average -and $HashRates_Count -gt 2) {($HashRates_Variances.Keys | ForEach-Object {$_} | ForEach-Object {Get-Sigma $HashRates_Variances.$_} | Measure-Object -Maximum).Maximum / $HashRates_Average} else {1}
            Write-Log -Level Info "$($this.Name): GetHashrate $Algorithm #$($Step) smpl:$HashRates_Count, avg:$([Math]::Round($HashRates_Average,2)), var:$([Math]::Round($HashRates_Variance,3)*100)"
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
        $TimeFrame = (Get-Date).ToUniversalTime().AddSeconds(-$this.DataInterval * [Math]::Max($this.ExtendInterval, 1))
        $sum = 0
        $count = 0

        foreach ($item in $this.Data) {
            if ($item.PowerDraw -and $item.Date -ge $TimeFrame) {
                $sum += $item.PowerDraw
                $count++
            }
        }
        if ($count -gt 0) { $sum = [Math]::Round($sum / $count) }
        return $sum
    }

    [bool]HasDevFees() {
        return $this.DevFee -and ($this.Algorithm.PSObject.Properties.Value | Measure-Object -Sum).Sum
    }

    [array]GetDevFees() {
        return @($this.HashRates.PSObject.Properties.Name | Foreach-Object {$this.DevFee.$_})
    }

    [bool]HasOCprofile() {
        if ($this.EnableOCprofile) {foreach ($model in @($this.DeviceModel -split '-' | Select-Object)) {if ($this.OCProfile.$model) {return $true}}}
        return $false
    }

    [DateTime]GetLastSetOCTime() {
        return $this.LastSetOCTime
    }

    SetOCprofileValue([string]$DeviceModel,[string]$Feature,$value) {
        if ($this.OCprofileSet -eq $null) {$this.OCprofileSet = [PSCustomObject]@{}}
        if ($this.OCprofileSet.$DeviceModel -eq $null) {$this.OCprofileSet | Add-Member $DeviceModel ([PSCustomObject]@{}) -Force}
        if ($this.OCprofileSet.$DeviceModel.$Feature -eq $null) {$this.OCprofileSet.$DeviceModel | Add-Member $Feature $value -Force}
    }

    SetOCprofile($Config,[int]$Sleep=500) {

        $ApplyToAllPerformanceLevels = $Global:Session.Config.EnableOCLinuxSetAllPStates

        $this.LastSetOCTime = (Get-Date).ToUniversalTime()

        if (-not $this.HasOCprofile()) {return}

        [System.Collections.Generic.List[string]]$applied = @()
        [System.Collections.Generic.List[string]]$NvCmd = @()
        [System.Collections.Generic.List[string]]$NvSmiCmd = @()
        [System.Collections.Generic.List[string]]$AmdCmd = @()
        [System.Collections.Generic.List[string]]$IntelCmd = @()
        [System.Collections.Generic.List[object]]$RunCmd = @()

        $IsAfterburner = Test-Afterburner

        $DeviceVendor = $Global:GlobalCachedDevices | Where-Object {$this.OCprofile.ContainsKey($_.Model)} | Foreach-Object {$_.Vendor} | Select-Object -Unique

        if ($Global:IsWindows) {
            if ($DeviceVendor -ne "NVIDIA" -and $IsAfterburner) {
                try {
                    $Script:abMonitor.ReloadAll()
                    $Script:abControl.ReloadAll()
                } catch {
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

        if ($Config) {
            $this.Profiles = [PSCustomObject]@{}
            foreach ($DeviceModel in @($this.OCprofile.Keys)) {
                $x = Switch -Regex ($DeviceModel) {
                    "1050"      {2;Break}
                    "P106-?100" {2;Break}
                    "P106-?090" {1;Break}
                    "P104-?100" {1;Break}
                    "P102-?100" {1;Break}
                    "1650"      {4;Break}
                    "1660"      {4;Break}
                    "^RTX"      {4;Break}
                    default {3}
                }
                [System.Collections.Generic.List[int]]$DeviceIds = @()
                [System.Collections.Generic.List[string]]$CardIds   = @()
                $Global:GlobalCachedDevices | Where-Object Model -eq $DeviceModel | Foreach-Object {
                    $VendorIndex = $_.Type_Vendor_Index
                    $CardId = $_.CardId
                    $Id = if ($Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($_.Index)" -ne $null) {$_.Index} elseif ($Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($_.Name)" -ne $null) {$_.Name} elseif ($Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($_.OpenCL.PCIBusId)" -ne $null) {$_.OpenCL.PCIBusId}
                    if ($Id) {
                        $DeviceModelId = "$($DeviceModel)[$($Id)]"
                        $this.Profiles | Add-Member $DeviceModelId ([PSCustomObject]@{Index = [System.Collections.Generic.List[int]]@(); CardId = [System.Collections.Generic.List[string]]@(); Profile = $Config.OCProfiles."$($this.OCprofile.$DeviceModel)-$($Id)"; x = $x}) -Force
                        [void]$this.Profiles.$DeviceModelId.Index.Add($VendorIndex)
                        [void]$this.Profiles.$DeviceModelId.CardId.Add($CardId)
                    } else {
                        [void]$DeviceIds.Add($VendorIndex)
                        [void]$CardIds.Add($CardId)
                    }
                }
                if ($DeviceIds.Count -gt 0) {
                    $Profile = if ($Config.OCprofiles."$($this.OCprofile.$DeviceModel)-$($DeviceModel)" -ne $null) {$Config.OCprofiles."$($this.OCprofile.$DeviceModel)-$($DeviceModel)"} elseif ($Config.OCprofiles."$($this.OCprofile.$DeviceModel)" -ne $null) {$Config.OCprofiles."$($this.OCprofile.$DeviceModel)"} else {[PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;PriorizeThermalLimit = "0";MemoryClockBoost = "*";CoreClockBoost = "*";LockVoltagePoint = "*";LockMemoryClock = "*";LockCoreClock = "*"}}
                    if ($Profile) {
                        $this.Profiles | Add-Member $DeviceModel ([PSCustomObject]@{Index = $DeviceIds; CardId = $CardIds; Profile = $Profile; x = $x}) -Force
                    }
                }
            }
        }

        foreach ($DeviceModel in @($this.Profiles.PSObject.Properties.Name | Select-Object)) {
            if (-not $Config) {
                $Profile = [PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;PriorizeThermalLimit = "0";MemoryClockBoost = "";CoreClockBoost = "";LockVoltagePoint = "";LockMemoryClock = "";LockCoreClock = ""}
                if ($Global:Session.Config.EnableOCFullReset) {
                    $Profile.MemoryClockBoost = $Profile.CoreClockBoost = $Profile.LockVoltagePoint = $Profile.LockMemoryClock = $Profile.LockCoreClock = "0"
                } elseif ($this.OCprofileSet.$DeviceModel) {
                    $this.OCprofileSet.$DeviceModel.PSObject.Properties.Name | Where-Object {$Profile.$_ -ne $null -and $Profile.$_ -eq ""} | Foreach-Object {$Profile.$_ = "0"}
                }
                if ($this.Profiles.$DeviceModel.Profile.PostCmd) {
                    [void]$RunCmd.Add([PSCustomObject]@{FilePath = $this.Profiles.$DeviceModel.Profile.PostCmd;ArgumentList=$this.Profiles.$DeviceModel.Profile.PostCmdArguments})
                }
                $this.OCprofileSet = $null
            } else {
                $Profile = $this.Profiles.$DeviceModel.Profile

                $Profile.CoreClockBoost   = $Profile.CoreClockBoost -replace '[^0-9\-]+'
                $Profile.MemoryClockBoost = $Profile.MemoryClockBoost -replace '[^0-9\-]+'
                $Profile.LockVoltagePoint = $Profile.LockVoltagePoint -replace '[^0-9]+'
                $Profile.LockMemoryClock  = $Profile.LockMemoryClock -replace '[^0-9]+'
                $Profile.LockCoreClock    = $Profile.LockCoreClock -replace '[^0-9]+'

                if ($Profile.PreCmd) {
                    [void]$RunCmd.Add([PSCustomObject]@{FilePath = $Profile.PreCmd;ArgumentList=$Profile.PreCmdArguments})
                }
            }

            if (-not $Config.EnableOCVoltage) {$Profile.LockVoltagePoint = ''}

            $applied_any = $false

            if ($DeviceVendor -eq "NVIDIA") {

                foreach($DeviceId in $this.Profiles.$DeviceModel.Index) {
                    if ($Profile.PowerLimit -gt 0) {$val=[Math]::Max([Math]::Min($Profile.PowerLimit,200),20);if ($Global:IsLinux) {Set-NvidiaPowerLimit $DeviceId $val} else {[void]$NvCmd.Add("-setPowerTarget:$($DeviceId),$($val)")};$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"PowerLimit",$val)}}
                    if (-not $Global:IsLinux) {
                        if ($Profile.ThermalLimit -gt 0) {$val=[Math]::Max([Math]::Min($Profile.ThermalLimit,95),50);[void]$NvCmd.Add("-setTempTarget:$($DeviceId),$(if (Get-Yes $Profile.PriorizeThermalLimit) {"1"} else {"0"}),$($val)");$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"ThermalLimit",$val);$this.SetOCprofileValue($DeviceModel,"PriorizeThermalLimit",(Get-Yes $Profile.PriorizeThermalLimit))}}
                        if ($Profile.LockVoltagePoint-match '^\-*[0-9]+$') {$val=[int]([Convert]::ToInt32($Profile.LockVoltagePoint)/12500)*12500;[void]$NvCmd.Add("-lockVoltagePoint:$($DeviceId),$($val)");$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"LockVoltagePoint",$val)}}
                    } else {
                        [void]$NvCmd.Add("-a '[gpu:$($DeviceId)]/GPUPowerMizerMode=1'")
                    }
                    if ($Profile.CoreClockBoost -match '^\-*[0-9]+$') {$val=[Convert]::ToInt32($Profile.CoreClockBoost);[void]$NvCmd.Add("$(if ($Global:IsLinux) {
                        if ($ApplyToAllPerformanceLevels) {"-a '[gpu:$($DeviceId)]/GPUGraphicsClockOffsetAllPerformanceLevels=$($val)'"}
                        else {"-a '[gpu:$($DeviceId)]/GPUGraphicsClockOffset[$($this.Profiles.$DeviceModel.x)]=$($val)'"}} else {"-setBaseClockOffset:$($DeviceId),0,$($val)"})")
                        $applied_any=$true
                        if ($Config) {$this.SetOCprofileValue($DeviceModel,"CoreClockBoost",$val)}
                    }
                    if ($Profile.MemoryClockBoost -match '^\-*[0-9]+$') {$val = [Convert]::ToInt32($Profile.MemoryClockBoost);[void]$NvCmd.Add("$(if ($Global:IsLinux) {
                        if ($ApplyToAllPerformanceLevels) {"-a '[gpu:$($DeviceId)]/GPUMemoryTransferRateOffsetAllPerformanceLevels=$($val)'"}
                        else{"-a '[gpu:$($DeviceId)]/GPUMemoryTransferRateOffset[$($this.Profiles.$DeviceModel.x)]=$($val)'"}} else {"-setMemoryClockOffset:$($DeviceId),0,$($val)"})")
                        $applied_any=$true
                        if ($Config) {$this.SetOCprofileValue($DeviceModel,"MemoryClockBoost",$val)}
                    }
                    if ($Profile.LockCoreClock -match '^[0-9]+$') {[void]$NvSmiCmd.Add("-i $($DeviceId) $(if ($Profile.LockCoreClock -eq 0) {"-rgc"} else {"-lgc $($Profile.LockCoreClock)"})");if ($Config) {$this.SetOCprofileValue($DeviceModel,"LockCoreClock",$Profile.LockCoreClock)}}
                    if ($Profile.LockMemoryClock -match '^[0-9]+$') {[void]$NvSmiCmd.Add("-i $($DeviceId) $(if ($Profile.LockMemoryClock -eq 0) {"-rmc"} else {"-lmc $($Profile.LockMemoryClock)"})");if ($Config) {$this.SetOCprofileValue($DeviceModel,"LockMemoryClock",$Profile.LockMemoryClock)}}
                }

            } elseif ($DeviceVendor -eq "AMD" -and $Global:IsLinux) {

                foreach($CardId in $this.Profiles.$DeviceModel.CardId) {
                    #if ($Profile.PowerLimit -gt 0) {$val=[Math]::Max([Math]::Min($Profile.PowerLimit,200),20);if ($Global:IsLinux) {Set-NvidiaPowerLimit $DeviceId $val} else {[void]$NvCmd.Add("-setPowerTarget:$($DeviceId),$($val)")};$applied_any=$true}
                }
            
            } elseif ($Pattern.$DeviceVendor -ne $null) {
                if ($IsAfterburner) {
                    $DeviceId = 0
                    $Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$DeviceVendor | Select-Object -ExpandProperty Index | Foreach-Object {
                        if ($DeviceId -in $this.Profiles.$DeviceModel.Index) {
                            $GpuEntry = $Script:abControl.GpuEntries[$_]
                            try {if (-not ($GpuEntry.PowerLimitMin -eq 0 -and $GpuEntry.PowerLimitMax -eq 0) -and $Profile.PowerLimit -gt 0) {$Script:abControl.GpuEntries[$_].PowerLimitCur = [Math]::Max([Math]::Min($Profile.PowerLimit,$GpuEntry.PowerLimitMax),$GpuEntry.PowerLimitMin);$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"PowerLimit",$Script:abControl.GpuEntries[$_].PowerLimitCur)}}} catch {Write-Log -Level Warn $_.Exception.Message}
                            try {if (-not ($GpuEntry.ThermalLimitMin -eq 0 -and $GpuEntry.ThermalLimitMax -eq 0) -and $Profile.ThermalLimit -gt 0) {$Script:abControl.GpuEntries[$_].ThermalLimitCur = [Math]::Max([Math]::Min($Profile.ThermalLimit,$GpuEntry.ThermalLimitMax),$GpuEntry.ThermalLimitMin);$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"ThermalLimit",$Script:abControl.GpuEntries[$_].ThermalLimitCur)}}} catch {Write-Log -Level Warn $_.Exception.Message}
                            try {if (-not ($GpuEntry.CoreClockBoostMin -eq 0 -and $GpuEntry.CoreClockBoostMax -eq 0) -and $Profile.CoreClockBoost -match '^\-*[0-9]+$') {$Script:abControl.GpuEntries[$_].CoreClockBoostCur = [Math]::Max([Math]::Min([convert]::ToInt32($Profile.CoreClockBoost) * 1000,$GpuEntry.CoreClockBoostMax),$GpuEntry.CoreClockBoostMin);$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"CoreClockBoost",$Script:abControl.GpuEntries[$_].CoreClockBoostCur)}}} catch {Write-Log -Level Warn $_.Exception.Message}
                            try {if (-not ($GpuEntry.MemoryClockBoostMin -eq 0 -and $GpuEntry.MemoryClockBoostMax -eq 0) -and $Profile.MemoryClockBoost -match '^\-*[0-9]+$') {$Script:abControl.GpuEntries[$_].MemoryClockBoostCur = [Math]::Max([Math]::Min([convert]::ToInt32($Profile.MemoryClockBoost) * 1000,$GpuEntry.MemoryClockBoostMax),$GpuEntry.MemoryClockBoostMin);$applied_any=$true;if ($Config) {$this.SetOCprofileValue($DeviceModel,"MemoryClockBoost",$Script:abControl.GpuEntries[$_].MemoryClockBoostCur)}}} catch {Write-Log -Level Warn $_.Exception.Message}
                            if ($Profile.LockVoltagePoint -match '^\-*[0-9]+$') {Write-Log -Level Warn "$DeviceModel does not support LockVoltagePoint overclocking"}
                        }
                        $DeviceId++
                    }
                }
            }
            if ($applied_any) {[void]$applied.Add("OC set for $($this.BaseName)-$($DeviceModel)-$($this.BaseAlgorithm -join '-'): PL=$(if ($Profile.PowerLimit) {"$($Profile.PowerLimit)%"} else {"-"}), TL=$(if ($Profile.ThermalLimit) {"$($Profile.ThermalLimit)°C"} else {"-"}), PRIO=$(if (Get-Yes $Profile.PriorizeThermalLimit) {"TL"} else {"PL"}), MEMboost=$(if ($Profile.MemoryClockBoost -ne '') {"$($Profile.MemoryClockBoost)"} else {"-"}), COREboost=$(if ($Profile.CoreClockBoost -ne '') {"$($Profile.CoreClockBoost)"} else {"-"}), MEMlock=$(if ($Profile.LockMemoryClock -ne '') {"$($Profile.LockMemoryClock)"} else {"-"}), CORElock=$(if ($Profile.LockCoreClock -ne '') {"$($Profile.LockCoreClock)"} else {"-"}), LVP=$(if ($Profile.LockVoltagePoint -ne '') {"$($Profile.LockVoltagePoint)µV"} else {"-"})")}
        }

        if ($RunCmd.Count) {
            $CmdInfo = "$(if ($Config) {"prerun"} else {"postrun"})"
            foreach($Cmd in $RunCmd) {
                Write-Log -Level Info "Miner $($this.Name) $($CmdInfo): $($Cmd.FilePath) $($Cmd.ArgumentList)"
                $CmdJob = Start-SubProcess -FilePath $Cmd.FilePath -ArgumentList $Cmd.ArgumentList -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -ShowMinerWindow $true -SetLDLIBRARYPATH:$this.SetLDLIBRARYPATH
                if ($CmdJob.XJob) {
                    $wait = 0
                    While ($wait -lt 300) {
                        Start-Sleep -Milliseconds 100
                        $CmdProcess = $CmdJob.ProcessId | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore | Select-Object Id,HasExited}
                        if ((-not $CmdProcess -and $CmdJob.XJob.State -eq "Running") -or ($CmdProcess -and ($CmdProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq 1)) {$wait++} else {break}
                    }
                }
                Stop-SubProcess -Job $CmdJob -Title "Miner $($this.Name) ($($CmdInfo))"

                $CmdJob = $null
                Remove-Variable -Name CmdJob -ErrorAction Ignore
            }
        }

        if ($applied.Count) {
            try {
                if ($Sleep -gt 0) {Start-Sleep -Milliseconds $Sleep}
                if ($DeviceVendor -eq "NVIDIA") {
                    Invoke-NvidiaSettings $NvCmd
                    if ($Global:IsLinux -or (Test-IsElevated)) {
                        $NvSmiCmd | Foreach-Object {Invoke-NvidiaSmi -Arguments $_ -Runas > $null}
                    }
                } elseif ($DeviceVendor -eq "AMD" -and $AmdCmd.Count) {
                    #t.b.i
                } elseif ($DeviceVendor -eq "INTEL" -and $IntelCmd.Count) {
                    #t.b.i
                } elseif ($IsAfterburner) {
                    $Script:abControl.CommitChanges()
                }
                $applied | Foreach-Object {Write-Log -Level Info $_}
                if ($Sleep -gt 0) {Start-Sleep -Milliseconds $Sleep}
            } catch {
                Write-Log -Level Warn "Failed to apply OC for $($this.Name))!"
                $applied | Foreach-Object {Write-Log -Level Info "$($_ -replace "OC set","OC NOT set")"}
            }
        }
    }

    ResetOCprofile([int]$Sleep=500) {
        if ($this.HasOCprofile()) {
            $this.SetOCprofile($null,$Sleep)
            Write-Log "OC reset for $($this.BaseName)"
        }
        $this.OCprofileSet = $null
    }
}



class BMiner : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api/v1/status/solver" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        try {
            $Data2 = Invoke-TcpRequest "http://$($Server):$($this.Port)/api/v1/status/stratum" -Timeout $Timeout
            $Data | Add-member stratums $Data2.stratums
        }
        catch {
        }

        $Index = 0
        $this.Algorithm | Select-Object -Unique | ForEach-Object {
            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix

            $HashRate_Value = 0.0

            $Data.devices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
                $Data.devices.$_.solvers | Where-Object {$HashRate_Name -like "$(Get-Algorithm $_.Algorithm)*"} | ForEach-Object {
                    if ($_.speed_info.hash_rate) {$HashRate_Value += [Double]$_.speed_info.hash_rate}
                    else {$HashRate_Value += [Double]$_.speed_info.solution_rate}
                }
            }
            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

                $Accepted_Shares = [Int64]$Data.stratums.$_.accepted_shares
                $Rejected_Shares = [Int64]$Data.stratums.$_.rejected_shares
                $this.UpdateShares($Index,$Accepted_Shares,$Rejected_Shares)
            }
            $Index++
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}

class BzMiner : Miner {

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/status" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $Count = $this.Algorithm.Count
        if ($Data.pools.Count -gt $Count -and $Data.pools[$Data.pools.Count-1].algorithm -eq "zil") {$Count++}

        $Devices = $Data.devices | Where-Object {$_.status.Count -eq $Count -and $_.hashrate.Count -eq $Count -and $_.status[0] -eq 3} | Select-Object

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [double]($Devices | Foreach-Object {$_.hashrate[0]} | Measure-Object -Sum).Sum

        $PowerDraw      = [Double]($Devices | Foreach-Object {$_.power} | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]($Devices | Foreach-Object {$_.valid_solutions[0]} | Measure-Object -Sum).Sum
            $Rejected_Shares = [Int64]($Devices | Foreach-Object {$_.rejected_solutions[0]} | Measure-Object -Sum).Sum
            $Stale_Shares    = [Int64]($Devices | Foreach-Object {$_.stale_solutions[0]} | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)

            if ($this.Algorithm[1]) {
                $HashRate_Name = [String]$this.Algorithm[1]
                $HashRate_Value = [double]($Devices | Foreach-Object {$_.hashrate[1]} | Measure-Object -Sum).Sum

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

                    $Accepted_Shares = [Int64]($Devices | Foreach-Object {$_.valid_solutions[1]} | Measure-Object -Sum).Sum
                    $Rejected_Shares = [Int64]($Devices | Foreach-Object {$_.rejected_solutions[1]} | Measure-Object -Sum).Sum
                    $Stale_Shares    = [Int64]($Devices | Foreach-Object {$_.stale_solutions[1]} | Measure-Object -Sum).Sum
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)
                }
            }
        }

        $this.AddMinerData("",$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class Cast : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]$Data.shares.num_accepted
            $Rejected_Shares = [Int64]($Data.shares.num_rejected + $Data.shares.num_rejected + $Data.shares.num_network_fail + $Data.shares.num_outdated)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class Ccminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = "summary"
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        #$Difficulty = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response -split ";" | ConvertFrom-StringData -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = if ($Data.HS -ne $null -and [Double]$Data.HS -gt [Double]$Data.KHS) {[Double]$Data.HS} else {[Double]$Data.KHS * 1000}

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            #$Difficulty_Value = [Double]$Data.DIFF
            #$Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}
    
            $Accepted_Shares = [Int64]($Data.ACC | Measure-Object -Sum).Sum
            $Rejected_Shares = [Int64]($Data.REJ | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)
        #$this.AddMinerData($Response,$HashRate,$Difficulty) too bad! Ccminer shows network diff and not share diff

        $this.CleanupMinerData()
    }
}


class Claymore : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server   = "127.0.0.1" #"localhost"
        $Timeout  = 10 #seconds

        $Request  = '{"id":1,"jsonrpc":"2.0","method":"miner_getstat1"}'
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            if (-not $Data -or -not $Data.result -or -not $Data.result[2]) {throw}
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name    = [String]$this.Algorithm[0]
        $HashRate_Value   = [Double]($Data.result[2] -split ";")[0]

        if ($this.Algorithm -match "^ethash|^etchash|^firopow|^kawpow|^neoscrypt|^ubqhash|progpow|^sccpow" -and $Data.result[0] -notmatch "^TT-Miner") {$HashRate_Value *= 1000}

        $HashRate_Value = [Int64]$HashRate_Value

        $PowerDraw      = if ($Data.result[9]) {("$($Data.result[9])" -split ";" | Foreach-Object {[Double]$_} | Measure-Object -Sum).Sum}
            
        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares  = [Int64]($Data.result[2] -split ";")[1]
            $Rejected_Shares  = [Int64]($Data.result[2] -split ";")[2]
            $Accepted_Shares -= $Rejected_Shares
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        if ($this.Algorithm[1]) {
            $HashRate_Name = [String]$this.Algorithm[1]

            $HashRate_Value = [Double]($Data.result[4] -split ";")[0]

            if ($this.Algorithm -match "^ethash|^etchash|^kawpow|^neoscrypt|progpow|^sccpow" -and $Data.result[0] -notmatch "^TT-Miner") {$HashRate_Value *= 1000}

            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

                $Accepted_Shares = [Int64]($Data.result[4] -split ";")[1]
                $Rejected_Shares = [Int64]($Data.result[4] -split ";")[2]
                $Accepted_Shares -= $Rejected_Shares
                $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
            }
        }

        $this.AddMinerData($Response,$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class CryptoDredge : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1"
        $Timeout = 10 #seconds

        $Request = "summary"
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -DoNotSendNewline -ErrorAction Stop -Quiet
            $Data = $Response -split ";" | ConvertFrom-StringData -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.KHS * 1000

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]($Data.ACC | Measure-Object -Sum).Sum
            $Rejected_Shares = [Int64]($Data.REJ | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class Dstm : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; method = "getstat"} | ConvertTo-Json -Depth 10 -Compress
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.result.sol_ps | Measure-Object -Sum).Sum
        if (-not $HashRate_Value) {$HashRate_Value = [Double]($Data.result.speed_sps | Measure-Object -Sum).Sum} #ewbf fix
        
        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Double]($Data.result.accepted_shares | Measure-Object -Sum).Sum
            $Rejected_Shares = [Double]($Data.result.rejected_shares | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}

class DynexsolveWrapper : Miner {

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple -match "\[GPU \*\].+ HASHRATE ([\d\s\./hkMGTPs]+?) \|") {
                    $Words = "$($Matches[1])".Trim() -split "\s+"

                    $HashRate = [PSCustomObject]@{}

                    $HashRate_Value = [Double]"$($Words[0] -replace "[^\d\.]+")"

                    switch -Regex ($Words[1]) {
                        "k" {$HashRate_Value *= 1E+3}
                        "M" {$HashRate_Value *= 1E+6}
                        "G" {$HashRate_Value *= 1E+9}
                        "T" {$HashRate_Value *= 1E+12}
                        "P" {$HashRate_Value *= 1E+15}
                    }

                    if ($HashRate_Value -gt 0) {
                        $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                    }

                    $this.AddMinerData($Line_Simple,$HashRate)
                } elseif ($Line_Simple -match "POOL.+?\((\d+)/(\d+)[/)]") {                
                    $Accepted_Shares = [Int64]$Matches[1]
                    $Rejected_Shares    = [Int64]$Matches[2]
                    $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                } elseif ($Line_Simple -match "GPU\s+(\d+):\s+has\s+timed\sout") {
                    #GPU has crashed, restart miner
                    Write-Log -Level Warn "$($this.Name): GPU $($Matches[1]) has timed out - restarting miner"
                    $this.Restart = $true
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class Eminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api/v1/stats" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }
        
        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.total_hashrate_mean | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Double]$Data.found_solutions
            $Rejected_Shares = [Double]($Data.invalid_solutions + $Data.rejected_solutions)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class EnemyZ : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/summary?gpuinfo=1" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]

        $PowerDraw      = [Double]($Data.gpus.power | Measure-Object -Sum).Sum / 1e3

        $HashRate_Value   = [Double]$Data.hashrate
        $HashRateGPUs_Value = [Double]($Data.gpus.hashrate | Measure-Object -Sum).Sum
        if ($HashRate_Value -le $HashRateGPUs_Value*0.6) {
            $HashRate_Value = $HashRateGPUs_Value
        }

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.pool_difficulty
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Int64]$Data.accepted_count
            $Rejected_Shares  = [Int64]$Data.rejected_count
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class Ethminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server   = "127.0.0.1" #"localhost"
        $Timeout  = 10 #seconds

        $Request  = '{"id":1,"jsonrpc":"2.0","method":"miner_getstatdetail"}'
        $Response = ""

        $HashRate = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            if (-not $Data -or -not $Data.result) {throw}
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name    = [String]$this.Algorithm[0]
        $HashRate_Value   = [Int64]$Data.result.mining.hashrate

        $Difficulty | Add-Member @{$HashRate_Name = [Double]$Data.result.mining.difficulty}

        $PowerDraw      = ($Data.result.devices | Foreach-Object {[Double]$_.hardware.sensors[2]} | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares  = [Int64]$Data.result.mining.shares[0]
            $Rejected_Shares  = [Int64]$Data.result.mining.shares[1]
            $Accepted_Shares -= $Rejected_Shares
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class EthminerWrapper : Miner {
    [Double]$Difficulty_Value = 0.0

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple) {
                    if ($Line_Simple -match "^\s+i\s+.+?Difficulty\s*:\s*([\d\.\,]+?)\s*([hkMGT]+)") {
                        $this.Difficulty_Value  = [double]($Matches[1] -replace ',','.') * $(Switch ($Matches[2]) {
                            "Th" {1e12}
                            "Gh" {1e9}
                            "Mh" {1e6}
                            "kh" {1e3}
                            default {1}
                        })
                    } elseif ($Line_Simple -match "^\s+m\s+(.+)$") {
                        $Line_Cols = $Matches[1] -split '\s+'
                        $HashRate   = [PSCustomObject]@{}
                        $Difficulty = [PSCustomObject]@{}

                        $HashRate_Value  = [double]($Line_Cols[4] -replace ',','.') * $(Switch ($Line_Cols[5]) {
                            "Th" {1e12}
                            "Gh" {1e9}
                            "Mh" {1e6}
                            "kh" {1e3}
                            default {1}
                        })

                        if ($HashRate_Value -gt 0) {
                            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
                            $Difficulty | Add-Member @{$HashRate_Name = $this.Difficulty_Value}

                            $Accepted_Shares = [Int64]$(if ($Line_Cols[3] -match "A(\d+)") {$Matches[1]})
                            $Rejected_Shares = [Int64]0
                            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                        }

                        $this.AddMinerData($Line_Simple,$HashRate,$Difficulty)
                    }
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}


class Fireice : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Miner_Path       = Split-Path $this.Path
        $Parameters       = $Arguments | ConvertFrom-Json
        $Miner_Vendor     = $Parameters.Vendor
        $ConfigFN         = "common_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)-$($Parameters.Config.httpd_port).txt"
        $PoolConfigFN     = "pool_$($this.Pool -join'-')-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($Parameters.Pools[0].use_tls){"-ssl"}).txt"
        $HwConfigFN       = "config_$($Miner_Vendor.ToLower())-$(($Global:Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $this.DeviceModel | Select-Object -ExpandProperty Name | Sort-Object) -join '-').txt"
        $DeviceConfigFN   = "$($Miner_Vendor.ToLower())_$($this.BaseAlgorithm -join '-')-$($this.DeviceName -join '-').txt"
        $LegacyDeviceConfigFN = "$($Miner_Vendor.ToLower())-$($this.BaseAlgorithm -join '-').txt"

        $PoolConfigFile   = Join-Path $Miner_Path $PoolConfigFN
        $ConfigFile       = Join-Path $Miner_Path $ConfigFN
        $HwConfigFile     = Join-Path $Miner_Path $HwConfigFN
        $DeviceConfigFile = Join-Path $Miner_Path $DeviceConfigFN
        $LegacyDeviceConfigFile = Join-Path $Miner_Path $LegacyDeviceConfigFN

        if ($Parameters.Config.httpd_port) {$Parameters.Config.httpd_port = $this.Port}
        ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content $ConfigFile -ErrorAction Ignore -Encoding UTF8 -Force
        ($Parameters.Pools  | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$","," | Set-Content $PoolConfigFile -ErrorAction Ignore -Encoding UTF8 -Force
                
        try {
            if (Test-Path $HwConfigFile) {
                try {
                    Get-Content $HwConfigFile -Raw | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-Log -Level Warn "Bad json file found ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) - creating a new one"
                    Remove-Item $HwConfigFile -ErrorAction Ignore -Force
                }
            }
            if (-not (Test-Path $HwConfigFile)) {
                Remove-Item "$Miner_Path\config_$($Miner_Vendor.ToLower())-*.txt" -Force -ErrorAction Ignore
                $ArgumentList = "--poolconf $PoolConfigFN --config $ConfigFN --$($Miner_Vendor.ToLower()) $HwConfigFN $($Parameters.Params)".Trim()
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -LogPath $this.LogFile -WorkingDirectory $Miner_Path -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper") -Executables $this.Executables -SetLDLIBRARYPATH:$this.SetLDLIBRARYPATH
                if ($Job.XJob) {
                    $wait = 0
                    While ($wait -lt 60) {
                        if (Test-Path $HwConfigFile) {
                            $ThreadsConfigJson = "{$((Get-Content $HwConfigFile -Raw) -replace '(?ms)/\*.+\*/' -replace '//.*' -replace '\s' -replace '"bfactor":\d+,','"bfactor":8,' -replace ',}','}' -replace ',]',']' -replace ',$')}" | ConvertFrom-Json
                            if ($Miner_Vendor -eq "GPU") {
                                $ThreadsConfigJson | Add-Member gpu_threads_conf @($ThreadsConfigJson.gpu_threads_conf | Sort-Object -Property Index -Unique) -Force
                            }
                            $ThreadsConfigJson | ConvertTo-Json -Depth 10 | Set-Content $HwConfigFile -Force
                            break
                        }
                        Start-Sleep -Milliseconds 500
                        $MiningProcess = $Job.ProcessId | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore | Select-Object Id,HasExited}
                        if ((-not $MiningProcess -and $Job.XJob.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq 1)) {$wait++} else {break}
                    }
                }
                if ($Job) {
                    Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"

                    $Job = $null
                    Remove-Variable -Name Job -ErrorAction Ignore
                }
            }

            if (-not (Test-Path $DeviceConfigFile)) {
                if (Test-Path $LegacyDeviceConfigFile) {$HwConfigFN = $LegacyDeviceConfigFN;$HwConfigFile = $LegacyDeviceConfigFile}

                $ThreadsConfigJson = Get-Content $HwConfigFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($Miner_Vendor -eq "CPU") {
                    if ($Parameters.Affinity -ne $null) {
                        $FirstCpu = $ThreadsConfigJson.cpu_threads_conf | Select-Object -First 1 | ConvertTo-Json -Depth 10 -Compress
                        $ThreadsConfigJson | Add-Member cpu_threads_conf ([Array]($Parameters.Affinity | Foreach-Object {$FirstCpu | ConvertFrom-Json | Add-Member affine_to_cpu $_ -Force -PassThru}) * $Parameters.Threads) -Force
                    } else {
                        $ThreadsConfigJson | Add-Member cpu_threads_conf ([Array]$ThreadsConfigJson.cpu_threads_conf * $Parameters.Threads) -Force
                    }
                } else {
                    $ThreadsConfigJson | Add-Member gpu_threads_conf ([Array]($ThreadsConfigJson.gpu_threads_conf | Where-Object {$Parameters.Devices -contains $_.Index}) * $Parameters.Threads) -Force
                }
                ($ThreadsConfigJson | ConvertTo-Json -Depth 10) -replace '^{' -replace '}$' | Set-Content $DeviceConfigFile -Force
            }
        }
        catch {
            Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
        }

        return "--poolconf $PoolConfigFN --config $ConfigFN --$($Miner_Vendor.ToLower()) $DeviceConfigFN $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api.json" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.results.diff_current
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Double]$Data.results.shares_good
            $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}


class Gminer : Miner {

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/stat" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        #$Version = if ($Data.miner -match "(\d\.[\d\.]+)") {$Matches[1]} else {$null}

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.speed | Measure-Object -Sum).Sum

        $PowerDraw      = [Double]($Data.devices.power_usage | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            #if ($HashRate_Name -eq "Eaglesong" -and $Version -ne $null -and [version]$Version -le [version]"1.77") {$HashRate_Value /= 2}
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]($Data.devices.accepted_shares | Measure-Object -Sum).Sum
            $Rejected_Shares = [Int64]($Data.devices.rejected_shares | Measure-Object -Sum).Sum
            $Stale_Shares    = [Int64]($Data.devices.stale_shares | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)

            if ($this.Algorithm[1]) {
                $HashRate_Name = [String]$this.Algorithm[1]
                $HashRate_Value = [Double]($Data.devices.speed2 | Measure-Object -Sum).Sum

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

                    $Accepted_Shares = [Int64]($Data.devices.accepted_shares2 | Measure-Object -Sum).Sum
                    $Rejected_Shares = [Int64]($Data.devices.rejected_shares2 | Measure-Object -Sum).Sum
                    $Stale_Shares    = [Int64]($Data.devices.stale_shares2 | Measure-Object -Sum).Sum
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)
                }
            }
        }

        $this.AddMinerData("",$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class GrinPro : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Parameters = $Arguments | ConvertFrom-Json

        $ConfigPath = Join-Path $([IO.Path]::GetFullPath($this.Path) | Split-Path) "$($this.Pool -join '-')-$($this.DeviceModel)$(if ($Parameters.SSL){"-ssl"})"

        if (Test-Path $this.Path) {
            if (-not (Test-Path $ConfigPath)) {New-Item $ConfigPath -ItemType "directory" > $null}
            "<?xml version=`"1.0`" encoding=`"utf-8`"?>
<Config xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
  <PrimaryConnection>
    <ConnectionAddress>$($Parameters.Config.Host)</ConnectionAddress>
    <ConnectionPort>$($Parameters.Config.Port)</ConnectionPort>
    <Ssl>$(if ($Parameters.Config.SSL) {"true"} else {"false"})</Ssl>
    <Login>$($Parameters.Config.User)</Login>
    <Password>$($Parameters.Config.Pass)</Password>  
  </PrimaryConnection>
  <SecondaryConnection>
  </SecondaryConnection>
  <LogOptions>
    <FileMinimumLogLevel>WARNING</FileMinimumLogLevel>
    <ConsoleMinimumLogLevel>INFO</ConsoleMinimumLogLevel>
    <KeepDays>1</KeepDays>
    <DisableLogging>false</DisableLogging>
  </LogOptions>
  <CPUOffloadValue>0</CPUOffloadValue>
  <GPUOptions>$($Parameters.Device | Foreach-Object {"
    <GPUOption>
        <GPUName>$($_.Name)</GPUName>
        <GPUType>$($_.Vendor)</GPUType>
        <DeviceID>$($_.Index)</DeviceID>
        <PlatformID>$($_.PlatformId)</PlatformID>
        <Enabled>true</Enabled>
    </GPUOption>"})
  </GPUOptions>
</Config>" | Out-File "$($ConfigPath)\config.xml" -Encoding utf8
        }

        return "configpath=$ConfigPath $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api/status" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.workers | Where-Object status -eq "ONLINE" | Select-Object -ExpandProperty graphsPerSecond | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]$Data.shares.accepted
            $Rejected_Shares = [Int64]($Data.shares.submitted - $Data.shares.accepted)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class Jceminer : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Parameters = $Arguments | ConvertFrom-Json

        $Params = ""
        if ($Parameters.Config -ne $null) {
            #Write config files. Keep separate files and do not overwrite to preserve optional manual customization

            if ($this.DeviceModel -match "CPU") {
                $ConfigFile = "config_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).txt"
                $ConfigFileExample = "config_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).example.txt"
            } else {
                $ConfigFile = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).txt"
                $ConfigFileExample = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).example.txt"                
            }

            if (-not (Test-Path "$(Split-Path $this.Path)\$ConfigFile") -and $this.DeviceModel -match "CPU") {
                ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{\s*" -replace "\s*}$" | Set-Content "$(Split-Path $this.Path)\$ConfigFile" -ErrorAction Ignore -Encoding UTF8
            }
            ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{\s*" -replace "\s*}$" | Set-Content "$(Split-Path $this.Path)\$ConfigFileExample" -ErrorAction Ignore -Encoding UTF8 -Force
            $Params = if (Test-Path "$(Split-Path $this.Path)\$ConfigFile") {"-c $ConfigFile"} else {"--auto"}
        }

        return "$Params $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api.json" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $Data.algo))
        if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
        if (-not $HashRate_Name) {$HashRate_Name = [String]$this.Algorithm[0]} #fireice fix
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.results.diff_current
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Double]$Data.results.shares_good
            $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}


class Lol : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/summary" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $PowerDraw      = [Double]($Data.Workers.Power | Measure-Object -Sum).Sum

        for ($i=0; $i -lt [int]$Data.Num_Algorithms; $i++) {
            $HashRate_Name  = [String]$this.Algorithm[$i]
            $HashRate_Value = [Double]($Data.Algorithms[$i].Total_Performance * $Data.Algorithms[$i].Performance_Factor)

            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

                $Accepted_Shares = [Int64]$Data.Algorithms[$i].Total_Accepted
                $Stale_Shares    = [Int64]$Data.Algorithms[$i].Total_Stales
                $Rejected_Shares = [Int64]$Data.Algorithms[$i].Total_Rejected
                $this.UpdateShares($i,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)
            } elseif ($i -gt 0) {
                $HashRate = [PSCustomObject]@{}
            }
        }

        $this.AddMinerData($Data,$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class Luk : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Response = $Data = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest -Server $Server -Port $this.Port -Timeout $Timeout -ReadToEnd -ErrorAction Stop -Quiet
            if (-not $Response) {throw}
            if ($Response -match 'LOG:') {$Data = $Response -replace 'LOG:' | ConvertFrom-StringData}
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name  = $this.Algorithm[0]        
        $HashRate_Value = [double]$Data.hash_rate

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [int64]$Data.num_shares_accepted
            $Rejected_Shares = [int64]$Data.num_shares_rejected
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class MiniZ : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = '{ "id":"0", "method":"getstat" }'
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet -ReadToEnd
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        if ($Data.pers -ne "zil") {
            $HashRate_Name    = [String]$this.Algorithm[0]

            $HashRate_Value   = [Double]($Data.result.speed_sps | Measure-Object -Sum).Sum

            $PowerDraw        = [Double]($Data.result.gpu_power_usage | Measure-Object -Sum).Sum

            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

                $Difficulty_Value = [Double]$Data.pool.difficulty
                $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

                $Accepted_Shares  = [Int64]($Data.result.accepted_shares | Measure-Object -Sum).Sum
                $Rejected_Shares  = [Int64]($Data.result.rejected_shares | Measure-Object -Sum).Sum
                #$Stale_Shares     = [Int64]($Data.result.stale_shares | Measure-Object -Sum).SUm
                $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
            }

            $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        }
        $this.CleanupMinerData()
    }
}


class Nanominer : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Miner_Path = Split-Path $this.Path
        $Parameters = $Arguments | ConvertFrom-Json
        $ConfigFile = "config_$($this.Pool -join '-')-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($Parameters.SSL){"-ssl"}).txt"

        if (Test-Path $this.Path) {
            $FileC = @(
                ";Automatic config file created by RainbowMiner",
                ";Do not edit!",
                "mport=0",
                "webPort=$($this.Port)",
                "Watchdog=false",
                "noLog=true"
            )

            foreach ($Algo in $Parameters.Algorithms) {
                $FileC += @(
                                "[$($Algo.Algo)]",
                                "wallet=$($Algo.Wallet)",
                                "rigName=$($Algo.Worker)",
                                "pool1=$($Algo.Host):$($Algo.Port)",
                                "devices=$(if ($Parameters.Devices -ne $null) {$Parameters.Devices -join ','})",
                                "useSSL=$(if ($Algo.SSL) {"true"} else {"false"})"
                            )
                if ($Algo.PaymentId -ne $null) {$FileC += "paymentId=$($Algo.PaymentId)"}
                if ($Algo.Pass)                {$FileC += "rigPassword=$($Algo.Pass)"}
                if ($Algo.Email)               {$FileC += "email=$($Algo.Email)"}
                if ($Algo.Coin)                {$FileC += "coin=$($Algo.Coin)"}
                if ($Algo.Protocol)            {$FileC += "protocol=$($Algo.Protocol)"}
                if ($Algo.Algo -eq "zil")      {$FileC += "zilEpoch=0"}
                if ($Parameters.LHR)           {$FileC += "lhr=$($Parameters.LHR)"}
                if ($Parameters.Threads)       {$FileC += "cpuThreads=$($Parameters.Threads)"}                
            }

            $FileC | Out-File "$($Miner_Path)\$($ConfigFile)" -Encoding utf8
        }

        return "$($ConfigFile)$(if ($Parameters.Params) {" $($Parameters.Params)"})"
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/stats" -Timeout $Timeout
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name0 = [String]$this.Algorithm[0]

        $HashRate_Ix0 = [String]$this.BaseAlgorithm[0]
        if ($HashRate_Ix0 -match "^(Ethash|KawPOW)(\d+|low|NH)") {$HashRate_Ix0 = $Matches[1]}
        elseif ($HashRate_Ix0 -eq "SCCPow") {$Hashrate_Ix0 = "FiroPow"}

        $Algos          = $Data.Algorithms[0].PSObject.Properties.Name

        if ($this.Algorithm.Count -gt 1) {
            $HashRate_Name1 = [String]$this.Algorithm[1]
            $HashRate_Ix1   = [String]$this.BaseAlgorithm[1]
            if ($HashRate_Ix1 -match "^(Ethash|KawPOW)(\d+|low|NH)") {$HashRate_Ix1 = $Matches[1]}
        } else {
            $HashRate_Name1 = ''
            $HashRate_Ix1   = ''
        }
        
        $Algos | Foreach-Object {
            $Algo_Norm = Get-Algorithm "$(if ($_ -eq "Heavyhash") {"kHeavyHash"} else {$_})"
            if ($HashRate_Ix0 -eq $Algo_Norm)     {$HashRate_Ix0 = $_}
            elseif ($HashRate_Ix1 -eq $Algo_Norm) {$HashRate_Ix1 = $_}

        }

        $HashRate_Value = [Double]$Data.Algorithms[0].$HashRate_Ix0.Total.Hashrate

        $PowerDraw      = [Double]($Data.Devices[0].PSObject.Properties.Value | Foreach-Object {[Double]$_.Power} | Measure-Object -Sum).Sum

        if ($HashRate_Name0 -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name0 = $HashRate_Value}

            $Accepted_Shares = [Int64]$Data.Algorithms[0].$HashRate_Ix0.Total.Accepted
            $Rejected_Shares = [Int64]$Data.Algorithms[0].$HashRate_Ix0.Total.Rejected
            #$Stale_Shares    = [Int64]$Data.solution_stat.$HashRate_Ix0.invalid
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($HashRate_Ix1) {
                $HashRate_Value = [Double]$Data.Algorithms[0].$HashRate_Ix1.Total.Hashrate

                if ($HashRate_Name1 -and $HashRate_Value -gt 0) {
                    $HashRate | Add-Member @{$HashRate_Name1 = $HashRate_Value}

                    $Accepted_Shares = [Int64]$Data.Algorithms[0].$HashRate_Ix1.Total.Accepted
                    $Rejected_Shares = [Int64]$Data.Algorithms[0].$HashRate_Ix1.Total.Accepted
                    #$Stale_Shares    = [Int64]$Data.solution_stat.$HashRate_Ix1.invalid
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
                }
            }
        }

        $this.AddMinerData("",$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class NBminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api/v1/status" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $ix = if ($this.Algorithm[1]) {1} else {0}

        $HashRate_Name  = [String]$this.Algorithm[$ix]
        $HashRate_Value = [Double]$Data.miner.total_hashrate_raw

        $PowerDraw      = [Double]$Data.miner.total_power_consume

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double](ConvertFrom-Hash($Data.stratum.difficulty))
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Int64]$Data.stratum.accepted_shares
            $Rejected_Shares  = [Int64]$Data.stratum.rejected_shares
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($ix -and $this.Algorithm[0]) {
                $HashRate_Name = [String]$this.Algorithm[0]

                $HashRate_Value = [Double]$Data.miner.total_hashrate2_raw

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

                    $Difficulty_Value = [Double](ConvertFrom-Hash($Data.stratum.difficulty2))
                    $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

                    $Accepted_Shares  = [Int64]$Data.stratum.accepted_shares2
                    $Rejected_Shares  = [Int64]$Data.stratum.rejected_shares2
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
                }
            }
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        $this.CleanupMinerData()
    }
}


class Nheq : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = "status"
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.result.speed_ips | Measure-Object -Sum).Sum * 1e6
        
        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $RunningMinutes = ($this.GetRunningTime()).TotalMinutes
            $Accepted_Shares = [Double]($Data.result.accepted_per_minute | Measure-Object -Sum).Sum * $RunningMinutes
            $Rejected_Shares = [Double]($Data.result.rejected_per_minute | Measure-Object -Sum).Sum * $RunningMinutes
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}

class NoncerPro : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate   = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.totalHashrate

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Rejected_Shares = [Int64]$Data.invalidShares
            $Accepted_Shares = [Int64]$Data.totalShares - $Rejected_Shares
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}

class Nqminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate   = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.totalHashrate

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Rejected_Shares = [Int64]$Data.errors
            $Accepted_Shares = [Int64]$Data.shares
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}

class OneZeroMiner : Miner {

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        #$Version = if ($Data.version -match "(\d\.[\d\.]+)") {$Matches[1]} else {$null}

        $HashRate_Name   = [String]$this.Algorithm[0]
        $HashRate_Name_0 = [String]$this.BaseAlgorithm[0]

        $Data_Algos     = $Data.algos | WHere-Object {$HashRate_Name_0 -eq (Get-Algorithm $_.name)}

        $HashRate_Value = [Double]($Data_Algos.total_hashrate)

        $PowerDraw      = [Double]($Data.devices.power | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            #if ($HashRate_Name -eq "Eaglesong" -and $Version -ne $null -and [version]$Version -le [version]"1.77") {$HashRate_Value /= 2}
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]($Data_Algos.total_accepted_shares)
            $Rejected_Shares = [Int64]($Data_Algos.total_rejected_shares)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData("",$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}

class Prospector : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api/v0/hashrates" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $Data.coin | Select-Object -Unique | ForEach-Object {
            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix
            $HashRate_Value = [Double](($Data | Where-Object coin -EQ $_).rate | Measure-Object -Sum).Sum

            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                $this.UpdateShares(0,0,0)
            }
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class RH : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = " "
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.infos.speed | Measure-Object -Sum).Sum
        
        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Double]($Data.infos.accepted | Measure-Object -Sum).Sum
            $Rejected_Shares = [Double]($Data.infos.rejected | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}


class RHWrapper : Miner {
    [Double]$Difficulty_Value = 0.0

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple) {
                    if ($Line_Simple -match "^Net\s+.+?Difficulty\s*is\s*([\d\.\,]+)") {
                        $this.Difficulty_Value  = [double]($Matches[1] -replace ',','.')
                    } elseif ($Line_Simple -match "^Miner\s+.+?Shares.+?Accepted.*?(\d+).*?Rejected.*?(\d+).*?Failed.*?(\d+)") {
                        $Accepted_Shares = [Int64]$Matches[1]
                        $Rejected_Shares = [Int64]$Matches[2]
                        $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                    } elseif ($Line_Simple -match "^Miner\s+.+?Speed.*?([\d\.\,]+).*?([hkMGT]+)") {
                        $Line_Cols = $Matches[1] -split '\s+'
                        $HashRate   = [PSCustomObject]@{}
                        $Difficulty = [PSCustomObject]@{}

                        $HashRate_Value  = [double]($Matches[1] -replace ',','.') * $(Switch ($Matches[2]) {
                            "Th" {1e12}
                            "Gh" {1e9}
                            "Mh" {1e6}
                            "kh" {1e3}
                            default {1}
                        })

                        if ($HashRate_Value -gt 0) {
                            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
                            $Difficulty | Add-Member @{$HashRate_Name = $this.Difficulty_Value}
                        }

                        $this.AddMinerData($Line_Simple,$HashRate,$Difficulty)
                    }
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class Rigel : Miner {

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/stat" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        #$Version = if ($Data.miner -match "(\d\.[\d\.]+)") {$Matches[1]} else {$null}

        $HashRate_Name0 = [String]$this.Algorithm[0]
        $HashRate_Ix0   = [String]$this.BaseAlgorithm[0]
        if ($HashRate_Ix0 -match "^(Ethash|KawPOW)(\d+|low|NH)") {$HashRate_Ix0 = $Matches[1]}
        elseif ($HashRate_Ix0 -eq "BlocxAutolykos2") {$HashRate_Ix0 = "Autolykos2"}

        $Algos          = $Data.algorithm -split '\+'

        if ($this.Algorithm.Count -gt 1) {
            $HashRate_Name1 = [String]$this.Algorithm[1]
            $HashRate_Ix1   = [String]$this.BaseAlgorithm[1]
            if ($HashRate_Ix1 -match "^(Ethash|KawPOW)(\d+|low|NH)") {$HashRate_Ix1 = $Matches[1]}
        } else {
            $HashRate_Name1 = ''
            $HashRate_Ix1   = ''
        }
        
        $Algos | Foreach-Object {
            $Algo_Norm = Get-Algorithm $_
            if ($HashRate_Ix0 -eq $Algo_Norm)     {$HashRate_Ix0 = $_}
            elseif ($HashRate_Ix1 -eq $Algo_Norm) {$HashRate_Ix1 = $_}

        }

        $HashRate_Value = [Double]$Data.hashrate.$HashRate_Ix0

        $PowerDraw      = [Double]$Data.power_usage

        $ZilHashRate = 0

        if ($Data.algorithm -match "\+zil") {
            $ZilHashRate = [Double]$Data.hashrate.zil
            if ($ZilHashRate -gt 0) {
                if ($HashRate_Value -le 1) {
                    $HashRate_Value = $this.Speed_Last[0]
                }
            }
        }

        if ($HashRate_Name0 -and $HashRate_Value -gt 0) {

            $this.Speed_Last[0] = $HashRate_Value

            $HashRate | Add-Member @{$HashRate_Name0 = $HashRate_Value}

            $Accepted_Shares = [Int64]$Data.solution_stat.$HashRate_Ix0.accepted
            $Rejected_Shares = [Int64]$Data.solution_stat.$HashRate_Ix0.rejected
            $Stale_Shares    = [Int64]$Data.solution_stat.$HashRate_Ix0.invalid
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)

            if ($HashRate_Ix1) {

                $HashRate_Value = [Double]$Data.hashrate.$HashRate_Ix1

                if ($ZilHashRate -gt 0) {
                    if ($HashRate_Value -le 1) {
                        $HashRate_Value = $this.Speed_Last[1]
                    }
                }
                
                $this.Speed_Last[1] = $HashRate_Value

                if ($HashRate_Name1 -and $HashRate_Value -gt 0) {
                    $HashRate | Add-Member @{$HashRate_Name1 = $HashRate_Value}

                    $Accepted_Shares = [Int64]$Data.solution_stat.$HashRate_Ix1.accepted
                    $Rejected_Shares = [Int64]$Data.solution_stat.$HashRate_Ix1.rejected
                    $Stale_Shares    = [Int64]$Data.solution_stat.$HashRate_Ix1.invalid
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)
                }
            }
        }

        $this.AddMinerData("",$HashRate,$null,$PowerDraw)

        $this.CleanupMinerData()
    }
}

class SixMinerWrapper : Miner {

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple -match "^.+?(speed|accepted)\s+(.+?)$") {
                    $Mode  = $Matches[1]
                    $Words = $Matches[2] -split "\s+"
                    if ($Mode -eq "speed") {
                        $HashRate = [PSCustomObject]@{}
                        $Speed = if ($Words[2] -notmatch "n/a") {$Unit=$Words[3];$Words[2]} else {$Unit=$Words[1];$Words[0]}
                        $HashRate_Value  = [double]($Speed -replace '^.*:' -replace ',','.')

                        switch -Regex ($Unit) {
                            "^k" {$HashRate_Value *= 1E+3}
                            "^M" {$HashRate_Value *= 1E+6}
                            "^G" {$HashRate_Value *= 1E+9}
                            "^T" {$HashRate_Value *= 1E+12}
                            "^P" {$HashRate_Value *= 1E+15}
                        }

                        if ($HashRate_Value -gt 0) {
                            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                        }

                        $this.AddMinerData($Line_Simple,$HashRate)
                    } elseif ($Mode -eq "accepted" -and $Words[0] -match "(\d+)/(\d+)") {
                        $Accepted_Shares = [Int64]$Matches[1]
                        $Rejected_Shares = [Int64]$Matches[2]
                        $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                    }
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class SPMinerWrapper : Miner {

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple -match "accepted:\s*(\d+)/(\d+).+\s+([\d\.]+)\s+([hkMGTP]+)/s") {
                    $Accepted_Shares = [Int64]$Matches[1]
                    $Total_Shares    = [Int64]$Matches[2]

                    $HashRate_Value = [Double]"$($Matches[3] -replace "[^\d\.]+")"

                    switch -Regex ($Matches[4]) {
                        "k" {$HashRate_Value *= 1E+3}
                        "M" {$HashRate_Value *= 1E+6}
                        "G" {$HashRate_Value *= 1E+9}
                        "T" {$HashRate_Value *= 1E+12}
                        "P" {$HashRate_Value *= 1E+15}
                    }

                    $HashRate = [PSCustomObject]@{}

                    if ($HashRate_Value -gt 0) {
                        $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                        $this.UpdateShares(0,$Accepted_Shares,$Total_Shares - $Accepted_Shares)
                    }

                    $this.AddMinerData($Line_Simple,$HashRate)
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class SrbMiner : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Parameters = $Arguments | ConvertFrom-Json

        #Write config files. Keep separate files and do not overwrite to preserve optional manual customization
        $Threads = $Parameters.Config.gpu_conf.threads | Select-Object -Unique
        $ConfigFile = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($Threads -and $Threads -gt 1) {"-$($Threads)"}).txt"
        if (-not (Test-Path "$(Split-Path $this.Path)\$ConfigFile")) {
            $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content "$(Join-Path (Split-Path $this.Path) $ConfigFile)" -ErrorAction Ignore -Encoding UTF8
        }

        #Write pool file. Keep separate files
        $PoolFile = "pools_$($this.Pool)-$($this.BaseAlgorithm -join '-').txt"
        $Parameters.Pools | ConvertTo-Json -Depth 10 | Set-Content "$(Join-Path (Split-Path $this.Path) $PoolFile)" -Force -ErrorAction Ignore -Encoding UTF8

        return "$(if ($Parameters.CPar) {$Parameters.CPar} else {"--config"}) $ConfigFile $(if ($Parameters.PPar) {$Parameters.PPar} else {"--pools"}) $PoolFile $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [double]$Data.HashRate_total_5min
        if (-not $HashRate_Value) {$HashRate_Value = [double]$Data.HashRate_total_now}

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Accepted_Shares = [Int64]$Data.shares.accepted
            $Rejected_Shares = [Int64]$Data.shares.rejected
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}

class SrbMinerMulti : Miner {

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds
        $DualMining = $this.Algorithm.Count -eq 2

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $Type = if ($Data.total_cpu_workers -gt 0) {"cpu"} else {"gpu"}

        $BaseAlgorithm0 = [String]$this.BaseAlgorithm[0]

        if ($BaseAlgorithm0 -match "^(Ethash|KawPOW)(\d+|low|NH)") {$BaseAlgorithm0 = $Matches[1]}
        elseif ($BaseAlgorithm0 -eq "SCCPow") {$BaseAlgorithm0 = "FiroPow"}

        $Data0 = $Data.algorithms | Where-Object {"$(Get-Algorithm $_.name)" -eq $BaseAlgorithm0} | Select-Object -First 1

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = if ($Type -eq "cpu" -or $Data.mining_time -gt 20) {[double]$Data0.hashrate.$Type.total} else {0}

        $PowerDraw = if ($Type -eq "gpu") {($Data.gpu_devices | Foreach-Object {$_.asic_power} | Measure-Object -Sum).Sum} else {$null}

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data0.pool.difficulty
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares = [Int64]$Data0.shares.accepted
            $Rejected_Shares = [Int64]$Data0.shares.rejected
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($DualMining) {

                $Data0 = $Data.algorithms | Where-Object {"$(Get-Algorithm $_.name)" -eq [String]$this.BaseAlgorithm[1]} | Select-Object -First 1

                $HashRate_Name = [String]$this.Algorithm[1]
                $HashRate_Value = [double]$Data0.hashrate.$Type.total

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

                    $Difficulty_Value = [Double]$Data0.pool.difficulty
                    $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

                    $Accepted_Shares = [Int64]$Data0.shares.accepted
                    $Rejected_Shares = [Int64]$Data0.shares.rejected
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
                }

            }
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        $this.CleanupMinerData()
    }
}

class SwapminerWrapper : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Parameters = $Arguments | ConvertFrom-Json

        $ConfigPath = Join-Path $([IO.Path]::GetFullPath($this.Path) | Split-Path) "$($this.Pool -join '-')-$($this.DeviceModel)$(if ($Parameters.SSL){"-ssl"})"

        if (Test-Path $this.Path) {
            if (-not (Test-Path $ConfigPath)) {New-Item $ConfigPath -ItemType "directory" > $null}
            "<?xml version=`"1.0`" encoding=`"utf-8`"?>
<Config xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
  <PrimaryConnection>
    <ConnectionAddress>$($Parameters.Config.Host)</ConnectionAddress>
    <ConnectionPort>$($Parameters.Config.Port)</ConnectionPort>
    <Ssl>$(if ($Parameters.Config.SSL) {"true"} else {"false"})</Ssl>
    <Login>$($Parameters.Config.User)</Login>
    <Password>$($Parameters.Config.Pass)</Password>  
  </PrimaryConnection>
  <SecondaryConnection>
  </SecondaryConnection>
  <LogOptions>
    <FileMinimumLogLevel>$(if ($Parameters.LogOptions.FileMinimumLogLevel) {$Parameters.LogOptions.FileMinimumLogLevel} else {"INFO"})</FileMinimumLogLevel>
    <ConsoleMinimumLogLevel>$(if ($Parameters.LogOptions.ConsoleMinimumLogLevel) {$Parameters.LogOptions.ConsoleMinimumLogLevel} else {"INFO"})</ConsoleMinimumLogLevel>
    <KeepDays>1</KeepDays>
    <DisableLogging>false</DisableLogging>
  </LogOptions>
  <CPUOffloadValue>$([int]$Parameters.CPUOffloadValue)</CPUOffloadValue>
  <GPUOptions>$($Parameters.Device | Foreach-Object {"
    <GPUOption>
        <GPUName>$($_.Name)</GPUName>
        <GPUType>$($_.Vendor)</GPUType>
        <DeviceID>$($_.Index)</DeviceID>
        <PlatformID>$($_.PlatformId)</PlatformID>
        <Enabled>true</Enabled>
    </GPUOption>"})
  </GPUOptions>
</Config>" | Out-File "$($ConfigPath)\config.xml" -Encoding utf8
        }

        return "configpath=$ConfigPath mode=rolling $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple) {

                    if ($Line_Simple -match "Results: ([\d\.,]+).*gps.+sub:(\d+).+acc:(\d+).+rej:(\d+)") {
                        $HashRate = [PSCustomObject]@{}

                        $HashRate_Value  = [double]($Matches[1] -replace ',','.')

                        if ($HashRate_Value -gt 0) {
                            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}

                            $Accepted_Shares = [Int64]$Matches[3]
                            $Rejected_Shares = [Int64]$Matches[4]
                            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                        }

                        $this.AddMinerData($Line_Simple,$HashRate)
                    }
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class TBMiner : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = $null

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/summary" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name  = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.PSObject.Properties.Value.hashrate | Measure-Object -Sum).Sum
        $PowerDraw      = [Double]($Data.devices.PSObject.Properties.Value.watt | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]($Data.pool.PSObject.Properties.Value | Select-Object -First 1).diff
            if ($Difficulty_Value -gt 0) {
                $Difficulty = [PSCustomObject]@{$HashRate_Name = $Difficulty_Value}
            }

            $Accepted_Shares  = [Int64]($Data.devices.PSObject.Properties.Value.accepted | Measure-Object -Sum).Sum
            $Rejected_Shares  = [Int64]($Data.devices.PSObject.Properties.Value.rejected | Measure-Object -Sum).Sum
            $Stale_Shares     = [Int64]($Data.devices.PSObject.Properties.Value.stale | Measure-Object -Sum).Sum
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares,$Stale_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        $this.CleanupMinerData()
    }
}

class TeamblackWrapper : Miner {

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple -notmatch "GPU\d" -and $Line_Simple -match "([\d\s\./hkMGTPs]+?)(\d+)/(\d+)[/\s].*\([\d\.]+\)$") {
                    $Accepted_Shares = [Int64]$Matches[2]
                    $Rejected_Shares = [Int64]$Matches[3]

                    $Words = "$($Matches[1])".Trim() -split "\s+"

                    $HashRate = [PSCustomObject]@{}

                    $HashRate_Value = [Double]"$($Words[2] -replace "[^\d\.]+")"

                    switch -Regex ($Words[3]) {
                        "k" {$HashRate_Value *= 1E+3}
                        "M" {$HashRate_Value *= 1E+6}
                        "G" {$HashRate_Value *= 1E+9}
                        "T" {$HashRate_Value *= 1E+12}
                        "P" {$HashRate_Value *= 1E+15}
                    }

                    if ($HashRate_Value -gt 0) {
                        $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                        $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                    }

                    $this.AddMinerData($Line_Simple,$HashRate)
                } elseif ($Line_Simple -match "Accepted\s+\((\d+)/(\d+)[/)]") {
                    $Accepted_Shares = [Int64]$Matches[1]
                    $Total_Shares    = [Int64]$Matches[2]
                    $this.UpdateShares(0,$Accepted_Shares,$Total_Shares - $Accepted_Shares)
                } elseif ($Line_Simple -match "GPU\s+(\d+):\s+has\s+timed\sout") {
                    #GPU has crashed, restart miner
                    Write-Log -Level Warn "$($this.Name): GPU $($Matches[1]) has timed out - restarting miner"
                    $this.Restart = $true
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class Trex : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/summary" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]

        $PowerDraw      = [Double]($Data.gpus.power | Measure-Object -Sum).Sum

        $HashRate_Value   = [Double]$Data.hashrate
        $HashRateGPUs_Value = [Double]($Data.gpus.hashrate | Measure-Object -Sum).Sum
        if ($HashRate_Value -le $HashRateGPUs_Value*0.6) {
            $HashRate_Value = $HashRateGPUs_Value
        }

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = ConvertFrom-Hash "$($Data.active_pool.difficulty)"
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Int64]$Data.accepted_count
            $Rejected_Shares  = [Int64]$Data.rejected_count
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        if ($this.Algorithm.Count -eq 2) {

            $HashRate_Name = [String]$this.Algorithm[1]

            $HashRate_Value   = [Double]$Data.dual_stat.hashrate
            $HashRateGPUs_Value = [Double]($Data.dual_stat.gpus.hashrate | Measure-Object -Sum).Sum
            if ($HashRate_Value -le $HashRateGPUs_Value*0.6) {
                $HashRate_Value = $HashRateGPUs_Value
            }

            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

                $Difficulty_Value = ConvertFrom-Hash "$($Data.dual_stat.active_pool.difficulty)"
                $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

                $Accepted_Shares  = [Int64]$Data.dual_stat.accepted_count
                $Rejected_Shares  = [Int64]$Data.dual_stat.rejected_count
                $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
            }

        }

        $this.AddMinerData($Response,$HashRate,$Difficulty,$PowerDraw)

        $this.CleanupMinerData()
    }

    [String]GetShutdownUrl() {
        return "$(if ($Global:IsLinux) {"http://127.0.0.1:$($this.Port)/control?command=shutdown"})"
    }
}

class VerthashWrapper : Miner {

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r"
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]"
                if ($Line_Simple -match "^.+?accepted[:\s]+(\d+)/(\d+).+hashrate[^\d]+(.+?)\s+(.+?)/s") {
                    $HashRate_Value = [Double]"$($Matches[3])"

                    switch ("$($Matches[4])") {
                        "kH" {$HashRate_Value *= 1e+3;Break}
                        "MH" {$HashRate_Value *= 1e+6;Break}
                        "GH" {$HashRate_Value *= 1e+9;Break}
                        "TH" {$HashRate_Value *= 1e+12;Break}
                        "PH" {$HashRate_Value *= 1e+15;Break}
                    }

                    $HashRate = [PSCustomObject]@{}
                    if ($HashRate_Value -gt 0) {
                        $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                    }

                    $Accepted_Shares = [Int64]$Matches[1]
                    $Rejected_Shares = [Int64]$Matches[2] - $Accepted_Shares
                    $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

                    $this.AddMinerData($Line_Simple,$HashRate)
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}

class WildRig : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }
        
        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.results.diff_current
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Double]$Data.results.shares_good
            $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}

class Wrapper : Miner {
}


class Xgminer : Miner {
    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport2",($this.Port + 1) -replace "\`$mport",$this.Port
        return $Arguments
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $DualMining = $this.Algorithm.Count -ge 2

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Depth 10 -Compress
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = If ($Data.SUMMARY.HS_5s) { [Double]$Data.SUMMARY.HS_5s }
        elseif ($Data.SUMMARY.KHS_5s) { [Double]$Data.SUMMARY.KHS_5s * 1e3 }
        elseif ($Data.SUMMARY.MHS_5s) { [Double]$Data.SUMMARY.MHS_5s * 1e6 }
        elseif ($Data.SUMMARY.GHS_5s) { [Double]$Data.SUMMARY.GHS_5s * 1e9 }
        elseif ($Data.SUMMARY.THS_5s) { [Double]$Data.SUMMARY.THS_5s * 1e12 }
        elseif ($Data.SUMMARY.PHS_5s) { [Double]$Data.SUMMARY.PHS_5s * 1e15 }
        elseif ($Data.SUMMARY.KHS_30s) { [Double]$Data.SUMMARY.KHS_30s * 1e3 }
        elseif ($Data.SUMMARY.MHS_30s) { [Double]$Data.SUMMARY.MHS_30s * 1e6 }
        elseif ($Data.SUMMARY.GHS_30s) { [Double]$Data.SUMMARY.GHS_30s * 1e9 }
        elseif ($Data.SUMMARY.THS_30s) { [Double]$Data.SUMMARY.THS_30s * 1e12 }
        elseif ($Data.SUMMARY.PHS_30s) { [Double]$Data.SUMMARY.PHS_30s * 1e15 }
        elseif ($Data.SUMMARY.HS_av) { [Double]$Data.SUMMARY.HS_av }
        elseif ($Data.SUMMARY.KHS_av) { [Double]$Data.SUMMARY.KHS_av * 1e3 }
        elseif ($Data.SUMMARY.MHS_av) { [Double]$Data.SUMMARY.MHS_av * 1e6 }
        elseif ($Data.SUMMARY.GHS_av) { [Double]$Data.SUMMARY.GHS_av * 1e9 }
        elseif ($Data.SUMMARY.THS_av) { [Double]$Data.SUMMARY.THS_av * 1e12 }
        elseif ($Data.SUMMARY.PHS_av) { [Double]$Data.SUMMARY.PHS_av * 1e15 }

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.SUMMARY.Difficulty_Accepted
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Int64]$Data.SUMMARY.accepted
            $Rejected_Shares  = [Int64]$Data.SUMMARY.rejected
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($DualMining) {

                try {
                    $Response = Invoke-TcpRequest $Server ($this.Port + 1) $Request -Timeout $Timeout -ErrorAction Stop -Quiet
                    $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    Write-Log -Level Info "Failed to connect to miner $($this.Name), second algorithm $($this.Algorithm[1]). "
                    return
                }

                $HashRate_Name = [String]$this.Algorithm[1]
                $HashRate_Value = If ($Data.SUMMARY.HS_5s) { [Double]$Data.SUMMARY.HS_5s }
                elseif ($Data.SUMMARY.KHS_5s) { [Double]$Data.SUMMARY.KHS_5s * 1e3 }
                elseif ($Data.SUMMARY.MHS_5s) { [Double]$Data.SUMMARY.MHS_5s * 1e6 }
                elseif ($Data.SUMMARY.GHS_5s) { [Double]$Data.SUMMARY.GHS_5s * 1e9 }
                elseif ($Data.SUMMARY.THS_5s) { [Double]$Data.SUMMARY.THS_5s * 1e12 }
                elseif ($Data.SUMMARY.PHS_5s) { [Double]$Data.SUMMARY.PHS_5s * 1e15 }
                elseif ($Data.SUMMARY.KHS_30s) { [Double]$Data.SUMMARY.KHS_30s * 1e3 }
                elseif ($Data.SUMMARY.MHS_30s) { [Double]$Data.SUMMARY.MHS_30s * 1e6 }
                elseif ($Data.SUMMARY.GHS_30s) { [Double]$Data.SUMMARY.GHS_30s * 1e9 }
                elseif ($Data.SUMMARY.THS_30s) { [Double]$Data.SUMMARY.THS_30s * 1e12 }
                elseif ($Data.SUMMARY.PHS_30s) { [Double]$Data.SUMMARY.PHS_30s * 1e15 }
                elseif ($Data.SUMMARY.HS_av) { [Double]$Data.SUMMARY.HS_av }
                elseif ($Data.SUMMARY.KHS_av) { [Double]$Data.SUMMARY.KHS_av * 1e3 }
                elseif ($Data.SUMMARY.MHS_av) { [Double]$Data.SUMMARY.MHS_av * 1e6 }
                elseif ($Data.SUMMARY.GHS_av) { [Double]$Data.SUMMARY.GHS_av * 1e9 }
                elseif ($Data.SUMMARY.THS_av) { [Double]$Data.SUMMARY.THS_av * 1e12 }
                elseif ($Data.SUMMARY.PHS_av) { [Double]$Data.SUMMARY.PHS_av * 1e15 }

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

                    $Difficulty_Value = [Double]$Data.SUMMARY.Difficulty_Accepted
                    $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

                    $Accepted_Shares  = [Int64]$Data.SUMMARY.accepted
                    $Rejected_Shares  = [Int64]$Data.SUMMARY.rejected
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
                }
            }
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}


class Xmrig : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $Miner_Path        = Split-Path $this.Path
        $Parameters        = $Arguments | ConvertFrom-Json
        $ConfigFN          = "config_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($this.DeviceName -like "GPU*") {"-$(($Parameters.Devices | %{"{0:x}" -f $_}) -join '')"})_$($this.Port)-$($Parameters.Threads).json"
        $ThreadsConfigFN   = "threads_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig).json"
        $ConfigFile        = Join-Path $Miner_Path $ConfigFN
        $ThreadsConfigFile = Join-Path $Miner_Path $ThreadsConfigFN
        $ThreadsConfig     = $null
        $LogFile           = Join-Path $Miner_Path "log_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig).txt"

        if ($Parameters.Config.api.port) {$Parameters.Config.api.port = $this.Port}

        try {
            if (Test-Path $ThreadsConfigFile) {
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            if (-not ($ThreadsConfig | Measure-Object).Count) {
                $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -Force

                $ArgumentList = ("$($Parameters.PoolParams) --config=$ThreadsConfigFN $($Parameters.DeviceParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -WorkingDirectory $Miner_Path -LogPath $LogFile -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper") -Executables $this.Executables -SetLDLIBRARYPATH:$this.SetLDLIBRARYPATH
                if ($Job.XJob) {
                    $wait = 0
                    While ($wait -lt 60) {
                        if (($ThreadsConfig = @(Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).threads | Select-Object)) {
                            if ($this.DeviceName -like "GPU*") {
                                ConvertTo-Json -InputObject @($ThreadsConfig | Sort-Object -Property Index -Unique) -Depth 10 | Set-Content $ThreadsConfigFile -ErrorAction Ignore -Force
                            }
                            else {
                                ConvertTo-Json -InputObject @($ThreadsConfig | Select-Object -Unique) -Depth 10 | Set-Content $ThreadsConfigFile -ErrorAction Ignore -Force
                            }
                            break
                        }
                        Start-Sleep -Milliseconds 500
                        $MiningProcess = $Job.ProcessId | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore | Select-Object Id,HasExited}
                        if ((-not $MiningProcess -and $Job.XJob.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq 1)) {$wait++} else {break}
                    }
                }
                if ($Job) {
                    Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"

                    $Job = $null
                    Remove-Variable -Name Job -ErrorAction Ignore
                }
                if ((Test-Path $ThreadsConfigFile) -and -not ($ThreadsConfig | Measure-Object).Count) {
                    Remove-Item $ThreadsConfigFile -ErrorAction Ignore -Force
                }
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            if (-not ((Get-Content $ConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).threads)) {
                if ($ThreadsConfig -and $ThreadsConfig.Count) {
                    if ($this.DeviceName -like "GPU*") {
                        $Parameters.Config | Add-Member threads ([Array](@($ThreadsConfig | Where-Object {$Parameters.Devices -contains $_.index} | Select-Object) * $Parameters.Threads)) -Force
                    }
                    else {
                        if ($Parameters.Threads) {
                            $Parameters.Config | Add-Member threads ([Array]($ThreadsConfig * $Parameters.Threads)) -Force
                        } else {
                            $Parameters.Config | Add-Member threads ([Array]($ThreadsConfig)) -Force
                        }
                    }
                    $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Force
                }
                else {
                    Write-Log -Level Warn "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')})"
                }                
            }
        }
        catch {
            Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
        }

        return ("$($Parameters.PoolParams) --config=$ConfigFN $($Parameters.DeviceParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api.json" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }
        
        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.results.diff_current
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Double]$Data.results.shares_good
            $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}


class Xmrig3 : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $ThreadsConfig     = $null

        $Miner_Path        = Split-Path $this.Path
        $Parameters        = $Arguments | ConvertFrom-Json

        $ConfigName        = "$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig)$(if ($Parameters.Affinity -ne $null) {"_$($Parameters.Affinity)"})_$($Parameters.Threads)"

        $ConfigFN          = "config_$($ConfigName).json"
        $ThreadsConfigFN   = "threads_$($Parameters.HwSig).json"
        $ConfigFile        = Join-Path $Miner_Path $ConfigFN
        $ThreadsConfigFile = Join-Path $Miner_Path $ThreadsConfigFN
        $LogFile           = "log_$($ConfigName).txt"

        $Algo              = $Parameters.Algorithm
        $Algo0             = $Parameters.Algorithm -replace "/.+$"
        $Device            = Switch($Parameters.Vendor) {"AMD" {"opencl"}; "NVIDIA" {"cuda"}; default {"cpu"}}

        try {
            if (Test-Path $ThreadsConfigFile) {
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            if (-not ($ThreadsConfig.$Algo | Measure-Object).Count -and -not ($ThreadsConfig.$Algo0 | Measure-Object).Count) {
                $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -Force

                $ArgumentList = ("--algo=$Algo $($Parameters.PoolParams) --config=$ThreadsConfigFN $($Parameters.DeviceParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -WorkingDirectory $Miner_Path -LogPath (Join-Path $Miner_Path $LogFile) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper") -Executables $this.Executables -SetLDLIBRARYPATH:$this.SetLDLIBRARYPATH
                if ($Job.XJob) {
                    $wait = 0
                    While ($wait -lt 60) {
                        if (($ThreadsConfig = @(Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).$Device | Select-Object)) {
                            ConvertTo-Json $ThreadsConfig -Depth 10 | Set-Content $ThreadsConfigFile -Force
                            break
                        }
                        Start-Sleep -Milliseconds 500
                        $MiningProcess = $Job.ProcessId | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore | Select-Object Id,HasExited}
                        if ((-not $MiningProcess -and $Job.XJob.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq 1)) {$wait++} else {break}
                    }
                }
                if ($Job) {
                    Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"

                    $Job = $null
                    Remove-Variable -Name Job -ErrorAction Ignore
                }
                if ((Test-Path $ThreadsConfigFile) -and -not ($ThreadsConfig.$Algo | Measure-Object).Count -and -not ($ThreadsConfig.$Algo0 | Measure-Object).Count) {
                    Remove-Item $ThreadsConfigFile -ErrorAction Ignore -Force
                }
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }

            $Config = Get-Content $ConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

            if (-not $Config.$Device -and -not ($Config.$Device.$Algo | Measure-Object).Count -and -not ($Config.$Device.$Algo0 | Measure-Object).Count) {
                if ($ThreadsConfig.$Algo -or $ThreadsConfig.$Algo0) {
                    $Parameters.Config | Add-Member $Device ([PSCustomObject]@{}) -Force
                    $ThreadsConfig.PSObject.Properties | Where-Object {$_.Name -notmatch "/0$" -and $_.Value -isnot [array]} | Foreach-Object {
                        $n = $_.Name; $v = $_.Value
                        $Parameters.Config.$Device | Add-Member $n $v -Force
                    }
                    $Algo = if ($ThreadsConfig.$Algo) {$Algo} else {$Algo0}

                    if ($Device -eq "cpu") {
                        $cix = @{}
                        $ThreadsAffinity = $ThreadsConfig.$Algo | Foreach-Object {if ($_ -is [array] -and $_.Count -eq 2) {$cix["k$($_[1])"] = $_[0];$_[1]} else {$_}}

                        $Parameters.Config.$Device | Add-Member $Algo ([Array]($ThreadsAffinity | Sort-Object {$_ -band 1},{$_} | Select-Object -First $(if ($Parameters.Threads -and $Parameters.Threads -lt $ThreadsConfig.$Algo.Count) {$Parameters.Threads} else {$ThreadsConfig.$Algo.Count}) | Sort-Object)) -Force

                        $Aff = if ($Parameters.Affinity) {ConvertFrom-CPUAffinity $Parameters.Affinity}
                        if ($AffCount = ($Aff | Measure-Object).Count) {
                            $AffThreads = @(Compare-Object $Aff $Parameters.Config.$Device.$Algo -IncludeEqual -ExcludeDifferent | Where-Object {$_.SideIndicator -eq "=="} | Foreach-Object {$_.InputObject} | Select-Object)
                            $ThreadsCount = [Math]::Min($AffCount,$Parameters.Config.$Device.$Algo.Count)
                            if ($AffThreads.Count -lt $ThreadsCount) {
                                $Aff | Where-Object {$_ -notin $AffThreads} | Sort-Object {$_ -band 1},{$_} | Select-Object -First ($ThreadsCount-$AffThreads.Count) | Foreach-Object {$AffThreads += $_}
                            }
                            $Parameters.Config.$Device.$Algo = @($AffThreads | Sort-Object);
                        }
                        if ($cix.Count) {
                            for ($i=0; $i -lt $Parameters.Config.$Device.$Algo.Count; $i++) {
                                $thr = $Parameters.Config.$Device.$Algo[$i]
                                $Parameters.Config.$Device.$Algo[$i] = @($(if ($cix["k$thr"]) {$cix["k$thr"]} else {1}),$thr)
                            }
                        }
                    } else { #device is cuda or opencl
                        $Parameters.Config.$Device | Add-Member $Algo ([Array](@($ThreadsConfig.$Algo | Where-Object {$Parameters.Devices -contains $_.index} | Select-Object) * $Parameters.Threads)) -Force
                    }
                    $Parameters.Config | Add-Member autosave $false -Force
                    $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Force
                }
                else {
                    Write-Log -Level Warn "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')})"
                }                
            }
        }
        catch {
            Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
        }

        return ("--algo=$($Parameters.Algorithm) --config=$ConfigFN $($Parameters.DeviceParams) $($Parameters.PoolParams) $($Parameters.APIParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api.json" -Timeout $Timeout -ForceHttpClient
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.results.diff_current
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Double]$Data.results.shares_good
            $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}

class Xmrig6 : Miner {

    [String]GetArguments() {
        $Arguments = $this.Arguments -replace "\`$mport",$this.Port
        if ($Arguments -notlike "{*}") {return $Arguments}

        $ThreadsConfig     = $null

        $Miner_Path        = Split-Path $this.Path
        $Parameters        = $Arguments | ConvertFrom-Json

        $ConfigName        = "$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig)$(if ($Parameters.Affinity -ne $null) {"_$($Parameters.Affinity)"})_$($Parameters.Threads)"

        $ConfigFN          = "config_$($ConfigName).json"
        $ThreadsConfigFN   = "threads_$($Parameters.HwSig).json"
        $RunConfigFN       = "run_$(Get-MD5Hash "$($ConfigName)$(ConvertTo-Json $Parameters.Pools -Compress)").json"
        $ConfigFile        = Join-Path $Miner_Path $ConfigFN
        $ThreadsConfigFile = Join-Path $Miner_Path $ThreadsConfigFN
        $RunConfigFile     = Join-Path $Miner_Path $RunConfigFN
        $LogFile           = "log_$($ConfigName).txt"

        $Algo              = $Parameters.Algorithm
        $Algo0             = $Parameters.Algorithm -replace "/.+$"
        $Device            = if ($Parameters.Codec -ne $null -and $Parameters.Codec -ne "auto") {$Parameters.Codec} else {Switch($Parameters.Vendor) {"AMD" {"opencl";break}; "INTEL" {"opencl";break}; "NVIDIA" {"cuda";break}; default {"cpu"}}}

        try {
            if (Test-Path $ThreadsConfigFile) {
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            if (-not ($ThreadsConfig.$Algo | Measure-Object).Count -and -not ($ThreadsConfig.$Algo0 | Measure-Object).Count) {
                $InitConfig = $Parameters.Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                $InitConfig | Add-Member pools $Parameters.Pools -Force -PassThru | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -Force

                $ArgumentList = ("--algo=$($Parameters.Algorithm) --config=$ThreadsConfigFN $($Parameters.DeviceParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -WorkingDirectory $Miner_Path -LogPath (Join-Path $Miner_Path $LogFile) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper") -MultiProcess $this.MultiProcess -Executables $this.Executables -SetLDLIBRARYPATH:$this.SetLDLIBRARYPATH
                if ($Job.XJob) {
                    $WaitProc    = $this.MultiProcess + 1
                    $WaitSeconds = if ($Device -eq "cpu") {30} else {90}
                    $StopWatch = [System.Diagnostics.StopWatch]::New()
                    $StopWatch.Restart()
                    do {
                        if ($ThreadsConfig = (Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).$Device | Select-Object) {
                            ConvertTo-Json $ThreadsConfig -Depth 10 | Set-Content $ThreadsConfigFile -Force
                            break
                        }
                        Start-Sleep -Milliseconds 500
                        $MiningProcess = $Job.ProcessId | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore | Select-Object Id,HasExited}
                    } while ($StopWatch.Elapsed.TotalSeconds -lt $WaitSeconds -and ((-not $MiningProcess -and $Job.XJob.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq $WaitProc)))
                    $StopWatch = $null
                }
                if ($Job) {
                    Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"

                    $Job = $null
                    Remove-Variable -Name Job -ErrorAction Ignore
                }
                if ((Test-Path $ThreadsConfigFile) -and -not ($ThreadsConfig.$Algo | Measure-Object).Count -and -not ($ThreadsConfig.$Algo0 | Measure-Object).Count) {
                    Remove-Item $ThreadsConfigFile -ErrorAction Ignore -Force
                }
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }

            $Config = Get-Content $ConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

            if (-not $Config.$Device -and -not ($Config.$Device.$Algo | Measure-Object).Count -and -not ($Config.$Device.$Algo0 | Measure-Object).Count) {
                if ($ThreadsConfig.$Algo -or $ThreadsConfig.$Algo0) {
                    $Parameters.Config | Add-Member $Device ([PSCustomObject]@{}) -Force
                    $ThreadsConfig.PSObject.Properties | Where-Object {$_.Name -notmatch "/0$" -and $_.Value -isnot [array]} | Foreach-Object {
                        $n = $_.Name; $v = $_.Value
                        $Parameters.Config.$Device | Add-Member $n $v -Force
                    }
                    $Algo = if ($ThreadsConfig.$Algo) {$Algo} else {$Algo0}

                    if ($Device -eq "cpu") {
                        if ($Algo -eq "ghostrider") {
                            $Parameters.Config.$Device | Add-Member "max-threads-hint" ([int](100 * $Parameters.Threads / $Global:GlobalCPUInfo.Threads)) -Force
                        }
                        $cix = @{}
                        $ThreadsAffinity = $ThreadsConfig.$Algo | Foreach-Object {if ($_ -is [array] -and $_.Count -eq 2) {$cix["k$($_[1])"] = $_[0];$_[1]} else {$_}}

                        $Parameters.Config.$Device | Add-Member $Algo ([Array]($ThreadsAffinity | Sort-Object {$_ -band 1},{$_} | Select-Object -First $(if ($Parameters.Threads -and $Parameters.Threads -lt $ThreadsConfig.$Algo.Count) {$Parameters.Threads} else {$ThreadsConfig.$Algo.Count}) | Sort-Object)) -Force

                        $Aff = if ($Parameters.Affinity) {ConvertFrom-CPUAffinity $Parameters.Affinity}
                        if ($AffCount = ($Aff | Measure-Object).Count) {
                            $AffThreads = @(Compare-Object $Aff $Parameters.Config.$Device.$Algo -IncludeEqual -ExcludeDifferent | Where-Object {$_.SideIndicator -eq "=="} | Foreach-Object {$_.InputObject} | Select-Object)
                            $ThreadsCount = [Math]::Min($AffCount,$Parameters.Config.$Device.$Algo.Count)
                            if ($AffThreads.Count -lt $ThreadsCount) {
                                $Aff | Where-Object {$_ -notin $AffThreads} | Sort-Object {$_ -band 1},{$_} | Select-Object -First ($ThreadsCount-$AffThreads.Count) | Foreach-Object {$AffThreads += $_}
                            }
                            $Parameters.Config.$Device.$Algo = @($AffThreads | Sort-Object);
                        }
                        if ($cix.Count) {
                            for ($i=0; $i -lt $Parameters.Config.$Device.$Algo.Count; $i++) {
                                $thr = $Parameters.Config.$Device.$Algo[$i]
                                $Parameters.Config.$Device.$Algo[$i] = @($(if ($cix["k$thr"]) {$cix["k$thr"]} else {1}),$thr)
                            }
                        }
                        $Parameters.Config | Add-Member cuda   ([PSCustomObject]@{enabled=$false}) -Force
                        $Parameters.Config | Add-Member opencl ([PSCustomObject]@{enabled=$false}) -Force
                    } else { #device is cuda or opencl
                        $Parameters.Config.$Device | Add-Member $Algo ([Array](@($ThreadsConfig.$Algo | Where-Object {$Parameters.Devices -contains $_.index} | Select-Object) * $Parameters.Threads)) -Force
                        $Parameters.Config | Add-Member cpu ([PSCustomObject]@{enabled=$false}) -Force
                        $Parameters.Config | Add-Member "$(if ($Device -eq "cuda") {"opencl"} else {"cuda"})" ([PSCustomObject]@{enabled=$false}) -Force
                    }
                    $Parameters.Config | Add-Member autosave $false -Force
                    $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Force
                }
                else {
                    Write-Log -Level Warn "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')})"
                }                
            }

            $LastModified = (Get-Item $ConfigFile -ErrorAction Ignore).LastWriteTime

            if (-not (Test-Path $RunConfigFile) -or (Test-Path $RunConfigFile -OlderThan $LastModified)) {
                $RunConfig = Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $RunConfig | Add-Member pools $Parameters.Pools -Force
                foreach ($par in @("algo-perf","rebench-algo","bench-algo-time","algo-min-time")) {
                    if ($par -in $Parameters.Config.PSObject.Properties.Name) {$RunConfig | Add-Member $par $Parameters.Config.$par -Force}
                }
                Set-ContentJson -PathToFile $RunConfigFile -Data $RunConfig > $null
            }
        }
        catch {
            Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
        }


        return ("--algo=$($Parameters.Algorithm) --config=$RunConfigFN $($Parameters.DeviceParams) $($Parameters.APIParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1" #"localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            if ($this.Name -match "^Xlarig") { #temporary fix for bug in windows API in Xlarig v5.2.4
                $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api.json" -Timeout $Timeout -ForceHttpClient -Method "WEB"
                if ($Data -is [string] -and $Data -match "(?smi)^({.+?`"total`":\s*\[.+?\])") {
                    $Data = "$($Matches[1])}}"
                }
            } else {
                $Data = Invoke-GetUrl "http://$($Server):$($this.Port)/api.json" -Timeout $Timeout -ForceHttpClient
            }

            if ($Data -is [string]) {
                $Data = $Data | ConvertFrom-Json -ErrorAction Stop
            }
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner $($this.Name). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}

            $Difficulty_Value = [Double]$Data.results.diff_current
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}

            $Accepted_Shares  = [Double]$Data.results.shares_good
            $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData($Response,$HashRate,$Difficulty)

        $this.CleanupMinerData()
    }
}

class XmrigWrapper : Miner {

    [Void]UpdateMinerData () {
        $MJob = if ($Global:IsLinux) {$this.WrapperJob} else {$this.Job.XJob}
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple -match "^.+?(speed|accepted)\s+(.+?)$") {
                    $Mode  = $Matches[1]
                    $Words = $Matches[2] -split "\s+"
                    if ($Mode -eq "speed") {
                        $HashRate = [PSCustomObject]@{}
                        $Speed = if ($Words[2] -ne "n/a") {$Words[2]} else {$Words[1]}
                        $HashRate_Value  = [double]($Speed -replace ',','.')

                        switch -Regex ($Words[4]) {
                            "k" {$HashRate_Value *= 1E+3}
                            "M" {$HashRate_Value *= 1E+6}
                            "G" {$HashRate_Value *= 1E+9}
                            "T" {$HashRate_Value *= 1E+12}
                            "P" {$HashRate_Value *= 1E+15}
                        }

                        if ($HashRate_Value -gt 0) {
                            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                        }

                        $this.AddMinerData($Line_Simple,$HashRate)
                    } elseif ($Mode -eq "accepted" -and $Words[0] -match "(\d+)/(\d+)") {
                        $Accepted_Shares = [Int64]$Matches[1]
                        $Rejected_Shares = [Int64]$Matches[2]
                        $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                    }
                }
            }
        }
        $MJob = $null
        $this.CleanupMinerData()
    }
}