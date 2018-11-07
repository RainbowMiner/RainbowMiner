function Start-AsyncLoader {
[cmdletbinding()]
Param(
    [Parameter(Mandatory = $False)]
    [int]$Interval = 60
)
    if ($Interval -lt 60) {return}

    $Global:AsyncLoader = [hashtable]::Synchronized(@{})

    $AsyncLoader.Stop = $false
    [hashtable]$AsyncLoader.Jobs = @{}
    $AsyncLoader.CycleTime = 10
    $AsyncLoader.Interval  = $Interval

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) > $null

    $AsyncLoader.Loader = [PowerShell]::Create().AddScript({        
        Import-Module ".\Include.psm1"

        # Set the starting directory
        if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

        $ProgressPreference = "SilentlyContinue"
        $ErrorActionPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"
        $InformationPreference = "SilentlyContinue"

        [System.Collections.ArrayList]$Errors = @()

        $Cycle = -1

        while (-not $AsyncLoader.Stop) {
            $Start = (Get-Date).ToUniversalTime()
            $Cycle++            
            foreach ($Jobkey in @($AsyncLoader.Jobs.Keys | Select-Object)) {
                $Job = $AsyncLoader.Jobs.$Jobkey
                if ($Job -and -not $Job.Running -and -not $Job.Paused -and $Job.LastRequest -le (Get-Date).ToUniversalTime().AddSeconds(-$Job.CycleTime)) {
                    try {
                        Invoke-GetUrlAsync -Jobkey $Jobkey -force -quiet
                        if ($AsyncLoader.Jobs.$Jobkey.Error) {$AsyncLoader.Errors.Add($AsyncLoader.Jobs.$Jobkey.Error)>$null}
                    }
                    catch {
                        $Errors.Add("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Cycle problem with $($Job.Url) using $($Job.Method): $($_.Exception.Message)")>$null
                    }
                    finally {
                        $Error.Clear()
                    }
                }
            }
            $Delta = $AsyncLoader.CycleTime-((Get-Date).ToUniversalTime() - $Start).TotalSeconds
            if ($Delta -gt 0) {Sleep -Milliseconds ($Delta*1000)}
            if ($Error.Count) {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8;$Error.Clear()}
            if ($Errors.Count) {$Errors | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").asyncloader.txt" -Append -Encoding utf8;$Errors.Clear()}
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

function Get-AsyncLoaderJobs {
    $AsyncLoader.Jobs.Values | Select-Object | Foreach-Object {
        $Job = $_;$Out = [PSCustomObject]@{};$Job.PSObject.Properties.Name | Where-Object {$_ -ne "Request"} | Foreach-Object {$Out | Add-Member $_ $Job.$_ -Force};$Out
    }
}