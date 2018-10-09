using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}

$Success = $true
try {
    if (-not ($Pool_Request = Invoke-RestMethodAsync "https://ravenminer.com/api/status" -tag $Name)){throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success = $false
}

if (-not $Success) {
    $Success = $true
    try {
        $Pool_Request = Invoke-GetUrl "https://ravenminer.com/site/current_results" -method "WEB"
        $Value_Group = ([regex]'data="([\d\.]+?)"').Matches($Pool_Request.Content).Groups | Where-Object Name -eq 1
        if (-not ($Value = $Value_Group | Select-Object -Last 1 -ExpandProperty Value)){throw}
        $Hashrate = $Value_Group | Select-Object -First 1 -ExpandProperty Value
        $Pool_Request = [PSCustomObject]@{'x16r'=[PSCustomObject]@{actual_last24h = $Value;hashrate = $Hashrate;fees = 0.5;name = "x16r";port = 1111}}
        $DataWindow = "actual_last24h"
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Success = $false
    }
}

if (-not $Success) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    if (-not ($PoolCoins_Request = Invoke-RestMethodAsync "https://ravenminer.com/api/currencies" -tag $Name)){throw}
}
catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Success = $false
}

if (-not $Success) {
    $Success = $true
    try {
        $PoolCoins_Request = Invoke-GetUrl "https://ravenminer.com/site/history_results" -method "WEB"
        $Value_Content = $PoolCoins_Request.Content -split "</thead>" | Select-Object -Last 1
        $Value_Content = $Value_Content -split "</tr>" | Select-Object -First 1        
        $Value_Content = ([regex]">([\d\.]+?)<").Matches($Value_Content)
        if ($Value_Content.Count -ge 2) {
            $PoolCoins_Request = [PSCustomObject]@{RVN=[PSCustomObject]@{"24h_blocks" = $Value_Content[1].Groups[1].Value}}
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        $Success = $false
    }
}

$Pool_Coin = "Ravencoin"
$Pool_Currency = "RVN"
$Pool_Host = "ravenminer.com"
$Pool_Region = Get-Region "us"

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_Request.$_.actual_last24h -gt 0 -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $Pool_Request.$_.name
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees
    $Pool_User = $Wallets.$Pool_Currency
    $Pool_Port = 6666

    $Pool_Factor = 1

    if (-not $InfoOnly) {
        if (-not (Test-Path "Stats\Pools\$($Name)_$($Pool_Algorithm_Norm)_Profit.txt")) {$Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value (Get-YiiMPValue $Pool_Request.$_ -DataWindow "estimate_last24h" -Factor $Pool_Factor) -Duration (New-TimeSpan -Days 1)}
        else {$Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value (Get-YiiMPValue $Pool_Request.$_ -DataWindow $DataWindow -Factor $Pool_Factor) -Duration $StatSpan -ChangeDetection $false}
        $StatHSR = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_HSR" -Value ([Int64]$Pool_Request.$_.hashrate) -Duration $StatSpan -ChangeDetection $false
        $StatTTF = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_TTF" -Value ([Double]$PoolCoins_Request.$Pool_Currency."24h_blocks" / 24 * 60) -Duration $StatSpan -ChangeDetection $false
    }

    if ($Pool_User -or $InfoOnly) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $Pool_Coin
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = $Stat.Hour # instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Pool_Host
            Port          = $Pool_Port
            User          = $Pool_User
            Pass          = "$Worker,c=$Pool_Currency"
            Region        = $Pool_Region
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            DataWindow    = $DataWindow
            Hashrate      = $StatHSR.Hour
            TTF           = $StatTTF.Hour
        }
    }
}
