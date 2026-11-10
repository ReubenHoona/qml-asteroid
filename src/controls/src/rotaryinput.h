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

class QQuickItem;
class QQuickWindow;
class QWheelEvent;
class MDConfItem;

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
 *  - a curved position indicator at the right edge (PositionIndicator.qml)
 *    shows where a free view is while the crown or a finger scrolls it.
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

public:
    enum Kind { None, Free, Snap, Path, Exit };

    static void install();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    explicit RotaryInput(QObject *parent = nullptr);

    bool handleWheel(QQuickWindow *window, QWheelEvent *event);
    void notePress(QQuickWindow *window, const QPointF &pos);
    QQuickItem *findTarget(QQuickWindow *window, const QPointF &pos, Kind *kind, bool *blocked) const;
    static Kind kindOf(QQuickItem *item);
    static bool scrollsVertically(QQuickItem *item);
    static bool scrollsHorizontally(QQuickItem *item);
    void scrollFree(qreal forward);
    void stepSnap(int steps);
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
    void showIndicator(QQuickItem *flickable, bool flash);
    bool ensureIndicator(QQuickWindow *window, QQuickItem *anyItem);
    void prepareIndicator(QQuickWindow *window);
    void readSettings();

    QPointer<QQuickItem> m_target;
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

    QPointer<QObject> m_indicator;
    /* windows whose indicator is made (or about to be) ahead of use */
    QSet<QQuickWindow *> m_prepared;
};

#endif // ROTARYINPUT_H
