[Flags()]
enum PauseStatus {
    None        = 0
    ByUser      = 1
    ByScheduler = 2
    ByActivity  = 4
    ByBattery   = 8
    ByError     = 16
}

class PauseMiners {
    static [PauseStatus]$IA = [PauseStatus]::ByUser -bor [PauseStatus]::ByError

    [PauseStatus]$Status = [PauseStatus]::None

    PauseMiners() {}

    [bool]Test() {
        return $this.Status -ne [PauseStatus]::None
    }

    [bool]Test([PauseStatus]$Pause) {
        return ($this.Status -band $Pause) -ne 0
    }

    [bool]TestIA() {
        return ($this.Status -band [PauseMiners]::IA) -ne 0
    }

    [bool]TestIAOnly() {
        return (($this.Status -band [PauseMiners]::IA) -ne 0) -and (($this.Status -band (-bnot [PauseMiners]::IA)) -eq 0)
    }

    [void]Reset() {
        $this.Status = [PauseStatus]::None
    }

    [void]Reset([PauseStatus]$Pause) {
        $this.Status = $this.Status -band (-bnot $Pause)
    }

    [void]ResetIA() {
        $this.Status = $this.Status -band (-bnot [PauseMiners]::IA)
    }

    [void]Set([PauseStatus] $Pause) {
        $this.Status = $this.Status -bor $Pause
    }

    [void]Set([PauseStatus] $Pause, [bool] $Value) {
        if ($Value) { $this.Set($Pause) } else { $this.Reset($Pause) }
    }

    [void]SetIA() {
        $this.Set([PauseStatus]::ByUser)
    }
}
