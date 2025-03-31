#
# Invoke functions for web access
#

function Invoke-RestMethodAsync {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $True)]
        [string]$url,
    [Parameter(Mandatory = $False)]   
        [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]
        [int]$retry = 0,
    [Parameter(Mandatory = $False)]
        [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]
        [string]$tag = "",
    [Parameter(Mandatory = $False)]
        [int]$delay = 0,
    [Parameter(Mandatory = $False)]
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        [switch]$fixbigint,
    [Parameter(Mandatory = $False)]
        [switch]$nocache,
    [Parameter(Mandatory = $False)]
        [switch]$noquickstart,
    [Parameter(Mandatory = $False)]
        [string]$Jobkey = $null,
    [Parameter(Mandatory = $False)]
        $body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    Invoke-GetUrlAsync $url -method "REST" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body -headers $headers -fixbigint $fixbigint
}

function Invoke-WebRequestAsync {
[cmdletbinding()]   
Param(   
    [Parameter(Mandatory = $True)]
        [string]$url,
    [Parameter(Mandatory = $False)]
        [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]
        [int]$retry = 0,
    [Parameter(Mandatory = $False)]
        [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]
        [string]$Jobkey = $null,
    [Parameter(Mandatory = $False)]
        [string]$tag = "",
    [Parameter(Mandatory = $False)]
        [int]$delay = 0,
    [Parameter(Mandatory = $False)]
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        [switch]$fixbigint,
    [Parameter(Mandatory = $False)]
        [switch]$nocache,
    [Parameter(Mandatory = $False)]
        [switch]$noquickstart,
    [Parameter(Mandatory = $False)]
        $body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    Invoke-GetUrlAsync $url -method "WEB" -cycletime $cycletime -retry $retry -retrywait $retrywait -tag $tag -delay $delay -timeout $timeout -nocache $nocache -noquickstart $noquickstart -Jobkey $Jobkey -body $body -headers $headers -fixbigint $fixbigint
}

function Invoke-GetUrlAsync {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]   
        [string]$url = "",
    [Parameter(Mandatory = $False)]   
        [string]$method = "REST",
    [Parameter(Mandatory = $False)]   
        [switch]$force = $false,
    [Parameter(Mandatory = $False)]   
        [switch]$quiet = $false,
    [Parameter(Mandatory = $False)]   
        [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]
        [int]$retry = 0,
    [Parameter(Mandatory = $False)]
        [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]   
        [string]$Jobkey = $null,
    [Parameter(Mandatory = $False)]
        [string]$tag = "",
    [Parameter(Mandatory = $False)]
        [int]$delay = 0,
    [Parameter(Mandatory = $False)]
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        [bool]$fixbigint = $False,
    [Parameter(Mandatory = $False)]
        [bool]$nocache = $false,
    [Parameter(Mandatory = $False)]
        [bool]$noquickstart = $false,
    [Parameter(Mandatory = $False)]
        $body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers
)
    if (-not $url -and -not $Jobkey) {return}

    if (-not $Jobkey) {$Jobkey = Get-MD5Hash "$($url)$(Get-HashtableAsJson $body)$(Get-HashtableAsJson $headers)";$StaticJobKey = $false} else {$StaticJobKey = $true}

    $Job = $null
    $useAsyncLoader = Test-Path Variable:Global:Asyncloader

    if ($useAsyncLoader) {
        [void]$AsyncLoader.Jobs.TryGetValue($Jobkey, [ref]$Job)
    }

    $retry     = [Math]::Min([Math]::Max($retry,0),5)
    $retrywait = [Math]::Min([Math]::Max($retrywait,0),5000)
    $delay     = [Math]::Min([Math]::Max($delay,0),5000)

    if (-not $Job) {
        $JobHost = if ($url -notmatch "^server://") {try{([System.Uri]$url).Host}catch{}} else {"server"}
        $JobData = [PSCustomObject]@{Url=$url;Host=$JobHost;Error=$null;Running=$true;Paused=$false;Method=$method;Body=$body;Headers=$headers;Success=0;Fail=0;Prefail=0;LastRequest=(Get-Date).ToUniversalTime();LastCacheWrite=$null;LastFailRetry=$null;LastFailCount=0;CycleTime=$cycletime;Retry=$retry;RetryWait=$retrywait;Delay=$delay;Tag=$tag;Timeout=$timeout;FixBigInt=$fixbigint;Index=0}
    }

    if (-not $useAsyncLoader) {
        if ($delay) {Start-Sleep -Milliseconds $delay}
        Invoke-GetUrl -JobData $JobData -JobKey $JobKey -ForceLocal:$($JobHost -in @("localhost","127.0.0.1"))
        $JobData.LastCacheWrite = (Get-Date).ToUniversalTime()
        return
    }

    if ($StaticJobKey -and $url -and $Job -and ($Job.Url -ne $url -or (Get-HashtableAsJson $Job.Body) -ne (Get-HashtableAsJson $body) -or (Get-HashtableAsJson $Job.Headers) -ne (Get-HashtableAsJson $headers))) {$force = $true;$Job.Url = $url;$Job.Body = $body;$Job.Headers = $headers}

    if ($JobHost) {
        $HostDelay = $null
        if (($JobHost -eq "rbminer.net" -or $JobHost -eq "api.rbminer.net") -and -not $AsyncLoader.HostDelays.TryGetValue($JobHost, [ref]$HostDelay)) {
            [void]$AsyncLoader.HostDelays.TryAdd($JobHost, 200)
        }

        if ($AsyncLoader.HostDelays.TryGetValue($JobHost, [ref]$HostDelay) -and $delay -gt $HostDelay) {
            [void]$AsyncLoader.HostDelays.AddOrUpdate($JobHost, $delay, { param($key, $oldValue) $delay })
        }

        [void]$AsyncLoader.HostTags.AddOrUpdate($JobHost, @($tag), { param($key, $oldValue) 
            $result = @($oldValue)
            if ($result -notcontains $tag) { $result += $tag }
            return $result
        })
    }

    if (-not (Test-Path ".\Cache")) {New-Item "Cache" -ItemType "directory" -ErrorAction Ignore > $null}

    if ($force -or -not $Job -or $Job.Paused -or -not (Test-Path ".\Cache\$($Jobkey).asy")) {
        $Quickstart = $false
        if (-not $Job) {
            $Quickstart = -not $nocache -and -not $noquickstart -and $AsyncLoader.Quickstart -and (Test-Path ".\Cache\$($Jobkey).asy")
            $JobData.Index = $AsyncLoader.Jobs.Count + 1
            [void]$AsyncLoader.Jobs.TryAdd($Jobkey, $JobData)
            [void]$AsyncLoader.Jobs.TryGetValue($Jobkey, [ref]$Job)
        } else {
            $Job.Running = $true
            $Job.LastRequest=(Get-Date).ToUniversalTime()
            $Job.Paused=$false
        }

        $retry = $Job.Retry + 1

        $StopWatch = [System.Diagnostics.Stopwatch]::New()
        do {
            $Request = $RequestError = $null
            $StopWatch.Restart()
            try {                
                if ($Quickstart) {
                    if (-not ($Request = Get-ContentByStreamReader ".\Cache\$($Jobkey).asy")) {
                        if (Test-Path ".\Cache\$($Jobkey).asy") {
                            try {Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore} catch {}
                        }
                        $Quickstart = $false
                    }
                }
                if (-not $Quickstart) {
                    if ($delay -gt 0) {Start-Sleep -Milliseconds $delay}
                    $Request = Invoke-GetUrl -JobData $Job -JobKey $JobKey
                }
                if ($Request) {
                    $Job.Success++
                    $Job.Prefail=0
                } else {
                    $RequestError = "Empty request"
                }
            }
            catch {
                $RequestError = "$($_.Exception.Message)"
            } finally {
                if ($RequestError) {$RequestError = "Problem fetching $($Job.Url) using $($Job.Method): $($RequestError)"}
            }

            if (-not $Quickstart) {$Job.LastRequest=(Get-Date).ToUniversalTime()}

            $retry--
            if ($retry -gt 0) {
                if (-not $RequestError) {$retry = 0}
                else {
                    $RetryWait_Time = [Math]::Min($Job.RetryWait - $StopWatch.ElapsedMilliseconds,5000)
                    if ($RetryWait_Time -gt 50) {
                        Start-Sleep -Milliseconds $RetryWait_Time
                    }
                }
            }
        } until ($retry -le 0)

        $StopWatch.Stop()
        $StopWatch = $null

        if (-not $Quickstart -and -not $RequestError -and $Request) {
            if ($Job.Method -eq "REST") {
                try {
                    $Request = $Request | ConvertTo-Json -Compress -Depth 10 -ErrorAction Stop
                } catch {
                    $RequestError = "$($_.Exception.Message)"
                } finally {
                    if ($RequestError) {$RequestError = "JSON problem: $($RequestError)"}
                }
            }
        }

        $CacheWriteOk = $false

        if ($RequestError -or -not $Request) {
            $Job.Prefail++
            if ($Job.Prefail -gt 5) {$Job.Fail++;$Job.Prefail=0}            
        } elseif ($Quickstart) {
            $CacheWriteOk = $true
        } else {
            $retry = 3
            do {
                $RequestError = $null
                try {
                    Write-ToFile -FilePath ".\Cache\$($Jobkey).asy" -Message $Request -NoCR -ThrowError
                    $CacheWriteOk = $true
                } catch {
                    $RequestError = "$($_.Exception.Message)"                
                }
                $retry--
                if ($retry -gt 0) {
                    if (-not $RequestError) {$retry = 0}
                    else {
                        Start-Sleep -Milliseconds 500
                    }
                }
            } until ($retry -le 0)
        }

        if ($CacheWriteOk) {
            $Job.LastCacheWrite=(Get-Date).ToUniversalTime()
        }

        if (-not (Test-Path ".\Cache\$($Jobkey).asy")) {
            try {New-Item ".\Cache\$($Jobkey).asy" -ItemType File > $null} catch {}
        }

        $Job.Error = $RequestError
        $Job.Running = $false
    }
    if (-not $quiet) {
        if ($Job.Error -and $Job.Prefail -eq 0 -and -not (Test-Path ".\Cache\$($Jobkey).asy")) {throw $Job.Error}
        if (Test-Path ".\Cache\$($Jobkey).asy") {
            try {
                if ($Job.Method -eq "REST") {
                    if (Test-IsPS7) {
                        Get-ContentByStreamReader ".\Cache\$($Jobkey).asy" | ConvertFrom-Json -ErrorAction Stop
                    } else {
                        $Data = Get-ContentByStreamReader ".\Cache\$($Jobkey).asy" | ConvertFrom-Json -ErrorAction Stop
                        $Data
                    }
                } else {
                    Get-ContentByStreamReader ".\Cache\$($Jobkey).asy"
                }
            }
            catch {
                Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore
                throw "Job $Jobkey contains clutter."
            }
        }
    }
}

