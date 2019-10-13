using module ..\Include.psm1

class Nanominer : Miner {

    [String]GetArguments() {
        $Miner_Path = Split-Path $this.Path
        $Parameters = $this.Arguments | ConvertFrom-Json
        $ConfigFile = "config_$($this.Pool -join '-')-$($this.BaseAlgorithm -join '-')-$($this.DeviceModel)$(if ($Parameters.SSL){"-ssl"}).txt"

        if (Test-Path $this.Path) {
            $FileC = @(
                ";Automatic config file created by RainbowMiner",
                ";Do not edit!",
                "mport=-$($this.Port)",
                "webPort = 0",
                "Watchdog = false",
                "noLog = true",
                "",
                "[$($Parameters.Algo)]",
                "wallet=$($Parameters.Wallet)",
                "rigName=$($Parameters.Worker)",
                "pool1 = $($Parameters.Host):$($Parameters.Port)",
                "devices =$(if ($Parameters.Devices -ne $null) {$Parameters.Devices -join ','})"
            )
            if ($Parameters.PaymentId -ne $null) {$FileC += "paymentId=$($Parameters.PaymentId)"}
            if ($Parameters.Pass)                {$FileC += "rigPassword=$($Parameters.Pass)"}
            if ($Parameters.Email)               {$FileC += "email=$($Parameters.Email)"}
            if ($Parameters.Threads)             {$FileC += "cpuThreads = $($Parameters.Threads)"}

            $FileC | Out-File "$($Miner_Path)\$($ConfigFile)" -Encoding utf8
        }

        return $ConfigFile
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]

        $HashRate_Value = [Double]($Data.result[2] -split ";")[0]
        $Accepted_Shares = [Int64]($Data.result[2] -split ";")[1]
        $Rejected_Shares = [Int64]($Data.result[2] -split ";")[2]
        $Accepted_Shares -= $Rejected_Shares

        if ($this.Algorithm -like "ethash*") {$HashRate_Value *= 1000}

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