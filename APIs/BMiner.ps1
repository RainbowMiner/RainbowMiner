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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status/solver" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $Data.devices.PSObject.Properties.Value.solvers | ForEach-Object {
            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_.algorithm))
            if ( $HashRate_Name ) {                    
                if ( $_.algorithm -eq "equihash" ) {$HashRate_Value = [Double]$_.speed_info.solution_rate}
                else {$HashRate_Value = [Double]$_.speed_info.hash_rate}
                if ( Get-Member -inputobject $HashRate -name $HashRate_Name ) {
                    $HashRate.$HashRate_Name += [Int64]$HashRate_Value
                } else {
                    $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
                }
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