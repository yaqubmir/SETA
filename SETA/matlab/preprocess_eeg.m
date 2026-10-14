% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
function y = preprocess_eeg(x, fs, bandHz, notchHz)
% PREPROCESS_EEG Bandpass + notch filtering
% Keeps original toolbox-based behavior when available.
% Falls back to FFT filtering if Signal Processing Toolbox functions
% are unavailable on another computer.
%
% x: [N x C]

if nargin < 3 || isempty(bandHz)
    bandHz = [1 100];
end
if nargin < 4 || isempty(notchHz)
    notchHz = 50; % or 60 depending on mains frequency
end

x = double(x);
y = x;

useToolboxBandpass = (exist('designfilt','file') == 2);
useToolboxNotch    = (exist('iirnotch','file') == 2);

% =========================================================
% Bandpass
% =========================================================
if useToolboxBandpass
    bp = designfilt('bandpassiir', ...
        'FilterOrder', 6, ...
        'HalfPowerFrequency1', bandHz(1), ...
        'HalfPowerFrequency2', bandHz(2), ...
        'SampleRate', fs);

    for c = 1:size(y,2)
        y(:,c) = filtfilt(bp, y(:,c));
    end
else
    warning('preprocess_eeg:NoDesignfilt', ...
        'designfilt not available. Using FFT bandpass fallback.');
    for c = 1:size(y,2)
        y(:,c) = fft_bandpass(y(:,c), fs, bandHz(1), bandHz(2));
    end
end

% =========================================================
% Notch
% =========================================================
if useToolboxNotch
    wo = notchHz/(fs/2);
    bw = wo/35;
    [b,a] = iirnotch(wo, bw);

    for c = 1:size(y,2)
        y(:,c) = filtfilt(b, a, y(:,c));
    end
else
    warning('preprocess_eeg:NoIIRNotch', ...
        'iirnotch not available. Using FFT notch fallback.');
    for c = 1:size(y,2)
        y(:,c) = fft_notch(y(:,c), fs, notchHz, 1.0);

        if 2*notchHz < fs/2
            y(:,c) = fft_notch(y(:,c), fs, 2*notchHz, 1.0);
        end
        if 3*notchHz < fs/2
            y(:,c) = fft_notch(y(:,c), fs, 3*notchHz, 1.0);
        end
    end
end

end

% =========================================================
function y = fft_bandpass(x, fs, fLow, fHigh)
x = double(x(:));
N = numel(x);

X = fft(x);
freqs = (0:N-1)' * fs / N;

maskPos = (freqs >= fLow & freqs <= fHigh);
maskNeg = (freqs >= fs - fHigh & freqs <= fs - fLow);
mask = maskPos | maskNeg;

X(~mask) = 0;
y = real(ifft(X));
end

% =========================================================
function y = fft_notch(x, fs, f0, halfWidthHz)
x = double(x(:));
N = numel(x);

X = fft(x);
freqs = (0:N-1)' * fs / N;

mask1 = abs(freqs - f0) <= halfWidthHz;
mask2 = abs(freqs - (fs - f0)) <= halfWidthHz;
mask = mask1 | mask2;

X(mask) = 0;
y = real(ifft(X));
end
