using module ..\Modules\Include.psm1
using module ..\Modules\MiningRigRentals.psm1

param(
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "average-2",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week",
    [String]$User = "",
    [String]$API_Key = "",
    [String]$API_Secret = "",
    [String]$UseWorkerName = "",
    [String]$ExcludeWorkerName = "",
    [Bool]$EnableMining = $false,
    [Bool]$EnableAutoCreate = $false,
    [Bool]$EnableAutoUpdate = $false,
    [Bool]$EnableAutoExtend = $false,
    [Bool]$EnableAutoPrice = $false,
    [Bool]$EnableAutoBenchmark = $false,
    [Bool]$EnableMinimumPrice = $false,
    [Bool]$EnableUpdateTitle = $false,
    [Bool]$EnableUpdateDescription = $false,
    [Bool]$EnableUpdatePriceModifier = $false,
    [Bool]$EnablePowerDrawAddOnly = $false,
    [Bool]$AllowExtensions = $false,
    [String]$AutoCreateAlgorithm = "",
    [String]$AutoCreateMinProfitPercent = "50",
    [String]$AutoCreateMinCPUProfitBTC = "0.00001",
    [String]$AutoCreateMaxMinHours = "24",
    [String]$AutoExtendTargetPercent = "100",
    [String]$AutoExtendMaximumPercent = "30",
    [String]$AutoBonusExtendForHours = "0",
    [String]$AutoBonusExtendByHours = "0",
    [String]$AutoBonusExtendTimes = "0",
    [String]$AutoUpdateMinPriceChangePercent = "3",
    [String]$AutoPriceModifierPercent = "0",
    [String]$UpdateInterval = "1h",
    [String]$PriceBTC = "0",
    [String]$PriceFactor = "1.8",
    [String]$PriceFactorMin = "1.1",
    [String]$PriceFactorDecayPercent = "10",
    [String]$PriceFactorDecayTime = "4h",
    [String]$PowerDrawFactor = "1.0",
    [String]$PriceCurrencies = "BTC",
    [String]$MinHours = "3",
    [String]$MaxHours = "168",
    [String]$ProfitAverageTime = "Day",
    [String]$PauseBetweenRentals = "0",
    [String]$Title = "",
    [String]$Description = "",
    [String]$StartMessage = "",
    [String]$ExtensionMessage = "",
    [String]$ExtensionMessageTime = "",
    [String]$UseHost = ""
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 3

if ($InfoOnly) {
    [PSCustomObject]@{
        Algorithm     = ""
        CoinName      = ""
        CoinSymbol    = ""
        Currency      = "BTC"
        Price         = 0
        StablePrice   = 0
        MarginOfError = 0
        Protocol      = "stratum+tcp"
        PoolFee       = $Pool_Fee
        Name          = $Name
        Penalty       = 0
        PenaltyFactor = 1
        Disabled      = $false
        HasMinerExclusions = $false
        Price_Bias    = 0.0
        Price_Unbias  = 0.0
        Wallet        = $Wallets.BTC
        Worker        = $Worker
        Email         = $Email
    }
    return
}

if (-not $API_Key -or -not $API_Secret) {return}

$Workers     = @($Session.Config.DeviceModel | Where-Object {$Session.Config.Devices.$_.Worker} | Foreach-Object {$Session.Config.Devices.$_.Worker} | Select-Object -Unique) + $Worker | Select-Object -Unique

$UseWorkerName_Array     = @($UseWorkerName   -split "[,; ]+" | Where-Object {$_} | Select-Object -Unique)
$ExcludeWorkerName_Array = @($ExcludeWorkerName -split "[,; ]+" | Where-Object {$_} | Select-Object -Unique)

$StartMessage = "$StartMessage".Trim()
$ExtensionMessage = "$ExtensionMessage".Trim()

if ($UseWorkerName_Array.Count -or $ExcludeWorkerName_Array.Count) {
    $Workers = $Workers.Where({($UseWorkerName_Array.Count -eq 0 -or $UseWorkerName_Array -contains $_) -and ($ExcludeWorkerName_Array.Count -eq 0 -or $ExcludeWorkerName_Array -notcontains $_)})
}

if (-not $Workers.Count) {return}

$AllRigs_Request   = Get-MiningRigRentalRigs -key $API_Key -secret $API_Secret -workers $Workers

Set-MiningRigRentalConfigDefault -Workers $Workers > $null

if ($API.MinersNeedingBenchmark) {
    $Devices_Benchmarking = @($API.MinersNeedingBenchmark.ForEach("DeviceName") | Select-Object -Unique)
} else {
    $Devices_Benchmarking = @()
}
if ($Session.MRRBenchmarkStatus -eq $null) {$Session.MRRBenchmarkStatus = @{}}
if ($Session.MRRRentalTimestamp -eq $null) {$Session.MRRRentalTimestamp = @{}}
if ($Session.MRRRigGroups       -eq $null) {
    $Session.MRRRigGroups       = @{}
    Get-MiningRigRentalGroups -key $API_Key -secret $API_Secret | Foreach-Object {
        $Session.MRRRigGroups[$_.name] = [int]$_.id
    }
}

$UpdateInterval_Seconds      = ConvertFrom-Time "$UpdateInterval"
$PauseBetweenRentals_Seconds = ConvertFrom-Time "$PauseBetweenRentals"
$ExtensionMessageTime_Hours  = (ConvertFrom-Time "$ExtensionMessageTime") / 3600

if (-not $UpdateInterval_Seconds) {$UpdateInterval_Seconds = 3600}
elseif ($UpdateInterval_Seconds -lt 600) {$UpdateInterval_Seconds = 600}

if ($AllRigs_Request) {

    [hashtable]$Pool_RegionsTable = @{}

    $Pool_AllHosts = Get-MiningRigRentalServers

    $Pool_AllHosts.Foreach({$Pool_RegionsTable[$_.region] = Get-Region "$($_.region -replace "^eu-")"})

    $Workers_Devices = @{}
    $Workers_Models  = @{}
    $Devices_Rented  = @()
    $MRR_Pings       = $null

    if ($Remove_Rigs = $AllRigs_Request | Where-Object {$_.type -eq "sha256" -and $_.status.status -ne "rented" -and -not $_.status.rented} | Select-Object -ExpandProperty id | Sort-Object) {
        Invoke-MiningRigRentalRequest "/rig/$($Remove_Rigs -join ';')" $API_Key $API_Secret -method "DELETE" > $null
        $AllRigs_Request = $AllRigs_Request | Where-Object {$_.id -notin @($Remove_Rigs)}
    }

    foreach ($Worker1 in $Workers) {

        if (-not ($Rigs_Request = $AllRigs_Request | Where-Object description -match "\[$($Worker1)\]")) {continue}

        $Rigs_DeviceModels = @($Session.Config.Devices.PSObject.Properties | Where-Object {$_.Value.Worker -eq $Worker1} | Select-Object -ExpandProperty Name | Select-Object -Unique)

        if ($Session.Config.MiningMode -eq "Legacy") {
            $Rigs_Devices = @($Global:DeviceCache.DevicesByTypes.AMD + $Global:DeviceCache.DevicesByTypes.NVIDIA + $Global:DeviceCache.DevicesByTypes.CPU | Sort-Object Index)
        } else {
            $Rigs_Devices = $Global:DeviceCache.Devices
        }

        $Rigs_Devices = $Rigs_Devices.Where({($Worker1 -eq $Worker -and $_.Type -eq "Gpu") -or ($Worker1 -ne $Worker -and $_.Model -in $Rigs_DeviceModels)})
        $Workers_Devices[$Worker1] = @($Rigs_Devices.Foreach("Name") | Select-Object -Unique)
        $Workers_Models[$Worker1]  = @($Rigs_Devices.Foreach("Model") | Select-Object -Unique)

        if (($Rigs_Request | Where-Object {$_.status.status -eq "rented" -or $_.status.rented} | Measure-Object).Count) {
            $Devices_Rented = @($Devices_Rented + $Workers_Devices[$Worker1] | Select-Object -Unique | Sort-Object)
        }

        if (-not $Session.MRRBenchmarkStatus.ContainsKey($Worker1)) {$Session.MRRBenchmarkStatus[$Worker1] = $false}
        if (-not $Session.MRRRentalTimestamp.ContainsKey($Worker1)) {$Session.MRRRentalTimestamp[$Worker1] = (Get-Date).ToUniversalTime().AddDays(-7)}
    }

    foreach ($Worker1 in $Workers) {

        if (-not ($Rigs_Request = $AllRigs_Request | Where-Object description -match "\[$($Worker1)\]")) {continue}

        if (($Rigs_Request | Where-Object {$_.status.status -eq "rented" -or $_.status.rented} | Measure-Object).Count) {
            if ($Disable_Rigs = $Rigs_Request | Where-Object {$_.status.status -ne "rented" -and -not $_.status.rented -and $_.available_status -eq "available"} | Select-Object -ExpandProperty id | Sort-Object) {
                Invoke-MiningRigRentalRequest "/rig/$($Disable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="disabled"} -method "PUT" > $null
                $Rigs_Request | Where-Object {$Disable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="disabled"}
                $Disable_Rigs | Foreach-Object {Set-MiningRigRentalStatus $_ -Stop}
            }
            $Session.MRRRentalTimestamp[$Worker1] = (Get-Date).ToUniversalTime()
        } else {
            $Valid_Rigs = @()

            if ((Compare-Object $Devices_Benchmarking $Workers_Devices[$Worker1] -ExcludeDifferent -IncludeEqual | Measure-Object).Count) {
                $Session.MRRBenchmarkStatus[$Worker1] = $true
            } elseif ($Session.MRRBenchmarkStatus[$Worker1]) {
                $API.UpdateMRR = $true
                $Session.MRRBenchmarkStatus[$Worker1] = $false
            } else {
                $NotRentedSince_Seconds = ((Get-Date).ToUniversalTime() - $Session.MRRRentalTimestamp[$Worker1]).TotalSeconds

                if (-not $PauseBetweenRentals_Seconds -or $PauseBetweenRentals_Seconds -lt $NotRentedSince_Seconds) {
                    $DeviceAlgorithm        = @($Workers_Models[$Worker1] | Where-Object {$Session.Config.Devices.$_.Algorithm.Count} | Foreach-Object {$Session.Config.Devices.$_.Algorithm} | Select-Object -Unique)
                    $DeviceExcludeAlgorithm = @($Workers_Models[$Worker1] | Where-Object {$Session.Config.Devices.$_.ExcludeAlgorithm.Count} | Foreach-Object {$Session.Config.Devices.$_.ExcludeAlgorithm} | Select-Object -Unique)

                    $ActiveAlgorithms       = @($Global:ActiveMiners.Where({$_.Enabled -and ($_.DeviceModel -in $Workers_Models[$Worker1]) -and (-not $_.ExcludePoolName -or $_.ExcludePoolName -notmatch $Name)}).Foreach({"$($_.Algorithm[0])" -replace "-.+$"}) | Select-Object -Unique)

                    $Rigs_Request | Select-Object id,type | Foreach-Object {
                        $Pool_Algorithm_Norm = Get-MiningRigRentalAlgorithm $_.type
                        if ((Get-Yes $Session.Config.Algorithms.$Pool_Algorithm_Norm.MRREnable) -and ($ActiveAlgorithms -icontains $Pool_Algorithm_Norm) -and -not (
                            ($Session.Config.Algorithm.Count -and $Session.Config.Algorithm -inotcontains $Pool_Algorithm_Norm) -or
                            ($Session.Config.ExcludeAlgorithm.Count -and $Session.Config.ExcludeAlgorithm -icontains $Pool_Algorithm_Norm) -or
                            ($Session.Config.Pools.$Name.Algorithm.Count -and $Session.Config.Pools.$Name.Algorithm -inotcontains $Pool_Algorithm_Norm) -or
                            ($Session.Config.Pools.$Name.ExcludeAlgorithm.Count -and $Session.Config.Pools.$Name.ExcludeAlgorithm -icontains $Pool_Algorithm_Norm) -or
                            (Compare-Object $Devices_Rented $Workers_Devices[$Worker1] -ExcludeDifferent -IncludeEqual | Measure-Object).Count -or
                            ($DeviceAlgorithm.Count -and $DeviceAlgorithm -inotcontains $Pool_Algorithm_Norm) -or
                            ($DeviceExcludeAlgorithm.Count -and $DeviceExcludeAlgorithm -icontains $Pool_Algorithm_Norm)
                            )) {$Valid_Rigs += $_.id}
                    }
                } else {
                    Write-Log -Level Warn "$($Name): Wait $([Math]::Round(($PauseBetweenRentals_Seconds - $NotRentedSince_Seconds)/60,1)) minutes for $($Worker1) rigs to be re-enabled."
                }
            }

            if ($Enable_Rigs = $Rigs_Request | Where-Object {$_.available_status -ne "available" -and $Valid_Rigs -contains $_.id} | Select-Object -ExpandProperty id | Sort-Object) {
                Invoke-MiningRigRentalRequest "/rig/$($Enable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="available"} -method "PUT" > $null
                $Rigs_Request | Where-Object {$Enable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="available"}
            }
            if ($Disable_Rigs = $Rigs_Request | Where-Object {$_.available_status -eq "available" -and $Valid_Rigs -notcontains $_.id} | Select-Object -ExpandProperty id | Sort-Object) {
                Invoke-MiningRigRentalRequest "/rig/$($Disable_Rigs -join ';')" $API_Key $API_Secret -params @{"status"="disabled"} -method "PUT" > $null
                $Rigs_Request | Where-Object {$Disable_Rigs -contains $_.id} | Foreach-Object {$_.available_status="disabled"}
            }
            $Rigs_Request | Foreach-Object {Set-MiningRigRentalStatus $_.id -Stop}
        }

        if (-not ($Rigs_Ids = $Rigs_Request | Where-Object {$_.available_status -eq "available"} | Select-Object -ExpandProperty id | Sort-Object)) {continue}

        $RigInfo_Request = Get-MiningRigInfo -id $Rigs_Ids -key $API_Key -secret $API_Secret
        if (-not $RigInfo_Request) {
            Write-Log -Level Warn "Pool API ($Name) rig $Worker1 info request has failed. "
            return
        }

        $Rigs_Request | Where-Object {$_.available_status -eq "available"} | ForEach-Object {
            $Pool_RigId = $_.id
            $Pool_Algorithm = $_.type
            $Pool_Algorithm_Norm = Get-MiningRigRentalAlgorithm $_.type
            $Pool_CoinSymbol = Get-MiningRigRentalCoin $_.type

            $Divisor = Get-MiningRigRentalsDivisor $_.price.type
            $Pool_Price = $_.price.BTC.price

            if (-not $InfoOnly) {
                $Stat = Set-Stat -Name "$($Name)_$($Pool_Algorithm_Norm)_Profit" -Value ([Double]$Pool_Price / $Divisor) -Duration $StatSpan -ChangeDetection $false -Quiet
            }

            $Pool_Rig = $RigInfo_Request | Where-Object {$_.rigid -eq $Pool_RigId -and $_.port -ne "error"}

            if ($Pool_Rig) {
                $Pool_Price = $Stat.$StatAverage
                $Pool_Currency = "BTC"

                $Pool_RigEnable = if ($_.status.status -eq "rented" -or $_.status.rented) {Set-MiningRigRentalStatus $Pool_RigId -Status $_.poolstatus}

                if ($_.status.status -eq "rented" -or $_.status.rented) {

                    $Rental_Result  = $null

                    $Pool_RigStatus = Get-MiningRigRentalStatus $Pool_RigId

                    $Rental_CheckForAutoExtend = ([double]$_.status.hours -lt 0.25) -and -not $Pool_RigStatus.extended
                    $Rental_CheckForExtensionMessage = $AllowExtensions -and $($ExtensionMessageTime_Hours -gt 0) -and ($ExtensionMessage.Length -gt 3) -and ([double]$_.status.hours -lt $ExtensionMessageTime_Hours) -and -not $Pool_RigStatus.extensionmessagesent

                    $Rental_Check = ($EnableAutoExtend -and $Rental_CheckForAutoExtend) -or $Rental_CheckForExtensionMessage

                    try {
                        try {
                            $Rental_Result = Invoke-MiningRigRentalRequest "/rental/$($_.rental_id)" $API_Key $API_Secret -method "GET" -Timeout 60 -Cache $(if ($Rental_Check) {0} else {[double]$_.status.hours*3600})
                            if ($Rental_Result.id -eq $_.rental_id) {
                                Set-MiningRigRentalStat $Worker1 $Rental_Result
                            }
                        } catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            $Rental_Result = Get-MiningRigRentalStat $Worker1 $_.rental_id
                        }

                        if ($Rental_Result) {
                            if ($Rig_RentalPrice = [Double]$Rental_Result.price_converted.advertised / (ConvertFrom-Hash "1$($Rental_Result.price_converted.type)")) {
                                $Pool_Price = $Rig_RentalPrice
                                if ($Rental_Result.price_converted.currency -ne "BTC") {
                                    $Pool_Currency = $Rental_Result.price_converted.currency
                                    $Pool_Price *= $_.price.BTC.price/$_.price."$($Rental_Result.price.currency)".price
                                }
                            }
                            if ($Rental_Check) {
                                $Rental_AdvHashrate = [double]$Rental_Result.hashrate.advertised.hash * (ConvertFrom-Hash "1$($Rental_Result.hashrate.advertised.type)")
                                $Rental_AvgHashrate = [double]$Rental_Result.hashrate.average.hash * (ConvertFrom-Hash "1$($Rental_Result.hashrate.average.type)")
                            }
                        }
                    } catch {if ($Error.Count){$Error.RemoveAt(0)}}

                    if ($StartMessage -ne "" -and -not $Pool_RigStatus.startmessagesent) {
                        try {
                            $StartMessage_Result = $null

                            if ($Rental_Result.length -and (([double]$Rental_Result.length + [double]$Rental_Result.extended - [double]$Rental_Result.rig.status.hours) -lt 5/60)) {
                                $StartMessage_Result = Invoke-MiningRigRentalRequest "/rental/$($_.rental_id)/message" $API_Key $API_Secret -params @{"message"=$StartMessage} -method "PUT" -Timeout 60
                            }

                            Write-Log -Level Info "$($Name): Start message $(if (-not $StartMessage_Result.success) {"NOT "})sent to rental #$($_.rental_id) for $Pool_Algorithm_Norm on $Worker1"

                            Set-MiningRigRentalStatus $Pool_RigId -Status "startmessagesent" > $null
                        } catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            Write-Log -Level Warn "$($Name): Unable to handle start message for rental #$($_.rental_id): $($_.Exception.Message)"
                        }
                    }

                    if ($EnableAutoExtend) {
                        if ($Rental_CheckForAutoExtend) {
                            try {
                                $Rental_SetStatus = $true

                                if ($Rental_AvgHashrate -and $Rental_AdvHashrate -and $Rental_AvgHashrate -lt $Rental_AdvHashrate) {
                                    $MRRConfig = Get-ConfigContent "MRR"
                                    if ($MRRConfig -eq $null) {$MRRConfig = [PSCustomObject]@{}}
                                    $AutoExtendTargetPercent_Value  = if ($MRRConfig.$Worker1.AutoExtendTargetPercent -ne $null -and $MRRConfig.$Worker1.AutoExtendTargetPercent -ne "") {$MRRConfig.$Worker1.AutoExtendTargetPercent} else {$AutoExtendTargetPercent}
                                    $AutoExtendTargetPercent_Value  = [Double]("$($AutoExtendTargetPercent_Value)" -replace ",","." -replace "[^0-9\.]+") / 100
                                    $AutoExtendMaximumPercent_Value = if ($MRRConfig.$Worker1.AutoExtendMaximumPercent -ne $null -and $MRRConfig.$Worker1.AutoExtendMaximumPercent -ne "") {$MRRConfig.$Worker1.AutoExtendMaximumPercent} else {$AutoExtendMaximumPercent}
                                    $AutoExtendMaximumPercent_Value = [Double]("$($AutoExtendMaximumPercent_Value)" -replace ",","." -replace "[^0-9\.]+") / 100

                                    $Rental_Extended = [double]$Rental_Result.extended

                                    $ExtendBy = ([double]$Rental_Result.length + $Rental_Extended) * ($AutoExtendTargetPercent_Value * $Rental_AdvHashrate / $Rental_AvgHashrate - 1)

                                    if ($ExtendBy -gt 0 -and $AutoExtendMaximumPercent_Value -gt 0) {

                                        $Rental_ExtendedBonus = 0
                                        if ($Rental_Extended -gt 0) {
                                            $AutoBonusExtendForHours_Value = if ($MRRConfig.$Worker1.AutoBonusExtendForHours -ne $null -and $MRRConfig.$Worker1.AutoBonusExtendForHours -ne "") {$MRRConfig.$Worker1.AutoBonusExtendForHours} else {$AutoBonusExtendForHours}
                                            $AutoBonusExtendForHours_Value = [Double]("$($AutoBonusExtendForHours_Value)" -replace ",","." -replace "[^0-9\.]+")
                                            $AutoBonusExtendByHours_Value  = if ($MRRConfig.$Worker1.AutoBonusExtendByHours -ne $null -and $MRRConfig.$Worker1.AutoBonusExtendByHours -ne "") {$MRRConfig.$Worker1.AutoBonusExtendByHours} else {$AutoBonusExtendByHours}
                                            $AutoBonusExtendByHours_Value  = [Double]("$($AutoBonusExtendByHours_Value)" -replace ",","." -replace "[^0-9\.]+")
                                            $AutoBonusExtendTimes_Value  = if ($MRRConfig.$Worker1.AutoBonusExtendTimes -ne $null -and $MRRConfig.$Worker1.AutoBonusExtendTimes -ne "") {$MRRConfig.$Worker1.AutoBonusExtendTimes} else {$AutoBonusExtendTimes}
                                            $AutoBonusExtendTimes_Value  = [Double]("$($AutoBonusExtendTimes_Value)" -replace ",","." -replace "[^0-9\.]+")
                                            if ($AutoBonusExtendTimes_Value -le 0) {$AutoBonusExtendTimes_Value = 1000}

                                            if ($AutoBonusExtendForHours_Value -gt 0 -and $AutoBonusExtendByHours_Value -gt 0) {
                                                $Rental_ExtendedBonus = [Math]::Min([Math]::Floor([double]$Rental_Result.length/$AutoBonusExtendForHours_Value),$AutoBonusExtendTimes_Value) * $AutoBonusExtendByHours_Value
                                                if ($Rental_ExtendedBonus -gt $Rental_Extended) {
                                                    $Rental_ExtendedBonus = 0
                                                }
                                            }
                                        }

                                        $ExtendBy = [Math]::Min([double]$Rental_Result.length * $AutoExtendMaximumPercent_Value - $Rental_Extended + $Rental_ExtendedBonus,$ExtendBy)
                                    }

                                    $ExtendBy = [Math]::Round($ExtendBy,2)

                                    if ($ExtendBy -ge (1/6)) {
                                        $Extend_Result = Invoke-MiningRigRentalRequest "/rig/$Pool_RigId/extend" $API_Key $API_Secret -params @{"hours"=$ExtendBy} -method "PUT" -Timeout 60
                                        if ($Extend_Result.success) {
                                            Write-Log -Level Info "$($Name): Extended rental #$($_.rental_id) for $Pool_Algorithm_Norm on $Worker1 for $ExtendBy hours."
                                        } else {
                                            $Rental_SetStatus = $false
                                        }
                                    }
                                }
                                if ($Rental_SetStatus) {
                                    Set-MiningRigRentalStatus $Pool_RigId -Status "extended" > $null
                                }
                            } catch {
                                if ($Error.Count){$Error.RemoveAt(0)}
                                Write-Log -Level Warn "$($Name): Unable to get rental #$($_.rental_id): $($_.Exception.Message)"
                            }
                        } elseif (([double]$_.status.hours -gt 0.25) -and $Pool_RigStatus.extended) {
                            Set-MiningRigRentalStatus $Pool_RigId -Status "notextended" > $null
                        }
                    }

                    if ($Rental_CheckForExtensionMessage) {
                        try {
                            $Rental_AdvProfit   = $Rental_AdvHashrate * $Rig_RentalPrice
                            $Rental_AvgProfit   = $Rental_AvgHashrate * $Rig_RentalPrice
                            $Rental_RigProfit   = ([double]$_.hashrate.advertised.hash * (ConvertFrom-Hash "1$($_.hashrate.advertised.type)")) * ([double]$_.price.BTC.price / (ConvertFrom-Hash "1$($_.price.type)"))

                            $ExtMessage_Result = $null
                            if (($Rental_AdvProfit - [Math]::Abs($Rental_AdvProfit - $Rental_AvgProfit)) -ge $Rental_RigProfit) {
                                $ExtMessage_Result = Invoke-MiningRigRentalRequest "/rental/$($_.rental_id)/message" $API_Key $API_Secret -params @{"message"=$ExtensionMessage} -method "PUT" -Timeout 60
                            }

                            Write-Log -Level Info "$($Name): Extension message $(if (-not $ExtMessage_Result.success) {"NOT "})sent to rental #$($_.rental_id) for $Pool_Algorithm_Norm on $Worker1"

                            Set-MiningRigRentalStatus $Pool_RigId -Status "extensionmessagesent" > $null
                        } catch {
                            if ($Error.Count){$Error.RemoveAt(0)}
                            Write-Log -Level Warn "$($Name): Unable to handle extension message for rental #$($_.rental_id): $($_.Exception.Message)"
                        }
                    }

                    try {
                        if ($Rental_Result.end -and ((Get-Date).ToUniversalTime().AddMinutes(-15) -gt [DateTime]::Parse("$($Rental_Result.end -replace "\s+UTC$")"))) {

                            #Manual override to end rentals in case of server failure

                            if ($_.status.rented) {$_.status.rented = $false}
                            if ($_.status.status -eq "rented") {$_.status.status = "available"}
                            $Pool_RigEnable = $false

                            Write-Log -Level Warn "MiningRigRentals: cannot reach MRR, manually disable rental #$($Rental_Result.id) on $($Worker1) that ended $($Rental_Result.end)."
                        }
                    } catch {if ($Error.Count){$Error.RemoveAt(0)}}

                    $Pool_RigStatus = $null
                }

                if ($_.status.status -eq "rented" -or $_.status.rented -or $_.poolstatus -eq "online" -or $EnableMining) {

                    $Miner_Server = $Pool_Rig.server
                    $Miner_Port   = $Pool_Rig.port

                    if ($UseHost -and $Pool_RigEnable -and ($Host_Rig = $Pool_AllHosts | Where-Object name -like "$UseHost*" | Select-Object -First 1)) {
                        $Miner_Server = $Host_Rig.name
                        $Miner_Port   = if ($Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {$Host_Rig.ethereum_port} else {$Host_Rig.port}
                    }

                    $Pool_FailOver = if ($Pool_AltRegions = Get-Region2 $Pool_RegionsTable."$($_.region)") {$Pool_AllHosts | Where-Object {$_.name -ne $Miner_Server} | Sort-Object -Descending {$ix = $Pool_AltRegions.IndexOf($Pool_RegionsTable."$($_.region)");[int]($ix -ge 0)*(100-$ix)},{$_.region -match "^$($Miner_Server.SubString(0,2))"},{100-$_.id} | Select-Object -First 2}
                    if (-not $Pool_Failover) {$Pool_FailOver = @($Pool_AllHosts | Where-Object {$_.name -ne $Miner_Server -and $_.region -match "^us"} | Select-Object -First 1) + @($Pool_AllHosts | Where-Object {$_.name -ne $Miner_Server -and $_.region -match "^eu"} | Select-Object -First 1)}
                    $Pool_FailOver += $Pool_AllHosts | Where-Object {$_.name -ne $Miner_Server -and $Pool_FailOver -notcontains $_} | Select-Object -First 1
                
                    #BEGIN temporary fixes

                    #
                    # hardcoded fixes due to MRR stratum or API failures
                    #

                    #if (($Pool_Algorithm_Norm -eq "X25x" -or $Pool_Algorithm_Norm -eq "MTP") -and $Miner_Server -match "^eu-01") {
                    #    $Miner_Server = ($Pool_Failover | Select-Object -First 1).name
                    #    $Miner_Port   = 3333
                    #    $Pool_Failover = $Pool_Failover | Select-Object -Skip 1
                    #}

                    #if ($Pool_Algorithm_Norm -eq "Cuckaroo29") {$Miner_Port = 3322}
                    #if ($Pool_Algorithm_Norm -eq "Tensority") {$Miner_Port = 3333}

                    $Pool_SSL = $Pool_Algorithm_Norm -in @("EquihashR25x5","EquihashR25x5x3")

                    #END temporary fixes
                    
                    $Rigs_Model = if ($Worker1 -ne $Worker) {"$(($Session.Config.DeviceModel | Where-Object {$Session.Config.Devices.$_.Worker -eq $Worker1} | Sort-Object -Unique) -join '-')"} elseif ($Global:DeviceCache.DeviceNames.CPU -ne $null) {"GPU"}

                    $Rigs_UserSep   = if (@("ProgPowVeil","ProgPowZ","Ubqhash") -icontains $Pool_Algorithm_Norm) {"*"} else {"."}

                    [PSCustomObject]@{
                        Algorithm     = "$Pool_Algorithm_Norm$(if ($Rigs_Model) {"-$Rigs_Model"})"
					    Algorithm0    = $Pool_Algorithm_Norm
                        CoinName      = if ($_.status.status -eq "rented" -or $_.status.rented) {try {$ts=[timespan]::fromhours($_.status.hours);"{0:00}h{1:00}m{2:00}s" -f [Math]::Floor($ts.TotalHours),$ts.Minutes,$ts.Seconds}catch{if ($Error.Count){$Error.RemoveAt(0)};"$($_.status.hours)h"}} else {""}
                        CoinSymbol    = $Pool_CoinSymbol
                        Currency      = $Pool_Currency
                        Price         = $Pool_Price
                        StablePrice   = $Stat.$StatAverageStable
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+$(if ($Pool_SSL) {"ssl"} else {"tcp"})"
                        Host          = $Miner_Server
                        Port          = $Miner_Port
                        User          = "$($User)$($Rigs_UserSep)$($Pool_RigId)"
                        Pass          = "x"
                        Region        = $Pool_RegionsTable."$($_.region)"
                        SSL           = $Pool_SSL
                        Updated       = $Stat.Updated
                        PoolFee       = $Pool_Fee
                        Exclusive     = ($_.status.status -eq "rented" -or $_.status.rented) -and $Pool_RigEnable
                        Idle          = if (($_.status.status -eq "rented" -or $_.status.rented) -and $Pool_RigEnable) {$false} else {-not $EnableMining}
                        Failover      = @($Pool_Failover | Select-Object -ExpandProperty name | Foreach-Object {
                            [PSCustomObject]@{
                                Protocol = "stratum+tcp"
                                Host     = $_
                                Port     = if ($Miner_Port -match "^33\d\d$") {$Miner_Port} else {3333}
                                User     = "$($User)$($Rigs_UserSep)$($Pool_RigId)"
                                Pass     = "x"
                            }
                        })
                        EthMode       = if ($Miner_Port -match "^33\d\d$" -and $Pool_Algorithm_Norm -match $Global:RegexAlgoHasDAGSize) {"qtminer"} else {$null}
                        Name          = $Name
                        Penalty       = 0
                        PenaltyFactor = 1
					    Disabled      = $false
					    HasMinerExclusions = $false
					    Price_Bias    = 0.0
					    Price_Unbias  = 0.0
                        Wallet        = ""
                        Worker        = $Worker1
                        Email         = $Email
                    }
                }

                if (-not $Pool_RigEnable) {
                    if ($MRR_Pings -eq $null) {
                        [System.Collections.ArrayList]$MRR_Pings = @()
                    }
                    $MRR_Pings.Add([PSCustomObject]@{
                                        Data = @{
                                            Server = $Pool_Rig.server
                                            Port   = $Pool_Rig.port
                                            User   = "$($User).$($Pool_RigId)"
                                            Pass   = "x"
                                            Worker = $Worker1
                                            Method = if ($Pool_Rig.port -match "^33\d\d$") {"EthProxy"} else {"Stratum"}
                                            WaitForResponse = $_.status.status -eq "rented" -or $_.status.rented
                                        }
                                        Failover = @($Pool_Failover | Select-Object -ExpandProperty name)
                    }) > $null
                }
            }
        }
    }

    if ($MRR_Pings) {
        #Write-Log -Level Warn "$(ConvertTo-Json $MRR_Pings)"
        try {
            if ($MRR_Job = Get-Job -Name MRRPing -ErrorAction Ignore) {
                if ($MRR_Job.State -ne "Running") {
                    if ($MRR_Job.HasMoreData) {$MRR_Job | Receive-Job > $null}
                    $MRR_Job | Remove-Job -Force
                    $MRR_Job = $null
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}    
        }

        if (-not $MRR_Job) {
            #write-host -level warn "$(ConvertTo-Json $MRR_Pings)"
            $MRR_Job = Start-Job -Name MRRPing  -FilePath .\Scripts\MRRPing.ps1 -ArgumentList $MRR_Pings -InitializationScript ([ScriptBlock]::Create("Set-Location `"$($PWD.Path -replace '"','``"')`""))
            if ($MRR_Job) {Remove-Variable "MRR_Job"}
        }
        $MRR_Pings.Clear()
        Remove-Variable "MRR_Pings"
    }

    Remove-Variable "Workers_Devices"
    Remove-Variable "Devices_Rented"
}

#
# we will check for auto operations every hour but not at startup
#
if (-not $InfoOnly -and (-not $API.DownloadList -or -not $API.DownloadList.Count) -and -not $Session.IsDonationRun -and $Session.RoundCounter -and ($API.UpdateMRR -or -not $Session.MRRlastautoperation -or $Session.MRRlastautoperation -lt (Get-Date).AddSeconds(-$UpdateInterval_Seconds))) {

    if ($API.UpdateMRR) {$API.UpdateMRR = $false}

    $RigDivisors = @("h","kh","mh","gh","th") | Foreach-Object {[PSCustomObject]@{type=$_;value=(ConvertFrom-Hash "1$_")}}
    $RigCreated = 0
    $RigsToUpdate = @()
    $RigGroupsAdd = @()
    $RigGroupsRemove = @()
    $RigMinProfit = 0.00001
    $RigServer = $null

    $UniqueRigs_Request = $AllRigs_Request.Where({(([regex]"\[[\w\-]+\]").Matches($_.description).Value | Select-Object -Unique | Measure-Object).Count -eq 1})

    #
    # 1. gather config per workername
    #

    if ($MRRConfig -eq $null) {
        $MRRConfig = Get-ConfigContent "MRR"
        if ($MRRConfig -eq $null) {$MRRConfig = [PSCustomObject]@{}}
    }

    foreach ($RigName in $Workers) {

        if ($MRRConfig.$RigName -eq $null) {$MRRConfig | Add-Member $RigName ([PSCustomObject]@{}) -Force}
            
        foreach ($fld in @("EnableAutoCreate","EnableAutoUpdate","EnableAutoPrice","EnableMinimumPrice","EnableUpdateTitle","EnableUpdateDescription","EnableUpdatePriceModifier","EnablePowerDrawAddOnly","AllowExtensions")) {
            #boolean
            try {
                $val = if ($MRRConfig.$RigName.$fld -ne $null -and $MRRConfig.$RigName.$fld -ne "") {Get-Yes $MRRConfig.$RigName.$fld} else {Get-Variable $fld -ValueOnly -ErrorAction Ignore}
                $MRRConfig.$RigName | Add-Member $fld $val -Force
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "$($Name): Error in parameter `"$fld`" in pools.config.txt or mrr.config.txt"
            }
        }

        $AutoCreateMinProfitBTC = "-1"

        foreach ($fld in @("AutoCreateMinProfitPercent","AutoCreateMinProfitBTC","AutoCreateMinCPUProfitBTC","AutoCreateMaxMinHours","AutoExtendTargetPercent","AutoExtendMaximumPercent","AutoBonusExtendForHours","AutoBonusExtendByHours","AutoBonusExtendTimes","AutoUpdateMinPriceChangePercent","AutoPriceModifierPercent","PriceBTC","PriceFactor","PriceFactorMin","PriceFactorDecayPercent","PowerDrawFactor","MinHours","MaxHours")) {
            #double
            try {
                $val = if ($MRRConfig.$RigName.$fld -ne $null -and $MRRConfig.$RigName.$fld -ne "") {$MRRConfig.$RigName.$fld} else {Get-Variable -Name $fld -ValueOnly -ErrorAction Ignore}
                $val = "$($val)" -replace ",","." -replace "[^0-9\.\-]+"
                $MRRConfig.$RigName | Add-Member $fld ([Double]$(if ($val.Length -le 1) {$val -replace "[^0-9]"} else {$val[0] + "$($val.Substring(1) -replace "[^0-9\.]")"})) -Force
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "$($Name): Error in parameter `"$fld`" in pools.config.txt or mrr.config.txt"
            }
        }

        foreach ($fld in @("PriceCurrencies","AutoCreateAlgorithm")) {
            #array
            try {
                $val = if ($MRRConfig.$RigName.$fld -ne $null -and $MRRConfig.$RigName.$fld -ne "") {$MRRConfig.$RigName.$fld} else {Get-Variable -Name $fld -ValueOnly -ErrorAction Ignore}
                if ($fld -match "Algorithm") {
                    $val = @($val -split "[,; ]+" | Where-Object {$_} | Foreach-Object {Get-Algorithm $_} | Select-Object -Unique)
                } else {
                    $val = @($val -split "[,; ]+" | Where-Object {$_} | Select-Object)
                }
                $MRRConfig.$RigName | Add-Member $fld $val -Force
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "$($Name): Error in parameter `"$fld`" in pools.config.txt or mrr.config.txt"
            }
        }

        foreach ($fld in @("Title","Description","ProfitAverageTime","PriceFactorDecayTime")) {
            #string
            try {
                $val = if ($MRRConfig.$RigName.$fld -ne $null -and $MRRConfig.$RigName.$fld -ne "") {$MRRConfig.$RigName.$fld} else {Get-Variable $fld -ValueOnly -ErrorAction Ignore}
                $val = "$($val)".Trim()
                $MRRConfig.$RigName | Add-Member $fld $val -Force
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "$($Name): Error in parameter `"$fld`" in pools.config.txt or mrr.config.txt"
            }
        }

        if ($MRRConfig.$RigName.AutoBonusExtendTimes -le 0) {$MRRConfig.$RigName.AutoBonusExtendTimes = 1000}
        if ($MRRConfig.$RigName.MinHours -lt 3) {$MRRConfig.$RigName.MinHours = 3}
        if ($MRRConfig.$RigName.MaxHours -lt $MRRConfig.$RigName.MinHours) {$MRRConfig.$RigName.MaxHours = $MRRConfig.$RigName.MinHours}
        if ($MRRConfig.$RigName.AutoCreateMaxMinHours -lt 3) {$MRRConfig.$RigName.AutoCreateMaxMinHours = 3}
        if ($MRRConfig.$RigName.ProfitAverageTime -notin @("Minute","Minute_5","Minute_10","Hour","Day","ThreeDay","Week")) {$MRRConfig.$RigName.ProfitAverageTime = "Day"}
        $MRRConfig.$RigName.PriceFactorDecayTime = [Math]::Max((ConvertFrom-Time "$($MRRConfig.$RigName.PriceFactorDecayTime)"),$UpdateInterval_Seconds) / 3600
    }

    #
    # 2. Auto extend rented rigs, if bonus applicable
    #

    $RentalIDs = @($UniqueRigs_Request.Where({$_.status.status -eq "rented" -or $_.status.rented}).rental_id | Select-Object)
    
    if ($RentalIDs) {
        $Rental_Result = Invoke-MiningRigRentalRequest "/rental/$($RentalIDs -join ";")" $API_Key $API_Secret -method "GET" -Timeout 60
        foreach ($RigName in $Workers) {
            if (-not $MRRConfig.$RigName.AutoBonusExtendForHours -or -not $MRRConfig.$RigName.AutoBonusExtendByHours) {continue}
            $Rental_Result | Where-Object {$_.rig.description -match "\[$RigName\]"} | Foreach-Object {
                $ExtendBy = [Math]::Min([Math]::Floor([double]$_.length/$MRRConfig.$RigName.AutoBonusExtendForHours),$MRRConfig.$RigName.AutoBonusExtendTimes) * $MRRConfig.$RigName.AutoBonusExtendByHours - [double]$_.extended
                if ($ExtendBy -gt 0) {
                    try {                    
                        $Extend_Result = Invoke-MiningRigRentalRequest "/rig/$($_.rig.id)/extend" $API_Key $API_Secret -params @{"hours"=$ExtendBy} -method "PUT" -Timeout 60
                        if ($Extend_Result.success) {
                            Write-Log -Level Info "$($Name): Extended rental #$($_.id) for $(Get-MiningRigRentalAlgorithm $_.rig.type) on $($RigName) for $ExtendBy bonus-hours."
                        }
                    } catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                        Write-Log -Level Warn "$($Name): Unable to extend rental #$($_.id) $(Get-MiningRigRentalAlgorithm $_.rig.type) on $($RigName) for $ExtendBy bonus-hours: $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    #
    # 3. Load control data
    #

    $MRRRigControl_Data = $null
    if (Test-Path ".\Data\mrrcontrol.json") {
        try {
            $MRRRigControl_Data = Get-Content ".\Data\mrrcontrol.json" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "$($Name): mrrcontrol database is corrupt and will be reset. "
            $MRRRigControl_Data = $null
        }
    }

    $RigNow = (Get-Date).ToUniversalTime()
    $MRRRigControl = @($Workers.ForEach({
        $RigName = $_
        $RigUpdated = $RigNow
        $RigPriceFactor = $MRRConfig.$RigName.PriceFactor

        $MRRRigControl_Data | Where-Object {$_.Name -eq $RigName} | Foreach-Object {
            $TimeC = [Math]::Floor(($RigNow - $_.LastReset).TotalHours / $MRRConfig.$RigName.PriceFactorDecayTime)
            While ($TimeC -gt 0) {
                $RigPriceFactor = [Math]::Max($RigPriceFactor * (1 - $MRRConfig.$RigName.PriceFactorDecayPercent/100),$MRRConfig.$RigName.PriceFactorMin)
                $TimeC--
            }
            $RigUpdated = [DateTime]$_.LastReset
        }
        [PSCustomObject]@{
            Name         = $RigName
            PriceFactor  = $RigPriceFactor
            LastReset    = $RigUpdated
        }
    }) | Select-Object)

    if (Test-Path Variable:MRRRigControl_Data) {
        Remove-Variable "MRRRigControl_Data"
    }

    #
    # 4. Auto create/update rigs
    #

    $Pool_Request = [PSCustomObject]@{}

    if ($Pool_Request = (Get-MiningRigRentalAlgos).Where({$_.name -ne "sha256"})) {

        $MaxAPICalls = 40

        $RigGPUModels = $Session.Config.DeviceModel.Where({$_ -ne "CPU"})

        $RigPools = [hashtable]@{}
        if ($AllRigs_Request) {
            try {
                (Invoke-MiningRigRentalRequest "/rig/$(@($AllRigs_Request | Select-Object -ExpandProperty id) -join ";")/pool" $API_Key $API_Secret -Timeout 60) | Foreach-Object {$RigPools[[int]$_.rigid] = $_.pools}
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "$($Name): Unable to get pools: $($_.Exception.Message)"
            }
        }

        $PoolsData = Get-MiningRigRentalsPoolsData -UpdateLocalCopy

        foreach($RigRunMode in @("create","update")) {

            foreach ($RigName in $Workers) {

                $RigNameStat = Get-MiningRigStat $RigName
                if (-not $RigNameStat) {
                    $RigNameStat = [PSCustomObject]@{}
                }

                Write-Log -Level Info "$($Name): Start $($RigRunMode) rigs on $($RigName)"

                if ($RigRunMode -eq "create" -and $RigCreated -ge $MaxAPICalls) {break}

                if (($RigRunMode -eq "create" -and $MRRConfig.$RigName.EnableAutoCreate) -or ($RigRunMode -eq "update" -and $MRRConfig.$RigName.EnableAutoUpdate)) {
                    try {
                        $RigModels           = @($Session.Config.Devices.PSObject.Properties | Where-Object {$_.Value.Worker -eq $RigName} | Foreach-Object {$_.Name} | Select-Object -Unique)
                        $RigDevice           = $Global:DeviceCache.Devices.Where({($_.Model -notmatch "-" -and (($RigName -eq $Worker -and $_.Type -eq "Gpu") -or ($RigName -ne $Worker -and $_.Model -in $RigModels)))})
                        $RigDeviceStat       = Get-Stat -Name "Profit-$(@($RigDevice.Foreach("Name") | Sort-Object -Unique) -join "-")"
                        $RigDeviceRevenue24h = $RigDeviceStat."$($MRRConfig.$RigName.ProfitAverageTime)"
                        $RigDevicePowerDraw  = $RigDeviceStat.PowerDraw_Average

                        $RigType ="$($RigDevice.Foreach("Type") | Select-Object -Unique)".ToUpper()

                        if ($RigType -eq "GPU") {
                            $RigDeviceRam = ($RigDevice | Foreach-Object {$_.OpenCL.GlobalMemsize} | Measure-Object -Minimum).Minimum / 1GB
                            if ($IsWindows -and $Session.IsWin10 -and -not $Session.Config.EnableEthashZombieMode) {
                                $RigDeviceRam *= 0.8652
                            }
                            $RigDeviceRam = [Math]::Round($RigDeviceRam,3)
                        }

                        if (-not $API.MinersNeedingBenchmark) {$CurrentlyBenchmarking = @()}
                        else {$CurrentlyBenchmarking = @($API.MinersNeedingBenchmark | Foreach-Object {[PSCustomObject]@{Algorithm="$($_.HashRates.PSObject.Properties.Name | Select-Object -First 1)" -replace "-$($_.DeviceModel)";DeviceModel=$_.DeviceModel}} | Where-Object {$_.Algorithm -notmatch "-"} | Group-Object "Algorithm","DeviceModel" | Foreach-Object {$_.Group | Select-Object -First 1})}

                        if ($MRRConfig.$RigName.AutoCreateMinProfitBTC -lt 0) {
                            $MRRConfig.$RigName.AutoCreateMinProfitBTC = if ($RigType -eq "CPU") {$MRRConfig.$RigName.AutoCreateMinCPUProfitBTC} else {0}
                        }

                        $RigSubst = @{
                            "RigID"      = "$(Get-MiningRigRentalsRigID $RigName)"
                            "Type"       = $RigType
                            "TypeCPU"    = "$(if ($RigType -eq "CPU") {"CPU"})"
                            "TypeGPU"    = "$(if ($RigType -eq "GPU") {"GPU"})"
                            "Workername" = $RigName
                        }
                    
                        if ($RigDeviceRevenue24h -and $RigDeviceStat.Duration) {
                            if ($RigDeviceStat.Duration -lt [timespan]::FromHours(3)) {throw "your rig must run for at least 3 hours be accurate"}
                            $RigModels         = @($RigDevice.Foreach("Model") | Sort-Object -Unique)
                            $RigAlreadyCreated = @($UniqueRigs_Request.Where({$_.description -match "\[$RigName\]"}))
                            $RigProfitBTCLimit = [Math]::Max($RigDeviceRevenue24h * [Math]::Min($MRRConfig.$RigName.AutoCreateMinProfitPercent,100)/100,$MRRConfig.$RigName.AutoCreateMinProfitBTC)
                            $RigModifier       = [Math]::Max(-30,[Math]::Min(30,$MRRConfig.$RigName.AutoPriceModifierPercent))

                            $RigPriceFactor    = $MRRConfig.$RigName.PriceFactor

                            $RigControl_Data   = $null

                            if ($RigRunMode -eq "update" -and $MRRConfig.$RigName.PriceFactorDecayPercent -gt 0 -and $MRRConfig.$RigName.PriceFactorDecayTime -gt 0) {
                                if ($RigControl_Data = $MRRRigControl | Where-Object {$_.Name -eq $RigName}) {
                                    $RigPriceFactor = $RigControl_Data.PriceFactor
                                }
                            }

                            $DeviceAlgorithm        = @($RigModels | Where-Object {$Session.Config.Devices.$_.Algorithm.Count} | Foreach-Object {$Session.Config.Devices.$_.Algorithm} | Select-Object -Unique)
                            $DeviceExcludeAlgorithm = @($RigModels | Where-Object {$Session.Config.Devices.$_.ExcludeAlgorithm.Count} | Foreach-Object {$Session.Config.Devices.$_.ExcludeAlgorithm} | Select-Object -Unique)

                            $Pool_Request.Where({($RigRunMode -eq "create" -and $RigAlreadyCreated.type -notcontains $_.name) -or ($RigRunMode -eq "update" -and $RigAlreadyCreated.type -contains $_.name)}).Foreach({

                                $Algorithm_Norm  = Get-MiningRigRentalAlgorithm $_.name
                                $RigPower     = 0
                                $RigSpeed     = 0
                                $RigRevenue   = 0
                                $RigMaxRevenueFactor = 10

                                $SuggestedPrice = if ($_.suggested_price.unit) {[Double]$_.suggested_price.amount / (ConvertFrom-Hash "1$($_.suggested_price.unit -replace "\*.+$")")} else {0}

                                if ((Get-Yes $Session.Config.Algorithms.$Algorithm_Norm.MRREnable) -and -not (
                                        ($Session.Config.Algorithm.Count -and $Session.Config.Algorithm -inotcontains $Algorithm_Norm) -or
                                        ($Session.Config.ExcludeAlgorithm.Count -and $Session.Config.ExcludeAlgorithm -icontains $Algorithm_Norm) -or
                                        ($Session.Config.Pools.$Name.Algorithm.Count -and $Session.Config.Pools.$Name.Algorithm -inotcontains $Algorithm_Norm) -or
                                        ($Session.Config.Pools.$Name.ExcludeAlgorithm.Count -and $Session.Config.Pools.$Name.ExcludeAlgorithm -icontains $Algorithm_Norm) -or
                                        ($DeviceAlgorithm.Count -and $DeviceAlgorithm -inotcontains $Algorithm_Norm) -or
                                        ($DeviceExcludeAlgorithm.Count -and $DeviceExcludeAlgorithm -icontains $Algorithm_Norm)
                                    ) -and (-not $CurrentlyBenchmarking.Count -or -not $CurrentlyBenchmarking.Where({$_.Algorithm -eq $Algorithm_Norm -and $RigModels -contains $_.DeviceModel}).Count)) {
                                    foreach ($Model in $RigModels) {
                                        $RigPowerAdd   = 0
                                        $RigSpeedAdd   = 0
                                        $RigRevenueAdd = 0
                                        $RigIsMRRPool  = $false
                                        $Global:ActiveMiners.Where({$_.Enabled -and $_.Speed -ne $null -and "$($_.BaseAlgorithm[0])" -eq $Algorithm_Norm -and $_.DeviceModel -eq $Model -and (-not $_.ExcludePoolName -or $_.ExcludePoolName -notmatch $Name)}).Foreach({
                                            $ThisSpeed = $_.Speed[0] * (1 - $_.DevFee."$($_.Algorithm[0])" / 100)
                                            if ($ThisSpeed -gt $RigSpeedAdd) {
                                                $RigIsMRRPool  = $_.Pool -contains "MiningRigRentals"
                                                $ThisProfit    = if ($RigIsMRRPool) {$SuggestedPrice * $ThisSpeed} else {$_.Profit}
                                                $RigPowerAdd   = $_.PowerDraw
                                                $RigSpeedAdd   = $ThisSpeed
                                                $RigRevenueAdd = $ThisProfit + $(if ($Session.Config.UsePowerPrice -and $_.Profit_Cost -ne $null -and $_.Profit_Cost -gt 0) {$_.Profit_Cost})

                                            }
                                        })
                                        $RigPower   += $RigPowerAdd
                                        $RigSpeed   += $RigSpeedAdd
                                        $RigRevenue += $RigRevenueAdd
                                        if ($RigIsMRRPool) {$RigMaxRevenueFactor = 20}
                                    }
                                    $RigModelsKey = "$($RigModels -join "-")"
                                    if ($RigSpeed -gt 0) {
                                        if (-not $RigNameStat.$RigModelsKey) {$RigNameStat | Add-Member $RigModelsKey ([PSCustomObject]@{}) -Force}
                                        $RigNameStat.$RigModelsKey | Add-Member $Algorithm_Norm ([PSCustomObject]@{Power=$RigPower;Speed=$RigSpeed;Revenue=$RigRevenue}) -Force
                                    } elseif ($RigRunMode -eq "update") {
                                        if ($RigNameStat.$RigModelsKey.$Algorithm_Norm) {
                                            $RigPower   = $RigNameStat.$RigModelsKey.$Algorithm_Norm.Power
                                            $RigSpeed   = $RigNameStat.$RigModelsKey.$Algorithm_Norm.Speed
                                            $RigRevenue = $RigNameStat.$RigModelsKey.$Algorithm_Norm.Revenue
                                        } else {
                                            $RigPower   = $RigDevicePowerDraw
                                            $RigRevenue = 0
                                            $RigMRRid   = $_.name
                                            $RigAlreadyCreated.Where({$_.type -eq $RigMRRid -and $_.price.BTC.autoprice}).Foreach({
                                                $RigSpeed = [double]$_.hashrate.advertised.hash * $(ConvertFrom-Hash "1$($_.hashrate.advertised.type)")
                                            })
                                        }
                                    }
                                }

                                $IsHandleRig    = ($RigRunMode -eq "update") -or ($MRRConfig.$RigName.AutoCreateAlgorithm -contains $Algorithm_Norm)

                                $RigPowerDiff   = 0
                                $RigMinPrice    = 0
                                $RigPrice       = 0

                                if ($RigSpeed -gt 0) {
                                    $RigPowerDiff   = if ($Session.Config.UsePowerPrice -and $RigPower -gt 0 -and $RigDevicePowerDraw -gt 0) {($RigPower - $RigDevicePowerDraw) * 24/1000 * $Session.PowerPriceBTC * $MRRConfig.$RigName.PowerDrawFactor} else {0}
                                    if ($RigPowerDiff -lt 0 -and $MRRConfig.$RigName.EnablePowerDrawAddOnly) {$RigPowerDiff = 0}
                                    $RigMinPrice    = [Math]::Max($RigDeviceRevenue24h * $RigPriceFactor + $RigPowerDiff,$RigDeviceRevenue24h) / $RigSpeed
                                    $RigPrice       = if ($MRRConfig.$RigName.PriceBTC -gt 0) {$MRRConfig.$RigName.PriceBTC / $RigSpeed} else {$RigMinPrice}
       
                                    if ($IsHandleRig -or (($RigRevenue -lt $RigMaxRevenueFactor*$RigDeviceRevenue24h) -and ($RigRevenue -ge $RigProfitBTCLimit -or $RigMinPrice -lt $SuggestedPrice))) {

                                        #Write-Log -Level Warn "$($Name): $RigRunMode $RigName $($_.name): Profit=$($RigRevenue) > $($RigProfitBTCLimit) $(if ($RigRevenue -gt $RigProfitBTCLimit) {"YES!!"} else {"no   "}), MinPrice=$($RigMinPrice) / $($RigMinPriceNew) => $($RigDevicePowerDraw) vs. $($RigPower), Sugg=$($SuggestedPrice), Speed=$($RigSpeed), MinHours=$($RigMinHours)"

                                        $RigMinPrice = [Math]::Max($RigPrice,$RigMinPrice)

                                        $PriceDivisor = 0
                                        while($PriceDivisor -lt $RigDivisors.Count -and $RigMinPrice -lt 1e-3) {
                                            $RigMinPrice *= 1000
                                            $RigPrice    *= 1000
                                            $PriceDivisor++
                                        }
                                        $RigMinPrice = [Decimal][Math]::Round($RigMinPrice,12)
                                        $RigPrice    = [Decimal][Math]::Round($RigPrice,12)

                                        $HashDivisor = 0
                                        while ($HashDivisor -lt $RigDivisors.Count -and $RigSpeed -gt 1000) {
                                            $RigSpeed /= 1000
                                            $HashDivisor++
                                        }

                                        if ($RigSpeed -lt 1) {$RigSpeed = [Math]::Floor($RigSpeed*100)/100}
                                        elseif ($RigSpeed -lt 100) {$RigSpeed = [Math]::Floor($RigSpeed*10)/10}
                                        else {$RigSpeed = [Math]::Floor($RigSpeed)}

                                        $Multiply = $RigDivisors[$HashDivisor].value / $RigDivisors[$PriceDivisor].value

                                        $RigMinHours = if ($RigMinPrice -eq 0 -or ($RigMinPrice * $RigSpeed * $MRRConfig.$RigName.MinHours * $Multiply / 24 -gt $RigMinProfit)) {$MRRConfig.$RigName.MinHours} else {[Math]::Ceiling($RigMinProfit*24/($RigMinPrice*$RigSpeed*$Multiply))}

                                        #Write-Log -Level Warn "$($Name): $RigRunMode $RigName $($_.name): Multiply=$($Multiply), MinPrice=$($RigMinPrice), Sugg=$($SuggestedPrice), Speed=$($RigSpeed), MinHours=$($RigMinHours)"

                                        if ($IsHandleRig -or $RigMinHours -le $MRRConfig.$RigName.AutoCreateMaxMinHours) {

                                            $RigMaxHours             = [Math]::Max($MRRConfig.$RigName.MinHours,$MRRConfig.$RigName.MaxHours)
                                            $Algorithm_Norm_Mapped   = Get-MappedAlgorithm $Algorithm_Norm
                                            $RigSubst["Algorithm"]   = $Algorithm_Norm_Mapped
                                            $RigSubst["AlgorithmEx"] = if ($_.display -match "\(([^\)]+)\)$") {"$($Algorithm_Norm_Mapped)$(if (Get-Coin $Matches[1]) {"/$($Matches[1].ToUpper())"} elseif ($Matches[1] -ne $Algorithm_Norm_Mapped) {"/$($Matches[1])"})"} else {$Algorithm_Norm_Mapped}
                                            $RigSubst["CoinInfo"]    = if ($_.display -match "\(([^\)]+)\)$") {"$(if (Get-Coin $Matches[1]) {$Matches[1].ToUpper()} else {$Matches[1]})"} else {""}
                                            $RigSubst["Display"]     = $_.display

                                            $RigGroupName = "RBM-$($RigName)"

                                            if (-not $Session.MRRRigGroups.$RigGroupName) {
                                                try {
                                                    $Result = Invoke-MiningRigRentalRequest "/riggroup" $API_Key $API_Secret -params @{name = $RigGroupName;enabled = 1;rental_limit = 1} -method "PUT" -Timeout 60
                                                    if ($Result.id) {
                                                        $RigCreated++
                                                        $Session.MRRRigGroups[$RigGroupName] = [int]$Result.id
                                                    }
                                                    Write-Log -Level Info "$($Name): $(if ($Result.id) {"Successfully created"} else {"Failed to create"}) rig group $($RigGroupName)"
                                                } catch {
                                                    if ($Error.Count){$Error.RemoveAt(0)}
                                                    Write-Log -Level Warn "$($Name): Unable to create rig group $($RigGroupName): $($_.Exception.Message)"
                                                }
                                            }

                                            $RigGroupId = if ($Session.MRRRigGroups.$RigGroupName) {[int]$Session.MRRRigGroups.$RigGroupName} else {0}
                                    
                                            if (-not $RigServer) {$RigServer = Get-MiningRigRentalServers -Region @(@($Session.Config.Region) + $Session.Config.DefaultPoolRegion.Where({$_ -ne $Session.Config.Region}) | Select-Object)}
                                            $CreateRig = if ($RigRunMode -eq "create") {
                                                @{
                                                    type          = $_.name
                                                    status	      = "disabled"
                                                    server	      = $RigServer.name
                                                    ndevices      = 1
                                                }
                                            } else {
                                                @{
                                                    ndevices    = 1
                                                }
                                            }

                                            #$CreateRig["riggroup"] = $RigGroupId

                                            if ($RigType -eq "GPU") {
                                                $CreateRig["device_ram"] = $RigDeviceRam
                                            }

                                            if ($RigRunMode -eq "create" -or $MRRConfig.$RigName.EnableUpdateTitle) {
                                                $CreateRig["name"] = Get-MiningRigRentalsSubst "$(if (-not $MRRConfig.$RigName.Title -or $MRRConfig.$RigName.Title -eq "%algorithm% mining") {"%algorithmex% mining with RainbowMiner rig %rigid%"} elseif ($MRRConfig.$RigName.Title -notmatch "%(algorithm|algorithmex|display)%") {"%algorithmex% $($MRRConfig.$RigName.Title)"} else {$MRRConfig.$RigName.Title})" -Subst $RigSubst
                                            }

                                            if ($RigRunMode -eq "create" -or $MRRConfig.$RigName.EnableUpdateDescription) {
                                                $CreateRig["description"] = Get-MiningRigRentalsSubst "$(if ($MRRConfig.$RigName.Description -notmatch "%workername%") {"$($MRRConfig.$RigName.Description)[$RigName]"} elseif ($MRRConfig.$RigName.Description -notmatch "\[%workername%\]") {$MRRConfig.$RigName.Description -replace "%workername%","[$RigName]"} else {$MRRConfig.$RigName.Description})" -Subst $RigSubst
                                            }

                                            $CreateRig["price"] = @{
                                                btc = @{
                                                    price       = $RigPrice
                                                    autoprice   = $MRRConfig.$RigName.EnableAutoPrice
                                                    minimum	    = if ($MRRConfig.$RigName.EnableMinimumPrice) {$RigMinPrice} else {0}
                                                }
                                                ltc = @{
                                                    enabled     = $MRRConfig.$RigName.PriceCurrencies -contains "LTC"
                                                    autoprice   = $true
                                                }
                                                eth = @{
                                                    enabled     = $MRRConfig.$RigName.PriceCurrencies -contains "ETH"
                                                    autoprice   = $true
                                                }
                                                dash = @{
                                                    enabled     = $MRRConfig.$RigName.PriceCurrencies -contains "DASH"
                                                    autoprice   = $true
                                                }
                                                bch = @{
                                                    enabled     = $MRRConfig.$RigName.PriceCurrencies -contains "BCH"
                                                    autoprice   = $true
                                                }
                                                type = $RigDivisors[$PriceDivisor].type
                                            }

                                            $CreateRig["hash"] = @{
                                                hash = $RigSpeed
                                                type = $RigDivisors[$HashDivisor].type
                                            }

                                            $CreateRig["minhours"] = $RigMinHours
                                            $CreateRig["maxhours"] = $RigMaxHours

                                            $CreateRig["extensions"] = ($MRRConfig.$RigName.AllowExtensions -and $Session.Config.Algorithms.$Algorithm_Norm.MRRAllowExtensions -eq $null) -or ($Session.Config.Algorithms.$Algorithm_Norm.MRRAllowExtensions)

                                            if ($RigRunMode -eq "create" -or $EnableUpdatePriceModifier) {
                                                $CreateRig["price"]["btc"]["modifier"] = if ($Session.Config.Algorithms.$Algorithm_Norm.MRRPriceModifierPercent -ne $null) {$Session.Config.Algorithms.$Algorithm_Norm.MRRPriceModifierPercent} else {$RigModifier}
                                                $CreateRig["price"]["btc"]["modifier"] = "$(if ($CreateRig["price"]["btc"]["modifier"] -gt 0) {"+"})$($CreateRig["price"]["btc"]["modifier"])"
                                            }

                                            $RigPool = $PoolsData | Where-Object {$_.Algorithm -eq $Algorithm_Norm} | Sort-Object -Descending {$_.Region -eq $Session.Config.Region}, {$ix = $Session.Config.DefaultPoolRegion.IndexOf($_.Region);[int]($ix -ge 0)*(100-$ix)} | Select-Object -First 1
                                            if ($RigRunMode -eq "create") {
                                                try {
                                                    $Result = Invoke-MiningRigRentalRequest "/rig" $API_Key $API_Secret -params $CreateRig -method "PUT" -Timeout 60
                                                    if ($Result.id) {
                                                        if ($RigGroupId) {
                                                            $RigGroupsAdd += [PSCustomObject]@{groupid = $RigGroupId;rigid = $Result.id}
                                                        }
                                                        Write-Log -Level Info "$($Name): Created rig #$($Result.id) $($Algorithm_Norm) [$($RigName)]: hash=$($CreateRig.hash.hash)$($CreateRig.hash.type), minimum=$($RigMinPrice)/$($RigDivisors[$PriceDivisor].type)/day, minhours=$($CreateRig.minhours)"
                                                        if ($RigPool) {
                                                            try {
                                                                $Result = Invoke-MiningRigRentalRequest "/rig/$($Result.id)/pool" $API_Key $API_Secret -params @{host=$RigPool.Host;port=$RigPool.Port;user=$RigPool.User;pass=$RigPool.pass} -method "PUT" -Timeout 60
                                                                if ($Result.success) {
                                                                    $RigCreated++
                                                                }
                                                                Write-Log -Level Info "$($Name): $(if ($Result.success) {"Update"} else {"Unable to add"}) pools of rig #$($Result.id) $($Algorithm_Norm) [$($RigName)]: $($RigPool.Host)"
                                                            } catch {
                                                                if ($Error.Count){$Error.RemoveAt(0)}
                                                                Write-Log -Level Warn "$($Name): Unable to add pools to $($Algorithm_Norm) rig for $($RigName): $($_.Exception.Message)"
                                                            }
                                                        }
                                                    } else {
                                                        Write-Log -Level Warn "$($Name): Unable to create $($Algorithm_Norm) rig for $($RigName)"
                                                    }
                                                } catch {
                                                    if ($Error.Count){$Error.RemoveAt(0)}
                                                    Write-Log -Level Warn "$($Name): Unable to create $($Algorithm_Norm) rig for $($RigName): $($_.Exception.Message)"
                                                }
                                                $RigCreated++
                                                if ($RigCreated -ge $MaxAPICalls) {return}

                                            } elseif ($RigRunMode -eq "update") {

                                                $RigMRRid = $_.name
                                                $RigAlreadyCreated.Where({$_.type -eq $RigMRRid -and $_.price.BTC.autoprice}).Foreach({

                                                    $RigPools_Id = [int]$_.id

                                                    if ($RigGroupId -and ([int]$_.riggroup -ne $RigGroupId)) {
                                                        $RigGroupsAdd += [PSCustomObject]@{groupid = $RigGroupId;rigid = $RigPools_Id}
                                                        if ([int]$_.riggroup) {
                                                            $RigGroupsRemove += [PSCustomObject]@{groupid = [int]$_.riggroup;rigid = $RigPools_Id}
                                                        }
                                                    }

                                                    if ($RigControl_Data -and ($_.status.status -eq "rented" -or $_.status.rented)) {
                                                        $RigControl_Data.LastReset = (Get-Date).ToUniversalTime()
                                                    }
                                                    $RigHashCurrent     = [double]$_.hashrate.advertised.hash * $(ConvertFrom-Hash "1$($_.hashrate.advertised.type)")
                                                    $RigMinPriceCurrent = [double]$_.price.BTC.minimum / $(ConvertFrom-Hash "1$($_.price.type)")

                                                    if ( (-not $RigMinPriceCurrent) -or
                                                         ([decimal]($RigSpeed*$RigDivisors[$HashDivisor].value) -ne [decimal]$RigHashCurrent) -or
                                                         ([Math]::Abs($RigMinPrice / $RigDivisors[$PriceDivisor].value / $RigMinPriceCurrent - 1) -gt ($MRRConfig.$RigName.AutoUpdateMinPriceChangePercent / 100)) -or
                                                         ($_.ndevices -ne $CreateRig.ndevices) -or 
                                                         ($CreateRig.device_ram -and ($_.device_ram -ne $CreateRig.device_ram)) -or
                                                         ($MRRConfig.$RigName.EnableUpdateTitle -and $_.name -ne $CreateRig.name) -or
                                                         ($MRRConfig.$RigName.EnableUpdateDescription -and $_.description -ne $CreateRig.description) -or
                                                         ($CreateRig.price.btc.modifier -ne $null -and $_.price.BTC.modifier -ne $CreateRig.price.btc.modifier) -or
                                                         ($RigServer -and ($_.region -ne $RigServer.region)) -or
                                                         ($_.extensions -ne $CreateRig.extensions)
                                                    ) {
                                                        $CreateRig["id"] = $RigPools_Id
                                                        if ($_.region -ne $RigServer.region) {$CreateRig["server"] = $RigServer.name}
                                                        $RigUpdated = $false
                                                        if ($MRRConfig.$RigName.EnableUpdateDescription -and $_.description -ne $CreateRig.description) {
                                                            if ($RigCreated -lt $MaxAPICalls) {
                                                                $RigUpdated = $true
                                                                try {
                                                                    $Result = Invoke-MiningRigRentalRequest "/rig/$($RigPools_Id)" $API_Key $API_Secret -params $CreateRig -method "PUT" -Timeout 60
                                                                } catch {
                                                                    if ($Error.Count){$Error.RemoveAt(0)}
                                                                    Write-Log -Level Warn "$($Name): Unable to update rig #$($RigPools_Id) $($Algorithm_Norm) [$($RigName)]: $($_.Exception.Message)"
                                                                }
                                                                $RigCreated++
                                                            }
                                                        } else {
                                                            $RigUpdated = $true
                                                            $RigsToUpdate += $CreateRig
                                                        }
                                                        if ($RigUpdated) {
                                                            Write-Log -Level Info "$($Name): Update rig #$($RigPools_Id) $($Algorithm_Norm) [$($RigName)]: hash=$($CreateRig.hash.hash)$($CreateRig.hash.type), minimum=$($RigMinPrice)/$($RigDivisors[$PriceDivisor].type)/day, minhours=$($CreateRig.minhours), ndevices=$($CreateRig.ndevices), device_ram=$($CreateRig.device_ram), modifier=$($CreateRig.price.btc.modifier), region=$($RigServer.region), extensions=$($CreateRig.extensions)"
                                                        }
                                                    }

                                                    if ($RigPool -and $RigCreated -lt $MaxAPICalls) {
                                                        $RigPoolCurrent = $RigPools[$RigPools_Id] | Where-Object {$_.user -match "mrx$" -or $_.pass -match "^mrx"  -or $_.pass -match "=mrx" -or $_.user -eq "rbm.worker1"} | Select-Object -First 1
                                                        if ((-not $RigPoolCurrent -and ($RigPools[$RigPools_Id] | Measure-Object).Count -lt 5) -or ($RigPoolCurrent -and ($RigPoolCurrent.host -ne $RigPool.Host -or $RigPoolCurrent.user -ne $RigPool.User -or $RigPoolCurrent.pass -ne $RigPool.Pass))) {
                                                            try {
                                                                $RigPriority = [int]$(if ($RigPoolCurrent) {
                                                                    $RigPoolCurrent.priority
                                                                } else {
                                                                    foreach($i in 0..4) {
                                                                        if (-not ($RigPools[$RigPools_Id] | Where-Object {$_.priority -eq $i})) {
                                                                            $i
                                                                            break
                                                                        }
                                                                    }
                                                                })
                                                                $Result = Invoke-MiningRigRentalRequest "/rig/$($RigPools_Id)/pool/$($RigPriority)" $API_Key $API_Secret -params @{host=$RigPool.Host;port=$RigPool.Port;user=$RigPool.User;pass=$RigPool.pass} -method "PUT" -Timeout 60
                                                                if ($Result.success) {
                                                                    $RigCreated++
                                                                }
                                                                Write-Log -Level Info "$($Name): $(if ($Result.success) {"Update"} else {"Unable to update"}) pools of rig #$($RigPools_Id) $($Algorithm_Norm) [$($RigName)]: $($RigPool.Host)"
                                                            } catch {
                                                                if ($Error.Count){$Error.RemoveAt(0)}
                                                                Write-Log -Level Warn "$($Name): Unable to update pools of rig #$($RigPools_Id) $($Algorithm_Norm) [$($RigName)]: $($_.Exception.Message)"
                                                            }                                                        
                                                        }

                                                        #temporary fix
                                                        @($RigPools[$RigPools_Id] | Where-Object {$_.user -eq "rbm.worker1"} | Select-Object) + @($RigPools[$RigPools_Id] | Where-Object {$_.pass -match "ID=mrx"} | Select-Object -Skip 1) | Foreach-Object {
                                                            if ($RigCreated -lt $MaxAPICalls) {
                                                                try {
                                                                    $Result = Invoke-MiningRigRentalRequest "/rig/$($RigPools_Id)/pool/$($_.priority)" $API_Key $API_Secret -method "DELETE" -Timeout 60
                                                                    if ($Result.success) {
                                                                        $RigCreated++
                                                                    }
                                                                    Write-Log -Level Info "$($Name): $(if ($Result.success) {"Delete"} else {"Unable to delete"}) pool $(1 + $_.priority) from rig #$($RigPools_Id) $($Algorithm_Norm) [$($RigName)]: $($RigPool.Host)"
                                                                } catch {
                                                                    if ($Error.Count){$Error.RemoveAt(0)}
                                                                    Write-Log -Level Warn "$($Name): Unable to delete pool $(1 + $_.priority) from rig #$($RigPools_Id) $($Algorithm_Norm) [$($RigName)]: $($_.Exception.Message)"
                                                                }
                                                            }
                                                        }
                                                    }
                                                })
                                            }
                                        }
                                    }
                                }
                            })
                        }
                    } catch {
                        if ($Error.Count){$Error.RemoveAt(0)}
                        Write-Log -Level Warn "$($Name): Unable to $($RigRunMode) rigs for $($RigName): $($_.Exception.Message)"
                    }
                }

                Set-MiningRigStat -Name $RigName -Data $RigNameStat > $null
            }
        }

        if ($RigsToUpdate.Count) {
            try {
                $Result = Invoke-MiningRigRentalRequest "/rig/batch" $API_Key $API_Secret -params @{"rigs"=$RigsToUpdate} -method "PUT" -Timeout 60
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Log -Level Warn "$($Name): Unable to update: $($_.Exception.Message)"
            }
        }


        if ($RigGroupsRemove.Count) {
            #POST /riggroup/[ID]/remove/[rigid1];[rigid2];[rigid3]...
            $RigGroupsRemove | Group-Object groupid | Foreach-Object {
                $RigGroupName = ($Session.MRRRigGroups.GetEnumerator() | Where-Object Value -eq $_.name).Name
                try {
                    $Result = Invoke-MiningRigRentalRequest "/riggroup/$($_.Name)/remove/$($_.Group.rigid -join ';')" $API_Key $API_Secret -method "POST" -Timeout 60
                    Write-Log -Level Info "$($Name): $(if ($Result.success) {"Successfully removed"} else {"Failed to remove"}) rigs $($_.Group.rigid -join ',') from group $($RigGroupName): $($_.Exception.Message)"
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "$($Name): Unable to remove rigs from group $($RigGroupName): $($_.Exception.Message)"
                }
            }
        }

        if ($RigGroupsAdd.Count) {
            #POST /riggroup/[ID]/add/[rigid1];[rigid2];[rigid3]...
            $RigGroupsAdd | Group-Object groupid | Foreach-Object {
                $RigGroupName = ($Session.MRRRigGroups.GetEnumerator() | Where-Object Value -eq $_.Name).Name
                try {
                    $Result = Invoke-MiningRigRentalRequest "/riggroup/$($_.Name)/add/$($_.Group.rigid -join ';')" $API_Key $API_Secret -method "POST" -Timeout 60
                    $FailedToAdd = @(Compare-Object @($Result.rigs.id | Select-Object) @($_.Group.rigid | Select-Object) | Where-Object SideIndicator -eq "=>" | Foreach-Object {$_.InputObject} | Select-Object)
                    $SuccessToAdd = @($_.Group.rigid | Where-Object {$_ -notin $FailedToAdd} | Select-Object)
                    if ($SuccessToAdd.Count) {
                        Write-Log -Level Info "$($Name): Successfully added rig$(if ($SuccessToAdd.Count -gt 1) {"s"}) $($SuccessToAdd -join ',') to group $($RigGroupName)"
                    }
                    if ($FailedToAdd.Count) {
                        Write-Log -Level Info "$($Name): Failed to add rig$(if ($FailedToAdd.Count -gt 1) {"s"}) $($FailedToAdd -join ',') to group $($RigGroupName)"
                    }
                } catch {
                    if ($Error.Count){$Error.RemoveAt(0)}
                    Write-Log -Level Warn "$($Name): Unable to add rigs to group $($RigGroupName): $($_.Exception.Message)"
                }
            }
        }
    }

    Set-ContentJson ".\Data\mrrcontrol.json" -Data $MRRRigControl > $null

    if (Test-Path Variable:MRRRigControl) {
        Remove-Variable "MRRRigControl"
    }

    $Session.MRRlastautoperation = Get-Date    
}

#
# auto benchmark missing algorithms
#
if ($EnableAutoBenchmark -and $Global:AllPools) {

    if (-not $PoolsData) {
        $PoolsData = Get-MiningRigRentalsPoolsData
    }

    if ($PoolsData -is [array]) {

        try {
            $Pool_Request_Nicehash = Invoke-RestMethodAsync "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info/" -tag "Nicehash" -timeout 20
        }
        catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Log -Level Warn "Pool API (Nicehash) has failed. "
        }

        $InactiveNicehashAlgorithms = @($Pool_Request_Nicehash.miningAlgorithms | Where-Object {[double]$_.paying -le 0 -or [double]$_.speed -le 0} | ForEach-Object {Get-Algorithm $_.algorithm} | Select-Object)
       
        $ActiveAlgorithms = @($Global:AllPools.Where({$_.Name -ne "MiningRigRentals"}).Foreach("Algorithm0") | Select-Object -Unique)

        $PoolsData.Where({$_.Algorithm -notin $ActiveAlgorithms -and ($_.Pool -ne "Nicehash" -or $_.Algorithm -notin $InactiveNicehashAlgorithms)}).Foreach({
            [PSCustomObject]@{
                Algorithm     = $_.Algorithm
			    Algorithm0    = $_.Algorithm
                CoinName      = $_.CoinName
                CoinSymbol    = $_.CoinSymbol
                Currency      = $_.Currency
                Price         = 1E-20
                StablePrice   = 1E-20
                MarginOfError = 0
                Protocol      = $_.Protocol
                Host          = $_.Host
                Port          = $_.Port
                User          = $_.User
                Pass          = $_.Pass
                Region        = $_.Region
                SSL           = $_.SSL
                Updated       = (Get-Date).ToUniversalTime()
                PoolFee       = 0
                EthMode       = $_.EthMode
                Name          = $Name
                Penalty       = 99
                PenaltyFactor = 0.01
			    Disabled      = $false
			    HasMinerExclusions = $false
			    Price_Bias    = 0.0
			    Price_Unbias  = 0.0
                Wallet        = $_.Wallet
                Worker        = $_.Worker
                Email         = ""
            }
        })
    }
}
