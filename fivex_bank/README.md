# fivex_bank v1.0.0

Standalone bank for FiveX. Vanilla CFX — no QB / ESX / Qbox / ox_lib. Requires `fivex_jobcenter` 1.1.0+.

**Cash** is the `fivex_jobcenter` pay wallet (job pay lands there). **Bank** balance lives here. Players
move money between the two at tellers and ATMs, and send bank transfers to account numbers.

The **client is untrusted**. Every action is a server event. Teller actions re-check distance each time;
amounts, limits, funds and account numbers are validated server-side.

## Ensure

```
ensure fivex_jobcenter
ensure fivex_bank
```

(`ensure [fivex]` works too — `dependency 'fivex_jobcenter'` orders the start.)

`fivex_jobcenter/config.lua` must list `fivex_bank = true` in `Config.TrustedResources` (default).

## Where

| Point | Notes |
|---|---|
| 8 tellers (`Config.Branches`) | Fleeca ×6, Pacific Standard, Blaine County Savings. Green marker + blip 108. |
| ATMs | Any `prop_atm_01/02/03` or `prop_fleeca_atm` on the map, within 1.2 m. On foot only. |

Teller coords are stand-here points — check each in game and nudge `Config.Branches` if one is off.

## Features

- Account number per `license:` (`FX123456`), created on first join with `Config.StartingBalance` ($2,500).
- Deposit cash → bank, withdraw bank → cash.
- Transfers to any account number, **online or offline**, with an optional note.
- Last 40 transactions per account (`Config.HistoryMax`).

### ATM vs teller

The server cannot see map props, so ATM use is detected client-side and **not** position-verified.
ATMs therefore get tighter per-transaction limits (`Config.Atm`): $5,000 withdraw / deposit,
$10,000 transfer (`AllowTransfer = false` restricts transfers to tellers). A cheater can at most open
the ATM screen from anywhere and move their *own* money within those limits.

## Commands

| Command | Who | What |
|---|---|---|
| `/bank` | anyone | Print account, bank and cash |
| `/bankgive [id] [amount]` | ACE `fivex_bank.staff` | Add to bank |
| `/banktake [id] [amount]` | ACE `fivex_bank.staff` | Remove from bank (floors at 0) |
| `/bankset [id] [amount]` | ACE `fivex_bank.staff` | Set bank balance |

Staff changes are logged to the server console and to the player's history as *Adjustment*.

## Persistence (MySQL via oxmysql)

Requires **oxmysql** (`ensure oxmysql` before this resource). Tables are created on first start, and existing KVP data is imported once (the KVP entries are left untouched).

| Table | Key → value |
|---|---|
| `fivex_bank_balance` | `license` → `balance` (integer dollars) |
| `fivex_bank_account` | `license` → `account` number |
| `fivex_bank_owner` | `account` → `license` (reverse lookup) |
| `fivex_bank_history` | `license` → `entries` (JSON history array) |

## Server exports

```
GetBalance(src) -> int
GetAccount(src) -> string|nil
AddMoney(src, amount, reason) -> newBalance|nil      -- trusted resources only
RemoveMoney(src, amount, reason) -> newBalance|nil   -- trusted resources only, nil if short
```

Trusted = `Config.TrustedResources` (default `fivex_dealership`). Amount 1..`Config.MaxAmount`.
`RemoveMoney` shows as *Purchase* in history, `AddMoney` as *Payment received*.

Client exports: `GetBalance()`, `GetAccount()` (cached from the last server push).

## Events

- `fivex_bank:notify(msg, type)` — client
- `fivex_bank:balance(balance, account)` — client, after transfers in / export / staff changes

## ACE

See `permissions.cfg.example`. Players need no ACE. Parent `fivex_bank` grants all.
