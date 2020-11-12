function Set-MiningRigRentalConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $Workers = $null
    )
    $ConfigName = "MRR"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if (-not (Test-Path $PathToFile) -or (Test-Config $ConfigName -LastWriteTime) -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\MRRConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{UseWorkerName="";ExcludeWorkerName="";EnableAutoCreate="";AutoCreateMinProfitPercent="";AutoCreateMinProfitBTC="";AutoCreateMaxMinHours="";AutoUpdateMinPriceChangePercent="";AutoCreateAlgorithm="";EnableAutoUpdate="";EnableAutoExtend="";AutoExtendTargetPercent="";AutoExtendMaximumPercent="";AutoBonusExtendForHours="";AutoBonusExtendByHours="";EnableAutoPrice="";EnableMinimumPrice="";EnableUpdateTitle="";EnableUpdateDescription="";EnableUpdatePriceModifier="";EnablePowerDrawAddOnly="";AutoPriceModifierPercent="";PriceBTC="";PriceFactor="";PriceFactorMin="";PriceFactorDecayPercent="";PriceFactorDecayTime="";PowerDrawFactor="";MinHours="";MaxHours="";AllowExtensions="";PriceCurrencies="";Title = "";Description = "";ProfitAverageTime = ""}
            $Setup = Get-ChildItemContent ".\Data\MRRConfigDefault.ps1"
            
            foreach ($RigName in @(@($Setup.PSObject.Properties.Name | Select-Object) + @($Workers) | Select-Object -Unique)) {
                if (-not $Preset.$RigName) {$Preset | Add-Member $RigName $(if ($Setup.$RigName) {$Setup.$RigName} else {[PSCustomObject]@{}}) -Force}
            }

            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {                
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$_.$SetupName -eq $null){$Preset.$_ | Add-Member $SetupName $Default.$SetupName -Force}}
                $Sorted | Add-Member $_ $Preset.$_ -Force
            }
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
            $Session.ConfigFiles[$ConfigName].Healthy = $true
            Set-ConfigLastWriteTime $ConfigName
        }
        catch{
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
            $Session.ConfigFiles[$ConfigName].Healthy = $false
        }
    }
    Test-Config $ConfigName -Exists
}

