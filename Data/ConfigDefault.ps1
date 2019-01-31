[PSCustomObject]@{
    PoolName = @("Nicehash","MiningPoolHub","NLpool","ZergPool","Zpool")
    Algorithm = @("AeriumX","Allium","Argon2dDYN","Bcd","Bitcore","Blake2s","C11","CryptoNightHeavy","CryptoNightSuperFast","CryptoNightV8","Cuckaroo29","Cuckoo","Equihash","Equihash16x5","Equihash24x5",
"Equihash24x7","Equihash25x5","Ethash","GLTPawelHash","Hex","HMQ1725","Keccak","KeccakC","Lyra2RE3","Lyra2z","Lyra2zz","m7m","MTP","NrgHash","Pascal","PHI","PHI2","Polytimos","Skein","
Skunk","SonoA","Tribus","X16r","X16rt","X16s","X17","X21s","X22i","Xevan","Yescrypt","YescryptR16","YescryptR32","YescryptR8","Yespower")
    ExcludeMinerName = @("ClaymoreEquihashAmd")
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
}