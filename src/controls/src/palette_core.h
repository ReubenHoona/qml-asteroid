/*
 * Copyright (C) 2026 eos-mainline contributors
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef PALETTE_CORE_H
#define PALETTE_CORE_H

/*
 * The colour maths of the Wear OS "Color theme", with no Qt in it (so it can
 * be tested on the host): HCT (CAM16 hue and chroma + CIE L* tone), tonal
 * palettes and the five Wear schemes (NEUTRAL, TONAL_SPOT, VIBRANT,
 * EXPRESSIVE, CONTENT) as ClockworkSystemUI builds them. Ported from the
 * Apache-2.0 material-color-utilities as stock CP3A ships it:
 *   libmonet hct/Hct.java, hct/HctSolver.java, hct/ViewingConditions.java,
 *   contrast/Contrast.java, dynamiccolor/DynamicColor.foregroundTone
 *   (decomp/jar.services),
 *   themeoverlay/monet/WearColorScheme.java:94-130,
 *   themeoverlay/libmonet/scheme (the five Wear*V2 classes), WearMaterialDynamicColors.java
 *   (mainTone, dimTone, containerTone, findDesiredChromaByTone)
 *   (decomp/com.google.android.apps.wearable.systemui).
 * The 29 role rules come from the static "No theme" table, which is the
 * NEUTRAL scheme of a blue-grey seed (see roles()).
 */

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

namespace eosmonet {

typedef std::array<double, 3> Vec3;

/* ---------------------------------------------------------------- colour utils */

inline double linearized(int c)
{
    double d = c / 255.0;
    return (d <= 0.040449936 ? d / 12.92 : std::pow((d + 0.055) / 1.055, 2.4)) * 100.0;
}

inline int delinearized(double v)
{
    double n = v / 100.0;
    double d = n <= 0.0031308 ? n * 12.92 : std::pow(n, 1.0 / 2.4) * 1.055 - 0.055;
    long r = std::lround(d * 255.0);
    return int(std::min(255L, std::max(0L, r)));
}

inline double trueDelinearized(double v)
{
    double n = v / 100.0;
    return (n <= 0.0031308 ? n * 12.92 : std::pow(n, 1.0 / 2.4) * 1.055 - 0.055) * 255.0;
}

inline double labF(double t)
{
    return t > 216.0 / 24389.0 ? std::cbrt(t) : ((24389.0 / 27.0) * t + 16.0) / 116.0;
}

inline double yFromLstar(double l)
{
    double f = (l + 16.0) / 116.0;
    double f3 = f * f * f;
    if (f3 <= 216.0 / 24389.0)
        f3 = (f * 116.0 - 16.0) / (24389.0 / 27.0);
    return f3 * 100.0;
}

inline double lstarFromY(double y) { return labF(y / 100.0) * 116.0 - 16.0; }

inline double sanitizeDegrees(double d)
{
    double r = std::fmod(d, 360.0);
    return r < 0 ? r + 360.0 : r;
}

inline Vec3 mul3(const Vec3 &v, const double m[3][3])
{
    return {m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
            m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
            m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2]};
}

/* ------------------------------------------------------------ viewing conditions */

static const double kSrgbToXyz[3][3] = {{0.41233895, 0.35762064, 0.18051042},
                                        {0.2126, 0.7152, 0.0722},
                                        {0.01932141, 0.11916382, 0.95034478}};
static const double kXyzToCam16Rgb[3][3] = {{0.401288, 0.650173, -0.051461},
                                            {-0.250268, 1.204414, 0.045854},
                                            {-0.002079, 0.048952, 0.953127}};
static const double kScaledDiscountFromLinrgb[3][3] = {
    {0.001200833568784504, 0.002389694492170889, 0.0002795742885861124},
    {0.0005891086651375999, 0.0029785502573438758, 0.0003270666104008398},
    {0.00010146692491640572, 0.0005364214359186694, 0.0032979401770712076}};
static const double kLinrgbFromScaledDiscount[3][3] = {
    {1373.2198709594231, -1100.4251190754821, -7.278681089101213},
    {-271.815969077903, 559.6580465940733, -32.46047482791194},
    {1.9622899599665666, -57.173814538844006, 308.7233197812385}};
