---
name: quiz-latex-style
description: How this Quarto quiz site writes math and TikZ diagrams, and the house voice for hints and solutions. Use it whenever you write or edit math in any .qmd here, especially the game files under topic/. That covers $...$ or $$ equations, ```{.tikz} diagrams, Memory Match formula tables, Wordle answer symbols, hints, solutions, and changes to the TikZ preamble in _quarto.yml. Use it even when the user just says "add a wordle about X" or "draw a picture for this hint". For where files go and how games are wired up, see the quiz-authoring skill.
---

# Quiz LaTeX & style

The site is Quarto HTML (`_quarto.yml`, output in `docs/`) for ACT-level geometry practice, used mostly on phones. Math shows up in four places, and each place handles LaTeX differently:

| Where | Engine | How to write it |
|---|---|---|
| Hints, solutions, titles, notes | MathJax with **SVG output** (`tex-svg-full.js` in `_quarto.yml`; no web fonts needed) | `$...$` / `$$...$$`. In a front-matter `title:`, use single quotes: `title: 'Expand $(x + 3)(x + 5)$'` |
| Diagrams | `pandoc-ext/diagram` → lualatex → SVG | ` ```{.tikz} ` block |
| Memory Match table | MathJax, via the quiz filter | full formula in `$...$`, normal single backslashes: `$A = \pi r^2$`. Cards drop a one-symbol left side by themselves (`= \pi r^2`), and the filter draws card math in `\displaystyle` with a thin space `\,` before each `)`. Don't add those yourself. |
| Wordle `answer:` / `keys:` | plain text, no LaTeX | Unicode, space-separated: `π r ²` (from `π r d 2 ² C θ ½`) |

## Math in prose (MathJax)

- Put every variable in math, even in running text: "radius $r$", "Area $A$".
- Use `\frac{a}{b}`, not `a/b`. Use `\left(\frac{d}{2}\right)^2` for grouped fractions. Use `\cdot` for multiplication, not `*`. Use `\approx` for approximations (`\pi \approx 3.14`).
- Put multi-step work in display math: `$$` on lines of their own, an `aligned` block, the body indented 4 spaces, `&=` on every line, and one algebra step per line:

```
$$
\begin{aligned}
    C &= \pi d \\
      &= \pi (2r) \\
      &= 2\pi r
\end{aligned}
$$
```

- Keep Memory Match formulas to one short inline formula. Cards never wrap a formula, and they shrink text to fit a phone-width card.
- In Wordle, a plain **2** and the exponent **²** are different keys. Make sure `answer:` uses the one the formula means.
- Wordle exponents and subscripts use Unicode: superscripts `ᵃ ᵇ ⁺ ⁻ ⁰ ¹ ²` (product of exponents = two tiles side by side, `ᵃ ᵇ`, never `ˣ`), subscripts `x₁ y₂`, operators `− ÷ ×` (true minus `−`, not hyphen). A tile can be a whole word or term (`rise`, `xᵃ`). Keep answers to about 6 tiles so the board fits a phone; a long `lhs:` is fine (it moves above the board on narrow screens).
- When a formula's left side *is* the thing being asked (e.g. FOIL, exponent rules), put it in the Memory Match **first column** instead of in the formula: `| $x^a \cdot x^b$ | $x^{a+b}$ |`. Math works in either column.

## TikZ diagrams

