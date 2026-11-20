# CLAUDE.md

Quarto website (`_quarto.yml`, output in `docs/` for GitHub Pages) with formula
practice games for ACT-level geometry, used mostly on phones. Everything is on one
page, `index.qmd`, built from one file per game under `topic/<topic>/_*.qmd` by
a Lua filter (`_extensions/quiz/`).

## Git

- Never run `git push` (or push any other way, e.g. GitHub API file writes) until the user explicitly tells you to push. Committing locally is fine.

## Where things are documented

- `_README/design_decisions.md`: **the decisions the owner made** (one page,
  auto-discovered files, four game types (multiple choice, Memory Match, Wordle, parentheses puzzle), scoring, persistence, ...). Read it
  before changing structure or behavior, and update it when the owner changes a decision.
- `_README/lua_filter.md`: how the filter, `quiz.js` and `quiz.css` fit
  together, and the step-by-step recipe for **adding a new question type**.
- Skill `quiz-authoring`: adding or editing games, topics and question types.
- Skill `quiz-latex-style`: how math, TikZ and the writing voice should look.
- `topic/_template/`: copy-me example file for each type.

## Checks

- Run `scripts/check.sh --templates` after any change. It renders the site plus
  the templates and fails on filter, Quarto or TikZ errors. (Quarto exits 0 even
  when the filter fails, so don't trust the exit code of a bare `quarto render`.)
- Commit the re-rendered `docs/` together with the source change.
