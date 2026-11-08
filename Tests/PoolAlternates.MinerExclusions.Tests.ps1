$ErrorActionPreference='Stop'
$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$src = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Modules/MinersLib.psm1'))
$start = $src.IndexOf('function Test-PoolConstraint {')
$end = $src.IndexOf('# Re-bound ScriptBlock slots', $start)
if ($start -lt 0 -or $end -le $start) {throw 'Cannot extract helper under test'}
. ([ScriptBlock]::Create($src.Substring($start,$end-$start)))

$global:Session = [pscustomobject]@{Config=[pscustomobject]@{
    EnablePoolAlternates=$true
    MaxPoolAlternates=2
    Pools=[pscustomobject]@{
      AlphaPool=[pscustomobject]@{MinerName=@(); ExcludeMinerName=@('WildRig','WildrigNg')}
      Pearlhash=[pscustomobject]@{MinerName=@('WildRig','WildrigNg'); ExcludeMinerName=@()}
      Kryptex=[pscustomobject]@{MinerName=@(); ExcludeMinerName=@()}
    }
}}
$global:PoolAlternates=@{PearlHash=[Collections.Generic.List[string]]::new()}
[void]$global:PoolAlternates.PearlHash.Add('PearlHash-@Kryptex')
[void]$global:PoolAlternates.PearlHash.Add('PearlHash-@Pearlhash')
$pools=[pscustomobject]@{
 PearlHash=[pscustomobject]@{Name='AlphaPool';Host='us1.alphapool.tech';CoinSymbol='PRL';MinerName=@();ExcludeMinerName=@()}
 'PearlHash-@Kryptex'=[pscustomobject]@{Name='Kryptex';Host='prl-eu.kryptex.network';CoinSymbol='PRL';MinerName=@();ExcludeMinerName=@()}
 'PearlHash-@Pearlhash'=[pscustomobject]@{Name='Pearlhash';Host='84.32.220.219';CoinSymbol='PRL';MinerName=@();ExcludeMinerName=@()}
}
$moduleRegex='BaikalMine|F2pool|HeroMiners|K1Pool|K1PoolSolo|Kryptex|KryptexSolo|LuckyPool|Mining4people|RPlant|RPlantSolo|SuprNova|unMineable'
$tests=0
function Assert-Keys($Label,[string[]]$Actual,[string[]]$Wanted) {
  $script:tests++
  $a=($Actual -join '|')
  $w=($Wanted -join '|')
  if ($a -cne $w) {throw "$Label expected [$w] but got [$a]"}
  "PASS $Label"
}
function Get-Keys($Who, $Regex=$moduleRegex, $Algorithm='PearlHash', $Model='RTX5070') {
  @(Get-PoolAlgorithmKeys -Pools $pools -Algorithm $Algorithm -Model $Model -ExcludePoolName $Regex -MinerName $Who)
}
$base=@('PearlHash','PearlHash-RTX5070','PearlHash-GPU')
$withPearl=@('PearlHash','PearlHash-@Pearlhash','PearlHash-RTX5070','PearlHash-GPU')
Assert-Keys 'main issue WildRig' (Get-Keys 'WildRig') $withPearl
Assert-Keys 'main issue WildrigNg' (Get-Keys 'WildrigNg') $withPearl
Assert-Keys 'unchanged PeakMiner on AlphaPool' (Get-Keys 'PeakMiner') $base
Assert-Keys 'no miner identity backward compatible' @(Get-PoolAlgorithmKeys -Pools $pools -Algorithm PearlHash -Model RTX5070 -ExcludePoolName $moduleRegex) $base
Assert-Keys 'no module regex but pool policy triggers fallback' (Get-Keys 'WildRig' '') @('PearlHash','PearlHash-@Kryptex','PearlHash-@Pearlhash','PearlHash-RTX5070','PearlHash-GPU')
Assert-Keys 'explicit miner module blocks primary' (Get-Keys 'WildRig' "$moduleRegex|AlphaPool") $withPearl
Assert-Keys 'non-PearlHash unaffected' (Get-Keys 'WildRig' $moduleRegex 'Quantus') @('Quantus','Quantus-RTX5070','Quantus-GPU')
Assert-Keys 'secondary algorithm unaffected' (Get-Keys 'WildRig' $moduleRegex 'KawPOW') @('KawPOW','KawPOW-RTX5070','KawPOW-GPU')
$global:Session.Config.Pools.Pearlhash.MinerName=@('WildRig')
Assert-Keys 'pool allowlist denies NG fallback' (Get-Keys 'WildrigNg') $base
$global:Session.Config.Pools.Pearlhash.MinerName=@('WildRig','WildrigNg')
$pools.'PearlHash-@Pearlhash'.ExcludeMinerName=@('WildRig')
Assert-Keys 'pool data exclusion prevents fallback' (Get-Keys 'WildRig') $base
$pools.'PearlHash-@Pearlhash'.ExcludeMinerName=@()
$pools.'PearlHash-@Pearlhash'.MinerName=@('AnotherMiner')
Assert-Keys 'pool data allowlist prevents fallback' (Get-Keys 'WildRig') $base
$pools.'PearlHash-@Pearlhash'.MinerName=@()
$global:Session.Config.MaxPoolAlternates=1
Assert-Keys 'max 1 matching alternate still selects Pearlhash' (Get-Keys 'WildRig') $withPearl
$global:Session.Config.EnablePoolAlternates=$false
Assert-Keys 'alternates disabled remains legacy baseline' (Get-Keys 'WildRig') $base
$global:Session.Config.EnablePoolAlternates=$true
$global:Session.Config.Pools.AlphaPool.ExcludeMinerName=@()
Assert-Keys 'no restriction means no extra candidates' (Get-Keys 'WildRig') $base
$global:Session.Config.Pools.AlphaPool.ExcludeMinerName=@('WildRig','WildrigNg')
$global:PoolAlternates=@{}
Assert-Keys 'no alternates recorded leaves legacy baseline' (Get-Keys 'WildRig') $base
"PASS $tests targeted behavioral regression scenarios"

