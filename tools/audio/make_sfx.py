#!/usr/bin/env python3
"""Synthesises every Dhaba Rush sound: the effects, the music loop and the two
ambience beds. No samples and no licences to track: everything is sines,
noise and a little physics (decaying modes, reeds, a reverb made of noise).

Run with Blender (its Python has numpy, and its `aud` module encodes the Ogg
Vorbis music and ambience and the MP3 listening previews):

  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python tools/audio/make_sfx.py -- themes/dhaba/audio [--only a,b] [--preview docs/polish/audio]

Without Blender (plain python3 + numpy) the .wav effects are still written;
the .ogg files are skipped with a note.

Every sound has its own random generator, seeded by its name, so changing one
sound leaves every other file byte-identical. Sounds are 22 050 Hz mono
16-bit .wav (Godot imports them as QOA); the music is 22 050 Hz stereo Ogg
Vorbis and the ambience 22 050 Hz mono Ogg Vorbis (both import as looping
streams, see their .import files).

Musical key: D (Sa = D). The music is in D (Khamaj flavour: D major with a
C natural on the way down); every tonal effect uses notes of D major so a
chime never fights the music.
"""
import os
import sys
import wave
import zlib

import numpy as np

SR = 22050
TAU = 2 * np.pi
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)


# ================================================================ basics
def rng_for(name):
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")))


def n_of(dur):
    return int(round(SR * dur))


def t_axis(dur):
    return np.arange(n_of(dur)) / SR


def note(m):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((m - 69) / 12)


