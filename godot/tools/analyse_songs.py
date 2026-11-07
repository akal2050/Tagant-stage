"""TAGANT Animal Karaoke - song analysis.
Reads mono 22.05 kHz wavs, writes data/<song>.json with:
  hop (s), midi (pitch per frame, 0 = no pitch), conf (0-1), rms (0-1), phrases [[start, end], ...]
Pitch: YIN (de Cheveigne & Kawahara 2002), vectorised with numpy FFT.
Usage: python analyse_songs.py <folder_with_an_*.wav> <out_data_folder>
"""
import sys, os, json, wave, glob
import numpy as np

SR = 22050
FRAME = 2048
HOP = 441            # 20 ms
FMIN, FMAX = 70.0, 4000.0
THRESH = 0.15


def read_wav(p):
    w = wave.open(p, 'rb')
    n = w.getnframes(); sw = w.getsampwidth(); raw = w.readframes(n)
    a = np.frombuffer(raw, dtype=np.int16 if sw == 2 else np.int32).astype(np.float32)
    a /= 32768.0 if sw == 2 else 2147483648.0
    return a


def yin(x):
    nfr = 1 + (len(x) - FRAME) // HOP
    W = FRAME // 2
    tmin, tmax = int(SR / FMAX), int(SR / FMIN)
    midi = np.zeros(nfr, np.float32); conf = np.zeros(nfr, np.float32); rms = np.zeros(nfr, np.float32)
    B = 256
    for b0 in range(0, nfr, B):
        idx = np.arange(b0, min(nfr, b0 + B))
        fr = np.stack([x[i * HOP:i * HOP + FRAME] for i in idx])
        rms[idx] = np.sqrt((fr ** 2).mean(1))
        # difference function d(tau) = r(0)_win + r(0)_shift - 2 r(tau)
        F = np.fft.rfft(fr, 2 * FRAME)
        F2 = np.fft.rfft(fr[:, :W], 2 * FRAME)
        corr = np.fft.irfft(F * np.conj(F2), 2 * FRAME)[:, :W]
        cs = np.cumsum(fr ** 2, 1)
        e0 = cs[:, W - 1]
        etau = cs[:, W - 1:W - 1 + W] - np.concatenate([np.zeros((len(idx), 1)), cs[:, :W - 1]], 1)
        d = e0[:, None] + etau - 2 * corr
        d[:, 0] = 0
        cm = np.cumsum(d[:, 1:], 1)
        dp = np.ones_like(d)
        dp[:, 1:] = d[:, 1:] * np.arange(1, W) / np.maximum(cm, 1e-12)
        for k, i in enumerate(idx):
            row = dp[k, tmin:tmax]
            below = np.where(row < THRESH)[0]
            if len(below):
                t = below[0]
                while t + 1 < len(row) and row[t + 1] < row[t]:
                    t += 1
            else:
                t = int(np.argmin(row))
            val = row[t]
            tau = t + tmin
            if 0 < t < len(row) - 1:  # parabolic interpolation
                a, bb, c = row[t - 1], row[t], row[t + 1]
                den = a - 2 * bb + c
                if abs(den) > 1e-9:
                    tau += 0.5 * (a - c) / den
            f = SR / tau
            conf[i] = max(0.0, 1.0 - val)
            midi[i] = 69 + 12 * np.log2(f / 440.0)
    return midi, conf, rms


def phrases(rms, conf):
    db = 20 * np.log10(np.maximum(rms, 1e-6))
    floor = np.percentile(db, 20); top = np.percentile(db, 97)
    th = floor + 0.35 * (top - floor)
    act = db > th
    hop = HOP / SR
    segs = []; s = None
    for i, a in enumerate(act):
        if a and s is None: s = i
        if not a and s is not None: segs.append([s, i]); s = None
    if s is not None: segs.append([s, len(act)])
    merged = []
    for a, b in segs:  # merge gaps < 0.35 s
        if merged and (a - merged[-1][1]) * hop < 0.35: merged[-1][1] = b
        else: merged.append([a, b])
    out = []
    for a, b in merged:
        dur = (b - a) * hop
        if dur < 0.25: continue
        while dur > 6.0:  # split long phrases at 4 s
            n = int(4.0 / hop); out.append([a * hop, (a + n) * hop]); a += n; dur = (b - a) * hop
        if dur >= 0.25: out.append([a * hop, b * hop])
    return [[round(a, 2), round(b, 2)] for a, b in out]


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    for p in sorted(glob.glob(os.path.join(src, 'an_*.wav'))):
        name = os.path.basename(p)[3:-4]
        x = read_wav(p)
        midi, conf, rms = yin(x)
        voiced = (conf > 0.55) & (rms > np.percentile(rms, 35))
        m = np.where(voiced, midi, 0.0)
        # light median smoothing on voiced runs
        sm = m.copy()
        for i in range(2, len(m) - 2):
            w = m[i - 2:i + 3]
            w = w[w > 0]
            if m[i] > 0 and len(w) >= 3: sm[i] = np.median(w)
        rn = rms / max(1e-6, np.percentile(rms, 99.5))
        ph = phrases(rms, conf)
        vm = sm[sm > 0]
        data = {
            'song': name, 'hop': HOP / SR, 'duration': round(len(x) / SR, 2),
            'midi': [round(float(v), 2) for v in sm],
            'conf': [round(float(v), 2) for v in conf],
            'rms': [round(float(min(1.0, v)), 3) for v in rn],
            'phrases': ph,
            'midi_range': [round(float(np.percentile(vm, 5)), 1), round(float(np.percentile(vm, 95)), 1)] if len(vm) else [48, 84],
            'voiced_ratio': round(float((sm > 0).mean()), 3),
        }
        json.dump(data, open(os.path.join(dst, name + '.json'), 'w'), separators=(',', ':'))
        print(f"{name:26s} {data['duration']:6.1f}s voiced={data['voiced_ratio']:.2f} range={data['midi_range']} phrases={len(ph)}")


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
