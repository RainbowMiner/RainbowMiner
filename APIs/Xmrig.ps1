using module ..\Include.psm1

class Xmrig : Miner {

    [String]GetArguments() {
        if ($this.Arguments -notlike "{*}") {return $this.Arguments}

        $Miner_Path        = Split-Path $this.Path
        $Parameters        = $this.Arguments | ConvertFrom-Json
        $ConfigFN          = "config_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($this.DeviceName -like "GPU*") {"-$(($Parameters.Devices | %{"{0:x}" -f $_}) -join '')"})_$($this.Port)-$($Parameters.Threads).json"
        $ThreadsConfigFN   = "threads_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig).json"
        $ConfigFile        = Join-Path $Miner_Path $ConfigFN
        $ThreadsConfigFile = Join-Path $Miner_Path $ThreadsConfigFN
        $ThreadsConfig     = $null
        $LogFile           = Join-Path $Miner_Path "log_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig).txt"

        try {
            if (Test-Path $ThreadsConfigFile) {
                $ThreadsConfig = Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            if (-not ($ThreadsConfig | Measure-Object).Count) {
                $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ThreadsConfigFile -Force

                $ArgumentList = ("$($Parameters.PoolParams) --config=$ThreadsConfigFN $($Parameters.DeviceParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -WorkingDirectory $Miner_Path -LogPath $LogFile -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper")
                if ($Job.Process | Get-Job -ErrorAction SilentlyContinue) {
                    $wait = 0
                    $Job | Add-Member HasOwnMinerWindow $true -Force
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
                        if ((-not $MiningProcess -and $this.Process.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq 1)) {$wait++} else {break}
                    }
                }
                if ($Job) {
                    Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"
                    Remove-Variable "Job"
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
                    Write-Log -Level Warn "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')})$(if ($Error.Count){"[Error: '$($Error[0])'].";$Error.RemoveAt(0)})"
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

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api.json" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares  = [Double]$Data.results.shares_good
        $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
        $Difficulty_Value = [Double]$Data.results.diff_current
        
        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }
                
        $this.AddMinerData([PSCustomObject]@{
            Raw        = $Response
            HashRate   = $HashRate
            Difficulty = $Difficulty
            Device     = @()
        })

        $this.CleanupMinerData()
    }
}