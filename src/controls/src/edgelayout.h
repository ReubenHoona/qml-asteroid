/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef EDGELAYOUT_H
#define EDGELAYOUT_H

#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class QQuickItem;
class EdgeEffect;

/*
 * The edge transformation of a Wear OS list (TransformingLazyColumn) as a
 * spec, and the packed layout that keeps the shrunk rows 8 px apart: the
 * launcher's WearEdge.js (asteroid-launcher src/applauncher/wear,
 * evaluate(), layout(), transformedHeight()) in C++, the same numbers.
 *
 * A spec (WearEdge.js format; every key optional, missing keys take the
 * SCALING values):
 *   minElementHeight, maxElementHeight   viewport fractions (0.2, 0.6)
 *   minArea, maxArea                     the transition area (0.35, 0.55)
 *   easing                               [x1, y1, x2, y2] ([0.3, 0, 0.7, 1])
 *   scale, containerAlpha, contentAlpha, sideOffset
 *       { top, target, bottom, enter, exit }: the value at the top edge,
 *       inside, at the bottom edge, and the zone of x it changes over
 *       (scale 0.7, alphas 0.5, target 1, zone 0-1; sideOffset none)
 *
 * SCALING is the spec of eos EdgeEffect and ScalingList (androidx wear
 * ScalingLazyColumnDefaults / ResponsiveTransformationSpecDefaults for
 * 192 dp screens): edge scale 0.7, alpha 0.5, area 0.35-0.55 for rows of
 * 0.2-0.6 of the viewport, easing (0.3, 0, 0.7, 1), measured from the
 * row's edge nearest the centre. The Wear OS 6 emulator draws Settings
 * with it (S16-S22: a row bottom at y 74 is at 0.85 / 0.75, a row top at
 * y 347 at 0.75 / 0.58, 8 px between rows at every scale).
 */
struct EdgeSpec
{
    struct Variable {
        qreal top;
        qreal target;
        qreal bottom;
        qreal enter;
        qreal exit;
    };
    qreal minElementHeight = 0.2;
    qreal maxElementHeight = 0.6;
    qreal minArea = 0.35;
    qreal maxArea = 0.55;
    qreal easing[4] = { 0.3, 0.0, 0.7, 1.0 };
    Variable scale = { 0.7, 1, 0.7, 0, 1 };
    Variable containerAlpha = { 0.5, 1, 0.5, 0, 1 };
    Variable contentAlpha = { 0.5, 1, 0.5, 0, 1 };
    bool hasSideOffset = false;
    Variable sideOffset = { 0, 0, 0, 0, 1 };

    static EdgeSpec fromVariant(const QVariantMap &map);
    QVariantMap toVariant() const;
};

/* The values of one item (WearEdge.js evaluate()) */
struct EdgeValues
{
    qreal l = 0;
    qreal x = 1;
    qreal scale = 1;
    qreal containerAlpha = 1;
    qreal contentAlpha = 1;
    qreal sideOffset = 0;
};

/* Where an item is drawn (WearEdge.js layout()): y the top of its picture
 * (scaled about its top), height its transformed height, side -1 above
 * the anchor, 0 the anchor, 1 below it; shown false beyond the screen */
struct EdgePlace
{
    qreal y = 0;
    qreal height = 0;
    EdgeValues v;
    int side = 0;
    bool shown = true;
};

