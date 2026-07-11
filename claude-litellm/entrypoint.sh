#!/usr/bin/env bash
# Boot the mock backend + LiteLLM proxy, wait until both are healthy,
# then exec whatever command was passed (default: the verify script).
set -e

CONFIG_FILE="${LITELLM_CONFIG:-/app/litellm_config.yaml}"

echo "[entrypoint] starting mock OpenAI backend on :8081"
uvicorn mock_openai_backend:app --host 0.0.0.0 --port 8081 --log-level warning \
  > /tmp/mock.log 2>&1 &

echo "[entrypoint] starting LiteLLM proxy on :4000 (config: $CONFIG_FILE)"
litellm --config "$CONFIG_FILE" --port 4000 > /tmp/litellm.log 2>&1 &

wait_for() {
  local name="$1" url="$2" tries="$3"
  for _ in $(seq 1 "$tries"); do
    if curl -sf "$url" >/dev/null 2>&1; then
      echo "[entrypoint] $name is up"
      return 0
    fi
    sleep 1
  done
  echo "[entrypoint] ERROR: $name did not become healthy ($url)"
  return 1
}

wait_for "mock-backend" "http://localhost:8081/health" 30 || { tail -20 /tmp/mock.log; exit 1; }
wait_for "litellm-proxy" "http://localhost:4000/health/liveliness" 90 || { tail -40 /tmp/litellm.log; exit 1; }

echo "[entrypoint] all services up — running: $*"
exec "$@"
