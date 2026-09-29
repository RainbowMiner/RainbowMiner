### Hints for Networking

Choose one PC to be the Server (it may be a dusty old notebook). No need to let it mine, just let RainbowMiner start in paused mode. Select all other Rigs to act as Clients. All pool API communication will then be managed by the server: no more being blocked by the pools due to excessive use of their API

There is a Network setup build-in the configuration (press [C], then enter [N]) to help with the setup.

If you want it quicker, just run one of the following init scripts for very convenient pre-setup:
```InitServer.bat / initserver.sh``` : make this rig a server
```InitClient.bat / initclient.sh``` : make this rig a client
```InitStandalone.bat / initstandalone.sh``` : make this rig a standalone machine

Of course you may also edit the `Config\config.txt` directly.

If you change the RunMode of a rig, RainbowMiner needs to be restarted.

#### Setup as Server
- one PC takes the role as Server
- it will act as gateway to the pool APIs for all Clients 
- enable auth: choose an username and a password.
- the server will be running on the API port
- optionally provide individual config files for each client

These are the server-fields to fill in the config.txt (or use the initscripts or the build-in config)
```
  "RunMode": "server",
  "APIport": 4000,
  "APIauth": "1",
  "APIuser": "serverusername",
  "APIpassword": "serverpassword",
  "EnableServerDiscovery": "1",
```

#### Setup as Client
- all other Rigs shall be clients
- if you have enable auth at the server: set the username and password.
- the RainbowMiner running on the server will tell you the machinename, ip address and port
- use either the machinename or the ip address of the server as servername
- optionally select to download config files from the server

These are the client-fields to fill in the config.txt (or use the initscripts or the build-in config)
```
  "RunMode": "client",
  "ServerName": "machinenameofserver",
  "ServerPort": 4000,
  "ServerUser": "serverusername",
  "ServerPassword": "serverpassword",
  "EnableServerConfig": "1",
  "EnableServerPools": "1",
  "EnableServerDiscovery": "1",
  "ServerConfigName": "config,coins,pools",
```

If "EnableServerConfig" is set to "1" (like in the above example), the Client will download the config files defined with the list "ServerConfigName" from the Server. In the example: config.txt, coins.config.txt, pools.config.txt would be downloaded automatically. Possible names are config, coins, pools, algorithms, scheduler, mrralgorithms, userpools, customminers, miners and ocprofiles.

If "EnableServerPools" is set to "1", the client will download the server's pool and balance statistics and mine to exactly those pools (except for MiningRigRentals, which will always be handled locally)

### Server discovery: surviving an ip change of the server

A client reaches the server by `ServerName`. If that is an ip address and the server gets a new
one from DHCP, or if it is a name that the router's DNS still resolves to the old address, the
client shows `Server ... does not respond` and works as a standalone rig until the config is
corrected by hand.

With `"EnableServerDiscovery": "1"` on the server and on the clients, the server announces its
api address to the local network once per round (a UDP broadcast to its api port) and the
clients learn the address from those announcements:

- an announcement is signed with the server's `APIpassword` (HMAC-SHA256). `APIauth`, `APIuser`
  and `APIpassword` must be set on the server, `ServerUser` and `ServerPassword` on the clients.
  Without a password nothing is sent and nothing is accepted: an unsigned announcement would let
  any device in the network redirect the clients
- a client accepts an announcement only if the signature matches, the sender is the address it
  announces, the timestamp is fresh and the machine name matches `ServerName` (or, when
  `ServerName` is an ip address, the machine name first seen at that address)
- the learned address is stored in `Data\serveraddr.json` and used for all server calls, the
  status line shows `Connected to <ServerName>:<port> via <ip>`. If the learned address stops
  answering while the configured name works again, the file is dropped
- the announcements are broadcasts, so server and clients must be in the same network segment.
  Clients in other networks keep using the name (see the DDNS hint below)
- Windows clients need an inbound firewall rule for UDP on the server's port. The rule exists
  when the client's own `APIport` is that same port (the usual 4000). Otherwise run
  `InitClient.bat` again or add the rule "RainbowMiner API <port> UDP". Linux rigs with an
  active firewall: `ufw allow <port>/udp`
- `EnableServerDiscovery` is part of the server's config.txt that managed clients download, so
  enabling it on the server enables it on the clients with `EnableServerConfig` as well

Independent of this option, a client resolves a `ServerName` itself and connects to the first
of its IPv4 addresses that answers on the api port. PowerShell 7 would otherwise try the name's
IPv6 addresses first, and one stale IPv6 address costs the complete connection timeout.

### Connecting a client over the internet

Client and server do not have to sit in the same network - the client only needs to reach the
server's API port. But the API speaks plain HTTP, and so does the RainbowMiner client: the
username and password, the config files with the wallets and the relayed marketplace and
exchange API keys and secrets (MiningRigRentals, NiceHash, Binance) travel unencrypted.
Forwarding the API port on the router puts all of that in front of anyone on the path, and
the login throttling only slows down password guessing. Use one of these two ways instead.

#### 1. A VPN or an overlay network (recommended)

Put the rigs into one private network and treat it like a LAN: WireGuard, or an overlay such
as Tailscale or ZeroTier, which connects the rigs through NAT without any port forwarding.
The server's API port stays closed to the internet, and the clients use the server's VPN
address as `ServerName`, e.g. its WireGuard address or, with Tailscale, its `100.x.y.z`
address or MagicDNS name:

```
  "RunMode": "client",
  "ServerName": "100.101.102.103",
  "ServerPort": "4000",
  "ServerUser": "serverusername",
  "ServerPassword": "serverpassword",
```

Everything else stays the LAN setup from above, including the authentication. VPN addresses
do not change, and the server discovery announcements are broadcasts that do not cross a VPN
anyway, so leave `EnableServerDiscovery` off for these clients.

#### 2. A TLS reverse proxy in front of the server

If the server must be reachable directly, put a TLS proxy in front of the API port and forward
only the proxy's port. Caddy fetches and renews a Let's Encrypt certificate for a DDNS name
by itself; this is the complete Caddyfile:

```
rig.example.dyndns.org {
    reverse_proxy 127.0.0.1:4000
}
```

Forward ports 443 and 80 (the certificate challenge) of the router to the machine running
the proxy, and do not forward the API port itself. This secures the access to the web
interface from anywhere with `https://rig.example.dyndns.org`.

It does not secure RainbowMiner clients by itself: a client speaks plain http to
`ServerName:ServerPort`. To run a client through the proxy, give it a TLS tunnel of its own
(e.g. stunnel in client mode: it listens on `127.0.0.1:4000` on the client rig and forwards
to `rig.example.dyndns.org:443` over TLS) and set `"ServerName": "localhost"`. If that is
too much plumbing, use the VPN.

#### Plain port forwarding

If you forward the API port anyway, know what you expose (see above) and reduce it as far as
it goes: enable the authentication, restrict the callers to the clients' public addresses
with `"APIallowIPs"`, use a DDNS name instead of the router's changing IP as `ServerName`,
and do not use `EnableServerConfig` or the marketplace relays over such a link.

**Always enable the authentication for any access from outside the LAN** - an open API port
lets anyone read and change the configuration of your rigs:

- on the server: `"APIauth": "1"`, `"APIuser"`, `"APIpassword"`, and restrict the callers
  with `"APIallowIPs"`
- on the client: `"ServerUser"` and `"ServerPassword"` with the same values
