function Start-AsyncLoader {
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $False)]
    [int]$Interval = 60,
    [Parameter(Mandatory = $False)]
    [bool]$Quickstart = $false
)
    if ($Interval -lt 60) {return}

    if (-not (Test-Path ".\Cache")) {New-Item "Cache" -ItemType "directory" > $null}

    $Global:AsyncLoader = [hashtable]::Synchronized(@{})

    $AsyncLoader.Stop       = $false
    $AsyncLoader.Pause      = $true
    $AsyncLoader.Jobs       = [hashtable]@{}
    $AsyncLoader.CycleTime  = 10
    $AsyncLoader.Interval   = $Interval
    $AsyncLoader.Quickstart = if ($Quickstart) {0} else {-1}
    $AsyncLoader.Verbose    = $false
    $AsyncLoader.Debug      = $Session.LogLevel -eq "Debug"

    $AsyncLoaderScript = {
        param($CurrentPwd)

        Set-Location $CurrentPwd

        if ($AsyncLoader.Debug -and -not $psISE -and $Session.LogLevel -ne "Silent") {Start-Transcript ".\Logs\AsyncLoader_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"}

        $ProgressPreference = "SilentlyContinue"

        Import-Module ".\Modules\Include.psm1"

        Set-OsFlags

        $Cycle = -1

        $StopWatch = [System.Diagnostics.StopWatch]::New()

        while (-not $AsyncLoader.Stop) {
            $StopWatch.Restart()
            $Cycle++

            if ($AsyncLoader.Verbose) {
                Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Start cycle" -Append -Timestamp
            }

            if (-not ($Cycle % 3)) {
                $Session.SysInfo = Get-SysInfo
            }

            if (-not $AsyncLoader.Pause -and $AsyncLoader.Jobs.Count) {

                $JobKeys = @($AsyncLoader.Jobs.Keys | Sort-Object {$AsyncLoader.Jobs.$_.Index} | Select-Object)
                foreach ($JobKey in $JobKeys) {
                    $Job = $AsyncLoader.Jobs.$JobKey

                    if ($Job.CycleTime -le 0) {$Job.CycleTime = $AsyncLoader.Interval}

                    $JobFailRetry = $false

                    $Now = (Get-Date).ToUniversalTime()

                    if (-not $Job.LastCacheWrite -or (($Job.LastCacheWrite -lt $Job.LastRequest) -and ($Job.LastCacheWrite -lt $Now.AddSeconds(-600-$Job.CycleTime)))) {
                        if (-not $Job.LastFailRetry -or ($Job.LastFailRetry -le $Now.AddSeconds(-600))) {
                            $Job.LastFailRetry = (Get-Date).ToUniversalTime()
                            $JobFailRetry = $true
                        }
                    }

                    if (-not $AsyncLoader.Pause -and $Job -and -not $Job.Running -and -not $Job.Paused -and ($JobFailRetry -or ($Job.LastRequest -le $Now.AddSeconds(-$Job.CycleTime)))) {
                        if ($AsyncLoader.Verbose) {
                            Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Start job $JobKey with $($Job.Url) using $($Job.Method)" -Append -Timestamp
                        }
                        try {
                            Invoke-GetUrlAsync -Jobkey $Jobkey -force -quiet
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

            $Delta = $AsyncLoader.CycleTime-$StopWatch.Elapsed.TotalSeconds

            if ($AsyncLoader.Verbose) {
                Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "End cycle $(if ($Delta -gt 0) {"(wait $Delta s)"})" -Append -Timestamp
            }

            if ($Delta -gt 0)  {Start-Sleep -Milliseconds ($Delta*1000)}
        }

        Stop-OpenHardwareMonitor

        if ($AsyncLoader.Debug) {Stop-Transcript}
    }

    # Setup additional, global variables for server handling
    $Global:AsyncLoaderListeners   = [System.Collections.ArrayList]@()

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.SetVariable("Session", $Session)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) > $null

    $newPS = [PowerShell]::Create().AddScript($AsyncLoaderScript).AddParameters(@{'CurrentPwd'=$PWD})
    $newPS.Runspace = $newRunspace

    $Global:AsyncLoaderListeners.Add([PSCustomObject]@{
        Runspace   = $newPS.BeginInvoke()
		PowerShell = $newPS 
    }) > $null
}

function Stop-AsyncLoader {
    if (-not (Test-Path Variable:Global:Asyncloader)) {return}
    $Global:AsyncLoader.Stop = $true

    if ($Global:AsyncLoaderListeners) {
        foreach ($Listener in $Global:AsyncLoaderListeners.ToArray()) {
			$Listener.PowerShell.Dispose()
			$Global:AsyncLoaderListeners.Remove($Listener)
		}
    }
    $Global:AsyncLoaderListeners.Clear()

    Remove-Variable "AsyncLoader" -Scope Global -Force
}

function Stop-AsyncJob {
[cmdletbinding()]   
Param(
   [Parameter(Mandatory = $True)]   
        [string]$tag
)
    if (-not (Test-Path Variable:Global:Asyncloader)) {return}
    foreach ($Jobkey in @($AsyncLoader.Jobs.Keys | Select-Object)) {if ($AsyncLoader.Jobs.$Jobkey.Tag -eq $tag) {$AsyncLoader.Jobs.$Jobkey.Paused=$true}}
}
