// Ghost Hunt: real 3D first-person view, ray traced per pixel on the GPU.
//
// World: x right, y down (maze rows), z up. One tile = 1 unit.
// The maze lives in a tiny texture (one texel per tile):
//   r = 1 wall, g = 1 pellet / 0.5 power pellet, b = 1 ghost door.
// Walls are traced with a 3D grid walk (exact, can look over walls when
// the camera is high: jump / flight). Pac-Man, ghosts and
// pellets are analytic spheres/cylinders. Pac-Man is the light source: walls,
// floor and ghosts are lit by him, with shadows.

#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;   // canvas size in pixels
uniform vec4 uCam;    // x, y, eye height, yaw
uniform vec4 uView;   // pitch, time, mode (0 hard, 1 hell), heartbeat 0..1
uniform vec4 uPac;    // x, y, facing angle, mouth open 0..1
uniform vec4 uPacFx;  // beam 0/1, frightened 0/1, pac visible 0/1, zoom
uniform vec4 uG0;     // ghost: x, y, facing angle, state (0 none, 1 body, 2 eyes)
uniform vec4 uC0;     // ghost colour rgb, flash 0/1
uniform vec4 uG1;
uniform vec4 uC1;
uniform vec4 uG2;
uniform vec4 uC2;
uniform vec2 uMaze;   // maze width, height in tiles
uniform vec3 uFruit;  // bonus fruit: x, y, visible 0/1
uniform vec3 uFruitC; // fruit colour
uniform sampler2D uTex;

out vec4 fragColor;

const float WALL_H = 0.85;
const float PAC_Z = 0.40;
const float PAC_R = 0.36;
const float FAR = 1e4;

// ---------------------------------------------------------------- helpers

vec4 cellAt(vec2 c) {
  if (c.x < 0.0 || c.y < 0.0 || c.x >= uMaze.x || c.y >= uMaze.y) {
    return vec4(0.0, 0.0, 0.0, -1.0); // outside the maze
  }
  return texture(uTex, (c + 0.5) / uMaze);
}

bool isWall(vec4 c) { return c.r > 0.5; }

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Nearest positive ray/sphere hit, or FAR.
float sphere(vec3 ro, vec3 rd, vec3 c, float r) {
  vec3 oc = ro - c;
  float b = dot(oc, rd);
  float h = b * b - (dot(oc, oc) - r * r);
  if (h < 0.0) return FAR;
  h = sqrt(h);
  float t = -b - h;
  if (t > 0.001) return t;
  return FAR;
}

// Far side of a sphere (for Pac-Man's mouth).
float sphereFar(vec3 ro, vec3 rd, vec3 c, float r) {
  vec3 oc = ro - c;
  float b = dot(oc, rd);
  float h = b * b - (dot(oc, oc) - r * r);
  if (h < 0.0) return FAR;
  float t = -b + sqrt(h);
  return t > 0.001 ? t : FAR;
}

// ------------------------------------------------------------ grid walk

