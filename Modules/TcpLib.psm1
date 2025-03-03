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