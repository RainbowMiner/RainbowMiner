param($ControllerProcessID, $PhysicalCPUs)

Import-Module ".\Modules\Include.psm1"

Set-OsFlags

if ($IsLinux) {Import-Module ".\Modules\OCDaemon.psm1"}

$ControllerProcess = Get-Process -Id $ControllerProcessID -ErrorAction Ignore
if ($ControllerProcess -eq $null) {return}

$ControllerProcess.Handle >$null

$count = 0

do {

    $end = $ControllerProcess.WaitForExit(500)
    if (-not $end -and $count -le 0) {
        try {
            $GetCPU_Running = $IsWindows -and (Get-Process -Name "GetCPU" -ErrorAction Ignore)
            if ($SysInfo = Get-SysInfo -PhysicalCPUs $PhysicalCPUs -FromRegistry $GetCPU_Running) {
                Set-ContentJson -PathToFile ".\Data\sysinfo.json" -Data $SysInfo -Quiet > $null
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
        }
        $count = 60
    }
    $count--

} until ($end)

