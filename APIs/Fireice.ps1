using module ..\Include.psm1

class Fireice : Miner {

    [String]GetArguments() {
        $Miner_Path = Split-Path $this.Path
        $Parameters = $this.Arguments | ConvertFrom-Json
        $Miner_Vendor = $Parameters.Vendor
        $ConfigFile = "common_$($this.Pool -join'-')-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($Parameters.Config.pool_list[0].use_tls){"-ssl"}).txt"
        $HwConfigFile = "config_$($Miner_Vendor.ToLower())-$(($Global:Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $this.DeviceModel | Select-Object -ExpandProperty Name | Sort-Object) -join '-').txt"
        $DeviceConfigFile = "$($Miner_Vendor.ToLower())_$($this.BaseAlgorithm -join '-')-$($this.DeviceName -join '-').txt"

        ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $this.Path)\$ConfigFile" -ErrorAction Ignore -Encoding UTF8 -Force
        
        if (-not (Test-Path "$Miner_Path\$DeviceConfigFile")) {
            if ($Miner_Vendor -eq "CPU") {
                if (Test-Path "$Miner_Path\cpu.txt") {Copy-Item "$Miner_Path\cpu.txt" "$Miner_Path\$DeviceConfigFile" -Force}
            } else {
                try {
                    if (-not (Test-Path "$Miner_Path\$HwConfigFile")) {
                        Remove-Item "$Miner_Path\config_$($Miner_Vendor.ToLower())-*.txt" -Force -ErrorAction Ignore
                        $ArgumentList = "-C $ConfigFile --$($Miner_Vendor.ToLower()) $HwConfigFile $($Parameters.Params)".Trim()
                        $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -LogPath $this.LogFile -WorkingDirectory $Miner_Path -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -ProcessName $this.ExecName -IsWrapper ($this.API -eq "Wrapper")
                        if ($Job.Process | Get-Job -ErrorAction SilentlyContinue) {
                            $wait = 0
                            $Job | Add-Member HasOwnMinerWindow $true -Force
                            While (-not (Test-Path "$Miner_Path\$HwConfigFile") -and $wait -lt 60) {
                                Start-Sleep -Milliseconds 500
                                $wait++
                            }
                        }
                        Stop-SubProcess -Job $Job -Title "Miner $($this.Name) (prerun)"
                        Remove-Variable "Job"
                    }
                    $LegacyDeviceConfigFile = "$($Miner_Vendor.ToLower())-$($this.BaseAlgorithm -join '-').txt"
                    if (Test-Path "$Miner_Path\$LegacyDeviceConfigFile") {$HwConfigFile = $LegacyDeviceConfigFile}
                    $DeviceConfig = @("{$(((Get-Content "$Miner_Path\$HwConfigFile") -replace '^\s*//.*' | Out-String) -replace '\/\*.*' -replace '\*\/' -replace '\*.+' -replace '\s' -replace ',\},]','}]' -replace ',\},\{','},{' -replace '},]', '}]' -replace ',$','')}" | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty gpu_threads_conf | Where-Object {$Parameters.Devices -contains $_.index} | Select-Object)
                    $DeviceConfig | Where-Object bfactor -eq 6 | Foreach-Object {$_.bfactor = 8}
                    if ($DeviceConfig) {"`"gpu_threads_conf`": $(ConvertTo-Json $DeviceConfig -Depth 10)," | Set-Content "$Miner_Path\$DeviceConfigFile" -Force}
                }
                catch {
                    Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
                }
            }
        }

        return "-C $ConfigFile --$($Miner_Vendor.ToLower()) $DeviceConfigFile $($Parameters.Params)".Trim()
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

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

        $Accepted_Shares = [Double]$Data.results.shares_good
        $Rejected_Shares = [Double]($Data.results.shares_total - $Data.results.shares_good)

        $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $Data.algo))
        if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
        if (-not $HashRate_Name) {$HashRate_Name = [String]$this.Algorithm[0]} #fireice fix
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        })

        $this.CleanupMinerData()

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}