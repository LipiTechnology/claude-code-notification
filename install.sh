#!/bin/bash
# Installer for claude-code-notification-hook.
#
# Run it from a local checkout of this repo:
#     git clone https://github.com/<you>/claude-code-notification-hook.git
#     cd claude-code-notification-hook
#     ./install.sh
#
# It symlinks the hook into ~/.claude/hooks (so `git pull` in the repo updates the
# live hook), requires you to have copied the config from the example, then
# automatically merges the required hook entries into ~/.claude/settings.json
# (backing up the original first).
set -e

hooks_dir="$HOME/.claude/hooks"
config="$HOME/.config/claude-notify.conf"

# Resolve the checkout this script lives in and link straight out of it.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -z "$repo_dir" ] || [ ! -f "$repo_dir/commands/notify.sh" ]; then
  echo "Could not find commands/notify.sh next to this script." >&2
  echo "Clone the repo and run ./install.sh from inside the checkout:" >&2
  echo "  git clone https://github.com/<you>/claude-code-notification-hook.git" >&2
  echo "  cd claude-code-notification-hook && ./install.sh" >&2
  exit 1
fi

# Check runtime dependencies before touching the filesystem. alerter (notifications)
# and python3 (payload parsing) are required; the `claude` CLI is only needed for
# context-aware summaries, so its absence is a warning rather than a halt.
missing=0
if ! command -v alerter >/dev/null 2>&1; then
  echo "Missing required dependency: alerter" >&2
  echo "  Install with: brew install alerter" >&2
  missing=1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing required dependency: python3" >&2
  echo "  Install with: brew install python   (or: xcode-select --install)" >&2
  missing=1
fi
if [ "$missing" -ne 0 ]; then
  echo "Install the missing dependencies above, then re-run this installer." >&2
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "Note: 'claude' CLI not found on PATH — context-aware summaries will fall back to the" >&2
  echo "      static message. Install it, or set context_aware=false in the config to silence this." >&2
fi

# Require the in-repo config to exist. We deliberately don't auto-seed it: copy the
# example to claude-notify.conf (git-ignored), edit it, then re-run. This halts before
# linking so nothing is left half-done. We symlink it into ~/.config like the hook, so
# the live config stays co-located with your checkout.
repo_config="$repo_dir/claude-notify.conf"
if [ ! -f "$repo_config" ]; then
  echo "Config not found: $repo_config" >&2
  echo "Copy the example, edit it to your liking, then re-run ./install.sh:" >&2
  echo "  cp \"$repo_dir/claude-notify.conf.example\" \"$repo_config\"" >&2
  echo "  \"\${EDITOR:-vi}\" \"$repo_config\"" >&2
  exit 1
fi

echo "Using checkout: $repo_dir"
chmod +x "$repo_dir/commands/notify.sh"
mkdir -p "$hooks_dir"
ln -sf "$repo_dir/commands/notify.sh" "$hooks_dir/notify.sh"
echo "Linked: $hooks_dir/notify.sh -> $repo_dir/commands/notify.sh"
mkdir -p "$(dirname "$config")"
# Don't clobber a real (non-symlink) config already sitting at the target — that may be
# the user's hand-edited file. Ask them to move it into the repo first.
if [ -e "$config" ] && [ ! -L "$config" ]; then
  echo "A real file already exists at: $config" >&2
  echo "Move it into the repo so it can be the source of truth, then re-run ./install.sh:" >&2
  echo "  mv \"$config\" \"$repo_config\"" >&2
  exit 1
fi
ln -sf "$repo_config" "$config"
echo "Linked: $config -> $repo_config"

# Merge hook entries into ~/.claude/settings.json automatically.
# Back up the existing file first, then use python3 (already a required dep)
# to do a safe JSON merge: for each hook event, append the notify.sh entry
# only if one isn't already present.
settings_file="$HOME/.claude/settings.json"

echo ""
echo "Updating $settings_file ..."

python3 - "$settings_file" <<'PYEOF'
import json, sys, os, shutil
from datetime import datetime

settings_path = sys.argv[1]

# Read existing settings or start fresh
if os.path.isfile(settings_path):
    with open(settings_path, "r") as f:
        settings = json.load(f)
    # Create timestamped backup
    backup = f"{settings_path}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
    shutil.copy2(settings_path, backup)
    print(f"  Backed up: {settings_path} -> {backup}")
else:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    settings = {}
    print(f"  Creating new: {settings_path}")

hooks = settings.setdefault("hooks", {})

# Hook entries to install
entries = {
    "PermissionRequest": {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/notify.sh --title 'Claude needs permission' --message 'Requesting tool access' --sound 'Funk' --context_aware false"}]
    },
    "Stop": {
        "hooks": [{"type": "command", "timeout": 25, "command": "~/.claude/hooks/notify.sh 'Claude finished' 'Response ready' 'Glass'"}]
    },
    "StopFailure": {
        "hooks": [{"type": "command", "timeout": 25, "command": "~/.claude/hooks/notify.sh 'Claude error' 'Turn ended with API error' 'Basso'"}]
    },
    "Notification": {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/notify.sh 'Claude' 'Notification' 'Pop'"}]
    },
}

for event, entry in entries.items():
    existing = hooks.get(event, [])
    # Check if any existing hook already references notify.sh
    already = False
    for group in existing:
        for h in group.get("hooks", []):
            if "notify.sh" in h.get("command", ""):
                already = True
                break
        if already:
            break
    if already:
        print(f"  {event}: already has notify.sh hook, skipped")
    else:
        existing.append(entry)
        hooks[event] = existing
        print(f"  {event}: added notify.sh hook")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"  Updated: {settings_path}")
PYEOF

echo ""
echo "Done! Notification hooks are installed and ready."
