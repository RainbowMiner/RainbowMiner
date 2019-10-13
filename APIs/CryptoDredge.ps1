using module ..\Include.psm1

class CryptoDredge : Miner {
    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "127.0.0.1"
        $Timeout = 10 #seconds

        $Request = "summary"
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        try {
            $Response = Invoke-TcpRequest $Server $this.Port $Request -Timeout $Timeout -DoNotSendNewline -ErrorAction Stop -Quiet
            $Data = $Response -split ";" | ConvertFrom-StringData -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }

        $HashRate_Name = $this.Algorithm[0]
        $HashRate_Value = [Double]$Data.KHS * 1000

        $Accepted_Shares = [Int64]($Data.ACC | Measure-Object -Sum).Sum
        $Rejected_Shares = [Int64]($Data.REJ | Measure-Object -Sum).Sum

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