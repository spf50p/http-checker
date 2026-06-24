# http-checker

Small Bash script that checks HTTP availability of one or more domains.

For each domain it resolves all `A` records via `dig`, then sends a `curl`
request to **every** resolved IP (using `--resolve`, so the right backend is
hit regardless of DNS round-robin) and prints the result. A failed `curl`
request is retried up to `RETRY_COUNT` times (default 3) with `RETRY_INTERVAL`
seconds (default 2) between attempts; only if every attempt fails does it log an
error and optionally send a Telegram notification.

## Requirements

The following binaries must be available in `PATH`:

- `dig` — resolve `A` records
- `curl` — perform the requests
- `jq` — format the `curl` JSON output

## Installation

```sh
sudo curl -fsSL "https://raw.githubusercontent.com/spf50p/http-checker/refs/heads/main/http-checker.sh" \
  -o /usr/local/bin/http-checker.sh \
  && chmod +x /usr/local/bin/http-checker.sh
```

## Configuration

Settings are read from a config file that is **sourced as shell**, so it must
use `KEY=value` syntax. Default path is `.http-checker.conf` in the
current directory; override it with the `HC_CONF` environment variable.

```sh
# .http-checker.conf
DOMAIN=domain1.com,domain2.com,domain3.com   # comma-separated list of domains
SCHEME=https                                 # optional, defaults to https
CURL_TIMEOUT=5                               # optional, connect timeout in seconds
RETRY_COUNT=3                                # optional, attempts before reporting failure
RETRY_INTERVAL=2                             # optional, seconds between retries
TELEGRAM_BOT_TOKEN=<bot-token>               # optional, enables notifications
TELEGRAM_CHAT_ID=<chat-id>                   # optional, enables notifications
TELEGRAM_API_URL=https://api.telegram.org   # optional, Telegram API base URL
```

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | yes | — | Comma-separated list of domains to check |
| `SCHEME` | no | `https` | Request scheme (`http` or `https`) |
| `CURL_TIMEOUT` | no | `5` | Curl connect timeout in seconds |
| `RETRY_COUNT` | no | `3` | Number of attempts per IP before reporting a failure |
| `RETRY_INTERVAL` | no | `2` | Seconds to wait between retries |
| `TELEGRAM_BOT_TOKEN` | no | — | Telegram bot token for notifications |
| `TELEGRAM_CHAT_ID` | no | — | Telegram chat ID for notifications |
| `TELEGRAM_API_URL` | no | `https://api.telegram.org` | Base URL of the Telegram Bot API |
| `HC_CONF` (env) | no | `.http-checker.conf` | Path to the config file |

If both `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set, failures are sent
to Telegram; otherwise a warning is printed and the script continues.

`TELEGRAM_API_URL` lets you point the Bot API requests at a different host
than the default `https://api.telegram.org` — for example a reverse
proxy/mirror used in networks where `api.telegram.org` is blocked. The script
builds the request URL as `${TELEGRAM_API_URL}/bot${TELEGRAM_BOT_TOKEN}/sendMessage`.

## Usage

Check the domains from the config file:

```sh
./http-checker.sh
```

Override the domains via the first argument (takes precedence over the config
file `DOMAIN`):

```sh
./http-checker.sh domain1.com
./http-checker.sh domain1.com,domain2.com
```

Send a test message to verify the Telegram integration:

```sh
./http-checker.sh check-tg
```

## Output

For each resolved IP the script prints a line like:

```
url=https://example.com remote-ip=93.184.216.34 http-code=200 time=0.123456
```

## License

BSD 3-Clause License
