"""Original short synth/brass victory cue for Dust Front."""
from pathlib import Path
import numpy as np
import wave

sr=32000
out=np.zeros(sr*12)
def note(midi,start,duration,gain):
    t=np.arange(int(sr*duration))/sr
    f=440*2**((midi-69)/12)
    env=np.minimum(t/.035,1)*np.minimum((duration-t)/.7,1)
    signal=sum(np.sin(2*np.pi*f*h*t)/h**1.5 for h in range(1,6))*env*gain
    begin=int(start*sr)
    out[begin:begin+len(signal)]+=signal[:len(out)-begin]
for chord,start in [([50,57,62,65],0),([46,53,58,62],2),([48,55,60,64],4),([50,57,62,66,69],6)]:
    for midi in chord: note(midi,start,4,.045)
for midi,start in [(74,0),(77,.5),(81,1),(86,1.5),(84,2.5),(81,3),(79,4),(81,4.5),(86,6)]:
    note(midi,start,2 if start<6 else 4,.11)
out=np.tanh(out)
out*=.75/max(abs(out))
path=Path(__file__).resolve().parents[1]/'assets/audio/victory_theme.wav'
with wave.open(str(path),'wb') as wav:
    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(sr)
    wav.writeframes((out*32767).astype('<i2').tobytes())
print('Victory cue: 12 seconds, original composition')
