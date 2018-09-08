[PSCustomObject]@{
    PoolName = @("Nicehash","AHashPool","Blazepool","MiningPoolHub","Zergpool")
    Algorithm = @("aergo","allium","balloon","bitcore","blake2s","c11","cryptonightlite","cryptonighthaven","cryptonightheavy","cryptonightv7","equihash","equihash144","equihash192","ethash","hex","hmq1725","hodl","keccak","keccakc","lyra2re2","lyra2z","m7m","myrgr","neoscrypt","pascal","phi","phi2","poly","renesis","skein","skunk","sonoa","timetravel","tribus","x16r","x16s","x17","xevan","yescrypt","yescryptr16","yespower")
    ExcludeMinerName = @("ClaymoreEquihashAmd","lolMiner")
    FastestMinerOnly = $true
    RemoteAPI = $false 
    ShowPoolBalances = $true
    ShowMinerWindow = $false
    Watchdog = $true 
    UseTimeSync = $false
    MSIAprofile = 0
    EnableOCProfiles = $false
    EnableOCVoltage = $false
    EnableAutoUpdate = $false
    Delay = 1
}