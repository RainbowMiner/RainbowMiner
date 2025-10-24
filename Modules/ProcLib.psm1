function Start-SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Bool]$ShowMinerWindow = $false,
        [Parameter(Mandatory = $false)]
        [Bool]$IsWrapper = $false,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [Int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$Executables = @(),
        [Parameter(Mandatory = $false)]
        [String]$ScreenName = "",
        [Parameter(Mandatory = $false)]
        [String]$BashFileName = "",
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "",
        [Parameter(Mandatory = $false)]
        [String]$WinTitle = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    if ($IsLinux -and (-not $Session.Config.LinuxMinerTerminal -or $Session.Config.LinuxMinerTerminal -in @("auto","tmux")) -and (Get-Command "tmux" -ErrorAction Ignore)) {
        Start-SubProcessInTmux -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -Executables $Executables -ScreenName $ScreenName -BashFileName $BashFileName -Vendor $Vendor -SetLDLIBRARYPATH:$SetLDLIBRARYPATH -Quiet:$Quiet
    } elseif ($IsLinux -and (-not $Session.Config.LinuxMinerTerminal -or $Session.Config.LinuxMinerTerminal -in @("auto","screen")) -and (Get-Command "screen" -ErrorAction Ignore)) {
        Start-SubProcessInScreen -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -Executables $Executables -ScreenName $ScreenName -BashFileName $BashFileName -Vendor $Vendor -SetLDLIBRARYPATH:$SetLDLIBRARYPATH -Quiet:$Quiet
    } elseif (($ShowMinerWindow -and -not $IsWrapper) -or -not $IsWindows) {
        Start-SubProcessInConsole -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -Executables $Executables -SetLDLIBRARYPATH:$SetLDLIBRARYPATH -Quiet:$Quiet -WinTitle $WinTitle
    } else {
        Start-SubProcessInBackground -FilePath $FilePath -ArgumentList $ArgumentList -LogPath $LogPath -WorkingDirectory $WorkingDirectory -Priority $Priority -CPUAffinity $CPUAffinity -EnvVars $EnvVars -MultiProcess $MultiProcess -Executables $Executables -SetLDLIBRARYPATH:$SetLDLIBRARYPATH -Quiet:$Quiet
    }
}

