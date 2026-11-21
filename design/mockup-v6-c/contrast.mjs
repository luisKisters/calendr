#!/usr/bin/env node
// Contrast check for Horion v6 · C "Warm editorial".
//   node design/mockup-v6-c/contrast.mjs          table of every token pair, exit 1 if a pair misses its target
//   node design/mockup-v6-c/contrast.mjs --fails  only the misses
// WCAG 2.x relative-luminance ratio and APCA-W3 0.0.98G-4g (Lc; negative = light text on dark, size matters only).
// Tokens and the event recipe come from tokens.js; calendar colours from data.js (CALS0 + SWATCHES).
import { createRequire } from 'node:module'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const { THEMES, ev, mix } = createRequire(import.meta.url)(join(here, 'tokens.js'))
const onlyFails = process.argv.includes('--fails')

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

// ---------------------------------------------------------------- targets (brief §1 table, direction C)
// [min ratio, min |Lc|, max |Lc|]   max is the halation cap on dark
const T = {
  dark: {
    fg1: [12, 88, 96], fg2: [7, 68], fg3: [6.5, 48], fg3raised: [5.5, 45],
    evTitle: [7, 75], evMeta: [6.5, 60], evPastTitle: [7, 65], evPastMeta: [5.7, 48], evDecl: [6, 55],
    live: [4.5, 45], focus: [3, 0], accent: [12, 88], decor: [1, 0, 15], decorMin: [1.2, 0, 15], structure: [1.6, 0, 30], outline: [3, 0],
    fg1soft: [12, 88, 96], fg2soft: [7, 66], fg3soft: [5.5, 45],
  },
  paper: {
    fg1: [12, 95], fg2: [7, 80], fg3: [5, 70], fg3raised: [5, 70], fg3rail: [5, 68],
    evTitle: [8, 80], evMeta: [5.9, 72], evPastTitle: [7, 80], evPastMeta: [5, 68], evDecl: [6.5, 78],
    live: [4.5, 60], focus: [3, 0], accent: [12, 90], decor: [1, 0, 15], decorMin: [1.2, 6, 15], structure: [1.4, 15, 30], outline: [3, 0],
    fg1soft: [12, 88], fg2soft: [7, 75], fg3soft: [5, 65],
  },
}

const rows = []
function check(theme, what, fg, bg, key) {
  const [minR, minLc, maxLc] = T[theme][key]
  const r = wcag(fg, bg), lc = apca(fg, bg), a = Math.abs(lc)
  const ok = r >= minR - 1e-9 && a >= minLc - 0.05 && (maxLc == null || a <= maxLc + 0.05)
  rows.push({ theme, what, fg, bg, r, lc, target: `≥${minR}:1${minLc ? ` Lc≥${minLc}` : ''}${maxLc != null ? ` Lc≤${maxLc}` : ''}`, ok, key })
}

