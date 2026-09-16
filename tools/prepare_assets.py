"""Reproducible texture maps and edited CC0 audio. Run from the project root."""
from pathlib import Path
import array, math, subprocess, wave, zipfile
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1]
audio = root / 'assets/audio'
textures = root / 'assets/textures'
audio.mkdir(exist_ok=True)
textures.mkdir(exist_ok=True)

with zipfile.ZipFile(audio / 'source/kenney-sci-fi.zip') as z:
    wanted = ['explosionCrunch_000', 'explosionCrunch_002', 'impactMetal_000',
              'laserSmall_000', 'laserLarge_000', 'thrusterFire_000',
              'computerNoise_000', 'forceField_000', 'lowFrequency_explosion_000']
    for name in wanted:
        (audio / (name + '.ogg')).write_bytes(z.read('Audio/' + name + '.ogg'))
    (audio / 'KENNEY-LICENSE.txt').write_bytes(z.read('License.txt'))

def decode(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '1', '-ar', '44100', '-'])
    return np.frombuffer(raw, dtype='<f4').copy()

def write(name, data):
    data = np.nan_to_num(data)
    data -= np.mean(data)
    peak = max(.01, np.max(np.abs(data)))
    data *= .82 / peak
    with wave.open(str(audio / (name + '.wav')), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
        w.writeframes((data * 32767).astype('<i2').tobytes())

# Use a steady section from the supplied collection, with an equal-power seam.
source = decode(audio / 'source/helicopter-aquinn.mp3')
segment = source[int(.45*44100):int(3.65*44100)]
n = int(.22*44100)
blend = np.linspace(0, 1, n)
loop = np.concatenate([segment[n:-n], segment[-n:] * np.cos(blend*np.pi/2) + segment[:n] * np.sin(blend*np.pi/2)])
write('rotor_loop', loop)

# Layer the authored cannon transient with a licensed metallic action for heft.
cannon = decode(root/'assets/cannon.wav')
metal = decode(audio/'impactMetal_000.ogg')
out = np.zeros(max(len(cannon), len(metal)))
out[:len(cannon)] += cannon*.85
out[:len(metal)] += metal*.3
write('cannon_heavy', out)
engine = decode(audio/'thrusterFire_000.ogg')
write('rocket_launch', engine)

# Original warning and confirmation cues.
for name, freq, duration in [('lock', 880, .10), ('warning', 430, .32), ('reward', 660, .3), ('click', 1100, .055)]:
    t = np.arange(int(duration*44100))/44100
    y = np.sin(2*np.pi*freq*t) * np.sin(np.pi*t/duration)**2
    if name == 'reward': y += .5*np.sin(2*np.pi*freq*1.5*t)*np.sin(np.pi*t/duration)**2
    write(name, y)

N = 512
rng = np.random.default_rng(573)
def periodic_noise(cells):
    grid = rng.random((cells,cells))
    q = np.arange(N)/N*cells
    i = np.floor(q).astype(int); f = q-i; f = f*f*(3-2*f)
    a = grid[i[:,None]%cells,i[None,:]%cells]
    b = grid[i[:,None]%cells,(i[None,:]+1)%cells]
    c = grid[(i[:,None]+1)%cells,i[None,:]%cells]
    d = grid[(i[:,None]+1)%cells,(i[None,:]+1)%cells]
    return (a*(1-f)[None,:]+b*f[None,:])*(1-f)[:,None]+(c*(1-f)[None,:]+d*f[None,:])*f[:,None]

for name, low, high in [('sand',(.28,.22,.13),(.64,.51,.32)), ('rock',(.15,.17,.18),(.45,.47,.44)), ('snow',(.57,.66,.70),(.9,.94,.95)), ('ash',(.07,.075,.08),(.27,.25,.23)), ('metal',(.1,.14,.13),(.25,.31,.25))]:
    h = sum(periodic_noise(c)*w for c,w in [(4,.35),(16,.3),(64,.2),(128,.15)])
    if name == 'sand':
        x,y=np.meshgrid(np.arange(N)/N,np.arange(N)/N)
        h = h*.7 + .15*(np.sin(x*48*np.pi+periodic_noise(8)*4)+1)
    if name == 'metal':
        h[::128,:]*=.45; h[:,::128]*=.45
    c=np.array(low)[None,None,:]+h[:,:,None]*(np.array(high)-low)[None,None,:]
    Image.fromarray(np.uint8(np.clip(c,0,1)*255)).save(textures/(name+'_color.png'))
    dx=(np.roll(h,-1,axis=1)-np.roll(h,1,axis=1))*2.2
    dy=(np.roll(h,-1,axis=0)-np.roll(h,1,axis=0))*2.2
    normal=np.stack([-dx,-dy,np.ones_like(h)],axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    Image.fromarray(np.uint8((normal*.5+.5)*255)).save(textures/(name+'_normal.png'))
    Image.fromarray(np.uint8(np.clip(.75+h*.22,0,1)*255)).save(textures/(name+'_rough.png'))
print('Prepared CC0 audio edits, original cues, and 15 seamless texture maps.')
