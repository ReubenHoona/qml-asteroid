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
#include <QVariantList>
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
 * As stock (ResponsiveTransformationSpecKt.TransitionAreaProgress), the
 * progress comes from the item's edge nearest the centre: near the top its
 * bottom edge, near the bottom its top edge; the transition area is capped
 * at (1 + item height) / 2 of the viewport. Stock scales the container
 * about its top (translationY = -(1 - s) h / 2 with a centre pivot) and lays
 * the list out at the transformed height ceil(s h), so scaled rows stay
 * packed:
 *
 *   Item {                                   // the delegate
 *       height: edge.transformedHeight       // packed as stock
 *       EdgeEffect { id: edge; item: row }
 *       Item { id: row                       // the row at its own height
 *           transform: Scale { origin.x: row.width / 2; origin.y: 0
 *                              xScale: edge.scale; yScale: edge.scale }
 *           opacity: edge.alpha }
 *   }
 *
 * The values per surface are properties: Settings and most lists keep the
 * defaults (scale 0.7, alpha 0.5, easing (0.3, 0, 0.7, 1)); the
 * notification stream sets edgeScale 0.6 and easing [0, 0, 0.6, 1]
 * (SysUI kwf.java:613, hca.java:2750-2765). Accessibility > Reduce
 * animations keeps every value at 1 (ReduceMotionScalingParams).
 *
 * The effect finds the Flickable (ListView, GridView, Flickable) the item
 * scrolls in by itself, and stays at 1 when there is none, on a square
 * screen, or when disabled.
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
    Q_PROPERTY(qreal contentAlpha READ contentAlpha NOTIFY valuesChanged)
    /* ceil(scale x the item's height): the delegate's height in a packed list */
    Q_PROPERTY(qreal transformedHeight READ transformedHeight NOTIFY valuesChanged)
    /* -(1 - scale) h / 2: the shift that pins a centre-scaled item at its top */
    Q_PROPERTY(qreal offsetY READ offsetY NOTIFY valuesChanged)
    Q_PROPERTY(qreal edgeScale READ edgeScale WRITE setEdgeScale NOTIFY specChanged)
    Q_PROPERTY(qreal edgeAlpha READ edgeAlpha WRITE setEdgeAlpha NOTIFY specChanged)
    Q_PROPERTY(qreal edgeContentAlpha READ edgeContentAlpha WRITE setEdgeContentAlpha NOTIFY specChanged)
    /* the cubic Bezier control points [x1, y1, x2, y2] */
    Q_PROPERTY(QVariantList easing READ easing WRITE setEasing NOTIFY specChanged)
    Q_PROPERTY(Measure measure READ measure WRITE setMeasure NOTIFY specChanged)
    Q_PROPERTY(QQuickItem *flickable READ flickable NOTIFY flickableChanged)

public:
    /* InnerEdge: stock (the item edge nearest the centre); Center: the
     * item's centre, as before */
    enum Measure { InnerEdge, Center };
    Q_ENUM(Measure)

    explicit EdgeEffect(QObject *parent = nullptr);

    QQuickItem *item() const { return m_item; }
    void setItem(QQuickItem *item);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    qreal scale() const { return m_scale; }
    qreal alpha() const { return m_alpha; }
    qreal contentAlpha() const { return m_contentAlpha; }
    qreal transformedHeight() const;
    qreal offsetY() const;
    qreal edgeScale() const { return m_edgeScale; }
    void setEdgeScale(qreal s);
    qreal edgeAlpha() const { return m_edgeAlpha; }
    void setEdgeAlpha(qreal a);
    qreal edgeContentAlpha() const { return m_edgeContentAlpha; }
    void setEdgeContentAlpha(qreal a);
    QVariantList easing() const { return m_easing; }
    void setEasing(const QVariantList &e);
    Measure measure() const { return m_measure; }
    void setMeasure(Measure m);

    /* The stock curve, for tests: the value at a transition-area progress
     * x (0 at the edge, 1 out of the area) for an edge value */
    Q_INVOKABLE qreal valueAt(qreal x, qreal edgeValue) const;
    QQuickItem *flickable() const { return m_flickable; }

    void classBegin() override {}
    void componentComplete() override;

signals:
    void itemChanged();
    void enabledChanged();
    void valuesChanged();
    void flickableChanged();
    void specChanged();

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
    qreal m_contentAlpha = 1;
    qreal m_itemH = 0;
    qreal m_edgeScale = 0.7;
    qreal m_edgeAlpha = 0.5;
    qreal m_edgeContentAlpha = 0.5;
    QVariantList m_easing;
    Measure m_measure = InnerEdge;
    /* the flickable's content height with its margins, read when it
     * changes, not on every scrolled pixel */
    qreal m_contentH = 0;
    QEasingCurve m_curve;
};

#endif // EDGEEFFECT_H
