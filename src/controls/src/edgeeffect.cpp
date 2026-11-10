/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "edgeeffect.h"
#include "spring.h"

#include <QQuickItem>
#include <QSettings>
#include <QtMath>

/* androidx wear compose foundation ScalingLazyColumnDefaults.scalingParams
 * and material3 ResponsiveTransformationSpecDefaults (192 dp screens,
 * CP3A SysUI ResponsiveTransformationSpecDefaults.java:17; Settings
 * ScalingLazyColumnDefaults.java:13-25). The edge scale and alphas are
 * per instance (edgeScale, edgeAlpha, edgeContentAlpha). */
static const qreal MIN_ELEMENT_HEIGHT = 0.2;
static const qreal MAX_ELEMENT_HEIGHT = 0.6;
static const qreal MIN_TRANSITION_AREA = 0.35;
static const qreal MAX_TRANSITION_AREA = 0.55;

static bool roundScreen()
{
    static int round = -1;
    if (round < 0) {
        QSettings machineConf(QStringLiteral("/etc/asteroid/machine.conf"), QSettings::IniFormat);
        round = machineConf.value(QStringLiteral("Display/ROUND"), false).toBool() ? 1 : 0;
    }
    return round == 1;
}

EdgeEffect::EdgeEffect(QObject *parent) : QObject(parent),
    m_curve(QEasingCurve::BezierSpline)
{
    setEasing(QVariantList{0.3, 0.0, 0.7, 1.0});
    connect(ReduceMotion::instance(), &ReduceMotion::changed, this, &EdgeEffect::update);
}

void EdgeEffect::setEdgeScale(qreal s)
{
    if (qFuzzyCompare(s, m_edgeScale))
        return;
    m_edgeScale = s;
    emit specChanged();
    update();
}

void EdgeEffect::setEdgeAlpha(qreal a)
{
    if (qFuzzyCompare(a, m_edgeAlpha))
        return;
    m_edgeAlpha = a;
    emit specChanged();
    update();
}

void EdgeEffect::setEdgeContentAlpha(qreal a)
{
    if (qFuzzyCompare(a, m_edgeContentAlpha))
        return;
    m_edgeContentAlpha = a;
    emit specChanged();
    update();
}

void EdgeEffect::setEasing(const QVariantList &e)
{
    if (e.size() != 4 || e == m_easing)
        return;
    m_easing = e;
    m_curve = QEasingCurve(QEasingCurve::BezierSpline);
    m_curve.addCubicBezierSegment(QPointF(e[0].toReal(), e[1].toReal()),
                                  QPointF(e[2].toReal(), e[3].toReal()), QPointF(1.0, 1.0));
    emit specChanged();
    update();
}

void EdgeEffect::setMeasure(Measure m)
{
    if (m == m_measure)
        return;
    m_measure = m;
    emit specChanged();
    update();
}

qreal EdgeEffect::valueAt(qreal x, qreal edgeValue) const
{
    /* TransitionAreaProgress.compute: lerp(edge, 1, easing(x)) */
    return edgeValue + (1 - edgeValue) * m_curve.valueForProgress(qBound<qreal>(0, x, 1));
}

qreal EdgeEffect::transformedHeight() const
{
    /* ResponsiveTransformationSpecImpl.getTransformedHeight: ceil(s h) */
    return m_item ? qCeil(m_scale * m_item->height()) : 0;
}

qreal EdgeEffect::offsetY() const
{
    return m_item ? -(1 - m_scale) * m_item->height() / 2 : 0;
}

void EdgeEffect::setItem(QQuickItem *item)
{
    if (m_item == item)
        return;
    m_item = item;
    emit itemChanged();
    if (m_complete)
        findFlickable();
}

void EdgeEffect::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    emit enabledChanged();
    update();
}

void EdgeEffect::componentComplete()
{
    m_complete = true;
    if (!m_item)
        setItem(qobject_cast<QQuickItem *>(parent()));
    findFlickable();
}

