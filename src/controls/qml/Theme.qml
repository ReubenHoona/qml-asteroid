/*
 * Copyright (C) 2026 Reuben Horner
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
pragma Singleton

import QtQuick
import QtQuick.Window
import Nemo.Configuration
import org.asteroid.utils

/*!
    \qmltype Theme
    \inqmlmodule org.asteroid.controls

    \brief One source of the Wear OS (Material 3) design tokens: type,
    colour, state alphas, shapes, spacing, component sizes and round-screen
    margins.

    The values are those of the Pixel Watch 2 system build CP3A (Settings
    and system UI build the same MaterialTheme), in pixels for the current
    screen: write sizes as \c{Theme.dp(x)} and text as \c{Theme.sp(x)} so the
    "Display size & text" settings (display size, font size, bold text)
    apply everywhere.

    \list
    \li \c{Theme.type.<role>}: the 21 type roles, each
        {pixelSize, lineHeight, weight, width, roundness, opsz,
         letterSpacing, letterSpacingBottom, axes}; Label binds them through
         its \c role property.
    \li \c{Theme.color.<role>}: plain \c color properties, so a colour theme
        can replace them live. The values are stock's "No theme".
    \li \c{Theme.alpha.*}, \c{Theme.shape.*}, \c{Theme.space.*},
        \c{Theme.size.*}, \c{Theme.margin.*}.
    \endlist

    Dims stays for upstream and third-party applications.
*/
QtObject {
    id: theme

    /* ---- Density and scale (Settings > Display > Display size & text) ---- */

    // Wear OS screens are laid out in dp; the Pixel Watch 2 screen is
    // 192 dp wide (384 px at 320 dpi = 2.0 px per dp). Other screens keep
    // the same layout by scaling to their shortest side.
    readonly property real _screenPx: {
        var w = Screen.desktopAvailableWidth
        var h = Screen.desktopAvailableHeight + DeviceSpecs.flatTireHeight
        var m = Math.min(w, h)
        return m > 0 ? m : 384
    }
    /*! The automatic density in px per dp: 2.0 on the Pixel Watch 2. */
    readonly property real autoDensity: _screenPx / 192
    /*!
        The "Display size" steps in px per dp, smallest to default: 284, 301
        and 320 dpi on the Pixel Watch 2 (DisplaySizeCalculator).
    */
    readonly property var densitySteps: [1.775, 1.881, 2.0]
    /*!
        The "Font size" steps (arrays.xml text_size_entries): Small, Default,
        Medium, Large, Larger, Largest.
    */
    readonly property var fontScaleSteps: [0.94, 1.0, 1.06, 1.12, 1.18, 1.24]
    /*! Bold text adds this to every weight (font_weight_adjustment), cap 1000. */
    readonly property int boldWeightAdjustment: 300

    property ConfigurationValue _densitySetting: ConfigurationValue {
        key: "/org/asteroidos/ux/display-density"
        defaultValue: 0
    }
    property ConfigurationValue _fontScaleSetting: ConfigurationValue {
        key: "/org/asteroidos/ux/font-scale"
        defaultValue: 1.0
    }
    property ConfigurationValue _boldSetting: ConfigurationValue {
        key: "/org/asteroidos/ux/bold-text"
        defaultValue: false
    }

    // the raw key values (tests replace these instead of writing dconf)
    property var _densityValue: _densitySetting.value
    property var _fontScaleValue: _fontScaleSetting.value
    property var _boldValue: _boldSetting.value

    /*! Pixels per dp: the display-density key, 0 (default) = automatic. */
    readonly property real density: {
        var d = Number(_densityValue)
        return (d > 0.5 && d < 8) ? d : autoDensity
    }
    /*! The font scale (1.0 by default). */
    readonly property real fontScale: {
        var s = Number(_fontScaleValue)
        return (s >= 0.5 && s <= 3) ? s : 1.0
    }
    /*! Bold text is on. */
    readonly property bool boldText: _boldValue === true || _boldValue === "true"
    /*! Added to every type weight: 0, or 300 with Bold text. */
    readonly property int weightAdjust: boldText ? boldWeightAdjustment : 0

    /*! Returns \a x dp in pixels. */
    function dp(x: real): real { return x * density }
    /*! Returns \a x sp in pixels (dp times the font scale). */
    function sp(x: real): real { return x * density * fontScale }
    /*! A type weight with the Bold text adjustment, capped at 1000. */
    function weight(w: int): int { return Math.min(1000, w + weightAdjust) }

    /*! The screen in dp. */
    readonly property real screenWidthDp: Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth / density : 192
    readonly property real screenHeightDp: (Screen.desktopAvailableHeight + DeviceSpecs.flatTireHeight) > 0
                                           ? (Screen.desktopAvailableHeight + DeviceSpecs.flatTireHeight) / density : 192
    /*! Wear OS treats screens 225 dp and wider as large (materialcore ResourcesKt.java:10-15). */
    readonly property bool isLargeScreen: screenWidthDp >= 225

    /* ---- Typography ---- */

    /*!
        The system font family. Stock uses Google Sans Flex (never copied
        from the firmware); until an open-licence flex font is installed
        this is the image's Noto Sans.
    */
    property string fontFamily: "Noto Sans"

    /*! OpenType features for numbers that change (timers, pickers): tabular digits. */
    readonly property var tabularNumerals: ({ "tnum": 1 })

    /*
     * The CP3A type scale in sp: size, line height, weight, width (wdth),
     * tracking (top, bottom for the curved roles). Roundness (ROND) is 100
     * on every role and opsz follows the size.
     * Settings v2 ui/theme/tokens/TypeScaleTokens.java:83-213,
     * TypeVariationTokens.java:33-53; PixelWatchSysUi mmo.java:135-265.
     */
    readonly property var _typeScale: ({
        displayLarge:      [40, 44, 450, 100, 0,   0],
        displayMedium:     [30, 34, 500, 100, 0,   0],
        displaySmall:      [24, 26, 500, 100, 0,   0],
        titleLarge:        [18, 20, 500, 100, 0,   0],
        titleMedium:       [16, 18, 550, 100, 0.2, 0.2],
        titleSmall:        [14, 16, 550, 100, 0.4, 0.4],
        labelLarge:        [20, 22, 500, 100, 0.4, 0.4],
        labelMedium:       [15, 18, 500,  90, 0.4, 0.4],
        labelSmall:        [13, 16, 500,  84, 0.4, 0.4],
        bodyLarge:         [16, 18, 450,  90, 0.4, 0.4],
        bodyMedium:        [14, 16, 450,  90, 0.4, 0.4],
        bodySmall:         [12, 14, 500,  86, 0.4, 0.4],
        bodyExtraSmall:    [10, 12, 500,  84, 0.4, 0.4],
        numeralExtraLarge: [60, 60, 550, 100, 0,   0],
        numeralLarge:      [50, 50, 599, 100, 0,   0],
        numeralMedium:     [40, 40, 599, 100, 0,   0],
        numeralSmall:      [30, 30, 599, 100, 0,   0],
        numeralExtraSmall: [24, 24, 550, 100, 0,   0],
        arcLarge:          [18, 22, 599, 100, 0.4, 1.6],
        arcMedium:         [15, 18, 599,  90, 0.6, 1.4],
        arcSmall:          [14, 16, 550,  90, 0.6, 1.4]
    })

    /*! The names of the 21 type roles. */
    readonly property var typeRoles: Object.keys(_typeScale)

    /*!
        The type roles in pixels for the current density, font scale and
        Bold text: \c{Theme.type.bodyLarge.pixelSize} and so on.
    */
    readonly property var type: {
        var out = {}
        var k = density * fontScale
        var adj = weightAdjust
        for (var name in _typeScale) {
            var r = _typeScale[name]
            var w = Math.min(1000, r[2] + adj)
            out[name] = {
                pixelSize: r[0] * k,
                lineHeight: r[1] * k,
                weight: w,
                width: r[3],
                roundness: 100,
                opsz: r[0],
                letterSpacing: r[4] * k,
                letterSpacingBottom: r[5] * k,
                axes: { "wght": w, "wdth": r[3], "ROND": 100, "opsz": r[0] }
            }
        }
        return out
    }

    /* ---- Colour roles: stock "No theme" (AndroidOverlayPixelWatch) ---- */

    /*!
        The static palette (GoogleMaterialThemeKt.java:47-77 reading the
        Pixel overlay's system colours). Surfaces that are never themed
        (the power menu, config_customGlobalActionColors) read these.
    */
    readonly property var staticPalette: ({
        primary: "#DBE2F9",
        primaryDim: "#CDD4EB",
        primaryContainer: "#404759",
        onPrimary: "#383F51",
        onPrimaryContainer: "#D9E0F7",
        secondary: "#E0E2EF",
        secondaryDim: "#D1D4E1",
        secondaryContainer: "#434751",
        onSecondary: "#3C3F49",
        onSecondaryContainer: "#DDDFED",
        tertiary: "#D4C7FF",
        tertiaryDim: "#C6B8F9",
        tertiaryContainer: "#B8ABEB",
        onTertiary: "#352960",
        onTertiaryContainer: "#2A1E55",
        surfaceContainerLow: "#24262B",
        surfaceContainer: "#2F3036",
        surfaceContainerHigh: "#3A3B41",
        onSurface: "#E8E7EE",
        onSurfaceVariant: "#CECDD4",
        outline: "#A5A5AC",
        outlineVariant: "#85858C",
        background: "#000000",
        onBackground: "#FFFFFF",
        error: "#FFBEB9",
        errorDim: "#EA8C87",          // inferred (design-tokens AUDIT 5.1.3)
        errorContainer: "#77302E",
        onError: "#3C0507",
        onErrorContainer: "#FFD7D4"
    })

    /*! The colour roles; plain properties so a colour theme can rebind them. */
    property QtObject color: QtObject {
        property color primary: theme.staticPalette.primary
        property color primaryDim: theme.staticPalette.primaryDim
        property color primaryContainer: theme.staticPalette.primaryContainer
        property color onPrimary
        property color onPrimaryContainer
        property color secondary: theme.staticPalette.secondary
        property color secondaryDim: theme.staticPalette.secondaryDim
        property color secondaryContainer: theme.staticPalette.secondaryContainer
        property color onSecondary
        property color onSecondaryContainer
        property color tertiary: theme.staticPalette.tertiary
        property color tertiaryDim: theme.staticPalette.tertiaryDim
        property color tertiaryContainer: theme.staticPalette.tertiaryContainer
        property color onTertiary
        property color onTertiaryContainer
        property color surfaceContainerLow: theme.staticPalette.surfaceContainerLow
        property color surfaceContainer: theme.staticPalette.surfaceContainer
        property color surfaceContainerHigh: theme.staticPalette.surfaceContainerHigh
        property color onSurface
        property color onSurfaceVariant
        property color outline: theme.staticPalette.outline
        property color outlineVariant: theme.staticPalette.outlineVariant
        property color background: theme.staticPalette.background
        property color onBackground
        property color error: theme.staticPalette.error
        property color errorDim: theme.staticPalette.errorDim
        property color errorContainer: theme.staticPalette.errorContainer
        property color onError
        property color onErrorContainer

        /*! Default text (LocalContentColor): white. */
        property color content: "#FFFFFF"
        /*! Icons in tonal buttons and rows (FilledTonalButtonTokens.java:23). */
        property color icon: primary
        /*! Time text: onBackground at tone 80 (TimeTextDefaults.java:16-20; inferred +/-1). */
        property color timeText: "#C6C6C6"
        /*! The scrim behind the time text: black at 0.85 (TimeTextKt.java:89-90). */
        property color timeTextScrim: Qt.rgba(0, 0, 0, 0.85)
        /*! Scroll indicator thumb / track: tone 80 / tone 20 (ScrollIndicatorKt.java:269-273). */
        property color scrollThumb: "#C6C6C6"
        property color scrollTrack: "#303030"
        /*! Slider track on a surface: black 30 % over surfaceContainer (SliderTokens). */
        property color sliderTrackOnSurface: "#212226"
        /*! The quick settings battery button while Battery Saver is on. */
        property color batterySaver: "#FEE170"
        /*! Phone call buttons and their glyphs (Phone 164.0; calls E09). A
            property named onCallAnswer does not compile in Qt 6.11 (read as a
            signal handler), so the glyph colours are *Content. */
        property color callDecline: "#EC928E"
        property color callDeclineContent: "#410E0B"
        property color callAnswer: "#93E5C3"
        property color callAnswerContent: "#003828"
        property color callOption: "#72E5BA"
        /*! The power menu keeps the static palette, never themed. */
        readonly property var powerMenu: theme.staticPalette

        // A declared property on<X> next to a property <x> does not take an
        // initial value in Qt 6.11 (read as a handler for <x>), so the
        // on* roles are set here.
        Component.onCompleted: {
            onPrimary = theme.staticPalette.onPrimary
            onPrimaryContainer = theme.staticPalette.onPrimaryContainer
            onSecondary = theme.staticPalette.onSecondary
            onSecondaryContainer = theme.staticPalette.onSecondaryContainer
            onTertiary = theme.staticPalette.onTertiary
            onTertiaryContainer = theme.staticPalette.onTertiaryContainer
            onSurface = theme.staticPalette.onSurface
            onSurfaceVariant = theme.staticPalette.onSurfaceVariant
            onBackground = theme.staticPalette.onBackground
            onError = theme.staticPalette.onError
            onErrorContainer = theme.staticPalette.onErrorContainer
        }
    }

    /* ---- State alphas ---- */

    property QtObject alpha: QtObject {
        /*! Disabled content: onSurface at 0.38 (FilledTonalButtonTokens). */
        readonly property real disabledContent: 0.38
        /*! Disabled container: onSurface at 0.12. */
        readonly property real disabledContainer: 0.12
        /*! Pressed ripple of the content colour (RippleAlpha, RippleKt.java:16). */
        readonly property real pressed: 0.10
        readonly property real focus: 0.10
        readonly property real hover: 0.08
        readonly property real drag: 0.16
        /*! Secondary label on a filled button (FilledButtonTokens). */
        readonly property real secondaryOnFilled: 0.8
        /*! Secondary label on a checked switch row (SwitchButtonTokens). */
        readonly property real secondaryOnChecked: 0.9
        /*! Slider unselected bar (SliderTokens). */
        readonly property real sliderUnselected: 0.3
        /*! Unselected page dots and the page indicator band (PageIndicator.kt). */
        readonly property real pageDotUnselected: 0.3
        readonly property real pageIndicatorBand: 0.85
        /*! Time text scrim (TimeTextKt.java:90). */
        readonly property real timeTextScrim: 0.85
    }

    /* ---- Shapes (ShapeTokens.java:11-17), px ---- */

    property QtObject shape: QtObject {
        readonly property real none: 0
        readonly property real extraSmall: theme.dp(4)
        readonly property real small: theme.dp(8)
        readonly property real medium: theme.dp(18)
        readonly property real large: theme.dp(26)
        readonly property real extraLarge: theme.dp(36)
        /*! Windows are cut to the screen circle (WearMixedTransitionHandler.java:75). */
        readonly property real window: Math.min(Screen.desktopAvailableWidth, Screen.desktopAvailableHeight + DeviceSpecs.flatTireHeight) / 2
        /*! CornerFull: a pill or circle of height \a h. */
        function full(h: real): real { return h / 2 }
        /*! A corner of \a r capped at a pill of height \a h (Compose clamps corners). */
        function clamp(r: real, h: real): real { return Math.min(r, h / 2) }
    }

    /* ---- Spacing (px) ---- */

    property QtObject space: QtObject {
        readonly property real xxs: theme.dp(2)   // time text outer padding (TimeTextDefaults.java:16)
        readonly property real xs: theme.dp(4)    // list item gap (ScalingLazyColumnKt.java:167)
        readonly property real s: theme.dp(6)     // icon to label; button vertical padding (ButtonDefaults.java:21,33)
        readonly property real m: theme.dp(8)     // sub-header bottom
        readonly property real l: theme.dp(12)    // header bottom; category top
        readonly property real xl: theme.dp(14)   // button and header horizontal padding
        readonly property real xxl: theme.dp(16)  // header top
    }

    /* ---- Component sizes (px) ---- */

    property QtObject size: QtObject {
        readonly property real button: theme.dp(52)            // FilledButtonTokens.java:7
        readonly property real listHeader: theme.dp(48)        // ListHeaderTokens
        readonly property real cardMin: theme.dp(64)           // CardTokens.kt
        readonly property real iconButton: theme.dp(52)        // IconButtonDefaults.java:18
        readonly property real iconButtonSmall: theme.dp(48)
        readonly property real iconButtonExtraSmall: theme.dp(32)
        readonly property real iconButtonLarge: theme.dp(60)
        readonly property real icon: theme.dp(26)              // FilledButtonTokens.java:31-33
        readonly property real iconSmall: theme.dp(24)         // settings_list_icon_size
        readonly property real iconLarge: theme.dp(32)
        readonly property real iconExtraLarge: theme.dp(36)
        readonly property real touchMin: theme.dp(48)

        // EdgeButton (EdgeButtonKt.java:147,274-276; ShapeHelper.java:28-31,52)
        readonly property real edgeButtonExtraSmall: theme.dp(46)
        readonly property real edgeButtonSmall: theme.dp(56)
        readonly property real edgeButtonMedium: theme.dp(70)
        readonly property real edgeButtonLarge: theme.dp(96)
        readonly property real edgeButton: edgeButtonSmall
        readonly property real edgeButtonBottomGap: theme.dp(3)
        readonly property real edgeButtonSideMargin: theme.dp(20)
        /*! Height of the outline ellipse for an edge button of height \a h px. */
        function edgeButtonOutlineHeight(h: real): real {
            return theme.dp(58) + 1.42 * (h - theme.dp(46))
        }

        // SwitchButton (SwitchButtonKt.java:144,160)
        readonly property real switchTrackWidth: theme.dp(32)
        readonly property real switchTrackHeight: theme.dp(22)
        readonly property real switchTrackBorder: theme.dp(2)
        readonly property real switchThumbOff: theme.dp(12)
        readonly property real switchThumbOn: theme.dp(18)
        readonly property real switchTickStroke: theme.dp(2)

        // RadioButton (RadioButtonKt.java:348-352,423)
        readonly property real radio: theme.dp(20)
        readonly property real radioStroke: theme.dp(2)
        readonly property real radioDot: theme.dp(10)

        // Slider (SliderKt, SliderTokens)
        readonly property real slider: theme.dp(52)
        readonly property real sliderButtonWidth: theme.dp(48)
        readonly property real sliderSelectedBar: theme.dp(12)
        readonly property real sliderUnselectedBar: theme.dp(4)
        readonly property real sliderStepDot: theme.dp(4)

        // Scroll indicator (ScrollIndicatorDefaults.java:10-13)
        readonly property real scrollIndicatorEdgeGap: theme.dp(2)
        readonly property real scrollIndicatorLength: theme.dp(50)
        readonly property real scrollIndicatorWidth: theme.dp(5)
        readonly property real scrollIndicatorGap: theme.dp(3)
        readonly property real scrollThumbMin: 0.3
        readonly property real scrollThumbMax: 0.7

        // Page indicator (PageIndicator.kt)
        readonly property real pageDot: theme.dp(6)
        readonly property real pageDotSpacing: theme.dp(4)
        readonly property int pageDotsMax: 6
        readonly property real pageDotEndScale: 0.66
        readonly property real pageIndicatorBand: theme.dp(12)
        readonly property real pageIndicatorEdge: theme.dp(8)

        /*! TimeText sweep, degrees (TimeTextKt.java:130). */
        readonly property real timeTextSweep: 70
        /*! Status icon disc at the top centre. */
        readonly property real statusIcon: theme.dp(18)
        /*! Watch face complication bulb: 86 dp circle, 8 dp ring, 61 degree gap. */
        readonly property real complicationBulb: theme.dp(86)
        readonly property real complicationBulbRing: theme.dp(8)
        readonly property real complicationBulbGap: 61
        /*! App icon on a tile, 3 dp from the top. */
        readonly property real tileAppIcon: theme.dp(24)
        readonly property real tileAppIconTop: theme.dp(3)
    }

    /* ---- Round-screen margins: fractions of the screen ---- */

    property QtObject margin: QtObject {
        readonly property real _w: theme.screenWidthDp
        readonly property real _h: theme.screenHeightDp
        /*! Scaffold sides: ceil(5.2 % of the width in dp) (ScreenScaffoldKt.java:396). */
        readonly property real side: theme.dp(Math.ceil(0.052 * _w))
        /*! Scaffold top and bottom: ceil(10 % of the height in dp) (ScreenScaffoldKt.java:397). */
        readonly property real scaffoldVertical: theme.dp(Math.ceil(0.10 * _h))
        /*! Settings list (CustomDimensions.java:22-26). */
        readonly property real listTop: theme.dp(0.1664 * _h)
        readonly property real listBottom: theme.dp(0.3646 * _h)
        readonly property real listSide: theme.dp(0.052 * _w)
        readonly property real titleSide: theme.dp(0.12 * _w)
        readonly property real subtitleSide: theme.dp(0.0416 * _w)
        /*! Dialogs (AlertDialogDefaults.java:40-70). */
        readonly property real dialogTop: theme.dp(Math.ceil(0.10 * _h))
        readonly property real dialogTopWithIcon: theme.dp(Math.ceil(0.012 * _h))
        readonly property real dialogSide: theme.dp(Math.ceil(0.052 * _w))
        readonly property real dialogBottomNoEdgeButton: theme.dp(Math.ceil(0.3646 * _h))
        /*! App list top gap (app-launcher-03). */
        readonly property real launcherTop: theme.dp(0.13 * _h)
    }
}
