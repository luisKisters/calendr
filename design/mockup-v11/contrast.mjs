#!/usr/bin/env node
// Contrast check for Calendr v11 (v10 + the Readability designer, look R, Dark): every look (L0 = v8, L1–L4) × Dark and Paper, and the Designer: every combination of its
// colour controls (READABILITY-BRIEF.md §1 and §5). The targets are the v8 targets, unchanged.
//   node design/mockup-v10/contrast.mjs              summary per look: pairs, misses and the tightest pair per theme
//   node design/mockup-v10/contrast.mjs --all        every pair
//   node design/mockup-v10/contrast.mjs --fails      only the misses
//   node design/mockup-v10/contrast.mjs --look L3    one look only
//   node design/mockup-v10/contrast.mjs --no-designer   skip the Designer sweep
//   node design/mockup-v11/contrast.mjs --rd          only the Readability sweep (every combination of its colour levers) · --no-rd skips it
// WCAG 2.x relative-luminance ratio and APCA-W3 0.0.98G-4g (Lc; negative = light on dark, only the size counts).
// Tokens and event recipes come from tokens.js (the page reads the same file); calendar colours from data.js (CALS0 + SWATCHES).
import { createRequire } from 'node:module'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const req = createRequire(import.meta.url)
const THEME = req(join(here, 'tokens.js'))
const DESIGNER = req(join(here, 'designer.js'))
const READ = req(join(here, 'readability.js'))
const rdOnly = process.argv.includes('--rd')
const arg = process.argv.slice(2), onlyFails = arg.includes('--fails'), all = arg.includes('--all')
const only = arg.includes('--look') ? arg[arg.indexOf('--look') + 1] : null
const PACKS = rdOnly ? [] : THEME.ids.filter(id => !only || id === only).map(id => THEME.look(id))

// ---------------------------------------------------------------- maths
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255)
const lin = c => c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
const relL = h => { const [r, g, b] = rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b }
const wcag = (a, b) => { const x = relL(a), y = relL(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) }
function apca(txt, bg) {
  const Y = h => { const [r, g, b] = rgb(h).map(c => c ** 2.4); return 0.2126729 * r + 0.7151522 * g + 0.0721750 * b }
  const clamp = y => y > 0.022 ? y : y + (0.022 - y) ** 1.414
  const t = clamp(Y(txt)), b = clamp(Y(bg))
  if (Math.abs(b - t) < 0.0005) return 0
  if (b > t) { const s = (b ** 0.56 - t ** 0.57) * 1.14; return s < 0.1 ? 0 : (s - 0.027) * 100 }
  const s = (b ** 0.65 - t ** 0.62) * 1.14; return s > -0.1 ? 0 : (s + 0.027) * 100
}