void EdgeEffect::findFlickable()
{
    for (const QMetaObject::Connection &c : std::as_const(m_connections))
        disconnect(c);
    m_connections.clear();
    m_watchedParents.clear();

    QQuickItem *found = nullptr;
    if (m_item && roundScreen()) {
        /* Delegates and Column children get their parents after creation:
         * watch every parent on the way up and look again if one changes */
        for (QQuickItem *p = m_item; p; p = p->parentItem()) {
            m_connections << connect(p, &QQuickItem::parentChanged, this, &EdgeEffect::findFlickable,
                                     Qt::UniqueConnection);
            QQuickItem *up = p->parentItem();
            if (up && up->inherits("QQuickFlickable")) {
                found = up;
                break;
            }
            if (p != m_item) {
                /* moving parents (a Column relaying out) move the item */
                m_connections << connect(p, &QQuickItem::yChanged, this, &EdgeEffect::update);
            }
        }
    }
    if (found) {
        m_connections << connect(found, SIGNAL(contentYChanged()), this, SLOT(update()));
        m_connections << connect(found, SIGNAL(contentHeightChanged()), this, SLOT(updateContentHeight()));
        m_connections << connect(found, SIGNAL(topMarginChanged()), this, SLOT(updateContentHeight()));
        m_connections << connect(found, SIGNAL(bottomMarginChanged()), this, SLOT(updateContentHeight()));
        m_connections << connect(found, &QQuickItem::heightChanged, this, &EdgeEffect::update);
        m_connections << connect(m_item, &QQuickItem::yChanged, this, &EdgeEffect::update);
        m_connections << connect(m_item, &QQuickItem::heightChanged, this, &EdgeEffect::update);
    }
    if (m_flickable != found) {
        m_flickable = found;
        emit flickableChanged();
    }
    updateContentHeight();
}

void EdgeEffect::updateContentHeight()
{
    QQuickItem *f = m_flickable;
    m_contentH = f ? f->property("contentHeight").toReal() + f->property("topMargin").toReal()
                     + f->property("bottomMargin").toReal()
                   : 0;
    update();
}

void EdgeEffect::update()
{
    qreal scale = 1;
    qreal alpha = 1;
    qreal contentAlpha = 1;
    QQuickItem *f = m_flickable;
    const bool reduced = ReduceMotion::instance()->enabled();
    if (m_enabled && !reduced && m_item && f && f->height() > 0) {
        const qreal viewH = f->height();
        /* the item in viewport fractions, at its own (untransformed) height;
         * stock transforms whether or not the list can scroll */
        const qreal h = m_item->height() / viewH;
        const qreal top = m_item->mapToItem(f, QPointF(0, 0)).y() / viewH;
        const qreal bottom = top + h;
        const qreal heightFraction = qBound<qreal>(0, (h - MIN_ELEMENT_HEIGHT)
                                                   / (MAX_ELEMENT_HEIGHT - MIN_ELEMENT_HEIGHT), 1);
        qreal area = MIN_TRANSITION_AREA + (MAX_TRANSITION_AREA - MIN_TRANSITION_AREA) * heightFraction;
        /* x: 0 at the screen edge, 1 at the inner end of the area (no change) */
        qreal x = 1;
        if (m_measure == Center) {
            const qreal center = (top + bottom) / 2;
            x = qMin(center, 1 - center) / area;
        } else {
            /* ResponsiveTransformationSpecKt.TransitionAreaProgress */
            area = qMin(area, (h + 1) / 2);
            x = bottom < 1 - top ? bottom / area : (1 - top) / area;
        }
        if (x < 1) {
            scale = valueAt(x, m_edgeScale);
            alpha = valueAt(x, m_edgeAlpha);
            contentAlpha = valueAt(x, m_edgeContentAlpha);
        }
    }
    const qreal itemH = m_item ? m_item->height() : 0;
    if (!qFuzzyCompare(scale, m_scale) || !qFuzzyCompare(alpha, m_alpha)
            || !qFuzzyCompare(contentAlpha, m_contentAlpha) || itemH != m_itemH) {
        m_itemH = itemH;
        m_scale = scale;
        m_alpha = alpha;
        m_contentAlpha = contentAlpha;
        emit valuesChanged();
    }
}
