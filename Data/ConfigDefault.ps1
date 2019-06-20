[PSCustomObject]@{
    PoolName = @("Nicehash","MiningPoolHub","NLpool","ZergPool","Zpool")
    MinerStatusURL = "https://rbminer.net"
    FastestMinerOnly = $true
    RemoteAPI = $false 
    ShowPoolBalances = $true
    ShowPoolBalancesDetails = $true
    ShowMinerWindow = $false
    Watchdog = $true 
    UseTimeSync = $false
    MSIAprofile = 0
    DisableMSIAmonitor = $false
    EnableOCProfiles = $false
    EnableOCVoltage = $false
    EnableAutoUpdate = $true
    EnableAutoAlgorithmAdd = $true
    EnableAutoBenchmark = $true
    EnableMinerStatus = $true
    DisableUnprofitableAlgolist = $false
    CPUMiningThreads = $Global:GlobalCPUInfo.Cores
    CPUMiningAffinity = Get-CPUAffinity $Global:GlobalCPUInfo.RealCores.Count -Hex
    GPUMiningAffinity = ""
    Delay = 1
    EthPillEnable = "disable"
    MinimumMiningIntervals = 1
    EnableServerConfig = $false
    ServerConfigName = @("config","coins","pools","algorithms")
    ExcludeServerConfigVars = @(
        "WorkerName","DeviceName","ExcludeDeviceName","Proxy",
        "APIPort","APIUser","APIPassword","APIAuth",
        "MSIApath","NVSMIpath",
        "CPUMiningThreads","CPUMiningAffinity","GPUMiningAffinity",
        "ServerName","ServerPort","ServerUser","ServerPassword","EnableServerConfig","ServerConfigName","ExcludeServerConfigVars",
        "RunMode","StartPaused"
    )
    EnableServerExcludeList = $false
}