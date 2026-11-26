// Q5 (N61-09 follow-up): SwipeToReveal's drag under expressiveLook as the Wear OS 6
// emulator. S34 / S34-b: the finger held 160 px right / left of the press (DOWN 100 or
// 290, MOVEs 20-30 px apart) shows the card 102 px out (card x 121-364 or 19-262, pill
// 19-116 or 267-364 = |offset| - 4). M10 / V10 (input swipe 80 -> 340 in 200 ms): the
// card moves 22 px a frame at the finger's 21.7 (1:1 speed), about 55 px behind the
// finger, so the card starts 29 dp (58 px) after the press and then follows 1:1.
// r2-63: a release goes to an anchor by stock's rule (Wear OS material3 SwipeToReveal fling
// behaviour, decompiled deskclock dvw / contacts dzr): no speed: the nearest anchor; under
// 200 dp/s the nearer of the two around the card; 200-800 dp/s the next one in the finger's
// direction; 800 dp/s or more the last one that way. Without a secondary action the partial
// anchor is stock's single-action one: 64 dp x 344 / 384 = 114.7 px. 1 dp/s = 2 px/s here.
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Item {
        id: host
        anchors.fill: parent
    }

    property int primaryCount: 0

    TestCase {
        id: tc
        name: "Q5swipe"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function pixelNear(img, x, y, hex, tol, msg) {
            var p = img.pixel(x, y), c = Qt.color(hex)
            var d = Math.max(Math.abs(p.r - c.r), Math.abs(p.g - c.g), Math.abs(p.b - c.b)) * 255
            verify(d <= tol, msg + " at " + x + "," + y + ": " + p + " != " + hex + " (" + d.toFixed(1) + ")")
        }
        function cleanup() {
            mouseRelease(top, 1, 1)
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            primaryCount = 0
            wait(0)
        }
        // the S34 card: 172 dp at x 20, y 84
        function card(flags) {
            var s = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; SwipeToReveal { x: 20; y: 84; width: 344; height: 172; '
                + flags + ' Rectangle { anchors.fill: parent; radius: 52; color: "#2F3036" } }', host)
            s.primaryAction.connect(function() { top.primaryCount++ })
            return s
        }
        // press at local x0 and move by dx in steps of about step px (10), pause ms apart (16), holding
        function drag(s, x0, dx, step, pause) {
            mousePress(s, x0, 86)
            moveTo(s, x0, x0 + dx, step, pause)
        }
        function moveTo(s, x0, x1, step, pause) {
            var d = pause === undefined ? 16 : pause
            var n = Math.max(1, Math.round(Math.abs(x1 - x0) / (step || 10)))
            for (var i = 1; i <= n; i++) {
                mouseMove(s, x0 + (x1 - x0) * i / n, 86, d, Qt.LeftButton)
                wait(d)
            }
        }
        function pill(s) { return findChild(s, "swipeRevealPill") }

        function test_1_lag() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            compare(s.dragLag, 58, "29 dp")
            drag(s, 80, 50)
            compare(s.offset, 0, "50 px from the press: the card has not moved yet")
            moveTo(s, 130, 160)
            near(s.offset, 22, 0.5, "80 px right: 22 px (0.28 of the finger)")
            near(pill(s).width, 18, 0.5, "pill |offset| - 4")
            moveTo(s, 160, 240)
            near(s.offset, 102, 0.5, "160 px right: 102 px as S34 (0.64 of the finger)")
            near(pill(s).width, 98, 0.5, "pill 98 px as S34")
            moveTo(s, 240, 320)
            near(s.offset, 182, 0.5, "then 1:1 as M10: 80 px more finger, 80 px more card")
            moveTo(s, 320, 200)
            near(s.offset, 62, 0.5, "back with the finger 1:1")
            mouseRelease(s, 200, 86)
            wait(500)
            // released slowly: the nearer anchor, the partial one (114.7 px) rather than covered
            compare(s.state_, "revealing", "62 px released slowly: the nearer anchor")
            near(s.offset, s.revealingOffset, 0.5, "at the single-action partial anchor")
            s.reset()
            wait(50)
            // the left, as S34-b (DOWN 290 = local 270)
            drag(s, 270, -80)
            near(s.offset, -22, 0.5, "80 px left: -22 px")
            moveTo(s, 190, 110)
            near(s.offset, -102, 0.5, "160 px left: -102 px as S34-b")
            var p = pill(s)
            near(p.width, 98, 0.5, "pill 98 px")
            near(p.mapToItem(top, 0, 0).x + p.width, 364, 0.5, "pill to the card's rest edge (S34-b 267-364)")
            waitForRendering(s)
            var img = grabImage(top)
            img.save("shots/swipe-s34b.png")
            pixelNear(img, 300, 170, "#343B4D", 2, "pill colour")
            pixelNear(img, 263, 170, "#000000", 2, "4 px gap")
            mouseRelease(s, 110, 86)
            wait(500)
            compare(primaryCount, 0, "no clear")
        }

        // S34 replayed: DOWN at 100, MOVEs 120 ... 260 (20-30 px apart), held
        function test_2_asS34() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            mousePress(top, 100, 170)
            var xs = [120, 150, 180, 210, 240, 260]
            for (var i = 0; i < xs.length; i++) {
                mouseMove(top, xs[i], 170, 16, Qt.LeftButton)
                wait(100)
            }
            near(s.offset, 102, 0.5, "card 102 px out")
            waitForRendering(s)
            var img = grabImage(top)
            img.save("shots/swipe-s34.png")
            var p = pill(s)
            near(p.mapToItem(top, 0, 0).x, 20, 0.5, "pill from the card's rest edge (S34 19)")
            near(p.width, 98, 0.5, "pill 98 px (S34 19-116)")
            pixelNear(img, 30, 170, "#343B4D", 2, "pill colour")
            pixelNear(img, 119, 170, "#000000", 2, "the gap (S34 117-120)")
            pixelNear(img, 126, 200, "#2F3036", 2, "the card from x 122 (S34 121)")
            mouseRelease(top, 260, 170)
            wait(500)
            // let go after the hold (no fling): the nearest anchor, the partial reveal
            compare(s.state_, "revealing", "S34 let go: the partial reveal")
            near(s.offset, 114.67, 0.5, "at 114.7 px (64 dp x 344 / 384)")
            compare(primaryCount, 0, "no clear")
        }

        // thresholds in the card's space; a full swipe emits once
        function test_3_fullSwipe() {
            var s = card("bidirectional: true; expressiveLook: true;")
            wait(50)
            // the partial anchor (232.9 px of card) is reached at 291 px of finger
            drag(s, 330, -285)
            compare(s.state_, "covered", "227 px of card: not yet the partial anchor")
            moveTo(s, 330 - 285, 330 - 292)
            compare(s.state_, "revealing", "234 px of card: the partial anchor")
            // the full threshold (268 px of card) at 326 px of finger
            moveTo(s, 330 - 292, 330 - 330)
            near(s.offset, -272, 0.5, "272 px of card")
            mouseRelease(s, 0, 86)
            wait(600)
            // stock: released slowly, the nearer anchor (half way to the full one is 288.5 px);
            // CP3A's 268 px threshold is not used
            compare(s.state_, "revealing", "272 px released slowly: the partial anchor")
            near(s.offset, -s.revealingOffset, 0.5, "at the partial anchor")
            compare(primaryCount, 0, "no clear")
            s.reset()
            wait(50)
            // the same 272 px let go moving (110 px steps a few ms apart): the full reveal
            drag(s, 330, -330, 110, 4)
            near(s.offset, -272, 0.5, "272 px of card, moving")
            mouseRelease(s, 0, 86)
            wait(600)
            compare(s.state_, "revealed", "let go moving left: revealed")
            near(s.offset, -344, 0.5, "off to the left")
            compare(primaryCount, 1, "primaryAction once")
            wait(300)
            compare(primaryCount, 1, "still once")
            s.reset()
            // a fling (100 px steps a few ms apart, far over 1600 px/s) to the right from rest,
            // released at 242 px of card (under the 268 px threshold)
            drag(s, 40, 300, 100, 4)
            near(s.offset, 242, 0.5, "300 px of finger: 242 px of card")
            mouseRelease(s, 340, 86)
            wait(600)
            compare(s.state_, "revealed", "a fast fling reveals")
            near(s.offset, 344, 0.5, "off to the right")
            compare(primaryCount, 2, "primaryAction once more")
            wait(300)
            compare(primaryCount, 2, "still once")
            s.reset()
            // a quick flick to the left that never moved the card is not a fling
            drag(s, 300, -56, 14, 4)
            compare(s.offset, 0, "not moved")
            mouseRelease(s, 244, 86)
            wait(500)
            compare(s.state_, "covered", "stays covered")
            compare(primaryCount, 2, "no clear")
            // the thresholds themselves are unchanged
            near(s.revealingOffset, 232.9, 0.1, "partial anchor")
            compare(s.fullThreshold, 268, "full threshold")
            compare(s.decide(116.5, 0), "revealing", "half the partial anchor, in card px")
            compare(s.decide(116, 0), "covered", "under half")
        }

        // flags off (the Timer's list) and bidirectional alone: 1:1 from the press as before
        function test_4_flagsOff() {
            var s = card("")
            wait(50)
            compare(s.dragLag, 0, "no lag")
            drag(s, 300, -80)
            near(s.offset, -80, 0.5, "80 px left: 80 px")
            moveTo(s, 220, 140)
            near(s.offset, -160, 0.5, "160 px left: 160 px")
            mouseRelease(s, 140, 86)
            wait(500)
            compare(s.state_, "revealing", "160 px released: the partial reveal (as before)")
            s.reset()
            drag(s, 100, 160)
            compare(s.offset, 0, "a rightward drag on a covered card is the back swipe's")
            mouseRelease(s, 260, 86)
            wait(100)
            s.destroy()
            wait(0)
            var b = card("bidirectional: true;")
            wait(50)
            compare(b.dragLag, 0, "no lag without expressiveLook")
            drag(b, 100, 160)
            near(b.offset, 160, 0.5, "bidirectional alone: 1:1")
            mouseRelease(b, 260, 86)
            wait(500)
        }

        // r2-63: stock's release rule at 150, 300, 600 and 900 dp/s both ways
        function releaseAt(s, from, v) {
            s.reset()
            s.offset = from
            s._release(v)
            wait(700)
        }
        function stateOf(anchor) {
            return anchor === 0 ? "covered" : Math.abs(anchor) >= 344 ? "revealed" : "revealing"
        }
        function bands(s, cases, tag0) {
            var cleared = top.primaryCount
            for (var i = 0; i < cases.length; i++) {
                var c = cases[i]
                var tag = tag0 + " from " + c[0] + " px at " + (c[1] / 2) + " dp/s"
                releaseAt(s, c[0], c[1])
                near(s.offset, c[2], 0.5, tag)
                compare(s.state_, stateOf(c[2]), tag)
                if (stateOf(c[2]) === "revealed")
                    cleared++
                compare(top.primaryCount, cleared, tag + ": primaryAction once per full reveal")
            }
            s.reset()
            wait(300)
            compare(top.primaryCount, cleared, tag0 + ": no late action")
        }
        function test_5_releaseBands() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            var sec = 0
            s.secondaryAction.connect(function() { sec++ })
            wait(50)
            var R = s.revealingOffset, W = 344
            near(R, 114.67, 0.01, "stock's single-action anchor: 64 dp x 344 / 384")
            compare(s.anchorVelocity, 400, "200 dp/s")
            compare(s.flingVelocity, 1600, "800 dp/s")
            compare(s.stopTime, 40, "40 ms")
            // [card offset, velocity px/s (negative = left), the anchor it goes to]
            bands(s, [
                // 150 dp/s: the nearer of the two anchors around the card
                [-60, -300, -R], [-60, 300, -R], [-40, -300, 0], [-40, 300, 0],
                [-200, -300, -R], [-200, 300, -R], [-240, -300, -W], [-240, 300, -W],
                [60, -300, R], [60, 300, R],
                // 300 dp/s: the next anchor in the finger's direction
                [-60, -600, -R], [-60, 600, 0], [-200, -600, -W], [-200, 600, -R],
                [60, 600, R], [60, -600, 0], [200, 600, W], [200, -600, R],
                // 600 dp/s: the same
                [-60, -1200, -R], [-60, 1200, 0], [-200, -1200, -W], [-200, 1200, -R],
                [60, 1200, R], [60, -1200, 0],
                // 900 dp/s: the last anchor that way (the other side's full reveal too)
                [-60, -1800, -W], [-60, 1800, W], [60, 1800, W], [60, -1800, -W],
                [-R, 1800, W], [0, -1800, -W]
            ], "both ways")
            // the card exactly at an anchor stays there at 300 dp/s (stock's closestAnchor)
            releaseAt(s, -R, -600)
            near(s.offset, -R, 0.5, "at the partial anchor, 300 dp/s left: stays")
            // decide() and release() give the same anchors (decide mirrored by the side)
            compare(s.decide(60, -300), "revealing", "decide: 60 px at 150 dp/s towards the side")
            compare(s.decide(60, 600), "covered", "decide: 300 dp/s away from the side")
            compare(s.decide(200, -1200), "revealed", "decide: 600 dp/s towards the side")
            compare(s.decide(60, 1800), "revealed", "decide: 900 dp/s away: the other side's full reveal")
            s.reset()
            s.release(200, -1200)
            wait(700)
            near(s.offset, -W, 0.5, "release(200, -1200): off to the left")
            compare(sec, 0, "no secondary action")
            s.destroy()
            wait(0)
            // one way only: the last anchor to the right is covered
            var o = card("expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            bands(o, [[-60, 1800, 0], [-200, 1800, 0], [-60, -1800, -W], [-200, 300, -o.revealingOffset],
                      [-200, 600, -o.revealingOffset], [-60, -600, -o.revealingOffset]], "left only")
        }

        // M10 / V10 replayed (input swipe 80 -> 340 in 200 ms: 12 moves of 21.7 px about
        // 16 ms apart): the card 202 px out at about 650 dp/s; the next anchor to the right is
        // the full reveal (the partial one is 114.7 px), so the card clears as in the emulator
        function swipe12(x0, x1) {
            mousePress(top, x0, 170)
            var t0 = Date.now()
            for (var i = 1; i <= 12; i++)
                mouseMove(top, x0 + (x1 - x0) * i / 12, 170, 16, Qt.LeftButton)
            return Math.abs(x1 - x0) * 1000 / Math.max(1, Date.now() - t0)
        }
        function test_6_asM10() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            var v = swipe12(80, 340)
            near(s.offset, 202, 0.5, "the card 58 px behind the finger")
            verify(v >= s.anchorVelocity && v < s.flingVelocity, "the replay at " + v.toFixed(0) + " px/s, stock 1300")
            mouseRelease(top, 340, 170)
            wait(700)
            compare(s.state_, "revealed", "M10: cleared")
            near(s.offset, 344, 0.5, "off to the right")
            compare(top.primaryCount, 1, "primaryAction once")
            s.reset()
            wait(500)
            v = swipe12(320, 60)
            near(s.offset, -202, 0.5, "the left side")
            mouseRelease(top, 60, 170)
            wait(700)
            compare(s.state_, "revealed", "the same to the left: cleared")
            near(s.offset, -344, 0.5, "off to the left")
            compare(top.primaryCount, 2, "primaryAction once more")
            wait(300)
            compare(top.primaryCount, 2, "still")
        }

        // a finger that stops (40 ms) before it lets go is no fling: the nearest anchor
        function test_7_stoppedThenLetGo() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            swipe12(330, 72)
            near(s.offset, -200, 0.5, "card 200 px out")
            wait(200)
            mouseRelease(top, 72, 170)
            wait(700)
            compare(s.state_, "revealing", "held, then let go: the nearer anchor")
            near(s.offset, -s.revealingOffset, 0.5, "the partial reveal")
            compare(top.primaryCount, 0, "no clear")
            s.reset()
            wait(500)
            swipe12(330, 72)
            mouseRelease(top, 72, 170)
            wait(700)
            compare(s.state_, "revealed", "let go moving: the full reveal")
            compare(top.primaryCount, 1, "once")
        }

        // with a secondary action (a call's mute) the partial anchor stays 130 dp x 344 / 384:
        // the M10 release stops there; the gear emits once
        function test_8_secondary() {
            var s = card("bidirectional: true; expressiveLook: true;")
            var sec = 0
            s.secondaryAction.connect(function() { sec++ })
            wait(50)
            near(s.revealingOffset, 232.9, 0.1, "the two-action anchor")
            releaseAt(s, 202, 1300)
            compare(s.state_, "revealing", "650 dp/s at 202 px: the next anchor, the partial one")
            near(s.offset, 232.9, 0.5, "at 232.9 px")
            compare(top.primaryCount, 0, "no clear")
            var g = findChild(s, "swipeRevealSecondary")
            mouseClick(g, g.width / 2, g.height / 2)
            compare(sec, 1, "secondaryAction once")
            wait(700)
            compare(s.state_, "covered", "covered after the gear")
            compare(top.primaryCount, 0, "no clear")
            compare(sec, 1, "still once")
        }

        // flags off (the Timer's list) and bidirectional alone: the CP3A rule at every speed
        function test_9_flagsOffBands() {
            var s = card("")
            wait(50)
            var R = s.revealingOffset
            near(R, 232.9, 0.1, "CP3A anchor (also without a secondary action)")
            bands(s, [
                [-60, -300, 0], [-60, 300, 0], [-60, -600, 0], [-60, 600, 0], [-60, -1200, 0], [-60, 1200, 0],
                [-60, -1800, -344], [-60, 1800, 0],
                [-200, -300, -R], [-200, 300, -R], [-200, -600, -R], [-200, 1200, -R], [-200, 1800, -R],
                [-272, -300, -344], [-272, 300, -344]
            ], "flags off")
            compare(s.decide(270, 0), "revealed", "CP3A: past 134 dp")
            compare(s.decide(60, 1800), "covered", "CP3A: a fling away covers")
            s.reset()
            wait(500)
            // a swipe as M10 to the left: 260 px at about 650 dp/s, released at 260 px: the partial reveal as before
            var v = swipe12(340, 80)
            near(s.offset, -260, 0.5, "1:1")
            verify(v < s.flingVelocity, "the replay at " + v.toFixed(0) + " px/s")
            mouseRelease(top, 80, 170)
            wait(700)
            compare(s.state_, "revealing", "CP3A: the partial reveal")
            near(s.offset, -R, 0.5, "at 232.9 px")
            s.destroy()
            wait(0)
            var b = card("bidirectional: true; hasSecondaryAction: false;")
            wait(50)
            near(b.revealingOffset, 232.9, 0.1, "CP3A anchor")
            bands(b, [[60, 1800, 344], [60, -1800, 0], [60, 300, 0], [200, -1200, 232.92], [-200, 1800, -232.92]], "bidirectional alone")
        }
    }
}
