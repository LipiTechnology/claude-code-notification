# claude-code-notification-hook

A [Claude Code](https://claude.com/claude-code) **Stop hook** for macOS. When a turn ends it fires a
native notification — and instead of a generic "task finished", it shows a one-line summary of what
the turn actually accomplished. Click the notification to jump back to your editor.

```
┌──────────────────────────────────────────────────────┐
│ Claude Code                                          │
│ Added context-aware flag and config variables        │  ← generated from the turn
└──────────────────────────────────────────────────────┘
```

## Requirements

- **macOS**
- [`alerter`](https://github.com/vjeantet/alerter) — `brew install vjeantet/tap/alerter`
- The `claude` CLI on your `PATH`
- `python3` (ships with the Xcode Command Line Tools)
- _Optional:_ `coreutils` (`brew install coreutils`) for `gtimeout`, used as a safety timeout on the
  summary call. Without it the call simply runs untimed.

## Install

This is a Claude Code **plugin**. Add the repo as a marketplace, then install:

```
/plugin marketplace add LipiTechnology/claude-code-notification
/plugin install claude-code-notification-hook
```

Claude Code prompts you for the settings below when the plugin is enabled, and registers the
notification hooks automatically — no editing of `settings.json` and no symlinks. Update the settings
any time from the `/plugin` menu. Pull new versions with `/plugin marketplace update`.

Hooks registered by the plugin:

| Event               | Sound   | When it fires                       |
| ------------------- | ------- | ----------------------------------- |
| `PermissionRequest` | `Funk`  | Claude requests tool access         |
| `Stop`              | `Glass` | A turn finishes (context-aware here) |
| `StopFailure`       | `Basso` | A turn ends with an API error       |
| `PostCompact`       | `Glass` | Context is compacted                |

### Named arguments

You can also pass arguments by name, which lets you omit or reorder any of them — useful when you only
want to set, say, the title and `context`:

```json
"command": "$HOME/.claude/hooks/notify.sh --title \"Claude Code\" --context true"
```

| Flag        | Overrides        | Notes                                                                                                              |
| ----------- | ---------------- | ------------------------------------------------------------------------------------------------------------------ |
| `--title`   | title            | Defaults to `Claude Code` if omitted.                                                                              |
| `--message` | fallback message | Used when summarization is off/unavailable.                                                                        |
| `--sound`   | sound            | Defaults to `Glass` if omitted.                                                                                    |
| `--context` | `context_aware`  | `true`/`1`/`yes`/`on` forces summarization on; any other value off. Aliases: `--context-aware`, `--context_aware`. |

Both `--flag value` and `--flag=value` forms work. The named style kicks in when any argument starts
with `--`; otherwise arguments are read positionally as `title message sound context`, so existing
positional hook entries keep working unchanged.

## Configuration

Set from the `/plugin` menu (Claude Code prompts for these at enable time). All optional:

| Setting             | Default                     | Meaning                                                                                                     |
| ------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `context_aware`     | `false`                     | `true` summarizes the turn with a model call; `false` shows the static message and makes **no** model call. |
| `summarize_model`   | `claude-haiku-4-5-20251001` | Model used for the summary.                                                                                 |
| `summarize_timeout` | `30`                        | Max seconds for the summary call; `0` disables it.                                                          |
| `icon`              | _(empty)_                   | Path to a notification icon; empty uses alerter's default.                                                  |
| `action_app`        | _(empty)_                   | App opened when you click the notification, e.g. `Visual Studio Code`. Empty = no click action.             |
| `alerter_timeout`   | _(empty)_                   | Seconds before auto-dismiss. Empty = the notification waits until you click/dismiss it.                     |
| `cmd_prefix`        | _(empty)_                   | Prefix for the `alerter`/`open` calls. Empty runs them directly; set to `mac` under OrbStack.               |

<!-- ponytail: script also sources ~/.config/claude-notify.conf (or $CLAUDE_NOTIFY_CONFIG) if present, for non-plugin use. -->
Advanced: the script still sources `~/.config/claude-notify.conf` (or `$CLAUDE_NOTIFY_CONFIG`) as bash
`key=value` if present, used as a fallback for non-plugin setups. Plugin settings take precedence over it.

## Layout

```
.claude-plugin/plugin.json       ← plugin manifest + userConfig
.claude-plugin/marketplace.json  ← lets the repo be added as a marketplace
hooks/hooks.json                 ← hook registrations (use ${CLAUDE_PLUGIN_ROOT})
scripts/notify.sh                ← the notification script
```

## Privacy

When `context_aware=true`, the hook sends your **last message** and the **assistant's final reply**
from the current turn to a `claude` Haiku call to generate the summary. If you don't want any turn
content leaving for that summary, set `context_aware=false` — the hook then shows only the static
message and makes no model call.

## License

[MIT](LICENSE)
