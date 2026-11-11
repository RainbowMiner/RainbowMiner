#
# Stat functions
#

$Script:StatFluctuationFields = @("Minute_Fluctuation","Minute_5_Fluctuation","Minute_10_Fluctuation","Hour_Fluctuation","Day_Fluctuation","ThreeDay_Fluctuation","Week_Fluctuation")
$Script:StatDirsChecked = @{}
$Script:Utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($false)
# last Get-Stat -Miners pass: folder write time (changes on file add/remove) and device names
$Script:MinerStatsStamp = $null

function Test-StatDir {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Dir
    )
    if (-not $Script:StatDirsChecked.ContainsKey($Dir)) {
        if (-not (Test-Path $Dir)) {New-Item $Dir -ItemType "directory" > $null}
        $Script:StatDirsChecked[$Dir] = $true
    }
}

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
        [String]$DeviceModel = "",
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
            if ($Mode -eq "Miners") {
                $Benchmarked = if ($Stat.Benchmarked -ne $null) {$Stat.Benchmarked} else {[DateTime]$Stat.Updated - [TimeSpan]$Stat.Duration}
            }

            $Stat = Switch ($Mode) {
                "Miners" {
                    [RBMMinerStat]@{
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
                        Failed_Value       = [Double]$Stat.Failed_Value
                        Failed_Streak      = [Int]$Stat.Failed_Streak
                        DeviceModel        = [String]$Stat.DeviceModel
                        #Ratio_Average      = [Double]$Stat.Ratio_Average
                    }
                    Break
                }
                "Pools" {
                    [RBMPoolStat]@{
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
                        Deviation_Streak   = [Int]$Stat.Deviation_Streak
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
                        Failed_Value = [Double]$Stat.Failed_Value
                        Failed_Streak = [Int]$Stat.Failed_Streak
                        Deviation_Streak = [Int]$Stat.Deviation_Streak

                        # Profit Part
                        PowerDraw_Live     = [Double]$Stat.PowerDraw_Live
                        PowerDraw_Average  = [Double]$Stat.PowerDraw_Average
                    }
                }
            }

            if ($Mode -in @("Pools","Profit")) {
                # restart the history if it fluctuates too much (stats older than an hour only, a young one would reset
                # again and again) or if it stayed off the long average by more than 5x for 15 rounds (a new price level)
                if ([Double]$Stat.Week_Fluctuation -ge 0.8 -and $Stat.Duration -ge [TimeSpan]::FromHours(1)) {throw "Fluctuation out of range ($Name)"}
                if ([Int]$Stat.Deviation_Streak -ge 15) {throw "Deviation out of range ($Name)"}
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

            $StatRejected   = ($Value -lt $ToleranceMin -or $Value -gt $ToleranceMax)
            $StatKeepStreak = $false

            if ($StatRejected -and $mode -eq "Profit" -and $UplimProtection -gt 1.0 -and $Value -gt 0) {
                # spike protection self-heal: a level that holds for three rounds is real and accepted without a reset,
                # so the stat keeps its age for the MiningRigRentals price reference
                $StatRejectMatch    = $Stat.Failed_Value -gt 0 -and [Math]::Abs($Value / $Stat.Failed_Value - 1) -le 0.5
                $Stat.Failed_Streak = if ($StatRejectMatch) {$Stat.Failed_Streak + 1} else {1}
                $Stat.Failed_Value  = $Value
                if ($Stat.Failed_Streak -ge 3) {
                    if (-not $Quiet) {Write-Log -Level $LogLevel "Stat file ($Name) accepts the value $($Value.ToString()), it held for $($Stat.Failed_Streak) rounds above the spike protection. "}
                    $StatRejected   = $false
                    $StatKeepStreak = $true
                }
            }

            if ($StatRejected) {
                $StatResetValue  = $null
                $StatResetStreak = $null

                $Stat.Failed += 10

                if ($Stat.Failed -ge 30) {
                    $Stat.Failed = 30

                    if ($mode -eq "Miners" -and $Stat.IsFL) {
                        $StatResetValue  = $Stat.Week
                        $IsFastlaneValue = $false
                        $Stat = $null
                    }
                }

                if ($Stat -and $mode -eq "Miners" -and $Value -gt 0) {
                    # self-heal for a wrong or stale stat: three rejected samples in a row that agree with each other
                    # restart the stat from the current sample (a single off sample or a zero cannot)
                    $StatRejectMatch = $false
                    if ($Stat.Failed_Value -gt 0) {
                        if ($FaultTolerance -lt 1) {
                            $StatRejectMatch = [Math]::Abs($Value / $Stat.Failed_Value - 1) -le [Math]::Min(2 * [Math]::Max($FaultTolerance, 0.1), 0.5)
                        } else {
                            $StatRejectFactor = [Math]::Max($FaultTolerance, 2)
                            $StatRejectMatch  = ($Value -ge $Stat.Failed_Value / $StatRejectFactor) -and ($Value -le $Stat.Failed_Value * $StatRejectFactor)
                        }
                    }
                    $Stat.Failed_Streak = if ($StatRejectMatch) {$Stat.Failed_Streak + 1} else {1}
                    $Stat.Failed_Value  = $Value
                    if ($Stat.Failed_Streak -ge 3) {
                        $StatResetValue  = $Stat.Week
                        $StatResetStreak = $Stat.Failed_Streak
                        $IsFastlaneValue = $false
                        $Stat = $null
                    }
                }

                if (-not $Quiet) {
                    if ($mode -eq "Miners") {
                        if ($StatResetStreak) {
                            Write-Log -Level $LogLevel "Stat file ($Name) will be reset, because the stored value $($StatResetValue | ConvertTo-Hash) is too far off of the last $($StatResetStreak) measured values (now $($Value | ConvertTo-Hash)). "
                        } elseif ($StatResetValue -ne $null) {
                            Write-Log -Level $LogLevel "Stat file ($Name) will be reset, because the seeded value $($StatResetValue | ConvertTo-Hash) (fastlane or derived from another device set) is too far off of $($Value | ConvertTo-Hash). "
                        } else {
                            Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value | ConvertTo-Hash) is outside fault tolerance $($ToleranceMin | ConvertTo-Hash) to $($ToleranceMax | ConvertTo-Hash). "
                        }
                    } 
                    elseif ($UplimProtection -gt 1.0) {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString()) is at least $($UplimProtection.ToString()) times above the hourly average. "}
                    else {Write-Log -Level $LogLevel "Stat file ($Name) was not updated because the value $($Value.ToString()) is outside fault tolerance $($ToleranceMin.ToString()) to $($ToleranceMax.ToString()). "}
                }

            } else {
                # rounds off the long average by more than 5x (pool and profit stats, zeros excluded), see the throw above
                $StatDeviationStreak = 0
                if ($Mode -ne "Miners" -and $Value -gt 0 -and $Stat.Week -gt 0) {
                    $StatRatio = $Value / $Stat.Week
                    if ($StatRatio -gt 5 -or $StatRatio -lt 0.2) {$StatDeviationStreak = [Int]$Stat.Deviation_Streak + 1}
                }

                $Span_Minute = [Math]::Min($Duration.TotalMinutes / [Math]::Min($Stat.Duration.TotalMinutes, 1), 1)
                $Span_Minute_5 = [Math]::Min(($Duration.TotalMinutes / 5) / [Math]::Min(($Stat.Duration.TotalMinutes / 5), 1), 1)
                $Span_Minute_10 = [Math]::Min(($Duration.TotalMinutes / 10) / [Math]::Min(($Stat.Duration.TotalMinutes / 10), 1), 1)
                $Span_Hour = [Math]::Min($Duration.TotalHours / [Math]::Min($Stat.Duration.TotalHours, 1), 1)
                $Span_Day = [Math]::Min($Duration.TotalDays / [Math]::Min($Stat.Duration.TotalDays, 1), 1)
                $Span_ThreeDay = [Math]::Min(($Duration.TotalDays / 3) / [Math]::Min(($Stat.Duration.TotalDays / 3), 1), 1)
                $Span_Week = [Math]::Min(($Duration.TotalDays / 7) / [Math]::Min(($Stat.Duration.TotalDays / 7), 1), 1)

                $Stat = Switch ($Mode) {
                    "Miners" {
                        [RBMMinerStat]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Min([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue), 1) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Min([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue), 1) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Min([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue), 1) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Min([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue), 1) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Min([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue), 1) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Min([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue), 1) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Min([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue), 1) - $Stat.Week_Fluctuation)
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
                            Failed_Value       = 0
                            Failed_Streak      = 0
                            # only an accepted sample stamps the model: a rejected one leaves a stale value unconfirmed
                            DeviceModel        = if ($DeviceModel) {$DeviceModel} else {$Stat.DeviceModel}
                            #Ratio_Average      = if ($Stat.Ratio_Average -gt 0) {[Math]::Round($Stat.Ratio_Average - $Span_Hour * ($Ratio - $Stat.Ratio_Average),4)} else {$Ratio}
                        }
                        Break
                    }
                    "Pools" {
                        [RBMPoolStat]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Min([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue), 1) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Min([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue), 1) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Min([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue), 1) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Min([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue), 1) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Min([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue), 1) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Min([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue), 1) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Min([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue), 1) - $Stat.Week_Fluctuation)
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
                            Deviation_Streak   = $StatDeviationStreak
                        }
                        Break
                    }
                    default {
                        [PSCustomObject]@{
                            Live = $Value
                            Minute = $Stat.Minute + $Span_Minute * ($Value - $Stat.Minute)
                            Minute_Fluctuation = $Stat.Minute_Fluctuation + $Span_Minute * ([Math]::Min([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue), 1) - $Stat.Minute_Fluctuation)
                            Minute_5 = $Stat.Minute_5 + $Span_Minute_5 * ($Value - $Stat.Minute_5)
                            Minute_5_Fluctuation = $Stat.Minute_5_Fluctuation + $Span_Minute_5 * ([Math]::Min([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue), 1) - $Stat.Minute_5_Fluctuation)
                            Minute_10 = $Stat.Minute_10 + $Span_Minute_10 * ($Value - $Stat.Minute_10)
                            Minute_10_Fluctuation = $Stat.Minute_10_Fluctuation + $Span_Minute_10 * ([Math]::Min([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue), 1) - $Stat.Minute_10_Fluctuation)
                            Hour = $Stat.Hour + $Span_Hour * ($Value - $Stat.Hour)
                            Hour_Fluctuation = $Stat.Hour_Fluctuation + $Span_Hour * ([Math]::Min([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue), 1) - $Stat.Hour_Fluctuation)
                            Day = $Stat.Day + $Span_Day * ($Value - $Stat.Day)
                            Day_Fluctuation = $Stat.Day_Fluctuation + $Span_Day * ([Math]::Min([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue), 1) - $Stat.Day_Fluctuation)
                            ThreeDay = $Stat.ThreeDay + $Span_ThreeDay * ($Value - $Stat.ThreeDay)
                            ThreeDay_Fluctuation = $Stat.ThreeDay_Fluctuation + $Span_ThreeDay * ([Math]::Min([Math]::Abs($Value - $Stat.ThreeDay) / [Math]::Max([Math]::Abs($Stat.ThreeDay), $SmallestValue), 1) - $Stat.ThreeDay_Fluctuation)
                            Week = $Stat.Week + $Span_Week * ($Value - $Stat.Week)
                            Week_Fluctuation = $Stat.Week_Fluctuation + $Span_Week * ([Math]::Min([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue), 1) - $Stat.Week_Fluctuation)
                            Duration = $Stat.Duration + $Duration
                            Updated = $Updated
                            Failed = [Math]::Max($Stat.Failed-1,0)
                            Failed_Value = if ($StatKeepStreak) {$Stat.Failed_Value} else {0}
                            Failed_Streak = if ($StatKeepStreak) {$Stat.Failed_Streak} else {0}
                            Deviation_Streak = $StatDeviationStreak

                            # Profit part
                            PowerDraw_Live     = $PowerDraw
                            PowerDraw_Average  = if ($Stat.PowerDraw_Average -gt 0) {$Stat.PowerDraw_Average + $Span_Day * ($PowerDraw - $Stat.PowerDraw_Average)} else {$PowerDraw}
                        }
                    }
                }
                foreach ($fluct in $Script:StatFluctuationFields) {if ($Stat.$fluct -gt 1) {$Stat.$fluct = 0}}
            }
        }
        catch {
            if (-not $Quiet -and (Test-Path $Path)) {
                # the two deliberate resets above throw as well, give them their own words: "corrupt" is for files that really cannot be read
                if ("$($_.Exception.Message)" -match "^Fluctuation out of range") {
                    Write-Log -Level Warn "Stat file ($Name) will be reset, because its values fluctuate too much (week fluctuation $([Math]::Round([Double]$Stat.Week_Fluctuation * 100))%). "
                } elseif ("$($_.Exception.Message)" -match "^Deviation out of range") {
                    Write-Log -Level Warn "Stat file ($Name) will be reset, because its values stayed more than 5x off the average for $([Int]$Stat.Deviation_Streak) rounds. "
                } elseif ($ResetIfZero -and $Stat -and -not $Stat.Live) {
                    Write-Log -Level Warn "Stat file ($Name) will be reset, because its last value is zero. "
                } else {
                    Write-Log -Level Warn "Stat file ($Name) is corrupt and will be reset. "
                }
            }
            $Stat = $null
        }
    }

    if (-not $Stat) {
        $Stat = Switch($Mode) {
            "Miners" {
                [RBMMinerStat]@{
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
                    Failed_Value       = 0
                    Failed_Streak      = 0
                    DeviceModel        = $DeviceModel
                    #Ratio_Average      = $Ratio
                }
                Break
            }
            "Pools" {
                [RBMPoolStat]@{
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
                    Deviation_Streak   = 0
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
                    Failed_Value = 0
                    Failed_Streak = 0
                    Deviation_Streak = 0

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

    Test-StatDir $Path0

    if ($Stat.Duration -ne 0) {
        $OutStat = Switch($Mode) {
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
                    Failed_Value       = [Double]$Stat.Failed_Value
                    Failed_Streak      = [Int]$Stat.Failed_Streak
                    DeviceModel        = [String]$Stat.DeviceModel
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
                    Deviation_Streak   = [Int]$Stat.Deviation_Streak
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
                    Failed_Value       = [Double]$Stat.Failed_Value
                    Failed_Streak      = [Int]$Stat.Failed_Streak
                    Deviation_Streak   = [Int]$Stat.Deviation_Streak
                }
            }
        }
        try {
            [System.IO.File]::WriteAllText($Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path), (ConvertTo-Json $OutStat -Depth 10 -Compress), $Script:Utf8NoBomEncoding)
        } catch {
            Write-Log -Level $LogLevel "Could not write stat file ($Name): $($_.Exception.Message) "
        }
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

    if (-not $Cached -or $Global:StatsCache[$Name] -eq $null -or -not [System.IO.File]::Exists($Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))) {
        try {
            $Stat = ConvertFrom-Json "$(Get-ContentByStreamReader $Path)" -ErrorAction Stop
            if ($Stat -ne $null -and $Stat.PSObject.BaseObject -is [System.Management.Automation.PSCustomObject]) {
                if ($Cached -and $Name -match '_Hashrate$') {
                    # cached stats are typed objects (RBMToolBox.cs): ~400 bytes instead of ~4 KB as PSCustomObject
                    $Stat = [RBMMinerStat]::FromObject($Stat)
                } elseif ($Cached -and $Name -match '_Profit$') {
                    $Stat = [RBMPoolStat]::FromObject($Stat)
                } else {
                    # rebuild with interned property names, ConvertFrom-Json allocates fresh name strings per file
                    $StatInterned = [PSCustomObject]@{}
                    foreach ($StatProperty in $Stat.PSObject.Properties) {
                        $StatInterned.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new([string]::Intern($StatProperty.Name), $StatProperty.Value))
                    }
                    $Stat = $StatInterned
                }
            }
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

        Test-StatDir $Path

        if ($Sub) {
            $Path = "$Path\$Sub-$Name.txt"
        } else {
            $Path = "$Path\$Name.txt"
        }

        Get-StatFromFile -Path $Path -Name $Name -Cached:$Cached -Check $Check
    } else {
        # Return all stats
        [hashtable]$NewStats = @{}

        if ($Miners -or $All) {Test-StatDir "Stats\Miners"}
        if ($Disabled -or $All) {Test-StatDir "Stats\Disabled"}
        if ($Pools -or $Poolstats -or $All) {Test-StatDir "Stats\Pools"}
        if ($Totals -or $TotalAvgs -or $All) {Test-StatDir "Stats\Totals"}
        if ($Balances -or $All) {Test-StatDir "Stats\Balances"}

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

        # cache only miner stats whose devices are all detected (selected or not: the benchmark seeding in
        # Invoke-Core uses sibling sets as its source). Files stay untouched, a returning card gets its stats back
        $PresentDevices = $null
        if ($Miners -and $Cached -and (Test-Path Variable:Global:GlobalCachedDevices) -and $Global:GlobalCachedDevices) {
            $PresentDevices = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($Device in $Global:GlobalCachedDevices) {if ($Device.Name) {[void]$PresentDevices.Add($Device.Name)}}
            if (-not $PresentDevices.Count) {$PresentDevices = $null}
        }

        # skip the per-round (-Quiet) pass when folder and devices are unchanged. The stamp is armed only once
        # the folder has been quiet for a few seconds, coarse timestamps (ext3, FAT) could hide a later change
        if ($Miners -and $Cached -and $Quiet) {
            $Stamp = $null
            try {
                $StatsDirWrite = (Get-Item $Path -ErrorAction Stop).LastWriteTimeUtc
                if (((Get-Date).ToUniversalTime() - $StatsDirWrite).TotalSeconds -gt 3) {
                    $Stamp = "$($StatsDirWrite.Ticks)|$(if ($PresentDevices) {@($PresentDevices | Sort-Object) -join ","})"
                }
            } catch {}
            if ($Stamp -and $Stamp -eq $Script:MinerStatsStamp) {return}
            $Script:MinerStatsStamp = $Stamp
        }

        foreach($p in (Get-ChildItem -Recurse $Path -File -Filter "*.txt")) {
            $BaseName = $p.BaseName
            $FullName = $p.FullName
            if (-not $All -and $BaseName -notmatch "_$MatchStr$") {continue}

            $NewStatsKey = $BaseName -replace "^(AMD|CPU|INTEL|NVIDIA)-"

            if ($PresentDevices) {
                # the device names sit between the miner name and the first "_"
                $StatDevices = [regex]::Matches($NewStatsKey.Substring(0, [Math]::Max(0, $NewStatsKey.IndexOf("_"))), "(?:GPU|CPU)#\d+")
                $StatDeviceMissing = $false
                foreach ($StatDevice in $StatDevices) {
                    if (-not $PresentDevices.Contains($StatDevice.Value)) {$StatDeviceMissing = $true; break}
                }
                if ($StatDeviceMissing) {continue}
            }

            if ($Stat = Get-StatFromFile -Path $FullName -Name $NewStatsKey -Cached:$Cached -Check $Check) {
                $NewStats[$NewStatsKey] = $Stat
            }
        }
        if ($Cached) {
            foreach ($CacheKey in @($Global:StatsCache.Keys)) {
                if ($CacheKey -match "_$MatchStr$" -and -not $NewStats.ContainsKey($CacheKey)) {[void]$Global:StatsCache.Remove($CacheKey)}
            }
        }
        if (-not $Quiet) {$NewStats}
    }
}

