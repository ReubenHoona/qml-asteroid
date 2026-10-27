/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef ROTARYINPUT_H
#define ROTARYINPUT_H

#include <QObject>
#include <QPointer>
#include <QPointF>
#include <QElapsedTimer>
#include <QTimer>

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
 *    pxPerCount per count, smoothed over a few frames, faster when the crown
 *    turns fast (as Wear OS's rotary fling), with a haptic tick for every
 *    detent's worth of travel and a bump at either end.
 *  - snapping views (PathView pickers, ListViews that snap or strictly
 *    enforce a highlight range) step one item per detent with a tick.
 *  - a curved position indicator at the right edge (PositionIndicator.qml)
 *    shows where a free view is while the crown or a finger scrolls it.
 *
 * dconf (all optional, read at start and on change):
 *   /org/asteroidos/ux/rotary            bool, default true
 *   /org/asteroidos/ux/rotary-invert     bool, default false
 *   /org/asteroidos/ux/rotary-px-per-count       double, px, default 3.5
 *   /org/asteroidos/ux/rotary-counts-per-detent  double, default 24
 *   /org/asteroidos/ux/position-indicator         bool, default true
 * QT_LOGGING_RULES="asteroid.rotary.debug=true" logs every event.
 */
class RotaryInput : public QObject
{
    Q_OBJECT

public:
    enum Kind { None, Free, Snap, Path };

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
    void scrollFree(qreal counts);
    void stepSnap(int steps);
    void animate();
    void showIndicator(QQuickItem *flickable, bool flash);
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
    qreal m_lastTickPos = 0;     /* content position of the last tick */
    QTimer m_frame;
    QElapsedTimer m_frameClock;
    QElapsedTimer m_lastEvent;
    qreal m_speed = 0;           /* smoothed counts per second */

    /* snapping */
    qreal m_pending = 0;         /* counts not yet worth a detent */

    /* settings */
    MDConfItem *m_enabled;
    MDConfItem *m_invert;
    MDConfItem *m_pxPerCount;
    MDConfItem *m_countsPerDetent;
    MDConfItem *m_indicatorEnabled;
    bool m_on = true;
    bool m_inverted = false;
    qreal m_px = 3.5;
    qreal m_detent = 24;
    bool m_indicatorOn = true;

    QPointer<QObject> m_indicator;
};

#endif // ROTARYINPUT_H
