#!/usr/bin/env node
// Contrast check for Calendr v6 · A "Calm graphite".
//   node design/mockup-v6-a/contrast.mjs          prints every token pair (WCAG 2 ratio + APCA Lc) and exits 1 on a miss
// Reads the same tokens.js and data.js the page uses, so the table is what the mockup renders.
// APCA: 0.0.98G-4g constants (same as the brief's c.py). Lc is negative for light text on dark; the table shows |Lc|.
import { readFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import vm from 'node:vm'

const dir = dirname(fileURLToPath(import.meta.url))
const ctx = vm.createContext({})
for (const f of ['tokens.js', 'data.js']) vm.runInContext(await readFile(join(dir, f), 'utf8'), ctx, { filename: f })
const { TOKENS, evColors, mix, CALS0, SWATCHES } = vm.runInContext('({ TOKENS, evColors, mix, CALS0, SWATCHES })', ctx)

const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
const lin = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4 }
const rl = h => { const [r, g, b] = rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b }
const wcag = (f, b) => { const a = rl(f), c = rl(b); return (Math.max(a, c) + 0.05) / (Math.min(a, c) + 0.05) }
const ys = h => { const [r, g, b] = rgb(h).map(c => (c / 255) ** 2.4); const y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b; return y < 0.022 ? y + (0.022 - y) ** 1.414 : y }
function apca(t, bg) {
  const yt = ys(t), yb = ys(bg)
  if (Math.abs(yb - yt) < 0.0005) return 0
  if (yb > yt) { const s = (yb ** 0.56 - yt ** 0.57) * 1.14; return s < 0.1 ? 0 : (s - 0.027) * 100 }
  const s = (yb ** 0.65 - yt ** 0.62) * 1.14; return s > -0.1 ? 0 : (s + 0.027) * 100
}
const over = (bg, fg, pct) => mix(bg, fg, pct / 100) // a translucent fg tint composited on bg

// targets from the brief (§1 table and §5 event recipe)
const TGT = {
  dark: {
    primary: { r: 12, lc: 88, lcMax: 97 }, secondary: { r: 7, lc: 68 }, tertiary: { r: 6.5, lc: 48 },
    evTitle: { r: 7, lc: 75 }, evMeta: { r: 6.5, lc: 60 }, evPastT: { r: 7, lc: 60 }, evPastM: { r: 4.5, lc: 45 },
    ui: { r: 3 }, onAccent: { r: 12, lc: 88 }, btn: { r: 4.5, lc: 60 },
  },
  paper: {
    primary: { r: 12, lc: 95 }, secondary: { r: 7, lc: 80 }, tertiary: { r: 5, lc: 70 },
    evTitle: { r: 7, lc: 75 }, evMeta: { r: 5.5, lc: 70 }, evPastT: { r: 7, lc: 75 }, evPastM: { r: 4.5, lc: 60 },
    ui: { r: 3 }, onAccent: { r: 12, lc: 95 }, btn: { r: 4.5, lc: 60 },
    // hover / selected rows are tinted (#E9–#EC), outside the brief's "off-white #F7–#FA" column: AA+ floors, lower Lc
    primaryT: { r: 12, lc: 85 }, secondaryT: { r: 7, lc: 72 }, tertiaryT: { r: 5, lc: 62 },
  },
}

const rows = []
function check(theme, group, name, fg, bg, t) {
  const r = wcag(fg, bg), lc = Math.abs(apca(fg, bg))
  const miss = []
  if (t.r && r < t.r) miss.push(`ratio < ${t.r}`)
  if (t.lc && lc < t.lc) miss.push(`Lc < ${t.lc}`)
  if (t.lcMax && lc > t.lcMax) miss.push(`Lc > ${t.lcMax} (halation)`)
  rows.push({ theme, group, name, fg, bg, r, lc, t, miss })
}

