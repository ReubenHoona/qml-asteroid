/*
 * Copyright (C) 2017 Florent Revest <revestflo@gmail.com>
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

#include "icon.h"

#include <QPainter>
#include <QIcon>
#include <QSvgRenderer>
#include <QFile>
#include <QQuickWindow>
#include <QGuiApplication>
#include <private/qquickitem_p.h>

#define ICONS_DIRECTORY "/usr/share/icons/asteroid/"

Icon::Icon()
{
    setFlag(ItemHasContents, true);
    m_color = Qt::white;
}

static qreal effectiveDpr(QQuickItem *item)
{
    if (item->window())
        return item->window()->effectiveDevicePixelRatio();
    return qGuiApp ? qGuiApp->devicePixelRatio() : 1.0;
}

void Icon::updateBasePixmap()
{
    const qreal dpr = effectiveDpr(this);
    const QSize pixelSize(qRound(width()  * dpr),
                          qRound(height() * dpr));

    m_pixmap = QPixmap(pixelSize);
    m_pixmap.setDevicePixelRatio(dpr);

    setTextureSize(pixelSize);
}

void Icon::updatePixmapContent()
{
    if(m_pixmap.isNull())
        return;

    m_pixmap.fill(Qt::transparent);

    if(!QFile::exists(ICONS_DIRECTORY + m_name + ".svg"))
        return;

    QPainter painter(&m_pixmap);
    painter.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);

    QSvgRenderer svgRenderer(ICONS_DIRECTORY + m_name + ".svg");
    svgRenderer.render(&painter, QRectF(0, 0, width(), height()));
}

void Icon::updatePixmapColor()
{
    if(m_pixmap.isNull())
        return;

    QPainter painter(&m_pixmap);
    painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    painter.fillRect(QRect(0, 0, width(), height()), m_color);
}

void Icon::paint(QPainter *painter)
{
    if(m_pixmap.isNull())
        return;
    // read the layout now: a mirror that changed since the last paint shows
    const bool mirror = m_autoMirror && isDirectional(m_name)
            && QQuickItemPrivate::get(this)->effectiveLayoutMirror;
    if (mirror) {
        painter->save();
        painter->translate(width(), 0);
        painter->scale(-1, 1);
    }
    painter->drawPixmap(0, 0, width(), height(), m_pixmap);
    if (mirror)
        painter->restore();
}

/*
 * The pictures that point somewhere: the arrows and chevrons, send, return,
 * undo and redo, exit, log in and out, backspace (stock's autoMirrored vector
 * drawables). Not mirrored: media transport (play, skip, rewind, fast
 * forward: the transport keeps its left-to-right order in every language),
 * clocks, trending arrows and the "round" up and down arrows.
 */
bool Icon::isDirectional(const QString &name)
{
    static const char *const names[] = {
        "ios-arrow-back", "ios-arrow-forward", "ios-arrow-round-back", "ios-arrow-round-forward",
        "ios-arrow-dropleft", "ios-arrow-dropleft-circle", "ios-arrow-dropright", "ios-arrow-dropright-circle",
        "ios-return-left", "ios-return-right", "ios-send", "ios-send-outline",
        "ios-undo", "ios-undo-outline", "ios-redo", "ios-redo-outline",
        "ios-exit", "ios-exit-outline", "ios-log-in", "ios-log-out",
        "ios-backspace", "ios-backspace-outline",
    };
    for (const char *n : names) {
        if (name == QLatin1String(n))
            return true;
    }
    return false;
}

bool Icon::autoMirror() const
{
    return m_autoMirror;
}

void Icon::setAutoMirror(bool on)
{
    if (m_autoMirror == on)
        return;
    m_autoMirror = on;
    emit autoMirrorChanged();
    refreshMirroring();
}

bool Icon::mirrored() const
{
    return m_mirrored;
}

void Icon::refreshMirroring()
{
    const bool now = m_autoMirror && isDirectional(m_name)
            && QQuickItemPrivate::get(this)->effectiveLayoutMirror;
    if (now == m_mirrored)
        return;
    m_mirrored = now;
    update();
    emit mirroredChanged();
}

void Icon::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickPaintedItem::itemChange(change, value);
    // the parents decide the layout direction: look when this icon is placed
    if (change == ItemParentHasChanged || change == ItemSceneChange)
        refreshMirroring();
}


void Icon::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    if(newGeometry.size() == oldGeometry.size() || newGeometry.width() == 0 || newGeometry.height() == 0)
        return;
    updateBasePixmap();
    updatePixmapContent();
    updatePixmapColor();
    update();
}

QString Icon::name()
{
    return m_name;
}

void Icon::setName(QString name)
{
    if(m_name == name)
        return;

    m_name = name;

    updatePixmapContent();
    updatePixmapColor();
    update();
    emit nameChanged();
    refreshMirroring();
}

QColor Icon::color()
{
    return m_color;
}

void Icon::setColor(QColor color)
{
    if(m_color == color)
        return;

    m_color = color;

    updatePixmapColor();
    update();
    emit colorChanged();
}
