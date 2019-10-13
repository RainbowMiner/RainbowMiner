using module ..\Include.psm1

class SrbMiner : Miner {

    [String]GetArguments() {
        if ($this.Arguments -notlike "{*}") {return $this.Arguments}

        $Parameters = $this.Arguments | ConvertFrom-Json

        #Write config files. Keep separate files and do not overwrite to preserve optional manual customization
        $Threads = $Parameters.Config.gpu_conf.threads | Select-Object -Unique
        $ConfigFile = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($Threads -and $Threads -gt 1) {"-$($Threads)"}).txt"
        if (-not (Test-Path "$(Split-Path $this.Path)\$ConfigFile")) {
            $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content "$(Join-Path (Split-Path $this.Path) $ConfigFile)" -ErrorAction Ignore -Encoding UTF8
        }

        #Write pool file. Keep separate files
        $PoolFile = "pools_$($this.Pool)-$($this.BaseAlgorithm -join '-').txt"
        $Parameters.Pools | ConvertTo-Json -Depth 10 | Set-Content "$(Join-Path (Split-Path $this.Path) $PoolFile)" -Force -ErrorAction Ignore -Encoding UTF8

        return "$(if ($Parameters.CPar) {$Parameters.CPar} else {"--config"}) $ConfigFile $(if ($Parameters.PPar) {$Parameters.PPar} else {"--pools"}) $PoolFile $($Parameters.Params)".Trim()
    }

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
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares = [Int64]$Data.shares.accepted
        $Rejected_Shares = [Int64]$Data.shares.rejected

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [double]$Data.HashRate_total_5min
        if (-not $HashRate_Value) {$HashRate_Value = [double]$Data.HashRate_total_now}

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        })

        $this.CleanupMinerData()
    }
}