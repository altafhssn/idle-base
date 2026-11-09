#!/usr/bin/env python3
"""Listening files for the owner (docs/polish/audio.md), as MP3 so they play
anywhere (Finder, a phone, a browser):

  sfx_reel.mp3      every sound once, in the order of the doc's table, at its
                    in-game level (Sfx VOLUME_DB / PITCHED_DB + bus level),
                    1 s apart, variants back to back
  music_twice.mp3   the music loop played through twice (listen for the seam
                    at 1:08.6) at its in-game level, then 20 s of the day
                    bed and 20 s of the night bed alone
  <name>.mp3        any extra .wav given with --clip name=path.wav (for
                    example a game recording from Godot's --write-movie)

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python tools/audio/preview.py -- themes/dhaba/audio docs/polish/audio [--clip name=path.wav ...]
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.dont_write_bytecode = True  # no __pycache__ in the project
import measure  # noqa: E402

SR = 22050
# (id, how Sfx plays it): "play" or "pitched"; the doc's order.
REEL = [
    ("sale_chime", "play"), ("sale_chime_2", "play"), ("sale_chime_3", "play"),
    ("bill_whoosh", "play"), ("bill_whoosh_2", "play"),
    ("serve", "play"), ("serve_2", "play"), ("serve_3", "play"),
    ("pop", "pitched"), ("pop", "play"),
    ("horn", "play"), ("horn_truck", "play"), ("horn_auto", "play"), ("bike", "play"),
    ("chai_pour", "play"), ("tandoor_slap", "play"), ("churn", "play"), ("kadai_sizzle", "play"),
    ("egg_crack", "play"), ("handi_bubble", "play"),
    ("tap", "play"), ("button_thunk", "play"), ("deny", "pitched"), ("typewriter", "play"),
    ("marker_pop", "play"), ("reward_count", "pitched"), ("claim", "play"), ("build_done", "play"),
    ("menu_unlock", "play"), ("ready", "play"), ("upgrade", "pitched"), ("angry", "play"),
]


def load(path):
    if path.endswith(".ogg"):
        x, sr = measure.read_ogg(path)
    else:
        x, sr = measure.read_wav(path)
    return x, sr


def to_rate(x, sr, rate):
    if sr == rate:
        return x
    n = int(round(len(x) * rate / sr))
    t = np.linspace(0, len(x) - 1, n)
    return np.stack([np.interp(t, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], axis=1)


def stereo(x):
    return np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x


def write_mp3(path, x, rate):
    import aud
    x = np.ascontiguousarray(np.clip(x, -1, 1).astype(np.float32))
    s = aud.Sound.buffer(x, rate)
    s.write(path, rate=rate, channels=aud.CHANNELS_STEREO, container=aud.CONTAINER_MP3, codec=aud.CODEC_MP3,
            bitrate=128000)
    print(f"[preview] {os.path.basename(path)}  {len(x) / rate:.1f} s  {os.path.getsize(path) / 1024:.0f} KB")


def main(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
    os.makedirs(out, exist_ok=True)
    vol, bus_of, bus_db = measure.sfx_tables()
    src_gd = open(measure.SFX_GD, encoding="utf-8").read()
    pitched = {k: float(v) for k, v in __import__("re").findall(r'"(\w+)"\s*:\s*(-?[\d.]+)',
                                                              measure._dict_block(src_gd, "PITCHED_DB"))}
    db = lambda d: 10 ** (d / 20)
    # ---- reel
    parts = []
    for fid, how in REEL:
        path = os.path.join(src, fid + ".wav")
        if not os.path.exists(path):
            continue
        x, sr = load(path)
        base = __import__("re").sub(r"_\d+$", "", fid)
        bus = bus_of.get(base, "SFX")
        g = (pitched.get(base, -4.0) if how == "pitched" else vol.get(fid, vol.get(base, 0.0))) + bus_db.get(bus, 0.0)
        parts.append(stereo(x) * db(g))
        parts.append(np.zeros((SR, 2)))
    reel = np.concatenate(parts)
    write_mp3(os.path.join(out, "sfx_reel.mp3"), reel, SR)
    # ---- music twice, then the beds
    m, sr = load(os.path.join(src, "music_loop.ogg"))
    mg = db(vol.get("music_loop", 0.0) + bus_db.get("Music", 0.0))
    seq = [np.concatenate([m, m]) * mg]
    for bed in ("amb_day", "amb_night"):
        b, _ = load(os.path.join(src, bed + ".ogg"))
        b = stereo(b) * db(vol.get(bed, 0.0) + bus_db.get("SFX", 0.0))
        reps = int(np.ceil(20 * SR / len(b)))
        seq.append(np.zeros((SR, 2)))
        seq.append(np.tile(b, (reps, 1))[: 20 * SR])
    write_mp3(os.path.join(out, "music_twice.mp3"), np.concatenate(seq), SR)
    # ---- extra clips
    for a in [args[i + 1] for i, v in enumerate(args) if v == "--clip"]:
        name, path = a.split("=", 1)
        x, sr = load(path)
        write_mp3(os.path.join(out, name + ".mp3"), stereo(x), sr if sr in (22050, 44100, 48000) else 44100)


if __name__ == "__main__":
    main(sys.argv)
