using module ..\Include.psm1

class Excavator : Miner {
    [PSCustomObject]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error  "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $Data.algorithms.name | Select-Object -Unique | ForEach-Object {
            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix
            $HashRate_Value = [Double](($Data.algorithms | Where-Object name -EQ $_).workers.speed  | Measure-Object -Sum).Sum
            if ( $HashRate_Value -eq 0 ) {
                # New API as of Excavator v1.5.0a
                $HashRate_Value = [Double]($Data.algorithms | Where-Object name -EQ $_).speed
            }

            $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}                
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