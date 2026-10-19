"""Synthesises the wake-up tones in assets/sounds/ (original, generated here).

    python scripts/make-sounds.py

Each tone is a seamless ~12 s loop, written as Ogg Vorbis with the ffmpeg that
ships with imageio-ffmpeg (pip install imageio-ffmpeg numpy). The "Classic"
tone is the older assets/alarm.wav and is not generated.
"""
import os
import subprocess
import tempfile
import wave

import imageio_ffmpeg
import numpy as np

RATE = 32000
LENGTH = 12.0
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
rng = np.random.default_rng(7)


def silence():
    return np.zeros(int(RATE * LENGTH))


def place(buf, sound, at):
    """Adds [sound] into [buf] at [at] seconds, wrapping round for a seamless loop."""
    start = int(at * RATE) % len(buf)
    end = start + len(sound)
    if end <= len(buf):
        buf[start:end] += sound
    else:
        cut = len(buf) - start
        buf[start:] += sound[:cut]
        buf[: end - len(buf)] += sound[cut:]


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def note(freq, seconds, partials, decay, attack=0.004):
    t = t_axis(seconds)
    tone = sum(a * np.sin(2 * np.pi * freq * m * t) * np.exp(-t * decay * (1 + m * 0.35))
               for m, a in partials)
    env = np.minimum(1, t / attack)
    return tone * env


def hz(semitones_from_a4):
    return 440 * 2 ** (semitones_from_a4 / 12)


# Note names relative to A4.
C5, D5, E5, G5, A5, C6, D6, E6 = 3, 5, 7, 10, 12, 15, 17, 19
C4, E4, G4, B4 = -9, -5, -2, 2


def chimes():
    buf = silence()
    scale = [C5, D5, E5, G5, A5, C6, E6]
    bell = [(1, 1.0), (2.76, 0.35), (5.4, 0.12)]
    t = 0.0
    while t < LENGTH:
        f = hz(scale[rng.integers(len(scale))])
        place(buf, note(f, 4.0, bell, 1.1) * rng.uniform(0.5, 1.0), t)
        t += rng.choice([0.45, 0.6, 0.9, 1.2])
    return buf


def music_box():
    buf = silence()
    # An original little tune, two bars repeated with a variation.
    tune = [E6, C6, G5, C6, D6, E6, D6, C6, G5, A5, C6, G5, E5, G5, C6, None,
            E6, D6, C6, A5, G5, A5, C6, D6, E6, G5, C6, D6, C6, None, None, None]
    pluck = [(1, 1.0), (2, 0.25), (3, 0.12), (4.2, 0.06)]
    step = LENGTH / len(tune)
    for i, n in enumerate(tune):
        if n is not None:
            place(buf, note(hz(n), 2.0, pluck, 3.0), i * step)
            if i % 4 == 0:
                place(buf, 0.35 * note(hz(n - 24), 2.0, pluck, 2.0), i * step)
    return buf


def birds():
    buf = silence()
    t = 0.3
    while t < LENGTH:
        for _ in range(rng.integers(2, 6)):
            dur = rng.uniform(0.06, 0.16)
            tt = t_axis(dur)
            f0, f1 = rng.uniform(2600, 4200), rng.uniform(3000, 5200)
            freq = f0 + (f1 - f0) * (tt / dur) + 300 * np.sin(2 * np.pi * 28 * tt)
            phase = 2 * np.pi * np.cumsum(freq) / RATE
            chirp = np.sin(phase) * np.sin(np.pi * tt / dur) ** 2
            place(buf, chirp * rng.uniform(0.4, 0.9), t)
            t += dur + rng.uniform(0.03, 0.09)
        t += rng.uniform(0.6, 1.6)
    # A soft morning bed under the birds.
    tt = t_axis(LENGTH)
    buf += 0.05 * np.sin(2 * np.pi * hz(C4) * tt) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / LENGTH))
    return buf


def sunrise_piano():
    buf = silence()
    piano = [(1, 1.0), (2, 0.45), (3, 0.2), (4, 0.1), (5, 0.05)]
    chords = [[C4, E4, G4, C5, E5], [-7, -3, 0, 5, 9], [-4, 0, 3, 8, 12], [-2, 2, 5, 10, 14]]
    step = LENGTH / (len(chords) * 6)
    i = 0
    for chord in chords:
        for n in chord + [chord[-2]]:
            place(buf, note(hz(n), 3.5, piano, 1.6, attack=0.01), i * step)
            i += 1
    return buf


def write(name, samples):
    samples = samples / np.max(np.abs(samples)) * 0.7
    # Short fades at the loop point.
    fade = int(0.02 * RATE)
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    pcm = (samples * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, 'tone.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        out = os.path.join(OUT, f'{name}.ogg')
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-loglevel', 'error', '-i', wav,
                        '-c:a', 'libvorbis', '-q:a', '3', out], check=True)
        print(f'{out}: {os.path.getsize(out) // 1024} KB')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    write('chimes', chimes())
    write('music_box', music_box())
    write('birds', birds())
    write('sunrise_piano', sunrise_piano())
