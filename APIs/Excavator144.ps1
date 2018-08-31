using module ..\Include.psm1

class Excavator144 : Miner {
    hidden static [System.Management.Automation.Job]$Service
    hidden [DateTime]$BeginTime = 0
    hidden [DateTime]$EndTime = 0
    hidden [Array]$Workers = @()
    hidden [Int32]$Service_Id = 0

    [String[]]GetProcessNames() {
        return @()
    }

    [String[]]GetExecNames() {
        return @()
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
            if ([Excavator144]::Service.Id -eq $this.Service_Id) {
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
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus([MinerStatus]::Failed)
            return
        }

        $Data_Algorithms = @($Data.algorithms | Select-Object @{"Name" = "ID"; "Expression" = {$_.algorithm_id}}, @{"Name" = "Name"; "Expression" = {$_.name}}, @{"Name" = "Address1"; "Expression" = {$_.pools[0].address}}, @{"Name" = "Login1"; "Expression" = {$_.pools[0].login}}, @{"Name" = "Address2"; "Expression" = {$_.pools[1].address}}, @{"Name" = "Login2"; "Expression" = {$_.pools[1].login}})
        $Arguments_Algorithms = @()

        ($this.Arguments | ConvertFrom-Json) | Where-Object Method -Like "*.add" | ForEach-Object {
            $Argument = $_

            switch ($Argument.method) {
                "algorithm.add" {
                    $Argument_Algorithm = $Argument | Select-Object @{"Name" = "ID"; "Expression" = {""}}, @{"Name" = "Name"; "Expression" = {$_.params[0]}}, @{"Name" = "Address1"; "Expression" = {if ($_.params[1]) {$_.params[1]}else {"benchmark"}}}, @{"Name" = "Login1"; "Expression" = {if ($_.params[2]) {$_.params[2]}else {"benchmark"}}}, @{"Name" = "Address2"; "Expression" = {if ($_.params[3]) {$_.params[3]}else {"benchmark"}}}, @{"Name" = "Login2"; "Expression" = {if ($_.params[4]) {$_.params[4]}else {"benchmark"}}}
                    $Algorithm_ID = $Data_Algorithms | Where-Object Name -EQ $Argument_Algorithm.Name | Where-Object Address1 -EQ $Argument_Algorithm.Address1 | Where-Object Login1 -EQ $Argument_Algorithm.Login1 | Where-Object Address2 -EQ $Argument_Algorithm.Address2 | Where-Object Login2 -EQ $Argument_Algorithm.Login2 | Select-Object -ExpandProperty ID -First 1

                    if (-not "$Algorithm_ID") {
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
                            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                            $this.SetStatus([MinerStatus]::Failed)
                            return
                        }

                        $Algorithm_ID = $Data.algorithm_id
                    }

                    if ("$Algorithm_ID") {
                        $Argument_Algorithm.ID = "$Algorithm_ID"
                        $Data_Algorithms += $Argument_Algorithm
                        $Arguments_Algorithms += $Argument_Algorithm
                    }
                }
                "worker.add" {
                    $Argument.params[0] = "$($Arguments_Algorithms[$Argument.params[0]].ID)"
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
                        Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                        return
                    }

                    if ("$($Data.worker_id)") {
                        $this.Workers += "$($Data.worker_id)"
                    }
                }
                "workers.add" {
                    $Argument.params = @(
                        $Argument.params | ForEach-Object {
                            if ($_ -like "alg-*") {
                                "alg-$($Arguments_Algorithms[$_.TrimStart("alg-")].ID)"
                            }
                            else {
                                $_
                            }
                        }
                    )
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
                        Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
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
                        Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                        return
                    }
                }
            }
        }

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
            if ($this.GetActiveTime().TotalSeconds -gt 60 -or -not (Get-Process -Name ($this.GetProcessNames()))) {
                Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                $this.SetStatus([MinerStatus]::Failed)
            }
            return
        }   

        if (($this.Data).count -eq 0) {
            #Resets logged speed of worker to 0 for more accurate hashrate reporting
            $Request = @{id = 1; method = "worker.reset"; params = @($this.Workers)} | ConvertTo-Json -Compress

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
                if ($this.GetActiveTime().TotalSeconds -gt 60 -or -not (Get-Process -Name ($this.GetProcessNames()))) {
                    Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                    $this.SetStatus([MinerStatus]::Failed)
                }
                return
            }   
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
            if ([Excavator144]::Service.Id -eq $this.Service_Id) {
                # Free workers for this device
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
                #Print message
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
                    if ($this.GetActiveTime().TotalSeconds -gt 60 -or -not (Get-Process -Name ($this.GetProcessNames()))) {
                        Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
                        $this.SetStatus([MinerStatus]::Failed)
                    }
                    return
                }   

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
                $Algorithms = @($Data.algorithms)

                #Clear all unused algorithms
                $Algorithms | Where-Object {-not $_.Workers.Count} | ForEach-Object {
                    $Request = @{id = 1; method = "algorithm.clear"; params = @($_.Name)} | ConvertTo-Json -Compress
                    $Response = ""

                    $HashRate = [PSCustomObject]@{}

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
        if ([Excavator144]::Service.MiningProcess) {
            return [Excavator144]::Service.MiningProcess.Id;
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

        if (-not [Excavator144]::Service) {
            $LogFile = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Logs\Excavator-$($this.Port)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt")
            [Excavator144]::Service = Start-SubProcess -FilePath $this.Path -ArgumentList "-p $($this.Port) -f 0 -fn `"$($LogFile)`"" -LogPath $this.LogFile -WorkingDirectory (Split-Path $this.Path) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {-2}else {1}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -ProcessName $this.ExecName

            #Wait until excavator is ready, max 10 seconds
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

        if ($this.Service_Id -ne [Excavator144]::Service.Id) {
            $this.Status = [MinerStatus]::Idle
            $this.Workers = @()
            $this.Service_Id = [Excavator144]::Service.Id
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
                if ([Excavator144]::Service.MiningProcess) {
                    [Excavator144]::Service.MiningProcess.CloseMainWindow() | Out-Null
                    # Wait up to 10 seconds for the miner to close gracefully
                    $closedgracefully = [Excavator144]::Service.MiningProcess.WaitForExit(10000)
                    if($closedgracefully) { 
                        Write-Log "$($this.Type) miner $($this.Name) closed gracefully" 
                    } else {
                        Write-Log -Level Warning "$($this.Type) miner $($this.Name) failed to close within 10 seconds"
                        if(![Excavator144]::Service.MiningProcess.HasExited) {
                            Write-Log -Level Warning "Attempting to kill $($this.Type) miner $($this.Name) PID $($this.Process.Id)"
                            [Excavator144]::Service.MiningProcess.Kill()
                        }
                    }
                }
                if ([Excavator144]::Service | Get-Job -ErrorAction SilentlyContinue) {
                    [Excavator144]::Service | Remove-Job -Force
                }

                if (-not ([Excavator144]::Service | Get-Job -ErrorAction SilentlyContinue)) {
                    [Excavator144]::Service = $null
                }

                $this.Status = $Status
                $this.StopMiningPostProcess()
            }
        }
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
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
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
            $this.SetStatus([MinerStatus]::Failed)
            return @($Request, $Response)
        }

        $Data.algorithms.name | Select-Object -Unique | ForEach-Object {
            $Workers = @(($Data.algorithms | Where-Object name -EQ $_).workers)
            $Algorithms = $_ -split "_"
            $Algorithms | ForEach-Object {
                $Algorithm = $_

                $HashRate_Name = [String]($this.Algorithm -match (Get-Algorithm $Algorithm))
                if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -match "$(Get-Algorithm $Algorithm)*")} #temp fix
                $HashRate_Value = [Double](($Workers | Where-Object {$this.Workers -like $_.worker_id}).speed | Select-Object -Index @($Workers.worker_id | ForEach-Object {$_ * 2 + $Algorithms.IndexOf($Algorithm)}) | Measure-Object -Sum).Sum
                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
                }
            }
        }

        $Request = @{id = 1; method = "algorithm.print.speeds"; params = @()} | ConvertTo-Json -Compress

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
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
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