% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
function results = detect_events_with_params(signal, fs, params)
signal = double(signal(:))';
results = struct();

if mod(params.SGOLAY_FRAME_LEN, 2) == 0
    params.SGOLAY_FRAME_LEN = params.SGOLAY_FRAME_LEN + 1;
end

% Smooth
signal = sgolayfilt(signal, params.SGOLAY_ORDER, params.SGOLAY_FRAME_LEN);

% Edge trim
trim_samp = round(params.EDGE_TRIM_MIN * 60 * fs);
if trim_samp > 0 && length(signal) > 2*trim_samp
    signal_trim = signal(trim_samp + 1 : end - trim_samp);
else
    signal_trim = signal;
    trim_samp = 0;
end

t = (0:length(signal_trim)-1)/fs;
if params.PRESERVE_ORIGINAL_TIME
    t = t + trim_samp/fs;
end

% Band powers
low   = bandpower_fast_local(signal_trim, fs, params.LOW_BAND);
gamma = bandpower_fast_local(signal_trim, fs, params.GAMMA_BAND);
broad = bandpower_fast_local(signal_trim, fs, params.BROAD_BAND);

low   = movmean(low,   max(1, round(params.POWER_SMOOTH_SEC * fs)));
gamma = movmean(gamma, max(1, round(params.POWER_SMOOTH_SEC * fs)));
broad = movmean(broad, max(1, round(params.POWER_SMOOTH_SEC * fs)));

low_z   = robust_zscore_local(low);
gamma_z = robust_zscore_local(gamma);
broad_z = robust_zscore_local(broad);

% Spike detection
spike_sig = bandpass_simple_local(signal_trim, fs, params.SPIKE_BAND);
spike_env = abs(hilbert(spike_sig));

spike_thr = median(spike_env) + params.SPIKE_MAD_MULT * mad(spike_env, 1);

minDist = max(1, round(params.MIN_SPIKE_DISTANCE_MS * fs / 1000));
[pks, locs, widths] = findpeaks(spike_env, ...
    'MinPeakHeight', spike_thr, ...
    'MinPeakDistance', minDist);

minW = params.MIN_SPIKE_WIDTH_MS * fs / 1000;
maxW = params.MAX_SPIKE_WIDTH_MS * fs / 1000;

keep = widths >= minW & widths <= maxW;
spike_locs = locs(keep);
spike_pks = pks(keep); %#ok<NASGU>

spike_mask = false(size(signal_trim));
spike_mask(spike_locs) = true;

% Composite score
spike_density = movmean(double(spike_mask), max(1, round(params.SCORE_SMOOTH_SEC * fs)));
spike_density_z = robust_zscore_local(spike_density);

score = params.W_SPIKE_DENSITY * spike_density_z + ...
        params.W_BROAD         * broad_z + ...
        params.W_GAMMA         * gamma_z + ...
        params.W_LOW           * low_z;

score = movmean(score, max(1, round(params.SCORE_SMOOTH_SEC * fs)));

% Adaptive convulsive threshold
base_idx = 1:min(length(score), round(params.BASELINE_SEC * fs));
score_base = score(base_idx);
conv_thr = median(score_base) + params.CONV_THR_MAD_MULT * mad(score_base, 1);

% Group spikes into episodes
events = {};
if ~isempty(spike_locs)
    s = spike_locs(1);
    prev = spike_locs(1);

    for k = 2:length(spike_locs)
        isi = (spike_locs(k) - prev) / fs;
        if isi <= params.MAX_INTERSPIKE_SEC
            prev = spike_locs(k);
        else
            events{end+1} = [s prev]; %#ok<AGROW>
            s = spike_locs(k);
            prev = spike_locs(k);
        end
    end
    events{end+1} = [s prev];
end

% Pad clusters
pad_samp = round(params.CLUSTER_PAD_SEC * fs);
for k = 1:length(events)
    events{k}(1) = max(1, events{k}(1) - pad_samp);
    events{k}(2) = min(length(signal_trim), events{k}(2) + pad_samp);
end

% Merge nearby
events = merge_events_local(events, fs, params.MERGE_GAP_SEC);

% Keep seizure-like episodes
final_events = {};
for k = 1:length(events)
    s = events{k}(1);
    e = events{k}(2);
    dur = (e - s + 1) / fs;

    nsp = sum(spike_locs >= s & spike_locs <= e);
    freq = nsp / max(dur, eps);

    if dur >= params.MIN_EPISODE_DURATION_SEC && freq >= params.MIN_SPIKE_FREQ_HZ
        peak_score = max(score(s:e));
        mean_score = mean(score(s:e));

        if peak_score >= conv_thr
            seizure_type = 'convulsive';
        else
            seizure_type = 'behavior';
        end

        final_events{end+1} = struct( ...
            'start_idx', s, ...
            'stop_idx', e, ...
            'start_s', t(s), ...
            'end_s', t(e), ...
            'duration_s', dur, ...
            'spike_count', nsp, ...
            'spike_freq', freq, ...
            'mean_score', mean_score, ...
            'peak_score', peak_score, ...
            'mean_low', mean(low_z(s:e)), ...
            'mean_gamma', mean(gamma_z(s:e)), ...
            'mean_broad', mean(broad_z(s:e)), ...
            'type', seizure_type); %#ok<AGROW>
    end
end

results.signal = signal_trim;
results.time = t;
results.low_z = low_z;
results.gamma_z = gamma_z;
results.broad_z = broad_z;
results.score = score;
results.spike_locs = spike_locs;
results.spike_threshold = spike_thr;
results.convulsive_threshold = conv_thr;
results.events = final_events;
end

function y = bandpass_simple_local(x, fs, band)
d = designfilt('bandpassiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency1', band(1), ...
    'HalfPowerFrequency2', band(2), ...
    'SampleRate', fs);
y = filtfilt(d, x);
end

function power = bandpower_fast_local(signal, fs, band)
y = bandpass_simple_local(signal, fs, band);
power = y.^2;
end

function z = robust_zscore_local(x)
x = x(:)';
medx = median(x);
madx = mad(x, 1);
if madx < eps
    z = zeros(size(x));
else
    z = (x - medx) / madx;
end
end

function merged = merge_events_local(events, fs, mergeGapSec)
merged = {};
if isempty(events)
    return;
end

i = 1;
while i <= length(events)
    s = events{i}(1);
    e = events{i}(2);

    while i < length(events)
        if (events{i+1}(1) - e) / fs < mergeGapSec
            e = max(e, events{i+1}(2));
            i = i + 1;
        else
            break;
        end
    end

    merged{end+1} = [s e]; %#ok<AGROW>
    i = i + 1;
end
end