def env(n, attack=0.005, decay=None):
    """Linear attack, then exponential decay (time constant in s) or hold."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a if decay is None else a * np.exp(-t / decay)


def ramp_env(n, attack, release, hold_end=None):
    """Attack ramp, flat, linear release over the last `release` s."""
    e = np.ones(n)
    a = max(1, n_of(attack))
    e[:a] = np.linspace(0, 1, a)
    r = max(1, min(n, n_of(release)))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def end_fade(x, dur=0.012):
    """Raised-cosine fade over the last `dur` s: a clip cut while it still
    rings would click where it stops."""
    n = min(len(x), max(1, n_of(dur)))
    x[-n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


def modes(f0, dur, parts, attack=0.002, rng=None, glide=0.0, glide_t=0.02):
    """Sum of exponentially decaying sines (struck objects, drums, bells).
    parts = [(frequency ratio, amplitude, decay time constant s)]. `glide`
    starts the pitch that much sharp and lets it settle (drum skins)."""
    t = t_axis(dur)
    out = np.zeros(len(t))
    bend = 1 + glide * np.exp(-t / glide_t) if glide else None
    for ratio, amp, dec in parts:
        f = f0 * ratio
        if f > SR * 0.45:
            continue
        ph0 = rng.uniform(0, TAU) if rng is not None else 0.0
        ph = (TAU * np.cumsum(f * bend) / SR if bend is not None else TAU * f * t) + ph0
        out += amp * np.sin(ph) * np.exp(-t / dec)
    return end_fade(out * np.clip(t / max(attack, 1e-4), 0, 1), min(0.02, dur * 0.2))


def sweep(f0, f1, dur, decay=0.1, attack=0.003, kind="sine"):
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = TAU * np.cumsum(f) / SR
    w = np.sin(ph) if kind == "sine" else 2 / np.pi * np.arcsin(np.sin(ph))
    return end_fade(w * env(len(t), attack, decay), min(0.015, dur * 0.2))


def spectrum_mask(n, lo=None, hi=None, tilt=0.0, peaks=()):
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-3
    m = np.ones_like(f)
    if lo:
        m /= np.sqrt(1 + (lo / f) ** 4)
    if hi:
        m /= np.sqrt(1 + (f / hi) ** 4)
    if tilt:
        m *= (f / 1000.0) ** (tilt / 6.02)
    for fc, gain_db, bw in peaks:
        m *= 1 + (10 ** (gain_db / 20) - 1) * np.exp(-0.5 * ((f - fc) / bw) ** 2)
    return m


def shaped_noise(n, rng, lo=None, hi=None, tilt=0.0, peaks=()):
    """Gaussian noise, band-limited in the FFT domain (circular, so a full
    loop of it wraps seamlessly), normalised to unit RMS."""
    x = rng.standard_normal(max(n, 2))
    y = np.fft.irfft(np.fft.rfft(x) * spectrum_mask(len(x), lo, hi, tilt, peaks), len(x))
    return (y / (np.std(y) + 1e-12))[:n]


def fft_filter(x, lo=None, hi=None, tilt=0.0, peaks=()):
    """Zero-phase EQ of a whole clip (pads to avoid wrap on one-shots)."""
    n = len(x)
    pad = n + n_of(0.05)
    X = np.fft.rfft(x, pad)
    return np.fft.irfft(X * spectrum_mask(pad, lo, hi, tilt, peaks), pad)[:n]


def conv(x, h):
    n = len(x) + len(h) - 1
    nf = 1 << int(np.ceil(np.log2(max(n, 2))))
    return np.fft.irfft(np.fft.rfft(x, nf) * np.fft.rfft(h, nf), nf)[:n]


def reverb_ir(rt60, rng, pre=0.012, bright=0.5, length=None):
    """Noise reverb: a dark tail plus a brighter one that dies sooner, a few
    early reflections; unit energy."""
    n = n_of(length or rt60 * 1.1)
    t = np.arange(n) / SR
    dark = shaped_noise(n, rng, 120, 2800) * np.exp(-6.91 * t / rt60)
    lite = shaped_noise(n, rng, 600, 7000) * np.exp(-6.91 * t / (rt60 * 0.4)) * bright
    ir = dark + lite
    p = n_of(pre)
    ir = np.concatenate([np.zeros(p), ir])[:n]
    for d, g in ((0.007, 0.5), (0.013, -0.35), (0.021, 0.3), (0.034, -0.2)):
        ir[n_of(pre + d)] += g * 4
    return ir / np.sqrt(np.sum(ir ** 2))


def room(x, rng, rt60=0.5, mix=0.2, pre=0.008, bright=0.5):
    """One-shot through a small room: the clip grows by the tail."""
    ir = reverb_ir(rt60, rng, pre, bright)
    wet = conv(x, ir)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry + mix * wet * (np.sqrt(np.mean(x ** 2)) / (np.sqrt(np.mean(wet ** 2)) + 1e-12))


def place(buf, clip, at, gain=1.0):
    i = n_of(at)
    j = min(len(buf), i + len(clip))
    if j > i:
        buf[i:j] += clip[: j - i] * gain
    return buf


def mix(dur, parts):
    buf = np.zeros(n_of(dur))
    for clip, at, gain in parts:
        place(buf, clip, at, gain)
    return buf


def tidy(x, fade_in=0.0008, fade_out=0.012, floor_db=-56.0):
    """Trim the silent tail, then short fades so no one-shot clicks."""
    x = np.asarray(x, dtype=np.float64)
    pk = np.max(np.abs(x)) or 1.0
    above = np.nonzero(np.abs(x) > pk * 10 ** (floor_db / 20))[0]
    if len(above):
        x = x[: min(len(x), above[-1] + n_of(0.01))]
    a = min(len(x), max(1, n_of(fade_in)))
    x[:a] *= np.linspace(0, 1, a)
    r = min(len(x), max(1, n_of(fade_out)))
    x[-r:] *= np.linspace(1, 0, r) ** 2
    return x


def write_wav(path, data, peak_db=-3.0, channels=1):
    data = np.asarray(data, dtype=np.float64)
    m = np.max(np.abs(data)) or 1.0
    data = data / m * 10 ** (peak_db / 20)
    pcm = (np.clip(data, -1, 1) * 32767).round().astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"[sfx] {os.path.basename(path):<20} {len(data) / SR / channels:6.2f}s  {os.path.getsize(path) / 1024:6.1f} KB")


MASTERS = None  # --masters DIR: also keep the loops as 16-bit .wav (analysis, previews)


def encode(path, data, kbps, codec="vorbis"):
    """Ogg Vorbis (or MP3 for previews) through Blender's aud. Returns False
    outside Blender."""
    if MASTERS and codec == "vorbis":
        os.makedirs(MASTERS, exist_ok=True)
        d2 = np.asarray(data, dtype=np.float64)
        write_wav(os.path.join(MASTERS, os.path.splitext(os.path.basename(path))[0] + ".wav"),
                  d2.reshape(-1), 20 * np.log10(np.max(np.abs(d2))), d2.shape[1] if d2.ndim == 2 else 1)
    try:
        import aud
    except ImportError:
        print(f"[sfx] {os.path.basename(path)}: skipped (run with Blender to encode)")
        return False
    data = np.asarray(data, dtype=np.float32)
    if data.ndim == 1:
        data = data.reshape(-1, 1)
    ch = aud.CHANNELS_STEREO if data.shape[1] == 2 else aud.CHANNELS_MONO
    s = aud.Sound.buffer(np.ascontiguousarray(data), SR)
    if codec == "vorbis":
        s.write(path, rate=SR, channels=ch, container=aud.CONTAINER_OGG, codec=aud.CODEC_VORBIS,
                bitrate=int(kbps * 1000))
    else:
        s.write(path, rate=SR, channels=ch, container=aud.CONTAINER_MP3, codec=aud.CODEC_MP3,
                bitrate=int(kbps * 1000))
    print(f"[sfx] {os.path.basename(path):<20} {len(data) / SR:6.2f}s  {os.path.getsize(path) / 1024:6.1f} KB "
          f"({data.shape[1]} ch, {codec} ~{kbps} kbps)")
    return True


# ================================================================ instruments
def bell(f, dur, decay, rng=None):
    """Small brass bell: fundamental, octave and two inharmonic partials."""
    return modes(f, dur, [(1, 1.0, decay), (2.0, 0.15, decay * 0.6), (2.76, 0.35, decay * 0.4),
                          (5.4, 0.12, decay * 0.2)], 0.0015, rng)


def coin(rng):
    f = rng.uniform(2700, 3500)
    c = modes(f, 0.22, [(1, 1.0, rng.uniform(0.05, 0.08)), (1.48, 0.55, 0.045), (2.03, 0.3, 0.03),
                        (2.69, 0.18, 0.02)], 0.0004, rng)
    c += 0.12 * shaped_noise(len(c), rng, 3000, 9000) * env(len(c), 0.0003, 0.003)
    return c


def wood(f, dur, rng, decay=0.03, glide=0.06, click=0.4):
    """Wood block / box knock: three decaying modes, a short pitch settle and
    a filtered click."""
    w = modes(f, dur, [(1, 1.0, decay), (2.57, 0.45, decay * 0.45), (4.1, 0.18, decay * 0.25)], 0.0006, rng,
              glide=glide, glide_t=0.008)
    w += click * 0.3 * shaped_noise(len(w), rng, 700, 4500) * env(len(w), 0.0003, 0.003)
    return w


def reed(midi, dur, rng, attack=0.09, release=0.22, detune_cents=0.0, bright=1.0, swell=0.0, fmax=5200.0):
    """Harmonium reed: rich harmonics under a nasal formant near 1.1 kHz,
    rolled off above ~2.5 kHz; random harmonic phases; optional bellows
    swell (a slow rise and fall over the note)."""
    f0 = note(midi) * 2 ** (detune_cents / 1200)
    n = n_of(dur + release)
    t = np.arange(n) / SR
    out = np.zeros(n)
    k = 1
    while f0 * k < min(fmax, SR * 0.45):
        fk = f0 * k
        a = k ** -0.75 * (1 + 0.7 * np.exp(-0.5 * ((fk - 1100) / 450) ** 2)) / (1 + (fk / (2500 * bright)) ** 2)
        if a > 0.004:
            out += a * np.sin(TAU * fk * t + rng.uniform(0, TAU))
        k += 1
    e = np.ones(n)
    na = n_of(attack)
    e[:na] = (np.linspace(0, 1, na)) ** 1.5
    nr = n_of(release)
    e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    if swell:
        e *= 1 - swell + swell * np.sin(np.pi * np.clip(t / max(dur, 1e-3), 0, 1)) ** 0.7
    return out * e * 0.35


def santoor(midi, rng, vel=1.0, dur=3.0):
    """Hammered strings: two strings per note a hair apart, slightly stiff
    (sharp upper partials), bright attack that mellows."""
    f0 = note(midi)
    out = np.zeros(n_of(dur))
    t = np.arange(len(out)) / SR
    for cents in (-1.3, 1.1):
        f = f0 * 2 ** (cents / 1200)
        for k in range(1, 10):
            fk = k * f * np.sqrt(1 + 0.00025 * k * k)
            if fk > SR * 0.45:
                break
            a = vel * k ** -1.1 * np.exp(-k / 5.5)
            tau = 1.7 / (1 + 0.5 * k)
            out += a * np.sin(TAU * fk * t + rng.uniform(0, TAU)) * np.exp(-t / tau)
    out *= np.clip(t / 0.0015, 0, 1)
    out += 0.08 * vel * shaped_noise(len(out), rng, 1800, 6500) * env(len(out), 0.0003, 0.004)
    return end_fade(out * 0.5, min(0.25, dur * 0.25))


# ---------------------------------------------------------------- tabla
SA = note(62)  # D4: the dayan is tuned to Sa


def dayan(kind, rng, vel=1.0):
    """Treble drum. na: rim stroke, bright and ringing; tin: open, round;
    ti / ra / ki / ta: closed, short."""
    if kind == "na":
        parts = [(1, 0.55, 0.30), (2, 1.0, 0.22), (3, 0.65, 0.15), (4, 0.4, 0.1), (5, 0.25, 0.07)]
        click, dur = 0.25, 1.2
    elif kind == "tin":
        parts = [(1, 1.0, 0.40), (2, 0.35, 0.18), (3, 0.14, 0.09)]
        click, dur = 0.15, 1.4
    else:  # ti, ra, ki, ta: damped
        parts = [(1, 0.8, 0.045), (2, 0.5, 0.035), (3, 0.3, 0.025)]
        click, dur = 0.35, 0.25
    d = modes(SA * rng.uniform(0.997, 1.003), dur, [(r * (1 + 0.004 * (r - 1)), a, dec) for r, a, dec in parts],
              0.0007, rng, glide=0.02, glide_t=0.015)
    d += click * 0.3 * shaped_noise(len(d), rng, 1500, 7000) * env(len(d), 0.0003, 0.0035)
    return d * vel


def bayan(kind, rng, vel=1.0):
    """Bass drum. ge: resonant with the palm's upward pitch bend; ka: flat
    slap, no ring."""
    if kind == "ge":
        dur = 1.1
        t = t_axis(dur)
        f = 82 * (1 + rng.uniform(0.18, 0.32) * (1 - np.exp(-t / 0.12)))
        ph = TAU * np.cumsum(f) / SR
        g = (np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.18 * np.sin(3 * ph) + 0.06 * np.sin(4 * ph)) * env(len(t), 0.002, 0.28)
        g += 0.25 * shaped_noise(len(g), rng, 60, 500) * env(len(g), 0.0005, 0.008)
        return end_fade(g * vel, 0.05)
    # ka: flat slap
    k = modes(125, 0.08, [(1, 1.0, 0.018), (2.3, 0.3, 0.01)], 0.0006, rng)
    k += 0.5 * shaped_noise(len(k), rng, 120, 900) * env(len(k), 0.0003, 0.01)
    return k * vel * 0.6


def bol(name, rng, vel=1.0):
    """A tabla syllable as left + right hand."""
    if name == "dha":
        return mix(1.2, [(dayan("na", rng, vel), 0, 1.0), (bayan("ge", rng, vel), 0, 0.9)])
    if name == "dhi":
        return mix(1.4, [(dayan("tin", rng, vel), 0, 1.0), (bayan("ge", rng, vel), 0, 0.9)])
    if name == "ge":
        return bayan("ge", rng, vel)
    if name == "ka":
        return bayan("ka", rng, vel)
    return dayan(name, rng, vel)  # na, tin, ti, ra, ki, ta


# ================================================================ effects
def swoosh(dur, lp_lo, lp_hi, flutter_hz, rng):
    """Noise through a one-pole low-pass whose cutoff opens then closes
    (paper, air, liquid swish)."""
    n = n_of(dur)
    t = np.arange(n) / SR
    raw = rng.uniform(-1, 1, n)
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1))
    lp = lp_lo + (lp_hi - lp_lo) * shape ** 2
    out = np.zeros(n)
    acc = 0.0
    slow = 0.0
    for i in range(n):
        acc += lp[i] * (raw[i] - acc)
        slow += 0.01 * (acc - slow)
        out[i] = acc - slow
    amp = shape ** 1.5
    if flutter_hz > 0:
        amp = amp * (0.65 + 0.35 * np.sin(TAU * flutter_hz * t))
    return out * amp


def horn_voice(freqs, dur, rng, formant=1800.0, droop=0.012, attack=0.012, release=0.05, fmax=6000.0):
    """Electric / air horn: buzzy harmonic stack under one formant, the
    pitch settling from a touch sharp."""
    t = t_axis(dur)
    out = np.zeros(len(t))
    for f in freqs:
        fb = f * (1 + droop * np.exp(-t / 0.05))
        ph = TAU * np.cumsum(fb) / SR + rng.uniform(0, TAU)
        for k in range(1, 30):
            fk = f * k
            if fk > fmax:
                break
            a = k ** -0.9 * (1 + 1.6 * np.exp(-0.5 * ((fk - formant) / (formant * 0.35)) ** 2)) / (1 + (fk / 3500) ** 2)
            out += a * np.sin(k * ph)
    return out * ramp_env(len(t), attack, release)


def far(x, rng, hi=3200.0, rt60=0.7, mix_=0.3):
    """Push a sound back: darker, a little room."""
    return room(fft_filter(x, lo=140, hi=hi), rng, rt60, mix_, 0.015, 0.3)


# ---- the sale (galla): box clack + coins + the two-bell ding
def sale_chime(rng, bells):
    clack = wood(rng.uniform(600, 700), 0.09, rng, 0.016, 0.03, 0.8)
    parts = [(clack, 0.0, 0.55)]
    at = 0.012
    for _ in range(int(rng.integers(2, 4))):
        parts.append((coin(rng), at, 0.32 * rng.uniform(0.7, 1.0)))
        at += rng.uniform(0.025, 0.05)
    for i, (m, t0) in enumerate(bells):
        parts.append((bell(note(m), 0.6, 0.16 if i == len(bells) - 1 else 0.12, rng), t0, 0.8 if i == 0 else 1.0))
    return mix(0.75, parts)


# ---- a dish lands on the table: thali thud + steel ring + a soft ting
def serve(rng, ting, steel):
    thud = modes(rng.uniform(170, 210), 0.12, [(1, 1.0, 0.03), (1.6, 0.4, 0.018)], 0.001, rng)
    thud += 0.3 * shaped_noise(len(thud), rng, 80, 1200) * env(len(thud), 0.0005, 0.008)
    plate = modes(steel, 0.4, [(1, 1.0, 0.09), (1.72, 0.6, 0.065), (2.51, 0.35, 0.045), (3.33, 0.2, 0.03)], 0.0008, rng)
    return mix(0.45, [(thud, 0.0, 0.8), (plate, 0.002, 0.3), (bell(note(ting), 0.35, 0.085, rng), 0.008, 0.45)])


def sfx_defs():
    """name -> (builder(rng), peak dBFS). Builders take the sound's own rng."""
    d = {}

    # ---------------- core loop
    d["sale_chime"] = (lambda r: sale_chime(r, [(88, 0.0), (95, 0.06)]), -3.0)      # E6 -> B6 (the original pair)
    d["sale_chime_2"] = (lambda r: sale_chime(r, [(86, 0.0), (93, 0.06)]), -3.0)    # D6 -> A6
    d["sale_chime_3"] = (lambda r: sale_chime(r, [(88, 0.0), (93, 0.055)]), -3.0)   # E6 -> A6
    d["bill_whoosh"] = (lambda r: swoosh(0.34, 0.05, 0.5, 34.0, r), -4.0)
    d["bill_whoosh_2"] = (lambda r: swoosh(0.30, 0.05, 0.45, 41.0, r), -4.0)
    d["serve"] = (lambda r: serve(r, 100, 1150), -3.0)      # E7 ting (the original's pitch)
    d["serve_2"] = (lambda r: serve(r, 98, 1020), -3.0)     # D7
    d["serve_3"] = (lambda r: serve(r, 102, 1260), -3.0)    # F#7
    d["pop"] = (lambda r: mix(0.1, [(sweep(380, 950, 0.09, 0.035), 0, 1.0),
                                   (modes(520, 0.05, [(1, 1, 0.01)], 0.0005, r), 0, 0.25)]), -3.0)

    # ---------------- traffic (Sfx picks one per horn: car, lorry, auto, bike)
    def car(r):
        honk = horn_voice([415, 523], 0.15, r, 1900, 0.01, 0.008, 0.035)
        return far(mix(0.5, [(honk, 0.0, 1.0), (honk * 0.9, 0.22, 1.0)]), r, 3400, 0.6, 0.28)

    def truck(r):
        a = horn_voice([note(57), note(61)], 0.42, r, 1100, 0.02, 0.02, 0.06)  # A3 + C#4
        b = horn_voice([note(54), note(57)], 0.62, r, 1000, 0.015, 0.02, 0.22)  # F#3 + A3
        return far(mix(1.1, [(a, 0.0, 1.0), (b, 0.40, 1.0)]), r, 2600, 1.0, 0.32)

    def auto(r):
        def squeeze():
            t = t_axis(0.16)
            f = 360 * (1 + 0.22 * (1 - np.exp(-t / 0.025)) - 0.18 * np.clip((t - 0.11) / 0.05, 0, 1))
            ph = TAU * np.cumsum(f) / SR
            w = sum(np.sin(k * ph) * k ** -0.8 * (1 + 2.0 * np.exp(-0.5 * ((k * 360 - 1400) / 450) ** 2))
                    for k in range(1, 14))
            return w * ramp_env(len(t), 0.012, 0.04)
        return far(mix(0.45, [(squeeze(), 0.0, 1.0), (squeeze(), 0.22, 0.9)]), r, 3600, 0.5, 0.25)

    def bike(r):
        beep = horn_voice([620], 0.12, r, 2200, 0.0, 0.006, 0.03, 4500)
        return far(mix(0.32, [(beep, 0.0, 1.0), (beep, 0.17, 1.0)]), r, 4000, 0.45, 0.22)

    d["horn"] = (car, -3.0)
    d["horn_truck"] = (truck, -3.0)
    d["horn_auto"] = (auto, -3.0)
    d["bike"] = (bike, -3.0)

    # ---------------- stations (a cook starts an order, station on screen)
    def chai_pour(r):
        dur = 0.85
        n = n_of(dur)
        t = np.arange(n) / SR
        flutter = fft_filter(r.standard_normal(n), hi=30.0)
        flutter = 0.6 + 0.4 * flutter / (np.max(np.abs(flutter)) + 1e-9)
        stream = shaped_noise(n, r, 450, 2400, peaks=((900, 4, 300),)) * flutter
        stream *= ramp_env(n, 0.03, 0.18) * np.clip((0.7 - t) / 0.1, 0, 1) ** 0.5
        parts = [(stream, 0.0, 0.16)]
        for i in range(16):
            at = r.uniform(0.04, 0.66)
            f = (650 + 800 * (at / 0.66) ** 0.8) * r.uniform(0.9, 1.1)
            parts.append((sweep(f, f * 1.18, 0.035, 0.012), at, r.uniform(0.25, 0.5)))
        parts.append((modes(2950, 0.2, [(1, 1.0, 0.05), (2.32, 0.4, 0.025)], 0.0005, r), 0.72, 0.18))
        return mix(dur + 0.2, parts)

    def tandoor_slap(r):
        slap = shaped_noise(n_of(0.12), r, 160, 1700) * env(n_of(0.12), 0.0008, 0.02)
        slap += 1.4 * modes(150, 0.12, [(1, 1.0, 0.035), (2.1, 0.4, 0.018)], 0.0008, r)
        fire_n = n_of(0.5)
        fire = shaped_noise(fire_n, r, 70, 800) * np.sin(np.pi * np.linspace(0, 1, fire_n)) ** 1.5
        parts = [(slap, 0.0, 0.5), (fire, 0.04, 0.09)]
        for _ in range(5):
            pop = shaped_noise(n_of(0.02), r, 1800, 6000) * env(n_of(0.02), 0.0002, 0.002)
            parts.append((pop, r.uniform(0.08, 0.45), r.uniform(0.05, 0.12)))
        return mix(0.6, parts)

    def churn(r):
        knock = modes(310, 0.1, [(1, 1.0, 0.03), (2.2, 0.35, 0.015), (3.6, 0.15, 0.008)], 0.0006, r)
        knock += 0.2 * shaped_noise(len(knock), r, 300, 2500) * env(len(knock), 0.0003, 0.004)
        return mix(0.55, [(fft_filter(swoosh(0.17, 0.04, 0.26, 0.0, r), hi=2200), 0.0, 1.0), (knock, 0.14, 0.45),
                          (fft_filter(swoosh(0.17, 0.04, 0.22, 0.0, r), hi=2000), 0.23, 0.85), (knock, 0.37, 0.35)])

    def kadai_sizzle(r):
        n = n_of(0.65)
        crackle = np.zeros(n)
        for _ in range(60):
            i = int(r.integers(0, n - 40))
            crackle[i] += r.uniform(0.3, 1.0) * r.choice([-1, 1])
        crackle = fft_filter(crackle, lo=1500, hi=7000)
        bed = shaped_noise(n, r, 2600, 8500) * (0.5 + 0.5 * np.abs(fft_filter(r.standard_normal(n), hi=40)))
        sizz = (bed * 0.5 + crackle * 6) * env(n, 0.015, 0.3)
        clink = modes(1650, 0.18, [(1, 1.0, 0.05), (2.7, 0.5, 0.03), (4.1, 0.3, 0.02)], 0.0004, r)
        return mix(0.7, [(sizz, 0.0, 0.5), (clink, 0.05, 0.3), (clink * 0.8, 0.31, 0.25)])

    def egg_crack(r):
        crack = np.zeros(n_of(0.05))
        for at in (0.0, 0.007, 0.018):
            place(crack, shaped_noise(n_of(0.012), r, 1200, 8000) * env(n_of(0.012), 0.0002, 0.0018), at,
                  r.uniform(0.6, 1.0))
        crack += 0.4 * modes(2200, 0.05, [(1, 1, 0.008)], 0.0003, r)
        n = n_of(0.45)
        sizz = shaped_noise(n, r, 2400, 8000) * np.minimum(1, np.arange(n) / n_of(0.03)) * np.exp(-np.arange(n) / n_of(0.17))
        return mix(0.55, [(crack, 0.0, 1.0), (sizz, 0.05, 0.22)])

    def handi_bubble(r):
        def blub(f):
            b = sweep(f, f * 1.7, 0.07, 0.03) + 0.35 * sweep(2 * f, 3.4 * f, 0.07, 0.025)
            b = mix(0.09, [(b, 0, 1.0), (shaped_noise(n_of(0.01), r, 800, 3000) * env(n_of(0.01), 0.0002, 0.002), 0.062, 0.12)])
            return b
        n = n_of(0.55)
        simmer = shaped_noise(n, r, 90, 500) * ramp_env(n, 0.05, 0.2)
        return mix(0.55, [(simmer, 0.0, 0.05), (blub(290), 0.0, 1.0), (blub(350), 0.14, 0.75), (blub(260), 0.29, 0.9)])

    d["chai_pour"] = (chai_pour, -4.0)
    d["tandoor_slap"] = (tandoor_slap, -3.0)
    d["churn"] = (churn, -4.0)
    d["kadai_sizzle"] = (kadai_sizzle, -4.0)
    d["egg_crack"] = (egg_crack, -4.0)
    d["handi_bubble"] = (handi_bubble, -4.0)

    # ---------------- UI
    d["tap"] = (lambda r: mix(0.07, [(modes(1350, 0.06, [(1, 1.0, 0.008), (2.4, 0.4, 0.004)], 0.0004, r), 0, 1.0),
                                     (shaped_noise(n_of(0.02), r, 2000, 6000) * env(n_of(0.02), 0.0002, 0.002), 0, 0.25)]),
                -4.0)
    d["button_thunk"] = (lambda r: wood(300, 0.16, r, 0.035, 0.08, 0.5), -3.0)

    def deny(r):
        def bup(m):
            b = modes(note(m), 0.3, [(1, 1.0, 0.05), (2, 0.45, 0.032), (3, 0.22, 0.022), (4, 0.08, 0.015)], 0.004, r,
                      glide=-0.03, glide_t=0.05)
            return b + 0.12 * shaped_noise(len(b), r, 300, 1500) * env(len(b), 0.001, 0.01)
        # A4 -> F#4, muted (an octave up from a "bup" a phone speaker could not play)
        return mix(0.42, [(bup(69), 0.0, 1.0), (bup(66), 0.11, 0.9)])

    d["deny"] = (deny, -4.0)
    d["typewriter"] = (lambda r: mix(0.04, [(shaped_noise(n_of(0.03), r, 2500, 7000) * env(n_of(0.03), 0.0004, 0.004), 0, 0.5),
                                            (modes(1800, 0.03, [(1, 1.0, 0.005)], 0.0004, r), 0, 0.4)]), -6.0)
    d["marker_pop"] = (lambda r: mix(0.26, [(sweep(320, 1100, 0.11, 0.05), 0, 1.0), (bell(note(98), 0.18, 0.05, r), 0.07, 0.3)]),
                       -3.0)
    d["reward_count"] = (lambda r: mix(0.17, [(modes(note(93), 0.16, [(1, 1.0, 0.04), (2.0, 0.3, 0.025)], 0.001, r), 0, 1.0),
                                              (bell(note(100), 0.1, 0.025, r), 0.012, 0.35)]), -4.0)

    def claim(r):
        parts = [(sweep(400, 1600, 0.25, 0.2, kind="tri"), 0, 0.45)]
        parts += [(bell(note(m), 0.55, 0.16, r), 0.12 + i * 0.04, 0.6) for i, m in enumerate((86, 90, 93, 98))]
        parts += [(swoosh(0.3, 0.3, 0.9, 0.0, r), 0.1, 0.1)]
        return room(mix(0.9, parts), r, 0.6, 0.18)

    d["claim"] = (claim, -3.0)

    def build_done(r):
        """The unlock fanfare: dholak 'dha-dhin', a harmonium D chord
        swelling under a santoor run up the D major arpeggio, a shimmer."""
        parts = [(bol("dha", r, 1.0), 0.0, 0.9), (bol("dhi", r, 0.85), 0.13, 0.8)]
        for m in (62, 66, 69, 74):
            parts.append((reed(m, 0.75, r, 0.06, 0.3, swell=0.3), 0.24, 0.16))
        for i, m in enumerate((74, 78, 81, 86, 90)):
            parts.append((santoor(m, r, 1.0, 1.3), 0.24 + i * 0.07, 0.55))
        parts.append((sweep(1200, 3200, 0.5, 0.25), 0.55, 0.06))
        return room(mix(1.9, parts), r, 0.9, 0.22)

    d["build_done"] = (build_done, -2.5)

    # Art audit UA2 (4 Nov): a hire gets its own sound (a soft wooden tok under two
    # steel-tray clinks, D major) and a table a short build knock, so the long
    # fanfare stays for counters, the renovation and the move.
    d["hire"] = (lambda r: room(mix(0.5, [(wood(294, 0.12, r, 0.03, 0.05, 0.35), 0.0, 0.6),
                                          (bell(note(86), 0.3, 0.09, r), 0.03, 0.75),
                                          (bell(note(93), 0.35, 0.12, r), 0.11, 0.85)]), r, 0.45, 0.14), -3.0)
    d["table_knock"] = (lambda r: room(mix(0.6, [(wood(196, 0.16, r, 0.04, 0.05, 0.5), 0.0, 1.0),
                                                 (wood(247, 0.14, r, 0.035, 0.05, 0.45), 0.12, 0.85),
                                                 (bell(note(81), 0.28, 0.09, r), 0.22, 0.3)]), r, 0.5, 0.14), -3.0)

    # Story (4 Nov): Simran's message: two short phone-vibration buzzes (a
    # 180 Hz hum shaken at 32 Hz) and a soft two-note ting (D6 -> A6).
    def phone_buzz(r):
        def buzz(dur):
            t = t_axis(dur)
            hum = np.sin(TAU * 180.0 * t) + 0.35 * np.sin(TAU * 360.0 * t)
            shake = 0.6 + 0.4 * np.sin(TAU * 32.0 * t)
            return end_fade(hum * shake * env(len(t), 0.008, None), 0.02)
        return room(mix(0.75, [(buzz(0.14), 0.0, 0.5), (buzz(0.14), 0.2, 0.5),
                               (bell(note(86), 0.3, 0.1, r), 0.4, 0.7),
                               (bell(note(93), 0.35, 0.12, r), 0.5, 0.8)]), r, 0.4, 0.12)

    d["phone_buzz"] = (phone_buzz, -3.0)

    def menu_unlock(r):
        parts = [(bell(note(m), 0.6, 0.14, r), i * 0.09, 0.8 if i < 2 else 1.0) for i, m in enumerate((86, 90, 93))]
        parts += [(swoosh(0.25, 0.1, 0.6, 0.0, r), 0.0, 0.3)]
        parts += [(reed(m, 0.5, r, 0.05, 0.25, swell=0.4), 0.05, 0.1) for m in (62, 66, 69)]
        return room(mix(0.95, parts), r, 0.7, 0.2)

    d["menu_unlock"] = (menu_unlock, -3.0)
    d["ready"] = (lambda r: room(mix(0.55, [(bell(note(81), 0.35, 0.09, r), 0.0, 0.8), (bell(note(86), 0.45, 0.13, r), 0.08, 1.0)]),
                                 r, 0.5, 0.15), -4.0)
    # LEVEL UP (hook, not wired yet): a woody tok and an A6 ting.
    d["upgrade"] = (lambda r: mix(0.35, [(wood(330, 0.14, r, 0.03, 0.06, 0.4), 0, 0.8), (bell(note(93), 0.3, 0.08, r), 0.025, 0.55)]),
                    -3.0)

    # A traveller gives up and leaves (hook, not wired yet): a soft, falling
    # "hm-mm" on a muted reed, not a buzzer.
    def angry(r):
        def hum(m, dur, fall):
            t = t_axis(dur)
            f = note(m) * (1 - fall * np.clip(t / dur, 0, 1))
            ph = TAU * np.cumsum(f) / SR
            w = sum(np.sin(k * ph) * k ** -1.3 * (1 + 1.2 * np.exp(-0.5 * ((k * note(m) - 700) / 250) ** 2)) for k in range(1, 9))
            return w * ramp_env(len(t), 0.03, 0.08)
        return mix(0.45, [(hum(57, 0.16, 0.02), 0.0, 1.0), (hum(53, 0.24, 0.06), 0.15, 0.9)])

    d["angry"] = (angry, -4.0)

    # ---------------- core-and-feel (2026-11-01, W1-ART1): appended, earlier entries untouched
    def tv_cheer(r):
        """A cricket crowd roaring out of a small TV across the room (night, C8.3): a swell of many
        voices (vowel formants), a few voices on top, a scatter of claps, through a tinny speaker
        and a little room."""
        dur = 1.5
        n = n_of(dur)
        t = np.arange(n) / SR
        swell = np.clip(t / 0.25, 0, 1) ** 1.5 * np.exp(-np.clip(t - 0.45, 0, None) / 0.45)
        crowd = shaped_noise(n, r, 250, 3200, peaks=((650, 9, 180), (1150, 7, 260), (2500, 4, 400)))
        flutter = fft_filter(r.standard_normal(n), hi=14.0)
        flutter = 0.7 + 0.3 * flutter / (np.max(np.abs(flutter)) + 1e-9)
        parts = [(crowd * swell * flutter, 0.0, 0.6)]
        for _ in range(6):                                        # a few voices: "aaah", "ohh"
            vd = r.uniform(0.5, 0.9)
            tt = t_axis(vd)
            f0 = r.uniform(170, 300)
            f = f0 * (1 + 0.04 * np.sin(TAU * r.uniform(3, 6) * tt)) * (1 + 0.15 * tt / vd)
            ph = TAU * np.cumsum(f) / SR
            v = sum(np.sin(m * ph) / m for m in range(1, 12))
            v = fft_filter(v, 300, 3000, peaks=((700, 10, 150), (1200, 8, 220)))
            parts.append((v * ramp_env(len(tt), 0.08, 0.3), r.uniform(0.08, 0.35), r.uniform(0.06, 0.12)))
        for _ in range(26):                                       # claps
            c = shaped_noise(n_of(0.02), r, 900, 5000) * env(n_of(0.02), 0.0005, 0.004)
            parts.append((c, r.uniform(0.15, 1.1), r.uniform(0.05, 0.14)))
        x = fft_filter(mix(dur + 0.2, parts), 320, 3600, peaks=((1800, 4, 600),))   # small TV speaker
        return room(x, r, 0.45, 0.25)

    def baraat_band(r):
        """A wedding band arriving (C6.4): a dhol in a bhangra chaal (the bass head's palm bend, the
        stick's crack on the treble head) and a trumpet sting rising up the D major chord to a held
        D6 with a second trumpet a third under it. About 3 s."""
        eighth = 60.0 / 150 / 2

        def dhol_bass(v):
            return v * modes(95, 0.45, [(1, 1.0, 0.16), (1.5, 0.3, 0.07), (2.3, 0.15, 0.04)], 0.002, r,
                             glide=0.18, glide_t=0.04)

        def dhol_tick(v):
            k = modes(520, 0.12, [(1, 1.0, 0.035), (1.62, 0.6, 0.02), (2.7, 0.3, 0.012)], 0.0006, r)
            k += 0.5 * shaped_noise(len(k), r, 1500, 7000) * env(len(k), 0.0003, 0.006)
            return v * k

        def brass(m, dur, vib=0.0):
            tt = t_axis(dur)
            f = note(m) * (1 + vib * np.sin(TAU * 5.5 * tt) * np.clip((tt - 0.15) / 0.2, 0, 1))
            ph = TAU * np.cumsum(f) / SR
            w = sum(np.sin(k * ph) * k ** -0.9 for k in range(1, 18) if k * note(m) < 7000)
            w = fft_filter(w, 200, 6000, peaks=((1300, 8, 500),))
            return w * ramp_env(len(tt), 0.03, min(0.12, dur * 0.4))

        parts = []
        chaal = (("B", 0, 1.0), ("T", 2, 0.6), ("B", 3, 0.85), ("T", 5, 0.6), ("B", 6, 0.8), ("T", 7, 0.7))
        for rep in range(2):
            for (kind, e, v) in chaal:
                at = (rep * 8 + e) * eighth
                v *= r.uniform(0.9, 1.0)
                parts.append((dhol_bass(v) if kind == "B" else dhol_tick(v), at, 1.0))
        for i, (m, d_) in enumerate(((74, 0.16), (78, 0.16), (81, 0.16))):
            parts.append((brass(m, d_), 1.2 + i * 0.17, 0.45))
        parts.append((brass(86, 1.1, 0.006), 1.71, 0.5))
        parts.append((brass(83, 1.0, 0.007), 1.75, 0.3))
        x = room(mix(3.2, parts), r, 0.6, 0.18)[: n_of(3.0)]
        return end_fade(x, 0.25)

    def dog_bark(r):
        """A street dog's two short barks (C8.3), a little way off."""
        def bark(f0, dur):
            tt = t_axis(dur)
            f = f0 * (1.25 - 0.45 * np.clip(tt / dur, 0, 1))
            ph = TAU * np.cumsum(f) / SR
            v = sum(np.sin(m * ph) * m ** -0.7 for m in range(1, 16))
            v = v + 0.6 * shaped_noise(len(tt), r, 400, 4500)
            v = fft_filter(v, 250, 5000, peaks=((900, 9, 250), (2200, 5, 400)))
            e = np.clip(tt / 0.008, 0, 1) * np.exp(-np.clip(tt - 0.03, 0, None) / 0.045)
            return v * e
        return far(mix(0.6, [(bark(430, 0.16), 0.0, 1.0), (bark(390, 0.18), 0.24, 0.9)]), r, 3800, 0.5, 0.22)

    d["tv_cheer"] = (tv_cheer, -6.0)
    d["baraat_band"] = (baraat_band, -3.0)
    d["dog_bark"] = (dog_bark, -3.0)
    return d


