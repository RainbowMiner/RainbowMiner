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

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = ""; SecondIntensity = 00; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "blake2s"; SecondIntensity = 40; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "blake2s"; SecondIntensity = 60; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "blake2s"; SecondIntensity = 80; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "decred"; SecondIntensity = 40; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "decred"; SecondIntensity = 60; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "decred"; SecondIntensity = 80; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "keccak"; SecondIntensity = 20; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "keccak"; SecondIntensity = 30; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "keccak"; SecondIntensity = 40; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "lbry"; SecondIntensity = 30; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "lbry"; SecondIntensity = 40; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "lbry"; SecondIntensity = 50; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "pascal"; SecondIntensity = 27; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "pascal"; SecondIntensity = 30; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash"; MinMemGB = 4; SecondAlgorithm = "pascal"; SecondIntensity = 33; Params = ""} #Ethash/Pascal

    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = ""; SecondIntensity = 00; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "blake2s"; SecondIntensity = 40; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "blake2s"; SecondIntensity = 60; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "blake2s"; SecondIntensity = 80; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "decred"; SecondIntensity = 40; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "decred"; SecondIntensity = 60; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "decred"; SecondIntensity = 80; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "keccak"; SecondIntensity = 20; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "keccak"; SecondIntensity = 30; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "keccak"; SecondIntensity = 40; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "lbry"; SecondIntensity = 30; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "lbry"; SecondIntensity = 40; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "lbry"; SecondIntensity = 50; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "pascal"; SecondIntensity = 27; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "pascal"; SecondIntensity = 30; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; SecondAlgorithm = "pascal"; SecondIntensity = 33; Params = ""} #Ethash/Pascal

    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = ""; SecondIntensity = 00; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "blake2s"; SecondIntensity = 40; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "blake2s"; SecondIntensity = 60; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "blake2s"; SecondIntensity = 80; Params = ""} #Ethash/Blake2s
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "decred"; SecondIntensity = 40; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "decred"; SecondIntensity = 60; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "decred"; SecondIntensity = 80; Params = ""} #Ethash/Decred
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "keccak"; SecondIntensity = 20; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "keccak"; SecondIntensity = 30; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "keccak"; SecondIntensity = 40; Params = ""} #Ethash/Keccak
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "lbry"; SecondIntensity = 30; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "lbry"; SecondIntensity = 40; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "lbry"; SecondIntensity = 50; Params = ""} #Ethash/Lbry
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "pascal"; SecondIntensity = 27; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "pascal"; SecondIntensity = 30; Params = ""} #Ethash/Pascal
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; SecondAlgorithm = "pascal"; SecondIntensity = 33; Params = ""} #Ethash/Pascal
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
    if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -or (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda)) {
        $Uri = $UriCuda[$i].Uri
        $Cuda= $UriCuda[$i].Cuda
    }
}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
		$Miner_Model = $_.Model
		$Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
		$Fee = 0
		if ($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge 4gb}) {$Fee=$DevFee}

		switch($_.Vendor) {
			"NVIDIA" {$Arguments_Platform = "-platform 2"}
			"AMD" {$Arguments_Platform = "-platform 1 -y 1"}
			Default {$Arguments_Platform = ""}
		}
 
		$Commands | ForEach-Object {
            $First = $true
			$MainAlgorithm = $_.MainAlgorithm
			$MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm
            $SecondAlgorithm = $_.SecondAlgorithm
			$MinMemGB = $_.MinMemGB
            if ($_.MainAlgorithm -eq "Ethash" -and $Pools.$MainAlgorithm_Norm_0.CoinSymbol -eq "ETP") {$MinMemGB = 3}

            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb - 0.25gb)}

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Fee = $Fee
                        if ($SecondAlgorithm) {
				            $SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
                            $Miner_BaseAlgo = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
                            $Miner_Name = ((@($Name) + @($MainAlgorithm_Norm_0 -replace '^ethash', '') + @($SecondAlgorithm_Norm) + @(if ($_.SecondIntensity -ge 0) {$_.SecondIntensity}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
				            if ($Miner_Fee -gt 0) {$Miner_Fee = $DevFeeDual}
                        } else {
                            $Miner_BaseAlgo = $MainAlgorithm_Norm_0
				            $Miner_Name = ((@($Name) + @($MainAlgorithm_Norm_0 -replace '^ethash', '') + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-') -replace '-+','-'
                        }
                        $DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f $_.Type_Vendor_Index} ) -join ''
                        $First = $false
                    }

					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

					$Miner_Protocol_Params = Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                        "minerproxy"       {"-esm 2"}
                        "ethproxy"         {"-esm 0"}
                        "qtminer"          {"-esm 1"}
						"ethstratumnh"     {"-esm 3"}
						default            {"-esm 2"}
					}

                    if ($Pools.$MainAlgorithm_Norm.Name -eq "F2pool" -and $Pools.$MainAlgorithm_Norm.User -match "^0x[0-9a-f]{40}") {$Pool_Port = 8008}

					if ($Arguments_Platform) {
						if ($SecondAlgorithm) {
							$Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week; "$SecondAlgorithm_Norm" = $Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm)_HashRate".Week}
							$Pool_Port_Second = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
							$Arguments_Second = "-mode 0 -dcoin $($Coins.$SecondAlgorithm) -dpool $($Pools.$SecondAlgorithm_Norm.Host):$($Pool_Port_Second) -dwal $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" -dpsw $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if($_.SecondIntensity -ge 0){" -dcri $($_.SecondIntensity)"})"
						}
						else {
							$Miner_HashRates = [PSCustomObject]@{"$MainAlgorithm_Norm" = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
							$Arguments_Second = "-mode 1"
						}

						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path               
							Arguments      = "-mport -`$mport -epool $($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) $(if ($Pools.$MainAlgorithm_Norm.Wallet) {"-ewal $($Pools.$MainAlgorithm_Norm.Wallet) -eworker $($Pools.$MainAlgorithm_Norm.Worker)"} else {"-ewal $($Pools.$MainAlgorithm_Norm.User)"})$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -epsw $($Pools.$MainAlgorithm_Norm.Pass)"}) -allpools 1 -allcoins $(if ($MainAlgorithm_Norm -match "^Ethash") {"etc"} else {"1"}) -wd 1 -logsmaxsize 10 -r -1 -dbg -1 $($Miner_Protocol_Params) $($Arguments_Second) $($Arguments_Platform) -di $($DeviceIDsAll) $($_.Params)"
							HashRates      = $Miner_HashRates
							API            = "Claymore"
							Port           = $Miner_Port
							Uri            = $Uri
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
                            Penalty        = 0
							DevFee         = if ($SecondAlgorithm) {[PSCustomObject]@{$MainAlgorithm_Norm = $Miner_Fee;$SecondAlgorithm_Norm = 0.0}} else {[PSCustomObject]@{$MainAlgorithm_Norm = $Miner_Fee}}
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