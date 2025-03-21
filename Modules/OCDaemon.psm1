﻿
function Set-BashFile {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $true)]
    $FilePath,
    [Parameter(Mandatory = $False)]
    $Cmd
)
    if (-not (Test-Path Variable:Global:GlobalOCD)) {[System.Collections.ArrayList]$Global:GlobalOCD = @()}

    if ($Cmd) {
        [System.Collections.ArrayList]$OCDcmd = @()
        $Cmd | Foreach-Object {[void]$OCDcmd.Add($_)}
    } else {
        $OCDcmd = $Global:GlobalOCD
    }
    if ($OCDcmd.Count) {
        $OCDcmd.Insert(0,"`#`!/usr/bin/env bash")
        $OCDcmd | Out-File "$FilePath" -ErrorAction Ignore -Force
        $OCDcmd.Clear()
    }
    if ($Cmd) {
        $OCDCmd = $null
        Remove-Variable -Name OCDcmd -ErrorAction Ignore
    }
}

function Invoke-OCDaemonWithName {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $False)]
    $FilePath,
    [Parameter(Mandatory = $False)]
    $Name,
    [Parameter(Mandatory = $False)]
    $Cmd,
    [Parameter(Mandatory = $False)]
    [Switch]$Move = $false,
    [Parameter(Mandatory = $False)]
    [Switch]$Quiet = $false
)
    if (-not ($Cmd -or $Global:GlobalOCD.Count) -and (-not $FilePath -or -not (Test-Path $FilePath))) {return}

    if (-not $Name) {$Name = (Get-ChildItem $FilePath -ErrorAction Ignore).BaseName}

    "$(Get-Date)" | Out-File "/opt/rainbowminer/ocdcmd/$Name.lock" -ErrorAction Ignore -Force
    if ($Cmd -or $Global:GlobalOCD.Count) {
        Set-BashFile -FilePath "/opt/rainbowminer/ocdcmd/$Name.sh" -Cmd $Cmd
    } else {
        Copy-Item $FilePath "/opt/rainbowminer/ocdcmd/$Name.sh" -ErrorAction Ignore
        if ($Move) {Remove-Item $FilePath -Force -ErrorAction Ignore}
    }
    if (Test-Path "/opt/rainbowminer/ocdcmd/$Name.lock") {Remove-Item "/opt/rainbowminer/ocdcmd/$Name.lock" -Force -ErrorAction Ignore}
    $StopWatch = [System.Diagnostics.StopWatch]::New()
    $StopWatch.Start()
    $stoptime = 5000
    While ((Test-Path "/opt/rainbowminer/ocdcmd/$Name.sh") -and $StopWatch.ElapsedMilliseconds -lt $stoptime) {
        Start-Sleep -Seconds 1
        if ($stoptime -lt 30000 -and (Test-Path "/opt/rainbowminer/ocdcmd/$Name.run")) {$stoptime = 30000}
    }

    $StopWatch = $null
    if (Test-Path "/opt/rainbowminer/ocdcmd/$Name.out") {
        if (-not $Quiet) {Get-Content "/opt/rainbowminer/ocdcmd/$Name.out" -Raw}
        Remove-Item "/opt/rainbowminer/ocdcmd/$Name.out" -Force -ErrorAction Ignore
    }
    if ($Quiet) {-not (Test-Path "/opt/rainbowminer/ocdcmd/$Name.sh")}
}

function Initialize-OCDaemon {
    if ($IsLinux) {
        try {
            $pre = Get-MD5Hash $Pwd
            $Session.OCDaemonPrefix = "$($pre.Substring(0,4))$($pre.Substring(28,4))"
            $Session.OCDaemonCount  = 0
            if (Test-Path "/opt/rainbowminer/ocdcmd") {
                Get-ChildItem "/opt/rainbowminer/ocdcmd" -Filter "$($Session.OCDaemonPrefix)*" -File -Force | Foreach-Object {Remove-Item $_.FullName -ErrorAction Ignore -Force}
            }
        } catch {}
    }
}

