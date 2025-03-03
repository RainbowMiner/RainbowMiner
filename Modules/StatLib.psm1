#
# Stat functions
#

function Set-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $true)]
        [Double]$Value,
        [Parameter(Mandatory = $false)]
        [Double]$Actual24h = 0,
        [Parameter(Mandatory = $false)]
        [Double]$Estimate24h = 0,
        [Parameter(Mandatory = $false)]
        [Double]$Difficulty = 0.0,
        [Parameter(Mandatory = $false)]
        [Double]$Ratio = 0.0,
        [Parameter(Mandatory = $false)]
        [DateTime]$Updated = (Get-Date).ToUniversalTime(),
        [Parameter(Mandatory = $false)]
        [DateTime]$StartTime = (Get-Date).ToUniversalTime(),
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration, 
        [Parameter(Mandatory = $false)]
        [Bool]$FaultDetection = $false,
        [Parameter(Mandatory = $false)]
        [Bool]$ChangeDetection = $false,
        [Parameter(Mandatory = $false)]
        [Double]$FaultTolerance = 0.1,
        [Parameter(Mandatory = $false)]
        [Double]$PowerDraw = 0,
        [Parameter(Mandatory = $false)]
        [Double]$HashRate = 0,
        [Parameter(Mandatory = $false)]
        [Double]$BlockRate = 0,
        [Parameter(Mandatory = $false)]
        [Double]$UplimProtection = 0,
        [Parameter(Mandatory = $false)]
        [String]$Sub = "",
        [Parameter(Mandatory = $false)]
        [String]$Version = "",
        [Parameter(Mandatory = $false)]
        [String]$LogFile = "",
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$IsFastlaneValue = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Reset = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$ResetIfZero = $false
    )

    $Updated = $Updated.ToUniversalTime()

    $Mode     = ""
    $LogLevel = if ($Quiet) {"Info"} else {"Warn"}
    $Cached   = $true
    $Check    = "Minute"

    if ($Name -match '_Profit$')       {
        $Path0 = "Stats\Pools";    $Mode = "Pools"
        if ($Actual24h -gt 0 -and $Estimate24h -gt 0 -and ($Estimate24h / $Actual24h) -gt 1000) {
            $Estimate24h = $Actual24h
        }
    }
    elseif ($Name -match '_Hashrate$') {$Path0 = "Stats\Miners";   $Mode = "Miners"}
    else                               {$Path0 = "Stats";          $Mode = "Profit"; $Cached = $false; $Check = ""}

    $Path = if ($Sub) {"$Path0\$Sub-$Name.txt"} else {"$Path0\$Name.txt"}

    $SmallestValue = 1E-20


    if (-not $Reset -and ($Stat = Get-StatFromFile -Path $Path -Name $Name -Cached:$Cached -Check $Check)) {
        try {
            if ($Mode -in @("Pools","Profit") -and $Stat.Week_Fluctuation -and [Double]$Stat.Week_Fluctuation -ge 0.8) {throw "Fluctuation out of range"}

            if ($Mode -eq "Miners") {
                $Benchmarked = if ($Stat.Benchmarked -ne $null) {$Stat.Benchmarked} else {[DateTime]$Stat.Updated - [TimeSpan]$Stat.Duration}
            }

            $Stat = Switch ($Mode) {
                "Miners" {
                    [PSCustomObject]@{
                        Live = [Double]$Stat.Live
                        Minute = [Double]$Stat.Minute
                        Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
                        Minute_5 = [Double]$Stat.Minute_5
                        Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
                        Minute_10 = [Double]$Stat.Minute_10
                        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                        Hour = [Double]$Stat.Hour
                        Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
                        Day = [Double]$Stat.Day
                        Day_Fluctuation = [Double]$Stat.Day_Fluctuation
                        ThreeDay = [Double]$Stat.ThreeDay
                        ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                        Week = [Double]$Stat.Week
                        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                        Duration = [TimeSpan]$Stat.Duration
                        Updated = [DateTime]$Stat.Updated
                        Failed = [Int]$Stat.Failed

                        # Miners Part
                        PowerDraw_Live     = [Double]$Stat.PowerDraw_Live
                        PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                        Diff_Live          = [Double]$Stat.Diff_Live
                        Diff_Average       = [Double]$Stat.Diff_Average
                        Ratio_Live         = [Double]$Stat.Ratio_Live
                        Benchmarked        = $Benchmarked
                        Version            = $Version
                        LogFile            = $LogFile
                        IsFL               = [Bool]$Stat.IsFL
                        #Ratio_Average      = [Double]$Stat.Ratio_Average
                    }
                    Break
                }
                "Pools" {
                    [PSCustomObject]@{
                        Live = [Double]$Stat.Live
                        Minute = [Double]$Stat.Minute
                        Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
                        Minute_5 = [Double]$Stat.Minute_5
                        Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
                        Minute_10 = [Double]$Stat.Minute_10
                        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                        Hour = [Double]$Stat.Hour
                        Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
                        Day = [Double]$Stat.Day
                        Day_Fluctuation = [Double]$Stat.Day_Fluctuation
                        ThreeDay = [Double]$Stat.ThreeDay
                        ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                        Week = [Double]$Stat.Week
                        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                        Duration = [TimeSpan]$Stat.Duration
                        Updated = [DateTime]$Stat.Updated
                        Failed = [Int]$Stat.Failed

                        # Pools part
                        HashRate_Live      = [Double]$Stat.HashRate_Live
                        HashRate_Average   = [Double]$Stat.HashRate_Average
                        BlockRate_Live     = [Double]$Stat.BlockRate_Live
                        BlockRate_Average  = [Double]$Stat.BlockRate_Average
                        Diff_Live          = [Double]$Stat.Diff_Live
                        Diff_Average       = [Double]$Stat.Diff_Average
                        Actual24h_Week     = [Double]$Stat.Actual24h_Week
                        Estimate24h_Week   = [Double]$Stat.Estimate24h_Week
                        ErrorRatio         = [Double]$Stat.ErrorRatio
                    }
                    Break
                }
                default {
                    [PSCustomObject]@{
                        Live = [Double]$Stat.Live
                        Minute = [Double]$Stat.Minute
                        Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
                        Minute_5 = [Double]$Stat.Minute_5
                        Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
                        Minute_10 = [Double]$Stat.Minute_10
                        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                        Hour = [Double]$Stat.Hour
                        Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
                        Day = [Double]$Stat.Day
                        Day_Fluctuation = [Double]$Stat.Day_Fluctuation
                        ThreeDay = [Double]$Stat.ThreeDay
                        ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                        Week = [Double]$Stat.Week
                        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                        Duration = [TimeSpan]$Stat.Duration
                        Updated = [DateTime]$Stat.Updated
                        Failed = [Int]$Stat.Failed

                        # Profit Part
                        PowerDraw_Live     = [Double]$Stat.PowerDraw_Live
                        PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                    }
                }
            }

            if ($ResetIfZero -and -not $Stat.Live) {throw}

            $ToleranceMin = $Value
            $ToleranceMax = $Value

            if ($FaultDetection) {
                if ($FaultTolerance -eq $null) {$FaultTolerance = 0.1}
                if ($FaultTolerance -lt 1) {
                    $ToleranceMin = $Stat.Week * (1 - [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance + $Stat.Failed/100), 0.9))
                    $ToleranceMax = $Stat.Week * (1 + [Math]::Min([Math]::Max($Stat.Week_Fluctuation * 2, $FaultTolerance + [Math]::Max($Stat.Failed * 3,10)/100), 2))
                } elseif ($Stat.Hour -gt 0) {
                    if ($FaultTolerance -lt 2) {$FaultTolerance = 2}
                    $ToleranceMin = $Stat.Hour / $FaultTolerance
                    $ToleranceMax = $Stat.Hour * $FaultTolerance
                }
            } elseif ($Stat.Hour -gt 0 -and $UplimProtection -gt 1.0) {            
                $ToleranceMax = $Stat.Hour * $UplimProtection
            }

            if ($ChangeDetection -and [Decimal]$Value -eq [Decimal]$Stat.Live -and ($Mode -ne "Pools" -or [Decimal]$Hashrate -eq [Decimal]$Stat.HashRate_Live)) {$Updated = $Stat.Updated}
        
            if ($Value -gt 0 -and $ToleranceMax -eq 0) {$ToleranceMax = $Value}

            if ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax) {
                $StatResetValue = $null

                $Stat.Failed += 10
                
                if ($Stat.Failed -ge 30) {
                    $Stat.Failed = 30

                    if ($mode -eq "Miners" -and $Stat.IsFL) {
                        $StatResetValue  = $Stat.Value
                        $IsFastlaneValue = $false
                        $Stat = $null
                    }
                }

                if (-not $Quiet) {
                    if ($mode -eq "Miners") {
                        if ($StatResetValue -ne $null) {
                            Write-Log -Level $LogLevel "Stat file ($Name) will be reset, because fastlane benchmark value $($StatResetValue | ConvertTo-Hash) is too far off of $($Value | ConvertTo-Hash). "
                        } else {
                            Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value | ConvertTo-Hash) is outside fault tolerance $($ToleranceMin | ConvertTo-Hash) to $($ToleranceMax | ConvertTo-Hash). "
                        }
                    } 
                    elseif ($UplimProtection -gt 1.0) {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString()) is at least $($UplimProtection.ToString()) times above the hourly average. "}
                    else {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString()) is outside fault tolerance $($ToleranceMin.ToString()) to $($ToleranceMax.ToString()). "}
                }

            } else {
                $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
                $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
                $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
                $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
                $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
                $Span_ThreeDay = [Math]::Min(($Duration.TotalDays / 3) / [Math]::Min(($Stat.Duration.TotalDays / 3), 1), 1)
                $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

                $Stat = Switch ($Mode) {
                    "Miners" {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)

                            # Miners part
                            PowerDraw_Live     = $PowerDraw
                            PowerDraw_Average  = if ($Stat.PowerDraw_Average -gt 0) {$Stat.PowerDraw_Average + $Span_Week * ($PowerDraw - $Stat.PowerDraw_Average)} else {$PowerDraw}
                            Diff_Live          = $Difficulty
                            Diff_Average       = $Stat.Diff_Average + $Span_Hour * ($Difficulty - $Stat.Diff_Average)
                            Ratio_Live         = $Ratio
                            Benchmarked        = $Benchmarked
                            Version            = $Version
                            LogFile            = $LogFile
                            IsFL               = $false
                            #Ratio_Average      = if ($Stat.Ratio_Average -gt 0) {[Math]::Round($Stat.Ratio_Average - $Span_Hour * ($Ratio - $Stat.Ratio_Average),4)} else {$Ratio}
                        }
                        Break
                    }
                    "Pools" {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)

                            # Pools part
                            HashRate_Live      = $HashRate
                            HashRate_Average   = if ($Stat.HashRate_Average -gt 0) {$Stat.HashRate_Average + $Span_Hour * ($HashRate - $Stat.HashRate_Average)} else {$HashRate}
                            BlockRate_Live     = $BlockRate
                            BlockRate_Average  = if ($Stat.BlockRate_Average -gt 0) {$Stat.BlockRate_Average + $Span_Hour * ($BlockRate - $Stat.BlockRate_Average)} else {$BlockRate}
                            Diff_Live          = $Difficulty
                            Diff_Average       = $Stat.Diff_Average + $Span_Hour * ($Difficulty - $Stat.Diff_Average)
                            Actual24h_Week     = $Stat.Actual24h_Week + $Span_Day * ($Actual24h - $Stat.Actual24h_Week)
                            Estimate24h_Week   = $Stat.Estimate24h_Week + $Span_Day * ($Estimate24h - $Stat.Estimate24h_Week)
                            ErrorRatio         = $Stat.ErrorRatio
                        }
                        Break
                    }
                    default {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)

                            # Profit part
                            PowerDraw_Live     = $PowerDraw
                            PowerDraw_Average  = if ($Stat.PowerDraw_Average -gt 0) {$Stat.PowerDraw_Average + $Span_Day * ($PowerDraw - $Stat.PowerDraw_Average)} else {$PowerDraw}
                        }
                    }
                }
                $Stat.PSObject.Properties.Name | Where-Object {$_ -match "Fluctuation" -and $Stat.$_ -gt 1} | Foreach-Object {$Stat.$_ = 0}
            }
        }
        catch {
            if (-not $Quiet -and (Test-Path $Path)) {Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. "}
            $Stat = $null
        }
    }

    if (-not $Stat) {
        $Stat = Switch($Mode) {
            "Miners" {
                [PSCustomObject]@{
                    Live = $Value
                    Minute = $Value
                    Minute_Fluctuation = 0
                    Minute_5 = $Value
                    Minute_5_Fluctuation = 0
                    Minute_10 = $Value
                    Minute_10_Fluctuation = 0
                    Hour = $Value
                    Hour_Fluctuation = 0
                    Day = $Value
                    Day_Fluctuation = 0
                    ThreeDay = $Value
                    ThreeDay_Fluctuation = 0
                    Week = $Value
                    Week_Fluctuation = 0
                    Duration = $Duration
                    Updated = $Updated
                    Failed = 0

                    # Miners part
                    PowerDraw_Live     = $PowerDraw
                    PowerDraw_Average  = $PowerDraw
                    Diff_Live          = $Difficulty
                    Diff_Average       = $Difficulty
                    Ratio_Live         = $Ratio
                    Benchmarked        = $StartTime
                    Version            = $Version
                    LogFile            = $LogFile
                    IsFL               = $IsFastlaneValue
                    #Ratio_Average      = $Ratio
                }
                Break
            }
            "Pools" {
                [PSCustomObject]@{
                    Live = $Value
                    Minute = $Value
                    Minute_Fluctuation = 0
                    Minute_5 = $Value
                    Minute_5_Fluctuation = 0
                    Minute_10 = $Value
                    Minute_10_Fluctuation = 0
                    Hour = $Value
                    Hour_Fluctuation = 0
                    Day = $Value
                    Day_Fluctuation = 0
                    ThreeDay = $Value
                    ThreeDay_Fluctuation = 0
                    Week = $Value
                    Week_Fluctuation = 0
                    Duration = $Duration
                    Updated = $Updated
                    Failed = 0

                    # Pools part
                    HashRate_Live      = $HashRate
                    HashRate_Average   = $HashRate
                    BlockRate_Live     = $BlockRate
                    BlockRate_Average  = $BlockRate
                    Diff_Live          = $Difficulty
                    Diff_Average       = $Difficulty
                    Actual24h_Week     = 0
                    Estimate24h_Week   = 0
                    ErrorRatio         = 0
                }
                Break
            }
            default {
                [PSCustomObject]@{
                    Live = $Value
                    Minute = $Value
                    Minute_Fluctuation = 0
                    Minute_5 = $Value
                    Minute_5_Fluctuation = 0
                    Minute_10 = $Value
                    Minute_10_Fluctuation = 0
                    Hour = $Value
                    Hour_Fluctuation = 0
                    Day = $Value
                    Day_Fluctuation = 0
                    ThreeDay = $Value
                    ThreeDay_Fluctuation = 0
                    Week = $Value
                    Week_Fluctuation = 0
                    Duration = $Duration
                    Updated = $Updated
                    Failed = 0

                    # Profit part
                    PowerDraw_Live     = $PowerDraw
                    PowerDraw_Average  = $PowerDraw
                }
            }
        }
    }

    if ($Mode -eq "Pools") {
        $Stat.ErrorRatio = [Math]::Min(1+$(if ($Stat.Estimate24h_Week) {($Stat.Actual24h_Week/$Stat.Estimate24h_Week-1) * $(if ($Stat.Duration.TotalDays -lt 7) {$Stat.Duration.TotalDays/7*(2 - $Stat.Duration.TotalDays/7)} else {1})}),[Math]::Max($Stat.Duration.TotalDays,1))
        if ($Session.Config.MaxErrorRatio -and $Stat.ErrorRatio -gt $Session.Config.MaxErrorRatio) {
            $Stat.ErrorRatio = $Session.Config.MaxErrorRatio
        }
    }

    if (-not (Test-Path $Path0)) {New-Item $Path0 -ItemType "directory" > $null}

    if ($Stat.Duration -ne 0) {
        $(Switch($Mode) {
            "Miners" {
                [PSCustomObject]@{
                    Live = [Decimal]$Stat.Live
                    Minute = [Decimal]$Stat.Minute
                    Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
                    Minute_5 = [Decimal]$Stat.Minute_5
                    Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
                    Minute_10 = [Decimal]$Stat.Minute_10
                    Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                    Hour = [Decimal]$Stat.Hour
                    Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
                    Day = [Decimal]$Stat.Day
                    Day_Fluctuation = [Double]$Stat.Day_Fluctuation
                    ThreeDay = [Decimal]$Stat.ThreeDay
                    ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                    Week = [Decimal]$Stat.Week
                    Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                    Duration = [String]$Stat.Duration
                    Updated = [DateTime]$Stat.Updated
                    Failed = [Int]$Stat.Failed

                    # Miners part
                    PowerDraw_Live     = [Decimal]$Stat.PowerDraw_Live
                    PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                    Diff_Live          = [Double]$Stat.Diff_Live
                    Diff_Average       = [Double]$Stat.Diff_Average
                    Ratio_Live         = [Double]$Stat.Ratio_Live
                    Benchmarked        = [DateTime]$Stat.Benchmarked
                    Version            = [String]$Stat.Version
                    LogFile            = [String]$Stat.LogFile
                    IsFL               = [Bool]$Stat.IsFL
                    #Ratio_Average      = [Double]$Stat.Ratio_Average
                }
                Break
            }
            "Pools" {
                [PSCustomObject]@{
                    Live = [Decimal]$Stat.Live
                    Minute = [Decimal]$Stat.Minute
                    Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
                    Minute_5 = [Decimal]$Stat.Minute_5
                    Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
                    Minute_10 = [Decimal]$Stat.Minute_10
                    Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                    Hour = [Decimal]$Stat.Hour
                    Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
                    Day = [Decimal]$Stat.Day
                    Day_Fluctuation = [Double]$Stat.Day_Fluctuation
                    ThreeDay = [Decimal]$Stat.ThreeDay
                    ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                    Week = [Decimal]$Stat.Week
                    Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                    Duration = [String]$Stat.Duration
                    Updated = [DateTime]$Stat.Updated
                    Failed = [Int]$Stat.Failed

                    # Pools part
                    HashRate_Live      = [Decimal]$Stat.HashRate_Live
                    HashRate_Average   = [Double]$Stat.HashRate_Average
                    BlockRate_Live     = [Decimal]$Stat.BlockRate_Live
                    BlockRate_Average  = [Double]$Stat.BlockRate_Average
                    Diff_Live          = [Double]$Stat.Diff_Live
                    Diff_Average       = [Double]$Stat.Diff_Average
                    Actual24h_Week     = [Decimal]$Stat.Actual24h_Week
                    Estimate24h_Week   = [Decimal]$Stat.Estimate24h_Week
                    ErrorRatio         = [Decimal]$Stat.ErrorRatio
                }
                Break
            }
            default {
                [PSCustomObject]@{
                    Live = [Decimal]$Stat.Live
                    Minute = [Decimal]$Stat.Minute
                    Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
                    Minute_5 = [Decimal]$Stat.Minute_5
                    Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
                    Minute_10 = [Decimal]$Stat.Minute_10
                    Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
                    Hour = [Decimal]$Stat.Hour
                    Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
                    Day = [Decimal]$Stat.Day
                    Day_Fluctuation = [Double]$Stat.Day_Fluctuation
                    ThreeDay = [Decimal]$Stat.ThreeDay
                    ThreeDay_Fluctuation = [Double]$Stat.ThreeDay_Fluctuation
                    Week = [Decimal]$Stat.Week
                    Week_Fluctuation = [Double]$Stat.Week_Fluctuation
                    Duration = [String]$Stat.Duration
                    Updated = [DateTime]$Stat.Updated
                    Failed = [Int]$Stat.Failed

                    # Profit part
                    PowerDraw_Live     = [Decimal]$Stat.PowerDraw_Live
                    PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                }
            }
        }) | ConvertTo-Json -Depth 10 | Set-Content $Path
    }

    if ($Cached) {$Global:StatsCache[$Name] = $Stat}

    $Stat
}

