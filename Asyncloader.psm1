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

            $AsyncLoader.Jobs.Keys | Where-Object {$AsyncLoader.Jobs.$_.CycleTime -le 0} | Foreach-Object {$AsyncLoader.Jobs.$Jobkey.CycleTime = $AsyncLoader.Interval}

            if (-not $AsyncLoader.Pause) {
                $AsyncLoader.Jobs.GetEnumerator() | Where-Object {$_.Value -and -not $_.Value.Running -and -not $_.Value.Paused -and $_.Value.LastRequest -le (Get-Date).ToUniversalTime().AddSeconds(-$_.Value.CycleTime)} | Sort-Object {$_.Value.LastRequest - (Get-Date).ToUniversalTime().AddSeconds(-$_.Value.CycleTime)} | Foreach-Object {
                    $JobKey = $_.Name
                    $Job    = $_.Value
                    try {
                        Invoke-GetUrlAsync -Jobkey $Jobkey -force -quiet
                        if ($AsyncLoader.Jobs.$Jobkey.Error) {$Errors.Add($AsyncLoader.Jobs.$Jobkey.Error)>$null}
                    }
                    catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                        $Errors.Add("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Cycle problem with $($Job.Url) using $($Job.Method): $($_.Exception.Message)")>$null
                    }
                    finally {
                        $Error.Clear()
                    }
                }
            }
            $Delta = $AsyncLoader.CycleTime-$StopWatch.Elapsed.TotalSeconds
            if ($Delta -gt 0)  {Start-Sleep -Milliseconds ($Delta*1000)}
            if ($Error.Count)  {if ($Session.LogLevel -ne "Silent") {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8};$Error.Clear()}
            if ($Errors.Count) {if ($Session.LogLevel -ne "Silent") {$Errors | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8};$Errors.Clear()}
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
