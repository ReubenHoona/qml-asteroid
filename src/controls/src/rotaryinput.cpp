/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "rotaryinput.h"
#include "haptics.h"

#include <QAbstractAnimation>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QMouseEvent>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTouchEvent>
#include <QWheelEvent>
#include <QtMath>
#include <MDConfItem>

#include <private/qquickitem_p.h>
#include <private/qquickpointerhandler_p.h>

Q_STATIC_LOGGING_CATEGORY(lcRotary, "asteroid.rotary", QtWarningMsg)

/* A touch picks the view the crown drives for this long */
static const qint64 PRESS_MEMORY_MS = 10000;
/* Wheel events further apart than this start a new crown gesture: the
 * target is looked up again */
static const qint64 GESTURE_GAP_MS = 300;
/* Smoothing time constant of the free scroll: the content covers 63% of
 * the remaining way in this time, so a detent settles in about 100 ms,
 * like Wear OS's rotary scroll animation */
static const qreal SMOOTHING_MS = 35.0;
/* Wear OS 6 ticks every 21 dp of rotary scroll (config_rotaryEncoderAxis
 * ScrollTickInterval); the Pixel Watch 2 is 192 dp wide at 2 px per dp,
 * so 42 px out of 384: 11% of the window height */
static const qreal TICK_FRACTION = 42.0 / 384.0;
/* Crown speed (detents per second) where the rotary "fling" gain starts and
 * where it reaches its maximum */
static const qreal FAST_FROM = 4.0;
static const qreal FAST_TO = 12.0;
static const qreal MAX_GAIN = 3.0;

static const char KEY_ENABLED[] = "/org/asteroidos/ux/rotary";
static const char KEY_INVERT[] = "/org/asteroidos/ux/rotary-invert";
static const char KEY_PX[] = "/org/asteroidos/ux/rotary-px-per-count";
static const char KEY_DETENT[] = "/org/asteroidos/ux/rotary-counts-per-detent";
static const char KEY_INDICATOR[] = "/org/asteroidos/ux/position-indicator";

class RotaryFrames : public QAbstractAnimation
{
public:
    explicit RotaryFrames(RotaryInput *r) : QAbstractAnimation(r), m_rotary(r) { }
    int duration() const override { return -1; }

protected:
    void updateCurrentTime(int t) override
    {
        const int dt = t - m_rotary->m_frameTime;
        m_rotary->m_frameTime = t;
        m_rotary->animate(qBound(1, dt, 100));
    }

private:
    RotaryInput *m_rotary;
};

void RotaryInput::install()
{
    static RotaryInput *s = nullptr;
    if (s || !qApp)
        return;
    s = new RotaryInput(qApp);
    qApp->installEventFilter(s);
}

RotaryInput::RotaryInput(QObject *parent) : QObject(parent),
    m_enabled(new MDConfItem(QLatin1String(KEY_ENABLED), this)),
    m_invert(new MDConfItem(QLatin1String(KEY_INVERT), this)),
    m_pxPerCount(new MDConfItem(QLatin1String(KEY_PX), this)),
    m_countsPerDetent(new MDConfItem(QLatin1String(KEY_DETENT), this)),
    m_indicatorEnabled(new MDConfItem(QLatin1String(KEY_INDICATOR), this))
{
    for (MDConfItem *item : {m_enabled, m_invert, m_pxPerCount, m_countsPerDetent, m_indicatorEnabled})
        connect(item, &MDConfItem::valueChanged, this, &RotaryInput::readSettings);
    readSettings();
    m_frame = new RotaryFrames(this);
}

bool RotaryInput::gliding() const
{
    return m_frame->state() == QAbstractAnimation::Running;
}

void RotaryInput::startGlide()
{
    if (gliding())
        return;
    m_frameTime = 0;
    m_frame->start();
}

void RotaryInput::readSettings()
{
    m_on = m_enabled->value(true).toBool();
    m_inverted = m_invert->value(false).toBool();
    bool ok = false;
    const qreal detent = m_countsPerDetent->value(24).toDouble(&ok);
    m_detent = ok && detent >= 1 ? detent : 24;
    /* 0 or unset: one tick of travel per detent (Wear OS's tick interval) */
    const qreal px = m_pxPerCount->value(0).toDouble(&ok);
    m_px = ok && px > 0 ? px : 0;
    m_indicatorOn = m_indicatorEnabled->value(true).toBool();
}

