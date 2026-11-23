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

    \brief The Wear OS Material 3 dialog container (E01): a full-screen,
    opaque black window over the screen it belongs to.

    Stock CP3A (androidx.wear.compose.material3 Dialog, Settings decomp
    DialogKt$$ExternalSyntheticLambda0.java:67-68,148,173-175,218,255,
    DialogKt.java:108, MotionSchemeKt$$ExternalSyntheticLambda0.java:13-18,
    AnimationSpecUtilsKt.java:115-126):
    \list
    \li no window dim (setDimAmount(0)); the background is opaque #000000;
    \li show: alpha 0 -> 1 on a critically damped spring of stiffness 3150
        (fastEffects 1400 made 50 % faster: 1400 x 1.5^2), the content scale
        1.25 -> 1.0 on stiffness 1125 (defaultEffects 500 x 1.5^2);
    \li hide: alpha 1 -> 0 on fastEffects (1400), the content scale
        1.0 -> 1.25 on 1125;
    \li \l behind (the screen under the dialog) scales 1.0 -> 0.85 on show
        and back on hide, on 1125;
    \li a swipe right is BasicSwipeToDismissBox (motion B7;
        BasicSwipeToDismissBoxKt.java:53, its ExternalSyntheticLambda8,
        Lambda9, Lambda11, SwipeableV2Kt$$ExternalSyntheticLambda0.java:10,
        SwipeableV2State.java:169): at the progress p = dx / width the dialog
        scales lerp(1, 0.7, p) with its right edge on the screen's, under a
        content scrim min(p / 2, 0.3); the screen under it shows through a
        scrim 0.5 (1 - p) while \l behind scales lerp(0.85, 1.0, p). Let go
        at half the width or more (whatever its speed, even flung back) or
        flung right at 800 dp/s, it slides off (past p 0.7 it runs to the
        right edge), else it comes back, both in 200 ms on
        LinearOutSlowIn (0, 0, 0.2, 1); \l dismissRequested() follows the
        slide, and a dialog that stays shown after it comes back at rest;
    \li Reduce animations makes every spring land at once (WearSpring).
    \endlist

    Nothing runs while the dialog is hidden or once its springs have
    settled. \l keepScreenOn holds the display on (Nemo.KeepAlive) only while
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

    /*! The screen under the dialog: scaled to \l behindScale while shown. */
    property Item behind: null
    /*! A swipe right dismisses the dialog. */
    property bool swipeToDismiss: true
    /*! Close the dialog by itself when it is swiped away. */
    property bool closeOnSwipe: true
    /*! Hold the display on while shown (confirmations only, as stock). */
    property bool keepScreenOn: false

    /*! The display is held on now (\l keepScreenOn and shown). */
    readonly property bool holdingDisplay: keepScreenOn && _shown
    /*! The dialog is shown (between \l open() and \l close()). */
    readonly property bool shown: _shown
    /*! The dialog is on screen, entering, shown or leaving. */
    readonly property bool active: _shown || _alpha.value > 0.001 || _alpha.running
    /*! The content, scaled by the entry and exit. */
    default property alias contentData: _content.data
    readonly property alias content: _content
    /*! The dialog surface (background and content), moved by the swipe. */
    readonly property alias surface: _surface

    /*! Window alpha now. */
    readonly property real alpha: _alpha.value
    /*! Content scale now. */
    readonly property real contentScale: _scale.value
    /*! Horizontal offset of the swipe, px (the finger's, then the settle's). */
    readonly property real swipeOffset: _offset

    /* ---- stock numbers ---- */
    /*! Content scale at the start of the entry and the end of the exit. */
    readonly property real enterScale: 1.25
    /*! Scale of \l behind while the dialog shows. */
    readonly property real behindScale: 0.85
    /*! faster(50 %, fastEffects 1400): 3150. */
    readonly property real alphaInStiffness: Motion.faster(Motion.standard.fastEffects, 50).stiffness
    /*! fastEffects: 1400. */
    readonly property real alphaOutStiffness: Motion.standard.fastEffects.stiffness
    /*! faster(50 %, defaultEffects 500): 1125, for the content and \l behind. */
    readonly property real scaleStiffness: Motion.faster(Motion.standard.defaultEffects, 50).stiffness

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
        if (!active) {
            _alpha.snapTo(0)
            _scale.snapTo(enterScale)
        }
        _shown = true
        _alpha.stiffness = alphaInStiffness
        _alpha.animateTo(1)
        _scale.animateTo(1)
        if (behind) {
            _behind.target = behind
            _behind.animateTo(behindScale)
        }
        opened()
    }

    /*! Hide the dialog. */
    function close() {
        if (!_shown)
            return
        _shown = false
        _alpha.stiffness = alphaOutStiffness
        _alpha.animateTo(0)
        _scale.animateTo(enterScale)
        if (_behind.target)
            _behind.animateTo(1)
    }

    property bool _shown: false

    /* ---- the swipe to dismiss (B7) ---- */
    // a swipe is on (the finger, or its 200 ms settle)
    property bool _swiping: false
    // the offset in px; squeezed (right edge pinned) or sliding off (let go to dismiss)
    property real _offset: 0
    property bool _squeeze: true
    readonly property real _p: width > 0 ? Math.max(0, Math.min(1, _offset / width)) : 0
    readonly property real _swipeScale: Math.max(0.7, Math.min(1, 1 - 0.3 * _p))
    readonly property real _squeezeX: Math.max(0, (1 - _swipeScale) * width / 2)
    readonly property real _surfaceX: _squeeze ? _squeezeX
                                               : _squeezeX + (width - _squeezeX) * Math.max(0, _p - 0.7) / 0.3
    // behind follows the swipe only while the dialog is shown: once close()
    // has sent it back to 1.0, neither the finger nor a settle snaps it again
    on_OffsetChanged: {
        if (_swiping && _shown && _behind.target)
            _behind.snapTo(behindScale + (1 - behindScale) * _p)
    }
    function _endSwipe() {
        _settle.stop()
        _swiping = false
        _squeeze = true
        _offset = 0
    }

    anchors.fill: parent
    visible: active
    opacity: _alpha.value
    z: 1000

    WearSpring {
        id: _alpha
        dampingRatio: 1.0
        visibilityThreshold: 0.002
        onFinished: {
            if (!dialog._shown && value <= 0.002) {
                dialog._endSwipe()
                dialog.closed()
            }
        }
    }
    WearSpring {
        id: _scale
        stiffness: dialog.scaleStiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.0005
    }
    WearSpring {
        id: _behind
        property: "scale"
        stiffness: dialog.scaleStiffness
        dampingRatio: 1.0
        visibilityThreshold: 0.0005
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
                // dialog comes back on screen and behind to its 0.85
                if (dialog._shown) {
                    dialog._endSwipe()
                    if (_behind.target)
                        _behind.snapTo(dialog.behindScale)
                }
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

        property bool tracking: false
        onStarted: {
            tracking = true
            _settle.stop()
            dialog._squeeze = true
            dialog._offset = 0
            dialog._swiping = true
        }
        onValueChanged: {
            if (!tracking)
                return
            dialog._offset = Math.max(0, value)
        }
        onFinished: {
            tracking = false
            // stock's anchors (SwipeableV2State.computeTarget from Default): off
            // rest, a fling of 800 dp/s right, or half the width at any velocity,
            // dismisses; else it goes back
            var vmin = 800 * Math.min(dialog.width, dialog.height) / 192
            var dismiss = dialog._offset > 0
                    && (velocity >= vmin || dialog._offset >= dialog.width / 2)
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
                scale: _scale.value
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
