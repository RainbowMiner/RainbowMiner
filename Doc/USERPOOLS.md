# User Pools

RainbowMiner ships with modules for dozens of pools, but the pool you want may not be among
them: the pool of a young coin, a regional pool with better latency, a pool that pays out in
a currency of your choice, or your own private pool. User pools close that gap. You describe
the stratum once - host, port, coin, wallet - and from then on the pool is treated like every
built-in pool: it is polled every round, its algorithms are matched with your miners and it
takes part in the profit switching.

A user pool is defined by one or more entries in `Config\userpools.config.txt`. Every entry
describes one stratum (one coin or algorithm at one region); all entries with the same name
form one pool. The **User Pools** page of the web interface lists the entries, edits them,
stores the wallet in `pools.config.txt` and adds the pool to `PoolName` when you restrict
the pools.

Contents

1. [Quick start](#quick-start)
2. [How user pools work](#how-user-pools-work)
3. [The User Pools page](#the-user-pools-page)
4. [The fields](#the-fields)
5. [Placeholders](#placeholders)
6. [Reading profit and statistics from a pool API](#reading-profit-and-statistics-from-a-pool-api)
7. [Worked example: xvg-pool.com](#worked-example-xvg-poolcom)
8. [Tips and troubleshooting](#tips-and-troubleshooting)

## Quick start

1. Open the web interface at [localhost:4000](http://localhost:4000) and click
   **Config > User Pools**.
2. Click **New user pool**.
3. Fill in the form:
   - **Name**: a short name without spaces, e.g. `MyPool`. It is the name of the pool on the
     Pools page, the section in `pools.config.txt` and the entry for `PoolName`.
   - **Host** and **Port**: the stratum server. A pasted `stratum+tcp://host:port` is split
     automatically. Set **SSL** if the stratum wants TLS.
   - **Coin symbol**: the coin that is mined, e.g. `RVN`. For a coin RainbowMiner knows, the
     algorithm and the coin name are filled in. For an unknown coin enter the **Algorithm**.
   - **Currency**: the currency the pool pays out. Leave it empty when it is the coin itself.
   - **Wallet**: your address for that currency at this pool.
4. Click **Save**. If `PoolName` in your setup restricts the pools, tick **Add ... to
   PoolName** before saving (the checkbox appears only then).
5. RainbowMiner picks the pool up after the current round. Watch it on the **Pools** page.

For another coin, algorithm or region of the same pool click the **Duplicate** button of the
entry, change the fields and save: the copy keeps the name and therefore the wallet.

The entries are stored in `Config\userpools.config.txt`. You can also edit that file with
the **JSON Editor** page or a text editor.

## How user pools work

- **One name, one pool.** Every entry with the same `Name` belongs to the same pool. The
  name gets a section in `pools.config.txt` like a built-in pool: the wallet per currency,
  `<Currency>-Params`, `Worker`, `Penalty`, the `Algorithm` / `CoinSymbol` filters, `Region`,
  `SSL` and so on. The section is created when you save the first entry.
- **One entry per stratum.** A pool that offers three coins needs three entries with the
  same name; a pool with a European and an American stratum for the same coin needs two
  entries with different `Region`.
- **The wallet is in pools.config.txt**, not in the entry. An entry is only used when the
  section of its pool has a wallet for the entry's currency. The page writes it for you;
  the Setup Pools page and the console setup show the section like any other pool.
- **PoolName and ExcludePoolName** of `config.txt` apply. When `PoolName` is a list, the
  pool must be in it (the page shows a hint and a button for that). Do not put
  `Userpools` into `PoolName`, the entries are selected by their own names.
- **Profit.** Without a pool API the price of the coin comes from WhatToMine (or, for solo
  pools, from the coin's difficulty). With `APIUrl1..3` and the API fields the pool's own
  profit, hashrate, workers and block statistics are read, see
  [below](#reading-profit-and-statistics-from-a-pool-api).
- **Client/Server.** `userpools` is one of the config files a client can pull from its
  server (`ServerConfigName`). On such a client the User Pools page is read-only. The same
  holds for the wallet when `pools` is pulled from the server, and for the PoolName button
  when `config` is.

## The User Pools page

The list shows one row per entry with the coin, the resolved algorithm, the stratum, the
region, the wallet state and a status:

| Badge | Meaning |
| --- | --- |
| `ready` | the entry is complete and selected |
| `no wallet` | `pools.config.txt` has no wallet for the currency of this entry; the pool is not used |
| `not in PoolName` | `PoolName` in `config.txt` is a list and does not contain the pool |
| `excluded` | the pool is listed in `ExcludePoolName` |
| `incomplete` | `Currency` (or `CoinSymbol`) or `Host` is empty; RainbowMiner disables such entries |
| `unknown coin, no algorithm` | the coin symbol is not in RainbowMiner's coin database and `Algorithm` is empty |
| `invalid name` | the name contains other characters than letters, digits and underscore, or equals a built-in pool |
| `disabled` | `Enable` is `0` |

Actions per row: **Edit**, **Duplicate** (a new entry with the same values, for another
coin, algorithm or region of the pool) and **Delete** (click twice).

The editor has these sections:

- **General**: name and enable switch. The name list offers the names you already use.
- **Pool connection**: host, port, protocol, SSL, region, EthMode and solo mining.
- **Coin**: coin symbol (with the coin database as suggestions), currency, algorithm and
  coin name. Choosing a known coin fills in algorithm and coin name.
- **Credentials**: the pool user and password with placeholders, and the wallet. The wallet
  is shared by all entries of the pool with the same currency; the label tells you for which
  currency and pool it is stored. An existing wallet of the pool is shown and kept unless
  you change it.
- **Pool API, fee and statistics**: the optional API fields, collapsed unless one is set.
- **Preview**: the stratum line and the user and password with the placeholders resolved,
  the algorithm that will be used and the currency and wallet.

Above the list a hint appears when `PoolName` is a list and one of your user pools is
missing in it, with one button per pool that adds the name to `PoolName` in `config.txt`.

The page keeps the array positions of `userpools.config.txt`: when the file was changed by
somebody else between loading and saving (the JSON editor, the server, a second browser
tab) the save is refused with "changed meanwhile" - reload the page and edit again.

## The fields

All values are strings in the JSON file, switches are `"1"` / `"0"`. Fields marked *API*
accept a number or a path into a pool API answer, see the next sections.

Mandatory:

| Field | Meaning |
| --- | --- |
| `Enable` | `1` = the entry takes part, `0` = kept in the file but never used [default `0`] |
| `Name` | the pool name: letters, digits and underscore, not the name of a built-in pool. All entries with the same name form one pool |
| `Currency` | the currency the pool pays out, decides which wallet of the pool section is used. Empty = `CoinSymbol` |
| `Host` | the stratum server address, without `stratum+tcp://` and without port |
| `Port` | the stratum port |

Optional:

| Field | Meaning |
| --- | --- |
| `CoinSymbol` | the coin that is mined. A coin from RainbowMiner's database brings its algorithm and name |
| `Algorithm` | the algorithm, needed when `CoinSymbol` is empty or unknown. RainbowMiner's name as shown on the Algorithms page (`KawPOW`, `RandomX`, `X17` ...), spelling variants are normalized |
| `CoinName` | the coin's name, for the display when the coin is not in the database |
| `User` | the user the miners log in with, placeholders allowed [default `$Wallet.$WorkerName`] |
| `Pass` | the pool password, placeholders allowed [default `x`] |
| `Protocol` | the stratum protocol, if it differs from the default [default `stratum+tcp`, or `stratum+ssl` when `SSL` is set] |
| `SSL` | `1` = the stratum wants SSL/TLS [default `0`] |
| `Region` | the home region of the stratum server, used for the `Region` filter of the pool section [default `US`] |
| `EthMode` | the stratum mode for Ethash, KawPOW and ProgPow pools: `ethproxy`, `ethstratumnh`, `qtminer`, `minerproxy` or `stratum` [default `ethproxy` for Ethash, `stratum` for KawPOW] |
| `SoloMining` | `1` = a solo mining pool; the profit is calculated from the difficulty [default `0`] |
| `PoolFee` | the pool fee in percent, e.g. `1` for one percent [default `0`] - *API* |
| `APIUrl1`, `APIUrl2`, `APIUrl3` | up to three API urls of the pool |
| `Profit` | the value of `Currency` per hashrate and day; profit per day = `Profit` x hashrate / `ProfitFactor` - *API* |
| `ProfitFactor` | the divisor for the profit calculation [default `1`] - *API* |
| `ProfitCurrency` | the currency `Profit` is quoted in, if it differs from `Currency` |
| `Hashrate` | the current hashrate of the pool - *API* |
| `Workers` | the number of workers on the pool - *API* |
| `TimeSinceLast` | seconds since the last block was found - *API* |
| `Blocks24h` | blocks found in the past 24 hours - *API* |
| `Difficulty` | the current difficulty of the coin, needed for solo mining - *API* |

Everything else - the wallet, `Penalty`, the `Algorithm` / `CoinSymbol` filters, `Region`,
`SSL`, `MaxMarginOfError` and so on - is configured in the section of the pool in
`pools.config.txt` (Config > Setup Pools, the JSON editor or the console setup), exactly
like for the built-in pools.

## Placeholders

The following variables are replaced in `User`, `Pass` and in all *API* fields:

| Placeholder | Value |
| --- | --- |
| `$Wallet` | the wallet for `Currency` from the pool section in `pools.config.txt` |
| `$WorkerName` | the rig's worker name (or the `Worker` value of the pool section) |
| `$CoinSymbol` | the `CoinSymbol` of the entry |
| `$Currency` | the `Currency` of the entry |
| `$Password` | the `Password` of the pool section |
| `$Params` | the `<Currency>-Params` of the pool section |

Example: with `User` = `$Wallet.$WorkerName` and `Pass` = `c=$Currency,mc=$CoinSymbol` a
rig named `rig01` logs in as `RVNWALLET.rig01` with the password `c=RVN,mc=RVN`.

## Reading profit and statistics from a pool API

Enter up to three API urls in `APIUrl1`, `APIUrl2` and `APIUrl3`. The urls are fetched
every two minutes and have to return JSON (with one exception, see `Profit` below). The
*API* fields then describe where the value is found:

- a plain number is taken as it is (`1` for a one percent fee, `2500000` for a hashrate);
- a path starts with `api1`, `api2` or `api3` for the url that carries the value, followed
  by the names of the nested objects: `api1.x17.estimate_current`. Without a prefix `api1`
  is used;
- arrays are indexed with brackets: `api1.pools[0].hashrate` picks the first element,
  `api1.coins[symbol=RVN].profit` picks the element whose `symbol` is `RVN`.

Special cases:

- `Profit`: when an API url returns the profit directly as a number (no JSON object), set
  `Profit` to `#` (or `#1`) for url 1, `#2` for url 2, `#3` for url 3.
- `ProfitFactor`: when the path contains `mbtc_mh_factor`, the factor is multiplied by
  1e6, which fits the yiimp style `estimate_current` / `mbtc_mh_factor` pair.
- `ProfitCurrency`: set it when the profit is quoted in another currency than `Currency`,
  e.g. a pool that pays in RVN but reports the profit in BTC.

The profit per day is `Profit` x hashrate / `ProfitFactor`, converted to BTC with the
current rates. When `Profit` is empty (or `SoloMining` is set) the price comes from
WhatToMine or from the difficulty instead.

## Worked example: xvg-pool.com

A yiimp style pool for Verge on X17 with the profit, hashrate and block statistics read
from the pool API. The form produces the same entry:

```json
{
  "Enable": "1",
  "Name": "XvgPool",
  "PoolFee": "api1.x17.fees",
  "Algorithm": "X17",
  "CoinName": "Verge",
  "CoinSymbol": "XVG",
  "Currency": "XVG",
  "Protocol": "stratum+tcp",
  "Host": "mining.xvg-pool.com",
  "Port": "6851",
  "User": "$Wallet.$WorkerName",
  "Pass": "c=XVG5",
  "Region": "US",
  "SSL": "0",
  "EthMode": "",
  "APIUrl1": "https://xvg-pool.com/api/status",
  "APIUrl2": "https://xvg-pool.com/api/currencies",
  "APIUrl3": "",
  "Profit": "api1.x17.estimate_current",
  "ProfitFactor": "api1.x17.mbtc_mh_factor",
  "ProfitCurrency": "BTC",
  "Hashrate": "api1.x17.hashrate",
  "Workers": "api1.x17.workers",
  "TimeSinceLast": "api2.XVG5.timesincelast",
  "Blocks24h": "api2.XVG5.24h_blocks",
  "Difficulty": "api2.XVG5.difficulty",
  "SoloMining": "0"
}
```

After saving with the wallet `XVGWALLET`, `pools.config.txt` contains

```json
"XvgPool": {
  "XVG": "XVGWALLET",
  "XVG-Params": "",
  "Worker": "$WorkerName",
  "Penalty": "0",
  ...
}
```

and, when the pools are restricted, `config.txt` reads `"PoolName": "Nicehash,Zpool,XvgPool"`.

## Tips and troubleshooting

- **The pool does not appear on the Pools page.** Check the status badges: the entry needs
  `Enable`, a wallet for its currency, a place in `PoolName` (or an empty `PoolName`), and
  `Currency` and `Host`. A coin symbol RainbowMiner does not know needs the `Algorithm`.
  Then wait for the next round; the log line `Userpool <Name>: no Algorithm set` or
  `no Currency set` names the missing field.
- **Which algorithm is used?** For a known coin the algorithm of the coin database wins
  over `Algorithm`. The list shows the resolved name, `from coin` marks the derived ones.
- **"changed meanwhile".** The entry was changed by somebody else after the page was
  loaded. Reload the page and redo the change.
- **Renaming a pool.** The entries get the new name, the old section in `pools.config.txt`
  and the old entry in `PoolName` stay. Enter the wallet for the new name (the page asks
  for it) and remove the old section when you do not need it any more.
- **Deleting an entry** removes it from `userpools.config.txt` only. The section of the
  pool in `pools.config.txt` is kept, so a pool can be re-added without losing the wallet.
- **Blank entries.** A fresh `userpools.config.txt` contains five empty templates. They
  are not shown on the page, RainbowMiner ignores them, and you may delete them from the
  file.
- **Same pool, several coins.** Use **Duplicate** and change the coin. The wallet field
  shows the wallet the pool already has for that currency, if any.
- **Per-pool tuning.** `Penalty`, the algorithm and coin filters, `Region`, `SSL` and
  `MaxMarginOfError` are set in the pool section of `pools.config.txt` (Config > Setup
  Pools), like for every other pool.
- **Client/Server.** `userpools` is synced to clients through `ServerConfigName`; on such
  a client the page is read-only. A per-worker file `Config\<workername>\userpools.config.txt`
  on the server overrides the shared one.
- **Custom miners.** The flight sheet import of the Custom Miners page creates the pool of
  the sheet as a user pool; enter its wallet on this page. See
  [CUSTOMMINERS.md](CUSTOMMINERS.md).
