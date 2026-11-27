/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * R5 C-03: AsteroidApp's catalogues (installTranslators) and the language follower (LocaleFollower), on
 * invented catalogues (the .ts files of tests/asteroidapp/i18n, made into TST_I18N_DIR by xbuild-ctests.sh): a new
 * language replaces the app's catalogues, and a running app's QML text follows the Locale localed
 * announces, as the launcher does. No bus is needed: localed's signal is handed to the slot.
 */

#include <QtTest>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickView>

#include "asteroidapp.h"
#include "localefollower.h"

#ifndef TST_I18N_DIR
#define TST_I18N_DIR "i18n"
#endif

class TstAsteroidApp : public QObject
{
    Q_OBJECT

    QString dir() const { return QStringLiteral(TST_I18N_DIR); }
    static QString hello() { return qtTrId("id-tst-hello"); }

private slots:
    void initTestCase()
    {
        qputenv("LANG", "en_GB.utf8");
        QLocale::setDefault(QLocale(QStringLiteral("en_GB")));
        QVERIFY2(QFile::exists(dir() + QStringLiteral("/tst-app.en.qm")), qPrintable(dir()));
    }

    void langOf()
    {
        QCOMPARE(LocaleFollower::langOf({ QStringLiteral("LANG=fr_FR.utf8") }), QStringLiteral("fr_FR.utf8"));
        QCOMPARE(LocaleFollower::langOf({ QStringLiteral("LC_TIME=en_GB.utf8"), QStringLiteral("LANG=de_DE.utf8") }),
                 QStringLiteral("de_DE.utf8"));
        QCOMPARE(LocaleFollower::langOf({ QStringLiteral("LC_TIME=en_GB.utf8") }), QString());
        QCOMPARE(LocaleFollower::langOf({}), QString());
    }

    // a second call replaces the first one's catalogues (the old language's text does not stay)
    void installReplaces()
    {
        // en_GB: the English fallback, and the locale's search ends at tst-app.en (no en_GB catalogue)
        QCOMPARE(AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir()), 2);
        QCOMPARE(hello(), QStringLiteral("Hello"));
        QLocale::setDefault(QLocale(QStringLiteral("fr_FR")));
        QCOMPARE(AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir()), 2);
        QCOMPARE(hello(), QStringLiteral("Bonjour"));
        QCOMPARE(AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir()), 2);
        QCOMPARE(hello(), QStringLiteral("Bonjour"));
        QLocale::setDefault(QLocale(QStringLiteral("en_GB")));
        QCOMPARE(AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir()), 2);
        QCOMPARE(hello(), QStringLiteral("Hello"));
        // an id the language lacks falls back to English
        QLocale::setDefault(QLocale(QStringLiteral("fr_FR")));
        AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir());
        QCOMPARE(qtTrId("id-tst-only-english"), QStringLiteral("Only English"));
        QLocale::setDefault(QLocale(QStringLiteral("en_GB")));
        AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir());
    }

    // localed's Locale: the app's language, its catalogues and the QML of its window
    void followerApplies()
    {
        qputenv("LANG", "en_GB.utf8");
        QLocale::setDefault(QLocale(QStringLiteral("en_GB")));
        AsteroidApp::installTranslators(qApp, QStringLiteral("tst-app"), dir());
        LocaleFollower follower(qApp, QStringLiteral("tst-app"), dir());
        QCOMPARE(follower.language(), QStringLiteral("en_GB.utf8"));
        QSignalSpy changed(&follower, &LocaleFollower::languageChanged);

        QQuickView view;
        QQmlComponent c(view.engine());
        c.setData("import QtQuick\nText { text: qsTrId(\"id-tst-hello\") }", QUrl());
        QScopedPointer<QObject> text(c.create());
        QVERIFY2(text, qPrintable(c.errorString()));
        QCOMPARE(text->property("text").toString(), QStringLiteral("Hello"));

        // the signal of another interface, or of another property, changes nothing
        follower.propertiesChanged(QStringLiteral("org.freedesktop.timedate1"),
                                   { { QStringLiteral("Locale"), QStringList{ QStringLiteral("LANG=fr_FR.utf8") } } }, {});
        follower.propertiesChanged(QStringLiteral("org.freedesktop.locale1"),
                                   { { QStringLiteral("X11Layout"), QStringLiteral("us") } }, {});
        QCOMPARE(changed.count(), 0);
        QCOMPARE(text->property("text").toString(), QStringLiteral("Hello"));

        // localed: LANG=fr_FR.utf8
        follower.propertiesChanged(QStringLiteral("org.freedesktop.locale1"),
                                   { { QStringLiteral("Locale"), QStringList{ QStringLiteral("LANG=fr_FR.utf8") } } }, {});
        QCOMPARE(changed.count(), 1);
        QCOMPARE(changed.at(0).at(0).toString(), QStringLiteral("fr_FR.utf8"));
        QCOMPARE(follower.language(), QStringLiteral("fr_FR.utf8"));
        QCOMPARE(qgetenv("LANG"), QByteArray("fr_FR.utf8"));
        QCOMPARE(QLocale().name(), QStringLiteral("fr_FR"));
        QCOMPARE(text->property("text").toString(), QStringLiteral("Bonjour"));

        // the same again: nothing to do
        QVERIFY(!follower.apply(QStringLiteral("fr_FR.utf8")));
        QVERIFY(!follower.apply(QString()));
        QCOMPARE(changed.count(), 1);

        // and back to English
        QVERIFY(follower.apply(QStringLiteral("en_GB.utf8")));
        QCOMPARE(text->property("text").toString(), QStringLiteral("Hello"));
        QCOMPARE(QLocale().name(), QStringLiteral("en_GB"));
    }

    void noBus()
    {
        LocaleFollower follower(qApp, QStringLiteral("tst-app"), dir());
        QVERIFY(!follower.watch(QDBusConnection(QString())));
    }
};

QTEST_MAIN(TstAsteroidApp)
#include "tst_asteroidapp.moc"
