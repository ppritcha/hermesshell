# HermesShell — Feature Reference

Complete reference for all features, capabilities, and CLI commands.

---

## Table of Contents

1. [Sandbox Security](#sandbox-security)
2. [Policy Management](#policy-management)
3. [Inference Routing](#inference-routing)
4. [Sandbox Lifecycle](#sandbox-lifecycle)
5. [Hermes Agent Capabilities](#hermes-agent-capabilities)
6. [Messaging Gateway](#messaging-gateway)
7. [Memory System](#memory-system)
8. [Skills System](#skills-system)
9. [hermesshell CLI Reference](#hermesshell-cli-reference)
10. [Python SDK](#python-sdk)
11. [Docker / Deployment](#docker--deployment)

---

## Sandbox Security

OpenShell enforces security at the kernel level — **below the application layer**. Even a fully compromised Hermes process cannot override these limits.

### Four enforcement layers

| Layer | Mechanism | Locked at creation? |
|-------|-----------|:-------------------:|
| Filesystem | Landlock LSM | Yes |
| Process | Seccomp BPF + unprivileged user | Yes |
| Network | OPA + HTTP CONNECT proxy | No (hot-reloadable) |
| Inference | Privacy router (credential injection) | No (hot-reloadable) |

### What is blocked by default

- **Network**: all outbound traffic except `inference.local` (configured per policy)
- **Filesystem**: everything except `~/.hermes/`, `/sandbox/`, `/tmp/`, and system read-only paths
- **Syscalls**: `ptrace`, `mount`, `umount2`, `kexec_load`, `perf_event_open`, `process_vm_readv`, `process_vm_writev`
- **Privilege escalation**: agent runs as non-root user `hermes:hermes`

---

## Policy Management

### Policy tiers

Tiers are defined in [`openshell/tiers.yaml`](../openshell/tiers.yaml) and composed from individual presets in [`openshell/presets/`](../openshell/presets/). The onboard wizard picks a tier; presets can be added or removed on a live sandbox without restart.

| Tier | Default presets | Description |
|------|-----------------|-------------|
| `restricted` | *(none)* | Inference only — no third-party network egress. Most secure. |
| `balanced` | `npm`, `pypi`, `huggingface`, `brave`, `github` | Full dev tooling + web search. No messaging platforms. |
| `open` | `balanced` + `slack`, `discord`, `telegram` | Broad access including messaging gateways. |

Available presets: `npm`, `pypi`, `huggingface`, `brave`, `github`, `slack`, `discord`, `telegram`.

The baseline filesystem / process / inference policy (always applied beneath the tier presets) lives in [`openshell/hermesshell-policy.yaml`](../openshell/hermesshell-policy.yaml) and is wired through [`openshell/hermesshell-profile.yaml`](../openshell/hermesshell-profile.yaml).

### Apply or change a policy

```bash
# Pick a tier at onboard time (creates a sandbox with that tier's presets):
hermesshell onboard --policy-tier restricted

# Add or remove a preset on a running sandbox (hot-reload, no restart):
hermesshell mybot policy add github
hermesshell mybot policy remove slack
hermesshell mybot policy list

# Inspect current policy via OpenShell directly:
openshell policy get hermesshell-1 --full

# View policy history:
openshell policy list hermesshell-1
```

### Policy YAML schema

```yaml
version: 1

filesystem_policy:
  include_workdir: true     # auto-include agent working dir
  read_only:
    - /usr
    - /etc/ssl
  read_write:
    - /opt/data
    - /sandbox
    - /tmp

landlock:
  compatibility: best_effort   # or hard_requirement

process:
  run_as_user: hermes          # cannot be "root"
  run_as_group: hermes

network_policies:
  policy_name:
    endpoints:
      - host: "api.example.com"
        port: 443
        enforcement: enforce   # or audit
        access: full           # or read-only, read-write
        rules:
          - method: "POST"
            path: "/v1/chat/completions"
    binaries:
      - path: "/usr/local/bin/hermes*"   # glob supported
```

---

## Inference Routing

OpenShell's privacy router intercepts every call to `https://inference.local` inside the sandbox, strips the agent's credentials, and forwards to the configured backend.

### Configure providers

```bash
# Local llama.cpp
openshell provider create --name local-llama --type openai \
  --credential OPENAI_API_KEY=not-needed \
  --config OPENAI_BASE_URL=http://127.0.0.1:8080/v1

# NVIDIA API Catalog
openshell provider create --name nvidia-prod --type nvidia --from-existing

# OpenAI
openshell provider create --name openai-prod --type openai --from-existing

# Anthropic
openshell provider create --name anthropic-prod --type anthropic --from-existing

# Ollama (local)
openshell provider create --name local-ollama --type openai \
  --credential OPENAI_API_KEY=dummy \
  --config OPENAI_BASE_URL=http://host.openshell.internal:11434/v1
```

### Switch inference backend (hot-reload, no restart)

```bash
openshell inference set --provider local-llama --model qwen3-4b
openshell inference set --provider nvidia-prod --model nemotron-4-340b-instruct
openshell inference set --provider anthropic-prod --model claude-sonnet-4-6
openshell inference get   # verify
```

---

## Sandbox Lifecycle

### Full command reference

```bash
# Start
hermesshell start                         # OpenShell or Docker depending on availability
hermesshell start --gpu                   # Pass NVIDIA GPU to sandbox
hermesshell start --policy permissive     # Use permissive policy preset

# Connect and inspect
hermesshell connect                       # Interactive shell inside sandbox
hermesshell logs                          # View logs
hermesshell logs --follow                 # Stream logs
openshell term                           # Live monitoring dashboard (TUI)

# File transfer
openshell sandbox upload hermesshell-1 ./local-file.txt /sandbox/file.txt
openshell sandbox download hermesshell-1 /opt/data/MEMORY.md ./memory-backup.md

# Port forwarding
openshell forward start hermesshell-1 --local 9090 --remote 9090

# Remote deployment
openshell gateway start --remote user@gpu-server
openshell gateway select my-remote-gateway
hermesshell start   # now creates sandbox on remote machine

# Stop / cleanup
hermesshell stop                          # Stop sandbox (memories preserved)
hermesshell uninstall                     # Remove image (memories preserved)
```

---

## Hermes Agent Capabilities

HermesShell runs the full Hermes Agent stack inside the sandbox. All 40+ tools are available (subject to the active network policy).

### Tool categories

| Category | Tools | Network policy needed |
|----------|-------|----------------------|
| Web | `web_search`, `web_extract`, `browser_*` | `web_search` policy |
| Terminal | `terminal`, `process`, `execute_code` | None |
| Files | `read_file`, `patch`, `file_search`, `file_grep` | None |
| Memory | `memory`, `session_search`, `honcho` | None |
| Vision | `vision_analyze`, `image_crop`, `browser_vision` | None (local model) |
| Voice | `text_to_speech` | None (local) |
| Image gen | `image_generate` | Optional API |
| Messaging | `send_message`, `background_notify` | Gateway policy |
| Skills | `skill_manage` (`create`, `patch`, `edit`, `delete`) | Optional GitHub |
| Planning | `todo`, `clarify`, `delegate_task` | None |
| Scheduling | `cronjob` | None |
| AI | `moa`, `rl_train` | Inference only |
| MCP | `mcp_tool` | Per-MCP-server policy |

### In-session commands

```
/model         Switch provider/model mid-session
/tools         Manage active tools
/skills browse Browse available skills
/personality   Switch persona (focused, researcher, etc.)
/reasoning     Set reasoning level (low/medium/high)
/voice on      Enable voice mode
/plan          Generate implementation plan
/rollback      Rollback to previous checkpoint
/stop          Stop active agent run
/background    Run task in background
```

---

## Messaging Gateway

Run `hermes gateway` inside the sandbox to handle messages from all platforms.

**Required presets:** `telegram`, `discord`, `slack` (per platform). The `open` tier ships with all three already enabled, or add them individually on any sandbox:

```bash
hermesshell mybot policy add telegram
hermesshell mybot policy add discord
hermesshell mybot policy add slack
```

### Setup

```bash
# Interactive setup (run inside sandbox)
hermesshell connect
hermes gateway

# Or configure manually in ~/.hermes/config.yaml
# Tokens in ~/.hermes/.env
```

### Supported platforms

| Platform | Bot creation | Voice notes | Threading | Groups |
|----------|-------------|:-----------:|:---------:|:------:|
| Telegram | @BotFather | ✅ | ✅ | ✅ |
| Discord | Developer Portal | ✅ | ✅ | ✅ |
| Signal | signal-cli bridge | ✅ | - | ✅ |
| Slack | Workspace app | - | ✅ | ✅ |
| WhatsApp | QR pairing | ✅ | - | ✅ |
| Email | IMAP/SMTP | - | - | - |

### User authorization

```bash
# Generate pairing code (users send this in DM)
hermes pairing

# Allow all users on a platform (not recommended for public bots)
# Set allow_all: true in gateway config
```

---

## Memory System

Hermes maintains two memory files, loaded into every session:

| File | Size | Contents |
|------|------|----------|
| `~/.hermes/memories/MEMORY.md` | ~800 tokens | Environment facts, conventions, lessons learned |
| `~/.hermes/memories/USER.md` | ~500 tokens | Your profile, preferences, communication style |

Memory is **persisted on the host** via the volume mount — survives sandbox recreation.

### Session search

All past sessions are stored in SQLite with FTS5 full-text search:

```bash
hermes sessions search "how to configure Telegram"
hermes sessions list
hermes sessions browse
```

---

## Skills System

Skills are reusable procedures Hermes creates, stores, and improves over time.

```
~/.hermes/skills/
  skill-name/
    SKILL.md          # Description + procedure
    references/       # Reference docs
    scripts/          # Helper scripts
    templates/        # File templates
```

### Auto-creation

Hermes creates skills automatically after complex tasks (5+ tool calls). Skills improve via **DSPy + GEPA** (Genetic-Pareto Prompt Evolution) — no GPU required, costs $2–10/run.

```bash
# Manage skills
hermes skills list
hermes skills search "deployment"
hermes skills install skill-name
hermes skills browse
hermes skills publish my-skill

# Audit installed skills
hermes skills audit
```

---

## hermesshell CLI Reference

```
hermesshell help                      Display this help
hermesshell onboard                   First-time setup and status check
hermesshell start [--gpu] [--policy]  Start sandbox (OpenShell) or docker compose
hermesshell stop                      Stop sandbox (memories preserved)
hermesshell status                    Show inference config + memory/skill counts
hermesshell connect                   Open interactive shell in sandbox
hermesshell logs [--follow]           Stream sandbox logs
hermesshell NAME policy list          List active presets on a sandbox
hermesshell NAME policy add PRESET    Hot-add a preset to a running sandbox
hermesshell NAME policy remove PRESET Hot-remove a preset from a running sandbox
hermesshell doctor                    Run end-to-end diagnostics
hermesshell chat "prompt"             One-shot message to Hermes
hermesshell version                   Print version info
hermesshell uninstall                 Remove Docker image (memories preserved)
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMESSHELL_SANDBOX` | `hermesshell-1` | Sandbox name |

---

## Python SDK

Use Hermes programmatically in any Python application:

```python
from run_agent import AIAgent

agent = AIAgent(
    model="local",                         # or "anthropic/claude-opus-4-6"
    enabled_toolsets=["web", "terminal", "memory", "skills"],
    ephemeral_system_prompt="You are a helpful assistant.",
    max_iterations=90,
    skip_memory=False,                     # load MEMORY.md + USER.md
)

# Single-turn
response = agent.chat("Summarise the files in /sandbox")
print(response)

# Multi-turn
history = []
result = agent.run_conversation("Research this topic", conversation_history=history)
history = result["history"]
result2 = agent.run_conversation("Now write a report", conversation_history=history)
```

---

## Docker / Deployment

### Quick start

```bash
cp .env.example .env         # fill in MODEL_FILE and optional tokens
docker compose up            # CPU inference
docker compose --profile gpu up  # NVIDIA GPU inference
```

### GPU mode

Requires NVIDIA Container Toolkit. Uses `llama.cpp:server-cuda` image.

```bash
# In .env:
N_GPU_LAYERS=99
```

### Volumes

| Volume | Contents | Persists |
|--------|----------|:--------:|
| `hermesshell-memories` | Hermes memories | ✅ |
| `hermesshell-skills` | Hermes skills | ✅ |
| `./knowledge` | User docs (read-only mount) | On host |
| `./models` | Model weights (read-only mount) | On host |

### Environment variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_FILE` | `Qwen3-4B-Q4_K_M.gguf` | Model filename in `models/` |
| `N_GPU_LAYERS` | `0` | GPU layers (0 = CPU, 99 = all GPU) |
| `CTX_SIZE` | `32768` | Context window for llama-server (ignored by Ollama) |
| `LLAMA_PORT` | `8080` | llama.cpp port |
| `HERMESSHELL_PORT` | `8090` | HermesShell gateway webhook port |
| `TELEGRAM_BOT_TOKEN` | — | Telegram bot token |
| `DISCORD_BOT_TOKEN` | — | Discord bot token |
| `SLACK_BOT_TOKEN` | — | Slack bot token |
| `HERMES_PRIVACY_THRESHOLD` | `0.0` | 0=local only, 1=cloud only, 0.7=auto |
| `HERMES_APPROVAL_MODE` | `smart` | `manual`, `smart`, or `off` |
