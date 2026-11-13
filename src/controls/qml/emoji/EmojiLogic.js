/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

.pragma library
.import "EmojiData.js" as Data

/*
 * The logic of the emoji page, as pure functions (so the numbers are
 * testable): the category list, decoding of the generated data, the recents
 * and the stock page geometry.
 *
 * Stock evidence (Gboard for Wear OS, decomp/com.google.android.inputmethod.latin):
 *   res/values: emoji_keyboard_header_height 15 %, emoji_picker_row_height_ratio 18 %,
 *   emoji_picker_row_vertical_margin 1 dp, emoji_picker_column_count 4,
 *   emoji_body_padding_left/right 19 dp, emoji_body_padding_top 3 dp,
 *   emoji_header_padding_horizontal 24 dp, emoji_picker_header_icon_* (20 dp icon in a 24 dp
 *   holder, 2 x 24 dp underline), emoji_picker_default_emoji_text_size 30 dp,
 *   emoji_max_recent_count 8, emoji_expanded_padding_bottom_extra 40 dp;
 *   sources/defpackage/ctb.java (WearExpandableEmojiKeyboardController: the expansion).
 */

/* The tabs in stock order: Recently used, then the nine Unicode groups.
 * icon: the ion name (the icon theme maps these names to Material shapes). */
var tabs = [
    { id: "recent",     icon: "ios-time" },
    { id: "smileys",    icon: "ios-happy" },
    { id: "people",     icon: "ios-people" },
    { id: "animals",    icon: "ios-paw" },
    { id: "food",       icon: "ios-pizza" },
    { id: "travel",     icon: "ios-car" },
    { id: "activities", icon: "ios-football" },
    { id: "objects",    icon: "ios-bulb" },
    { id: "symbols",    icon: "ios-heart" },
    { id: "flags",      icon: "ios-flag" }
]

function decode(hex) {
    var cps = hex.split(".")
    var s = ""
    for (var i = 0; i < cps.length; i++)
        s += String.fromCodePoint(parseInt(cps[i], 16))
    return s
}

var _cache = {}

/*
 * The emoji of a category (not "recent"), as [{ e: "emoji", v: ["variant", ...] }]
 * in Unicode order, those with an Emoji version up to maxVersion (x10; 160 = E16.0).
 */
function list(id, maxVersion) {
    var key = id + "/" + maxVersion
    if (_cache[key])
        return _cache[key]
    var out = []
    for (var c = 0; c < Data.categories.length; c++) {
        if (Data.categories[c].id !== id)
            continue
        var entries = Data.categories[c].data.split("|")
        for (var i = 0; i < entries.length; i++) {
            var parts = entries[i].split(",")
            var head = parts[0].split(":")
            if (parseInt(head[1], 10) > maxVersion)
                continue
            var vars = []
            for (var j = 1; j < parts.length; j++)
                vars.push(decode(parts[j]))
            out.push({ e: decode(head[0]), v: vars })
        }
    }
    _cache[key] = out
    return out
}

var _variantIndex = null

/* The variants of an emoji of any category with the emoji itself first, or [] when it has none */
function variantsOf(e) {
    if (_variantIndex === null) {
        _variantIndex = {}
        for (var t = 1; t < tabs.length; t++) {
            var l = list(tabs[t].id, 9999)
            for (var i = 0; i < l.length; i++) {
                if (l[i].v.length === 0)
                    continue
                var all = [l[i].e].concat(l[i].v)
                for (var j = 0; j < all.length; j++)
                    _variantIndex[all[j]] = all
            }
        }
    }
    return _variantIndex[e] || []
}

/* The recents after picking e: e first, no duplicates, at most max */
function addRecent(recents, e, max) {
    var out = [e]
    var r = recents || []
    for (var i = 0; i < r.length && out.length < max; i++)
        if (typeof r[i] === "string" && r[i].length > 0 && out.indexOf(r[i]) < 0)
            out.push(r[i])
    return out
}

/* The stored recents (anything dconf may hold) as a clean list of at most max strings */
function cleanRecents(raw, max) {
    var out = []
    if (!raw || typeof raw.length !== "number")
        return out
    for (var i = 0; i < raw.length && out.length < max; i++) {
        var s = raw[i]
        if (typeof s === "string" && s.length > 0 && out.indexOf(s) < 0)
            out.push(s)
    }
    return out
}

/* The recents as grid items (a recent skin tone keeps its own variants) */
function recentItems(recents) {
    var out = []
    for (var i = 0; i < recents.length; i++) {
        var v = variantsOf(recents[i])
        out.push({ e: recents[i], v: v.length > 1 ? v : [] })
    }
    return out
}

