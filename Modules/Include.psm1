#
# Basic functions
#

function Initialize-Session {
    [CmdletBinding()]
    param([switch]$Mini)

    Set-OsFlags -Mini:$Mini

    if (-not (Test-Path Variable:Global:Session)) {
        $Global:Session = [System.Collections.Hashtable]::Synchronized(@{})

        if ($IsWindows) {
            $Session.WindowsVersion = [System.Environment]::OSVersion.Version
            $Session.IsWin10        = [System.Environment]::OSVersion.Version -ge (Get-Version "10.0")
        } elseif ($IsLinux) {
            try {
                Get-ChildItem ".\IncludesLinux\bin\libc_version" -File -ErrorAction Stop | Foreach-Object {
                    (Start-Process "chmod" -ArgumentList "+x",$_.FullName -PassThru).WaitForExit(1000) > $null
                    $Session.LibCVersion = Get-Version "$(& $_.FullName)"
                }
            } catch {
            }
            $Session.LinuxDistroInfo = Get-LinuxDistroInfo
        }
        $Session.IsAdmin            = Test-IsElevated
        $Session.IsCore             = $PSVersionTable.PSVersion -ge (Get-Version "6.1")
        $Session.IsPS7              = $PSVersionTable.PSVersion -ge (Get-Version "7.0")
        $Session.MachineName        = [System.Environment]::MachineName
        $Session.MyIP               = Get-MyIP
        $Session.MainPath           = "$PWD"
        $Session.UnixEpoch          = [DateTime]::new(1970, 1, 1, 0, 0, 0, 0, ([System.DateTimeKind]::Utc))

        Set-Variable RegexAlgoHasEthproxy -Option Constant -Scope Global -Value "^Etc?hash|ProgPow|^Meraki|UbqHash"
        Set-Variable RegexAlgoHasDAGSize -Option Constant -Scope Global -Value "^Etc?hash|^KawPow|ProgPow|^FiroPow|^Meraki|UbqHash|Octopus"
        Set-Variable RegexAlgoIsEthash -Option Constant -Scope Global -Value "^Etc?hash|UbqHash"
        Set-Variable RegexAlgoIsProgPow -Option Constant -Scope Global -Value "^KawPow|ProgPow|^FiroPow|^Meraki"
    }
}

function Set-OsFlags {
    [CmdletBinding()]
    param([switch]$Mini)

    if ($Global:OsFlagsSet) { return }

    if ($Global:IsWindows -eq $null) {
        $Global:IsWindows = [System.Environment]::OSVersion.Platform -eq "Win32NT" -or [System.Boolean](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Ignore)
        $Global:IsLinux   = -not $IsWindows
        $Global:IsMacOS   = $false
    }

    $Global:7zip = if ($Global:IsWindows) {".\7z.exe"} else {"7z"}

    if ($Global:IsLinux) {
        $Global:OSArch = try {
            Switch -Regex ("$(uname -m)".Trim()) {
                "(i386|i686)" {"i386"; Break}
                "x86_64" {"amd64"; Break}
                "(arm|aarch64)" {if ("$(dpkg --print-architecture)" -match "arm64") {"arm64"} else {"arm"}; Break}
                default {$PSItem}
            }
        } catch {
            "amd64"
        }

        if (-not (Get-Command $Global:7zip -ErrorAction Ignore)) {
            $Path_7zz = ".\IncludesLinux\bin\7zz-$(if ($Global:OSArch -eq "arm") {"arm64"} else {$Global:OSArch})"
            if (Test-Path $Path_7zz) {
                $Global:7zip = $Path_7zz
                try {
                    Get-ChildItem $Global:7zip -File -ErrorAction Stop | Foreach-Object {
                        (Start-Process "chmod" -ArgumentList "+x",$_.FullName -PassThru).WaitForExit(1000) > $null
                    }
                } catch {
                }
            }
        }
    } elseif ($Global:IsWindows) {
        $Global:OSArch = if ([System.Environment]::Is64BitOperatingSystem) {"amd64"} else {"i386"}
    }

    if ("$((Get-Culture).NumberFormat.NumberGroupSeparator)$((Get-Culture).NumberFormat.NumberDecimalSeparator)" -notmatch "^[,.]{2}$") {
        [CultureInfo]::CurrentCulture = 'en-US'
    }

    if (-not (Get-Command "Start-ThreadJob" -ErrorAction Ignore)) {Set-Alias -Scope Global Start-ThreadJob Start-Job}

    if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
       [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    if (-not (Test-IsCore)) {
        Initialize-DLLs -CSFileName "SSL.cs"
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
    }

    if ($IsWindows -and -not $Mini) {
        Initialize-DLLs -CSFileName "CPUID.cs"
        Initialize-DLLs -CSFileName "UserInput.cs"
    }

    Initialize-DLLs -CSFileName "RBMToolBox.cs"

    $Global:OsFlagsSet = $true
}

function Get-LinuxDistroInfo {
    $distroName = $null
    $distroVersion = $null

    # Function to extract information from key-value pairs in a file
    function ParseKeyValueFile {
        param (
            [string]$FilePath,
            [string[]]$Keys
        )
        $result = @{}
        if (Test-Path $FilePath) {
            $content = Get-Content $FilePath | ForEach-Object {
                $parts = $_ -split '='
                $key = $parts[0]
                $value = $parts[1] -replace '"', '' -replace '\s+$', '' # remove quotes and trailing spaces
                if ($Keys -contains $key) {
                    $result[$key] = $value
                }
            }
        }
        return $result
    }

    try {

        # 1. Try /etc/os-release
        if (Test-Path "/etc/os-release") {
            $osRelease = ParseKeyValueFile "/etc/os-release" @('NAME', 'VERSION_ID')
            if ($osRelease['NAME']) {
                $distroName = $osRelease['NAME']
            }
            if ($osRelease['VERSION_ID']) {
                $distroVersion = $osRelease['VERSION_ID']
            }
        }

        # 2. Try /etc/lsb-release (common on Ubuntu and some Debian derivatives)
        elseif (Test-Path "/etc/lsb-release") {
            $lsbRelease = ParseKeyValueFile "/etc/lsb-release" @('DISTRIB_ID', 'DISTRIB_RELEASE')
            if ($lsbRelease['DISTRIB_ID']) {
                $distroName = $lsbRelease['DISTRIB_ID']
            }
            if ($lsbRelease['DISTRIB_RELEASE']) {
                $distroVersion = $lsbRelease['DISTRIB_RELEASE']
            }
        }

        # 3. Try /etc/debian_version (specific to Debian)
        elseif (Test-Path "/etc/debian_version") {
            $distroName = "Debian"
            $distroVersion = Get-Content "/etc/debian_version" -Raw
        }

        # 4. Try /etc/redhat-release (specific to Red Hat-based systems)
        elseif (Test-Path "/etc/redhat-release") {
            $content = Get-Content "/etc/redhat-release" -Raw
            if ($content -match "(.+)\srelease\s([\d\.]+)") {
                $distroName = $matches[1].Trim()
                $distroVersion = $matches[2].Trim()
            }
        }

        # 5. Fallback to /etc/issue if others are not available
        elseif (Test-Path "/etc/issue") {
            $content = Get-Content "/etc/issue" -Raw
            if ($content -match "(.+)\s([\d\.]+)") {
                $distroName = $matches[1].Trim()
                $distroVersion = $matches[2].Trim()
            }
        }
    } catch {
    }

    # Return formatted result
    [PSCustomObject]@{
        distroName = $distroName
        distroVersion = $distroVersion
        distroInfo = "$distroName $distroVersion"
    }
}

function Get-Version {
    [CmdletBinding()]
    param($Version)
    $ParsedVersion = $null
    [System.Version]::TryParse(($Version -replace '-.+' -replace "[^0-9.]" -replace "^(\d+\.\d+\.\d+\.\d+)\..+","`$1"), [ref]$ParsedVersion) > $null
    $ParsedVersion
}

function Get-MinerVersion {
    [CmdletBinding()]
    param($Version)
    try {
        if ($Version -match "/v([0-9a-z.]+)-") {$Version = $Matches[1]}
        $Version = $Version -replace "[^0-9a-z.]" -replace "^[^0-9]+" -replace "(\d)[a-z]*v(\d)","`$1.`$2" -replace "(\d)[a-z]*r(\d)","`$1.`$2" -replace "^([0-9]+)$","`$1.0"
        if ($Version -notmatch "^[0-9.]+$") {
            if ($Session.IsCore) {
                $Version = $Version -replace "([a-z])([0-9]|$)",{".$([byte][char]($_.Groups[1].Value.ToLower()) - [byte][char]'a')$(if ($_.Groups[2].Value) {".$($_.Groups[2].Value)"})"}
            } else {
                $Version = [regex]::Replace($Version,"([a-z])([0-9]|$)",{param($match) ".$([byte][char]($match.Groups[1].Value.ToLower()) - [byte][char]'a')$(if ($match.Groups[2].Value) {".$($match.Groups[2].Value)"})"})
            }
        }
    } catch {
        $Version = "1.0"
    }
    if ("$($Version -replace "[^\.]")".Length -gt 3) {
        $VersionArray = $Version -split "\." | %{[int]::parse($_)}
        $x = 1000
        for($i=$VersionArray.Count -2;$i -gt 2;$i--) {
            $VersionArray[$i]*=$x
            $x*=1000
        }
        $Version = "$(($VersionArray | Select-Object -First 3) -join ".").$(($VersionArray | Select-Object -Skip 3 | Measure-Object -Sum).Sum)"

    }
    [System.Version]$Version
}

function Compare-Version {
    [CmdletBinding()]
    param($Version1,$Version2,[int]$revs = -1)
    $ver1 = ($Version1 -Split '-' -Replace "[^0-9.]")[0] -split '\.'
    $ver2 = ($Version2 -Split '-' -Replace "[^0-9.]")[0] -split '\.'
    $max = [Math]::Min($ver1.Count,$ver2.Count)
    if ($revs -gt 0 -and $revs -lt $max) {$max = $revs}

    for($i=0;$i -lt $max;$i++) {
        if ([int]$ver1[$i] -lt [int]$ver2[$i]) {return -1}
        if ([int]$ver1[$i] -gt [int]$ver2[$i]) {return 1}
    }
    return 0
}

function Confirm-Version {
    [CmdletBinding()]
    param($RBMVersion, [Switch]$Force = $false, [Switch]$Silent = $false)

    $Name = "RainbowMiner"
    if ($Force -or -not (Test-Path Variable:Global:GlobalVersion) -or (Get-Date).ToUniversalTime() -ge $Global:GlobalVersion.NextCheck) {

        $RBMVersion = $Version = Get-Version($RBMVersion)
        $Uri = ""
        $NextCheck = (Get-Date).ToUniversalTime()

        try {
            $ReposURI = "https://api.github.com/repos/rainbowminer/$Name/releases/latest"
            if ($Force) {
                $Request = Invoke-GetUrl $ReposURI -timeout 20
            } else {
                $Request = Invoke-RestMethodAsync $ReposURI -cycletime 3600 -noquickstart
            }
            $RemoteVersion = ($Request.tag_name -replace '^v')
            if ($RemoteVersion) {
                if ($IsWindows) {
                    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion)_win.zip" | Select-Object -ExpandProperty browser_download_url
                } elseif ($IsLinux) {
                    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion)_linux.zip" | Select-Object -ExpandProperty browser_download_url
                }
                if (-not $Uri) {
                    $Uri = $Request.assets | Where-Object Name -EQ "$($Name)V$($RemoteVersion).zip" | Select-Object -ExpandProperty browser_download_url
                }
                $Version  = Get-Version($RemoteVersion)
            }
            $NextCheck = $NextCheck.AddHours(1)
        }
        catch {
            Write-Log -Level Warn "Github could not be reached. "
        }
        $Global:GlobalVersion = [PSCustomObject]@{
            Version = $RBMVersion
            RemoteVersion = $Version
            DownloadURI = $Uri
            ManualURI = "https://github.com/RainbowMiner/$Name/releases"
            NextCheck = $NextCheck
        }
    }

    if (-not $Silent) {
        if ($Global:GlobalVersion.RemoteVersion -gt $Global:GlobalVersion.Version) {
            Write-Log -Level Warn "$Name is out of date: lastest release version v$($Global:GlobalVersion.RemoteVersion) is available."
        } elseif ($Global:GlobalVersion.RemoteVersion -lt $Global:GlobalVersion.Version) {
            Write-Log -Level Warn "You are running $Name prerelease v$RBMVersion. Use at your own risk."
        }
    }
    $Global:GlobalVersion
}