# Test the actual Core.psm1 alternate builder, not a hand-built list:
# the first two alternate pools are incompatible with WildRig but the third
# is Pearlhash. The global discovery stage must not discard it prematurely.
$core=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Modules/Core.psm1'))
$at=$core.IndexOf('        $MaxPoolAlternates = if ($Session.Config.EnablePoolAlternates)')
$end=$core.IndexOf('        $Pools_OutOfSyncMinutes = 0',$at)
if($at -lt 0 -or $end -le $at) {throw 'Core alternate selection extraction failed'}
function Get-PoolPriorityTier {param($Pool, $LockMiners) [int]$Pool.PriorityTier}
$global:Session.Config.EnablePoolAlternates=$true
$global:Session.Config.MaxPoolAlternates=2
$SortedPools=[Collections.Generic.List[PSCustomObject]]::new()
foreach($p in @(
 @{Name='AlphaPool';Host='us1.alphapool.tech'; PriorityTier=1}
 @{Name='Kryptex';Host='prl-eu.kryptex.network';PriorityTier=1}
 @{Name='LuckyPool';Host='luckypool.example';PriorityTier=1}
 @{Name='Pearlhash';Host='84.32.220.219';PriorityTier=1}
 @{Name='OtherTier';Host='other.example';PriorityTier=2}
)) {
 [void]$SortedPools.Add([pscustomobject]@{
    Algorithm='PearlHash'; Algorithm0='PearlHash'; CoinSymbol='PRL'
    Name=$p.Name;Host=$p.Host;PriorityTier=$p.PriorityTier;
    BenchmarkOnly=$false;DisabledDueToCoinSymbolPBM=$false;
    MinerName=@();ExcludeMinerName=@()
 })
}
$global:Session.Config.Pools|Add-Member NoteProperty 'LuckyPool' ([pscustomobject]@{MinerName=@();ExcludeMinerName=@()}) -Force
$global:Session.Config.Pools|Add-Member NoteProperty 'OtherTier' ([pscustomobject]@{MinerName=@();ExcludeMinerName=@()}) -Force
$pools=[pscustomobject]@{}
$LockMiners=$null
. ([ScriptBlock]::Create($core.Substring($at,$end-$at)))
$alts=@($global:PoolAlternates['pearlhash'])
Assert-Keys 'core retains 3 same-tier options despite max 2' $alts @('PearlHash-@Kryptex','PearlHash-@LuckyPool','PearlHash-@Pearlhash')
$regexCrowded=$moduleRegex+'|LuckyPool'
Assert-Keys 'helper skips incompatible first 2 and selects third' @(Get-PoolAlgorithmKeys -Pools $pools -Algorithm PearlHash -Model RTX5070 -ExcludePoolName $regexCrowded -MinerName WildRig) $withPearl
$global:Session.Config.MaxPoolAlternates=1
Assert-Keys 'per-miner max 1 still skips unusable first 2' @(Get-PoolAlgorithmKeys -Pools $pools -Algorithm PearlHash -Model RTX5070 -ExcludePoolName $regexCrowded -MinerName WildrigNg) $withPearl
"PASS $tests total regressions with real Core and helper logic"
# Bounding regression: a large list of ordinary same-priority pools must NOT
# materialize unbounded alternate keys. A final, explicitly allowlisted pool
# that accepts a miner excluded by the primary must still survive.
function Run-CoreBlock($ranked) {
  $SortedPools=[Collections.Generic.List[PSCustomObject]]::new()
  foreach($p in $ranked){[void]$SortedPools.Add($p)}
  $Pools=[pscustomobject]@{}
  $LockMiners=$null
  . ([ScriptBlock]::Create($core.Substring($at,$end-$at)))
  [pscustomobject]@{Alts=@($global:PoolAlternates['pearlhash'] | Where-Object {$_}); Pools=$Pools}
}
$global:Session.Config.MaxPoolAlternates=2
$lots=[Collections.Generic.List[PSCustomObject]]::new()
[void]$lots.Add([pscustomobject]@{Algorithm='PearlHash';Algorithm0='PearlHash';CoinSymbol='PRL';Name='AlphaPool';Host='us1.alphapool.tech';PriorityTier=1;BenchmarkOnly=$false;DisabledDueToCoinSymbolPBM=$false;MinerName=@();ExcludeMinerName=@()})
for($i=0;$i -lt 50;$i++) {
  $name="GenericPool$i"
  $global:Session.Config.Pools | Add-Member NoteProperty $name ([pscustomobject]@{MinerName=@();ExcludeMinerName=@()}) -Force
  [void]$lots.Add([pscustomobject]@{Algorithm='PearlHash';Algorithm0='PearlHash';CoinSymbol='PRL';Name=$name;Host="generic$i.example";PriorityTier=1;BenchmarkOnly=$false;DisabledDueToCoinSymbolPBM=$false;MinerName=@();ExcludeMinerName=@()})
}
[void]$lots.Add([pscustomobject]@{Algorithm='PearlHash';Algorithm0='PearlHash';CoinSymbol='PRL';Name='Pearlhash';Host='84.32.220.219';PriorityTier=1;BenchmarkOnly=$false;DisabledDueToCoinSymbolPBM=$false;MinerName=@();ExcludeMinerName=@()})
$r=Run-CoreBlock $lots
if($r.Alts.Count -ne 3){throw "Bounded extras expected 3, saw $($r.Alts.Count)"}
Assert-Keys '50 general alternatives remain bounded, pinned Pearlhash preserved' $r.Alts @('PearlHash-@GenericPool0','PearlHash-@GenericPool1','PearlHash-@Pearlhash')
$global:Session.Config.Pools.AlphaPool.ExcludeMinerName=@()
$r2=Run-CoreBlock $lots
Assert-Keys 'no excluded miner implies strict cap 2' $r2.Alts @('PearlHash-@GenericPool0','PearlHash-@GenericPool1')
$global:Session.Config.Pools.AlphaPool.ExcludeMinerName=@('WildRig','WildrigNg')
$global:Session.Config.EnablePoolAlternates=$false
$r3=Run-CoreBlock $lots
if($r3.Alts.Count -ne 0){throw 'Alternate disable failed'}
'PASS disabled alternates produce no alternate entries'
$global:Session.Config.EnablePoolAlternates=$true
"PASS $tests tested scenarios plus disabled alternates bounded stress"
