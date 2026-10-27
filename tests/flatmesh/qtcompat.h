/* Forced include for the host test: Qt 6.9 macros that Debian's Qt 6.8 does not have yet */
#pragma once
#include <QtCore/qglobal.h>
#include <QtCore/qloggingcategory.h>
#ifndef Q_STATIC_LOGGING_CATEGORY
#define Q_STATIC_LOGGING_CATEGORY(name, ...) static Q_LOGGING_CATEGORY(name, __VA_ARGS__)
#endif
