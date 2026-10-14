"""Generate clearly labelled synthetic EEG for testing SETA, not research results."""
from pathlib import Path
import numpy as np
out=Path(__file__).parent/'demo'
out.mkdir(exist_ok=True)
fs=1000; t=np.arange(30*fs)/fs; rng=np.random.default_rng(42)
x=rng.normal(0,.03,len(t))
for onset in np.arange(12,18,.2):x+=2*np.exp(-((t-onset)/.025)**2)*np.sin(2*np.pi*30*t)
x.astype('<f4').tofile(out/'SYNTHETIC_Ch1Biopot_1000Hz.dat')
print('Synthetic demo saved. Open as single DAT: 1000 Hz, float32, scale 1.')
