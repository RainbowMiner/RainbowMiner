using module ..\Include.psm1

$Path = ".\Bin\Equihash-BMiner7\bminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v7.0.0-bminer/bminer-v7.0.0-9c7291b-amd64.zip"

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$DevFee = [PSCustomObject]@{
    "equihash" = 2.0
    "ethash" = 0.65
}

$Commands = [PSCustomObject]@{
    "equihash" = "" #" -nofee" #Equihash (fastest)
    #"ethash" = "" #Ethash (ethminer is faster and no dev fee)
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = (Get-GPUlist $Type) -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    if ( $_ -eq "equihash" ) {
        [PSCustomObject]@{
            Type = $Type
            Path = $Path
            Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:1880 -uri $(if ($Pools.$Algorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)}
            API = "Bminer"
            Port = 1880
            DevFee = $DevFee.$_
            URI = $Uri
        }
    } elseif ( $_ -eq "ethash" ) {
        [PSCustomObject]@{
            Type = $Type
            Path = $Path
            Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:1880 -uri $(if ($Pools.$Algorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)}
            API = "Bminer"
            Port = 1880
            DevFee = $DevFee.$_
            URI = $Uri
        }
    }
}