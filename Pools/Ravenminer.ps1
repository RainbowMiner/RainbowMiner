using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Ravenminer_Regions = "eu", "us"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Ravenminer_Request = [PSCustomObject]@{}


$Success = $true
try {
    if (-not ($Ravenminer_Request = Invoke-RestMethod "https://eu.ravenminer.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop)){throw}
}
catch {
    $Success = $false
}

if ( -not $Success ) { 
    $Success = $true
    try {
        if (-not ($Ravenminer_Request = Invoke-RestMethod "https://ravenminer.com/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop)){throw}
    }
    catch {
        $Success = $false
    }
}

if ( -not $Success ) {
    $Success = $true
    try {
        $Ravenminer_Request = Invoke-WebRequest -UseBasicParsing "https://eu.ravenminer.com/site/current_results" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36" -TimeoutSec 10 -ErrorAction Stop
        if (-not ($Value = ([regex]'data="([\d\.]+?)"').Matches($Ravenminer_Request.Content).Groups | Where-Object Name -eq 1 | Select-Object -Last 1 -ExpandProperty Value)){throw}
        $Ravenminer_Request = [PSCustomObject]@{'x16r'=[PSCustomObject]@{actual_last24h = $Value;fees = 0;name = "x16r"}}
    }
    catch {
        $Success = $false
    }
}

if ( -not $Success ) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Ravenminer_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}


$Ravenminer_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Ravenminer_Request.$_.actual_last24h -gt 0} | ForEach-Object {
    $Ravenminer_Algorithm = $Ravenminer_Request.$_.name
    $Ravenminer_Algorithm_Norm = Get-Algorithm $Ravenminer_Algorithm
    $Ravenminer_Coin = "Ravencoin"
    $Ravenminer_Currency = "RVN"
    $Ravenminer_PoolFee = [Double]$Ravenminer_Request.$_.fees +8

    $Divisor = 1000000000

    switch ($Ravenminer_Algorithm_Norm) {
        "x16r" {$Divisor *= 1}
    }

    $Stat = Set-Stat -Name "$($Name)_$($Ravenminer_Algorithm_Norm)_Profit" -Value ([Double]$Ravenminer_Request.$_.actual_last24h / $Divisor) -Duration $StatSpan -ChangeDetection $false

    $Ravenminer_Regions | ForEach-Object {
        $Ravenminer_Region = $_
        $Ravenminer_Region_Norm = Get-Region $Ravenminer_Region

        if ( $Ravenminer_Region -eq "eu" -or $true ) { $Ravenminer_Host = "eu.ravenminer.com"; $Ravenminer_Port = 1111 }
        else { $Ravenminer_Host = "ravenminer.com"; $Ravenminer_Port = 6666 }

        [PSCustomObject]@{
            Algorithm     = $Ravenminer_Algorithm_Norm
            Info          = $Ravenminer_Coin
            Price         = $Stat.Hour # instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Ravenminer_Host
            Port          = $Ravenminer_Port
            User          = Get-Variable $Ravenminer_Currency -ValueOnly
            Pass          = "$Worker,c=$Ravenminer_Currency"
            Region        = $Ravenminer_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Ravenminer_PoolFee
        }
    }
}
