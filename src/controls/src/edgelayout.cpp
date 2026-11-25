/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "edgelayout.h"
#include "edgeeffect.h"
#include "spring.h"

#include <QHash>
#include <QMetaObject>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtMath>
#include <algorithm>

/* ---- the spec ---- */

static EdgeSpec::Variable variableFrom(const QVariant &v, const EdgeSpec::Variable &fallback)
{
    const QVariantMap m = v.toMap();
    if (m.isEmpty())
        return fallback;
    EdgeSpec::Variable out = fallback;
    out.top = m.value(QStringLiteral("top"), fallback.top).toReal();
    out.target = m.value(QStringLiteral("target"), fallback.target).toReal();
    out.bottom = m.value(QStringLiteral("bottom"), fallback.bottom).toReal();
    out.enter = m.value(QStringLiteral("enter"), fallback.enter).toReal();
    out.exit = m.value(QStringLiteral("exit"), fallback.exit).toReal();
    return out;
}

static QVariantMap variableMap(const EdgeSpec::Variable &v)
{
    return QVariantMap{
        { QStringLiteral("top"), v.top }, { QStringLiteral("target"), v.target },
        { QStringLiteral("bottom"), v.bottom }, { QStringLiteral("enter"), v.enter },
        { QStringLiteral("exit"), v.exit }
    };
}

EdgeSpec EdgeSpec::fromVariant(const QVariantMap &map)
{
    EdgeSpec s;
    s.minElementHeight = map.value(QStringLiteral("minElementHeight"), s.minElementHeight).toReal();
    s.maxElementHeight = map.value(QStringLiteral("maxElementHeight"), s.maxElementHeight).toReal();
    s.minArea = map.value(QStringLiteral("minArea"), s.minArea).toReal();
    s.maxArea = map.value(QStringLiteral("maxArea"), s.maxArea).toReal();
    const QVariantList e = map.value(QStringLiteral("easing")).toList();
    if (e.size() == 4) {
        for (int i = 0; i < 4; i++)
            s.easing[i] = e[i].toReal();
    }
    s.scale = variableFrom(map.value(QStringLiteral("scale")), s.scale);
    s.containerAlpha = variableFrom(map.value(QStringLiteral("containerAlpha")), s.containerAlpha);
    s.contentAlpha = variableFrom(map.value(QStringLiteral("contentAlpha")), s.contentAlpha);
    const QVariantMap side = map.value(QStringLiteral("sideOffset")).toMap();
    s.hasSideOffset = !side.isEmpty();
    if (s.hasSideOffset)
        s.sideOffset = variableFrom(side, s.sideOffset);
    return s;
}

QVariantMap EdgeSpec::toVariant() const
{
    return QVariantMap{
        { QStringLiteral("minElementHeight"), minElementHeight },
        { QStringLiteral("maxElementHeight"), maxElementHeight },
        { QStringLiteral("minArea"), minArea },
        { QStringLiteral("maxArea"), maxArea },
        { QStringLiteral("easing"), QVariantList{ easing[0], easing[1], easing[2], easing[3] } },
        { QStringLiteral("scale"), variableMap(scale) },
        { QStringLiteral("containerAlpha"), variableMap(containerAlpha) },
        { QStringLiteral("contentAlpha"), variableMap(contentAlpha) },
        { QStringLiteral("sideOffset"), hasSideOffset ? QVariant(variableMap(sideOffset)) : QVariant() }
    };
}

/* ---- WearEdge.js in C++ ---- */

static inline qreal clamp01(qreal v)
{
    return v < 0 ? 0 : (v > 1 ? 1 : v);
}

EdgeLayout::EdgeLayout(QObject *parent) : QObject(parent)
{
}

QVariantMap EdgeLayout::scaling() const
{
    return EdgeSpec().toVariant();
}

