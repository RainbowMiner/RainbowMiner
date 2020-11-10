using module .\Modules\PingStratum.psm1

$args.Where({$_.Data.Server}).Foreach({
    $Data = $_.Data
    if (-not (Invoke-PingStratum @Data)) {
        $_.Failover.Foreach({
            $Data.Server = $_
            if (Invoke-PingStratum @Data) {return}
        })
    }
})