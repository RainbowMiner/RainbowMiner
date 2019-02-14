using module ..\Include.psm1

class Excavator : Miner {
    hidden static [System.Management.Automation.Job]$Service
    hidden static [Int]$ServiceId = 0
    hidden [DateTime]$BeginTime = 0
    hidden [DateTime]$EndTime = 0
    hidden [Array]$Workers = @()
    hidden [Array]$Algorithm_IDs = @()
    hidden [Int32]$Service_Id = 1

    static [PSCustomObject]InvokeRequest($Miner, $Request) {
        $Server = "localhost"
        $Timeout = 10 #seconds

        try {
            $Response = Invoke-TcpRequest $Server $Miner.Port ($Request | ConvertTo-Json -Compress) $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($Miner.Name)). "
                $Miner.SetStatus("Failed")
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($Miner.Name)): $($Data.error)"
                $Miner.SetStatus("Failed")
            }
        }
        catch {
            Write-Log -Level Error  "Failed to connect to miner ($($Miner.Name)). "
            $Miner.SetStatus("Failed")
            return $null
        }
        return $Data
    }

    static WriteMessage($Miner, $Message) {
        $Data = [Excavator]::InvokeRequest($Miner, @{id = 1; method = "message"; params = @($Message)})
    }

    [String[]]GetProcessNames() {
        return @()
    }

    [String[]]GetExecNames() {
        return @()
    }

    [String]GetMinerDeviceName() {
        return $this.BaseName
    }

    hidden StartMining() {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $this.New = $true
        $this.Activated++
        $this.Rounds = 0

        if ($this.Status -ne [MinerStatus]::Idle) {
            return
        }

        $this.Status = [MinerStatus]::Running

        $this.BeginTime = Get-Date

        [Excavator]::WriteMessage($this, "Starting worker for miner $($this.Name) ")

        if ($this.Workers) {
            if ([Excavator]::Service.Id -eq $this.Service_Id) {
                #Free all workers for this device
                $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "workers.free"; params = @($this.Workers)})
            }
        }

        #Subscribe to Nicehash        
        $Request = ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "subscribe" | Select-Object -Index 0
        $Data = [Excavator]::InvokeRequest($this, $Request)

        #Build list of all algorithms
        $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "algorithm.list"; params = @()})
        $Algorithms = @($Data.algorithms.name)

        ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "*.add" | ForEach-Object {
            $Argument = @($_)

            switch ($Argument.method) {
                #Add algorithms so it will receive new jobs
                "algorithm.add" {
                    if ($Algorithms -notcontains $Argument.params) {
                        $Data = [Excavator]::InvokeRequest($this, $Argument)
                    }
                }

                #Add workers for device
                "workers.add" {
                    $Data = [Excavator]::InvokeRequest($this, $Argument)
                    $Data.Status | Where-Object {"$($_.worker_id)"} | ForEach-Object {
                        $this.Workers += "$($_.worker_id)"
                    }
                }

                Default {
                    $Data = [Excavator]::InvokeRequest($this, $Argument)
                }
            }
        }

        #Get Algorithm ID list for current miner
        $WorkerList = [Excavator]::InvokeRequest($this, @{id = 1; method = "worker.list"; params = @()})
        $this.Algorithm_IDs = @(($WorkerList.workers | Where-Object {$this.Workers -contains $_.worker_id}).algorithms.id) | Select-Object -Unique
        
        #Worker started message
        if ($this.Algorithm_IDs) {
            [Excavator]::WriteMessage($this, "Worker [$($this.Workers -join " ")] for miner $($this.Name) started. ")
        }
    }

    hidden StopMining() {
        $Server = "localhost"
        $Timeout = 10 #seconds

        $this.Data.Clear()

        if ($this.Status -ne [MinerStatus]::Running) {
            return
        }

        $this.Status = [MinerStatus]::Idle

        if ($this.Workers) {
            if ([Excavator]::Service.Id -eq $this.Service_Id) {
                
                #Get algorithm list
                $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "algorithm.list"; params = @()})
                $Algorithms = @($Data.algorithms.Name)

                #Free workers for this device
                $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "workers.free"; params = @($this.Workers)})

                #Worker stopped message
                [Excavator]::WriteMessage($this, "Worker [$($this.Workers -join " ")] for miner $($this.Name) stopped. ")

                #Get worker list
                $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "worker.list"; params = @()})
                $Active_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -icontains $_}
                $Unused_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -inotcontains $_}

                $Unused_Algorithms | ForEach-Object {
                    #Remove unused algorithm
                    $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "algorithm.remove"; params = @($_)})

                    #Algorithm cleared message
                    [Excavator]::WriteMessage($this, "Unused algorithm [$_] cleared. ")
                }

                if (-not $Active_Algorithms) {
                    if ($true) {
                        #Stop miner, this will also unsubscribe
                        $Request = @{id = 1; method = "miner.stop"; params = @()}
                    }
                    else{
                        #Quit miner
                        $Request = @{id = 1; method = "quit"; params = @()}
                    }
                    $Data = [Excavator]::InvokeRequest($this, $Request)
                }
            }
        }
    }

    StopMiningPostCleanup() {

        $Server = "localhost"
        $Timeout = 10
       
        if ([Excavator]::Service | Get-Job -ErrorAction Ignore) {
            #Get algorithm list
            $Failed = $false
            $Data = [PSCustomObject]@{}
            $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
            try {
                $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                if ($Data.id -ne 1) {
                    Write-Log -Level Warn  "Invalid response returned by miner ($($this.Name)). "
                    $Failed = $true
                }

                if ($Data.error) {
                    Write-Log -Level Warn  "Error returned by miner ($($this.Name)): $($Data.error)"
                    $Failed = $true
                }
            }
            catch {
                Write-Log -Level Warn "Failed to connect to miner ($($this.Name)). "
                $Failed = $true
            }

            if (-not $Failed -and -not $Data.algorithms) {
                #Quit miner
                $Request = @{id = 1; method = "quit"; params = @()} | ConvertTo-Json -Compress
                $Response = ""

                $HashRate = [PSCustomObject]@{}
                $Failed = $false

                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Warn  "Invalid response returned by miner ($($this.Name)). "
                        $Failed = $true
                    }

                    if ($Data.error) {
                        Write-Log -Level Warn  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $Failed = $true
                    }
                }
                catch {
                    Write-Log -Level Warn "Failed to connect to miner ($($this.Name)). "
                    $Failed = $true
                }

                Sleep -Milliseconds 500
                $this.ShutdownMiner()
            }
        }
        ([Miner]$this).StopMiningPostCleanup()
    }

    EndOfRoundCleanup() {
        if ([Excavator]::Service.HasMoreData) {[Excavator]::Service | Receive-Job > $null}
        $this.Rounds++
    }

    [DateTime]GetActiveLast() {
        if ($this.BeginTime.Ticks -and $this.EndTime.Ticks) {
            return $this.EndTime
        }
        elseif ($this.BeginTime.Ticks) {
            return Get-Date
        }
        else {
            return [DateTime]::MinValue
        }
    }

    [TimeSpan]GetActiveTime() {
        if ($this.BeginTime.Ticks -and $this.EndTime.Ticks) {
            return $this.Active + ($this.EndTime - $this.BeginTime)
        }
        elseif ($this.BeginTime.Ticks) {
            return $this.Active + ((Get-Date) - $this.BeginTime)
        }
        else {
            return $this.Active
        }
    }

    [Int]GetActivateCount() {
        return $this.Activated
    }

    [MinerStatus]GetStatus() {
        return $this.Status
    }

    [Int]GetProcessId() {
        return [Excavator]::ServiceId;
    }

    SetStatus([MinerStatus]$Status) {
        if ($Status -eq $this.GetStatus()) {return}

        if ($this.BeginTime.Ticks) {
            if (-not $this.EndTime.Ticks) {
                $this.EndTime = Get-Date
            }

            $this.Active += $this.EndTime - $this.BeginTime
            $this.BeginTime = 0
            $this.EndTime = 0
        }

        if (-not [Excavator]::Service) {
            $LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\Excavator-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            $Job = Start-SubProcess -FilePath $this.Path -ArgumentList "-d 2 -p $($this.Port) -wp $([Int]($this.Port) + 1) -f 0 -fn `"$($LogFile)`"" -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -ProcessName $this.ExecName
            [Excavator]::Service   = $Job.Process
            [Excavator]::ServiceId = $Job.ProcessId
            #Start-Sleep 5
            $Server = "localhost"
            $Timeout = 1
            $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
            $Response = ""
            for($waitforlocalhost=0; $waitforlocalhost -le 10; $waitforlocalhost++) {
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop
                    break
                }
                catch {
                }
            }
        }

        if ($this.Service_Id -ne [Excavator]::Service.Id) {
            $this.Status = [MinerStatus]::Idle
            $this.Workers = @()
            $this.Service_Id = [Excavator]::Service.Id
        }

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
                $this.ShutdownMiner()
                $this.Status = $Status
                $this.StopMiningPostProcess()
            }
        }
    }

    ShutdownMiner() {
        if ([Excavator]::ServiceId) {
            if ($MiningProcess = Get-Process -Id ([Excavator]::ServiceId) -ErrorAction Ignore) {
                $MiningProcess.CloseMainWindow() | Out-Null
                # Wait up to 10 seconds for the miner to close gracefully
                if($MiningProcess.WaitForExit(10000)) { 
                    Write-Log "Miner $($this.Name) closed gracefully" 
                } else {
                    Write-Log -Level Warn "Miner $($this.Name) failed to close within 10 seconds"
                    if(-not $MiningProcess.HasExited) {
                        Write-Log -Level Warn "Attempting to kill miner $($this.Name) PID $($this.Process.Id)"
                        $MiningProcess.Kill()
                    }
                }
            }
            [Excavator]::ServiceId = 0
        }

        if ([Excavator]::Service | Get-Job -ErrorAction Ignore) {
            [Excavator]::Service | Remove-Job -Force
        }

        if (-not ([Excavator]::Service | Get-Job -ErrorAction Ignore)) {
            [Excavator]::Service = $null
        }
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        #Get list of all active algorithms
        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
        $Response = ""
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
            }
        }
        catch {
            return @($Request, $Response)
        }

        #Get hash rates per algorithm
        $Algorithms = $Data.algorithms | Where-Object {$this.Algorithm_IDs -contains $_.Algorithm_id}

        $HashRate = [PSCustomObject]@{}
        $HashRate_Name = ""
        $HashRate_Value = [Int64]0

        $Algorithms | ForEach-Object {
            $HashRate_Name = [String](Get-Algorithm $_.name)

            $Accepted_Shares = [Int64]$_.accepted_shares
            $Rejected_Shares = [Int64]$_.rejected_shares
            $HashRate_Value  = [Int64]$_.Speed

            if ($HashRate_Name -and $HashRate_Value -GT 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
            }
        }

        #Print algorithm speeds
        $Data = [Excavator]::InvokeRequest($this, @{id = 1; method = "algorithm.print.speeds"; params = @()})

        $this.AddMinerData([PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
            Device   = @()
        })

        $this.CleanupMinerData()

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}