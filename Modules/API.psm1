Function Start-APIServer {

    # Create a global synchronized hashtable that all threads can access to pass data between the main script and API
    $Global:API = [System.Collections.Hashtable]::Synchronized(@{})

    # Initialize firewall and prefix
    if ($Session.IsAdmin -and $Session.Config.APIport) {Initialize-APIServer -Port $Session.Config.APIport -ServerPort $(if ($Session.Config.EnableServerDiscovery -and $Session.Config.RunMode -eq "Client") {$Session.Config.ServerPort} else {0})}
  
    # Setup flags for controlling script execution
    $API.Stop        = $false
    $API.Pause       = $false
    $API.Update      = $false
    $API.Reboot      = $false
    $API.UpdateBalance = $false
    $API.UpdateMRR   = $false
    $API.WatchdogReset = $false
    $API.ClearCache  = $false
    $API.ApplyOC     = $false
    $API.LockMiners  = $false
    $API.SetDevices  = $false
    $API.DeviceSelection = $null
    $API.IsVirtual   = $false
    $API.CmdMenu     = @()
    $API.CmdKey      = ''
    $API.APIport     = $Session.Config.APIport
    $API.RandTag     = Get-MD5Hash("$((Get-Date).ToUniversalTime())$(Get-Random)")
    $API.RemoteAPI   = Test-APIServer -Port $Session.Config.APIport
    $API.IsServer    = $Session.Config.RunMode -eq "Server"
    $API.MachineName = $Session.MachineName
    $API.Debug       = $Session.LogLevel -eq "Debug"
    $API.PauseMiners = [PSCustomObject]@{Pause = $false;PauseIA = $false;PauseIAOnly = $false}

    Set-APIConfig
    Set-APICredentials

    # Setup the global HTTP listener
    $Global:APIHttpListener = New-Object System.Net.HttpListener
    if ($API.RemoteAPI) {
        [void]$Global:APIHttpListener.Prefixes.Add("http://+:$($API.APIport)/")
        # Require authentication when listening remotely
        $Global:APIHttpListener.AuthenticationSchemes = if ($API.APIauth) {[System.Net.AuthenticationSchemes]::Basic} else {[System.Net.AuthenticationSchemes]::Anonymous}
    } else {
        [void]$Global:APIHttpListener.Prefixes.Add("http://localhost:$($API.APIport)/")
    }
    $Global:APIHttpListener.Start()

    # Setup additional, global variables for server handling
    $Global:APIClients   = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    $Global:APIListeners = [System.Collections.ArrayList]@()
    $Global:APIAccessDB  = [System.Collections.Hashtable]::Synchronized(@{})
    $Global:APICacheDB   = [System.Collections.Hashtable]::Synchronized(@{})

    # Setup runspacepool to launch the API webserver in separate threads
    $initialSessionState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('API', $API, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('Rates', $Global:Rates, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('StatsCache', $Global:StatsCache, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('Session', $Session, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('AsyncLoader', $AsyncLoader, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('APIClients', $APIClients, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('APIAccessDB', $APIAccessDB, $null))
    [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('APICacheDB', $APICacheDB, $null))
    if (Initialize-HttpClient) {
        [void]$initialSessionState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new("GlobalHttpClient", $Global:GlobalHttpClient, $null))
    }

    foreach ($Module in @("APILib","ConfigLib","Include","MiningRigRentals","StatLib","TcpLib","WebLib","WhatToMineLib")) {
        [void]$initialSessionState.ImportPSModule((Resolve-Path ".\Modules\$($Module).psm1"))
    }

    $MinThreads = 1
    $MaxThreads = if ($Session.Config.APIthreads) {$Session.Config.APIthreads} elseif ($API.IsServer) {$MinThreads = 2;[Math]::Min($Global:GlobalCPUInfo.Threads,8)} else {[Math]::Min($Global:GlobalCPUInfo.Cores,2)}
    $MaxThreads = [Math]::Max($MinThreads,$MaxThreads)

    $Global:APIRunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads, $initialSessionState, $Host)
    $Global:APIRunspacePool.Open()

    # pass the text: AddScript parses it per thread anyway, a [ScriptBlock]::Create copy would stay alive in the script cache (~2.7 MB)
    $APIScript = Get-Content ".\Scripts\API.ps1" -Raw

    for($ThreadID = 0; $ThreadID -lt $MaxThreads; $ThreadID++) {
        $newPS = [PowerShell]::Create().AddScript($APIScript).AddParameters(@{'ThreadID'=$ThreadID;'APIHttpListener'=$Global:APIHttpListener;'CurrentPwd'=$PWD})
        $newPS.RunspacePool = $Global:APIRunspacePool

        [void]$Global:APIListeners.Add([PSCustomObject]@{
            Runspace   = $newPS.BeginInvoke()
		    PowerShell = $newPS 
        })
    }
    Write-Log -Level Info "Started $($MaxThreads) API threads on port $($API.APIport)"
}

Function Clear-APIServerStreams {
    # the pool shares the console host, so a listener pipeline mirrors every Write-Host
    # of the whole process into its information buffers - drain them, they are never read
    if ($Global:APIListeners) {
        foreach ($Listener in $Global:APIListeners) {
            try {$Listener.PowerShell.Streams.ClearStreams()} catch {}
        }
    }
}

Function Stop-APIServer {
    if (-not (Test-Path Variable:Global:API)) {return}
    $Global:API.Stop = $true

    if ($Global:APIListeners) {
        foreach ($Listener in $Global:APIListeners.ToArray()) {
			$Listener.PowerShell.Dispose()
			[void]$Global:APIListeners.Remove($Listener)
		}
    }
    $Global:APIListeners.Clear()

    $Global:APIRunspacePool.Close()

    $Global:APIHttpListener.Stop()
    $Global:APIHttpListener.Close()

    $Global:APIListeners = $null
    $Global:APIRunspacePool = $null
    $Global:APIHttpListener = $null

    $Global:API = $null
    Remove-Variable -Name API -Scope Global -Force -ErrorAction Ignore
}

function Set-APIConfig {
    $API.LockConfig  = $Session.Config.APIlockConfig
    $API.MaxLoginAttempts = $Session.Config.APImaxLoginAttemps
    $API.BlockLoginAttemptsTime = ConvertFrom-Time $Session.Config.APIblockLoginAttemptsTime
    $API.AllowIPs    = $Session.Config.APIallowIPs
}

function Set-APICredentials {
    $API.APIauth     = $Session.Config.APIauth -and $Session.Config.APIuser -and $Session.Config.APIpassword
    $API.APIuser     = $Session.Config.APIuser
    $API.APIpassword = $Session.Config.APIpassword
}

function Get-APIServerName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Protocol = "TCP"
    )
    "RainbowMiner API $($Port)$(if ($Protocol -ne "TCP") {" $Protocol"})"
}

function Get-APIBeaconHmac {
    # the announcement's signature: HMAC-SHA256 over the message, keyed with the api password shared by server and clients
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Message,
        [Parameter(Mandatory = $true)]
        [String]$Password
    )
    $hmac = $null
    try {
        $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Password))
        $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Message))
    } finally {
        if ($hmac) {$hmac.Dispose()}
    }
    -join ($hash | Foreach-Object {$_.ToString("x2")})
}

