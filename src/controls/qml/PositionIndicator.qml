/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
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
    \li Shown when it is attached to a view that can scroll (a screen opens:
        \l flickable set) and while the view moves, until 2 s after it stops
        (the screen stage is not Idle); fades with the stiffness 400 spring
        (about 332 ms, ScreenScaffoldKt$$ExternalSyntheticLambda5.java:25).
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

    opacity: shown && _scrollable ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: indicator.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springEasing
        }
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
    readonly property real _length: Theme.size.scrollIndicatorLength
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
        property color color: Theme.color.scrollThumb
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
        color: Theme.color.scrollTrack
    }
    Arc {
        id: trackAfter
        from: indicator.thumbEnd + indicator.gap
        to: indicator._length / 2
        color: Theme.color.scrollTrack
    }
    Arc {
        id: thumb
        from: indicator.thumbStart
        to: indicator.thumbEnd
        color: Theme.color.scrollThumb
    }
}
