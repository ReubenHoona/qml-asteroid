/*
 * Copyright (C) 2016 Florent Revest <revestflo@gmail.com>
 * All rights reserved.
 *
 * You may use this file under the terms of BSD license as follows:
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the author nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "flatmesh.h"
#include "flatmeshnode.h"

#include <QAbstractAnimation>
#include <QSettings>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QMouseEvent>
#include <QLoggingCategory>
#include <MDConfItem>

Q_STATIC_LOGGING_CATEGORY(lcFlatMesh, "asteroid.flatmesh", QtWarningMsg)

/* Seconds of glide after the last input in "input" mode when dconf has no
 * value */
static const double DEFAULT_IDLE_TIMEOUT_S = 3.0;
/* The glide slows down to a stop over this last part of it, and picks up
 * speed over RAMP_UP_MS when input starts it again, so it never jumps */
static const int SLOW_DOWN_MS = 600;
static const int RAMP_UP_MS = 250;
/* The stock speed: 0.02 of a loop every 90 ms */
static const float LOOPS_PER_MS = 0.02f / 90.0f;

static const char APPS_KEY[] = "/org/asteroidos/settings/flatmesh-idle-timeout";
static const char HOME_KEY[] = "/org/asteroidos/settings/flatmesh-idle-timeout-home";
static const char MOTION_KEY[] = "/org/asteroidos/settings/flatmesh-motion";

/* Driven by Qt Quick's animation driver: once per frame, in step with the
 * display, for as long as it runs */
class FlatMeshAnimation : public QAbstractAnimation
{
public:
    explicit FlatMeshAnimation(FlatMesh *mesh) : QAbstractAnimation(mesh), m_mesh(mesh) { }
    int duration() const override { return -1; }

protected:
    void updateCurrentTime(int currentTime) override { m_mesh->advance(currentTime); }

private:
    FlatMesh *m_mesh;
};

namespace {
/* One set of dconf watchers per process, shared by every FlatMesh */
struct FlatMeshSettings {
    MDConfItem *apps = nullptr;
    MDConfItem *home = nullptr;   /* only in the compositor (launcher) */
    MDConfItem *motion = nullptr;
    bool isHome = false;
};
}

static FlatMeshSettings *flatMeshSettings()
{
    static FlatMeshSettings *s = nullptr;
    if (!s) {
        s = new FlatMeshSettings;
        /* Applications are Wayland clients; the launcher is the compositor
         * and draws on eglfs (or hwcomposer, linuxfb) itself. */
        const QString platform = QGuiApplication::platformName();
        s->isHome = !platform.startsWith(QLatin1String("wayland"));
        s->apps = new MDConfItem(QLatin1String(APPS_KEY), qApp);
        if (s->isHome)
            s->home = new MDConfItem(QLatin1String(HOME_KEY), qApp);
        s->motion = new MDConfItem(QLatin1String(MOTION_KEY), qApp);
        qCDebug(lcFlatMesh) << "platform" << platform << (s->isHome ? "(home)" : "(application)");
    }
    return s;
}

static FlatMesh::Motion parseMotion(const QString &s, bool *ok = nullptr)
{
    if (ok)
        *ok = true;
    if (s == QLatin1String("input"))
        return FlatMesh::AfterInput;
    if (s == QLatin1String("always"))
        return FlatMesh::Always;
    if (ok && s != QLatin1String("static"))
        *ok = false;
    return FlatMesh::Static;
}

static FlatMesh::Motion systemMotion()
{
    return parseMotion(flatMeshSettings()->motion->value().toString());
}

/* The glide time from dconf in ms. Unset, unreadable or 0 keys give the
 * default; the home key, when set, wins in the launcher. */
static int systemIdleTimeoutMs()
{
    FlatMeshSettings *s = flatMeshSettings();
    QVariant v;
    if (s->home)
        v = s->home->value();
    if (!v.isValid())
        v = s->apps->value();
    double sec = DEFAULT_IDLE_TIMEOUT_S;
    if (v.isValid()) {
        bool ok = false;
        const double d = v.toDouble(&ok);
        if (ok && d > 0.0)
            sec = d;
    }
    return int(qBound(0.5, sec, 86400.0) * 1000.0);
}

