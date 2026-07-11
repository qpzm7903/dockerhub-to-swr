#!/usr/bin/env bash
# End-to-end verification of: Claude Code -> LiteLLM /v1/messages -> OpenAI
# backend -> back to Anthropic format, with usage flowing through.
set -uo pipefail

BASE="http://localhost:4000"
KEY="${ANTHROPIC_AUTH_TOKEN:-sk-verify-1234}"
MODEL="${VERIFY_MODEL:-mock-sonnet}"   # backend-agnostic: mock-sonnet / ds-pro / ...
pass=0
fail=0
echo "验证使用的 LiteLLM 模型名: $MODEL"

check() {  # check <rc> <label>
  if [ "$1" = "0" ]; then echo "  ✅ $2"; pass=$((pass + 1)); else echo "  ❌ $2"; fail=$((fail + 1)); fi
}

echo "=================================================================="
echo " Test 1: /v1/messages 非流式 — 是否返回 Anthropic 格式 + usage"
echo "=================================================================="
r=$(curl -sS -X POST "$BASE/v1/messages" \
  -H 'content-type: application/json' -H "x-api-key: $KEY" -H 'anthropic-version: 2023-06-01' \
  -d "{\"model\":\"$MODEL\",\"max_tokens\":512,\"messages\":[{\"role\":\"user\",\"content\":\"say pong please\"}]}")
echo "$r" | python3 -m json.tool 2>/dev/null || echo "$r"
echo "$r" | python3 -c '
import sys, json
d = json.load(sys.stdin)
assert d.get("type") == "message", "not an anthropic message: %s" % d
u = d.get("usage", {})
assert u.get("input_tokens", 0) > 0, "input_tokens missing/zero: %s" % u
assert u.get("output_tokens", 0) > 0, "output_tokens missing/zero: %s" % u
print("  -> usage:", u)
'
check $? "非流式: Anthropic message + usage.input_tokens/output_tokens > 0"

echo ""
echo "=================================================================="
echo " Test 2: /v1/messages 流式 — SSE 事件 + message_delta.usage"
echo "=================================================================="
s=$(curl -sS -N -X POST "$BASE/v1/messages" \
  -H 'content-type: application/json' -H "x-api-key: $KEY" -H 'anthropic-version: 2023-06-01' \
  -d "{\"model\":\"$MODEL\",\"max_tokens\":512,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"say pong\"}]}")
echo "$s" | head -30
echo "$s" | grep -q 'event: message_start' && \
echo "$s" | grep -q 'event: message_delta' && \
echo "$s" | grep -q 'output_tokens'
check $? "流式: 含 message_start / message_delta 且带 usage(output_tokens)"

echo ""
echo "=================================================================="
echo " Test 3: Claude Code 端到端 (claude -p 经 LiteLLM)"
echo "=================================================================="
out=$(cd /tmp && claude -p "Reply with exactly one short word." --dangerously-skip-permissions 2>/tmp/claude.err)
rc=$?
echo "  claude -p 退出码: $rc"
echo "  claude -p 输出: [$out]"
# 后端无关: 只要求退出码 0 且有非空输出(证明整条链路打通)
{ [ "$rc" = "0" ] && [ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ]; }
check $? "claude -p 成功经 LiteLLM 拿到后端响应(非空)"

echo ""
echo "=================================================================="
echo "  结果:  PASS=$pass   FAIL=$fail"
echo "=================================================================="
if [ "$fail" != "0" ]; then
  echo ""
  echo "---- /tmp/litellm.log (tail) ----"; tail -40 /tmp/litellm.log 2>/dev/null
  echo "---- /tmp/claude.err (tail) ----"; tail -30 /tmp/claude.err 2>/dev/null
  exit 1
fi
echo "所有能力验证通过 ✅  (Claude Code ↔ LiteLLM ↔ OpenAI 转换 + usage 全链路 OK)"
