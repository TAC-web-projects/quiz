# How the quiz Lua filter works

This is a guide for people who haven't used Lua filters before. It covers what
the filter is, how a question file becomes part of the page, and how to add a
brand-new question type with its own JavaScript and styling.

Files involved:

| File | What it does |
|---|---|
| `index.qmd` | The only page. Has one `::: {.topic ...}` line per topic. |
| `topic/<name>/_*.qmd` | One file per game (or note). Front matter says its `type:`. |
| `_extensions/quiz/quiz.lua` | **The filter.** Turns topic lines + files into page content. |
| `_extensions/quiz/quiz.js` | Makes the games interactive, scores them, and saves progress. |
| `_extensions/quiz/quiz.css` | Styles for the games and topic headers. |
| `_quarto.yml` | Tells Quarto to run the filter (`filters:`). |
| `scripts/check.sh` | Renders everything and fails loudly on any problem. |

---

## 1. What a "filter" is

When you run `quarto render`, Quarto doesn't go straight from `.qmd` to HTML.
In between, it hands the page to **pandoc**, which turns the Markdown into a
tree of pieces called the **AST** (abstract syntax tree):

```
index.qmd ──read──▶  AST  ──(filters change the AST)──▶  AST  ──write──▶  index.html
```

The AST is just a list of building blocks: a `Para` (paragraph), a `Header`,
a `Table`, a `Div` (any `::: {...}` block), a `Math` formula, a `CodeBlock`,
and so on. A **filter** is a small program that walks over those blocks and
replaces some of them. A **Lua** filter is one written in Lua, a small
scripting language that pandoc has built in. You don't need to install anything.

Our filter looks for exactly two kinds of block in `index.qmd`:

```markdown
::: {.topic folder="topic/circles" title="Circles"}
:::

::: {.quiz-results}
:::
```

It replaces the first with a whole collapsible topic, and the second with the
"Check your results" buttons. Everything else on the page is left alone.

The bottom of `quiz.lua` is where this hook is set up:

```lua
return {
  {
    Div = function(div)                         -- called for every ::: block
      if div.classes:includes("topic") then
        return build_topic(div)                 -- replace it with the topic
      elseif div.classes:includes("quiz-results") then
        return build_results()
      end                                       -- returning nothing = keep as is
    end,
  },
}
```

## 2. When it runs (and why that matters)

In `_quarto.yml`:

```yaml
filters:
  - path: _extensions/quiz/quiz.lua
    at: pre-ast
  - diagram
```

- `at: pre-ast` means "run **before** Quarto does its own processing". Quarto
  turns `.callout-tip` divs into callout boxes and `.panel-tabset` divs into tabs
  in an early step. Because our filter runs before that step, the callouts and
  tabs it creates are treated exactly like ones you'd type by hand. If it ran
  later, they would show up as plain unstyled sections.
- `diagram` (the TikZ filter) is listed **after** it. The TikZ blocks inside
  question files only exist on the page once the quiz filter has pulled the
  files in, so the order matters.

## 3. What happens to one topic, step by step

`build_topic` in `quiz.lua`:

1. **List the folder.** It lists `topic/circles/`, keeps files named
   `_*.qmd`, and sorts them by filename. That's why `_wordle-1-area.qmd` comes
   before `_wordle-2-circumference.qmd`.
2. **Read each file.** `pandoc.read` parses the file into its own small AST.
   That gives the front matter (`doc.meta`: `type`, `title`, `lhs`, ...) and the
   body (`doc.blocks`).
3. **Check it.** A missing `type:`, an unknown type, a missing `title:` and
   similar mistakes stop the render with a message such as
   `[quiz] topic/circles/_wordle-1-area.qmd: missing `title:``.
4. **Group by type** and lay out each group in a fixed order (Memory Match,
   then Formula Wordle, then notes). Each type that has a `section` becomes a
   `### Memory Match` sub-heading plus a **carousel** with one slide per file
   and Previous / Next / Shuffle buttons.
5. **Build each slide** by calling that type's `build` function (see §4). It
   produces the Question / Hint / Solution tabs:
   - `## Hint` sections in the file → collapsible "Hint 1", "Hint 2" callouts
   - `## Solution` → the Solution tab
   - the game itself → an empty `<div class="quiz-game quiz-wordle" data-...>`
     that the JavaScript fills in later
6. **Wrap it all** in a collapsible topic: an `<h2>` you can click, plus a
   Bootstrap `collapse` div. Only the first topic starts open.

### The hand-off from Lua to JavaScript

The filter only writes **static HTML**. It can't make anything clickable.
It passes everything the game needs to the browser as `data-` attributes:

```html
<div class="quiz-game quiz-wordle"
     data-game="circles/wordle-1-area"     ← unique id, used to save progress
     data-topic="circles" data-topic-title="Circles"
     data-title="Area of a circle"
     data-lhs="A =" data-answer="π r ²" data-keys="π r d 2 ² C θ ½" data-tries="6">
</div>
```

When the page loads, `quiz.js` finds every `.quiz-game`, reads the second
class (`quiz-wordle` → type `wordle`), and runs the code registered for that
type. That code reads the `data-` attributes and builds the board.

Math is the one exception. The Memory Match faces are written as real pandoc
`Math` (inside a hidden `.mm-faces` div), so **MathJax typesets them with the
rest of the page**, and `quiz.js` only moves those finished faces into the
card buttons.

## 4. Adding a new question type

Example: a **"numeric"** type, where the student types a number and the
answer is checked. You add one thing to each of three files.

### Step 1: the question file format (pick it first)

