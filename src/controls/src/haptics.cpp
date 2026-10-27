/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "haptics.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QJSEngine>
#include <QLoggingCategory>
#include <QQmlEngine>
#include <QVariantMap>
#include <MDConfItem>

Q_STATIC_LOGGING_CATEGORY(lcHaptics, "asteroid.haptics", QtWarningMsg)

static const char NGF_SERVICE[] = "com.nokia.NonGraphicFeedback1.Backend";
static const char NGF_PATH[] = "/com/nokia/NonGraphicFeedback1";
static const char NGF_INTERFACE[] = "com.nokia.NonGraphicFeedback1";

/* Two ticks closer than this feel like one longer buzz on the cs40l26:
 * merge them. A fast crown spin then gives a steady 40/s at most. */
static const qint64 MIN_TICK_INTERVAL_MS = 25;
/* One end-of-list bump per push against the end, not one per wheel event */
static const qint64 MIN_LIMIT_INTERVAL_MS = 400;

Haptics *Haptics::instance()
{
    static Haptics *s = nullptr;
    if (!s)
        s = new Haptics(qApp);
    return s;
}

Haptics *Haptics::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    Haptics *h = instance();
    QJSEngine::setObjectOwnership(h, QJSEngine::CppOwnership);
    return h;
}

Haptics::Haptics(QObject *parent) : QObject(parent),
    m_vibration(new MDConfItem(QStringLiteral("/desktop/asteroid/vibration"), this)),
    m_ui(new MDConfItem(QStringLiteral("/org/asteroidos/ux/haptics"), this))
{
    connect(m_vibration, &MDConfItem::valueChanged, this, &Haptics::enabledChanged);
    connect(m_ui, &MDConfItem::valueChanged, this, &Haptics::enabledChanged);
}

bool Haptics::enabled() const
{
    return m_vibration->value(true).toBool() && m_ui->value(true).toBool();
}

void Haptics::play(const QString &event)
{
    if (event.isEmpty() || !enabled())
        return;
    QDBusMessage msg = QDBusMessage::createMethodCall(QLatin1String(NGF_SERVICE),
                                                      QLatin1String(NGF_PATH),
                                                      QLatin1String(NGF_INTERFACE),
                                                      QStringLiteral("Play"));
    /* A haptic only, whatever the event file says: ngfd's resource plugin
     * turns off every media.* resource the request does not name */
    QVariantMap props;
    props.insert(QStringLiteral("media.vibra"), true);
    msg << event << props;
    /* send(), not call(): the reply (an event id) is not needed and a busy
     * ngfd must never stall the user interface thread */
    if (!QDBusConnection::systemBus().send(msg))
        qCDebug(lcHaptics) << "could not send" << event;
    else
        qCDebug(lcHaptics) << "play" << event;
}

void Haptics::tick()
{
    if (m_lastTick.isValid() && m_lastTick.elapsed() < MIN_TICK_INTERVAL_MS)
        return;
    m_lastTick.start();
    play(QStringLiteral("ui_tick"));
}

void Haptics::click()
{
    play(QStringLiteral("ui_click"));
}

void Haptics::limit()
{
    if (m_lastLimit.isValid() && m_lastLimit.elapsed() < MIN_LIMIT_INTERVAL_MS)
        return;
    m_lastLimit.start();
    play(QStringLiteral("ui_limit"));
}

void Haptics::confirm()
{
    play(QStringLiteral("ui_confirm"));
}

void Haptics::longPress()
{
    play(QStringLiteral("ui_long_press"));
}
