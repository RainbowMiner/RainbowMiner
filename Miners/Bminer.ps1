using module ..\Include.psm1

$Path = ".\Bin\Equihash-BMiner\bminer.exe"
$URI = "https://www.bminercontent.com/releases/bminer-v8.0.0-32928c5-amd64.zip"

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$DevFee = [PSCustomObject]@{
    "equihash" = 2.0
    "ethash" = 0.65
    "ethash;blake2s" = 1.3
    "ethash;blake14r" = 1.3
}

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore
    #"blake14r" = "" #Blake14r
    #"blake2s" = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"c11" = "" #C11
    #"cryptonight" = "" #CryptoNight
    #"decred" = "" #Decred
    "equihash" = "" #" -nofee" #Equihash
    "ethash" = "" #Ethash
    "ethash;blake2s" = "" #Ethash + Blake2s
    "ethash;blake14r" = "" #Ethash + Decred
    #"groestl" = "" #Groestl
    #"hmq1725" = "" #HMQ1725
    #"jha" = "" #JHA
    #"keccak" = "" #Keccak
    #"lbry" = "" #Lbry
    #"lyra2v2" = "" #Lyra2RE2
    #"lyra2z" = "" #Lyra2z
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"nist5" = "" #Nist5
    #"pascal" = "" #Pascal
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sib" = "" #Sib
    #"skein" = "" #Skein
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"veltor" = "" #Veltor
    #"x11" = "" #X11
    #"x11evo" = "" #X11evo
    #"x17" = "" #X17
    #"yescrypt" = "" #Yescrypt
    #"xevan" = "" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = (Get-GPUlist $Type) -join ','

$Commands | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {

    $MinerAlgorithms = $_.Split(";")

    $MainAlgorithm = $MinerAlgorithms[0]
    $MainAlgorithm_Norm = Get-Algorithm $MainAlgorithm

    if ( $MinerAlgorithms.Count -gt 1 ) {
        $SecondAlgorithm = $MinerAlgorithms[1]
        $SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
    } else {
        $SecondAlgorithm = $false
    }

    if ( $MainAlgorithm -eq "equihash" ) {
        [PSCustomObject]@{
            Type = $Type
            Path = $Path
            Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:1880 -uri $(if ($Pools.$MainAlgorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
            HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week)}
            API = "Bminer"
            Port = 1880
            DevFee = $DevFee.$_
            URI = $Uri
        }
    } elseif ( $MainAlgorithm -eq "ethash" ) {        
        if ( -not $SecondAlgorithm ) {
            [PSCustomObject]@{
                Type = $Type
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:1880 -uri $(if ($Pools.$MainAlgorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                HashRates = [PSCustomObject]@{$MainAlgorithm_Norm = $($Stats."$($Name)_$($MainAlgorithm_Norm)_HashRate".Week)}
                API = "Bminer"
                Port = 1880
                DevFee = $DevFee.$_
                URI = $Uri
            }
        } else {
            $MinerName = "$($Name)$($MainAlgorithm_Norm -replace '^ethash', '')$($SecondAlgorithm_Norm)"
            [PSCustomObject]@{
                Name = $MinerName
                Type = $Type
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:1880 -uri $(if ($Pools.$MainAlgorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$MainAlgorithm_Norm.Pass))@$($Pools.$MainAlgorithm_Norm.Host):$($Pools.$MainAlgorithm_Norm.Port) -uri2 $($SecondAlgorithm)://$([System.Web.HttpUtility]::UrlEncode($Pools.$SecondAlgorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$SecondAlgorithm_Norm.Pass))@$($Pools.$SecondAlgorithm_Norm.Host):$($Pools.$SecondAlgorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
                HashRates = [PSCustomObject]@{
                    $MainAlgorithm_Norm = $($Stats."$($MinerName)_$($MainAlgorithm_Norm)_HashRate".Week)
                    $SecondAlgorithm_Norm = $($Stats."$($MinerName)_$($SecondAlgorithm_Norm)_HashRate".Week)
                }
                API = "Bminer"
                Port = 1880
                DevFee = [PSCustomObject]@{
                    ($MainAlgorithm_Norm) = $DevFee.$_
                    ($SecondAlgorithm_Norm) = 0
                }
                URI = $Uri
            }
        }
    }
}