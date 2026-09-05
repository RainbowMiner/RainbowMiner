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
5. [The Nvidia P2 state](#the-nvidia-p2-state)
6. [Overclocking does not work on Linux](#overclocking-does-not-work-on-linux)

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
- ocprofiles are unlimited in amount, you decide what their names are. RainbowMiner comes with an example ocprofiles.config.txt, where the profiles are named "Profile1", "Profile", .. "Profile9". The profile is being selected by the full name in parameter "OCprofile" in miners.config.txt (for example "Profile2")

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
