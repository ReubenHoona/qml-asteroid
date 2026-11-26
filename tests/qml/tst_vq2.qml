// independent checks of WO-61-Q2 (verifier)
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384
    Rectangle { anchors.fill: parent; color: "#000000" }

    // Exercise / Map style page: Column at 5.2 %, 4 dp spacing, plain rows (no EdgeEffect)
    Flickable {
        id: ex
        width: 384; height: 384
        visible: false
        contentHeight: excol.y + excol.height + 140
        Column {
            id: excol
            y: Math.round(384 * 0.1664)
            x: Math.round(384 * 0.052)
            width: 384 - 2 * x
            spacing: Theme.space.xs
            ListHeader { id: exTitle; text: "Exercise" }
            Repeater { model: 3; Rectangle { width: parent.width; height: 104; radius: 52; color: "#2F3036" } }
            ListSubHeader { id: exSub; text: "Button action" }
            Repeater { model: 4; Rectangle { width: parent.width; height: 104; radius: 52; color: "#2F3036" } }
        }
    }

    // ScalingList with a sub-header row inside its itemDelegate (Weather settings)
    ScalingList {
        id: wl
        width: 384; height: 384
        visible: false
        model: 4
        itemDelegate: Item {
            property int index
            height: index === 1 ? hdr.height : 104
            Rectangle { visible: index !== 1; width: parent.width; height: 104; radius: 52; color: "#2F3036" }
            ListSubHeader { id: hdr; visible: index === 1; text: "Temperature Units" }
        }
    }

    // ListItems, one with edgeEffect false
    Flickable {
        id: li
        width: 384; height: 384
        visible: false
        contentHeight: licol.y + licol.height + 140
        Column {
            id: licol
            y: 64
            width: parent.width
            Repeater {
                model: 10
                ListItem { title: "Row " + index; edgeEffect: index !== 5 }
            }
        }
    }
    // the same, all on
    Flickable {
        id: li2
        width: 384; height: 384
        visible: false
        contentHeight: licol2.y + licol2.height + 140
        Column {
            id: licol2
            y: 64
            width: parent.width
            Repeater { model: 10; ListItem { title: "Row " + index } }
        }
    }

    TestCase {
        name: "VQ2"
        when: windowShown
        function cleanup() { ex.visible = false; wl.visible = false; li.visible = false; li2.visible = false }
        function inkLeft(img, y0, y1) {
            var left = 999
            for (var y = y0; y < y1; y++)
                for (var x = 0; x < 200; x++) {
                    var p = img.pixel(x, y)
                    if (p.r > 150 / 255 && p.g > 150 / 255 && p.b > 150 / 255) { left = Math.min(left, x); break }
                }
            return left
        }
        function rect(it, f, inset) {
            var a = it.mapToItem(f, 0, inset), b = it.mapToItem(f, 0, it.height - inset)
            return { top: a.y, bottom: b.y }
        }
        function edgeOf(item) {
            for (var k = 0; k < item.data.length; k++)
                if (item.data[k].originY !== undefined && item.data[k].transformedHeight !== undefined)
                    return item.data[k]
            return null
        }

        function test_1_subHeaderInsetColumn() {
            ex.visible = true
            ex.contentY = exSub.parent.mapToItem(ex.contentItem, 0, exSub.y).y - 150
            wait(30)
            waitForRendering(ex)
            var img = grabImage(top)
            var y = Math.max(0, exSub.mapToItem(top, 0, 0).y)
            console.log("Exercise column x", excol.x, "sub-header label x", exSub.label.mapToItem(top, 0, 0).x,
                        "ink from x", inkLeft(img, y, y + exSub.height), "(stock 52; before Q2: 36)")
        }
        function test_2_subHeaderInScalingList() {
            wl.visible = true
            waitForRendering(wl)
            var img = grabImage(top)
            var row = wl.itemAtIndex(1)
            var y = row.mapToItem(top, 0, 0).y
            console.log("ScalingList itemDelegate sub-header ink from x", inkLeft(img, y, y + row.height), "(stock 52)")
        }
        function test_3_headersMoveAlone() {
            ex.visible = true
            var worstUp = 0, worstDown = 0, minTitle = 1, minSub = 1, worstOverlapBelow = 0, worstOverlapAbove = 0
            var kids = []
            for (var k = 0; k < excol.children.length; k++)
                if (excol.children[k].radius === 52) kids.push(excol.children[k])
            for (var cy = -50; cy < ex.contentHeight - 384 + 50; cy += 3) {
                ex.contentY = cy
                var te = edgeOf(exTitle), se = edgeOf(exSub)
                minTitle = Math.min(minTitle, te.scale); minSub = Math.min(minSub, se.scale)
                // the sub-header picture against the plain rows above and below it
                var s = rect(exSub, ex, 0)
                var above = kids[2], below = kids[3]
                var ab = above.mapToItem(ex, 0, above.height).y, bt = below.mapToItem(ex, 0, 0).y
                var natTop = exSub.mapToItem(ex, 0, 0).y // includes transform; recompute natural:
                var nat = exSub.parent.mapToItem(ex, 0, exSub.y).y
                worstUp = Math.max(worstUp, nat - s.top)
                if (s.bottom > bt + 0.5 && s.top < 384) worstOverlapBelow = Math.max(worstOverlapBelow, s.bottom - bt)
                if (s.top < ab - 0.5 && s.bottom > 0) worstOverlapAbove = Math.max(worstOverlapAbove, ab - s.top)
                worstDown = Math.max(worstDown, s.top - nat)
            }
            console.log("Exercise: title min scale", minTitle.toFixed(3), "sub-header min scale", minSub.toFixed(3),
                        "sub-header picture moved up to", worstUp.toFixed(1), "px / down", worstDown.toFixed(1),
                        "px against the unscaled rows; overlap into the row below", worstOverlapBelow.toFixed(1), "above", worstOverlapAbove.toFixed(1))
        }
        function sweepGaps(f, col, inset) {
            var items = []
            for (var k = 0; k < col.children.length; k++)
                if (col.children[k].button !== undefined) items.push(col.children[k])
            var minGap = 1e9, maxGap = -1e9, at = 0
            for (var cy = -60; cy < f.contentHeight - 384 + 60; cy += 2) {
                f.contentY = cy
                for (var i = 0; i + 1 < items.length; i++) {
                    var a = rect(items[i].button, f, 0), b = rect(items[i + 1].button, f, 0)
                    if (b.top > 384 || a.bottom < 0) continue
                    var g = b.top - a.bottom
                    if (g < minGap) { minGap = g; at = cy }
                    maxGap = Math.max(maxGap, g)
                }
            }
            return { min: minGap, max: maxGap, at: at }
        }
        function test_4_gapsAllOn() {
            li2.visible = true
            wait(30)
            var r = sweepGaps(li2, licol2)
            console.log("ListItems all on: gaps over the sweep", r.min.toFixed(2), "-", r.max.toFixed(2))
        }
        function test_5_oneOff() {
            li.visible = true
            wait(30)
            var r = sweepGaps(li, licol)
            console.log("ListItems with row 5 edgeEffect false: gaps over the sweep", r.min.toFixed(2), "-",
                        r.max.toFixed(2), "worst at contentY", r.at)
        }
    }
}
