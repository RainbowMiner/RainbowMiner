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
    $AsyncLoader.Timestamp  = $null

    # Setup additional, global variables for server handling
    $Global:AsyncLoaderListeners   = [System.Collections.ArrayList]@()

     # Setup runspace to launch the AsyncLoader in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.SetVariable("Session", $Session)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) > $null

    $AsyncloaderScript = [ScriptBlock]::Create((Get-Content ".\Scripts\Asyncloader.ps1" -Raw))

    $newPS = [PowerShell]::Create().AddScript($AsyncloaderScript).AddParameters(@{'CurrentPwd'=$PWD})
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