function Get-PoolPayoutCurrencies {
    param($Pool)
    if (-not (Test-Path Variable:Global:GlobalPoolFields)) {
        if (-not $Session.PoolsConfigDefault) {$Session.PoolsConfigDefault = Get-ChildItemContent ".\Data\PoolsConfigDefault.ps1"}
        $Global:GlobalPoolFields = @($Session.PoolsConfigDefault.PSObject.Properties.Value | Where-Object {$_.Fields} | Foreach-Object {$_.Fields.PSObject.Properties.Name} | Select-Object) + @("Worker","Penalty","Algorithm","ExcludeAlgorithm","CoinName","ExcludeCoin","CoinSymbol","ExcludeCoinSymbol","MinerName","ExcludeMinerName","FocusWallet","AllowZero","EnableAutoCoin","EnablePostBlockMining","CoinSymbolPBM","DataWindow","StatAverage","StatAverageStable","MaxMarginOfError","SwitchingHysteresis","MaxAllowedLuck","MaxTimeSinceLastBlock","MaxTimeToFind","Region","SSL","BalancesKeepAlive","Wallets","DefaultMinerSwitchCoinSymbol","ETH-Paymentmode","MiningMode") | Sort-Object -Unique
    }
    if ($Pool) {
        $Payout_Currencies = [PSCustomObject]@{}
        $Pool.PSObject.Properties | Where-Object Membertype -eq "NoteProperty" | Where-Object {$_.Value -is [string] -and ($_.Value.Length -gt 2 -or $_.Value -eq "`$Wallet" -or $_.Value -eq "`$$($_.Name)") -and $Global:GlobalPoolFields -notcontains $_.Name -and $_.Name -notmatch "-Params$" -and $_.Name -notmatch "^#"} | Select-Object Name,Value -Unique | Sort-Object Name,Value | Foreach-Object{$Payout_Currencies | Add-Member $_.Name $_.Value}
        $Payout_Currencies
    }
}

function Get-UnprofitableAlgos {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-GetUrlAsync "https://api.rbminer.net/data/unprofitable3.json" -cycletime 3600 -Jobkey "unprofitable3"
    }
    catch {
        Write-Log -Level Warn "Unprofitable algo API failed. "
    }

    if ($Request.Algorithms -and $Request.Algorithms.Count -gt 10) {
        Set-ContentJson -PathToFile ".\Data\unprofitable.json" -Data $Request -MD5hash $Global:GlobalUnprofitableAlgosHash > $null
    } elseif (Test-Path ".\Data\unprofitable.json") {
        try{
            $Request = Get-ContentByStreamReader ".\Data\unprofitable.json" | ConvertFrom-Json -ErrorAction Ignore
        } catch {
            Write-Log -Level Warn "Unprofitable database is corrupt. "
        }
    }
    $Global:GlobalUnprofitableAlgosHash = Get-ContentDataMD5hash $Request
    $Request
}

function Get-UnprofitableCpuAlgos {
    $Request = [PSCustomObject]@{}
    try {
        $Request = Invoke-GetUrlAsync "https://api.rbminer.net/data/unprofitable-cpu.json" -cycletime 3600 -Jobkey "unprofitablecpu"
    }
    catch {
        Write-Log -Level Warn "Unprofitable Cpu algo API failed. "
    }

    if ($Request -and $Request.Count -gt 10) {
        Set-ContentJson -PathToFile ".\Data\unprofitable-cpu.json" -Data $Request -MD5hash $Global:GlobalUnprofitableCpuAlgosHash > $null
    } elseif (Test-Path ".\Data\unprofitable.json") {
        try{
            $Request = Get-ContentByStreamReader ".\Data\unprofitable-cpu.json" | ConvertFrom-Json -ErrorAction Ignore
        } catch {
            Write-Log -Level Warn "Unprofitable Cpu database is corrupt. "
        }
    }
    $Global:GlobalUnprofitableCpuAlgosHash = Get-ContentDataMD5hash $Request
    $Request
}

function Get-CoinSymbol {
    [CmdletBinding()]
    param($CoinName = "Bitcoin",[Switch]$Silent,[Switch]$Reverse)
    
    if (-not $Session.GlobalCoinNames -or -not $Session.GlobalCoinNames.Count) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-GetUrlAsync "https://api.rbminer.net/data/coins.json" -cycletime 86400 -Jobkey "coins"
        }
        catch {
            Write-Log -Level Warn "Coins API failed. "
        }
        if (-not $Request -or $Request.PSObject.Properties.Name.Count -le 100) {
            $Request = $null
            if (Test-Path "Data\coins.json") {try {$Request = Get-ContentByStreamReader "Data\coins.json" | ConvertFrom-Json -ErrorAction Stop} catch {$Request = $null}}
            if (-not $Request) {Write-Log -Level Warn "Coins API return empty string. ";return}
        } else {Set-ContentJson -PathToFile "Data\coins.json" -Data $Request > $null}
        $Session.GlobalCoinNames = [System.Collections.Hashtable]@{}
        $Request.PSObject.Properties | Foreach-Object {$Session.GlobalCoinNames[$_.Name] = $_.Value}
    }
    if (-not $Silent) {
        if ($Reverse) {
            $CoinName = $CoinName.ToUpper()
            (Get-Culture).TextInfo.ToTitleCase("$($Session.GlobalCoinNames.GetEnumerator() | Where-Object {$_.Value -eq $CoinName} | Select-Object -ExpandProperty Name -First 1)")
        } else {
            $Session.GlobalCoinNames[$CoinName.ToLower() -replace "[^a-z0-9]+"]
        }
    }
}

function Write-ToFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$FilePath,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,
        [Parameter(Mandatory = $False)]
        [switch]$Append = $false,
        [Parameter(Mandatory = $False)]
        [switch]$Timestamp = $false,
        [Parameter(Mandatory = $False)]
        [switch]$NoCR = $false,
        [Parameter(Mandatory = $False)]
        [switch]$ThrowError = $false
    )
    Begin {
        $ErrorMessage = $null
        try {
            $FilePath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
            $file = New-Object System.IO.StreamWriter($FilePath, $Append, [System.Text.Encoding]::UTF8)
        } catch {$ErrorMessage = "$($_.Exception.Message)"}
    }
    Process {
        if ($file) {
            try {
                if ($Timestamp) {
                    if ($NoCR) {
                        $file.Write("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $Message")
                    } else {
                        $file.WriteLine("[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $Message")
                    }
                } else {
                    if ($NoCR) {
                        $file.Write($Message)
                    } else {
                        $file.WriteLine($Message)
                    }
                }
            } catch {$ErrorMessage = "$($_.Exception.Message)"}
        }
    }
    End {
        if ($file) {
            try {
                $file.Close()
                $file.Dispose()
            } catch {$ErrorMessage = "$($_.Exception.Message)"}
        }
        if ($ThrowError -and $ErrorMessage) {throw $ErrorMessage}
    }
}

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet("Error", "Warn", "Info", "Verbose", "Debug")][string]$Level = "Info"
    )

    Begin {
        if ($Session.SetupOnly) {return}
    }
    Process {

        $filename = ".\Logs\RainbowMiner_$(Get-Date -Format "yyyy-MM-dd").txt"

        if (-not (Test-Path "Stats\Pools")) {New-Item "Stats\Pools" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Miners")) {New-Item "Stats\Miners" -ItemType "directory" > $null}
        if (-not (Test-Path "Stats\Totals")) {New-Item "Stats\Totals" -ItemType "directory" > $null}

        $Color = ""

        switch ($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                $Color = "Red"
                Break
            }
            'Warn' {
                $LevelText = 'WARNING:'
                $Color = "Yellow"
                Break
            }
            'Info' {
                $LevelText = 'INFO:'
                if ($Session.Debug) {
                    $Color = "DarkGray"
                }
                Break
            }
            'Verbose' {
                $LevelText = 'VERBOSE:'
                Break
            }
            'Debug' {
                $LevelText = 'DEBUG:'
                Break
            }
        }

        if ($Color -ne "") {
            Write-Host "$LevelText $Message" -ForegroundColor $Color
        }

        $NoLog = Switch ($Session.LogLevel) {
                    "Silent" {$true;Break}
                    "Info"   {$Level -eq "Debug";Break}
                    "Warn"   {@("Info","Debug") -icontains $Level;Break}
                    "Error"  {@("Warn","Info","Debug") -icontains $Level;Break}
                }

        if (-not $NoLog) {
            if ($Session.Debug) {
                $grow = Test-CacheGrow
                $grow_out = @()
                foreach ( $item in $grow ) {
                    $grow_out += "$($item.Name) $(if ($item.Diff -ge 0) {"+"})$($item.Diff)"
                }
                if ($grow_out.Count) {
                    $Message += " " + ($grow_out -join ", ")
                }
            }
            # Generate a unique mutex name for the log directory
            $mutexName = "RBM" + (Get-MD5Hash ([io.fileinfo](".\Logs")).FullName)
            $mutex = [System.Threading.Mutex]::new($false, $mutexName)
            try {
                # Attempt to acquire the mutex, waiting up to 2 seconds
                if ($mutex.WaitOne(2000)) {
                    try {
                        "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $LevelText $Message" | Out-File $filename -Append -Encoding utf8
                    }
                    finally {
                        $mutex.ReleaseMutex()
                    }
                }
                else {
                    Write-Error "Log file is locked, unable to write message to $FileName."
                }
            }
            catch {
                Write-Error "Error acquiring mutex: $($_.Exception.Message)"
            }
            finally {
                $mutex.Dispose()
            }
        }
    }
    End {}
}