function Initialize-ZipSupport {
    if (-not ("System.IO.Compression.ZipFile" -as [type])) {
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    }
}

function Get-MinerStatsBackupPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name = ""
    )
    $Path = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Stats\Backups")
    if ($Name -eq "") {
        if (-not [System.IO.Directory]::Exists($Path)) {[void][System.IO.Directory]::CreateDirectory($Path)}
        $Path
    } elseif ($Name -match "^minerstats_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}(_[a-z]+)?\.zip$") {
        # only names this module creates: no path parts can sneak in
        $Path = [System.IO.Path]::Combine($Path, $Name)
        if ([System.IO.File]::Exists($Path)) {$Path}
    }
}

function Get-MinerStatsBackups {
    $Path = Get-MinerStatsBackupPath
    foreach ($File in @([System.IO.Directory]::GetFiles($Path, "minerstats_*.zip") | Sort-Object -Descending)) {
        $Name = [System.IO.Path]::GetFileName($File)
        if ($Name -notmatch "^minerstats_(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})(?:_([a-z]+))?\.zip$") {continue}
        $Count = $null
        $Zip = $null
        try {
            Initialize-ZipSupport
            $Zip = [System.IO.Compression.ZipFile]::OpenRead($File)
            $Count = $Zip.Entries.Count
        } catch {
        } finally {
            if ($Zip) {$Zip.Dispose()}
        }
        [PSCustomObject]@{
            Name  = $Name
            Date  = "$($Matches[1]) $($Matches[2]):$($Matches[3]):$($Matches[4])"
            Tag   = "$($Matches[5])"
            Files = $Count
            Size  = ([System.IO.FileInfo]::new($File)).Length
        }
    }
}

