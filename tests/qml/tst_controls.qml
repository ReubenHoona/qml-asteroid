import QtQuick
import QtTest
import org.asteroid.controls
import org.asteroid.utils

// W1-qa-controls: the Material 3 component set. 384 x 384, 2 px per dp.
// Numbers from the gaps (audit/controls-components, design-tokens-17,
// dialogs-pickers-feedback-18/19, notif-stream-03) and TOKENS.md.
TestCase {
    id: tc
    name: "Controls"
    when: windowShown
    visible: true
    width: 384
    height: 384

    function near(a, b, tol, msg) {
        verify(Math.abs(a - b) <= tol, msg + ": " + a + " != " + b + " (tol " + tol + ")")
    }
    function sameColor(a, b, msg) {
        var A = Qt.color(a), B = Qt.color(b)
        verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
               && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
    }
    function rgba(hex, a) { var c = Qt.color(hex); return Qt.rgba(c.r, c.g, c.b, a) }
    function cleanup() { mouseRelease(tc, 1, 1) }
    // show only the test's own fixture, so clicks reach it
    function only(item) {
        var h = item
        while (h.parent !== tc) h = h.parent
        for (var i = 0; i < tc.children.length; i++)
            tc.children[i].visible = tc.children[i] === h
    }

    // ---- density ----
    function test_density() {
        compare(Theme.dp(1), 2, "2 px per dp on a 384 px screen")
    }

    // ---- Ripple (controls-components-07) ----
    Item {
        id: rippleHost
        x: 0; y: 0; width: 200; height: 104
        MouseArea { id: rippleArea; anchors.fill: parent }
        Ripple { id: ripple; radius: 52; pressed: rippleArea.pressed; pressX: rippleArea.mouseX; pressY: rippleArea.mouseY }
    }
    function test_ripple() {
        only(rippleHost)
        compare(ripple.alpha, 0.10, "ripple alpha 0.10 (RippleAlpha pressedAlpha)")
        compare(ripple.growDuration, 450, "grow 450 ms")
        compare(ripple.fadeDuration, 375, "fade 375 ms")
        verify(!ripple.visible, "nothing drawn at rest")
        mousePress(rippleArea, 20, 30)
        verify(ripple.visible, "drawn while pressed")
        near(ripple._cx, 20, 0.5, "ripple centred on the press x")
        near(ripple._cy, 30, 0.5, "ripple centred on the press y")
        near(ripple.coverRadius, Math.sqrt(180 * 180 + 74 * 74), 0.5, "grows to the farthest corner")
        wait(225)
        verify(ripple.circleRadius > 0.5 * ripple.coverRadius && ripple.circleRadius < ripple.coverRadius,
               "half way through (0.4,0,0.2,1) at 225 ms: " + ripple.circleRadius)
        wait(300)
        near(ripple.circleRadius, ripple.coverRadius, 0.5, "covers the control after 450 ms")
        compare(ripple.fade, 1, "full while held")
        mouseRelease(rippleArea, 20, 30)
        wait(190)
        near(ripple.fade, 0.5, 0.15, "linear fade, half at 187 ms")
        wait(260)
        compare(ripple.fade, 0, "gone after 375 ms")
        verify(!ripple.visible && !ripple.running, "invisible and idle after the fade")
    }

    // ---- Buttons (controls-components-31) ----
    Column {
        x: 0; y: 110; width: 344
        Button { id: bFilled; width: 344; text: "Filled"; iconName: "ios-settings" }
        Button { id: bTwo; width: 344; text: "Label"; secondaryText: "Second"; variant: "tonal" }
        FilledTonalButton { id: bTonal; width: 344; text: "Tonal" }
        OutlinedButton { id: bOutlined; width: 344; text: "Outlined" }
        Button { id: bChild; width: 344; text: "Child"; variant: "child" }
        Button { id: bDisabled; width: 344; text: "Off"; enabled: false }
        CompactButton { id: bCompact; text: "Compact" }
        CompactButton { id: bCompactIcon; iconName: "ios-add" }
        TextButton { id: tb; text: "OK" }
        TextButton { id: tbF; text: "1"; variant: "filled"; size: Theme.dp(60) }
    }
    function test_buttonSizes() {
        only(bFilled)
        compare(bFilled.height, 104, "Button min 52 dp")
        compare(bFilled.container.radius, 52, "CornerLarge 26 dp")
        compare(bFilled.horizontalPadding, 28, "14 dp side padding")
        compare(bFilled.verticalPadding, 12, "6 dp vertical padding")
        compare(bFilled.iconSize, 52, "icon 26 dp")
        compare(bFilled.iconSpacing, 12, "icon gap 6 dp")
        compare(bFilled.label.font.pixelSize, 30, "label labelMedium 15 sp")
        compare(bTwo.secondaryLabel.font.pixelSize, 26, "second line labelSmall 13 sp")
        compare(bTwo.maximumLineCount, 3, "3 label lines with a second line")
        compare(bFilled.maximumLineCount, 5, "5 label lines without")
        compare(bCompact.height, 96, "compact touch 48 dp")
        compare(bCompact.container.height, 64, "compact container 32 dp")
        compare(bCompact.container.radius, 32, "compact pill")
        compare(bCompact.horizontalPadding, 24, "compact sides 12 dp")
        compare(bCompact.iconSize, 40, "compact icon 20 dp")
        compare(bCompactIcon.width, 104, "icon-only compact 52 dp wide")
        compare(bCompactIcon.iconSize, 48, "icon-only compact icon 24 dp")
        compare(tb.width, 104, "TextButton 52 dp")
        compare(tbF.width, 120, "TextButton 60 dp")
    }
    function test_buttonColors() {
        only(bFilled)
        sameColor(bFilled.containerColor, "#DBE2F9", "filled container primary")
        sameColor(bFilled.contentColor, "#383F51", "filled content onPrimary")
        sameColor(bTonal.containerColor, "#2F3036", "tonal surfaceContainer")
        sameColor(bTonal.contentColor, "#E8E7EE", "tonal onSurface")
        sameColor(bTwo.secondaryContentColor, "#DBE2F9", "tonal second line primary (N61-07)")
        sameColor(bTonal.iconColor, "#DBE2F9", "tonal icon primary")
        sameColor(bOutlined.containerColor, "transparent", "outlined transparent")
        compare(bOutlined.borderWidth, 2, "outlined 1 dp border")
        sameColor(bOutlined.borderColor, "#85858C", "outlined border outlineVariant")
        sameColor(bChild.containerColor, "transparent", "child transparent")
        compare(bChild.borderWidth, 0, "child no border")
        sameColor(bDisabled.containerColor, rgba("#E8E7EE", 0.12), "disabled container onSurface 12 %")
        sameColor(bDisabled.contentColor, rgba("#E8E7EE", 0.38), "disabled content onSurface 38 %")
        sameColor(tb.contentColor, "#E8E7EE", "TextButton onSurface")
        sameColor(tbF.containerColor, "#DBE2F9", "filled TextButton primary")
        sameColor(bFilled.ripple.color, bFilled.contentColor, "ripple in the content colour")
    }

    // ---- Ripple pixels: drawn clipped and in the colour at 10 % ----
    Rectangle {
        id: rippleBox
        x: 0; y: 0; width: 120; height: 60
        color: "black"
        MouseArea { id: rippleBoxArea; anchors.fill: parent }
        Ripple { id: redRipple; radius: 30; color: "#ff0000"; pressed: rippleBoxArea.pressed; pressX: rippleBoxArea.mouseX; pressY: rippleBoxArea.mouseY }
    }
    function test_ripplePixels() {
        only(rippleBox)
        mousePress(rippleBoxArea, 60, 30)
        wait(600)
        var img = grabImage(rippleBox)
        var c = img.pixel(60, 30)
        near(c.r * 255, 25.5, 4, "red at 10 % over black in the middle")
        compare(c.g, 0, "no green")
        var corner = img.pixel(1, 1)
        verify(corner.r * 255 < 3, "outside the rounded shape stays clear: " + corner.r * 255)
        mouseRelease(rippleBoxArea, 60, 30)
        wait(450)
        verify(!redRipple.visible, "gone after the fade")
    }

    // ---- Switch (controls-components-29, -02) ----
    Item {
        x: 0; y: 0; width: 100; height: 60
        Switch { id: sw }
    }
    function test_switch() {
        only(sw)
        // N61-06: the Wear OS 6 emulator's small switch
        compare(sw.width, 48, "slot 24 dp")
        compare(sw.height, 28, "slot 14 dp")
        compare(sw.trackWidth, 48, "track 24 dp")
        compare(sw.trackHeight, 20, "track 10 dp")
        compare(sw.borderWidth, 0, "no border")
        sw.checked = false
        wait(250)
        compare(sw.thumbSize, 28, "off thumb 14 dp")
        compare(sw.thumbCenter, 14, "off thumb centre 7 dp")
        sameColor(sw.trackColor, Qt.tint("#2F3036", rgba("#E8E7EE", 0.38)), "off track onSurface 38 % over surfaceContainer")
        sameColor(sw.thumbColor, "#8B8B8F", "off thumb #8B8B8F")
        compare(Motion.springDuration(Motion.standard.fastEffects.stiffness), 177, "one 177 ms transition")
        sw.checked = true
        wait(90)
        verify(sw.progress > 0.3 && sw.progress < 1, "moving at 90 ms: " + sw.progress)
        // motion G5 G6 (eea477a): a WearSpring (fast effects 1.0/1400), not a 177 ms
        // tween: 99 % at 177 ms, at rest (its 0.001 visibility threshold) at about 250 ms
        tryCompare(sw, "progress", 1, 1000, "at rest on the fast effects spring")
        compare(sw.thumbSize, 28, "on thumb 14 dp")
        compare(sw.thumbCenter, 34, "on thumb centre 17 dp")
        sameColor(sw.trackColor, Qt.tint("#2F3036", rgba("#D4C7FF", 0.38)), "on track tertiary 38 %")
        sameColor(sw.thumbColor, "#D4C7FF", "on thumb tertiary")
        mouseClick(sw)
        compare(sw.checked, false, "a tap toggles")
    }

    // ---- Switch, radio and checkbox rows (controls-components-28, -34) ----
    Column {
        x: 0; y: 0; width: 344
        SwitchButton { id: swRow; width: 344; text: "Wi-Fi"; secondaryText: "On" }
        RadioButton { id: radio; width: 344; text: "One" }
        CheckboxButton { id: check; width: 344; text: "Mon" }
    }
    function test_switchRow() {
        only(swRow)
        verify(swRow.height >= 104 && swRow.height < 108, "row at least 52 dp (two lines): " + swRow.height)
        compare(radio.height, 104, "one-line row 52 dp")
        compare(swRow.verticalPadding, 16, "toggle rows 8 dp vertical padding")
        compare(swRow.trailingWidth, 48, "24 dp control slot (N61-07)")
        compare(swRow.trailingSpacing, 12, "6 dp after the label")
        compare(swRow.colorDuration, 412, "slow effects spring, 412 ms")
        swRow.checked = false
        wait(500)
        sameColor(swRow.containerColor, "#2F3036", "off surfaceContainer")
        sameColor(swRow.contentColor, "#E8E7EE", "off label onSurface")
        mouseClick(swRow)
        compare(swRow.checked, true, "tap toggles")
        wait(500)
        // N61-07: surfaceContainer with the checked gradient, onSurface, primary second line
        sameColor(swRow.containerColor, "#2F3036", "on surfaceContainer")
        // the slow effects spring (1.0/260) is past 99 % at 412 ms of spring time, which
        // lags the wall clock under load: bounded, not at a fixed time
        tryVerify(function() { return swRow.checkedGradient > 0.99 }, 1500,
                  "on: the checked gradient (slow spring): " + swRow.checkedGradient)
        sameColor(swRow.contentColor, "#E8E7EE", "on label onSurface")
        sameColor(swRow.secondaryContentColor, "#DBE2F9", "on second line primary")
        sameColor(swRow.iconColor, "#DBE2F9", "icon primary")
    }
    function test_radioRow() {
        only(radio)
        compare(Theme.size.radio, 40, "ring 20 dp outside")
        compare(Theme.size.radioStroke, 4, "ring stroke 2 dp")
        compare(Theme.size.radioDot, 20, "dot 10 dp")
        radio.checked = false
        wait(250)
        compare(radio.dotScale, 0, "no dot unselected")
        sameColor(radio.controlColor, "#A5A5AC", "ring outline unselected")
        mouseClick(radio)
        compare(radio.checked, true, "tap selects")
        mouseClick(radio)
        compare(radio.checked, true, "a second tap does not unselect")
        // motion G5 G6 (eea477a): the dot grows on a WearSpring (fast effects 1.0/1400),
        // not a 177 ms tween: 99 % at 177 ms, at rest (its 0.001 visibility
        // threshold) at about 250 ms
        wait(250)
        verify(radio.dotScale > 0.99, "dot grown: " + radio.dotScale)
        tryCompare(radio, "dotScale", 1, 1000, "at rest on the fast effects spring")
        sameColor(radio.controlColor, "#DBE2F9", "ring primary selected")
        wait(300)
        sameColor(radio.containerColor, "#404759", "selected row primaryContainer")
    }
    function test_checkboxRow() {
        only(check)
        check.checked = false
        wait(250)
        sameColor(check.boxColor, "#A5A5AC", "unchecked outline")
        mouseClick(check)
        compare(check.checked, true, "tap checks")
        // motion G5 G6 (eea477a): the tick runs on a WearSpring (fast effects 1.0/1400),
        // not a 177 ms tween: 99 % at 177 ms, at rest (its 0.001 visibility
        // threshold) at about 250 ms
        wait(250)
        verify(check.progress > 0.99, "tick drawn: " + check.progress)
        tryCompare(check, "progress", 1, 1000, "at rest on the fast effects spring")
        sameColor(check.boxColor, "#DBE2F9", "checked box primary")
        sameColor(check.checkColor, "#404759", "check mark primaryContainer")
        compare(check.verticalPadding, 16, "14/8/14/8 dp")
    }

    // ---- List rows (controls-components-28) ----
    Column {
        x: 0; y: 0; width: 384
        ListItem { id: li; title: "Display"; iconName: "ios-sunny" }
        ListItem { id: liSel; title: "Selected"; highlight: true }
        LabeledSwitch { id: ls; width: 384; height: implicitHeight; text: "Feature" }
        LabeledActionButton { id: lab; width: 384; height: implicitHeight; text: "Check"; icon: "ios-refresh" }
        OptionCycler { id: oc; width: 384; height: implicitHeight; text: "Design"; valueArray: ["a", "b", "c"]; currentValue: "a"
                       onValueChanged: (v) => { ocPicked = v; currentValue = v } }
        RowSeparator { id: sep }
        IntSelector { id: isel; width: 384; height: 112; min: 0; max: 100; stepSize: 10; value: 50 }
    }
    property string ocPicked: ""
    function test_listItem() {
        only(li)
        compare(li.height, 112, "52 dp row plus the 4 dp list spacing")
        compare(li.button.height, 104, "row 52 dp")
        compare(li.button.x, Theme.margin.listSide, "5.2 % side padding")
        near(Theme.margin.listSide, 19.97, 0.05, "listSide 5.2 % of 192 dp")
        compare(li.button.container.radius, 52, "CornerLarge")
        sameColor(li.button.containerColor, "#2F3036", "tonal container")
        sameColor(li.button.iconColor, "#DBE2F9", "icon primary")
        compare(li.button.iconSize, 52, "icon 26 dp")
        compare(li.button.label.font.pixelSize, 30, "label 15 sp")
        sameColor(liSel.button.containerColor, "#404759", "highlight = selected colours")
        var clicked = false
        li.clicked.connect(function () { clicked = true })
        mouseClick(li)
        verify(clicked, "clicked forwarded")
    }
    function test_listRows() {
        only(ls)
        compare(ls.container.height, ls.height - 8, "container inside the 4 dp gaps")
        verify(ls.container.height >= 104, "row at least 52 dp: " + ls.container.height)
        compare(ls.container.radius, 52, "CornerLarge")
        compare(ls.container.x, ls.rowMargin, "side padding"); compare(ls.rowMargin, Math.floor(Theme.margin.listSide), "5.2 % (int)")
        compare(ls.iconSize, 64, "32 dp control slot")
        ls.checked = false
        wait(450)
        sameColor(ls.containerColor, "#2F3036", "off")
        mouseClick(ls)
        compare(ls.checked, true, "tap anywhere toggles")
        compare(ls.actionArea.item.checked, true, "switch follows")
        sameColor(ls.containerColor, "#404759", "on: checked colours")
        sameColor(ls.contentColor, "#D9E0F7", "on: label onPrimaryContainer")
        compare(lab.actionArea.item.children[0].width, 52, "action icon 26 dp")
        compare(sep.height, 8, "rows 4 dp apart, no divider")
        sameColor(sep.color, "transparent", "no divider")
    }
    function test_optionCycler() {
        only(oc)
        compare(oc.secondaryText, "a", "value as the second line")
        mouseClick(oc)
        verify(oc.choosing, "a tap opens the choice page, never cycles")
        compare(ocPicked, "", "nothing picked yet")
        oc.choose("c")
        verify(!oc.choosing, "picking closes it")
        compare(ocPicked, "c", "valueChanged with the pick")
        compare(oc.secondaryText, "c", "second line follows")
    }
    function test_intSelector() {
        only(isel)
        compare(Theme.size.sliderButtonWidth, 96, "buttons 48 dp")
        compare(Theme.size.sliderSelectedBar, 24, "selected bar 12 dp")
        compare(Theme.size.sliderUnselectedBar, 8, "unselected bar 4 dp")
        sameColor(isel.containerColor, "#2F3036", "slider container")
        compare(isel.fraction, 0.5, "half")
        isel._step(10)
        compare(isel.value, 60, "step up")
        isel._step(100)
        compare(isel.value, 100, "clamped at max")
        isel.value = 50
    }

    // ---- Headers (controls-components-27) ----
    Column {
        x: 0; y: 0; width: 384
        ListHeader { id: lh; text: "Display" }
        ListSubHeader { id: lsh; text: "Brightness" }
        ListSubHeader { id: lsh0; text: "First"; first: true }
    }
    function test_headers() {
        only(lh)
        compare(lh.label.font.pixelSize, 32, "titleMedium 16 sp")
        // D60-37 (1bf3893): titleMedium asks Noto Sans for Medium (500); the CP3A 550 is axes.wght
        compare(lh.label.font.weight, 500, "weight 500 (static face)")
        compare(Theme.type.titleMedium.axes.wght, 550, "CP3A weight 550 for a variable font")
        sameColor(lh.label.color, "#FFFFFF", "onBackground")
        compare(lh.label.horizontalAlignment, Text.AlignHCenter, "centred")
        near(lh.horizontalPadding, 46.08, 0.05, "12 % of the width each side")
        compare(lh.topPadding, 8, "4 dp above")
        compare(lh.bottomPadding, 24, "12 dp below")
        compare(lh.height, 96, "min 48 dp")
        compare(lh.label.maximumLineCount, 3, "3 lines")
        // N61-05 (f723498, 1908d6d): the Wear OS 6 sub-header, labelSmall 13 sp Medium,
        // the ink 16 dp from its own edge, the cap top 37 px under the row above and
        // the next row 21 px under the baseline (less the list's 4 dp), no 48 dp box
        compare(lsh.label.font.pixelSize, 26, "labelSmall 13 sp")
        compare(lsh.label.font.weight, Font.Medium, "Medium")
        sameColor(lsh.label.color, "#E8E7EE", "onSurface")
        compare(lsh.textInset, 32, "the ink 16 dp from its own edge")
        verify(lsh.horizontalPadding > 26 && lsh.horizontalPadding <= 32, "16 dp less the font's left bearing: " + lsh.horizontalPadding)
        compare(lsh.topPadding, 29, "37 px to the cap top, less the list's 8")
        compare(lsh0.topPadding, 0, "0 above the first item")
        compare(lsh.bottomPadding, 13, "21 px under the baseline, less the list's 8")
        verify(lsh.height < 96, "no 48 dp minimum: " + lsh.height)
    }

    // ---- Cards (controls-components-33) ----
    Column {
        x: 0; y: 0; width: 344
        Card { id: card; width: 344 }
        AppCard { id: appCard; width: 344; appName: "App"; time: "now"; title: "Title"; text: "Body" }
        TitleCard { id: titleCard; width: 344; title: "Title"; time: "12:00"; text: "Body"; subtitle: "Sub" }
    }
    function test_cards() {
        only(card)
        compare(card.height, 128, "min 64 dp")
        compare(card.padding, 24, "12 dp padding")
        compare(card.container.radius, 52, "CornerLarge 26 dp")
        sameColor(card.containerColor, "#2F3036", "surfaceContainer")
        compare(card.ripple.alpha, 0.10, "bounded ripple")
        verify(appCard.height > 128, "content grows the card")
        compare(Theme.type.titleMedium.pixelSize, 32, "card title 16 sp")
        compare(Theme.type.bodyLarge.pixelSize, 32, "card content 16 sp")
        compare(Theme.type.bodyMedium.pixelSize, 28, "time 14 sp")
        sameColor(Theme.color.tertiary, "#D4C7FF", "subtitle tertiary")
    }

    // ---- IconButton (controls-components-30) ----
    Row {
        x: 0; y: 0
        IconButton { id: ibLegacy; iconName: "ios-add" }
        IconButton { id: ibXs; size: Theme.size.iconButtonExtraSmall; iconName: "ios-add" }
        IconButton { id: ibS; size: Theme.size.iconButtonSmall; iconName: "ios-add"; variant: "tonal" }
        IconButton { id: ib; size: Theme.size.iconButton; iconName: "ios-add"; variant: "filled" }
        IconButton { id: ibL; size: Theme.size.iconButtonLarge; iconName: "ios-add"; variant: "outlined" }
        IconButton { id: ibOff; size: Theme.size.iconButton; iconName: "ios-add"; variant: "filled"; enabled: false }
    }
    function test_iconButton() {
        only(ib)
        near(ibLegacy.width, Dims.l(20), 0.01, "old default kept without size")
        sameColor(ibLegacy.iconColor, "#FFFFFF", "old white icon")
        compare(ibXs.width, 64, "32 dp"); compare(ibXs.iconSize, 48, "icon 24 dp")
        compare(ibS.width, 96, "48 dp"); compare(ibS.iconSize, 48, "icon 24 dp")
        compare(ib.width, 104, "52 dp"); compare(ib.iconSize, 52, "icon 26 dp")
        compare(ibL.width, 120, "60 dp"); compare(ibL.iconSize, 64, "icon 32 dp")
        sameColor(ib.containerColor, "#DBE2F9", "filled primary")
        sameColor(ib.iconColor, "#383F51", "filled onPrimary")
        sameColor(ibS.containerColor, "#2F3036", "tonal surfaceContainer")
        sameColor(ibS.iconColor, "#DBE2F9", "tonal primary")
        sameColor(ibXs.containerColor, "transparent", "plain transparent")
        sameColor(ibXs.iconColor, "#DBE2F9", "plain primary")
        sameColor(ibL.containerColor, "transparent", "outlined transparent")
        sameColor(ibOff.containerColor, rgba("#E8E7EE", 0.12), "disabled container")
        sameColor(ibOff.iconColor, rgba("#E8E7EE", 0.38), "disabled content")
    }
    function test_pressMorph() {
        only(ib)
        var box = ib.children[0]
        compare(box.radius, 52, "circle at rest")
        mousePress(ib, 52, 52)
        wait(150)
        near(box.radius, Theme.shape.small, 1, "pressed: small corners (spring 12600)")
        mouseRelease(ib, 52, 52)
        wait(900)
        near(box.radius, 52, 0.5, "back to a circle (spring 260)")
    }

    // ---- EdgeButton (controls-components-32) ----
    Item {
        id: edgeHost
        x: 0; y: 0; width: 384; height: 384
        Flickable {
            id: edgeList
            anchors.fill: parent
            contentHeight: 1000
            bottomMargin: edge.contentPadding
        }
        EdgeButton { id: edge; text: "Done"; flickable: edgeList }
        EdgeButton { id: edgeL; text: "Large"; preferredHeight: Theme.size.edgeButtonLarge; visible: false }
    }
    function test_edgeButton() {
        only(edge)
        compare(Theme.size.edgeButtonExtraSmall, 92, "46 dp")
        compare(Theme.size.edgeButtonSmall, 112, "56 dp (default)")
        compare(Theme.size.edgeButtonMedium, 140, "70 dp")
        compare(Theme.size.edgeButtonLarge, 192, "96 dp")
        compare(edge.preferredHeight, 112, "default 56 dp")
        compare(edge.contentPadding, 112 - 6 + 32, "height - 3 dp + 16 dp")
        sameColor(edge.containerColor, "#DBE2F9", "primary")
        sameColor(edge.contentColor, "#383F51", "onPrimary")
        var g = edge.geometry(384, 112)
        near(g.ellipseHeight, 116 + 1.42 * 20, 0.01, "ellipse 58 dp + 1.42 x extra")
        near(g.a, Math.sqrt(g.ellipseHeight / 2 * (192 - 6)), 0.01, "half width sqrt(b R)")
        near(g.qy, g.k, 0.01, "corner circles touch the top")
        near(g.sweep, 90, 0.01, "quarter corners at full height")
        compare(g.fade, 0, "no fade at full height")
        var gs = edge.geometry(384, 46)
        near(gs.fade, 0.5, 0.001, "half faded at 23 dp")
        near(gs.ellipseHeight, 0.5 * (58 * 2 + 1.42 * (46 - 92)) + 0.5 * 46, 0.01, "ellipse lerps to the height")
        compare(edge.anchors.bottomMargin, 6, "3 dp above the edge")
        // reveal: held back by the scroll left
        edgeList.contentY = 0
        wait(400)
        compare(edge.shownHeight, 0, "hidden far from the end")
        edgeList.contentY = edgeList.contentHeight + edgeList.bottomMargin - edgeList.height - 50
        wait(400)
        near(edge.shownHeight, 62, 0.5, "grows as the end nears (112 - 50)")
        edgeList.contentY = edgeList.contentHeight + edgeList.bottomMargin - edgeList.height
        wait(400)
        compare(edge.shownHeight, 112, "full at the end")
        compare(Motion.springDuration(400), 332, "settles with stiffness 400")
    }

    // ---- Progress (controls-components-35/36, dialogs-pickers-feedback-18/19) ----
    Item {
        x: 0; y: 0; width: 384; height: 384
        CircularProgressIndicator { id: ring; anchors.fill: parent; progress: 0.25 }
        CircularProgressIndicator { id: spin; indeterminate: true; displayOn: true }
        CircularProgressIndicator { id: spinOff; indeterminate: true; displayOn: false }
        ArcProgressIndicator { id: arcp; displayOn: true }
        LinearProgressIndicator { id: lin; width: 200; progress: 0.5 }
        ProgressDialog { id: pdlg; anchors.fill: parent; title: "Installing"; message: "Step"; progress: 0.5; visible: false }
    }
    function test_circularDeterminate() {
        only(ring)
        compare(ring.strokeWidth, 10, "5 dp stroke")
        near(ring.gap, 10 / 3, 0.001, "gap stroke / 3")
        compare(ring.edgePadding, 4, "2 dp from the edge")
        compare(ring._start, 270, "starts at 12 o'clock")
        sameColor(ring.color, "#DBE2F9", "primary")
        sameColor(ring.trackColor, "#2F3036", "on surfaceContainer")
        wait(400)
        near(ring._fraction, 0.25, 0.001, "progress shown")
        ring.progress = 1.5
        sameColor(ring.trackColor, rgba("#DBE2F9", 0.6), "overflow primary 60 %")
        ring.progress = 0.25
        verify(!ring.running, "nothing runs for a determinate ring")
        compare(pdlg.ring.strokeWidth, 10, "dialog ring 5 dp")
    }
    LoadingRow { id: loadRow; x: 0; y: 0; text: "Verifying..." }
    function test_loadingRow() {
        only(loadRow)
        compare(loadRow.spacing, 8, "spinner, 4 dp, text")
        compare(loadRow.indicator.width, 48, "24 dp spinner")
        verify(loadRow.indicator.indeterminate, "indeterminate")
    }
    function test_circularIndeterminate() {
        only(spin)
        compare(spin.width, 48, "24 dp")
        compare(spin.strokeWidth, 6, "3 dp stroke")
        compare(spin.gap, 2, "gap stroke / 3")
        near(spin.keyframe(spin._keySweep, 1250), 0.8, 1e-6, "0.8 at 1250 ms")
        near(spin.keyframe(spin._keySweep, 2500), 0.2, 1e-6, "0.2 at 2500 ms")
        near(spin.keyframe(spin._keySweep, 3750), 0.8, 1e-6, "0.8 at 3750 ms")
        near(spin.keyframe(spin._keySweep, 5000), 0, 1e-6, "0 at 5000 ms")
        near(spin.keyframe(spin._keyExtra, 2500), 360, 1e-6, "+360 at 2500 ms")
        near(spin.keyframe(spin._keyExtra, 5000), 720, 1e-6, "+720 at 5000 ms")
        // standard easing (0.2, 0, 0, 1) at half way is ~0.81 of the step
        near(spin.keyframe(spin._keySweep, 625), 0.8 * spin._ease(0.5), 1e-6, "eased between frames")
        verify(spin._ease(0.5) > 0.75, "standard easing front-loaded: " + spin._ease(0.5))
        verify(spin.running, "runs while visible and the display is on")
        verify(!spinOff.running, "stops with the display")
        spin.visible = false
        verify(!spin.running, "stops when hidden")
        spin.visible = true
    }
    function test_arcAndLinear() {
        only(arcp)
        compare(arcp.strokeWidth, 12, "6 dp")
        compare(arcp.gap, 4, "2 dp gap")
        near(arcp._radius, 384 * 0.8124 / 2 - 6, 0.01, "81.24 % of the height")
        sameColor(arcp.color, "#CDD4EB", "primaryDim")
        compare(arcp.arcStart, 65); compare(arcp.arcEnd, 115)
        near(arcp.head(600), 1, 1e-6, "head done at 600 ms")
        near(arcp.tail(300), 0, 1e-6, "tail starts at 300 ms")
        near(arcp.tail(900), 1, 1e-6, "tail done at 900 ms")
        verify(arcp.running, "runs while shown")
        arcp.displayOn = false
        verify(!arcp.running, "stops with the display")
        compare(lin.height, 8, "4 dp tall")
        compare(lin.gap, 8, "4 dp gap")
        sameColor(lin.color, "#D4C7FF", "tertiary")
        sameColor(lin.trackColor, "#2F3036", "on surfaceContainer")
    }

    // ---- Placeholder (controls-components-37) ----
    Item {
        x: 0; y: 0; width: 200; height: 40
        Placeholder { id: ph; anchors.fill: parent; displayOn: true }
        Placeholder { id: phOff; anchors.fill: parent; displayOn: false }
    }
    function test_placeholder() {
        only(ph)
        sameColor(ph.fillColor, rgba("#E8E7EE", 0.10), "onSurface 10 %")
        verify(ph.shimmering, "shimmer while loading and on")
        verify(!phOff.shimmering, "no shimmer with the display off")
        wait(400)
        verify(ph.sweep > -0.5 && ph.sweep < 1.5, "sweeping: " + ph.sweep)
        ph.loading = false
        wait(450)
        verify(!ph.visible, "wiped off in 400 ms")
        verify(!ph.shimmering, "and stopped")
    }

    // ---- Stepper (controls-components-40) ----
    Item {
        x: 0; y: 0; width: 384; height: 384
        Stepper { id: stepper; anchors.fill: parent; from: 0; to: 3; value: 2 }
    }
    function test_stepper() {
        only(stepper)
        var inc = stepper.children[0]
        compare(inc.width, 120, "60 dp")
        compare(inc.height, 96, "48 dp")
        stepper.step(1)
        compare(stepper.value, 3, "up")
        stepper.step(1)
        compare(stepper.value, 3, "held at the limit")
    }

    // ---- Scroll indicator (controls-components-22/23) ----
    Item {
        x: 0; y: 0; width: 384; height: 384
        Flickable { id: piList; anchors.fill: parent; contentHeight: 1200 }
        PositionIndicator { id: pi }
    }
    function test_positionIndicator() {
        only(pi)
        sameColor(Theme.color.scrollThumb, "#C6C6C6", "thumb tone 80")
        sameColor(Theme.color.scrollTrack, "#303030", "track tone 20")
        compare(pi.gap, 6, "3 dp gap each side of the thumb")
        compare(pi.fadeDuration, 332, "spring 400 fade")
        verify(!pi.shown, "hidden before it is attached")
        pi.flickable = piList
        verify(pi.shown, "flashes when attached to a scrollable view (screen open)")
        wait(2600)
        verify(!pi.shown, "hidden 2 s later")
        var l0 = pi.thumbCenter
        piList.contentY = 800
        wait(250)
        verify(pi.thumbCenter > l0 && pi.thumbCenter < (pi._length - pi.thumbLength) / 2, "thumb animating (500 ms): " + pi.thumbCenter)
        wait(400)
        near(pi.thumbCenter, (pi._length - pi.thumbLength) * (pi._position - 0.5), 0.5, "arrived after 500 ms")
        piList.contentY = 0
    }

    // ---- ScrollAway (controls-components-21) ----
    Item {
        x: 0; y: 0; width: 384; height: 384
        Flickable { id: saList; anchors.fill: parent; contentHeight: 1200 }
        ScrollAway { id: sa }
    }
    function test_scrollAway() {
        only(sa)
        sa.flickable = saList
        compare(sa.threshold, 72, "36 dp")
        compare(sa.maxShift, 48, "24 dp")
        sa.stage = 2
        saList.contentY = 36
        wait(260)
        near(sa.progressValue, 0.5, 0.01, "p = 36 px / 72 px")
        near(sa.scale, 0.75, 0.01, "scale 1 - 0.5 p")
        near(sa.translateY, -24, 0.5, "up p x 24 dp")
        near(sa.alpha, 0.75, 0.01, "alpha x scale")
        saList.contentY = 54
        near(sa.progressValue, 0.75, 0.001, "follows the scroll directly (snap)")
        saList.contentY = 100
        compare(sa.alphaValue, 0, "past 36 dp: alpha snaps to 0")
        sa.stage = 1
        near(sa.progressValue, 0, 0.001, "idle and gone: back, scale snaps")
        wait(300)
        near(sa.alphaValue, 1, 0.01, "alpha back in 250 ms")
        sa.stage = 2
        saList.contentY = 108
        compare(sa.alphaValue, 0, "scroll again: gone")
        saList.contentY = 0
        sa.stage = 1
        wait(300)
        compare(sa.progressValue, 0, "top: shown")
        compare(sa.alphaValue, 1, "top: opaque")
        compare(sa.idleDelay, 2000, "idle 2 s after scrolling stops")
    }

    // ---- Page indicators (controls-components-24/25) ----
    Item {
        id: pdHost
        x: 0; y: 0; width: 384; height: 384
        ArcPageIndicator { id: api; count: 9; position: 0 }
        ArcPageIndicator { id: api3; count: 3; position: 1 }
        // a page (as a LayerStack layer or a launcher panel) with the dots
        // somewhere inside it, and a layer above it (as the top LayerStack
        // layer sliding over the page below during a back swipe)
        Rectangle {
            id: pdPage
            width: 384; height: 384
            color: "white"
            Item {
                id: pdMid
                x: 40; y: 30; width: 100; height: 40
                PageDot { id: pd; height: 10; dotNumber: 4; currentIndex: 1 }
            }
        }
        Rectangle { id: pdCover; width: 384; height: 384; color: "#ff0000"; visible: false }
    }
    function test_pageIndicator() {
        only(api)
        compare(Theme.size.pageDot, 12, "6 dp dots")
        compare(Theme.size.pageDotSpacing, 8, "4 dp apart")
        compare(Theme.size.pageIndicatorBand, 24, "band 12 dp")
        compare(api._radius, 192 - 16, "dot centres 8 dp from the edge")
        compare(api.shownCount, 6, "at most 6 dots")
        compare(api.windowStart, 0, "window at the start")
        compare(api.slotScale(0), 1, "first dot full size at the start")
        compare(api.slotScale(5), 0.66, "end dot shrinks with more pages")
        api.position = 5
        compare(api.windowStart, 3, "window follows the page")
        compare(api.slotScale(0), 0.66, "start dot shrinks when pages are before it")
        api.position = 8
        compare(api.windowStart, 3, "window ends at the last page")
        compare(api.slotScale(5), 1, "last dot full size at the end")
        compare(api3.shownCount, 3, "few pages: all shown")
        compare(api3.slotScale(0), 1, "no shrink")
        compare(api.unselectedAlpha, 0.3, "others 30 %")
        verify(DeviceSpecs.hasRoundScreen, "round screen in machine.conf")
        verify(pd.arc, "PageDot draws the arc on a round screen")
        compare(pd.arcIndicator.count, 4, "arc has the dots")
        // review fix: the arc belongs to the page, not to the window
        compare(pd.arcIndicator.parent, pd, "the arc stays a child of the PageDot")
        compare(pd.arcPage, pdPage, "drawn over the nearest ancestor covering the window")
        function aligned(msg) {
            var a = pd.arcIndicator.mapToItem(null, 0, 0), b = pdPage.mapToItem(null, 0, 0)
            near(a.x, b.x, 0.5, msg + " (x)")
            near(a.y, b.y, 0.5, msg + " (y)")
            near(pd.arcIndicator.width, 384, 0.5, msg + " (width)")
            near(pd.arcIndicator.height, 384, 0.5, msg + " (height)")
        }
        aligned("covers the page")
        pdMid.x = 120; pdMid.y = 200
        aligned("the dots moving inside the page leave the arc on the page")
        var bandAt = function(img, x) { return img.pixel(x, 384 - 16) }
        var img = grabImage(pdHost)
        verify(bandAt(img, 192).r < 0.3, "band drawn: black 0.85 over white at the bottom centre " + bandAt(img, 192).r)
        // the caller's opacity (QuickPanel hides the dots while scrubbing)
        pd.opacity = 0
        img = grabImage(pdHost)
        verify(bandAt(img, 192).r > 0.95, "opacity 0 hides the arc and band " + bandAt(img, 192).r)
        pd.opacity = 0.5
        img = grabImage(pdHost)
        near(bandAt(img, 192).r * 255, 255 * (1 - 0.5 * 0.85), 6, "opacity 0.5 halves the band")
        pd.opacity = 1
        // the page being swiped (panel swipe, LayerStack pop): the arc moves with it
        pdPage.x = 100
        aligned("follows the page while it is swiped")
        img = grabImage(pdHost)
        verify(bandAt(img, 192).r > 0.95, "nothing left at the screen centre " + bandAt(img, 192).r)
        verify(bandAt(img, 292).r < 0.3, "band at the page's bottom centre " + bandAt(img, 292).r)
        pdPage.x = 384
        img = grabImage(pdHost)
        verify(bandAt(img, 192).r < 0.01 || bandAt(img, 192).r > 0.95, "page off screen: no band on the screen")
        pdPage.x = 0
        // a layer above the page covers its arc
        pdCover.visible = true
        img = grabImage(pdHost)
        var c = bandAt(img, 192)
        verify(c.r > 0.95 && c.g < 0.05, "the layer above covers the arc: " + c)
        pdCover.visible = false
        // the caller hiding the PageDot hides the arc
        pd.visible = false
        img = grabImage(pdHost)
        verify(bandAt(img, 192).r > 0.95, "hidden with the PageDot")
        pd.visible = true
        // reparenting finds the new page (no timer: on parentChanged)
        pdMid.parent = pdHost
        wait(0)
        compare(pd.arcPage, pdHost, "new page after a reparent")
        pdMid.parent = pdPage
        wait(0)
        compare(pd.arcPage, pdPage, "back on the page")
        pdMid.x = 40; pdMid.y = 30
        aligned("aligned after the moves")
    }

    // ---- Text fields on tokens (design-tokens-17) ----
    Item {
        id: tfHost
        x: 0; y: 0; width: 384; height: 300
        TextField { id: tf; width: 300; height: 60; fullScreenKeyboard: false }
        TextArea { id: ta; y: 80; width: 300; height: 200; fullScreenKeyboard: false }
    }
    function bgOf(item) {
        for (var i = 0; i < item.children.length; i++) {
            var ch = item.children[i]
            if (ch.border !== undefined && ch.radius !== undefined && ch.width === item.width && ch.height === item.height)
                return ch
        }
        return null
    }
    function test_textFieldTokens() {
        only(tfHost)
        sameColor(tf.editor.color, Theme.color.onSurface, "TextField ink onSurface (was #2B2C2E)")
        sameColor(tf.editor.selectionColor, Theme.color.primary, "selection primary")
        sameColor(tf.editor.selectedTextColor, Theme.color.onPrimary, "selected text onPrimary")
        sameColor(ta.editor.color, Theme.color.onSurface, "TextArea ink onSurface (was #2B2C2E)")
        sameColor(ta.editor.selectionColor, Theme.color.primary, "TextArea selection primary")
        var bg = bgOf(tf)
        verify(bg !== null, "field background found")
        sameColor(bg.color, Theme.color.surfaceContainer, "field container surfaceContainer (was #FFFFFF)")
        compare(bg.radius, Theme.shape.extraSmall, "CornerExtraSmall")
        sameColor(bg.border.color, Theme.color.outline, "unfocused outline")
        compare(bg.border.width, Theme.dp(1), "1 dp")
        tf.editor.forceActiveFocus()
        sameColor(bg.border.color, Theme.color.primary, "focused primary")
        compare(bg.border.width, Theme.dp(2), "2 dp when focused")
        tf.editor.focus = false
        var rule = null
        for (var i = 0; i < ta.children.length; i++)
            if (ta.children[i].height === 1 && ta.children[i].color !== undefined) { rule = ta.children[i]; break }
        verify(rule !== null, "TextArea rule lines present")
        sameColor(rule.color, Theme.color.outlineVariant, "rules outlineVariant (was #D6D6D6)")
    }

    // ---- SwipeToReveal (notif-stream-03) ----
    Item {
        x: 20; y: 0; width: 344; height: 200
        SwipeToReveal {
            id: s2r
            width: 344; height: 150
            onPrimaryAction: s2rCleared = true
            Rectangle { anchors.fill: parent; color: "#2F3036" }
        }
    }
    property bool s2rCleared: false
    function test_swipeToReveal() {
        only(s2r)
        near(s2r.revealingOffset, 232.9, 0.1, "130 dp x 172/192 dp = 116 dp")
        compare(s2r.fullThreshold, 268, "0.75 x 192 - 10 = 134 dp")
        compare(s2r.flingVelocity, 1600, "800 dp/s")
        near(s2r.edgeExclusion, 57.6, 0.01, "left 15 % excluded")
        compare(s2r.decide(100, 0), "covered", "short swipe covers")
        compare(s2r.decide(200, 0), "revealing", "past half way: partial reveal")
        compare(s2r.decide(270, 0), "revealed", "past 134 dp: full")
        compare(s2r.decide(50, -1700), "revealed", "fast fling: full")
        // a drag that starts in the excluded edge does nothing
        mousePress(s2r, 20, 75)
        mouseMove(s2r, 0, 75, 10, Qt.LeftButton)
        mouseRelease(s2r, 0, 75)
        compare(s2r.offset, 0, "edge start ignored while covered")
        // partial reveal
        mousePress(s2r, 300, 75)
        for (var x = 290; x >= 30; x -= 20) { mouseMove(s2r, x, 75, 10, Qt.LeftButton); wait(16) }
        compare(s2r.state_, "revealing", "partial reveal reached during the drag")
        wait(200)
        mouseRelease(s2r, 30, 75)
        wait(400)
        if (s2r.state_ === "revealing")
            near(s2r.offset, -s2r.revealingOffset, 0.5, "settles at the partial anchor")
        else
            verify(s2rCleared, "or cleared")
        s2r.reset()
        s2rCleared = false
        s2r.settle("revealed")
        wait(400)
        compare(s2r.offset, -344, "full reveal covers the width")
        verify(s2rCleared, "full reveal clears the card")
        s2r.reset()
        s2r.swipeEnabled = false
        mousePress(s2r, 300, 75)
        mouseMove(s2r, 100, 75, 10, Qt.LeftButton)
        mouseRelease(s2r, 100, 75)
        compare(s2r.offset, 0, "not swipeable when disabled")
    }

    function test_application() {
        var app = Qt.createQmlObject('import QtQuick; import org.asteroid.controls; Application { width: 384; height: 384 }', tc)
        verify(app !== null, "Application created")
        compare(app.leftIndicVisible, false, "no left edge hint (stock app screens)")
        compare(app.topIndicVisible, false, "no top edge hint")
        compare(app._asteroidAppRoot, true, "marks itself for the position indicator")
        app.scrollFlickable = saList
        compare(app.children.length > 0, true, "has content")
        app.destroy()
    }

    // ---- Edge hints and tokens (controls-components-26, design-tokens-17) ----
    function test_tokens() {
        compare(Theme.alpha.pressed, 0.10, "ripple alpha token")
        compare(Theme.shape.large, 52, "CornerLarge token")
        compare(Theme.size.button, 104, "52 dp rows = 104 px")
    }
}