function Invoke-MiningRigRentalRequest {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $False)]
    [String]$endpoint = "",
    [Parameter(Mandatory = $False)]
    [String]$key = "",
    [Parameter(Mandatory = $False)]
    [String]$secret = "",
    [Parameter(Mandatory = $False)]
    [hashtable]$params,
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://www.miningrigrentals.com/api/v2",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0,
    [Parameter(Mandatory = $False)]
    [int64]$nonce = 0,
    [Parameter(Mandatory = $False)]
    [string]$useragent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36",
    [Parameter(Mandatory = $False)]
    $JobData,
    [Parameter(Mandatory = $False)]
    [string]$JobKey = "",
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal,
    [Parameter(Mandatory = $False)]
    [switch]$Raw
)

    if ($JobKey -and $JobData) {
        $endpoint  = $JobData.endpoint
        $key       = $JobData.key
        $secret    = $JobData.secret
        $params    = $JobData.params
        $method    = $JobData.method
        $base      = $JobData.base
        $Timeout   = $JobData.timeout
        $Cache     = $JobData.cache
        $ForceLocal= $JobData.forcelocal
        $Raw       = $JobData.raw
    } else {
        $JobKey = Get-MD5Hash "$($method)$($endpoint)$(Get-HashtableAsJson $params)"
    }

    if ($Session.MRRCache -eq $null) {[hashtable]$Session.MRRCache = @{}}
    if (-not $Cache -or -not $Session.MRRCache[$JobKey] -or -not $Session.MRRCache[$JobKey].request -or -not $Session.MRRCache[$JobKey].request.success -or $Session.MRRCache[$JobKey].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

       $Remote = $false

       if ($nonce -le 0) {$nonce = Get-UnixTimestamp -Milliseconds}

        $params_local = @{}
        if ($params) {$params.Keys | Foreach-Object {$params_local[$_] = $params[$_]}}

       if (-not $ForceLocal -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and (Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 2)) {
            $serverbody = @{
                endpoint  = $endpoint
                key       = $key
                secret    = $secret
                params    = $params_local | ConvertTo-Json -Depth 10 -Compress
                method    = $method
                base      = $base
                timeout   = $timeout
                nonce     = $nonce
                machinename = $Session.MachineName
                workername  = $Session.Config.Workername
                myip      = $Session.MyIP
            }
            try {
                $Result = Invoke-GetUrl "http://$($Session.Config.ServerName):$($Session.Config.ServerPort)/getmrr" -body $serverbody -user $Session.Config.ServerUser -password $Session.Config.ServerPassword -ForceLocal
                if ($Result.Status) {$Request = $Result.Content;$Remote = $true}
                #Write-Log -Level Info "MRR server $($method): endpoint=$($endpoint) params=$($serverbody.params)"
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "MiningRigRental server call: $($_.Exception.Message)"
            }
        }

        if (-not $Remote) {
            $str = "$key$nonce$endpoint"
            $sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HMACSHA1")
            $sha.key = [System.Text.Encoding]::UTF8.Getbytes($secret)
            $sign = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${str})))    
            $headers = [hashtable]@{
	            'x-api-sign' = ($sign -replace '\-').ToLower()
	            'x-api-key'  = $key
	            'x-api-nonce'= $nonce
                'Cache-Control' = 'no-cache'
            }
            try {
                $body = Switch($method) {
                    "PUT" {$params_local | ConvertTo-Json -Depth 10;Break}
                    "GET" {if ($params_local.Count) {$params_local} else {$null};Break}
                }
                #Write-Log -Level Info "MiningRigRental call: $($endpoint)"
                $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint("$base$endpoint")
                $Request = Invoke-RestMethod "$base$endpoint" -UseBasicParsing -UserAgent $useragent -TimeoutSec $Timeout -ErrorAction Stop -Headers $headers -Method $method -Body $body
                #$Request = Invoke-GetUrl "$base$endpoint" -timeout $Timeout -headers $headers -requestmethod $method -body $body
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "MiningRigRental call: $($_.Exception.Message)"
            } finally {
                if ($ServicePoint) {$ServicePoint.CloseConnectionGroup("") > $null}
            }
        }
        if ($Request.success -ne $null -and -not $Request.success) {
            Write-Log -Level Warn "MiningRigRental error: $(if ($Request.data.message) {$Request.data.message} else {"unknown"})"
        }

        if (-not $Session.MRRCache[$JobKey] -or ($Request -and $Request.success)) {
            $Session.MRRCache[$JobKey] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request; cachetime = $Cache}
        }
    }
    if ($Raw) {$Session.MRRCache[$JobKey].request}
    else {
        if ($Session.MRRCache[$JobKey].request -and $Session.MRRCache[$JobKey].request.success) {$Session.MRRCache[$JobKey].request.data}
    }

    try {
        if ($Session.MRRCacheLastCleanup -eq $null -or $Session.MRRCacheLastCleanup -lt (Get-Date).AddMinutes(-10).ToUniversalTime()) {
            if ($RemoveKeys = $Session.MRRCache.Keys | Where-Object {$_ -ne $JobKey -and $Session.MRRCache.$_.last -lt (Get-Date).AddSeconds(-[Math]::Max(3600,$Session.MRRCache.$_.cachetime)).ToUniversalTime()} | Select-Object) {
                $RemoveKeys | Foreach-Object {$Session.MRRCache[$_] = $null; $Session.MRRCache.Remove($_)}
            }
            $Session.MRRCacheLastCleanup = (Get-Date).ToUniversalTime()
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Info "MiningRigRental cache cleanup: $($_.Exception.Message)"
    }
}

