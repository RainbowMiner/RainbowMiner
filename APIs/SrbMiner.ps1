using module ..\Include.psm1

class SrbMiner : Miner {

    [String]GetArguments() {
        $Parameters = $this.Arguments | ConvertFrom-Json

        #Write config files. Keep separate files and do not overwrite to preserve optional manual customization
        $ConfigFile = "$(Split-Path $this.Path)\Config_$($this.Name)-$($this.Algorithm)-$($this.Port).txt"
        $Parameters.Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -ErrorAction Ignore

        #Write pool file. Keep separate files
        $PoolFile = "$(Split-Path $this.Path)\Pools_$($this.Pool)-$($this.Algorithm).txt"
        $Parameters.Pools | ConvertTo-Json -Depth 10 | Set-Content $PoolFile -Force -ErrorAction SilentlyContinue

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

        $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

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