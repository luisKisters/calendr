// Calendr v10 · the Designer proof (a worker of contrast.mjs; one canvas per worker). Streams pairs, returns counts.
// The colour controls split into groups that never share a pair; each group is crossed fully for this canvas, both modes and every
// calendar colour under every event palette:
//   chrome  = sidebar shade × right column × header × hover strength          → the text greys on every surface, live red, Join, hour labels
//   accent  = chrome variants × accent                                        → today pill / filled circle / outline text, focus ring
//   lines   = distinct fg1 × (grid × hour line, grid × half-hour line, grid × day divider × dividers, all-day separator, pane edge)
//   events  = distinct text greys × fill × title × time colour × hue          → title, time, hover / hatch, selected, needs-reply outline
//   past    = distinct text greys × fill × past × hue                         → past title / time, declined
//   chips   = distinct text greys × all-day style × title × time colour × hue (+ past)
// The event recipe reads only bg, raised and the text greys of the canvas, so crossing the distinct grey sets produced by the chrome
// controls covers every chrome × event combination.
import { parentPort, workerData } from 'node:worker_threads'
import { createRequire } from 'node:module'
const req = createRequire(import.meta.url)
const THEME = req('./tokens.js'), D = req('./designer.js'), U = THEME.util, P = D.probe
const { ci, T, colours } = workerData
const n = k => D.CONTROLS[D.KI[k]].o.length, DECOR = new Set(['decor', 'decorMin', 'structure'])
const st = { pairs: 0, fails: 0, worst: null, failSamples: [], fallback: 0, fallbackFills: [], groups: {} }
let G = ''
function C(theme, what, fg, bg, key, tag) {
  const [minR, minLc, maxLc] = T[theme][key]
  const r = U.wcag(fg, bg), a = Math.abs(U.apca(fg, bg))
  const okk = r >= minR - 1e-9 && a >= minLc - 0.05 && (maxLc == null || a <= maxLc + 0.05)
  st.pairs++; st.groups[G].pairs++
  if (!okk) { st.fails++; if (st.failSamples.length < 8) st.failSamples.push(`canvas ${ci} ${theme} ${tag} · ${what} ${fg} on ${bg} ${r.toFixed(2)}:1 Lc ${a.toFixed(1)} (≥${minR}:1 Lc≥${minLc}${maxLc != null ? ` ≤${maxLc}` : ''})`) }
  if (!DECOR.has(key) && key !== 'nontext') { const m = Math.min(r / minR, minLc ? a / minLc : Infinity); if (!st.worst || m < st.worst.m) st.worst = { m, theme, tag, what, fg, bg, r, a, target: `≥${minR}:1 Lc≥${minLc}` } }
}
const group = g => { G = g; st.groups[g] = st.groups[g] || { combos: 0, pairs: 0 } }
const combo = () => st.groups[G].combos++
const base = D.decode('-'), hues = [...new Set(colours.flatMap(h => P.PALETTES.map((_, p) => P.palHex(h, p))))]

