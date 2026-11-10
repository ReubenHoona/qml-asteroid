/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "spring.h"

#include <QVariant>
#include <QtMath>
#include <MDConfItem>

/* ---- SpringMath ---- */

void SpringMath::step(qreal k, qreal z, qreal x0, qreal v0, qreal t, qreal *x, qreal *v)
{
    const qreal w = qSqrt(qMax<qreal>(k, 1e-6));
    qreal px, pv;
    if (qAbs(z - 1) < 1e-6) {
        /* critically damped */
        const qreal e = qExp(-w * t);
        const qreal b = v0 + w * x0;
        px = e * (x0 + b * t);
        pv = e * (v0 - w * t * b);
    } else if (z < 1) {
        const qreal wd = w * qSqrt(1 - z * z);
        const qreal e = qExp(-z * w * t);
        const qreal a = x0;
        const qreal b = (v0 + z * w * x0) / wd;
        const qreal c = qCos(wd * t), s = qSin(wd * t);
        px = e * (a * c + b * s);
        pv = e * (-z * w * (a * c + b * s) + wd * (-a * s + b * c));
    } else {
        const qreal r = w * qSqrt(z * z - 1);
        const qreal r1 = -z * w + r, r2 = -z * w - r;
        const qreal c2 = (r1 * x0 - v0) / (r1 - r2);
        const qreal c1 = x0 - c2;
        const qreal e1 = qExp(r1 * t), e2 = qExp(r2 * t);
        px = c1 * e1 + c2 * e2;
        pv = c1 * r1 * e1 + c2 * r2 * e2;
    }
    if (x)
        *x = px;
    if (v)
        *v = pv;
}

qreal SpringMath::settleTime(qreal k, qreal z, qreal fraction)
{
    /* the last time a unit step at rest is outside the band, 0.1 ms steps */
    qreal last = 0;
    const qreal dt = 0.0001;
    for (qreal t = dt; t < 10; t += dt) {
        qreal x;
        step(k, z, 1, 0, t, &x, nullptr);
        if (qAbs(x) > fraction)
            last = t;
        else if (z >= 1)
            break;   /* no overshoot: it stays inside */
        else if (t - last > 4 * M_PI / (qSqrt(k) * qSqrt(1 - z * z)))
            break;   /* two periods inside the band */
    }
    return last;
}

/* ---- FlingSpline (AOSP OverScroller.SplineOverScroller) ---- */

namespace {
const int NB_SAMPLES = 100;
const qreal INFLEXION = 0.35;
const qreal START_TENSION = 0.5;
const qreal END_TENSION = 1.0;
const qreal P1 = START_TENSION * INFLEXION;
const qreal P2 = 1.0 - END_TENSION * (1.0 - INFLEXION);
/* ln(0.78) / ln(0.9) */
const qreal DECELERATION_RATE = 2.3582017;
const qreal GRAVITY_EARTH = 9.80665;

struct SplineTable {
    qreal position[NB_SAMPLES + 1];
    SplineTable()
    {
        qreal xMin = 0;
        for (int i = 0; i < NB_SAMPLES; i++) {
            const qreal alpha = qreal(i) / NB_SAMPLES;
            qreal xMax = 1, x, tx, coef;
            while (true) {
                x = xMin + (xMax - xMin) / 2;
                coef = 3 * x * (1 - x);
                tx = coef * ((1 - x) * P1 + x * P2) + x * x * x;
                if (qAbs(tx - alpha) < 1e-5)
                    break;
                if (tx > alpha)
                    xMax = x;
                else
                    xMin = x;
            }
            position[i] = coef * ((1 - x) * START_TENSION + x) + x * x * x;
        }
        position[NB_SAMPLES] = 1;
    }
};

const SplineTable &table()
{
    static const SplineTable t;
    return t;
}

qreal physicalCoeff(qreal ppi)
{
    return GRAVITY_EARTH * 39.37 * ppi * 0.84;
}

qreal splineDeceleration(qreal velocity, qreal ppi, qreal friction)
{
    return qLn(INFLEXION * qAbs(velocity) / (friction * physicalCoeff(ppi)));
}
}

qreal FlingSpline::distance(qreal velocity, qreal ppi, qreal friction)
{
    if (velocity == 0)
        return 0;
    const qreal l = splineDeceleration(velocity, ppi, friction);
    return friction * physicalCoeff(ppi) * qExp(DECELERATION_RATE / (DECELERATION_RATE - 1) * l);
}

