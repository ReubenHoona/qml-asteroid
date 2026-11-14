/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

.pragma library
.import "NextWordData.js" as Data

/*
 * The rules of the keyboard's prediction, as pure functions (WearKeyboard has
 * the state, the tests have the numbers): next-word candidates after a space,
 * autocorrection of the word just typed, the double space that makes a full
 * stop, and the position of the punctuation that takes the place of a space
 * the keyboard added. Stock (Gboard, com.google.android.inputmethod.latin
 * VALUES.tsv): pref_def_value_next_word_prediction, _latin_auto_correction,
 * _enable_double_space_period are all true; pref_def_value_latin_enable_ac_revert
 * is false (the optional "revert on any key"), so only the backspace right after
 * a correction undoes it (as in Gboard and AOSP LatinIME).
 */

/* A double space makes a full stop only when the second space comes within this many ms
 * (AOSP LatinIME config_double_space_period_timeout, 1100: not in the stock resources, inferred) */
var DOUBLE_SPACE_MS = 1100
/* Autocorrection needs a word of this many letters at least (a shorter slip has too many readings) */
var MIN_AUTOCORRECT_LETTERS = 3
/* The punctuation that takes the place of a space the keyboard added, and that corrects the word before it */
var PUNCTUATION = ".,!?;:"

