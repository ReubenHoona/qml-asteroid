/*
 * Host test of DateFormat's ranges (src/utils/src/dateformat.{h,cpp}): formatRange shows the wall times Qt
 * shows for the same QDateTimes, whatever TZ says: a zone name (UTC, a tzdata name, Etc/GMT-n) or a
 * hand-written POSIX TZ string, with or without DST rules, a DST change inside the range included; a range
 * of one instant reads as format() of it. The zone names of the POSIX strings are invented. TZ is set per
 * row (and tzset() called) before the QDateTimes are made, as local times, as QML hands them over.
 */
#include <QtTest>
#include <QDateTime>
#include <QTimeZone>

#include <time.h>

#include "dateformat.h"

class TestDateFormat : public QObject
{
    Q_OBJECT

private:
    QByteArray m_oldTz;
    bool m_hadTz = false;

    static void setZone(const QByteArray &tz)
    {
        qputenv("TZ", tz);
        tzset();
    }
    // ICU's narrow and thin spaces as plain ones: the texts below do not depend on the ICU version's spaces
    static QString plain(QString s)
    {
        s.replace(QChar(0x202F), QLatin1Char(' ')).replace(QChar(0x2009), QLatin1Char(' ')).replace(QChar(0x00A0), QLatin1Char(' '));
        return s;
    }
    // a UTC instant as a local time of the zone set now
    static QDateTime local(const QString &utc)
    {
        return QDateTime::fromString(utc + QLatin1Char('Z'), Qt::ISODate).toLocalTime();
    }

    static void rangeRows()
    {
        QTest::addColumn<QByteArray>("tz");
        QTest::addColumn<QString>("from");
        QTest::addColumn<QString>("to");
        QTest::addColumn<QString>("skeleton");
        QTest::addColumn<QString>("expected");

        // named zones
        QTest::newRow("UTC") << QByteArray("UTC") << "2026-03-10T14:30:00" << "2026-03-10T15:30:00" << "hm" << "2:30 – 3:30 PM";
        QTest::newRow("Etc/GMT-3") << QByteArray("Etc/GMT-3") << "2026-03-10T09:00:00" << "2026-03-10T10:00:00" << "hm" << "12:00 – 1:00 PM";
        QTest::newRow("CET winter") << QByteArray("CET") << "2026-01-15T11:00:00" << "2026-01-15T12:00:00" << "hm" << "12:00 – 1:00 PM";
        QTest::newRow("CET summer") << QByteArray("CET") << "2026-07-15T10:00:00" << "2026-07-15T11:00:00" << "Hm" << "12:00 – 13:00";
        QTest::newRow("CET DST starts") << QByteArray("CET") << "2026-03-29T00:30:00" << "2026-03-29T01:30:00" << "Hm" << "01:30 – 03:30";
        // POSIX strings without DST
        QTest::newRow("XYZ-12") << QByteArray("XYZ-12") << "2026-03-10T02:30:00" << "2026-03-10T03:30:00" << "hm" << "2:30 – 3:30 PM";
        QTest::newRow("XYZ-12 24 h") << QByteArray("XYZ-12") << "2026-03-10T02:30:00" << "2026-03-10T03:30:00" << "Hm" << "14:30 – 15:30";
        QTest::newRow("XYZ-12 next day") << QByteArray("XYZ-12") << "2026-03-10T13:00:00" << "2026-03-10T14:00:00" << "MMMd" << "Mar 11";
        QTest::newRow("PQW+7") << QByteArray("PQW+7") << "2026-06-01T20:15:00" << "2026-06-01T21:45:00" << "hm" << "1:15 – 2:45 PM";
        QTest::newRow("HHO-5:30") << QByteArray("HHO-5:30") << "2026-05-01T06:00:00" << "2026-05-01T07:00:00" << "hm" << "11:30 AM – 12:30 PM";
        QTest::newRow("<+0545>-5:45") << QByteArray("<+0545>-5:45") << "2026-05-01T06:15:00" << "2026-05-01T06:45:00" << "Hm" << "12:00 – 12:30";
        // POSIX strings with DST rules
        QTest::newRow("ABC+5DEF winter") << QByteArray("ABC+5DEF,M3.2.0,M11.1.0") << "2026-01-15T17:00:00" << "2026-01-15T18:00:00" << "hm" << "12:00 – 1:00 PM";
        QTest::newRow("ABC+5DEF summer") << QByteArray("ABC+5DEF,M3.2.0,M11.1.0") << "2026-07-15T16:00:00" << "2026-07-15T17:00:00" << "hm" << "12:00 – 1:00 PM";
        QTest::newRow("ABC+5DEF DST starts") << QByteArray("ABC+5DEF,M3.2.0,M11.1.0") << "2026-03-08T06:30:00" << "2026-03-08T07:30:00" << "hm" << "1:30 – 3:30 AM";
        QTest::newRow("ABC+5DEF DST ends") << QByteArray("ABC+5DEF,M3.2.0,M11.1.0") << "2026-11-01T05:30:00" << "2026-11-01T07:30:00" << "Hm" << "01:30 – 02:30";
        QTest::newRow("QRS-10TUV summer") << QByteArray("QRS-10TUV,M10.1.0,M4.1.0/3") << "2026-01-20T01:00:00" << "2026-01-20T02:00:00" << "hm" << "12:00 – 1:00 PM";
        QTest::newRow("QRS-10TUV winter") << QByteArray("QRS-10TUV,M10.1.0,M4.1.0/3") << "2026-07-20T02:00:00" << "2026-07-20T03:00:00" << "hm" << "12:00 – 1:00 PM";
        QTest::newRow("JKL-1MNO-2 summer") << QByteArray("JKL-1MNO-2,M3.5.0,M10.5.0/3") << "2026-07-15T10:00:00" << "2026-07-15T11:00:00" << "Hm" << "12:00 – 13:00";
    }

private slots:
    void initTestCase()
    {
        m_hadTz = qEnvironmentVariableIsSet("TZ");
        m_oldTz = qgetenv("TZ");
    }
    void cleanupTestCase()
    {
        if (m_hadTz)
            setZone(m_oldTz);
        else {
            qunsetenv("TZ");
            tzset();
        }
    }

