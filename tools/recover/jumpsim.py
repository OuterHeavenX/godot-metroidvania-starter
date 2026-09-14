#!/usr/bin/env python3
"""Replay MVPlayer's _physics_process to size level geometry.

Run it before placing a ledge. It reports how far a platform can sit
horizontally for a given rise, which is the number that decides whether a jump
is possible. Keep real hops comfortably under the printed reach -- the
Undercroft sits at or under 70%.

Keep the constants below in sync with src/player/player.gd.
"""

DT = 1.0 / 60.0
SPEED, ACCEL, AIR_ACCEL = 260.0, 2400.0, 1500.0
JUMP_V, GRAV = -560.0, 980.0
DOUBLE_MULT = 0.92
MAX_FALL = 1150.0
FALL_GRAVITY_MULT, APEX_GRAVITY_MULT, APEX_SPEED = 1.35, 0.72, 90.0
DASH_SPEED, DASH_TIME = 640.0, 0.16


def move_toward(v, target, delta):
    return target if abs(target - v) <= delta else v + (delta if target > v else -delta)


def gravity_now(vy):
    g = GRAV
    if vy > 0.0:
        g *= FALL_GRAVITY_MULT
    if abs(vy) < APEX_SPEED:
        g *= APEX_GRAVITY_MULT
    return g


def trajectory(double=False, dash_at=None, hold_jump=True):
    """Positions relative to the takeoff point, y positive downward."""
    x = y = 0.0
    vx, vy = SPEED, JUMP_V
    used_double = not double
    dash_left = 0.0
    pts = []
    for i in range(400):
        t = i * DT
        if dash_at is not None and abs(t - dash_at) < DT / 2:
            dash_left = DASH_TIME
        if dash_left > 0.0:
            dash_left -= DT
            vx, vy = DASH_SPEED, 0.0
        else:
            if not hold_jump and vy < -220.0:
                vy = -220.0
            vx = move_toward(vx, SPEED, AIR_ACCEL * DT)
            vy = min(vy + gravity_now(vy) * DT, MAX_FALL)
            if not used_double and vy >= 0.0:
                vy = JUMP_V * DOUBLE_MULT
                used_double = True
        x += vx * DT
        y += vy * DT
        pts.append((x, y))
        if y > 600:
            break
    return pts


def max_gap(dy, **kw):
    """Furthest a platform whose top is `dy` below takeoff can sit.

    dy < 0 means the target is higher than the takeoff. Returns 0.0 when the
    trajectory never reaches that height at all.
    """
    best = 0.0
    for x, y in trajectory(**kw):
        if y <= dy:
            best = max(best, x)
    return best


def peak(**kw):
    return -min(y for _x, y in trajectory(**kw))


if __name__ == '__main__':
    print(f"single jump peak: {peak():.0f}px     double jump peak: {peak(double=True):.0f}px")
    print()
    print("how far a ledge can sit for a given rise:")
    print(f"  {'rise':>6} {'single':>10} {'double':>10} {'dbl+dash':>10}")
    for rise in (0, 60, 120, 180, 240, 260, 295):
        s = max_gap(-rise)
        d = max_gap(-rise, double=True)
        dd = max_gap(-rise, double=True, dash_at=0.30)
        fmt = lambda v: f"{v:.0f}px" if v > 0 else "--"
        print(f"  {rise:>4}px {fmt(s):>10} {fmt(d):>10} {fmt(dd):>10}")
    print()
    print("dropping to a lower ledge:")
    for drop in (70, 160, 300):
        print(f"  {drop:>4}px down: single {max_gap(drop):.0f}px, "
              f"double {max_gap(drop, double=True):.0f}px")
