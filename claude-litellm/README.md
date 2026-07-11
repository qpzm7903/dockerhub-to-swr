# claude-litellm

一个自带 **LiteLLM 网关 + Claude Code CLI** 的镜像,用于把 Claude Code 接到任意
OpenAI 兼容后端(公司网关 / DeepSeek 等)。镜像内还带一个 mock 后端和 `verify.sh`,
拉下来就能自检「Claude Code ↔ LiteLLM ↔ OpenAI 转换 + usage」这条链路是否正常。

## 组件成分

* Python 3.12 slim
* Node.js 20
* LiteLLM (`litellm[proxy]`)
* Claude Code CLI (`@anthropic-ai/claude-code`)
* mock OpenAI 后端(离线自检用)

## 构建(CI)

GitHub Actions workflow: `.github/workflows/claude-litellm.yml`(手动 `workflow_dispatch` 触发)
构建后推送到:

* `swr.cn-southwest-2.myhuaweicloud.com/gsc-hub/claude-litellm:<时间戳>-x86_64`
* `ghcr.io/<user>/claude-litellm:<时间戳>-x86_64`

本地构建(注意 build context 是仓库根):

```bash
docker build -f claude-litellm/Dockerfile -t claude-litellm .
```

## 从 SWR 拉取使用(公司 WSL)

```bash
docker pull swr.cn-southwest-2.myhuaweicloud.com/gsc-hub/claude-litellm:<时间戳>-x86_64
IMG=swr.cn-southwest-2.myhuaweicloud.com/gsc-hub/claude-litellm:<时间戳>-x86_64
```

### 1) 离线自检(无需密钥)

```bash
docker run --rm $IMG
```

### 2) 对真实后端自检(以 DeepSeek 为例)

```bash
docker run --rm \
  -e LITELLM_CONFIG=/app/litellm_config.deepseek.yaml \
  -e DEEPSEEK_API_KEY=sk-xxxx \
  -e VERIFY_MODEL=ds-pro \
  -e ANTHROPIC_MODEL=ds-pro \
  -e ANTHROPIC_DEFAULT_SONNET_MODEL=ds-pro \
  -e ANTHROPIC_DEFAULT_HAIKU_MODEL=ds-flash \
  $IMG
```

### 3) 当作常驻网关 + 交互用 Claude Code

```bash
docker run --rm -it -p 4000:4000 \
  -e LITELLM_CONFIG=/app/litellm_config.real.yaml \
  -e BACKEND_API_KEY=sk-xxxx \
  -v $(pwd)/litellm_config.real.yaml:/app/litellm_config.real.yaml \
  $IMG bash
# 进容器后 LiteLLM 已在 :4000 起好:
#   claude -p "hello"
#   curl localhost:4000/v1/messages ...
```

> 密钥一律通过 `-e` 运行时注入,不写入镜像。

## 文件

| 文件 | 作用 |
|------|------|
| `Dockerfile` | 组装镜像(context = 仓库根) |
| `entrypoint.sh` | 起 mock + LiteLLM,健康检查后执行 CMD |
| `verify.sh` | 3 项能力自检(`VERIFY_MODEL` 切模型) |
| `mock_openai_backend.py` | 极简 OpenAI 后端,固定回 PONG + 真实 usage |
| `litellm_config.yaml` | 默认 mock 路由 |
| `litellm_config.deepseek.yaml` | DeepSeek 真实后端路由 |
| `litellm_config.real.example.yaml` | 通用真实后端模板 |
