--[[
  quiz.lua: turns short topic folders into the quiz page.

  In index.qmd, a block like

      ::: {.topic folder="topic/circles" title="Circles"}
      :::

  is replaced by a collapsible "Circles" section built from every
  topic/circles/_*.qmd file (sorted by filename). Each file says what it is
  with `type:` in its front matter. See _README/lua_filter.md for a
  beginner-friendly walkthrough, including how to add a new type.

  ::: {.quiz-results}
  :::
  becomes the "Check your results" button.
]]

local stringify = pandoc.utils.stringify

-- Stop the whole render with a message that names the bad file.
local function fail(file, msg)
  error("\n[quiz] " .. file .. ": " .. msg .. "\n", 0)
end

local function slug(s)
  return (s:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

local function attr(id, classes, attributes)
  return pandoc.Attr(id or "", classes or {}, attributes or {})
end

-- Default Wordle keyboard (every answer symbol must be one of these keys).
local DEFAULT_KEYS = { "π", "r", "d", "2", "²", "C", "θ", "½" }

---------------------------------------------------------------------------
-- Reading a question file
---------------------------------------------------------------------------

local function read_file(path)
  local f = io.open(path, "r")
  if not f then fail(path, "cannot open file") end
  local text = f:read("a")
  f:close()
  return pandoc.read(text, "markdown")
end

-- Split a file body at its "## Hint" / "## Solution" headings.
--   intro    = blocks before the first "##"
--   hints    = list of block lists, one per "## Hint"
--   solution = block list after "## Solution" (or nil)
local function split_sections(blocks, file)
  local parts = { intro = pandoc.Blocks {}, hints = {}, solution = nil }
  local current = parts.intro
  for _, b in ipairs(blocks) do
    if b.t == "Header" and b.level == 2 then
      local name = stringify(b.content):lower()
      if name:match("^hint") then
        current = pandoc.Blocks {}
        table.insert(parts.hints, current)
      elseif name:match("^solution") then
        if parts.solution then fail(file, "more than one '## Solution'") end
        current = pandoc.Blocks {}
        parts.solution = current
      else
        fail(file, "unknown section '## " .. stringify(b.content) ..
          "' (only '## Hint' and '## Solution' are allowed)")
      end
    else
      current:insert(b)
    end
  end
  return parts
end

-- Front-matter value as a list of strings ("π r ²" or [π, r, ²]).
local function symbol_list(value)
  local out = {}
  if value == nil then return out end
  if pandoc.utils.type(value) == "List" then
    for _, v in ipairs(value) do table.insert(out, stringify(v)) end
  else
    for s in stringify(value):gmatch("%S+") do table.insert(out, s) end
  end
  return out
end

---------------------------------------------------------------------------
-- Shared building blocks: tabs, hints, carousel items, carousels
---------------------------------------------------------------------------

-- Question / Hint / Solution tabs. `solution` may be nil.
local function tabset(question, hints, solution)
  local blocks = pandoc.Blocks {}
  blocks:insert(pandoc.Header(4, "Question"))
  blocks:extend(question)
  if #hints > 0 then
    blocks:insert(pandoc.Header(4, "Hint"))
    for i, h in ipairs(hints) do
      local callout = pandoc.Blocks { pandoc.Header(2, "Hint " .. i) }
      callout:extend(h)
      blocks:insert(pandoc.Div(callout, attr("", { "callout-tip" }, { collapse = "true" })))
    end
  end
  if solution and #solution > 0 then
    blocks:insert(pandoc.Header(4, "Solution"))
    blocks:extend(solution)
  end
  return pandoc.Div(blocks, attr("", { "panel-tabset" }))
end

-- One slide: "Wordle 1 of 3: Area" (or "Wordle: Area" when it's the only one) + its tabs.
local function carousel_item(game)
  local title
  if game.count > 1 then
    title = pandoc.Inlines {
      pandoc.Str(game.label), pandoc.Space(),
      pandoc.Span(pandoc.Str(tostring(game.index)), attr("", { "slide-num" })),
      pandoc.Space(), pandoc.Str("of"), pandoc.Space(), pandoc.Str(tostring(game.count) .. ":"),
      pandoc.Space(),
    }
  else
    title = pandoc.Inlines { pandoc.Str(game.label .. ":"), pandoc.Space() }
  end
  title:extend(game.title)
  local classes = { "carousel-item" }
  if game.index == 1 then table.insert(classes, "active") end
  return pandoc.Div({
    pandoc.Header(4, title, attr(game.id:gsub("/", "-") .. "-title", { "unlisted", "no-anchor" })),
    game.tabs,
  }, attr("", classes))
end

-- A carousel of slides plus Previous / Next / Shuffle buttons underneath.
-- The buttons are left out when there is only one slide, or when the type
-- draws its own (show_nav = false, e.g. Wordle puts them next to Enter).
local function carousel(id, noun, items, show_nav)
  local inner = pandoc.Div(items, attr("", { "carousel-inner" }))
  if #items < 2 or show_nav == false then
    return pandoc.Blocks {
      pandoc.Div({ inner }, attr(id, { "carousel", "slide", "mb-4" }, { ["data-bs-interval"] = "false" })),
    }
  end
  local html = string.format([[
<div class="quiz-nav">
<button class="btn btn-outline-primary" data-bs-target="#%s" data-bs-slide="prev">‹ Previous %s</button>
<button class="btn btn-outline-primary" data-bs-target="#%s" data-bs-slide="next">Next %s ›</button>
<button class="btn btn-outline-secondary" data-shuffle="#%s">Shuffle order</button>
</div>]], id, noun, id, noun, id)
  return pandoc.Blocks {
    pandoc.Div({ inner }, attr(id, { "carousel", "slide" }, { ["data-bs-interval"] = "false" })),
    pandoc.RawBlock("html", html),
  }
end

-- Plain-text title for data-title: math stays as \( ... \) so quiz.js can
-- have MathJax typeset it (e.g. in the results list).
local function title_text(inlines)
  local parts = {}
  for _, il in ipairs(inlines) do
    if il.t == "Math" then table.insert(parts, "\\(" .. il.text .. "\\)")
    else table.insert(parts, stringify(il)) end
  end
  return table.concat(parts)
end

-- The <div> a game's JavaScript attaches to (see quiz.js: Quiz.register).
local function game_div(game, type_name, extra_attrs, content)
  local a = {
    ["data-game"] = game.id,
    ["data-topic"] = game.topic_id,
    ["data-topic-title"] = game.topic_title,
    ["data-title"] = title_text(game.title),
  }
  for k, v in pairs(extra_attrs or {}) do a[k] = v end
  return pandoc.Div(content or {}, attr("", { "quiz-game", "quiz-" .. type_name }, a))
end

---------------------------------------------------------------------------
-- Question types
--
-- Each type is a table:
--   section  = heading of the topic sub-section ("Memory Match"); nil = no carousel
--   noun     = word used on the slide titles and Previous/Next buttons
--   order    = position of its sub-section inside a topic
--   intro    = optional blocks shown once at the top of the sub-section
--   nav      = false to leave out the Previous / Next / Shuffle buttons under
--              the carousel (the widget draws its own; game.carousel_id is set)
--   build(game, meta, blocks) -> fills game.tabs (for carousel types)
--                                or returns blocks (for non-carousel types)
---------------------------------------------------------------------------

local TYPES = {}

-- Memory match ------------------------------------------------------------

-- Math on a card: display style (full-size fractions, so subscripts and
-- numerators stay readable) and a thin space before each ")" so it doesn't
-- crowd the letter in front of it. "\right)" is left alone.
local function card_style(tex)
  tex = tex:gsub("\\right%)", "@@RIGHTPAREN@@"):gsub("%)", "\\,)"):gsub("@@RIGHTPAREN@@", "\\right)")
  return "\\displaystyle " .. tex
end

-- Only hide the left side when it is a single symbol (A, C, d, r_1, \theta).
local function card_tex(tex)
  local lhs, rhs = tex:match("^%s*(.-)%s*=%s*(.-)%s*$")
  if lhs and (lhs:match("^%a$") or lhs:match("^%a_%w$") or lhs:match("^%a_%b{}$")
      or lhs:match("^\\%a+$")) then
    tex = "= " .. rhs
  end
  return card_style(tex)
end

TYPES.memory = {
  section = "Memory Match",
  noun = "Memory Match",
  order = 1,
  build = function(game, meta, blocks)
    local tbl
    local rest = pandoc.Blocks {}
    for _, b in ipairs(blocks) do
      if b.t == "Table" and not tbl then tbl = b else rest:insert(b) end
    end
    if not tbl then fail(game.file, "a memory match needs a | Name | Formula | table") end

    local parts = split_sections(rest, game.file)
    local faces = pandoc.Inlines {}
    local n = 0
    for _, body in ipairs(tbl.bodies) do
      for _, row in ipairs(body.body) do
        local cells = row.cells
        if #cells < 2 then fail(game.file, "each table row needs a name and a formula") end
        local name = pandoc.utils.blocks_to_inlines(cells[1].contents)
        local math
        for _, il in ipairs(pandoc.utils.blocks_to_inlines(cells[2].contents)) do
          if il.t == "Math" then math = il; break end
        end
        if not math then
          fail(game.file, "the formula for '" .. stringify(name) .. "' must be written in $...$")
        end
        -- Math in the name column (e.g. "$x^a \cdot x^b$") gets the card styling too.
        name = pandoc.Inlines(name):walk({
          Math = function(m) return pandoc.Math("InlineMath", card_style(m.text)) end,
        })
        -- data-side: picking a card dims the other cards of the same side (quiz.js).
        faces:insert(pandoc.Span({ pandoc.Strong(name) },
          attr("", { "mm-face" }, { ["data-pair"] = tostring(n), ["data-side"] = "name" })))
        faces:insert(pandoc.Span({ pandoc.Math("InlineMath", card_tex(math.text)) },
          attr("", { "mm-face" }, { ["data-pair"] = tostring(n), ["data-side"] = "formula" })))
        n = n + 1
      end
    end
    if n < 2 then fail(game.file, "a memory match needs at least 2 rows") end

    local question = pandoc.Blocks {}
    if #parts.intro > 0 then
      question:extend(parts.intro)
    else
      question:insert(pandoc.Para(pandoc.read(
        "Pick a **name** and a **formula** to match them. Once you pick a card, the other cards of the same kind dim.", "markdown").blocks[1].content))
    end
    question:insert(game_div(game, "memory", {
      ["data-pairs"] = tostring(n),
      -- `face-up: true`: all cards visible from the start, names in table order
      ["data-face-up"] = (meta["face-up"] and stringify(meta["face-up"]) == "true") and "true" or "false",
    },
      { pandoc.Div({ pandoc.Plain(faces) }, attr("", { "mm-faces" })) }))

    -- The solution always shows the full table (with the left-hand sides).
    local solution = pandoc.Blocks { tbl }
    if parts.solution then solution:extend(parts.solution) end
    game.tabs = tabset(question, parts.hints, solution)
  end,
}

-- Formula Wordle ----------------------------------------------------------

TYPES.wordle = {
  section = "Formula Wordle",
  noun = "Wordle",
  order = 2,
  nav = false,   -- Previous / Next sit on the Enter / Reset row instead (quiz.js)
  intro = function()
    return pandoc.read([[
Fill in the blanks to finish each formula, then press **Enter**.

::: {.callout-note collapse="true"}
## How to play Wordle

- [Green]{.badge .bg-success}: right symbol, right spot. It stays filled in on your next try.
- [Yellow]{.badge .wordle-yellow}: the symbol is in the formula, but in a different spot.
- [Gray]{.badge .bg-secondary}: the symbol isn't in the formula.
:::
]], "markdown").blocks
  end,
  build = function(game, meta, blocks)
    local parts = split_sections(blocks, game.file)
    if not meta.lhs then fail(game.file, "a wordle needs `lhs:` (e.g. lhs: \"A =\")") end
    local answer = symbol_list(meta.answer)
    if #answer == 0 then fail(game.file, "a wordle needs `answer:` (e.g. answer: π r ²)") end
    local keys = meta.keys and symbol_list(meta.keys) or DEFAULT_KEYS
    for _, s in ipairs(answer) do
      local found = false
      for _, k in ipairs(keys) do if k == s then found = true end end
      if not found then
        fail(game.file, "answer symbol '" .. s .. "' is not on the keyboard; add it to `keys:`")
      end
    end

    local question = pandoc.Blocks {
      -- The quantity being tested, shown big above the board.
      pandoc.Div({ pandoc.Plain(game.title) }, attr("", { "quiz-quantity" })),
    }
    question:extend(parts.intro)
    question:insert(game_div(game, "wordle", {
      ["data-lhs"] = stringify(meta.lhs),
      ["data-answer"] = table.concat(answer, " "),
      ["data-keys"] = table.concat(keys, " "),
      ["data-tries"] = meta.tries and stringify(meta.tries) or "6",
      ["data-carousel"] = "#" .. game.carousel_id,   -- for the Previous / Next buttons
      ["data-count"] = tostring(game.count),
    }))
    game.tabs = tabset(question, parts.hints, parts.solution)
  end,
}

-- Multiple choice ---------------------------------------------------------
-- The options are a task list in the question text:
--     - [ ] wrong
--     - [x] right        (exactly one)
-- Pandoc reads the boxes as the characters ☐ / ☒.

local function task_mark(item)
  local first = item[1]
  if first and (first.t == "Plain" or first.t == "Para") then
    local s = first.content[1]
    if s and s.t == "Str" then
      if s.text == "☐" then return false elseif s.text == "☒" then return true end
    end
  end
  return nil
end

TYPES.choice = {
  section = "Multiple Choice",
  noun = "Question",
  order = 0,
  build = function(game, meta, blocks)
    local parts = split_sections(blocks, game.file)
    local list_at
    for i, b in ipairs(parts.intro) do
      if b.t == "BulletList" and task_mark(b.content[1]) ~= nil then list_at = i end
    end
    if not list_at then
      fail(game.file, "a choice question needs its options as a list: '- [ ] wrong' and '- [x] right'")
    end
    local list = parts.intro:remove(list_at)
    local options, correct = pandoc.Blocks {}, 0
    for _, item in ipairs(list.content) do
      local mark = task_mark(item)
      if mark == nil then fail(game.file, "every option must start with '[ ]' or '[x]'") end
      local inl = pandoc.utils.blocks_to_inlines(item)
      inl:remove(1)                                        -- the ☐ / ☒ box
      if inl[1] and inl[1].t == "Space" then inl:remove(1) end
      if mark then correct = correct + 1 end
      options:insert(pandoc.Div({ pandoc.Plain(inl) },
        attr("", { "choice-option" }, { ["data-correct"] = mark and "true" or "false" })))
    end
    if correct ~= 1 then fail(game.file, "mark exactly one option with [x] (found " .. correct .. ")") end
    if #options < 2 then fail(game.file, "a choice question needs at least 2 options") end

    local question = pandoc.Blocks {}
    question:extend(parts.intro)
    question:insert(game_div(game, "choice", {
      -- `shuffle: false` keeps the options in the order they are written
      ["data-order"] = (meta.shuffle and stringify(meta.shuffle) == "false") and "fixed" or "shuffle",
    }, { pandoc.Div(options, attr("", { "choice-options" })) }))
    game.tabs = tabset(question, parts.hints, parts.solution)
  end,
}

-- Parentheses puzzle --------------------------------------------------------
-- The student taps the gaps between the tokens of `expression:` to place
-- parentheses until it equals `target:` (for every x, or only at `x:`).
-- quiz.js does the arithmetic, so any correct placement is accepted.

-- Characters the quiz.js calculator understands.
local function check_math(file, field, s)
  local rest = s:gsub("[%d%.x%s%(%)%+%-%^%*/]", ""):gsub("−", ""):gsub("·", ""):gsub("×", "")
    :gsub("÷", ""):gsub("²", "")
  if rest ~= "" then
    fail(file, "`" .. field .. ":` can only use digits, x, + − · × ÷ ^ ² and parentheses (found '" .. rest .. "')")
  end
end

TYPES.parens = {
  section = "Parentheses Puzzle",
  noun = "Puzzle",
  order = 3,
  build = function(game, meta, blocks)
    local parts = split_sections(blocks, game.file)
    local tokens = symbol_list(meta.expression)
    if #tokens < 3 then fail(game.file, "a parens puzzle needs `expression:` (space-separated, e.g. − 1 · x + 2)") end
    if not meta.target then fail(game.file, "a parens puzzle needs `target:` (e.g. target: x²)") end
    local target = stringify(meta.target)
    check_math(game.file, "expression", table.concat(tokens, " "))
    check_math(game.file, "target", target)
    if meta.x then check_math(game.file, "x", stringify(meta.x)) end

    local question = pandoc.Blocks {}
    question:extend(parts.intro)
    question:insert(game_div(game, "parens", {
      ["data-expression"] = table.concat(tokens, " "),
      ["data-target"] = target,
      ["data-x"] = meta.x and stringify(meta.x) or "",
      ["data-pairs"] = meta.pairs and stringify(meta.pairs) or "1",
    }))
    game.tabs = tabset(question, parts.hints, parts.solution)
  end,
}

-- Notes: plain content shown at the bottom of the topic (no carousel) -----

TYPES.notes = {
  order = 99,
  build = function(game, meta, blocks)
    return blocks
  end,
}

---------------------------------------------------------------------------
-- Building a topic
---------------------------------------------------------------------------

local topic_count = 0

local function build_topic(div)
  local folder = div.attributes.folder
  if not folder then error("\n[quiz] a .topic block in index.qmd needs folder=\"topic/...\"\n", 0) end
  local title_text = div.attributes.title or pandoc.path.filename(folder)
  local topic_id = slug(title_text)
  local base = pandoc.path.directory(quarto.doc.input_file)
  local dir = pandoc.path.join({ base, folder })

  local ok, names = pcall(pandoc.system.list_directory, dir)
  if not ok then fail(folder, "folder not found") end
  table.sort(names)

  -- Read every _*.qmd file and group it by type.
  local groups = {}
  for _, name in ipairs(names) do
    if name:match("^_.*%.qmd$") then
      local file = pandoc.path.join({ folder, name })
      local doc = read_file(pandoc.path.join({ dir, name }))
      local type_name = doc.meta.type and stringify(doc.meta.type)
      if not type_name then fail(file, "missing `type:` in the front matter") end
      local T = TYPES[type_name]
      if not T then fail(file, "unknown type '" .. type_name .. "'") end
      if T.section and not doc.meta.title then fail(file, "missing `title:` in the front matter") end
      groups[type_name] = groups[type_name] or {}
      table.insert(groups[type_name], {
        file = file,
        meta = doc.meta,
        blocks = doc.blocks,
        id = topic_id .. "/" .. name:gsub("^_", ""):gsub("%.qmd$", ""),
        topic_id = topic_id,
        topic_title = title_text,
        title = doc.meta.title and pandoc.Inlines(doc.meta.title) or pandoc.Inlines {},
      })
    end
  end

  -- Lay out each type's sub-section in its fixed order.
  local type_names = {}
  for k in pairs(groups) do table.insert(type_names, k) end
  table.sort(type_names, function(a, b) return TYPES[a].order < TYPES[b].order end)

  local body = pandoc.Blocks {}
  for _, type_name in ipairs(type_names) do
    local T, games = TYPES[type_name], groups[type_name]
    if T.section then
      body:insert(pandoc.Header(3, T.section, attr(topic_id .. "-" .. type_name, { "no-anchor" })))
      if T.intro then body:extend(T.intro()) end
      local items = {}
      local carousel_id = topic_id .. "-" .. type_name .. "-carousel"
      for i, game in ipairs(games) do
        game.index, game.count, game.label, game.carousel_id = i, #games, T.noun, carousel_id
        T.build(game, game.meta, game.blocks)
        table.insert(items, carousel_item(game))
      end
      body:extend(carousel(carousel_id, T.noun, items, T.nav))
    else
      for _, game in ipairs(games) do body:extend(T.build(game, game.meta, game.blocks)) end
    end
  end

  -- Collapsible topic: the first topic on the page starts open.
  -- The header is raw HTML on purpose: a Markdown "##" header would get its
  -- attributes moved onto a wrapping <section>, making the whole topic a toggle.
  topic_count = topic_count + 1
  local open = topic_count == 1
  local body_id = "topic-" .. topic_id
  local escaped = title_text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  local header = pandoc.RawBlock("html", string.format(
    '<h2 id="%s" class="quiz-topic-toggle" role="button" tabindex="0" data-bs-toggle="collapse" '
    .. 'data-bs-target="#%s" aria-controls="%s" aria-expanded="%s">%s</h2>',
    topic_id, body_id, body_id, open and "true" or "false", escaped))
  return pandoc.Div({
    header,
    pandoc.Div(body, attr(body_id, { "collapse", "quiz-topic-body", open and "show" or nil })),
  }, attr("", { "quiz-topic" }))
end

local function build_results()
  return pandoc.RawBlock("html", [[
<div class="quiz-results-box">
<button class="btn btn-primary" data-quiz-results>Check your results</button>
<button class="btn btn-outline-secondary" data-quiz-reset-all>Reset all progress</button>
<div class="quiz-results-output"></div>
</div>]])
end

return {
  {
    Div = function(div)
      if div.classes:includes("topic") then
        quarto.doc.add_html_dependency({
          name = "quiz",
          version = "1.0.0",
          scripts = { { path = "quiz.js", afterBody = true } },
          stylesheets = { "quiz.css" },
        })
        return build_topic(div)
      elseif div.classes:includes("quiz-results") then
        return build_results()
      end
    end,
  },
}