function Invoke-MiningRigRentalRequestAsync {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $False)]
    [String]$endpoint = "",
    [Parameter(Mandatory = $False)]
    [String]$key = "",
    [Parameter(Mandatory = $False)]
    [String]$secret = "",
    [Parameter(Mandatory = $False)]
    [hashtable]$params,
    [Parameter(Mandatory = $False)]
    [String]$method = "GET",
    [Parameter(Mandatory = $False)]
    [String]$base = "https://www.miningrigrentals.com/api/v2",
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [int]$Cache = 0,
    [Parameter(Mandatory = $False)]
    [int64]$nonce = 0,
    [Parameter(Mandatory = $False)]
    [string]$JobKey = "",
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal,
    [Parameter(Mandatory = $False)]
    [switch]$Raw,
    [Parameter(Mandatory = $False)]   
    [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]   
    [switch]$force = $false,
    [Parameter(Mandatory = $False)]   
    [switch]$quiet = $false
)
    if (-not $endpoint -and -not $Jobkey) {return}

    if (-not $Jobkey) {$Jobkey = Get-MD5Hash "$($method)$($endpoint)$(Get-HashtableAsJson $params)";$StaticJobKey = $false} else {$StaticJobKey = $true}

    if (-not (Test-Path Variable:Global:Asyncloader) -or -not $AsyncLoader.Jobs.$Jobkey) {
        $JobData = [PSCustomObject]@{endpoint=$endpoint;key=$key;secret=$secret;params=$params;method=$method;base=$base;cache=$cache;forcelocal=$ForceLocal;raw=$Raw;Error=$null;Running=$true;Paused=$false;Success=0;Fail=0;Prefail=0;LastRequest=(Get-Date).ToUniversalTime();LastCacheWrite=$null;LastFailRetry=$null;CycleTime=$cycletime;Retry=0;RetryWait=0;Tag="MiningRigRentals";Timeout=$timeout;Index=0}
    }

    if (-not (Test-Path Variable:Global:Asyncloader)) {
        Invoke-MiningRigRentalRequest -JobData $JobData -JobKey $JobKey
        $JobData.LastCacheWrite = (Get-Date).ToUniversalTime()
        return
    }
    
    if ($StaticJobKey -and $endpoint -and $AsyncLoader.Jobs.$Jobkey -and ($AsyncLoader.Jobs.$Jobkey.endpoint -ne $endpoint -or $AsyncLoader.Jobs.$Jobkey.key -ne $key -or (Get-HashtableAsJson $AsyncLoader.Jobs.$Jobkey.params) -ne (Get-HashtableAsJson $params))) {$force = $true;$AsyncLoader.Jobs.$Jobkey.endpoint = $endpoint;$AsyncLoader.Jobs.$Jobkey.key = $key;$AsyncLoader.Jobs.$Jobkey.secret = $secret;$AsyncLoader.Jobs.$Jobkey.params = $params}

    if ($force -or -not $AsyncLoader.Jobs.$Jobkey -or $AsyncLoader.Jobs.$Jobkey.Paused -or -not $Session.MRRCache -or -not $Session.MRRCache[$JobKey]) {
        if (-not $AsyncLoader.Jobs.$Jobkey) {
            $AsyncLoader.Jobs.$Jobkey = $JobData
            $AsyncLoader.Jobs.$Jobkey.Index = $AsyncLoader.Jobs.Count
        } else {
            $AsyncLoader.Jobs.$Jobkey.Running=$true
            $AsyncLoader.Jobs.$JobKey.LastRequest=(Get-Date).ToUniversalTime()
            $AsyncLoader.Jobs.$Jobkey.Paused=$false
        }

        $retry = $AsyncLoader.Jobs.$Jobkey.Retry + 1

        $StopWatch = [System.Diagnostics.Stopwatch]::New()
        do {
            $Request = $RequestError = $null
            $StopWatch.Restart()
            try {                
                $Request = Invoke-MiningRigRentalRequest -JobData $AsyncLoader.Jobs.$Jobkey -JobKey $JobKey
                if ($Request) {
                    $AsyncLoader.Jobs.$Jobkey.Success++
                    $AsyncLoader.Jobs.$Jobkey.Prefail=0
                } else {
                    $RequestError = "Empty request"
                }
            }
            catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $RequestError = "$($_.Exception.Message)"
            } finally {
                if ($RequestError) {$RequestError = "Problem fetching $($AsyncLoader.Jobs.$Jobkey.Url) using $($AsyncLoader.Jobs.$Jobkey.Method): $($RequestError)"}
            }

            $AsyncLoader.Jobs.$Jobkey.LastRequest=(Get-Date).ToUniversalTime()

            $retry--
            if ($retry -gt 0) {
                if (-not $RequestError) {$retry = 0}
                else {
                    $Passed = $StopWatch.ElapsedMilliseconds
                    if ($AsyncLoader.Jobs.$Jobkey.RetryWait -gt $Passed) {
                        Start-Sleep -Milliseconds ($AsyncLoader.Jobs.$Jobkey.RetryWait - $Passed)
                    }
                }
            }
        } until ($retry -le 0)

        $StopWatch.Stop()
        $StopWatch = $null

        if ($RequestError -or -not $Request) {
            $AsyncLoader.Jobs.$Jobkey.Prefail++
            if ($AsyncLoader.Jobs.$Jobkey.Prefail -gt 5) {$AsyncLoader.Jobs.$Jobkey.Fail++;$AsyncLoader.Jobs.$Jobkey.Prefail=0}            
        } elseif ($Session.MRRCache[$JobKey]) {
            $AsyncLoader.Jobs.$Jobkey.LastCacheWrite=$Session.MRRCache[$JobKey].last
        }

        $AsyncLoader.Jobs.$Jobkey.Error = $RequestError
        $AsyncLoader.Jobs.$Jobkey.Running = $false
    }
    if (-not $quiet) {
        if ($AsyncLoader.Jobs.$Jobkey.Error -and $AsyncLoader.Jobs.$Jobkey.Prefail -eq 0 -and -not $Session.MRRCache[$JobKey]) {throw $AsyncLoader.Jobs.$Jobkey.Error}
        if ($Session.MRRCache -and $Session.MRRCache[$JobKey]) {
            if ($Raw) {$Session.MRRCache[$JobKey].request}
            else {
                if ($Session.MRRCache[$JobKey].request -and $Session.MRRCache[$JobKey].request.success) {$Session.MRRCache[$JobKey].request.data}
            }
        }
    }
}