Write a fenced ` ```{.tikz} ` block holding just `\begin{tikzpicture}...\end{tikzpicture}`. The preamble comes from the `diagram.engine.tikz.header-includes` list in `_quarto.yml`. It loads `amsmath,amssymb` (so `\dfrac` works) and the libraries `angles, quotes, calc, patterns, decorations.pathreplacing, arrows.meta, positioning, intersections`, and it defines these styles. Use them rather than hand-coding widths:

- `circ`, `seg`: circles and line segments (0.9pt)
- `center dot`: `\node[center dot] at (0,0) {};`
- `dim brace`: a dimension brace. Label it with `node[right=11pt]` or `node[below=11pt]`. The brace bulges outward when you draw it clockwise around the shape: the top edge left→right, the right edge top→bottom, the bottom edge right→left.
- `callout`: a stealth arrow from a label node to a feature, e.g. `to[bend left=25]`

House conventions:
- `\def\R{1.6}` is the radius. Place everything relative to `\R`.
- Set multi-panel figures side by side with `\begin{scope}[shift={(4.6,0)}]`, introduce each panel with a `% ---- (a) Name ----` comment, and caption it with `\node at (0,-\R-0.55) {\small (a) Name};`.
- Labels are math (`{$r$}`). Use `font=\footnotesize` on crowded labels. Hatch a shaded region with `pattern=north east lines`.
- Add color only to tell parts apart: `red!65!black` and `blue!65!black`. Everything else stays black.
- The same dark red in MathJax (cards, hints, solutions) is `\textcolor{#A60000}{a}`. MathJax rejects the `\textcolor[HTML]{...}` form, and an error there shows up as red error text on the page, not as a failed render. Use colour for meaning, e.g. FOIL's "these two terms get multiplied".
- If you need a new package, library or style, add it as a **new item** in the `header-includes` list, one LaTeX command per item. Two commands in one item get a stray `\\` between them, and every diagram fails. `additional-packages` looks like it should work, but the diagram filter turns it into plain text and drops the LaTeX. It is **not applied**, so pgfplots, tkz-euclide and the rest listed there are not loaded.
- Diagrams normally go in a `## Hint` section of a game file, not in the question itself.

To check a diagram, run `scripts/check.sh`. A TikZ error makes it fail.

## Hint/solution style

Each game file has its body split by `## Hint` and `## Solution` headings. The filter turns them into the Hint/Solution tabs. File formats are covered in the `quiz-authoring` skill.

- **Title:** for a Wordle, `title:` names the quantity in words ("Area of a circle", "Circumference of a circle, using its diameter"). It's shown above the board, so it should say exactly what is being asked.
- **Hints:** as many as the question needs (one is fine, three is fine), ordered from gentlest to most direct.
  - **Hint 1 must not give the answer away**, and neither may a diagram in it (e.g. don't draw the finished result). It names the idea to use, or asks a guiding question ("Is one denominator already a multiple of the other?").
  - Later hints get more concrete: a worked number example, the first step, or a check ("with $a = 2$, $b = 3$ it should give $x^5$").
  - For a Memory Match, no single hint should settle a pair outright.
- **Solution:** start with `**Answer:** $A = \pi r^2$`, give the reasoning (multi-step work in `aligned`), then name the likely traps as bullets that start with the bold key or mistake ("**d**: using the diameter instead of the radius gives an area 4 times too big.").
- **Precision:** every statement must be unambiguously true as written.
  - Prefer symbols to loose words: "$\pi = \frac{C}{d}$", not "the number of diameters around a circle"; "$x^{-a} = \frac{1}{x^a}$", not "flip it into a fraction"; "the product of $a$ factors of $x$", not "$x$ multiplied by itself $a$ times".
  - State the conditions: $x \neq 0$ for $x^0$, negative exponents and denominators; $x_1 \neq x_2$ for slope.
  - Say "numerator/denominator" (with "top/bottom" in brackets the first time), and "same base" for exponent rules.
  - Avoid phrases that read two ways: "no slope" (say "undefined" or "$m = 0$"), and "bigger" for expressions like $x$ vs $x^2$ (say "a factor of").
  - In trap bullets, name the mistake precisely and show it with numbers when you can ("$(x-4)^2 \neq x^2 \pm 16$").
  - Re-derive every worked example.
- **Voice:** short, plain sentences for a teenager. Use units to reason ("square units means area"). No em dashes; use colons or periods instead.

Multiple choice (`type: choice`): the options are a task list (`- [x]` marks the right one). The Solution explains the right option and then has one trap bullet per wrong option, starting with the option itself in bold (**$x < -3$**: ...). The old checkbox-form format is archived in `archive/_multiple-choice-circles.qmd` and is no longer used.
