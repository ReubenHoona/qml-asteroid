/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef BACKSWIPEAREA_H
#define BACKSWIPEAREA_H

#include <QElapsedTimer>
#include <QPointF>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>

class WearSpring;

/*
 * Swipe right from anywhere to go back, as Wear OS does (CP3A
 * WearGestureInterceptionDetector and SwipeBackGestureHandler): the area
 * watches the touches its children get and takes a drag over once it goes
 * right by more than twice the touch slop (2 x 8 dp = 32 px) with
 * |dy| < |dx|. Taps, vertical scrolling
 * and horizontal content that can still scroll back stay with the children:
 * a drag that starts on a horizontally scrolling Flickable or ListView that
 * is not at its start, or on an item with the property blocksBackSwipe set
 * to true, is left alone. edgeOnly limits it to a strip at the left edge
 * (round-aware, as BorderGestureArea), as Wear OS does for content that
 * scrolls horizontally.
 *
 * While a drag is taken, "value" follows the finger (0 .. width) and
 * "smoothedProgress" chases value / width on a spring (stiffness 1500,
 * damping 1, stock BackProgressAnimator). "armed" is stock's "will go back":
 * the swipe is past 0.33 of the width and the finger is not moving left;
 * it plays the threshold haptic (a click, at most once per 100 ms) when it
 * turns on. On release "finished" is emitted with "velocity" (px/s), and
 * "committed" holds stock's decision: 500 dp/s (1000 px/s) or more to the
 * right goes back, 500 dp/s or more to the left cancels, otherwise it goes
 * back past lerp(0.33, 0.10, v / 500 dp/s) of the width when the last move
 * was not leftward. The user animates to the end (value is writable) and
 * calls reset().
 */
class BackSwipeArea : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(BackSwipeArea)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(qreal value READ value WRITE setValue NOTIFY valueChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY valueChanged)
    Q_PROPERTY(qreal velocity READ velocity NOTIFY velocityChanged)
    /* Deprecated: 125 dp/s (250 px/s) or more to the right on release, the
     * old quick-flick test kept for callers that still decide with
     * `progress >= 0.5 || flung`. Use "committed" (stock's rule). */
    Q_PROPERTY(bool flung READ flung NOTIFY velocityChanged)
    Q_PROPERTY(bool committed READ committed NOTIFY velocityChanged)
    Q_PROPERTY(bool armed READ armed NOTIFY armedChanged)
    Q_PROPERTY(qreal smoothedProgress READ smoothedProgress NOTIFY smoothedProgressChanged)
    /* d smoothedProgress / dt, per second */
    Q_PROPERTY(qreal smoothedVelocity READ smoothedVelocity NOTIFY smoothedProgressChanged)
    /* how far right a drag goes before it is a back swipe, px */
    Q_PROPERTY(qreal decideDistance READ decideDistance NOTIFY densityChanged)
    Q_PROPERTY(bool edgeOnly READ edgeOnly WRITE setEdgeOnly NOTIFY edgeOnlyChanged)
    /* Whether a swipe is taken at all (not "enabled", which would also
     * disable the children) */
    Q_PROPERTY(bool swipeEnabled READ swipeEnabled WRITE setSwipeEnabled NOTIFY swipeEnabledChanged)

public:
    explicit BackSwipeArea(QQuickItem *parent = nullptr);

    bool active() const { return m_active; }
    qreal value() const { return m_value; }
    void setValue(qreal v);
    qreal progress() const { return width() > 0 ? qBound<qreal>(0, m_value / width(), 1) : 0; }
    qreal velocity() const { return m_velocity; }
    bool flung() const;
    bool committed() const { return m_committed; }
    bool armed() const { return m_armed; }
    qreal smoothedProgress() const;
    qreal smoothedVelocity() const;
    qreal decideDistance() const;
    /* px per dp: the shorter side over 192 dp (2.0 on the Pixel Watch 2) */
    qreal dp() const;

    /* Stock's decision on release (SwipeBackGestureHandler): dx = the
     * swipe's distance (px), velocity px/s, lastDx = the last move (px) */
    Q_INVOKABLE bool shouldCommit(qreal dx, qreal velocity, qreal lastDx, qreal width) const;
    bool edgeOnly() const { return m_edgeOnly; }
    void setEdgeOnly(bool e);
    bool swipeEnabled() const { return m_swipeEnabled; }
    void setSwipeEnabled(bool e);

    /* Ends a gesture whose animation is done: value 0, not active */
    Q_INVOKABLE void reset();

    /* Whether a touch at scenePos, under root, starts on content of its own
     * that moves sideways (a back swipe must leave it alone) */
    static bool blockedUnder(QQuickItem *root, const QPointF &scenePos);

signals:
    void activeChanged();
    void valueChanged();
    void velocityChanged();
    void edgeOnlyChanged();
    void swipeEnabledChanged();
    void started();
    void finished();
    void armedChanged();
    void smoothedProgressChanged();
    void densityChanged();
    /* the swipe armed: the threshold haptic played (rate-limited) */
    void thresholdCrossed();

protected:
    bool childMouseEventFilter(QQuickItem *item, QEvent *event) override;
    void touchEvent(QTouchEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void mouseUngrabEvent() override;
    void touchUngrabEvent() override;

private:
    bool press(const QPointF &scenePos);
    /* the touch point followed (see backswipearea.cpp) */
    const QEventPoint *followedPoint(QTouchEvent *event) const;
    bool pressPoint(const QTouchEvent *event, const QEventPoint &point);
    /* true when the drag is ours from now on */
    bool move(const QPointF &scenePos);
    void release(const QPointF &scenePos);
    bool startAllowed(const QPointF &scenePos) const;
    bool blockedAt(const QPointF &scenePos) const;
    void setArmed(bool a);

    bool m_tracking = false;
    bool m_active = false;
    /* the finger of this swipe is down (m_active stays set after the lift,
     * until reset(), while the swipe animates out) */
    bool m_down = false;
    int m_pointId = -1;
    quint64 m_pressTime = 0;
    bool m_edgeOnly = false;
    bool m_swipeEnabled = true;
    QPointF m_start;
    qreal m_value = 0;
    qreal m_velocity = 0;
    qreal m_speed = 0;
    qreal m_lastX = 0;
    QElapsedTimer m_lastTime;
    /* where the finger went down, and its last horizontal step */
    qreal m_downX = 0;
    qreal m_lastDx = 0;
    bool m_armed = false;
    bool m_committed = false;
    QElapsedTimer m_lastHaptic;
    WearSpring *m_smooth = nullptr;
};

#endif // BACKSWIPEAREA_H
