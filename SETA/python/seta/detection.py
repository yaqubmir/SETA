"""Port of detect_events_with_params.m; numerical parity is not yet certified.
Copyright (C) 2026 Mohd Yaqub Mir. SPDX-License-Identifier: GPL-3.0-only
"""
from dataclasses import dataclass, asdict
import math
import numpy as np
from scipy import signal as sp


@dataclass
class Parameters:
    EDGE_TRIM_MIN: float = 1
    PRESERVE_ORIGINAL_TIME: bool = True
    SGOLAY_ORDER: int = 1
    SGOLAY_FRAME_LEN: int = 15
    LOW_BAND: tuple = (3, 12)
    GAMMA_BAND: tuple = (20, 50)
    BROAD_BAND: tuple = (1, 80)
    SPIKE_BAND: tuple = (15, 80)
    SPIKE_MAD_MULT: float = 4
    MIN_SPIKE_DISTANCE_MS: float = 80
    MIN_SPIKE_WIDTH_MS: float = 15
    MAX_SPIKE_WIDTH_MS: float = 500
    MAX_INTERSPIKE_SEC: float = .5
    CLUSTER_PAD_SEC: float = 1
    MERGE_GAP_SEC: float = 2
    MIN_EPISODE_DURATION_SEC: float = 15
    MIN_SPIKE_FREQ_HZ: float = 2.5
    SCORE_SMOOTH_SEC: float = 2
    POWER_SMOOTH_SEC: float = 1
    W_SPIKE_DENSITY: float = 1.2
    W_BROAD: float = .8
    W_GAMMA: float = .6
    W_LOW: float = .5
    BASELINE_SEC: float = 60
    CONV_THR_MAD_MULT: float = 5

    def validate(self, fs):
        if not math.isfinite(fs) or fs <= 0:
            raise ValueError('Sampling rate must be positive.')
        for key, value in asdict(self).items():
            if key.endswith('_BAND'):
                if len(value) != 2 or not 0 < value[0] < value[1] < fs/2:
                    raise ValueError(f'{key} must satisfy 0 < low < high < Nyquist ({fs/2:g}).')
            elif key != 'PRESERVE_ORIGINAL_TIME':
                if not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                    raise ValueError(f'{key} must be a finite nonnegative number.')
        if self.BASELINE_SEC <= 0:
            raise ValueError('BASELINE_SEC must be positive.')
        if self.SGOLAY_ORDER != int(self.SGOLAY_ORDER) or self.SGOLAY_FRAME_LEN != int(self.SGOLAY_FRAME_LEN):
            raise ValueError('Savitzky–Golay order/frame must be integers.')
        if self.MIN_SPIKE_WIDTH_MS > self.MAX_SPIKE_WIDTH_MS:
            raise ValueError('Minimum spike width exceeds maximum.')
        frame = int(self.SGOLAY_FRAME_LEN) | 1
        if self.SGOLAY_ORDER >= frame:
            raise ValueError('Savitzky–Golay order must be below frame length.')


def nround(x):
    return int(math.floor(x + .5))


