# Changelog

All notable changes to HermesShell are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] — 2026-05-27

Initial public release.

### Added

- **TypeScript CLI (`hermesshell`)** — commander-based command tree with `onboard`, `chat`, `connect`, `logs`, `status`, `list`, `policy add/remove/list`, `snapshot`, `rebuild`, `destroy`, `backup-all`, `credentials`, `doctor`, and `uninstall`. Installed via `npm link` from `scripts/install.sh`.
- **Multi-sandbox lifecycle** — manage any number of isolated Hermes agents from a single host, each with its own credentials, persona, memory, skills, and policy. Onboard, list, snapshot, restore, and destroy sandboxes independently.
- **Interactive onboard wizard** — walks through inference provider selection (NVIDIA NIM, OpenAI, Anthropic, Gemini, Ollama, llama.cpp, or any OpenAI-compatible endpoint), model and credentials configuration, policy tier selection, and sandbox creation in one flow.
- **Composable policy tiers and presets** — three tiers (`restricted`, `balanced`, `open`) composed from individual network presets (`npm`, `pypi`, `huggingface`, `brave`, `github`, `slack`, `discord`, `telegram`). Add or remove presets on a running sandbox without restart via `hermesshell <name> policy add/remove`.
- **OpenShell kernel-enforced sandbox** — Landlock (filesystem), seccomp (syscall), and OPA + L7 proxy (network egress) enforced out-of-process so a compromised agent cannot override them. Docker-only fallback available for non-Linux hosts.
- **Persistent per-sandbox memory** — Hermes `MEMORY.md`, `USER.md`, and skill artifacts survive sandbox restarts, snapshots, and rebuilds via host-mounted volumes.
- **Skills library** — `anomaly-detection`, `market-alerts`, `code-review`, `slack-support`, `home-assistant`, `research-digest`, installable individually or in bulk via `skills/install.sh`.
- **Diagnostics** — `hermesshell doctor [--quick]` performs provider-aware inference health checks, Docker image inspection, config and policy parse, memory/skill counts, and a chat round-trip.
- **Use-case documentation** — seven end-to-end deployment guides under `docs/use-cases/` covering researcher, developer, home automation, data analyst, small business, privacy-regulated, and trader scenarios.

[Unreleased]: https://github.com/ppritcha/hermesshell/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ppritcha/hermesshell/releases/tag/v1.0.0