function Export-ToCsvFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $True)]
        $InputObject,
        [Parameter(Mandatory = $false)]
        [Switch]$UseCulture = $false
    )
    $Skip = if (Test-Path $FilePath) {1} else {0}
    if ($UseCulture) {
        $InputObject | ConvertTo-Csv -NoTypeInformation -UseCulture -ErrorAction Ignore | Select-Object -Skip $Skip | Write-ToFile -FilePath $FilePath -Append
    } else {
        $InputObject | ConvertTo-Csv -NoTypeInformation -ErrorAction Ignore | Select-Object -Skip $Skip | Write-ToFile -FilePath $FilePath -Append
    }
}

function Get-ChildItemContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path, 
        [Parameter(Mandatory = $false)]
        [Hashtable]$Parameters = @{},
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Quick = $false
    )

    function Invoke-ExpressionRecursive ($Expression) {
        if ($Expression -is [String]) {
            if ($Expression -match '(\$|")') {
                try {$Expression = Invoke-Expression $Expression}
                catch {$Expression = Invoke-Expression "`"$Expression`""}
            }
        }
        elseif ($Expression -is [PSCustomObject]) {
            $Expression | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                $Expression.$_ = Invoke-ExpressionRecursive $Expression.$_
            }
        }
        return $Expression
    }

    Get-ChildItem $Path -File -ErrorAction Ignore | ForEach-Object {
        $Name = $_.BaseName
        if ($_.Extension -eq ".ps1") {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}
                & $_.FullName @Parameters                
            }
        }
        elseif ($Quick) {
            $Content = $null
            try {
                $Content = Get-ContentByStreamReader $_.FullName | ConvertFrom-Json -ErrorAction Stop
            } catch {}
            if ($Content -eq $null) {$Content = Get-ContentByStreamReader $_.FullName}
        }
        else {
            $Content = & {
                foreach ($k in $Parameters.Keys) {Set-Variable $k $Parameters.$k}                
                try {
                    (Get-ContentByStreamReader $_.FullName | ConvertFrom-Json -ErrorAction Stop) | ForEach-Object {Invoke-ExpressionRecursive $_}
                }
                catch {}
            }
            if ($Content -eq $null) {$Content = Get-ContentByStreamReader $_.FullName}
        }
        if ($Force -and $Content) {
            foreach ($k in $Parameters.Keys) {
                if ($Member = Get-Member -InputObject $Content -Name $k -Membertype Properties) {
                    if ($Member.Name -and ($Member.Name -cne $k)) {
                        $Value = $Content.$k
                        $Content | Add-Member $k $Value -Force
                    }
                } else {
                    $Content | Add-Member $k $Parameters.$k -Force 
                }
            }
        }
        $Content
    }
}

function Get-ContentByStreamReader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $True)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [Switch]$ExpandLines = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$ThrowError = $false
    )
    $ErrorString = $null
    try {
        if (-not (Test-Path $FilePath)) {return}
        $FilePath = $Global:ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
        $stream = [System.IO.FileStream]::new($FilePath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
        $reader = [System.IO.StreamReader]::new($stream)
        if ($ExpandLines) {
            while (-not $reader.EndOfStream) {$reader.ReadLine()}
        } else {
            $reader.ReadToEnd()
        }
    }
    catch {
        $ErrorString = "$($_.Exception.Message)"
    }
    finally {
        if ($reader) {$reader.Close();$reader.Dispose()}
        if ($stream) {$stream.Close();$stream.Dispose()}
    }
    if ($ThrowError -and $ErrorString) {throw $ErrorString}
}

filter ConvertTo-Float {
    [CmdletBinding()]
    $Num = $_ -as [double]

    if ($Num -eq $null) {0} else {
        switch ([Math]::Floor([Math]::Log($Num, 1e3))) {
            "-Infinity" {"0  ";Break}
            -2 {"{0:n2} µ" -f ($Num * 1e6);Break}
            -1 {"{0:n2} m" -f ($Num * 1e3);Break}
             0 {"{0:n2}  " -f ($Num / 1);Break}
             1 {"{0:n2} k" -f ($Num / 1e3);Break}
             2 {"{0:n2} M" -f ($Num / 1e6);Break}
             3 {"{0:n2} G" -f ($Num / 1e9);Break}
             4 {"{0:n2} T" -f ($Num / 1e12);Break}
             5 {"{0:n2} P" -f ($Num / 1e15);Break}
             6 {"{0:n2} E" -f ($Num / 1e18);Break}
             7 {"{0:n2} Z" -f ($Num / 1e21);Break}
             Default {"{0:n2} Y" -f ($Num / 1e24)}
        }
    }
}

filter ConvertTo-Hash { 
    "$($_ | ConvertTo-Float)H"
}

filter ConvertTo-TTF {
    try {
        if ($_ -lt [timespan]::MaxValue.TotalSeconds) {
            $Secs = [timespan]::FromSeconds($_)
            if ($Secs.Days -gt 0) {
                if ($Secs.Days -gt 365) {">1 y"}
                elseif ($Secs.Days -gt 182) {">6 mo"}
                elseif ($Secs.Days -gt 30) {">1 mo"}
                elseif ($Secs.Days -gt 7) {">1 w"}
                else {"$([Math]::Round($Secs.TotalDays,1)) d"}
            }
            elseif ($Secs.Hours -gt 0) {"$([Math]::Round($Secs.TotalHours,1)) h"}
            elseif ($Secs.Minutes -gt 0) {"$([Math]::Round($Secs.TotalMinutes,1)) m"}
            else {"$([Math]::Round($Secs.TotalSeconds,1)) s"}
        } else {">10 y"}
    } catch {
        ">10 y"
    }
}

function ConvertFrom-Hash {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Hash
    )
    try {$Num = [double]($Hash -replace "[^0-9`.]")} catch {$Num=0}
    switch (($Hash -replace "[^kMGHTPEZY]")[0]) {
        "k" {$Num*1e3;Break}
        "M" {$Num*1e6;Break}
        "G" {$Num*1e9;Break}
        "T" {$Num*1e12;Break}
        "P" {$Num*1e15;Break}
        "E" {$Num*1e18;Break}
        "Z" {$Num*1e21;Break}
        "Y" {$Num*1e24;Break}
        default {$Num}
    }
}

function ConvertFrom-Bytes {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Hash
    )
    try {$Num = [double]($Hash -replace "[^0-9`.]")} catch {$Num=0}
    switch (($Hash -replace "[^kMGHTPEZY]")[0]) {
        "k" {[int64]$Num*1024;Break}
        "M" {[int64]$Num*1048576;Break}
        "G" {[int64]$Num*1073741824;Break}
        "T" {[int64]$Num*1099511627776;Break}
        "P" {[int64]$Num*1.12589990684262e15;Break}
        "E" {if ($Num -lt 8.67) {[int64]$Num*1.15292150460684e18} else {[bigint]$Num*1.15292150460684e18};Break}
        "Z" {[bigint]$Num*1.18059162071741e21;Break}
        "Y" {[bigint]$Num*1.20892581961462e24;Break}
        default {[int64]$Num}
    }
}

function ConvertFrom-Time {
    param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string]$Time
    )
    try {$Num = [double]($Time -replace "[^0-9`.]")} catch {$Num=0}
    [int64]$(switch (($Time -replace "[^mhdw]")[0]) {
        "m" {$Num*60;Break}
        "h" {$Num*3600;Break}
        "d" {$Num*86400;Break}
        "w" {$Num*604800;Break}
        default {$Num}
    })
}

function ConvertTo-LocalCurrency { 
    [CmdletBinding()]
    # To get same numbering scheme regardless of value BTC value (size) to determine formatting
    # Use $Offset to add/remove decimal places

    param(
        [Parameter(Mandatory = $true)]
        [Double]$Number, 
        [Parameter(Mandatory = $true)]
        [Double]$BTCRate,
        [Parameter(Mandatory = $false)]
        [Int]$Offset = 2
    )

    ($Number * $BTCRate).ToString("N$([Math]::Max([Math]::Min([Math]::Truncate(10 - $Offset - [Math]::Log10($BTCRate)),9),0))")
}

function ConvertTo-BTC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Double]$Number, 
        [Parameter(Mandatory = $false)]
        [Int]$Offset = 2
    )

    $Currency = "BTC"
    if ($Number -ne 0) {
        switch ([Math]::Truncate([Math]::Log([Math]::Abs($Number), 1000))) {
            -1 {$Currency = "mBTC";$Number*=1e3;$Offset = 5;Break}
            -2 {$Currency = "µBTC";$Number*=1e6;$Offset = 8;Break}
            -3 {$Currency = "sat"; $Number*=1e8;$Offset = 10;Break}
        }
    }

    "$(ConvertTo-LocalCurrency $Number -BTCRate 1 -Offset $Offset) $Currency"
}

