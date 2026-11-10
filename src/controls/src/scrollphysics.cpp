/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "scrollphysics.h"
#include "spring.h"

#include <QGuiApplication>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QtMath>

#include <qpa/qplatformtheme.h>
#include <private/qguiapplication_p.h>

/* dynamic property naming the ScrollPhysics that drives a Flickable */
static const char PHYSICS_PROPERTY[] = "_asteroidScrollPhysics";
/* an application may opt a view out of the global stock fling */
static const char OPT_OUT_PROPERTY[] = "asteroidStockFling";

/* Qt's Flickable reports half the finger's travel past an end as overshoot
 * (QQuickFlickablePrivate::drag: newY = minY + (newY - minY) / 2) */
static const qreal QT_DRAG_OVERSHOOT_GAIN = 2.0;

namespace {
class PhysicsDriver : public QAbstractAnimation
{
public:
    explicit PhysicsDriver(ScrollPhysics *p) : QAbstractAnimation(p), m_physics(p) { }
    int duration() const override { return -1; }

protected:
    void updateCurrentTime(int t) override { m_physics->advance(t); }

private:
    ScrollPhysics *m_physics;
};
}

ScrollPhysics::ScrollPhysics(QObject *parent) : QObject(parent)
{
    m_driver = new PhysicsDriver(this);
}

ScrollPhysics::~ScrollPhysics()
{
    m_driver->stop();
    if (m_flickable && physicsOf(m_flickable) == this)
        m_flickable->setProperty(PHYSICS_PROPERTY, QVariant());
}

ScrollPhysics *ScrollPhysics::physicsOf(QQuickItem *flickable)
{
    if (!flickable)
        return nullptr;
    return qobject_cast<ScrollPhysics *>(flickable->property(PHYSICS_PROPERTY).value<QObject *>());
}

static qreal themeHint(QPlatformTheme::ThemeHint hint, qreal fallback)
{
    const QPlatformTheme *theme = QGuiApplicationPrivate::platformTheme();
    return theme ? theme->themeHint(hint).toReal() : fallback;
}

bool ScrollPhysics::installStockFling(QQuickItem *f)
{
    if (!f || !f->inherits("QQuickFlickable"))
        return false;
    if (physicsOf(f))
        return true;
    const QVariant optIn = f->property(OPT_OUT_PROPERTY);
    if (optIn.isValid() && !optIn.toBool())
        return false;
    /* the application tuned its own physics (Qt's defaults: 2500 px/s,
     * 1500 px/s^2, qplatformtheme.cpp FlickMaximumVelocity/Deceleration) */
    if (!qFuzzyCompare(f->property("maximumFlickVelocity").toReal(),
                       themeHint(QPlatformTheme::FlickMaximumVelocity, 2500))
            || !qFuzzyCompare(f->property("flickDeceleration").toReal(),
                              themeHint(QPlatformTheme::FlickDeceleration, 1500)))
        return false;
    ScrollPhysics *p = new ScrollPhysics(f);
    p->m_global = true;
    p->m_stretchEnabled = false;
    p->m_flickable = f;
    p->m_complete = true;
    p->attach();
    return true;
}

QQuickItem *ScrollPhysics::flickable() const
{
    return m_flickable;
}

void ScrollPhysics::setFlickable(QQuickItem *f)
{
    if (m_flickable == f)
        return;
    stop();
    m_flickable = f;
    if (m_complete)
        attach();
    emit flickableChanged();
}

void ScrollPhysics::setFlingEnabled(bool e)
{
    if (e == m_flingEnabled)
        return;
    m_flingEnabled = e;
    emit flingEnabledChanged();
}

void ScrollPhysics::setStretchEnabled(bool e)
{
    if (e == m_stretchEnabled)
        return;
    m_stretchEnabled = e;
    if (!e)
        setPull(0);
    emit stretchEnabledChanged();
}

void ScrollPhysics::componentComplete()
{
    m_complete = true;
    if (!m_flickable) {
        QQuickItem *p = qobject_cast<QQuickItem *>(parent());
        if (p && p->inherits("QQuickFlickable"))
            m_flickable = p;
    }
    attach();
}

