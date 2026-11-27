/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef LOCALEFOLLOWER_H
#define LOCALEFOLLOWER_H

#include <QDBusConnection>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class QCoreApplication;

/*
 * An app follows a language change while it runs, as stock Android recreates every activity on a
 * configuration change (setup LocaleController:197, Settings LocaleSettingsFragment): Settings >
 * Language, setup and the phone's language set the system locale through systemd-localed
 * (org.freedesktop.locale1 SetLocale, which writes /etc/locale.conf), and the launcher retranslates
 * itself (lipstick LocaleManager::selectLocale). localed announces the new Locale with
 * org.freedesktop.DBus.Properties.PropertiesChanged on the system bus; the follower takes its LANG and
 * makes it the app's language: the default QLocale, LANG in the environment, the app's catalogues
 * installed again (AsteroidApp::installTranslators) and every QML engine of the app's windows
 * retranslated (each qsTr / qsTrId binding is evaluated again).
 * Battery: one D-Bus match rule; nothing runs until the language changes.
 */
class LocaleFollower : public QObject
{
    Q_OBJECT

public:
    LocaleFollower(QCoreApplication *app, const QString &name, const QString &directory,
                   QObject *parent = nullptr);

    /* Listens to localed's announcements on bus; false when the bus is not there */
    bool watch(const QDBusConnection &bus);
    /* The LANG of a localed Locale list ("LANG=de_DE.utf8", "LC_TIME=..."); "" when it names none */
    static QString langOf(const QStringList &locale);
    /* The app's language: LANG when it started, then the last one applied */
    QString language() const { return m_lang; }
    /* Makes lang the app's language; false when it is empty or already the one in use */
    bool apply(const QString &lang);

signals:
    void languageChanged(const QString &lang);

public slots:
    /* org.freedesktop.DBus.Properties.PropertiesChanged of /org/freedesktop/locale1 */
    void propertiesChanged(const QString &interface, const QVariantMap &changed,
                           const QStringList &invalidated);

private:
    void fetch();

    QCoreApplication *m_app;
    QString m_name;
    QString m_dir;
    QString m_lang;
    QDBusConnection m_bus;
};

#endif // LOCALEFOLLOWER_H
