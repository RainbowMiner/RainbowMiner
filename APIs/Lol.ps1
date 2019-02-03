using module ..\Include.psm1

class Lol : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/summary" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            if ($Response.StatusCode -ne 200) {throw}
            $Data = $Response.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @("", $Response)
        }

        $HashRate_Name = Get-Algorithm($Data.Mining.Algorithm -replace "/")
        $HashRate_Value = [Double]$data.Session.Performance_Summary

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
        }

        $this.AddMinerData([PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response.Content
            HashRate = $HashRate
            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
            Device   = @()
        })

        $this.CleanupMinerData()

        return @("", $Data | ConvertTo-Json -Compress)
    }
}