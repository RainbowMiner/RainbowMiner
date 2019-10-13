using module ..\Include.psm1

class Cast : Miner {
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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000

        $Accepted_Shares = [Int64]$Data.shares.num_accepted
        $Rejected_Shares = [Int64]($Data.shares.num_rejected + $Data.shares.num_rejected + $Data.shares.num_network_fail + $Data.shares.num_outdated)

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