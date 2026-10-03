// Single-scattering sky into an equirect HDR map.

let metalSky = #"""
// ---------------------------------------------------------------- sky
// Single-scattering atmosphere (Rayleigh + Mie, Nishita-style ray march) into an equirect HDR map.
struct SkyParams { float3 sunDir; float sunIntensity; float turbidity; float groundAlbedo; int width; int height; int drawSun; float exposure; float pad0; float pad1; };

float2 raySphere(float3 ro, float3 rd, float R) {
    float b = dot(ro, rd), c = dot(ro, ro) - R * R, d = b * b - c;
    if (d < 0.0) return float2(1e9, -1e9);
    d = sqrt(d); return float2(-b - d, -b + d);
}
float3 atmosphere(float3 rd, float3 sunDir, float turb, float sunI) {
    const float Re = 6360e3, Ra = 6420e3, Hr = 7994.0, Hm = 1200.0;
    const float3 betaR = float3(5.8e-6, 13.5e-6, 33.1e-6);
    float3 betaM = float3(21e-6) * turb;
    float3 ro = float3(0, Re + 2.0, 0);
    float2 t = raySphere(ro, rd, Ra);
    float tmax = t.y;
    float2 tg = raySphere(ro, rd, Re);
    if (tg.x > 0.0) tmax = min(tmax, tg.x);
    const int NS = 16, NL = 6;
    float seg = tmax / float(NS), tc = 0.0;
    float3 sumR = 0.0, sumM = 0.0; float odR = 0.0, odM = 0.0;
    float mu = dot(rd, sunDir);
    float phR = 3.0 / (16.0 * 3.14159) * (1.0 + mu * mu);
    float g = 0.76;
    float phM = 3.0 / (8.0 * 3.14159) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
    for (int i = 0; i < NS; i++) {
        float3 p = ro + rd * (tc + seg * 0.5);
        float h = length(p) - Re;
        float hr = exp(-h / Hr) * seg, hm = exp(-h / Hm) * seg;
        odR += hr; odM += hm;
        float2 tl = raySphere(p, sunDir, Ra);
        float segL = tl.y / float(NL), tcl = 0.0, odRL = 0.0, odML = 0.0; bool ok = true;
        for (int j = 0; j < NL; j++) {
            float3 pl = p + sunDir * (tcl + segL * 0.5);
            float hl = length(pl) - Re;
            if (hl < 0.0) { ok = false; break; }
            odRL += exp(-hl / Hr) * segL; odML += exp(-hl / Hm) * segL; tcl += segL;
        }
        if (ok) {
            const float3 betaO = float3(0.65e-6, 1.881e-6, 0.085e-6) * 2.0;   // ozone: keeps horizons blue, not green
            float3 tau = (betaR + betaO) * (odR + odRL) + betaM * 1.1 * (odM + odML);
            float3 att = exp(-tau);
            sumR += att * hr; sumM += att * hm;
        }
        tc += seg;
    }
    return sunI * (sumR * betaR * phR + sumM * betaM * phM);
}
kernel void rf_sky(texture2d<float, access::write> out [[texture(0)]],
                   constant SkyParams &S [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (int(gid.x) >= S.width || int(gid.y) >= S.height) return;
    float u = (float(gid.x) + 0.5) / float(S.width), v = (float(gid.y) + 0.5) / float(S.height);
    float phi = (u - 0.5) * 2.0 * 3.14159265, theta = (0.5 - v) * 3.14159265;   // theta: elevation
    // Equirect convention: u=0.5 looks down -Z, +X at u=0.75.
    float3 rd = float3(sin(phi) * cos(theta), sin(theta), -cos(phi) * cos(theta));
    float3 sd = normalize(S.sunDir);
    float3 col;
    if (rd.y >= 0.0) {
        // Single scattering darkens grazing rays; real horizons stay bright from multiple scattering.
        col = atmosphere(normalize(float3(rd.x, max(rd.y, 0.045), rd.z)), sd, S.turbidity, S.sunIntensity);
        if (S.drawSun == 1) {
            float cosA = dot(rd, sd);
            float disk = smoothstep(0.99996, 0.999985, cosA);
            float3 trans = exp(-(float3(5.8e-6, 13.5e-6, 33.1e-6) * 7994.0 + 21e-6 * S.turbidity * 1200.0) / max(sd.y, 0.03));
            col += disk * trans * S.sunIntensity * 40.0;
        }
    } else {
        // Below the horizon: distant land seen through haze (never a hard brown band).
        float3 horizon = atmosphere(normalize(float3(rd.x, 0.045, rd.z)), sd, S.turbidity, S.sunIntensity);
        float3 land = horizon * float3(0.55, 0.6, 0.5) * S.groundAlbedo;
        col = mix(horizon, land, smoothstep(0.0, 0.35, -rd.y));
    }
    col *= S.exposure;
    out.write(float4(col, 1.0), gid);
}
"""#
