function Start-AsyncMiner {

    $Global:AsyncMiner = [hashtable]::Synchronized(@{})
    $AsyncMiner.Stop = $false
    $AsyncMiner.MinersUpdated = 0
    $AsyncMiner.MinersFailed  = 0
    $AsyncMiner.ExclusiveMinersFailed = 0
    $AsyncMiner.LastUpdate    = [DateTime]::MinValue

     # Setup runspace to launch the AsyncMiner in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("API", $API)
    $newRunspace.SessionStateProxy.SetVariable("Session", $Session)
    $newRunspace.SessionStateProxy.SetVariable("AsyncMiner", $AsyncMiner)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) > $null

    $AsyncMiner.Loader = [PowerShell]::Create().AddScript({        
        Import-Module ".\Include.psm1"

        # Set the starting directory
        if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

        $ProgressPreference = "SilentlyContinue"
        $ErrorActionPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"
        $InformationPreference = "SilentlyContinue"

        while (-not $AsyncMiner.Stop) {
            Update-DeviceInformation $Session.ActiveMiners_DeviceNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor) -NVSMIpath $Session.Config.NVSMIpath -DeviceConfig $Session.Config.Devices
            $MinersUpdated = 0
            $MinersFailed  = 0
            $ExclusiveMinersFailed = 0
            $Session.ActiveMiners | Where-Object Best |  Foreach-Object {
                $Miner = $_
                Switch ($Miner.GetStatus()) {
                    "Running" {$Miner.UpdateMinerData() > $null;$MinersUpdated++}
                    "RunningFailed" {$MinersFailed++;if ($Miner.IsExclusiveMiner) {$ExclusiveMinersFailed++}}
                }        
            }
            if ($MinersFailed) {
                $API.RunningMiners = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running}
            }
            $AsyncMiner.MinersUpdated = $MinersUpdated
            $AsyncMiner.MinersFailed  = $MinersFailed
            $AsyncMiner.ExclusiveMinersFailed = $ExclusiveMinersFailed
            $AsyncMiner.LastUpdate    = (Get-Date).ToUniversalTime()

            Sleep 5
        }
    });
    $AsyncMiner.Loader.Runspace = $newRunspace
    $AsyncMiner.Handle = $AsyncMiner.Loader.BeginInvoke()
}

function Stop-AsyncMiner {
    if (-not (Test-Path Variable:Global:AsyncMiner)) {return}
    $Global:AsyncMiner.Stop = $true
    if ($Global:AsyncMiner.Loader) {$Global:AsyncMiner.Loader.dispose()}
    $Global:AsyncMiner.Loader = $null
    $Global:AsyncMiner.Handle = $null
    Remove-Variable "AsyncMiner" -Scope Global -Force
}

