# Overclocking

RainbowMiner can change the overclocking of your GPUs whenever it switches the miner or the
algorithm, because the settings that are best for one algorithm are rarely the best for the
next one. There are two ways to do that: switching between the five profiles of MSI
Afterburner, or RainbowMiner's own overclocking profiles, which are unlimited in number and
can be assigned per miner, algorithm and device.

**Be careful when playing with OC, since this can damage your devices. RainbowMiner will not
be responsible, if you kill your devices.**

Contents

1. [Which of the two options do I want?](#which-of-the-two-options-do-i-want)
2. [Option 1: MSI Afterburner profiles](#option-1-msi-afterburner-profiles)
3. [Option 2: custom overclocking profiles](#option-2-custom-overclocking-profiles)
4. [Config\ocprofiles.config.txt](#configocprofilesconfigtxt)
5. [The default profiles](#the-default-profiles)
6. [Memory offsets on Linux](#memory-offsets-on-linux)
7. [Recommended clock locks](#recommended-clock-locks)
8. [The Nvidia P2 state](#the-nvidia-p2-state)
9. [Overclocking does not work on Linux](#overclocking-does-not-work-on-linux)

## Which of the two options do I want?

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
  - independent of MSI Afterburner

If you do not want to use the overclocking features in RainbowMiner: set both, "**EnableOCProfiles**" and "**MSIAprofile**", to "**0**" ([C]onfiguration->[C]ommon)

**Frequently asked questions**

> Just wondering what would happen if in miners.config I set the ocprofile to a clock and then set it different within AF under the same profile number. Would one trump the other? If so which one would override? 

Only one of the two OC options can be enabled at a time:

| config.txt                | MSIAprofile | EnableOCprofiles |
| ------------------------- | :---------: | :--------------: |
| Use ocprofiles.config.txt |   whatever  |         1        |
| Use Afterburner profiles  |     1-5     |         0        |
| No OC switching at all    |      0      |         0        |

The differences:

|                                              | MSIAprofiles | ocprofiles |
| -------------------------------------------- | :----------: | :--------: |
| Can handle parallel miners on different GPUs |      no      |     yes    |
| Depends on Afterburner                       |      yes     |     no     |
| Depends on nvidiaInspector                   |      no      |     yes    |
| Speed with more than 6 GPU                   |     slow     |    fast    |
| Works for Nvidia                             |      yes     |     yes    |
| Works for AMD                                |      yes     |     no     |
| max. number of profiles                      |       5      |  unlimited |
| Individual profile names                     |      no      |     yes    |

> I set the ocprofile to a clock and then set it different within AF under the same profile number

- MSI Afterburner profiles are fixed to a maximum of five and are selected by their number 1 to 5 in parameter "MSIAprofile" in miners.config.txt
- ocprofiles are unlimited in amount, you decide what their names are. RainbowMiner comes with preset profiles named "Profile0" to "Profile8" (see [The default profiles](#the-default-profiles)). The profile is being selected by the full name in parameter "OCprofile" in miners.config.txt (for example "Profile2")

> My overclocking settings do not work on Linux

- check config.txt, if "EnableOCProfiles" is set to 1
- are you running a headless system (without monitor), then set "EnableLinuxHeadless" to "1"
- open a linux shell and start `ocdaemon status` - it should report `Running`. If not, run `./install.sh` again.
- open a linux shell and cd to IncludesLinux/bash within your RainbowMiner folder - start `./getxauth.sh` and see, if the XAUTHORITY path matches your system's. If not, enter your system's path into parameter "LinuxXAuthority" in config.txt.


    "EnableOCProfiles": "1",
    "EnableLinuxHeadless": "1",


## Option 1: MSI Afterburner profiles

Overclocking option, recommended for **unique GPU mining rigs with maximum 6 GPU**

### Introduction

MSI Afterburner allows to configure up to five profiles. Each of which defines the exact overclocking parameters for any number of GPU. RainbowMiner will never change these values, but it can be defined for miners/algorithms/devices, that another profile than the default should be used during mining (miners.config.txt, fields "MSIAprofile"). RainbowMiner comes with some miner/algorithm presets, already.

### Enable Profile Switching

By default, the profile switching is disabled. To enable MSI Afterburner profile switching:

- check or set the path to MSIA (config.txt, field "MSIApath")
- set the profile number you want to be used as default (config.txt, field "MSIAprofile") 

### Explanation of operation

RainbowMiner's default setup has already preset some Profile fields for the following algorithms (miners.config.txt, fields "MSIAprofile"):
- ClaymoreEthash-Keccak, NeoScrypt => Profile 3
- Lyra2Re2, Lyra2z, X16r, X16s => Profile 4
- ClaymoreEthash-Blake2s, ClaymoreEthash-Pascal => Profile 5

Remember: **no overclocking values will be changed by RainbowMiner!** It will switch your preset profiles, only.

I recommend you set the following profile setup in MSI Afterburner, so that you can use the default setup of RainbowMiner. The overclocking values in brackets (core clock/memory clock) are those I use for my GTX 1070 and are only for illustration.

- Profile 1: no oc (e.g. +0/+0)
- Profile 2: max. core / max. memory oc (e.g. +100/+400), good for most miners
- Profile 3: max. core / half memory oc (e.g. +100/+200), recm. for claymore ethash-keccak, neoscrypt
- Profile 4: max. core / low memory oc (e.g. +100/-500), recm. for lyra2re2, lyra2z, x16r, x16s
- Profile 5: max. core / reduced memory oc (e.g. +100/+350), recm. for claymore ethash-blake2s, claymore ethash-pascal

Be careful when playing with OC, since this can damage your devices. RainbowMiner will not be responsible, if you kill your devices.


## Option 2: custom overclocking profiles

Recommended for mining rigs with **more than 6 GPU** or **different GPU**

### Introduction

Each miner/device/algorithm combination can have it's own overclocking values set by RainbowMiner. To enable: set "**EnableOCProfiles**" to "**1**" in your config.txt or use the [C]onfiguration->[C]ommon.

**!! It is important, that you choose a default profile for each GPU device in your devices.config.txt !!**

You can edit the file directly: put the name of your custom default profile into field "**DefaultOCprofile**"
Alternatively, the devices can be changed using [C]onfiguration->[D]evices

### 1. setup overclocking profiles

Use [C]onfiguration->[O]C-Profiles to edit, create and delete overclocking profiles. Values for PowerLimit (%), ThermalLimit (°C), MemoryClockBoost (MHz), CoreClockBoost (MHz), LockMemoryClock (MHz), LockCoreClock (MHz) and LockVoltagePoint (µV) (see hint below) can be defined. You may name the profiles like you want. Hint: Use the complete profile's names, when editing the config files directly. Of course you may also edit the ocprofiles.config.txt file directly.

Hint: LockVoltagePoint can only be set, if EnableOCvoltage is set to 1 in your config.txt (or use [C]onfiguration->[C]ommon to change)

### 2. set one default profile for each GPU group

With the help of [C]onfiguration->[D]evices it is very easy to choose a default profile for each GPU group used. The values can be edited directly in file devices.config.txt, too. Put the names of the default profiles into the property "DefaultOCprofile".

### 3. assign profiles to miner-device-algorithms

The assignment is done, using either [C]onfiguration->[M]iners or directly edited into the miners.config.txt file. Find your miner, the device it will use, plus the algorithm and put the profile's name into the field "**OCprofile**" 

## Config\ocprofiles.config.txt

This file contains all custom overclocking profiles. These profiles can be assigned by name to miners in file Config\miners.config.txt or to algorithms in file Config\algorithms.config.txt, field "OCprofile".

To make it easy to handle names, profiles may be assigned to devices. Just add the device model (see file Config\devices.config.txt for all model names), a specific device's name ("GPU#00","GPU#01",..) or PCI bus id ("00:02","00:03",..) with "-" to the profile name. With this feature, it is very easy to use different overclocking rules for devices under one name.

Example (this is the setup for one of my GTX1070 rigs, basically substituting the MSI Afterburner profiles I recommended above)

    {
      "Profile1-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "0",
        "CoreClockBoost": "0",
        "LockVoltagePoint": "*",
        "LockMemoryClock": "*",
        "LockCoreClock": "*",
        "PreCmd": "",
        "PreCmdArguments": "",
        "PostCmd": "",
        "PostCmdArguments": ""
      },
      "Profile2-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "400",
        "CoreClockBoost": "100",
        "LockVoltagePoint": "*",
        "LockMemoryClock": "*",
        "LockCoreClock": "*",
        "PreCmd": "",
        "PreCmdArguments": "",
        "PostCmd": "",
        "PostCmdArguments": ""
      },
      "Profile3-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "200",
        "CoreClockBoost": "100",
        "LockMemoryClock": "*",
        "LockCoreClock": "*",
        "LockVoltagePoint": "*",
        "PreCmd": "",
        "PreCmdArguments": "",
        "PostCmd": "",
        "PostCmdArguments": ""
      },
      "Profile4-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "-500",
        "CoreClockBoost": "100",
        "LockMemoryClock": "*",
        "LockCoreClock": "*",
        "LockVoltagePoint": "*",
        "PreCmd": "",
        "PreCmdArguments": "",
        "PostCmd": "",
        "PostCmdArguments": ""
      },
      "Profile5-GTX1070": {
        "PowerLimit": 80,
        "ThermalLimit": 0,
        "MemoryClockBoost": "350",
        "CoreClockBoost": "100",
        "LockMemoryClock": "*",
        "LockCoreClock": "*",
        "LockVoltagePoint": "*",
        "PreCmd": "",
        "PreCmdArguments": "",
        "PostCmd": "",
        "PostCmdArguments": ""
      },
      "Profile2-GPU#02": {
        "PowerLimit": 85,
        "ThermalLimit": 0,
        "MemoryClockBoost": "500",
        "CoreClockBoost": "150",
        "LockMemoryClock": "*",
        "LockCoreClock": "*",
        "LockVoltagePoint": "*",
        "PreCmd": "",
        "PreCmdArguments": "",
        "PostCmd": "",
        "PostCmdArguments": ""
      }
    }

- PowerLimit: in percent, set to 0, if you do not want this to be changed
- ThermalLimit: in °C, set to 0, if you do not want this to be changed
- MemoryClockBoost: in MHz, set to "*", if you do not want this to be changed
- CoreClockBoost: in MHz, set to "*", if you do not want this to be changed
- LockVoltagePoint: in µV, set to "*", if you do not want this to be changed or "0", if voltagePoint should be unlocked
- LockMemoryClock: in MHz, set to "*", if you do not want this to be changed or "0", if MemoryClock should be unlocked
- LockCoreClock: in MHz, set to "*", if you do not want this to be changed or "0", if CoreClock should be unlocked
- PreCmd/PreCmdArguments: define a command to be executed before the miner starts. PreCmd is the path to the binary, PreCmdArguments are optional arguments for that command.
- PostCmd/PostCmdArguments: define a command to be executed after the miner has finished. PostCmd is the path to the binary, PostCmdArguments are optional arguments for that command.

Note the last entry: "Profile2-GPU#02"
Imagine a rig with multiple GTX1070 from the same manufacturer, except GPU#02, which is from a different manufacturer. This one GPU might need slightly different overclocking for Profile2.

The suffix decides how narrowly a profile is aimed, and the more specific one always wins:

| Suffix | Example | Addresses |
| ------------ | ------------------------------------- | ---------------------------------------- |
| GPU id       | `Profile2-GPU#03`, short `Profile2-3` | exactly that one GPU                      |
| PCI bus id   | `Profile2-03:00`                      | the GPU at that PCIe address              |
| device model | `Profile2-GTX1060`                    | all GPUs of that model, that no rule above already covers |
| no suffix    | `Profile2`                            | everything else                           |

So a rig with six GTX1060, of which two only take a low memory overclock, needs one
`Profile2-GTX1060` for the four good ones plus a `Profile2-GPU#04` and `Profile2-GPU#05` for
the other two.

## The default profiles

RainbowMiner seeds `Profile0` to `Profile8` for every GPU model it finds in your rig. For the
Nvidia models listed below, the values come from a preset table; every other model gets empty
profiles that change nothing. The presets are written once: RainbowMiner never overwrites a
profile that is already in your `ocprofiles.config.txt`, so editing them is safe.

| Profile  | Idea                                   | Used by (algorithms.config.txt)                                          |
| -------- | -------------------------------------- | ------------------------------------------------------------------------ |
| Profile0 | core up, memory +0                     | Cuckatoo31/32, Cuckaroo29/30                                             |
| Profile1 | stock, nothing is changed              | Allium, Qubit                                                            |
| Profile2 | core up, memory max                    | Autolykos2, NexaPow, XelisHashV2/V3, BeamHash3, MTP - and the default for every algorithm without an entry |
| Profile3 | core up, half memory                   | Equihash family, NeoScrypt                                               |
| Profile4 | core up, memory as low as it goes      | kHeavyHash, Karlsen v1, Pyrin, Blake3, SHA512256d, SHA3x, SHA256dt, Hoohash, Qhash, Quantus, DynexSolve, X16r family, Lyra2z |
| Profile5 | core up, memory reduced (85%)          | a few miner-specific entries in miners.config.txt                         |
| Profile6 | core down, memory max, low power       | Ethash, EtcHash, EthashB3, UbqHash, FishHash, KarlsenHashV2, Octopus     |
| Profile7 | core slightly up, memory max           | KawPow family, EvrProgPow, MeowPow, SCCPow                               |
| Profile8 | core +0, memory max                    | FiroPow, ProgPowZ and the other plain ProgPow variants                   |

Presets exist for GTX1050Ti, GTX1060 (3GB/6GB), GTX1070, GTX1070Ti, GTX1080, GTX1080Ti,
P104-100, P106-100, GTX1650 (Super), GTX1660 (Super/Ti), RTX2060 to RTX2080Ti (incl. Super),
the whole RTX30, RTX40 and RTX50 series. They are conservative values that should run on any
card of that model, not the maximum your card may reach. Things to know:

- **GTX1070, RTX3070** are tested by the RainbowMiner author; all others are taken from public
  mining benchmarks (hashrate.no, Kryptex) and should be checked on your own rig.
- **GDDR5X (GTX1080, GTX1080Ti, P104-100):** if you use the ETHlargement Pill or a miner's
  memory timing tweak, the usable memory offset goes down.
- **GTX1660 Super with Hynix memory** does not take positive memory offsets well, that's why its
  preset is low. Samsung and Micron cards can take +750.
- **GDDR6X (RTX3070Ti, RTX3080/Ti, RTX3090/Ti):** watch the memory junction temperature, it
  throttles at 110 C. The RTX3090 back-side memory is the first to get there.
- **4 GB cards** (GTX1050Ti, GTX1650) are too small for most current DAG coins, so Profile6 to
  Profile8 only matter for them on small-DAG coins.

## Memory offsets on Linux

All presets and all values in this document use the Windows scale, the one that MSI
Afterburner and nvidiaInspector show. On Linux, RainbowMiner hands MemoryClockBoost to
nvidia-settings as `GPUMemoryTransferRateOffset`, which is an offset on the memory **transfer
rate**. GDDR memory transfers data twice per clock, so the transfer rate is exactly twice the
clock, and **the same number gives only half the memory overclock on Linux**.

This does not depend on the Linux distribution, the GPU generation or the memory type
(GDDR5, GDDR5X, GDDR6, GDDR6X, GDDR7) - it is the unit of the Linux control. HiveOS says the
same: "Usually this value is double from what you see in AfterBurner" (+800 on Windows = 1600
on HiveOS). Values from hashrate.no, HiveOS, lolMiner `--moff` or BzMiner are already in the
Linux scale; Rigel `--mclock` uses the Windows scale.

So on a Linux rig, double the MemoryClockBoost of the presets. Nothing else is affected:
CoreClockBoost, PowerLimit and the absolute locks LockCoreClock/LockMemoryClock take the same
numbers on both systems.

## Recommended clock locks

Since Turing, most miners lock the core clock instead of using an offset: a locked core plus a
positive CoreClockBoost runs the card at a lower voltage (an undervolt), and memory locked at
810 MHz, its lowest state, saves a lot of power on algorithms that do not need memory speed.
The presets do not use locks, because they have side effects:

- on Windows, RainbowMiner can only set locks when it runs as administrator
- a lock stays in place until something unlocks it. `"*"` leaves a lock untouched, so once one
  profile of a card sets a lock, **all other profiles of that card must set LockCoreClock and
  LockMemoryClock to "0"** - otherwise the next algorithm runs with the old lock
- Pascal (GTX10xx, P10x) does not support locks on most drivers

If you want them, these are good starting points (LockCoreClock / LockMemoryClock in MHz,
"-" means leave it "*" and use the offset preset):

| Profile                  | Turing      | Ampere GDDR6 | Ampere GDDR6X | Ada         | Blackwell   |
| ------------------------ | ----------- | ------------ | ------------- | ----------- | ----------- |
| Profile2 (Autolykos2)    | 1200 / -    | 1410 / -     | 1410 / -      | 2100 / -    | 1800 / -    |
| Profile3 (Equihash)      | 1500 / -    | 1600 / -     | 1600 / -      | 2400 / -    | 2400 / -    |
| Profile4 (core-heavy)    | 1500 / 810  | 1400 / 810   | 1450 / 810    | 2200 / 810  | 2000 / 810  |
| Profile6 (Ethash family) | 1100 / -    | 1410 / -     | 1100 / -      | 2000 / -    | 2400 / -    |
| Profile7 (KawPow)        | -           | -            | 1200 / -      | 2200 / -    | 2400 / -    |
| Profile8 (ProgPow)       | -           | -            | 1200 / -      | 2200 / -    | 2400 / -    |

- For more efficiency on Ampere, use 1305 instead of 1400 for Profile4.
- NexaPow uses Profile2, but prefers memory locked at 5000 instead of an offset.
- Autolykos2 with memory locked at 5000 loses about 13% hashrate for about 20% less power.

## The Nvidia P2 state

Nvidia's consumer cards are not meant for compute work: they start a mining job in the P0
performance state and drop back to P2 shortly after, which lowers the memory clock and makes
all your overclocking numbers meaningless. Switching that behaviour off is often worth more
than the overclocking itself.

**On Windows**, use the Nvidia Profile Inspector that ships with RainbowMiner:

1. stop all miners
2. set memory +0 and core +0 in MSI Afterburner
3. open `Includes\NvidiaProfileInspector` in your RainbowMiner folder and start
   `NvidiaProfileInspector.exe`
4. in **section 5**, set **CUDA - Force P2 State** to **Off** and click **Apply Settings**
5. redo your overclocking profiles - the reference clocks have shifted, and values that were
   safe in P2 can be outside the card's limits in P0

**Every Nvidia driver update sets "Force P2 State" back to On**, so this has to be repeated
after each driver installation. If NvidiaProfileInspector refuses to start, delete
`AppData\Local\NVIDIA Profile Inspector\settings.xml` and start it again.

**On Linux** there is no way to switch the P2 state off. RainbowMiner works around it with
`EnableOCLinuxForcePState`: a helper keeps all Nvidia GPUs in their workload performance
state for as long as they are mining, without using measurable resources. The cards do stay
in P2 though, so overclocks that are stable under Windows can be too ambitious here - dial
them back a little rather than hunting for a P0 switch that does not exist on Linux.

## Overclocking does not work on Linux

If the power limit and the thermal limit are applied but the memory and core clocks are not,
the cause is almost always the access to the X server:

- `"EnableOCProfiles": "1"` must be set
- on a rig without a monitor, `"EnableLinuxHeadless": "1"` must be set as well
- `ocdaemon status` in a shell must report `Running` - if it does not, run `./install.sh`
  again
- the XAUTHORITY path must match your system. `IncludesLinux/bash/getxauth.sh` guesses it;
  if the guess is wrong, find the real one with `ps aux | grep Xorg` and put it into
  `"LinuxXAuthority"` in config.txt

One trap on a client rig: `EnableLinuxHeadless` is an ordinary config value, so a server
config can overwrite it. If overclocking stops working right after a config sync, check
whether the setting is still there and add it to `ExcludeServerConfigVars` if needed.
