using module ..\Include.psm1

class SrbMiner : Miner {

    [String]GetArguments() {
        $Parameters = $this.Arguments | ConvertFrom-Json

        #Write config files. Keep separate files and do not overwrite to preserve optional manual customization
        $ConfigFile = "config_$($this.Name)-$($this.Algorithm -join '-')-$($this.DeviceModel).txt"
        if (-not (Test-Path "$(Split-Path $this.Path)\$ConfigFile")) {
            $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $this.Path)\$ConfigFile" -ErrorAction Ignore -Encoding UTF8
        }

        #Write pool file. Keep separate files
        $PoolFile = "pools_$($this.Pool)-$($this.Algorithm -join '-').txt"
        $Parameters.Pools | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $this.Path)\$PoolFile" -Force -ErrorAction Ignore -Encoding UTF8

        return "--config $ConfigFile --pools $PoolFile $($Parameters.Params)".Trim()
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [double]$Data.HashRate_total_5min
        if (-not $HashRate_Value) {$HashRate_Value = [double]$Data.HashRate_total_now}

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}
        }

        $this.Data.Add([PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
            Device   = @()
        })>$null

        $this.CleanupMinerData()

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}