static qreal tickPx(QQuickItem *item)
{
    const QQuickWindow *w = item ? item->window() : nullptr;
    const qreal h = w ? qMin(w->width(), w->height()) : 384;
    return qMax<qreal>(8, h * TICK_FRACTION);
}

bool RotaryInput::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::Wheel: {
        /* Only the window's own copy: Qt then sends the event on to items,
         * and those copies pass this filter too */
        QQuickWindow *window = qobject_cast<QQuickWindow *>(watched);
        if (!window || !m_on)
            break;
        return handleWheel(window, static_cast<QWheelEvent *>(event));
    }
    case QEvent::Expose: {
        QQuickWindow *window = qobject_cast<QQuickWindow *>(watched);
        if (window && !m_prepared.contains(window)) {
            m_prepared.insert(window);
            QPointer<QQuickWindow> w(window);
            QTimer::singleShot(1500, this, [this, w]() { prepareIndicator(w); });
        }
        break;
    }
    case QEvent::TouchBegin: {
        QQuickWindow *window = qobject_cast<QQuickWindow *>(watched);
        QTouchEvent *te = static_cast<QTouchEvent *>(event);
        if (window && te->pointCount() > 0)
            notePress(window, te->points().first().scenePosition());
        break;
    }
    case QEvent::MouseButtonPress: {
        QQuickWindow *window = qobject_cast<QQuickWindow *>(watched);
        QMouseEvent *me = static_cast<QMouseEvent *>(event);
        if (window && me->source() == Qt::MouseEventNotSynthesized)
            notePress(window, me->scenePosition());
        break;
    }
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void RotaryInput::notePress(QQuickWindow *window, const QPointF &pos)
{
    m_pressWindow = window;
    m_pressPos = pos;
    m_pressTime.start();
    /* a finger takes over from a crown scroll still gliding */
    m_frame->stop();
    /* the next crown event looks the target up again, under this touch */
    m_lastEvent.invalidate();
    /* show the indicator while a finger scrolls a list, as Wear OS does */
    if (m_indicatorOn) {
        Kind kind = None;
        bool blocked = false;
        QQuickItem *t = findTarget(window, pos, &kind, &blocked);
        if (t && !blocked && kind == Free && scrollsVertically(t))
            showIndicator(t, false);
    }
}

RotaryInput::Kind RotaryInput::kindOf(QQuickItem *item)
{
    if (!item->isEnabled())
        return None;
    if (item->inherits("QQuickPathView")) {
        if (!item->property("interactive").toBool() || item->property("count").toInt() < 2)
            return None;
        return Path;
    }
    if (item->inherits("QQuickFlickable")) {
        if (!item->property("interactive").toBool())
            return None;
        if (item->inherits("QQuickItemView")) {
            /* ListView.SnapToItem/SnapOneItem, or StrictlyEnforceRange (2):
             * the view rests on items, so the crown steps through them */
            const int snap = item->property("snapMode").toInt();
            const int range = item->property("highlightRangeMode").toInt();
            if ((snap != 0 || range == 2) && item->property("count").toInt() > 0)
                return Snap;
        }
        if (scrollsVertically(item) || scrollsHorizontally(item))
            return Free;
    }
    return None;
}

bool RotaryInput::scrollsVertically(QQuickItem *item)
{
    const qreal content = item->property("contentHeight").toReal()
            + item->property("topMargin").toReal() + item->property("bottomMargin").toReal();
    const int dir = item->property("flickableDirection").toInt();
    /* Flickable.AutoFlickDirection 0, HorizontalFlick 1, VerticalFlick 2,
     * HorizontalAndVerticalFlick 3 */
    return dir != 1 && content > item->height() + 1;
}

bool RotaryInput::scrollsHorizontally(QQuickItem *item)
{
    const qreal content = item->property("contentWidth").toReal()
            + item->property("leftMargin").toReal() + item->property("rightMargin").toReal();
    const int dir = item->property("flickableDirection").toInt();
    return dir != 2 && content > item->width() + 1;
}

static bool hasWheelHandler(QQuickItem *item)
{
    QQuickItemPrivate *d = QQuickItemPrivate::get(item);
    if (!d->hasPointerHandlers())
        return false;
    for (QQuickPointerHandler *h : d->extra->pointerHandlers) {
        if (h->inherits("QQuickWheelHandler") && h->enabled())
            return true;
    }
    return false;
}