/* y of a cubic Bezier through (0, 0), (x1, y1), (x2, y2), (1, 1) at x (the
 * AOSP PathInterpolator / Compose CubicBezierEasing; WearEdge.js bezier) */
qreal EdgeLayout::bezier(const qreal e[4], qreal x)
{
    if (x <= 0)
        return 0;
    if (x >= 1)
        return 1;
    qreal lo = 0, hi = 1, s = x;
    for (int i = 0; i < 32; i++) {
        const qreal u = 1 - s;
        const qreal bx = 3 * u * u * s * e[0] + 3 * u * s * s * e[2] + s * s * s;
        if (qAbs(bx - x) < 1e-7)
            break;
        if (bx < x)
            lo = s;
        else
            hi = s;
        s = (lo + hi) / 2;
    }
    const qreal v = 1 - s;
    return 3 * v * v * s * e[1] + 3 * v * s * s * e[3] + s * s * s;
}

/* The transition progress l of an item (hca.l): top and h in viewport
 * fractions; -1 at the top edge, +1 at the bottom edge, 0 inside */
qreal EdgeLayout::progress(const EdgeSpec &spec, qreal top, qreal h)
{
    const qreal bottom = top + h;
    const qreal span = spec.maxElementHeight - spec.minElementHeight;
    const qreal hf = span > 0 ? clamp01((h - spec.minElementHeight) / span) : (h >= spec.maxElementHeight ? 1 : 0);
    qreal area = spec.minArea * (1 - hf) + spec.maxArea * hf;
    area = qMin(area, (h + 1) / 2);
    if (bottom < 1 - top) {
        const qreal nearTop = bottom / area - 1;
        return nearTop > 0 ? 0 : nearTop;
    }
    const qreal far = 1 - (1 - top) / area;
    return far < 0 ? 0 : far;
}

/* One variable at progress l (hqf.a) */
qreal EdgeLayout::value(qreal l, const EdgeSpec::Variable &v, const qreal e[4])
{
    const qreal edge = l < 0 ? v.top : v.bottom;
    const qreal x = l < 0 ? l + 1 : 1 - l;
    const qreal zone = v.exit - v.enter;
    const qreal f = zone != 0 ? clamp01((x - v.enter) / zone) : (x >= v.exit ? 1 : 0);
    const qreal eased = bezier(e, f);
    return (1 - eased) * edge + eased * v.target;
}

EdgeValues EdgeLayout::evaluate(const EdgeSpec &spec, qreal top, qreal h, bool reduced)
{
    EdgeValues out;
    if (reduced || !(h > 0))
        return out;
    const qreal l = progress(spec, top, h);
    out.l = l;
    out.x = l < 0 ? l + 1 : 1 - l;
    out.scale = value(l, spec.scale, spec.easing);
    out.containerAlpha = value(l, spec.containerAlpha, spec.easing);
    out.contentAlpha = value(l, spec.contentAlpha, spec.easing);
    out.sideOffset = spec.hasSideOffset ? value(l, spec.sideOffset, spec.easing) : 0;
    return out;
}

/* The height an item is laid out at (ResponsiveTransformationSpecImpl: ceil) */
qreal EdgeLayout::ceilHeight(qreal h, qreal scale)
{
    return qCeil(h * scale);
}

