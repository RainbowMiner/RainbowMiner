
function Get-UnixTimestamp {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [DateTime]$DateTime = [DateTime]::UtcNow,
    [Parameter(Mandatory = $False)]
    [Switch]$Milliseconds = $false
)
    [Math]::Floor(($DateTime - [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, 'Utc'))."$(if ($Milliseconds) {"TotalMilliseconds"} else {"TotalSeconds"})" - $(if ($Milliseconds) {1000} else {1})*[int]$Session.TimeDiff)
}

function Invoke-Exe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,ValueFromPipeline = $True)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "", 
        [Parameter(Mandatory = $false)]
        [Int]$WaitForExit = 5,
        [Parameter(Mandatory = $false)]
        [Switch]$ExpandLines,
        [Parameter(Mandatory = $false)]
        [Switch]$ExcludeEmptyLines,
        [Parameter(Mandatory = $false)]
        [Switch]$AutoWorkingDirectory = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Runas = $false
        )
    try {
        if ($WorkingDirectory -eq '' -and $AutoWorkingDirectory) {$WorkingDirectory = Get-Item $FilePath | Select-Object -ExpandProperty FullName | Split-path}

        if ($IsLinux) {
            $psi = New-object System.Diagnostics.ProcessStartInfo $FilePath
        } else {
            $psi = New-object System.Diagnostics.ProcessStartInfo
            $psi.FileName = Resolve-Path $FilePath
        }
        $psi.CreateNoWindow = $true
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.Arguments = $ArgumentList
        $psi.WorkingDirectory = $WorkingDirectory
        if ($Runas) {$psi.Verb = "runas"}
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()
        $out = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit($WaitForExit*1000)>$null
        if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}

        $psi = $null
        $process.Dispose()
        $process = $null
    } catch {if ($Error.Count){$Error.RemoveAt(0)}}
}

if (-not (Test-Path "/opt/rainbowminer/ocdcmd")) {
    New-Item "/opt/rainbowminer/ocdcmd" -ItemType "directory" -Force
    & chmod 777 "/opt/rainbowminer/ocdcmd"
}

if (Test-Path "/opt/rainbowminer/ocdcmd") {
    Get-ChildItem "/opt/rainbowminer/ocdcmd" -Filter "*.run" -File -Force | Foreach-Object {Remove-Item $_.FullName -ErrorAction Ignore -Force}
}

While (-not (Test-Path "/opt/rainbowminer/ocdcmd/stop")) {
    Get-ChildItem "/opt/rainbowminer/ocdcmd" -Filter "*.sh" -File -ErrorAction Ignore | Where-Object {-not (Test-Path "/opt/rainbowminer/ocdcmd/$($tmpfn).lock")} | Foreach-Object {
        $tmpfn = $_.BaseName
        try {
            Get-UnixTimestamp | Out-File "/opt/rainbowminer/ocdcmd/$($tmpfn).run" -Force
            Get-ChildItem "/opt/rainbowminer/ocdcmd" -Filter "$($tmpfn).run" -File -ErrorAction Ignore | Foreach-Object {& chmod 666 "$($_.FullName)" > $null}
            & chmod 777 "$($_.FullName)" > $null
            Invoke-Exe -FilePath $_.FullName -WorkingDirectory "/opt/rainbowminer/ocdcmd" -Runas > $null
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        } finally {                
            Get-ChildItem "/opt/rainbowminer/ocdcmd" -Filter "$($tmpfn)*" -File -Force -ErrorAction Ignore | Foreach-Object {Remove-Item $_.FullName -ErrorAction Ignore -Force}
        }
    }
    Start-Sleep -Seconds 1
}

if (Test-Path "/opt/rainbowminer/ocdcmd") {
    Get-ChildItem "/opt/rainbowminer/ocdcmd" -File -Force | Foreach-Object {Remove-Item $_.FullName -ErrorAction Ignore -Force}
}

Write-Host "RainbowMiner OCDaemon stopped."
