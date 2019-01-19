using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
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

$Rigs_Request = Invoke-MiningRigRentalRequest "/rig/mine" $API_Key $API_Secret | Where-Object description -match "\[$($Worker)\]"

if (-not $Rigs_Request) {return}

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

if (($Rigs_Request | Where-Object {$_.status.status -eq "rented"} | Measure-Object).Count) {
    if ($Disable_Rigs = $Rigs_Request | Where-Object {$_.status.status -ne "rented" -and $_.available_status -eq "available"} | Select-Object -ExpandProperty id) {
        Invoke-MiningRigRentalRequest "/rig/$($Disable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="disabled"} -method "PUT" >$null
        $Rigs_Request | Where-Object {$Disable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="disabled"}
        $Disable_Rigs | Foreach-Object {Set-MiningRigRentalStatus $_ -Stop}
    }
} else {
    if ($Enable_Rigs = $Rigs_Request | Where-Object {$_.available_status -ne "available"} | Select-Object -ExpandProperty id) {
        Invoke-MiningRigRentalRequest "/rig/$($Enable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="available"} -method "PUT" >$null
        $Rigs_Request | Where-Object {$Enable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="available"}
    }
    $Rigs_Request | Foreach-Object {Set-MiningRigRentalStatus $_.id -Stop}
}

$RigInfo_Request = @(Invoke-MiningRigRentalRequest "/rig/$(($Rigs_Request | Where-Object {$_.available_status -eq "available"} | Select-Object -ExpandProperty id | Sort-Object) -join ';')/port" $API_Key $API_Secret -Timeout 20 -Cache 3600 | Select-Object)
if (-not $RigInfo_Request) {
    Write-Log -Level Warn "Pool API ($Name) rig $Worker info request has failed. "
    return
}

$NewRigs = Compare-Object @($Rigs_Request | Where-Object {$_.available_status -eq "available"} | Select-Object -ExpandProperty id) @($RigInfo_Request | Select-Object -ExpandProperty rigid) | Where-Object {$_.SideIndicator -eq "<="} | Select-Object -ExpandProperty InputObject
if ($NewRigs -and $NewRigs.Count) {
    $NewRigInfo_Request = Invoke-MiningRigRentalRequest "/rig/$(($NewRigs | Sort-Object) -join ';')/port" $API_Key $API_Secret -Timeout 20
    $NewRigInfo_Request | Foreach-Object {$RigInfo_Request += $_}
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
        $Pool_Price = $Stat.$StatAverage
        if ($_.status.status -eq "rented") {
            try {
                $Pool_RigRental = Invoke-MiningRigRentalRequest "/rental" $API_Key $API_Secret -params (@{type="owner";"rig"=$Pool_RigId;history=$false;limit=1}) -Cache $([double]$_.status.hours*3600)
                if ($Rig_RentalPrice = [Double]$Pool_RigRental.rentals.price.advertised / 1e6) {
                    $Pool_Price = $Rig_RentalPrice
                    if ($Pool_RigRental.rentals.price.currency -ne "BTC") {$Pool_Price *= $_.price.BTC.price/$_.price.LTC.price}
                }
            } catch {}
        }

        $Pool_RigEnable = if ($_.status.status -eq "rented") {Set-MiningRigRentalStatus $Pool_RigId -Status $_.poolstatus}
        if ($_.status.status -eq "rented" -or $_.poolstatus -eq "online" -or $EnableMining) {
            $Pool_Failover = $Pool_AllHosts | Where-Object {$_ -ne $Pool_Rig.Server -and $_ -match "^$($Pool_Rig.Server.SubString(0,2))"} | Select-Object -First 2
            if (-not $Pool_Failover) {$Pool_Failover = @($Pool_AllHosts | Where-Object {$_ -ne $Pool_Rig.Server -and $_ -match "^us"} | Select-Object -First 1) + @($Pool_AllHosts | Where-Object {$_ -ne $Pool_Rig.Server -and $_ -match "^eu"} | Select-Object -First 1)}
            
            [PSCustomObject]@{
                Algorithm     = $Pool_Algorithm_Norm
                CoinName      = if ($_.status.status -eq "rented") {try {$ts=[timespan]::fromhours($_.status.hours);"{0:00}h{1:00}m{2:00}s" -f [Math]::Floor($ts.TotalHours),$ts.Minutes,$ts.Seconds}catch{"$($_.status.hours)h"}} else {""}
                CoinSymbol    = ""
                Currency      = "BTC"
                Price         = $Pool_Price
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
                Exclusive     = $_.status.status -eq "rented" -and $Pool_RigEnable
                Idle          = if ($_.status.status -eq "rented" -and $Pool_RigEnable) {$false} else {-not $EnableMining}
                Failover      = @($Pool_Failover | Select-Object | Foreach-Object {
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

        if (-not $Pool_RigEnable) {
            if (-not (Invoke-PingStratum -Server $Pool_Rig.server -Port $Pool_Rig.port -User "$($User).$($Pool_RigId)" -Pass "x" -Worker $Worker -Method $(if ($Pool_Rig.port -eq 3333 -or $Pool_Rig.port -eq 3344) {"EthProxy"} else {"Stratum"}) -WaitForResponse ($_.status.status -eq "rented"))) {
                $Pool_Failover | Select-Object | Foreach-Object {if (Invoke-PingStratum -Server $_ -Port $Pool_Rig.port -User "$($User).$($Pool_RigId)" -Pass "x" -Worker $Worker -Method $(if ($Pool_Rig.port -eq 3333 -or $Pool_Rig.port -eq 3344) {"EthProxy"} else {"Stratum"}) -WaitForResponse ($_.status.status -eq "rented")) {return}}
            }
        }
    }
}