qreal FlingSpline::duration(qreal velocity, qreal ppi, qreal friction)
{
    if (velocity == 0)
        return 0;
    const qreal l = splineDeceleration(velocity, ppi, friction);
    return 1000.0 * qExp(l / (DECELERATION_RATE - 1));
}

qreal FlingSpline::position(qreal t)
{
    t = qBound<qreal>(0, t, 1);
    const int index = int(NB_SAMPLES * t);
    if (index >= NB_SAMPLES)
        return 1;
    const qreal tInf = qreal(index) / NB_SAMPLES;
    const qreal tSup = qreal(index + 1) / NB_SAMPLES;
    const qreal dInf = table().position[index];
    const qreal dSup = table().position[index + 1];
    return dInf + (t - tInf) * (dSup - dInf) / (tSup - tInf);
}

qreal FlingSpline::velocityCoefficient(qreal t)
{
    t = qBound<qreal>(0, t, 1);
    const int index = qMin(int(NB_SAMPLES * t), NB_SAMPLES - 1);
    return (table().position[index + 1] - table().position[index]) * NB_SAMPLES;
}

/* ---- ReduceMotion ---- */

ReduceMotion *ReduceMotion::instance()
{
    static ReduceMotion *s = nullptr;
    if (!s)
        s = new ReduceMotion();
    return s;
}

ReduceMotion::ReduceMotion(QObject *parent) : QObject(parent)
{
    /* stock Settings.Global reduce_motion (Accessibility > Reduce
     * animations); dconf notifies changes, nothing is polled */
    m_item = new MDConfItem(QStringLiteral("/org/asteroidos/a11y/reduce-motion"), this);
    connect(m_item, &MDConfItem::valueChanged, this, &ReduceMotion::update);
    update();
}

void ReduceMotion::setOverride(int value)
{
    m_override = value;
    update();
}

void ReduceMotion::update()
{
    const bool on = m_override >= 0 ? m_override > 0 : m_item->value(false).toBool();
    if (on == m_enabled)
        return;
    m_enabled = on;
    emit changed();
}

/* ---- WearSpring ---- */

namespace {
class SpringDriver : public QAbstractAnimation
{
public:
    explicit SpringDriver(WearSpring *s) : QAbstractAnimation(s), m_spring(s) { }
    int duration() const override { return -1; }

protected:
    void updateCurrentTime(int t) override { m_spring->advance(t); }

private:
    WearSpring *m_spring;
};
}

WearSpring::WearSpring(QObject *parent) : QObject(parent)
{
    m_driver = new SpringDriver(this);
    connect(m_driver, &QAbstractAnimation::stateChanged, this, &WearSpring::runningChanged);
    connect(ReduceMotion::instance(), &ReduceMotion::changed, this, &WearSpring::reduceMotionChanged);
}

WearSpring::~WearSpring()
{
    m_driver->stop();
}

bool WearSpring::running() const
{
    return m_driver->state() == QAbstractAnimation::Running;
}

bool WearSpring::reduceMotion() const
{
    return ReduceMotion::instance()->enabled();
}

void WearSpring::setTarget(QObject *t)
{
    if (m_target == t)
        return;
    m_target = t;
    emit targetChanged();
}

void WearSpring::setProperty(const QString &p)
{
    if (m_property == p)
        return;
    m_property = p;
    emit propertyChanged();
}

void WearSpring::setStiffness(qreal k)
{
    if (k <= 0 || qFuzzyCompare(k, m_stiffness))
        return;
    /* a spring in flight keeps its position and speed */
    if (running()) {
        m_stiffness = k;
        start(m_velocity);
    } else {
        m_stiffness = k;
    }
    emit specChanged();
}

void WearSpring::setDampingRatio(qreal z)
{
    if (z <= 0 || qFuzzyCompare(z, m_damping))
        return;
    m_damping = z;
    if (running())
        start(m_velocity);
    emit specChanged();
}

void WearSpring::setVisibilityThreshold(qreal t)
{
    if (t <= 0 || qFuzzyCompare(t, m_threshold))
        return;
    m_threshold = t;
    emit specChanged();
}

void WearSpring::setStopAtFraction(qreal f)
{
    f = qBound<qreal>(0, f, 1);
    if (qFuzzyCompare(f, m_stopAt))
        return;
    m_stopAt = f;
    emit specChanged();
}

