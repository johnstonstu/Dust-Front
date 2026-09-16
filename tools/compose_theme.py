"""Render an original seamless 32-bar electronic menu theme; no external samples."""
from pathlib import Path
import numpy as np
import wave

RATE=32000
BPM=108
BEAT=60/BPM
LENGTH=32*4*BEAT
N=round(LENGTH*RATE)
mix=np.zeros((N,2),dtype=np.float64)
rng=np.random.default_rng(31415)

def note_freq(midi): return 440*2**((midi-69)/12)

def add(signal,start,pan=0):
    idx=(np.arange(len(signal))+round(start*RATE))%N
    mix[idx,0]+=signal*np.sqrt((1-pan)/2)
    mix[idx,1]+=signal*np.sqrt((1+pan)/2)

def tone(midi,duration,amp,kind='lead'):
    t=np.arange(round(duration*RATE))/RATE
    f=note_freq(midi)
    if kind=='pad':
        env=np.minimum(t/.7,1)*np.minimum((duration-t)/.8,1)
        s=np.sin(2*np.pi*f*t)+.3*np.sin(2*np.pi*f*1.003*t)+.15*np.sin(4*np.pi*f*t)
    elif kind=='bass':
        env=np.minimum(t/.012,1)*np.exp(-t*4)*np.minimum((duration-t)/.06,1)
        s=np.sin(2*np.pi*f*t)+.22*np.sin(4*np.pi*f*t)
    else:
        env=np.minimum(t/.009,1)*np.exp(-t*5)*np.minimum((duration-t)/.07,1)
        s=np.sin(2*np.pi*f*t)+.3*np.sin(4*np.pi*f*t)+.1*np.sin(6*np.pi*f*t)
    return s*env*amp

chords=[(38,[62,65,69]),(34,[58,62,65]),(41,[60,65,69]),(36,[60,64,67])]
for bar in range(32):
    start=bar*4*BEAT
    root,chord=chords[(bar//2)%4]
    energy=1 if 8<=bar<24 else .65
    for j,note in enumerate(chord): add(tone(note,4*BEAT,.045,'pad'),start,(j-1)*.5)
    for step in range(8):
        at=start+step*BEAT/2
        add(tone(root,BEAT*.7,.16*energy,'bass'),at)
        melody=chord[[0,2,1,2,0,1,2,1][step]]+(12 if bar>=16 else 0)
        lead=tone(melody,BEAT*.65,.07*energy)
        add(lead,at,(-1 if step%2 else 1)*.3)
        add(lead*.3,at+BEAT*.75,.55)
        add(lead*.12,at+BEAT*1.5,-.55)
        t=np.arange(round(.085*RATE))/RATE
        noise=rng.normal(0,1,len(t)); noise=np.diff(noise,prepend=0)
        add(noise*np.exp(-t*65)*.013*energy,at,(-1 if step%2 else 1)*.6)
    for beat in range(4):
        at=start+beat*BEAT
        t=np.arange(round(.35*RATE))/RATE
        kick=np.sin(2*np.pi*(48*t+2.8*(1-np.exp(-t*25))))*np.exp(-t*13)*.35*energy
        add(kick,at)
        if beat%2:
            t=np.arange(round(.2*RATE))/RATE
            snare=(rng.normal(0,1,len(t))*.13+np.sin(2*np.pi*180*t)*.09)*np.exp(-t*20)*energy
            add(snare,at,.1)

# Circular arrangement includes delay tails across the loop boundary.
mix=np.tanh(mix*1.15)
mix*=.78/max(np.max(np.abs(mix)),.001)
path=Path(__file__).resolve().parents[1]/'assets/audio/dust_front_theme.wav'
with wave.open(str(path),'wb') as output:
    output.setnchannels(2); output.setsampwidth(2); output.setframerate(RATE)
    output.writeframes((mix*32767).astype('<i2').tobytes())
print(f'Original menu theme: {LENGTH:.1f}s, stereo, peak {np.max(np.abs(mix)):.2f}')
