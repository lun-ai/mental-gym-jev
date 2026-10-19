#!/usr/bin/env bash
# Install (or refresh) the mental gym skills into this repo's local skills
# directory, where any skills-aware agent can find them. Idempotent.
#
#   scripts/install-skills.sh
#
# Layout after running:
#   .agents/skills/AI-mental-gym/            canonical copy (Codex, Gemini CLI,
#   .agents/skills/AI-mental-gym-checklist/  and other Agent Skills clients)
#   .claude/skills -> ../.agents/skills      symlink for Claude Code
#   .gemini/skills -> ../.agents/skills      symlink for older Gemini CLI builds
set -euo pipefail

REPO_URL="https://github.com/lun-ai/skills.git"
SKILLS=(AI-mental-gym AI-mental-gym-checklist)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DST="$ROOT/.agents/skills"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone -q --depth 1 "$REPO_URL" "$TMP/skills"

mkdir -p "$DST"
for skill in "${SKILLS[@]}"; do
  rm -rf "${DST:?}/$skill"
  cp -R "$TMP/skills/$skill" "$DST/$skill"
  echo "installed .agents/skills/$skill"
done

# Client-specific directories point at the canonical copy.
for client in claude gemini; do
  link="$ROOT/.$client/skills"
  if [ -L "$link" ]; then
    continue
  elif [ -e "$link" ]; then
    echo "note: $link exists and is not a symlink; copying skills into it"
    for skill in "${SKILLS[@]}"; do
      rm -rf "${link:?}/$skill"
      cp -R "$DST/$skill" "$link/$skill"
    done
  else
    mkdir -p "$ROOT/.$client"
    ln -s ../.agents/skills "$link"
    echo "linked .$client/skills -> .agents/skills"
  fi
done

# Tag the GitHub repo with the `mental-gym` topic so every gym shows up under
# github.com/topics/mental-gym and the profile filter `topic:mental-gym`.
# Best effort: skipped when gh is missing, not logged in, or there is no remote.
TOPIC="mental-gym"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
   && git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
  if gh repo edit --add-topic "$TOPIC" >/dev/null 2>&1; then
    echo "tagged GitHub repo with topic '$TOPIC'"
  else
    echo "note: could not add GitHub topic '$TOPIC' (no push access?); skipping"
  fi
else
  echo "note: gh unavailable or no origin remote; skipping GitHub topic '$TOPIC'"
fi
