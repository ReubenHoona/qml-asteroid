// WO-61-Q4 N61-11 and N61-12: the stock Wear OS 6 confirmation dialog
// (emulator S25, System > Restart: two 104 px circles at y 257-360, x 76-179
// and 204-307, title cap top 103, text cap top 164, #E8E7EE text, #2F3036
// dismiss with a 30 x 30 px X, #DBE2F9 confirm with a 36 x 26 px check) and
// the dialog motion (M15 measured at 1x and 10x: show = alpha 0 -> 1 and the
// content +10 % -> 0 of the height on standard (0.2, 0, 0, 1) in 200 ms; hide
// = alpha 1 -> 0 and the content 0 -> -5 % on standardAccelerate (0.3, 0, 1,
// 1) in 150 ms; the screen under it cross-fades and is never scaled).
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
    // the screen under the dialogs: a stand-in for the Settings System list
    Item {
        id: page
        anchors.fill: parent
        Repeater {
            model: 3
            Rectangle {
                x: 20; y: 24 + index * 112; width: 344; height: 104
                radius: 52
                color: "#2F3036"
            }
        }
    }
    Item {
        id: host
        anchors.fill: parent
    }

    TestCase {
        id: tc
        name: "Q4dialog"
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
        function scene(item) { return item.mapToItem(top, 0, 0) }
        function cleanup() {
            mouseRelease(top, 1, 1)
            page.scale = 1
            page.opacity = 1
            for (var i = host.children.length - 1; i >= 0; i--)
                host.children[i].destroy()
            wait(0)
        }
        function make(src) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; ' + src, host)
        }
        function openSettled(d) {
            d.open()
            tryVerify(function() { return d.alpha === 1 && d.contentOffset === 0 }, 3000, "open settled")
        }
        // a cubic bezier easing (x1, y1, x2, y2) at progress x
        function bez(c, x) {
            if (x <= 0) return 0
            if (x >= 1) return 1
            var lo = 0, hi = 1
            for (var i = 0; i < 60; i++) {
                var m = (lo + hi) / 2
                var bx = 3 * (1 - m) * (1 - m) * m * c[0] + 3 * (1 - m) * m * m * c[2] + m * m * m
                if (bx < x) lo = m; else hi = m
            }
            var t = (lo + hi) / 2
            return 3 * (1 - t) * (1 - t) * t * c[1] + 3 * (1 - t) * t * t * c[3] + t * t * t
        }
        // ink extents of the pixels that pass f inside a box
        function ink(img, x0, y0, x1, y1, f) {
            var r = { x0: 999, y0: 999, x1: -1, y1: -1 }
            for (var y = y0; y <= y1; y++)
                for (var x = x0; x <= x1; x++)
                    if (f(img.pixel(x, y))) {
                        r.x0 = Math.min(r.x0, x); r.x1 = Math.max(r.x1, x)
                        r.y0 = Math.min(r.y0, y); r.y1 = Math.max(r.y1, y)
                    }
            return r
        }
        readonly property string restart: 'AlertDialog { anchors.fill: parent; title: "Restart"; text: "Are you sure?" }'

        // ---- N61-11: the two-button layout ----
        function test_01_twoButtonGeometry() {
            var d = make(restart)
            verify(d.twoButtons, "confirmDismiss is the two-button style")
            openSettled(d)
            verify(!d.scrolling, "fits")
            compare(d.topPadding, 47, "top 12.48 %")
            compare(d.bottomPadding, 23, "bottom 6.24 %")
            var dm = d.dismissButton, cf = d.confirmButton
            verify(dm.visible && cf.visible && !d.infoButton.visible && !d.edgeButton.visible, "two round buttons only")
            compare(dm.width, 104); compare(dm.height, 104); compare(cf.width, 104); compare(cf.height, 104)
            var pd = scene(dm), pc = scene(cf)
            near(pd.x, 76, 0.01, "dismiss x 76-179")
            near(pc.x, 204, 0.01, "confirm x 204-307")
            near(pd.y, 257, 0.01, "dismiss y 257-360")
            near(pc.y, 257, 0.01, "confirm y 257-360")
            near(pc.x - (pd.x + 104), 24, 0.01, "24 px apart")
            near((pd.x + pc.x + 104) / 2, 192, 0.01, "the pair centred")
            near(384 - (pd.y + 104), 23, 0.01, "23 px above the bottom, as the info style")
            compare(dm.children[0].radius, 52, "dismiss a circle")
            compare(cf.children[0].radius, 52, "confirm a circle")
            compare(dm.children[0].rotation, 0); compare(cf.children[0].rotation, 0)
            sameColor(dm.children[0].color, "#2F3036", "dismiss surfaceContainer")
            sameColor(cf.children[0].color, "#DBE2F9", "confirm primary")
            compare(dm.children[1].glyph, "close"); compare(cf.children[1].glyph, "check")
            compare(dm.children[1].width, 48, "24 dp X"); compare(cf.children[1].width, 48, "24 dp check")
            sameColor(dm.children[1].color, "#E8E7EE", "X onSurface")
            sameColor(cf.children[1].color, "#383F51", "check onPrimary")
            // the texts
            var t = d.titleLabel, x = d.textLabel
            compare(t.role, "titleMedium", "title titleMedium by default")
            compare(t.font.pixelSize, 32)
            compare(x.font.pixelSize, 28, "text bodyMedium")
            sameColor(t.color, "#E8E7EE", "title onSurface")
            sameColor(x.color, "#E8E7EE", "text onSurface")
            compare(t.horizontalAlignment, Text.AlignHCenter); compare(x.horizontalAlignment, Text.AlignHCenter)
            near(scene(t).x, 52, 0.01, "title box x 52-332"); near(t.width, 280, 0.01, "title width")
            near(scene(x).x, 36, 0.05, "text box x 36-348"); near(x.width, 312, 0.1, "text width")
            var tm = Qt.createQmlObject('import QtQuick; FontMetrics { }', d); tm.font = t.font
            var xm = Qt.createQmlObject('import QtQuick; FontMetrics { }', d); xm.font = x.font
            var tb = scene(t).y + t.topPadding + tm.ascent, xb = scene(x).y + x.topPadding + xm.ascent
            console.log("Q4 dbg: title y", scene(t).y, "h", t.height, "pad", t.topPadding, t.bottomPadding, "asc", tm.ascent, "desc", tm.descent, "lines", t.lineCount, "contentH", t.contentHeight,
                        "| text y", scene(x).y, "h", x.height, "pad", x.topPadding, x.bottomPadding, "asc", xm.ascent, "desc", xm.descent, "contentH", x.contentHeight,
                        "| natural", d.naturalHeight, "free", d._freeHalf, "top", d.topPadding)
            near(tb, 126, 0.01, "title baseline y 126 (S25)")
            near(xb, 184, 0.01, "text baseline y 184 (S25)")
            console.log("Q4 two-button: title cap top", (tb - tm.capitalHeight).toFixed(2), "(S25 103), text cap top",
                        (xb - xm.capitalHeight).toFixed(2), "(S25 164)")
            near(tb - tm.capitalHeight, 103, 1, "title cap top 103")
            near(xb - xm.capitalHeight, 164, 1, "text cap top 164")
            compare(dm.Accessible.name, "Dismiss"); compare(cf.Accessible.name, "Confirm")
            compare(dm.Accessible.role, Accessible.Button); compare(cf.Accessible.role, Accessible.Button)
            verify(!d.holdingDisplay, "alert dialogs never hold the display")
        }

        // rendered: the pixels against S25
        function test_02_twoButtonPixels() {
            var d = make(restart)
            openSettled(d)
            waitForRendering(d)
            var img = grabImage(top)
            img.save("shots/two-button.png")
            pixelNear(img, 88, 308, "#2F3036", 3, "dismiss #2F3036")
            pixelNear(img, 216, 308, "#DBE2F9", 3, "confirm #DBE2F9")
            pixelNear(img, 192, 308, "#000000", 1, "black between")
            pixelNear(img, 60, 308, "#000000", 1, "black outside")
            var row = ink(img, 0, 308, 383, 308, function(p) { return Math.abs(p.r * 255 - 0x2F) <= 3 && Math.abs(p.b * 255 - 0x36) <= 3 })
            near(row.x0, 76, 1, "dismiss from x 76"); near(row.x1, 179, 1, "dismiss to x 179")
            row = ink(img, 0, 308, 383, 308, function(p) { return Math.abs(p.r * 255 - 0xDB) <= 3 && Math.abs(p.b * 255 - 0xF9) <= 3 })
            near(row.x0, 204, 1, "confirm from x 204"); near(row.x1, 307, 1, "confirm to x 307")
            var vcol = ink(img, 100, 230, 100, 383, function(p) { return Math.abs(p.r * 255 - 0x2F) <= 3 && Math.abs(p.b * 255 - 0x36) <= 3 })
            near(vcol.y0, 257 + 52 - Math.sqrt(52 * 52 - 27.5 * 27.5), 1.5, "dismiss circle top at x 100")
            vcol = ink(img, 256, 230, 256, 383, function(p) { return Math.abs(p.r * 255 - 0xDB) <= 3 && Math.abs(p.b * 255 - 0xF9) <= 3 })
            verify(vcol.y0 >= 256 && vcol.y0 <= 258, "confirm from y 257: " + vcol.y0)
            verify(vcol.y1 >= 359 && vcol.y1 <= 361, "confirm to y 360: " + vcol.y1)
            // glyph ink (anti-aliased edges included), as measured on S25
            var X = ink(img, 80, 262, 175, 356, function(p) { return p.r * 255 > 60 })
            var C = { x0: 999, y0: 999, x1: -1, y1: -1 }
            for (var yy = 264; yy <= 353; yy++)
                for (var xx = 211; xx <= 300; xx++)
                    if ((xx - 255.5) * (xx - 255.5) + (yy - 308.5) * (yy - 308.5) < 45 * 45 && img.pixel(xx, yy).b * 255 < 235) {
                        C.x0 = Math.min(C.x0, xx); C.x1 = Math.max(C.x1, xx)
                        C.y0 = Math.min(C.y0, yy); C.y1 = Math.max(C.y1, yy)
                    }
            console.log("Q4 glyphs: X", X.x1 - X.x0 + 1, "x", X.y1 - X.y0 + 1, "(S25 30 x 30), check",
                        C.x1 - C.x0 + 1, "x", C.y1 - C.y0 + 1, "(S25 36 x 26)")
            near(X.x1 - X.x0 + 1, 30, 3, "X width"); near(X.y1 - X.y0 + 1, 30, 3, "X height")
            near(C.x1 - C.x0 + 1, 36, 3, "check width"); near(C.y1 - C.y0 + 1, 26, 3, "check height")
            near((X.x0 + X.x1) / 2, 127.5, 1, "X centred in its circle")
            near((C.x0 + C.x1) / 2, 255.5, 2, "check centred in its circle")
            // the cap tops: the first rows of ink in the title and text bands
            var T = ink(img, 52, 80, 332, 140, function(p) { return p.r * 255 > 116 })
            var M = ink(img, 36, 150, 348, 200, function(p) { return p.r * 255 > 116 })
            console.log("Q4 ink: title rows", T.y0, "-", T.y1, "x", T.x0, "-", T.x1, "(S25 103-126, 139-248); text rows",
                        M.y0, "-", M.y1, "x", M.x0, "-", M.x1, "(S25 164-189, 101-282)")
            near(T.y0, 103, 2, "title cap top 103 +- 2")
            near(M.y0, 164, 2, "text cap top 164 +- 2")
            near((T.x0 + T.x1) / 2, 192, 3, "title centred"); near((M.x0 + M.x1) / 2, 192, 3, "text centred")
        }

        // Settings today (titleLarge) and after S1 (titleMedium): same chain
        function test_03_titleRole() {
            var d = make(restart)
            d.titleRole = "titleLarge"
            openSettled(d)
            compare(d.titleLabel.font.pixelSize, 36, "titleLarge 36 px")
            var tm = Qt.createQmlObject('import QtQuick; FontMetrics { }', d); tm.font = d.titleLabel.font
            var b = scene(d.titleLabel).y + d.titleLabel.topPadding + tm.ascent
            console.log("Q4 titleLarge: first baseline", b.toFixed(2), "cap top", (b - tm.capitalHeight).toFixed(2))
            near(b, 126, 1.5, "first baseline about 126")
            near(scene(d.dismissButton).y, 257, 0.01, "buttons stay at the bottom")
            verify(!d.scrolling)
            d.titleRole = "titleMedium"
            compare(d.titleLabel.font.pixelSize, 32, "S1: titleMedium 32 px")
        }

        function test_04_actions() {
            var d = make(restart)
            var conf = 0, dism = 0, req = 0
            d.confirmed.connect(function() { conf++ })
            d.dismissed.connect(function() { dism++ })
            d.dismissRequested.connect(function() { req++ })
            openSettled(d)
            mouseClick(d.confirmButton, 52, 52)
            compare(conf, 1, "the check confirms")
            tryVerify(function() { return !d.active }, 3000, "and closes")
            openSettled(d)
            mouseClick(d.dismissButton, 52, 52)
            compare(dism, 1, "the X dismisses")
            tryVerify(function() { return !d.active }, 3000, "and closes")
            // a tap between the buttons does nothing
            openSettled(d)
            mouseClick(top, 192, 308)
            compare(conf + dism, 2, "nothing between the buttons")
            verify(d.shown)
            // swipe right dismisses (B7), the screen under it at its own size
            mousePress(d, 60, 192)
            for (var x = 70; x <= 300; x += 10) {
                mouseMove(d, x, 192)
                wait(16)
                compare(page.scale, 1, "the screen under it is not scaled during the swipe")
            }
            mouseRelease(d, 300, 192)
            tryVerify(function() { return req === 1 && dism === 2 }, 2000, "swiped away: dismissRequested, dismissed")
            tryVerify(function() { return !d.active }, 3000, "and closed")
            // the accessibility actions
            openSettled(d)
            d.confirmButton.Accessible.pressAction()
            compare(conf, 2, "Confirm action")
            tryVerify(function() { return !d.active }, 3000)
        }

        function test_05_longContent() {
            var d = make(restart)
            d.text = "Wi-Fi uses more battery while it looks for networks. ".repeat(12)
            openSettled(d)
            verify(d.scrolling, "long text scrolls")
            verify(d.flickable.interactive)
            compare(d.bottomPadding, 79, "20.83 % while it scrolls")
            compare(d.flickable.contentY, -d.flickable.topMargin, "starts at the top")
            near(d.flickable.topMargin, 47, 0.01, "top padding 47")
            // the buttons follow the text and its 16 dp bottom margin
            var textRow = d.textLabel.parent.parent, roundRow = d.confirmButton.parent.parent
            verify(roundRow.y > textRow.y + textRow.height, "buttons under the text")
            var gap = roundRow.y - (textRow.y + textRow.height)
            verify(gap > 1 && gap <= 32.01, "the 16 dp margin (edge-scaled) between: " + gap)
            d.flickable.contentY = d.flickable.contentHeight - 384 + d.flickable.bottomMargin
            wait(50)
            var p = scene(d.confirmButton)
            verify(p.y < 384 - 79, "scrolled to the end: the buttons above the bottom padding: " + p.y)
        }

        function test_06_iconAndRows() {
            var d = make('AlertDialog { anchors.fill: parent; title: "Bedtime mode"; text: "Turn it on?"; iconName: "ios-moon" }')
            openSettled(d)
            compare(d.topPadding, 39, "10.4 % with an icon")
            verify(!d.scrolling, "an icon, a title and a text still fit")
            near(scene(d.confirmButton).y, 257, 0.01, "buttons at the bottom")
            var ip = scene(d.titleLabel).y
            verify(ip >= 39 + 64, "the title under the icon: " + ip)
            var r = make('AlertDialog { anchors.fill: parent; title: "Bedtime"; text: "Turn it on?"; CheckboxButton { width: parent ? parent.width : 300; text: "Do not ask again" } }')
            openSettled(r)
            var tr = scene(r.textLabel), b = scene(r.confirmButton)
            verify(b.y > tr.y + r.textLabel.height, "buttons under the text and the row")
        }

        // ---- N61-12: the motion ----
        function test_10_motionNumbers() {
            var d = make('Dialog { behind: page }')
            compare(d.enterRise, 0.10, "+10 % of the height")
            compare(d.exitRise, -0.05, "-5 % of the height")
            compare(d.enterDuration, 200)
            compare(d.exitDuration, 150)
            compare(d.contentScale, 1, "no zoom")
            var e = d._enterAnimation.animations, x = d._exitAnimation.animations
            compare(e.length, 2); compare(x.length, 2)
            for (var i = 0; i < 2; i++) {
                compare(e[i].duration, 200 * Motion.animationScale)
                compare(x[i].duration, 150 * Motion.animationScale)
                compare(e[i].easing.type, Easing.BezierSpline)
                compare(x[i].easing.type, Easing.BezierSpline)
                for (var k = 0; k < 6; k++) {
                    near(e[i].easing.bezierCurve[k], Motion.easing.standard[k], 1e-9, "show easing " + k)
                    near(x[i].easing.bezierCurve[k], Motion.easing.standardAccelerate[k], 1e-9, "hide easing " + k)
                }
            }
        }

        Component { id: acC; AnimationController { } }

        // the show sampled at fixed times (an AnimationController drives the
        // dialog's own animation) against the model and the stock frames
        function test_11_showCurve() {
            var d = make('Dialog { behind: page; Rectangle { anchors.centerIn: parent; width: 104; height: 104; radius: 52; color: "#DBE2F9" } }')
            d._a = 0
            d._rise = d.enterRise * 384
            var ac = acC.createObject(d, { animation: d._enterAnimation })
            ac.reload()
            // stock M15 at 10x (cross-fade fit, ms from the start): alpha, offset px
            var stock = [[20.3, 0.18, 32], [40.5, 0.48, 20], [61.7, 0.69, 12], [81.6, 0.81, 8], [101.1, 0.89, 5],
                         [121.8, 0.93, 3], [148.6, 0.97, 2], [174.8, 0.98, 1]]
            var log = []
            var at = function(ms) {
                ac.progress = ms / 200
                return [d.alpha, d.contentOffset]
            }
            var s0 = at(0)
            near(s0[0], 0, 1e-6, "alpha 0 at 0 ms"); near(s0[1], 38.4, 1e-6, "+38.4 px at 0 ms")
            for (var i = 0; i < stock.length; i++) {
                var s = at(stock[i][0]), m = bez(Motion.easing.standard, stock[i][0] / 200)
                near(s[0], m, 0.01, "alpha on standard at " + stock[i][0])
                near(s[1], 38.4 * (1 - m), 0.4, "offset on standard at " + stock[i][0])
                near(s[0], stock[i][1], 0.07, "alpha as stock at " + stock[i][0] + " ms")
                near(s[1], stock[i][2], 4, "offset as stock at " + stock[i][0] + " ms")
                log.push(stock[i][0] + " ms: a " + s[0].toFixed(2) + " (" + stock[i][1] + ") y " + s[1].toFixed(1) + " (" + stock[i][2] + ")")
            }
            var plan = [[0, 38.4], [75, 0], [150, 0], [200, 0]]
            for (i = 0; i < plan.length; i++) {
                s = at(plan[i][0])
                log.push("t " + plan[i][0] + ": y " + s[1].toFixed(2) + " a " + s[0].toFixed(3))
            }
            console.log("Q4 show:", log.join("; "))
            s = at(200)
            compare(s[0], 1, "alpha 1 at 200 ms"); compare(s[1], 0, "at rest at 200 ms")
            compare(page.scale, 1, "the screen under it keeps its size")
            compare(page.opacity, 1, "and its own opacity (it shows through the fading dialog)")
            ac.destroy()
        }

        function test_12_hideCurve() {
            var d = make('Dialog { behind: page }')
            d._a = 1
            d._rise = 0
            var ac = acC.createObject(d, { animation: d._exitAnimation })
            ac.reload()
            // stock M15 at 10x (ms from the start of the fade): alpha, offset px
            var stock = [[16.8, 0.97, -1], [41.5, 0.85, -3], [66.5, 0.71, -6], [91.3, 0.49, -10],
                         [116.2, 0.28, -14], [141.3, 0.05, -19]]
            var log = []
            for (var i = 0; i < stock.length; i++) {
                ac.progress = stock[i][0] / 150
                var m = bez(Motion.easing.standardAccelerate, stock[i][0] / 150)
                near(d.alpha, 1 - m, 0.01, "alpha on standardAccelerate at " + stock[i][0])
                near(d.contentOffset, -19.2 * m, 0.2, "offset on standardAccelerate at " + stock[i][0])
                near(d.alpha, stock[i][1], 0.07, "alpha as stock at " + stock[i][0] + " ms")
                near(d.contentOffset, stock[i][2], 3, "offset as stock at " + stock[i][0] + " ms")
                log.push(stock[i][0] + " ms: a " + d.alpha.toFixed(2) + " (" + stock[i][1] + ") y " + d.contentOffset.toFixed(1) + " (" + stock[i][2] + ")")
            }
            console.log("Q4 hide:", log.join("; "))
            ac.progress = 1
            compare(d.alpha, 0); near(d.contentOffset, -19.2, 1e-6, "-5 % at the end")
            ac.destroy()
        }

        // real time: the dialog opens and closes on its own clock, the screen
        // under it never moves
        function test_13_liveOpenClose() {
            var d = make('Dialog { behind: page; Rectangle { anchors.centerIn: parent; width: 104; height: 104; color: "red" } }')
            var closed = 0
            d.closed.connect(function() { closed++ })
            var t0 = Date.now(), last = 1e9, samples = 0
            d.open()
            verify(d.visible && d.shown)
            verify(d.contentOffset > 0 && d.contentOffset <= 38.41, "starts low: " + d.contentOffset)
            verify(d.alpha < 0.5, "starts transparent: " + d.alpha)
            while (!(d.alpha === 1 && d.contentOffset === 0) && Date.now() - t0 < 3000) {
                verify(d.contentOffset <= last + 1e-9, "rises monotonically")
                last = d.contentOffset
                compare(d.contentScale, 1); compare(page.scale, 1); compare(page.opacity, 1)
                samples++
                wait(10)
            }
            var openMs = Date.now() - t0
            verify(d.alpha === 1 && d.contentOffset === 0, "settled")
            console.log("Q4 live show: settled after", openMs, "ms,", samples, "samples")
            d.close()
            last = 0
            t0 = Date.now()
            while (d.active && Date.now() - t0 < 3000) {
                verify(d.contentOffset <= last + 1e-9, "goes on up while it fades")
                last = d.contentOffset
                compare(page.scale, 1)
                wait(10)
            }
            verify(!d.visible, "hidden after the hide")
            compare(closed, 1, "closed() once")
            near(d.contentOffset, -19.2, 0.01, "ends 19.2 px higher")
            console.log("Q4 live hide: done after", Date.now() - t0, "ms")
        }

        // opened again while it fades out: it comes back from where it is
        function test_14_reopenWhileHiding() {
            var d = make('Dialog { behind: page }')
            var closed = 0
            d.closed.connect(function() { closed++ })
            openSettled(d)
            d.close()
            // half way through the hide (set by hand: the clock under qemu jumps)
            d._exitAnimation.stop()
            d._a = 0.4
            d._rise = -5
            verify(d.active, "still on screen while it fades")
            d.open()
            near(d.alpha, 0.4, 1e-9, "opened again: no snap back to 0")
            near(d.contentOffset, -5, 1e-9, "and no jump down to +10 %")
            tryVerify(function() { return d.alpha === 1 && d.contentOffset === 0 }, 3000, "back at rest")
            compare(closed, 0, "never closed")
            d.close()
            tryVerify(function() { return !d.active }, 3000)
            compare(closed, 1)
            // from hidden it starts again at +10 %
            d.open()
            verify(d.contentOffset > 30 || d.alpha === 1, "a fresh show starts low: " + d.contentOffset)
            tryVerify(function() { return d.alpha === 1 }, 3000)
        }

        // Reduce animations: Motion.duration() is 0; the same zero-length
        // animations land at once and the hide still ends with closed()
        function test_16_zeroDuration() {
            var d = make('Dialog { behind: page }')
            var closed = 0
            d.closed.connect(function() { closed++ })
            for (var i = 0; i < 2; i++) {
                d._enterAnimation.animations[i].duration = 0
                d._exitAnimation.animations[i].duration = 0
            }
            d.open()
            tryVerify(function() { return d.alpha === 1 && d.contentOffset === 0 }, 500, "shown at once")
            d.close()
            tryVerify(function() { return closed === 1 && !d.visible }, 500, "hidden at once, closed() sent")
            near(d.contentOffset, -19.2, 1e-6, "at the end of the hide")
        }

        // the frames for the comparison with M15 (saved, viewed by hand)
        function test_15_frames() {
            var d = make(restart)
            d.behind = page
            var ac = acC.createObject(d, { animation: d._enterAnimation })
            d._a = 0
            d._rise = 38.4
            ac.reload()
            var times = [0, 25, 50, 75, 100, 150, 200]
            for (var i = 0; i < times.length; i++) {
                ac.progress = times[i] / 200
                d._shown = true
                waitForRendering(d)
                grabImage(top).save("shots/show-" + times[i] + ".png")
            }
            ac.destroy()
            d._a = 1
            d._rise = 0
            var ac2 = acC.createObject(d, { animation: d._exitAnimation })
            ac2.reload()
            times = [0, 25, 50, 75, 100, 125, 150]
            for (i = 0; i < times.length; i++) {
                ac2.progress = times[i] / 150
                verify(d.visible, "on screen while it fades")
                waitForRendering(d)
                grabImage(top).save("shots/hide-" + times[i] + ".png")
            }
            ac2.destroy()
        }
    }
}
