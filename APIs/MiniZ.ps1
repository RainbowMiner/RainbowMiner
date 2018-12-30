using module ..\Include.psm1

class MiniZ : Miner {
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
            $Response = (Invoke-WebRequest "http://$($Server):$($this.Port)" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop).Content
            $HashRate_Value = if (($Response -split 'Total')[1] -match "Sol/s[^\d\.]+([\d\.]+)") {[Double]$Matches[1]}
            if ($HashRate_Value -eq $null) {Throw "Invalid response"}
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }
        $Global:ProgressPreference = $oldProgressPreference

        $HashRate_Name = [String]$this.Algorithm[0]
        
        $HashRate_Value = [Int64]$HashRate_Value
        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.AddMinerData([PSCustomObject]@{
                Date     = (Get-Date).ToUniversalTime()
                Raw      = $Response
                HashRate = $HashRate
                PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
                Device   = @()
            })
        }

        $this.CleanupMinerData()

        return @($Request, "")
    }
}