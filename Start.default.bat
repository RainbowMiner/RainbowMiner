@cd /d %~dp0

@if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
@if not "%GPU_MAX_HEAP_SIZE%"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
@if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
@if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
@if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& .\rainbowminer.ps1 -wallet <your_bitcoin_address> -username <your_pool_username> -workername <your_pool_workername> -region us -currency btc,usd,eur -type nvidia,amd -poolname miningpoolhub,nicehash,blazepool,ravenminer -algorithm bitcore,c11,cryptonight,cryptonightv7,ethash,equihash,hmq1725,hsr,keccak,keccakc,lyra2re2,lyra2z,neoscrypt,pascal,phi,skein,skunk,timetravel,tribus,x16r,x16s,x17,vit,xevan,yescrypt,yescryptr16 -excludepoolname ahashpool,blockmunch,hashrefinery,italyiimp,zpool -delay 0 -watchdog -switchingprevention 2"    

start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log '^(.+)?-\d+_\d\d\d\d-\d\d-\d\d_\d\d-\d\d-\d\d.txt' -sort '^[^_]*_' -quickstart"

pwsh -noexit -executionpolicy bypass -windowstyle maximized -command "%command%"

