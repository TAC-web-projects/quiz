---
name: quiz-latex-style
description: How this Quarto quiz site writes math and TikZ diagrams, and the house voice for hints and solutions. Use it whenever you write or edit math in any .qmd here, especially the game files under topic/. That covers $...$ or $$ equations, ```{.tikz} diagrams, Memory Match formula tables, Wordle answer symbols, hints, solutions, and changes to the TikZ preamble in _quarto.yml. Use it even when the user just says "add a wordle about X" or "draw a picture for this hint". For where files go and how games are wired up, see the quiz-authoring skill.
---

# Quiz LaTeX & style

The site is Quarto HTML (`_quarto.yml`, output in `docs/`) for ACT-level geometry practice, used mostly on phones. Math shows up in four places, and each place handles LaTeX differently:

| Where | Engine | How to write it |
|---|---|---|
| Hints, solutions, titles, notes | MathJax (`html-math-method: mathjax`) | `$...$` / `$$...$$` |
| Diagrams | `pandoc-ext/diagram` → lualatex → SVG | ` ```{.tikz} ` block |
| Memory Match table | MathJax, via the quiz filter | full formula in `$...$`, normal single backslashes: `$A = \pi r^2$`. Cards drop a one-symbol left side by themselves (`= \pi r^2`). |
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
- Diagrams normally go in a `## Hint` section of a game file, not in the question itself.

To check a diagram, run `scripts/check.sh`. A TikZ error makes it fail.

## Hint/solution style

Each game file has its body split by `## Hint` and `## Solution` headings. The filter turns them into the Hint/Solution tabs. File formats are covered in the `quiz-authoring` skill.

- **Title:** for a Wordle, `title:` names the quantity in words ("Area of a circle", "Circumference of a circle, using its diameter"). It's shown above the board, so it should say exactly what is being asked.
- **Hints:** usually two. Hint 1 nudges ("Area is measured in square units…") and may show a diagram. Hint 2 gives a concrete check ("How many radii make one diameter?", "try $r = 3$").
- **Solution:** start with `**Answer:** $A = \pi r^2$`, give the reasoning (multi-step work in `aligned`), then name the likely traps as bullets that start with the bold key or mistake ("**d**: using the diameter instead of the radius gives an area 4 times too big.").
- **Voice:** short, plain sentences for a teenager. Use units to reason ("square units means area"). No em dashes; use colons or periods instead.

The old multiple-choice format (checkbox forms, "Why the others are wrong" by letter) is archived in `archive/_multiple-choice-circles.qmd` and is no longer used.
