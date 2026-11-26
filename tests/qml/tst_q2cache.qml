// WO-61-Q2 follow-up: the packer's kept rows are worked out again when a
// row moves without a y change (reparented inside the content, an
// EdgeEffect's item switched), at the start of a touch gesture (a section
// moved by a transform), and a layout that does not settle in four rounds
// is tried again on the next frames, a bounded number of times.
// Method (as the review's probe): one scroll step from the kept rows
// against the same place laid out from scratch (the viewport height +1 /
// -1 marks the rows to be worked out again and lays them out at once).
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    component PRow: Rectangle {
        property alias fx: e
        width: 300
        height: 80
        color: "#2F3036"
        EdgeEffect { id: e; packed: true }
    }

    Flickable {
        id: fa
        width: 384; height: 384
        visible: false
        contentHeight: 2400
        Column {
            id: colA
            spacing: 8
            Repeater { model: 8; PRow { } }
        }
        Item { id: sideA; y: 1000; width: 300; height: 400 }
        // a section moved by a transform, not by y
        Item {
            id: wrapT
            y: 1500
            width: 300; height: 300
            transform: Translate { id: tr; y: 0 }
            Column { spacing: 8; Repeater { model: 3; PRow { } } }
        }
        Rectangle { id: freeA; y: 2000; width: 300; height: 80 }
        Rectangle { id: freeB; y: 2100; width: 300; height: 120 }
    }
    EdgeEffect { id: freeFx; packed: true }

    // a row whose place follows its own pivot: it never settles
    Flickable {
        id: fo
        width: 384; height: 384
        visible: false
        contentHeight: 1000
        PRow { y: 150; height: 90 }
        PRow {
            id: flipper
            property int flips: 0
            height: 50
            // above the middle row it scales about its bottom (originY > 0)
            // and goes below it; below, about its top, and goes back above
            y: fx.originY > 0 ? 290 : 40
            onYChanged: flips++
        }
    }

    TestCase {
        name: "Q2cache"
        when: windowShown

        function cleanup() {
            fa.visible = false
            fo.visible = false
        }
        function effects(f) {
            var out = []
            function walk(it) {
                for (var k = 0; k < it.children.length; k++) {
                    var c = it.children[k]
                    if (c.fx !== undefined && c.visible) out.push(c.fx)
                    walk(c)
                }
            }
            walk(f.contentItem)
            if (f === fa) out.push(freeFx)
            return out
        }
        function snap(list) {
            var s = []
            for (var i = 0; i < list.length; i++)
                s.push([list[i].scale, list[i].translateY, list[i].originY])
            return s
        }
        function forced(f) {
            var cy = f.contentY
            f.height = f.height + 1
            f.height = f.height - 1
            if (f.contentY !== cy)
                f.contentY = cy
        }
        // kept rows after one scroll step against the place laid out afresh
        function keptVsFresh(f, tag) {
            wait(40)
            f.contentY = f.contentY + 1
            wait(60)
            var list = effects(f)
            var kept = snap(list)
            forced(f)
            wait(60)
            var fresh = snap(list)
            var worst = 0, at = -1
            for (var i = 0; i < list.length; i++)
                for (var j = 0; j < 3; j++) {
                    var d = Math.abs(kept[i][j] - fresh[i][j])
                    if (d > worst) { worst = d; at = i }
                }
            console.log(tag + ": kept vs fresh worst " + worst.toFixed(3)
                        + (at >= 0 ? " kept " + JSON.stringify(kept[at]) + " fresh " + JSON.stringify(fresh[at]) : ""))
            return worst
        }

        function test_01_reparentedRow() {
            fa.visible = true
            fa.contentY = 300
            wait(40)
            verify(keptVsFresh(fa, "baseline") < 0.01)
            // the last Column row into another item of the same content: no y change
            var last = colA.children[7]
            last.parent = sideA
            var w = keptVsFresh(fa, "reparented")
            verify(w < 0.01, "worked out again after a reparent: " + w)
            last.parent = colA
            wait(40)
        }
        function test_02_itemSwitched() {
            fa.visible = true
            fa.contentY = 1700
            freeFx.item = freeA
            wait(40)
            verify(keptVsFresh(fa, "free effect on A") < 0.01)
            freeFx.item = freeB
            var w = keptVsFresh(fa, "item switched to B")
            verify(w < 0.01, "worked out again after the item changed: " + w)
            freeFx.item = null
            wait(40)
        }
        function test_03_transformedSectionAtTheNextGesture() {
            fa.visible = true
            fa.contentY = 1300
            wait(40)
            verify(keptVsFresh(fa, "transform baseline") < 0.01)
            tr.y = 60
            // a program scroll alone keeps the old place (the documented limit)
            var stale = keptVsFresh(fa, "moved by a Translate, program scroll")
            console.log("stale until a gesture: " + stale.toFixed(3))
            // forced() above worked them out again: move the section once more
            tr.y = 0
            // a touch gesture starts: the rows are worked out again
            fa.flick(0, 300)
            tryCompare(fa, "moving", false, 3000)
            var w = keptVsFresh(fa, "after a gesture")
            verify(w < 0.01, "worked out again at the gesture: " + w)
            tr.y = 0
        }
        function test_04_unsettledIsRetriedBounded() {
            fo.visible = true
            wait(50)
            var f0 = flipper.flips
            // a row whose place follows its pivot flips on every round; the
            // packer gives up after four rounds a pass and tries again on the
            // next frames, eight times at most, then stops
            fo.contentY = 1
            wait(600)
            var f1 = flipper.flips
            wait(400)
            var f2 = flipper.flips
            console.log("flips: start " + f0 + ", after the scroll " + f1 + ", later " + f2)
            verify(f1 - f0 > 8, "tried again on later frames: " + (f1 - f0) + " flips")
            verify(f1 - f0 <= 4 * 10, "bounded: " + (f1 - f0) + " flips")
            compare(f2, f1, "and then it stops")
            // the list still works afterwards: a normal row is laid out
            fo.visible = false
        }
    }
}
