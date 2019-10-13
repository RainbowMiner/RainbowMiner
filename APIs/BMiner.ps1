using module ..\Include.psm1

class BMiner : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status/solver" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/v1/status/stratum" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data | Add-member stratums ($Response | ConvertFrom-Json -ErrorAction Stop).stratums
        }
        catch {}
        $Global:ProgressPreference = $oldProgressPreference

        $Index = 0
        $this.Algorithm | Select-Object -Unique | ForEach-Object {
            $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $_))
            if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $_)*")} #temp fix

            $HashRate_Value = 0.0

            $Accepted_Shares = [Int64]$Data.stratums.$_.accepted_shares
            $Rejected_Shares = [Int64]$Data.stratums.$_.rejected_shares

            $Data.devices | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {
                $Data.devices.$_.solvers | Where-Object {$HashRate_Name -like "$(Get-Algorithm $_.Algorithm)*"} | ForEach-Object {
                    if ($_.speed_info.hash_rate) {$HashRate_Value += [Double]$_.speed_info.hash_rate}
                    else {$HashRate_Value += [Double]$_.speed_info.solution_rate}
                }
            }
            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                $this.UpdateShares($Index,$Accepted_Shares,$Rejected_Shares)
            }
            $Index++
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        })

        $this.CleanupMinerData()
    }
}