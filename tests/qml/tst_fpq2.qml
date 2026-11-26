import QtQuick
import QtTest
import org.asteroid.controls

// FP-Q2 (r2-63): RotaryInput's crown-speed mode on ListViews (face-interaction-32): a snapping
// view with `property bool rotaryCrownSpeed: true` scrolls by the crown's pixels and, once the
// crown rests (80 ms, stock hds.java), glides to the nearest item; a StrictlyEnforceRange view
// (as the face picker) makes that item current. Without the property the view steps item by
// item as before. The crown as the image sets it (crown-fast, 7.5 px per count from the image's
// dconf database, 24 counts per detent); one event per gesture, so no speed gain.
TestCase {
    id: tc
    name: "FPQ2"
    when: windowShown
    visible: true
    width: 384
    height: 384

    property var made: []

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }
    function make(c, props) {
        var o = c.createObject(tc, props || {})
        made.push(o)
        return o
    }
    function cleanup() {
        for (var i = 0; i < made.length; i++)
            made[i].destroy()
        made = []
        wait(350)   // a new crown gesture for the next case (300 ms)
    }
    // n counts forward (towards the end; negative: back), one wheel event
    function crown(item, n) {
        mouseWheel(item, 192, 192, 0, -120 * n)
    }
    // wait until prop has not changed for 200 ms (the glide and the snap are over)
    function settle(o, prop) {
        var last = o[prop], still = 0
        for (var i = 0; i < 100 && still < 4; i++) {
            wait(50)
            if (o[prop] === last) {
                still++
            } else {
                still = 0
                last = o[prop]
            }
        }
    }

    Component {
        id: freeComp
        Flickable { width: 384; height: 384; contentHeight: 4000 }
    }
    Component {
        id: listComp
        ListView {
            width: 384
            height: 384
            model: 20
            snapMode: ListView.SnapToItem
            delegate: Rectangle { width: 384; height: 100; color: index % 2 ? "#333333" : "#555555" }
        }
    }
    Component {
        id: speedListComp
        ListView {
            property bool rotaryCrownSpeed: true
            width: 384
            height: 384
            model: 20
            snapMode: ListView.SnapToItem
            delegate: Rectangle { width: 384; height: 100; color: index % 2 ? "#333333" : "#555555" }
        }
    }
    // the face picker's set-up: horizontal, SnapOneItem, StrictlyEnforceRange, centred items
    Component {
        id: pickerComp
        ListView {
            property bool rotaryCrownSpeed: true
            width: 384
            height: 384
            orientation: ListView.Horizontal
            model: 10
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 92
            preferredHighlightEnd: 292
            delegate: Rectangle { width: 200; height: 384; color: index % 2 ? "#333333" : "#555555" }
        }
    }

    function test_0_crown() {
        var f = make(freeComp)
        wait(50)
        crown(f, 4)
        settle(f, "contentY")
        near(f.contentY, 30, 0.5, "the image's crown: 7.5 px per count")
    }

    // a snapping list, default: one item per detent (24 counts); 8 counts move nothing
    function test_1_defaultSteps() {
        var lv = make(listComp)
        wait(50)
        crown(lv, 8)
        settle(lv, "contentY")
        compare(lv.contentY, 0, "the default: no step under a detent")
        wait(350)
        crown(lv, 24)
        settle(lv, "contentY")
        near(lv.contentY, 100, 0.5, "one detent: one item")
    }

    // crown-speed: the crown's pixels, then the nearest item
    function test_2_freeThenSnap() {
        var lv = make(speedListComp)
        wait(50)
        crown(lv, 4)
        wait(30)
        verify(lv.contentY > 0, "moves at once by crown pixels: " + lv.contentY)
        settle(lv, "contentY")
        compare(lv.contentY, 0, "30 px: back to the nearest item (0)")
        wait(350)
        crown(lv, 8)
        settle(lv, "contentY")
        near(lv.contentY, 100, 0.5, "60 px: on to the nearest item (100)")
        wait(350)
        crown(lv, 20)
        settle(lv, "contentY")
        near(lv.contentY, 300, 0.5, "150 px more (250): a tie goes the crown's way (300)")
        wait(350)
        crown(lv, -6)
        settle(lv, "contentY")
        near(lv.contentY, 300, 0.5, "45 px back: the nearest is still 300")
        wait(350)
        crown(lv, -8)
        settle(lv, "contentY")
        near(lv.contentY, 200, 0.5, "60 px back: 200")
    }

    // the ends: bounded, no overshoot; the end of a list that cannot bring its last item to the top
    function test_3_ends() {
        var lv = make(speedListComp)
        wait(50)
        crown(lv, -8)
        settle(lv, "contentY")
        compare(lv.contentY, 0, "at the start: stays")
        lv.positionViewAtEnd()
        wait(50)
        var end = lv.contentY
        near(end, 2000 - 384, 0.5, "the end")
        crown(lv, 8)
        settle(lv, "contentY")
        near(lv.contentY, end, 0.5, "past the end: stays at the end")
        wait(350)
        crown(lv, -1)
        settle(lv, "contentY")
        near(lv.contentY, end, 0.5, "7.5 px back (1608.5): the end (1616) is nearer than item 16 (1600)")
        wait(350)
        crown(lv, -4)
        settle(lv, "contentY")
        near(lv.contentY, 1600, 0.5, "30 px back (1586): item 16 at 1600 (14 px) rather than the end (30)")
        wait(350)
        crown(lv, -10)
        settle(lv, "contentY")
        near(lv.contentY, 1500, 0.5, "75 px back (1525): the item at 1500")
    }

    // the face picker's set-up: the snapped item is the current one
    function test_4_highlightRange() {
        var p = make(pickerComp)
        wait(50)
        near(p.contentX, -92, 0.5, "the first item centred")
        compare(p.currentIndex, 0)
        crown(p, 16)
        settle(p, "contentX")
        near(p.contentX, 108, 0.5, "120 px: the second item (80 px away) rather than the first (120)")
        compare(p.currentIndex, 1, "the snapped item is current")
        wait(350)
        crown(p, -8)
        settle(p, "contentX")
        near(p.contentX, 108, 0.5, "60 px back: still the second")
        compare(p.currentIndex, 1)
        wait(350)
        crown(p, -16)
        settle(p, "contentX")
        near(p.contentX, -92, 0.5, "120 px back: the first")
        compare(p.currentIndex, 0)
        wait(350)
        crown(p, -8)
        settle(p, "contentX")
        near(p.contentX, -92, 0.5, "before the first: stays")
        wait(350)
        crown(p, 80)
        settle(p, "contentX")
        near(p.contentX, 508, 0.5, "600 px: the fourth item")
        compare(p.currentIndex, 3)
        wait(350)
        crown(p, 200)
        settle(p, "contentX")
        near(p.contentX, 1708, 0.5, "past the end: the last item centred")
        compare(p.currentIndex, 9)
    }

    // a finger takes over: the view's own snapping
    function test_5_finger() {
        var lv = make(speedListComp)
        wait(50)
        crown(lv, 6)
        mousePress(lv, 192, 300)
        mouseRelease(lv, 192, 300)
        settle(lv, "contentY")
        verify(lv.contentY >= 0 && lv.contentY < 100, "no crown snap after the finger: " + lv.contentY)
    }
}
