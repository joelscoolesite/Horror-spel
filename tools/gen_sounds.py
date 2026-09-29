"""Genereert alle geluiden voor de game (lo-fi, 22 kHz, mono .wav).

Gebruik:  python tools/gen_sounds.py
Vereist:  pip install numpy

Wil je een geluid vervangen door een echte opname? Zet dan gewoon een .wav
met dezelfde naam in assets/sounds/. De game merkt het verschil niet.
"""
import os
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
SR = 22050
rng = np.random.default_rng(666)


# ---------------------------------------------------------------- helpers

def t(sec):
    return np.arange(int(sec * SR)) / SR


def white(sec):
    return rng.uniform(-1, 1, int(sec * SR))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def resonator(x, freq, q=30.0):
    """Simpel 2-pole resonant filter: geeft 'toon' aan ruis/klikken."""
    w = 2 * np.pi * freq / SR
    r = np.exp(-w / (2 * q))
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        yn = v - a1 * y1 - a2 * y2
        y[i] = yn
        y2, y1 = y1, yn
    return y * (1 - r)


def env(n, attack, decay_rate):
    tt = np.arange(n) / SR
    e = np.exp(-tt * decay_rate)
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def crossfade_loop(x, fade=0.05):
    """Maakt een geluid naadloos loopbaar."""
    n = int(fade * SR)
    head = x[:n].copy()
    body = x[n:].copy()
    ramp = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * (1 - ramp) + head * ramp
    return body


def save(name, x, peak=0.9):
    x = norm(x, peak)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  ", name)


# ---------------------------------------------------------------- geluiden

def footsteps():
    for i in range(3):
        n = int(0.28 * SR)
        click = white(0.28) * env(n, 0.002, 60)
        # hout: holle 'tok' met resonantie
        thump = np.sin(2 * np.pi * (90 + i * 12) * t(0.28)) * env(n, 0.003, 30)
        wood = resonator(click, 320 + i * 40, 8) * 3 + thump * 0.8 + lowpass(click, 1800) * 0.5
        save(f"step_wood_{i + 1}", wood, 0.8)
        # tapijt: gedempt
        carpet = lowpass(white(0.28) * env(n, 0.01, 25), 500) + thump * 0.4
        save(f"step_carpet_{i + 1}", carpet, 0.6)
        # tegels: scherpe klik
        tile = highpass(click, 1200) * 0.8 + resonator(click, 1400 + i * 100, 12) * 2 + thump * 0.3
        save(f"step_tile_{i + 1}", tile, 0.8)


def creak_signal(sec, base_rate=40.0, pitch=480.0, seed_jitter=0.3):
    """Stick-slip: een reeks kleine tikjes die samen een piep/kraak vormen."""
    n = int(sec * SR)
    x = np.zeros(n)
    pos = 0.0
    k = 0
    while pos < n:
        rate = base_rate * (1 + 0.5 * np.sin(k * 0.13) + rng.uniform(-seed_jitter, seed_jitter))
        pos += SR / max(rate, 5)
        if int(pos) < n:
            x[int(pos)] = rng.uniform(0.5, 1.0)
        k += 1
    y = resonator(x, pitch, 25) * 6 + resonator(x, pitch * 2.3, 20) * 3 + resonator(x, 180, 6) * 2
    return y


