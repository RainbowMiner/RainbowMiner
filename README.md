# RainbowMiner [![current release](https://img.shields.io/github/release/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/releases) [![current release date](https://img.shields.io/github/release-date/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/releases) [![open issues](https://img.shields.io/github/issues-raw/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/issues)
###### **RELEASES: [https://github.com/RainbowMiner/RainbowMiner/releases](https://github.com/RainbowMiner/RainbowMiner/releases)**

###### **Actual master.zip: [Developer Version master.zip](https://github.com/RainbowMiner/RainbowMiner/archive/master.zip)**

###### **Central monitoring for all of your rigs: [https://rbminer.net](https://rbminer.net)**

###### **Discord: [https://discord.gg/ZBNVWYY](https://discord.gg/ZBNVWYY)**


## INTRODUCTION

GPU/CPU Mining script with intelligent auto-switching between different miningpools, algorithm, miner programs using all possible combinations of devices (NVIDIA, AMD and CPU), optionally including cost of electricity into profit calculations and  stop mining, if no longer profitable.
Features: easy setup wizard with adhoc working default (no editing of files needed), GUI-webinterface, selection of devices to be used, very low CPU usage.


![alt text](https://raw.githubusercontent.com/RainbowMiner/miner-binaries/master/rainbowminerhome.png "RainbowMiner Web GUI")


## FEATURE SUMMARY

- **Multi-Platform (AMD, NVIDIA, CPU) on Windows and Linux**
- **Profit auto-switch between mining programs and [algorithm](https://rbminer.net/algorithms/) for GPUs & CPUs (optimized one for each vendor vs. one for each possible device combination)**
- **Profit auto-switch between pools (2Miners, AHashPool, BaikalMiner, BlazePool, BlockCruncher, BlockMasters, Bsod, CryptoKnight, EthashPool, Ethermine, F2pool, FairPool, FlyPool, GosCx, GrinMint, Hashpool, HashVault, HeroMiners, Icemining, LuckyPool, MinerMore, MinerRocks, MiningPoolHub, [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069), Mintpond, Nanopool, Nicehash, PhiPhiPool, PocketWhale, Ravenminer, SparkPool, SuprNova, UUpool, YiiMP, Zergpool and Zpool)**
- **Profit calculation, including real cost of electricity per miner**
- **Uses the top actual available miner programs (Bminer, Ccminer, Claymore, CryptoDredge, Dstm, EnemyZ, Ewbf, Gminer, NBminer, Sgminer, SrbMiner, T-Rex, Xmrig and many more)**
- **Easy setup wizard with adhoc working default - click Start.bat and off you go (RainbowMiner will ask for your credentials, no hassle with editing configuration files)**
- **CLient/Server networking for multiple rigs, to minimize internet traffic and avoid pool bans**
- **Scheduler for different power prices and/or pause during specific timespans**
- **Build-in automatic update**
- **Mining devices freely selectable**
- **Finetune miner- and pool-configuration during runtime**
- **Bind/exclude devices to/from specific algorithm and miners**
- **Define pool's algorithms and coins**
- **Use unlimited custom overclocking profiles per miner/algorithm**
- **Easy overclocking of gpus (memory, core, powerlimit and voltage)**
- **Switch MSI Afterburner profiles per miner/algorithm**
- **Includes [OhGodAnETHlargementPill](https://bitcointalk.org/index.php?topic=3370685.0)**
- **Very low CPU usage to increase CPU mining profit**
- **Pause mining without exiting the RainbowMiner**
- **Full automatic update**
- **Easy replication and setup configuration**
- **Live monitoring web-interface at [localhost:4000](http://localhost:4000)**
- **Central monitoring of all your rigs at [https://rbminer.net](https://rbminer.net)**
- **Offline notifications via email and/or https://pushover.net**

## REQUIRED PRE-REQUESITES

### Windows 7/8.1/10 pre-requesites

1. Install PowerShell 6: [Download Installer for version 6.2.1](https://github.com/PowerShell/PowerShell/releases/download/v6.2.1/PowerShell-6.2.1-win-x64.msi)
2. Install Microsoft .NET Framework 4.5.1 or later: [Web Installer](https://www.microsoft.com/net/download/dotnet-framework-runtime)
3. Update GPU drivers: [Nvidia 431.60](https://www.nvidia.com/Download/index.aspx) and [AMD Adrenalin 2019 Edition 19.5.2](https://support.amd.com/en-us/download/desktop?os=Windows+10+-+64)
4. If your rig contains AMD graphic cards, RainbowMiner's overclocking features rely on MSI Afterburner, you should install and run it: [Download](http://download.msi.com/uti_exe//vga/MSIAfterburnerSetup.zip)
5. If you plan on using [GrinGoldMiner](https://github.com/mozkomor/GrinGoldMiner): Install Microsoft [.NET Core 2.2 Runtime](https://dotnet.microsoft.com/download) - download and install "Run Apps .NET Core Runtime", click the button "** Download .NET Core Runtime (see here: https://github.com/RainbowMiner/RainbowMiner/issues/441#issuecomment-465932125) **"

Finally: check, if Powershell 6 is in your PATH, because RainbowMiner will not run correctly, if the path to powershell is missing. Sometimes "C:\Program Files\PowerShell\6" has to be added manually to the PATH environement variable after installing Powershell 6. Here is a nice tutorial, how to add to PATH environment variable https://www.howtogeek.com/118594/how-to-edit-your-system-path-for-easy-command-line-access/amp/

A note on Windows Nvidia drivers. Recommended lite-packed versions are available for direct download:
[Windows 10 / Nvidia 431.68](http://us.download.nvidia.com/Windows/431.86/431.86-desktop-win10-64bit-international-nsd-whql.exe)
[Windows 10 / Nvidia 431.68 DCH](http://us.download.nvidia.com/Windows/431.86/431.86-desktop-win10-64bit-international-nsd-dch-whql.exe)
[Windows 7,8,8.1 / Nvidia 431.60](http://us.download.nvidia.com/Windows/431.60/431.60-desktop-win8-win7-64bit-international-whql.exe)

### Ubuntu 18.x Pre-requesites
(This section is WIP! Want to help? Make an [issue](https://github.com/RainbowMiner/RainbowMiner/issues) or a [PR](https://github.com/RainbowMiner/RainbowMiner/pulls)))

Debian-based distros will be more-or-less the same as these instructions.

Other distros will have settings in different places (hugepages) and the software install commands will be differen (dnf, yum, pacman, nix, pkg, etc.) It is assumed you are clever enough to sort out the differences on your own if you choose a different distribution. BUT! As noted above, feel free to edit this page and make a pull request.

###### Huge Pages
By default, linux sets memory-chunk size fairly small. This is to save RAM useage for low-requirement sofware (ie: most programs running in system-space, rather than user-space.) Scrypt^N (Verium) and the CryptoNight family (Monero, etc.) algorithms *need* a large memory-chunk allocation, and many benefit from it even if they don't need it. In linux, this is call 'hugepages'. For Ubuntu-based distributions, you can set this manually on each boot with `sudo sysctl -w vm.nr_hugepages=XXX` where XXX is a how many megabytes to assign per page-chunk.  This can be made persistent across reboots by editing the value in `/proc/sys/vm/nr_hugepages` and you need to be root do it (ie: `sudo emacs -wm /proc/sys/vm/nr_hugepages` (substitue 'emacs -wm' with your editor of choice - nano, vi, joe, etc.)

On my system (@ParalegicRacehorse), xmr-stak will not run with hugepages<1024. Setting it to 2048 did gain me anything more than 1024, but experience in the verium/vericoin community have shown hugepages as large as 4096 can be beneficial. YMMV. Tuning is left to the rig operator, but I recommend keeping it as low as you can get away with so your other programs can run lean.

#### Video Cards

##### Nvidia
Nvidia has kindly supplied a ppa for their official drivers.

```
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt -y install dkms build-essential
sudo apt update
sudo apt -y install nvidia-headless-430 nvidia-driver-430 nvidia-compute-utils-430 nvidia-cuda-toolkit

```
Reboot after the driver have been installed.

**Important: check which version of the Nvidia driver you need (i.e. which is compatible with your graphics card)** You can check on the Nvidia website which products are supported by each driver (the latest one is usually the best if you have a recent graphics card). Not doing so can cause black screen on reboot. Only the main version is needed (don't bother about the number after the point, so if latest driver is 430.24, just write 430).

###### Optional Overclocking for Nvidia:

```
sudo nvidia-xconfig -a --cool-bits=31 --allow-empty-initial-configuration
```
Reboot after setting cool bits.

##### AMD Drivers
Download and extract the latest driver for your cards from the [AMD support site](https://www.amd.com/en/support)

After the archive is downloaded, extract the contents to a temporary location from which you can install it. 

Run the following to install it "headless" (this is nessecary for Ubuntu Desktop installations and possibly some other configurations. [Read more here](https://amdgpu-install.readthedocs.io/en/latest/install-installing.html#installing-the-pro-variant)) and with ROCm support.

```
./amdgpu-pro-install -y --opencl=pal,legacy,rocm --headless

```
Reboot and you should be good to go! 

**Important:** Some algorithms, on some miner-software, will not hash with a kernel version greater than 4.2. You may have to downgrade your OS to Ubuntu 16.04 since more recent editions will not run kernel numbers lower than 4.8. This has everything to do with a mismatch between OpenCL versions provided by recent drivers and those supported by the mining software. Yes, that means you will be running older drivers. If you want the newer drivers, with newer versions of OpenCL to work, feel free to provide assistance to the affected mining softwares by fixing their code and sending pull-requests.

## INSTALLATION

#### 1. Download RainbowMiner and extract to a folder of you choice: [![current release](https://img.shields.io/github/release/RainbowMiner/RainbowMiner.svg)](https://github.com/RainbowMiner/RainbowMiner/releases)

**Important:** Add the RainbowMiner directory to the exceptions of your antivirus program. Otherwise, some miner will cause false virus alerts.

On Linux, you may use git for a shortcut:
```
sudo apt-get update
sudo apt-get install git
git clone https://github.com/rainbowminer/RainbowMiner
```

#### 2. Run the RainbowMiner installer

On Windows:
- open RainbowMiner folder with Explorer
- right-click "Install.bat" and choose "Run as administrator"

On Linux, cd into your RainbowMiner folder, change the attributes of install.sh, start.sh and others and run the Installer as root (sudo):
```
cd RainbowMiner
chmod +x *.sh
sudo ./install.sh
```

At the end of the install, you will be asked to start RainbowMiner.

**If the installer fails to install PowerShell, this is the way to install it manually:**

Find the matching version of [Powershell Core v6.2.2 for your system from here](https://github.com/PowerShell/PowerShell/releases) and download it to your machine.

On Windows, just run the Installer

On Linux: either use the GUI installer to install the package or do it manually, e.g. for Ubuntu:
```
# if not already done, download the package, change the ubuntu distro version number!
wget https://github.com/PowerShell/PowerShell/releases/download/v6.2.2/powershell_6.2.2-1.ubuntu.18.04_amd64.deb

# install powershell package
dpkg -i powershell_6.2.2-1.ubuntu.18.04_amd64.deb

# install powershell dependecies
apt install -f
```



#### 3. Start it (if not yet running)

##### On Windows:

- open RainbowMiner folder with Explorer
- right-click "Start.bat" and choose "Run as administrator"

##### On Linux:

```
./start.sh
```

Alternative: start as Linux `screen`:

```
./start-screen.sh
```

- press `Ctrl+A`, then `d` to detach from screen (imagine you want to disconnect your ssh session)
- enter `screen -r` to reconnect to screen


#### 4. Enter basic information

   - choose your rig's WorkerName [default=rainbowminer]
   - choose your RunMode:
     - **standalone** = all config locally and direct connect to pool APIs
     - **server** = act as server for many Clients, may also run as mining rig
     - **client** = opionally use server's config files, connect to server for pool API data
   - enter API port for webinterface at http://localhost:<APIport>
   - optionally protect access to the webinterface with username and password
   - for client-mode:
     - enter the server's name (or IP)
     - enter the server's API port
     - optionally enter username and password, if you have protected the access to the servers's webinterface


#### 5. Enter your credentials:

   - your btc-wallet address (one for general use, and one for NiceHash)
   - your MiningPoolHub credentials, if you plan to use this pool
   - your [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) credentials, if you plan to use this pool   
   - your region. Valid names are: US, Europe, Asia
   - your currencies. Valid currencies are: BTC, USD, EUR, GBP, ETH, ..
   - the pools, you want to mine as comma separated list. 
   - the algorithm, you want to mine as comma separated list.
   - the devices, you want to use for mining. Valid descriptors are: gpu, cpu, nvidia, amd (RainbowMiner will show you, which devices are available on your machine)
     or use your device names (without spaces, without leading geforce): gtx1070, gtx1080ti ..


#### 6. Let the downloads and benchmarking finish

   - **be patient!** This might take a while
   - Anyway: it will already mine to your wallets

### Done!

<details><summary>Valid poolnames</summary>2miners, 2minersolo, ahashpool, ahashpoolcoins, blazepool, baikalminer, baikalminersolo, blockcruncher, blockmasters, blockmasterscoins, bsod, bsodparty, bsodsolo, cryptoknight, ethashpool, ethermine, f2pool, fairpool, flypool, goscx, goscxparty, goscxsolo, grinmint, hashpool, hashvault, herominers, icemining, luckypool, minermore, minerrocks, miningpoolhub, miningpoolhubcoins, mininigrigrentals, mintpond, nanopool, nicehash, nlpool, phiphipool, ravenminer, sparkpool, suprnova, uupool, yiimp, zergpool, zergpoolcoins, zergpoolparty, zergpoolsolo, zergpoolcoinsparty, zergpoolcoinssolo, zpool, zpoolcoins</details>
<details><summary>Valid algorithms</summary> Balloon, Bitcore, Blakecoin, Blake2s, BlakeVanilla, C11, CryptoNightV8, CryptoNight-Swap, Cuckaroo29, Ethash, X11, Decred, Equihash, Equihash144, Equihash192, Equihash-BTG, Groestl, Hex, HMQ1725, HSR, JHA, Keccak, Lbry, Lyra2RE2, Lyra2z, MyriadGroestl, NeoScrypt, Pascal, Phi, Phi2, Polytimos, Quark, Qubit, Scrypt, SHA256, Sib, Skunk, Skein, Tensority, Timetravel, Tribus, Veltor, X11, X12, X11evo, X16R, X16S, X17, X18, X21s, X22i, Yescrypt and many more: https://rbminer.net/algorithms/</details>


## HOTKEYS

You can press the follwing keys, while RainbowMiner is waiting for the next run.

- E[**x**]it Miningscript = stop all running miner and exit RainbowMiner
- [**S**]kip switching prevention = immediately start the most profitable miner, without waiting for the switching prevention
- start [**D**]ownloader = start the downloader manually (only needed, if you manually updated a miner)
- [**C**]onfiguration = goto the configuration setup (after setup all miner will be restarted)
- [**V**]erbose off/on = switch the user interface from lite(=off) to full(=on)
- [**P**]ause = stop all running miner and wait until user presses P again
- [**U**]pdate = if a new release of RainbowMiner is available, this option will show up. Pressing this key will start the automatic update.


## RECOMMENDATIONS & HELPERS

- Set your Windows virtual memory size to a fixed size, to the sum of your GPU memories x 1.1, e.g. if you have 6x GTX1070 8GB installed, use at least 53000 (Computer Properties->Advanced System Settings->Performance->Advanced->Virtual Memory)
- Submit bugs and feature requests here: https://github.com/RainbowMiner/RainbowMiner/issues 
- if mining on GeForce GTX 1070/GTX 1070Ti/GTX 1080/GTX 1080Ti, it is recommended to set "Force P2-State" to "Off", so that the card will always operate in P0 state. [How to set P0 state for my GTX1070 and GTX1080](https://github.com/RainbowMiner/RainbowMiner/issues/36)
- Important: **NEVER EDIT THE "Start.bat" !** It will break the autoupate. If you want to add commands to the start, edit .\Config\autoexec.txt
- the root directory of RainbowMiner contains the following, additional batch files:

|Windows|Linux|Description|
|---|---|---|
|`Start.bat`|`./start.sh`|start RainbowMiner|
|-|`./start-screen.sh`|start as Linux `screen`, `Ctrl+A` then `d` to detach, `screen -r` to reconnect|
|-|`./start-nohup.sh`|start as background job, run `./stopp.sh` to stop rainbowminer, run `./rbmlog.sh` to follow the Rainbowminer logfile, run `./minerlog.sh` to follow the miner log files|
|`Setup.bat`|`./setup.sh`|start RainbowMiner configuration|
|`Install.bat`|`./install.sh`|install pre-requisites|
|`InitServer.bat`|`sudo ./initserver.sh`|make this rig a server|
|`InitClient.bat`|`sudo ./initclient.sh`|make this rig a client|
|`InitStandalone.bat`|`sudo ./initstandalone.sh`|make this rig a standalone machine|
|`GPUtest.bat`|`sudo ./gputest.sh`|create gputestresults.txt with tech details|
|`Updater.bat`|`./updater.sh`|manually update to newest release of RainbowMiner. Make sure, you stop RainbowMiner before running this helper|
|`ListDevices.bat`|-|list all available devices|
|`MinerLog.bat`|`./minerlog.sh`|follow the output of the miners|
|-|`./rbmlog.sh`|follow the RainbowMiner log (useful if RainbowMiner is running as background job)|
|`RemoveLogs.bat`|-|delete all log files to save some disk space|
|`RemovePresets.bat`|-|block presets from being written to miners.config.txt (see section MINERS)|
|`ResetBenchmark.bat`|-|reset all benchmarks|
|`ResetBenchmarkAMD.bat`|-|reset all AMD benchmarks|
|`ResetBenchmarkCPU.bat`|-|reset all CPU benchmarks|
|`ResetBenchmarkNVIDIA.bat`|-|reset all NVIDIA benchmarks|
|`ResetProfit.bat`|-|reset RainbowMiner's profit calculation|
|`TouchBenchmark.bat`|-|avoid benchmark of new miners, will set the timestamp of all miner stat files to now|
|`Stopp.bat`|`./stopp.sh`|halt RainbowMiner at once|
  	

## WEB-INTERFACE

For your convenience, you can monitor and setup RainbowMiner using your web browser. The web interface very prominently shows RainbowMiner's live profitability and the current BTC exchange rates. To start the web interface, simply open the URL [localhost:4000](http://localhost:4000) in a new browser tab.
- Dashboard: shows the live running miners & pool balances, click the Pause/Restart button to halt and restart RainbowMiner. It will take up to 20 seconds, until the miner script finalize the pause/restart procedure, so give it some time.
- Selected Devices: lists the preselected devices
- All Devices: lists all available devices in your rig
- Best Pools: lists the best possible pool for every algorithm
- All Pools: lists all pools available vs. all algorithm
- Miners: lists all miners vs. all algorithm
- Active Miners: lists the best possible miners for each algorithm
- Benchmarks: monitor and reset benchmarks of failed and updated miners, reset all benchmarks

## CLIENT/SERVER NETWORKING

Choose one PC to be the Server (it may be a dusty old notebook). No need to let it mine, just let RainbowMiner start in paused mode. Select all other Rigs to act as Clients. All pool API communication will then be managed by the server: no more being blocked by the pools due to excessive use of their API

There is a Network setup build-in the configuration (press [C], then enter [N]) to help with the setup.

If you want it quicker, just run one of the following init scripts for very convenient pre-setup:

|Windows|Linux|Description|
|---|---|---|
|`InitServer.bat`|`sudo ./initserver.sh`|make this rig a server|
|`InitClient.bat`|`sudo ./initclient.sh`|make this rig a client|
|`InitStandalone.bat`|`sudo ./initstandalone.sh`|make this rig a standalone machine|

Of course, you may also edit the `Config\config.txt` directly.

If you change the RunMode of a rig, RainbowMiner needs to be restarted.

### Setup as Server

- one PC takes the role as Server
- it will act as gateway to the pool APIs for all Clients 
- enable auth: choose an username and a password.
- the server will be running on the API port

These are the server-fields to fill in the config.txt (or use the initscripts or the build-in config)
```
  "RunMode": "server",
  "APIport": 4000,
  "APIauth": "1",
  "APIuser": "serverusername",
  "APIpassword": "serverpassword",
```

### Setup as Client
- all other Rigs shall be clients
- if you have enable auth at the server: set the username and password.
- the RainbowMiner running on the server will tell you the machinename, ip address and port
- use either the machinename or the ip address of the server as servername

These are the client-fields to fill in the config.txt (or use the initscripts or the build-in config)
```
  "RunMode": "client",
  "ServerName": "machinenameofserver",
  "ServerPort": 4000,
  "ServerUser": "serverusername",
  "ServerPassword": "serverpassword",
  "EnableServerConfig": "1",
  "ServerConfigName": "config,coins,pools",
  "EnableServerExcludeList": "0",
  "ExcludeServerConfigVars": "WorkerName,DeviceName,ExcludeDeviceName,Proxy,APIPort,APIUser,APIPassword,APIAuth,MSIApath,NVSMIpath,CPUMiningThreads,CPUMiningAffinity,GPUMiningAffinity,ServerName,Serve
rPort,ServerUser,ServerPassword,EnableServerConfig,ServerConfigName,ExcludeServerConfigVars,RunMode,StartPaused",
```

If "EnableServerConfig" is set to "1", the client will try to download the config files specified with "ServerConfigName" from the server. If you want to provide the indiviual rig with specific config files, put them into a subdirectory `.\Config\<workername>` (linux: `./Config/<workername>`) . Use lowercase letters for the subdirectoy `<workername>`.
Setting the field "EnableServerExcludeList" to "1" lets your client use the servers "ExcludeServerConfigVars" field, instead of the local one in config.txt
All variables defined in "ExcludeServerConfig" will not be overwritten by the server's values.

## POOLS

<details><summary>2Miners</summary> https://www.2miners.com/ no auto-exchange, a seperate wallet address is needed for each coin (ETH, XZC and more) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>2MinersSolo</summary> https://www.2miners.com/ no auto-exchange, a seperate wallet address is needed for each coin (ETH, XZC and more) you want to mine solo. Set in pools configuration or edit pools.config.txt</details>
<details><summary>AHashPool / AHashPoolCoins</summary>https://www.ahashpool.com/  auto-exchange and payout in BTC</details>
<details><summary>BaikalMiner</summary> https://www.baikalminer.com/ no auto-exchange, enter wallet address for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>BaikalMinerSolo</summary> https://www.baikalminer.com/ no auto-exchange, solo mining, only. Enter wallet address for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>BlazePool</summary> https://www.blazepool.com/ auto-exchange and payout in BTC</details>
<details><summary>BlockCruncher</summary> https://www.blockcruncher.com/ (pigeoncoin-pool, pays in PGN, set your PGN-address in pools configuration or edit pools.config.txt</details>
<details><summary>BlockMasters</summary> https://www.blockmasters.co/ auto-exchange and payout in BTC, mine most profitable algorithm. Pool chooses coin or merged mining benefits
</details>
<details><summary>BlockMastersCoins</summary> https://www.blockmasters.co/ auto-exchange and payout in BTC, mine most profitable coin. Either with auto-exchange to a currency of wish, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithm, expect a lot of switching.
</details>
<details><summary>Bsod</summary> https://bsod.pw/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>BsodParty</summary> https://bsod.pw/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine solo together with others. Set in pools configuration or edit pools.config.txt. Set "PartyPassword" in pools.config.txt for your group</details>
<details><summary>BsodSolo</summary> https://bsod.pw/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine solo. Set in pools configuration or edit pools.config.txt</details>
<details><summary>CryptoKnight</summary> https://cryptoknight.cc/ no auto-exchange, dedicated to cryptonight and swap mining, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>EthashPool</summary> https://ethashpool.com/ auto-exchange to ETH and BTC, registration is mandatory for autoexchange to work. Either set wallet address or username (autoexchange) in pools configuration or edit pools.config.txt</details>
<details><summary>Ethermine</summary> https://ethermine.org/ no auto-exchange, a seperate wallet address is needed for each coin (ETH, ETC) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>F2Pool</summary> https://www.f2pool.com/ no auto-exchange, either enter your f2pool username as wallet address, or a real wallet address for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>FairPool</summary> https://fairpool.xyz/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Ethermine</summary> https://flypool.org/ no auto-exchange, a seperate wallet address is needed for each coin (ZEC, YEC) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>GosCx</summary> https://gos.cx/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>GosCxParty</summary> https://gos.cx/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine solo together with others. Set in pools configuration or edit pools.config.txt. Set "PartyPassword" in pools.config.txt for your group</details>
<details><summary>GosCxSolo</summary> https://gos.cx/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine solo. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Grinmint</summary> https://grinmint.com/ GRIN/Cuckaroo29-pool, pays in GRIN, set your GRIN-eMail-address as wallet and enter your Grinmint password in pools configuration or edit pools.config.txt</details>
<details><summary>Hashpool</summary> https://hashpool.eu/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>HashVault</summary> https://hashvault.pro/ no auto-exchange, dedicated to cryptonight mining, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>HeroMiners</summary> https://herominers.com/ no auto-exchange, dedicated to cryptonight and swap mining, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Icemining</summary> https://icemining.ca/ no auto-exchange, very good BCD (BitcoinDiamond) performance, a seperate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>PocketWhale</summary> https://swap2.luckypool.io/ SWAP-pool for us region, pays in XWP, set your XWP-address in pools configuration or edit pools.config.txt. No price, so only suitable for FocusWallet mining.</details>
<details><summary>SparkPool</summary> https://sparkpool.com/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>MinerMore</summary> https://minermore.com/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>MinerRocks</summary> https://miner.rocks/ no auto-exchange, dedicated to cryptonight mining, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Minexmr</summary> https://minexmr.com/ if you are totally in Monero, then this pool might be the best choice: it's monero and no autoexchange, only. A monero XMR wallet address is needed. Set in pools configuration or edit pools.config.txt</details>
<details><summary>MiningPoolHub</summary> https://miningpoolhub.com/ auto-exchange and paymout in BTC, username required. Parameter uses the 17xxx ports therefore allows the pool to decide on which coin is mined of a specific algorithm
</details>
<details><summary>MiningPooHubCoins</summary> https://miningpoolhub.com/ auto-exchange and paymout in BTC, username required. Allows for RainbowMiner to calculate and determine what is mined from all of the available coins (20xxx ports).
</details>
<details><summary>MiningRigRentals</summary> [https://www.miningrigrentals.com/](https://www.miningrigrentals.com/?ref=2598069) rent your complete rig to interested users in exchange for BTC, ETC, LTC or DASH. See extra section for more details</details>
<details><summary>Mintpond</summary> https://mintpond.com/ if you are totally in Zcoin, then this pool might be the best choice. A seperate wallet address is needed for XZC. Set in pools configuration or edit pools.config.txt</details>
<details><summary>NanoPool</summary> https://nanopool.org/ no auto-exchange, a seperate wallet address is needed for each coin (ETH, ETC, ZEC, ETN, SIA, PASC), you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Nicehash</summary> https://www.nicehash.com/ auto-exchange and payout in BTC, use of Nicehash wallet is recommended, see note below</details>
<details><summary>NLpool</summary> https://www.nlpool.nl/ auto-exchange and payout in BTC, LTC or any coin, that is listed at the pool</details>
<details><summary>PhiPhiPool</summary> https://www.phi-phi-pool.com auto-exchangeand payout in BTC or any coin, that is listed at the pool</details>
<details><summary>PocketWhale</summary> https://swap.pocketwhale.info/ SWAP-pool for us region, pays in XWP, set your XWP-address in pools configuration or edit pools.config.txt. No price, so only suitable for FocusWallet mining.</details>
<details><summary>PoolSexy</summary> https://pool.sexy/ no auto-exchange, mostly DaggerHashimoto (ethash) mined coins, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Ravenminer</summary> https://www.ravenminer.com/ ravencoin-pool for us region, pays in RVN, set your RVN-address in pools configuration or edit pools.config.txt</details>
<details><summary>RavenminerEu</summary> https://eu.ravenminer.com/ ravencoin-pool for eu region, pays in RVN, set your RVN-address in pools configuration or edit pools.config.txt</details>
<details><summary>SuprNova</summary> https://suprnova.cc/ no auto-exchange, enter your SuprNova username as wallet address for each coin, you want to mine. Make sure, that your workername on SuprNova matches your rig's name and the SuprNova worker password is "x". Set in pools configuration or edit pools.config.txt</details>
<details><summary>UUPool</summary> https://www.uupool.com/ no auto-exchange, a separate wallet is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>YiiMP</summary> https://yiimp.eu/ no auto-exchange, a seperate wallet address is needed for each coin, you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>ZergPool</summary> https://www.zergpool.com/ auto-exchange and payout in BTC, LTC or any coin, that is listed at the pool. Pool will automatically select the most profitable coin. Switching will be by algorithm.</details>
<details><summary>ZergPoolParty</summary> https://www.zergpool.com/ auto-exchange and payout in BTC, LTC or any coin, that is listed at the pool. Pool will automatically select the most profitable coin. Switching will be by algorithm. Set "PartyPassword" in pools.config.txt for your group</details>
<details><summary>ZergPoolSolo</summary> https://www.zergpool.com/ auto-exchange and payout in BTC, LTC or any coin, that is listed at the pool. Pool will automatically select the most profitable coin. Switching will be by algorithm. Solo mining!</details>
<details><summary>ZergPoolCoins</summary> https://www.zergpool.com/ auto-exchange and payout in BTC, LTC or any other coin. Mine most profitable coin, either with auto-exchange to a currency of wish, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithm, expect a lot of switching. Switching will be by coin.</details>
<details><summary>ZergPoolCoinsParty</summary> https://www.zergpool.com/ auto-exchange and payout in BTC, LTC or any other coin. Mine most profitable coin, either with auto-exchange to a currency of wish, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithm, expect a lot of switching. Switching will be by coin. Set "PartyPassword" in pools.config.txt for your group</details>
<details><summary>ZergPoolCoinsSolo</summary> https://www.zergpool.com/ auto-exchange and payout in BTC, LTC or any other coin. Mine most profitable coin, either with auto-exchange to a currency of wish, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithm, expect a lot of switching. Switching will be by coin. Solo mining!</details>
<details><summary>Zpool</summary> https://www.zpool.ca/ auto-exchange and payout in BTC</details>
<br />	
  
<details><summary>Notes for NiceHash</summary>

If you plan to mine through Nicehash, I strongly recommend, that you register an account with them (https://www.nicehash.com/register). In this case, Nicehash will provide you with an extra NiceHash wallet/bitcoin address (RainbowMiner will ask for this address during the setup or configuration process).
This lowers the minimum payout sum from 0.1BTC (for external wallet) to a very low 0.001BTC (for Nicehash wallet). An additional benefit for Coinbase users: sending BTC from the Nicehash wallet to your Coinbase account is free of charge.</details>
<details><summary>Notes for the pools BlockCruncher, BlockMasters, Bsod, CryptoKnight, GosCx, HashPool, Icemining, MinerRocks, NLpool, PhiPhiPool, PocketWhale, Ravenminer, YiiMP and Zpool</summary>
  
The miner can be setup to mine any coin or currency, that is listed at the respective pool. The pool will then payout to the given non-BTC wallet address. Take into account, that non-BTC payouts depend heavily on that coin being mined. If the pool has not or is not mining that currency, the payouts will be delayed until the pool has mined the blocks. Read the pools websites, about the mineability and reliability of a currency. It's recommended to use BTC as any other coin could be removed at anytime and payouts will not occur. The pools Bsod, CryptoKnight, GosCx, Icemining, MinerRocks, PhiPhiPool, PocketWhale, Ravenminer and Yiimp do not have auto-exchange to BTC. Please be careful, what you choose to mine.
</details>
<details><summary>Notes for Solo- and Party-mining</summary>
  
Bsod.pw, Gos.cx and ZergPool allow solo mining and party mining. This is achieved by adding parameters "m=solo" or "m=party.yourpassword" to the password of the pool. There are two ways to achieve this with RainbowMiner:
- either supply `"BTC-Params": "m=solo",` / `"BTC-Params": "m=party.password",` in pools.config.txt and use the standard pools modules "Bsod", "GosCx", "Zergpool", "ZergpoolCoins"
- or use the special pool modules "BsodSolo", "BsodParty", "GosCxSolo", "GosCxParty", "ZergpoolSolo", "ZergpoolParty", "ZergpoolCoinsSolo", "ZergpoolCoinsParty" - in case of party mining, these pool modules come with an extra parameter "PartyPassword" in pools.config.txt
</details>


## MINERS

- The RainbowMiner contains a list of well approved miners in the directory "Miners"
- The miner Excavator mines on NiceHash pool, only
- Miners Excavator & Excavator1.4.4 run in their own miner window, even if you select to hide miner windows.
- Each miner's algorithm can be fine tuned for each device in your mining rig

### Special finetuning

The following miners can be fine tuned, using config files. Most of the config files are being generated upon the first start of the miner. All config files will be written once, only, and kept through miner updates. To let Rainbowminer recreate those files, they will have to be deleted.

|Minername|Type|Path|Configfile(s)|Documentation Link|
|---|---|---|---|---|
|FireIce/XMR-Stak|AMD|Bin\Cryptonight-FireIce|amd.txt|https://github.com/fireice-uk/xmr-stak/blob/master/doc/tuning.md|
|FireIce/XMR-Stak|CPU|Bin\Cryptonight-FireIce|cpu.txt|https://github.com/fireice-uk/xmr-stak/blob/master/doc/tuning.md|
|FireIce/XMR-Stak|NVIDIA|Bin\Cryptonight-FireIce|nvidia.txt|https://github.com/fireice-uk/xmr-stak/blob/master/doc/tuning.md|
|JceminerCpu|CPU|Bin\CPU-Jceminer|config_[algorithm]-CPU.txt|https://bitcointalk.org/index.php?topic=3281187.0|
|SrbMiner|AMD|Bin\Cryptonight-Srbminer|config_[algorithm]-[devicemodel].txt|https://bitcointalk.org/index.php?topic=3167363.0|


## ALGORITHMS

RainbowMiner uses a build-in hash table to convert different algorithmnames to unique and beautified, internal representations. Because of this, you do not have to care too much about how to write an algorithm, when directly editing the "Config\config.txt" or using command line parameters. E.g. cryptonight-v7, cryptonight/1, cryptonightv7 would all be converted to CryptonightV7.

## Special notes for Equihash

The different Equihash algorithms are distinguished using the following Parameters: (n, k). For example, the classic Equihash first used by Zcash used n = 200 and k = 9, so it became Equihash (200, 9). For BEAM and ZEL a new variant EquihashR has been introduced. These add an extra paramter (r).

The n, k and r values create enormous differences in the minimum memory requirement, and create enormous differences in how the actual mining software is coded in order to do the mining.

RainbowMiner uses the following nameing convention:
- Equihash16x5 = Equihash (96, 5)
- Equihash20x9 = Equihash (200, 9)
- Equihash21x9 = Equihash (210, 9)
- Equihash24x5 = Equihash (144,5), e.g. BTG
- Equihash24x7 = Equihash (192,7), e.g. ZEROcoin
- EquihashR25x4 = Equihash (125,4), e.g. ZelHash
- EquihashR25x5 = Equihash (150,5), e.g. GRIMM
- EquihashR25x5x3 = Equihash (150,5,3), e.g. BEAM

The new numbers (16x5, 20x9, ..) describe the number of bits matched in each round for the algorithm, and provide a relative measure of the “hardness” of the algorithm (the numbers can be calculated, using n and k: n/(k+1) )
For EquihashR the parameter (r) will be added to the algorithm name. For r=0, nothing will be added. 

RainbowMiner's build-in hash table makes it possible for you, to use many different algorithmnames. E.g. equihash-144_5, equihash1445, equihash-btg, equihash144btg will all be represented by Equihash24x5. BeamHash will be represented by EquihashR25x5x3


## OVERCLOCKING OVERVIEW

There are two ways to adjust overclocking values in RainbowMiner:
- **Option1: MSI Afterburner profiles**
  - recommended for **mining rigs with max. 6 identical GPUs**
  - to enable, set "**MSIAprofile**" to the number of your default AB profile ([C]onfiguration->[C]ommon)
  - MSI Afterburner profiles are addressed by number 1-5
- **Option2: custom overclocking profiles**
  - recommended for mining rigs with **more than 6 or mixed GPUs**
  - to enable, set "**EnableOCProfiles**" to "**1**" ([C]onfiguration->[C]ommon)
  - custom profiles have freely defined names (it differs from option 1!)
  - **important:** set a default profile for each GPU group ([C]onfiguration->[D]evices). Use the name of the profiles (look into ocprofiles.config.txt, if in doubt)
  - independant of MSI Afterburner

If you do not want to use the overclocking features in RainbowMiner: set both, "**EnableOCProfiles**" and "**MSIAprofile**", to "**0**" ([C]onfiguration->[C]ommon)

**Frequently asked questions**

> Just wondering what would happen if in miners.config I set the ocprofile to a clock and then set it different within AF under the same profile number. Would one trump the other? If so which one would override? 

Only one of the two OC options can be enabled at a time:

|config.txt|MSIAprofile|EnableOCprofiles|
|---|:---:|:---:|
|Use ocprofiles.config.txt|whatever|1|
|Use Afterburner profiles|1-5|0|
|No OC switching at all|0|0|

The differences:

|   |MSIAprofiles|ocprofiles| 
|---|:---:|:---:|
|Can handle parallel miners on different GPUs|no|yes|
|Depends on Afterburner|yes|no|
|Depends on nvidiaInspector|no|yes|
|Speed with more than 6 GPU|slow|fast|
|Works for Nvidia|yes|yes|
|Works for AMD|yes|no|
|max. number of profiles|5|unlimited|
|Individual profile names|no|yes|

> I set the ocprofile to a clock and then set it different within AF under the same profile number

- MSI Afterburner profiles are fixed to a maximum of five and is being selected by their number 1 to 5 in parameter "MSIprofile" in miners.config.txt"
- ocprofiles are unlimited in ammount, you decide what their names are. RainbowMiner comes with an example ocprofiles.config.txt, where the profiles are named "Profile1", "Profile", .. "Profile9". The profile is being selected by the full name in parameter "OCprofile" in miners.config.txt (for example "Profile2")


## OC OPTION1: MSI AFTERBURNER PROFILES

Overclocking option, recommended for **unique GPU mining rigs with maximum 6 GPU**

### Introduction

MSI Afterburner allows to configure up to five profiles. Each of which defines the exact overclocking parameters for any number of GPU. RainbowMiner will never change these values, but it can be defined for miners/algorithms/devices, that another profile than the default should be used during minining (miners.config.txt, fields "MSIAprofile"). RainbowMiner comes with some miner/algorithm presets, already.

### Enable Profile Switching

By default, the profile switching is disabled. To enable MSI Afterburner profile switching:
- check or set the path to MSIA (config.txt, field "MSIApath")
- set the profile number, you want to be used as default (config.txt, field "MSIAprofile") 

### Explanation of operation

RainbowMiner's default setup has already preset some Profile fields for the following algorithms (miners.config.txt, fields "MSIAprofile"):
- ClaymoreEthash-Keccak, NeoScrypt => Profile 3
- Lyra2Re2, Lyra2z, X16r, X16s => Profile 4
- ClaymoreEthash-Blake2s, ClaymoreEthash-Pascal => Profile 5

Remember: __no overclocking values will be changed by RainbowMiner!__ It will switch your preset profiles, only.

I recommend you set the following profile setup in MSI Afterburner, so that you can use the default setup of RainbowMiner. The overclocking values in brackets (core clock/memory clock) are those I use for my GTX 1070 and are only for illustration.

- Profile 1: no oc (e.g. +0/+0)
- Profile 2: max. core / max. memory oc (e.g. +100/+400), good for most miners
- Profile 3: max. core / half memory oc (e.g. +100/+200), recm. for claymore ethash-keccak, neoscrypt
- Profile 4: max. core / low memory oc (e.g. +100/-500), recm. for lyra2re2, lyra2z, x16r, x16s
- Profile 5: max. core / reduced memory oc (e.g. +100/+350), recm. for claymore ethash-blake2s, claymore ethash-pascal

Be careful when playing with OC, since this can damage your devices. RainbowMiner will not be responsible, if you kill your devices.


## OC OPTION2: CUSTOM OVERCLOCKING PROFILES

Recommended for mining rigs with **more than 6 GPU** or **different GPU**

### Introduction

Each miner/device/algorithm combination can have it's own overclocking values set by RainbowMiner. To enable: set "**EnableOCProfiles**" to "**1**" in your config.txt or use the [C]onfiguration->[C]ommon.

**!! It is important, that you coose a default profile for each GPU device in your devices.config.txt !!**

You can edit the file directly: put the name of your custom default profile into field "**DefaultOCprofile**"
Alternatively, the devices can be changed using [C]onfiguration->[D]evices

### 1. setup overclocking profiles

Use [C]onfiguration->[O]C-Profiles to edit, create and delete overclocking profiles. Values for PowerLimit (%), ThermalLimit (°C), MemoryClockBoost (MHz), CoreClockBoost (MHz) and LockVoltagePoint (µV) (see hint below) can be defined. You may name the profiles like you want. Hint: Use the complete profile's names, when editing the config files directly. Of course you may also edit the ocprofiles.config.txt file directly.

Hint: LockVoltagePoint can only be set, if EnableOCvoltage is set to 1 in your config.txt (or use [C]onfiguration->[C]ommon to change)

### 2. set one default profile for each GPU group ###

With the help of [C]onfiguration->[D]evices it is very easy to choose a default profile for each GPU group used. The values can be edited directly in file devices.config.txt, too. Put the names of the default profiles into the property "DefaultOCprofile".

### 3. assign profiles to miner-device-algorithms

The assignment is done, using either [C]onfiguration->[M]iners or directly edited into the miners.config.txt file. Find your miner, the device it will use, plus the algorithm and put the profile's name into the field "**OCprofile**" 

## COPY CURRENT CONFIGURATION TO NEW RIGS

RainbowMiner comes with an easy setup configuration.

### 1. get a setup.json 

Open http://localhost:4000 on your current rig and click "Get setup.json" (or directly enter http://localhost:4000/setup.json into your internet browser) and you will get a setup.json file, containing your current rig's configuration files.

### 2. install RainbowMiner

Extract a current RainbowMiner zip onto your new mining rig and copy the setup.json into the RainbowMiner folder. Run install.bat/install.sh to get missing system libraries, then run Start.bat/start.sh.

Now RainbowMiner will ask, if it should import the data from the setup.json. That's it!

### Hint: the setup.json contains an autostart section.

Change this to control the setup behavior.

```
  "Autostart": {
    "Enable": "0",
    "ConfigName": "All",
    "DeviceName": "GPU",
    "WorkerName": ""
  },
```

**Settings of the `"Autostart"` section explained:**

- `"Enable"` setting this to "1" will force RainbowMiner to skip the import questionaire during start. It will import all data and begin mining at once.
- `"ConfigName"` define which of the config file's should be imported. A well approved combination would be `"Config,Coins,Pools"`. `"All"` will import all possible modules.
- `"DeviceName"` define which devices RainbowMiner should use. Possible values are CPU, GPU, NVIDIA, AMD (and even GPU#00, GPU#01, ..). Leave empty to start without devices.
- `"WorkerName"` define the workername of the new rig. If left empty, the rig's machinename will be used as workername, automatically.


## ADVANCED CONFIGURATION

RainbowMiner has a configuration function built-in: to change any parameter of the script, press key "**C**", while the script is running.
**There is no more need to edit the following config files directly.**

Config files are found in directory "Config\"
- config.txt = general settings, wallet, etc.
- pools.config.txt = pool setup, set a different wallet, workername for each pool and coin
- miners.config.txt = individually add arguments to miner (selected by name and device names and algorithm)
- devices.config.txt = control algorithms and miners to be used by specific devices
- algorithms.config.txt = globally adjust algorithms, like min. hashrate, timetofind etc.
- coins.config.txt = globally adjust specific coins, like min. hashrate, timetofind etc.
- ocprofiles.confit.txt = setup custom overclocking profiles
- autoexec.config.txt = add executables/commands to be executed when RainbowMiner starts

**Note: if you have not started the Start.bat yet, there will be no config files! Start it first!**
**Config files are in JSON format. Look here for to get an idea, how they work: https://www.tutorialspoint.com/json/index.htm**
**Be careful, when editing these files. Every comma counts!**


### Config\config.txt

The config file will contain variables to reflect default values. You can safely replace those variables with values.

An example:

    "StartPaused": "$StartPaused",
    "Interval": "$Interval",

You may replace $StartPaused and $Interval with your MiningPoolHub USER ID/API KEY

    "StartPaused": "0",
    "Interval": "90",

#### Basic setup ####

- **Wallet** = your general BTC wallet address
- **WorkerName** = your desired worker name
- **Currency** = currencies, you want to be shown [default=BTC,USD,EUR]
- **Region** = your region, [default=US]
- **UIstyle** = set to "full" for complete listing, set to "lite" for reduced listing [default=full]
- **APIport** = enter a free web-interface port localhost:<port> [default=4000]
- **EnableAutoUpdate** = set to 1 if you want RainbowMiner to be updated automatically
- **EnableAutoAlgorithmAdd** = set to 1 if Rainbowminer should add all newly added algorithms to your config.txt, during (automatic) update
- **EnableMinerStatus** = set to 1 to enable central monitoring
- **MinerStatusURL** = url to central monitoring server [default=https://rbminer.net]
- **MinerStatusKey** = your unique miner status key (get one at https://rbminer.net, you can reuse MPM keys)
- **MinerStatusEmail** = if your miningrig goes offline at https://rbminer.net/monitoring, a warning will be sent to this email-address. Leave empty, if you do not want notifications.
- **PushOverUserKey** = if your miningrig goes offline at https://rbminer.net/monitoring, a notification will be sent via https://pushover.net, using your pushover user key. Leave empty, if you do not want this.


#### Select devices ####

- **DeviceName** = list of device descriptors, with which you want to mine [default=gpu]
  - click ListDevices.bat to find out which devices are availabe
  - out of this table, models, vendors and names can be used to select
  - for mining on all GPUs, use "gpu"
  - for mining on all Nvidia GPUs use "nvidia"
  - for mining on all AMD GPUs use "amd"
  - for mining on CPU, use "cpu"
  - examples:
    - "nvidia"
    - "gtx1070,gtx1080,cpu"
    - "cpu,gpu"
    - "gpu#01,gpu#03"
- **ExcludeDeviceName** = list of device descriptors to exclude from mining (see DeviceName for explanation)
- **CPUMiningThreads** = enter the number of softwarethreads being used by CPU miners. Adds "-t [threads]" to commandline of cpuminer forks
- **CPUMiningAffinity** = enter a hex number to define CPU mining core affinity (e.g. 0xAAAA). Adds "--cpu-affinity [affinity]" to commandline of cpuminer forks
- **GPUMiningAffinity** = enter a hex number to define GPU miner's CPU core affinity for validating results (e.g. 0xAAAA). Especially useful, when mining CPU and GPU in parallel.

If you defined CPUMiningThreads or CPUMiningAffinity, you may override the values for single miner, by adding your own "-t" and "--cpu-affinity" to the field Params in miners.config.txt. 
ClaymoreCPU, FireIce and JceminerCpu are not affected by these settings. They can be finetuned by editing config files (see section MINERS)

The affinity values define bitmasks, bit 0 = Core 0, bit 1 = Core 1, etc. The bitmasks are build from right to left.

Some examples:

    0 or 1 - 1 CPU/Core on or off.
    10 - Core/CPU 2 On, 1 Off.
    100 - Core/CPU 3 On, 1 and 2 off.
    101010 - Odd cores on, even off, 6 core.
    10101010 - Odd cores on, even off, 8 core.
    10101010101 - Even cores on, Odds off, 12 core.
    
To convert those binary 0/1 values into a hex number, you may use this [Bin/Hex Converter](https://www.rapidtables.com/convert/number/binary-to-hex.html).

#### Select algorithms ####

- **Algorithm** = list of algorithms, you want to mine [default=bitcore,blake2s,c11,cryptonightheavy,cryptonightv7,ethash,equihash,hmq1725,hsr,keccak,keccakc,lyra2re2,lyra2z,neoscrypt,pascal,phi,skein,skunk,timetravel,tribus,x16r,x16s,x17,vit,xevan,yescrypt,yescryptr16]
- **ExcludeAlgorithm** = list of algorithms, you want to exclude from mining
- **ExcludeCoin** = list of coins, you want to exclude from mining
- **ExcludeFromWatchdog** = list of algorithms or miner, you want to exclude from the watchdog
- **DisableUnprofitableAlgolist** = set to "1" if you do not want to use the list of unprofitable algorithms, provided live by RainbowMiner.

#### Select miners ####

- **MinerName** = list of miner, you want to use for mining (see directory Miners, without .ps1, e.g. CcminerAlexis78.ps1 -> CcminerAlexis78)
- **ExcludeMinerName** = list of miner names, you want to exclude from mining
- **ExcludeMinersWithFee** = exclude all miners, that have a developer fee build-in [default=0]
- **DisableDualMining** = set to 1, if you want to disable all dual mining [default=0]
- **IgnoreFees** = set to 1, if you do not want RainbowMiner to account the pool- and miner fees [default=0]
- **ShowMinerWindow** = show (1) or do not show (0) miner windows. Note: excavator will always run in an extra window [default=0]
- **FastestMinerOnly** = set to 1 to reduce list by only showing the fastest miner [default=1]
- **DisableExtendInterval** = during benchmark, some miners will run longer to find an accurate hashrate. Set to 1 to disable the extended times (this is not recommended, as it may result in inaccurate hashrates or failed some miners) [default=0]

#### Select pools ####

- **PoolName** = list of pool names, you want to use for mining [default=nicehash,blazepool,miningpoolhubmini]
- **ExcludePoolName** = list of pool names, you want to exclude from mining
- **ShowPoolBalances** = set to 1 to let RainbowMiner show your current pool balances [default=1]
- **ShowPoolBalancesDetails** = set to 0 if coin balances at a pool should be added up to BTC [default=1]
- **ShowPoolBalancesExcludedPools** = set to 1 to let RainbowMiner try to fetch balances from not used pools in addition to the currently activated pools [default=0]
- **PoolDataWindow** = set global default for all pool data windows [default=estimate_current]
- **PoolStatAverage** = set global default for all pool moving average price trend

#### Select mining mode ####

- **MiningMode** = possible values are "legacy", "device" and "combo", see explanation below
  - "legacy": one miner will handle all devices of one vendor together. Only NVIDIA, AMD, CPU are possible to select.
  - "device" (default): each device group (e.g. GTX1070, RX570, CPU..) will get the most profitable miner to work on the different algorithm. If you have three different device groups, there will be three miners launched.
  - "combo": in addition to "device" mode, all possible combinations of device groups are taken into account. E.g. if all device types are considered most profitable for one specific miner, only one instance of the miner will be launched. Device types will only be combined for specific algorithm, if they have exactly equal params configured in miners.config.txt (the strings have to match). The combination of devices will be monitored seperatly: if the combo is less efficient than single miners, it will be deactivated automatically.
- **EnableResetVega** = set to 1 to always reset Vega Gpus before mining

#### Setup network operations

- **RunMode** = possible values are "standalone", "server", "client"
  - "standalone": this mining rig will handle everything on it's own
  - "server": this mining rig will act as server in a multiple rig setup
  - "client": this mining rig will not create network traffic but pull the data from the server rig
  
For Client (Runmode=client) setup:
- **ServerName** = enter the server's machinename or ip
- **ServerPort** = enter the server's ports
- **ServerUser** = enter the server's username (if auth)
- **ServerPassword** = enter the server's password
- **EnableServerConfig** = set to "1" to use the server's config files on this rig
- **ServerConfigName** = list of config files to be downloaded if "EnableServerConfig" is set to "1". Possible values are "algorithms","coins","config","miners","ocprofiles","pools"
- **ExcludeServerConfigVars** = list of parameter names in config.txt or pools.config.txt, that should -not- be overwritten with server values (best is to leave it as is).
  For pools.config.txt:
  - `pools:<poolname>` = protect all values of pool "poolname"
  - `pools:<poolname>:<variablename>` = protect "variablename" in pool "poolname"
- **EnableServerExcludeList** = set to "1" to always use the server's "ExcludeServerConfigVars", instead of the local one in config.txt

For Server (Runmode=server) setup:
- **APIport** = enter a free web-interface port localhost:<port> [default=4000]
- **APIauth** = set to "1" for username/password auth on localhost [default=0]
- **APIuser** = enter an username for localhost accessability
- **APIpassword** = enter a password for localhost accessability



#### Set electricity cost handling ####

- **PowerPrice** = price of 1kW/h (kilowatt per hour) that your electricity supplier charges [default=0]
- **PowerOffset** = power offset to allow consideration for overhead power [default=0]
- **PowerPriceCurrency** = currency of your PowerPrice [default=USD]
- **UsePowerPrice** = set to (1), if electricity cost should be substracted from profits [default=0]
- **CheckProfitability** = if no more miners are profitable and this is set to (1), RainbowMiner will idle, until profitability returns. UsePowerPrice needs to be (1) and a PowerPrice greater than zero must be set for this function to work. [default=0]
- **EnableHeatMyFlat** =  set to a value 1..10 to prefer miners, that run hotter (0=disable, 5=good point to start). A "PowerPrice" must be set for this function to work. [default=0]


#### Technical/Other ####
- **Interval** = timing interval in seconds of RainbowMiner [default=60]
- **BenchmarkInterval** = timing interval in seconds, used for benchmarks [default=60]
- **MinimumMiningIntervals** = minimum number of intervals a miner will run, before switching will be allowed [default=1]
- **SSL** = set to 1, if only ssl connections wanted
- **Proxy** = set your proxy address here, if you are using one
- **Delay** = extra delay in secondes, between switching to avoid blue screen [default=0]
- **Watchdog** = use (1) or do not use (0) watchdog [default=1]
- **UseTimeSync** = set to 1, if RainbowMiner should adjust the windows clock by rtp [default=1]
- **SwitchingPrevention** = finetune the switching prevention algorithm. Set to zero to disable [default=2]
- **MaxRejectedShareRatio** = set max. allowed ratio "bad shares/found shares" until a miner gets disabled [default=0.3]
- **EnableFastSwitching** = set to 1 to remove switching prevention completly. Expect a lot of switching [default=0]
- **HashrateWeight** = adjust weight of pool hashrates on the profit comparison in % (0..100, 0=disable) [default=20]
- **HashrateWeightStrength** = adjust the strength of the weight (integer, 0=no weight, 100=linear, 200=square) [default=50]
- **PoolAccuracyWeight** = adjust weight of pool accuracy on the profit comparison in % (0..100, 0=disable) [default=15]
- **RebootOnGPUFailure** = (currently disabled)
- **EnableOCProfiles** = set to 1, if you plan to use custom overclocking profiles [default=0]
- **EnableOCVoltage** = set to 1, if you plan to set voltage for overclocking [default=0]
- **MSIApath** = absolute windows path to MSI Afterburner executable [default=c:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe]
- **MSIAprofile** = default MSI Afterburner profile (1-5), set to 0 to disable [default=2]
- **NVSMIpath** = absolute windows path to Nvidia smi tools [default=c:\Program Files\NVIDIA Corporation\NVSMI]
- **MiningPriorityCPU** = process priority for CPU miners (-2..2) [default=-2]
- **MiningPriorityGPU** = process priority for GPU miners (-2..2) [default=-1]
- **AutoexecPriority** = process priority for commands started via autoexec.txt (-2..2) [default=0]
- **EthPillEnable** = set to "revA" or "revB" (read [Wiki](https://github.com/OhGodACompany/OhGodAnETHlargementPill/wiki) for more information on revA/revB), or "disable" to stop using the EthPill for Ethereum mining [default=disable]
- **RemoteAPI** = set to 1 to enable accessability of API within your network [default=0]
- **Donate** = set the minutes, you want RainbowMiner to work for the developer (min. is 10 minutes, equals to 0.7%) [default=24]
- **EnableAutoMinerPorts** = set to 1, if miners get into conflict with the ports in use
- **DisableAPI** = set to 1, if no localhost API is needed
- **DisableAsyncLoader** = set to 1, if all net access should happen synchronous (used for debugging)
- **DisableMSIAmonitor** = set to 1, to fully disable MSI Afterburner monitoring (if more than six AMD GPU are used for mining)
- **Quickstart** = set to 1 to read all pool data from cache during startup (speeds up first start, but balance data may be out of date)
- **StartPaused** = set to 1 to start RainbowMiner in pause mode (no mining, you will have to press "P" to enable mining)


**Notes for HashrateWeight**

The comparison prices of the pools will be scaled with the following formula:

    compare price = price x (1-(HashrateWeight/100)x(1-(rel. hashrate)^(HashrateWeightStrength/100))


### Config\pools.config.txt

Each pool has it's own section, in the pools.config.txt

#### Change payout currency of a pool / add more wallets (e.g. Ravenminer uses RVN)

The default pool config look like this:

    "Zpool": {
        "BTC": "$Wallet",
        "Worker": "$WorkerName",
        "Penalty": 0
    }

The line "BTC": "$Wallet" defines the payout wallet address. $Wallet uses the value in your config.txt, $<CURRENCY> uses the value, defined for the corresponding currency in coins.config.txt
If you want to change it to LTC, for example, you have to change this line like this:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 0
    }

Or like this, if you setup a global wallet address in coins.config.txt

    "Zpool": {
        "LTC": "$LTC",
        "Worker": "$WorkerName",
        "Penalty": 0
    }

For non-autoexchange pools, you may define multiple wallets. The wallets define, which coins may be mined at a pool. In the following example, Rainbowminer will mine RVN and SUQA on Icemining, hereby using the default RVN wallet in the coins.config.txt.

    "Icemining": {
        "RVN": "$RVN",
        "SUQA": "<YOUR_SUQA_ADDRESS>"
        "Worker": "$WorkerName",
        "Penalty": 0
    }
    
Alternatively you may instruct RainbowMiner to automatically use every currency defined in coins.config.txt (which is enabled by adding a wallet address and setting parameter "EnableAutoPool" to "1") for a certain pool. To do so, set paremeter "EnableAutoCoin" to "1".
Example:

    "Icemining": {
        "Worker": "$WorkerName",
        "Penalty": 0,
        "EnableAutoCoin": "1"
    }

#### Add additional password parameters for YiiMP based pools

Many of our pools are based on the open-source YiiMP pool (e.g. AHashpool,BlazePool,Blockmaster,ZergPool,ZPool etc.). Some of these pools accept additional parameters. A prominent example is the setting of a custom payout limit at ZergPool (pl=x.xx). To add a password parameter, add one line to pools.config.txt in the form `"CURRENCY-Params": "parameters",`. In fact, all parameters will be added to the preset password contents, using a comma.

Example:

    "ZergPool": {
        "LTC": "<YOUR_LTC_ADDRESS>",
        "LTC-Params": "pl=1.5",
        "Worker": "$WorkerName",
        "Penalty": 0
    }

In this example, if mining Zergpool, it will autoexchange everything into LTC. The parameter string "pl=1.5" will be added to the password, that is passed to the pool. In the case of ZergPool it will define a payout limit of 1.5 LTC. Of course any parameters can be added here, depending on the pool's options.

#### Change a pool's penalty
    
If you feel like a pool tends to exagerate it's results, you can set a penalty in % through the field "Penalty":

    "Ravenminer": {
        "RVN": "<YOUR_RAVENCOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 5
    }

This would reduce the hashrate-results from the pool Ravenminer by 5%


#### Change a pool's time frame (data window)

To override the default data window "average2e" of the YiiMP based pools (AHashPool,BlazePool,BlockMasters,Hashpool,ZergPool,Zpool) the parameter "DataWindow" can be added to the pool's configuration record. 
Possible values are:
- estimate_current (=default): the pool's current calculated profitability-estimation (more switching, relies on the honesty of the pool)
- estimate_last24h: the pool's calculated profitability-estimation for the past 24 hours (less switching, relies on the honesty of the pool)
- actual_last24h: the actual profitability over the past 24 hours (less switching)
- minimum2: the minimum value of estimate_current and actual_last24h will be used
- maximum2: the maximum value of estimate_current and actual_last24h will be used
- average2: the calculated average of estimate_current and actual_last24h will be used
- mininum2e: the minimum value of estimate_current and estimate_last24h will be used
- maximum2e: the maximum value of estimate_current and estimate_last24h will be used
- average2e: the calculated average of estimate_current and estimate_last24h will be used
- minimum2h: the minimum value of estimate_last24h and actual_last24h will be used
- maximum2h: the maximum value of estimate_last24h and actual_last24h will be used
- average2h: the calculated average of estimate_last24h and actual_last24h will be used
- mininum3: the minimum value of the above three values will be used
- maximum3: the maximum value of the above three values will be used
- average3: the calculated average of the above three values will be used
    
Example:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 0,
        "DataWindow": "minimum3"
    }


#### Change a pool's moving average (stat average)

The price pulled from the pool's API is being averaged down with a defined moving average trend line. The averaging time can be defined, using the parameter "StatAverage". It overrides the global default set by the config.txt parameter "PoolStatAverage".

Possible values are:
- Live: the live price
- Minute_5: five minutes moving average
- Minute_10: ten minutes moving average
- Hour: one hour moving average
- Day: one day moving average
- ThreeDay: three day moving average
- Week: one week moving average

Example:

    "Zpool": {
        "LTC": "<YOUR_LITECOIN_ADDRESS>",
        "Worker": "$WorkerName",
        "Penalty": 0,
        "DataWindow": "minimum3",
        "StatAverage": "Hour"
    }


#### Define the algorithms and coins of a pool
    
Per default all algorithms of a pool will be used. To define your own set of algorithm, there are two additional fields:
- Algorithm: a comma separated list of all pool's algorithm, you want RainbowMiner to use (leave empty for all)
- ExcludeAlgorithm: a comma separated list of all pool's algorithm, you explicitly do not want RainbowMiner to use (leave empty for no exception)
- CoinName: a comma separated list of coin names, you want RainbowMiner to use (leave empty for all). The coin's name must be spelled exactly like it is used at the corresponding pool. It applies to the pools, that transmit the coin names, only.
- ExcludeCoin: a comma separated list of coin names, you explicitly do not want RainbowMiner to use (leave empty for all coins). The coin's name must be spelled exactly like it is used at the corresponding pool. It applies to the pools, that transmit the coin names, only.
- CoinSymbol: a comma separated list of coin symbols, you want RainbowMiner to use (leave empty for all). Better alternative to "CoinName"
- ExcludeCoinSymbol: a comma separated list of coin's, you want RainbowMiner to use (leave empty for all). Better alternative to "ExcludeCoin"
- EnablePostBlockMining: set to "1" to allow forced mining a specific currency for a timespan (defined in coins.config.txt), after a block has been found.
- CoinSymbolPBM: if EnablePostBlockMining is set to "1", specify which currency is taken into account for post block mining. Leave empty for all.

Example:

    "MiningPoolHub": {
        "User": "$UserName",
        "Worker": "$WorkerName",
        "API_ID": "$API_ID",
        "API_Key": "$API_Key",
        "Algorithm": "lyra2z,skein,myriadgroestl,groestl,neoscrypt,equihash-btg",
        "ExcludeAlgorithm": "",
        "CoinName": "",
        "ExcludeCoin": "",
        "CoinSymbol": "",
        "ExcludeCoinSymbol": "BTG,XTC",
        "FocusWallet": "",
        "EnablePostBlockMining": "0",
        "CoinSymbolPBM": ""
    }
    
#### Force mining to a pool's wallet

To force mining to pool's wallets, you may add the wallet's currencies to field "FocusWallet". RainbowMiner will mine into the the focused pool/wallets, only.

Example:

    "Ethermine": {
        "ETH": "0x012031012301230123012301230",
        "ZEC": "$ZEC",
        "User": "$UserName",
        "Worker": "$WorkerName",
        "Algorithm": "",
        "ExcludeAlgorithm": "",
        "CoinName": "",
        "ExcludeCoin": "",
        "CoinSymbol": "",
        "ExcludeCoinSymbol": "",
        "FocusWallet": "ETH,ZEC"
    }

This example will focus mining operations to pool Ethermine, comparing this pool's profitability of ETH and ZEC, only. No other pool will be mined.

#### Allow mining algorithm when pool hashrate equals to 0
    
All pool modules contain a check for an algorithm hashrate to be greater than 0. If you want to mine a special currency, even if you are the only miner (e.g. solo mining on BsodSolo), set field "AllowZero" to "1":

Example:

    "BsodSolo": {
        "SUQA": "<YOUR_SUQA_ADDRESS>",
        "Worker": "$WorkerName",
        "FocusWallet": "SUQA",
        "AllowZero": "1"
    }

### Config\miners.config.txt

Each miner can be configured by it's own section, in the miners.config.txt

Example:

    {
        "CcminerAlexis78-NVIDIA":  [
                                {
                                    "MainAlgorithm":  "c11",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-i 21",
                                    "MSIAprofile":  "",
                                    "OCprofile": "",
                                    "Difficulty": ""
                                },
                                {
                                    "MainAlgorithm":  "keccak",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-m 2 -i 19,29",
                                    "MSIAprofile":  "",
                                    "OCprofile": "",
                                    "Difficulty": ""
                                }
                            ],
       "CcminerAlexis78-GTX1070":  [
                                {
                                    "MainAlgorithm":  "c11",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-i 21",
                                    "MSIAprofile":  "",
                                    "OCprofile": "Profile1",
                                    "Difficulty": ""
                                },
                                {
                                    "MainAlgorithm":  "keccak",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "-m 2 -i 19,29",
                                    "MSIAprofile":  "",
                                    "OCprofile": "",
                                    "Difficulty": ""
                                }
                            ],
        "Sgminer-AMD":  [
                                {
                                    "MainAlgorithm":  "lyra2rev2",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "--gpu-threads 2 --worksize 128 --intensity d",
                                    "MSIAprofile":  "",
                                    "OCprofile": "",
                                    "Difficulty": ""
                                },
                                {
                                    "MainAlgorithm":  "neoscrypt",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "--gpu-threads 1 --worksize 64 --intensity 15",
                                    "MSIAprofile":  "",
                                    "OCprofile": "",
                                    "Difficulty": "1000"
                                }
                            ],
        "Trex":  [
                                {
                                    "MainAlgorithm":  "\*",
                                    "SecondaryAlgorithm":  "",
                                    "Params":  "",
                                    "MSIAprofile":  "",
                                    "Penalty": "12.5",
                                    "Difficulty": ""
                                }
                            ]                                                                
    }

.. this adds extra command line parameters "-i 21" and "-m 2 -i 19,29" to
- "CcminerAlexis78-NVIDIA": miner CcminerAlexis78 in LegacyMining mode, mine on all selected nvidia GPU, Algorithms c11 and keccak
- "CcminerAlexis78-GTX1070": miner CcminerAlexis78 in non-LegacyMining mode on selected GPU devices with model name GTX1070, Algorithms c11 and keccak
- "CcminerAlexis78-GTX1070": miner will use custom overclocking profile "Profile1"
- "Sgminer-AMD": miner Sgminer in LegacyMining mode, mine on all selected amd GPU, Algorithms c11 and keccak
- "MainAlgorithm": alogrithm, for which the extra configuration will be used
- "SecondaryAlgorithm": secondary alogrithm, for which the extra configuration will be used (used for dual-mining Claymore, Excavator)
- "Params": these are the extra parameters, that will be added to the miner call
- "MSIAprofile": desired MSI Afterburner profile

.. this adds a Penalty of 12.5% to all algorithms used by Trex

.. this adds a static pool difficulty of 1000 to Sgminer's Neoscrypt


### Config\devices.config.txt

Each device group can be bound to/excluded from specific algorithm and miners by editing this config file.

Example:

    {
      "GTX1050Ti": [
        {
          "Algorithm": "Ethash,x16r",
          "ExcludeAlgorithm": "",
          "MinerName": "",
          "ExcludeMinerName": "ClaymoreEthash",
          "DisableDualMining": "1",
          "DefaultOCprofile": "Profile1",
          "PowerAdjust": "100",
          "Worker": "my1050"
        }
      ],
      "R290X": [
        {
          "Algorithm": "",
          "ExcludeAlgorithm": "",
          "MinerName": "",
          "ExcludeMinerName": "",
          "DisableDualMining": "1",
          "DefaultOCprofile": "Profile1",
          "PowerAdjust": "87.5",
          "Worker": ""
        }
      ]      
    }

This configuration would:
- bind all GTX1050Ti in the system to Ethash and X16R mining, only, excluding the ClaymoreEthash miner
- setting the flag "DisableDualMining" to "1", all dual-algorithm miners will be removed from this device's list.
- for custom overclocking Profile1 is used as default for this GPU type
- set a power adjust factor of 87.5% to the Radeon R290X (if RainbowMiner reported 250W with factor 100%, it will now show 250W x 87.5 / 100 = 175W)
- the pool worker name for the GTX1050Ti will be set to "my1050". If used in combos, the individual worker names will be combined with _ (underscore)


### Config\gpugroups.config.txt

Under some circumstances you might want to divide GPUs with unique model name into multiple groups (e.g. mining on different pools). For this case, all GPUs may be grouped, using group names, to be setup in gpugroups.config.txt.
To find out the GPU numbers in your system, start ListDevices.bat

Example:
Assumed four GTX1070 GPUs running in this rig.

    {
      "GPU#00": "A",
      "GPU#01": "A",
      "GPU#02": "Zerg",
      "GPU#03": ""
    }

Using this setup, RainbowMiner will use the following model names:
- GPU#00 and GPU#01 will get name "GTX1070A"
- GPU#02 will get name "GTX1070ZERG"
- GPU#03 will keep name "GTX1070"

This will result in three separate GPU groups. Be aware, that for each device group a new entry in devices.config.txt will be created. Also, all different device group combinations will be added to miners.config.txt.


### Config\algorithms.config.txt

Globally define parameters for algorithms:

Example:

    {
      "X17": {
          "Penalty": "10",
          "MinHashrate": "50GH",
          "MinWorkers": "300",
          "MaxTimeToFind": "1.5h",
          "MSIAprofile": 4,
          "OCprofile": "Profile4"
        }
    }

This configuration would:
- reduce all X17 pool prices by a "Penalty" of 10%
- set a minimum X17 pool hashrate of 50 GH/s for a pool to be selected (units allowed: k=kilo, M=Mega, G=Giga, T=Tera, P=Peta)
- set the mimimum pool workers mining X17 to 300 for a pool to be selected
- set a maximum time to find for the next block of 1.5 hours (units allowed: s=seconds, m=minutes, h=hours)
- set the MSI Afterburner overclocking profile to 4 (if MSIA is used)
- set the overclocking profile to "Profile4" (if the RainbowMiner oc is used)
- the overclocking profiles define the default for a specific algorithm
- the OCprofile hierarchy: miners.config.txt over algorithms.config.txt over devices.config.txt


### Config\coins.config.txt

Globally define parameters for coins:

Example:

    {
      "RVN": {
          "Penalty": "10",
          "MinHashrate": "50GH",
          "MinWorkers": "300",
          "MaxTimeToFind": "1.5h",
          "Wallet": "<YOUR_RAVENCOIN_ADDRESS>",
          "EnableAutoPool": "1",
          "PostBlockMining": "5m",
          "MinProfitPercent": "80"
        }
    }

This configuration would:
- reduce all RVN pool coin prices by a "Penalty" of 10%
- set a minimum RVN pool hashrate of 50 GH/s for a pool to be selected (units allowed: k=kilo, M=Mega, G=Giga, T=Tera, P=Peta)
- set the mimimum pool workers mining RVN to 300 for a pool to be selected
- set a maximum time to find for the next block of 1.5 hours (units allowed: s=seconds, m=minutes, h=hours)
- define a global RVN wallet with value <YOUR_RAVENCOIN_ADDRESS>. Every occurence of "$RVN" in pools.config.txt will be automatically substituted with this wallet.
- each pool, that has it's parameter "EnableAutoCoin" set to "1" will use this RVN wallet
- if a RVN block has been found within the timespan of 5 minutes (PostBlockMining) at a pool that has "EnablePostBlockMining" set to "1", RainbowMiner will force mining RVN on this pool
- switching to postblock mining only, if the post block miner's profit is at least 80% of the best miner's profit (field "MinProfitPercent")


### Config\ocprofiles.config.txt

This file contains all custom overclocking profiles. These profiles can be assigned by name to miners in file Config\miners.config.txt or to algorithms in file Config\algorithms.config.txt, field "OCprofile".

To make it easy to handle names, profiles may be assigned to devices. Just add the device model (see file Config\devices.config.txt for all model names), a specific device's name ("GPU#00","GPU#01",..) or PCI bus id ("00:02","00:03",..) with "-" to the profile name. With this feature, it is very easy to use different overclocking rules for devices under one name.

Example (this is the setup for one of my GTX1070 rigs, basicly substituting the MSI Afterburner profiles I recommended above)

    {
      "Profile1-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "0",
        "CoreClockBoost": "0",
        "LockVoltagePoint": "*"
      },
      "Profile2-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "400",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "*"
      },
      "Profile3-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "200",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "*"
      },
      "Profile4-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "-500",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "*"
      },
      "Profile5-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "350",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "*"
      },
      "Profile2-GPU#02": {
        "PowerLimit": 85,
        "ThermalLimit": 0,
        "MemoryClockBoost": "500",
        "CoreClockBoost": "150",
        "LockVoltagePoint": "*"
      }      
    }

- PowerLimit: in percent, set to 0, if you do not want this to be changed
- ThermalLimit: in °C, set to 0, if you do not want this to be changed
- MemoryClockBoost: in MHz, set to "*", if you do not want this to be changed
- CoreClockBoost: in MHz, set to "*", if you do not want this to be changed
- LockVoltagePoint: in µV set to "*", if you do not want this to be changed or "0", if voltagePoint should be unlocked

Note the last entry: "Profile-GPU#02"
Imagine a rig with multiple GTX1070 from the same manufacturer, except GPU#02, which is from a different manufacturer. This one GPU might need slightly different overclocking for Profile2. 
Adding the GPU's name or PCI bus id has priority over the model name selection.

### Config\scheduler.config.txt

Define different power prices and/or pause miners for different timespans.

- DayOfWeek: \*=all 0=Sunday 1=Monday 2=Tuesday 3=Wednesday 4=Thursday 5=Friday 6=Saturday
- From: start of timespan, 24h notation HH:MM, e.g. 15:30
- To: end of timespan, 24h notation HH:MM, e.g. 22:45
- PowerPrice: power price for this timespan, leave empty for default powerprice
- Pause: if set to "1", miners will be paused during this timespan
- Enable: if set to "1", this timespan will be used

Example

    [
        {
            "DayOfWeek":  "*",
            "From":  "01:15",
            "To":  "07:30",
            "PowerPrice":  "0.15",
            "Pause":  "0",
            "Enable":  "1"
        },
        {
            "DayOfWeek":  "0",
            "From":  "00:00",
            "To":  "23:59",
            "PowerPrice":  "",
            "Pause":  "0",
            "Enable":  "1"
        },
        {
            "DayOfWeek":  "1",
            "From":  "15:00",
            "To":  "16:30",
            "PowerPrice":  "",
            "Pause":  "1",
            "Enable":  "1"
        }
    ]

- On sunday (dow=0), the default power price from config.txt will be used for the whole day
- On monday (dow=1), the miners will be paused during 3pm - 4:30pm
- On all other weekdays (dow=*), a power price of 0.15 will be used during 1am - 7:30am
- During all other times, the default power price from config.txt will be used

### Config\autoexec.config.txt

If you want RainbowMiner to start other commands before the mining begins, you may add them to file Config\autoexec.config.txt by following the following rules:
- one line, one command
- command and path must be enclosed with doublequotes (")
- arguments (if any) must follow after the closing doublequote if the command
- a hashtag (#) marks the beginning of a comment, everything behind this within the line, will be ignored

Example:

    #
    # RainbowMiner autoexec
    # =====================
    # 

    "C:\Qbundle\BlagoMiner\Blagominer_avx.exe" --argument1 whatsoever1

.. would start Blagominer_avx.exe with commands ""--argument1 whatsoever1", setting the working directory to "C:\Qbundle\BlagoMiner"

## FAQ

### How do I add RainbowMiner's Start.bat to the windows task sheduler for autostart?

Press windows key and type `shedule`, click on `Task Sheduler`

`Create a basic task`

Tab "General":
- check `Run only when user is logged in`
- check `Run with highest privileges`
- Configure for: `Windows Vista, Windows Server 2008`

Tab "Trigger":
- check `When I log in`

Tab "Actions": 
- Action=`Start a program`
- Program/Script=`cmd`
- Add Arguments=`/c "C:\Users\RainbowMiner\Desktop\current-version\Start.bat"`
- Start In=`C:\Users\RainbowMiner\Desktop\current-version\`

### How can I rent my rig to someone at [MiningRigRentals.com](https://www.miningrigrentals.com?ref=2598069)?

#### 1. Signup and create a rig for rent
- signup at [https://www.miningrigrentals.com](https://www.miningrigrentals.com/register?ref=2598069)
- create API keys with permission "Balance/Withdraw" = "Read-Only" and "Manage Rigs" = "Yes" (Hint: if you have multiple RainbowMiner rigs, create new keys for each of it!)
- create a rig for at least one algorithm that you want to rent to an interested renter at the "MyRigs" section of the website
- optional: add pools on the "Pool Configuration" tab of the rig
- set your rig's rentable status to "available"
- edit your rig's description and add your RainbowMiner workername, enclosed with square brackets, somewhere into the text, e.g. ``[rbm]``. This is important, otherwise Rainbowminer will not find your rig, later.

#### 2. Setup Rainbowminer
- add "MiningRigRentals" to the PoolName list and make sure it is not in the ExcludePoolName list (config.txt or [C]onfiguration->[S]elections)
- edit "Config\pools.config.txt", find the MiningRigRentals section and add (API_Secret, User) or edit the following data:

  
    "API_Key": "<put your MiningRigRentals API-key here>",
    "API_Secret": "<put your MiningRigRentals API-secret key here>",
    "User": "<put your MiningRigRentals username here>",
    "Worker": "<put your RainbowMiner workername here or leave $WorkerName>",
    "EnableMining": "0",

All rigs will be automatically set to status "online", at [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) and rest idle within RainbowMiner. If someone starts a rental, RainbowMiner will detect this and run the respective miner exclusively, until the rental ends. All other rigs on [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) will be deactivated, for that time.

If you want to include [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) into RainbowMiner's profitability checks and switching operation, so that it behaves just like a normal pool, set "EnableMining" to "1". Only do this, if [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069) is your only pool, because the mining prices (these are the prices setup at [MiningRigRentals](https://www.miningrigrentals.com?ref=2598069)), will not reflect the real market prices.

### How can I quickly copy my current configuration to a new rig?

RainbowMiner comes with easy setup configuration. Download a setup.json at http://localhost:4000/setup.json from your current rig, copy it into the new rig's RainbowMiner folder *before first start* (you may easily reset RainbowMiner by simply deleting the complete `".\Config"` folder). Now answer two inputs and off you go.
More info can be [found here](https://github.com/RainbowMiner/RainbowMiner#copy-current-configuration-to-new-rigs).


### How can I make sure, my hand tuned config files in the Bin folders, will not be deleted during miner updates?

- RainbowMiner has a build-in list of protected files, that will be kept during updates: 

    config.txt
    nvidia.txt
    amd.txt
    config_*.txt

- If you want to add your own userdefined files, that should be kept from update to update, edit the file `Config\minerconfigfiles.txt` and add your files (wildcards are allowed), one at each row.

- if the automatic fails: when updating, RainbowMiner creates a backup folder that contains the full contents of the original. It is named like the original miner's folder, but date/time added with a dot (e.g. CryptoNight-SrbMiner.20181202_174533). A maximum of three backups is kept.

  
## CREDITS

The miner script has initially been forked from MultiPoolMiner, for my private use, only.
Since I changed and optimized the script a lot to suit my needs, I decided to make the source code public, so that others can profit from my optimizations.

**If you are happy with the script, bitcoin donations are greatly appreciated:**

**The RainbowMiner author**
  - BTC: 3P7pVVNpExuuHL9wjWKAo7jzQsb9ZziUFC
  - BCH: 1MGRzyaLjQ67ZwwL9QTbXzwLxa8x1qSTBD
  - ETH: 0x3084A8657ccF9d21575e5dD8357A2DEAf1904ef6

**The MultiPoolMiner author**
  - BTC: 1Q24z7gHPDbedkaWDTFqhMF8g7iHMehsCb