static bool effectivelyVisible(QQuickItem *item)
{
    for (QQuickItem *i = item; i; i = i->parentItem()) {
        if (!i->isVisible() || i->opacity() <= 0.0)
            return false;
    }
    return true;
}

/* Depth-first over the whole item tree in paint order: the last scrollable
 * view under pos that is drawn on top (the deepest one wins among nested
 * views), and whether any item under pos wants raw wheel events */
static void collect(QQuickItem *item, const QPointF &scenePos, int depth,
                    QQuickItem **best, int *bestDepth, bool *blocked,
                    RotaryInput::Kind (*kindOf)(QQuickItem *), int *bestKind)
{
    if (!item->isVisible() || item->opacity() <= 0.0)
        return;
    const QPointF p = item->mapFromScene(scenePos);
    const bool inside = item->contains(p);
    if (inside && hasWheelHandler(item))
        *blocked = true;
    if (inside) {
        const RotaryInput::Kind k = kindOf(item);
        if (k != 0 && depth >= *bestDepth) {
            *best = item;
            *bestDepth = depth;
            *bestKind = k;
        }
    }
    /* children can lie outside their parent: keep going unless the parent
     * clips them away */
    if (!inside && item->clip())
        return;
    const QList<QQuickItem *> children = QQuickItemPrivate::get(item)->paintOrderChildItems();
    for (QQuickItem *child : children)
        collect(child, scenePos, depth + 1, best, bestDepth, blocked, kindOf, bestKind);
}

QQuickItem *RotaryInput::findTarget(QQuickWindow *window, const QPointF &pos, Kind *kind, bool *blocked) const
{
    QQuickItem *best = nullptr;
    int bestDepth = -1;
    int bestKind = None;
    *blocked = false;
    collect(window->contentItem(), pos, 0, &best, &bestDepth, blocked, &RotaryInput::kindOf, &bestKind);
    *kind = Kind(bestKind);
    if (best && !effectivelyVisible(best))
        best = nullptr;
    return best;
}

bool RotaryInput::handleWheel(QQuickWindow *window, QWheelEvent *event)
{
    qreal counts = event->angleDelta().y() / 120.0;
    if (qFuzzyIsNull(counts))
        counts = event->angleDelta().x() / 120.0;
    if (qFuzzyIsNull(counts))
        return false;

    /* A new crown gesture: find what to drive */
    const bool newGesture = !m_lastEvent.isValid() || m_lastEvent.elapsed() > GESTURE_GAP_MS
            || !m_target || m_target->window() != window;
    if (newGesture) {
        QPointF pos(window->width() / 2.0, window->height() / 2.0);
        if (m_pressWindow == window && m_pressTime.isValid() && m_pressTime.elapsed() < PRESS_MEMORY_MS)
            pos = m_pressPos;
        bool blocked = false;
        Kind kind = None;
        QQuickItem *t = findTarget(window, pos, &kind, &blocked);
        if (blocked || !t) {
            qCDebug(lcRotary) << "pass" << event->angleDelta() << (blocked ? "(WheelHandler)" : "(no view)");
            m_target = nullptr;
            m_kind = None;
            return false;
        }
        if (m_target != t || m_kind != kind) {
            m_frame->stop();
            m_pending = 0;
        }
        m_target = t;
        m_kind = kind;
        m_speed = 0;
        if (kind == Free)
            m_horizontal = !scrollsVertically(t) && scrollsHorizontally(t);
        else if (kind == Snap)
            m_horizontal = t->property("orientation").toInt() == 1; /* ListView.Horizontal */
        else
            m_horizontal = false;
        qCDebug(lcRotary) << "target" << t << "kind" << kind << (m_horizontal ? "horizontal" : "vertical");
    }

    /* crown speed in detents per second, smoothed over a few events */
    if (m_lastEvent.isValid()) {
        const qreal dt = qMax<qint64>(1, m_lastEvent.elapsed()) / 1000.0;
        const qreal inst = qAbs(counts) / m_detent / dt;
        m_speed = newGesture ? 0 : m_speed * 0.7 + qMin<qreal>(inst, 60) * 0.3;
    }
    m_lastEvent.start();

    /* Qt's wheel convention: a positive angle scrolls towards the start.
     * Forward (towards the end of a list) is the other way. */
    qreal forward = -counts;
    if (m_inverted)
        forward = -forward;

    qCDebug(lcRotary) << "wheel" << event->angleDelta() << "counts" << counts
                      << "speed" << m_speed << "detents/s";

    switch (m_kind) {
    case Free:
        scrollFree(forward);
        break;
    case Snap:
    case Path: {
        m_pending += forward;
        const int steps = int(m_pending / m_detent);
        if (steps != 0) {
            m_pending -= steps * m_detent;
            stepSnap(steps);
        }
        break;
    }
    default:
        return false;
    }
    event->accept();
    return true;
}

