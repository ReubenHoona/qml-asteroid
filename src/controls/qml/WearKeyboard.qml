/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import Nemo.DBus
import org.asteroid.controls

/*!
    \qmltype WearKeyboard
    \inqmlmodule org.asteroid.controls

    \brief The full screen keyboard of a round watch, as Gboard for Wear OS.

    The text being written sits at the top of the screen, inside the circle
    (it wraps and keeps its end in view); below it the QWERTY rows, each as
    wide as the circle allows at its height and all with keys of the same
    size (about 35 x 45 px on a 384 px watch); a bottom row with ?123, the
    microphone (or a comma), space, full stop and the action key (Send or
    Done). Shift and backspace frame the third row, as on a phone.

    Above the keys, Gboard's strip: three suggestions for the word being
    written (WordPredictor: completions, and corrections when it is no
    word), the likeliest in the middle; a tap puts it in place of the word,
    with a space. Not for passwords, numbers or addresses
    (\l suggestionsEnabled).

    A press shows the key enlarged above the finger and clicks the
    vibrator (ui_click); the finger can slide to another key before it lifts.
    A long press on a letter offers its accents (and on the top row its
    digit), on the full stop more punctuation, on backspace repeated
    deletion. ?123 and =\\< open two pages of digits and symbols.

    A swipe down, or a swipe right starting on the text or left of the
    keys, dismisses the keyboard (\l dismissed); the action key emits
    \l accepted. The keyboard keeps its touches to itself (no back swipe,
    panel swipe or app dismissal takes them).

    The microphone dictates with the watch's own recogniser
    (asteroid-assistant's Dictate, D-Bus org.asteroidos.assistant) and
    shows only when that service is installed.

    Nothing animates: the keyboard draws a frame when something changes and
    none at rest.

    \qml
    WearKeyboard {
        anchors.fill: parent
        placeholderText: "Your reply"
        actionKey: "send"
        onAccepted: (text) => send(text)
        onDismissed: close()
    }
    \endqml

    \l TextField and \l TextArea open it over the whole window on a tap.
*/
FocusScope {
    id: kb

    /*! The text written so far */
    property string text: ""
    /*! Shown, greyed, while \l text is empty */
    property string placeholderText: ""
    /*! TextInput.Password shows dots (the last letter typed for a second) */
    property int echoMode: TextInput.Normal
    /*! Qt.ImhDigitsOnly and the other number hints open the digits page */
    property int inputMethodHints: Qt.ImhNone
    /*! A capital at the start of a sentence */
    property bool autoCapitalize: echoMode === TextInput.Normal
                                  && !(inputMethodHints & (Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly | Qt.ImhEmailCharactersOnly))
    /*! "send" (an arrow, only with some text) or "done" (a tick) */
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

    /*! The action key: the text is done */
    signal accepted(string text)
    /*! Swiped away (or \l dismiss()): nothing is sent */
    signal dismissed()

    /*! Leaves without accepting (the crown, a swipe) */
    function dismiss() {
        cancelDictation()
        dismissed()
    }

    // ---- geometry: everything inside the circle of the screen ----
    readonly property real _s: Math.min(width, height)
    readonly property real _r: _s / 2
    readonly property real _cx: width / 2
    readonly property real _cy: height / 2
    readonly property real keyHeight: Math.round(_s * 0.117)
    readonly property real _gap: Math.max(2, Math.round(_s * 0.006))
    readonly property real _rowsTop: Math.round(_cy - _r + _s * 0.325)
    readonly property real _margin: _s * 0.01
    // the strip of suggestions, right above the keys
    readonly property real _stripHeight: Math.round(_s * 0.08)
    readonly property real _stripY: _rowsTop - _stripHeight - _gap
    // weights of the letter rows: they set the size of every key
    readonly property var _letterWeights: [10, 9, 10, 8.5]

    function _chord(y) {
        var d = y - _cy
        return d * d >= _r * _r ? 0 : 2 * Math.sqrt(_r * _r - d * d)
    }
    function _rowY(i) { return _rowsTop + i * (keyHeight + _gap) }
    // what a row can use: the chord at its narrower edge
    function _rowRoom(i) {
        var t = _rowY(i)
        return Math.min(_chord(t), _chord(t + keyHeight)) - 2 * _margin
    }
    /*! The width of a key (one unit) */
    readonly property real keyWidth: {
        var u = _s * 0.115
        for (var i = 0; i < _letterWeights.length; i++)
            u = Math.min(u, _rowRoom(i) / _letterWeights[i])
        return Math.floor(u)
    }

    // ---- pages ----
    // a key: t type (c char, shift, back, page, space, action, mic), c the
    // character or label, w weight, p the page a page key opens
    function _chars(s) {
        var keys = []
        for (var i = 0; i < s.length; i++)
            keys.push({ t: "c", c: s.charAt(i), w: 1 })
        return keys
    }
    readonly property bool _micShown: _dictationAvailable && dictationAllowed
    function _bottomRow(pageKey, pageLabel) {
        return [{ t: "page", c: pageLabel, p: pageKey, w: 1.5 },
                _micShown ? { t: "mic", c: "", w: 1 } : { t: "c", c: ",", w: 1 },
                { t: "space", c: " ", w: 3.5 },
                { t: "c", c: ".", w: 1 },
                { t: "action", c: "", w: 1.5 }]
    }
    readonly property var _pages: [
        [ _chars("qwertyuiop"),
          _chars("asdfghjkl"),
          [{ t: "shift", c: "", w: 1.5 }].concat(_chars("zxcvbnm"), [{ t: "back", c: "", w: 1.5 }]),
          _bottomRow(1, "?123") ],
        [ _chars("1234567890"),
          _chars("@#£_&-+()/"),
          [{ t: "page", c: "=\\<", p: 2, w: 1.5 }].concat(_chars("*\"':;!?"), [{ t: "back", c: "", w: 1.5 }]),
          _bottomRow(0, "ABC") ],
        [ _chars("~`|•√π÷×¶∆"),
          _chars("€$¥^°={}\\%"),
          [{ t: "page", c: "?123", p: 1, w: 1.5 }].concat(_chars("©®[]<>✓"), [{ t: "back", c: "", w: 1.5 }]),
          _bottomRow(0, "ABC") ]
    ]
    // long press: accents (top row: its digit first), more punctuation
    readonly property var _alternatives: ({
        "q": "1", "w": "2", "e": "3èéêëēęė", "r": "4", "t": "5", "y": "6ÿ", "u": "7ûüùúū",
        "i": "8îïíīįì", "o": "9ôöòóœøōõ", "p": "0", "a": "àáâäæãåā", "s": "ßśš",
        "l": "ł", "z": "žźż", "c": "çćč", "n": "ñń", ".": ",?!'\"-:;@",
        "0": "°", "-": "–—", "/": "\\", "?": "¿", "!": "¡", "£": "€$¥"
    })

    property int page: (inputMethodHints & (Qt.ImhDigitsOnly | Qt.ImhFormattedNumbersOnly | Qt.ImhDialableCharactersOnly)) ? 1 : 0
    // 0 off, 1 the next letter, 2 locked
    property int shift: 0

    // the keys of the page with their places
    readonly property var _keys: {
        var rows = _pages[page]
        var list = []
        for (var i = 0; i < rows.length; i++) {
            var weight = 0
            for (var k = 0; k < rows[i].length; k++)
                weight += rows[i][k].w
            var x = Math.round(_cx - weight * keyWidth / 2)
            for (k = 0; k < rows[i].length; k++) {
                var key = rows[i][k]
                var w = Math.round(key.w * keyWidth)
                list.push({ t: key.t, c: key.c, p: key.p, x: x, y: _rowY(i), w: w, h: keyHeight, row: i })
                x += w
            }
        }
        return list
    }

    function _keyAt(x, y) {
        for (var i = 0; i < _keys.length; i++) {
            var k = _keys[i]
            if (x >= k.x && x < k.x + k.w && y >= k.y - _gap / 2 && y < k.y + k.h + _gap / 2)
                return i
        }
        return -1
    }

    function _label(k) {
        if (k.t !== "c")
            return k.c
        return shift > 0 ? k.c.toUpperCase() : k.c
    }

    // ---- editing ----
    function _capitalizeNext() {
        if (!autoCapitalize || shift === 2)
            return
        var t = text
        shift = (t.length === 0 || /[.!?]\s+$/.test(t) || /\n$/.test(t)) ? 1 : 0
    }
    Component.onCompleted: {
        _capitalizeNext()
        if (dictationAllowed)
            dbusDaemon.typedCall("ListActivatableNames", [], function (names) {
                kb._dictationAvailable = Array.isArray(names) && names.indexOf("org.asteroidos.assistant") >= 0
            })
    }

    function insert(s) {
        text = text + s
        _lastTyped = echoMode === TextInput.Password
        if (_lastTyped)
            maskTimer.restart()
        if (shift === 1)
            shift = 0
        _capitalizeNext()
    }
    function backspace() {
        if (text.length === 0)
            return
        var n = 1
        var last = text.charCodeAt(text.length - 1)
        if (last >= 0xDC00 && last <= 0xDFFF && text.length > 1)
            n = 2   // a surrogate pair
        text = text.substring(0, text.length - n)
        _lastTyped = false
        _capitalizeNext()
    }

    function _press(k) {
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
        case "action":
            if (actionKey !== "send" || text.trim().length > 0) {
                cancelDictation()
                accepted(text)
            }
            break
        case "mic":
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
    // the word being written: the end of the text after its last space or
    // punctuation
    readonly property string _currentWord: {
        var m = /[^\s.,!?;:"()\[\]{}<>@#\u2026]*$/.exec(text)
        return m ? m[0] : ""
    }
    /*! The suggestions for the word being written, the likeliest first */
    readonly property var suggestions: suggestionsEnabled && predictor.available && _currentWord.length > 0
                                       && _partial.length === 0 && !_dictating
                                       ? predictor.suggest(_currentWord, 3) : []
    // the strip's slots, left to right: the second, the first, the third
    readonly property var _slots: [suggestions.length > 1 ? suggestions[1] : "",
                                   suggestions.length > 0 ? suggestions[0] : "",
                                   suggestions.length > 2 ? suggestions[2] : ""]
    /*! Puts the suggestion in place of the word being written, and a space */
    function applySuggestion(s) {
        if (s.length === 0)
            return
        text = text.substring(0, text.length - _currentWord.length) + s + " "
        _lastTyped = false
        if (shift === 1)
            shift = 0
        _capitalizeNext()
    }
    function _slotAt(x, y) {
        if (!suggestionsEnabled || y < _stripY || y >= _stripY + _stripHeight || suggestions.length === 0)
            return -1
        var room = _chord(_stripY + _stripHeight / 2) - 2 * _margin
        var left = _cx - room / 2
        var i = Math.floor((x - left) / (room / 3))
        return i >= 0 && i < 3 && _slots[i].length > 0 ? i : -1
    }

    // ---- password: dots, the last letter for a second ----
    property bool _lastTyped: false
    Timer { id: maskTimer; interval: 1000; onTriggered: kb._lastTyped = false }
    readonly property string _shownText: {
        if (echoMode !== TextInput.Password)
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

        // the signals Partial and Result (Nemo.DBus: the name, lower case first)
        function partial(session, text) {
            if (kb._dictating && (kb._session === 0 || session === kb._session))
                kb._partial = text
        }
        function result(session, json) {
            if (!kb._dictating || (kb._session !== 0 && session !== kb._session))
                return
            var r = {}
            try { r = JSON.parse(json) } catch (e) { }
            kb._dictating = false
            kb._partial = ""
            if (r.type === "dictation" && r.text) {
                var t = String(r.text)
                kb.insert((kb.text.length > 0 && !/\s$/.test(kb.text) ? " " : "") + t)
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
            if (typeof session === "number" && session > 0)
                kb._session = session
            else if (session === 0)
                kb._dictating = false
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

    // ---- what is drawn ----
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // the text, its end in view
    Item {
        id: textArea
        width: Math.round(kb._s * 0.64)
        x: Math.round(kb._cx - width / 2)
        y: Math.round(kb._cy - kb._r + kb._s * (kb.suggestionsEnabled ? 0.06 : 0.075))
        height: (kb.suggestionsEnabled ? kb._stripY - Math.round(kb._s * 0.01) : kb._rowsTop - Math.round(kb._s * 0.03)) - y
        clip: true

        TextEdit {
            id: shown
            visible: kb._partial.length === 0
            width: parent.width
            anchors.bottom: parent.bottom
            readOnly: true
            activeFocusOnPress: false
            cursorVisible: false
            selectByMouse: false
            wrapMode: TextEdit.Wrap
            horizontalAlignment: TextEdit.AlignHCenter
            color: "#ffffff"
            font.pixelSize: Math.round(kb._s * 0.06)
            text: kb._shownText
        }
        // while dictating: the text and, greyed, what the recogniser heard so far
        Text {
            visible: kb._partial.length > 0
            width: parent.width
            anchors.bottom: parent.bottom
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.StyledText
            color: "#ffffff"
            font.pixelSize: shown.font.pixelSize
            function escaped(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
            text: escaped(kb._shownText) + (kb._shownText.length > 0 ? " " : "")
                  + "<font color=\"#9aa0a6\">" + escaped(kb._partial) + "</font>"
        }
        // a still cursor after the last letter (no blinking: no frames)
        Rectangle {
            readonly property rect at: shown.positionToRectangle(shown.length)
            visible: shown.visible && kb.text.length > 0
            x: at.x
            y: shown.y + at.y + at.height * 0.1
            width: Math.max(2, Math.round(kb._s * 0.005))
            height: at.height * 0.8
            color: "#a8c7fa"
        }
        Text {
            visible: kb.text.length === 0 && kb._partial.length === 0
            width: parent.width
            anchors.bottom: parent.bottom
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: "#80868b"
            font.pixelSize: shown.font.pixelSize
            text: kb._note.length > 0 ? kb._note : kb._dictating ? kb.listeningText : kb.placeholderText
        }
    }

    // the strip: three suggestions, the likeliest in the middle
    Item {
        id: strip
        visible: kb.suggestionsEnabled
        readonly property real room: kb._chord(kb._stripY + kb._stripHeight / 2) - 2 * kb._margin
        x: Math.round(kb._cx - room / 2)
        y: kb._stripY
        width: Math.round(room)
        height: kb._stripHeight

        Repeater {
            model: 3
            delegate: Item {
                id: slot
                required property int index
                x: Math.round(index * strip.width / 3)
                width: Math.round(strip.width / 3)
                height: strip.height
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: kb._gap / 2
                    radius: height / 2
                    color: "#3c4043"
                    visible: inputArea.pressedSlot === slot.index
                }
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: kb._gap * 2
                    anchors.rightMargin: kb._gap * 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: kb._slots[slot.index]
                    color: "#ffffff"
                    font.pixelSize: Math.round(kb._s * 0.05)
                    font.styleName: slot.index === 1 ? "Medium" : "Regular"
                }
                // a line between two suggestions
                Rectangle {
                    visible: slot.index > 0 && kb._slots[slot.index].length > 0 && kb._slots[slot.index - 1].length > 0
                    width: 1
                    height: parent.height * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#5f6368"
                }
            }
        }
    }

    Repeater {
        model: kb._keys
        delegate: Item {
            id: keyItem
            required property var modelData
            required property int index
            readonly property bool down: inputArea.pressedKey === index
            readonly property bool special: modelData.t === "shift" || modelData.t === "back" || modelData.t === "page"
                                            || modelData.t === "mic"
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            Rectangle {
                anchors.fill: parent
                anchors.margins: kb._gap / 2
                radius: Math.round(Math.min(width, height) * 0.25)
                color: keyItem.modelData.t === "action" ? (keyItem.down ? "#d3e3fd" : "#a8c7fa")
                     : keyItem.modelData.t === "mic" && kb._dictating ? "#f28b82"
                     : keyItem.modelData.t === "shift" && kb.shift > 0 ? (keyItem.down ? "#d3e3fd" : "#a8c7fa")
                     : keyItem.down ? "#5f6368"
                     : keyItem.special ? "#3c4043" : "#2d2e30"
                opacity: keyItem.modelData.t === "action" && kb.actionKey === "send" && kb.text.trim().length === 0 ? 0.4 : 1
            }
            Text {
                anchors.centerIn: parent
                visible: keyItem.modelData.c.length > 0 && keyItem.modelData.t !== "space"
                text: kb._label(keyItem.modelData)
                color: "#ffffff"
                font.pixelSize: keyItem.modelData.t === "page" ? Math.round(kb._s * 0.042) : Math.round(kb._s * 0.058)
                font.styleName: keyItem.modelData.t === "page" ? "SemiCondensed Medium" : "Regular"
            }
            // the digit of a top row letter, small, as Gboard hints it
            Text {
                readonly property string hint: kb.page === 0 && keyItem.modelData.row === 0 && keyItem.modelData.t === "c"
                                               ? (kb._alternatives[keyItem.modelData.c] || "").charAt(0) : ""
                visible: hint.length > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Math.round(kb._s * 0.008)
                anchors.rightMargin: Math.round(kb._s * 0.012)
                text: hint
                color: "#9aa0a6"
                font.pixelSize: Math.round(kb._s * 0.026)
            }
            Icon {
                visible: name !== ""
                anchors.centerIn: parent
                // the tick's drawing is smaller in its square than the others
                width: Math.round(Math.min(parent.width, parent.height) * (name === "ios-checkmark" ? 0.8 : 0.55))
                height: width
                color: keyItem.modelData.t === "action" || (keyItem.modelData.t === "shift" && kb.shift > 0) ? "#062e6f" : "#ffffff"
                name: keyItem.modelData.t === "back" ? "ios-backspace-outline"
                    : keyItem.modelData.t === "shift" ? "ios-arrow-up"
                    : keyItem.modelData.t === "mic" ? (kb._dictating ? "ios-mic" : "ios-mic-outline")
                    : keyItem.modelData.t === "action" ? (kb.actionKey === "send" ? "ios-send" : "ios-checkmark")
                    : ""
            }
            // caps lock: a line under the arrow
            Rectangle {
                visible: keyItem.modelData.t === "shift" && kb.shift === 2
                width: parent.width * 0.3
                height: Math.max(2, Math.round(kb._s * 0.006))
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.18
                color: "#062e6f"
            }
        }
    }

    // the key under the finger, enlarged above it
    Rectangle {
        id: preview
        readonly property var key: inputArea.pressedKey >= 0 ? kb._keys[inputArea.pressedKey] : null
        visible: key !== null && key.t === "c" && !alternatives.visible
        width: key ? Math.round(key.w * 1.4) : 0
        height: Math.round(kb.keyHeight * 1.3)
        x: key ? Math.round(key.x + key.w / 2 - width / 2) : 0
        y: key ? Math.round(key.y - height + kb.keyHeight * 0.1) : 0
        radius: Math.round(width * 0.25)
        color: "#5f6368"
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -parent.height * 0.05
            text: preview.key ? kb._label(preview.key) : ""
            color: "#ffffff"
            font.pixelSize: Math.round(kb._s * 0.085)
        }
    }

    // the accents of a long pressed key
    Rectangle {
        id: alternatives
        property string chars: ""
        property int selected: 0
        property real cell: kb.keyWidth
        visible: chars.length > 0
        width: chars.length * cell + kb._gap * 2
        height: Math.round(kb.keyHeight * 1.1)
        radius: Math.round(height * 0.2)
        color: "#3c4043"
        border.color: "#5f6368"
        border.width: 1

        function open(key) {
            var c = kb._alternatives[key.c] || ""
            if (kb.shift > 0)   // one letter each ("ß" stays)
                c = c.split("").map(function (ch) { var u = ch.toUpperCase(); return u.length === 1 ? u : ch }).join("")
            selected = 0
            y = Math.round(key.y - height - kb._gap)
            var room = kb._chord(y + height / 2) - 2 * kb._margin
            var w = c.length * cell + kb._gap * 2
            var left = kb._cx - room / 2
            x = Math.round(Math.max(left, Math.min(key.x + key.w / 2 - cell / 2 - kb._gap, left + room - w)))
            chars = c
        }
        function pick(px) {
            var i = Math.floor((px - x - kb._gap) / cell)
            selected = Math.max(0, Math.min(chars.length - 1, i))
        }

        Repeater {
            model: alternatives.chars.length
            delegate: Rectangle {
                required property int index
                x: kb._gap + index * alternatives.cell
                y: kb._gap
                width: alternatives.cell
                height: alternatives.height - 2 * kb._gap
                radius: Math.round(width * 0.25)
                color: index === alternatives.selected ? "#a8c7fa" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: alternatives.chars.charAt(parent.index)
                    color: parent.index === alternatives.selected ? "#062e6f" : "#ffffff"
                    font.pixelSize: Math.round(kb._s * 0.058)
                }
            }
        }
    }

    // One area takes every touch: keys (slide to another before lifting),
    // long presses, and the swipes that dismiss. preventStealing: no back
    // swipe, panel swipe or app dismissal takes a touch from the keyboard.
    MouseArea {
        id: inputArea
        anchors.fill: parent
        preventStealing: true
        property bool blocksBackSwipe: true
        property int pressedKey: -1
        property int pressedSlot: -1
        property real startX: 0
        property real startY: 0
        property bool gesture: false
        property bool repeating: false

        onPressed: (mouse) => {
            startX = mouse.x
            startY = mouse.y
            gesture = false
            repeating = false
            pressedKey = kb._keyAt(mouse.x, mouse.y)
            pressedSlot = pressedKey < 0 ? kb._slotAt(mouse.x, mouse.y) : -1
            if (pressedKey >= 0) {
                Haptics.click()
                longPress.restart()
            } else if (pressedSlot >= 0) {
                Haptics.click()
            }
        }
        onPositionChanged: (mouse) => {
            if (gesture)
                return
            var dx = mouse.x - startX
            var dy = mouse.y - startY
            // a swipe down, or right from the text or the left edge
            var fromEdge = startY < kb._rowsTop || startX < kb._cx - 5 * kb.keyWidth
            if (!alternatives.visible && !repeating
                    && ((dy > kb.keyHeight * 1.3 && Math.abs(dx) < dy * 0.6)
                        || (fromEdge && dx > kb._s * 0.25 && Math.abs(dy) < dx * 0.6))) {
                gesture = true
                longPress.stop()
                repeat.stop()
                pressedKey = -1
                kb.dismiss()
                return
            }
            if (alternatives.visible) {
                alternatives.pick(mouse.x)
                return
            }
            if (repeating)
                return
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
            if (alternatives.visible) {
                kb.insert(alternatives.chars.charAt(alternatives.selected))
                alternatives.chars = ""
            } else if (pressedKey >= 0 && !gesture && !repeating) {
                kb._press(kb._keys[pressedKey])
            } else if (pressedSlot >= 0 && !gesture && kb._slotAt(mouse.x, mouse.y) === pressedSlot) {
                kb.applySuggestion(kb._slots[pressedSlot])
            }
            pressedKey = -1
            pressedSlot = -1
            repeating = false
        }
        onCanceled: {
            longPress.stop()
            repeat.stop()
            pressedSlot = -1
            alternatives.chars = ""
            pressedKey = -1
        }

        Timer {
            id: longPress
            interval: 450
            onTriggered: {
                var k = inputArea.pressedKey >= 0 ? kb._keys[inputArea.pressedKey] : null
                if (!k)
                    return
                if (k.t === "back") {
                    inputArea.repeating = true
                    kb.backspace()
                    repeat.start()
                } else if (k.t === "c" && kb._alternatives[k.c]) {
                    Haptics.longPress()
                    alternatives.open(k)
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

    Keys.onBackPressed: kb.dismiss()
}
