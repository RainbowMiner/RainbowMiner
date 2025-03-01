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
    $AsyncLoader.HostTags   = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
    $AsyncLoader.CycleTime  = 10
    $AsyncLoader.Interval   = $Interval
    $AsyncLoader.Quickstart = $Quickstart
    $AsyncLoader.Debug      = ($Session.LogLevel -eq "Debug")
    $AsyncLoader.Timestamp  = $null

    # Setup additional, global variables for server handling
    $Global:AsyncLoaderListeners   = [System.Collections.ArrayList]@()

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $Global:AsyncLoader)
    $newRunspace.SessionStateProxy.SetVariable("Session", $Global:Session)
    $newRunspace.SessionStateProxy.SetVariable("VarCache", $Global:VarCache)
    if (Initialize-HttpClient) {
        $newRunspace.SessionStateProxy.SetVariable("GlobalHttpClient", $Global:GlobalHttpClient)
    }

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
        if ($JobHost -and $AsyncLoader.HostTags.$JobHost -and ($AsyncLoader.HostTags.$JobHost -contains $tag)) {
            $AsyncLoader.HostTags.$JobHost = @($AsyncLoader.HostTags.$JobHost | Where-Object {$_ -ne $tag})
        }
        if (-not $JobHost -or ($AsyncLoader.HostTags.$JobHost | Measure-Object).Count -eq 0) {
            $AsyncLoader.Jobs.$Jobkey.Paused = $true
        }
    }
}