for (const theme of ['dark', 'paper']) {
  const T = TOKENS[theme], G = TGT[theme]
  const grounds = { bg: T.bg, side: T.side, surface: T.surface, raised: T.raised, hover: over(T.side, T.fg1, T.hoverA), selected: over(T.side, T.fg1, T.selA) }
  // text greys on every surface they sit on
  for (const [gname, g] of Object.entries(grounds)) {
    const tint = !T.dark && (gname === 'hover' || gname === 'selected') ? 'T' : ''
    check(theme, 'text', `fg1 on ${gname} ${g}`.trim(), T.fg1, g, G['primary' + tint])
    check(theme, 'text', `fg2 on ${gname}`, T.fg2, g, G['secondary' + tint])
    check(theme, 'text', `fg3 on ${gname}`, T.fg3, g, G['tertiary' + tint])
  }
  check(theme, 'text', 'fg4 (disabled, exempt) on bg', T.fg4, T.bg, {})
  check(theme, 'ui', 'onAccent on accent (primary button, today pill)', T.onAccent, T.accent, G.onAccent)
  check(theme, 'ui', 'onDanger on danger (delete button)', T.onDanger, T.danger, G.btn)
  check(theme, 'ui', 'focus ring vs bg', T.focus, T.bg, G.ui)
  check(theme, 'ui', 'focus ring vs raised', T.focus, T.raised, G.ui)
  check(theme, 'ui', 'now line (live) vs bg', T.live, T.bg, G.ui)
  check(theme, 'ui', 'selected segment ring vs track (surface)', T.segRing, T.surface, G.ui)
  check(theme, 'ui', 'selected segment ring vs bg', T.segRing, T.bg, G.ui)
  check(theme, 'ui', 'checkbox outline (fg3) vs raised', T.fg3, T.raised, G.ui)
  check(theme, 'deco', 'hour line vs bg (decorative, keep Lc < 15)', T.line, T.bg, {})
  check(theme, 'deco', 'all-day edge vs bg', T.hairStrong, T.bg, {})
  // events: every calendar colour and every swatch, every state
  const colours = new Map()
  Object.values(CALS0).forEach(c => colours.set(c.hex, c.name + (c.task ? ' (task)' : '')))
  SWATCHES.forEach(([h, n]) => { if (!colours.has(h)) colours.set(h, n) })
  for (const [hex, name] of colours) {
    const task = /\(task\)/.test(name), c = evColors(hex, theme, task), n = `${name} ${hex}`
    check(theme, 'event', `${n}: title on fill`, c.title, c.fill, G.evTitle)
    check(theme, 'event', `${n}: time/meta on fill`, c.meta, c.fill, G.evMeta)
    check(theme, 'event', `${n}: title on hover fill`, c.title, c.fillH, G.evTitle)
    check(theme, 'event', `${n}: title on selected fill`, c.title, c.fillSel, G.evTitle)
    check(theme, 'event', `${n}: meta on selected fill`, c.metaSel, c.fillSel, G.evMeta)
    check(theme, 'event', `${n}: past title`, c.titlePast, c.fillPast, G.evPastT)
    check(theme, 'event', `${n}: past meta`, c.metaPast, c.fillPast, G.evPastM)
    check(theme, 'event', `${n}: declined title`, c.titleDec, c.fillDec, G.evPastT)
    if (!task) check(theme, 'ui', `${n}: needs-reply outline vs bg`, c.edge, T.bg, G.ui)
    if (!task) check(theme, 'event', `${n}: needs-reply title (fg1) on bg`, T.fg1, T.bg, G.evTitle)
  }
}

const pad = (s, n) => String(s).padEnd(n)
let misses = 0, worst = {}
for (const theme of ['dark', 'paper']) {
  console.log(`\n== ${theme === 'dark' ? 'Dark graphite (bg ' + TOKENS.dark.bg + ')' : 'Paper (bg ' + TOKENS.paper.bg + ')'}`)
  console.log(pad('pair', 62) + pad('fg', 9) + pad('bg', 9) + pad('ratio', 8) + pad('|Lc|', 7) + 'target')
  for (const x of rows.filter(r => r.theme === theme)) {
    const tgt = [x.t.r ? `≥${x.t.r}:1` : '', x.t.lc ? `Lc≥${x.t.lc}` : '', x.t.lcMax ? `≤${x.t.lcMax}` : ''].filter(Boolean).join(' ') || '—'
    console.log(pad(x.name, 62) + pad(x.fg, 9) + pad(x.bg, 9) + pad(x.r.toFixed(2), 8) + pad(x.lc.toFixed(1), 7) + pad(tgt, 18) + (x.miss.length ? 'MISS ' + x.miss.join(', ') : 'ok'))
    if (x.miss.length) misses++
    // worst text pair by WCAG ratio (only pairs with a target)
    if (x.t.r && x.group !== 'ui' && (!worst[theme] || x.r < worst[theme].r)) worst[theme] = x
  }
}
console.log('\nWorst text pair per theme:')
for (const [th, x] of Object.entries(worst)) console.log(`  ${th}: ${x.name}  ${x.fg} on ${x.bg}  ${x.r.toFixed(2)}:1  Lc ${x.lc.toFixed(1)}`)
console.log(misses ? `\n${misses} pair(s) miss their target` : '\nall pairs meet their targets')
process.exit(misses ? 1 : 0)
