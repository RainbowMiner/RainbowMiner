using module .\Include.psm1

@(Get-Device "gpu" | Select-Object -Property Name,Vendor,@{Name="CardName"; Expression={$_.OpenCL.Name}},@{Name="Memory"; Expression={"$([math]::round($_.OpenCL.GlobalMemSize/1gb,3))GB"}})

#@(Get-Device "gpu" | Select-Object)