function New-MinerStatsBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidatePattern("^[a-z]*$")]
        [String]$Tag = ""
    )

    Initialize-ZipSupport

    $StatsPath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Stats\Miners")
    $Files = @(if ([System.IO.Directory]::Exists($StatsPath)) {[System.IO.Directory]::GetFiles($StatsPath, "*.txt") | Where-Object {$_ -match "_HashRate\.txt$"}})
    if (-not $Files.Count) {throw "There are no miner stats to back up"}

    $Name    = "minerstats_$((Get-Date).ToString("yyyy-MM-dd_HH-mm-ss"))$(if ($Tag) {"_$Tag"}).zip"
    $ZipPath = [System.IO.Path]::Combine((Get-MinerStatsBackupPath), $Name)
    if ([System.IO.File]::Exists($ZipPath)) {throw "A backup with this time stamp exists already, please try again"}

    $Count = 0
    $Zip   = $null
    try {
        $Zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($File in $Files) {
            $Source = $null
            $Target = $null
            try {
                # share ReadWrite: Set-Stat may write a stat file at the same time
                $Source = [System.IO.File]::Open($File, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $Entry  = $Zip.CreateEntry([System.IO.Path]::GetFileName($File), [System.IO.Compression.CompressionLevel]::Optimal)
                $Entry.LastWriteTime = [System.IO.File]::GetLastWriteTime($File)
                $Target = $Entry.Open()
                $Source.CopyTo($Target)
                $Count++
            } catch {
                Write-Log -Level Warn "Miner stats backup: $([System.IO.Path]::GetFileName($File)) skipped: $($_.Exception.Message)"
            } finally {
                if ($Target) {$Target.Dispose()}
                if ($Source) {$Source.Dispose()}
            }
        }
    } finally {
        if ($Zip) {$Zip.Dispose()}
    }

    if (-not $Count) {
        [System.IO.File]::Delete($ZipPath)
        throw "No miner stats could be read"
    }

    Write-Log "Miner stats backup $Name created with $Count files"
    [PSCustomObject]@{Name = $Name; Files = $Count}
}

