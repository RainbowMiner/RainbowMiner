
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
			if ($QueryString -and $Query) {
				$Properties | Add-Member $Query $QueryString
			}
		}

        if($Request.HasEntityBody -and $Request.HttpMethod -in @("POST","PUT")) {
	        $PostCommand = New-Object IO.StreamReader ($InputStream,$ContentEncoding)
	        $PostCommand = $PostCommand.ReadToEnd()
	        $PostCommand = $PostCommand.ToString()
	
	        if ($PostCommand) {
		        $PostCommand = $PostCommand -replace('\+'," ")
		        $PostCommand = $PostCommand -replace("%20"," ")
		        $PostCommand = $PostCommand -replace("%21","!")
		        $PostCommand = $PostCommand -replace('%22','"')
		        $PostCommand = $PostCommand -replace("%23","#")
		        $PostCommand = $PostCommand -replace("%24","$")
		        $PostCommand = $PostCommand -replace("%25","%")
		        $PostCommand = $PostCommand -replace("%27","'")
		        $PostCommand = $PostCommand -replace("%28","(")
		        $PostCommand = $PostCommand -replace("%29",")")
		        $PostCommand = $PostCommand -replace("%2A","*")
		        $PostCommand = $PostCommand -replace("%2B","+")
		        $PostCommand = $PostCommand -replace("%2C",",")
		        $PostCommand = $PostCommand -replace("%2D","-")
		        $PostCommand = $PostCommand -replace("%2E",".")
		        $PostCommand = $PostCommand -replace("%2F","/")
		        $PostCommand = $PostCommand -replace("%3A",":")
		        $PostCommand = $PostCommand -replace("%3B",";")
		        $PostCommand = $PostCommand -replace("%3C","<")
		        $PostCommand = $PostCommand -replace("%3E",">")
		        $PostCommand = $PostCommand -replace("%3F","?")
		        $PostCommand = $PostCommand -replace("%5B","[")
		        $PostCommand = $PostCommand -replace("%5C","\")
		        $PostCommand = $PostCommand -replace("%5D","]")
		        $PostCommand = $PostCommand -replace("%5E","^")
		        $PostCommand = $PostCommand -replace("%5F","_")
		        $PostCommand = $PostCommand -replace("%7B","{")
		        $PostCommand = $PostCommand -replace("%7C","|")
		        $PostCommand = $PostCommand -replace("%7D","}")
		        $PostCommand = $PostCommand -replace("%7E","~")
		        $PostCommand = $PostCommand -replace("%7F","_")
		        $PostCommand = $PostCommand -replace("%7F%25","%")
		        $PostCommand = $PostCommand.Split("&")

		        foreach ($Post in $PostCommand) {
			        $PostValue = $Post.Replace("%26","&")
			        $PostContent = $PostValue.Split("=")
			        $PostName = $PostContent[0] -replace("%3D","=")
			        $PostValue = $PostContent[1] -replace("%3D","=")

			        if ($PostName.EndsWith("[]")) {
				        $PostName = $PostName.Substring(0,$PostName.Length-2)
				        if ($Properties.$Postname -isnot [array]) {
					        $Properties | Add-Member $Postname (@()) -Force
					        $Properties."$PostName" += $PostValue
				        } else {
					        $Properties."$PostName" += $PostValue
				        }
			        } else {
				        $Properties | Add-Member $PostName $PostValue -Force
			        }
		        }
            }
        }

		$Properties
	}
}
