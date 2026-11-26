/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef ROTARYINPUT_H
#define ROTARYINPUT_H

#include <QObject>
#include <QPointer>
#include <QSet>
#include <QPointF>
#include <QElapsedTimer>
#include <QTimer>
#include <QList>
#include <QPair>
#include <QtQml/qqmlregistration.h>

#include "crownspeed.h"

class QQuickItem;
class QQuickWindow;
class QWheelEvent;
class MDConfItem;
class QQmlEngine;
class QJSEngine;

/*
 * RotaryInput: the crown scrolls whatever the user is looking at, as on
 * Wear OS, in every application that imports org.asteroid.controls and in
 * the launcher, without any change to the application.
 *
 * The crown (PAT9126, REL_WHEEL) reaches Qt as wheel events of 120 angle
 * units per count. Left to Qt, a Flickable turns each count into a 72 px
 * jump or an accelerated mouse-wheel flick, which is far too fast for a
 * crown that gives about 24 counts per detent, and PathView pickers (time,
 * date, timer) ignore the wheel altogether. RotaryInput is an application
 * event filter that takes the wheel events of a QQuickWindow before Qt does
 * and drives the target itself:
 *
 *  - the target is the scrollable view under the last touch when there was
 *    one in the last 10 s (the column of a picker the user last touched),
 *    else the view under the middle of the window. Items carrying a
 *    WheelHandler (map zoom, the speed-dial launcher) keep their wheel
 *    events: RotaryInput steps aside for them and for windows without any
 *    scrollable view.
 *  - free views (Flickable, ListView, GridView without snapping) scroll by
 *    pxPerCount per count, smoothed over a few frames, with a haptic tick
 *    (Haptics.scrollTick) for every 42 px (21 dp) of crown scroll and one
 *    bump (Haptics.scrollLimit) at an end, re-armed once the view moves.
 *  - snapping views (PathView pickers, ListViews that snap or strictly
 *    enforce a highlight range) step item by item with Haptics.scrollFocus.
 *  - crown-speed mode (stock's picker, face-interaction-32; crownspeed.h):
 *    a snapping ListView or GridView with `property bool rotaryCrownSpeed:
 *    true` scrolls freely by the crown's pixels (as a free view, with its
 *    smoothing and gain), a Haptics.scrollTick every 42 px and one
 *    Haptics.scrollLimit at an end, and 80 ms after the last crown event
 *    (or when the smoothing glide reaches the goal, if later) it glides to
 *    the nearest item (for StrictlyEnforceRange: the item at
 *    preferredHighlightBegin, which becomes the current one). No view sets
 *    it by default.
 *  - a curved position indicator at the right edge (PositionIndicator.qml)
 *    shows where a free view is while the crown or a finger scrolls it,
 *    and for 2 s when QML calls RotaryInput.flashIndicator(view) as a list
 *    screen opens (the launcher's panels, which no touch or crown opens).
 *    RotaryInput.systemIndicator (default false) draws it in the system
 *    UI's style (white thumb, #4D4D4D track, 34 degrees); the launcher,
 *    which hosts only system surfaces, sets it once at start. A view with
 *    `property bool m3Indicator: true` keeps the app (M3) style.
 *  - rotary overscroll exit (stock SysUI ScrollAccumulator): a view or an
 *    ancestor that declares `signal rotaryExit(int direction)` gets it once
 *    the crown has pushed 150 px past an end (events under 120 ms apart,
 *    one direction; -1 = past the start, 1 = past the end). An optional
 *    `property int rotaryExitEdge` (-1 start, 1 end, 0 both) limits the
 *    edge. While it accumulates, the events are taken and no bump plays.
 *
 * Crown speed, Settings > Buttons > Faster crown scrolling (choice 2,
 * /org/asteroidos/ux/crown-fast, default true = the user's value):
 *  - true: rotary-px-per-count (7.5 in the image) with a 1-3x gain from 4
 *    to 12 detents/s, 24 counts per item for snapping views, no slop, no
 *    crown fling (the behaviour before this option existed).
 *  - false (stock CP3A): 1.4976 px per count (|device.scalingFactor| 0.0117
 *    x config_verticalScrollFactor 64 dp x 2 px/dp), no gain; input slop
 *    (the first 12 counts after 500 ms without rotation or after a
 *    direction change are dropped); a crown fling after a fast spin
 *    (velocity over the last events x 0.7, from 500 to 2750 dp/s, AOSP
 *    spline); snapping views step when the crown has moved
 *    itemSize / lerp(1, 1.5, ease(v)) px (pagers: lerp(5, 7.5, ...)), at
 *    most 2 items per event, and glide on a spring of stiffness 200.
 *
 * dconf (all optional, read at start and on change):
 *   /org/asteroidos/ux/rotary            bool, default true
 *   /org/asteroidos/ux/rotary-invert     bool, default false
 *   /org/asteroidos/ux/crown-fast        bool, default true
 *   /org/asteroidos/ux/rotary-px-per-count       double, px, default 1.75
 *                                        (42 px per detent; crown-fast only)
 *   /org/asteroidos/ux/rotary-counts-per-detent  double, default 24
 *   /org/asteroidos/ux/position-indicator         bool, default true
 * Haptics follow Settings > Vibration > Using crown (Haptics.crownEnabled).
 * QT_LOGGING_RULES="asteroid.rotary.debug=true" logs every event.
 */
