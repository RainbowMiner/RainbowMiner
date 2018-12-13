[PSCustomObject]@{
    PoolName = @("Nicehash","Blazepool","MiningPoolHub","NLpool","Zpool")
    Algorithm = @("aergo","allium","balloon","bcd","bitcore","blake2s","c11","cryptonightfreehaven","cryptonighthaven","cryptonightheavy","cryptonightv8","equihash","equihash144","equihash192","ethash","hex","hmq1725","hodl","keccak","keccakc","lyra2z","m7m","myrgr","neoscrypt","pascal","phi","phi2","poly","renesis","skein","skunk","sonoa","timetravel","tribus","x16r","x16s","x17","x22i","xevan","yescrypt","yescryptr16","yescryptr32","yespower")
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
    Delay = 1
    EthPillEnable = "disable"
}