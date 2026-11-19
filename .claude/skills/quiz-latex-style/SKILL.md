---
name: quiz-latex-style
description: How this Quarto quiz site writes math and TikZ diagrams, and the house style for questions, hints and solutions. Use it whenever you add or edit anything in index.qmd or another .qmd here that involves math. That covers $...$ or $$ equations, ```{.tikz} diagrams, memory-match formulas, Wordle symbols, new quiz questions, hints, solutions, and changes to the TikZ preamble in _quarto.yml. Use it even when the user just says "add a question about X" or "draw a picture for this hint".
---

# Quiz LaTeX & style

The site is Quarto HTML (`_quarto.yml`, output in `docs/`) for ACT-level geometry practice, used mostly on phones. Math shows up in four places, and each place handles LaTeX differently:

| Where | Engine | How to write it |
|---|---|---|
| Prose, choices, solutions | MathJax (`html-math-method: mathjax`) | `$...$` / `$$...$$` |
| Diagrams | `pandoc-ext/diagram` → lualatex → SVG | ` ```{.tikz} ` block |
| Memory-match cards | OJS `tex` (KaTeX) inside a JS string | double the backslashes: `"A = \\pi r^2"` |
| Wordle tiles/keys | plain text, no LaTeX | Unicode: `π r d 2 ² C θ ½` |

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

- Keep display math out of quiz `<label>`s and memory cards, because they have to fit on one line on a phone (`.mm-card .katex` is `nowrap`, and the text shrinks to fit).

## TikZ diagrams

Write a fenced ` ```{.tikz} ` block holding just `\begin{tikzpicture}...\end{tikzpicture}`. The preamble comes from `diagram.engine.tikz.additional-packages` in `_quarto.yml`. It loads amsmath, pgfplots, tkz-euclide and the libraries `angles, quotes, calc, patterns, decorations.pathreplacing, arrows.meta, positioning, intersections`, and it defines these styles. Use them rather than hand-coding widths:

- `circ`, `seg`: circles and line segments (0.9pt)
- `center dot`: `\node[center dot] at (0,0) {};`
- `dim brace`: a dimension brace. Label it with `node[right=11pt]` or `node[below=11pt]`. The brace bulges outward when you draw it clockwise around the shape: the top edge left→right, the right edge top→bottom, the bottom edge right→left.
- `callout`: a stealth arrow from a label node to a feature, e.g. `to[bend left=25]`

House conventions:
- `\def\R{1.6}` is the radius. Place everything relative to `\R`.
- Set multi-panel figures side by side with `\begin{scope}[shift={(4.6,0)}]`, introduce each panel with a `% ---- (a) Name ----` comment, and caption it with `\node at (0,-\R-0.55) {\small (a) Name};`.
- Labels are math (`{$r$}`). Use `font=\footnotesize` on crowded labels. Hatch a shaded region with `pattern=north east lines`.
- Add color only to tell parts apart: `red!65!black` and `blue!65!black`. Everything else stays black.
- If you need a new library or style, add it to `additional-packages`. That key passes raw TeX through. `header-includes` escapes the backslashes, so it has no effect.
- Diagrams normally go inside a hint callout, not in the question itself.

To check a diagram, render it with `quarto render index.qmd`. A TikZ error makes the render fail, and the message names the block.

## Question/hint/solution style

Each item is a `.carousel-item` with a `.panel-tabset` that has the tabs **Question / Hint / Solution**. Copy an existing item, then bump `name="qN"` and "of N".

- **Question:** a checkbox `<form class="quiz-question" data-answer="b,d">`. Write choices as `A. $...$`. Add "(more than one correct choice)" after a `<br>`. Make the wrong choices *plausible mistakes*, such as a 2 on the wrong side, a missing square, or radius and diameter swapped.
- **Hint:** two `::: {.callout-tip collapse="true"}` blocks titled `## Hint 1` and `## Hint 2`. Hint 1 nudges and often shows a diagram. Hint 2 gives a concrete check ("try $r = 3$").
- **Solution:** `**Answer: B & D.**`, then the derivation in `aligned`, then `**Why the others are wrong:**` as bullets. Each bullet starts with the bold letter and names the mistake ("forgets to square the 2. That's 2 times too big.").
- **Voice:** short, plain sentences for a teenager. Use units to reason ("square units means area"). No em dashes; use colons or periods instead.
