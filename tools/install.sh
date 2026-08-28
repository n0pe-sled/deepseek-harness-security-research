#!/bin/sh
set -eu

framework_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
dsh_root=${DSH_HOME:-"$HOME/.dsh"}
skills_root=${DSH_SKILLS_REPO:-"$HOME/deepseek-harness-skills"}
plugins_root=${DSH_PLUGINS_REPO:-"$HOME/deepseek-harness-plugins"}
agents_root=${DSH_AGENTS_HOME:-"$HOME/.agents"}
user_skills="$agents_root/skills"
user_presets="$dsh_root/.agent-presets"

"$framework_root/tools/validate.sh"
mkdir -p "$user_skills" "$user_presets"

# Skills live in the canonical skills repo (DSH_SKILLS_REPO), grouped into
# category folders. Link each bundle flat into the agent skills root so a
# `git pull` on that repo updates them in place.
if test -d "$skills_root"; then
  for bundle in $(find "$skills_root" -mindepth 2 -maxdepth 3 -name SKILL.md | sort); do
    name=$(basename "$(dirname "$bundle")")
    destination="$user_skills/$name"
    if test ! -e "$destination" && test ! -L "$destination"; then
      ln -s "$(dirname "$bundle")" "$destination"
      echo "linked skill $name -> $destination"
    else
      echo "kept existing skill link $destination"
    fi
  done
else
  echo "skills repo not found at $skills_root; set DSH_SKILLS_REPO" >&2
fi

preset_source="$framework_root/dsh/agent-presets/security-research"
preset_destination="$user_presets/security-research"
if test ! -e "$preset_destination"; then
  cp -R "$preset_source" "$preset_destination"
  echo "installed preset at $preset_destination"
else
  echo "kept existing preset $preset_destination"
fi

if command -v dsh >/dev/null 2>&1 && test -d "$plugins_root"; then
  echo "Optional existing plugins:"
  echo "  dsh plugin --profile web add $plugins_root/skill-mcp-manager"
  echo "  dsh plugin --profile web add $plugins_root/system-prompt-editor"
fi

echo "MCP overlays: $framework_root/dsh/mcp"
echo "Copy $framework_root/project-template to a campaign directory and invoke \$security-scope-interview"
