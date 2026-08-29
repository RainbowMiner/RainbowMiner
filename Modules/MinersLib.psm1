#
# Miner module functions
#

# In-memory compiled ScriptBlock cache for the miner modules (BaseName -> entry).
# Opt-out escape hatch: create an empty "nominerscache.txt" in the RainbowMiner
# folder and restart to fall back to per-round file invocation.
$Script:MinerScriptBlockCache = @{}
$Script:MinerScriptBlockCacheDisabled = $null

# Per-device effective memory sizes for Test-VRAM (Device.Name -> @(memsize, offset))
$Script:TestVRAMMem = @{}

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
    # Hot path: called per device per pool key from ~55 miner modules. Deliberately
    # plain parameters (see Get-PoolAlgorithmKeys). The Win10/NVIDIA memory factor
    # and the OpenCL memsize are static per device, so resolve them once per device
    # and keep the comparison arithmetic byte for byte
    param(
        $Device,
        $MinMemGB = 0.0
    )
    $Mem = $Script:TestVRAMMem[$Device.Name]
    if ($null -eq $Mem) {
        $Mem = if ($IsWindows -and $Session.IsWin10 -and $Device.Vendor -eq "NVIDIA") {@(($Device.OpenCL.GlobalMemsize*0.865), 0.0)} else {@($Device.OpenCL.GlobalMemsize, 0.25)}
        $Script:TestVRAMMem[$Device.Name] = $Mem
    }
    $Mem[0] -ge (($MinMemGB + $Mem[1]) * 1Gb)
}

#
# Pool selection helpers for miner modules
#
# $Pools may carry more than one entry per base algorithm: the device-model variants
# built in PoolsLib (Algorithm-GPU, Algorithm-<Model>) and the pool alternates
# registered by Core (Algorithm-@<PoolName>). Every key starts with the base
# algorithm followed by a dash, so "-replace '\-.*$'" always yields the base name.
#

function Get-PoolAlgorithmBase {
    param($Key = "")
    $Key -replace '\-.*$'
}

function Test-PoolAlgorithmAlternate {
    param($Key = "")
    $Key -match '\-@'
}

function Test-PoolConstraint {
    param(
        $Pool,
        $ExcludePoolName = "",
        $PoolName = "",
        $CoinSymbols = @(),
        [Switch]$ExcludeYiimp
    )
    if (-not $Pool -or -not $Pool.Host) {return $false}
    # matched against Host AND Name: most miner modules historically listed pool names
    # but tested them against the hostname, which silently misses every pool that does
    # not carry its own name in its host (or exposes a bare IP)
    if ($ExcludePoolName -and (($Pool.Host -match $ExcludePoolName) -or ($Pool.Name -match $ExcludePoolName))) {return $false}
    if ($PoolName -and -not (($Pool.Host -match $PoolName) -or ($Pool.Name -match $PoolName))) {return $false}
    if ($CoinSymbols -and $Pool.CoinSymbol -notin $CoinSymbols) {return $false}
    if ($ExcludeYiimp -and $Session.YiimpPools -and $Session.YiimpPools.Contains("$($Pool.Name)")) {return $false}
    $true
}

function Get-PoolAlgorithmKeys {
    # Called once per $Commands entry per device model, i.e. a few thousand times per round.
    # Deliberately a simple function with untyped parameters: [CmdletBinding()], typed
    # parameters and [Parameter()] attributes cost more than this function's entire body.
    param(
        $Pools,
        $Algorithm,
        $Model = "",
        [Switch]$NoGPU,
        $ExcludePoolName = "",
        $PoolName = "",
        $CoinSymbols = @(),
        [Switch]$ExcludeYiimp
    )

    $Keys = if ($NoGPU) {
        if ($Model) {@($Algorithm,"$($Algorithm)-$($Model)")} else {@($Algorithm)}
    } else {
        if ($Model) {@($Algorithm,"$($Algorithm)-$($Model)","$($Algorithm)-GPU")} else {@($Algorithm,"$($Algorithm)-GPU")}
    }

    # Fast path: no pool constraint on this entry, feature off, or no alternates registered.
    # Returns the exact same literal the miner modules used before this feature existed.
    # Note $CoinSymbols is compared truthy, not by .Count: @($_.CoinSymbols) on an entry
    # without CoinSymbols yields a one-element array holding $null, whose .Count is 1.
    if (-not ($ExcludePoolName -or $PoolName -or $CoinSymbols -or $ExcludeYiimp)) {return $Keys}
    if (-not $Session.Config.EnablePoolAlternates) {return $Keys}
    $MaxAlternates = [int]$Session.Config.MaxPoolAlternates
    if ($MaxAlternates -le 0) {return $Keys}
    if (-not $Global:PoolAlternates -or -not $Global:PoolAlternates.Count) {return $Keys}

    $Result = [System.Collections.Generic.List[string]]::new()
    foreach ($Key in $Keys) {
        [void]$Result.Add($Key)
        if (-not $Pools.$Key) {continue}
        # only fall back when the winning pool really fails this entry's constraint
        if (Test-PoolConstraint $Pools.$Key -ExcludePoolName $ExcludePoolName -PoolName $PoolName -CoinSymbols $CoinSymbols -ExcludeYiimp:$ExcludeYiimp) {continue}
        if (-not $Global:PoolAlternates.ContainsKey($Key)) {continue}
        $Found = 0
        foreach ($AltKey in $Global:PoolAlternates[$Key]) {
            if ($Found -ge $MaxAlternates) {break}
            if (Test-PoolConstraint $Pools.$AltKey -ExcludePoolName $ExcludePoolName -PoolName $PoolName -CoinSymbols $CoinSymbols -ExcludeYiimp:$ExcludeYiimp) {
                [void]$Result.Add($AltKey)
                $Found++
            }
        }
    }
    $Result.ToArray()
}

