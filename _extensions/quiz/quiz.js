/*
  quiz.js: the interactive parts of the quiz page.

  The Lua filter (quiz.lua) writes plain HTML like
      <div class="quiz-game quiz-wordle" data-game="circles/wordle-area" data-lhs="A =" ...>
  and this file brings each one to life.

  Adding a question type = one Quiz.register(...) call (see the bottom of
  this file and _README/lua_filter.md):

      Quiz.register("mytype", {
        init(el, game) { ... },      // build the widget inside el
        summary(state) { ... },      // -> { solved: true/false, detail: "..." }
      });

  `game.state` is this game's saved progress (or {} the first time), and
  `game.save(newState)` stores it in the browser so it survives a reload.
*/
(() => {
  // ---------------------------------------------------------------- storage
  const STORE_KEY = "tac-quiz-progress-v1";
  let progress = {};
  try { progress = JSON.parse(localStorage.getItem(STORE_KEY)) || {}; } catch (e) { progress = {}; }
  const persist = () => {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(progress)); } catch (e) { /* private mode */ }
  };

  // ---------------------------------------------------------------- registry
  const types = {};
  const listeners = [];   // called whenever any game saves (refreshes results)

  const Quiz = {
    register(name, def) { types[name] = def; },
    onChange(fn) { listeners.push(fn); },
    types,
  };
  window.Quiz = Quiz;

  function startGame(el) {
    const type = [...el.classList].find(c => c.startsWith("quiz-") && c !== "quiz-game").slice(5);
    const def = types[type];
    if (!def) { console.warn("quiz.js: no Quiz.register for type", type); return; }
    const id = el.dataset.game;
    const game = {
      id,
      get state() { return progress[id] || {}; },
      save(state) {
        progress[id] = state;
        persist();
        listeners.forEach(fn => fn());
      },
    };
    def.init(el, game);
  }

  // ---------------------------------------------------------------- helpers
  const h = (html) => {
    const t = document.createElement("template");
    t.innerHTML = html.trim();
    return t.content.firstElementChild;
  };

  const shuffle = (arr) => {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  };

  // ======================================================== MEMORY MATCH
  // el contains pre-rendered faces: <span class="mm-face" data-pair="0" data-side="name">…</span>,
  // one "name" and one "formula" per pair. MathJax has already typeset them, so we
  // only move them into card buttons and show/hide them.
  //
  // Names and formulas are dealt into two separate piles. Flipping a card locks
  // the rest of its pile (grayed out) until a card from the other pile is picked,
  // so every second flip is a real match attempt. Tapping the open card again
  // puts it back.
  // state = { found: [pair numbers], mismatches: n, done: true/false }
  Quiz.register("memory", {
    init(el, game) {
      const faces = [...el.querySelectorAll(".mm-face")];
      const pairs = Number(el.dataset.pairs);
      const status = h(`<p class="mm-status"></p>`);
      const resetBtn = h(`<button class="btn btn-secondary mb-2">Reset &amp; shuffle</button>`);
      const piles = {};
      const pileBox = h(`<div class="mm-piles"></div>`);
      for (const side of ["name", "formula"]) {
        const pile = h(`<div class="mm-pile"><div class="mm-pile-label"></div><div class="mm-grid"></div></div>`);
        pile.firstChild.textContent = side === "name" ? (el.dataset.nameLabel || "Names") : (el.dataset.formulaLabel || "Formulas");
        piles[side] = pile.querySelector(".mm-grid");
        pileBox.append(pile);
      }
      el.querySelector(".mm-faces").remove();
      el.append(resetBtn, status, pileBox);

      let cards = [], first = null, busy = false, timer;

      const showStatus = () => {
        const s = game.state, found = (s.found || []).length;
        status.textContent = found === pairs
          ? `All matched! 🎉 (${s.mismatches || 0} mismatches)`
          : `Pairs found: ${found} / ${pairs}`;
      };

      // Shrink a card's text until it fits on one line (long formulas on phones).
      const fit = (card) => {
        card.face.style.fontSize = "";
        for (let s = 95; s >= 50 && card.btn.scrollWidth > card.btn.clientWidth; s -= 5) card.face.style.fontSize = s + "%";
      };
      const flip = (card, up) => {
        card.btn.classList.toggle("open", up);
        if (up) fit(card);
      };
      // Lock (gray out) or unlock every unmatched card in one pile except `except`.
      const lockPile = (side, locked, except) => {
        for (const c of cards) {
          if (c.side !== side || c === except || c.matched) continue;
          c.btn.disabled = locked;
          c.btn.classList.toggle("mm-locked", locked);
        }
      };
      const markMatched = (c) => {
        c.matched = true;
        c.btn.disabled = true;
        c.btn.className = "btn mm-card mm-matched open";
      };

      function choose(card) {
        if (busy || card.matched) return;
        if (first === card) {                       // tap the open card again: put it back
          flip(card, false); lockPile(card.side, false); first = null; return;
        }
        flip(card, true);
        if (!first) { first = card; lockPile(card.side, true, card); return; }

        const a = first, b = card;
        const s = { found: [...(game.state.found || [])], mismatches: game.state.mismatches || 0 };
        if (a.pair === b.pair) {                    // match: both turn green and stay up
          markMatched(a); markMatched(b);
          s.found.push(Number(a.pair));
          lockPile(a.side, false);
          first = null;
        } else {                                    // no match: flip both back after a moment
          s.mismatches++;
          busy = true;
          timer = setTimeout(() => {
            flip(a, false); flip(b, false);
            lockPile(a.side, false);
            first = null; busy = false;
          }, 1200);
        }
        s.done = s.found.length === pairs;
        game.save(s);
        showStatus();
      }

      function deal() {
        clearTimeout(timer);
        first = null; busy = false; cards = [];
        piles.name.replaceChildren(); piles.formula.replaceChildren();
        const found = game.state.found || [];
        for (const face of shuffle([...faces])) {
          const btn = h(`<button class="btn btn-outline-primary mm-card"><span class="mm-q">?</span></button>`);
          btn.append(face);
          const card = { btn, face, pair: face.dataset.pair, side: face.dataset.side || "name", matched: false };
          btn.onclick = () => choose(card);
          piles[card.side].append(btn);
          cards.push(card);
          if (found.includes(Number(card.pair))) { markMatched(card); fit(card); }
        }
        showStatus();
      }

      resetBtn.onclick = () => { game.save({ found: [], mismatches: 0 }); deal(); };
      deal();
      // Fonts can finish loading after we deal; re-fit the open cards then.
      document.fonts && document.fonts.ready.then(() => cards.filter(c => c.btn.classList.contains("open")).forEach(fit));
    },

    summary(s) {
      const found = (s.found || []).length;
      if (found === 0 && !s.mismatches) return { solved: false, detail: "not started" };
      const miss = `${s.mismatches || 0} mismatch${s.mismatches === 1 ? "" : "es"}`;
      return s.done
        ? { solved: true, detail: `solved, ${miss}` }
        : { solved: false, detail: `${found} pair${found === 1 ? "" : "s"} found so far, ${miss}` };
    },
  });

  // ======================================================== FORMULA WORDLE
  // data-lhs="A =", data-answer="π r ²", data-keys="π r d 2 ² C θ ½", data-tries="6"
  // state = { guesses: [["π","r","²"], ...] }  (replayed on reload)
  Quiz.register("wordle", {
    init(el, game) {
      const lhs = el.dataset.lhs;
      const answer = el.dataset.answer.split(" ");
      const keys = el.dataset.keys.split(" ");
      const maxTries = Number(el.dataset.tries || 6);
      const look = {                       // [tile classes, key classes] for each result
        success: ["bg-success text-white", "btn-success"],
        warning: ["wordle-yellow", "wordle-yellow"],
        secondary: ["bg-secondary text-white", "btn-secondary"],
      };
      const tileCls = "wordle-tile border rounded fs-4 d-inline-flex align-items-center justify-content-center";
      const board = h(`<div class="d-flex flex-column gap-1 mb-2"></div>`);
      const msg = h(`<p class="wordle-msg"></p>`);
      const kb = h(`<div class="d-flex flex-wrap gap-1 mb-3"></div>`);
      // Second row: Enter, Reset, and (when there are several Wordles) Previous / Next.
      const enterBtn = h(`<button class="btn btn-primary">Enter</button>`);
      const resetBtn = h(`<button class="btn btn-secondary">Reset</button>`);
      const controls = h(`<div class="wordle-controls"></div>`);
      controls.append(enterBtn, resetBtn);
      if (Number(el.dataset.count) > 1) {
        const nav = h(`<div class="wordle-nav">
          <button class="btn btn-outline-primary" data-bs-slide="prev" aria-label="Previous Wordle"><i class="bi bi-arrow-left"></i><span class="wordle-nav-text"> Previous</span></button>
          <button class="btn btn-outline-primary" data-bs-slide="next" aria-label="Next Wordle"><span class="wordle-nav-text">Next </span><i class="bi bi-arrow-right"></i></button>
        </div>`);
        nav.querySelectorAll("button").forEach(b => b.dataset.bsTarget = el.dataset.carousel);
        controls.append(nav);
      }
      const keyBtns = {};
      let typed, locked, row, guesses, done;

      // Full guess: locked greens stay put; typed symbols fill the other blanks in order
      const full = () => { let j = 0; return answer.map((a, i) => locked[i] ? a : typed[j++]); };
      const blanks = () => locked.filter(x => !x).length;

      // Wordle rules: greens first, then yellows use up whatever answer symbols are left
      function score(g) {
        const left = answer.filter((a, i) => g[i] !== a);
        return g.map((s, i) =>
          s === answer[i] ? "success"
            : left.includes(s) ? (left.splice(left.indexOf(s), 1), "warning")
              : "secondary");
      }

      // If a row (left side + tiles) is too wide for the screen, show the left
      // side once above the board instead of at the start of every row.
      const lhsTop = h(`<div class="wordle-lhs-top fs-4 mb-1"></div>`);
      lhsTop.textContent = lhs + " …";
      const checkFit = () => {
        el.classList.remove("wordle-lhs-above");
        el.style.removeProperty("--tile");
        const first = board.firstElementChild;
        const overflows = () => first && first.scrollWidth > first.clientWidth + 1;
        if (!overflows()) return;
        el.classList.add("wordle-lhs-above");
        // Still too wide (many tiles): shrink the tiles to share the width.
        if (overflows()) {
          const gap = 4, n = answer.length;
          el.style.setProperty("--tile", Math.floor((first.clientWidth - gap * (n - 1)) / n) + "px");
        }
      };

      function newRow() {
        row = h(`<div class="wordle-row d-flex gap-1 align-items-center"><span class="wordle-lhs fs-4 me-2"></span></div>`);
        row.firstChild.textContent = lhs;
        answer.forEach((a, i) => {
          const tile = h(`<span class="${tileCls} ${locked[i] ? look.success[0] : ""}"></span>`);
          tile.textContent = locked[i] ? a : "";
          row.append(tile);
        });
        board.append(row);
      }

      function submit(g) {
        score(g).forEach((c, i) => {
          row.children[i + 1].className = `${tileCls} ${look[c][0]}`;
          row.children[i + 1].textContent = g[i];
          if (c === "success") locked[i] = true;                  // greens carry over to the next row
          const b = keyBtns[g[i]], rank = ["secondary", "warning", "success"].indexOf(c);
          if (b && rank > b.rank) { b.rank = rank; b.className = `btn fs-5 ${look[c][1]}`; }  // keys keep their best color
        });
        guesses.push(g);
        if (locked.every(Boolean)) { done = true; msg.textContent = `Solved in ${guesses.length} ${guesses.length === 1 ? "try" : "tries"}! 🎉`; }
        else if (guesses.length === maxTries) { done = true; msg.textContent = `Out of tries. The answer is ${lhs} ${answer.join("")}`; }
        else { typed = []; newRow(); msg.textContent = ""; }
      }

      function press(k) {
        if (done) return;
        if (k === "⌫") typed.pop();
        else if (k !== "Enter") { if (typed.length < blanks()) typed.push(k); }
        else if (typed.length < blanks()) { msg.textContent = "Fill every blank first."; return; }
        else {
          submit(full());
          game.save({ guesses, solved: locked.every(Boolean), max: maxTries });
          return;
        }
        full().forEach((s, i) => row.children[i + 1].textContent = s ?? "");
      }

      function reset(replay) {
        board.replaceChildren();
        typed = []; locked = answer.map(() => false); guesses = []; done = false; msg.textContent = "";
        for (const b of Object.values(keyBtns)) { b.rank = -1; b.className = "btn btn-outline-primary fs-5"; }
        newRow();
        for (const g of replay) submit(g);   // restore saved progress
      }

      for (const k of [...keys, "⌫"]) {
        keyBtns[k] = h(`<button style="min-width:2.5em"></button>`);
        keyBtns[k].textContent = k;
        keyBtns[k].onclick = () => press(k);
        kb.append(keyBtns[k]);
      }
      enterBtn.onclick = () => press("Enter");
      resetBtn.onclick = () => { game.save({ guesses: [] }); reset([]); };
      el.append(lhsTop, board, msg, kb, controls);
      reset(game.state.guesses || []);
      // Measure once visible (topics/slides start hidden), and on resize.
      let lastWidth = 0;
      new ResizeObserver(() => {
        const w = el.clientWidth;
        if (w > 0 && w !== lastWidth) { lastWidth = w; checkFit(); }
      }).observe(el);
      document.fonts && document.fonts.ready.then(checkFit);
    },

    summary(s) {
      const n = (s.guesses || []).length;
      const tries = `${n} ${n === 1 ? "try" : "tries"}`;
      if (n === 0) return { solved: false, detail: "not started" };
      if (s.solved) return { solved: true, detail: `solved in ${tries}` };
      if (n >= (s.max || 6)) return { solved: false, detail: `out of tries (${tries})` };
      return { solved: false, detail: `${tries} so far` };
    },
  });

  // ======================================================== PAGE-WIDE PIECES

  // Shuffle buttons: put a carousel's slides in random order, show the new first
  // one, and renumber the "1 of N" titles. Games keep their progress.
  function setupShuffle() {
    for (const btn of document.querySelectorAll("[data-shuffle]")) {
      const inner = document.querySelector(btn.dataset.shuffle + " .carousel-inner");
      btn.onclick = () => shuffle([...inner.children]).forEach((item, i) => {
        item.classList.toggle("active", i === 0);
        item.querySelector(".slide-num").textContent = i + 1;
        inner.append(item);
      });
    }
  }

  // Topic headers open/close with the keyboard too (Enter or Space).
  function setupTopicKeys() {
    for (const h2 of document.querySelectorAll(".quiz-topic-toggle")) {
      h2.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); h2.click(); }
      });
    }
  }

  // "Check your results": a score per topic, plus the detail of every game.
  function setupResults() {
    const box = document.querySelector(".quiz-results-box");
    if (!box) return;
    const out = box.querySelector(".quiz-results-output");
    let shown = false;

    const render = () => {
      const topics = new Map();
      for (const el of document.querySelectorAll(".quiz-game")) {
        const type = [...el.classList].find(c => c.startsWith("quiz-") && c !== "quiz-game").slice(5);
        const def = types[type];
        if (!def || !def.summary) continue;
        const r = def.summary(progress[el.dataset.game] || {});
        if (!topics.has(el.dataset.topic)) topics.set(el.dataset.topic, { title: el.dataset.topicTitle, games: [] });
        topics.get(el.dataset.topic).games.push({ title: el.dataset.title, ...r });
      }
      out.replaceChildren();
      for (const t of topics.values()) {
        const solved = t.games.filter(g => g.solved).length;
        const section = h(`<div class="quiz-result-topic"><h4></h4><ul></ul></div>`);
        section.querySelector("h4").textContent = `${t.title}: ${solved} / ${t.games.length} solved`;
        for (const g of t.games) {
          const li = document.createElement("li");
          li.textContent = `${g.solved ? "✅" : "⬜"} ${g.title}: ${g.detail}`;
          section.querySelector("ul").append(li);
        }
        out.append(section);
      }
      // Titles may contain math written as \( ... \); typeset it.
      if (window.MathJax && MathJax.typesetPromise) MathJax.typesetPromise([out]);
    };

    box.querySelector("[data-quiz-results]").onclick = () => { shown = true; render(); };
    box.querySelector("[data-quiz-reset-all]").onclick = () => {
      if (!confirm("Erase all your progress on this page?")) return;
      progress = {};
      persist();
      location.reload();
    };
    Quiz.onChange(() => { if (shown) render(); });   // keep it live once shown
  }

  function start() {
    document.querySelectorAll(".quiz-game").forEach(startGame);
    setupShuffle();
    setupTopicKeys();
    setupResults();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
