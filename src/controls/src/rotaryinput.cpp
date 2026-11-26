/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "rotaryinput.h"
#include "haptics.h"
#include "spring.h"
#include "scrollphysics.h"

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
#include <QLineF>
#include <QtMath>
#include <MDConfItem>

#include <cmath>

#include <private/qquickitem_p.h>
#include <private/qquickpointerhandler_p.h>

Q_STATIC_LOGGING_CATEGORY(lcRotary, "asteroid.rotary", QtWarningMsg)

/* A touch picks the view the crown drives for this long */
static const qint64 PRESS_MEMORY_MS = 10000;
/* Wheel events further apart than this start a new crown gesture: the
 * target is looked up again */
static const qint64 GESTURE_GAP_MS = 300;
/* Smoothing of the free scroll as Wear OS (androidx RotaryScrollable
 * RotaryScrollHandler): every event moves a target and the content follows
 * it on spring() (stiffness 1500, damping 1: 98 % in about 151 ms),
 * retargeted with its speed kept */
static const qreal SMOOTHING_STIFFNESS = 1500.0;
static const qreal SMOOTHING_DAMPING = 1.0;
/* Wear OS 6 ticks every 21 dp of rotary scroll (config_rotaryEncoderAxis
 * ScrollTickInterval, VALUES.tsv values-watch); the Pixel Watch 2 is 192 dp
 * wide at 2 px per dp, so 42 px out of 384: 11% of the window height */
static const qreal TICK_FRACTION = 42.0 / 384.0;
static const qreal WINDOW_DP = 192.0;
/* crown-fast (the user's choice 2): crown speed (detents per second) where
 * the rotary gain starts and where it reaches its maximum */
static const qreal FAST_FROM = 4.0;
static const qreal FAST_TO = 12.0;
static const qreal MAX_GAIN = 3.0;

/* Stock CP3A crown (choice 2 off), choice-settings-04: AXIS_SCROLL per
 * count = |device.scalingFactor| 0.0117 (pixart_pat9126.idc), a view scrolls
 * AXIS_SCROLL x config_verticalScrollFactor 64 dp: 0.749 dp = 1.4976 px per
 * count at 2 px/dp; 360 counts (device.res 57.296 per radian) = 539 px a
 * turn. No speed gain. */
static const qreal STOCK_SCALING_FACTOR = 0.0117;
static const qreal STOCK_SCROLL_FACTOR_DP = 64.0;
/* Input slop (motion-transitions-25; pixart_pat9126.idc
 * rotary_encoder.slop_threshold 12, slop_duration_ms 500; AOSP
 * SlopController): after 500 ms without rotation, or when the direction
 * reverses, the first 12 counts are dropped and only the excess passes */
static const qreal SLOP_COUNTS = 12.0;
static const qint64 SLOP_DURATION_MS = 500;
/* Crown fling (motion-transitions-24; androidx RotaryScrollable
 * HighResFlingTimeframe 30 ms, flingScaleFactor 0.7; VALUES.tsv
 * config_viewMin/MaxRotaryEncoderFlingVelocity 500 / 2750 dp/s): the fling
 * starts 30 ms after the last event when the events came at most 60 ms
 * apart and the scaled speed is over 500 dp/s */
static const qint64 FLING_TIMEFRAME_MS = 30;
static const qreal FLING_SCALE = 0.7;
static const qint64 FLING_EVENT_GAP_MS = 60;
static const qint64 FLING_HORIZON_MS = 100;
static const qreal MIN_ROTARY_FLING_DP = 500.0;
static const qreal MAX_ROTARY_FLING_DP = 2750.0;
/* Stock rotary snap (motion-transitions-26; androidx RotaryScrollable
 * ThresholdHandler, RotarySnapSensitivityValues, RotarySnapHandler):
 * threshold = itemSize / lerp(minDivider, maxDivider,
 * CubicBezier(0.5, 0, 0.5, 1)((v - 300) / 2700)), v smoothed with 0.4;
 * Default (lists, pickers) 1 -> 1.5, High (pagers) 5 -> 7.5; at most 2
 * snaps per event; 200 ms between events breaks the gesture; the snap
 * glides on a spring of stiffness 200 */
static const qreal SNAP_MIN_VELOCITY = 300.0;
static const qreal SNAP_MAX_VELOCITY = 3000.0;
static const qreal SNAP_VELOCITY_SMOOTHING = 0.4;
static const qreal SNAP_DIVIDER_MIN = 1.0;
static const qreal SNAP_DIVIDER_MAX = 1.5;
static const qreal PAGER_DIVIDER_MIN = 5.0;
static const qreal PAGER_DIVIDER_MAX = 7.5;
static const int MAX_SNAPS_PER_EVENT = 2;
static const qint64 SNAP_GESTURE_BREAK_MS = 200;
static const qreal SNAP_STIFFNESS = 200.0;
/* Rotary overscroll exit (motion-transitions-16; SysUI ihx/kwg
 * ScrollAccumulator, scroll_accumulated_slop_threshold 96 raised to 150 by
 * SysUIOverlayScrollSlop150; a gap over 120 ms resets the sum) */
