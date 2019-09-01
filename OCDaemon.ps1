using module .\Include.psm1

Set-OsFlags

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

if ($IsWindows) {
    if ($PSVersionTable.PSVersion -ge (Get-Version "6.1")) {
        Import-Module NetSecurity -ErrorAction Ignore -SkipEditionCheck
        Import-Module Defender -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore -SkipEditionCheck
    } else {
        Import-Module NetSecurity -ErrorAction Ignore
        Import-Module Defender -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore
    }
}

Get-ChildItem ".\stopocdaemon.txt" -ErrorAction Ignore | Remove-Item -Force

if (Test-Path ".\Data\ocdcmd") {
    Get-ChildItem ".\Data\ocdcmd" -File -Force | Foreach-Object {Remove-Item $_.FullName -ErrorAction Ignore -Force}
}

While (-not (Test-Path ".\stopocdaemon.txt")) {
    if ((Test-Path ".\Data\ocdcmd") -and -not (Test-Path ".\Data\ocdcmd\.pid")) {
        Get-ChildItem ".\Data\ocdcmd" -Filter "*.sh" -File -ErrorAction Ignore | Foreach-Object {
            try {
                Get-UnixTimestamp | Out-File ".\Data\ocdcmd\$($_.Name).pid" -Force
                Get-ChildItem ".\Data\ocdcmd" -Filter "$($_.Name).pid" -File -ErrorAction Ignore | Foreach-Object {& chmod +rw "$($_.FullName)" > $null}
                & chmod +x "$($_.FullName)" > $null
                Invoke-Exe -FilePath $_.FullName -Runas > $null
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            } finally {                
                Get-ChildItem ".\Data\ocdcmd" -Filter "$($_.Name)*" -File -ErrorAction Ignore | Foreach-Object {Remove-Item $_.FullName -ErrorAction Ignore -Force}
            }
        }
    }
    Start-Sleep -Seconds 1
}

Get-ChildItem ".\stopocdaemon.txt" -ErrorAction Ignore | Remove-Item -Force

Write-Host "RainbowMiner OCDaemon stopped."
