// FP-Q2 (r2-63): host test of CrownSpeed, the state machine of RotaryInput's
// crown-speed mode (free scroll by crown px, tick every 42 px, one limit bump
// per end, the snap 80 ms after the last crown event, to the nearest item).
// R6 K-08: SnapSpeed, the stock rotary snap (speed-dependent threshold, at most 2 steps an event).
// Build: tests/crownspeed/CMakeLists.txt (host), or tests/run-qemu.sh crownspeed (aarch64, qemu).
#include "crownspeed.h"

#include <cmath>
#include <cstdio>
#include <vector>

static int failures = 0, checks = 0;
#define CHECK(c, msg) do { checks++; if (!(c)) { failures++; std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, msg); } } while (0)
static bool near(double a, double b, double tol = 1e-6) { return std::fabs(a - b) <= tol; }

static const double LO = 0, HI = 1000, TICK = 42;

static void freeScrollAndTicks()
{
    CrownSpeed c;
    CHECK(c.state() == CrownSpeed::Idle, "idle at first");
    // from rest at 100: the goal starts where the content is
    CrownSpeed::Event e = c.scroll(100, 30, LO, HI, TICK, 0);
    CHECK(c.state() == CrownSpeed::Scrolling, "scrolling");
    CHECK(near(e.goal, 130) && near(e.applied, 30), "30 px of crown: 30 px of scroll, no item step");
    CHECK(!e.tick, "no tick under 42 px");
    // while scrolling the goal accumulates (the content may lag behind it)
    e = c.scroll(110, 15, LO, HI, TICK, 20);
    CHECK(near(e.goal, 145), "the goal goes on from the last goal, not the content");
    CHECK(e.tick, "a tick at 45 px of scroll");
    e = c.scroll(140, 36, LO, HI, TICK, 40);
    CHECK(!e.tick, "the remainder (3 px) carried over: 39 px, no tick");
    e = c.scroll(170, 3, LO, HI, TICK, 60);
    CHECK(e.tick, "42 px since the last tick: a tick");
    // backwards: the accumulator runs down through 0 before a tick
    e = c.scroll(0, -41, LO, HI, TICK, 70);
    CHECK(!e.tick, "41 px back: no tick");
    e = c.scroll(0, -2, LO, HI, TICK, 75);
    CHECK(e.tick, "43 px back: a tick (1 px left over)");
    // at most one tick per event, the remainder kept below 42
    e = c.scroll(0, 130, LO, HI, TICK, 78);
    CHECK(e.tick && near(e.applied, 130), "a big event: one tick");
    e = c.scroll(0, 30, LO, HI, TICK, 79);
    CHECK(!e.tick, "-1 + 130 = 129, 129 % 42 = 3, plus 30 = 33: no tick");
}

static void tickRemainder()
{
    CrownSpeed c;
    c.scroll(0, 130, LO, HI, TICK, 0);          // tick, remainder 4
    CrownSpeed::Event e = c.scroll(0, 30, LO, HI, TICK, 10);
    CHECK(!e.tick, "remainder 4 + 30 = 34: no tick");
    e = c.scroll(0, 8, LO, HI, TICK, 20);
    CHECK(e.tick, "4 + 30 + 8 = 42: a tick");
}

static void limitAtEnds()
{
    CrownSpeed c;
    CrownSpeed::Event e = c.scroll(990, 30, LO, HI, TICK, 0);
    CHECK(near(e.goal, HI) && near(e.applied, 10), "bounded at the end");
    CHECK(!e.atEnd, "it moved");
    e = c.scroll(1000, 30, LO, HI, TICK, 10);
    CHECK(e.atEnd && near(e.applied, 0), "pushing against the end");
    CHECK(c.limit(e.goal), "the limit bump plays");
    e = c.scroll(1000, 30, LO, HI, TICK, 20);
    CHECK(e.atEnd && !c.limit(e.goal), "once per end");
    e = c.scroll(1000, -50, LO, HI, TICK, 30);
    CHECK(!e.atEnd && near(e.goal, 950), "away from the end");
    e = c.scroll(950, 80, LO, HI, TICK, 40);
    CHECK(near(e.goal, HI), "back to the end");
    e = c.scroll(1000, 10, LO, HI, TICK, 50);
    CHECK(e.atEnd && c.limit(e.goal), "re-armed after the view moved");
    // the start
    CrownSpeed s;
    e = s.scroll(0, -5, LO, HI, TICK, 0);
    CHECK(e.atEnd && s.limit(e.goal), "the start bumps too");
    CHECK(near(s.goal(), LO), "bounded at the start");
}

