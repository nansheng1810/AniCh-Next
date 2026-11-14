//!DESC [Sharp Bilinear] (AniCh)
//!HOOK MAIN
//!BIND HOOKED
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!WHEN OUTPUT.w HOOKED.w 1.000 * > OUTPUT.h HOOKED.h 1.000 * > *
//!COMPONENTS 4

// 锐度：1.0 等价普通双线性，数值越大采样点越靠近最近邻
#define SHARPNESS 1.6

vec4 hook() {
    vec2 p = HOOKED_pos * HOOKED_size - 0.5;
    vec2 f = fract(p);
    f = clamp((f - 0.5) * SHARPNESS + 0.5, 0.0, 1.0);
    vec2 pos = (floor(p) + f + 0.5) / HOOKED_size;
    return HOOKED_tex(pos);
}
