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

#ifndef APPLICATION_P_H
#define APPLICATION_P_H

#include <QQuickItem>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>
#include <memory>
#include <QPointer>

class GestureSurface;

class Application_p : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Application_p)
    Q_PROPERTY(QQuickWindow* window READ window CONSTANT)
    Q_PROPERTY(bool overridesSystemGestures READ overridesSystemGestures WRITE setOverridesSystemGestures NOTIFY overridesSystemGesturesChanged)
    /* At its root page (no override), a swipe right from anywhere closes
     * the application, as Wear OS does, unless the touch starts on content
     * that moves sideways (see BackSwipeArea). Default true. */
    Q_PROPERTY(bool backFromAnywhere READ backFromAnywhere WRITE setBackFromAnywhere NOTIFY backFromAnywhereChanged)

public:
    explicit Application_p();
    ~Application_p();
    Q_INVOKABLE void setOverridesSystemGestures(bool enable);
    bool overridesSystemGestures();
    bool backFromAnywhere() const { return m_backFromAnywhere; }
    void setBackFromAnywhere(bool enable);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    void applyOverrideToCompositor();
    void applyBackToCompositor();

    bool m_overridesSystemGestures;
    bool m_backFromAnywhere = true;
    bool m_touchBlocked = false;
    int m_sentBack = -1;
    QPointer<QQuickWindow> m_watched;
    std::unique_ptr<GestureSurface> m_gestureSurface;

signals:
    void overridesSystemGesturesChanged();
    void backFromAnywhereChanged();
};

#endif // APPLICATION_P_H
