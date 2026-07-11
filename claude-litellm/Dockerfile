FROM python:3.12-slim

# --- system + Node.js 20 (for Claude Code CLI) ---
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates gnupg \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Python: LiteLLM proxy + mock backend deps ---
RUN pip install --no-cache-dir "litellm[proxy]" fastapi uvicorn

# --- Claude Code CLI ---
RUN npm install -g @anthropic-ai/claude-code

# Run as non-root so `claude --dangerously-skip-permissions` is permitted.
RUN useradd --create-home --uid 1000 app

WORKDIR /app
# NOTE: build context is the repo root (docker build -f claude-litellm/Dockerfile .)
COPY claude-litellm/mock_openai_backend.py \
     claude-litellm/litellm_config.yaml \
     claude-litellm/litellm_config.real.example.yaml \
     claude-litellm/litellm_config.deepseek.yaml \
     claude-litellm/entrypoint.sh \
     claude-litellm/verify.sh \
     /app/
RUN chmod +x /app/entrypoint.sh /app/verify.sh

# Skip Claude Code first-run onboarding so `claude -p` runs headless.
RUN printf '%s' '{"hasCompletedOnboarding":true}' > /home/app/.claude.json \
 && chown -R app:app /home/app /app

USER app

# Point Claude Code at the in-container LiteLLM proxy and map the 3 model tiers.
ENV ANTHROPIC_BASE_URL=http://localhost:4000 \
    ANTHROPIC_AUTH_TOKEN=sk-verify-1234 \
    ANTHROPIC_MODEL=mock-sonnet \
    ANTHROPIC_DEFAULT_SONNET_MODEL=mock-sonnet \
    ANTHROPIC_DEFAULT_HAIKU_MODEL=mock-haiku \
    ANTHROPIC_DEFAULT_OPUS_MODEL=mock-opus

EXPOSE 4000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/verify.sh"]