# ================================================================ music
BPM = 84
BEAT = 60.0 / BPM
BARS = 24
LOOP_S = BARS * 4 * BEAT
LOOP_N = n_of(LOOP_S)  # 1 512 000 samples: an exact 68.571 s

# One chord per bar. D = Sa. Section A (1-8), B (9-16), C (17-24).
CHORDS = ["D", "D", "G", "D", "C", "G", "A", "D",
          "G", "G", "D", "D", "Em", "A", "D", "D",
          "D", "C", "G", "D", "G", "C", "A", "A7"]
VOICING = {"D": (57, 62, 66), "G": (59, 62, 67), "C": (60, 64, 67), "A": (57, 61, 64),
           "A7": (57, 61, 64, 67), "Em": (59, 64, 67)}
ROOT = {"D": 50, "G": 43, "C": 48, "A": 45, "A7": 45, "Em": 52}
ARP = {"D": (62, 66, 69, 74, 78), "G": (62, 67, 71, 74, 79), "C": (60, 64, 67, 72, 76), "A": (61, 64, 69, 73, 76),
       "A7": (61, 64, 67, 69, 73), "Em": (64, 67, 71, 76, 79)}

# Bansuri phrases: (midi, beat from the phrase's bar, beats).
PHRASE_A = [(69, 1.0, 0.5), (71, 1.5, 0.5), (74, 2.0, 1.5), (76, 3.5, 0.5), (78, 4.0, 2.0), (76, 6.0, 0.5),
            (74, 6.5, 1.5), (74, 8.0, 0.5), (76, 8.5, 0.5), (71, 9.0, 1.0), (74, 10.0, 1.0), (71, 11.0, 0.5),
            (69, 11.5, 0.5), (69, 12.0, 3.0)]
