// WO-61-Q3 N61-08: InlineSlider, the Wear OS 6 stepper. Stock: the emulator,
// S24 (Brightness 3 of 5, segmented: pill x 20-363, y 84-187; dividers
// #000000 at x 92-93 and 290-291; selected #D4C7FF x 108-208; bar y 130-141)
// and S21-d (Ring volume 0, one bar #202124 x 108-275; minus x 44-75, plus
// x 308-339).
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

    // packed list rows with a slider between them
    Flickable {
        id: flick
        width: 384; height: 384
        visible: false
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            spacing: 8
            Repeater { model: 3; ListItem { title: "Row " + index } }
            InlineSlider { id: listSlider; x: 20; width: 344; from: 0; to: 10; stepSize: 1; value: 5 }
            Repeater { model: 6; ListItem { title: "Row " + (index + 3) } }
        }
    }

    TestCase {
        id: tc
        name: "Q3slider"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
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
        function brightness() {
            return make('InlineSlider { x: 20; y: 84; width: 344; segmented: true; from: 0; to: 5; stepSize: 1; lowest: 1; value: 3 }')
        }

        function test_1_tokens() {
            sameColor(Theme.color.sliderTrack, "#202124", "sliderTrack")
            sameColor(Theme.color.sliderFill, "#D4C7FF", "sliderFill tertiary")
            var s = brightness()
            compare(s.height, 104, "52 dp pill")
            compare(s.segmentWidth, 72, "36 dp end segments")
            compare(s.dividerWidth, 2, "1 dp dividers")
            compare(s.barInset, 14, "bar 7 dp inside the dividers")
            compare(s.barHeight, 12, "bar 6 dp tall")
            compare(s.segments, 5, "5 segments")
            compare(s.edgeEffect, true, "packed edge effect on")
        }

        function test_2_pixelsSegmented() {
            var s = brightness()
            wait(250)
            waitForRendering(s)
            var img = grabImage(top)
            img.save("shots/slider-bright.png")
            pixelNear(img, 30, 136, "#2F3036", 1, "pill")
            pixelNear(img, 92, 100, "#000000", 1, "divider x 92")
            pixelNear(img, 93, 170, "#000000", 1, "divider x 93")
            pixelNear(img, 91, 136, "#2F3036", 1, "segment to x 91")
            pixelNear(img, 94, 136, "#2F3036", 1, "middle from x 94")
            pixelNear(img, 290, 100, "#000000", 1, "divider x 290")
            pixelNear(img, 291, 170, "#000000", 1, "divider x 291")
            pixelNear(img, 292, 120, "#2F3036", 1, "segment from x 292")
            // selected x 108-208, 12 px tall
            pixelNear(img, 110, 136, "#D4C7FF", 2, "selected from the start")
            pixelNear(img, 206, 136, "#D4C7FF", 2, "selected to x 207")
            pixelNear(img, 150, 130, "#D4C7FF", 2, "bar top row 130")
            pixelNear(img, 150, 141, "#D4C7FF", 2, "bar bottom row 141")
            pixelNear(img, 150, 129, "#2F3036", 2, "pill above the bar")
            pixelNear(img, 150, 142, "#2F3036", 2, "pill under the bar")
            pixelNear(img, 107, 136, "#2F3036", 2, "bar starts at x 108")
            pixelNear(img, 230, 136, "#202124", 2, "unselected #202124")
            pixelNear(img, 273, 136, "#202124", 2, "unselected to x 275")
            pixelNear(img, 277, 136, "#2F3036", 2, "bar ends at x 275")
            // the gaps at the segment joins (108 + 33.6 k)
            verify(img.pixel(141, 136).r < 0.5, "gap near x 141: " + img.pixel(141, 136))
            verify(img.pixel(175, 136).r < 0.6, "gap near x 175: " + img.pixel(175, 136))
            verify(img.pixel(242, 136).r * 255 < 0x18, "gap near x 242 on the unselected part: " + img.pixel(242, 136))
            // glyphs: white, square ends
            pixelNear(img, 44, 135, "#FFFFFF", 1, "minus from x 44")
            pixelNear(img, 75, 136, "#FFFFFF", 1, "minus to x 75")
            pixelNear(img, 43, 135, "#2F3036", 1, "minus ends at x 44")
            pixelNear(img, 76, 135, "#2F3036", 1, "minus ends at x 75")
            pixelNear(img, 60, 133, "#2F3036", 1, "minus 4 px tall (above)")
            pixelNear(img, 60, 138, "#2F3036", 1, "minus 4 px tall (below)")
            pixelNear(img, 308, 135, "#FFFFFF", 1, "plus from x 308")
            pixelNear(img, 339, 136, "#FFFFFF", 1, "plus to x 339")
            pixelNear(img, 323, 120, "#FFFFFF", 1, "plus from y 120")
            pixelNear(img, 324, 151, "#FFFFFF", 1, "plus to y 151")
            pixelNear(img, 323, 119, "#2F3036", 1, "plus ends at y 120")
        }

        function test_3_pixelsVolume() {
            var s = make('InlineSlider { x: 20; y: 120; width: 344; from: 0; to: 7; stepSize: 1; value: 0 }')
            wait(250)
            waitForRendering(s)
            var img = grabImage(top)
            img.save("shots/slider-volume0.png")
            pixelNear(img, 150, 171, "#202124", 1, "one bar #202124")
            pixelNear(img, 175, 171, "#202124", 1, "no gaps when not segmented")
            verify(img.pixel(60, 172).r < 0.6, "the minus at 38 % at its limit: " + img.pixel(60, 172))
            s.value = 4
            wait(300)
            waitForRendering(s)
            img = grabImage(top)
            img.save("shots/slider-volume4.png")
            pixelNear(img, 60, 172, "#FFFFFF", 1, "minus white away from the limit")
            // 4 of 7 of the 168 px bar: x 108-203, the end square
            pixelNear(img, 200, 171, "#D4C7FF", 2, "selected to x 203")
            pixelNear(img, 202, 166, "#D4C7FF", 2, "square end (top corner)")
            pixelNear(img, 206, 171, "#202124", 2, "unselected after it")
        }

        function test_4_steps() {
            var s = brightness()
            var got = []
            s.moved.connect(function(v) { got.push(v) })
            mouseClick(s, 300, 52)
            compare(got[0], 4, "increase segment +1")
            s.value = 1
            mouseClick(s, 30, 52)
            compare(got.length, 1, "nothing below lowest")
            s.value = 2
            mouseClick(s, 30, 52)
            compare(got[1], 1, "decrease segment -1")
            s.active = false
            sameColor(s.decreaseColor, Qt.rgba(1, 1, 1, 0.38), "inactive glyph 38 %")
            sameColor(s.fillColor, "#80868B", "inactive fill #80868B")
            mouseClick(s, 300, 52)
            compare(got.length, 2, "inactive: taps do nothing")
            s.active = true
            s.value = 3
            wait(50)
            s.value = 5
            wait(75)
            var sel = findChild(s, "sliderSelected")
            verify(sel.width > 100 && sel.width < 168, "the fraction animates over 150 ms: " + sel.width)
            wait(150)
            compare(sel.width, 168, "full after 150 ms")
        }

        function test_5_packedInList() {
            flick.visible = true
            wait(50)
            // the slider low on the screen: it shrinks with its neighbours
            flick.contentY = listSlider.y - 300
            wait(100)
            var e = null
            for (var i = 0; i < listSlider.data.length; i++)
                if (listSlider.data[i].packed !== undefined) e = listSlider.data[i]
            verify(e !== null, "an EdgeEffect")
            verify(e.packed, "packed")
            verify(e.scale < 1, "shrinks near the bottom edge: " + e.scale)
            compare(listSlider.transform[0].xScale, e.scale)
            compare(listSlider.transform[1].y, e.translateY)
            listSlider.edgeEffect = false
            wait(50)
            compare(e.scale, 1, "off: at rest")
            listSlider.edgeEffect = true
            flick.visible = false
        }
    }
}
