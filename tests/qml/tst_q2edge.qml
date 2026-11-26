// WO-61-Q2 N61-04: the packed edge layout. EdgeLayout is the launcher's
// WearEdge.js in C++ (compared here with a copy of WearEdge.js); the rows of
// ScalingList, ListItem, ListRow and the list headers scale about their edge
// nearest the centre and close up. Stock: the Wear OS 6 emulator, Settings
// S16-S22: a row bottom at y 74 is at scale 0.85 / alpha 0.75, a row top at
// y 347 at 0.75 / 0.58, 8 px between rows at every scale (S17: Google row
// bottom 74, Sound 83-186, Vibration 195-298, Battery top 307).
import QtQuick
import QtTest
import org.asteroid.controls
import "ref/WearEdge.js" as Ref

Item {
    id: top
    width: 384
    height: 384

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // eight 104 px rows, 8 px apart, as Settings (S16: chips x 20-364)
    ScalingList {
        id: slist
        width: 384; height: 384
        visible: false
        model: 8
        itemDelegate: Rectangle { height: 104; color: "white"; property int index: -1 }
    }

    // ListItems in a Column (each keeps 2 dp above and below its row)
    Flickable {
        id: flick
        width: 384; height: 384
        visible: false
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            y: 64
            ListHeader { id: lhead; text: "Settings" }
            Repeater {
                model: 8
                ListItem { title: "Row " + index; iconName: "ios-help" }
            }
            ListSubHeader { id: lsub; text: "More" }
            Repeater {
                model: 3
                // ListRow's height defaults to its parent's: give it its own in a Column
                ListRow { text: "Row " + index; height: implicitHeight }
            }
            Item { width: 1; height: 300 }
        }
    }

    // a ListItem given to a ScalingList as its row: the list does the edge
    ScalingList {
        id: nested
        width: 384; height: 384
        visible: false
        model: 8
        itemDelegate: ListItem { property int index: -1; title: "Row " + index; iconName: "ios-help" }
    }

    // a header with the page's own EdgeEffect (Settings, Health) keeps it
    Flickable {
        id: own
        width: 384; height: 384
        visible: false
        contentHeight: 2000
        Column {
            width: parent.width
            ListHeader {
                id: ownHeader
                text: "Own"
                EdgeEffect { id: ownEdge; item: ownHeader }
                transform: Scale { yScale: ownEdge.scale }
            }
            Repeater {
                model: 10
                ListItem { title: "Row " + index }
            }
        }
    }

    // a page of plain rows (Exercise, Map): its headers stay as they are
    Flickable {
        id: plain
        width: 384; height: 384
        visible: false
        contentHeight: pcol.y + pcol.height + 140
        Column {
            id: pcol
            x: 20; y: 64
            width: 344
            spacing: Theme.space.xs
            ListHeader { id: pTitle; text: "Exercise" }
            Repeater { model: 3; Rectangle { width: parent.width; height: 104; radius: 52; color: "#2F3036" } }
            ListSubHeader { id: pSub; text: "Button action" }
            Repeater { model: 3; Rectangle { width: parent.width; height: 104; radius: 52; color: "#2F3036" } }
            Button { id: pButton; width: parent.width; text: "Add" }
            Repeater { model: 2; Rectangle { width: parent.width; height: 104; radius: 52; color: "#2F3036" } }
        }
    }

    // the OptionCycler chooser: a ListView with a ListHeader over plain buttons
    ListView {
        id: chooser
        width: 384; height: 384
        visible: false
        topMargin: Theme.margin.listTop
        spacing: Theme.space.xs
        model: 8
        header: ListHeader { text: "Choose" }
        delegate: RadioButton { x: 20; width: 344; text: "Option " + index }
    }

    // one row: the row nearest the middle is the only one, and shrinks
    ScalingList {
        id: single
        width: 384; height: 384
        visible: false
        model: 1
        itemDelegate: Rectangle { height: 104; color: "white"; property int index: -1 }
    }

    TestCase {
        name: "Q2edge"
        when: windowShown

        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " not within " + tol + " of " + b)
        }
        function cleanup() {
            slist.visible = false
            flick.visible = false
            nested.visible = false
            own.visible = false
            plain.visible = false
            chooser.visible = false
            single.visible = false
            pButton.edgeEffect = false
        }
        function findEdge(item) {
            for (var k = 0; k < item.data.length; k++)
                if (item.data[k].transformedHeight !== undefined && item.data[k].originY !== undefined)
                    return item.data[k]
            return null
        }

        // ---- EdgeLayout = WearEdge.js ----
        function jsScaling() {
            return { minElementHeight: 0.2, maxElementHeight: 0.6, minArea: 0.35, maxArea: 0.55,
                     easing: [0.3, 0, 0.7, 1],
                     containerAlpha: Ref.variable(0.5, 0.5, 0, 1), contentAlpha: Ref.variable(0.5, 0.5, 0, 1),
                     scale: Ref.variable(0.7, 0.7, 0, 1), sideOffset: null }
        }
        function test_01_scalingSpec() {
            var s = EdgeLayout.scaling
            compare(s.minElementHeight, 0.2)
            compare(s.maxElementHeight, 0.6)
            near(s.minArea, 0.35, 1e-12, "min area")
            near(s.maxArea, 0.55, 1e-12, "max area")
            compare(s.easing.length, 4)
            near(s.easing[0], 0.3, 1e-12, "x1"); near(s.easing[2], 0.7, 1e-12, "x2")
            near(s.scale.top, 0.7, 1e-12, "edge scale"); compare(s.scale.target, 1)
            near(s.containerAlpha.bottom, 0.5, 1e-12, "edge alpha")
            near(s.contentAlpha.top, 0.5, 1e-12, "edge content alpha")
            compare(EdgeLayout.transformedHeight(104, 0.85), 89, "ceil(s h)")
            // the same values as an EdgeEffect at the same place (192 dp spec)
            var v = EdgeLayout.evaluate(s, 0, 104 / 384, false)
            var area = 0.35 + 0.2 * ((104 / 384 - 0.2) / 0.4)
            near(v.scale, 0.7 + 0.3 * Ref.bezier([0.3, 0, 0.7, 1], (104 / 384) / area), 1e-9, "evaluate")
            var r = EdgeLayout.evaluate(s, 0, 104 / 384, true)
            compare(r.scale, 1, "reduced: at rest")
        }

        function compareLayouts(spec, jsSpec, tops, hs, gaps, vh, what) {
            var c = EdgeLayout.layout(spec, tops, hs, gaps, vh, false)
            var j = Ref.layout(jsSpec, tops, hs, gaps, vh, false)
            compare(c.length, j.length, what + " length")
            for (var i = 0; i < j.length; i++) {
                var a = c[i], b = j[i]
                verify(b !== undefined, what + " js item " + i)
                var keys = ["y", "height", "scale", "containerAlpha", "contentAlpha", "sideOffset"]
                for (var k = 0; k < keys.length; k++)
                    near(a[keys[k]], b[keys[k]], 1e-9, what + " item " + i + " " + keys[k])
                compare(a.shown, b.shown, what + " item " + i + " shown")
            }
        }
        function test_02_sameAsWearEdge() {
            // deterministic pseudo-random lists over a sweep of scroll positions
            var seed = 7
            function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
            for (var trial = 0; trial < 40; trial++) {
                var n = 3 + Math.floor(rnd() * 10)
                var tops = [], hs = [], gaps = []
                var y = -400 + rnd() * 600
                for (var i = 0; i < n; i++) {
                    var h = 40 + Math.floor(rnd() * 200)
                    var g = Math.floor(rnd() * 16)
                    tops.push(y); hs.push(h); gaps.push(g)
                    y += h + g
                }
                compareLayouts(EdgeLayout.scaling, jsScaling(), tops, hs, gaps, 384, "SCALING " + trial)
                compareLayouts(Ref.LIST, Ref.LIST, tops, hs, gaps, 384, "LIST " + trial)
                compareLayouts(Ref.GRID, Ref.GRID, tops, hs, gaps, 384, "GRID " + trial)
            }
            // side: -1 above the anchor, 0 the anchor, 1 below
            var out = EdgeLayout.layout(EdgeLayout.scaling, [-100, 20, 140, 260, 380], [104, 104, 104, 104, 104],
                                        [16, 16, 16, 16, 0], 384, false)
            compare(out[2].side, 0, "anchor nearest the middle")
            compare(out[1].side, -1); compare(out[3].side, 1)
        }

        // ---- ScalingList ----
        function drawn(item, view) {
            var a = item.mapToItem(view, 0, 0), b = item.mapToItem(view, 0, item.height)
            return { top: a.y, bottom: b.y }
        }
        function sRow(i) {
            var row = slist.itemAtIndex(i)
            return row ? row.children[0] : null
        }
        // contentY that puts edge `which` of row i (drawn) at y
        function solve(view, rowOf, i, which, y) {
            var lo = view.originY - view.topMargin - 600, hi = view.originY + view.contentHeight + 600
            for (var it = 0; it < 60; it++) {
                var mid = (lo + hi) / 2
                view.contentY = mid
                var r = rowOf(i)
                var v = r ? drawn(r, view)[which] : 1e9
                if (v > y) lo = mid; else hi = mid
            }
            view.contentY = (lo + hi) / 2
            return rowOf(i)
        }

        function test_03_scalingListBottom74() {
            slist.visible = true
            wait(50)
            var h0 = slist.contentHeight
            var r1 = solve(slist, sRow, 1, "bottom", 74)
            var e1 = findEdge(r1.parent)
            var d1 = drawn(r1, slist), d2 = drawn(sRow(2), slist)
            console.log("bottom 74: scale", e1.scale.toFixed(4), "alpha", e1.alpha.toFixed(4), "gap", (d2.top - d1.bottom).toFixed(2))
            near(d1.bottom, 74, 0.05, "row 1 drawn bottom")
            near(e1.scale, 0.85, 0.02, "scale at a bottom of 74 (S17)")
            near(e1.alpha, 0.75, 0.03, "alpha at a bottom of 74")
            near(d2.top - d1.bottom, 8, 1, "gap to the next row (S17: 74 -> 83)")
            near(d1.bottom - d1.top, 104 * e1.scale, 0.01, "shrunk about its bottom")
            compare(e1.originY, 104, "above the middle: pivot at the bottom")
            // row 3 (195-298) is nearest the middle: it and the rows below
            // scale about their top, row 2 (83-186) above it about its bottom
            compare(findEdge(sRow(3).parent).originY, 0, "the middle row: pivot at the top")
            compare(findEdge(sRow(2).parent).originY, 104, "the row above the middle: pivot at the bottom")
            // rows keep their natural place: the list keeps its length and
            // each delegate its height
            near(slist.contentHeight, h0, 0.5, "content height unchanged")
            compare(r1.parent.height, 104, "delegate at its natural height")
            slist.visible = false
        }

        function test_04_scalingListTop347() {
            slist.visible = true
            wait(50)
            var r = solve(slist, sRow, 5, "top", 347)
            var e = findEdge(r.parent)
            var d = drawn(r, slist), dp = drawn(sRow(4), slist)
            console.log("top 347: scale", e.scale.toFixed(4), "alpha", e.alpha.toFixed(4), "gap", (d.top - dp.bottom).toFixed(2))
            near(d.top, 347, 0.05, "row 5 drawn top")
            near(e.scale, 0.75, 0.02, "scale at a top of 347 (S16)")
            near(e.alpha, 0.58, 0.03, "alpha at a top of 347")
            near(d.top - dp.bottom, 8, 1, "8 px under the previous row")
            compare(e.originY, 0, "below the middle: pivot at the top")
            slist.visible = false
        }

        // the screenshot method: runs of non-black pixels down x = 192
        function runs(img) {
            var out = [], cur = -1
            for (var y = 0; y < 384; y++) {
                var p = img.pixel(192, y)
                var on = p.r + p.g + p.b > 30 / 255
                if (on && cur < 0) cur = y
                if (!on && cur >= 0) { out.push([cur, y - 1]); cur = -1 }
            }
            if (cur >= 0) out.push([cur, 383])
            return out
        }
        function test_05_scalingListPixels() {
            slist.visible = true
            wait(50)
            solve(slist, sRow, 1, "bottom", 74.5)
            waitForRendering(slist)
            var rr = runs(grabImage(top))
            console.log("x 192 runs", JSON.stringify(rr))
            // S17: (0, 74) (83, 186) (195, 298) (307, 383)
            verify(rr.length >= 4, "four rows on screen: " + JSON.stringify(rr))
            near(rr[0][1], 74, 1, "row bottom " + JSON.stringify(rr))
            near(rr[1][0] - rr[0][1] - 1, 8, 1, "gap 1")
            near(rr[1][1] - rr[1][0] + 1, 104, 1, "full row")
            near(rr[2][0] - rr[1][1] - 1, 8, 1, "gap 2")
            near(rr[3][0] - rr[2][1] - 1, 8, 1, "gap 3")
            near(rr[3][0], 307, 2, "bottom row top (S17 307)")
            slist.visible = false
        }

        // ---- ListItem / ListRow / headers in a Column ----
        function colRow(i) {
            // children: header, 8 ListItems, (Repeater), sub-header, 3 ListRows ...
            var items = []
            for (var k = 0; k < col.children.length; k++)
                if (col.children[k].button !== undefined) items.push(col.children[k])
            return items[i] ? items[i].button : null
        }
        function test_06_listItemsPacked() {
            flick.visible = true
            wait(50)
            var b = solve(flick, colRow, 2, "bottom", 74)
            var li = b.parent
            var e = findEdge(li)
            var d = drawn(b, flick), dn = drawn(colRow(3), flick)
            console.log("ListItem bottom 74: scale", e.scale.toFixed(4), "alpha", e.alpha.toFixed(4), "gap", (dn.top - d.bottom).toFixed(2))
            near(d.bottom, 74, 0.05, "container bottom")
            near(e.scale, 0.85, 0.02, "ListItem scale at 74")
            near(e.alpha, 0.75, 0.03, "ListItem alpha at 74")
            near(dn.top - d.bottom, 8, 1, "8 px between the containers")
            compare(e.originY, 108, "pivot at the container's bottom (2 dp inset)")
            compare(e.inset, 4, "2 dp inset")
            // the transform: Scale first (tests read transform[0].xScale), then Translate
            compare(li.transform[0].xScale, e.scale)
            compare(li.transform[1].y, e.translateY)
            var bb = solve(flick, colRow, 6, "top", 347)
            var e6 = findEdge(bb.parent)
            near(e6.scale, 0.75, 0.02, "ListItem scale at a top of 347")
            near(e6.alpha, 0.58, 0.03, "ListItem alpha at 347")
            near(drawn(bb, flick).top - drawn(colRow(5), flick).bottom, 8, 1, "8 px under the previous container")
            compare(e6.originY, 4, "pivot at the container's top")
            flick.visible = false
        }

        function test_07_headersPack() {
            flick.visible = true
            wait(50)
            // the title at the top edge shrinks about its bottom and keeps its
            // gap to the first row
            var b0 = solve(flick, colRow, 0, "top", 70)
            var he = findEdge(lhead)
            verify(he.scale < 1 && he.scale > 0.7, "the title shrinks: " + he.scale)
            compare(he.originY, lhead.height, "about its bottom")
            var hb = lhead.mapToItem(flick, 0, lhead.height).y
            near(drawn(b0, flick).top - hb, 4, 1, "the title keeps its natural gap (the row's 2 dp)")
            // the sub-header between ListItems and ListRows packs as a row
            var se = findEdge(lsub)
            verify(se !== null, "ListSubHeader has an EdgeEffect")
            var rows = []
            for (var k = 0; k < col.children.length; k++)
                if (col.children[k].container !== undefined) rows.push(col.children[k])
            compare(rows.length, 3, "three ListRows")
            var lr = rows[0]
            flick.contentY = lsub.y + col.y - 200   // the sub-header at y 200, its row at 300
            wait(20)
            var subBottom = lsub.mapToItem(flick, 0, lsub.height).y
            var rowTop = lr.container.mapToItem(flick, 0, 0).y
            near(rowTop - subBottom, 4, 1, "the ListRow keeps its 2 dp under the sub-header")
            var le = findEdge(lr)
            compare(le.inset, 4, "ListRow 2 dp inset")
            verify(le.scale < 1, "the ListRow shrinks low on the screen: " + le.scale)
            flick.visible = false
        }

        function test_08_nestedRowLeavesItToTheList() {
            nested.visible = true
            wait(50)
            nested.contentY = nested.contentY + 60
            wait(20)
            var row = nested.itemAtIndex(0)
            var outer = findEdge(row)
            var inner = findEdge(row.children[0].item)
            verify(outer.scale < 1, "the list's edge: " + outer.scale)
            compare(inner.scale, 1, "the ListItem's own edge at rest")
            compare(inner.translateY, 0)
            compare(inner.alpha, 1)
            nested.visible = false
        }

        function test_09_ownEffectWins() {
            own.visible = true
            wait(50)
            own.contentY = 60
            wait(20)
            var inner = findEdge(ownHeader)
            // the header carries two: its own (packed) and the page's
            var packedOne = null
            for (var k = 0; k < ownHeader.data.length; k++) {
                var d = ownHeader.data[k]
                if (d.originY !== undefined && d.packed) packedOne = d
            }
            verify(packedOne !== null)
            compare(packedOne.scale, 1, "the header's own packed effect sits out")
            verify(ownEdge.scale < 1, "the page's effect works: " + ownEdge.scale)
            own.visible = false
        }
        // headers among plain rows stay at rest at every scroll position; one
        // packed row (a Button with edgeEffect) brings them in
        function sweepAtRest(view, items, what) {
            var worst = 0
            for (var cy = view.originY - 80; cy < view.originY + view.contentHeight - 384 + 80; cy += 3) {
                view.contentY = cy
                for (var i = 0; i < items.length; i++) {
                    var e = findEdge(items[i])
                    worst = Math.max(worst, Math.abs(1 - e.scale), Math.abs(1 - e.alpha), Math.abs(e.translateY))
                }
            }
            compare(worst, 0, what + ": at rest over the whole scroll")
        }
        function test_11_headersAmongPlainRows() {
            plain.visible = true
            wait(50)
            sweepAtRest(plain, [pTitle, pSub], "title and sub-header among plain rows")
            // a Button joining as a packed row brings the headers in
            pButton.edgeEffect = true
            wait(50)
            plain.contentY = 70
            wait(20)
            var te = findEdge(pTitle)
            verify(te.scale < 1 && te.scale > 0.7, "the title shrinks once the list has a packed row: " + te.scale)
            pButton.edgeEffect = false
            wait(50)
            sweepAtRest(plain, [pTitle, pSub], "and at rest again without it")
            plain.visible = false
        }
        function test_12_chooserHeader() {
            chooser.visible = true
            wait(50)
            var h = chooser.headerItem
            verify(h !== null)
            sweepAtRest(chooser, [h], "OptionCycler's chooser title over RadioButtons")
            chooser.visible = false
        }

        // the packer draws every row where WearEdge.js (and EdgeLayout.layout)
        // puts it: the picture's top at y, scale as there, over a sweep
        function packedAgainstRef(view, count, what) {
            var worst = 0, n = 0
            for (var cy = view.originY - view.topMargin - 120; cy < view.originY + view.contentHeight + 120; cy += 7) {
                view.contentY = cy
                var tops = [], hs = [], gaps = [], rows = []
                for (var i = 0; i < count; i++) {
                    var row = view.itemAtIndex(i)
                    if (!row) continue
                    rows.push(row)
                    tops.push(row.mapToItem(view, 0, 0).y)   // the delegate: its natural place
                    hs.push(row.children[0].height)
                }
                for (var g = 0; g + 1 < tops.length; g++)
                    gaps.push(tops[g + 1] - tops[g] - hs[g])
                gaps.push(0)
                var ref = Ref.layout(jsScaling(), tops, hs, gaps, 384, false)
                for (var k = 0; k < rows.length; k++) {
                    if (!ref[k].shown) continue
                    var c = rows[k].children[0], e = findEdge(rows[k])
                    worst = Math.max(worst, Math.abs(c.mapToItem(view, 0, 0).y - ref[k].y), Math.abs(e.scale - ref[k].scale))
                    n++
                }
            }
            verify(n > 20, what + ": rows compared " + n)
            verify(worst < 0.01, what + ": drawn top and scale as WearEdge.js, worst " + worst)
        }
        function test_13_packerAgreesWithWearEdge() {
            slist.visible = true
            wait(50)
            packedAgainstRef(slist, 8, "eight rows")
            slist.visible = false
            // a single row above the middle shrinks about its top, as WearEdge.js
            single.visible = true
            wait(50)
            packedAgainstRef(single, 1, "one row")
            // its top at y 20 (a list that cannot scroll: by its top margin)
            single.topMargin = 20
            single.positionViewAtBeginning()
            wait(50)
            var c = single.itemAtIndex(0).children[0]
            var e = findEdge(single.itemAtIndex(0))
            near(c.mapToItem(single, 0, 0).y, 20, 0.01, "its top stays")
            verify(e.scale < 1, "and it shrinks: " + e.scale)
            compare(e.originY, 0, "about its top")
            single.visible = false
        }

        // what a scroll costs: 600 contentY steps over 40 ListItems, and over a
        // page whose only packed effect (its title) stays out (logged; the
        // numbers before and after the cached packer are in the commit)
        function scrollCost(src, what) {
            var page = Qt.createQmlObject(src, top)
            wait(100)
            var t0 = Date.now()
            for (var i = 0; i < 600; i++)
                page.contentY = (i * 7) % 3000
            var ms = Date.now() - t0
            console.log(what + ": 600 scroll steps in " + ms + " ms")
            page.destroy()
            wait(20)
        }
        function test_14_scrollCost() {
            scrollCost('import QtQuick; import org.asteroid.controls; Flickable { width: 384; height: 384; '
                       + 'contentHeight: c.height; Column { id: c; width: 384; '
                       + 'Repeater { model: 40; ListItem { title: "R" + index } } } }', "40 ListItems")
            scrollCost('import QtQuick; import org.asteroid.controls; Flickable { width: 384; height: 384; '
                       + 'contentHeight: c.height; Column { id: c; width: 384; ListHeader { text: "T" } '
                       + 'Repeater { model: 40; Rectangle { width: 384; height: 104 } } } }', "a title over 40 plain rows")
            verify(true)
        }

        // a page of rows is laid out before its first frame (the packer runs
        // on afterAnimating, after the polish that places the rows)
        function test_10_firstFrame() {
            var w = top.Window.window
            verify(w !== null)
            var page = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; Flickable { width: 384; height: 384; '
                                          + 'contentHeight: c.height; contentY: 60; Column { id: c; width: 384; '
                                          + 'Repeater { model: 6; ListItem { title: "R" + index } } } }', top)
            var col0 = page.contentItem.children[0]
            var first = null
            for (var k = 0; k < col0.children.length; k++)
                if (col0.children[k].title === "R0") first = col0.children[k]
            verify(first !== null)
            var e = findEdge(first)
            var seen = null
            function onSwap() { if (seen === null) seen = { scale: e.scale, ty: e.translateY, origin: e.originY } }
            w.frameSwapped.connect(onSwap)
            tryVerify(function () { return seen !== null }, 2000)
            w.frameSwapped.disconnect(onSwap)
            verify(seen.scale < 0.95, "the top row is shrunk in the first frame: " + seen.scale)
            compare(seen.origin, 108, "about its container's bottom from the first frame")
            page.destroy()
        }
    }
}
