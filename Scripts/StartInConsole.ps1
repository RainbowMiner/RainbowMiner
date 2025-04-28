param($ControllerProcessID, $CreateProcessPath, $LDExportPath, $FilePath, $ArgumentList, $WorkingDirectory, $LogPath, $EnvVars, $StartWithoutTakingFocus, $LinuxDisplay, $CurrentPwd, $SetLDLIBRARYPATH, $LinuxNiceness)

$EnvVars | Where-Object {$_ -match "^(\S*?)\s*=\s*(.*)$"} | Foreach-Object {Set-Item -force -path "env:$($matches[1])" -value $matches[2]}

$ControllerProcess = Get-Process -Id $ControllerProcessID
if ($ControllerProcess -eq $null) {return}

if ($StartWithoutTakingFocus) {
    Add-Type -Path $CreateProcessPath
    $lpApplicationName = $FilePath;
    $lpCommandLine = '"' + $FilePath + '"' #Windows paths cannot contain ", so there is no need to escape
    if ($ArgumentList -ne "") {$lpCommandLine += " " + $ArgumentList}
    $lpProcessAttributes = New-Object SECURITY_ATTRIBUTES
    $lpProcessAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpProcessAttributes)
    $lpThreadAttributes = New-Object SECURITY_ATTRIBUTES
    $lpThreadAttributes.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($lpThreadAttributes)
    $bInheritHandles = $false
    $dwCreationFlags = [CreationFlags]::CREATE_NEW_CONSOLE
    $lpEnvironment = [IntPtr]::Zero
    if ($WorkingDirectory -ne "") {$lpCurrentDirectory = $WorkingDirectory} else {$lpCurrentDirectory = $using:pwd}
    $lpStartupInfo = New-Object STARTUPINFO
    $lpStartupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($lpStartupInfo)
    $lpStartupInfo.wShowWindow = [ShowWindow]::SW_SHOWMINNOACTIVE
    $lpStartupInfo.dwFlags = [STARTF]::STARTF_USESHOWWINDOW
    $lpProcessInformation = New-Object PROCESS_INFORMATION

    [Kernel32]::CreateProcess($lpApplicationName, $lpCommandLine, [ref] $lpProcessAttributes, [ref] $lpThreadAttributes, $bInheritHandles, $dwCreationFlags, $lpEnvironment, $lpCurrentDirectory, [ref] $lpStartupInfo, [ref] $lpProcessInformation)
    $Process = Get-Process -Id $lpProcessInformation.dwProcessID
} else {

    if ($ArgumentList -eq "") {
        $ProcessParams = @{
            FilePath         = $FilePath
            WorkingDirectory = $WorkingDirectory
            PassThru         = $true
        }
    } else {
        $ProcessParams = @{
            FilePath         = $FilePath
            ArgumentList     = $ArgumentList
            WorkingDirectory = $WorkingDirectory
            PassThru         = $true
        }
    }

    if ($IsLinux) {
        # Linux requires output redirection, otherwise Receive-Job fails
        $ProcessParams.RedirectStandardOutput = $LogPath
        $ProcessParams.RedirectStandardError  = $LogPath -replace ".txt","-err.txt"

        # Fix executable permissions
        $Chmod_Process = Start-Process "chmod" -ArgumentList "+x $FilePath" -PassThru
        $Chmod_Process.WaitForExit(1000) > $null

        # Set lib path to local
        #$BE = "/usr/lib/x86_64-linux-gnu/libcurl-compat.so.3.0.0"
        if ($LinuxDisplay) {$env:DISPLAY = "$($LinuxDisplay)"}
        if ($SetLDLIBRARYPATH) {$env:LD_LIBRARY_PATH = "$($LDExportPath)"}

        # Set nice level if requested
        if ($LinuxNiceness -ne "") {
            $OriginalFilePath = $ProcessParams.FilePath
            $ProcessParams.FilePath = (Get-Command nice).Source
            if (-not $ProcessParams.ArgumentList) {
                $ProcessParams.ArgumentList = "-n $LinuxNiceness $OriginalFilePath"
            } else {
                $ProcessParams.ArgumentList = "-n $LinuxNiceness $OriginalFilePath $($ProcessParams.ArgumentList)"
            }
        }
    }

    $Process = Start-Process @ProcessParams
}
if ($Process -eq $null) {
    [PSCustomObject]@{ProcessId = $null}
    return
}

[PSCustomObject]@{ProcessId = $Process.Id}

$ControllerProcess.Handle >$null
$Process.Handle >$null

do {
    if ($Done = $ControllerProcess.WaitForExit(1000)) {
        $Process.CloseMainWindow()>$null
    }
    if ($Global:Error.Count) {
        $logDate = Get-Date -Format "yyyy-MM-dd"
        $errPath = Join-Path $CurrentPwd "Logs\errors_$(Get-Date -Format "yyyy-MM-dd").jobs.txt"
        foreach ($err in $Global:Error) {
            if ($err.Exception.Message) {
                Write-ToFile -FilePath $errPath -Message "Error during $($FilePath) $($Argumentlist): $($err.Exception.Message)" -Append -Timestamp
            }
        }
        $Global:Error.Clear()
    }
}
while (-not $Done -and $Process.HasExited -eq $false)

$Process = $null