static const qreal EXIT_THRESHOLD_PX = 150.0;
static const qint64 EXIT_GAP_MS = 120;

static const char KEY_ENABLED[] = "/org/asteroidos/ux/rotary";
static const char KEY_INVERT[] = "/org/asteroidos/ux/rotary-invert";
static const char KEY_PX[] = "/org/asteroidos/ux/rotary-px-per-count";
static const char KEY_DETENT[] = "/org/asteroidos/ux/rotary-counts-per-detent";
static const char KEY_INDICATOR[] = "/org/asteroidos/ux/position-indicator";
/* Settings > Buttons > Faster crown scrolling (choice 2) */
static const char KEY_FAST[] = "/org/asteroidos/ux/crown-fast";

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

RotaryInput *RotaryInput::instance()
{
    static RotaryInput *s = nullptr;
    if (!s && qApp) {
        s = new RotaryInput(qApp);
        qApp->installEventFilter(s);
    }
    return s;
}

void RotaryInput::install()
{
    instance();
}

/* The QML singleton is the one event filter */
RotaryInput *RotaryInput::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    RotaryInput *r = instance();
    QJSEngine::setObjectOwnership(r, QJSEngine::CppOwnership);
    return r;
}

RotaryInput::RotaryInput(QObject *parent) : QObject(parent),
    m_enabled(new MDConfItem(QLatin1String(KEY_ENABLED), this)),
    m_invert(new MDConfItem(QLatin1String(KEY_INVERT), this)),
    m_pxPerCount(new MDConfItem(QLatin1String(KEY_PX), this)),
    m_countsPerDetent(new MDConfItem(QLatin1String(KEY_DETENT), this)),
    m_indicatorEnabled(new MDConfItem(QLatin1String(KEY_INDICATOR), this)),
    m_fastItem(new MDConfItem(QLatin1String(KEY_FAST), this))
{
    for (MDConfItem *item : {m_enabled, m_invert, m_pxPerCount, m_countsPerDetent, m_indicatorEnabled, m_fastItem})
        connect(item, &MDConfItem::valueChanged, this, &RotaryInput::readSettings);
    readSettings();
    m_frame = new RotaryFrames(this);
    m_clock.start();
    /* one shot per crown pause, never periodic */
    m_flingTimer.setSingleShot(true);
    m_flingTimer.setInterval(int(FLING_TIMEFRAME_MS));
    connect(&m_flingTimer, &QTimer::timeout, this, &RotaryInput::maybeFling);
    m_speedTimer.setSingleShot(true);
    m_speedTimer.setInterval(int(CrownSpeed::IdleMs));
    connect(&m_speedTimer, &QTimer::timeout, this, &RotaryInput::snapSpeed);
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
    m_glideVelocity = 0;
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
    const bool fast = m_fastItem->value(true).toBool();
    if (fast != m_fast) {
        m_fast = fast;
        m_slopSum = 0;
        m_slopMet = false;
        m_slopTime.invalidate();
        m_pending = 0;
        m_samples.clear();
        m_flinging = false;
    }
}

/* px per dp: the Pixel Watch 2's window is 192 dp wide */
static qreal densityOf(QQuickItem *item)
{
    const QQuickWindow *w = item ? item->window() : nullptr;
    const qreal h = w ? qMin(w->width(), w->height()) : 384;
    return h > 0 ? h / WINDOW_DP : 2.0;
}

static qreal tickPx(QQuickItem *item)
{
    const QQuickWindow *w = item ? item->window() : nullptr;
    const qreal h = w ? qMin(w->width(), w->height()) : 384;
    return qMax<qreal>(8, h * TICK_FRACTION);
}

qreal RotaryInput::pxPerCount(QQuickItem *item) const
{
    if (!m_fast)
        return STOCK_SCALING_FACTOR * STOCK_SCROLL_FACTOR_DP * densityOf(item);
    return m_px > 0 ? m_px : tickPx(item) / m_detent;
}

/* CubicBezier(x1, y1, x2, y2) easing at x (compose CubicBezierEasing) */
static qreal cubicBezier(qreal x1, qreal y1, qreal x2, qreal y2, qreal x)
{
    auto b = [](qreal p1, qreal p2, qreal t) {
        const qreal u = 1 - t;
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
    };
    qreal lo = 0, hi = 1, t = x;
    for (int i = 0; i < 32; i++) {
        t = (lo + hi) / 2;
        if (b(x1, x2, t) < x)
            lo = t;
        else
            hi = t;
    }
    return b(y1, y2, t);
}

static bool hasExitSignal(QObject *o)
{
    return o && o->metaObject()->indexOfSignal("rotaryExit(int)") >= 0;
}

