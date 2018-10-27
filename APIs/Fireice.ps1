using module ..\Include.psm1

class Fireice : Miner {

    [String]GetArguments() {
        $Parameters = $this.Arguments | ConvertFrom-Json        
        $ConfigFile = "config_$($this.Name)-$($this.BaseAlgorithm -join '-')$(if ($Parameters.Config.pool_list[0].use_tls){"-ssl"}).txt"
        ($Parameters.Config | ConvertTo-Json -Depth 10) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $this.Path)\$ConfigFile" -ErrorAction Ignore -Encoding UTF8 -Force

        if ($this.DeviceModel -ne "CPU") {
            $Vendor = Get-Device $this.DeviceName[0] | Select-Object -ExpandProperty Vendor
            $DCFile = "$($Vendor.ToLower())-$($this.BaseAlgorithm -join '-').txt"
            $DCPath = Join-Path $(Split-Path $this.Path) $DCFile
            $DCFile0= "$($Vendor.ToLower()).txt"
            $DCPath0= Join-Path $(Split-Path $this.Path) $DCFile0
            if (-not (Test-Path $DCPath) -and (Test-Path $DCPath0)) {Copy-Item $DCPath0 $DCPath -Force} #legacy
            $DCFile = "-$($Vendor.ToLower()) $DCFile "
        } else {
            $DCFile = ""
        }

        return "-C $ConfigFile $DCFile$($Parameters.Params)".Trim()
    }

    [String[]]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return @()}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api.json" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Error "Failed to connect to miner ($($this.Name)). "
            return @($Request, $Response)
        }

        $HashRate_Name = [String]($this.Algorithm -like (Get-Algorithm $Data.algo))
        if (-not $HashRate_Name) {$HashRate_Name = [String]($this.Algorithm -like "$(Get-Algorithm $Data.algo)*")} #temp fix
        if (-not $HashRate_Name) {$HashRate_Name = [String]$this.Algorithm[0]} #fireice fix
        $HashRate_Value = [Double]$Data.hashrate.total[0]
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[1]} #fix
        if (-not $HashRate_Value) {$HashRate_Value = [Double]$Data.hashrate.total[2]} #fix

        $HashRate | Where-Object {$HashRate_Name} | Add-Member @{$HashRate_Name = [Int64]$HashRate_Value}

        $this.AddMinerData([PSCustomObject]@{
            Date     = (Get-Date).ToUniversalTime()
            Raw      = $Response
            HashRate = $HashRate
            PowerDraw = Get-DevicePowerDraw -DeviceName $this.DeviceName
            Device   = @()
        })

        $this.CleanupMinerData()

        return @($Request, $Data | ConvertTo-Json -Compress)
    }
}