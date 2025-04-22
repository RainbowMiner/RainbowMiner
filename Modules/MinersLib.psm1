#
# Miner module functions
#

function Confirm-Cuda {
   [CmdletBinding()]
   param($ActualVersion,$RequiredVersion,$Warning = "")
   if (-not $RequiredVersion) {return $true}
    $ver1 = $ActualVersion -split '\.'
    $ver2 = $RequiredVersion -split '\.'
    $max = [Math]::Min($ver1.Count,$ver2.Count)

    for($i=0;$i -lt $max;$i++) {
        if ([int]$ver1[$i] -lt [int]$ver2[$i]) {if ($Warning -ne "") {Write-Log "$($Warning) requires CUDA version $($RequiredVersion) or above (installed version is $($ActualVersion)). Please update your Nvidia drivers."};return $false}
        if ([int]$ver1[$i] -gt [int]$ver2[$i]) {return $true}
    }
    $true
}

function Test-VRAM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Device,
        [Parameter(Mandatory = $false)]
        $MinMemGB = 0.0
    )
    if ($IsWindows -and $Session.IsWin10 -and $Device.Vendor -eq "NVIDIA") {
        $Device.OpenCL.GlobalMemsize*0.865 -ge ($MinMemGB * 1Gb)
    } else {
        $Device.OpenCL.GlobalMemsize -ge (($MinMemGB + 0.25) * 1Gb)
    }
}

#
# Get-MinersContent
#

function Get-MinersContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [String]$MinerName = "*"
    )

    if ($Parameters.InfoOnly -eq $null) {$Parameters.InfoOnly = $false}

    $possibleDevices = @($Global:DeviceCache.DevicesToVendors.Values | Select-Object -Unique)
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        for($i=0; $i -lt $possibleDevice.Count; $i++) { $possibleDevice[$i] = "ARM" + $possibleDevice[$i] }
    }
    
    Get-ChildItem "Miners\$($MinerName).ps1" -File -ErrorAction Ignore | Where-Object {
        $scriptName = $_.BaseName
        $Parameters.InfoOnly -or (
            (Test-Intersect $possibleDevices @($Global:MinerInfo.$scriptName)) -and
            ($Session.Config.MinerName.Count -eq 0 -or (Test-Intersect $Session.Config.MinerName $_.BaseName)) -and
            ($Session.Config.ExcludeMinerName.Count -eq 0 -or -not (Test-Intersect $Session.Config.ExcludeMinerName $_.BaseName))
        )
    } | Foreach-Object { 
        $scriptPath = $_.FullName
        $scriptName = $_.BaseName
        
        $Parameters["Name"] = $scriptName

        & $scriptPath @Parameters | Foreach-Object {
            if ($Parameters.InfoOnly) {
                $_ | Add-Member -NotePropertyMembers @{
                    Name     = if ($_.Name) {$_.Name} else {$scriptName}
                    BaseName = $scriptName
                } -Force -PassThru
            } elseif ($_.PowerDraw -eq 0) {
                $_.PowerDraw = $Global:StatsCache."$($_.Name)_$($_.BaseAlgorithm -replace '\-.*$')_HashRate".PowerDraw_Average
                if (@($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name) -contains $_.DeviceModel) {$_.DeviceModel = $Global:DeviceCache.DevicesByTypes.FullComboModels."$($_.DeviceModel)"}
                $_
            } else {
                Write-Log -Level Warn "Miner module $($scriptName) returned invalid object. Please open an issue at https://github.com/rainbowminer/RainbowMiner/issues"
            }
        }
    }
}