function Get-StatFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [Switch]$Cached = $false,
        [Parameter(Mandatory = $false)]
        [String]$Check = ""
    )

    if ($Cached -and $Check -ne "" -and $Global:StatsCache[$Name] -ne $null -and $Global:StatsCache[$Name].$Check -isnot [decimal] -and $Global:StatsCache[$Name].$Check -isnot [double]) {
        if ($Global:StatsCache[$Name].$Check -notmatch "^[0-9E\-\+\.]+$") {
            $Global:StatsCache[$Name] = $null
        }
    }

    if (-not $Cached -or $Global:StatsCache[$Name] -eq $null -or -not (Test-Path $Path)) {
        try {
            $Stat = ConvertFrom-Json "$(Get-ContentByStreamReader $Path)" -ErrorAction Stop
            if ($Cached) {
                if ($Stat) {
                    $Global:StatsCache[$Name] = $Stat
                } else {
                    $RemoveKey = $true
                }
            }
        } catch {
            if (Test-Path $Path) {
                Write-Log -Level Warn "Stat file ($([IO.Path]::GetFileName($Path)) is corrupt and will be removed. "
                Remove-Item -Path $Path -Force -Confirm:$false
            }
            if ($Cached) {$RemoveKey = $true}
        }
        if ($RemoveKey) {
            if ($Global:StatsCache.ContainsKey($Name)) {
                [void]$Global:StatsCache.Remove($Name)
            }
        }
    }

    if ($Cached) {
        $Global:StatsCache[$Name]
    } else {
        $Stat
    }
}

