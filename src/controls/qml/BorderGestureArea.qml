/*
 * Copyright (C) 2015 Florent Revest <revestflo@gmail.com>
 *               2014 Aleksi Suomalainen <suomalainen.aleksi@gmail.com>
 *               2013 John Brooks <john.brooks@dereferenced.net>
 * All rights reserved.
 *
 * You may use this file under the terms of BSD license as follows:
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the author nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import QtQuick
import QtQuick.Window
import org.asteroid.utils

/*!
    \qmltype BorderGestureArea
    \inqmlmodule org.asteroid.controls

    \brief Provides simple gesture support for swiping up, down, left, right.

    A simple example, based on the example for \l Application is shown below.  If
    the user swipes right, the rectangle turns red.  If the user swipes left, 
    the rectangle turns blue.  If the user swipes down, the rectangle turns 
    yellow.  No action is assigned to swipes up.

    \qml
    import QtQuick
    import org.asteroid.controls

    Application {
        id: myapp
        centerColor: "#00010B"
        outerColor: "#E044A6"
        rightIndicVisible: true
        bottomIndicVisible: true

        BorderGestureArea {
            id: gestureArea
            anchors.fill: parent
            acceptsRight: true
            acceptsLeft: true
            acceptsDown: true
            onGestureFinished: (gesture) => {
                if (gesture == "right") {
                    square.color = "red"
                }
                else if (gesture == "left") {
                    square.color = "blue"
                }
                else {
                    square.color = "yellow"
                }
            }
        }

        Rectangle {
            id: square
            anchors.centerIn: parent
            color: "yellow"
            width: parent.width * 0.4
            height: parent.height * 0.2
        }
    }
    \endqml

    Also note that it is possible to use a \l BorderGestureArea inside
    other containers.  For example, one could add the following inside
    the \l Rectangle in the example above.  Within the rectangle, swipes up 
    turn the \l Rectangle green and swipes down turn it orange.

    \qml
    BorderGestureArea {
        id: innerGestureArea
        anchors.fill: parent
        acceptsUp: true
        acceptsDown: true
        onGestureFinished: (gesture) => {
            if (gesture == "up") {
                square.color = "green"
            }
            else {
                square.color = "orange"
            }
        }
    }
    \endqml

*/
MouseArea {
    id: root

    property int boundary: width*DeviceSpecs.borderGestureWidth
    property bool delayReset

    signal gestureStarted(string gesture)
    signal gestureFinished(string gesture)

    /*!
        True if the current gesture active.
     */
    property bool active: gesture != ""
    /*!
        Describes the current gesture.

        The string is "down", "left", "up" or "right" if the 
        user has gestured.  Otherwise the string is empty.
     */
    property string gesture
    property int value
    property int max
    property real progress: max > 0 ? Math.abs(value) / max : 0
    /*!
        Speed of the finger along the gesture when it was lifted, in pixels
        per second, positive in the direction of the gesture. Lets a quick
        flick finish a gesture that did not travel far, as Wear OS's swipe
        to dismiss does.
     */
    property real velocity: 0
    /*!
        True when a quick flick along the gesture ended it: the finger moved
        at least \l flingVelocity pixels per second in the direction of the
        gesture when it was lifted.
     */
    readonly property bool flung: velocity >= flingVelocity
    /*!
        Speed above which a gesture counts as \l flung, in pixels per second.
        Defaults to 125 dp/s on a 192 dp wide watch.
     */
    property real flingVelocity: Math.min(width, height) / 192 * 125
    /*!
        True if gesture is left or right.
    */
    property bool horizontal: gesture === "left" || gesture === "right"
    property bool inverted: gesture === "left" || gesture === "up"
    /*!
        On a round screen the edges where a gesture starts follow the circle
        of the display: a swipe from the left edge starts within
        \l boundary of the visible left edge at that height, not of the
        corner of the square around it, which is off the screen above and
        below the middle.
     */
    property bool roundEdges: DeviceSpecs.hasRoundScreen && Math.abs(width - height) < 2

    /*!
        Tells the BorderGestureArea to accept right gestures.
     */
    property bool acceptsRight: false
    /*!
        Tells the BorderGestureArea to accept left gestures.
     */
    property bool acceptsLeft: false
    /*!
        Tells the BorderGestureArea to accept down gestures.
     */
    property bool acceptsDown: false
    /*!
        Tells the BorderGestureArea to accept up gestures.
     */
    property bool acceptsUp: false

    // Internal
    property int _mouseStart
    property variant _gestures: ["down", "left", "up", "right"]
    property real _lastPos
    property real _lastTime
    property real _speed

    // Half the width of the circle inscribed in the area at height y (or
    // half its height at x), 0 outside it
    function _halfChord(offset, size) {
        var r = size / 2
        var d = offset - r
        return d * d < r * r ? Math.sqrt(r * r - d * d) : 0
    }

    onPressed: (mouse) => {
        var leftEdge = 0, rightEdge = width, topEdge = 0, bottomEdge = height
        if (roundEdges) {
            var hx = _halfChord(mouse.y, height)
            var hy = _halfChord(mouse.x, width)
            leftEdge = width / 2 - hx
            rightEdge = width / 2 + hx
            topEdge = height / 2 - hy
            bottomEdge = height / 2 + hy
        }
        if (mouse.x - leftEdge < boundary && acceptsRight) {
            gesture = "right"
            max = width - mouse.x
        } else if (rightEdge - mouse.x < boundary && acceptsLeft) {
            gesture = "left"
            max = mouse.x
        } else if (mouse.y - topEdge < boundary && acceptsDown) {
            gesture = "down"
            max = height - mouse.y
        } else if (bottomEdge - mouse.y < boundary && acceptsUp) {
            gesture = "up"
            max = mouse.y
        } else {
            mouse.accepted = false
            return
        }

        value = 0
        velocity = 0
        _speed = 0
        if (horizontal)
            _mouseStart = mouse.x
        else
            _mouseStart = mouse.y
        _lastPos = _mouseStart
        _lastTime = Date.now()

        gestureStarted(gesture)
    }

    onPositionChanged: (mouse) => {
        var p = horizontal ? mouse.x : mouse.y
        value = Math.max(Math.min(p - _mouseStart, max), -max)
        // finger speed, smoothed over the last few moves
        var now = Date.now()
        var dt = now - _lastTime
        if (dt > 0) {
            var inst = (p - _lastPos) * 1000 / dt
            _speed = dt > 100 ? inst : _speed * 0.4 + inst * 0.6
            _lastPos = p
            _lastTime = now
        }
    }

    function reset() {
        gesture = ""
        value = max = 0
        _mouseStart = 0
    }

    onDelayResetChanged: {
        if (!delayReset)
            reset()
    }

    onReleased: {
        // a finger that stopped before lifting did not flick
        var speed = Date.now() - _lastTime > 80 ? 0 : _speed
        velocity = inverted ? -speed : speed
        gestureFinished(gesture)
        if (!delayReset)
            reset()
    }
}
