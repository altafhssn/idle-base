#!/usr/bin/env python3
"""Measures every sound in themes/dhaba/audio: length, peak, RMS, LUFS-ish loudness,
clipping, clicks at the edges and, for loops, the seam.

Run it with Blender (its bundled Python has numpy, and Blender's `aud` module
decodes the .ogg music and ambience):

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python tools/audio/measure.py -- themes/dhaba/audio [--json out.json] [--svg out_dir]

Plain Python with numpy also works for the .wav files (the .ogg rows then say
"needs Blender").

Columns
  peak      sample peak, dBFS
  rms       RMS of the sounding part (10 ms blocks above -50 dBFS), dBFS
  lufs_i    integrated loudness, BS.1770 K-weighting + gating (long files)
  lufs_m    loudest 400 ms window (momentary max), the fair figure for a
            short sound
  game_m    lufs_m after Sfx's per-sound volume and its bus level, i.e. how
            loud the sound is in the game relative to the others
  phone     how many dB quieter it gets through a small phone speaker
            (phone_speaker()): bass-heavy sounds lose the most
  clip      samples at or above 0.999 full scale
  edge      level of the first / last millisecond (a one-shot that does not
            start and end near silence clicks)
  seam      loops only: the jump across the loop point in units of the
            file's typical sample-to-sample step (1.0 = as smooth as anywhere
            else), and the level difference between the last and the first
            250 ms
"""
import json
import os
import re
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SFX_GD = os.path.join(ROOT, "scripts", "autoload", "sfx.gd")


# ---------------------------------------------------------------- decoding
def read_wav(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        sw = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if sw != 2:
        raise ValueError(f"{path}: {sw * 8}-bit not supported")
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    return x.reshape(-1, ch), sr


def read_ogg(path):
    try:
        import aud  # Blender only
    except ImportError:
        return None, 0
    s = aud.Sound(path)
    sr = int(s.specs[0])
    data = np.asarray(s.data(), dtype=np.float64)
    if data.ndim == 1:
        data = data.reshape(-1, 1)
    return data, sr


# ---------------------------------------------------------------- loudness
def _biquad_response(b, a, w):
    z = np.exp(-1j * w)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def k_weight(x, sr):
    """BS.1770 K-weighting at any sample rate (pyloudnorm's analog-matched
    biquads), applied as a magnitude response in the FFT domain: phase does
    not change a mean-square measure."""
    G, f0, Q = 3.999843853973347, 1681.974450955533, 0.7071752369554196
    K = np.tan(np.pi * f0 / sr)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * f0 / sr)
    a0 = 1 + K / Q + K * K
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    n = len(x)
    nfft = 1 << int(np.ceil(np.log2(max(n, 2) * 2)))
    w = 2 * np.pi * np.fft.rfftfreq(nfft)
    h = _biquad_response(b1, a1, w) * _biquad_response(b2, a2, w)
    out = np.empty_like(x)
    for c in range(x.shape[1]):
        X = np.fft.rfft(x[:, c], nfft)
        out[:, c] = np.fft.irfft(X * h, nfft)[:n]
    return out


def _db(v, floor=-120.0):
    return float(10 * np.log10(v)) if v > 1e-12 else floor


def phone_speaker(x, sr):
    """A small phone speaker, roughly: nothing much below ~400 Hz (2nd-order
    high-pass at 450 Hz, a 4th-order one at 200 Hz), a presence bump near
    3 kHz. Used for the "on a phone" column: a sound that loses much more
    than the others there leans on bass a phone cannot play."""
    n = len(x)
    nf = 1 << int(np.ceil(np.log2(max(n, 2) * 2)))
    f = np.fft.rfftfreq(nf, 1 / sr)
    f[0] = 1e-3
    m = 1 / np.sqrt(1 + (450 / f) ** 4) / np.sqrt(1 + (200 / f) ** 8) * (1 + 0.4 * np.exp(-0.5 * ((f - 3000) / 1200) ** 2))
    out = np.empty_like(x)
    for c in range(x.shape[1]):
        out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], nf) * m, nf)[:n]
    return out