// Returns hit distance; kind: 0 nothing/sky, 1 wall side, 2 wall top,
// 3 floor, 7 dark end of the side tunnel. n = surface normal. pel = nearest pellet hit (t, power?).
float trace(vec3 ro, vec3 rd, out int kind, out vec3 n, out vec2 pel) {
  kind = 0;
  n = vec3(0.0, 0.0, 1.0);
  pel = vec2(FAR, 0.0);

  vec2 c = floor(ro.xy);
  vec2 st = vec2(rd.x >= 0.0 ? 1.0 : -1.0, rd.y >= 0.0 ? 1.0 : -1.0);
  vec2 inv = 1.0 / max(abs(rd.xy), vec2(1e-5));
  vec2 tMax = vec2(
    (rd.x >= 0.0 ? (c.x + 1.0 - ro.x) : (ro.x - c.x)) * inv.x,
    (rd.y >= 0.0 ? (c.y + 1.0 - ro.y) : (ro.y - c.y)) * inv.y);
  float tFloor = rd.z < 0.0 ? -ro.z / rd.z : FAR;
  float tEnter = 0.0;
  float axis = 0.0; // 0 crossed an x boundary, 1 a y boundary

  for (int i = 0; i < 72; i++) {
    float tExit = min(tMax.x, tMax.y);
    vec4 cl = cellAt(c);
    if (cl.a < 0.0) {
      // Below wall height the only way out is the side tunnel: end in the
      // dark instead of showing an endless corridor.
      float zOut = ro.z + rd.z * tEnter;
      if (i > 0 && zOut >= 0.0 && zOut <= WALL_H) {
        kind = 7;
        return tEnter;
      }
      // Left the maze: only the floor (void plane) or sky remain.
      if (tFloor < FAR && ro.z + rd.z * tEnter > 0.0) {
        kind = 3;
        return tFloor;
      }
      return FAR;
    }
    if (isWall(cl)) {
      float zIn = ro.z + rd.z * tEnter;
      // i > 0: when you are inside a wall (phase pack) you see out of it.
      if (i > 0 && zIn <= WALL_H && zIn >= 0.0) {
        kind = 1;
        n = axis < 0.5 ? vec3(-st.x, 0.0, 0.0) : vec3(0.0, -st.y, 0.0);
        return tEnter;
      }
      if (rd.z < 0.0 && ro.z > WALL_H) {
        float tt = (ro.z - WALL_H) / -rd.z;
        if (tt >= tEnter && tt < tExit) {
          kind = 2;
          return tt;
        }
      }
    } else {
      if (cl.g > 0.1) {
        float r = cl.g > 0.75 ? 0.055 : 0.13;
        float tp = sphere(ro, rd, vec3(c + 0.5, 0.30), r);
        if (tp < pel.x) pel = vec2(tp, cl.g > 0.75 ? 0.0 : 1.0);
      }
      if (tFloor >= tEnter && tFloor < tExit) {
        kind = 3;
        return tFloor;
      }
    }
    // Climbing away above every wall: nothing more to hit.
    if (rd.z > 0.0 && ro.z + rd.z * tEnter > WALL_H) return FAR;

    if (tMax.x < tMax.y) {
      tEnter = tMax.x;
      tMax.x += inv.x;
      c.x += st.x;
      axis = 0.0;
    } else {
      tEnter = tMax.y;
      tMax.y += inv.y;
      c.y += st.y;
      axis = 1.0;
    }
  }
  return FAR;
}

// Is the straight line p -> l blocked by a wall? (2D walk, z interpolated)
float shadow(vec3 p, vec3 l) {
  vec3 d = l - p;
  float len = length(d.xy);
  if (len < 0.01) return 1.0;
  vec3 rd = d / len; // parametrised by horizontal distance
  vec2 c = floor(p.xy);
  vec2 st = vec2(rd.x >= 0.0 ? 1.0 : -1.0, rd.y >= 0.0 ? 1.0 : -1.0);
  vec2 inv = 1.0 / max(abs(rd.xy), vec2(1e-5));
  vec2 tMax = vec2(
    (rd.x >= 0.0 ? (c.x + 1.0 - p.x) : (p.x - c.x)) * inv.x,
    (rd.y >= 0.0 ? (c.y + 1.0 - p.y) : (p.y - c.y)) * inv.y);
  for (int i = 0; i < 28; i++) {
    float t = min(tMax.x, tMax.y);
    if (t >= len) return 1.0;
    if (tMax.x < tMax.y) {
      tMax.x += inv.x;
      c.x += st.x;
    } else {
      tMax.y += inv.y;
      c.y += st.y;
    }
    if (isWall(cellAt(c)) && p.z + rd.z * t < WALL_H) return 0.0;
  }
  return 0.0; // too far: dark anyway
}

// ---------------------------------------------------------------- ghosts

