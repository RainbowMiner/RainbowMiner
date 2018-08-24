using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false
)

$Pool_Regions = "eu", "us"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Request = [PSCustomObject]@{}


$Success = $true
try {
    if (-not ($Pool_Request = Invoke-RestMethodAsync "https://eu.ravenminer.com/api/status")){throw}
}
catch {
    $Success = $false
}

if ( -not $Success ) { 
    $Success = $true
    try {
        if (-not ($Pool_Request = Invoke-RestMethodAsync "https://ravenminer.com/api/status")){throw}
    }
    catch {
        $Success = $false
    }
}

if ( -not $Success ) {
    $Success = $true
    try {
        $Pool_Request = Invoke-WebRequestAsync "https://eu.ravenminer.com/site/current_results"
        if (-not ($Value = ([regex]'data="([\d\.]+?)"').Matches($Pool_Request.Content).Groups | Where-Object Name -eq 1 | Select-Object -Last 1 -ExpandProperty Value)){throw}
        $Pool_Request = [PSCustomObject]@{'x16r'=[PSCustomObject]@{actual_last24h = $Value;fees = 0.5;name = "x16r"}}
        $DataWindow = "actual_last24h"
    }
    catch {
        $Success = $false
    }
}

if ( -not $Success ) {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -lt 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$Pool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$Pool_Request.$_.actual_last24h -gt 0 -or $InfoOnly} | ForEach-Object {
    $Pool_Algorithm = $Pool_Request.$_.name
    $Pool_Algorithm_Norm = Get-Algorithm $Pool_Algorithm
    $Pool_Coin = "Ravencoin"
    $Pool_Currency = "RVN"
    $Pool_PoolFee = [Double]$Pool_Request.$_.fees

    $Divisor = 1e6

    switch ($Pool_Algorithm_Norm) {
        "x16r" {$Divisor *= 1}
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $Pool_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $false
    }

    $Pool_Regions | ForEach-Object {
        $Pool_Region = $_
        $Pool_Region_Norm = Get-Region $Pool_Region

        if ( $Pool_Region -eq "eu" -or $true ) { $Pool_Host = "eu.ravenminer.com"; $Pool_Port = 1111 }
        else { $Pool_Host = "ravenminer.com"; $Pool_Port = 6666 }

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
            User          = Get-Variable $Pool_Currency -ValueOnly -ErrorAction SilentlyContinue
            Pass          = "$Worker,c=$Pool_Currency"
            Region        = $Pool_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Pool_PoolFee
            UsesDataWindow = $True
        }
    }
}
