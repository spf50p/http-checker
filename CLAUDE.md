# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A single-file Bash script (`http-checker.sh`) that checks HTTP availability of one
or more domains. For each domain it resolves all `A` records via `dig`, then sends
a `curl` request to **every** resolved IP using `curl --resolve` (so each backend
behind DNS round-robin is hit directly). Failures are logged and optionally pushed
to Telegram. There is no build system, dependency manager, or test suite — the whole
program is the script.

## Running

```sh
./http-checker.sh                       # check domains from the config file
./http-checker.sh domain1.com           # override DOMAIN (arg wins over config)
./http-checker.sh domain1.com,dom2.com  # comma-separated list
./http-checker.sh check-tg              # send a test Telegram message
HC_CONF=/path/to/conf ./http-checker.sh # use a non-default config path
```

Runtime requirements (must be in `PATH`): `dig`, `curl`, `jq`. The script checks
for each and exits 1 if missing.

## Configuration

Config is **sourced as shell**, so it must be valid `KEY=value` Bash. Default path
is `.http-checker.conf` in the cwd; override with the `HC_CONF` env var. Keys:
`DOMAIN` (required, comma-separated), `SCHEME` (default `https`), `CURL_PORT`
(default 443), `CURL_TIMEOUT` (default 5), `RETRY_COUNT` (default 3),
`RETRY_INTERVAL` (default 2),
`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `TELEGRAM_API_URL`
(default `https://api.telegram.org`). Telegram notifications fire only when both
token and chat id are set; otherwise a warning is printed and the run continues.

`.http-checker.conf` is gitignored because it holds secrets — do not commit it or
copy its real token/chat-id values into tracked files. Note the committed working
copy uses `BASE_TELEGRAM_URL`, but the script actually reads `TELEGRAM_API_URL`.

## Architecture notes / gotchas

- `set -eo pipefail` is enabled. `check_domain` failures are caught locally (the
  `curl ... | jq` pipeline is guarded inside a retry loop), so one bad IP does not
  abort the whole run.
- Each per-IP `curl` is retried up to `RETRY_COUNT` times (default 3) with
  `RETRY_INTERVAL` seconds (default 2) between attempts. Intermediate failures log a
  `Warning`; Telegram fires only after the final attempt fails. The `dig` "No IP
  found" path is **not** retried — it notifies immediately.
- `check_domain` uses `--resolve "$domain:$CURL_PORT:$ip"` (`CURL_PORT` default 443).
  `CURL_PORT` is independent of `SCHEME`, so when setting `SCHEME=http` also set
  `CURL_PORT=80`.
- Output format comes from the `jq` filter on `curl -w '%{json}'`:
  `url=... remote-ip=... http-code=... time=...`. Update the filter to change output.
- When editing the script, keep the README's configuration table and the variable
  defaults in `http-checker.sh` (lines ~15-17) in sync.
