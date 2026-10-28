/*
 * Copyright (C) 2015 Florent Revest <revestflo@gmail.com>
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

#include "application_p.h"
#include "backswipearea.h"
#include "gesturesextension.h"

#include <QMouseEvent>
#include <QTouchEvent>

Application_p::Application_p() : QQuickItem()
{
    m_overridesSystemGestures = false;
}

Application_p::~Application_p()
{
    if (m_watched)
        m_watched->removeEventFilter(this);
}

void Application_p::setBackFromAnywhere(bool enable)
{
    if (m_backFromAnywhere == enable)
        return;
    m_backFromAnywhere = enable;
    applyBackToCompositor();
    emit backFromAnywhereChanged();
}

void Application_p::itemChange(ItemChange change, const ItemChangeData &value)
{
    if (change == ItemSceneChange) {
        if (m_watched)
            m_watched->removeEventFilter(this);
        m_watched = value.window;
        if (m_watched)
            m_watched->installEventFilter(this);
    }
    QQuickItem::itemChange(change, value);
}

/* Per touch, before the compositor decides (it waits for 12 px of travel):
 * may a swipe right from here go back? Not on content that moves sideways */
bool Application_p::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_watched) {
        QPointF pos;
        bool press = false;
        if (event->type() == QEvent::TouchBegin) {
            QTouchEvent *te = static_cast<QTouchEvent *>(event);
            if (te->pointCount() > 0) {
                pos = te->points().first().scenePosition();
                press = true;
            }
        } else if (event->type() == QEvent::MouseButtonPress) {
            QMouseEvent *me = static_cast<QMouseEvent *>(event);
            if (me->source() == Qt::MouseEventNotSynthesized) {
                pos = me->scenePosition();
                press = true;
            }
        } else if (event->type() == QEvent::Expose && m_sentBack < 0) {
            applyBackToCompositor();
        }
        if (press) {
            m_touchBlocked = BackSwipeArea::blockedUnder(m_watched->contentItem(), pos);
            applyBackToCompositor();
        }
    }
    return QQuickItem::eventFilter(watched, event);
}

void Application_p::applyBackToCompositor()
{
    auto *win = window();
    if (!win || !win->isExposed())
        return;
    if (!m_gestureSurface)
        m_gestureSurface.reset(GestureSurface::forWindow(win));
    if (!m_gestureSurface)
        return;
    const int want = (m_backFromAnywhere && !m_touchBlocked) ? 1 : 0;
    if (want == m_sentBack)
        return;
    m_sentBack = want;
    m_gestureSurface->setBackFromAnywhere(want);
}

void Application_p::setOverridesSystemGestures(bool enable)
{
    if (m_overridesSystemGestures == enable)
        return;

    m_overridesSystemGestures = enable;
    applyOverrideToCompositor();
    emit overridesSystemGesturesChanged();
}

bool Application_p::overridesSystemGestures()
{
    return m_overridesSystemGestures;
}

void Application_p::applyOverrideToCompositor()
{
    // The wl_surface only exists once the window has been created and
    // exposed; setOverridesSystemGestures may run before that. Defer to
    // windowChanged()/QQuickItem::componentComplete in that case via a
    // single-shot connection.
    auto *win = window();
    if (!win) {
        connect(this, &QQuickItem::windowChanged, this,
                [this](QQuickWindow *) { applyOverrideToCompositor(); },
                Qt::SingleShotConnection);
        return;
    }

    if (!m_gestureSurface)
        m_gestureSurface.reset(GestureSurface::forWindow(win));

    if (m_gestureSurface)
        m_gestureSurface->set_overrides_system_gestures(m_overridesSystemGestures ? 1 : 0);
}
