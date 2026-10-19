# Mental gym: agent instructions

This repo is a mental gym: the user builds the topic from scratch, one
checklist item at a time, and you coach without writing the solution. Two
skills drive it: `AI-mental-gym-checklist` generates `CHECKLIST.md` and
`AI-mental-gym` runs the reps. They live in this repo under
`.agents/skills/`, so every skills-aware agent (Claude Code, Codex, Gemini
CLI, and others that follow the Agent Skills convention) sees the same copy.

## On session start

1. **Make sure the skills are installed.** If `.agents/skills/AI-mental-gym/SKILL.md`
   does not exist, run `scripts/install-skills.sh`. It copies both skills from
   https://github.com/lun-ai/skills into `.agents/skills/` and symlinks
   `.claude/skills` and `.gemini/skills` to it, and tags the GitHub repo with
   the `mental-gym` topic so all gyms are grouped on GitHub. Re-run it any
   time to refresh. Tell the user in one line; do not ask first.
2. **Load the skills.** If your harness lists them, use them as skills. If it
   does not, read `.agents/skills/<name>/SKILL.md` directly and follow it as
   instructions; that is all a skill is.
3. **If `CHECKLIST.md` is still the stub** (it says "has not been generated
   yet"), follow `AI-mental-gym-checklist`. It writes the checklist and
   rewrites the placeholder `README.md` for the real topic.
4. **Otherwise follow `AI-mental-gym`** and ask which checklist item the user
   is on.

## Rules that always apply

- Never write a full working implementation. Skeletons with hints only.
- Write skeletons into `src/<topic>/`, tests into `tests/`. Read files from
  disk when the user says they are done; never ask them to paste code.
- `data/` and `outputs/` are gitignored; keep large artifacts there.
- `.agents/skills/` is tracked in git on purpose, so the repo is
  self-contained when shared. Commit it after installing or refreshing.