QVector<EdgePlace> EdgeLayout::layout(const QVector<const EdgeSpec *> &specs, const QVector<qreal> &tops,
                                      const QVector<qreal> &hs, const QVector<qreal> &gaps, qreal vh,
                                      bool reduced, int *anchor, bool innerAnchor)
{
    const int n = tops.size();
    QVector<EdgePlace> out(n);
    if (anchor)
        *anchor = -1;
    if (n == 0 || !(vh > 0) || hs.size() < n || specs.size() < n)
        return out;
    auto gapAt = [&](int i) { return i >= 0 && i < gaps.size() ? gaps[i] : 0; };
    auto eval1 = [&](int i, qreal top, qreal h) { return evaluate(*specs[i], top / vh, h / vh, reduced); };
    auto placed = [](qreal y, qreal h, const EdgeValues &e, int side) {
        EdgePlace p;
        p.y = y;
        p.height = ceilHeight(h, e.scale);
        p.v = e;
        p.side = side;
        return p;
    };
    auto gone = [](qreal y, const EdgeValues &e, int side) {
        EdgePlace p;
        p.y = y;
        p.height = 0;
        p.v = e;
        p.side = side;
        p.shown = false;
        return p;
    };
    int a = 0;
    qreal best = 1e30;
    for (int i = 0; i < n; i++) {
        const qreal d = qAbs(tops[i] + hs[i] / 2 - vh / 2);
        if (d < best) {
            best = d;
            a = i;
        }
    }
    if (anchor)
        *anchor = a;
    const EdgeValues ea = eval1(a, tops[a], hs[a]);
    if (innerAnchor && tops[a] + hs[a] / 2 < vh / 2)
        out[a] = placed(tops[a] + hs[a] - ceilHeight(hs[a], ea.scale), hs[a], ea, -1);
    else
        out[a] = placed(tops[a], hs[a], ea, 0);
    // downwards from the anchor's bottom
    qreal bottom = out[a].y + out[a].height;
    for (int k = a + 1; k < n; k++) {
        const qreal top = bottom + gapAt(k - 1);
        const EdgeValues e = eval1(k, top, hs[k]);
        if (top >= vh) {
            for (int r = k; r < n; r++)
                out[r] = gone(vh + hs[r], e, 1);
            break;
        }
        out[k] = placed(top, hs[k], e, 1);
        bottom = top + out[k].height;
    }
    // upwards from the anchor's top: the item that ends at `end` is judged as
    // it would be untransformed, which is what its edge progress (its bottom
    // edge) needs
    qreal start = out[a].y;
    for (int j = a - 1; j >= 0; j--) {
        const qreal end = start - gapAt(j);
        const EdgeValues e2 = eval1(j, end - hs[j], hs[j]);
        const qreal h2 = ceilHeight(hs[j], e2.scale);
        if (end <= 0) {
            for (int q = j; q >= 0; q--)
                out[q] = gone(-hs[q], e2, -1);
            break;
        }
        out[j] = placed(end - h2, hs[j], e2, -1);
        start = out[j].y;
    }
    return out;
}

/* ---- the QML functions ---- */

static QVariantMap valuesMap(const EdgeValues &v)
{
    return QVariantMap{
        { QStringLiteral("l"), v.l }, { QStringLiteral("x"), v.x }, { QStringLiteral("scale"), v.scale },
        { QStringLiteral("containerAlpha"), v.containerAlpha }, { QStringLiteral("contentAlpha"), v.contentAlpha },
        { QStringLiteral("sideOffset"), v.sideOffset }
    };
}

QVariantMap EdgeLayout::evaluate(const QVariantMap &spec, qreal top, qreal height, bool reduced) const
{
    return valuesMap(evaluate(EdgeSpec::fromVariant(spec), top, height, reduced));
}

QVariantList EdgeLayout::layout(const QVariantMap &spec, const QVariantList &tops, const QVariantList &heights,
                                const QVariantList &gaps, qreal viewportHeight, bool reduced) const
{
    const EdgeSpec s = EdgeSpec::fromVariant(spec);
    const int n = tops.size();
    QVector<qreal> t(n), h(n), g(gaps.size());
    QVector<const EdgeSpec *> specs(n, &s);
    for (int i = 0; i < n; i++) {
        t[i] = tops[i].toReal();
        h[i] = i < heights.size() ? heights[i].toReal() : 0;
    }
    for (int i = 0; i < gaps.size(); i++)
        g[i] = gaps[i].toReal();
    const QVector<EdgePlace> places = layout(specs, t, h, g, viewportHeight, reduced);
    QVariantList out;
    out.reserve(places.size());
    for (const EdgePlace &p : places) {
        /* WearEdge.js: beyond the screen nothing is drawn */
        out << QVariantMap{
            { QStringLiteral("y"), p.y }, { QStringLiteral("height"), p.height },
            { QStringLiteral("scale"), p.v.scale },
            { QStringLiteral("containerAlpha"), p.shown ? p.v.containerAlpha : 0 },
            { QStringLiteral("contentAlpha"), p.shown ? p.v.contentAlpha : 0 },
            { QStringLiteral("sideOffset"), p.v.sideOffset },
            { QStringLiteral("shown"), p.shown }, { QStringLiteral("side"), p.side }
        };
    }
    return out;
}

