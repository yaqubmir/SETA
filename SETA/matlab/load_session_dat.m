% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
function data = load_session_dat(folderPath, sessionPrefix, varargin)
% LOAD_SESSION_DAT Load EEG session from per-channel DAT files
%
% Example:
% data = load_session_dat(folderPath, 'B1_W1_D1_04092025(1)', ...
%     'Fs', 1000, 'NumChannels', 8, 'DataType', 'int16');

p = inputParser;
addParameter(p, 'Fs', 1000);
addParameter(p, 'NumChannels', 8);
addParameter(p, 'DataType', 'int16');
addParameter(p, 'ByteOrder', 'ieee-le');
parse(p, varargin{:});
opts = p.Results;

if ~isfolder(folderPath)
    error('Folder does not exist: %s', folderPath);
end

signals = cell(1, opts.NumChannels);
fileList = cell(1, opts.NumChannels);

for ch = 1:opts.NumChannels
    pattern = sprintf('%s*_Ch%dBiopot_%dHz.dat', sessionPrefix, ch, opts.Fs);
    f = dir(fullfile(folderPath, pattern));

    if isempty(f)
        error('Missing DAT file for channel %d with pattern: %s', ch, pattern);
    end

    filePath = fullfile(folderPath, f(1).folder, f(1).name);
    if ~isfile(filePath)
        filePath = fullfile(folderPath, f(1).name);
    end
    fileList{ch} = filePath;

    fid = fopen(filePath, 'r', opts.ByteOrder);
    if fid < 0
        error('Could not open file: %s', filePath);
    end

    raw = fread(fid, inf, opts.DataType);
    fclose(fid);

    if isempty(raw)
        error('No data read from file: %s', filePath);
    end

    signals{ch} = double(raw(:)) / 1000;
end

lengths = cellfun(@numel, signals);
minLen = min(lengths);

if any(lengths ~= minLen)
    warning('Channel lengths differ. Truncating all channels to %d samples.', minLen);
end

X = zeros(minLen, opts.NumChannels);
for ch = 1:opts.NumChannels
    X(:, ch) = signals{ch}(1:minLen);
end

data.signal = X;
data.fs = opts.Fs;
data.time = (0:minLen-1)' / opts.Fs;
data.channels = arrayfun(@(k) sprintf('Ch%d', k), 1:opts.NumChannels, 'UniformOutput', false);
data.files = fileList;
data.sessionPrefix = sessionPrefix;
end