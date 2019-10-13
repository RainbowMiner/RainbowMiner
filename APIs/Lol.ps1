using module ..\Include.psm1

class Lol : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/summary" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            if ($Response.StatusCode -ne 200) {throw}
            $Data = $Response.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares = [Int64]$Data.Session.Accepted
        $Rejected_Shares = [Int64]($Data.Session.Submitted - $Data.Session.Accepted)

        $HashRate_Name  = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]$data.Session.Performance_Summary

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response.Content
            HashRate = $HashRate
            Device   = @()
        })

        $this.CleanupMinerData()
    }
}