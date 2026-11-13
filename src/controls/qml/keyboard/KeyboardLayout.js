/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

.pragma library

/*
 * The geometry and key sets of WearKeyboard, as Gboard for Wear OS (stock
 * CP3A, com.google.android.inputmethod.latin 5.3.09) lays them out. Pure
 * functions of the window size: no QML, so the numbers are testable.
 * Sizes are in px; "dp" below is W / 192 px (2 px on the 384 px watch).
 *
 * Stock evidence (decomp/com.google.android.inputmethod.latin/sources):
 *   wear2/widget/WearBodyView.java:26-40   body 60 % of W, header 25 % of the body, bottom margin 3.7 % of W
 *   wear2/widget/WearRowsLayout.java:96-137 row widths from the circle chord
 *   wear2/widget/WearRowLayout.java:41-67  key widths (equal, width_by_height, width_by_parent)
 *   defpackage/csi.java:40-47              chord(y) = sqrt(W^2 - (W - 2y)^2)
 */

/* The width of the circle of diameter W at height y (y from the top of the circle). */
function chord(W, y) {
    var d = W - 2 * y
    var v = W * W - d * d
    return v > 0 ? Math.sqrt(v) : 0
}

/*
 * The vertical layout (text area, header row, four key rows, bottom
 * margin) for a window of W x H px (WearBodyView.java:26-40).
 */
function metrics(W, H) {
    var body = Math.floor(W * 0.60)
    var header = Math.floor(body * 0.25)
    var margin = Math.floor(W * 0.037)
    var area = header + body + margin
    var top = H - area
    return {
        W: W, H: H,
        u: W / 192,                      // px per dp
        oy: (H - W) / 2,                 // the circle's top, for a window taller or shorter than wide
        body: body, header: header, margin: margin,
        areaH: area,                     // keyboard area: header + body + margin
        top: top,                        // the keyboard area (and the header row) starts here
        rowsY: top + header,             // the first key row
        rowH: body / 4,                  // four rows (rowWeight 1)
        bodyBottom: top + header + body
    }
}

/* The chord of the window's circle at window y */
function chordAt(m, y) { return chord(m.W, y - m.oy) }

/*
 * The place of key row i (0..3) of the letter pages: as wide as the circle
 * at its narrower edge less 8 px each side (middle_row_margin 4 dp); the
 * bottom row takes the chord at its top edge, with no inset
 * (wide_bottom_row, WearRowsLayout.java:128-135).
 */
function rowRect(m, i) {
    var y = m.rowsY + i * m.rowH
    var w
    if (i === 3)
        w = chordAt(m, y)
    else
        w = Math.min(chordAt(m, y), chordAt(m, y + m.rowH)) - 2 * 4 * m.u
    return { x: m.W / 2 - w / 2, y: y, w: w, h: m.rowH }
}

/* The header row: one row at the top of the keyboard area, no inset. */
function headerRect(m) {
    var w = chordAt(m, m.top)
    return { x: m.W / 2 - w / 2, y: m.top, w: w, h: m.header }
}

// ---- key sets ----

function chars(s) {
    var keys = []
    for (var i = 0; i < s.length; i++)
        keys.push({ t: "c", c: s.charAt(i) })
    return keys
}

/*
 * The pages of the letter keyboard: rows of {t, c, p}: t the type (c a
 * character, shift, back, page, space), c the label or character, p the page
 * a page key opens; width: pct a share of the row, hmul a multiple of the
 * row height, rest what is left, else equal shares of what remains.
 * ?123 (digits): 5/5/5 with the =\< key at 33 %; =\< (symbols): 10/10/7 with
 * the 1234 key at 33 % (keyboard_5_5_5_input_area.xml,
 * keyboard_10_10_7_symbol_input_area.xml); the third key of the first
 * symbol row is the locale currency.
 */
function pageRows(page, password, currency) {
    var cur = currency && currency.length > 0 ? currency : "£"
    var bottomLetters = [{ t: "shift", hmul: 1.66, host: "end" },
                         { t: "space", rest: true },
                         { t: "back", hmul: 1.66, host: "start", borderless: true }]
    var bottomPlain = [{ t: "space", rest: true },
                       { t: "back", hmul: 1.66, bordered: true }]
    if (page === 1)
        return [chars("12345"),
                chars("67890"),
                [{ t: "page", c: "=\\<", p: 2, pct: 0.33 }].concat(chars(",!?.")),
                bottomPlain]
    if (page === 2) {
        var r1 = chars("@#" + cur + "$_&-+()")
        return [r1,
                chars("^*\"':;~·%="),
                [{ t: "page", c: "1234", p: 1, pct: 0.33 }].concat(chars("[]/\\<>")),
                bottomPlain]
    }
    return [chars("qwertyuiop"),
            chars("asdfghjkl"),
            chars("zxcvbnm"),
            password ? bottomPlain : bottomLetters]
}