def loudness(x, sr, loop=False):
    """(integrated LUFS, momentary max LUFS). Loops are measured wrapped."""
    if loop:
        x = np.concatenate([x, x[: int(0.4 * sr)]])
    y = k_weight(x, sr)
    ms = np.sum(y * y, axis=1)  # channel sum (all weights 1.0)
    blk = int(0.4 * sr)
    hop = int(0.1 * sr)
    if len(ms) < blk:
        ms = np.concatenate([ms, np.zeros(blk - len(ms))])
    c = np.concatenate([[0.0], np.cumsum(ms)])
    starts = np.arange(0, len(ms) - blk + 1, hop)
    z = (c[starts + blk] - c[starts]) / blk
    lk = -0.691 + 10 * np.log10(np.maximum(z, 1e-12))
    m_max = float(np.max(lk))
    g = z[lk > -70.0]
    if len(g) == 0:
        return -120.0, m_max
    rel = -0.691 + 10 * np.log10(np.mean(g)) - 10.0
    g2 = z[(lk > -70.0) & (lk > rel)]
    return float(-0.691 + 10 * np.log10(np.mean(g2))), m_max


# ---------------------------------------------------------------- measures
def measure(path, loop=False):
    ext = os.path.splitext(path)[1].lower()
    x, sr = (read_ogg(path) if ext == ".ogg" else read_wav(path))
    if x is None:
        return {"file": os.path.basename(path), "error": "needs Blender (aud) to decode"}
    mono = np.mean(x, axis=1)
    n = len(mono)
    peak = float(np.max(np.abs(x)))
    b = max(1, int(0.01 * sr))
    nb = n // b
    blocks = (mono[: nb * b].reshape(nb, b) ** 2).mean(axis=1) if nb else np.array([np.mean(mono ** 2)])
    loud = blocks[blocks > 10 ** (-50 / 10)]
    rms = 10 * np.log10(np.mean(loud)) if len(loud) else -120.0
    lufs_i, lufs_m = loudness(x, sr, loop)
    ph_i, ph_m = loudness(phone_speaker(x, sr), sr, loop)
    ms1 = max(1, int(0.001 * sr))
    r = {
        "file": os.path.basename(path),
        "sr": sr,
        "ch": int(x.shape[1]),
        "len": n / sr,
        "peak": 20 * np.log10(max(peak, 1e-9)),
        "rms": float(rms),
        "lufs_i": lufs_i,
        "lufs_m": lufs_m,
        "phone_loss": (lufs_i - ph_i) if loop else (lufs_m - ph_m),
        "clip": int(np.sum(np.abs(x) >= 0.999)),
        "dc": float(np.mean(mono)),
        "edge_in": 20 * np.log10(max(float(np.max(np.abs(mono[:ms1]))), 1e-9)),
        "edge_out": 20 * np.log10(max(float(np.max(np.abs(mono[-ms1:]))), 1e-9)),
        "bytes": os.path.getsize(path),
    }
    if loop:
        step = np.abs(np.diff(x, axis=0))
        typical = float(np.median(step[step > 0])) if np.any(step > 0) else 1e-9
        p99 = float(np.percentile(step, 99))
        jump = float(np.max(np.abs(x[0] - x[-1])))
        q = int(0.25 * sr)
        lv = lambda s: 10 * np.log10(max(float(np.mean(s ** 2)), 1e-12))
        r["seam_jump"] = jump / typical
        r["seam_jump_p99"] = jump / max(p99, 1e-9)
        r["seam_level_db"] = lv(x[-q:]) - lv(x[:q])
    return r


# ---------------------------------------------------------------- Sfx tables
def _dict_block(src, name):
    """Text between the braces of `const NAME := {...}` (nested braces ok)."""
    m = re.search(r"const\s+" + name + r"\s*:?=\s*\{", src)
    if not m:
        return ""
    depth, i = 1, m.end()
    while i < len(src) and depth:
        depth += {"{": 1, "}": -1}.get(src[i], 0)
        i += 1
    return src[m.end(): i - 1]


def sfx_tables(path=SFX_GD):
    """Per-sound volume, bus of each sound and bus levels, read from sfx.gd."""
    try:
        src = open(path, encoding="utf-8").read()
    except OSError:
        return {}, {}, {}
    src = re.sub(r"#[^\n]*", "", src)
    vol = {k: float(v) for k, v in re.findall(r'"(\w+)"\s*:\s*(-?[\d.]+)', _dict_block(src, "VOLUME_DB"))}
    bus_db = {k: float(v) for k, v in re.findall(r'"(\w+)"\s*:\s*(-?[\d.]+)', _dict_block(src, "BUS_DB"))}
    bus_of = dict(re.findall(r'"(\w+)"\s*:\s*"(\w+)"', _dict_block(src, "BUS_OF")))
    return vol, bus_of, bus_db


def game_level(stem, r, vol, bus_of, bus_db):
    base = re.sub(r"_\d+$", "", stem)
    v = vol.get(stem, vol.get(base, 0.0))
    bus = bus_of.get(stem, bus_of.get(base, "Music" if stem.startswith("music") else "SFX"))
    return r["lufs_m"] + v + bus_db.get(bus, 0.0), bus, v


