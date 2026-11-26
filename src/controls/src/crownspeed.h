/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef CROWNSPEED_H
#define CROWNSPEED_H

#include <vector>

/*
 * CrownSpeed: the state machine of RotaryInput's crown-speed mode
 * (face-interaction-32), for a view that snaps (a ListView or GridView with
 * a snap mode or StrictlyEnforceRange) and declares
 * `property bool rotaryCrownSpeed: true`. Without it such a view steps
 * item by item (RotaryInput's Snap kind); nothing sets it by default.
 *
 * Stock (SysUI, decompiled): the picker's RecyclerView scrolls by the
 * crown's pixels (AXIS_SCROLL x config_verticalScrollFactor 64 dp, no item
 * steps; RecyclerView.onGenericMotionEvent), its scroll feedback ticks every
 * 21 dp (42 px) of scroll with the remainder carried over and bumps once at
 * an end until the view moves again (HapticScrollFeedbackProvider), and
 * the picker column's rotary listener (hds.java) posts a 1 px smooth
 * scroll 80 ms after the last crown event (hdr.java case 0), so the
 * SnapHelper settles on the nearest item.
 *
 *   Idle --crown--> Scrolling --80 ms without crown--> Snapping --settled--> Idle
 *                      ^                                   |
 *                      +---------------crown---------------+
 *
 * A crown event during the snap scrolls on from where the content is (stock
 * scrollBy stops the smooth scroller). Plain C++ (no Qt): a host test drives
 * it (positions in px, times in ms, px positive towards the end).
 */
class CrownSpeed
{
public:
    enum State { Idle, Scrolling, Snapping };
    /* the snap 80 ms after the last crown event (hds.java postDelayed) */
    static constexpr long long IdleMs = 80;

    struct Event {
        double goal = 0;      /* where the content heads, within [lo, hi] */
        double applied = 0;   /* px the goal moved */
        bool tick = false;    /* a scroll tick plays (at most one per event) */
        bool atEnd = false;   /* the crown pushes against an end: nothing moved */
    };

    /* One crown event of px at timeMs. pos is where the content is now: the
     * scroll starts there from rest and during a snap. tickPx is the tick
     * interval (42 px on the watch). */
    Event scroll(double pos, double px, double lo, double hi, double tickPx, long long timeMs);
    /* At an end (Event::atEnd): true when the limit bump plays, once per end
     * until the view has moved. */
    bool limit(double pos);
    /* The crown has rested IdleMs since its last event. */
    bool snapDue(long long timeMs) const;
    /* Starts the snap to the snap position nearest to the goal (on a tie the
     * one the crown last turned towards); returns its index in positions,
     * -1 (and Idle) when there is none. */
    int snap(const std::vector<double> &positions);
    /* The glide reached the snap position. */
    void settled();
    /* A finger, or another view, took over. */
    void reset();

    State state() const { return m_state; }
    double goal() const { return m_goal; }

private:
    State m_state = Idle;
    double m_goal = 0;
    double m_tickAcc = 0;
    bool m_limitArmed = true;
    double m_limitPos = 0;
    long long m_lastMs = 0;
    int m_direction = 0;
};

#endif // CROWNSPEED_H
