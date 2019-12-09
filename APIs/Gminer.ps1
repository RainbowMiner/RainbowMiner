using module ..\Include.psm1

class Gminer : Miner {

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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/stat" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        #$Version = if ($Data.miner -match "(\d\.[\d\.]+)") {$Matches[1]} else {$null}

        $Accepted_Shares = [Int64]($Data.devices.accepted_shares | Measure-Object -Sum).Sum
        $Rejected_Shares = [Int64]($Data.devices.rejected_shares | Measure-Object -Sum).Sum

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.devices.speed | Measure-Object -Sum).Sum

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            #if ($HashRate_Name -eq "Eaglesong" -and $Version -ne $null -and [version]$Version -le [version]"1.77") {$HashRate_Value /= 2}
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

            if ($this.Algorithm[1]) {
                $Accepted_Shares = [Int64]($Data.devices.accepted_shares2 | Measure-Object -Sum).Sum
                $Rejected_Shares = [Int64]($Data.devices.rejected_shares2 | Measure-Object -Sum).Sum

                $HashRate_Name = [String]$this.Algorithm[1]
                $HashRate_Value = [Double]($Data.devices.speed2 | Measure-Object -Sum).Sum

                if ($HashRate_Name -and $HashRate_Value -gt 0) {
                    #if ($HashRate_Name -eq "Eaglesong" -and $Version -ne $null -and [version]$Version -le [version]"1.78") {$HashRate_Value /= 2}
                    $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                    $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
                }
            }
        }

        $this.AddMinerData($Response,$HashRate)

        $this.CleanupMinerData()
    }
}