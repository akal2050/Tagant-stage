"""TAGANT Animal Karaoke - scientific spectrograms for the lane.
For every songs/<id>.ogg writes spectra/<id>.png: a log-frequency spectrogram (50 Hz - 9 kHz, 256 rows,
40 px per second, dB scaled, 72 dB range) coloured in the TAGANT palette
(oil black -> indigo -> poppy red -> ochre -> salt white), low frequencies at the bottom.
Usage: python spectrogram.py <project folder>
"""
import os, sys, glob, json, subprocess
import numpy as np
from PIL import Image

SR = 22050
NFFT = 2048
PXPS = 40                 # pixels (frames) per second
HOP = SR // PXPS
ROWS = 256
FMIN, FMAX = 50.0, 9000.0
RANGE_DB = 72.0

# TAGANT palette ramp
STOPS = [(0.00, (4, 3, 6)), (0.22, (28, 14, 48)), (0.45, (120, 16, 22)), (0.64, (205, 40, 22)),
         (0.80, (226, 140, 60)), (0.92, (240, 214, 160)), (1.00, (250, 248, 240))]


def ramp(v):
    v = np.clip(v, 0, 1)
    out = np.zeros(v.shape + (3,), np.float32)
    for (a, ca), (b, cb) in zip(STOPS[:-1], STOPS[1:]):
        m = (v >= a) & (v <= b)
        t = ((v - a) / (b - a))[m][:, None]
        out[m] = np.array(ca) * (1 - t) + np.array(cb) * t
    return out.astype(np.uint8)


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0


def main(root):
    out_dir = os.path.join(root, "spectra")
    os.makedirs(out_dir, exist_ok=True)
    freqs = np.fft.rfftfreq(NFFT, 1.0 / SR)
    rows_f = np.geomspace(FMIN, FMAX, ROWS)
    win = np.hanning(NFFT).astype(np.float32)
    for p in sorted(glob.glob(os.path.join(root, "songs", "*.ogg"))):
        sid = os.path.basename(p)[:-4]
        x = decode(p)
        x = np.concatenate([np.zeros(NFFT // 2, np.float32), x, np.zeros(NFFT, np.float32)])
        n = max(1, (len(x) - NFFT) // HOP)
        frames = np.lib.stride_tricks.as_strided(x, (n, NFFT), (x.strides[0] * HOP, x.strides[0]))
        mag = np.abs(np.fft.rfft(frames * win, axis=1))
        # resample linear bins onto log-frequency rows (max of the bins in each row band)
        edges = np.geomspace(FMIN, FMAX, ROWS + 1)
        spec = np.zeros((n, ROWS), np.float32)
        for r in range(ROWS):
            lo, hi = np.searchsorted(freqs, edges[r]), np.searchsorted(freqs, edges[r + 1])
            hi = max(hi, lo + 1)
            spec[:, r] = mag[:, lo:hi].max(axis=1)
        db = 20 * np.log10(spec + 1e-9)
        top = np.percentile(db, 99.7)
        v = (db - (top - RANGE_DB)) / RANGE_DB
        img = ramp(v.T[::-1])          # rows: high frequencies at the top
        Image.fromarray(img, "RGB").save(os.path.join(out_dir, sid + ".png"), optimize=True)
        json.dump({"pxps": PXPS, "rows": ROWS, "fmin": FMIN, "fmax": FMAX, "frames": int(n), "range_db": RANGE_DB},
                  open(os.path.join(out_dir, sid + ".json"), "w"))
        print(f"{sid:26s} {n} frames")


if __name__ == "__main__":
    main(sys.argv[1])