function Invoke-Exe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,ValueFromPipeline = $True)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "",
        [Parameter(Mandatory = $false)]
        [Int]$WaitForExit = 5,
        [Parameter(Mandatory = $false)]
        [Switch]$ExpandLines,
        [Parameter(Mandatory = $false)]
        [Switch]$ExcludeEmptyLines,
        [Parameter(Mandatory = $false)]
        [Switch]$AutoWorkingDirectory = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Runas = $false
        )

    $psi = $null
    $process = $null

    try {
        if ($WorkingDirectory -eq '' -and $AutoWorkingDirectory) {
            $WorkingDirectory = Get-Item $FilePath | Select-Object -ExpandProperty FullName | Split-Path
        }

        if ($IsWindows -or -not $Runas -or (Test-IsElevated)) {
            $psi = [System.Diagnostics.ProcessStartInfo]::New()
            $psi.FileName               = if ($NewFilePath = Resolve-Path $FilePath -ErrorAction Ignore) {$NewFilePath} else {$FilePath}
            $psi.CreateNoWindow         = $true
            $psi.UseShellExecute        = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.Arguments              = $ArgumentList
            $psi.WorkingDirectory       = $WorkingDirectory
            if ($Runas) {$psi.Verb = "runas"}

            $process = [System.Diagnostics.Process]::New()
            $process.StartInfo = $psi
            [void]$process.Start()

            $out = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit($WaitForExit*1000)>$null
            if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}
            $Global:LASTEXEEXITCODE = $process.ExitCode
        } else {
            if ($FilePath -match "IncludesLinux") {$FilePath = Get-Item $FilePath | Select-Object -ExpandProperty FullName}
            if (Test-OCDaemon) {
                $out = Invoke-OCDaemon -Cmd "$FilePath $ArgumentList".Trim()
            } else {
                Write-Log -Level Warn "Could not execute sudo $("$FilePath $ArgumentList".Trim()) (ocdaemon is not running. Please stop RainbowMiner and run `"./install.sh`")"
            }
            if ($ExpandLines) {foreach ($line in @($out -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$out}
        }

    } catch {Write-Log -Level Warn "Could not execute $FilePath $($ArgumentList): $($_.Exception.Message)"
    } finally {
        if ($process) { $process.Dispose(); $process = $null }
        if ($psi) { $psi = $null }
    }
}

function Invoke-Process {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true,ValueFromPipeline = $True)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "",
        [Parameter(Mandatory = $false)]
        [Int]$WaitForExit = 5,
        [Parameter(Mandatory = $false)]
        [Switch]$ExpandLines,
        [Parameter(Mandatory = $false)]
        [Switch]$ExcludeEmptyLines,
        [Parameter(Mandatory = $false)]
        [Switch]$AutoWorkingDirectory = $false
    )

    $cmd = $null

    try {
        if ($WorkingDirectory -eq '' -and $AutoWorkingDirectory) {$WorkingDirectory = Get-Item $FilePath | Select-Object -ExpandProperty FullName | Split-path}

        $stdOutTempFile = "$env:TEMP\$((New-Guid).Guid)"
        $stdErrTempFile = "$env:TEMP\$((New-Guid).Guid)"

        $startProcessParams = @{
            FilePath               = if ($NewFilePath = Resolve-Path $FilePath -ErrorAction Ignore) {$NewFilePath} else {$FilePath}
            ArgumentList           = $ArgumentList
            RedirectStandardError  = $stdErrTempFile
            RedirectStandardOutput = $stdOutTempFile
            PassThru               = $true;
            NoNewWindow            = $true;
        }

        if ($WorkingDirectory -ne '') {$startProcessParams['WorkingDirectory'] = $WorkingDirectory}

        $cmd = Start-Process @startProcessParams
        $cmdOk = if ($cmd.HasExited) {$true} elseif ($cmd.Handle) {$cmd.WaitForExit($WaitForExit*1000)} else {$false}
        $cmdOutput = Get-Content -Path $stdOutTempFile -Raw -ErrorAction Ignore
        $cmdError = Get-Content -Path $stdErrTempFile -Raw -ErrorAction Ignore
        $Global:LASTEXEEXITCODE = $cmd.ExitCode
        if (-not $cmdOk -or $cmd.ExitCode -ne 0) {
            if ($cmdError) {
                throw $cmdError.Trim()
            }
            if ($cmdOutput) {
                throw $cmdOutput.Trim()
            }
        } else {
            if ([string]::IsNullOrEmpty($cmdOutput) -eq $false) {
                if ($ExpandLines) {foreach ($line in @($cmdOutput -split '\n')){if (-not $ExcludeEmptyLines -or $line.Trim() -ne ''){$line -replace '\r'}}} else {$cmdOutput}
            }
        }
    } catch {Write-Log -Level Warn "Could not start process $FilePath $($ArgumentList): $($_.Exception.Message)"
    } finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction Ignore
        if ($cmd) {
            $cmd.Dispose()
            $cmd = $null
        }
    }
}

function Get-MyIP {
    if ($IsWindows -and ($cmd = Get-Command "ipconfig" -ErrorAction Ignore)) {
        $IpcResult = Invoke-Exe $cmd.Source -ExpandLines | Where-Object {$_ -match 'IPv4.+\s(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'} | Foreach-Object {$Matches[1]}
        if ($IpcResult.Count -gt 1 -and (Get-Command "Get-NetRoute" -ErrorAction Ignore) -and ($Trunc = Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Select-Object -ExpandProperty NextHop | Where-Object {$_ -match '^(\d{1,3}\.\d{1,3}\.)'} | Foreach-Object {$Matches[1]} | Select-Object -First 1)) {
            $IpcResult = $IpcResult | Where-Object {$_ -match "^$($Trunc)"}
        }
        $IpcResult | Select-Object -First 1
    } elseif ($IsLinux) {
        try {ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'} catch {try {hostname -I | Where-Object {$_ -match "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"} | Foreach-Object {$Matches[1]} | Select-Object -First 1} catch {}}
    }
}

function Get-CoinName {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,   
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$CoinName = ""
    )
    if ($CoinName -match "[,;]") {@($CoinName -split "\s*[,;]+\s*") | Foreach-Object {Get-CoinName $_}}
    else {
        ((Get-Culture).TextInfo.ToTitleCase($CoinName -replace "[^`$a-z0-9\s\-]+")).Trim()        
    }
}

function Get-Algorithm {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$Algorithm = "",
        [Parameter(Mandatory = $false)]
        [String]$CoinSymbol = ""
    )
    if ($Algorithm -eq '*') {$Algorithm}
    elseif ($Algorithm -match "[,;]") {@($Algorithm -split "\s*[,;]+\s*") | Foreach-Object {Get-Algorithm $_}}
    else {
        if (-not $Session.GlobalAlgorithms) {Get-Algorithms -Silent}
        $Algorithm = $Algorithm -replace "[^a-z0-9]+"
        if ($Session.GlobalAlgorithms.ContainsKey($Algorithm)) {
            $Algorithm = $Session.GlobalAlgorithms[$Algorithm]
            if ($CoinSymbol -ne "" -and $Algorithm -in @("Ethash","KawPOW") -and ($DAGSize = Get-EthDAGSize -CoinSymbol $CoinSymbol -Minimum 1) -le 5) {
                if ($DAGSize -le 2) {$Algorithm = "$($Algorithm)2g"}
                elseif ($DAGSize -le 3) {$Algorithm = "$($Algorithm)3g"}
                elseif ($DAGSize -le 4) {$Algorithm = "$($Algorithm)4g"}
                elseif ($DAGSize -le 5) {$Algorithm = "$($Algorithm)5g"}
            }
        } else {
            $Algorithm = (Get-Culture).TextInfo.ToTitleCase($Algorithm)
        }
        $Algorithm
    }
}

function Get-Coin {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ParameterSetName = '',   
            ValueFromPipeline = $True,
            Mandatory = $false)]
        [String]$CoinSymbol = "",
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = ""
    )
    if ($CoinSymbol -eq '*') {$CoinSymbol}
    elseif ($CoinSymbol -match "[,;]") {@($CoinSymbol -split "\s*[,;]+\s*") | Foreach-Object {Get-Coin $_}}
    else {
        if (-not $Session.GlobalCoinsDB) {Get-CoinsDB -Silent}
        $CoinSymbol = ($CoinSymbol -replace "[^A-Z0-9`$-]+").ToUpper()
        $Coin = if ($Session.GlobalCoinsDB.ContainsKey($CoinSymbol)) {$Session.GlobalCoinsDB[$CoinSymbol]}
                elseif ($Algorithm -ne "" -and $Session.GlobalCoinsDB.ContainsKey("$CoinSymbol-$Algorithm")) {$Session.GlobalCoinsDB["$CoinSymbol-$Algorithm"]}
        if ($Coin.Algo -in @("Ethash","KawPOW")) {$Coin.Algo = Get-Algorithm $Coin.Algo -CoinSymbol $CoinSymbol}
        $Coin
    }
}

function Get-MappedAlgorithm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Algorithm
    )
    if (-not $Session.Config.EnableAlgorithmMapping) {return $Algorithm}
    if (-not $Session.GlobalAlgorithmMap) {Get-AlgorithmMap -Silent}
    $Algorithm | Foreach-Object {if ($Session.GlobalAlgorithmMap.ContainsKey($_)) {$Session.GlobalAlgorithmMap[$_]} else {$_}}
}

function Get-AlgorithmMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not $Session.GlobalAlgorithmMap -or (Get-ChildItem "Data\algorithmmap.json").LastWriteTimeUtc -gt $Session.GlobalAlgorithmMapTimeStamp) {
        $Session.GlobalAlgorithmMap = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\algorithmmap.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalAlgorithmMap[$_.Name]=$_.Value}
        $Session.GlobalAlgorithmMapTimeStamp = (Get-ChildItem "Data\algorithmmap.json").LastWriteTimeUtc
    }
    if (-not $Silent) {
        $Session.GlobalAlgorithmMap
    }
}

function Get-AlgoVariants {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not $Session.GlobalAlgoVariants -or (Get-ChildItem "Data\algovariantsdb.json").LastWriteTimeUtc -gt $Session.GlobalAlgoVariantsTimeStamp) {
        $Session.GlobalAlgoVariants = Get-ContentByStreamReader "Data\algovariantsdb.json" | ConvertFrom-Json -ErrorAction Ignore
        $Session.GlobalAlgoVariantsTimeStamp = (Get-ChildItem "Data\algovariantsdb.json").LastWriteTimeUtc
    }
    if (-not $Silent) {
        $Session.GlobalAlgoVariants
    }
}

function Get-EquihashCoinPers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Coin = "",
        [Parameter(Mandatory = $false)]
        [String]$Default = "auto"
    )
    if (-not $Session.GlobalEquihashCoins) {Get-EquihashCoins -Silent}
    if ($Coin -and $Session.GlobalEquihashCoins.ContainsKey($Coin)) {$Session.GlobalEquihashCoins[$Coin]} else {$Default}
}

function Get-EthDAGSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$CoinSymbol = "",
        [Parameter(Mandatory = $false)]
        [String]$Algorithm = "",
        [Parameter(Mandatory = $false)]
        [Double]$Minimum = 1
    )
    if (-not $Session.GlobalEthDAGSizes) {Get-EthDAGSizes -Silent}
    if     ($CoinSymbol -and $Session.GlobalEthDAGSizes.$CoinSymbol -ne $null)          {$Session.GlobalEthDAGSizes.$CoinSymbol} 
    elseif ($Algorithm -and $Session.GlobalAlgorithms2EthDagSizes.$Algorithm -ne $null) {$Session.GlobalAlgorithms2EthDagSizes.$Algorithm}
    else   {$Minimum}
}

