Set-Location (Split-Path $MyInvocation.MyCommand.Path)

function Set-MiningRigRentalConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $False)]
        $Data = $null
    )
    $ConfigName = "MRR"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path
    if ($Force -or -not (Test-Path $PathToFile) -or $Data -or (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime() -lt (Get-ChildItem ".\Data\MRRConfigDefault.ps1").LastWriteTime.ToUniversalTime()) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $ChangeTag = Get-ContentDataMD5hash($Preset)
            $Default = [PSCustomObject]@{PriceStrategy="mrr";PriceBTC = "0";PriceFactor = "0";MinPriceStrategy="profit";MinPriceBTC = "0";MinPriceFactor = "30";EnablePriceUpdates = "1";Title="";Description=""}
            $Setup = Get-ChildItemContent ".\Data\MRRConfigDefault.ps1" | Select-Object -ExpandProperty Content

            #price strategies
            # profit = use rig's avergage profit as price
            # static = use PriceBTC/MinPriceBTC as price
            # mrr    = use MiningRigRental's suggested_price
            
            foreach ($Algorithm_Norm in @(@($Setup.PSObject.Properties.Name | Select-Object) + @($Data | Where-Object {$_} | Foreach-Object {Get-MiningRigRentalAlgorithm $_.name}) | Select-Object -Unique)) {
                if (-not $Preset.$Algorithm_Norm) {$Preset | Add-Member $Algorithm_Norm $(if ($Setup.$Algorithm_Norm) {$Setup.$Algorithm_Norm} else {[PSCustomObject]@{}}) -Force}
            }

            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {                
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$_.$SetupName -eq $null){$Preset.$_ | Add-Member $SetupName $Default.$SetupName -Force}}
                $Sorted | Add-Member $_ $Preset.$_ -Force
            }
            Set-ContentJson -PathToFile $PathToFile -Data $Sorted -MD5hash $ChangeTag > $null
            $Session.ConfigFiles[$ConfigName].Healthy = $true
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
    $keystr = Get-MD5Hash "$($endpoint)$($params | ConvertTo-Json -Depth 10 -Compress)"
    if (-not (Test-Path Variable:Global:MRRCache)) {$Global:MRRCache = [hashtable]::Synchronized(@{})}
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
            Remove-Variable "Result" -ErrorAction Ignore -Force
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
                    "PUT" {$params | ConvertTo-Json -Depth 10}
                    "GET" {if ($params.Count) {$params} else {$null}}
                }
                #Write-Log -Level Info "MiningRigRental call: $($endpoint)"
                $Request = Invoke-RestMethod "$base$endpoint" -UseBasicParsing -UserAgent $ua -TimeoutSec $Timeout -ErrorAction Stop -Headers $headers -Method $method -Body $body
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Info "MiningRigRental call: $($_.Exception.Message)"
            }
        }
        if ($Request.success -ne $null -and -not $Request.success) {
            Write-Log -Level Warn "MiningRigRental error: $(if ($Request.data.message) {$Request.data.message} else {"unknown"})"
        }

        if (-not $Global:MRRCache[$keystr] -or ($Request -and $Request.success)) {
            $Global:MRRCache[$keystr] = [PSCustomObject]@{last = (Get-Date).ToUniversalTime(); request = $Request}
        }
    }
    if ($Raw) {$Global:MRRCache[$keystr].request}
    else {
        if ($Global:MRRCache[$keystr].request -and $Global:MRRCache[$keystr].request.success) {$Global:MRRCache[$keystr].request.data}
    }
}

function Get-MiningRigRentalAlgorithm {
[cmdletbinding()]   
param(    
    [Parameter(Mandatory = $True)]
    [String]$Name
)
    Get-Algorithm $(Switch ($Name) {
            "x16rt"             {"Veil"}
            "x16rtgin"          {"X16rt"}
            "cuckoocycle"       {"Cuckarood29"}
            "cuckoocycleo"      {"Cuckaroo29"}
            "cuckoocycle29swap" {"Cuckaroo29s"}
            "cuckoocycle31"     {"Cuckatoo31"}
            "equihash1505"      {"EquihashR25x5x3"}
            "hashimotos"        {"Ethash"}
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
            "cuckoocycle"       {"GRIN"}
            "cuckoocycle29swap" {"SWAP"}
            "equihash1505"      {"BEAM"}
            "equihash1505g"     {"GRIMM"}
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
        $Global:MRRInfoCache = [hashtable]::Synchronized(@{})
        if (Test-Path ".\Data\mrrinfo.json") {
            try {
                $MrrInfo = Get-Content ".\Data\mrrinfo.json" -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                $MrrInfo = @()
            }
            $MrrInfo | Foreach-Object {$MrrInfoCache[$_.rigid] = $_}
        }
    }

    if ($Rigs_Ids = $id | Where-Object {-not $MrrInfoCache.ContainsKey($_) -or $MrrInfoCache.$_.updated -lt (Get-Date).AddHours(-24).ToUniversalTime()}) {
        $Updated = 0
        @(Invoke-MiningRigRentalRequest "/rig/$($Rigs_Ids -join ";")/port" $key $secret -Timeout 60 | Select-Object) | Foreach-Object {
            $MrrInfoCache[$_.rigid] = $_ | Add-Member updated (Get-Date).ToUniversalTime() -Force -PassThru
            $Updated++
        }
        if ($Updated) {Set-ContentJson -PathToFile ".\Data\mrrinfo.json" -Data $MrrInfoCache.Values -Compress > $null}
    }
    $id | Where-Object {$MrrInfoCache.ContainsKey($_)} | Foreach-Object {$MrrInfoCache.$_}
}

function Get-MiningRigRentalsDivisor {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$unit
)
    Switch (($unit -split "\*")[0]) {
        "kh" {1e3}
        "mh" {1e6}
        "gh" {1e9}
        "th" {1e12}
        default {1}
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
    if (-not (Test-Path Variable:Global:MRRStatus)) {$Global:MRRStatus = [hashtable]::Synchronized(@{})}
    $time = (Get-Date).ToUniversalTime()
    if ($MRRStatus.ContainsKey($RigId)) {
        if ($Stop) {$MRRStatus.Remove($RigId)}
        elseif ($Status -eq "online") {$MRRStatus[$RigId].next = $time;$MRRStatus[$RigId].wait = $false;$MRRStatus[$RigId].enable = $true}
        elseif ($time -ge $MRRStatus[$RigId].next) {
            if ($MRRStatus[$RigId].wait) {$MRRStatus[$RigId].next = $time.AddMinutes(15);$MRRStatus[$RigId].wait = $MRRStatus[$RigId].enable = $false}
            else {$MRRStatus[$RigId].next = $time.AddMinutes(3);$MRRStatus[$RigId].wait = $MRRStatus[$RigId].enable = $true}
        }
    } else {$MRRStatus[$RigId] = [PSCustomObject]@{next = $time.AddMinutes(3); wait = $true; enable = $true}}
    if (-not $Stop) {$MRRStatus[$RigId].enable}
}

function Get-MiningRigRentalAlgos {
    $Name = "MiningRigRentals"

    try {
        $Pool_Request = Invoke-RestMethodAsync "https://www.miningrigrentals.com/api/v2/info/algos" -tag $Name -cycletime 120
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Warn "Pool API ($Name) has failed. "
        return
    }

    if (-not $Pool_Request.success) {
        Write-Log -Level Warn "Pool API ($Name) returned nothing. "
        return
    }

    $Pool_Request.data
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
    [Int]$Cache = 55
)
    Invoke-MiningRigRentalRequest "/rig/mine" $key $secret -Cache $Cache | Where-Object description -match "\[($($workers -join '|'))\]"
}

