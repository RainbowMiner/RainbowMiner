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
    $AsyncLoader.Jobs       = [hashtable]::Synchronized(@{})
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

        [System.Collections.ArrayList]$Errors = @()

        Set-OsFlags

        $AllProtocols = [System.Net.SecurityProtocolType]'Tls12,Tls11,Tls' 
        [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

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
                            "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Start job $JobKey with $($Job.Url) using $($Job.Method)" | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8
                        }
                        try {
                            Invoke-GetUrlAsync -Jobkey $Jobkey -force -quiet
                            if ($AsyncLoader.Jobs.$Jobkey.Error) {$Errors.Add($AsyncLoader.Jobs.$Jobkey.Error)>$null}
                        }
                        catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            $Errors.Add("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Cycle problem with $($Job.Url) using $($Job.Method): $($_.Exception.Message)")>$null
                            if ($AsyncLoader.Verbose) {
                                "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Error job $JobKey with $($Job.Url) using $($Job.Method): $($_.Exception.Message)" | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8
                            }
                        }
                        finally {
                            $Error.Clear()
                            if ($AsyncLoader.Verbose) {
                                "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Done job $JobKey with $($Job.Url) using $($Job.Method)" | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8
                            }
                        }
                    }
                }
            }
            if ($Error.Count)  {if ($Session.LogLevel -ne "Silent") {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8};$Error.Clear()}
            if ($Errors.Count) {if ($Session.LogLevel -ne "Silent") {$Errors | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8};$Errors.Clear()}
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
