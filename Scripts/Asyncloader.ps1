param($CurrentPwd)

Set-Location $CurrentPwd

if ($AsyncLoader.Debug -and -not $psISE -and $Session.LogLevel -ne "Silent") {Start-Transcript ".\Logs\AsyncLoader_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"}

$ProgressPreference = "SilentlyContinue"

Import-Module ".\Modules\Include.psm1"
Import-Module ".\Modules\MiningRigRentals.psm1"

Set-OsFlags

$Cycle = -1

$StopWatch = [System.Diagnostics.StopWatch]::New()

$AsyncLoader_Paused = $AsyncLoader.Pause

$Hosts_LastCall = [hashtable]@{}

while (-not $AsyncLoader.Stop) {

    $StopWatch.Restart()
    $Cycle++
    $AsyncLoader.Timestamp = (Get-Date).ToUniversalTime()

    if ($AsyncLoader.Verbose) {
        Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Start cycle" -Append -Timestamp
    }

    if (-not ($Cycle % 3)) {
        $Session.SysInfo = Get-SysInfo
    }

    if (-not $AsyncLoader.Pause -and $AsyncLoader.Jobs.Count) {

        $JobKeys = @($AsyncLoader.Jobs.Keys | Sort-Object {$AsyncLoader.Jobs.$_.Index} | Select-Object)

        foreach ($JobKey in $JobKeys) {

            if ($AsyncLoader.Pause) {
                break
            }

            $Job = $AsyncLoader.Jobs.$JobKey

            if (-not $Job) {
                continue
            }

            if ($Job.CycleTime -le 0) {$Job.CycleTime = $AsyncLoader.Interval}

            $JobFailRetry = $false

            $Now = (Get-Date).ToUniversalTime()

            if (-not $Job.LastCacheWrite -or (($Job.LastCacheWrite -lt $Job.LastRequest) -and ($Job.LastCacheWrite -lt $Now.AddSeconds(-600-$Job.CycleTime)))) {
                $RetryTime = if ($Job.LastFailCount -le 3) {600} elseif ($Job.LastFailCount -le 6) {1800} elseif ($Job.LastFailCount -le 10) {3600} else {10800}
                if (-not $Job.LastFailRetry -or ($Job.LastFailRetry -le $Now.AddSeconds(-$RetryTime))) {
                    $Job.LastFailRetry = (Get-Date).ToUniversalTime()
                    $Job.LastFailCount++
                    $JobFailRetry = $true
                }
            } else {
                $Job.LastFailCount = 0
            }

            if (-not $AsyncLoader.Pause -and $Job -and -not $Job.Running -and -not $Job.Paused -and ($JobFailRetry -or ($Job.LastRequest -le $Now.AddSeconds(-$Job.CycleTime)))) {
                if ($AsyncLoader.Verbose) {
                    Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Start job $JobKey with $($Job.Url) using $($Job.Method)" -Append -Timestamp
                }
                try {
                    if ($Job.Tag -eq "MiningRigRentals" -and $Job.endpoint) {
                        Invoke-MiningRigRentalRequestAsync -Jobkey $Jobkey -force -quiet > $null
                    } else {
                        $JobDelay = 0
                        $JobHost  = $Job.Host
                        if ($JobHost) {
                            if ($AsyncLoader.HostDelays.$JobHost -and $Hosts_LastCall.$JobHost) {
                                $JobDelay = [Math]::Min([Math]::Max([Math]::Round($AsyncLoader.HostDelays.$JobHost - ((Get-Date).ToUniversalTime() - $Hosts_LastCall.$JobHost).TotalMilliseconds,0),0),5000)
                                if ($JobDelay -and $AsyncLoader.Verbose) {
                                    Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Delay for $($JobDelay) milliseconds" -Append -Timestamp
                                }
                            }
                        }

                        Invoke-GetUrlAsync -Jobkey $Jobkey -delay $JobDelay -force -quiet > $null

                        if ($JobHost) {
                            $Hosts_LastCall.$JobHost = $Job.LastRequest
                        }
                    }
                    if ($AsyncLoader.Jobs.$Jobkey.Error) {Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Error job $JobKey with $($Job.Url) using $($Job.Method): $($AsyncLoader.Jobs.$Jobkey.Error)" -Append -Timestamp}
                }
                catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Catch error job $JobKey with $($Job.Url) using $($Job.Method): $($_.Exception.Message)" -Append -Timestamp
                }
                finally {
                    if ($AsyncLoader.Verbose) {
                        Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Done job $JobKey with $($Job.Url) using $($Job.Method)" -Append -Timestamp
                    }
                }
            }
        }
    }
    if ($Error.Count)  {if ($Session.LogLevel -ne "Silent") {$Error | Foreach-Object {Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "$($_.Exception.Message)" -Append -Timestamp}};$Error.Clear()}

    $Delta = [Math]::Min([Math]::Max($AsyncLoader.CycleTime-$StopWatch.Elapsed.TotalSeconds,1),30)

    if ($AsyncLoader.Verbose) {
        Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "End cycle $(if ($Delta -gt 0) {"(wait $Delta s)"})" -Append -Timestamp
    }

    if ($AsyncLoader.Pause -ne $AsyncLoader_Paused) {
        $AsyncLoader_Paused = $AsyncLoader.Pause
        Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "$(if ($AsyncLoader_Paused) {"Stopping asyncloader due to"} else {"Restarting asyncloader after"}) pause" -Append -Timestamp
    }

    if ($Delta -gt 0)  {Start-Sleep -Milliseconds ($Delta*1000)}
}

if ($AsyncLoader.Debug) {Stop-Transcript}