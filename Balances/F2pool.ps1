param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $Config.Pools.$Name.UserName) {return}

$Payout_Currencies = $Config.Pools.$Name.Wallets.PSObject.Properties | Where-Object Value | Select-Object Name,Value -Unique | Sort-Object Name,Value

if (-not $Payout_Currencies) {
    Write-Log -Level Verbose "Cannot get balance on pool ($Name) - no wallet address specified. "
    return
}

$Pools_Data = [PSCustomObject]@{
    BTC = "bitcoin/user"
    LTC = "litecoin/user"
    GRIN = @("grin-29/user","grin-31/user")
    ETH = "ethereum/user"
    ETC = "etc/address"
    ZEC = "zec/address"
    SC  = "sc/address"
    XMR = "monero/address"
    Dash = "dash/address"
    DCR  = "decred/address"
    XZC  = "zcoin/address"
    RVN  = "raven/address"
    MONA = "monacoin/address"
    GRV  = "grv/address"
    ZEN  = "zen/address"
    ZCL  = "zclassic/address"
    ETN  = "electroneum/address"
    BTM  = "btm/address"
    PASC = "pasc/address"
    PGN  = "pigeon/address"
    XDAG = "xdag/address"
    LUX  = "lux/address"
    HDAC = "hdac/address"
    HYC  = "hycon/address"
    AE   = "aeternity/address"
    ZCR  = "zcore/address"
    XSC  = "hyperspace/address"
    BCHSV = "bitcoin-sv/address"
    BCHABC = "bitcoin-cash/address"
    SUQA = "suqa/address"
    DERO = "dero/address"
    ETP  = "metaverse/address"
    HCASH = "hcash/address"
    GIN  = "gincoin/address"
    AION = "aion/address"
    BEAM = "beam/address"
}

$Payout_Currencies | Where-Object {$Pools_Data.$($_.Name) -ne $null} | Foreach-Object {
    $Currency = $_
    $Pools_Data."$($Currency.Name)" | Foreach-Object {
        try {
            $Request = Invoke-RestMethodAsync "http://api.f2pool.com/$($_ -replace "address",$Currency.Value -replace "user",$Config.Pools.$Name.UserName)" -delay $(if ($Count){1000} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            $Count++
            if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name) ($($_ -replace "/.+$"))"
                    Currency    = $Currency.Name
                    Balance     = $Request.balance
                    Pending     = 0
                    Total       = $Request.balance
                    Paid        = $Request.paid
                    Earned      = $Request.paid + $Request.balance
                    Payouts     = @($Request.payout_history | Select-Object)
                    LastUpdated = (Get-Date).ToUniversalTime()
                }
            }
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Verbose "Pool Balance API ($Name) for $($_.Name) has failed. "
        }
    }
}