    void formatRange_data() { rangeRows(); }
    void formatRange()
    {
        QFETCH(QByteArray, tz);
        QFETCH(QString, from);
        QFETCH(QString, to);
        QFETCH(QString, skeleton);
        QFETCH(QString, expected);
        setZone(tz);
        DateFormat df;
        QCOMPARE(plain(df.formatRange(local(from), local(to), skeleton, QStringLiteral("en_US"))), expected);
    }

    // a zone field: ICU's name of a named zone, the true offset of a POSIX string (ICU has no zone by its name)
    void zoneField_data()
    {
        QTest::addColumn<QByteArray>("tz");
        QTest::addColumn<QString>("from");
        QTest::addColumn<QString>("to");
        QTest::addColumn<QString>("expected");
        QTest::newRow("UTC") << QByteArray("UTC") << "2026-03-10T14:30:00" << "2026-03-10T15:30:00" << "14:30 – 15:30 UTC";
        QTest::newRow("XYZ-12") << QByteArray("XYZ-12") << "2026-03-10T02:30:00" << "2026-03-10T03:30:00" << "14:30 – 15:30 GMT+12";
        QTest::newRow("HHO-5:30") << QByteArray("HHO-5:30") << "2026-05-01T06:00:00" << "2026-05-01T07:00:00" << "11:30 – 12:30 GMT+5:30";
        QTest::newRow("ABC+5DEF summer") << QByteArray("ABC+5DEF,M3.2.0,M11.1.0") << "2026-07-15T16:00:00" << "2026-07-15T17:00:00" << "12:00 – 13:00 GMT-4";
    }
    void zoneField()
    {
        QFETCH(QByteArray, tz);
        QFETCH(QString, from);
        QFETCH(QString, to);
        QFETCH(QString, expected);
        setZone(tz);
        DateFormat df;
        QCOMPARE(plain(df.formatRange(local(from), local(to), QStringLiteral("Hmz"), QStringLiteral("en_US"))), expected);
    }

    // a range of one instant is that time: the range and format() (Qt's own formatting) agree
    void singleInstant_data() { rangeRows(); }
    void singleInstant()
    {
        QFETCH(QByteArray, tz);
        QFETCH(QString, from);
        QFETCH(QString, to);
        QFETCH(QString, skeleton);
        setZone(tz);
        DateFormat df;
        const QString l = QStringLiteral("en_US");
        for (const QString &t : { from, to }) {
            const QDateTime d = local(t);
            QCOMPARE(plain(df.formatRange(d, d, skeleton, l)), plain(df.format(d, skeleton, l)));
        }
    }
};

QTEST_GUILESS_MAIN(TestDateFormat)
#include "tst_dateformat.moc"