/* A key placed in a cell: x y w h take the touches, v* is what is drawn. */
function _place(key, x, y, w, h, m, kind) {
    var k = { t: key.t, c: key.c === undefined ? "" : key.c, p: key.p, x: x, y: y, w: w, h: h, kind: kind }
    var dx = 1.35 * m.u, dy = 2 * m.u   // function key insets 1.35 dp x 2 dp (bg_inset_space_key.xml)
    if (kind === "fn") {
        k.vx = x + dx; k.vy = y + dy; k.vw = w - 2 * dx; k.vh = h - 2 * dy
    } else if (kind === "borderless") {
        // shift and delete on the letter page: the host frame is the inner
        // 60 % of the cell (gravity end for shift, start for delete) with
        // 5 dp bottom padding (keyboard_function_bottom_row_with_shift.xml)
        var hw = w * 0.6
        k.vw = hw
        k.vx = key.host === "end" ? x + w - hw : x
        k.vy = y + dy
        k.vh = h - dy - 5 * m.u
        if (k.vh < h * 0.5) k.vh = h - 2 * dy
    } else {
        // a letter: the press fill is the cell
        k.vx = x; k.vy = y; k.vw = w; k.vh = h
    }
    return k
}

/*
 * Share a row of width rw between its keys: pct keys, hmul keys, then equal
 * shares of the rest (a `rest` key takes what the others leave).
 */
function _layoutRow(keys, rw, rh) {
    var fixed = 0, weights = 0, rest = null
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i]
        if (k.pct) fixed += k.pct * rw
        else if (k.hmul) fixed += k.hmul * rh
        else if (k.rest) rest = k
        else weights++
    }
    var share = weights > 0 ? (rw - fixed) / weights : 0
    var widths = []
    for (i = 0; i < keys.length; i++) {
        k = keys[i]
        if (k.pct) widths.push(k.pct * rw)
        else if (k.hmul) widths.push(k.hmul * rh)
        else if (k.rest) widths.push(Math.max(0, rw - fixed))
        else widths.push(share)
    }
    return widths
}

/* The keys of a letter, digits or symbols page (the four rows). */
function bodyKeys(m, page, password, currency) {
    var rows = pageRows(page, password, currency)
    var list = []
    for (var r = 0; r < rows.length; r++) {
        var rr = rowRect(m, r)
        var widths = _layoutRow(rows[r], rr.w, rr.h)
        var x = rr.x
        for (var i = 0; i < rows[r].length; i++) {
            var key = rows[r][i]
            var kind = "letter"
            if (key.t === "space" || key.t === "page" || key.bordered) kind = "fn"
            else if (key.t === "shift" || key.t === "back") kind = "borderless"
            var k = _place(key, x, rr.y, widths[i], rr.h, m, kind)
            k.row = r
            list.push(k)
            x += widths[i]
        }
    }
    return list
}

/*
 * The header row: chevron (0.85 x h, entry_button) | the middle | action
 * (1.1 x h), or for a password field shift (square) | ?123 | Done. The
 * middle area is the features row [emoji][?123 1.6 x h][mic] or the
 * suggestion chips. `mode` is "features" or "chips", `opts`:
 * {emoji, pageLabel, pageTarget, password}.
 */
function headerKeys(m, mode, opts) {
    var hr = headerRect(m), h = hr.h
    var list = []
    var dy = 2 * m.u
    var actionW = 1.1 * h
    var ax = hr.x + hr.w - actionW
    var action = { t: "action", c: "", x: ax, y: hr.y, w: actionW, h: h, kind: "action",
                   // insets 1.25 dp x 2 dp (bg_inset_action_key.xml)
                   vx: ax + 1.25 * m.u, vy: hr.y + dy, vw: actionW - 2.5 * m.u, vh: h - 2 * dy }
    if (opts.password) {
        var sq = _place({ t: "shift" }, hr.x, hr.y, h, h, m, "fn")
        var pw = ax - (hr.x + h)
        var pg = _place({ t: "page", c: opts.pageLabel, p: opts.pageTarget }, hr.x + h, hr.y, pw, h, m, "fn")
        list.push(sq, pg, action)
        return { keys: list, strip: null }
    }
    var cw = 0.85 * h
    list.push(_place({ t: "chevron" }, hr.x, hr.y, cw, h, m, "fn"))
    var mx = hr.x + cw
    var mw = ax - mx
    if (mode === "features") {
        var x = mx
        if (opts.emoji) {
            list.push(_place({ t: "emoji" }, x, hr.y, h, h, m, "fn"))
            x += h
        }
        list.push(_place({ t: "page", c: opts.pageLabel, p: opts.pageTarget }, x, hr.y, 1.6 * h, h, m, "fn"))
        x += 1.6 * h
        list.push(_place({ t: "mic" }, x, hr.y, h, h, m, "fn"))
    }
    list.push(action)
    return { keys: list, strip: { x: mx, y: hr.y, w: mw, h: h } }
}

/*
 * The number pad (WearPinKeyboard): 1 2 3 / 4 5 6 / 7 8 9 / delete 0 Done;
 * the body is 82 % of the height with 15 dp bottom padding
 * (keyboard_number_keyboard_body_height).
 */
