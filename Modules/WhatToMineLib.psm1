#
# WhatToMine functions
#

function Get-WhatToMineData {
    [CmdletBinding()]
    param([Switch]$Silent)
    
    if (-not (Test-Path ".\Data\wtmdata.json") -or (Get-ChildItem ".\Data\wtmdata.json").LastWriteTimeUtc -lt (Get-Date).AddHours(-12).ToUniversalTime()) {
        try {
            $WtmUrl  = Invoke-GetUrlAsync "https://www.whattomine.com" -cycletime (12*3600) -retry 3 -timeout 10 -method "WEB"
            [System.Collections.Generic.List[PSCustomObject]]$WtmKeys = ([regex]'(?smi)data-bs-content="Include (.+?)".+?factor_([a-z0-9]+?)_hr.+?>([hkMGTP]+)/s<').Matches($WtmUrl) | Foreach-Object {
                    [PSCustomObject]@{
                        algo   = (Get-Algorithm ($_.Groups | Where-Object Name -eq 1 | Select-Object -ExpandProperty Value)) -replace "Cuckarood29","Cuckarooz29" -replace "Ethash4g","EthashLowMemory"
                        id     = $_.Groups | Where-Object Name -eq 2 | Select-Object -ExpandProperty Value
                        factor = $_.Groups | Where-Object Name -eq 3 | Select-Object -ExpandProperty Value | Foreach-Object {Switch($_) {"Ph" {1e15;Break};"Th" {1e12;Break};"Gh" {1e9;Break};"Mh" {1e6;Break};"kh" {1e3;Break};default {1}}}
                    }
                }
            if ($WtmKeys -and $WtmKeys.count -gt 10) {
                $WtmFactors = Get-ContentByStreamReader ".\Data\wtmfactors.json" | ConvertFrom-Json -ErrorAction Ignore
                if ($WtmFactors) {
                    $WtmFactors.PSObject.Properties.Name | Where-Object {@($WtmKeys.algo) -inotcontains $_} | Foreach-Object {
                        [void]$WtmKeys.Add([PSCustomObject]@{algo = $_;factor = $WtmFactors.$_})
                    }
                }
                Set-ContentJson ".\Data\wtmdata.json" -Data $WtmKeys > $null
                $Global:GlobalWTMData = $null
            }
        } catch {
            Write-Log "WhatToMiner datagrabber failed. "
            return
        }
    }

    if (-not (Test-Path Variable:Global:GlobalWTMData) -or $Global:GlobalWTMData -eq $null) {
        $Global:GlobalWTMData = Get-ContentByStreamReader ".\Data\wtmdata.json" | ConvertFrom-Json -ErrorAction Ignore
    }

    if (-not $Silent) {$Global:GlobalWTMData}
}

function Get-WhatToMineUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [int]$Factor = 10
    )
    "https://whattomine.com/coins.json?$(@(Get-WhatToMineData | Where-Object {$_.id} | Foreach-Object {"$($_.id)=true&factor[$($_.id)_hr]=$Factor&factor[$($_.id)_p]=0"}) -join '&')"
}

function Get-WhatToMineFactor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Algo,
        [Parameter(Mandatory = $false)]
        [int]$Factor = 10
    )
    if ($Algo) {
        if (-not (Test-Path Variable:Global:GlobalWTMData) -or $Global:GlobalWTMData -eq $null) {Get-WhatToMineData -Silent}
        $Global:GlobalWTMData | Where-Object {$_.algo -eq $Algo} | Foreach-Object {$_.factor * $Factor}
    }
}