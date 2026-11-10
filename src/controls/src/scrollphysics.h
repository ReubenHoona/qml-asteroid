/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef SCROLLPHYSICS_H
#define SCROLLPHYSICS_H

#include <QAbstractAnimation>
#include <QObject>
#include <QPointer>
#include <QQmlParserStatus>
#include <QtQml/qqmlregistration.h>

class QQuickItem;

/*
 * ScrollPhysics: Wear OS list physics for a vertical Flickable (ListView,
 * GridView, Flickable):
 *
 * - Fling: Android's spline decay (OverScroller, config_scrollFriction
 *   0.015) instead of Qt's constant deceleration, at most 2750 dp/s
 *   (config_viewMaxFlingVelocity, 5500 px/s on the Pixel Watch 2).
 *   2000 px/s goes 389 px in 555 ms (Qt's default: 1333 px in 1.3 s).
 * - Stretch overscroll (EdgeEffect TYPE_STRETCH): at an end the content does
 *   not move past the edge, it stretches: stretchScale = 1 + 0.016 d +
 *   0.016 (1 - exp(-d e / 0.33)) for a pull d (fraction of the height),
 *   about the pulled edge; let go, it springs back (natural frequency
 *   24.657 rad/s, damping 0.98); a fling that hits an end is absorbed into
 *   the same spring.
 *
 *   ListView {
 *       id: list
 *       ScrollPhysics { id: physics }          // the parent Flickable
 *       transform: Scale { origin.y: physics.stretchOrigin
 *                          yScale: physics.stretchScale }
 *   }
 *
 * Nothing runs while the list rests: the frame driver stops with the fling
 * or the spring. The crown scrolls the list without a stretch (stock gives
 * a limit haptic instead).
 *
 * Every other list gets the stock fling too (motion-transitions-19): when a
 * finger goes down on a vertical, free-scrolling Flickable that has no
 * ScrollPhysics of its own, RotaryInput (the window event filter) calls
 * installStockFling(), which attaches a fling-only ScrollPhysics: the
 * spline and the 2750 dp/s limit, no stretch, the bounds behaviour left as
 * the application set it. Left alone: views that snap (Qt snaps them),
 * views that also scroll horizontally, views whose flickDeceleration or
 * maximumFlickVelocity the application changed, and views that declare
 * `property bool asteroidStockFling: false`.
 */
class ScrollPhysics : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    QML_NAMED_ELEMENT(ScrollPhysics)

    Q_PROPERTY(QQuickItem *flickable READ flickable WRITE setFlickable NOTIFY flickableChanged)
    Q_PROPERTY(bool flingEnabled READ flingEnabled WRITE setFlingEnabled NOTIFY flingEnabledChanged)
    Q_PROPERTY(bool stretchEnabled READ stretchEnabled WRITE setStretchEnabled NOTIFY stretchEnabledChanged)
    Q_PROPERTY(qreal maximumVelocity READ maximumVelocity NOTIFY densityChanged)
    Q_PROPERTY(bool flinging READ flinging NOTIFY flingingChanged)
    Q_PROPERTY(qreal pull READ pull NOTIFY stretchChanged)
    Q_PROPERTY(qreal stretchScale READ stretchScale NOTIFY stretchChanged)
    Q_PROPERTY(qreal stretchOrigin READ stretchOrigin NOTIFY stretchChanged)

public:
    explicit ScrollPhysics(QObject *parent = nullptr);
    ~ScrollPhysics() override;

    QQuickItem *flickable() const;
    void setFlickable(QQuickItem *f);
    bool flingEnabled() const { return m_flingEnabled; }
    void setFlingEnabled(bool e);
    bool stretchEnabled() const { return m_stretchEnabled; }
    void setStretchEnabled(bool e);
    /* px per dp from the window (2.0 on the Pixel Watch 2) */
    qreal density() const;
    qreal maximumVelocity() const { return MAX_FLING_DP * density(); }
    bool flinging() const { return m_mode == Fling; }
    qreal pull() const { return m_pull; }
    qreal stretchScale() const;
    qreal stretchOrigin() const;

    /* Fling the content: velocity in px/s, positive = contentY grows */
    Q_INVOKABLE void fling(qreal velocity);
    /* A fling hit the end with this velocity (px/s, positive = towards
     * the bottom end) */
    Q_INVOKABLE void absorb(qreal velocity);
    /* Overscroll pull in px (positive: down at the top end) */
    Q_INVOKABLE void pullTo(qreal px);
    /* The finger left: the stretch springs back */
    Q_INVOKABLE void release();
    Q_INVOKABLE void stop();
    /* Attach a fling-only ScrollPhysics to a plain vertical Flickable, once;
     * returns whether the Flickable has the stock fling (its own or this) */
    static bool installStockFling(QQuickItem *flickable);
    /* The ScrollPhysics driving a Flickable, if any */
    Q_INVOKABLE static ScrollPhysics *physicsOf(QQuickItem *flickable);
    /* true for the fling-only physics installStockFling() made */
    bool isGlobal() const { return m_global; }
    /* The spline, for tests: distance (px) and duration (ms) of a fling */
    Q_INVOKABLE qreal flingDistance(qreal velocity) const;
    Q_INVOKABLE qreal flingDuration(qreal velocity) const;
    /* The stretch for a pull of d (fraction of the height) */
    Q_INVOKABLE qreal stretchFor(qreal d) const;

    void classBegin() override {}
    void componentComplete() override;

    void advance(int ms);

    static constexpr qreal MAX_FLING_DP = 2750;      /* config_viewMaxFlingVelocity (values-watch) */
    static constexpr qreal FRICTION = 0.015;         /* config_scrollFriction */
    static constexpr qreal STRETCH_INTENSITY = 0.016;    /* linear and exponential */
    static constexpr qreal SCROLL_DIST_AFFECTED = 0.33;
    static constexpr qreal NATURAL_FREQUENCY = 24.657;
    static constexpr qreal DAMPING_RATIO = 0.98;
    static constexpr qreal ABSORB_ADJUSTMENT = 13;

signals:
    void flickableChanged();
    void flingEnabledChanged();
    void stretchEnabledChanged();
    void densityChanged();
    void flingingChanged();
    void stretchChanged();

private slots:
    void onFlickStarted();
    void onDraggingChanged();
    void onOvershootChanged();
    void onContentYChanged();

private:
    enum Mode { Idle, Fling, Spring };
    void attach();
    void setMode(Mode m);
    void setPull(qreal p);
    qreal minY() const;
    qreal maxY() const;
    qreal height() const;

    QPointer<QQuickItem> m_flickable;
    QList<QMetaObject::Connection> m_connections;
    QAbstractAnimation *m_driver = nullptr;
    Mode m_mode = Idle;
    bool m_flingEnabled = true;
    bool m_stretchEnabled = true;
    bool m_complete = false;
    bool m_global = false;
    bool m_writing = false;
    /* fling */
    qreal m_start = 0;
    qreal m_distance = 0;
    qreal m_duration = 0;
    qreal m_written = 0;
    /* stretch: pull as a fraction of the height (+ top, - bottom) */
    qreal m_pull = 0;
    qreal m_springX0 = 0;
    qreal m_springV0 = 0;
};

#endif // SCROLLPHYSICS_H
