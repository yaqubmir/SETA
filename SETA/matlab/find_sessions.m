% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
function sessions = find_sessions(folderPath)
% FIND_SESSIONS
% Returns either:
%   1) DAT session prefixes if DAT groups exist
%   2) EDF filenames if EDF files exist
%
% Priority:
%   - use DAT grouped sessions first
%   - if no DAT sessions found, use EDF files

    sessions = {};

    if ~isfolder(folderPath)
        warning('Folder does not exist: %s', folderPath);
        return;
    end

    % -------------------------------------------------
    % First try DAT session detection
    % -------------------------------------------------
    datFiles = dir(fullfile(folderPath, '*.dat'));

    if ~isempty(datFiles)
        prefixes = {};
        for k = 1:numel(datFiles)
            fname = datFiles(k).name;

            % Example:
            % B1_W1_D1_04092025(1)_Ch1Biopot_1000Hz.dat
            tok = regexp(fname, '^(.*)\_Ch\d+Biopot\_.*\.dat$', 'tokens', 'once');

            if ~isempty(tok)
                prefixes{end+1} = tok{1}; %#ok<AGROW>
            end
        end

        if ~isempty(prefixes)
            sessions = unique(prefixes, 'stable');
            return;
        end
    end

    % -------------------------------------------------
    % If no DAT sessions, try EDF files
    % -------------------------------------------------
    edfFiles = dir(fullfile(folderPath, '*.edf'));

    if ~isempty(edfFiles)
        sessions = {edfFiles.name};
        return;
    end

    % -------------------------------------------------
    % Nothing found
    % -------------------------------------------------
    warning('No DAT sessions or EDF files found in folder: %s', folderPath);
end