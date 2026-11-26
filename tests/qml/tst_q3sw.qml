// WO-61-Q3 N61-06: the small Wear switch with its Material 3 and Material 2
// colour sets. Stock: the Wear OS 6 emulator, Settings S20-b (Battery Saver
// off: track x 288-335, y 166-185 on #2F3036, thumb #8B8B8F x 288-315),
// S18-b (Always-on screen on: thumb #D4C7FF x 308-335), Clock S29-b / S29-d
// (on #454648: thumb #FDE293 / #999999, track #8A8164 / #8B8C8D, y 121-140).
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    Rectangle {
        id: host
        anchors.fill: parent
        color: "#000000"
    }

    TestCase {
        id: tc
        name: "Q3switch"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
                   && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
        }
        // a pixel within tol (0..255) of hex
        function pixelNear(img, x, y, hex, tol, msg) {
            var p = img.pixel(x, y), c = Qt.color(hex)
            var d = Math.max(Math.abs(p.r - c.r), Math.abs(p.g - c.g), Math.abs(p.b - c.b)) * 255
            verify(d <= tol, msg + " at " + x + "," + y + ": " + p + " != " + hex + " (" + d.toFixed(1) + ")")
        }
        function cleanup() {
            Theme.materialVersion = 3
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            wait(0)
        }
        function make(src) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; ' + src, host)
        }
        // a 344 x 104 chip at x 20 with the switch 28 px from its end, as stock
        function chipWithSwitch(fill, checked) {
            return make('Rectangle { x: 20; y: 124; width: 344; height: 104; radius: 52; color: "' + fill + '";'
                        + ' property alias sw: s; Switch { id: s; x: parent.width - 28 - width;'
                        + ' anchors.verticalCenter: parent.verticalCenter; checked: ' + checked
                        + '; containerColor: "' + fill + '" } }')
        }

        function test_1_geometry() {
            compare(Theme.size.switchTrackWidth, 48, "track 24 dp")
            compare(Theme.size.switchTrackHeight, 20, "track 10 dp")
            compare(Theme.size.switchTrackBorder, 0, "no border")
            compare(Theme.size.switchThumbOff, 28, "thumb 14 dp off")
            compare(Theme.size.switchThumbOn, 28, "thumb 14 dp on")
            var sw = make('Switch { }')
            compare(sw.width, 48, "implicit width 24 dp")
            compare(sw.height, 28, "implicit height 14 dp")
            wait(250)
            compare(sw.progress, 0, "off")
            compare(sw._thumb.x, 0, "off thumb box from x 0")
            compare(sw._thumb.width, 28, "off thumb 28 px")
            compare(sw._thumb.y, -4, "4 px over the track above")
            compare(sw._track.y, 4, "track centred in the 28 px slot")
            compare(sw.thumbCenter, 14, "off centre 7 dp")
            sw.checked = true
            wait(90)
            verify(sw.progress > 0.3 && sw.progress < 1, "moving at 90 ms: " + sw.progress)
            wait(200)
            compare(sw.progress, 1, "done after 177 ms")
            compare(sw._thumb.x, 20, "on thumb box x 20-47 (ink 21-46)")
            compare(sw.thumbCenter, 34, "on centre 17 dp")
            mouseClick(sw)
            compare(sw.checked, false, "a tap toggles")
        }

        function test_2_m3Colors() {
            var sw = make('Switch { }')
            wait(250)
            sameColor(sw.thumbColor, "#8B8B8F", "off thumb")
            sameColor(sw.trackColor, Qt.tint("#2F3036", Qt.rgba(0xE8 / 255, 0xE7 / 255, 0xEE / 255, 0.38)), "off track onSurface 38 % over surfaceContainer")
            sw.checked = true
            wait(300)
            sameColor(sw.thumbColor, "#D4C7FF", "on thumb tertiary")
            sameColor(sw.trackColor, Qt.tint("#2F3036", Qt.rgba(0xD4 / 255, 0xC7 / 255, 1, 0.38)), "on track tertiary 38 %")
            sw.containerColor = "transparent"
            sameColor(sw.trackColor, Qt.rgba(0xD4 / 255, 0xC7 / 255, 1, 0.38), "translucent without a container")
            sw.enabled = false
            sameColor(sw.thumbColor, Qt.rgba(0xE8 / 255, 0xE7 / 255, 0xEE / 255, 0.12), "disabled thumb onSurface 12 %")
            sameColor(sw.trackColor, Qt.rgba(0xE8 / 255, 0xE7 / 255, 0xEE / 255, 0.12), "disabled track onSurface 12 %")
        }

        function test_3_m2Colors() {
            Theme.materialVersion = 2
            var sw = make('Switch { containerColor: "#454648" }')
            wait(250)
            sameColor(sw.thumbColor, "#999999", "off thumb #999999")
            var t = sw.trackColor
            near(Math.round(t.r * 255), 0x8B, 1, "off track R"); near(Math.round(t.g * 255), 0x8C, 1, "off track G"); near(Math.round(t.b * 255), 0x8D, 1, "off track B")
            sw.checked = true
            wait(300)
            sameColor(sw.thumbColor, "#FDE293", "on thumb secondary")
            t = sw.trackColor
            near(Math.round(t.r * 255), 0x8A, 1, "on track R"); near(Math.round(t.g * 255), 0x81, 1, "on track G"); near(Math.round(t.b * 255), 0x64, 1, "on track B")
        }

        // rendered as stock: S20-b (M3 off on #2F3036) and S29-b / S29-d (M2 on #454648)
        function test_4_pixels() {
            var c = chipWithSwitch("#2F3036", false)
            wait(250)
            waitForRendering(c)
            var img = grabImage(top)
            img.save("shots/sw-m3-off.png")
            // the chip's switch box is x 288-335 (28 px in from 363), centred on y 176
            pixelNear(img, 301, 176, "#8B8B8F", 3, "off thumb centre")
            pixelNear(img, 289, 176, "#8B8B8F", 3, "off thumb from x 288")
            pixelNear(img, 324, 176, "#74757C", 3, "off track")
            pixelNear(img, 324, 167, "#74757C", 3, "track top row 166")
            pixelNear(img, 324, 164, "#2F3036", 3, "chip above the track")
            pixelNear(img, 301, 164, "#8B8B8F", 3, "thumb 4 px over the track")
            verify(img.pixel(301, 190).r * 255 < 0x2F - 4, "the shadow under the thumb: " + img.pixel(301, 190))
            c.sw.checked = true
            wait(300)
            waitForRendering(c)
            img = grabImage(top)
            img.save("shots/sw-m3-on.png")
            pixelNear(img, 321, 176, "#D4C7FF", 3, "on thumb")
            pixelNear(img, 334, 176, "#D4C7FF", 3, "on thumb to x 335")
            pixelNear(img, 298, 176, "#6E6982", 4, "on track over #2F3036")
            c.destroy()

            Theme.materialVersion = 2
            c = chipWithSwitch("#454648", true)
            wait(300)
            waitForRendering(c)
            img = grabImage(top)
            img.save("shots/sw-m2-on.png")
            pixelNear(img, 321, 176, "#FDE293", 3, "M2 on thumb")
            pixelNear(img, 298, 176, "#8A8164", 3, "M2 on track")
            c.sw.checked = false
            wait(300)
            waitForRendering(c)
            img = grabImage(top)
            img.save("shots/sw-m2-off.png")
            pixelNear(img, 301, 176, "#999999", 3, "M2 off thumb")
            pixelNear(img, 324, 176, "#8B8C8D", 3, "M2 off track")
        }
    }
}