def creak():
    save("creak_loop", crossfade_loop(creak_signal(2.2, 35, 520)), 0.7)
    n = int(1.1 * SR)
    fast = creak_signal(1.1, 90, 700) * np.concatenate([np.linspace(0.3, 1, n // 3), np.linspace(1, 0, n - n // 3)])
    save("creak_fast", fast, 0.9)


def door_close():
    n = int(0.5 * SR)
    x = white(0.5) * env(n, 0.001, 40)
    thump = np.sin(2 * np.pi * 70 * t(0.5)) * env(n, 0.002, 12)
    save("door_close", resonator(x, 220, 6) * 3 + thump + lowpass(x, 900) * 0.4)


def switch_click():
    n = int(0.12 * SR)
    x = white(0.12) * env(n, 0.0005, 120)
    save("switch", highpass(x, 1500) + resonator(x, 2500, 10) * 2, 0.6)


def tv_static():
    x = white(2.5)
    x = x * 0.8 + highpass(white(2.5), 3000) * 0.4
    hum = np.sin(2 * np.pi * 50 * t(2.5)) * 0.15 + np.sin(2 * np.pi * 100 * t(2.5)) * 0.08
    wobble = 1.0 + 0.15 * np.sin(2 * np.pi * 3.1 * t(2.5))
    save("tv_static", crossfade_loop(x * wobble + hum), 0.95)


def tv_on():
    n = int(0.6 * SR)
    pop = white(0.6) * env(n, 0.0005, 30)
    whine = np.sin(2 * np.pi * 9800 * t(0.6)) * 0.2 * env(n, 0.01, 3)
    save("tv_on", lowpass(pop, 2000) + whine)


def heartbeat():
    sec = 60 / 72
    n = int(sec * SR)
    x = np.zeros(n)
    for start, amp in [(0.0, 1.0), (0.18, 0.7)]:
        s = int(start * SR)
        m = int(0.15 * SR)
        tt = np.arange(m) / SR
        x[s:s + m] += np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 30) * amp
    save("heartbeat", lowpass(x, 200), 0.9)


def fridge_hum():
    tt = t(3.0)
    x = (np.sin(2 * np.pi * 50 * tt) * 0.5 + np.sin(2 * np.pi * 100 * tt) * 0.3
         + np.sin(2 * np.pi * 150 * tt) * 0.12 + lowpass(white(3.0), 300) * 0.3)
    save("fridge_hum", crossfade_loop(x), 0.5)


def clock_tick():
    n = int(1.0 * SR)
    x = np.zeros(n)
    m = int(0.03 * SR)
    x[:m] = white(0.03) * env(m, 0.0003, 200)
    save("clock_tick", highpass(resonator(x, 3200, 15) * 4 + x, 800), 0.5)


def alarm():
    sec = 1.0
    tt = t(sec)
    beep = np.sign(np.sin(2 * np.pi * 1800 * tt)) * 0.5
    gate = ((tt % 0.25) < 0.12) & (tt < 0.5)
    save("alarm", lowpass(beep * gate, 4000), 0.5)


def room_tone():
    x = lowpass(white(4.0), 120) + lowpass(white(4.0), 800) * 0.05
    save("room_tone", crossfade_loop(x, 0.2), 0.35)


def rustle():
    n = int(1.2 * SR)
    e = np.abs(np.sin(np.linspace(0, np.pi, n))) * (0.6 + 0.4 * lowpass(rng.uniform(0, 1, n), 8) * 3)
    save("rustle", bandpass(white(1.2), 300, 3000) * e, 0.6)


def scratch():
    """Nagels over hout: korte schraapstreken met pauzes."""
    total = 2.4
    n = int(total * SR)
    x = np.zeros(n)
    starts = [0.0, 0.55, 0.95, 1.6]
    for s in starts:
        length = rng.uniform(0.3, 0.45)
        m = int(length * SR)
        a = int(s * SR)
        stroke = creak_signal(length, rng.uniform(120, 220), rng.uniform(1500, 2400), 0.6)
        grit = bandpass(white(length), 1500, 6000) * 0.6
        shape = np.sin(np.linspace(0, np.pi, m)) ** 0.5
        x[a:a + m] += (stroke * 0.5 + grit)[:m] * shape
    save("scratch", x, 0.8)


def breath():
    n = int(3.0 * SR)
    tt = np.arange(n) / SR
    e = np.maximum(0, np.sin(2 * np.pi * tt / 3.0)) ** 2 + 0.6 * np.maximum(0, -np.sin(2 * np.pi * tt / 3.0)) ** 2
    save("breath", crossfade_loop(bandpass(white(3.0), 400, 2500) * e, 0.1), 0.5)


def bell():
    tt = t(2.5)
    x = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(880, 1), (1320, 0.5), (2210, 0.3)])
    x *= ((tt * 18) % 1 < 0.6) * np.exp(-tt * 0.3) * (tt < 2.0)
    save("school_bell", lowpass(np.sign(x) * 0.3 + x * 0.1, 3000), 0.5)


