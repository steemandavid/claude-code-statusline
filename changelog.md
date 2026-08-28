# Claude Code Statusline — Changelog

## 2026-08-28 — Anthropic usage now read live from statusLine JSON (fixes stuck "Tok 5%/30%")

The status line had been showing a frozen `Tok 5%/30%` on the Anthropic
backend for months. Root cause: those numbers came from
`~/.anthropic-usage-cache.json`, a **manually** initialized file last written
2026-05-15 — there was no updater (unlike the GLM side, which auto-refreshes
via `update-glm-usage-cache.mjs`), because at the time the script was written
Anthropic exposed no API for subscription quota usage.

That changed: Claude Code v2.1.x passes live rate-limit usage directly in the
statusLine JSON stdin payload (fields `rate_limits.five_hour.used_percentage`
and `rate_limits.seven_day.used_percentage`, populated for Claude.ai
Pro/Max subscribers after the first API response of a session; verified
against the official statusline docs). Installed version here is 2.1.250.

### Changes

- `statusline-command.sh` (repo + `~/.claude/`): Anthropic branch now reads
  `rate_limits` from the stdin JSON only. The manual-cache read was removed
  entirely at the user's request — it provided no information. If
  `rate_limits` is absent, the pre-existing live session-token fallback
  (`Tok: XXk`, covering API-key usage) still applies.
- Deleted `~/.anthropic-usage-cache.json` (stale 5%/30% file).
- Deleted `init-anthropic-usage-cache.sh` from the repo and `~/.claude/` —
  nothing consumes that cache format any more.
- `install.sh`: no longer copies the init script; final notes updated.
- `README.md`: data-sources table, "Anthropic Pro Usage" section, example
  format table and manual-install file list updated to describe the live
  source and drop all cache references.

### Behavior matrix (Anthropic backend, verified with mock JSON)

| statusLine input | Output |
|---|---|
| `rate_limits` present | `Tok 23.5%/41.2%` (live) |
| `rate_limits` absent, session tokens > 0 | `Tok: 16.7k` |
| `rate_limits` absent, no tokens yet | (no token segment) |

### Notes

- `rate_limits` windows can be independently absent, and a window is dropped
  once its `resets_at` passes — absent windows render as `0`.
- ~~Values may be floats (e.g. `23.5`); displayed as-is.~~ — superseded later
  today: values are now rounded to whole percent (see next section).
- The GLM branch was untouched; `update-claude-pro-usage.sh` kept as
  reference (fetches org/tier info only, still no quota API).
- The z.ai backend detection quirk observed while testing: `ANTHROPIC_BASE_URL`
  is set inside Claude Code sessions running on the GLM backend, so testing
  the Anthropic branch requires `env -u ANTHROPIC_BASE_URL`.

## 2026-08-28 — Round Anthropic token percentages to whole numbers

The status line showed float artifacts from the live rate-limit JSON, e.g.
`Tok 28.000000000000004%/56.00000000000001%`. The values are computed
upstream as `used/limit*100` in floating point, so artifacts like this are
routine rather than exceptional.

### Changes

- `statusline-command.sh` (repo): the two Anthropic extractions now pipe
  through jq's `round` filter:
  `.rate_limits.five_hour.used_percentage // 0 | round` (and the
  `seven_day` equivalent), so the output is always a whole percent
  (`Tok 28%/56%`).
- The GLM branch was left alone — its cache percentages are already integers
  from the API, and the bash `-gt` comparisons there assume integers anyway.

### Verification

Mock payload with `28.000000000000004` / `56.00000000000001` under
`env -u ANTHROPIC_BASE_URL` renders `Tok 28%/56%`.

### Note

- The installed copy under `~/.claude/` needs a re-run of `install.sh`
  (or a manual copy) to pick up the fix.

## 2026-08-28 (later) — Fresh-session "missing limits" investigated; symlink repointed at repo

### Investigation: limits absent in fresh sessions (not a bug)

After the rounding fix, a fresh session showed only
`Opus 5 | john@john-ai:/BRMD2026` — no `Cont:` and no `Tok`. Debugging by
temporarily logging the raw statusLine JSON to `~/.claude/statusline-debug.log`
and reproducing confirmed: **`rate_limits` and `context_window` are absent
from the payload until the first API response of a session.** Once one
message gets a response, everything renders normally. Expected Claude Code
behavior; debug logging removed afterwards.

### Root cause of the rounding fix "not working" live: symlink drift

`~/.claude/statusline-command.sh` was a symlink to
`~/claudecode/projects/claudecode-sync/claude/statusline-command.sh`
(Syncthing dir), **not** the `install.sh` target — so repo fixes never
reached the live status line. The synced copy had drifted: it contained the
`rate_limits` code but not the `round` fix.

### Changes

- `~/.claude/statusline-command.sh` symlink repointed at the repo:
  `~/claudecode/projects/claude-code-statusline/statusline-command.sh`.
  Commits now go live immediately on this machine. Verified with a mock
  payload (`Tok 28%/57%`).
- `README.md`: added a note that fresh sessions render a bare status line
  until the first API response (expected), and a deployment note about the
  symlink setup.

### Notes

- Other machines may still consume the synced copy in
  `claudecode-sync/claude/` — copy changes there if so; the sync dir is no
  longer updated automatically from this repo.
- Debug technique for future payload questions: `printf '%s\n' "$input" >> ~/.claude/statusline-debug.log`
  right after `input=$(cat)`, reproduce, inspect, remove.
