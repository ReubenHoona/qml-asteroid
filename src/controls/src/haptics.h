/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef HAPTICS_H
#define HAPTICS_H

#include <QObject>
#include <QElapsedTimer>
#include <QtQml/qqmlregistration.h>

class MDConfItem;
class QQmlEngine;
class QJSEngine;

/*
 * Haptics: short system haptic effects for user interface feedback, the way
 * Wear OS gives a tick per crown detent, a click on a confirmed action and a
 * bump when a list reaches its end.
 *
 *   import org.asteroid.controls
 *   onClicked: Haptics.click()
 *
 * Every effect is an ngfd event ("ui_tick", "ui_click", "ui_limit",
 * "ui_confirm", "ui_long_press", see ui-feedback.ini) played with a
 * fire-and-forget D-Bus call, so a QML handler never waits for the vibrator.
 * Nothing plays while vibration is off (/desktop/asteroid/vibration, the
 * quick panel toggle) or user interface haptics are off
 * (/org/asteroidos/ux/haptics). Ticks closer than 25 ms are merged.
 */
class Haptics : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Haptics)
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)

public:
    static Haptics *instance();
    static Haptics *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool enabled() const;

    /*! A detent: crown rotation, a picker value or a list item passing. */
    Q_INVOKABLE void tick();
    /*! A tap on a button or toggle that changed something. */
    Q_INVOKABLE void click();
    /*! A list or picker reached its end. */
    Q_INVOKABLE void limit();
    /*! An action completed (sent, saved, dismissed). */
    Q_INVOKABLE void confirm();
    /*! A long press was recognised. */
    Q_INVOKABLE void longPress();
    /*! Any ngfd event by name. */
    Q_INVOKABLE void play(const QString &event);

signals:
    void enabledChanged();

private:
    explicit Haptics(QObject *parent = nullptr);

    MDConfItem *m_vibration;
    MDConfItem *m_ui;
    QElapsedTimer m_lastTick;
    QElapsedTimer m_lastLimit;
};

#endif // HAPTICS_H