# ---------------------------------------------------------------- mix design
# Target loudness in the game (LUFS, after Sfx's per-sound volume and the
# bus level): the beds by integrated loudness, everything else by its
# loudest 400 ms. --suggest prints the VOLUME_DB that hits each target.
# play_pitched() ids (PITCHED) are listed separately (Sfx.PITCHED_DB).
TARGETS = {
    # beds (integrated)
    "music_loop": -27.0, "amb_day": -39.0, "amb_night": -37.0,
    # core loop, many a minute
    "sale_chime": -18.0, "bill_whoosh": -26.0, "serve": -20.5, "pop": -19.0,
    # traffic, about 2.5 a minute, partly off screen
    "horn": -22.0, "horn_truck": -21.0, "horn_auto": -23.0, "bike": -23.5,
    # stations (on screen only)
    "chai_pour": -26.0, "tandoor_slap": -26.0, "churn": -26.0, "kadai_sizzle": -26.0,
    "egg_crack": -26.0, "handi_bubble": -26.0,
    # UI
    "tap": -27.0, "button_thunk": -21.0, "typewriter": -37.0, "marker_pop": -19.0, "deny": -21.0,
    # rewards and moments
    "claim": -14.0, "build_done": -12.0, "menu_unlock": -13.0, "ready": -17.0, "upgrade": -18.0,
    # hooks
    "angry": -24.0,
    # world moments, core and feel (docs/polish/audio.md section 3)
    "tv_cheer": -30.0, "baraat_band": -19.0, "dog_bark": -24.0,
}
PITCHED = {"pop": -23.0, "deny": -21.0, "reward_count": -23.0, "upgrade": -21.0}

# ---------------------------------------------------------------- report
LOOPS = ("music_loop", "amb_day", "amb_night")


def main(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    d = args[0] if args and not args[0].startswith("--") else os.path.join(ROOT, "assets", "audio")
    out_json = args[args.index("--json") + 1] if "--json" in args else None
    files = sorted(f for f in os.listdir(d) if f.endswith((".wav", ".ogg")))
    vol, bus_of, bus_db = sfx_tables()
    rows = []
    print("| file | s | ch | Hz | peak | rms | LUFS-I | LUFS-M max | bus | vol | in game | phone loss | clip | edge in/out | KB |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for f in files:
        stem = os.path.splitext(f)[0]
        r = measure(os.path.join(d, f), stem in LOOPS)
        if "error" in r:
            print(f"| {f} | {r['error']} |")
            continue
        g, bus, v = game_level(stem, r, vol, bus_of, bus_db)
        r["game_m"], r["bus"], r["vol"] = g, bus, v
        rows.append(r)
        print(f"| {f} | {r['len']:.2f} | {r['ch']} | {r['sr']} | {r['peak']:.1f} | {r['rms']:.1f} | {r['lufs_i']:.1f} | "
              f"{r['lufs_m']:.1f} | {bus} | {v:+.1f} | {g:.1f} | {r['phone_loss']:.1f} | {r['clip']} | {r['edge_in']:.0f} / {r['edge_out']:.0f} | "
              f"{r['bytes'] / 1024:.0f} |")
    for r in rows:
        if "seam_jump" in r:
            print(f"[seam] {r['file']}: jump {r['seam_jump']:.2f}x typical step ({r['seam_jump_p99']:.2f}x the 99th "
                  f"percentile), level last vs first 250 ms {r['seam_level_db']:+.2f} dB")
    if "--suggest" in args:
        vol_s, pit_s = {}, {}
        for r in rows:
            stem = os.path.splitext(r["file"])[0]
            base = re.sub(r"_\d+$", "", stem)
            bus = bus_of.get(stem, bus_of.get(base, "Music" if stem.startswith("music") else "SFX"))
            got = r["lufs_i"] if stem in LOOPS else r["lufs_m"]
            if base in TARGETS:
                vol_s[stem] = TARGETS[base] - got - bus_db.get(bus, 0.0)
            if stem in PITCHED:
                pit_s[stem] = PITCHED[stem] - got - bus_db.get(bus, 0.0)
        print("[suggest] VOLUME_DB " + ", ".join(f'"{k}": {v:.1f}' for k, v in vol_s.items()))
        print("[suggest] PITCHED_DB " + ", ".join(f'"{k}": {v:.1f}' for k, v in pit_s.items()))
    total = sum(r["bytes"] for r in rows)
    print(f"[total] {len(rows)} files, {total / 1024:.0f} KB source")
    if out_json:
        with open(out_json, "w") as fh:
            json.dump(rows, fh, indent=1)
    return rows


if __name__ == "__main__":
    main(sys.argv)
