
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
                # Split the still-encoded POST data into key-value pairs first, then URL-decode each
                # token separately. Decoding before the split would corrupt values containing encoded
                # & or =, and the former unordered replacement map turned encoded plus signs into
                # spaces on some machines (issue #3095)
		        foreach ($Post in ($PostCommand -split "&")) {
			        $PostContent = $Post -split "=", 2

			        $PostName  = [System.Web.HttpUtility]::UrlDecode($PostContent[0])
			        $PostValue = [System.Web.HttpUtility]::UrlDecode($PostContent[1])

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