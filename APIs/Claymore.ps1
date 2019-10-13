using module ..\Include.psm1

class Claymore : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = @{id = 1; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress
        $Response = ""

        $HashRate   = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -ErrorAction Stop -Quiet
            $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            if (-not $Data -or -not $Data.result -or -not $Data.result[2]) {throw}
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }

        $HashRate_Name = [String]$this.Algorithm[0]

        $HashRate_Value   = [Double]($Data.result[2] -split ";")[0]
        $Accepted_Shares  = [Int64]($Data.result[2] -split ";")[1]
        $Rejected_Shares  = [Int64]($Data.result[2] -split ";")[2]
        $Accepted_Shares -= $Rejected_Shares

        if ($this.Algorithm -like "ethash*" -and $Data.result[0] -notmatch "^TT-Miner") {$HashRate_Value *= 1000}
        if ($this.Algorithm -like "progpow*" -and $Data.result[0] -notmatch "^TT-Miner") {$HashRate_Value *= 1000}
        if ($this.Algorithm -eq "neoscrypt") {$HashRate_Value *= 1000}

        $HashRate_Value = [Int64]$HashRate_Value

        if ($HashRate_Name -and $HashRate_Value -gt 0) {
            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
        }

        if ($this.Algorithm[1]) {
            $HashRate_Name = [String]$this.Algorithm[1]

            $HashRate_Value = [Double]($Data.result[4] -split ";")[0]
            $Accepted_Shares = [Int64]($Data.result[4] -split ";")[1]
            $Rejected_Shares = [Int64]($Data.result[4] -split ";")[2]
            $Accepted_Shares -= $Rejected_Shares

            if ($this.Algorithm -like "ethash*" -and $Data.result[0] -notmatch "^TT-Miner") {$HashRate_Value *= 1000}
            if ($this.Algorithm -like "progpow*" -and $Data.result[0] -notmatch "^TT-Miner") {$HashRate_Value *= 1000}
            if ($this.Algorithm -eq "neoscrypt") {$HashRate_Value *= 1000}

            if ($HashRate_Name -and $HashRate_Value -gt 0) {
                $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                $this.UpdateShares(1,$Accepted_Shares,$Rejected_Shares)
            }
        }

        $this.AddMinerData([PSCustomObject]@{
            Raw      = $Response
            HashRate = $HashRate
            Device   = @()
        })

        $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)

        $this.CleanupMinerData()
    }
}