// Ghost = dome + wavy skirt + two eyes. state 1 body, 2 eyes only.
float ghost(vec3 ro, vec3 rd, vec4 g, vec4 col, out vec3 n, out vec3 alb,
            out float emit) {
  n = vec3(0.0);
  alb = vec3(0.0);
  emit = 0.0;
  if (g.w < 0.5) return FAR;
  vec3 c = vec3(g.xy, 0.42);
  // Skip rays that pass well clear of it.
  vec3 oc0 = ro - c;
  float ob = dot(oc0, rd);
  if (dot(oc0, oc0) - ob * ob > 0.5) return FAR;
  vec2 f = vec2(cos(g.z), sin(g.z));
  vec2 side = vec2(-f.y, f.x);
  float best = FAR;
  bool frightened = col.r < 0.2 && col.b > 0.9 && col.g < 0.3;

  if (g.w < 1.5) {
    const float R = 0.30;
    // Dome (upper half sphere).
    float t = sphere(ro, rd, c, R);
    if (t < FAR && ro.z + rd.z * t >= c.z) {
      best = t;
      n = normalize(ro + rd * t - c);
    }
    // Skirt: vertical cylinder with a wavy hem.
    vec2 oc = ro.xy - c.xy;
    float a = dot(rd.xy, rd.xy);
    float b = dot(oc, rd.xy);
    float h = b * b - a * (dot(oc, oc) - R * R);
    if (h > 0.0) {
      float tc = (-b - sqrt(h)) / a;
      vec3 p = ro + rd * tc;
      float ang = atan(p.y - c.y, p.x - c.x);
      float hem = 0.07 + 0.05 * sin(ang * 7.0 + uView.y * 9.0);
      if (tc > 0.001 && tc < best && p.z <= c.z && p.z >= hem) {
        best = tc;
        n = normalize(vec3(p.xy - c.xy, 0.0));
      }
    }
    if (best < FAR) {
      alb = col.rgb;
      if (col.a > 0.5) alb = vec3(1.0); // flashing at the end of fright
      emit = 0.25;
    }
  }
  // Eyes (also the only thing left of an eaten ghost).
  for (int k = 0; k < 2; k++) {
    float s = k == 0 ? 1.0 : -1.0;
    vec3 eye = vec3(c.xy + f * 0.22 + side * 0.11 * s, 0.50);
    float te = sphere(ro, rd, eye, frightened ? 0.045 : 0.085);
    if (te < best) {
      best = te;
      n = normalize(ro + rd * te - eye);
      alb = frightened ? vec3(1.0, 0.8, 0.7) : vec3(1.0);
      emit = 0.5;
    }
    if (!frightened) {
      vec3 pup = vec3(eye.xy + f * 0.06, 0.50);
      float tp = sphere(ro, rd, pup, 0.045);
      if (tp < best) {
        best = tp;
        n = normalize(ro + rd * tp - pup);
        alb = vec3(0.1, 0.2, 1.0);
        emit = 0.3;
      }
    }
  }
  return best;
}