function Get-MiningRigRentalAlgorithm {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$Name
)
    Get-Algorithm $(Switch ($Name) {
            "cuckaroo24"        {"Cuckaroom29";Break}
            "cuckoocycle"       {"Cuckarood29";Break}
            "equihash1505"      {"BeamHash3";Break}
            "x16rt"             {"X16rtVeil";Break}
            "x16rtgin"          {"X16rt";Break}
            default             {$Name}
        }
    )
}

function Get-MiningRigRentalCoin {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$Name
)
    Switch ($Name) {
            "cuckaroo24"        {"PMEER";Break}
            "cuckoocycle"       {"GRIN";Break}
            "cuckoocycle29swap" {"SWAP";Break}
            "equihash1505"      {"BEAM";Break}
            "equihash1505g"     {"GRIMM";Break}
            "blake2b"           {"TNET";Break}
            default             {""}
    }
}

function Get-MiningRigStat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name
    )

    $Path   = "Stats\MRR"

    if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

    $Path = "$($Path)\$($Name).txt"

    try {
        $Stat = ConvertFrom-Json (Get-ContentByStreamReader $Path) -ErrorAction Stop
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        if (Test-Path $Path) {
            Write-Log -Level Warn "Stat file ($([IO.Path]::GetFileName($Path)) is corrupt and will be removed. "
            Remove-Item -Path $Path -Force -Confirm:$false
        }
    }
    $Stat
}

function Set-MiningRigStat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Data
    )

    $Path = "Stats\MRR"

    if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

    $Path = "$($Path)\$($Name).txt"

    $DataSorted = [PSCustomObject]@{}
    $Data.PSObject.Properties.Name | Sort-Object | Foreach-Object {
        $DeviceName = $_
        $AlgoSorted = [PSCustomObject]@{}
        $Data.$DeviceName.PSObject.Properties.Name | Sort-Object | Foreach-Object {
            $AlgoName = $_
            $AlgoSorted | Add-Member $AlgoName $Data.$DeviceName.$AlgoName -Force
        }
        $DataSorted | Add-Member $DeviceName $AlgoSorted -Force
    }

    try {
        $DataSorted | ConvertTo-Json -Depth 10 -ErrorAction Stop | Set-Content $Path
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Could not write MRR stat file for worker $Name"
    }
}