function Restore-MinerStatsBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [Parameter(Mandatory = $false)]
        [Switch]$OnlyMissing = $false
    )

    if (-not ($ZipPath = Get-MinerStatsBackupPath -Name $Name)) {throw "Backup $Name not found"}

    Initialize-ZipSupport

    $StatsPath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Stats\Miners")
    if (-not [System.IO.Directory]::Exists($StatsPath)) {[void][System.IO.Directory]::CreateDirectory($StatsPath)}

    $Zip = $null
    $Restored = [System.Collections.Generic.List[string]]::new()
    $Skipped = 0
    $Saved = $null
    try {
        $Zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

        # check the whole archive before anything is touched
        $Entries = @($Zip.Entries | Where-Object {$_.Length -gt 0})
        if (-not $Entries.Count) {throw "Backup $Name is empty"}
        if ($Entries | Where-Object {$_.FullName -notmatch "^[^\\/:]+_HashRate\.txt$" -or [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath([System.IO.Path]::Combine($StatsPath, $_.FullName))) -ne $StatsPath.TrimEnd('\','/')}) {throw "Backup $Name contains unexpected files, nothing restored"}

        # keep the current state, so that a restore can be undone
        if (@([System.IO.Directory]::GetFiles($StatsPath, "*.txt") | Where-Object {$_ -match "_HashRate\.txt$"}).Count) {
            $Saved = (New-MinerStatsBackup -Tag "beforerestore").Name
        }

        if (-not $OnlyMissing) {
            foreach ($File in @([System.IO.Directory]::GetFiles($StatsPath, "*.txt") | Where-Object {$_ -match "_HashRate\.txt$"})) {
                [System.IO.File]::Delete($File)
            }
        }

        foreach ($Entry in $Entries) {
            $Target = [System.IO.Path]::Combine($StatsPath, $Entry.FullName)
            # -OnlyMissing fills the gaps only, a stat that exists today is left as it is
            if ($OnlyMissing -and [System.IO.File]::Exists($Target)) {$Skipped++; continue}
            $Source = $null
            $Output = $null
            try {
                $Source = $Entry.Open()
                $Output = [System.IO.File]::Create($Target)
                $Source.CopyTo($Output)
            } finally {
                if ($Output) {$Output.Dispose()}
                if ($Source) {$Source.Dispose()}
            }
            # TouchBenchmark and the benchmark logic look at the file age
            [System.IO.File]::SetLastWriteTime($Target, $Entry.LastWriteTime.LocalDateTime)
            [void]$Restored.Add($Target)
        }
    } finally {
        if ($Zip) {$Zip.Dispose()}
    }

    # reload restored stats in place, dropping the cache would show all miners as unbenchmarked
    foreach ($Target in $Restored) {
        $Key = [System.IO.Path]::GetFileNameWithoutExtension($Target) -replace "^(AMD|CPU|INTEL|NVIDIA)-"
        if ($Global:StatsCache.ContainsKey($Key)) {[void]$Global:StatsCache.Remove($Key)}
        [void](Get-StatFromFile -Path $Target -Name $Key -Cached -Check "Minute")
    }

    if ($OnlyMissing) {
        Write-Log "Miner stats backup $Name restored $($Restored.Count) missing files, $Skipped existing kept$(if ($Saved) {", previous stats saved as $Saved"})"
    } else {
        Write-Log "Miner stats backup $Name restored with $($Restored.Count) files$(if ($Saved) {", previous stats saved as $Saved"})"
    }
    [PSCustomObject]@{Name = $Name; Files = $Restored.Count; Skipped = $Skipped; Saved = $Saved}
}

function Remove-MinerStatsBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name
    )
    if (-not ($ZipPath = Get-MinerStatsBackupPath -Name $Name)) {throw "Backup $Name not found"}
    [System.IO.File]::Delete($ZipPath)
    Write-Log "Miner stats backup $Name deleted"
}