function Invoke-GetUrl {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]   
        [string]$url = "",
    [Parameter(Mandatory = $False)]   
        [string]$method = "REST",
    [Parameter(Mandatory = $False)]   
        [string]$requestmethod = "",
    [Parameter(Mandatory = $False)]
        [int]$timeout = 15,
    [Parameter(Mandatory = $False)]
        $body,
    [Parameter(Mandatory = $False)]
        [hashtable]$headers,
    [Parameter(Mandatory = $False)]
        [string]$user = "",
    [Parameter(Mandatory = $False)]
        [string]$password = "",
    [Parameter(Mandatory = $False)]
        [string]$useragent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36",
    [Parameter(Mandatory = $False)]
        [bool]$fixbigint = $false,
    [Parameter(Mandatory = $False)]
        $JobData,
    [Parameter(Mandatory = $False)]
        [string]$JobKey = "",
    [Parameter(Mandatory = $False)]
        [switch]$ForceLocal,
    [Parameter(Mandatory = $False)]
        [switch]$NoExtraHeaderData,
    [Parameter(Mandatory = $False)]
        [switch]$ForceHttpClient,
    [Parameter(Mandatory = $False)]
        [switch]$ForceIWR
)
    if ($JobKey -and $JobData) {
        if (-not $ForceLocal -and $JobData.url -notmatch "^server://") {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}
            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                $serverbody = @{
                    url       = $JobData.url
                    method    = $JobData.method
                    timeout   = $JobData.timeout
                    body      = $JobData.body | ConvertTo-Json -Depth 10 -Compress
                    headers   = $JobData.headers | ConvertTo-Json -Depth 10 -Compress
                    cycletime = $JobData.cycletime
                    retry     = $JobData.retry
                    retrywait = $JobData.retrywait
                    delay     = $JobData.delay
                    tag       = $JobData.tag
                    user      = $JobData.user
                    password  = $JobData.password
                    fixbigint = [bool]$JobData.fixbigint
                    jobkey    = $JobKey
                    machinename = $Session.MachineName
                    workername  = $Config.Workername
                    myip      = $Session.MyIP
                    port      = $Config.APIPort
                }
                #Write-ToFile -FilePath "Logs\geturl_$(Get-Date -Format "yyyy-MM-dd").txt" -Message "http://$($Config.ServerName):$($Config.ServerPort)/getjob $(ConvertTo-Json $serverbody)" -Append -Timestamp
                $Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getjob" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                #Write-ToFile -FilePath "Logs\geturl_$(Get-Date -Format "yyyy-MM-dd").txt" -Message ".. $(if ($Result.Status) {"ok!"} else {"failed"})" -Append -Timestamp
                if ($Result.Status) {return $Result.Content}
            }
        }

        $url      = $JobData.url
        $method   = $JobData.method
        $timeout  = $JobData.timeout
        $body     = $JobData.body
        $headers  = $JobData.headers
        $user     = $JobData.user
        $password = $JobData.password
        $fixbigint= [bool]$JobData.fixbigint
    }

    if ($url -match "^server://(.+)$") {
        $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}
        if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
            $url           = "http://$($Config.ServerName):$($Config.ServerPort)/$($Matches[1])"
            $user          = $Config.ServerUser
            $password      = $Config.ServerPassword
        } else {
            return
        }
    }

    if (-not $requestmethod) {$requestmethod = if ($body) {"POST"} else {"GET"}}

    $Replacements = @("{timestamp}", "{unixtimestamp}", "{unixtimestamp_ms}", "{iso8601timestamp}")
    $Values = @(
        (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"),
        (Get-UnixTimestamp),
        (Get-UnixTimestamp -Milliseconds),
        ((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK"))
    )
    $RequestUrl = [RBMToolBox]::ReplaceMulti($url, $Replacements, $Values)

    $headers_local = @{}
    if ($headers) {$headers.Keys | Foreach-Object {$headers_local[$_] = $headers[$_]}}
    if (-not $NoExtraHeaderData) {
        if ($method -eq "REST" -and -not $headers_local.ContainsKey("Accept")) {$headers_local["Accept"] = "application/json"}
        if (-not $headers_local.ContainsKey("Cache-Control")) {$headers_local["Cache-Control"] = "no-cache"}
    }
    if ($user) {$headers_local["Authorization"] = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($user):$($password)")))"}

    $ErrorMessage = ''

    if (-not $ForceHttpClient -and -not $forceIWR -and $Session.EnableCurl) {

        $TmpFile = $null

        $Proxy = Get-Proxy

        try {
            $CurlHeaders = [RBMToolBox]::Join(" ", @(
                foreach ($header in $headers_local.GetEnumerator() | Sort-Object Name) {
                    "-H `"$($header.Name): $($header.Value)`""
                }
            ))

            $CurlBody = ""

            if ([RBMToolBox]::IndexOf($RequestUrl,'?') -gt 0) {
                ($RequestUrl, $body) = [RBMToolBox]::Split($RequestUrl,'?',2)
            }

            if ($body -and ($body -isnot [hashtable] -or $body.Count)) {
                if ($body -is [hashtable]) {
                    $out = [ordered]@{}
                    $requiresFile = $false
                    foreach ($entry in $body.GetEnumerator() | Sort-Object Name) {
                        if ($entry.Value -is [object] -and $entry.Value.FullName) {
                            $out[$entry.Name] = "@$($entry.Value.FullName)"
                            $requiresFile = $true
                        } else {
                            $out[$entry.Name] = [RBMToolBox]::Replace($entry.Value, '"', '\"')
                        }
                    }

                    if ($requiresFile) {
                        $outcmd = if ($requestmethod -eq "GET") { "-d" } else { "-F" }
                        $CurlBody = [RBMToolBox]::Join(" ", @(
                            foreach ($entry in $out.GetEnumerator()) {
                                "$outcmd `"$($entry.Name)=$($entry.Value)`""
                            }
                        )) + " "
                    } else {
                        $body = [RBMToolBox]::Join("&", @(
                            foreach ($entry in $body.GetEnumerator() | Sort-Object Name) {
                                "$($entry.Name)=$([System.Web.HttpUtility]::UrlEncode($entry.Value))"
                            }
                        ))
                    }
                }

                if ($body -isnot [hashtable]) {
                    if (($body.Length + [RBMToolBox]::CountChar($body,'"')) -gt 30000) {
                        $TmpFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString() + ".txt")
                        Set-Content -Value $body -Path $TmpFile
                        $body = "@$TmpFile"
                    }
                    $CurlBody = "-d `"$([RBMToolBox]::Replace($body, '"', '\"'))`" "
                }
            }

            if ($useragent -ne "") {
                $useragent = "-A `"$useragent`" "
            }

            $curlproxy = ""
            if ($Proxy.Proxy) {
                $curlproxy = "-x `"$Proxy.Proxy`" "
                if ($Proxy.Username -and $Proxy.Password) {
                    $curlproxy += "-U `"$($Proxy.Username):$($Proxy.Password)`" "
                }
            }

            $CurlCommand = "$(if ($requestmethod -ne 'GET') {"-X $requestmethod"} else {"-G"}) `"$RequestUrl`" $CurlBody$CurlHeaders $useragent$curlproxy-m $($timeout+5)$(if (-not $NoExtraHeaderData) {" --compressed"}) --connect-timeout $timeout --ssl-allow-beast --ssl-no-revoke --max-redirs 5 -k -s -L -q -w `"#~#%{response_code}`""

            $Data = [RBMToolBox]::Split((Invoke-Exe $Session.Curl -ArgumentList $CurlCommand -WaitForExit $Timeout),"#~#")

            if ($Session.LogLevel -eq "Debug") {
                Write-Log "CURL[$($Global:LASTEXEEXITCODE)][$($Data[-1])] $($CurlCommand)"
            }

            if ($Data -and $Data.Count -gt 1 -and $Global:LASTEXEEXITCODE -eq 0 -and $Data[-1] -match "^2\d\d") {
                $Data = if ($Data.Count -eq 2) {$Data[0]} else {$Data[0..($Data.Count-2)] -join '#~#'}
                if ($method -eq "REST") {
                    if ($fixbigint) {
                        try {
                            $Data = ([regex]"(?si):\s*(\d{19,})[`r`n,\s\]\}]").Replace($Data,{param($m) $m.Groups[0].Value -replace $m.Groups[1].Value,"$([double]$m.Groups[1].Value)"})
                        } catch {}
                    }
                    try {$Data = ConvertFrom-Json $Data -ErrorAction Stop} catch { $method = "WEB"}
                }
                if ($Data -and $Data.unlocked -ne $null) {[void]$Data.PSObject.Properties.Remove("unlocked")}
            } else {
                $ErrorMessage = "cURL $($Global:LASTEXEEXITCODE) / $(if ($Data -and $Data.Count -gt 1){"HTTP $($Data[-1])"} else {"Timeout after $($timeout)s"})"
            }
        } catch {
            $ErrorMessage = "$($_.Exception.Message)"
        } finally {
            if ($TmpFile -and (Test-Path $TmpFile)) {
                Remove-Item $TmpFile -Force -ErrorAction Ignore
            }
        }
    
    } else {

        if (-not $NoExtraHeaderData) {
            if (-not $headers_local.ContainsKey("Accept-Encoding")) {$headers_local["Accept-Encoding"] = "gzip"}
        }

        $IsForm = $false

        try {
            if ($body -and ($body -isnot [hashtable] -or $body.Count)) {
                if ($body -is [hashtable]) {
                    $IsForm = ($body.GetEnumerator() | Where-Object {$_.Value -is [object] -and $_.Value.FullName} | Measure-Object).Count -gt 0
                } elseif ($requestmethod -eq "GET") {
                    $RequestUrl = "$($RequestUrl)$(if ($RequestUrl.IndexOf('?') -gt 0) {'&'} else {'?'})$body"
                    $body = $null
                }
            }
        } catch {
        }

        $StatusCode = $null
        $Data       = $null

        $Result = [PSCustomObject]@{
            Status       = $false
            StatusCode   = $null
            Data         = $null
            ErrorMessage = ""
        }

        if (-not $forceIWR -and (Initialize-HttpClient)) {

            if ($Session.LogLevel -eq "Debug") {
                Write-Log "Using HttpClient to $($method)-$($requestmethod) $($requesturl)"
            }

            try {
                $Response = $null

                if ($IsForm) {
                    $fs_array = [System.Collections.Generic.List[System.IO.FileStream]]::new()
                }

                $content = [System.Net.Http.HttpRequestMessage]::new()

                $content.Method = $requestmethod
                $content.RequestUri = $requesturl
                $headers_local.GetEnumerator() | Foreach-Object {
                    if ($_.Key -ne "Content-Type") {
                        [void]$content.Headers.Add($_.Key, $_.Value)
                    }
                }
                [void]$content.Headers.Add('User-Agent', $userAgent)

                if ($body) {
                    if ($body -is [hashtable]) {
                        if ($Session.LogLevel -eq "Debug") {$fx = @{}}
                        if ($IsForm) {
                            $content.Content = [System.Net.Http.MultipartFormDataContent]::New()
                            $body.GetEnumerator() | Foreach-Object {
                                if ($_.Value -is [object] -and $_.Value.FullName) {
                                    $fs = [System.IO.FileStream]::New($_.Value, [System.IO.FileMode]::Open)
                                    [void]$fs_array.Add($fs)
                                    [void]$content.Content.Add([System.Net.Http.StreamContent]::New($fs),$_.Name,(Split-Path $_.Value -Leaf))
                                    if ($Session.LogLevel -eq "Debug") {$fx[$_.Name] = "@$($_.Value.FullName)"}
                                } else {
                                    [void]$content.Content.Add([System.Net.Http.StringContent]::New($_.Value),$_.Name)
                                    if ($Session.LogLevel -eq "Debug") {$fx[$_.Name] = $_.Value}
                                }
                            }
                        } else {
                            $body_local = [System.Collections.Generic.Dictionary[string,string]]::New()
                            $body.GetEnumerator() | Foreach-Object {
                                [void]$body_local.Add([string]$_.Name,[string]$_.Value)
                                if ($Session.LogLevel -eq "Debug") {$fx[$_.Name] = $_.Value}
                            }
                            $content.Content = [System.Net.Http.FormUrlEncodedContent]::new($body_local)
                            $body_local = $null
                        }

                        if ($Session.LogLevel -eq "Debug") {
                            Write-Log "--> $(if ($IsForm) {"FORM"} else {"BODY"}): $(ConvertTo-Json $fx -Depth 10)"
                        }
                    } else {
                        if ($Session.LogLevel -eq "Debug") {
                            Write-Log "--> PLAIN: $($body)"
                        }

                        $contentType = if ($headers_local.ContainsKey("Content-Type")) {
                            $headers_local["Content-Type"]
                        } elseif ($body.TrimStart().StartsWith("{")) {
                            try {
                                [void](ConvertFrom-Json $body -ErrorAction Stop)
                                "application/json"
                            } catch {
                                "text/plain"
                            }
                        } else {
                            "text/plain"
                        }

                        $content.Content = [System.Net.Http.StringContent]::new($body,[System.Text.Encoding]::UTF8,$contentType)
                    }
                }

                $cts = [System.Threading.CancellationTokenSource]::new()

                $task = $Global:GlobalHttpClient.SendAsync($content,$cts.Token)

                if ($task.IsFaulted -or $task.IsCanceled) {

                    $Result.StatusCode = 504
                    $Result.ErrorMessage = "Call to $($RequestUrl) failed: $(if ($task.IsCanceled -and -not $task.Exception.Message) {"canceled"} else {$task.Exception.Message})$(if ($task.Exception.InnerException) {" --> $($task.Exception.InnerException.Message)"})"

                } elseif ($task.Wait($timeout*1000)) {

                    if ($Session.LogLevel -eq "Debug") {
                        Write-Log "--> Result: $($task.Result.StatusCode) IsFaulted=$($task.Result.isFaulted) Status=$($task.Status)"
                    }

                    $Result.Status = -not $task.Result.isFaulted -and $task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion

                    if ($task.Result) {

                        $Result.StatusCode = [int]$task.Result.StatusCode

                        if (-not $Result.Status) {
                            $Result.ErrorMessage =  "$($task.Result.Exception.Message)$(if ($task.Result.Exception.InnerException) {" --> $($task.Result.Exception.InnerException.Message)"})"
                        }

                        $Response = $task.Result.Content.ReadAsStringAsync().Result

                    } elseif ($task.IsCanceled) {
                        $Result.StatusCode = 504
                    }

                    if ($Result.StatusCode -match "^2\d\d$") {
                        $Result.Data = if ($Response -is [byte[]]) {[System.Text.Encoding]::UTF8.GetString($Response)} else {$Response}
                        if ($method -eq "REST") {
                            if ($fixbigint) {
                                try {
                                    $Result.Data = ([regex]"(?si):\s*(\d{19,})[`r`n,\s\]\}]").Replace($Result.Data,{param($m) $m.Groups[0].Value -replace $m.Groups[1].Value,"$([double]$m.Groups[1].Value)"})
                                } catch {}
                            }
                            try {$Result.Data = ConvertFrom-Json $Result.Data -ErrorAction Stop} catch {}
                        }
                        if ($Result.Data -and $Result.Data.unlocked -ne $null) {[void]$Result.Data.PSObject.Properties.Remove("unlocked")}
                    }

                } else {
                    $cts.Cancel()
                    $Result.StatusCode = 444
                    $Result.ErrorMessage = "Call to $($RequestUrl) timed out after $($timeout) secs"
                }
            } catch {
                $Result.ErrorMessage = "$($_.Exception.Message)$(if ($_.Exception.InnerException) {" --> $($_.Exception.InnerException.Message)"})"
            } finally {
                if($task -ne $null) {
                    if (-not $task.IsCompleted -and $cts) {
                        $cts.Cancel()
                        $retry = 10
                        while (-not $task.IsCompleted -and $retry -gt 0) {
                            Start-Sleep -Milliseconds 100
                            $retry--
                        }
                    }
                    if ($task.Status -in @([System.Threading.Tasks.TaskStatus]::RanToCompletion,[System.Threading.Tasks.TaskStatus]::Canceled,[System.Threading.Tasks.TaskStatus]::Faulted)) {
                        if ($task.Result -ne $null) {$task.Result.Dispose()}
                        $task.Dispose()
                    }
                    $task = $null
                }
                if ($cts -ne $null) {
                    $cts.Dispose()
                    $cts = $null
                }
                if ($fs_array.Count) {
                    foreach($fs in $fs_array) {
                        $fs.Close()
                        $fs.Dispose()
                    }
                    $fs_array = $null
                }
                if ($content -ne $null) {
                    if ($content.Content -ne $null) {
                        $content.Content.Dispose()
                        $content.Content = $null
                    }
                    $content.Dispose()
                    $content = $null
                }
                if ($Response -ne $null) {
                    $Response = $null
                }
            }
            
        } else {

            $oldProgressPreference = $null
            if ($Global:ProgressPreference -ne "SilentlyContinue") {
                $oldProgressPreference = $Global:ProgressPreference
                $Global:ProgressPreference = "SilentlyContinue"
            }

            if ($Session.LogLevel -eq "Debug") {
                Write-Log "Using IWR to $($method)-$($requestmethod) $($requesturl)"
            }
            
            $Proxy = Get-Proxy

            if (Test-IsCore) {
                try {
                    $Response   = $null
                    if (Test-IsPS7) {
                        if ($IsForm) {
                            $Response = Invoke-WebRequest $RequestUrl -SkipHttpErrorCheck -SkipCertificateCheck -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Form $body -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials
                        } else {
                            $Response = Invoke-WebRequest $RequestUrl -SkipHttpErrorCheck -SkipCertificateCheck -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials
                        }
                    } else {
                        if ($IsForm) {
                            $Response = Invoke-WebRequest $RequestUrl -SkipCertificateCheck -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Form $body -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials
                        } else {
                            $Response = Invoke-WebRequest $RequestUrl -SkipCertificateCheck -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials
                        }
                    }

                    $Result.Status     = $true
                    $Result.StatusCode = $Response.StatusCode

                    if ($Result.StatusCode -match "^2\d\d$") {
                        $Result.Data = if ($Response.Content -is [byte[]]) {[System.Text.Encoding]::UTF8.GetString($Response.Content)} else {$Response.Content}
                        if ($method -eq "REST") {
                            if ($fixbigint) {
                                try {
                                    $Result.Data = ([regex]"(?si):\s*(\d{19,})[`r`n,\s\]\}]").Replace($Result.Data,{param($m) $m.Groups[0].Value -replace $m.Groups[1].Value,"$([double]$m.Groups[1].Value)"})
                                } catch {}
                            }
                            try {$Result.Data = ConvertFrom-Json $Result.Data -ErrorAction Stop} catch {}
                        }
                        if ($Result.Data -and $Result.Data.unlocked -ne $null) {[void]$Result.Data.PSObject.Properties.Remove("unlocked")}
                    }

                    if ($Response) {
                        $Response = $null
                    }
                } catch {
                    $Result.ErrorMessage = "$($_.Exception.Message)"
                }
            } else {
                try {
                    $ServicePoint = $null
                    if ($method -eq "REST") {
                        $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($RequestUrl)
                        $Result.Data = Invoke-RestMethod $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials
                    } else {
                        $Result.Data = (Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials).Content
                    }
                    if ($Result.Data -and $Result.Data.unlocked -ne $null) {[void]$Result.Data.PSObject.Properties.Remove("unlocked")}
                    $Result.Status = $true
                } catch {
                    $Result.ErrorMessage = "$($_.Exception.Message)"
                } finally {
                    if ($ServicePoint) {$ServicePoint.CloseConnectionGroup("") > $null}
                    $ServicePoint = $null
                }
            }
            if ($oldProgressPreference) {$Global:ProgressPreference = $oldProgressPreference}
        }

        if ($Result.Status -ne $null) {
            $StatusCode   = $Result.StatusCode
            $Data         = $Result.Data
            $ErrorMessage = $Result.ErrorMessage

            if ((Test-IsCore) -or $StatusCode -match "^\d\d\d$") {
                if ($ErrorMessage -eq '' -and $StatusCode -ne 200) {
                    if ($StatusCodeObject = Get-HttpStatusCode $StatusCode) {
                        if ($StatusCodeObject.Type -ne "Success") {
                            $ErrorMessage = "$($StatusCode) $($StatusCodeObject.Description) ($($StatusCodeObject.Type))"
                        }
                    } else {
                        $ErrorMessage = "$StatusCode Very bad! Code not found :("
                    }
                }
            }
        } else {
            $ErrorMessage = "Could not receive data from $($RequestUrl)"
        }
        $Result = $null
    }

    if ($ErrorMessage -eq '') {$Data}
    if ($ErrorMessage -ne '') {throw $ErrorMessage}
}