function Test-OCDaemon {
    $IsLinux -and (Test-Path "/var/run/ocdaemon.pid") -and (Get-Content "/var/run/ocdaemon.pid" -Raw -ErrorAction Ignore | Foreach-Object {Get-Process -Id $_ -ErrorAction Ignore} | Measure-Object).Count
}

function Set-OCDaemon {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$Cmd,
    [Parameter(Mandatory = $False)]
    $OnEmptyAdd
)
    if (-not (Test-Path Variable:Global:GlobalOCD)) {$Global:GlobalOCD = [System.Collections.ArrayList]@()}
    if ($OnEmptyAdd -and -not $Global:GlobalOCD.Count) {$OnEmptyAdd | Foreach-Object {[void]$Global:GlobalOCD.Add($_)}}
    [void]$Global:GlobalOCD.Add($Cmd)
}


function Invoke-OCDaemon {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $False)]
    $Cmd,
    [Parameter(Mandatory = $False)]
    $FilePath,
    [Parameter(Mandatory = $False)]
    $Miner,
    [Parameter(Mandatory = $False)]
    [Switch]$Quiet
)
    if (-not (Test-Path Variable:Global:GlobalOCD)) {$Global:GlobalOCD = [System.Collections.ArrayList]@()}

    if ($Cmd -or $Global:GlobalOCD.Count) {

        $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()

        if ($FilePath -or $Miner) {
            if ($Miner) {
                $ScreenName = "oc_$(("$($Miner.DeviceName -join "_")" -replace "[^A-Z0-9_-]").ToLower())"
                $FilePath = Join-Path (Split-Path $Miner.Path) "start$($ScreenName)_$($Miner.BaseAlgorithm -join "_").sh".ToLower()
            } else {
                if ($FilePath -notmatch "\.sh$") {$FilePath = "$FilePath.sh"}
                $FilePath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
                $ScreenName = "$(Split-Path $FilePath -Leaf)" -replace "\.sh$"
            }
            Set-BashFile -FilePath $FilePath -Cmd $Cmd
            if (Test-Path $FilePath) {
                (Start-Process "chmod" -ArgumentList "+x",$FilePath -PassThru).WaitForExit() > $null
            }
        }

        if (Test-OCDaemon) {
            if ($FilePath) {
                $tmpfn = "$($Session.OCDaemonPrefix).0.$ScreenName"
                Invoke-OCDaemonWithName -Name $tmpfn -FilePath $FilePath -Quiet:$Quiet
                $Session.OCDaemonCount++
            } else {
                $tmpfn = "$($Session.OCDaemonPrefix).$($Session.OCDaemonCount)"
                Invoke-OCDaemonWithName -Name $tmpfn -Cmd $Cmd -Quiet:$Quiet
                $Session.OCDaemonCount++
            }
            if (Test-Path "/opt/rainbowminer/ocdcmd/$tmpfn.sh") {
                Write-Log -Level Warn "OCDaemon failed. Please run `"./install.sh`" at the command line"
            }
        } else {
            $CommandTool = if ((-not $Session.Config.LinuxMinerTerminal -or $Session.Config.LinuxMinerTerminal -in @("auto","tmux")) -and (Get-Command "tmux" -ErrorAction Ignore)) {"tmux"} 
                           elseif ((-not $Session.Config.LinuxMinerTerminal -or $Session.Config.LinuxMinerTerminal -in @("auto","screen")) -and (Get-Command "screen" -ErrorAction Ignore)) {"screen"}

            if ($CommandTool) {
                if (-not $FilePath -and -not $Miner) {
                    $FilePath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Cache\tmp_$([System.IO.Path]::GetRandomFileName() -replace "\..+$").sh")
                    $ScreenName = "$(Split-Path $FilePath -Leaf)" -replace "\.sh$"
                    $IsTemporaryPath = $true
                    Set-BashFile -FilePath $FilePath -Cmd $Cmd
                } else {
                    $IsTemporaryPath = $false
                }

                $WorkerName = ($Session.Config.WorkerName -replace "[^A-Z0-9_-]").ToLower()

                $ScreenName = "$($WorkerName)_$($ScreenName)"

                if ($Miner) {
                    $DeviceNameMatch = "($(("$($Miner.DeviceName -join "|")" -replace "[^A-Z0-9\|]").ToLower()))"

                    if ($CommandTool -eq "tmux") {
                        Invoke-Exe "tmux" -ArgumentList "list-sessions -F '#{session_name}' 2>/dev/null" -ExpandLines | Where-Object { $_ -match "$($WorkerName)_oc_[a-z0-9_-]+" } | ForEach-Object {
                            $Name = $_
                            if ($Name -match $DeviceNameMatch) {
                                Invoke-Exe "tmux" -ArgumentList "send-keys -t $Name C-c" > $null
                                Start-Sleep -Milliseconds 250
                                Invoke-Exe "tmux" -ArgumentList "kill-session -t $Name" > $null
                                Start-Sleep -Milliseconds 250
                            }
                        }
                    } else {
                        Invoke-Exe "screen" -ArgumentList "-ls" -ExpandLines | Where-Object { $_ -match "(\d+\.$($WorkerName)_oc_[a-z0-9_-]+)" } | ForEach-Object {
                            $Name = $Matches[1]
                            if ($Name -match $DeviceNameMatch) {
                                Invoke-Exe "screen" -ArgumentList "-S $Name -X stuff `^C" > $null
                                Start-Sleep -Milliseconds 250
                                Invoke-Exe "screen" -ArgumentList "-S $Name -X quit" > $null
                                Start-Sleep -Milliseconds 250
                            }
                        }
                    }
                } else {
                    if ($CommandTool -eq "tmux") {
                        Invoke-Exe "tmux" -ArgumentList "list-sessions -F '#{session_name}' 2>/dev/null" -ExpandLines | Where-Object { $_ -match "$ScreenName" } | ForEach-Object {
                            $Name = $_
                            Invoke-Exe "tmux" -ArgumentList "send-keys -t $Name C-c" > $null
                            Start-Sleep -Milliseconds 250
                            Invoke-Exe "tmux" -ArgumentList "kill-session -t $Name" > $null
                            Start-Sleep -Milliseconds 250
                        }
                    } else {
                        Invoke-Exe "screen" -ArgumentList "-ls" -ExpandLines |
                        Where-Object { $_ -match "(\d+\.$ScreenName)\s+" } |
                        ForEach-Object {
                            $Name = $Matches[1]
                            Invoke-Exe "screen" -ArgumentList "-S $Name -X stuff `^C" > $null
                            Start-Sleep -Milliseconds 250
                            Invoke-Exe "screen" -ArgumentList "-S $Name -X quit" > $null
                            Start-Sleep -Milliseconds 250
                        }
                    }
                }

                if (Test-Path $FilePath) {
                    (Start-Process "chmod" -ArgumentList "+x",$FilePath -PassThru).WaitForExit() > $null

                    if ($CommandTool -eq "tmux") {
                        Invoke-Exe "tmux" -ArgumentList "new-session -d -s $ScreenName" > $null
                        Start-Sleep -Milliseconds 500
                        Invoke-Exe "tmux" -ArgumentList "send-keys -t $ScreenName $FilePath C-m" > $null
                    } else {
                        Invoke-Exe "screen" -ArgumentList "-S $ScreenName -d -m" > $null
                        Start-Sleep -Milliseconds 500
                        Invoke-Exe "screen" -ArgumentList "-S $ScreenName -X stuff $FilePath`n" > $null
                    }

                    if ($IsTemporaryPath) {Remove-Item $FilePath -Force -ErrorAction Ignore}
                }
            }
        }
    }
}