function Update-MinerAlgorithmsInfo {
    # algorithms per miner module (from its InfoOnly command list) for Get-MinerStatsStale, stored in
    # Data\mineralgorithms.json and re-read when the module file changes. Modules without a list get no entry
    [CmdletBinding()]
    param()

    $Path = ".\Data\mineralgorithms.json"
    $Info = [hashtable]@{}
    if (Test-Path $Path) {
        try {
            (Get-ContentByStreamReader $Path | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | Foreach-Object {$Info[$_.Name] = $_.Value}
        } catch {
            $Info = [hashtable]@{}
        }
    }

    $Changed = $false
    $Avail = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Name in @($Session.AvailMiners | Where-Object {$_})) {[void]$Avail.Add($Name)}
    foreach ($Name in @($Info.Keys)) {
        if (-not $Avail.Contains($Name)) {[void]$Info.Remove($Name); $Changed = $true}
    }
    foreach ($Name in $Avail) {
        $File = Get-Item ".\Miners\$($Name).ps1" -ErrorAction Ignore
        if (-not $File) {continue}
        $Stamp = "$($File.LastWriteTimeUtc.Ticks)"
        if ($Info[$Name] -and "$($Info[$Name].Stamp)" -eq $Stamp) {continue}
        $Algorithms = @()
        try {
            $Algorithms = @(Get-MinersContent -MinerName $Name -Parameters @{InfoOnly = $true} | Foreach-Object {$_.Commands} | Where-Object {$_ -ne $null -and $_ -isnot [string] -and "$($_.MainAlgorithm)".Trim() -ne ""} | Foreach-Object {
                Get-Algorithm "$($_.MainAlgorithm)".Trim()
                foreach ($Second in @($_.SecondaryAlgorithm, $_.SecondAlgorithm)) {
                    if ("$Second".Trim() -ne "") {Get-Algorithm "$Second".Trim()}
                }
            } | Where-Object {$_} | Sort-Object -Unique)
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            $Algorithms = @()
        }
        if ($Algorithms.Count) {
            $Info[$Name] = [PSCustomObject]@{Stamp = $Stamp; Algorithms = $Algorithms}
        } elseif ($Info[$Name]) {
            [void]$Info.Remove($Name)
        } else {
            continue
        }
        $Changed = $true
    }
    if ($Changed) {Set-ContentJson -PathToFile $Path -Data $Info -Compress > $null}
    $Info
}

