import QtQuick
import QtTest
import org.asteroid.controls

// W1-qa-motion: the spring engine, the motion tokens, the back gesture
// (BackSwipeArea, BorderGestureArea, LayerStack), list physics (fling,
// stretch), the stock edge transformation and ScalingList.
// 384 x 384, 2 px per dp. Numbers from TOKENS.md section 9 and the gaps.
TestCase {
    id: tc
    name: "Motion"
    when: windowShown
    visible: true
    width: 384
    height: 384

    // a failed gesture test must not leave the button down for the next one,
    // nor its view over the next test's (r2gh: a failed test_scalingList left
    // slist over the list test_stretch drags)
    function cleanup() {
        mouseRelease(tc, 1, 1)
        back.reset()
        var views = [stackHost, plain, optedOut, tuned, sideways, snapping, list, flick, slist]
        for (var i = 0; i < views.length; i++)
            views[i].visible = false
    }

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }

    // ---- reference maths (independent of the C++) ----

    // RK4 of x'' = -k x - 2 z sqrt(k) x', mass 1
    function rk4(k, z, x0, v0, t) {
        var c = 2 * z * Math.sqrt(k), dt = 0.00005, x = x0, v = v0
        var n = Math.round(t / dt)
        function a(x, v) { return -k * x - c * v }
        for (var i = 0; i < n; i++) {
            var k1x = v, k1v = a(x, v)
            var k2x = v + k1v * dt / 2, k2v = a(x + k1x * dt / 2, v + k1v * dt / 2)
            var k3x = v + k2v * dt / 2, k3v = a(x + k2x * dt / 2, v + k2v * dt / 2)
            var k4x = v + k3v * dt, k4v = a(x + k3x * dt, v + k3v * dt)
            x += dt / 6 * (k1x + 2 * k2x + 2 * k3x + k4x)
            v += dt / 6 * (k1v + 2 * k2v + 2 * k3v + k4v)
        }
        return x
    }
    // CSS-style cubic Bezier easing y(x)
    function bezier(x1, y1, x2, y2, x) {
        function bx(t) { return 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t }
        function by(t) { return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t }
        var lo = 0, hi = 1
        for (var i = 0; i < 60; i++) {
            var m = (lo + hi) / 2
            if (bx(m) < x) lo = m; else hi = m
        }
        return by((lo + hi) / 2)
    }
    // stock TransitionAreaProgress + compute (ResponsiveTransformationSpecKt.java:8-34)
    function stockEdge(topPx, hPx, viewH, edge, e) {
        var h = hPx / viewH, top = topPx / viewH, bottom = top + h
        var hf = Math.max(0, Math.min(1, (h - 0.2) / 0.4))
        var area = Math.min(0.35 + 0.2 * hf, (h + 1) / 2)
        var x = bottom < 1 - top ? bottom / area : (1 - top) / area
        if (x >= 1) return 1
        x = Math.max(0, x)
        return edge + (1 - edge) * bezier(e[0], e[1], e[2], e[3], x)
    }

    // ---- 1. spring engine ----

    WearSpring { id: probe }

    function test_springClosedForm_data() {
        var d = []
        var ks = [200, 260, 500, 1400, 1500], zs = [0.75, 0.8, 1.0]
        for (var i = 0; i < ks.length; i++)
            for (var j = 0; j < zs.length; j++)
                d.push({ tag: "k" + ks[i] + " z" + zs[j], k: ks[i], z: zs[j] })
        return d
    }
    // step response vs an RK4 integration, from rest and with a velocity
    function test_springClosedForm(d) {
        var times = [16, 50, 100, 200, 400]
        for (var i = 0; i < times.length; i++) {
            var t = times[i]
            var ref = 1 + rk4(d.k, d.z, -1, 0, t / 1000)
            near(probe.sample(d.k, d.z, 0, 1, 0, t), ref, 1e-4, "step at " + t + " ms")
            var refv = rk4(d.k, d.z, -1, 3, t / 1000)
            near(probe.sample(d.k, d.z, 0, 1, 3, t) - 1, refv, 1e-4, "with v0 3/s at " + t + " ms")
        }
    }

    function test_springOvershoot() {
        // Motion.push.enterX 0.8/300: ~1.5 % overshoot (gap motion-transitions-07)
        var peak = 0
        for (var t = 0; t < 600; t += 1)
            peak = Math.max(peak, probe.sample(300, 0.8, 0, 1, 0, t))
        near(peak - 1, Math.exp(-0.8 * Math.PI / Math.sqrt(1 - 0.64)), 0.0005, "0.8 damping overshoot")
        near(peak - 1, 0.0152, 0.0005, "1.5 %")
        // critically damped never overshoots
        for (t = 0; t < 1000; t += 5)
            verify(probe.sample(500, 1, 0, 1, 0, t) <= 1 + 1e-9, "no overshoot at z 1")
    }

    function test_settleTimes() {
        // critically damped: 99 % at 6.64 / sqrt(k) s (TOKENS 9.1: 177 / 297 / 412 ms)
        near(probe.settleMs(1400, 1, 0.01), 177.4, 0.6, "fast 1400")
        near(probe.settleMs(500, 1, 0.01), 296.9, 0.6, "default 500")
        near(probe.settleMs(260, 1, 0.01), 411.7, 0.6, "slow 260")
        near(probe.settleMs(1500, 1, 0.02), 150.7, 0.6, "1500 at 98 % (rotary, back progress)")
        near(Motion.springDuration(1400), 177, 1, "Motion.springDuration fast")
        near(Motion.springDuration(500), 297, 1, "Motion.springDuration default")
        near(Motion.springDuration(260), 412, 1, "Motion.springDuration slow")
        // fastSpatial.faster(200) = 12600: ~52 ms (press morph, M40)
        near(probe.settleMs(12600, 1, 0.02), 52.0, 1, "12600 settles in ~52 ms")
    }

    Rectangle { id: morph; width: 104; height: 104; radius: 52; color: "white" }
    WearSpring {
        id: follow
        target: morph; property: "radius"
        to: 52
        stiffness: 260
    }
    SignalSpy { id: followDone; target: follow; signalName: "finished" }

    function test_springRunsAndRests() {
        followDone.clear()
        compare(morph.radius, 52, "first value set, not animated")
        follow.stiffness = Motion.pressMorph.press.stiffness
        var t0 = Date.now()
        follow.to = Theme.shape.small
        verify(follow.running, "running after a change of to")
        tryCompare(follow, "running", false, 1000)
        compare(followDone.count, 1, "finished once")
        compare(morph.radius, 16, "rests at Theme.shape.small (8 dp)")
        verify(Date.now() - t0 < 600, "press morph is fast")
        // release on slowSpatial 260: samples sit on the closed form
        follow.stiffness = Motion.pressMorph.release.stiffness
        var samples = []
        t0 = Date.now()
        follow.to = 52
        while (follow.running) {
            wait(20)
            samples.push({ t: Date.now() - t0, v: morph.radius })
        }
        verify(samples.length > 5, "several frames")
        for (var i = 0; i < samples.length - 1; i++) {
            var s = samples[i]
            // the animation clock starts at or after t0: value <= curve(t + slack)
            verify(s.v <= probe.sample(260, 1, 16, 52, 0, s.t + 20) + 0.01, "not ahead of the curve at " + s.t)
            verify(s.v >= probe.sample(260, 1, 16, 52, 0, Math.max(0, s.t - 120)) - 0.01, "not far behind at " + s.t)
        }
        compare(morph.radius, 52, "back to a circle")
    }

    WearSpring { id: free; stiffness: 500; to: 0 }

    function test_springKeepsVelocityOnRetarget() {
        free.snapTo(0)
        free.animateTo(100, 0)
        wait(60)
        verify(free.running)
        var v = free.velocity
        verify(v > 100, "moving: " + v)
        free.to = -50
        compare(free.velocity, v, "retarget keeps the speed (no stop dead)")
        tryCompare(free, "running", false, 2000)
        compare(free.value, -50)
        // a gesture velocity start
        free.snapTo(0)
        free.animateTo(0, 2000)
        verify(free.running, "starts from a velocity at the target")
        wait(30)
        verify(free.value > 0, "carried past by the velocity")
        tryCompare(free, "running", false, 2000)
        compare(free.value, 0)
        free.stop()
    }

    WearSpring { id: shell; stiffness: 500; to: 0; stopAtFraction: 0.98 }
    function test_springStopAtFraction() {
        shell.snapTo(0)
        var t0 = Date.now()
        shell.animateTo(100, 0)
        tryCompare(shell, "running", false, 2000)
        compare(shell.value, 100, "jumps to the end")
        // 98 % of a 500 spring: (1 + w t) e^(-w t) = 0.02, w t = 5.834: 261 ms (297 ms at 99 %)
        near(probe.settleMs(500, 1, 0.02), 5.8339 / Math.sqrt(500) * 1000, 0.5, "98 % time")
        verify(Date.now() - t0 < 1000)
    }

    WearSpring { id: off; to: 0; enabled: false }
    function test_springDisabled() {
        off.to = 5
        compare(off.value, 5, "disabled: jumps")
        compare(off.running, false)
    }

    // ---- 2. tokens ----

    function test_tokens() {
        var s = Motion.standard, e = Motion.expressive
        compare([s.fastSpatial.stiffness, s.defaultSpatial.stiffness, s.slowSpatial.stiffness], [1400, 500, 260])
        compare([s.fastEffects.stiffness, s.defaultEffects.stiffness, s.slowEffects.stiffness], [1400, 500, 260])
        compare([s.fastSpatial.dampingRatio, s.defaultEffects.dampingRatio], [1, 1])
        compare([e.fastSpatial.stiffness, e.fastSpatial.dampingRatio], [800, 0.7])
        compare([e.defaultSpatial.stiffness, e.defaultSpatial.dampingRatio], [350, 0.75])
        compare([e.slowSpatial.stiffness, e.slowSpatial.dampingRatio], [200, 0.8])
        compare(e.defaultEffects.stiffness, 500)
        compare(Motion.faster(s.fastSpatial, 200).stiffness, 12600, "faster(200) = x 9")
        compare(Motion.easing.standard, [0.2, 0, 0, 1, 1, 1])
        compare(Motion.easing.standardAccelerate, [0.3, 0, 1, 1, 1, 1])
        compare(Motion.easing.standardDecelerate, [0, 0, 0, 1, 1, 1])
        compare(Motion.easing.emphasizedAccelerate, [0.3, 0, 0.8, 0.15, 1, 1])
        compare(Motion.easing.emphasizedDecelerate, [0.05, 0.7, 0.1, 1, 1, 1])
        compare(Motion.easing.legacy, [0.4, 0, 0.2, 1, 1, 1])
        compare(Motion.easing.legacyAccelerate, [0.4, 0, 1, 1, 1, 1])
        compare(Motion.easing.linearOutSlowIn, [0, 0, 0.2, 1, 1, 1])
        var d = Motion.durations
        compare([d.short1, d.short2, d.short3, d.short4], [50, 100, 150, 200])
        compare([d.medium1, d.medium2, d.medium3, d.medium4], [250, 300, 350, 400])
        compare(Motion.shellStopAtFraction, 0.98)
        compare(Motion.shellMinVisibleChange, 0.39)
        compare(Motion.springEasing, [0.25, 0.2, 0.15, 0.95, 1, 1])
        // the Qt fallback follows a critically damped spring within 1.1 %
        for (var x = 0.05; x < 1; x += 0.05)
            near(bezier(0.25, 0.2, 0.15, 0.95, x), probe.sample(1, 1, 0, 1, 0, x * 6638.4), 0.011, "fallback at " + x)
        compare(Motion.reduceMotion, false, "Reduce animations off by default")
        compare(Motion.animationScale, 1)
        compare(Motion.duration(250), 250)
        var p = Motion.push
        compare([p.enterOffset, p.enterScale, p.exitOffset, p.exitScale, p.exitAlpha], [0.5, 0.8, -0.5, 0.85, 0.6])
        compare([p.enterX.stiffness, p.enterX.dampingRatio, p.enterScaleSpring.stiffness, p.enterAlpha.stiffness], [300, 0.8, 500, 1500])
        compare([p.exitScaleSpring.stiffness, p.exitX.stiffness, p.exitX.dampingRatio, p.exitAlphaSpring.stiffness], [150, 200, 0.8, 1400])
        var b = Motion.inAppBack
        compare([b.topScale, b.belowOffset, b.belowScale, b.belowAlpha, b.settle.stiffness, b.settle.dampingRatio], [0.8, -0.5, 0.8, 0.5, 1500, 1])
        var g = Motion.backGesture
        compare([g.touchSlopDp, g.decideSlops, g.commitFraction, g.minCommitFraction], [8, 2, 0.33, 0.10])
        compare([g.minVelocityDp, g.maxVelocityDp, g.progress.stiffness, g.hapticIntervalMs], [500, 8000, 1500, 100])
        compare([Motion.pressMorph.press.stiffness, Motion.pressMorph.release.stiffness], [12600, 260])
        var l = Motion.list
        compare([l.friction, l.maxFlingDp, l.stretchIntensity, l.stretchDistanceAffected], [0.015, 2750, 0.016, 0.33])
        compare([l.stretchNaturalFrequency, l.stretchDampingRatio, l.absorbAdjustment], [24.657, 0.98, 13])
        compare([l.edgeScale, l.edgeAlpha, l.edgeContentAlpha], [0.7, 0.5, 0.5])
        compare(l.edgeEasing, [0.3, 0, 0.7, 1])
        compare([l.streamEdgeScale], [0.6])
        compare(l.streamEdgeEasing, [0, 0, 0.6, 1])
        compare(l.crownSmoothing.stiffness, 1500)
    }

    // ---- 3. back gesture ----

    Item {
        id: backHost
        width: 384; height: 384
        BackSwipeArea {
            id: back
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "transparent" }
        }
    }
    SignalSpy { id: armedSpy; target: back; signalName: "thresholdCrossed" }
    property var hapticTimes: []
    Connections { target: back; function onThresholdCrossed() { tc.hapticTimes.push(Date.now()) } }
    SignalSpy { id: startSpy; target: back; signalName: "started" }

    function test_backCommitRule_data() {
        // W = 384: 0.33 W = 126.72 px; v 500 px/s: lerp(0.33, 0.10, 0.5) W = 82.56 px
        return [
            { tag: "slow short", dx: 126, v: 0, last: 1, go: false },
            { tag: "slow past 0.33 W", dx: 127, v: 0, last: 1, go: true },
            { tag: "slow, last move left", dx: 200, v: 0, last: -1, go: false },
            { tag: "500 px/s short", dx: 82, v: 500, last: 1, go: false },
            { tag: "500 px/s past", dx: 83, v: 500, last: 1, go: true },
            { tag: "999 px/s at 0.10 W", dx: 39, v: 999, last: 1, go: true },
            { tag: "fling 1000 px/s", dx: 1, v: 1000, last: -1, go: true },
            { tag: "fling left -1000", dx: 300, v: -1000, last: -1, go: false },
            { tag: "-999 px/s far", dx: 200, v: -999, last: 0, go: true },
            { tag: "-999 px/s, last left", dx: 200, v: -999, last: -2, go: false }
        ]
    }
    function test_backCommitRule(d) {
        compare(back.shouldCommit(d.dx, d.v, d.last, 384), d.go, "BackSwipeArea")
        compare(Motion.backShouldCommit(d.dx, d.v, d.last, 384, 2), d.go, "Motion (BorderGestureArea)")
    }

    function test_backStart() {
        compare(back.decideDistance, 32, "2 x touch slop (8 dp)")
        startSpy.clear()
        mousePress(back, 40, 192)
        mouseMove(back, 72, 192, 10, Qt.LeftButton)   // dx 32: not yet
        compare(back.active, false, "32 px is not past the slop")
        mouseMove(back, 74, 192, 10, Qt.LeftButton)
        compare(back.active, true, "34 px right starts it")
        mouseRelease(back, 74, 192)
        back.reset()
        // |dy| >= |dx| does not start a back swipe
        mousePress(back, 40, 100)
        mouseMove(back, 80, 140, 10, Qt.LeftButton)
        compare(back.active, false, "45 degrees is not a back swipe")
        mouseRelease(back, 80, 140)
        back.reset()
        // anywhere: from the middle of the screen
        mousePress(back, 200, 200)
        mouseMove(back, 240, 210, 10, Qt.LeftButton)
        compare(back.active, true, "starts anywhere, |dy| < |dx|")
        mouseRelease(back, 240, 210)
        back.reset()
        compare(startSpy.count, 2)
    }

    function test_backArmAndHaptic() {
        armedSpy.clear()
        hapticTimes = []
        mousePress(back, 10, 192)
        for (var x = 20; x <= 130; x += 10)
            mouseMove(back, x, 192, 15, Qt.LeftButton)
        compare(back.armed, false, "120 px < 0.33 W")
        mouseMove(back, 140, 192, 15, Qt.LeftButton)
        compare(back.armed, true, "130 px > 126.72 px armed")
        compare(armedSpy.count, 1, "the threshold haptic once")
        mouseMove(back, 135, 192, 15, Qt.LeftButton)
        compare(back.armed, false, "moving left disarms")
        mouseMove(back, 150, 192, 15, Qt.LeftButton)
        compare(back.armed, true)
        // qemu is slow: the re-arm may come later than 100 ms; never sooner
        for (var i = 1; i < hapticTimes.length; i++)
            verify(hapticTimes[i] - hapticTimes[i - 1] >= 99, "at most one haptic per 100 ms")
        var before = armedSpy.count
        wait(120)
        mouseMove(back, 145, 192, 15, Qt.LeftButton)
        compare(back.armed, false)
        mouseMove(back, 160, 192, 15, Qt.LeftButton)
        compare(armedSpy.count, before + 1, "again after 100 ms")
        // smoothed progress chases value / W on 1.0/1500
        verify(back.smoothedProgress <= back.progress + 1e-6, "smoothed lags")
        tryVerify(function() { return Math.abs(back.smoothedProgress - back.progress) < 0.001 }, 500, "converges")
        wait(150)   // the finger stops: no fling
        mouseRelease(back, 160, 192)
        compare(back.velocity, 0, "a stopped finger did not fling")
        compare(back.committed, true, "150 px from the press, slow: goes back")
        back.reset()
    }

    function test_backCancelSlow() {
        mousePress(back, 10, 192)
        for (var x = 20; x <= 100; x += 10)
            mouseMove(back, x, 192, 15, Qt.LeftButton)
        wait(150)
        mouseRelease(back, 100, 192)
        compare(back.committed, false, "90 px slow: cancels")
        back.reset()
    }

    // review fix: flung keeps its old 125 dp/s threshold, so callers still
    // deciding with `progress >= 0.5 || flung` dismiss on a 250..999 px/s
    // flick as before; committed follows stock's rule
    function test_backFlungLegacy() {
        mousePress(back, 10, 192)
        for (var x = 20; x <= 80; x += 10)
            mouseMove(back, x, 192, 15, Qt.LeftButton)
        mouseRelease(back, 80, 192, Qt.LeftButton, Qt.NoModifier, 5)
        var v = back.velocity
        console.log("back flick: " + Math.round(v) + " px/s, flung " + back.flung + ", committed " + back.committed)
        verify(v > 0, "moving right on release: " + v)
        verify(back.progress < 0.5, "short of half the width")
        compare(back.flung, v >= 250, "flung at 125 dp/s = 250 px/s (v " + v + ")")
        if (v >= 250 && v < 1000)
            verify(back.flung, "a " + Math.round(v) + " px/s flick still counts as flung")
        compare(back.committed, back.shouldCommit(70, v, 10, 384), "committed is stock's rule")
        back.reset()
    }

    // ---- BorderGestureArea (the compositor's back from the edge) ----
    BorderGestureArea {
        id: border
        width: 384; height: 384
        acceptsRight: true
        acceptsDown: true
        enabled: false
    }
    SignalSpy { id: borderDone; target: border; signalName: "gestureFinished" }
    function test_borderGesture() {
        border.enabled = true
        compare(border.flingVelocity, 250, "flung keeps 125 dp/s (deprecated)")
        borderDone.clear()
        mousePress(border, 5, 192)
        for (var x = 15; x <= 125; x += 10)
            mouseMove(border, x, 192, 15, Qt.LeftButton)
        compare(border.armed, false, "120 px")
        mouseMove(border, 135, 192, 15, Qt.LeftButton)
        compare(border.armed, true, "130 px past 0.33 W")
        tryVerify(function() { return Math.abs(border.smoothedProgress - border.progress) < 0.001 }, 500, "smoothed converges")
        wait(150)
        mouseRelease(border, 135, 192)
        compare(borderDone.count, 1)
        compare(border.committed, true, "130 px slow goes back")
        mousePress(border, 5, 192)
        for (x = 15; x <= 75; x += 10)
            mouseMove(border, x, 192, 15, Qt.LeftButton)
        wait(150)
        mouseRelease(border, 75, 192)
        compare(border.committed, false, "70 px slow cancels")
        border.enabled = false
    }

    // ---- LayerStack: push and pop as Compose PredictiveBackNavHost ----
    Item {
        id: stackHost
        width: 384; height: 384
        visible: false
        Component {
            id: pageA
            Item { property int depth; property var pop; Rectangle { anchors.fill: parent; color: "red" } }
        }
        Component {
            id: pageB
            Item { property int depth; property var pop; Rectangle { width: 100; height: 100; color: "green" } }
        }
        LayerStack {
            id: stack
            win: null
            firstPage: pageA
        }
    }

    function resetStack() {
        stackHost.visible = true
        stack._finishPush()
        while (stack.layers.length > 0)
            stack.pop(stack.currentLayer)
        compare(stack.layers.length, 0)
    }
    function pushSettled() {
        stack.push(pageB)
        tryCompare(stack, "pushing", false, 3000)
        compare(stack.layers.length, 1)
    }

    function test_layerStackPush() {
        resetStack()
        near(stack._topX, 0, 0.01, "first page at rest")
        compare(stack._topScale, 1)
        compare(stack._topOpacity, 1)
        var page = stack.push(pageB)
        verify(page)
        compare(stack.layers.length, 1)
        // at the start: +W/2, scale 0.8, transparent; the old page in place
        near(stack._topX, 192, 0.5, "new page from +W/2")
        near(stack._topScale, 0.8, 0.002, "from 0.8")
        near(stack._topOpacity, 0, 0.01, "fades in")
        near(stack._belowX, 0, 0.5)
        near(stack._belowScale, 1, 0.002)
        near(stack._belowOpacity, 1, 0.01)
        verify(stack.pushing)
        var minX = 1e9, sawBelow = false
        var t0 = Date.now()
        while (stack.pushing && Date.now() - t0 < 3000) {
            minX = Math.min(minX, stack._topX)
            if (stack._frames[0].visible) sawBelow = true
            wait(8)
        }
        verify(!stack.pushing, "push settles")
        verify(sawBelow, "old page drawn during the push")
        // 0.8 / 300 overshoots by 1.5 % of W/2 (about 2.9 px)
        verify(minX < -0.5, "x spring overshoots: " + minX)
        near(stack._topX, 0, 0.5, "at rest")
        near(stack._topScale, 1, 0.002)
        near(stack._topOpacity, 1, 0.01)
        // old page: -W/2, 0.85, 0.6, then hidden
        near(stack._belowX, -192, 0.5, "old page to -W/2")
        near(stack._belowScale, 0.85, 0.002, "old page scale 0.85")
        near(stack._belowOpacity, 0.6, 0.01, "old page alpha 0.6")
        compare(stack._frames[0].visible, false, "old page hidden when the springs end")
        compare(stack._frames[1].visible, true)
        compare(page.parent, stack._frames[1], "page in its frame")
        compare(String(stack._frames[1].children[0].color), "#000000", "opaque black page background")
        stackHost.visible = false
    }

    function test_layerStackGesturePop() {
        resetStack()
        pushSettled()
        // drag right slowly to about 0.5 W
        mousePress(stack, 20, 192)
        for (var x = 30; x <= 230; x += 10)
            mouseMove(stack, x, 192, 15, Qt.LeftButton)
        wait(150)
        var p = stack._p
        verify(p > 0.4 && p < 0.6, "progress " + p)
        // linear in p (PredictiveBackNavHostKt.java:147-161)
        near(stack._topX, 384 * p, 0.01, "top x = W p")
        near(stack._topScale, 1 - 0.2 * p, 1e-6, "top scale 1 -> 0.8")
        near(stack._belowX, -192 * (1 - p), 0.01, "below x = -W/2 (1 - p)")
        near(stack._belowScale, 0.8 + 0.2 * p, 1e-6, "below scale 0.8 -> 1")
        near(stack._belowOpacity, 0.5 + 0.5 * p, 1e-6, "below alpha 0.5 -> 1")
        compare(stack._frames[0].visible, true, "the page below shows")
        mouseRelease(stack, 230, 192)
        tryCompare(stack.layers, "length", 0, 2000)
        compare(stack._frames.length, 1)
        compare(stack._popActive, false)
        near(stack._topX, 0, 0.01)
        compare(stack._topScale, 1)
        stackHost.visible = false
    }

    function test_layerStackCancelAndPopAnim() {
        resetStack()
        pushSettled()
        mousePress(stack, 20, 192)
        for (var x = 30; x <= 100; x += 10)
            mouseMove(stack, x, 192, 15, Qt.LeftButton)
        wait(150)
        mouseRelease(stack, 100, 192)
        tryCompare(stack, "_popActive", false, 2000)
        compare(stack.layers.length, 1, "80 px slow: cancelled")
        near(stack._topX, 0, 0.01, "back in place")
        compare(stack._frames[0].visible, false, "below hidden again")
        // programmatic pop runs the same transition to the end
        stack.currentLayer.pop()
        verify(stack._popActive)
        tryCompare(stack.layers, "length", 0, 2000)
        stackHost.visible = false
    }

    // ---- 4. lists: fling spline, stretch, edge transformation ----

    // plain lists: no ScrollPhysics of their own (the global hook)
    ListView {
        id: plain
        width: 384; height: 384
        visible: false
        model: 200
        delegate: Rectangle { width: 384; height: 50; color: index % 2 ? "grey" : "white" }
    }
    property real flickV: 0
    property real flickY: 0
    Connections {
        target: plain
        function onFlickStarted() { tc.flickV = plain.verticalVelocity; tc.flickY = plain.contentY }
    }
    ListView {
        id: optedOut
        property bool asteroidStockFling: false
        width: 384; height: 384; visible: false; model: 200
        delegate: Item { width: 384; height: 50 }
    }
    ListView {
        id: tuned
        maximumFlickVelocity: 1000
        width: 384; height: 384; visible: false; model: 200
        delegate: Item { width: 384; height: 50 }
    }
    ListView {
        id: sideways
        orientation: ListView.Horizontal
        width: 384; height: 384; visible: false; model: 200
        delegate: Item { width: 50; height: 384 }
    }
    ListView {
        id: snapping
        snapMode: ListView.SnapToItem
        width: 384; height: 384; visible: false; model: 200
        delegate: Item { width: 384; height: 50 }
    }

    ListView {
        id: list
        width: 384; height: 384
        visible: false
        model: 100
        delegate: Rectangle { width: 384; height: 100; color: index % 2 ? "grey" : "white" }
        ScrollPhysics { id: physics; flickable: list }
    }

    function test_flingSpline() {
        compare(physics.maximumVelocity, 5500, "2750 dp/s")
        compare(list.maximumFlickVelocity, 5500, "Qt's own limit raised to stock")
        // TOKENS 9.3 list.fling (AOSP OverScroller spline at 320 dpi)
        near(physics.flingDistance(1000), 117, 1, "1000 px/s distance")
        near(physics.flingDuration(1000), 333, 1, "1000 px/s duration")
        near(physics.flingDistance(2000), 389, 1, "2000 px/s distance")
        near(physics.flingDuration(2000), 555, 1, "2000 px/s duration")
        near(physics.flingDistance(4000), 1295, 2, "4000 px/s distance")
        near(physics.flingDuration(4000), 925, 1, "4000 px/s duration")
        near(physics.flingDistance(5500), 2251, 2, "5500 px/s distance")
        near(physics.flingDuration(5500), 1169, 1, "5500 px/s duration")
        near(physics.flingDistance(9000), physics.flingDistance(5500), 0.01, "capped at 5500 px/s")
    }

    function test_flingRuns() {
        list.visible = true
        list.contentY = 1000
        physics.fling(2000)
        verify(physics.flinging)
        tryCompare(physics, "flinging", false, 3000)
        near(list.contentY, 1389, 2, "2000 px/s goes 389 px")
        physics.fling(-1000)
        tryCompare(physics, "flinging", false, 3000)
        near(list.contentY, 1272, 2, "-1000 px/s goes 117 px back")
        // a finger flick ends in the spline, not Qt's constant deceleration
        list.contentY = 3000
        mousePress(list, 192, 300)
        mouseMove(list, 192, 270, 10, Qt.LeftButton)
        mouseMove(list, 192, 230, 10, Qt.LeftButton)
        mouseMove(list, 192, 180, 10, Qt.LeftButton)
        var released = list.contentY
        mouseRelease(list, 192, 180, Qt.LeftButton, Qt.NoModifier, 5)
        tryCompare(physics, "flinging", true, 500)
        tryCompare(physics, "flinging", false, 3000)
        verify(list.contentY > released + 20, "the fling carries on the way the finger went: "
               + released + " -> " + list.contentY)
        list.visible = false
    }

    // motion-transitions-19: every plain vertical list flings as stock,
    // through the RotaryInput window filter, without opting in
    function test_globalFling() {
        plain.visible = true
        plain.contentY = 3000
        compare(physics.physicsOf(plain), null, "nothing attached before a touch")
        compare(plain.maximumFlickVelocity, 2500, "Qt's default before")
        compare(plain.boundsBehavior, Flickable.DragAndOvershootBounds)
        mousePress(plain, 192, 300)
        var g = physics.physicsOf(plain)
        verify(g !== null, "a finger on the list attaches the stock fling")
        compare(g.stretchEnabled, false, "fling only: no stretch")
        compare(plain.maximumFlickVelocity, 5500, "2750 dp/s")
        compare(plain.boundsBehavior, Flickable.DragAndOvershootBounds, "bounds left as the app set them")
        mouseMove(plain, 192, 270, 10, Qt.LeftButton)
        mouseMove(plain, 192, 230, 10, Qt.LeftButton)
        mouseMove(plain, 192, 180, 10, Qt.LeftButton)
        tc.flickV = 0
        mouseRelease(plain, 192, 180, Qt.LeftButton, Qt.NoModifier, 5)
        verify(tc.flickV > 0, "Qt started a flick: " + tc.flickV)
        tryCompare(g, "flinging", true, 500)
        tryCompare(g, "flinging", false, 3000)
        var went = plain.contentY - tc.flickY
        console.log("global fling: " + Math.round(tc.flickV) + " px/s went " + Math.round(went) + " px")
        near(went, g.flingDistance(tc.flickV), 3, "spline distance for " + Math.round(tc.flickV) + " px/s")
        var qt = tc.flickV * tc.flickV / (2 * 1500)
        verify(Math.abs(went - qt) > 20 || tc.flickV < 300,
               "not Qt's constant deceleration (" + Math.round(qt) + " px)")
        // a second touch reuses it
        mousePress(plain, 192, 300)
        compare(physics.physicsOf(plain), g, "attached once")
        mouseRelease(plain, 192, 300)
        // a list with its own ScrollPhysics keeps it
        list.visible = true
        plain.visible = false
        mousePress(list, 192, 300)
        compare(physics.physicsOf(list), physics, "the explicit ScrollPhysics stays")
        compare(list.boundsBehavior, Flickable.DragOverBounds)
        mouseRelease(list, 192, 300)
        list.visible = false
    }

    function test_globalFlingLeftAlone_data() {
        return [
            { tag: "opted out", view: optedOut, vmax: 2500 },
            { tag: "app's own physics", view: tuned, vmax: 1000 },
            { tag: "horizontal", view: sideways, vmax: 2500 },
            { tag: "snapping", view: snapping, vmax: 2500 }
        ]
    }
    function test_globalFlingLeftAlone(d) {
        d.view.visible = true
        mousePress(d.view, 192, 300)
        compare(physics.physicsOf(d.view), null, "no stock fling attached")
        compare(d.view.maximumFlickVelocity, d.vmax, "limit unchanged")
        mouseRelease(d.view, 192, 300)
        d.view.visible = false
    }

    function test_stretch() {
        list.visible = true
        // AOSP dampStretchVector: 1 + 0.016 d + 0.016 (1 - e^(-d e / 0.33))
        near(physics.stretchFor(0.5), 1 + 0.008 + 0.016 * (1 - Math.exp(-0.5 * Math.E / 0.33)), 1e-6, "pull 0.5")
        near(physics.stretchFor(1), 1.032, 0.0001, "pull 1: about 3.2 %")
        near(physics.stretchFor(3), physics.stretchFor(1), 1e-9, "capped at one height")
        // a pull at the top stretches about the top edge, release springs back
        list.contentY = list.originY - list.topMargin
        physics.pullTo(96)
        near(physics.pull, 0.25, 1e-6, "96 px = 0.25 of the height")
        near(physics.stretchScale, physics.stretchFor(0.25), 1e-9)
        compare(physics.stretchOrigin, 0, "pulled at the top: about the top")
        physics.release()
        tryCompare(physics, "pull", 0, 1000)
        compare(physics.stretchScale, 1)
        // the finger past the top: Qt reports half the travel; ours is the travel
        mousePress(list, 192, 100)
        for (var y = 110; y <= 300; y += 10) {
            mouseMove(list, 192, y, 15, Qt.LeftButton)
        }
        verify(physics.pull > 0, "pulled at the top: " + physics.pull + " dragging " + list.dragging + " cy " + list.contentY)
        near(list.contentY, list.originY - list.topMargin, 0.5, "content stays at the bound")
        var travel = physics.pull * 384
        verify(travel > 120 && travel < 220, "pull follows the finger past the slop: " + travel)
        mouseRelease(list, 192, 300)
        tryCompare(physics, "pull", 0, 1500)
        // a fling into the bottom is absorbed into the stretch spring
        list.positionViewAtEnd()
        var end = list.contentY
        list.contentY = end - 50
        physics.fling(3000)
        tryVerify(function() { return physics.pull < 0 }, 1500, "absorbed at the bottom")
        compare(physics.stretchOrigin, 384, "about the bottom edge")
        verify(physics.stretchScale > 1.01, "visible bounce: " + physics.stretchScale)
        near(list.contentY, end, 0.5, "content stops at the end")
        tryCompare(physics, "pull", 0, 1500)
        list.visible = false
    }

    // stock edge transformation (192 dp spec)
    Flickable {
        id: flick
        width: 384; height: 384
        visible: false
        contentHeight: 384
        Item { id: e1; y: 0; width: 384; height: 104 }
        Item { id: e2; y: 300; width: 384; height: 104 }
        Item { id: e3; y: 140; width: 384; height: 104 }
        Item { id: e4; y: 20; width: 384; height: 230 }
        EdgeEffect { id: ee1; item: e1 }
        EdgeEffect { id: ee2; item: e2 }
        EdgeEffect { id: ee3; item: e3 }
        EdgeEffect { id: ee4; item: e4 }
        EdgeEffect { id: eeStream; item: e1; edgeScale: Motion.list.streamEdgeScale; easing: Motion.list.streamEdgeEasing }
        EdgeEffect { id: eeCenter; item: e1; measure: EdgeEffect.Center }
    }

    function test_edgeTransform() {
        var e = [0.3, 0, 0.7, 1]
        // near the top: the bottom edge (104 px of 384: x = 0.2708 / 0.3854)
        near(ee1.scale, stockEdge(0, 104, 384, 0.7, e), 5e-4, "top row scale")
        near(ee1.alpha, stockEdge(0, 104, 384, 0.5, e), 5e-4, "top row container alpha")
        near(ee1.contentAlpha, stockEdge(0, 104, 384, 0.5, e), 5e-4, "top row content alpha")
        verify(ee1.scale > 0.7 && ee1.scale < 1)
        near(ee1.transformedHeight, Math.ceil(ee1.scale * 104), 0, "laid out at ceil(s h)")
        near(ee1.offsetY, -(1 - ee1.scale) * 52, 1e-6, "pinned at its top")
        // near the bottom: the top edge
        near(ee2.scale, stockEdge(300, 104, 384, 0.7, e), 5e-4, "bottom row scale")
        // the middle: untouched
        compare(ee3.scale, 1, "middle row")
        compare(ee3.alpha, 1)
        // a tall row (0.6 of the view) gets the larger area, capped at (1 + h) / 2
        near(ee4.scale, stockEdge(20, 230, 384, 0.7, e), 5e-4, "tall row")
        // the notification stream: 0.6 and (0, 0, 0.6, 1) (kwf.java:613)
        near(eeStream.scale, stockEdge(0, 104, 384, 0.6, [0, 0, 0.6, 1]), 5e-4, "stream spec")
        // the old centre measure stays available
        var c = 52 / 384, hf = (104 / 384 - 0.2) / 0.4
        var area = 0.35 + 0.2 * hf
        near(eeCenter.scale, 0.7 + 0.3 * bezier(0.3, 0, 0.7, 1, c / area), 5e-4, "centre measure")
        // values at the ends of the curve
        near(ee1.valueAt(0, 0.7), 0.7, 1e-9, "edge value at the edge")
        near(ee1.valueAt(1, 0.7), 1, 1e-9)
        // stock transforms whether or not the list scrolls (contentHeight = height here)
        compare(flick.contentHeight, flick.height)
    }

    // crown smoothing: the list follows the crown target on spring 1.0/1500
    // (RotaryScrollable), not the old 35 ms exponential
    function test_crownSmoothing() {
        list.visible = true
        list.contentY = 2000
        wait(50)
        var y0 = list.contentY
        var t0 = Date.now()
        mouseWheel(list, 192, 192, 0, -1200)
        var samples = []
        for (var i = 0; i < 40; i++) {
            samples.push({ t: Date.now() - t0, y: list.contentY })
            wait(8)
        }
        var d = list.contentY - y0
        verify(Math.abs(d) > 5, "the crown moved the list: " + d)
        for (i = 0; i < samples.length; i++) {
            var s = samples[i]
            var f = (s.y - y0) / d          // fraction covered
            var ahead = 1 - probe.sample(1500, 1, 1, 0, 0, s.t + 20)   // most it can have covered
            verify(f <= ahead + 0.02, "not ahead of the spring at " + s.t + " ms: " + f + " > " + ahead)
            verify(f <= 1.0001, "no overshoot")
        }
        verify(Math.abs(samples[0].y - y0) < Math.abs(d), "starts from rest, not a jump")
        list.visible = false
    }

    FlatMesh { id: mesh; width: 50; height: 50; motion: "always" }
    function test_meshMovesWithoutReduceMotion() {
        tryCompare(mesh, "running", true, 1000)
        mesh.visible = false
        tryCompare(mesh, "running", false, 1000)
    }

    // ---- ScalingList ----
    ScalingList {
        id: slist
        width: 384; height: 384
        visible: false
        model: 30
        itemDelegate: Rectangle { height: 104; color: "white"; property int index: -1; property int i: index }
    }

    function test_scalingList() {
        slist.visible = true
        wait(50)
        near(slist.topMargin, 63.9, 0.05, "16.64 % top")
        near(slist.bottomMargin, 140.0, 0.05, "36.46 % bottom")
        compare(slist.spacing, 8, "4 dp between rows")
        near(slist.sideMargin, 20, 0.05, "5.2 % sides")
        compare(slist.physics.flickable, slist)
        compare(slist.boundsMovement, Flickable.StopAtBounds)
        // at rest the first row sits below the 16.64 % padding: out of the area
        var first = slist.itemAtIndex(0)
        verify(first)
        compare(first.height, 104, "row 0 at rest: unscaled")
        // scrolled up by 60 px its bottom edge enters the area: scaled, packed
        slist.contentY = slist.contentY + 60
        wait(20)
        var row = slist.itemAtIndex(0)
        verify(row)
        var content = row.children[0], edge = null
        for (var k = 0; k < row.data.length; k++)
            if (row.data[k].transformedHeight !== undefined) edge = row.data[k]
        verify(edge, "the row's EdgeEffect")
        compare(content.item.i, 0, "the row sees index")
        near(content.x, 20, 0.05)
        near(content.width, 344, 0.1)
        verify(edge.scale < 1, "top row scaled: " + edge.scale)
        // N61-04 (6c723b3): a packed row keeps its natural height and place (the list
        // scrolls evenly at its natural length); its picture scales about the edge
        // nearest the centre (the bottom, above the middle row) and a Translate closes
        // it up to the next row, 4 dp away at every scale (was: the delegate laid out
        // at ceil(s h))
        compare(row.height, 104, "natural height")
        verify(edge.packed, "packed")
        compare(edge.originY, 104, "above the middle row: about its bottom")
        // a middle row keeps its height
        var mid = slist.itemAtIndex(1)
        verify(mid)
        var midContent = mid.children[0], midEdge = null
        for (k = 0; k < mid.data.length; k++)
            if (mid.data[k].transformedHeight !== undefined) midEdge = mid.data[k]
        verify(midEdge, "the middle row's EdgeEffect")
        compare(mid.height, 104, "the middle row's natural height")
        // the pictures in the list's content: Scale about originY, then the Translate
        var bottom0 = row.y + content.y + edge.originY + edge.scale * (104 - edge.originY) + edge.translateY
        var top1 = mid.y + midContent.y + midEdge.originY * (1 - midEdge.scale) + midEdge.translateY
        near(top1 - bottom0, 8, 1, "4 dp from the shrunk row to the next")
        slist.visible = false
    }
}
