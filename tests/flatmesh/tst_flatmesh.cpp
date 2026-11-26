/*
 * Host test of FlatMesh's motion policy (src/controls/src/flatmesh.{h,cpp}): still by default; "input" glides
 * after input on its window for the idle timeout and stops, "always" moves for as long as it is visible; both
 * only while the item is visible, its window shown and exposed, "animated" is true and Accessibility > Reduce
 * animations is off. The mode comes from dconf (flatmesh-motion) or a "motion" binding, the glide time from dconf
 * (seconds; -home for the launcher) or an idleTimeout binding (ms); input on the window, wake(), the item or the
 * window showing again start the glide again.
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
static const char MOTION_KEY[] = "/org/asteroidos/settings/flatmesh-motion";
static const char REDUCE_KEY[] = "/org/asteroidos/a11y/reduce-motion";

class TestFlatMesh : public QObject
{
    Q_OBJECT

private:
    QQuickWindow *m_window = nullptr;
    FlatMesh *m_mesh = nullptr;

    static void setSystem(const QVariant &apps, const QVariant &home)
    {
        MDConfItem::setTestValue(QLatin1String(APPS_KEY), apps);
        MDConfItem::setTestValue(QLatin1String(HOME_KEY), home);
    }
    static void setSystemMotion(const QVariant &motion)
    {
        MDConfItem::setTestValue(QLatin1String(MOTION_KEY), motion);
    }
    void press()
    {
        QTest::mousePress(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(20, 20));
        QTest::mouseRelease(m_window, Qt::LeftButton, Qt::NoModifier, QPoint(20, 20));
    }
    /* "input" with a glide of ms: it moves at once, and stops by itself when the glide is over */
    bool becomeIdle(int ms)
    {
        m_mesh->setMotion(QStringLiteral("input"));
        m_mesh->setIdleTimeout(ms);
        if (!m_mesh->isRunning())
            return false;
        QElapsedTimer t;
        t.start();
        while (m_mesh->isRunning() && t.elapsed() < ms + 3000)
            QTest::qWait(20);
        return !m_mesh->isRunning();
    }

