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
    # plain parameters (see Get-PoolAlgorithmKeys). The usable memory is static per
    # device within a round, so resolve it once per device (measured reservation or
    # config override via Get-DeviceUsableVRAMGB, else the historic static factors)
    # and keep the comparison arithmetic byte for byte
    param(
        $Device,
        $MinMemGB = 0.0
    )
    $Mem = $Script:TestVRAMMem[$Device.Name]
    if ($null -eq $Mem) {
        $UsableGB = Get-DeviceUsableVRAMGB $Device
        $Mem = if ($null -ne $UsableGB) {@(($UsableGB * 1Gb), 0.0)}
               elseif ($IsWindows -and $Session.IsWin10 -and $Device.Vendor -eq "NVIDIA") {@(($Device.OpenCL.GlobalMemsize*0.865), 0.0)}
               else {@($Device.OpenCL.GlobalMemsize, 0.25)}
        $Script:TestVRAMMem[$Device.Name] = $Mem
    }
    $Mem[0] -ge (($MinMemGB + $Mem[1]) * 1Gb)
}

function Reset-TestVRAM {
    # Clears the per-device memoization. Call after anything that changes the
    # inputs of Test-VRAM mid-session: a config re-read (GPUReservedVRAMGB may
    # have changed) or a future Get-Device -Refresh (device list rebuild).
    $Script:TestVRAMMem = @{}
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

# Re-bound ScriptBlock slots for Invoke-MinerFamily ("<stub>|<slot>" -> @{Source; ScriptBlock})
$Script:MinerFamilySBCache = @{}

function Get-MinerFamilySB {
    # A {..} literal written in a miner stub is bound to that file's session state;
    # dot-sourced as-is it would not see the driver's loop variables. Recreating the
    # block from its source text detaches the binding; cached per stub and slot.
    param($Name, $Slot, $Block)
    $CacheKey = "$Name|$Slot"
    $Source = $Block.ToString()
    $Entry = $Script:MinerFamilySBCache[$CacheKey]
    if ($Entry -eq $null -or $Entry.Source -cne $Source) {
        $Entry = @{Source = $Source; ScriptBlock = [ScriptBlock]::Create($Source)}
        $Script:MinerFamilySBCache[$CacheKey] = $Entry
    }
    $Entry.ScriptBlock
}

function Invoke-MinerFamily {
    # Shared device/Commands/emission body for the Ccminer/Cpuminer module family.
    # The stubs keep their platform guards, header variables and $Commands table and
    # pass everything through -Setup (a module function cannot see the caller's
    # variables), so this body is compiled and promoted once for the whole family.
    # Every Setup flag reproduces the exact emission of one original per-file body;
    # values a body never referenced stay un-emitted (dead Commands data stays dead).
    param(
        [String]$Name,
        [PSCustomObject]$Pools,
        [Bool]$InfoOnly,
        [Hashtable]$Setup
    )

    # direct assignments instead of a Set-Variable loop: the cmdlet costs ~10us per
    # key and this function runs once per module per round
    $Vendor = $Setup["Vendor"]; $SuffixMode = $Setup["SuffixMode"]; $InfoTypes = $Setup["InfoTypes"]
    $Path = $Setup["Path"]; $Uri = $Setup["Uri"]; $UriCuda = $Setup["UriCuda"]; $ManualUri = $Setup["ManualUri"]
    $Port = $Setup["Port"]; $DevFee = $Setup["DevFee"]; $Version = $Setup["Version"]; $Commands = $Setup["Commands"]
    $CheckSSL = $Setup["CheckSSL"]; $MaxDevCount = $Setup["MaxDevCount"]; $PerEntryVRAM = $Setup["PerEntryVRAM"]
    $ArchIn = $Setup["ArchIn"]; $ArchNotIn = $Setup["ArchNotIn"]; $UseAlgoOverride = $Setup["UseAlgoOverride"]
    $CmdFilter = $Setup["CmdFilter"]; $CpuParams = $Setup["CpuParams"]; $ExtendDefault = $Setup["ExtendDefault"]
    $DevFeeZero = $Setup["DevFeeZero"]; $HashRateMode = $Setup["HashRateMode"]; $MaxRejDefault = $Setup["MaxRejDefault"]
    $MiningPriority = $Setup["MiningPriority"]; $UseExcludePool = $Setup["UseExcludePool"]
    $UseCoinSymbols = $Setup["UseCoinSymbols"]; $EmitsNoCPU = $Setup["EmitsNoCPU"]; $EmitsMaxRej = $Setup["EmitsMaxRej"]
    $API = $Setup["API"]; $MakeArgs = $Setup["MakeArgs"]; $PerModel = $Setup["PerModel"]
    $PreKey = $Setup["PreKey"]; $PerKey = $Setup["PerKey"]
    $FirstPerCmd = $Setup["FirstPerCmd"]; $NeedsPlatformId = $Setup["NeedsPlatformId"]; $EnvVars = $Setup["EnvVars"]
    $DevIdProp = $Setup["DevIdProp"]; $DevIdJoin = $Setup["DevIdJoin"]; $DevIdHex = $Setup["DevIdHex"]
    $DevFeeCmd = $Setup["DevFeeCmd"]; $WinOrSingleDev = $Setup["WinOrSingleDev"]
    # rare stub-scope variables referenced by MakeArgs/hooks (e.g. UseCPUAffinity)
    if ($Setup["Vars"]) { foreach ($VarKey in $Setup["Vars"].Keys) { Set-Variable -Name $VarKey -Value $Setup["Vars"][$VarKey] } }

    if ($InfoOnly) {
        [PSCustomObject]@{
            Type      = if ($InfoTypes) {$InfoTypes} else {@($Vendor)}
            Name      = $Name
            Path      = $Path
            Port      = $null
            Uri       = if ($UriCuda) {$UriCuda.Uri} else {$Uri}
            DevFee    = $DevFee
            ManualUri = $ManualUri
            Commands  = $Commands
        }
        return
    }

    if (-not $API) { $API = "Ccminer" }
    $IsGPU = $Vendor -ne "CPU"
    if (-not $DevIdProp) { $DevIdProp = "Type_Vendor_Index" }
    if ($DevIdJoin -eq $null) { $DevIdJoin = "," }
    $ArgsSB = Get-MinerFamilySB $Name "MakeArgs" $MakeArgs
    $PerModelSB = if ($PerModel) { Get-MinerFamilySB $Name "PerModel" $PerModel } else { $null }
    $PreKeySB   = if ($PreKey)   { Get-MinerFamilySB $Name "PreKey"   $PreKey }   else { $null }
    $PerKeySB   = if ($PerKey)   { Get-MinerFamilySB $Name "PerKey"   $PerKey }   else { $null }

    $Global:DeviceCache.DevicesByTypes."$Vendor" | Select-Object Vendor, Model -Unique | ForEach-Object {
        $First = $true
        $Miner_Model = $_.Model
        # NOT "$($_.Vendor)": CPU devices carry the silicon vendor (INTEL/AMD) there,
        # only GPU devices match their DevicesByTypes key; $Vendor is the type key
        $Miner_Device_All = $Global:DeviceCache.DevicesByTypes."$Vendor" | Where-Object {$_.Model -eq $Miner_Model}
        if ($NeedsPlatformId) {
            # AMD miners address devices per OpenCL platform; a model spanning
            # platforms (PlatformId not a single int) cannot be started
            $Miner_PlatformId = $Miner_Device_All | Select-Object -ExpandProperty PlatformId -Unique
            if ($Miner_PlatformId -isnot [int]) {return}
            $PlatformId = $Miner_PlatformId
        }

        $Miner_Device = if ($PerEntryVRAM) { $null } elseif ($ArchIn) { $Miner_Device_All | Where-Object {$_.OpenCL.Architecture -in $ArchIn} } elseif ($ArchNotIn) { $Miner_Device_All | Where-Object {$_.OpenCL.Architecture -notin $ArchNotIn} } else { $Miner_Device_All }

        if ($PerModelSB) { . $PerModelSB }

        $(if ($CmdFilter) { $Commands | Where-Object {(-not $_.LinuxOnly -or $IsLinux) -and (-not $_.NeverProfitable -or $Session.Config.EnableNeverprofitableAlgos)} } else { $Commands }) | ForEach-Object {

            if ($FirstPerCmd) { $First = $true }

            $Algorithm_Norm_0 = if ($UseAlgoOverride) { Get-Algorithm "$(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm})" } else { Get-Algorithm $_.MainAlgorithm }

            if ($PerEntryVRAM) {
                $MinMemGB = $_.MinMemGB
                $Miner_Device = if ($ArchIn) { $Miner_Device_All | Where-Object {(Test-VRAM $_ $MinMemGB) -and $_.OpenCL.Architecture -in $ArchIn} } else { $Miner_Device_All | Where-Object {(Test-VRAM $_ $MinMemGB) -and $_.OpenCL.Architecture -notin $ArchNotIn} }
            }

            if ($CpuParams) {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
                $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity"})"
            }

            if ($PreKeySB) { . $PreKeySB }

            $AlgoKeys = if ($SuffixMode -eq "ListGPU") { @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU") }
                        elseif ($SuffixMode -eq "ListCPU") { @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)") }
                        elseif ($SuffixMode -eq "KeysNoGPU") { @(Get-PoolAlgorithmKeys -Pools $Pools -Algorithm $Algorithm_Norm_0 -Model $Miner_Model -NoGPU -ExcludePoolName "$($_.ExcludePoolName)") }
                        elseif ($SuffixMode -eq "KeysCoin") { @(Get-PoolAlgorithmKeys -Pools $Pools -Algorithm $Algorithm_Norm_0 -Model $Miner_Model -ExcludePoolName "$($_.ExcludePoolName)" -CoinSymbols @($_.CoinSymbols)) }
                        else { @(Get-PoolAlgorithmKeys -Pools $Pools -Algorithm $Algorithm_Norm_0 -Model $Miner_Model -ExcludePoolName "$($_.ExcludePoolName)") }

            foreach ($Algorithm_Norm in $AlgoKeys) {
                if ($PerKeySB) { . $PerKeySB }
                if ((-not $CheckSSL -or -not $Pools.$Algorithm_Norm.SSL) -and $Pools.$Algorithm_Norm.Host -and $Miner_Device -and
                    (-not $MaxDevCount -or ($Miner_Device | Measure-Object).Count -le $MaxDevCount) -and
                    (-not $WinOrSingleDev -or $IsWindows -or ($Miner_Device | Measure-Object).Count -eq 1) -and
                    (-not $UseExcludePool -or -not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and
                    (-not $UseCoinSymbols -or -not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols)) {

                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        if ($IsGPU) { $DeviceIDsAll = if ($DevIdHex) { ($Miner_Device | ForEach-Object {'{0:x}' -f $_."$DevIdProp"}) -join $DevIdJoin } else { $Miner_Device."$DevIdProp" -join $DevIdJoin } }
                        $First = $false
                    }
                    if ($IsGPU) {
                        $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                    }

                    [PSCustomObject]@{
                        Name           = $Miner_Name
                        DeviceName     = $Miner_Device.Name
                        DeviceModel    = $Miner_Model
                        Path           = if ($_.Path) {$_.Path} else {$Path}
                        Arguments      = (. $ArgsSB)
                        HashRates      = if ($HashRateMode -eq "DayPenalty") { [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Day * $(if ($_.Penalty -ne $null) {$_.Penalty} else {1})} }
                                         else { [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"} }
                        API            = $API
                        Port           = $Miner_Port
                        Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
                        ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {$ExtendDefault}
                        Penalty        = 0
                        DevFee         = if ($DevFeeZero) {0.0} elseif ($DevFeeCmd) { if ($_.DevFee -ne $null) {$_.DevFee} else {$DevFee} } else {$DevFee}
                        ManualUri      = $ManualUri
                        EnvVars        = $EnvVars
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        MiningPriority = $MiningPriority
                        ExcludePoolName = if ($UseExcludePool) {$_.ExcludePoolName} else {$null}
                        NoCPUMining    = if ($EmitsNoCPU) {$_.NoCPUMining} else {$null}
                        MaxRejectedShareRatio = if ($EmitsMaxRej) { if ($_.MaxRejectedShareRatio) {$_.MaxRejectedShareRatio} else {$MaxRejDefault} } else {$null}
                        PrerequisitePath = $PrereqPath
                        PrerequisiteURI  = $PrereqURI
                        PrerequisiteMsg  = $PrereqMsg
                    }
                }
            }
        }
    }
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