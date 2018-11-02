using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [Bool]$EnableMining = $false,
    [String]$API_Key = "",
    [String]$API_Secret = "",
    [String]$User = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 3

if ($InfoOnly) {
    [PSCustomObject]@{
        Algorithm     = $Pool_Algorithm_Norm
        CoinName      = ""
        CoinSymbol    = ""
        Currency      = "BTC"
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "stratum+tcp"
        PoolFee       = $Pool_Fee
    }
    return
}

if (-not $API_Key -or -not $API_Secret) {return}

$Pool_Request = [PSCustomObject]@{}

$Pool_ApiBase = "https://www.miningrigrentals.com/api/v2"

try {
    $Pool_Request = Invoke-RestMethodAsync "$Pool_ApiBase/info/algos" -tag $Name
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
$Pool_Request = $Pool_Request.data

[hashtable]$Pool_Regions = @{
    "eu"   = Get-Region "eu"
    "us"   = Get-Region "us"
    "asia" = Get-Region "asia"
    "ru"   = Get-Region "ru"
}

$Pool_AllHosts = @("us-east01.miningrigrentals.com","us-west01.miningrigrentals.com","us-central01.miningrigrentals.com",
                   "eu-01.miningrigrentals.com","eu-de01.miningrigrentals.com","eu-de02.miningrigrentals.com",
                   "eu-ru01.miningrigrentals.com",
                   "ap-01.miningrigrentals.com")

function Invoke-MiningRigRentalRequest {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$base,
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret,
    [Parameter(Mandatory = $False)]
    $params = @{},
    [Parameter(Mandatory = $False)]
    [String]$method = "GET"
)
    $nonce = (Get-UnixTimestamp)+5000
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
        $Request = Invoke-RestMethod "$base$endpoint" -UseBasicParsing -UserAgent $ua -TimeoutSec 10 -ErrorAction Stop -Headers $headers -Method $method -Body $body
    } catch {
    }
    if ($Request -and $Request.success) {$Request.data}
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

$Rigs_Request = Invoke-MiningRigRentalRequest $Pool_ApiBase "/rig/mine" $API_Key $API_Secret | Where-Object description -match "\[$($Worker)\]"

if (-not $Rigs_Request) {
    Write-Log -Level Warn "Pool API ($Name) rig $Worker request has failed. "
    return
}

if (($Rigs_Request | Where-Object {$_.status.status -eq "rented"} | Measure-Object).Count) {
    if ($Disable_Rigs = $Rigs_Request | Where-Object {$_.status.status -ne "rented" -and $_.available_status -eq "available"} | Select-Object -ExpandProperty id) {
        Invoke-MiningRigRentalRequest $Pool_ApiBase "/rig/$($Disable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="disabled"} -method "PUT" >$null
        $Rigs_Request | Where-Object {$Disable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="disabled"}
    }
} else {
    if ($Enable_Rigs = $Rigs_Request | Where-Object {$_.available_status -ne "available"} | Select-Object -ExpandProperty id) {
        Invoke-MiningRigRentalRequest $Pool_ApiBase "/rig/$($Enable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="available"} -method "PUT" >$null
        $Rigs_Request | Where-Object {$Enable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="available"}
    }    
}

$RigInfo_Request = Invoke-MiningRigRentalRequest $Pool_ApiBase "/rig/$(($Rigs_Request | Where-Object {$_.available_status -eq "available"} | Select-Object -ExpandProperty id) -join ';')/port" $API_Key $API_Secret
if (-not $RigInfo_Request) {
    Write-Log -Level Warn "Pool API ($Name) rig $Worker info request has failed. "
    return
}

$Rigs_Request | Where-Object {$_.available_status -eq "available"} | ForEach-Object {
    $Pool_RigId = $_.id
    $Pool_Algorithm = $_.type
    $Pool_Algorithm_Norm = Get-Algorithm $_.type

    if ($false) {
        $Pool_Price_Data = ($Pool_Request | Where-Object name -eq $Pool_Algorithm).stats.prices.last_10 #suggested_price
        $Divisor = Get-MiningRigRentalsDivisor $Pool_Price_Data.unit
        $Pool_Price = $Pool_Price_Data.amount
    } else {
        $Divisor = Get-MiningRigRentalsDivisor $_.price.type
        $Pool_Price = $_.price.BTC.price
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_Price / $Divisor) -Duration $StatSpan -ChangeDetection $false -Quiet
    }

    $Pool_Rig = $RigInfo_Request | Where-Object rigid -eq $Pool_RigId

    if ($Pool_Rig) {
        if ($_.status.status -eq "rented" -or $_.poolstatus -eq "online") {
            $Pool_Failover = $Pool_AllHosts | Where-Object {$_ -ne $Pool_Rig.Server -and $_ -match "^$($Pool_Rig.Server.SubString(0,2))"} | Select-Object -First 2
            if (-not $Pool_Failover) {$Pool_Failover = @($Pool_AllHosts | Where-Object {$_ -ne $Pool_Rig.Server -and $_ -match "^us"} | Select-Object -First 1) + @($Pool_AllHosts | Where-Object {$_ -ne $Pool_Rig.Server -and $_ -match "^eu"} | Select-Object -First 1)}
            
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = if ($_.status.status -eq "rented") {"$($_.status.hours)h"} else {""}
                CoinSymbol    = ""
                Currency      = "BTC"
                Price         = $Stat.Minute_10 #instead of .Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $Pool_Rig.server
                Port          = $Pool_Rig.port
                User          = "$($User).$($Pool_RigId)"
                Pass          = "x"
                Region        = $Pool_Regions."$($_.region)"
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $Pool_Fee
                Exclusive     = $_.status.status -eq "rented"
                Idle          = if ($_.status.status -eq "rented") {$false} else {-not $EnableMining}
                Failover      = @($Pool_Failover | Foreach-Object {
                    [PSCustomObject]@{
                        Protocol = "stratum+tcp"
                        Host     = $_
                        Port     = $Pool_Rig.port
                        User     = "$($User).$($Pool_RigId)"
                        Pass     = "x"
                    }
                })
            }
        }

        if ($_.status.status -ne "rented") {if (-not (Invoke-PingStratum -Server $Pool_Rig.server -Port $Pool_Rig.port)) {$Pool_Failover | Foreach-Object {if (Invoke-PingStratum -Server $_ -Port $Pool_Rig.port) {return}}}}
    }
}