private slots:
    void init()
    {
        setSystem(QVariant(), QVariant());
        setSystemMotion(QVariant());
        MDConfItem::setTestValue(QLatin1String(REDUCE_KEY), QVariant());
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

    void stillByDefault()
    {
        QCOMPARE(m_mesh->motion(), QStringLiteral("static"));
        QCOMPARE(m_mesh->idleTimeout(), 3000);
        QVERIFY(m_mesh->getAnimated());
        QVERIFY(!m_mesh->isRunning());
        QTest::qWait(200);
        QVERIFY(!m_mesh->isRunning());
        /* input does not move a still mesh */
        press();
        m_mesh->wake();
        QVERIFY(!m_mesh->isRunning());
    }

    void systemMotion_data()
    {
        QTest::addColumn<QVariant>("value");
        QTest::addColumn<QString>("expected");
        QTest::addColumn<bool>("moves");
        QTest::newRow("unset") << QVariant() << QStringLiteral("static") << false;
        QTest::newRow("static") << QVariant(QStringLiteral("static")) << QStringLiteral("static") << false;
        QTest::newRow("input") << QVariant(QStringLiteral("input")) << QStringLiteral("input") << true;
        QTest::newRow("always") << QVariant(QStringLiteral("always")) << QStringLiteral("always") << true;
        QTest::newRow("unknown") << QVariant(QStringLiteral("sometimes")) << QStringLiteral("static") << false;
    }
    void systemMotion()
    {
        QFETCH(QVariant, value);
        QFETCH(QString, expected);
        QFETCH(bool, moves);
        setSystemMotion(value);
        QCOMPARE(m_mesh->motion(), expected);
        QCOMPARE(m_mesh->isRunning(), moves);
        /* read live: a new mesh sees the same */
        FlatMesh other;
        QCOMPARE(other.motion(), expected);
    }

    void liveMotionChange()
    {
        QSignalSpy changed(m_mesh, &FlatMesh::motionChanged);
        QSignalSpy running(m_mesh, &FlatMesh::runningChanged);
        setSystemMotion(QStringLiteral("always"));
        QCOMPARE(changed.count(), 1);
        QVERIFY(m_mesh->isRunning());
        QCOMPARE(running.count(), 1);
        /* the same value again: nothing */
        setSystemMotion(QStringLiteral("always"));
        QCOMPARE(changed.count(), 1);
        QCOMPARE(running.count(), 1);
        setSystemMotion(QVariant());
        QCOMPARE(changed.count(), 2);
        QVERIFY(!m_mesh->isRunning());
        QCOMPARE(running.count(), 2);
    }

    void motionBindingWinsAndResets()
    {
        setSystemMotion(QStringLiteral("always"));
        QVERIFY(m_mesh->isRunning());
        QSignalSpy changed(m_mesh, &FlatMesh::motionChanged);
        m_mesh->setMotion(QStringLiteral("static"));
        QCOMPARE(m_mesh->motion(), QStringLiteral("static"));
        QVERIFY(!m_mesh->isRunning());
        QCOMPARE(changed.count(), 1);
        /* the system setting no longer matters while overridden */
        setSystemMotion(QStringLiteral("input"));
        QCOMPARE(m_mesh->motion(), QStringLiteral("static"));
        QCOMPARE(changed.count(), 1);
        QVERIFY(!m_mesh->isRunning());
        /* an unknown value goes back to the system setting */
        m_mesh->setMotion(QStringLiteral("sometimes"));
        QCOMPARE(m_mesh->motion(), QStringLiteral("input"));
        QCOMPARE(changed.count(), 2);
        QVERIFY(m_mesh->isRunning());
        m_mesh->setMotion(QStringLiteral("always"));
        QCOMPARE(changed.count(), 3);
        m_mesh->resetMotion();
        QCOMPARE(m_mesh->motion(), QStringLiteral("input"));
        QCOMPARE(changed.count(), 4);
        /* an override equal to the mode in effect changes nothing visible */
        m_mesh->setMotion(QStringLiteral("input"));
        QCOMPARE(changed.count(), 4);
    }

    void alwaysHasNoIdleHold()
    {
        m_mesh->setMotion(QStringLiteral("always"));
        m_mesh->setIdleTimeout(300);
        QVERIFY(m_mesh->isRunning());
        QTest::qWait(900);   /* well past the glide time */
        QVERIFY(m_mesh->isRunning());
    }

    void invisibleItemStops()
    {
        m_mesh->setMotion(QStringLiteral("always"));
        QVERIFY(m_mesh->isRunning());
        QSignalSpy running(m_mesh, &FlatMesh::runningChanged);
        m_mesh->setVisible(false);
        QVERIFY(!m_mesh->isRunning());
        QCOMPARE(running.count(), 1);
        m_mesh->setVisible(true);
        QVERIFY(m_mesh->isRunning());
        QCOMPARE(running.count(), 2);
    }

    void becomingVisibleStartsTheGlide()
    {
        QVERIFY(becomeIdle(300));
        m_mesh->setVisible(false);
        m_mesh->setVisible(true);
        QVERIFY(m_mesh->isRunning());
    }

    void hiddenWindowStops()
    {
        m_mesh->setMotion(QStringLiteral("always"));
        QVERIFY(m_mesh->isRunning());
        m_window->hide();
        QTRY_VERIFY(!m_mesh->isRunning());
        m_window->show();
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
        QTRY_VERIFY(m_mesh->isRunning());
    }

    void windowShownAgainStartsTheGlide()
    {
        /* a glide long enough to be seen after the window is exposed again */
        QVERIFY(becomeIdle(300));
        m_mesh->setIdleTimeout(2000);
        QTRY_VERIFY_WITH_TIMEOUT(!m_mesh->isRunning(), 5000);
        m_window->hide();
        QVERIFY(!m_mesh->isRunning());
        m_window->show();
        QVERIFY(QTest::qWaitForWindowExposed(m_window));
        QTRY_VERIFY(m_mesh->isRunning());
    }

    void animatedFalseStops()
    {
        m_mesh->setMotion(QStringLiteral("always"));
        QSignalSpy animated(m_mesh, &FlatMesh::animatedChanged);
        m_mesh->setAnimated(false);
        QVERIFY(!m_mesh->isRunning());
        m_mesh->setAnimated(false);   /* no change, no signal */
        QCOMPARE(animated.count(), 1);
        m_mesh->setAnimated(true);
        QVERIFY(m_mesh->isRunning());
        QCOMPARE(animated.count(), 2);
    }

    void reduceMotionKeepsItStill()
    {
        m_mesh->setMotion(QStringLiteral("always"));
        QVERIFY(m_mesh->isRunning());
        MDConfItem::setTestValue(QLatin1String(REDUCE_KEY), true);
        QVERIFY(!m_mesh->isRunning());
        m_mesh->wake();
        m_mesh->setMotion(QStringLiteral("input"));
        QVERIFY(!m_mesh->isRunning());
        MDConfItem::setTestValue(QLatin1String(REDUCE_KEY), false);
        QVERIFY(m_mesh->isRunning());
    }

    void glidesForTheIdleTimeout()
    {
        m_mesh->setIdleTimeout(800);
        QElapsedTimer t;
        t.start();
        m_mesh->setMotion(QStringLiteral("input"));
        QVERIFY(m_mesh->isRunning());
        QTRY_VERIFY_WITH_TIMEOUT(!m_mesh->isRunning(), 5000);
        QVERIFY2(t.elapsed() >= 800, qPrintable(QStringLiteral("stopped after %1 ms").arg(t.elapsed())));
    }

    void idleHoldAndInputStartsTheGlide()
    {
        QVERIFY(becomeIdle(300));
        press();
        QVERIFY(m_mesh->isRunning());
        /* and it stops again after another quiet period */
        QTRY_VERIFY_WITH_TIMEOUT(!m_mesh->isRunning(), 3000);
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

    void wheelKeyAndFocusStartTheGlide_data()
    {
        QTest::addColumn<int>("kind");
        QTest::newRow("wheel") << 0;
        QTest::newRow("key") << 1;
        QTest::newRow("focus") << 2;
    }
    void wheelKeyAndFocusStartTheGlide()
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

    void wakeStartsTheGlide()
    {
        QVERIFY(becomeIdle(300));
        m_mesh->wake();
        QVERIFY(m_mesh->isRunning());
        m_mesh->wake();   /* gliding: nothing to do */
        QVERIFY(m_mesh->isRunning());
    }

    void systemTimeout_data()
    {
        QTest::addColumn<QVariant>("apps");
        QTest::addColumn<QVariant>("home");
        QTest::addColumn<int>("expectedMs");
        QTest::newRow("unset: 3 s") << QVariant() << QVariant() << 3000;
        QTest::newRow("apps seconds") << QVariant(10) << QVariant() << 10000;
        QTest::newRow("apps fraction") << QVariant(2.5) << QVariant() << 2500;
        QTest::newRow("apps string number") << QVariant(QStringLiteral("4")) << QVariant() << 4000;
        QTest::newRow("not a number") << QVariant(QStringLiteral("soon")) << QVariant() << 3000;
        QTest::newRow("zero") << QVariant(0) << QVariant() << 3000;
        QTest::newRow("negative") << QVariant(-5) << QVariant() << 3000;
        QTest::newRow("below the minimum") << QVariant(0.1) << QVariant() << 500;
        QTest::newRow("above a day") << QVariant(1e9) << QVariant() << 86400000;
        QTest::newRow("home wins in the launcher") << QVariant(3) << QVariant(1) << 1000;
        QTest::newRow("home 0: the default, not apps") << QVariant(5) << QVariant(0) << 3000;
        QTest::newRow("home unset: apps") << QVariant(4) << QVariant() << 4000;
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

    void liveChangeSignalsAndStartsTheGlide()
    {
        m_mesh->setMotion(QStringLiteral("input"));
        QSignalSpy changed(m_mesh, &FlatMesh::idleTimeoutChanged);
        setSystem(QVariant(0.5), QVariant());
        QCOMPARE(changed.count(), 1);
        QCOMPARE(m_mesh->idleTimeout(), 500);
        QTRY_VERIFY_WITH_TIMEOUT(!m_mesh->isRunning(), 3000);
        /* the same value again: no signal, still */
        setSystem(QVariant(0.5), QVariant());
        QCOMPARE(changed.count(), 1);
        QVERIFY(!m_mesh->isRunning());
        /* a new value glides again */
        setSystem(QVariant(), QVariant());
        QCOMPARE(changed.count(), 2);
        QCOMPARE(m_mesh->idleTimeout(), 3000);
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
        /* 0: no glide at all, input moves nothing */
        m_mesh->setIdleTimeout(0);
        QCOMPARE(m_mesh->idleTimeout(), 0);
        m_mesh->setMotion(QStringLiteral("input"));
        QVERIFY(!m_mesh->isRunning());
        press();
        QVERIFY(!m_mesh->isRunning());
    }

    void movesToAnotherWindow()
    {
        m_mesh->setMotion(QStringLiteral("always"));
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
        loose.setMotion(QStringLiteral("always"));
        QVERIFY(!loose.isRunning());
        loose.setAnimated(false);
        loose.setAnimated(true);
        loose.wake();
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
        m_mesh->setMotion(QStringLiteral("always"));
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
