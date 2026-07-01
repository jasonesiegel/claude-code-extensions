---
version: 0.2
---
# Changelog

## [0.2] - 2026-06-30

### Added
- **Effort tag** — the session's reasoning effort (`.effort.level`) renders as a light-gray tag (normal weight, secondary to the model) right after the model on line 1 (`Opus 4.8 High`), capitalized as `Low`/`Medium`/`High`/`XHigh`/`Max`. It reflects the live in-session value, including mid-session `/effort` changes, and is hidden entirely on models that don't support the effort parameter. Under width pressure (gated on a dominant session label) it abbreviates but never disappears: after the model version drops, a long level **shortens** (`Medium` → `Med`, any word over four chars → its first three, so future levels never break), but the tag itself is a permanent anchor like the model name — it is never dropped, so the effort signal is always visible. The model name stays anchored throughout.
- **Three-line layout on Pro/Max** — context on line 1, both rate-limit windows on line 2, and git on its own line 3. Line 3 is a reliable home for git because Claude Code draws its permission-mode indicator on a separate row *below* the statusline. On a pay-as-you-go API plan there are no rate-limit windows, so it stays two lines: a clean line 1, with session cost (leading) and git on line 2.
- **Width-responsive compression** — on every render the statusline measures each line against the terminal width (`COLUMNS`, on Claude Code v2.1.153+) and compresses only the lines that overflow, only as far as they need, with no fixed breakpoints and no state kept between renders. Each line sheds its own least-important details first: **line 1** stays intact until a long session label crowds it (the label is ≥ half the line), then drops the model version (`4.8`) and finally the context-window size (`1M`) — the model name (`Opus`) is a permanent anchor that never disappears; **line 2** shrinks its bars 5→3 first (cheap, big recovery — and global, so the context bar shrinks too), then drops the fill %, then the 5h/7d totals; **line 3** (git) compresses only the subfolder — shedding ancestor folders one level at a time (a leading `…/` marks the hidden ones), then truncating the child folder's own characters (only while a branch is present to keep in view), then dropping the subfolder entirely — never the worktree or branch. As a final squeeze, the `·` segment separator collapses to plain spacing on any line that still overflows. A bar's color, its pace, and the front-loaded session label itself never compress. Older Claude Code without `COLUMNS` renders full width as before.
- **Idle-wait indicator** — a `🖐️` and elapsed-time token on line 1 showing how long the session has been waiting on you; appears only while Claude is idle and clears on your next prompt (backed by silent `Stop`/`UserPromptSubmit` hooks keyed by session id).
- **Session-title shortening** — drops the leading verb and any consecutive leading connectives, prepositions, or particles from Claude Code's auto-generated title so the distinguishing words lead (e.g. "Read from Mac Notes app" → "Mac Notes app", "Optimize session title format" → "Session title format"). Only *leading* particles are dropped — a mid-title preposition is preserved ("Switch from Anthropic API **to** subscription" → "Anthropic API to subscription") — and a title that is an interrogative or nothing but a verb plus particles is left intact; the shortener never emits a leading particle or an empty label.
- **Session cost for API plans** — estimated cost in its own cyan, shown **only for API / pay-as-you-go users** where `total_cost_usd` is real spend; suppressed on Pro/Max subscriptions, where it's only an API-equivalent token estimate.
- Fully responsive subdirectory path — shown in full when it fits (`code/acme-api/src/handlers`), then sheds folders outermost-first as the terminal narrows (`…/src/handlers` → `…/handlers`), truncates the child folder to a 3-letter stem only to keep a branch visible (`…/han…`), and drops the subfolder entirely as a last resort — and a 24-character cap (with ellipsis) on long worktree and branch names.
- End-to-end test harness (`test_statusline.sh`).
- **Context-usage stamp** — every render writes the live context-window fill (`<pct> <size> <epoch>`) to `/tmp/pacekit-ctx-<session_id>`, exposing the budget the model can't see itself. Read by the `/context-usage` skill on demand and by wrap-up when choosing the compound-doc mode. Best-effort; a failed write never affects rendering.

### Changed
- Rate-limit windows now show time **elapsed** into each window (counting up toward `5h`/`7d`) instead of time-until-reset, matching the pace indicators.
- **Honest reset handling** — when a window's reset time has passed in the frozen idle snapshot, the (now stale) usage % is replaced with a cycle glyph `↻` and a dim-green empty bar, while the elapsed clock keeps counting into the new window. Because the limits are account-wide, a freshly-reset window's usage is genuinely unknown (not zero), so the `↻` is honest where a `0%` would mislead; the dim green keeps the state from reading as a broken or blank window. Self-corrects on your next message when a fresh snapshot arrives. When **both** windows are just-reset at once, git takes line 2 that turn and there is no line 3 — falling back to the two `↻` windows only when there's no repo info to show.

### Security
- Numeric-only validation of `total_cost_usd` before it enters arithmetic / awk, preventing shell injection via crafted statusline JSON.

## [0.1] - 2026-05-05

### Added
- Two-line statusline showing context usage, 5-hour window, 7-day window, model, worktree, subdirectory, and git branch
- Threshold-colored context fill bar (green < 40%, yellow 40–49%, red 50–59%, violet ≥ 60%)
- Velocity-colored rate-limit bars based on pace = `(usage% / elapsed%) − 1` (green ≤ -10%, yellow -10–0%, red 0–10%, violet > 10%)
- Pace number displayed alongside each rate-limit window (e.g. `(-25%)`, `(+46%)`)
- Time-until-reset display for both 5h and 7d windows
- Auto-hide of line 2 on non-Pro/Max plans (when rate-limit fields aren't sent)
- Worktree basename + subdirectory + branch display, with branch hidden when it duplicates the worktree name
