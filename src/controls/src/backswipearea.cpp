/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "backswipearea.h"

#include <QMouseEvent>
#include <QSettings>
#include <QTouchEvent>
#include <QtMath>

#include <private/qquickitem_p.h>
#include <private/qquickpointerhandler_p.h>

/* 6 dp at 2 px per dp: a drag this far to the right, at most 34 degrees off
 * the horizontal, is a back swipe */
static const qreal DECIDE_PX = 12.0;
static const qreal MAX_SLOPE = 0.67;
/* Wear OS: a quick flick dismisses whatever the distance, 125 dp/s */
static const qreal FLING_DP_PER_S = 125.0;
/* edgeOnly: the strip at the left edge, as BorderGestureArea */
static const qreal EDGE_FRACTION = 0.1;

static bool roundScreen()
{
    static int round = -1;
    if (round < 0) {
        QSettings machineConf(QStringLiteral("/etc/asteroid/machine.conf"), QSettings::IniFormat);
        round = machineConf.value(QStringLiteral("Display/ROUND"), false).toBool() ? 1 : 0;
    }
    return round == 1;
}

BackSwipeArea::BackSwipeArea(QQuickItem *parent) : QQuickItem(parent)
{
    setFiltersChildMouseEvents(true);
    setAcceptedMouseButtons(Qt::LeftButton);
    setAcceptTouchEvents(true);
}

void BackSwipeArea::setValue(qreal v)
{
    if (qFuzzyCompare(v, m_value))
        return;
    m_value = v;
    emit valueChanged();
}

bool BackSwipeArea::flung() const
{
    const qreal dp = qMin(width(), height()) / 192.0;
    return m_velocity >= FLING_DP_PER_S * dp;
}

void BackSwipeArea::setEdgeOnly(bool e)
{
    if (e == m_edgeOnly)
        return;
    m_edgeOnly = e;
    emit edgeOnlyChanged();
}

void BackSwipeArea::setSwipeEnabled(bool e)
{
    if (e == m_swipeEnabled)
        return;
    m_swipeEnabled = e;
    if (!e && !m_active)
        m_tracking = false;
    emit swipeEnabledChanged();
}

void BackSwipeArea::reset()
{
    m_tracking = false;
    setValue(0);
    if (m_active) {
        m_active = false;
        emit activeChanged();
    }
    setKeepTouchGrab(false);
    setKeepMouseGrab(false);
}

bool BackSwipeArea::startAllowed(const QPointF &scenePos) const
{
    if (!m_edgeOnly)
        return true;
    const QPointF p = mapFromScene(scenePos);
    qreal left = 0;
    if (roundScreen() && qAbs(width() - height()) < 2) {
        /* the visible left edge at this height */
        const qreal r = height() / 2;
        const qreal d = p.y() - r;
        left = d * d < r * r ? r - qSqrt(r * r - d * d) : r;
    }
    return p.x() - left < width() * EDGE_FRACTION;
}

static bool blocks(QQuickItem *item)
{
    if (item->property("blocksBackSwipe").toBool())
        return true;
    /* something dragged sideways: a MouseArea with a drag target on the x
     * axis, or one that never lets its press be stolen (sliders, scrubbers) */
    if (item->inherits("QQuickMouseArea")) {
        if (item->property("preventStealing").toBool())
            return true;
        QObject *drag = item->property("drag").value<QObject *>();
        if (drag && drag->property("target").value<QObject *>()
                && (drag->property("axis").toInt() & 1))
            return true;
    }
    /* a DragHandler that moves along x */
    QQuickItemPrivate *d = QQuickItemPrivate::get(item);
    if (d->hasPointerHandlers()) {
        for (QQuickPointerHandler *h : d->extra->pointerHandlers) {
            if (!h->enabled() || !h->inherits("QQuickDragHandler"))
                continue;
            QObject *x = h->property("xAxis").value<QObject *>();
            if (x && x->property("enabled").toBool())
                return true;
        }
    }
    if (item->inherits("QQuickFlickable")) {
        const int dir = item->property("flickableDirection").toInt();
        /* Flickable.VerticalFlick is 2 */
        if (dir != 2 && item->property("interactive").toBool()) {
            const qreal content = item->property("contentWidth").toReal()
                    + item->property("leftMargin").toReal() + item->property("rightMargin").toReal();
            if (content > item->width() + 1) {
                const qreal x = item->property("contentX").toReal();
                const qreal start = item->property("originX").toReal() - item->property("leftMargin").toReal();
                if (x > start + 0.5)
                    return true;   /* it can still scroll back: its swipe */
            }
        }
    }
    return false;
}

static bool blockedUnder(QQuickItem *item, const QPointF &scenePos)
{
    if (!item->isVisible() || !item->isEnabled())
        return false;
    const QPointF p = item->mapFromScene(scenePos);
    const bool inside = item->contains(p);
    if (inside && blocks(item))
        return true;
    if (!inside && item->clip())
        return false;
    const QList<QQuickItem *> children = QQuickItemPrivate::get(item)->paintOrderChildItems();
    for (QQuickItem *child : children) {
        if (blockedUnder(child, scenePos))
            return true;
    }
    return false;
}