/* The item (the view or an ancestor) that handles the rotary exit */
static QObject *exitReceiverFor(QQuickItem *item)
{
    for (QQuickItem *i = item; i; i = i->parentItem()) {
        if (hasExitSignal(i))
            return i;
    }
    return nullptr;
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
    /* a finger takes over from a crown scroll still gliding or flinging */
    m_frame->stop();
    m_flinging = false;
    m_flingTimer.stop();
    m_samples.clear();
    /* the view's own snapping takes over from a crown-speed scroll */
    m_speedTimer.stop();
    m_crown.reset();
    /* the next crown event looks the target up again, under this touch */
    m_lastEvent.invalidate();
    Kind kind = None;
    bool blocked = false;
    QQuickItem *t = findTarget(window, pos, &kind, &blocked);
    /* show the indicator while a finger scrolls a list, as Wear OS does */
    if (m_indicatorOn && t && !blocked && kind == Free && scrollsVertically(t))
        showIndicator(t, false);
    /* every vertical list under the finger flings as Wear OS's do (spline
     * decay, friction 0.015, 2750 dp/s; motion-transitions-19): attached
     * here, before the finger lifts, once per view */
    for (QQuickItem *i = t; i; i = i->parentItem()) {
        if (i->inherits("QQuickFlickable") && kindOf(i) == Free
                && scrollsVertically(i) && !scrollsHorizontally(i))
            ScrollPhysics::installStockFling(i);
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
                return item->property("rotaryCrownSpeed").toBool() ? Speed : Snap;
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

struct Found {
    QQuickItem *best = nullptr;
    int bestDepth = -1;
    int bestKind = 0;
    QQuickItem *exit = nullptr;   /* deepest item with a rotaryExit signal */
    int exitDepth = -1;
    bool blocked = false;
    bool modal = false;           /* a modal surface covers pos */
};

/* Depth-first over the whole item tree in paint order: the last scrollable
 * view under pos that is drawn on top (the deepest one wins among nested
 * views), and whether any item under pos wants raw wheel events */
static void collect(QQuickItem *item, const QPointF &scenePos, int depth, Found *f,
                    RotaryInput::Kind (*kindOf)(QQuickItem *))
{
    if (!item->isVisible())
        return;
    const QPointF p = item->mapFromScene(scenePos);
    const bool inside = item->contains(p);
    /* a modal surface (a shown Dialog: rotaryModal) under pos hides every
     * view drawn before it (paint order): only what it holds is a target,
     * also in the first frame of its fade */
    if (inside && item->property("rotaryModal").toBool()) {
        *f = Found();
        f->modal = true;
    }
    if (item->opacity() <= 0.0)
        return;
    if (inside && hasWheelHandler(item))
        f->blocked = true;
    if (inside) {
        const RotaryInput::Kind k = kindOf(item);
        if (k != 0 && depth >= f->bestDepth) {
            f->best = item;
            f->bestDepth = depth;
            f->bestKind = k;
        }
        if (depth >= f->exitDepth && hasExitSignal(item) && item->isEnabled()) {
            f->exit = item;
            f->exitDepth = depth;
        }
    }
    /* A picker group (TimePicker, DatePicker, NumberPicker) names the one
     * column the crown turns, whatever column the finger was on: its
     * rotaryTarget property (Item) wins over every view found inside it,
     * and null (its confirm button focused) leaves the crown nothing to
     * turn inside it (stock M3 TimePicker/DatePicker: the rotary input
     * goes to the focused picker only) */
    bool redirects = false;
    QQuickItem *redirect = nullptr;
    QQuickItem *bestBefore = f->best;
    int bestDepthBefore = f->bestDepth, bestKindBefore = f->bestKind;
    if (inside) {
        const QVariant rt = item->property("rotaryTarget");
        if (rt.isValid()) {
            redirects = true;
            redirect = qobject_cast<QQuickItem *>(rt.value<QObject *>());
        }
    }
    /* children can lie outside their parent: keep going unless the parent
     * clips them away */
    if (!inside && item->clip())
        return;
    const QList<QQuickItem *> children = QQuickItemPrivate::get(item)->paintOrderChildItems();
    for (QQuickItem *child : children)
        collect(child, scenePos, depth + 1, f, kindOf);
    if (redirects) {
        const RotaryInput::Kind k = redirect && effectivelyVisible(redirect) ? kindOf(redirect) : RotaryInput::Kind(0);
        if (k != 0) {
            f->best = redirect;
            f->bestDepth = qMax(f->bestDepth, depth);
            f->bestKind = k;
        } else {
            f->best = bestBefore;
            f->bestDepth = bestDepthBefore;
            f->bestKind = bestKindBefore;
        }
    }
}

QQuickItem *RotaryInput::findTarget(QQuickWindow *window, const QPointF &pos, Kind *kind, bool *blocked,
                                    bool *modal) const
{
    Found f;
    collect(window->contentItem(), pos, 0, &f, &RotaryInput::kindOf);
    *blocked = f.blocked;
    if (modal)
        *modal = f.modal;
    *kind = Kind(f.bestKind);
    QQuickItem *best = f.best;
    if (best && !effectivelyVisible(best))
        best = nullptr;
    /* nothing to scroll, but a tray that the crown closes (a short
     * notification list): the crown pushes past its end at once */
    if (!best && f.exit && effectivelyVisible(f.exit)) {
        best = f.exit;
        *kind = Exit;
    }
    return best;
}

/* AOSP SlopController::consumeEvent: the counts that pass */
qreal RotaryInput::applySlop(qreal counts)
{
    const bool reset = !m_slopTime.isValid() || m_slopTime.elapsed() >= SLOP_DURATION_MS
            || (m_slopSum > 0) != (counts > 0) || qFuzzyIsNull(m_slopSum);
    if (reset) {
        m_slopSum = 0;
        m_slopMet = false;
    }
    m_slopTime.start();
    if (m_slopMet)
        return counts;
    m_slopSum += counts;
    if (qAbs(m_slopSum) >= SLOP_COUNTS) {
        m_slopMet = true;
        return (counts > 0 ? 1 : -1) * (qAbs(m_slopSum) - SLOP_COUNTS);
    }
    return 0;
}

bool RotaryInput::handleWheel(QQuickWindow *window, QWheelEvent *event)
{
    qreal counts = event->angleDelta().y() / 120.0;
    if (qFuzzyIsNull(counts))
        counts = event->angleDelta().x() / 120.0;
    if (qFuzzyIsNull(counts))
        return false;

    /* Stock: the input layer drops the first counts after a rest */
    if (!m_fast) {
        counts = applySlop(counts);
        if (qFuzzyIsNull(counts)) {
            qCDebug(lcRotary) << "slop" << event->angleDelta() << m_slopSum;
            event->accept();
            return true;
        }
    }

    /* A new crown gesture: find what to drive (also when the picker group
     * that chose the target has moved its focus to another column) */
    const bool redirected = m_redirector
            && qobject_cast<QQuickItem *>(m_redirector->property("rotaryTarget").value<QObject *>()) != m_target;
    const bool newGesture = !m_lastEvent.isValid() || m_lastEvent.elapsed() > GESTURE_GAP_MS
            || !m_target || m_target->window() != window || redirected;
    if (newGesture) {
        QPointF pos(window->width() / 2.0, window->height() / 2.0);
        if (m_pressWindow == window && m_pressTime.isValid() && m_pressTime.elapsed() < PRESS_MEMORY_MS)
            pos = m_pressPos;
        bool blocked = false;
        bool modal = false;
        Kind kind = None;
        QQuickItem *t = findTarget(window, pos, &kind, &blocked, &modal);
        if (!blocked && !t && modal) {
            /* a shown Dialog with nothing to scroll: the crown turns
             * nothing, and Qt must not hand the wheel to the screen under
             * it (stock: the dialog window takes the rotary input) */
            qCDebug(lcRotary) << "modal, nothing to scroll" << event->angleDelta();
            m_target = nullptr;
            m_redirector = nullptr;
            m_kind = None;
            event->accept();
            return true;
        }
        if (blocked || !t) {
            qCDebug(lcRotary) << "pass" << event->angleDelta() << (blocked ? "(WheelHandler)" : "(no view)");
            m_target = nullptr;
            m_redirector = nullptr;
            m_kind = None;
            return false;
        }
        if (m_target != t || m_kind != kind) {
            m_frame->stop();
            m_flinging = false;
            m_flingTimer.stop();
            m_samples.clear();
            m_pending = 0;
            m_tickAcc = 0;
            m_limitArmed = true;
            m_exitSum = 0;
            m_speedTimer.stop();
            m_crown.reset();
        }
        m_target = t;
        m_kind = kind;
        m_speed = 0;
        m_redirector = nullptr;
        for (QQuickItem *i = t->parentItem(); i; i = i->parentItem()) {
            const QVariant rt = i->property("rotaryTarget");
            if (rt.isValid() && qobject_cast<QQuickItem *>(rt.value<QObject *>()) == t) {
                m_redirector = i;
                break;
            }
        }
        m_exitReceiver = exitReceiverFor(t);
        if (kind == Free)
            m_horizontal = !scrollsVertically(t) && scrollsHorizontally(t);
        else if (kind == Snap || kind == Speed)
            m_horizontal = t->property("orientation").toInt() == 1; /* ListView.Horizontal */
        else
            m_horizontal = false;
        qCDebug(lcRotary) << "target" << t << "kind" << kind << (m_horizontal ? "horizontal" : "vertical");
    }

    /* crown speed in detents per second, smoothed over a few events */
    const qint64 gapMs = m_lastEvent.isValid() ? m_lastEvent.elapsed() : -1;
    if (m_lastEvent.isValid()) {
        const qreal dt = qMax<qint64>(1, gapMs) / 1000.0;
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
    case Speed:
        scrollSpeed(forward);
        break;
    case Exit:
        /* nothing scrolls: every count pushes past the end */
        if (!pushPastEnd(forward * pxPerCount(m_target)))
            return false;
        break;
    case Snap:
    case Path:
        if (m_fast) {
            /* the user's crown: one item per detent */
            m_pending += forward;
            const int steps = int(m_pending / m_detent);
            if (steps != 0) {
                m_pending -= steps * m_detent;
                stepSnap(steps);
            }
        } else {
            /* stock: a speed-dependent share of the item size */
            const qreal px = forward * pxPerCount(m_target);
            if (gapMs < 0 || gapMs > SNAP_GESTURE_BREAK_MS || newGesture) {
                m_pending = 0;
                m_snapVelocity = 0;
            } else {
                const qreal v = qAbs(px) / qMax<qint64>(1, gapMs) * 1000.0;
                m_snapVelocity = v * SNAP_VELOCITY_SMOOTHING + (1 - SNAP_VELOCITY_SMOOTHING) * m_snapVelocity;
            }
            const qreal threshold = snapThreshold(px);
            m_pending += px;
            int steps = int(m_pending / threshold);
            if (steps != 0) {
                m_pending -= steps * threshold;
                steps = qBound(-MAX_SNAPS_PER_EVENT, steps, MAX_SNAPS_PER_EVENT);
                if (qAbs(m_pending) >= threshold)
                    m_pending = std::fmod(m_pending, threshold);
                stepSnap(steps);
            }
        }
        break;
    default:
        return false;
    }
    event->accept();
    return true;
}

/* Stock snap threshold in crown px for the current smoothed speed */
qreal RotaryInput::snapThreshold(qreal px)
{
    Q_UNUSED(px)
    const qreal u = qBound<qreal>(0, (m_snapVelocity - SNAP_MIN_VELOCITY)
                                  / (SNAP_MAX_VELOCITY - SNAP_MIN_VELOCITY), 1);
    const qreal e = cubicBezier(0.5, 0, 0.5, 1, u);
    /* pagers (one item per page) use the High sensitivity dividers */
    const bool pager = m_kind == Snap && m_target && m_target->property("snapMode").toInt() == 2;
    const qreal divider = pager ? PAGER_DIVIDER_MIN + (PAGER_DIVIDER_MAX - PAGER_DIVIDER_MIN) * e
                                : SNAP_DIVIDER_MIN + (SNAP_DIVIDER_MAX - SNAP_DIVIDER_MIN) * e;
    return qMax<qreal>(1, itemSize() / divider);
}

/* The size of one item along the crown's axis (with the view's spacing) */
qreal RotaryInput::itemSize() const
{
    QQuickItem *v = m_target;
    if (!v)
        return 42;
    const int index = v->property("currentIndex").toInt();
    QQuickItem *cur = nullptr;
    QMetaObject::invokeMethod(v, "itemAtIndex", Q_RETURN_ARG(QQuickItem *, cur), Q_ARG(int, index));
    if (m_kind == Path) {
        /* items sit along the path: the distance between two neighbours */
        QQuickItem *next = nullptr;
        const int count = v->property("count").toInt();
        QMetaObject::invokeMethod(v, "itemAtIndex", Q_RETURN_ARG(QQuickItem *, next),
                                  Q_ARG(int, (index + 1) % qMax(1, count)));
        if (cur && next && cur != next) {
            const QPointF a = cur->mapToItem(v, QPointF(cur->width() / 2, cur->height() / 2));
            const QPointF b = next->mapToItem(v, QPointF(next->width() / 2, next->height() / 2));
            const qreal d = QLineF(a, b).length();
            if (d >= 1)
                return d;
        }
        return cur && cur->height() >= 1 ? cur->height() : tickPx(v);
    }
    if (!cur)
        cur = qvariant_cast<QQuickItem *>(v->property("currentItem"));
    const qreal size = cur ? (m_horizontal ? cur->width() : cur->height()) : 0;
    if (size < 1)
        return tickPx(v);
    return size + qMax<qreal>(0, v->property("spacing").toReal());
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

/* The end bump (SCROLL_LIMIT): once per end, armed again when the view has
 * moved (stock HapticScrollFeedbackProvider mCanPlayLimitFeedback) */
void RotaryInput::playLimit(qreal pos)
{
    if (!m_limitArmed && qAbs(pos - m_limitPos) < 1)
        return;
    m_limitArmed = false;
    m_limitPos = pos;
    Haptics::instance()->scrollLimit();
}

/* The crown pushes px past an end. True when a rotary exit receiver took it
 * (then no end bump: stock consumes the event while it accumulates). */
bool RotaryInput::pushPastEnd(qreal px)
{
    QObject *r = m_exitReceiver;
    if (!r || qFuzzyIsNull(px))
        return false;
    const int dir = px > 0 ? 1 : -1;
    const QVariant edge = r->property("rotaryExitEdge");
    if (edge.isValid() && edge.toInt() != 0 && edge.toInt() != dir)
        return false;
    if (!m_exitTime.isValid() || m_exitTime.elapsed() > EXIT_GAP_MS
            || (!qFuzzyIsNull(m_exitSum) && (m_exitSum > 0) != (px > 0)))
        m_exitSum = 0;
    m_exitTime.start();
    m_exitSum += px;
    if (qAbs(m_exitSum) > EXIT_THRESHOLD_PX) {
        m_exitSum = 0;
        qCDebug(lcRotary) << "rotary exit" << dir << r;
        QMetaObject::invokeMethod(r, "rotaryExit", Q_ARG(int, dir));
    }
    return true;
}

void RotaryInput::scrollFree(qreal forward)
{
    QQuickItem *f = m_target;
    qreal gain = 1;
    if (m_fast) {
        const qreal fast = qBound<qreal>(0, (m_speed - FAST_FROM) / (FAST_TO - FAST_FROM), 1);
        gain = 1 + (MAX_GAIN - 1) * fast * fast * (3 - 2 * fast);
    }
    const qreal px = forward * pxPerCount(f) * gain;

    const qreal current = f->property(posName(m_horizontal)).toReal();
    if (!gliding()) {
        /* starting from rest: stop a finger fling first */
        QMetaObject::invokeMethod(f, "cancelFlick");
        m_goal = current;
    }
    /* the crown takes over from its own fling where the fling has got to */
    m_flinging = false;
    const qreal lo = minPos(f, m_horizontal);
    const qreal hi = maxPos(f, m_horizontal);
    const qreal before = m_goal;
    const qreal wanted = m_goal + px;
    m_goal = qBound(lo, wanted, hi);
    const qreal applied = m_goal - before;
    if (qAbs(applied) < 0.01) {
        /* pushing against an end */
        if (!pushPastEnd(px))
            playLimit(m_goal);
        return;
    }
    m_exitSum = 0;
    m_limitArmed = true;
    /* SCROLL_TICK every 21 dp of crown scroll, the remainder carried over
     * (stock HapticScrollFeedbackProvider.onScrollProgress) */
    const qreal tick = tickPx(f);
    m_tickAcc += applied;
    if (qAbs(m_tickAcc) >= tick) {
        m_tickAcc = std::fmod(m_tickAcc, tick);
        Haptics::instance()->scrollTick();
    }
    if (!m_fast)
        noteFlingSample(px);
    if (m_indicatorOn && !m_horizontal)
        showIndicator(f, true);
    if (!gliding()) {
        startGlide();
    }
}

void RotaryInput::noteFlingSample(qreal px)
{
    const qint64 now = m_clock.elapsed();
    if (!m_samples.isEmpty() && (now - m_samples.last().first > FLING_EVENT_GAP_MS
                                 || (m_samples.last().second > 0) != (px > 0)))
        m_samples.clear();
    m_samples.append(qMakePair(now, px));
    while (m_samples.size() > 2 && now - m_samples.first().first > FLING_HORIZON_MS)
        m_samples.removeFirst();
    m_flingTimer.start();
}

/* 30 ms after the last crown event: fling when the crown was fast */
void RotaryInput::maybeFling()
{
    const QList<QPair<qint64, qreal>> samples = m_samples;
    m_samples.clear();
    QQuickItem *f = m_target;
    if (m_fast || m_kind != Free || !f || samples.size() < 2)
        return;
    const qint64 span = samples.last().first - samples.first().first;
    if (span <= 0)
        return;
    qreal sum = 0;
    for (int i = 1; i < samples.size(); i++)
        sum += samples.at(i).second;
    const qreal density = densityOf(f);
    qreal v = sum / span * 1000.0 * FLING_SCALE;
    qCDebug(lcRotary) << "crown velocity" << v << "px/s over" << samples.size() << "events";
    if (qAbs(v) <= MIN_ROTARY_FLING_DP * density)
        return;
    v = qBound(-MAX_ROTARY_FLING_DP * density, v, MAX_ROTARY_FLING_DP * density);
    const qreal ppi = density * 160;
    m_flingDuration = FlingSpline::duration(qAbs(v), ppi);
    m_flingDistance = (v < 0 ? -1 : 1) * FlingSpline::distance(qAbs(v), ppi);
    if (m_flingDuration <= 0 || qAbs(m_flingDistance) < 0.5)
        return;
    m_flingFrom = m_goal;
    m_flingElapsed = 0;
    m_flinging = true;
    startGlide();
}

void RotaryInput::animate(qreal dt)
{
    QQuickItem *f = m_target;
    if (!f || m_kind == None || m_kind == Exit) {
        m_frame->stop();
        m_flinging = false;
        return;
    }
    if (m_flinging) {
        /* the crown fling moves the goal along the AOSP spline; the
         * smoothing spring follows it */
        m_flingElapsed += dt;
        const qreal t = qMin<qreal>(1, m_flingElapsed / m_flingDuration);
        const qreal g = m_flingFrom + m_flingDistance * FlingSpline::position(t);
        m_goal = qBound(minPos(f, m_horizontal), g, maxPos(f, m_horizontal));
        if (t >= 1 || g != m_goal)
            m_flinging = false;
    }
    const qreal current = f->property(posName(m_horizontal)).toReal();
    const qreal stiffness = !m_fast && m_kind == Snap ? SNAP_STIFFNESS : SMOOTHING_STIFFNESS;
    qreal x, v;
    SpringMath::step(stiffness, SMOOTHING_DAMPING, current - m_goal, m_glideVelocity,
                     dt / 1000.0, &x, &v);
    m_glideVelocity = v;
    qreal next = m_goal + x;
    /* within half a pixel and moving less than half a pixel a frame */
    const bool done = !m_flinging && qAbs(x) < 0.5 && qAbs(v) < 30;
    if (done)
        next = m_goal;
    f->setProperty(posName(m_horizontal), next);
    if (done) {
        m_frame->stop();
        if (m_kind == Snap)
            m_pending = 0;
        if (m_kind == Speed)
            speedSettled();
    }
}

/* Crown-speed mode: the content range. With StrictlyEnforceRange the first
 * item can reach preferredHighlightBegin (the view's origin already lies
 * that far before the first item) and the last one preferredHighlightEnd */
void RotaryInput::speedBounds(qreal *lo, qreal *hi) const
{
    QQuickItem *v = m_target;
    if (v->property("highlightRangeMode").toInt() == 2) {
        const qreal content = v->property(m_horizontal ? "contentWidth" : "contentHeight").toReal();
        *lo = minPos(v, m_horizontal);
        *hi = qMax(*lo, *lo + v->property("preferredHighlightBegin").toReal() + content
                   - v->property("preferredHighlightEnd").toReal());
        return;
    }
    *lo = minPos(v, m_horizontal);
    *hi = maxPos(v, m_horizontal);
}

/* Where the content rests with `item` snapped: its start at the view's
 * start, or at preferredHighlightBegin for StrictlyEnforceRange */
qreal RotaryInput::speedSnapPos(QQuickItem *item) const
{
    QQuickItem *v = m_target;
    qreal pos = m_horizontal ? item->x() : item->y();
    if (v->property("highlightRangeMode").toInt() == 2)
        pos -= v->property("preferredHighlightBegin").toReal();
    qreal lo, hi;
    speedBounds(&lo, &hi);
    return qBound(lo, pos, hi);
}

/* Crown-speed mode: one crown event scrolls the view by the crown's pixels */
void RotaryInput::scrollSpeed(qreal forward)
{
    QQuickItem *v = m_target;
    qreal gain = 1;
    if (m_fast) {
        const qreal fast = qBound<qreal>(0, (m_speed - FAST_FROM) / (FAST_TO - FAST_FROM), 1);
        gain = 1 + (MAX_GAIN - 1) * fast * fast * (3 - 2 * fast);
    }
    const qreal px = forward * pxPerCount(v) * gain;
    if (!gliding())
        QMetaObject::invokeMethod(v, "cancelFlick");
    qreal lo, hi;
    speedBounds(&lo, &hi);
    const CrownSpeed::Event e = m_crown.scroll(v->property(posName(m_horizontal)).toReal(), px, lo, hi,
                                               tickPx(v), m_clock.elapsed());
    m_goal = e.goal;
    m_speedIndex = -1;
    /* the snap follows 80 ms after the last crown event */
    m_speedTimer.start();
    qCDebug(lcRotary) << "crown speed" << px << "goal" << m_goal << "range" << lo << hi;
    if (e.atEnd) {
        if (!pushPastEnd(px) && m_crown.limit(m_goal))
            Haptics::instance()->scrollLimit();
        return;
    }
    m_exitSum = 0;
    if (e.tick)
        Haptics::instance()->scrollTick();
    startGlide();
}

/* Crown-speed mode, 80 ms after the last crown event: glide to the nearest
 * item (the snap positions of the items around the goal, and the ends).
 * Stock's content is at the goal at once; this one glides there (the
 * smoothing spring), so a snap still due when the glide ends starts then,
 * with the items at the goal made */
void RotaryInput::snapSpeed()
{
    QQuickItem *v = m_target;
    if (!v || m_kind != Speed || m_crown.state() != CrownSpeed::Scrolling)
        return;
    if (!m_crown.snapDue(m_clock.elapsed())) {
        m_speedTimer.start();
        return;
    }
    if (gliding())
        return;
    const bool range = v->property("highlightRangeMode").toInt() == 2;
    const qreal goal = m_crown.goal();
    const qreal along = goal + 1 + (range ? v->property("preferredHighlightBegin").toReal() : 0);
    const qreal across = m_horizontal ? v->property("contentY").toReal() + v->height() / 2
                                      : v->property("contentX").toReal() + v->width() / 2;
    int index = -1;
    QMetaObject::invokeMethod(v, "indexAt", Q_RETURN_ARG(int, index),
                              Q_ARG(qreal, m_horizontal ? along : across),
                              Q_ARG(qreal, m_horizontal ? across : along));
    if (index < 0)
        index = v->property("currentIndex").toInt();
    const int count = v->property("count").toInt();
    std::vector<double> positions;
    std::vector<int> indexes;
    for (int i = qMax(0, index - 2); i <= qMin(count - 1, index + 2); i++) {
        QQuickItem *item = nullptr;
        QMetaObject::invokeMethod(v, "itemAtIndex", Q_RETURN_ARG(QQuickItem *, item), Q_ARG(int, i));
        if (!item)
            continue;
        positions.push_back(speedSnapPos(item));
        indexes.push_back(i);
    }
    if (!range) {
        /* a list that cannot bring its last items to the start rests at its end */
        qreal lo, hi;
        speedBounds(&lo, &hi);
        positions.push_back(lo);
        indexes.push_back(-1);
        positions.push_back(hi);
        indexes.push_back(-1);
    }
    const int k = m_crown.snap(positions);
    if (k < 0)
        return;
    m_speedIndex = indexes[k];
    m_goal = m_crown.goal();
    qCDebug(lcRotary) << "crown speed snap to" << m_speedIndex << "at" << m_goal;
    startGlide();
}

/* The glide has stopped: a snap that is due starts; after a snap, the
 * snapped item of a highlight range is the current one */
void RotaryInput::speedSettled()
{
    if (m_crown.state() == CrownSpeed::Scrolling) {
        /* after this frame: the glide starts again from an event, not from its own frame */
        if (m_crown.snapDue(m_clock.elapsed()))
            QTimer::singleShot(0, this, &RotaryInput::snapSpeed);
        return;
    }
    if (m_crown.state() != CrownSpeed::Snapping)
        return;
    m_crown.settled();
    QQuickItem *v = m_target;
    if (v && m_speedIndex >= 0 && v->property("highlightRangeMode").toInt() == 2
            && v->property("currentIndex").toInt() != m_speedIndex)
        v->setProperty("currentIndex", m_speedIndex);
    m_speedIndex = -1;
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
        const int after = v->property("currentIndex").toInt();
        if (after != before) {
            m_limitArmed = true;
            Haptics::instance()->scrollFocus();
        } else {
            playLimit(after);
        }
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
        playLimit(index);
        return;
    }
    m_limitArmed = true;
    QQuickItem *item = nullptr;
    QMetaObject::invokeMethod(v, "itemAtIndex", Q_RETURN_ARG(QQuickItem *, item), Q_ARG(int, target));
    if (!item) {
        /* not instantiated (far away): jump */
        QMetaObject::invokeMethod(v, "positionViewAtIndex", Q_ARG(int, target), Q_ARG(int, 5 /* SnapPosition */));
        Haptics::instance()->scrollFocus();
        return;
    }
    if (!gliding())
        QMetaObject::invokeMethod(v, "cancelFlick");
    m_goal = qBound(minPos(v, horizontal), horizontal ? item->x() : item->y(), maxPos(v, horizontal));
    /* SCROLL_ITEM_FOCUS once per snapped item */
    Haptics::instance()->scrollFocus();
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

bool RotaryInput::showIndicator(QQuickItem *flickable, bool flash)
{
    QQuickWindow *window = flickable->window();
    if (!window || !ensureIndicator(window, flickable))
        return false;
    m_indicator->setProperty("flickable", QVariant::fromValue<QObject *>(flickable));
    if (flash)
        QMetaObject::invokeMethod(m_indicator, "flash");
    return true;
}

void RotaryInput::setSystemIndicator(bool on)
{
    if (on == m_systemIndicator)
        return;
    m_systemIndicator = on;
    emit systemIndicatorChanged();
}

/* A list screen opens (stock: the screen stage is New for 2 s and the
 * indicator shows while the stage is not Idle) */
bool RotaryInput::flashIndicator(QQuickItem *flickable)
{
    if (!m_indicatorOn || !flickable || !flickable->isVisible()
            || !flickable->inherits("QQuickFlickable") || !scrollsVertically(flickable))
        return false;
    return showIndicator(flickable, true);
}

void RotaryInput::coverIndicator(QQuickItem *cover)
{
    if (!m_indicator || !cover)
        return;
    QQuickItem *f = qobject_cast<QQuickItem *>(m_indicator->property("flickable").value<QObject *>());
    if (f && cover->isAncestorOf(f))
        return;
    m_indicator->setProperty("shown", false);
}
