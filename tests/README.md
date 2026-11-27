# qml-asteroid tests

The tests that pin down how the controls (`org.asteroid.controls`) look and behave: QML tests in
`tests/qml`, run with `qmltestrunner`, and three C++ tests (`tests/crownspeed`, `tests/flatmesh`,
`tests/dateformat`, the last one of org.asteroid.utils' DateFormat). They run without a watch, under
qemu-aarch64 against a copy of an image rootfs, with the controls plugin cross-built from this
checkout.

## Running

```sh
R=<rootfs copy> QEMU=<qemu-aarch64> XSYSROOT=<aarch64 sysroot> SYSROOTS=<sysroots-components> \
CONTACTS=<org.asteroid.contacts tree> tests/run-qemu.sh              # everything
... tests/run-qemu.sh tst_q3row.qml                                   # one file (or tst_q3row)
... tests/run-qemu.sh tst_q2edge tst_q2head flatmesh                  # some
... tests/run-qemu.sh path/to/tst_other.qml                           # a test from elsewhere
```

`run-qemu.sh` cross-builds the plugin into `build/qemu-tests` (incremental; git ignores `build/`),
stages an overlay with this checkout's `org.asteroid.controls` (the plugin and `src/controls/qml`)
before the rootfs imports, runs each file and prints one line per file and a grand total:

```
tst_q3row.qml: 10 passed, 0 failed, 0 skipped, loops 0
...
Total: N passed, 0 failed, 0 skipped, 0 binding-loop warnings in M files (logs: build/qemu-tests/logs)
```

The exit status is 1 when a test failed, a file gave no totals (a crash or `TMO`) or logged a
binding loop. Failures are shown under their file (`FAILS=` lines); full logs stay in
`build/qemu-tests/logs/<test>.txt`. The rootfs and the checkout are only read; the overlay, the
patched plugins and the pictures the tests save live in a fresh `/tmp/qXXXXX` folder that is removed
at the end (`KEEP=1` keeps it, `SHOTS=<dir>` keeps the pictures).

| Variable | |
|---|---|
| `R` | the rootfs copy, given to `qemu -L` (required). `tests/qemu/copy-rootfs.sh SRC DST` makes one: it waits while a bitbake runs and checks the copy. |
| `QEMU` | the qemu-aarch64 user-mode binary (required) |
| `XSYSROOT` | an aarch64 sysroot with the Qt 6 headers, libraries and metatypes of the image's Qt; its `usr/bin/qmltestrunner` runs the QML tests |
| `SYSROOTS` | the OE build's `tmp/sysroots-components` (cross gcc and binutils, moc, qmltyperegistrar, the Wayland scanners; qtsvg, mlite, wayland, mesa) |
| `XB` | use the `libasteroidcontrolsplugin.so` and `plugins.qmltypes` in this dir instead of building (then `SYSROOTS` is not needed for the QML tests) |
| `BUILD` | build and log dir (default `build/qemu-tests`) |
| `QMLTESTRUNNER` | default `$XSYSROOT/usr/bin/qmltestrunner` |
| `CONTACTS` | an `org.asteroid.contacts` tree, for `tst_q4contacts.qml`; without it that file is skipped (and named as not run) |
| `ICONS=1` | the rootfs icons for every file, not only those that ask for them |
| `TMO` | seconds per file (default 900) |

### What the environment needs

- The rootfs of an eos image built from the same Qt as `XSYSROOT`: QtTest (`usr/lib/qml/QtTest`,
  `libQt6QuickTest`), the offscreen platform plugin, Nemo.Configuration and the image's dconf
  defaults (the crown as the image sets it: crown-fast, 7.5 px per count), org.asteroid.utils, the
  Noto Sans static faces and the asteroid icons.
- python3 on the host (the plugin path patches).
- The plugins read `/etc/asteroid/machine.conf` and the controls `/usr/share/icons/asteroid/`
  themselves, which `qemu -L` does not redirect for them; `run-qemu.sh` patches those paths in copies
  of the plugins to the run folder (a path of the same length, hence the 11-character `/tmp/qXXXXX`).
- A test file asks for more with a line `// run-qemu: WORD ...`:
  `icons` (the controls draw the rootfs icons: `tst_fpq1.qml`, the equivalent of the harness's
  `ICONS=1`), `mocks` (`tests/qml/mocks` first in the import path: the Nemo.DBus double and
  VoiceTest), `contacts` (`CONTACTS=`: the contacts tree beside the test, its QML as
  `org.asteroid.contacts` with its ContactStore double and its test mocks).
- Real time: the tests run at the emulator's speed; the timing checks have room for a loaded host
  (`tst_q3row.qml`'s mid-spring check is bounded for that), but a very busy host can still make one
  late.

The C++ tests also build on the host with their own CMakeLists.txt (Qt 6 Quick and Test for
`tests/flatmesh`, Qt 6 Core and Test and ICU for `tests/dateformat`, nothing for `tests/crownspeed`):

```sh
cmake -S tests/flatmesh -B build/flatmesh && cmake --build build/flatmesh && \
  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software build/flatmesh/tst_flatmesh
cmake -S tests/crownspeed -B build/crownspeed && cmake --build build/crownspeed && build/crownspeed/tst_crownspeed
cmake -S tests/dateformat -B build/dateformat && cmake --build build/dateformat && build/dateformat/tst_dateformat
```

## What each file covers

Names follow the work orders they came from: `tst_qN*` WO-61-QN (the Wear OS 6 look), `tst_wo03`,
`tst_wo09` the image 60 defect lists, `tst_fpq*` FP-Q1/Q2, `tst_v*` and `tst_qvcache` the verifier's
independent checks. Stock numbers in the tests are measured on the Wear OS 6 emulator (S/M/V screens).

| File | Covers |
|---|---|
| `tst_controls.qml` | the Material 3 component set: density, buttons and ripples, switch/radio/checkbox rows, list items and rows, selectors, headers, cards, edge button, progress indicators, stepper, position and page indicators, scroll-away, text field, SwipeToReveal, Application, tokens |
| `tst_motion.qml` | the spring engine and motion tokens, the back gesture (BackSwipeArea, BorderGestureArea, LayerStack), list physics (fling, stretch), the edge transformation and ScalingList, including the N61-04 packed rows |
| `tst_ux.qml` | crown scrolling and picker stepping (RotaryInput), the ListItem edge effect, the round-edge back swipe with fling, PositionIndicator creation, the LaunchSplash life cycle (`ref/LaunchSplash.qml`) |
| `tst_wo03.qml` | the time text scrolls away under the crown (D60-13), RotaryInput.flashIndicator (D60-09) |
| `tst_wo09.qml` | title face weight (D60-37), LayerStack's round page clip while frames move (D60-34), the AlertDialog info style and the Wear OS 6 two-button confirmation (D60-41, N61-11) |
| `tst_dialogs.qml` | Dialog, AlertDialog, Confirmation (success, failure, open on phone), Toast, StatusPage, with the Wear OS 6 dialog motion (N61-11/12) |
| `tst_q1a.qml` | the Material 2 palette, opt-in per application (Theme/Application.materialVersion, Button and StatusPage under Material 2) (N61-01) |
| `tst_q1b.qml` | TimeText 3 px lower, its Material 2 style, Application.timeTextMargin (N61-02) |
| `tst_vorder.qml` | a Material 2 Application starts in its colours without a start-up colour animation (inline item, ListView delegates) |
| `tst_q2edge.qml` | the packed edge layout: EdgeLayout against `ref/WearEdge.js`, ScalingList, ListItem, ListRow and headers scaling about their edge nearest the centre and closing up (N61-04) |
| `tst_q2head.qml` | ListHeader options (minimumHeight, color), the Wear OS 6 ListSubHeader, Theme.color.caption (N61-05) |
| `tst_q2ind.qml` | the system UI scroll indicator with RotaryInput.systemIndicator, the M3 one in apps and with m3Indicator (N61-03) |
| `tst_q2cache.qml` | the packer works its kept rows out again when a row moves without a y change, at the start of a touch, and retries a layout that does not settle |
| `tst_q2pick.qml` | PickerGroup's columns end 61 dp over the bottom with the round confirm button |
| `tst_vq2.qml` | ListSubHeader in an inset column and in a ScalingList, headers moving alone, gaps (verifier's Q2 checks) |
| `tst_qvcache.qml` | EdgePacker caches after reparenting, item switches, transforms, model changes, reuse, toggles, margins and headers, horizontal lists, destruction while scrolling, against an oracle and a forced rebuild (incl. N61-05 restAtTop with a top margin) |
| `tst_q3sw.qml` | the small Wear switch, Material 3 and Material 2 colour sets (N61-06) |
| `tst_q3row.qml` | row buttons: the checked toggle row's gradient, the second line, disabled rows, Material 2 SwitchButton/CheckboxButton/RadioButton (N61-07) |
| `tst_q3slider.qml` | InlineSlider as the Wear OS 6 stepper (N61-08) |
| `tst_q3swipe.qml` | SwipeToReveal both ways and the expressive pill (N61-09) |
| `tst_q3picker.qml` | PickerGroup in the Clock's Material 2 style and the Label weight hook (N61-10) |
| `tst_q3m2.qml` | the Material 2 failure confirmation and chips (label weight and place) |
| `tst_q3edge.qml` | a Button used as a list row joins the packed edge layout when its edgeEffect is set |
| `tst_q4dialog.qml` | the Wear OS 6 confirmation dialog layout and the dialog motion (N61-11, N61-12) |
| `tst_q4push.qml` | the Settings push (LayerStack push tokens) against the emulator recording (N61-13) |
| `tst_q4loops.qml` | no binding loop while two-button and info AlertDialogs open, scroll and close |
| `tst_q4follow.qml` | a shown Dialog is modal for RotaryInput and its scroll indicator; ListHeader.restAtTop |
| `tst_q4contacts.qml` | no ScalingList height binding loop while the Contacts list scrolls in small steps (needs `CONTACTS=`) |
| `tst_q5edge.qml` | EdgeButton content placed as stock's ScaleAndAlignContentNode (N61-33) |
| `tst_q5swipe.qml` | SwipeToReveal's drag under expressiveLook: the card starts 29 dp after the press, then 1:1 (N61-09) |
| `tst_fpq1.qml` | no dictation during a call, the "Cannot record audio while in a call" toast, SetInUse("mic") around recording, Icon alpha after a dim colour (mocks, icons) |
| `tst_fpq2.qml` | RotaryInput's crown-speed mode on ListViews: free scroll, snap to the nearest item, StrictlyEnforceRange, a finger takes over |
| `crownspeed/` | CrownSpeed, the crown-speed state machine: px scroll, ticks per 42 px, limits, the 80 ms snap, a crown event during a snap, reset (counted as checks) |
| `flatmesh/` | FlatMesh: still by default, "input" glides for the idle timeout, "always" while visible; visibility, window, animated and reduce-motion stops; dconf motion and glide keys and their overrides |
| `dateformat/` | DateFormat.formatRange: the wall times Qt shows, under zone names and hand-written POSIX TZ strings (invented names) with and without DST rules, a DST change inside the range; one instant reads as format(); the zone field of a POSIX string is its offset |

Fixtures: `qml/ref/WearEdge.js` (the launcher's edge model that EdgeLayout must match),
`qml/ref/LaunchSplash.qml` (the launcher's launch splash, as `tst_ux.qml` loads it),
`qml/mocks/` (Nemo.DBus double, VoiceTest backend), `flatmesh/stubs/` (an in-memory MDConfItem).
