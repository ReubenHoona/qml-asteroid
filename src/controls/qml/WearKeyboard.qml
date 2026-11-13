/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import QtQuick.Shapes
import Nemo.DBus
import Nemo.KeepAlive
import Nemo.Configuration
import org.asteroid.controls
import "keyboard/KeyboardLayout.js" as L

/*!
    \qmltype WearKeyboard
    \inqmlmodule org.asteroid.controls

    \brief The full screen keyboard of a round watch, as Gboard for Wear OS
    (stock CP3A).

    From the top of the screen (all in px on the 384 px watch): the text
    area (y 0-83) with the one line text field at its bottom; the header row
    (y 83-140): a chevron, the features row (emoji, ?123, microphone) or the
    suggestion chips, and the action key; four key rows of 57.5 px (y
    140-370: q-p, a-l, z-m, then shift, space, delete) and a 14 px margin.
    Each row is as wide as the circle allows at its narrower edge (less 8 px
    each side), its keys of equal width. The numbers are Gboard's
    (KeyboardLayout.js has the formulas and where they come from).

    Letter keys have no fill at rest and a #3d3d3d rounded square while
    pressed; space, ?123, emoji, the microphone and the chevron are #32312f
    pills; the action key is a #fcf7eb pill: Close (a cross) while the text is
    empty whatever the application asked for, else Send, Done, Search, Go or
    Next (\l actionKey). A press shows one bubble at a fixed place above the
    keys (Settings > Input methods > Popup on keypress,
    /org/asteroidos/ux/keyboard-popup, default on) and clicks the vibrator;
    the finger can slide to another key before it lifts. A press held for
    300 ms on e, u, i, o, a, s, c or n opens Gboard's alternatives (no
    vibration); on delete it repeats; on space with more than one keyboard
    language it opens the language switcher. ?123 and =\\< open the digit and
    symbol pages.

    The text field is one line, scrolled to keep the cursor near the middle;
    the word being typed is yellow-green (#e6ff7b). The crown moves the
    cursor (3 px of crown scroll per character, at the user's crown speed);
    edits happen at the cursor. A drag down from the text area or the header
    (or a tap on the small handle at the top) folds the keyboard away into the
    preview: the whole text, wrapped, scrolled by the crown, with a "Return to
    keyboard" circle and the action circle. A field with a \l maximumLength
    shows "N characters" as its hint and stops there. For passwords the
    header is shift, ?123 and Done, the bottom row space and delete, and the
    field has an eye toggle; digits-only fields get the PIN pad.

    There is no swipe to dismiss on the letter and symbol pages (the keyboard
    keeps its touches to itself); a right swipe leaves the preview and the
    PIN pad only. Leave by the action key (Close when empty). \l hide() fades
    the keyboard out as the system does (150 ms), then \l closed is emitted.

    While the keyboard is open the display is held on until 30 s after the
    last touch or crown turn (Nemo.KeepAlive), then the normal timeout (and the
    always-on display) follows.

    Above the keys, Gboard's strip: the suggestions for the word being
    written (WordPredictor: completions, and corrections when it is no word)
    as scrolling pill chips in rank order; a tap puts the word in place of the
    one being written, with a space. Not for passwords, numbers or addresses
    (\l suggestionsEnabled).

    The microphone dictates with the watch's own recogniser
    (asteroid-assistant's Dictate, D-Bus org.asteroidos.assistant) and shows
    crossed out when that service is not installed.

    The keyboard draws a frame when something changes; the cursor blinks (500
    ms) only while the display is on and for 30 s after the last touch.

    \qml
    WearKeyboard {
        anchors.fill: parent
        actionKey: "send"
        onAccepted: (text) => send(text)
        onDismissed: hide()
        onClosed: destroy()
    }
    \endqml

    \l TextField and \l TextArea open it over the whole window on a tap.
*/
FocusScope {
    id: kb

    /*! The text written so far */
    property string text: ""
    /*! Shown, in dark grey, while \l text is empty (the application's hint) */
    property string placeholderText: ""
    /*! TextInput.Password shows dots (the last letter typed for a second) */
    property int echoMode: TextInput.Normal
    /*! Qt.ImhDigitsOnly and Qt.ImhDialableCharactersOnly open the PIN pad,
        Qt.ImhFormattedNumbersOnly the ?123 page */
    property int inputMethodHints: Qt.ImhNone
    /*! A capital at the start of a sentence */
    property bool autoCapitalize: echoMode === TextInput.Normal
                                  && !(inputMethodHints & (Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly | Qt.ImhEmailCharactersOnly))
    /*! The action key's icon when there is text: "send", "done", "search", "go" or "next" */
    property string actionKey: "done"
    /*! Dictation with the watch's recogniser, when it is installed */
    property bool dictationAllowed: echoMode === TextInput.Normal
    /*! Shown while the microphone listens and nothing is heard yet */
    property string listeningText: qsTr("Listening…")
    /*! The strip of word suggestions above the keys */
    property bool suggestionsEnabled: echoMode === TextInput.Normal
        && !(inputMethodHints & (Qt.ImhNoPredictiveText | Qt.ImhSensitiveData | Qt.ImhHiddenText
                                 | Qt.ImhUrlCharactersOnly | Qt.ImhEmailCharactersOnly | Qt.ImhDigitsOnly
                                 | Qt.ImhFormattedNumbersOnly | Qt.ImhDialableCharactersOnly))
    /*! Input stops at this many characters; with no \l placeholderText the hint reads "N characters". -1: no limit */
    property int maximumLength: -1
    /*! The emoji key in the features row; the emoji page sets it (it emits \l emojiRequested) */
    property bool emojiEnabled: false
    /*! The keyboard languages, {code, name}; the space key shows the code of \l language and opens the switcher when there are two or more */
    property var languages: [{ "code": "en", "name": qsTr("English (UK)") }]
    /*! The code of the language in use */
    property string language: languages.length > 0 ? languages[0].code : "en"
    /*! Settings > Input methods > Popup on keypress */
    property bool popupOnKeypress: _popupSetting.value !== false
    /*! The display is held on until this many ms after the last touch (stock: 30 s) */
    property int keepAwakeInterval: 30000
    /*! The cursor, as an index into \l text */
    property int cursor: 0
    /*! 0 the letters, 1 ?123, 2 =\\< */
    property int page: (inputMethodHints & Qt.ImhFormattedNumbersOnly) ? 1 : 0
    /*! 0 off, 1 the next letter, 2 locked */
    property int shift: 0

    /*! The action key: the text is done */
    signal accepted(string text)
    /*! Closed with the cross (or \l dismiss()): nothing is sent */
    signal dismissed()
    /*! The fade out of \l hide() has ended: destroy the keyboard now */
    signal closed()
    /*! The emoji key was tapped */
    signal emojiRequested()
    /*! "Language settings" in the switcher was tapped */
    signal languageSettingsRequested()
    /*! The user picked a language in the switcher */
    signal languageChosen(string code)

    /*! Leaves without accepting (the cross, the back key, a swipe in the preview) */
    function dismiss() {
        cancelDictation()
        dismissed()
    }

    /*!
        Fades the keyboard out as the system's input method window does:
        down by 8 % of its height and to alpha 0 in 150 ms, (0.4, 0, 1, 1);
        \l closed follows (at once with Reduce animations).
    */
    function hide() {
        if (_closing)
            return
        _closing = true
        cancelDictation()
        if (Motion.animationScale === 0) {
            opacity = 0
            closed()
            return
        }
        _openAnim.stop()
        _closeAnim.start()
    }

    // ---- geometry (KeyboardLayout.js) ----
    readonly property real _s: Math.min(width, height)
    readonly property var _m: L.metrics(_s, height)
    readonly property var _pad: L.padMetrics(_m)
    /*! The height of a key row (57.5 px) */
    readonly property real keyHeight: numberPad ? _pad.rowH : _m.rowH
    /*! The width of a letter key of the first row */
    readonly property real keyWidth: L.rowRect(_m, 0).w / 10
    readonly property bool numberPad: (inputMethodHints & (Qt.ImhDigitsOnly | Qt.ImhDialableCharactersOnly)) !== 0
    readonly property bool _password: echoMode === TextInput.Password && !numberPad
    readonly property string _currency: {
        var c = Qt.locale().currencySymbol(Locale.CurrencySymbol)
        return (c.length > 0 && c !== "$" && c !== "¤") ? c : "€"
    }

    // the fixed Gboard palette (WearGboardDefaultTheme, Pixel overlay): not themed
    readonly property QtObject _c: QtObject {
        readonly property color black: "#000000"
        readonly property color label: "#ffffff"
        readonly property color paper: "#fcf7eb"        // colorPrimary: the action key
        readonly property color ink: "#202124"      // gray_900: the action icon
        readonly property color fn: "#32312f"           // colorOnPrimary: function keys, chips, bubble
        readonly property color pressed: "#3d3d3d"      // colorKeyPressedBg
        readonly property color composing: "#e6ff7b"    // colorSecondary
        readonly property color cursor: "#bdc1c6"       // gray_400
        readonly property color hint: "#3c4043"         // gray_800
        readonly property color popup: "#3c474c"        // long press popup
        readonly property color handle: "#3c4043"       // preview handle
        readonly property color numberDone: "#30a0f2"   // colorNumberActionKey
        readonly property color partial: "#9aa0a6"
    }

    // the pill (20 x 6 dp) of the preview handle and its 60 x 24 dp touch area
    readonly property real _handleW: Theme.dp(20)
    readonly property real _handleH: Theme.dp(6)

    // ---- keys ----
    readonly property string _pageLabel: page === 0 ? "?123" : "ABC"
    readonly property int _pageTarget: page === 0 ? 1 : 0
    readonly property var _bodyKeys: numberPad ? L.padKeys(_m) : L.bodyKeys(_m, page, _password, _currency)
    readonly property var _header: numberPad ? { "keys": [], "strip": null }
                                   : L.headerKeys(_m, _headerMode,
                                                  { "emoji": emojiEnabled, "pageLabel": _pageLabel,
                                                    "pageTarget": _pageTarget, "password": _password })
    readonly property var _headerKeys: _header.keys
    readonly property var _allKeys: _headerKeys.concat(_bodyKeys)

    // "features" (emoji, ?123, mic) or "chips"; the chevron switches, new candidates
    // (or none) put it back to automatic
    property int _chevronMode: 0
    readonly property string _headerMode: page !== 0 ? "features"   // ABC must stay in reach
                                          : _chevronMode === 1 ? "features"
                                          : _chevronMode === 2 ? "chips"
                                          : suggestions.length > 0 ? "chips" : "features"
    property bool _hadChips: false
    onSuggestionsChanged: {
        var has = suggestions.length > 0
        if (has !== _hadChips) {
            _hadChips = has
            _chevronMode = 0
        }
    }

    function _keyAt(x, y) {
        for (var i = 0; i < _allKeys.length; i++) {
            var k = _allKeys[i]
            if (x >= k.x && x < k.x + k.w && y >= k.y && y < k.y + k.h)
                return i
        }
        return -1
    }

    function _label(k) {
        if (k.t !== "c")
            return k.c
        return shift > 0 && page === 0 ? k.c.toUpperCase() : k.c
    }

    // ---- editing (at the cursor) ----
    property bool _editing: false
    onTextChanged: {
        if (!_editing)
            cursor = text.length
        else if (cursor > text.length)
            cursor = text.length
    }
    function _setText(t, c) {
        _editing = true
        text = t
        cursor = Math.max(0, Math.min(t.length, c))
        _editing = false
        _cursorOn = true
        _touched()
    }
    function _capitalizeNext() {
        if (!autoCapitalize || shift === 2)
            return
        var t = text.substring(0, cursor)
        shift = (t.length === 0 || /[.!?]\s+$/.test(t) || /\n$/.test(t)) ? 1 : 0
    }
    Component.onCompleted: {
        cursor = text.length
        _capitalizeNext()
        _hadChips = suggestions.length > 0
        if (dictationAllowed)
            dbusDaemon.typedCall("ListActivatableNames", [], function (names) {
                // Nemo.DBus hands a string list over as an array-like
                // sequence, not an Array: look through it by index
                var found = false
                for (var i = 0; names && i < names.length; i++) {
                    if (String(names[i]) === "org.asteroidos.assistant")
                        found = true
                }
                kb._dictationAvailable = found
            })
        _awakeTimer.restart()
        if (Motion.animationScale > 0)
            _openAnim.start()
    }

    /*! Types \a s at the cursor (as much as \l maximumLength allows) */
    function insert(s) {
        if (maximumLength > 0) {
            var room = maximumLength - text.length
            if (room <= 0)
                return
            if (s.length > room)
                s = s.substring(0, room)
        }
        _lastTyped = echoMode === TextInput.Password
        if (_lastTyped)
            maskTimer.restart()
        _setText(text.substring(0, cursor) + s + text.substring(cursor), cursor + s.length)
        if (shift === 1)
            shift = 0
        _capitalizeNext()
    }
    /*! Deletes the character before the cursor */
    function backspace() {
        if (cursor === 0)
            return
        var from = L.stepIndex(text, cursor, -1)
        _lastTyped = false
        _setText(text.substring(0, from) + text.substring(cursor), from)
        _capitalizeNext()
    }
    /*! Moves the cursor by \a n characters (negative: left) */
    function moveCursor(n) {
        var c = cursor
        for (var i = 0; i < Math.abs(n); i++)
            c = L.stepIndex(text, c, n > 0 ? 1 : -1)
        var moved = c !== cursor
        if (moved) {
            cursor = c
            _cursorOn = true
            _lastTyped = false
            _capitalizeNext()
        }
        return moved
    }

    // the action key: Close while there is nothing to send
    function _activate() {
        cancelDictation()
        if (text.length === 0)
            dismissed()
        else
            accepted(text)
    }
    readonly property string _actionIcon: text.length === 0 ? "ios-close"
        : actionKey === "send" ? "ios-send"
        : actionKey === "search" ? "ios-search"
        : actionKey === "go" ? "ios-arrow-round-forward"
        : actionKey === "next" ? "ios-return-right"
        : "ios-checkmark"

    function _press(k) {
        if (!k)
            return
        switch (k.t) {
        case "c":
            insert(_label(k))
            break
        case "space":
            insert(" ")
            break
        case "back":
            backspace()
            break
        case "shift":
            // once: the next letter; twice quickly: locked
            if (shift === 1 && shiftDouble.running)
                shift = 2
            else
                shift = shift === 0 ? 1 : 0
            shiftDouble.restart()
            break
        case "page":
            page = k.p
            break
        case "chevron":
            _chevronMode = _headerMode === "features" ? 2 : 1
            break
        case "emoji":
            emojiRequested()
            break
        case "action":
            _activate()
            break
        case "mic":
            if (!_dictationAvailable)
                break
            if (_dictating)
                assistant.typedCall("Stop", [])
            else
                startDictation()
            break
        }
    }

    Timer { id: shiftDouble; interval: 400 }

    // ---- suggestions (WordPredictor) ----
    WordPredictor { id: predictor }
    // the word being written: the end of the text before the cursor, after
    // its last space or punctuation
    readonly property string _currentWord: {
        var m = /[^\s.,!?;:"()\[\]{}<>@#…]*$/.exec(text.substring(0, cursor))
        return m ? m[0] : ""
    }
    /*! For tests: the suggestions to show instead of the predictor's */
    property var _forcedSuggestions: null
    /*! The suggestions for the word being written, the likeliest first */
    readonly property var suggestions: _forcedSuggestions !== null ? _forcedSuggestions
        : suggestionsEnabled && predictor.available && _currentWord.length > 0
          && _partial.length === 0 && !_dictating
          ? predictor.suggest(_currentWord, 5) : []
    /*! Puts the suggestion in place of the word being written, and a space */
    function applySuggestion(s) {
        if (s.length === 0)
            return
        var start = cursor - _currentWord.length
        var add = s + " "
        if (maximumLength > 0 && text.length - _currentWord.length + add.length > maximumLength)
            return
        _lastTyped = false
        _setText(text.substring(0, start) + add + text.substring(cursor), start + add.length)
        if (shift === 1)
            shift = 0
        _capitalizeNext()
    }
    // the chip under (x, y) of the window, or -1
    function _slotAt(x, y) {
        var s = _header.strip
        if (_headerMode !== "chips" || !s || y < s.y || y >= s.y + s.h || x < s.x || x >= s.x + s.w)
            return -1
        var p = chipRow.mapFromItem(kb, x, y)
        var c = chipRow.childAt(p.x, chipRow.height / 2)
        return c && c.index !== undefined ? c.index : -1
    }

    // ---- password: dots, the last letter for a second, the eye ----
    property bool _lastTyped: false
    property bool _showPassword: false
    Timer { id: maskTimer; interval: 1000; onTriggered: kb._lastTyped = false }
    readonly property string _shownText: {
        if (echoMode !== TextInput.Password || _showPassword)
            return text
        var dots = ""
        for (var i = 0; i < text.length - (_lastTyped ? 1 : 0); i++)
            dots += "•"
        return _lastTyped && text.length > 0 ? dots + text.charAt(text.length - 1) : dots
    }

    // ---- dictation (asteroid-assistant) ----
    property bool _dictationAvailable: false
    property bool _dictating: false
    property int _session: 0
    property string _partial: ""
    property string _note: ""

    DBusInterface {
        id: dbusDaemon
        bus: DBus.SessionBus
        service: "org.freedesktop.DBus"
        path: "/org/freedesktop/DBus"
        iface: "org.freedesktop.DBus"
    }
    DBusInterface {
        id: assistant
        bus: DBus.SessionBus
        service: "org.asteroidos.assistant"
        path: "/org/asteroidos/assistant"
        iface: "org.asteroidos.assistant"
        signalsEnabled: kb._dictating

        // the signals StateChanged, Partial and Result (Nemo.DBus: the
        // name, lower case first). Only this keyboard's session: the one
        // whose "starting" comes while Dictate() has not returned (the
        // daemon emits it first), else the one Dictate() returns. Starting
        // a session ends the one going on with that session's "idle": a
        // Partial or Result of another client's session is not ours.
        function stateChanged(session: int, state: string) {
            if (!kb._dictating)
                return
            if (kb._session === 0 && state === "starting") {
                kb._session = session
            } else if (session === kb._session && state === "idle") {
                // dropped without a Result (the assistant overlay or a
                // voice reply took the microphone): nothing more comes
                kb._dictating = false
                kb._partial = ""
            }
        }
        function partial(session: int, text: string) {
            if (kb._dictating && kb._session !== 0 && session === kb._session)
                kb._partial = text
        }
        function result(session: int, json: string) {
            if (!kb._dictating || kb._session === 0 || session !== kb._session)
                return
            var r = {}
            try { r = JSON.parse(json) } catch (e) { }
            kb._dictating = false
            kb._partial = ""
            if (r.type === "dictation" && r.text) {
                var t = String(r.text)
                kb.insert((kb.cursor > 0 && !/\s$/.test(kb.text.substring(0, kb.cursor)) ? " " : "") + t)
            } else if (r.type === "error") {
                kb._note = r.text ? String(r.text) : ""
                noteTimer.restart()
            }
        }
    }
    Timer { id: noteTimer; interval: 2500; onTriggered: kb._note = "" }

    function startDictation() {
        _partial = ""
        _note = ""
        _session = 0
        _dictating = true
        assistant.typedCall("Dictate", [{ "type": "s", "value": "" }], function (session) {
            if (!kb._dictating)
                return
            if (typeof session === "number" && session > 0) {
                if (kb._session === 0)
                    kb._session = session
            } else if (session === 0) {
                kb._dictating = false
            }
        }, function () { kb._dictating = false })
    }
    function cancelDictation() {
        if (!_dictating)
            return
        _dictating = false
        _partial = ""
        assistant.typedCall("Cancel", [])
    }
    Component.onDestruction: cancelDictation()

    // ---- keep the screen on while typing: 30 s after the last touch or crown turn ----
    function _touched() {
        _awakeTimer.restart()
        _cursorOn = true
    }
    Timer {
        id: _awakeTimer
        interval: kb.keepAwakeInterval
    }
    /*! The display is held on (typing, or listening) */
    readonly property bool _awake: (_awakeTimer.running || _dictating) && !_closing
    DisplayBlanking { id: blanking; preventBlanking: kb._awake }

    // ---- the cursor: blinks 500 ms while the display is on and for 30 s after the last touch ----
    property bool _cursorOn: true
    /*! The display is on (the application is active); the cursor blinks only then */
    property bool displayOn: Qt.application.active
    readonly property bool _blinking: _awake && visible && displayOn
    Timer {
        id: _blink
        interval: 500
        repeat: true
        running: kb._blinking
        onTriggered: kb._cursorOn = !kb._cursorOn
        onRunningChanged: if (!running) kb._cursorOn = true
    }

    // ---- show and hide: the input method window animations ----
    property bool _closing: false
    // fraction of the height the window is moved down: 0.10 -> 0 in, 0 -> 0.08 out
    property real _slide: 0
    transform: Translate { y: kb._slide * kb.height }
    ParallelAnimation {
        id: _openAnim
        NumberAnimation {
            target: kb; property: "_slide"; from: 0.10; to: 0
            duration: Motion.duration(200); easing.type: Easing.OutQuint
        }
        NumberAnimation {
            target: kb; property: "opacity"; from: 0.5; to: 1
            duration: Motion.duration(200); easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: _closeAnim
        NumberAnimation {
            target: kb; property: "_slide"; to: 0.08
            duration: Motion.duration(150)
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 1, 1, 1, 1]
        }
        NumberAnimation {
            target: kb; property: "opacity"; to: 0
            duration: Motion.duration(150)
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 1, 1, 1, 1]
        }
        onFinished: kb.closed()
    }

    // ---- the crown: moves the cursor; scrolls the text in the preview ----
    property ConfigurationValue _popupSetting: ConfigurationValue {
        key: "/org/asteroidos/ux/keyboard-popup"
        defaultValue: true
    }
    property ConfigurationValue _crownFastSetting: ConfigurationValue {
        key: "/org/asteroidos/ux/crown-fast"
        defaultValue: true
    }
    property ConfigurationValue _crownPxSetting: ConfigurationValue {
        key: "/org/asteroidos/ux/rotary-px-per-count"
        defaultValue: 1.75
    }
    property ConfigurationValue _crownInvertSetting: ConfigurationValue {
        key: "/org/asteroidos/ux/rotary-invert"
        defaultValue: false
    }
    // crown scroll px per count, as the lists use: the user's speed
    // (crown-fast) or stock's 1.4976 px (|0.0117| x 64 dp x 2 px/dp)
    // (the raw dconf values: tests replace these instead of writing dconf)
    property var _crownFastValue: _crownFastSetting.value
    property var _crownPxValue: _crownPxSetting.value
    property var _crownInvertValue: _crownInvertSetting.value
    readonly property real crownPxPerCount: _crownFastValue === false ? 1.4976
        : (Number(_crownPxValue) > 0 ? Number(_crownPxValue) : 1.75)
    /*! Crown scroll px per character moved (csy.java: round(scrollPx / 3)) */
    readonly property real crownPxPerChar: 3
    property real _crownAcc: 0
    property real _lastWheel: 0

    function _crown(counts) {
        _touched()
        var forward = _crownInvertValue === true ? counts : -counts
        var px = forward * crownPxPerCount
        if (_f >= 1) {
            // the preview: the crown scrolls the text
            var maxY = Math.max(0, previewFlick.contentHeight - previewFlick.height)
            previewFlick.contentY = Math.max(0, Math.min(maxY, previewFlick.contentY + px))
            return
        }
        if (_f > 0)
            return
        var now = Date.now()
        if (now - _lastWheel > 400)
            _crownAcc = 0   // a new turn
        _lastWheel = now
        _crownAcc += px
        var steps = Math.trunc(_crownAcc / crownPxPerChar)
        if (steps === 0)
            return
        _crownAcc -= steps * crownPxPerChar
        if (moveCursor(steps))
            Haptics.tick()
    }
    WheelHandler {
        id: crownHandler
        orientation: Qt.Vertical
        onWheel: (event) => {
            var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            kb._crown(d / 120)
        }
    }

    // ---- the preview (fold the keyboard away): 0 open ... 1 collapsed ----
    property real _f: 0
    readonly property bool previewOpen: _f >= 1
    readonly property bool _canPreview: !numberPad && !_closing
    function _snapPreview(to) {
        _previewAnim.stop()
        if (Motion.animationScale === 0) {
            _f = to
            return
        }
        _previewAnim.to = to
        _previewAnim.from = _f
        _previewAnim.start()
    }
    /*! Folds the keyboard into the preview, or brings it back */
    function showPreview(on) { _snapPreview(on ? 1 : 0) }
    NumberAnimation {
        id: _previewAnim
        target: kb; property: "_f"
        // 450 ms, gm3 emphasized easing (ctz.java:270-316)
        duration: Motion.duration(450)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: L.emphasizedCurve
    }
    // the two preview circles (52 dp) sit above the collapse bar, 12 dp apart
    readonly property real _circle: Theme.dp(52)
    readonly property real _circleGap: Theme.dp(12)
    readonly property real _circleY: height - _m.margin - Theme.dp(78)
    readonly property real _barY: _circleY + _circle + Theme.dp(6)
    readonly property real _previewTop: Math.round(height * 0.25)
    function _previewHit(x, y) {
        var cx = _m.W / 2
        if (y >= _circleY && y < _circleY + _circle) {
            if (x >= cx - _circleGap / 2 - _circle && x < cx - _circleGap / 2)
                return "keyboard"
            if (x >= cx + _circleGap / 2 && x < cx + _circleGap / 2 + _circle)
                return "action"
        }
        if (y >= _barY - Theme.dp(6) && y < _barY + _handleH + Theme.dp(6) && Math.abs(x - cx) < _handleW)
            return "bar"
        return ""
    }
    function _handleHit(x, y) {
        return text.length > 0 && _canPreview && _f === 0 && y < Theme.dp(24)
               && Math.abs(x - _m.W / 2) < Theme.dp(30)
    }

    // ---- language switcher ----
    property bool _switcherOpen: false
    readonly property bool _multiLanguage: languages.length > 1
    function openLanguageSwitcher() {
        if (_multiLanguage)
            _switcherOpen = true
    }
    readonly property string _languageCode: {
        for (var i = 0; i < languages.length; i++)
            if (languages[i].code === language)
                return String(languages[i].code).toUpperCase()
        return String(language).toUpperCase()
    }

    // the parts, for tests
    readonly property Item _line: line
    readonly property Item _bubble: bubble
    readonly property Item _alternatives: alternatives
    readonly property Item _cursorBar: cursorBar
    readonly property QtObject _blanking: blanking
    readonly property Item _strip: strip
    readonly property Item _previewFlick: previewFlick
    readonly property Item _eye: eye
    readonly property QtObject _openAnimation: _openAnim
    readonly property QtObject _blinkTimer: _blink
    readonly property QtObject _closeAnimation: _closeAnim

    // ---- what is drawn ----
    Rectangle {
        anchors.fill: parent
        color: kb._c.black
    }

    // the one line text field, at the bottom of the text area
    Item {
        id: line
        readonly property real lineH: Math.round(Theme.sp(14) * 1.4)
        readonly property real lineY: (kb.numberPad ? kb._pad.top : kb._m.top) - lineH
        readonly property real pad: L.textPadding(kb._m, lineY)
        readonly property real eyeW: kb._password ? Theme.dp(24) : 0
        readonly property string hint: kb._note.length > 0 ? kb._note
            : kb._dictating ? kb.listeningText
            : kb.placeholderText.length > 0 ? kb.placeholderText
            : kb.maximumLength > 0 ? qsTr("%1 characters").arg(kb.maximumLength) : ""
        // the word being typed (before the cursor) in colour, when the text is plain
        readonly property bool composing: kb.suggestionsEnabled && kb._currentWord.length > 0
                                          && kb.echoMode === TextInput.Normal
        readonly property int cs: composing ? kb.cursor - kb._currentWord.length : kb.cursor
        readonly property string shown: kb._shownText
        readonly property real cursorX: pre.implicitWidth + word.implicitWidth
        // the text slides so that the cursor stays near the middle
        readonly property real scrollX: Math.max(0, cursorX - width / 2)
        x: pad
        y: lineY
        width: kb._m.W - 2 * pad - eyeW
        height: lineH
        clip: true
        opacity: 1 - Math.min(1, kb._f * 3)
        visible: opacity > 0

        Row {
            id: content
            height: parent.height
            // the cursor stays near the middle
            x: -line.scrollX
            Text {
                id: pre
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: line.shown.substring(0, line.cs)
                color: kb._c.label
                font.pixelSize: Math.round(Theme.sp(14))
                font.family: Theme.fontFamily
                font.weight: Font.Medium
            }
            Text {
                id: word
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: line.shown.substring(line.cs, kb.cursor)
                color: kb._c.composing
                font: pre.font
            }
            Text {
                id: post
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: line.shown.substring(kb.cursor)
                color: kb._c.label
                font: pre.font
            }
            // what the recogniser heard so far
            Text {
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: kb._partial.length > 0 ? (line.shown.length > 0 ? " " : "") + kb._partial : ""
                color: kb._c.partial
                font: pre.font
            }
        }
        Text {
            visible: kb.text.length === 0 && kb._partial.length === 0
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: line.hint
            color: kb._c.hint
            font: pre.font
        }
        // the cursor: 1.2 sp wide, 2 sp corners, #bdc1c6
        Rectangle {
            id: cursorBar
            visible: kb._cursorOn && kb._f === 0
            x: content.x + line.cursorX
            y: (parent.height - height) / 2
            width: Math.round(Theme.sp(1.2))
            height: Math.round(Theme.sp(14) * 1.2)
            radius: Math.round(Theme.sp(2))
            color: kb._c.cursor
        }
    }
    // the eye of a password field: shows and hides the text
    Item {
        id: eye
        visible: kb._password && kb._f === 0
        x: kb._m.W - line.pad - width
        y: line.lineY + (line.lineH - height) / 2
        width: Theme.dp(24); height: width
        Icon {
            anchors.centerIn: parent
            width: Theme.dp(24); height: width
            name: kb._showPassword ? "ios-eye-off" : "ios-eye"
            color: kb._c.label
        }
    }

    // the preview: the whole text, wrapped, from 25 % down
    Flickable {
        id: previewFlick
        readonly property real pad: L.textPadding(kb._m, kb._previewTop)
        x: pad
        y: kb._previewTop
        width: kb._m.W - 2 * pad
        height: kb._circleY - Theme.dp(6) - y
        clip: true
        contentWidth: width
        contentHeight: previewText.implicitHeight
        interactive: false
        visible: opacity > 0
        opacity: Math.min(1, kb._f * 3)
        Text {
            id: previewText
            width: previewFlick.width
            wrapMode: Text.Wrap
            // 2 px larger than the one line field
            font.pixelSize: Math.round(Theme.sp(14)) + 2
            font.family: Theme.fontFamily
            font.weight: Font.Medium
            color: kb._c.label
            text: kb.text.length > 0 ? kb._shownText : line.hint
            onTextChanged: previewFlick.contentY = 0
        }
    }

    // the handle: a 20 x 6 dp pill at the top centre while there is text
    Rectangle {
        id: handle
        visible: kb.text.length > 0 && kb._canPreview && kb._f === 0
        x: kb._m.W / 2 - width / 2
        y: Theme.dp(2)
        width: kb._handleW; height: kb._handleH
        radius: Theme.dp(3)
        color: kb._c.handle
    }

    // everything below the text area moves down with the preview drag
    Item {
        id: keyArea
        anchors.fill: parent
        transform: Translate { y: kb._f * kb._m.areaH }
        visible: kb._f < 1

        // the chips of the header
        Item {
            id: strip
            readonly property var rect: kb._header.strip
            visible: kb._headerMode === "chips" && rect !== null
            x: rect ? rect.x : 0
            y: rect ? rect.y : 0
            width: rect ? rect.w : 0
            height: rect ? rect.h : 0
            clip: true
            property real scrollX: 0
            Row {
                id: chipRow
                x: -strip.scrollX
                height: strip.height
                Repeater {
                    model: kb.suggestions
                    delegate: Item {
                        id: chip
                        required property string modelData
                        required property int index
                        readonly property bool down: inputArea.pressedSlot === index
                        // 8 dp side padding, 22 dp at least; insets 1.5 dp sides, 3 dp top, 2 dp bottom
                        width: Math.max(Theme.dp(22), chipLabel.implicitWidth + Theme.dp(16)) + Theme.dp(3)
                        height: chipRow.height
                        Rectangle {
                            x: Theme.dp(1.5)
                            y: Theme.dp(3)
                            width: parent.width - Theme.dp(3)
                            height: parent.height - Theme.dp(5)
                            radius: height / 2
                            color: chip.down ? kb._c.pressed : kb._c.fn
                        }
                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: kb._c.label
                            font.pixelSize: Math.round(Theme.sp(14))
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }
                    }
                }
            }
            // 16 dp fading edges
            Rectangle {
                visible: strip.scrollX > 0
                width: Theme.dp(16); height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: kb._c.black }
                    GradientStop { position: 1; color: "#00000000" }
                }
            }
            Rectangle {
                visible: chipRow.width - strip.scrollX > strip.width + 1
                x: parent.width - width
                width: Theme.dp(16); height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: kb._c.black }
                }
            }
        }

        Repeater {
            model: kb._allKeys
            delegate: Item {
                id: keyItem
                required property var modelData
                required property int index
                readonly property var k: modelData
                readonly property bool down: inputArea.pressedKey === index
                readonly property string kind: k.kind
                readonly property bool letterLike: kind === "letter" || kind === "pad-back" || kind === "pad-done"
                readonly property bool dictatingMic: k.t === "mic" && kb._dictating
                x: k.x; y: k.y; width: k.w; height: k.h
                // the space key is drawn at 80 % (softkey alpha 0xcc)
                opacity: k.t === "space" ? 0.8 : 1

                Rectangle {
                    id: fill
                    x: keyItem.k.vx - keyItem.k.x
                    y: keyItem.k.vy - keyItem.k.y
                    width: keyItem.k.vw
                    height: keyItem.k.vh
                    radius: keyItem.letterLike ? Math.round(Theme.dp(5)) : height / 2
                    visible: keyItem.down || keyItem.kind === "fn" || keyItem.kind === "action"
                    color: keyItem.down ? kb._c.pressed
                         : keyItem.kind === "action" || keyItem.dictatingMic ? kb._c.paper
                         : kb._c.fn
                }
                // a letter, digit, symbol or page label: Title Medium 16 sp, squeezed in X when too wide
                Item {
                    visible: keyLabel.text.length > 0
                    anchors.centerIn: parent
                    width: keyLabel.implicitWidth
                    height: keyLabel.implicitHeight
                    Text {
                        id: keyLabel
                        text: keyItem.k.t === "c" || keyItem.k.t === "page" ? kb._label(keyItem.k) : ""
                        color: kb._c.label
                        font.pixelSize: Math.round(Theme.sp(16))
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }
                    transform: Scale {
                        origin.x: keyLabel.implicitWidth / 2
                        xScale: Math.min(1, Math.max(1, keyItem.k.vw - Theme.dp(4)) / Math.max(1, keyLabel.implicitWidth))
                    }
                }
                Icon {
                    id: keyIcon
                    readonly property string iconName: {
                        switch (keyItem.k.t) {
                        case "back": return "ios-backspace-outline"
                        case "mic": return kb._dictationAvailable ? (kb._dictating ? "ios-mic" : "ios-mic-outline") : "ios-mic-off-outline"
                        case "emoji": return "ios-happy-outline"
                        case "chevron": return kb._headerMode === "features" ? "ios-arrow-forward" : "ios-arrow-back"
                        case "action": return keyItem.kind === "pad-done" ? "ios-checkmark" : kb._actionIcon
                        default: return ""
                        }
                    }
                    visible: iconName !== ""
                    anchors.centerIn: fill
                    width: Math.round(keyItem.k.t === "chevron" ? Theme.dp(20) : Theme.dp(24))
                    height: width
                    name: iconName
                    color: keyItem.kind === "pad-done" ? kb._c.numberDone
                         : keyItem.kind === "action" || keyItem.dictatingMic ? kb._c.ink
                         : kb._c.label
                }
                // shift: outline arrow (off), filled (on), filled with a bar (locked)
                Shape {
                    id: shiftArrow
                    visible: keyItem.k.t === "shift"
                    readonly property real size: Math.round(Theme.dp(24))
                    width: size; height: size
                    x: fill.x + (fill.width - size) / 2
                    y: fill.y + (fill.height - size) / 2
                    ShapePath {
                        strokeColor: kb._c.label
                        strokeWidth: Math.max(1, shiftArrow.size / 12)
                        fillColor: kb.shift > 0 ? kb._c.label : "transparent"
                        joinStyle: ShapePath.RoundJoin
                        scale: Qt.size(shiftArrow.size / 24, shiftArrow.size / 24)
                        startX: 12; startY: 3
                        PathLine { x: 3.5; y: 12 }
                        PathLine { x: 8; y: 12 }
                        PathLine { x: 8; y: kb.shift === 2 ? 17.5 : 20 }
                        PathLine { x: 16; y: kb.shift === 2 ? 17.5 : 20 }
                        PathLine { x: 16; y: 12 }
                        PathLine { x: 20.5; y: 12 }
                        PathLine { x: 12; y: 3 }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: kb.shift === 2 ? kb._c.label : "transparent"
                        scale: Qt.size(shiftArrow.size / 24, shiftArrow.size / 24)
                        startX: 8; startY: 19.5
                        PathLine { x: 16; y: 19.5 }
                        PathLine { x: 16; y: 21.5 }
                        PathLine { x: 8; y: 21.5 }
                        PathLine { x: 8; y: 19.5 }
                    }
                }
                // the space bar glyph (18 dp wide) or, with several languages, the language code
                Item {
                    id: spaceGlyph
                    visible: keyItem.k.t === "space" && !kb._multiLanguage
                    anchors.centerIn: fill
                    width: Theme.dp(18); height: Theme.dp(6)
                    Rectangle { x: 0; y: 0; width: Theme.dp(1.5); height: parent.height; color: kb._c.label }
                    Rectangle { x: parent.width - width; y: 0; width: Theme.dp(1.5); height: parent.height; color: kb._c.label }
                    Rectangle { x: 0; y: parent.height - height; width: parent.width; height: Theme.dp(1.5); color: kb._c.label }
                }
                Text {
                    visible: keyItem.k.t === "space" && kb._multiLanguage
                    anchors.centerIn: fill
                    text: kb._languageCode
                    color: kb._c.label
                    font.pixelSize: Math.round(Theme.sp(16))
                    font.family: Theme.fontFamily
                    font.weight: Font.Medium
                }
            }
        }

        // the key bubble: one, at a fixed place over the middle of the header row
        Rectangle {
            id: bubble
            readonly property var key: inputArea.pressedKey >= 0 ? (kb._allKeys[inputArea.pressedKey] || null) : null
            visible: kb.popupOnKeypress && key !== null && key.t === "c" && !alternatives.visible && !kb.numberPad
            // min 80 x 33 dp, max width 110 dp, padding 8 x 6 dp; bottom 6 dp below the top of the key rows
            width: Math.max(Theme.dp(80), Math.min(Theme.dp(110), bubbleLabel.implicitWidth + Theme.dp(16)))
            height: Math.max(Theme.dp(33), bubbleLabel.font.pixelSize + Theme.dp(12))
            x: Math.round(kb._m.W / 2 - width / 2)
            y: Math.round(kb._m.rowsY + Theme.dp(6) - height)
            radius: Theme.dp(6)
            color: kb._c.fn
            Text {
                id: bubbleLabel
                anchors.centerIn: parent
                text: bubble.key ? kb._label(bubble.key) : ""
                color: kb._c.label
                font.pixelSize: Math.round(Theme.sp(19))
                font.family: Theme.fontFamily
            }
        }

        // the long press popup above the key: up to 5 per row
        Rectangle {
            id: alternatives
            property var items: []
            property int selected: 0
            readonly property real cellW: Theme.dp(23)
            readonly property real cellH: Theme.dp(27)
            readonly property real margin: Theme.dp(1)
            readonly property int cols: Math.min(5, items.length)
            readonly property int rows: Math.ceil(items.length / 5)
            visible: items.length > 0
            width: cols * cellW + 2 * margin
            height: rows * cellH + 2 * margin
            radius: Theme.dp(6)
            color: kb._c.popup

            function open(key) {
                var c = L.popupItems(key.c, kb.shift > 0)
                if (c.length === 0)
                    return false
                selected = 0
                var w = Math.min(5, c.length) * cellW + 2 * margin
                var h = Math.ceil(c.length / 5) * cellH + 2 * margin
                y = Math.round(key.y - h - Theme.dp(2))
                var room = kb._m.u > 0 ? L.chordAt(kb._m, y + h / 2) - 2 * kb._m.u * 4 : kb._m.W
                var left = kb._m.W / 2 - room / 2
                x = Math.round(Math.max(left, Math.min(key.x + key.w / 2 - w / 2, left + room - w)))
                items = c
                return true
            }
            function pick(px, py) {
                var col = Math.floor((px - x - margin) / cellW)
                var row = Math.floor((py - y - margin) / cellH)
                row = Math.max(0, Math.min(rows - 1, row))
                var inRow = Math.min(5, items.length - row * 5)
                col = Math.max(0, Math.min(inRow - 1, col))
                selected = row * 5 + col
            }

            Repeater {
                model: alternatives.items
                delegate: Rectangle {
                    id: altCell
                    required property string modelData
                    required property int index
                    x: alternatives.margin + (index % 5) * alternatives.cellW
                    y: alternatives.margin + Math.floor(index / 5) * alternatives.cellH
                    width: alternatives.cellW
                    height: alternatives.cellH
                    radius: Theme.dp(6)
                    color: index === alternatives.selected ? kb._c.paper : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: altCell.modelData
                        color: altCell.index === alternatives.selected ? kb._c.ink : kb._c.label
                        font.pixelSize: Math.round(Theme.sp(16))
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // the preview's two circles and its collapse bar
    Item {
        id: previewButtons
        anchors.fill: parent
        visible: kb._f > 0.5
        readonly property real fade: L.previewButtonAlpha(kb._f)
        Rectangle {
            id: keyboardCircle
            x: kb._m.W / 2 - kb._circleGap / 2 - width
            y: kb._circleY
            width: kb._circle; height: width
            radius: width / 2
            opacity: previewButtons.fade
            color: inputArea.special === "keyboard" ? kb._c.pressed : kb._c.fn
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: "ios-keypad"
                color: kb._c.label
            }
        }
        Rectangle {
            id: actionCircle
            x: kb._m.W / 2 + kb._circleGap / 2
            y: kb._circleY
            width: kb._circle; height: width
            radius: width / 2
            opacity: previewButtons.fade
            color: inputArea.special === "action" ? kb._c.pressed : kb._c.paper
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: kb._actionIcon
                color: kb._c.ink
            }
        }
        Rectangle {
            id: collapseBar
            x: kb._m.W / 2 - width / 2
            y: kb._barY
            width: kb._handleW; height: kb._handleH
            radius: Theme.dp(3)
            opacity: previewButtons.fade
            color: kb._c.handle
        }
    }

    // One area takes every touch: keys (slide to another before lifting),
    // long presses, the drag that folds the keyboard into the preview and the
    // swipes. preventStealing: no back swipe, panel swipe or app dismissal
    // takes a touch from the keyboard.
    MouseArea {
        id: inputArea
        anchors.fill: parent
        enabled: !kb._switcherOpen && !kb._closing
        preventStealing: true
        property bool blocksBackSwipe: true
        property int pressedKey: -1
        property int pressedSlot: -1
        property string special: ""
        property real startX: 0
        property real startY: 0
        property real startScroll: 0
        property bool gesture: false
        property bool repeating: false
        property bool collapsing: false
        property bool scrolling: false
        readonly property real slop: Theme.dp(8)

        // a right swipe leaves only the preview and the PIN pad
        readonly property bool swipeRightDismisses: kb.numberPad || kb._f >= 1

        onPressed: (mouse) => {
            kb._touched()
            startX = mouse.x
            startY = mouse.y
            gesture = false
            repeating = false
            collapsing = false
            scrolling = false
            startScroll = strip.scrollX
            pressedKey = -1
            pressedSlot = -1
            special = ""
            if (kb._f >= 1) {
                special = kb._previewHit(mouse.x, mouse.y)
                return
            }
            if (kb._handleHit(mouse.x, mouse.y)) {
                special = "handle"
                return
            }
            if (kb._password && kb._f === 0 && eye.visible
                    && mouse.x >= eye.x - Theme.dp(12) && mouse.y >= eye.y - Theme.dp(12)
                    && mouse.y < eye.y + eye.height + Theme.dp(12) && mouse.x < kb._m.W) {
                special = "eye"
                return
            }
            pressedKey = kb._keyAt(mouse.x, mouse.y)
            if (pressedKey >= 0) {
                Haptics.keyboardTap()
                longPress.restart()
            } else {
                pressedSlot = kb._slotAt(mouse.x, mouse.y)
                if (pressedSlot >= 0)
                    Haptics.click()
            }
        }
        onPositionChanged: (mouse) => {
            if (gesture)
                return
            var dx = mouse.x - startX
            var dy = mouse.y - startY
            // a right swipe: the preview and the PIN pad only
            if (swipeRightDismisses && !alternatives.visible
                    && dx > kb._s * 0.25 && Math.abs(dy) < dx * 0.6) {
                gesture = true
                longPress.stop()
                repeat.stop()
                pressedKey = -1
                pressedSlot = -1
                special = ""
                kb.dismiss()
                return
            }
            // a drag down from the text area or the header folds the keyboard away
            if (collapsing) {
                _previewAnim.stop()
                kb._f = Math.max(0, Math.min(1, dy / kb._m.areaH))
                return
            }
            if (kb._canPreview && kb.text.length > 0 && kb._f === 0 && !alternatives.visible && !repeating
                    && startY < kb._m.rowsY && dy > slop && dy > Math.abs(dx)) {
                collapsing = true
                longPress.stop()
                pressedKey = -1
                pressedSlot = -1
                special = ""
                kb._f = Math.max(0, Math.min(1, dy / kb._m.areaH))
                return
            }
            if (special !== "")
                return
            if (alternatives.visible) {
                alternatives.pick(mouse.x, mouse.y)
                return
            }
            if (repeating)
                return
            // the chips scroll sideways
            if (pressedSlot >= 0 || scrolling) {
                if (scrolling || Math.abs(dx) > slop) {
                    scrolling = true
                    var maxScroll = Math.max(0, chipRow.width - strip.width)
                    strip.scrollX = Math.max(0, Math.min(maxScroll, startScroll - dx))
                }
                return
            }
            var k = kb._keyAt(mouse.x, mouse.y)
            if (k !== pressedKey) {
                pressedKey = k
                if (k >= 0)
                    longPress.restart()
                else
                    longPress.stop()
            }
        }
        onReleased: (mouse) => {
            longPress.stop()
            repeat.stop()
            var sp = special
            if (collapsing) {
                // on to the nearer end
                kb._snapPreview(kb._f > 0.5 ? 1 : 0)
            } else if (sp !== "") {
                if (sp === "handle" && kb._handleHit(mouse.x, mouse.y))
                    kb._snapPreview(1)
                else if (kb._f >= 1 && kb._previewHit(mouse.x, mouse.y) === sp) {
                    if (sp === "keyboard" || sp === "bar")
                        kb._snapPreview(0)
                    else if (sp === "action")
                        kb._activate()
                } else if (sp === "eye") {
                    kb._showPassword = !kb._showPassword
                }
            } else if (alternatives.visible) {
                var it = alternatives.items[alternatives.selected]
                alternatives.items = []
                kb.insert(it)
            } else if (pressedKey >= 0 && !gesture && !repeating) {
                kb._press(kb._allKeys[pressedKey])
            } else if (pressedSlot >= 0 && !gesture && !scrolling && kb._slotAt(mouse.x, mouse.y) === pressedSlot) {
                kb.applySuggestion(kb.suggestions[pressedSlot])
            }
            pressedKey = -1
            pressedSlot = -1
            special = ""
            repeating = false
            collapsing = false
            scrolling = false
        }
        onCanceled: {
            longPress.stop()
            repeat.stop()
            pressedSlot = -1
            special = ""
            alternatives.items = []
            pressedKey = -1
            if (collapsing)
                kb._snapPreview(kb._f > 0.5 ? 1 : 0)
            collapsing = false
        }

        Timer {
            id: longPress
            // Gboard's long press delay (pref_def_value_key_long_press_delay)
            interval: 300
            onTriggered: {
                var k = inputArea.pressedKey >= 0 ? kb._allKeys[inputArea.pressedKey] : null
                if (!k)
                    return
                if (k.t === "back") {
                    inputArea.repeating = true
                    kb.backspace()
                    repeat.start()
                } else if (k.t === "c") {
                    alternatives.open(k)
                } else if (k.t === "space" && kb._multiLanguage) {
                    inputArea.pressedKey = -1
                    kb.openLanguageSwitcher()
                }
            }
        }
        Timer {
            id: repeat
            interval: 70
            repeat: true
            onTriggered: kb.backspace()
        }
    }

    // ---- the language switcher (long press on space with more than one language) ----
    Rectangle {
        id: switcher
        anchors.fill: parent
        visible: kb._switcherOpen
        color: kb._c.black
        // swallow touches
        MouseArea { anchors.fill: parent; preventStealing: true }
        Flickable {
            anchors.fill: parent
            contentHeight: switcherColumn.height + Theme.dp(24)
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Column {
                id: switcherColumn
                // as wide as the circle is at the first row
                width: Math.round(L.chordAt(kb._m, Theme.dp(42)) - Theme.dp(10))
                x: Math.round((kb._m.W - width) / 2)
                y: Theme.dp(14)
                spacing: Theme.dp(4)
                Row {
                    spacing: Theme.dp(4)
                    height: Theme.dp(24)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Icon {
                        width: Theme.dp(20); height: width
                        anchors.verticalCenter: parent.verticalCenter
                        name: "ios-globe-outline"
                        color: Theme.color.onSurface
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Change Language")
                        color: Theme.color.onSurface
                        font.pixelSize: Math.round(Theme.type.titleMedium.pixelSize)
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }
                }
                Repeater {
                    model: kb.languages
                    delegate: Rectangle {
                        id: langRow
                        required property var modelData
                        readonly property bool selected: modelData.code === kb.language
                        width: switcherColumn.width
                        height: Theme.dp(52)
                        radius: height / 2
                        color: selected ? Theme.color.secondaryContainer : Theme.color.surfaceContainer
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.dp(16)
                            width: parent.width - Theme.dp(56)
                            elide: Text.ElideRight
                            text: langRow.modelData.name
                            color: langRow.selected ? Theme.color.onSecondaryContainer : Theme.color.onSurface
                            font.pixelSize: Math.round(Theme.type.labelMedium.pixelSize)
                            font.family: Theme.fontFamily
                            font.weight: Font.Medium
                        }
                        Icon {
                            visible: langRow.selected
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width - width - Theme.dp(14)
                            width: Theme.dp(24); height: width
                            name: "ios-checkmark"
                            color: Theme.color.onSecondaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                kb.language = langRow.modelData.code
                                kb.languageChosen(langRow.modelData.code)
                                kb._switcherOpen = false
                            }
                        }
                    }
                }
                Rectangle {
                    width: switcherColumn.width
                    height: Theme.dp(48)
                    radius: height / 2
                    color: "transparent"
                    border.width: Theme.dp(1)
                    border.color: Theme.color.outlineVariant
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Language settings")
                        color: Theme.color.primary
                        font.pixelSize: Math.round(Theme.type.labelMedium.pixelSize)
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: kb.languageSettingsRequested()
                    }
                }
            }
        }
    }

    Keys.onBackPressed: {
        if (_switcherOpen)
            _switcherOpen = false
        else
            kb.dismiss()
    }
}
