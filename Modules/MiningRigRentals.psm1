function Set-MiningRigRentalConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $Workers = $null
    )
    $ConfigName = "MRR"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if (-not (Test-Path $PathToFile) -or (Test-Config $ConfigName -LastWriteTime) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\MRRConfigDefault.ps1").LastWriteTimeUtc) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{EnableAutoCreate="";AutoCreateMinProfitPercent="";AutoCreateMinProfitBTC="";AutoCreateMaxMinHours="";AutoUpdateMinPriceChangePercent="";AutoCreateAlgorithm="";EnableAutoUpdate="";EnableAutoExtend="";AutoExtendTargetPercent="";AutoExtendMaximumPercent="";AutoBonusExtendForHours="";AutoBonusExtendByHours="";AutoBonusExtendTimes="";EnableAutoPrice="";EnableMinimumPrice="";EnableUpdateTitle="";EnableUpdateDescription="";EnableUpdatePriceModifier="";EnablePowerDrawAddOnly="";AutoPriceModifierPercent="";PriceBTC="";PriceFactor="";PriceFactorMin="";PriceFactorDecayPercent="";PriceFactorDecayTime="";PriceRiseExtensionPercent="";PowerDrawFactor="";MinHours="";MaxHours="";AllowExtensions="";AllowRentalDuringPause="";PriceCurrencies="";Title ="";Description="";ProfitAverageTime=""}
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

function Set-MiningRigRentalAlgorithmsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})MRRAlgorithms"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or (Test-Config $ConfigName -LastWriteTime) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\MRRAlgorithmsConfigDefault.ps1").LastWriteTimeUtc) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{Enable="1";PriceModifierPercent="";PriceFactor="";PriceFactorMin="";PriceFactorDecayPercent="";PriceFactorDecayTime="";PriceRiseExtensionPercent="";AllowExtensions=""}
            $Setup = Get-ChildItemContent ".\Data\MRRAlgorithmsConfigDefault.ps1"
            $AllAlgorithms = Get-MiningRigRentalAlgos
            foreach ($Algorithm in $AllAlgorithms) {
                $Algorithm_Norm = Get-MiningRigRentalAlgorithm $Algorithm.name
                if (-not $Preset.$Algorithm_Norm) {$Preset | Add-Member $Algorithm_Norm $(if ($Setup.$Algorithm_Norm) {$Setup.$Algorithm_Norm} else {[PSCustomObject]@{}}) -Force}
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$Algorithm_Norm.$SetupName -eq $null){$Preset.$Algorithm_Norm | Add-Member $SetupName $Default.$SetupName -Force}}
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

function Update-MiningRigRentalAlgorithmsConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Int]$UpdateInterval = 3600
    )

    $AllAlgorithms = Get-ConfigContent "MRRAlgorithms" -UpdateLastWriteTime

    if (Test-Config "MRRAlgorithms" -Health) {
        $Session.Config | Add-Member MRRAlgorithms ([PSCustomObject]@{}) -Force
        $AllAlgorithms.PSObject.Properties.Name | Where-Object {-not $Session.Config.Algorithm.Count -or $Session.Config.Algorithm -icontains $_} | Foreach-Object {
            $a = $_
            $Session.Config.MRRAlgorithms | Add-Member $a $AllAlgorithms.$a -Force

            $Algo_Params = [ordered]@{
                Enable          = $(if ($Session.Config.MRRAlgorithms.$a.Enable -ne $null) {Get-Yes $Session.Config.MRRAlgorithms.$a.Enable} else {$true})
                AllowExtensions = $(if ($Session.Config.MRRAlgorithms.$a.AllowExtensions -ne "" -and $Session.Config.MRRAlgorithms.$a.AllowExtensions -ne $null) {Get-Yes $Session.Config.MRRAlgorithms.$a.AllowExtensions} else {$null})
            }
            foreach ($Algo_Param in @("PriceModifierPercent","PriceFactor","PriceFactorMin","PriceFactorDecayPercent","PriceFactorDecayTime","PriceRiseExtensionPercent")) {
                if ($Algo_Param -match "Time$") {
                    $val = "$($Session.Config.MRRAlgorithms.$a.$Algo_Param)".Trim()
                    $Algo_Params[$Algo_Param] = if ($val -ne "") {[Math]::Max((ConvertFrom-Time "$($val)"),$UpdateInterval) / 3600} else {$null}
                } else {
                    $val = "$($Session.Config.MRRAlgorithms.$a.$Algo_Param -replace ",","." -replace "[^\d\.\-]+")"
                    $Algo_Params[$Algo_Param] = if ($val -ne "") {[Double]$(if ($val.Length -le 1) {$val -replace "[^0-9]"} else {$val[0] + "$($val.Substring(1) -replace "[^0-9\.]")"})} else {$null}
                }
            }
            if ($Algo_Params["PriceModifierPercent"] -ne $Null) {
                $Algo_Params["PriceModifierPercent"] = [Math]::Max(-30,[Math]::Min(30,[Math]::Round($Algo_Params["PriceModifierPercent"],2)))
            }
                
            $Algo_Params.GetEnumerator() | Foreach-Object {
                if ([bool]$Session.Config.MRRAlgorithms.$a.PSObject.Properties["$($_.Name)"]) {
                    $Session.Config.MRRAlgorithms.$a."$($_.Name)" = $_.Value
                } else {
                    $Session.Config.MRRAlgorithms.$a | Add-Member "$($_.Name)" $_.Value -Force
                }
            }
        }
    }
    if ($AllAlgorithms -ne $null) {Remove-Variable "AllAlgorithms"}
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
    [String]$regex = "",
    [Parameter(Mandatory = $False)]
    [String]$regexfld = "",
    [Parameter(Mandatory = $False)]
    [Bool]$regexmatch = $true,
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
    [switch]$Raw,
    [Parameter(Mandatory = $False)]
    [switch]$Force = $false
)

    if ($JobKey -and $JobData) {
        $endpoint  = $JobData.endpoint
        $key       = $JobData.key
        $secret    = $JobData.secret
        $params    = $JobData.params
        $method    = $JobData.method
        $base      = $JobData.base
        $regex     = $JobData.regex
        $regexfld  = $JobData.regexfld
        $regexmatch= $JobData.regexmatch
        $Timeout   = $JobData.timeout
        $ForceLocal= $JobData.forcelocal
        $Raw       = $JobData.raw
        $cycletime = $JobData.cycletime
        $retry     = $JobData.retry
        $retrywait = $JobData.retrywait
    } else {
        $JobKey = Get-MD5Hash "$($base)$($method)$($endpoint)$($regexfld)$($regex)$($regexmatch)$(Get-HashtableAsJson $params)"
        $cycletime = $retry = $retrywait = 0
    }

    $Result = $null

    if (-not (Test-Path Variable:Global:MRRCache)) {[hashtable]$Global:MRRCache = @{}}
    if (-not $Cache -or $Force -or -not $Global:MRRCache[$JobKey] -or -not $Global:MRRCache[$JobKey].request -or -not $Global:MRRCache[$JobKey].request.success -or $Global:MRRCache[$JobKey].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

        $Remote = $false

        if ($nonce -le 0) {$nonce = Get-UnixTimestamp -Milliseconds}

        $params_local = @{}
        if ($params) {$params.Keys | Foreach-Object {$params_local[$_] = $params[$_]}}

        if (-not $ForceLocal) {
            $Config = if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}

            if ($Config.RunMode -eq "Client" -and $Config.ServerName -and $Config.ServerPort -and (Test-TcpServer $Config.ServerName -Port $Config.ServerPort -Timeout 2)) {
                $serverbody = @{
                    endpoint  = $endpoint
                    key       = $key
                    secret    = $secret
                    params    = $params_local | ConvertTo-Json -Depth 10 -Compress
                    method    = $method
                    base      = $base
                    regex     = $regex
                    regexfld  = $regexfld
                    regexmatch= $regexmatch
                    timeout   = $timeout
                    nonce     = $nonce
                    cycletime = $cycletime
                    retry     = $retry
                    retrywait = $retrywait
                    machinename = $Session.MachineName
                    workername  = $Config.Workername
                    myip      = $Session.MyIP
                }
                try {
                    $GetMrr_Result = Invoke-GetUrl "http://$($Config.ServerName):$($Config.ServerPort)/getmrr" -body $serverbody -user $Config.ServerUser -password $Config.ServerPassword -ForceLocal -Timeout 30
                    if ($GetMrr_Result.Status) {$Data = $GetMrr_Result.Content;$Remote = $true}
                    if ($GetMrr_Result -ne $null) {$GetMrr_Result = $null}
                    #Write-Log -Level Info "MRR server $($method): endpoint=$($endpoint) params=$($serverbody.params)"
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Info "MiningRigRental server call: $($_.Exception.Message)"
                }
            }
        }

        if (-not $Remote) {
            $str = "$key$nonce$endpoint"
            $headers = [hashtable]@{
	            'x-api-sign' = Get-HMACSignature $str $secret "HMACSHA1"
	            'x-api-key'  = $key
	            'x-api-nonce'= $nonce
                'Cache-Control' = 'no-cache'
            }

            $ErrorMessage = ''

            try {
                $body = Switch -Regex ($method) {
                    "^(POST|PUT)$"   {$params_local | ConvertTo-Json -Depth 10 -Compress;Break}
                    "^(DELETE|GET)$" {if ($params_local.Count) {$params_local} else {$null};Break}
                }
                #Write-Log -Level Info "MiningRigRental call: $($endpoint) $($body)"
                $Data = Invoke-GetUrl "$base$endpoint" -useragent $useragent -timeout $Timeout -headers $headers -requestmethod $method -body $body
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $ErrorMessage = "$($_.Exception.Message)"
            }

            if ($ErrorMessage -ne '') {
                Write-Log -Level Info "MiningRigRental call: $($ErrorMessage)"
            }
        }
        if ($Data.success -ne $null -and -not $Data.success) {
            Write-Log -Level Warn "MiningRigRental error: $(if ($Data.data.message) {$Data.data.message} else {"unknown"})"
        }

        if (($Data -and $Data.success) -or -not $Cache -or -not $Global:MRRCache[$JobKey]) {
            if ($regex -and $regexfld -and $Data.data) {
                if ($regexmatch) {
                    $Data.data = $Data.data | Where-Object {$_.$regexfld -match $regex}
                } else {
                    $Data.data = $Data.data | Where-Object {$_.$regexfld -notmatch $regex}
                }
            }
            $Result = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Data; cachetime = $Cache}
        }
        if ($Data -ne $null) {$Data = $null}
    }

    if ($Cache) {
        if ($Result -eq $null) {
            if ($Global:MRRCache[$JobKey]) {
                $Result = $Global:MRRCache[$JobKey]
            }
        } else {
            $Global:MRRCache[$JobKey] = $Result
        }
    } elseif ($Global:MRRCache.ContainsKey($JobKey)) {
        $Global:MRRCache[$JobKey] = $null
        $Global:MRRCache.Remove($JobKey)
    }

    if ($Result -ne $null) {
        if ($Raw) {$Result.request}
        else {
            if ($Result.request -and $Result.request.success) {$Result.request.data}
        }
        $Result = $null
    }

    try {
        if ($Global:MRRCacheLastCleanup -eq $null -or $Global:MRRCacheLastCleanup -lt (Get-Date).AddMinutes(-10).ToUniversalTime()) {
            $Global:MRRCacheLastCleanup = (Get-Date).ToUniversalTime()
            $CacheKeys = $Global:MRRCache.Keys
            if ($RemoveKeys = $CacheKeys | Where-Object {$_ -ne $JobKey -and $Global:MRRCache.$_.last -lt (Get-Date).AddSeconds(-[Math]::Max(3600,$Global:MRRCache.$_.cachetime)).ToUniversalTime()} | Select-Object) {
                $RemoveKeys | Foreach-Object {
                    if ($Global:MRRCache.ContainsKey($_)) {
                        $Global:MRRCache[$_] = $null
                        $Global:MRRCache.Remove($_)
                    }
                }
            }
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
    [String]$regex = "",
    [Parameter(Mandatory = $False)]
    [String]$regexfld = "",
    [Parameter(Mandatory = $False)]
    [Bool]$regexmatch = $true,
    [Parameter(Mandatory = $False)]
    [int]$Timeout = 15,
    [Parameter(Mandatory = $False)]
    [string]$JobKey = "",
    [Parameter(Mandatory = $False)]
    [switch]$ForceLocal,
    [Parameter(Mandatory = $False)]
    [switch]$Raw,
    [Parameter(Mandatory = $False)]   
    [int]$cycletime = 0,
    [Parameter(Mandatory = $False)]   
    [int]$retry = 0,
    [Parameter(Mandatory = $False)]   
    [int]$retrywait = 250,
    [Parameter(Mandatory = $False)]   
    [switch]$force = $false,
    [Parameter(Mandatory = $False)]   
    [switch]$quiet = $false
)
    if (-not $endpoint -and -not $Jobkey) {return}

    if (-not $Jobkey) {$Jobkey = Get-MD5Hash "$($base)$($method)$($endpoint)$($regex)$($regexfld)$($regexmatch)$(Get-HashtableAsJson $params)";$StaticJobKey = $false} else {$StaticJobKey = $true}

    $tag = "MiningRigRentals"

    if (-not (Test-Path Variable:Global:Asyncloader) -or -not $AsyncLoader.Jobs.$Jobkey) {
        $JobHost = try{([System.Uri]$base).Host}catch{if($Error.Count){$Error.RemoveAt(0)};"www.miningrigrentals.com"}
        $JobData = [PSCustomObject]@{endpoint=$endpoint;key=$key;secret=$secret;params=$params;method=$method;base=$base;regex=$regex;regexfld=$regexfld;regexmatch=$regexmatch;forcelocal=[bool]$ForceLocal;raw=[bool]$Raw;Host=$JobHost;Error=$null;Running=$true;Paused=$false;Success=0;Fail=0;Prefail=0;LastRequest=(Get-Date).ToUniversalTime();LastCacheWrite=$null;LastFailRetry=$null;LastFailCount=0;CycleTime=$cycletime;Retry=$retry;RetryWait=$retrywait;Tag=$tag;Timeout=$timeout;Index=0}
    }

    if (-not (Test-Path Variable:Global:Asyncloader)) {
        Invoke-MiningRigRentalRequest -JobData $JobData -JobKey $JobKey
        $JobData.LastCacheWrite = (Get-Date).ToUniversalTime()
        return
    }
    
    if ($StaticJobKey -and $endpoint -and $AsyncLoader.Jobs.$Jobkey -and ($AsyncLoader.Jobs.$Jobkey.endpoint -ne $endpoint -or $AsyncLoader.Jobs.$Jobkey.key -ne $key -or $AsyncLoader.Jobs.$Jobkey.regex -ne $regex -or $AsyncLoader.Jobs.$Jobkey.regexfld -ne $regexfld -or $AsyncLoader.Jobs.$Jobkey.regexmatch -ne $regexmatch -or (Get-HashtableAsJson $AsyncLoader.Jobs.$Jobkey.params) -ne (Get-HashtableAsJson $params))) {$force = $true;$AsyncLoader.Jobs.$Jobkey.endpoint = $endpoint;$AsyncLoader.Jobs.$Jobkey.key = $key;$AsyncLoader.Jobs.$Jobkey.secret = $secret;$AsyncLoader.Jobs.$Jobkey.params = $params}

    if ($JobHost) {
        if ($AsyncLoader.HostTags.$JobHost -eq $null) {
            $AsyncLoader.HostTags.$JobHost = @($tag)
        } elseif ($AsyncLoader.HostTags.$JobHost -notcontains $tag) {
            $AsyncLoader.HostTags.$JobHost += $tag
        }
    }

    if (-not (Test-Path ".\Cache")) {New-Item "Cache" -ItemType "directory" -ErrorAction Ignore > $null}

    if ($force -or -not $AsyncLoader.Jobs.$Jobkey -or $AsyncLoader.Jobs.$Jobkey.Paused -or -not (Test-Path ".\Cache\$($Jobkey).asy") -or (Get-ChildItem ".\Cache\$($Jobkey).asy").LastWriteTimeUtc -lt (Get-Date).ToUniversalTime().AddSeconds(-$AsyncLoader.Jobs.$Jobkey.CycleTime*10)) {
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
                     $RetryWait_Time = [Math]::Min($AsyncLoader.Jobs.$Jobkey.RetryWait - $StopWatch.ElapsedMilliseconds,5000)
                    if ($RetryWait_Time -gt 50) {
                        Start-Sleep -Milliseconds $RetryWait_Time
                    }
                }
            }
        } until ($retry -le 0)

        $StopWatch.Stop()
        $StopWatch = $null

        if (-not $RequestError -and $Request) {
            try {
                $Request = $Request | ConvertTo-Json -Compress -Depth 10 -ErrorAction Stop
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $RequestError = "$($_.Exception.Message)"
            } finally {
                if ($RequestError) {$RequestError = "JSON problem: $($RequestError)"}
            }
        }

        $CacheWriteOk = $false

        if ($RequestError -or -not $Request) {
            $AsyncLoader.Jobs.$Jobkey.Prefail++
            if ($AsyncLoader.Jobs.$Jobkey.Prefail -gt 5) {$AsyncLoader.Jobs.$Jobkey.Fail++;$AsyncLoader.Jobs.$Jobkey.Prefail=0}            
        } else {
            $retry = 3
            do {
                $RequestError = $null
                try {
                    Write-ToFile -FilePath ".\Cache\$($Jobkey).asy" -Message $Request -NoCR -ThrowError
                    $CacheWriteOk = $true
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
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
            $AsyncLoader.Jobs.$Jobkey.LastCacheWrite=(Get-Date).ToUniversalTime()
        }

        if (-not (Test-Path ".\Cache\$($Jobkey).asy")) {
            try {New-Item ".\Cache\$($Jobkey).asy" -ItemType File > $null} catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }

        $AsyncLoader.Jobs.$Jobkey.Error = $RequestError
        $AsyncLoader.Jobs.$Jobkey.Running = $false
    }
    if (-not $quiet) {
        if ($AsyncLoader.Jobs.$Jobkey.Error -and $AsyncLoader.Jobs.$Jobkey.Prefail -eq 0 -and -not (Test-Path ".\Cache\$($Jobkey).asy")) {throw $AsyncLoader.Jobs.$Jobkey.Error}
        if (Test-Path ".\Cache\$($Jobkey).asy") {
            try {
                if (Test-IsPS7) {
                    Get-ContentByStreamReader ".\Cache\$($Jobkey).asy" | ConvertFrom-Json -ErrorAction Stop
                } else {
                    $Data = Get-ContentByStreamReader ".\Cache\$($Jobkey).asy" | ConvertFrom-Json -ErrorAction Stop
                    $Data
                }
            }
            catch {if ($Error.Count){$Error.RemoveAt(0)};Remove-Item ".\Cache\$($Jobkey).asy" -Force -ErrorAction Ignore;throw "Job $Jobkey contains clutter."}
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

function Get-MiningRigRentalStat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [Int]$RentalId
    )

    $Path   = "Stats\MRR"

    if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

    $Path = "$($Path)\$($Name)_rental.txt"

    $RentalError = $null

    try {
        $Stat = ConvertFrom-Json (Get-ContentByStreamReader $Path) -ErrorAction Stop
        if ($RentalId -and ($Stat.id -ne $RentalId)) {
            $RentalError = "obsolete"
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $RentalError = "corrupt"
    }
    if ($RentalError) {
        if (Test-Path $Path) {
            Write-Log -Level Warn "Stat file $([IO.Path]::GetFileName($Path)) is $($RentalError) and will be removed. "
            Remove-Item -Path $Path -Force -Confirm:$false
        }
    } else {
        $Stat
    }
}

function Set-MiningRigRentalStat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Data
    )

    $Path = "Stats\MRR"

    if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

    $Path = "$($Path)\$($Name)_rental.txt"

    try {
        $Data | ConvertTo-Json -Depth 10 -ErrorAction Stop | Set-Content $Path
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Could not write MRR rental stat file for worker $Name, rental id $($Data.id)"
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

    if (-not (Test-Path Variable:Global:MRRInfoCache)) {
        [hashtable]$Global:MRRInfoCache = @{}
        if (Test-Path ".\Data\mrrinfo.json") {
            try {
                $MrrInfo = Get-Content ".\Data\mrrinfo.json" -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $MrrInfo = @()
            }
            $MrrInfo | Foreach-Object {$Global:MRRInfoCache["$($_.rigid)"] = $_}
        }
    }

    if ($Rigs_Ids = $id | Where-Object {-not $Global:MRRInfoCache.ContainsKey("$_") -or $Global:MRRInfoCache."$_".port -eq "error" -or $Global:MRRInfoCache."$_".updated -lt (Get-Date).AddHours(-24).ToUniversalTime()} | Sort-Object) {
        $Updated = 0
        @(Invoke-MiningRigRentalRequest "/rig/$($Rigs_Ids -join ";")/port" $key $secret -Timeout 60 | Select-Object) | Foreach-Object {
            $Global:MRRInfoCache["$($_.rigid)"] = [PSCustomObject]@{rigid=$_.rigid;port=$_.port;server=$_.server;updated=(Get-Date).ToUniversalTime()}
            $Updated++
        }
        if ($Updated) {Set-ContentJson -PathToFile ".\Data\mrrinfo.json" -Data $Global:MRRInfoCache.Values -Compress > $null}
    }
    $id | Where-Object {$Global:MRRInfoCache.ContainsKey("$_")} | Foreach-Object {$Global:MRRInfoCache."$_"}
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
        elseif ($Status -eq "startmessagesent") {$Session.MRRStatus[$RigKey].startmessagesent = $true}
        elseif ($Status -eq "online") {$Session.MRRStatus[$RigKey].next = $time;$Session.MRRStatus[$RigKey].wait = $false;$Session.MRRStatus[$RigKey].enable = $true}
        elseif ($time -ge $Session.MRRStatus[$RigKey].next) {
            if ($Session.MRRStatus[$RigKey].wait) {$Session.MRRStatus[$RigKey].next = $time.AddMinutes(15);$Session.MRRStatus[$RigKey].wait = $Session.MRRStatus[$RigKey].enable = $false}
            else {$Session.MRRStatus[$RigKey].next = $time.AddMinutes(3);$Session.MRRStatus[$RigKey].wait = $Session.MRRStatus[$RigKey].enable = $true}
        }
    } else {$Session.MRRStatus[$RigKey] = [PSCustomObject]@{next = $time.AddMinutes(3); wait = $true; enable = $true; extended = $(if ($Status -eq "extended") {$true} else {$false}); extensionmessagesent = $(if ($Status -eq "extensionmessagesent") {$true} else {$false}); startmessagesent = $(if ($Status -eq "startmessagesent") {$true} else {$false})}}
    
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

    $Pool_Request.data | Foreach-Object {$_.display = $_.display.Trim()}

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
    [String[]]$workers
)
    $regex = "\[($($workers -join '|'))\]"
    if ($Session.Config.RunMode -eq "Server") {
        Invoke-MiningRigRentalRequestAsync "/rig/mine" $key $secret -cycletime 60 | Where-Object {$_.description -match $regex}
    } else {
        Invoke-MiningRigRentalRequestAsync "/rig/mine" $key $secret -cycletime 60 -regexfld "description" -regex $regex -regexmatch $true
    }
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

function Get-MiningRigRentalGroups {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    [String[]]$workers,
    [Parameter(Mandatory = $False)]
    [Int]$Cache = 0
)
    if ($Result = Invoke-MiningRigRentalRequest "/riggroup" $key $secret -Cache $Cache) {
        $Result.PSObject.Properties.Value | Where-Object {-not $Workers.Count -or "$($_.name -replace "^RBM-")" -in $Workers}
    }
}