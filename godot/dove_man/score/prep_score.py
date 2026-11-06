"""Turn a recorded Dove Man hour (score_*.json from score_recorder.gd) into the compact
voice data the score page draws. Usage: prep_score.py in.json out.json"""
import json, math, sys

src = json.load(open(sys.argv[1]))
T = src["t"]
dt = src["meta"]["sample_s"]
N = len(T)


def r1(x):
    return round(x, 1)


def interp(series, t):
    i = (t - T[0]) / dt
    i0 = max(0, min(N - 1, int(math.floor(i))))
    i1 = min(N - 1, i0 + 1)
    u = i - i0
    a, b = series[i0], series[i1]
    if a is None or b is None or a < 0 or b < 0:
        return a
    return a + (b - a) * max(0.0, min(1.0, u))


voices = []

# Dove Man: the axis. Weight = rocks resting at his feet (the hour's sediment).
rocks = src["dove"]["rocks"]
ev = []
for i in range(1, N):
    d = rocks[i] - rocks[i - 1]
    if d > 0:
        ev.append([T[i], 0, min(1.0, d / 25.0)])
voices.append({"id": "dove", "name": "Dove Man", "group": "dove", "mode": "tone",
               "what": "the axis — a drone that thickens as rock piles up at his feet",
               "r": [0] * N, "w": [r1(min(1.0, x / 1500.0)) for x in rocks], "events": ev})

# Dinosaurs: held tones, pitch = distance from Dove Man, rests when they stand.
for k, d in enumerate(src["dinos"]):
    ev = [[s, r1(interp(d["r"], s)), 1] for s in d["steps"]]
    voices.append({"id": f"dino{k+1}", "name": f"Dinosaur {k+1}", "group": "dino", "mode": "tone",
                   "what": f"{d['h']:.0f} m — tone gliding with its track; silent while it stands",
                   "r": d["r"], "w": [r1(min(1.0, v / 1.9)) for v in d["v"]], "events": ev})

# Boeing: orbit as vibrato.
b = src["boeing"]
ev = []
for i in range(1, len(b["a"])):
    if (b["a"][i - 1] < 0 <= b["a"][i]):
        ev.append([T[i], r1(b["r"][i]), 1])
voices.append({"id": "boeing", "name": "Boeing", "group": "boeing", "mode": "tone",
               "what": "junk satellite — a thin tone close to the mountain, its orbit as vibrato",
               "r": b["r"], "w": [r1(max(0.0, min(1.0, (a - 110) / 50))) for a in b["alt"]],
               "vib": b["a"], "events": ev})

# Godzilla: footfalls, the uneven limp of his walk; weight = how present he is (fade).
g = src["godzilla"]
gr = [x if x >= 0 else None for x in g["r"]]
voices.append({"id": "godzilla", "name": "Godzilla", "group": "godzilla", "mode": "rhythm",
               "what": "three crossings — footfalls in his own limp (22 / 26 of 48), stronger as he comes out of the haze",
               "r": gr, "w": g["fade"], "events": [[s[0], s[1], s[2]] for s in g["steps"]]})

# Mannequins: shuffling steps; falls and risings.
for k, m in enumerate(src["mannequins"]):
    ev = [[s, r1(interp(m["r"], s)), 0.6] for s in m["steps"]]
    grp = "inner" if m["group"] == "inner" else "outer"
    idx = sum(1 for x in src["mannequins"][:k] if x["group"] == m["group"]) + 1
    voices.append({"id": f"{grp}{idx}", "name": f"{'Inner' if grp=='inner' else 'Outer'} mannequin {idx}",
                   "group": grp, "mode": "rhythm",
                   "what": f"{m['h']:.1f} m — one mark per dragged step; × a fall, ⁝ the three heaves of rising",
                   "r": m["r"], "w": [r1(min(1.0, v / max(0.01, max(m['v'])))) for v in m["v"]],
                   "down": m["down"], "falls": m["falls"], "rises": m["rises"], "events": ev})

# Camels: four beats per stride while walking; flight doubles.
for k, c in enumerate(src["camels"]):
    stride = 1.82 * c["h"]
    ev, acc = [], 0.0
    for i in range(1, N):
        acc += c["v"][i] * dt
        while acc >= stride / 4:
            acc -= stride / 4
            ev.append([T[i], r1(c["r"][i]), 1 if c["mood"][i] == "f" else 0.6])
    voices.append({"id": f"camel{k+1}", "name": c["name"].replace("_", " "), "group": "camel", "mode": "rhythm",
                   "what": f"{c['h']:.1f} m — four hoofbeats per stride; rests while grazing, dense when fleeing",
                   "r": c["r"], "w": [r1(min(1.0, v / 3.0)) for v in c["v"]], "mood": c["mood"], "events": ev})

# Birds: every flock a cloud of grains; perched birds are held notes.
fl = src["birds"]["flocks"]
ids = sorted({f[0] for s in fl for f in s})
flocks = {i: {"r": [None] * N, "n": [0] * N, "p": [0] * N} for i in ids}
for i, s in enumerate(fl):
    for f in s:
        flocks[f[0]]["r"][i] = f[2]
        flocks[f[0]]["n"][i] = f[1]
        flocks[f[0]]["p"][i] = f[4]
ev = []
for i in range(0, N, 2):
    for f in fl[i]:
        ev.append([T[i], f[2], f[1], f[4]])
voices.append({"id": "birds", "name": "Flocks", "group": "birds", "mode": "rhythm",
               "what": "grains — one cloud per flock (at most 7 birds), the community growing from 5 to 77",
               "flocks": [{"id": i, **flocks[i]} for i in ids], "count": src["birds"]["count"], "events": ev})

# Cars: a strike, then the crater filling with sand as a decaying tail.
voices.append({"id": "cars", "name": "Falling cars", "group": "cars", "mode": "rhythm",
               "what": "a strike on impact; as tone, the crater's slow refilling (≈3.5 min decay)",
               "fill_s": src["meta"]["crater_fill_s"],
               "events": [[c[0], c[1], 1] for c in src["cars"]]})

out = {"meta": src["meta"], "phases": src["phases"], "t0": T[0], "dt": dt, "n": N,
       "sun": src["env"]["sun_elev"], "fog": src["env"]["fog"], "voices": voices}
json.dump(out, open(sys.argv[2], "w"), separators=(",", ":"))
print("voices", len(voices), "events", sum(len(v.get("events", [])) for v in voices))
