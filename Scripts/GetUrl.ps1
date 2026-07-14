param($RequestUrl,$method,$useragent,$timeout,$requestmethod,$headers_local,$body)

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

if ($timeout -eq $null) {
    $timeout = 60
}

if ($requestmethod -eq $null) {
    $requestmethod = if ($body) {"POST"} else {"GET"}
}

try {
    $Script:IWRCompat = @{}
    $IWRCmd = Get-Command Invoke-WebRequest
    if ($IWRCmd.Parameters.ContainsKey("AllowInsecureRedirect")) { $Script:IWRCompat["AllowInsecureRedirect"] = $true }
    if ($method -eq "REST") {
        $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($RequestUrl)
        $Data = Invoke-RestMethod $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body @Script:IWRCompat
    } else {
        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        $Data = (Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body @Script:IWRCompat).Content
        $Global:ProgressPreference = $oldProgressPreference
    }
    if ($Data -and $Data.unlocked -ne $null) {[void]$Data.PSObject.Properties.Remove("unlocked")}
} catch {
    $Data = [PSCustomObject]@{ErrorMessage="$($_.Exception.Message)"}
} finally {
    if ($ServicePoint) {$ServicePoint.CloseConnectionGroup("") > $null}
}

[PSCustomObject]@{Data = $Data}