def murmur():
    """Klaslokaal-geroezemoes: veel 'stemmen' als gefilterde ruis."""
    sec = 4.0
    n = int(sec * SR)
    x = np.zeros(n)
    for _ in range(6):
        f = rng.uniform(250, 900)
        voice = bandpass(white(sec), f * 0.7, f * 1.4)
        syll = np.clip(np.sin(2 * np.pi * rng.uniform(2.5, 5) * t(sec) + rng.uniform(0, 6)), 0, 1)
        x += voice * syll * rng.uniform(0.3, 1)
    save("murmur", crossfade_loop(x, 0.3), 0.4)


def stinger():
    tt = t(3.0)
    x = sum(np.sin(2 * np.pi * f * tt + np.sin(tt * 3 + f)) for f in [55, 58.3, 82.4, 116.5])
    x += lowpass(white(3.0), 400) * 2
    x *= np.exp(-tt * 1.2) * np.minimum(1, tt * 60)
    save("stinger", x, 0.95)


def tv_game():
    """Chiptune-melodietje van het spel op de TV (en later... het gekras)."""
    notes = [0, 3, 7, 10, 7, 3, 0, -2, 0, 3, 7, 12, 10, 7, 3, 7]
    step = 0.16
    out = []
    for i, nt in enumerate(notes):
        f = 330 * 2 ** (nt / 12)
        tt = t(step)
        sq = np.sign(np.sin(2 * np.pi * f * tt)) * 0.3
        bass = np.sign(np.sin(2 * np.pi * (f / 4) * tt)) * 0.2 if i % 2 == 0 else 0
        out.append((sq + bass) * np.exp(-tt * 6))
    save("tv_game", np.concatenate(out), 0.5)


def whisper():
    """Gefluister: een paar 'lettergrepen' van ruis, met een beetje galm."""
    total = 2.2
    n = int(total * SR)
    x = np.zeros(n)
    # (start, lengte, klank-laag, klank-hoog) -> iets als "hé... ..."
    for start, length, lo, hi in [(0.05, 0.28, 2500, 7000), (0.35, 0.35, 700, 2600), (0.8, 0.25, 900, 3000), (1.15, 0.45, 600, 2200)]:
        m = int(length * SR)
        a = int(start * SR)
        seg = bandpass(white(length), lo, hi)
        shape = np.sin(np.linspace(0, np.pi, m)) ** 1.5
        x[a:a + m] += seg[:m] * shape
    # galm: vertraagde zachtere kopieën
    out = x.copy()
    for d, g in [(0.07, 0.35), (0.13, 0.25), (0.21, 0.15)]:
        k = int(d * SR)
        out[k:] += x[:-k] * g
    save("whisper", out, 0.7)


def ui_click():
    n = int(0.05 * SR)
    save("ui_click", np.sin(2 * np.pi * 1200 * t(0.05)) * env(n, 0.001, 80), 0.4)


def pickup():
    n = int(0.3 * SR)
    x = lowpass(white(0.3), 2500) * env(n, 0.01, 12)
    save("pickup", x, 0.5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("Geluiden maken in", os.path.abspath(OUT))
    footsteps()
    creak()
    door_close()
    switch_click()
    tv_static()
    tv_on()
    heartbeat()
    fridge_hum()
    clock_tick()
    alarm()
    room_tone()
    rustle()
    scratch()
    breath()
    bell()
    murmur()
    stinger()
    tv_game()
    ui_click()
    pickup()
    whisper()
    print("Klaar!")
