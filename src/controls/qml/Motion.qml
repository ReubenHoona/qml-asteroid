/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

pragma Singleton

import QtQuick
import Nemo.Configuration

/*!
    \qmltype Motion
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS (Material 3, CP3A) motion tokens: springs, easings,
    durations and the named transitions of the system.

    Every CP3A transition is a spring. Run them with \l WearSpring (a
    velocity-aware damped spring), for example:

    \qml
    WearSpring {
        target: page; property: "x"
        to: shown ? 0 : page.width
        stiffness: Motion.standard.defaultSpatial.stiffness
        dampingRatio: Motion.standard.defaultSpatial.dampingRatio
    }
    \endqml

    Where a spring cannot be used, \c{Motion.springEasing} over
    \c{Motion.springDuration(stiffness)} follows a critically damped spring
    within about 1 %.

    Accessibility > Reduce animations (\c{/org/asteroidos/a11y/reduce-motion})
    sets \l animationScale to 0: springs land at once, durations from
    \l duration() are 0 and list edges stop scaling.
*/
QtObject {
    id: motion

    /* ---- Spring scheme (Wear Compose Material 3 MotionScheme) ---- */

    function _spring(k, z) { return { stiffness: k, dampingRatio: z } }

    /*!
        The standard scheme (LocalMotionScheme default): spatial and effects
        springs, damping 1.0, stiffness fast 1400, default 500, slow 260
        (Settings MotionSchemeKt$$ExternalSyntheticLambda0.java:13-18).
    */
    readonly property var standard: ({
        fastSpatial: _spring(1400, 1.0),
        defaultSpatial: _spring(500, 1.0),
        slowSpatial: _spring(260, 1.0),
        fastEffects: _spring(1400, 1.0),
        defaultEffects: _spring(500, 1.0),
        slowEffects: _spring(260, 1.0)
    })
    /*!
        The expressive scheme: spatial fast 800/0.7, default 350/0.75, slow
        200/0.8 (androidx MotionScheme.kt, values-watch integers.xml);
        effects as the standard scheme.
    */
    readonly property var expressive: ({
        fastSpatial: _spring(800, 0.7),
        defaultSpatial: _spring(350, 0.75),
        slowSpatial: _spring(200, 0.8),
        fastEffects: _spring(1400, 1.0),
        defaultEffects: _spring(500, 1.0),
        slowEffects: _spring(260, 1.0)
    })

    /*!
        A spring \a pct percent faster: stiffness x (1 + pct / 100)^2
        (AnimationSpecUtilsKt.java:115-125, faster()).
    */
    function faster(spring, pct) {
        var f = 1 + pct / 100
        return _spring(spring.stiffness * f * f, spring.dampingRatio)
    }

    /* ---- Easings for the few tweens (MotionTokens.java:16-41) ---- */

    readonly property var easing: ({
        standard: [0.2, 0, 0, 1, 1, 1],
        standardAccelerate: [0.3, 0, 1, 1, 1, 1],
        standardDecelerate: [0, 0, 0, 1, 1, 1],
        emphasizedAccelerate: [0.3, 0, 0.8, 0.15, 1, 1],
        emphasizedDecelerate: [0.05, 0.7, 0.1, 1, 1, 1],
        legacy: [0.4, 0, 0.2, 1, 1, 1],
        legacyAccelerate: [0.4, 0, 1, 1, 1, 1],
        linearOutSlowIn: [0, 0, 0.2, 1, 1, 1]
    })

    /*! Shell durations in ms (TransitionAnimationController.java:20-36). */
    readonly property var durations: ({
        short1: 50, short2: 100, short3: 150, short4: 200,
        medium1: 250, medium2: 300, medium3: 350, medium4: 400
    })

    /*!
        Qt fallback where a WearSpring cannot run: this BezierSpline over
        \l springDuration() follows a critically damped spring within 1.1 %
        (controls-components audit 2.0).
    */
    readonly property var springEasing: [0.25, 0.2, 0.15, 0.95, 1, 1]

    /*!
        Seconds-to-ms time for a critically damped spring of \a stiffness to
        cover \a fraction of a step from rest (default 0.99: 6.64 / sqrt(k) s),
        scaled by \l animationScale.
    */
    function springDuration(stiffness, fraction) {
        var f = fraction === undefined ? 0.99 : fraction
        // (1 + w t) e^(-w t) = 1 - f, solved for w t
        var lo = 0, hi = 50
        for (var i = 0; i < 60; i++) {
            var m = (lo + hi) / 2
            if ((1 + m) * Math.exp(-m) > 1 - f) lo = m; else hi = m
        }
        return Math.round(1000 * lo / Math.sqrt(stiffness)) * animationScale
    }

    /*!
        Shell transitions run their spring on 0..100 and skip to the end at
        98 % (TransitionAnimationController.java:81-95, 246-254).
    */
    readonly property real shellStopAtFraction: 0.98
    readonly property real shellMinVisibleChange: 0.39

    /* ---- Reduce animations ---- */

    property ConfigurationValue _reduceMotion: ConfigurationValue {
        key: "/org/asteroidos/a11y/reduce-motion"
        defaultValue: false
    }
    /*! Accessibility > Reduce animations is on. */
    readonly property bool reduceMotion: _reduceMotion.value === true
    /*! 0 with Reduce animations (stock sets the animator scale to 0), else 1. */
    readonly property real animationScale: reduceMotion ? 0 : 1
    /*! A tween duration in ms with the animation scale applied. */
    function duration(ms) { return ms * animationScale }

    /* ---- Named transitions ---- */

    /*!
        Compose push (PredictiveBackNavHostKt.java:133-146): the new screen
        from +W/2 on 0.8/300, scale 0.8 -> 1 on 1.0/500, fade in on
        1.0/1500; the old one to scale 0.85 on 1.0/150, to -W/2 on 0.8/200,
        to alpha 0.6 on 1.0/1400.
    */
    readonly property var push: ({
        enterOffset: 0.5, enterScale: 0.8, exitOffset: -0.5, exitScale: 0.85, exitAlpha: 0.6,
        enterX: _spring(300, 0.8), enterScaleSpring: _spring(500, 1.0), enterAlpha: _spring(1500, 1.0),
        exitScaleSpring: _spring(150, 1.0), exitX: _spring(200, 0.8), exitAlphaSpring: _spring(1400, 1.0)
    })
    /*!
        Compose pop, linear in the back progress p
        (PredictiveBackNavHostKt.java:147-161): the current screen x = W p,
        scale 1 -> 0.8; the previous one x = -W/2 (1 - p), scale 0.8 -> 1,
        alpha 0.5 -> 1; commit and cancel on 1.0/1500.
    */
    readonly property var inAppBack: ({
        topScale: 0.8, belowOffset: -0.5, belowScale: 0.8, belowAlpha: 0.5,
        settle: _spring(1500, 1.0)
    })
    /*!
        The system back gesture (SwipeBackGestureHandler.java:96-149,
        WearGestureInterceptionDetector): starts past 2 x 8 dp with
        |dy| < |dx|, anywhere; armed past 0.33 W; on release 500 dp/s goes,
        -500 dp/s cancels, else past lerp(0.33, 0.10, v / 500 dp/s) W;
        velocity capped at 8000 dp/s; progress dx / W smoothed by 1.0/1500;
        the threshold haptic at most every 100 ms.
    */
    readonly property var backGesture: ({
        touchSlopDp: 8, decideSlops: 2, commitFraction: 0.33, minCommitFraction: 0.10,
        minVelocityDp: 500, maxVelocityDp: 8000, progress: _spring(1500, 1.0),
        hapticIntervalMs: 100
    })
    /*!
        Stock's back decision for a swipe of \a dx px released at
        \a velocity px/s, whose last move was \a lastDx px, on a screen
        \a width px wide with \a dpPx px per dp (2 on the Pixel Watch 2).
        The same rule as BackSwipeArea.shouldCommit().
    */
    function backShouldCommit(dx, velocity, lastDx, width, dpPx) {
        var vmin = backGesture.minVelocityDp * (dpPx === undefined ? 2 : dpPx)
        if (velocity >= vmin) return true
        if (velocity <= -vmin) return false
        var f = Math.max(0, Math.min(1, velocity / vmin))
        var t = width * (backGesture.commitFraction
                         + (backGesture.minCommitFraction - backGesture.commitFraction) * f)
        return dx > t && lastDx >= 0
    }
    /*!
        IconButton and TextButton press morph (IconButtonKt.java:207): circle
        to Theme.shape.small on fastSpatial.faster(200) = 1.0/12600, back on
        slowSpatial = 1.0/260. Rows and chips: ripple only.
    */
    readonly property var pressMorph: ({
        press: _spring(12600, 1.0), release: _spring(260, 1.0)
    })

    /* ---- Lists ---- */

    /*!
        Touch fling (ScrollPhysics): Android spline decay, friction 0.015,
        at most 2750 dp/s; stretch overscroll (EdgeEffect TYPE_STRETCH)
        damping 0.98, natural frequency 24.657 rad/s, intensity 0.016,
        distance affected 0.33, absorb x 13.
    */
    readonly property var list: ({
        friction: 0.015, maxFlingDp: 2750,
        stretchIntensity: 0.016, stretchDistanceAffected: 0.33,
        stretchNaturalFrequency: 24.657, stretchDampingRatio: 0.98, absorbAdjustment: 13,
        edgeScale: 0.7, edgeAlpha: 0.5, edgeContentAlpha: 0.5, edgeEasing: [0.3, 0, 0.7, 1],
        streamEdgeScale: 0.6, streamEdgeEasing: [0, 0, 0.6, 1],
        crownSmoothing: _spring(1500, 1.0)
    })
}
