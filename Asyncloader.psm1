function Start-AsyncLoader {
    $Global:AsyncLoader = [hashtable]::Synchronized(@{})

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) > $null

    $AsyncLoader.Loader = [PowerShell]::Create().AddScript({        
        Import-Module ".\Include.psm1"

        # Set the starting directory
        if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

        $AsyncLoader.Stop = $false
        $AsyncLoader.Cycle = -1
        [hashtable]$AsyncLoader.Jobs = @{}
        $AsyncLoader.CycleTime = 10
        $ProgressPreference = "SilentlyContinue"
        $ErrorActionPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"
        $InformationPreference = "SilentlyContinue"

        [System.Collections.ArrayList]$Errors = @()

        while (-not $AsyncLoader.Stop) {
            $Start = (Get-Date).ToUniversalTime()
            $AsyncLoader.Cycle++
            if (-not ($AsyncLoader.Cycle % 6)) {[System.GC]::GetTotalMemory("forcefullcollection")>$null;[System.GC]::Collect();Sleep -Milliseconds 500}
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
    $Global:AsyncLoader.Stop = $true
    $Global:AsyncLoader.Loader.dispose()
    $Global:AsyncLoader = [hashtable]::Synchronized(@{})
    $Global:AsyncLoader.Loader = $null
    $Global:AsyncLoader.Handle = $null
}