using module ..\Include.psm1

class Fireice : Miner {

    [String]GetArguments() {
        $Miner_Path       = Split-Path $this.Path
        $Parameters       = $this.Arguments | ConvertFrom-Json
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
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -LogPath $this.LogFile -WorkingDirectory $Miner_Path -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper")
                if ($Job.Process | Get-Job -ErrorAction SilentlyContinue) {
                    $wait = 0
                    $Job | Add-Member HasOwnMinerWindow $true -Force
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
                        if ((-not $MiningProcess -and $this.Process.State -eq "Running") -or ($MiningProcess -and ($MiningProcess | Where-Object {-not $_.HasExited} | Measure-Object).Count -eq 1)) {$wait++} else {break}
                    }
                }
                Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"
                Remove-Variable "Job"
            }

            if (-not (Test-Path $DeviceConfigFile)) {
                if (Test-Path $LegacyDeviceConfigFile) {$HwConfigFN = $LegacyDeviceConfigFN;$HwConfigFile = $LegacyDeviceConfigFile}

                $ThreadsConfigJson = Get-Content $HwConfigFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($Miner_Vendor -eq "CPU") {
                    if ($Parameters.Affinity -ne $null) {
                        $FirstCpu = $ThreadsConfigJson.cpu_threads_conf | Select-Object -First 1 | ConvertTo-Json -Compress
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

        $Difficulty_Value = [Double]$Data.results.diff_current
        $Accepted_Shares  = [Double]$Data.results.shares_good
        $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)

        $HashRate_Name = [String]$this.Algorithm[0]
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