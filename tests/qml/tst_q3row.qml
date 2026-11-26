// WO-61-Q3 N61-07: row buttons. The checked toggle row's gradient, the
// second line in primary, disabled rows #80868B on their own container, and
// the Material 2 cases of SwitchButton, CheckboxButton and RadioButton.
// Stock: the Wear OS 6 emulator, S21 ('Mute ring & notifications' on, chip
// x 20-363, y 123-226), S18-b, S20, S23-b.
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
        name: "Q3row"
        when: windowShown

        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
                   && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
        }
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

        function test_1_tokens() {
            sameColor(Theme.color.disabledContentFlat, "#80868B", "disabledContentFlat")
            compare(Theme.alpha.checkedGradient, 0.325, "primary at 32.5 % in the far corner")
        }

        function test_2_tonalButton() {
            var b = make('Button { x: 20; width: 344; variant: "tonal"; text: "Go to watch face"; secondaryText: "After 1 minute" }')
            sameColor(b.containerColor, "#2F3036", "tonal surfaceContainer")
            sameColor(b.contentColor, "#E8E7EE", "label onSurface")
            sameColor(b.secondaryContentColor, "#DBE2F9", "second line primary (S18-b, S20)")
            sameColor(b.iconColor, "#DBE2F9", "icon primary")
            compare(b.checkedGradient, 0, "no gradient by default")
            b.enabled = false
            sameColor(b.containerColor, "#2F3036", "disabled keeps its container (S23-b)")
            sameColor(b.contentColor, "#80868B", "disabled label #80868B")
            sameColor(b.secondaryContentColor, "#80868B", "disabled second line #80868B")
            sameColor(b.iconColor, "#80868B", "disabled icon #80868B")
            // filled buttons keep their disabled look
            var f = make('Button { enabled: false; text: "OK" }')
            sameColor(f.containerColor, Qt.rgba(0xE8 / 255, 0xE7 / 255, 0xEE / 255, 0.12), "filled disabled container")
            sameColor(f.contentColor, Qt.rgba(0xE8 / 255, 0xE7 / 255, 0xEE / 255, 0.38), "filled disabled content")
            Theme.materialVersion = 2
            b.enabled = true
            sameColor(b.secondaryContentColor, "#FFFFFF", "Material 2: the second line is the content colour")
            sameColor(b.iconColor, "#FFFFFF", "Material 2: the icon is the content colour")
            b.enabled = false
            sameColor(b.containerColor, "#303133", "Material 2 disabled keeps its container")
            sameColor(b.secondaryContentColor, "#80868B", "Material 2 disabled second line")
        }

        function test_3_switchRowColors() {
            var r = make('SwitchButton { x: 20; y: 123; width: 344; height: 104; text: "Mute ring"; secondaryText: "On" }')
            compare(r.trailingWidth, 48, "24 dp switch slot")
            wait(500)
            compare(r.checkedGradient, 0, "off: no gradient")
            sameColor(r.containerColor, "#2F3036", "off surfaceContainer")
            sameColor(r.contentColor, "#E8E7EE", "label onSurface")
            sameColor(r.secondaryContentColor, "#DBE2F9", "second line primary")
            r.checked = true
            // N61-07: the gradient runs on a WearSpring (slow effects 1.0/260): 99 % at
            // 412 ms, at rest (its 0.001 visibility threshold) at about 573 ms of spring
            // time, which lags the wall clock under a loaded qemu (r2gh: 0.258 at 200 ms,
            // short of 1 at 600 ms, 3 runs of 21 on e43d1cb and this tree): seen moving,
            // then at rest, each within a bound
            tryVerify(function() { return r.checkedGradient > 0.3 && r.checkedGradient < 1 }, 600,
                      "gradient on the slow spring, part way: " + r.checkedGradient)
            tryCompare(r, "checkedGradient", 1, 1500, "on: full gradient at rest")
            sameColor(r.containerColor, "#2F3036", "checked keeps surfaceContainer")
            sameColor(r.contentColor, "#E8E7EE", "checked label onSurface (S21)")
            sameColor(r.secondaryContentColor, "#DBE2F9", "checked second line primary")
            var p = r.switchItem.mapToItem(top, 0, 0)
            compare(p.x, 288, "switch box from x 288 (28 px from the end at 363)")
            compare(r.switchItem.containerColor.a, 0, "the switch track is translucent over the gradient")
            r.enabled = false
            wait(500)
            sameColor(r.containerColor, "#2F3036", "disabled container stays")
            sameColor(r.contentColor, "#80868B", "disabled label #80868B")
            sameColor(r.secondaryContentColor, "#80868B", "disabled second line #80868B")
            sameColor(r.iconColor, "#80868B", "disabled icon #80868B")
        }

        // rendered against S21: the same chip box, sampled where stock has no text
        function test_4_gradientPixels() {
            var r = make('SwitchButton { x: 20; y: 123; width: 344; height: 104; text: ""; checked: false }')
            wait(500)
            waitForRendering(r)
            var img = grabImage(top)
            img.save("shots/row-off.png")
            pixelNear(img, 30, 174, "#2F3036", 1, "unchecked flat at x 30")
            pixelNear(img, 355, 174, "#2F3036", 1, "unchecked flat at x 355")
            r.checked = true
            wait(600)
            waitForRendering(r)
            img = grabImage(top)
            img.save("shots/row-on.png")
            // stock S21 pixels (x, y, colour)
            var s = [[80, 129, "#383A41"], [170, 129, "#464850"], [270, 129, "#555761"], [317, 129, "#5C5E69"],
                     [32, 174, "#33343B"], [80, 174, "#3A3C43"], [170, 174, "#484A52"], [270, 174, "#575963"],
                     [80, 220, "#3C3E45"], [170, 220, "#4A4C54"], [270, 220, "#595B65"], [317, 220, "#60626D"]]
            for (var i = 0; i < s.length; i++)
                pixelNear(img, s[i][0], s[i][1], s[i][2], 3, "S21 gradient")
            pixelNear(img, 30, 174, "#35363D", 4, "plan: #35363D at x 30")
            pixelNear(img, 355, 174, "#646772", 4, "plan: #646772 at x 355")
            // the switch on the gradient: thumb tertiary, track tertiary 38 % over the gradient (S18-b #8985A1 there)
            pixelNear(img, 321, 174, "#D4C7FF", 3, "thumb on the checked row")
            var t = img.pixel(298, 174)
            verify(t.b * 255 > 0x95 && t.b * 255 < 0xA6 && t.r * 255 > 0x78 && t.r * 255 < 0x8A, "translucent track over the gradient: " + t)
        }

        function test_5_switchRowMaterial2() {
            Theme.materialVersion = 2
            var r = make('SwitchButton { x: 20; y: 123; width: 344; height: 104; text: "Vibrate"; secondaryText: "On"; checked: true }')
            wait(600)
            sameColor(r.containerColor, "#303133", "M2 surface")
            sameColor(r.contentColor, "#FFFFFF", "M2 label onSurface")
            sameColor(r.secondaryContentColor, "#FFFFFF", "M2 second line = content")
            sameColor(r.iconColor, "#FFFFFF", "M2 icon = content")
            compare(r.checkedGradient, 1, "M2 checked gradient (ToggleChip)")
            sameColor(r.switchItem.onColor, "#FDE293", "M2 switch secondary")
            waitForRendering(r)
            var img = grabImage(top)
            img.save("shots/row-m2-on.png")
            // primary #AECBFA at 32.5 % x t over #303133, t = 0.94 at x 355 mid-height
            var x = 355 - 20 + 0.5, y = 174 - 123 + 0.5
            var tt = (x * 344 + y * 104) / (344 * 344 + 104 * 104) * 0.325
            var e = Qt.tint("#303133", Qt.rgba(0xAE / 255, 0xCB / 255, 0xFA / 255, tt))
            pixelNear(img, 355, 174, Qt.rgba(e.r, e.g, e.b, 1).toString(), 3, "M2 gradient end")
        }

        function test_6_checkboxAndRadio() {
            var c = make('CheckboxButton { width: 344; text: "Mon"; checked: true }')
            var r = make('RadioButton { y: 110; width: 344; text: "One"; checked: true }')
            wait(600)
            // Material 3: the CP3A rows (no emulator capture)
            sameColor(c.containerColor, "#404759", "M3 checkbox checked primaryContainer")
            sameColor(r.containerColor, "#404759", "M3 radio selected primaryContainer")
            compare(c.checkedGradient, 0, "M3 checkbox: no gradient")
            Theme.materialVersion = 2
            wait(600)
            sameColor(c.containerColor, "#303133", "M2 checkbox surface")
            sameColor(c.contentColor, "#FFFFFF", "M2 checkbox label")
            sameColor(c.secondaryContentColor, "#FFFFFF", "M2 checkbox second line")
            sameColor(c.iconColor, "#FFFFFF", "M2 checkbox icon")
            compare(c.checkedGradient, 1, "M2 checkbox gradient")
            sameColor(c.boxColor, "#FDE293", "M2 box secondary")
            sameColor(c.checkColor, "#303133", "M2 check onSecondary")
            sameColor(r.containerColor, "#303133", "M2 radio surface")
            sameColor(r.secondaryContentColor, "#FFFFFF", "M2 radio second line")
            sameColor(r.iconColor, "#FFFFFF", "M2 radio icon")
            sameColor(r.controlColor, "#FDE293", "M2 radio secondary")
            compare(r.checkedGradient, 1, "M2 radio gradient")
            c.checked = false
            r.checked = false
            wait(600)
            compare(c.checkedGradient, 0, "M2 unchecked: no gradient")
            sameColor(c.boxColor, Qt.rgba(1, 1, 1, 0.6), "M2 unchecked box onSurface 60 %")
            sameColor(r.controlColor, Qt.rgba(1, 1, 1, 0.6), "M2 unselected ring onSurface 60 %")
            c.enabled = false
            wait(500)
            sameColor(c.contentColor, "#80868B", "M2 disabled #80868B")
        }

        // a transparent row (the face editor's toggles, WearChipButtonTransparent):
        // checked, it draws no gradient
        function test_7_transparentRowNoGradient() {
            var r = make('SwitchButton { x: 20; y: 123; width: 344; height: 104; text: ""; containerColor: "transparent"; checked: true }')
            wait(600)
            compare(r.checkedGradient, 1, "the spring still runs")
            waitForRendering(r)
            var img = grabImage(top)
            img.save("shots/row-transparent-on.png")
            pixelNear(img, 355, 174, "#000000", 1, "no gradient at the far end (was #43454C)")
            pixelNear(img, 30, 174, "#000000", 1, "no gradient at the start")
            pixelNear(img, 321, 174, "#D4C7FF", 3, "the switch is on")
            // an opaque row still gets it
            r.containerColor = Theme.color.surfaceContainer
            wait(50)
            waitForRendering(r)
            img = grabImage(top)
            pixelNear(img, 355, 174, "#646772", 4, "opaque container: the gradient")
        }

        // a disabled checked row keeps its gradient at 38 % (Wear Material 2's disabled chip)
        function test_8_disabledCheckedGradient() {
            var r = make('SwitchButton { x: 20; y: 123; width: 344; height: 104; text: ""; checked: true }')
            wait(600)
            compare(r.checkedGradient, 1, "enabled: full")
            r.enabled = false
            wait(600)
            compare(r.checkedGradient, 0.38, "disabled: 38 %")
            waitForRendering(r)
            var img = grabImage(top)
            img.save("shots/row-disabled-on.png")
            // primary at 32.5 % x 0.38 x t over #2F3036, t = 0.934 at x 355 mid-height
            var x = 355 - 20 + 0.5, y = 174 - 123 + 0.5
            var tt = (x * 344 + y * 104) / (344 * 344 + 104 * 104) * 0.325 * 0.38
            var e = Qt.tint("#2F3036", Qt.rgba(0xDB / 255, 0xE2 / 255, 0xF9 / 255, tt))
            pixelNear(img, 355, 174, Qt.rgba(e.r, e.g, e.b, 1).toString(), 3, "38 % gradient end")
            r.checked = false
            wait(600)
            compare(r.checkedGradient, 0, "disabled unchecked: none")
            r.enabled = true
            r.checked = true
            wait(600)
            compare(r.checkedGradient, 1, "enabled again: full")
            Theme.materialVersion = 2
            var c = make('CheckboxButton { y: 240; width: 344; text: "Mon"; checked: true; enabled: false }')
            var d = make('RadioButton { y: 240; width: 344; text: "One"; checked: true; enabled: false }')
            wait(600)
            compare(c.checkedGradient, 0.38, "M2 checkbox disabled: 38 %")
            compare(d.checkedGradient, 0.38, "M2 radio disabled: 38 %")
        }
    }
}