function Get-NimqHashrate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$GPU = "",
        [Parameter(Mandatory = $false)]
        [Int]$Default = 100
    )
    if (-not $Session.GlobalNimqHashrates) {Get-NimqHashrates -Silent}
    if ($GPU -and $Session.GlobalNimqHashrates.ContainsKey($GPU)) {$Session.GlobalNimqHashrates[$GPU]} else {$Default}
}

function Get-Region {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )
    if (-not $Session.GlobalRegions) {Get-Regions -Silent}
    $Region = (Get-Culture).TextInfo.ToTitleCase(($Region -replace "-", " " -replace "_", " ")) -replace " "
    if ($Session.GlobalRegions.ContainsKey($Region)) {$Session.GlobalRegions[$Region]} else {foreach($r in @($Session.GlobalRegions.Keys)) {if ($Region -match "^$($r)") {$Session.GlobalRegions[$r];return}};$Region}
}

function Get-Region2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Region = ""
    )
    if (-not $Session.GlobalRegions2) {Get-Regions2 -Silent}
    if ($Session.GlobalRegions2.ContainsKey($Region)) {$Session.GlobalRegions2[$Region]}
}

function Get-Algorithms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Values = $false
    )
    if ($Force -or -not $Session.GlobalAlgorithms -or (Get-ChildItem "Data\algorithms.json").LastWriteTimeUtc -gt $Session.GlobalAlgorithmsTimeStamp) {
        $Session.GlobalAlgorithms = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\algorithms.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalAlgorithms[$_.Name]=$_.Value}
        $Session.GlobalAlgorithmsTimeStamp = (Get-ChildItem "Data\algorithms.json").LastWriteTimeUtc
    }
    if (-not $Silent) {
        if ($Values) {$Session.GlobalAlgorithms.Values | Sort-Object -Unique}
        else {$Session.GlobalAlgorithms.Keys | Sort-Object}
    }
}

function Get-CoinsDB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Values = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false
    )
    if ($Force -or -not $Session.GlobalCoinsDB -or (Get-ChildItem "Data\coinsdb.json").LastWriteTimeUtc -gt $Session.GlobalCoinsDBTimeStamp) {
        $Session.GlobalCoinsDB = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\coinsdb.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalCoinsDB[$_.Name]=$_.Value;$Session.GlobalCoinsDB[$_.Name].Algo = Get-Algorithm $Session.GlobalCoinsDB[$_.Name].Algo}
        $Session.GlobalCoinsDBTimeStamp = (Get-ChildItem "Data\coinsdb.json").LastWriteTimeUtc
    }
    if (-not $Silent) {
        if ($Values) {$Session.GlobalCoinsDB.Values | Sort-Object -Unique}
        else {$Session.GlobalCoinsDB.Keys | Sort-Object}
    }
}

function Get-EquihashCoins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not $Session.GlobalEquihashCoins -or (Get-ChildItem "Data\equihashcoins.json").LastWriteTimeUtc -gt $Session.GlobalEquihashCoinsTimeStamp) {
        $Session.GlobalEquihashCoins = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\equihashcoins.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalEquihashCoins[$_.Name]=$_.Value}
        $Session.GlobalEquihashCoinsTimeStamp = (Get-ChildItem "Data\equihashcoins.json").LastWriteTimeUtc
    }
    if (-not $Silent) {$Session.GlobalEquihashCoins.Keys}
}

function Get-EthDAGSizes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableRemoteUpdate = $false
    )

    if (-not $Session.GlobalCoinsDB) {Get-CoinsDB -Silent}

    $Request = [PSCustomObject]@{}

    if ($EnableRemoteUpdate) {
        try {
            $Request = Invoke-GetUrlAsync "https://api.rbminer.net/data/ethdagsizes.json" -cycletime 3600 -Jobkey "ethdagsizes"
        }
        catch {
            Write-Log -Level Warn "EthDAGsize API failed. "
        }
    }

    if ($Request -and $Request.PSObject.Properties.Name.Count -gt 10) {
        Set-ContentJson -PathToFile ".\Data\ethdagsizes.json" -Data $Request -MD5hash (Get-ContentDataMD5hash $Session.GlobalEthDAGSizes) > $null
    } else {
        $Request = Get-ContentByStreamReader ".\Data\ethdagsizes.json" | ConvertFrom-Json -ErrorAction Ignore
    }
    $Session.GlobalEthDAGSizes = [PSCustomObject]@{}
    $Request.PSObject.Properties | Foreach-Object {$Session.GlobalEthDAGSizes | Add-Member $_.Name ($_.Value/1Gb)}

    $SingleAlgos = $Session.GlobalCoinsDB.Values | Group-Object -Property Algo | Where-Object {$_.Count -eq 1} | Select-Object -ExpandProperty Name
    $Session.GlobalAlgorithms2EthDagSizes = [PSCustomObject]@{}
    $Session.GlobalCoinsDB.GetEnumerator() | Where-Object {$Coin = $_.Name -replace "-.+$";$Session.GlobalEthDAGSizes.$Coin} | Where-Object {$Algo = Get-Algorithm $_.Value.Algo;$Algo -in $SingleAlgos -and $Algo -match $Global:RegexAlgoHasDAGSize -and $_.Value.Name -notmatch "Testnet"} | Foreach-Object {
        if ($Session.GlobalAlgorithms2EthDagSizes.$Algo -eq $null) {
            $Session.GlobalAlgorithms2EthDagSizes | Add-Member $Algo $Session.GlobalEthDAGSizes.$Coin -Force
        } elseif ($Session.GlobalAlgorithms2EthDagSizes.$Algo -lt $Session.GlobalEthDAGSizes.$Coin) {
            $Session.GlobalAlgorithms2EthDagSizes.$Algo = $Session.GlobalEthDAGSizes.$Coin
        }
    }

    if (-not $Silent) {$Session.GlobalEthDAGSizes}
}

function Get-NimqHashrates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not $Session.GlobalNimqHashrates -or (Get-ChildItem "Data\nimqhashrates.json").LastWriteTimeUtc -gt $Session.GlobalNimqHashratesTimeStamp) {
        $Session.GlobalNimqHashrates = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\nimqhashrates.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalNimqHashrates[$_.Name]=$_.Value}
        $Session.GlobalNimqHashratesTimeStamp = (Get-ChildItem "Data\nimqhashrates.json").LastWriteTimeUtc

    }
    if (-not $Silent) {$Session.GlobalNimqHashrates.Keys}
}

function Get-WalletsData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$Force = $false
    )
    if ($Force -or -not $Session.GlobalWalletsData -or (Get-ChildItem "Data\walletsdata.json").LastWriteTimeUtc -gt $Session.GlobalWalletsDataTimeStamp) {
        $Session.GlobalWalletsData = @(Get-ContentByStreamReader "Data\walletsdata.json" | ConvertFrom-Json -ErrorAction Ignore)
        $Session.GlobalWalletsDataTimeStamp = (Get-ChildItem "Data\walletsdata.json").LastWriteTimeUtc
    }
    if (-not $Silent) {
        $Session.GlobalWalletsData
    }
}

function Get-Regions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Switch]$AsHash = $false
    )
    if (-not $Session.GlobalRegions -or (Get-ChildItem "Data\regions.json").LastWriteTimeUtc -gt $Session.GlobalRegionsTimeStamp) {
        $Session.GlobalRegions = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\regions.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalRegions[$_.Name]=$_.Value}
        $Session.GlobalRegionsTimeStamp = (Get-ChildItem "Data\regions.json").LastWriteTimeUtc
    }
    if (-not $Silent) {
        if ($AsHash) {$Session.GlobalRegions}
        else {$Session.GlobalRegions.Keys}
    }
}

function Get-Regions2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false
    )
    if (-not $Session.GlobalRegions2 -or (Get-ChildItem "Data\regions2.json").LastWriteTimeUtc -gt $Session.GlobalRegions2TimeStamp) {
        $Session.GlobalRegions2 = [System.Collections.Hashtable]@{}
        (Get-ContentByStreamReader "Data\regions2.json" | ConvertFrom-Json -ErrorAction Ignore).PSObject.Properties | %{$Session.GlobalRegions2[$_.Name]=$_.Value}
        $Session.GlobalRegions2TimeStamp = (Get-ChildItem "Data\regions2.json").LastWriteTimeUtc
    }
    if (-not $Silent) {$Session.GlobalRegions2.Keys}
}

function Get-WorldCurrencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]$Silent = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$EnableRemoteUpdate = $false
    )

    if (-not (Test-Path Variable:Global:GlobalWorldCurrencies)) {
        $Global:GlobalWorldCurrencies = if (Test-Path ".\Data\worldcurrencies.json") {Get-ContentByStreamReader ".\Data\worldcurrencies.json" | ConvertFrom-Json -ErrorAction Ignore} else {@("USD","INR","RUB","EUR","GBP")}
    }

    if ($EnableRemoteUpdate) {
        $Request = [PSCustomObject]@{}
        try {
            $Request = Invoke-GetUrlAsync "https://api.coinbase.com/v2/currencies" -cycletime 86400 -Jobkey "worldcurrencies"
            if ($Request.data -and ($Request.data | Measure-Object).Count -gt 100) {
                Set-ContentJson -PathToFile ".\Data\worldcurrencies.json" -Data $Request.data.id -MD5hash (Get-ContentDataMD5hash $Global:GlobalWorldCurrencies) > $null
                $Global:GlobalWorldCurrencies = if (Test-Path ".\Data\worldcurrencies.json") {Get-ContentByStreamReader ".\Data\worldcurrencies.json" | ConvertFrom-Json -ErrorAction Ignore} else {@("USD","INR","RUB","EUR","GBP")}
            }
        }
        catch {
            Write-Log -Level Warn "Worldcurrencies API failed. "
        }
    }

    if (-not $Silent) {$Global:GlobalWorldCurrencies}
}

function Get-Sigma {
    [CmdletBinding()]
    param($data)

    if ($data -and $data.count -gt 1) {
        $mean  = ($data | measure-object -Average).Average
        $bias  = $data.Count-1.5+1/(8*($data.Count-1))
        [Math]::Sqrt(($data | Foreach-Object {[Math]::Pow(($_ - $mean),2)} | Measure-Object -Sum).Sum/$bias)
    } else {0}
}