class QAbstractAnimation;

class RotaryInput : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(RotaryInput)
    QML_SINGLETON
    Q_MOC_INCLUDE(<QQuickItem>)
    /* the position indicator in the system UI's style (N61-03) */
    Q_PROPERTY(bool systemIndicator READ systemIndicator WRITE setSystemIndicator NOTIFY systemIndicatorChanged)

public:
    enum Kind { None, Free, Snap, Path, Exit, Speed };

    static void install();
    static RotaryInput *instance();
    static RotaryInput *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    /* Show the position indicator on `flickable` now and hide it 2 s later,
     * as stock does when a list screen opens: its indicator shows while the
     * screen stage is not Idle, and a new screen is New for 2 s
     * (ScreenScaffoldKt$$ExternalSyntheticLambda5.java:24,
     * ScreenContent$UpdateIdlingDetectorIfNeeded$2$1.java:45). Only for a
     * visible Flickable that scrolls vertically (contentHeight + topMargin
     * + bottomMargin > height + 1) while the indicator is on
     * (/org/asteroidos/ux/position-indicator); returns true when shown.
     * In an Application the view also goes to the time text (ScrollAway)
     * as a new screen. */
    Q_INVOKABLE bool flashIndicator(QQuickItem *flickable);
    /* A modal surface (a Dialog) shows over the screen: the indicator of a
     * view that is not inside it fades out now, as stock's belongs to the
     * screen under the dialog (the Wear OS 6 confirmation S25 shows none).
     * While an item with `property bool rotaryModal: true` covers the touch
     * or the middle of the window, the crown and the indicator only see
     * the views inside it. */
    Q_INVOKABLE void coverIndicator(QQuickItem *cover);

    bool systemIndicator() const { return m_systemIndicator; }
    void setSystemIndicator(bool on);