PHRASE_A2 = [(74, 1.0, 0.5), (72, 1.5, 1.5), (69, 3.0, 1.0), (67, 4.0, 1.0), (69, 5.0, 0.5), (71, 5.5, 0.5),
             (74, 6.0, 2.0), (73, 8.0, 1.0), (76, 9.0, 1.0), (73, 10.0, 0.5), (71, 10.5, 0.5), (69, 11.0, 1.0),
             (74, 12.0, 3.0)]
PHRASE_B = [(76, 0.0, 1.0), (79, 1.0, 1.0), (78, 2.0, 0.5), (76, 2.5, 1.5), (73, 4.0, 0.5), (76, 4.5, 0.5),
            (78, 5.0, 1.0), (76, 6.0, 1.0), (73, 7.0, 1.0), (74, 8.0, 2.0), (69, 10.0, 1.0), (71, 11.0, 0.5),
            (69, 11.5, 0.5), (66, 12.0, 2.5)]
PHRASE_C = [(67, 0.5, 0.5), (69, 1.0, 1.0), (71, 2.0, 1.0), (74, 3.0, 1.0), (72, 4.0, 1.5), (71, 5.5, 0.5),
            (69, 6.0, 1.0), (67, 7.0, 1.0), (64, 8.0, 1.0), (66, 9.0, 0.5), (67, 9.5, 0.5), (69, 10.0, 2.0)]
