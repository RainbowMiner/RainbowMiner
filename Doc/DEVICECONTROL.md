# Device Control

A mining rig produces heat, and how much of it you want depends on things RainbowMiner
cannot see: the temperature in the garage, the sun on the roof, whether anyone is sleeping
next door. Device control closes that gap. Your home automation decides how many GPUs
should run, sends one HTTP call, and RainbowMiner switches to that selection at the start
of the next round - a second later when it is waiting, at the end of the current round when it
is busy - without restarting, without touching your config.

The two commands are `/setdevices`, which sets the devices to mine on, and `/getdevices`,
which reports what is configured, what is running and which override is active. The
override lives in memory only: `Config\config.txt` is never written, so there is no config
churn and no edit to undo, and a restart of RainbowMiner always returns to the selection
you configured.

Contents

1. [Quick start](#quick-start)
2. [How the override works](#how-the-override-works)
3. [The commands](#the-commands)
4. [Device selectors](#device-selectors)
5. [Worked example: Home Assistant](#worked-example-home-assistant)
6. [Tips and troubleshooting](#tips-and-troubleshooting)

## Quick start

1. Open the web interface at [localhost:4000](http://localhost:4000) and click
   **Config > Setup**, section **Basic Setup**, to check that the devices you want to
   choose from are enabled under **DeviceName**. Device control can only ever select from
   this list - it never switches on a device you excluded.
2. Ask the rig what it has:

   ```
   curl http://localhost:4000/getdevices
   ```

   The **Available** list is what you can address, each entry with the **Selector** to
   address it by.
3. Run on three GPUs:

   ```
   curl "http://localhost:4000/setdevices?count=3"
   ```

   The console logs `Device selection changed via API` as soon as RainbowMiner is in its
   waiting phase, then `Device configuration changed. Refreshing now.` at the start of the
   next round; miners on the dropped GPUs stop, and
   the Devices page shows three cards.
4. Go back to the configured selection:

   ```
   curl "http://localhost:4000/setdevices?reset=1"
   ```

## How the override works

- **It never writes config.txt.** The selection you set is held in memory. This is what
  makes it safe to call on every temperature change - a config write would rewrite the
  file, trigger a full config reload and fill your log, several times an hour.
- **It survives a locked config.** `APIlockConfig` blocks `/saveconfig`, but not
  `/setdevices`, because no file is written.
- **It is volatile.** Stopping RainbowMiner, an auto-update, or a restart clears the
  override and returns to `config.txt`. Have your automation re-send the command when the
  rig comes back, or simply on a timer.
- **It applies at the start of the next round.** If RainbowMiner is in its waiting phase,
  the command ends that phase immediately and the delay is about a second. If a round is
  busy (loading pools, updating balances, starting miners - typically 20-60 seconds), the
  command is picked up when that round ends. It never waits a full `Interval`.
- **Miners are not bounced.** Miners on devices that drop out are stopped; miners on
  devices you kept keep running unless the profit switching decides otherwise.
- **Every distinct device set has its own statistics, seeded from its siblings.** A miner
  instance is named after the devices it runs on, so `GPU#00-GPU#01-GPU#02` and
  `GPU#00-...-GPU#05` keep separate hashrate statistics, and a 3-GPU run never distorts
  the 6-GPU numbers. A set that has no statistics yet does not benchmark from scratch:
  when any other set of the same GPU model has been benchmarked, RainbowMiner seeds the
  new set with that hashrate and power scaled per device (`Seeded benchmark ...` in the
  log) and starts mining right away. The seed is replaced by the first live measurement,
  and if it was far off it is reset after three rejected samples - the same treatment a
  fastlane benchmark gets. Only the very first set benchmarks the classic way. Still keep
  the number of distinct sets small: `count` always keeps the *first* N GPUs, so a rule
  with three steps produces exactly three sets.
- **Linux re-runs the overclocking init on every switch.** With `EnableOCProfiles` the
  device refresh calls `nvidia-smi -pm 1`, the PowerMizer setting and `oc_init.sh` again,
  exactly as a change of `DeviceName` in `config.txt` does. Harmless, but a rule that flips
  every few minutes will show it in the log - give your automation some hysteresis.
- **The Setup page and the console setup edit config.txt, not the override.** Saving there
  updates the configured selection underneath a running override; the override stays
  active until you reset it.
- **It narrows your configured selection.** `count` picks from the devices configured in
  `DeviceName`/`ExcludeDeviceName`, so a GPU you excluded in the setup stays excluded.
- **`count=0` stops the GPUs, not the CPU.** On a rig that also mines on the CPU, the CPU
  keeps going - that is the point of leaving the CPU part alone. To stop everything, either
  configure GPUs only, or send `devicename` with a selector that matches nothing.
- **Selecting nothing at all pauses the rig.** The status line then reads
  `PAUSED BY DEVICE SELECTION (call /setdevices?reset=1 to resume)`, and `/status` reports
  `"Pause": true`. Note that pressing **[P]** on the console does *not* resume from this
  state - send the reset.

## The commands

### /getdevices

Takes no parameters and changes nothing.

```json
{
  "Available": [
    {"Name":"GPU#00","Selector":"GPU#00","Type":"Gpu","Model":"GTX1070","Model_Name":"GeForce GTX 1070"},
    {"Name":"GPU#01","Selector":"GPU#01","Type":"Gpu","Model":"GTX1070","Model_Name":"GeForce GTX 1070"},
    {"Name":"CPU#00","Selector":"CPU#00","Type":"Cpu","Model":"CPU","Model_Name":"AMD Ryzen 5 3600"}
  ],
  "Active": ["GPU#00","GPU#01"],
  "Override": {"DeviceName":["GPU#00","GPU#01"],"ExcludeDeviceName":[],"Count":2,"Since":"09/21/2026 10:14:02","Source":"10.0.0.5"}
}
```

- **Available** - the selection from `config.txt`, i.e. every device you may address.
- **Active** - the devices actually being mined on right now.
- **Override** - `null` when none is set, otherwise the override with the time it was set
  and the IP that set it.

### /setdevices

Call it with a query string (GET) or as a form POST. Exactly one of the following three
parameters is used, checked in this order:

- **reset=1** - drop the override and return to `config.txt`.
- **count=N** - keep the first `N` GPUs of **Available**, in the order that `/getdevices`
  lists them, whatever their model. The CPU part of your configured selection is left
  alone, so a rig that mines on CPU and GPU keeps mining on the CPU. `N` larger than the
  number of configured GPUs is clamped, and the clamp is reported in `Warnings`. `N=0`
  selects no GPU.
- **count=GROUP:N,GROUP:N** - the same per device group, e.g. `count=GTX1070:2,RTX3070:1`
  on a rig with four 1070s and two 3070s. A group is the `Model` that `/getdevices` shows;
  a group name from `gpugroups.config.txt` such as `GTX1070A` works too, and case does not
  matter. Groups you do not name keep all their configured GPUs, so `count=RTX3070:0`
  parks the 3070s and leaves everything else running. An unknown name is rejected together
  with the list of valid groups; `Count` in the answer echoes the applied list.
- **devicename=LIST** - a comma or semicolon separated list of device selectors, used
  verbatim. Optionally combined with **excludedevicename=LIST**; when that is omitted, the
  excludes from `config.txt` are kept. Use this when *which* GPUs matters, e.g. to keep the
  two that sit in front of the fan.

On success:

```json
{"Success":true,"DeviceName":["GPU#00","GPU#01","GPU#02"],"ExcludeDeviceName":[],
 "Count":3,"Available":6,"Pending":true,"Warnings":[]}
```

`Pending` is always `true` - it means the selection is accepted and will be live at the
start of the next round. `/getdevices` shows the new `Override` immediately and the new
`Active` list once the round has switched.

On failure the call still answers with HTTP 200, and the body says what was wrong:

```json
{"Success":false,"Error":"Please call with one of the parameters count, devicename or reset."}
```

## Device selectors

Use the **Selector** field from `/getdevices` and you cannot go wrong. If you write them by
hand, these are the forms RainbowMiner understands, the same ones that `DeviceName` in
`config.txt` accepts:

| Selector | Meaning |
| --- | --- |
| `GPU` | all GPUs |
| `CPU` | the CPU |
| `NVIDIA`, `AMD`, `INTEL` | all GPUs of that vendor |
| `GPU#02` | the third GPU, counted across all devices |
| `NVIDIA#01` | the second Nvidia GPU |
| `CPU#00` | the first CPU |
| `GTX1070` | every GPU of that model |

Be aware that `GPU#nn` counts through all devices while `NVIDIA#nn` counts only the Nvidia
cards, so the two numberings can differ on a mixed rig. That is exactly why `/getdevices`
hands you a selector per device - take it from there instead of counting yourself.

## Worked example: Home Assistant

This is the setup the feature was built for: a rig in a garage, and fewer GPUs running as
the garage gets warmer.

First make the rig reachable. In **Config > Setup**, section **API**, set:

- **RemoteAPI** = `1`, so the API listens on the network and not only on localhost.
- **APIauth** = `1`, plus **APIuser** and **APIpassword**.
- **APIallowIPs** = the address of your Home Assistant host, e.g. `10.0.0.5`.

On Windows, `RemoteAPI` needs the firewall rule and URL reservation that RainbowMiner
creates when it runs as administrator once. Then restart RainbowMiner and check from the
Home Assistant host that `curl -u user:pass http://10.0.0.50:4000/getdevices` answers.

Now add the command to `configuration.yaml`:

```yaml
rest_command:
  rbm_setdevices:
    url: "http://10.0.0.50:4000/setdevices?count={{ count }}"
    method: get
    username: !secret rbm_user
    password: !secret rbm_password
```

And the automation that implements the rule "over 38 C run 3 GPUs, between 30 and 38 C run
4, below 30 C run all 6":

```yaml
automation:
  - alias: "Mining GPUs by garage temperature"
    trigger:
      - platform: state
        entity_id: sensor.garage_temperature
      - platform: homeassistant
        event: start
      - platform: time_pattern
        minutes: "/15"
    action:
      - service: rest_command.rbm_setdevices
        data:
          count: >
            {% set t = states('sensor.garage_temperature') | float(0) %}
            {% if t >= 38 %}3{% elif t >= 30 %}4{% else %}6{% endif %}
```

A few things worth copying from this example:

- The `homeassistant / start` and `time_pattern` triggers re-send the current state
  regularly. The override is volatile, so after a restart of RainbowMiner the rig runs on
  the configured selection until the next command arrives.
- `float(0)` guards against the sensor being `unavailable`, which would otherwise render an
  empty `count` and get the call rejected.
- The automation sends the same count repeatedly. That is harmless: an unchanged selection
  costs nothing, because RainbowMiner only refreshes its devices when the selection
  actually differs.

To read the state back into Home Assistant, add a sensor:

```yaml
sensor:
  - platform: rest
    name: "RainbowMiner active GPUs"
    resource: "http://10.0.0.50:4000/getdevices"
    username: !secret rbm_user
    password: !secret rbm_password
    value_template: "{{ value_json.Active | reject('search','CPU') | list | count }}"
    scan_interval: 60
```

## Tips and troubleshooting

**Nothing happens and the answer says `Device detection has not finished yet`.** The
command needs the first round to have completed, so that RainbowMiner knows its devices.
Wait for the miner list to appear and try again.

**The rig pauses with `PAUSED BY DEVICE SELECTION`.** The selection resolved to no device
at all - usually a typo in `devicename`, which is taken verbatim and simply matches
nothing. Send `/setdevices?reset=1`; `/getdevices` shows the selectors that work.

**The API blocks after a few calls.** `APImaxLoginAttemps` (default 3) blocks an IP for
`APIblockLoginAttemptsTime` (default 30 minutes) after failed logins, and every
unauthenticated request counts. A wrong password in Home Assistant will therefore lock your
rig's API out for half an hour. Fix the credentials, then wait out the block or restart
RainbowMiner.

**The Setup page shows my configured devices, not the override.** That is intentional. The
setup form writes its checkboxes back into `config.txt`, so it always shows what is
configured - otherwise pressing Save while an override was active would make the override
permanent. `/getdevices` is the place to look at what is running.

**After sending a new count, everything benchmarks.** That only happens when no set of
that GPU model has been benchmarked yet; otherwise the new set is seeded from a sibling
(see above) and mines immediately. Check the log for `Seeded benchmark` lines. Resetting a
benchmark of a subset with the Reset buttons is answered by a seed as well, which the
first live sample then replaces - effectively a one-round benchmark.

**I want the change to survive a restart.** Then it is not an override but a setting: open
**Config > Setup** and change **DeviceName**, or let your automation call `/saveconfig`.
Device control is deliberately the volatile half of that pair.

**Can I switch algorithms or pools this way too?** Not with this command. For time-based
changes of algorithm, pool or pause state, use `Config\scheduler.config.txt`, described in
[CONFIG.md](CONFIG.md).

**Related documentation.** The full API is listed on the **API** page of the web interface;
the device selection syntax is documented with `DeviceName` in [CONFIG.md](CONFIG.md);
splitting one GPU model into named groups is described in the `gpugroups.config.txt`
section of the [README](../README.md).