// ------------------------------------------------------------------ main

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag - 0.5 * uSize) / uSize.y;
  bool hell = uView.z > 0.5;
  float time = uView.y;
  float beat = uView.w;

  // Camera.
  float yaw = uCam.w, pitch = uView.x;
  vec3 fwd = vec3(cos(yaw) * cos(pitch), sin(yaw) * cos(pitch), sin(pitch));
  vec3 right = normalize(vec3(-sin(yaw), cos(yaw), 0.0));
  vec3 up = cross(fwd, right);
  vec3 ro = uCam.xyz;
  vec3 rd = normalize(fwd * uPacFx.w + right * uv.x - up * uv.y);

  // Palette.
  vec3 wallCol = hell ? vec3(0.22, 0.02, 0.03) : vec3(0.08, 0.05, 0.28);
  vec3 neon = hell ? vec3(1.0, 0.12, 0.05) : vec3(0.40, 0.26, 1.0);
  vec3 fogCol = hell ? vec3(0.05, 0.0, 0.0) : vec3(0.01, 0.01, 0.05);
  vec3 pacCol = uPacFx.y > 0.5 ? vec3(1.0, 0.95, 0.6) : vec3(1.0, 0.85, 0.0);
  float flicker = hell ? 0.75 + 0.25 * step(0.08, hash(vec2(floor(time * 14.0), 3.0))) : 1.0;
  vec3 lightCol = pacCol * (1.6 + 1.4 * beat) * flicker;
  vec3 L = vec3(uPac.xy, PAC_Z);

  // ---- scene geometry
  int kind;
  vec3 n;
  vec2 pel;
  float t = trace(ro, rd, kind, n, pel);
  vec3 alb = vec3(0.0);
  float emit = 0.0;
  bool lit = true;
  bool isPac = false;
  vec3 col;

  // Pellets.
  if (pel.x < t) {
    t = pel.x;
    kind = 4;
    vec3 p = ro + rd * t;
    n = normalize(p - vec3(floor(p.xy) + 0.5, 0.30));
    alb = pel.y > 0.5 ? vec3(1.0, 0.75, 0.7) : vec3(1.0, 0.72, 0.68);
    emit = pel.y > 0.5 ? 0.9 + 0.6 * sin(time * 6.0) : 0.6;
  }

  // Pac-Man: a real sphere with a chomping mouth.
  if (uPacFx.z > 0.5) {
    vec3 pc = vec3(uPac.xy, PAC_Z);
    vec2 f = vec2(cos(uPac.z), sin(uPac.z));
    float mouthA = 0.05 + uPac.w * 0.75;
    for (int k = 0; k < 2; k++) {
      float tp = k == 0 ? sphere(ro, rd, pc, PAC_R) : sphereFar(ro, rd, pc, PAC_R);
      if (tp >= t) break;
      vec3 q = ro + rd * tp - pc;
      float fwdq = dot(q.xy, f);
      bool inMouth = fwdq > 0.0 && abs(atan(q.z, fwdq)) < mouthA;
      if (!inMouth) {
        t = tp;
        isPac = true;
        n = normalize(q);
        if (k == 1) n = -n;
        alb = k == 1 ? vec3(0.5, 0.05, 0.02) : pacCol; // inside of the mouth
        emit = k == 1 ? 0.3 : 1.0;
        kind = 5;
        break;
      }
    }
  }

  // Team-mate ghosts.
  {
    vec3 gn, ga;
    float ge;
    float tg = ghost(ro, rd, uG0, uC0, gn, ga, ge);
    if (tg < t) { t = tg; n = gn; alb = ga; emit = ge; kind = 6; }
    tg = ghost(ro, rd, uG1, uC1, gn, ga, ge);
    if (tg < t) { t = tg; n = gn; alb = ga; emit = ge; kind = 6; }
    tg = ghost(ro, rd, uG2, uC2, gn, ga, ge);
    if (tg < t) { t = tg; n = gn; alb = ga; emit = ge; kind = 6; }
  }

  // Bonus fruit: a bobbing, glowing ball with a little leaf.
  vec3 fruitAt = vec3(uFruit.xy, 0.36 + 0.04 * sin(time * 4.0));
  if (uFruit.z > 0.5) {
    float tf = sphere(ro, rd, fruitAt, 0.17);
    if (tf < t) {
      t = tf; kind = 8; isPac = false;
      n = normalize(ro + rd * tf - fruitAt);
      alb = uFruitC;
      emit = 0.9;
    }
    vec3 leaf = fruitAt + vec3(0.0, 0.0, 0.19);
    tf = sphere(ro, rd, leaf, 0.06);
    if (tf < t) {
      t = tf; kind = 8; isPac = false;
      n = normalize(ro + rd * tf - leaf);
      alb = vec3(0.25, 0.75, 0.3);
      emit = 0.6;
    }
  }

  vec3 p = ro + rd * t;

  if (kind == 0) {
    // Night sky with stars.
    float hgt = clamp(rd.z * 0.5 + 0.5, 0.0, 1.0);
    col = mix(fogCol * 1.5, hell ? vec3(0.0) : vec3(0.0, 0.0, 0.02), hgt);
    vec2 sp = vec2(atan(rd.y, rd.x) * 60.0, rd.z * 90.0);
    vec2 cell = floor(sp);
    float star = step(0.97, hash(cell)) *
        smoothstep(0.12, 0.0, length(fract(sp) - 0.5)) *
        (0.6 + 0.4 * sin(time * 3.0 + hash(cell + 7.0) * 30.0));
    col += star * vec3(0.6) * smoothstep(0.0, 0.3, rd.z) * (hell ? 0.2 : 1.0);
    lit = false;
  } else if (kind == 1) {
    // Wall side: dark panel, neon top and bottom edges, faint seams.
    float u = abs(n.x) > 0.5 ? fract(p.y) : fract(p.x);
    float top = smoothstep(0.05, 0.0, WALL_H - p.z);
    float bot = smoothstep(0.035, 0.0, p.z);
    float seam = smoothstep(0.03, 0.0, abs(u - 0.5) - 0.47);
    float lines = 0.5 + 0.5 * step(0.5, fract(p.z * 6.0));
    alb = wallCol * (0.75 + 0.25 * lines);
    emit = 0.0;
    col = neon * (top * 2.2 + bot * 0.8 + seam * 0.25);
  } else if (kind == 2) {
    // Wall top: glowing neon lid.
    vec2 fr = fract(p.xy);
    vec2 cc = floor(p.xy);
    // Rim where the top meets an open tile.
    float rim = 0.0;
    if (!isWall(cellAt(cc + vec2(1.0, 0.0)))) rim = max(rim, smoothstep(0.08, 0.0, 1.0 - fr.x));
    if (!isWall(cellAt(cc - vec2(1.0, 0.0)))) rim = max(rim, smoothstep(0.08, 0.0, fr.x));
    if (!isWall(cellAt(cc + vec2(0.0, 1.0)))) rim = max(rim, smoothstep(0.08, 0.0, 1.0 - fr.y));
    if (!isWall(cellAt(cc - vec2(0.0, 1.0)))) rim = max(rim, smoothstep(0.08, 0.0, fr.y));
    alb = wallCol * 1.3;
    col = neon * rim * 2.0;
  } else if (kind == 3) {
    // Floor: dark tiles with glowing grid lines, glossy.
    vec2 fr = fract(p.xy);
    float grid = smoothstep(0.03, 0.0, min(min(fr.x, 1.0 - fr.x), min(fr.y, 1.0 - fr.y)));
    bool door = cellAt(floor(p.xy)).b > 0.5;
    alb = hell ? vec3(0.05, 0.02, 0.02) : vec3(0.025, 0.025, 0.06);
    col = neon * grid * 0.18 + (door ? vec3(0.91, 0.77, 0.42) * 0.5 : vec3(0.0));
  } else {
    col = vec3(0.0);
  }

  if (kind != 0) {
    // Ambient + Pac-Man's light with shadows.
    vec3 amb = hell ? vec3(0.03, 0.005, 0.005) : vec3(0.025, 0.03, 0.07);
    vec3 shade = alb * amb * 2.0;
    vec3 tol = L - p;
    float d = length(tol);
    vec3 l = tol / d;
    float diff = max(dot(n, l), 0.0);
    if (isPac) diff = 0.0;
    float att = 1.0 / (1.0 + d * d * 0.09);
    if (diff > 0.0 && att > 0.01) {
      float sh = shadow(p + n * 0.01, L);
      shade += alb * lightCol * diff * att * sh;
      // Glossy floor highlight.
      if (kind == 3) {
        vec3 hv = normalize(l - rd);
        shade += lightCol * pow(max(dot(n, hv), 0.0), 40.0) * att * sh * 0.6;
      }
    }
    // Emissive things glow by themselves; Pac-Man shaded by facing.
    if (isPac) {
      float face = 0.55 + 0.45 * max(dot(n, -rd), 0.0);
      float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
      shade = alb * (1.1 + beat * 0.4) * face + pacCol * rim * 0.6;
    } else {
      shade += alb * emit;
      // Rim light on ghosts so they read in the dark.
      if (kind == 6) shade += alb * pow(1.0 - max(dot(n, -rd), 0.0), 2.0) * 0.5;
    }
    col += shade;

    // Fog.
    float fog = 1.0 - exp(-t * (hell ? 0.16 : 0.07));
    col = mix(col, fogCol, fog);
  }

  // ---- glow volumes (not occluded only if in front of the hit)
  // Halo around Pac-Man (bloom).
  if (uPacFx.z > 0.5) {
    vec3 oc = L - ro;
    float tc = dot(oc, rd);
    if (tc > 0.0 && tc < t + 0.4) {
      float dd = length(oc - rd * tc);
      col += pacCol * exp(-dd * dd * 10.0) * 0.35 * (0.7 + 0.6 * beat) * flicker;
    }
  }
  // Soft glow around the fruit.
  if (uFruit.z > 0.5) {
    vec3 oc = fruitAt - ro;
    float tc = dot(oc, rd);
    if (tc > 0.0 && tc < t + 0.2) {
      float dd = length(oc - rd * tc);
      col += uFruitC * exp(-dd * dd * 18.0) * 0.4;
    }
  }
  // The light beam rising from Pac-Man above the walls (Hard / sonar).
  if (uPacFx.x > 0.5) {
    vec2 oc = uPac.xy - ro.xy;
    float a = max(dot(rd.xy, rd.xy), 1e-5);
    float tc = dot(oc, rd.xy) / a;
    if (tc > 0.0 && tc < t) {
      float dd = length(ro.xy + rd.xy * tc - uPac.xy);
      float z = ro.z + rd.z * tc;
      float hfade = smoothstep(PAC_Z, PAC_Z + 0.4, z) * exp(-max(z - 1.0, 0.0) * 0.12);
      float core = exp(-dd * dd * 120.0);
      float halo = exp(-dd * dd * 6.0) * 0.35;
      float pulse = 0.35 + 0.65 * beat;
      col += pacCol * (core * 1.4 + halo) * hfade * pulse;
    }
  }

  // Vignette, hell grain, tone map.
  float vig = 1.0 - 0.45 * dot(uv, uv);
  col *= vig;
  if (hell) {
    col += (hash(frag + fract(time) * 100.0) - 0.5) * 0.04;
    col *= 0.92 + 0.08 * sin(frag.y * 1.5);
  }
  col = col / (1.0 + col);
  col = pow(max(col, 0.0), vec3(0.85));
  fragColor = vec4(col, 1.0);
}