function Get-MiningRigInfo {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    $id,
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret
)
    if (-not $id) {return}

    if ($Session.MRRInfoCache -eq $null) {
        [hashtable]$Session.MRRInfoCache = @{}
        if (Test-Path ".\Data\mrrinfo.json") {
            try {
                $MrrInfo = Get-Content ".\Data\mrrinfo.json" -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $MrrInfo = @()
            }
            $MrrInfo | Foreach-Object {$Session.MRRInfoCache["$($_.rigid)"] = $_}
        }
    }

    if ($Rigs_Ids = $id | Where-Object {-not $Session.MRRInfoCache.ContainsKey("$_")-or $Session.MRRInfoCache."$_".port -eq "error" -or $Session.MRRInfoCache."$_".updated -lt (Get-Date).AddHours(-24).ToUniversalTime()} | Sort-Object) {
        $Updated = 0
        @(Invoke-MiningRigRentalRequest "/rig/$($Rigs_Ids -join ";")/port" $key $secret -Timeout 60 | Select-Object) | Foreach-Object {
            $Session.MRRInfoCache["$($_.rigid)"] = [PSCustomObject]@{rigid=$_.rigid;port=$_.port;server=$_.server;updated=(Get-Date).ToUniversalTime()}
            $Updated++
        }
        if ($Updated) {Set-ContentJson -PathToFile ".\Data\mrrinfo.json" -Data $Session.MRRInfoCache.Values -Compress > $null}
    }
    $id | Where-Object {$Session.MRRInfoCache.ContainsKey("$_")} | Foreach-Object {$Session.MRRInfoCache."$_"}
}

function Get-MiningRigRentalsDivisor {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$unit
)
    Switch (($unit -split "\*")[0]) {
        "kh" {1e3;Break}
        "mh" {1e6;Break}
        "gh" {1e9;Break}
        "th" {1e12;Break}
        default {1}
    }
}

function Get-MiningRigRentalStatus {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [Int]$RigId
)
    if ($Session.MRRStatus -ne $null) {
        $RigKey = "$RigId"
        $Session.MRRStatus[$RigKey]
    }
}

function Set-MiningRigRentalStatus {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [Int]$RigId,
    [Parameter(Mandatory = $False)]
    [Switch]$Stop,
    [Parameter(Mandatory = $False)]
    [String]$Status = ""
)
    if ($Session.MRRStatus -eq $null) {[hashtable]$Session.MRRStatus = @{}}
    $time = (Get-Date).ToUniversalTime()
    $RigKey = "$RigId"
    if ($Session.MRRStatus.ContainsKey($RigKey)) {
        if ($Stop) {$Session.MRRStatus.Remove($RigKey)}
        elseif ($Status -eq "extended") {$Session.MRRStatus[$RigKey].extended = $true}
        elseif ($Status -eq "notextended") {$Session.MRRStatus[$RigKey].extended = $false}
        elseif ($Status -eq "extensionmessagesent") {$Session.MRRStatus[$RigKey].extensionmessagesent = $true}
        elseif ($Status -eq "online") {$Session.MRRStatus[$RigKey].next = $time;$Session.MRRStatus[$RigKey].wait = $false;$Session.MRRStatus[$RigKey].enable = $true}
        elseif ($time -ge $Session.MRRStatus[$RigKey].next) {
            if ($Session.MRRStatus[$RigKey].wait) {$Session.MRRStatus[$RigKey].next = $time.AddMinutes(15);$Session.MRRStatus[$RigKey].wait = $Session.MRRStatus[$RigKey].enable = $false}
            else {$Session.MRRStatus[$RigKey].next = $time.AddMinutes(3);$Session.MRRStatus[$RigKey].wait = $Session.MRRStatus[$RigKey].enable = $true}
        }
    } else {$Session.MRRStatus[$RigKey] = [PSCustomObject]@{next = $time.AddMinutes(3); wait = $true; enable = $true; extended = $(if ($Status -eq "extended") {$true} else {$false}); extensionmessagesent = $(if ($Status -eq "extensionmessagesent") {$true} else {$false})}}
    
    if (-not $Stop) {$Session.MRRStatus[$RigKey].enable}
}