function Test-TimeSync {

    if (-not $IsWindows) {return}

    try {
        if ((Get-Service -Name W32Time).Status -ne 'Running')
        {
            Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq "W32Time" -and $_.Status -ne "Running" } | Set-Service -StartupType Manual -Status Running
            Write-Log 'Start service W32Time (Windows Time)'
        }
    }
    catch {
        Write-Log -Level Warn "[Test-TimeSync] W32Time Service is not running and could not be started!"
        return
    }


    try {
        $configuredNtpServerNameRegistryPolicy = $null
        if (Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters -PathType Container)
        {
            $configuredNtpServerNameRegistryPolicy = Get-ItemProperty `
                -Path HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters `
                -Name 'NtpServer' -ErrorAction Ignore |
                Select-Object -ExpandProperty NtpServer
        }

        if ($configuredNtpServerNameRegistryPolicy)
        {
            # Policy override
            $ConfiguredNTPServerNameRaw = $configuredNtpServerNameRegistryPolicy.Trim()
        }
        else
        {
            # Exception if not exists
            $ConfiguredNTPServerNameRaw = [RBMToolBox]::Trim((Get-ItemProperty `
                -Path HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters -Name 'NtpServer').NtpServer)
        }

        if ($ConfiguredNTPServerNameRaw)
        {
            $ConfiguredNTPServerNames = [RBMToolBox]::Split($ConfiguredNTPServerNameRaw, " ") -replace ',.+$'
        }
        else {
            $ConfiguredNTPServerNames = @("pool.ntp.org","time.windows.com")
        }
    }
    catch {
        Write-Log -Level Warn "[Test-TimeSync] No configured nameservers found in registry"
        return
    }


    try {
        $w32tm = w32tm /stripchart /computer:$($ConfiguredNTPServerNames[0]) /dataonly /samples:1 | Select-Object -Last 1 | Out-String
        if ( [RBMToolBox]::Split($w32tm,",")[1] -match '([\d\.\-\+]+)' ) {
            $b = [double]$matches[1]
            if ( $b*$b -gt 4.0 ) {
                Write-Log -Level Warn "[Test-TimeSync] Time is out of sync by $($b.ToString('f3'))s! $((get-date).ToString('HH:mm:ss')) - syncing now with $($ConfiguredNTPServerNames[0])"
                $s = w32tm /resync /update | Select-Object -Last 1 | Out-String                
                Write-Log "[Test-TimeSync] $($s)"
            }
        } else {
            Write-Log -Level Warn "[Test-TimeSync] Could not read w32tm statistics from $($w32tmSource)"
        }
    }
    catch { 
        Write-Log -Level Warn "[Test-TimeSync] Something went wrong"
    }

}

function Get-Yes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $Argument = $false
    )
    if ($Argument -eq $null) {$false}
    elseif ($Argument -is [bool]) {$Argument} else {[Bool](0,$false,"no","n","not","niet","non","nein","never","0","false" -inotcontains $Argument)}
}

function Get-ContentDataMD5hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        $Data
    )
    if ($Data -eq $null) {$Data = ''}
    Get-MD5Hash ($Data | ConvertTo-Json -Depth 10 -Compress)
}

function Set-ContentJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$PathToFile,
        [Parameter(Mandatory = $True)]
        $Data,
        [Parameter(Mandatory = $False)]
        $MD5hash = '',
        [Parameter(Mandatory = $False)]
        [Switch]$Compress,
        [Parameter(Mandatory = $False)]
        [Switch]$Quiet
    )
    $retry = 3
    do {
        $stream = $null
        try {
            $Exists = $false
            if ([System.IO.File]::Exists($PathToFile)) {
                    if ((Get-ChildItem $PathToFile -File).IsReadOnly) {
                        if (-not $Quiet) {Write-Log -Level Warn "Unable to write to read-only file $PathToFile"}
                        return $false
                    }
                    $stream = [System.IO.File]::Open($PathToFile,'Open','Write')
                    $stream.Close()
                    $stream.Dispose()
                    $stream = $null
                    $Exists = $true
            }
            if (-not $Exists -or $MD5hash -eq '' -or ($MD5hash -ne (Get-ContentDataMD5hash($Data)))) {
                if ($Session.IsCore -or ($PSVersionTable.PSVersion -ge (Get-Version "6.1"))) {
                    if ($Data -is [array]) {
                        ConvertTo-Json -InputObject @($Data | Select-Object) -Compress:$Compress -Depth 10 -ErrorAction Stop | Set-Content $PathToFile -Encoding utf8 -Force -ErrorAction Stop
                    } else {
                        ConvertTo-Json -InputObject $Data -Compress:$Compress -Depth 10 -ErrorAction Stop | Set-Content $PathToFile -Encoding utf8 -Force -ErrorAction Stop
                    }
                } else {
                    $JsonOut = if ($Data -is [array]) {
                        ConvertTo-Json -InputObject @($Data | Select-Object) -Compress:$Compress -Depth 10 -ErrorAction Stop
                    } else {
                        ConvertTo-Json -InputObject $Data -Compress:$Compress -Depth 10 -ErrorAction Stop
                    }
                    $utf8 = [System.Text.UTF8Encoding]::new($false)
                    Set-Content -Value $utf8.GetBytes($JsonOut) -Encoding Byte -Path $PathToFile -ErrorAction Stop
                }
            } elseif ($Exists) {
                (Get-ChildItem $PathToFile -File).LastWriteTime = Get-Date
            }
            return $true
        } catch {
        }
        finally {
            if ($stream) { $stream.Close(); $stream.Dispose(); $stream = $null }
        }
        $retry--
        Start-Sleep -Seconds 1
    } until ($retry -le 0)
    if (-not $Quiet) {Write-Log -Level Warn "Unable to write to file $PathToFile"}
    return $false
}

function Get-ConfigArray {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        $Config,
        [Parameter(Mandatory = $False)]
        $Split = ",;",
        [Parameter(Mandatory = $False)]
        $Characters = ""
    )
    if ($Config -isnot [array]) {
        $Config = "$Config".Trim()
        if ($Characters -ne "") {$Config = $Config -replace "[^$Characters$Split]+"}
        @($Config -split "\s*[$Split]+\s*" | Where-Object {$_} | Select-Object)
    } else {$Config}
}

function ConvertFrom-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [string]$Affinity = '',
        [Parameter(Mandatory = $False)]
        [switch]$ToInt
    )
    try {$AffinityInt = [System.Numerics.BigInteger]::Parse("0$($Affinity -replace "[^0-9A-Fx]" -replace "^[0x]+")", 'AllowHexSpecifier')}catch{$AffinityInt=[bigint]0}
    if ($ToInt) {$AffinityInt}
    else {@(for($a=0;$AffinityInt -gt 0;$a++) {if (($AffinityInt -band 1) -eq 1){$a};$AffinityInt=$AffinityInt -shr 1})}
}

function ConvertTo-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [int[]]$Threads = @(),
        [Parameter(Mandatory = $False)]
        [switch]$ToHex
    )
    [bigint]$a=0;foreach($b in $Threads){$a+=[bigint]1 -shl $b};
    if ($ToHex) {
        if ($a -gt 0) {"0x$($a.ToString("x") -replace "^0")"}
        else {"0x00"}
    }else{$a}
}

function Get-CPUAffinity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [int]$Threads = 0,
        [Parameter(Mandatory = $False)]
        [switch]$ToHex,
        [Parameter(Mandatory = $False)]
        [switch]$ToInt
    )
    if ($ToHex) {ConvertTo-CPUAffinity @(Get-CPUAffinity $Threads) -ToHex}
    elseif ($ToInt) {ConvertTo-CPUAffinity @(Get-CPUAffinity $Threads)}
    else {
        @(if ($Threads -and $Threads -ne $Global:GlobalCPUInfo.RealCores.Count) {
            $a = $r = 0; $b = [Math]::Max(1,[int]($Global:GlobalCPUInfo.Threads/$Global:GlobalCPUInfo.Cores));
            for($i=0;$i -lt [Math]::Min($Threads,$Global:GlobalCPUInfo.Threads);$i++) {$a;$c=($a+$b)%$Global:GlobalCPUInfo.Threads;if ($c -lt $a) {$r++;$a=$c+$r}else{$a=$c}}
        } else {$Global:GlobalCPUInfo.RealCores}) | Sort-Object
    }
}

function Get-MemoryUsage {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    [Switch]$forceFullCollection = $false
)
    $memusagebyte = [System.GC]::GetTotalMemory($forceFullCollection)
    $memdiff = $memusagebyte - [int64]$Global:last_memory_usage_byte
    [PSCustomObject]@{
        MemUsage   = $memusagebyte
        MemDiff    = $memdiff
        MemText    = "Memory usage: {0:n1} MB ({1:n0} Bytes {2})" -f  ($memusagebyte/1MB), $memusagebyte, "$(if ($memdiff -gt 0){"+"})$($memdiff)"
    }

    $Global:last_memory_usage_byte = $memusagebyte
}

function Write-MemoryUsageToLog {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    [String]$Message = ""
)
    #[System.GC]::Collect()
    #[System.GC]::WaitForPendingFinalizers()
    #[System.GC]::Collect()
    #Get-MemoryUsage -ForceFullCollection >$null
    #Write-Log "$($Message) $((Get-MemoryUsage -Reset).MemText)"
    Write-Log "$($Message) $((Get-MemoryUsage).MemText)"
}

function Get-MD5Hash {
[CmdletBinding()]
Param(
    [Parameter(
        Mandatory = $True,
        Position = 0,
        ValueFromPipeline = $True)]
    [string]$value
)

    $md5 = [System.Security.Cryptography.MD5CryptoServiceProvider]::new()
    $utf8 = [System.Text.Encoding]::UTF8

    try {
        [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($value))).ToUpper() -replace '-'
    }
    finally {
        $md5.Dispose()  # Ensure cleanup
    }
}

function Get-HashtableAsJson {
[cmdletbinding()]
Param(   
    [Parameter(Mandatory = $False)]
    $hashtable
)
    if ($hashtable -is [string]) {$hashtable}
    else {
        if ($hashtable -eq $null) {"{}"}
        else {
            "{$(@($hashtable.Keys | Sort-Object | Foreach-Object {"$($_):$(if ($hashtable.$_ -is [hashtable]) {Get-HashtableAsJson $hashtable.$_} else {ConvertTo-Json $hashtable.$_ -Depth 10})"}) -join ",")}"
        }
    }
}

function Get-MinerStatusKey {
    $Response = [guid]::NewGuid().ToString()
    Write-Log "Miner Status key created: $Response"
    $Response
}

function Initialize-User32Dll {
    try {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace User32
{
    public class WindowManagement {
        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")]
        public static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, IntPtr lclassName, string windowTitle);
        [DllImport("user32.dll")] 
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        public static extern int SetWindowText(IntPtr hWnd, string strTitle);
    }
}
"@
    } catch {
        Write-Log -Level Warn "Error initializing User32.dll functions"
    }
}

function Get-NtpTime {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [String]$NTPServer = "time.google.com",
    [Parameter(Mandatory = $False)]
    [Switch]$Quiet = $false
)

    $NTPData    = New-Object byte[] 48  # Array of 48 bytes set to zero
    $NTPData[0] = 27                    # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

    try {
        $Socket = New-Object Net.Sockets.Socket ( 'InterNetwork', 'Dgram', 'Udp' )
        $Socket.SendTimeOut    = 2000  # ms
        $Socket.ReceiveTimeOut = 2000  # ms
        $Socket.Connect( $NTPServer, 123 )
        $Null = $Socket.Send(    $NTPData )
        $Null = $Socket.Receive( $NTPData )
        $Socket.Shutdown( 'Both' )
        $Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )
    } catch {
        Write-Log -Level "$(if ($Quiet) {"Info"} else {"Warn"})" "Could not read time from $($NTPServer)"
    }
    finally {
        if ($Socket) {$Socket.Close();$Socket.Dispose()}
    }

    if ($Seconds) {( [datetime]'1/1/1900' ).AddSeconds( $Seconds ).ToLocalTime()} else {Get-Date}
}

function Get-UnixTimestamp {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    $DateTime = $null, # keep for backwards compatibility
    [Parameter(Mandatory = $False)]
    [Switch]$Milliseconds = $false
)
    if ($DateTime -ne $null) {
        Get-UTCToUnix $DateTime -Milliseconds:$Milliseconds
    } else {
        if ($Milliseconds) {
            [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - 1000*[int]$Session.TimeDiff
        } else {
            [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [int]$Session.TimeDiff
        }
    }
}

function Get-UTCToUnix {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False)]
    [DateTime]$DateTime = [DateTime]::UtcNow,
    [Parameter(Mandatory = $False)]
    [Switch]$Milliseconds = $false
)
    [Math]::Floor((($DateTime - $Session.UnixEpoch).TotalSeconds - [int]$Session.TimeDiff)*$(if ($Milliseconds) {1000} else {1}))
}

function Get-UnixToUTC {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [Int64]$UnixTimestamp = 0
)
    ([datetimeoffset]::FromUnixTimeSeconds($UnixTimestamp)).UtcDateTime
}

function Get-Zip {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [String]$s = ""
)
    if (-not $s) {return ""}
    $ms = $cs = $sw = $null
    try {
        $ms = [System.IO.MemoryStream]::new()
        $cs = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionMode]::Compress)
        $sw = [System.IO.StreamWriter]::new($cs)
        $sw.Write($s)
        $sw.Close()
        [System.Convert]::ToBase64String($ms.ToArray())
    } catch {
        $s
    }
    finally {
        if ($sw) { $sw.Dispose(); $sw = $null }
        if ($cs) { $cs.Dispose(); $cs = $null }
        if ($ms) { $ms.Dispose(); $ms = $null }        
    }
}

function Get-Unzip {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [String]$s = ""
)
    if (-not $s) {return ""}
    $ms = $sr = $null
    try {
        $data = [System.Convert]::FromBase64String($s)
        $ms = New-Object System.IO.MemoryStream
        $ms.Write($data, 0, $data.Length)
        $ms.Seek(0,0) | Out-Null
        $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress))
        $sr.ReadToEnd()
    } catch {
        $s
    }
    finally {
        if ($sr) { $sr.Dispose(); $sr = $null }
        if ($cs) { $cs.Dispose(); $cs = $null }
        if ($ms) { $ms.Dispose(); $ms = $null }
    }
}

function Get-UrlEncode {
[cmdletbinding()]
param(
    [Parameter(Mandatory = $False,ValueFromPipeline = $True)]
    [string]$Uri = "",
    [Parameter(Mandatory = $false)]
    [switch]$ConvertDot = $false
)
    $Uri2 = [System.Collections.Generic.List[string]]::new()
    while ($Uri -match "^(.*?)({[^}]+})(.*?)$") {
        if ($Matches[1].Length) {[void]$Uri2.Add([System.Web.HttpUtility]::UrlEncode($Matches[1]))}
        $Tmp=$Matches[2]
        $Uri=$Matches[3]
        if ($Tmp -match "^{(\w+):(.*?)}$") {$Tmp = "{$($Matches[1]):$([System.Web.HttpUtility]::UrlEncode($($Matches[2] -replace "\$","*dollar*")) -replace "\*dollar\*","$")}"}
        [void]$Uri2.Add($Tmp)
    }
    if ($Uri.Length) {[void]$Uri2.Add([System.Web.HttpUtility]::UrlEncode($Uri))}
    $Uri = $Uri2 -join ''
    if ($ConvertDot) {$Uri -replace "\.","%2e"} else {$Uri}
}

function Get-LinuxXAuthority {
    if ($IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
        Get-ChildItem ".\IncludesLinux\bash" -Filter "getxauth.sh" -File | Foreach-Object {
            try {
                (Start-Process "chmod" -ArgumentList "+x",$_.FullName -PassThru).WaitForExit(1000) > $null
                Invoke-exe $_.FullName -ExpandLines | Where-Object {$_ -match "XAUTHORITY=(.+)"} | Foreach-Object {$Matches[1]}
            } catch {}
        }
    }
}

function Get-LinuxDisplay {
    if ($IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
        Get-ChildItem ".\IncludesLinux\bash" -Filter "getdisplay.sh" -File | Foreach-Object {
            try {
                (Start-Process "chmod" -ArgumentList "+x",$_.FullName -PassThru).WaitForExit(1000) > $null
                Invoke-exe $_.FullName -ExpandLines | Where-Object {$_ -match "DISPLAY=(.+)"} | Foreach-Object {$Matches[1]}
            } catch {}
        }
    }
}

function Wait-UntilTrue
{
    [CmdletBinding()]
    param (
        [ScriptBlock]$sb,
        [int]$TimeoutInMilliseconds = 10000,
        [int]$IntervalInMilliseconds = 1000
        )
    # Get the current time
    $startTime = [DateTime]::Now

    # Loop until the script block evaluates to true
    while (-not ($sb.Invoke())) {
        # If the timeout period has passed, return false
        if (([DateTime]::Now - $startTime).TotalMilliseconds -gt $timeoutInMilliseconds) {
            return $false
        }
        # Sleep for the specified interval
        Start-Sleep -Milliseconds $intervalInMilliseconds
    }
    return $true
}

function Wait-FileToBePresent
{
    [CmdletBinding()]
    param (
        [string]$File,
        [int]$TimeoutInSeconds = 10,
        [int]$IntervalInMilliseconds = 100
    )

    Wait-UntilTrue -sb { Test-Path $File } -TimeoutInMilliseconds ($TimeoutInSeconds*1000) -IntervalInMilliseconds $IntervalInMilliseconds > $null
}

function Test-IsElevated
{
    if ($Session.IsAdmin -ne $null) {
        $Session.IsAdmin
    } else {
        if ($IsWindows) {
            ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        } else {
            (whoami) -match "root"
        }
    }
}

function Test-IsCore
{
    $Session.IsCore -or ($Session.IsCore -eq $null -and $PSVersionTable.PSVersion -ge (Get-Version "6.1"))
}

function Test-IsPS7
{
    $Session.IsPS7 -or ($Session.IsPS7 -eq $null -and $PSVersionTable.PSVersion -ge (Get-Version "7.0"))
}

function Initialize-DLLs {
    [CmdletBinding()]
    param (
        [string]$CSFileName = "*.cs",
        [string]$CSFolder = ".\DotNet\Tools",
        [string]$DLLFolder = ".\DotNet\Bin"
    )

    if (-not (Test-Path $DLLFolder)) {
        New-Item $DLLFolder -ItemType "directory" -Force > $null
        if ($IsLinux) {
            (Start-Process "chmod" -ArgumentList "777",(Resolve-Path $DLLFolder) -PassThru).WaitForExit(1000) > $null
        }
    }
        
    $IsNetCore3Plus = $PSVersionTable.PSVersion.Major -ge 7 -and ($IsLinux -or $IsMacOS -or $IsCoreCLR) -and [System.Environment]::Version.Major -ge 3

    Get-ChildItem -Path $CSFolder -Filter $CSFileName -File | ForEach-Object {
        $CSFile = $_.FullName
        $DLLFile = Join-Path $DLLFolder "$($_.BaseName)_$($PSVersionTable.PSVersion).dll"

        # Check if the DLL needs to be rebuilt
        $NeedsRebuild = $true
        if (Test-Path $DLLFile) {
            $CSLastWrite = (Get-Item $CSFile).LastWriteTime
            $DLLLastWrite = (Get-Item $DLLFile).LastWriteTime
            if ($DLLLastWrite -gt $CSLastWrite) {
                try {
                    Add-Type -Path $DLLFile -ErrorAction Stop
                    $NeedsRebuild = $false
                } catch {
                    Write-Log -Level Warn "Cannot load $($DLLFile), will try to rebuild"
                }
            }
        }

        if ($NeedsRebuild) {
            try {
                if (Test-Path $DLLFile) {
                    try {
                        Remove-Item $DLLFile -Force -ErrorAction Stop
                    } catch {
                        Write-Log -Level Info "Cannot remove $($DLLFile) for rebuild. Compiling directly into memory."
                        $DLLFile = $null
                    }
                }

                if ($IsNetCore3Plus) {
                    $CSCode = Get-Content $CSFile -Raw
                    $CSCode = "#define NETCOREAPP3_0_OR_GREATER`n" + $CSCode
                } else {
                    $CSCode = Get-Content $CSFile -Raw
                }

                try {
                    Add-Type -TypeDefinition $CSCode -OutputAssembly $DLLFile -Language CSharp -ErrorAction Stop
                } catch {
                    if (-not $DLLFile) {
                        throw $_.Exception.Message
                    }
                    Write-Log -Level Info "Cannot rebuild $($DLLFile). Compiling directly into memory."
                    Add-Type -TypeDefinition $CSCode -Language CSharp -ErrorAction Stop
                }

                $CSCode = $null

                if ($DLLFile) {
                    Add-Type -Path $DLLFile -ErrorAction Stop
                    if ($IsLinux) {
                        (Start-Process "chmod" -ArgumentList "777",(Resolve-Path $DLLFile) -PassThru).WaitForExit(1000) > $null
                    }
                }

            } catch {
                Write-Log -Level Error "Error building $($DLLFile): $($_.Exception.Message)"
            }
        }
    }
}

