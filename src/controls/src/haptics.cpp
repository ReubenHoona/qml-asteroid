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

static const char KEY_VIBRATION[] = "/desktop/asteroid/vibration";
/* Settings > Vibration > Interactive haptics > Touch feedback */
static const char KEY_TOUCH[] = "/org/asteroidos/ux/haptics";
/* Settings > Vibration > Interactive haptics > Using crown (choice 1) */
static const char KEY_CROWN[] = "/org/asteroidos/ux/haptics-crown";

/* The older tick(): two ticks closer than this are merged. scrollTick()
 * is not merged (stock HapticScrollFeedbackProvider plays every one). */
static const qint64 MIN_TICK_INTERVAL_MS = 25;
/* The older limit(): one bump per push. scrollLimit() is armed per edge by
 * its caller instead (RotaryInput). */
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
    m_vibration(new MDConfItem(QLatin1String(KEY_VIBRATION), this)),
    m_ui(new MDConfItem(QLatin1String(KEY_TOUCH), this)),
    m_crown(new MDConfItem(QLatin1String(KEY_CROWN), this))
{
    for (MDConfItem *item : {m_vibration, m_ui, m_crown})
        connect(item, &MDConfItem::valueChanged, this, &Haptics::enabledChanged);
}

bool Haptics::enabled() const
{
    return m_vibration->value(true).toBool() && m_ui->value(true).toBool();
}

bool Haptics::crownEnabled() const
{
    return m_vibration->value(true).toBool() && m_crown->value(false).toBool();
}

void Haptics::playAs(const QString &event, int hapticClass)
{
    if (event.isEmpty())
        return;
    if (!(hapticClass == Crown ? crownEnabled() : enabled()))
        return;
    emit played(event);
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

void Haptics::play(const QString &event)
{
    playAs(event, Touch);
}

void Haptics::longPress() { playAs(QStringLiteral("ui_long_press"), Touch); }
void Haptics::virtualKey() { playAs(QStringLiteral("ui_virtual_key"), Touch); }
void Haptics::keyboardTap() { playAs(QStringLiteral("ui_key_tap"), Touch); }
void Haptics::keyboardRelease() { playAs(QStringLiteral("ui_key_release"), Touch); }
void Haptics::contextClick() { playAs(QStringLiteral("ui_context_click"), Touch); }
void Haptics::gestureEnd() { playAs(QStringLiteral("ui_gesture_end"), Touch); }
void Haptics::confirm() { playAs(QStringLiteral("ui_confirm"), Touch); }
void Haptics::reject() { playAs(QStringLiteral("ui_reject"), Touch); }
void Haptics::toggleOn() { playAs(QStringLiteral("ui_toggle_on"), Touch); }
void Haptics::toggleOff() { playAs(QStringLiteral("ui_toggle_off"), Touch); }
void Haptics::gestureThreshold() { playAs(QStringLiteral("ui_gesture_threshold"), Touch); }
void Haptics::segmentTick() { playAs(QStringLiteral("ui_segment_tick"), Touch); }
void Haptics::scrollTick() { playAs(QStringLiteral("ui_scroll_tick"), Crown); }
void Haptics::scrollFocus() { playAs(QStringLiteral("ui_scroll_focus"), Crown); }
void Haptics::scrollLimit() { playAs(QStringLiteral("ui_scroll_limit"), Crown); }

void Haptics::click()
{
    playAs(QStringLiteral("ui_click"), Touch);
}

void Haptics::tick()
{
    if (!crownEnabled())
        return;
    if (m_lastTick.isValid() && m_lastTick.elapsed() < MIN_TICK_INTERVAL_MS)
        return;
    m_lastTick.start();
    playAs(QStringLiteral("ui_tick"), Crown);
}

void Haptics::limit()
{
    if (!crownEnabled())
        return;
    if (m_lastLimit.isValid() && m_lastLimit.elapsed() < MIN_LIMIT_INTERVAL_MS)
        return;
    m_lastLimit.start();
    playAs(QStringLiteral("ui_limit"), Crown);
}

void Haptics::toggle(bool on)
{
    if (on)
        toggleOn();
    else
        toggleOff();
}

void Haptics::select()
{
    contextClick();
}