FlatMesh::FlatMesh(QQuickItem *parent) : QQuickItem(parent),
    m_animated(false), m_colorsDirty(true), m_animationState(0.0f), m_loopCount(0),
    m_idleTimeoutOverride(-1), m_systemIdleTimeout(0), m_motionOverride(-1),
    m_systemMotion(Static), m_lastAdvance(0), m_speed(0.0f),
    m_animation(new FlatMeshAnimation(this))
{
    m_centerColor = QColor("#ffaa39");
    m_outerColor = QColor("#df4829");

    QSettings machineConf("/etc/asteroid/machine.conf", QSettings::IniFormat);
    m_screenScaleFactor = machineConf.value("Display/ROUND", false).toBool() ? 1.2f : 1.7f;

    FlatMeshSettings *s = flatMeshSettings();
    connect(s->apps, &MDConfItem::valueChanged, this, &FlatMesh::reloadSettings);
    if (s->home)
        connect(s->home, &MDConfItem::valueChanged, this, &FlatMesh::reloadSettings);
    connect(s->motion, &MDConfItem::valueChanged, this, &FlatMesh::reloadSettings);
    m_systemIdleTimeout = systemIdleTimeoutMs();
    m_systemMotion = systemMotion();
    m_lastActivity.start();

    connect(this, &QQuickItem::visibleChanged, this, &FlatMesh::onVisibleChanged);

    setFlag(ItemHasContents);
    setAnimated(true);
}

FlatMesh::~FlatMesh()
{
    m_animation->stop();
    if (m_window)
        m_window->removeEventFilter(this);
}

void FlatMesh::setCenterColor(QColor c)
{
    if (c == m_centerColor)
        return;
    m_centerColor = c;
    m_colorsDirty = true;
    update();
}

void FlatMesh::setOuterColor(QColor c)
{
    if (c == m_outerColor)
        return;
    m_outerColor = c;
    m_colorsDirty = true;
    update();
}

FlatMesh::Motion FlatMesh::effectiveMotion() const
{
    return m_motionOverride >= 0 ? Motion(m_motionOverride) : m_systemMotion;
}

QString FlatMesh::motion() const
{
    switch (effectiveMotion()) {
    case AfterInput: return QStringLiteral("input");
    case Always: return QStringLiteral("always");
    default: return QStringLiteral("static");
    }
}

void FlatMesh::setMotion(const QString &motion)
{
    const QString old = this->motion();
    bool ok = false;
    const Motion m = parseMotion(motion, &ok);
    m_motionOverride = motion.isEmpty() || !ok ? -1 : int(m);
    if (this->motion() != old) {
        emit motionChanged();
        wake();
        maybeEnableAnimation();
    }
}

int FlatMesh::idleTimeout() const
{
    return m_idleTimeoutOverride >= 0 ? m_idleTimeoutOverride : m_systemIdleTimeout;
}

void FlatMesh::setIdleTimeout(int ms)
{
    if (ms < 0)
        ms = -1;
    if (ms == m_idleTimeoutOverride)
        return;
    const int old = idleTimeout();
    m_idleTimeoutOverride = ms;
    if (idleTimeout() != old) {
        emit idleTimeoutChanged();
        wake();
    }
}

void FlatMesh::reloadSettings()
{
    const int oldTimeout = idleTimeout();
    const QString oldMotion = motion();
    m_systemIdleTimeout = systemIdleTimeoutMs();
    m_systemMotion = systemMotion();
    if (idleTimeout() != oldTimeout)
        emit idleTimeoutChanged();
    if (motion() != oldMotion)
        emit motionChanged();
    if (idleTimeout() != oldTimeout || motion() != oldMotion) {
        qCDebug(lcFlatMesh) << this << "motion" << motion() << "glide" << idleTimeout() << "ms";
        wake();
        maybeEnableAnimation();
    }
}

bool FlatMesh::isRunning() const
{
    return m_animation->state() == QAbstractAnimation::Running;
}

void FlatMesh::wake()
{
    noteActivity();
}

void FlatMesh::noteActivity()
{
    m_lastActivity.restart();
    if (effectiveMotion() == AfterInput && !isRunning())
        maybeEnableAnimation();
}

bool FlatMesh::windowShowing() const
{
    return m_window && m_window->isVisible() && m_window->isExposed();
}

