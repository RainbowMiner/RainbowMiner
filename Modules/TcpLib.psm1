#
# TCP functions
#

function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $false)]
        [String]$Port, 
        [Parameter(Mandatory = $false)]
        [String]$Request = "",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds,
        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},
        [Parameter(Mandatory = $false)]
        [Switch]$DoNotSendNewline,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet,
        [Parameter(Mandatory = $false)]
        [Switch]$UseSSL,
        [Parameter(Mandatory = $false)]
        [Switch]$WriteOnly,
        [Parameter(Mandatory = $false)]
        [Switch]$ReadToEnd
    )
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    $Response = $Client = $Stream = $tcpStream = $Reader = $Writer = $null
    try {
        if ($Server -match "^http") {
            $Uri = [System.Uri]::New($Server)
            $Server = $Uri.Host
            $Port   = $Uri.Port
            $UseSSL = $Uri.Scheme -eq "https"
        }
        $Client = [System.Net.Sockets.TcpClient]::new($Server, $Port)
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000

        #$Client.LingerState = [System.Net.Sockets.LingerOption]::new($true, 0)

        if ($UseSSL) {
            $tcpStream = $Client.GetStream()
            $Stream = [System.Net.Security.SslStream]::new($tcpStream,$false,({$True} -as [Net.Security.RemoteCertificateValidationCallback]))
            $Stream.AuthenticateAsClient($Server)
        } else {
            $Stream = $Client.GetStream()
        }

        $Writer = [System.IO.StreamWriter]::new($Stream)
        if (-not $WriteOnly -or $Uri) {$Reader = [System.IO.StreamReader]::new($Stream)}
        $Writer.AutoFlush = $true

        if ($Uri) {
            $Writer.NewLine = "`r`n"
            $Writer.WriteLine("GET $($Uri.PathAndQuery) HTTP/1.1")
            $Writer.WriteLine("Host: $($Server):$($Port)")
            $Writer.WriteLine("Cache-Control: no-cache")
            if ($headers -and $headers.Keys) {
                $headers.Keys | Foreach-Object {$Writer.WriteLine("$($_): $($headers[$_])")}
            }
            $Writer.WriteLine("Connection: close")
            $Writer.WriteLine("")

            $cnt = 0
            $closed = $false
            while ($cnt -lt 20 -and -not $Reader.EndOfStream -and ($line = $Reader.ReadLine())) {
                $line = $line.Trim()
                if ($line -match "HTTP/[0-9\.]+\s+(\d{3}.*)") {$HttpCheck = $Matches[1]}
                elseif ($line -match "Connection:\s+close") {$closed = $true}
                $cnt++
            }

            if ($line -eq $null) {throw "empty response"}
            if (-not $HttpCheck) {throw "invalid response"}
            if ($HttpCheck -notmatch "^2") {throw $HttpCheck}

            $Response = $Reader.ReadToEnd()
        } else {
            if ($Request) {if ($DoNotSendNewline) {$Writer.Write($Request)} else {$Writer.WriteLine($Request)}}
            if (-not $WriteOnly) {$Response = if ($ReadToEnd) {$Reader.ReadToEnd()} else {$Reader.ReadLine()}}
        }
    }
    catch {
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "TCP request to $($Server):$($Port) failed: $($_.Exception.Message)"
    }
    finally {
        if ($Reader) {$Reader.Dispose(); $Reader = $null}
        if ($Writer) {$Writer.Dispose(); $Writer = $null}
        if ($Stream) {$Stream.Dispose(); $Stream = $null}
        if ($tcpStream) {$tcpStream.Dispose(); $tcpStream = $null}
        if ($Client) {$Client.Close(); $Client.Dispose(); $Client = $null}
    }

    $Response
}

function Invoke-TcpRead {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $true)]
        [String]$Port, 
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet
    )
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    $Response = $Client = $Stream = $Reader = $null
    try {
        $Client = [System.Net.Sockets.TcpClient]::new($Server, $Port)
        $Stream = $Client.GetStream()
        $Reader = [System.IO.StreamReader]::new($Stream)
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Response = $Reader.ReadToEnd()
    }
    catch {
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "Could not read from $($Server):$($Port)"
    }
    finally {
        if ($Reader) {$Reader.Dispose(); $Reader = $null}
        if ($Stream) {$Stream.Dispose(); $Stream = $null}
        if ($Client) {$Client.Close(); $Client.Dispose(); $Client = $null}
    }

    $Response
}

