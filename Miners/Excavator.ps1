using module ..\Include.psm1

$Path = ".\Bin\Excavator2\excavator.exe"
$Uri = "https://github.com/nicehash/excavator/releases/download/v1.5.3a/excavator_v1.5.3a_NVIDIA_Win64.zip"

$Commands = [PSCustomObject]@{
    #"blake2s" = @() #Blake2s
    #"decred" = @() #Decred
    #"daggerhashimoto" = @() #Ethash
    #"equihash" = @() #Equihash
    "keccak" = @() #Keccak (fastest, but running on nicehash, only!)
    #"lbry" = @() #Lbry
    #"lyra2rev2" = @() #Lyra2RE2
    #"neoscrypt" = @() #NeoScrypt
    #"pascal" = @() #Pascal
    #"daggerhashimoto_decred" = @() #Ethash+Decred
    #"daggerhashimoto_pascal" = @() #Ethash+Pascal
}

$Dcris = [PSCustomObject]@{
    "daggerhashimoto_pascal" = "0:0"
    "daggerhashimoto_decred" = "0:0","16:3","16:4","16:5"
}

$Threads = [PSCustomObject]@{
    "blake2s" = 1
    "cryptonight" = 1
    "decred" = 1
    "daggerhashimoto" = 1
    "equihash" = 1,2
    "keccak" = 1
    "lbry" = 1
    "lyra2rev2" = 1,2
    "neoscrypt" = 1
    "nist5" = 1
    "pascal" = 1
    "daggerhashimoto_decred" = 1
    "daggerhashimoto_pascal" = 1
}


$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3456 + (2 * 10000)

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    try {
        $nh = ""

        $nhAlgorithm = $_
        $nhAlgorithms = @($_ -split "_")
        $nhBaseAlgorithm = $nhAlgorithms[0]

        if ((Get-Algorithm $nhBaseAlgorithm) -eq "Decred" -or (Get-Algorithm $nhBaseAlgorithm) -eq "Sia") { $nh = "NiceHash" }

        $Threads.$nhAlgorithm | Foreach-Object {
            $nhThreads = $_

            if ( -not (Test-Path (Split-Path $Path)) ) { New-Item (Split-Path $Path) -ItemType "directory" | Out-Null }

            if ($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Host -and $Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Name -like "Nicehash") {
                $gpus = $(Get-GPUlist "NVIDIA")

                if ( $nhAlgorithms.Count -eq 1 ) {
                    $res = @()
                    $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Host -replace '^[^\.]+\.','nhmp.'):3200", "$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".User):$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Pass)")})}
                    $res += [PSCustomObject]@{time = 1; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$nhBaseAlgorithm")})}
                    foreach( $gpu in $gpus ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("$nhAlgorithm", "$gpu") + $Commands.$nhAlgorithm}) * $nhThreads}}
                    $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @()})}
                    for( $worker_id=0; $worker_id -lt ($gpus.count * $nhThreads); $worker_id++ ) { $res += [PSCustomObject]@{time = 15; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                    $nhConfig = "$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Name)_$(Get-Algorithm $nhBaseAlgorithm)_$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".User)_$($nhThreads)_Nvidia.json"
                    $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$nhConfig" -Force -ErrorAction Stop

                    $MinerName = $Name + $(if($nhThreads -gt 1){$nhThreads})

                    [PSCustomObject]@{
                        Name = $MinerName
                        Type = "NVIDIA"
                        Path = $Path
                        Arguments = "-p $Port -c $nhConfig -na"
                        HashRates = [PSCustomObject]@{"$(Get-Algorithm $nhBaseAlgorithm)$nh" = $Stats."$($MinerName)_$(Get-Algorithm $nhBaseAlgorithm)$($nh)_HashRate".Week}
                        API = "Excavator"
                        Port = $Port
                        URI = $Uri
                        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                        PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                        MSIAprofile = if ( $nhBaseAlgorithm -eq "neoscrypt" ) { 3 } else { 2 }
                        ShowMinerWindow = $True
                    }
                } else {
                    $Dcris.$nhAlgorithm | Foreach-Object {
                        $Dcri = $_
                        $nh2 = ""
                        if ((Get-Algorithm $nhAlgorithms[1]) -eq "Decred" -or (Get-Algorithm $nhAlgorithms[1]) -eq "Sia") { $nh2 = "NiceHash" }
                        $MinerName = $Name + $(if($nhThreads -gt 1){$nhThreads}) + $(Get-Algorithm $nhBaseAlgorithm) + $(Get-Algorithm $nhAlgorithms[1]) + $($Dcri -replace ":","x")

                        $DcriArray = $Dcri -split ":"

                        $res = @()
                        $res += [PSCustomObject]@{time = 0; commands = @([PSCustomObject]@{id = 1; method = "subscribe"; params = @("$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Host -replace '^[^\.]+\.','nhmp.'):3200", "$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".User):$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Pass)")})}
                        $res += [PSCustomObject]@{time = 1; commands = @([PSCustomObject]@{id = 1; method = "algorithm.add"; params = @("$nhBaseAlgorithm")}) + @([PSCustomObject]@{id = 2; method = "algorithm.add"; params = @("$($nhAlgorithms[1])")})}
                        foreach( $gpu in $gpus ) { $res += [PSCustomObject]@{time = 3; commands = @([PSCustomObject]@{id = 1; method = "worker.add"; params = @("$nhAlgorithm", "$gpu", "R_0=$($DcriArray[0])", "R_1=$($DcriArray[1])") + $Commands.$nhAlgorithm}) * $nhThreads}}
                        $res += [PSCustomObject]@{time = 10; loop = 10; commands = @([PSCustomObject]@{id = 1; method = "algorithm.print.speeds"; params = @()})}
                        for( $worker_id=0; $worker_id -lt ($gpus.count * $nhThreads); $worker_id++ ) { $res += [PSCustomObject]@{time = 15; commands = @([PSCustomObject]@{id = 1; method = "worker.reset"; params = @("$worker_id")})}}

                        $nhConfig = "$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".Name)_$(Get-Algorithm $nhBaseAlgorithm)$(Get-Algorithm $nhAlgorithms[1])$($Dcri -replace ":","x")_$($Pools."$(Get-Algorithm $nhBaseAlgorithm)$nh".User)_$($nhThreads)_Nvidia.json"
                        $res | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\$nhConfig" -Force -ErrorAction Stop

                        [PSCustomObject]@{
                            Name = $MinerName
                            Type = "NVIDIA"
                            Path = $Path
                            Arguments = "-p $Port -c $nhConfig -na"
                            HashRates = [PSCustomObject]@{
                                "$(Get-Algorithm $nhBaseAlgorithm)$nh" = $Stats."$($MinerName)_$(Get-Algorithm $nhBaseAlgorithm)$($nh)_HashRate".Week
                                "$(Get-Algorithm $nhAlgorithms[1])$nh2" = $Stats."$($MinerName)_$(Get-Algorithm $nhAlgorithms[1])$($nh2)_HashRate".Week
                            }
                            API = "Excavator"
                            Port = $Port
                            URI = $Uri
                            PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
                            PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
                            MSIAprofile = if ( $nhBaseAlgorithm -eq "neoscrypt" ) { 3 } else { 2 }
                            ShowMinerWindow = $True
                        }
                    }
                }
            }
        }
    }
    catch {
    }
}