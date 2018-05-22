param([String]$Log = ".\.txt", [String]$Sort = "", [Switch]$QuickStart)

Set-Location (Split-Path $MyInvocation.MyCommand.Path)

$Active = @{}

while ($true) {
    Compare-Object @(Get-Job -ErrorAction Ignore | Select-Object -ExpandProperty Name) @(Get-ChildItem ".\Logs" -ErrorAction Ignore | Where-Object {(-not $QuickStart) -or ((Get-Date) - $_.LastWriteTime).TotalMinutes -le 1} | Select-Object -ExpandProperty Name) | 
        Sort-Object {$_.InputObject -replace $Sort} | 
        Where-Object InputObject -match $Log | 
        Where-Object SideIndicator -EQ "=>" | 
        ForEach-Object {$Active[(Start-Job ([ScriptBlock]::Create("Get-Content '$(Convert-Path ".\Logs\$($_.InputObject)")' -Wait$(if($QuickStart){" -Tail 1000"})")) -Name $_.InputObject).Id] = (Get-Date).ToUniversalTime()}

    Start-Sleep 1

    Get-Job | ForEach-Object {
        $out = (Receive-Job $_)
        if ( $out ) {$out; $Active[$_.Id] = (Get-Date).ToUniversalTime()}
        elseif ($Active[$_.Id] -lt (Get-Date).ToUniversalTime().AddMinutes(-10)) {$Active.Remove($_.Id); Remove-Job $_ -Force;}
    }

}