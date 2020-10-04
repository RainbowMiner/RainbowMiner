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
            $Default = [PSCustomObject]@{UseWorkerName="";ExcludeWorkerName="";EnableAutoCreate="";AutoCreateMinProfitPercent="";AutoCreateMinProfitBTC="";AutoCreateMaxMinHours="";AutoUpdateMinPriceChangePercent="";AutoCreateAlgorithm="";EnableAutoUpdate="";EnableAutoExtend="";AutoExtendTargetPercent="";AutoExtendMaximumPercent="";AutoBonusExtendForHours="";AutoBonusExtendByHours="";EnableAutoPrice="";EnableMinimumPrice="";EnableUpdateTitle="";EnableUpdateDescription="";EnableUpdatePriceModifier="";EnablePowerDrawAddOnly="";AutoPriceModifierPercent="";PriceBTC="";PriceFactor="";PowerDrawFactor="";MinHours="";MaxHours="";AllowExtensions="";PriceCurrencies="";Title = "";Description = "";ProfitAverageTime = ""}
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

       if (-not $ForceLocal -and $Session.Config.RunMode -eq "Client" -and $Session.Config.ServerName -and $Session.Config.ServerPort -and (Test-TcpServer $Session.Config.ServerName -Port $Session.Config.ServerPort -Timeout 2)) {
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
            "cuckaroo24"        {"Cuckaroom29";Break}
            "cuckoocycle"       {"Cuckarood29";Break}
            "equihash1505"      {"BeamHash3";Break}
            "x16rt"             {"Veil";Break}
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
        $DataSorted | ConvertTo-Json -ErrorAction Stop | Set-Content $Path
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
    [String]$Status = ""
)
    if (-not (Test-Path Variable:Global:MRRStatus)) {[hashtable]$Global:MRRStatus = @{}}
    $time = (Get-Date).ToUniversalTime()
    $RigKey = "$RigId"
    if ($Global:MRRStatus.ContainsKey($RigKey)) {
        if ($Stop) {$Global:MRRStatus.Remove($RigKey)}
        elseif ($Status -eq "extended") {$Global:MRRStatus[$RigKey].extended = $true}
        elseif ($Status -eq "notextended") {$Global:MRRStatus[$RigKey].extended = $false}
        elseif ($Status -eq "online") {$Global:MRRStatus[$RigKey].next = $time;$Global:MRRStatus[$RigKey].wait = $false;$Global:MRRStatus[$RigKey].enable = $true}
        elseif ($time -ge $Global:MRRStatus[$RigKey].next) {
            if ($Global:MRRStatus[$RigKey].wait) {$Global:MRRStatus[$RigKey].next = $time.AddMinutes(15);$Global:MRRStatus[$RigKey].wait = $Global:MRRStatus[$RigKey].enable = $false}
            else {$Global:MRRStatus[$RigKey].next = $time.AddMinutes(3);$Global:MRRStatus[$RigKey].wait = $Global:MRRStatus[$RigKey].enable = $true}
        }
    } else {$Global:MRRStatus[$RigKey] = [PSCustomObject]@{next = $time.AddMinutes(3); wait = $true; enable = $true; extended = $(if ($Status -eq "extended") {$true} else {$false})}}
    
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