void WearSpring::setEnabled(bool e)
{
    if (e == m_enabled)
        return;
    m_enabled = e;
    if (!e && running())
        snapTo(m_to);
    emit enabledChanged();
}

void WearSpring::setTo(qreal to)
{
    m_toSet = true;
    if (qFuzzyCompare(to + 1, m_to + 1))
        return;
    m_to = to;
    emit toChanged();
    if (!m_complete)
        return;
    if (!m_enabled) {
        snapTo(to);
        return;
    }
    start(m_velocity);
}

void WearSpring::componentComplete()
{
    m_complete = true;
    bool ok = false;
    const qreal current = readTarget(&ok);
    if (m_toSet) {
        /* like a Behavior: the first value is set, not animated */
        setValueInternal(m_to, 0);
        write();
    } else if (ok) {
        m_to = current;
        setValueInternal(current, 0);
    }
}

qreal WearSpring::readTarget(bool *ok) const
{
    *ok = false;
    if (!m_target || m_property.isEmpty())
        return 0;
    const QVariant v = m_target->property(m_property.toUtf8().constData());
    if (!v.isValid())
        return 0;
    return v.toReal(ok);
}

void WearSpring::animateTo(qreal to, qreal velocity)
{
    if (!qFuzzyCompare(to + 1, m_to + 1)) {
        m_to = to;
        m_toSet = true;
        emit toChanged();
    }
    if (!m_enabled) {
        snapTo(to);
        return;
    }
    start(qIsNaN(velocity) ? m_velocity : velocity);
}

void WearSpring::snapTo(qreal v)
{
    m_driver->stop();
    if (!qFuzzyCompare(v + 1, m_to + 1)) {
        m_to = v;
        emit toChanged();
    }
    setValueInternal(v, 0);
    write();
}

void WearSpring::stop()
{
    m_driver->stop();
    if (m_velocity != 0) {
        m_velocity = 0;
        emit valueChanged();
    }
}

void WearSpring::start(qreal velocity)
{
    if (!running()) {
        /* someone else may have moved the property since the last run */
        bool ok = false;
        const qreal current = readTarget(&ok);
        if (ok)
            m_value = current;
    }
    if (reduceMotion()) {
        /* animator duration scale 0: the end at once */
        m_driver->stop();
        setValueInternal(m_to, 0);
        write();
        emit finished();
        return;
    }
    m_x0 = m_value - m_to;
    m_v0 = velocity;
    m_velocity = velocity;
    m_span = qAbs(m_x0);
    m_lastMs = 0;
    if (qAbs(m_x0) < m_threshold && qAbs(m_v0) * 0.016 < m_threshold) {
        m_driver->stop();
        setValueInternal(m_to, 0);
        write();
        emit finished();
        return;
    }
    m_driver->stop();
    m_driver->start();
}

void WearSpring::advance(int ms)
{
    m_lastMs = ms;
    qreal x, v;
    SpringMath::step(m_stiffness, m_damping, m_x0, m_v0, ms / 1000.0, &x, &v);
    /* at rest: within the visibility threshold and moving less than it per
     * frame; or, for shell-style transitions, the last 2 % skipped */
    const bool rest = qAbs(x) < m_threshold && qAbs(v) * 0.016 < m_threshold;
    const bool cut = m_stopAt < 1 && m_span > 0 && qAbs(x) <= (1 - m_stopAt) * m_span;
    if (rest || cut) {
        m_driver->stop();
        setValueInternal(m_to, 0);
        write();
        emit finished();
        return;
    }
    setValueInternal(m_to + x, v);
    write();
}

void WearSpring::setValueInternal(qreal v, qreal velocity)
{
    const bool changed = !qFuzzyCompare(v + 1, m_value + 1) || velocity != m_velocity;
    m_value = v;
    m_velocity = velocity;
    if (changed)
        emit valueChanged();
}

void WearSpring::write()
{
    if (m_target && !m_property.isEmpty())
        m_target->setProperty(m_property.toUtf8().constData(), m_value);
}

qreal WearSpring::sample(qreal stiffness, qreal dampingRatio, qreal from, qreal to,
                         qreal velocity, qreal ms) const
{
    qreal x;
    SpringMath::step(stiffness, dampingRatio, from - to, velocity, ms / 1000.0, &x, nullptr);
    return to + x;
}

qreal WearSpring::settleMs(qreal stiffness, qreal dampingRatio, qreal fraction) const
{
    return SpringMath::settleTime(stiffness, dampingRatio, fraction) * 1000.0;
}
