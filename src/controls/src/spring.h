/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef SPRING_H
#define SPRING_H

#include <QAbstractAnimation>
#include <QObject>
#include <QPointer>
#include <QQmlParserStatus>
#include <QtQml/qqmlregistration.h>

class MDConfItem;

/*
 * The physics of Wear OS motion (Wear Compose Material 3, CP3A): every
 * transition is a damped spring of mass 1,
 *
 *   x'' = -k (x - target) - 2 z sqrt(k) x'
 *
 * with stiffness k and damping ratio z (androidx compose animation-core
 * SpringSimulation, solved in closed form, so a frame that comes late lands
 * where it should).
 */
namespace SpringMath {
/* State after t seconds of a spring released at displacement x0 (from its
 * target) with velocity v0 (units/s): displacement *x and velocity *v */
void step(qreal stiffness, qreal dampingRatio, qreal x0, qreal v0, qreal t, qreal *x, qreal *v);
/* Seconds until the displacement stays within fraction (0.01 = 99 %) of a
 * unit step released at rest */
qreal settleTime(qreal stiffness, qreal dampingRatio, qreal fraction = 0.01);
}

/*
 * Android's fling: OverScroller's spline decay with the CP3A values
 * (config_scrollFriction 0.015, 160 dpi physical coefficient, inflexion
 * 0.35, deceleration rate ln(0.78) / ln(0.9)), the curve Compose's
 * SplineBasedFloatDecayAnimationSpec uses as well.
 */
namespace FlingSpline {
/* ppi = px per dp x 160 (320 on the Pixel Watch 2) */
qreal distance(qreal velocity, qreal ppi, qreal friction = 0.015);
/* ms */
qreal duration(qreal velocity, qreal ppi, qreal friction = 0.015);
/* fraction of the distance covered at fraction t of the duration */
qreal position(qreal t);
/* d position / d t at fraction t (for the velocity left when a fling hits
 * the end of a list) */
qreal velocityCoefficient(qreal t);
}

/*
 * Accessibility > Reduce animations (/org/asteroidos/a11y/reduce-motion,
 * stock reduce_motion): springs land at once, list edges stop scaling.
 */
class ReduceMotion : public QObject
{
    Q_OBJECT
public:
    static ReduceMotion *instance();
    bool enabled() const { return m_enabled; }
    /* tests and the settings page preview */
    void setOverride(int value);   /* -1: follow the key, 0 off, 1 on */

signals:
    void changed();

private:
    explicit ReduceMotion(QObject *parent = nullptr);
    void update();
    MDConfItem *m_item = nullptr;
    int m_override = -1;
    bool m_enabled = false;
};

/*
 * WearSpring: a velocity-aware spring animation.
 *
 *   // follows "to": every change animates from where it is now, keeping
 *   // its speed (a Behavior that does not stop dead when retargeted)
 *   WearSpring {
 *       target: button; property: "radius"
 *       to: button.pressed ? Theme.shape.small : button.height / 2
 *       stiffness: button.pressed ? 12600 : 260
 *   }
 *
 *   // driven from a gesture: start where the finger left it, at its speed
 *   WearSpring { id: settle; stiffness: 1500 }   // read settle.value
 *   settle.animateTo(1, flingVelocity)
 *
 * Without a target, "value" is the output. A finished spring stops its frame
 * driver (no timer runs while it rests), and Reduce animations makes it jump
 * to the end. stopAtFraction 0.98 ends it once 98 % of the way is covered,
 * as the window transitions of Wear OS do (TransitionAnimationController).
 */
class WearSpring : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    QML_NAMED_ELEMENT(WearSpring)

    Q_PROPERTY(QObject *target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(QString property READ property WRITE setProperty NOTIFY propertyChanged)
    Q_PROPERTY(qreal to READ to WRITE setTo NOTIFY toChanged)
    Q_PROPERTY(qreal value READ value NOTIFY valueChanged)
    Q_PROPERTY(qreal velocity READ velocity NOTIFY valueChanged)
    Q_PROPERTY(qreal stiffness READ stiffness WRITE setStiffness NOTIFY specChanged)
    Q_PROPERTY(qreal dampingRatio READ dampingRatio WRITE setDampingRatio NOTIFY specChanged)
    Q_PROPERTY(qreal visibilityThreshold READ visibilityThreshold WRITE setVisibilityThreshold NOTIFY specChanged)
    Q_PROPERTY(qreal stopAtFraction READ stopAtFraction WRITE setStopAtFraction NOTIFY specChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(bool reduceMotion READ reduceMotion NOTIFY reduceMotionChanged)

public:
    explicit WearSpring(QObject *parent = nullptr);
    ~WearSpring() override;

    QObject *target() const { return m_target; }
    void setTarget(QObject *t);
    QString property() const { return m_property; }
    void setProperty(const QString &p);
    qreal to() const { return m_to; }
    void setTo(qreal to);
    qreal value() const { return m_value; }
    qreal velocity() const { return m_velocity; }
    qreal stiffness() const { return m_stiffness; }
    void setStiffness(qreal k);
    qreal dampingRatio() const { return m_damping; }
    void setDampingRatio(qreal z);
    qreal visibilityThreshold() const { return m_threshold; }
    void setVisibilityThreshold(qreal t);
    qreal stopAtFraction() const { return m_stopAt; }
    void setStopAtFraction(qreal f);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool e);
    bool running() const;
    bool reduceMotion() const;

    /* Animate to "to" from the current value; velocity in units/s (NaN or
     * left out: keep the current velocity) */
    Q_INVOKABLE void animateTo(qreal to, qreal velocity = qQNaN());
    /* Jump: value = to = v, at rest */
    Q_INVOKABLE void snapTo(qreal v);
    Q_INVOKABLE void stop();
    /* The closed form, for tests and for animations that sample it
     * themselves: displacement from "to" after ms milliseconds */
    Q_INVOKABLE qreal sample(qreal stiffness, qreal dampingRatio, qreal from, qreal to,
                             qreal velocity, qreal ms) const;
    Q_INVOKABLE qreal settleMs(qreal stiffness, qreal dampingRatio, qreal fraction = 0.01) const;

    void classBegin() override {}
    void componentComplete() override;

    /* frame driver callback */
    void advance(int ms);

signals:
    void targetChanged();
    void propertyChanged();
    void toChanged();
    void valueChanged();
    void specChanged();
    void enabledChanged();
    void runningChanged();
    void reduceMotionChanged();
    /* the spring came to rest at "to" (not after stop()) */
    void finished();

private:
    void start(qreal velocity);
    void setValueInternal(qreal v, qreal velocity);
    void write();
    qreal readTarget(bool *ok) const;

    QPointer<QObject> m_target;
    QString m_property;
    QAbstractAnimation *m_driver = nullptr;
    qreal m_to = 0;
    qreal m_value = 0;
    qreal m_velocity = 0;
    qreal m_stiffness = 1500;   /* Spring.StiffnessMedium, androidx spring() */
    qreal m_damping = 1;        /* Spring.DampingRatioNoBouncy */
    qreal m_threshold = 0.01;   /* androidx visibility threshold of a Float */
    qreal m_stopAt = 1;
    bool m_enabled = true;
    bool m_complete = false;
    bool m_toSet = false;
    bool m_writing = false;
    /* segment start: displacement and velocity at m_startMs */
    qreal m_x0 = 0;
    qreal m_v0 = 0;
    qreal m_span = 0;
    int m_lastMs = 0;
};

#endif // SPRING_H