bool BackSwipeArea::blockedAt(const QPointF &scenePos) const
{
    const QList<QQuickItem *> children = QQuickItemPrivate::get(this)->paintOrderChildItems();
    for (QQuickItem *child : children) {
        if (blockedUnder(child, scenePos))
            return true;
    }
    return false;
}

bool BackSwipeArea::press(const QPointF &scenePos)
{
    m_tracking = m_swipeEnabled && isEnabled() && isVisible() && startAllowed(scenePos) && !blockedAt(scenePos);
    m_start = scenePos;
    m_lastX = scenePos.x();
    m_speed = 0;
    m_lastTime.start();
    return m_tracking;
}

bool BackSwipeArea::move(const QPointF &scenePos)
{
    if (!m_tracking)
        return false;
    const qreal dx = scenePos.x() - m_start.x();
    const qreal dy = scenePos.y() - m_start.y();

    const qint64 dt = m_lastTime.restart();
    if (dt > 0) {
        const qreal inst = (scenePos.x() - m_lastX) * 1000.0 / dt;
        m_speed = dt > 100 ? inst : m_speed * 0.4 + inst * 0.6;
    }
    m_lastX = scenePos.x();

    if (!m_active) {
        if (qAbs(dy) > DECIDE_PX && qAbs(dy) > qAbs(dx)) {
            m_tracking = false;   /* a vertical scroll */
            return false;
        }
        if (dx < -DECIDE_PX) {
            m_tracking = false;   /* going left: not back */
            return false;
        }
        if (dx < DECIDE_PX || qAbs(dy) > dx * MAX_SLOPE)
            return false;
        m_active = true;
        /* start from where the decision was made, so nothing jumps */
        m_start.setX(scenePos.x());
        emit activeChanged();
        emit started();
        return true;
    }
    setValue(qBound<qreal>(0, scenePos.x() - m_start.x(), width()));
    return true;
}

void BackSwipeArea::release(const QPointF &scenePos)
{
    Q_UNUSED(scenePos)
    const bool was = m_active;
    m_tracking = false;
    setKeepTouchGrab(false);
    setKeepMouseGrab(false);
    if (!was)
        return;
    m_velocity = m_lastTime.elapsed() > 80 ? 0 : m_speed;
    emit velocityChanged();
    emit finished();
}

bool BackSwipeArea::childMouseEventFilter(QQuickItem *item, QEvent *event)
{
    Q_UNUSED(item)
    if (!isVisible() || !isEnabled())
        return QQuickItem::childMouseEventFilter(item, event);

    switch (event->type()) {
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd: {
        QTouchEvent *te = static_cast<QTouchEvent *>(event);
        if (te->pointCount() != 1)
            return false;
        const QEventPoint &pt = te->points().first();
        if (pt.state() == QEventPoint::State::Pressed) {
            press(pt.scenePosition());
        } else if (pt.state() == QEventPoint::State::Updated) {
            if (!m_active && move(pt.scenePosition())) {
                /* take the drag over: accepting the filtered event makes
                 * the delivery agent give us the exclusive grab */
                setKeepTouchGrab(true);
                setKeepMouseGrab(true);
                te->accept();
                return true;
            }
        } else if (pt.state() == QEventPoint::State::Released) {
            if (!m_active)
                m_tracking = false;
        }
        return false;
    }
    case QEvent::MouseButtonPress:
    case QEvent::MouseMove:
    case QEvent::MouseButtonRelease: {
        QMouseEvent *me = static_cast<QMouseEvent *>(event);
        if (me->source() != Qt::MouseEventNotSynthesized)
            return false;   /* the touch events are handled */
        if (event->type() == QEvent::MouseButtonPress) {
            press(me->scenePosition());
        } else if (event->type() == QEvent::MouseMove) {
            if (!m_active && move(me->scenePosition())) {
                setKeepMouseGrab(true);
                grabMouse();
                return true;
            }
        } else if (!m_active) {
            m_tracking = false;
        }
        return false;
    }
    default:
        break;
    }
    return QQuickItem::childMouseEventFilter(item, event);
}

void BackSwipeArea::touchEvent(QTouchEvent *event)
{
    if (event->pointCount() != 1) {
        QQuickItem::touchEvent(event);
        return;
    }
    const QEventPoint &pt = event->points().first();
    switch (pt.state()) {
    case QEventPoint::State::Pressed:
        /* nothing under the finger took the press: track it ourselves */
        if (press(pt.scenePosition()))
            event->accept();
        else
            event->ignore();
        break;
    case QEventPoint::State::Updated:
        move(pt.scenePosition());
        event->accept();
        break;
    case QEventPoint::State::Released:
        release(pt.scenePosition());
        event->accept();
        break;
    default:
        QQuickItem::touchEvent(event);
        break;
    }
}

void BackSwipeArea::mousePressEvent(QMouseEvent *event)
{
    if (press(event->scenePosition()))
        event->accept();
    else
        event->ignore();
}

void BackSwipeArea::mouseMoveEvent(QMouseEvent *event)
{
    move(event->scenePosition());
}

void BackSwipeArea::mouseReleaseEvent(QMouseEvent *event)
{
    release(event->scenePosition());
}

void BackSwipeArea::mouseUngrabEvent()
{
    if (m_active)
        release(QPointF());
    m_tracking = false;
}

void BackSwipeArea::touchUngrabEvent()
{
    if (m_active)
        release(QPointF());
    m_tracking = false;
}