function Get-MinerScriptBlock {
    # Returns a cached, compiled ScriptBlock for a miner file (or the file path as
    # fallback when the file cannot be read - both are invocable via &). Reusing the
    # same ScriptBlock instance each round removes the per-round parse cost and lets
    # PowerShell promote hot miner code to compiled delegates.
    param($File)

    $Entry = $Script:MinerScriptBlockCache[$File.BaseName]
    if ($Entry -ne $null -and $Entry.LastWriteTimeUtc -eq $File.LastWriteTimeUtc -and $Entry.Length -eq $File.Length) {
        return $Entry.ScriptBlock
    }

    $Text = Get-ContentByStreamReader $File.FullName
    if (-not $Text) {return $File.FullName}

    # comment out (not remove) the "using module" line: its relative path cannot
    # resolve without a file context, Include.psm1 is already loaded in the session,
    # and keeping the line preserves the file's line numbers in error messages
    $Text = $Text -replace '(?m)^(\s*using\s+module\s.*)$','#$1'

    $ScriptBlock = [ScriptBlock]::Create($Text)

    $Script:MinerScriptBlockCache[$File.BaseName] = @{
        ScriptBlock      = $ScriptBlock
        LastWriteTimeUtc = $File.LastWriteTimeUtc
        Length           = $File.Length
    }
    $ScriptBlock
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
        [String]$MinerName = "*",
        [Parameter(Mandatory = $false)]
        [Hashtable]$Timer = $null
    )

    if ($Parameters.InfoOnly -eq $null) {$Parameters.InfoOnly = $false}

    if ($Script:MinerScriptBlockCacheDisabled -eq $null) {$Script:MinerScriptBlockCacheDisabled = Test-Path ".\nominerscache.txt"}

    $StopWatch = [System.Diagnostics.StopWatch]::New()

    $possibleDevices = @($Global:DeviceCache.DevicesToVendors.Values | Select-Object -Unique)
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        for($i=0; $i -lt $possibleDevices.Count; $i++) { $possibleDevices[$i] = "ARM" + $possibleDevices[$i] }
    }

    # hoisted out of the per-object pipeline below: FullComboModels is stable during
    # one call, but PSObject.Properties.Name would be reflection per emitted object
    $FullComboLookup = @{}
    if ($Global:DeviceCache.DevicesByTypes.FullComboModels) {
        foreach ($p in $Global:DeviceCache.DevicesByTypes.FullComboModels.PSObject.Properties) {$FullComboLookup[$p.Name] = $p.Value}
    }

    Get-ChildItem "Miners\$($MinerName).ps1" -File -ErrorAction Ignore | Where-Object {
        $scriptName = $_.BaseName
        $Parameters.InfoOnly -or (
            (Test-Intersect $possibleDevices @($Global:MinerInfo.$scriptName)) -and
            ($Session.Config.MinerName.Count -eq 0 -or (Test-Intersect $Session.Config.MinerName $_.BaseName)) -and
            ($Session.Config.ExcludeMinerName.Count -eq 0 -or -not (Test-Intersect $Session.Config.ExcludeMinerName $_.BaseName))
        )
    } | Foreach-Object { 
        $scriptName = $_.BaseName
        
        $Parameters["Name"] = $scriptName

        $scriptCmd = if ($Script:MinerScriptBlockCacheDisabled -or $Parameters.InfoOnly) {$_.FullName} else {Get-MinerScriptBlock $_}

        $StopWatch.Restart()

        & $scriptCmd @Parameters | Foreach-Object {
            if ($Parameters.InfoOnly) {
                $_ | Add-Member -NotePropertyMembers @{
                    Name     = if ($_.Name) {$_.Name} else {$scriptName}
                    BaseName = $scriptName
                } -Force -PassThru
            } elseif ($_.PowerDraw -eq 0) {
                $_.PowerDraw = $Global:StatsCache."$($_.Name)_$($_.BaseAlgorithm -replace '\-.*$')_HashRate".PowerDraw_Average
                if ($_.DeviceModel -and $FullComboLookup.ContainsKey($_.DeviceModel)) {$_.DeviceModel = $FullComboLookup[$_.DeviceModel]}
                $_
            } else {
                Write-Log -Level Warn "Miner module $($scriptName) returned invalid object. Please open an issue at https://github.com/rainbowminer/RainbowMiner/issues"
            }
        }

        if ($Timer -ne $null) {$Timer[$scriptName] = [Math]::Round($StopWatch.Elapsed.TotalSeconds, 3)}
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
        for($i=0; $i -lt $possibleDevices.Count; $i++) { $possibleDevices[$i] = "ARM" + $possibleDevices[$i] }
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