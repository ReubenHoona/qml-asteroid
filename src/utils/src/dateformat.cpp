/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include "dateformat.h"

#include <QLocale>
#include <QTimeZone>

#include <unicode/udat.h>
#include <unicode/udateintervalformat.h>
#include <unicode/udatpg.h>
#include <unicode/ustring.h>

DateFormat::DateFormat(QObject *parent) : QObject(parent)
{
}

QObject *DateFormat::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    return new DateFormat;
}

QByteArray DateFormat::icuLocale(const QString &locale)
{
    QString name = locale.isEmpty() ? QLocale().name() : QLocale(locale).name();
    // Qt's "C" locale: ICU's English
    if (name == QLatin1String("C") || name.isEmpty())
        name = QStringLiteral("en_US");
    return name.toLatin1();
}

QString DateFormat::icuPattern(const QString &skeleton, const QString &locale) const
{
    const QByteArray loc = icuLocale(locale);
    const QString key = QString::fromLatin1(loc) + QChar(0x1f) + skeleton;
    auto it = m_cache.constFind(key);
    if (it != m_cache.constEnd())
        return it.value();

    UErrorCode status = U_ZERO_ERROR;
    UDateTimePatternGenerator *gen = udatpg_open(loc.constData(), &status);
    QString result;
    if (U_SUCCESS(status)) {
        UChar buf[128];
        const int32_t len = udatpg_getBestPattern(gen, reinterpret_cast<const UChar *>(skeleton.utf16()),
                                                  skeleton.length(), buf, 128, &status);
        if (U_SUCCESS(status))
            result = QString(reinterpret_cast<const QChar *>(buf), len);
    }
    if (gen)
        udatpg_close(gen);
    // no ICU data: the skeleton itself is a usable pattern
    if (result.isEmpty())
        result = skeleton;
    m_cache.insert(key, result);
    return result;
}

static bool isPatternLetter(QChar c)
{
    return (c >= QLatin1Char('a') && c <= QLatin1Char('z')) || (c >= QLatin1Char('A') && c <= QLatin1Char('Z'));
}

static bool isSpace(QChar c)
{
    return c.isSpace() || c == QChar(0x202F) || c == QChar(0x00A0) || c == QChar(0x2009);
}

static QString trimSpaces(const QString &s)
{
    int b = 0, e = s.length();
    while (b < e && isSpace(s.at(b)))
        b++;
    while (e > b && isSpace(s.at(e - 1)))
        e--;
    return s.mid(b, e - b);
}

QString DateFormat::toQtPattern(const QString &icu)
{
    QString out;
    const int n = icu.length();
    int i = 0;
    while (i < n) {
        const QChar c = icu.at(i);
        if (c == QLatin1Char('\'')) {
            // quoted text (and '' for a quote) means the same in Qt
            int j = i + 1;
            while (j < n) {
                if (icu.at(j) == QLatin1Char('\'')) {
                    if (j + 1 < n && icu.at(j + 1) == QLatin1Char('\'')) {
                        j += 2;
                        continue;
                    }
                    break;
                }
                j++;
            }
            out += icu.mid(i, qMin(j + 1, n) - i);
            i = j + 1;
            continue;
        }
        if (!isPatternLetter(c)) {
            out += c;
            i++;
            continue;
        }
        int count = 1;
        while (i + count < n && icu.at(i + count) == c)
            count++;
        i += count;
        switch (c.unicode()) {
        case 'y': case 'u': case 'Y':
            out += count == 2 ? QStringLiteral("yy") : QStringLiteral("yyyy");
            break;
        case 'M': case 'L':
            // MMMMM (narrow) has no Qt field: abbreviated
            out += QString(count >= 4 ? (count == 4 ? 4 : 3) : count, QLatin1Char('M'));
            break;
        case 'd':
            out += QString(qMin(count, 2), QLatin1Char('d'));
            break;
        case 'E': case 'c': case 'e':
            if ((c == QLatin1Char('e') || c == QLatin1Char('c')) && count <= 2)
                break; // numeric day of week: Qt has none
            out += count == 4 ? QStringLiteral("dddd") : QStringLiteral("ddd");
            break;
        case 'h': case 'K':
            out += QString(qMin(count, 2), QLatin1Char('h'));
            break;
        case 'H': case 'k':
            out += QString(qMin(count, 2), QLatin1Char('H'));
            break;
        case 'm':
            out += QString(qMin(count, 2), QLatin1Char('m'));
            break;
        case 's':
            out += QString(qMin(count, 2), QLatin1Char('s'));
            break;
        case 'S':
            out += count >= 3 ? QStringLiteral("zzz") : QStringLiteral("z");
            break;
        case 'a': case 'b': case 'B':
            // the locale's own AM/PM text, case unchanged (Qt 6.3+)
            out += QStringLiteral("Ap");
            break;
        case 'z': case 'Z': case 'v': case 'V': case 'O': case 'X': case 'x':
            out += QLatin1Char('t');
            break;
        default:
            break; // era, week, quarter...: no Qt field
        }
    }
    return trimSpaces(out);
}