static qreal minPos(QQuickItem *f, bool horizontal)
{
    return horizontal ? f->property("originX").toReal() - f->property("leftMargin").toReal()
                      : f->property("originY").toReal() - f->property("topMargin").toReal();
}

static qreal maxPos(QQuickItem *f, bool horizontal)
{
    const qreal lo = minPos(f, horizontal);
    const qreal hi = horizontal
            ? f->property("originX").toReal() + f->property("contentWidth").toReal()
              + f->property("rightMargin").toReal() - f->width()
            : f->property("originY").toReal() + f->property("contentHeight").toReal()
              + f->property("bottomMargin").toReal() - f->height();
    return qMax(lo, hi);
}

static const char *posName(bool horizontal)
{
    return horizontal ? "contentX" : "contentY";
}

void RotaryInput::scrollFree(qreal forward)
{
    QQuickItem *f = m_target;
    const qreal tick = tickPx(f);
    const qreal pxPerCount = m_px > 0 ? m_px : tick / m_detent;
    const qreal fast = qBound<qreal>(0, (m_speed - FAST_FROM) / (FAST_TO - FAST_FROM), 1);
    const qreal gain = 1 + (MAX_GAIN - 1) * fast * fast * (3 - 2 * fast);

    const qreal current = f->property(posName(m_horizontal)).toReal();
    if (!gliding()) {
        /* starting from rest: stop a finger fling first */
        QMetaObject::invokeMethod(f, "cancelFlick");
        m_goal = current;
        m_lastTickPos = current;
    }
    const qreal lo = minPos(f, m_horizontal);
    const qreal hi = maxPos(f, m_horizontal);
    const qreal wanted = m_goal + forward * pxPerCount * gain;
    m_goal = qBound(lo, wanted, hi);
    if (wanted != m_goal && qAbs(current - m_goal) < 1) {
        /* pushing against an end that is already reached */
        Haptics::instance()->limit();
        return;
    }
    if (m_indicatorOn && !m_horizontal)
        showIndicator(f, true);
    if (!gliding()) {
        startGlide();
    }
}

void RotaryInput::animate(qreal dt)
{
    QQuickItem *f = m_target;
    if (!f || m_kind == None) {
        m_frame->stop();
        return;
    }
    const qreal current = f->property(posName(m_horizontal)).toReal();
    const qreal k = 1 - qExp(-dt / SMOOTHING_MS);
    qreal next = current + (m_goal - current) * k;
    const bool done = qAbs(m_goal - next) < 0.5;
    if (done)
        next = m_goal;
    f->setProperty(posName(m_horizontal), next);

    const qreal tick = tickPx(f);
    if (qAbs(next - m_lastTickPos) >= tick) {
        Haptics::instance()->tick();
        /* keep the tick grid: a long frame does not shift later ticks */
        m_lastTickPos += (next > m_lastTickPos ? tick : -tick)
                * qFloor(qAbs(next - m_lastTickPos) / tick);
    }
    if (done) {
        m_frame->stop();
        if (m_kind == Snap)
            m_pending = 0;
    }
}