void FlatMesh::maybeEnableAnimation()
{
    const Motion m = effectiveMotion();
    bool run = m_animated && m != Static && isVisible() && windowShowing();
    if (run && m == AfterInput && m_lastActivity.elapsed() >= idleTimeout())
        run = false;
    if (run == isRunning())
        return;
    if (run) {
        m_lastAdvance = 0;
        m_animation->start();
    } else {
        m_animation->stop();   /* the last frame stays on screen */
        m_speed = 0.0f;
    }
    qCDebug(lcFlatMesh) << this << (run ? "moving" : "still") << "motion" << motion()
                        << "visible" << isVisible() << "window" << windowShowing();
    emit runningChanged();
}

void FlatMesh::onVisibleChanged()
{
    /* Becoming visible (the home screen coming back when an application
     * closes, the display waking up from always-on mode) counts as activity */
    if (isVisible())
        m_lastActivity.restart();
    maybeEnableAnimation();
}

void FlatMesh::setAnimated(bool animated)
{
    if (animated == m_animated)
        return;
    m_animated = animated;
    emit animatedChanged();
    if (animated)
        m_lastActivity.restart();
    maybeEnableAnimation();
}

void FlatMesh::itemChange(ItemChange change, const ItemChangeData &value)
{
    if (change == ItemSceneChange)
        watchWindow(value.window);
    QQuickItem::itemChange(change, value);
}

void FlatMesh::watchWindow(QQuickWindow *window)
{
    if (window == m_window)
        return;
    if (m_window) {
        m_window->removeEventFilter(this);
        disconnect(m_window, nullptr, this, nullptr);
    }
    m_window = window;
    if (window) {
        window->installEventFilter(this);
        connect(window, &QWindow::visibleChanged, this, &FlatMesh::maybeEnableAnimation);
        m_lastActivity.restart();
    }
    maybeEnableAnimation();
}

bool FlatMesh::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window) {
        switch (event->type()) {
        case QEvent::TouchBegin:
        case QEvent::TouchUpdate:
        case QEvent::MouseButtonPress:
        case QEvent::Wheel:
        case QEvent::KeyPress:
        case QEvent::FocusIn:
            noteActivity();
            break;
        case QEvent::MouseMove:
            if (static_cast<QMouseEvent *>(event)->buttons() != Qt::NoButton)
                noteActivity();
            break;
        case QEvent::Show:
            /* The window is shown again (the display turned on) */
            m_lastActivity.restart();
            maybeEnableAnimation();
            break;
        case QEvent::Hide:
        case QEvent::Expose:
            /* QWindow::isExposed() is already updated when the expose event
             * is delivered. Exposure alone is not activity: a Wayland client
             * flips it whenever frame callbacks come late. */
            maybeEnableAnimation();
            break;
        default:
            break;
        }
    }
    return QQuickItem::eventFilter(watched, event);
}

void FlatMesh::advance(int ms)
{
    const int dt = qBound(0, ms - m_lastAdvance, 100);
    m_lastAdvance = ms;
    if (!windowShowing() || !isVisible()) {
        maybeEnableAnimation();
        return;
    }

    float target = 1.0f;
    if (effectiveMotion() == AfterInput) {
        const qint64 left = idleTimeout() - m_lastActivity.elapsed();
        if (left <= 0) {
            maybeEnableAnimation();   /* stops: the glide is over */
            return;
        }
        if (left < SLOW_DOWN_MS) {
            const float t = float(left) / SLOW_DOWN_MS;
            target = t * t * (3.0f - 2.0f * t);
        }
    }
    /* speed up gently, slow down along the target */
    m_speed = qMin(target, m_speed + float(dt) / RAMP_UP_MS);

    m_animationState += LOOPS_PER_MS * m_speed * dt;
    while (m_animationState >= 1.0f) {
        m_animationState -= 1.0f;
        m_loopCount++;
    }
    update();
}

QSGNode *FlatMesh::updatePaintNode(QSGNode *old, UpdatePaintNodeData *)
{
    FlatMeshNode *n = static_cast<FlatMeshNode *>(old);
    if (!n) {
        n = new FlatMeshNode(m_screenScaleFactor);
        m_colorsDirty = true;
    }

    if (m_colorsDirty) {
        n->updateColors(m_centerColor, m_outerColor);
        m_colorsDirty = false;
    }
    n->updateGeometry(boundingRect(), m_animationState, m_loopCount);

    return n;
}
