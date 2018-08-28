Function Start-APIServer {
    Param(
        [Parameter(Mandatory = $false)]
        [Switch]$RemoteAPI = $false
    )

    # Create a global synchronized hashtable that all threads can access to pass data between the main script and API
    $Global:API = [hashtable]::Synchronized(@{})
  
    # Setup flags for controlling script execution
    $API.Stop = $false
    $API.Pause = $false
    $API.Update = $false
    $API.RemoteAPI = $RemoteAPI

    # Starting the API for remote access requires that a reservation be set to give permission for non-admin users.
    # If switching back to local only, the reservation needs to be removed first.
    # Check the reservations before trying to create them to avoid unnecessary UAC prompts.
    $urlACLs = & netsh http show urlacl | Out-String

    if ($API.RemoteAPI -and (!$urlACLs.Contains('http://+:4000/'))) {
        # S-1-5-32-545 is the well known SID for the Users group. Use the SID because the name Users is localized for different languages
        Start-Process netsh -Verb runas -Wait -ArgumentList 'http add urlacl url=http://+:4000/ sddl=D:(A;;GX;;;S-1-5-32-545)'
    }
    if (!$API.RemoteAPI -and ($urlACLs.Contains('http://+:4000/'))) {
        Start-Process netsh -Verb runas -Wait -ArgumentList 'http delete urlacl url=http://+:4000/'
    }

    # Setup runspace to launch the API webserver in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("API", $API)
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) | Out-Null

    $API.Server = [PowerShell]::Create().AddScript({

        # Set the starting directory
        Set-Location (Split-Path $MyInvocation.MyCommand.Path)
        $BasePath = "$PWD\web"

        # List of possible mime types for files
        $MIMETypes = @{
            ".js" = "application/x-javascript"
            ".html" = "text/html"
            ".htm" = "text/html"
            ".json" = "application/json"
            ".css" = "text/css"
            ".txt" = "text/plain"
            ".ico" = "image/x-icon"
            ".png" = "image/png"
            ".jpg" = "image/jpeg"
            ".gif" = "image/gif"
            ".ps1" = "text/html" # ps1 files get executed, assume their response is html
        }

        # Setup the listener
        $Server = New-Object System.Net.HttpListener
        if ($API.RemoteAPI) {
            $Server.Prefixes.Add("http://+:4000/")
            # Require authentication when listening remotely
            $Server.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication
        } else {
            $Server.Prefixes.Add("http://localhost:4000/")
        }
        $Server.Start()

        While ($Server.IsListening -and -not $API.Stop) {
            $Context = $Server.GetContext()
            $Request = $Context.Request
            $URL = $Request.Url.OriginalString

            # Determine the requested resource and parse query strings
            $Path = $Request.Url.LocalPath

            # Parse any parameters in the URL - $Request.Url.Query looks like "+ ?a=b&c=d&message=Hello%20world"
            $Parameters = [PSCustomObject]@{}
            $Request.Url.Query -Replace "\?", "" -Split '&' | Foreach-Object {
                $key, $value = $_ -Split '='
                # Decode any url escaped characters in the key and value
                $key = [URI]::UnescapeDataString($key)
                $value = [URI]::UnescapeDataString($value)
                if ($key -and $value) {
                    $Parameters | Add-Member $key $value
                }
            }

            if($Request.HasEntityBody) {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $NewParameters = $Reader.ReadToEnd()
            }

            # Create a new response and the defaults for associated settings
            $Response = $Context.Response
            $ContentType = "application/json"
            $StatusCode = 200
            $Data = ""
            
            if($API.RemoteAPI -and (!$Request.IsAuthenticated)) {
                $Data = "Unauthorized"
                $StatusCode = 403
                $ContentType = "text/html"
            } else {
                # Set the proper content type, status code and data for each resource
                Switch($Path) {
                "/version" {
                    $Data = $API.Version | ConvertTo-Json
                    break
                }
                "/activeminers" {
                    $Data = ConvertTo-Json @($API.ActiveMiners | Where Profit | Select-Object)
                    break
                }
                "/runningminers" {
                    $Data = ConvertTo-Json @($API.RunningMiners | Select-Object)
                    Break
                }
                "/failedminers" {
                    $Data = ConvertTo-Json @($API.FailedMiners | Select-Object)
                    Break
                }
                "/minersneedingbenchmark" {
                    $Data = ConvertTo-Json @($API.MinersNeedingBenchmark | Select-Object)
                    Break
                }
                "/pools" {
                    $Data = ConvertTo-Json @($API.Pools.PSObject.Properties | Select-Object -ExpandProperty Value)
                    Break
                }
                "/newpools" {
                    $Data = ConvertTo-Json @($API.NewPools | Select-Object)
                    Break
                }
                "/allpools" {
                    $Data = ConvertTo-Json @($API.AllPools | Select-Object)
                    Break
                }
                "/algorithms" {
                    $Data = ConvertTo-Json @($API.AllPools.Algorithm | Sort-Object -Unique)
                    Break
                }
                "/miners" {
                    $Data = ConvertTo-Json @($API.Miners | Select-Object)
                    Break
                }
                "/fastestminers" {
                    $Data = ConvertTo-Json @($API.FastestMiners | Select-Object)
                    Break
                }
                "/config" {
                    $Data = $API.Config | ConvertTo-Json
                    Break
                }
                "/debug" {
                    $Data = $API | ConvertTo-Json
                    Break
                }
                "/alldevices" {
                    $Data = ConvertTo-Json @($API.AllDevices | Select-Object)
                    Break
                }
                "/devices" {
                    $Data = ConvertTo-Json @($API.Devices | Select-Object)
                    Break
                }
                "/devicecombos" {
                    $Data = ConvertTo-Json @($API.DeviceCombos | Select-Object)
                    Break
                }
                "/stats" {
                    $Data = ConvertTo-Json @($API.Stats | Select-Object)
                    Break
                }
                "/watchdogtimers" {
                    $Data = ConvertTo-Json @($API.WatchdogTimers | Select-Object)
                    Break
                }
                "/balances" {
                    $Data = ConvertTo-Json @($API.Balances | Select-Object)
                    Break
                }
                "/rates" {
                    $Data = ConvertTo-Json @($API.Rates | Select-Object)
                    Break
                }
                "/asyncloaderjobs" {
                    $Data = ConvertTo-Json @($AsyncLoader.Jobs | Select-Object)
                    Break
                }
                "/asyncloadererrors" {
                    $Data = ConvertTo-Json @($AsyncLoader.Errors | Select-Object)
                    Break
                }
                "/minerstats" {
                    [hashtable]$JsonUri_Dates = @{}
                    [hashtable]$Miners_List = @{}
                    [System.Collections.ArrayList]$Out = @()
                    $API.Miners | Select-Object BaseName,Name,Path,HashRates,DeviceModel | Foreach-Object {                                
                        
                        if (-not $JsonUri_Dates.ContainsKey($_.BaseName)) {
                            $JsonUri = (Split-Path $_.Path) + "\_uri.json"
                            $JsonUri_Dates[$_.BaseName] = if (Test-Path $JsonUri) {(Get-ChildItem $JsonUri).LastWriteTime.ToUniversalTime()} else {$null}
                        }
                        [String]$Algo = $_.HashRates.PSObject.Properties.Name | Select -First 1
                        [String]$SecondAlgo = ''
                        if (($_.HashRates.PSObject.Properties.Name | Measure-Object).Count -gt 1) {
                            $SecondAlgo = $_.HashRates.PSObject.Properties.Name | Select -Index 1
                        }
                            
                        $Miners_Key = "$($_.Name)_$($Algo -replace '\-.*$')"
                        if ($JsonUri_Dates[$_.BaseName] -ne $null -and -not $Miners_List.ContainsKey($Miners_Key)) {
                            $Miners_List[$Miners_Key] = $true                            
                            $Miner_Path = ".\Stats\$($Miners_Key)_HashRate.txt"
                            $Miner_Failed = @($_.HashRates.PSObject.Properties.Value) -contains 0
                            $Miner_NeedsBenchmark = (Test-Path $Miner_Path) -and (Get-ChildItem $Miner_Path).LastWriteTime.ToUniversalTime() -lt $JsonUri_Dates[$_.BaseName]
                            $Out.Add([PSCustomObject]@{
                                BaseName = $_.BaseName
                                Name = $_.Name
                                Algorithm = $Algo
                                SecondaryAlgorithm = $SecondAlgo                                
                                DeviceModel = $_.DeviceModel
                                Benchmarking = -not (Test-Path $Miner_Path)
                                NeedsBenchmark = $Miner_NeedsBenchmark
                                BenchmarkFailed = $Miner_Failed
                            }) | Out-Null
                        }
                    }
                    $Data = ConvertTo-Json @($Out)
                    Break
                }
                "/computerstats" {
                    $Data = $API.ComputerStats | ConvertTo-Json
                    Break
                }
                "/currentprofit" {
                    $Data = [PSCustomObject]@{ProfitBTC=($API.RunningMiners | Measure-Object -Sum -Property Profit).Sum;Rates=$API.Rates} | ConvertTo-Json
                    Break
                }
                "/stop" {
                    $API.Stop = $true
                    $Data = "Stopping"
                    Break
                }
                "/pause" {
                    $API.Pause = -not $API.Pause
                    $Data = $API.Pause | ConvertTo-Json
                    Break
                }
                "/update" {
                    $API.Update = $true
                    $Data = $API.Update | ConvertTo-Json
                    Break
                }
                "/status" {
                    $Data = [PSCustomObject]@{Pause=$API.Pause} | ConvertTo-Json
                    Break
                }
                default {
                    # Set index page
                    if ($Path -eq "/") {
                        $Path = "/index.html"
                    }

                    # Check if there is a file with the requested path
                    $Filename = $BasePath + $Path
                    if (Test-Path $Filename -PathType Leaf) {
                        # If the file is a powershell script, execute it and return the output. A $Parameters parameter is sent built from the query string
                        # Otherwise, just return the contents of the file
                        $File = Get-ChildItem $Filename

                        If ($File.Extension -eq ".ps1") {
                            $Data = & $File.FullName -Parameters $Parameters
                        } else {
                            $Data = Get-Content $Filename -Raw

                            # Process server side includes for html files
                            # Includes are in the traditional '<!-- #include file="/path/filename.html" -->' format used by many web servers
                            if($File.Extension -eq ".html") {
                                $IncludeRegex = [regex]'<!-- *#include *file="(.*)" *-->'
                                $IncludeRegex.Matches($Data) | Foreach-Object {
                                    $IncludeFile = $BasePath +'/' + $_.Groups[1].Value
                                    If (Test-Path $IncludeFile -PathType Leaf) {
                                        $IncludeData = Get-Content $IncludeFile -Raw
                                        $Data = $Data -Replace $_.Value, $IncludeData
                                    }
                                }
                            }
                        }

                        # Set content type based on file extension
                        If ($MIMETypes.ContainsKey($File.Extension)) {
                            $ContentType = $MIMETypes[$File.Extension]
                        } else {
                            # If it's an unrecognized file type, prompt for download
                            $ContentType = "application/octet-stream"
                        }
                    } else {
                        $StatusCode = 404
                        $ContentType = "text/html"
                        $Data = "URI '$Path' is not a valid resource."
                    }
                }
            }
            }

            # If $Data is null, the API will just return whatever data was in the previous request.  Instead, show an error
            # This happens if the script just started and hasn't filled all the properties in yet.
            If($Data -eq $Null) { 
                $Data = @{'Error' = "API data not available"} | ConvertTo-Json
            }

            # Send the response
            $Response.Headers.Add("Content-Type", $ContentType)
            $Response.StatusCode = $StatusCode
            $ResponseBuffer = [System.Text.Encoding]::UTF8.GetBytes($Data)
            $Response.ContentLength64 = $ResponseBuffer.Length
            $Response.OutputStream.Write($ResponseBuffer,0,$ResponseBuffer.Length)
            $Response.Close()

            $Error.Clear()
        }
        # Only gets here if something is wrong and the server couldn't start or stops listening
        $Server.Stop()
        $Server.Close()
    }) #end of $apiserver

    $API.Server.Runspace = $newRunspace
    $API.Handle = $API.Server.BeginInvoke()
}

Function Stop-APIServer {
    if ( -not $Global:API.Stop ) {
        try { $result = Invoke-WebRequest -Uri "http://localhost:4000/stop" } catch { Write-Host "Listener ended" }
    }
    $Global:API.Server.dispose()
}