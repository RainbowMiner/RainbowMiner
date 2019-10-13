using module ..\Include.psm1

class Gminer : Miner {

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/stat" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares = [Int64]($Data.devices.accepted_shares | Measure-Object -Sum).Sum
        $Rejected_Shares = [Int64]($Data.devices.rejected_shares | Measure-Object -Sum).Sum

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.speed | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        })

        $this.CleanupMinerData()
    }
}