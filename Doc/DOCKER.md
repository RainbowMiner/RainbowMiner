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
2. [The entrypoint](#the-entrypoint)
3. [The compose file](#the-compose-file)
4. [First start](#first-start)
5. [Stopping the container](#stopping-the-container)
6. [What to persist](#what-to-persist)
7. [Troubleshooting](#troubleshooting)

## The Dockerfiles

All three variants share the same skeleton: Ubuntu 24.04 as the base, because AMD does not
ship ROCm packages for newer Ubuntu releases yet and the miner binaries are built against
the glibc of the LTS releases; the packages `install.sh` cannot install itself; the latest
RainbowMiner release unpacked to `/RainbowMiner`; and the entrypoint from the next
section. Only the GPU runtime differs.

Three things apply to all of them:

- `install.sh` installs PowerShell and the packages the miners need. It also tries to
  install the `ocdaemon` service and prints that systemd is missing. That is expected in a
  container and harmless.
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
            ca-certificates curl wget unzip xz-utils pciutils libicu74 \
            ocl-icd-libopencl1 clinfo \
        && rm -rf /var/lib/apt/lists/*

    # the file name is the one listed at https://repo.radeon.com/amdgpu-install/latest/ubuntu/noble/
    # (7.2.4 in October 2026); older cards may need an older version from the parent directory
    RUN wget -q https://repo.radeon.com/amdgpu-install/latest/ubuntu/noble/amdgpu-install_7.2.4.70204-1_all.deb \
        && apt-get update && apt-get install -y ./amdgpu-install_7.2.4.70204-1_all.deb \
        && amdgpu-install -y --usecase=opencl --no-dkms --no-32 \
        && rm -f amdgpu-install_*.deb && rm -rf /var/lib/apt/lists/*

    RUN mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh

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
            ca-certificates curl wget unzip xz-utils pciutils libicu74 \
            ocl-icd-libopencl1 clinfo \
        && rm -rf /var/lib/apt/lists/*

    # what the NVIDIA Container Toolkit mounts at start: compute = CUDA, utility = nvidia-smi and NVML
    ENV NVIDIA_VISIBLE_DEVICES=all
    ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

    # -nv fetches the CUDA runtime bundles (one per CUDA generation) into /opt/rainbowminer/lib
    RUN mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh -nv

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
            ca-certificates curl wget unzip xz-utils pciutils libicu74 \
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

    RUN mkdir /RainbowMiner \
        && curl -s https://api.github.com/repos/RainbowMiner/RainbowMiner/releases/latest \
           | grep -o 'https://[^"]*RainbowMiner[^"]*linux.zip' | head -1 | xargs curl -sL -o /tmp/rbm.zip \
        && unzip -q /tmp/rbm.zip -d /RainbowMiner && rm /tmp/rbm.zip \
        && bash /RainbowMiner/install.sh -nv

    COPY entrypoint.sh /entrypoint.sh
    ENTRYPOINT ["bash", "/entrypoint.sh"]

The compose file for the mixed image needs both vendor blocks: the NVIDIA runtime and the
AMD device passthrough combine without conflict.

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
    trap 'echo adios > /RainbowMiner/stopp.txt; wait $child' TERM INT
    wait $child

A `trap` installed in PID 1 counts as a signal handler, so bash receives the SIGTERM here
even without `init: true`.

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
        group_add:
          - video
          - render
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

`stop_grace_period` matters. Docker's default of 10 seconds is not enough for a clean stop:
the stop file is polled once per second while RainbowMiner waits, but not while it fetches
pools or starts miners at the beginning of a round, and stopping the miners takes a few
seconds on its own. With the default, Docker kills the container before the shutdown is
through.

If the host runs the AMD container runtime, `runtime: amd` together with `gpus: all`
replaces the `devices` and `group_add` lines. Either way, `clinfo` inside the container
has to list an AMD platform.

## First start

The first start of RainbowMiner opens the setup wizard, which needs a terminal. A detached
container has none, so do the setup once interactively:

    docker compose build
    docker compose run --rm -it --entrypoint bash rainbowminer /RainbowMiner/setup.sh
    docker compose up -d

`setup.sh` writes `Config/config.txt` and the pool configuration into the mounted `Config`
folder, where every later start finds them. The alternative is to copy a `Config` folder
from an existing rig into place before the first `up`.

The web interface is reachable at `http://<host>:4000` as usual.

## Stopping the container

`docker compose stop` or `docker compose down` send SIGTERM to the entrypoint, the
entrypoint writes the stop file, RainbowMiner stops the miners and exits, the container
ends. Expect it to take between a few seconds and about a minute, depending on what
RainbowMiner was doing when the signal arrived.

Without the entrypoint, or with a shell-form `ENTRYPOINT`, nothing happens on SIGTERM and
Docker kills the container with SIGKILL after the grace period. The miners die with it
(RainbowMiner's miner guard ends them when the controller disappears), but the shutdown is
not clean: tmux sessions and the pid file stay behind.

A clean stop from outside, independent of signals, is always

    docker exec rainbowminer bash /RainbowMiner/stopp.sh

## What to persist

| folder   | what is in it                                                                                                  |
|----------|----------------------------------------------------------------------------------------------------------------|
| `Config` | `config.txt`, the pool, miner, device and OC configuration. Without it every start is a first start            |
| `Stats`  | the benchmark results and the profit history. Without it every rebuild starts a full re-benchmark of all miners |
| `Bin`    | the downloaded miner binaries. Optional, saves the download after a rebuild                                     |
| `Logs`   | the RainbowMiner log and one file per miner run. This is where you look when a miner crashes                   |

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
  container and that the image was built with `install.sh -nv`.
- **No GPU found.** `clinfo` shows no device: for AMD check that `/dev/kfd` and `/dev/dri`
  are passed through and that the container user is in the `video` and `render` groups.
  For NVIDIA run `nvidia-smi` inside the container, which tests the container toolkit and
  the `runtime: nvidia` line.
- **The container does not stop.** The `ENTRYPOINT` has to be in exec form and has to be
  the entrypoint shown above. Check with `docker top rainbowminer` that `bash /entrypoint.sh`
  is the first process, not `sh -c`.
- **The setup wizard loops or errors at the first start.** The container was started
  detached without a `Config/config.txt`. Run the interactive setup from
  [First start](#first-start) once.
- **Benchmarks start from zero after every rebuild.** The `Stats` folder is not mounted.