static const double kYFromLinrgb[3] = {0.2126, 0.7152, 0.0722};

struct Viewing {
    double aw, nbb, ncb, c, nc, n, z, fl, flRoot;
    double rgbD[3];
};

/* ViewingConditions.DEFAULT: D65, L* 50 background, average surround */
inline const Viewing &viewing()
{
    static const Viewing v = [] {
        Viewing r;
        const double wp[3] = {95.047, 100.0, 108.883};
        double adapting = yFromLstar(50.0) * 63.66197723675813 / 100.0;
        Vec3 rgbW = mul3({wp[0], wp[1], wp[2]}, kXyzToCam16Rgb);
        double f = 1.0;
        double c = 0.59 + (0.69 - 0.59) * 0.9999999999999998;
        double d = std::min(1.0, std::max(0.0, (1.0 - std::exp((-adapting - 42.0) / 92.0) * (1.0 / 3.6)) * f));
        for (int i = 0; i < 3; i++)
            r.rgbD[i] = (100.0 / rgbW[i]) * d + 1.0 - d;
        double k = 1.0 / (5.0 * adapting + 1.0);
        double k4 = k * k * k * k;
        double k4f = 1.0 - k4;
        r.fl = k4 * adapting + 0.1 * k4f * k4f * std::cbrt(5.0 * adapting);
        r.n = yFromLstar(50.0) / wp[1];
        r.z = 1.48 + std::sqrt(r.n);
        r.nbb = 0.725 / std::pow(r.n, 0.2);
        r.ncb = r.nbb;
        double a[3];
        for (int i = 0; i < 3; i++) {
            double x = std::pow(r.rgbD[i] * r.fl * rgbW[i] / 100.0, 0.42);
            a[i] = x * 400.0 / (x + 27.13);
        }
        r.aw = (2.0 * a[0] + a[1] + 0.05 * a[2]) * r.nbb;
        r.flRoot = std::pow(r.fl, 0.25);
        r.c = c;
        r.nc = 1.0;
        return r;
    }();
    return v;
}

/* ------------------------------------------------------------------------- HCT */

struct Hct {
    double hue = 0, chroma = 0, tone = 0;
};

inline Hct hctFromArgb(uint32_t argb)
{
    const Viewing &v = viewing();
    int r = (argb >> 16) & 255, g = (argb >> 8) & 255, b = argb & 255;
    Vec3 xyz = mul3({linearized(r), linearized(g), linearized(b)}, kSrgbToXyz);
    Vec3 rgbC = mul3(xyz, kXyzToCam16Rgb);
    double ra[3];
    for (int i = 0; i < 3; i++) {
        double x = rgbC[i] * v.rgbD[i];
        double af = std::pow(std::fabs(x) * v.fl / 100.0, 0.42);
        ra[i] = (x < 0 ? -1.0 : (x == 0 ? 0.0 : 1.0)) * 400.0 * af / (af + 27.13);
    }
    double a = (11.0 * ra[0] + -12.0 * ra[1] + ra[2]) / 11.0;
    double bb = (ra[0] + ra[1] - 2.0 * ra[2]) / 9.0;
    double u = (20.0 * ra[0] + 20.0 * ra[1] + 21.0 * ra[2]) / 20.0;
    double p2 = (40.0 * ra[0] + 20.0 * ra[1] + ra[2]) / 20.0;
    double hue = sanitizeDegrees(std::atan2(bb, a) * 180.0 / M_PI);
    double j = std::pow(p2 * v.nbb / v.aw, v.z * v.c);
    double hr = (hue < 20.14 ? hue + 360.0 : hue) * M_PI / 180.0;
    double eHue = 0.25 * (std::cos(hr + 2.0) + 3.8);
    double t = 50000.0 / 13.0 * eHue * v.nc * v.ncb * std::hypot(a, bb) / (u + 0.305);
    double alpha = std::pow(t, 0.9) * std::pow(1.64 - std::pow(0.29, v.n), 0.73);
    Hct h;
    h.hue = hue;
    h.chroma = std::sqrt(j) * alpha;
    h.tone = labF(xyz[1] / 100.0) * 116.0 - 16.0;
    return h;
}

