using module ..\Include.psm1

class BMiner : Miner {
    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "127.0.0.1"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $ApiURI = if ($this.Name -like "Bminer7*") {"/api/status"}else{"/api/v1/status/solver"}
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)$($ApiURI)" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        if ($this.Name -like "Bminer7*") {
            # Legacy API for bminer upto version 7.0.0
            $HashRate_Name = [String]$this.Algorithm[0]
            $HashRate_Value = [Double]($Data.miners | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {$Data.miners.$_.solver.solution_rate} | Measure-Object -Sum).Sum
            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
        } else {
            # API for bminer starting version 8.0.0
            $Data.devices.PSObject.Properties.Value.solvers | ForEach-Object {
                $HashRate_Name = Get-Algorithm $_.algorithm
                $HashRate_Value = if ($_.speed_info.solution_rate) {[Double]$_.speed_info.solution_rate} else {[Double]$_.speed_info.hash_rate}
                if (Get-Member -inputobject $HashRate -name $HashRate_Name) {$HashRate.$HashRate_Name += [Int64]$HashRate_Value} else {$HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}}
            }
        }

        $this.Data += [PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        }

        $this.Data = @($this.Data | Select-Object -Last 10000)

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}