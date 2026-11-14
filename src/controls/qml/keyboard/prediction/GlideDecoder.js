/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

.pragma library

/*
 * Glide typing (text-input-17): the decoder, as pure functions. A glide is the
 * path of the finger over the letter keys; the words it can mean come from
 * WordPredictor.glideCandidates() (the words that begin and end under the
 * ends of the path, the likeliest first) and each is scored by how well the
 * path through the centres of ITS letters matches the finger's path
 * (template matching in the style of SHARK2: both paths resampled to equal
 * steps, the mean distance in key widths), plus the letters of the word the
 * finger never came near, how far the two lengths differ and, a little, how
 * unusual the word is (its place in the candidate list).
 */

/* Points each path is resampled to */
var STEPS = 32
/* The finger must come within this many key widths of the centre of every letter of the word */
var NEAR = 0.9
/* The ends of the path must be within this many key widths of the first and last letter of the word */
var END_RADIUS = 1.3
/* The words kept for the second pass (the visited letters) */
var SHORTLIST = 40
/* Weights of the score (key widths): letters never visited, length ratio (ln), place in the list */
var W_MISS = 0.5
var W_LENGTH = 0.25
var W_PRIOR = 0.2
/* The list is at most this long (WordPredictor.glideCandidates limit): the prior is the place in it, on a log scale */
var PRIOR_SCALE = Math.log(3001)
/* A touch that moves less than this many key widths from the start, or passes fewer than two keys, is a tap */
var MIN_TRAVEL = 0.8

function _dist(a, b) {
    var dx = a.x - b.x, dy = a.y - b.y
    return Math.sqrt(dx * dx + dy * dy)
}

/* The length of a polyline */
function pathLength(p) {
    var l = 0
    for (var i = 1; i < p.length; i++)
        l += _dist(p[i - 1], p[i])
    return l
}

/* A polyline as n points at equal steps along it (the ends included) */
function resample(p, n) {
    var out = []
    if (p.length === 0)
        return out
    var total = pathLength(p)
    if (p.length === 1 || total === 0) {
        for (var k = 0; k < n; k++)
            out.push({ "x": p[0].x, "y": p[0].y })
        return out
    }
    var step = total / (n - 1)
    out.push({ "x": p[0].x, "y": p[0].y })
    var acc = 0
    var prev = p[0]
    var i = 1
    while (i < p.length && out.length < n) {
        var d = _dist(prev, p[i])
        if (acc + d >= step && d > 0) {
            var t = (step - acc) / d
            var q = { "x": prev.x + (p[i].x - prev.x) * t, "y": prev.y + (p[i].y - prev.y) * t }
            out.push(q)
            prev = q
            acc = 0
        } else {
            acc += d
            prev = p[i]
            i++
        }
    }
    while (out.length < n)
        out.push({ "x": p[p.length - 1].x, "y": p[p.length - 1].y })
    return out
}

/*
 * The letters of the keys within radius of a point, the nearest first
 * (centres: { "q": {x, y}, ... }).
 */
function nearKeys(point, centres, radius) {
    var found = []
    for (var c in centres) {
        var d = _dist(point, centres[c])
        if (d <= radius)
            found.push({ "c": c, "d": d })
    }
    found.sort(function (a, b) { return a.d - b.d })
    return found.map(function (f) { return f.c }).join("")
}

/*
 * The path of a word over the keys: the centres of its letters (a repeated
 * letter is one visit, an apostrophe has no key), or null when a letter has
 * no key.
 */
function wordPoints(word, centres) {
    var pts = []
    var last = ""
    for (var i = 0; i < word.length; i++) {
        var c = word.charAt(i).toLowerCase()
        if (c === "'")
            continue
        if (c === last)
            continue
        var k = centres[c]
        if (!k)
            return null
        pts.push({ "x": k.x, "y": k.y })
        last = c
    }
    return pts
}

/*
 * The keys the path passes over, in order, each once in a row (the distinct
 * letters touched; a glide needs at least two).
 */
function keysTouched(path, keyAt) {
    var out = []
    for (var i = 0; i < path.length; i++) {
        var c = keyAt(path[i].x, path[i].y)
        if (c && (out.length === 0 || out[out.length - 1] !== c))
            out.push(c)
    }
    return out
}

/*
 * Is this touch a glide yet: it has moved at least MIN_TRAVEL key widths from
 * where it began and has been over two different letter keys.
 */
function isGlide(path, keyW, touchedCount) {
    if (path.length < 2 || touchedCount < 2)
        return false
    return _dist(path[0], path[path.length - 1]) >= MIN_TRAVEL * keyW || pathLength(path) >= 1.5 * keyW
}

/*
 * Decodes a glide: path is [{x, y}] (the touch points), centres the letter
 * key centres, keyW the key width in the same unit, candidates the words
 * (WordPredictor.glideCandidates, likeliest first), count how many to return.
 * Returns the words, the best first, as [{ "word", "score" }] (lower is better).
 */
function decode(path, centres, keyW, candidates, count) {
    if (path.length < 2 || keyW <= 0)
        return []
    var n = STEPS
    var user = resample(path, n)
    var dense = resample(path, 2 * n)
    var uLen = Math.max(pathLength(path), 1)
    var first = path[0], last = path[path.length - 1]
    var scored = []
    var seen = {}
    for (var idx = 0; idx < candidates.length; idx++) {
        var word = candidates[idx]
        var key = word.toLowerCase()
        if (seen[key])
            continue
        var wp = wordPoints(word, centres)
        if (!wp || wp.length < 2)
            continue
        if (_dist(first, wp[0]) > END_RADIUS * keyW || _dist(last, wp[wp.length - 1]) > END_RADIUS * keyW)
            continue
        seen[key] = true
        var wr = resample(wp, n)
        var s = 0
        for (var i = 0; i < n; i++)
            s += _dist(user[i], wr[i])
        var loc = s / n / keyW
        var wLen = Math.max(pathLength(wp), 1)
        var score = loc + W_LENGTH * Math.abs(Math.log(uLen / wLen))
                    + W_PRIOR * Math.log(1 + idx) / PRIOR_SCALE
        scored.push({ "word": word, "score": score, "points": wp })
    }
    scored.sort(function (a, b) { return a.score - b.score })
    scored = scored.slice(0, Math.max(SHORTLIST, count))
    // the letters of the word the finger never came near
    for (var j = 0; j < scored.length; j++) {
        var miss = 0
        var pts = scored[j].points
        for (var q = 0; q < pts.length; q++) {
            var dmin = 1e9
            for (var r = 0; r < dense.length; r++) {
                var dd = _dist(pts[q], dense[r])
                if (dd < dmin)
                    dmin = dd
            }
            if (dmin / keyW > NEAR)
                miss += dmin / keyW - NEAR
        }
        scored[j].score += W_MISS * miss
    }
    scored.sort(function (a, b) { return a.score - b.score })
    return scored.slice(0, count).map(function (s) { return { "word": s.word, "score": s.score } })
}
