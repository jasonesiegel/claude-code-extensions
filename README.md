# claude-code-extensions

A collection of Claude Code extensions by [Jason Siegel](https://github.com/jasonesiegel).

This repo contains two kinds of extensions, which install **differently**:

- **Scripts** — single-file utilities (e.g. statuslines) you wire into `~/.claude/settings.json`. Clone this repo and point `settings.json` at the script.
- **Plugins** — Claude Code plugins installed via `/plugin marketplace add`. **None published yet** — this repo is not a plugin marketplace today. `/plugin marketplace add jasonesiegel/claude-code-extensions` will not work until the first plugin ships.

## Scripts

- **[pacekit-statusline/](./pacekit-statusline)** — Two-line statusline with velocity-based pace coloring for context + 5-hour / 7-day rate-limit windows. See its README for install steps.

## Plugins

None yet. The first plugin (`chatroom` — peer-to-peer collaboration) is in progress; once it lands, this repo will also be installable as a marketplace.

## License

Each extension carries its own LICENSE. The umbrella repo is MIT; see `LICENSE`.