/* ---- the packer ---- */

static QHash<QQuickItem *, EdgePacker *> &packers()
{
    /* never freed: a Flickable may go after static destruction at exit */
    static QHash<QQuickItem *, EdgePacker *> *all = new QHash<QQuickItem *, EdgePacker *>;
    return *all;
}

EdgePacker *EdgePacker::forFlickable(QQuickItem *flickable)
{
    QHash<QQuickItem *, EdgePacker *> &all = packers();
    const auto it = all.constFind(flickable);
    if (it != all.constEnd())
        return it.value();
    EdgePacker *p = new EdgePacker(flickable);
    all.insert(flickable, p);
    return p;
}

EdgePacker::EdgePacker(QQuickItem *flickable) : QObject(flickable),
    m_flickable(flickable), m_key(flickable)
{
    connect(flickable, SIGNAL(contentYChanged()), this, SLOT(relayout()));
    connect(flickable, &QQuickItem::heightChanged, this, &EdgePacker::relayout);
    connect(flickable, &QQuickItem::visibleChanged, this, &EdgePacker::scheduleRelayout);
    connect(flickable, &QQuickItem::windowChanged, this, &EdgePacker::scheduleRelayout);
    connect(ReduceMotion::instance(), &ReduceMotion::changed, this, &EdgePacker::scheduleRelayout);
}

EdgePacker::~EdgePacker()
{
    packers().remove(m_key);
}

void EdgePacker::add(EdgeEffect *effect)
{
    for (const QPointer<EdgeEffect> &e : std::as_const(m_effects)) {
        if (e == effect)
            return;
    }
    m_effects << effect;
    scheduleRelayout();
}

void EdgePacker::remove(EdgeEffect *effect)
{
    m_effects.removeAll(effect);
    m_effects.removeAll(nullptr);
    /* not now: the effect may be going with its item */
    scheduleRelayout();
}

/* A page of rows completes, a Column or ListView places its items: one
 * layout for all of it, in the same frame (afterAnimating comes after the
 * polish that places them and before the scene is synchronised), or a
 * queued call when no frame is coming (no frame is asked for: the values
 * that change ask for one themselves) */
void EdgePacker::scheduleRelayout()
{
    if (m_scheduled)
        return;
    m_scheduled = true;
    if (QQuickWindow *w = m_flickable ? m_flickable->window() : nullptr)
        connect(w, &QQuickWindow::afterAnimating, this, &EdgePacker::flushScheduled, Qt::UniqueConnection);
    QMetaObject::invokeMethod(this, &EdgePacker::flushScheduled, Qt::QueuedConnection);
}

void EdgePacker::flushScheduled()
{
    if (!m_scheduled)
        return;
    m_scheduled = false;
    relayout();
}

void EdgePacker::relayout()
{
    if (m_busy) {
        m_again = true;
        return;
    }
    m_busy = true;
    /* this layout is the one a schedule asked for */
    m_scheduled = false;
    int rounds = 0;
    do {
        m_again = false;
        doLayout();
    } while (m_again && ++rounds < 4);
    m_busy = false;
}

