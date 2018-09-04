using module ..\Include.psm1

class Excavator : Miner {
    hidden static [System.Management.Automation.Job]$Service
    hidden [DateTime]$BeginTime = 0
    hidden [DateTime]$EndTime = 0
    hidden [Array]$Workers = @()
    hidden [Int32]$Service_Id = 1

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

        if ($this.Status -ne [MinerStatus]::Idle) {
            return
        }

        $this.Status = [MinerStatus]::Running

        $this.BeginTime = Get-Date

        if ($this.Workers) {
            if ([Excavator]::Service.Id -eq $this.Service_Id) {
                # Free all workers for this device
                $Request = @{id = 1; method = "workers.free"; params = $this.Workers} | ConvertTo-Json -Compress
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                       $this.SetStatus([MinerStatus]::Failed)
                    }
                }
                catch {
                    Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus([MinerStatus]::Failed)
                    return
                }
            }
        }

        # Subscribe to Nicehash        
        $Request = ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "subscribe" | Select-Object -Index 0 | ConvertTo-Json -Depth 10 -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus([MinerStatus]::Failed)
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus([MinerStatus]::Failed)
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus([MinerStatus]::Failed)
            return
        }

        # Build list of all algorithms
        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus([MinerStatus]::Failed)
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus([MinerStatus]::Failed)
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus([MinerStatus]::Failed)
            return
        }
        $Algorithms = @($Data.algorithms.Name)

        ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "*.add" | ForEach-Object {
            $Argument = $_

            switch ($Argument.method) {
                #Add algorithms so it will receive new jobs
                "algorithm.add" {
                    if ($Algorithms -notcontains $Argument.params) {
                        $Request = $Argument | ConvertTo-Json -Compress

                        try {
                            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                            if ($Data.id -ne 1) {
                                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                                $this.SetStatus([MinerStatus]::Failed)
                            }

                            if ($Data.error) {
                                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                                $this.SetStatus([MinerStatus]::Failed)
                            }
                        }
                        catch {
                            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                            return
                        }

                    }
                }

                "worker.add" {
                    # Add worker for device
                    $Request = $Argument | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus([MinerStatus]::Failed)
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                        return
                    }

                    if ("$($Data.worker_id)") {
                        $this.Workers += "$($Data.worker_id)"
                    }
                }

                #Add workers for device
                "workers.add" {
                    $Request = $Argument | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                        }

                        $Data.Status | ForEach-Object {
                            if ($_.error) {
                                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($_.error)"
                                $this.SetStatus([MinerStatus]::Failed)
                            }
                        }
                    }
                    catch {
                        if ($this.GetActiveTime().TotalSeconds -gt 60) {
                            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                        }
                        return
                    }

                    $Data.Status | Where-Object {"$($_.worker_id)"} | ForEach-Object {
                        $this.Workers += "$($_.worker_id)"
                    }
                }
                Default {
                    $Request = $Argument | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus([MinerStatus]::Failed)
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                        return
                    }
                }
            }
        }

        # Worker started message
        $Request = @{id = 1; method = "message"; params = @("Worker [$($this.Workers -join "&")] for miner $($this.Name) started. ")} | ConvertTo-Json -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus([MinerStatus]::Failed)
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus([MinerStatus]::Failed)
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus([MinerStatus]::Failed)
            return
        }
    }

    hidden StopMining() {
        $Server = "localhost"
        $Timeout = 10 #seconds

        if ($this.Status -ne [MinerStatus]::Running) {
            return
        }

        $this.Status = [MinerStatus]::Idle

        if ($this.Workers) {
            if ([Excavator]::Service.Id -eq $this.Service_Id) {
                
                #Get algorithm list
                $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus([MinerStatus]::Failed)
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus([MinerStatus]::Failed)
                    return
                }
                $Algorithms = @($Data.algorithms.Name)

                # Free workers for this device
                $Request = @{id = 1; method = "workers.free"; params = $this.Workers} | ConvertTo-Json -Compress
                $Response = ""
                $HashRate = [PSCustomObject]@{}

                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus([MinerStatus]::Failed)
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus([MinerStatus]::Failed)
                    return
                }

                #Get worker list
                $Request = @{id = 1; method = "worker.list"; params = @()} | ConvertTo-Json -Compress

                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus([MinerStatus]::Failed)
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus([MinerStatus]::Failed)
                    return
                }
                $Active_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -icontains $_}
                $Unused_Algorithms = $Algorithms | Select-Object -Unique |  Where-Object {$Data.workers.algorithms.name -inotcontains $_}

                if ($Unused_Algorithms) {
                    #Remove unused algorithms
                    $Request = @{id = 1; method = "algorithm.remove"; params = @($Unused_Algorithms)} | ConvertTo-Json -Compress

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus([MinerStatus]::Failed)
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                        return
                    }
                }


                # Worker stopped message
                $Request = @{id = 1; method = "message"; params = @("Worker [$($this.Workers -join "&")] for miner $($this.Name) stopped. ")} | ConvertTo-Json -Compress
                try {
                    $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                    $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                    if ($Data.id -ne 1) {
                        Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                    }

                    if ($Data.error) {
                        Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                        $this.SetStatus([MinerStatus]::Failed)
                    }
                }
                catch {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus([MinerStatus]::Failed)
                    return
                }

                if (-not $Active_Algorithms) {
                    if ($true) {
                        #Stop miner, this will also unsubscribe
                        $Request = @{id = 1; method = "miner.stop"; params = @()} | ConvertTo-Json -Compress
                    }
                    else{
                        #Quit miner
                        $Request = @{id = 1; method = "quit"; params = @()} | ConvertTo-Json -Compress
                    }
                    $Response = ""

                    $HashRate = [PSCustomObject]@{}

                    try {
                        $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
                        $Data = $Response | ConvertFrom-Json -ErrorAction Stop

                        if ($Data.id -ne 1) {
                            Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                        }

                        if ($Data.error) {
                            Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                            $this.SetStatus([MinerStatus]::Failed)
                        }
                    }
                    catch {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                        return
                    }
                }
            }
        }
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
        if ([Excavator]::Service.MiningProcess) {
            return [Excavator]::Service.MiningProcess.Id;
        } else {
            return 0;
        }
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
            [Excavator]::Service = Start-SubProcess -FilePath $this.Path -ArgumentList "-d 2 -p $($this.Port) -wp $([Int]($this.Port) + 1) -f 0 -fn `"$($LogFile)`"" -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {-2}else {1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -ProcessName $this.ExecName
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
        if ([Excavator]::Service.MiningProcess) {
            [Excavator]::Service.MiningProcess.CloseMainWindow() | Out-Null
            # Wait up to 10 seconds for the miner to close gracefully
            $closedgracefully = [Excavator]::Service.MiningProcess.WaitForExit(10000)
            if($closedgracefully) { 
                Write-Log "$($this.Type) miner $($this.Name) closed gracefully" 
            } else {
                Write-Log -Level Warn "$($this.Type) miner $($this.Name) failed to close within 10 seconds"
                if(![Excavator]::Service.MiningProcess.HasExited) {
                    Write-Log -Level Warn "Attempting to kill $($this.Type) miner $($this.Name) PID $($this.Process.Id)"
                    [Excavator]::Service.MiningProcess.Kill()
                }
            }
        }

        if ([Excavator]::Service | Get-Job -ErrorAction SilentlyContinue) {
            [Excavator]::Service | Remove-Job -Force
        }

        if (-not ([Excavator]::Service | Get-Job -ErrorAction SilentlyContinue)) {
            [Excavator]::Service = $null
        }
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds
        $HashRate = [PSCustomObject]@{}

        #Get list of all active workers
        $Request = @{id = 1; method = "worker.list"; params = @()} | ConvertTo-Json -Compress
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
            if ($this.GetActiveTime().TotalSeconds -gt 60) {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                $this.SetStatus([MinerStatus]::Failed)
            }
            return @($Request, $Response)
        }

        #Get hash rates per algorithm
        $Data.workers.algorithms.name | Select-Object -Unique | ForEach-Object {
            $Workers = $Data.workers | Where-Object {$this.workers -match $_.Worker_id}
            $Algorithm = $_

            $HashRate_Name = [String](($this.Algorithm -replace "-NHMP") -match (Get-Algorithm $Algorithm))
            if (-not $HashRate_Name) {$HashRate_Name = [String](($this.Algorithm -replace "-NHMP") -match "$(Get-Algorithm $Algorithm)*")} #temp fix
            $HashRate_Value = [Double](($Workers.algorithms | Where-Object {$_.name -eq $Algorithm}).speed | Measure-Object -Sum).Sum
            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{"$($HashRate_Name)-NHMP" = [Int64]$HashRate_Value}
            }
        }

        #Print algorithm speeds
        $Request = @{id = 1; method = "algorithm.print.speeds"; params = @()} | ConvertTo-Json -Compress
        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop

            if ($Data.id -ne 1) {
                Write-Log -Level Error  "Invalid response returned by miner ($($this.Name)). "
                $this.SetStatus([MinerStatus]::Failed)
            }

            if ($Data.error) {
                Write-Log -Level Error  "Error returned by miner ($($this.Name)): $($Data.error)"
                $this.SetStatus([MinerStatus]::Failed)
            }
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus([MinerStatus]::Failed)
        }

        $this.Data += [PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
            Device   = @()
        }

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}