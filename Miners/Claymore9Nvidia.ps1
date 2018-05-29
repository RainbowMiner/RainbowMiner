using module ..\Include.psm1

$Path = ".\Bin\Ethash-Claymore9\monk.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v9.7-claymoredual/claymoredual_9.7.zip"
$Api = "Claymore"

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$DevFee = 0.0
$DevFeeDual = 0.0

$Commands = [PSCustomObject]@{
    "ethash" = ""
    "ethash2gb" = ""
    "ethash;decred:30" = ""
    "ethash;decred:40" = ""
    "ethash;decred:50" = ""
    "ethash;lbry:30" = ""
    "ethash;lbry:40" = ""
    "ethash;lbry:50" = ""
    "ethash;pascal:24" = ""
    "ethash;pascal:27" = ""
    "ethash;pascal:30" = ""
    "ethash;pascal:33" = ""
    "ethash;pascal:36" = ""
    #"ethash;pascal:39" = ""
    #"ethash;pascal:42" = ""
    "ethash2gb;decred:30" = ""
    "ethash2gb;decred:40" = ""
    "ethash2gb;decred:50" = ""
    "ethash2gb;lbry:30" = ""
    "ethash2gb;lbry:40" = ""
    "ethash2gb;lbry:50" = ""
    "ethash2gb;pascal:27" = ""
    "ethash2gb;pascal:30" = ""
    "ethash2gb;pascal:33" = ""
}
$CommonCommands = @(" -logsmaxsize 1", "") # array, first value for main algo, second value for secondary algo

$Profile = [PSCustomObject]@{
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

if ( $Name -like "*nvidia*" ) {
    $Type = "NVIDIA"
    $Platform = 2
    $Port = 23333
} elseif ( $Name -like "*amd*" ) {
    $Type = "AMD"
    $Platform = 1
    $Port = 13333
}

$DeviceIDs4gb = Get-GPUlist $Type 4GB -ToHex
$DeviceIDs3gb = Get-GPUlist $Type 3GB -ToHex
$DeviceIDsAll = Get-GPUlist $Type -ToHex

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $MainAlgorithm = $_.Split(";") | Select -Index 0
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm
    
    Switch ($MainAlgorithm_Norm) { # default is all devices, ethash has a 4GB minimum memory limit
        "Ethash"    {$DeviceIDs = $DeviceIDs4gb}
        "Ethash3gb" {$DeviceIDs = $DeviceIDs3gb}
        default     {$DeviceIDs = $DeviceIDsAll}
    }

    if ($Pools.$MainAlgorithm_Norm -and $DeviceIDs) { # must have a valid pool to mine and available devices

        $Miner_Name = $Name
        $MainAlgorithmCommands = $Commands.$_.Split(";") | Select -Index 0 # additional command line options for main algorithm
        $SecondaryAlgorithmCommands = $Commands.$_.Split(";") | Select -Index 1 # additional command line options for secondary algorithm

        if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = "3"} else {$EthereumStratumMode = "2"} #Optimize stratum compatibility

        if ($_ -notmatch ";") { # single algo mining
            $Miner_Name = "$($Miner_Name)$($MainAlgorithm_Norm -replace '^ethash', '')"
            $HashRateMainAlgorithm = ($Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week)

            # Single mining mode
            [PSCustomObject]@{
                Name      = $Miner_Name
                Type      = $Type
                Path      = $Path
                Arguments = ("EthDcrMiner64.exe -mode 1 -mport -$($Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 0) -esm $EthereumStratumMode -allpools 1 -allcoins 1 -platform 2 -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm}
                API       = $Api
                Port      = $Port
                URI       = $Uri
                DevFee    = $DevFee
                MSIAprofile = if ( $Profile.$MainAlgorithm_Norm ) {$Profile.$MainAlgorithm_Norm} else {$DefaultProfile}
                BaseName = "EthDcrMiner64"
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
                # Dual mining mode
                [PSCustomObject]@{
                    Name      = $Miner_Name
                    Type      = $Type
                    Path      = $Path
                    Arguments = ("EthDcrMiner64.exe -mode 0 -mport -$($Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 1) -esm $EthereumStratumMode -allpools 1 -allcoins exp -dcoin $SecondaryCoin -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand$($CommonCommands | Select -Index 1) -platform $($Platform) -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                    HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                    API       = $Api
                    Port      = $Port
                    URI       = $Uri
                    DevFee = [PSCustomObject]@{
                        ($MainAlgorithm_Norm) = $DevFeeDual
                        ($SecondaryAlgorithm_Norm) = 0
                    }
                    MSIAprofile = if ( $Profile.$SecondaryAlgorithm_Norm ) {$Profile.$SecondaryAlgorithm_Norm} else {$DefaultProfile}
                    BaseName = "EthDcrMiner64"
                }
                if ($SecondaryAlgorithm_Norm -eq "Sia" -or $SecondaryAlgorithm_Norm -eq "Decred") {
                    $SecondaryAlgorithm_Norm = "$($SecondaryAlgorithm_Norm)NiceHash"
                    [PSCustomObject]@{
                        Name      = $Miner_Name
                        Type      = $Type
                        Path      = $Path
                        Arguments = ("EthDcrMiner64.exe -mode 0 -mport -$($Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass)$MainAlgorithmCommand$($CommonCommands | Select -Index 1) -esm $EthereumStratumMode -allpools 1 -allcoins exp -dcoin $SecondaryCoin -dcri $SecondaryAlgorithmIntensity -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$SecondaryAlgorithmCommand$($CommonCommands | Select -Index 1) -platform $($Platform) -di $($DeviceIDs -join '')" -replace "\s+", " ").trim()
                        HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $HashRateMainAlgorithm; "$SecondaryAlgorithm_Norm" = $HashRateSecondaryAlgorithm}
                        API       = $Api
                        Port      = $Port
                        URI       = $Uri
                        DevFee = [PSCustomObject]@{
                            ($MainAlgorithm_Norm) = $DevFeeDual
                            ($SecondaryAlgorithm_Norm) = 0
                        }
                        MSIAprofile = if ( $Profile.$SecondaryAlgorithm_Norm ) {$Profile.$SecondaryAlgorithm_Norm} else {$DefaultProfile}
                        BaseName = "EthDcrMiner64"
                    }
                }
            }
        }
    }
}