function Start-SubProcessInBackground {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [Int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$Executables = @(),
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Running = [System.Collections.Generic.List[int]]::new()
    Get-SubProcessRunningIds $FilePath | Where-Object {$_} | Foreach-Object {[void]$Running.Add([int]$_)}

    if ($ArgumentList) {
        $ArgumentListToBlock = $ArgumentList
        ([regex]"\s-+[\w\-_]+[\s=]+([^'`"][^\s]*,[^\s]+)").Matches(" $ArgumentListToBlock") | Foreach-Object {$ArgumentListToBlock=$ArgumentListToBlock -replace [regex]::Escape($_.Groups[1].Value),"'$($_.Groups[1].Value -replace "'","``'")'"}
        ([regex]"\s-+[\w\-_]+[\s=]+([\[][^\s]+)").Matches(" $ArgumentListToBlock") | Foreach-Object {$ArgumentListToBlock=$ArgumentListToBlock -replace [regex]::Escape($_.Groups[1].Value),"'$($_.Groups[1].Value -replace "'","``'")'"}
        if ($ArgumentList -ne $ArgumentListToBlock) {
            Write-Log "Start-SubProcessInBackground argumentlist: $($ArgumentListToBlock)"
            $ArgumentList = $ArgumentListToBlock
        }
    }

    $Job = Start-ThreadJob -FilePath .\Scripts\StartInBackground.ps1 -ArgumentList $PID, $WorkingDirectory, $FilePath, $ArgumentList, $LogPath, $EnvVars, $Priority, $PWD

    $ProcessIds = [System.Collections.Generic.List[int]]::new()
    if ($Job) {
        Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $Running -Executables $Executables | Where-Object {$_} | Foreach-Object {[void]$ProcessIds.Add([int]$_)}
    }
    
    if ($Priority -lt 10) {
        Set-SubProcessPriority $ProcessIds -Priority $Priority -CPUAffinity $CPUAffinity -Quiet:$Quiet
    }

    [PSCustomObject]@{
        ScreenName = ""
        ScreenCmd  = ""
        Name       = $Job.Name
        WorkingDir = $WorkingDirectory
        XJob       = $Job
        OwnWindow  = $false
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Start-SubProcessInConsole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$Executables = @(),
        [Parameter(Mandatory = $false)]
        [String]$WinTitle = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Running = [System.Collections.Generic.List[int]]::new()
    Get-SubProcessRunningIds $FilePath | Where-Object {$_} | Foreach-Object {[void]$Running.Add([int]$_)}

    $LDExp = ""
    $LinuxDisplay = ""
    $LinuxNiceness = ""
    if ($IsLinux) {
        $LDExp = if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")}
        $LinuxDisplay = "$(if ($Session.Config.EnableLinuxHeadless) {$Session.Config.LinuxDisplay})"
        if ($Session.Config.EnableLinuxMinerNiceness) {
            $LinuxNiceness = "$($Session.Config.LinuxMinerNiceness)"
        }
        $Executables | Foreach-Object {
            $Exec_Path = Join-Path (Split-Path -Path $FilePath) $_
            if (Test-Path $Exec_Path) {
                (Start-Process "chmod" -ArgumentList "+x",$Exec_Path -PassThru).WaitForExit(1000) > $null
            }
        }
    }

    $Job = Start-Job -FilePath .\Scripts\StartInConsole.ps1 -ArgumentList $PID, (Resolve-Path ".\DotNet\Tools\CreateProcess.cs"), $LDExp, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars, $IsWindows, $LinuxDisplay, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation, $SetLDLIBRARYPATH, $LinuxNiceness

    $cnt = 30
    do {Start-Sleep 1; $JobOutput = Receive-Job $Job;$cnt--}
    while ($JobOutput -eq $null -and $cnt -gt 0)

    $ProcessIds = [System.Collections.Generic.List[int]]::new()
    if ($JobOutput) {
        Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $Running -Executables $Executables | Where-Object {$_} | Foreach-Object {[void]$ProcessIds.Add([int]$_)}

        if (-not $ProcessIds.Count -and $JobOutput.ProcessId) {
            [void]$ProcessIds.Add([int]$JobOutput.ProcessId)
        }
    }

    if ($Priority -lt 10) {
        Set-SubProcessPriority $ProcessIds -Priority $Priority -CPUAffinity $CPUAffinity -Quiet:$Quiet
    }

    if ($IsWindows -and $JobOutput.ProcessId -and $WinTitle -ne "") {
        try {
            if ($Process = Get-Process -Id $JobOutput.ProcessId -ErrorAction Stop) {
                Initialize-User32Dll
                [User32.WindowManagement]::SetWindowText($Process.mainWindowHandle, $WinTitle) > $null
            }
        } catch {
            if (-not $Quiet) {
                Write-Log -Level Warn "Could not set process window title: $($_.Exception.Message)"
            }
        }
    }
    
    [PSCustomObject]@{
        ScreenName = ""
        ScreenCmd  = ""
        Name       = $Job.Name
        WorkingDir = $WorkingDirectory
        XJob       = $Job
        OwnWindow  = $true
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Start-SubProcessInScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$Executables = @(),
        [Parameter(Mandatory = $false)]
        [String]$ScreenName = "",
        [Parameter(Mandatory = $false)]
        [String]$BashFileName = "",
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $StartStopDaemon = Get-Command "start-stop-daemon" -ErrorAction Ignore

    $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()
    $ScreenName = ($ScreenName -replace "[^A-Z0-9_-]").ToLower()
    $BashFileName = ($BashFileName -replace "[^A-Z0-9_-]").ToLower()

    if (-not $ScreenName) {$ScreenName = Get-MD5Hash "$FilePath $ArgumentList";$ScreenName = "$($ScreenName.SubString(0,3))$($ScreenName.SubString(28,3))".ToLower()}

    $ScreenName = "$($WorkerName)_$($ScreenName)"

    if (-not (Test-Path ".\Data\pid")) {New-Item ".\Data\pid" -ItemType "directory" -force > $null}

    $PIDPath = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_pid.txt"
    $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_info.txt"
    $PIDBash = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName).sh"
    $PIDTest = Join-Path $WorkingDirectory "$(if ($BashFileName) {$BashFileName} else {"start_$($ScreenName)"}).sh"
    $PIDDebug= Join-Path $WorkingDirectory "$(if ($BashFileName) {"debug_$BashFileName"} else {"debug_start_$($ScreenName)"}).sh"

    if (Test-Path $PIDPath) { Remove-Item $PIDPath -Force }
    if (Test-Path $PIDInfo) { Remove-Item $PIDInfo -Force }
    if (Test-Path $PIDBash) { Remove-Item $PIDBash -Force }
    if (Test-Path $PIDDebug){ Remove-Item $PIDDebug -Force }

    $TestArgumentList = "$ArgumentList"

    if ($LogPath) {
        $ArgumentList = "$ArgumentList 2>&1 | tee `'$($LogPath)`'"
    }

    Set-ContentJson -Data @{miner_exec = "$FilePath"; start_date = "$(Get-Date)"; pid_path = "$PIDPath" } -PathToFile $PIDInfo > $null

    [System.Collections.Generic.List[string]]$Stuff = @()
    [void]$Stuff.Add("export DISPLAY=:0")
    [void]$Stuff.Add("cd /")
    [void]$Stuff.Add("cd '$WorkingDirectory'")

    $StuffEnv = Switch ($Vendor) {
        "AMD" {
            [ordered]@{
                GPU_MAX_HEAP_SIZE=100
                GPU_MAX_USE_SYNC_OBJECTS=1
                GPU_SINGLE_ALLOC_PERCENT=100
                GPU_MAX_ALLOC_PERCENT=100
                GPU_MAX_SINGLE_ALLOC_PERCENT=100
                GPU_ENABLE_LARGE_ALLOCATION=100
                GPU_MAX_WORKGROUP_SIZE=256
            }
        }
        "INTEL" {
            [ordered]@{
                GPU_MAX_HEAP_SIZE=100
                GPU_MAX_USE_SYNC_OBJECTS=1
                GPU_SINGLE_ALLOC_PERCENT=100
                GPU_MAX_ALLOC_PERCENT=100
                GPU_MAX_SINGLE_ALLOC_PERCENT=100
                GPU_ENABLE_LARGE_ALLOCATION=100
                GPU_MAX_WORKGROUP_SIZE=256
            }
        }
        "NVIDIA" {
            [ordered]@{
                CUDA_DEVICE_ORDER="PCI_BUS_ID"
            }
        }
        default {
            [ordered]@{}
        }
    }

    $EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {$StuffEnv[$matches[1]]=$matches[2]}

    $StuffEnv.GetEnumerator() | Foreach-Object {
        [void]$Stuff.Add("export $($_.Name)=$($_.Value)")
    }

    if ($SetLDLIBRARYPATH) {
        [void]$Stuff.Add("export LD_LIBRARY_PATH=./:$(if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")})")
    }

    [System.Collections.Generic.List[string]]$Test  = @()
    $Stuff | Foreach-Object {[void]$Test.Add($_)}

    $nice = "$(if ($Session.Config.EnableLinuxMinerNiceness) {"nice -n $($Session.Config.LinuxMinerNiceness) "})"
    [void]$Test.Add("$nice$FilePath $TestArgumentList")

    if ($StartStopDaemon) {
        $nice = "$(if ($Session.Config.EnableLinuxMinerNiceness) {"--nicelevel $($Session.Config.LinuxMinerNiceness) "})"
        [void]$Stuff.Add("start-stop-daemon --start --make-pidfile --chdir '$WorkingDirectory' --pidfile '$PIDPath' $($nice)--exec '$FilePath' -- $ArgumentList")
    } else {
        [void]$Stuff.Add("$nice$FilePath $ArgumentList")
    }

    [System.Collections.Generic.List[string]]$Cmd = @()
    [void]$Cmd.Add("screen -ls `"$ScreenName`" |  grep '[0-9].$ScreenName' | (")
    [void]$Cmd.Add("  IFS=`$(printf '\t');")
    [void]$Cmd.Add("  sed `"s/^`$IFS//`" |")
    [void]$Cmd.Add("  while read -r name stuff; do")
    [void]$Cmd.Add("    screen -S `"`$name`" -X stuff `^C >/dev/null 2>&1")
    [void]$Cmd.Add("    sleep .1 >/dev/null 2>&1")
    [void]$Cmd.Add("    screen -S `"`$name`" -X stuff `^C >/dev/null 2>&1")
    [void]$Cmd.Add("    sleep .1 >/dev/null 2>&1")
    [void]$Cmd.Add("    screen -S `"`$name`" -X quit  >/dev/null 2>&1")
    [void]$Cmd.Add("    screen -S `"`$name`" -X quit  >/dev/null 2>&1")
    [void]$Cmd.Add("  done")
    [void]$Cmd.Add(")")
    [void]$Cmd.Add("screen -wipe >/dev/null 2>&1")
    [void]$Cmd.Add("screen -S $($ScreenName) -d -m")
    [void]$Cmd.Add("sleep .1")

    $StringChunkSize = 500

    $Stuff | Foreach-Object {
        $str = $_
        while ($str) {
            $substr = $str.substring(0,[Math]::Min($str.length,$StringChunkSize))
            if ($str.length -gt $substr.length) {
                [void]$Cmd.Add("screen -S $($ScreenName) -X stuff $`"$($substr -replace '"','\"')`"")
                $str = $str.substring($substr.length)
            } else {
                [void]$Cmd.Add("screen -S $($ScreenName) -X stuff $`"$($substr -replace '"','\"')\n`"")
                $str = ""
            }
            [void]$Cmd.Add("sleep .1")
        }
    }

    Set-BashFile -FilePath $PIDBash -Cmd $Cmd
    Set-BashFile -FilePath $PIDTest -Cmd $Test

    if ($Session.Config.EnableDebugMode -and (Test-Path $PIDBash)) {
        Copy-Item -Path $PIDBash -Destination $PIDDebug -ErrorAction Ignore
        (Start-Process "chmod" -ArgumentList "+x",$PIDDebug -PassThru).WaitForExit(1000) > $null
    }

    (Start-Process "chmod" -ArgumentList "+x",$FilePath -PassThru).WaitForExit(1000) > $null
    (Start-Process "chmod" -ArgumentList "+x",$PIDBash -PassThru).WaitForExit(1000) > $null
    (Start-Process "chmod" -ArgumentList "+x",$PIDTest -PassThru).WaitForExit(1000) > $null

    $Executables | Foreach-Object {
        $Exec_Path = Join-Path (Split-Path -Path $FilePath) $_
        if (Test-Path $Exec_Path) {
            (Start-Process "chmod" -ArgumentList "+x",$Exec_Path -PassThru).WaitForExit(1000) > $null
        }
    }

    $Job = Start-Job -FilePath .\Scripts\StartInScreen.ps1 -ArgumentList $PID, $WorkingDirectory, $FilePath, $Session.OCDaemonPrefix, $Session.Config.EnableMinersAsRoot, $PIDPath, $PIDBash, $ScreenName, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation, $Session.IsAdmin

    $cnt = 30;
    do {Start-Sleep 1; $JobOutput = Receive-Job $Job;$cnt--}
    while ($JobOutput -eq $null -and $cnt -gt 0)

    $JobOutput.StartLog | Where-Object {$_} | Foreach-Object {Write-Log "$_"}

    $ProcessIds = [System.Collections.Generic.List[int]]::new()
    if ($JobOutput.ProcessId) {
        [void]$ProcessIds.Add([int]$JobOutput.ProcessId)
        if ($MultiProcess) {
            if (-not $Executables) { $Executables = @(Split-Path $FilePath -Leaf) }
            Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $ProcessIds -Executables $Executables | Where-Object {$_} | Foreach-Object {
                if (-not $ProcessIds.Contains([int]$_)) {
                    [void]$ProcessIds.Add([int]$_)
                }
            }
        }
    }
    
    [PSCustomObject]@{
        ScreenName = $ScreenName
        ScreenCmd  = "screen"
        Name       = $Job.Name
        WorkingDir = $WorkingDirectory
        XJob       = $Job
        OwnWindow  = $true
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Start-SubProcessInTmux {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$LogPath = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$EnvVars = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0,
        [Parameter(Mandatory = $false)]
        [String[]]$Executables = @(),
        [Parameter(Mandatory = $false)]
        [String]$ScreenName = "",
        [Parameter(Mandatory = $false)]
        [String]$BashFileName = "",
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SetLDLIBRARYPATH = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $StartStopDaemon = Get-Command "start-stop-daemon" -ErrorAction Ignore

    $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()
    $ScreenName = ($ScreenName -replace "[^A-Z0-9_-]").ToLower()
    $BashFileName = ($BashFileName -replace "[^A-Z0-9_-]").ToLower()

    if (-not $ScreenName) {$ScreenName = Get-MD5Hash "$FilePath $ArgumentList";$ScreenName = "$($ScreenName.SubString(0,3))$($ScreenName.SubString(28,3))".ToLower()}

    $ScreenName = "$($WorkerName)_$($ScreenName)"

    if (-not (Test-Path ".\Data\pid")) {New-Item ".\Data\pid" -ItemType "directory" -force > $null}

    $PIDPath = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_pid.txt"
    $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName)_info.txt"
    $PIDBash = Join-Path (Resolve-Path ".\Data\pid") "$($ScreenName).sh"
    $PIDTest = Join-Path $WorkingDirectory "$(if ($BashFileName) {$BashFileName} else {"start_$($ScreenName)"}).sh"
    $PIDDebug= Join-Path $WorkingDirectory "$(if ($BashFileName) {"debug_$BashFileName"} else {"debug_start_$($ScreenName)"}).sh"

    if (Test-Path $PIDPath) { Remove-Item $PIDPath -Force }
    if (Test-Path $PIDInfo) { Remove-Item $PIDInfo -Force }
    if (Test-Path $PIDBash) { Remove-Item $PIDBash -Force }
    if (Test-Path $PIDDebug){ Remove-Item $PIDDebug -Force }

    $TestArgumentList = "$ArgumentList"

    if ($LogPath) {
        $ArgumentList = "$ArgumentList 2>&1 | tee `'$($LogPath)`'"
    }

    Set-ContentJson -Data @{miner_exec = "$FilePath"; start_date = "$(Get-Date)"; pid_path = "$PIDPath" } -PathToFile $PIDInfo > $null

    [System.Collections.Generic.List[string]]$Stuff = @()
    [void]$Stuff.Add("export DISPLAY=:0")
    [void]$Stuff.Add("cd /")
    [void]$Stuff.Add("cd '$WorkingDirectory'")

    $StuffEnv = Switch ($Vendor) {
        "AMD" {
            [ordered]@{
                GPU_MAX_HEAP_SIZE=100
                GPU_MAX_USE_SYNC_OBJECTS=1
                GPU_SINGLE_ALLOC_PERCENT=100
                GPU_MAX_ALLOC_PERCENT=100
                GPU_MAX_SINGLE_ALLOC_PERCENT=100
                GPU_ENABLE_LARGE_ALLOCATION=100
                GPU_MAX_WORKGROUP_SIZE=256
            }
        }
        "INTEL" {
            [ordered]@{
                GPU_MAX_HEAP_SIZE=100
                GPU_MAX_USE_SYNC_OBJECTS=1
                GPU_SINGLE_ALLOC_PERCENT=100
                GPU_MAX_ALLOC_PERCENT=100
                GPU_MAX_SINGLE_ALLOC_PERCENT=100
                GPU_ENABLE_LARGE_ALLOCATION=100
                GPU_MAX_WORKGROUP_SIZE=256
            }
        }
        "NVIDIA" {
            [ordered]@{
                CUDA_DEVICE_ORDER="PCI_BUS_ID"
            }
        }
        default {
            [ordered]@{}
        }
    }

    $EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {$StuffEnv[$matches[1]]=$matches[2]}

    $StuffEnv.GetEnumerator() | Foreach-Object {
        [void]$Stuff.Add("export $($_.Name)=$($_.Value)")
    }

    if ($SetLDLIBRARYPATH) {
        [void]$Stuff.Add("export LD_LIBRARY_PATH=./:$(if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")})")
    }

    [System.Collections.Generic.List[string]]$Test  = @()
    $Stuff | Foreach-Object {[void]$Test.Add($_)}

    $nice = "$(if ($Session.Config.EnableLinuxMinerNiceness) {"nice -n $($Session.Config.LinuxMinerNiceness) "})"
    [void]$Test.Add("$nice$FilePath $TestArgumentList")

    if ($StartStopDaemon) {
        $nice = "$(if ($Session.Config.EnableLinuxMinerNiceness) {"--nicelevel $($Session.Config.LinuxMinerNiceness) "})"
        [void]$Stuff.Add("start-stop-daemon --start --make-pidfile --chdir '$WorkingDirectory' --pidfile '$PIDPath' $($nice)--exec '$FilePath' -- $ArgumentList")
    } else {
        [void]$Stuff.Add("$nice$FilePath $ArgumentList")
    }

    [System.Collections.Generic.List[string]]$Cmd = @()

    [void]$Cmd.Add("if tmux has-session 2>/dev/null; then")
    [void]$Cmd.Add("  tmux list-sessions -F '#{session_name}' | grep '$ScreenName' | (")
    [void]$Cmd.Add("    while read -r name; do")
    [void]$Cmd.Add("      tmux send-keys -t `"`$name`" C-c >/dev/null 2>&1")
    [void]$Cmd.Add("      sleep 0.1")
    [void]$Cmd.Add("      tmux send-keys -t `"`$name`" C-c >/dev/null 2>&1")
    [void]$Cmd.Add("      sleep 0.1")
    [void]$Cmd.Add("      tmux kill-session -t `"`$name`" >/dev/null 2>&1")
    [void]$Cmd.Add("    done")
    [void]$Cmd.Add("  )")
    [void]$Cmd.Add("fi")

    [void]$Cmd.Add("tmux new-session -d -s $($ScreenName)")
    [void]$Cmd.Add("sleep 0.1")

    $StringChunkSize = 2000
    $Stuff | ForEach-Object {
        $str = $_
        while ($str) {
            $substr = $str.Substring(0, [Math]::Min($str.Length, $StringChunkSize))
            if ($str.Length -gt $substr.Length) {
                [void]$Cmd.Add("tmux send-keys -t $($ScreenName) $`"$($substr -replace '\"', '\"')`"")
                $str = $str.Substring($substr.Length)
            } else {
                [void]$Cmd.Add("tmux send-keys -t $($ScreenName) $`"$($substr -replace '\"', '\"')`" C-m")
                $str = ""
            }
            [void]$Cmd.Add("sleep 0.1")
        }
    }

    Set-BashFile -FilePath $PIDBash -Cmd $Cmd
    Set-BashFile -FilePath $PIDTest -Cmd $Test

    if ($Session.Config.EnableDebugMode -and (Test-Path $PIDBash)) {
        Copy-Item -Path $PIDBash -Destination $PIDDebug -ErrorAction Ignore
        (Start-Process "chmod" -ArgumentList "+x",$PIDDebug -PassThru).WaitForExit(1000) > $null
    }

    (Start-Process "chmod" -ArgumentList "+x",$FilePath -PassThru).WaitForExit(1000) > $null
    (Start-Process "chmod" -ArgumentList "+x",$PIDBash -PassThru).WaitForExit(1000) > $null
    (Start-Process "chmod" -ArgumentList "+x",$PIDTest -PassThru).WaitForExit(1000) > $null

    $Executables | Foreach-Object {
        $Exec_Path = Join-Path (Split-Path -Path $FilePath) $_
        if (Test-Path $Exec_Path) {
            (Start-Process "chmod" -ArgumentList "+x",$Exec_Path -PassThru).WaitForExit(1000) > $null
        }
    }

    $Job = Start-Job -FilePath .\Scripts\StartInTmux.ps1 -ArgumentList $PID, $WorkingDirectory, $FilePath, $Session.OCDaemonPrefix, $Session.Config.EnableMinersAsRoot, $PIDPath, $PIDBash, $ScreenName, $ExecutionContext.SessionState.Path.CurrentFileSystemLocation, $Session.IsAdmin

    $cnt = 30;
    do {Start-Sleep 1; $JobOutput = Receive-Job $Job;$cnt--}
    while ($JobOutput -eq $null -and $cnt -gt 0)

    $JobOutput.StartLog | Where-Object {$_} | Foreach-Object {Write-Log "$_"}

    $ProcessIds = [System.Collections.Generic.List[int]]::new()
    if ($JobOutput.ProcessId) {
        [void]$ProcessIds.Add([int]$JobOutput.ProcessId)
        if ($MultiProcess) {
            if (-not $Executables) { $Executables = @(Split-Path $FilePath -Leaf) }
            Get-SubProcessIds -FilePath $FilePath -ArgumentList $ArgumentList -MultiProcess $MultiProcess -Running $ProcessIds -Executables $Executables | Where-Object {$_} | Foreach-Object {
                if (-not $ProcessIds.Contains([int]$_)) {
                    [void]$ProcessIds.Add([int]$_)
                }
            }
        }
    }
    
    [PSCustomObject]@{
        ScreenName = $ScreenName
        ScreenCmd  = "tmux"
        Name       = $Job.Name
        WorkingDir = $WorkingDirectory
        XJob       = $Job
        OwnWindow  = $true
        ProcessId  = [int[]]@($ProcessIds | Where-Object {$_ -gt 0})
    }
}

function Get-SubProcessRunningIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath
    )
    $FilePath = "$(Split-Path -Path $FilePath)"
    if ($IsWindows) {(Get-CIMInstance CIM_Process | Where-Object {$_.ExecutablePath -ne $null -and ("$(Split-Path -Path $_.ExecutablePath)" -eq $FilePath)}).ProcessId}
    elseif ($IsLinux) {(Get-Process | Where-Object {$_.Path -ne $null -and ("$(Split-Path -Path $_.Path)" -eq $FilePath)}).Id}
}

