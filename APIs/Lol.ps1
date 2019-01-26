using module ..\Include.psm1

class Lol : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRead $Server 31702 $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @("", $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        try {
            $HashRate_Value = [Double]$Data.'TotalSpeed(60s)'
            if (-not $HashRate_Value) {throw}
        } catch {
            $HashRate_Value = [double]$Data.'TotalSpeed(5s)'
        }
        
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

        return @("", $Data | ConvertTo-Json -Compress)
    }
}