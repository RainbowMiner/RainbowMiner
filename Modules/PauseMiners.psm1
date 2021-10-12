enum PauseStatus {
    ByUser
    ByScheduler
    ByActivity
    ByBattery
    ByError
}


class PauseMiners {
    [PauseStatus[]]$Status

    PauseMiners() {
        $this.Reset()
    }

    [bool]Test() {
        return $this.Status.Count -gt 0
    }

    [bool]Test([PauseStatus]$Pause) {
        return $this.Status -contains $Pause
    }

    [bool]TestIA() {
        return $this.Status.Count -gt 0 -and ($this.Status -contains [PauseStatus]::ByUser -or $this.Status -contains [PauseStatus]::ByError)
    }

    [bool]TestIAOnly() {
        return $this.Status.Count -gt 0 -and -not ((Compare-Object $this.Status @([PauseStatus]::ByUser,[PauseStatus]::ByError) | Where-Object SideIndicator -eq "<=" | Measure-Object).Count)
    }

    [void]Reset() {
        [PauseStatus[]]$this.Status = @()
    }

    [void]Reset([PauseStatus]$Pause) {
        if ($this.Status -contains $Pause) {$this.Status = $this.Status.Where({$_ -ne $Pause})}
    }

    [void]ResetIA() {
        if ($this.TestIA()) {$this.Status = $this.Status.Where({$_ -ne [PauseStatus]::ByUser -and $_ -ne [PauseStatus]::ByError})}
    }
    
    [void]Set([PauseStatus]$Pause) {
        if ($this.Status -notcontains $Pause) {$this.Status += $Pause}
    }

    [void]Set([PauseStatus]$Pause,[Bool]$Value) {
        if ($Value) {$this.Set($Pause)} else {$this.Reset($Pause)}
    }

    [void]SetIA() {
        $this.Set([PauseStatus]::ByUser)
    }
}