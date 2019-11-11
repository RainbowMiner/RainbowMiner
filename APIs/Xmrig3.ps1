using module ..\Include.psm1

class Xmrig3 : Miner {

    [String]GetArguments() {
        $Arguments = ([Miner]$this).GetArguments()
        if ($Arguments -notlike "{*}") {return $Arguments}

        $ThreadsConfig     = $null

        $Miner_Path        = Split-Path $this.Path
        $Parameters        = $Arguments | ConvertFrom-Json

        $ConfigFN          = "config_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig)_$($Parameters.Threads).json"
        $ThreadsConfigFN   = "threads_$($Parameters.HwSig).json"
        $ConfigFile        = Join-Path $Miner_Path $ConfigFN
        $ThreadsConfigFile = Join-Path $Miner_Path $ThreadsConfigFN
        $LogFile           = "log_$($this.BaseAlgorithm -join '-')_$($Parameters.HwSig)_$($Parameters.Threads).txt"

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
                $Job = Start-SubProcess -FilePath $this.Path -ArgumentList $ArgumentList -WorkingDirectory $Miner_Path -LogPath (Join-Path $Miner_Path $LogFile) -Priority ($this.DeviceName | ForEach-Object {if ($_ -like "CPU*") {$this.Priorities.CPU} else {$this.Priorities.GPU}} | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) -ShowMinerWindow $true -IsWrapper ($this.API -eq "Wrapper")
                if ($Job.Process | Get-Job -ErrorAction SilentlyContinue) {
                    $wait = 0
                    $Job | Add-Member HasOwnMinerWindow $true -Force
                    While ($wait -lt 60) {
                        if (($ThreadsConfig = @(Get-Content $ThreadsConfigFile -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore).$Device | Select-Object)) {
                            ConvertTo-Json $ThreadsConfig -Depth 10 | Set-Content $ThreadsConfigFile -Force
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
                    Write-Log -Level Warn "Error parsing threads config file - cannot create miner config file ($($this.Name) {$($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')})$(if ($Error.Count){"[Error: '$($Error[0])'].";$Error.RemoveAt(0)})"
                }                
            }
        }
        catch {
            Write-Log -Level Warn "Creating miner config files failed ($($this.BaseName) $($this.BaseAlgorithm -join '-')@$($this.Pool -join '-')}) [Error: '$($_.Exception.Message)']."
        }

        return ("$($Parameters.DeviceParams) --config=$ConfigFN --algo=$($Parameters.Algorithm) $($Parameters.PoolParams) $($Parameters.APIParams) $($Parameters.Params)" -replace "\s+",' ').Trim()
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