inline double chromaticAdaptation(double d)
{
    double p = std::pow(std::fabs(d), 0.42);
    return (d < 0 ? -1.0 : (d == 0 ? 0.0 : 1.0)) * 400.0 * p / (p + 27.13);
}

inline double inverseChromaticAdaptation(double d)
{
    double a = std::fabs(d);
    return std::pow(std::max(0.0, 27.13 * a / (400.0 - a)), 1.0 / 0.42) * (d < 0 ? -1.0 : (d == 0 ? 0.0 : 1.0));
}

inline double hueOf(const Vec3 &lin)
{
    Vec3 s = mul3(lin, kScaledDiscountFromLinrgb);
    double ra = chromaticAdaptation(s[0]), ga = chromaticAdaptation(s[1]), ba = chromaticAdaptation(s[2]);
    return std::atan2((ra + ga - 2.0 * ba) / 9.0, (11.0 * ra - 12.0 * ga + ba) / 11.0);
}

inline bool inCyclicOrder(double a, double b, double c)
{
    return std::fmod((b - a) + 8.0 * M_PI, 2.0 * M_PI) < std::fmod((c - a) + 8.0 * M_PI, 2.0 * M_PI);
}

inline bool bounded(double x) { return 0.0 <= x && x <= 100.0; }

inline uint32_t argbFromLinrgb(const Vec3 &l)
{
    return 0xFF000000u | (uint32_t(delinearized(l[0])) << 16) | (uint32_t(delinearized(l[1])) << 8)
           | uint32_t(delinearized(l[2]));
}

/* the exact solution at the requested J, or 0 when it is out of gamut */
inline uint32_t solveAtJ(double hueRad, double chroma, double y)
{
    const Viewing &v = viewing();
    double j = std::sqrt(y) * 11.0;
    double tInner = 1.0 / std::pow(1.64 - std::pow(0.29, v.n), 0.73);
    double eHue = 0.25 * (std::cos(hueRad + 2.0) + 3.8);
    double p1 = eHue * (50000.0 / 13.0) * v.nc * v.ncb;
    double hSin = std::sin(hueRad), hCos = std::cos(hueRad);
    for (int round = 0; round < 5; round++) {
        double jn = j / 100.0;
        double alpha = (chroma == 0.0 || j == 0.0) ? 0.0 : chroma / std::sqrt(jn);
        double t = std::pow(alpha * tInner, 1.0 / 0.9);
        double ac = std::pow(jn, 1.0 / v.c / v.z) * v.aw;
        double p2 = ac / v.nbb;
        double gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11.0 * t * hCos + 108.0 * t * hSin);
        double a = gamma * hCos, b = gamma * hSin;
        double rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
        double gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
        double bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;
        Vec3 lin = mul3({inverseChromaticAdaptation(rA), inverseChromaticAdaptation(gA), inverseChromaticAdaptation(bA)},
                        kLinrgbFromScaledDiscount);
        if (lin[0] < 0 || lin[1] < 0 || lin[2] < 0)
            return 0;
        double fnj = kYFromLinrgb[0] * lin[0] + kYFromLinrgb[1] * lin[1] + kYFromLinrgb[2] * lin[2];
        if (fnj <= 0)
            return 0;
        if (round == 4 || std::fabs(fnj - y) < 0.002) {
            if (lin[0] > 100.01 || lin[1] > 100.01 || lin[2] > 100.01)
                return 0;
            return argbFromLinrgb(lin);
        }
        j = j - (fnj - y) * j / (2.0 * fnj);
    }
    return 0;
}

inline Vec3 nthVertex(double y, int n)
{
    double kR = kYFromLinrgb[0], kG = kYFromLinrgb[1], kB = kYFromLinrgb[2];
    double coordA = n % 4 <= 1 ? 0.0 : 100.0;
    double coordB = n % 2 == 0 ? 0.0 : 100.0;
    if (n < 4) {
        double r = (y - coordA * kG - coordB * kB) / kR;
        return bounded(r) ? Vec3{r, coordA, coordB} : Vec3{-1, -1, -1};
    }
    if (n < 8) {
        double g = (y - coordB * kR - coordA * kB) / kG;
        return bounded(g) ? Vec3{coordB, g, coordA} : Vec3{-1, -1, -1};
    }
    double b = (y - coordA * kR - coordB * kG) / kB;
    return bounded(b) ? Vec3{coordA, coordB, b} : Vec3{-1, -1, -1};
}

