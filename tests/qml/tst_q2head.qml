// WO-61-Q2 N61-05: ListHeader options (minimumHeight, color; defaults
// unchanged), the Wear OS 6 ListSubHeader, Theme.color.caption. Stock: the
// Wear OS 6 emulator, Settings S21-d ('Notification volume': the stepper
// above ends at row 223, the 'N' cap 261-277 from x 51; 'Ring volume': 'R'
// 82-98, the stepper below from row 120), S20-b captions #9AA0A6.
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

    // ListHeader: defaults and the two options
    Column {
        id: heads
        visible: false
        width: 384
        ListHeader { id: lh; text: "Display" }
        ListHeader { id: lhSettings; text: "Display"; minimumHeight: 0; color: Theme.color.onSurface }
        ListSubHeader { id: lsh; text: "Brightness" }
        ListSubHeader { id: lsh0; text: "First"; first: true }
    }

    // a stock list: a Column 5.2 % in from each side (Exercise, Map, Settings),
    // rows 4 dp apart, the sub-header between two of them
    Column {
        id: stock
        visible: false
        x: 20
        y: 40
        width: 344
        spacing: Theme.space.xs
        Rectangle { id: rowA; width: 344; height: 104; radius: 52; color: "#2F3036" }
        ListSubHeader { id: sub; text: "Notification volume" }
        Rectangle { id: rowB; width: 344; height: 104; radius: 52; color: "#2F3036" }
    }

    // ListRows in a full-width Column without spacing (each keeps 2 dp above
    // and below and the 5.2 % inside): the header adds the 5.2 % itself
    Column {
        id: rows
        visible: false
        y: 40
        width: 384
        ListRow { id: lrA; text: "Mute"; height: implicitHeight }
        ListSubHeader {
            id: sub2
            text: "Ring volume"
            rowGap: Theme.space.xs / 2
            textInset: Theme.margin.listSide + Theme.dp(16)
        }
        ListRow { id: lrB; text: "Alarm"; height: implicitHeight }
    }

    // a ScalingList row holding the sub-header (Weather's settings): the row
    // is 5.2 % in from each side
    ScalingList {
        id: wl
        width: 384; height: 384
        visible: false
        model: 4
        itemDelegate: Item {
            property int index
            height: index === 1 ? hdr.height : 104
            Rectangle { visible: index !== 1; width: parent.width; height: 104; radius: 52; color: "#2F3036" }
            ListSubHeader { id: hdr; visible: index === 1; text: "Notification volume" }
        }
    }

    TestCase {
        name: "Q2head"
        when: windowShown

        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004,
                   msg + ": " + A + " != " + B)
        }
        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " not within " + tol + " of " + b)
        }
        function cleanup() {
            heads.visible = false
            stock.visible = false
            rows.visible = false
            wl.visible = false
        }

        function test_01_caption() {
            sameColor(Theme.color.caption, "#9AA0A6", "caption grey (S20-b)")
        }

        function test_02_listHeaderDefaults() {
            heads.visible = true
            // unchanged for every app
            compare(lh.minimumHeight, 96, "48 dp")
            sameColor(lh.color, "#FFFFFF", "onBackground")
            sameColor(lh.label.color, "#FFFFFF", "label onBackground")
            compare(lh.label.font.pixelSize, 32, "titleMedium 16 sp")
            compare(lh.label.horizontalAlignment, Text.AlignHCenter)
            near(lh.horizontalPadding, 46.08, 0.05, "12 % each side")
            compare(lh.topPadding, 8, "4 dp above")
            compare(lh.bottomPadding, 24, "12 dp below")
            compare(lh.height, 96, "min 48 dp")
            compare(lh.label.maximumLineCount, 3)
            // the options (the Wear OS 6 Settings title, S1)
            compare(lhSettings.minimumHeight, 0)
            compare(lhSettings.height, lhSettings.label.implicitHeight + 8 + 24, "no least height")
            verify(lhSettings.height < 96)
            sameColor(lhSettings.label.color, "#E8E7EE", "onSurface")
        }

        function test_03_subHeaderValues() {
            heads.visible = true
            compare(lsh.label.font.pixelSize, 26, "13 sp")
            compare(lsh.label.font.weight, Font.Medium, "Medium")
            sameColor(lsh.label.color, "#E8E7EE", "onSurface")
            compare(lsh.label.horizontalAlignment, Text.AlignLeft)
            compare(lsh.rowGap, 8, "the stock list's 4 dp")
            compare(lsh.topPadding, 29, "37 px from the row above, less the list's 8")
            compare(lsh.bottomPadding, 13, "21 px to the next row, less the list's 8")
            compare(lsh0.topPadding, 0, "first: nothing above")
            near(lsh.capHeight, 18.5, 1.5, "cap of the 26 px font")
            // 52 px less the font's left bearing (the ink is checked in test_04)
            compare(lsh.textInset, 32, "16 dp from its own left edge")
            // less the font's left bearing (the ink is checked in test_04-06)
            verify(lsh.horizontalPadding > 26 && lsh.horizontalPadding <= 32, "inset " + lsh.horizontalPadding)
            verify(lsh.height < 96, "no 48 dp minimum: " + lsh.height)
        }

        // the ink of the sub-header text (pixels brighter than 150 in all
        // channels, as the screenshots were measured) and the rows' runs
        function ink(img, y0, y1) {
            var top = -1, bottom = -1, left = 999
            for (var y = y0; y < y1; y++)
                for (var x = 30; x < 360; x++) {
                    var p = img.pixel(x, y)
                    if (p.r > 150 / 255 && p.g > 150 / 255 && p.b > 150 / 255) {
                        if (top < 0) top = y
                        bottom = y
                        left = Math.min(left, x)
                    }
                }
            return { top: top, bottom: bottom, left: left }
        }
        // the cap rows of the first letter (its stem columns only)
        function stem(img, x0, y0, y1) {
            var top = -1, bottom = -1
            for (var y = y0; y < y1; y++)
                for (var x = x0; x < x0 + 4; x++) {
                    var p = img.pixel(x, y)
                    if (p.r > 150 / 255 && p.g > 150 / 255 && p.b > 150 / 255) {
                        if (top < 0) top = y
                        bottom = y
                    }
                }
            return { top: top, bottom: bottom }
        }
        function lastRow(img, x, y0, y1) {
            var last = -1
            for (var y = y0; y < y1; y++) {
                var p = img.pixel(x, y)
                if (p.r + p.g + p.b > 30 / 255) last = y
            }
            return last
        }
        // the first row of a container: the surfaceContainer colour (#2F3036
        // within 3), so text ink above it does not count
        function firstRow(img, x, y0, y1) {
            var c = Qt.color("#2F3036")
            for (var y = y0; y < y1; y++) {
                var p = img.pixel(x, y)
                if (Math.abs(p.r - c.r) < 0.013 && Math.abs(p.g - c.g) < 0.013 && Math.abs(p.b - c.b) < 0.013)
                    return y
            }
            return -1
        }

        function test_04_renderStockList() {
            stock.visible = true
            waitForRendering(stock)
            var img = grabImage(top)
            var aLast = lastRow(img, 192, 40, 160)
            var bFirst = firstRow(img, 192, aLast + 2, 384)
            var t = ink(img, aLast + 2, bFirst)
            var s = stem(img, t.left, aLast + 2, bFirst)
            console.log("stock list: row A ends", aLast, "'N' rows", s.top, "-", s.bottom, "ink x from", t.left,
                        "row B from", bFirst)
            compare(aLast, 143, "row A 40-143")
            compare(sub.mapToItem(top, 0, 0).x, 20, "the header 5.2 % in, as wide as the rows")
            near(s.top - aLast, 38, 1, "first cap row 38 rows under row A (S21-d 223 -> 261)")
            near(bFirst - s.bottom, 22, 2, "row B 22 rows under the last cap row (S21-d 98 -> 120)")
            near(s.bottom - s.top + 1, 18, 1, "cap 18 rows (S21-d 17)")
            near(t.left, 52, 1, "ink from x 52 (S21-d 51)")
        }

        function test_05_renderListRows() {
            rows.visible = true
            waitForRendering(rows)
            var img = grabImage(top)
            // the ListRow containers: x 192 runs (their 2 dp margins are empty)
            var aLast = lastRow(img, 192, 40, 170)
            var bFirst = firstRow(img, 192, aLast + 2, 384)
            var t = ink(img, aLast + 2, bFirst)
            var s = stem(img, t.left, aLast + 2, bFirst)
            console.log("ListRows: row A ends", aLast, "'R' rows", s.top, "-", s.bottom, "ink x from", t.left,
                        "row B from", bFirst)
            near(s.top - aLast, 38, 1, "first cap row 38 rows under the container")
            near(bFirst - s.bottom, 22, 2, "the next container 22 rows under the last cap row")
            near(t.left, 52, 1, "ink from x 52")
        }

        function test_06_renderScalingListRow() {
            wl.visible = true
            wait(50)
            waitForRendering(wl)
            var img = grabImage(top)
            var row = wl.itemAtIndex(1)
            verify(row)
            var hdr = row.children[0].item
            var y0 = Math.floor(row.mapToItem(top, 0, 0).y), y1 = Math.ceil(row.mapToItem(top, 0, row.height).y)
            var t = ink(img, Math.max(0, y0), Math.min(384, y1))
            console.log("ScalingList row: header at x", hdr.mapToItem(top, 0, 0).x, "ink x from", t.left,
                        "rows", t.top, "-", t.bottom)
            verify(t.top >= 0, "the header's ink is on the screen")
            near(t.left, 52, 1, "ink from x 52 in a ScalingList row (was 70)")
        }
    }
}
