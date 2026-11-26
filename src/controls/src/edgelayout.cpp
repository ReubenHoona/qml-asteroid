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
#include <private/qquickitem_p.h>

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
    const qreal x = l < 0 ? l + 1 : 1 - l;
    out.l = l;
    out.x = x;
    /* value() for each variable, with one easing for the variables that
     * share a zone (all of them in SCALING): the same numbers, one bisection */
    qreal zoneEnter = qQNaN(), zoneExit = qQNaN(), eased = 0;
    auto mix = [&](const EdgeSpec::Variable &v) {
        if (v.enter != zoneEnter || v.exit != zoneExit) {
            zoneEnter = v.enter;
            zoneExit = v.exit;
            const qreal zone = v.exit - v.enter;
            const qreal f = zone != 0 ? clamp01((x - v.enter) / zone) : (x >= v.exit ? 1 : 0);
            eased = bezier(spec.easing, f);
        }
        const qreal edge = l < 0 ? v.top : v.bottom;
        return (1 - eased) * edge + eased * v.target;
    };
    out.scale = mix(spec.scale);
    out.containerAlpha = mix(spec.containerAlpha);
    out.contentAlpha = mix(spec.contentAlpha);
    out.sideOffset = spec.hasSideOffset ? mix(spec.sideOffset) : 0;
    return out;
}

/* The height an item is laid out at (ResponsiveTransformationSpecImpl: ceil) */
qreal EdgeLayout::ceilHeight(qreal h, qreal scale)
{
    return qCeil(h * scale);
}

