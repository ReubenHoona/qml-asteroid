/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "edgeeffect.h"

#include <QQuickItem>
#include <QSettings>
#include <QtMath>

/* androidx wear compose foundation ScalingLazyColumnDefaults.scalingParams
 * and material3 ResponsiveTransformationSpec (small screens, 192 dp) */
static const qreal EDGE_SCALE = 0.7;
static const qreal EDGE_ALPHA = 0.5;
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
    m_curve.addCubicBezierSegment(QPointF(0.3, 0.0), QPointF(0.7, 1.0), QPointF(1.0, 1.0));
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
    QQuickItem *f = m_flickable;
    if (m_enabled && m_item && f && f->height() > 0) {
        const qreal viewH = f->height();
        if (m_contentH > viewH + 1) {
            const qreal h = m_item->height() * m_item->scale();
            const qreal center = m_item->mapToItem(f, QPointF(0, m_item->height() / 2)).y();
            const qreal heightFraction = qBound<qreal>(0, (h / viewH - MIN_ELEMENT_HEIGHT)
                                                       / (MAX_ELEMENT_HEIGHT - MIN_ELEMENT_HEIGHT), 1);
            const qreal zone = viewH * (MIN_TRANSITION_AREA
                                        + (MAX_TRANSITION_AREA - MIN_TRANSITION_AREA) * heightFraction);
            const qreal edgeDistance = qMin(center, viewH - center);
            if (edgeDistance < zone) {
                const qreal t = m_curve.valueForProgress(qBound<qreal>(0, edgeDistance / zone, 1));
                scale = EDGE_SCALE + (1 - EDGE_SCALE) * t;
                alpha = EDGE_ALPHA + (1 - EDGE_ALPHA) * t;
            }
        }
    }
    if (!qFuzzyCompare(scale, m_scale) || !qFuzzyCompare(alpha, m_alpha)) {
        m_scale = scale;
        m_alpha = alpha;
        emit valuesChanged();
    }
}
