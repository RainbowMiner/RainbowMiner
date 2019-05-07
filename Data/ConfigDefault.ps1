[PSCustomObject]@{
    PoolName = @("Nicehash","MiningPoolHub","NLpool","ZergPool","Zpool")
    ExcludeAlgorithm = @(     
     "Blakecoin",
     "BlakeVanilla",
     "CryptoLight",
     "CryptoNight",
     "Decred",
     "Keccak",
     "KeccakC",
     "Lbry",
     "Lyra2RE",
     "Lyra2RE2",
     "MyriadGroestl",
     "Nist5",
     "Pascal",
     "Quark",
     "Qubit",
     "Scrypt",
     "ScryptN",
     "SHA256d",
     "SHA256t",
     "Sia",
     "Sib",
     "X11",
     "X13",
     "X14",
     "X15"        
    )
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
    CPUMiningThreads = $Global:GlobalCPUInfo.Cores
    CPUMiningAffinity = Get-CPUAffinity $Global:GlobalCPUInfo.RealCores.Count -Hex
    GPUMiningAffinity = ""
    Delay = 1
    EthPillEnable = "disable"
    MinimumMiningIntervals = 1
    EnableServerConfig = $false
    ServerConfigName = @("config","coins","pools","algorithms")
    ExcludeServerConfigVars = @(
        "WorkerName","DeviceName","Proxy",
        "APIPort","APIUser","APIPassword","APIAuth",
        "MSIApath","NVSMIpath",
        "CPUMiningThreads","CPUMiningAffinity","GPUMiningAffinity",
        "ServerName","ServerPort","ServerUser","ServerPassword","UseServerConfig","ExcludeServerConfigVars",
        "RunMode","StartPaused"
    )
}