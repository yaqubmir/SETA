% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
function params = default_detection_params()
params.fs = 1000;

% Preprocessing
params.EDGE_TRIM_MIN = 1;
params.PRESERVE_ORIGINAL_TIME = true;
params.SGOLAY_ORDER = 1;
params.SGOLAY_FRAME_LEN = 15;

% Bands
params.LOW_BAND = [3 12];
params.GAMMA_BAND = [20 50];
params.BROAD_BAND = [1 80];
params.SPIKE_BAND = [15 80];

% Spike detection
params.SPIKE_MAD_MULT = 4.0;
params.MIN_SPIKE_DISTANCE_MS = 80;
params.MIN_SPIKE_WIDTH_MS = 15;
params.MAX_SPIKE_WIDTH_MS = 500;

% Grouping
params.MAX_INTERSPIKE_SEC = 0.5;
params.CLUSTER_PAD_SEC = 1.0;
params.MERGE_GAP_SEC = 2.0;

% Seizure rules
params.MIN_EPISODE_DURATION_SEC = 15;
params.MIN_SPIKE_FREQ_HZ = 2.5;

% Smoothing
params.SCORE_SMOOTH_SEC = 2.0;
params.POWER_SMOOTH_SEC = 1.0;

% Weights
params.W_SPIKE_DENSITY = 1.2;
params.W_BROAD = 0.8;
params.W_GAMMA = 0.6;
params.W_LOW = 0.5;

% Thresholding
params.BASELINE_SEC = 60;
params.CONV_THR_MAD_MULT = 5.0;
end