inline const std::vector<double> &criticalPlanes()
{
    /* the 256 planes between the 8-bit steps: linear light of (i + 0.5) / 255 */
    static const std::vector<double> p = [] {
        std::vector<double> r(256);
        for (int i = 0; i < 256; i++) {
            double n = (i + 0.5) / 255.0;
            r[i] = (n <= 0.040449936 ? n / 12.92 : std::pow((n + 0.055) / 1.055, 2.4)) * 100.0;
        }
        return r;
    }();
    return p;
}

/* the in-gamut colour of the requested hue and tone nearest the requested chroma */
inline uint32_t bisectToLimit(double y, double targetHue)
{
    /* bisectToSegment */
    Vec3 left = {-1, -1, -1}, right = left;
    double leftHue = 0, rightHue = 0;
    bool initialized = false, uncut = true;
    for (int n = 0; n < 12; n++) {
        Vec3 mid = nthVertex(y, n);
        if (mid[0] < 0)
            continue;
        double midHue = hueOf(mid);
        if (!initialized) {
            left = right = mid;
            leftHue = rightHue = midHue;
            initialized = true;
            continue;
        }
        if (uncut || inCyclicOrder(leftHue, midHue, rightHue)) {
            uncut = false;
            if (inCyclicOrder(leftHue, targetHue, midHue)) {
                right = mid;
                rightHue = midHue;
            } else {
                left = mid;
                leftHue = midHue;
            }
        }
    }
    leftHue = hueOf(left);
    const std::vector<double> &planes = criticalPlanes();
    for (int axis = 0; axis < 3; axis++) {
        if (left[axis] == right[axis])
            continue;
        int lPlane, rPlane;
        if (left[axis] < right[axis]) {
            lPlane = int(std::floor(trueDelinearized(left[axis]) - 0.5));
            rPlane = int(std::ceil(trueDelinearized(right[axis]) - 0.5));
        } else {
            lPlane = int(std::ceil(trueDelinearized(left[axis]) - 0.5));
            rPlane = int(std::floor(trueDelinearized(right[axis]) - 0.5));
        }
        for (int i = 0; i < 8; i++) {
            if (std::abs(rPlane - lPlane) <= 1)
                break;
            int mPlane = int(std::floor((lPlane + rPlane) / 2.0));
            double coord = planes[std::min(255, std::max(0, mPlane))];
            double t = (coord - left[axis]) / (right[axis] - left[axis]);
            Vec3 mid = {left[0] + (right[0] - left[0]) * t, left[1] + (right[1] - left[1]) * t,
                        left[2] + (right[2] - left[2]) * t};
            double midHue = hueOf(mid);
            if (inCyclicOrder(leftHue, targetHue, midHue)) {
                right = mid;
                rPlane = mPlane;
            } else {
                left = mid;
                leftHue = midHue;
                lPlane = mPlane;
            }
        }
    }
    return argbFromLinrgb({(left[0] + right[0]) / 2.0, (left[1] + right[1]) / 2.0, (left[2] + right[2]) / 2.0});
}

/* Hct.from(hue, chroma, tone) as an ARGB integer */
inline uint32_t hctSolve(double hue, double chroma, double tone)
{
    if (chroma < 1.0e-4 || tone < 1.0e-4 || tone > 99.9999) {
        uint32_t c = uint32_t(delinearized(yFromLstar(tone)));
        return 0xFF000000u | (c << 16) | (c << 8) | c;
    }
    double hueRad = sanitizeDegrees(hue) / 180.0 * M_PI;
    double y = yFromLstar(tone);
    uint32_t exact = solveAtJ(hueRad, chroma, y);
    if (exact != 0)
        return exact;
    return bisectToLimit(y, hueRad);
}

inline Hct hctFrom(double hue, double chroma, double tone) { return hctFromArgb(hctSolve(hue, chroma, tone)); }

