using module ..\Include.psm1

class NBminer : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

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
            return @($Request, $Response)
        }
        $Global:ProgressPreference = $oldProgressPreference

        $HashRate_Name = [String]$this.Algorithm[0]

        $HashRate_Value = $Difficulty_Value = 0.0
        $Accepted_Shares = $Rejected_Shares = 0

        $Data.stratum | Select-Object -Index 0 | Foreach-Object {
            $Accepted_Shares  = [Int64]$_.accepted_shares
            $Rejected_Shares  = [Int64]$_.rejected_shares
            $Difficulty_Value = [Double](ConvertFrom-Hash($_.difficulty))
        }

        $HashRate_Value = [Double]$Data.miner.total_hashrate_raw

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($this.Algorithm[1]) {
                $HashRate_Name = [String]$this.Algorithm[1]

                $HashRate_Value = $Difficulty_Value = 0.0
                $Accepted_Shares = $Rejected_Shares = 0

                $HashRate_Value = [Double]$Data.miner.total_hashrate_raw2
                $Data.stratum | Select-Object -Index 1 | Foreach-Object {
                    $Accepted_Shares  = [Int64]$_.accepted_shares
                    $Rejected_Shares  = [Int64]$_.rejected_shares
                    $Difficulty_Value = [Double](ConvertFrom-Hash($_.difficulty))
                }

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

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}