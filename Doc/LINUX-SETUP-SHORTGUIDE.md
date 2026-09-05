## Short Guide to Running RBM on Linux with Nvidia GPUs

### Stage 1: Prepping the OS

Download and flash a copy of HiveOS. Boot into HiveOS and set up an account. Get the rig up and mining with an overclock where p0 state is enabled. You can then remove the flight sheet to stop the rig from mining and disconnect the rig from the hiveOS servers either by deleting the account information from the rig or deleting the rig from the website.


![alt text](https://github.com/RainbowMiner/miner-binaries/raw/master/short-guide-linux-nvidia-setup-1.png "Setting up your OS")

Note: This step can be skipped but enabling p0 state seems to provide more stability when pushing overclocks to their limits. Using HiveOS is preferable since it contains all the prerequisite mining packages.


### Stage 2: Install RBM

You can ignore the additional steps on github since drivers are already installed. Just run these

```
sudo apt-get update
sudo apt-get install git
git clone https://github.com/rainbowminer/RainbowMiner
cd RainbowMiner
chmod +x *.sh
sudo ./install.sh
```

**Start the Script:**

`./start.sh`

Alternative: start as Linux screen:

`./start-screen.sh`

Press `Ctrl+a`, then `d` to detach from screen (imagine you want to disconnect your ssh session)

Enter screen -R RainbowMiner to reconnect to screen

### Stage 3: Configuring RBM

Run the initial set up of RBM as you normally would, there are a few desirable but optional steps.

**Enable file sharing through samba (preferred way to edit config files remotely)**

```
sudo apt update
sudo apt install samba
```

Add this to the file

```
[RainbowMiner]
path = /home/user/RainbowMiner
writeable = yes
browseable = yes
public = yes
create mask = 0777
directory mask = 0777
force user = root
sudo service smbd restart
```

**Making sure OCprofiles is working**

`ps aux | grep Xorg`

![alt text](https://github.com/RainbowMiner/miner-binaries/raw/master/short-guide-linux-nvidia-setup-2.png "Result of ps grepped for Xorg")

Copy the top path to your config file...

![alt text](https://github.com/RainbowMiner/miner-binaries/raw/master/short-guide-linux-nvidia-setup-3.png "Insert the path to Xorg into config.txt")

If using linux headless make sure the option is set correctly.

### Set RBM to run at start up

`sudo nano /etc/rc.local`

Insert the rainbowminer command

![alt text](https://github.com/RainbowMiner/miner-binaries/raw/master/short-guide-linux-nvidia-setup-4.png "Insert the Rainbowminer start command")

(Written by @acos0874 - Thank you very much!)

### Start RainbowMiner as a systemd service

The alternative to crontab or `rc.local`: a service unit lets you start, stop and enable
RainbowMiner with the usual systemd commands, and it can run RainbowMiner as a normal user or
as root. As root, create `/etc/systemd/system/rainbowminer.service` (adapt the user name and
the path):

```
[Unit]
Description=starts RainbowMiner as a service
Wants=network.target

[Service]
Type=simple

User=USERNAME             ## your username here, or comment it out to run as root
ExecStart=/YOURPATH/RainbowMiner/start-nohup.sh

KillMode=none
TimeoutStopSec=15
ExecStop=/YOURPATH/RainbowMiner/stopp.sh

[Install]
WantedBy=multi-user.target
```

Then:

```
systemctl daemon-reload                     # once, so systemd learns about the new unit
systemctl enable rainbowminer.service       # once, to start it at boot
systemctl start rainbowminer.service        # bring it up now
systemctl stop rainbowminer.service         # clean shutdown via stopp.sh
```

`KillMode=none` and `TimeoutStopSec` are what let `stopp.sh` end the miners in an orderly
fashion instead of systemd killing the process group.

Thanks to @timvis for this unit file
([issue #2602](https://github.com/RainbowMiner/RainbowMiner/issues/2602)).
