# Pools

RainbowMiner ships with a module for every pool listed here. Choose the pools you want with
`PoolName` and `ExcludePoolName` in `Config\config.txt`, or with
[C]onfiguration->[S]elections; their wallets, usernames and API keys are entered in the
configuration setup or in `Config\pools.config.txt`, which is documented in
[POOLSCONFIG.md](POOLSCONFIG.md).

A pool that is not in this list can be added as a user pool, see [USERPOOLS.md](USERPOOLS.md).

Click a pool for its notes - what it pays out, and what it needs from you.

<details><summary>2Miners</summary> https://www.2miners.com/ no auto-exchange, a separate wallet address is needed for each coin (ETC, XZC and more) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>2MinersAE</summary> https://www.2miners.com/ auto-exchange pool, mines Ethash and Etchash, payout in BTC or NANO (not for ETC). BTC is preset with $Wallet by default. So if you want to autoexchange to NANO, set the wallets and parameter AECurrency accordingly in pools.config.txt. Use parameter "CoinSymbol" to define, which coin to mine (e.g. set to "ETC", if you want to autoexchange-mine ETC, only).</details>
<details><summary>2MinersSolo</summary> https://www.2miners.com/ no auto-exchange, a separate wallet address is needed for each coin (ETC, XZC and more) you want to mine solo. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Abelpool</summary> https://abelpool.io/ ABEL/Abelean-pool, pays in ABEL, create an account, then look for "deploy command" and copy the wallet address plus password (looks like adb0000000000000000000000000000000000000000000000000000xxxyyyzzz:thepassword), then either set the full string as ABEL wallet or do separate the string at the ":" and put the left string into ABEL and the right string into ABEL-Params in pools configuration or edit pools.config.txt</details>
<details><summary>AccPool</summary> https://acc-pool.pw/ KAS and NEXA pools, no auto-exchange, pays in the mined coin. Set your KAS and/or NEXA address in pools configuration or edit pools.config.txt</details>
<details><summary>Acepool</summary> https://acepool.top/ Equihash-pool in eu region for BEAM and XGM(Defis), set your acepool public key (can be created on their website) as wallet in pools configuration or edit pools.config.txt</details>
<details><summary>Aionpool</summary> https://aionpool.tech/ AION/Equihash210,9-pool, pays in AION, enter your Aion wallet address in pools configuration or edit pools.config.txt</details>
<details><summary>BaikalMine</summary> https://baikalmine.com/ no auto-exchange, enter wallet address for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>BaikalMinePPS</summary> https://baikalmine.com/ PPS+ variant of BaikalMine, no auto-exchange, enter wallet address for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>BaikalMineSolo</summary> https://baikalmine.com/ no auto-exchange, solo mining, only. Enter wallet address for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Binance</summary> https://pool.binance.com/ no auto-exchange, ETC mining, instead of wallet, setup and use a miner name. Set in pools configuration or edit pools.config.txt</details>
<details><summary>C3pool</summary> https://c3pool.com/oldui/en/ auto-exchange and payout in XMR, enter your Monero wallet address and a password (either a real password or your email-address) into pools.config.txt to start mining</details>
<details><summary>CpuPool</summary> http://cpu-pool.com/ specialized on CPU mining, no auto-exchange, a separate wallet is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Crazypool</summary> https://crazypool.org/ no auto-exchange, a separate wallet address is needed for each coin (ETC, UBQ) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>DeepMinerZ</summary> https://pool.deepminerz.com/ DNX, DynexSolve pool, pays in DNX, enter your DNX wallet address in pools configuration or edit pools.config.txt</details>
<details><summary>DeepMinerZSolo</summary> https://pool.deepminerz.com/ DNX, DynexSolve for solo mining, pays in DNX, enter your DNX wallet address in pools configuration or edit pools.config.txt</details>
<details><summary>EpicMine</summary> https://epicmine.io/ EPIC-pool pays in EPIC, set your EpicMine MiningAlias and optional your API key and API secret for balance display in pools.config.txt</details>
<details><summary>Ethwmine</summary> https://ethwmine.com/ no auto-exchange, a separate wallet address is needed for ETHW. Set in pools configuration or edit pools.config.txt</details>
<details><summary>F2Pool</summary> https://www.f2pool.com/ no auto-exchange, either enter your f2pool username as wallet address, or a real wallet address for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>FlockPool</summary> https://flockpool.com/ Raptoreum-pool, pays in RTM, set your RTM-address in pools configuration or edit pools.config.txt</details>
<details><summary>Gtpool</summary> https://gtpool.io/ account based multi-coin pool: create an account on their website and set your API key as parameter API_Key in pools.config.txt. RainbowMiner switches your workers to the best coin via the pool API</details>
<details><summary>Hashcryptos</summary>https://www.hashcryptos.com/  auto-exchange and payout in BTC and other currencies. To mine, you need to "activate" your wallet address on their website, first.</details>
<details><summary>Hashpool</summary> https://hashpool.com/ no auto-exchange, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>HashVault</summary> https://hashvault.pro/ no auto-exchange, dedicated to cryptonight mining, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Hellominer</summary> https://hellominer.com/ no auto-exchange, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>HeroMiners</summary> https://herominers.com/ no auto-exchange, a separate wallet address is needed for each coin (ETC, BEAM, GRIN, Monero, Haven, Conceal, Cortex and more) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Icemining</summary> https://icemining.ca/ no auto-exchange, NIM, GRAM and CHAPA. Set your wallet in pools.config.txt</details>
<details><summary>K1Pool</summary> https://k1pool.com/invite/016079e6c5 no auto-exchange, many currencies including XEL. Set your account wallet ID for coins to mine in pools.config.txt</details>
<details><summary>K1PoolSolo</summary> https://k1pool.com/invite/016079e6c5 solo mining, no auto-exchange, many currencies. Set your account wallet ID for coins to mine in pools.config.txt</details>
<details><summary>Kryptex</summary> https://pool.kryptex.com/?ref=15aa84c0 auto-exchange and coin mining, many currencies including ALPH and NEXA. Set your account email, mining username for all coins or wallets for specific coins to mine in pools.config.txt</details>
<details><summary>KryptexSolo</summary> https://pool.kryptex.com/?ref=15aa84c0 solo mining, many currencies including ALPH and NEXA. Set your wallets for coins to mine in pools.config.txt</details>
<details><summary>LeafPool</summary> https://www.leafpool.com/ no auto-exchange, mainly BEAM mining, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>LuckPool</summary> https://luckpool.net/ no auto-exchange, mining VRSC and YEC, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>LuckyPool</summary> https://luckypool.io/ no auto-exchange, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Luxor</summary> https://mining.luxor.tech/ no auto-exchange, small pool with hand picked coins, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>MinerRocks</summary> https://miner.rocks/ no auto-exchange, dedicated to cryptonight mining, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Mining4people</summary> https://www.mining4people.com/ no auto-exchange, multiple coins for pool mining available, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Mining4peopleSolo</summary> https://www.mining4people.com/ no auto-exchange, multiple coins for solo mining available, a separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>MiningDutch</summary> https://mining-dutch.nl/ auto-exchange and payout in various currencies, username required. Mining by algorithm profitability</details>
<details><summary>MiningRigRentals</summary> <a href="https://www.miningrigrentals.com/?ref=2598069">https://www.miningrigrentals.com/</a> rent your complete rig to interested users in exchange for BTC, ETC, LTC or DASH. See extra section for more details</details>
<details><summary>Mintpond</summary> https://mintpond.com/ if you are totally in Zcoin, then this pool might be the best choice. A separate wallet address is needed for XZC. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Molepool</summary> https://molepool.com/ no auto-exchange, a separate wallet address is needed for ETHW. Set in pools configuration or edit pools.config.txt</details>
<details><summary>MoneroOcean</summary> https://moneroocean.stream/ auto-exchange and payout in XMR, enter your Monero wallet address and a password (either a real password or your email-address) into pools.config.txt to start mining</details>
<details><summary>NanoPool</summary> https://nanopool.org/ no auto-exchange, a separate wallet address is needed for each coin (ETHW, ETC, ZEC, ETN, SIA, PASC) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Neuropool</summary> https://neuropool.net/ DNX, DynexSolve pool, pays in DNX, enter your DNX wallet address in pools configuration or edit pools.config.txt</details>
<details><summary>Nicehash</summary> <a href="https://www.nicehash.com/?refby=c402ea4d-9203-414c-b96e-526e34ad20e1">https://www.nicehash.com/</a> auto-exchange and payout in BTC, use of a special Nicehash mining wallet is mandatory, see note below</details>
<details><summary>Pearlhash</summary> https://pearlhash.xyz/ Pearl-pool for eu, us and asia region, pays in PRL, set your PRL-address in pools configuration or edit pools.config.txt</details>
<details><summary>Poolin</summary> https://www.poolin.me/ no auto-exchange registration is mandatory, mines ETC, ETHW and RVN. Set Poolin subaccount-worker plus minerid (e.g. "miner.001") as wallet address in pools configuration or edit pools.config.txt</details>
<details><summary>RaptoreumZone</summary> https://raptoreum.zone/ Take2/Ghostrider mining pool, pays in RTM, set your RTM-address in pools configuration or edit pools.config.txt</details>
<details><summary>Ravenminer</summary> https://www.ravenminer.com/ ravencoin-pool for us region, pays in RVN, set your RVN-address in pools configuration or edit pools.config.txt</details>
<details><summary>RavenminerSolo</summary> https://www.ravenminer.com/ ravencoin solo mining, pays in RVN, set your RVN-address in pools configuration or edit pools.config.txt</details>
<details><summary>Rplant</summary> https://pool.rplant.xyz/ specialized on CPU mining, no auto-exchange, a separate wallet is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>RplantSolo</summary> https://pool.rplant.xyz/ solo mining, specialized on CPU coins, no auto-exchange, a separate wallet is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>SeroPool</summary> https://pool.sero.cash/ Supersero-pool for asia region, pays in SERO, set your SERO-address in pools configuration or edit pools.config.txt</details>
<details><summary>SoloPool</summary> https://solopool.org/ no auto-exchange, solo mining, only. A separate wallet address is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Sunpool</summary> https://sunpool.top/ Equihash-pool in eu region for BEAM, GRIMM, XGM(Defis) and ATOMI, set your sunpool public key (can be created on their website) as wallet in pools configuration or edit pools.config.txt</details>
<details><summary>SupportXmr</summary> https://www.supportxmr.com/ Monero-pool, pays in XMR, set your XMR-address in pools configuration or edit pools.config.txt</details>
<details><summary>SuprNova</summary> https://suprnova.cc/ no auto-exchange, enter your SuprNova username as wallet address for each coin you want to mine. Make sure, that your workername on SuprNova matches your rig's name and the SuprNova worker password is "x". Set in pools configuration or edit pools.config.txt</details>
<details><summary>unMineable</summary> <a href="https://unmineable.com/?ref=U-TEMDPF">https://unmineable.com/</a> auto-exchange and payout in over 50 non-mineable coins. Mined with Ethash, Etchash, RandomX, KawPow, BeamHash and more. Put your user alias (and optional API key/secret) into pools.config.txt. See the notes below.</details>
<details><summary>UUPool</summary> https://www.uupool.com/ no auto-exchange, a separate wallet is needed for each coin you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>ViaBTC</summary> https://www.viabtc.com/ ETC mining pool, use your ViaBTC username or ETC deposit address of ViaBTC pool as wallet address. Set in pools configuration or edit pools.config.txt</details>
<details><summary>Vipor</summary> https://vipor.net/ no auto-exchange, dedicated to Radiant/RXD mining. Set in pools configuration or edit pools.config.txt</details>
<details><summary>ViporSolo</summary> https://vipor.net/ solo mining, no auto-exchange, dedicated to Radiant/RXD mining. Set in pools configuration or edit pools.config.txt</details>
<details><summary>WoolyPooly</summary> https://www.woolypooly.com/ no auto-exchange, a separate wallet address is needed for each coin (ETHW, ETC, RVN, ERG, CFX, VEIL and more) you want to mine. Set in pools configuration or edit pools.config.txt</details>
<details><summary>WoolyPoolySolo</summary> https://www.woolypooly.com/ no auto-exchange, a separate wallet address is needed for each coin (ETHW, ETC, RVN, ERG, CFX, VEIL and more) you want to mine solo. Set in pools configuration or edit pools.config.txt</details>
<details><summary>XdagOrg</summary> https://xdag.org/ XDAG community pools, pays in XDAG, set your XDAG-address in pools configuration or edit pools.config.txt</details>
<details><summary>XdagOrgSolo</summary> https://xdag.org/ XDAG solo mining, pays in XDAG, set your XDAG-address in pools configuration or edit pools.config.txt</details>
<details><summary>YadaMiners</summary> http://yadaminers.pl/ YDA/RandomYada-pool, pays in YDA, enter your Yada wallet address in pools configuration or edit pools.config.txt</details>
<details><summary>Zpool</summary> https://www.zpool.ca/ auto-exchange and payout in BTC, DASH, XVG, DGB and KMD or any other coin that is listed at the pool. Pool will automatically select the most profitable coin. Switching will be by algorithm.</details>
<details><summary>ZpoolCoins</summary> https://www.zpool.ca/ auto-exchange and payout in BTC, DASH, XVG, DGB and KMD or any other coin that is listed at the pool. Mine most profitable coin, either with auto-exchange to a currency of wish, or mine directly to individual coin wallets. If you setup RainbowMiner with many algorithms, expect a lot of switching. Switching will be by coin.</details>
<br />	
  
