using module ..\Include.psm1

$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v11.8-claymoredual/claymoredual_11.8.zip"
$Api = "Claymore"

$DevFee = 1.0
$DevFeeDual = 1.5

$Commands = [PSCustomObject]@{
    "ethash" = ""
    "ethash2gb" = ""
    "ethash;blake2s:40" = ""
    "ethash;blake2s:60" = ""
    "ethash;blake2s:80" = ""
    #"ethash;decred:40" = ""
    #"ethash;decred:60" = ""
    #"ethash;decred:80" = ""
    #"ethash:keccak:24" = ""
    "ethash;keccak:27" = ""
    "ethash;keccak:30" = ""
    "ethash;keccak:33" = ""
    #"ethash;keccak:36" = ""
    #"ethash;keccak:39" = ""
    #"ethash;lbry:30" = ""
    #"ethash;lbry:40" = ""
    #"ethash;lbry:50" = ""
    #"ethash;lbry:60" = ""
    "ethash;pascal:27" = ""
    "ethash;pascal:30" = ""
    "ethash;pascal:33" = ""
    #"ethash;pascal:36" = ""
    #"ethash;pascal:39" = ""
    #"ethash;pascal:42" = ""
    "ethash2gb;blake2s:40" = ""
    "ethash2gb;blake2s:60" = ""
    "ethash2gb;blake2s:80" =  ""
    #"ethash2gb;decred:40" = ""
    #"ethash2gb;decred:60" = ""
    #"ethash2gb;decred:80" = ""
    "ethash2gb;keccak:27" = ""
    "ethash2gb;keccak:30" = ""
    "ethash2gb;keccak:33" = ""
    #"ethash2gb;lbry:60" = ""
    #"ethash2gb;lbry:75" = ""
    #"ethash2gb;lbry:90" = ""
    #"ethash2gb;pascal:40" = ""
    #"ethash2gb;pascal:60" = ""
    #"ethash2gb;pascal:80" = ""
}
$CommonCommands = @(" -logsmaxsize 1 -y 1", "") # array, first value for main algo, second value for secondary algo

$Profile = [PSCustomObject]@{
    "Blake2s" = 5
    "Keccak" = 3
    "Pascal" = 5
}
$DefaultProfile = 2

#
# Internal presets, do not change from here on
#
$Coins = [PSCustomObject]@{
    "Pascal" = "pasc"
    "Lbry" = "lbc"
    "Decred" = "dcr"
    "Sia" = "sc"
    "Keccak" = "keccak"
    "Blake2s" = "blake2s"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Platforms = @()

if ($Devices.NVIDIA -and -not $Config.InfoOnly) {
    $Platforms += [PSCustomObject]@{
        Platform = 2
        Port = 23333
        Devices = "Nvidia"
    }
}

if ($Devices.AMD -and -not $Config.InfoOnly) {
    $Platforms += [PSCustomObject]@{
        Platform = 1
        Port = 13333
        Devices = "Amd"
    }
}

$Platforms | Foreach-Object {
    $Platform = $_

    $Device3gb = Select-Device $Devices.($Platform.Devices) -MinMemSize 3gb
    $Device4gb = Select-Device $Device3gb -MinMemSize 4gb

    $Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

        $MainAlgorithm = $_.Split(";") | Select -Index 0
        $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm
    
        Switch ($MainAlgorithm_Norm) { # default is all devices, ethash has a 4GB minimum memory limit
            "Ethash"    {$Device = $Device4gb}
            "Ethash3gb" {$Device = $Device3gb}
            default     {$Device = $Devices.($Platform.Devices)}
        }
        $DeviceIDs = Get-GPUIDs $Device -join '' -ToHex

        if ($Pools.$MainAlgorithm_Norm -and $Device) { # must have a valid pool to mine and available devices

            $Miner_Name = "$($Name)$($Platform.Devices)"
            $MainAlgorithmCommands = $Commands.$_.Split(";") | Select -Index 0 # additional command line options for main algorithm
            $SecondaryAlgorithmCommands = $Commands.$_.Split(";") | Select -Index 1 # additional command line options for secondary algorithm

            if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = "3"} else {$EthereumStratumMode = "2"} #Optimize stratum compatibility

            if ($_ -notmatch ";") { # single algo mining
                $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')"
                $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)

                # Single mining mode
                [PSCustomObject]@{
                    Name      = $Miner_Name
                    DeviceName = $Device.Name
                    Path      = $Path
                    Arguments = ("-mode 1 -mport -$($Platform.Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 0) -esm $EthereumStratumMode -allpools 1 -allcoins 1 -platform $($Platform.Platform) -di $($DeviceIDs)" -replace "\s+", " ").trim()
                    HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                    API       = $Api
                    Port      = $Platform.Port
                    URI       = $Uri
                    DevFee    = if (-not ($Device | Where-Object GlobalMemsize -GT 2000000000)){0}else{$DevFee}
                    MSIAprofile = if ( $Profile.$MainAlgorithm_Norm ) {$Profile.$MainAlgorithm_Norm} else {$DefaultProfile}
                    BenchmarkIntervals = 2
                }
            }
            elseif ($_ -match "^.+;.+:\d+$") { # valid dual mining parameter set

                $SecondaryAlgorithm = ($_.Split(";") | Select -Index 1).Split(":") | Select -Index 0
                $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
                $SecondaryAlgorithmIntensity = ($_.Split(";") | Select -Index 1).Split(":") | Select -Index 1

                $SecondaryCoin = $Coins.$SecondaryAlgorithm_Norm
        
                $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondaryAlgorithm_Norm)$($SecondaryAlgorithmIntensity)"
                $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)
                $HashRateSecondaryAlgorithm = ($Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week)

                if ($Pools.$SecondaryAlgorithm_Norm -and $SecondaryAlgorithmIntensity -gt 0) { # must have a valid pool to mine and positive intensity
                    [PSCustomObject]@{
                        Name      = $Miner_Name
                        DeviceName = $Device.Name
                        Path      = $Path
                        Arguments = ("-mode 0 -mport -$($Platform.Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 1) -esm $EthereumStratumMode -allpools 1 -allcoins 1 -dcoin $SecondaryCoin -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand$($CommonCommands | Select -Index 1) -platform $($Platform.Platform) -di $($DeviceIDs)" -replace "\s+", " ").trim()
                        HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                        API       = $Api
                        Port      = $Platform.Port
                        URI       = $Uri
                        DevFee = [PSCustomObject]@{
                            ($MainAlgorithm_Norm) = if (-not ($Device | Where-Object GlobalMemsize -GT 2000000000)){0}else{$DevFeeDual}
                            ($SecondaryAlgorithm_Norm) = 0
                        }
                        MSIAprofile = if ( $Profile.$SecondaryAlgorithm_Norm ) {$Profile.$SecondaryAlgorithm_Norm} else {$DefaultProfile}
                        BenchmarkIntervals = 2
                    }
                }
            }
        }
    }
}