/* -------------------------------------------------------------------- contrast */

inline double ratioOfYs(double a, double b)
{
    double hi = std::max(a, b), lo = std::min(a, b);
    return (hi + 5.0) / (lo + 5.0);
}
inline double ratioOfTones(double a, double b) { return ratioOfYs(yFromLstar(a), yFromLstar(b)); }

inline double contrastLighter(double tone, double ratio)
{
    if (tone < 0 || tone > 100)
        return -1;
    double dark = yFromLstar(tone);
    double light = (dark + 5.0) * ratio - 5.0;
    if (light < 0 || light > 100)
        return -1;
    double real = ratioOfYs(light, dark);
    if (real < ratio && std::fabs(real - ratio) > 0.04)
        return -1;
    double v = lstarFromY(light) + 0.4;
    return (v < 0 || v > 100) ? -1 : v;
}

inline double contrastDarker(double tone, double ratio)
{
    if (tone < 0 || tone > 100)
        return -1;
    double light = yFromLstar(tone);
    double dark = (light + 5.0) / ratio - 5.0;
    if (dark < 0 || dark > 100)
        return -1;
    double real = ratioOfYs(light, dark);
    if (real < ratio && std::fabs(real - ratio) > 0.04)
        return -1;
    double v = lstarFromY(dark) - 0.4;
    return (v < 0 || v > 100) ? -1 : v;
}

/* DynamicColor.foregroundTone(bgTone, ratio) */
inline double foregroundTone(double bg, double ratio)
{
    double lighter = contrastLighter(bg, ratio);
    if (lighter < 0)
        lighter = 100.0;
    double darker = std::max(0.0, contrastDarker(bg, ratio));
    double lighterRatio = ratioOfTones(lighter, bg);
    double darkerRatio = ratioOfTones(darker, bg);
    if (std::lround(bg) < 60) { /* tonePrefersLightForeground */
        bool negligible = std::fabs(lighterRatio - darkerRatio) < 0.1 && lighterRatio < ratio && darkerRatio < ratio;
        return (lighterRatio >= ratio || lighterRatio >= darkerRatio || negligible) ? lighter : darker;
    }
    return (darkerRatio >= ratio || darkerRatio >= lighterRatio) ? darker : lighter;
}

/* -------------------------------------------------------------- tonal palettes */

struct Tonal {
    double hue = 0, chroma = 0;
    uint32_t get(double tone) const { return hctSolve(hue, chroma, tone); }
};

inline Tonal tonal(double hue, double chroma)
{
    Tonal t;
    t.hue = hue;
    t.chroma = chroma;
    return t;
}

/* "FixedTone(t)" or "MaxChromaTone(t)" of WearTonalPaletteToneConfig */
struct Tone {
    bool fixed;
    double v;
};
struct ToneConfig {
    Tone main, dim, container;
};

/* WearMaterialDynamicColors.findDesiredChromaByTone(hue, chroma, tone, limit) */
inline double findDesiredChromaByTone(double hue, double chroma, double tone, double limit)
{
    if (limit == tone)
        return tone;
    Hct from = hctFrom(hue, chroma, tone);
    if (from.chroma >= chroma || std::fabs(from.chroma - chroma) < 0.4)
        return tone;
    double best = tone, cursor = tone;
    while (from.chroma < chroma) {
        double next = cursor + (limit < tone ? -1.0 : 1.0);
        if ((next < limit && limit < tone) || (next > limit && limit > tone))
            break;
        Hct h2 = hctFrom(hue, chroma, next);
        if (std::fabs(h2.chroma - chroma) < 0.4)
            return next;
        if (std::fabs(h2.chroma - chroma) < std::fabs(from.chroma - chroma)) {
            from = h2;
            best = next;
        }
        cursor = next;
    }
    return best;
}

/* the tone of the highest surface in the dark scheme: surfaceContainerHigh */
static const double kHighestSurfaceTone = 25.0;

inline double mainTone(const Tonal &p, const ToneConfig &c)
{
    if (c.main.fixed)
        return c.main.v;
    return findDesiredChromaByTone(p.hue, p.chroma, c.main.v, foregroundTone(kHighestSurfaceTone, 7.0));
}

