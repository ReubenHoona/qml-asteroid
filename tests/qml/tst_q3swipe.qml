// WO-61-Q3 N61-09: SwipeToReveal both ways and the expressive pill (opt-in).
// Stock: the Wear OS 6 emulator S34 / S34-b (card x 19-364, y 84-255 held
// about 102 px right / left: pill #343B4D x 19-116 / 267-364, y 86-253,
// X #D9E0F7 ink 28 px centred, 4 px gap to the card) and V10 (the X fades
// in by 80 px of pill, 'Clear' only near full width).
// Q5: under expressiveLook the card starts 29 dp (58 px) after the press, then 1:1
// (S34: 160 px held = 102 px; M10), so the drags below are 58 px longer than in Q3.
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
    property int secondaryCount: 0

    TestCase {
        id: tc
        name: "Q3swipe"
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
            secondaryCount = 0
            wait(0)
        }
        function card(flags) {
            var s = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; SwipeToReveal { x: 20; y: 84; width: 344; height: 172; '
                + flags + ' Rectangle { anchors.fill: parent; radius: 52; color: "#2F3036" } }', host)
            s.primaryAction.connect(function() { top.primaryCount++ })
            s.secondaryAction.connect(function() { top.secondaryCount++ })
            return s
        }
        // press at local x0 and drag by dx in 10 px steps, holding
        function drag(s, x0, dx) {
            mousePress(s, x0, 86)
            var n = Math.max(1, Math.round(Math.abs(dx) / 10))
            for (var i = 1; i <= n; i++) {
                mouseMove(s, x0 + dx * i / n, 86, 10, Qt.LeftButton)
                wait(16)
            }
        }
        function pill(s) { return findChild(s, "swipeRevealPill") }

        function test_1_token() {
            var c = Qt.color(Theme.color.swipeRevealContainer)
            compare(Math.round(c.r * 255), 0x34); compare(Math.round(c.g * 255), 0x3B); compare(Math.round(c.b * 255), 0x4D)
        }

        function test_2_rightAndLeft() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            drag(s, 100, 218)
            near(s.offset, 160, 1, "follows the finger to the right")
            compare(s.side, 1, "right side")
            compare(s.state_, "revealing", "160 px: past stock's single-action partial anchor (114.7 px)")
            var p = pill(s)
            verify(p !== null, "the pill")
            near(p.width, 156, 0.5, "pill |offset| - 4")
            near(p.height, 168, 0.5, "pill the card's height - 4")
            near(p.mapToItem(top, 0, 0).x, 20, 0.5, "pill on the left, from the card's rest edge")
            near(p.mapToItem(top, 0, 0).y, 86, 0.5, "pill 2 px under the card's top")
            waitForRendering(s)
            var img = grabImage(top)
            img.save("shots/q3-swipe-right160.png")
            pixelNear(img, 30, 170, "#343B4D", 2, "pill colour")
            pixelNear(img, 177, 170, "#000000", 2, "4 px gap")
            pixelNear(img, 200, 170, "#2F3036", 2, "the card after the gap")
            mouseRelease(s, 318, 86)
            wait(400)
            compare(s.state_, "revealing", "160 px released slowly: the nearer anchor, the partial reveal")
            near(s.offset, s.revealingOffset, 0.5, "right partial anchor")
            s.reset()
            drag(s, 300, -218)
            near(s.offset, -160, 1, "follows the finger to the left")
            compare(s.side, -1, "left side")
            p = pill(s)
            near(p.width, 156, 0.5, "pill |offset| - 4 on the right")
            near(p.mapToItem(top, 0, 0).x + p.width, 364, 0.5, "pill to the card's rest edge at the right")
            waitForRendering(s)
            img = grabImage(top)
            img.save("shots/q3-swipe-left160.png")
            pixelNear(img, 350, 170, "#343B4D", 2, "pill on the right")
            mouseRelease(s, 82, 86)
            wait(400)
            compare(primaryCount, 0, "no clear")
        }

        // held as S34 (about 102 px right): pill x 20-117 (stock 19-116), the X full
        function test_3_asS34() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            drag(s, 100, 160)
            waitForRendering(s)
            var img = grabImage(top)
            img.save("shots/q3-swipe-s34.png")
            var p = pill(s)
            near(p.width, 98, 0.5, "98 px pill as S34")
            // the X (Icon draws nothing in this harness: checked as an item)
            var icon = findChild(s, "swipeRevealIcon")
            compare(icon.name, "ms-close", "the Material close glyph")
            compare(icon.width, 48, "24 dp")
            compare(icon.opacity, 1, "full at 98 px")
            var ic = icon.color
            verify(Math.abs(ic.r - 0xD9 / 255) < 0.004 && Math.abs(ic.g - 0xE0 / 255) < 0.004 && Math.abs(ic.b - 0xF7 / 255) < 0.004, "onPrimaryContainer: " + ic)
            var c = icon.mapToItem(top, icon.width / 2, icon.height / 2)
            near(c.x, 69, 0.5, "centred in the pill (stock ink 52-79, centre 66 in 19-116)")
            near(c.y, 170, 0.5, "centred vertically (stock ink 156-183)")
            pixelNear(img, 60, 120, "#343B4D", 2, "pill colour")
            mouseRelease(s, 260, 86)
        }

        function test_4_fades() {
            var s = card("bidirectional: true; expressiveLook: true; hasSecondaryAction: false;")
            wait(50)
            var icon = findChild(s, "swipeRevealIcon"), label = findChild(s, "swipeRevealLabel")
            s.offset = 46     // a 42 px pill
            compare(icon.opacity, 0, "no X at 42 px (V10 f35)")
            s.offset = 66     // 62 px
            near(icon.opacity, 0.44, 0.1, "the X fading in at 62 px (V10 f36: 0.38)")
            s.offset = 84     // 80 px
            compare(icon.opacity, 1, "the X full at 80 px (V10 f37)")
            s.offset = 0.75 * 344
            compare(label.opacity, 0, "no label at 75 % of the card")
            s.offset = 0.9 * 344
            near(label.opacity, 0.6, 0.01, "label fading in")
            s.offset = 344
            compare(label.opacity, 1, "label full at the card's width")
            var g = icon.parent
            near(icon.x + (icon.width + g.spacing + label.implicitWidth) / 2, g.width / 2, 0.5, "X and label centred as a group")
            var lc = label.color
            near(lc.a, 0.8, 0.01, "label onPrimaryContainer 80 %")
            compare(label.font.pixelSize, 32, "16 sp")
            waitForRendering(s)
            grabImage(top).save("shots/q3-swipe-full.png")
            s.reset()
        }

        function test_5_fullSwipeOnce() {
            var s = card("bidirectional: true; expressiveLook: true;")
            wait(50)
            // let go moving (stock: a slow release goes to the nearer anchor)
            mousePress(s, 330, 86)
            for (var i = 1; i <= 3; i++) {
                mouseMove(s, 330 - 110 * i, 86, 4, Qt.LeftButton)
                wait(4)
            }
            mouseRelease(s, 0, 86)
            wait(600)
            compare(s.state_, "revealed", "let go moving: revealed")
            near(s.offset, -344, 0.5, "the card off to the left")
            compare(primaryCount, 1, "primaryAction once")
            wait(300)
            compare(primaryCount, 1, "still once")
            s.reset()
            // a fling towards the card's side, mirrored: right
            s.offset = 60
            s._release(1700)
            wait(600)
            near(s.offset, 344, 0.5, "a fast fling to the right reveals on the right")
            compare(primaryCount, 2, "and clears")
            s.reset()
            compare(s.decide(60, -1700), "revealed", "a fast fling reveals")
            compare(s.decide(60, 1700), "revealed", "a fast fling the other way: the other side's full reveal (stock)")
        }

        function test_6_partialBothSides() {
            var s = card("bidirectional: true; expressiveLook: true;")
            wait(50)
            drag(s, 40, 300)
            compare(s.state_, "revealing", "partial reached on the right")
            mouseRelease(s, 340, 86)
            wait(400)
            near(s.offset, s.revealingOffset, 0.5, "right partial anchor")
            s.settle("covered")
            wait(400)
            drag(s, 330, -300)
            compare(s.state_, "revealing", "partial reached on the left")
            mouseRelease(s, 30, 86)
            wait(400)
            near(s.offset, -s.revealingOffset, 0.5, "left partial anchor")
            s.reset()
        }

        // flags off: the CP3A list (the Timer's) behaves as before
        function test_7_flagsOff() {
            var s = card("")
            wait(50)
            compare(s.primaryIcon, "ios-close", "CP3A icon")
            drag(s, 100, 160)
            compare(s.offset, 0, "a rightward drag on a covered card is the back swipe's")
            mouseRelease(s, 260, 86)
            drag(s, 300, -160)
            near(s.offset, -160, 1, "leftwards follows")
            var p = pill(s)
            var pc = p.children[0].color
            verify(Math.abs(pc.r - 0xCD / 255) < 0.004 && Math.abs(pc.b - 0xEB / 255) < 0.004, "CP3A pill primaryDim: " + pc)
            near(p.mapToItem(top, 0, 0).x + p.width, 356, 0.5, "CP3A pill 4 dp from the edge")
            mouseRelease(s, 140, 86)
            wait(400)
            near(s.revealingOffset, 232.9, 0.1, "partial anchor as CP3A")
            compare(s.fullThreshold, 268, "full threshold as CP3A")
        }
    }
}
