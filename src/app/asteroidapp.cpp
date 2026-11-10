/*
 * Copyright (C) 2017 - Florent Revest <revestflo@gmail.com>
 * Copyright (C) 2013 - 2014 Jolla Ltd.
 * Contact: Thomas Perl <thomas.perl@jollamobile.com>
 * All rights reserved.
 *
 * This file is part of qml-asteroid
 *
 * You may use this file under the terms of the GNU Lesser General
 * Public License version 2.1 as published by the Free Software Foundation
 * and appearing in the file license.lgpl included in the packaging
 * of this file.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License version 2.1 as published by the Free Software Foundation
 * and appearing in the file license.lgpl included in the packaging
 * of this file.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 */

#include "asteroidapp.h"

#include <MDeclarativeCache>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQuickView>
#include <QScreen>
#include <QSettings>
#include <QTranslator>
#include <QUrl>

static QString applicationPath()
{
    QString argv0 = QCoreApplication::arguments()[0];

    if (argv0.startsWith("/")) {
        // First, try argv[0] if it's an absolute path (needed for booster)
        return argv0;
    } else {
        // If that doesn't give an absolute path, use /proc-based detection
        return QCoreApplication::applicationFilePath();
    }
}

namespace AsteroidApp {
    QString appName()
    {
        QFileInfo exe = QFileInfo(applicationPath());
        return exe.baseName();
    }

    int installTranslators(QCoreApplication *app, const QString &name, const QString &directory)
    {
        int installed = 0;
        // English first: Qt searches the most recently installed catalog
        // first, so the locale's catalog below wins wherever it has the id
        // (as LocaleManager does for the launcher). Stock apps show complete
        // text in every language; an untranslated id falls back to English.
        QTranslator *fallback = new QTranslator(app);
        if (fallback->load(name + QStringLiteral(".en"), directory)) {
            app->installTranslator(fallback);
            installed++;
        } else {
            delete fallback;
        }

        QTranslator *translator = new QTranslator(app);
        if (translator->load(QLocale(), name, QStringLiteral("."), directory, QStringLiteral(".qm"))) {
            app->installTranslator(translator);
            installed++;
        } else {
            qDebug() << "Failed to load" << QLocale().name() << "translations for" << name;
            delete translator;
        }
        return installed;
    }

    QGuiApplication *application(int &argc, char **argv)
    {
        static QGuiApplication *app = NULL;

        if (app == NULL) {
            app = MDeclarativeCache::qApplication(argc, argv);

            app->setOrganizationName(appName());
            app->setOrganizationDomain(appName());
            app->setApplicationName(appName());

            installTranslators(app, appName(), QStringLiteral("/usr/share/translations"));
        } else {
            qWarning("AsteroidApp::application() called multiple times");
        }

        return app;
    }

    QQuickView *createView()
    {
        QQuickView *view = MDeclarativeCache::qQuickView();
        QString path = "/usr/share/applications/" + appName() + ".desktop";
        QSettings applicationSettings(path, QSettings::IniFormat);
        auto applicationName = applicationSettings.value("Desktop Entry/Name");
        view->setTitle(applicationName.toString());

        QObject::connect(view->engine(), &QQmlEngine::quit,
                         qApp, &QGuiApplication::quit);

        return view;
    }

    int main(int &argc, char **argv)
    {
        QScopedPointer<QGuiApplication> app(AsteroidApp::application(argc, argv));
        QScopedPointer<QQuickView> view(AsteroidApp::createView());

        QString uri = appName();
        if (uri.startsWith(QStringLiteral("asteroid-")))
            uri = uri.mid(qstrlen("asteroid-"));
        if (!uri.isEmpty())
            uri[0] = uri[0].toUpper();

        const QString cachegenPath = QStringLiteral(":/") + uri + QStringLiteral("/main.qml");
        if (QFile::exists(cachegenPath))
            view->setSource(QUrl(QStringLiteral("qrc") + cachegenPath));
        else
            view->setSource(QUrl(QStringLiteral("qrc:/main.qml")));

        view->resize(app->primaryScreen()->size());
        view->show();
        return app->exec();
    }
};