void RotaryInput::stepSnap(int steps)
{
    QQuickItem *v = m_target;
    if (m_kind == Path || v->property("highlightRangeMode").toInt() == 2) {
        /* the view follows its current item: step it */
        const int before = v->property("currentIndex").toInt();
        const char *method = steps > 0 ? "incrementCurrentIndex" : "decrementCurrentIndex";
        for (int i = 0; i < qAbs(steps); i++)
            QMetaObject::invokeMethod(v, method);
        if (v->property("currentIndex").toInt() != before)
            Haptics::instance()->tick();
        else
            Haptics::instance()->limit();
        return;
    }

    /* SnapToItem / SnapOneItem without a highlight range: glide to the
     * start of the item `steps` away from the one at the start of the view */
    const bool horizontal = m_horizontal;
    const qreal pos = gliding() ? m_goal : v->property(posName(horizontal)).toReal();
    const qreal probeX = horizontal ? pos + 1 : v->property("contentX").toReal() + v->width() / 2;
    const qreal probeY = horizontal ? v->property("contentY").toReal() + v->height() / 2 : pos + 1;
    int index = -1;
    QMetaObject::invokeMethod(v, "indexAt", Q_RETURN_ARG(int, index),
                              Q_ARG(qreal, probeX), Q_ARG(qreal, probeY));
    if (index < 0)
        index = v->property("currentIndex").toInt();
    const int count = v->property("count").toInt();
    const int target = qBound(0, index + steps, count - 1);
    if (target == index) {
        Haptics::instance()->limit();
        return;
    }
    QQuickItem *item = nullptr;
    QMetaObject::invokeMethod(v, "itemAtIndex", Q_RETURN_ARG(QQuickItem *, item), Q_ARG(int, target));
    if (!item) {
        /* not instantiated (far away): jump */
        QMetaObject::invokeMethod(v, "positionViewAtIndex", Q_ARG(int, target), Q_ARG(int, 5 /* SnapPosition */));
        Haptics::instance()->tick();
        return;
    }
    if (!gliding()) {
        QMetaObject::invokeMethod(v, "cancelFlick");
        m_lastTickPos = v->property(posName(horizontal)).toReal();
    }
    m_goal = qBound(minPos(v, horizontal), horizontal ? item->x() : item->y(), maxPos(v, horizontal));
    /* one tick per item, from stepSnap, not from the travel */
    Haptics::instance()->tick();
    m_lastTickPos = m_goal;
    if (!gliding()) {
        startGlide();
    }
}

/* Any item of the window that QML made: its engine and context */
static QQuickItem *qmlItemOf(QQuickItem *item)
{
    if (qmlEngine(item))
        return item;
    const QList<QQuickItem *> children = item->childItems();
    for (QQuickItem *child : children) {
        if (QQuickItem *found = qmlItemOf(child))
            return found;
    }
    return nullptr;
}

/* Make the indicator before anyone scrolls: compiling and creating it took
 * 80 ms the first time a finger or the crown moved a list, a stall in the
 * first frames of that scroll. Runs 1.5 s after a window shows. */
void RotaryInput::prepareIndicator(QQuickWindow *window)
{
    if (!window || !m_indicatorOn)
        return;
    if (m_indicator && qobject_cast<QQuickItem *>(m_indicator)->window() == window)
        return;
    if (QQuickItem *item = qmlItemOf(window->contentItem()))
        ensureIndicator(window, item);
}

bool RotaryInput::ensureIndicator(QQuickWindow *window, QQuickItem *anyItem)
{
    QQuickItem *root = window->contentItem();
    if (!m_indicator || qobject_cast<QQuickItem *>(m_indicator)->window() != window) {
        QQmlEngine *engine = qmlEngine(anyItem);
        if (!engine)
            return false;
        QQmlComponent component(engine);
        component.setData("import org.asteroid.controls\nPositionIndicator { }", QUrl());
        QObject *o = component.create(qmlContext(root) ? qmlContext(root) : engine->rootContext());
        QQuickItem *indicator = qobject_cast<QQuickItem *>(o);
        if (!indicator) {
            qCWarning(lcRotary) << "PositionIndicator:" << component.errorString();
            delete o;
            return false;
        }
        if (m_indicator)
            m_indicator->deleteLater();
        indicator->setParentItem(root);
        indicator->setParent(root);
        indicator->setZ(1e6);
        m_indicator = indicator;
    }
    return true;
}

void RotaryInput::showIndicator(QQuickItem *flickable, bool flash)
{
    QQuickWindow *window = flickable->window();
    if (!window || !ensureIndicator(window, flickable))
        return;
    m_indicator->setProperty("flickable", QVariant::fromValue<QObject *>(flickable));
    if (flash)
        QMetaObject::invokeMethod(m_indicator, "flash");
}