function Get-RandomFileName
{
    [System.IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetRandomFileName())
}

function Get-MinerInstPath {
    [CmdletBinding()]
    param (
        [string]$Path
    )
    if ($Path -match "^(\.[/\\]Bin[/\\][^/\\]+)") {$Matches[1]}
    else {
        if (-not (Test-Path Variable:Global:MinersInstallationPath)) {$Global:MinersInstallationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\Bin")}
        if ($Path.StartsWith($Global:MinersInstallationPath) -and $Path.Substring($Global:MinersInstallationPath.Length) -match "^([/\\][^/\\]+)") {"$($Global:MinersInstallationPath)$($Matches[1])"}
        else {Split-Path $Path}
    }
}

function Get-LastSatPrice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [String]$Currency = "",
        [Parameter(Mandatory = $False)]
        [Double]$lastSatPrice = 0
    )

    if ($Global:Rates.$Currency -and -not $lastSatPrice) {$lastSatPrice = 1/$Global:Rates.$Currency*1e8}
    if (-not $Global:Rates.$Currency -and $lastSatPrice) {$Global:Rates.$Currency = 1/$lastSatPrice*1e8}
    $lastSatPrice
}

function Get-HourMinStr {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string]$Str,
        [Parameter(Mandatory = $False)]
        [switch]$to,
        [Parameter(Mandatory = $False)]
        [switch]$addseconds
    )
    $add = 0
    if ($Str -match "p") {$add = 12}
    $Str = $Str -replace "[^\d:]+"
    $Str = if ($Str -match "^\d+$") {"{0:d2}:{1}" -f (([int]$Str+$add) % 24),$(if ($to) {"59:59"} else {"00:00"})}
    elseif ($Str -match "^(\d+):(\d+)") {"{0:d2}:{1:d2}:{2}" -f (([int]$Matches[1]+$add) % 24),([int]$Matches[2] % 60),$(if ($to) {"59"} else {"00"})}
    elseif ($to) {"23:59:59"}
    else {"00:00:00"}
    if (-not $addseconds) {$Str.Substring(0,5)} else {$Str}
}