function Get-SubProcessIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "",
        [Parameter(Mandatory = $false)]
        [int[]]$Running = @(),
        [Parameter(Mandatory = $false)]
        [String[]]$Executables = @(),
        [Parameter(Mandatory = $false)]
        [int]$MultiProcess = 0
    )

    $found = [System.Collections.Generic.List[int]]::new()

    $runningSet = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($p in $Running) { [void]$runningSet.Add([int]$p) }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    if ($IsWindows) {
        $ArgumentList = ("*$($ArgumentList.Replace("*","#!star!#").Replace("'","*").Replace('"',"*") -replace '([\[\]\?\`])','`$1')*" -replace "\*+","*").Replace("#!star!#",'`*')
        $FilePathOnly = "$(Split-Path -Path $FilePath)"

        do {
            Start-Sleep -Milliseconds 100
            Get-CIMInstance CIM_Process | Where-Object {($_.ExecutablePath -ne $null -and ("$(Split-Path -Path $_.ExecutablePath)" -eq $FilePathOnly)) -and $_.CommandLine -like $ArgumentList -and -not $runningSet.Contains([int]$_.ProcessId)} | Foreach-Object {
                $p = [int]$_.ProcessId
                [void]$runningSet.Add($p)
                [void]$found.Add($p)
                Write-Log "$p found for $FilePath"
            }
        } until (($sw.Elapsed.TotalSeconds -gt 10) -or ($found.Count -gt $MultiProcess))

    } elseif ($IsLinux) {
        do {
            Start-Sleep -Milliseconds 100
            Get-Process | Where-Object {$_.Name -in $Executables -and $_.Parent -and ($runningSet.Contains([int]$_.Parent.Id) -or ($_.Parent.Parent -and $runningSet.Contains([int]$_.Parent.Parent.Id)))} | Foreach-Object {
                $p = [int]$_.Id
                [void]$found.Add($p)
                Write-Log "Success: got id $p for $($_.Name) as child of $($_.Parent.Parent.Name)"
            }
        } until (($sw.Elapsed.TotalSeconds -gt 10) -or ($found.Count -ge $MultiProcess))
    }

    $sw.Stop()
    $sw = $null

    $found.ToArray()
}

