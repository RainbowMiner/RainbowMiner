[PSCustomObject]@{
    'Profile1-GTX1070' = [PSCustomObject]@{
        PowerLimit = 0
        ThermalLimit = 0
        MemoryClockBoost = "*"
        CoreClockBoost = "*"
        LockVoltagePoint = "*"
    }
    'Profile2-GTX1070' = [PSCustomObject]@{
        PowerLimit = 85
        ThermalLimit = 0
        MemoryClockBoost = if ($IsLinux) {"*"} else {"400"}
        CoreClockBoost = if ($IsLinux) {"*"} else {"100"}
        LockVoltagePoint = "*"
    }
    'Profile3-GTX1070' = [PSCustomObject]@{
        PowerLimit = 85
        ThermalLimit = 0
        MemoryClockBoost = if ($IsLinux) {"*"} else {"200"}
        CoreClockBoost = if ($IsLinux) {"*"} else {"100"}
        LockVoltagePoint = "*"
    }
    'Profile4-GTX1070' = [PSCustomObject]@{
        PowerLimit = 85
        ThermalLimit = 0
        MemoryClockBoost = if ($IsLinux) {"*"} else {"-500"}
        CoreClockBoost = if ($IsLinux) {"*"} else {"100"}
        LockVoltagePoint = "*"
    }
    'Profile5-GTX1070' = [PSCustomObject]@{
        PowerLimit = 85
        ThermalLimit = 0
        MemoryClockBoost = if ($IsLinux) {"*"} else {"350"}
        CoreClockBoost = if ($IsLinux) {"*"} else {"100"}
        LockVoltagePoint = "*"
    }
}
