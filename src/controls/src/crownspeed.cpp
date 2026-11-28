/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "crownspeed.h"

#include <cmath>

CrownSpeed::Event CrownSpeed::scroll(double pos, double px, double lo, double hi, double tickPx,
                                     long long timeMs)
{
    Event e;
    /* from rest, or during a snap: from where the content is */
    if (m_state != Scrolling)
        m_goal = pos;
    m_state = Scrolling;
    m_lastMs = timeMs;
    if (px != 0)
        m_direction = px > 0 ? 1 : -1;
    const double before = m_goal;
    const double wanted = m_goal + px;
    m_goal = wanted < lo ? lo : wanted > hi ? hi : wanted;
    e.goal = m_goal;
    e.applied = m_goal - before;
    if (std::fabs(e.applied) < 0.01) {
        e.applied = 0;
        e.atEnd = true;
        return e;
    }
    m_limitArmed = true;
    /* SCROLL_TICK every tickPx of scroll, the remainder carried over */
    m_tickAcc += e.applied;
    if (tickPx > 0 && std::fabs(m_tickAcc) >= tickPx) {
        m_tickAcc = std::fmod(m_tickAcc, tickPx);
        e.tick = true;
    }
    return e;
}

bool CrownSpeed::limit(double pos)
{
    if (!m_limitArmed && std::fabs(pos - m_limitPos) < 1)
        return false;
    m_limitArmed = false;
    m_limitPos = pos;
    return true;
}

bool CrownSpeed::snapDue(long long timeMs) const
{
    return m_state == Scrolling && timeMs - m_lastMs >= IdleMs;
}

int CrownSpeed::snap(const std::vector<double> &positions)
{
    int best = -1;
    double bestDistance = 0;
    for (int i = 0; i < int(positions.size()); i++) {
        const double d = std::fabs(positions[i] - m_goal);
        const bool tie = best >= 0 && std::fabs(d - bestDistance) < 1e-6;
        if (best < 0 || (!tie && d < bestDistance)
                || (tie && (positions[i] - m_goal) * m_direction > (positions[best] - m_goal) * m_direction)) {
            best = i;
            bestDistance = d;
        }
    }
    if (best < 0) {
        m_state = Idle;
        return -1;
    }
    m_goal = positions[best];
    m_state = Snapping;
    return best;
}

void CrownSpeed::settled()
{
    if (m_state == Snapping)
        m_state = Idle;
}

void CrownSpeed::reset()
{
    m_state = Idle;
    m_tickAcc = 0;
    m_limitArmed = true;
    m_direction = 0;
}

/* CubicBezier(x1, y1, x2, y2) easing at x (compose CubicBezierEasing) */
static double cubicBezier(double x1, double y1, double x2, double y2, double x)
{
    auto b = [](double p1, double p2, double t) {
        const double u = 1 - t;
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
    };
    double lo = 0, hi = 1, t = x;
    for (int i = 0; i < 32; i++) {
        t = (lo + hi) / 2;
        if (b(x1, x2, t) < x)
            lo = t;
        else
            hi = t;
    }
    return b(y1, y2, t);
}

double SnapSpeed::threshold(double velocity, double itemSize, double minDivider, double maxDivider)
{
    double u = (velocity - MinVelocity) / (MaxVelocity - MinVelocity);
    u = u < 0 ? 0 : u > 1 ? 1 : u;
    const double e = cubicBezier(0.5, 0, 0.5, 1, u);
    const double t = itemSize / (minDivider + (maxDivider - minDivider) * e);
    return t < 1 ? 1 : t;
}

SnapStep SnapSpeed::step(double pending, double velocity, double px, double speedPx, long long gapMs, bool fresh,
                         double itemSize, double minDivider, double maxDivider)
{
    SnapStep s;
    if (gapMs < 0 || gapMs > BreakMs || fresh) {
        pending = 0;
        velocity = 0;
    } else {
        const double v = std::fabs(speedPx) / (gapMs < 1 ? 1 : gapMs) * 1000.0;
        velocity = v * Smoothing + (1 - Smoothing) * velocity;
    }
    const double threshold = SnapSpeed::threshold(velocity, itemSize, minDivider, maxDivider);
    pending += px;
    int steps = int(pending / threshold);
    if (steps != 0) {
        pending -= steps * threshold;
        steps = steps < -MaxPerEvent ? -MaxPerEvent : steps > MaxPerEvent ? MaxPerEvent : steps;
        if (std::fabs(pending) >= threshold)
            pending = std::fmod(pending, threshold);
    }
    s.steps = steps;
    s.pending = pending;
    s.velocity = velocity;
    return s;
}
