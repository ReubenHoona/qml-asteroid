// WO-61-Q3: a Button used as a list row joins the packed edge layout (Q2,
// N61-04) when its edgeEffect is set; by default it makes no EdgeEffect.
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    Flickable {
        id: flick
        width: 384; height: 384
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            Repeater { model: 4; ListItem { title: "Row " + index } }
            Button { id: rowButton; x: Theme.margin.listSide; width: 384 - 2 * x; variant: "tonal"; text: "Add"; edgeEffect: true }
            Repeater { model: 6; ListItem { title: "Row " + (index + 4) } }
        }
    }
    Button { id: plain; text: "Plain"; visible: false }

    TestCase {
        id: tc
        name: "Q3edge"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        // the drawn top and bottom of an item in the Flickable's viewport
        function drawn(item) {
            var a = item.mapToItem(flick, 0, 0), b = item.mapToItem(flick, 0, item.height)
            return { top: a.y, bottom: b.y }
        }

        function test_1_defaultMakesNone() {
            compare(plain.edgeEffect, false, "off by default")
            compare(plain._edge, null, "no EdgeEffect made")
            compare(plain.transform[0].xScale, 1, "identity scale")
            compare(plain.transform[1].y, 0, "no shift")
        }

        function test_2_packedWithNeighbours() {
            verify(rowButton._edge !== null, "made when set")
            compare(rowButton._edge.packed, true, "packed")
            // the button low on the screen, about where a row top of 347 is
            flick.contentY = rowButton.y - 330
            wait(100)
            var e = rowButton._edge
            verify(e.scale < 1, "shrinks near the bottom edge: " + e.scale)
            compare(rowButton.transform[0].xScale, e.scale, "Scale from the effect")
            compare(rowButton.transform[1].y, e.translateY, "Translate from the effect")
            compare(rowButton.container.opacity, e.alpha, "alpha on the container")
            // the row before it (a packed ListItem) and the button stay apart, not overlapping
            var prev = null
            for (var i = 0; i < col.children.length; i++) {
                var c = col.children[i]
                if (c.title !== undefined && c.y < rowButton.y && (!prev || c.y > prev.y)) prev = c
            }
            var d = drawn(rowButton), dp = drawn(prev)
            console.log("Q3edge button scale", e.scale.toFixed(3), "top", d.top.toFixed(1), "previous row bottom", dp.bottom.toFixed(1))
            verify(d.top >= dp.bottom - 4.5, "packed under its neighbour")
            rowButton.edgeEffect = false
            wait(50)
            compare(e.scale, 1, "off again: at rest")
            compare(rowButton.transform[0].xScale, 1)
        }
    }
}
