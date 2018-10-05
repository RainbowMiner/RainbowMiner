[PSCustomObject]@{
    PoolName = @("Nicehash","Blazepool","MiningPoolHub","NLpool","Zergpool")
    Algorithm = @("aergo","allium","balloon","bcd","bitcore","blake2s","c11","cryptonightlite","cryptonighthaven","cryptonightheavy","cryptonightv7","equihash","equihash144","equihash192","ethash","hex","hmq1725","hodl","keccak","keccakc","lyra2re2","lyra2z","m7m","myrgr","neoscrypt","pascal","phi","phi2","poly","renesis","skein","skunk","sonoa","timetravel","tribus","x16r","x16s","x17","xevan","yescrypt","yescryptr16","yespower")
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