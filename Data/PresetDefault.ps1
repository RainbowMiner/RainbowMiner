[PSCustomObject]@{
    EnableCheckMiningConflict = $Global:GlobalCPUInfo.Cores -le 4
}