using module ..\Include.psm1

param(
    [PSCustomObject]$Wallets,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 1
$Pool_Region = Get-Region "US"

$Pool_Request = [PSCustomObject]@{}

$Pools_Data = @(
    [PSCustomObject]@{coin = "Beam"            ; symbol = "BEAM"  ; algo = "Equihash150" ; rpc = "beam"     ; port = @(7776,7777)}
    [PSCustomObject]@{coin = "BitcoinGold"     ; symbol = "BTG"   ; algo = "Equihash144" ; rpc = "btg"      ; port = @(8866,8817)}
    [PSCustomObject]@{coin = "BitcoinInterest" ; symbol = "BCI"   ; algo = "ProgPOW"     ; rpc = "bci"      ; port = 9166}
    [PSCustomObject]@{coin = "BitcoinZ"        ; symbol = "BTCZ"  ; algo = "Equihash144" ; rpc = "btcz"     ; port = 6586}
    [PSCustomObject]@{coin = "BitCore"         ; symbol = "BTX"   ; algo = "Bitcore"     ; rpc = "btx"      ; port = 3629}
    [PSCustomObject]@{coin = "BitSend"         ; symbol = "BSD"   ; algo = "Xevan"       ; rpc = "bsd"      ; port = 8686}
    #[PSCustomObject]@{coin = "Credits"         ; symbol = "CRDS"  ; algo = "Argon2d250"  ; rpc = "crds"     ; port = 2771}
    [PSCustomObject]@{coin = "Dynamic"         ; symbol = "DYN"   ; algo = "Argon2d500"  ; rpc = "dyn"      ; port = 5960}
    [PSCustomObject]@{coin = "Garlicoin"       ; symbol = "GRLC"  ; algo = "Allium"      ; rpc = "grlc"     ; port = 8600}
    [PSCustomObject]@{coin = "GenX"            ; symbol = "GENX"  ; algo = "Equihash192" ; rpc = "genx"     ; port = 9983}
    [PSCustomObject]@{coin = "HODLcoin"        ; symbol = "HODL"  ; algo = "HOdl"        ; rpc = "hodl"     ; port = 4693}
    [PSCustomObject]@{coin = "Pigeon"          ; symbol = "PGN"   ; algo = "X16s"        ; rpc = "pign"     ; port = 4096}
    [PSCustomObject]@{coin = "Polytimos"       ; symbol = "POLY"  ; algo = "Polytimos"   ; rpc = "poly"     ; port = 7935}
    [PSCustomObject]@{coin = "Raven"           ; symbol = "RVN"   ; algo = "X16r"        ; rpc = "rvn"      ; port = 6666}
    [PSCustomObject]@{coin = "ROIcoin"         ; symbol = "ROI"   ; algo = "HOdl"        ; rpc = "roi"      ; port = 4699}
    [PSCustomObject]@{coin = "SafeCash"        ; symbol = "SCASH" ; algo = "Equihash144" ; rpc = "scash"    ; port = 8983}
    [PSCustomObject]@{coin = "UBIQ"            ; symbol = "UBQ"   ; algo = "Ethash"      ; rpc = "ubiq"     ; port = 3030}
    [pscustomobject]@{coin = "Veil"            ; symbol = "VEIL"  ; algo = "X16rt"       ; rpc = "veil"     ; port = 7220}
    [pscustomobject]@{coin = "Verge"           ; symbol = "XVG"   ; algo = "X17"         ; rpc = "xvg-x17"  ; port = 7477}
    [PSCustomObject]@{coin = "Vertcoin"        ; symbol = "VTC"   ; algo = "Lyra2v3"     ; rpc = "vtc"      ; port = 5778}
    [PSCustomObject]@{coin = "XDNA"            ; symbol = "XDNA"  ; algo = "Hex"         ; rpc = "xdna"     ; port = 4919}
    [PSCustomObject]@{coin = "Zero"            ; symbol = "ZER"   ; algo = "Equihash192" ; rpc = "zero"     ; port = 6568}
)

$Pools_Data | Where-Object {$Wallets."$($_.symbol)" -or $InfoOnly} | ForEach-Object {
    $Pool_Port = $_.port
    $Pool_Algorithm = $_.algo
    $Pool_Algorithm_Norm = Get-Algorithm $_.algo

    $Pool_Hashrate = $Pool_Workers = $null

    if (-not $InfoOnly) {
        $Pool_Request = [PSCustomObject]@{}
        try {
            $Pool_Request = Invoke-RestMethodAsync "https://$($_.rpc).suprnova.cc/index.php" -tag $Name -retry 3 -timeout 15
            if ($Pool_Request -match "b-poolhashrate.+?>([a-z0-9,\.\s]+?)<.+overview-mhs.+?>(.+?)/s") {
                $Pool_Hashrate = [double]($Matches[1] -replace "[,\s]+") * $(Switch -Regex ($Matches[2] -replace "\s+") {"^k" {1e3};"^M" {1e6};"^G" {1e9};"^T" {1e12};"^P" {1e15};default {1}})
            }
            if ($Pool_Request -match "b-poolworkers.+?>([0-9,\s]+?)<") {
                $Pool_Workers = [int]($Matches[1] -replace "[,\s]+")
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API ($Name) for $($_.symbol) has failed. "        
        }
    }

    $Pool_SSL = $false
    foreach ($Port in @($Pool_Port | Select-Object)) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
            CoinName      = $_.coin
            CoinSymbol    = $_.symbol
            Currency      = $_.symbol
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = if ($Pool_SSL) {"ssl"} else {"stratum+tcp"}
            Host          = $_.rpc + ".suprnova.cc"
            Port          = $Port
            User          = "$($Wallets."$($_.symbol)").{workername:$Worker}"
            Pass          = "x"
            Region        = $Pool_Region
            SSL           = $Pool_SSL
            Updated       = (Get-Date).ToUniversalTime()
            PoolFee       = $Pool_Fee
            Workers       = $Pool_Workers
            Hashrate      = $Pool_Hashrate
            DataWindow    = $DataWindow
            WTM           = $true
        }
        $Pool_SSL = $true
    }
}
