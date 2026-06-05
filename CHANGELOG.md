# Changelog

All notable changes to HermesShell are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.1] — 2026-05-29

### Added

- **Operator-tunable Hermes env vars are now forwarded from the host shell into the sandbox.** Setting `HERMES_KANBAN_CLAIM_TTL_SECONDS`, `HERMES_API_TIMEOUT`, or `HERMES_API_CALL_STALE_TIMEOUT` in your shell before running `hermesshell onboard` (or `hermesshell rebuild`) automatically passes the value to the sandbox via `openshell sandbox create -- env KEY=VALUE`. See [docs/compatibility.md](docs/compatibility.md) for details.

### Changed

- **Bumped pinned Hermes Agent from `v2026.5.7` (v0.13.0) to `v2026.5.29.2` (v0.15.2)** — pulls in v0.14.0 (Foundation), v0.15.0 (Velocity), v0.15.1 (Patch), and v0.15.2 (packaging). See upstream notes: <https://github.com/NousResearch/hermes-agent/releases>.
- **Replaced TUI bundle staleness sed patch with `HERMES_TUI_DIR`.** The Dockerfile no longer sed-edits `ui-tui/packages/hermes-ink/package.json` and no longer pre-installs TUI npm dependencies; setting `HERMES_TUI_DIR=/opt/hermes/ui-tui` makes `_make_tui_argv` check `dist/entry.js` and skip the staleness loop, which is required for OpenShell's read-only `/opt/hermes`.
- **Removed kanban TTL sed patch from the public image.** The Dockerfile no longer sed-edits `hermes_cli/kanban_db.py` and no longer sets `HERMES_KANBAN_CLAIM_TTL_SECONDS`. Operators who need a non-default heartbeat TTL set the env var in their host shell before running `hermesshell onboard`/`rebuild` (see Added).
- **README architecture diagram replaced** with a Mermaid multi-sandbox flowchart; the static `assets/architecture.png` is removed.

### Fixed

- **`hermesshell rebuild` no longer bails on missing env vars.** It now propagates `provider`, `model`, and `tier` from the stashed registry entry into the environment before invoking the non-interactive `onboardCommand`, so users no longer have to hand-set `HERMESSHELL_PROVIDER=... HERMESSHELL_MODEL=...` to recover from a rebuild.
- **`hermesshell --version`** now reads from the `HERMESSHELL_VERSION` constant in [cli/src/lib/constants.ts](cli/src/lib/constants.ts), keeping it in sync with `package.json` instead of a hard-coded `"0.0.50"` string.


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

[Unreleased]: https://github.com/ppritcha/hermesshell/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/ppritcha/hermesshell/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ppritcha/hermesshell/releases/tag/v1.0.0