#
# Downloader helper
#

function Expand-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $false)]
        [String]$Path = "",
        [Parameter(Mandatory = $false)]
        [String[]]$ProtectedFiles = @(),
        [Parameter(Mandatory = $false)]
        [String]$Sha256 = "",
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "-qb",
        [Parameter(Mandatory = $false)]
        [Switch]$EnableMinerBackups = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableKeepDownloads = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$IsMiner = $false
    )

    # Set current path used by .net methods to the same as the script's path
    [Environment]::CurrentDirectory = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation

    if (-not $Path) {$Path = Join-Path ".\Downloads" ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName}
    if (-not (Test-Path ".\Downloads"))  {New-Item "Downloads" -ItemType "directory" > $null}
    if (-not (Test-Path ".\Bin"))        {New-Item "Bin" -ItemType "directory" > $null}
    if (-not (Test-Path ".\Bin\Common")) {New-Item "Bin\Common" -ItemType "directory" > $null}

    $FileName = Join-Path ".\Downloads" (Split-Path $Uri -Leaf)

    $Proxy = Get-Proxy

    if (Test-Path $FileName) {Remove-Item $FileName}
    $oldProgressPreference = $Global:ProgressPreference
    $Global:ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing -Proxy $Proxy.Proxy -ProxyCredential $Proxy.Credentials
    $Global:ProgressPreference = $oldProgressPreference

    if ($Sha256 -and (Test-Path $FileName)) {if ($Sha256 -ne (Get-FileHash $FileName -Algorithm SHA256).Hash) {Remove-Item $FileName; throw "Downloadfile $FileName has wrong hash! Please open an issue at github.com."}}

    if (".msi", ".exe" -contains ([IO.FileInfo](Split-Path $Uri -Leaf)).Extension) {
        $Run_Process = Start-Process $FileName $ArgumentList -PassThru
        $Run_Process.WaitForExit()>$null
    }
    else {
        $Path_Old = (Join-Path (Split-Path $Path) ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName)
        $Path_New = (Join-Path (Split-Path $Path) (Split-Path $Path -Leaf))
        $Path_Bak = (Join-Path (Split-Path $Path) "$(Split-Path $Path -Leaf).$(Get-Date -Format "yyyyMMdd_HHmmss")")

        if (Test-Path $Path_Old) {Remove-Item $Path_Old -Recurse -Force}

        $FromFullPath = [IO.Path]::GetFullPath($FileName)
        $ToFullPath   = [IO.Path]::GetFullPath($Path_Old)
        if ($IsLinux) {
            if (-not (Test-Path $ToFullPath)) {New-Item $ToFullPath -ItemType "directory" > $null}
            if (($FileName -split '\.')[-2] -eq 'tar') {
                $Params = @{
                    FilePath     = "tar"
                    ArgumentList = "-xa -f $FromFullPath -C $ToFullPath"
                }
            } elseif (($FileName -split '\.')[-1] -in @('tgz')) {
                $Params = @{
                    FilePath     = "tar"
                    ArgumentList = "-xz -f $FromFullPath -C $ToFullPath"
                }
            } else {
                $Params = @{
                    FilePath     = $Global:7zip
                    ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y"
                    RedirectStandardOutput = Join-Path ".\Logs" "7z-console.log"
                    RedirectStandardError  = Join-Path ".\Logs" "7z-error.log"
                }
            }
        } else {
            $Params = @{
                FilePath     = $Global:7zip
                ArgumentList = "x `"$FromFullPath`" -o`"$ToFullPath`" -y -spe"
                WindowStyle  = "Hidden"
            }
        }

        $Params.PassThru = $true
        $Extract_Process = Start-Process @Params
        $Extract_Process.WaitForExit()>$null

        if ($IsMiner) {
            if (Test-Path $Path_Bak) {Remove-Item $Path_Bak -Recurse -Force}
            if (Test-Path $Path_New) {Rename-Item $Path_New (Split-Path $Path_Bak -Leaf) -Force}

            if (Get-ChildItem $Path_Old -File) {
                Rename-Item $Path_Old (Split-Path $Path -Leaf)
            }
            else {
                Get-ChildItem $Path_Old -Directory | ForEach-Object {Move-Item (Join-Path $Path_Old $_.Name) $Path_New}
                Remove-Item $Path_Old -Recurse -Force
            }

            if (Test-Path $Path_Bak) {
                $ProtectedFiles | Foreach-Object {
                    $CheckForFile_Path = Split-Path $_
                    $CheckForFile_Name = Split-Path $_ -Leaf
                    Get-ChildItem (Join-Path $Path_Bak $_) -ErrorAction Ignore -File | Where-Object {[IO.Path]::GetExtension($_) -notmatch "(dll|exe|bin)$"} | Foreach-Object {
                        if ($CheckForFile_Path) {
                            $CopyToPath = Join-Path $Path_New $CheckForFile_Path
                            if (-not (Test-Path $CopyToPath)) {
                                New-Item $CopyToPath -ItemType Directory -ErrorAction Ignore > $null
                            }
                        } else {
                            $CopyToPath = $Path_New
                        }
                        if ($_.Length -lt 10MB) {
                            Copy-Item $_ $CopyToPath -Force
                        } else {
                            Move-Item $_ $CopyToPath -Force
                        }
                    }
                }
                $Rm_Paths = @("DAGs")
                $Rm_Paths | Foreach-Object {
                    $Rm_Path = Join-Path $Path_Bak $_
                    if (Test-Path $Rm_Path) {
                        try {
                            Get-ChildItem $Rm_Path -File | Foreach-Object {
                                Remove-Item $_.FullName -Force
                            }
                        } catch {
                            Write-Log -Level Warn "Downloader: Could not remove from backup path $_. Please do this manually, root might be needed ($($_.Exception.Message))"
                        }
                    }
                }
                $SkipBackups = if ($EnableMinerBackups) {3} else {0}
                Get-ChildItem (Join-Path (Split-Path $Path) "$(Split-Path $Path -Leaf).*") -Directory | Sort-Object Name -Descending | Select-Object -Skip $SkipBackups | Foreach-Object {
                    try {
                        Remove-Item $_ -Recurse -Force
                    } catch {
                        Write-Log -Level Warn "Downloader: Could not to remove backup path $_. Please do this manually, root might be needed ($($_.Exception.Message))"
                    }
                }
            }
        } else {
            if (Test-Path $Path_Old) {
                Get-ChildItem $Path_Old | ForEach-Object {Move-Item $_.FullName $Path_New -Force}
                Remove-Item $Path_Old -Recurse -Force
            }
        }
    }
    if (-not $EnableKeepDownloads -and (Test-Path $FileName)) {
        Get-ChildItem $FileName -File | Foreach-Object {Remove-Item $_}
    }
}