MELODY = [(0, PHRASE_A), (4, PHRASE_A2), (12, PHRASE_B), (20, PHRASE_C)]  # (start bar, phrase)


# Stem levels (RMS over the whole loop, dB, relative): the mix balance.
STEM_DB = {"harm": -27.0, "drone": -36.0, "tabla": -24.0, "flute": -23.0, "santoor": -26.5}


class Loop:
    """Stereo buffer one loop long; everything placed wraps round the end,
    so the loop point is seamless by construction."""

    def __init__(self, n):
        self.n = n
        self.buf = np.zeros((n, 2))

    def add(self, clip, at_s, gain=1.0, pan=0.0):
        clip = np.asarray(clip) * gain
        gl = np.cos((pan + 1) * np.pi / 4) * np.sqrt(2)
        gr = np.sin((pan + 1) * np.pi / 4) * np.sqrt(2)
        i = int(round(at_s * SR)) % self.n
        L = len(clip)
        while L > 0:
            j = min(self.n, i + L)
            k = j - i
            self.buf[i:j, 0] += clip[:k] * gl
            self.buf[i:j, 1] += clip[:k] * gr
            clip = clip[k:]
            L -= k
            i = 0


def periodic(f, period_s):
    """Nearest frequency with a whole number of cycles in the loop."""
    return max(1, round(f * period_s)) / period_s


