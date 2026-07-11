"""Minimal OpenAI-compatible backend used to verify the conversion chain.

LiteLLM translates Claude Code's Anthropic request into an OpenAI
`/v1/chat/completions` call and hits this server. We return a deterministic
reply ("PONG") plus a real `usage` block so we can prove that token usage
flows all the way back to Claude Code — the exact thing that was broken in
claude-code-router v2.
"""

import json

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, StreamingResponse

app = FastAPI()

REPLY = "PONG"


def sse(obj: dict) -> str:
    return "data: " + json.dumps(obj) + "\n\n"


def estimate_prompt_tokens(body: dict) -> int:
    """Crude but non-zero token estimate from the serialized messages."""
    text = json.dumps(body.get("messages", []))
    return max(1, len(text) // 4)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/v1/models")
def models():
    ids = ["mock-sonnet", "mock-haiku", "mock-opus"]
    return {"object": "list", "data": [{"id": i, "object": "model", "owned_by": "mock"} for i in ids]}


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.json()
    model = body.get("model", "mock")
    prompt_tokens = estimate_prompt_tokens(body)
    completion_tokens = len(REPLY.split())
    usage = {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": prompt_tokens + completion_tokens,
    }

    if body.get("stream"):
        def generate():
            base = {"id": "chatcmpl-mock", "object": "chat.completion.chunk", "created": 0, "model": model}
            yield sse({**base, "choices": [{"index": 0, "delta": {"role": "assistant"}, "finish_reason": None}]})
            yield sse({**base, "choices": [{"index": 0, "delta": {"content": REPLY}, "finish_reason": None}]})
            yield sse({**base, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]})
            if (body.get("stream_options") or {}).get("include_usage"):
                yield sse({**base, "choices": [], "usage": usage})
            yield "data: [DONE]\n\n"

        return StreamingResponse(generate(), media_type="text/event-stream")

    return JSONResponse({
        "id": "chatcmpl-mock",
        "object": "chat.completion",
        "created": 0,
        "model": model,
        "choices": [{"index": 0, "message": {"role": "assistant", "content": REPLY}, "finish_reason": "stop"}],
        "usage": usage,
    })
