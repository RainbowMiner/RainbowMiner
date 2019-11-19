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

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.SetVariable("Session", $Session)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) > $null

    $AsyncLoader.Loader = [PowerShell]::Create().AddScript({        
        Import-Module ".\Include.psm1"

        $ProgressPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"
        $InformationPreference = "SilentlyContinue"

        # Set the starting directory
        if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

        Set-OsFlags

        if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
            [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
        }

        $Cycle = -1

        $StopWatch = New-Object -TypeName System.Diagnostics.StopWatch

        while (-not $AsyncLoader.Stop) {
            $StopWatch.Restart()
            $Cycle++

            if (-not $AsyncLoader.Pause) {
                foreach ($JobKey in @($AsyncLoader.Jobs.Keys | Sort-Object {$AsyncLoader.Jobs.$_.Index} | Select-Object)) {
                    $Job = $AsyncLoader.Jobs.$JobKey
                    if ($Job.CycleTime -le 0) {$Job.CycleTime = $AsyncLoader.Interval}
                    if ($Job -and -not $Job.Running -and -not $Job.Paused -and $Job.LastRequest -le (Get-Date).ToUniversalTime().AddSeconds(-$Job.CycleTime)) {
                        if ($AsyncLoader.Verbose) {
                            Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Start job $JobKey with $($Job.Url) using $($Job.Method)" -Append -Timestamp
                        }
                        try {
                            Invoke-GetUrlAsync -Jobkey $Jobkey -force -quiet
                            if ($AsyncLoader.Jobs.$Jobkey.Error) {Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "$($AsyncLoader.Jobs.$Jobkey.Error)" -Append -Timestamp}
                        }
                        catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Error job $JobKey with $($Job.Url) using $($Job.Method): $($_.Exception.Message)" -Append -Timestamp
                        }
                        finally {
                            if ($AsyncLoader.Verbose) {
                                Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "Done job $JobKey with $($Job.Url) using $($Job.Method)" -Append -Timestamp
                            }
                        }
                    }
                }
                Get-Job -State Completed | Remove-Job -Force
            }
            if ($Error.Count)  {if ($Session.LogLevel -ne "Silent") {$Error | Foreach-Object {Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Message "$($_.Exception.Message)" -Append -Timestamp}};$Error.Clear()}
            $Delta = $AsyncLoader.CycleTime-$StopWatch.Elapsed.TotalSeconds
            if ($Delta -gt 0)  {Start-Sleep -Milliseconds ($Delta*1000)}
        }
    });
    $AsyncLoader.Loader.Runspace = $newRunspace
    $AsyncLoader.Handle = $AsyncLoader.Loader.BeginInvoke()
}

function Stop-AsyncLoader {
    if (-not (Test-Path Variable:Global:Asyncloader)) {return}
    $Global:AsyncLoader.Stop = $true
    if ($Global:AsyncLoader.Loader) {$Global:AsyncLoader.Loader.dispose()}
    $Global:AsyncLoader.Loader = $null
    $Global:AsyncLoader.Handle = $null
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
