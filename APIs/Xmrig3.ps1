using module ..\Include.psm1

class Xmrig : Miner {

    [String]GetArguments() {
        if ($this.Arguments -notlike "{*}") {return $this.Arguments}

        $Miner_Path        = Split-Path $this.Path
        $Parameters        = $this.Arguments | ConvertFrom-Json
        $ConfigFile        = "config_$($this.BaseAlgorithm -join '-')_$($this.DeviceModel)$(if ($this.DeviceName -like "GPU*") {"_$(($Parameters.Devices | %{"{0:x}" -f $_}) -join '')"})_$($this.Port)-$($Parameters.Threads).json"
        $ThreadsConfigFile = "threads_$($Parameters.HwSig).json"
        $ThreadsConfig     = $null
        $LogFile           = "$Miner_Path\log_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig).txt"
        $Algo              = $Parameters.Algorithm
        $Algo0             = $Parameters.Algorithm -replace "/.+$"
        $Device            = if ($this.DeviceName -like "GPU*") {} else {"cpu"}

        try {
            if (Test-Path "$Miner_Path\$ThreadsConfigFile") {
                $ThreadsConfig = Get-Content "$Miner_Path\$ThreadsConfigFile" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            if (-not ($ThreadsConfig.$Algo | Measure-Object).Count -and -not ($ThreadsConfig.$Algo0 | Measure-Object).Count) {
                $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content "$Miner_Path\$ThreadsConfigFile" -Force

                $ArgumentList = ("$($Parameters.PoolParams) --algo=$Algo --config=$ThreadsConfigFile $($Parameters.Params)" -replace "\s+",' ').Trim()
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -WorkingDirectory $Miner_Path -LogPath $LogFile -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper")
                if ($Job.Process | Get-Job -ErrorAction SilentlyContinue) {
                    $wait = 0
                    $Job | Add-Member HasOwnMinerWindow $true -Force
                    While ($wait -lt 60) {
                        if (($ThreadsConfig = @(Get-Content "$Miner_Path\$ThreadsConfigFile" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).$Device | Select-Object)) {
                            ConvertTo-Json $ThreadsConfig -Depth 10 | Set-Content "$Miner_Path\$ThreadsConfigFile" -Force
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
                if ((Test-Path "$Miner_Path\$ThreadsConfigFile") -and -not ($ThreadsConfig.$Algo | Measure-Object).Count -and -not ($ThreadsConfig.$Algo0 | Measure-Object).Count) {
                    Remove-Item "$Miner_Path\$ThreadsConfigFile" -ErrorAction Ignore -Force
                }
                $ThreadsConfig = Get-Content "$Miner_Path\$ThreadsConfigFile" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            }
            $Config = Get-Content "$Miner_Path\$ConfigFile" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            if (-not $Config.$Device -and -not $Config.$Device.$Algo -and -not $Config.$Device.$Algo0) {
                if ($ThreadsConfig.$Algo -or $ThreadsConfig.$Algo0) {
                    if ($this.DeviceName -like "GPU*") {
                        #$Parameters.Config | Add-Member threads ([Array](@($ThreadsConfig | Where-Object {$Parameters.Devices -contains $_.index} | Select-Object) * $Parameters.Threads)) -Force
                    }
                    else {
                        $Parameters.Config | Add-Member $Device ([PSCustomObject]@{}) -Force
                        $ThreadsConfig.PSObject.Properties | Where-Object {$_.Name -notmatch "/0$" -and $_.Value -isnot [array]} | Foreach-Object {
                            $n = $_.Name; $v = $_.Value
                            $Parameters.Config.$Device | Add-Member $n $v -Force
                        }
                        $Algo = if ($ThreadsConfig.$Algo) {$Algo} else {$Algo0}
                        if ($Parameters.Threads) {
                            $Parameters.Config.$Device | Add-Member $Algo ([array](-1) * $Parameters.Threads) -Force
                        } else {
                            $Parameters.Config.$Device | Add-Member $Algo ([Array]($ThreadsConfig.$Algo)) -Force
                        }
                    }
                    $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content "$Miner_Path\$ConfigFile" -Force
                }
                else {
                    Write-Log -Level Warn "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')})$(if ($Error.Count){"[Error: '$($Error[0])'].";$Error.RemoveAt(0)})"
                }                
            }
        }
        catch {
            Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
        }

        return ("--config=$ConfigFile $($Parameters.PoolParams) --algo=$($Parameters.Algorithm) $($Parameters.DeviceParams) $($Parameters.APIParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

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
            return @($Request, $Response)
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

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}