#
# Pool specific web requests
#

function Invoke-BinanceRequest {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $False)]
    [String]$key,
    [Parameter(Mandatory = $False)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    $params = @{},
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://api.binance.com",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0,
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal
)

    $keystr = Get-MD5Hash "$($endpoint)$(Get-HashtableAsJson $params)"
    if (-not (Test-Path Variable:Global:BinanceCache)) {$Global:BinanceCache = [hashtable]@{}}
    if (-not $Cache -or -not $Global:BinanceCache[$keystr] -or -not $Global:BinanceCache[$keystr].request -or $Global:BinanceCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

        $Remote = $false

        if (-not $ForceLocal) {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                $serverbody = @{
                    endpoint  = $endpoint
                    key       = $key
                    secret    = $secret
                    params    = $params | ConvertTo-Json -Depth 10 -Compress
                    method    = $method
                    base      = $base
                    timeout   = $timeout
                    machinename = $Session.MachineName
                    workername  = $Config.Workername
                    myip      = $Session.MyIP
                    port      = $Config.APIPort
                }
                try {
                    $Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getbinance" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                    if ($Result.Status) {$Request = $Result.Content;$Remote = $true}
                } catch {
                    Write-Log "Binance server call: $($_.Exception.Message)"
                }
            }
        }

        if (-not $Remote -and $key -and $secret) {
            $timestamp = 0
            try {$timestamp = (Invoke-GetUrl "$($base)/api/v3/time" -timeout 3).serverTime} catch {}
            if (-not $timestamp) {$timestamp = Get-UnixTimestamp -Milliseconds}

            $params["timestamp"] = $timestamp
            $paramstr = "$(($params.Keys | Sort-Object | Foreach-Object {"$($_)=$([System.Web.HttpUtility]::UrlEncode($params.$_))"}) -join '&')"

            $headers = [hashtable]@{
                'X-MBX-APIKEY'  = $key
            }
            try {
                $Request = Invoke-GetUrl "$base$endpoint" -timeout $Timeout -headers $headers -requestmethod $method -body "$($paramstr)&signature=$(Get-HMACSignature $paramstr $secret)"
            } catch {
                "Binance API call: $($_.Exception.Message)"
                Write-Log "Binance API call: $($_.Exception.Message)"
            }
        }

        if (-not $Global:BinanceCache[$keystr] -or $Request) {
            $Global:BinanceCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request}
        }
    }
    $Global:BinanceCache[$keystr].request
}

