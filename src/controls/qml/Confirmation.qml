/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import QtQuick.Shapes
import org.asteroid.controls

/*!
    \qmltype Confirmation
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS Material 3 confirmation dialogs (E08 success, E09
    failure, E11 open on phone) on \l Dialog.

    \qml
    Confirmation { id: confirmation }
    ...
    confirmation.show(qsTrId("id-sent"))              // success
    confirmation.show(qsTrId("id-not-sent"), false)   // failure
    confirmation.showOpenOnPhone()                    // "Check your phone"
    \endqml

    Stock CP3A (ConfirmationDialogKt.java:50,91,98,327-336,346,452,
    OpenOnPhoneDialogKt.java:128-133,149,163,172,275,335,
    OpenOnPhoneDialogDefaults.java:32,51; androidx ConfirmationDialog.kt,
    OpenOnPhoneDialog.kt), px on the 384 px screen:
    \list
    \li all: an opaque black \l Dialog (entry 1.25 -> 1, swipe right closes
        it early, a tap does nothing), shown for \l duration (4000 ms by
        default; callers may pass the stock 899 or 1500), the screen held on
        while it shows; the message curved along the bottom edge, centred
        at 6 o'clock, arcLarge 36 px weight 599, 4 px from the edge, fading
        in after 100 ms (150 ms for open on phone);
    \li success: a full-round pill 53.7 % of the width (206 px) turned 45
        degrees in onPrimary #383F51; from 100 ms its long side grows 206 ->
        249 px (64.8 %) on a spring of damping 0.55, stiffness 800; a 104 px
        check in primary #DBE2F9, stroke 7 px, drawn in 267 ms with
        (0.2, 0, 0, 1) from 100 ms; at most 120 degrees of text; text that
        does not fit uses the linear layout (a 160 px container morphing to
        52 px corners, a 72 px icon, the text in titleMedium 32 px, at most
        3 lines, 46 px from the sides, 16 px gaps); the confirm haptic;
    \li failure: a 206 px container morphing from a circle to 72 px
        (extraLarge) corners in 120 ms, onError #3C0507 at 80 %; our own
        stroked failure glyph 104 px in errorDim, each stroke drawn in
        267 ms, the second from 100 ms; from 150 ms the content moves
        -8 px, -15 px, then back to 0 on a bouncy spring (damping 0.5); the
        reject haptic;
    \li open on phone: a 249 px circle (64.8 %) 60 px (15.7 %) from the top
        in primaryContainer #404759; a ring 10 px in, 10 px wide, primary on
        onPrimary, from 12 o'clock, filling linearly over \l duration -
        500 ms; a 104 px phone in onPrimaryContainer drawn from 67 ms; at
        most 200 degrees of text, "Check your phone" by default; in the last
        500 ms the ring narrows and fades and the container and icon colours
        swap; no haptic.
    \endlist

    Stock stretches the duration for accessibility services
    (getRecommendedTimeoutMillis); there is no such service here yet.
    Nothing runs while it is hidden: the animations stop and the display
    hold is released when it closes.
*/
Dialog {
    id: confirmation

    /*! The message. */
    property string text: ""
    /*! True for success and open on phone, false for a failure. */
    property bool success: true
    /*! "success", "failure" or "openOnPhone". */
    property string type: "success"
    /*! How long it stays, ms (stock ConfirmationDialogDefaults: 4000). */
    property int duration: defaultDuration
    readonly property int defaultDuration: 4000

    /*! Emitted when it has gone. */
    signal finished()

    /*! Show \a message; \a ok false shows a failure; "openOnPhone",
        "success" or "failure" choose the type by name. */
    function show(message, ok) {
        if (ok === "success" || ok === "failure" || ok === "openOnPhone")
            type = ok
        else
            type = (ok === undefined || !!ok) ? "success" : "failure"
        success = type !== "failure"
        text = message !== undefined && message !== null && message !== "" ? message
             : type === "openOnPhone" ? qsTr("Check your phone") : ""
        _start()
        if (type === "success")
            Haptics.confirm()
        else if (type === "failure")
            Haptics.reject()
    }
    /*! The open-on-phone dialog; \a message defaults to "Check your phone". */
    function showOpenOnPhone(message) {
        show(message, "openOnPhone")
    }
    /*! Hide it now. */
    function hide() {
        close()
    }

    keepScreenOn: true
    onClosed: {
        _stopAll()
        finished()
    }
    onShownChanged: if (!shown) hideTimer.stop()

    /* ---- stock numbers (px) ---- */
    readonly property real _w: width > 0 ? width : 384
    readonly property real _h: height > 0 ? height : 384
    readonly property real successWidth: 0.537 * _w
    readonly property real successLength: 0.648 * _w
    readonly property real iconSize: Theme.dp(52)
    readonly property real iconStroke: 7
    readonly property real failureCorner: Theme.shape.extraLarge
    readonly property real openOnPhoneSize: 0.648 * _w
    readonly property real openOnPhoneTop: 0.157 * _w
    // open on phone (OpenOnPhoneDialogKt$$ExternalSyntheticLambda7): the
    // container Box is padded 10 dp x f and clipped to a circle, the ring
    // (IconContainerProgressIndicator on FillWholeMaxSize) is 5 dp x f wide
    // at radius (minDim - stroke) / 2 (drawCircularProgressIndicator), so
    // at f = 1 a 10 px black gap separates a 209 px disc from the ring
    readonly property real discPadding: Theme.dp(10)
    readonly property real ringWidth: Theme.dp(5)
    readonly property real textEdgeMargin: 4
    readonly property real maxSweep: type === "openOnPhone" ? 200 : 120
    readonly property var drawEasing: [0.2, 0, 0, 1, 1, 1]

    /*! The message does not fit the arc: the linear layout (success, failure). */
    readonly property bool linear: type !== "openOnPhone" && text !== "" && !_curved.fits

    // animated values, all at rest while hidden
    property real _stroke1: 0
    property real _stroke2: 0
    property real _textAlpha: 0
    property real _corner: 0      // failure: 0 circle -> 1 rounded square
    property real _shakeX: 0
    property real _ring: 0        // open on phone: progress 0..1
    property real _f: 1           // open on phone: padding and ring width fraction, 1 -> 0 at the end
    property real _end: 0         // open on phone: ring alpha out and colour swap, 0 -> 1 at the end

    function _stopAll() {
        _seq.stop()
        _lengthSpring.stop()
        _shakeSpring.stop()
        _endSpatial.stop()
        _endEffects.stop()
    }
    function _start() {
        _stopAll()
        _stroke1 = 0; _stroke2 = 0; _textAlpha = 0; _corner = 0; _shakeX = 0; _ring = 0
        _endSpatial.snapTo(1)
        _endEffects.snapTo(0)
        _lengthSpring.snapTo(successWidth)
        _shakeSpring.snapTo(0)
        open()
        hideTimer.interval = duration
        hideTimer.restart()
        _seq.restart()
    }

    Timer {
        id: hideTimer
        interval: confirmation.duration
        onTriggered: confirmation.close()
    }

    // the success pill's long side: 206 -> 249 px, damping 0.55, stiffness 800
    WearSpring {
        id: _lengthSpring
        stiffness: 800
        dampingRatio: 0.55
        visibilityThreshold: 0.1
    }
    // the failure shake's last step: a bouncy spring back to 0
    WearSpring {
        id: _shakeSpring
        target: confirmation
        property: "_shakeX"
        stiffness: Motion.standard.fastSpatial.stiffness
        dampingRatio: 0.5
        visibilityThreshold: 0.1
    }

    // open on phone, the end phase (OpenOnPhoneDialogKt.java:293-309): the
    // padding / stroke fraction 1 -> 0 on defaultSpatialSpec, the ring alpha
    // 1 -> 0 and both colours on defaultEffectsSpec (standard scheme: 500, 1.0)
    WearSpring {
        id: _endSpatial
        target: confirmation
        property: "_f"
        stiffness: Motion.standard.defaultSpatial.stiffness
        dampingRatio: Motion.standard.defaultSpatial.dampingRatio
        visibilityThreshold: 0.001
    }
    WearSpring {
        id: _endEffects
        target: confirmation
        property: "_end"
        stiffness: Motion.standard.defaultEffects.stiffness
        dampingRatio: Motion.standard.defaultEffects.dampingRatio
        visibilityThreshold: 0.001
    }

    ParallelAnimation {
        id: _seq
        // success
        SequentialAnimation {
            PauseAnimation { duration: Motion.duration(confirmation.type === "success" ? 100 : 0) }
            ScriptAction { script: if (confirmation.type === "success") _lengthSpring.animateTo(confirmation.successLength) }
        }
        // the first stroke: check, failure glyph, phone
        SequentialAnimation {
            PauseAnimation { duration: Motion.duration(confirmation.type === "success" ? 100 : confirmation.type === "openOnPhone" ? 67 : 0) }
            NumberAnimation {
                target: confirmation; property: "_stroke1"; from: 0; to: 1; duration: Motion.duration(267)
                easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation.drawEasing
            }
        }
        // the second stroke (failure, phone), 100 ms after the first
        SequentialAnimation {
            PauseAnimation { duration: Motion.duration(confirmation.type === "openOnPhone" ? 167 : 100) }
            NumberAnimation {
                target: confirmation; property: "_stroke2"; from: 0; to: 1; duration: Motion.duration(267)
                easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation.drawEasing
            }
        }
        // the text
        SequentialAnimation {
            PauseAnimation { duration: Motion.duration(confirmation.type === "openOnPhone" ? 150 : 100) }
            NumberAnimation {
                target: confirmation; property: "_textAlpha"; from: 0; to: 1; duration: Motion.duration(267)
                easing.type: Easing.BezierSpline; easing.bezierCurve: confirmation.drawEasing
            }
        }
        // failure: the morph and the shake
        NumberAnimation {
            target: confirmation; property: "_corner"; from: 0; to: 1
            duration: Motion.duration(confirmation.type === "failure" || confirmation.linear ? 120 : 0)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: Motion.duration(confirmation.type === "failure" ? 150 : 0) }
            NumberAnimation {
                target: confirmation; property: "_shakeX"; to: confirmation.type === "failure" ? -8 : 0
                duration: Motion.duration(50); easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: confirmation; property: "_shakeX"; to: confirmation.type === "failure" ? -15 : 0
                duration: Motion.duration(50); easing.type: Easing.OutCubic
            }
            ScriptAction { script: _shakeSpring.animateTo(0) }
        }
        // open on phone: the ring, then the last 500 ms
        SequentialAnimation {
            NumberAnimation {
                target: confirmation; property: "_ring"; from: 0; to: 1
                duration: confirmation.type === "openOnPhone" ? Math.max(0, confirmation.duration - 500) : 0
                easing.type: Easing.Linear
            }
            ScriptAction {
                script: if (confirmation.type === "openOnPhone") {
                    _endSpatial.animateTo(0)
                    _endEffects.animateTo(1)
                }
            }
        }
    }

    /* ---- the drawing ---- */

    function _mix(a, b, t) {
        var A = Qt.color(a), B = Qt.color(b)
        return Qt.rgba(A.r + (B.r - A.r) * t, A.g + (B.g - A.g) * t, A.b + (B.b - A.b) * t, A.a + (B.a - A.a) * t)
    }

    /*! The icon container (for tests): the pill, square or circle. */
    readonly property alias container: _container
    readonly property alias glyph: _glyph
    readonly property alias curvedText: _curved
    readonly property alias linearText: _linearText
    readonly property alias ring: _ringShape
    readonly property alias endSpatialSpring: _endSpatial
    readonly property alias endEffectsSpring: _endEffects

    Item {
        id: _group
        width: confirmation._w
        height: confirmation._h
        x: confirmation._shakeX

        // the linear layout: icon over up to 3 lines of text, centred
        readonly property real _linearSize: Theme.dp(80)
        readonly property real _linearGap: Theme.dp(8)
        readonly property real _linearTotal: _linearSize + _linearGap + _linearText.height
        readonly property real _linearTop: (height - _linearTotal) / 2

        Rectangle {
            id: _container
            readonly property real size: confirmation.type === "openOnPhone" ? confirmation.openOnPhoneSize - 2 * confirmation.discPadding * confirmation._f
                                       : confirmation.linear ? _group._linearSize
                                       : confirmation.successWidth
            // success: the pill's long side grows along the 45 degree axis
            width: confirmation.type === "success" && !confirmation.linear ? _lengthSpring.value : size
            height: size
            x: (_group.width - width) / 2
            y: confirmation.type === "openOnPhone" ? confirmation.openOnPhoneTop + (confirmation.openOnPhoneSize - height) / 2
               : confirmation.linear ? _group._linearTop
               : (_group.height - height) / 2
            rotation: confirmation.type === "success" && !confirmation.linear ? 45 : 0
            radius: {
                var full = height / 2
                if (confirmation.type === "failure")
                    return full + ((confirmation.linear ? Theme.dp(26) : confirmation.failureCorner) - full) * confirmation._corner
                if (confirmation.linear)
                    return full + (Theme.dp(26) - full) * confirmation._corner
                return full
            }
            color: confirmation.type === "success" ? Theme.color.onPrimary
                 : confirmation.type === "failure" ? Qt.rgba(Theme.color.onError.r, Theme.color.onError.g, Theme.color.onError.b, 0.8)
                 : confirmation._mix(Theme.color.primaryContainer, Theme.color.onPrimaryContainer, confirmation._end)
        }

        // open on phone: the progress ring on the outer edge of the 249 px
        // box, around the padded disc; none with Reduce animations (Lambda7)
        Shape {
            id: _ringShape
            visible: confirmation.type === "openOnPhone" && opacity > 0 && !Motion.reduceMotion
            x: (_group.width - width) / 2
            y: confirmation.openOnPhoneTop
            width: confirmation.openOnPhoneSize
            height: confirmation.openOnPhoneSize
            opacity: 1 - confirmation._end
            preferredRendererType: Shape.CurveRenderer
            readonly property real stroke: Math.max(0, confirmation.ringWidth * confirmation._f)
            readonly property real r: (width - stroke) / 2
            readonly property real sweep: 360 * confirmation._ring
            // the gap between the two pieces, as stock (stroke / 3 past the caps)
            readonly property real gapDeg: r > 0 ? (stroke + stroke / 3) / r * 180 / Math.PI : 0
            readonly property real progress: confirmation._ring
            ShapePath {
                strokeColor: Theme.color.onPrimary
                strokeWidth: _ringShape.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: _ringShape.width / 2; centerY: _ringShape.height / 2
                    radiusX: _ringShape.r; radiusY: _ringShape.r
                    startAngle: 270 + (_ringShape.sweep > 0 ? _ringShape.sweep + _ringShape.gapDeg : 0)
                    sweepAngle: _ringShape.sweep > 0 ? Math.max(0, 360 - _ringShape.sweep - 2 * _ringShape.gapDeg) : 360
                }
            }
            ShapePath {
                strokeColor: _ringShape.sweep > 0 ? Theme.color.primary : "transparent"
                strokeWidth: _ringShape.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: _ringShape.width / 2; centerY: _ringShape.height / 2
                    radiusX: _ringShape.r; radiusY: _ringShape.r
                    startAngle: 270
                    sweepAngle: _ringShape.sweep
                }
            }
        }

        DialogGlyph {
            id: _glyph
            readonly property real size: confirmation.linear ? Theme.dp(36) : confirmation.iconSize
            width: size
            height: size
            x: _container.x + (_container.width - width) / 2
            y: _container.y + (_container.height - height) / 2
            glyph: confirmation.type === "success" ? "check" : confirmation.type === "failure" ? "failure" : "phone"
            strokeUnits: confirmation.iconStroke * 24 / Math.max(1, size)
            color: confirmation.type === "success" ? Theme.color.primary
                 : confirmation.type === "failure" ? Theme.color.errorDim
                 : confirmation._mix(Theme.color.onPrimaryContainer, Theme.color.primaryContainer, confirmation._end)
            progress: confirmation._stroke1
            progress2: confirmation.type === "success" ? 1 : confirmation._stroke2
        }

        Label {
            id: _linearText
            visible: confirmation.linear
            x: Math.round(0.12 * confirmation._w)
            width: confirmation._w - 2 * x
            y: _container.y + _container.height + _group._linearGap
            text: confirmation.text
            role: "titleMedium"
            color: Theme.color.onBackground
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            opacity: confirmation._textAlpha
        }
    }

    CurvedText {
        id: _curved
        anchors.fill: parent
        visible: !confirmation.linear && text !== ""
        text: confirmation.text
        role: "arcLarge"
        color: Theme.color.onBackground
        maxSweep: confirmation.maxSweep
        edgeMargin: confirmation.textEdgeMargin
        opacity: confirmation._textAlpha
    }
}