/*
 * The geometry of the page for a window of W px wide (u = px per dp, W / 192):
 * the header is 15 % of W; the grid has 4 columns inside 19 dp side padding;
 * a row is 18 % of W plus 1 dp (71 px at 384); the first row is 3 dp down.
 */
function geometry(W, columns) {
    var u = W / 192
    var cols = columns || 4
    var header = Math.floor(W * 0.15)
    var side = Math.round(19 * u)
    var gridW = W - 2 * side
    return {
        u: u,
        header: header,
        side: side,
        gridW: gridW,
        columns: cols,
        cellW: gridW / cols,
        rowH: Math.round(W * 0.18) + Math.round(u),
        gridTop: Math.round(3 * u),
        emoji: Math.round(30 * u),
        corner: Math.round(8 * u),
        indicator: Math.round(5 * u),
        iconSize: Math.round(20 * u),
        holderW: Math.round(24 * u),
        underlineH: Math.round(2 * u),
        underlineW: Math.round(24 * u),
        headerPad: Math.round(24 * u),
        actionW: header * 1.1,
        expandedBottom: Math.round(40 * u)
    }
}

/*
 * The crown on the expandable page (ctb.java b(), csy.java case 0). px > 0
 * scrolls forward. "expand": the body grows to the whole screen first;
 * "collapse": turned back with the grid at its top; else "scroll".
 */
function crownAction(px, expansion, atTop) {
    if (px > 0 && expansion < 1)
        return "expand"
    if (px < 0 && expansion > 0 && atTop)
        return "collapse"
    return "scroll"
}

/* The duration of the expansion between two fractions (ctb.java p(): |dh| * 450 / (l - k) ms) */
function expandDuration(e0, e1) { return Math.round(Math.abs(e1 - e0) * 450) }

/* ---- editing: a whole emoji (a sequence) is one character ---- */

function _isLow(c) { return c >= 0xDC00 && c <= 0xDFFF }
function _isHigh(c) { return c >= 0xD800 && c <= 0xDBFF }
function _cpAt(text, i) { return text.codePointAt(i) }
/* the start of the code point that ends at i */
function _cpStart(text, i) {
    if (i <= 0) return 0
    return i - ((_isLow(text.charCodeAt(i - 1)) && i > 1 && _isHigh(text.charCodeAt(i - 2))) ? 2 : 1)
}
function _isRegional(cp) { return cp >= 0x1F1E6 && cp <= 0x1F1FF }
/* what continues the character before it: variation selector, keycap, skin tone, tag */
function _extends(cp) {
    return cp === 0xFE0F || cp === 0xFE0E || cp === 0x20E3 || (cp >= 0x1F3FB && cp <= 0x1F3FF)
           || (cp >= 0xE0020 && cp <= 0xE007F)
}

/*
 * The index Backspace goes back to from index i: a flag, a keycap, a skin-toned
 * person or a ZWJ sequence goes whole, anything else one code point (stock
 * deletes the whole grapheme).
 */
function stepBack(text, i) {
    if (i <= 0)
        return 0
    var s = _cpStart(text, i)
    while (s > 0 && _extends(_cpAt(text, s)))
        s = _cpStart(text, s)
    if (_isRegional(_cpAt(text, s))) {
        // flags are pairs counted from the left of a run of regional indicators
        var n = 1, k = s
        while (k > 0 && _isRegional(_cpAt(text, _cpStart(text, k)))) {
            k = _cpStart(text, k)
            n++
        }
        if (n % 2 === 0)
            s = _cpStart(text, s)
    }
    while (s > 0) {
        var z = _cpStart(text, s)
        if (_cpAt(text, z) !== 0x200D || z === 0)
            break
        var p = _cpStart(text, z)
        while (p > 0 && _extends(_cpAt(text, p)))
            p = _cpStart(text, p)
        s = p
    }
    return s
}

/* The index after the emoji (or character) that starts at i */
function stepForward(text, i) {
    if (i >= text.length)
        return text.length
    var first = _cpAt(text, i)
    var e = i + (first > 0xFFFF ? 2 : 1)
    if (_isRegional(first) && e < text.length && _isRegional(_cpAt(text, e)))
        e += 2
    while (e < text.length) {
        var cp = _cpAt(text, e)
        var w = cp > 0xFFFF ? 2 : 1
        if (_extends(cp)) {
            e += w
        } else if (cp === 0x200D && e + w < text.length) {
            e += w
            e += _cpAt(text, e) > 0xFFFF ? 2 : 1
        } else {
            break
        }
    }
    return e
}
