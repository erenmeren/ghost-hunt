"""Synthesise the game's retro sound effects (16-bit mono WAV)."""
import math, struct, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')

def write(name, samples):
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 30000)) for s in samples))

def sweep(f0, f1, dur, vol=0.6, wave_fn=None, env=True):
    n = int(SR * dur); ph = 0; out = []
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        ph += 2 * math.pi * f / SR
        s = (wave_fn or (lambda p: 1.0 if math.sin(p) >= 0 else -1.0))(ph)
        e = min(1, i / (SR * 0.005)) * (min(1, (n - i) / (SR * 0.01)) if env else 1)
        out.append(s * vol * e)
    return out

tri = lambda p: 2 / math.pi * math.asin(math.sin(p))
write('waka.wav', sweep(260, 520, 0.07, 0.5, tri) + sweep(520, 260, 0.07, 0.5, tri))
power = []
for _ in range(4): power += sweep(300, 900, 0.09, 0.35) + sweep(900, 300, 0.09, 0.35)
write('power.wav', power)
death = []
for k in range(9): death += sweep(800 - k * 70, 400 - k * 35, 0.11, 0.45, tri)
write('death.wav', death)
write('eat_ghost.wav', sweep(200, 1400, 0.25, 0.45))
win = []
for f in [523, 659, 784, 1046]: win += sweep(f, f, 0.14, 0.4, tri)
write('win.wav', win + sweep(1046, 1046, 0.35, 0.4, tri))
lose = []
for f in [392, 330, 262, 196]: lose += sweep(f, f * 0.97, 0.22, 0.4, tri)
write('lose.wav', lose)
write('turn.wav', sweep(600, 700, 0.03, 0.15, tri))
print('ok', sorted(os.listdir(OUT)))