```markdown
---
type: numeric
title: Circumference when r = 3
answer: 18.85
tolerance: 0.05
---

A circle has radius $r = 3$. What is its circumference, to 2 decimal places?

## Hint
$C = 2\pi r$

## Solution
$C = 2\pi \cdot 3 = 6\pi \approx 18.85$
```

### Step 2: `quiz.lua`: add an entry to the `TYPES` table

```lua
TYPES.numeric = {
  section = "Quick Numbers",   -- sub-heading inside the topic (nil = no carousel)
  noun = "Question",           -- used in "Question 1 of 3" and on the buttons
  order = 3,                   -- after Memory Match (1) and Wordle (2)
  build = function(game, meta, blocks)
    local parts = split_sections(blocks, game.file)    -- intro / hints / solution
    if not meta.answer then fail(game.file, "a numeric question needs `answer:`") end
    local question = pandoc.Blocks {}
    question:extend(parts.intro)                       -- the question text
    question:insert(game_div(game, "numeric", {        -- → <div class="quiz-game quiz-numeric" ...>
      ["data-answer"] = pandoc.utils.stringify(meta.answer),
      ["data-tolerance"] = meta.tolerance and pandoc.utils.stringify(meta.tolerance) or "0",
    }))
    game.tabs = tabset(question, parts.hints, parts.solution)
  end,
}
```

Helpers you can reuse: `split_sections` (splits on `## Hint` / `## Solution`),
`tabset`, `game_div` (adds `data-game`, `data-topic`, `data-title` for you),
and `fail` (stops the render with a clear message).

A non-game type that just shows content (like `notes`) leaves out `section`
and has `build` **return** the blocks to show. See `TYPES.notes`.

### Step 3: `quiz.js`: register the widget

Add this before the `PAGE-WIDE PIECES` section:

```js
Quiz.register("numeric", {
  // el = the <div class="quiz-game quiz-numeric">; game.state = saved progress
  init(el, game) {
    const input = h(`<input type="text" inputmode="decimal" class="form-control d-inline-block w-auto">`);
    const btn = h(`<button class="btn btn-primary ms-2">Check</button>`);
    const msg = h(`<p class="mt-2"></p>`);
    const answer = Number(el.dataset.answer), tol = Number(el.dataset.tolerance);
    const show = (s) => { msg.textContent = s.solved ? "Correct! 🎉" : s.tries ? "Not quite. Try again." : ""; };
    btn.onclick = () => {
      const s = { ...game.state, tries: (game.state.tries || 0) + 1 };
      s.solved = s.solved || Math.abs(Number(input.value) - answer) <= tol;
      game.save(s);             // saves to the browser + refreshes the results
      show(s);
    };
    el.append(input, btn, msg);
    show(game.state);           // restore after a reload
  },
  // Used by "Check your results"
  summary(s) {
    if (!s.tries) return { solved: false, detail: "not started" };
    return { solved: !!s.solved, detail: s.solved ? `solved in ${s.tries} tries` : `${s.tries} tries so far` };
  },
});
```

The rules a widget follows:

- Build everything **inside `el`** and read settings from `el.dataset`.
- Store progress only through `game.save(state)`. The state must be plain JSON
  (numbers, strings, arrays). Restore from `game.state` in `init` so progress
  survives a reload.
- `summary(state)` returns `{ solved, detail }`, and the results list uses it.
  Leave it out if the type shouldn't be scored.

### Step 4: `quiz.css`: styles (if needed)

Prefix class names with the type (`.numeric-...`) so they can't clash with
others. Bootstrap classes (`btn`, `form-control`, `d-flex`, `gap-1`, ...) are
already available. Check the phone layout (width ≤ 576px) as well.

### Step 5: template + check

1. Add `topic/_template/_numeric-example.qmd`.
2. Run `scripts/check.sh --templates`. It renders the site **and** a test page
   built from `topic/_template/`, and fails on any problem.

## 5. Adding content (no code needed)

- **New game:** copy a file from `topic/_template/` into a topic folder.
  Keep the leading `_`, and use the filename to set the order.
- **New topic:** make `topic/<name>/`, add files, and add one line to
  `index.qmd`:
  ```markdown
  ::: {.topic folder="topic/triangles" title="Triangles"}
  :::
  ```

## 6. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Render stops with `[quiz] <file>: ...` | The message names the file and the problem; fix the file. |
| Hints show as plain text, not boxes | The filter is no longer `at: pre-ast` in `_quarto.yml`. |
| TikZ shows as code | `diagram` must come **after** the quiz filter in `filters:`. |
| `quarto preview` doesn't update after editing a question file | Preview only watches `index.qmd`; save `index.qmd` again or run `quarto render`. |
| A game is blank in the browser | Its `quiz-<type>` has no `Quiz.register("<type>", ...)`; check the browser console. |
| A file isn't showing up | Its name must start with `_` and end in `.qmd`, and its folder must be listed in `index.qmd`. |
| Saved progress looks wrong after renaming a file | Progress is keyed by `topic/filename`; renaming starts that game fresh. |

## Lua in 60 seconds

```lua
local x = 3                 -- variable (always use `local`)
local t = { "a", "b" }      -- list; t[1] == "a" (counting starts at 1)
local m = { key = "v" }     -- table/map; m.key == "v"
for i, v in ipairs(t) do end
if x == 3 then ... elseif x ~= 4 then ... end   -- ~= means "not equal"
local s = "a" .. "b"        -- .. joins strings
```

Pandoc functions used here: `pandoc.read(text, "markdown")`, `pandoc.Div(blocks, attr)`,
`pandoc.Header(level, text, attr)`, `pandoc.Para(...)`, `pandoc.RawBlock("html", "...")`,
`pandoc.utils.stringify(x)` (anything → plain text). Full reference:
<https://pandoc.org/lua-filters.html>.
