/*
 * Host test of FlatMesh's animation policy (qml-asteroid eos: "flatmesh: Stop animating when nobody can see it"):
 * it moves only while the item is visible, its window shown and exposed, and it is not idle; the optional idle
 * hold comes from dconf (seconds; -home for the launcher) or an idleTimeout binding (ms), and input on the window,
 * wake(), the item or window showing again resume it.
 * Runs on the offscreen platform (a compositor-like process: FlatMesh reads the -home key there too).
 */
#include <QtTest>
#include <QGuiApplication>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSignalSpy>

#include "flatmesh.h"
#include "mdconfitem.h"

static const char APPS_KEY[] = "/org/asteroidos/settings/flatmesh-idle-timeout";
static const char HOME_KEY[] = "/org/asteroidos/settings/flatmesh-idle-timeout-home";

class TestFlatMesh : public QObject
{
    Q_OBJECT

private:
    QQuickWindow *m_window = nullptr;
    FlatMesh *m_mesh = nullptr;

    void setSystem(const QVariant &apps, const QVariant &home)
    {
        MDConfItem::setTestValue(QLatin1String(APPS_KEY), apps);
        MDConfItem::setTestValue(QLatin1String(HOME_KEY), home);
    }
    void press()
    {
        QTest::mousePress(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(20, 20));
        QTest::mouseRelease(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(20, 20));
    }
    bool becomeIdle(int ms)
    {
        m_mesh->setIdleTimeout(ms);
        QElapsedTimer t;
        t.start();
        while (m_mesh->isRunning() && t.elapsed() < ms + 2000)
            QTest::qWait(20);
        return !m_mesh->isRunning();
    }

private slots:
    void init()
    {
        setSystem(QVariant(), QVariant());
        m_window = new QQuickWindow;
        m_window->resize(200, 200);
        m_mesh = new FlatMesh;
        m_mesh->setSize(QSizeF(200, 200));
        m_mesh->setParentItem(m_window->contentItem());
        m_window->show();
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
    }
    void cleanup()
    {
        delete m_mesh;
        m_mesh = nullptr;
        delete m_window;
        m_window = nullptr;
    }

    void defaultAlwaysAnimates()
    {
        QCOMPARE(m_mesh->idleTimeout(), 0);
        QVERIFY(m_mesh->getAnimated());
        QTRY_VERIFY(m_mesh->isRunning());
        QTest::qWait(400);   /* several 90 ms steps: no idle hold without a timeout */
        QVERIFY(m_mesh->isRunning());
    }

    void invisibleItemStops()
    {
        QTRY_VERIFY(m_mesh->isRunning());
        QSignalSpy running(m_mesh, &FlatMesh::runningChanged);
        m_mesh->setVisible(false);
        QVERIFY(!m_mesh->isRunning());
        QCOMPARE(running.count(), 1);
        m_mesh->setVisible(true);
        QVERIFY(m_mesh->isRunning());
        QCOMPARE(running.count(), 2);
    }

    void becomingVisibleCountsAsActivity()
    {
        QVERIFY(becomeIdle(300));
        m_mesh->setVisible(false);
        m_mesh->setVisible(true);
        QVERIFY(m_mesh->isRunning());
    }

    void hiddenWindowStops()
    {
        QTRY_VERIFY(m_mesh->isRunning());
        m_window->hide();
        QTRY_VERIFY(!m_mesh->isRunning());
        m_window->show();
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
        QTRY_VERIFY(m_mesh->isRunning());
    }

    void windowShownAgainResumesAnIdleMesh()
    {
        QVERIFY(becomeIdle(300));
        m_window->hide();
        m_window->show();
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
        QTRY_VERIFY(m_mesh->isRunning());
    }

    void animatedFalseStops()
    {
        QSignalSpy animated(m_mesh, &FlatMesh::animatedChanged);
        m_mesh->setAnimated(false);
        QVERIFY(!m_mesh->isRunning());
        m_mesh->setAnimated(false);   /* no change, no signal */
        QCOMPARE(animated.count(), 1);
        m_mesh->setAnimated(true);
        QVERIFY(m_mesh->isRunning());
        QCOMPARE(animated.count(), 2);
    }