static void snapOnIdle()
{
    CrownSpeed c;
    // items every 100 px: snap positions 0, 100, 200, 300
    const std::vector<double> items = {0, 100, 200, 300};
    c.scroll(100, 30, LO, HI, TICK, 1000);      // goal 130
    CHECK(!c.snapDue(1000 + 79), "79 ms after the last event: not yet");
    CHECK(c.snapDue(1000 + 80), "80 ms: the snap is due");
    c.scroll(130, 20, LO, HI, TICK, 1050);      // goal 150, a later event moves the deadline
    CHECK(!c.snapDue(1100), "50 ms after the newer event: not yet");
    CHECK(c.snapDue(1130), "80 ms after the newer event");
    // 150 is half way between 100 and 200: the tie goes the way the crown turned
    int k = c.snap(items);
    CHECK(k == 2 && near(c.goal(), 200), "tie: towards the crown's direction (forward)");
    CHECK(c.state() == CrownSpeed::Snapping, "snapping");
    CHECK(!c.snapDue(5000), "no second snap while snapping");
    c.settled();
    CHECK(c.state() == CrownSpeed::Idle, "idle after the glide");

    CrownSpeed b;
    b.scroll(300, -170, LO, HI, TICK, 0);       // goal 130, turning back
    k = b.snap(items);
    CHECK(k == 1 && near(b.goal(), 100), "130: the nearest is 100");
    b.settled();
    b.scroll(100, -50, LO, HI, TICK, 200);      // goal 50: a tie between 0 and 100, turning back
    k = b.snap(items);
    CHECK(k == 0 && near(b.goal(), 0), "tie backwards: 0");
    b.settled();
    b.scroll(0, 70, LO, HI, TICK, 400);         // goal 70
    k = b.snap(items);
    CHECK(k == 1, "70: 100");
}

static void crownDuringSnap()
{
    CrownSpeed c;
    const std::vector<double> items = {0, 100, 200};
    c.scroll(0, 60, LO, HI, TICK, 0);
    c.snap(items);                              // to 100
    CHECK(c.state() == CrownSpeed::Snapping, "snapping");
    // the content is at 80 on its way to 100: a crown event scrolls on from 80
    CrownSpeed::Event e = c.scroll(80, 10, LO, HI, TICK, 120);
    CHECK(c.state() == CrownSpeed::Scrolling, "scrolling again");
    CHECK(near(e.goal, 90), "from where the content is");
    CHECK(c.snapDue(200) && !c.snapDue(199), "a new deadline");
}

static void resetAndEmpty()
{
    CrownSpeed c;
    c.scroll(0, 30, LO, HI, TICK, 0);
    c.reset();
    CHECK(c.state() == CrownSpeed::Idle && !c.snapDue(1000), "a finger: idle, no snap");
    CrownSpeed::Event e = c.scroll(500, 10, LO, HI, TICK, 10);
    CHECK(near(e.goal, 510), "the next crown event starts where the content is");
    CHECK(c.snap({}) == -1 && c.state() == CrownSpeed::Idle, "nothing to snap to: idle");
    CHECK(!c.snapDue(10000), "and no snap due");
}