for (const theme of ['dark', 'paper']) {
  const dk = theme === 'dark'
  // ---- chrome
  group('chrome'); const variants = new Map()
  for (let sb = 0; sb < n('sideBg'); sb++) for (let rb = 0; rb < n('rightBg'); rb++) for (let hb = 0; hb < n('headBg'); hb++) for (let hk = 0; hk < n('hoverK'); hk++) {
    const o = { ...base, canvas: ci, sideBg: sb, rightBg: rb, headBg: hb, hoverK: hk }, t = P.canvasOf(o, theme), tag = `chrome ${sb}${rb}${hb}${hk}`
    combo()
    const canv = dk ? [['bg', t.bg], ['rail', t.rail]] : [['bg', t.bg], ['raised', t.raised], ['rail', t.rail]]
    const soft = [['raised', t.raised], ['surface', t.surface], ['hover', t.hover], ['hover on rail', t.hoverRail], ['selected', t.selected], ['right column', t.rcol], ['hover in right column', t.hoverR], ['header', t.hdrbg]]
    for (const [sn, s] of canv) { C(theme, `fg1 on ${sn}`, t.fg1, s, U.relL(s) < 0.01 || !dk ? 'fg1' : 'fg1soft', tag); C(theme, `fg2 on ${sn}`, t.fg2, s, 'fg2', tag); C(theme, `fg3 on ${sn}`, t.fg3, s, 'fg3', tag) }
    for (const [sn, s] of soft) { C(theme, `fg1 on ${sn}`, t.fg1, s, 'fg1soft', tag); C(theme, `fg2 on ${sn}`, t.fg2, s, 'fg2soft', tag); C(theme, `fg3 on ${sn}`, t.fg3, s, 'fg3soft', tag) }
    for (const [sn, s] of [['bg', t.bg], ['rail', t.rail], ['card', dk ? t.surface : t.raised], ['right column', t.rcol]]) C(theme, `live text on ${sn}`, t.live, s, 'live', tag)
    C(theme, 'now pill text on live red', t.onLive, t.live, 'live', tag)
    C(theme, 'Join button text', t.joinFg, t.joinBg, 'accent', tag)
    C(theme, 'selected segment edge vs track', t.segRing, t.surface, 'nontext', tag)
    for (const [sn, h] of [['ok', t.ok], ['warn', t.warn], ['danger', t.danger]]) C(theme, `${sn} text on bg`, h, t.bg, 'status', tag)
    for (let hc = 0; hc < n('hourc'); hc++) { const hcol = hc === 0 ? t.fg2 : hc === 1 ? U.mx(t.fg2, t.fg3, .5) : t.fg3; C(theme, `hour labels (${hc})`, hcol, t.bg, 'fg3', tag) }
    C(theme, 'now line vs bg', t.live, t.bg, 'nontext', tag)
    variants.set([t.bg, t.raised, t.fg1, t.fg2, t.fg3].join(), { t, o })
  }
  // ---- accent
  group('accent')
  for (const { t, o } of variants.values()) for (let ac = 0; ac < n('accent'); ac++) {
    const x = { ...t }; P.accentOf(x, { ...o, accent: ac }); combo()
    C(theme, 'today marker / accent pill text', x.onAccent, x.accent, 'accent', `accent ${ac}`)
    C(theme, 'focus ring vs bg', x.focus, x.bg, 'nontext', `accent ${ac}`); C(theme, 'focus ring vs raised', x.focus, x.raised, 'nontext', `accent ${ac}`)
    C(theme, 'outline marker ring vs bg', x.accent, x.bg, 'nontext', `accent ${ac}`)
  }
  // ---- lines
  group('lines')
  const fg1s = [...new Map([...variants.values()].map(v => [v.t.fg1, v])).values()]
  for (const { t, o } of fg1s) {
    const L = oo => { const x = { ...t }; P.linesOf(x, { ...o, ...oo }); combo(); return x }
    for (let g = 0; g < n('grid'); g++) {
      for (let h = 0; h < n('lHour'); h++) { const x = L({ grid: g, lHour: h }); C(theme, 'hour line', x.grid, x.bg, 'structure', `grid ${g} hour ${h}`) }
      for (let h = 0; h < n('lHalf'); h++) { const x = L({ grid: g, lHalf: h }); if (x.gridHalf !== 'transparent') C(theme, 'half-hour line', x.gridHalf, x.bg, 'decor', `grid ${g} half ${h}`) }
      for (let h = 0; h < n('lDay'); h++) for (let dv = 0; dv < 2; dv++) { const x = L({ grid: g, lDay: h, div: dv }); if (x.gridV !== 'transparent') C(theme, 'day divider', x.gridV, x.bg, 'decor', `grid ${g} day ${h}`) }
    }
    for (let a = 0; a < n('lAd'); a++) { const x = L({ lAd: a }); C(theme, 'all-day separator', x.hairStrong, x.bg, 'structure', `ad ${a}`) }
    for (let a = 0; a < n('lPane'); a++) { const x = L({ lPane: a }); C(theme, 'pane edge', x.hair, x.bg, 'decor', `pane ${a}`) }
  }
  // ---- events, past, chips (per distinct grey set)
  const greys = [...variants.values()]
  const evp = (e, t, tag, hoverMeta = true) => {
    C(theme, 'event title', e.title, e.fill, 'evTitle', tag); C(theme, 'event time', e.meta, e.fill, 'evMeta', tag)
    if (e.fill2 !== e.fill) { C(theme, 'title on fade end', e.title, e.fill2, 'evTitle', tag); C(theme, 'time on fade end', e.meta, e.fill2, 'evMeta', tag) }
    C(theme, 'title on hover', e.title, e.fillH, 'evTitle', tag); if (hoverMeta) C(theme, 'time on hover / hatch', e.meta, e.fillH, 'evMeta', tag)
    C(theme, 'selected title', e.titleSel, e.fillSel, 'evTitle', tag); C(theme, 'selected time', e.metaSel, e.fillSel, 'evSelMeta', tag)
    C(theme, 'needs-reply outline vs bg', e.edge, t.bg, 'nontext', tag)
  }
  const pp = (p, tag) => { C(theme, 'past title', p.titlePast, p.fillPast, 'evPastTitle', tag); C(theme, 'past time', p.metaPast, p.fillPast, 'evPastMeta', tag); C(theme, 'declined title', p.titleDec, p.fillDec, 'evDecl', tag) }
  group('events')
  for (const { t, o } of greys) for (let fl = 0; fl < n('fill'); fl++) for (let ti = 0; ti < n('title'); ti++) for (let tc = 0; tc < n('tcol'); tc++) {
    const oo = { ...o, fill: fl, title: ti, tcol: tc, palette: 0 }; combo()
    if (!D.titleAllowed(fl, ti, theme)) { st.fallback++; const fn = D.CONTROLS[D.KI.fill].o[fl]; if (!st.fallbackFills.includes(fn)) st.fallbackFills.push(fn) }
    for (const h of hues) evp(P.recipe(h, oo, t, theme), t, `fill ${fl} title ${ti} time ${tc} ${h}`)
  }
  group('past')
  for (const { t } of greys) for (let fl = 0; fl < n('fill'); fl++) for (let pa = 0; pa < n('past'); pa++) {
    combo()
    for (const h of hues) { const { fill } = P.fillsOf(h, fl, t, theme); pp(P.pastOf(h, fl, pa, t, theme, fill), `fill ${fl} past ${pa} ${h}`) }
  }
  group('chips')
  for (const { t, o } of greys) for (let ad = 1; ad < n('allday'); ad++) for (let ti = 0; ti < n('title'); ti++) for (let tc = 0; tc < n('tcol'); tc++) {
    const oo = P.adOpts({ ...o, allday: ad, title: ti, tcol: tc, palette: 0 }); combo()
    for (const h of hues) evp(P.recipe(h, oo, t, theme), t, `allday ${ad} title ${ti} time ${tc} ${h}`)
  }
  for (const { t, o } of greys) for (let ad = 1; ad < n('allday'); ad++) for (let pa = 0; pa < n('past'); pa++) {
    const oo = P.adOpts({ ...o, allday: ad }); combo()
    for (const h of hues) { const { fill } = P.fillsOf(h, oo.fill, t, theme); pp(P.pastOf(h, oo.fill, pa, t, theme, fill), `allday ${ad} past ${pa} ${h}`) }
  }
}
st.hues = hues.length
parentPort.postMessage(st)
