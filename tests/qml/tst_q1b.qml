// WO-61-Q1 N61-02: TimeText 3 px lower, the Material 2 style in Material 2
// applications, Application.timeTextMargin. Stock: the Wear OS 6 emulator,
// Settings S16 ('6:47' #C6C6C6, digits x 160-224, y 15-38) and Clock S27
// ('7:00' #FFFFFF, x 159-224, y 16-39, '0' stroke about 2.85 px).
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    // black as every Wear OS application screen (the window clears white)
    Rectangle {
        id: host
        anchors.fill: parent
        color: "#000000"
    }

    TestCase {
        id: tc
        name: "Q1b"
        when: windowShown

        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
                   && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
        }
        function cleanup() {
            Theme.materialVersion = 3
        }
        function make(src) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; ' + src, host)
        }
        function findTimeText(item) {
            if (item.maxSweep !== undefined && item.edgeMargin !== undefined)
                return item
            for (var i = 0; i < item.children.length; i++) {
                var r = findTimeText(item.children[i])
                if (r)
                    return r
            }
            return null
        }

        // the ink of the time text as the plan measured the screenshots
        // (pixels brighter than 100/255): box, brightest pixel, and the stroke
        // runs (coverage sums) across the digits' middle rows
        function measure(tt) {
            waitForRendering(tt)
            var img = grabImage(top)
            var y0 = 999, y1 = -1, x0 = 999, x1 = -1, best = 0, bestC = null
            for (var y = 0; y < 60; y++)
                for (var x = 120; x < 264; x++) {
                    var p = img.pixel(x, y)
                    var s = p.r + p.g + p.b
                    if (s > 300 / 255) {
                        y0 = Math.min(y0, y); y1 = Math.max(y1, y)
                        x0 = Math.min(x0, x); x1 = Math.max(x1, x)
                    }
                    if (s > best) { best = s; bestC = p }
                }
            var level = bestC ? (bestC.r + bestC.g + bestC.b) / 3 : 1
            var rows = []
            for (var r = 10; r <= 12; r++) {
                var runs = [], cur = -1, acc = 0
                for (var xx = 120; xx < 265; xx++) {
                    var q = img.pixel(xx, y0 + r)
                    var v = (q.r + q.g + q.b) / 3 / level
                    if (v > 0.08) {
                        if (cur < 0) { cur = xx; acc = 0 }
                        acc += v
                    } else if (cur >= 0) {
                        runs.push(Math.round(acc * 100) / 100)
                        cur = -1
                    }
                }
                rows.push(runs)
            }
            return { top: y0, bottom: y1, left: x0, right: x1, color: bestC, runs: rows }
        }

        function test_01_defaults() {
            compare(Theme.size.timeTextEdgeMargin, 7, "M3 3.5 dp")
            var tt = make('TimeText { text: "6:47" }')
            compare(tt.edgeMargin, 7, "M3 edge 3.5 dp (was 2 dp)")
            compare(tt.weight, Theme.type.arcMedium.weight, "M3 weight = arcMedium")
            compare(tt.weight, 599)
            sameColor(tt.color, "#C6C6C6", "M3 tone 80")
            compare(tt._styleName, "SemiCondensed SemiBold")
            Theme.materialVersion = 2
            compare(Theme.size.timeTextEdgeMargin, 9, "M2 4.5 dp")
            compare(tt.edgeMargin, 9, "M2 edge 4.5 dp")
            compare(tt.weight, 500, "M2 weight 500 (caption1 Medium)")
            compare(tt._styleName, "SemiCondensed Medium")
            compare(tt._axes.wght, 500, "wght axis follows")
            sameColor(tt.color, "#FFFFFF", "M2 white")
            compare(tt.pixelSize, Theme.type.arcMedium.pixelSize, "same size")
            tt.weight = 400
            compare(tt._styleName, "SemiCondensed", "a weight of its own")
            tt.destroy()
        }

        function test_02_renderM3() {
            var tt = make('TimeText { text: "6:47" }')
            var m = measure(tt)
            console.log("Q1b M3 6:47 ink x " + m.left + "-" + m.right + " y " + m.top + "-" + m.bottom
                        + " colour " + m.color + " runs " + JSON.stringify(m.runs))
            compare(m.top, 15, "M3 digit top y 15 as S16 and S20 (plan: +/- 1)")
            sameColor(m.color, "#C6C6C6", "M3 ink #C6C6C6")
            tt.text = "7:00"
            var m0 = measure(tt)
            console.log("Q1b M3 7:00 ink x " + m0.left + "-" + m0.right + " y " + m0.top + "-" + m0.bottom
                        + " runs " + JSON.stringify(m0.runs))
            tt.destroy()
        }

        function test_03_renderM2() {
            Theme.materialVersion = 2
            var tt = make('TimeText { text: "7:00" }')
            var m = measure(tt)
            console.log("Q1b M2 7:00 ink x " + m.left + "-" + m.right + " y " + m.top + "-" + m.bottom
                        + " colour " + m.color + " runs " + JSON.stringify(m.runs))
            compare(m.top, 16, "M2 digit top y 16 as S27-S31 (plan: +/- 1)")
            sameColor(m.color, "#FFFFFF", "M2 ink white")
            // the two zeros: the last four runs of each middle row
            var sum = 0, n = 0
            for (var i = 0; i < m.runs.length; i++) {
                var r = m.runs[i]
                for (var j = Math.max(0, r.length - 4); j < r.length; j++) {
                    sum += r[j]
                    n++
                }
            }
            var stroke = n > 0 ? sum / n : 0
            console.log("Q1b M2 '0' stroke " + stroke.toFixed(2))
            verify(stroke >= 2.5 && stroke <= 3.3, "M2 '0' stroke 2.5-3.3 px (S27 2.85): " + stroke)
            tt.destroy()
        }

        function test_04_application() {
            var app = make('Application { width: 384; height: 384; showTime: true }')
            var tt = findTimeText(app)
            verify(tt !== null, "the Application's TimeText")
            compare(app.timeTextMargin, 7, "M3 default 3.5 dp")
            compare(tt.edgeMargin, 7, "bound to timeTextMargin")
            // D60-13: the scroll-away transform stays on the same instance
            compare(tt.transform.length, 2, "Scale + Translate")
            app.materialVersion = 2
            compare(app.timeTextMargin, 9, "M2 default 4.5 dp")
            compare(tt.edgeMargin, 9)
            compare(tt.weight, 500)
            app.timeTextMargin = Theme.dp(1)
            compare(tt.edgeMargin, 2, "an app's own margin (Media 1 dp)")
            app.destroy()
            wait(0)
            var media = make('Application { width: 384; height: 384; showTime: true; timeTextMargin: Theme.dp(1) }')
            var mt = findTimeText(media)
            compare(mt.edgeMargin, 2, "declared margin")
            mt.text = "6:47"
            var m = measure(mt)
            console.log("Q1b Media 1 dp ink y " + m.top + "-" + m.bottom)
            verify(Math.abs(m.top - 10) <= 1, "Media digit top y 10 +/- 1 (S33): " + m.top)
            media.destroy()
        }
    }
}
