# RainbowMiner in Docker

RainbowMiner was written for bare metal, but it runs in a container once three things are
taken care of that a normal rig gets for free: the GPU runtime has to be inside the image,
the configuration has to exist before the first unattended start, and the stop signal of
the container has to reach RainbowMiner. This page shows one working layout for each of
them. Treat the files as a template: the RainbowMiner parts are verified, the GPU runtime
lines follow the vendor documentation and change with every driver generation, so check
them against the current ROCm or NVIDIA container pages before you copy them.

What does not work in a container: overclocking. The `ocdaemon` service needs systemd,
which a container does not have, and the GPU clocks belong to the host anyway. Keep
`EnableOCProfiles` off and do the overclocking on the host.

Contents

1. [The Dockerfiles](#the-dockerfiles)
   - [AMD](#amd)
   - [NVIDIA](#nvidia)
   - [AMD and NVIDIA in one image](#amd-and-nvidia-in-one-image)
   - [CPU only](#cpu-only)
2. [The entrypoint](#the-entrypoint)
3. [The compose file](#the-compose-file)
4. [First start](#first-start)
5. [Stopping the container](#stopping-the-container)
6. [What to persist](#what-to-persist)
7. [Troubleshooting](#troubleshooting)

## The Dockerfiles

All variants share the same skeleton: Ubuntu 24.04 as the base, because AMD does not
ship ROCm packages for newer Ubuntu releases yet and the miner binaries are built against
the glibc of the LTS releases; the packages `install.sh` cannot install itself; the latest
RainbowMiner release unpacked to `/RainbowMiner`; and the entrypoint from the next
section. Only the GPU runtime differs.

Four things apply to all of them:

- `install.sh` installs PowerShell and the packages the miners need. It also tries to
  install the `ocdaemon` service and complains that systemd is missing. That is expected
  in a container and harmless.
- `install.sh` calls `apt-get install` for the miner libraries (`libjansson4`, `libnuma1`,
  `libuv1`, `libomp`, ...) and for `tmux` and `screen`, but never `apt-get update`. The
  Ubuntu base image ships without package lists, so the `apt-get update` in front of
  `install.sh` is not optional: without it every one of these installs fails silently and
  the miners die at start with "error while loading shared libraries". The lists are
  removed again at the end of the same step to keep the image small.
- `procps` is in the package list because the base image has no `ps` and `pgrep`, which
  RainbowMiner's shutdown and the miner guard use.
- No GPU is visible while an image is built, so everything that depends on hardware
  detection has to be forced. That is why the NVIDIA variants call `install.sh -nv`: the
  CUDA runtime libraries the miners link against are only fetched when `install.sh` sees
  an NVIDIA card, and at build time it sees none.
- The `ENTRYPOINT` uses the exec form (the JSON array). The shell form would put `sh -c`
  at PID 1, and a PID 1 without a signal handler ignores the stop signal of the container.

### AMD

The miners need the ROCm OpenCL runtime. The kernel module stays on the host, the
container only needs the user-space part, which `amdgpu-install` installs with
`--no-dkms`.

    FROM ubuntu:24.04

    ENV DEBIAN_FRONTEND=noninteractive
    RUN apt-get update && apt-get install -y --no-install-recommends \
            ca-certificates curl wget unzip xz-utils pciutils procps libicu74 \
            ocl-icd-libopencl1 clinfo \
        && rm -rf /var/lib/apt/lists/*

    # the file name is the one listed at https://repo.radeon.com/amdgpu-install/latest/ubuntu/noble/
    # (7.2.4 in October 2026); older cards may need an older version from the parent directory
    RUN wget -q https://repo.radeon.com/amdgpu-install/latest/ubuntu/noble/amdgpu-install_7.2.4.70204-1_all.deb \
        && apt-get update && apt-get install -y ./amdgpu-install_7.2.4.70204-1_all.deb \
        && amdgpu-install -y --usecase=opencl --no-dkms --no-32 \
        && rm -f amdgpu-install_*.deb && rm -rf /var/lib/apt/lists/*

    RUN apt-get update && mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh \
        && rm -rf /var/lib/apt/lists/*

    COPY entrypoint.sh /entrypoint.sh
    ENTRYPOINT ["bash", "/entrypoint.sh"]

Do not install `mesa-opencl-icd`. Mesa's Rusticl reports the card as an AMD device, so
RainbowMiner detects it and starts the AMD miners, but none of them runs on Rusticl. The
result is an endless "All miners crashed" loop. If both runtimes are installed, the card
shows up twice.

On the host the `amdgpu` kernel module has to be loaded, nothing else. The container gets
the card through `/dev/kfd` (compute) and `/dev/dri` (render nodes), both are needed, see
the compose file.

### NVIDIA

The image stays driver-free. The driver, `libcuda` and `nvidia-smi` are mounted into the
container at start by the NVIDIA Container Toolkit, which has to be installed on the host:

    # on the host, once (Ubuntu/Debian, see the toolkit's install guide for other distributions)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

The Dockerfile:

    FROM ubuntu:24.04

    ENV DEBIAN_FRONTEND=noninteractive
    RUN apt-get update && apt-get install -y --no-install-recommends \
            ca-certificates curl wget unzip xz-utils pciutils procps libicu74 \
            ocl-icd-libopencl1 clinfo \
        && rm -rf /var/lib/apt/lists/*

    # what the NVIDIA Container Toolkit mounts at start: compute = CUDA, utility = nvidia-smi and NVML
    ENV NVIDIA_VISIBLE_DEVICES=all
    ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

    # -nv fetches the CUDA runtime bundles (one per CUDA generation) into /opt/rainbowminer/lib
    RUN apt-get update && mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh -nv \
        && rm -rf /var/lib/apt/lists/*

    COPY entrypoint.sh /entrypoint.sh
    ENTRYPOINT ["bash", "/entrypoint.sh"]

`utility` is not optional. Without it `nvidia-smi` and the NVML library are missing inside
the container, RainbowMiner cannot read temperature, power and fan of the cards, and the
miners that monitor through NVML complain or refuse to start.

The host driver has to be at least as new as the newest CUDA library bundle the miners use,
that is the same rule as on a bare metal rig: a miner built for CUDA 12.8 needs a 570 series
driver or newer on the host.

### AMD and NVIDIA in one image

A mixed rig gets both runtimes: the ROCm OpenCL part from the AMD image and the
environment plus `install.sh -nv` from the NVIDIA image. The two do not interfere, the
ROCm runtime only registers an AMD OpenCL platform, and the NVIDIA toolkit only mounts the
NVIDIA libraries.

    FROM ubuntu:24.04

    ENV DEBIAN_FRONTEND=noninteractive
    RUN apt-get update && apt-get install -y --no-install-recommends \
            ca-certificates curl wget unzip xz-utils pciutils procps libicu74 \
            ocl-icd-libopencl1 clinfo \
        && rm -rf /var/lib/apt/lists/*

    # AMD: the ROCm OpenCL runtime
    RUN wget -q https://repo.radeon.com/amdgpu-install/latest/ubuntu/noble/amdgpu-install_7.2.4.70204-1_all.deb \
        && apt-get update && apt-get install -y ./amdgpu-install_7.2.4.70204-1_all.deb \
        && amdgpu-install -y --usecase=opencl --no-dkms --no-32 \
        && rm -f amdgpu-install_*.deb && rm -rf /var/lib/apt/lists/*

    # NVIDIA: what the container toolkit mounts at start
    ENV NVIDIA_VISIBLE_DEVICES=all
    ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

    RUN apt-get update && mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh -nv \
        && rm -rf /var/lib/apt/lists/*

    COPY entrypoint.sh /entrypoint.sh
    ENTRYPOINT ["bash", "/entrypoint.sh"]

The compose file for the mixed image needs both vendor blocks: the NVIDIA runtime and the
AMD device passthrough combine without conflict.

### CPU only

A CPU rig needs no GPU runtime, the skeleton alone is the image. `install.sh` sees no
NVIDIA card and skips the CUDA bundles on its own, and `clinfo` and the OpenCL loader can
stay out.

    FROM ubuntu:24.04

    ENV DEBIAN_FRONTEND=noninteractive
    RUN apt-get update && apt-get install -y --no-install-recommends \
            ca-certificates curl wget unzip xz-utils pciutils procps libicu74 \
        && rm -rf /var/lib/apt/lists/*

    RUN apt-get update && mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh \
        && rm -rf /var/lib/apt/lists/*

    COPY entrypoint.sh /entrypoint.sh
    ENTRYPOINT ["bash", "/entrypoint.sh"]

The compose file gets neither vendor block. Instead, pin the container to the cores it may
use:

        cpuset: "0-7"

RainbowMiner reads the cpuset of its own process and offers the miners only those cores,
so `CPUMiningThreads` and `CPUMiningAffinity` in `config.txt` can stay at their defaults.
`cpus: 8` (a CFS quota) works too, but it throttles instead of pinning, which costs
hashrate on RandomX. In the setup wizard answer `CPU` for the devices (`DeviceName = CPU`
in `config.txt`), nothing else is CPU specific.

RandomX miners run noticeably faster with huge pages and the MSR mod, both are host
matters:

- huge pages: reserve them on the host, e.g. `sysctl -w vm.nr_hugepages=1280` (xmrig's
  recommendation, 2.5 GB), the container sees them without further flags. 1 GB pages
  (`EnableRandomX1GBPages`) need `hugepagesz=1G hugepages=<n>` on the host's kernel
  command line.
- MSR mod: the miner writes the registers itself when it can reach `/dev/cpu/*/msr`, which
  needs the `msr` module loaded on the host and `privileged: true` in the compose file.
  Without it the miner prints a warning and runs 5-15% slower.

## The entrypoint

RainbowMiner does not handle SIGTERM itself, the signal ends PowerShell without a clean
shutdown. The container's stop signal therefore gets translated into the file that
`stopp.sh` writes: RainbowMiner picks it up at its next loop iteration, stops the miners,
and exits with code 0, which ends the loop in `start.sh`.

    #!/bin/bash
    # /entrypoint.sh
    cd /RainbowMiner
    bash start.sh &
    child=$!

    # RainbowMiner deletes a stop file it finds while it is still starting up, so one write
    # is not enough: keep writing it until the loop has seen it and the process is gone
    stopped=
    stop() {
      stopped=1
      while kill -0 $child 2>/dev/null; do
        echo adios > /RainbowMiner/stopp.txt
        sleep 1
      done
    }
    trap stop TERM INT

    # the signal makes the first wait return early (status > 128), so wait once more for
    # the real exit code of RainbowMiner
    wait $child; rc=$?
    [ -n "$stopped" ] && { wait $child; rc=$?; }
    exit $rc

A `trap` installed in PID 1 counts as a signal handler, so bash receives the SIGTERM here
even without `init: true`. The loop in `stop` is what makes `docker compose restart` and a
`stop` right after `up` work: a `docker compose stop` that arrives during the first 15 to
30 seconds of a start hits RainbowMiner's startup phase, which removes a stale stop file,
and with a single write the container would run into the grace period and be killed. The
loop's last write lands after RainbowMiner has cleaned up, so a `stopp.txt` left in the
container is normal, the next start removes it.

## The compose file

    services:
      rainbowminer:
        container_name: rainbowminer
        build:
          dockerfile: Dockerfile
        restart: unless-stopped
        stop_grace_period: 60s
        ports:
          - 4000:4000
        volumes:
          - ./Config:/RainbowMiner/Config
          - ./Stats:/RainbowMiner/Stats
          - ./Bin:/RainbowMiner/Bin
          - ./Logs:/RainbowMiner/Logs

        # --- AMD ---
        devices:
          - /dev/kfd
          - /dev/dri
        security_opt:
          - seccomp=unconfined

        # --- NVIDIA (needs the NVIDIA Container Toolkit on the host) ---
        runtime: nvidia
        environment:
          - NVIDIA_VISIBLE_DEVICES=all
          - NVIDIA_DRIVER_CAPABILITIES=compute,utility

Keep the vendor block that matches the image, delete the other, keep both for the mixed
image. For NVIDIA the `environment` lines repeat what the Dockerfile already sets, they
are there so that a compose file with an image from elsewhere works as well. The newer
`deploy.resources.reservations.devices` syntax with `driver: nvidia` and
`capabilities: [gpu]` does the same as `runtime: nvidia`.

ROCm's own examples add `--group-add video --group-add render`. That is for containers
running as a user: Docker resolves the names in the image's `/etc/group`, and the image has
no `render` group, so the container is not even created ("Unable to find group render").
This container runs as root, which opens the device nodes regardless of their group. If
you do run it as a user, put the host's numeric GIDs under `group_add`
(`getent group video render | cut -d: -f3`).

`stop_grace_period` matters. Docker's default of 10 seconds is not enough for a clean stop:
the stop file is polled once per second while RainbowMiner waits, but not while it fetches
pools or starts miners at the beginning of a round, not during its startup, and stopping
the miners takes a few seconds on its own. With the default, Docker kills the container
before the shutdown is through.

`restart: unless-stopped` restarts the container after every exit that was not a
`docker stop`, a clean exit with code 0 included. That is what a rig wants after a host
reboot or a crash, but it also means that the web interface's stop button and `stopp.sh`
do not stop the container, they restart RainbowMiner (see
[Stopping the container](#stopping-the-container)). `restart: on-failure` only restarts
after a non-zero exit, so a stop from inside stays a stop, but the container then does not
come back after a host reboot.

If the host runs the AMD container runtime, `runtime: amd` together with `gpus: all`
replaces the `devices` lines. Either way, `clinfo` inside the container
has to list an AMD platform.

## First start

The first start of RainbowMiner opens the setup wizard, which needs a terminal. A detached
container has none, so do the setup once interactively:

    docker compose build
    docker compose run --rm --entrypoint bash rainbowminer /RainbowMiner/setup.sh
    docker compose up -d

`setup.sh` writes `Config/config.txt` and the pool configuration into the mounted `Config`
folder, where every later start finds them. The alternative is to copy a `Config` folder
from an existing rig into place before the first `up`; `chown -R root:root Config` after
the copy, see the read-only entry in [Troubleshooting](#troubleshooting).

The web interface is reachable at `http://<host>:4000` as usual.

## Stopping the container

`docker compose stop` or `docker compose down` send SIGTERM to the entrypoint, the
entrypoint writes the stop file, RainbowMiner stops the miners and exits, the container
ends. Measured on a CPU container: 3 seconds when RainbowMiner was waiting for the next
round, 18 seconds when the stop arrived 3 seconds after the start. Expect up to about a
minute when it hits the pool and miner loading at the beginning of a round.

Without the entrypoint, or with a shell-form `ENTRYPOINT`, nothing happens on SIGTERM and
Docker kills the container with SIGKILL after the grace period. The kernel then ends every
process in the container at once, miners included, so nothing keeps running, but the
shutdown is not clean: the pool never sees the miners leave, and `Data/rbm.pid` survives
in the container layer, so the next start reports "Checking last shutdown .. crashed"
once.

A stop from inside, independent of signals, is

    docker exec rainbowminer bash /RainbowMiner/stopp.sh

RainbowMiner shuts down cleanly and the container exits with code 0, but with
`restart: unless-stopped` Docker starts it again right away. The same holds for the stop
button of the web interface. Use it as a restart; the stop that stays stopped is
`docker compose stop`.

## What to persist

| folder   | what is in it                                                                                                  |
|----------|----------------------------------------------------------------------------------------------------------------|
| `Config` | `config.txt`, the pool, miner, device and OC configuration. Without it every start is a first start            |
| `Stats`  | the benchmark results and the profit history. Without it every rebuild starts a full re-benchmark of all miners |
| `Bin`    | the downloaded miner binaries. Optional, saves the download after a rebuild                                     |
| `Logs`   | the RainbowMiner log and one file per miner run. This is where you look when a miner crashes                   |

`Data` is not worth a mount: it holds caches RainbowMiner refreshes on its own (pool and
coin data, DAG sizes) and the `rbm.pid` marker.

An automatic update inside the running container updates the files in the container
layer, which is thrown away at the next rebuild. Rebuilding the image from the latest
release is the cleaner way to update, so set `EnableAutoUpdate` to `0` in `config.txt`
and rebuild when a new release is out.

## Troubleshooting

- **"All miners crashed. Immediately restarting loop."** The miners start and die at once.
  Look at `Logs/<MinerName>-<port>_<date>.txt` for the miner's own output. The usual cause
  in a container is the GPU runtime: run `clinfo` inside the container, it has to show an
  AMD platform (ROCm) or an NVIDIA platform. A platform named `rusticl` or `Clover` is
  Mesa and does not run miners. For NVIDIA also check that `nvidia-smi` works inside the
  container and that the image was built with `install.sh -nv`. If the miner log ends in
  `error while loading shared libraries`, the apt step of `install.sh` did not run: the
  Dockerfile lacks the `apt-get update` in front of it.
- **No GPU found.** `clinfo` shows no device: for AMD check that `/dev/kfd` and `/dev/dri`
  are passed through and, if the container runs as a user, that `group_add` carries the
  numeric GIDs of the host's `video` and `render` groups. For NVIDIA run `nvidia-smi`
  inside the container, which tests the container toolkit and the `runtime: nvidia` line.
- **"Unable to write to read-only file ./Config/config.txt"** and settings do not save.
  The `Config` files belong to a host user and lack the write bit for others. Releases up
  to v5.0.3.5 trust .NET's `IsReadOnly`, which has no exception for root, and do not even
  try to write. `chown -R root:root Config` on the host. Fixed in the release after
  v5.0.3.5.
- **"Checking for VM .. found (some miners will be excluded)"** at start. `virt-what`
  reports `docker`. The only miner this excludes is CryptoDredge, everything else runs.
- **"TERM environment variable not set."** at the top of `docker logs`. PowerShell's
  `Clear-Host` without a terminal, harmless.
- **The container does not stop.** The `ENTRYPOINT` has to be in exec form and has to be
  the entrypoint shown above. Check with `docker top rainbowminer` that `bash /entrypoint.sh`
  is the first process, not `sh -c`.
- **The setup wizard loops or errors at the first start.** The container was started
  detached without a `Config/config.txt`. Run the interactive setup from
  [First start](#first-start) once.
- **RainbowMiner restarts instead of stopping.** `stopp.sh` or the web stop button were
  used with `restart: unless-stopped`. Stop with `docker compose stop`.
- **Benchmarks start from zero after every rebuild.** The `Stats` folder is not mounted.