def flute_phrase(phrase, rng):
    """One legato bansuri phrase: a continuous pitch line with short glides
    (meend) between joined notes, breath, delayed vibrato."""
    end = max(s + d for _, s, d in phrase) * BEAT + 0.35
    n = n_of(end)
    t = np.arange(n) / SR
    f = np.zeros(n)
    a = np.zeros(n)
    vib_depth = np.zeros(n)
    onsets = []
    for idx, (m, s, d) in enumerate(phrase):
        i0 = n_of(s * BEAT)
        i1 = min(n, n_of((s + d) * BEAT))
        f[i0:i1] = note(m)
        joined = idx + 1 < len(phrase) and abs(phrase[idx + 1][1] - (s + d)) < 1e-6
        seg = np.ones(i1 - i0)
        att = min(len(seg), n_of(0.05 if idx == 0 or not joined_prev(phrase, idx) else 0.025))
        seg[:att] = np.linspace(0.35 if joined_prev(phrase, idx) else 0.0, 1.0, att)
        seg *= np.linspace(1.0, 0.85, len(seg))
        if not joined:
            rel = min(len(seg), n_of(0.12))
            seg[-rel:] *= np.linspace(1, 0, rel) ** 1.3
        a[i0:i1] = seg
        vd = np.clip((np.arange(i1 - i0) / SR - 0.22) / 0.3, 0, 1) * 0.0055
        vib_depth[i0:i1] = vd
        if not joined_prev(phrase, idx):
            onsets.append(i0)
    # hold pitch through rests (no zero-frequency gaps), then glide
    last = note(phrase[0][0])
    for i in range(n):
        if f[i] == 0:
            f[i] = last
        else:
            last = f[i]
    g = n_of(0.045)
    kern = np.ones(g) / g
    f = np.convolve(np.pad(f, (g, g), mode="edge"), kern, mode="same")[g:-g]
    f *= 1 + vib_depth * np.sin(TAU * 5.1 * t + rng.uniform(0, TAU))
    ph = TAU * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.2 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph) + 0.025 * np.sin(4 * ph)
    breath = shaped_noise(n, rng, 900, 5000) * 0.05
    sig = (tone + breath) * a
    for i0 in onsets:
        ch = shaped_noise(n_of(0.04), rng, 1500, 6000) * env(n_of(0.04), 0.002, 0.012) * 0.12
        place(sig, ch, i0 / SR)
    return sig * 0.5


