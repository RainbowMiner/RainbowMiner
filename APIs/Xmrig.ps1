using module ..\Include.psm1

class Xmrig : Miner {
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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api.json" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares  = [Double]$Data.results.shares_good
        $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)
        $Difficulty_Value = [Double]$Data.results.diff_current
        
        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
            $Difficulty | Add-Member @{$HashRate_Name = $Difficulty_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
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