function Test-TcpServer {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $false)]
        [String]$Port = 4000, 
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 1, #seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$ConvertToIP
    )
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    elseif ($ConvertToIP) {      
        try {$Server = [ipaddress]$Server}
        catch {
            try {
                $Server = [system.Net.Dns]::GetHostByName($Server).AddressList | Where-Object {$_.IPAddressToString -match "^\d+\.\d+\.\d+\.\d+$"} | select-object -index 0
            } catch {
                return $false
            }
        }
    }

    $Client = $null
    try {
        $Client = [System.Net.Sockets.TcpClient]::new()
        $Conn   = $Client.BeginConnect($Server,$Port,$null,$null)
        $Result = $Conn.AsyncWaitHandle.WaitOne($Timeout*1000,$false)
        if ($Result) {$Client.EndConnect($Conn)>$null}
    } catch {
        if ($Verbose) {Write-Log -Level Warn "Test-TcpServer $($Server):$($Port) failed $($_.Exception.Message)"}
        $Result = $false
    }
    finally {
        if ($Client) {$Client.Close(); $Client.Dispose(); $Client = $null}
    }

    $Result
}

function Get-ServerAddressState {
    # the learned address of the configured server. Lives in $Session, so the AsyncLoader and API runspaces see it too
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ServerName,
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )
    $Key = "$($ServerName.ToLower())|$($Port)"
    $State = $Session.ServerAddress
    if (-not $State -or $State.Key -ne $Key) {
        $State = [PSCustomObject]@{
            Key         = $Key
            ServerName  = $ServerName
            Port        = $Port
            IP          = $null
            MachineName = ""
            Timestamp   = [int64]0
            ProbeHost   = $null
            ProbeTime   = [int64]0
        }
        $PathToFile = ".\Data\serveraddr.json"
        if (Test-Path $PathToFile) {
            try {
                $Data = Get-ContentByStreamReader $PathToFile | ConvertFrom-Json -ErrorAction Stop
                if ("$($Data.servername)".ToLower() -eq $ServerName.ToLower() -and [int]$Data.serverport -eq $Port -and "$($Data.ip)" -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    $State.IP          = "$($Data.ip)"
                    $State.MachineName = "$($Data.machinename)"
                    $State.Timestamp   = [int64]$Data.timestamp
                }
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
        $Session.ServerAddress = $State
    }
    $State
}

function Get-ServerAddress {
    # the host to build server urls with: the learned ip first, then the configured name. $null when nothing answers
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$ServerName = "",
        [Parameter(Mandatory = $false)]
        [Int]$Port = 0,
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 2
    )
    if (-not $ServerName -or -not $Port) {return}
    $State = Get-ServerAddressState -ServerName $ServerName -Port $Port
    $Now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    # several call sites probe per round: share one result for a few seconds
    if ($State.ProbeTime -gt ($Now - 3)) {return $State.ProbeHost}
    $ServerHost = $null
    if ($State.IP -and $State.IP -ne $ServerName -and (Test-TcpServer -Server $State.IP -Port $Port -Timeout $Timeout)) {
        $ServerHost = $State.IP
        if ($State.ProbeHost -ne $ServerHost) {
            Write-Log -Level Info "Server $($ServerName):$($Port) is reached at the announced address $($ServerHost)"
        }
    } else {
        # a name is resolved here and its ipv4 addresses are probed one by one: TcpClient on pwsh 7 walks the whole
        # address list itself, ipv6 first, and a stale or unreachable ipv6 address eats the complete timeout - the same
        # would happen to the http calls later on, so the working ip goes into the urls
        $Candidates = @()
        if ($ServerName -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -and $ServerName -ne "localhost") {
            try {
                $Candidates = @([System.Net.Dns]::GetHostAddresses($ServerName) | Where-Object {$_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork} | Foreach-Object {$_.ToString()} | Select-Object -Unique -First 3)
            } catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
        if ($Candidates.Count) {
            foreach ($Candidate in $Candidates) {
                if ($Candidate -ne $State.IP -and (Test-TcpServer -Server $Candidate -Port $Port -Timeout $Timeout)) {$ServerHost = $Candidate; break}
            }
        } elseif (Test-TcpServer -Server $ServerName -Port $Port -Timeout $Timeout) {
            $ServerHost = $ServerName
        }
        if ($ServerHost -and $State.IP -and $State.IP -ne $ServerName) {
            # the announced ip is dead but the name answers again: forget it, or every probe pays the timeout first
            Write-Log -Level Info "Server $($ServerName):$($Port) no longer answers at the announced address $($State.IP), using the configured name again"
            $State.IP = $null
            $State.MachineName = ""
            Remove-Item ".\Data\serveraddr.json" -Force -ErrorAction Ignore
        }
    }
    $State.ProbeHost = $ServerHost
    $State.ProbeTime = $Now
    $ServerHost
}

function Get-ServerUrl {
    # the url of a server endpoint. With -SSL the host is registered for certificate checks: chain validation, or the pinned fingerprint
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ServerHost,
        [Parameter(Mandatory = $true)]
        $Port,
        [Parameter(Mandatory = $false)]
        [String]$Path = "",
        [Parameter(Mandatory = $false)]
        [Switch]$SSL,
        [Parameter(Mandatory = $false)]
        [String]$CertHash = ""
    )
    if ($SSL) {
        try {[RBMCertPin]::Set($ServerHost, $CertHash)} catch {if ($Error.Count){$Error.RemoveAt(0)}}
        "https://$($ServerHost):$($Port)/$($Path)"
    } else {
        try {[RBMCertPin]::Remove($ServerHost)} catch {if ($Error.Count){$Error.RemoveAt(0)}}
        "http://$($ServerHost):$($Port)/$($Path)"
    }
}