function Get-Uptime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [switch]$System
    )
    $ts = $null
    if ($System) {
        try {
            if ($IsWindows) {
                $ts = (Get-Date) - (Get-CimInstance Win32_OperatingSystem -Property LastBootUpTime -ErrorAction Ignore | Select-Object -ExpandProperty LastBootUpTime)
            } elseif ($IsLinux) {
                $ts = New-TimeSpan -Seconds ([double]((cat /proc/uptime) -split "\s+" | Select-Object -First 1))
            }
        } catch {
            Write-Log -Level Warn "Could not get system uptime: $($_.Exception.Message)"
            $ts = $null
        }
    }
    if (-not $ts) {
        try {
            $ts = (Get-Date).ToUniversalTime() - $Session.StartTime
        } catch {
            Write-Log -Level Warn "Could not get script uptime: $($_.Exception.Message)"
            $ts = $null
        }
    }
    if ($ts) {$ts} else {New-TimeSpan -Seconds 0}
}

function Get-SysInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [int]$PhysicalCPUs = 1,
        [Parameter(Mandatory = $false)]
        [bool]$IsARM = $false,
        [Parameter(Mandatory = $false)]
        [bool]$FromRegistry = $false,
        [Parameter(Mandatory = $false)]
        [double]$CPUtdp = 0
    )

    $Data = if ($IsWindows) {

        $CIM_CPU = $null

        $CPUs = @(1..$PhysicalCPUs | Foreach-Object {
            [PSCustomObject]@{
                    Clock       = 0
                    Utilization = 0
                    PowerDraw   = 0
                    Temperature = 0
                    Method      = "lhm"
            }
        } | Select-Object)

        $GetCPU_Data = @(if (Test-IsElevated) {
            try {
                if ($FromRegistry) {
                    Get-ItemPropertyValue "HKCU:\Software\RainbowMiner" -Name "GetCPU" -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                } else {
                    Invoke-Exe ".\Includes\getcpu\GetCPU.exe" | ConvertFrom-Json -ErrorAction Stop
                }
            } catch {
            }
        })
        
        try {
            $Index = 0
            $CPUs | Foreach-Object {
                $CPU = $_

                if ($GetCPU_Data -and $GetCPU_Data[$Index] -ne $null) {
                    $CPU.Clock = $GetCPU_Data[$Index].Clock
                    $CPU.Utilization = $GetCPU_Data[$Index].Utilization
                    $CPU.PowerDraw = $GetCPU_Data[$Index].PowerDraw
                    $CPU.Temperature = $GetCPU_Data[$Index].Temperature
                } else {
                    if (-not $CIM_CPU) {
                        $CIM_CPU = Get-CimInstance -ClassName CIM_Processor -Property "Name","MaxClockSpeed","LoadPercentage" -ErrorAction Ignore
                    }
                    $CPU.Method = "cim"
                    $CIM_CPU | Select-Object -Index $Index | Foreach-Object {
                        if (-not $CPU.Clock)       {$CPU.Clock = $_.MaxClockSpeed}
                        if (-not $CPU.Utilization) {$CPU.Utilization = $_.LoadPercentage}
                        if (-not $CPU.Utilization) {$CPU.Utilization = 100}
                    }
                }

                if ($CPU.Utilization -gt 0 -and $CPU.PowerDraw -eq 0) {
                    $CPU.PowerDraw = $CPUtdp * ($CPU.Utilization / 100)
                    $CPU.Method = "tdp"
                }

                $Index++
            }
        } catch {
        } finally {
            if ($CIM_CPU -ne $null) {$CIM_CPU.Dispose();$CIM_CPU = $null}
        }

        try {
            $CPULoad = ($CPUs | Measure-Object -Property Utilization -Average).Average
            $OSData  = Get-CimInstance -Class Win32_OperatingSystem -Property "TotalVisibleMemorySize","FreePhysicalMemory" -ErrorAction Ignore
        } catch {
        }

        [PSCustomObject]@{
            CpuLoad = $CPULoad
            Cpus    = $CPUs
            Gpus    = $null
            Memory  = [PSCustomObject]@{
                TotalGB = [decimal][Math]::Round($OSData.TotalVisibleMemorySize/1MB,1)
                UsedGB  = [decimal][Math]::Round(($OSData.TotalVisibleMemorySize - $OSData.FreePhysicalMemory)/1MB,1)
                UsedPercent = if ($OSData.TotalVisibleMemorySize -gt 0) {[Math]::Round(($OSData.TotalVisibleMemorySize - $OSData.FreePhysicalMemory)/$OSData.TotalVisibleMemorySize * 100,2)} else {0}
            }
            Disks   = $null
        }

        if ($OSData -ne $null) {$OSData.Dispose();$OSData = $null}

    } elseif ($IsLinux -and (Test-Path ".\IncludesLinux\bash")) {
        Get-ChildItem ".\IncludesLinux\bash" -Filter "sysinfo.sh" -File | Foreach-Object {
            try {
                (Start-Process "chmod" -ArgumentList "+x",$_.FullName -PassThru).WaitForExit(1000) > $null
                Invoke-exe $_.FullName -ArgumentList "--cpu --mem --disks" | ConvertFrom-Json -ErrorAction Stop
            } catch {}
        }
    }

    if (-not $Data) {
        $Data = [PSCustomObject]@{
            CpuLoad = 0
            Cpus = @([PSCustomObject]@{Clock=0;Temperature=0;Method="nop"})
            Gpus = $null
            Memory = [PSCustomObject]@{TotalGB=0;UsedGB=0;UsedPercent=0}
            Disks = $null
        }
    }

    $Data.Disks = @(Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -ne "Temp"} | Foreach-Object {
                    $total = $_.Free+$_.Used
                    [PSCustomObject]@{ 
                        Drive = $_.Root -replace "\\$"
                        Name = $_.Name
                        TotalGB = [decimal][Math]::Round($total/1GB,1)
                        FreeGB  = [decimal][Math]::Round($_.Free/1GB,1)
                        UsedGB  = [decimal][Math]::Round($_.Used/1GB,1)
                        UsedPercent = if ($total -gt 0) {[decimal][Math]::Round($_.Used/$total * 100,2)} else {0}
                        IsCurrent = "$($_.Root)$($_.CurrentLocation)" -eq "$(Pwd)"
                    }
                })

    $Data
}

function Get-ReadableHex32 {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    [String]$key
)
    if ($key.Length % 32) {
        $key
    } else {
        $s = ""
        for ($i=0; $i -lt $key.Length; $i+=32) {$s="$s$($key.Substring($i,8))-$($key.Substring($i+4,4))-$($key.Substring($i+8,4))-$($key.Substring($i+12,4))-$($key.Substring($i+16,12))"}
        $s
    }
}

function Get-HMACSignature {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]$string,
    [Parameter(Mandatory = $true)]
    [String]$secret,
    [Parameter(Mandatory = $false)]
    [String]$hash = "HMACSHA256"
)

    $sha = [System.Security.Cryptography.KeyedHashAlgorithm]::Create($hash)
    $sha.key = [System.Text.Encoding]::UTF8.Getbytes($secret)
    [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.Getbytes(${string}))).ToLower() -replace "[^0-9a-z]"
}

function Invoke-Reboot {
    if ($IsLinux) {
        if ((Get-Command "Test-OCDaemon" -ErrorAction Ignore) -and (Test-OCDaemon)) {
            Invoke-OCDaemon -Cmd "reboot" -Quiet > $null
        } elseif (Test-IsElevated) {
            Invoke-Exe -FilePath "reboot" -RunAs > $null
        } else {
            throw "need to be root to reboot $($Session.MachineName)"
        }
    } else {
        try {
            Restart-Computer -Force -ErrorAction Stop
        } catch {
            Write-Log "Restart-Computer command failed. Falling back to shutdown."
            shutdown /r /f /t 10 /c "RainbowMiner scheduled restart" 2>$null
            if ($LastExitCode -ne 0) {
                throw "shutdown cannot reboot $($Session.MachineName) ($LastExitCode)"
            }
        }
    }
}

function Get-LastUserInput {
    try {
        if ($IsWindows) {
            [PSCustomObject]@{
                IdleTime  = [PInvoke.Win32.UserInput]::IdleTime
                LastInput = [PInvoke.Win32.UserInput]::LastInput
            }
        }
    } catch {
    }
}

function Send-CtrlC {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [int]$ProcessID,
        [Parameter(Mandatory = $False)]
        [string]$Signal = "SIGINT" #SIGINT sends Ctrl+C, SIGBREAK sends Ctrl+Break
    )
    $Result = $false
    try {
        if ($IsWindows) {
            $WinKillResult = Invoke-Exe ".\Includes\windows-kill\$(if ([System.Environment]::Is64BitOperatingSystem) {"x64"} else {"x32"})\windows-kill.exe" -ArgumentList "-$($Signal) $($ProcessID)"
            $Result = $WinKillResult -match "success" -and $WinKillResult -match "$($ProcessId)"
            if (-not $Result) {
                Write-Log "Send-CtrlC to PID $($ProcessID) failed: $("$($WinKillResult)".Trim() -split "[`r`n]+" | Select-Object -Last 1)"
            }
        }
    } catch {
    }
    $Result
}