using module ..\Include.psm1

class EthminerWrapper : Miner {
    [Double]$Difficulty_Value = 0.0

    [Void]UpdateMinerData () {
        if ($this.Process.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $this.Process | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple) {
                    if ($Line_Simple -match "^\s+i\s+.+?Difficulty\s*:\s*([\d\.\,]+?)\s*([hkMGT]+)") {
                        $this.Difficulty_Value  = [double]($Matches[1] -replace ',','.') * $(Switch ($Matches[2]) {
                            "Th" {1e12}
                            "Gh" {1e9}
                            "Mh" {1e6}
                            "kh" {1e3}
                            default {1}
                        })
                    } elseif ($Line_Simple -match "^\s+m\s+(.+)$") {
                        $Line_Cols = $Matches[1] -split '\s+'
                        $HashRate   = [PSCustomObject]@{}
                        $Difficulty = [PSCustomObject]@{}

                        $HashRate_Value  = [double]($Line_Cols[4] -replace ',','.') * $(Switch ($Line_Cols[5]) {
                            "Th" {1e12}
                            "Gh" {1e9}
                            "Mh" {1e6}
                            "kh" {1e3}
                            default {1}
                        })

                        $Accepted_Shares = [Int64]$(if ($Line_Cols[3] -match "A(\d+)") {$Matches[1]})
                        $Rejected_Shares = [Int64]0

                        if ($HashRate_Value -gt 0) {
                            $HashRate   | Add-Member @{$HashRate_Name = $HashRate_Value}
                            $Difficulty | Add-Member @{$HashRate_Name = $this.Difficulty_Value}
                            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                        }

                        $this.AddMinerData([PSCustomObject]@{
                            Raw        = $Line_Simple
                            HashRate   = $HashRate
                            Difficulty = $Difficulty
                            Device = @()
                        })
                    }
                }
            }

            $this.CleanupMinerData()
        }
    }
}