function Get-Stat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [String]$Sub = "",
        [Parameter(Mandatory = $false)]
        [Switch]$Pools = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Miners = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Disabled = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Totals = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$TotalAvgs = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Balances = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Poolstats = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$All = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet = $false
    )

    $Cached = $false

    if ($Name) {
        # Return single requested stat
        $Check = ""
        if ($Name -match '_Profit$') {$Path = "Stats\Pools"; $Cached = $true; $Check = "Minute"}
        elseif ($Name -match '_Hashrate$') {$Path = "Stats\Miners"; $Cached = $true; $Check = "Minute"}
        elseif ($Name -match '_(Total|TotalAvg)$') {$Path = "Stats\Totals"}
        elseif ($Name -match '_Balance$') {$Path = "Stats\Balances"}
        elseif ($Name -match '_Poolstats$') {$Path = "Stats\Pools"}
        else {$Path = "Stats"}

        if (-not (Test-Path $Path)) {New-Item $Path -ItemType "directory" > $null}

        if ($Sub) {
            $Path = "$Path\$Sub-$Name.txt"
        } else {
            $Path = "$Path\$Name.txt"
        }

        Get-StatFromFile -Path $Path -Name $Name -Cached:$Cached -Check $Check
    } else {
        # Return all stats
        [hashtable]$NewStats = @{}

        if (($Miners -or $All) -and -not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        if (($Disabled -or $All) -and -not (Test-Path "Stats\Disabled")) {New-Item "Stats\Disabled" -ItemType "directory" > $null}
        if (($Pools -or $Poolstats -or $All) -and -not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (($Totals -or $TotalAvgs -or $All) -and -not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}
        if (($Balances -or $All) -and -not (Test-Path "Stats\Balances")) {New-Item "Stats\Balances" -ItemType "directory" > $null}

        $Check = ""

        [System.Collections.Generic.List[string]]$MatchArray = @()
        if ($Miners)    {[void]$MatchArray.Add("Hashrate");$Path = "Stats\Miners";$Cached = $true; $Check = "Minute"}
        if ($Disabled)  {[void]$MatchArray.Add("Hashrate|Profit");$Path = "Stats\Disabled"}
        if ($Pools)     {[void]$MatchArray.Add("Profit");$Path = "Stats\Pools"; $Cached = $true; $Check = "Minute"}
        if ($Poolstats) {[void]$MatchArray.Add("Poolstats");$Path = "Stats\Pools"}
        if ($Totals)    {[void]$MatchArray.Add("Total");$Path = "Stats\Totals"}
        if ($TotalAvgs) {[void]$MatchArray.Add("TotalAvg");$Path = "Stats\Totals"}
        if ($Balances)  {[void]$MatchArray.Add("Balance");$Path = "Stats\Balances"}
        if (-not $Path -or $All -or $MatchArray.Count -gt 1) {$Path = "Stats"; $Cached = $false}

        $MatchStr = if ($MatchArray.Count -gt 1) {$MatchArray -join "|"} else {$MatchArray}
        if ($MatchStr -match "|") {$MatchStr = "($MatchStr)"}

        foreach($p in (Get-ChildItem -Recurse $Path -File -Filter "*.txt")) {
            $BaseName = $p.BaseName
            $FullName = $p.FullName
            if (-not $All -and $BaseName -notmatch "_$MatchStr$") {continue}

            $NewStatsKey = $BaseName -replace "^(AMD|CPU|INTEL|NVIDIA)-"

            if ($Stat = Get-StatFromFile -Path $FullName -Name $NewStatsKey -Cached:$Cached -Check $Check) {
                $NewStats[$NewStatsKey] = $Stat
            }
        }
        if ($Cached) {
            $RemoveKeys = (Compare-Object @($NewStats.Keys | Select-Object) @($Global:StatsCache.Keys | Where {$_ -match "_$MatchStr$"} | Select-Object)) | Where-Object {$_.SideIndicator -eq "=>"} | Foreach-Object {$_.InputObject}
            $RemoveKeys | Foreach-Object {[void]$Global:StatsCache.Remove($_)}
        }
        if (-not $Quiet) {$NewStats}
    }
}