inline double dimTone(const Tonal &p, const ToneConfig &c)
{
    if (c.dim.fixed)
        return c.dim.v;
    return findDesiredChromaByTone(p.hue, p.chroma, std::min(mainTone(p, c) - 5.0, c.dim.v),
                                   foregroundTone(kHighestSurfaceTone, 4.5));
}

inline double containerTone(const Tonal &p, const ToneConfig &c)
{
    if (c.container.fixed)
        return c.container.v;
    double minTone = foregroundTone(0.0, 7.0); /* MIN_LIGHT_CONTAINER_TONE */
    if (c.container.v > minTone + 5.0)
        return findDesiredChromaByTone(p.hue, p.chroma, std::min(dimTone(p, c) - 5.0, c.container.v), minTone);
    return 30.0; /* "unsupported tone, using fixed value" */
}

/* ---------------------------------------------------------------------- schemes */

enum Style { Neutral = 0, TonalSpot = 1, Vibrant = 2, Expressive = 3, Content = 6 };

inline double rotatedHue(double hue, const double *hues, const double *rot, int n)
{
    for (int i = 0; i + 1 < n; i++)
        if (hues[i] < hue && hue < hues[i + 1])
            return sanitizeDegrees(hue + rot[i]);
    return hue;
}

inline bool isBlueHue(double hue) { return 250.0 <= hue && hue <= 270.0; }

struct Scheme {
    Tonal primary, secondary, tertiary, neutral, neutralVariant, error;
    ToneConfig pc, sc, tc;
};

static const double kNeutralHues[9] = {0, 41, 61, 101, 131, 181, 250, 270, 360};
static const double kNeutralTertiary[9] = {25, 25, 26, 25, -39, 25, 28, 25, 25};
static const double kSpotHues[6] = {0, 40, 101, 210, 301, 360};
static const double kSpotTertiary[6] = {-32, 32, -32, 32, -32, -32};
static const double kVibrantHues[9] = {0, 41, 61, 101, 131, 181, 251, 301, 360};
static const double kVibrantSecondary[9] = {-14, 0, 355, 357, 0, 3, 10, 331, 331};
static const double kVibrantTertiary[9] = {-72, 55, 45, 50, 55, 50, 62, 303, 303};
static const double kExprHues[9] = {0, 21, 51, 121, 151, 191, 271, 321, 360};
static const double kExprSecondary[9] = {204, 175, 155, 150, 204, 260, 204, 204, 204};
static const double kExprTertiary[9] = {200, 200, 160, 169, 200, 220, 200, 200, 200};
static const double kExprNeutral[9] = {0, 0, 0, 0, 0, 0, 10, 0, 0};
static const double kErrorRanges[9] = {0, 3, 13, 23, 33, 43, 153, 273, 360};
static const double kErrorHues[9] = {12, 22, 32, 12, 22, 32, 22, 12, 12};

inline Tone fixedTone(double t) { return {true, t}; }
inline Tone maxChroma(double t) { return {false, t}; }

/*
 * WearColorScheme(seed, accent, dark = true, style): the seed with CAM16
 * chroma under 5 becomes #1B6EF3 (not for CONTENT). accent (0 = none) is
 * the face accent, used by CONTENT's tertiary palette.
 */
