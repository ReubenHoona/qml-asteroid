// Q5 (N61-33 follow-up): EdgeButton content placed as stock's ScaleAndAlignContentNode
// (6 dp top, 8 dp bottom). Stock: the Wear OS 6 emulator S05 'All apps' edge button
// (x 64-318, y 238-377, #DBE2F9) has its label ink at y 294-322 (cap top 294).
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
        name: "Q5edge"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function cleanup() {
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            wait(0)
        }
        function make(props) {
            var e = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; EdgeButton { ' + props + ' }', host)
            tryVerify(function() { return Math.abs(e.shownHeight - e.preferredHeight) < 0.5 }, 3000, "shown in full")
            wait(50)
            return e
        }
        // the control's own content Column (the only Column child)
        function content(e) {
            for (var i = 0; i < e.children.length; i++)
                if (e.children[i].spacing !== undefined && e.children[i].objectName === "")
                    return e.children[i]
            return null
        }
        function lum(p) { return 255 * (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) }
        // dark ink rows inside the button (x0..x1, y0..y1), as the stock measurement (L < 140)
        function inkRows(img, x0, x1, y0, y1) {
            var first = -1, last = -1
            for (var y = y0; y <= y1; y++) {
                for (var x = x0; x <= x1; x++) {
                    if (lum(img.pixel(x, y)) < 140) {
                        if (first < 0)
                            first = y
                        last = y
                        break
                    }
                }
            }
            return [first, last]
        }

        // the launcher's Recents end: WearList's EdgeButton with the control's own label
        function test_1_allApps() {
            var e = make('preferredHeight: Theme.size.edgeButtonMedium; text: "All apps"')
            near(e.mapToItem(top, 0, 0).y, 238, 0.5, "button top as S05")
            near(e.height, 140, 0.5, "70 dp")
            waitForRendering(e)
            var img = grabImage(top)
            img.save("shots/edge-allapps.png")
            var r = inkRows(img, 110, 274, 240, 350)
            console.log("Q5 allApps ink rows " + r[0] + "-" + r[1] + " content y " + content(e).y + " h " + content(e).height.toFixed(2))
            near(r[0], 294, 1, "label cap top as S05 (294)")
            near(r[1], 322, 2, "descender bottom as S05 (322)")
        }

        // stock's rule for every size: round((H - h + 12 - 16) / 2), at least 12 px
        function test_2_rule() {
            var sizes = [Theme.size.edgeButtonExtraSmall, Theme.size.edgeButtonSmall, Theme.size.edgeButtonMedium, Theme.size.edgeButtonLarge]
            for (var i = 0; i < sizes.length; i++) {
                var e = make('preferredHeight: ' + sizes[i] + '; text: "Done"')
                var c = content(e)
                var want = Math.max(12, Math.round((e.height - c.height + 12 - 16) / 2))
                near(c.y, want, 0.01, "content y at " + sizes[i] + " px")
                console.log("Q5 rule H " + e.height + " h " + c.height.toFixed(2) + " y " + c.y + " (centred " + ((e.height - c.height) / 2).toFixed(2) + ")")
                e.destroy()
                wait(0)
            }
        }

        // the launcher's 'List view' / 'Grid view': its own Column child, not moved
        function test_3_ownContentUnmoved() {
            var e = make('id: eb; preferredHeight: Theme.size.edgeButtonMedium; text: ""; '
                + 'Column { objectName: "own"; anchors.centerIn: parent; anchors.verticalCenterOffset: -Theme.dp(1.5); '
                + 'Label { anchors.horizontalCenter: parent.horizontalCenter; text: "List view"; role: "labelMedium"; color: eb.contentColor; maximumLineCount: 1 } '
                + 'Item { width: Theme.size.iconSmall; height: width } }')
            var own = findChild(e, "own")
            near(own.mapToItem(top, 0, 0).y + own.height / 2, 238 + 70 - 3, 0.5, "own content centred 1.5 dp above the middle")
            waitForRendering(e)
            var img = grabImage(top)
            img.save("shots/edge-listview.png")
            var r = inkRows(img, 110, 274, 240, 300)
            console.log("Q5 listView label ink rows " + r[0] + "-" + r[1])
            near(r[0], 270, 2, "the label's ink from y 270 as S05-b")
        }
    }
}
