param([switch]$Live)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot "../Modules/PoolEndpointLatency.psm1") -Force

function Pool([string]$Endpoint,[int]$Port=8610) {
    [pscustomobject]@{Name='LuckyPool';Algorithm='Qhash';CoinSymbol='QTC';Currency='QTC';Region='us';Protocol='stratum+tcp';SSL=$false;Host=$Endpoint;Port=$Port}
}
function Assert([bool]$Condition,[string]$Message) {
    if (-not $Condition) {throw "FAIL $Message"}
    "PASS $Message"
}
$east=Pool 'qtc-us-east.lproute.com'
$west=Pool 'qtc-us-west.lproute.com'
$pool=@($east,$west)
$script:Latencies=@{'qtc-us-east.lproute.com'=23.0;'qtc-us-west.lproute.com'=80.0}
$probe={param($h,$p,$timeout) $script:Latencies[$h]}
$t=[datetime]'2026-11-08T22:00:00Z'
$base=@{Candidates=$pool; ActiveEndpoint='qtc-us-east.lproute.com:8610';Probe=$probe}
$a=Get-PoolEndpointChoice @base -Now $t
Assert ($a.Candidate.Host -eq $east.Host -and -not $a.Switched) 'healthy East remains preferred'
$script:Latencies['qtc-us-east.lproute.com']=110.0
$script:Latencies['qtc-us-west.lproute.com']=25.0
$a=Get-PoolEndpointChoice @base -Now $t.AddSeconds(181)
Assert ($a.Candidate.Host -eq $east.Host -and -not $a.Switched) 'single improvement never switches'
$a=Get-PoolEndpointChoice @base -Now $t.AddSeconds(362)
Assert ($a.Candidate.Host -eq $west.Host -and $a.Switched) 'sustained >=30ms 30% improvement switches'
$base.ActiveEndpoint='qtc-us-west.lproute.com:8610'
$script:Latencies['qtc-us-east.lproute.com']=22.0
$script:Latencies['qtc-us-west.lproute.com']=100.0
$a=Get-PoolEndpointChoice @base -Now $t.AddSeconds(543)
Assert ($a.Candidate.Host -eq $west.Host -and -not $a.Switched) 'cooldown prevents immediate return'
$a=Get-PoolEndpointChoice @base -Now $t.AddSeconds(724)
Assert ($a.Candidate.Host -eq $west.Host -and -not $a.Switched) 'cooldown still protects when multiple samples confirm'
$a=Get-PoolEndpointChoice @base -Now $t.AddSeconds(1540)
Assert ($a.Candidate.Host -eq $east.Host -and $a.Switched) 'returns to healthier server after cooldown and confirmation'
# Low significance improvement must not restart.
$script:Latencies['qtc-us-east.lproute.com']=30.0
$script:Latencies['qtc-us-west.lproute.com']=20.0
$base.ActiveEndpoint='qtc-us-east.lproute.com:8610'
$a=Get-PoolEndpointChoice @base -Now $t.AddSeconds(1721)
Assert ($a.Candidate.Host -eq $east.Host -and -not $a.Switched) '10ms improvement is insufficient'
# No active miner: don't scan endpoints or change the baseline.
$a=Get-PoolEndpointChoice -Candidates @($west,$east) -ActiveEndpoint '' -Probe {throw 'probed an inactive group'}
Assert ($a.Candidate.Host -eq $west.Host) 'inactive group not probed'
# Fallback when API removes current endpoint.
$a=Get-PoolEndpointChoice -Candidates @($west) -ActiveEndpoint 'qtc-us-east.lproute.com:8610' -Probe {throw 'probed a single endpoint'}
Assert ($a.Candidate.Host -eq $west.Host) 'single surviving endpoint selected'
# Probe errors are tolerated. Separate group id.
$canada=Pool 'canada.example.test' 5001
$backup=Pool 'backup.example.test' 5001
$a=Get-PoolEndpointChoice -Candidates @($backup,$canada) -ActiveEndpoint 'backup.example.test:5001' -Probe {throw 'firewall error'} -Now $t
Assert ($a.Candidate.Host -eq $backup.Host -and -not $a.Switched) 'failed probes retain existing endpoint'
# First successful measurement doesn't switch after only one sample.
$script:Latencies['canada.example.test']=8.0
$script:Latencies['backup.example.test']=100.0
$a=Get-PoolEndpointChoice -Candidates @($backup,$canada) -ActiveEndpoint 'backup.example.test:5001' -Probe $probe -Now $t.AddSeconds(181)
Assert ($a.Candidate.Host -eq $backup.Host) 'recovered candidate requires confirmation'
$a=Get-PoolEndpointChoice -Candidates @($backup,$canada) -ActiveEndpoint 'backup.example.test:5001' -Probe $probe -Now $t.AddSeconds(362)
Assert ($a.Candidate.Host -eq $canada.Host) 'recovered candidate wins after confirmation'
# Real reachability check (non-mining TCP connections).
if ($Live) {
    $liveSample = Get-PoolEndpointChoice -Candidates @($east,$west) -ActiveEndpoint 'qtc-us-east.lproute.com:8610' -Now $t.AddDays(1)
    Assert ($liveSample.Candidate.Host -eq $east.Host) 'live TCP probes permit healthy endpoint'
}
# A failed primary should yield to an available backup after confirmation.
$failed = Pool 'dead-endpoint.example.test' 5999
$standby = Pool 'working-endpoint.example.test' 5999
$probeFailover = { param($h,$p,$timeout) if ($h -eq 'working-endpoint.example.test') {18.0} else {$null} }
$a = Get-PoolEndpointChoice -Candidates @($failed,$standby) -ActiveEndpoint 'dead-endpoint.example.test:5999' -Probe $probeFailover -Now $t
Assert ($a.Candidate.Host -eq $failed.Host) 'failed primary does not switch on first probe'
$a = Get-PoolEndpointChoice -Candidates @($failed,$standby) -ActiveEndpoint 'dead-endpoint.example.test:5999' -Probe $probeFailover -Now $t.AddSeconds(181)
Assert ($a.Candidate.Host -eq $standby.Host -and $a.Switched) 'TCP-unreachable primary falls back to healthy endpoint'
Write-Host "All endpoint-health tests passed."

