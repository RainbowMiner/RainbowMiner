param($Parameters)


$text = ''
$count = 0

[hashtable]$JsonUri_Dates = @{}
[hashtable]$Miners_List = @{}
$API.Miners | Select-Object BaseName,Name,Path,HashRates,DeviceModel | Foreach-Object {                                
                        
    if (-not $JsonUri_Dates.ContainsKey($_.BaseName)) {
        $JsonUri = (Split-Path $_.Path) + "\_uri.json"
        $JsonUri_Dates[$_.BaseName] = if (Test-Path $JsonUri) {(Get-ChildItem $JsonUri).LastWriteTime.ToUniversalTime()} else {$null}
    }
    [String]$Algo = $_.HashRates.PSObject.Properties.Name | Select -First 1
    [String]$SecondAlgo = ''
    if (($_.HashRates.PSObject.Properties.Name | Measure-Object).Count -gt 1) {
        $SecondAlgo = $_.HashRates.PSObject.Properties.Name | Select -Index 1
    }
                            
    $Miners_Key = "$($_.Name)-$($Algo)"
    if ($JsonUri_Dates[$_.BaseName] -ne $null -and -not $Miners_List.ContainsKey($Miners_Key)) {
        $Miners_List[$Miners_Key] = $true                            
        $Miners_Path = Get-ChildItem ".\Stats\Miners\*$($_.Name)_$($Algo)_HashRate.txt"

        if ($Miners_Path -and $Miners_Path.LastWriteTime.ToUniversalTime() -lt $JsonUri_Dates[$_.BaseName]) {
            $Miners_Path | Remove-Item -ErrorAction Ignore
            $text += "$($_.Name -replace '-GPU.+$')/$($_.DeviceModel)/$($Algo)`n"
            $count++
            if ($SecondAlgo -ne '') {
                Remove-Item ".\Stats\Miners\*$($_.Name)_$($SecondAlgo)_HashRate.txt" -ErrorAction Ignore
            }
        }

    }
}

Write-Output "Removed $count stat files:"
Write-Output "<pre>"
$text | Write-Output
Write-Output "</pre>"