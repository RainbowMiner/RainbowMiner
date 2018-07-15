using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Ethash-Claymore\EthDcrMiner64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v11.9-claymoredual/claymoredual_v11.9.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=1433925.0"
$Port = "203{0:d2}"

$DevFee = 1.0
$DevFeeDual = 1.5

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 17; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 21; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 24; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 27; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 33; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal

    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 17; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 21; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 24; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 27; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal

    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 17; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 21; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 24; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 27; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 33; Params = ""} #Ethash/Keccak
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal
)
#-logsmaxsize 1

#
# Internal presets, do not change from here on
#
$Coins = [PSCustomObject]@{
    "pascal" = "pasc"
    "lbry" = "lbc"
    "decred" = "dcr"
    "sia" = "sc"
    "keccak" = "keccak"
    "blake2s" = "blake2s"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices = @($Devices.NVIDIA) + @($Devices.AMD) 
if (-not $Devices -and -not $Config.InfoOnly) {return} # No GPU present in system

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Vendor = Get-DeviceVendor $_
    $Miner_Model = $_.Model
    $Fee = 0
    if (Select-Device $Device -MinMemSize 2.1Gb) {$Fee=$DevFee}

    switch($Miner_Vendor) {
        "NVIDIA" {$Arguments_Platform = " -platform 2"}
        "AMD" {$Arguments_Platform = " -platform 1 -y 1"}
        Default {$Arguments_Platform = ""}
    }

    $Commands | ForEach-Object {
        $MainAlgorithm = $_.MainAlgorithm
        $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm
        #$Miner_Device = Select-Device $Device -MinMemSize ($_.MinMemGB*1gb)
        $MinMemGB = $_.MinMemGB
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1gb})
        
        if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device) {

            $DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f $_.Type_PlatformId_Index} ) -join ''

            if ($Pools.$MainAlgorithm_Norm.Name -eq 'NiceHash') {$EthereumStratumMode = "3"} else {$EthereumStratumMode = "2"} #Optimize stratum compatibility

            if ($Arguments_Platform) {
                if ($_.SecondaryAlgorithm) {
                    $SecondaryAlgorithm = $_.SecondaryAlgorithm
                    $SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm

                    $Miner_Name = ((@($Name) + @($MainAlgorithm_Norm -replace '^ethash', '') + @($SecondaryAlgorithm_Norm) + @(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
                    $Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week; "$SecondaryAlgorithm_Norm" = $Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm)_HashRate".Week}
                    $Arguments_Secondary = " -mode 0 -dcoin $($Coins.$SecondaryAlgorithm) -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pools.$SecondaryAlgorithm_Norm.Port) -dwal $($Pools.$SecondaryAlgorithm_Norm.User) -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)$(if($_.SecondaryIntensity -ge 0){" -dcri $($_.SecondaryIntensity)"})"
                    if ($Fee -gt 0) {$Miner_Fee = $DevFeeDual}
                }
                else {
                    $Miner_Name = ((@($Name) + @($MainAlgorithm_Norm -replace '^ethash', '') + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
                    $Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Stats."$($Miner_Name)_$($MainAlgorithm_Norm)_HashRate".Week}
                    $Arguments_Secondary = " -mode 1"
                    $Miner_Fee = $Fee
                }

                [PSCustomObject]@{
                    Name        = $Miner_Name
                    DeviceName  = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path        = $Path               
                    Arguments   = ("-mport -$($Miner_Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -ewal $($Pools.$MainAlgorithm_Norm.User) -epsw $($Pools.$MainAlgorithm_Norm.Pass) -allpools 1 -allcoins exp -esm $($EthereumStratumMode)$($Arguments_Secondary)$($_.Params)$($Arguments_Platform) -di $($DeviceIDsAll)" -replace "\s+", " ").trim()
                    HashRates   = $Miner_HashRates
                    API         = "Claymore"
                    Port        = $Miner_Port
                    URI         = $Uri
                    DevFee      = [PSCustomObject]@{$MainAlgorithm_Norm = $Miner_Fee;$SecondaryAlgorithm_Norm = 0.0}
                }
            }
        }
    }
}