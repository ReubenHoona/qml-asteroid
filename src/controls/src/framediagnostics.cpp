/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "framediagnostics.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QFileInfo>
#include <QHash>
#include <QLoggingCategory>
#include <QMutex>
#include <QPointer>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>

#include <private/qquickitem_p.h>
#include <private/qquickwindow_p.h>
#include <private/qqmldata_p.h>

Q_STATIC_LOGGING_CATEGORY(lcFrames, "asteroid.frames", QtWarningMsg)

static const int MAX_NAMED = 10;

namespace {
/* Per window. The timestamps come from the GUI thread (afterAnimating) and
 * the render thread (the rest); in the threaded render loop the GUI thread
 * is blocked while the render thread syncs, so the hand-over is ordered. */
struct WindowFrames : public QObject {
    QPointer<QQuickWindow> window;
    QElapsedTimer clock;
    QMutex lock;
    qint64 animated = -1;     /* end of the animation step (GUI thread) */
    qint64 syncStart = -1;
    qint64 syncEnd = -1;
    qint64 lastSwap = -1;
    quint64 frames = 0;
    QString dirty;
    int dirtyCount = 0;
};
}

static QString describe(QQuickItem *item)
{
    QString s = QString::fromLatin1(item->metaObject()->className());
    const int q = s.indexOf(QLatin1String("_QMLTYPE_"));
    if (q > 0)
        s.truncate(q);
    if (QQmlContext *ctx = qmlContext(item)) {
        const QString id = ctx->nameForObject(item);
        if (!id.isEmpty())
            s += QLatin1Char('#') + id;
        const QString file = QFileInfo(ctx->baseUrl().path()).fileName();
        if (!file.isEmpty()) {
            s += QLatin1Char('@') + file;
            if (QQmlData *ddata = QQmlData::get(item, false))
                s += QLatin1Char(':') + QString::number(ddata->lineNumber);
        }
    }
    if (!item->objectName().isEmpty())
        s += QLatin1String("(\"") + item->objectName() + QLatin1String("\")");
    if (!item->isVisible())
        s += QLatin1String("{hidden}");
    return s;
}

/* Runs before the scene graph copies the dirty items: the list is intact */
static void collectDirty(WindowFrames *f)
{
    QQuickWindow *w = f->window;
    if (!w)
        return;
    QQuickWindowPrivate *wd = QQuickWindowPrivate::get(w);
    QString out;
    int n = 0;
    for (QQuickItem *item = wd->dirtyItemList; item; item = QQuickItemPrivate::get(item)->nextDirtyItem) {
        if (n < MAX_NAMED) {
            QQuickItemPrivate *d = QQuickItemPrivate::get(item);
            out += QLatin1Char(' ') + describe(item) + QLatin1String(" [")
                    + d->dirtyToString().trimmed() + QLatin1Char(']');
        }
        n++;
    }
    if (n > MAX_NAMED)
        out += QStringLiteral(" ... +%1").arg(n - MAX_NAMED);
    f->dirty = out;
    f->dirtyCount = n;
}

static void hook(QQuickWindow *window)
{
    static QHash<QQuickWindow *, WindowFrames *> hooked;
    if (hooked.contains(window))
        return;
    WindowFrames *f = new WindowFrames;
    f->window = window;
    f->setParent(window);
    f->clock.start();
    hooked.insert(window, f);
    QObject::connect(window, &QObject::destroyed, [window]() { hooked.remove(window); });

    QObject::connect(window, &QQuickWindow::afterAnimating, f, [f]() {
        QMutexLocker l(&f->lock);
        f->animated = f->clock.elapsed();
    }, Qt::DirectConnection);
    QObject::connect(window, &QQuickWindow::beforeSynchronizing, f, [f]() {
        QMutexLocker l(&f->lock);
        f->syncStart = f->clock.elapsed();
        collectDirty(f);
    }, Qt::DirectConnection);
    QObject::connect(window, &QQuickWindow::afterSynchronizing, f, [f]() {
        QMutexLocker l(&f->lock);
        f->syncEnd = f->clock.elapsed();
    }, Qt::DirectConnection);
    QObject::connect(window, &QQuickWindow::frameSwapped, f, [f]() {
        QMutexLocker l(&f->lock);
        const qint64 now = f->clock.elapsed();
        const qint64 interval = f->lastSwap >= 0 ? now - f->lastSwap : 0;
        const qint64 gui = f->animated >= 0 && f->syncStart >= f->animated ? f->syncStart - f->animated : -1;
        const qint64 sync = f->syncEnd >= f->syncStart && f->syncStart >= 0 ? f->syncEnd - f->syncStart : -1;
        const qint64 render = f->syncEnd >= 0 ? now - f->syncEnd : -1;
        f->frames++;
        qCDebug(lcFrames).noquote() << QStringLiteral("frame %1 +%2 gui %3 sync %4 render %5 dirty %6:%7")
                                       .arg(f->frames).arg(interval).arg(gui).arg(sync).arg(render)
                                       .arg(f->dirtyCount).arg(f->dirtyCount ? f->dirty
                                                                               : QStringLiteral(" (animation or update())"));
        f->lastSwap = now;
        f->animated = f->syncStart = f->syncEnd = -1;
        f->dirty.clear();
        f->dirtyCount = 0;
    }, Qt::DirectConnection);
    qCDebug(lcFrames) << "watching" << window;
}

void FrameDiagnostics::install()
{
    static FrameDiagnostics *s = nullptr;
    if (s || !qApp || !lcFrames().isDebugEnabled())
        return;
    s = new FrameDiagnostics(qApp);
    qApp->installEventFilter(s);
    for (QWindow *w : QGuiApplication::topLevelWindows())
        if (QQuickWindow *qw = qobject_cast<QQuickWindow *>(w))
            hook(qw);
}

FrameDiagnostics::FrameDiagnostics(QObject *parent) : QObject(parent)
{
}

bool FrameDiagnostics::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::Show || event->type() == QEvent::Expose) {
        if (QQuickWindow *w = qobject_cast<QQuickWindow *>(watched))
            hook(w);
    }
    return QObject::eventFilter(watched, event);
}
