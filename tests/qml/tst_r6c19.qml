// Copyright (C) 2026 eos
// SPDX-License-Identifier: BSD-3-Clause
//
// R6 C-19: two Developer options readers of the controls (Settings' rows behind their -supported gates):
// - Animator duration scale (/org/asteroidos/developer/animator-duration-scale; stock animator_duration_scale,
//   Animation off .. 10x, 1 by default): Motion.animationScale, so Motion.duration() and springDuration() of every
//   app; Reduce animations still wins (0);
// - Force RTL Layout (/org/asteroidos/developer/force-rtl; stock debug.force_rtl): Theme.rtl, so Application's
//   LayoutMirroring and Theme.layoutDirection mirror every screen whatever the language.
// The rules are pure functions (Motion.scaleFor, Theme.rtlFor) checked here; the keys are the ones Settings writes;
// the image's database has neither key, so the defaults hold (a test writes no dconf: no session bus here).
import QtQuick
import QtTest
import org.asteroid.controls

TestCase {
    name: "R6C19"

    function test_1_animator_scale_rule() {
        compare(Motion.scaleFor(false, 1), 1)
        compare(Motion.scaleFor(false, 0), 0, "Animation off")
        compare(Motion.scaleFor(false, 0.5), 0.5)
        compare(Motion.scaleFor(false, "1.5"), 1.5, "dconf may hold a string")
        compare(Motion.scaleFor(false, 10), 10)
        compare(Motion.scaleFor(false, 20), 10, "at most 10x (stock's largest)")
        compare(Motion.scaleFor(false, -1), 1, "nonsense: 1x")
        compare(Motion.scaleFor(false, "abc"), 1)
        compare(Motion.scaleFor(false, undefined), 1)
        compare(Motion.scaleFor(true, 5), 0, "Reduce animations: off whatever the scale")
    }

    function test_2_animator_scale_reader() {
        compare(Motion._animatorScale.key, "/org/asteroidos/developer/animator-duration-scale")
        compare(Motion.animatorScale, 1, "unset: 1x")
        compare(Motion.animationScale, 1)
        compare(Motion.duration(250), 250)
    }

    function test_3_force_rtl_rule() {
        compare(Theme.rtlFor(false, false), false)
        compare(Theme.rtlFor(false, true), true, "a right to left language")
        compare(Theme.rtlFor(true, false), true, "forced: right to left in any language")
        compare(Theme.rtlFor("true", false), true, "dconf may hold a string")
        compare(Theme.rtlFor("false", false), false)
    }

    function test_4_force_rtl_reader() {
        compare(Theme._forceRtlSetting.key, "/org/asteroidos/developer/force-rtl")
        compare(Theme.forceRtl, false, "unset: off")
        compare(Theme.rtl, Theme.rtlFor(false, Theme._locale.textDirection === Qt.RightToLeft
                                              || Theme.isRtlLanguage(Theme._locale.name)
                                              || Theme.isRtlLanguage(Qt.uiLanguage)))
        compare(Theme.layoutDirection, Theme.rtl ? Qt.RightToLeft : Qt.LeftToRight)
    }
}
