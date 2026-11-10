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

#ifndef ASTEROIDAPP_H
#define ASTEROIDAPP_H

#include <QtGlobal>

class QCoreApplication;
class QGuiApplication;
class QQuickView;
class QString;

#if defined(ASTEROIDAPP_LIBRARY)
#  define ASTEROIDAPP_EXPORT Q_DECL_EXPORT
#else
#  define ASTEROIDAPP_EXPORT Q_DECL_IMPORT
#endif

namespace AsteroidApp {
    // Simple interface: Get boosted application and view
    ASTEROIDAPP_EXPORT QGuiApplication *application(int &argc, char **argv);
    ASTEROIDAPP_EXPORT QQuickView *createView();

    // Installs the English catalog <name>.en.qm (the //% source texts) and
    // then the catalog of the current locale, so an id the locale has not
    // translated shows English instead of the raw id. Returns the number of
    // catalogs installed. application() calls it with the app's own name.
    ASTEROIDAPP_EXPORT int installTranslators(QCoreApplication *app, const QString &name,
                                              const QString &directory);

    // Very simple interface: Uses "qrc:/main.qml" as QML entry point
    ASTEROIDAPP_EXPORT int main(int &argc, char **argv);
};

Q_DECL_EXPORT int main(int argc, char *argv[]);

#endif /* ASTEROIDAPP_H */
