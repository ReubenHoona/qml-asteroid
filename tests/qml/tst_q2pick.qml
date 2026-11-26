// Review follow-up (Q3 area): PickerGroup's columns end 61 dp over the
// bottom (52 dp round button + 9 dp) whenever the round confirm button is
// used, also in a Material 3 picker that asks for it; the edge button
// margin otherwise.
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    PickerGroup { id: m3; anchors.fill: parent; visible: false }
    PickerGroup { id: m3round; anchors.fill: parent; visible: false; roundConfirm: true }

    TestCase {
        name: "Q2pick"
        when: windowShown

        function cleanup() {
            Theme.materialVersion = 3
        }
        function test_01_marginFollowsTheButton() {
            var edge = m3.sectionPadding + m3.buttonHeight + Theme.size.edgeButtonBottomGap
            compare(m3.roundConfirm, false, "Material 3: the edge button")
            compare(m3.columnsBottomMargin, edge, "clear of the edge button")
            compare(m3round.roundConfirm, true)
            compare(m3round.columnsBottomMargin, Theme.dp(61), "Material 3 with the round button: 52 + 9 dp")
            verify(m3round.columnsBottomMargin !== edge)
            Theme.materialVersion = 2
            compare(m3.roundConfirm, true, "Material 2: the round button")
            compare(m3.columnsBottomMargin, Theme.dp(61), "Material 2: 61 dp as before")
            m3.roundConfirm = false
            compare(m3.columnsBottomMargin, edge, "Material 2 without the round button: the edge button's")
        }
    }
}
