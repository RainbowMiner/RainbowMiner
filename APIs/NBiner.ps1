using module ..\Include.psm1

class NBminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $HashRate_Name = [String]$this.Algorithm[0]

        $HashRate_Value = $Difficulty_Value = 0.0
        $Accepted_Shares = $Rejected_Shares = 0

        $Accepted_Shares  = [Int64]$Data.stratum.accepted_shares
        $Rejected_Shares  = [Int64]$Data.stratum.rejected_shares
        $Difficulty_Value = [Double](ConvertFrom-Hash($Data.stratum.difficulty))

        $HashRate_Value = [Double]$Data.miner.total_hashrate_raw

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($this.Algorithm[1]) {
                $HashRate_Name = [String]$this.Algorithm[1]

                $HashRate_Value = $Difficulty_Value = 0.0
                $Accepted_Shares = $Rejected_Shares = 0

                $HashRate_Value = [Double]$Data.miner.total_hashrate2_raw
                $Accepted_Shares  = [Int64]$Data.stratum.accepted_shares2
                $Rejected_Shares  = [Int64]$Data.stratum.rejected_shares2
                $Difficulty_Value = [Double](ConvertFrom-Hash($Data.stratum.difficulty2))

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
                    $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
                }
            }
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw        = $Response
            HashRate   = $HashRate
            Difficulty = $Difficulty
            Device     = @()
        })

        $this.CleanupMinerData()
    }
}