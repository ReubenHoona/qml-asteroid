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

/*
 * Swipe right from anywhere to go back, as Wear OS's SwipeToDismissBox: the
 * area watches the touches its children get and takes a drag over once it
 * clearly goes right (12 px, mostly sideways). Taps, vertical scrolling
 * and horizontal content that can still scroll back stay with the children:
 * a drag that starts on a horizontally scrolling Flickable or ListView that
 * is not at its start, or on an item with the property blocksBackSwipe set
 * to true, is left alone. edgeOnly limits it to a strip at the left edge
 * (round-aware, as BorderGestureArea), as Wear OS does for content that
 * scrolls horizontally.
 *
 * While a drag is taken, "value" follows the finger (0 .. width); on release
 * "finished" is emitted with "velocity" (px/s) and "flung" set, and the user
 * animates "value" to its end (it is writable) and calls reset().
 */
class BackSwipeArea : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(BackSwipeArea)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(qreal value READ value WRITE setValue NOTIFY valueChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY valueChanged)
    Q_PROPERTY(qreal velocity READ velocity NOTIFY velocityChanged)
    Q_PROPERTY(bool flung READ flung NOTIFY velocityChanged)
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
    /* true when the drag is ours from now on */
    bool move(const QPointF &scenePos);
    void release(const QPointF &scenePos);
    bool startAllowed(const QPointF &scenePos) const;
    bool blockedAt(const QPointF &scenePos) const;

    bool m_tracking = false;
    bool m_active = false;
    bool m_edgeOnly = false;
    bool m_swipeEnabled = true;
    QPointF m_start;
    qreal m_value = 0;
    qreal m_velocity = 0;
    qreal m_speed = 0;
    qreal m_lastX = 0;
    QElapsedTimer m_lastTime;
};

#endif // BACKSWIPEAREA_H
