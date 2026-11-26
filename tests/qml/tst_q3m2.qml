// WO-61-Q3 additions from the Messages (A7) sweep: two shared controls under
// Material 2. The failure confirmation was black on black (M2 onError is
// #000000); Material 2 chips draw their label in regular weight, 8 dp after
// a 24 dp icon (the Wear OS 6 emulator S31 'Favorites', S32 'Open on phone':
// icon box x 48-96, text ink from x 112-113, 'Open on phone' one line,
// 205 px of ink).
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

    TestCase {
        id: tc
        name: "Q3m2"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
                   && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
        }
        // WCAG relative luminance and contrast ratio of two opaque colours
        function lum(c) {
            function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
        }
        function contrast(a, b) {
            var la = lum(Qt.color(a)), lb = lum(Qt.color(b))
            return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
        }
        function over(c, bg) {   // c composited over an opaque bg
            c = Qt.color(c); bg = Qt.color(bg)
            return Qt.rgba(c.r * c.a + bg.r * (1 - c.a), c.g * c.a + bg.g * (1 - c.a), c.b * c.a + bg.b * (1 - c.a), 1)
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

        function failureRender(tag) {
            var c = make('Confirmation { anchors.fill: parent }')
            c.show("Not sent", false)
            wait(900)
            waitForRendering(top)
            var img = grabImage(top)
            img.save("shots/failure-" + tag + ".png")
            var cont = over(c.container.color, "#000000")
            var glyph = over(c.glyph.color, cont)
            // the container's own pixel, between its centre and its edge
            var p = img.pixel(192 - c.container.width * 0.4, 192)
            c.close()
            return { c: c, cont: cont, glyph: glyph, pixel: p }
        }

        function test_1_failureVisible() {
            var r = failureRender("m3")
            sameColor(r.c.failureContainerColor, Qt.rgba(0x3C / 255, 0x05 / 255, 0x07 / 255, 0.8), "M3 onError at 80 % (CP3A)")
            sameColor(r.c.failureGlyphColor, Theme.color.errorDim, "M3 glyph errorDim")
            verify(contrast(r.glyph, r.cont) >= 4.5, "M3 glyph on its container: " + contrast(r.glyph, r.cont).toFixed(2))
            verify(contrast(r.glyph, "#000000") >= 4.5, "M3 glyph on black: " + contrast(r.glyph, "#000000").toFixed(2))
            verify(r.pixel.r * 255 > 30, "M3 container drawn (dark red): " + r.pixel)
            wait(600)
            Theme.materialVersion = 2
            var m = failureRender("m2")
            sameColor(Theme.color.onError, "#000000", "M2 onError is black")
            sameColor(m.c.failureContainerColor, "#EE675C", "M2 container error")
            sameColor(m.c.failureGlyphColor, "#000000", "M2 glyph onError")
            verify(contrast(m.cont, "#000000") >= 3, "M2 container on the black dialog: " + contrast(m.cont, "#000000").toFixed(2))
            verify(contrast(m.glyph, m.cont) >= 4.5, "M2 glyph on its container: " + contrast(m.glyph, m.cont).toFixed(2))
            verify(Math.abs(m.pixel.r - 0xEE / 255) < 0.02 && Math.abs(m.pixel.g - 0x67 / 255) < 0.02, "M2 container drawn #EE675C: " + m.pixel)
        }

        function test_2_m2ChipLabel() {
            var b = make('Button { x: 20; y: 212; width: 344; variant: "tonal"; iconName: "ms-open_in_phone"; text: "Open on phone" }')
            compare(b.iconSize, 52, "M3 icon 26 dp")
            compare(b.iconSpacing, 12, "M3 6 dp")
            compare(b.label.font.weight, 500, "M3 label Medium")
            Theme.materialVersion = 2
            wait(50)
            compare(b.labelWeight, 400, "M2 label weight 400")
            compare(b.label.font.weight, 400, "M2 label drawn regular")
            compare(b.iconSize, 48, "M2 icon 24 dp")
            compare(b.iconSpacing, 16, "M2 8 dp after the icon")
            var lx = b.label.mapToItem(top, 0, 0).x
            near(lx, 112, 0.5, "the label box from x 112 (stock ink from 112-113)")
            var fm = Qt.createQmlObject('import QtQuick; TextMetrics { }', b)
            fm.font = b.label.font
            fm.text = "Open on phone"
            console.log("Q3m2 'Open on phone' advance", fm.advanceWidth.toFixed(1), "ink", fm.tightBoundingRect.width.toFixed(1), "room", b.label.width.toFixed(1), "lines", b.label.lineCount)
            fm.font.family = "Noto Sans SemiCondensed"
            console.log("Q3m2 SemiCondensed advance", fm.advanceWidth.toFixed(1))
            // Noto Sans at 400 is 7-10 % wider than stock's face (decision 2): the
            // label wraps where stock's fits (stock ink 205 px in 224 px of room)
            verify(b.label.lineCount <= 2, "at most two lines")
            waitForRendering(b)
            var img = grabImage(top)
            img.save("shots/chip-m2.png")
            var x0 = 999, x1 = -1
            for (var x = 100; x < 370; x++)
                for (var y = 240; y < 290; y++)
                    if (img.pixel(x, y).r > 0.6) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); break }
            console.log("Q3m2 'Open on phone' ink x", x0, x1, "(stock 113-317)")
            near(x0, 113, 2, "ink starts as stock")
            b.labelWeight = 0
            compare(b.label.font.weight, 500, "an app can ask for the role's weight again")
            Theme.materialVersion = 3
            compare(b.label.font.weight, 500, "M3 Medium")
        }
    }
}
