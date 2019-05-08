[PSCustomObject]@{
    EnableCheckMiningConflict = $Global:GlobalCPUInfo.Cores -le 2
    ExcludeServerConfigVars = @(
        "WorkerName","DeviceName","Proxy",
        "APIPort","APIUser","APIPassword","APIAuth",
        "MSIApath","NVSMIpath",
        "CPUMiningThreads","CPUMiningAffinity","GPUMiningAffinity",
        "ServerName","ServerPort","ServerUser","ServerPassword","EnableServerConfig","ServerConfigName","ExcludeServerConfigVars",
        "RunMode","StartPaused"
    )
}