// ---------------------------------------------------------------- calendar colours
const data = readFileSync(join(here, 'data.js'), 'utf8')
const cals = [...data.matchAll(/(\w+): \{ name: '([^']+)', hex: '(#[0-9A-Fa-f]{6})'/g)].map(m => [m[2], m[3]])
const swatches = [...data.matchAll(/\['(#[0-9A-Fa-f]{6})', '(\w+)'\]/g)].map(m => [m[2], m[1]])
const colours = [...new Map([...cals, ...swatches].map(([n, h]) => [h.toUpperCase(), n])).entries()].map(([h, n]) => [n, h])

// ---------------------------------------------------------------- targets: [min ratio, min |Lc|, max |Lc|]
// Canvas floors are the brief's §1 table. "soft" = one surface step off the canvas (cards, fields, hover, selected): the ratio floor
// stays, the Lc floor is 3–5 lower (the brief states its Lc floors for the canvas). Non-text (focus ring, selected segment, now line,
// needs-reply outline) needs 3:1 (WCAG 1.4.11). Hairlines are decoration: below Lc 15 on purpose; the hour line must still be visible (≥ 1.15:1).
// "structure" lines (the all-day edge, C8: 22 % / 24 %, and the hour line of timetable packs, brief §6 B "visible grid") may reach Lc 35.
const T = {
  dark: {
    fg1: [12, 88, 96], fg1soft: [12, 85], fg2: [7, 68], fg2soft: [7, 63], fg3: [6.5, 48], fg3soft: [5.5, 45],
    accent: [12, 85], live: [4.5, 45], status: [4.5, 45], nontext: [3, 0],
    evTitle: [7, 75], evMeta: [6.5, 60], evSelMeta: [5.5, 55], evPastTitle: [7, 65], evPastMeta: [5.7, 48], evDecl: [6, 55],
    decor: [1, 0, 15], decorMin: [1.15, 0, 15], structure: [1.15, 0, 35],
  },
  paper: {
    fg1: [12, 95], fg1soft: [12, 88], fg2: [7, 80], fg2soft: [7, 75], fg3: [5, 70], fg3soft: [5, 65],
    accent: [12, 90], live: [4.5, 60], status: [4.5, 60], nontext: [3, 0],
    evTitle: [7, 75], evMeta: [5.9, 70], evSelMeta: [5.5, 65], evPastTitle: [7, 75], evPastMeta: [5, 65], evDecl: [6.5, 75],
    decor: [1, 0, 15], decorMin: [1.15, 0, 15], structure: [1.15, 0, 35],
  },
}
const DECOR = new Set(['decor', 'decorMin', 'structure'])

const rows = []
function check(pack, theme, what, fg, bg, key) {
  const [minR, minLc, maxLc] = T[theme][key]
  const r = wcag(fg, bg), lc = apca(fg, bg), a = Math.abs(lc)
  const ok = r >= minR - 1e-9 && a >= minLc - 0.05 && (maxLc == null || a <= maxLc + 0.05)
  // margin: how far above its floor the pair sits (1 = exactly on the floor); decoration has none
  const margin = DECOR.has(key) ? Infinity : Math.min(r / minR, minLc ? a / minLc : Infinity)
  rows.push({ pack, theme, what, fg, bg, r, lc, key, ok, margin, target: `≥${minR}:1${minLc ? ` Lc≥${minLc}` : ''}${maxLc != null ? ` Lc≤${maxLc}` : ''}` })
}

// every pair of one look in one mode; C(what, fg, bg, key)
function pairsOf(N, C, { events = true, neutrals = true } = {}) {
  if (neutrals) {
    // the canvas floor on dark only applies the halation cap on near-black grounds (#00–#16)
    for (const [sn, s] of N.canvas) { C(`fg1 on ${sn}`, N.fg1, s, relL(s) < 0.01 || !N.dark ? 'fg1' : 'fg1soft'); C(`fg2 on ${sn}`, N.fg2, s, 'fg2'); C(`fg3 on ${sn}`, N.fg3, s, 'fg3') }
    for (const [sn, s] of N.soft) { C(`fg1 on ${sn}`, N.fg1, s, 'fg1soft'); C(`fg2 on ${sn}`, N.fg2, s, 'fg2soft'); C(`fg3 on ${sn}`, N.fg3, s, 'fg3soft') }
    C('primary button / today pill text', N.onAccent, N.accent, 'accent')
    C('now pill text on live red', N.onLive, N.live, 'live')
    if (N.liveText) for (const [sn, s] of (N.liveOn || N.canvas)) C(`live text ("now", "min left") on ${sn}`, N.liveText, s, 'live')
    C('now line vs bg', N.live, N.canvas[0][1], 'nontext')
    C('focus ring vs bg', N.focus, N.canvas[0][1], 'nontext')
    C('focus ring vs raised', N.focus, [...N.canvas, ...N.soft].find(x => x[0] === 'raised')[1], 'nontext')
    C('selected segment edge vs track', N.segRing, N.track, 'nontext')
    for (const [sn, hex] of N.status) C(`${sn} text on bg`, hex, N.canvas[0][1], 'status')
    for (const [ln, hex, key] of N.lines) C(`${ln} on bg`, hex, N.canvas[0][1], key)
    if (N.chip) C('all-day chip title (neutral chip)', N.chip.fg, N.chip.bg, 'fg1soft')
    // v9: the Join button is a raised neutral button in L1–L4; it keeps the primary-button target
    if (N.join) C('Join button text', N.join.fg, N.join.bg, 'accent')
  }
  if (events) for (const [cn, hex] of colours) evPairs(N.ev(hex), N, C, cn, '')
}
function evPairs(e, N, C, cn, pre) {
  C(`${pre}event title · ${cn}`, e.title, e.fill, 'evTitle')
  C(`${pre}event time · ${cn}`, e.meta, e.fill, 'evMeta')
  C(`${pre}event title on hover · ${cn}`, e.title, e.fillH, 'evTitle')
  // v10 Designer: the time also sits on the hover fill (hover, and the stripes of the "Hatch" tentative style)
  if (N.hoverMeta) C(`${pre}event time on hover / hatch · ${cn}`, e.meta, e.fillH, 'evMeta')
  C(`${pre}selected title · ${cn}`, e.titleSel, e.fillSel, 'evTitle')
  C(`${pre}selected time · ${cn}`, e.metaSel, e.fillSel, 'evSelMeta')
  C(`${pre}past title · ${cn}`, e.titlePast, e.fillPast, 'evPastTitle')
  C(`${pre}past time · ${cn}`, e.metaPast, e.fillPast, 'evPastMeta')
  C(`${pre}declined title · ${cn}`, e.titleDec, e.fillDec, 'evDecl')
  C(`${pre}needs-reply outline vs bg · ${cn}`, e.edge, N.canvas[0][1], 'nontext')
}
for (const pk of PACKS) for (const theme of ['dark', 'paper']) pairsOf(pk.check(theme), (what, fg, bg, key) => check(pk.id, theme, what, fg, bg, key))

// ---------------------------------------------------------------- print
const pad = (s, n) => String(s).padEnd(n)
const line = r => `${pad(r.pack, 3)} ${pad(r.theme, 6)} ${pad(r.what, 50)} ${pad(r.fg, 8)} ${pad(r.bg, 8)} ${pad(r.r.toFixed(2), 6)} ${pad(r.lc.toFixed(1), 7)} ${pad(r.target, 22)} ${r.ok ? 'pass' : 'FAIL'}`
if (all || onlyFails) {
  console.log(`${pad('pk', 3)} ${pad('theme', 6)} ${pad('pair', 50)} ${pad('fg', 8)} ${pad('bg', 8)} ${pad('ratio', 6)} ${pad('Lc', 7)} ${pad('target', 22)} ok`)
  for (const r of rows.filter(r => all || !r.ok)) console.log(line(r))
  console.log('-'.repeat(120))
}
const fails = rows.filter(r => !r.ok)
if (!rdOnly) console.log(`${rows.length} pairs over ${PACKS.length} look(s) × 2 themes (${colours.length} calendar colours × 9 event states per theme), ${fails.length} below target.`)
if (!rdOnly) console.log('\nPer look: pairs, misses, tightest pair per theme (smallest margin over its floor; ratio and Lc):')
for (const { id, name } of PACKS) {
  if (!rows.length) break
  const rl = rows.filter(r => r.pack === id)
  console.log(`  ${id} · ${name}: ${rl.length} pairs, ${rl.filter(r => !r.ok).length} fails`)
  for (const theme of ['dark', 'paper']) {
    const rs = rl.filter(r => r.theme === theme); if (!rs.length) continue
    const w = rs.filter(r => r.margin !== Infinity).sort((a, b) => a.margin - b.margin)[0]
    const minText = rs.filter(r => !DECOR.has(r.key) && r.key !== 'nontext').sort((a, b) => a.r - b.r)[0]
    console.log(`     ${pad(theme, 6)} ${pad(w.what, 44)} ${w.fg} on ${w.bg}  ${w.r.toFixed(2)}:1  Lc ${Math.abs(w.lc).toFixed(1)}  (floor ${w.target})` +
      `   · lowest text ratio ${minText.r.toFixed(2)}:1 (${minText.what})`)
  }
}

// ---------------------------------------------------------------- the Designer: every combination of its colour controls
// designer-proof.mjs runs one canvas per worker (8 at a time) and streams its pairs; see the groups there.
let dFails = 0
if (!arg.includes('--no-designer') && !rdOnly) {
  const { Worker } = await import('node:worker_threads')
  const { availableParallelism } = await import('node:os')
  const D = DESIGNER, n = k => D.CONTROLS[D.KI[k]].o.length, nc = n('canvas'), t0 = Date.now()
  const queue = [...Array(nc).keys()], results = []
  await Promise.all(Array.from({ length: Math.min(availableParallelism(), nc) }, async () => {
    while (queue.length) {
      const ci = queue.shift()
      results.push(await new Promise((res, rej) => { const w = new Worker(new URL('./designer-proof.mjs', import.meta.url), { workerData: { ci, T, colours: colours.map(c => c[1]) } }); w.on('message', res); w.on('error', rej) }))
    }
  }))
  const sum = { pairs: 0, fails: 0, fallback: 0, worst: null, failSamples: [], fallbackFills: new Set(), groups: {} }
  for (const r of results) {
    sum.pairs += r.pairs; sum.fails += r.fails; sum.fallback += r.fallback; sum.failSamples.push(...r.failSamples); r.fallbackFills.forEach(f => sum.fallbackFills.add(f))
    if (r.worst && (!sum.worst || r.worst.m < sum.worst.m)) sum.worst = r.worst
    for (const [g, x] of Object.entries(r.groups)) { const y = sum.groups[g] = sum.groups[g] || { combos: 0, pairs: 0 }; y.combos += x.combos; y.pairs += x.pairs }
  }
  const combos = Object.values(sum.groups).reduce((a, g) => a + g.combos, 0)
  const full = D.colour.reduce((a, k) => a * n(k), 1)
  console.log(`\nDesigner (${D.CONTROLS.length} controls, ${D.CONTROLS.filter(c => c.c).length} change colours: ${D.colour.join(', ')})`)
  console.log(`  full product of the colour controls: ${full.toExponential(2)} designs × 2 modes, covered by crossing the groups that share pairs (${results[0].hues} hues = ${colours.length} calendar colours × ${n('palette')} palettes, deduplicated):`)
  for (const [g, x] of Object.entries(sum.groups)) console.log(`    ${pad(g, 7)} ${pad(x.combos.toLocaleString('en') + ' combinations', 22)} ${x.pairs.toLocaleString('en')} pairs`)
  console.log(`  ${combos.toLocaleString('en')} combinations checked (both modes, ${nc} canvases), ${sum.pairs.toLocaleString('en')} pairs, ${sum.fails} below target  (${((Date.now() - t0) / 1000).toFixed(0)} s).`)
  const w = sum.worst
  console.log(`  tightest pair: ${w.what} · ${w.fg} on ${w.bg} ${w.r.toFixed(2)}:1 Lc ${w.a.toFixed(1)} (floor ${w.target}) · ${w.theme}, ${w.tag}`)
  console.log(`  disabled (title falls back to Auto): ${sum.fallback.toLocaleString('en')} of ${sum.groups.events.combos.toLocaleString('en')} event combinations — a White title in Paper on ${[...sum.fallbackFills].join(', ')}; the rail strikes the option through ("not readable with this fill")`)
  if (sum.failSamples.length) console.log('  fails:\n    ' + sum.failSamples.slice(0, 24).join('\n    '))
  dFails = sum.fails
}

// ---------------------------------------------------------------- v11: the Readability designer (look R, Dark)
// Its colour levers split into two groups whose pairs never overlap (READ.pairs): chrome = canvas × panes × steps × hour labels × hour line ×
// minor lines × today × now; events = canvas × steps × recipe × strength × event text × past × all-day. Both groups are crossed fully, for every
// calendar colour, and every pair is checked here with T.dark (the floors above, unchanged). A design is reachable only if both of its
// projections pass (the rail disables any option that leads elsewhere, and a link to such a design falls back to R1); the type levers and
// Maybe / declined change no colour pair. The guard in readability.js must agree with this check on every combination.
let rdFails = 0
if (!arg.includes('--no-rd')) {
  const R = READ, t0 = Date.now(), hues = colours.map(c => c[1].toUpperCase())
  R.setHues(hues)
  const n = k => R.LEVERS[R.KI[k]].o.length
  const cross = keys => keys.reduce((acc, k) => acc.flatMap(o => [...Array(n(k)).keys()].map(i => ({ ...o, [k]: i }))), [{}])
  const base = R.decode('')
  const res = {}, perCS = {}, blocked = {}, mismatch = []
  let pairs = 0, fails = 0, worst = null, pPairs = 0, pFails = 0, pWorst = null
  for (const g of ['chrome', 'events']) {
    const keys = g === 'chrome' ? R.CHROME_K : R.EVENT_K, combos = cross(keys)
    let pass = 0
    for (const c of combos) {
      const s = { ...base, ...c }
      let bad = null
      for (const [what, fg, bg, key, th] of [...R.pairs(s, hues, g, 'dark'), ...R.pairs(s, hues, g, 'paper')]) {
        pairs++; if (th === 'paper') pPairs++
        const [minR, minLc, maxLc] = T[th][key], r = wcag(fg, bg), a = Math.abs(apca(fg, bg))
        const ok = r >= minR - 1e-9 && a >= minLc - 0.05 && (maxLc == null || a <= maxLc + 0.05)
        if (!ok) { if (!bad) bad = { what: (th === 'paper' ? 'Paper · ' : '') + what, fg, bg, r, a, key: th === 'paper' ? 'p' + key : key }; if (th === 'paper') pFails++ }
        else if (!DECOR.has(key) && key !== 'nontext') { const m = Math.min(r / minR, minLc ? a / minLc : Infinity); if (th === 'dark' && (!worst || m < worst.m)) worst = { m, what, fg, bg, r, a, key, s }; if (th === 'paper' && (!pWorst || m < pWorst.m)) pWorst = { m, what, fg, bg, r, a, key, s } }
      }
      const guard = R.verdict(s, g, hues).ok
      if (guard !== !bad) mismatch.push(`${g} ${R.encode(s)}`)
      const cs = `${s.canvas}.${s.steps}`; perCS[cs] = perCS[cs] || { chrome: 0, events: 0 }
      if (!bad) { pass++; perCS[cs][g]++ } else {
        fails++
        // which option made it unreachable: name the first failing pair kind per (lever option) for the summary
        const TT = bad.key[0] === 'p' && !T.dark[bad.key] ? T.paper[bad.key.slice(1)] : T.dark[bad.key], kind = bad.what.replace(/ · #\w+$/, '') + (bad.key === 'fg1' && bad.a > 96 ? ' > Lc 96 (halation cap)' : bad.r < TT[0] ? ` < ${TT[0]}:1` : ` < Lc ${TT[1]}`)
        blocked[kind] = (blocked[kind] || 0) + 1
      }
    }
    res[g] = { combos: combos.length, pass }
  }
  const other = ['size', 'weight', 'font', 'chrome', 'tent'].reduce((a, k) => a * n(k), 1)
  const full = R.LEVERS.reduce((a, l) => a * l.o.length, 1)
  const reach = Object.values(perCS).reduce((a, x) => a + x.chrome * x.events, 0) * other
  const presetsOk = R.PRESETS.every(p => R.passes(p.code))
  console.log(`\nReadability designer (look R, Dark): ${R.LEVERS.length} levers, ${R.LEVERS.reduce((a, l) => a + l.o.length, 0)} options, ${R.COLOUR.length} change colours (${R.COLOUR.join(', ')})`)
  console.log(`  full product: ${full.toLocaleString('en')} designs; ${hues.length} calendar colours × 9 event states (+ all-day chips)`)
  for (const [g, x] of Object.entries(res)) console.log(`    ${pad(g, 7)} ${x.combos.toLocaleString('en')} combinations, ${x.pass.toLocaleString('en')} pass, ${(x.combos - x.pass).toLocaleString('en')} blocked (unreachable)`)
  console.log(`  ${pairs.toLocaleString('en')} pairs checked (${((Date.now() - t0) / 1000).toFixed(0)} s); ${fails} combinations miss a floor, all of them blocked by the guard (mismatches: ${mismatch.length})`)
  console.log(`  reachable designs: ${reach.toLocaleString('en')} of ${full.toLocaleString('en')}, every one at 0 pairs below target · presets R1–R11 ${presetsOk ? 'all pass' : 'FAIL'}`)
  console.log(`  Paper (round h, derived): ${pPairs.toLocaleString('en')} of the pairs are Paper (T.paper floors), ${pFails} Paper misses (all blocked); tightest Paper pair: ${pWorst.what} · ${pWorst.fg} on ${pWorst.bg} ${pWorst.r.toFixed(2)}:1 Lc ${pWorst.a.toFixed(1)} (floor ${T.paper[pWorst.key].slice(0, 2).join(':1 / Lc ')})`)
  console.log(`  tightest text pair: ${worst.what} · ${worst.fg} on ${worst.bg} ${worst.r.toFixed(2)}:1 Lc ${worst.a.toFixed(1)} (floor ${T.dark[worst.key].slice(0, 2).join(':1 / Lc ')}) · design ${R.encode(worst.s)}`)
  console.log('  why options get disabled (combinations per first failing pair):')
  for (const [k, v] of Object.entries(blocked).sort((a, b) => b[1] - a[1]).slice(0, 12)) console.log(`    ${pad(v.toLocaleString('en'), 8)} ${k}`)
  rdFails = mismatch.length + (presetsOk ? 0 : 1)

  // round e: the sliders. Sampled on a grid around every preset (each colour slider alone at 7 steps; related sliders crossed at 5 steps:
  // fill L × C × strength, bar L × C × hue, title L × time L × time C, canvas L × C × hue × sidebar offset, hour × half line, one hue × fill L,
  // hue shift × fill L × C). A sample the guard accepts must have 0 pairs below target here; a sample it rejects is a clamped slider position.
  const t1 = Date.now(), SL = R.SLIDERS, at = (id, k, n) => { const x = SL[R.SI[id]]; return R.snap(id, x[3] + (x[4] - x[3]) * k / (n - 1)) }
  const grid = (ids, n) => ids.reduce((acc, id) => acc.flatMap(K => [...Array(n).keys()].map(i => ({ ...K, [id]: at(id, i, n) }))), [{}])
  const plans = [...R.CSL.filter(id => id !== 'oh').map(id => grid([id], 7)), grid(['el', 'ec', 'es'], 5), grid(['bl', 'bc', 'bh'], 5), grid(['tl', 'ml', 'mc'], 5),
    grid(['cl', 'cc', 'ch', 'so'], 5), grid(['hl', 'hm'], 7), grid(['ty', 'yc', 'yh'], 5), grid(['ty', 'hl'], 7), grid(['pf', 'ps'], 4), grid(['pf', 'es'], 4), grid(['ou', 'el'], 5).map(K => ({ ...K, oh: 1 })), grid(['eh', 'el', 'ec'], 5)].flat()
  let sN = 0, sOk = 0, sPairs = 0, sFails = 0, sMis = 0, sWorst = null; const sBlock = {}
  for (const p of R.PRESETS) for (const K0 of plans) {
    const K = { ...R.decodeK(p.k), ...K0 }, s = { ...R.decode(p.code), K }
    sN++
    let bad = null
    for (const [what, fg, bg, key, th] of ['dark', 'paper'].flatMap(m => [...R.pairs(s, hues, 'chrome', m), ...R.pairs(s, hues, 'events', m)])) {
      const [minR, minLc, maxLc] = T[th][key], r = wcag(fg, bg), a = Math.abs(apca(fg, bg))
      const ok = r >= minR - 1e-9 && a >= minLc - 0.05 && (maxLc == null || a <= maxLc + 0.05)
      if (!ok && !bad) bad = { what: (th === 'paper' ? 'Paper · ' : '') + what.replace(/ · #\w+$/, ''), key, r, a }
      if (ok && !DECOR.has(key) && key !== 'nontext') { const m = Math.min(r / minR, minLc ? a / minLc : Infinity); if (!sWorst || m < sWorst.m) sWorst = { m, what, fg, bg, r, a, key, id: p.id, K: R.encodeK(K) } }
    }
    const guard = R.passes(s)
    if (guard !== !bad) sMis++
    if (guard) { sOk++; sPairs += ['dark', 'paper'].reduce((a, m) => a + R.pairs(s, hues, 'chrome', m).length + R.pairs(s, hues, 'events', m).length, 0); if (bad) sFails++ }
    else { const k = `${Object.keys(K0).join('+')}: ${bad ? bad.what : '?'}`; sBlock[k] = (sBlock[k] || 0) + 1 }
  }
  console.log(`\nReadability sliders (sampled): ${sN.toLocaleString('en')} slider settings over ${R.PRESETS.length} presets (${plans.length} per preset), ${((Date.now() - t1) / 1000).toFixed(0)} s`)
  console.log(`  accepted by the guard: ${sOk.toLocaleString('en')} · ${sPairs.toLocaleString('en')} pairs · ${sFails} below target · guard vs check mismatches: ${sMis}`)
  console.log(`  clamped (slider range cut there): ${(sN - sOk).toLocaleString('en')} settings; most common first failing pair:`)
  for (const [k, v] of Object.entries(sBlock).sort((a, b) => b[1] - a[1]).slice(0, 10)) console.log(`    ${pad(v.toLocaleString('en'), 7)} ${k}`)
  console.log(`  tightest accepted text pair: ${sWorst.what} · ${sWorst.fg} on ${sWorst.bg} ${sWorst.r.toFixed(2)}:1 Lc ${sWorst.a.toFixed(1)} (${sWorst.id} + ${sWorst.K})`)
  rdFails += sFails + sMis
  if (mismatch.length) console.log('  MISMATCH guard vs check:\n    ' + mismatch.slice(0, 10).join('\n    '))
}
process.exit(fails.length || dFails || rdFails ? 1 : 0)
