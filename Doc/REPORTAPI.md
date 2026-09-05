# Report API

If `EnableMinerStatus` is switched on, every rig sends a status report to the server in
`MinerStatusURL` once per round. That is how [rbminer.net](https://rbminer.net) knows what
your rigs are doing, and it is also the hook for your own monitoring: point `MinerStatusURL`
at a script of your own and you receive the very same data.

    "EnableMinerStatus": "1",
    "MinerStatusURL": "https://rbminer.net",
    "MinerStatusKey": "<your key>",

Contents

1. [How a report is sent](#how-a-report-is-sent)
2. [The report body](#the-report-body)
3. [The data array](#the-data-array)
4. [The extra payloads](#the-extra-payloads)
5. [What the server may answer](#what-the-server-may-answer)
6. [Pointing a rig at your own server](#pointing-a-rig-at-your-own-server)

## How a report is sent

The report is a HTTP POST with a form encoded body. The URL that is actually called is not
`MinerStatusURL` itself, but the API url that belongs to it: `Data\reportapi.json` maps a
`match` (a substring of `MinerStatusURL`) to the `apiurl` that receives the POST. For
rbminer.net that is `https://api.rbminer.net/report.php`. If nothing matches, that same
rbminer.net entry is used as the fallback.

One report is sent per round, so the interval follows `Interval` (or `BenchmarkInterval`
during benchmarks) - the value is in the `interval` field, so the receiving side knows when
to expect the next one.

## The report body

| Field | Content |
| ---------------- | ------------------------------------------------------------------------------------- |
| `user`           | your `MinerStatusKey` - this identifies the account, not the rig                        |
| `worker`         | the rig's `WorkerName`                                                                  |
| `machinename`    | the machine's system name                                                               |
| `machineip`      | the machine's local IP address                                                          |
| `version`        | e.g. `RainbowMiner 5.0.2.8`                                                             |
| `psversion`      | the PowerShell version the rig is running on                                            |
| `status`         | `Running`, `Paused` or `Waiting` (waiting for profitability)                             |
| `runmode`        | `0` = standalone, `1` = server, `2` = client                                            |
| `shrm`           | the `ShowRemoteMachines` setting                                                        |
| `interval`       | the current round interval in seconds                                                   |
| `uptime`         | uptime of RainbowMiner in seconds                                                       |
| `sysuptime`      | uptime of the machine in seconds                                                        |
| `memusage`       | memory usage of the RainbowMiner process in bytes                                       |
| `profit`         | current profit in BTC per day, summed over all running miners                            |
| `powerdraw`      | current power draw in Watt, summed over all running miners                               |
| `earnings_avg`   | live moving average of the earnings per day                                             |
| `earnings_1d`    | one day moving average of the earnings per day                                          |
| `rates`          | JSON object with the conversion rates of your `Currency` list (refreshed every 30 min)   |
| `cpu`            | name of the machine's CPU                                                               |
| `cpuload`        | current CPU load in percent                                                             |
| `cputemp`        | average CPU temperature                                                                 |
| `cpupower`       | current CPU power draw (needs the PawnIO driver on Windows, see the README)              |
| `maxtemp`        | the configured `MinerStatusMaxTemp`                                                      |
| `tempalert`      | number of GPUs currently above `MinerStatusMaxTemp`                                      |
| `maxcrashes`     | the configured `MinerStatusMaxCrashesPerHour`                                            |
| `crashalert`     | number of crashes in the past hour, but only if it exceeds `maxcrashes` - otherwise `0`  |
| `crashdata`      | JSON array with one record per crash of the past hour (see below)                        |
| `diskmingbalert` | JSON array of the disks that have less free space than `DiskMinGB`                       |
| `uncleanalert`   | `true` if the previous run of RainbowMiner ended unclean                                 |
| `email`          | your `MinerStatusEmail`, if set                                                          |
| `pushoverkey`    | your `PushOverUserKey`, if set                                                           |
| `console`        | the current `Logs\console.txt`, so the server can show the rig's console                 |
| `devices`        | JSON with all device data - sent once a day, empty otherwise                             |
| `pool_totals`    | JSON with the totals per pool - sent every three hours, empty otherwise                  |
| `data`           | JSON array with one record per running miner (see below)                                 |

A `crashdata` record holds `Timestamp`, `Start`, `End`, `Runtime`, `Name` (the miner),
`Device`, `Algorithm` and `Pool`.

## The data array

One record per miner that is currently running:

| Field | Content |
| ---------------- | ------------------------------------------------------------------------------------- |
| `Name`           | the miner's name                                                                        |
| `Version`        | the miner's version                                                                     |
| `Path`           | path to the miner binary, relative to the RainbowMiner folder                            |
| `Type`           | array of device model names                                                             |
| `Active`         | runtime of the miner, as `00 Days 01 Hours 23 Minutes`                                   |
| `Algorithm`      | array of algorithms *                                                                   |
| `Currency`       | the payout currency (or the coin symbol, if the pool does not auto-exchange)             |
| `CoinName`       | array of the mined coins' names *                                                        |
| `CoinSymbol`     | array of the mined coins' symbols *                                                      |
| `Pool`           | array of pools *                                                                         |
| `BLK`            | array with the blocks found per day at that pool *                                       |
| `CurrentSpeed`   | array with the live hashrate in H/s *                                                    |
| `EstimatedSpeed` | array with the benchmarked hashrate in H/s *                                             |
| `Accepted`       | array with the number of accepted shares *                                               |
| `Rejected`       | array with the number of rejected shares *                                               |
| `Stale`          | array with the number of stale shares *                                                  |
| `PowerDraw`      | current power draw in Watt                                                               |
| `BTC/day`        | current profit per day in BTC                                                            |
| `Profit`         | current profit per day                                                                   |
| `Donator`        | `true` while this miner mines the developer fee                                          |
| `Benchmarking`   | `true` while this miner is benchmarking                                                  |
| `Devices`        | array of the devices this miner uses                                                     |

\* two entries when dual mining, one otherwise.

A `Devices` record holds `Id` (internal device number), `Name` (model name), `Watt` and
`Temp`; for GPUs also `Mem` (board memory in GB), `Fan` (in percent), `Core` and `MemC`
(current core and memory clock) and `MaxTemp` (highest temperature seen during the run).

## The extra payloads

Two bigger data sets are not part of the round report - they are POSTed separately, with
only `user`, `worker`, `version` and the payload itself, and only when they have been
rebuilt:

- `minerdata` - the benchmark results of this rig (miner, version, algorithm, device,
  hashrate, power draw, OC profile) plus the OC profiles and the CPU name. Rebuilt every six
  hours, but never while the rig is benchmarking.
- `poolsdata` - name, algorithm, coin symbol, price, stable price, penalty factor and error
  ratio of every pool the rig has seen. Rebuilt every six hours.

Both are only sent from a rig that runs PowerShell 7 or has `EnableCurl` switched on, since
they are uploaded as files.

## What the server may answer

The answer is evaluated, so a monitoring server can talk back. All of it is optional:

- `Status` - a status string, written to the log
- `Actions` - an array of actions to execute on the rig. Supported are
  `resetfailedbenchmarks` (re-benchmark everything that ended with a zero hashrate) and
  `resetneededbenchmarks` (re-benchmark everything that is waiting for a benchmark)
- `Workers` - the other rigs of the same account. RainbowMiner shows them on the dashboard
  as remote workers and adds up their profit and earnings (this is what `ShowRemoteMachines`
  switches on)
- `Compare` - comparison data, shown in the web interface
- `IP` - the rig's external IP address, shown in the web interface

## Pointing a rig at your own server

Set `MinerStatusURL` to your own url and give it a `MinerStatusKey` of your choice - the key
is passed through as `user` and is what separates several rigs of one account from each
other. Your script receives the POST described above and may answer with an empty body; only
if you want the extra features do you need to answer with the JSON fields above.

If your url does not contain `rbminer.net`, add an entry to `Data\reportapi.json` so that
RainbowMiner knows which url to POST to:

    [
        {
            "match":  "myserver.example.com",
            "apiurl":  "https://myserver.example.com/report.php",
            "web":  "https://myserver.example.com",
            "desc":  "my own monitoring"
        }
    ]

Note that `Data\reportapi.json` ships with RainbowMiner and is overwritten by an update, so
keep a copy of your entry.