/* The last word of the text before the cursor (as WearKeyboard's _currentWord) */
function currentWord(before) {
    var m = /[^\s.,!?;:"()\[\]{}<>@#…]*$/.exec(before)
    return m ? m[0] : ""
}

/* The text before the cursor ends a sentence (a . ! ? and a space, or a new line) */
function endsSentence(before) {
    return /[.!?]["')\]]*\s+$/.test(before) || /\n$/.test(before)
}

/* The cursor is where a sentence begins: the field is empty or the sentence before has ended */
function atSentenceStart(before) {
    return before.trim().length === 0 || endsSentence(before)
}

// the words before the cursor, lower case, without the punctuation round them
function _words(before) {
    var raw = before.trim().split(/\s+/)
    var out = []
    for (var i = 0; i < raw.length; i++) {
        var w = raw[i].replace(/^[^\w']+/, "").replace(/[^\w']+$/, "").toLowerCase()
        if (w.length > 0)
            out.push(w)
    }
    return out
}

function _fixI(w) {
    return w === "i" ? "I" : w
}

/*
 * Up to count words that can come next, the likeliest first, for the text
 * before the cursor. Only after a space (while a word is being typed the
 * word predictor completes it); nothing in an empty field (the features row
 * is what stock shows when the keyboard opens); the starts of sentences after
 * a full stop.
 */
function nextWords(before, count) {
    if (before.length === 0 || !/\s$/.test(before) || count <= 0)
        return []
    if (endsSentence(before))
        return Data.STARTS.slice(0, count)
    var words = _words(before)
    if (words.length === 0)
        return []
    var w1 = words[words.length - 1]
    var w2 = words.length > 1 ? words[words.length - 2] : ""
    var out = []
    var lists = [Data.triples[w2 + " " + w1], Data.pairs[w1]]
    for (var l = 0; l < lists.length; l++) {
        var list = lists[l] || []
        for (var i = 0; i < list.length && out.length < count; i++) {
            if (out.indexOf(list[i]) < 0)
                out.push(list[i])
        }
    }
    return out.map(_fixI)
}

/* Two spaces after a word end the sentence: the text before the cursor ends in one space
 * that follows something a sentence can end after (not a space or punctuation) */
function canDoubleSpace(before) {
    var n = before.length
    if (n < 2 || before.charAt(n - 1) !== " ")
        return false
    return !/[\s.,!?;:\-–—…\/\\@#$&*+=<>|~^_`]/.test(before.charAt(n - 2))
}

/* The double space is on: the second space comes within DOUBLE_SPACE_MS of the first, which is just before the cursor */
function doubleSpace(before, firstSpaceTime, now) {
    return firstSpaceTime > 0 && now - firstSpaceTime <= DOUBLE_SPACE_MS && now >= firstSpaceTime && canDoubleSpace(before)
}

// the key position of a letter on QWERTY, in key widths (the rows are staggered)
var _rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
var _stagger = [0, 0.25, 0.75]
function _pos(c) {
    for (var r = 0; r < 3; r++) {
        var i = _rows[r].indexOf(c)
        if (i >= 0)
            return { "x": i + _stagger[r], "y": r }
    }
    return null
}

/* The two letters sit next to each other on the keyboard (a slip of the finger) */
function neighbours(a, b) {
    var p = _pos(a), q = _pos(b)
    if (!p || !q || a === b)
        return false
    return Math.sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y)) <= 1.35
}

/*
 * What kind of slip the word typed is: the word meant differs from it by
 * "swap" (two letters exchanged), "sub" (one letter, \a at is the index,
 * \a with is the letter meant), "missing" (a letter left out) or "extra"
 * (a letter added), "apostrophe" (only the apostrophes differ: dont, im), or
 * "" for anything else (two slips or none). Case does not count.
 */
function slip(typed, meant) {
    var a = typed.toLowerCase(), b = meant.toLowerCase()
    if (a === b)
        return { "kind": "" }
    if (b.replace(/'/g, "") === a)
        return { "kind": "apostrophe" }
    var n = a.length, m = b.length
    var i = 0
    while (i < n && i < m && a.charAt(i) === b.charAt(i))
        i++
    if (n === m) {
        if (i + 1 < n && a.charAt(i) === b.charAt(i + 1) && a.charAt(i + 1) === b.charAt(i)
                && a.substring(i + 2) === b.substring(i + 2))
            return { "kind": "swap", "at": i }
        if (a.substring(i + 1) === b.substring(i + 1))
            return { "kind": "sub", "at": i, "typed": a.charAt(i), "meant": b.charAt(i) }
        return { "kind": "" }
    }
    if (m === n + 1 && a.substring(i) === b.substring(i + 1))
        return { "kind": "missing", "at": i }
    if (n === m + 1 && a.substring(i + 1) === b.substring(i))
        return { "kind": "extra", "at": i }
    return { "kind": "" }
}

/*
 * The word to put in place of the word just typed when the space (or the
 * full stop, comma ...) is hit, or "" to leave it. candidates are
 * WordPredictor.suggest() of the typed word, the likeliest first;
 * isWord(w) asks the word list. Only a confident correction: the typed
 * word is no word, has three letters or more, no digit, is not shouting;
 * a name (a capital that does not start a sentence) stays; the word meant
 * is not a completion of it (a half-typed word is never "corrected"); and
 * the slip is one a finger makes: two letters swapped, a neighbouring key
 * (so "lol" is not "lot"), a letter missing or added in a word of four
 * letters or more, or the apostrophe left out.
 */
function autocorrect(typed, candidates, isWord, sentenceStart) {
    if (typed.length < MIN_AUTOCORRECT_LETTERS || /[0-9]/.test(typed) || /[^A-Za-z']/.test(typed))
        return ""
    if (typed.length > 1 && typed === typed.toUpperCase())
        return ""
    if (typed.charAt(0) !== typed.charAt(0).toLowerCase() && !sentenceStart)
        return ""
    if (isWord(typed))
        return ""
    var lower = typed.toLowerCase()
    var best = ""
    var bestRank = 99
    for (var i = 0; i < candidates.length; i++) {
        var c = candidates[i]
        var cl = c.toLowerCase()
        if (cl === lower)
            continue
        var s = slip(lower, cl)
        // 0: a swap or the apostrophe (the surest), 1: any other slip a finger makes, 99: none
        var rank = 99
        switch (s.kind) {
        case "apostrophe":
        case "swap":
            rank = 0
            break
        case "sub":
            if (neighbours(s.typed, s.meant))
                rank = 1
            break
        case "missing":
        case "extra":
            // a completion ("hel" -> "help") is the word still being typed
            if (cl.indexOf(lower) !== 0 && typed.length >= 4)
                rank = 1
            break
        }
        // the first of the surest kind, else the likeliest of the others
        if (rank < bestRank) {
            best = c
            bestRank = rank
        }
    }
    return best
}

/*
 * The text after the backspace that undoes a correction: the corrected word
 * and its space go, the word as it was typed comes back (and is not corrected
 * again). Returns the new text and cursor, or null when the cursor is not
 * right after the corrected word and its space.
 */
function revertCorrection(text, cursor, correction) {
    if (!correction)
        return null
    var end = correction.start + correction.corrected.length + correction.trailing.length
    if (cursor !== end || text.substring(correction.start, end) !== correction.corrected + correction.trailing)
        return null
    return {
        "text": text.substring(0, correction.start) + correction.typed + text.substring(end),
        "cursor": correction.start + correction.typed.length
    }
}

/* The keyboard added a space and the punctuation typed now takes its place: "hello ," becomes "hello," */
function swapsSpace(before, autoSpaceEnd, c) {
    return PUNCTUATION.indexOf(c) >= 0 && before.length === autoSpaceEnd && before.length >= 2
           && before.charAt(before.length - 1) === " " && before.charAt(before.length - 2) !== " "
}
