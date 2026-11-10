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
 * Haptics: the Pixel Watch 2's user interface haptics, one method per stock
 * HapticFeedbackConstants id (Wear OS CP3A, AndroidOverlayHapticsWeakActuator
 * haptic_feedback_customization.xml over the framework table; stock
 * OVERLAYS.md:154-348, HapticFeedbackVibrationProvider.java:40-87):
 *
 *   method            ngfd event            stock constant          pattern
 *   longPress()       ui_long_press         LONG_PRESS              thud 1.0
 *   virtualKey()      ui_virtual_key        VIRTUAL_KEY             click 1.0
 *   keyboardTap()     ui_key_tap            KEYBOARD_TAP            click 0.5
 *   keyboardRelease() ui_key_release        KEYBOARD_RELEASE        click 0.5
 *   contextClick()    ui_context_click      CONTEXT_CLICK           click 0.5
 *   gestureEnd()      ui_gesture_end        GESTURE_END             click 1.0
 *   confirm()         ui_confirm            CONFIRM                 thud, thud +116 ms
 *   reject()          ui_reject             REJECT                  thud x3, 116 ms apart
 *   toggleOn()        ui_toggle_on          TOGGLE_ON               click, click +51 ms
 *   toggleOff()       ui_toggle_off         TOGGLE_OFF              click, click +51 ms
 *   gestureThreshold() ui_gesture_threshold GESTURE_THRESHOLD_ACTIVATE click 1.0
 *   segmentTick()     ui_segment_tick       SEGMENT_FREQUENT_TICK   tick 1.0
 *   scrollTick()      ui_scroll_tick        SCROLL_TICK             tick 1.0   (crown)
 *   scrollFocus()     ui_scroll_focus       SCROLL_ITEM_FOCUS       click 0.5  (crown)
 *   scrollLimit()     ui_scroll_limit       SCROLL_LIMIT            click 1.0  (crown)
 *
 * The patterns live in ngfd's events.d/ui-feedback.ini (meta-eos64,
 * W1-engine-haptics), played by the CS40L26 wavetable; this class only
 * names them. Every effect is a fire-and-forget D-Bus call, so a QML handler
 * never waits for the vibrator.
 *
 *   import org.asteroid.controls
 *   onClicked: Haptics.virtualKey()
 *
 * Two classes, as stock (scroll ids are USAGE_HARDWARE_FEEDBACK, the rest
 * USAGE_TOUCH): nothing plays while vibration is off
 * (/desktop/asteroid/vibration); touch effects also need Settings >
 * Vibration > Touch feedback (/org/asteroidos/ux/haptics, default true);
 * crown effects (scroll*, and the older tick() and limit()) need Settings >
 * Vibration > Using crown (/org/asteroidos/ux/haptics-crown, default false:
 * the user's choice 1, stock's value is on).
 *
 * click(), tick(), limit(), toggle() and select() are the older names, kept
 * until their callers move: click = virtualKey, tick = ui_tick (crown),
 * limit = ui_limit (crown, at most one per 400 ms), toggle(on) =
 * toggleOn/toggleOff, select = contextClick.
 */
class Haptics : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Haptics)
    QML_SINGLETON

    /* touch feedback plays (vibration and Touch feedback on) */
    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    /* crown feedback plays (vibration and Using crown on) */
    Q_PROPERTY(bool crownEnabled READ crownEnabled NOTIFY enabledChanged)

public:
    enum Class { Touch, Crown };
    Q_ENUM(Class)

    static Haptics *instance();
    static Haptics *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool enabled() const;
    bool crownEnabled() const;

    /* stock constants (see the table above) */
    Q_INVOKABLE void longPress();
    Q_INVOKABLE void virtualKey();
    Q_INVOKABLE void keyboardTap();
    Q_INVOKABLE void keyboardRelease();
    Q_INVOKABLE void contextClick();
    Q_INVOKABLE void gestureEnd();
    Q_INVOKABLE void confirm();
    Q_INVOKABLE void reject();
    Q_INVOKABLE void toggleOn();
    Q_INVOKABLE void toggleOff();
    Q_INVOKABLE void gestureThreshold();
    Q_INVOKABLE void segmentTick();
    Q_INVOKABLE void scrollTick();
    Q_INVOKABLE void scrollFocus();
    Q_INVOKABLE void scrollLimit();

    /* older names */
    Q_INVOKABLE void click();
    Q_INVOKABLE void tick();
    Q_INVOKABLE void limit();
    Q_INVOKABLE void toggle(bool on = true);
    Q_INVOKABLE void select();

    /*! Any ngfd event by name, in the touch class. */
    Q_INVOKABLE void play(const QString &event);
    /*! Any ngfd event by name in a class (Haptics.Touch or Haptics.Crown). */
    Q_INVOKABLE void playAs(const QString &event, int hapticClass);

signals:
    void enabledChanged();
    /* an event passed the switches and was sent to ngfd (tests, previews) */
    void played(const QString &event);

private:
    explicit Haptics(QObject *parent = nullptr);

    MDConfItem *m_vibration;
    MDConfItem *m_ui;
    MDConfItem *m_crown;
    QElapsedTimer m_lastTick;
    QElapsedTimer m_lastLimit;
};

#endif // HAPTICS_H