<details><summary>Notes for <a href="https://www.nicehash.com/?refby=c402ea4d-9203-414c-b96e-526e34ad20e1">NiceHash</a></summary>

If you plan to mine through Nicehash, you need to register an account with them ([https://www.nicehash.com/register](https://www.nicehash.com/?refby=c402ea4d-9203-414c-b96e-526e34ad20e1)). NiceHash will provide you with an extra NiceHash wallet/bitcoin address (RainbowMiner will ask for this address during the setup or configuration process).
Payout via Bitcoin-Lightning channel is possible. If you want to see balance details, first create a new API key (My Settings->API-Key) with "Wallet permission->View.." and "Mining permission->View.." enabled. Second add API key, API secret and Organizazion ID to pools.config.txt</details>
<details><summary>Notes for <a href="https://unmineable.com/?ref=U-TEMDPF">unMineable</a></summary>

unMineable can be mined in two ways, and RainbowMiner supports both:

- **account (alias) mode** - the modern way. Create an account at unMineable, then put your
  alias into the `"User"` field of the unMineable section of `pools.config.txt` (or use
  Setup: [P]ools -> unMineable). The worker name comes from the `"Worker"` field, where
  `$WorkerName` is the default from config.txt. RainbowMiner then logs in as
  `youralias.workername`. The payout coin and the address are chosen in the unMineable
  dashboard, not in RainbowMiner, which values the pool in BTC.
- **coin/wallet mode** - the classic way. Enter a wallet address per coin (`"DOGE"`,
  `"USDT"`, ...) in the same section. RainbowMiner then logs in as
  `COIN:youraddress.workername`, one pool entry per coin.

Both work at the same time. If you configure an alias **and** coin wallets, both variants
take part in the profit switching and your earnings can land on the account as well as on the
old addresses. To mine on the alias only, clear the per-coin wallet fields **and**
`"FocusWallet"` - as long as FocusWallet names a coin, the account entry can never win.

Two more notes: the `"<COIN>-Params"` fields are not used by the unMineable module, and a
*mining key* is not the same thing as an alias - a mining key replaces the `COIN:ADDRESS`
part of the classic format, whereas the alias belongs into `"User"`.
</details>
<details><summary>Notes for the pools Hashcryptos, HashPool, MinerRocks, Mining4people, Ravenminer and Zpool</summary>
  
The miner can be setup to mine any coin or currency, that is listed at the respective pool. The pool will then payout to the given non-BTC wallet address. Take into account, that non-BTC payouts depend heavily on that coin being mined. If the pool has not mined or is not mining that currency, the payouts will be delayed until the pool has mined the blocks. Read the pools websites, about the mineability and reliability of a currency. It's recommended to use BTC as any other coin could be removed at anytime and payouts will not occur. The pools MinerRocks and Ravenminer do not have auto-exchange to BTC. Please be careful, what you choose to mine.
</details>
