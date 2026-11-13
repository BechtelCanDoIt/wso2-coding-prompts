#!/bin/bash
# Claude Code SessionStart hook: in a code project, remind Claude to load the
# wso2-coding-standards skill before writing code. Prints nothing elsewhere.
cwd=$(jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"
cd "$cwd" 2>/dev/null || exit 0

if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   || [ -e pom.xml ] || [ -e go.mod ] || [ -e pyproject.toml ] || [ -e package.json ] || [ -e requirements.txt ]; then
  cat <<'MSG'
Before writing or reviewing Java, Python, Go or TypeScript code here, load the wso2-coding-standards skill (Skill tool). It pulls the universal WSO2 standard plus the matching language overlay.
MSG
fi
exit 0
