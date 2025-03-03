function Set-PresetDefault {
    if (Test-Path ".\Data\PresetDefault.ps1") {
        $Setup = Get-ChildItemContent ".\Data\PresetDefault.ps1"
        $Setup.PSObject.Properties.Name | Foreach-Object {
            $Session.DefaultValues[$_] = $Setup.$_
        }
    }
}

function Set-AlgorithmsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Algorithms"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\AlgorithmsConfigDefault.ps1").LastWriteTimeUtc
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            $Default = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinHashrateSolo = "0";MinWorkers = "0";MaxTimeToFind = "0";MSIAprofile = 0;OCprofile="";MinerName="";ExcludeMinerName=""}
            $Setup = Get-ChildItemContent ".\Data\AlgorithmsConfigDefault.ps1"
            $AllAlgorithms = Get-Algorithms -Values
            foreach ($Algorithm in $AllAlgorithms) {
                if (-not $Preset.$Algorithm) {$Preset | Add-Member $Algorithm $(if ($Setup.$Algorithm) {$Setup.$Algorithm} else {[PSCustomObject]@{}}) -Force}
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$Algorithm.$SetupName -eq $null){$Preset.$Algorithm | Add-Member $SetupName $Default.$SetupName -Force}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Sorted,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Sorted > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Preset = $Sorted = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-CoinsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Coins"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\CoinsConfigDefault.ps1").LastWriteTimeUtc
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            $Default = [PSCustomObject]@{Penalty = "0";MinHashrate = "0";MinHashrateSolo = "0"; MinWorkers = "0";MaxTimeToFind="0";PostBlockMining="0";MinProfitPercent="0";Wallet="";EnableAutoPool="0";Comment=""}
            $Setup = Get-ChildItemContent ".\Data\CoinsConfigDefault.ps1"
            
            foreach ($Coin in @($Setup.PSObject.Properties.Name | Select-Object)) {
                if (-not $Preset.$Coin) {$Preset | Add-Member $Coin $(if ($Setup.$Coin) {$Setup.$Coin} else {[PSCustomObject]@{}}) -Force}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {                
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$_.$SetupName -eq $null){$Preset.$_ | Add-Member $SetupName $Default.$SetupName -Force}}
                $Sorted | Add-Member $_ $Preset.$_ -Force
            }
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Sorted,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Sorted > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Preset = $Sorted = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-GpuGroupsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})GpuGroups"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile)
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            $GpuNames = Get-Device "amd","intel","nvidia" -IgnoreOpenCL | Select-Object -ExpandProperty Name -Unique
            foreach ($GpuName in $GpuNames) {
                if ($Preset.$GpuName -eq $null) {$Preset | Add-Member $GpuName "" -Force}
                elseif ($Preset.$GpuName -ne "") {$Global:GlobalCachedDevices | Where-Object Name -eq $GpuName | Foreach-Object {$_.Model += $Preset.$GpuName.ToUpper();$_.GpuGroup = $Preset.$GpuName.ToUpper()}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Sorted,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Sorted > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Preset = $Sorted = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-CombosConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Combos"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile)
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

            $Sorted = [PSCustomObject]@{}
            Foreach($SubsetType in @("AMD","INTEL","NVIDIA")) {
                if ($Preset.$SubsetType -eq $null) {$Preset | Add-Member $SubsetType ([PSCustomObject]@{}) -Force}
                if ($Sorted.$SubsetType -eq $null) {$Sorted | Add-Member $SubsetType ([PSCustomObject]@{}) -Force}

                $NewSubsetModels = @()

                $SubsetDevices = @($Global:GlobalCachedDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq $SubsetType})

                if (($SubsetDevices.Model | Select-Object -Unique).Count -gt 1) {

                    # gpugroups never combine against each other, if same gpu. Except full group
                    $GpuGroups = @()
                    $FullGpuGroups = $SubsetDevices | Where-Object GpuGroup -ne "" | Group-Object {$_.Model -replace "$($_.GpuGroup)$"} | Where-Object {$_.Count -gt 1} | Foreach-Object {$GpuGroups += $_.Group.Model;($_.Group.Model | Select-Object -Unique | Sort-Object) -join '-'}

                    # count groups
                    $GpuCount = ($SubsetDevices | Where-Object GpuGroup -eq "" | Select-Object -Property Model -Unique | Measure-Object).Count + $FullGpuGroups.Count

                    # collect full combos for gpu categories
                    $FullCombosByCategory = @{}
                    if ($GpuCount -gt 3) {
                        $SubsetDevices | Group-Object {
                            $Model = $_.Model
                            $Mem = $_.OpenCL.GlobalMemSizeGB
                            Switch ($SubsetType) {
                                "AMD"    {"$($Model.SubString(0,2))$($Mem)GB";Break}
                                "INTEL"  {"$($Model.SubString(0,2))$($Mem)GB";Break}
                                "NVIDIA" {"$(
                                    Switch ($_.OpenCL.Architecture) {
                                        "Pascal" {Switch -Regex ($Model) {"105" {"GTX5";Break};"106" {"GTX6";Break};"(104|107|108)" {"GTX7";Break};default {$Model}};Break}
                                        "Turing" {"RTX2";Break}
                                        "Ampere" {"RTX3";Break}
                                        "Ada"    {"RTX4";Break}
                                        "Hopper" {"H100";Break}
                                        default  {$Model}
                                    })$(if ($Mem -lt 6) {"$($Mem)GB"})"}
                            }
                        } | Foreach-Object {$FullCombosByCategory[$_.Name] = @($_.Group.Model | Select-Object -Unique | Sort-Object | Select-Object)}
                    }

                    $DisplayWarning = $false
                    Get-DeviceSubSets $SubsetDevices | Foreach-Object {
                        $Subset = $_.Model
                        $SubsetModel= $Subset -join '-'
                        if ($Preset.$SubsetType.$SubsetModel -eq $null) {
                            $SubsetDefault = -not $GpuGroups.Count -or ($FullGpuGroups | Where-Object {$SubsetModel -match $_} | Measure-Object).Count -or -not [RBMToolBox]::IsIntersect($GpuGroups,$_.Model)
                            if ($SubsetDefault -and $GpuCount -gt 3) {
                                if (($FullCombosByCategory.GetEnumerator() | Where-Object {(Compare-Object $Subset $_.Value -IncludeEqual -ExcludeDifferent | Measure-Object).Count -eq $_.Value.Count} | Foreach-Object {$_.Value.Count} | Measure-Object -Sum).Sum -ne $Subset.Count) {
                                    $SubsetDefault = "0"
                                }
                                $DisplayWarning = $true
                            }
                            $Preset.$SubsetType | Add-Member $SubsetModel "$([int]$SubsetDefault)" -Force
                        }
                        $NewSubsetModels += $SubsetModel
                    }

                    if ($DisplayWarning) {
                        Write-Log -Level Warn "More than 3 different GPUs will slow down the combo mode significantly. Automatically reducing combinations in combos.config.txt."
                    }

                    # always allow fullcombomodel
                    $Preset.$SubsetType.$SubsetModel = "1"
                }

                $Preset.$SubsetType.PSObject.Properties.Name | Where-Object {$NewSubsetModels -icontains $_} | Sort-Object | Foreach-Object {$Sorted.$SubsetType | Add-Member $_ "$(if (Get-Yes $Preset.$SubsetType.$_) {1} else {0})" -Force}
            }
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Sorted,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Sorted > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Preset = $Sorted = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-DevicesConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Devices"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\DevicesConfigDefault.ps1").LastWriteTimeUtc
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {            
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            $Default = [PSCustomObject]@{Algorithm="";ExcludeAlgorithm="";MinerName="";ExcludeMinerName="";DisableDualMining="";DefaultOCprofile="";PowerAdjust="100";Worker="";EnableLHR=""}
            $Setup = Get-ChildItemContent ".\Data\DevicesConfigDefault.ps1"
            $Devices = Get-Device "amd","intel","nvidia","cpu" -IgnoreOpenCL
            $Devices | Select-Object -Unique Type,Model | Foreach-Object {
                $DeviceModel = $_.Model
                $DeviceType  = $_.Type
                if (-not $Preset.$DeviceModel) {$Preset | Add-Member $DeviceModel $(if ($Setup.$DeviceType) {$Setup.$DeviceType} else {[PSCustomObject]@{}}) -Force}
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$DeviceModel.$SetupName -eq $null){$Preset.$DeviceModel | Add-Member $SetupName $Default.$SetupName -Force}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Sorted,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Sorted > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Preset = $Sorted = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-MinersConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $False)]
        [Switch]$UseDefaultParams = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Miners"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\MinersConfigDefault.ps1").LastWriteTimeUtc
    if ($Force -or $ForceWrite) {
        $Algo = [hashtable]@{}
        $Done = [PSCustomObject]@{}
        $Preset_Copy = $null
        if (Test-Path $PathToFile) {
            $PresetTmp = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
            $Preset_Copy = $PresetTmp | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

            #autofix json array in array for count one
            $PresetTmp.PSObject.Properties.Name | Where-Object {$PresetTmp.$_ -is [array] -and $PresetTmp.$_.Count -eq 1 -and $PresetTmp.$_[0].value -is [array]} | Foreach-Object {$PresetTmp.$_ = $PresetTmp.$_[0].value}

            #cleanup duplicates in algorithm lists
            $Preset = [PSCustomObject]@{}
            if ($PresetTmp.PSObject.Properties.Name.Count -gt 0 ) {
                foreach($Name in @($PresetTmp.PSObject.Properties.Name)) {
                    if (-not $Name -or (Get-Member -inputobject $Preset -name $Name -Membertype Properties)) {continue}
                    $Preset | Add-Member $Name @(
                        [System.Collections.ArrayList]$MinerCheck = @()
                        foreach($cmd in $PresetTmp.$Name) {
                            if (-not $cmd.MainAlgorithm) { continue }
                            $m = $(if (-not $Algo[$cmd.MainAlgorithm]) {$Algo[$cmd.MainAlgorithm]=Get-Algorithm $cmd.MainAlgorithm};$Algo[$cmd.MainAlgorithm])
                            $s = $(if ($cmd.SecondaryAlgorithm) {if (-not $Algo[$cmd.SecondaryAlgorithm]) {$Algo[$cmd.SecondaryAlgorithm]=Get-Algorithm $cmd.SecondaryAlgorithm};$Algo[$cmd.SecondaryAlgorithm]}else{""})
                            $k = "$m-$s"
                            if (-not $MinerCheck.Contains($k)) {$cmd.MainAlgorithm=$m;$cmd.SecondaryAlgorithm=$s;$cmd;[void]$MinerCheck.Add($k)}
                        }) -Force
                }
            }
        }

        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = $null}
            if (-not (Test-Path ".\nopresets.txt")) {$Setup = Get-ChildItemContent ".\Data\MinersConfigDefault.ps1"}
            $AllDevices = Get-Device "cpu","gpu" -IgnoreOpenCL
            $AllMiners = if (Test-Path "Miners") {@(Get-MinersContentRS -Parameters @{InfoOnly = $true})}

            $MiningMode = $Session.Config.MiningMode
            if ($MiningMode -eq $null) {
                try {
                    $MiningMode = (Get-Content $Session.ConfigFiles["Config"].Path -Raw | ConvertFrom-Json -ErrorAction Stop).MiningMode
                    if ($MiningMode -eq "`$MiningMode") {
                        $MiningMode = $Session.DefaultValues["MiningMode"]
                    }
                } catch {
                    Write-Log -Level Warn "Set-MinersConfigDefault: Problem reading MiningMode from config (assuming combo)"
                    $MiningMode = $null
                }
            }
            if (-not $MiningMode) {
                $MiningMode = "combo"
            }

            foreach ($a in @("CPU","AMD","INTEL","NVIDIA")) {
                if ($a -eq "CPU") {[System.Collections.ArrayList]$SetupDevices = @("CPU")}
                else {
                    $Devices = @($AllDevices | Where-Object {$_.Type -eq "Gpu" -and $_.Vendor -eq $a} | Select-Object Model,Model_Name,Name)
                    [System.Collections.ArrayList]$SetupDevices = @($Devices | Select-Object -ExpandProperty Model -Unique)
                    if ($SetupDevices.Count -gt 1 -and $MiningMode -eq "combo") {
                        Get-DeviceSubsets $Devices | Foreach-Object {[void]$SetupDevices.Add($_.Model -join '-')}
                    }
                }
                
                [System.Collections.ArrayList]$Miners = @($AllMiners | Where-Object Type -icontains $a)
                [System.Collections.ArrayList]$MinerNames = @($Miners | Select-Object -ExpandProperty Name -Unique)                
                foreach ($Miner in $Miners) {
                    foreach ($SetupDevice in $SetupDevices) {
                        $Done | Add-Member "$($Miner.Name)-$($SetupDevice)" @(
                            [System.Collections.ArrayList]$MinerCheck = @()
                            foreach($cmd in $Miner.Commands) {
                                $m = $(if (-not $Algo[$cmd.MainAlgorithm]) {$Algo[$cmd.MainAlgorithm]=Get-Algorithm $cmd.MainAlgorithm};$Algo[$cmd.MainAlgorithm])
                                $s = $(if ($cmd.SecondaryAlgorithm) {if (-not $Algo[$cmd.SecondaryAlgorithm]) {$Algo[$cmd.SecondaryAlgorithm]=Get-Algorithm $cmd.SecondaryAlgorithm};$Algo[$cmd.SecondaryAlgorithm]}else{""})
                                $k = "$m-$s"                                
                                if (-not $MinerCheck.Contains($k)) {
                                    if ($SetupDevice -eq "CPU") {
                                        [PSCustomObject]@{MainAlgorithm=$m;SecondaryAlgorithm=$s;Params="";MSIAprofile="";OCprofile="";Difficulty="";Penalty="";HashAdjust="";Disable="0";Tuning="0";ShareCheck="";Affinity="";Threads=""}
                                    } elseif ($s -ne "") {
                                        [PSCustomObject]@{MainAlgorithm=$m;SecondaryAlgorithm=$s;Params="";MSIAprofile="";OCprofile="";Difficulty="";Penalty="";HashAdjust="";Hash2Adjust="";Disable="0";Tuning="0";ShareCheck="";Intensity=""}
                                    } else {
                                        [PSCustomObject]@{MainAlgorithm=$m;SecondaryAlgorithm=$s;Params="";MSIAprofile="";OCprofile="";Difficulty="";Penalty="";HashAdjust="";Disable="0";Tuning="0";ShareCheck=""}
                                    }
                                    [void]$MinerCheck.Add($k)
                                }
                            }
                        )
                    }
                }

                if ($Setup) {
                    foreach ($Name in @($Setup.PSObject.Properties.Name)) {
                        if ($MinerNames.Contains($Name)) {
                            [System.Collections.ArrayList]$Value = @(foreach ($v in $Setup.$Name) {if (-not $UseDefaultParams) {$v.Params = ''};if ($v.MainAlgorithm -ne '*') {$v.MainAlgorithm=$(if (-not $Algo[$v.MainAlgorithm]) {$Algo[$v.MainAlgorithm]=Get-Algorithm $v.MainAlgorithm};$Algo[$v.MainAlgorithm]);$v.SecondaryAlgorithm=$(if ($v.SecondaryAlgorithm) {if (-not $Algo[$v.SecondaryAlgorithm]) {$Algo[$v.SecondaryAlgorithm]=Get-Algorithm $v.SecondaryAlgorithm};$Algo[$v.SecondaryAlgorithm]}else{""})};$v})
                            foreach ($SetupDevice in $SetupDevices) {
                                $NameKey = "$($Name)-$($SetupDevice)"
                                [System.Collections.ArrayList]$ValueTmp = $Value.Clone()
                                if (Get-Member -inputobject $Done -name $NameKey -Membertype Properties) {
                                    [System.Collections.ArrayList]$NewValues = @(Compare-Object @($Done.$NameKey) @($Setup.$Name) -Property MainAlgorithm,SecondaryAlgorithm | Where-Object SideIndicator -eq '<=' | Foreach-Object {$m=$_.MainAlgorithm;$s=$_.SecondaryAlgorithm;$Done.$NameKey | Where-Object {$_.MainAlgorithm -eq $m -and $_.SecondaryAlgorithm -eq $s}} | Select-Object)
                                    if ($NewValues.count) {$ValueTmp.AddRange($NewValues) > $null}
                                    $Done | Add-Member $NameKey $ValueTmp -Force
                                }
                            }
                        }
                    }
                }
            }

            if ($Preset) {
                foreach ($Name in @($Preset.PSObject.Properties.Name)) {
                    [System.Collections.ArrayList]$Value = @(foreach ($v in $Preset.$Name) {if ($v.MainAlgorithm -ne '*') {$v.MainAlgorithm=$(if (-not $Algo[$v.MainAlgorithm]) {$Algo[$v.MainAlgorithm]=Get-Algorithm $v.MainAlgorithm};$Algo[$v.MainAlgorithm]);$v.SecondaryAlgorithm=$(if ($v.SecondaryAlgorithm) {if (-not $Algo[$v.SecondaryAlgorithm]) {$Algo[$v.SecondaryAlgorithm]=Get-Algorithm $v.SecondaryAlgorithm};$Algo[$v.SecondaryAlgorithm]}else{""})};$v})
                    if (Get-Member -inputobject $Done -name $Name -Membertype Properties) {
                        [System.Collections.ArrayList]$NewValues = @(Compare-Object $Done.$Name $Preset.$Name -Property MainAlgorithm,SecondaryAlgorithm | Where-Object SideIndicator -eq '<=' | Foreach-Object {$m=$_.MainAlgorithm;$s=$_.SecondaryAlgorithm;$Done.$Name | Where-Object {$_.MainAlgorithm -eq $m -and $_.SecondaryAlgorithm -eq $s}} | Select-Object)
                        if ($NewValues.Count) {$Value.AddRange($NewValues) > $null}
                    }
                    $Done | Add-Member $Name $Value.ToArray() -Force
                }
            }

            $Default     = [PSCustomObject]@{Params="";MSIAprofile="";OCprofile="";Difficulty="";Penalty="";HashAdjust="";Disable="0";Tuning="0";ShareCheck=""}
            $DefaultCPU  = [PSCustomObject]@{Params="";MSIAprofile="";OCprofile="";Difficulty="";Penalty="";HashAdjust="";Disable="0";Tuning="0";ShareCheck="";Affinity="";Threads=""}
            $DefaultDual = [PSCustomObject]@{Params="";MSIAprofile="";OCprofile="";Difficulty="";Penalty="";HashAdjust="";Hash2Adjust="";Disable="0";Tuning="0";ShareCheck="";Intensity=""}
            $DoneSave = [PSCustomObject]@{}
            $Done.PSObject.Properties.Name | Sort-Object | Foreach-Object {
                $Name = $_
                if ($Done.$Name.Count) {
                    $Done.$Name | Foreach-Object {
                        $Done1 = $_
                        $DefaultHandler = if ($_.SecondaryAlgorithm) {$DefaultDual} elseif ($Name -match "-CPU$") {$DefaultCPU} else {$Default}
                        $DefaultHandler.PSObject.Properties.Name | Where-Object {$Done1.$_ -eq $null} | Foreach-Object {$Done1 | Add-Member $_ $DefaultHandler.$_ -Force}
                    }
                    $DoneSave | Add-Member $Name @($Done.$Name | Sort-Object MainAlgorithm,SecondaryAlgorithm)
                }
            }
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($DoneSave,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $DoneSave > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $PresetTmp = $DoneSave = $Done = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-PoolsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Pools"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $UserpoolsUpdated = $false
    $UserpoolsPathToFile = ""

    $UserpoolsConfigName = "$(if ($Folder -and $Session.ConfigFiles.ContainsKey("$Folder/Userpools")) {"$Folder/"})Userpools"
    if ($UserpoolsConfigName -and $Session.ConfigFiles.ContainsKey($UserpoolsConfigName)) {
        $UserpoolsPathToFile = $Session.ConfigFiles[$UserpoolsConfigName].Path
        if (Test-Path $UserpoolsPathToFile) {
            $UserpoolsUpdated = ((Test-Path $PathToFile) -and (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem $UserpoolsPathToFile).LastWriteTimeUtc)
        } else {
            $UserpoolsPathToFile = ""
        }
    }

    $ForceWrite = -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\PoolsConfigDefault.ps1").LastWriteTimeUtc -or $UserpoolsUpdated
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = $null}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            $Done = [PSCustomObject]@{}
            $Default = [PSCustomObject]@{Worker = "`$WorkerName";Penalty = "0";Algorithm = "";ExcludeAlgorithm = "";CoinName = "";ExcludeCoin = "";CoinSymbol = "";ExcludeCoinSymbol = "";MinerName = "";ExcludeMinerName = "";FocusWallet = "";AllowZero = "0";EnableAutoCoin = "0";EnablePostBlockMining = "0";CoinSymbolPBM = "";DataWindow = "";StatAverage = "";StatAverageStable = "";MaxMarginOfError = "100";SwitchingHysteresis="";MaxAllowedLuck="";MaxTimeSinceLastBlock="";MaxTimeToFind="";Region="";SSL="";BalancesKeepAlive=""}
            $Session.PoolsConfigDefault = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1"
            $Pools = @(Get-ChildItem ".\Pools\*.ps1" -File | Select-Object -ExpandProperty BaseName | Where-Object {$_ -notin @("Userpools")})
            $Userpools = @()
            if ($UserpoolsPathToFile) {
                $UserpoolsConfig = Get-ConfigContent $UserpoolsConfigName
                if ($UserpoolsConfig -isnot [array] -and $UserpoolsConfig.value -ne $null) {
                    $UserpoolsConfig = $UserpoolsConfig.value
                }
                if ($Session.ConfigFiles[$UserpoolsConfigName].Healthy) {
                    $Userpools = @($UserpoolsConfig | Where-Object {$_.Name} | Foreach-Object {$_.Name} | Select-Object -Unique)
                }
            }

            if ($Pools.Count -gt 0 -or $Userpools.Count -gt 0) {
                $Pools + $Userpools | Sort-Object -Unique | Foreach-Object {
                    $Pool_Name = $_
                    if ($Preset -and $Preset.PSObject.Properties.Name -icontains $Pool_Name) {
                        $Setup_Content = $Preset.$Pool_Name
                    } else {
                        $Setup_Content = [PSCustomObject]@{}
                        if ($Pool_Name -ne "WhatToMine") {
                            if ($Pool_Name -in $Userpools) {
                                $Setup_Currencies = @($UserpoolsConfig | Where-Object {$_.Name -eq $Pool_Name} | Select-Object -ExpandProperty Currency -Unique)
                                if (-not $Setup_Currencies) {$Setup_Currencies = @("BTC")}
                            } else {
                                $Setup_Currencies = @("BTC")
                                if ($Session.PoolsConfigDefault.$Pool_Name) {
                                    if ($Session.PoolsConfigDefault.$Pool_Name.Fields) {$Setup_Content = $Session.PoolsConfigDefault.$Pool_Name.Fields}
                                    $Setup_Currencies = @($Session.PoolsConfigDefault.$Pool_Name.Currencies)            
                                }
                            }
                            $Setup_Currencies | Foreach-Object {
                                $Setup_Content | Add-Member $_ "$(if ($_ -eq "BTC"){"`$Wallet"})" -Force
                                $Setup_Content | Add-Member "$($_)-Params" "" -Force
                            }
                        }
                    }
                    if ($Session.PoolsConfigDefault.$Pool_Name.Fields -ne $null) {
                        foreach($SetupName in $Session.PoolsConfigDefault.$Pool_Name.Fields.PSObject.Properties.Name) {if ($Setup_Content.$SetupName -eq $null){$Setup_Content | Add-Member $SetupName $Session.PoolsConfigDefault.$Pool_Name.Fields.$SetupName -Force}}
                    }
                    foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Setup_Content.$SetupName -eq $null){$Setup_Content | Add-Member $SetupName $Default.$SetupName -Force}}
                    if ($Session.PoolsConfigDefault.$Pool_Name.Autoexchange -and (Get-Yes $Setup_Content.EnableAutoCoin)) {
                        $Setup_Content.EnableAutoCoin = "0" # do not allow EnableAutoCoin for pools with autoexchange feature
                    }
                    $Done | Add-Member $Pool_Name $Setup_Content
                }
                if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Done,$Preset_Copy)) {
                    Set-ContentJson -PathToFile $PathToFile -Data $Done > $null
                }
            } else {
                Write-Log -Level Error "No pools found!"
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name): $($_.Exception.Message)"
        }
        finally {
            $Done = $Pools = $Setup_Currencies = $Preset = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-OCProfilesConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})OCProfiles"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile) -or (Get-ChildItem $PathToFile).LastWriteTimeUtc -lt (Get-ChildItem ".\Data\OCProfilesConfigDefault.ps1").LastWriteTimeUtc
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            if ($Preset -is [string] -or -not $Preset.PSObject.Properties.Name) {$Preset = [PSCustomObject]@{}}
            $Preset_Copy = $Preset | ConvertTo-Json -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore
            $Default = [PSCustomObject]@{PowerLimit = 0;ThermalLimit = 0;PriorizeThermalLimit = 0;MemoryClockBoost = "*";CoreClockBoost = "*";LockVoltagePoint = "*";PreCmd="";PreCmdArguments="";PostCmd="";PostCmdArguments="";LockMemoryClock = "*";LockCoreClock = "*"}
            if ($true -or -not $Preset.PSObject.Properties.Name) {
                $Setup = Get-ChildItemContent ".\Data\OCProfilesConfigDefault.ps1"
                $Devices = Get-Device "amd","intel","nvidia" -IgnoreOpenCL
                $Devices | Select-Object -ExpandProperty Model -Unique | Sort-Object | Foreach-Object {
                    $Model = $_
                    For($i=1;$i -le 7;$i++) {
                        $Profile = "Profile$($i)-$($Model)"
                        if (-not $Preset.$Profile) {$Preset | Add-Member $Profile $(if ($Setup.$Profile -ne $null) {$Setup.$Profile} else {$Default}) -Force}
                    }
                }
                if (-not $Devices) {
                    For($i=1;$i -le 7;$i++) {
                        $Profile = "Profile$($i)"
                        if (-not $Preset.$Profile) {$Preset | Add-Member $Profile $(if ($Setup.$Profile -ne $null) {$Setup.$Profile} else {$Default}) -Force}
                    }
                }
            }
            $Preset.PSObject.Properties.Name | Foreach-Object {
                $PresetName = $_
                foreach($SetupName in $Default.PSObject.Properties.Name) {if ($Preset.$PresetName.$SetupName -eq $null){$Preset.$PresetName | Add-Member $SetupName $Default.$SetupName -Force}}
            }
            $Sorted = [PSCustomObject]@{}
            $Preset.PSObject.Properties.Name | Sort-Object | Foreach-Object {$Sorted | Add-Member $_ $Preset.$_ -Force}
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Sorted,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Sorted > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Sorted = $Preset = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-SchedulerConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Scheduler"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile)
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            $Default = Get-ChildItemContent ".\Data\SchedulerConfigDefault.ps1"
            if ($Preset -is [string] -or $Preset -eq $null) {
                $Preset = @($Default) + @((0..6) | Foreach-Object {$a=$Default | ConvertTo-Json -Depth 10 | ConvertFrom-Json -ErrorAction Ignore;$a.DayOfWeek = "$_";$a})
            }
            $Done = @($Preset | Select-Object)
            $Preset_Copy = ConvertTo-Json $Done -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

            if ($Preset -isnot [array] -and $Preset.value -ne $null) {
                $Preset = $Preset.value
            }
            
            $Preset | Foreach-Object {
                foreach($SetupName in @($Default.PSObject.Properties.Name | Select-Object)) {
                    if ($_.$SetupName -eq $null) {$_ | Add-Member $SetupName $Default.$SetupName -Force}
                }
                if (-not $_.Name) {
                    if ($_.DayOfWeek -eq "*") {$_.Name = "All"}
                    elseif ($_.DayOfWeek -match "^[0-6]$") {$_.Name = "$([DayOfWeek]$_.DayOfWeek)"}
                }
            }
            $Done = @($Preset | Select-Object)
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Done,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Done > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Done = $Preset = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Set-UserpoolsConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )
    $ConfigName = "$(if ($Folder) {"$Folder/"})Userpools"
    if (-not (Test-Config $ConfigName)) {return}
    $PathToFile = $Session.ConfigFiles[$ConfigName].Path

    $ForceWrite = -not (Test-Path $PathToFile)
    if ($Force -or $ForceWrite) {
        if (Test-Path $PathToFile) {
            $Preset = Get-ConfigContent $ConfigName
            if (-not $Session.ConfigFiles[$ConfigName].Healthy) {return}
        }
        try {
            $Default = Get-ChildItemContent ".\Data\UserpoolsConfigDefault.ps1"
            if ($Preset -is [string] -or $Preset -eq $null) {
                $Preset = 1..5 | Foreach-Object {$Default | ConvertTo-Json -Depth 10 | ConvertFrom-Json -ErrorAction Ignore}
            }

            $Done = @($Preset | Select-Object)
            $Preset_Copy = ConvertTo-Json $Done -Depth 10 -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore

            if ($Preset -isnot [array] -and $Preset.value -ne $null) {
                $Preset = $Preset.value
            }
            
            $Preset | Foreach-Object {
                foreach($SetupName in @($Default.PSObject.Properties.Name | Select-Object)) {
                    if ($_.$SetupName -eq $null) {$_ | Add-Member $SetupName $Default.$SetupName -Force}
                }
            }

            $Done = @($Preset | Select-Object)
            if ($ForceWrite -or -not [RBMToolBox]::CompareObject($Done,$Preset_Copy)) {
                Set-ContentJson -PathToFile $PathToFile -Data $Done > $null
            }
        }
        catch{
            Write-Log -Level Warn "Could not write to $(([IO.FileInfo]$PathToFile).Name). $($_.Exception.Message)"
        }
        finally {
            $Done = $Preset = $Preset_Copy = $null
        }
    }
    Test-Config $ConfigName -Exists
}

function Test-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$ConfigName,
        [Parameter(Mandatory = $False)]
        [Switch]$Exists,
        [Parameter(Mandatory = $False)]
        [Switch]$Health,
        [Parameter(Mandatory = $False)]
        [Switch]$LastWriteTime
    )
    if (-not $Exists -and ($Health -or $LastWriteTime)) {$Exists = $true}
    $Session.ConfigFiles.ContainsKey($ConfigName) -and $Session.ConfigFiles[$ConfigName].Path -and (-not $Exists -or (Test-Path $Session.ConfigFiles[$ConfigName].Path)) -and (-not $Health -or $Session.ConfigFiles[$ConfigName].Healthy) -and (-not $LastWriteTime -or (Get-ChildItem $Session.ConfigFiles[$ConfigName].Path).LastWriteTimeUtc -gt $Session.ConfigFiles[$ConfigName].LastWriteTime)
}

function Set-ConfigLastWriteTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName
    )
    if (Test-Config $ConfigName -Exists) {
        $Session.ConfigFiles[$ConfigName].LastWriteTime = (Get-ChildItem $Session.ConfigFiles[$ConfigName].Path).LastWriteTimeUtc
    }
}

function Set-ConfigDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName,
        [Parameter(Mandatory = $False)]
        [string]$Folder = "",
        [Parameter(Mandatory = $False)]
        [Switch]$Force = $false
    )

    Switch ($ConfigName) {
        "Algorithms"    {Set-AlgorithmsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Coins"         {Set-CoinsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Combos"        {Set-CombosConfigDefault -Folder $Folder -Force:$Force;Break}
        "Devices"       {Set-DevicesConfigDefault -Folder $Folder -Force:$Force;Break}
        "GpuGroups"     {Set-GpuGroupsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Miners"        {Set-MinersConfigDefault -Folder $Folder -Force:$Force;Break}
        "OCProfiles"    {Set-OCProfilesConfigDefault -Folder $Folder -Force:$Force;Break}
        "Pools"         {Set-PoolsConfigDefault -Folder $Folder -Force:$Force;Break}
        "Scheduler"     {Set-SchedulerConfigDefault -Folder $Folder -Force:$Force;Break}
        "Userpools"     {Set-UserpoolsConfigDefault -Folder $Folder -Force:$Force;Break}
        default {
            $ConfigName = "$(if ($Folder) {"$Folder/"})$($ConfigName)"
            $PathToFile = $Session.ConfigFiles[$ConfigName].Path
            if ((Test-Config $ConfigName) -and -not (Test-Path $PathToFile)) {
                Set-ContentJson -PathToFile $PathToFile -Data ([PSCustomObject]@{}) > $null
                $Session.ConfigFiles[$ConfigName].Healthy = $true
                $Session.ConfigFiles[$ConfigName].LastWriteTime = 0
            }
        }
    }
}

function Get-ConfigPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName,
        [Parameter(Mandatory = $False)]
        [string]$WorkerName = "",
        [Parameter(Mandatory = $False)]
        [string]$GroupName = ""
    )
    if (Test-Config $ConfigName -Exists) {
        $PathToFile = $Session.ConfigFiles[$ConfigName].Path
        if ($WorkerName -or $GroupName) {
            $FileName = Split-Path -Leaf $PathToFile
            $FilePath = Split-Path $PathToFile
            if ($WorkerName) {
                $PathToFileM = Join-Path (Join-Path $FilePath $WorkerName.ToLower()) $FileName
                if (Test-Path $PathToFileM) {$PathToFile = $PathToFileM}
            }
            if ($GroupName) {
                $PathToFileM = Join-Path (Join-Path $FilePath $GroupName.ToLower()) $FileName
                if (Test-Path $PathToFileM) {$PathToFile = $PathToFileM}
            }
        }
        $PathToFile
    }
}

function Get-ConfigContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$ConfigName,
        [Parameter(Mandatory = $False)]
        [hashtable]$Parameters = @{},
        [Parameter(Mandatory = $False)]
        [string]$WorkerName = "",
        [Parameter(Mandatory = $False)]
        [string]$GroupName = "",
        [Parameter(Mandatory = $False)]
        [Switch]$UpdateLastWriteTime,
        [Parameter(Mandatory = $False)]
        [Switch]$ConserveUnkownParameters
    )
    if ($UpdateLastWriteTime) {$WorkerName = ""}
    if ($PathToFile = Get-ConfigPath -ConfigName $ConfigName -WorkerName $WorkerName -GroupName $GroupName) {
        try {
            if ($UpdateLastWriteTime) {
                $Session.ConfigFiles[$ConfigName].LastWriteTime = (Get-ChildItem $PathToFile).LastWriteTimeUtc
            }
            $Result = Get-ContentByStreamReader $PathToFile
            if ($Parameters.Count) {
                $Parameters.Keys | Sort-Object -Descending {$_.Length} | Foreach-Object {$Result = $Result -replace "\`$$($_)","$($Parameters.$_)"}
                if (-not $ConserveUnkownParameters) {
                    $Result = $Result -replace "\`$[A-Z0-9_]+"
                }
            }
            if (Test-IsCore) {
                $Result | ConvertFrom-Json -ErrorAction Stop
            } else {
                $Data = $Result | ConvertFrom-Json -ErrorAction Stop
                $Data
            }
            if (-not $WorkerName) {
                $Session.ConfigFiles[$ConfigName].Healthy=$true
            }
        }
        catch { Write-Log -Level Warn "Your $(([IO.FileInfo]$PathToFile).Name) seems to be corrupt. Check for correct JSON format or delete it.";Write-Log "Your $(([IO.FileInfo]$PathToFile).Name) error: `r`n$($_.Exception.Message)"; if (-not $WorkerName) {$Session.ConfigFiles[$ConfigName].Healthy=$false}}
    }
}

function Get-SessionServerConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [switch]$Force
    )
    if (-not (Test-Config "Config" -Exists)) {return}

    $CurrentConfig = if ($Session.Config) {$Session.Config} else {
        $Result = Get-ConfigContent "Config"
        @("RunMode","ServerName","ServerPort","ServerUser","ServerPassword","EnableServerConfig","ServerConfigName","ExcludeServerConfigVars","EnableServerExcludeList","WorkerName","GroupName","APIPort") | Where-Object {$Session.DefaultValues.ContainsKey($_) -and $Result.$_ -eq "`$$_"} | ForEach-Object {
            $val = $Session.DefaultValues[$_]
            if ($val -is [array]) {$val = $val -join ','}
            $Result.$_ = $val
        }
        $Result
    }

    if ($CurrentConfig -and $CurrentConfig.RunMode -eq "client" -and $CurrentConfig.ServerName -and $CurrentConfig.ServerPort -and (Get-Yes $CurrentConfig.EnableServerConfig)) {
        $ServerConfigName = if ($CurrentConfig.ServerConfigName) {Get-ConfigArray $CurrentConfig.ServerConfigName}
        if (($ServerConfigName | Measure-Object).Count) {
            Get-ServerConfig -ConfigFiles $Session.ConfigFiles -ConfigName $ServerConfigName -ExcludeConfigVars (Get-ConfigArray $CurrentConfig.ExcludeServerConfigVars) -Server $CurrentConfig.ServerName -Port $CurrentConfig.ServerPort -APIPort $CurrentConfig.APIPort -WorkerName $CurrentConfig.WorkerName -GroupName $CurrentConfig.GroupName -Username $CurrentConfig.ServerUser -Password $CurrentConfig.ServerPassword -Force:$Force -EnableServerExcludeList:(Get-Yes $CurrentConfig.EnableServerExcludeList) > $null
        }
    }
}

function Get-ServerConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigFiles,
        [Parameter(Mandatory = $False)]
        [array]$ConfigName = @(),
        [Parameter(Mandatory = $False)]
        [array]$ExcludeConfigVars = @(),
        [Parameter(Mandatory = $False)]
        [string]$Server = "",
        [Parameter(Mandatory = $False)]
        [int]$Port = 0,
        [Parameter(Mandatory = $False)]
        [int]$APIPort = 4000,
        [Parameter(Mandatory = $False)]
        [string]$WorkerName = "",
        [Parameter(Mandatory = $False)]
        [string]$GroupName = "",
        [Parameter(Mandatory = $False)]
        [string]$Username = "",
        [Parameter(Mandatory = $False)]
        [string]$Password = "",
        [Parameter(Mandatory = $False)]
        [switch]$EnableServerExcludeList,
        [Parameter(Mandatory = $False)]
        [switch]$Force
    )
    $rv = $true
    $ConfigName = $ConfigName | Where-Object {Test-Config $_ -Exists}
    if (($ConfigName | Measure-Object).Count -and $Server -and $Port -and (Test-TcpServer -Server $Server -Port $Port -Timeout 2)) {
        $ErrorMessage = ""
        if (-not (Test-Path ".\Data\serverlwt")) {New-Item ".\Data\serverlwt" -ItemType "directory" -ErrorAction Ignore > $null}
        $ServerLWTFile = Join-Path ".\Data\serverlwt" "$(if ($GroupName) {$GroupName} elseif ($WorkerName) {$WorkerName} else {"this"})_$($Server.ToLower() -replace '\.','-')_$($Port).json"
        $ServerLWT = if (Test-Path $ServerLWTFile) {try {Get-ContentByStreamReader $ServerLWTFile | ConvertFrom-Json -ErrorAction Stop} catch {}}
        if (-not $ServerLWT) {$ServerLWT = [PSCustomObject]@{}}
        $Params = ($ConfigName | Foreach-Object {$PathToFile = $ConfigFiles[$_].Path;"$($_)ZZZ$(if ($Force -or -not (Test-Path $PathToFile) -or -not $ServerLWT.$_) {"0"} else {$ServerLWT.$_})"}) -join ','
        $Uri = "http://$($Server):$($Port)/getconfig?config=$($Params)&workername=$($WorkerName)&groupname=$($GroupName)&machinename=$($Session.MachineName)&myip=$($Session.MyIP)&port=$($APIPort)&version=$($Session.Version)"
        try {
            $Result = Invoke-GetUrl $Uri -user $Username -password $Password -ForceLocal -Timeout 30
        } catch {
            $ErrorMessage = "$($_.Exception.Message)"
        }
        if ($Result.Status -and $Result.Content) {
            if ($EnableServerExcludeList -and $Result.ExcludeList) {$ExcludeConfigVars = $Result.ExcludeList}
            $ChangeTag = Get-ContentDataMD5hash($ServerLWT) 
            $ConfigName | Where-Object {$Result.Content.$_.isnew -and $Result.Content.$_.data} | Foreach-Object {
                $PathToFile = $ConfigFiles[$_].Path
                $Data = $Result.Content.$_.data
                if ($_ -eq "config") {
                    $Preset = Get-ConfigContent "config"
                    $Data.PSObject.Properties.Name | Where-Object {$ExcludeConfigVars -inotcontains $_} | Foreach-Object {$Preset | Add-Member $_ $Data.$_ -Force}
                    $Data = $Preset
                } elseif ($_ -eq "pools") {
                    $Preset = Get-ConfigContent "pools"
                    $Preset.PSObject.Properties.Name | Where-Object {$Data.$_ -eq $null -or $ExcludeConfigVars -match "^pools:$($_)$"} | Foreach-Object {$Data | Add-Member $_ $Preset.$_ -Force}
                    $ExcludeConfigVars -match "^pools:.+:.+$" | Foreach-Object {
                        $PoolName = ($_ -split ":")[1]
                        $PoolKey  = ($_ -split ":")[2]
                        if ($Preset.$PoolName.$PoolKey -ne $null) {
                            $Data.$PoolName | Add-Member $PoolKey $Preset.$PoolName.$PoolKey -Force
                        }
                    }
                }
                Set-ContentJson -PathToFile $PathToFile -Data $Data > $null
                $ServerLWT | Add-Member $_ $Result.Content.$_.lwt -Force
            }
            if ($ChangeTag -ne (Get-ContentDataMD5hash($ServerLWT))) {Set-ContentJson $ServerLWTFile -Data $ServerLWT > $null}
        } elseif (-not $Result.Status) {
            Write-Log -Level Warn "Get-ServerConfig failed $(if ($Result.Content) {$Result.Content} else {$ErrorMessage})"
            $rv = $false
        }
    }
    $rv
}

function Confirm-ConfigHealth {
    $Ok = $true
    $Session.ConfigFiles.Keys | Where-Object {$Session.ConfigFiles.$_.Path -and (Test-Path $Session.ConfigFiles.$_.Path)} | Where-Object {(Get-ChildItem $Session.ConfigFiles.$_.Path).LastWriteTimeUtc -gt $_.Value.LastWriteTime} | Foreach-Object {
        $Name = $_
        $File = $Session.ConfigFiles.$_
        try {
            Get-ContentByStreamReader $File.Path | ConvertFrom-Json -ErrorAction Stop > $null
        } catch {
            Write-Log -Level Warn "$($Name) configfile $(Split-Path $File.Path -Leaf) has invalid JSON syntax!"
            $Ok = $false
        }
    }
    $Ok
}