signals:
    void systemIndicatorChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    explicit RotaryInput(QObject *parent = nullptr);

    bool handleWheel(QQuickWindow *window, QWheelEvent *event);
    void notePress(QQuickWindow *window, const QPointF &pos);
    QQuickItem *findTarget(QQuickWindow *window, const QPointF &pos, Kind *kind, bool *blocked,
                           bool *modal = nullptr) const;
    static Kind kindOf(QQuickItem *item);
    static bool scrollsVertically(QQuickItem *item);
    static bool scrollsHorizontally(QQuickItem *item);
    void scrollFree(qreal forward);
    void stepSnap(int steps);
    void scrollSpeed(qreal forward);
    void snapSpeed();
    void speedSettled();
    void speedBounds(qreal *lo, qreal *hi) const;
    qreal speedSnapPos(QQuickItem *item) const;
    qreal applySlop(qreal counts);
    bool pushPastEnd(qreal px);
    void playLimit(qreal pos);
    void noteFlingSample(qreal px);
    void maybeFling();
    qreal snapThreshold(qreal px);
    qreal itemSize() const;
    qreal pxPerCount(QQuickItem *item) const;
    void animate(qreal dt);
    bool gliding() const;
    void startGlide();
    friend class RotaryFrames;
    bool showIndicator(QQuickItem *flickable, bool flash);
    bool ensureIndicator(QQuickWindow *window, QQuickItem *anyItem);
    void prepareIndicator(QQuickWindow *window);
    void readSettings();

    QPointer<QQuickItem> m_target;
    /* the picker group whose rotaryTarget gave m_target: the crown moves
     * on with its focus at once, not after a gesture gap */
    QPointer<QQuickItem> m_redirector;
    Kind m_kind = None;
    bool m_horizontal = false;

    /* the last touch: where and when, and what it resolved to */
    QPointer<QQuickWindow> m_pressWindow;
    QPointF m_pressPos;
    QElapsedTimer m_pressTime;

    /* free scrolling */
    qreal m_goal = 0;            /* where the content is heading */
    /* driven by Qt Quick's animation driver: one step per frame, in step
     * with the display (a 16 ms timer beats against the 16.7 ms vsync) */
    QAbstractAnimation *m_frame = nullptr;
    int m_frameTime = 0;
    qreal m_glideVelocity = 0;   /* px/s of the smoothing spring */
    QElapsedTimer m_lastEvent;
    qreal m_speed = 0;           /* smoothed counts per second */

    /* snapping: counts (crown-fast) or crown px (stock) not yet worth an
     * item, and the stock snap's smoothed crown speed in px/s */
    qreal m_pending = 0;
    qreal m_snapVelocity = 0;

    /* crown-speed mode: its state, the snap 80 ms after the last crown
     * event (one shot), and the item the snap goes to */
    CrownSpeed m_crown;
    QTimer m_speedTimer;
    int m_speedIndex = -1;

    /* haptics: crown px since the last scroll tick (signed, the remainder
     * carried over), and the end bump armed until it plays at limitPos */
    qreal m_tickAcc = 0;
    bool m_limitArmed = true;
    qreal m_limitPos = 0;

    /* stock slop (input filter, as AOSP SlopController) */
    QElapsedTimer m_slopTime;
    qreal m_slopSum = 0;
    bool m_slopMet = false;

    /* rotary overscroll exit */
    QPointer<QObject> m_exitReceiver;
    qreal m_exitSum = 0;
    QElapsedTimer m_exitTime;

    /* stock crown fling: recent events (ms, px) and the spline running */
    QElapsedTimer m_clock;
    QList<QPair<qint64, qreal>> m_samples;
    QTimer m_flingTimer;
    bool m_flinging = false;
    qreal m_flingFrom = 0;
    qreal m_flingDistance = 0;
    qreal m_flingDuration = 0;
    qreal m_flingElapsed = 0;

    /* settings */
    MDConfItem *m_enabled;
    MDConfItem *m_invert;
    MDConfItem *m_pxPerCount;
    MDConfItem *m_countsPerDetent;
    MDConfItem *m_indicatorEnabled;
    MDConfItem *m_fastItem;
    bool m_on = true;
    bool m_fast = true;
    bool m_inverted = false;
    qreal m_px = 3.5;
    qreal m_detent = 24;
    bool m_indicatorOn = true;
    bool m_systemIndicator = false;

    QPointer<QObject> m_indicator;
    /* windows whose indicator is made (or about to be) ahead of use */
    QSet<QQuickWindow *> m_prepared;
};

#endif // ROTARYINPUT_H
