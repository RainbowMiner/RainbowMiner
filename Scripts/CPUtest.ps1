Import-Module .\Modules\Include.psm1
Import-Module .\Modules\DeviceLib.psm1

Initialize-Session

$TestFileName = "cputestresult.txt"

$CPUInfo     = [PSCustomObject]@{}

"CPU-TEST $((Get-Date).ToUniversalTime())" | Out-File $TestFileName -Encoding utf8
"="*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

if ($IsWindows) {

    " " | Out-File $TestFileName -Append
    "1. CHKCPU32.exe" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    $Arguments = @('/x')
    Invoke-Exe '.\Includes\CHKCPU32.exe' -ArgumentList ($Arguments -join ' ') -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Out-File $TestFileName -Encoding utf8 -Append

    " " | Out-File $TestFileName -Append
    "2. Get-CimInstance -ClassName CIM_Processor" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {
        $CIM_CPU = Get-CimInstance -ClassName CIM_Processor
        $CPUNo = 0
        $CIM_CPU | Foreach-Object {
            "** CPU$($CPUNo) **" | Out-File $TestFileName -Append
            $_.CimInstanceProperties | Where-Object Value | Foreach-Object {
                "  $($_.Name)=$($_.Value)" | Out-File $TestFileName -Append
            }
            $CPUNo++
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }

    if ($CIM_CPU) {
        " " | Out-File $TestFileName -Append
        "3. Fill CPUInfo object" | Out-File $TestFileName -Append
        "-"*80 | Out-File $TestFileName -Append
        " " | Out-File $TestFileName -Append

        try {
            $CPUInfo | Add-Member Name          "$($CIM_CPU[0].Name)".Trim()
            $CPUInfo | Add-Member Manufacturer  "$($CIM_CPU[0].Manufacturer)".Trim()
            $CPUInfo | Add-Member Cores         ($CIM_CPU.NumberOfCores | Measure-Object -Sum).Sum
            $CPUInfo | Add-Member Threads       ($CIM_CPU.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
            $CPUInfo | Add-Member PhysicalCPUs  ($CIM_CPU | Measure-Object).Count
            $CPUInfo | Add-Member L3CacheSize   $CIM_CPU[0].L3CacheSize
            $CPUInfo | Add-Member MaxClockSpeed $CIM_CPU[0].MaxClockSpeed
            $CPUInfo | Add-Member TDP           0
            $CPUInfo | Add-Member Family        0
            $CPUInfo | Add-Member Model         0
            $CPUInfo | Add-Member Stepping      0
            $CPUInfo | Add-Member Architecture  ""
            $CPUInfo | Add-Member Features      @{}
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }

        " " | Out-File $TestFileName -Append
        "4. Add Family/Model/Stepping to CPUInfo object" | Out-File $TestFileName -Append
        "-"*80 | Out-File $TestFileName -Append
        " " | Out-File $TestFileName -Append

        try {
            $lscpu = Get-CpuInfo
            $CPUInfo.Family   = $lscpu.family
            $CPUInfo.Model    = $lscpu.model
            $CPUInfo.Stepping = $lscpu.stepping
            $lscpu.features | Foreach-Object {$CPUInfo.Features."$($_ -replace "[^a-z0-9]")" = $true}
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }

        try {
            if (-not $CPUInfo.Family   -and $CIM_CPU[0].Caption -match "Family\s*(\d+)")   {$CPUInfo.Family   = $Matches[1]}
            if (-not $CPUInfo.Model    -and $CIM_CPU[0].Caption -match "Model\s*(\d+)")    {$CPUInfo.Model    = $Matches[1]}
            if (-not $CPUInfo.Stepping -and $CIM_CPU[0].Caption -match "Stepping\s*(\d+)") {$CPUInfo.Stepping = $Matches[1]}
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }

        " " | Out-File $TestFileName -Append
        "5. Add RealCores to CPUInfo object" | Out-File $TestFileName -Append
        "-"*80 | Out-File $TestFileName -Append
        " " | Out-File $TestFileName -Append

        try {
            $CPUInfo | Add-Member RealCores ([int[]](0..($CPUInfo.Threads - 1))) -Force
            if ($CPUInfo.Threads -gt $CPUInfo.Cores) {$CPUInfo.RealCores = $CPUInfo.RealCores | Where-Object {-not ($_ % [int]($CPUInfo.Threads/$CPUInfo.Cores))}}
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }

    }

    " " | Out-File $TestFileName -Append
    "6. list_cpu_features.exe" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {
        (Invoke-Exe ".\Includes\list_cpu_features.exe" -ArgumentList "--json" -WorkingDirectory $Pwd | ConvertFrom-Json -ErrorAction Stop).flags | Foreach-Object {$CPUInfo.Features."$($_ -replace "[^a-z0-9]")" = $true}
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }

    " " | Out-File $TestFileName -Append
    "7. GetCPU.exe" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append
    if (Test-IsElevated) {
        try {
            $GetCPU = Invoke-Exe ".\Includes\GetCPU\GetCPU.exe" -ArgumentList "--debug" -WorkingDirectory $Pwd | ConvertFrom-Json -ErrorAction Stop | ConvertTo-Json | Out-File $TestFileName -Append
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }
    } else {
        "not started, needs elevated rights" | Out-File $TestFileName -Append
    }

    $lfnr = 7
}

if ($IsLinux) {

    " " | Out-File $TestFileName -Append
    "1. lscpu" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    if (Get-Command "lscpu" -ErrorAction Ignore) {
        try {
            Invoke-Exe 'lscpu' -ExpandLines -ExcludeEmptyLines | Out-File $TestFileName -Append
            "[Exit $($Global:LASTEXEEXITCODE)]" | Out-File $TestFileName -Append
            if (-not (Test-Path ".\Data\lscpu.txt")) {
                Invoke-Exe 'lscpu' -ExpandLines -ExcludeEmptyLines | Out-File ".\Data\lscpu.txt"
            }
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }

    } else {
        "command lscpu not found" | Out-File $TestFileName -Append
    }

    " " | Out-File $TestFileName -Append
    "2. cpuinfo" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {
        $Data = Get-Content "/proc/cpuinfo"
        $Data | Out-File $TestFileName -Append
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }

    " " | Out-File $TestFileName -Append
    "3. getcpuinfo.sh" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {
        $Data = Invoke-Exe "IncludesLinux/bash/getcpuinfo.sh"
        try {
            ConvertFrom-Json $Data -ErrorAction Stop | ConvertTo-Json | Out-File $TestFileName -Append
        } catch {
            $Data | Out-File $TestFileName -Append
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }
        "[Exit $($Global:LASTEXEEXITCODE)]" | Out-File $TestFileName -Append
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }

    " " | Out-File $TestFileName -Append
    "4. getcputopo.sh" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {
        $Data = Invoke-Exe "IncludesLinux/bash/getcputopo.sh"
        try {
            ConvertFrom-Json $Data -ErrorAction Stop | ConvertTo-Json | Out-File $TestFileName -Append
        } catch {
            $Data | Out-File $TestFileName -Append
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        }
        "[Exit $($Global:LASTEXEEXITCODE)]" | Out-File $TestFileName -Append
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }

    " " | Out-File $TestFileName -Append
    "5. Fill CPUInfo object" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {
        $ci = Get-CpuInformation
        if ($ci) {
            $CPUInfo | Add-Member Name          $ci.Name
            $CPUInfo | Add-Member Manufacturer  $ci.Manufacturer
            $CPUInfo | Add-Member Cores         ([int]$ci.Cores)
            $CPUInfo | Add-Member Threads       ([int]$ci.Threads)
            $CPUInfo | Add-Member PhysicalCPUs  ([int]$ci.PhysicalCPUs)
            $CPUInfo | Add-Member L3CacheSize   ([int]($ci.L3CacheKB/1024))   # if you want MB
            $CPUInfo | Add-Member MaxClockSpeed ([int]$ci.MaxClockMHz)
            $CPUInfo | Add-Member TDP           0
            $CPUInfo | Add-Member Family        $ci.Family
            $CPUInfo | Add-Member Model         $ci.Model
            $CPUInfo | Add-Member Stepping      $ci.Stepping
            $CPUInfo | Add-Member Architecture  $ci.Architecture
            $CPUInfo | Add-Member Features      @{}

            # Features map
            if ($ci.Features) {
                foreach ($p in $ci.Features.PSObject.Properties) {
                    $CPUInfo.Features[$p.Name] = [bool]$p.Value
                }
            }

            if ($ci.IsArm) {
                $CPUInfo.Features.ARM = $true
                $CPUInfo.Architecture = $ci.ARMarch
                if ($ci.ArmParts -and (-not $CPUInfo.Name -or -not $CPUInfo.Manufacturer -or $CPUInfo.Name -eq "Unknown" -or $CPUInfo.Manufacturer -eq "Unknown")) {
                    try {
                        $ArmDB = Get-Content ".\Data\armdb.json" | ConvertFrom-Json -ErrorAction Stop
                        $CPUName = [System.Collections.Generic.List[string]]::new()

                        if (-not $CPUInfo.Name) {
                            $CPUInfo.Name = "Unknown"
                        }

                        if (-not $CPUInfo.Manufacturer) {
                            $CPUInfo.Manufacturer = "Unknown"
                        }

                        foreach($ArmPart in $ci.ArmParts) {
                            $CPUimpl = [int]$ArmPart.implementer
                            if ($CPUimpl -gt 0 -and $ArmDB.implementers.$CPUimpl -ne $null) {
                                $CPUInfo.Manufacturer = $ArmDB.implementers.$CPUimpl

                                    
                                if ($ArmDB.implementers.$CPUimpl -ne $null) {
                                    $CPUInfo.Manufacturer = $ArmDB.implementers.$CPUimpl

                                    $part = [int]$ArmPart.part
                                    $variant = [int]$ArmPart.variant

                                    $name = if ($ArmDB.variants.$CPUimpl.$part.$variant -ne $null) {$ArmDB.variants.$CPUimpl.$part.$variant}
                                            elseif ($ArmDB.parts.$CPUimpl.$part -ne $null) {$ArmDB.parts.$CPUimpl.$part}

                                    if ($name -and -not $CPUName.Contains([string]$name)) {
                                        [void]$CPUName.Add([string]$name)
                                    }
                                }
                            }
                        }
                        if ($CPUName.Length -gt 0) {
                            $CPUInfo.Name = $CPUName -join "/"
                        }
                        $CPUName = $null
                    } catch {
                    }
                }
            }

        }
                    
        if (-not $CPUInfo.Name -or -not $CPUInfo.Cores -or -not $CPUInfo.PhysicalCPUs) { # Fallback to old code
            #$Data = Get-Content "/proc/cpuinfo"
            if ($Data) {
                $CPUInfo | Add-Member Name          "$((($Data | Where-Object {$_ -match 'model name'} | Select-Object -First 1) -split ":")[1])".Trim() -Force
                $CPUInfo | Add-Member Manufacturer  "$((($Data | Where-Object {$_ -match 'vendor_id'}  | Select-Object -First 1) -split ":")[1])".Trim() -Force
                $CPUInfo | Add-Member Cores         ([int]"$((($Data | Where-Object {$_ -match 'cpu cores'}  | Select-Object -First 1) -split ":")[1])".Trim()) -Force
                $CPUInfo | Add-Member Threads       ([int]"$((($Data | Where-Object {$_ -match 'siblings'}   | Select-Object -First 1) -split ":")[1])".Trim()) -Force
                $CPUInfo | Add-Member PhysicalCPUs  ($Data | Where-Object {$_ -match 'physical id'} | Select-Object -Unique | Measure-Object).Count -Force
                $CPUInfo | Add-Member L3CacheSize   ([int](ConvertFrom-Bytes "$((($Data | Where-Object {$_ -match 'cache size'} | Select-Object -First 1) -split ":")[1])".Trim())/1024) -Force
                $CPUInfo | Add-Member MaxClockSpeed ([int]"$((($Data | Where-Object {$_ -match 'cpu MHz'}    | Select-Object -First 1) -split ":")[1])".Trim()) -Force
                $CPUInfo | Add-Member TDP           0 -Force
                $CPUInfo | Add-Member Family        "$((($Data | Where-Object {$_ -match 'cpu family'}  | Select-Object -First 1) -split ":")[1])".Trim() -Force
                $CPUInfo | Add-Member Model         "$((($Data | Where-Object {$_ -match 'model\s*:'}  | Select-Object -First 1) -split ":")[1])".Trim() -Force
                $CPUInfo | Add-Member Stepping      "$((($Data | Where-Object {$_ -match 'stepping'}  | Select-Object -First 1) -split ":")[1])".Trim() -Force
                $CPUInfo | Add-Member Architecture  "$((($Data | Where-Object {$_ -match 'CPU architecture'}  | Select-Object -First 1) -split ":")[1])".Trim() -Force
                $CPUInfo | Add-Member Features      @{} -Force

                $Processors = ($Data | Where-Object {$fld = $_ -split ":";$fld.Count -gt 1 -and $fld[0].Trim() -eq "processor" -and $fld[1].Trim() -match "^[0-9]+$"} | Measure-Object).Count

                if (-not $CPUInfo.PhysicalCPUs) {$CPUInfo.PhysicalCPUs = 1}
                if (-not $CPUInfo.Cores)   {$CPUInfo.Cores = 1}
                if (-not $CPUInfo.Threads) {$CPUInfo.Threads = 1}

                @("Family","Model","Stepping","Architecture") | Foreach-Object {
                    if ($CPUInfo.$_ -match "^[0-9a-fx]+$") {$CPUInfo.$_ = [int]$CPUInfo.$_}
                }

                "$((($Data | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$ft = "$($_ -replace "[^a-z0-9]+")";if ($ft -ne "") {$CPUInfo.Features.$ft = $true}}
                "$((($Data | Where-Object {$_ -like "Features*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$ft = "$($_ -replace "[^a-z0-9]+")";if ($ft -ne "") {$CPUInfo.Features.$ft = $true}}

                if (-not $CPUInfo.Name -or -not $CPUInfo.Manufacturer) {
                    try {
                        $CPUimpl = [int]"$((($Data | Where-Object {$_ -match 'CPU implementer'} | Select-Object -First 1) -split ":")[1])".Trim()
                        if ($CPUimpl -gt 0) {
                            $CPUpart = @($Data | Where-Object {$_ -match "CPU part"} | Foreach-Object {[int]"$(($_ -split ":")[1])".Trim()}) | Select-Object -Unique
                            $CPUvariant = @($Data | Where-Object {$_ -match "CPU variant"} | Foreach-Object {[int]"$(($_ -split ":")[1])".Trim()}) | Select-Object -Unique
                            $ArmDB = Get-Content ".\Data\armdb.json" | ConvertFrom-Json -ErrorAction Stop
                            if ($ArmDB.implementers.$CPUimpl -ne $null) {
                                $CPUInfo.Manufacturer = $ArmDB.implementers.$CPUimpl
                                $CPUInfo.Name = "Unknown"

                                if ($CPUpart.Length -gt 0) {
                                    $CPUName = [System.Collections.Generic.List[string]]::new()
                                    for($i=0; $i -lt $CPUpart.Length; $i++) {
                                        $part = $CPUpart[$i]
                                        $variant = if ($CPUvariant -and $CPUvariant.length -gt $i) {$CPUvariant[$i]} else {$CPUvariant[0]}
                                        if ($ArmDB.variants.$CPUimpl.$part.$variant -ne $null) {[void]$CPUName.Add($ArmDB.variants.$CPUimpl.$part.$variant)}
                                        elseif ($ArmDB.parts.$CPUimpl.$part -ne $null) {[void]$CPUName.Add($ArmDB.parts.$CPUimpl.$part)}
                                    }
                                    if ($CPUName.Length -gt 0) {
                                        $CPUInfo.Name = $CPUName -join "/"
                                        $CPUInfo.Features.ARM = $true
                                    }
                                    $CPUName = $null
                                }
                            }
                        }
                    } catch {
                    }
                }                

                if ((-not $CPUInfo.Name -or -not $CPUInfo.Manufacturer -or -not $Processors) -and (Test-Path ".\Data\lscpu.txt")) {
                    try {
                        $lscpu = (Get-Content ".\Data\lscpu.txt") -split "[\r\n]+"
                        $CPUName = @($lscpu | Where-Object {$_ -match 'model name'} | Foreach-Object {"$(($_ -split ":")[1].Trim())"}) | Select-Object -Unique
                        $CPUInfo.Name = $CPUName -join "/"
                        $CPUInfo.Manufacturer = "$((($lscpu | Where-Object {$_ -match 'vendor id'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        if (-not $Processors) {
                            $Processors = [int]"$((($lscpu | Where-Object {$_ -match '^CPU\(s\)'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        }

                        "$((($lscpu | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$CPUInfo.Features."$($_ -replace "[^a-z0-9]+")" = $true}

                    } catch {
                    }
                }

                if ($CPUInfo.PhysicalCPUs -gt 1) {
                    $CPUInfo.Cores   *= $CPUInfo.PhysicalCPUs
                    $CPUInfo.Threads *= $CPUInfo.PhysicalCPUs
                    $CPUInfo.PhysicalCPUs = 1
                }

                #adapt to virtual CPUs and ARM
                if ($Processors -gt $CPUInfo.Threads -and $CPUInfo.Threads -eq 1) {
                    $CPUInfo.Cores   = $Processors
                    $CPUInfo.Threads = $Processors
                }
            }
        }
    
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }


    " " | Out-File $TestFileName -Append
    "6. Add real cores and threadlist to CPUInfo object" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    try {

        $threadList = $realCores = $null

        try {
            $topo = Get-CpuTopology | Where-Object { $_.online }

            $allCpus = @(
                $topo | 
                    Sort-Object socket, core, thread, cpu |
                    Select-Object -ExpandProperty cpu -Unique
            )

            $realCores = @(
                $topo |
                    Group-Object socket, core |
                    ForEach-Object {
                        $g = $_.Group | Sort-Object thread, cpu
                        $t0 = $g | Where-Object thread -eq 0 | Select-Object -First 1
                        if ($t0) { $t0.cpu } else { $g[0].cpu }
                    } |
                    Sort-Object
            )

            $threadList = @(
                $allCpus | Where-Object { $_ -notin $realCores }
            )
        }
        catch {
        }

        if (-not $realCores) {
            $realCores = [int[]](0..($CPUInfo.Cores - 1))
        }
        if ($CPUInfo.Threads -gt $CPUInfo.Cores -and -not $threadList) {
            $threadList = [int[]]($CPUInfo.Cores..($CPUInfo.Threads + $CPUInfo.Cores - 1))
        }

        $CPUInfo | Add-Member RealCores  ([int[]]$realCores)  -Force
        $CPUInfo | Add-Member ThreadList ([int[]]$threadList) -Force

    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    }

    $lfnr = 6
}

$lfnr++

" " | Out-File $TestFileName -Append
"$($lfnr). Add Vendor to CPUInfo object" | Out-File $TestFileName -Append
"-"*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

try {
    $CPUInfo | Add-Member Vendor $(Switch -Regex ("$($CPUInfo.Manufacturer)") {
                "(AMD|Advanced Micro Devices)" {"AMD"}
                "Hygon" {"HYGON"}
                "Intel" {"INTEL"}
                default {"$($CPUInfo.Manufacturer)".ToUpper() -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
            })

    if (-not $CPUInfo.Vendor) {$CPUInfo.Vendor = "OTHER"}
    if ($CPUInfo.Vendor -eq "ARM") {$CPUInfo.Features.ARM = $true}
    $CPUInfo | Add-Member IsRyzen ($CPUInfo.Vendor -eq "AMD" -and $CPUInfo.Name -match "Ryzen")
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
    "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
    "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
}

$lfnr++

" " | Out-File $TestFileName -Append
"$($lfnr). Result: CPUInfo" | Out-File $TestFileName -Append
"-"*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

$CPUInfo | ConvertTo-Json -ErrorAction Ignore -Depth 10 | Out-File $TestFileName -Append

Write-Host "Done! Now please drop the file"
Write-Host " "
Write-Host $(Resolve-Path $TestFileName | Select-Object -ExpandProperty Path) -ForegroundColor Yellow
Write-Host " "
Write-Host "onto your issue at https://github.com/RainbowMiner/RainbowMiner/issues"
Write-Host " "