function Update-MiningRigRentalRigs {
    Write-Host "Not implemented"
}

function Invoke-MiningRigRentalCreateRigs {
    Write-Host "Not implemented"
}

function Invoke-MiningRigRentalUpdatePrices {
    Write-Host "Not implemented"
    return

    $MRRActual = (Get-ConfigContent "Pools").MiningRigRentals
    $MRRActual.Worker = $MRRActual.Worker -replace "^\`$.+"
    if (-not $MRRActual.Worker) {$MRRActual.Worker = $Session.Config.WorkerName}

    if (-not $MRRActual.API_Key -or -not $MRRActual.API_Secret -or -not (Test-Config "Pools" -Health)) {return}

    $MRRActual.PSObject.Properties | Foreach-Object {
        $Rec = $_
        if ($Rec.Name -match "^(Allow|Enable)" -and $Rec.Value -isnot [bool]) {
            $MRRActual | Add-Member $Rec.Name (Get-Yes $Rec.Value) -Force
        } elseif ($Rec.Name -match "(Algorithm|Coin|Miner|Currencies)" -and $Rec.Value -is [string]) {
            $MRRActual | Add-Member $Rec.Name (Get-ConfigArray $Rec.Value) -Force
        } elseif ($Rec.Name -match "^Price" -and $Rec.Value -isnot [double]) {
            $MRRActual | Add-Member $Rec.Name ([double]$MRRActual.Value) -Force
        }
    }

    $AllMRRConfig = Get-ConfigContent "MRR" -UpdateLastWriteTime
    if (Test-Config "MRR" -Health) {
        $MRRActual | Add-Member Algorithms ([PSCustomObject]@{}) -Force
        $AllMRRConfig.PSObject.Properties.Name | Foreach-Object {
            $m = $_
            $MRRActual.Algorithms | Add-Member $m $AllMRRConfig.$m -Force
            $MRRActual.Algorithms.$m | Add-Member EnableAutoCreate ($MRRActual.EnableAutoCreate -and (Get-Yes $MRRActual.Algorithms.$m.EnableAutoCreate)) -Force
            $MRRActual.Algorithms.$m | Add-Member EnablePriceUpdates ($MRRActual.EnablePriceUpdates -and (Get-Yes $MRRActual.Algorithms.$m.EnablePriceUpdates)) -Force
            $MRRActual.Algorithms.$m | Add-Member EnableAutoPrice ($MRRActual.EnableAutoPrice -and (Get-Yes $MRRActual.Algorithms.$m.EnableAutoPrice)) -Force
            $MRRActual.Algorithms.$m | Add-Member EnableMinimumPrice ($MRRActual.EnableMinimumPrice -and (Get-Yes $MRRActual.Algorithms.$m.EnableMinimumPrice)) -Force
            $MRRActual.Algorithms.$m | Add-Member PriceBTC ([double]$MRRActual.Algorithms.$m.PriceBTC) -Force
            $MRRActual.Algorithms.$m | Add-Member PriceFactor ([double]$MRRActual.Algorithms.$m.PriceFactor) -Force
            if (-not $MRRActual.Algorithms.$m.PriceBTC) {$MRRActual.Algorithms.$m.PriceBTC = $MRRActual.PriceBTC}
            if (-not $MRRActual.Algorithms.$m.PriceFactor) {$MRRActual.Algorithms.$m.PriceFactor = $MRRActual.PriceFactor}
        }
    }
    if ($AllMRRConfig) {Remove-Variable "AllMRRConfig" -Force}

    $Models = Get-Device (Get-ConfigArray $Session.Config.DeviceName) | Select-Object -ExpandProperty Model | Select-Object -Unique | Sort-Object

    $DevicesActual = Get-ConfigContent "Devices"
}
