// Host checks of the eos-ux controls under qemu-aarch64 (offscreen, software
// Qt Quick): crown scrolling and picker stepping (RotaryInput), the edge
// effect of ListItem, round-aware back swipe with fling (BorderGestureArea in
// LayerStack), PositionIndicator creation, LaunchSplash life cycle.
import QtQuick
import QtTest
import Nemo.Configuration
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            Repeater {
                model: 20
                ListItem { title: "Row " + index; iconName: "ios-help" }
            }
        }
    }

    CircularSpinner {
        id: spinner
        anchors.fill: parent
        model: 24
        visible: false
    }

    // the crown settings the image ships (meta-eos64 dconf 00-eos-defaults, read
    // from the rootfs under test): "Faster crown scrolling" on, 7.5 px per count
    // (the user's speed since 2026-10-28, f4d8eda and later); unset, RotaryInput
    // scrolls one Wear OS tick, 42 px of 384, per 24-count detent
    ConfigurationValue { id: crownFast; key: "/org/asteroidos/ux/crown-fast"; defaultValue: true }
    ConfigurationValue { id: crownPx; key: "/org/asteroidos/ux/rotary-px-per-count"; defaultValue: 0 }

    Component { id: firstPage; Item { } }
    Component { id: secondPage; Item { property int depth; property var pop } }

    LayerStack {
        id: stack
        anchors.fill: parent
        firstPage: firstPage
        win: null
        visible: false
    }

    Loader {
        id: splashLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("ref/LaunchSplash.qml")
    }

    function wheel(counts, gapMs) {
        var d = counts > 0 ? -120 : 120 // forward = negative angle (towards the end)
        for (var i = 0; i < Math.abs(counts); i++) {
            testCase.mouseWheel(top, 192, 192, 0, d)
            testCase.wait(gapMs)
        }
    }

    TestCase {
        id: testCase
        name: "EosUx"
        when: windowShown

        function init() {
            flick.visible = true
            spinner.visible = false
            stack.visible = false
            flick.contentY = 0
            wait(400) // let a previous gesture's crown session time out
        }

        function test_1_crown_scrolls_one_tick_per_detent() {
            top.wheel(24, 20) // one detent, slowly: no fling gain
            wait(400)
            // the image's setting, not the control default: 24 x 7.5 = 180 px per detent
            // with the shipped dconf; 42 px per detent on a 384 px screen without it
            verify(crownFast.value, "the faster crown (stock's 1.5 px a count and slop are another mode)")
            var px = Number(crownPx.value)
            var detent = px > 0 ? 24 * px : 42
            console.log("crown: " + (px > 0 ? px + " px per count (dconf)" : "default") + ", one detent " + detent + " px")
            verify(Math.abs(flick.contentY - detent) < 2.5, "contentY " + flick.contentY + " for " + detent)
        }

        function test_2_crown_stops_at_the_top() {
            top.wheel(-48, 5)
            wait(400)
            compare(flick.contentY, 0)
        }

        function test_3_fast_crown_goes_further() {
            top.wheel(48, 2)
            wait(500)
            verify(flick.contentY > 84 * 1.3, "fast spin gain, contentY " + flick.contentY)
        }

        function test_4_position_indicator_exists() {
            top.wheel(24, 20)
            wait(100)
            var found = null
            var kids = top.Window.contentItem.children
            for (var i = 0; i < kids.length; i++)
                if (kids[i].hasOwnProperty("flickable") && kids[i].hasOwnProperty("shown"))
                    found = kids[i]
            verify(found !== null, "PositionIndicator on the window")
            compare(found.flickable, flick)
            verify(found.shown)
        }

        function test_5_edge_effect() {
            flick.contentY = 0
            wait(50)
            var first = col.children[0]
            var middle = col.children[2] // y 160..240 centred at 200
            var s0 = first.transform[0].xScale
            var s2 = middle.transform[0].xScale
            verify(s0 < 0.95 && s0 >= 0.7, "top row scale " + s0)
            verify(s2 > 0.99, "middle row scale " + s2)
            flick.contentY = 40
            wait(50)
            verify(first.transform[0].xScale < s0, "shrinks further as it leaves")
        }

        function test_6_picker_steps_per_detent() {
            flick.visible = false
            spinner.visible = true
            spinner.currentIndex = 5
            wait(50)
            top.wheel(24, 10)
            compare(spinner.currentIndex, 6)
            top.wheel(-48, 10)
            compare(spinner.currentIndex, 4)
        }

        function test_7_round_edge_back_flick() {
            flick.visible = false
            stack.visible = true
            stack.push(secondPage)
            wait(400)
            compare(stack.layers.length, 1)
            // x=55 at y=100 is 31.5 px inside the circle (an edge swipe on a
            // round screen) but 55 px from x=0, outside the old 38 px strip
            mousePress(stack, 55, 100)
            for (var i = 1; i <= 5; i++) {
                mouseMove(stack, 55 + i * 16, 100)
                wait(16)
            }
            mouseRelease(stack, 135, 100)
            wait(500)
            compare(stack.layers.length, 0, "a quick short flick goes back")
        }

        function test_8_slow_short_drag_stays() {
            flick.visible = false
            stack.visible = true
            stack.push(secondPage)
            wait(400)
            mousePress(stack, 10, 192)
            for (var i = 1; i <= 10; i++) {
                mouseMove(stack, 10 + i * 8, 192)
                wait(40)
            }
            wait(150) // stop before lifting: no fling
            mouseRelease(stack, 90, 192)
            wait(500)
            compare(stack.layers.length, 1, "a slow 21% drag settles back")
            stack.pop(stack.currentLayer)
        }

        function test_9_launch_splash() {
            var s = splashLoader.item
            verify(s !== null, "LaunchSplash loads")
            s.start(Qt.rect(150, 150, 80, 80), "#ff0000", "#000000", "ios-help")
            verify(s.visible && s.active)
            wait(300)
            compare(s.progress, 1)
            s.finish()
            verify(!s.active)
            wait(400)
            verify(!s.visible)
        }
    }
}
