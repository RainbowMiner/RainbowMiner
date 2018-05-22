using module ..\Include.psm1

$Path = ".\Bin\Equihash-BMiner\bminer.exe"
$URI = "https://www.bminercontent.com/releases/bminer-v7.0.0-9c7291b-amd64.zip"
$DevFee = [PSCustomObject]@{
    "equihash" = 2.0
    "ethash" = 0.65
}

$Commands = [PSCustomObject]@{
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"c11" = "" #C11
    #"cryptonight" = "" #CryptoNight
    #"decred" = "" #Decred
    "equihash" = "" #" -nofee" #Equihash
    "ethash" = "" #Ethash
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

$DeviceIDsAll = Get-GPUlist "NVIDIA"

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    if ( $_ -eq "equihash" ) {
        [PSCustomObject]@{
            Type = "NVIDIA"
            Path = $Path
            Arguments = "-devices $($DeviceIDsAll -join ',') -api 127.0.0.1:1880 -uri $(if ($Pools.$Algorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)}
            API = "Bminer"
            Port = 1880
            DevFee = $DevFee.$_
            URI = $Uri
        }
    } elseif ( $_ -eq "ethash" ) {
        [PSCustomObject]@{
            Type = "NVIDIA"
            Path = $Path
            Arguments = "-devices $($DeviceIDsAll -join ',') -api 127.0.0.1:1880 -uri $(if ($Pools.$Algorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)}
            API = "Bminer"
            Port = 1880
            DevFee = $DevFee.$_
            URI = $Uri
        }
    }
}