using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$API_ID = "",
    [String]$API_Key = ""
)

if (-not $API_ID -or -not $API_Key) {return}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 3

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

function Get-XRequest {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String]$base,
    [Parameter(Mandatory = $True)]
    [String]$endpoint,
    [Parameter(Mandatory = $True)]
    [String]$key,
    [Parameter(Mandatory = $True)]
    [String]$secret
)
    $nonce = Get-UnixTimestamp
    $str = "$key$nonce$endpoint"
    $sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create("HMACSHA1")
    $sha.key = [System.Text.Encoding]::UTF8.Getbytes($secret)
    $sign = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${str})))    
    $headers = [hashtable]@{
	    'x-api-sign' = ($sign -replace '\-').ToLower()
	    'x-api-key'  = $key
	    'x-api-nonce'= $nonce
    }
    try {
        $Request = Invoke-RestMethod "$base$endpoint" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop -Headers $headers
    } catch {
    }
    if ($Request -and $Request.success) {$Request.data}
}

$Rigs_Request = Get-XRequest $Pool_ApiBase "/rig/mine" $API_ID $API_Key
if ($Rigs_Request) {
    $RigInfo_Request = Get-XRequest $Pool_ApiBase "/rig/$($Rigs_Request.id -join ';')/port" $API_ID $API_Key
}

if (-not $Rigs_Request -or -not $RigInfo_Request) {
    Write-Log -Level Warn "Pool API ($Name) rig request has failed. "
    return
}

$Rigs_Request | Where-Object {@("available","rented") -icontains $_.available_status} | ForEach-Object {
    $Pool_RigId = $_.id
    $Pool_Algorithm = $_.type
    $Pool_Algorithm_Norm = Get-Algorithm $_.type
    $Pool_User = $Wallets.$Pool_Algorithm_Norm

    $Pool_Price = $Pool_Request | Where-Object name -eq $Pool_Algorithm

    Switch (($Pool_Price.suggested_price.unit -split "\*")[0]) {
        "kh" {$Divisor = 1e3}
        "mh" {$Divisor = 1e6}
        "gh" {$Divisor = 1e9}
        "th" {$Divisor = 1e12}
        default {$Divisor = 1}
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_Price.suggested_price.amount / $Divisor) -Duration $StatSpan -ChangeDetection $true
    }

    $Pool_Rig = $RigInfo_Request | Where-Object rigid -eq $Pool_RigId

    if ($Pool_Rig) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = ""
            CoinSymbol    = ""
            Currency      = "BTC"
            Price         = $Stat.Minute_10 #instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Pool_Rig.server
            Port          = $Pool_Rig.port
            User          = $Worker
            Pass          = "x"
            Region        = $Pool_Regions."$($_.region)"
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Exclusive     = $_.available_status -eq "rented"
        }
    }
}
