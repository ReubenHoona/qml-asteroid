/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef EDGEEFFECT_H
#define EDGEEFFECT_H

#include <QObject>
#include <QPointer>
#include <QEasingCurve>
#include <QQmlParserStatus>
#include <QtQml/qqmlregistration.h>

class QQuickItem;

/*
 * EdgeEffect: how much a row of a scrolling list shrinks and fades near the
 * top and bottom of a round screen, as Wear OS's ScalingLazyColumn and
 * TransformingLazyColumn do (androidx wear compose: edge scale 0.7, edge
 * alpha 0.5, a transition area of 35% of the viewport for rows up to 20%
 * of its height growing to 55% for rows of 60%, eased with
 * CubicBezier(0.3, 0, 0.7, 1)).
 *
 * The row only reads the two values and applies them where it wants
 * (a Scale transform and the opacity of its content), so nothing in the
 * layout changes and the work per frame is a transform and an opacity:
 *
 *   EdgeEffect { id: edge; item: row }
 *   transform: Scale { origin.x: row.width / 2; origin.y: row.height / 2
 *                      xScale: edge.scale; yScale: edge.scale }
 *
 * The effect finds the Flickable (ListView, GridView, Flickable) the item
 * scrolls in by itself, and stays at 1 when there is none, when the view
 * does not scroll vertically, on a square screen, or when disabled.
 */
class EdgeEffect : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    QML_NAMED_ELEMENT(EdgeEffect)

    Q_PROPERTY(QQuickItem *item READ item WRITE setItem NOTIFY itemChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(qreal scale READ scale NOTIFY valuesChanged)
    Q_PROPERTY(qreal alpha READ alpha NOTIFY valuesChanged)
    Q_PROPERTY(QQuickItem *flickable READ flickable NOTIFY flickableChanged)

public:
    explicit EdgeEffect(QObject *parent = nullptr);

    QQuickItem *item() const { return m_item; }
    void setItem(QQuickItem *item);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    qreal scale() const { return m_scale; }
    qreal alpha() const { return m_alpha; }
    QQuickItem *flickable() const { return m_flickable; }

    void classBegin() override {}
    void componentComplete() override;

signals:
    void itemChanged();
    void enabledChanged();
    void valuesChanged();
    void flickableChanged();

private slots:
    void findFlickable();
    void update();
    void updateContentHeight();

private:
    QPointer<QQuickItem> m_item;
    QPointer<QQuickItem> m_flickable;
    QList<QMetaObject::Connection> m_connections;
    QList<QPointer<QQuickItem>> m_watchedParents;
    bool m_enabled = true;
    bool m_complete = false;
    qreal m_scale = 1;
    qreal m_alpha = 1;
    /* the flickable's content height with its margins, read when it
     * changes, not on every scrolled pixel */
    qreal m_contentH = 0;
    QEasingCurve m_curve;
};

#endif // EDGEEFFECT_H
