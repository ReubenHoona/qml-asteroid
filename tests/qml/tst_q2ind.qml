// WO-61-Q2 N61-03: the scroll indicator in the system UI's style when
// RotaryInput.systemIndicator is set (the launcher), the M3 style in apps
// and for a view with m3Indicator: true. Stock: the Wear OS 6 emulator,
// SysUI lists S05 / S11 (thumb #FFFFFF, track #4D4D4D, -17 to +17 degrees
// at radius 183, stroke radius 179-188) and M3 screens S16 / S28 / S30-b /
// S14-d (thumb #C6C6C7, track about #2F2F2F, +-16 degrees).
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
        width: 384
        height: 384
        Flickable {
            id: list
            anchors.fill: parent
            contentHeight: 1200
        }
        Flickable {
            id: m3list
            property bool m3Indicator: true
            anchors.fill: parent
            contentHeight: 1200
        }
        PositionIndicator {
            id: pi
        }
    }

    TestCase {
        name: "Q2ind"
        when: windowShown

        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004,
                   msg + ": " + A + " != " + B)
        }
        // a rendered pixel: within 3/255 (antialiased segment joins)
        function closeColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.013 && Math.abs(A.g - B.g) < 0.013 && Math.abs(A.b - B.b) < 0.013,
                   msg + ": " + A + " != " + B)
        }
        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " not within " + tol + " of " + b)
        }
        function hex(p) {
            function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
            return "#" + h(p.r) + h(p.g) + h(p.b)
        }
        function cleanup() {
            RotaryInput.systemIndicator = false
            pi.flickable = null
            pi.shown = false
        }

        function test_01_tokens() {
            compare(RotaryInput.systemIndicator, false, "off by default (apps)")
            sameColor(Theme.color.scrollThumbSystem, "#FFFFFF", "system thumb")
            sameColor(Theme.color.scrollTrackSystem, "#4D4D4D", "system track")
            compare(Theme.size.scrollIndicatorSweepSystem, 34, "34 degrees")
            // the app style is unchanged
            sameColor(Theme.color.scrollThumb, "#C6C6C6", "M3 thumb")
            sameColor(Theme.color.scrollTrack, "#303030", "M3 track")
            compare(Theme.size.scrollIndicatorLength, 100, "M3 50 dp")
        }

        function test_02_appStyle() {
            pi.flickable = list
            verify(!pi.systemStyle)
            sameColor(pi.thumbColor, "#C6C6C6", "app thumb")
            sameColor(pi.trackColor, "#303030", "app track")
            near(pi._radius, 183, 0.01, "track radius")
            near(pi._length, 100, 0.01, "50 dp along the track")
            near(pi.sweepDegrees, 100 / 183 * 180 / Math.PI, 0.01, "about 31.3 degrees")
            compare(pi.gap, 6, "3 dp gaps")
            compare(pi._thickness, 10, "5 dp stroke")
        }

        function test_03_systemStyle() {
            RotaryInput.systemIndicator = true
            pi.flickable = list
            verify(pi.systemStyle)
            sameColor(pi.thumbColor, "#FFFFFF", "system thumb")
            sameColor(pi.trackColor, "#4D4D4D", "system track")
            compare(pi.sweepDegrees, 34, "34 degrees")
            near(pi._length, 183 * 34 * Math.PI / 180, 0.01, "108.6 px along the track")
            compare(pi.gap, 6, "the same 3 dp gaps")
            compare(pi._thickness, 10, "the same stroke")
            // a view that asks for the app style keeps it (the tile picker, S14-d)
            pi.flickable = m3list
            verify(!pi.systemStyle)
            sameColor(pi.thumbColor, "#C6C6C6", "m3Indicator thumb")
            sameColor(pi.trackColor, "#303030", "m3Indicator track")
            near(pi._length, 100, 0.01, "m3Indicator 50 dp")
            // and the flag follows at run time
            pi.flickable = list
            RotaryInput.systemIndicator = false
            sameColor(pi.thumbColor, "#C6C6C6", "back to the app style")
        }

        // the ink along radius 183 as the plan measured the screenshots
        function arc(view, system) {
            RotaryInput.systemIndicator = system
            view.contentY = (view.contentHeight - view.height) / 2   // thumb in the middle
            pi.flickable = view
            pi.flash()
            tryCompare(pi, "opacity", 1, 2000)
            wait(700)   // the 500 ms thumb animation
            waitForRendering(top)
            var img = grabImage(top)
            var cx = 191.5, cy = 191.5
            var first = null, last = null
            for (var a = -25; a <= 25.001; a += 0.25) {
                var r = a * Math.PI / 180
                var p = img.pixel(Math.round(cx + 183 * Math.cos(r)), Math.round(cy + 183 * Math.sin(r)))
                if (p.r + p.g + p.b > 0.15) {
                    if (first === null) first = a
                    last = a
                }
            }
            // radii as the screenshot script took them: x = int(191.5 + r)
            var radial = []
            for (var rad = 168; rad < 192; rad++) {
                var q = img.pixel(Math.floor(cx + rad), Math.floor(cy))
                if (q.r + q.g + q.b > 0.15) radial.push(rad)
            }
            return { img: img, first: first, last: last, r0: radial[0], r1: radial[radial.length - 1],
                     at: function (deg) {
                         var rr = deg * Math.PI / 180
                         return this.img.pixel(Math.round(cx + 183 * Math.cos(rr)), Math.round(cy + 183 * Math.sin(rr)))
                     } }
        }

        function test_04_renderSystem() {
            var m = arc(list, true)
            closeColor(m.at(0), "#FFFFFF", "radius 183 at 0 degrees: thumb " + hex(m.at(0)))
            closeColor(m.at(12), "#4D4D4D", "track below the thumb " + hex(m.at(12)))
            closeColor(m.at(-12), "#4D4D4D", "track above the thumb " + hex(m.at(-12)))
            near(m.first, -17, 0.5, "ink starts at -17 degrees")
            near(m.last, 17, 0.5, "ink ends at +17 degrees")
            // stroke radius 178-188 (S05 / S11: 179-188 by the same method)
            near(m.r0, 178.5, 1, "inner edge " + m.r0)
            compare(m.r1, 188, "outer edge 4 px inside the bezel")
            // the arc spans y 138-245 (the watch check after L3)
            near(191.5 - 183 * Math.sin(17 * Math.PI / 180), 138, 1, "top of the arc")
        }

        function test_05_renderApp() {
            var m = arc(list, false)
            closeColor(m.at(0), "#C6C6C6", "app thumb " + hex(m.at(0)))
            closeColor(m.at(12), "#303030", "app track " + hex(m.at(12)))
            near(m.first, -15.65, 0.5, "50 dp: ink from -15.7 degrees")
            near(m.last, 15.65, 0.5, "to +15.7 degrees")
            var m2 = arc(m3list, true)
            closeColor(m2.at(0), "#C6C6C6", "m3Indicator under the system flag " + hex(m2.at(0)))
            near(m2.last, 15.65, 0.5, "m3Indicator keeps 50 dp")
        }
    }
}
