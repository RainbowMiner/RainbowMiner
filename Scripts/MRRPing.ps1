using module .\Modules\PingStratum.psm1

$args.Where({$_.Data.Server -and $_.Data.Port}).Foreach({
    $Data = $_.Data
    if ($Data.Method -eq "EthProxy") {$Data.WaitForResponse = $true}
    if (-not (Invoke-PingStratum -Server $Data.Server -Port $Data.Port -Worker $Data.Worker -User $Data.User -Pass $Data.Pass -WaitForResponse $Data.WaitForResponse -Method $Data.Method)) {
        if ($Data.Method -eq "EthProxy") {
            $Data.Method = "Stratum"
            Invoke-PingStratum -Server $Data.Server -Port $Data.Port -Worker $Data.Worker -User $Data.User -Pass $Data.Pass -WaitForResponse $Data.WaitForResponse -Method $Data.Method > $null
        }
    }
})