def joined_prev(phrase, idx):
    if idx == 0:
        return False
    m, s, d = phrase[idx - 1]
    return abs(s + d - phrase[idx][1]) < 1e-6


def keherwa(bar, rng):
    """Bols for one bar of keherwa (8 eighths): dha ge na ti | na ka dhi na,
    with a tirakita fill every fourth bar, a sparse bar set in section C and
    a bigger fill into the top of the loop."""
    theka = [("dha", 1.0), ("ge", 0.55), ("na", 0.6), ("ti", 0.45), ("na", 0.62), ("ka", 0.45), ("dhi", 0.78),
             ("na", 0.58)]
    if 16 <= bar <= 19:  # breathing space: sam, a soft na, dhi
        return [(0, "dha", 0.85), (2, "na", 0.4), (6, "dhi", 0.6)]
    hits = [(i, b, v) for i, (b, v) in enumerate(theka)]
    if bar == 23:  # into the top of the loop: na tirakita dha ge
        hits = hits[:4] + [(4, "na", 0.6), (5, "ti", 0.5), (5.5, "ra", 0.4), (6, "ki", 0.45), (6.5, "ta", 0.55),
                           (7, "dha", 0.8), (7.5, "ge", 0.5)]
    elif bar % 4 == 3:  # end of a 4-bar line: ti ra ki ta on the last two eighths
        hits = hits[:6] + [(6, "ti", 0.5), (6.5, "ra", 0.38), (7, "ki", 0.42), (7.5, "ta", 0.5)]
    return hits