function Get-MiningRigRentalAlgos {
    $Name = "MiningRigRentals"

    $Pool_Request = [PSCustomObject]@{}
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://www.miningrigrentals.com/api/v2/info/algos" -tag $Name -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    if (-not $Pool_Request.success) {
        Write-Log -Level Warn "Pool API ($Name/info/algos) returned nothing. "
        return
    }

    $Pool_Request.data
}

function Get-MiningRigRentalServers {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $False)]
    $Region
)

    $Name = "MiningRigRentals"

    $Pool_Request = [PSCustomObject]@{}
    try {
        $Pool_Request = Invoke-RestMethodAsync "https://www.miningrigrentals.com/api/v2/info/servers" -tag $Name -cycletime 86400
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    try {
        $Servers = Get-Content ".\Data\mrrservers.json" -Raw | ConvertFrom-Json
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "mrrservers.json missing in Data folder! Cannot run MiningRigRentals"
    }

    if ($Pool_Request.success -and ((Compare-Object @($Pool_Request.data | Select-Object -ExpandProperty name) @($Servers | Select-Object -ExpandProperty name)) -or -not (Test-Path ".\Data\mrrservers.json"))) {
        Set-ContentJson ".\Data\mrrservers.json" -Data @($Pool_Request.data | Sort-Object @{Expression={$_.region -match "^(eu|us)"};Descending=$true},@{Expression={$_.name};Descending=$false}) > $null
        $Servers = @($Pool_Request.data | Foreach-Object {$_})
    }

    if (-not $Region) {$Servers}
    else {
        if ($Region -is [string]) {$Region = @(Get-Region $Region)+@(Get-Region2 "$(Get-Region $Region)")}
        foreach($Region1 in $Region) {
            $RigServer = $Servers.Where({$Region1 -eq "$(Get-Region ($_.region -replace "^eu-"))"},'First',1)
            if ($RigServer) {break}
        }
        if ($RigServer) {$RigServer | Select-Object -First 1} else {$Servers | Select-Object -First 1}
    }
}

function Get-MiningRigRentalRigs {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret,
    [Parameter(Mandatory = $True)]
    [String[]]$workers,
    [Parameter(Mandatory = $False)]
    [Int]$Cache = 0
)
    Invoke-MiningRigRentalRequestAsync "/rig/mine" $key $secret -Cache $Cache -cycletime $Session.Config.Interval | Where-Object description -match "\[($($workers -join '|'))\]"
}

function Update-MiningRigRentalRigs {
    Write-Host "Not implemented"
}

function Invoke-MiningRigRentalUpdatePrices {
    Write-Host "Not implemented"
}

function Get-MiningRigRentalsRigID {
[cmdletbinding()]
Param(   
    [Parameter(
        Mandatory = $True,   
        Position = 0,   
        ParameterSetName = '',   
        ValueFromPipeline = $True)]   
        [string]$worker
)
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = new-object -TypeName System.Text.UTF8Encoding
    $idstr = [convert]::ToBase64String($md5.ComputeHash($utf8.GetBytes($worker))) -replace "[^a-z0-9]"
    "$($idstr.substring(0,2))$($idstr.substring($idstr.Length-2,2))"
}

function Get-MiningRigRentalsSubst {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $True)]
    [string]$Text,
    [Parameter(Mandatory = $True)]
    [hashtable]$Subst
)
    foreach ($i in $Subst.Keys) {$Text = $Text -replace "%$i%", $Subst[$i]}
    "$($Text -replace "[\s+]"," ")"
}

function Get-MiningRigRentalsPoolsData {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    [Switch]$UpdateLocalCopy
)
    try {
        $PoolsData = Invoke-RestMethodAsync "https://rbminer.net/api/data/mrrpools.json" -Tag "MiningRigRentals" -cycletime 1800
        if ($UpdateLocalCopy) {
            Set-ContentJson -PathToFile ".\Data\mrrpools.json" -Data $PoolsData -Compress > $null
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Rbminer.net/api/data/mrrpools.json could not be reached"
    }
    if (-not $PoolsData) {
        try {
            $PoolsData = Get-ContentByStreamReader ".\Data\mrrpools.json" | ConvertFrom-Json -ErrorAction Stop
        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
    }
    $PoolsData
}