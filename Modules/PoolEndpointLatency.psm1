# Optional endpoint selection for equivalent offerings; profitability and region
# ordering are determined by Core before this module is called.
$script:EndpointHealth = @{}

function Measure-PoolEndpointTcp {
    param([string]$Server, [int]$Port, [int]$TimeoutMs = 600)
    # No credentials, protocol messages or TLS validation bypasses: TCP setup only.
    if (-not $Server -or $Port -lt 1 -or $Port -gt 65535 -or $Server -notmatch '^[a-zA-Z0-9.-]+$') {return $null}
    $client = $null
    $async = $null
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $async = $client.BeginConnect($Server, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) {return $null}
        $client.EndConnect($async)
        $watch.Stop()
        return [double]$watch.Elapsed.TotalMilliseconds
    } catch {
        return $null
    } finally {
        if ($async -and $async.AsyncWaitHandle) {$async.AsyncWaitHandle.Dispose()}
        if ($client) {$client.Dispose()}
    }
}

function Get-PoolEndpointChoice {
    [CmdletBinding()]
    param(
        [object[]]$Candidates,
        [string]$ActiveEndpoint,
        [datetime]$Now = [datetime]::UtcNow,
        [scriptblock]$Probe = $null,
        [int]$ProbeIntervalSeconds = 180,
        [int]$CooldownSeconds = 900,
        [int]$TimeoutMs = 350,
        [int]$MaxProbeEndpoints = 4,
        [int]$MaxProbeBudgetMs = 2200
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) {return $null}
    $Default = $Candidates[0]
    if (-not $ActiveEndpoint -or $Candidates.Count -lt 2) {
        return [pscustomobject]@{ Candidate = $Default; Switched = $false; Reason = 'inactive-or-ineligible' }
    }

    # The caller only passes equivalent pool, coin, region, protocol, TLS and port candidates.
    $Id = "$($Default.Name)|$($Default.Algorithm)|$($Default.CoinSymbol)|$($Default.Currency)|$($Default.Region)|$($Default.Protocol)|$($Default.SSL)|$($Default.Port)"
    $Endpoints = @{}
    foreach ($p in $Candidates) {$Endpoints["$($p.Host):$($p.Port)".ToLowerInvariant()] = $p}
    $Active = $ActiveEndpoint.ToLowerInvariant()
    if (-not $Endpoints.ContainsKey($Active)) {
        return [pscustomobject]@{ Candidate = $Default; Switched = $false; Reason = 'running-endpoint-not-in-offering' }
    }

    $State = $script:EndpointHealth[$Id]
    if (-not $State) {
        $State = [pscustomobject]@{
            Selected = $Active
            LastProbe = [datetime]::MinValue
            LastSwitch = [datetime]::MinValue
            Challenger = ''
            Confirmations = 0
            Samples = @{}
            ScanOffset = 0
        }
        $script:EndpointHealth[$Id] = $State
    } elseif ($State.Selected -ne $Active) {
        # If an endpoint disappears from the pool API, honor the real miner's
        # surviving endpoint or fall back to Core's deterministic selection.
        $State.Selected = $Active
        $State.Challenger = ''
        $State.Confirmations = 0
    }

    if (-not $Endpoints.ContainsKey($State.Selected)) {$State.Selected = $Active}
    if (($Now - $State.LastProbe).TotalSeconds -ge $ProbeIntervalSeconds) {
        # Bound the blocking cost even when a pool publishes dozens of endpoints.
        # Always test the actual running server and carry forward a previously
        # improving challenger for the second confirmation before rotating peers.
        $targets = [System.Collections.Generic.List[string]]::new()
        [void]$targets.Add($Active)
        if ($State.Challenger -and $State.Challenger -ne $Active -and $Endpoints.ContainsKey($State.Challenger)) {
            [void]$targets.Add($State.Challenger)
        }
        $others = @($Endpoints.Keys | Where-Object {$_ -notin @($Active, $State.Challenger)} | Sort-Object)
        if ($others.Count) {
            $offset = [int]($State.ScanOffset % $others.Count)
            $slots = [Math]::Min([Math]::Max($MaxProbeEndpoints - $targets.Count, 0), $others.Count)
            for ($ix = 0; $ix -lt $slots; $ix++) {
                [void]$targets.Add($others[($offset + $ix) % $others.Count])
            }
            $State.ScanOffset = [int](($offset + $slots) % $others.Count)
        }

        $Readings = @{}
        $AttemptCounts = @{}
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ($endpoint in $targets) {
            $p = $Endpoints[$endpoint]
            $results = [System.Collections.Generic.List[double]]::new()
            $attempts = 0
            for ($attempt = 0; $attempt -lt 2; $attempt++) {
                $remainingMs = [int]($MaxProbeBudgetMs - $timer.ElapsedMilliseconds)
                if ($remainingMs -lt 100) {break}
                $attemptTimeout = [Math]::Min($TimeoutMs, $remainingMs)
                $attempts++
                try {
                    $result = if ($Probe) { & $Probe $p.Host ([int]$p.Port) $attemptTimeout } else {
                        Measure-PoolEndpointTcp -Server $p.Host -Port ([int]$p.Port) -TimeoutMs $attemptTimeout
                    }
                } catch {$result = $null}
                if ($null -ne $result -and [double]$result -gt 0 -and [double]$result -lt ($attemptTimeout + 100)) {
                    [void]$results.Add([double]$result)
                }
            }
            $AttemptCounts[$endpoint] = $attempts
            if ($results.Count -eq 2) {
                $Readings[$endpoint] = [Math]::Max($results[0], $results[1])
            }
        }
        $timer.Stop()
        $State.Samples = $Readings
        $State.LastProbe = $Now
        $ProbeSummary = "sampled=$($targets.Count)/$($Endpoints.Count) elapsed=$($timer.ElapsedMilliseconds)ms; " + (@($targets | ForEach-Object {"$_=$(if($Readings.ContainsKey($_)) {'{0:N0}' -f $Readings[$_]} else {'unreachable'})ms"}) -join '; ')

        $healthy = @($Readings.Keys | Sort-Object @{Expression = {$Readings[$_] }}, @{Expression = {$_}})
        if ($healthy.Count) {
            $best = $healthy[0]
            $current = $State.Selected
            $superior = $false
            if ($best -ne $current) {
                if (-not $Readings.ContainsKey($current)) {
                    # Treat the active server as down only after two full attempts.
                    $superior = ($AttemptCounts[$current] -ge 2)
                } else {
                    $gain = [double]$Readings[$current] - [double]$Readings[$best]
                    $superior = $gain -ge 30.0 -and $gain -ge ([double]$Readings[$current] * 0.3)
                }
            }
            if ($superior) {
                if ($State.Challenger -eq $best) {$State.Confirmations++}
                else {$State.Challenger = $best; $State.Confirmations = 1}
                if ($State.Confirmations -ge 2 -and ($Now - $State.LastSwitch).TotalSeconds -ge $CooldownSeconds) {
                    $State.Selected = $best
                    $State.LastSwitch = $Now
                    $State.Challenger = ''
                    $State.Confirmations = 0
                    return [pscustomobject]@{ Candidate = $Endpoints[$best]; Switched = $true; Probed = $true; Reason = "tcp median $current=$($Readings[$current])ms -> $best=$($Readings[$best])ms; $ProbeSummary" }
                }
            } else {
                $State.Challenger = ''
                $State.Confirmations = 0
            }
        }
    }
    return [pscustomobject]@{ Candidate = $Endpoints[$State.Selected]; Switched = $false; Probed = [bool]($State.LastProbe -eq $Now); Reason = $(if ($ProbeSummary) {$ProbeSummary} else {'cached'}) }
}
Export-ModuleMember -Function Measure-PoolEndpointTcp, Get-PoolEndpointChoice
