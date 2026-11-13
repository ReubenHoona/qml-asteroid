/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import Nemo.DBus
import Nemo.KeepAlive
import org.asteroid.controls

/*!
    \qmltype VoiceInput
    \inqmlmodule org.asteroid.controls

    \brief The voice dictation screen of a round watch, as Gboard for Wear OS
    (stock CP3A): one screen for the keyboard's microphone and for a reply.

    A black full screen. The text is 16 sp white, centred, 56 dp down with 12
    dp sides and 72 dp below, in a scroll view with a 10 dp fading edge (the
    crown scrolls it). At the bottom centre the 52 dp microphone button, 16 dp
    up; 36 dp up a row with "step back" (left) and "return to keyboard"
    (right), 14 dp from the sides.

    The states are stock's (WearVoiceImeUi.l()):
    \list
    \li \c initializing: the microphone is not ready (a #202124 circle, outline
        microphone #cac5bc), the text "Initializing…";
    \li \c ready: the microphone bounces (1 to 0.8 in 75 ms, then back in 225
        ms) with the glyph in #fcf7eb, "Speak now";
    \li \c listening: speech heard. A #fcf7eb disc whose radius follows \l level
        (40 to 52 px) with a #32312f tick ("Stop voice dictation"), "Listening…";
    \li \c hearing: as listening, with the words heard so far as the text;
    \li \c done: with text, the action button (#fcf7eb circle, #32312f icon of
        \l actionKey) replaces the microphone; a tap accepts. Without text it
        is \c failed:
    \li \c failed: the microphone is back (white), "Didn't catch that. Try
        speaking again", a keyboard button at the top centre, the bottom row
        hidden.
    \endlist

    The text changes with a short slide: out in 75 ms (alpha to 0 and up 5 %
    of the height), in in 225 ms from 5 % below.

    The engine is \l engine: "assistant" (asteroid-assistant's Dictate over
    D-Bus, the watch's recogniser), "btsyncd" (btsyncd's Voice, which uses the
    watch's recogniser and falls back to the phone's; for voice replies) or
    "none" (the owner sets \l phase, \l partialText, \l level and \l errorCode
    and answers \l restartRequested and \l stopRequested).

    The screen holds the display on while it is shown and listens (and draws
    its animations) only then; it stops the engine when it is dismissed or
    destroyed. In "keyboard" mode the dictated text goes in at \l cursor of
    \l text (what the keyboard already holds); in "reply" mode \l text is
    empty.

    \qml
    VoiceInput {
        anchors.fill: parent
        mode: "reply"
        actionKey: "send"
        engine: "btsyncd"
        notificationId: id
        onAccepted: (text) => sendReply(text)
        onKeyboardRequested: (text) => openKeyboard(text)
        onDismissed: close()
    }
    \endqml
*/
FocusScope {
    id: voice

    /*! "keyboard" (dictation into a field) or "reply" */
    property string mode: "keyboard"
    /*! The icon of the button that takes the result: "send", "done", "search", "go" or "next" */
    property string actionKey: mode === "reply" ? "send" : "done"
    /*! What the field already holds (keyboard mode); the dictation goes in at \l cursor */
    property string text: ""
    /*! Where the dictation goes into \l text */
    property int cursor: text.length
    /*! "assistant", "btsyncd" or "none" (the owner drives the states) */
    property string engine: "assistant"
    /*! btsyncd's Start(): the notification being answered */
    property int notificationId: 0
    /*! Start the engine when the screen is created */
    property bool autoStart: true
    /*! Hold the display on while shown (stock keepScreenOn) */
    property bool keepAwake: true
    /*! The "return to keyboard" buttons */
    property bool keyboardAllowed: true
    /*! The display is on (the application is active): the animations draw only then */
    property bool displayOn: Qt.application.active
    /*! The microphone level (0..1) from which speech counts as heard (an engine without start-of-speech events) */
    property real speechLevel: 0.3

    /*! initializing, ready, listening, hearing, done or failed */
    property string phase: "initializing"
    /*! The words heard so far in this utterance */
    property string partialText: ""
    /*! Why it failed (btsyncd's codes, "no-match", "unavailable", ...) */
    property string errorCode: ""
    /*! The microphone level, 0..1 (from asteroid-assistant or btsyncd, about 25 a second) */
    property real level: 0

    /*! What the user said in this screen, the earlier utterances and the one being heard */
    readonly property string dictated: {
        var parts = _segments.slice()
        if (partialText.length > 0)
            parts.push(partialText)
        return parts.join(" ")
    }
    readonly property bool hasText: dictated.length > 0
    /*! What goes into the field: the dictation with the spaces it needs round it */
    readonly property string insertion: {
        if (!hasText)
            return ""
        var before = text.substring(0, Math.min(cursor, text.length))
        var after = text.substring(Math.min(cursor, text.length))
        return (before.length > 0 && !/\s$/.test(before) ? " " : "") + dictated
               + (after.length > 0 && !/^\s/.test(after) ? " " : "")
    }
    /*! \l text with the dictation in at the cursor: what the screen shows */
    readonly property string composite: {
        var c = Math.min(cursor, text.length)
        return text.substring(0, c) + insertion + text.substring(c)
    }

    /*! The action button was tapped: the full text and what was dictated (with its spaces) */
    signal accepted(string text, string insertion)
    /*! "Return to keyboard" was tapped (the dictation is not lost) */
    signal keyboardRequested(string text, string insertion)
    /*! Left with a right swipe or the back key: nothing is taken */
    signal dismissed()
    /*! Engine "none": start listening (again) */
    signal restartRequested()
    /*! Engine "none": the tick was tapped, stop listening */
    signal stopRequested()

    // ---- geometry (WearVoiceImeUi layout, wear_voice_ime_panel.xml; dp = Theme.dp) ----
    readonly property real micSize: Theme.dp(52)
    readonly property real micBottom: Theme.dp(16)
    readonly property real micY: height - micBottom - micSize
    readonly property real textTop: Theme.dp(56)
    readonly property real textSide: Theme.dp(12)
    readonly property real textBottom: Theme.dp(72)
    readonly property real fadeLength: Theme.dp(10)
    readonly property real rowSize: Theme.dp(48)
    readonly property real rowBottom: Theme.dp(36)
    readonly property real rowSide: Theme.dp(14)
    /*! The touch area of a side button: the 24 dp icon with 8 dp padding */
    readonly property real sideButton: Theme.dp(24 + 16)
    readonly property real errorKeyboardTop: Theme.dp(8)
    /*! The disc of the listening mic: 20 dp to 26 dp radius */
    readonly property real discMin: Theme.dp(20)
    readonly property real discMax: Theme.dp(26)
    readonly property real slide: Math.round(height * 0.05)

    // the fixed Gboard Pixel palette (not themed): the keyboard's
    readonly property QtObject _c: QtObject {
        readonly property color black: "#000000"
        readonly property color text: "#ffffff"
        readonly property color hint: "#9aa0a6"       // the guiding texts (grey)
        readonly property color paper: "#fcf7eb"      // colorPrimary: the ready mic, the disc, the action button
        // colorVoiceActionTint (= colorSurface, #32312f in the Pixel palette): the tick and the action
        // icon, both (wear_voice_ime_panel.xml voiceime_stop, voice_action_icon.xml); gap 26 names
        // #202124 for the Send icon, the layout file gives both the one attribute
        readonly property color ink: "#32312f"
        readonly property color unready: "#cac5bc"    // voice_input_mic_unready_tint_color (colorPrimaryVariant)
        readonly property color circle: "#202124"     // gray_900: the unready mic and the keyboard button
        readonly property color terminated: "#ffffff" // voice_input_mic_terminated_tint_color
    }

    // ---- texts (STRINGS.tsv voice_ime_*, voice_input_*, voiceime_*) ----
    readonly property string initializingText: qsTr("Initializing…")
    readonly property string speakNowText: qsTr("Speak now")
    readonly property string listeningText: qsTr("Listening…")
    readonly property string restartText: qsTr("Didn’t catch that. Try speaking again")
    readonly property string unavailableText: qsTr("Voice input is unavailable, please use keyboard to input text instead.")
    readonly property string stopDescription: qsTr("Stop voice dictation")
    readonly property string restartDescription: qsTr("Restart voice dictation")
    readonly property string clearAndRestartDescription: qsTr("Clear and restart voice dictation")
    readonly property string backDescription: qsTr("Back to previous stage")
    readonly property string keyboardDescription: qsTr("Return to keyboard")
    readonly property string resultDescription: qsTr("Voice input result is %1").arg(composite)
    readonly property string noResultDescription: qsTr("Didn’t catch the results. Try speaking again")

    /*! The guiding text of the phase, in grey (stock gmx / cvs); "" when the text is shown instead */
    readonly property string guidingText: {
        switch (phase) {
        case "initializing": return initializingText
        case "ready": return speakNowText
        case "listening": return listeningText
        case "failed": return _unavailableCode(errorCode) ? unavailableText : restartText
        default: return ""
        }
    }
    /*! What the text area shows: the text once there is some, else the guiding text */
    readonly property string shownText: hasText && phase !== "failed" ? composite : guidingText

    /*! The step back button's description for the phase (cwh.java:396-407) */
    readonly property string stepBackDescription: phase === "hearing" ? clearAndRestartDescription
        : phase === "done" && hasText ? restartDescription : backDescription
    /*! The step back button works while text is being heard or done */
    readonly property bool stepBackEnabled: phase === "hearing" || (phase === "done" && hasText)
    readonly property bool failed: phase === "failed"
    readonly property bool showsAction: phase === "done" && hasText
    readonly property bool showsTick: phase === "listening" || phase === "hearing"
    readonly property bool showsMic: !showsTick && !showsAction

    function _unavailableCode(code) {
        return code === "no-phone" || code === "disconnected" || code === "no-recognizer"
               || code === "language" || code === "permission" || code === "source"
               || code === "unavailable"
    }

    // ---- phase machine ----
    property var _segments: []
    property int _session: 0
    // an engine session is open (signals wanted)
    property bool _active: false

    function _setState(s) {
        if (phase === s)
            return
        phase = s
        if (s === "ready" || s === "done")
            Haptics.longPress()   // stock: the mic haptic (thud) at ready and at the end
    }

    /*! Starts listening: a new utterance; what was dictated before stays */
    function start() {
        partialText = ""
        errorCode = ""
        level = 0
        _session = 0
        _setState("initializing")
        _active = engine !== "none"
        if (engine === "assistant") {
            assistantIface.typedCall("Dictate", [{ "type": "s", "value": "" }], function (session) {
                if (!voice._active)
                    return
                if (typeof session === "number" && session > 0) {
                    if (voice._session === 0)
                        voice._session = session
                } else if (session === 0) {
                    voice._fail("unavailable")
                }
            }, function () { voice._fail("unavailable") })
        } else if (engine === "btsyncd") {
            btsyncdIface.typedCall("Start",
                [{ "type": "u", "value": notificationId }, { "type": "s", "value": "" }],
                function (sid) {
                    if (!voice._active)
                        return
                    if (sid > 0) {
                        if (voice.phase === "initializing")
                            voice._setState("ready")
                    } else if (voice.phase !== "failed") {
                        // btsyncd says why in an Error signal, which may have come before
                        // we listened; most often no phone is connected
                        btsyncdIface.typedCall("Available", [], function (available) {
                            if (voice._active && voice.phase !== "failed")
                                voice._fail(available ? "unavailable" : "no-phone")
                        })
                    }
                },
                function () { voice._fail("no-phone") })
        } else {
            restartRequested()
        }
    }

    /*! The user is done talking (the tick) */
    function stop() {
        if (!showsTick && phase !== "ready")
            return
        if (engine === "assistant")
            assistantIface.typedCall("Stop", [])
        else if (engine === "btsyncd")
            btsyncdIface.typedCall("Stop", [])
        else
            stopRequested()
    }

    /*! Drops the session without a result */
    function cancel() {
        if (_active) {
            if (engine === "assistant")
                assistantIface.typedCall("Cancel", [])
            else if (engine === "btsyncd")
                btsyncdIface.typedCall("Cancel", [])
        }
        _active = false
        _session = 0
    }

    function _fail(code) {
        if (phase === "done" && hasText)
            return
        _active = false
        partialText = ""
        errorCode = code
        _setState("failed")
    }

    // the engine's answers (called by the D-Bus handlers; engine "none" owners may call them too)
    /*! asteroid-assistant StateChanged */
    function engineState(session, s) {
        if (!_active || engine !== "assistant")
            return
        if (_session === 0 && s === "starting") {
            _session = session
        } else if (session === _session) {
            if (s === "listening" && phase === "initializing")
                _setState("ready")
            else if (s === "idle" && phase !== "done" && phase !== "failed")
                _fail("interrupted")   // dropped without a result: another session took the microphone
        }
    }
    /*! What is heard so far (assistant Partial with its session, btsyncd Partial with session -1) */
    function enginePartial(session, t) {
        if (!_active || (session >= 0 && (_session === 0 || session !== _session)))
            return
        heard(t)
    }
    /*! Words heard: the screen shows them and counts as listening */
    function heard(t) {
        if (phase === "done" || phase === "failed")
            return
        partialText = t
        if (t.length > 0)
            _setState("hearing")
        else if (phase === "initializing" || phase === "ready")
            _setState("listening")
    }
    /*! The final text of the utterance */
    function engineFinal(t) {
        if (phase === "failed")
            return
        _active = false
        partialText = ""
        var s = String(t).trim()
        if (s.length > 0) {
            var n = _segments.slice()
            n.push(s)
            _segments = n
            _setState("done")
        } else if (_segments.length > 0) {
            _setState("done")   // nothing new: what was dictated before stays
        } else {
            _fail("no-match")
        }
    }
    function engineResult(session, json) {
        if (!_active || engine !== "assistant" || _session === 0 || session !== _session)
            return
        var r = {}
        try { r = JSON.parse(json) } catch (e) { }
        if (r.type === "dictation") {
            engineFinal(r.text ? String(r.text) : "")
        } else if (r.type === "error") {
            _fail(r.code ? String(r.code) : "no-match")
        } else if (r.type === "cancel") {
            _active = false
        } else {
            _fail("no-match")
        }
    }
    function engineError(code) {
        if (phase === "done" && hasText)
            return
        _fail(code)
    }
    function engineLevel(l) {
        if (!_active)
            return
        level = Math.max(0, Math.min(1, l))
        if (phase === "ready" && level >= speechLevel)
            _setState("listening")
    }

    // ---- the buttons ----
    function micTapped() {
        if (phase === "failed" || phase === "initializing" && !_active) {
            start()
        } else if (phase === "ready") {
            stop()
        }
    }
    function tickTapped() { stop() }
    function actionTapped() {
        if (!showsAction)
            return
        cancel()
        accepted(composite, insertion)
    }
    function keyboardTapped() {
        cancel()
        keyboardRequested(composite, insertion)
    }
    /*! The undo button: restarts, keeping the earlier text (done) or clearing the utterance being heard */
    function stepBack() {
        if (!stepBackEnabled)
            return
        cancel()
        start()
    }
    /*! Leaves with nothing taken (the right swipe) */
    function dismiss() {
        cancel()
        dismissed()
    }
    /*! Scrolls the text by px (the crown; positive is forward) */
    function scrollBy(px) {
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + px))
    }

    Component.onCompleted: {
        label.current = shownText
        if (autoStart)
            start()
    }
    Component.onDestruction: cancel()

    // ---- the engines (D-Bus) ----
    // Nemo.DBus names the handler of a signal either "rc" + the Signal or the
    // signal with a lower case first letter, depending on its version: both
    // are defined.
    DBusInterface {
        id: assistantIface
        bus: DBus.SessionBus
        service: "org.asteroidos.assistant"
        path: "/org/asteroidos/assistant"
        iface: "org.asteroidos.assistant"
        signalsEnabled: voice._active && voice.engine === "assistant"

        function stateChanged(session: int, s: string) { voice.engineState(session, s) }
        function rcStateChanged(session: int, s: string) { voice.engineState(session, s) }
        function partial(session: int, t: string) { voice.enginePartial(session, t) }
        function rcPartial(session: int, t: string) { voice.enginePartial(session, t) }
        function result(session: int, json: string) { voice.engineResult(session, json) }
        function rcResult(session: int, json: string) { voice.engineResult(session, json) }
        function level(l: real) { voice.engineLevel(l) }
        function rcLevel(l: real) { voice.engineLevel(l) }
    }
    DBusInterface {
        id: btsyncdIface
        bus: DBus.SessionBus
        service: "org.asteroidos.btsyncd"
        path: "/org/asteroidos/btsyncd/voice"
        iface: "org.asteroidos.btsyncd.Voice"
        signalsEnabled: voice._active && voice.engine === "btsyncd"

        // btsyncd's Partial(s), Final(s), Error(s) and Level(d); the parameters
        // must be typed (Qt 6 cannot pass the signal's QString to a QVariant one)
        function partial(t: string) { voice.enginePartial(-1, t) }
        function rcPartial(t: string) { voice.enginePartial(-1, t) }
        function final(t: string) { voice.engineFinal(t) }
        function rcFinal(t: string) { voice.engineFinal(t) }
        function error(code: string) { voice.engineError(code) }
        function rcError(code: string) { voice.engineError(code) }
        function level(l: real) { voice.engineLevel(l) }
        function rcLevel(l: real) { voice.engineLevel(l) }
    }

    // the display stays on while the screen is up
    DisplayBlanking { id: blanking; preventBlanking: voice.keepAwake && voice.visible }
    readonly property QtObject _blanking: blanking

    // ---- what is drawn ----
    Rectangle {
        anchors.fill: parent
        color: voice._c.black
    }
    // takes the touches that no button wants (the keyboard under the screen gets none), and a right swipe leaves
    MouseArea {
        id: backdrop
        anchors.fill: parent
        DragHandler {
            id: swipe
            property bool fired: false
            target: null
            yAxis.enabled: false
            onActiveChanged: if (active) fired = false
            onTranslationChanged: {
                if (active && !fired && translation.x > voice.width * 0.25) {
                    fired = true
                    voice.swipeRight()
                }
            }
        }
    }

    // the text: a scroll view with 72 dp bottom padding (content clipped at the padding) and 10 dp fading edges
    Flickable {
        id: flick
        x: 0; y: 0
        width: parent.width
        height: voice.height - voice.textBottom
        contentWidth: width
        // the text is at least as tall as the screen less the bottom padding (setMinHeight)
        contentHeight: Math.max(voice.textTop + label.implicitHeight, height)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        flickableDirection: Flickable.VerticalFlick

        Label {
            id: label
            // the text shown now (voice.shownText, after the swap animation)
            property string current: ""
            property bool dim: !voice.hasText || voice.phase === "failed"
            x: voice.textSide
            y: voice.textTop + shift
            property real shift: 0
            width: flick.width - 2 * voice.textSide
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            role: "bodyLarge"
            color: dim ? voice._c.hint : voice._c.text
            text: current
        }
    }
    readonly property Item _flick: flick
    readonly property Item _label: label

    // the text swap: out 75 ms (accelerate), in 225 ms (decelerate), 5 % of the height
    Connections {
        target: voice
        function onShownTextChanged() { voice._textChanged() }
    }
    function _textChanged() {
        // the words heard change the text in place; only the guiding texts slide
        if (hasText && phase !== "failed") {
            swap.stop()
            label.opacity = 1
            label.shift = 0
            label.current = shownText
            // the cursor is at the end of the dictation: keep it in view (cvs.java f())
            scrollEnd.restart()
            return
        }
        if (label.current === shownText)
            return
        if (Motion.animationScale === 0 || !visible || !displayOn) {
            swap.stop()
            label.opacity = 1
            label.shift = 0
            label.current = shownText
            return
        }
        swap.restart()
    }
    Timer { id: scrollEnd; interval: 0; onTriggered: voice.scrollBy(1e6) }
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation {
                target: label; property: "opacity"; to: 0
                duration: Motion.duration(75)
                easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardAccelerate
            }
            NumberAnimation {
                target: label; property: "shift"; to: -voice.slide
                duration: Motion.duration(75)
                easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardAccelerate
            }
        }
        ScriptAction { script: { label.current = voice.shownText; label.shift = voice.slide } }
        ParallelAnimation {
            NumberAnimation {
                target: label; property: "opacity"; to: 1
                duration: Motion.duration(225)
                easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardDecelerate
            }
            NumberAnimation {
                target: label; property: "shift"; to: 0
                duration: Motion.duration(225)
                easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardDecelerate
            }
        }
    }
    readonly property QtObject _swap: swap

    // fading edges (a View's requiresFadingEdge shows them where there is more)
    Rectangle {
        visible: flick.contentY > 1
        width: parent.width; height: voice.fadeLength
        gradient: Gradient {
            GradientStop { position: 0; color: voice._c.black }
            GradientStop { position: 1; color: "#00000000" }
        }
    }
    Rectangle {
        readonly property real viewBottom: voice.height - voice.textBottom
        visible: flick.contentHeight - flick.contentY > viewBottom + 1
        y: viewBottom - height
        width: parent.width; height: voice.fadeLength
        gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 1; color: voice._c.black }
        }
    }

    // the error phase's keyboard button: 48 dp, top centre, 8 dp down
    Rectangle {
        id: errorKeyboard
        visible: voice.failed && voice.keyboardAllowed
        width: voice.rowSize; height: width
        radius: width / 2
        x: (parent.width - width) / 2
        y: voice.errorKeyboardTop
        color: voice._c.circle
        opacity: errorTap.pressed ? 0.7 : 1
        Icon {
            anchors.centerIn: parent
            width: Theme.dp(24); height: width
            name: "ios-keypad"
            color: voice._c.text
        }
        MouseArea { id: errorTap; anchors.fill: parent; onClicked: voice.keyboardTapped() }
    }
    readonly property Item _errorKeyboard: errorKeyboard

    // the bottom row: step back (left), return to keyboard (right); hidden on failure
    Item {
        id: buttonRow
        visible: !voice.failed
        x: 0
        y: voice.height - voice.rowBottom - voice.rowSize
        width: parent.width
        height: voice.rowSize
        Item {
            id: stepBack
            x: voice.rowSide
            y: (parent.height - height) / 2
            width: voice.sideButton; height: width
            opacity: voice.stepBackEnabled ? 1 : 0.38
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: stepTap.pressed && voice.stepBackEnabled ? "#3d3d3d" : "transparent"
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: "ios-undo"
                color: voice._c.text
            }
            MouseArea {
                id: stepTap
                anchors.fill: parent
                enabled: voice.stepBackEnabled
                onClicked: voice.stepBack()
            }
        }
        Item {
            id: toKeyboard
            visible: voice.keyboardAllowed
            x: parent.width - voice.rowSide - width
            y: (parent.height - height) / 2
            width: voice.sideButton; height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: keyboardTap.pressed ? "#3d3d3d" : "transparent"
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: "ios-keypad"
                color: voice._c.text
            }
            MouseArea { id: keyboardTap; anchors.fill: parent; onClicked: voice.keyboardTapped() }
        }
    }
    readonly property Item _stepBack: stepBack
    readonly property Item _toKeyboard: toKeyboard
    readonly property Item _buttonRow: buttonRow

    // ---- the microphone button: unready / ready / listening / action ----
    Item {
        id: micArea
        x: (parent.width - width) / 2
        y: voice.micY
        width: voice.micSize; height: width

        // the unready or ready or terminated microphone: a gray_900 circle with the mic outline
        Item {
            id: micButton
            anchors.fill: parent
            visible: voice.showsMic
            // the bounce: 1 -> 0.8 -> 1
            property real bounce: 1
            transform: Scale {
                origin.x: micButton.width / 2; origin.y: micButton.height / 2
                xScale: micButton.bounce; yScale: micButton.bounce
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: voice._c.circle
            }
            Icon {
                id: micGlyph
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: voice.phase === "initializing" ? "ios-mic-outline" : "ios-mic"
                color: voice.phase === "initializing" ? voice._c.unready
                     : voice.phase === "ready" ? voice._c.paper
                     : voice._c.terminated
                // the glyph's own second: a small breath while ready (an original stand-in for
                // stock's 1 s lottie mic animation, which is not copied)
                property real breath: 1
                scale: breath
            }
            MouseArea { anchors.fill: parent; onClicked: voice.micTapped() }
        }
        readonly property Item mic: micButton
        readonly property Item glyph: micGlyph

        // listening: the #fcf7eb disc follows the level; the tick on it
        Item {
            id: listenButton
            anchors.fill: parent
            visible: voice.showsTick
            readonly property real radius: voice.discMin + (voice.discMax - voice.discMin) * voice.level
            Rectangle {
                id: disc
                anchors.centerIn: parent
                width: listenButton.radius * 2; height: width
                radius: width / 2
                color: voice._c.paper
                Behavior on width {
                    enabled: voice.showsTick && voice.visible && voice.displayOn
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: "ios-checkmark"
                color: voice._c.ink
            }
            MouseArea { anchors.fill: parent; onClicked: voice.tickTapped() }
        }
        readonly property Item disc: disc

        // the result: the action button replaces the microphone
        Item {
            id: actionButton
            anchors.fill: parent
            visible: voice.showsAction
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: actionTap.pressed ? "#e0dccf" : voice._c.paper
            }
            Icon {
                anchors.centerIn: parent
                width: Theme.dp(24); height: width
                name: voice.actionKey === "send" ? "ios-send"
                      : voice.actionKey === "search" ? "ios-search"
                      : voice.actionKey === "go" ? "ios-arrow-round-forward"
                      : voice.actionKey === "next" ? "ios-return-right"
                      : "ios-checkmark"
                color: voice._c.ink
            }
            MouseArea { id: actionTap; anchors.fill: parent; onClicked: voice.actionTapped() }
        }
    }
    readonly property Item _micArea: micArea
    readonly property Item _micButton: micButton
    readonly property Item _listenButton: listenButton
    readonly property Item _actionButton: actionButton
    readonly property Item _micGlyph: micGlyph

    // ready: the bounce (1 -> 0.8 in 75 ms, 0.8 -> 1 in 225 ms) and the glyph's second
    SequentialAnimation {
        id: bounceAnim
        NumberAnimation {
            target: micButton; property: "bounce"; from: 1; to: 0.8
            duration: Motion.duration(75)
            easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardAccelerate
        }
        NumberAnimation {
            target: micButton; property: "bounce"; from: 0.8; to: 1
            duration: Motion.duration(225)
            easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardDecelerate
        }
    }
    SequentialAnimation {
        id: breathAnim
        NumberAnimation { target: micGlyph; property: "breath"; to: 1.12; duration: Motion.duration(500); easing.type: Easing.InOutSine }
        NumberAnimation { target: micGlyph; property: "breath"; to: 1; duration: Motion.duration(500); easing.type: Easing.InOutSine }
    }
    readonly property QtObject _bounce: bounceAnim
    readonly property QtObject _breath: breathAnim
    onPhaseChanged: {
        if (phase === "ready" && visible && displayOn && Motion.animationScale > 0) {
            bounceAnim.restart()
            breathAnim.restart()
        } else {
            bounceAnim.stop()
            breathAnim.stop()
            micButton.bounce = 1
            micGlyph.breath = 1
        }
    }
    onVisibleChanged: if (!visible) { bounceAnim.stop(); breathAnim.stop(); swap.stop() }

    /*! A right swipe: leaves (also callable from tests) */
    function swipeRight() { dismiss() }

    Keys.onBackPressed: dismiss()
}
