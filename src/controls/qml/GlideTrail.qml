/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

import QtQuick
import QtQuick.Shapes
import org.asteroid.controls

/*!
    \qmltype GlideTrail
    \inqmlmodule org.asteroid.controls

    \brief The trail that follows the finger while it glides over the keys
    (Gboard's gesture trail, \c gboardGestureTrailColor = colorSecondary,
    #e6ff7b).

    \l begin() starts a trail at a point, \l add() extends it, \l finish()
    lets it fade out and \l clear() removes it at once. Only the last
    \l holdTime ms of the path are drawn, in three bands that grow thicker and
    brighter towards the finger (the tail tapers away); nothing moves by
    itself: the trail is redrawn when a point is added, and after \l finish()
    only the one fade runs, then the item is invisible and does nothing.

    The sizes (2, 4 and 6 dp, hold time 350 ms, fade 250 ms) are not in the
    stock resources (the trail is drawn by Gboard's native code) and are
    inferred from AOSP LatinIME's gesture trail.
*/
Item {
    id: trail

    /*! The trail colour (stock: colorSecondary of the Wear Gboard theme) */
    property color color: "#e6ff7b"
    /*! How long a point of the path is kept while the finger moves (ms) */
    property int holdTime: 350
    /*! The fade after the finger lifts (ms, 0 with Reduce animations) */
    property int fadeTime: 250
    /*! The widths of the tail, middle and head bands (px) */
    property var widths: [Theme.dp(2), Theme.dp(4), Theme.dp(6)]
    /*! The alpha of the tail, middle and head bands */
    property var alphas: [0.35, 0.7, 1.0]
    /*! A trail is being drawn (the finger is down) */
    readonly property bool active: _down
    /*! The points kept, {x, y} each (for tests) */
    readonly property var points: _pts
    /*! A clock in ms (tests replace it) */
    property var clock: function () { return Date.now() }

    property bool _down: false
    property var _pts: []
    property var _stamps: []
    property var _tail: []
    property var _mid: []
    property var _head: []

    visible: opacity > 0
    opacity: 0
    enabled: false

    function _rebuild() {
        var n = _pts.length
        var a = Math.floor(n / 3), b = Math.floor(2 * n / 3)
        // the bands share their end points: one line
        _tail = _pts.slice(0, Math.min(n, a + 1)).map(function (p) { return Qt.point(p.x, p.y) })
        _mid = _pts.slice(a, Math.min(n, b + 1)).map(function (p) { return Qt.point(p.x, p.y) })
        _head = _pts.slice(b).map(function (p) { return Qt.point(p.x, p.y) })
    }

    /*! Starts a trail at (x, y) */
    function begin(x, y) {
        _fade.stop()
        _pts = [{ "x": x, "y": y }]
        _stamps = [clock()]
        _down = true
        opacity = 1
        _rebuild()
    }
    /*! Extends the trail to (x, y) and drops the points older than \l holdTime */
    function add(x, y) {
        if (!_down)
            return
        var now = clock()
        var pts = _pts.slice(), st = _stamps.slice()
        pts.push({ "x": x, "y": y })
        st.push(now)
        while (pts.length > 2 && now - st[0] > holdTime) {
            pts.shift()
            st.shift()
        }
        _pts = pts
        _stamps = st
        _rebuild()
    }
    /*! The finger lifted: the trail fades out */
    function finish() {
        _down = false
        if (opacity === 0)
            return
        if (fadeTime <= 0 || Motion.animationScale === 0) {
            clear()
            return
        }
        _fade.duration = Motion.duration(fadeTime)
        _fade.restart()
    }
    /*! Removes the trail at once */
    function clear() {
        _fade.stop()
        _down = false
        _pts = []
        _stamps = []
        _tail = []
        _mid = []
        _head = []
        opacity = 0
    }

    NumberAnimation {
        id: _fade
        target: trail
        property: "opacity"
        to: 0
        easing.type: Easing.OutQuad
        onFinished: trail.clear()
    }

    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: Qt.rgba(trail.color.r, trail.color.g, trail.color.b, trail.color.a * trail.alphas[0])
            strokeWidth: trail.widths[0]
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { id: tailLine; path: trail._tail }
        }
        ShapePath {
            strokeColor: Qt.rgba(trail.color.r, trail.color.g, trail.color.b, trail.color.a * trail.alphas[1])
            strokeWidth: trail.widths[1]
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { id: midLine; path: trail._mid }
        }
        ShapePath {
            strokeColor: Qt.rgba(trail.color.r, trail.color.g, trail.color.b, trail.color.a * trail.alphas[2])
            strokeWidth: trail.widths[2]
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { id: headLine; path: trail._head }
        }
    }
}
