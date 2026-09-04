# Custom Miners

RainbowMiner ships with more than a hundred miner modules, but sometimes the miner you
need is not among them: a brand new release for a young coin, a private build, or a
program that only a handful of people use. Custom miners close that gap. You describe the
miner once - where to download it, how to start it and how RainbowMiner can read its
hashrate - and from then on it is treated like every built-in miner: the binary is
downloaded, every algorithm you list is benchmarked, and the miner takes part in the
profit switching with all pools that serve its algorithms.

HiveOS users will feel at home: the definition covers the same fields as a HiveOS custom
miner flight sheet, and flight sheet JSON can be imported and exported.

Contents

1. [Quick start](#quick-start)
2. [Importing a HiveOS flight sheet](#importing-a-hiveos-flight-sheet)
3. [The fields](#the-fields)
4. [Placeholders for the command line](#placeholders-for-the-command-line)
5. [Reading the hashrate](#reading-the-hashrate)
6. [Worked example: BzMiner](#worked-example-bzminer)
7. [Tips and troubleshooting](#tips-and-troubleshooting)

## Quick start

1. Open the web interface at [localhost:4000](http://localhost:4000) and click
   **Config > Custom Miners**.
2. Click **New custom miner** (or **Import flight sheet**, see below).
3. Fill in the form:
   - **Name**: a short name without spaces, e.g. `MyMiner`. It becomes the folder
     `Bin\Custom-MyMiner`, the key in `miners.config.txt` and the prefix of the
     benchmark files.
   - **Download**: the URL of the Windows archive and the name of the executable inside
     it, and/or the same for Linux. Only the fields for the operating system of the rig
     have to be filled.
   - **Devices**: the device types the miner can use (NVIDIA, AMD, INTEL, CPU).
   - **Hashrate and API**: how RainbowMiner reads the speed. `Wrapper` works for most
     miners, it reads values like `12.3 MH/s` from the miner output.
   - **Arguments**: the command line, with placeholders for pool, wallet, devices and port.
   - **Algorithms**: one row per algorithm the miner should mine.
4. Click **Save**. RainbowMiner picks the miner up after the current round, downloads
   the binary into `Bin\Custom-<Name>` and starts benchmarking.
5. Watch it on the **Miners** page (it appears with its name, like every other miner) and
   on the **Benchmarks** page once the first hashrate is in.

The definition is stored in `Config\customminers.config.txt`. You can also edit that
file with the **JSON Editor** page or a text editor.

## Importing a HiveOS flight sheet

Many coin projects publish a HiveOS flight sheet for their miner, a JSON block like this:

```json
{
  "name": "PEARL_BZMINER_CUSTOM",
  "items": [
    {
      "coin": "PEARL",
      "pool_ssl": false,
      "pool_urls": [ "us.pearl.herominers.com:1200" ],
      "miner": "custom",
      "miner_alt": "bzminer_custom",
      "miner_config": {
        "url": "us.pearl.herominers.com:1200",
        "algo": "pearl",
        "pass": "x",
        "miner": "bzminer_custom",
        "template": "%WAL%",
        "install_url": "https://github.com/bzminer/bzminer/releases/download/v100.11/bzminer_custom-v100.11.tar.gz",
        "user_config": ""
      }
    }
  ]
}
```

Click **Import flight sheet**, paste the JSON and click **Import into form**:

- The miner name, the algorithm, the HiveOS install URL (as Linux download) and the
  extra arguments (`user_config`) are copied into the form.
- The pool part (`url`, `pass`, `template`, `coin`) becomes an entry in
  `userpools.config.txt` (a user pool, see [USERPOOLS.md](USERPOOLS.md)) when you keep
  the checkbox **Also create or update the pool as a userpool** ticked. `%WAL%` and
  `%WORKER_NAME%` in the wallet template are translated to RainbowMiner's `$Wallet` and
  `$WorkerName`; other placeholders (for example `%EMAIL%`) are asked from you during the
  import.

A flight sheet does not know anything about Windows. After the import:

1. Enter the **Windows URL** and the **Windows executable** (the HiveOS package is a
   Linux archive with HiveOS helper scripts; on a plain Linux rig the miner's normal Linux
   release is usually the better choice, so check the **Linux URL** as well).
2. Check the **Arguments**. The import proposes
   `-a %ALGO% -o %URL% -u %WAL% -p %PASS%`, which fits many miners, but every program has
   its own switches - look at the miner's help output.
3. Choose the **API** or leave `Wrapper`.
4. Save. Then open **Config > User Pools**: the imported pool is listed there, enter the
   wallet for the coin and, if you restrict pools with `PoolName`, use the hint on that
   page to add the pool name (see [USERPOOLS.md](USERPOOLS.md)).

**Export** works the other way around: the export button of a custom miner builds a
flight sheet from the definition and, optionally, one of your userpools.

## The fields

All values are strings in the JSON file, switches are `"1"` / `"0"`.

| Field | Meaning |
| --- | --- |
| `Enable` | `1` = the miner takes part, `0` = kept in the list but never started |
| `Comment` | free text |
| `ManualUri` | homepage of the miner, shown as link on the Miners page |
| `Version` | version of the binary, e.g. `1.2.3`. Changing it resets the benchmarks of this miner (the new build may be faster or slower). Changing only the download URL re-downloads and keeps the benchmarks |
| `Vendors` | comma separated device types: `NVIDIA`, `AMD`, `INTEL`, `CPU` |
| `Windows.Uri` / `Windows.Path` | download URL of the Windows build and the executable inside the archive (subfolders allowed, e.g. `bin\miner.exe`). A single top level folder in the archive is removed automatically. The URL may also point directly to an `.exe` |
| `Linux.Uri` / `Linux.Path` | the same for Linux (`.tar.gz`, `.tgz`, `.zip` or a single binary) |
| `API` | the miner API class RainbowMiner uses to read the hashrate, see [Reading the hashrate](#reading-the-hashrate). Default `Wrapper` |
| `HashRateRegex` | optional regular expression for the miner output, overrides `API` |
| `Port` | base port for the miner API. The port of the running miner is this value plus the index of its first device, use `$mport` in the arguments. Every custom miner needs its own base |
| `DevFee` | dev fee of the miner in percent, used for the profit calculation (may be overridden per algorithm) |
| `Arguments` | the command line template, see [Placeholders](#placeholders-for-the-command-line) |
| `SSLArguments` | appended to the command line when the pool uses SSL, e.g. `--tls` |
| `EnableSSL` | `0` = never use pools that require SSL |
| `DeviceIndexProperty` | which device number goes into `%DEVICES%`: `Type_Vendor_Index` (0,1,2.. per vendor, the usual choice), `Type_PlatformId_Index` (per OpenCL platform, some AMD miners), `Type_Index` (all GPUs), `Type_Mineable_Index`, `Vendor_Index`, `Index` (RainbowMiner's own device index), `BusId`, `PCIBusId` |
| `DeviceIndexHex` | `1` = write the device numbers as hex |
| `DeviceSeparator` | between the device numbers, default `,` |
| `EnvVars` | comma separated `NAME=VALUE` pairs set for the miner process |
| `ExcludePoolName` | regular expression; pools whose host matches are skipped |
| `ShowMinerWindow` | `1` = show the miner window (Windows; ignored when the hashrate is read from the output) |
| `ExtendInterval` | benchmark duration as multiple of `BenchmarkInterval`, default `2` |
| `Commands` | the list of algorithms, see below |

Each entry in `Commands`:

| Field | Meaning |
| --- | --- |
| `MainAlgorithm` | RainbowMiner's algorithm name, as shown on the Algorithms page (`KawPOW`, `RandomX`, `Ethash` ...). Spelling variants are normalized |
| `Algo` | the name the miner expects for this algorithm, inserted for `%ALGO%`. Empty = same as `MainAlgorithm` |
| `Params` | extra arguments for this algorithm only |
| `Fee` | dev fee in percent for this algorithm (empty = the miner's `DevFee`) |
| `MinMemGB` | minimum GPU memory in GB; smaller cards are left out |
| `DAG` | `1` = the algorithm has a growing DAG (Ethash, KawPOW, ...): the memory check uses the current DAG size of the coin |
| `ExtendInterval` | benchmark duration for this algorithm only |
| `Vendors` | subset of the miner's device types for this algorithm, e.g. `CPU` for an algorithm that the miner supports on CPU only. Empty = all |

Everything else - `Params` per device model, OC profiles, penalties, `Disable` - is
configured exactly like for the built-in miners, in `miners.config.txt` under the key
`<Name>-<DeviceModel>` (the entries are created at the next start of RainbowMiner).

## Placeholders for the command line

The arguments are a template. RainbowMiner fills the placeholders for every pool and
device model when it builds the miner list:

| Placeholder | Value |
| --- | --- |
| `%ALGO%` | the `Algo` (or `MainAlgorithm`) of the entry |
| `%URL%` | `host:port` of the pool |
| `%HOST%`, `%PORT%` | host and port separately |
| `%PROTOCOL%` | `stratum+tcp`, `stratum+ssl` or what the pool module reports |
| `%WAL%`, `%USER%` | the pool user, usually `wallet.workername` |
| `%WALLET%` | the plain wallet address |
| `%PASS%` | the pool password |
| `%WORKER_NAME%` | the worker name |
| `%COIN%` | the coin symbol of the pool, if known |
| `%ETHMODE%` | the ethash stratum mode reported by the pool (`ethproxy`, `ethstratum1`, ...) |
| `%DEVICES%` | the device numbers of the model, formatted with `DeviceIndexProperty`, `DeviceIndexHex` and `DeviceSeparator` |
| `%DEVCOUNT%` | number of devices |
| `%THREADS%` | CPU threads (from `miners.config.txt` or `CPUMiningThreads`) |
| `%AFFINITY%` | CPU affinity mask as configured, e.g. `0xff` |
| `%AFFINITY_LIST%` | the same as a list, e.g. `0,1,2,3,4,5,6,7` |
| `$mport` or `%MPORT%` | the API port of this miner instance |

Placeholders that RainbowMiner does not know stay in the command line unchanged, so a
program's own `%`-syntax is not disturbed.

Example: with

```
-a %ALGO% -o %PROTOCOL%://%URL% -u %WAL% -p %PASS% -d %DEVICES% --api-port $mport
```

a rig with two RTX 3070 mining KawPOW at 2Miners starts the miner as

```
-a kawpow -o stratum+tcp://rvn.2miners.com:6060 -u RVNWALLET.rig01 -p x -d 0,1 --api-port 4028
```

## Reading the hashrate

RainbowMiner needs the hashrate to benchmark and to watch the running miner. Three ways:

**Wrapper (default).** RainbowMiner reads the output of the miner and takes every value
followed by a unit like `H/s`, `kH/s`, `MH/s`, `GH/s`. Works for almost every miner that
prints its speed. Some miners print nothing when they are not attached to a terminal; a
`--no-color` or `--log` switch usually helps, and setting `ShowMinerWindow` has no effect
in this mode on Windows (the output has to be captured).

**Hashrate regex.** For miners whose output does not fit the generic parser, enter a
regular expression. RainbowMiner matches every output line against it (case insensitive):

- the named group `hashrate` (or `value`, or the first group) holds the number
- the named group `unit` (or the second group) holds the unit; `k`, `M`, `G`, `T`, `P`
  prefixes are applied, no unit means H/s
- the optional named groups `accepted` and `rejected` feed the share counters

Examples:

```
speed:\s*(?<hashrate>[\d.]+)\s*(?<unit>[kMG]?H/s)
Total\s+(?<hashrate>[\d.]+)\s*(?<unit>\w+/s).*acc=(?<accepted>\d+)\s+rej=(?<rejected>\d+)
```

**A miner API.** If the program is a build of a miner that RainbowMiner already knows,
pick its API from the list (`BzMiner`, `Trex`, `Xmrig6`, `Ccminer`, `Gminer`,
`Lol`, `Rigel`, `SrbMinerMulti`, ...). RainbowMiner then queries the miner's HTTP or TCP
API on the port passed with `$mport`, exactly like for the built-in module. Pass the port
the same way the built-in module does (look at `Miners\<Module>.ps1` for the switch).

## Worked example: BzMiner

BzMiner supports many coins, publishes Windows and Linux builds and has an HTTP API that
RainbowMiner already speaks. As a custom miner it looks like this in
`customminers.config.txt` (the form produces the same):

```json
{
  "MyBzMiner": {
    "Enable": "1",
    "Comment": "BzMiner as custom miner",
    "ManualUri": "https://github.com/bzminer/bzminer/releases",
    "Version": "100.11",
    "Vendors": "NVIDIA,AMD,CPU",
    "Windows": { "Uri": "https://github.com/bzminer/bzminer/releases/download/v100.11/bzminer_v100.11_windows.zip", "Path": "bzminer.exe" },
    "Linux":   { "Uri": "https://github.com/bzminer/bzminer/releases/download/v100.11/bzminer_v100.11_linux.tar.gz", "Path": "bzminer" },
    "API": "BzMiner",
    "HashRateRegex": "",
    "Port": "4014",
    "DevFee": "1.0",
    "Arguments": "-a %ALGO% -p %PROTOCOL%://%URL% -w %WAL% --pass %PASS% --http_address 127.0.0.1 --http_port $mport --no-watchdog --output log --no-color",
    "SSLArguments": "",
    "EnableSSL": "1",
    "DeviceIndexProperty": "Type_Vendor_Index",
    "DeviceIndexHex": "0",
    "DeviceSeparator": ",",
    "EnvVars": "",
    "ExcludePoolName": "",
    "ShowMinerWindow": "0",
    "ExtendInterval": "2",
    "Commands": [
      { "MainAlgorithm": "KawPOW",  "Algo": "kawpow",  "Params": "--nvidia 1 --amd 1 --cpu 0", "Fee": "1.0", "ExtendInterval": "", "MinMemGB": "3", "DAG": "1", "Vendors": "NVIDIA,AMD" },
      { "MainAlgorithm": "RandomX", "Algo": "randomx", "Params": "--nvidia 0 --amd 0 --cpu 1 --cpu_threads %THREADS%", "Fee": "1.0", "ExtendInterval": "", "MinMemGB": "", "DAG": "0", "Vendors": "CPU" }
    ]
  }
}
```

What happens after saving:

1. The next round lists `MyBzMiner` on the Miners page for every pool with KawPOW or
   RandomX. The binary is not there yet, so the downloader fetches the zip, unpacks it to
   `Bin\Custom-MyBzMiner` and writes `_uri.json` next to it.
2. The benchmark starts; the result lands in
   `Stats\Miners\NVIDIA-MyBzMiner-GPU#00_KawPOW_HashRate.txt` (and the CPU variant).
3. From then on the miner is switched to whenever it is the most profitable option.

The same definition, exported as a flight sheet together with a Pearl userpool, is the
JSON shown in the import section above.

## Tips and troubleshooting

- **The miner does not appear on the Miners page.** Check `Enable`, the device types
  (a CPU-only rig needs `CPU` in `Vendors`), and that the download fields for the rig's
  operating system are filled. A name that equals a built-in miner (`Trex`, `BzMiner`)
  or contains other characters than letters, digits and underscore is skipped with a
  warning in the log.
- **"not downloaded yet" never changes.** Look at the log for download errors. The URL
  has to be reachable without login and has to be an archive or a single executable.
- **The benchmark never finishes.** The hashrate is not read. Try the regex, check the
  miner's output in `Logs\<Name>-*.txt`, or pass the correct API port switch when using a
  miner API. A wrong API class fails silently.
- **Two miners fight for a port.** Give every custom miner its own `Port` base.
  `EnableAutoMinerPorts` in the setup lets RainbowMiner pick a free port automatically.
- **Benchmarks were reset.** You changed `Version`. That is intended: a new build gets new
  benchmarks.
- **Per-model tuning.** Use `miners.config.txt` (Config > JSON Editor, or the console
  setup) with the key `<Name>-<DeviceModel>`, the entries appear after the next start.
- **Client/Server.** `customminers` is one of the config files a client can pull from
  the server (`ServerConfigName`). On such a client the Custom Miners page is read-only.
  A per-worker file `Config\<workername>\customminers.config.txt` on the server overrides
  the shared one. Binaries are always downloaded from the URL in the definition.
- **Deleting a miner** removes the definition only. `Bin\Custom-<Name>` and the benchmark
  files stay until you delete them (benchmarks of unknown miners are purged after seven
  days).
- **Dual mining** is not supported for custom miners in this version.
