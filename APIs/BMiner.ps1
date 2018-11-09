using module ..\Include.psm1

class BMiner : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status/solver" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $this.Algorithm | Select-Object -Unique | ForEach-Object {
            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix

            $HashRate_Value = 0

            $Data.devices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
                $Data.devices.$_.solvers | Where-Object {$HashRate_Name -like "$(Get-Algorithm $_.Algorithm)*"} | ForEach-Object {
                    if ($_.speed_info.hash_rate) {$HashRate_Value += $_.speed_info.hash_rate}
                    else {$HashRate_Value += $_.speed_info.solution_rate}
                }
            }
            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
            }
        }

        $this.AddMinerData([PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
            Device   = @()
        })

        $this.CleanupMinerData()

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}