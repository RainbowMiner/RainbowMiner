function convertx($in) {
    Write-Host '$Commands = [PSCustomObject[]]@('
    $lines = [String[]]@([String[]]@($in -split "[\r\n]+") | Foreach-Object {        
        $l = $_.Trim()
        if ($l -eq '') {'{nl}'}
        elseif ($l -notmatch '\$commands' -and $_ -ne '}') {
            if ($l -match '^(.*?)"(.+?)"\s*=\s*"(.*?)"(.*?)$') {
                '    '+$matches[1]+'[PSCustomObject]@{MainAlgorithm = "'+$matches[2]+'"; Params = "'+$matches[3]+'"}{comma}'+$matches[4]
            }
            elseif ($l -match '^(.*?)"(.+?)"\s*=\s*(@\(.*?\))(.*?)$') {
                '    '+$matches[1]+'[PSCustomObject]@{MainAlgorithm = "'+$matches[2]+'"; Params = '+$matches[3]+'}{comma}'+$matches[4]
            } else {
                '    '+$l
            }
        }
    })
    $lines[$lines.Count-1] = $lines[$lines.Count-1] -replace '{comma}',''
    $lines | Foreach-Object {Write-Host $($_ -replace '{comma}',',' -replace '{nl}',"")}
    Write-Host ')'
}