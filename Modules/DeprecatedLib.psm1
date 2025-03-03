function Set-WindowStyle {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $Style = 'SHOW',
    [Parameter(Mandatory = $False)]
    [int64]$Id = $PID,
    [Parameter(Mandatory = $False)]
    [String]$Title = ""
)
    $WindowStates = @{
        FORCEMINIMIZE   = 11; HIDE            = 0
        MAXIMIZE        = 3;  MINIMIZE        = 6
        RESTORE         = 9;  SHOW            = 5
        SHOWDEFAULT     = 10; SHOWMAXIMIZED   = 3
        SHOWMINIMIZED   = 2;  SHOWMINNOACTIVE = 7
        SHOWNA          = 8;  SHOWNOACTIVATE  = 4
        SHOWNORMAL      = 1
    }
    Initialize-User32Dll
    try {
        $hwnd = (ps -Id $Id)[0].MainWindowHandle
        if ($hwnd -eq 0) {
            $zero = [IntPtr]::Zero
            $hwnd = [User32.WindowManagement]::FindWindowEx($zero,$zero,$zero,$Title)
        }
        [User32.WindowManagement]::ShowWindowAsync($hwnd, $WindowStates[$Style])>$null        
    } catch {}
}

function Get-VariableUsage {
    $ExWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"

    foreach( $Scope in @("Script","Global") ) {
        Get-Variable -Scope $Scope | ForEach-Object {
            $size = 0
            $type = "Unknown"

            try {
                # Skip null values
                if ($_.Value -ne $null) {
                    $type = $_.Value.GetType().Name

                    if ($_.Value -is [ValueType]) {
                        $size = [System.Runtime.InteropServices.Marshal]::SizeOf($_.Value)
                    }
                    elseif ($_.Value -is [String]) {
                        $size = ($_.Value.Length * 2)
                    }
                    elseif ($_.Value -is [Array] -or $_.Value -is [System.Collections.ICollection]) {
                        try {
                            $jsonSize = ($_ | ConvertTo-Json -Depth 3 -Compress) 2>$null
                            $size = [Math]::Min($jsonSize.Length, $_.Value.Count * 500)
                        } catch {
                            $size = $_.Value.Count * 100
                        }
                    }
                    else {
                        try {
                            $jsonSize = ($_ | ConvertTo-Json -Depth 2 -Compress) 2>$null
                            $size = [Math]::Min($jsonSize.Length, 10000)
                        } catch {
                            $size = 1000
                        }
                    }
                }
            }
            catch {
                $size = 0
            }

            [PSCustomObject]@{
                Name  = "$($Scope):$($_.Name)"
                Type  = $type
                Size  = $size
                Value = $_.Value
            }
        } | Sort-Object Size -Descending | Select-Object -First 10

    }

    $WarningPreference = $ExWarningPreference

}