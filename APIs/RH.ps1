using module ..\Include.psm1

class RH : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = " "
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

        $Accepted_Shares = [Double]($Data.infos.accepted | Measure-Object -Sum).Sum
        $Rejected_Shares = [Double]($Data.infos.rejected | Measure-Object -Sum).Sum

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.infos.speed | Measure-Object -Sum).Sum
        
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