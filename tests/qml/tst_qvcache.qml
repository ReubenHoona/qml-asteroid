// independent probes of the EdgePacker caches (8a11336): after each change,
// one scroll step (the kept rows) against
//  - the rows' geometry at that moment (oracle(): EdgeLayout.layout on the
//    natural places read from the items, the packer's rules for plain packed
//    rows), and
//  - a forced rebuild at the same place (viewport height +1 / -1, which marks
//    the rows dirty and lays them out at once).
// r2gh: a ListView whose origin drifted after model resets with rows of mixed
// heights (test_04 / test_04b left originY -6304 and -2842) moves its content
// in the polish after that height change (contentY 1 -> -38, -293 -> -294
// seen), so the probe compared two places and test_05 / test_09 failed after
// test_04 / test_04b, never alone, with the kept rows matching the oracle
// exactly. The view is now put back before the comparison (only the oracle
// counts if it moves again), and init() gives every case fresh fixtures (all
// hidden, no transform moved, a new ListView), so a failed case leaves
// nothing for the next one.
// r2gh, N61-04: the items between the rows and the content are watched for a
// move by a transform (test_03*: all fail on e43d1cb), and restAtTop rows
// follow topMargin (test_09b: fails on e43d1cb).
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

    // A: a Column of rows and a second container in the same content
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
        // a free effect whose item can change
        Rectangle { id: freeA; y: 2000; width: 300; height: 80 }
        Rectangle { id: freeB; y: 2100; width: 300; height: 120 }
    }
    EdgeEffect { id: freeFx; packed: true }
    NumberAnimation { id: trAnim; target: tr; property: "y" }

    // T: sections moved by transforms of every kind (each 3 rows, 264 px)
    Flickable {
        id: ft
        width: 384; height: 384
        visible: false
        contentHeight: 3000
        Column { spacing: 8; Repeater { model: 4; PRow { } } }
        // a Scale on the section
        Item {
            id: secS
            y: 400
            width: 300; height: 264
            transform: Scale { id: scS; origin.y: 0; xScale: 1; yScale: 1 }
            Column { spacing: 8; Repeater { model: 3; PRow { } } }
        }
        // the Translate two levels up from the rows
        Item {
            id: secO
            y: 800
            width: 300; height: 264
            transform: Translate { id: trO; y: 0 }
            Item {
                width: 300; height: 264
                Column { spacing: 8; Repeater { model: 3; PRow { } } }
            }
        }
        // a transform added to the section at run time (no property changes)
        Item {
            id: secL
            y: 1200
            width: 300; height: 264
            Column { spacing: 8; Repeater { model: 3; PRow { } } }
        }
        // the item's own scale (no transform object)
        Item {
            id: secQ
            y: 1600
            width: 300; height: 264
            transformOrigin: Item.Top
            Column { spacing: 8; Repeater { model: 3; PRow { } } }
        }
        // a section bound to its first row's values: the packer's own writes
        // move it (not followed: it must not lay the rows out for ever)
        Item {
            id: secB
            y: 2000
            width: 300; height: 264
            transform: Translate { y: bRow.fx.translateY / 4 }
            Column { spacing: 8; PRow { id: bRow } Repeater { model: 2; PRow { } } }
        }
        property Translate added: Translate { y: 50 }
    }

    // B: a ListView of packed rows, made again for each case
    ListModel { id: lm }
    property ListView lv: null
    Component {
        id: lvComp
        ListView {
            id: view
            width: 384; height: 384
            visible: false
            spacing: 8
            model: lm
            delegate: PRow { height: model.h }
            property real headerH: 0
            header: Item { width: 300; height: view.headerH }
        }
    }

    // D: a horizontal list of packed rows inside a vertical Flickable
    Flickable {
        id: fd
        width: 384; height: 384
        visible: false
        contentHeight: 1200
        ListView {
            id: hl
            y: 150
            width: 384; height: 100
            orientation: ListView.Horizontal
            spacing: 8
            model: 6
            delegate: PRow { width: 200; height: 80 }
        }
        ListItem { y: 300; width: 384; title: "Below" }
    }

    // C: rows made and destroyed at run time
    Flickable {
        id: fc
        width: 384; height: 384
        visible: false
        contentHeight: 3000
        Column { id: colC; spacing: 8 }
    }
    Component { id: rowComp; PRow { } }

    // R: a page title with restAtTop over packed rows (Settings pages)
    Flickable {
        id: fr
        width: 384; height: 384
        visible: false
        contentHeight: colR.height
        Column {
            id: colR
            width: 384
            ListHeader { id: hdr; text: "Connectivity"; restAtTop: true }
            Repeater { model: 10; ListItem { title: "Row " + index } }
        }
    }

    TestCase {
        name: "QvCache"
        when: windowShown

        // every case starts from the same fixtures
        function init() {
            fa.visible = false; ft.visible = false; fd.visible = false; fc.visible = false; fr.visible = false
            trAnim.stop()
            tr.y = 0; trO.y = 0; scS.xScale = 1; scS.yScale = 1; secL.transform = []; secQ.scale = 1
            fr.topMargin = 0; fr.contentY = 0; hdr.restAtTop = true
            if (lv) { lv.visible = false; lv.destroy() }
            lm.clear()
            lv = lvComp.createObject(top)
            wait(20)
        }
        function cleanup() {
            trAnim.stop()
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
            // a height change may fix an out-of-bounds position: put it back
            // (the rows were just worked out again)
            if (f.contentY !== cy)
                f.contentY = cy
        }
        // what the rows should get now, from their geometry (EdgeLayout.layout,
        // the same rules as the packer for plain packed rows): worst difference
        function oracle(f) {
            var all = effects(f), rows = []
            for (var i = 0; i < all.length; i++) {
                var e = all[i], it = e.item
                if (!it || !e.packed || !e.enabled || !it.visible || !(it.height > 0) || !it.parent) continue
                if (!f.contentItem.mapFromItem) continue
                var p = it.parent.mapToItem(f.contentItem, 0, it.y)
                // only rows inside this Flickable's content
                var q = it, inside = false
                while (q) { if (q === f.contentItem) { inside = true; break } q = q.parent }
                if (!inside) continue
                rows.push({ e: e, top: p.y + e.inset, h: it.height - 2 * e.inset, ih: it.height, inset: e.inset })
            }
            rows.sort(function(a, b) { return a.top - b.top })
            // the SCALING spec for every row: a row with edge values of its own
            // (test_06 edgeScale) leaves only the rebuilt comparison
            for (i = 0; i < rows.length; i++) {
                var x = rows[i].e
                if (Math.abs(x.edgeScale - 0.7) > 1e-9 || Math.abs(x.edgeAlpha - 0.5) > 1e-9 || Math.abs(x.edgeContentAlpha - 0.5) > 1e-9)
                    return { worst: 0, info: "(a row with its own edge values: no oracle)", n: rows.length }
            }
            var tops = [], hs = [], gaps = []
            for (i = 0; i < rows.length; i++) {
                tops.push(rows[i].top - f.contentY)
                hs.push(Math.round(rows[i].h))
            }
            for (i = 0; i < rows.length; i++)
                gaps.push(i + 1 < rows.length ? rows[i + 1].top - (rows[i].top + hs[i]) : 0)
            var out = EdgeLayout.layout(EdgeLayout.scaling, tops, hs, gaps, f.height, false)
            var worst = 0, info = ""
            for (i = 0; i < rows.length; i++) {
                var r = rows[i], pl = out[i], s = pl.scale, origin = r.inset, shift = 0
                if (pl.side < 0) { origin = r.ih - r.inset; if (pl.shown) shift = pl.y + s * r.h - (tops[i] + r.h) }
                else if (pl.shown) shift = pl.y - tops[i]
                var d = Math.max(Math.abs(s - r.e.scale), Math.abs(shift - r.e.translateY), Math.abs(origin - r.e.originY))
                if (d > worst) { worst = d; info = "row top " + tops[i].toFixed(1) + " want [" + s.toFixed(3) + "," + shift.toFixed(2) + "," + origin + "] has [" + r.e.scale.toFixed(3) + "," + r.e.translateY.toFixed(2) + "," + r.e.originY + "]" }
            }
            return { worst: worst, info: info, n: rows.length }
        }
        // one scroll step from the kept rows, then the same place rebuilt (was
        // compare(), which hid QtTest's compare); the
        // worst of: kept vs the geometry, rebuilt vs the geometry, kept vs rebuilt
        function probe(f, tag) {
            wait(40)
            f.contentY = f.contentY + 1
            // let a layout the scroll scheduled run (the frame hook or the queued call)
            wait(60)
            var cy = f.contentY
            var list = effects(f)
            var kept = snap(list)
            var o = oracle(f)
            console.log("   oracle (" + o.n + " rows): worst", o.worst.toFixed(3), o.info)
            forced(f)
            wait(60)
            if (f.contentY !== cy) {
                // the view moved itself in the polish after the height change
                console.log("   the view moved after the forced rebuild:", cy, "->", f.contentY, "(put back)")
                f.contentY = cy
                wait(60)
            }
            var o2 = oracle(f)
            var worst = Math.max(o.worst, o2.worst), at = -1
            if (f.contentY === cy) {
                var now = effects(f)
                for (var i = 0; i < list.length; i++) {
                    // pooled or gone since: not drawn
                    if (now.indexOf(list[i]) < 0) continue
                    var fresh = [list[i].scale, list[i].translateY, list[i].originY]
                    for (var j = 0; j < 3; j++) {
                        var d = Math.abs(kept[i][j] - fresh[j])
                        if (d > worst) { worst = d; at = i }
                    }
                }
            } else {
                console.log("   the view keeps moving (" + cy + " -> " + f.contentY + "): the geometry only")
            }
            console.log(tag + ": worst", worst.toFixed(3), "(kept vs geometry", o.worst.toFixed(3),
                        ", rebuilt vs geometry", o2.worst.toFixed(3) + ")", at >= 0 ? "kept vs rebuilt at row " + at : "", o2.info)
            return worst
        }
        // the rows against their geometry now, without a scroll (a change
        // alone must be followed before the next frame)
        function still(f, tag) {
            wait(60)
            var o = oracle(f)
            console.log(tag + " (no scroll): worst", o.worst.toFixed(3), o.info)
            return o.worst
        }

        function test_01_reparentLastRow() {
            fa.visible = true
            fa.contentY = 300
            wait(40)
            probe(fa, "baseline")
            var last = colA.children[7]
            last.parent = sideA
            var w = probe(fa, "reparent the last Column row into another item (same Flickable)")
            last.parent = colA
            verify(w < 0.01, "stale after a reparent: " + w)
        }
        function test_02_setItem() {
            fa.visible = true
            fa.contentY = 1700
            freeFx.item = freeA
            wait(40)
            probe(fa, "free effect on A")
            freeFx.item = freeB
            var w = probe(fa, "EdgeEffect.item changed to another row of the same Flickable")
            verify(w < 0.01, "stale after item changed: " + w)
        }
        function test_03_transformMove() {
            fa.visible = true
            fa.contentY = 1300
            wait(40)
            var w = probe(fa, "transform baseline")
            tr.y = 60
            w = Math.max(w, still(fa, "a section moved by a Translate"))
            w = Math.max(w, probe(fa, "a section moved by a Translate"))
            verify(w < 0.01, "stale after a transform move: " + w)
        }
        // the rows follow the section on every frame of an animation
        function test_03b_transformAnimated() {
            fa.visible = true
            fa.contentY = 1300
            wait(60)
            trAnim.from = 0
            trAnim.to = 150
            trAnim.duration = 400
            trAnim.start()
            var w = 0, n = 0
            while (trAnim.running) {
                wait(30)
                var o = oracle(fa)
                // a sample between the animation tick and the layout it asks for: once more
                if (o.worst >= 0.01) { wait(5); o = oracle(fa) }
                if (o.worst > w) console.log("   at tr.y", tr.y.toFixed(1), "worst", o.worst.toFixed(3), o.info)
                w = Math.max(w, o.worst)
                n++
            }
            w = Math.max(w, still(fa, "after the animation"))
            console.log("animated Translate: " + n + " samples, worst " + w.toFixed(3))
            verify(n >= 4, "samples during the animation: " + n)
            verify(w < 0.01, "stale while a section slides: " + w)
        }
        function test_03c_scaleOnSection() {
            ft.visible = true
            ft.contentY = 300
            wait(40)
            var w = probe(ft, "scale baseline")
            scS.yScale = 0.8
            scS.xScale = 0.8
            w = Math.max(w, still(ft, "a Scale on the section"))
            w = Math.max(w, probe(ft, "a Scale on the section"))
            verify(w < 0.01, "stale after a Scale: " + w)
        }
        function test_03d_transformTwoLevelsUp() {
            ft.visible = true
            ft.contentY = 700
            wait(40)
            var w = probe(ft, "outer section baseline")
            trO.y = -50
            w = Math.max(w, still(ft, "a Translate two levels above the rows"))
            w = Math.max(w, probe(ft, "a Translate two levels above the rows"))
            verify(w < 0.01, "stale after a move two levels up: " + w)
        }
        function test_03e_transformAdded() {
            ft.visible = true
            ft.contentY = 1100
            wait(40)
            var w = probe(ft, "added baseline")
            secL.transform = [ft.added]
            w = Math.max(w, still(ft, "a Translate added to the section"))
            w = Math.max(w, probe(ft, "a Translate added to the section"))
            secL.transform = []
            w = Math.max(w, still(ft, "the Translate taken away"))
            w = Math.max(w, probe(ft, "the Translate taken away"))
            verify(w < 0.01, "stale after a transform was added or taken away: " + w)
        }
        function test_03f_itemScale() {
            ft.visible = true
            ft.contentY = 1500
            wait(40)
            var w = probe(ft, "item scale baseline")
            secQ.scale = 0.9
            w = Math.max(w, still(ft, "the section's own scale"))
            w = Math.max(w, probe(ft, "the section's own scale"))
            verify(w < 0.01, "stale after an item scale: " + w)
        }
        // a section bound to a row's values: laid out a bounded number of times
        function test_03g_boundSection() {
            ft.visible = true
            ft.contentY = 1900
            wait(100)
            var n = 0
            function count() { n++ }
            bRow.fx.valuesChanged.connect(count)
            wait(300)
            var idle = n
            ft.contentY = 1910
            wait(300)
            bRow.fx.valuesChanged.disconnect(count)
            console.log("bound section: values changed", idle, "times at rest,", n - idle, "after one scroll")
            compare(idle, 0, "nothing at rest")
            verify(n - idle <= 2, "one scroll, one layout: " + (n - idle))
        }
        function test_04_listInsertRemoveReset() {
            for (var i = 0; i < 30; i++) lm.append({ h: 80 + (i % 3) * 20 })
            lv.visible = true
            lv.contentY = 600
            wait(60)
            var w = 0
            w = Math.max(w, probe(lv, "list baseline"))
            lm.insert(0, { h: 140 })
            w = Math.max(w, probe(lv, "insert above while scrolled"))
            lm.insert(9, { h: 60 })
            w = Math.max(w, probe(lv, "insert in view"))
            lm.remove(8, 2)
            w = Math.max(w, probe(lv, "remove in view"))
            lm.setProperty(8, "h", 150)
            w = Math.max(w, probe(lv, "resize in view"))
            lm.move(8, 2, 1)
            w = Math.max(w, probe(lv, "move"))
            lm.clear()
            for (var k = 0; k < 25; k++) lm.append({ h: 100 })
            w = Math.max(w, probe(lv, "model reset"))
            lv.positionViewAtIndex(20, ListView.Center)
            w = Math.max(w, probe(lv, "positionViewAtIndex jump"))
            lv.positionViewAtBeginning()
            w = Math.max(w, probe(lv, "jump to the beginning"))
            verify(w < 0.01, "list: " + w)
        }
        function dump(f, tag) {
            var k = f.contentItem.children, out = []
            for (var i = 0; i < k.length; i++) {
                var c = k[i]
                if (c.fx === undefined) continue
                out.push(Math.round(c.y) + "/" + c.height + (c.visible ? "" : "H") + ":" + c.fx.scale.toFixed(3) + "," + c.fx.translateY.toFixed(1) + "," + c.fx.originY)
            }
            console.log(tag, "contentY", f.contentY, "originY", f.originY, "n", out.length, out.join(" "))
        }
        // the drifted origin: the same jumps as test_04, then the geometry
        function test_04b_jump() {
            for (var i = 0; i < 30; i++) lm.append({ h: 80 + (i % 3) * 20 })
            lv.visible = true
            lv.contentY = 600
            wait(60)
            lm.clear()
            for (var k = 0; k < 25; k++) lm.append({ h: 100 })
            wait(60)
            lv.positionViewAtIndex(20, ListView.Center)
            wait(60)
            lv.contentY = 0
            wait(60)
            dump(lv, "after the jumps")
            var w = still(lv, "after the jumps")
            lv.contentY = 1
            w = Math.max(w, still(lv, "scrolled 1"))
            verify(w < 0.01, "jumps: " + w)
        }
        function test_05_reuseItems() {
            for (var i = 0; i < 60; i++) lm.append({ h: 80 + (i % 4) * 15 })
            lv.reuseItems = true
            lv.visible = true
            var w = 0
            for (var cy = 0; cy < 3000; cy += 397) {
                lv.contentY = cy
                w = Math.max(w, probe(lv, "reuse at " + cy))
            }
            // the same, after the origin drifted (model reset while scrolled)
            lm.clear()
            for (i = 0; i < 60; i++) lm.append({ h: 80 + ((i + 1) % 4) * 15 })
            lv.positionViewAtIndex(30, ListView.Center)
            for (cy = 2800; cy > 0; cy -= 397) {
                lv.contentY = cy
                w = Math.max(w, probe(lv, "reuse after a reset at " + cy))
            }
            verify(w < 0.01, "reuse: " + w)
        }
        // r2q's failing order (test_04b, then test_05 / test_09 on the same view):
        // the origin drifts, the view moves itself after the forced rebuild, and
        // the kept rows still match the geometry
        function drift() {
            for (var i = 0; i < 30; i++) lm.append({ h: 80 + (i % 3) * 20 })
            lv.visible = true
            lv.contentY = 600
            wait(60)
            lm.clear()
            for (var k = 0; k < 25; k++) lm.append({ h: 100 })
            wait(60)
            lv.positionViewAtIndex(20, ListView.Center)
            wait(60)
            lv.contentY = 0
            wait(60)
            lv.contentY = 1
            wait(60)
            console.log("drifted: originY", lv.originY, "contentY", lv.contentY)
        }
        function test_05b_reuseAfterDrift() {
            drift()
            lm.clear()
            for (var i = 0; i < 60; i++) lm.append({ h: 80 + (i % 4) * 15 })
            lv.reuseItems = true
            var w = 0
            for (var cy = 0; cy < 3000; cy += 397) {
                lv.contentY = cy
                w = Math.max(w, probe(lv, "reuse after the drift at " + cy))
            }
            verify(w < 0.01, "reuse after the drift: " + w)
        }
        function test_09c_headerAfterDrift() {
            drift()
            lm.clear()
            for (var i = 0; i < 30; i++) lm.append({ h: 90 })
            lv.contentY = 300
            wait(60)
            var w = 0
            lv.headerH = 120
            w = Math.max(w, still(lv, "header grows after the drift"))
            w = Math.max(w, probe(lv, "header grows after the drift"))
            lv.topMargin = 40
            w = Math.max(w, still(lv, "top margin after the drift"))
            w = Math.max(w, probe(lv, "top margin after the drift"))
            verify(w < 0.01, "margins/header after the drift: " + w)
        }
        function test_06_toggles() {
            fa.visible = true
            fa.contentY = 300
            wait(40)
            var r3 = colA.children[3]
            var w = 0
            r3.fx.packed = false
            w = Math.max(w, probe(fa, "packed off"))
            r3.fx.packed = true
            w = Math.max(w, probe(fa, "packed on"))
            r3.fx.enabled = false
            w = Math.max(w, probe(fa, "enabled off"))
            r3.fx.enabled = true
            r3.visible = false
            w = Math.max(w, probe(fa, "row hidden"))
            r3.visible = true
            colA.visible = false
            colA.visible = true
            w = Math.max(w, probe(fa, "column hidden and shown"))
            r3.fx.inset = 6
            w = Math.max(w, probe(fa, "inset"))
            r3.fx.edgeScale = 0.5
            w = Math.max(w, probe(fa, "edgeScale"))
            r3.height = 130
            w = Math.max(w, probe(fa, "row height"))
            fa.height = 300
            w = Math.max(w, probe(fa, "viewport height"))
            fa.height = 384
            r3.fx.inset = 0
            r3.fx.edgeScale = 0.7
            r3.height = 80
            verify(w < 0.01, "toggles: " + w)
        }
        function test_09_marginsAndHeader() {
            for (var i = 0; i < 30; i++) lm.append({ h: 90 })
            lv.visible = true
            lv.contentY = 300
            wait(60)
            var w = 0
            lv.headerH = 120
            w = Math.max(w, still(lv, "header grows"))
            w = Math.max(w, probe(lv, "header grows"))
            lv.topMargin = 40
            w = Math.max(w, still(lv, "top margin"))
            w = Math.max(w, probe(lv, "top margin"))
            lv.bottomMargin = 60
            w = Math.max(w, still(lv, "bottom margin"))
            w = Math.max(w, probe(lv, "bottom margin"))
            lv.headerH = 0
            lv.topMargin = 0
            w = Math.max(w, still(lv, "header and margin back"))
            w = Math.max(w, probe(lv, "header and margin back"))
            // at the top: the header pushes the rows down
            lv.positionViewAtBeginning()
            wait(60)
            lv.headerH = 150
            w = Math.max(w, still(lv, "header grows at the top"))
            w = Math.max(w, probe(lv, "header grows at the top"))
            lv.topMargin = 30
            w = Math.max(w, still(lv, "top margin at the top"))
            w = Math.max(w, probe(lv, "top margin at the top"))
            verify(w < 0.01, "margins/header: " + w)
        }
        // restAtTop reads contentY - originY + topMargin: a margin change at
        // a fixed contentY moves the title through its 16 px ramp
        function test_09b_restAtTopMargin() {
            fr.visible = true
            fr.contentY = 8
            hdr.restAtTop = false
            wait(100)
            var pa = hdr.label.opacity, ps = hdr.transform[0].yScale, pt = hdr.transform[1].y
            verify(pa < 0.99 && ps < 0.99, "the title is in the edge area at 8 px: " + pa + " / " + ps)
            hdr.restAtTop = true
            wait(100)
            near(hdr.label.opacity, 1 - 0.5 * (1 - pa), 0.002, "8 px: half the effect")
            fr.topMargin = 4
            wait(60)
            compare(fr.contentY, 8, "the content stays where it is")
            near(hdr.label.opacity, 1 - 0.75 * (1 - pa), 0.002, "8 px + 4 px margin: three quarters of the alpha")
            near(hdr.transform[0].yScale, 1 - 0.75 * (1 - ps), 0.002, "three quarters of the scale")
            near(hdr.transform[1].y, 0.75 * pt, 0.05, "three quarters of the shift")
            fr.topMargin = 0
            wait(60)
            near(hdr.label.opacity, 1 - 0.5 * (1 - pa), 0.002, "the margin back: half again")
        }
        function near(a, b, tol, msg) {
            verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
        }
        function test_08_horizontalList() {
            fd.visible = true
            wait(60)
            var out = []
            for (var i = 0; i < hl.contentItem.children.length; i++) {
                var c = hl.contentItem.children[i]
                if (c.fx !== undefined) out.push("x" + Math.round(c.x) + " y" + c.y + ":" + c.fx.scale.toFixed(3) + "," + c.fx.translateY.toFixed(1) + "," + c.fx.originY + " fl " + (c.fx.flickable === hl))
            }
            console.log("horizontal list rows:", out.join(" | "))
            fd.contentY = 120
            wait(60)
            out = []
            for (i = 0; i < hl.contentItem.children.length; i++) {
                c = hl.contentItem.children[i]
                if (c.fx !== undefined) out.push(c.fx.scale.toFixed(3) + "," + c.fx.translateY.toFixed(1))
            }
            console.log("after the outer scroll to 120:", out.join(" | "))
        }
        function test_07_destroyWhileScrolling() {
            fc.visible = true
            var rows = []
            for (var i = 0; i < 20; i++) rows.push(rowComp.createObject(colC))
            fc.contentY = 200
            wait(40)
            // destroy and scroll in the same turn of the event loop, many times
            for (var k = 0; k < 10; k++) {
                rows[k].destroy()
                fc.contentY = fc.contentY + 7
            }
            for (k = 10; k < 15; k++) {
                rows[k].parent = null
                fc.contentY = fc.contentY - 3
            }
            wait(50)
            for (var n = 0; n < 40; n++) fc.contentY = 100 + n * 13
            var w = probe(fc, "after destroying rows while scrolling")
            for (k = 10; k < 20; k++) rows[k].destroy()
            wait(30)
            fc.contentY = 50
            fc.contentY = 60
            verify(w < 0.01, "destroy: " + w)
        }
    }
}
