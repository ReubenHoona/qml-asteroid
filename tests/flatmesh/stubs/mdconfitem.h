/* In-memory stand-in for mlite6's MDConfItem (dconf), for the host tests: the values live in a process-wide
 * map, and set() / setTestValue() notify every item of that key like a dconf change does. */
#pragma once
#include <QObject>
#include <QString>
#include <QVariant>

class MDConfItem : public QObject
{
    Q_OBJECT
public:
    explicit MDConfItem(const QString &key, QObject *parent = nullptr);
    ~MDConfItem() override;

    QString key() const { return m_key; }
    QVariant value() const;
    QVariant value(const QVariant &def) const;
    void set(const QVariant &value);
    void unset() { set(QVariant()); }

    /* test helper: what another process writing to dconf looks like */
    static void setTestValue(const QString &key, const QVariant &value);
    static int instances(const QString &key);

signals:
    void valueChanged();

private:
    QString m_key;
};