function Set-SubProcessPriority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $ProcessId,
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)]
        [Int]$CPUAffinity = 0,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )
    $ProcessId | Where-Object {$_} | Foreach-Object {
        try {
            if ($Process = Get-Process -Id $_ -ErrorAction Stop) {
                $Process.PriorityClass = @{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}[$Priority]
                if ($CPUAffinity) {$Process.ProcessorAffinity = $CPUAffinity}
            }
        } catch {
            if (-not $Quiet) {Write-Log -Level Warn "Could not set process priority/affinity: $($_.Exception.Message)"}
        }
    }
}

function Stop-SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Job,
        [Parameter(Mandatory = $false)]
        [String]$Title = "Process",
        [Parameter(Mandatory = $false)]
        [String]$Name = "",
        [Parameter(Mandatory = $false)]
        [String]$ShutdownUrl = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SkipWait = $false
    )

    $WaitForExit = if ($SkipWait) {0} elseif ($IsWindows) {20} else {120}

    if ($Job.ProcessId) {
        $Job.ProcessId | Select-Object -First 1 | Foreach-Object {
            if ($Process = Get-Process -Id $_ -ErrorAction Ignore) {

                $sw = [System.Diagnostics.Stopwatch]::StartNew()

                $ToKill  = [System.Collections.ArrayList]::new()
                [void]$ToKill.Add($Process)

                if ($IsLinux) {
                    foreach ($p in Get-Process -Name $Process.Name -ErrorAction Ignore) {
                        if ($p.Parent -and ($p.Parent.Id -eq $Process.Id)) {
                            [void]$ToKill.Add($p)
                        }
                    }
                    $p = $null
                }

                if ($ShutdownUrl -ne "") {
                    Write-Log "Trying to shutdown $($Title) via API$(if ($Name) {": $($Name)"})"
                    $oldProgressPreference = $Global:ProgressPreference
                    $Global:ProgressPreference = "SilentlyContinue"
                    try {
                        $Response = Invoke-GetUrl $ShutdownUrl -Timeout 20 -ErrorAction Stop

                        $sw.Restart()
                        while ($sw.Elapsed.TotalSeconds -le 20) {
                            $hx = $ToKill.HasExited
                            if ($hx -contains $null -or $hx -contains $false) {
                                Start-Sleep -Milliseconds 500
                            } else {
                                break
                            }
                        }
                        $hx = $ToKill.HasExited
                        if ($hx -contains $null -or $hx -contains $false) {
                            Write-Log -Level Warn "$($Title) failed to close within 20 seconds via API $(if ($Name) {": $($Name)"})"
                        }
                    }
                    catch {
                        Write-Log -Level Warn "Failed to shutdown process $($Title) via API$(if ($Name) {": $($Name)"})"
                    }
                    $Global:ProgressPreference = $oldProgressPreference
                }

                if ($IsWindows) {

                    #
                    # shutdown Windows miners
                    #

                    $Shutdown_Title = "$($Title) PID $($Process.Id)$(if ($Name) {": $($Name)"})"

                    try {
                        if ($Job.OwnWindow) {
                            Write-Log "Attempting to close main window $($Shutdown_Title)"
                            $Process.CloseMainWindow() > $null
                        } else {
                            if (-not $Process.HasExited) {
                                Write-Log "Attempting to kill $($Shutdown_Title)"
                                Stop-Process -InputObject $Process -ErrorAction Ignore -Force
                            }
                        }
                    } catch {
                        Write-Log "Failed to $(if ($Job.OwnWindow) {"close main window of"} else {"kill"}) $($Title) PID $($Process.Id): $($_.Exception.Message)"
                    }

                } else {

                    #
                    # shutdown Linux miners
                    #

                    if ($Job.ScreenName) {
                        try {
                            $hx = $ToKill.HasExited
                            if ($hx -contains $null -or $hx -contains $false) {
                                Write-Log "Send ^C to $($Title)'s screen $($Job.ScreenName)"

                                $ArgumentList = if ($Job.ScreenCmd -eq "screen") {"-S $($Job.ScreenName) -X stuff `^C"} elseif ($Job.ScreenCmd -eq "tmux") {"send-keys -t $($Job.ScreenName) C-c"}
                                if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                                    $Cmd = "$($Job.ScreenCmd) $ArgumentList"
                                    $Msg = Invoke-OCDaemon -Cmd $Cmd
                                    if ($Msg) {Write-Log "OCDaemon for `"$Cmd`" reports: $Msg"}
                                } else {
                                    $Screen_Process = Start-Process $Job.ScreenCmd -ArgumentList $ArgumentList -PassThru
                                    $Screen_Process.WaitForExit(5000) > $null
                                }

                                $sw.Restart()
                                while ($sw.Elapsed.TotalSeconds -le 10) {
                                    $hx = $ToKill.HasExited
                                    if ($hx -contains $null -or $hx -contains $false) {
                                        Start-Sleep -Milliseconds 500
                                    } else {
                                        break
                                    }
                                }

                                if ($hx -contains $null -or $hx -contains $false) {
                                    Write-Log -Level Warn "$($Title) failed to close within 10 seconds$(if ($Name) {": $($Name)"})"
                                }
                            }

                            $PIDInfo = Join-Path (Resolve-Path ".\Data\pid") "$($Job.ScreenName)_info.txt"
                            if ($MI = Get-Content $PIDInfo -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore) {
                                if (-not $Process.HasExited -and (Get-Command "start-stop-daemon" -ErrorAction Ignore)) {
                                    Write-Log "Call start-stop-daemon to kill $($Title)"
                                    $ArgumentList = "--stop --name $($Process.Name) --pidfile $($MI.pid_path) --retry 5"
                                    if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                                        $Cmd = "start-stop-daemon $ArgumentList"
                                        $Msg = Invoke-OCDaemon -Cmd $Cmd
                                        if ($Msg) {Write-Log "OCDaemon for $Cmd reports: $Msg"}
                                    } else {
                                        $StartStopDaemon_Process = Start-Process "start-stop-daemon" -ArgumentList $ArgumentList -PassThru
                                        if (-not $StartStopDaemon_Process.WaitForExit(10000)) {
                                            Write-Log "start-stop-daemon failed to close $($Title) within 10 seconds$(if ($Name) {": $($Name)"})"
                                        }
                                    }
                                }
                                if (Test-Path $MI.pid_path) {Remove-Item -Path $MI.pid_path -ErrorAction Ignore -Force}
                                if (Test-Path $PIDInfo) {Remove-Item -Path $PIDInfo -ErrorAction Ignore -Force}
                            }

                        } catch {
                            Write-Log -Level Warn "Problem killing screen process $($Job.ScreenName): $($_.Exception.Message)"
                        }
                    } else {
                        $ToKill | Where-Object {-not $_.HasExited} | Foreach-Object {
                            Write-Log "Attempting to kill $($Title) PID $($_.Id)$(if ($Name) {": $($Name)"})"
                            if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                                Invoke-OCDaemon -Cmd "kill $($_.Id)" > $null
                            } else {
                                Stop-Process -InputObject $_ -Force -ErrorAction Ignore
                            }
                        }
                    }

                }

                #
                # Wait for miner to shutdown
                #

                while ($sw.Elapsed.TotalSeconds -le $WaitForExit) {
                    $hx = $ToKill.HasExited
                    if ($hx -contains $null -or $hx -contains $false) {
                        Write-Log "Wait for exit of $($Title) PID $($_) ($($sw.Elapsed.TotalSeconds)s elapsed)$(if ($Name) {": $($Name)"})"
                        Start-Sleep -Seconds 1
                    } else {
                        break
                    }
                }

                if ($WaitForExit -gt 0) {
                    $hx = $ToKill.HasExited
                    if ($hx -contains $null -or $hx -contains $false) {
                        Write-Log -Level Warn "Alas! $($Title) failed to close within $WaitForExit seconds$(if ($Name) {": $($Name)"}) - $(if ($Session.Config.EnableRestartComputer) {"REBOOTING COMPUTER NOW"} else {"PLEASE REBOOT COMPUTER!"})"
                        if ($Session.Config.EnableRestartComputer) {$Session.RestartComputer = $true}
                    } else {
                        Write-Log "$($Title) closed gracefully$(if ($Name) {": $($Name)"})"
                        Start-Sleep -Seconds 1
                    }
                }

                $ToKill.Clear()
                $ToKill = $null
            }
        }
    }

    #
    # Second round - kill
    #
    if ($Job.ProcessId) {
        $Job.ProcessId | Foreach-Object {
            if ($Process = Get-Process -Id $_ -ErrorAction Ignore) {
                if (-not $Process.HasExited) {
                    Write-Log "Attempting to kill $($Title) PID $($_)$(if ($Name) {": $($Name)"})"
                    #if ($IsLinux -and (Test-OCDaemon)) {
                    #    Invoke-OCDaemon -Cmd "kill -9 $($_.Id)" > $null
                    #} else {
                        Stop-Process -InputObject $Process -ErrorAction Ignore -Force
                    #}
                }
            }
        }
        $Job.ProcessId = [int[]]@()
    }

    if ($Job.XJob) {
        if ($Job.XJob.HasMoreData) {Receive-Job $Job.XJob > $null}
        Remove-Job $Job.XJob -Force -ErrorAction Ignore
        $Job.Name = $null
        $Job.XJob = $null
    }

    if ($IsLinux -and $Job.ScreenName) {
        try {
            if ($Job.ScreenCmd -eq "screen") {
                $ScreenCmd = "screen -ls | grep $($Job.ScreenName) | cut -f1 -d'.' | sed 's/\W//g'"
                if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                    $ScreenProcessIds = Invoke-OCDaemon -Cmd $ScreenCmd
                    $OCDcount++
                } else {
                    $ScreenProcessIds = Invoke-Expression $ScreenCmd
                }
                $ScreenProcessIds | Foreach-Object {
                    $ScreenProcessId = [int]$_
                    if ($ScreenProcessId) {
                        $ArgumentList = "-S $($ScreenProcessId) -X quit"
                        if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                            $Cmd = "screen $ArgumentList"
                            $Msg = Invoke-OCDaemon -Cmd $Cmd
                            if ($Msg) {Write-Log "OCDaemon for `"$Cmd`" reports: $Msg"}
                        } else {
                            $Screen_Process = Start-Process "screen" -ArgumentList $ArgumentList -PassThru
                            $Screen_Process.WaitForExit(5000) > $null
                        }
                    }
                }
            } elseif ($Job.ScreenCmd -eq "tmux") {
                $ArgumentList = "kill-session -t $($Job.ScreenName) >/dev/null 2>&1"
                if ($Session.Config.EnableMinersAsRoot -and (Test-OCDaemon)) {
                    $Cmd = "tmux $ArgumentList"
                    $Msg = Invoke-OCDaemon -Cmd $Cmd
                    if ($Msg) {Write-Log "OCDaemon for `"$Cmd`" reports: $Msg"}
                } else {
                    $Screen_Process = Start-Process "tmux" -ArgumentList $ArgumentList -PassThru
                    $Screen_Process.WaitForExit(5000) > $null
                }
            }
        } catch {
            Write-Log -Level Warn "Problem killing bash $($Job.ScreenCmd) $($Job.ScreenName): $($_.Exception.Message)"
        }

        if ($Job.WorkingDir -and (Test-Path $Job.WorkingDir) -and $Session.Config.EnableMinersAsRoot -and -not (Test-IsElevated) -and (Test-OCDaemon)) {
            try {
                Invoke-OCDaemon -Cmd "$(Get-Location)/IncludesLinux/bash/setperms.sh `"$($Job.WorkingDir)`" root" -Quiet > $null
            } catch {
                Write-Log -Level Warn "Problem setting permissions inside $($Job.WorkingDir): $($_.Exception.Message)"
            }
        }
    }
}

function Start-Wrapper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$ProcessId = 0,
        [Parameter(Mandatory = $false)]
        [String]$LogPath = ""
    )
    if (-not $ProcessId -or -not $LogPath) {return}

    Start-Job -FilePath .\Scripts\Wrapper.ps1 -ArgumentList $PID, $ProcessId, $LogPath
}