param($Parameters)

$files = Get-ChildItem "Stats" -Recurse -File | Where-Object {$_.Name -like '*HashRate.txt'}

$count = $files.Count

$files | Foreach-Object {
  Remove-Item $_.FullName
}

Write-Output "Removed $count stats files"