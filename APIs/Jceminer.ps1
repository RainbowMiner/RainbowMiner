using module ..\Include.psm1

class Jceminer : Miner {

    [String]GetArguments() {
        $Parameters = $this.Arguments | ConvertFrom-Json

        $Params = ""
        if ($Parameters.Config -ne $null) {
            #Write config files. Keep separate files and do not overwrite to preserve optional manual customization

            if ($this.DeviceModel -match "CPU") {
                $ConfigFile = "config_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).txt"
                $ConfigFileExample = "config_$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).example.txt"
            } else {
                $ConfigFile = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).txt"
                $ConfigFileExample = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel).example.txt"                
            }

            if (-not (Test-Path "$(Split-Path $this.Path)\$ConfigFile") -and $this.DeviceModel -match "CPU") {
                ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{\s*" -replace "\s*}$" | Set-Content "$(Split-Path $this.Path)\$ConfigFile" -ErrorAction Ignore -Encoding UTF8
            }
            ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{\s*" -replace "\s*}$" | Set-Content "$(Split-Path $this.Path)\$ConfigFileExample" -ErrorAction Ignore -Encoding UTF8 -Force
            $Params = if (Test-Path "$(Split-Path $this.Path)\$ConfigFile") {"-c $ConfigFile"} else {"--auto"}
        }

        return "$Params $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

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
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Difficulty_Value = [Double]$Data.results.diff_current
        $Accepted_Shares  = [Double]$Data.results.shares_good
        $Rejected_Shares  = [Double]($Data.results.shares_total - $Data.results.shares_good)

        $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $Data.algo))
        if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
        if (-not $HashRate_Name) {$HashRate_Name = [String]$this.Algorithm[0]} #fireice fix
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
    }
}