/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "localefollower.h"
#include "asteroidapp.h"
#include "eoscatalogues.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QHash>
#include <QList>
#include <QLocale>
#include <QPointer>
#include <QQmlEngine>
#include <QQuickView>
#include <QSet>
#include <QTranslator>
#include <QWindow>

static const char LOCALE1_PATH[] = "/org/freedesktop/locale1";
static const char LOCALE1_SERVICE[] = "org.freedesktop.locale1";
static const char LOCALE1_INTERFACE[] = "org.freedesktop.locale1";
static const char PROPERTIES_INTERFACE[] = "org.freedesktop.DBus.Properties";

// The catalogues installTranslators() installed, by catalogue name: another call replaces them
static QHash<QString, QList<QPointer<QTranslator>>> &installedCatalogues()
{
    static QHash<QString, QList<QPointer<QTranslator>>> installed;
    return installed;
}

namespace AsteroidApp {
    int installTranslators(QCoreApplication *app, const QString &name, const QString &directory)
    {
        // a second call (a new language) takes the catalogues of the first one out
        QList<QPointer<QTranslator>> &mine = installedCatalogues()[name];
        for (const QPointer<QTranslator> &old : std::as_const(mine)) {
            if (old) {
                app->removeTranslator(old);
                delete old;
            }
        }
        mine.clear();

        int installed = 0;
        // English first: Qt searches the most recently installed catalog
        // first, so the locale's catalog below wins wherever it has the id
        // (as LocaleManager does for the launcher). Stock apps show complete
        // text in every language; an untranslated id falls back to English.
        QTranslator *fallback = new QTranslator(app);
        if (fallback->load(name + QStringLiteral(".en"), directory)) {
            app->installTranslator(fallback);
            mine.append(fallback);
            installed++;
        } else {
            delete fallback;
        }

        // the locale's: an English region of en_001 reads en_GB's, else QTranslator's own search, else the
        // language's other region (de_AT: de_DE), as every program of the image chooses (eoscatalogues.h)
        QTranslator *translator = new QTranslator(app);
        if (EosCatalogues::load(translator, name, directory, QLocale())) {
            app->installTranslator(translator);
            mine.append(translator);
            installed++;
        } else {
            qDebug() << "Failed to load" << QLocale().name() << "translations for" << name;
            delete translator;
        }
        return installed;
    }
}

LocaleFollower::LocaleFollower(QCoreApplication *app, const QString &name, const QString &directory,
                               QObject *parent)
    : QObject(parent), m_app(app), m_name(name), m_dir(directory),
      m_lang(qEnvironmentVariable("LANG")), m_bus(QString())
{
}

bool LocaleFollower::watch(const QDBusConnection &bus)
{
    if (!bus.isConnected())
        return false;
    m_bus = bus;
    // no sender in the match: only localed has this path, and a match on its bus-activated name
    // would have QtDBus follow its NameOwnerChanged every time localed starts and exits
    return m_bus.connect(QString(), QLatin1String(LOCALE1_PATH), QLatin1String(PROPERTIES_INTERFACE),
                         QStringLiteral("PropertiesChanged"), this,
                         SLOT(propertiesChanged(QString,QVariantMap,QStringList)));
}

QString LocaleFollower::langOf(const QStringList &locale)
{
    for (const QString &entry : locale) {
        if (entry.startsWith(QLatin1String("LANG=")))
            return entry.mid(5).trimmed();
    }
    return QString();
}

static QStringList stringList(const QVariant &v)
{
    if (v.canConvert<QDBusArgument>())
        return qdbus_cast<QStringList>(v.value<QDBusArgument>());
    if (v.canConvert<QDBusVariant>())
        return stringList(v.value<QDBusVariant>().variant());
    return v.toStringList();
}

void LocaleFollower::propertiesChanged(const QString &interface, const QVariantMap &changed,
                                       const QStringList &invalidated)
{
    if (interface != QLatin1String(LOCALE1_INTERFACE))
        return;
    const auto it = changed.constFind(QStringLiteral("Locale"));
    if (it != changed.constEnd()) {
        apply(langOf(stringList(it.value())));
        return;
    }
    // announced without its value: asked for once
    if (invalidated.contains(QStringLiteral("Locale")))
        fetch();
}

void LocaleFollower::fetch()
{
    if (!m_bus.isConnected())
        return;
    QDBusMessage get = QDBusMessage::createMethodCall(QLatin1String(LOCALE1_SERVICE), QLatin1String(LOCALE1_PATH),
                                                      QLatin1String(PROPERTIES_INTERFACE), QStringLiteral("Get"));
    get << QLatin1String(LOCALE1_INTERFACE) << QStringLiteral("Locale");
    QDBusPendingCallWatcher *w = new QDBusPendingCallWatcher(m_bus.asyncCall(get), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        QDBusPendingReply<QDBusVariant> reply = *call;
        if (!reply.isError())
            apply(langOf(stringList(reply.value().variant())));
        call->deleteLater();
    });
}

bool LocaleFollower::apply(const QString &lang)
{
    if (lang.isEmpty() || lang == m_lang)
        return false;
    m_lang = lang;
    // as the launcher's LocaleManager::selectLocale: the default locale and LANG, then the catalogues
    qputenv("LANG", lang.toUtf8());
    QLocale::setDefault(QLocale(lang));
    AsteroidApp::installTranslators(m_app, m_name, m_dir);

    // every QML engine of the app's windows: each qsTr / qsTrId binding evaluated again
    QSet<QQmlEngine *> engines;
    if (qobject_cast<QGuiApplication *>(QCoreApplication::instance())) {
        const QList<QWindow *> windows = QGuiApplication::allWindows();
        for (QWindow *w : windows) {
            if (QQuickView *view = qobject_cast<QQuickView *>(w))
                engines.insert(view->engine());
            else if (QQmlEngine *e = qmlEngine(w))
                engines.insert(e);
        }
    }
    for (QQmlEngine *e : std::as_const(engines)) {
        if (e)
            e->retranslate();
    }
    emit languageChanged(lang);
    return true;
}
