/*
 * Copyright (C) 2026 Reuben Horner
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import Nemo.KeepAlive
import org.asteroid.controls

/*!
    \qmltype Dialog
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS dialog container (E01): a full-screen, opaque black
    window over the screen it belongs to.

    Show and hide as the stock Wear OS 6 emulator (System > Restart, motion
    M15, measured from its 1x and 10x screen recordings):
    \list
    \li no window dim; the background is opaque #000000 and fades with the
        dialog, so the screen under it cross-fades: it shows at 1 - \l alpha
        and is not moved or scaled (\l behind is left alone); nothing zooms
        (\l contentScale stays 1);
    \li show: alpha 0 -> 1 while the content rises from \l enterRise (10 %
        of the height, 38.4 px on the 384 px screen) to 0, both over
        \l enterDuration (200 ms) on standard (0.2, 0, 0, 1);
    \li hide: alpha 1 -> 0 while the content rises on to \l exitRise
        (-5 %, -19.2 px), both over \l exitDuration (150 ms) on
        standardAccelerate (0.3, 0, 1, 1);
    \li a swipe right is BasicSwipeToDismissBox (motion B7;
        BasicSwipeToDismissBoxKt.java:53, its ExternalSyntheticLambda8,
        Lambda9, Lambda11, SwipeableV2Kt$$ExternalSyntheticLambda0.java:10,
        SwipeableV2State.java:169): at the progress p = dx / width the dialog
        scales lerp(1, 0.7, p) with its right edge on the screen's, under a
        content scrim min(p / 2, 0.3); the screen under it shows through a
        scrim 0.5 (1 - p) at its own size. Let go
        at half the width or more (whatever its speed, even flung back) or
        flung right at 800 dp/s, it slides off (past p 0.7 it runs to the
        right edge), else it comes back, both in 200 ms on
        LinearOutSlowIn (0, 0, 0.2, 1); \l dismissRequested() follows the
        slide, and a dialog that stays shown after it comes back at rest;
        no haptic plays on the way (stock has none); a swipe that starts
        while it settles takes it over where it is;
    \li Reduce animations makes the show and hide land at once
        (Motion.duration).
    \endlist

    Nothing runs while the dialog is hidden or once its animations have
    finished. \l keepScreenOn holds the display on (Nemo.KeepAlive) only while
    the dialog is shown; confirmations set it, alert dialogs never do.

    \qml
    Dialog {
        id: dialog
        behind: page
        onDismissRequested: close()
        Label { anchors.centerIn: parent; text: "Hello" }
    }
    \endqml
*/
Item {
    id: dialog

    /*! The screen under the dialog. Kept for callers: the dialog no longer
        moves or scales it (it shows through the fading dialog). */
    property Item behind: null
    /*! A swipe right dismisses the dialog. */
    property bool swipeToDismiss: true
    /*! Close the dialog by itself when it is swiped away. */
    property bool closeOnSwipe: true
    /*! Hold the display on while shown (confirmations only, as stock). */
    property bool keepScreenOn: false

    /*! Modal for the crown and the scroll indicator while shown: they see
        only what the dialog holds, never the screen under it (RotaryInput). */
    readonly property bool rotaryModal: _shown
    /*! The display is held on now (\l keepScreenOn and shown). */
    readonly property bool holdingDisplay: keepScreenOn && _shown
    /*! The dialog is shown (between \l open() and \l close()). */
    readonly property bool shown: _shown
    /*! The dialog is on screen, entering, shown or leaving. */
    readonly property bool active: _shown || _a > 0.001 || _enter.running || _exit.running
    /*! The content, moved by the entry and exit. */
    default property alias contentData: _content.data
    readonly property alias content: _content
    /*! The dialog surface (background and content), moved by the swipe. */
    readonly property alias surface: _surface

    /*! Window alpha now (the background and the content). */
    readonly property real alpha: _a
    /*! Content scale: always 1, stock Wear OS 6 does not zoom a dialog. */
    readonly property real contentScale: 1
    /*! Vertical offset of the content now, px (positive is lower). */
    readonly property real contentOffset: _rise
    /*! Horizontal offset of the swipe, px (the finger's, then the settle's). */
    readonly property real swipeOffset: _offset

    /* ---- stock numbers (Wear OS 6 emulator, M15) ---- */
    /*! Content offset at the start of the show, a fraction of the height. */
    readonly property real enterRise: 0.10
    /*! Content offset at the end of the hide, a fraction of the height. */
    readonly property real exitRise: -0.05
    /*! Show: alpha and offset, ms, on Motion.easing.standard. */
    readonly property int enterDuration: 200
    /*! Hide: alpha and offset, ms, on Motion.easing.standardAccelerate. */
    readonly property int exitDuration: 150

    /*! Emitted by \l open(). */
    signal opened()
    /*! Emitted once the exit animation has finished. */
    signal closed()
    /*! The dialog was swiped away (stock onDismissRequest). */
    signal dismissRequested()

    /*! Show the dialog. */
    function open() {
        if (_shown)
            return
        // a swipe left from the last showing (kept, or opened again while
        // it fades out) ends: the dialog comes back at rest
        _endSwipe()
        // opened again while it fades out: it comes back from where it is
        _exit.stop()
        if (!active) {
            _a = 0
            _rise = enterRise * _riseH
        }
        _shown = true
        // the scroll indicator of the screen under it goes (stock: it is
        // under the dialog; S25 shows none)
        RotaryInput.coverIndicator(dialog)
        _enter.restart()
        opened()
    }

    /*! Hide the dialog. */
    function close() {
        if (!_shown)
            return
        _shown = false
        _enter.stop()
        _exit.restart()
    }

    property bool _shown: false
    // alpha and the content offset (px), driven by _enter and _exit
    property real _a: 0
    property real _rise: 0
    // the height the rise is a fraction of
    readonly property real _riseH: height > 0 ? height : 384
    // for tests: the show and hide animations
    readonly property alias _enterAnimation: _enter
    readonly property alias _exitAnimation: _exit

    /* ---- the swipe to dismiss (B7) ---- */
    // a swipe is on (the finger, or its 200 ms settle)
    property bool _swiping: false
    // the offset in px; squeezed (right edge pinned) or sliding off (let go to dismiss)
    property real _offset: 0
    property bool _squeeze: true
    // where the finger took the box over: 0 from rest, the box's offset when a
    // swipe catches it mid-settle
    property real _swipeBase: 0
    readonly property real _p: width > 0 ? Math.max(0, Math.min(1, _offset / width)) : 0
    readonly property real _swipeScale: Math.max(0.7, Math.min(1, 1 - 0.3 * _p))
    readonly property real _squeezeX: Math.max(0, (1 - _swipeScale) * width / 2)
    readonly property real _surfaceX: _squeeze ? _squeezeX
                                               : _squeezeX + (width - _squeezeX) * Math.max(0, _p - 0.7) / 0.3
    function _endSwipe() {
        _settle.stop()
        _swipeBase = 0
        _swiping = false
        _squeeze = true
        _offset = 0
    }

    anchors.fill: parent
    visible: active
    opacity: _a
    z: 1000

    // show: alpha 0 -> 1 and the content from +10 % of the height to 0
    ParallelAnimation {
        id: _enter
        NumberAnimation {
            target: dialog
            property: "_a"
            to: 1
            duration: Motion.duration(dialog.enterDuration)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.easing.standard
        }
        NumberAnimation {
            target: dialog
            property: "_rise"
            to: 0
            duration: Motion.duration(dialog.enterDuration)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.easing.standard
        }
    }
    // hide: alpha 1 -> 0 and the content on up to -5 % of the height
    ParallelAnimation {
        id: _exit
        NumberAnimation {
            target: dialog
            property: "_a"
            to: 0
            duration: Motion.duration(dialog.exitDuration)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.easing.standardAccelerate
        }
        NumberAnimation {
            target: dialog
            property: "_rise"
            to: dialog.exitRise * dialog._riseH
            duration: Motion.duration(dialog.exitDuration)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.easing.standardAccelerate
        }
        onFinished: {
            if (!dialog._shown) {
                dialog._endSwipe()
                dialog.closed()
            }
        }
    }
    // the settle once the finger has let go: SWIPE_TO_DISMISS_BOX_ANIMATION_SPEC,
    // tween(200, LinearOutSlowInEasing); off the screen it dismisses
    NumberAnimation {
        id: _settle
        target: dialog
        property: "_offset"
        duration: Motion.duration(200)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.easing.linearOutSlowIn
        onFinished: {
            if (to > 0) {
                dialog.dismissRequested()
                if (dialog.closeOnSwipe)
                    dialog.close()
                // kept (closeOnSwipe false and the owner did not close it):
                // stock's box snaps back to rest once dismissed, so the
                // dialog comes back on screen
                if (dialog._shown)
                    dialog._endSwipe()
            } else {
                dialog._endSwipe()
            }
        }
    }

    // only dialogs that may hold the display (confirmations) talk to mce
    Loader {
        id: _blanking
        active: dialog.keepScreenOn
        sourceComponent: Component {
            DisplayBlanking {
                preventBlanking: dialog.holdingDisplay
            }
        }
    }

    BackSwipeArea {
        id: _swipe
        anchors.fill: parent
        swipeEnabled: dialog.swipeToDismiss && dialog._shown
        // stock's swipe-to-dismiss box plays no threshold haptic
        thresholdHaptic: false
        // a swipe that caught the box mid-settle may take it back to rest
        minimumValue: -dialog._swipeBase

        property bool tracking: false
        onStarted: {
            tracking = true
            // stock's drag takes the box over where it is, also while it
            // settles: a swipe that starts during the 200 ms goes on from
            // there (and may still bring it back), not from rest
            var caught = _settle.running
            _settle.stop()
            dialog._swipeBase = caught ? dialog._offset : 0
            dialog._offset = dialog._swipeBase
            // squeeze mode is back once the box is short of half (stock:
            // the target is Default again)
            if (dialog._offset < dialog.width / 2)
                dialog._squeeze = true
            dialog._swiping = true
        }
        onValueChanged: {
            if (!tracking)
                return
            dialog._offset = Math.max(0, Math.min(dialog.width, dialog._swipeBase + value))
            if (!dialog._squeeze && dialog._offset < dialog.width / 2)
                dialog._squeeze = true
        }
        onFinished: {
            tracking = false
            // stock's anchors (SwipeableV2State.computeTarget from Default): a
            // fling of 800 dp/s right, or half the width at any velocity,
            // dismisses; else it goes back
            var vmin = 800 * Math.min(dialog.width, dialog.height) / 192
            var dismiss = velocity >= vmin || dialog._offset >= dialog.width / 2
            dialog._squeeze = !dismiss
            _settle.to = dismiss ? dialog.width : 0
            _settle.restart()
            reset()
        }

        // the screen under the dialog shows through a black scrim of 0.5 (1 - p)
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5 * (1 - dialog._p)
            visible: dialog._swiping
        }

        Item {
            id: _surface
            width: dialog.width
            height: dialog.height
            x: dialog._surfaceX
            scale: dialog._swipeScale

            Rectangle {
                anchors.fill: parent
                color: "#000000"
            }
            // the dialog takes every touch it does not use
            MouseArea {
                anchors.fill: parent
                enabled: dialog._shown
            }
            Item {
                id: _content
                anchors.fill: parent
                transform: Translate { y: dialog._rise }
            }
            // the content scrim of the swipe, min(p / 2, 0.3)
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: Math.min(dialog._p / 2, 0.3)
                visible: dialog._swiping && opacity > 0
            }
        }
    }
}