function Invoke-NHRequest {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $False)]
    [String]$key,
    [Parameter(Mandatory = $False)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    [String]$organizationid,
    [Parameter(Mandatory = $False)]
    $params = @{},
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://api2.nicehash.com",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0,
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal
)
    #autofix key/secret/organizationid
    if ($key) {$key = Get-ReadableHex32 $key}
    if ($secret) {$secret = Get-ReadableHex32 $secret}
    if ($organizationid) {$organizationid = Get-ReadableHex32 $organizationid}

    $keystr = Get-MD5Hash "$($endpoint)$(Get-HashtableAsJson $params)"
    if (-not (Test-Path Variable:Global:NHCache)) {$Global:NHCache = [hashtable]@{}}
    if (-not $Cache -or -not $Global:NHCache[$keystr] -or -not $Global:NHCache[$keystr].request -or $Global:NHCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

        $Remote = $false

        if (-not $ForceLocal) {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                $serverbody = @{
                    endpoint  = $endpoint
                    key       = $key
                    secret    = $secret
                    orgid     = $organizationid
                    params    = $params | ConvertTo-Json -Depth 10 -Compress
                    method    = $method
                    base      = $base
                    timeout   = $timeout
                    machinename = $Session.MachineName
                    workername  = $Config.Workername
                    myip      = $Session.MyIP
                    port      = $Config.APIPort
                }
                try {
                    $Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getnh" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                    if ($Result.Status) {$Request = $Result.Content;$Remote = $true}
                } catch {
                    Write-Log "Nicehash server call: $($_.Exception.Message)"
                }
            }
        }

        if (-not $Remote -and $key -and $secret -and $organizationid) {
            $uuid = [string]([guid]::NewGuid())
            $timestamp = 0
            try {$timestamp = (Invoke-GetUrl "$($base)/api/v2/time" -timeout 3).serverTime} catch {}
            if (-not $timestamp) {$timestamp = Get-UnixTimestamp -Milliseconds}

            $paramstr = "$(($params.Keys | Foreach-Object {"$($_)=$([System.Web.HttpUtility]::UrlEncode($params.$_))"}) -join '&')"
            $str = "$key`0$timestamp`0$uuid`0`0$organizationid`0`0$($method.ToUpper())`0$endpoint`0$(if ($method -eq "GET") {$paramstr} else {"`0$($params | ConvertTo-Json -Depth 10 -Compress)"})"

            $headers = [hashtable]@{
                'X-Time'            = $timestamp
                'X-Nonce'           = $uuid
                'X-Organization-Id' = $organizationid
                'X-Auth'            = "$($key):$(Get-HMACSignature $str $secret)"
                'Cache-Control'     = 'no-cache'
            }
            try {
                $body = Switch($method) {
                    "GET" {if ($params.Count) {$params} else {$null};Break}
                    default {$params | ConvertTo-Json -Depth 10}
                }

                $Request = Invoke-GetUrl "$base$endpoint" -timeout $Timeout -headers $headers -requestmethod $method -body $body
            } catch {
                Write-Log "Nicehash API call: $($_.Exception.Message)"
            }
        }

        if (-not $Global:NHCache[$keystr] -or $Request) {
            $Global:NHCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request}
        }
    }
    $Global:NHCache[$keystr].request
}

#
# Web tools and database functions
#

function Get-Proxy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false
    )

    if ($Force -or -not (Test-Path Variable:Global:GlobalProxy)) {

        $Proxy = [PSCustomObject]@{
            Proxy       = $null
            Username    = $null
            Password    = $null
            Uri         = $null
            Credentials = $null
        }

        if (Test-Path ".\Data\proxy.json") {
            try {
                $CurrentProxy = Get-ContentByStreamReader ".\Data\proxy.json" | ConvertFrom-Json -ErrorAction Stop
            } catch {
            }

            if ($CurrentProxy.Proxy) {
                $Proxy.Proxy = $CurrentProxy.Proxy
                $Proxy.Uri   = [Uri]$Proxy.Proxy
            
                if ($Proxy.Uri.UserInfo) {
                    $Proxy.Username = $Proxy.Uri.UserInfo -replace ":.+$"
                    $Proxy.Password = $Proxy.Uri.UserInfo -replace "^.+:"
                } else {
                    $Proxy.Username = $CurrentProxy.Username
                    $Proxy.Password = $CurrentProxy.Password
                }
                if ($Proxy.Username -and $Proxy.Password) {
                    $pass = ConvertTo-SecureString "$($Proxy.Password)" -AsPlainText -Force
                    $Proxy.Credentials = [System.Management.Automation.PSCredential]::new($Proxy.Username, $pass)
                }
            }
        }

        $Global:GlobalProxy = $Proxy
    }
    if (-not $silent) {$Global:GlobalProxy}
}

function Set-Proxy {
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [String]$Proxy = "",
    [Parameter(Mandatory = $false)]
    [String]$Username = "",
    [Parameter(Mandatory = $false)]
    [String]$Password = ""
)

    $ProxyRecord = [PSCustomObject]@{
        Proxy    = $Proxy
        Username = $Username
        Password = $Password
    }

    try {
        $CurrentProxy = Get-ContentByStreamReader ".\Data\proxy.json" | ConvertFrom-Json -ErrorAction Stop
    } catch {
    }
    if (-not $CurrentProxy -or $CurrentProxy.Proxy -ne $ProxyRecord.Proxy -or $CurrentProxy.ProxyUsername -ne $ProxyRecord.ProxyUsername -or $CurrentProxy.Password -ne $ProxyRecord.Password) {
        Set-ContentJson -PathToFile ".\Data\proxy.json" -Data $ProxyRecord > $null
        $true
    } else {
        $false
    }
    Get-Proxy -Force -Silent
}

function Initialize-HttpClient {
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Switch]$Restart
)
    if ($Restart) {
        if ($Global:GlobalHttpClient) {
            $Global:GlobalHttpClient.Dispose()
        }
        $Global:GlobalHttpClient = $null
    }

    if ($Global:GlobalHttpClient -eq $null) {
        try {
            Add-Type -AssemblyName System.Net.Http -ErrorAction Stop

            $WebProxy = $null

            if (($Proxy = Get-Proxy).Proxy) {
                $WebProxy    = [System.Net.WebProxy]::New($Proxy.Proxy)
                $WebProxy.BypassProxyOnLocal = $true
                if ($Proxy.Credentials) {
                    $WebProxy.Credentials = $Proxy.Credentials
                }
            }

            $Sockets = $false
            try {
                $httpHandler = [System.Net.Http.SocketsHttpHandler]::New()
                $Sockets = $true
            } catch {
                $httpHandler = [System.Net.Http.HttpClientHandler]::New()
            }

            $httpHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate

            if (Test-IsCore) {
                try {
                    Add-Type -TypeDefinition @"
public class SSLHandler
{
    public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
    {
        return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
    }
    
}
"@
                    if ($Sockets) {
                        $httpHandler.SslOptions.RemoteCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
                    } else {
                        $httpHandler.ServerCertificateCustomValidationCallback = [SSLHandler]::GetSSLHandler()
                    }
                } catch {
                }
            }

            if ($WebProxy) {
                $httpHandler.Proxy = $WebProxy
            }
            $Global:GlobalHttpClient = [System.Net.Http.HttpClient]::new($httpHandler)

            $Global:GlobalHttpClient.Timeout = New-TimeSpan -Seconds 100
            if ($Session.LogLevel -eq "Debug") {Write-Log "New HttpClient created"}
        } catch {
            Write-Log "The installed .net version doesn't support HttpClient yet: $($_.Exception.Message)"
            $Global:GlobalHttpClient = $false
        }
    }
    $Global:GlobalHttpClient -ne $false
}

function Get-HttpStatusCode {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$Code = ""
    )
    if (-not (Test-Path Variable:Global:GlobalHttpStatusCodes)) {Get-HttpStatusCodes -Silent}
    $Global:GlobalHttpStatusCodes | Where StatusCode -eq $Code
}

function Get-HttpStatusCodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not (Test-Path Variable:Global:GlobalHttpStatusCodes)) {
        $Global:GlobalHttpStatusCodes = Get-ContentByStreamReader "Data\httpstatuscodes.json" | ConvertFrom-Json -ErrorAction Ignore
    }
    if (-not $Silent) {
        $Global:GlobalHttpStatusCodes
    }
}