function Get-MinersContentMOD {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [String]$MinerName = "*"
    )

    if ($Parameters.InfoOnly -eq $null) {$Parameters.InfoOnly = $false}

    $possibleDevices = @($Global:DeviceCache.DevicesToVendors.Values | Sort-Object -Unique)
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        for($i=0; $i -lt $possibleDevice.Count; $i++) { $possibleDevice[$i] = "ARM" + $possibleDevice[$i] }
    }
    
    if (-not (Test-Path ".\Modules\Miners")) { New-Item ".\Modules\Miners" -ItemType "directory" > $null }

    Get-ChildItem "Miners\$($MinerName).ps1" -File -ErrorAction Ignore | Where-Object {
        $scriptName = $_.BaseName
        $Parameters.InfoOnly -or (
            (Test-Intersect $possibleDevices @($Global:MinerInfo.$scriptName)) -and
            ($Session.Config.MinerName.Count -eq 0 -or (Test-Intersect $Session.Config.MinerName $_.BaseName)) -and
            ($Session.Config.ExcludeMinerName.Count -eq 0 -or -not (Test-Intersect $Session.Config.ExcludeMinerName $_.BaseName))
        )
    } | Foreach-Object { 
        $scriptName = $_.BaseName
        $scriptFile = $_.FullName

        $minerFunc = "Get-Miner$($scriptName)"
        $modFile = Join-Path ".\Modules\Miners" ($minerFunc + ".psm1")

        if (Test-Path $modFile) {
            $lwt = (Get-ChildItem $modFile -File -ErrorAction Ignore).LastWriteTimeUtc
            if ($lwt -lt $_.LastWriteTimeUtc) {
                Remove-Item $modFile -Force
            }
        }

        if (-not (Test-Path $modFile)) {
            try {
                $stream = [System.IO.StreamWriter]::new([IO.Path]::GetFullPath($modFile), $true)
                [void]$stream.WriteLine("function $($minerFunc) {")
                Get-Content -Path $scriptFile | ForEach-Object { if ($_ -notmatch "using module") {[void]$stream.WriteLine($_)} }
                [void]$stream.WriteLine("}")
            }
            catch {
                Write-Log -Level Warn "Creation of Modfile failed: $($_.Exception.Message)"
            }
            finally {
                if ($stream -ne $null) {
                    $stream.Close()
                    $stream.Dispose()
                }
            }
        }

        $Parameters["Name"] = $scriptName

        Import-Module $modFile -Scope Local

         & $minerFunc @Parameters | Foreach-Object {
            if ($Parameters.InfoOnly) {
                $_ | Add-Member -NotePropertyMembers @{
                    Name     = if ($_.Name) {$_.Name} else {$scriptName}
                    BaseName = $scriptName
                } -Force -PassThru
            } elseif ($_.PowerDraw -eq 0) {
                $_.PowerDraw = $Global:StatsCache."$($_.Name)_$($_.BaseAlgorithm -replace '\-.*$')_HashRate".PowerDraw_Average
                if (@($Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties.Name) -contains $_.DeviceModel) {$_.DeviceModel = $Global:DeviceCache.DevicesByTypes.FullComboModels."$($_.DeviceModel)"}
                $_
            } else {
                Write-Log -Level Warn "Miner module $($scriptName) returned invalid object. Please open an issue at https://github.com/rainbowminer/RainbowMiner/issues"
            }
        }

        Remove-Module $minerFunc
    }
}

function Get-MinersContentRS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [String]$MinerName = "*",
        [Parameter(Mandatory = $false)]
        [int]$DelayMilliseconds = 100
    )

    if ($Parameters.InfoOnly -eq $null) { $Parameters.InfoOnly = $false }

    $GlobalVars = [System.Collections.Generic.List[String]]@("Session")
    if (-not $Parameters.InfoOnly) {
        [void]$GlobalVars.AddRange([string[]]@("DeviceCache","GlobalCPUInfo","MinerInfo","StatsCache"))
    }

    foreach ($Var in $GlobalVars) {
        if (-not (Test-Path Variable:Global:$Var)) { Write-Log -Level Error "Get-MinersContentRS needs `$$Var variable"; return }
    }

    $runspace = $null
    $psCmd = $null

    try {

        $initialSessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        foreach ($Var in $GlobalVars) {
            $VarRef = Get-Variable -Scope Global $Var -ValueOnly
            [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new($Var, $VarRef, $null))
        }

        foreach ($Module in @("Include","MinersLib")) {
            [void]$initialSessionState.ImportPSModule((Resolve-Path ".\Modules\$($Module).psm1"))
        }

        $runspace = [runspacefactory]::CreateRunspace($initialSessionState)
        if (-not $runspace) { throw "Failed to create Runspace!" }
        $runspace.Open()

        $psCmd = [powershell]::Create()
        if (-not $psCmd) { throw "Failed to create PowerShell instance!" }
        $psCmd.Runspace = $runspace

        [void]$psCmd.AddScript({
            param ($Parameters, $MinerName)
            Set-Location $Session.MainPath
            try {
                Set-OsFlags -NoDLLs
                Get-MinersContent -Parameters $Parameters -MinerName $MinerName
            } catch {
                Write-Log -Level Error "Error in Get-MinersContent: $_"
            }
        }).AddArgument($Parameters).AddArgument($MinerName)

        $inputCollection = [System.Management.Automation.PSDataCollection[PSObject]]::new()
        $outputCollection = [System.Management.Automation.PSDataCollection[PSObject]]::new()

        $asyncResult = $psCmd.BeginInvoke($inputCollection, $outputCollection)

        while (-not $asyncResult.IsCompleted -or $outputCollection.Count -gt 0) {
            if ($outputCollection.Count -gt 0) { $outputCollection.ReadAll() }
            if (-not $asyncResult.IsCompleted) { Start-Sleep -Milliseconds $DelayMilliseconds }
        }

        if ($outputCollection.Count -gt 0) {
            $outputCollection.ReadAll()
        }
        
        [void]$psCmd.EndInvoke($asyncResult)
    } catch {
        Write-Log -Level Error "Critical error in Get-MinersContentPS: $_"
    } finally {
        if ($inputCollection) { $inputCollection.Dispose() }
        if ($outputCollection) { $outputCollection.Dispose() }
        if ($psCmd) { $psCmd.Dispose() }
        if ($runspace) {
            if ($runspace.RunspaceStateInfo.State -ne 'Closed') { $runspace.Close() }
            $runspace.Dispose()
        }
        $inputCollection = $outputCollection = $psCmd = $runspace = $null
    }
}