QString DateFormat::stripMarker(const QString &icu)
{
    QString out;
    bool quoted = false;
    for (QChar c : icu) {
        if (c == QLatin1Char('\''))
            quoted = !quoted;
        if (!quoted && (c == QLatin1Char('a') || c == QLatin1Char('b') || c == QLatin1Char('B')))
            continue;
        out += c;
    }
    return trimSpaces(out);
}

QString DateFormat::bestPattern(const QString &skeleton, const QString &locale) const
{
    return toQtPattern(icuPattern(skeleton, locale));
}

QString DateFormat::format(const QDateTime &dateTime, const QString &skeleton, const QString &locale) const
{
    const QLocale l = locale.isEmpty() ? QLocale() : QLocale(locale);
    return l.toString(dateTime, bestPattern(skeleton, locale));
}

QString DateFormat::clockPattern(bool use24h, const QString &locale) const
{
    // TimeTextKt.java:91: getBestDateTimePattern(locale, "HH:mm" | "h:mm"),
    // "a" removed, trimmed
    return toQtPattern(stripMarker(icuPattern(use24h ? QStringLiteral("HH:mm") : QStringLiteral("h:mm"), locale)));
}

QString DateFormat::timePattern(bool use24h, const QString &locale) const
{
    // DateFormat.getTimeFormat: the locale's "hm" / "Hm"
    return bestPattern(use24h ? QStringLiteral("Hm") : QStringLiteral("hm"), locale);
}

QString DateFormat::hourPattern(bool use24h, const QString &locale) const
{
    // skeleton "j" with the 12/24 hour setting applied
    return bestPattern(use24h ? QStringLiteral("H") : QStringLiteral("ha"), locale);
}

bool DateFormat::markerFirst(const QString &locale) const
{
    const QString p = icuPattern(QStringLiteral("hm"), locale);
    const int a = p.indexOf(QLatin1Char('a'));
    const int h = p.indexOf(QLatin1Char('h'));
    return a >= 0 && h >= 0 && a < h;
}

QString DateFormat::formatRange(const QDateTime &from, const QDateTime &to, const QString &skeleton, const QString &locale) const
{
    const QByteArray loc = icuLocale(locale);
    // the zone Qt formats in, so a range and a single time agree
    const QString tz = QString::fromLatin1(QTimeZone::systemTimeZoneId());
    UErrorCode status = U_ZERO_ERROR;
    UDateIntervalFormat *f = udtitvfmt_open(loc.constData(),
                                            reinterpret_cast<const UChar *>(skeleton.utf16()), skeleton.length(),
                                            tz.isEmpty() ? nullptr : reinterpret_cast<const UChar *>(tz.utf16()),
                                            tz.isEmpty() ? 0 : tz.length(), &status);
    QString result;
    if (U_SUCCESS(status)) {
        UChar buf[256];
        const int32_t len = udtitvfmt_format(f, double(from.toMSecsSinceEpoch()), double(to.toMSecsSinceEpoch()),
                                             buf, 256, nullptr, &status);
        if (U_SUCCESS(status))
            result = QString(reinterpret_cast<const QChar *>(buf), len);
    }
    if (f)
        udtitvfmt_close(f);
    if (result.isEmpty()) {
        const QLocale l = locale.isEmpty() ? QLocale() : QLocale(locale);
        const QString p = bestPattern(skeleton, locale);
        result = l.toString(from, p) + QStringLiteral(" – ") + l.toString(to, p);
    }
    return result;
}