function Get-MinerStatsStale {
    # unusable benchmarks not updated for -Days, first matching reason per file:
    #   device = undetected device, miner = module missing, algorithm = not listed by the module,
    #   set = neither a model group nor a combination of model groups
    # Pools, exclusions and the current miner list do not matter; reasons without their input are skipped
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Int]$Days = 30,
        [Parameter(Mandatory = $false)]
        $Devices = $null,
        [Parameter(Mandatory = $false)]
        [String[]]$AvailMiners = @(),
        [Parameter(Mandatory = $false)]
        $MinerAlgorithms = $null
    )

    $StatsPath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Stats\Miners")
    if (-not [System.IO.Directory]::Exists($StatsPath)) {return}

    # detected device names, and the device sets a miner instance can have:
    # every model group and every combination of model groups
    $DeviceNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ValidSets   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Groups = @{}
    foreach ($Device in @($Devices)) {
        if (-not $Device.Name) {continue}
        [void]$DeviceNames.Add($Device.Name)
        $Model = "$($Device.Model)"
        if (-not $Groups.ContainsKey($Model)) {$Groups[$Model] = [System.Collections.Generic.List[string]]::new()}
        if (-not $Groups[$Model].Contains($Device.Name)) {[void]$Groups[$Model].Add($Device.Name)}
    }
    $GroupList = @($Groups.Values)
    if ($GroupList.Count -gt 0 -and $GroupList.Count -le 10) {
        for ($Mask = 1; $Mask -lt [Math]::Pow(2, $GroupList.Count); $Mask++) {
            $Members = [System.Collections.Generic.List[string]]::new()
            for ($Bit = 0; $Bit -lt $GroupList.Count; $Bit++) {
                if ($Mask -band (1 -shl $Bit)) {$Members.AddRange($GroupList[$Bit])}
            }
            [void]$ValidSets.Add((@($Members | Sort-Object) -join "-"))
        }
    } else {
        foreach ($Group in $GroupList) {[void]$ValidSets.Add((@($Group | Sort-Object) -join "-"))}
        if ($DeviceNames.Count) {[void]$ValidSets.Add((@($DeviceNames | Sort-Object) -join "-"))}
    }

    $Avail = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Miner in $AvailMiners) {if ($Miner) {[void]$Avail.Add($Miner)}}

    # algorithms per module: hashtable or object from Data\mineralgorithms.json
    $Algos = @{}
    if ($MinerAlgorithms -is [hashtable]) {
        foreach ($Key in $MinerAlgorithms.Keys) {if ($MinerAlgorithms[$Key].Algorithms) {$Algos[$Key] = @($MinerAlgorithms[$Key].Algorithms)}}
    } elseif ($MinerAlgorithms) {
        foreach ($Property in $MinerAlgorithms.PSObject.Properties) {if ($Property.Value.Algorithms) {$Algos[$Property.Name] = @($Property.Value.Algorithms)}}
    }

    $Limit = (Get-Date).AddDays(-$Days)

    foreach ($File in @([System.IO.Directory]::GetFiles($StatsPath, "*_HashRate.txt") | Sort-Object)) {
        $FileName = [System.IO.Path]::GetFileName($File)
        if ($FileName -notmatch '^(?:AMD|CPU|INTEL|NVIDIA)-(.+?)((?:-(?:GPU|CPU)#\d+)+)_([^_]+)_HashRate\.txt$') {continue}
        $StatMiner   = $Matches[1]
        $StatDevices = @($Matches[2].TrimStart('-') -split '-')
        $StatAlgo    = $Matches[3]

        # dual mining names carry the algorithms (Miner-Algo1-Algo2-GPU#nn): the miner is the longest known prefix
        $StatBase = $StatMiner
        if ($Avail.Count -and -not $Avail.Contains($StatBase)) {
            $StatParts = $StatMiner -split '-'
            for ($StatIndex = $StatParts.Count - 1; $StatIndex -gt 0; $StatIndex--) {
                $StatCandidate = $StatParts[0..($StatIndex - 1)] -join '-'
                if ($Avail.Contains($StatCandidate)) {$StatBase = $StatCandidate; break}
            }
        }

        $Reason = ""
        if ($DeviceNames.Count) {
            foreach ($StatDevice in $StatDevices) {
                if (-not $DeviceNames.Contains($StatDevice)) {$Reason = "device"; break}
            }
        }
        if (-not $Reason -and $Avail.Count -and -not $Avail.Contains($StatBase)) {$Reason = "miner"}
        if (-not $Reason -and $Algos.ContainsKey($StatBase) -and $Algos[$StatBase] -notcontains $StatAlgo) {$Reason = "algorithm"}
        if (-not $Reason -and $ValidSets.Count -and -not $ValidSets.Contains((@($StatDevices | Sort-Object) -join "-"))) {$Reason = "set"}
        if (-not $Reason) {continue}

        $Info = [System.IO.FileInfo]::new($File)
        if ($Info.LastWriteTime -gt $Limit) {continue}

        [PSCustomObject]@{
            Name      = $FileName
            Miner     = $StatBase
            Instance  = $StatMiner
            Devices   = $StatDevices -join "-"
            Algorithm = $StatAlgo
            Reason    = $Reason
            Updated   = $Info.LastWriteTime.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
            Age       = [Math]::Floor(((Get-Date) - $Info.LastWriteTime).TotalDays)
            Size      = $Info.Length
        }
    }
}

