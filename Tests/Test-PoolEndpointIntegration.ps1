enum MinerStatus {Idle; Running}
$ErrorActionPreference='Stop'
$Session=[pscustomobject]@{
 Config=[pscustomobject]@{
  EnablePoolEndpointLatencySelection=$true
  Pools=[pscustomobject]@{
   LuckyPool=[pscustomobject]@{FocusWallet=@();SSL=$false}
   OtherPool=[pscustomobject]@{FocusWallet=@();SSL=$false}
  }
  Region='ca'
  DefaultPoolRegion=@('ca','us')
 }
}
$LockMiners=$false
$Pools_PriceCmp=@{'LuckyPool-Qhash-QTC'=1.0;'OtherPool-Qhash-QTC'=1.15}
function NewOffer([string]$Server,[string]$Name='LuckyPool',[string]$Region='us') {
 [pscustomobject]@{
  Name=$Name;Algorithm='Qhash';Algorithm0='Qhash';CoinSymbol='QTC';Currency='QTC'
  Host=$Server;Port=8610;Region=$Region;Protocol='stratum+tcp';SSL=$false;Exclusive=$false;Idle=$false;PostBlockMining=$false;BenchmarkOnly=$false
 }
}
function Write-Log { param([string]$Message) }
function Assert([bool]$ok,[string]$note) {
 if (-not $ok) {throw "FAIL $note"};Write-Host "PASS $note"
}
$east=NewOffer 'qtc-us-east.lproute.com'
$west=NewOffer 'qtc-us-west.lproute.com'
$high=NewOffer 'big-profit.example.test' 'OtherPool'
$can=NewOffer 'ca.example.test' 'LuckyPool' 'ca'
$Global:ActiveMiners=@([pscustomobject]@{
 Status=[MinerStatus]::Running;Pool='LuckyPool';BaseAlgorithm='Qhash';CoinSymbol='QTC';Arguments='-a qhash -o stratum+tcp://qtc-us-east.lproute.com:8610'
})
$script:ChoiceHost='qtc-us-west.lproute.com'
function Get-PoolEndpointChoice {
 param([object[]]$Candidates,[string]$ActiveEndpoint,[int]$MaxProbeBudgetMs)
 $choice=$Candidates | Where-Object Host -eq $script:ChoiceHost | Select-Object -First 1
 if(-not $choice) {$choice=$Candidates[0]}
 [pscustomobject]@{Candidate=$choice;Switched=$true;Reason="injected test choice"}
}
function Set-SortedPool([object[]]$PoolList) {
 $NewPools=$PoolList
 $SortedPools=[System.Collections.Generic.List[PSCustomObject]]::new()
 $core = Get-Content (Join-Path $PSScriptRoot '../Modules/Core.psm1') -Raw
 $sortSource=([regex]::Match($core, '(?s)\$NewPools \| Sort-Object.+?\| Foreach-Object \{ \[void\]\$SortedPools\.Add\(\$_\) \}')).Value
 if (-not $sortSource) {throw 'Core pool sort missing'}
 & ([scriptblock]::Create($sortSource))
 $match=[regex]::Match($core, '(?s)# Optional latency-aware selection.+?(?=        # one ordered pass)')
 if(-not $match.Success) {throw 'Latency selection integration missing'}
 & ([scriptblock]::Create($match.Value))
 return $SortedPools.ToArray()
}
$s=@(Set-SortedPool @($west,$east))
Assert ($s[0].Host -eq $west.Host) 'same-offer selection swaps endpoint in winner slot'
$s=@(Set-SortedPool @($high,$west,$east))
Assert ($s[0].Name -eq 'OtherPool' -and $s[0].Host -eq $high.Host) 'higher-profit pool cannot be displaced'
$s=@(Set-SortedPool @($can,$west,$east))
Assert ($s[0].Host -eq $can.Host) 'region preference cannot be displaced'
$s=@(Set-SortedPool @($east))
Assert ($s[0].Host -eq $east.Host) 'single endpoint unchanged'
$Global:ActiveMiners=@()
$s=@(Set-SortedPool @($west,$east))
Assert ($s[0].Host -eq $east.Host) 'no active miner means deterministic baseline'
$Session.Config.EnablePoolEndpointLatencySelection=$false
$s=@(Set-SortedPool @($west,$east))
Assert ($s[0].Host -eq $east.Host) 'disabled feature preserves deterministic baseline'
Write-Host 'Core integration selection tests passed.'


$Session.Config.EnablePoolEndpointLatencySelection=$true
foreach ($adapter in @('HeroMiners','SuprNova','2Miners','WoolyPooly')) {
  $Session.Config.Pools | Add-Member NoteProperty $adapter ([pscustomobject]@{FocusWallet=@();SSL=$false}) -Force
  $Pools_PriceCmp["$adapter-Qhash-QTC"]=1.0
  $a=NewOffer ("a.$adapter.example.test") $adapter
  $b=NewOffer ("b.$adapter.example.test") $adapter
  $script:ChoiceHost=$b.Host
  $Global:ActiveMiners=@([pscustomobject]@{Status=[MinerStatus]::Running;Pool=$adapter;BaseAlgorithm='Qhash';CoinSymbol='QTC';Arguments="-a qhash -o stratum+tcp://$($a.Host):8610"})
  $s=@(Set-SortedPool @($b,$a))
  Assert ($s[0].Host -eq $b.Host) "$adapter-style equivalent endpoint grouping"
}
# Cross-port is unsafe: often a pool encodes static difficulty or modes in the port.
$script:ChoiceHost='qtc-us-west.lproute.com'
$Global:ActiveMiners=@([pscustomobject]@{Status=[MinerStatus]::Running;Pool='LuckyPool';BaseAlgorithm='Qhash';CoinSymbol='QTC';Arguments='-a qhash -o stratum+tcp://qtc-us-east.lproute.com:8610'})
$east=NewOffer 'qtc-us-east.lproute.com'
$west=NewOffer 'qtc-us-west.lproute.com'
$west.Port=8611
$s=@(Set-SortedPool @($west,$east))
Assert ($s[0].Host -eq $east.Host) 'distinct port mode not overridden by measured latency'
# SSL preference must remain stronger than endpoint latency.
$west.Port=8610
$west.SSL=$true;$west.Protocol='stratum+ssl'
$s=@(Set-SortedPool @($west,$east))
Assert ($s[0].Host -eq $east.Host) 'distinct TLS protocol not conflated with same offering'
Write-Host 'Multi-adapter compatibility fixtures passed.'

# Different wallet/worker authentication is not a safe equivalent endpoint.
$script:ChoiceHost='qtc-us-west.lproute.com'
$Global:ActiveMiners=@([pscustomobject]@{Status=[MinerStatus]::Running;Pool='LuckyPool';BaseAlgorithm='Qhash';CoinSymbol='QTC';Arguments='-a qhash -o stratum+tcp://qtc-us-east.lproute.com:8610'})
$east=NewOffer 'qtc-us-east.lproute.com'
$west=NewOffer 'qtc-us-west.lproute.com'
$east | Add-Member User 'walletA';$west | Add-Member User 'walletB'
$s=@(Set-SortedPool @($west,$east))
Assert ($s[0].Host -eq $east.Host) 'different wallet identity not conflated with equivalent server'
Write-Host 'Credentials safety tests passed.'