# Multi-endpoint pools (>4): bounded rotation, not a full network scan.
$many = @()
1..8 | ForEach-Object {
  $p = Pool ("many-$_.example.test") 8610
  $p.Name='HeroMiners'
  $many += $p
}
$script:Visited = [System.Collections.Generic.HashSet[string]]::new()
$script:ProbeInvocations = 0
$script:AltLatency = @{}
foreach ($p in $many) {$script:AltLatency[$p.Host] = 90.0}
$bounded = {
  param($h,$p,$timeout)
  $script:ProbeInvocations++
  [void]$script:Visited.Add($h)
  $script:AltLatency[$h]
}
$scanBase = @{Candidates=$many;ActiveEndpoint='many-1.example.test:8610';Probe=$bounded}
$n1 = Get-PoolEndpointChoice @scanBase -Now $t
Assert ($n1.Candidate.Host -eq 'many-1.example.test' -and $script:ProbeInvocations -le 8) '8-endpoint group checks <=4 nodes / 8 probes per round'
Assert ($script:Visited.Count -eq 4) 'first scan touches only four of eight hosts'
$n2 = Get-PoolEndpointChoice @scanBase -Now $t.AddSeconds(181)
Assert ($script:Visited.Count -ge 6) 'next scan rotates through previously unchecked servers'
$n3 = Get-PoolEndpointChoice @scanBase -Now $t.AddSeconds(362)
Assert ($script:Visited.Count -eq 8) 'rotation eventually checks all eight servers'

# An improving challenger must remain in the sample set for confirmation.
$script:AltLatency['many-1.example.test']=120.0
$script:AltLatency['many-2.example.test']=25.0
$n4 = Get-PoolEndpointChoice @scanBase -Now $t.AddSeconds(543)
Assert (-not $n4.Switched) '8-endpoint challenger first seen without immediate switching'
$adaptiveSwitch = $false
for ($repeat=1; $repeat -le 7; $repeat++) {
    $n5 = Get-PoolEndpointChoice @scanBase -Now $t.AddSeconds(543 + $repeat * 181)
    if ($n5.Switched) {$adaptiveSwitch = ($n5.Candidate.Host -eq 'many-2.example.test');break}
}
Assert ($adaptiveSwitch) 'challenger confirmed across rotating scans'

# Max time budget: simulated slow/dead endpoints must not cause unbounded scan delay.
$slowNodes = @()
1..9 | ForEach-Object {
  $p = Pool ("slow-$_.example.test") 8611
  $p.Name='SuprNova'
  $slowNodes += $p
}
$script:SlowHits=0
$unresponsive = {param($h,$p,$timeout) $script:SlowHits++; Start-Sleep -Milliseconds 150; $null}
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$slow = Get-PoolEndpointChoice -Candidates $slowNodes -ActiveEndpoint 'slow-1.example.test:8611' -Probe $unresponsive -Now $t -MaxProbeBudgetMs 750
$sw.Stop()
Assert ($sw.ElapsedMilliseconds -lt 1150 -and $script:SlowHits -le 6) 'time-budgeted scan of nine failing endpoints stays bounded'
Assert ($slow.Candidate.Host -eq 'slow-1.example.test' -and -not $slow.Switched) 'failed network probes leave running server untouched'
Write-Host 'Expanded endpoint capacity and bounded performance tests passed.'
