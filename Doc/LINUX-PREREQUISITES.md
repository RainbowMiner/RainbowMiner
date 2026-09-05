# Linux pre-requisites

Everything a Linux rig needs before RainbowMiner is installed: the GPU driver, OpenCL, huge
pages and, for Nvidia, the cool-bits that make overclocking possible. RainbowMiner itself
only needs PowerShell 7 - `install.sh` takes care of that.

A complete walkthrough of a full rig setup, from the operating system to the autostart, is
kept in [LINUX-SETUP-SHORTGUIDE.md](LINUX-SETUP-SHORTGUIDE.md).

**Please note:** these instructions were written and verified with the driver and
distribution versions named in them (Ubuntu 22.04 with ROCm 5.4.1, and Ubuntu 18.04 with the
Nvidia 510 series). The commands are still valid as a template, but check the current
versions on the vendor's pages before you copy them: driver releases have moved on, and the
version that is right for your cards depends on the cards. Corrections are very welcome as
an [issue](https://github.com/RainbowMiner/RainbowMiner/issues) or a
[PR](https://github.com/RainbowMiner/RainbowMiner/pulls).

Contents

1. [Ubuntu 22.04 AMD Pre-requisites](#ubuntu-2204-amd-pre-requisites)
2. [Ubuntu 18.x Pre-requisites](#ubuntu-18x-pre-requisites)
3. [Huge Pages](#huge-pages)
4. [Video Cards](#video-cards)

## Ubuntu 22.04 AMD Pre-requisites
AMD drivers on recent versions of Ubuntu have been flaky and challenging to install. As of December 22, there is a nearly out of the box solution that works. Using older, or non-LTS versions of Ubuntu is always going to present a challenge down the road in terms of staying current from a security perspective, and who wants their rig getting owned? So 22.04.01 (LTS) is going to be a popular distro choice for rigs.

This has only been confirmed as working with RX 6700XT, RX 5700XT and RX5700.

To install the AMD drivers do:

    sudo apt-get update
    sudo apt install linux-headers-$(uname -r)
    wget https://repo.radeon.com/amdgpu-install/5.4.1/ubuntu/jammy/amdgpu-install_5.4.50401-1_all.deb
    sudo apt-get install ./amdgpu-install_5.4.50401-1_all.deb
    sudo ln -s /usr/src/amdgpu-5.18.13-1520974.22.04 /usr/src/amdgpu-5.18.2.22.40-1483871.22.04  # The AMD packages are still slightly broken
    sudo amdgpu-install --no-32 --usecase=rocm,opencl

You'll want to reboot at this point. No, seriously, just do it.

This results in driver versions of

    [ 3.998083] [drm] amdgpu kernel modesetting enabled.
    [ 3.998090] [drm] amdgpu version: 5.18.13
    [ 3.998092] [drm] OS DRM version: 5.15.0
You could also - instead - just install the runtime, and use the amdgpu module that comes with your Ubuntu kernel, in which case its:

    sudo apt-get update
    sudo apt install linux-headers-$(uname -r)
    wget https://repo.radeon.com/amdgpu-install/5.4.1/ubuntu/jammy/amdgpu-install_5.4.50401-1_all.deb
    sudo apt-get install ./amdgpu-install_5.4.50401-1_all.deb
    sudo amdgpu-install --no-32 --usecase=rocm,opencl --no-dkms
Testing has not been performed to determine which of these approaches results in the best mining performance. 

Finally you can go back to square 1 with

    sudo amdgpu-uninstall
    sudo apt remove amdgpu-install

.. and of course reboot.

The utilities are, somewhat un-helpfully, installed to /opt/rocm/bin so you'll want to add that to your PATH. One way to do that is to edit /etc/environment so it looks like this:

    PATH="/opt/rocm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"

You can change your current session with:
    export PATH=/opt/rocm/bin:$PATH

Finally you can test it is all working with the rocm-smi command, hopefully you'll get something like this:

    root@ubuntu2:/home/pi/RainbowMiner/Bin/AMD-Teamred# rocm-smi

    ROCm System Management Interface
    Concise Info
    GPU Temp (DieEdge) AvgPwr SCLK MCLK Fan Perf PwrCap VRAM% GPU%
    0 29.0c 11.0W 500Mhz 96Mhz 0% auto 186.0W 0% 6%
    1 30.0c 41.0W 800Mhz 100Mhz 0% auto 160.0W 0% 13%
    2 33.0c 95.0W 1440Mhz 100Mhz 0% auto 190.0W 0% 42%

    End of ROCm SMI Log
If you really want to validate all is well, then check out the RainbowMiner supplied version of TRM:

    root@ubuntu2:/home/pi/RainbowMiner/Bin/AMD-Teamred# ./teamredminer --list_devices
    Team Red Miner version 0.10.6
    [2022-12-23 20:18:21] Auto-detected AMD OpenCL platform 0
    [2022-12-23 20:18:21] Detected 3 GPU devices, listed in pcie bus id order:
    [2022-12-23 20:18:21] Miner Platform OpenCL BusId Name Model Nr CUs
    [2022-12-23 20:18:21] ----- -------- ------ -------- ------------- ------------------------- ------
    [2022-12-23 20:18:21] 0 0 0 27:00.0 gfx1031 AMD Radeon RX 6700 XT 20
    [2022-12-23 20:18:21] 1 0 1 2c:00.0 gfx1010 AMD Radeon RX 5700 18
    [2022-12-23 20:18:21] 2 0 2 2f:00.0 gfx1010 AMD Radeon RX 5700 XT 20
    [2022-12-23 20:18:21] Detected 0 FPGA devices
    [2022-12-23 20:18:21] Miner Board Part BusId DNA Serial
    [2022-12-23 20:18:21] ----- --------- ------ --------- ------------------------ ------------
    [2022-12-23 20:18:21] Successful clean shutdown.
Finally, let's make sure we don't have any library clashes:

    root@ubuntu2:/home/pi/RainbowMiner/Bin/AMD-Teamred# export LD_LIBRARY_PATH=./:/opt/rocm/lib
    root@ubuntu2:/home/pi/RainbowMiner/Bin/AMD-Teamred# ./teamredminer --list_devices
    Team Red Miner version 0.10.6
    [2022-12-23 20:18:21] Auto-detected AMD OpenCL platform 0
    [2022-12-23 20:18:21] Detected 3 GPU devices, listed in pcie bus id order:
    [2022-12-23 20:18:21] Miner Platform OpenCL BusId Name Model Nr CUs
    [2022-12-23 20:18:21] ----- -------- ------ -------- ------------- ------------------------- ------
    [2022-12-23 20:18:21] 0 0 0 27:00.0 gfx1031 AMD Radeon RX 6700 XT 20
    [2022-12-23 20:18:21] 1 0 1 2c:00.0 gfx1010 AMD Radeon RX 5700 18
    [2022-12-23 20:18:21] 2 0 2 2f:00.0 gfx1010 AMD Radeon RX 5700 XT 20
    [2022-12-23 20:18:21] Detected 0 FPGA devices
    [2022-12-23 20:18:21] Miner Board Part BusId DNA Serial
    [2022-12-23 20:18:21] ----- --------- ------ --------- ------------------------ ------------
    [2022-12-23 20:18:21] Successful clean shutdown.
    root@ubuntu2:/home/pi/RainbowMiner/Bin/AMD-Teamred# unset LD_LIBRARY_PATH
Happy AMD mining. Nothing here stops you also installing the Nvidia drivers, it's a little simpler on a modern Ubuntu:

    sudo apt install nvidia-driver-520 nvidia-dkms-520 nvidia-utils-520 nvidia-settings xserver-xorg-video-nvidia-520  libnvidia-ml1

But mixed rigs can present their own challenges further down the road.

You may also want to tweak huge pages as noted in the Ubuntu 18.x notes below

## Ubuntu 18.x Pre-requisites

(This section is WIP! Want to help? Make an [issue](https://github.com/RainbowMiner/RainbowMiner/issues) or a [PR](https://github.com/RainbowMiner/RainbowMiner/pulls)))

Debian-based distros will be more-or-less the same as these instructions.

Other distros will have settings in different places (hugepages) and the software install commands will be different (dnf, yum, pacman, nix, pkg, etc.) It is assumed you are clever enough to sort out the differences on your own if you choose a different distribution. BUT! As noted above, feel free to edit this page and make a pull request.

### Huge Pages

By default, linux sets memory-chunk size fairly small. This is to save RAM usage for low-requirement software (ie: most programs running in system-space, rather than user-space.) Scrypt^N (Verium) and the CryptoNight family (Monero, etc.) algorithms *need* a large memory-chunk allocation, and many benefit from it even if they don't need it. In linux, this is called 'hugepages'. For Ubuntu-based distributions, you can set this manually on each boot with `sudo sysctl -w vm.nr_hugepages=XXX` where XXX is how many megabytes to assign per page-chunk.  This can be made persistent across reboots by editing the value in `/proc/sys/vm/nr_hugepages` and you need to be root to do it (ie: `sudo emacs -wm /proc/sys/vm/nr_hugepages` (substitute 'emacs -wm' with your editor of choice - nano, vi, joe, etc.))

On newer Ubuntu distros (Ubuntu 18.04 - Bionic Beaver and up), the value can be added to `/etc/sysctl.conf` and you need to be root to do it (ie: `sudo emacs -wm /etc/sysctl.conf` (substitute 'emacs -wm' with your editor of choice - nano, vi, joe, etc.)) The system will need to be rebooted to load the new kernel parameters or you can run `sudo sysctl -p` to load any new or changed parameters at runtime. 

On my system (@ParalegicRacehorse), xmr-stak will not run with hugepages<1024. Setting it to 2048 did not gain me anything more than 1024, but experience in the verium/vericoin community have shown hugepages as large as 4096 can be beneficial. YMMV. Tuning is left to the rig operator, but I recommend keeping it as low as you can get away with so your other programs can run lean.

### Video Cards

#### Nvidia

Nvidia has kindly supplied a ppa for their official drivers.

1. install some needed packages and add the drivers repository:

       sudo apt update
       sudo add-apt-repository ppa:graphics-drivers/ppa
       sudo apt -y install dkms build-essential
       sudo apt update

2. optionally, uninstall any existing Nvidia driver:

       sudo apt-get -y purge nvidia-*
       sudo apt-get -y autoremove --purge

3. now install the new Nvidia driver and reboot

       sudo apt -y install nvidia-headless-510 nvidia-driver-510 nvidia-compute-utils-510 nvidia-cuda-toolkit
       sudo reboot

4. finally make sure OpenCL is installed

       sudo apt -y install nvidia-opencl-dev

**Important: check which version of the Nvidia driver you need (i.e. which is compatible with your graphics card)** You can check on the Nvidia website which products are supported by each driver (the latest one is usually the best if you have a recent graphics card). Not doing so can cause a black screen on reboot. Only the main version is needed (don't bother about the number after the point, so if latest driver is 510.60, just write 510).

##### Optional Overclocking for Nvidia

    sudo nvidia-xconfig -a --cool-bits=31 --allow-empty-initial-configuration
    sudo reboot

Reboot after setting cool bits.

#### AMD Drivers

Download and extract the latest driver for your cards from the [AMD support site](https://www.amd.com/en/support)

After the archive is downloaded, extract the contents to a temporary location from which you can install it. 

Run the following to install it "headless" (this is necessary for Ubuntu Desktop installations and possibly some other configurations. [Read more here](https://amdgpu-install.readthedocs.io/en/latest/install-installing.html#installing-the-pro-variant)) and with ROCm support.

    ./amdgpu-pro-install -y --opencl=pal,legacy,rocm --headless

Reboot and you should be good to go! 

**Important:** Some algorithms, on some miner-software, will not hash with a kernel version greater than 4.2. You may have to downgrade your OS to Ubuntu 16.04 since more recent editions will not run kernel numbers lower than 4.8. This has everything to do with a mismatch between OpenCL versions provided by recent drivers and those supported by the mining software. Yes, that means you will be running older drivers. If you want the newer drivers, with newer versions of OpenCL to work, feel free to provide assistance to the affected mining software by fixing their code and sending pull-requests.

## RainbowMiner does not find the GPUs

RainbowMiner detects the GPUs through OpenCL, so `clinfo` is the tool to check with: if
`clinfo` does not list a platform and its devices, RainbowMiner will not see them either -
even when `lspci`, `rocm-smi` or `nvidia-smi` are perfectly happy, and even when the miner
binaries find the cards on their own.

Things worth checking, in this order:

- **is the OpenCL ICD loader installed?** The vendor driver installs the vendor part, but the
  loader is a separate package and is missing surprisingly often. On Debian/Ubuntu:
  `sudo apt install ocl-icd-libopencl1 ocl-icd-opencl-dev`, then check `/etc/OpenCL/vendors`
  for a file that points at your driver
- **does it work as root?** If `clinfo` finds the cards as root but not as your user, the
  user is missing the `video` and `render` groups: `sudo usermod -aG video,render $USER` and
  log in again
- **do the kernel module and the libraries match?** A driver installed against different
  kernel headers than the running kernel (typical after a half-finished distribution upgrade)
  produces exactly this picture: some calls work, `clinfo` errors out, `rocm-smi` still looks
  fine. Reinstall the driver against the running kernel - `uname -r` and the version in
  `dmesg | grep amdgpu` have to fit together
- **AMD only:** older amdgpu releases need `amdgpu.ppfeaturemask=0xffffffff` on the kernel
  command line, or overclocking and memory timings stay unavailable

Test with `clinfo | head`, then with the miner itself, e.g.
`./Bin/AMD-Teamred/teamredminer --list_devices`, before you look for the problem in
RainbowMiner.
