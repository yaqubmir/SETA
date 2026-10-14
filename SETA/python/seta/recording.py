"""Strict EDF/DAT loading. Copyright (C) 2026 Mohd Yaqub Mir. GPL-3.0-only."""
from dataclasses import dataclass
from pathlib import Path
import re
import numpy as np


@dataclass
class Recording:
    name: str
    data: np.ndarray
    fs: float
    channels: list
    units: list
    channel_numbers: list
    source: str

    @property
    def duration(self):
        return len(self.data)/self.fs


def load_dat(path, fs=1000., dtype='float32', scale=1.):
    path = Path(path)
    if not np.isfinite(fs) or fs <= 0 or not np.isfinite(scale):
        raise ValueError('Specify a valid DAT sample rate and scale.')
    if dtype not in ('float32','int16','float64'):
        raise ValueError('Supported DAT types: float32, int16, float64 (little-endian).')
    dt = np.dtype(dtype).newbyteorder('<')
    if path.stat().st_size % dt.itemsize:
        raise ValueError('DAT size is not a whole number of samples for this encoding.')
    x = np.fromfile(path, dtype=dt).astype(float)*scale
    if not len(x) or not np.isfinite(x).all():
        raise ValueError('DAT is empty or contains non-finite samples; verify encoding.')
    match = re.search(r'_Ch(\d+)Biopot_',path.name)
    ch = int(match[1]) if match else 1
    return Recording(path.name,x[:,None],float(fs),[f'Ch{ch}'],['scaled DAT units'],[ch],str(path))


def load_dat_session(folder, prefix, fs=1000., dtype='float32', scale=.001, channels=8):
    recordings=[]
    for ch in range(1,channels+1):
        matches=sorted(Path(folder).glob(f'{prefix}*_Ch{ch}Biopot_{fs:g}Hz.dat'))
        if len(matches)!=1:
            raise ValueError(f'Expected exactly one DAT for Ch{ch}; found {len(matches)}.')
        recordings.append(load_dat(matches[0],fs,dtype,scale))
    lengths={len(r.data) for r in recordings}
    if len(lengths)!=1:
        raise ValueError('Grouped DAT channels have unequal lengths; align them before loading.')
    return Recording(prefix,np.column_stack([r.data[:,0] for r in recordings]),float(fs),
                     [f'Ch{ch}' for ch in range(1,channels+1)],['scaled DAT units']*channels,
                     list(range(1,channels+1)),str(Path(folder)))


def load_edf(path):
    """Read continuous 16-bit EDF/EDF+C; reject discontinuity and mixed EEG rates."""
    path=Path(path)
    with path.open('rb') as f:
        fixed=f.read(256)
        if len(fixed)!=256 or fixed[:8].strip()!=b'0':
            raise ValueError('Expected standard 16-bit EDF, not BDF or another format.')
        if b'EDF+D' in fixed[192:236]:
            raise ValueError('Discontinuous EDF+D is not supported; do not flatten gaps.')
        n=int(fixed[252:256]); header=int(fixed[184:192]); records=int(fixed[236:244]); sec=float(fixed[244:252])
        if not 1<=n<=512 or header<256+256*n or not np.isfinite(sec) or sec<=0:
            raise ValueError('Invalid EDF header.')
        fields={}
        for name,width in [('labels',16),('transducer',80),('units',8),('pmin',8),('pmax',8),
                           ('dmin',8),('dmax',8),('prefilter',80),('samples',8),('reserved',32)]:
            block=f.read(n*width)
            if len(block)!=n*width: raise ValueError('Truncated EDF header.')
            fields[name]=[block[i*width:(i+1)*width].decode('ascii',errors='replace').strip() for i in range(n)]
        counts=np.array([int(v) for v in fields['samples']])
        if np.any(counts<=0): raise ValueError('Invalid EDF samples per record.')
        total=int(counts.sum()); available=path.stat().st_size-header
        if available<0 or available%(total*2): raise ValueError('Truncated EDF data record.')
        actual=available//(total*2)
        if records==-1: records=actual
        if records<=0 or records!=actual: raise ValueError('EDF record count does not match file size.')
        f.seek(header)
        raw=np.fromfile(f,dtype='<i2').reshape(records,total)
    keep=[i for i,label in enumerate(fields['labels']) if 'annotations' not in label.lower()]
    preferred=[i for i in keep if re.search(r'biopot|eeg|^ch',fields['labels'][i],re.I)]
    keep=preferred or keep
    if not keep or len(set(counts[keep]))!=1:
        raise ValueError('No EEG channels or differing EEG sample rates; select/resample externally.')
    offsets=np.r_[0,np.cumsum(counts)]
    arrays=[]
    for i in keep:
        pmin,pmax,dmin,dmax=(float(fields[key][i]) for key in ('pmin','pmax','dmin','dmax'))
        if not np.isfinite([pmin,pmax,dmin,dmax]).all() or dmax<=dmin or pmax<=pmin:
            raise ValueError(f'Invalid amplitude calibration for {fields["labels"][i]}.')
        digit=raw[:,offsets[i]:offsets[i+1]].reshape(-1).astype(float)
        arrays.append((digit-dmin)*(pmax-pmin)/(dmax-dmin)+pmin)
    return Recording(path.name,np.column_stack(arrays),counts[keep[0]]/sec,
                     [fields['labels'][i] for i in keep],[fields['units'][i] for i in keep],
                     [i+1 for i in keep],str(path))


def load(path, **kwargs):
    return load_edf(path) if Path(path).suffix.lower()=='.edf' else load_dat(path,**kwargs)