void ScrollPhysics::attach()
{
    for (const QMetaObject::Connection &c : std::as_const(m_connections))
        disconnect(c);
    m_connections.clear();
    QQuickItem *f = m_flickable;
    if (!f || !f->inherits("QQuickFlickable"))
        return;
    /* one ScrollPhysics per Flickable: an explicit one replaces the global
     * fling-only one */
    ScrollPhysics *other = physicsOf(f);
    if (other && other != this) {
        if (!other->m_global || m_global)
            return;
        other->stop();
        for (const QMetaObject::Connection &c : std::as_const(other->m_connections))
            disconnect(c);
        other->m_connections.clear();
        other->m_flickable = nullptr;
        other->deleteLater();
    }
    f->setProperty(PHYSICS_PROPERTY, QVariant::fromValue<QObject *>(this));
    if (!m_global) {
        /* the finger may pull past an end (that is the stretch), the content
         * itself stops at the bounds */
        f->setProperty("boundsBehavior", 1);   /* Flickable.DragOverBounds */
        f->setProperty("boundsMovement", 0);   /* Flickable.StopAtBounds */
    }
    /* the speed limit is stock's */
    f->setProperty("maximumFlickVelocity", maximumVelocity());
    m_connections << connect(f, SIGNAL(flickStarted()), this, SLOT(onFlickStarted()));
    m_connections << connect(f, SIGNAL(draggingChanged()), this, SLOT(onDraggingChanged()));
    if (!m_global)
        m_connections << connect(f, SIGNAL(verticalOvershootChanged()), this, SLOT(onOvershootChanged()));
    m_connections << connect(f, SIGNAL(contentYChanged()), this, SLOT(onContentYChanged()));
}

qreal ScrollPhysics::density() const
{
    QQuickItem *f = m_flickable;
    QSizeF s;
    if (f && f->window())
        s = f->window()->size();
    else if (QGuiApplication::primaryScreen())
        s = QGuiApplication::primaryScreen()->size();
    const qreal m = qMin(s.width(), s.height());
    /* Wear OS lays the Pixel Watch 2 out as 192 dp */
    return m > 0 ? m / 192.0 : 2.0;
}

qreal ScrollPhysics::height() const
{
    return m_flickable ? m_flickable->height() : 0;
}

qreal ScrollPhysics::minY() const
{
    QQuickItem *f = m_flickable;
    return f->property("originY").toReal() - f->property("topMargin").toReal();
}

qreal ScrollPhysics::maxY() const
{
    QQuickItem *f = m_flickable;
    const qreal m = f->property("originY").toReal() + f->property("contentHeight").toReal()
            + f->property("bottomMargin").toReal() - f->height();
    return qMax(m, minY());
}

qreal ScrollPhysics::flingDistance(qreal velocity) const
{
    const qreal v = qBound(-maximumVelocity(), velocity, maximumVelocity());
    return FlingSpline::distance(v, density() * 160, FRICTION);
}

qreal ScrollPhysics::flingDuration(qreal velocity) const
{
    const qreal v = qBound(-maximumVelocity(), velocity, maximumVelocity());
    return FlingSpline::duration(v, density() * 160, FRICTION);
}

qreal ScrollPhysics::stretchFor(qreal d) const
{
    /* AOSP EdgeEffect.dampStretchVector */
    const qreal o = qMin<qreal>(qAbs(d), 1);
    return 1 + STRETCH_INTENSITY * o + STRETCH_INTENSITY * (1 - qExp(-o * M_E / SCROLL_DIST_AFFECTED));
}

qreal ScrollPhysics::stretchScale() const
{
    return m_stretchEnabled && m_pull != 0 ? stretchFor(m_pull) : 1;
}

qreal ScrollPhysics::stretchOrigin() const
{
    /* the content stretches away from the edge being pulled */
    return m_pull < 0 ? height() : 0;
}

void ScrollPhysics::setMode(Mode m)
{
    if (m == m_mode)
        return;
    const bool wasFling = m_mode == Fling;
    m_mode = m;
    m_driver->stop();
    if (m != Idle)
        m_driver->start();
    if (wasFling != (m == Fling))
        emit flingingChanged();
}

void ScrollPhysics::setPull(qreal p)
{
    if (qFuzzyCompare(p + 1, m_pull + 1))
        return;
    m_pull = p;
    emit stretchChanged();
}

void ScrollPhysics::stop()
{
    setMode(Idle);
    setPull(0);
}

void ScrollPhysics::onFlickStarted()
{
    QQuickItem *f = m_flickable;
    if (!m_flingEnabled || !f)
        return;
    const int dir = f->property("flickableDirection").toInt();
    /* Flickable.HorizontalFlick is 1 */
    if (dir == 1)
        return;
    /* a flick that also goes sideways, or a view that snaps (ListView
     * snapMode, StrictlyEnforceRange): Qt's own flick does that */
    if (f->property("horizontalVelocity").toReal() != 0)
        return;
    if (f->property("snapMode").toInt() != 0 || f->property("highlightRangeMode").toInt() == 2)
        return;
    const qreal v = f->property("verticalVelocity").toReal();
    if (v == 0)
        return;
    /* the spline replaces Qt's constant deceleration */
    QMetaObject::invokeMethod(f, "cancelFlick");
    fling(v);
}