function Remove-MinerStatsStale {
    # deletes the named benchmark files, a backup of all current benchmarks is
    # taken first ("beforecleanup"), so the cleanup can be undone with a restore
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String[]]$Names
    )

    $StatsPath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Stats\Miners")

    # only names this module creates: no path parts can sneak in
    $Files = [System.Collections.Generic.List[string]]::new()
    foreach ($Name in @($Names | Select-Object -Unique)) {
        $Name = "$Name".Trim()
        if ($Name -notmatch '^(?:AMD|CPU|INTEL|NVIDIA)-[^\\/:*?"<>|]+_HashRate\.txt$') {continue}
        $File = [System.IO.Path]::Combine($StatsPath, $Name)
        if ([System.IO.File]::Exists($File)) {[void]$Files.Add($File)}
    }
    if (-not $Files.Count) {throw "None of the benchmarks exists"}

    $Saved = (New-MinerStatsBackup -Tag "beforecleanup").Name

    $Count = 0
    foreach ($File in $Files) {
        try {
            [System.IO.File]::Delete($File)
            $Count++
        } catch {
            Write-Log -Level Warn "Miner stats cleanup: $([System.IO.Path]::GetFileName($File)) not deleted: $($_.Exception.Message)"
            continue
        }
        # the running round keeps its cached values; the next round reloads the folder
        $Key = [System.IO.Path]::GetFileNameWithoutExtension($File) -replace "^(AMD|CPU|INTEL|NVIDIA)-"
        if ($Global:StatsCache.ContainsKey($Key)) {[void]$Global:StatsCache.Remove($Key)}
    }

    Write-Log "Miner stats cleanup deleted $Count benchmarks, previous stats saved as $Saved"
    [PSCustomObject]@{Files = $Count; Saved = $Saved}
}