for (const [name, t] of Object.entries(THEMES)) {
  const surfaces = [['bg', t.bg], ['rail', t.rail], ['surface', t.surface], ['raised', t.raised], ['hover', t.hover], ['selected', t.selected]]
  for (const [sn, s] of surfaces) {
    // the brief's floors are stated for the canvas; on the other surfaces (one step off the canvas) the Lc floor is lower, the ratio floor stays
    const soft = !(sn === 'bg' || (name === 'paper' && sn === 'raised') || (name === 'dark' && sn === 'rail'))
    check(name, `fg1 on ${sn}`, t.fg1, s, soft ? 'fg1soft' : 'fg1')
    check(name, `fg2 on ${sn}`, t.fg2, s, soft ? 'fg2soft' : 'fg2')
    check(name, `fg3 on ${sn}`, t.fg3, s, soft ? 'fg3soft' : 'fg3')
  }
  check(name, 'onAccent on accent (primary button, today pill)', t.onAccent, t.accent, 'accent')
  check(name, 'live on bg (now line, "now" label)', t.live, t.bg, 'live')
  check(name, 'live on rail ("12 min left")', t.live, t.rail, 'live')
  check(name, 'focus ring vs bg', t.focus, t.bg, 'focus')
  check(name, 'focus ring vs raised', t.focus, t.raised, 'focus')
  check(name, 'selected segment edge vs track', t.segRing, t.surface, 'focus')
  check(name, 'hour line on bg (decor, visible)', t.grid, t.bg, 'decorMin')
  check(name, 'day separator on bg (decor)', t.gridV, t.bg, 'decor')
  check(name, 'pane hairline on bg (decor)', t.hair, t.bg, 'decor')
  check(name, 'all-day edge on bg (structure, C8)', t.hairStrong, t.bg, 'structure')
  for (const [cn, hex] of colours) {
    const e = ev(hex, t)
    check(name, `event title · ${cn}`, e.tc, e.fill, 'evTitle')
    check(name, `event time · ${cn}`, e.mc, e.fill, 'evMeta')
    check(name, `event title hover · ${cn}`, e.tc, e.fillh, 'evTitle')
    check(name, `event title selected · ${cn}`, e.tcs, e.fills, 'evTitle')
    check(name, `event time selected · ${cn}`, e.mcs, e.fills, 'evMeta')
    check(name, `past title · ${cn}`, e.tcp, e.fillp, 'evPastTitle')
    check(name, `past time · ${cn}`, e.mcp, e.fillp, 'evPastMeta')
    check(name, `declined text · ${cn}`, e.dectc, e.decfill, 'evDecl')
    check(name, `needs-reply outline vs bg · ${cn}`, e.line, t.bg, 'outline')
  }
}

// ---------------------------------------------------------------- print
const pad = (s, n) => String(s).padEnd(n)
const show = onlyFails ? rows.filter(r => !r.ok) : rows
let last = ''
console.log(pad('theme', 6), pad('pair', 46), pad('fg', 8), pad('bg', 8), pad('ratio', 7), pad('Lc', 7), pad('target', 24), 'ok')
for (const r of show) {
  if (r.theme !== last) { console.log('-'.repeat(112)); last = r.theme }
  console.log(pad(r.theme, 6), pad(r.what, 46), pad(r.fg, 8), pad(r.bg, 8), pad(r.r.toFixed(2), 7), pad(r.lc.toFixed(1), 7), pad(r.target, 24), r.ok ? 'pass' : 'FAIL')
}
const fails = rows.filter(r => !r.ok)
// worst text pair = lowest margin over its ratio target (decoration excluded)
const text = rows.filter(r => !['decor', 'decorMin', 'structure', 'focus', 'outline'].includes(r.key))
const worst = text.map(r => ({ r, m: r.r / +r.target.match(/≥([\d.]+)/)[1] })).sort((a, b) => a.m - b.m)[0].r
const worstLc = text.filter(r => r.theme === 'dark').sort((a, b) => Math.abs(a.lc) - Math.abs(b.lc))[0]
console.log('-'.repeat(112))
console.log(`${rows.length} pairs, ${fails.length} below target. Calendar colours: ${colours.length}.`)
console.log(`Lowest text ratio vs its target: ${worst.theme} · ${worst.what} = ${worst.r.toFixed(2)}:1, Lc ${worst.lc.toFixed(1)} (target ${worst.target})`)
console.log(`Lowest |Lc| for text on dark: ${worstLc.what} = Lc ${worstLc.lc.toFixed(1)}, ${worstLc.r.toFixed(2)}:1`)
for (const th of Object.keys(THEMES)) {
  const all = text.filter(r => r.theme === th)
  console.log(`${th}: min text ratio ${Math.min(...all.map(r => r.r)).toFixed(2)}:1 (${all.sort((a, b) => a.r - b.r)[0].what})`)
}
process.exit(fails.length ? 1 : 0)
