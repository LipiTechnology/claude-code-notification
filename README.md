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

Clone the repo, create your config from the example, then run `install.sh` from inside the checkout:

```bash
git clone https://github.com/<you>/claude-code-notification-hook.git
cd claude-code-notification-hook
cp claude-notify.conf.example claude-notify.conf   # git-ignored; your live config
"${EDITOR:-vi}" claude-notify.conf                 # review/edit to taste
./install.sh
```

`install.sh` checks dependencies and requires the in-repo `claude-notify.conf` to exist — it won't
seed one for you, so copy the example first (it halts with a reminder if it's missing). It then makes
the hook executable and creates two **symlinks** so a later `git pull` updates the live hook and your
config stays co-located with the checkout:

- `~/.claude/hooks/notify.sh` → `commands/notify.sh`
- `~/.config/claude-notify.conf` → `claude-notify.conf`

Finally it prints the settings block to add to `~/.claude/settings.json` (it won't edit your JSON for
you). Keep the checkout around — both symlinks point back into it. `claude-notify.conf` is git-ignored,
so your edits are never touched by `git pull`.

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh --title '⚠️ Claude needs permission' --message 'Requesting tool access' --sound 'Funk' --context_aware false"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "timeout": 25,
            "command": "~/.claude/hooks/notify.sh '✅ Claude finished' 'Response ready' 'Glass'"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "timeout": 25,
            "command": "~/.claude/hooks/notify.sh '❌ Claude error' 'Turn ended with API error' 'Basso'"
          }
        ]
      }
    ]
  }
}
```

The positional arguments are the notification **title**, the **fallback message** (used when
summarization is off or unavailable), and the **sound**.

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

Settings live in `~/.config/claude-notify.conf` (sourced as bash `key=value`). All optional:

| Key               | Default                     | Meaning                                                                                                     |
| ----------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `context_aware`   | `true`                      | `true` summarizes the turn with a model call; `false` shows the static message and makes **no** model call. |
| `summarize_model` | `claude-haiku-4-5-20251001` | Model used for the summary.                                                                                 |
| `icon`            | _(empty)_                   | Path to a notification icon; empty uses alerter's default.                                                  |
| `action_app`      | _(empty)_                   | App opened when you click the notification, e.g. `"Visual Studio Code"`. Empty = no click action.           |
| `alerter_timeout` | _(empty)_                   | Seconds before auto-dismiss. Empty = the notification waits until you click/dismiss it.                     |
| `debug`           | `false`                     | Append diagnostics to `~/notification.log`.                                                                 |

You can also point at a different config file with the `CLAUDE_NOTIFY_CONFIG` environment variable.

## Layout

```
install.sh                  ← run this from the checkout
commands/notify.sh          ← the Stop hook; ~/.claude/hooks/notify.sh symlinks here
claude-notify.conf.example  ← template; copy to claude-notify.conf
claude-notify.conf          ← your config (git-ignored); ~/.config/claude-notify.conf symlinks here
```

## Privacy

When `context_aware=true`, the hook sends your **last message** and the **assistant's final reply**
from the current turn to a `claude` Haiku call to generate the summary. If you don't want any turn
content leaving for that summary, set `context_aware=false` — the hook then shows only the static
message and makes no model call.

## License

[MIT](LICENSE)
