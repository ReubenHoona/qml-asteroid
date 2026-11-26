// WO-61-Q1 N61-01: the Material 2 palette, opt-in per application
// (Theme.materialVersion, Application.materialVersion, Button and
// StatusPage under Material 2). Stock values: the Wear OS 6 emulator
// screens S27-S32 and androidx.wear.compose.material Colors/Typography.
import QtQuick
import QtTest
import org.asteroid.controls

Item {
    id: top
    width: 384
    height: 384

    // black as every Wear OS application screen (the window clears white)
    Rectangle {
        id: host
        anchors.fill: parent
        color: "#000000"
    }

    TestCase {
        id: tc
        name: "Q1a"
        when: windowShown

        function sameColor(a, b, msg) {
            var A = Qt.color(a), B = Qt.color(b)
            verify(Math.abs(A.r - B.r) < 0.004 && Math.abs(A.g - B.g) < 0.004 && Math.abs(A.b - B.b) < 0.004
                   && Math.abs(A.a - B.a) < 0.004, msg + ": " + A + " != " + B + " (a " + A.a + " / " + B.a + ")")
        }
        function differ(a, b) {
            var A = Qt.color(a), B = Qt.color(b)
            return Math.abs(A.r - B.r) > 0.01 || Math.abs(A.g - B.g) > 0.01 || Math.abs(A.b - B.b) > 0.01
        }
        function cleanup() {
            Theme.materialVersion = 3
        }
        function make(src) {
            return Qt.createQmlObject('import QtQuick; import org.asteroid.controls; ' + src, host)
        }

        // Material 3 (the default) is what it was
        function test_01_m3Unchanged() {
            compare(Theme.materialVersion, 3, "default 3")
            var c = Theme.color
            sameColor(c.primary, "#DBE2F9", "M3 primary")
            sameColor(c.primaryDim, "#CDD4EB", "M3 primaryDim")
            sameColor(c.onPrimary, "#383F51", "M3 onPrimary")
            sameColor(c.secondary, "#E0E2EF", "M3 secondary")
            sameColor(c.surfaceContainer, "#2F3036", "M3 surfaceContainer (Settings rows)")
            sameColor(c.surfaceContainerHigh, "#3A3B41", "M3 surfaceContainerHigh")
            sameColor(c.onSurface, "#E8E7EE", "M3 onSurface")
            sameColor(c.onSurfaceVariant, "#CECDD4", "M3 onSurfaceVariant")
            sameColor(c.error, "#FFBEB9", "M3 error")
            sameColor(c.timeText, "#C6C6C6", "M3 time text")
            compare(Theme.type.numeralSmall.weight, 599, "M3 numeralSmall 599")
            compare(Theme.type.numeralMedium.weight, 599, "M3 numeralMedium 599")
            compare(Theme.typeRoles.length, 21, "21 M3 roles")
        }

        // Material 2: every role of the plan's list, the rest static
        function test_02_m2Roles() {
            Theme.materialVersion = 2
            var c = Theme.color
            sameColor(c.primary, "#AECBFA", "M2 primary (S30-b search disc)")
            sameColor(c.primaryDim, "#8AB4F8", "M2 primaryDim = primaryVariant")
            sameColor(c.onPrimary, "#303133", "M2 onPrimary")
            sameColor(c.secondary, "#FDE293", "M2 secondary (S29-b thumb, S28-c Hour)")
            sameColor(c.secondaryDim, "#FDE293", "M2 secondaryDim")
            sameColor(c.onSecondary, "#303133", "M2 onSecondary")
            sameColor(c.surfaceContainerLow, "#303133", "M2 surfaceContainerLow")
            sameColor(c.surfaceContainer, "#303133", "M2 surfaceContainer (S31 chip)")
            sameColor(c.surfaceContainerHigh, "#454648", "M2 surfaceContainerHigh (S29-b segment)")
            sameColor(c.onSurface, "#FFFFFF", "M2 onSurface")
            sameColor(c.onSurfaceVariant, "#DADCE0", "M2 onSurfaceVariant")
            sameColor(c.background, "#000000", "M2 background")
            sameColor(c.onBackground, "#FFFFFF", "M2 onBackground")
            sameColor(c.error, "#EE675C", "M2 error")
            sameColor(c.onError, "#000000", "M2 onError")
            sameColor(c.timeText, "#FFFFFF", "M2 time text")
            // roles Material 2 has none for keep the static palette
            sameColor(c.tertiary, "#D4C7FF", "tertiary static")
            sameColor(c.primaryContainer, "#404759", "primaryContainer static")
            sameColor(c.outline, "#A5A5AC", "outline static")
            compare(Theme.type.numeralSmall.weight, 400, "M2 numeralSmall 400")
            compare(Theme.type.numeralMedium.weight, 400, "M2 numeralMedium 400")
            compare(Theme.type.numeralSmall.axes.wght, 400, "M2 numeralSmall wght 400")
            compare(Theme.type.numeralLarge.weight, 599, "numeralLarge unchanged")
            compare(Theme.type.bodyLarge.weight, 450, "bodyLarge unchanged")
            // the palette itself (androidx.wear.compose.material Colors defaults)
            var p = Theme.m2Palette
            var want = { primary: "#AECBFA", primaryVariant: "#8AB4F8", secondary: "#FDE293",
                         secondaryVariant: "#594F33", background: "#000000", surface: "#303133",
                         error: "#EE675C", onPrimary: "#303133", onSecondary: "#303133",
                         onBackground: "#FFFFFF", onSurface: "#FFFFFF", onSurfaceVariant: "#DADCE0",
                         onError: "#000000" }
            for (var k in want)
                sameColor(p[k], want[k], "m2Palette." + k)
            compare(Object.keys(p).length, 13, "13 palette entries")
            // the Material 2 type roles
            compare(Theme.m2TypeRoles.length, 12, "12 M2 roles")
            compare(Theme.type.body1.pixelSize, 32, "body1 16 sp")
            compare(Theme.type.body1.lineHeight, 40, "body1 20 sp line")
            compare(Theme.type.body1.weight, 400, "body1 Normal")
            fuzzyCompare(Theme.type.body1.letterSpacing, 0.36, 0.001, "body1 0.18 sp")
            compare(Theme.type.caption1.weight, 500, "caption1 Medium")
            compare(Theme.type.button.weight, 700, "button Bold")
            // back to 3: the static palette again
            Theme.materialVersion = 3
            sameColor(c.surfaceContainer, "#2F3036", "back to M3 surfaceContainer")
            sameColor(c.primary, "#DBE2F9", "back to M3 primary")
            sameColor(c.timeText, "#C6C6C6", "back to M3 time text")
            compare(Theme.type.numeralSmall.weight, 599, "back to 599")
        }

        // D60-38: the Color theme is not applied under Material 2
        function test_03_colorThemeSkipped() {
            Theme._colorSourceValue = "preset"
            Theme._colorSeedValue = "#FF6F7F"
            Theme._colorStyleValue = ""
            verify(differ(Theme.color.primary, "#DBE2F9"), "Peony themes an M3 app: " + Theme.color.primary)
            Theme.materialVersion = 2
            sameColor(Theme.color.primary, "#AECBFA", "M2 app ignores Peony")
            sameColor(Theme.color.surfaceContainer, "#303133", "M2 surface under Peony")
            Theme._colorSeedValue = "#6F9BFF"
            sameColor(Theme.color.primary, "#AECBFA", "M2 app ignores a theme change")
            Theme.materialVersion = 3
            verify(differ(Theme.color.primary, "#DBE2F9") && differ(Theme.color.primary, "#AECBFA"),
                   "back to M3: the Indigo theme applies: " + Theme.color.primary)
            Theme._colorSourceValue = "static"
            Theme._colorSeedValue = ""
            sameColor(Theme.color.primary, "#DBE2F9", "No theme again")
        }

        // Application.materialVersion is written to Theme on construction
        function test_04_application() {
            var app = make('Application { width: 384; height: 384; materialVersion: 2 }')
            compare(app.materialVersion, 2)
            compare(Theme.materialVersion, 2, "written to Theme")
            sameColor(Theme.color.surfaceContainer, "#303133", "M2 surface in the app")
            app.materialVersion = 3
            compare(Theme.materialVersion, 3, "follows a change")
            app.destroy()
            wait(0)
            var app3 = make('Application { width: 384; height: 384 }')
            compare(app3.materialVersion, 3, "default 3")
            compare(Theme.materialVersion, 3)
            app3.destroy()
        }

        // Button: M2 icons and second lines take the content colour (S31, S29-b)
        function test_05_button() {
            var b = make('Button { width: 344; variant: "tonal"; iconName: "ios-star"; text: "Favorites"; secondaryText: "One time" }')
            sameColor(b.containerColor, "#2F3036", "M3 tonal container")
            sameColor(b.contentColor, "#E8E7EE", "M3 tonal label")
            sameColor(b.iconColor, "#DBE2F9", "M3 tonal icon primary")
            // N61-07: the Wear OS 6 emulator draws a tonal row's second line in primary
            sameColor(b.secondaryContentColor, "#DBE2F9", "M3 tonal second line primary (N61-07)")
            Theme.materialVersion = 2
            sameColor(b.containerColor, "#303133", "M2 chip #303133")
            sameColor(b.contentColor, "#FFFFFF", "M2 label white")
            sameColor(b.iconColor, "#FFFFFF", "M2 icon white (S31 star)")
            sameColor(b.secondaryContentColor, "#FFFFFF", "M2 second line white (S29-b One time)")
            sameColor(b.label.color, "#FFFFFF", "drawn label")
            sameColor(b.secondaryLabel.color, "#FFFFFF", "drawn second line")
            b.enabled = false
            sameColor(b.iconColor, b.contentColor, "M2 disabled icon = content")
            sameColor(b.secondaryContentColor, b.contentColor, "M2 disabled second line = content")
            b.enabled = true
            b.variant = "filled"
            sameColor(b.containerColor, "#AECBFA", "M2 filled primary")
            sameColor(b.iconColor, "#303133", "M2 filled icon onPrimary")
            sameColor(b.secondaryContentColor, "#303133", "M2 filled second line onPrimary")
            b.destroy()
        }

        function inkRows(img, x0, x1, y0, y1) {
            var rows = []
            for (var y = y0; y < y1; y++) {
                var ink = false
                for (var x = x0; x < x1 && !ink; x += 1) {
                    var p = img.pixel(x, y)
                    if (p.r + p.g + p.b > 1.2)
                        ink = true
                }
                if (ink)
                    rows.push(y)
            }
            var groups = []
            for (var i = 0; i < rows.length; i++) {
                if (groups.length > 0 && rows[i] === groups[groups.length - 1][1] + 1)
                    groups[groups.length - 1][1] = rows[i]
                else
                    groups.push([rows[i], rows[i]])
            }
            return groups
        }

        // StatusPage: M2 status text white body1 (S30: 23 px cap, 40 px pitch)
        function test_06_statusPage() {
            var s = make('StatusPage { text: "No contacts could be found" }')
            sameColor(s.label.color, "#CECDD4", "M3 message onSurfaceVariant")
            compare(s.label.font.pixelSize, 28, "M3 bodyMedium 14 sp")
            Theme.materialVersion = 2
            sameColor(s.label.color, "#FFFFFF", "M2 message white")
            sameColor(s.iconItem.color, "#FFFFFF", "M2 icon white")
            compare(s.label.font.pixelSize, 32, "M2 body1 16 sp")
            compare(s.label.lineHeight, 40, "M2 20 sp line")
            compare(s.label.font.weight, 400, "M2 weight 400")
            waitForRendering(s)
            var img = grabImage(top)
            var g = inkRows(img, 40, 344, 100, 300)
            console.log("Q1a status M2 ink rows " + JSON.stringify(g) + " lines " + s.label.lineCount)
            verify(g.length >= 2, "two lines")
            compare(g[1][0] - g[0][0], 40, "40 px line pitch (S30 166 -> 206)")
            verify(Math.abs((g[0][1] - g[0][0] + 1) - 24) <= 2, "line ink 24 +/- 2 px (S30 166-189)")
            Theme.materialVersion = 3
            compare(s.label.font.pixelSize, 28, "back to M3")
            compare(s.label.font.weight, Theme.type.bodyMedium.weight, "back to the M3 weight")
            s.destroy()
        }
    }
}
