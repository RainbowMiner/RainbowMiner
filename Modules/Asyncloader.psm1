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

    $Global:AsyncLoader = [System.Collections.Hashtable]::Synchronized(@{})
    $AsyncLoader.Stop       = $false
    $AsyncLoader.Pause      = $true
    $AsyncLoader.Jobs       = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
    $AsyncLoader.HostDelays = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
    $AsyncLoader.HostTags   = [System.Collections.Generic.Dictionary[string, [System.Collections.Generic.HashSet[string]]]]::new([StringComparer]::OrdinalIgnoreCase)
    $AsyncLoader.CycleTime  = 10
    $AsyncLoader.Interval   = $Interval
    $AsyncLoader.Quickstart = $Quickstart
    $AsyncLoader.Debug      = ($Session.LogLevel -eq "Debug")
    $AsyncLoader.Timestamp  = $null

    # Setup additional, global variables for server handling
    $Global:AsyncLoaderListeners   = [System.Collections.ArrayList]::new()

    $initialSessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('AsyncLoader', $AsyncLoader, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('Session', $Session, $null))
    if (Initialize-HttpClient) {
        [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new("GlobalHttpClient", $Global:GlobalHttpClient, $null))
    }

    foreach ($Module in @("Include","MiningRigRentals","TcpLib","WebLib")) {
        [void]$initialSessionState.ImportPSModule((Resolve-Path ".\Modules\$($Module).psm1"))
    }

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace($initialSessionState)
    $newRunspace.Open()

    $AsyncloaderScript = [ScriptBlock]::Create((Get-Content ".\Scripts\Asyncloader.ps1" -Raw))

    $newPS = [PowerShell]::Create().AddScript($AsyncloaderScript).AddParameters(@{'CurrentPwd'=$PWD})
    $newPS.Runspace = $newRunspace

    [void]$Global:AsyncLoaderListeners.Add([PSCustomObject]@{
        Runspace   = $newPS.BeginInvoke()
		PowerShell = $newPS 
    })
}

function Stop-AsyncLoader {
    if (-not (Test-Path Variable:Global:Asyncloader)) {return}
    $Global:AsyncLoader.Stop = $true

    if ($Global:AsyncLoaderListeners) {
        foreach ($Listener in $Global:AsyncLoaderListeners.ToArray()) {
			$Listener.PowerShell.Dispose()
			[void]$Global:AsyncLoaderListeners.Remove($Listener)
		}
    }
    $Global:AsyncLoaderListeners.Clear()

    $Global:AsyncLoader = $null

    Remove-Variable -Name AsyncLoader -Scope Global -Force -ErrorAction Ignore
}

function Stop-AsyncJob {
[cmdletbinding()]   
Param(
   [Parameter(Mandatory = $True)]   
        [string]$tag
)
    if (-not (Test-Path Variable:Global:Asyncloader)) {return}
    foreach ($Jobkey in @($AsyncLoader.Jobs.Keys | Select-Object)) {
        $JobHost = $AsyncLoader.Jobs.$Jobkey.Host
        $set = $null
        if ($JobHost -and $AsyncLoader.HostTags.TryGetValue($JobHost, [ref]$set)) {
            if ($set.Remove($tag) -and $set.Count -eq 0) {
                [void]$AsyncLoader.HostTags.Remove($JobHost)
            }
        }
        if (-not $JobHost -or ($AsyncLoader.HostTags.$JobHost | Measure-Object).Count -eq 0) {
            $AsyncLoader.Jobs.$Jobkey.Paused = $true
        }
    }
}
