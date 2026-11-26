#include "mdconfitem.h"

#include <QHash>
#include <QList>

namespace {
QHash<QString, QVariant> &store()
{
    static QHash<QString, QVariant> s;
    return s;
}
QList<MDConfItem *> &items()
{
    static QList<MDConfItem *> l;
    return l;
}
}

MDConfItem::MDConfItem(const QString &key, QObject *parent) : QObject(parent), m_key(key)
{
    items().append(this);
}

MDConfItem::~MDConfItem()
{
    items().removeAll(this);
}

QVariant MDConfItem::value() const
{
    return store().value(m_key);
}

QVariant MDConfItem::value(const QVariant &def) const
{
    const QVariant v = value();
    return v.isValid() ? v : def;
}

void MDConfItem::set(const QVariant &value)
{
    setTestValue(m_key, value);
}

void MDConfItem::setTestValue(const QString &key, const QVariant &value)
{
    if (value.isValid())
        store().insert(key, value);
    else
        store().remove(key);
    const QList<MDConfItem *> all = items();
    for (MDConfItem *item : all) {
        if (item->m_key == key)
            emit item->valueChanged();
    }
}

int MDConfItem::instances(const QString &key)
{
    int n = 0;
    for (const MDConfItem *item : items())
        n += item->m_key == key;
    return n;
}
