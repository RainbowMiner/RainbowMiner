$ErrorActionPreference = 'Stop'
$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$Source = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Pools/LuckyPool.ps1')).Replace(([string][char]13+[char]10),[string][char]10)
$Start = $Source.IndexOf('        $Port_Check = @')
$End = $Source.LastIndexOf("    }"+[char]10+"}")
if ($Start -lt 0 -or $End -le $Start) {throw 'Cannot extract LuckyPool port-generation block'}
$EmitPorts = [ScriptBlock]::Create($Source.Substring($Start,$End-$Start))

function Get-Region {param($Flag) $Flag}

$Pool_Algorithm_Norm = 'PearlHash'
$Pool_Coin = [pscustomobject]@{Name='Pearl';Algo='PearlHash'}
$Pool_Currency = 'PRL'
$Pool_Request = [pscustomobject]@{
    config = [pscustomobject]@{
        ports = @()
        stratum = @([pscustomobject]@{server='pearl-ca1.luckypool.io';flag='ca'})
    }
}
$StatAverage = 'Live'
$StatAverageStable = 'Live'
$Stat = [pscustomobject]@{Live=1.0;Week_Fluctuation=0;Updated=(Get-Date)}
$Pool_Data = [pscustomobject]@{Workers=1;TSL=0}
$Name = 'LuckyPool'
$Pool_User = 'dummy-wallet'
$Pool_Pass = 'x'
$Wallets = [pscustomobject]@{PRL='dummy-wallet'}

function Assert-PortCase ($CaseName, $Ports, [string[]]$Expected) {
    $Pool_Request.config.ports = $Ports
    $Results = @(& $EmitPorts)
    $Observed = @($Results | ForEach-Object { "$($_.Protocol):$($_.Port)" })
    if (($Observed -join '|') -cne ($Expected -join '|')) {
        throw "$CaseName expected [$($Expected -join ',')] but got [$($Observed -join ',')]"
    }
    foreach ($Item in $Results) {
        if ($Item.SSL -cne ($Item.Protocol -eq 'stratum+ssl')) {
            throw "$CaseName SSL field disagrees with protocol"
        }
    }
    "PASS $CaseName"
}

Assert-PortCase 'dual TCP/TLS on one port' @(
    [pscustomobject]@{port=3360;tcp=$true;tls=$true},
    [pscustomobject]@{port=3361;tcp=$true;tls=$true}
) @('stratum+tcp:3360','stratum+ssl:3360')

Assert-PortCase 'TLS only' @(
    [pscustomobject]@{port=3360;tcp=$false;tls=$true}
) @('stratum+ssl:3360')

Assert-PortCase 'TCP only' @(
    [pscustomobject]@{port=3360;tcp=$true;tls=$false}
) @('stratum+tcp:3360')

Assert-PortCase 'separate TCP/TLS ports' @(
    [pscustomobject]@{port=3360;tcp=$true;tls=$false},
    [pscustomobject]@{port=3361;tcp=$false;tls=$true}
) @('stratum+tcp:3360','stratum+ssl:3361')

Assert-PortCase 'legacy port without capability flags' @(
    [pscustomobject]@{port=3360}
) @('stratum+tcp:3360')

'PASS all 5 LuckyPool protocol selection regression tests'
