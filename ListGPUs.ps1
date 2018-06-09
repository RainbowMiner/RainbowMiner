using module .\Include.psm1

@(Get-Device "gpu" | Select-Object -Property Name,Vendor,Model,@{Name="Memory"; Expression={"$([math]::round($_.OpenCL.GlobalMemSize/1gb,3))GB"}})

#@(Get-Device "gpu" | Select-Object)
