param($ControllerProcessID, $PhysicalCPUs)

Import-Module .\Modules\Include.psm1

Set-OsFlags

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

$count = 0

do {

    $end = $ControllerProcess.WaitForExit(500)
    if (-not $end -and $count -le 0) {
        try {
            if ($SysInfo = Get-SysInfo -PhysicalCPUs $PhysicalCPUs) {
                Set-ContentJson ".\Data\sysinfo.json" $SysInfo > $null
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
        $count = 60
    }
    $count--

} until ($end)