function Send-APIServerUdp {
    # announce the api address to the local network: one directed broadcast per ipv4 interface, each carrying that interface's ip
    # datagram: RBM2|<machinename>|<ipv4>|<port>|<unixts>|<hmac>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [String]$MachineName = [System.Environment]::MachineName,
        [Parameter(Mandatory = $false)]
        [String]$Password = ""
    )
    if (-not $Port -or -not $Password) {return $false}

    $Targets = [System.Collections.Generic.List[PSCustomObject]]::new()
    try {
        foreach ($NetIf in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($NetIf.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up -or $NetIf.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback) {continue}
            foreach ($Unicast in $NetIf.GetIPProperties().UnicastAddresses) {
                if ($Unicast.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or -not $Unicast.IPv4Mask) {continue}
                $ip   = $Unicast.Address.GetAddressBytes()
                $mask = $Unicast.IPv4Mask.GetAddressBytes()
                $bc   = [byte[]]::new(4)
                for ($i = 0; $i -lt 4; $i++) {$bc[$i] = [byte]($ip[$i] -bor (255 -bxor $mask[$i]))}
                [void]$Targets.Add([PSCustomObject]@{IP = $Unicast.Address.ToString(); Broadcast = [System.Net.IPAddress]::new($bc)})
            }
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
    if (-not $Targets.Count -and $Session.MyIP) {
        [void]$Targets.Add([PSCustomObject]@{IP = $Session.MyIP; Broadcast = [System.Net.IPAddress]::Broadcast})
    } elseif ($Targets.Count -gt 1 -and $Session.MyIP) {
        # the default route's interface goes first: a client that hears several interfaces keeps the first announcement of a timestamp
        for ($i = 1; $i -lt $Targets.Count; $i++) {
            if ($Targets[$i].IP -eq $Session.MyIP) {
                $Target = $Targets[$i]
                $Targets.RemoveAt($i)
                $Targets.Insert(0, $Target)
                break
            }
        }
    }

    $Sent = 0
    $UdpClient = $null
    try {
        $UdpClient = [System.Net.Sockets.UdpClient]::new([System.Net.Sockets.AddressFamily]::InterNetwork)
        $UdpClient.EnableBroadcast = $true
        $Timestamp = Get-UnixTimestamp
        foreach ($Target in $Targets) {
            $Message = "RBM2|$($MachineName)|$($Target.IP)|$($Port)|$($Timestamp)"
            $Buffer  = [System.Text.Encoding]::ASCII.GetBytes("$($Message)|$(Get-APIBeaconHmac -Message $Message -Password $Password)")
            try {
                [void]$UdpClient.Send($Buffer, $Buffer.Length, [System.Net.IPEndPoint]::new($Target.Broadcast, $Port))
                $Sent++
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    } finally {
        if ($UdpClient) {$UdpClient.Close(); $UdpClient.Dispose(); $UdpClient = $null}
    }
    $Targets.Clear()
    $Sent -gt 0
}

function Start-APIBeacon {
    # client side: one udp socket on the server's api port, polled by Receive-APIBeacon once per round. No thread, no event
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )
    if (-not (Test-Path Variable:Global:APIBeacon)) {
        $Global:APIBeacon = [hashtable]@{Port = 0; Client = $null; Failed = 0; LastTs = [int64]0; SkewWarned = $false}
    }
    $B = $Global:APIBeacon
    if ($B.Client -and $B.Port -eq $Port) {return $true}
    if ($B.Client) {Stop-APIBeacon}
    if ($B.Failed -and $B.Port -eq $Port -and $B.Failed -gt (Get-Date).AddMinutes(-10)) {return $false}
    $B.Port = $Port
    $Udp = $null
    try {
        $Udp = [System.Net.Sockets.UdpClient]::new([System.Net.Sockets.AddressFamily]::InterNetwork)
        $Udp.ExclusiveAddressUse = $false
        $Udp.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
        $Udp.Client.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, $Port))
        $B.Client = $Udp
        $B.Failed = 0
        Write-Log -Level Info "Listening for server announcements on udp port $($Port)"
        if ($IsWindows -and -not (Test-APIServer -Port $Port -Type "firewall-udp")) {
            Write-Log -Level Warn "No inbound firewall rule for udp port $($Port): server announcements may not arrive. Run InitClient or add the rule `"$(Get-APIServerName -Port $Port -Protocol "UDP")`""
        }
        $true
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Cannot listen for server announcements on udp port $($Port): $($_.Exception.Message)"
        if ($Udp) {try {$Udp.Close(); $Udp.Dispose()} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
        $B.Client = $null
        $B.Failed = Get-Date
        $false
    }
}

function Receive-APIBeacon {
    # drain the pending announcements and accept the ones signed with our server password
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ServerName,
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $true)]
        [String]$Password
    )
    if (-not (Test-Path Variable:Global:APIBeacon) -or -not $Global:APIBeacon.Client) {return}
    $B = $Global:APIBeacon
    $IsIP  = $ServerName -match '^\d{1,3}(\.\d{1,3}){3}$'
    $Label = if ($IsIP) {$ServerName} else {($ServerName -split '\.')[0]}
    $Now   = Get-UnixTimestamp
    $n = 0
    while ($n -lt 50) {
        $n++
        $bytes = $null
        try {
            if ($B.Client.Available -le 0) {break}
            $ep = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
            $bytes = $B.Client.Receive([ref]$ep)
        } catch {
            # WSAECONNRESET and friends: nothing to read from this one, look at the next
            if ($Error.Count){$Error.RemoveAt(0)}
            continue
        }
        if (-not $bytes -or $bytes.Length -gt 512) {continue}
        $Text = [System.Text.Encoding]::ASCII.GetString($bytes)
        if (-not $Text.StartsWith("RBM2|")) {continue}
        $Parts = $Text -split '\|'
        if ($Parts.Count -ne 6) {continue}
        $MachineName = $Parts[1]
        $IP = $Parts[2]
        if ($IP -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or $Parts[3] -notmatch '^\d+$' -or $Parts[4] -notmatch '^\d+$') {continue}
        if ([int]$Parts[3] -ne $Port) {continue}
        $Ts = [int64]$Parts[4]
        if ([Math]::Abs($Now - $Ts) -gt 600) {
            if (-not $B.SkewWarned) {
                Write-Log -Level Warn "Ignoring a server announcement from $($ep.Address): its clock is off by more than 10 minutes"
                $B.SkewWarned = $true
            }
            continue
        }
        if ($Ts -le $B.LastTs) {continue}
        # the sender must be the address it announces: a replayed datagram from another host is worthless
        if ("$($ep.Address)" -ne $IP) {continue}
        $Message = $Text.Substring(0, $Text.LastIndexOf('|'))
        if ((Get-APIBeaconHmac -Message $Message -Password $Password) -ne $Parts[5]) {continue}
        if ($IsIP) {
            # configured by ip: the first accepted announcement must come from that ip, its machine name is bound from then on
            $State = Get-ServerAddressState -ServerName $ServerName -Port $Port
            if ($State.MachineName) {
                if ($MachineName -ne $State.MachineName) {continue}
            } elseif ($IP -ne $ServerName) {continue}
        } elseif ($MachineName -ne $Label) {continue}
        $B.LastTs = $Ts
        Set-ServerAddress -ServerName $ServerName -Port $Port -IP $IP -MachineName $MachineName -Timestamp $Ts > $null
    }
}

function Stop-APIBeacon {
    if (-not (Test-Path Variable:Global:APIBeacon) -or -not $Global:APIBeacon.Client) {return}
    try {$Global:APIBeacon.Client.Close(); $Global:APIBeacon.Client.Dispose()} catch {if ($Error.Count){$Error.RemoveAt(0)}}
    $Global:APIBeacon.Client = $null
}

function Test-APIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [string]$Type = "all"
    )
    $rv = $true
    if ($IsWindows) {
        if ($rv -and ($Type -eq "firewall" -or $Type -eq "firewall-tcp" -or $Type -eq "all")) {
            $FWLname = Get-APIServerName -Port $Port -Protocol "TCP"
            $fwlACLs = & netsh advfirewall firewall show rule name="$($FWLname)" | Out-String
            if (-not $fwlACLs.Contains($FWLname)) {$rv = $false}
        }
        if ($rv -and ($Type -eq "firewall" -or $Type -eq "firewall-udp" -or $Type -eq "all")) {
            $FWLname = Get-APIServerName -Port $Port -Protocol "UDP"
            $fwlACLs = & netsh advfirewall firewall show rule name="$($FWLname)" | Out-String
            if (-not $fwlACLs.Contains($FWLname)) {$rv = $false}
        }
        if ($rv -and ($Type -eq "url" -or $Type -eq "all")) {
            $urlACLs = & netsh http show urlacl | Out-String
            if (-not $urlACLs.Contains("http://+:$($Port)/")) {$rv = $false}
        }
    }
    $rv
}

function Initialize-APIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [Int]$ServerPort = 0
    )

    if ($IsWindows) {
        if (-not (Test-APIServer -Port $Port -Type "url")) {
            # S-1-5-32-545 is the well known SID for the Users group. Use the SID because the name Users is localized for different languages
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "http add urlacl url=http://+:$($Port)/ sddl=D:(A;;GX;;;S-1-5-32-545) user=everyone").WaitForExit(5000)>$null
        }

        if (-not (Test-APIServer -Port $Port -Type "firewall-tcp")) {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"$(Get-APIServerName -Port $Port -Protocol "TCP")`" dir=in action=allow protocol=TCP localport=$($Port)").WaitForExit(5000)>$null
        }

        if (-not (Test-APIServer -Port $Port -Type "firewall-udp")) {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"$(Get-APIServerName -Port $Port -Protocol "UDP")`" dir=in action=allow protocol=UDP localport=$($Port)").WaitForExit(5000)>$null
        }

        # a client listens for the server's announcements on the server's port, which may differ from its own api port
        if ($ServerPort -and $ServerPort -ne $Port -and -not (Test-APIServer -Port $ServerPort -Type "firewall-udp")) {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"$(Get-APIServerName -Port $ServerPort -Protocol "UDP")`" dir=in action=allow protocol=UDP localport=$($ServerPort)").WaitForExit(5000)>$null
        }
    }
}

function Reset-APIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )

    if ($IsWindows) {
        if (Test-APIServer -Port $Port -Type "url") {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "http delete urlacl url=http://+:$($Port)/").WaitForExit(5000)>$null
        }

        if (Test-APIServer -Port $Port -Type "firewall")  {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall delete rule name=`"$(Get-APIServerName -Port $Port -Protocol "TCP")`"").WaitForExit(5000)>$null
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall delete rule name=`"$(Get-APIServerName -Port $Port -Protocol "UDP")`"").WaitForExit(5000)>$null
        }
    }
}
