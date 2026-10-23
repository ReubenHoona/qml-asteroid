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

#include <QSettings>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QMouseEvent>
#include <QLoggingCategory>
#include <MDConfItem>

Q_STATIC_LOGGING_CATEGORY(lcFlatMesh, "asteroid.flatmesh", QtWarningMsg)

/* Seconds of animation after the last input when dconf has no value.
 * 0 = never hold a mesh that is on screen: the stock look. A hidden window,
 * an unexposed Wayland surface or an invisible item always stops the mesh
 * (nobody can see it move); holding a visible mesh after a quiet period is
 * opt-in through the dconf keys below (10 s is the tested value: two full
 * 4.5 s loops of 50 steps after each touch). */
static const double DEFAULT_IDLE_TIMEOUT_S = 0.0;

static const char APPS_KEY[] = "/org/asteroidos/settings/flatmesh-idle-timeout";
static const char HOME_KEY[] = "/org/asteroidos/settings/flatmesh-idle-timeout-home";

namespace {
/* One set of dconf watchers per process, shared by every FlatMesh */
struct FlatMeshSettings {
    MDConfItem *apps = nullptr;
    MDConfItem *home = nullptr;   /* only in the compositor (launcher) */
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
        qCDebug(lcFlatMesh) << "platform" << platform << (s->isHome ? "(home)" : "(application)");
    }
    return s;
}

/* The idle timeout from dconf in ms, 0 = never idle. Unset or unreadable
 * keys give the default; the home key, when set, wins in the launcher. */
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
        if (ok)
            sec = d;
    }
    if (sec <= 0.0)
        return 0;
    return int(qBound(0.5, sec, 86400.0) * 1000.0);
}

FlatMesh::FlatMesh(QQuickItem *parent) : QQuickItem(parent),
    m_animated(false), m_colorsDirty(true), m_animationState(0.0f), m_loopCount(0),
    m_idle(false), m_idleTimeoutOverride(-1), m_systemIdleTimeout(0)
{
    m_timer.setInterval(90);
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &FlatMesh::animate);

    m_centerColor = QColor("#ffaa39");
    m_outerColor = QColor("#df4829");

    QSettings machineConf("/etc/asteroid/machine.conf", QSettings::IniFormat);
    m_screenScaleFactor = machineConf.value("Display/ROUND", false).toBool() ? 1.2f : 1.7f;

    FlatMeshSettings *s = flatMeshSettings();
    connect(s->apps, &MDConfItem::valueChanged, this, &FlatMesh::reloadIdleTimeout);
    if (s->home)
        connect(s->home, &MDConfItem::valueChanged, this, &FlatMesh::reloadIdleTimeout);
    m_systemIdleTimeout = systemIdleTimeoutMs();
    m_lastActivity.start();

    connect(this, &QQuickItem::visibleChanged, this, &FlatMesh::onVisibleChanged);

    setFlag(ItemHasContents);
    setAnimated(true);
}

FlatMesh::~FlatMesh()
{
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
        /* A new policy starts a new countdown; 0 resumes a held mesh */
        wake();
    }
}

void FlatMesh::reloadIdleTimeout()
{
    const int old = idleTimeout();
    m_systemIdleTimeout = systemIdleTimeoutMs();
    if (idleTimeout() != old) {
        qCDebug(lcFlatMesh) << this << "idle timeout" << idleTimeout() << "ms";
        emit idleTimeoutChanged();
        wake();
    }
}

void FlatMesh::wake()
{
    noteActivity();
}

void FlatMesh::noteActivity()
{
    m_lastActivity.restart();
    if (m_idle) {
        m_idle = false;
        maybeEnableAnimation();
    }
}

bool FlatMesh::windowShowing() const
{
    return m_window && m_window->isVisible() && m_window->isExposed();
}

void FlatMesh::maybeEnableAnimation()
{
    const bool run = m_animated && isVisible() && windowShowing() && !m_idle;
    if (run == m_timer.isActive())
        return;
    if (run)
        m_timer.start();
    else
        m_timer.stop();   /* the last frame stays on screen */
    qCDebug(lcFlatMesh) << this << (run ? "animating" : "holding")
                        << "visible" << isVisible() << "window" << windowShowing()
                        << "idle" << m_idle << "timeout" << idleTimeout();
    emit runningChanged();
}

void FlatMesh::onVisibleChanged()
{
    /* Becoming visible (the home screen coming back when an application
     * closes, the display waking up from always-on mode) counts as activity */
    if (isVisible()) {
        m_lastActivity.restart();
        m_idle = false;
    }
    maybeEnableAnimation();
}

void FlatMesh::setAnimated(bool animated)
{
    if (animated == m_animated)
        return;
    m_animated = animated;
    emit animatedChanged();
    if (animated) {
        m_lastActivity.restart();
        m_idle = false;
    }
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
        m_idle = false;
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
            m_idle = false;
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

void FlatMesh::animate()
{
    if (!windowShowing()) {
        maybeEnableAnimation();
        return;
    }
    const int timeout = idleTimeout();
    if (timeout > 0 && m_lastActivity.elapsed() >= timeout) {
        /* Hold the frame on screen; the next input resumes from here */
        m_idle = true;
        maybeEnableAnimation();
        return;
    }

    m_animationState += 0.02f;
    if (m_animationState >= 1.0f) {
        m_animationState = 0.0f;
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
