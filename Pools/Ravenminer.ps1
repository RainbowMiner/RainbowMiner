using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "avg",
    [Bool]$InfoOnly = $false
)

$Ravenminer_Regions = "eu", "us"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Ravenminer_Request = [PSCustomObject]@{}


$Success = $true
try {
    if (-not ($Ravenminer_Request = Invoke-RestMethodAsync "https://eu.ravenminer.com/api/status")){throw}
}
catch {
    $Success = $false
}

if ( -not $Success ) { 
    $Success = $true
    try {
        if (-not ($Ravenminer_Request = Invoke-RestMethodAsync "https://ravenminer.com/api/status")){throw}
    }
    catch {
        $Success = $false
    }
}

if ( -not $Success ) {
    $Success = $true
    try {
        $Ravenminer_Request = Invoke-WebRequestAsync "https://eu.ravenminer.com/site/current_results"
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
    $Ravenminer_Coin = Get-CoinName "Ravencoin"
    $Ravenminer_Currency = "RVN"
    $Ravenminer_PoolFee = [Double]$Ravenminer_Request.$_.fees

    $Divisor = 1000000000

    switch ($Ravenminer_Algorithm_Norm) {
        "x16r" {$Divisor *= 1}
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Ravenminer_Algorithm_Norm)_Profit" -Value ((Get-YiiMPValue $Ravenminer_Request.$_ $DataWindow) / $Divisor) -Duration $StatSpan -ChangeDetection $false
    }

    $Ravenminer_Regions | ForEach-Object {
        $Ravenminer_Region = $_
        $Ravenminer_Region_Norm = Get-Region $Ravenminer_Region

        if ( $Ravenminer_Region -eq "eu" -or $true ) { $Ravenminer_Host = "eu.ravenminer.com"; $Ravenminer_Port = 1111 }
        else { $Ravenminer_Host = "ravenminer.com"; $Ravenminer_Port = 6666 }

        [PSCustomObject]@{
            Algorithm     = $Ravenminer_Algorithm_Norm
            CoinName      = $Ravenminer_Coin
            Currency      = $Ravenminer_Currency
            Price         = $Stat.Hour # instead of .Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $Ravenminer_Host
            Port          = $Ravenminer_Port
            User          = Get-Variable $Ravenminer_Currency -ValueOnly -ErrorAction SilentlyContinue
            Pass          = "$Worker,c=$Ravenminer_Currency"
            Region        = $Ravenminer_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $Ravenminer_PoolFee
            UsesDataWindow = $True
        }
    }
}
