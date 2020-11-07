function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost", 
        [Parameter(Mandatory = $true)]
        [String]$Port, 
        [Parameter(Mandatory = $false)]
        [String]$Request = "",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$DoNotSendNewline,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet,
        [Parameter(Mandatory = $false)]
        [Switch]$WriteOnly,
        [Parameter(Mandatory = $false)]
        [Switch]$ReadToEnd
    )
    $Response = $null
    if ($Server -eq "localhost") {$Server = "127.0.0.1"}
    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        if (-not $WriteOnly) {$Reader = New-Object System.IO.StreamReader $Stream}
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        if ($Request) {if ($DoNotSendNewline) {$Writer.Write($Request)} else {$Writer.WriteLine($Request)}}
        if (-not $WriteOnly) {$Response = if ($ReadToEnd) {$Reader.ReadToEnd()} else {$Reader.ReadLine()}}
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }
    finally {
        if ($Reader) {$Reader.Close();$Reader.Dispose()}
        if ($Writer) {$Writer.Close();$Writer.Dispose()}
        if ($Stream) {$Stream.Close();$Stream.Dispose()}
        if ($Client) {$Client.Close();$Client.Dispose()}
    }

    $Response
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
    [ValidateSet("Stratum","EthProxy")]
    [string]$Method = "Stratum"
)    
    $Request = if ($Method -eq "EthProxy") {"{`"id`": 1, `"method`": `"login`", `"params`": {`"login`": `"$($User)`", `"pass`": `"$($Pass)`", `"rigid`": `"$($Worker)`", `"agent`": `"RainbowMiner/$($Session.Version)`"}}"} else {"{`"id`": 1, `"method`": `"mining.subscribe`", `"params`": [`"RainbowMiner/$($Session.Version)`"]}"}
    try {
        if ($WaitForResponse) {
            $Result = Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout
            if ($Result) {
                $Result = ConvertFrom-Json $Result -ErrorAction Stop
                if ($Result.id -eq 1 -and -not $Result.error) {$true}
            }
        } else {
            Invoke-TcpRequest -Server $Server -Port $Port -Request $Request -Timeout $Timeout -Quiet -WriteOnly > $null
            $true
        }
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
}