    void idleHoldAndInputResumes()
    {
        QVERIFY(becomeIdle(300));
        press();
        QVERIFY(m_mesh->isRunning());
        /* and it holds again after another quiet period */
        QTRY_VERIFY_WITH_TIMEOUT(!m_mesh->isRunning(), 2300);
    }

    void hoverIsNotActivityButADragIs()
    {
        QVERIFY(becomeIdle(300));
        QMouseEvent hover(QEvent::MouseMove, QPointF(30, 30), QPointF(30, 30), Qt::NoButton, Qt::NoButton,
                          Qt::NoModifier);
        QCoreApplication::sendEvent(m_window, &hover);
        QVERIFY(!m_mesh->isRunning());
        QMouseEvent drag(QEvent::MouseMove, QPointF(40, 40), QPointF(40, 40), Qt::NoButton, Qt::LeftButton,
                         Qt::NoModifier);
        QCoreApplication::sendEvent(m_window, &drag);
        QVERIFY(m_mesh->isRunning());
    }

    void wheelKeyAndFocusResume_data()
    {
        QTest::addColumn<int>("kind");
        QTest::newRow("wheel") << 0;
        QTest::newRow("key") << 1;
        QTest::newRow("focus") << 2;
    }
    void wheelKeyAndFocusResume()
    {
        QFETCH(int, kind);
        QVERIFY(becomeIdle(300));
        if (kind == 0) {
            QWheelEvent wheel(QPointF(10, 10), QPointF(10, 10), QPoint(), QPoint(0, 120), Qt::NoButton,
                              Qt::NoModifier, Qt::NoScrollPhase, false);
            QCoreApplication::sendEvent(m_window, &wheel);
        } else if (kind == 1) {
            QKeyEvent key(QEvent::KeyPress, Qt::Key_Up, Qt::NoModifier);
            QCoreApplication::sendEvent(m_window, &key);
        } else {
            QFocusEvent focus(QEvent::FocusIn);
            QCoreApplication::sendEvent(m_window, &focus);
        }
        QVERIFY(m_mesh->isRunning());
    }

    void wakeResumes()
    {
        QVERIFY(becomeIdle(300));
        m_mesh->wake();
        QVERIFY(m_mesh->isRunning());
        m_mesh->wake();   /* not idle: nothing to do */
        QVERIFY(m_mesh->isRunning());
    }

    void systemTimeout_data()
    {
        QTest::addColumn<QVariant>("apps");
        QTest::addColumn<QVariant>("home");
        QTest::addColumn<int>("expectedMs");
        QTest::newRow("unset") << QVariant() << QVariant() << 0;
        QTest::newRow("apps seconds") << QVariant(10) << QVariant() << 10000;
        QTest::newRow("apps fraction") << QVariant(2.5) << QVariant() << 2500;
        QTest::newRow("apps string number") << QVariant(QStringLiteral("4")) << QVariant() << 4000;
        QTest::newRow("not a number") << QVariant(QStringLiteral("soon")) << QVariant() << 0;
        QTest::newRow("zero") << QVariant(0) << QVariant() << 0;
        QTest::newRow("negative") << QVariant(-5) << QVariant() << 0;
        QTest::newRow("below the minimum") << QVariant(0.1) << QVariant() << 500;
        QTest::newRow("above a day") << QVariant(1e9) << QVariant() << 86400000;
        QTest::newRow("home wins in the launcher") << QVariant(3) << QVariant(1) << 1000;
        QTest::newRow("home 0 keeps the launcher animating") << QVariant(3) << QVariant(0) << 0;
        QTest::newRow("home unset: apps") << QVariant(3) << QVariant() << 3000;
    }
    void systemTimeout()
    {
        QFETCH(QVariant, apps);
        QFETCH(QVariant, home);
        QFETCH(int, expectedMs);
        setSystem(apps, home);
        QCOMPARE(m_mesh->idleTimeout(), expectedMs);
        /* read live: a new mesh sees the same */
        FlatMesh other;
        QCOMPARE(other.idleTimeout(), expectedMs);
    }

