// WO-61-Q3 N61-10: PickerGroup in the Clock's Material 2 style, and the
// Label weight hook it needs. Stock: the Wear OS 6 emulator S28-c (Timer
// h:m:s) and S29-c (Alarm h:m + PM): heading 'Hour' #FDE293 at y 31-53,
// focused digits #FDE293 (cap y 147-189 on S28-c), the other columns
// #FFFFFF with no neighbours, ':' #FFFFFF, a round #FFFFFF confirm disc x
// 140-243, y 262-365 with a #303133 check.
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
        name: "Q3picker"
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
        // the option delegates of a column that are drawn in its viewport
        function drawnOptions(picker) {
            var lv = picker.view, out = []
            var kids = lv.contentItem.children
            for (var i = 0; i < kids.length; i++) {
                var d = kids[i]
                if (d.option === undefined || !d.visible)
                    continue
                if (d.y + d.height <= lv.contentY || d.y >= lv.contentY + lv.height)
                    continue
                out.push(d)
            }
            return out
        }
        // rows whose pixels are within tol of hex, in a box
        function inkRows(img, x0, x1, y0, y1, hex, tol) {
            var c = Qt.color(hex), r0 = 999, r1 = -1
            for (var y = y0; y < y1; y++)
                for (var x = x0; x < x1; x++) {
                    var p = img.pixel(x, y)
                    if (Math.max(Math.abs(p.r - c.r), Math.abs(p.g - c.g), Math.abs(p.b - c.b)) * 255 <= tol) {
                        r0 = Math.min(r0, y); r1 = Math.max(r1, y)
                        break
                    }
                }
            return [r0, r1]
        }

        function test_1_labelWeight() {
            var l = make('Label { role: "labelMedium"; text: "Open on phone" }')
            compare(l.font.weight, 500, "labelMedium Medium")
            var r = make('Label { role: "labelMedium"; weight: 400; text: "Open on phone" }')
            compare(r.font.weight, 400, "weight 400 wins over the role")
            r.weight = 0
            compare(r.font.weight, 500, "0: the role again")
            r.weight = 600
            compare(r.font.weight, 600, "a later weight")
            var b = make('Label { role: "labelMedium"; weight: 400; font.bold: true; text: "x" }')
            compare(b.font.weight, Font.Bold, "a caller's font.bold still wins")
        }

        function test_2_m3Unchanged() {
            var tp = make('TimePicker { width: 384; height: 384; type: "hms" }')
            wait(100)
            sameColor(tp.headingColor, "#DBE2F9", "M3 heading primary")
            verify(tp.button.visible, "M3 edge button")
            verify(!tp.roundButton.visible, "no round button in M3")
            compare(tp.optionWeight, 0, "M3 role weight")
            var p1 = tp.pickerAt(1)
            verify(drawnOptions(p1).length > 1, "M3 unfocused columns keep their neighbours")
            sameColor(tp.separatorColor, "#CECDD4", "M3 separators onSurfaceVariant")
        }

        function test_3_m2Timer() {
            Theme.materialVersion = 2
            var tp = make('TimePicker { width: 384; height: 384; type: "hms" }')
            wait(200)
            sameColor(tp.headingColor, "#FDE293", "heading secondary")
            compare(tp.headingItem.font.weight, 500, "heading weight 500")
            sameColor(tp.selectedColor, "#FDE293", "focused column secondary")
            sameColor(tp.unselectedColor, "#FFFFFF", "other columns #FFFFFF")
            sameColor(tp.separatorColor, "#FFFFFF", "separators #FFFFFF")
            compare(tp.optionWeight, 400, "options weight 400")
            var p0 = tp.pickerAt(0), p1 = tp.pickerAt(1), p2 = tp.pickerAt(2)
            verify(drawnOptions(p0).length >= 3, "the focused column shows its neighbours: " + drawnOptions(p0).length)
            var d0 = drawnOptions(p0)
            for (var i = 0; i < d0.length; i++) {
                sameColor(d0[i].color, "#FDE293", "focused column option " + i)
                compare(d0[i].font.weight, 400, "regular digits")
            }
            compare(drawnOptions(p1).length, 1, "an unfocused column: one option")
            compare(drawnOptions(p2).length, 1, "an unfocused column: one option")
            sameColor(drawnOptions(p1)[0].color, "#FFFFFF", "unfocused value #FFFFFF")
            // the round confirm
            verify(!tp.button.visible, "no edge button")
            var rb = tp.roundButton
            verify(rb.visible, "round button")
            compare(tp.confirmButton, rb, "confirmButton is the round one")
            compare(rb.width, 104, "52 dp")
            var c = rb.mapToItem(top, rb.width / 2, rb.height / 2)
            near(c.x, 192, 0.5, "centred (disc x 140-243)")
            near(c.y, 315, 0.5, "disc y 263-366 (S28-c 262-365, S29-c 264-367)")
            sameColor(rb.containerColor, "#AECBFA", "M2 default fill primary")
            sameColor(rb.iconColor, "#303133", "glyph #303133")
            compare(rb.iconName, "ms-check", "the Material check")
            compare(rb.iconSize, 52, "26 dp: the check ink 34 x 25 px as stock")
            var area = tp.columnsItem
            near(area.mapToItem(top, 0, 0).y, 61, 0.5, "the columns from y 61 (S29-c fades from 62)")
            near(area.mapToItem(top, 0, area.height).y, 262, 0.5, "the columns to y 262 (S29-c fades to 262)")
            tp.confirmContainerColor = "#FFFFFF"     // the Timer and the Alarm
            sameColor(rb.containerColor, "#FFFFFF", "white disc")
            var accepted = 0
            tp.accepted.connect(function() { accepted++ })
            mouseClick(rb)
            compare(accepted, 1, "the round button confirms")
            // focus moves: column 1 shows its neighbours, column 0 one option
            tp.focusIndex = 1
            wait(100)
            verify(drawnOptions(p1).length >= 3, "the newly focused column shows its neighbours")
            compare(drawnOptions(p0).length, 1, "the old one only its value")
            tp.focusIndex = 0
            wait(700)    // the heading's cross-fade
            waitForRendering(tp)
            var img = grabImage(top)
            img.save("shots/picker-m2-timer.png")
            var h = inkRows(img, 100, 284, 0, 80, "#FDE293", 40)
            console.log("Q3picker heading rows", h, "(stock 31-53)")
            near(h[0], 31, 3, "heading cap top")
            near(h[1], 53, 3, "heading baseline")
            var g = inkRows(img, 20, 120, 120, 220, "#FDE293", 30)
            console.log("Q3picker focused digits rows", g, "(stock at rest S29-c 141-184; S28-c mid-scroll 147-189)")
            near((g[0] + g[1]) / 2, 162.5, 2, "focused digits cap centre")
            near(g[1] - g[0] + 1, 43, 3, "cap 43 px")
            pixelNear(img, 192, 300, "#FFFFFF", 1, "disc #FFFFFF")
            pixelNear(img, 192, 264, "#FFFFFF", 2, "disc from row 263")
            pixelNear(img, 192, 259, "#000000", 2, "black above the disc")
            // the other columns' values white, nothing above or below them
            var w = inkRows(img, 150, 240, 62, 260, "#FFFFFF", 30)
            console.log("Q3picker middle column rows", w)
            verify(w[0] > 130 && w[1] < 200, "the middle column: its value only " + w)
        }

        function test_4_m2Alarm() {
            Theme.materialVersion = 2
            var tp = make('TimePicker { width: 384; height: 384; type: "12h"; hour: 19; minute: 2; confirmContainerColor: "#FFFFFF" }')
            wait(200)
            waitForRendering(tp)
            var img = grabImage(top)
            img.save("shots/picker-m2-alarm.png")
            compare(drawnOptions(tp.pickerAt(2)).length, 1, "the period column: its value only")
            var g = inkRows(img, 20, 120, 120, 220, "#FDE293", 30)
            console.log("Q3picker alarm focused rows", g, "(stock 142-184)")
        }

        function test_5_numberPicker() {
            Theme.materialVersion = 2
            var np = make('NumberPicker { width: 384; height: 384; title: "Weight"; count: 300; value: 70 }')
            wait(200)
            var d = drawnOptions(np.pickerAt(0))
            verify(d.length >= 1, "options drawn")
            for (var i = 0; i < d.length; i++)
                compare(d[i].font.weight, 400, "displaySmall at 400 in Material 2")
            verify(np.roundButton.visible, "round confirm")
            Theme.materialVersion = 3
            wait(50)
            compare(drawnOptions(np.pickerAt(0))[0].font.weight, 500, "M3 displaySmall 500 again")
        }

        // the strongest pixel of a row in a box, as a fraction of #FDE293
        function strength(img, x0, x1, y) {
            var best = 0
            for (var x = x0; x < x1; x++)
                best = Math.max(best, img.pixel(x, y).r)
            return best * 255 / 0xFD
        }
        // S29-c at rest: '06' over '07' over '08' in the hour column
        function test_6_m2Neighbours() {
            Theme.materialVersion = 2
            var tp = make('TimePicker { width: 384; height: 384; type: "12h"; hour: 19; minute: 2; confirmContainerColor: "#FFFFFF" }')
            wait(300)
            waitForRendering(tp)
            var img = grabImage(top)
            img.save("shots/picker-m2-neighbours.png")
            var p0 = tp.pickerAt(0)
            compare(p0.pitch, 68, "34 dp pitch")
            compare(p0.centerOffset, 5, "2.5 dp under the centre")
            // rows with any pixel at 15 % of #FDE293 or more in the hour column
            var x0 = p0.mapToItem(top, 0, 0).x, x1 = x0 + p0.width
            var rows = []
            for (var y = 62; y < 262; y++)
                if (strength(img, x0, x1, y) > 0.15) rows.push(y)
            var runs = [], s0 = rows[0]
            for (var i = 1; i <= rows.length; i++)
                if (i === rows.length || rows[i] !== rows[i - 1] + 1) { runs.push([s0, rows[i - 1]]); s0 = rows[i] }
            console.log("Q3picker M2 hour column ink runs", JSON.stringify(runs), "(S29-c 79-111, 141-184, 215-246)")
            compare(runs.length, 3, "the value and two neighbours")
            near((runs[1][0] + runs[1][1]) / 2, 162.5, 2, "selected cap centre (S29-c 162.5)")
            near((runs[0][0] + runs[0][1]) / 2, 95, 3, "upper neighbour centre (S29-c 95)")
            near((runs[2][0] + runs[2][1]) / 2, 230.5, 3, "lower neighbour centre (S29-c 230.5)")
            near(runs[0][1] - runs[0][0] + 1, 33, 4, "upper neighbour 0.75 tall (S29-c 33 px)")
            near(runs[2][1] - runs[2][0] + 1, 32, 4, "lower neighbour 0.75 tall (S29-c 32 px)")
            // the fade, against S29-c's brightest pixel per row (as #FDE293 fractions)
            var stock = [[97, 0.53], [103, 0.62], [109, 0.71], [220, 0.64], [229, 0.51], [241, 0.33]]
            for (var k = 0; k < stock.length; k++)
                near(strength(img, x0, x1, stock[k][0]), stock[k][1], 0.08, "fade at row " + stock[k][0])
            // the M3 picker keeps its CP3A geometry
            Theme.materialVersion = 3
            wait(100)
            compare(p0.pitch, 80, "M3 pitch 80 px")
            compare(p0.centerOffset, 0, "M3 centred")
            near(tp.columnsItem.mapToItem(top, 0, 0).y, 84, 0.5, "M3 columns under the heading band")
        }
    }
}
