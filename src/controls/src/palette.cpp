/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "palette.h"
#include "palette_core.h"

PaletteGenerator::PaletteGenerator(QObject *parent)
    : QObject(parent)
{
}

QStringList PaletteGenerator::roleNames() const
{
    QStringList names;
    for (const char *const *n = eosmonet::roleNames(); *n; n++)
        names << QString::fromLatin1(*n);
    return names;
}

QVariantMap PaletteGenerator::generate(const QString &seed, const QString &accent, int style)
{
    uint32_t s = eosmonet::parseHex(seed.toStdString());
    if (!s)
        return QVariantMap();
    uint32_t a = eosmonet::parseHex(accent.toStdString());
    switch (style) {
    case Neutral:
    case TonalSpot:
    case Vibrant:
    case Expressive:
    case Content:
        break;
    default:
        style = Content; /* a style stock does not know, like a face colour with no preset */
    }
    auto roles = eosmonet::roles(eosmonet::makeScheme(s, a, style));
    QVariantMap out;
    const char *const *names = eosmonet::roleNames();
    for (int i = 0; names[i]; i++)
        out.insert(QString::fromLatin1(names[i]), QString::fromStdString(eosmonet::hex(roles[size_t(i)])));
    m_generated++;
    emit generatedChanged();
    return out;
}

QVariantMap PaletteGenerator::hct(const QString &color) const
{
    uint32_t c = eosmonet::parseHex(color.toStdString());
    if (!c)
        return QVariantMap();
    eosmonet::Hct h = eosmonet::hctFromArgb(c);
    QVariantMap m;
    m.insert(QStringLiteral("hue"), h.hue);
    m.insert(QStringLiteral("chroma"), h.chroma);
    m.insert(QStringLiteral("tone"), h.tone);
    return m;
}

QString PaletteGenerator::fromHct(double hue, double chroma, double tone) const
{
    return QString::fromStdString(eosmonet::hex(eosmonet::hctSolve(hue, chroma, tone)));
}
