Function Start-APIServer {

    # Create a global synchronized hashtable that all threads can access to pass data between the main script and API
    $Global:API = [hashtable]::Synchronized(@{})

    # Initialize firewall and prefix
    if ($Session.IsAdmin -and $Session.Config.APIport) {Initialize-APIServer -Port $Session.Config.APIport}
  
    # Setup flags for controlling script execution
    $API.Stop        = $false
    $API.Pause       = $false
    $API.Update      = $false
    $API.UpdateBalance = $false
    $API.ApplyOC     = $false
    $API.LockMiners  = $false
    $API.IsVirtual   = $false
    $API.APIport     = $Session.Config.APIport
    $API.RandTag     = Get-MD5Hash("$((Get-Date).ToUniversalTime())$(Get-Random)")
    $API.RemoteAPI   = Test-APIServer -Port $Session.Config.APIport
    $API.IsServer    = $Session.Config.RunMode -eq "Server"

    Set-APICredentials

    # Setup runspace to launch the API webserver in a separate thread
    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("API", $API)
    $newRunspace.SessionStateProxy.SetVariable("Session", $Session)
    $newRunspace.SessionStateProxy.SetVariable("AsyncLoader", $AsyncLoader)
    $newRunspace.SessionStateProxy.Path.SetLocation($(pwd)) | Out-Null

    $API.Server = [PowerShell]::Create().AddScript({

        $ProgressPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"
        $InformationPreference = "SilentlyContinue"

        # Set the starting directory
        if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

        Import-Module ".\Include.psm1"
        Import-Module ".\MiningRigRentals.psm1"

        $BasePath = "$PWD\web"

        Set-OsFlags

        $AllProtocols = [System.Net.SecurityProtocolType]'Tls12,Tls11,Tls' 
        [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

        # List of possible mime types for files
        $MIMETypes = @{
            ".js" = "application/x-javascript"
            ".html" = "text/html"
            ".htm" = "text/html"
            ".json" = "application/json"
            ".css" = "text/css"
            ".txt" = "text/plain"
            ".ico" = "image/x-icon"
            ".png" = "image/png"
            ".jpg" = "image/jpeg"
            ".gif" = "image/gif"
            ".ps1" = "text/html" # ps1 files get executed, assume their response is html
            ".7z"  = "application/x-7z-compressed”
            ".zip" = "application/zip”
        }

        function Get-FilteredMinerObject {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
                $Miner
            )
            $Out = [PSCustomObject]@{}
            $Miner.PSObject.Properties | Foreach-Object {$Out | Add-Member $_.Name $_.Value}
            $Out
        }

        $Clients = @()

        # Setup the listener
        $Server = New-Object System.Net.HttpListener
        if ($API.RemoteAPI) {
            $Server.Prefixes.Add("http://+:$($API.APIport)/")
            # Require authentication when listening remotely
            $Server.AuthenticationSchemes = if ($API.APIauth) {[System.Net.AuthenticationSchemes]::Basic} else {[System.Net.AuthenticationSchemes]::Anonymous}
        } else {
            $Server.Prefixes.Add("http://localhost:$($API.APIport)/")
        }
        $Server.Start()

        $StopWatch = New-Object -TypeName System.Diagnostics.StopWatch

        While ($Server.IsListening -and -not $API.Stop) {
            $task = $Server.GetContextAsync();
            $Context = $null
            while(-not $Context -and -not $API.Stop){
                if ($API.IsServer -and (-not $StopWatch.IsRunning -or $StopWatch.ElapsedMilliseconds -gt 1000)) {
                    #Send-APIServerUdp -Port $API.APIport -MachineName $Session.MachineName -IPaddress $Session.MyIP > $null
                    $StopWatch.Restart()
                }
                if($task.Wait(500)){$Context = $task.Result}
                if (-not $Context) {Start-Sleep -Milliseconds 100}
            }

            if ($API.Stop) {Break}

            $Request         = $Context.Request
		    $InputStream     = $Request.InputStream
			$ContentEncoding = $Request.ContentEncoding

            $Parameters = [PSCustomObject]@{}

            # Get query parameters		
    		foreach ($Query in $Request.QueryString) {
			    $QueryString = $Request.QueryString["$Query"]
			    if ($QueryString -and $Query) {
                    $Parameters | Add-Member $Query $QueryString -Force
			    }
		    }

            # Get post parameters
            if($Request.HasEntityBody -and $Request.HttpMethod -in @("POST","PUT")) {
	            $PostCommand = New-Object IO.StreamReader ($InputStream,$ContentEncoding)
	            $PostCommand = $PostCommand.ReadToEnd()
	            $PostCommand = $PostCommand.ToString()
	
	            if ($PostCommand) {
		            $PostCommand = $PostCommand -replace('\+'," ")
		            $PostCommand = $PostCommand -replace("%20"," ")
		            $PostCommand = $PostCommand -replace("%21","!")
		            $PostCommand = $PostCommand -replace('%22','"')
		            $PostCommand = $PostCommand -replace("%23","#")
		            $PostCommand = $PostCommand -replace("%24","$")
		            $PostCommand = $PostCommand -replace("%25","%")
		            $PostCommand = $PostCommand -replace("%27","'")
		            $PostCommand = $PostCommand -replace("%28","(")
		            $PostCommand = $PostCommand -replace("%29",")")
		            $PostCommand = $PostCommand -replace("%2A","*")
		            $PostCommand = $PostCommand -replace("%2B","+")
		            $PostCommand = $PostCommand -replace("%2C",",")
		            $PostCommand = $PostCommand -replace("%2D","-")
		            $PostCommand = $PostCommand -replace("%2E",".")
		            $PostCommand = $PostCommand -replace("%2F","/")
		            $PostCommand = $PostCommand -replace("%3A",":")
		            $PostCommand = $PostCommand -replace("%3B",";")
		            $PostCommand = $PostCommand -replace("%3C","<")
		            $PostCommand = $PostCommand -replace("%3E",">")
		            $PostCommand = $PostCommand -replace("%3F","?")
		            $PostCommand = $PostCommand -replace("%5B","[")
		            $PostCommand = $PostCommand -replace("%5C","\")
		            $PostCommand = $PostCommand -replace("%5D","]")
		            $PostCommand = $PostCommand -replace("%5E","^")
		            $PostCommand = $PostCommand -replace("%5F","_")
		            $PostCommand = $PostCommand -replace("%7B","{")
		            $PostCommand = $PostCommand -replace("%7C","|")
		            $PostCommand = $PostCommand -replace("%7D","}")
		            $PostCommand = $PostCommand -replace("%7E","~")
		            $PostCommand = $PostCommand -replace("%7F","_")
		            $PostCommand = $PostCommand -replace("%7F%25","%")
		            $PostCommand = $PostCommand.Split("&")

		            foreach ($Post in $PostCommand) {
			            $PostValue = $Post.Replace("%26","&")
			            $PostContent = $PostValue.Split("=")
			            $PostName = $PostContent[0] -replace("%3D","=")
			            $PostValue = $PostContent[1] -replace("%3D","=")

			            if ($PostName.EndsWith("[]")) {
				            $PostName = $PostName.Substring(0,$PostName.Length-2)
				            if (!(New-Object PSObject -Property @{PostName=@()}).PostName) {
					            $Parameters | Add-Member $Postname (@()) -Force
					            $Parameters."$PostName" += $PostValue
				            } else {
					            $Parameters."$PostName" += $PostValue
				            }
			            } else {
				            $Parameters | Add-Member $PostName $PostValue -Force
			            }
		            }
                    Remove-Variable "PostCommand" -ErrorAction Ignore
                }
          	}

            # Determine the requested resource and parse query strings
            $Path = $Request.Url.LocalPath

            # Create a new response and the defaults for associated settings
            $Response = $Context.Response
            $ContentType = "application/json"
            $StatusCode = 200
            $Data = ""
            $ContentFileName = ""

            if ($Path -match $API.RandTag) {$Path = "/stop";$API.APIAuth = $false}
            
            if($API.RemoteAPI -and $API.APIauth -and (-not $Context.User.Identity.IsAuthenticated -or $Context.User.Identity.Name -ne $API.APIuser -or $Context.User.Identity.Password -ne $API.APIpassword)) {
                $Data = "Access denied"
                $StatusCode = 401
                $ContentType = "text/html"
            } else {
                # Set the proper content type, status code and data for each resource
                Switch($Path) {
                "/version" {
                    $Data = $API.Version
                    break
                }
                "/info" {
                    $Data = ConvertTo-Json $API.Info -Depth 10
                    break
                }
                "/uptime" {
                    $Timer = Get-UpTime
                    $Data = ConvertTo-Json ([PSCustomObject]@{
                                                AsString = "{0:d}.{1:d2}:{2:d2}:{3:d2}" -f ($Timer.Days,$Timer.Hours,$Timer.Minutes,$Timer.Seconds+[int]($Timer.Milliseconds/1000))
                                                Seconds  = [int64]$Timer.TotalSeconds
                                            })
                    break
                }
                "/systemuptime" {
                    $Timer = Get-UpTime -System
                    $Data = ConvertTo-Json ([PSCustomObject]@{
                                                AsString = "{0:d}.{1:d2}:{2:d2}:{3:d2}" -f ($Timer.Days,$Timer.Hours,$Timer.Minutes,$Timer.Seconds+[int]($Timer.Milliseconds/1000))
                                                Seconds  = [int64]$Timer.TotalSeconds
                                            })
                    break
                }
                "/isserver" {
                    $Data = [PSCustomObject]@{Status=$API.IsServer} | ConvertTo-Json
                    break
                }
                "/activeminers" {
                    $Data = ConvertTo-Json @($API.ActiveMiners | Select-Object) -Depth 2 # | Foreach-Object {Get-FilteredMinerObject $_}) -Depth 2
                    break
                }
                "/runningminers" {
                    $Data = ConvertTo-Json @($API.RunningMiners | Select-Object) -Depth 2 # | Foreach-Object {Get-FilteredMinerObject $_}) -Depth 2
                    Break
                }
                "/failedminers" {
                    $Data = ConvertTo-Json @($API.FailedMiners | Select-Object) -Depth 2 # | Foreach-Object {Get-FilteredMinerObject $_}) -Depth 2
                    Break
                }
                "/remoteminers" {
                    $Data = ConvertTo-Json @(($API.RemoteMiners | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Select-Object) -Depth 10
                    Break
                }
                "/minersneedingbenchmark" {
                    $Data = ConvertTo-Json @(($API.MinersNeedingBenchmark | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Select-Object)
                    Break
                }
                "/minerinfo" {
                    $Data = ConvertTo-Json @($Session.MinerInfo | Select-Object)
                    Break
                }
                "/pools" {
                    $Data = ConvertTo-Json @(($API.Pools | Select-Object | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Select-Object -ExpandProperty Value)
                    Break
                }
                "/newpools" {
                    $Data = ConvertTo-Json @(($API.NewPools | Select-Object) | ConvertFrom-Json -ErrorAction Ignore | Select-Object)
                    Break
                }
                "/allpools" {
                    $Data = ConvertTo-Json @($Session.AllPools | Select-Object)
                    Break
                }
                "/selectedpools" {
                    $Data = ConvertTo-Json @(($API.SelectedPools | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Select-Object)
                    Break
                }
                "/algorithms" {
                    $Data = ConvertTo-Json @(($Session.AllPools | Select-Object).Algorithm | Sort-Object -Unique)
                    Break
                }
                "/miners" {
                    $Data = ConvertTo-Json @(($API.Miners | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Select-Object)
                    Break
                }
                "/fastestminers" {
                    $Data = ConvertTo-Json @(($API.FastestMiners | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Select-Object)
                    Break
                }
                "/config" {
                    $Data = ConvertTo-Json $Session.Config
                    Break
                }
                "/userconfig" {
                    $Data = ConvertTo-Json $Session.UserConfig
                    Break
                }
                "/ocprofiles" {
                    $Data = ConvertTo-Json @($Session.Config.OCProfiles.PSObject.Properties | Foreach-Object {$_.Value | Add-Member -NotePropertyMembers @{Name=($_.Name -replace "-.+$");Device=$(if ($_.Name -match "-(.+)$") {$Matches[1]} else {""})} -Force -PassThru} | Select-Object)
                    Break
                }
                "/downloadlist" {
                    $Data = ConvertTo-Json @(($API.DownloadList | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Select-Object)
                    Break
                }
                "/debug" {
                    #create zip log and xxx out all purses
                    $DebugDate = Get-Date -Format "yyyy-MM-dd"
                    $DebugPath = Join-Path (Resolve-Path ".\Logs") "debug-$DebugDate"
                    $PurgeStrings = @()
                    @($Session.Config,$Session.UserConfig) | Select-Object | Foreach-Object {
                        $CurrentConfig = $_
                        @("Wallet","UserName","API_ID","API_Key","MinerStatusKey","MinerStatusEmail","PushOverUserKey") | Where-Object {$CurrentConfig.$_} | Foreach-Object {$PurgeStrings += $CurrentConfig.$_}
                        $CurrentConfig.Pools.PSObject.Properties.Value | Foreach-Object {
                            $CurrentPool = $_
                            $PurgeStrings += @($CurrentPool.Wallets.PSObject.Properties.Value | Select-Object)
                            @("Wallet","API_Key","API_Secret","Password","PartyPassword","Email") | Where-Object {$CurrentPool.$_ -and $CurrentPool.$_.Length -gt 5} | Foreach-Object {$PurgeStrings += $CurrentPool.$_}
                        }
                    }
                    $PurgeStrings = $PurgeStrings | Select-Object -Unique | Foreach-Object {[regex]::Escape($_)}

                    if (-not (Test-Path $DebugPath)) {New-Item $DebugPath -ItemType "directory" > $null}
                    @(Get-ChildItem ".\Logs\*$(Get-Date -Format "yyyy-MM-dd")*.txt" | Select-Object) + @(Get-ChildItem ".\Logs\*$((Get-Date).AddDays(-1).ToString('yyyy-MM-dd'))*.txt" | Select-Object) | Sort-Object LastWriteTime | Foreach-Object {
                        $LastWriteTime = $_.LastWriteTime
                        $NewFile = "$DebugPath\$($_.Name)"
                        Get-Content $_ -Raw | Foreach-Object {$_ -replace "($($PurgeStrings -join "|"))","XXX"} | Out-File $NewFile                        
                    }

                    @("Config","UserConfig") | Where-Object {$API.$_} | Foreach-Object {
                        $NewFile = "$DebugPath\$($_).json"
                        ($API.$_ | Select-Object | ConvertTo-Json -Depth 10) -replace "($($PurgeStrings -join "|"))","XXX" | Out-File $NewFile
                    }


                    if ($IsLinux) {
                        $Params = @{
                            FilePath     = "7z"
                            ArgumentList = "a `"$($DebugPath).zip`" `"$(Join-Path $DebugPath "*")`" -y -sdel -tzip"
                        }
                    } else {
                        $Params = @{
                            FilePath     = "7z"
                            ArgumentList = "a `"$($DebugPath).zip`" `"$(Join-Path $DebugPath "*")`" -y -sdel -tzip"
                            WindowStyle  = "Hidden"
                        }
                    }

                    $Params.PassThru = $true
                    (Start-Process @Params).WaitForExit()>$null

                    Remove-Item $DebugPath -Recurse -Force

                    $Data = [System.IO.File]::ReadAllBytes("$($DebugPath).zip")
                    $ContentType = $MIMETypes[".zip"]
                    $ContentFileName = "debug_$($DebugDate).zip"

                    Remove-Item "$($DebugPath).zip" -Force -ErrorAction Ignore
                    Remove-Variable "PurgeStrings" -ErrorAction Ignore
                    Break
                }
                "/setup.json" {
                    $Data = ConvertTo-Json ([PSCustomObject]@{Autostart=[PSCustomObject]@{Enable="0";ConfigName="All";DeviceName="GPU";WorkerName=""};Exclude=$Session.Config.ExcludeServerConfigVars;Config=(Get-ConfigContent "config");Pools=(Get-ConfigContent "pools");Coins=(Get-ConfigContent "coins");OCProfiles=(Get-ConfigContent "ocprofiles");Scheduler=(Get-ConfigContent "scheduler")}) -Depth 10
                    $ContentType = $MIMETypes[".json"]
                    $ContentFileName = "setup.json"
                    Break
                }
                "/alldevices" {
                    $Data = ConvertTo-Json @($Session.AllDevices | Select-Object)
                    Break
                }
                "/devices" {
                    $Data = ConvertTo-Json @($Session.Devices | Select-Object)
                    Break
                }
                "/devicecombos" {
                    $Data = ConvertTo-Json @($Session.DeviceCombos | Select-Object)
                    Break
                }
                "/stats" {
                    $Data = ConvertTo-Json @($Session.Stats | Select-Object)
                    Break
                }
                "/totals" {
                    $Data = ConvertTo-Json @((Get-Stat -Totals).Values | Select-Object)
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
                        $Earnings = @(Import-Csv "Stats\Balances\Earnings.csv" | Foreach-Object {
                            $Rate = $Session.Rates."$($_.Currency)"
                            [PSCustomObject]@{
                                Date = if ($Parameters.as_csv) {[DateTime]$_.Date} else {([DateTime]$_.Date).ToString("yyyy-MM-dd HH:mm:ss")}
                                Date_UTC = if ($Parameters.as_csv) {[DateTime]$_.Date_UTC} else {([DateTime]$_.Date_UTC).ToString("yyyy-MM-dd HH:mm:ss")}
                                PoolName = $_.PoolName
                                Currency = $_.Currency
                                Balance  = [Decimal]$_.Balance
                                Paid     = [Decimal]$_.Paid
                                Earnings = [Decimal]$_.Earnings
                                Value    = [Decimal]$_.Value
                                Balance_BTC = [Decimal]$(if ($Rate) {$_.Balance / $Rate} else {0})
                                Paid_BTC = [Decimal]$(if ($Rate) {$_.Paid / $Rate} else {0})
                                Earnings_BTC = [Decimal]$(if ($Rate) {$_.Earnings / $Rate} else {0})
                                Value_BTC = [Decimal]$(if ($Rate) {$_.Value / $Rate} else {0})
                            }
                        } | Select-Object)
                        if ($Parameters.as_csv) {
                            $Data = $Earnings | ConvertTo-Csv -NoTypeInformation -UseCulture -ErrorAction Ignore
                            $Data = $Data -join "`r`n"
                            $ContentType = "text/csv"
                            $ContentFileName = "earnings_$(Get-Date -Format "yyyy-MM-dd_HHmmss").csv"
                        } else {
                            $Filter = if ($Parameters.filter) {$Parameters.filter | ConvertFrom-Json -ErrorAction Ignore}
                            $Sort   = if ($Parameters.sort) {$Parameters.sort} else {"Date"}
                            $Order  = $Parameters.order -eq "desc"

                            $TotalNotFiltered = $Earnings.Count
                            $Earnings = @($Earnings | Where-Object {-not $Filter -or -not (Compare-Object $_ $Filter -Property $Filter.PSObject.Properties.Name | Measure-Object).Count} | Sort-Object -Property $Sort -Descending:$Order | Select-Object)
                            $Total = $Earnings.Count
                            if ($Parameters.limit) {
                                $Earnings = @($Earnings | Select-Object -Skip ([int]$Parameters.offset) -First ([int]$Parameters.limit))
                            } 

                            $Data = [PSCustomObject]@{
                                total = $Total
                                totalNotFiltered = $TotalNotFiltered
                                rows = $Earnings
                            } | ConvertTo-Json -Depth 10
                        }
                        Remove-Variable "Earnings" -ErrorAction Ignore
                    }
                    Break
                }
                "/poolstats" {
                    $Data = ConvertTo-Json @(Get-Stat -Pools | Select-Object)
                    Break
                }
                "/sessionvars" {           
                    $SessionVars = [hashtable]@{}
                    $Session.Keys | Where-Object {$Session[$_] -isnot [hashtable] -and $Session[$_] -isnot [array] -and $Session[$_] -isnot [pscustomobject] -and $Session[$_] -ne $null} | Sort-Object | Foreach-Object {$SessionVars[$_] = $Session[$_]}
                    $Data = ConvertTo-Json $SessionVars
                    Remove-Variable "SessionVars"
                    Break
                }
                "/watchdogtimers" {
                    $Data = ConvertTo-Json @($Session.WatchdogTimers | Select-Object)
                    Break
                }
                "/balances" {
                    $Balances = ($API.Balances | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Where-Object {$Parameters.add_total -or $_.Name -ne "*Total*"}
                    if ($Parameters.consolidate) {
                        $Balances = $Balances | Group-Object -Property Name | Foreach-Object {
                            $BalanceGroup = $_.Group | Where-Object {$Session.Rates."$($_.Currency)"}
                            [PSCustomObject]@{
                                Name = $_.Name
                                Total = [Decimal]($BalanceGroup | Foreach-Object {$_.Total / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                                Paid  = [Decimal]($BalanceGroup | Foreach-Object {$_.Paid / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                                Earnings  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                                Earnings_1h  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_1h / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                                Earnings_1d  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_1d / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                                Earnings_1w  = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_1w / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                                Earnings_Avg = [Decimal]($BalanceGroup | Foreach-Object {$_.Earnings_Avg / $Session.Rates."$($_.Currency)"} | Measure-Object -Sum).Sum
                            }
                        }
                    }
                                        
                    if ($Parameters.as_csv) {
                        if (-not $Parameters.consolidate) {
                            $Balances = $Balances | Foreach-Object {
                                $Rate = $Session.Rates."$($_.Currency)"
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
                        if ($Parameters.add_btc) {
                            $Balances | Foreach-Object {
                                $Rate = $Session.Rates."$($_.Currency)"
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
                            $Balances | Where-Object {$_.Name -ne "*Total*"} | Foreach-Object {
                                if ($_.Last_Earnings -ne $null) {$_.PSObject.Properties.Remove("Last_Earnings")}
                                if ($_.Payouts -ne $null) {$_.PSObject.Properties.Remove("Payouts")}
                            }
                        }
                        $Balances | Where-Object {$_.Started} | Foreach-Object {$_.Started = ([DateTime]$_.Started).ToString("yyyy-MM-dd HH:mm:ss")}
                        $Data = ConvertTo-Json @($Balances | Select-Object) -Depth 10
                    }
                    Remove-Variable "Balances" -Force -ErrorAction Ignore
                    Break
                }
                "/payouts" {
                    $Data = ConvertTo-Json @(($API.Balances | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Where {$_.Currency -ne $null -and $_.Payouts} | Select-Object BaseName,Currency,Payouts | Foreach-Object {
                        $Balance_BaseName = $_.BaseName
                        $Balance_Currency = $_.Currency
                        $_.Payouts | Foreach-Object {
                            $DateTime = "$(if ($_.time) {$_.time} elseif ($_.date) {$_.date} elseif ($_.datetime) {$_.datetime})"
                            [PSCustomObject]@{
                                Name     = $Balance_BaseName
                                Currency = $Balance_Currency
                                Date     = $(if ($DateTime -match "^\d+$") {[DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc') + [TimeSpan]::FromSeconds($DateTime)} else {(Get-Date $DateTime).ToUniversalTime()}).ToString("yyyy-MM-dd HH:mm:ss")
                                Amount   = [Double]$_.amount
                                Txid     = "$(if ($_.tx) {$_.tx} elseif ($_.txid) {$_.txid} elseif ($_.txHash) {$_.txHash})"
                            }
                        }
                    } | Sort-Object Date,Name,Currency | Select-Object)
                    Break
                }
                "/rates" {
                    $Data = ConvertTo-Json @($Session.Rates | Select-Object)
                    Break
                }
                "/asyncloaderjobs" {
                    $Data = ConvertTo-Json @($Asyncloader.Jobs | Select-Object)
                    Break
                }
                "/decsep" {
                    $Data = (Get-Culture).NumberFormat.NumberDecimalSeparator | ConvertTo-Json
                    Break
                }
                "/minerstats" {
                    [hashtable]$JsonUri_Dates = @{}
                    [hashtable]$Miners_List = @{}
                    [System.Collections.ArrayList]$Out = @()
                    ($API.Miners | Select-Object | ConvertFrom-Json -ErrorAction Ignore) | Where-Object {$_.DeviceModel -notmatch '-' -or $Session.Config.MiningMode -eq "legacy"} | Select-Object BaseName,Name,Path,HashRates,DeviceModel,MSIAprofile,OCprofile,PowerDraw,Ratios | Foreach-Object {
                        if (-not $JsonUri_Dates.ContainsKey($_.BaseName)) {
                            $JsonUri = Join-Path (Get-MinerInstPath $_.Path) "_uri.json"
                            $JsonUri_Dates[$_.BaseName] = if (Test-Path $JsonUri) {(Get-ChildItem $JsonUri -ErrorAction Ignore).LastWriteTime.ToUniversalTime()} else {$null}
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
                            $Miner_NeedsBenchmark = $Miner_Path -and $Miner_Path.LastWriteTime.ToUniversalTime() -lt $JsonUri_Dates[$_.BaseName]
                            $Miner_DeviceModel = if ($Session.Config.MiningMode -eq "legacy" -and $_.DeviceModel -match "-") {$Session.DevicesToVendors."$($_.DeviceModel)"} else {$_.DeviceModel}
                            if ($Miner_DeviceModel -notmatch "-" -or $Miner_Path) {
                                $Out.Add([PSCustomObject]@{
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
                                })>$null
                            }
                        }
                    }
                    $Data = ConvertTo-Json @($Out)
                    $Out.Clear()
                    $JsonUri_Dates.Clear()
                    $Miners_List.Clear()
                    Remove-Variable "Out" -ErrorAction Ignore
                    Remove-Variable "JsonUri_Dates" -ErrorAction Ignore
                    Remove-Variable "Miners_List" -ErrorAction Ignore
                    Break
                }
                "/activity" {
                    $LimitDays = (Get-Date).ToUniversalTime().AddDays(-2)
                    $BigJson = ''
                    Get-ChildItem "Logs\Activity_*.txt" -ErrorAction Ignore | Where-Object LastWriteTime -gt $LimitDays | Sort-Object LastWriteTime -Descending | Get-Content -Raw -ErrorAction Ignore | Foreach-Object {$BigJson += $_}
                    $GroupedData = "[$($BigJson -replace "[,\r\n]+$")]" | ConvertFrom-Json -ErrorAction Ignore
                    $Data = $GroupedData | Where-Object ActiveStart -ne "0001-01-01 00:00:00" | Group-Object ActiveStart,Name,Device | Foreach-Object {
                        $AvgProfit     = ($_.Group | Measure-Object Profit -Average).Average
                        $AvgPowerDraw  = ($_.Group | Measure-Object PowerDraw -Average).Average
                        $One           = $_.Group | Sort-Object ActiveLast -Descending | Select-Object -First 1
                        $Active        = ((Get-Date $One.ActiveLast)-(Get-Date $One.ActiveStart)).TotalMinutes
                        $One.Profit    = $AvgProfit
                        if ($One.PowerDraw -eq $null) {$One | Add-Member PowerDraw $AvgPowerDraw -Force} else {$One.PowerDraw = $AvgPowerDraw}
                        $One | Add-Member TotalPowerDraw ($AvgPowerDraw * $Active / 60000) #kWh
                        $One | Add-Member TotalProfit ($AvgProfit * $Active / 1440)
                        $One | Add-Member Active $Active -PassThru
                    } | Sort-Object ActiveStart,Name,Device | ConvertTo-Json
                    Remove-Variable "BigJson" -ErrorAction Ignore
                    Remove-Variable "GroupedData" -ErrorAction Ignore
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
                    $RemoteMiners = $API.RemoteMiners | Select-Object | ConvertFrom-Json -ErrorAction Ignore
                    $RemoteMiners | Where-Object {[Math]::Floor(([DateTime]::UtcNow - [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc')).TotalSeconds)-5*60 -lt $_.lastseen} | Foreach-Object {$Profit += [decimal]$_.profit;$Earnings_Avg = [Math]::Max($Earnings_Avg,[decimal]$_.earnings_avg);$Earnings_1d = [Math]::Max($Earnings_1d,[decimal]$_.earnings_1d)}
                    $Rates = [PSCustomObject]@{}; $Session.Rates.Keys | Where-Object {$Session.Config.Currency -icontains $_} | Foreach-Object {$Rates | Add-Member $_ $Session.Rates.$_}
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
                    $Data  = [PSCustomObject]@{AllProfitBTC=$Profit;ProfitBTC=[decimal]$API.CurrentProfit;Earnings_Avg=[decimal]$API.Earnings_Avg;Earnings_1d=[decimal]$API.Earnings_1d;AllEarnings_Avg=$Earnings_Avg;AllEarnings_1d=$Earnings_1d;Rates=$Rates;;PowerPrice=$Session.CurrentPowerPrice;Uptime=$Uptime;SysUptime=$SysUptime} | ConvertTo-Json
                    Remove-Variable "Rates" -ErrorAction Ignore
                    Remove-Variable "RemoteMiners" -ErrorAction Ignore
                    Remove-Variable "Timer" -ErrorAction Ignore
                    Remove-Variable "Uptime" -ErrorAction Ignore
                    Remove-Variable "SysUptime" -ErrorAction Ignore
                    Break
                }
                "/stop" {
                    $API.Stop = $true
                    $Data = "Stopping"
                    Break
                }
                "/pause" {
                    $API.Pause = -not $API.Pause
                    $Data = $API.Pause | ConvertTo-Json
                    Break
                }
                "/lockminers" {
                    $API.LockMiners = -not $API.LockMiners
                    $Data = $API.LockMiners | ConvertTo-Json
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
                "/status" {
                    $Data = [PSCustomObject]@{Pause=$API.Pause;LockMiners=$Session.LockMiners;IsExclusiveRun=$Session.IsExclusiveRun;IsDonationRun=$Session.IsDonationRun} | ConvertTo-Json
                    Break
                }
                "/clients" {
                    $Data = ConvertTo-Json @($Clients | Select-Object)
                    Break
                }
                "/getconfig" {
                    $Status = $false
                    if ($API.IsServer -and -not (Compare-Version $Session.Version $Parameters.version -revs 1)) {
                        if ($Parameters.workername -and $Parameters.machinename) {
                            $Client = $Clients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                            if ($Client) {
                                $Client.machineip = $Parameters.myip
                                $Client.timestamp = Get-UnixTimestamp
                            }
                            else {$Clients += [PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; timestamp = Get-UnixTimestamp}}
                        }
                        $Result = [PSCustomObject]@{}
                        $Parameters.config -split ',' | Where-Object {$_} | Foreach-Object {
                            $GetConfigA = @($_ -split 'ZZZ' | Select-Object)
                            if ($PathToFile = Get-ConfigPath -ConfigName $GetConfigA[0] -WorkerName $Parameters.workername -GroupName $Parameters.groupname) {
                                $ConfigLwt = Get-UnixTimestamp (Get-ChildItem $PathToFile).LastWriteTime.ToUniversalTime()
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
                        $Result = if (-not $API.IsServer) {"$($Session.MachineName) is not a server"}
                              elseif ($Session.Version -ne $Parameters.version) {"Server runs on wrong Version v$($Session.Version)"}
                              else {"No data found"}
                    }
                    $Data = [PSCustomObject]@{Status=$Status;Content=$Result;ExcludeList=$Session.Config.ExcludeServerConfigVars} | ConvertTo-Json -Depth 10
                    Remove-Variable "Result" -ErrorAction Ignore
                    Break
                }
                "/getjob" {
                    if ($API.IsServer) {
                        $Status = $false
                        if ($Parameters.workername -and $Parameters.machinename) {
                            $Client = $Clients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                            if ($Client) {
                                $Client.machineip = $Parameters.myip
                                $Client.timestamp = Get-UnixTimestamp
                            }
                            else {$Clients += [PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; timestamp = Get-UnixTimestamp}}
                        }
                        $Result = $null
                        try {
                            $pbody = $null
                            if ($Parameters.body -match "^{.+}$") {
                                $pbody_in = $Parameters.body | ConvertFrom-Json -ErrorAction Ignore
                                $pbody_in.PSObject.Properties | Foreach-Object {if ($pbody -eq $null) {$pbody = @{}};$pbody[$_.Name] = $_.Value}
                                Remove-Variable "pbody_in" -ErrorAction Ignore
                            }
                            $pheaders = $null
                            if ($Parameters.headers -match "^{.+}$") {
                                $pheaders_in = $Parameters.headers | ConvertFrom-Json -ErrorAction Ignore
                                $pheaders_in.PSObject.Properties | Foreach-Object {if ($pheaders -eq $null) {$pheaders = @{}};$pheaders[$_.Name] = $_.Value}
                                Remove-Variable "pheaders_in" -ErrorAction Ignore
                            }
                            if ($Parameters.jobkey -eq "morerates") {
                                try {
                                    $RatesUri = [System.Uri]$Parameters.url
                                    $RatesQry = [System.Web.HttpUtility]::ParseQueryString($RatesUri.Query)
                                    if ($Session.GlobalGetTicker -isnot [array]) {$Session.GlobalGetTicker = @()}
                                    Compare-Object $Session.GlobalGetTicker @([System.Web.HttpUtility]::UrlDecode($RatesQry["symbols"]) -split ',' | Select-Object) | Where-Object {$_.SideIndicator -eq "=>" -and $_.InputObject} | Foreach-Object {$Session.GlobalGetTicker += $_.InputObject.ToUpper()}
                                    $SymbolStr = "$(($Session.GlobalGetTicker | Sort-Object) -join ',')".ToUpper()
                                    $Parameters.url = "https://rbminer.net/api/cmc.php?symbols=$($SymbolStr)"
                                    Remove-Variable "RatesUri" -ErrorAction Ignore
                                    Remove-Variable "RatesQry" -ErrorAction Ignore
                                    Remove-Variable "SymbolStr" -ErrorAction Ignore
                                } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                            }
                            $Result = Invoke-GetUrlAsync $Parameters.url -method $Parameters.method -cycletime $Parameters.cycletime -retry $Parameters.retry -retrywait $Parameters.retrywait -tag $Parameters.tag -delay $Parameters.delay -timeout $Parameters.timeout -body $pbody -headers $pheaders -jobkey $Parameters.jobkey
                            if ($Result) {$Status = $true}
                        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        $Data = [PSCustomObject]@{Status=$Status;Content=if (($Result.GetType()).IsArray) {@($Result | Select-Object)} else {$Result}} | ConvertTo-Json -Depth 10 -Compress
                        if ($pbody -ne $null) {Remove-Variable "pbody" -ErrorAction Ignore}
                        if ($pheaders -ne $null) {Remove-Variable "pheaders" -ErrorAction Ignore}
                        if ($Result -ne $null) {Remove-Variable "Result" -ErrorAction Ignore}
                    }
                    break
                }
                "/getmrr" {
                    if ($API.IsServer) {
                        $Status = $false
                        if ($Parameters.workername -and $Parameters.machinename) {
                            $Client = $Clients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                            if ($Client) {
                                $Client.machineip = $Parameters.myip
                                $Client.timestamp = Get-UnixTimestamp
                            }
                            else {$Clients += [PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; timestamp = Get-UnixTimestamp}}
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
                                $Result = Invoke-MiningRigRentalRequest $Parameters.endpoint $Parameters.key $Parameters.secret -method $Parameters.method -params $Params -Timeout $Parameters.Timeout -Cache 30 -nonce $Parameters.nonce -Raw
                                $Status = $true
                            }
                        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        $Data = [PSCustomObject]@{Status=$Status;Content=$Result} | ConvertTo-Json -Depth 10 -Compress
                        if ($Result -ne $null) {Remove-Variable "Result" -ErrorAction Ignore}
                    }
                    break
                }
                "/getnh" {
                    if ($API.IsServer) {
                        $Status = $false
                        if ($Parameters.workername -and $Parameters.machinename) {
                            $Client = $Clients | Where-Object {$_.workername -eq $Parameters.workername -and $_.machinename -eq $Parameters.machinename}
                            if ($Client) {
                                $Client.machineip = $Parameters.myip
                                $Client.timestamp = Get-UnixTimestamp
                            }
                            else {$Clients += [PSCustomObject]@{workername = $Parameters.workername; machinename = $Parameters.machinename; machineip = $Parameters.myip; timestamp = Get-UnixTimestamp}}
                        }
                        $Result = $null
                        try {
                            if (-not $Parameters.key) {
                                $PoolName = if ($Session.Config.Pools.NiceHash.Platform -in @("2","v2","new") -and $Session.Config.Pools.NiceHash.API_Key  -and $Session.Config.Pools.NiceHash.API_Secret -and $Session.Config.Pools.NiceHash.OrganizationID) {"NiceHash"}
                                            elseif ($Session.Config.Pools.NiceHashV2.API_Key -and $Session.Config.Pools.NiceHashV2.API_Secret -and $Session.Config.Pools.NiceHashV2.OrganizationID) {"NiceHashV2"}
                                if ($PoolName) {
                                    $Parameters | Add-Member key    $Session.Config.Pools.$PoolName.API_Key -Force
                                    $Parameters | Add-Member secret $Session.Config.Pools.$PoolName.API_Secret -Force
                                    $Parameters | Add-Member orgid  $Session.Config.Pools.$PoolName.OrganizationID -Force
                                }
                            }
                            if ($Parameters.key -and $Parameters.secret -and $Parameters.orgid) {
                                $Params = [hashtable]@{}
                                ($Parameters.params | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Where-Object MemberType -eq "NoteProperty" | Foreach-Object {$Params[$_.Name] = $_.Value}
                                $Result = Invoke-NHRequest $Parameters.endpoint $Parameters.key $Parameters.secret $Parameters.orgid -method $Parameters.method -params $Params -Timeout $Parameters.Timeout -Cache 30 -nonce $Parameters.nonce -Raw
                                $Status = $true
                            }
                        } catch {if ($Error.Count){$Error.RemoveAt(0)}}
                        $Data = [PSCustomObject]@{Status=$Status;Content=$Result} | ConvertTo-Json -Depth 10 -Compress
                        if ($Result -ne $null) {Remove-Variable "Result" -ErrorAction Ignore}
                    }
                    break
                }
                "/mrrstats" {
                    [System.Collections.ArrayList]$Mrr_Data = @()
                    $CpuDevices = ($Session.Devices | Where-Object Type -eq "CPU" | Measure-Object).Count
                    $GpuDevices = ($Session.Devices | Where-Object Type -eq "GPU" | Measure-Object).Count

                    if ($Pool_Request = Get-MiningRigRentalAlgos) {
                        [hashtable]$StatsCPU = @{}
                        [hashtable]$StatsGPU = @{}
                        if ($CpuDevices) {
                            $Session.Stats.Keys | Where-Object {$_ -match "CPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsCPU[$Matches[1]] -lt $Session.Stats.$_.Day) {$StatsCPU[$Matches[1]] = $Session.Stats.$_.Day}}
                            $API.ActiveMiners | Where-Object {$_.DeviceName -match "CPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsCPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                        }
                        if ($GpuDevices) {
                            $Session.Stats.Keys | Where-Object {$_ -match "GPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsGPU[$Matches[1]] -lt $Session.Stats.$_.Day) {$StatsGPU[$Matches[1]] = $Session.Stats.$_.Day}}
                            $API.ActiveMiners | Where-Object {$_.DeviceName -match "GPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsGPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                        }
                        $Pool_Request | Foreach-Object {
                            $Algo  = Get-MiningRigRentalAlgorithm $_.name
                            $Speed = [Double]$StatsCPU[$Algo] + [Double]$StatsGPU[$Algo]
                            $Mrr_Data.Add([PSCustomObject]@{
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
                            }) > $null
                        }
                        Remove-Variable "StatsCPU"
                        Remove-Variable "StatsGPU"
                        Remove-Variable "Pool_Request"
                    }
                    $Data = ConvertTo-Json @($Mrr_Data) -Depth 10 -Compress
                    Remove-Variable "Mrr_Data"
                    break
                }
                "/mrrrigs" {
                    [System.Collections.ArrayList]$Mrr_Data = @()
                    $CpuDevices = ($Session.Devices | Where-Object Type -eq "CPU" | Measure-Object).Count
                    $GpuDevices = ($Session.Devices | Where-Object Type -eq "GPU" | Measure-Object).Count

                    if ($Session.Config.Pools.MiningRigRentals.API_Key -and $Session.Config.Pools.MiningRigRentals.API_Secret) {
                        $Workers = @($Session.Config.DeviceModel | Where-Object {$Session.Config.Devices.$_.Worker} | Foreach-Object {$Session.Config.Devices.$_.Worker} | Select-Object -Unique) + $Session.Config.WorkerName | Select-Object -Unique
                        if (($Pool_Request = Get-MiningRigRentalAlgos) -and ($AllRigs_Request = Get-MiningRigRentalRigs -key $Session.Config.Pools.MiningRigRentals.API_Key -secret $Session.Config.Pools.MiningRigRentals.API_Secret -workers $Workers)) {
                            [hashtable]$StatsCPU = @{}
                            [hashtable]$StatsGPU = @{}
                            if ($CpuDevices) {
                                $Session.Stats.Keys | Where-Object {$_ -match "CPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsCPU[$Matches[1]] -lt $Session.Stats.$_.Day) {$StatsCPU[$Matches[1]] = $Session.Stats.$_.Day}}
                                $API.ActiveMiners | Where-Object {$_.DeviceName -match "CPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsCPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                            }
                            if ($GpuDevices) {
                                $Session.Stats.Keys | Where-Object {$_ -match "GPU#.+_(.+)_HashRate"} | Foreach-Object {if ($StatsGPU[$Matches[1]] -lt $Session.Stats.$_.Day) {$StatsGPU[$Matches[1]] = $Session.Stats.$_.Day}}
                                $API.ActiveMiners | Where-Object {$_.DeviceName -match "GPU"} | Group-Object {$_.BaseAlgorithm[0]} | Foreach-Object {$StatsGPU[$_.Name] = ($_.Group.Speed | Measure-Object -Maximum).Maximum}
                            }
                            $AllRigs_Request | Foreach-Object {
                                $Rig = $_
                                $Pool_Data = $Pool_Request | Where-Object {$_.name -eq $Rig.type}
                                $Algo  = Get-MiningRigRentalAlgorithm $_.type
                                $Speed = [Double]$StatsCPU[$Algo] + [Double]$StatsGPU[$Algo]
                                $Mrr_Data.Add([PSCustomObject]@{
                                    Algorithm = $Algo
                                    Title     = $Pool_Data.display
                                    SuggPrice = $Pool_Data.suggested_price.amount
                                    LastPrice = $Pool_Data.stats.prices.last.amount
                                    RigsPrice = [double]$Rig.hashrate.advertised.hash*[double]$Rig.price.BTC.price
                                    Unit      = $Pool_Data.hashtype.ToUpper()
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
                                }) > $null
                            }
                            Remove-Variable "StatsCPU"
                            Remove-Variable "StatsGPU"
                            Remove-Variable "AllRigs_Request"
                        }
                        if ($Pool_Request) {Remove-Variable "Pool_Request"}
                    }
                    $Data = ConvertTo-Json @($Mrr_Data) -Depth 10 -Compress
                    Remove-Variable "Mrr_Data"
                    break
                }
                default {
                    # Set index page
                    if ($Path -eq "/") {
                        $Path = "/index.html"
                    }

                    # Check if there is a file with the requested path
                    $Filename = $BasePath + $Path
                    if (Test-Path $Filename -PathType Leaf) {
                        # If the file is a powershell script, execute it and return the output. A $Parameters parameter is sent built from the query string
                        # Otherwise, just return the contents of the file
                        $File = Get-ChildItem $Filename -ErrorAction Ignore

                        If ($File.Extension -eq ".ps1") {
                            $Data = (& $File.FullName -Parameters $Parameters) -join "`r`n"
                        } elseif (@(".html",".css",".js",".json",".xml",".txt") -icontains $File.Extension) {
                            $Data = Get-Content $Filename -Raw -ErrorAction Ignore

                            if ($Data -and $File.Extension -match "htm") {
                                # Process server side includes for html files
                                # Includes are in the traditional '<!-- #include file="/path/filename.html" -->' format used by many web servers
                                $IncludeRegex = [regex]'<!-- *#include *file="(.*)" *-->'
                                $IncludeRegex.Matches($Data) | Foreach-Object {
                                    $IncludeFile = $BasePath +'/' + $_.Groups[1].Value
                                    If (Test-Path $IncludeFile -PathType Leaf) {
                                        $IncludeData = Get-Content $IncludeFile -Raw -ErrorAction Ignore
                                        $Data = $Data -Replace $_.Value, $IncludeData
                                    }
                                }
                            }
                        } else {
                            $Data = [System.IO.File]::ReadAllBytes($File.FullName)
                        }

                        # Set content type based on file extension
                        If ($MIMETypes.ContainsKey($File.Extension)) {
                            $ContentType = $MIMETypes[$File.Extension]
                        } else {
                            # If it's an unrecognized file type, prompt for download
                            $ContentType = "application/octet-stream"
                        }
                    } else {
                        $StatusCode = 404
                        $ContentType = "text/html"
                        $Data = "URI '$Path' is not a valid resource."
                    }
                }
            }
            }

            # If $Data is null, the API will just return whatever data was in the previous request.  Instead, show an error
            # This happens if the script just started and hasn't filled all the properties in yet.
            If($Data -eq $Null) { 
                $Data = @{'Error' = "API data not available"} | ConvertTo-Json
            }

            # Send the response
			$Response.Headers.Add("Accept-Encoding","gzip");
			$Response.Headers.Add("Server","RainbowMiner API on $($Session.MachineName)");
			$Response.Headers.Add("X-Powered-By","Microsoft PowerShell");
            $Response.Headers.Add("Content-Type", $ContentType)
            #if ($StatusCode -eq 401) {$Response.Headers.Add("WWW-Authenticate","Basic Realm=`"RainbowMiner API`"")}
            if ($ContentFileName -ne "") {$Response.Headers.Add("Content-Disposition", "attachment; filename=$($ContentFileName)")}
            $Response.StatusCode = $StatusCode
            $ResponseBuffer = if ($Data -is [string]) {[System.Text.Encoding]::UTF8.GetBytes($Data)} else {$Data}
            $Response.ContentLength64 = $ResponseBuffer.Length
            $Response.OutputStream.Write($ResponseBuffer,0,$ResponseBuffer.Length)
            $Response.Close()
            if ($Error.Count -and $Session.LogLevel -ne "Silent") {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").api.txt" -Append -Encoding utf8}
            $Error.Clear()
            Foreach ($var in @("Context","Data","ContentEncoding","InputStream","Parameters","Request","Response","ResponseBuffer","task")) {Remove-Variable $var -Force -ErrorAction Ignore}
        }
        # Only gets here if something is wrong and the server couldn't start or stops listening
        $Server.Stop()
        $Server.Close()
    }) #end of $apiserver

    $API.Server.Runspace = $newRunspace
    $API.Handle = $API.Server.BeginInvoke()
}

Function Stop-APIServer {
    try {Invoke-GetUrl "http://localhost:$($API.APIport)/$($API.RandTag)" -user $API.APIUser -password $API.APIpassword -method Web -timeout 5 > $null} catch {if ($Error.Count){$Error.RemoveAt(0)};$API.Stop = $true}
    if ($Global:API.Server) {$Global:API.Server.dispose()}
    $Global:API.Server = $null
    $Global:API.Handle = $null
    Remove-Variable "API" -Scope Global -Force    
}

function Set-APIInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $true)]
        $Value
    )
    if (-not $API.Info) {$API.Info = [hashtable]@{}}
    $API.Info[$Name] = $Value
}

function Set-APICredentials {
    $API.APIAuth     = $Session.Config.APIAuth -and $Session.Config.APIUser -and $Session.Config.APIPassword
    $API.APIUser     = $Session.Config.APIUser
    $API.APIPassword = $Session.Config.APIPassword
}

function Get-APIServerName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Protocol = "TCP"
    )
    "RainbowMiner API $($Port)$(if ($Protocol -ne "TCP") {" $Protocol"})"
}

function Send-APIServerUdp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [String]$MachineName = [System.Environment]::MachineName,
        [Parameter(Mandatory = $false)]
        [String]$IPaddress = ""
    )
    
    try {
        $UdpClient   = new-Object system.Net.Sockets.Udpclient 
        if ($UdpClient) {
            $Buffer = "RBM:$($MachineName):$(if ($IPaddress) {$IPaddress} else {Get-MyIP}):$($Port)"
            $byteBuffer = [System.Text.Encoding]::ASCII.GetBytes($Buffer)
            $UdpClient.Send($byteBuffer, $byteBuffer.length, [system.net.IPAddress]::Broadcast, $Port)
        }
        $true
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
}

function Test-APIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [string]$Type = "all"
    )
    $rv = $true
    if ($IsWindows) {
        if ($rv -and ($Type -eq "firewall" -or $Type -eq "firewall-tcp" -or $Type -eq "all")) {
            $FWLname = Get-APIServerName -Port $Port -Protocol "TCP"
            $fwlACLs = & netsh advfirewall firewall show rule name="$($FWLname)" | Out-String
            if (-not $fwlACLs.Contains($FWLname)) {$rv = $false}
        }
        if ($rv -and ($Type -eq "firewall" -or $Type -eq "firewall-udp" -or $Type -eq "all")) {
            $FWLname = Get-APIServerName -Port $Port -Protocol "UDP"
            $fwlACLs = & netsh advfirewall firewall show rule name="$($FWLname)" | Out-String
            if (-not $fwlACLs.Contains($FWLname)) {$rv = $false}
        }
        if ($rv -and ($Type -eq "url" -or $Type -eq "all")) {
            $urlACLs = & netsh http show urlacl | Out-String
            if (-not $urlACLs.Contains("http://+:$($Port)/")) {$rv = $false}
        }
    }
    $rv
}

function Initialize-APIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )

    if ($IsWindows) {
        if (-not (Test-APIServer -Port $Port -Type "url")) {
            # S-1-5-32-545 is the well known SID for the Users group. Use the SID because the name Users is localized for different languages
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "http add urlacl url=http://+:$($Port)/ sddl=D:(A;;GX;;;S-1-5-32-545) user=everyone").WaitForExit(5000)>$null
        }

        if (-not (Test-APIServer -Port $Port -Type "firewall-tcp")) {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"$(Get-APIServerName -Port $Port -Protocol "TCP")`" dir=in action=allow protocol=TCP localport=$($Port)").WaitForExit(5000)>$null
        }

        if (-not (Test-APIServer -Port $Port -Type "firewall-udp")) {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"$(Get-APIServerName -Port $Port -Protocol "UDP")`" dir=in action=allow protocol=UDP localport=$($Port)").WaitForExit(5000)>$null
        }
    }
}

function Reset-APIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )

    if ($IsWindows) {
        if (Test-APIServer -Port $Port -Type "url") {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "http delete urlacl url=http://+:$($Port)/").WaitForExit(5000)>$null
        }

        if (Test-APIServer -Port $Port -Type "firewall")  {
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall delete rule name=`"$(Get-APIServerName -Port $Port -Protocol "TCP")`"").WaitForExit(5000)>$null
            (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall delete rule name=`"$(Get-APIServerName -Port $Port -Protocol "UDP")`"").WaitForExit(5000)>$null
        }
    }
}
