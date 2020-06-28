Set-Location (Split-Path $MyInvocation.MyCommand.Path)

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
            $Default = [PSCustomObject]@{UseWorkerName="";ExcludeWorkerName="";EnableAutoCreate="";AutoCreateMinProfitPercent="";AutoCreateMinProfitBTC="";AutoCreateMaxMinHours="";AutoUpdateMinPriceChangePercent="";AutoCreateAlgorithm="";EnableAutoUpdate="";EnableAutoExtend="";AutoExtendTargetPercent="";AutoExtendMaximumPercent="";AutoBonusExtendForHours="";AutoBonusExtendByHours="";EnableAutoPrice="";EnableMinimumPrice="";EnableUpdateTitle="";EnableUpdateDescription="";EnableUpdatePriceModifier="";EnablePowerDrawAddOnly="";AutoPriceModifierPercent="";PriceBTC="";PriceFactor="";PowerDrawFactor="";MinHours="";MaxHours="";PriceCurrencies="";Title = "";Description = ""}
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
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    $params = @{},
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
    [switch]$ForceLocal,
    [Parameter(Mandatory = $False)]
    [switch]$Raw
)
    $keystr = Get-MD5Hash "$($endpoint)$(Get-HashtableAsJson $params)"
    if (-not (Test-Path Variable:Global:MRRCache)) {[hashtable]$Global:MRRCache = @{}}
    if (-not $Cache -or -not $Global:MRRCache[$keystr] -or -not $Global:MRRCache[$keystr].request -or -not $Global:MRRCache[$keystr].request.success -or $Global:MRRCache[$keystr].last -lt (Get-Date).ToUniversalTime().AddSeconds(-$Cache)) {

       $Remote = $false

       if ($nonce -le 0) {$nonce = Get-UnixTimestamp -Milliseconds}

       if (-not $ForceLocal -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and (Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 1)) {
            $serverbody = @{
                endpoint  = $endpoint
                key       = $key
                secret    = $secret
                params    = $params | ConvertTo-Json -Depth 10 -Compress
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
            $ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36"
            try {
                $body = Switch($method) {
                    "PUT" {$params | ConvertTo-Json -Depth 10;Break}
                    "GET" {if ($params.Count) {$params} else {$null};Break}
                }
                #Write-Log -Level Info "MiningRigRental call: $($endpoint)"
                $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint("$base$endpoint")
                $Request = Invoke-RestMethod "$base$endpoint" -UseBasicParsing -UserAgent $ua -TimeoutSec $Timeout -ErrorAction Stop -Headers $headers -Method $method -Body $body
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

        if (-not $Global:MRRCache[$keystr] -or ($Request -and $Request.success)) {
            $Global:MRRCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request; cachetime = $Cache}
        }
    }
    if ($Raw) {$Global:MRRCache[$keystr].request}
    else {
        if ($Global:MRRCache[$keystr].request -and $Global:MRRCache[$keystr].request.success) {$Global:MRRCache[$keystr].request.data}
    }

    try {
        if ($Global:MRRCacheLastCleanup -eq $null -or $Global:MRRCacheLastCleanup -lt (Get-Date).AddMinutes(-10).ToUniversalTime()) {
            if ($RemoveKeys = $Global:MRRCache.Keys | Where-Object {$_ -ne $keystr -and $Global:MRRCache.$_.last -lt (Get-Date).AddSeconds(-[Math]::Max(3600,$Global:MRRCache.$_.cachetime)).ToUniversalTime()} | Select-Object) {
                $RemoveKeys | Foreach-Object {$Global:MRRCache[$_] = $null; $Global:MRRCache.Remove($_)}
            }
            $Global:MRRCacheLastCleanup = (Get-Date).ToUniversalTime()
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Info "MiningRigRental cache cleanup: $($_.Exception.Message)"
    }
}

function Get-MiningRigRentalAlgorithm {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$Name
)
    Get-Algorithm $(Switch ($Name) {
            "x16rt"             {"Veil";Break}
            "x16rtgin"          {"X16rt";Break}
            "cuckoocycle"       {"Cuckarood29";Break}
            "equihash1505"      {"EquihashR25x5x3";Break}
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
            "cuckoocycle"       {"GRIN";Break}
            "cuckoocycle29swap" {"SWAP";Break}
            "equihash1505"      {"ATOMI";Break}
            "equihash1505g"     {"XGM";Break}
            default             {""}
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

    if ($Rigs_Ids = $id | Where-Object {-not $Global:MRRInfoCache.ContainsKey("$_")-or $Global:MRRInfoCache."$_".port -eq "error" -or $Global:MRRInfoCache."$_".updated -lt (Get-Date).AddHours(-24).ToUniversalTime()} | Sort-Object) {
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
    if (Test-Path Variable:Global:MRRStatus) {
        $RigKey = "$RigId"
        $Global:MRRStatus[$RigKey]
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
    [Switch]$Extend,
    [Parameter(Mandatory = $False)]
    [String]$Status = ""
)
    if (-not (Test-Path Variable:Global:MRRStatus)) {[hashtable]$Global:MRRStatus = @{}}
    $time = (Get-Date).ToUniversalTime()
    $RigKey = "$RigId"
    if ($Global:MRRStatus.ContainsKey($RigKey)) {
        if ($Stop) {$Global:MRRStatus.Remove($RigKey)}
        elseif ($Extend) {$Global:MRRStatus[$RigKey].extend = $true}
        elseif ($Status -eq "online") {$Global:MRRStatus[$RigKey].next = $time;$Global:MRRStatus[$RigKey].wait = $false;$Global:MRRStatus[$RigKey].enable = $true}
        elseif ($time -ge $Global:MRRStatus[$RigKey].next) {
            if ($Global:MRRStatus[$RigKey].wait) {$Global:MRRStatus[$RigKey].next = $time.AddMinutes(15);$Global:MRRStatus[$RigKey].wait = $Global:MRRStatus[$RigKey].enable = $false}
            else {$Global:MRRStatus[$RigKey].next = $time.AddMinutes(3);$Global:MRRStatus[$RigKey].wait = $Global:MRRStatus[$RigKey].enable = $true}
        }
    } else {$Global:MRRStatus[$RigKey] = [PSCustomObject]@{next = $time.AddMinutes(3); wait = $true; enable = $true; extend = $false}}
    
    if (-not $Stop) {$Global:MRRStatus[$RigKey].enable}
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
        Set-ContentJson ".\Data\mrrservers.json" -Data $Pool_Request.data > $null
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
    Invoke-MiningRigRentalRequest "/rig/mine" $key $secret -Cache $Cache | Where-Object description -match "\[($($workers -join '|'))\]"
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
    try {$PoolsData = Invoke-RestMethodAsync "https://rbminer.net/api/data/mrrpools.json" -Tag "MiningRigRentals" -cycletime 86400;Set-ContentJson -PathToFile ".\Data\mrrpools.json" -Data $PoolsData -Compress > $null} catch {if ($Error.Count){$Error.RemoveAt(0)};Write-Log -Level Warn "Rbminer.net/api/data/mrrpools.json could not be reached"}
    if (-not $PoolsData) {try {$PoolsData = Get-ContentByStreamReader ".\Data\mrrpools.json" | ConvertFrom-Json -ErrorAction Stop} catch {if ($Error.Count){$Error.RemoveAt(0)}}}
    if (-not $PoolsData) {$PoolsData = Get-Unzip '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' | ConvertFrom-Json}
    $PoolsData
}