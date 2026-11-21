#!/usr/bin/env node
// Contrast check for Horion v6 · B. Reads tokens.js (the same file the app uses) and prints WCAG 2.x ratio and APCA Lc
// (APCA-W3 0.0.98G-4g; |Lc| shown) for every token pair, plus the worst case per event role over every calendar colour.
//   node design/mockup-v6-b/contrast.mjs          summary table
//   node design/mockup-v6-b/contrast.mjs --all    also every calendar colour
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import vm from 'node:vm'

const here = dirname(fileURLToPath(import.meta.url))
const ctx = { module: { exports: {} } }
vm.runInNewContext(readFileSync(join(here, 'tokens.js'), 'utf8'), ctx)
const { TOKENS, eventColors, tMix } = ctx.module.exports
// calendar colours and swatches straight from data.js
const data = readFileSync(join(here, 'data.js'), 'utf8')
const CAL = [...new Set([...data.matchAll(/hex: '(#[0-9A-Fa-f]{6})'/g), ...data.matchAll(/\['(#[0-9A-Fa-f]{6})', '[A-Z]/g)].map(m => m[1].toUpperCase()))]

const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16))
const lin = c => { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4 }
const relL = h => { const [r, g, b] = rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b }
const wcag = (a, b) => { const x = relL(a), y = relL(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) }
function apca(txt, bg) {
  const Y = h => { const [r, g, b] = rgb(h).map(c => (c / 255) ** 2.4); let y = 0.2126729 * r + 0.7151522 * g + 0.072175 * b; return y > 0.022 ? y : y + (0.022 - y) ** 1.414 }
  const yt = Y(txt), yb = Y(bg)
  if (Math.abs(yb - yt) < 0.0005) return 0
  let out
  if (yb > yt) { const s = (yb ** 0.56 - yt ** 0.57) * 1.14; out = s < 0.1 ? 0 : s - 0.027 }
  else { const s = (yb ** 0.65 - yt ** 0.62) * 1.14; out = s > -0.1 ? 0 : s + 0.027 }
  return Math.abs(out * 100)
}
const over = (base, fg, pct) => tMix(base, fg, pct / 100) // a translucent fg tint over a surface

const rows = []
const add = (theme, role, fg, bg, minW, minLc, note = '') => {
  const w = wcag(fg, bg), lc = apca(fg, bg)
  rows.push({ theme, role, fg, bg, w, lc, minW, minLc, ok: w >= minW - 1e-9 && lc >= minLc - 1e-9, note })
}

for (const theme of ['dark', 'paper']) {
  const T = TOKENS[theme], d = theme === 'dark'
  const tgt = d ? { p: [12, 88], s: [7, 68], t: [6.5, 48] } : { p: [12, 95], s: [7, 80], t: [5, 70] }
  const surf = { bg: T.bg, surface: T.surface, raised: T.raised }
  for (const [n, b] of Object.entries(surf)) {
    add(theme, `fg1 on ${n}`, T.fg1, b, ...tgt.p)
    add(theme, `fg2 on ${n}`, T.fg2, b, ...tgt.s)
    add(theme, `fg3 on ${n}`, T.fg3, b, ...tgt.t, 'labels, hints, placeholders, icons')
    // hover is transient: primary keeps 12:1, tertiary keeps AA+ (5.5:1) and the Lc floor
    add(theme, `fg1 on hover(${n})`, T.fg1, over(b, T.fg1, T.hover), 12, d ? 88 : 90)
    add(theme, `fg3 on hover(${n})`, T.fg3, over(b, T.fg1, T.hover), 5.5, tgt.t[1])
  }
  add(theme, 'fg1 on raised2', T.fg1, T.raised2, d ? 12 : 12, d ? 85 : 90, 'dialog boxes, secondary buttons')
  add(theme, 'fg2 on raised2', T.fg2, T.raised2, 7, d ? 62 : 78)
  add(theme, 'fg3 on raised2', T.fg3, T.raised2, d ? 5.5 : 5, d ? 45 : 65)
  add(theme, 'fg1 on thumb (selected segment)', T.fg1, T.thumb, 7, d ? 80 : 95)
  add(theme, 'fg2 on track (segments)', T.fg2, T.track, 7, d ? 66 : 78)
  add(theme, 'selected-segment ring vs track', T.segRing, T.track, 3, 0, 'non-text 1.4.11')
  add(theme, 'fg1 on selected row', T.fg1, over(T.surface, T.fg1, T.selected), 10, d ? 80 : 88)
  add(theme, 'hour label on bg', T.hourLabel, T.bg, ...tgt.s)
  add(theme, 'onAccent on accent (primary)', T.onAccent, T.accent, 12, d ? 88 : 95)
  add(theme, 'liveText on bg (now time)', T.liveText, T.bg, 4.5, d ? 50 : 60)
  add(theme, 'liveText on surface (countdown)', T.liveText, T.surface, 4.5, d ? 50 : 60)
  add(theme, 'liveText on raised (Now card)', T.liveText, T.raised, 4.5, d ? 50 : 60)
  add(theme, 'ok text on raised', T.ok, T.raised, 4.5, d ? 50 : 60)
  add(theme, 'danger text on raised', T.danger, T.raised, 4.5, d ? 50 : 60)
  add(theme, 'warn icon on raised', T.warn, T.raised, 3, 30, 'non-text')
  add(theme, 'white on dangerFill (button)', '#FFFFFF', T.dangerFill, 4.5, 60)
  add(theme, 'focus ring vs bg', T.focus, T.bg, 3, 30, 'non-text 1.4.11')
  add(theme, 'focus ring vs raised', T.focus, T.raised, 3, 30, 'non-text')
  add(theme, 'now line vs bg', T.live, T.bg, 3, 30, 'non-text')
  add(theme, 'field outline vs bg', T.hairStrong, T.bg, 1.3, 0, 'fields also have a fill (paper only)')
  add(theme, 'hour line vs bg', T.lineHour, T.bg, 1.1, 0, 'decoration, Lc < 15 intended')
  add(theme, 'lane edge vs bg', T.lineEdge, T.bg, 1.3, 0, 'decoration')
  add(theme, 'fg4 disabled on bg', T.fg4, T.bg, 0, 0, 'exempt')

  // events: worst case over every calendar colour and swatch
  const ev = [
    ['event title on fill', c => [c.title, c.fill], 7, d ? 75 : 85],
    ['event meta on fill', c => [c.meta, c.fill], d ? 7 : 6.2, d ? 68 : 75],
    ['event title on hover fill', c => [c.title, c.fillHover], 7, d ? 75 : 85],
    ['event meta on hover fill', c => [c.meta, c.fillHover], 6.5, d ? 66 : 75],
    ['event title on selected fill', c => [c.title, c.fillSel], 7, d ? 70 : 75],
    ['event meta on selected fill', c => [c.meta, c.fillSel], 5.5, d ? 60 : 65],
    ['past title (fg2) on past fill', c => [c.titlePast, c.fillPast], 9, d ? 68 : 80],
    ['past meta (fg3) on past fill', c => [c.metaPast, c.fillPast], 5.7, d ? 48 : 68],
    ['declined title (fg2) on fill', c => [c.titleDec, c.fillDec], 7, d ? 65 : 78],
    ['needs-reply outline vs bg', c => [c.outline, T.bg], 3, 30],
    ['selected ring (fg1) vs selected fill', c => [T.fg1, c.fillSel], 3, 30],
    ['all-day chip dot vs chip', c => [c.cc, T.raised], 1.5, 0],
  ]
  for (const [role, f, minW, minLc] of ev) {
    let worst = null
    for (const cc of CAL) {
      const [fg, bg] = f(eventColors(cc, theme)), w = wcag(fg, bg), lc = apca(fg, bg)
      if (process.argv.includes('--all')) rows.push({ theme, role: `  ${role} ${cc}`, fg, bg, w, lc, minW, minLc, ok: w >= minW && lc >= minLc, note: '' })
      if (!worst || w < worst.w) worst = { fg, bg, w, lc, cc, minLcSeen: lc }
      worst.minLcSeen = Math.min(worst.minLcSeen, lc)
    }
    rows.push({ theme, role: `${role} (worst: ${worst.cc})`, fg: worst.fg, bg: worst.bg, w: worst.w, lc: worst.minLcSeen, minW, minLc, ok: worst.w >= minW && worst.minLcSeen >= minLc, note: `${CAL.length} colours` })
  }
}

const pad = (s, n) => String(s).padEnd(n)
const lpad = (s, n) => String(s).padStart(n)
console.log(pad('theme', 6), pad('pair', 52), pad('fg', 8), pad('bg', 8), lpad('WCAG', 7), lpad('Lc', 6), lpad('need', 12), ' ok')
let fails = 0, worstText = null
for (const r of rows) {
  if (!r.ok) fails++
  if (r.minW >= 4.5 && !r.role.startsWith('  ') && (!worstText || r.w < worstText.w)) worstText = r
  console.log(pad(r.theme, 6), pad(r.role, 52), pad(r.fg, 8), pad(r.bg, 8), lpad(r.w.toFixed(2), 7), lpad(r.lc.toFixed(1), 6), lpad(`${r.minW}:1 Lc${r.minLc}`, 12), r.ok ? ' ✓' : ' ✗ FAIL', r.note ? ` ${r.note}` : '')
}
console.log(`\n${rows.length} pairs, ${fails} failing. Worst text pair: ${worstText.theme} ${worstText.role} ${worstText.w.toFixed(2)}:1, Lc ${worstText.lc.toFixed(1)}.`)
process.exit(fails ? 1 : 0)
