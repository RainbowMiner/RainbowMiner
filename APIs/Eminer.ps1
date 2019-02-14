using module ..\Include.psm1

class Eminer : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/stats" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares = [Double]$Data.found_solutions
        $Rejected_Shares = [Double]($Data.invalid_solutions + $Data.rejected_solutions)
        
        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.total_hashrate_mean | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares($HashRate_Name,$Accepted_Shares,$Rejected_Shares)
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