inline Scheme makeScheme(uint32_t seed, uint32_t accent, int style)
{
    Hct seedHct = hctFromArgb(seed);
    uint32_t use = (seed != 0 && (style == Content || seedHct.chroma >= 5.0)) ? seed : 0xFF1B6EF3u;
    Hct h = hctFromArgb(use);
    double hue = h.hue;
    bool blue = isBlueHue(hue);
    Scheme s;
    double errorChroma = 40.0;
    switch (style) {
    case Neutral:
        s.primary = tonal(hue, blue ? 16.0 : 12.0);
        s.secondary = tonal(hue, blue ? 10.0 : 6.0);
        s.tertiary = tonal(rotatedHue(hue, kNeutralHues, kNeutralTertiary, 9), 36.0);
        s.neutral = tonal(hue, 6.0);
        s.neutralVariant = tonal(hue, 6.0);
        errorChroma = 40.0;
        s.pc = {fixedTone(90), fixedTone(85), fixedTone(30)};
        s.sc = {fixedTone(90), fixedTone(85), fixedTone(30)};
        s.tc = {maxChroma(100), maxChroma(100), maxChroma(100)};
        break;
    case TonalSpot:
        s.primary = tonal(hue, 32.0);
        s.secondary = tonal(hue, 16.0);
        s.tertiary = tonal(rotatedHue(hue, kSpotHues, kSpotTertiary, 6), 32.0);
        s.neutral = tonal(hue, 10.0);
        s.neutralVariant = tonal(hue, 10.0);
        errorChroma = 48.0;
        s.pc = {maxChroma(90), maxChroma(90), fixedTone(30)};
        s.sc = {maxChroma(90), maxChroma(90), fixedTone(30)};
        s.tc = {maxChroma(90), maxChroma(90), maxChroma(90)};
        break;
    case Vibrant:
        s.primary = tonal(hue, 48.0);
        s.secondary = tonal(rotatedHue(hue, kVibrantHues, kVibrantSecondary, 9), 36.0);
        s.tertiary = tonal(rotatedHue(hue, kVibrantHues, kVibrantTertiary, 9), 48.0);
        s.neutral = tonal(rotatedHue(hue, kVibrantHues, kVibrantSecondary, 9), blue ? 28.0 : 20.0);
        s.neutralVariant = s.neutral;
        errorChroma = 48.0;
        s.pc = {maxChroma(100), maxChroma(100), fixedTone(30)};
        s.sc = {maxChroma(90), maxChroma(90), fixedTone(30)};
        s.tc = {maxChroma(100), maxChroma(100), maxChroma(100)};
        break;
    case Expressive:
        s.primary = tonal(sanitizeDegrees(hue), 40.0);
        s.secondary = tonal(rotatedHue(hue, kExprHues, kExprSecondary, 9), 24.0);
        s.tertiary = tonal(rotatedHue(hue, kExprHues, kExprTertiary, 9), 48.0);
        s.neutral = tonal(rotatedHue(hue, kExprHues, kExprNeutral, 9), 12.0);
        s.neutralVariant = s.neutral;
        errorChroma = 48.0;
        s.pc = {maxChroma(100), maxChroma(100), fixedTone(30)};
        s.sc = {maxChroma(90), maxChroma(90), fixedTone(30)};
        s.tc = {maxChroma(100), maxChroma(100), maxChroma(100)};
        break;
    default: { /* Content */
        double c = h.chroma;
        s.primary = tonal(hue, c);
        s.secondary = tonal(hue, std::min(36.0, std::max(16.0, c * 0.5)));
        if (accent != 0) {
            Hct a = hctFromArgb(accent);
            s.tertiary = tonal(a.hue, a.chroma);
        } else {
            s.tertiary = tonal(rotatedHue(hue, kSpotHues, kSpotTertiary, 6), c);
        }
        double n = std::min(20.0, std::max(6.0, c * 0.333));
        s.neutral = tonal(hue, n);
        s.neutralVariant = tonal(hue, n);
        errorChroma = std::max(40.0, c);
        s.pc = {maxChroma(100), maxChroma(100), fixedTone(30)};
        s.sc = {maxChroma(90), maxChroma(90), fixedTone(30)};
        s.tc = {maxChroma(100), maxChroma(100), maxChroma(100)};
        break;
    }
    }
    double errorHue = kErrorHues[0];
    for (int i = 0; i < 8; i++)
        if (kErrorRanges[i] < hue && hue < kErrorRanges[i + 1]) {
            errorHue = sanitizeDegrees(kErrorHues[i]);
            break;
        }
    s.error = tonal(errorHue, errorChroma);
    return s;
}

/* ----------------------------------------------------------------------- roles */

inline const char *const *roleNames()
{
    static const char *const names[30] = {
        "primary", "primaryDim", "primaryContainer", "onPrimary", "onPrimaryContainer",
        "secondary", "secondaryDim", "secondaryContainer", "onSecondary", "onSecondaryContainer",
        "tertiary", "tertiaryDim", "tertiaryContainer", "onTertiary", "onTertiaryContainer",
        "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "onSurface", "onSurfaceVariant",
        "outline", "outlineVariant", "background", "onBackground",
        "error", "errorDim", "errorContainer", "onError", "onErrorContainer", nullptr};
    return names;
}