void EdgePacker::doLayout()
{
    QQuickItem *f = m_flickable;
    if (!f)
        return;
    const QList<QPointer<EdgeEffect>> effects = m_effects;
    /* nothing to lay out (a page of unpacked effects): no work per move */
    bool any = false;
    for (const QPointer<EdgeEffect> &e : effects)
        any = any || (e && e->m_packed);
    if (!any)
        return;
    /* the items that carry an effect, in the order the effects joined */
    QHash<QQuickItem *, QList<EdgeEffect *>> byItem;
    for (const QPointer<EdgeEffect> &e : effects) {
        if (e && e->m_item)
            byItem[e->m_item.data()] << e.data();
    }
    struct Row {
        EdgeEffect *effect;
        qreal top;      /* the row's natural top in the viewport (inset included) */
        qreal height;   /* the row (the item less its insets) */
        qreal inset;
        qreal itemHeight;
    };
    QVector<Row> rows;
    QVector<EdgeEffect *> rest;
    const qreal vh = f->height();
    const bool reduced = ReduceMotion::instance()->enabled();
    for (const QPointer<EdgeEffect> &e : effects) {
        if (!e || !e->m_packed)
            continue;
        QQuickItem *it = e->m_item;
        bool in = e->m_enabled && it && it->parentItem() && it->window() && it->isVisible()
                && it->height() > 0 && vh > 0 && !reduced;
        if (in) {
            /* another effect on the same item (the page's own, or a packed
             * one that joined first) or on an item this one is inside */
            const QList<EdgeEffect *> &same = byItem[it];
            for (EdgeEffect *o : same) {
                if (o != e && (!o->m_packed || same.indexOf(o) < same.indexOf(e.data())))
                    in = false;
            }
            for (QQuickItem *p = it->parentItem(); in && p && p != f; p = p->parentItem()) {
                if (byItem.contains(p))
                    in = false;
            }
        }
        if (!in) {
            rest << e.data();
            continue;
        }
        /* the natural place: through the parent, without the item's own
         * transform (the one this layout drives) */
        const qreal y = it->parentItem()->mapToItem(f, QPointF(0, it->y())).y();
        const qreal itemH = it->height();
        const qreal inset = qBound<qreal>(0, e->m_inset, itemH / 2 - 0.5);
        rows.append(Row{ e.data(), y + inset, itemH - 2 * inset, inset, itemH });
    }
    std::stable_sort(rows.begin(), rows.end(), [](const Row &a, const Row &b) { return a.top < b.top; });
    const int n = rows.size();
    QVector<qreal> tops(n), hs(n), gaps(n);
    QVector<const EdgeSpec *> specs(n);
    for (int i = 0; i < n; i++) {
        tops[i] = rows[i].top;
        hs[i] = rows[i].height;
        gaps[i] = i + 1 < n ? rows[i + 1].top - (rows[i].top + rows[i].height) : 0;
        specs[i] = &rows[i].effect->m_spec;
    }
    const QVector<EdgePlace> places = EdgeLayout::layout(specs, tops, hs, gaps, vh, reduced, nullptr, true);
    for (int i = 0; i < n && i < places.size(); i++) {
        const Row &r = rows[i];
        const EdgePlace &p = places[i];
        const qreal s = p.v.scale;
        qreal origin = r.inset;
        qreal shift = 0;
        if (p.side < 0) {
            /* above the anchor: about its bottom, the picture's top at p.y */
            origin = r.itemHeight - r.inset;
            if (p.shown)
                shift = p.y + s * r.height - (r.top + r.height);
        } else if (p.shown) {
            /* the anchor and below: about its top */
            shift = p.y - r.top;
        }
        r.effect->setLayoutValues(s, p.v.containerAlpha, p.v.contentAlpha, shift, origin);
    }
    for (EdgeEffect *e : std::as_const(rest))
        e->setLayoutValues(1, 1, 1, 0, 0);
}
