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
#include <QElapsedTimer>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

class QQuickWindow;
class FlatMeshAnimation;

/*
 * The triangle background of the launcher and of every application
 * (Application.qml).
 *
 * By default it is still: it is drawn once and the screen it sits on
 * produces no frame unless something on it changes. Wear OS backgrounds do
 * not move either, and a moving mesh behind every screen costs a frame each
 * time it moves (the old 90 ms step made every open application redraw at
 * 11-12 fps; eos-frametime on #88).
 *
 * Motion, from dconf /org/asteroidos/settings/flatmesh-motion (read live; a
 * QML "motion" binding overrides it):
 *   "static" (default, also unset or unknown)  never moves
 *   "input"   glides after input on its window (touch, crown/wheel, key, the
 *             window or the item showing up) for flatmesh-idle-timeout
 *             seconds (default 3), slows down over the last 0.6 s and stops
 *   "always"  the stock behaviour: moves for as long as it is visible
 * In both moving modes it moves at the display rate (a QAbstractAnimation:
 * Qt Quick's animation driver advances it once per frame, in step with the
 * vsync), not in 90 ms steps, and only while somebody can see it: the item
 * visible, its window shown and exposed. "animated: false" keeps it still
 * whatever the setting.
 *   /org/asteroidos/settings/flatmesh-idle-timeout       seconds, applications
 *   /org/asteroidos/settings/flatmesh-idle-timeout-home  the launcher (the
 *       compositor process); unset = same as the applications key
 * Logging category: asteroid.flatmesh (debug: every start/stop).
 */
class FlatMesh : public QQuickItem
{
    Q_OBJECT
    QML_NAMED_ELEMENT(FlatMesh)
    Q_PROPERTY(QColor centerColor WRITE setCenterColor READ getCenterColor)
    Q_PROPERTY(QColor outerColor WRITE setOuterColor READ getOuterColor)
    Q_PROPERTY(bool animated WRITE setAnimated READ getAnimated NOTIFY animatedChanged)
    Q_PROPERTY(QString motion READ motion WRITE setMotion RESET resetMotion NOTIFY motionChanged)
    Q_PROPERTY(int idleTimeout READ idleTimeout WRITE setIdleTimeout RESET resetIdleTimeout NOTIFY idleTimeoutChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)

public:
    enum Motion { Static, AfterInput, Always };

    FlatMesh(QQuickItem *parent = 0);
    ~FlatMesh() override;

    bool getAnimated() const { return m_animated; }
    void setAnimated(bool animated);

    QColor getCenterColor() const { return m_centerColor; }
    void setCenterColor(QColor c);

    QColor getOuterColor() const { return m_outerColor; }
    void setOuterColor(QColor c);

    /* "static", "input" or "always": the effective mode */
    QString motion() const;
    /* an empty string goes back to the system setting */
    void setMotion(const QString &motion);
    void resetMotion() { setMotion(QString()); }

    /* Effective glide time after input in ms ("input" mode) */
    int idleTimeout() const;
    /* ms; a negative value goes back to the system setting */
    void setIdleTimeout(int ms);
    void resetIdleTimeout() { setIdleTimeout(-1); }

    /* Whether the mesh is moving right now */
    bool isRunning() const;

    /* Counts as user activity: an "input" mesh glides for another idleTimeout */
    Q_INVOKABLE void wake();

    /* Called by the animation once per frame with its running time in ms */
    void advance(int ms);

signals:
    void animatedChanged();
    void motionChanged();
    void idleTimeoutChanged();
    void runningChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *node, UpdatePaintNodeData *data) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    bool eventFilter(QObject *watched, QEvent *event) override;

private slots:
    void maybeEnableAnimation();
    void onVisibleChanged();
    void reloadSettings();

private:
    void watchWindow(QQuickWindow *window);
    void noteActivity();
    bool windowShowing() const;
    Motion effectiveMotion() const;

    QColor m_centerColor, m_outerColor;
    bool m_animated;
    bool m_colorsDirty;
    float m_animationState;
    int m_loopCount;
    float m_screenScaleFactor;
    int m_idleTimeoutOverride;   /* ms, < 0: use the system setting */
    int m_systemIdleTimeout;     /* ms, from dconf */
    int m_motionOverride;        /* Motion, < 0: use the system setting */
    Motion m_systemMotion;
    QElapsedTimer m_lastActivity;
    int m_lastAdvance;           /* animation time of the previous frame */
    float m_speed;               /* 0..1 of full speed, eased in and out */
    QPointer<QQuickWindow> m_window;
    FlatMeshAnimation *m_animation;
};

#endif // FLATMESH_H
