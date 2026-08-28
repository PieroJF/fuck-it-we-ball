#!/usr/bin/env bash
# run-arm.sh <red|green> <scenario-file> [reps=3] [model=fable]
# Isolated instrument (see ~/.claude/projects/-home-piero-Desktop/memory/workflow-ab-contamination.md):
#   --safe-mode + --strict-mcp-config + --disallowed-tools (all) + prompt via stdin + neutral cwd.
# GREEN adds --append-system-prompt-file SKILL.md so the skill text is the ONLY delta.
set -euo pipefail
ARM="${1:?red|green}"; SCEN="$(realpath "${2:?scenario file}")"; REPS="${3:-3}"; MODEL="${4:-fable}"
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$DIR/../SKILL.md"
NEUTRAL="${FIWB_NEUTRAL_DIR:-${TMPDIR:-/tmp}/n7}"
mkdir -p "$NEUTRAL" "$DIR/raw"
NAME="$(basename "$SCEN" .txt)"
DISALLOWED=(Read Glob Grep Bash Skill Agent WebSearch WebFetch Edit Write NotebookEdit SendMessage ListAgents Workflow AskUserQuestion ToolSearch EnterPlanMode ExitPlanMode Artifact)
if [ "$ARM" = green ] && [ ! -f "$SKILL" ]; then echo "GREEN arm needs $SKILL" >&2; exit 2; fi
for i in $(seq 1 "$REPS"); do
  OUT="$DIR/raw/$ARM-$NAME-rep$i.md"
  if [ "$ARM" = green ]; then
    ( cd "$NEUTRAL" && claude -p --safe-mode --strict-mcp-config --model "$MODEL" --effort xhigh \
        --append-system-prompt-file "$SKILL" \
        --disallowed-tools "${DISALLOWED[@]}" < "$SCEN" > "$OUT" 2> "$OUT.err" ) &
  else
    ( cd "$NEUTRAL" && claude -p --safe-mode --strict-mcp-config --model "$MODEL" --effort xhigh \
        --disallowed-tools "${DISALLOWED[@]}" < "$SCEN" > "$OUT" 2> "$OUT.err" ) &
  fi
done
wait
for i in $(seq 1 "$REPS"); do printf '%s: %s words\n' "$ARM-$NAME-rep$i" "$(wc -w < "$DIR/raw/$ARM-$NAME-rep$i.md")"; done
