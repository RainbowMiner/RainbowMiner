using module ..\Modules\Include.psm1

$TestFileName = "cputestresult.txt"

if ($IsWindows -eq $null) {
    if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
    }
}

$CPUInfo     = [PSCustomObject]@{Features = @{}}

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
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    if ($CIM_CPU) {
        " " | Out-File $TestFileName -Append
        "3. Fill CPUInfo object" | Out-File $TestFileName -Append
        "-"*80 | Out-File $TestFileName -Append
        " " | Out-File $TestFileName -Append

        try {
            $CPUInfo | Add-Member Name          $CIM_CPU[0].Name
            $CPUInfo | Add-Member Manufacturer  $CIM_CPU[0].Manufacturer
            $CPUInfo | Add-Member Cores         ($CIM_CPU.NumberOfCores | Measure-Object -Sum).Sum
            $CPUInfo | Add-Member Threads       ($CIM_CPU.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
            $CPUInfo | Add-Member PhysicalCPUs  ($CIM_CPU | Measure-Object).Count
            $CPUInfo | Add-Member L3CacheSize   $CIM_CPU[0].L3CacheSize
            $CPUInfo | Add-Member MaxClockSpeed $CIM_CPU[0].MaxClockSpeed
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    }

    " " | Out-File $TestFileName -Append
    "4. Get-CPUFeatures" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

   try {
        Get-CPUFeatures | Foreach-Object {$CPUInfo.Features.$_ = $true}
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
        "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
        "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
        if ($Error.Count){$Error.RemoveAt(0)}
    }

}


if ($IsLinux) {

    " " | Out-File $TestFileName -Append
    "1. lscpu" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    Invoke-Exe 'lscpu' -ExpandLines -ExcludeEmptyLines | Out-File $TestFileName -Append

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
        if ($Error.Count){$Error.RemoveAt(0)}
    }

    " " | Out-File $TestFileName -Append
    "3. Fill CPUInfo object" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append
    
    if ($Data) {
        try {
            $CPUInfo | Add-Member Name          "$((($Data | Where-Object {$_ -match 'model name'} | Select-Object -First 1) -split ":")[1])".Trim()
            $CPUInfo | Add-Member Manufacturer  "$((($Data | Where-Object {$_ -match 'vendor_id'}  | Select-Object -First 1) -split ":")[1])".Trim()
            $CPUInfo | Add-Member Cores         ([int]"$((($Data | Where-Object {$_ -match 'cpu cores'}  | Select-Object -First 1) -split ":")[1])".Trim())
            $CPUInfo | Add-Member Threads       ([int]"$((($Data | Where-Object {$_ -match 'siblings'}   | Select-Object -First 1) -split ":")[1])".Trim())
            $CPUInfo | Add-Member PhysicalCPUs  ($Data | Where-Object {$_ -match 'physical id'} | Select-Object -Unique | Measure-Object).Count
            $CPUInfo | Add-Member L3CacheSize   ([int](ConvertFrom-Bytes "$((($Data | Where-Object {$_ -match 'cache size'} | Select-Object -First 1) -split ":")[1])".Trim())/1024)
            $CPUInfo | Add-Member MaxClockSpeed ([int]"$((($Data | Where-Object {$_ -match 'cpu MHz'}    | Select-Object -First 1) -split ":")[1])".Trim())

            $Processors = ($Data | Where-Object {$_ -match "^processor"} | Measure-Object).Count

            if ($CPUInfo.PhysicalCPUs -gt 1) {
                $CPUInfo.Cores   *= $CPUInfo.PhysicalCPUs
                $CPUInfo.Threads *= $CPUInfo.PhysicalCPUs
                $CPUInfo.PhysicalCPUs = 1
            }

            #adapt to virtual CPUs
            if ($Processors -gt $CPUInfo.Threads -and $CPUInfo.Threads -eq 1) {
                $CPUInfo.Cores   = $Processors
                $CPUInfo.Threads = $Processors
            }
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    }

    " " | Out-File $TestFileName -Append
    "4. Parse CPU features" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    if ($Data) {
        try {
            "$((($Data | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$CPUInfo.Features."$($_ -replace "[^a-z0-9]+")" = $true}

            if ($CPUInfo.Features.avx512f -and $CPUInfo.Features.avx512vl -and $CPUInfo.Features.avx512dq -and $CPUInfo.Features.avx512bw) {$CPUInfo.Features.avx512 = $true}
        } catch {
            "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
            "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
            "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
            if ($Error.Count){$Error.RemoveAt(0)}
        }
    }

}

" " | Out-File $TestFileName -Append
"5. Add Vendor to CPUInfo object" | Out-File $TestFileName -Append
"-"*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

try {
    $CPUInfo | Add-Member Vendor $(Switch -Regex ("$($CPUInfo.Manufacturer)") {
                "(AMD|Advanced Micro Devices)" {"AMD"}
                "Intel" {"INTEL"}
                default {"$($CPUInfo.Manufacturer)".ToUpper() -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
            })

    if (-not $CPUInfo.Vendor) {$CPUInfo.Vendor = "OTHER"}
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
    "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
    "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    if ($Error.Count){$Error.RemoveAt(0)}
}

" " | Out-File $TestFileName -Append
"6. Add RealCores to CPUInfo object" | Out-File $TestFileName -Append
"-"*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

try {
    $CPUInfo | Add-Member RealCores ([int[]](0..($CPUInfo.Threads - 1))) -Force
    if ($CPUInfo.Threads -gt $CPUInfo.Cores) {$CPUInfo.RealCores = $CPUInfo.RealCores | Where-Object {-not ($_ % [int]($CPUInfo.Threads/$CPUInfo.Cores))}}
    $CPUInfo | Add-Member IsRyzen ($CPUInfo.Vendor -eq "AMD" -and $CPUInfo.Name -match "Ryzen")
} catch {
    "ERROR: $($_.Exception.Message)" | Out-File $TestFileName -Append
    "$($_.InvocationInfo.PositionMessage)" | Out-File $TestFileName -Append
    "$($_.Exception.StackTrace)" | Out-File $TestFileName -Append
    if ($Error.Count){$Error.RemoveAt(0)}
}

" " | Out-File $TestFileName -Append
"Result: CPUInfo" | Out-File $TestFileName -Append
"-"*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

$CPUInfo | ConvertTo-Json -ErrorAction Ignore -Depth 10 | Out-File $TestFileName -Append

Write-Host "Done! Now please drop the file"
Write-Host " "
Write-Host $(Resolve-Path $TestFileName | Select-Object -ExpandProperty Path) -ForegroundColor Yellow
Write-Host " "
Write-Host "onto your issue at https://github.com/RainbowMiner/RainbowMiner/issues"
Write-Host " "
