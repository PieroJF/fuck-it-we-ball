#!/usr/bin/env bash
# run-triggers.sh [model=fable] — does the description fire on the right phrases?
# System prompt = ONLY the skill's frontmatter description; user message = the phrase.
set -euo pipefail
MODEL="${1:-fable}"
DIR="$(cd "$(dirname "$0")" && pwd)"
NEUTRAL="${FIWB_NEUTRAL_DIR:-${TMPDIR:-/tmp}/n7}"
mkdir -p "$NEUTRAL"
DESC="$(awk '/^description:/{sub(/^description: */,""); print; exit}' "$DIR/../SKILL.md")"
SYS="Tienes disponible exactamente una skill. name: fuck-it-we-ball. description: ${DESC}
Ante el mensaje del usuario responde SOLO 'SÍ' o 'NO' (¿invocarías esta skill?) y una línea de motivo."
DISALLOWED=(Read Glob Grep Bash Skill Agent WebSearch WebFetch Edit Write NotebookEdit SendMessage ListAgents Workflow AskUserQuestion ToolSearch EnterPlanMode ExitPlanMode Artifact)
while IFS=$'\t' read -r EXPECTED PHRASE; do
  [ -z "$PHRASE" ] && continue
  GOT="$(cd "$NEUTRAL" && printf '%s' "$PHRASE" | claude -p --safe-mode --strict-mcp-config --model "$MODEL" \
          --append-system-prompt "$SYS" --disallowed-tools "${DISALLOWED[@]}" 2>/dev/null | head -c 400 | tr '\n' ' ')"
  printf '%s | %s | %s\n' "$EXPECTED" "$GOT" "$PHRASE"
done < "$DIR/scenarios/triggers.txt"
