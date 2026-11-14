/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef PALETTE_H
#define PALETTE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

/*
 * PaletteGenerator: the "Color theme" of Wear OS (Settings > Display > Color
 * theme). Theme.qml calls generate() when the setting or the watch face's
 * colours change, never on a tick, and writes the 29 roles it returns to
 * Theme.color. The maths is palette_core.h (HCT, the five Wear schemes).
 *
 *   generate("#9A9EAD", "", Neutral)   the 29 roles as "#RRGGBB" (this call
 *                                      with Moonstone is stock's "No theme"
 *                                      table exactly); {} for a bad seed
 *   hct("#RRGGBB")                     {hue, chroma, tone}
 *   fromHct(hue, chroma, tone)         "#RRGGBB" (in gamut)
 */
class PaletteGenerator : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(PaletteGenerator)
    QML_SINGLETON

    /* the 29 role names in the order of Theme.color */
    Q_PROPERTY(QStringList roleNames READ roleNames CONSTANT)
    /* how many palettes have been generated in this process (diagnostic) */
    Q_PROPERTY(int generated READ generated NOTIFY generatedChanged)

public:
    /* the stock theme_style values (WearColorScheme: 0, 1, 2, 3 and 6) */
    enum Style { Neutral = 0, TonalSpot = 1, Vibrant = 2, Expressive = 3, Content = 6 };
    Q_ENUM(Style)

    explicit PaletteGenerator(QObject *parent = nullptr);

    QStringList roleNames() const;
    int generated() const { return m_generated; }

    Q_INVOKABLE QVariantMap generate(const QString &seed, const QString &accent, int style);
    Q_INVOKABLE QVariantMap hct(const QString &color) const;
    Q_INVOKABLE QString fromHct(double hue, double chroma, double tone) const;

signals:
    void generatedChanged();

private:
    int m_generated = 0;
};

#endif