function Set-ServerAddress {
    # a verified announcement: remember the server's address for all runspaces and across restarts
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ServerName,
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $true)]
        [String]$IP,
        [Parameter(Mandatory = $false)]
        [String]$MachineName = "",
        [Parameter(Mandatory = $false)]
        [Int64]$Timestamp = 0
    )
    $State = Get-ServerAddressState -ServerName $ServerName -Port $Port
    $Changed = ($State.IP -ne $IP) -or ($State.MachineName -ne $MachineName)
    $State.IP          = $IP
    $State.MachineName = $MachineName
    $State.Timestamp   = $Timestamp
    if ($Changed) {
        $State.ProbeTime = 0
        Set-ContentJson -PathToFile ".\Data\serveraddr.json" -Data ([PSCustomObject]@{servername = $ServerName; serverport = $Port; machinename = $MachineName; ip = $IP; timestamp = $Timestamp}) -Quiet > $null
        Write-Log -Level Info "Server $($ServerName):$($Port) announced its address $($IP)$(if ($MachineName) {" (machine $($MachineName))"})"
    }
    $Changed
}

function Invoke-PingStratum {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [String]$Server,
    [Parameter(Mandatory = $True)]
    [Int]$Port,
    [Parameter(Mandatory = $False)]
    [String]$User="",
    [Parameter(Mandatory = $False)]
    [String]$Pass="x",
    [Parameter(Mandatory = $False)]
    [String]$Worker=$Session.Config.WorkerName,
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 3,
    [Parameter(Mandatory = $False)]
    [bool]$WaitForResponse = $False,
    [Parameter(Mandatory = $False)]
    [ValidateSet("Stratum","EthProxy","Qtminer")]
    [string]$Method = "Stratum",
    [Parameter(Mandatory = $false)]
    [Switch]$UseSSL
)    
    $Request = if ($Method -eq "EthProxy") {"{`"id`": 1, `"method`": `"login`", `"params`": {`"login`": `"$($User)`", `"pass`": `"$($Pass)`", `"rigid`": `"$($Worker)`", `"agent`": `"RainbowMiner/$($Session.Version)`"}}"} elseif ($Method -eq "qtminer") {"{`"id`":1, `"jsonrpc`":`"2.0`", `"method`":`"eth_login`", `"params`":[`"$($User)`",`"$($Pass)`"]}"} else {"{`"id`": 1, `"method`": `"mining.subscribe`", `"params`": [`"RainbowMiner/$($Session.Version)`"]}"}
    try {
        if ($WaitForResponse) {
            $Result = Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -UseSSL:$UseSSL -Quiet
            if ($Result) {
                $Result = ConvertFrom-Json $Result -ErrorAction Stop
                if ($Result.id -eq 1 -and -not $Result.error) {$true}
            }
        } else {
            Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -Quiet -WriteOnly -UseSSL:$UseSSL > $null
            $true
        }
    } catch {}
}