function padMetrics(m) {
    var body = Math.round(m.H * 0.82)
    var pad = Math.round(15 * m.u)
    var top = m.H - body
    var rowH = (body - pad) / 4
    return { top: top, rowH: rowH, bottomPad: pad, body: body }
}
function padRect(m, i) {
    var p = padMetrics(m)
    var y = p.top + i * p.rowH
    var w = i === 3 ? chordAt(m, y)
                    : Math.min(chordAt(m, y), chordAt(m, y + p.rowH)) - 2 * 4 * m.u
    return { x: m.W / 2 - w / 2, y: y, w: w, h: p.rowH }
}
function padKeys(m) {
    var rows = [chars("123"), chars("456"), chars("789"),
                [{ t: "back" }, { t: "c", c: "0" }, { t: "action", c: "" }]]
    var list = []
    // three equal columns, as wide as the narrowest row allows
    var kw = 1e9
    for (var r = 0; r < 4; r++)
        kw = Math.min(kw, padRect(m, r).w / 3)
    for (r = 0; r < 4; r++) {
        var rr = padRect(m, r)
        for (var i = 0; i < 3; i++) {
            var key = rows[r][i]
            var k = _place(key, m.W / 2 - 1.5 * kw + i * kw, rr.y, kw, rr.h, m, "letter")
            k.row = r
            if (key.t === "action") k.kind = "pad-done"
            else if (key.t === "back") k.kind = "pad-back"
            list.push(k)
        }
    }
    return list
}

// ---- long press ----

/*
 * Long press alternatives, wear_softkeys_input_en.xml: only these keys have
 * any. The first item of a set is the key itself, the upper case item the
 * swap to the other case.
 */
var alternatives = {
    "e": ["e", "é", "è", "ê", "E", "ë", "ē"],
    "u": ["u", "ú", "û", "ü", "U", "ù", "ū"],
    "i": ["i", "í", "î", "ï", "I", "ī", "ì"],
    "o": ["o", "ó", "ô", "ö", "ò", "O", "œ", "ø", "ō", "õ"],
    "a": ["a", "à", "á", "â", "ä", "A", "æ", "ã", "å", "ā"],
    "s": ["s", "S", "ß"],
    "c": ["c", "C", "ç"],
    "n": ["n", "N", "ñ"]
}

/* The popup items of a key: with shift on every letter is upper case (one
 * letter each, so the sharp s stays), without duplicates. */
function popupItems(ch, shifted) {
    var base = alternatives[ch.toLowerCase()]
    if (!base)
        return []
    var out = []
    for (var i = 0; i < base.length; i++) {
        var it = base[i]
        if (shifted) {
            var u = it.toUpperCase()
            it = u.length === it.length ? u : it
        }
        if (out.indexOf(it) < 0)
            out.push(it)
    }
    return out
}

// ---- curves ----

/*
 * A CSS cubic-bezier easing (x1, y1, x2, y2) at progress t (0..1): solve
 * x(s) = t by bisection, return y(s).
 */
function cubicBezier(x1, y1, x2, y2, t) {
    if (t <= 0) return 0
    if (t >= 1) return 1
    var lo = 0, hi = 1, s = t
    for (var i = 0; i < 40; i++) {
        s = (lo + hi) / 2
        var x = 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s
        if (x < t) lo = s; else hi = s
    }
    return 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s
}

/* gm3 emphasized, the preview's 450 ms (ctz.java:270-316):
 * M0,0 C0.05,0 0.133,0.06 0.167,0.4 C0.208,0.82 0.25,1 1,1 */
var emphasizedCurve = [0.05, 0, 0.133, 0.06, 0.167, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]

/* standard accelerate (0.3, 0, 1, 1) */
function standardAccelerate(t) { return cubicBezier(0.3, 0, 1, 1, t) }

/*
 * The alpha of the two preview buttons while the keyboard collapses by
 * fraction f (0 open, 1 collapsed): standard-accelerate((f - 0.5) / 0.4).
 */
function previewButtonAlpha(f) {
    var t = (f - 0.5) / 0.4
    return t <= 0 ? 0 : t >= 1 ? 1 : standardAccelerate(t)
}

/* The side padding of the one line text field (WearStagingEditText.f()): min(1 dp + (W - chord(y)) / 2, 26 % of W) */
function textPadding(m, y) {
    return Math.min(m.u + (m.W - chordAt(m, y)) / 2, 0.26 * m.W)
}

/* Code points: the step over one character at index i going forward (+1) or back (-1) */
function stepIndex(text, i, dir) {
    if (dir > 0) {
        if (i >= text.length) return text.length
        var c = text.charCodeAt(i)
        return i + ((c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) ? 2 : 1)
    }
    if (i <= 0) return 0
    var d = text.charCodeAt(i - 1)
    return i - ((d >= 0xDC00 && d <= 0xDFFF && i > 1) ? 2 : 1)
}