def movmean(x, width):
    """MATLAB centered movmean, shrink endpoints, even window centered left."""
    x = np.asarray(x, dtype=float)
    width = max(1, nround(width))
    indexes = np.arange(len(x))
    left = np.maximum(0, indexes - width//2)
    right = np.minimum(len(x), indexes + (width-1)//2 + 1)
    c = np.r_[0., np.cumsum(x)]
    return (c[right]-c[left])/(right-left)


def mad(x):
    return np.median(np.abs(x-np.median(x)))


def robust_z(x):
    m = mad(x)
    return np.zeros_like(x) if m < np.finfo(float).eps else (x-np.median(x))/m


def bandpass(x, fs, band, order=4):
    if not 0 < band[0] < band[1] < fs/2:
        raise ValueError('Bandpass limits must be positive, ordered, and below Nyquist.')
    # Butterworth bandpass order is twice the prototype order in SciPy.
    sos = sp.butter(order//2, band, btype='bandpass', fs=fs, output='sos')
    return sp.sosfiltfilt(sos, x)


def preprocess(x, fs, band=(5, 80), notch=50):
    y = bandpass(np.asarray(x, float), fs, band, order=6)
    if notch:
        if not 0 < notch < fs/2:
            raise ValueError('Notch must be below Nyquist (or 0 to disable).')
        b, a = sp.iirnotch(notch, 35, fs=fs)
        y = sp.filtfilt(b, a, y)
    return y


def detect(x, fs, params=None):
    p = params or Parameters()
    p.validate(fs)
    x = np.asarray(x, dtype=float).reshape(-1)
    frame = int(p.SGOLAY_FRAME_LEN) | 1
    if len(x) < max(frame, 32) or not np.isfinite(x).all():
        raise ValueError('Detection requires at least 32 finite samples and a full smoothing frame.')
    x = sp.savgol_filter(x, frame, int(p.SGOLAY_ORDER), mode='interp')
    trim = nround(p.EDGE_TRIM_MIN*60*fs)
    if trim and len(x) > 2*trim:
        x = x[trim:-trim]
    else:
        trim = 0
    if len(x) < 32:
        raise ValueError('Too few samples remain after edge trimming.')
    powers = [robust_z(movmean(bandpass(x, fs, b)**2, max(1, nround(p.POWER_SMOOTH_SEC*fs))))
              for b in (p.LOW_BAND, p.GAMMA_BAND, p.BROAD_BAND)]
    low, gamma, broad = powers
    envelope = np.abs(sp.hilbert(bandpass(x, fs, p.SPIKE_BAND)))
    threshold = np.median(envelope) + p.SPIKE_MAD_MULT*mad(envelope)
    peaks, _ = sp.find_peaks(envelope, height=threshold,
                            distance=max(1, nround(p.MIN_SPIKE_DISTANCE_MS*fs/1000)))
    if len(peaks):
        widths = sp.peak_widths(envelope, peaks, rel_height=.5)[0]
        peaks = peaks[(widths >= p.MIN_SPIKE_WIDTH_MS*fs/1000) &
                      (widths <= p.MAX_SPIKE_WIDTH_MS*fs/1000)]
    mask = np.zeros(len(x)); mask[peaks] = 1
    density = robust_z(movmean(mask, max(1, nround(p.SCORE_SMOOTH_SEC*fs))))
    score = movmean(p.W_SPIKE_DENSITY*density+p.W_BROAD*broad+p.W_GAMMA*gamma+p.W_LOW*low,
                    max(1, nround(p.SCORE_SMOOTH_SEC*fs)))
    baseline = score[:max(1, nround(p.BASELINE_SEC*fs))]
    conv_threshold = np.median(baseline)+p.CONV_THR_MAD_MULT*mad(baseline)
    clusters = []
    if len(peaks):
        starts = np.r_[0, np.flatnonzero(np.diff(peaks)/fs > p.MAX_INTERSPIKE_SEC)+1]
        stops = np.r_[starts[1:]-1, len(peaks)-1]
        pad = nround(p.CLUSTER_PAD_SEC*fs)
        for a,b in zip(starts,stops):
            a,b = max(0,int(peaks[a])-pad), min(len(x)-1,int(peaks[b])+pad)
            if clusters and (a-clusters[-1][1])/fs < p.MERGE_GAP_SEC:
                clusters[-1][1] = max(clusters[-1][1],b)
            else:
                clusters.append([a,b])
    offset = trim/fs if p.PRESERVE_ORIGINAL_TIME else 0.
    events = []
    for a,b in clusters:
        duration = (b-a+1)/fs
        count = int(np.sum((peaks>=a)&(peaks<=b)))
        freq = count/duration
        if duration < p.MIN_EPISODE_DURATION_SEC or freq < p.MIN_SPIKE_FREQ_HZ:
            continue
        peak_score = float(np.max(score[a:b+1]))
        events.append(dict(start_s=a/fs+offset, end_s=b/fs+offset, duration_s=duration,
                           spike_count=count, spike_freq=freq, peak_score=peak_score,
                           mean_score=float(np.mean(score[a:b+1])),
                           mean_low=float(np.mean(low[a:b+1])), mean_gamma=float(np.mean(gamma[a:b+1])),
                           mean_broad=float(np.mean(broad[a:b+1])),
                           type='convulsive' if peak_score>=conv_threshold else 'behavior'))
    return dict(events=events, score=score, spike_locs=peaks, offset_s=offset,
                spike_threshold=float(threshold), convulsive_threshold=float(conv_threshold))
