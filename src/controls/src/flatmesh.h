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

#ifndef FLATMESH_H
#define FLATMESH_H

#include <QQuickItem>
#include <QSGNode>
#include <QColor>
#include <QTimer>
#include <QElapsedTimer>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

class QQuickWindow;

/*
 * The animated triangle background of the launcher and of every application
 * (Application.qml). It moves one step every 90 ms while it is animated, and
 * it only does so while somebody can see it move:
 *  - the item is visible (effective visibility: the launcher hides its home
 *    screen, wallpaper included, while an application covers it, and hides
 *    the wallpaper in always-on-display mode),
 *  - its window is shown and exposed (the compositor hides its window when
 *    the display is off; a Wayland client is unexposed when the compositor
 *    stops sending it frame callbacks),
 *  - and it is not idle: after idleTimeout ms without input on its window
 *    it holds its last frame, and the next touch, crown/wheel or key event,
 *    the window being shown again or the item becoming visible again
 *    resumes it from where it stopped.
 * The idle timeout comes from dconf (seconds, 0 = always animate while
 * visible, the stock behaviour; unset or not a number = 0):
 *   /org/asteroidos/settings/flatmesh-idle-timeout       applications
 *   /org/asteroidos/settings/flatmesh-idle-timeout-home  the launcher (the
 *       compositor process); unset = same as the applications key
 * Both are read live. A QML idleTimeout binding (ms) overrides them.
 * Logging category: asteroid.flatmesh (debug: every start/hold).
 */
class FlatMesh : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FlatMesh)
    Q_PROPERTY(QColor centerColor WRITE setCenterColor READ getCenterColor)
    Q_PROPERTY(QColor outerColor WRITE setOuterColor READ getOuterColor)
    Q_PROPERTY(bool animated WRITE setAnimated READ getAnimated NOTIFY animatedChanged)
    Q_PROPERTY(int idleTimeout READ idleTimeout WRITE setIdleTimeout RESET resetIdleTimeout NOTIFY idleTimeoutChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)

public:
    FlatMesh(QQuickItem *parent = 0);
    ~FlatMesh() override;

    bool getAnimated() const { return m_animated; }
    void setAnimated(bool animated);

    QColor getCenterColor() const { return m_centerColor; }
    void setCenterColor(QColor c);

    QColor getOuterColor() const { return m_outerColor; }
    void setOuterColor(QColor c);

    /* Effective idle timeout in ms, 0 = never idle (always animate) */
    int idleTimeout() const;
    /* ms; a negative value goes back to the system setting */
    void setIdleTimeout(int ms);
    void resetIdleTimeout() { setIdleTimeout(-1); }

    /* Whether the mesh is moving right now */
    bool isRunning() const { return m_timer.isActive(); }

    /* Counts as user activity: resumes an idle mesh for another idleTimeout */
    Q_INVOKABLE void wake();

signals:
    void animatedChanged();
    void idleTimeoutChanged();
    void runningChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *node, UpdatePaintNodeData *data) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    bool eventFilter(QObject *watched, QEvent *event) override;

private slots:
    void maybeEnableAnimation();
    void animate();
    void onVisibleChanged();
    void reloadIdleTimeout();

private:
    void watchWindow(QQuickWindow *window);
    void noteActivity();
    bool windowShowing() const;

    QColor m_centerColor, m_outerColor;
    bool m_animated;
    bool m_colorsDirty;
    float m_animationState;
    int m_loopCount;
    float m_screenScaleFactor;
    bool m_idle;
    int m_idleTimeoutOverride;   /* ms, < 0: use the system setting */
    int m_systemIdleTimeout;     /* ms, from dconf, 0 = never idle */
    QElapsedTimer m_lastActivity;
    QPointer<QQuickWindow> m_window;
    QTimer m_timer;
};

#endif // FLATMESH_H
