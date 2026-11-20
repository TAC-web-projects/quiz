# Design decisions

The site owner made these decisions when the quiz was restructured (Nov 2026).
Follow them unless the owner changes them, and update this file when they do.

## Page & audience
- **One page only** (`index.qmd`). Students scroll and never navigate to another
  page. Each topic is a big collapsible header on that page.
- **First topic starts open**, and the others are collapsed. Topics open and close
  **independently** (not an accordion), so several can be open at once.
- Students are mostly **on phones**: everything must work at phone width with no
  sideways scrolling. Memory cards are 2 columns on phones, and formulas never wrap.
- Short student intro at the top. (The old note to David was removed.)

## Content organization
- **One file per game**: `topic/<topic>/_<name>.qmd`. Front matter `type:` says
  what it is (`memory`, `wordle`, `notes`). The point is that a single question
  is easy to find and edit by hand.
- **Auto-discovery**: every `_*.qmd` in a topic folder is included, **sorted by
  filename**. Adding a game means adding a file, and nothing else changes.
- **`index.qmd` has one line per topic** (`::: {.topic folder=... title=...}`). Order
  there is the order on the page. Quarto's `{{< include >}}` was not used for
  this because it can't take wildcards.
- Question files never render as their own pages. This is enforced **twice**: the
  `_` filename prefix, and `project.render: [index.qmd]` in `_quarto.yml`.
- Hints and solutions are written as `## Hint` / `## Solution` headings (not divs).

## Activity types
- The old **Practice Questions** (checkbox forms with a Submit button) were removed.
  The 4 original circle questions are kept, unrendered, in
  `archive/_multiple-choice-circles.qmd`.
- **Multiple choice came back as a game type** (`type: choice`, Nov 2026), for
  questions like "what does the A in SOH CAH TOA stand for". One right option;
  tapping a wrong option turns it red and crosses it out, and the student keeps
  going until they find the right one. No Submit button. Options are shuffled.
- **Parentheses puzzle** (`type: parens`, Nov 2026): the student taps the gaps
  in an expression to place parentheses until it equals a target. The answer is
  checked by evaluating it, not by comparing strings, so any correct placement
  counts. Wrong tries say what their version equals at a sample $x$.
- Each topic has fixed sub-sections, in order: **Multiple Choice**, **Memory
  Match**, **Formula Wordle**, **Parentheses Puzzle**. A sub-section is left out
  if the topic has none. `notes` files go at the bottom of the topic.
- **Wordle shows the quantity being tested** (its `title:`, e.g. "Area of a
  circle") prominently above the `A = ___` board.
- If a Wordle row (left side + tiles) is too wide for the screen, the left side
  is shown **once above the board** instead of at the start of every row, so
  long left sides like `m = (y₁ − y₂) ÷` work on phones.
- A carousel with only **one** game has no Previous / Next / Shuffle buttons, and its
  title has no "1 of 1".
- **Memory Match is one grid, and cards never move.** Picking a card dims and
  locks the other cards of the same kind (names or formulas) until one of the
  other kind is picked; tapping the picked card again puts it back. This saves
  students from flipping name after name. A whole board must fit on one phone
  screen without scrolling (2 columns and shorter cards on phones; tried
  separate piles, rejected because they made the board taller).
- `face-up: true` in a memory file shows every card from the start, with the
  names first **in table order** and the formulas shuffled after them. Used for
  FOIL (F, O, I, L in reading order). A wrong pair flashes red instead of
  flipping back.
- Matched memory cards turn **entirely** light green (no white box around math).
- Memory card math is drawn in display style (full-size fractions) with a thin
  space before each `)`, so subscripts, numerators and parentheses stay readable.
- Wordle: **Enter** sits on its own row with **Reset** and the **← Previous** /
  **Next →** arrows (only when the topic has several Wordles), away from the
  symbol keys. Wordles have no Shuffle button. On screens under 360px the arrows
  drop their words.
- Titles may contain LaTeX (`title: 'Subtracting two fractions, $\frac{a}{b} - \frac{c}{d}$'`,
  in single quotes so the backslashes survive YAML).
- **Memory cards never give the pair away**: a formula card shows `= \pi r^2`,
  never `A = \pi r^2`. Authors write the full formula. The filter strips a
  one-symbol left side, and the Solution tab shows the full table.

## Scoring & progress
- **No Submit buttons.** Games record results automatically as they finish.
- **"Check your results"** at the bottom shows, per topic, *games solved / total*,
  plus details: tries used per Wordle and mismatches per Memory Match.
- **Progress is saved in the browser** (localStorage), so it survives a reload. There
  are per-game Reset buttons and a "Reset all progress" button.

## Technology
- Markdown files + a **Lua filter** (`_extensions/quiz/quiz.lua`) generate the
  carousels, tabs and callouts. These were not chosen: YAML data files (LaTeX
  quoting gets painful) and a JS framework rewrite (would lose Quarto's MathJax
  and TikZ pipeline).
- The filter runs **`at: pre-ast`** so Quarto treats generated callouts and tabsets
  like hand-written ones. The TikZ `diagram` filter runs after it.
- Widgets are **plain JavaScript** (`quiz.js`, no Observable JS). Formulas are
  typeset by the page's MathJax.
- MathJax uses **SVG output** (`tex-svg-full.js`, pinned to 3.2.2 in `_quarto.yml`).
  The default CHTML output needs web fonts from the CDN; where those are blocked
  (some phones and networks, embedded previews) letters get squeezed and
  descenders clipped. SVG output needs no fonts.
- A new question type = a `TYPES.<name>` entry in `quiz.lua` + a
  `Quiz.register("<name>", ...)` in `quiz.js` (+ CSS). See `lua_filter.md`.

## Workflow
- `scripts/check.sh --templates` must pass before committing. It renders the
  site and the `topic/_template/` examples, and fails on any filter or TikZ error.
- `docs/` is the published site (GitHub Pages) and is committed after rendering.
- **Never push** until the owner explicitly says so (see `CLAUDE.md`).
