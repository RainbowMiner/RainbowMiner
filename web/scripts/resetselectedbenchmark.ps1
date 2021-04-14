param($Parameters)

$text = ''
$count = 0

if ($Parameters.name -and $Parameters.algorithm -and $Parameters.devicemodel) {
    for ($i=0; $i -lt $Parameters.name.Count; $i++) {
	    $Algorithm = $Parameters.algorithm[$i] -replace '-.+$'
	    if (($Parameters.name[$i] -replace '-GPU.+$' -split '-').Count -gt 2) {
		    $Algorithm = "*"
	    }

	    Get-ChildItem ".\Stats\Miners\*-$($Parameters.name[$i] -replace '-.+')-$($Parameters.name[$i] -replace '^.+?-' -replace '-','*')*_$($Algorithm)_HashRate.txt" -ErrorAction Ignore | Foreach-Object {
		    $count++
		    Remove-Item $_ -ErrorAction Ignore
		    $text += "$($_.BaseName -replace '-(C|G)PU.+$')/$($Parameters.devicemodel[$i])/$($_.BaseName -split '_' | Select-Object -Index 1)`n"
	    }
    }
}

Write-Output "Removed $($count) stat files:"
Write-Output "<pre>"
$text | Write-Output
Write-Output "</pre>"