/*
 * The 29 roles (dark scheme, contrast 0) as ARGB, in roleNames() order. Rules
 * (each checked against the static table, which is the NEUTRAL scheme of the
 * seed #9A9EAD, to within a few 8-bit steps of the stock values):
 *   primary / secondary / tertiary          main tone of the palette's config
 *   *Dim                                    dim tone
 *   *Container                              container tone
 *   onPrimary, onSecondary, onTertiary      foregroundTone(dim tone, 7)
 *   on*Container                            foregroundTone(container tone, 7)
 *   surfaceContainerLow / -Container / -High  neutral tones 15 / 20 / 25
 *   onSurface                               neutral, foregroundTone(25, 9)
 *   onSurfaceVariant / outline / outlineVariant   neutral variant,
 *                                           foregroundTone(25, 7 / 4.5 / 3)
 *   background, onBackground                tone 0 and 100 (black, white)
 *   error                                   error palette, foregroundTone(25, 7)
 *   errorDim, errorContainer                error palette tones 68 and 30
 *   onError                                 foregroundTone(68, 7)
 *   onErrorContainer                        foregroundTone(30, 7)
 */
inline std::array<uint32_t, 29> roles(const Scheme &s)
{
    std::array<uint32_t, 29> r{};
    const Tonal *pal[3] = {&s.primary, &s.secondary, &s.tertiary};
    const ToneConfig *cfg[3] = {&s.pc, &s.sc, &s.tc};
    for (int i = 0; i < 3; i++) {
        double main = mainTone(*pal[i], *cfg[i]);
        double dim = dimTone(*pal[i], *cfg[i]);
        double cont = containerTone(*pal[i], *cfg[i]);
        r[i * 5 + 0] = pal[i]->get(main);
        r[i * 5 + 1] = pal[i]->get(dim);
        r[i * 5 + 2] = pal[i]->get(cont);
        r[i * 5 + 3] = pal[i]->get(foregroundTone(dim, 7.0));
        r[i * 5 + 4] = pal[i]->get(foregroundTone(cont, 7.0));
    }
    r[15] = s.neutral.get(15.0);
    r[16] = s.neutral.get(20.0);
    r[17] = s.neutral.get(25.0);
    r[18] = s.neutral.get(foregroundTone(kHighestSurfaceTone, 9.0));
    r[19] = s.neutralVariant.get(foregroundTone(kHighestSurfaceTone, 7.0));
    r[20] = s.neutralVariant.get(foregroundTone(kHighestSurfaceTone, 4.5));
    r[21] = s.neutralVariant.get(foregroundTone(kHighestSurfaceTone, 3.0));
    r[22] = s.neutral.get(0.0);
    r[23] = s.neutral.get(100.0);
    r[24] = s.error.get(foregroundTone(kHighestSurfaceTone, 7.0));
    r[25] = s.error.get(68.0);
    r[26] = s.error.get(30.0);
    r[27] = s.error.get(foregroundTone(68.0, 7.0));
    r[28] = s.error.get(foregroundTone(30.0, 7.0));
    return r;
}

inline std::string hex(uint32_t argb)
{
    char b[8];
    std::snprintf(b, sizeof b, "#%06X", argb & 0xFFFFFFu);
    return b;
}

/* "#RRGGBB" or "RRGGBB" (any case) -> 0xFFRRGGBB, 0 when it is not a colour */
inline uint32_t parseHex(const std::string &s)
{
    size_t i = (!s.empty() && s[0] == '#') ? 1 : 0;
    if (s.size() - i != 6)
        return 0;
    uint32_t v = 0;
    for (size_t k = i; k < s.size(); k++) {
        char c = s[k];
        int d = (c >= '0' && c <= '9') ? c - '0' : (c >= 'a' && c <= 'f') ? c - 'a' + 10 : (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
        if (d < 0)
            return 0;
        v = v * 16 + uint32_t(d);
    }
    return 0xFF000000u | v;
}

} // namespace eosmonet

#endif
