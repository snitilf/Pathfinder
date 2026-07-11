# Pathfinder v1.0

Date: 2026-07-11. Static checks, dry-run, and documentation citations for the pathfinder tree as shipped.

Items not exercised are marked **not exercised**, not rounded up.

---

## 1. Documentation citations (settings and hooks)

### 1.1 `model: "best"`

**Kept** in `templates/settings.snippet.json`.

**Source:** https://code.claude.com/docs/en/model-config (Model aliases table, fetched 2026-07-11).

> **`best`** - Uses Fable 5 where your organization has access to it, otherwise the latest Opus model

### 1.2 `fallbackModel` as a JSON array

**Kept** as `["opus", "sonnet"]` in `templates/settings.snippet.json`.

**Source:** same page, section **Fallback model chains**.

> To persist a chain across sessions, set `fallbackModel` in settings as an array:

```json
{
  "fallbackModel": ["claude-sonnet-5", "claude-haiku-4-5"]
}
```

### 1.3 Hook events, payload fields, and `async`

**Source:** https://code.claude.com/docs/en/hooks (fetched 2026-07-11). See also `templates/hooks/pathfinder-telemetry.md`.

| Claim | Documented |
|---|---|
| Events `SubagentStart`, `SubagentStop`, `SessionEnd` | Yes (event table) |
| `session_id`, `agent_id`, `agent_type` | Yes (common / SubagentStart-Stop input) |
| `last_assistant_message`, `agent_transcript_path` | Yes (SubagentStop input) |
| `reason` | Yes (SessionEnd input) |
| Command hook `async: true` | Yes (command hook fields) |
| Token counts / duration | Not claimed |

---

## 2. Static checks

| Check | Method | Result |
|---|---|---|
| Agent count = 7 | `ls templates/agents/*.md \| wc -l` | **7** |
| Default assembly markers | cat header+core+verification+footer | **begin=1 end=1** |
| Working-style excluded from default | grep assembly | **0 matches** |
| Policy prose model names | grep on `10-core.md`, `20-verification.md` | **CLEAN** |
| scout/Explore allowlist | frontmatter | `Read, Glob, Grep` |
| light-verifier / verifier write denylist | frontmatter | Write, Edit, NotebookEdit, Agent, Workflow denied |
| Product naming greps clean | greps excluding .git and ignored local dirs | **CLEAN** |
| Settings snippet | read | `model: best`, `fallbackModel: ["opus","sonnet"]` |

---

## 3. Install dry-run (8 items)

Environment: temp `$HOME`, Claude Code **2.1.207**, pathfinder checkout.

| # | Item | Exercised? | Outcome |
|---|---|---|---|
| 1 | Preflight version | **Yes** | `2.1.207` meets min `2.1.198` |
| 2 | Plan-then-approve before write | **Partially** | Runbook convention only; no real-home write |
| 3 | Marker install / upgrade | **Yes** | Fresh assembly into CLAUDE.md: pathfinder begin=1 end=1. Install is pathfinder-only; ambiguous marker counts stop and ask. |
| 4 | Customized agent diff-and-ask | **Yes** | Differing `scout.md` left custom; no silent clobber |
| 5 | Settings: ask before non-target model change | **Yes** | Existing `model: sonnet` left; `fallbackModel` added |
| 6 | Verify markers, seven agents, VERSION | **Yes** | 7 agents, begin=1, VERSION 1.0.0; diag ok |
| 7 | Hooks install path | **Partially** | Opt-in not merged; helper/stats smoke-tested. Live session hooks: **not exercised** |
| 8 | Uninstall reverse path | **Not exercised** on a real machine | Documented in `install/AGENT-INSTALL.md` only |

---

## 4. Ten success criteria

| # | Criterion | Evidence | Status |
|---|---|---|---|
| 1 | Config layer, not runtime product | `README.md`; templates + runbook | **Pass** |
| 2 | Seven roles only | `templates/agents/` count 7 | **Pass** |
| 3 | Research/design present; shorter user docs | `docs/research.md`, `docs/design.md`, `README.md` | **Pass** |
| 4 | Best-effort observability with limits | log helper + hooks doc; honesty language | **Pass** (live hooks session: **not exercised**) |
| 5 | Tiered verification | `templates/claude-md/20-verification.md` | **Pass** |
| 6 | Optional project config | `examples/.pathfinder/config.json` | **Pass** |
| 7 | Install/update/diag honest approval | runbook + diag script; dry-run 1-6 | **Pass** (live approval / real uninstall: **not exercised**) |
| 8 | Working-style opt-in | default assembly excludes it; repo `CLAUDE.md` present | **Pass** |
| 9 | No external-supervisor dependency | design appendix future-correlation note only | **Pass** |
| 10 | Core principles intact | role-only policy; leaf tools; security role; aliases | **Pass** |

---

## 5. Install runbook must-have checklist

Confirmed present:

- Preflight version gate **2.1.198**
- Approval as convention (not enforcement) wording
- Pathfinder-only marker census; stop-and-ask on ambiguous counts
- Agent diff-and-ask; never silent clobber
- Backups under `~/.claude/backups/`
- Uninstall section
