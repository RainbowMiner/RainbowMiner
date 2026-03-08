
function Get-MimeType {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$Extension
)
	Switch ($Extension) { 
        ".js"   {"application/x-javascript"}
        ".html" {"text/html"}
        ".htm"  {"text/html"}
        ".json" {"application/json"}
        ".css" {"text/css"}
        ".txt" {"text/plain"}
        ".ico" {"image/x-icon"}
        ".png" {"image/png"}
        ".jpg" {"image/jpeg"}
        ".gif" {"image/gif"}
        ".svg" {"image/svg+xml"}
        ".ps1" {"text/html"} # ps1 files get executed, assume their response is html
        ".7z"  {"application/x-7z-compressed”}
        ".zip" {"application/zip”}
        default {"application/octet-stream"}
    }
}

function Get-QueryParameters {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    $Request,
    [Parameter(Mandatory = $false)]
    $InputStream,
	[Parameter(Mandatory = $false)]
    $ContentEncoding
)
	if ($Request -and $InputStream -and $ContentEncoding) {

		$Properties = [PSCustomObject]@{}

		$QueryStrings = $Request.QueryString
		foreach ($Query in $QueryStrings) {
			$QueryString = $Request.QueryString["$Query"]
			if ($QueryString -and $Query -and $Query -ne "_") {
				$Properties | Add-Member $Query $QueryString
			}
		}

        if($Request.HasEntityBody -and $Request.HttpMethod -in @("POST","PUT")) {
	        $PostStreamReader = [System.IO.StreamReader]::new($InputStream, $ContentEncoding)

            try {
	            $PostCommand = $PostStreamReader.ReadToEnd()
            } catch {
            } finally {
                $PostStreamReader.Dispose()
                $PostStreamReader = $null
            }

	        if ($PostCommand) {
                # URL Decode common percent-encoded characters efficiently
                $decodeMap = @{
                    '+'  = " "; "%20" = " "; "%21" = "!" ; '%22' = '"'; "%23" = "#"; "%24" = "$"; "%25" = "%"; #"%26" = "&"; later!
                    "%27" = "'"; "%28" = "("; "%29" = ")"; "%2A" = "*"; "%2B" = "+"; "%2C" = ","; "%2D" = "-"; "%2E" = ".";
                    "%2F" = "/"; "%3A" = ":"; "%3B" = ";"; "%3C" = "<"; "%3E" = ">"; "%3F" = "?"; "%40" = "@"; #"%3D" = "="; later!
                    "%5B" = "["; "%5C" = "\"; "%5D" = "]"; "%5E" = "^"; "%5F" = "_"; "%7B" = "{"; "%7C" = "|"; "%7D" = "}";
                    "%7E" = "~"; "%7F" = "_"; "%7F%25" = "%"
                }

                # Perform URL decoding in a single pass
                foreach ($key in $decodeMap.Keys) {
                    $PostCommand = $PostCommand -replace [regex]::Escape($key), $decodeMap[$key]
                }

                $decodeMap = $null

                # Split POST Data into key-value pairs
                $PostCommand = $PostCommand -split "&"

		        foreach ($Post in $PostCommand) {
			        $PostValue = $Post -replace "%26","&"
			        $PostContent = $PostValue -split "=", 2

			        $PostName = $PostContent[0] -replace "%3D","="
			        $PostValue = $PostContent[1] -replace "%3D","="

                    if ($PostName -ne "_") {
			            if ([RBMToolBox]::EndsWith($PostName,"[]")) {
				            $PostName = [RBMToolBox]::Substring($PostName,0,$PostName.Length-2)
				            if ($Properties.$Postname -isnot [System.Collections.ArrayList]) {
					            $Properties | Add-Member $Postname ([System.Collections.ArrayList]@()) -Force
				            }
					        [void]$Properties.$PostName.Add($PostValue)
			            } else {
				            $Properties | Add-Member $PostName $PostValue -Force
			            }
                    }
		        }
            }
        }

		$Properties
	}
}

function Test-IPInRange {
    param(
        [string]$IP,
        [string]$Pattern
    )

    # CIDR-notation: IPv4 (10.0.0.0/24) or IPv6 (2001:db8::/32)
    if ($Pattern -match '^(.+)/(\d{1,3})$') {
        $NetworkStr = $Matches[1]
        $PrefixLen  = [int]$Matches[2]

        try {
            $NetworkAddr = [System.Net.IPAddress]::Parse($NetworkStr)
            $RemoteAddr  = [System.Net.IPAddress]::Parse($IP)

            if ($NetworkAddr.AddressFamily -ne $RemoteAddr.AddressFamily) {
                return $false
            }

            $NetworkBytes = $NetworkAddr.GetAddressBytes()
            $RemoteBytes  = $RemoteAddr.GetAddressBytes()
            $TotalBits    = $NetworkBytes.Length * 8   # IPv4: 32, IPv6: 128

            if ($PrefixLen -gt $TotalBits) { return $false }

            $FullBytes = [Math]::Floor($PrefixLen / 8)
            $RemBits   = $PrefixLen % 8

            for ($i = 0; $i -lt $FullBytes; $i++) {
                if ($NetworkBytes[$i] -ne $RemoteBytes[$i]) { return $false }
            }

            if ($RemBits -gt 0 -and $FullBytes -lt $NetworkBytes.Length) {
                $Mask = [byte](0xFF -shl (8 - $RemBits) -band 0xFF)
                if (($NetworkBytes[$FullBytes] -band $Mask) -ne
                    ($RemoteBytes[$FullBytes]  -band $Mask)) {
                    return $false
                }
            }

            return $true

        } catch {
            return $false
        }
    }

    return $IP -like $Pattern
}