using module ..\Include.psm1

class GrinPro : Miner {

    [String]GetArguments() {
        $Parameters = $this.Arguments | ConvertFrom-Json

        $ConfigPath = Join-Path $([IO.Path]::GetFullPath($this.Path) | Split-Path) "$($this.Pool -join '-')-$($this.DeviceModel)$(if ($Parameters.SSL){"-ssl"})"

        if (Test-Path $this.Path) {
            if (-not (Test-Path $ConfigPath)) {New-Item $ConfigPath -ItemType "directory" > $null}
            "<?xml version=`"1.0`" encoding=`"utf-8`"?>
<Config xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
  <PrimaryConnection>
    <ConnectionAddress>$($Parameters.Config.Host)</ConnectionAddress>
    <ConnectionPort>$($Parameters.Config.Port)</ConnectionPort>
    <Ssl>$(if ($Parameters.Config.SSL) {"true"} else {"false"})</Ssl>
    <Login>$($Parameters.Config.User)</Login>
    <Password>$($Parameters.Config.Pass)</Password>  
  </PrimaryConnection>
  <SecondaryConnection>
  </SecondaryConnection>
  <LogOptions>
    <FileMinimumLogLevel>WARNING</FileMinimumLogLevel>
    <ConsoleMinimumLogLevel>INFO</ConsoleMinimumLogLevel>
    <KeepDays>1</KeepDays>
    <DisableLogging>false</DisableLogging>
  </LogOptions>
  <CPUOffloadValue>0</CPUOffloadValue>
  <GPUOptions>$($Parameters.Device | Foreach-Object {"
    <GPUOption>
        <GPUName>$($_.Name)</GPUName>
        <GPUType>$($_.Vendor)</GPUType>
        <DeviceID>$($_.Index)</DeviceID>
        <PlatformID>$($_.PlatformId)</PlatformID>
        <Enabled>true</Enabled>
    </GPUOption>"})
  </GPUOptions>
</Config>" | Out-File "$($ConfigPath)\config.xml" -Encoding utf8
        }

        return "configpath=$ConfigPath $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.GetStatus() -ne [MinerStatus]::Running) {return}

        $Server = "localhost"
        $Timeout = 10 #seconds

        $Request = ""
        $Response = ""

        $HashRate = [PSCustomObject]@{}

        $oldProgressPreference = $Global:ProgressPreference
        $Global:ProgressPreference = "SilentlyContinue"
        try {
            $Response = Invoke-WebRequest "http://$($Server):$($this.Port)/api/status" -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
            if ($Response.StatusCode -ne 200) {throw}
            $Data = $Response.Content | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Level Info "Failed to connect to miner ($($this.Name)). "
            return
        }
        $Global:ProgressPreference = $oldProgressPreference

        $Accepted_Shares = [Int64]$Data.shares.accepted
        $Rejected_Shares = [Int64]($Data.shares.submitted - $Data.shares.accepted)

        $HashRate_Name = [String]$this.Algorithm[0]
        $HashRate_Value = [Double]($Data.workers | Where-Object status -eq "ONLINE" | Select-Object -ExpandProperty graphsPerSecond | Measure-Object -Sum).Sum

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