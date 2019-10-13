using module ..\Include.psm1

class Xgminer : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate   = [PSCustomObject]@{}
        $Difficulty = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response.Substring($Response.IndexOf("{"), $Response.LastIndexOf("}") - $Response.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }

        $Difficulty_Value = [Double]$Data.SUMMARY.Difficulty_Accepted
        $Accepted_Shares  = [Int64]$Data.SUMMARY.accepted
        $Rejected_Shares  = [Int64]$Data.SUMMARY.rejected

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = if ($Data.SUMMARY.HS_5s) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow(1000, 0)}
        elseif ($Data.SUMMARY.KHS_5s) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow(1000, 1)}
        elseif ($Data.SUMMARY.MHS_5s) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow(1000, 2)}
        elseif ($Data.SUMMARY.GHS_5s) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow(1000, 3)}
        elseif ($Data.SUMMARY.THS_5s) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow(1000, 4)}
        elseif ($Data.SUMMARY.PHS_5s) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow(1000, 5)}
        elseif ($Data.SUMMARY.HS_av) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow(1000, 0)}
        elseif ($Data.SUMMARY.KHS_av) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow(1000, 1)}
        elseif ($Data.SUMMARY.MHS_av) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow(1000, 2)}
        elseif ($Data.SUMMARY.GHS_av) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow(1000, 3)}
        elseif ($Data.SUMMARY.THS_av) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow(1000, 4)}
        elseif ($Data.SUMMARY.PHS_av) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow(1000, 5)}

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
    }
}