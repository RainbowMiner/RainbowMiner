[PSCustomObject]@{
    PoolName = @("Nicehash","Blazepool","MiningPoolHub","NLpool","Zpool")
    Algorithm = @("aergo","allium","bcd","bitcore","blake2s","c11","cryptonightswap","cryptonightheavy","cryptonightv8","dedal","equihash","equihash144","equihash192","ethash","hex","hmq1725","keccak","keccakc","lyra2z","m7m","pascal","phi","phi2","poly","renesis","skein","skunk","sonoa","timetravel","tribus","x16r","x16s","x17","x21s","x22i","xevan","yescrypt","yescryptr16","yescryptr32","yespower")
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
    EnableAutoUpdate = $false
    EnableMinerStatus = $true
    CPUMiningThreads = $Global:GlobalCPUInfo.Cores
    CPUMiningAffinity = Get-CPUAffinity $Global:GlobalCPUInfo.RealCores.Count -Hex
    GPUMiningAffinity = ""
    Delay = 1
    EthPillEnable = "disable"
    MinimumMiningIntervals = 1
}