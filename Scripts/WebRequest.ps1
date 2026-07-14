param($RequestUrl, $useragent, $timeout, $requestmethod, $method, $headers, $body, $IsForm, $fixbigint)


if ($Global:IsWindows -eq $null) {
    $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
    $Global:IsLinux   = -not $IsWindows
    $Global:IsMacOS   = $false
}

if ($timeout -eq $null) {
    $timeout = 60
}

if ($requestmethod -eq $null) {
    $requestmethod = if ($body) {"POST"} else {"GET"}
}

if ("$((Get-Culture).NumberFormat.NumberGroupSeparator)$((Get-Culture).NumberFormat.NumberDecimalSeparator)" -notmatch "^[,.]{2}$") {
    [CultureInfo]::CurrentCulture = 'en-US'
}

if (-not (Get-Command "Start-ThreadJob" -ErrorAction SilentlyContinue)) {Set-Alias -Scope Global Start-ThreadJob Start-Job}

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

$Result = [PSCustomObject]@{
    Status       = $false
    StatusCode   = $null
    Data         = $null
    ErrorMessage = ""
}

$IsCore = $PSVersionTable.PSVersion -ge ([System.Version]"6.1")
$IsPS7  = $PSVersionTable.PSVersion -ge ([System.Version]"7.0")

$oldProgressPreference = $null
if ($Global:ProgressPreference -ne "SilentlyContinue") {
    $oldProgressPreference = $Global:ProgressPreference
    $Global:ProgressPreference = "SilentlyContinue"
}

if ($IsCore) {
    try {
        $Script:IWRCompat = @{}
        $IWRCmd = Get-Command Invoke-WebRequest
        if ($IWRCmd.Parameters.ContainsKey("SkipHttpErrorCheck"))    { $Script:IWRCompat["SkipHttpErrorCheck"]    = $true }
        if ($IWRCmd.Parameters.ContainsKey("AllowInsecureRedirect")) { $Script:IWRCompat["AllowInsecureRedirect"] = $true }

        $Response   = $null
        if ($IsForm) {
            $Response = Invoke-WebRequest $RequestUrl -UseBasicParsing -DisableKeepAlive -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Form $body @Script:IWRCompat
        } else {
            $Response = Invoke-WebRequest $RequestUrl -UseBasicParsing -DisableKeepAlive -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body @Script:IWRCompat
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
            $Result.Data = Invoke-RestMethod $RequestUrl -UseBasicParsing -DisableKeepAlive -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body
        } else {
            $Result.Data = (Invoke-WebRequest $RequestUrl -UseBasicParsing -DisableKeepAlive -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body).Content
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

$Result