import QtQuick
import QtTest
import org.asteroid.controls
import org.asteroid.utils

// WO-09 (image 60 defect list): D60-37 title face weight, D60-34 round page
// clip of LayerStack frames while they move, D60-41 AlertDialog info style.
// WO-61-Q4 copy: test_41_m3Unchanged now expects the Wear OS 6 two-button
// confirmation (N61-11) next to the info style.
// 384 x 384, 2 px per dp, the image 59 rootfs fonts (Noto Sans static faces).
TestCase {
    id: tc
    name: "WO09"
    when: windowShown
    visible: true
    width: 384
    height: 384

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }

    // ---- D60-37: titleMedium / titleSmall ask Noto Sans for Medium ----
    Component { id: titleC; Label { text: "Connectivity"; role: "titleMedium" } }
    Component { id: subC; Label { text: "Connectivity"; role: "titleSmall" } }
    Component { id: semiC; Label { text: "Connectivity"; role: "titleMedium"; Component.onCompleted: font.weight = 550 } }
    Component { id: headerC; ListHeader { width: 384; text: "Connectivity" } }

    function test_37_titleFace() {
        compare(Theme.type.titleMedium.weight, 500, "titleMedium asks for 500")
        compare(Theme.type.titleSmall.weight, 500, "titleSmall asks for 500")
        compare(Theme.type.titleMedium.axes.wght, 550, "CP3A weight kept for a variable font")
        compare(Theme.type.titleSmall.axes.wght, 550, "CP3A weight kept for a variable font")
        compare(Theme.type.numeralExtraLarge.weight, 550, "other 550 roles unchanged")
        compare(Theme.type.arcSmall.weight, 550, "other 550 roles unchanged")
        compare(Theme.type.titleLarge.weight, 500, "titleLarge unchanged")

        var t = createTemporaryObject(titleC, tc)
        compare(t.font.weight, 500)
        compare(t.fontInfo.styleName, "Medium", "Noto Sans Medium face")
        compare(t.fontInfo.weight, 500)
        var s = createTemporaryObject(subC, tc)
        compare(s.fontInfo.styleName, "Medium", "titleSmall: Noto Sans Medium face")
        // what 550 gave: Qt matches it upwards to the SemiBold face
        var b = createTemporaryObject(semiC, tc)
        compare(b.fontInfo.styleName, "SemiBold", "550 resolves to SemiBold")
        console.log("Connectivity titleMedium:", t.contentWidth.toFixed(1), "px (Medium), was",
                    b.contentWidth.toFixed(1), "px (SemiBold); stock 182")
        near(t.contentWidth, 194.3, 1.0, "Medium: Connectivity advance width")
        near(b.contentWidth, 199.6, 1.0, "SemiBold: Connectivity advance width")
        verify(t.contentWidth < b.contentWidth - 4, "narrower than before")

        var h = createTemporaryObject(headerC, tc)
        compare(h.label.fontInfo.styleName, "Medium", "ListHeader title in Medium")
    }

    // ---- D60-34: LayerStack frames are circles while they move ----
    Item {
        id: stackHost
        width: 384; height: 384
        Component {
            id: pageA
            Item { property int depth; property var pop; Rectangle { anchors.fill: parent; color: "red" } }
        }
        Component {
            id: pageB
            Item { property int depth; property var pop; Rectangle { anchors.fill: parent; color: "green" } }
        }
        LayerStack {
            id: stack
            win: null
            firstPage: pageA
        }
    }
    // the effect items a frame's layer puts next to it (siblings in the back swipe area)
    function effects() {
        var out = []
        var area = stack._frames[0].parent
        for (var i = 0; i < area.children.length; i++)
            if (area.children[i].maskEnabled !== undefined)
                out.push(area.children[i])
        return out
    }
    function frameBackground(f) {
        for (var i = 0; i < f.children.length; i++)
            if (f.children[i].color !== undefined && f.children[i].radius !== undefined)
                return f.children[i]
        return null
    }
    function checkMoving(what) {
        var top = stack._frames[stack._frames.length - 1]
        var below = stack._frames[stack._frames.length - 2]
        verify(top.layer.enabled, what + ": top page drawn through the round mask")
        verify(below.layer.enabled, what + ": page below drawn through the round mask")
        verify(top.layer.smooth, what + ": layer sampled smoothly while scaled")
        var fx = effects()
        compare(fx.length, 2, what + ": one mask effect per moving page")
        for (var i = 0; i < fx.length; i++) {
            verify(fx[i].maskEnabled, what + ": mask on")
            near(fx[i].maskThresholdMin, 0.5, 0.0001, what + ": mask threshold")
            near(fx[i].maskSpreadAtMin, 1.0, 0.0001, what + ": mask spread (anti-aliased arc)")
            var r = fx[i].maskSource.sourceItem
            compare(r.width, 384, what + ": mask width")
            compare(r.height, 384, what + ": mask height")
            compare(r.radius, 192, what + ": mask is the screen circle")
            verify(r.antialiasing, what + ": mask edge anti-aliased")
            verify(fx[i].maskSource.hideSource, what + ": mask shape itself not drawn")
        }
    }
    function checkRest(what) {
        for (var i = 0; i < stack._frames.length; i++)
            verify(!stack._frames[i].layer.enabled, what + ": no layer at rest (frame " + i + ")")
        compare(effects().length, 0, what + ": no mask effect at rest")
    }

    function test_34_roundPages() {
        verify(DeviceSpecs.hasRoundScreen, "machine.conf: round screen")
        stack._finishPush()
        while (stack.layers.length > 0)
            stack.pop(stack.currentLayer)
        compare(stack._frames.length, 1)
        checkRest("first page")
        compare(frameBackground(stack._frames[0]).radius, 192, "page background is the screen circle")

        // push: both pages are circles until every push spring has settled
        stack.push(pageB)
        verify(stack.pushing)
        checkMoving("push start")
        wait(150)
        verify(stack.pushing)
        checkMoving("push mid")
        compare(frameBackground(stack._frames[1]).radius, 192, "new page background circle")
        tryCompare(stack, "pushing", false, 3000)
        checkRest("push settled")

        // the stock pop transition (popAnim): circles again until the pop ends
        stack.popAnim()
        verify(stack._popActive)
        checkMoving("pop start")
        tryCompare(stack, "_popActive", false, 3000)
        compare(stack.layers.length, 0, "popped")
        checkRest("pop settled")

        // a back swipe in progress: the pages move with the finger, masked
        stack.push(pageB)
        tryCompare(stack, "pushing", false, 3000)
        mousePress(stack, 40, 192)
        for (var x = 40; x <= 200; x += 20) {
            mouseMove(stack, x, 192)
            wait(16)
        }
        verify(stack._popActive, "back swipe started")
        checkMoving("back swipe")
        mouseRelease(stack, 200, 192)
        tryCompare(stack, "_popActive", false, 3000)
        checkRest("back swipe settled")
        while (stack.layers.length > 0)
            stack.pop(stack.currentLayer)
    }

    // ---- D60-41: AlertDialog info style (CP3A DialogUtils.showPopup) ----
    // CP3A info_value_legal_notices (three lines in Title3 on the emulator)
    readonly property string legalText: "For legal notices, see device paired with your watch"
    // the eos wording of About > Legal notices (asteroid-settings AboutPage.qml)
    readonly property string eosLegalText: "AsteroidOS is free software. Its licences, and the source of this system, are at asteroidos.org."
    Component {
        id: infoC
        AlertDialog {
            buttons: "info"
            text: tc.legalText
        }
    }
    Component {
        id: infoEosC
        AlertDialog { buttons: "info"; text: tc.eosLegalText }
    }
    Component {
        id: infoTitleOnlyC
        AlertDialog { buttons: "info"; title: "Only a title" }
    }
    Component {
        id: infoLongC
        AlertDialog {
            buttons: "info"
            text: "Line of text that wraps. ".repeat(14)
        }
    }
    Component {
        id: m3C
        AlertDialog { title: "Turn on Bedtime mode?"; text: "Notifications and the screen stay off" }
    }
    function inScene(item) { return item.mapToItem(tc, 0, 0) }
    function openDialog(c) {
        var d = createTemporaryObject(c, tc, { width: 384, height: 384 })
        d.open()
        tryCompare(d, "shown", true, 3000)
        // the entry springs snap to their targets once they rest (WearSpring
        // advance: setValueInternal(m_to)); measure only then, as scene
        // positions go through contentScale (1.0008 still moves a 773 px
        // column by 0.6 px and x 36 by 0.13 px)
        tryVerify(function() { return d.contentScale === 1 && d.alpha === 1 }, 3000, "open settled")
        return d
    }
    // the cap top of the first line in scene px (Noto Sans cap height)
    function firstCapTop(label, metrics) {
        var p = inScene(label)
        return p.y + label.topPadding + metrics.ascent - metrics.capHeightPx
    }
    FontMetrics { id: tm; font.family: "Noto Sans"; font.pixelSize: 32; font.weight: 500
        readonly property real capHeightPx: capitalHeight }

    function test_41_infoLayout() {
        var d = openDialog(infoC)
        verify(d.info, "info style")
        verify(!d.scrolling, "fits")
        // no title, no M3 buttons, no edge button
        verify(!d.titleLabel.parent.parent.visible, "title row hidden")
        verify(!d.edgeButton.visible, "no edge button")
        verify(!d.confirmButton.visible && !d.dismissButton.visible, "no M3 icon buttons")
        // the message: titleMedium, onSurface, centred, Title3 tracking
        var t = d.textLabel
        compare(t.text, tc.legalText)
        compare(t.font.pixelSize, 32, "Title3 16 sp")
        near(t.lineHeight, 36, 0.001, "18 sp line")
        compare(t.font.weight, 500, "titleMedium face")
        near(t.font.letterSpacing, 0.8, 0.02, "0.025 em tracking")
        compare(t.color, Theme.color.onSurface, "onSurface")
        compare(String(t.color), "#e8e7ee", "#E8E7EE")
        compare(t.horizontalAlignment, Text.AlignHCenter)
        var tp = inScene(t)
        near(tp.x, 52, 0.5, "message box from x 52")
        near(t.width, 280, 0.5, "to x 332")
        compare(t.lineCount, 3, "three lines")
        near(t.height, 108, 0.6, "36 px per line, as the View box")
        // first baseline 28 px below the box top, the last 8 px above its bottom
        near(t.topPadding + tm.ascent, 28, 0.6, "first baseline at 14 sp")
        near(t.height - (t.topPadding + tm.ascent + 2 * 36), 8, 0.6, "last baseline 4 sp above the bottom")
        // the round button: 104 px circle at the bottom, centred
        var b = d.infoButton
        verify(b.visible, "info button shown")
        compare(b.width, 104); compare(b.height, 104)
        var bp = inScene(b)
        near(bp.x, 140, 0.5, "button x 140-244")
        near(bp.y, 257, 0.5, "button y 257-361")
        var shape = b.children[0]
        compare(shape.radius, 52, "a circle")
        compare(String(shape.color), "#dbe2f9", "primary #DBE2F9")
        var glyph = b.children[1]
        compare(glyph.glyph, "check")
        compare(glyph.width, 52, "26 dp check")
        compare(String(glyph.color), "#383f51", "onPrimary #383F51")
        compare(b.Accessible.name, "OK")
        // the message is centred between the top padding (47) and the button (257)
        compare(d.topPadding, 47, "12.48 %")
        compare(d.bottomPadding, 23, "6.24 %")
        var top = tp.y - d.infoTextTop
        near(top - 47, 257 - (tp.y + t.height), 0.6, "centred: same space above and below")
        var cap = firstCapTop(t, tm)
        console.log("info: message box y", tp.y.toFixed(1), "first cap top", cap.toFixed(1),
                    "(stock 111), button y", bp.y)
        near(tp.y, 106, 0.6, "message box top as CP3A's chain (47 + 43 + 16)")
        near(cap, 111, 3, "first cap top y 111 +- 3")
        // the check confirms and closes
        var confirmed = false
        d.confirmed.connect(function() { confirmed = true })
        mouseClick(b)
        verify(confirmed, "OK confirms")
        tryCompare(d, "shown", false, 3000)
    }

    function test_41_infoEosWording() {
        // the eos legal wording is six lines of Title3 in 280 px: more than
        // the five that fit between 47 px and the button, so it scrolls
        var d = openDialog(infoEosC)
        compare(d.textLabel.lineCount, 6, "eos wording: 6 lines")
        near(d.textLabel.height, 216, 0.6, "6 x 36 px")
        verify(d.scrolling, "eos wording scrolls in the stock layout")
        console.log("eos legal wording:", d.textLabel.lineCount, "lines, content", d.naturalHeight, "px")
        d.close()
    }

    function test_41_infoTitleOnlyAndLong() {
        var d = openDialog(infoTitleOnlyC)
        compare(d.textLabel.text, "Only a title", "a title alone is the message")
        verify(!d.titleLabel.parent.parent.visible, "no title row")
        near(inScene(d.infoButton).y, 257, 0.5, "button at the bottom")
        d.close()

        var l = openDialog(infoLongC)
        verify(l.scrolling, "long message scrolls")
        compare(l.bottomPadding, 79, "20.83 % while it scrolls")
        var t = l.textLabel
        // the button follows the message directly: in the column's own
        // coordinates the button row starts where the text row ends
        // (spacing 0 and no free half while it scrolls)
        var textRow = t.parent.parent, infoRow = l.infoButton.parent.parent
        near(infoRow.y - (textRow.y + textRow.height), 0, 0.001, "button row follows the text row")
        // the text row is the message box at the edge scale rounded up to a
        // whole px (stock getTransformedHeight: ceil(s h)): less than 1 px
        var fx = textRow.data[0]
        var box = t.y + t.height
        compare(textRow.height, Math.ceil(fx.scale * box), "text row ceil(s h)")
        var below = textRow.height - box
        verify(below >= 0 && below < 1, "under 1 px from the text box to the button: " + below)
        // the same in the scene, now that the dialog is at rest
        near(inScene(l.infoButton).y - (inScene(t).y + t.height), below, 0.01, "scene gap = the ceil remainder")
        console.log("long info: text box", Math.round(box * 1000) / 1000, "row", textRow.height, "edge scale", fx.scale,
                    "gap", Math.round(below * 1000) / 1000)
        compare(l.flickable.contentY, -l.flickable.topMargin, "starts at the top")
        near(l.flickable.topMargin, 47, 0.01, "top padding 47")
        l.close()
    }

    function test_41_m3Unchanged() {
        // the two-button confirmation is the Wear OS 6 one now (N61-11):
        // the info style's 104 px round button, twice
        var d = openDialog(m3C)
        verify(!d.info && d.twoButtons)
        verify(!d.infoButton.visible, "no info button")
        verify(d.titleLabel.visible && d.titleLabel.text !== "")
        compare(d.textLabel.font.pixelSize, 28, "text bodyMedium")
        compare(d.topPadding, 47)
        // two lines of title and two of text are 2 px more than the room:
        // it scrolls, as the stock ScrollView, with the 20.83 % padding
        console.log("m3C: title lines", d.titleLabel.lineCount, "text lines", d.textLabel.lineCount,
                    "content", d.naturalHeight, "scrolling", d.scrolling)
        compare(d.bottomPadding, d.scrolling ? 79 : 23, "6.24 %, 20.83 % while it scrolls")
        compare(d.textLabel.y, 24, "12 dp above the text")
        near(inScene(d.textLabel).x, 20 + 0.0416 * 384, 0.001, "text side padding 4.16 %")
        verify(d.confirmButton.visible && d.dismissButton.visible)
        compare(d.confirmButton.width, d.infoButtonSize, "the info style's button size")
        d.close()
    }
}