    void liveChangeSignalsAndRestartsTheCountdown()
    {
        QSignalSpy changed(m_mesh, &FlatMesh::idleTimeoutChanged);
        setSystem(QVariant(0.5), QVariant());
        QCOMPARE(changed.count(), 1);
        QTRY_VERIFY_WITH_TIMEOUT(!m_mesh->isRunning(), 2500);
        /* the same value again: no signal; switching the hold off resumes the mesh */
        setSystem(QVariant(0.5), QVariant());
        QCOMPARE(changed.count(), 1);
        setSystem(QVariant(), QVariant());
        QCOMPARE(changed.count(), 2);
        QVERIFY(m_mesh->isRunning());
    }

    void overrideWinsAndResets()
    {
        setSystem(QVariant(2), QVariant());
        QSignalSpy changed(m_mesh, &FlatMesh::idleTimeoutChanged);
        m_mesh->setIdleTimeout(700);
        QCOMPARE(m_mesh->idleTimeout(), 700);
        QCOMPARE(changed.count(), 1);
        m_mesh->setIdleTimeout(700);
        QCOMPARE(changed.count(), 1);
        /* the system setting no longer matters while overridden */
        setSystem(QVariant(5), QVariant());
        QCOMPARE(m_mesh->idleTimeout(), 700);
        QCOMPARE(changed.count(), 1);
        m_mesh->resetIdleTimeout();
        QCOMPARE(m_mesh->idleTimeout(), 5000);
        QCOMPARE(changed.count(), 2);
        /* an override equal to the system value changes nothing visible */
        m_mesh->setIdleTimeout(5000);
        QCOMPARE(changed.count(), 2);
        m_mesh->setIdleTimeout(-42);
        QCOMPARE(m_mesh->idleTimeout(), 5000);
        /* 0 = never idle */
        m_mesh->setIdleTimeout(0);
        QCOMPARE(m_mesh->idleTimeout(), 0);
    }

    void movesToAnotherWindow()
    {
        QQuickWindow second;
        second.resize(100, 100);
        second.show();
        QVERIFY(QTest::qWaitForWindowExposed(&second));
        m_mesh->setParentItem(second.contentItem());
        QTRY_VERIFY(m_mesh->isRunning());
        /* the first window no longer matters */
        m_window->hide();
        QTest::qWait(50);
        QVERIFY(m_mesh->isRunning());
        second.hide();
        QTRY_VERIFY(!m_mesh->isRunning());
        m_mesh->setParentItem(nullptr);
        QVERIFY(!m_mesh->isRunning());
    }

    void outOfAWindowNeverRuns()
    {
        FlatMesh loose;
        QVERIFY(!loose.isRunning());
        loose.setAnimated(false);
        loose.setAnimated(true);
        QVERIFY(!loose.isRunning());
    }

    void destroyedMeshLeavesTheWindowAlone()
    {
        delete m_mesh;
        m_mesh = nullptr;
        press();   /* the event filter is gone with the mesh */
        m_window->hide();
        m_window->show();
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
    }

    void colours()
    {
        m_mesh->setCenterColor(QColor("#102030"));
        m_mesh->setOuterColor(QColor("#405060"));
        m_mesh->setCenterColor(QColor("#102030"));
        QCOMPARE(m_mesh->getCenterColor(), QColor("#102030"));
        QCOMPARE(m_mesh->getOuterColor(), QColor("#405060"));
        QTest::qWait(200);   /* a few frames with the new colours */
        QVERIFY(m_mesh->isRunning());
    }
};

QTEST_MAIN(TestFlatMesh)
#include "tst_flatmesh.moc"