/*
 * EdgeLayout (QML singleton): the functions for QML.
 *
 *   EdgeLayout.scaling                     the SCALING spec (a map)
 *   EdgeLayout.evaluate(spec, top, h, reduced)
 *       { l, x, scale, containerAlpha, contentAlpha, sideOffset } of an
 *       item at top with height h (viewport fractions)
 *   EdgeLayout.layout(spec, tops, heights, gaps, viewportHeight, reduced)
 *       for every item { y, height, scale, containerAlpha, contentAlpha,
 *       sideOffset, shown, side }: tops in viewport px (natural places),
 *       gaps[i] between item i and i + 1. The item nearest the middle stays
 *       where it is; the ones below follow it downwards from its bottom and
 *       the ones above upwards from its top, each at ceil(scale x height)
 *       plus its gap, with the values of the place it comes to.
 *   EdgeLayout.transformedHeight(h, scale)  ceil(scale x h)
 *
 * A row keeps its natural place in the Flickable (the list scrolls evenly
 * at its natural length); what moves is its picture: a Scale about its
 * edge nearest the centre (origin.y 0 at and below the anchor, its height
 * above it) and a Translate to the place the layout gives. EdgeEffect does
 * this by itself with `packed: true` (ScalingList, ListItem, ListRow,
 * ListHeader and ListSubHeader).
 */
class EdgeLayout : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantMap scaling READ scaling CONSTANT)

public:
    explicit EdgeLayout(QObject *parent = nullptr);

    QVariantMap scaling() const;

    Q_INVOKABLE QVariantMap evaluate(const QVariantMap &spec, qreal top, qreal height, bool reduced = false) const;
    Q_INVOKABLE QVariantList layout(const QVariantMap &spec, const QVariantList &tops, const QVariantList &heights,
                                    const QVariantList &gaps, qreal viewportHeight, bool reduced = false) const;
    Q_INVOKABLE qreal transformedHeight(qreal height, qreal scale) const { return ceilHeight(height, scale); }

    /* the C++ side, shared with EdgeEffect */
    static qreal bezier(const qreal e[4], qreal x);
    static qreal progress(const EdgeSpec &spec, qreal top, qreal h);
    static qreal value(qreal l, const EdgeSpec::Variable &v, const qreal e[4]);
    static EdgeValues evaluate(const EdgeSpec &spec, qreal top, qreal h, bool reduced);
    static qreal ceilHeight(qreal h, qreal scale);
    /* one spec per item (specs[i]); returns the anchor in *anchor.
     * innerAnchor: an anchor above the middle scales about its bottom
     * (side -1) instead of its top, so a list whose middle row is still
     * shrinking (a short list, a lone header) keeps the inner edge too;
     * WearEdge.js (innerAnchor false) always uses the top. */
    static QVector<EdgePlace> layout(const QVector<const EdgeSpec *> &specs, const QVector<qreal> &tops,
                                     const QVector<qreal> &hs, const QVector<qreal> &gaps, qreal vh,
                                     bool reduced, int *anchor = nullptr, bool innerAnchor = false);
};

/*
 * The packed layout of one Flickable's rows: every EdgeEffect in the
 * Flickable joins its packer; the ones with `packed: true` are laid out
 * together on every move (EdgeLayout::layout) and get their scale,
 * alphas, translateY and originY from it; every row, the middle one too,
 * scales about its edge nearest the centre. A packed effect sits out (at
 * rest) when its item, or an item it is inside, carries another
 * EdgeEffect: a ListItem given to a ScalingList as its itemDelegate, or a
 * ListHeader with an EdgeEffect of the page's own.
 */
class EdgePacker : public QObject
{
    Q_OBJECT

public:
    static EdgePacker *forFlickable(QQuickItem *flickable);

    void add(EdgeEffect *effect);
    void remove(EdgeEffect *effect);
    QQuickItem *flickable() const { return m_flickable; }

public slots:
    /* now: the list moved (contentY, height) */
    void relayout();
    /* once, before the next frame is synchronised (after the polish that
     * places the items): rows added, removed, moved or resized */
    void scheduleRelayout();

private slots:
    void flushScheduled();

private:
    explicit EdgePacker(QQuickItem *flickable);
    ~EdgePacker() override;
    void doLayout();

    QPointer<QQuickItem> m_flickable;
    /* the registry key (m_flickable is already null when it goes) */
    QQuickItem *m_key = nullptr;
    QList<QPointer<EdgeEffect>> m_effects;
    bool m_busy = false;
    bool m_again = false;
    bool m_scheduled = false;
};

#endif // EDGELAYOUT_H
