﻿using module .\Modules\MinerAPIs.psm1

param([int]$ThreadID,$APIHttpListener,$CurrentPwd)

Set-Location $CurrentPwd

if ($API.Debug -and -not $psISE -and $Session.LogLevel -ne "Silent") {Start-Transcript ".\Logs\API$($ThreadID)_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"}

$ProgressPreference = "SilentlyContinue"

$BasePath = Join-Path $PWD "web"

Set-OsFlags

$GCStopWatch = [System.Diagnostics.StopWatch]::New()
$GCStopWatch.Start()

$EnableFixBigInt = (Get-Command "Invoke-GetUrlAsync").parameters.fixbigint -ne $null

While ($APIHttpListener.IsListening -and -not $API.Stop) {
    $Data    = $null
    $Context = $null

    $task = $APIHttpListener.GetContextAsync()
    while(-not $Context -and -not $API.Stop){
        if($task.Wait(500)){$Context = $task.Result}
        if (-not $Context) {Start-Sleep -Milliseconds 100}
    }

    if ($API.Stop) {Break}

    $Response = $Context.Response
	[void]$Response.Headers.Add("Accept-Encoding","gzip");
	[void]$Response.Headers.Add("Server","RainbowMiner API on $($API.MachineName) [$($ThreadID)]");
	[void]$Response.Headers.Add("X-Powered-By","Microsoft PowerShell");

    $Request         = $Context.Request
	$InputStream     = $Request.InputStream
	$ContentEncoding = $Request.ContentEncoding

	# Get query and post parameters
	$Parameters = Get-QueryParameters -Request $Request -InputStream $InputStream -ContentEncoding $ContentEncoding

    # Determine the requested resource and parse query strings
    $Path = $Request.Url.LocalPath

    if ($API.Debug) {
        Write-ToFile -FilePath "Logs\requests$($ThreadID)_$(Get-Date -Format "yyyy-MM-dd").api.txt" -Message "$Path $($Parameters | ConvertTo-Json -Depth 10 -Compress)" -Append -Timestamp
    }

    # Create the defaults for associated settings
    $ContentType     = "application/json"
    $StatusCode      = [System.Net.HttpStatusCode]::OK
    $ContentFileName = ""

    if ($Path -match $API.RandTag) {$Path = "/stop";$API.APIauth = $false}

    $IsAuth = $true

    $RemoteIP   = "$($Request.RemoteEndPoint)" -replace ":\d+$" -replace "^\[.+\]$"
    $RemoteAuth = $API.RemoteAPI -and $API.APIauth
    
    if ($RemoteAuth -or $API.AllowIPs) {
    
        $IsAuth = (-not $RemoteAuth -or ($Context.User.Identity.IsAuthenticated -and $Context.User.Identity.Name -eq $API.APIuser -and $Context.User.Identity.Password -eq $API.APIpassword)) -and (-not $API.AllowIPs -or $RemoteIP -eq "" -or ($API.AllowIPs | Where-Object {$RemoteIP -like $_} | Measure-Object).Count)

        if ($API.MaxLoginAttempts -gt 0 -and $RemoteIP -ne "") {

            $AuthNow = (Get-Date).ToUniversalTime()

            if ($IsAuth) {
                if ($APIAccessDB.ContainsKey($RemoteIP)) {
                    if ($APIAccessDB[$RemoteIP].BlockedUntil -ne $null -and ($APIAccessDB[$RemoteIP].BlockedUntil -ge $AuthNow)) {
                        $IsAuth = $false
                    } else {
                        [void]$APIAccessDB.Remove($RemoteIP)
                    }
                }
            } else {
                if (-not $APIAccessDB.ContainsKey($RemoteIP)) {
                    $APIAccessDB[$RemoteIP] = [PSCustomObject]@{
                        FailedCount  = 0
                        LastFailed   = $null
                        BlockedUntil = $null
                    }
                } elseif ($APIAccessDB[$RemoteIP].LastFailed -ne $null -and ($APIAccessDB[$RemoteIP].LastFailed -lt $AuthNow.AddSeconds(-$API.BlockLoginAttemptsTime))) {
                    $APIAccessDB[$RemoteIP].FailedCount = 0
                    $APIAccessDB[$RemoteIP].BlockedUntil = $null
                }

                $APIAccessDB[$RemoteIP].FailedCount++
                $APIAccessDB[$RemoteIP].LastFailed = $AuthNow

                if ($APIAccessDB[$RemoteIP].FailedCount -gt $API.MaxLoginAttempts) {
                    $APIAccessDB[$RemoteIP].BlockedUntil = $AuthNow.AddSeconds($API.BlockLoginAttemptsTime)
                }
            }
        }
    }

    if(-not $IsAuth) {
        $Data        = "Access denied"
        $StatusCode  = [System.Net.HttpStatusCode]::Unauthorized
        $ContentType = "text/html"
    } else {
        # Set the proper content type, status code and data for each resource
        Switch($Path) {
        "/version" {
            $Data = ConvertTo-Json $API.Version -ErrorAction Ignore -Depth 10
            break
        }
        "/info" {
            $Data = $API.Info
            break
        }
        "/remoteip" {
            $Data = if ($API.RemoteIP) {ConvertTo-Json $API.RemoteIP -ErrorAction Ignore -Depth 10} else {$null}
            break
        }
        "/console" {
            $CountLines = 0
            $ConsoleTimestamp = [int]$(if (Test-Path ".\Logs\console.txt") {Get-UTCToUnix (Get-Item ".\Logs\console.txt" -ErrorAction Ignore).LastWriteTime} else {0})
            
            $CurrentConsole = if (-not $Parameters.ts -or ($ConsoleTimestamp -ne $Parameters.ts)) {[String]::Join("`n",@(Get-ContentByStreamReader -FilePath ".\Logs\console.txt" -ExpandLines | Where-Object {
                if ($_ -match "^\*+$") {$CountLines++}
                else {
                    $CountLines -eq 2 -and $_ -notmatch "console.txt"
                }
            } | Foreach-Object {
                $_ -replace "\x1B\[[;\d]+m"
            }))} else {'*'}

            $CurrentMiners = @()
            if (($IsLinux -or -not $Session.Config.ShowMinerWindow) -and $API.RunningMiners) {
                $RunningMiners = ConvertFrom-Json $API.RunningMiners -ErrorAction Ignore
                $CurrentMiners = @($RunningMiners | Where-Object {$_.LogFile -and (Test-Path $_.LogFile)} | Sort-Object -Property Name | Foreach-Object {
                    [PSCustomObject]@{
                        Name = "$($_.DeviceModel) $($_.BaseName)"
                        Content = [String]::Join("`n",@(Get-Content $_.LogFile -Tail 20 -ErrorAction Ignore | Foreach-Object {$_ -replace "\x1B\[[;\d]+m"}))
                    }
                })
            }

            $Data = ConvertTo-Json ([PSCustomObject]@{Content = $CurrentConsole; Miners = $CurrentMiners; Timestamp = $ConsoleTimestamp; CmdMenu = $API.CmdMenu; CmdKey = $API.CmdKey})

            $RunningMiners = $CurrentMiners = $CurrentConsole = $ConsoleTimestamp = $null
            Remove-Variable -Name RunningMiners, CurrentMiners, CurrentConsole, ConsoleTimestamp -ErrorAction Ignore
            break
        }
        "/cmdkey" {
            $API.CmdKey = $Parameters.CmdKey
            $Data = ConvertTo-Json $API.CmdKey
            break
        }
        "/cpuinfo" {
            $Data = $API.CPUinfo
            break
        }
        "/sysinfo" {
            $Data = if ($Session.SysInfo) {ConvertTo-Json $Session.SysInfo -ErrorAction Ignore -Depth 10} else {"{}"}
            break
        }
        "/uptime" {
            $Timer = Get-UpTime
            $Data = ConvertTo-Json ([PSCustomObject]@{
                                        AsString = "{0:d}.{1:d2}:{2:d2}:{3:d2}" -f ($Timer.Days,$Timer.Hours,$Timer.Minutes,$Timer.Seconds+[int]($Timer.Milliseconds/1000))
                                        Seconds  = [int64]$Timer.TotalSeconds
                                    }) -Depth 10
            $Timer = $null
            Remove-Variable -Name Timer -ErrorAction Ignore
            break
        }
        "/systemuptime" {
            $Timer = Get-UpTime -System
            $Data = ConvertTo-Json ([PSCustomObject]@{
                                        AsString = "{0:d}.{1:d2}:{2:d2}:{3:d2}" -f ($Timer.Days,$Timer.Hours,$Timer.Minutes,$Timer.Seconds+[int]($Timer.Milliseconds/1000))
                                        Seconds  = [int64]$Timer.TotalSeconds
                                    }) -Depth 10
            $Timer = $null
            Remove-Variable -Name Timer -ErrorAction Ignore
            break
        }
        "/isserver" {
            $Data = [PSCustomObject]@{Status=$API.IsServer} | ConvertTo-Json -Depth 10
            break
        }
        "/activeminers" {
            $Data = if ($API.ActiveMiners) {$API.ActiveMiners} else {"[]"}
            break
        }
        "/runningminers" {
            $Data = if ($API.RunningMiners) {$API.RunningMiners} else {"[]"}
            Break
        }
        "/failedminers" {
            $Data = if ($API.FailedMiners) {$API.FailedMiners} else {"[]"}
            Break
        }
        "/remoteminers" {
            if ($Parameters.Mode -eq "miners") {
                $AllMiners = @($API.RemoteMiners | Where-Object {$_.online} | Foreach-Object {
                    $Worker = $_.worker
                    $_.data | Foreach-Object {
                        $Data = ConvertTo-Json $_ -ErrorAction Ignore -Depth 10 | ConvertFrom-Json -ErrorAction Ignore
                        $Data | Add-Member Worker $Worker -Force -PassThru
                    }
                } | Select-Object)
                $Data = if ($AllMiners) {ConvertTo-Json $AllMiners -Depth 10} else {"[]"}
                $AllMiners = $null
                Remove-Variable -Name AllMiners -ErrorAction Ignore
            } else {
                $Data = if ($API.RemoteMiners) {ConvertTo-Json $API.RemoteMiners -Depth 10} else {"[]"}
            }
            Break
        }
        "/minersneedingbenchmark" {
            $Data = if ($API.MinersNeedingBenchmark) {$API.MinersNeedingBenchmark} else {"[]"}
            Break
        }
        "/minerinfo" {
            $Data = if (Test-Path ".\Data\minerinfo.json") {Get-ContentByStreamReader ".\Data\minerinfo.json"} else {"[]"}
            Break
        }
        "/minerspeeds" {
            $Data = if (Test-Path ".\Data\minerspeeds.json") {Get-ContentByStreamReader ".\Data\minerspeeds.json"} else {"[]"}
            Break
        }
        "/pools" {
            $Data = if ($API.Pools) {$API.Pools} else {"[]"}
            Break
        }
        "/allpools" {
            $Data = if ($API.AllPools) {$API.AllPools} else {"[]"}
            Break
        }
        "/newpools" {
            $Data = if (Test-Path ".\Data\newpools.json") {Get-ContentByStreamReader ".\Data\newpools.json"} else {"[]"}
            Break
        }
        "/algorithms" {
            $Data = if ($API.Algorithms) {ConvertTo-Json $API.Algorithms -Depth 10} else {"[]"}
            Break
        }
        "/miners" {
            $Data = if (Test-Path ".\Data\miners.json") {Get-ContentByStreamReader ".\Data\miners.json"} else {"[]"}
            Break
        }
        "/fastestminers" {
            $Data = if ($API.FastestMiners) {$API.FastestMiners} else {"[]"}
            Break
        }
        "/availminers" {
            $Data = if ($Session.AvailMiners) {ConvertTo-Json $Session.AvailMiners -Depth 10} else {"[]"}
        }
        "/availminerstats" {
            $Data = if ($Session.AvailMiners) {
                ConvertTo-Json @($Session.AvailMiners | Foreach-Object {
                    [PSCustomObject]@{
                        Name = $_
                        Statcount = (Get-ChildItem ".\Stats\Miners" -File -Filter "*-$($_)-*_Hashrate.txt" | Measure-Object).Count
                    }
                }) -Depth 10
            } else {"[]"}
        }
        "/disabled" {
            $Data = ConvertTo-Json @((Get-Stat -Disabled).Keys | Select-Object) -Depth 10
            Break
        }
        "/getwtmurls" {
            $WTMdata = Get-WhatToMineData
            $WTMdata_algos = @($WTMdata | Where-Object {$_.id} | Foreach-Object {if ($_.algo -eq "ProgPow") {"ProgPowZ","ProgPowSero"} else {$_.algo}} | Select-Object)
            $WTMdata_result = [hashtable]@{}
            if ($API.FastestMiners) {
                $API_FastestMiners = ConvertFrom-Json $API.FastestMiners -ErrorAction Ignore
                $API_FastestMiners | Where-Object {$_.BaseAlgorithm -notmatch '-' -and $WTMdata_algos -icontains $_.BaseAlgorithm} | Group-Object -Property DeviceModel | Foreach-Object {
                    $Group = $_.Group
                    $WTMdata_result[$_.Name] = "https://whattomine.com/coins?$(@($WTMdata | Where-Object {$_.id} | Foreach-Object {$Algo = @(if ($_.algo -eq "ProgPow") {"ProgPowZ","ProgPowSero"} else {$_.algo});if (($One = $Group | Where-Object {$_.BaseAlgorithm -in $Algo} | Select-Object -First 1) -and (($OneHR = if ($One.HashRates."$($One.BaseAlgorithm)") {$One.HashRates."$($One.BaseAlgorithm)"} elseif ($One.HashRates."$($One.BaseAlgorithm)-$($One.DeviceModel)") {$One.HashRates."$($One.BaseAlgorithm)-$($One.DeviceModel)"} else {$One.HashRates."$($One.BaseAlgorithm)-GPU"}) -gt 0)) {"$($_.id)=true&factor[$($_.id)_hr]=$([Math]::Round($OneHR/$_.factor,3))&factor[$($_.id)_p]=$([int]$One.PowerDraw)"} else {"$($_.id)=false&factor[$($_.id)_hr]=$(if ($_.id -eq "eth") {"0.000001"} else {"0"})&factor[$($_.id)_p]=0"}}) -join '&')&factor[cost]=$(if ($Session.Config.UsePowerPrice) {[Math]::Round($API.CurrentPowerPrice*$(if ($Session.Config.PowerPriceCurrency -ne "USD" -and $Rates."$($Session.Config.PowerPriceCurrency)") {$Rates.USD/$Rates."$($Session.Config.PowerPriceCurrency)"} else {1}),4)} else {0})&sort=Profitability24&volume=0&revenue=24h&dataset=$($Session.Config.WorkerName)&commit=Calculate"
                }
            }
            $Data = ConvertTo-Json $WTMdata_result -Depth 10
            
            $API_FastestMiners = $Group = $WTMdata = $WTMdata_algos = $WTMdata_result = $null
            Remove-Variable -Name API_FastestMiners, Group, WTMdata, WTMdata_algos, WTMdata_result -ErrorAction Ignore
            Break
        }
        "/loadconfigjson" {
            $ConfigName = if ($Parameters.ConfigName) {$Parameters.ConfigName} else {"Config"}

            $ConfigActual = Get-ConfigContent $ConfigName

            $Success = $false
            $Data = $null
            if ($Session.ConfigFiles[$ConfigName].Healthy -and (Test-Path $Session.ConfigFiles[$ConfigName].Path)) {
                try {
                    $Data = Get-ContentByStreamReader $Session.ConfigFiles[$ConfigName].Path -ThrowError
                    $Success = $true
                } catch {
                    Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").api.txt" -Message "[$ThreadID] Error reading config file $($Session.ConfigFiles[$ConfigName].Path): $($_.Exception.Message)" -Append -Timestamp
                }
            }

            if ($Success -and $Data) {
                $Data = ConvertTo-Json ([PSCustomObject]@{Success=$true;Data=$Data}) -Depth 10
            } else {
                $Data = ConvertTo-Json ([PSCustomObject]@{Success=$false}) -Depth 10
            }

            $ConfigName = $ConfigActual = $null
            Remove-Variable -Name ConfigName, ConfigActual -ErrorAction Ignore
            Break
        }
        "/saveconfigjson" {
            if ($API.LockConfig) {
                $Data = ConvertTo-Json ([PSCustomObject]@{Success=$false}) -Depth 10
                Break;
            }

            $ConfigName = if ($Parameters.ConfigName) {$Parameters.ConfigName} else {"Config"}

            $Success = $false
            if ("$($Parameters.Data)" -ne "") {
                try {
                    $Data = $Parameters.Data | ConvertFrom-Json -ErrorAction Stop
                    $ConfigActual = Get-ConfigContent $ConfigName
                    $ChangeTag = Get-ContentDataMD5hash($ConfigActual)
                    $Success = Set-ContentJson -PathToFile $Session.ConfigFiles[$ConfigName].Path -Data $Data -MD5hash $ChangeTag
                } catch {
                    Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").api.txt" -Message "[$ThreadID] Error writing config file $($Session.ConfigFiles[$ConfigName].Path): $($_.Exception.Message)" -Append -Timestamp
                }
            }

            $Data = ConvertTo-Json ([PSCustomObject]@{Success=$Success}) -Depth 10

            $ConfigName = $ConfigActual = $ChangeTag = $Success = $null
            Remove-Variable -Name ConfigName, ConfigActual, ChangeTag, Success -ErrorAction Ignore
            Break
        }
        "/loadconfig" {
            $ConfigName = if ($Parameters.ConfigName) {$Parameters.ConfigName} else {"Config"}
            if ($ConfigName -eq "Config") {
                $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1"
                $ConfigParameters = @{}
                $Session.DefaultValues.Keys | Where-Object {$_ -ne "SetupOnly"} | ForEach-Object {
                    $val = $Session.DefaultValues[$_]
                    if ($ConfigSetup.$_ -ne $null) {$val = $ConfigSetup.$_}
                    if ($val -is [array]) {$val = $val -join ','}
                    [void]$ConfigParameters.Add($_ , $val)
                }
                $ConfigActual = Get-ChildItemContent $Session.ConfigFiles["Config"].Path -Force -Parameters $ConfigParameters
                $Data = ConvertTo-Json $ConfigActual -Depth 10
            } else {
                $ConfigActual = Get-ConfigContent $ConfigName
                if (-not $Session.ConfigFiles[$ConfigName].Healthy) {
                    $Data = "[]"
                } else {
                    if ($ConfigName -eq "Miners") {
                        $Data = ConvertTo-Json @($ConfigActual.PSObject.Properties | Foreach-Object {
                            $MinerName = $_.Name -replace "-.+$"
                            $MinerDevice = $_.Name -replace "^.+?-"
                            $_.Value | Foreach-Object {
                                [PSCustomObject]@{
                                    Name               = $MinerName
                                    Device             = $MinerDevice
                                    MainAlgorithm      = $_.MainAlgorithm
                                    SecondaryAlgorithm = $_.SecondaryAlgorithm
                                    Params             = $_.Params
                                    MSIAprofile        = $_.MSIAprofile
                                    OCprofile          = $_.OCprofile
                                    Difficulty         = $_.Difficulty
                                    Penalty            = $_.Penalty
                                    Disable            = $_.Disable
                                    Tuning             = $_.Tuning
                                }
                            }
                        }) -Depth 10 -Compress
                    } elseif ($ConfigName -eq "Pools") {
                        $PoolSetup = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1"
                        if ($Parameters.PoolName) {
                            if ($Parameters.PoolName -in @("ls","list")) {
                                $RealConfig = if ($Session.UserConfig) {$Session.UserConfig} else {$Session.Config}
                                $Data = ConvertTo-Json @($ConfigActual.PSObject.Properties.Name | Foreach-Object {"$($_)$(if ($_ -in $RealConfig.PoolName) {"*"})"} | Sort-Object -Unique)
                            } else {
                                $Data = ConvertTo-Json ([PSCustomObject]@{
                                    PoolName = $Parameters.PoolName
                                    Config = $ConfigActual."$($Parameters.PoolName)"
                                    Setup  = $PoolSetup."$($Parameters.PoolName)"
                                }) -Depth 10 -Compress
                            }
                        } else {
                            $Data = ConvertTo-Json ([PSCustomObject]@{
                                Pools = $ConfigActual
                                Setup = $PoolSetup
                            }) -Depth 10 -Compress
                        }
                    } else {
                        $Data = ConvertTo-Json $ConfigActual -Depth 10 -Compress
                    }
                }
            }
            $ConfigName = $ConfigSetup = $ConfigParameters = $ConfigActual = $MinerName = $MinerDevice = $PoolSetup = $RealConfig = $null
            Remove-Variable -Name ConfigName, ConfigSetup, ConfigParameters, ConfigActual, MinerName, MinerDevice, PoolSetup, RealConfig -ErrorAction Ignore
            Break
        }
        "/saveconfig" {
            if ($API.LockConfig) {
                $Data = ConvertTo-Json ([PSCustomObject]@{Success=$false}) -Depth 10
                Break;
            }

            $ConfigName = if ($Parameters.ConfigName) {$Parameters.ConfigName} else {"Config"}

            $ConfigActual = Get-ConfigContent $ConfigName

            $ConfigChanged = 0

            if ($ConfigName -eq "Config") {

                $ConfigSetup = Get-ChildItemContent ".\Data\ConfigDefault.ps1"
                $ConfigParameters = @{}
                $Session.DefaultValues.Keys | Where-Object {$_ -ne "SetupOnly"} | ForEach-Object {
                    $val = $Session.DefaultValues[$_]
                    if ($ConfigSetup.$_ -ne $null) {$val = $ConfigSetup.$_}
                    if ($val -is [array]) {$val = $val -join ','}
                    [void]$ConfigParameters.Add($_ , $val)
                }

                $DataSaved = [hashtable]@{}

                $Parameters.PSObject.Properties.Name | Where-Object {$ConfigActual.$_ -ne $null} | Foreach-Object {
                    if ($_ -eq "APIpassword" -or $_ -eq "ServerPassword") {
                        if ($Parameters."Reset$_") {
                            $DataSaved[$_] = ""
                        } elseif ($Parameters.$_ -ne "") {
                            $DataSaved[$_] = $Parameters.$_
                        } else {
                            $DataSaved[$_] = $ConfigActual.$_
                        }                 
                    } else {
                        $DataSaved[$_] = "$(if ($Parameters.$_ -is [System.Collections.ArrayList]) {($Parameters.$_ | Foreach-Object {$_.Trim()}) -join ","} else {$Parameters.$_.Trim()})"
                    }

                    if ($ConfigParameters.ContainsKey($_) -and $DataSaved[$_] -eq $ConfigParameters[$_]) {
                        $DataSaved[$_] = "`$$_"
                    }

                    if ($DataSaved[$_] -ne "$($ConfigActual.$_)") {
                        $ConfigChanged++
                        $ConfigActual.$_ = $DataSaved[$_]
                    }
                }

                if ($ConfigActual.MinerStatusKey -eq "new") {
                    $ConfigActual.MinerStatusKey = Get-MinerStatusKey
                    $ConfigChanged++
                }

                #reset checkbox-arrays
                $Parameters.savearrays | Where-Object {$Parameters.$_ -eq $null} | Foreach-Object {
                    $DataSaved[$_] = ""
                    if ($DataSaved[$_] -ne "$($ConfigActual.$_)") {
                        $ConfigChanged++
                        $ConfigActual.$_ = $DataSaved[$_]
                    }
                }
            } elseif ($ConfigName -eq "Pools") {

                $PoolName = $Parameters.PoolName

                if ($PoolName -and $ConfigActual.$PoolName) {
                    $DataSaved = [PSCustomObject]@{}

                    $NewCoin = "$($Parameters.AddNewCoin)".Trim().ToUpper()

                    if ($NewCoin -ne "" -and $ConfigActual.$NewCoin -eq $null) {
                        $DataSaved | Add-Member $NewCoin "$($Parameters.AddNewCoinWallet.Trim())"
                        $DataSaved | Add-Member "$($NewCoin)-Params" "$($Parameters.AddNewCoinParams.Trim())"

                        $ConfigActual.$PoolName | Add-Member $NewCoin "$($Parameters.AddNewCoinWallet.Trim())" -Force
                        $ConfigActual.$PoolName | Add-Member "$($NewCoin)-Params" "$($Parameters.AddNewCoinParams.Trim())" -Force
                        $ConfigChanged++
                    }

                    $Parameters.PSObject.Properties.Name | Where-Object {$_ -notmatch "^AddNewCoin" -and ($ConfigActual.$PoolName.$_ -ne $null -or $_ -match "-Params$")} | Foreach-Object {
                        $Value = $Parameters.$_.Trim()

                        $Type = Switch($_) {
                            #Common
                            "Penalty" {"float"}
                            "MaxAllowedLuck" {"float"}
                            "MaxMarginOfError" {"float"}
                            "MaxTimeSinceLastBlock" {"timespan"}
                            "MaxTimeToFind" {"timespan"}
                            "SwitchingHysteresis" {"float"}

                            #MiningRigRentals
                            "PriceBTC" {"float"}
                            "PriceFactor" {"float"}
                            "AutoCreateMinProfitPercent" {"float"}
                            "AutoCreateMinCPUProfitBTC" {"float"}
                            "MinHours" {"int"}
                            "MaxHours" {"int"}
                            "AutoCreateMaxMinHours" {"int"}
                            "AutoPriceModifierPercent" {"float"}
                            "AutoUpdateMinPriceChangePercent" {"float"}
                            "PowerDrawFactor" {"float"}
                            "AutoExtendTargetPercent" {"float"}
                            "AutoExtendMaximumPercent" {"float"}
                            "AutoBonusExtendForHours" {"float"}
                            "AutoBonusExtendByHours" {"float"}
                            "PauseBetweenRentals" {"timespan"}
                            "ExtensionMessageTime" {"timespan"}
                            "PriceFactorMin" {"float"}
                            "PriceFactorDecayPercent" {"float"}
                            "PriceFactorDecayTime" {"timespan"}
                            "UpdateInterval" {"timespan"}

                            default {
                                if ($_ -match "^Allow|Enable|Disable") {"bool"} else {$null}
                            }
                        }

                        if ($Type) {
                            $Value = Switch($Type) {
                                "bool" {"$([int](Get-Yes $Value))"}
                                "float" {"$([double]($Value -replace ",","." -replace "[^0-9`-`.]+"))"}
                                "int" {"$([int]($Value -replace ",","." -replace "[^0-9`-`.]+"))"}
                                "timespan" {"$($Value -replace ",","." -replace "[^0-9smhdw`.]+"  -replace "([A-Z])[A-Z]+","`$1")"}
                                default {$Value}
                            }
                        }

                        if ($ConfigActual.$PoolName.$_ -ne $null) {
                            if ("$($Value)" -ne "$($ConfigActual.$PoolName.$_)") {
                                $ConfigActual.$PoolName.$_ = $Value
                                $DataSaved | Add-Member $_ $Value
                                $ConfigChanged++
                            }
                        } else {
                            $ConfigActual.$PoolName | Add-Member $_ "$($Value)" -Force
                            $DataSaved | Add-Member $_ $Value
                        }
                    }
                }

            } elseif ($ConfigName -eq "Coins") {
                $Parameters.Coins | Foreach-Object {
                    $CoinSymbol = $_
                    $CoinSymbol_Real = if ($CoinSymbol -eq "NewCoin") {"$($Parameters."Newcoin--CoinSymbol")".Trim().ToUpper()} else {$CoinSymbol}

                    if ($CoinSymbol_Real) {
                        if ($CoinSymbol -ne "NewCoin" -and $Parameters."$($CoinSymbol)--RemoveCoin") {
                            if ($ConfigActual.$CoinSymbol) {
                                [void]$ConfigActual.PSObject.Properties.Remove($CoinSymbol)
                                $ConfigChanged++
                            }
                        } else {
                            $DataSaved = [PSCustomObject]@{}
                            @("Wallet","Penalty","MinHashrate","MinWorkers","MaxTimeToFind","PostBlockMining","MinProfitPercent","EnableAutoPool","Comment") | Foreach-Object {
                                $Value = $Parameters."$($CoinSymbol)--$($_)"
                                $Value = Switch ($_) {
                                    "Penalty"          {"$([double]($Value -replace ",","." -replace "[^0-9`-`.]+"))"}
                                    "MinHashrate"      {"$($Value -replace ",","." -replace "[^0-9kMGTPH`.]+" -replace "([A-Z]{2})[A-Z]+","`$1")"}
                                    "MinWorkers"       {"$($Value -replace ",","." -replace "[^0-9kMGTPH`.]+" -replace "([A-Z])[A-Z]+","`$1")"}
                                    "MaxTimeToFind"    {"$($Value -replace ",","." -replace "[^0-9smhdw`.]+"  -replace "([A-Z])[A-Z]+","`$1")"}
                                    "PostBlockMining"  {"$($Value -replace ",","." -replace "[^0-9smhdw`.]+"  -replace "([A-Z])[A-Z]+","`$1")"}
                                    "MinProfitPercent" {"$([double]($Value -replace ",","." -replace "[^0-9`.]+"))"}
                                    "EnableAutoPool"   {"$([int](Get-Yes $Value))"}
                                    default {$Value.Trim()}
                                }
                                
                                $DataSaved | Add-Member $_ $Value

                                if ($CoinSymbol -eq "NewCoin" -or $Value -ne "$($ConfigActual.$CoinSymbol.$_)") {
                                    $ConfigChanged++
                                }
                            }

                            if ($CoinSymbol -eq "NewCoin") {
                                $i=0
                                do {
                                    $CoinSymbol = "$($CoinSymbol_Real)$(if ($i) {"-$($i)"})"
                                    $i++
                                } while ([bool]$ConfigActual.PSObject.Properties["$($CoinSymbol)"])
                            }
                            $ConfigActual | Add-Member $CoinSymbol $DataSaved -Force
                        }
                    }
                }
                $Sorted = [PSCustomObject]@{}
                $ConfigActual.PSObject.Properties.Name | Sort-Object | Foreach-Object {                
                    $Sorted | Add-Member $_ $ConfigActual.$_ -Force
                }
                $ConfigActual = $Sorted
            }

            if ($ConfigChanged -and ($ConfigPath = Get-ConfigPath $ConfigName)) {
                Set-ContentJson -PathToFile $ConfigPath -Data $ConfigActual > $null
                $Data = ConvertTo-Json ([PSCustomObject]@{Success=$true;Data=$DataSaved}) -Depth 10
            } else {
                $Data = ConvertTo-Json ([PSCustomObject]@{Success=$false}) -Depth 10
            }

            $ConfigName = $ConfigPath = $ConfigSetup = $ConfigParameters = $ConfigActual = $ConfigChanged = $DataSaved = $PoolName = $NewCoin = $Value = $Type = $CoinSymbol = $i = $Sorted = $null
            Remove-Variable -Name ConfigName, ConfigPath, ConfigSetup, ConfigParameters, ConfigActual, ConfigChanged, DataSaved, PoolName, NewCoin, Value, Type, CoinSymbol, i, Sorted -ErrorAction Ignore
            Break
        }
        "/loadminerstats" {
            

            Break
        }
        "/saveminerstats" {
            $Miner = "$(if ($Parameters.MinerName -and $Parameters.MinerName -ne "all") {$Parameters.MinerName -replace "[^A-Za-z0-9]"} else {"all"})"
            if ($Miner -eq "all" -or $Session.AvailMiners -contains $Miner) {
                $ZipDate     = Get-Date -Format "yyyy-MM-dd"
                $ZipFileName = "minerstats-$($Miner)-$($ZipDate).zip"
                $ZipPath     = Join-Path (Resolve-Path ".\Logs") $ZipFileName
                $StatsPath   = Join-Path (Resolve-Path ".\Stats\Miners") "*$(if ($Miner -ne "all") {"-$($Miner)-*"})_HashRate.txt"
                if ($IsWindows) {
                    $Params = @{
                        FilePath     = "7z.exe"
                        ArgumentList = "a `"$($ZipPath)`" `"$($StatsPath)`" -y -tzip"
                        WindowStyle  = "Hidden"
                    }
                } else {
                    $Params = @{
                        FilePath     = "7z"
                        ArgumentList = "a `"$($ZipPath)`" `"$($StatsPath)`" -y -tzip"
                    }
                }

                $Params.PassThru = $true
                (Start-Process @Params).WaitForExit()>$null

                $Data = [System.IO.File]::ReadAllBytes($ZipPath)
                $ContentType = Get-MimeType ".zip"
                $ContentFileName = $ZipFileName

                Remove-Item $ZipPath -Force -ErrorAction Ignore
            }
            $Miner = $ZipDate = $ZipFileName = $ZipPath = $StatsPath = $Params = $null
            Remove-Variable -Name Miner, ZipDate, ZipFileName, ZipPath, StatsPath, Params -ErrorAction Ignore
            Break
        }
        "/config" {
            $Data = ConvertTo-Json $Session.Config -Depth 10
            Break
        }
        "/userconfig" {
            $Data = if ($Session.UserConfig) {ConvertTo-Json $Session.UserConfig -Depth 10} else {ConvertTo-Json $Session.Config -Depth 10}
            Break
        }
        "/ocprofiles" {
            $Data = ConvertTo-Json @($Session.Config.OCProfiles.PSObject.Properties).Foreach({
                        [PSCustomObject]@{
                            Name             = $_.Name -replace "-.+$"
                            Device           = $(if ($_.Name -match "-(.+)$") {$Matches[1]} else {""})
                            PowerLimit       = $_.Value.PowerLimit
                            ThermalLimit     = $_.Value.ThermalLimit
                            MemoryClockBoost = $_.Value.MemoryClockBoost
                            CoreClockBoost   = $_.Value.CoreClockBoost
                            LockVoltagePoint = $_.Value.LockVoltagePoint
                            LockMemoryClock  = $_.Value.LockMemoryClock
                            LockCoreClock    = $_.Value.LockCoreClock
                        }
                    }) -Depth 10
            Break
        }
        "/downloadlist" {
            $Data = ConvertTo-Json @($API.DownloadList | Select-Object) -Depth 10
            Break
        }
        "/debug" {
            #create zip log and xxx out all purses
            $DebugDate     = Get-Date -Format "yyyy-MM-dd"
            $DebugPath     = Join-Path (Resolve-Path ".\Logs") "debug-$DebugDate"

            $PurgeStrings  = [System.Collections.Generic.List[string]]::new()
            $UserConfig    = if ($Session.UserConfig) {$Session.UserConfig | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore} else {$null}
            $RunningConfig = $Session.Config | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            @($RunningConfig,$UserConfig) | Where-Object {$_} | Foreach-Object {
                $CurrentConfig = $_
                @("Wallet","API_Key","MinerStatusKey","MinerStatusEmail","PushOverUserKey") | Where-Object {$CurrentConfig.$_} | Foreach-Object {[void]$PurgeStrings.Add($CurrentConfig.$_)}
                @("Username","APIPassword","ServerPassword") | Where-Object {$CurrentConfig.$_} | Foreach-Object {$CurrentConfig.$_ = "XXX"}
                $CurrentConfig.Pools.PSObject.Properties.Value | Foreach-Object {
                    $CurrentPool = $_
                    $CurrentPool.Wallets.PSObject.Properties.Value | Where-Object {$_} | Foreach-Object {[void]$PurgeStrings.Add([string]$_)}
                    @("Wallet","API_Key","API_Secret","OrganizationID","Password","PartyPassword","Email") | Where-Object {$CurrentPool.$_ -and $CurrentPool.$_.Length -gt 5} | Foreach-Object {[void]$PurgeStrings.Add([string]$CurrentPool.$_)}
                    @("Username") | Where-Object {$CurrentPool.$_} | Foreach-Object {$CurrentPool.$_ = "XXX"}
                }
            }

            $PurgeStrings = @($PurgeStrings | Select-Object -Unique | Where-Object {$_ -and $_.Length -gt 2} | Foreach-Object {[regex]::Escape($_)} | Sort-Object -Property {$_.Length})

            $PurgeStringsUnique = [System.Collections.Generic.List[string]]::new()

            While ($PurgeStrings) {
                $PurgeUnique = [System.Collections.Generic.List[string]]::new()
                for ($i=0;$i -lt $PurgeStrings.Count;$i++) {
                    if (-not (@($PurgeStrings | Select-Object -Skip ($i+1)) -match $PurgeStrings[$i])) {
                        [void]$PurgeUnique.Add($PurgeStrings[$i])
                    }
                }
                if ($PurgeUnique.Count) {
                    [void]$PurgeStringsUnique.AddRange($PurgeUnique)
                    $PurgeStrings = @(Compare-Object $PurgeStrings $PurgeUnique | Where-Object SideIndicator -eq "<=" | Foreach-Object {$_.InputObject} | Select-Object)
                } else {
                    [void]$PurgeStringsUnique.AddRange([string[]]$PurgeStrings)
                    $PurgeStrings = $null
                }
            }

            if (-not (Test-Path $DebugPath)) {New-Item $DebugPath -ItemType "directory" > $null}
            @(Get-ChildItem ".\Logs\*$(Get-Date -Format "yyyy-MM-dd")*.txt" | Select-Object) + @(Get-ChildItem ".\Logs\*$((Get-Date).AddDays(-1).ToString('yyyy-MM-dd'))*.txt" | Select-Object) | Sort-Object LastWriteTime | Foreach-Object {
                $LastWriteTime = $_.LastWriteTime
                $NewFile = "$DebugPath\$($_.Name)"
                $PurgeString = Get-ContentByStreamReader $_
                $PurgeStringsUnique.Where({$_ -and $_.Count}).Foreach({$PurgeString = $PurgeString -replace "($($_ -join "|"))","XXX"})
                $ip_regex = '\b(?!4\.)\d{1,3}(?:\.\d{1,3}){3}\b'
                $PurgeString = $PurgeString -replace "onnected to [^\s]+:\d+","onnected to XXX:NNN"  -replace "Server [^\s]+:\d+","Server XXX:NNN" -replace "Port=\d+","Port=NNN" -replace "(\d+\.){3}\d+:\d+","X.X.X.X:NNN" -replace $ip_regex,"X.X.X.X" -replace "([0-9a-f]+:){7}[0-9a-f]+","X:X:X:X:X:X:X:X"
                Out-File -InputObject $PurgeString -FilePath $NewFile
                Get-ChildItem $NewFile | Foreach-Object {$_.LastWriteTime = $_.CreationTime = $_.LastAccessTime = $LastWriteTime}
            }

            if ($Session.Config) {
                $NewFile = "$DebugPath\config.json"
                $PurgeString = $RunningConfig | ConvertTo-Json -Depth 10
                $PurgeStringsUnique.Where({$_ -and $_.Count}).Foreach({$PurgeString = $PurgeString -replace "($($_ -join "|"))","XXX"})
                Out-File -InputObject $PurgeString -FilePath $NewFile
            }

            if ($Session.UserConfig) {
                $NewFile = "$DebugPath\userconfig.json"
                $PurgeString = $UserConfig | ConvertTo-Json -Depth 10
                $PurgeStringsUnique.Where({$_ -and $_.Count}).Foreach({$PurgeString = $PurgeString -replace "($($_ -join "|"))","XXX"})
                Out-File -InputObject $PurgeString -FilePath $NewFile
            }

            $TestFileName = ".\Data\gpu-test.txt"

            "GPU-TEST $((Get-Date).ToUniversalTime())" | Out-File $TestFileName -Encoding utf8
            "="*80 | Out-File $TestFileName -Append -Encoding utf8
            " " | Out-File $TestFileName -Append -Encoding utf8

            if ($IsLinux) {

                try {
                    Invoke-Expression "lspci" | Select-String "VGA", "3D" | Tee-Object -Variable lspci | Tee-Object -FilePath ".\Data\gpu-count.txt" | Out-null
                } catch {
                }

                if ($API.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "NVIDIA"}) {

                    try {
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        "[nvidia-smi]" | Out-File $TestFileName -Append -Encoding utf8
                        "-"*80 | Out-File $TestFileName -Append -Encoding utf8
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        $Arguments = @(
                            '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
                            '--format=csv,noheader'
                        )
                        Invoke-Exe "nvidia-smi" -ArgumentList ($Arguments -join ' ') -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Out-File $TestFileName -Encoding utf8 -Append
                    } catch {
                    }

                }
            } elseif ($IsWindows) {

                try {
                    @(try {
                        Get-CimInstance CIM_VideoController | Where-Object {
                            (Get-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)" -name locationinformation).locationInformation -match "\d+,\d+,\d+"
                        } | Foreach-Object {"$("{0:X2}:{1:X2}.{2:d}" -f ($Matches[0] -split "," | Foreach-Object {[int]$_})) $(if ($_.AdapterCompatibility -match "Advanced Micro Devices") {"$($Matches[0]) "})$($_.Name)"} | Sort-Object
                    }
                    catch {
                    }) | Tee-Object -Variable lspci | Tee-Object -FilePath ".\Data\gpu-count.txt" | Out-Null
                } catch {
                }
               
                if ($API.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "AMD"}) {

                    try {
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        "[OdVII 8]" | Out-File $TestFileName -Append -Encoding utf8
                        "-"*80 | Out-File $TestFileName -Append -Encoding utf8
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        Invoke-Exe ".\Includes\odvii_$(if ([System.Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}).exe" -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines  | Out-File $TestFileName -Encoding utf8 -Append
                    } catch {
                    }

                }
                
                if ($API.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq "NVIDIA"}) {

                    try {    
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        "[nvidia-smi]" | Out-File $TestFileName -Append -Encoding utf8
                        "-"*80 | Out-File $TestFileName -Append -Encoding utf8
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        $Arguments = @(
                            '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
                            '--format=csv,noheader'
                        )
                        Invoke-Exe ".\Includes\nvidia-smi.exe" -ArgumentList ($Arguments -join ' ') -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Out-File $TestFileName -Encoding utf8 -Append
                    } catch {
                    }

                }
            }

            if ($API.AllDevices) {Set-ContentJson -PathToFile ".\Data\alldevices.json" -Data $API.AllDevices > $null} else {"[]" > ".\Data\alldevices.json"}

            $TestFileName = ".\Data\gpu-minerlist.txt"

            "GPU-MINERLIST $((Get-Date).ToUniversalTime())" | Out-File $TestFileName -Encoding utf8
            "="*80 | Out-File $TestFileName -Append -Encoding utf8
            " " | Out-File $TestFileName -Append -Encoding utf8

            if (Test-Path ".\Data\miners.json") {
                $API_Miners = ConvertFrom-Json "$(Get-ContentByStreamReader ".\Data\miners.json")" -ErrorAction Ignore
                $API_Miners | Where-Object {$_.ListDevices -ne $null} | Select-Object -Unique -Property BaseName,Path,ListDevices,ListPlatforms | Sort-Object -Property BaseName | Where-Object {Test-Path $_.Path} | Foreach-Object {
                    try {
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        "[$($_.BaseName)]" | Out-File $TestFileName -Append -Encoding utf8
                        "-"*80 | Out-File $TestFileName -Append -Encoding utf8
                        " " | Out-File $TestFileName -Append -Encoding utf8
                        if ($_.ListPlatforms) {
                            Invoke-Exe $_.Path -ArgumentList $_.ListPlatforms -WorkingDirectory $Pwd -ExpandLines | Out-File $TestFileName -Encoding utf8 -Append
                        }
                        Invoke-Exe $_.Path -ArgumentList $_.ListDevices -WorkingDirectory $Pwd -ExpandLines | Out-File $TestFileName -Encoding utf8 -Append
                    } catch {
                    }
                }
            }

            @(".\Data\lscpu.txt", ".\Data\gpu-count.txt", ".\Data\gpu-minerlist.txt", ".\Data\gpu-test.txt", ".\Data\alldevices.json", ".\Data\sysinfo.json") | Where-Object {Test-Path $_} | Foreach-Object {
                Copy-Item $_ $DebugPath -ErrorAction Ignore
            }

            if ($IsWindows) {
                $Params = @{
                    FilePath     = "7z.exe"
                    ArgumentList = "a `"$($DebugPath).zip`" `"$(Join-Path $DebugPath "*")`" -y -sdel -tzip"
                    WindowStyle  = "Hidden"
                }
            } else {
                $Params = @{
                    FilePath     = "7z"
                    ArgumentList = "a `"$($DebugPath).zip`" `"$(Join-Path $DebugPath "*")`" -y -sdel -tzip"
                }
            }

            $Params.PassThru = $true
            (Start-Process @Params).WaitForExit()>$null

            Remove-Item $DebugPath -Recurse -Force

            $Data = [System.IO.File]::ReadAllBytes("$($DebugPath).zip")
            $ContentType = Get-MimeType ".zip"
            $ContentFileName = "debug_$($DebugDate).zip"

            Remove-Item "$($DebugPath).zip" -Force -ErrorAction Ignore

            $API_Miners = $Arguments = $CurrentConfig = $CurrentPool = $DebugDate = $DebugPath = $ip_regex = $LastWriteTime = $NewFile = $Params = $PurgeString = $PurgeStrings = $PurgeStringsUnique = $PurgeUnique = $RunningConfig = $TestFileName = $UserConfig = $null
            Remove-Variable -Name API_Miners, Arguments, CurrentConfig, CurrentPool, DebugDate, DebugPath, ip_regex, LastWriteTime, NewFile, Params, PurgeString, PurgeStrings, PurgeStringsUnique, PurgeUnique, RunningConfig, TestFileName, UserConfig -ErrorAction Ignore
            Break
        }
        "/setup.json" {
            $Data = ConvertTo-Json ([PSCustomObject]@{Autostart=[PSCustomObject]@{Enable="0";ConfigName="All";DeviceName="GPU";WorkerName=""};Exclude=$Session.Config.ExcludeServerConfigVars;Config=(Get-ConfigContent "config");Pools=(Get-ConfigContent "pools");Coins=(Get-ConfigContent "coins");OCProfiles=(Get-ConfigContent "ocprofiles");Scheduler=(Get-ConfigContent "scheduler");Userpools=(Get-ConfigContent "userpools")}) -Depth 10
            $ContentFileName = "setup.json"
            Break
        }
        "/alldevices" {
            $Data = if ($API.AllDevices) {ConvertTo-Json $API.AllDevices -Depth 10} else {"[]"}
            Break
        }
        "/devices" {
            $Data = if ($API.Devices) {ConvertTo-Json $API.Devices -Depth 10} else {"[]"}
            Break
        }
        "/platforms" {
            $Data = if (Test-Path ".\Logs\platforms.json") {Get-Content ".\Logs\platforms.json" -Raw}
            Break
        }
        "/devicecombos" {
            $Data = if ($API.DeviceCombos) {ConvertTo-Json $API.DeviceCombos -Depth 10} else {"[]"}
            Break
        }
        "/getdeviceconfig" {
            $Data = if ($API.AllDevices) {
                $GPUDevices = $API.AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -in @("AMD","INTEL","NVIDIA")}
                $CPUDevice  = $API.AllDevices | Where-Object {$_.Type -eq "Cpu"} | Select-Object -First 1
                ConvertTo-Json @(@("CPU") + @($GPUDevices.Vendor | Select-Object -Unique | Sort-Object) + @($GPUDevices.Model | Select-Object -Unique | Sort-Object) + @($GPUDevices.Name | Select-Object -Unique | Sort-Object) | Foreach-Object {
                    if ($_ -eq "CPU") {
                        [PSCustomObject]@{Name=$_;Selected=$($_ -in $Session.Config.DeviceName);Excluded=$($_ -in $Session.Config.ExcludeDeviceName);Cores=$CPUDevice.Data.Cores;Threads=$CPUDevice.Data.Threads}
                    } else {
                        [PSCustomObject]@{Name=$_;Selected=$($_ -in $Session.Config.DeviceName);Excluded=$($_ -in $Session.Config.ExcludeDeviceName)}
                    }
                }) -Depth 10
                $GPUDevices = $CPUDevices = $null
                Remove-Variable -Name GPUDevices, CPUDevice -ErrorAction Ignore
            } else {"[]"}
            Break
        }
        "/stats" {
            $Data = ConvertTo-Json $StatsCache -Depth 10
            Break
        }
        "/totals" {
            $Totals = @((Get-Stat -Totals).Values | Foreach-Object {$_.Power *= 24} | Select-Object)
            $Data = ConvertTo-Json @((Get-Stat -Totals).Values | Select-Object) -Depth 10
            Break
        }
        "/totalscsv" {
            $Data = @((Get-Stat -Totals).Values | Sort-Object Pool | Select-Object) | ConvertTo-Csv -NoTypeInformation -ErrorAction Ignore
            $Data = $Data -join "`r`n"
            $ContentType = "text/csv"
            $ContentFileName = "totals_$(Get-Date -Format "yyyy-MM-dd_HHmmss").txt"
            Break
        }
        "/earnings" {
            $Data = ""
            if (Test-Path "Stats\Balances\Earnings.csv") {

                $reader = $null
                try {
                    $APIData = $null
                    if ($APICacheDB.ContainsKey("earnings")) {
                        $APIData = $APICacheDB["earnings"]
                    }
                    if (-not $APIData -or $APIData.LastWrite -lt (Get-ChildItem "Stats\Balances\Earnings.csv" -File).LastWriteTimeUtc) {
                        $Earnings = [System.Collections.Generic.List[PSCustomObject]]::new()
                        $sourceFile = "Stats\Balances\Earnings.csv"

                        $reader = [System.IO.StreamReader]::new($sourceFile)
                        $header = $reader.ReadLine()

                        if (-not $header) {
                            throw "Earnings.csv is empty."
                        }

                        $columns = $header -split ',' | Foreach-Object {$_.Trim('"')}

                        while (!$reader.EndOfStream) {
                            $line = $reader.ReadLine()
                            $line = $line -replace "^[^`"]+" -replace "[^`"]+$"
                            if ([string]::IsNullOrWhiteSpace($line)) { continue }

                            $fields = $line -split ','
                            if ($fields.Count -ne $columns.Count) { continue }  # skip malformed rows

                            $row = @{}
                            for ($i = 0; $i -lt $columns.Count; $i++) {
                                $row[$columns[$i]] = $fields[$i].Trim('"')
                            }

                            $Rate = $Rates."$($row.Currency)"

                            [void]$Earnings.Add([PSCustomObject]@{
                                Date          = if ($Parameters.as_csv) {[DateTime]$row.Date} else {([DateTime]$row.Date).ToString("yyyy-MM-dd HH:mm:ss")}
                                Date_UTC      = if ($Parameters.as_csv) {[DateTime]$row.Date_UTC} else {([DateTime]$row.Date_UTC).ToString("yyyy-MM-dd HH:mm:ss")}
                                PoolName      = $row.PoolName
                                Currency      = $row.Currency
                                Balance       = [Decimal]$row.Balance
                                Paid          = [Decimal]$row.Paid
                                Earnings      = [Decimal]$row.Earnings
                                Value         = [Decimal]$row.Value
                                Balance_BTC   = [Decimal]$(if ($Rate) {$row.Balance / $Rate} else {0})
                                Paid_BTC      = [Decimal]$(if ($Rate) {$row.Paid / $Rate} else {0})
                                Earnings_BTC  = [Decimal]$(if ($Rate) {$row.Earnings / $Rate} else {0})
                                Value_BTC     = [Decimal]$(if ($Rate) {$row.Value / $Rate} else {0})
                            })
                        }

                        $CacheTime = (Get-Date).ToUniversalTime()
                        if (-not $APIData) {
                            $APICacheDB["earnings"] = [PSCustomObject]@{LastWrite = $CacheTime; LastAccess = $CacheTime; Data = $Earnings}
                        } else {
                            $APIData.LastWrite = $APIData.LastAccess = $CacheTime
                            $APIData.Data = $null
                            $APIData.Data = $Earnings
                        }
                    } else {
                        $Earnings = $APIData.Data
                        $APIData.LastAccess = (Get-Date).ToUniversalTime()
                    }
                } catch {
                    
                } finally {
                    if ($reader) { $reader.Close() }
                }

                if ($Parameters.as_csv) {
                    $Data = $Earnings | ConvertTo-Csv -NoTypeInformation -UseCulture -ErrorAction Ignore
                    $Data = $Data -join "`r`n"
                    $ContentType = "text/csv"
                    $ContentFileName = "earnings_$(Get-Date -Format "yyyy-MM-dd_HHmmss").csv"
                } else {
                    $Filter = if ($Parameters.filter) { $Parameters.filter | ConvertFrom-Json -ErrorAction Ignore } else { $null }
                    $Sort   = if ($Parameters.sort) { $Parameters.sort } else { "Date" }
                    $Order  = $Parameters.order -eq "desc"

                    $TotalNotFiltered = $Earnings.Count

                    # Filter manually if filter exists
                    if ($Filter) {
                        $filtered = [System.Collections.Generic.List[PSObject]]::new()
                        foreach ($item in $Earnings) {
                            $match = $true
                            foreach ($prop in $Filter.PSObject.Properties.Name) {
                                if ($item.$prop -ne $Filter.$prop) {
                                    $match = $false
                                    break
                                }
                            }
                            if ($match) { $filtered.Add($item) }
                        }
                        $Earnings = $filtered
                    }

                    $Total = $Earnings.Count

                    $Earnings = $Earnings | Sort-Object -Property $Sort -Descending:$Order

                    # Apply paging
                    if ($Parameters.limit) {
                        $Earnings = $Earnings | Select-Object -Skip ([int]$Parameters.offset) -First ([int]$Parameters.limit)
                    }
                    if (-not $Earnings.Count) {
                        $Earnings = @()
                    } elseif ($Earnings.Count -eq 1) {
                        $Earnings = @($Earnings)
                    }

                    $Data = [PSCustomObject]@{
                        total = $Total
                        totalNotFiltered = $TotalNotFiltered
                        rows = $Earnings
                    } | ConvertTo-Json -Depth 10
                }

                $reader = $Earnings = $SourceFile = $header = $columns = $line = $row = $Filter = $Sort = $Order = $TotalNotFiltered = $filtered = $item = $null
                Remove-Variable -Name reader, Earnings, SourceFile, header, columns, line, row, Filter, Sort, Order, TotalNotFiltered, filtered, item -ErrorAction Ignore
            }
            Break
        }
        "/sessionvars" {           
            $SessionVars = [hashtable]@{}
            $Session.Keys | Where-Object {$Session[$_] -isnot [hashtable] -and $Session[$_] -isnot [array] -and $Session[$_] -isnot [pscustomobject] -and $Session[$_] -isnot [System.Collections.ArrayList] -and $Session[$_] -ne $null} | Sort-Object | Foreach-Object {$SessionVars[$_] = $Session[$_]}
            $Data = ConvertTo-Json $SessionVars -Depth 10

            $SessionVars = $null
            Remove-Variable -Name SessionVars -ErrorAction Ignore
            Break
        }
        "/session" {
            $Data = ConvertTo-Json $Session -Depth 10
            Break
        }
        "/gc" {
            $Data = ConvertTo-Json $SyncCache -Depth 10
            Break
        }
        "/watchdogtimers" {
            $Data = if ($API.WatchdogTimers) {ConvertTo-Json $API.WatchdogTimers -Depth 2 -WarningAction Ignore} else {"[]"}
            Break
        }
        "/crashcounter" {
            $Data = if ($API.CrashCounter) {ConvertTo-Json $API.CrashCounter -Depth 2 -WarningAction Ignore} else {"[]"}
            Break
        }
        "/balances" {
            if ($Parameters.raw) {
                $Data = if ($API.Balances) {$API.Balances} else {"[]"}
                Break
            }
            if ($API.Balances) {$Balances = ConvertFrom-Json $API.Balances -ErrorAction Ignore}
            $Balances = $Balances | Where-Object {($Parameters.add_total -or $_.Name -notmatch "^\*") -and ($Parameters.add_wallets -or $_.BaseName -ne "Wallet")}

            if ($Session.Config.ShowWalletBalances -and $Parameters.add_total -and -not $Parameters.add_wallets) {
                $Balances = $Balances | Where-Object {$_.BaseName -eq "TotalPools" -or $_.Name -notmatch "^\*"}
            }

            if ($Parameters.consolidate) {
                $Balances = $Balances | Where-Object {$_.Name -notmatch "^\*"} | Group-Object -Property Name | Foreach-Object {
                    $BalanceGroup = $_.Group | Where-Object {$Rates."$($_.Currency)"}
                    [PSCustomObject]@{
                        Name = $_.Name
                        Total = [Decimal]($BalanceGroup | Foreach-Object {$_.Total / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                        Paid  = [Decimal]($BalanceGroup | Foreach-Object {$_.Paid / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                        Earnings  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                        Earnings_1h  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_1h / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                        Earnings_1d  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_1d / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                        Earnings_1w  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_1w / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                        Earnings_Avg = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_Avg / $Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                    }
                }
            }
                                        
            if ($Parameters.as_csv) {
                if (-not $Parameters.consolidate) {
                    $Balances = $Balances | Foreach-Object {
                        $Rate = $Rates."$($_.Currency)"
                        [PSCustomObject]@{
                            Name = $_.Name
                            Currency = $_.Currency
                            Started = [DateTime]$_.Started
                            Total = [Decimal]$_.Total
                            Paid  = [Decimal]$_.Paid
                            Earnings  = [Decimal]$_.Earnings
                            Earnings_1h  = [Decimal]$_.Earnings_1h
                            Earnings_1d  = [Decimal]$_.Earnings_1d
                            Earnings_1w  = [Decimal]$_.Earnings_1w
                            Earnings_Avg  = [Decimal]$_.Earnings_Avg
                            Total_BTC = [Decimal]$(if ($Rate) {$_.Total / $Rate} else {0})
                            Paid_BTC = [Decimal]$(if ($Rate) {$_.Paid / $Rate} else {0})
                            Earnings_BTC  = [Decimal]$(if ($Rate) {$_.Earnings / $Rate} else {0})
                            Earnings_1h_BTC  = [Decimal]$(if ($Rate) {$_.Earnings_1h / $Rate} else {0})
                            Earnings_1d_BTC  = [Decimal]$(if ($Rate) {$_.Earnings_1d / $Rate} else {0})
                            Earnings_1w_BTC  = [Decimal]$(if ($Rate) {$_.Earnings_1w / $Rate} else {0})
                            Earnings_Avg_BTC = [Decimal]$(if ($Rate) {$_.Earnings_Avg / $Rate} else {0})
                        }
                    }
                }
                $ContentType = "text/csv"
                $ContentFileName = "$(if ($Parameters.consolidate) {"consolidate"} else {"balances"})_$(Get-Date -Format "yyyy-MM-dd_HHmmss").csv"
                $Data = $Balances | ConvertTo-Csv -NoTypeInformation -UseCulture -ErrorAction Ignore
                $Data = $Data -join "`r`n"
            } else {
                if (-not $Parameters.consolidate) {
                    $Balances = $Balances | ConvertTo-Json -Compress -Depth 10 | ConvertFrom-Json
                }
                if ($Parameters.add_btc) {
                    $Balances | Foreach-Object {
                        $Rate = if ($_.Currency) {$Rates."$($_.Currency)"} else {0}
                        $_ | Add-Member -NotePropertyMembers @{
                            Total_BTC = [Decimal]$(if ($Rate) {$_.Total / $Rate} else {0})
                            Paid_BTC = [Decimal]$(if ($Rate) {$_.Paid / $Rate} else {0})
                            Earnings_BTC  = [Decimal]$(if ($Rate) {$_.Earnings / $Rate} else {0})
                            Earnings_1h_BTC  = [Decimal]$(if ($Rate) {$_.Earnings_1h / $Rate} else {0})
                            Earnings_1d_BTC  = [Decimal]$(if ($Rate) {$_.Earnings_1d / $Rate} else {0})
                            Earnings_1w_BTC  = [Decimal]$(if ($Rate) {$_.Earnings_1w / $Rate} else {0})
                            Earnings_Avg_BTC = [Decimal]$(if ($Rate) {$_.Earnings_Avg / $Rate} else {0})
                        } -Force
                    }
                }
                if ($Parameters.add_total) {
                    $Balances | Where-Object {$_.Name -notmatch "^\*"} | Foreach-Object {
                        if ($_.Last_Earnings -ne $null) {[void]$_.PSObject.Properties.Remove("Last_Earnings")}
                        if ($_.Payouts -ne $null) {[void]$_.PSObject.Properties.Remove("Payouts")}
                    }
                }
                $Balances | Where-Object {$_.Started} | Foreach-Object {$_.Started = ([DateTime]$_.Started).ToString("yyyy-MM-dd HH:mm:ss")}
                $Data = ConvertTo-Json @($Balances | Select-Object) -Depth 10
            }

            $BalanceGroup = $Balances = $Rate = $null
            Remove-Variable -Name BalanceGroup, Balances, Rate -ErrorAction Ignore
            Break
        }
        "/payouts" {
            if ($API.Balances) {$Balances = ConvertFrom-Json $API.Balances}
            $Data = ConvertTo-Json @($Balances | Where {$_.Currency -ne $null -and $_.Payouts} | Select-Object BaseName,Currency,Payouts | Foreach-Object {
                $Balance_BaseName = $_.BaseName
                $Balance_Currency = $_.Currency
                $_.Payouts | Foreach-Object {
                    [PSCustomObject]@{
                        Name     = $Balance_BaseName
                        Currency = $Balance_Currency
                        Date     = $_.Date.ToString("yyyy-MM-dd HH:mm:ss")
                        Amount   = [Double]$_.amount
                        Txid     = $_.Txid
                    }
                }
            } | Sort-Object Date,Name,Currency | Select-Object) -Depth 10

            $Balances = $Balance_BaseName = $Balance_Currency = $null
            Remove-Variable -Name Balances, Balance_BaseName, Balance_Currency -ErrorAction Ignore
            Break
        }
        "/rates" {
            if ($Parameters.format -eq "table") {
                $CurrentRates = $API.ActualRates.PSObject.Properties.Name | Sort-Object | Foreach-Object {[PSCustomObject]@{symbol=$_;rate=$API.ActualRates.$_}}
                $Data = foreach ($sym in @($Rates.Keys)) {
                    $val = [PSCustomObject]@{
                        symbol = $sym
                    }
                    $rate = $Rates.$sym
                    $CurrentRates | Foreach-Object {
                        $rate_sym = if ($rate) {$Rates."$($_.symbol)" / $rate} else {0}
                        $val | Add-Member "rate$($_.symbol)" $rate_sym
                    }
                    $val
                }
                $Data = ConvertTo-Json @($Data) -Depth 10
            } else {
                $Data = ConvertTo-Json $Rates -Depth 10
            }
            $CurrentRates = $rate = $rate_sym = $val = $null
            Remove-Variable -Name CurrentRates, rate, rate_sym, val -ErrorAction Ignore
            Break
        }
        "/asyncloaderjobs" {
            $Data = ConvertTo-Json @($Asyncloader.Jobs).Where({$_}) -Depth 10
            Break
        }
        "/decsep" {
            $Data = (Get-Culture).NumberFormat.NumberDecimalSeparator | ConvertTo-Json -Depth 10
            Break
        }
        "/getminerlog" {
            $Data = [PSCustomObject]@{Status=$false;Content=""}
            if ($Parameters.logfile -and ($Parameters.logfile -match "\d+_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.txt$") -and (Test-Path (Join-Path ".\Logs" $Parameters.logfile))) {
                $Data.Status  = $true
                $Data.Content = Get-ContentByStreamReader (Join-Path ".\Logs" $Parameters.logfile)
            }
            $Data = ConvertTo-Json $Data
            Break
        }
        "/minerstats" {
            [hashtable]$JsonUri_Dates = @{}
            [hashtable]$Miners_List = @{}
            [System.Collections.ArrayList]$Out = @()
            if (Test-Path ".\Data\miners.json") {
                $API_Miners = ConvertFrom-Json "$(Get-ContentByStreamReader ".\Data\miners.json")" -ErrorAction Ignore

                $API_Miners | Where-Object {$_.DeviceModel -notmatch '-' -or $Session.Config.MiningMode -eq "legacy"} | Foreach-Object {
                    if (-not $JsonUri_Dates.ContainsKey($_.BaseName)) {
                        $JsonUri = Join-Path (Get-MinerInstPath $_.Path) "_uri.json"
                        $JsonUri_Dates[$_.BaseName] = if (Test-Path $JsonUri) {(Get-ChildItem $JsonUri -ErrorAction Ignore).LastWriteTimeUtc} else {$null}
                    }
                    [String]$Algo = $_.HashRates.PSObject.Properties.Name | Select -First 1
                    [String]$SecondAlgo = ''
                    $Speed = @($_.HashRates.$Algo)
                    $Ratio = @($_.Ratios.$Algo)
                    if (($_.HashRates.PSObject.Properties.Name | Measure-Object).Count -gt 1) {
                        $SecondAlgo = $_.HashRates.PSObject.Properties.Name | Select -Index 1
                        $Speed += $_.HashRates.$SecondAlgo
                        $Ratio += $_.Ratios.$SecondAlgo
                    }
                        
                    $Miners_Key = "$($_.Name)_$($Algo -replace '\-.*$')"
                    if ($JsonUri_Dates[$_.BaseName] -ne $null -and -not $Miners_List.ContainsKey($Miners_Key)) {
                        $Miners_List[$Miners_Key] = $true
                        $Miner_Path = Get-ChildItem "Stats\Miners\*-$($Miners_Key)_HashRate.txt" -ErrorAction Ignore
                        $Miner_Failed = @($_.HashRates.PSObject.Properties.Value) -contains 0 -or @($_.HashRates.PSObject.Properties.Value) -contains $null
                        $Miner_NeedsBenchmark = $Miner_Path -and $Miner_Path.LastWriteTimeUtc -lt $JsonUri_Dates[$_.BaseName]
                        $Miner_DeviceModel = if ($Session.Config.MiningMode -eq "legacy" -and $_.DeviceModel -match "-") {$API.DevicesToVendors."$($_.DeviceModel)"} else {$_.DeviceModel}
                        if ($Miner_DeviceModel -notmatch "-" -or $Miner_Path) {
                            [void]$Out.Add([PSCustomObject]@{
                                BaseName = $_.BaseName
                                Name = $_.Name
                                Algorithm = $Algo
                                SecondaryAlgorithm = $SecondAlgo
                                Speed = $Speed
                                Ratio = $Ratio
                                PowerDraw = $_.PowerDraw
                                Devices     = $Miner_DeviceModel
                                DeviceModel = $_.DeviceModel
                                MSIAprofile = $_.MSIAprofile
                                OCprofile   = $_.OCprofile
                                Benchmarking = -not $Miner_Path
                                NeedsBenchmark = $Miner_NeedsBenchmark
                                BenchmarkFailed = $Miner_Failed
                                Benchmarked = if ($_.Benchmarked) {$_.Benchmarked.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")} else {$null}
                                LogFile     = "$(if ($_.LogFile -and (Test-Path (Join-Path ".\Logs" $_.LogFile))) {$_.LogFile})"
                            })
                        }
                    }
                }
            }
            $Data = ConvertTo-Json @($Out) -Depth 10
            $Out.Clear()
            $JsonUri_Dates.Clear()
            $Miners_List.Clear()

            $Algo = $API_Miners = $JsonUri = $JsonUri_Dates = $Miner_DeviceModel = $Miner_Failed = $Miner_NeedsBenchmark = $Miner_Path = $Miners_Key = $Miners_List = $Out = $Ratio = $SecondAlgo = $Speed = $null
            Remove-Variable -Name Algo, API_Miners, JsonUri, JsonUri_Dates, Miner_DeviceModel, Miner_Failed, Miner_NeedsBenchmark, Miner_Path, Miners_Key, Miners_List, Out, Ratio, SecondAlgo, Speed -ErrorAction Ignore
            Break
        }
        "/activity" {
            $LimitDays = (Get-Date).ToUniversalTime().AddDays(-[Math]::Max(1,[Math]::Min(7,[int]$Session.Config.MaxActivityDays)))
            $Activities = Get-ChildItem "Logs\Activity_*.txt" -ErrorAction Ignore | Where-Object LastWriteTime -gt $LimitDays | Sort-Object LastWriteTime -Descending | Foreach-Object {"[$(Get-ContentByStreamReader $_){`"ActiveStart`":`"0001-01-01 00:00:00`"}]" | ConvertFrom-Json -ErrorAction Ignore | Foreach-Object {$_}} | Where-Object ActiveStart -ne "0001-01-01 00:00:00" | Group-Object ActiveStart,Name,Device | Foreach-Object {
                $AvgProfit     = ($_.Group | Measure-Object Profit -Average).Average
                $AvgPowerDraw  = ($_.Group | Measure-Object PowerDraw -Average).Average
                $One           = $_.Group | Sort-Object ActiveLast -Descending | Select-Object -First 1
                $Active        = ((Get-Date $One.ActiveLast)-(Get-Date $One.ActiveStart)).TotalMinutes
                if ($Parameters.as_csv) {
                    [PSCustomObject]@{
                        ActiveStart = $One.ActiveStart
                        ActiveLast  = $One.ActiveLast
                        Name        = $One.Name
                        Device      = $One.Device -join '-'
                        Algorithm   = $One.Algorithm[0]
                        Algorithm2nd= "$($One.Algorithm[1])"
                        Pool        = $One.Pool[0]
                        Pool2nd     = "$($One.Pool[1])"
                        Speed       = $One.Speed[0]
                        Speed2nd    = [double]$One.Speed[1]
                        Ratio       = $One.Ratio[0]
                        Ratio2nd    = [double]$One.Ratio[1]
                        Crashed     = $One.Crashed
                        OCmode      = $One.OCmode
                        OCP         = "$($One.OCP.PSObject.Properties.Foreach({"$($_.Name)=$($_.Value)"}) -join ',')"

                        Profit      = $AvgProfit
                        PowerDraw   = $AvgPowerDraw
                        TotalPowerDraw = ($AvgPowerDraw * $Active / 60000)
                        TotalProfit = ($AvgProfit * $Active / 1440)
                        Active      = $Active
                        Mined       = "$(if ($One.Donation) {"for dev"} else {"for you"})"
                    }
                } else {
                    [PSCustomObject]@{
                        ActiveStart = $One.ActiveStart
                        ActiveLast  = $One.ActiveLast
                        Name        = $One.Name
                        Device      = $One.Device
                        Algorithm   = $One.Algorithm
                        Pool        = $One.Pool
                        Speed       = $One.Speed
                        Ratio       = $One.Ratio
                        Crashed     = $One.Crashed
                        OCmode      = $One.OCmode
                        OCP         = $One.OCP

                        Profit      = $AvgProfit
                        PowerDraw   = $AvgPowerDraw
                        TotalPowerDraw = ($AvgPowerDraw * $Active / 60000)
                        TotalProfit = ($AvgProfit * $Active / 1440)
                        Active      = $Active
                        Donation    = $One.Donation
                    }
                }
            } | Sort-Object ActiveStart,Name,Device
                    
            if ($Parameters.as_csv) {
                    $Data = $Activities | ConvertTo-Csv -NoTypeInformation -UseCulture -ErrorAction Ignore
                    $Data = $Data -join "`r`n"
                    $ContentType = "text/csv"
                    $ContentFileName = "activities_$(Get-Date -Format "yyyy-MM-dd_HHmmss").csv"
            } else {
                $Data = $Activities | ConvertTo-Json -Compress -Depth 10
            }

            $Active = $Activities = $AvgPowerDraw = $AvgProfit = $LimitDays = $One = $null
            Remove-Variable -Name Active, Activities, AvgPowerDraw, AvgProfit, LimitDays, One -ErrorAction Ignore
            Break
        }
        "/computerstats" {
            $Data = $API.ComputerStats
            Break
        }
        "/minerports" {
            $Data = $API.MinerPorts
            Break
        }
        "/currentprofit" {
            $Profit = [decimal]$API.CurrentProfit
            $Earnings_Avg = [decimal]$API.Earnings_Avg
            $Earnings_1d  = [decimal]$API.Earnings_1d
            if ($API.RemoteMiners) {
                $Profit += [decimal]$API.RemoteMinersProfit
                $Earnings_Avg = [Math]::Max($Earnings_Avg,[decimal]$API.RemoteMinersEarnings_Avg)
                $Earnings_1d  = [Math]::Max($Earnings_1d,[decimal]$API.RemoteMinersEarnings_1d)
            }
            $Timer = Get-UpTime
            $Uptime= [PSCustomObject]@{
                                        AsString = "{0:d}.{1:d2}:{2:d2}:{3:d2}" -f ($Timer.Days,$Timer.Hours,$Timer.Minutes,$Timer.Seconds+[int]($Timer.Milliseconds/1000))
                                        Seconds  = [int64]$Timer.TotalSeconds
                                    }
            $Timer = Get-UpTime -System
            $SysUptime= [PSCustomObject]@{
                                        AsString = "{0:d}.{1:d2}:{2:d2}:{3:d2}" -f ($Timer.Days,$Timer.Hours,$Timer.Minutes,$Timer.Seconds+[int]($Timer.Milliseconds/1000))
                                        Seconds  = [int64]$Timer.TotalSeconds
                                    }

            $Data  = [PSCustomObject]@{AllProfitBTC=$Profit;ProfitBTC=[decimal]$API.CurrentProfit;Earnings_Avg=[decimal]$API.Earnings_Avg;Earnings_1d=[decimal]$API.Earnings_1d;AllEarnings_Avg=$Earnings_Avg;AllEarnings_1d=$Earnings_1d;Rates=$API.ActualRates;PowerPrice=$API.CurrentPowerPrice;Power=$API.CurrentPower;Uptime=$Uptime;SysUptime=$SysUptime;RemoteIP=$API.RemoteIP} | ConvertTo-Json -Depth 10

            $Earnings_1d = $Earnings_Avg = $Profit = $SysUptime = $Timer = $Uptime = $null
            Remove-Variable -Name Earnings_1d, Earnings_Avg, Profit, SysUptime, Timer, Uptime -ErrorAction Ignore
            Break
        }
        "/stop" {
            $API.Stop = $true
            $Data = "Stopping"
            Break
        }
        "/reboot" {
            if ($Session.Config.EnableRestartComputer) {
                try {
                    $API.Reboot = $true
                    Invoke-Reboot
                    $Data = "Rebooting now!"
                } catch {
                    $Data = if ($IsLinux) {"Rebooting in some moments"} else {"Failed to reboot, sorry!"}
                }
            } else {
                $Data = "Reboot is disabled. Set `"EnableRestartComputer`": `"1`" in config.txt to enable."
            }
            Break
        }
        "/pause" {
            if ($Parameters.action -in @("set","reset","pause","unpause")) {
                $API.Pause = ($Parameters.action -in @("set","pause")) -ne $API.PauseMiners.PauseIA
            } else {
                $API.Pause = $true
            }
            $Data = $API.Pause | ConvertTo-Json
            Break
        }
        "/lockminers" {
            $API.LockMiners = -not $API.LockMiners
            $Data = $API.LockMiners | ConvertTo-Json
            Break
        }
        "/resetworkers" {
            if ($Session.Config.MinerStatusKey -match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") {
                $Result = Invoke-GetUrl "https://api.rbminer.net/reset_workers.php?user=$($Session.Config.MinerStatusKey)" -timeout 10
                if ($Result.status) {
                    $Data = "The signal to delete all offline workers was successfully sent to api.rbminer.net."
                } else {
                    $Data = "Failed to send reset signal to api.rbminer.net."
                }

                $Result = $null
                Remove-Variable -Name Result -ErrorAction Ignore
            } else {
                $Data = "No valid MinerStatusKey found in config.txt"
            }
            Break
        }
        "/applyoc" {
            $API.ApplyOC = $true
            $Data = "Please wait, OC will be applied asap"
            Break
        }
        "/update" {
            $API.Update = $true
            $Data = $API.Update | ConvertTo-Json
            Break
        }
        "/updatebalance" {
            $API.UpdateBalance = $true
            $Data = $API.UpdateBalance | ConvertTo-Json
            Break
        }
        "/updatemrr" {
            $API.UpdateMRR = $true
            $Data = $API.UpdateMRR | ConvertTo-Json
            Break
        }
        "/watchdogreset" {
            $API.WatchdogReset = $true
            $Data = $API.WatchdogReset | ConvertTo-Json
            Break
        }
        "/status" {
            $Data = [PSCustomObject]@{Pause=$API.PauseMiners.Pause;PauseIAOnly=$API.PauseMiners.PauseIAOnly;LockMiners=$Session.LockMiners;IsExclusiveRun=$Session.IsExclusiveRun;IsDonationRun=$Session.IsDonationRun} | ConvertTo-Json -Depth 10
            Break
        }
        "/clients" {
            $Config = if ($Session.UserConfig) {$Session.UserConfig} else {$Session.Config}
            if ($Parameters.include_server -eq "true" -and $Config.RunMode -eq "Server") {
                $Data = @($APIClients) + @([PSCustomObject]@{workername = $Config.Workername; machinename = $Session.MachineName; machineip = $Session.MyIP; port = $Config.APIPort; timestamp = Get-UnixTimestamp; isserver=$true}) | ConvertTo-Json
            } else {
                $Data = ConvertTo-Json $APIClients
            }
            $Config = $null
            Remove-Variable -Name Config -ErrorAction Ignore
            Break
        }
        "/action/toggleminer" {
            $status = $false
            if ($Parameters.name -and $Parameters.algorithm -and $Parameters.devicemodel) {
                $status = $true
                $count = 0
                $Vendor = $API.DevicesToVendors[$Parameters.devicemodel]
                $Parameters.algorithm -split '-' | Foreach-Object {
                    $Name = "$Vendor-$($Parameters.name)_$($_ -replace '-.+$')_HashRate.txt"
                    Get-ChildItem ".\Stats\Disabled\$Name" -ErrorAction Ignore | Foreach-Object {Remove-Item $_ -ErrorAction Ignore;$count++}
                }
                if ($count) {$disabled = $false}
                else {
                    $Parameters.algorithm -split '-' | Foreach-Object {
                        $Name = "$Vendor-$($Parameters.name)_$($_ -replace '-.+$')_HashRate.txt"
                        if (Test-Path ".\Stats\Miners\$Name") {Copy-Item ".\Stats\Miners\$Name" ".\Stats\Disabled\$Name" -Force}
                        else {Set-ContentJson -PathToFile ".\Stats\Disabled\$Name" -Data ([PSCustomObject]@{DisabledWhen=(Get-Date).ToUniversalTime()}) -Compress > $null}
                        $disabled = $true
                    }
                }
            }
            $Data = ConvertTo-Json $(if ($status) {[PSCustomObject]@{Status=$status;Disabled=$disabled}} else {[PSCustomObject]@{Status=$status}}) -Depth 10
            $Status = $Count = $Vendor = $Name = $disabled = $null
            Remove-Variable -Name Status, Count, Vendor, Name, disabled -ErrorAction Ignore
            Break
        }
        "/action/togglepool" {
            $status = $false
            if ($Parameters.name -and ($Parameters.algorithm -or $Parameters.coinsymbol)) {
                $status = $true
                $count = 0
                $Name = "$($Parameters.name)_$(if ($Parameters.coinsymbol) {$Parameters.coinsymbol} else {$Parameters.algorithm})_Profit.txt"
                Get-ChildItem ".\Stats\Disabled\$Name" -ErrorAction Ignore | Foreach-Object {Remove-Item $_.FullName -Force;$count++}
                if ($count) {$disabled = $false}
                else {
                    if (Test-Path ".\Stats\Pools\$Name") {Copy-Item ".\Stats\Pools\$Name" ".\Stats\Disabled\$Name" -Force}
                    else {Set-ContentJson -PathToFile ".\Stats\Disabled\$Name" -Data ([PSCustomObject]@{DisabledWhen=(Get-Date).ToUniversalTime()}) -Compress > $null}
                    $disabled = $true
                }
            }
            $Data = ConvertTo-Json $(if ($status) {[PSCustomObject]@{Status=$status;Disabled=$disabled}} else {[PSCustomObject]@{Status=$status}}) -Depth 10
            $Status = $Count = $Vendor = $Name = $disabled = $null
            Remove-Variable -Name Status, Count, Vendor, Name, disabled -ErrorAction Ignore
            Break
        }
        "/getconfig" {
            $Status = $false
            if ($API.IsServer) {
                if ($Parameters.workername -and $Parameters.machinename) {
                    $Client = $APIClients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                    if ($Client) {
                        $Client.machineip = $Parameters.myip
                        $Client.port      = $Parameters.port 
                        $Client.timestamp = Get-UnixTimestamp
                    }
                    else {[void]$APIClients.Add([PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; port = $Parameters.port; timestamp = Get-UnixTimestamp})}
                }
                $Result = [PSCustomObject]@{}
                $Parameters.config -split ',' | Where-Object {$_} | Foreach-Object {
                    $GetConfigA = @($_ -split 'ZZZ' | Select-Object)
                    if ($PathToFile = Get-ConfigPath -ConfigName $GetConfigA[0] -WorkerName $Parameters.workername -GroupName $Parameters.groupname) {
                        $ConfigLwt = Get-UTCToUnix (Get-ChildItem $PathToFile).LastWriteTimeUtc
                        $GetConfigNew = ($GetConfigA.Count -lt 2) -or ([int]$GetConfigA[1] -lt $ConfigLwt)
                        $Result | Add-Member $GetConfigA[0] ([PSCustomObject]@{
                                                    isnew = $GetConfigNew
                                                    lwt   = $ConfigLwt
                                                    data  = if ($GetConfigNew) {Get-ConfigContent -ConfigName $GetConfigA[0] -WorkerName $Parameters.workername -GroupName $Parameters.groupname}
                                                    }) -Force
                        $Status = $true
                    }
                }
            }
            if (-not $Status) {
                $Result = if (-not $API.IsServer) {"$($API.MachineName) is not a server"}
                        elseif ($API.Version.Version -ne $Parameters.version) {"Server runs on wrong Version v$($API.Version.Version)"}
                        else {"No data found"}
            }
            $Data = [PSCustomObject]@{Status=$Status;Content=$Result;ExcludeList=$Session.Config.ExcludeServerConfigVars} | ConvertTo-Json -Depth 10

            $Status = $Client = $PathToFile = $ConfigLwt = $Result = $GetConfigA = $GetConfigNew = $null
            Remove-Variable -Name Status, Client, PathToFile, ConfigLwt, Result, GetConfigA, GetConfigNew -ErrorAction Ignore
            Break
        }
        "/getjob" {
            if ($API.IsServer) {
                $Status = $false
                if ($Parameters.workername -and $Parameters.machinename) {
                    $Client = $APIClients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                    if ($Client) {
                        $Client.machineip = $Parameters.myip
                        $Client.port      = $Parameters.port; 
                        $Client.timestamp = Get-UnixTimestamp
                    }
                    else {[void]$APIClients.Add([PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; port = $Parameters.port; timestamp = Get-UnixTimestamp})}
                }
                $Result = $null
                try {
                    $pbody = $null
                    if ($Parameters.body -match "^{.+}$") {
                        $pbody_in = $Parameters.body | ConvertFrom-Json -ErrorAction Ignore
                        $pbody_in.PSObject.Properties | Foreach-Object {if ($pbody -eq $null) {$pbody = @{}};$pbody[$_.Name] = $_.Value}

                        $pbody_in = $null
                        Remove-Variable -Name pbody_in -ErrorAction Ignore
                    }
                    $pheaders = $null
                    if ($Parameters.headers -match "^{.+}$") {
                        $pheaders_in = $Parameters.headers | ConvertFrom-Json -ErrorAction Ignore
                        $pheaders_in.PSObject.Properties | Foreach-Object {if ($pheaders -eq $null) {$pheaders = @{}};$pheaders[$_.Name] = $_.Value}

                        $pheaders_in = $null
                        Remove-Variable -Name pheaders_in -ErrorAction Ignore
                    }
                    if ($Parameters.jobkey -eq "morerates") {
                        try {
                            $RatesUri = [System.Uri]$Parameters.url
                            $RatesQry = [System.Web.HttpUtility]::ParseQueryString($RatesUri.Query)
                            Compare-Object $Session.GetTicker @([System.Web.HttpUtility]::UrlDecode($RatesQry["symbols"]) -split ',' | Select-Object) | Where-Object {$_.SideIndicator -eq "=>" -and $_.InputObject} | Foreach-Object {[void]$Session.GetTicker.Add($_.InputObject.ToUpper())}
                            $SymbolStr = "$(($Session.GetTicker | Sort-Object) -join ',')".ToUpper()
                            $Parameters.url = "https://api.rbminer.net/cmc.php?symbols=$($SymbolStr)"

                            $RatesUri = $RatesQry = $SymbolStr = $null
                            Remove-Variable -Name RatesUri, RatesQry, SymbolStr -ErrorAction Ignore
                        } catch {}
                    }
                    if ($EnableFixBigInt) {
                        $Result = Invoke-GetUrlAsync $Parameters.url -requestmethod $Parameters.requestmethod -method $Parameters.method -cycletime $Parameters.cycletime -retry $Parameters.retry -retrywait $Parameters.retrywait -tag $Parameters.tag -delay $Parameters.delay -timeout $Parameters.timeout -body $pbody -headers $pheaders -jobkey $Parameters.jobkey -fixbigint $(Get-Yes $Parameters.fixbigint)
                    } else {
                        $Result = Invoke-GetUrlAsync $Parameters.url -requestmethod $Parameters.requestmethod -method $Parameters.method -cycletime $Parameters.cycletime -retry $Parameters.retry -retrywait $Parameters.retrywait -tag $Parameters.tag -delay $Parameters.delay -timeout $Parameters.timeout -body $pbody -headers $pheaders -jobkey $Parameters.jobkey
                    }
                    if ($Result) {$Status = $true}
                } catch {}
                $Data = [PSCustomObject]@{Status=$Status;Content=if ($Result -is [array]) {@($Result | Select-Object)} else {$Result}} | ConvertTo-Json -Depth 10 -Compress

                $Status = $Client = $pbody = $pheaders = $Result = $null
                Remove-Variable -Name Status, Client, pbody, pheaders, Result -ErrorAction Ignore
            }
            break
        }
        "/getmrr" {
            if ($API.IsServer) {
                $Status = $false
                if ($Parameters.workername -and $Parameters.machinename) {
                    $Client = $APIClients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                    if ($Client) {
                        $Client.machineip = $Parameters.myip
                        $Client.port      = $Parameters.port; 
                        $Client.timestamp = Get-UnixTimestamp
                    }
                    else {[void]$APIClients.Add([PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; port = $Parameters.port; timestamp = Get-UnixTimestamp})}
                }
                $Result = $null
                try {
                    if (-not $Parameters.key) {
                        $Parameters | Add-Member key $Session.Config.Pools.MiningRigRentals.API_Key -Force
                    }
                    if ($Parameters.key -eq $Session.Config.Pools.MiningRigRentals.API_Key) {
                        $Parameters | Add-Member secret $Session.Config.Pools.MiningRigRentals.API_Secret -Force
                        $Parameters | Add-Member nonce 0 -Force
                    }
                    if ($Parameters.key -and $Parameters.secret) {
                        $Params = [hashtable]@{}
                        ($Parameters.params | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {$Params[$_.Name] = $_.Value}

                        $regex = "$($Parameters.regex)"
                        $regexfld = "$($Parameters.regexfld)"
                        $regexmatch = Get-Yes $Parameters.regexmatch
                        $cycletime = [int]$Parameters.cycletime
                        $nonce     = [int]$Parameters.nonce

                        if (-not $nonce -and $cycletime -and (Test-Path Variable:Global:AsyncLoader) -and $AsyncLoader.Timestamp -and ($AsyncLoader.Timestamp -gt (Get-Date).ToUniversalTime().AddMinutes(-10))) {
                            $Result = Invoke-MiningRigRentalRequestAsync $Parameters.endpoint $Parameters.key $Parameters.secret -method $Parameters.method -params $Params -Timeout $Parameters.Timeout -cycletime $cycletime -retry $Parameters.retry -retrywait $Parameters.retrywait -Raw
                            if ($regexfld -and $regex -and $Result.data) {
                                if ($regexmatch) {
                                    $Result.data = $Result.data | Where-Object {$_.$regexfld -match $regex}
                                } else {
                                    $Result.data = $Result.data | Where-Object {$_.$regexfld -notmatch $regex}
                                }
                            }
                        } else {
                            $Result = Invoke-MiningRigRentalRequest $Parameters.endpoint $Parameters.key $Parameters.secret -method $Parameters.method -params $Params -Timeout $Parameters.Timeout -nonce $nonce -regexfld $regexfld -regex $regex -regexmatch $regexmatch -Raw -Cache $(if ($cycletime) {30} else {0})
                        }

                        $Status = $true
                    }
                } catch {}
                $Data = [PSCustomObject]@{Status=$Status;Content=$Result} | ConvertTo-Json -Depth 10 -Compress

                $Client = $cycletime = $nonce = $regex = $regexfld = $regexmatch = $Result = $Status = $null
                Remove-Variable -Name Client, cycletime, nonce, regex, regexfld, regexmatch, Result, Status -ErrorAction Ignore
            }
            break
        }
        "/getbinance" {
            if ($API.IsServer) {
                $Status = $false
                if ($Parameters.workername -and $Parameters.machinename) {
                    $Client = $APIClients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                    if ($Client) {
                        $Client.machineip = $Parameters.myip
                        $Client.port      = $Parameters.port
                        $Client.timestamp = Get-UnixTimestamp
                    }
                    else {[void]$APIClients.Add([PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; port = $Parameters.port; timestamp = Get-UnixTimestamp})}
                }
                $Result = $null
                try {
                    if (-not $Parameters.key -and $Session.Config.Pools.Binance.API_Key  -and $Session.Config.Pools.Binance.API_Secret) {
                        $Parameters | Add-Member key    $Session.Config.Pools.Binance.API_Key -Force
                        $Parameters | Add-Member secret $Session.Config.Pools.Binance.API_Secret -Force
                    }
                    if ($Parameters.key -and $Parameters.secret) {
                        $Params = [hashtable]@{}
                        ($Parameters.params | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {$Params[$_.Name] = $_.Value}
                        $Result = Invoke-BinanceRequest $Parameters.endpoint $Parameters.key $Parameters.secret -method $Parameters.method -params $Params -Timeout $Parameters.Timeout -Cache 30
                        $Status = $true
                    }
                } catch {}
                $Data = [PSCustomObject]@{Status=$Status;Content=$Result} | ConvertTo-Json -Depth 10 -Compress

                $Status = $Client = $Params = $Result = $null
                Remove-Variable -Name Status, Client, Params, Result -ErrorAction Ignore
            }
            break
        }
        "/getnh" {
            if ($API.IsServer) {
                $Status = $false
                if ($Parameters.workername -and $Parameters.machinename) {
                    $Client = $APIClients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                    if ($Client) {
                        $Client.machineip = $Parameters.myip
                        $Client.port      = $Parameters.port
                        $Client.timestamp = Get-UnixTimestamp
                    }
                    else {[void]$APIClients.Add([PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; port = $Parameters.port; timestamp = Get-UnixTimestamp})}
                }
                $Result = $null
                try {
                    if (-not $Parameters.key -and $Session.Config.Pools.NiceHash.API_Key  -and $Session.Config.Pools.NiceHash.API_Secret -and $Session.Config.Pools.NiceHash.OrganizationID) {
                        $Parameters | Add-Member key    $Session.Config.Pools.NiceHash.API_Key -Force
                        $Parameters | Add-Member secret $Session.Config.Pools.NiceHash.API_Secret -Force
                        $Parameters | Add-Member orgid  $Session.Config.Pools.NiceHash.OrganizationID -Force
                    }
                    if ($Parameters.key -and $Parameters.secret -and $Parameters.orgid) {
                        $Params = [hashtable]@{}
                        ($Parameters.params | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {$Params[$_.Name] = $_.Value}
                        $Result = Invoke-NHRequest $Parameters.endpoint $Parameters.key $Parameters.secret $Parameters.orgid -method $Parameters.method -params $Params -Timeout $Parameters.Timeout -Cache 30
                        $Status = $true
                    }
                } catch {}
                $Data = [PSCustomObject]@{Status=$Status;Content=$Result} | ConvertTo-Json -Depth 10 -Compress

                $Status = $Client = $Params = $Result = $null
                Remove-Variable -Name Status, Client, Params, Result -ErrorAction Ignore
            }
            break
        }
        "/mrrstats" {
            [System.Collections.ArrayList]$Mrr_Data = @()
            $CpuDevices = ($API.Devices | Where-Object Type -eq "CPU" | Measure-Object).Count
            $GpuDevices = ($API.Devices | Where-Object Type -eq "GPU" | Measure-Object).Count

            if ($Pool_Request = Get-MiningRigRentalAlgos) {
                $ActiveMiners = @()

                if ($API.ActiveMiners) {
                    $ActiveMiners = ConvertFrom-Json $API.ActiveMiners -ErrorAction Ignore
                }

                [hashtable]$StatsCPU = @{}
                [hashtable]$StatsGPU = @{}
                if ($CpuDevices) {
                    $StatsCache.Keys | Where-Object {$_ -match "CPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsCPU[$Matches[1]] -lt $StatsCache.$_.Day) {$StatsCPU[$Matches[1]] = $StatsCache.$_.Day}}
                    $ActiveMiners | Where-Object {$_.DeviceName -match "CPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsCPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                }
                if ($GpuDevices) {
                    $StatsCache.Keys | Where-Object {$_ -match "GPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsGPU[$Matches[1]] -lt $StatsCache.$_.Day) {$StatsGPU[$Matches[1]] = $StatsCache.$_.Day}}
                    $ActiveMiners | Where-Object {$_.DeviceName -match "GPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsGPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                }
                $Pool_Request | Foreach-Object {
                    $Algo  = Get-MiningRigRentalAlgorithm $_.name
                    $Speed = [Double]$StatsCPU[$Algo] + [Double]$StatsGPU[$Algo]
                    [void]$Mrr_Data.Add([PSCustomObject]@{
                        Algorithm = $Algo
                        Title     = $_.display
                        SuggPrice = $_.suggested_price.amount
                        LastPrice = $_.stats.prices.last.amount
                        RigsPrice = ($Speed / (Get-MiningRigRentalsDivisor $_.suggested_price.unit))*[double]$_.suggested_price.amount
                        Unit      = $_.hashtype.ToUpper()
                        Hot       = $_.hot
                        RigsAvail = $_.stats.available.rigs
                        RigsRented= $_.stats.rented.rigs
                        HashRate  = $Speed
                    })
                }
            }
            $Data = ConvertTo-Json @($Mrr_Data) -Depth 10 -Compress

            $ActiveMiners = $Algo = $CpuDevices = $GpuDevices = $Mrr_Data = $Pool_Request = $Speed = $StatsCPU = $StatsGPU = $null
            Remove-Variable -Name ActiveMiners, Algo, CpuDevices, GpuDevices, Mrr_Data, Pool_Request, Speed, StatsCPU, StatsGPU -ErrorAction Ignore
            break
        }
        "/mrrrigs" {
            [System.Collections.ArrayList]$Mrr_Data = @()
            $CpuDevices = ($API.Devices | Where-Object Type -eq "CPU" | Measure-Object).Count
            $GpuDevices = ($API.Devices | Where-Object Type -eq "GPU" | Measure-Object).Count

            if ($Session.Config.Pools.MiningRigRentals.API_Key -and $Session.Config.Pools.MiningRigRentals.API_Secret) {
                $Workers = @($Session.Config.DeviceModel | Where-Object {$Session.Config.Devices.$_.Worker} | Foreach-Object {$Session.Config.Devices.$_.Worker} | Select-Object -Unique) + $Session.Config.WorkerName | Select-Object -Unique
                if (($Pool_Request = Get-MiningRigRentalAlgos) -and ($AllRigs_Request = Get-MiningRigRentalRigs -key $Session.Config.Pools.MiningRigRentals.API_Key -secret $Session.Config.Pools.MiningRigRentals.API_Secret -workers $Workers)) {
                    $ActiveMiners = @()

                    if ($API.ActiveMiners) {
                        $ActiveMiners = ConvertFrom-Json $API.ActiveMiners -ErrorAction Ignore
                    }
                    
                    [hashtable]$StatsCPU = @{}
                    [hashtable]$StatsGPU = @{}
                    if ($CpuDevices) {
                        $StatsCache.Keys | Where-Object {$_ -match "CPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsCPU[$Matches[1]] -lt $StatsCache.$_.Day) {$StatsCPU[$Matches[1]] = $StatsCache.$_.Day}}
                        $ActiveMiners | Where-Object {$_.DeviceName -match "CPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsCPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                    }
                    if ($GpuDevices) {
                        $StatsCache.Keys | Where-Object {$_ -match "GPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsGPU[$Matches[1]] -lt $StatsCache.$_.Day) {$StatsGPU[$Matches[1]] = $StatsCache.$_.Day}}
                        $ActiveMiners | Where-Object {$_.DeviceName -match "GPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsGPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                    }
                    $AllRigs_Request | Foreach-Object {
                        $Rig = $_
                        if ($Pool_Data = $Pool_Request | Where-Object {$_.name -eq $Rig.type}) {
                            $Algo  = Get-MiningRigRentalAlgorithm $_.type
                            $Speed = [Double]$StatsCPU[$Algo] + [Double]$StatsGPU[$Algo]
                            [void]$Mrr_Data.Add([PSCustomObject]@{
                                Algorithm = $Algo
                                Title     = $Pool_Data.display
                                SuggPrice = $Pool_Data.suggested_price.amount
                                LastPrice = $Pool_Data.stats.prices.last.amount
                                RigsPrice = [double]$Rig.hashrate.advertised.hash*[double]$Rig.price.BTC.price
                                Unit      = "$($Pool_Data.hashtype)".ToUpper()
                                Hot       = $Pool_Data.hot
                                RigsAvail = $Pool_Data.stats.available.rigs
                                RigsRented= $Pool_Data.stats.rented.rigs
                                Price     = $Rig.price.BTC.price
                                MinPrice  = $Rig.price.BTC.minimum
                                Modifier  = $Rig.price.BTC.modifier
                                Multiplier= Get-MiningRigRentalsDivisor $Rig.price.type
                                PriceData = $Rig.price
                                MinHours  = $Rig.minhours
                                MaxHours  = $Rig.maxhours
                                HashRate  = $Speed
                                HashRateAdv = $Rig.hashrate.advertised.hash * (Get-MiningRigRentalsDivisor $Rig.hashrate.advertised.type)
                            })
                        }
                    }
                }
            }
            $Data = ConvertTo-Json @($Mrr_Data) -Depth 10 -Compress

            $ActiveMiners = $AllRigs_Request = $Algo = $CpuDevices = $GpuDevices = $Mrr_Data = $Pool_Data = $Pool_Request = $Rig = $Speed = $StatsCPU = $StatsGPU = $null
            Remove-Variable -Name ActiveMiners, AllRigs_Request, Algo, CpuDevices, GpuDevices, Mrr_Data, Pool_Data, Pool_Request, Rig, Speed, StatsCPU, StatsGPU -ErrorAction Ignore
            break
        }
        "/mrrcontrol" {
            $Data = try {
                (Get-ContentByStreamReader ".\Data\mrrcontrol.json" | ConvertFrom-Json -ErrorAction Stop) | Foreach-Object {
                    [PSCustomObject]@{
                        Name = $_.Name
                        PriceFactor = $_.PriceFactor
                        Algorithms = $_.Algorithms
                        LastReset = "$(([datetime]$_.LastReset).ToString("yyyy-MM-dd HH:mm:ss"))"
                    }
                }
            } catch {}
            $Data = if ($Data) {ConvertTo-Json $Data -Depth 10} else {"[]"}
            break
        }
        default {
            # Set index page
            if ($Path -eq "/") {
                $Path = "/index.html"
            }

            # Check if there is a file with the requested path
            $Filename = Join-Path $BasePath $Path
            if (Test-Path $Filename -PathType Leaf) {
                # If the file is a powershell script, execute it and return the output. A $Parameters parameter is sent built from the query string
                # Otherwise, just return the contents of the file
                $File = Get-ChildItem $Filename -ErrorAction Ignore

                If ($File.Extension -eq ".ps1") {
                    $Data = (& $File.FullName -Parameters $Parameters) -join "`r`n"
                } elseif (@(".html",".css",".js",".json",".xml",".txt") -icontains $File.Extension) {
                    $Data = Get-ContentByStreamReader $Filename

                    if ($Data -and $File.Extension -match "htm") {
                        # Process server side includes for html files
                        # Includes are in the traditional '<!-- #include file="/path/filename.html" -->' format used by many web servers
                        $IncludeRegex = [regex]'<!-- *#include *file="(.*?)" *-->'
                        $IncludeRegex.Matches($Data) | Foreach-Object {
                            $IncludeFile = Join-Path $BasePath $_.Groups[1].Value
                            If (Test-Path $IncludeFile -PathType Leaf) {
                                $IncludeData = Get-ContentByStreamReader $IncludeFile
                                $Data = $Data -Replace $_.Value, $IncludeData
                            }
                        }
                    }
                } else {
                    $Data = [System.IO.File]::ReadAllBytes($File.FullName)
                }

                $ContentType = Get-MimeType $File.Extension
            } else {
                $Data        = "URI '$Path' is not a valid resource."
                $StatusCode  = [System.Net.HttpStatusCode]::NotFound
                $ContentType = "text/html"
            }
        }
    }
    }

    # If $Data is null, the API will just return whatever data was in the previous request.  Instead, show an error
    # This happens if the script just started and hasn't filled all the properties in yet.
    If ($Data -eq $null) {
        $Data        = "API data not (yet) available"
        $StatusCode  = [System.Net.HttpStatusCode]::NotFound
        $ContentType = "text/html"
    }

    try {
        if ($ContentFileName -ne "") {
            [void]$Response.Headers.Add("Content-Disposition", "attachment; filename=$($ContentFileName)")
        }

        $Response.ContentType = $ContentType
        $Response.StatusCode  = $StatusCode

        if ($Data -is [string]) {
            $Utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($false)
            $ResponseStream = [System.IO.StreamWriter]::new($Response.OutputStream, $Utf8NoBomEncoding)
        
            try {
                $ResponseStream.Write($Data)
                $ResponseStream.Flush()
            } catch {
            } finally {
                $ResponseStream.Dispose()
            }
        } else {
            $Response.ContentLength64 = $Data.Length
            $Response.OutputStream.Write($Data, 0, $Data.Length)
        }
    } catch {
        if ($Session.Config.LogLevel -ne "Silent") {
            Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").api.txt" -Message "[$ThreadID] Response to $($Path) not sent: $($_.Exception.Message)" -Append -Timestamp
        }
    } finally {
        if ($Response -ne $null) {
            try {
                $Response.Close()
            } catch {
                if ($Session.Config.LogLevel -ne "Silent") {
                    Write-ToFile -FilePath "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").api.txt" -Message "[$ThreadID] Close response to $($Path) failed: $($_.Exception.Message)" -Append -Timestamp
                }
            }
        }
    }

    if ($Global:Error.Count) {
        if ($Session.LogLevel -ne "Silent") {
            $logDate = Get-Date -Format "yyyy-MM-dd"
            foreach ($err in $Global:Error) {
                if ($err.Exception.Message) {
                    Write-ToFile -FilePath "Logs\errors_$logDate.api.txt" -Message "[$ThreadID] Error during $($Path): $($err.Exception.Message)" -Append -Timestamp
                }
            }
        }
        $Global:Error.Clear()
    }

    if ($task -ne $null) {
        $task.Dispose()
    }

    $Data = $null
    $Parameters = $null
    $Utf8NoBomEncoding = $null
    $ResponseStream = $null
    $Response = $null
    $InputStream = $null
    $ContentEncoding = $null
    $Request = $null
    $Context = $null
    $task = $null

    $CacheDate = (Get-Date).AddMinutes(-30).ToUniversalTime()
    foreach ($key in @($APICacheDB.Keys)) {
        if ($APICacheDB.ContainsKey($key) -and $APICacheDB[$key].LastAccess -lt $CacheDate) {
            [void]$APICacheDB.Remove($key)
        }
    }
    $CacheDate = $null
    $key = $null

    if ($GCStopWatch.Elapsed.TotalSeconds -gt 120) {
        [System.GC]::Collect()
        $GCStopWatch.Restart()
    }
}

if ($API.Debug) {Stop-Transcript}