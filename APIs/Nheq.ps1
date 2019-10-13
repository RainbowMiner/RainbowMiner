using module ..\Include.psm1

class Nheq : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = "status"
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }

        $RunningMinutes = ($this.GetRunningTime()).TotalMinutes
        $Accepted_Shares = [Double]($Data.result.accepted_per_minute | Measure-Object -Sum).Sum * $RunningMinutes
        $Rejected_Shares = [Double]($Data.result.rejected_per_minute | Measure-Object -Sum).Sum * $RunningMinutes

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.result.speed_ips | Measure-Object -Sum).Sum * 1e6
        
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