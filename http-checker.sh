#!/usr/bin/env bash

set -eo pipefail

HC_CONF=${HC_CONF:-.http-checker.conf}

if [[ -f "$HC_CONF" ]]; then
  source "$HC_CONF"
fi

if [[ -n "$1" ]]; then
  DOMAIN=$1
fi

SCHEME=${SCHEME:-https}
CURL_PORT=${CURL_PORT:-443}
CURL_TIMEOUT=${CURL_TIMEOUT:-5}
RETRY_COUNT=${RETRY_COUNT:-3}
RETRY_INTERVAL=${RETRY_INTERVAL:-2}
TELEGRAM_API_URL=${TELEGRAM_API_URL:-https://api.telegram.org}

log_info() {
  local message=$1
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] [INFO] $message"
}

log_error() {
  local message=$1
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] [ERROR] $message"
}

log_warning() {
  local message=$1
  echo "[$(date +%Y-%m-%d\ %H:%M:%S)] [WARNING] $message"
}

send_telegram_message() {
  local message=$1

  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    if ! curl --connect-timeout "$CURL_TIMEOUT" -fsX POST "${TELEGRAM_API_URL}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${message}" >/dev/null 2>&1; then
      log_error "Failed to send Telegram message"
    fi
    return 0
  fi

  log_warning "TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are not set"
}

check_domain() {
  local domain=$1
  local scheme=$2

  result=$(dig +short "$domain" A)

  if [[ -z $result ]]; then
    log_error "No IP found for $domain"
    send_telegram_message "No IP found for $domain"
    return 1
  fi

  for ip in $result; do
    local attempt=1
    while true; do
      if curl -fs --connect-timeout "$CURL_TIMEOUT" --resolve "$domain:$CURL_PORT:$ip" \
         "$scheme://$domain" -o /dev/null -w '%{json}' | \
         jq -r '"url=\(.url) remote-ip=\(.remote_ip) http-code=\(.http_code) time=\(.time_total)"'; then
        break
      fi

      if [[ $attempt -ge $RETRY_COUNT ]]; then
        log_error "curl failed for $domain ($ip) after $attempt attempts"
        send_telegram_message "curl failed for $domain ($ip) after $attempt attempts"
        break
      fi

      log_warning "curl failed for $domain ($ip), attempt $attempt/$RETRY_COUNT, retrying in ${RETRY_INTERVAL}s"
      attempt=$((attempt + 1))
      sleep "$RETRY_INTERVAL"
    done
  done
}

if ! command -v dig >/dev/null 2>&1; then
  log_error "dig is not installed"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  log_error "curl is not installed"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  log_error "jq is not installed"
  exit 1
fi

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 [domain1[,domain2,...]]"
  exit 1
fi

if [[ "$DOMAIN" == "check-tg" ]]; then
  send_telegram_message "Hello World, I'm from https://github.com/spf50p/http-checker"
  exit 0
fi

log_info "Starting..."

for domain in ${DOMAIN//,/ }; do
  check_domain "$domain" "$SCHEME"
done

log_info "Finished."