// R6 K-08: the stock rotary snap step (androidx ThresholdHandler / HighResSnapRotaryScrollableBehavior)
static void snapSpeedSteps()
{
    const double ITEM = 80;
    // the thresholds: the whole item below 300 px/s, two thirds of it from 3000 px/s, eased between
    CHECK(near(SnapSpeed::threshold(0, ITEM, 1, 1.5), 80), "slow: the whole item");
    CHECK(near(SnapSpeed::threshold(300, ITEM, 1, 1.5), 80), "300 px/s: still the whole item");
    CHECK(near(SnapSpeed::threshold(3000, ITEM, 1, 1.5), 80 / 1.5), "3000 px/s: item / 1.5");
    CHECK(near(SnapSpeed::threshold(9000, ITEM, 1, 1.5), 80 / 1.5), "above: item / 1.5");
    CHECK(near(SnapSpeed::threshold(1650, ITEM, 1, 1.5), 80 / 1.25, 1e-3), "half way: the easing's middle");
    CHECK(near(SnapSpeed::threshold(3000, ITEM, 5, 7.5), 80 / 7.5), "pagers: the High dividers");
    CHECK(near(SnapSpeed::threshold(0, 0.5, 1, 1.5), 1), "at least 1 px");

    // a fresh gesture: no speed, the pending px start from nothing
    SnapStep s = SnapSpeed::step(50, 2000, 30, 30, -1, false, ITEM, 1, 1.5);
    CHECK(s.steps == 0 && near(s.pending, 30) && near(s.velocity, 0), "the first event: 30 px, no speed");
    s = SnapSpeed::step(s.pending, s.velocity, 60, 60, 300, false, ITEM, 1, 1.5);
    CHECK(s.steps == 0 && near(s.pending, 60), "300 ms later: a new gesture (the 30 px are dropped)");
    s = SnapSpeed::step(70, 900, 30, 30, 10, true, ITEM, 1, 1.5);
    CHECK(s.steps == 0 && near(s.pending, 30) && near(s.velocity, 0), "fresh: speed and pending reset");

    // slow turning (1 px speed per 20 ms = 50 px/s): one item per 80 px, the remainder kept
    s = SnapSpeed::step(0, 0, 40, 1, -1, false, ITEM, 1, 1.5);
    s = SnapSpeed::step(s.pending, s.velocity, 40, 1, 20, false, ITEM, 1, 1.5);
    CHECK(s.steps == 1 && near(s.pending, 0, 1e-9), "80 px slowly: one item");
    s = SnapSpeed::step(s.pending, s.velocity, -100, 1, 20, false, ITEM, 1, 1.5);
    CHECK(s.steps == -1 && near(s.pending, -20, 1e-9), "back 100 px: one item back, 20 px pending");

    // at most two items an event, the rest dropped below a threshold
    s = SnapSpeed::step(0, 0, 250, 1, -1, false, ITEM, 1, 1.5);
    CHECK(s.steps == 2, "250 px in one event: two items, not three");
    CHECK(near(s.pending, 10, 1e-9), "250 - 3 x 80 = 10 px left (fmod)");

    // fast spinning (36 px of stock speed every 10 ms = 3600 px/s): the threshold falls towards item / 1.5,
    // so the same 40 px events step more items than slow ones
    int slow = 0, fast = 0;
    SnapStep a, b;
    for (int i = 0; i < 12; i++) {
        a = SnapSpeed::step(a.pending, a.velocity, 40, 1, i ? 20 : -1, false, ITEM, 1, 1.5);
        b = SnapSpeed::step(b.pending, b.velocity, 40, 36, i ? 10 : -1, false, ITEM, 1, 1.5);
        slow += a.steps;
        fast += b.steps;
    }
    CHECK(slow == 6, "480 px slowly: 6 items");
    CHECK(fast >= 8 && fast <= 9, "480 px spun fast: 8 or 9 items (up to 480 / 53.3)");
    CHECK(b.velocity > 3000, "the speed past 3000 px/s");
}

int main()
{
    snapSpeedSteps();
    freeScrollAndTicks();
    tickRemainder();
    limitAtEnds();
    snapOnIdle();
    crownDuringSnap();
    resetAndEmpty();
    std::printf("Totals: %d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
