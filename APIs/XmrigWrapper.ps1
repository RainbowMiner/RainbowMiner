using module ..\Include.psm1

class XmrigWrapper : Miner {

    [String[]]UpdateMinerData () {
        $MJob = $this.GetMiningJob()
        if ($MJob.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $MJob | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple -match "^.+?(speed|accepted)\s+(.+?)$") {
                    $Mode  = $Matches[1]
                    $Words = $Matches[2] -split "\s+"
                    if ($Mode -eq "speed") {
                        $HashRate = [PSCustomObject]@{}
                        $Speed = if ($Words[2] -ne "n/a") {$Words[2]} else {$Words[1]}
                        $HashRate_Value  = [double]($Speed -replace ',','.')

                        switch -Regex ($Words[4]) {
                            "k" {$HashRate_Value *= 1E+3}
                            "M" {$HashRate_Value *= 1E+6}
                            "G" {$HashRate_Value *= 1E+9}
                            "T" {$HashRate_Value *= 1E+12}
                            "P" {$HashRate_Value *= 1E+15}
                        }

                        if ($HashRate_Value -gt 0) {
                            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                        }

                        $this.AddMinerData($Line_Simple,$HashRate)
                    } elseif ($Mode -eq "accepted" -and $Words[0] -match "(\d+)/(\d+)") {
                        $Accepted_Shares = [Int64]$Matches[1]
                        $Rejected_Shares = [Int64]$Matches[2]
                        $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                    }
                }
            }

            $this.CleanupMinerData()
        }

        return @()
    }
}