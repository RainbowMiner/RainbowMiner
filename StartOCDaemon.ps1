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

While (-not (Test-Path ".\stopocdaemon.txt")) {
    if (Test-Path ".\Data\ocdcmd") {
        Get-ChildItem ".\Data\ocdcmd" -Filter "*.sh" -ErrorAction Ignore | Foreach-Object {
            try {
                & chmod +x "$($_.FullName)" > $null
                Invoke-Exe -FilePath $_.FullName -Runas > $null
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
            }
            Remove-Item -Force $_.FullName -ErrorAction Ignore
        }
    }
    Start-Sleep -Seconds 1
}

Get-ChildItem ".\stopocdaemon.txt" -ErrorAction Ignore | Remove-Item -Force

Write-Host "Done!"
