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

#$m = ([regex]'(?ms)data-key="(.+?)".+?data-urlname="(.+?)"').Matches($a)
#$m | Where-Object {$_.Groups[1].Value -notmatch "^(xvg|dgb)"} | Foreach-Object {"    $($_.Groups[1].Value.ToUpper() -replace "-ADDRESS") = `"$($_.Groups[2].Value)/address`""}

$Pools_Data = [PSCustomObject]@{
    BTC = "bitcoin/user"
    LTC = "litecoin/user"
    GRIN = @("grin-29/user","grin-32/user")
    CKB = "nervos/user"
    ETH = "ethereum/user"
    AE = "ae/address"
    AION = "aion/address"
    BCD = "bcd/address"
    BCH = "bch/address"
    BEAM = "beam/address"
    BSV = "bsv/address"
    BTM = "btm/address"
    CHI = "chi/address"
    CLO = "clo/address"
    DASH = "dash/address"
    DCR = "decred/address"
    ETC = "etc/address"
    ETP = "etp/address"
    HC = "hc/address"
    HDAC = "hdac/address"
    HNS = "hns/address"
    HYC = "hyc/address"
    IMG = "imagecoin/address"
    KDA = "kda/address"
    LUX = "lux/address"
    MONA = "mona/address"
    PASC = "pasc/address"
    PGN = "pigeon/address"
    RVC = "ravenclassic/address"
    RVN = "raven/address"
    SC = "sia/address"
    SCC = "sc/address"
    SERO = "sero/address"
    VTC = "vtc/address"
    XMR = "xmr/address"
    XZC = "zcoin/address"
    YEC = "yec/address"
    ZEC = "zec/address"
    ZEL = "zel/address"
    ZEN = "zen/address"
}

$Payout_Currencies | Where-Object {$Pools_Data."$($_.Name)" -ne $null -and (-not $Config.ExcludeCoinsymbolBalances.Count -or $Config.ExcludeCoinsymbolBalances -notcontains "$($_.Name)")} | Foreach-Object {
    $Currency = $_
    $Pools_Data."$($Currency.Name)" | Foreach-Object {
        try {
            $Pool_Wallet = Get-WalletWithPaymentId $Currency.Value -pidchar '.'
            $Request = Invoke-RestMethodAsync "http://api.f2pool.com/$($_ -replace "address",$Pool_Wallet -replace "user",$Config.Pools.$Name.UserName)" -delay $(if ($Count){1000} else {0}) -cycletime ($Config.BalanceUpdateMinutes*60)
            $Count++
            if (($Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
                Write-Log -Level Info "Pool Balance API ($Name) for $($_.Name) returned nothing. "
            } else {
                [PSCustomObject]@{
                    Caption     = "$($Name) ($($_ -replace "/.+$"))"
					BaseName    = $Name
                    Currency    = $Currency.Name
                    Balance     = [Decimal]$Request.balance
                    Pending     = [Decimal]0
                    Total       = [Decimal]$Request.balance
                    Paid        = [Decimal]$Request.paid
                    Earned      = [Decimal]$Request.paid + [Decimal]$Request.balance
                    Payouts     = @($Request.payout_history | Foreach-Object {
                        [PSCustomObject]@{
                            Date     = (Get-Date $_[0]).ToUniversalTime()
                            Amount   = [Double]$_[2]
                            Txid     = $_[1]
                        }
                    } | Select-Object)
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