def music(out, preview=None):
    rng = rng_for("music_loop")
    dry = {k: Loop(LOOP_N) for k in ("harm", "drone", "tabla", "flute", "santoor")}
    bar_s = 4 * BEAT
    # Harmonium: one chord per bar, two reed banks a few cents apart (left /
    # right) for the beating warmth, legato into the next bar.
    for b, ch in enumerate(CHORDS):
        for m in VOICING[ch]:
            for det, pan in ((-3.5, -0.45), (3.5, 0.45)):
                dry["harm"].add(reed(m, bar_s, rng, 0.14, 0.3, det, 0.9, swell=0.22), b * bar_s, 0.5, pan)
        dry["harm"].add(reed(ROOT[ch], bar_s, rng, 0.14, 0.3, 0, 0.7, swell=0.15), b * bar_s, 0.55, 0.0)
    # Drone on Sa: whole-loop, frequencies snapped to the loop (seamless),
    # with a slow bellows breath.
    t = np.arange(LOOP_N) / SR
    drone = np.zeros(LOOP_N)
    for m, g in ((50, 1.0), (57, 0.45)):
        f0 = note(m)
        for k in range(1, 18):
            fk = periodic(f0 * k, LOOP_S)
            if fk > 3000:
                break
            drone += g * k ** -0.9 / (1 + (fk / 1500) ** 2) * np.sin(TAU * fk * t + rng.uniform(0, TAU))
    drone *= 0.85 + 0.15 * np.sin(TAU * periodic(0.11, LOOP_S) * t)
    dry["drone"].add(drone, 0.0, 0.08, 0.0)
    # Tabla, with a light swing and human timing.
    for b in range(BARS):
        for pos, name, vel in keherwa(b, rng):
            swing = 0.035 * BEAT if (pos % 1) == 0 and int(pos) % 2 == 1 else 0.0
            at = b * bar_s + pos * BEAT / 2 + swing + rng.normal(0, 0.003)
            v = vel * rng.uniform(0.92, 1.06)
            clip = bol(name, rng, v)
            pan = -0.18 if name in ("ge", "ka") else 0.12
            dry["tabla"].add(clip, at, 0.55, pan)
    # Bansuri.
    for bar, ph in MELODY:
        dry["flute"].add(flute_phrase(ph, rng), bar * bar_s, 0.42, -0.2)
    # Santoor: gentle broken chords in section B (no flute bars 8-11) and
    # raindrops in section C (bars 16-19), and a pickup at the end of A.
    for b in range(8, 12):
        tones = ARP[CHORDS[b]]
        pattern = (0, 2, 4, 3, None, 1, 2, None) if b % 2 == 0 else (4, 3, 2, None, 1, 2, None, 0)
        for i, p in enumerate(pattern):
            if p is not None:
                dry["santoor"].add(santoor(tones[p], rng, rng.uniform(0.75, 1.0)), b * bar_s + i * BEAT / 2, 0.5, 0.35)
    for b, hits in ((16, (0, 3, 5)), (17, (1, 4)), (18, (0, 2, 5)), (19, (2, 4, 7))):
        tones = ARP[CHORDS[b]]
        for i in hits:
            dry["santoor"].add(santoor(tones[(i + b) % 5], rng, rng.uniform(0.6, 0.85)), b * bar_s + i * BEAT / 2, 0.5, 0.35)
    for i, m in enumerate((69, 73, 76, 79)):  # A7 lift into the top
        dry["santoor"].add(santoor(m, rng, 0.55), 23 * bar_s + (4 + i) * BEAT / 2, 0.45, 0.35)

    # Balance: each stem to a set RMS (whole loop) before the reverb, so the
    # pad stays a bed under the bansuri and the tabla.
    lv = lambda b: 10 * np.log10(np.mean(np.asarray(b) ** 2) + 1e-12)
    for k, target in STEM_DB.items():
        dry[k].buf *= 10 ** ((target - lv(dry[k].buf)) / 20)
    # Reverb sends (circular convolution: the tail wraps into the start).
    sends = {"harm": 0.22, "drone": 0.1, "tabla": 0.14, "flute": 0.38, "santoor": 0.4}
    ir = np.stack([reverb_ir(1.6, rng, 0.02, 0.4), reverb_ir(1.6, rng, 0.023, 0.4)], axis=1)
    send = sum(dry[k].buf * g for k, g in sends.items())
    wet = np.zeros_like(send)
    for c in range(2):
        H = np.fft.rfft(np.concatenate([ir[:, c], np.zeros(LOOP_N - len(ir))]))
        wet[:, c] = np.fft.irfft(np.fft.rfft(send[:, c]) * H, LOOP_N)
    mixbuf = sum(d.buf for d in dry.values()) + 0.5 * wet
    ref = lv(mixbuf)
    print("[music] stem RMS vs the mix (dB): " + ", ".join(
        f"{k} {lv(d.buf) - ref:+.1f}" for k, d in list(dry.items()) + [("reverb", type("W", (), {"buf": 0.5 * wet}))]))
    # Master EQ (circular, zero-phase): no sub rumble, a warm top.
    m = spectrum_mask(LOOP_N, lo=55, hi=None, peaks=((7500, -4, 2500), (220, -1.5, 120)))
    for c in range(2):
        mixbuf[:, c] = np.fft.irfft(np.fft.rfft(mixbuf[:, c]) * m, LOOP_N)
    mixbuf /= np.max(np.abs(mixbuf))
    mixbuf *= 10 ** (-2.0 / 20)
    if preview is not None:
        preview["music_loop"] = mixbuf
    encode(os.path.join(out, "music_loop.ogg"), mixbuf, 40)
    return mixbuf


# ================================================================ ambience
def ambience_day(rng, dur=16.0):
    """Daytime: the highway far off (a faint wash, three lorries passing at
    a distance) and sparrows. Mostly quiet: events, not a constant hiss."""
    n = n_of(dur)
    t = np.arange(n) / SR
    bed = shaped_noise(n, rng, 120, 900, tilt=-3.0)
    lfo = sum(np.sin(TAU * periodic(f, dur) * t + rng.uniform(0, TAU)) * a for f, a in ((0.0625, 0.2), (0.1875, 0.12), (0.4375, 0.06)))
    out = 0.12 * bed * (0.75 + lfo)
    lp = Loop(n)
    for at, w in ((2.5, 3.0), (8.0, 3.5), (13.0, 2.6)):
        m = n_of(w * 2)
        x = shaped_noise(m, rng, 150, 1400, tilt=-2.0) + 0.15 * shaped_noise(m, rng, 1500, 3500)
        x *= np.exp(-0.5 * ((np.arange(m) / SR - w) / (w / 4.0)) ** 2)
        lp.add(x, at - w, 0.45)
    out += lp.buf[:, 0]
    birds = Loop(n)
    for at, notes in ((4.2, 3), (9.9, 2), (10.4, 3), (14.3, 2)):
        for k in range(notes):
            cn = n_of(rng.uniform(0.04, 0.06))
            ct = np.arange(cn) / SR
            f0 = rng.uniform(4000, 4800)
            f = f0 * (1 - rng.uniform(0.15, 0.3) * ct / ct[-1])
            chirp = np.sin(TAU * np.cumsum(f) / SR) * np.sin(np.pi * ct / ct[-1]) ** 2
            birds.add(chirp, at + k * rng.uniform(0.08, 0.11), rng.uniform(0.5, 0.8))
    out += birds.buf[:, 0]
    return out


def ambience_night(rng, dur=16.0):
    """Night: two crickets (whole chirp cycles per loop, so it wraps) and a
    lorry far away."""
    n = n_of(dur)
    t = np.arange(n) / SR
    out = 0.06 * shaped_noise(n, rng, 100, 500, tilt=-3.0) * (0.8 + 0.2 * np.sin(TAU * periodic(0.0625, dur) * t))
    lp = Loop(n)
    for name, fc, period, pulses, gap, gain in (("a", 4400, 0.8, 3, 0.032, 0.5), ("b", 4950, 1.0, 4, 0.026, 0.35)):
        r = rng_for("cricket_" + name)
        for i in range(int(round(dur / period))):
            if r.uniform() < 0.18:  # an occasional skipped chirp
                continue
            for p in range(pulses):
                pn = n_of(0.014)
                pt = np.arange(pn) / SR
                pulse = np.sin(TAU * fc * pt) * np.sin(np.pi * pt / pt[-1]) ** 2
                lp.add(pulse, i * period + p * gap + 0.11, gain * r.uniform(0.8, 1.0))
    out += lp.buf[:, 0]
    m = n_of(8.0)
    x = shaped_noise(m, rng, 120, 900, tilt=-2.0) * np.exp(-0.5 * ((np.arange(m) / SR - 4.0) / 1.6) ** 2)
    lp2 = Loop(n)
    lp2.add(x, 6.0, 0.2)
    out += lp2.buf[:, 0]
    return out


def ambience(out, preview=None):
    for name, fn in (("amb_day", ambience_day), ("amb_night", ambience_night)):
        x = fn(rng_for(name))
        x = x / np.max(np.abs(x)) * 10 ** (-3.0 / 20)
        if preview is not None:
            preview[name] = x
        encode(os.path.join(out, name + ".ogg"), x, 16)


# ================================================================ main
RETIRED = ("coin", "rush", "sizzle", "music_loop.wav")


def main(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    out = os.path.abspath(args[0] if args and not args[0].startswith("--") else os.path.join(HERE, "..", "..", "assets", "audio"))
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    global MASTERS
    MASTERS = os.path.abspath(args[args.index("--masters") + 1]) if "--masters" in args else None
    os.makedirs(out, exist_ok=True)
    for name, (build, peak) in sfx_defs().items():
        if only and name not in only:
            continue
        write_wav(os.path.join(out, name + ".wav"), tidy(build(rng_for(name))), peak)
    if not only or "music_loop" in only:
        music(out)
    if not only or "ambience" in only:
        ambience(out)


if __name__ == "__main__":
    main(sys.argv)
