/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#ifndef DATEFORMAT_H
#define DATEFORMAT_H

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QString>

class QQmlEngine;
class QJSEngine;

/*
 * DateFormat: locale date and time patterns from skeletons, as stock Wear OS
 * gets them (android.text.format.DateFormat.getBestDateTimePattern and
 * DateUtils.formatDateRange, both ICU). The ICU pattern is turned into a Qt
 * format string, so QML formats with Date.toLocaleString(locale, pattern).
 *
 *   DateFormat.bestPattern("MMMd")          // "d MMM" (en_GB), "MMM d" (en_US)
 *   DateFormat.format(new Date(), "EEEMMMd")
 *   DateFormat.formatRange(a, b, "hm")      // "2:30 - 3:30 pm"
 *
 * Nothing here runs on its own (no timer): patterns are made on request and
 * cached per locale and skeleton.
 */
class DateFormat : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY(DateFormat)
public:
    explicit DateFormat(QObject *parent = nullptr);
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    /* the ICU best pattern for a skeleton ("hm" -> "h:mm a") */
    Q_INVOKABLE QString icuPattern(const QString &skeleton, const QString &locale = QString()) const;
    /* the same, as a Qt format string ("h:mm Ap") */
    Q_INVOKABLE QString bestPattern(const QString &skeleton, const QString &locale = QString()) const;
    /* a date formatted with the best pattern for a skeleton */
    Q_INVOKABLE QString format(const QDateTime &dateTime, const QString &skeleton, const QString &locale = QString()) const;
    /* a range, as DateUtils.formatDateRange (ICU DateIntervalFormat) */
    Q_INVOKABLE QString formatRange(const QDateTime &from, const QDateTime &to, const QString &skeleton, const QString &locale = QString()) const;

    /* the four time patterns of the 12/24 hour setting, Qt format strings */
    /* A, clock: best "h:mm" / "HH:mm" with the marker removed (M3 TimeText) */
    Q_INVOKABLE QString clockPattern(bool use24h, const QString &locale = QString()) const;
    /* B, time with marker: best "hm" / "Hm" (DateFormat.getTimeFormat) */
    Q_INVOKABLE QString timePattern(bool use24h, const QString &locale = QString()) const;
    /* C, hour labels: best "ha" / "H" (skeleton "j" with the setting applied) */
    Q_INVOKABLE QString hourPattern(bool use24h, const QString &locale = QString()) const;
    /* true when the locale puts the day period before the time ("a h:mm") */
    Q_INVOKABLE bool markerFirst(const QString &locale = QString()) const;

    /* ICU locale id for a Qt locale name ("" = the default locale) */
    static QByteArray icuLocale(const QString &locale);
    /* ICU pattern letters -> Qt format letters; quoted text is kept */
    static QString toQtPattern(const QString &icu);
    /* drops the day period field ('a', 'b', 'B') and trims, as M3 TimeText */
    static QString stripMarker(const QString &icu);

private:
    mutable QHash<QString, QString> m_cache;
};

#endif // DATEFORMAT_H
