param($RequestUrl,$method,$useragent,$timeout,$requestmethod,$headers_local,$body)

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}
        
try {
    if ($method -eq "REST") {
        $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($RequestUrl)
        $Data = Invoke-RestMethod $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body
    } else {
        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        $Data = (Invoke-WebRequest $RequestUrl -UseBasicParsing -UserAgent $useragent -TimeoutSec $timeout -ErrorAction Stop -Method $requestmethod -Headers $headers_local -Body $body).Content
        $Global:ProgressPreference = $oldProgressPreference
    }
    if ($Data -and $Data.unlocked -ne $null) {$Data.PSObject.Properties.Remove("unlocked")}
} catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Data = [PSCustomObject]@{ErrorMessage="$($_.Exception.Message)"}
} finally {
    if ($ServicePoint) {$ServicePoint.CloseConnectionGroup("") > $null}
}

[PSCustomObject]@{Data = $Data}
