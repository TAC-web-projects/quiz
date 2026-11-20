---
name: quiz-authoring
description: How content and code are organized on this Quarto quiz site. It covers one file per game under topic/<topic>/_*.qmd, auto-discovered by the Lua filter in _extensions/quiz/, plus quiz.js widgets and per-topic scoring. Use it whenever you add, edit, reorder or remove a Memory Match, Wordle, notes block or topic. Also use it to add a new question type, or to change quiz.lua, quiz.js, quiz.css, index.qmd or _quarto.yml filters. Use it even for casual requests like "add a wordle for arc length", "make a triangles section" or "can we have a fill-in-the-blank kind of question".
---

# Quiz authoring

The owner's decisions are in `_README/design_decisions.md`. Treat them as requirements: one scrolling page, Memory Match + Wordle only, no Submit buttons, progress saved in the browser. The mechanics are explained in `_README/lua_filter.md`.

## Add a game (no code)

1. Copy the matching file from `topic/_template/` into `topic/<topic>/`. Keep the leading `_`. The filename sets the order, so number it (`_wordle-4-arc-length.qmd`).
2. Fill in the front matter:
   - **Wordle:** `type: wordle`, `title:` (the quantity in words; it's shown above the board), `lhs: "A ="`, `answer:` (space-separated Unicode symbols, e.g. `π r ²`). Every answer symbol must be on the keyboard, which defaults to `π r d 2 ² C θ ½`. Add any others with `keys:`.
   - **Memory:** `type: memory`, `title:`, and a `| Name | Formula |` table with each **full** formula in `$...$`. Cards hide a one-symbol left side by themselves. Never write `= \pi r^2` by hand. Add `face-up: true` to show all cards from the start, with the names in table order (e.g. FOIL letters).
   - **Notes:** `type: notes`. The body is shown as-is at the bottom of the topic.
3. Add `## Hint` sections (as many as needed, gentlest first; Hint 1 must not give the answer away) and a `## Solution`. Write the math and diagrams the way the `quiz-latex-style` skill says.
4. Run `scripts/check.sh --templates`.

## Add a topic

Create `topic/<name>/` with game files, then add one line to `index.qmd` in the position it should appear (the first topic starts open):

```markdown
::: {.topic folder="topic/<name>" title="<Title>"}
:::
```

## Add a question type (code)

Follow §4 of `_README/lua_filter.md`. It's a worked "numeric" example that has been tested. In short:
- `quiz.lua`: a `TYPES.<name> = { section, noun, order, build }` entry. Reuse `split_sections`, `tabset`, `game_div` and `fail`, and reject malformed files with `fail(...)`.
- `quiz.js`: `Quiz.register("<name>", { init(el, game), summary(state) })`. Build everything inside `el` from `el.dataset`. Persist only through `game.save(jsonState)`, and restore from `game.state`.
- `quiz.css`: class names prefixed with the type. Check the layout at phone width.
- Add `topic/_template/_<name>-example.qmd`, and describe the type in `_README/lua_filter.md`, `_README/design_decisions.md` and this skill.

## Things that break silently

- The filter must stay `at: pre-ast` and listed **before** `diagram` in `_quarto.yml`. Otherwise hints render as plain sections and TikZ shows as code.
- Topic headers are raw HTML `<h2>` on purpose. A Markdown header's attributes get moved onto its wrapping `<section>`, which would make the whole topic a click target.
- Progress is keyed by `topic-slug/filename`. Renaming a file resets that game for students.
- `quarto render` exits 0 even when the filter errors. Use `scripts/check.sh`.

## Verify in a browser

For a visible change, serve `docs/`, open it in Playwright on desktop and a phone size, and play the changed game.
- Set `sessionStorage.authed = "1"` with an init script to skip the login overlay.
- If the MathJax CDN is blocked in the sandbox, serve `mathjax@3.2.2` from npm through `page.route` (match `/mathjax@3[^/]*\/es5\/(.*)/`). Count errors with `[data-mml-node="merror"]` (SVG output).

Finally, commit the source and the re-rendered `docs/`, and don't push unless the user says to.
