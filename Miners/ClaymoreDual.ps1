using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}

if ($IsLinux) {
    $Path = ".\Bin\Ethash-ClaymoreDual\ethdcrminer64"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v15.0-claymoredual/claymoredual_v15.0_linux.tar.gz"
            Cuda = "8.0"
        }
    )
} else {
    $Path = ".\Bin\Ethash-ClaymoreDual\EthDcrMiner64.exe"
    $UriCuda = @(
        [PSCustomObject]@{            
            Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v15.0-claymoredual/claymoredual_v15.0_win_cuda10.7z"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v15.0-claymoredual/claymoredual_v15.0_win_cuda8.7z"
            Cuda = "8.0"
        }
    )
}
$ManualURI = "https://bitcointalk.org/index.php?topic=1433925.0"
$Port = "205{0:d2}"
$Version = "15.0"

$DevFee = 1.0
$DevFeeDual = 1.0

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 20; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 40; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal

    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 20; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 40; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal

    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = ""; SecondaryIntensity = 00; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 40; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 60; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "blake2s"; SecondaryIntensity = 80; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 40; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 60; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "decred"; SecondaryIntensity = 80; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 20; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 30; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "keccak"; SecondaryIntensity = 40; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 30; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 40; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "lbry"; SecondaryIntensity = 50; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 27; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 30; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondaryAlgorithm = "pascal"; SecondaryIntensity = 33; Params = ""} #Ethash/Pascal
)

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

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

for($i=0;$i -le $UriCuda.Count -and -not $Uri;$i++) {
    if (-not $Session.DevicesByTypes.NVIDIA -or (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda)) {
        $Uri = $UriCuda[$i].Uri
        $Cuda= $UriCuda[$i].Cuda
    }
}

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
		$Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
		$Miner_Model = $_.Model
		$Fee = 0
		if ($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge 4gb}) {$Fee=$DevFee}

		switch($_.Vendor) {
			"NVIDIA" {$Arguments_Platform = "-platform 2"}
			"AMD" {$Arguments_Platform = "-platform 1 -y 1"}
			Default {$Arguments_Platform = ""}
		}
		[hashtable]$Miner_Device_hash = @{}
		$Commands.MinMemGB | Select-Object -Unique | Foreach-Object {
			$MinMemGB = $_
			$Miner_Device_hash[$MinMemGB] = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb - 0.25gb)}
		}
 
		$Commands | ForEach-Object {
			$MainAlgorithm = $_.MainAlgorithm
			$MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm        
			$MinMemGB = $_.MinMemGB
            if ($_.MainAlgorithm -eq "Ethash" -and $Pools.$MainAlgorithm_Norm.CoinSymbol -eq "ETP") {$MinMemGB = 3}
			$Miner_Device = $Miner_Device_hash[$MinMemGB]

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm,"$($MainAlgorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device) {

					$DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f $_.Type_Vendor_Index} ) -join ''

					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

					$Miner_Protocol_Params = Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                        "minerproxy"       {"-esm 2"}
                        "ethproxy"         {"-esm 0"}
                        "qtminer"          {"-esm 1"}
						"ethstratumnh"     {"-esm 3"}
						default            {"-esm 2"}
					}

					if ($Arguments_Platform) {                
						$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
						$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

						if ($_.SecondaryAlgorithm) {
							$SecondaryAlgorithm = $_.SecondaryAlgorithm
							$SecondaryAlgorithm_Norm = Get-Algorithm $SecondaryAlgorithm
                            $Miner_BaseAlgo = @($($MainAlgorithm_Norm -replace '\-.*$'),$($SecondaryAlgorithm_Norm -replace '\-.*$'))
							$Miner_Name = ((@($Name) + @($MainAlgorithm_Norm -replace '^ethash', '') + @($SecondaryAlgorithm_Norm) + @(if ($_.SecondaryIntensity -ge 0) {$_.SecondaryIntensity}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
							$Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Session.Stats."$($Miner_Name)_$($MainAlgorithm_Norm -replace '\-.*$')_HashRate".Week; "$SecondaryAlgorithm_Norm" = $Session.Stats."$($Miner_Name)_$($SecondaryAlgorithm_Norm -replace '\-.*$')_HashRate".Week}
							$Pool_Port_Secondary = if ($Pools.$SecondaryAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondaryAlgorithm_Norm.Ports.GPU) {$Pools.$SecondaryAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondaryAlgorithm_Norm.Port}
							$Arguments_Secondary = "-mode 0 -dcoin $($Coins.$SecondaryAlgorithm) -dpool $($Pools.$SecondaryAlgorithm_Norm.Host):$($Pool_Port_Secondary) -dwal $($Pools.$SecondaryAlgorithm_Norm.User)$(if ($Pools.$SecondaryAlgorithm_Norm.Pass) {" -dpsw $($Pools.$SecondaryAlgorithm_Norm.Pass)"})$(if($_.SecondaryIntensity -ge 0){" -dcri $($_.SecondaryIntensity)"})"
							if ($Fee -gt 0) {$Miner_Fee = $DevFeeDual}
						}
						else {
                            $Miner_BaseAlgo = @($MainAlgorithm_Norm -replace '\-.*$')
							$Miner_Name = ((@($Name) + @($MainAlgorithm_Norm -replace '^ethash', '') + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
							$Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Session.Stats."$($Miner_Name)_$($MainAlgorithm_Norm -replace '\-.*$')_HashRate".Week}
							$Arguments_Secondary = "-mode 1"
							$Miner_Fee = $Fee
						}

						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path               
							Arguments      = "-mport -$($Miner_Port) -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) $(if ($Pools.$MainAlgorithm_Norm.Wallet) {"-ewal $($Pools.$MainAlgorithm_Norm.Wallet) -eworker $($Pools.$MainAlgorithm_Norm.Worker)"} else {"-ewal $($Pools.$MainAlgorithm_Norm.User)"})$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -epsw $($Pools.$MainAlgorithm_Norm.Pass)"}) -allpools 1 -allcoins $(if ($MainAlgorithm_Norm -eq "Ethash") {"etc"} else {"1"}) -wd 1 -logsmaxsize 10 -r -1 -dbg -1 $($Miner_Protocol_Params) $($Arguments_Secondary) $($Arguments_Platform) -di $($DeviceIDsAll) $($_.Params)"
							HashRates      = $Miner_HashRates
							API            = "Claymore"
							Port           = $Miner_Port
							Uri            = $Uri
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
                            Penalty        = 0
							DevFee         = if ($_.SecondaryAlgorithm) {[PSCustomObject]@{$MainAlgorithm_Norm = $Miner_Fee;$SecondaryAlgorithm_Norm = 0.0}} else {[PSCustomObject]@{$MainAlgorithm_Norm = $Miner_Fee}}
							ManualUri      = $ManualUri
                            StopCommand    = "Start-Sleep 3"
							EnvVars        = if ($Miner_Vendor -eq "AMD") {@("GPU_FORCE_64BIT_PTR=0")} else {$null}
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $Miner_BaseAlgo
						}
					}
				}
			}
		}
	}
}