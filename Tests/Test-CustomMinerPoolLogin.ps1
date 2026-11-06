$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../Modules/Include.psm1') -Force
$Tests = @(
    @{ Name='direct wallet'; User='prl1wallet/AMDRIG'; Worker='AMDRIG'; Expected='prl1wallet' },
    @{ Name='solo wallet'; User='solo:prl1wallet/AMDRIG'; Worker='AMDRIG'; Expected='solo:prl1wallet' },
    @{ Name='account username'; User='krx123456/AMDRIG'; Worker='AMDRIG'; Expected='krx123456' },
    @{ Name='solo account'; User='solo:krx123456/AMDRIG'; Worker='AMDRIG'; Expected='solo:krx123456' },
    @{ Name='dot worker'; User='wallet.AMDRIG'; Worker='AMDRIG'; Expected='wallet' },
    @{ Name='email account'; User='example@kryptex.test/AMDRIG'; Worker='AMDRIG'; Expected='example@kryptex.test' },
    @{ Name='server placeholder'; User='solo:prl1wallet/{workername:AMDRIG}'; Worker='{workername:AMDRIG}'; Expected='solo:prl1wallet' },
    @{ Name='unmatched suffix'; User='wallet/OTHER'; Worker='AMDRIG'; Expected='wallet/OTHER' },
    @{ Name='plain username'; User='krx123456'; Worker='AMDRIG'; Expected='krx123456' },
    @{ Name='empty worker'; User='wallet/AMDRIG'; Worker=''; Expected='wallet/AMDRIG' },
    @{ Name='regex metachar worker'; User='wallet/A.[B]'; Worker='A.[B]'; Expected='wallet' },
    @{ Name='case variation'; User='wallet/amdrig'; Worker='AMDRIG'; Expected='wallet' }
)
foreach ($Case in $Tests) {
    $Got = Get-CustomMinerPoolLogin -User $Case.User -Worker $Case.Worker
    if ($Got -cne $Case.Expected) { throw "FAIL $($Case.Name): '$Got' != '$($Case.Expected)'" }
    $Result = Expand-CustomMinerArguments -Template '--wallet %POOL_LOGIN% --worker %WORKER_NAME%' -Values @{ POOL_LOGIN=$Got; WORKER_NAME=$Case.Worker }
    if (-not $Result.StartsWith("--wallet $($Case.Expected) --worker")) { throw "FAIL expanded template: $Result" }
    Write-Output "PASS: $($Case.Name)"
}
Write-Output "PASS: all $($Tests.Count) cases"
