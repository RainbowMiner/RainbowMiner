using module ..\Include.psm1

class SwapminerWrapper : Miner {

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
    <FileMinimumLogLevel>$(if ($Parameters.LogOptions.FileMinimumLogLevel) {$Parameters.LogOptions.FileMinimumLogLevel} else {"INFO"})</FileMinimumLogLevel>
    <ConsoleMinimumLogLevel>$(if ($Parameters.LogOptions.ConsoleMinimumLogLevel) {$Parameters.LogOptions.ConsoleMinimumLogLevel} else {"INFO"})</ConsoleMinimumLogLevel>
    <KeepDays>1</KeepDays>
    <DisableLogging>false</DisableLogging>
  </LogOptions>
  <CPUOffloadValue>$([int]$Parameters.CPUOffloadValue)</CPUOffloadValue>
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

        return "configpath=$ConfigPath mode=rolling $($Parameters.Params)".Trim()
    }

    [Void]UpdateMinerData () {
        if ($this.Process.HasMoreData) {
            $HashRate_Name = $this.Algorithm[0]

            $this.Process | Receive-Job | ForEach-Object {
                $Line = $_ -replace "`n|`r", ""
                $Line_Simple = $Line -replace "\x1B\[[0-?]*[ -/]*[@-~]", ""
                if ($Line_Simple) {

                    if ($Line_Simple -match "Results: ([\d\.,]+).*gps.+sub:(\d+).+acc:(\d+).+rej:(\d+)") {
                        $HashRate = [PSCustomObject]@{}

                        $HashRate_Value  = [double]($Matches[1] -replace ',','.')

                        $Accepted_Shares = [Int64]$Matches[3]
                        $Rejected_Shares = [Int64]$Matches[4]

                        if ($HashRate_Value -gt 0) {
                            $HashRate | Add-Member @{$HashRate_Name = $HashRate_Value}
                            $this.UpdateShares(0,$Accepted_Shares,$Rejected_Shares)
                        }

                        $this.AddMinerData([PSCustomObject]@{
                            Raw = $Line_Simple
                            HashRate = $HashRate                          
                            Device = @()
                        })
                    }
                }
            }

            $this.CleanupMinerData()
        }
    }
}