/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import org.asteroid.controls
import org.asteroid.utils

/*!
    \qmltype PositionIndicator
    \inqmlmodule org.asteroid.controls

    \brief The curved scroll indicator at the right edge of a round screen.

    Shows where a vertically scrolling \l Flickable (or ListView) is, as a
    thumb on a short track bent along the right edge of the screen, the way
    Wear OS does (E36, E37, E48):
    \list
    \li 50 x 5 dp, 2 dp from the edge (ScrollIndicatorDefaults.java:10-13);
        the thumb is the visible fraction of the content, 30 % to 70 % of the
        track.
    \li Thumb onBackground tone 80 (#c6c6c6), track tone 20 (#303030),
        round caps; the track is drawn as two pieces that stop 3 dp short of
        each end of the thumb (ScrollIndicatorKt.java:269-273,335).
    \li The system UI's style when \c{RotaryInput.systemIndicator} is set
        (the launcher sets it: app list, grid, Recents, stream, quick
        settings): thumb #FFFFFF, track #4D4D4D, 34 degrees of the track,
        the same 10 px stroke, edge gap and 3 dp gaps (Wear OS 6 emulator
        S05, S07, S11: -17 to +17 degrees at radius 183). A view with
        \c{property bool m3Indicator: true} keeps the app style (the tile
        picker, S14-d). \l thumbColor, \l trackColor and \l sweepDegrees
        follow these unless set.
    \li Shown when it is attached to a view that can scroll (a screen opens:
        \l flickable set) and while the view moves, until 2 s after it stops
        (the screen stage is not Idle); fades with the stiffness 400 spring
        (about 332 ms, ScreenScaffoldKt$$ExternalSyntheticLambda5.java:25),
        each change from rest at the opacity it has.
    \li The thumb's position and length animate over 500 ms with (0, 0, 0, 1),
        from where they are on every change (ScrollIndicatorDefaults.java:10).
    \endlist

    Every application gets one for free: the crown support of
    org.asteroid.controls puts one on top of the window and points it at the
    view the crown or a finger scrolls. Set the dconf key
    /org/asteroidos/ux/position-indicator to false to turn that off. An
    application can also place its own:

    \qml
    PositionIndicator { flickable: myListView }
    \endqml

    When it attaches to a view of an \l Application, it also hands the view
    to the application's time text, which scrolls away with it (\l ScrollAway).
*/
Item {
    id: indicator

    /*! The view whose position is shown */
    property Item flickable: null
    /*! True while the indicator is (fading) in */
    property bool shown: false
    /*! The system UI's style: RotaryInput.systemIndicator, unless the view
        asks for the app style (\c{m3Indicator: true}) */
    readonly property bool systemStyle: RotaryInput.systemIndicator && !(_asked && _asked.m3Indicator === true)
    // the view as an untyped value: m3Indicator is the view's own property
    readonly property var _asked: flickable
    /*! The thumb: #FFFFFF in the system style, else Theme.color.scrollThumb (#C6C6C6) */
    property color thumbColor: systemStyle ? Theme.color.scrollThumbSystem : Theme.color.scrollThumb
    /*! The track: #4D4D4D in the system style, else Theme.color.scrollTrack (#303030) */
    property color trackColor: systemStyle ? Theme.color.scrollTrackSystem : Theme.color.scrollTrack
    /*! The track's length in degrees, caps included: 34 in the system
        style, else 50 dp along the track (about 31 degrees on 384 px) */
    property real sweepDegrees: systemStyle ? Theme.size.scrollIndicatorSweepSystem
        : (_radius > 0 ? Theme.size.scrollIndicatorLength / _radius * 180 / Math.PI : 0)

    anchors.fill: parent
    enabled: false

    readonly property real _content: flickable ? flickable.contentHeight + flickable.topMargin + flickable.bottomMargin : 0
    readonly property real _view: flickable ? flickable.height : 0
    readonly property bool _scrollable: _content > _view + 1
    /* Wear OS: the thumb is the visible fraction of the content, kept
     * between 30% and 70% of the track */
    readonly property real _thumbFraction: _scrollable ? Math.max(Theme.size.scrollThumbMin, Math.min(Theme.size.scrollThumbMax, _view / _content)) : 1
    readonly property real _position: _scrollable
        ? Math.max(0, Math.min(1, (flickable.contentY - flickable.originY + flickable.topMargin) / (_content - _view)))
        : 0

    /*! Show the indicator now and hide it two seconds after the last call */
    function flash() {
        shown = true
        hideTimer.restart()
    }

    onFlickableChanged: {
        if (!flickable)
            return
        // a screen opened (or another view took over): show it for 2 s
        // (computed here: the bindings may not have seen the new view yet)
        var f = flickable
        if (f.contentHeight + f.topMargin + f.bottomMargin > f.height + 1)
            flash()
        // hand the view to the application's time text (ScrollAway)
        for (var p = flickable.parent; p; p = p.parent) {
            if (p._asteroidAppRoot === true) {
                p._autoScrollFlickable = flickable
                break
            }
        }
    }

    /*! The fade time: the stiffness 400 spring, about 332 ms. */
    readonly property int fadeDuration: Motion.springDuration(400)

    opacity: 0
    visible: opacity > 0
    /* the fade runs on the stock spring itself, 1.0/400 (ScreenContent
     * UpdateIdlingDetectorIfNeeded, motion D14); every change starts from
     * rest at the opacity it has, so a fade turned round mid-way goes back
     * at once (stock AnimatedIndicator: animate() from the current alpha
     * with initial velocity 0, the last change cancelling the one before) */
    readonly property bool _fadeIn: shown && _scrollable
    property bool _fadeReady: false
    on_FadeInChanged: if (_fadeReady) _fade.animateTo(_fadeIn ? 1 : 0, 0)
    // from 0 once the spring is complete (stock's alpha starts at 0)
    Component.onCompleted: {
        _fadeReady = true
        if (_fadeIn)
            _fade.animateTo(1, 0)
    }
    WearSpring {
        id: _fade
        target: indicator
        property: "opacity"
        stiffness: 400
        dampingRatio: 1.0
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: {
            if (indicator.flickable && indicator.flickable.moving)
                restart()
            else
                indicator.shown = false
        }
    }

    Connections {
        target: indicator.flickable
        ignoreUnknownSignals: true
        function onMovingChanged() {
            if (indicator.flickable.moving)
                indicator.flash()
        }
    }

    readonly property real _thickness: Theme.size.scrollIndicatorWidth
    readonly property real _radius: Math.min(width, height) / 2 - Theme.size.scrollIndicatorEdgeGap - _thickness / 2
    // the track's length along its radius: track radius x sweep
    readonly property real _length: Math.max(0, _radius * sweepDegrees * Math.PI / 180)
    /*! Gap between the thumb and each track piece: 3 dp. */
    readonly property real gap: Theme.size.scrollIndicatorGap

    /*! The thumb length and centre along the track (px, 0 = the middle), animated. */
    property real thumbLength: _length * _thumbFraction
    property real thumbCenter: (_length - _length * _thumbFraction) * (_position - 0.5)
    Behavior on thumbLength { enabled: indicator.visible; NumberAnimation { duration: Motion.duration(500); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardDecelerate } }
    Behavior on thumbCenter { enabled: indicator.visible; NumberAnimation { duration: Motion.duration(500); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.easing.standardDecelerate } }

    readonly property real thumbStart: thumbCenter - thumbLength / 2
    readonly property real thumbEnd: thumbCenter + thumbLength / 2

    // an arc from `from` to `to` px along the track (0 = the middle of the
    // right edge, positive downwards; the round caps included), drawn as
    // rounded segments; the segment count is fixed, so a scroll only moves them
    component Arc: Item {
        id: arc
        property real from: 0
        property real to: 0
        property color color: indicator.thumbColor
        readonly property int count: Math.max(2, Math.ceil(indicator._length / (indicator._thickness * 1.2)))
        readonly property real span: Math.max(0, to - from - indicator._thickness)
        anchors.fill: parent
        visible: to - from > 0.5
        Repeater {
            model: arc.count
            delegate: Rectangle {
                readonly property real share: arc.span / arc.count
                // radians, 0 at the right edge, positive downwards
                readonly property real angle: (arc.from + indicator._thickness / 2 + share * (index + 0.5)) / indicator._radius
                width: indicator._thickness
                height: share + indicator._thickness
                radius: width / 2
                color: arc.color
                // at the end of the screen: the left edge in a right to left layout (the arc is mirrored)
                readonly property bool mirrored: indicator.LayoutMirroring.enabled
                x: arc.width / 2 + (mirrored ? -1 : 1) * indicator._radius * Math.cos(angle) - width / 2
                y: arc.height / 2 + indicator._radius * Math.sin(angle) - height / 2
                rotation: (mirrored ? -1 : 1) * angle * 180 / Math.PI
            }
        }
    }

    Arc {
        id: trackBefore
        from: -indicator._length / 2
        to: indicator.thumbStart - indicator.gap
        color: indicator.trackColor
    }
    Arc {
        id: trackAfter
        from: indicator.thumbEnd + indicator.gap
        to: indicator._length / 2
        color: indicator.trackColor
    }
    Arc {
        id: thumb
        from: indicator.thumbStart
        to: indicator.thumbEnd
        color: indicator.thumbColor
    }
}
