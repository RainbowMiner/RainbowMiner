param($Parameters)

$text = ""
$count = 0

Get-ChildItem "Stats\Miners" -File | Where-Object {$_.Name -like '*HashRate.txt'} | Foreach-Object {
    $FileName = $_.FullName

    $Stats = $null

    try {
        $Stats = Get-Content $Filename | ConvertFrom-Json -ErrorAction Stop
    } catch {
    }
    if (-not $Stats.Minute) {
        Remove-Item $FileName
        $text += "$($_.Name)`n"
        $count++
    }
}  

Write-Output "Removed $count stat files:"
Write-Output "<pre>"
$text | Write-Output
Write-Output "</pre>"