void ScrollPhysics::fling(qreal velocity)
{
    QQuickItem *f = m_flickable;
    if (!f)
        return;
    velocity = qBound(-maximumVelocity(), velocity, maximumVelocity());
    m_start = f->property("contentY").toReal();
    m_written = m_start;
    m_distance = (velocity < 0 ? -1 : 1) * flingDistance(velocity);
    m_duration = flingDuration(velocity);
    if (m_duration <= 0 || qAbs(m_distance) < 0.5)
        return;
    setPull(0);
    setMode(Idle);
    setMode(Fling);
}

void ScrollPhysics::absorb(qreal velocity)
{
    if (!m_stretchEnabled || height() <= 0)
        return;
    /* AOSP EdgeEffect.onAbsorb (TYPE_STRETCH): the spring starts at the edge
     * with the velocity x ON_ABSORB_VELOCITY_ADJUSTMENT; a fling into the
     * bottom pulls the bottom (negative) */
    m_springX0 = m_pull * height();
    m_springV0 = -velocity * ABSORB_ADJUSTMENT;
    setMode(Idle);
    setMode(Spring);
}

void ScrollPhysics::pullTo(qreal px)
{
    if (!m_stretchEnabled || height() <= 0)
        return;
    if (m_mode != Idle)
        setMode(Idle);
    setPull(qBound<qreal>(-1, px / height(), 1));
}

void ScrollPhysics::release()
{
    if (m_pull == 0 || height() <= 0)
        return;
    m_springX0 = m_pull * height();
    m_springV0 = 0;
    setMode(Spring);
}

void ScrollPhysics::onDraggingChanged()
{
    QQuickItem *f = m_flickable;
    if (!f)
        return;
    if (f->property("dragging").toBool()) {
        if (m_mode == Fling)
            setMode(Idle);
    } else {
        release();
    }
}

void ScrollPhysics::onOvershootChanged()
{
    QQuickItem *f = m_flickable;
    if (!f || !f->property("dragging").toBool())
        return;   /* Qt's own return to the bounds after a lift: ours springs */
    /* Qt: negative past the beginning; ours: positive when the top is pulled */
    pullTo(-f->property("verticalOvershoot").toReal() * QT_DRAG_OVERSHOOT_GAIN);
}

void ScrollPhysics::onContentYChanged()
{
    if (m_mode != Fling || m_writing || !m_flickable)
        return;
    /* someone else (the crown, a positionViewAtIndex) moved the list */
    if (qAbs(m_flickable->property("contentY").toReal() - m_written) > 1)
        setMode(Idle);
}

void ScrollPhysics::advance(int ms)
{
    QQuickItem *f = m_flickable;
    if (!f) {
        setMode(Idle);
        return;
    }
    if (m_mode == Fling) {
        const qreal t = m_duration > 0 ? ms / m_duration : 1;
        qreal y = m_start + m_distance * FlingSpline::position(t);
        const qreal lo = minY(), hi = maxY();
        bool hit = false;
        if (y < lo || y > hi) {
            y = qBound(lo, y, hi);
            hit = true;
        }
        m_writing = true;
        m_written = y;
        f->setProperty("contentY", y);
        m_writing = false;
        if (hit) {
            const qreal v = m_distance * FlingSpline::velocityCoefficient(t) / (m_duration / 1000.0);
            setMode(Idle);
            absorb(v);
        } else if (t >= 1) {
            setMode(Idle);
        }
        return;
    }
    if (m_mode == Spring) {
        const qreal k = NATURAL_FREQUENCY * NATURAL_FREQUENCY;
        qreal x, v;
        SpringMath::step(k, DAMPING_RATIO, m_springX0, m_springV0, ms / 1000.0, &x, &v);
        const qreal h = height();
        const qreal side = m_springX0 != 0 ? m_springX0 : m_springV0;
        if (qAbs(x) > h) {
            /* AOSP: at most one height, then back from there at rest */
            m_springX0 = x > 0 ? h : -h;
            m_springV0 = 0;
            setPull(m_springX0 / h);
            setMode(Idle);
            setMode(Spring);
            return;
        }
        /* AOSP isAtEquilibrium: back at (or through) the edge, or still */
        if (ms > 0 && (x * side <= 0 || (qAbs(x) < 0.25 && qAbs(v) < 5))) {
            setPull(0);
            setMode(Idle);
            return;
        }
        setPull(x / h);
    }
}
