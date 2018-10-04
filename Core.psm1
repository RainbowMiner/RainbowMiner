function Start-Core {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$ConfigFile = ".\Config\config.txt"
    )

    $Session.Timer = (Get-Date).ToUniversalTime()
    $Session.NextReport = $Session.Timer
    $Session.StatEnd = $Session.Timer
    $Session.DecayStart = $Session.Timer

    $Session.ActiveMiners = @()
    $Session.AllPools = $null
    $Session.WatchdogTimers = @()
    [hashtable]$Session.Rates = @{BTC = [Double]1}
    [hashtable]$Session.ConfigFiles = @{
        Config     = @{Path='';LastWriteTime=0}
        Devices    = @{Path='';LastWriteTime=0}
        Miners     = @{Path='';LastWriteTime=0}
        OCProfiles = @{Path='';LastWriteTime=0}
        Pools      = @{Path='';LastWriteTime=0}
    }

    $Session.LastDonated = 0

    $Session.SkipSwitchingPrevention = $false
    $Session.StartDownloader = $false
    $Session.PauseMiners = $false
    $Session.RestartMiners = $false
    $Session.Restart = $false
    $Session.AutoUpdate = $false
    $Session.MSIAcurrentprofile = -1
    $Session.RunSetup = $false
    $Session.IsInitialSetup = $false
    $Session.IsDonationRun = $false
    $Session.Stopp = $false
    [hashtable]$Session.Updatetracker = @{
        Balances = $Session.Timer
    }

    #Cleanup the log
    if (Test-Path ".\Logs"){
        Get-ChildItem -Path ".\Logs" -Filter "*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-5)} | Remove-Item -ErrorAction Ignore
    } else {
        New-Item ".\Logs" -ItemType "directory" -Force > $null
    }

    Write-Host "Detecting devices .."

    $Session.AllDevices = Get-Device "cpu","gpu"

    Write-Host "Initialize configuration .."
    try {
        $RunCleanup = $true
        $ConfigPath = [IO.Path]::GetDirectoryName($ConfigFile)
        if (-not $ConfigPath) {$ConfigPath = ".\Config"; $ConfigFile = "$($ConfigPath)\$($ConfigFile)"}
        if (-not (Test-Path $ConfigPath)) {$RunCleanup = $false;New-Item $ConfigPath -ItemType "directory" -Force > $null}
        if (-not (Test-Path "$ConfigPath\Backup")) {New-Item "$ConfigPath\Backup" -ItemType "directory" -Force > $null}    
        if (-not [IO.Path]::GetExtension($ConfigFile)) {$ConfigFile = "$($ConfigFile).txt"}
        if (-not (Test-Path $ConfigFile)) {
            $Parameters = @{VersionCompatibility=$Session.Version}
            $Session.DefaultValues.Keys | ForEach-Object {$Parameters | Add-Member $_ "`$$($_)" -ErrorAction SilentlyContinue}
            Set-ContentJson -PathToFile $ConfigFile -Data $Parameters > $null        
        } else {
            $ConfigForUpdate = Get-Content $ConfigFile | ConvertFrom-Json
            $ConfigForUpdate_changed = $false
            Compare-Object @($ConfigForUpdate.PSObject.Properties.Name) @($Session.DefaultValues.Keys) | Foreach-Object {
                if ($_.SideIndicator -eq "=>") {$ConfigForUpdate | Add-Member $_.InputObject "`$$($_.InputObject)";$ConfigForUpdate_changed=$true}
                elseif ($_.SideIndicator -eq "<=" -and @("ConfigFile","ExcludeNegativeProfit","DisableAutoUpdate","Regin","Debug","Verbose","ErrorAction","WarningAction","InformationAction","ErrorVariable","WarningVariable","InformationVariable","OutVariable","OutBuffer","PipelineVariable") -icontains $_.InputObject) {$ConfigForUpdate.PSObject.Properties.Remove($_.InputObject);$ConfigForUpdate_changed=$true}
            }
            if ($ConfigForUpdate_changed) {Set-ContentJson -PathToFile $ConfigFile -Data $ConfigForUpdate > $null}
        }
        $Session.ConfigFiles["Config"].Path = Get-Item $ConfigFile | Foreach-Object {
            $ConfigFile_Path = $_ | Select-Object -ExpandProperty DirectoryName
            $ConfigFile_Name = $_ | Select-Object -ExpandProperty Name
            $Session.ConfigFiles["Pools"].Path = @($ConfigFile_Path,"\pools.",$ConfigFile_Name) -join ''
            $Session.ConfigFiles["Miners"].Path = @($ConfigFile_Path,"\miners.",$ConfigFile_Name) -join ''
            $Session.ConfigFiles["Devices"].Path = @($ConfigFile_Path,"\devices.",$ConfigFile_Name) -join ''
            $Session.ConfigFiles["OCProfiles"].Path = @($ConfigFile_Path,"\ocprofiles.",$ConfigFile_Name) -join ''

            if (-not $psISE) {
                $BackupDate = Get-Date -Format "yyyyMMddHHmmss"
                if (Test-Path $ConfigFile) {Copy-Item $ConfigFile -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_$($ConfigFile_Name)"}
                if (Test-Path $Session.ConfigFiles["Pools"].Path) {Copy-Item $Session.ConfigFiles["Pools"].Path -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_pools.$($ConfigFile_Name)"}
                if (Test-Path $Session.ConfigFiles["Miners"].Path) {Copy-Item $Session.ConfigFiles["Miners"].Path -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_miners.$($ConfigFile_Name)"}
                if (Test-Path $Session.ConfigFiles["Devices"].Path) {Copy-Item $Session.ConfigFiles["Devices"].Path -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_devices.$($ConfigFile_Name)"}
                if (Test-Path $Session.ConfigFiles["OCProfiles"].Path) {Copy-Item $Session.ConfigFiles["OCProfiles"].Path -Destination "$($ConfigFile_Path)\Backup\$($BackupDate)_ocprofiles.$($ConfigFile_Name)"}
            }
        
            # Create pools.config.txt if it is missing
            Set-PoolsConfigDefault -PathToFile $Session.ConfigFiles["Pools"].Path -Force
            $Session.ConfigFiles["Pools"].Path = $Session.ConfigFiles["Pools"].Path | Resolve-Path -Relative

            # Create miners.config.txt and cpu.miners.config.txt, if they are missing
            Set-MinersConfigDefault -PathToFile $Session.ConfigFiles["Miners"].Path -Force
            $Session.ConfigFiles["Miners"].Path = $Session.ConfigFiles["Miners"].Path | Resolve-Path -Relative

            # Create devices.config.txt if it is missing
            Set-DevicesConfigDefault -PathToFile $Session.ConfigFiles["Devices"].Path -Force
            $Session.ConfigFiles["Devices"].Path = $Session.ConfigFiles["Devices"].Path | Resolve-Path -Relative

            # Create ocprofiles.config.txt if it is missing
            Set-OCProfilesConfigDefault -PathToFile $Session.ConfigFiles["OCProfiles"].Path -Force
            $Session.ConfigFiles["OCProfiles"].Path = $Session.ConfigFiles["OCProfiles"].Path | Resolve-Path -Relative

            $_ | Resolve-Path -Relative
        }
    
        #cleanup legacy data
        if (Test-Path ".\Cleanup.ps1") {
            if ($RunCleanup) {
                Write-Host "Cleanup legacy data .."
                [hashtable]$Cleanup_Parameters = @{
                    ConfigFile = $Session.ConfigFiles["Config"].Path
                    PoolsConfigFile = $Session.ConfigFiles["Pools"].Path
                    MinersConfigFile = $Session.ConfigFiles["Miners"].Path
                    DevicesConfigFile = $Session.ConfigFiles["Devices"].Path
                    OCProfilesConfigFile = $Session.ConfigFiles["OCProfiles"].Path
                    AllDevices = $Session.AllDevices
                    MyCommandParameters = $Session.DefaultValues.Keys
                    Version = if (Test-Path ".\Data\Version.json") {(Get-Content ".\Data\Version.json" -Raw | ConvertFrom-Json -ErrorAction Ignore).Version}else{"0.0.0.0"}
                }        
                Get-Item ".\Cleanup.ps1" | Foreach-Object {
                    $Cleanup_Result = & {
                        foreach ($k in $Cleanup_Parameters.Keys) {Set-Variable $k $Cleanup_Parameters.$k}
                        & $_.FullName @Cleanup_Parameters
                    }
                    if ($Cleanup_Result) {Write-Host $Cleanup_Result}
                }            
            }
            Remove-Item ".\Cleanup.ps1" -Force
        }

        #Remove stuck update
        if (Test-Path "Start.bat.saved") {Remove-Item "Start.bat.saved" -Force}

        #write version to data
        Set-ContentJson -PathToFile ".\Data\Version.json" -Data ([PSCustomObject]@{Version=$Session.Version}) > $null
        $true
    }
    catch {
        Write-Log -Level Error "$($_) Cannot run RainbowMiner. "
        $false
    }
    #[console]::TreatControlCAsInput = $true
}

function Invoke-Core {

    #Load the config    
    $ConfigBackup = if ($Session.Config -is [object]){$Session.Config | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json}else{$null}
    $CheckConfig = $true
    
    [string[]]$Session.AvailPools = Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object
    [string[]]$Session.AvailMiners = Get-ChildItem ".\Miners\*.ps1" -File | Select-Object -ExpandProperty BaseName | Sort-Object

    if (Test-Path $Session.ConfigFiles["Config"].Path) {
        if (-not $Session.Config -or $Session.RunSetup -or (Get-ChildItem $Session.ConfigFiles["Config"].Path).LastWriteTime.ToUniversalTime() -gt $Session.ConfigFiles["Config"].LastWriteTime) {

            do {
                if ($Session.Config -eq $null) {Write-Host "Read configuration .."}
                $Session.ConfigFiles["Config"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Config"].Path).LastWriteTime.ToUniversalTime()
                $Parameters = @{}
                $Session.DefaultValues.Keys | ForEach-Object {
                    $val = $Session.DefaultValues[$_]
                    if ($val -is [array]) {$val = $val -join ','}
                    $Parameters.Add($_ , $val)
                }                
                $Session.Config = Get-ChildItemContent $Session.ConfigFiles["Config"].Path -Force -Parameters $Parameters | Select-Object -ExpandProperty Content
                $Session.Config | Add-Member Pools ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member Miners ([PSCustomObject]@{}) -Force
                $Session.Config | Add-Member OCProfiles ([PSCustomObject]@{}) -Force

                if (-not $Session.Config.Wallet -or -not $Session.Config.WorkerName -or -not $Session.Config.PoolName) {
                    $Session.IsInitialSetup = -not $Session.Config.Wallet -or -not $Session.Config.WorkerName
                    $Session.RunSetup = $true
                }

                $ReReadConfig = $false
                if ($Session.RunSetup) {
                    Import-Module .\Setup.psm1
                    Start-Setup -Config $Session.Config -ConfigFiles $Session.ConfigFiles -IsInitialSetup $Session.IsInitialSetup
                    Remove-Module "Setup" -ErrorAction Ignore
                    $Session.RestartMiners = $true
                    $ReReadConfig = $true
                    $Session.RunSetup = $false
                }

            } until (-not $ReReadConfig)
        } else {
            $CheckConfig = $false
        }
    }
    
    #Error in Config.txt
    if ($Session.Config -isnot [PSCustomObject]) {
        Write-Log -Level Error "$($Session.ConfigFiles["Config"].Path) is invalid. Cannot continue. "
        Start-Sleep 10
        Break
    }

    #Convert to array, if needed and check contents of some fields, if Config has been reread or reset
    if ($CheckConfig) {
        #for backwards compatibility
        if ($Session.Config.Type -ne $null) {$Session.Config | Add-Member DeviceName $Session.Config.Type -Force}
        if ($Session.Config.GPUs -ne $null -and $Session.Config.GPUs) {
            if ($Session.Config.GPUs -is [string]) {$Session.Config.GPUs = [regex]::split($Session.Config.GPUs,"\s*[,;:]+\s*")}
            $Session.Config | Add-Member DeviceName @() -Force
            Get-Device "nvidia" | Where-Object {$Session.Config.GPUs -contains $_.Type_Vendor_Index} | Foreach-Object {$Session.Config.DeviceName += [string]("GPU#{0:d2}" -f $_.Type_Vendor_Index)}
        }

        $Session.Config.PSObject.Properties | Where-Object {$_.TypeNameOfValue -ne "System.Object" -and $_.MemberType -eq "NoteProperty"} | Select-Object Name,Value | Foreach-Object {
            $name = $_.Name;
            $var = $Session.DefaultValues[$name]
            if ($var -is [array] -and $Session.Config.$name -is [string]) {$Session.Config.$name = $Session.Config.$name.Trim(); $Session.Config.$name = @(if ($Session.Config.$name -ne ''){@([regex]::split($Session.Config.$name.Trim(),"\s*[,;:]+\s*") | Where-Object {$_})})}
            elseif (($var -is [bool] -or $var -is [switch]) -and $Session.Config.$name -isnot [bool]) {$Session.Config.$name = Get-Yes $Session.Config.$name}
            elseif ($var -is [int] -and $Session.Config.$name -isnot [int]) {$Session.Config.$name = [int]$Session.Config.$name}
        }
        $Session.Config.Algorithm = @($Session.Config.Algorithm | ForEach-Object {Get-Algorithm $_} | Where-Object {$_})
        $Session.Config.ExcludeAlgorithm = @($Session.Config.ExcludeAlgorithm | ForEach-Object {Get-Algorithm $_} | Where-Object {$_})
        $Session.Config.Region = $Session.Config.Region | ForEach-Object {Get-Region $_}
        $Session.Config.Currency = @($Session.Config.Currency | ForEach-Object {$_.ToUpper()} | Where-Object {$_})
        $Session.Config.UIstyle = if ( $Session.Config.UIstyle -ne "full" -and $Session.Config.UIstyle -ne "lite" ) {"full"} else {$Session.Config.UIstyle}
        $Session.Config.PowerPriceCurrency = $Session.Config.PowerPriceCurrency | ForEach-Object {$_.ToUpper()}
        if (-not $Session.Config.LocalAPIport) {$Session.Config | Add-Member LocalAPIport 4000 -Force}
        Set-ContentJson -PathToFile ".\Data\localapiport.json" -Data @{LocalAPIport = $Session.Config.LocalAPIport} > $null

        #For backwards compatibility        
        if ($Session.Config.LegacyMode -ne $null) {$Session.Config.MiningMode = if (Get-Yes $Session.Config.LegacyMode){"legacy"}else{"device"}}
    }

    #Start/stop services
    if (($Session.Config.DisableAsyncLoader -or $Session.Config.Interval -ne $ConfigBackup.Interval) -and (Test-Path Variable:Global:Asyncloader)) {Stop-AsyncLoader}
    if (-not $Session.Config.DisableAsyncLoader -and -not (Test-Path Variable:Global:AsyncLoader)) {Start-AsyncLoader -Interval $Session.Config.Interval}
    if (-not $Session.Config.DisableMSIAmonitor -and -not (Test-Path Variable:Script:abMonitor))   {Start-Afterburner}
    if (-not $psISE -and ($Session.Config.DisableAPI -or $Session.Config.LocalAPIport -ne $ConfigBackup.LocalAPIport) -and (Test-Path Variable:Global:API)) {Stop-APIServer}
    if (-not $psISE -and -not $Session.Config.DisableAPI -and -not (Test-Path Variable:Global:API)) {
        Start-APIServer -RemoteAPI:$Session.Config.RemoteAPI -LocalAPIport:$Session.Config.LocalAPIport
    }
    if($psISE -and -not (Test-Path Variable:Global:API)) {
        $Global:API = [hashtable]@{}
        $API.Stop = $false
        $API.Pause = $false
        $API.Update = $false
        $API.RemoteAPI = $Session.Config.RemoteAPI
        $API.LocalAPIport = $Session.Config.LocalAPIport
    }

    #Versioncheck
    $ConfirmedVersion = Confirm-Version $Session.Version
    $API.Version = $ConfirmedVersion | ConvertTo-Json
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version -and $Session.Config.EnableAutoUpdate) {$API.Update = $Session.AutoUpdate = $true}

    #Give API access to all possible devices
    if ($API.AllDevices -eq $null) {$API.AllDevices = $Session.AllDevices | ConvertTo-Json -Depth 10}

    $MSIAenabled = -not $Session.Config.EnableOCProfiles -and $Session.Config.MSIAprofile -gt 0 -and (Test-Path $Session.Config.MSIApath)

    #Check for oc profile config
    Set-OCProfilesConfigDefault $Session.ConfigFiles["OCProfiles"].Path
    if (Test-Path $Session.ConfigFiles["OCProfiles"].Path) {
        if ($CheckConfig -or -not $Session.Config.OCProfiles -or (Get-ChildItem $Session.ConfigFiles["OCProfiles"].Path).LastWriteTime.ToUniversalTime() -gt $Session.ConfigFiles["OCProfiles"].LastWriteTime) {        
            $Session.ConfigFiles["OCProfiles"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["OCProfiles"].Path).LastWriteTime.ToUniversalTime()
            $Session.Config | Add-Member OCProfiles (Get-ChildItemContent $Session.ConfigFiles["OCProfiles"].Path).Content -Force
        }
    }   

    #Check for devices config
    Set-DevicesConfigDefault $Session.ConfigFiles["Devices"].Path
    if (Test-Path $Session.ConfigFiles["Devices"].Path) {
        if ($CheckConfig -or -not $Session.Config.Devices -or (Get-ChildItem $Session.ConfigFiles["Devices"].Path).LastWriteTime.ToUniversalTime() -gt $Session.ConfigFiles["Devices"].LastWriteTime) {        
            $Session.ConfigFiles["Devices"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Devices"].Path).LastWriteTime.ToUniversalTime()
            $Session.Config | Add-Member Devices (Get-ChildItemContent $Session.ConfigFiles["Devices"].Path).Content -Force
            $OCprofileFirst = $Session.Config.OCProfiles.PSObject.Properties.Name | Select-Object -First 1
            foreach ($p in @($Session.Config.Devices.PSObject.Properties.Name)) {
                $Session.Config.Devices.$p | Add-Member Algorithm @(($Session.Config.Devices.$p.Algorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                $Session.Config.Devices.$p | Add-Member ExcludeAlgorithm @(($Session.Config.Devices.$p.ExcludeAlgorithm | Select-Object) | Where-Object {$_} | Foreach-Object {Get-Algorithm $_}) -Force
                foreach ($q in @("MinerName","PoolName","ExcludeMinerName","ExcludePoolName")) {
                    if ($Session.Config.Devices.$p.$q -is [string]){$Session.Config.Devices.$p.$q = if ($Session.Config.Devices.$p.$q.Trim() -eq ""){@()}else{[regex]::split($Session.Config.Devices.$p.$q.Trim(),"\s*[,;:]+\s*")}}
                }
                $Session.Config.Devices.$p | Add-Member DisableDualMining ($Session.Config.Devices.$p.DisableDualMining -and (Get-Yes $Session.Config.Devices.$p.DisableDualMining)) -Force
                if ($p -ne "CPU" -and -not $Session.Config.Devices.$p.DefaultOCprofile) {
                    $Session.Config.Devices.$p | Add-Member DefaultOCprofile $OCprofileFirst -Force
                    if ($Session.Config.EnableOCprofiles) {
                        Write-Log -Level Warn "No default overclocking profile defined for `"$p`" in $($Session.ConfigFiles["OCProfiles"].Path). Using `"$OCprofileFirst`" for now!"
                    }
                }
            }
        }
    }

    #Check for pool config
    $CheckPools = $false
    Set-PoolsConfigDefault $Session.ConfigFiles["Pools"].Path
    if (Test-Path $Session.ConfigFiles["Pools"].Path) {
        if ($CheckConfig -or -not $Session.Config.Pools -or (Get-ChildItem $Session.ConfigFiles["Pools"].Path).LastWriteTime.ToUniversalTime() -gt $Session.ConfigFiles["Pools"].LastWriteTime) {        
            $Session.ConfigFiles["Pools"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Pools"].Path).LastWriteTime.ToUniversalTime()
            $Session.Config | Add-Member Pools (Get-ChildItemContent $Session.ConfigFiles["Pools"].Path -Parameters @{
                Wallet              = $Session.Config.Wallet
                UserName            = $Session.Config.UserName
                WorkerName          = $Session.Config.WorkerName
                API_ID              = $Session.Config.API_ID
                API_Key             = $Session.Config.API_Key
            } | Select-Object -ExpandProperty Content) -Force
            $CheckPools = $true
        }
    }    

    $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_} | ForEach-Object {
        $Session.Config.Pools | Add-Member $_ (
            [PSCustomObject]@{
                BTC     = $Session.Config.Wallet
                User    = $Session.Config.UserName
                Worker  = $Session.Config.WorkerName
                API_ID  = $Session.Config.API_ID
                API_Key = $Session.Config.API_Key
            }
        )
        $CheckPools = $true
    }

    if ($CheckPools) {
        foreach ($p in @($Session.Config.Pools.PSObject.Properties.Name)) {
            foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","FocusWallet")) {
                if ($Session.Config.Pools.$p.$q -is [string]) {$Session.Config.Pools.$p.$q = @(($Session.Config.Pools.$p.$q -split "[,;]" | Select-Object) | Where-Object {$_} | Foreach-Object {$_.Trim()})}
                if ($q -eq "FocusWallet" -and $Session.Config.Pools.$p.$q.Count) {
                    $Session.Config.Pools.$p.$q = @(Compare-Object $Session.Config.Pools.$p.$q $Session.Config.Pools.$p.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject -Unique)
                }
                $Session.Config.Pools.$p | Add-Member $q @(($Session.Config.Pools.$p.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
            }
            $Session.Config.Pools.$p | Add-Member Wallets (Get-PoolPayoutCurrencies $Session.Config.Pools.$p) -Force
            $Session.Config.Pools.$p | Add-Member DataWindow (Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow) -Force
            $Session.Config.Pools.$p | Add-Member Penalty ([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.]+")) -Force
        }
    }
    
    #Activate or deactivate donation  
    $DonateMinutes = if ($Session.Config.Donate -lt 10) {10} else {$Session.Config.Donate}
    $DonateDelayHours = 24
    if ($DonateMinutes -gt 15) {
        $DonateMinutes /= 2
        $DonateDelayHours /= 2
    }
    if (-not $Session.LastDonated) {$Session.LastDonated = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)}
    if ($Session.Timer.AddHours(-$DonateDelayHours) -ge $Session.LastDonated.AddSeconds(59)) {
        $Session.IsDonationRun = $false
        $Session.LastDonated = $Session.Timer
        $Session.Config = $Session.UserConfig | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
        $Session.UserConfig = $null
        $Session.AllPools = $null
        Write-Log "Donation run finished. "        
    }
    if ($Session.Timer.AddHours(-$DonateDelayHours).AddMinutes($DonateMinutes) -ge $Session.LastDonated -and $Session.AvailPools.Count -gt 0) {
        if (-not $Session.IsDonationRun -or $CheckConfig) {
            if (-not $DonationData) {$DonationData = '{"Wallets":{"Blockcruncher":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"Bsod":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"NiceHash":{"BTC":"3HFhYADZvybBstETYNEVMqVWMU9EJRfs4f","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"Ravenminer":{"RVN":"RGo5UgbnyNkfA8sUUbv62cYnV4EfYziNxH","Worker":"mpx","DataWindow":"average-2e","Penalty":0},"MiningPoolHub":{"Worker":"mpx","User":"rbm","API_ID":"422496","API_Key":"ef4f18b4f48d5964c5f426b90424d088c156ce0cd0aa0b9884893cabf6be350e","DataWindow":"average-2e","Penalty":0,"Algorithm":["lyra2z","skein","myriadgroestl","groestl","neoscrypt"]},"MiningPoolHubCoins":{"Worker":"mpx","User":"rbm","API_ID":"422496","API_Key":"ef4f18b4f48d5964c5f426b90424d088c156ce0cd0aa0b9884893cabf6be350e","DataWindow":"average-2e","Penalty":0,"Algorithm":["lyra2z","skein","myriadgroestl","groestl","neoscrypt"]},"ZergPool":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","User":"rbm","DataWindow":"estimate_current","Penalty":0},"Default":{"BTC":"3DxRETpBoXKrEBQxFb2HsPmG6apxHmKmUx","Worker":"mpx","User":"rbm","DataWindow":"average-2e","Penalty":0}},"Pools":["AHashPool","Nicehash","BlazePool","Ravenminer","ZergPool"],"Algorithm":["balloon","bitcore","c11","ethash","equihash24x5","equihash24x7","hmq1725","lyra2re2","lyra2z","neoscrypt","phi2","sonoa","tribus","x16r","x16s","x17"]}' | ConvertFrom-Json}
            if (-not $Session.IsDonationRun) {Write-Log "Donation run started for the next $(($Session.LastDonated-($Session.Timer.AddHours(-$DonateDelayHours))).Minutes +1) minutes. "}
            $Session.UserConfig = $Session.Config | ConvertTo-Json -Depth 10 -Compress | ConvertFrom-Json
            $Session.IsDonationRun = $true            
            $Session.AvailPools | ForEach-Object {
                $DonationData1 = if (Get-Member -InputObject ($DonationData.Wallets) -Name $_ -MemberType NoteProperty) {$DonationData.Wallets.$_} else {$DonationData.Wallets.Default};
                $Session.Config.Pools | Add-Member $_ $DonationData1 -Force
            }
            #$Session.ConfigFiles["Config"].LastWriteTime = 0
            $DonationPoolsAvail = Compare-Object @($DonationData.Pools) @($Session.AvailPools) -IncludeEqual -ExcludeDifferent | Select-Object -ExpandProperty InputObject
            $DonationAlgorithm = @($DonationData.Algorithm | ForEach-Object {Get-Algorithm $_} | Select-Object)
            if ($Session.UserConfig.Algorithm.Count -gt 0) {$Session.Config | Add-Member Algorithm @(@($Session.UserConfig.Algorithm | Select-Object) + @($DonationAlgorithm) | Sort-Object -Unique)  -Force}
            if ($Session.UserConfig.ExcludeAlgorithm.Count -gt 0) {$Session.Config | Add-Member ExcludeAlgorithm @(Compare-Object @($Session.UserConfig.ExcludeAlgorithm | Select-Object) @($DonationAlgorithm) | Where-Object SideIndicator -eq "<=" | Select-Object -ExpandProperty InputObject | Sort-Object -Unique) -Force}
            $Session.Config | Add-Member ExcludeCoin @() -Force
            $Session.Config | Add-Member ExcludeCoinSymbol @() -Force        
            if (-not $DonationPoolsAvail.Count) {
                $Session.Config | Add-Member ExcludePoolName @() -Force
            } else {
                $Session.Config | Add-Member PoolName $DonationPoolsAvail -Force
                $Session.Config | Add-Member ExcludePoolName @(Compare-Object @($Session.AvailPools) @($DonationPoolsAvail) | Select-Object -ExpandProperty InputObject) -Force
            }
            foreach ($p in @($Session.Config.Pools.PSObject.Properties.Name)) {
                foreach($q in @("Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","FocusWallet")) {
                    if ($Session.Config.Pools.$p.$q -is [string]) {$Session.Config.Pools.$p.$q = @(($Session.Config.Pools.$p.$q -split "[,;]" | Select-Object) | Where-Object {$_} | Foreach-Object {$_.Trim()})}
                    $Session.Config.Pools.$p | Add-Member $q @(($Session.Config.Pools.$p.$q | Select-Object) | Where-Object {$_} | Foreach-Object {if ($q -match "algorithm"){Get-Algorithm $_}else{$_}} | Select-Object -Unique | Sort-Object) -Force
                }
                $Session.Config.Pools.$p | Add-Member Wallets (Get-PoolPayoutCurrencies $Session.Config.Pools.$p) -Force
                $Session.Config.Pools.$p | Add-Member DataWindow (Get-YiiMPDataWindow $Session.Config.Pools.$p.DataWindow) -Force
                $Session.Config.Pools.$p | Add-Member Penalty ([double]($Session.Config.Pools.$p.Penalty -replace "[^\d\.]+")) -Force

            }
            $Session.Config | Add-Member DisableExtendInterval $true -Force
            $Session.AllPools = $null
        }
    } else {
        Write-Log ("Next donation run will start in {0:hh} hour(s) {0:mm} minute(s). " -f $($Session.LastDonated.AddHours($DonateDelayHours) - ($Session.Timer.AddMinutes($DonateMinutes))))
    }

    #Give API access to the current running configuration
    $API.Config = $Session.Config | ConvertTo-Json -Depth 10

    #Clear pool cache if the pool configuration has changed
    if ($Session.AllPools -ne $null -and (($ConfigBackup.Pools | ConvertTo-Json -Compress -Depth 10) -ne ($Session.Config.Pools | ConvertTo-Json -Compress -Depth 10) -or (Compare-Object @($ConfigBackup.PoolName) @($Session.Config.PoolName)) -or (Compare-Object @($ConfigBackup.ExcludePoolName) @($Session.Config.ExcludePoolName)))) {$Session.AllPools = $null}

    #load device(s) information and device combos
    if ($CheckConfig -or $ConfigBackup.MiningMode -ne $Session.Config.MiningMode -or (Compare-Object $Session.Config.DeviceName $ConfigBackup.DeviceName | Measure-Object).Count -gt 0) {
        Write-Log "Device configuration changed. Refreshing now. "

        #Load information about the devices
        $Session.Devices = @(Get-Device $Session.Config.DeviceName | Select-Object)
        $Session.DevicesByTypes = [PSCustomObject]@{
            NVIDIA = @($Session.Devices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "NVIDIA"} | Select-Object)
            AMD    = @($Session.Devices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "AMD"} | Select-Object)
            CPU    = @($Session.Devices | Where-Object Type -eq "CPU" | Select-Object)
            Combos = [PSCustomObject]@{}
            FullComboModels = [PSCustomObject]@{}
        }
        [hashtable]$Session.DevicesToVendors = @{}

        $Session.Config | Add-Member DeviceModel @($Session.Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object) -Force
        $Session.Config | Add-Member CUDAVersion $(if (($Session.DevicesByTypes.NVIDIA | Select-Object -First 1).OpenCL.Platform.Version -match "CUDA\s+([\d\.]+)") {$Matches[1]}else{$false})

        #Create combos
        @($Session.DevicesByTypes.PSObject.Properties.Name) | Where {@("Combos","FullComboModels") -inotcontains $_} | Foreach-Object {
            $SubsetType = [String]$_
            $Session.DevicesByTypes.Combos | Add-Member $SubsetType @() -Force
            $Session.DevicesByTypes.FullComboModels | Add-Member $SubsetType $(@($Session.DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique | Sort-Object) -join '-') -Force
            Get-DeviceSubSets @($Session.DevicesByTypes.$SubsetType) | Foreach-Object {                       
                $SubsetModel= $_
                $Session.DevicesByTypes.Combos.$SubsetType += @($Session.DevicesByTypes.$SubsetType | Where-Object {$SubsetModel.Model -icontains $_.Model} | Foreach-Object {$SubsetNew = $_.PSObject.Copy();$SubsetNew.Model = $($SubsetModel.Model -join '-');$SubsetNew.Model_Name = $($SubsetModel.Model_Name -join '+');$SubsetNew})
            }
            if ($Session.DevicesByTypes.$SubsetType) {
                @($Session.DevicesByTypes.$SubsetType | Select-Object -ExpandProperty Model -Unique) + @($Session.DevicesByTypes.Combos.$SubsetType | Select-Object -ExpandProperty Model) | Where-Object {$_} | Foreach-Object {$Session.DevicesToVendors[$_] = $SubsetType}
            }
        }

        if ($Session.Config.MiningMode -eq "legacy") {
            @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {
                $Device_LegacyModel = $_
                if ($Session.DevicesByTypes.FullComboModels.$Device_LegacyModel -match '-') {
                    $Session.DevicesByTypes.$Device_LegacyModel = $Session.DevicesByTypes.Combos.$Device_LegacyModel | Where-Object Model -eq $Session.DevicesByTypes.FullComboModels.$Device_LegacyModel
                }
            }
        } elseif ($Session.Config.MiningMode -eq "combo") {
            #add combos to DevicesbyTypes
            @("NVIDIA","AMD","CPU") | Foreach-Object {$Session.DevicesByTypes.$_ += $Session.DevicesByTypes.Combos.$_}     
        }

        #Give API access to the device information
        $API.DeviceCombos = @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name) | ForEach-Object {$Session.DevicesByTypes.$_ | Select-Object -ExpandProperty Model -Unique} | Sort-Object | ConvertTo-Json -Depth 10

        #Update device information for the first time
        Update-DeviceInformation @($Session.Devices.Name | Select-Object -Unique) -UseAfterburner (-not $Session.Config.DisableMSIAmonitor)
    }
    
    $API.Devices = $Session.Devices | ConvertTo-Json -Depth 10

    if (-not $Session.Devices) {
        Write-Log -Level Warn "No devices available. Please check your configuration. "
        Start-Sleep $Session.Config.Interval
        continue
    }

    #Check for miner config
    Set-MinersConfigDefault -PathToFile $Session.ConfigFiles["Miners"].Path
    if (Test-Path $Session.ConfigFiles["Miners"].Path) {
        if ($CheckConfig -or -not $Session.Config.Miners -or (Get-ChildItem $Session.ConfigFiles["Miners"].Path).LastWriteTime.ToUniversalTime() -gt $Session.ConfigFiles["Miners"].LastWriteTime) {        
            $Session.ConfigFiles["Miners"].LastWriteTime = (Get-ChildItem $Session.ConfigFiles["Miners"].Path).LastWriteTime.ToUniversalTime()
            $Session.Config | Add-Member Miners ([PSCustomObject]@{}) -Force
            $Session.ConfigFullComboModelNames = @($Session.DevicesByTypes.FullComboModels.PSObject.Properties.Name)
            foreach ($CcMiner in @((Get-ChildItemContent -Path $Session.ConfigFiles["Miners"].Path).Content.PSObject.Properties)) {
                $CcMinerName = $CcMiner.Name
                [String[]]$CcMinerName_Array = @($CcMinerName -split '-')
                if ($CcMinerName_Array.Count -gt 1 -and ($Session.ConfigFullComboModelNames -icontains $CcMinerName_Array[1]) -and ($Session.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")) {$CcMinerName = "$($CcMinerName_Array[0])-$($Session.DevicesByTypes.FullComboModels."$($CcMinerName_Array[1])")";$CcMinerName_Array = @($CcMinerName -split '-')}                
                $CcMinerOk = $true
                for($i=1;($i -lt $CcMinerName_Array.Count) -and $CcMinerOk;$i++) {if ($Session.Config.DeviceModel -inotcontains $CcMinerName_Array[$i]) {$CcMinerOk=$false}}
                if ($CcMinerOk) {
                    foreach($p in @($CcMiner.Value)) {
                        if ($(foreach($q in $p.PSObject.Properties.Name) {if ($q -ne "MainAlgorithm" -and $q -ne "SecondaryAlgorithm" -and ($p.$q -isnot [string] -or $p.$q.Trim() -ne "")) {$true;break}})) {
                            $CcMinerNameToAdd = $CcMinerName
                            if ($p.MainAlgorithm -ne '*') {
                                $CcMinerNameToAdd += "-$(Get-Algorithm $p.MainAlgorithm)"
                                if ($p.SecondaryAlgorithm) {$CcMinerNameToAdd += "-$(Get-Algorithm $p.SecondaryAlgorithm)"}
                            }
                            $Session.Config.Miners | Add-Member -Name $CcMinerNameToAdd -Value $p -MemberType NoteProperty -Force
                        }
                    }
                }
            }
        }
    }

    #Check for GPU failure and reboot, if needed
    if ($Session.Config.RebootOnGPUFailure) { 
        Write-Log "Testing for GPU failure. "
        Test-GPU
    }

    if ($Session.Config.Proxy) {$PSDefaultParameterValues["*:Proxy"] = $Session.Config.Proxy}
    else {$PSDefaultParameterValues.Remove("*:Proxy")}

    Get-ChildItem "APIs" -File | Foreach-Object {. $_.FullName}

    if ($UseTimeSync) {Test-TimeSync}
    $Session.Timer = (Get-Date).ToUniversalTime()

    $StatStart = $Session.StatEnd
    $Session.StatEnd = $Session.Timer.AddSeconds($Session.Config.Interval)
    $StatSpan = New-TimeSpan $StatStart $Session.StatEnd

    $DecayExponent = [int](($Session.Timer - $Session.DecayStart).TotalSeconds / $Session.DecayPeriod)

    $WatchdogInterval = ($WatchdogInterval / $Session.Strikes * ($Session.Strikes - 1)) + $StatSpan.TotalSeconds
    $WatchdogReset = ($WatchdogReset / ($Session.Strikes * $Session.Strikes * $Session.Strikes) * (($Session.Strikes * $Session.Strikes * $Session.Strikes) - 1)) + $StatSpan.TotalSeconds

    #Update the exchange rates    
    try {
        Write-Log "Updating exchange rates from Coinbase. "
        [hashtable]$NewRates = @{}
        Invoke-RestMethodAsync "https://api.coinbase.com/v2/exchange-rates?currency=BTC" | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates | Foreach-Object {$_.PSObject.Properties | Foreach-Object {$NewRates[$_.Name] = $_.Value}}
        if ($NewRates.Count) {
            $Session.Config.Currency | Where-Object {$NewRates.$_} | ForEach-Object {$Session.Rates[$_] = ([Double]$NewRates.$_)}
            $MissingCurrencies = @($Session.Config.Currency | Where-Object {-not $NewRates.ContainsKey($_)})
            if ($MissingCurrencies.Count -gt 0) {
                if ($MissingCurrenciesTicker = Get-Ticker -Symbol $MissingCurrencies) {
                    Write-Log "Updating missing currencies ($($MissingCurrencies -join ",")) "
                    $MissingCurrenciesTicker.PSObject.Properties.Name | Foreach-Object {$v = $MissingCurrenciesTicker.$_.BTC;if ($v){$v=1/[double]$v}else{$v=0};$NewRates.$_ = [string][math]::round($v,[math]::max(0,[math]::truncate(8-[math]::log($v,10))));$Session.Rates[$_] = [Double]$NewRates.$_}                
                }
            }
        } else {
            Write-Log -Level Warn "Coinbase is down. "
        }
    }
    catch {
        Write-Log -Level Warn "Coinbase is down. "
    }

    #PowerPrice check
    [Double]$PowerPriceBTC = 0
    if ($Session.Config.PowerPrice -gt 0) {
        if ($NewRates."$($Session.Config.PowerPriceCurrency)") {
            $PowerPriceBTC = [Double]$Session.Config.PowerPrice/[Double]$NewRates."$($Session.Config.PowerPriceCurrency)"
        } else {
            Write-Log -Level Warn "Powerprice currency $($Session.Config.PowerPriceCurreny) not found on Coinbase. Cost of electricity will be ignored."
        }
    }

    #Update the pool balances every 10 Minutes
    if ($Session.Config.ShowPoolBalances) {
        $RefreshBalances = (-not $Session.Updatetracker.Balances -or $Session.Updatetracker.Balances -lt $Session.Timer.AddMinutes(-10))
        if ($RefreshBalances) {
            Write-Log "Getting pool balances. "
            $Session.Updatetracker.Balances = $Session.Timer
        } else {
            Write-Log "Updating pool balances. "
        }
        $BalancesData = Get-Balance -Config $(if ($Session.IsDonationRun) {$Session.UserConfig} else {$Session.Config}) -NewRates $NewRates -Refresh $RefreshBalances -Details $Session.Config.ShowPoolBalancesDetails
        if (-not $BalancesData) {$Session.Updatetracker.Balances = 0}
        else {$API.Balances = $BalancesData.Balances | ConvertTo-Json -Depth 10}
    }

    #Give API access to the current rates
    $API.Rates = $Session.Rates | ConvertTo-Json -Depth 10

    #Load the stats
    Write-Log "Loading saved statistics. "

    [hashtable]$Session.Stats = Get-Stat

    #Give API access to the current stats
    $API.Stats = $Session.Stats | ConvertTo-Json -Depth 10

    #Load information about the pools
    Write-Log "Loading pool information. "

    $SelectedPoolNames = @()
    $NewPools = @()
    if (Test-Path "Pools") {
        $NewPools = $Session.AvailPools | WHere-Object {$Session.Config.Pools.$_ -and ($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_)} | Foreach-Object {
            $SelectedPoolNames += $_
            Get-PoolsContent "Pools\$($_).ps1" -Config $Session.Config.Pools.$_ -StatSpan $StatSpan -InfoOnly $false -IgnoreFees $Session.Config.IgnoreFees
        }
    }

    #Stop async jobs for no longer needed pools (will restart automatically, if pool pops in again)
    $Session.AvailPools | Where-Object {-not $Session.Config.Pools.$_ -or -not (($Session.Config.PoolName.Count -eq 0 -or $Session.Config.PoolName -icontains $_) -and ($Session.Config.ExcludePoolName.Count -eq 0 -or $Session.Config.ExcludePoolName -inotcontains $_))} | Foreach-Object {Stop-AsyncJob -tag $_}

    #Remove stats from pools & miners not longer in use
    if (-not $Session.IsDonationRun -and (Test-Path "Stats")) {
        if ($SelectedPoolNames -and $SelectedPoolNames.Count -gt 0) {Compare-Object @($SelectedPoolNames | Select-Object) @($Session.Stats.Keys | Where-Object {$_ -match '^(.+?)_.+Profit$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Pools\$($_.InputObject)_*_Profit.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
        if ($Session.AvailMiners -and $Session.AvailMiners.Count -gt 0) {Compare-Object @($Session.AvailMiners | Select-Object) @($Session.Stats.Keys | Where-Object {$_ -match '^(.+?)-.+Hashrate$'} | % {$Matches[1]} | Select-Object -Unique) | Where-Object SideIndicator -eq "=>" | Foreach-Object {Get-ChildItem "Stats\Miners\$($_.InputObject)-*_Hashrate.txt" -File | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item -Force}}
    }

    #Give API access to the current running configuration
    $API.NewPools = $NewPools | ConvertTo-Json -Depth 10

    #This finds any pools that were already in $Session.AllPools (from a previous loop) but not in $NewPools. Add them back to the list. Their API likely didn't return in time, but we don't want to cut them off just yet
    #since mining is probably still working.  Then it filters out any algorithms that aren't being used.
    $Session.AllPools = @($NewPools) + @(Compare-Object @($NewPools.Name | Select-Object -Unique) @($Session.AllPools.Name | Select-Object -Unique) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | ForEach-Object {$Session.AllPools | Where-Object Name -EQ $_}) | Where-Object {
        $Pool = $_
        $Pool_Name = $Pool.Name
        -not (
                (-not $Session.Config.Pools.$Pool_Name) -or
                ($Session.Config.Algorithm.Count -and -not (Compare-Object @($Session.Config.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.ExcludeAlgorithm.Count -and (Compare-Object @($Session.Config.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object)  -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or 
                ($Session.Config.PoolName.Count -and $Session.Config.PoolName -inotcontains $Pool_Name) -or
                ($Session.Config.ExcludePoolName.Count -and $Session.Config.ExcludePoolName -icontains $Pool_Name) -or
                ($Session.Config.ExcludeCoin.Count -and $Pool.CoinName -and @($Session.Config.ExcludeCoin) -icontains $Pool.CoinName) -or
                ($Session.Config.ExcludeCoinSymbol.Count -and $Pool.CoinSymbol -and @($Session.Config.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol) -or
                ($Session.Config.Pools.$Pool_Name.Algorithm.Count -and -not (Compare-Object @($Session.Config.Pools.$Pool_Name.Algorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm.Count -and (Compare-Object @($Session.Config.Pools.$Pool_Name.ExcludeAlgorithm | Select-Object) @($Pool.AlgorithmList | Select-Object) -IncludeEqual -ExcludeDifferent | Measure-Object).Count) -or
                ($Pool.CoinName -and $Session.Config.Pools.$Pool_Name.CoinName.Count -and @($Session.Config.Pools.$Pool_Name.CoinName) -inotcontains $Pool.CoinName) -or
                ($Pool.CoinName -and $Session.Config.Pools.$Pool_Name.ExcludeCoin.Count -and @($Session.Config.Pools.$Pool_Name.ExcludeCoin) -icontains $Pool.CoinName) -or
                ($Pool.CoinSymbol -and $Session.Config.Pools.$Pool_Name.CoinSymbol.Count -and @($Session.Config.Pools.$Pool_Name.CoinSymbol) -inotcontains $Pool.CoinSymbol) -or
                ($Pool.CoinSymbol -and $Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol.Count -and @($Session.Config.Pools.$Pool_Name.ExcludeCoinSymbol) -icontains $Pool.CoinSymbol)
            )}
    Remove-Variable "NewPools" -Force

    #Give API access to the current running configuration
    $API.AllPools = $Session.AllPools | ConvertTo-Json -Depth 10

    #Apply watchdog to pools
    $Session.AllPools = $Session.AllPools | Where-Object {
        $Pool = $_
        $Pool_WatchdogTimers = $Session.WatchdogTimers | Where-Object PoolName -EQ $Pool.Name | Where-Object Kicked -LT $Session.Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Session.Timer.AddSeconds( - $WatchdogReset)
        ($Pool_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>3 -and ($Pool_WatchdogTimers | Where-Object {$Pool.Algorithm -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#statge#>2
    }

    #Update the active pools
    if ($Session.AllPools.Count -eq 0) {
        Write-Log -Level Warn "No pools available. Press [X] to exit."
        $i = 0
        $keyPressedValue = $false
        do {
            if ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}
            else {Write-Host "." -NoNewline;Start-Sleep 2;$i+=2}
            if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
        } until ($keyPressedValue -or ($i -gt $Session.Config.Interval))

        Write-Host " "

        if ($keyPressedValue -eq "X") {
            Write-Log "User requests to stop script. "
            Write-Host "[X] pressed - stopping script."
            break
        }

        continue
    }

    $Pools = [PSCustomObject]@{}
    
    #Decrease compare prices, if out of sync window
    # \frac{\left(\frac{\ln\left(60-x\right)}{\ln\left(50\right)}+1\right)}{2}
    $OutOfSyncTimer = ($Session.AllPools | Select-Object -ExpandProperty Updated | Measure-Object -Maximum).Maximum
    $OutOfSyncTime = $OutOfSyncTimer.AddMinutes(-$Session.OutofsyncWindow)
    $OutOfSyncDivisor = [Math]::Log($Session.OutofsyncWindow-$Session.SyncWindow) #precalc for sync decay method
    $OutOfSyncLimit = 1/($Session.OutofsyncWindow-$Session.SyncWindow)

    Write-Log "Selecting best pool for each algorithm. "
    $Session.AllPools.Algorithm | ForEach-Object {$_.ToLower()} | Select-Object -Unique | ForEach-Object {$Pools | Add-Member $_ ($Session.AllPools | Where-Object Algorithm -EQ $_ | Sort-Object -Descending {$Session.Config.PoolName.Count -eq 0 -or (Compare-Object $Session.Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}, {$Session.Config.Pools."$($_.Name)".FocusWallet -and $Session.Config.Pools."$($_.Name)".FocusWallet -gt 0 -and $Session.Config.Pools."$($_.Name)".FocusWallet -icontains $_.Currency}, {$_.StablePrice * (1 - $_.MarginOfError) * ([Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1))}, {$_.Region -EQ $Session.Config.Region}, {$_.SSL -EQ $Session.Config.SSL} | Select-Object -First 1)}
    $Pools_OutOfSyncMinutes = ($Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Pools.$_.Name} | Select-Object -Unique | ForEach-Object {$Session.AllPools | Where-Object Name -EQ $_ | Where-Object Updated -ge $OutOfSyncTime | Measure-Object Updated -Maximum | Select-Object -ExpandProperty Maximum} | Measure-Object -Minimum -Maximum | ForEach-Object {$_.Maximum - $_.Minimum} | Select-Object -ExpandProperty TotalMinutes)
    if ($Pools_OutOfSyncMinutes -gt $Session.SyncWindow) {
        Write-Log -Level Verbose "Pool prices are out of sync ($([int]$Pools_OutOfSyncMinutes) minutes). "
    }
    $Pools | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
        $Pools.$_ | Add-Member Price_SyncDecay ([Math]::min(([Math]::Log([Math]::max($OutOfSyncLimit,$Session.OutofsyncWindow - ($OutOfSyncTimer - $Pools.$_.Updated).TotalMinutes))/$OutOfSyncDivisor + 1)/2,1)) -Force
        $Pool_Price = $Pools.$_.Price * $Pools.$_.Price_SyncDecay
        $Pools.$_ | Add-Member Price_Bias ($Pool_Price * (1 - ([Math]::Floor(($Pools.$_.MarginOfError * [Math]::Min($Session.Config.SwitchingPrevention,1) * [Math]::Pow($Session.DecayBase, $DecayExponent / ([Math]::Max($Session.Config.SwitchingPrevention,1)))) * 100.00) / 100.00))) -Force
        $Pools.$_ | Add-Member Price_Unbias $Pool_Price -Force
    }

    #Give API access to the pools information
    $API.Pools = $Pools | ConvertTo-Json -Depth 10
 
    #Load information about the miners
    Write-Log "Getting miner information. "
    # select only the ones that have a HashRate matching our algorithms, and that only include algorithms we have pools for
    # select only the miners that match $Session.Config.MinerName, if specified, and don't match $Session.Config.ExcludeMinerName    
    if ($Session.Config.EnableAutoMinerPorts) {Set-ActiveMinerPorts @($Session.ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | Select-Object);Set-ActiveTcpPorts} else {Set-ActiveTcpPorts -Disable}
    $AllMiners = if (Test-Path "Miners") {
        Get-MinersContent -Pools $Pools | 
            Where-Object {$_.DeviceName} | #filter miners for non-present hardware
            Where-Object {-not $Session.Config.DisableDualMining -or $_.HashRates.PSObject.Properties.Name.Count -eq 1} | #filter dual algo miners
            Where-Object {(Compare-Object @($Session.Devices.Name | Select-Object) @($_.DeviceName | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} | 
            Where-Object {(Compare-Object @($Pools.PSObject.Properties.Name | Select-Object) @($_.HashRates.PSObject.Properties.Name | Select-Object) | Where-Object SideIndicator -EQ "=>" | Measure-Object).Count -eq 0} |             
            Where-Object {$Session.Config.MinerName.Count -eq 0 -or (Compare-Object $Session.Config.MinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | 
            Where-Object {$Session.Config.ExcludeMinerName.Count -eq 0 -or (Compare-Object $Session.Config.ExcludeMinerName $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0} |
            Where-Object {
                $MinerOk = $true
                foreach ($p in @($_.DeviceModel -split '-')) {
                    if ($Session.Config.Devices.$p -and
                        (
                            ($Session.Config.Devices.$p.DisableDualMining -and $_.HashRates.PSObject.Properties.Name.Count -gt 1) -or
                            ($Session.Config.Devices.$p.Algorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.Algorithm $_.BaseAlgorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq 0) -or
                            ($Session.Config.Devices.$p.ExcludeAlgorithm.Count -gt 0 -and (Compare-Object $Session.Config.Devices.$p.ExcludeAlgorithm $_.BaseAlgorithm -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
                            ($Session.Config.Devices.$p.MinerName.Count -gt 0 -and ($Session.Config.Devices.$p.MinerName -inotcontains $_.Basename)) -or
                            ($Session.Config.Devices.$p.ExcludeMinerName.Count -gt 0 -and ($Session.Config.Devices.$p.ExcludeMinerName -icontains $_.Basename))
                        )
                    ) {$MinerOk=$false;break}
                }
                $MinerOk
            }
    }
    $Session.Stats = $null

    if ($Session.Config.MiningMode -eq "combo") {
        if (($AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -eq $null -and $_.DeviceModel -notmatch '-'} | Measure-Object).Count -gt 1) {
            #Benchmarking is still ongoing - remove device combos from miners
            $AllMiners = $AllMiners | Where-Object {$_.DeviceModel -notmatch '-'}
        } else {
            #Remove device combos, where the parameter-preset is different and there does not exist an own definition
            $AllMiners = $AllMiners | Where-Object {
                $_.DeviceModel -notmatch '-' -or 
                (Get-Member -InputObject $Session.Config.Miners -Name $(@($_.BaseName | Select-Object) + @($_.DeviceModel | Select-Object) + @($_.BaseAlgorithm | Select-Object) -join '-') -MemberType NoteProperty) -or 
                $($Miner = $_; (@($Miner.DeviceModel -split '-') | Foreach-Object {
                    $Miner_ConfigName = @($Miner.BaseName | Select-Object) + @($_ | Select-Object) + @($Miner.BaseAlgorithm | Select-Object) -join '-'
                    if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_ConfigName -MemberType NoteProperty){$Session.Config.Miners.$Miner_ConfigName.Params}
                } | Select-Object -Unique | Measure-Object).Count -le 1)
            }

            #Gather mining statistics for fresh combos
            $AllMiners | Where-Object {$_.HashRates.PSObject.Properties.Value -eq $null -and $_.DeviceModel -match '-'} | Foreach-Object {
                $Miner = $_
                $ComboAlgos = $Miner.HashRates.PSObject.Properties.Name
                $AllMiners | 
                    Where-Object {$_.BaseName -eq $Miner.BaseName -and $_.DeviceModel -notmatch '-' -and $($Miner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($Miner.DeviceModel -split '-') -icontains $_.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} |
                    Select-Object -ExpandProperty HashRates |
                    Measure-Object -Sum @($ComboAlgos) |
                    Foreach-Object {$Miner.HashRates."$($_.Property)" = $_.Sum * 1.001} 
                    #we exagerate a bit to prefer combos over single miners for startup. If the combo runs less good, later, it will fall back by itself

                $Miner.PowerDraw = ($AllMiners | 
                    Where-Object {$_.BaseName -eq $Miner.BaseName -and $_.DeviceModel -notmatch '-' -and $($Miner.Name -replace "-GPU.+$","") -eq $($_.Name -replace "-GPU.+$","") -and @($Miner.DeviceModel -split '-') -icontains $_.DeviceModel -and (Compare-Object @($ComboAlgos) @($_.HashRates.PSObject.Properties.Name) | Measure-Object).Count -eq 0} |
                    Select-Object -ExpandProperty PowerDraw |
                    Measure-Object -Sum).Sum 
            }
        }
    }
    
    Write-Log "Calculating profit for each miner. "

    [hashtable]$AllMiners_VersionCheck = @{}
    [System.Collections.ArrayList]$Miner_Arguments_List = @()
    $AllMiners | ForEach-Object {
        $Miner = $_

        $Miner_HashRates = [PSCustomObject]@{}
        $Miner_DevFees = [PSCustomObject]@{}
        $Miner_Pools = [PSCustomObject]@{}
        $Miner_Pools_Comparison = [PSCustomObject]@{}
        $Miner_Profits = [PSCustomObject]@{}
        $Miner_Profits_Comparison = [PSCustomObject]@{}
        $Miner_Profits_MarginOfError = [PSCustomObject]@{}
        $Miner_Profits_Bias = [PSCustomObject]@{}
        $Miner_Profits_Unbias = [PSCustomObject]@{}
        $Miner_OCprofile = [PSCustomObject]@{}

        foreach($p in @($Miner.DeviceModel -split '-')) {$Miner_OCprofile | Add-Member $p ""}

        if ($Session.Config.Miners) {
            $Miner_CommonCommands = $Miner_Arguments = ''
            $Miner_MSIAprofile = 0
            $Miner_Penalty = $Miner_ExtendInterval = $Miner_FaultTolerance = -1
            $Miner_CommonCommands_found = $false
            [System.Collections.ArrayList]$Miner_CommonCommands_array = @($Miner.BaseName,$Miner.DeviceModel)
            $Miner_CommonCommands_array.AddRange(@($Miner.BaseAlgorithm | Select-Object))
            for($i=$Miner_CommonCommands_array.Count;$i -gt 0; $i--) {
                $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                    if ($Session.Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Session.Config.Miners.$Miner_CommonCommands.Params}
                    if ($Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -eq 0) {$Miner_MSIAprofile = [int]$Session.Config.Miners.$Miner_CommonCommands.MSIAprofile}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and $Miner_Penalty -eq -1) {$Miner_Penalty = [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.ExtendInterval -and $Miner_ExtendInterval -eq -1) {$Miner_ExtendInterval = [int]$Session.Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Session.Config.Miners.$Miner_CommonCommands.FaultTolerance -and $Miner_FaultTolerance -eq -1) {$Miner_FaultTolerance = [double]$Session.Config.Miners.$Miner_CommonCommands.FaultTolerance}
                    if ($Session.Config.Miners.$Miner_CommonCommands.OCprofile -and $i -gt 1) {foreach ($p in @($Miner.DeviceModel -split '-')) {if (-not $Miner_OCprofile.$p) {$Miner_OCprofile.$p=$Session.Config.Miners.$Miner_CommonCommands.OCprofile}}}
                    $Miner_CommonCommands_found = $true
                }
            }
            if (-not $Miner_CommonCommands_found -and $Session.Config.MiningMode -eq "combo" -and $Miner.DeviceModel -match '-') {
                #combo handling - we know that combos always have equal params, because we preselected them, already
                foreach($p in @($Miner.DeviceModel -split '-')) {
                    $Miner_CommonCommands_array[1] = $p
                    $Miner_CommonCommands = $Miner_CommonCommands_array -join '-'
                    if ($Session.Config.Miners.$Miner_CommonCommands.Params -and $Miner_Arguments -eq '') {$Miner_Arguments = $Session.Config.Miners.$Miner_CommonCommands.Params}
                    if ($Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -and $Miner_MSIAprofile -ge 0 -and $Session.Config.Miners.$Miner_CommonCommands.MSIAprofile -ne $Miner_MSIAprofile) {$Miner_MSIAprofile = if (-not $Miner_MSIAprofile){[int]$Session.Config.Miners.$Miner_CommonCommands.MSIAprofile}else{-1}}
                    if ($Session.Config.Miners.$Miner_CommonCommands.Penalty -ne $null -and $Session.Config.Miners.$Miner_CommonCommands.Penalty -ne '' -and [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty -gt $Miner_Penalty) {$Miner_Penalty = [double]$Session.Config.Miners.$Miner_CommonCommands.Penalty}
                    if ($Session.Config.Miners.$Miner_CommonCommands.ExtendInterval -and [int]$Session.Config.Miners.$Miner_CommonCommands.ExtendInterval -gt $Miner_ExtendInterval) {$Miner_ExtendInterval = [int]$Session.Config.Miners.$Miner_CommonCommands.ExtendInterval}
                    if ($Session.Config.Miners.$Miner_CommonCommands.FaultTolerance -and [double]$Session.Config.Miners.$Miner_CommonCommands.FaultTolerance -gt $Miner_FaultTolerance) {$Miner_FaultTolerance = [double]$Session.Config.Miners.$Miner_CommonCommands.FaultTolerance}
                }
            }           

            #overclocking is different
            foreach($p in @($Miner.DeviceModel -split '-')) {
                if ($Miner_OCprofiles.$p -ne '') {continue}
                $Miner_CommonCommands_array[1] = $p
                for($i=$Miner_CommonCommands_array.Count;$i -gt 1; $i--) {
                    $Miner_CommonCommands = $Miner_CommonCommands_array.GetRange(0,$i) -join '-'
                    if (Get-Member -InputObject $Session.Config.Miners -Name $Miner_CommonCommands -MemberType NoteProperty) {
                        if ($Session.Config.Miners.$Miner_CommonCommands.OCprofile) {$Miner_OCprofile.$p=$Session.Config.Miners.$Miner_CommonCommands.OCprofile}
                    }
                }
            }           
            if ($Miner_Arguments -ne '' -and $Miner.Arguments -is [string]) {
                $Miner_Arguments_List.Clear()
                foreach ($p in @(" $Miner_Arguments" -split '\s+-')) {
                    if (-not $p) {continue}
                    $p="-$p"
                    if ($p -match "([\s=]+)") {
                        $pdiv = $matches[1].Trim()
                        if ($pdiv -eq ''){$pdiv=" "}
                        $q = $p -split "[\s=]+"
                        $Miner.Arguments = $Miner.Arguments -replace "$($q[0])[\s=]+[^\s=]+\s*"
                        $Miner_Arguments_List.Add($q -join $pdiv)>$null
                    } else {
                        $Miner_Arguments_List.Add($p)>$null
                    }
                }
                $Miner | Add-Member -Name Arguments -Value "$($Miner.Arguments.Trim()) $($Miner_Arguments_List -join ' ')" -MemberType NoteProperty -Force
                #$Miner | Add-Member -Name Arguments -Value (@($Miner.Arguments,$Miner_Arguments) -join ' ') -MemberType NoteProperty -Force
            }
            if ($Miner_MSIAprofile -ne 0) {$Miner | Add-Member -Name MSIAprofile -Value $($Miner_MSIAprofile) -MemberType NoteProperty -Force}           
            if ($Miner_Penalty -ne -1) {$Miner | Add-Member -Name Penalty -Value $($Miner_Penalty) -MemberType NoteProperty -Force}
            if ($Miner_ExtendInterval -ne -1) {$Miner | Add-Member -Name ExtendInterval -Value $($Miner_ExtendInterval) -MemberType NoteProperty -Force}
            if ($Miner_FaultTolerance -ne -1) {$Miner | Add-Member -Name FaultTolerance -Value $($Miner_FaultTolerance) -MemberType NoteProperty -Force}            
        }

        foreach($p in @($Miner.DeviceModel -split '-')) {if ($Miner_OCprofile.$p -eq '') {$Miner_OCprofile.$p=$Session.Config.Devices.$p.DefaultOCprofile}}

        $Miner.HashRates.PSObject.Properties.Name | ForEach-Object { #temp fix, must use 'PSObject.Properties' to preserve order
            $Miner_DevFees | Add-Member $_ ([Double]$(if (-not $Session.Config.IgnoreFees -and $Miner.DevFee) {[Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.DevFee.GetType().Name) {$Miner.DevFee.$_} else {$Miner.DevFee})} else {0})) -Force
            $Miner_DevFeeFactor = (1-$Miner_DevFees.$_/100)
            if ($Miner.Penalty) {$Miner_DevFeeFactor -= [Double]$(if (@("Hashtable","PSCustomObject") -icontains $Miner.Penalty.GetType().Name) {$Miner.Penalty.$_} else {$Miner.Penalty})/100;if ($Miner_DevFeeFactor -lt 0){$Miner_DevFeeFactor=0}}
            $Miner_HashRates | Add-Member $_ ([Double]$Miner.HashRates.$_)
            $Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools.$_)
            $Miner_Profits | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price * $Miner_DevFeeFactor)
            $Miner_Profits_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice * $Miner_DevFeeFactor)
            $Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Bias * $Miner_DevFeeFactor)
            $Miner_Profits_Unbias | Add-Member $_ ([Double]$Miner.HashRates.$_ * $Pools.$_.Price_Unbias * $Miner_DevFeeFactor)
        }

        $Miner_Profit = [Double]($Miner_Profits.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Comparison = [Double]($Miner_Profits_Comparison.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Bias = [Double]($Miner_Profits_Bias.PSObject.Properties.Value | Measure-Object -Sum).Sum
        $Miner_Profit_Unbias = [Double]($Miner_Profits_Unbias.PSObject.Properties.Value | Measure-Object -Sum).Sum
        
        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            $Miner_Profits_MarginOfError | Add-Member $_ ([Double]$Pools.$_.MarginOfError * (& {if ($Miner_Profit) {([Double]$Miner.HashRates.$_ * $Pools.$_.StablePrice) / $Miner_Profit}else {1}}))
        }

        $Miner_Profit_MarginOfError = [Double]($Miner_Profits_MarginOfError.PSObject.Properties.Value | Measure-Object -Sum).Sum

        $Miner_Profit_Cost = [Double]($Miner.PowerDraw*24/1000 * $PowerPriceBTC)

        $Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
            if (-not [String]$Miner.HashRates.$_) {
                $Miner_HashRates.$_ = $null
                $Miner_Profits.$_ = $null
                $Miner_Profits_Comparison.$_ = $null
                $Miner_Profits_Bias.$_ = $null
                $Miner_Profits_Unbias.$_ = $null
                $Miner_Profit = $null
                $Miner_Profit_Comparison = $null
                $Miner_Profits_MarginOfError = $null
                $Miner_Profit_Bias = $null
                $Miner_Profit_Unbias = $null
                $Miner_Profit_Cost = $null
            }
        }

        $Miner | Add-Member HashRates $Miner_HashRates -Force
        $Miner | Add-Member DevFee $Miner_DevFees -Force
        $Miner | Add-Member OCprofile $Miner_OCprofile -Force

        $Miner | Add-Member Pools $Miner_Pools
        $Miner | Add-Member Profits $Miner_Profits
        $Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
        $Miner | Add-Member Profits_Bias $Miner_Profits_Bias
        $Miner | Add-Member Profits_Unbias $Miner_Profits_Unbias
        $Miner | Add-Member Profit $Miner_Profit
        $Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
        $Miner | Add-Member Profit_MarginOfError $Miner_Profit_MarginOfError
        $Miner | Add-Member Profit_Bias $Miner_Profit_Bias
        $Miner | Add-Member Profit_Unbias $Miner_Profit_Unbias
        $Miner | Add-Member Profit_Cost $Miner_Profit_Cost

        if ($Session.Config.UsePowerPrice -and $Miner.Profit_Cost -ne $null -and $Miner.Profit_Cost -gt 0) {
            $Miner.Profit -= $Miner.Profit_Cost
            $Miner.Profit_Comparison -= $Miner.Profit_Cost
            $Miner.Profit_Bias -= $Miner.Profit_Cost
            $Miner.Profit_Unbias -= $Miner.Profit_Cost
        }

        $Miner | Add-Member DeviceName @($Miner.DeviceName | Select-Object -Unique | Sort-Object) -Force

        $Miner.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.Path)
        if ($Miner.PrerequisitePath) {$Miner.PrerequisitePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Miner.PrerequisitePath)}

        if (-not $AllMiners_VersionCheck.ContainsKey($Miner.BaseName)) {
            $Miner_UriJson = (Split-Path $Miner.Path) + "\_uri.json"
            $Miner_Uri = ""
            if ((Test-Path $Miner.Path) -and (Test-Path $Miner_UriJson)) {$Miner_Uri = Get-Content $Miner_UriJson -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore | Select-Object -ExpandProperty URI}
            $AllMiners_VersionCheck[$Miner.BaseName] = $Miner_Uri -eq $Miner.URI
        }
        $Miner | Add-Member VersionCheck $AllMiners_VersionCheck[$Miner.BaseName]
  
        if ($Miner.Arguments -is [string]) {$Miner.Arguments = ($Miner.Arguments -replace "\s+"," ").trim()}
        else {$Miner.Arguments = $Miner.Arguments | ConvertTo-Json -Depth 10 -Compress}
        
        
        if ($Miner.ExecName -eq $null) {$Miner | Add-Member ExecName ([IO.FileInfo]($Miner.Path | Split-Path -Leaf -ErrorAction Ignore)).BaseName -Force}
        if (-not $Miner.ExtendInterval) {$Miner | Add-Member ExtendInterval 0 -Force}
        if (-not $Miner.FaultTolerance) {$Miner | Add-Member FaultTolerance 0.1 -Force}
        if (-not $Miner.Penalty) {$Miner | Add-Member Penalty 0 -Force}
        if (-not $Miner.API) {$Miner | Add-Member API "Miner" -Force}
        if (-not $Miner.ManualUri -and $Miner.Uri -notmatch "RainbowMiner" -and $Miner.Uri -match "^(.+?github.com/.+?/releases)") {$Miner | Add-Member ManualUri $Matches[1] -Force}
    }
    Remove-Variable "Miner_Arguments_List" -Force

    $Miners_DownloadList = @()
    $Miners = $AllMiners | Where-Object {(Test-Path $_.Path) -and ((-not $_.PrerequisitePath) -or (Test-Path $_.PrerequisitePath)) -and $_.VersionCheck}
    if (($AllMiners.Count -ne $Miners.Count) -or $Session.StartDownloader) {
        $Miners_DownloadList = @($AllMiners | Where-Object {$_.PrerequisitePath} | Select-Object -Unique PrerequisiteURI,PrerequisitePath | Where-Object {-not (Test-Path $_.PrerequisitePath)} | Select-Object @{name = "URI"; expression = {$_.PrerequisiteURI}}, @{name = "Path"; expression = {$_.PrerequisitePath}}, @{name = "Searchable"; expression = {$false}}, @{name = "IsMiner"; expression = {$false}}) + @($AllMiners | Where-Object {$_.VersionCheck -ne $true} | Sort-Object {$_.ExtendInterval} -Descending | Select-Object -Unique @{name = "URI"; expression = {$_.URI}}, @{name = "Path"; expression = {$_.Path}}, @{name = "Searchable"; expression = {$true}}, @{name = "IsMiner"; expression = {$true}})        
        if ($Miners_DownloadList.Count -gt 0 -and $Downloader.State -ne "Running") {
            Clear-Host
            Write-Log "Starting download of $($Miners_DownloadList.Count) files."
            $Downloader = Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ($Miners_DownloadList) -FilePath .\Downloader.ps1
        }
        $Session.StartDownloader = $false
    }
    $Miners_Downloading = $Miners_DownloadList.Count
    Remove-Variable "AllMiners_VersionCheck" -Force
    Remove-Variable "Miners_DownloadList" -Force

    #Open firewall ports for all miners
    if (Get-Command "Get-MpPreference" -ErrorAction Ignore) {
        if ((Get-Command "Get-MpComputerStatus" -ErrorAction Ignore) -and (Get-MpComputerStatus -ErrorAction Ignore)) {
            if (Get-Command "Get-NetFirewallRule" -ErrorAction Ignore) {
                if ($MinerFirewalls -eq $null) {$MinerFirewalls = Get-NetFirewallApplicationFilter | Select-Object -ExpandProperty Program}
                if (@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ "=>") {
                    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) ("-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1'; ('$(@($AllMiners | Select-Object -ExpandProperty Path -Unique) | Compare-Object @($MinerFirewalls) | Where-Object SideIndicator -EQ '=>' | Select-Object -ExpandProperty InputObject | ConvertTo-Json -Compress)' | ConvertFrom-Json) | ForEach {New-NetFirewallRule -DisplayName 'RainbowMiner' -Program `$_}" -replace '"', '\"') -Verb runAs
                    Remove-Variable "MinerFirewalls" -Force
                }
            }
        }
    }
    Remove-Variable "AllMiners"

    #Remove miners with developer fee
    if ($Session.Config.ExcludeMinersWithFee) {$Miners = $Miners | Where-Object {($_.DevFee.PSObject.Properties.Value | Foreach-Object {[Double]$_} | Measure-Object -Sum).Sum -eq 0}}

    #Apply watchdog to miners
    $Miners = $Miners | Where-Object {
        $Miner = $_
        $Miner_WatchdogTimers = $Session.WatchdogTimers | Where-Object MinerName -EQ $Miner.Name | Where-Object Kicked -LT $Session.Timer.AddSeconds( - $WatchdogInterval) | Where-Object Kicked -GT $Session.Timer.AddSeconds( - $WatchdogReset)
        ($Miner_WatchdogTimers | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>2 -and ($Miner_WatchdogTimers | Where-Object {$Miner.HashRates.PSObject.Properties.Name -contains $_.Algorithm} | Measure-Object | Select-Object -ExpandProperty Count) -lt <#stage#>1
    }

    #Give API access to the miners information
    $API.Miners = $Miners | ConvertTo-Json -Depth 10

    #Use only use fastest miner per algo and device index. E.g. if there are 2 miners available to mine the same algo, only the faster of the two will ever be used, the slower ones will also be hidden in the summary screen
    if ($Session.Config.FastestMinerOnly) {$Miners = $Miners | Sort-Object -Descending {"$($_.DeviceName -join '')$($_.BaseAlgorithm -join '')$(if($_.HashRates.PSObject.Properties.Value -eq $null) {$_.Name})"}, {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {([Double]($_ | Measure-Object Profit_Bias -Sum).Sum)}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count} | Group-Object {"$($_.DeviceName -join '')$($_.BaseAlgorithm -join '')$(if($_.HashRates.PSObject.Properties.Value -eq $null) {$_.Name})"} | Foreach-Object {$_.Group[0]}}
 
    #Give API access to the fasted miners information
    $API.FastestMiners = $Miners | ConvertTo-Json -Depth 10

    #Update the active miners
    if ($Miners.Count -eq 0) {
        Write-Log -Level Warn "No miners available. Press [X] to exit."
        if ($Miners_Downloading -gt 0) {
            Write-Host " "
            Write-Host "Downloading first miners, mining operation will start in $($Session.Config.Interval) seconds. Command windows will popup and close during extraction. Please be patient!" -ForegroundColor Black -BackgroundColor Yellow
        }

        $i = 0
        $keyPressedValue = $false
        do {
            if ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}
            else {Write-Host "." -NoNewline;Start-Sleep 2;$i+=2}
            if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
        } until ($keyPressedValue -or ($i -gt $Session.Config.Interval))

        Write-Host " "
        if ($keyPressedValue -eq "X") {
            Write-Log "User requests to stop script. "
            Write-Host "[X] pressed - stopping script."
            break
        }

        continue
    }

    $Session.ActiveMiners | Foreach-Object {
        $_.Profit = 0
        $_.Profit_Comparison = 0
        $_.Profit_MarginOfError = 0
        $_.Profit_Bias = 0
        $_.Profit_Unbias = 0
        $_.Profit_Cost = 0
        $_.Best = $false
        $_.Best_Comparison = $false
        $_.Stopped = $false
    }
    $Miners | ForEach-Object {
        $Miner = $_
        $ActiveMiner = $Session.ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and
            $_.Path -eq $Miner.Path -and
            $_.Arguments -eq $Miner.Arguments -and
            $_.API -eq $Miner.API -and
            $_.Port -eq $Miner.Port -and
            (Compare-Object $_.Algorithm ($Miner.HashRates | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) | Measure-Object).Count -eq 0
        }
        
        if ($ActiveMiner) {
            $ActiveMiner.Profit = $Miner.Profit
            $ActiveMiner.Profit_Comparison = $Miner.Profit_Comparison
            $ActiveMiner.Profit_MarginOfError = $Miner.Profit_MarginOfError
            $ActiveMiner.Profit_Bias = $Miner.Profit_Bias
            $ActiveMiner.Profit_Unbias = $Miner.Profit_Unbias
            $ActiveMiner.Profit_Cost = $Miner.Profit_Cost
            $ActiveMiner.PowerDraw = $Miner.PowerDraw
            $ActiveMiner.Speed = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
            $ActiveMiner.DeviceName = $Miner.DeviceName
            $ActiveMiner.DeviceModel = $Miner.DeviceModel
            $ActiveMiner.ShowMinerWindow = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow)
            $ActiveMiner.DevFee = $Miner.DevFee
            $ActiveMiner.MSIAprofile = $Miner.MSIAprofile
            $ActiveMiner.OCprofile = $Miner.OCprofile
            $ActiveMiner.FaultTolerance = $Miner.FaultTolerance
            $ActiveMiner.Penalty = $Miner.Penalty
            $ActiveMiner.ManualUri = $Miner.ManualUri
            $ActiveMiner.EthPillEnable = $Session.Config.EthPillEnable
        }
        else {
            Write-Log "New miner object for $($Miner.BaseName)"
            $Session.ActiveMiners += New-Object $Miner.API -Property @{
                Name                 = $Miner.Name
                BaseName             = $Miner.BaseName
                Path                 = $Miner.Path
                Arguments            = $Miner.Arguments
                API                  = $Miner.API
                Port                 = $Miner.Port
                Algorithm            = $Miner.HashRates.PSObject.Properties.Name #temp fix, must use 'PSObject.Properties' to preserve order
                BaseAlgorithm        = $Miner.BaseAlgorithm
                Currency             = $Miner.Pools.PSObject.Properties.Value.Currency
                DeviceName           = $Miner.DeviceName
                DeviceModel          = $Miner.DeviceModel
                Profit               = $Miner.Profit
                Profit_Comparison    = $Miner.Profit_Comparison
                Profit_MarginOfError = $Miner.Profit_MarginOfError
                Profit_Bias          = $Miner.Profit_Bias
                Profit_Unbias        = $Miner.Profit_Unbias
                Profit_Cost          = $Miner.Profit_Cost
                PowerDraw            = $Miner.PowerDraw
                Speed                = $Miner.HashRates.PSObject.Properties.Value #temp fix, must use 'PSObject.Properties' to preserve order
                Speed_Live           = 0
                Best                 = $false
                Best_Comparison      = $false
                New                  = $false
                Benchmarked          = 0
                Pool                 = $Miner.Pools.PSObject.Properties.Value.Name
                MSIAprofile          = $Miner.MSIAprofile
                OCprofile            = $Miner.OCprofile
                ExtendInterval       = $Miner.ExtendInterval
                ShowMinerWindow      = ($Miner.ShowMinerWindow -or $Session.Config.ShowMinerWindow)
                DevFee               = $Miner.DevFee
                ExecName             = $Miner.ExecName
                FaultTolerance       = $Miner.FaultTolerance
                Penalty              = $Miner.Penalty
                ManualUri            = $Miner.ManualUri
                EthPillEnable        = $Session.Config.EthPillEnable
                DataInterval         = $Session.Config.Interval
                Donator              = $Session.IsDonationRun
            }
        }
    }

    $Session.ActiveMiners_DeviceNames = @($Session.ActiveMiners.DeviceName | Select-Object -Unique | Sort-Object)

    #Don't penalize active miners
    $Session.ActiveMiners | Where-Object {$Session.SkipSwitchingPrevention -or ($_.GetStatus() -eq [MinerStatus]::Running)} | Foreach-Object {$_.Profit_Bias = $_.Profit_Unbias}

    #Get most profitable miner combination i.e. AMD+NVIDIA+CPU
    $BestMiners = $Session.ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($Session.ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$Session.Config.Pools."$($_.Pool)".FocusWallet -and $Session.Config.Pools."$($_.Pool)".FocusWallet.Count -gt 0 -and (Compare-Object $Session.Config.Pools."$($_.Pool)".FocusWallet $_.Currency -IncludeEqual -ExcludeDifferent)}, {($_ | Measure-Object Profit_Bias -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}
    $BestMiners_Comparison = $Session.ActiveMiners | Select-Object DeviceName -Unique | ForEach-Object {$Miner_GPU = $_; ($Session.ActiveMiners | Where-Object {(Compare-Object $Miner_GPU.DeviceName $_.DeviceName | Measure-Object).Count -eq 0} | Sort-Object -Descending {($_ | Where-Object Profit -EQ $null | Measure-Object).Count}, {$Session.Config.Pools."$($_.Pool)".FocusWallet -and $Session.Config.Pools."$($_.Pool)".FocusWallet.Count -gt 0 -and (Compare-Object $Session.Config.Pools."$($_.Pool)".FocusWallet $_.Currency -IncludeEqual -ExcludeDifferent)} ,{($_ | Measure-Object Profit_Comparison -Sum).Sum}, {($_ | Where-Object Profit -NE 0 | Measure-Object).Count}, {$_.Benchmarked}, {if ($Session.Config.DisableExtendInterval){0}else{$_.ExtendInterval}} | Select-Object -First 1)}
    $Miners_Device_Combos = (Get-Combination ($Session.ActiveMiners | Select-Object DeviceName -Unique) | Where-Object {(Compare-Object ($_.Combination | Select-Object -ExpandProperty DeviceName -Unique) ($_.Combination | Select-Object -ExpandProperty DeviceName) | Measure-Object).Count -eq 0})
    $BestMiners_Combos = $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.DeviceName.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                $BestMiners | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }
    $BestMiners_Combos_Comparison = $Miners_Device_Combos | ForEach-Object {
        $Miner_Device_Combo = $_.Combination
        [PSCustomObject]@{
            Combination = $Miner_Device_Combo | ForEach-Object {
                $Miner_Device_Count = $_.DeviceName.Count
                [Regex]$Miner_Device_Regex = "^(" + (($_.DeviceName | ForEach-Object {[Regex]::Escape($_)}) -join '|') + ")$"
                $BestMiners_Comparison | Where-Object {([Array]$_.DeviceName -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.DeviceName -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}
            }
        }
    }
    $BestMiners_Combo = $BestMiners_Combos | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Bias -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination
    $BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort-Object -Descending {($_.Combination | Where-Object Profit -EQ $null | Measure-Object).Count}, {($_.Combination | Measure-Object Profit_Comparison -Sum).Sum}, {($_.Combination | Where-Object Profit -NE 0 | Measure-Object).Count} | Select-Object -First 1 | Select-Object -ExpandProperty Combination

    #apply PowerOffset and check for remaining profitability
    $Session.Profitable = $true
    $PowerOffset_Cost = [Double]0
    if ($Session.Config.UsePowerPrice -and ($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null} | Measure-Object).Count -eq 0) {
        $PowerOffset_Cost = [Double]($Session.Config.PowerOffset*24/1000 * $PowerPriceBTC)
        if ((($BestMiners_Combo.Profit | Measure-Object -Sum).Sum - $PowerOffset_Cost) -le 0) {
            Write-Log -Level Warn "No more miners are profitable. $(if ($Session.Config.CheckProfitability) {" Waiting for profitability."})"
            if ($Session.Config.CheckProfitability) {$Session.Profitable = $false}
        }
    }

    if (-not $Session.PauseMiners -and -not $Session.AutoUpdate -and $Session.Profitable) {
        $BestMiners_Combo | ForEach-Object {$_.Best = $true}
        $BestMiners_Combo_Comparison | ForEach-Object {$_.Best_Comparison = $true}
    }

    #Stop or start miners in the active list depending on if they are the most profitable
    $Session.ActiveMiners | Where-Object {(($_.Best -EQ $false) -or $Session.RestartMiners) -and $_.GetActivateCount() -GT 0 -and $_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {
        $Miner = $_
        Write-Log "Stopping miner ($($Miner.Name)). "
        $Miner.SetStatus([MinerStatus]::Idle)

        #Remove watchdog timer
        $Miner_Name = $Miner.Name
        $Miner.Algorithm | ForEach-Object {
            $Miner_Algorithm = $_
            $WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
            if ($WatchdogTimer) {
                if (($WatchdogTimer.Kicked -lt $Session.Timer.AddSeconds( - $WatchdogInterval)) -and -not $Session.RestartMiners) {
                    $Miner.SetStatus([MinerStatus]::Failed)
                }
                else {
                    $Session.WatchdogTimers = $Session.WatchdogTimers -notmatch $WatchdogTimer
                }
            }
        }
        $Miner.Stopped = $true
    }

    if (($Session.ActiveMiners | ForEach-Object {$_.GetProcessNames()} | Measure-Object).Count -gt 0) {
        $Running = @($Session.ActiveMiners | Where-Object Best -EQ $true | Foreach-Object {if ($_.GetStatus() -eq [MinerStatus]::Running -and $_.GetProcessId() -gt 0) {$_.GetProcessId()}})
        Get-Process | Where-Object {@($Session.ActiveMiners | Foreach-Object {$_.GetExecNames()}) -contains $_.ProcessName} | Select-Object -ExpandProperty ProcessName | Compare-Object @($Session.ActiveMiners | Where-Object Best -EQ $true | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | ForEach-Object {$_.GetExecNames()}) | Where-Object SideIndicator -EQ "=>" | Select-Object -ExpandProperty InputObject | Select-Object -Unique | ForEach-Object {Get-Process -Name $_ -ErrorAction Ignore | Where-Object {$Running -notcontains $_.Id} | ForEach-Object {Write-Warning "Stop-Process $($_.ProcessName) with Id $($_.Id)"; Stop-Process -Id $_.Id -Force -ErrorAction Ignore}}
    }
    if ($Downloader.HasMoreData) {$Downloader | Receive-Job}
    if ($Session.Config.Delay -gt 0) {Start-Sleep $Session.Config.Delay} #Wait to prevent BSOD

    $Session.ActiveMiners | Where-Object {$_.Best -EQ $true -and $_.GetStatus() -ne [MinerStatus]::Running} | ForEach-Object {

        #Set MSI Afterburner profile
        if ($MSIAenabled) {
            $MSIAplannedprofile = $Session.ActiveMiners | Where-Object {$_.Best -eq $true -and $_.MSIAprofile -ne $null -and $_.MSIAprofile -gt 0} | Select-Object -ExpandProperty MSIAprofile -Unique
            if (-not $MSIAplannedprofile.Count) {$MSIAplannedprofile = $Session.Config.MSIAprofile}                
            else {$MSIAplannedprofile = $MSIAplannedprofile | Select-Object -Index 0}
            Start-Process -FilePath "$($Session.Config.MSIApath)" -ArgumentList "-Profile$($MSIAplannedprofile)" -Verb RunAs
            if ($MSIAplannedprofile -ne $Session.MSIAcurrentprofile) {
                Write-Log "New MSI Afterburner profile set: $($MSIAplannedprofile)"                
                $Session.MSIAcurrentprofile = $MSIAplannedprofile
                Start-Sleep 1
            }
        } elseif ($Session.Config.EnableOCprofiles) {
            Start-Sleep -Milliseconds 500
            $_.SetOCprofile($Session.Config)
            Start-Sleep -Milliseconds 500
        }
        if ($_.Speed -contains $null) {
            Write-Log "Benchmarking miner ($($_.Name)): '$($_.Path) $($_.Arguments)' (Extend Interval $($_.ExtendInterval))"
        }
        else {
            Write-Log "Starting miner ($($_.Name)): '$($_.Path) $($_.Arguments)'"
        }            
        $Session.DecayStart = $Session.Timer
        $_.SetStatus([MinerStatus]::Running)

        #Add watchdog timer
        if ($Session.Config.Watchdog -and $_.Profit -ne $null) {
            $Miner_Name = $_.Name
            $Miner_DeviceModel = $_.DeviceModel
            $_.Algorithm | ForEach-Object {
                $Miner_Algorithm = $_
                $WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if (-not $WatchdogTimer) {
                    $Session.WatchdogTimers += [PSCustomObject]@{
                        MinerName = $Miner_Name
                        DeviceModel= $Miner_DeviceModel
                        PoolName  = $Pools.$Miner_Algorithm.Name
                        Algorithm = $Miner_Algorithm
                        Kicked    = $Session.Timer
                    }
                }
                elseif (-not ($WatchdogTimer.Kicked -GT $Session.Timer.AddSeconds( - $WatchdogReset))) {
                    $WatchdogTimer.Kicked = $Session.Timer
                }
            }
        }
    }

    #Get count of miners, that need to be benchmarked. If greater than 0, the UIstyle "full" will be used    
    $MinersNeedingBenchmark = @($Miners | Where-Object {$_.HashRates.PSObject.Properties.Value -contains $null})
    $API.MinersNeedingBenchmark = $MinersNeedingBenchmark | ConvertTo-Json -Depth 10

    #Move donation run into the future, if benchmarks are ongoing
    if (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0) {$Session.LastDonated = $Session.Timer.AddHours(1 - $DonateDelayHours).AddMinutes($DonateMinutes)}

    #Give API access to WatchdogTimers information
    $API.WatchdogTimers = $Session.WatchdogTimers | ConvertTo-Json -Depth 10

    #Update API miner information
    #$RunningMiners = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {$_ | Add-Member ActiveTime $_.GetActiveTime() -Force -PassThru}
    $API.ActiveMiners  = $Session.ActiveMiners | Foreach-Object {Get-FilteredMinerObject $_} | ConvertTo-Json -Depth 2
    $API.RunningMiners = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Foreach-Object {Get-FilteredMinerObject $_} | ConvertTo-Json -Depth 2
    $API.FailedMiners  = $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Failed}  | Foreach-Object {Get-FilteredMinerObject $_} | ConvertTo-Json -Depth 2
    $API.Asyncloaderjobs = $Asyncloader.Jobs | ConvertTo-Json -Depth 10

    #
    #Start output to host
    #
    Clear-Host

    $LimitMiners = if ($Session.Config.UIstyle -eq "full" -or (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0)) {100} else {3}

    #Display mining information
    $Miners | Select-Object DeviceName, DeviceModel -Unique | Sort-Object DeviceModel | ForEach-Object {
        $Miner_DeviceName = $_.DeviceName
        $Miner_DeviceModel = $_.DeviceModel
        $Miner_DeviceTitle = @($Session.Devices | Where-Object {$Miner_DeviceName -icontains $_.Name} | Select-Object -ExpandProperty Model_Name -Unique | Sort-Object | Foreach-Object {"$($_) ($(@($Session.Devices | Where-Object Model_Name -eq $_ | Select-Object -ExpandProperty Name | Sort-Object) -join ','))"}) -join ', '
        Write-Host $Miner_DeviceTitle
        Write-Host $("=" * $Miner_DeviceTitle.Length)

        [System.Collections.ArrayList]$Miner_Table = @(
            @{Label = "Miner"; Expression = {$_.Name -replace '\-.*$'}},
            @{Label = "Fee"; Expression = {($_.DevFee.PSObject.Properties.Value | ForEach-Object {if ($_) {'{0:p2}' -f ($_/100) -replace ",*0+\s%"," %"}else {"-"}}) -join ','}; Align = 'right'},
            @{Label = "Algorithm"; Expression = {$_.HashRates.PSObject.Properties.Name}},
            @{Label = "Speed"; Expression = {$_.HashRates.PSObject.Properties.Value | ForEach-Object {if ($_ -ne $null) {"$($_ | ConvertTo-Hash)/s"}else {"Benchmarking"}}}; Align = 'right'},
            @{Label = "Power$(if ($Session.Config.UsePowerPrice -and $Session.Config.PowerOffset -gt 0){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}; Align = 'right'}
        )
        foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Table.Add(@{Label = "$Miner_Currency/Day $($_.Profit)"; Expression = [scriptblock]::Create("if (`$_.Profit) {ConvertTo-LocalCurrency `$(`$_.Profit) $($Session.Rates.$Miner_Currency) -Offset 2} else {`"Unknown`"}"); Align = "right"}) > $null
        }                        
        $Miner_Table.AddRange(@(
            @{Label = "Accuracy"; Expression = {$_.Pools.PSObject.Properties.Value.MarginOfError | ForEach-Object {(1 - $_).ToString("P0")}}; Align = 'right'}, 
            @{Label = "Pool"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {"$($_.Name)$(if ($_.CoinName) {"-$($_.CoinName)"})"}}}
            @{Label = "PoolFee"; Expression = {$_.Pools.PSObject.Properties.Value | ForEach-Object {if ($_.PoolFee) {'{0:p2}' -f ($_.PoolFee/100) -replace ",*0+\s%"," %"}else {"-"}}}; Align = 'right'}
        )) > $null

        $Miners | Where-Object {$_.DeviceModel -eq $Miner_DeviceModel} | Where-Object {$_.Profit -ge 1E-6 -or $_.Profit -eq $null} | Sort-Object DeviceModel, @{Expression = {if (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0) {$_.HashRates.PSObject.Properties.Name}}}, @{Expression = {if (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0) {$_.Profit}}; Descending = $true}, @{Expression = {if ($Session.IsDonationRun -or $MinersNeedingBenchmark.Count -lt 1) {[double]$_.Profit_Bias}}; Descending = $true} | Select-Object -First $($LimitMiners) | Format-Table $Miner_Table | Out-Host        
    }
    Remove-Variable "Miner_Table"

    if ($Session.RestartMiners) {
        Write-Host "Miners have been restarted!" -ForegroundColor Yellow
        Write-Host " "
        $Session.RestartMiners = $false
    }
    if ($Session.PauseMiners) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "PAUSED" -ForegroundColor Red
        Write-Host " (press P to resume)"
        Write-Host " "
    } elseif (-not $Session.Profitable) {
        Write-Host -NoNewline "Status: "
        Write-Host -NoNewLine "WAITING FOR PROFITABILITY" -ForegroundColor Red
        Write-Host " (be patient or set CheckProfitability to 0 to resume)"
        Write-Host " "
    } else {
        if ((-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0) -or $Miners_Downloading -gt 0) {Write-Host " "}
        #Display benchmarking progres
        if (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0) {
            Write-Log -Level Warn "Benchmarking in progress: $($MinersNeedingBenchmark.Count) miner$(if ($MinersNeedingBenchmark.Count -gt 1){'s'}) left."
            $MinersNeedingBenchmarkWithEI = ($MinersNeedingBenchmark | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Measure-Object).Count
            if (-not $Session.Config.DisableExtendInterval -and $MinersNeedingBenchmarkWithEI -gt 0) {
                Write-Host " "
                Write-Host "Please be patient!" -BackgroundColor Yellow -ForegroundColor Black
                Write-Host "RainbowMiner will benchmark the following $($MinersNeedingBenchmarkWithEI) miner$(if ($MinersNeedingBenchmarkWithEI -gt 1){'s'}) with extended intervals!" -ForegroundColor Yellow
                Write-Host "These algorithm need a longer time to reach an accurate average hashrate." -ForegroundColor Yellow
                Write-Host "After that, benchmarking will be much faster (1-2 minutes per miner)." -ForegroundColor Yellow
                Write-Host "If you do not want that accuracy, set DisableExtendInterval to 0 in your config.txt" -ForegroundColor Yellow
                $OldForegroundColor = [console]::ForegroundColor
                [console]::ForegroundColor = "Yellow"
                $MinersNeedingBenchmark | Select-Object BaseName,BaseAlgorithm,ExtendInterval | Where-Object {$_.ExtendInterval -gt 1 -and $_.ExtendInterval -ne $null} | Sort-Object -Property @{Expression = {$_.ExtendInterval}; Descending = $True},@{Expression = {$_.BaseName + $_.BaseAlgorithm -join '-'}; Descending = $False} | Format-Table (
                    @{Label = "Miner"; Expression = {$_.BaseName}},
                    @{Label = "Algorithms"; Expression = {$_.BaseAlgorithm -join '-'}},
                    @{Label = "Aprox. Time"; Expression = {"$($_.ExtendInterval)-$($_.ExtendInterval*2) minutes"}}
                )
                [console]::ForegroundColor = $OldForegroundColor
            }
        }
        if ($Miners_Downloading -gt 0) {
            Write-Log -Level Warn "Download in progress: $($Miners_Downloading) miner$(if($Miners_Downloading -gt 1){"s"}) left. Command windows will popup during extraction."
        }
    }

    #Extend benchmarking interval to the maximum from running miners
    $WatchdogResetOld = $WatchdogReset
    $ExtendInterval = if ($Session.Config.DisableExtendInterval) {1} else {(@(1) + [int[]]@($Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Where-Object {$_.Speed -eq $null} | Select-Object -ExpandProperty ExtendInterval) | Measure-Object -Maximum).Maximum}
    if ($ExtendInterval -gt 1) {
        $Session.StatEnd = $Session.StatEnd.AddSeconds($Session.Config.Interval * $ExtendInterval)
        $StatSpan = New-TimeSpan $StatStart $Session.StatEnd
        $WatchdogInterval = ($WatchdogInterval / $Session.Strikes * ($Session.Strikes - 1)) + $StatSpan.TotalSeconds
        $WatchdogReset = ($WatchdogReset / ($Session.Strikes * $Session.Strikes * $Session.Strikes) * (($Session.Strikes * $Session.Strikes * $Session.Strikes) - 1)) + $StatSpan.TotalSeconds
        Write-Log -Level Warn "Benchmarking watchdog sensitive algorithm or miner. Increasing interval time temporarily to $($ExtendInterval)x interval ($($Session.Config.Interval * $ExtendInterval) seconds). "
    }

    #Display active miners list
    $Session.ActiveMiners | Where-Object {$_.GetActivateCount() -GT 0 -and ($Session.Config.UIstyle -eq "full" -or (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0) -or $_.GetStatus() -eq [MinerStatus]::Running)} | Sort-Object -Property @{Expression = {$_.GetStatus()}; Descending = $False}, @{Expression = {$_.GetActiveLast()}; Descending = $True} | Select-Object -First (1 + 6 + 6) | Format-Table -GroupBy @{Label = "Status"; Expression = {$_.GetStatus()}} -Wrap (
        @{Label = "Last Speed"; Expression = {$_.Speed_Live | ForEach-Object {"$($_ | ConvertTo-Hash)/s"}}; Align = 'right'}, 
        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.GetActiveTime()}}, 
        @{Label = "Launched"; Expression = {Switch ($_.GetActivateCount()) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}},      
        @{Label = "Miner"; Expression = {"$($_.Name -replace '\-.*$')$(if ($Session.Config.Pools."$($_.Pool)".FocusWallet -and $Session.Config.Pools."$($_.Pool)".FocusWallet.Count -gt 0 -and (Compare-Object $Session.Config.Pools."$($_.Pool)".FocusWallet $_.Currency -IncludeEqual -ExcludeDifferent)) {"(!)"})"}},
        @{Label = "Device"; Expression = {@(Get-DeviceModelName $Session.Devices -Name @($_.DeviceName) -Short) -join ','}},
        @{Label = "Power$(if ($Session.Config.UsePowerPrice -and $Session.Config.PowerOffset -gt 0){"*"})"; Expression = {"{0:d}W" -f [int]$_.PowerDraw}},
        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
    ) | Out-Host

    if ($Session.Config.UIstyle -eq "full" -or (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0)) {
        #Display watchdog timers
        $Session.WatchdogTimers | Where-Object Kicked -gt $Session.Timer.AddSeconds( - $WatchdogResetOld) | Format-Table -Wrap (
            @{Label = "Miner"; Expression = {$_.MinerName -replace '\-.*$'}},
            @{Label = "Device"; Expression = {@(Get-DeviceModelName $Session.Devices -Name @($_.DeviceName) -Short) -join ','}}, 
            @{Label = "Pool"; Expression = {$_.PoolName}}, 
            @{Label = "Algorithm"; Expression = {$_.Algorithm}}, 
            @{Label = "Watchdog Timer"; Expression = {"{0:n0} Seconds" -f ($Session.Timer - $_.Kicked | Select-Object -ExpandProperty TotalSeconds)}; Align = 'right'}
        ) | Out-Host
    }

    if ($Session.Config.UsePowerPrice -and $Session.Config.PowerOffset -gt 0) {Write-Host "* net power consumption. A base power offset of $("{0:d}" -f [int]$Session.Config.PowerOffset)W is being added to calculate the final profit."; Write-Host " "}

    #Display profit comparison    
    if (($BestMiners_Combo | Where-Object Profit -EQ $null | Measure-Object).Count -eq 0 -and $Downloader.State -ne "Running") {
        $MinerComparisons = 
        [PSCustomObject]@{"Miner" = "RainbowMiner"}, 
        [PSCustomObject]@{"Miner" = $BestMiners_Combo_Comparison | ForEach-Object {"$($_.Name -replace '\-.*$')-$($_.Algorithm -join '/')"}}

        $BestMiners_Combo_Stat = Set-Stat -Name "Profit" -Value ($BestMiners_Combo | Measure-Object Profit -Sum).Sum -Duration $StatSpan

        $MinerComparisons_Profit = $BestMiners_Combo_Stat.Week, ($BestMiners_Combo_Comparison | Measure-Object Profit_Comparison -Sum).Sum
        $MinerComparisons_MarginOfError = $BestMiners_Combo_Stat.Week_Fluctuation, ($BestMiners_Combo_Comparison | ForEach-Object {$_.Profit_MarginOfError * (& {if ($MinerComparisons_Profit[1]) {$_.Profit_Comparison / $MinerComparisons_Profit[1]}else {1}})} | Measure-Object -Sum).Sum

        if ($Session.Config.UsePowerPrice) {
            $MinerComparisons_Profit[0] -= $PowerOffset_Cost
            $MinerComparisons_Profit[1] -= $PowerOffset_Cost
        }
        
        $Session.Config.Currency | ForEach-Object {
            $MinerComparisons[0] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[0] * $Session.Rates.$_), $MinerComparisons_MarginOfError[0], (($MinerComparisons_Profit[0] * $Session.Rates.$_) / (1 + $MinerComparisons_MarginOfError[0])), (($MinerComparisons_Profit[0] * $Session.Rates.$_) * (1 + $MinerComparisons_MarginOfError[0])))
            $MinerComparisons[1] | Add-Member $_.ToUpper() ("{0:N5} $([Char]0x00B1){1:P0} ({2:N5}-{3:N5})" -f ($MinerComparisons_Profit[1] * $Session.Rates.$_), $MinerComparisons_MarginOfError[1], (($MinerComparisons_Profit[1] * $Session.Rates.$_) / (1 + $MinerComparisons_MarginOfError[1])), (($MinerComparisons_Profit[1] * $Session.Rates.$_) * (1 + $MinerComparisons_MarginOfError[1])))
        }

        if ($Session.Config.UIstyle -eq "full" -or (-not $Session.IsDonationRun -and $MinersNeedingBenchmark.Count -gt 0)) {
            if ($MinerComparisons_Profit[1] -ne 0 -and [Math]::Round(($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1], 2) -gt 0) {
                $MinerComparisons_Range = ($MinerComparisons_MarginOfError | Measure-Object -Average | Select-Object -ExpandProperty Average), (($MinerComparisons_Profit[0] - $MinerComparisons_Profit[1]) / $MinerComparisons_Profit[1]) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
                Write-Host -BackgroundColor Yellow -ForegroundColor Black "RainbowMiner is between $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])-$MinerComparisons_Range)*100)))% and $([Math]::Round((((($MinerComparisons_Profit[0]-$MinerComparisons_Profit[1])/$MinerComparisons_Profit[1])+$MinerComparisons_Range)*100)))% more profitable than the fastest miner: "
            }

            $MinerComparisons | Out-Host
        }
    }

    #Display pool balances, formatting it to show all the user specified currencies
    if ($Session.Config.ShowPoolBalances -and $BalancesData -and $BalancesData.Balances.Count -gt 1) {
        $NextBalances = 10-[int]((Get-Date).ToUniversalTime()-$Session.Updatetracker.Balances).TotalMinutes
        $NextBalances = if ($NextBalances -gt 0){"in $($NextBalances) minutes"}else{"now"}
        Write-Host "Pool Balances as of $([System.Timezone]::CurrentTimeZone.ToLocalTime($Session.Updatetracker.Balances)) (next update $($NextBalances)): "        
        $Columns = @()
        $ColumnFormat = [Array]@{Name = "Name"; Expression = "Name"}
        if (($BalancesData.Balances.Currency | Select-Object -Unique | Measure-Object).Count -gt 1) {
            $ColumnFormat += @{Name = "Sym"; Expression = {$_.Currency}}
            $ColumnFormat += @{Name = "Balance"; Expression = {$_."Balance ($($_.Currency))"}}            
        }
        $Columns += $BalancesData.Balances | Foreach-Object {$_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name} | Where-Object {$_ -like "Value in *"} | Sort-Object -Unique
        $ColumnFormat += $Columns | Foreach-Object {@{Name = "$($_ -replace "Value in\s+")"; Expression = "$_"; Align = "right"}}
        $BalancesData.Balances | Format-Table -Wrap -Property $ColumnFormat
        Remove-Variable "Columns" -Force
        Remove-Variable "ColumnFormat" -Force
        Remove-Variable "BalancesData" -Force
    }

    #Display exchange rates
    $CurrentProfitTotal = $CurrentProfitWithoutCostTotal = $($Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty Profit | Measure-Object -Sum).Sum
    if ($Session.Config.UsePowerPrice) {$CurrentProfitTotal -= $PowerOffset_Cost;$CurrentProfitWithoutCostTotal += $($Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [MinerStatus]::Running} | Select-Object -ExpandProperty Profit_Cost | Measure-Object -Sum).Sum}
    [System.Collections.ArrayList]$StatusLine = @()
    foreach($Miner_Currency in @($Session.Config.Currency | Sort-Object)) {
            $Miner_Currency_Out = $Miner_Currency
            $CurrentProfitTotal_Out = $CurrentProfitTotal
            $CurrentProfitWithoutCostTotal_Out = $CurrentProfitWithoutCostTotal
            $CurrentProfit_Offset = 2
            if ($Miner_Currency -eq "BTC" -and $CurrentProfitWithoutCostTotal -ne 0) {
                switch ([math]::truncate([math]::log([math]::Abs($CurrentProfitWithoutCostTotal), 1000))) {
                    -1 {$Miner_Currency_Out = "mBTC";$CurrentProfitTotal_Out*=1e3;$CurrentProfitWithoutCostTotal_Out*=1e3}
                    -2 {$Miner_Currency_Out = "µBTC";$CurrentProfitTotal_Out*=1e6;$CurrentProfitWithoutCostTotal_Out*=1e6}
                    -3 {$Miner_Currency_Out = "sat";$CurrentProfitTotal_Out*=1e8;$CurrentProfitWithoutCostTotal_Out*=1e8}
                }
                $CurrentProfit_Offset = 6
            }
            $StatusLine.Add("$(ConvertTo-LocalCurrency $CurrentProfitTotal_Out $($Session.Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)$(if ($Session.Config.UsePowerPrice) {"/$(ConvertTo-LocalCurrency $CurrentProfitWithoutCostTotal_Out $($Session.Rates.$Miner_Currency) -Offset $CurrentProfit_Offset)"}) $Miner_Currency_Out/Day") > $null
    }
    if ($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_}) {$StatusLine.Add("1 BTC = $(($Session.Config.Currency | Where-Object {$_ -ne "BTC" -and $NewRates.$_} | Sort-Object | ForEach-Object { "$($_) $($NewRates.$_)"})  -join ' = ')") > $null}

    Write-Host " Profit = $($StatusLine -join ' | ') " -BackgroundColor White -ForegroundColor Black
    Write-Host " "
    Remove-Variable "StatusLine"

    #Check for updated RainbowMiner
    if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {
        if ($Session.Config.EnableAutoUpdate) {
            Write-Host "Automatic update to v$($ConfirmedVersion.RemoteVersion) will begin in some seconds" -ForegroundColor Yellow
            $API.Update = $true
        } else {
            Write-Host "To start update, press key `"U`"" -ForegroundColor Yellow            
        }
        Write-Host " "
    }

    #Reduce Memory
    @("BalancesData","BestMiners_Combo","BestMiners_Combo_Comparison","CcMiner","CcMinerNameToAdd","ComboAlgos","ConfigBackup","Miner","Miners","Miners_Device_Combos","MissingCurrencies","MissingCurrenciesTicker","p","Pool","Pool_Config","Pool_Parameters","Pool_WatchdogTimers","q") | Foreach-Object {Remove-Variable $_ -ErrorAction Ignore}
    if ($Error.Count) {$Error | Out-File "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").main.txt" -Append -Encoding utf8}
    $Error.Clear()
    $Global:Error.Clear()
    Get-Job -State Completed | Remove-Job -Force
         
    #Do nothing for a few seconds as to not overload the APIs and display miner download status
    $Session.AutoUpdate = $Session.SkipSwitchingPrevention = $Session.Stopp = $keyPressed = $false

    $Session.Timer = (Get-Date).ToUniversalTime()
    if ($Session.StatEnd.AddSeconds(-10) -le $Session.Timer) {$Session.StatEnd = $Session.Timer.AddSeconds(10)}
    $WaitSeconds = [int]($Session.StatEnd - $Session.Timer).TotalSeconds

    Write-Log "Start waiting $($WaitSeconds) seconds before next run. "

    $Host.UI.RawUI.FlushInputBuffer()

    $cursorPosition = $host.UI.RawUI.CursorPosition
    Write-Host ("Waiting $($WaitSeconds)s until next run: $(if ($ConfirmedVersion.RemoteVersion -gt $ConfirmedVersion.Version) {"[U]pdate RainbowMiner, "})E[x]it, [R]estart, [S]kip switching prevention, [C]onfiguration, [V]erbose{verboseoff}, [P]ause{pauseoff}" -replace "{verboseoff}",$(if ($Session.Config.UIstyle -eq "full"){" off"}) -replace "{pauseoff}",$(if ($Session.PauseMiners){" off"}))

    $SamplesPicked = 0
    $WaitRound = 0
    do {
        $WaitRound++

        $Session.TimerBackup = $Session.Timer

        Start-Sleep 2

        if ($WaitRound % 5 -eq 0) {
            #pick up a sample every ten seconds
            Update-DeviceInformation $Session.ActiveMiners_DeviceNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor)
            $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [Minerstatus]::Running} | Foreach-Object {$_.UpdateMinerData() > $null}
            $SamplesPicked++
        }

        $Session.Timer = (Get-Date).ToUniversalTime()
        if ($UseTimeSync -and $Session.Timer -le $Session.TimerBackup) {Test-TimeSync;$Session.Timer = (Get-Date).ToUniversalTime()}
        $keyPressedValue = $false

        if ((Test-Path ".\stopp.txt") -or $API.Stop) {$keyPressedValue = "X"}
        elseif ($API.Pause -ne $Session.PauseMiners) {$keyPressedValue = "P"}
        elseif ($API.Update) {$keyPressedValue = "U"}
        elseif ([console]::KeyAvailable) {$keyPressedValue = $([System.Console]::ReadKey($true)).key}

        if ($keyPressedValue) {
            switch ($keyPressedValue) {
                "S" { 
                    $Session.SkipSwitchingPrevention = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to skip switching prevention. "
                    Write-Host -NoNewline "[S] pressed - skip switching prevention in next run. "
                    $keyPressed = $true
                }
                "X" {
                    $Session.Stopp = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to stop script. "
                    Write-Host -NoNewline "[X] pressed - stopping script."
                    $keyPressed = $true
                }
                "D" {
                    $Session.StartDownloader = $true
                    $host.UI.RawUI.CursorPosition = $CursorPosition
                    Write-Log "User requests to start downloader. "
                    Write-Host -NoNewline "[D] pressed - starting downloader in next run. "
                    $keyPressed = $true
                }
                "V" {
                    $Session.Config.UIstyle = if ( $Session.Config.UIstyle -eq "full" ) {"lite"} else {"full"}
                    Write-Host -NoNewline "[V] pressed - UI will be set to $($Session.Config.UIstyle) in next run. "
                    $keyPressed = $true
                }
                "P" {
                    $Session.PauseMiners = -not $Session.PauseMiners
                    $API.Pause = $Session.PauseMiners
                    Write-Host -NoNewline "[P] pressed - miner script will be $(if ($Session.PauseMiners) {"PAUSED"} else {"RESTARTED"})"
                    $keyPressed = $true
                }
                "C" {
                    $Session.RunSetup = $true
                    Write-Host -NoNewline "[C] pressed - configuration setup will be started"
                    $keyPressed = $true
                }
                "U" {
                    $Session.AutoUpdate = $true
                    Write-Log "User requests to update to v$($ConfirmedVersion.RemoteVersion)"
                    Write-Host -NoNewline "[U] pressed - automatic update of Rainbowminer will be started "
                    $keyPressed = $true
                }
                "R" {
                    $Session.Restart = $true
                    Write-Log "User requests to restart RainbowMiner."
                    Write-Host -NoNewline "[R] pressed - restarting RainbowMiner."
                    $keyPressed = $true
                }
                "Y" {
                    Stop-AsyncLoader
                    Sleep 2
                    Start-Asyncloader
                    Write-Host -NoNewline "[Y] pressed - Asyncloader yanked."
                    Write-Log "Asyncloader yanked."
                }
            }
        }
    } until ($keyPressed -or $Session.SkipSwitchingPrevention -or $Session.StartDownloader -or $Session.Stopp -or ($Session.Timer -ge $Session.StatEnd))

    if ($SamplesPicked -eq 0) {
        #pick at least one sample   
        Update-DeviceInformation $Session.ActiveMiners_DeviceNames -UseAfterburner (-not $Session.Config.DisableMSIAmonitor)     
        $Session.ActiveMiners | Where-Object {$_.GetStatus() -eq [Minerstatus]::Running} | Foreach-Object {$_.UpdateMinerData() > $null}
        $SamplesPicked++
    }

    if ($Session.Config.EnableMinerStatus -and $Session.Config.MinerStatusURL -and $Session.Config.MinerStatusKey) {
        if ($Session.Timer -gt $Session.NextReport) {
            Update-MinerStatus
            $Session.NextReport = $Session.Timer.AddSeconds($Session.Config.Interval)
        }
    }

    if ($Downloader.HasMoreData) {$Downloader | Receive-Job}

    if (-not $keyPressed) {
        $host.UI.RawUI.CursorPosition = $CursorPosition
        Write-Log "Finish waiting before next run. "
        Write-Host -NoNewline "Finished waiting - starting next run "
    }

    Write-Host (" " * 100)

    #Save current hash rates
    Write-Log "Saving hash rates. "
    $Session.ActiveMiners | Foreach-Object {
        $Miner = $_
        $Miner.Speed_Live = [Double[]]@()

        if ($Miner.New) {$Miner.New = [Boolean]($Miner.Algorithm | Where-Object {-not (Get-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Sub $Session.DevicesToVendors[$Miner.DeviceModel])})}

        if ($Miner.New) {$Miner.Benchmarked++}

        if ($Miner.GetStatus() -eq [Minerstatus]::Running -or $Miner.New) {
            $Miner_PowerDraw = $Miner.GetPowerDraw($Session.Config.Interval * $ExtendInterval)
            $Miner.Algorithm | ForEach-Object {
                $Miner_Speed = $Miner.GetHashRate($_, $Session.Config.Interval * $ExtendInterval, $Miner.New)
                $Miner.Speed_Live += [Double]$Miner_Speed

                if ($Miner.New -and (-not $Miner_Speed)) {$Miner_Speed = $Miner.GetHashRate($_, ($Session.Config.Interval * $Miner.Benchmarked * $ExtendInterval), ($Miner.Benchmarked -lt $Session.Strikes))}

                if ((-not $Miner.New) -or $Miner_Speed -or $Miner.Benchmarked -ge ($Session.Strikes * $Session.Strikes) -or $Miner.GetActivateCount() -ge $Session.Strikes) {
                    $Stat = Set-Stat -Name "$($Miner.Name)_$($_ -replace '\-.*$')_HashRate" -Value $Miner_Speed -Duration $StatSpan -FaultDetection $true -FaultTolerance $Miner.FaultTolerance -PowerDraw $Miner_PowerDraw -Sub $Session.DevicesToVendors[$Miner.DeviceModel]                    
                }

                #Update watchdog timer
                $Miner_Name = $Miner.Name
                $Miner_Algorithm = $_
                $WatchdogTimer = $Session.WatchdogTimers | Where-Object {$_.MinerName -eq $Miner_Name -and $_.PoolName -eq $Pools.$Miner_Algorithm.Name -and $_.Algorithm -eq $Miner_Algorithm}
                if ($Stat -and $WatchdogTimer -and $Stat.Updated -gt $WatchdogTimer.Kicked) {
                    $WatchdogTimer.Kicked = $Stat.Updated
                }
                $Miner_PowerDraw = 0
            }
            $Miner.EndOfRoundCleanup()
            Write-ActivityLog $Miner
        }
    }

    Remove-Variable "Pools" -Force

    #Cleanup stopped miners    
    $Session.ActiveMiners | Where-Object {$_.Stopped} | Foreach-Object {$_.StopMiningPostCleanup()}
        
    if ($Session.Restart -or $Session.AutoUpdate) {
        $Session.Stopp = $false
        try {
            $CurrentProcess = Get-CimInstance Win32_Process -filter "ProcessID=$PID" | Select-Object CommandLine,ExecutablePath
            if ($CurrentProcess.CommandLine -and $CurrentProcess.ExecutablePath) {
                if ($Session.AutoUpdate) {& .\Updater.ps1}
                $StartCommand = $CurrentProcess.CommandLine -replace "^pwsh\s+","$($CurrentProcess.ExecutablePath) "
                $NewKid = Invoke-CimMethod Win32_Process -MethodName Create -Arguments @{CommandLine=$StartCommand;CurrentDirectory=(Split-Path $script:MyInvocation.MyCommand.Path)}
                if ($NewKid -and $NewKid.ReturnValue -eq 0) {
                    Write-Host "Restarting now, please wait!" -BackgroundColor Yellow -ForegroundColor Black                
                    $wait = 0;while ((-not $NewKid.ProcessId -or -not (Get-Process -id $NewKid.ProcessId -ErrorAction Stop)) -and $wait -lt 20) {Write-Host -NoNewline "."; Sleep -Milliseconds 500;$wait++}
                    Write-Host " "
                    if ($NewKid.ProcessId -and (Get-Process -id $NewKid.ProcessId -ErrorAction Ignore)) {$Session.Stopp = $true;$Session.AutoUpdate = $false}
                }
            }
        }
        catch {
        }
        if (-not $Session.Stopp) { #fallback to old updater           
            if ($Session.AutoUpdate) {
                Write-Log -Level Warn "Failed to start new instance of RainbowMiner. Switching to legacy update."                
                $Session.Stopp = $true
            } else {
                Write-Log -Level Warn "Restart not possible, since RainbowMiner has not been started with administrator rights"
                $Session.Restart = $false
            }
        }
    }
}

function Stop-Core {
    [console]::TreatControlCAsInput = $false

    #Stop services
    if (-not $Session.Config.DisableAPI)         {Stop-APIServer}
    if (-not $Session.Config.DisableAsyncLoader) {Stop-AsyncLoader}

    Remove-Item ".\stopp.txt" -Force -ErrorAction Ignore
    Write-Log "Gracefully halting RainbowMiner"
    [System.Collections.ArrayList]$ExcavatorWindowsClosed = @()
    $Session.ActiveMiners | Where-Object {$_.GetActivateCount() -gt 0} | ForEach-Object {
        $Miner = $_
        if ($Miner.GetStatus() -eq [MinerStatus]::Running) {
            Write-Log "Closing $($Miner.Type) miner $($Miner.Name)"
            $Miner.StopMining()            
        }
        if ($Miner.BaseName -like "Excavator*" -and -not $ExcavatorWindowsClosed.Contains($Miner.BaseName)) {
            $Miner.ShutDownMiner()
            $ExcavatorWindowsClosed.Add($Miner.BaseName) > $null
        }
    }
}