int EdgeLayout::layout(const QVector<const EdgeSpec *> &specs, const QVector<qreal> &tops,
                       const QVector<qreal> &hs, const QVector<qreal> &gaps, qreal vh,
                       bool reduced, QVector<EdgePlace> &out)
{
    const int n = tops.size();
    out.resize(n);
    if (n == 0 || !(vh > 0) || hs.size() < n || specs.size() < n) {
        for (int i = 0; i < n; i++)
            out[i] = EdgePlace();
        return -1;
    }
    auto gapAt = [&](int i) { return i >= 0 && i < gaps.size() ? gaps[i] : 0; };
    auto eval1 = [&](int i, qreal top, qreal h) { return evaluate(*specs[i], top / vh, h / vh, reduced); };
    auto placed = [&](int i, qreal y, const EdgeValues &e, int side) {
        EdgePlace &p = out[i];
        p.y = y;
        p.height = ceilHeight(hs[i], e.scale);
        p.v = e;
        p.side = side;
        p.shown = true;
    };
    auto gone = [&](int i, qreal y, const EdgeValues &e, int side) {
        EdgePlace &p = out[i];
        p.y = y;
        p.height = 0;
        p.v = e;
        p.side = side;
        p.shown = false;
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
    placed(a, tops[a], eval1(a, tops[a], hs[a]), 0);
    // downwards from the anchor's bottom
    qreal bottom = out[a].y + out[a].height;
    for (int k = a + 1; k < n; k++) {
        const qreal top = bottom + gapAt(k - 1);
        const EdgeValues e = eval1(k, top, hs[k]);
        if (top >= vh) {
            for (int r = k; r < n; r++)
                gone(r, vh + hs[r], e, 1);
            break;
        }
        placed(k, top, e, 1);
        bottom = top + out[k].height;
    }
    // upwards from the anchor's top: the item that ends at `end` is judged as
    // it would be untransformed, which is what its edge progress (its bottom
    // edge) needs
    qreal start = out[a].y;
    for (int j = a - 1; j >= 0; j--) {
        const qreal end = start - gapAt(j);
        const EdgeValues e2 = eval1(j, end - hs[j], hs[j]);
        if (end <= 0) {
            for (int q = j; q >= 0; q--)
                gone(q, -hs[q], e2, -1);
            break;
        }
        placed(j, end - ceilHeight(hs[j], e2.scale), e2, -1);
        start = out[j].y;
    }
    return a;
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
    QVector<EdgePlace> places;
    layout(specs, t, h, g, viewportHeight, reduced, places);
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

/*
 * The items between the packer's rows and the content (a Column, a section
 * with a Translate). Qt has no signal for a transform; an item whose
 * transform, transform origin, scale, rotation, position or size changes
 * tells its Matrix listeners (QQuickItemPrivate::transformChanged), and so
 * does a transform added to it or taken away. Only an item's own change
 * counts: one above it (a scroll moves the content) arrives with another
 * transformedItem when Qt walks a subtree, and the items above a row are
 * watched themselves.
 */
class EdgeContainerWatch : public QQuickItemChangeListener
{
public:
    explicit EdgeContainerWatch(EdgePacker *packer) : m_packer(packer) {}
    ~EdgeContainerWatch() { set(QVector<QQuickItem *>()); }

    /* watch exactly these items */
    void set(const QVector<QQuickItem *> &items)
    {
        for (QQuickItem *it : std::as_const(m_items)) {
            if (!items.contains(it))
                QQuickItemPrivate::get(it)->removeItemChangeListener(this, types());
        }
        for (QQuickItem *it : items) {
            if (!m_items.contains(it))
                QQuickItemPrivate::get(it)->addItemChangeListener(this, types());
        }
        m_items = items;
    }

    void itemTransformChanged(QQuickItem *item, QQuickItem *transformedItem) override
    {
        /* m_busy: the packer's own values moved it (a transform bound to a
         * row's values on an item above the row): not followed, it would
         * lay the rows out again for ever */
        if (item == transformedItem && !m_packer->m_busy)
            m_packer->scheduleRelayout();
    }
    /* Qt drops its listeners itself */
    void itemDestroyed(QQuickItem *item) override { m_items.removeAll(item); }

private:
    static QQuickItemPrivate::ChangeTypes types()
    {
        return QQuickItemPrivate::ChangeTypes(QQuickItemPrivate::Matrix) | QQuickItemPrivate::Destroyed;
    }
    EdgePacker *m_packer;
    QVector<QQuickItem *> m_items;
};

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
    m_flickable(flickable), m_key(flickable), m_watch(new EdgeContainerWatch(this))
{
    connect(flickable, SIGNAL(contentYChanged()), this, SLOT(scrolled()));
    connect(flickable, SIGNAL(movementStarted()), this, SLOT(gestureStarted()));
    connect(flickable, &QQuickItem::heightChanged, this, &EdgePacker::viewportResized);
    connect(flickable, &QQuickItem::visibleChanged, this, &EdgePacker::scheduleRelayout);
    connect(flickable, &QQuickItem::windowChanged, this, &EdgePacker::scheduleRelayout);
    connect(ReduceMotion::instance(), &ReduceMotion::changed, this, &EdgePacker::scheduleRelayout);
}

EdgePacker::~EdgePacker()
{
    delete m_watch;
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
    /* the rows kept may hold it: they are worked out again before the next
     * layout; not now, the effect may be going with its item */
    scheduleRelayout();
}

/* The rows changed: one rebuild and layout for all of it, in the same frame
 * (afterAnimating comes after the polish that places them and before the
 * scene is synchronised), or a queued call when no frame is coming. The
 * per-frame signal is connected only until then. */
void EdgePacker::scheduleRelayout()
{
    m_dirty = true;
    if (m_busy) {
        m_again = true;
        return;
    }
    /* a change from outside: a fresh budget for passes that do not settle */
    m_unsettled = 0;
    makeDue();
}

void EdgePacker::scrolled()
{
    m_unsettled = 0;
    relayout();
}

void EdgePacker::makeDue()
{
    if (m_scheduled)
        return;
    m_scheduled = true;
    if (QQuickWindow *w = m_flickable ? m_flickable->window() : nullptr)
        m_frameHook = connect(w, &QQuickWindow::afterAnimating, this, &EdgePacker::flushScheduled);
    QMetaObject::invokeMethod(this, &EdgePacker::flushScheduled, Qt::QueuedConnection);
}

void EdgePacker::flushScheduled()
{
    if (m_scheduled)
        relayout();
    else
        dropFrameHook();
}

void EdgePacker::dropFrameHook()
{
    if (m_frameHook) {
        disconnect(m_frameHook);
        m_frameHook = QMetaObject::Connection();
    }
}

/* A touch gesture starts: the rows are worked out again at its first move
 * (one rebuild per gesture): a guard for a row moved in a way no hook
 * follows */
void EdgePacker::gestureStarted()
{
    m_dirty = true;
}

void EdgePacker::viewportResized()
{
    /* the values follow the viewport's height; who takes part may too */
    m_dirty = true;
    relayout();
}

void EdgePacker::relayout()
{
    if (m_busy) {
        m_again = true;
        return;
    }
    m_busy = true;
    if (m_scheduled) {
        /* this layout is the one the schedule asked for */
        m_scheduled = false;
        dropFrameHook();
    }
    int rounds = 0;
    do {
        m_again = false;
        if (m_dirty)
            rebuild();
        place();
    } while (m_again && ++rounds < 4);
    const bool unsettled = m_again;
    m_busy = false;
    if (!unsettled) {
        m_unsettled = 0;
    } else if (++m_unsettled <= 8) {
        /* the rows still moved after four rounds (something that moves a
         * row when its picture moves): once more on the next frame, at most
         * eight times after a scroll or a change, so they are not left
         * dirty with nothing due; then they stay as the last round put them
         * (still marked dirty: the next scroll or change works them out) */
        m_dirty = true;
        makeDue();
    }
}

void EdgePacker::rebuild()
{
    m_dirty = false;
    m_rows.clear();
    /* the items between the rows taking part and the content */
    QVector<QQuickItem *> containers;
    QQuickItem *f = m_flickable;
    m_content = f ? f->property("contentItem").value<QQuickItem *>() : nullptr;
    QQuickItem *content = m_content;
    /* the packed effects, and the items that carry any effect */
    QHash<QQuickItem *, QList<EdgeEffect *>> byItem;
    bool anyPacked = false;
    for (const QPointer<EdgeEffect> &e : std::as_const(m_effects)) {
        if (e && e->m_item) {
            byItem[e->m_item.data()] << e.data();
            anyPacked = anyPacked || e->m_packed;
        }
    }
    if (!anyPacked) {
        m_watch->set(containers);
        return;
    }
    const bool on = f && content && f->height() > 0 && !ReduceMotion::instance()->enabled();
    int leaders = 0;
    QVector<EdgeEffect *> rest;
    for (const QPointer<EdgeEffect> &e : std::as_const(m_effects)) {
        if (!e || !e->m_packed)
            continue;
        QQuickItem *it = e->m_item;
        bool in = on && e->m_enabled && it && it->parentItem() && it->window() && it->isVisible()
                && it->height() > 0 && content->isAncestorOf(it);
        if (in) {
            /* another effect on the same item (the page's own, or a packed
             * one that joined first) or on an item this one is inside */
            const QList<EdgeEffect *> &same = byItem[it];
            for (EdgeEffect *o : same) {
                if (o != e && (!o->m_packed || same.indexOf(o) < same.indexOf(e.data())))
                    in = false;
            }
            for (QQuickItem *p = it->parentItem(); in && p && p != content; p = p->parentItem()) {
                if (byItem.contains(p))
                    in = false;
            }
        }
        if (!in) {
            rest << e.data();
            continue;
        }
        if (!e->m_onlyWithRows)
            leaders++;
        /* the natural place in the content, without the item's own
         * transform (the one this layout drives) */
        const qreal y = it->parentItem()->mapToItem(content, QPointF(0, it->y())).y();
        const qreal itemH = it->height();
        const qreal inset = qBound<qreal>(0, e->m_inset, itemH / 2 - 0.5);
        m_rows.append(Row{ e.data(), y + inset, itemH - 2 * inset, inset, itemH });
        for (QQuickItem *p = it->parentItem(); p && p != content; p = p->parentItem()) {
            if (!containers.contains(p))
                containers << p;
        }
    }
    /* headers alone (no other row takes part): at rest, as a page of plain
     * rows had them */
    if (leaders == 0) {
        for (const Row &r : std::as_const(m_rows))
            rest << r.effect;
        m_rows.clear();
        containers.clear();
    }
    m_watch->set(containers);
    for (EdgeEffect *e : std::as_const(rest))
        e->setLayoutValues(1, 1, 1, 0, 0);
    std::stable_sort(m_rows.begin(), m_rows.end(),
                     [](const Row &a, const Row &b) { return a.contentTop < b.contentTop; });
    const int n = m_rows.size();
    m_specs.resize(n);
    m_tops.resize(n);
    m_hs.resize(n);
    m_gaps.resize(n);
    for (int i = 0; i < n; i++) {
        const Row &r = m_rows[i];
        m_specs[i] = &r.effect->m_spec;
        /* laid out on whole pixels (stock lays out in integer px), so a row
         * at scale 1 keeps its place and fractions do not add up down the
         * list; the gap takes the remainder */
        m_hs[i] = qRound(r.height);
        m_gaps[i] = i + 1 < n ? m_rows[i + 1].contentTop - (r.contentTop + m_hs[i]) : 0;
    }
}

void EdgePacker::place()
{
    const int n = m_rows.size();
    QQuickItem *content = m_content;
    if (n == 0 || !content || !m_flickable)
        return;
    /* a scroll moves the content: the natural places move with it */
    const qreal cy = content->y();
    for (int i = 0; i < n; i++)
        m_tops[i] = cy + m_rows[i].contentTop;
    EdgeLayout::layout(m_specs, m_tops, m_hs, m_gaps, m_flickable->height(), false, m_places);
    for (int i = 0; i < n; i++) {
        const Row &r = m_rows[i];
        const EdgePlace &p = m_places[i];
        const qreal s = p.v.scale;
        qreal origin = r.inset;
        qreal shift = 0;
        if (p.side < 0) {
            /* above the anchor: about its bottom, the picture's top at p.y */
            origin = r.itemHeight - r.inset;
            if (p.shown)
                shift = p.y + s * r.height - (m_tops[i] + r.height);
        } else if (p.shown) {
            /* the anchor and below: about its top */
            shift = p.y - m_tops[i];
        }
        r.effect->setLayoutValues(s, p.v.containerAlpha, p.v.contentAlpha, shift, origin);
    }
}
