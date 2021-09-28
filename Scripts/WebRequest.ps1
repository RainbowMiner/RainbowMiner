param($RequestUrl, $useragent, $timeout, $requestmethod, $method, $headers, $body, $IsForm, $IsPS7, $IsCore, $fixbigint)


if ($Global:IsWindows -eq $null) {
    $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
    $Global:IsLinux   = -not $IsWindows
    $Global:IsMacOS   = $false
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

$oldProgressPreference = $null
if ($Global:ProgressPreference -ne "SilentlyContinue") {
    $oldProgressPreference = $Global:ProgressPreference
    $Global:ProgressPreference = "SilentlyContinue"
}

if ($IsCore) {
    try {
        $Response   = $null
        if ($IsPS7) {
            if ($IsForm) {
                $Response = Invoke-WebRequest $RequestUrl -SkipHttpErrorCheck -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Form $body
            } else {
                $Response = Invoke-WebRequest $RequestUrl -SkipHttpErrorCheck -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body
            }
        } else {
            if ($IsForm) {
                $Response = Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Form $body
            } else {
                $Response = Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body
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
                    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                }
                try {$Result.Data = ConvertFrom-Json $Result.Data -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}}
            }
            if ($Result.Data -and $Result.Data.unlocked -ne $null) {$Result.Data.PSObject.Properties.Remove("unlocked")}
        }

        if ($Response) {
            $Response = $null
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Result.ErrorMessage = "$($_.Exception.Message)"
    }
} else {
    try {
        $ServicePoint = $null
        if ($method -eq "REST") {
            $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($RequestUrl)
            $Result.Data = Invoke-RestMethod $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body
        } else {
            $Result.Data = (Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers -Body $body).Content
        }
        if ($Result.Data -and $Result.Data.unlocked -ne $null) {$Result.Data.PSObject.Properties.Remove("unlocked")}
        $Result.Status = $true
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Result.ErrorMessage = "$($_.Exception.Message)"
    } finally {
        if ($ServicePoint) {$ServicePoint.CloseConnectionGroup("") > $null}
        $ServicePoint = $null
    }
}
if ($oldProgressPreference) {$Global:ProgressPreference = $oldProgressPreference}

$Result