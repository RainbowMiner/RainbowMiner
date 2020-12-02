using module .\Modules\PingStratum.psm1

$args.Where({$_.Data.Server -and $_.Data.Port}).Foreach({
    $Data = $_.Data
    if ($Data.Method -eq "EthProxy") {$Data.WaitForResponse = $true}
    if (-not (Invoke-PingStratum @Data)) {
        if ($Data.Method -eq "EthProxy") {
            $Data.Method = "Stratum"
            Invoke-PingStratum @Data > $null
        }
    }
})