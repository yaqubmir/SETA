% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
classdef SETAAnnotatorApp < handle
    properties
        UIFigure
        LoadModeDropDown
        SelectSourceButton
        SessionDropDown
        LoadSessionButton
        PrevButton
        NextButton
        WindowEditField
        ViewModeDropDown
        ChannelDropDown
        DisplayModeDropDown
        ViewStartField
        ViewEndField
        GoRangeButton
        StartEditField
        EndEditField
        MarkSeizureButton
        MarkFalseButton
        MarkNormalButton
        PickStartButton
        PickEndButton
        ClearPickButton
        DeleteAnnotationButton
        SaveAnnotationsButton
        StatusLabel
        UIAxes
        AnnotationTable

        IdleLamp
        BusyLamp

        RunDetectionButton
        CandidateTable
        SpikeMadField
        MinEpisodeField
        MinSpikeFreqField
        ConvMadField
        InterSpikeField
        MergeGapField
        CandidatePadField

        EdgeTrimField
        SgolayOrderField
        SgolayFrameField

        LowBand1Field
        LowBand2Field
        GammaBand1Field
        GammaBand2Field
        BroadBand1Field
        BroadBand2Field
        SpikeBand1Field
        SpikeBand2Field

        MinSpikeDistField
        MinSpikeWidthField
        MaxSpikeWidthField
        MaxDurationField
        DisplayLowField
        DisplayHighField
        ClusterPadField

        ScoreSmoothField
        PowerSmoothField

        WeightSpikeField
        WeightBroadField
        WeightGammaField
        WeightLowField

        BaselineSecField
        PreserveOriginalTimeCheckBox

        DetectCh1
        DetectCh2
        DetectCh3
        DetectCh4
        DetectCh5
        DetectCh6
        DetectCh7
        DetectCh8

        folderPath = ''
        singleDatFile = ''
        sessions = {}
        data = struct()
        y = []
        currentSession = ''
        currentStartSec = 0
        windowSec = 10
        displayBandHz = [5 80]
        annotations table
        currentLoadMode = 'EDF / Session'
        pickMode = ""

        selectedCandidateIdx = NaN
        selectedCandidate = struct()

        params
        detectionResults = struct()
    end

    methods
        function app = SETAAnnotatorApp()
            app.createUI();
            app.params = default_detection_params();
            app.annotations = app.emptyAnnotationTable();
            app.loadParamsToUI();
            app.setRunningState(false);
        end

        function T = emptyAnnotationTable(app)
            T = table([], {}, [], [], [], [], {}, [], {}, [], [], [], [], [], [], [], {}, ...
                'VariableNames', { ...
                'session_idx', ...
                'session_name', ...
                'channel', ...
                'start_s', ...
                'end_s', ...
                'duration_s', ...
                'label', ...
                'candidate_idx', ...
                'candidate_type', ...
                'candidate_spike_count', ...
                'candidate_spike_freq', ...
                'candidate_peak_score', ...
                'candidate_mean_score', ...
                'candidate_mean_low', ...
                'candidate_mean_gamma', ...
                'candidate_mean_broad', ...
                'created_at'});
        end

        function createUI(app)
            app.UIFigure = uifigure('Name', 'SETA Annotator', 'Position', [40 40 1880 980]);

            uilabel(app.UIFigure, 'Text', 'Load Mode', 'Position', [20 930 65 20]);
            app.LoadModeDropDown = uidropdown(app.UIFigure, ...
                'Position', [90 925 130 30], ...
                'Items', {'EDF / Session','Single DAT'}, ...
                'Value', 'EDF / Session', ...
                'ValueChangedFcn', @(~,~)app.onLoadModeChanged());

            app.SelectSourceButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Select Source', ...
                'Position', [235 925 120 30], ...
                'ButtonPushedFcn', @(~,~)app.onSelectSource());

            uilabel(app.UIFigure, 'Text', 'Session / File', 'Position', [375 930 75 20]);
            app.SessionDropDown = uidropdown(app.UIFigure, ...
                'Position', [455 925 300 30], ...
                'Items', {''}, ...
                'Value', '', ...
                'ValueChangedFcn', @(~,~)app.onSessionChanged());
            app.LoadSessionButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Load', ...
                'Position', [770 925 80 30], ...
                'ButtonPushedFcn', @(~,~)app.onLoadSession());

            app.PrevButton = uibutton(app.UIFigure, 'push', ...
                'Text', '<< Prev', ...
                'Position', [870 925 80 30], ...
                'ButtonPushedFcn', @(~,~)app.onPrevWindow());

            app.NextButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Next >>', ...
                'Position', [960 925 80 30], ...
                'ButtonPushedFcn', @(~,~)app.onNextWindow());

            uilabel(app.UIFigure, 'Text', 'Window (s)', 'Position', [1060 930 70 20]);
            app.WindowEditField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [1135 925 60 30], ...
                'Value', 10, ...
                'ValueChangedFcn', @(~,~)app.onWindowChanged());

            uilabel(app.UIFigure, 'Text', 'Display', 'Position', [1210 930 45 20]);
            app.DisplayModeDropDown = uidropdown(app.UIFigure, ...
                'Position', [1260 925 95 30], ...
                'Items', {'Raw','Preprocessed'}, ...
                'Value', 'Raw', ...
                'ValueChangedFcn', @(~,~)app.plotCurrentWindow());

            uilabel(app.UIFigure, 'Text', 'View', 'Position', [1370 930 35 20]);
            app.ViewModeDropDown = uidropdown(app.UIFigure, ...
                'Position', [1410 925 110 30], ...
                'Items', {'All Channels','Single Channel'}, ...
                'Value', 'All Channels', ...
                'ValueChangedFcn', @(~,~)app.onViewModeChanged());

            uilabel(app.UIFigure, 'Text', 'Channel', 'Position', [1535 930 50 20]);
            app.ChannelDropDown = uidropdown(app.UIFigure, ...
                'Position', [1590 925 70 30], ...
                'Items', {'All','1','2','3','4','5','6','7','8'}, ...
                'Value', 'All', ...
                'ValueChangedFcn', @(~,~)app.plotCurrentWindow());

            app.RunDetectionButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Run Detection', ...
                'Position', [1675 925 120 30], ...
                'ButtonPushedFcn', @(~,~)app.onRunDetection());

            app.BusyLamp = uilamp(app.UIFigure, ...
                'Position', [1810 928 18 18], ...
                'Color', [0.6 0.6 0.6]);

            app.IdleLamp = uilamp(app.UIFigure, ...
                'Position', [1810 898 18 18], ...
                'Color', [0 1 0]);

            uilabel(app.UIFigure, 'Text', 'Ann Start (s)', 'Position', [20 885 70 20]);
            app.StartEditField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [90 880 70 30], ...
                'Value', 0, ...
                'ValueChangedFcn', @(~,~)app.plotCurrentWindow());

            uilabel(app.UIFigure, 'Text', 'Ann End (s)', 'Position', [170 885 65 20]);
            app.EndEditField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [235 880 70 30], ...
                'Value', 5, ...
                'ValueChangedFcn', @(~,~)app.plotCurrentWindow());

            app.MarkSeizureButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Mark Seizure', ...
                'Position', [340 880 110 30], ...
                'ButtonPushedFcn', @(~,~)app.addAnnotation('Seizure'));

            app.MarkFalseButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Mark False', ...
                'Position', [465 880 100 30], ...
                'ButtonPushedFcn', @(~,~)app.addAnnotation('False'));

            app.MarkNormalButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Mark Normal', ...
                'Position', [580 880 110 30], ...
                'ButtonPushedFcn', @(~,~)app.addAnnotation('Normal'));

            app.PickStartButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Pick Start', ...
                'Position', [705 880 95 30], ...
                'ButtonPushedFcn', @(~,~)app.onPickStart());

            app.PickEndButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Pick End', ...
                'Position', [810 880 90 30], ...
                'ButtonPushedFcn', @(~,~)app.onPickEnd());

            app.ClearPickButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Clear Pick', ...
                'Position', [910 880 90 30], ...
                'ButtonPushedFcn', @(~,~)app.onClearPick());

            app.DeleteAnnotationButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Delete Selected', ...
                'Position', [1010 880 120 30], ...
                'ButtonPushedFcn', @(~,~)app.onDeleteAnnotation());

            app.SaveAnnotationsButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Save Annotations', ...
                'Position', [1140 880 130 30], ...
                'ButtonPushedFcn', @(~,~)app.onSaveAnnotations());

            uilabel(app.UIFigure, 'Text', 'View Start', 'Position', [1290 885 60 20]);
            app.ViewStartField = uieditfield(app.UIFigure, 'text', ...
                'Position', [1350 880 90 30], ...
                'Value', '00:00:00');

            uilabel(app.UIFigure, 'Text', 'View End', 'Position', [1450 885 55 20]);
            app.ViewEndField = uieditfield(app.UIFigure, 'text', ...
                'Position', [1505 880 90 30], ...
                'Value', '00:00:10');

            app.GoRangeButton = uibutton(app.UIFigure, 'push', ...
                'Text', 'Go', ...
                'Position', [1600 880 50 30], ...
                'ButtonPushedFcn', @(~,~)app.onGoToRange());

            app.StatusLabel = uilabel(app.UIFigure, ...
                'Text', 'Status: Ready', ...
                'Position', [1660 885 190 20]);

            uipanel(app.UIFigure, 'Title', 'Detection Parameters', ...
                'Position', [20 720 1820 145]);

            uilabel(app.UIFigure, 'Text', 'Spike MAD', 'Position', [35 810 65 20]);
            app.SpikeMadField = uieditfield(app.UIFigure, 'numeric', 'Position', [105 805 70 28]);

            uilabel(app.UIFigure, 'Text', 'Min Episode (s)', 'Position', [185 810 90 20]);
            app.MinEpisodeField = uieditfield(app.UIFigure, 'numeric', 'Position', [280 805 70 28]);

            uilabel(app.UIFigure, 'Text', 'Min Spike Freq', 'Position', [360 810 90 20]);
            app.MinSpikeFreqField = uieditfield(app.UIFigure, 'numeric', 'Position', [455 805 70 28]);

            uilabel(app.UIFigure, 'Text', 'Conv MAD', 'Position', [535 810 65 20]);
            app.ConvMadField = uieditfield(app.UIFigure, 'numeric', 'Position', [605 805 70 28]);

            uilabel(app.UIFigure, 'Text', 'InterSpike (s)', 'Position', [695 810 85 20]);
            app.InterSpikeField = uieditfield(app.UIFigure, 'numeric', 'Position', [785 805 70 28]);

            uilabel(app.UIFigure, 'Text', 'Merge Gap (s)', 'Position', [875 810 85 20]);
            app.MergeGapField = uieditfield(app.UIFigure, 'numeric', 'Position', [965 805 70 28]);

            uilabel(app.UIFigure, 'Text', 'Context Pad (s)', 'Position', [1045 810 85 20]);
            app.CandidatePadField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [1135 805 70 28], ...
                'Value', 10);

            uilabel(app.UIFigure, 'Text', 'Edge Trim (min)', 'Position', [35 775 90 20]);
            app.EdgeTrimField = uieditfield(app.UIFigure, 'numeric', 'Position', [130 770 55 28]);

            uilabel(app.UIFigure, 'Text', 'SG Order', 'Position', [195 775 55 20]);
            app.SgolayOrderField = uieditfield(app.UIFigure, 'numeric', 'Position', [255 770 45 28]);

            uilabel(app.UIFigure, 'Text', 'SG Frame', 'Position', [310 775 55 20]);
            app.SgolayFrameField = uieditfield(app.UIFigure, 'numeric', 'Position', [370 770 50 28]);

            uilabel(app.UIFigure, 'Text', 'Low Band', 'Position', [440 775 55 20]);
            app.LowBand1Field = uieditfield(app.UIFigure, 'numeric', 'Position', [500 770 42 28]);
            app.LowBand2Field = uieditfield(app.UIFigure, 'numeric', 'Position', [547 770 42 28]);

            uilabel(app.UIFigure, 'Text', 'Gamma Band', 'Position', [605 775 75 20]);
            app.GammaBand1Field = uieditfield(app.UIFigure, 'numeric', 'Position', [685 770 42 28]);
            app.GammaBand2Field = uieditfield(app.UIFigure, 'numeric', 'Position', [732 770 42 28]);

            uilabel(app.UIFigure, 'Text', 'Broad Band', 'Position', [790 775 70 20]);
            app.BroadBand1Field = uieditfield(app.UIFigure, 'numeric', 'Position', [865 770 42 28]);
            app.BroadBand2Field = uieditfield(app.UIFigure, 'numeric', 'Position', [912 770 42 28]);

            uilabel(app.UIFigure, 'Text', 'Spike Band', 'Position', [970 775 70 20]);
            app.SpikeBand1Field = uieditfield(app.UIFigure, 'numeric', 'Position', [1045 770 42 28]);
            app.SpikeBand2Field = uieditfield(app.UIFigure, 'numeric', 'Position', [1092 770 42 28]);

            uilabel(app.UIFigure, 'Text', 'MinDist', 'Position', [1145 775 50 20]);
            app.MinSpikeDistField = uieditfield(app.UIFigure, 'numeric', 'Position', [1195 770 45 28]);

            uilabel(app.UIFigure, 'Text', 'MinW', 'Position', [1250 775 40 20]);
            app.MinSpikeWidthField = uieditfield(app.UIFigure, 'numeric', 'Position', [1290 770 45 28]);

            uilabel(app.UIFigure, 'Text', 'MaxW', 'Position', [1345 775 40 20]);
            app.MaxSpikeWidthField = uieditfield(app.UIFigure, 'numeric', 'Position', [1385 770 45 28]);

            uilabel(app.UIFigure, 'Text', 'Max Dur (s)', 'Position', [1210 810 70 20]);
            app.MaxDurationField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [1280 805 55 28], ...
                'Value', 120);

            uilabel(app.UIFigure, 'Text', 'Disp BP', 'Position', [1210 740 55 20]);
            app.DisplayLowField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [1265 735 45 28], ...
                'Value', 5, ...
                'ValueChangedFcn', @(~,~)app.onDisplayBandChanged());
            app.DisplayHighField = uieditfield(app.UIFigure, 'numeric', ...
                'Position', [1315 735 45 28], ...
                'Value', 80, ...
                'ValueChangedFcn', @(~,~)app.onDisplayBandChanged());

            uilabel(app.UIFigure, 'Text', 'Detect:', ...
                'Position', [1450 775 45 20]);

            app.DetectCh1 = uicheckbox(app.UIFigure, ...
                'Text', '1', 'Position', [1495 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh2 = uicheckbox(app.UIFigure, ...
                'Text', '2', 'Position', [1530 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh3 = uicheckbox(app.UIFigure, ...
                'Text', '3', 'Position', [1565 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh4 = uicheckbox(app.UIFigure, ...
                'Text', '4', 'Position', [1600 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh5 = uicheckbox(app.UIFigure, ...
                'Text', '5', 'Position', [1635 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh6 = uicheckbox(app.UIFigure, ...
                'Text', '6', 'Position', [1670 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh7 = uicheckbox(app.UIFigure, ...
                'Text', '7', 'Position', [1705 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());
            app.DetectCh8 = uicheckbox(app.UIFigure, ...
                'Text', '8', 'Position', [1740 775 35 20], ...
                'Value', true, ...
                'ValueChangedFcn', @(~,~)app.onDetectionChannelSelectionChanged());

            uilabel(app.UIFigure, 'Text', 'ClusterPad', 'Position', [35 740 70 20]);
            app.ClusterPadField = uieditfield(app.UIFigure, 'numeric', 'Position', [110 735 50 28]);

            uilabel(app.UIFigure, 'Text', 'ScoreSmooth', 'Position', [170 740 75 20]);
            app.ScoreSmoothField = uieditfield(app.UIFigure, 'numeric', 'Position', [250 735 50 28]);

            uilabel(app.UIFigure, 'Text', 'PowerSmooth', 'Position', [310 740 80 20]);
            app.PowerSmoothField = uieditfield(app.UIFigure, 'numeric', 'Position', [395 735 50 28]);

            uilabel(app.UIFigure, 'Text', 'W Spike', 'Position', [460 740 50 20]);
            app.WeightSpikeField = uieditfield(app.UIFigure, 'numeric', 'Position', [515 735 45 28]);

            uilabel(app.UIFigure, 'Text', 'W Broad', 'Position', [575 740 55 20]);
            app.WeightBroadField = uieditfield(app.UIFigure, 'numeric', 'Position', [635 735 45 28]);

            uilabel(app.UIFigure, 'Text', 'W Gamma', 'Position', [695 740 60 20]);
            app.WeightGammaField = uieditfield(app.UIFigure, 'numeric', 'Position', [760 735 45 28]);

            uilabel(app.UIFigure, 'Text', 'W Low', 'Position', [820 740 45 20]);
            app.WeightLowField = uieditfield(app.UIFigure, 'numeric', 'Position', [870 735 45 28]);

            uilabel(app.UIFigure, 'Text', 'Baseline s', 'Position', [935 740 60 20]);
            app.BaselineSecField = uieditfield(app.UIFigure, 'numeric', 'Position', [1000 735 50 28]);

            app.PreserveOriginalTimeCheckBox = uicheckbox(app.UIFigure, ...
                'Text', 'Preserve original time', ...
                'Position', [1070 740 160 22]);

            app.UIAxes = uiaxes(app.UIFigure, ...
                'Position', [20 155 1120 545], ...
                'ButtonDownFcn', @(src,event)app.onAxesClicked());
            title(app.UIAxes, 'EEG View');
            xlabel(app.UIAxes, 'Time (hh:mm:ss)');
            ylabel(app.UIAxes, 'Amplitude + offset');

            app.AnnotationTable = uitable(app.UIFigure, ...
                'Position', [1160 430 680 270], ...
                'ColumnName', {'session_idx','session_name','channel','start_s','end_s','dur_s','label', ...
                               'cand_idx','cand_type','cand_spike_count','cand_spike_freq','cand_peak_score', ...
                               'cand_mean_score','cand_mean_low','cand_mean_gamma','cand_mean_broad','created_at'}, ...
                'ColumnEditable', false(1,17), ...
                'Data', cell(0,17));

            app.CandidateTable = uitable(app.UIFigure, ...
                'Position', [1160 170 680 230], ...
                'ColumnName', {'idx','channel','type','start_s','end_s','dur_s','spike_freq','peak_score'}, ...
                'ColumnEditable', false(1,8), ...
                'Data', cell(0,8), ...
                'CellSelectionCallback', @(src,event)app.onCandidateSelected(event));

            uilabel(app.UIFigure, 'Text', ...
                'Tip: Click candidate, refine Start/End, then mark Seizure / False / Normal.', ...
                'Position', [20 125 900 20]);

            app.onLoadModeChanged();
        end

        function setRunningState(app, isRunning)
            if isRunning
                app.BusyLamp.Color = [1 0 0];
                app.IdleLamp.Color = [0.6 0.6 0.6];
            else
                app.BusyLamp.Color = [0.6 0.6 0.6];
                app.IdleLamp.Color = [0 1 0];
            end
            drawnow;
        end

        function onDetectionChannelSelectionChanged(app)
            chs = app.getDetectionChannels();
            if isempty(chs)
                app.updateStatus('No detection channels selected. Click channels to enable detection.');
            else
                chText = strjoin(arrayfun(@(c)sprintf('Ch%d', c), chs, 'UniformOutput', false), ', ');
                app.updateStatus(sprintf('Detection channels selected: %s. Click Run Detection.', chText));
            end
            app.plotCurrentWindow();
        end

        function onPickStart(app)
            app.pickMode = "start";
            app.updateStatus('Pick mode: click waveform to set START.');
        end

        function onPickEnd(app)
            app.pickMode = "end";
            app.updateStatus('Pick mode: click waveform to set END.');
        end

        function onClearPick(app)
            app.pickMode = "";
            app.updateStatus('Pick mode cleared.');
        end

        function onAxesClicked(app)
            if strlength(app.pickMode) == 0
                return;
            end

            cp = app.UIAxes.CurrentPoint;
            xClick = cp(1,1);

            if isempty(app.data) || ~isfield(app.data, 'time') || isempty(app.data.time)
                return;
            end

            xClick = max(0, min(app.data.time(end), xClick));

            switch app.pickMode
                case "start"
                    app.StartEditField.Value = xClick;
                    if app.EndEditField.Value <= app.StartEditField.Value
                        app.EndEditField.Value = min(app.data.time(end), xClick + 1);
                    end
                    app.updateStatus(sprintf('Picked START at %.3f s', xClick));
                case "end"
                    app.EndEditField.Value = xClick;
                    if app.EndEditField.Value <= app.StartEditField.Value
                        app.StartEditField.Value = max(0, xClick - 1);
                    end
                    app.updateStatus(sprintf('Picked END at %.3f s', xClick));
            end

            app.plotCurrentWindow();
        end

        function secs = parseClockTime(app, value)
            if isnumeric(value)
                secs = double(value);
                return;
            end
            s = strtrim(char(string(value)));
            if isempty(s)
                secs = 0;
                return;
            end
            if contains(s, ':')
                parts = sscanf(s, '%f:%f:%f');
                if numel(parts) == 3
                    secs = parts(1)*3600 + parts(2)*60 + parts(3);
                else
                    parts2 = sscanf(s, '%f:%f');
                    if numel(parts2) == 2
                        secs = parts2(1)*60 + parts2(2);
                    else
                        error('Use hh:mm:ss or mm:ss');
                    end
                end
            else
                secs = str2double(s);
                if isnan(secs)
                    error('Use hh:mm:ss or seconds');
                end
            end
        end

        function s = formatClockTime(app, secs)
            secs = max(0, double(secs));
            hh = floor(secs/3600);
            mm = floor(mod(secs,3600)/60);
            ss = floor(mod(secs,60));
            s = sprintf('%02d:%02d:%02d', hh, mm, ss);
        end

        function setViewRangeFields(app, t0, t1)
            app.ViewStartField.Value = app.formatClockTime(t0);
            app.ViewEndField.Value = app.formatClockTime(t1);
        end

        function onGoToRange(app)
            if isempty(app.data) || ~isfield(app.data, 'time') || isempty(app.data.time)
                return;
            end
            try
                t0 = app.parseClockTime(app.ViewStartField.Value);
                t1 = app.parseClockTime(app.ViewEndField.Value);
            catch ME
                uialert(app.UIFigure, ME.message, 'Invalid Time');
                return;
            end

            t0 = max(0, min(t0, app.data.time(end)));
            t1 = max(0, min(t1, app.data.time(end)));
            if t1 <= t0
                uialert(app.UIFigure, 'View End must be greater than View Start.', 'Invalid Range');
                return;
            end

            app.currentStartSec = t0;
            app.windowSec = t1 - t0;
            app.WindowEditField.Value = app.windowSec;
            app.setViewRangeFields(t0, t1);
            app.plotCurrentWindow();
            app.updateStatus(sprintf('Viewing range: %s to %s', app.ViewStartField.Value, app.ViewEndField.Value));
        end

        function loadParamsToUI(app)
            app.SpikeMadField.Value = app.params.SPIKE_MAD_MULT;
            app.MinEpisodeField.Value = app.params.MIN_EPISODE_DURATION_SEC;
            app.MinSpikeFreqField.Value = app.params.MIN_SPIKE_FREQ_HZ;
            app.ConvMadField.Value = app.params.CONV_THR_MAD_MULT;
            app.InterSpikeField.Value = app.params.MAX_INTERSPIKE_SEC;
            app.MergeGapField.Value = app.params.MERGE_GAP_SEC;
            app.EdgeTrimField.Value = app.params.EDGE_TRIM_MIN;
            app.SgolayOrderField.Value = app.params.SGOLAY_ORDER;
            app.SgolayFrameField.Value = app.params.SGOLAY_FRAME_LEN;
            app.LowBand1Field.Value = app.params.LOW_BAND(1);
            app.LowBand2Field.Value = app.params.LOW_BAND(2);
            app.GammaBand1Field.Value = app.params.GAMMA_BAND(1);
            app.GammaBand2Field.Value = app.params.GAMMA_BAND(2);
            app.BroadBand1Field.Value = app.params.BROAD_BAND(1);
            app.BroadBand2Field.Value = app.params.BROAD_BAND(2);
            app.SpikeBand1Field.Value = app.params.SPIKE_BAND(1);
            app.SpikeBand2Field.Value = app.params.SPIKE_BAND(2);
            app.MinSpikeDistField.Value = app.params.MIN_SPIKE_DISTANCE_MS;
            app.MinSpikeWidthField.Value = app.params.MIN_SPIKE_WIDTH_MS;
            app.MaxSpikeWidthField.Value = app.params.MAX_SPIKE_WIDTH_MS;
            app.ClusterPadField.Value = app.params.CLUSTER_PAD_SEC;
            app.ScoreSmoothField.Value = app.params.SCORE_SMOOTH_SEC;
            app.PowerSmoothField.Value = app.params.POWER_SMOOTH_SEC;
            app.WeightSpikeField.Value = app.params.W_SPIKE_DENSITY;
            app.WeightBroadField.Value = app.params.W_BROAD;
            app.WeightGammaField.Value = app.params.W_GAMMA;
            app.WeightLowField.Value = app.params.W_LOW;
            app.BaselineSecField.Value = app.params.BASELINE_SEC;
            app.PreserveOriginalTimeCheckBox.Value = logical(app.params.PRESERVE_ORIGINAL_TIME);
        end

        function readParamsFromUI(app)
            app.params.SPIKE_MAD_MULT = app.SpikeMadField.Value;
            app.params.MIN_EPISODE_DURATION_SEC = app.MinEpisodeField.Value;
            app.params.MIN_SPIKE_FREQ_HZ = app.MinSpikeFreqField.Value;
            app.params.CONV_THR_MAD_MULT = app.ConvMadField.Value;
            app.params.MAX_INTERSPIKE_SEC = app.InterSpikeField.Value;
            app.params.MERGE_GAP_SEC = app.MergeGapField.Value;
            app.params.EDGE_TRIM_MIN = app.EdgeTrimField.Value;
            app.params.SGOLAY_ORDER = app.SgolayOrderField.Value;
            app.params.SGOLAY_FRAME_LEN = app.SgolayFrameField.Value;
            app.params.LOW_BAND = [app.LowBand1Field.Value app.LowBand2Field.Value];
            app.params.GAMMA_BAND = [app.GammaBand1Field.Value app.GammaBand2Field.Value];
            app.params.BROAD_BAND = [app.BroadBand1Field.Value app.BroadBand2Field.Value];
            app.params.SPIKE_BAND = [app.SpikeBand1Field.Value app.SpikeBand2Field.Value];
            app.params.MIN_SPIKE_DISTANCE_MS = app.MinSpikeDistField.Value;
            app.params.MIN_SPIKE_WIDTH_MS = app.MinSpikeWidthField.Value;
            app.params.MAX_SPIKE_WIDTH_MS = app.MaxSpikeWidthField.Value;
            app.params.CLUSTER_PAD_SEC = app.ClusterPadField.Value;
            app.params.SCORE_SMOOTH_SEC = app.ScoreSmoothField.Value;
            app.params.POWER_SMOOTH_SEC = app.PowerSmoothField.Value;
            app.params.W_SPIKE_DENSITY = app.WeightSpikeField.Value;
            app.params.W_BROAD = app.WeightBroadField.Value;
            app.params.W_GAMMA = app.WeightGammaField.Value;
            app.params.W_LOW = app.WeightLowField.Value;
            app.params.BASELINE_SEC = app.BaselineSecField.Value;
            app.params.PRESERVE_ORIGINAL_TIME = logical(app.PreserveOriginalTimeCheckBox.Value);
        end

        function chs = getDetectionChannels(app)
            chs = [];
            if app.DetectCh1.Value, chs(end+1) = 1; end %#ok<AGROW>
            if app.DetectCh2.Value, chs(end+1) = 2; end %#ok<AGROW>
            if app.DetectCh3.Value, chs(end+1) = 3; end %#ok<AGROW>
            if app.DetectCh4.Value, chs(end+1) = 4; end %#ok<AGROW>
            if app.DetectCh5.Value, chs(end+1) = 5; end %#ok<AGROW>
            if app.DetectCh6.Value, chs(end+1) = 6; end %#ok<AGROW>
            if app.DetectCh7.Value, chs(end+1) = 7; end %#ok<AGROW>
            if app.DetectCh8.Value, chs(end+1) = 8; end %#ok<AGROW>
        end

        function tf = isEDFSelection(app, sessionName)
            tf = endsWith(lower(sessionName), '.edf');
        end

        function onLoadModeChanged(app)
            app.currentLoadMode = app.LoadModeDropDown.Value;

            if strcmp(app.currentLoadMode, 'Single DAT')
                app.SelectSourceButton.Text = 'Select DAT File';
                app.ViewModeDropDown.Items = {'Single Channel'};
                app.ViewModeDropDown.Value = 'Single Channel';
                app.ChannelDropDown.Items = {'1','2','3','4','5','6','7','8'};
                app.ChannelDropDown.Value = '1';
                app.ChannelDropDown.Enable = 'on';
            else
                app.SelectSourceButton.Text = 'Select Data Folder';
                app.ViewModeDropDown.Items = {'All Channels','Single Channel'};
                app.ViewModeDropDown.Value = 'All Channels';
                app.ChannelDropDown.Items = {'All','1','2','3','4','5','6','7','8'};
                app.ChannelDropDown.Value = 'All';
                app.ChannelDropDown.Enable = 'off';
            end

            app.SessionDropDown.Items = {};
            app.singleDatFile = '';
            app.sessions = {};
            app.data = struct();
            app.y = [];
            app.detectionResults = struct();
            app.selectedCandidateIdx = NaN;
            app.selectedCandidate = struct();
            app.annotations = app.emptyAnnotationTable();
            app.refreshAnnotationTable();
            cla(app.UIAxes);
            app.CandidateTable.Data = cell(0,8);
            app.updateStatus(['Mode set to: ' app.currentLoadMode]);
            app.setRunningState(false);
        end

        function onViewModeChanged(app)
            if strcmp(app.currentLoadMode, 'Single DAT')
                app.ChannelDropDown.Enable = 'on';
                app.ViewModeDropDown.Value = 'Single Channel';
            else
                if strcmp(app.ViewModeDropDown.Value, 'All Channels')
                    app.ChannelDropDown.Value = 'All';
                    app.ChannelDropDown.Enable = 'off';
                else
                    if strcmp(app.ChannelDropDown.Value, 'All')
                        app.ChannelDropDown.Value = '1';
                    end
                    app.ChannelDropDown.Enable = 'on';
                end
            end
            app.plotCurrentWindow();
        end

        function onSelectSource(app)
            if strcmp(app.currentLoadMode, 'Single DAT')
                [file, path] = uigetfile({'*.dat','DAT Files (*.dat)'}, 'Select single DAT file');
                if isequal(file, 0)
                    return;
                end

                app.singleDatFile = fullfile(path, file);
                [~, name, ext] = fileparts(app.singleDatFile);
                app.SessionDropDown.Items = {[name ext]};
                app.SessionDropDown.Value = [name ext];
                app.currentSession = [name ext];
                app.folderPath = path;

                tok = regexp(file, '_Ch(\d+)Biopot_', 'tokens', 'once');
                if ~isempty(tok)
                    app.ChannelDropDown.Value = tok{1};
                end

                app.loadExistingAnnotations();
                app.updateStatus(['Selected DAT file: ' app.singleDatFile]);
            else
                folder = uigetdir();
                if isequal(folder, 0)
                    return;
                end

                app.folderPath = folder;
                try
                    app.sessions = find_sessions(app.folderPath);
                    if isempty(app.sessions)
                        app.SessionDropDown.Items = {};
                        app.updateStatus('No DAT sessions or EDF files found in selected folder.');
                        return;
                    end

                    app.SessionDropDown.Items = app.sessions;
                    app.SessionDropDown.Value = app.sessions{1};
                    app.currentSession = app.sessions{1};
                    app.loadExistingAnnotations();
                    app.updateStatus(sprintf('Loaded folder: %s', app.folderPath));
                catch ME
                    uialert(app.UIFigure, ME.message, 'Folder Error');
                end
            end
        end

        function onSessionChanged(app)
            if ~isempty(app.SessionDropDown.Items)
                app.currentSession = app.SessionDropDown.Value;
                app.selectedCandidateIdx = NaN;
                app.selectedCandidate = struct();
                app.detectionResults = struct();
                app.CandidateTable.Data = cell(0,8);
                app.selectedCandidateIdx = NaN;
                app.selectedCandidate = struct();
                app.detectionResults = struct();
                app.CandidateTable.Data = cell(0,8);
                app.refreshSavedAnnotationTable();
                app.plotCurrentWindow();
            end
        end

        function data = load_single_dat_internal(app, filePath, fs, dataType, byteOrder)
            fid = fopen(filePath, 'r', byteOrder);
            if fid < 0
                error('Could not open file: %s', filePath);
            end
            raw = fread(fid, inf, dataType);
            fclose(fid);

            if isempty(raw)
                error('No data read from file: %s', filePath);
            end

            signal = double(raw(:));
            time = (0:numel(signal)-1)' / fs;

            [~, name, ~] = fileparts(filePath);
            tok = regexp(name, '_Ch(\d+)Biopot_', 'tokens', 'once');
            if isempty(tok)
                chNum = 1;
            else
                chNum = str2double(tok{1});
            end

            data.signal = signal;
            data.fs = fs;
            data.time = time;
            data.channels = {sprintf('Ch%d', chNum)};
            data.channel_number = chNum;
            data.file = filePath;
        end

        function data = load_edf_internal(app, filePath)
    if ~exist(filePath, 'file')
        error('EDF file not found: %s', filePath);
    end

    TT = edfread(filePath);

    if isempty(TT)
        error('EDF file is empty or could not be read.');
    end

    varNames = string(TT.Properties.VariableNames);
    nVars = numel(varNames);

    if nVars == 0
        error('No channels found in EDF file.');
    end

    % Prefer real EEG/Biopot channels, but gracefully fall back if names differ.
    isGood = contains(lower(varNames), "biopot") | ...
             contains(lower(varNames), "eeg") | ...
             startsWith(lower(varNames), "ch");

    idxKeep = find(isGood);
    if isempty(idxKeep)
        idxKeep = 1:nVars;
    end

    channelData = {};
    channelNames = strings(1,0);
    lengths = [];

    for k = 1:numel(idxKeep)
        col = TT.(TT.Properties.VariableNames{idxKeep(k)});

        if isnumeric(col)
            vec = double(col(:));

        elseif iscell(col)
            pieces = {};
            for i = 1:numel(col)
                item = col{i};
                if isnumeric(item)
                    v = double(item(:));
                elseif isstring(item) || ischar(item)
                    v = str2double(item(:));
                    if any(isnan(v))
                        v = [];
                    end
                else
                    try
                        v = double(item);
                        v = v(:);
                    catch
                        v = [];
                    end
                end
                if ~isempty(v)
                    pieces{end+1} = v; %#ok<AGROW>
                end
            end
            if isempty(pieces)
                continue;
            end
            vec = vertcat(pieces{:});

        elseif isstring(col) || ischar(col)
            vec = str2double(col(:));
            if any(isnan(vec))
                continue;
            end

        else
            try
                vec = double(col(:));
            catch
                continue;
            end
        end

        if isempty(vec)
            continue;
        end

        channelData{end+1} = vec; %#ok<AGROW>
        channelNames(end+1) = varNames(idxKeep(k)); %#ok<AGROW>
        lengths(end+1) = numel(vec); %#ok<AGROW>
    end

    if isempty(channelData)
        error('No usable numeric EDF channels found.');
    end

    % Use the typical channel length rather than the shortest one.
    targetLen = round(median(lengths));
    tol = max(100, round(0.02 * targetLen));
    ok = abs(lengths - targetLen) <= tol;

    if any(ok)
        channelData = channelData(ok);
        channelNames = channelNames(ok);
        lengths = lengths(ok);
    end

    if isempty(channelData)
        error('No EDF channels survived length consistency filtering.');
    end

    % Keep up to 8 longest/most consistent channels.
    [~, ord] = sort(lengths, 'descend');
    ord = ord(1:min(8, numel(ord)));
    channelData = channelData(ord);
    channelNames = channelNames(ord);

    nReal = numel(channelData);
    X = zeros(targetLen, 8);
    finalNames = strings(1,8);

    for j = 1:nReal
        vec = channelData{j};
        L = min(numel(vec), targetLen);
        X(1:L, j) = vec(1:L);
        finalNames(j) = channelNames(j);
    end

    for j = nReal+1:8
        finalNames(j) = "PadCh" + j;
    end

    % Use real EDF timing when available.
    fs = [];
    try
        info = edfinfo(filePath);
        if isfield(info, 'NumSamples') && ~isempty(info.NumSamples)
            ns = double(info.NumSamples(:));
            ns = ns(isfinite(ns) & ns > 0);
            if ~isempty(ns)
                if isfield(info, 'DataRecordDuration') && ~isempty(info.DataRecordDuration)
                    dr = info.DataRecordDuration;
                    try
                        if isduration(dr)
                            drSec = seconds(dr);
                        else
                            drSec = seconds(duration(dr));
                        end
                    catch
                        drSec = double(dr);
                    end
                else
                    drSec = 1;
                end
                if isfinite(drSec) && drSec > 0
                    fs = median(ns) / drSec;
                end
            end
        end
    catch
    end
    if isempty(fs) || ~isfinite(fs) || fs <= 0
        fs = 2000;
    end
    time = (0:size(X,1)-1)' / fs;

    data.signal = X;
    data.fs = fs;
    data.time = time;
    data.channels = cellstr(finalNames);
    data.file = filePath;
end

function onLoadSession(app)
            app.setRunningState(true);
            try
                if isempty(app.SessionDropDown.Items)
                    app.setRunningState(false);
                    uialert(app.UIFigure, 'No session or file selected.', 'Missing Selection');
                    return;
                end

                app.currentSession = app.SessionDropDown.Value;

                if strcmp(app.currentLoadMode, 'Single DAT')
                    if isempty(app.singleDatFile)
                        app.setRunningState(false);
                        uialert(app.UIFigure, 'Please select a DAT file first.', 'Missing File');
                        return;
                    end

                    app.data = app.load_single_dat_internal(app.singleDatFile, 1000, 'float32', 'ieee-le');
                    app.updateDisplayPreprocessing();

                    app.currentStartSec = 0;
                    app.StartEditField.Value = 0;
                    app.EndEditField.Value = min(5, app.data.time(end));
                    app.setViewRangeFields(0, min(app.windowSec, app.data.time(end)));
                    app.plotCurrentWindow();
                    app.refreshSavedAnnotationTable();
                    app.updateStatus(['Loaded single DAT: ' app.currentSession]);

                else
                    if isempty(app.folderPath)
                        app.setRunningState(false);
                        uialert(app.UIFigure, 'Please select a data folder first.', 'Missing Folder');
                        return;
                    end

                    if app.isEDFSelection(app.currentSession)
                        edfPath = fullfile(app.folderPath, app.currentSession);
                        app.data = app.load_edf_internal(edfPath);
                        app.updateDisplayPreprocessing();

                        app.currentStartSec = 0;
                        app.StartEditField.Value = 0;
                        app.EndEditField.Value = min(5, app.data.time(end));
                        app.setViewRangeFields(0, min(app.windowSec, app.data.time(end)));

                        nCh = size(app.data.signal, 2);
                        if nCh <= 1
                            app.ViewModeDropDown.Items = {'Single Channel'};
                            app.ViewModeDropDown.Value = 'Single Channel';
                            app.ChannelDropDown.Items = {'1'};
                            app.ChannelDropDown.Value = '1';
                            app.ChannelDropDown.Enable = 'on';
                        else
                            app.ViewModeDropDown.Items = {'All Channels','Single Channel'};
                            app.ViewModeDropDown.Value = 'All Channels';
                            items = [{'All'}, arrayfun(@num2str, 1:nCh, 'UniformOutput', false)];
                            app.ChannelDropDown.Items = items;
                            app.ChannelDropDown.Value = 'All';
                            app.ChannelDropDown.Enable = 'off';
                        end

                        app.plotCurrentWindow();
                        app.refreshSavedAnnotationTable();
                        app.updateStatus(sprintf('Loaded EDF file: %s', app.currentSession));
                    else
                        app.data = load_session_dat(app.folderPath, app.currentSession, ...
                            'Fs', 1000, ...
                            'NumChannels', 8, ...
                            'DataType', 'float32', ...
                            'ByteOrder', 'ieee-le');

                        app.updateDisplayPreprocessing();
                        app.currentStartSec = 0;
                        app.StartEditField.Value = 0;
                        app.EndEditField.Value = min(5, app.data.time(end));
                        app.setViewRangeFields(0, min(app.windowSec, app.data.time(end)));
                        app.plotCurrentWindow();
                        app.refreshSavedAnnotationTable();
                        app.updateStatus(sprintf('Loaded DAT session: %s', app.currentSession));
                    end
                end

                app.setRunningState(false);
            catch ME
                app.setRunningState(false);
                uialert(app.UIFigure, ME.message, 'Load Error');
            end
        end

        function onRunDetection(app)
            if isempty(app.data) || ~isfield(app.data, 'signal') || isempty(app.data.signal)
                uialert(app.UIFigure, 'Load data first.', 'No Data');
                return;
            end

            app.setRunningState(true);
            try
                app.readParamsFromUI();
                allEvents = {};
                MAX_CAND_DUR_SEC = app.MaxDurationField.Value;

                if strcmp(app.currentLoadMode, 'Single DAT')
                    sig = double(app.data.signal(:))';
                    det = detect_events_with_params(sig, app.data.fs, app.params);

                    chNum = 1;
                    if isfield(app.data, 'channel_number')
                        chNum = app.data.channel_number;
                    end

                    if isfield(det, 'events') && ~isempty(det.events)
                        for i = 1:numel(det.events)
                            ev = det.events{i};
                            ev.channel = chNum;
                            if isfield(ev,'duration_s') && isfinite(ev.duration_s) && ev.duration_s > 0 && ev.duration_s <= MAX_CAND_DUR_SEC
                                allEvents{end+1} = ev; %#ok<AGROW>
                            end
                        end
                    end
                else
                    channelList = app.getDetectionChannels();
                    if isempty(channelList)
                        app.setRunningState(false);
                        uialert(app.UIFigure, 'Please select at least one detection channel.', 'No Detection Channels');
                        return;
                    end

                    nAvail = size(app.data.signal, 2);
                    channelList = channelList(channelList <= nAvail);

                    for ch = channelList
                        sig = double(app.data.signal(:, ch))';
                        det = detect_events_with_params(sig, app.data.fs, app.params);

                        if isfield(det, 'events') && ~isempty(det.events)
                            for i = 1:numel(det.events)
                                ev = det.events{i};
                                ev.channel = ch;
                                if isfield(ev,'duration_s') && isfinite(ev.duration_s) && ev.duration_s > 0 && ev.duration_s <= MAX_CAND_DUR_SEC
                                    allEvents{end+1} = ev; %#ok<AGROW>
                                end
                            end
                        end
                    end
                end

                if ~isempty(allEvents)
                    starts = cellfun(@(e)e.start_s, allEvents);
                    [~, order] = sort(starts);
                    allEvents = allEvents(order);
                end

                app.detectionResults = struct();
                app.detectionResults.events = allEvents;

                app.refreshCandidateTable();
                app.plotCurrentWindow();
                app.updateStatus(sprintf('Detection complete. Found %d candidate events (<= %d s).', numel(allEvents), MAX_CAND_DUR_SEC));
                app.setRunningState(false);
            catch ME
                app.setRunningState(false);
                uialert(app.UIFigure, ME.message, 'Detection Error');
            end
        end


        function s = fmtTableTime(app, secs)
            if isempty(secs) || ~isfinite(secs)
                s = '';
            else
                s = app.formatClockTime(secs);
            end
        end

        function v = fmtTableNum(app, x, fmt)
            if nargin < 3
                fmt = '%.2f';
            end
            if isempty(x) || ~isfinite(x)
                v = '';
            else
                v = sprintf(fmt, x);
            end
        end

        function applyTimeAxisFormatting(app, viewStart, viewEnd)
            xt = get(app.UIAxes, 'XTick');
            xt = xt(xt >= viewStart & xt <= viewEnd);
            if isempty(xt)
                xt = linspace(viewStart, viewEnd, 6);
            end
            labels = arrayfun(@(v) app.formatClockTime(v), xt, 'UniformOutput', false);
            set(app.UIAxes, 'XTick', xt, 'XTickLabel', labels);
            xlabel(app.UIAxes, 'Time (hh:mm:ss)');
        end


function refreshCandidateTable(app)
            if ~isfield(app.detectionResults, 'events') || isempty(app.detectionResults.events)
                app.CandidateTable.Data = cell(0,8);
                return;
            end

            ev = app.detectionResults.events;
            data = cell(numel(ev), 8);
            for i = 1:numel(ev)
                data{i,1} = i;
                data{i,2} = ev{i}.channel;
                data{i,3} = ev{i}.type;
                data{i,4} = app.fmtTableTime(ev{i}.start_s);
                data{i,5} = app.fmtTableTime(ev{i}.end_s);
                data{i,6} = app.fmtTableNum(ev{i}.duration_s, '%.2f');
                data{i,7} = app.fmtTableNum(ev{i}.spike_freq, '%.4f');
                data{i,8} = app.fmtTableNum(ev{i}.peak_score, '%.4f');
            end
            app.CandidateTable.Data = data;
        end

        function onCandidateSelected(app, event)
            if isempty(event.Indices)
                return;
            end
            rowIdx = event.Indices(1);

            if ~isfield(app.detectionResults, 'events') || isempty(app.detectionResults.events)
                return;
            end
            if rowIdx < 1 || rowIdx > numel(app.detectionResults.events)
                return;
            end

            ev = app.detectionResults.events{rowIdx};
            app.selectedCandidateIdx = rowIdx;
            app.selectedCandidate = ev;

            padSec = app.CandidatePadField.Value;
            if isempty(padSec) || ~isfinite(padSec) || padSec < 0
                padSec = 10;
            end

            app.StartEditField.Value = ev.start_s;
            app.EndEditField.Value = ev.end_s;
            app.currentStartSec = max(0, ev.start_s - padSec);
            app.setViewRangeFields(app.currentStartSec, min(app.data.time(end), app.currentStartSec + app.windowSec));

            neededWindow = (ev.end_s - ev.start_s) + 2*padSec;
            neededWindow = min(neededWindow, app.MaxDurationField.Value);
            if neededWindow > app.WindowEditField.Value
                app.WindowEditField.Value = neededWindow;
                app.windowSec = neededWindow;
            else
                app.windowSec = min(app.WindowEditField.Value, app.MaxDurationField.Value);
            end

            if isfield(ev, 'channel')
                if strcmp(app.currentLoadMode, 'EDF / Session')
                    app.ViewModeDropDown.Value = 'Single Channel';
                    app.ChannelDropDown.Enable = 'on';
                    if ev.channel <= numel(app.ChannelDropDown.Items)-1 || strcmp(app.currentLoadMode,'Single DAT')
                        app.ChannelDropDown.Value = num2str(ev.channel);
                    end
                end
            end

            app.setViewRangeFields(app.currentStartSec, min(app.data.time(end), app.currentStartSec + app.windowSec));
            app.plotCurrentWindow();
            app.updateStatus(sprintf('Jumped to candidate %d: Ch%d, %s, %.2f-%.2f s', ...
                rowIdx, ev.channel, ev.type, ev.start_s, ev.end_s));
        end


function onWindowChanged(app)
            app.windowSec = app.WindowEditField.Value;
            if ~isempty(app.data) && isfield(app.data,'time') && ~isempty(app.data.time)
                app.setViewRangeFields(app.currentStartSec, min(app.data.time(end), app.currentStartSec + app.windowSec));
            end
            app.plotCurrentWindow();
        end

        function onDisplayBandChanged(app)
            if isempty(app.data) || ~isfield(app.data, 'signal') || isempty(app.data.signal)
                return;
            end
            app.updateDisplayPreprocessing();
            app.plotCurrentWindow();
        end

        function updateDisplayPreprocessing(app)
            lowHz = app.DisplayLowField.Value;
            highHz = app.DisplayHighField.Value;

            if ~isfinite(lowHz) || ~isfinite(highHz)
                lowHz = 5; highHz = 80;
            end
            lowHz = max(lowHz, 0.1);
            highHz = min(highHz, app.data.fs/2 - 1);

            if highHz <= lowHz
                highHz = min(max(lowHz + 1, 2), app.data.fs/2 - 1);
            end

            app.displayBandHz = [lowHz highHz];
            app.y = preprocess_eeg(app.data.signal, app.data.fs, app.displayBandHz, 50);
        end

        function onPrevWindow(app)
            if isempty(app.data) || ~isfield(app.data, 'time') || isempty(app.data.time)
                return;
            end
            app.currentStartSec = max(0, app.currentStartSec - app.windowSec);
            app.setViewRangeFields(app.currentStartSec, min(app.data.time(end), app.currentStartSec + app.windowSec));
            app.plotCurrentWindow();
        end

        function onNextWindow(app)
            if isempty(app.data) || ~isfield(app.data, 'time') || isempty(app.data.time)
                return;
            end
            maxStart = max(app.data.time(end) - app.windowSec, 0);
            app.currentStartSec = min(maxStart, app.currentStartSec + app.windowSec);
            app.setViewRangeFields(app.currentStartSec, min(app.data.time(end), app.currentStartSec + app.windowSec));
            app.plotCurrentWindow();
        end

        function sig = getDisplaySignal(app)
            if strcmp(app.DisplayModeDropDown.Value, 'Raw') || isempty(app.y)
                sig = app.data.signal;
            else
                sig = app.y;
            end
        end

        function plotCurrentWindow(app)
            if isempty(app.data) || ~isfield(app.data, 'time') || isempty(app.data.time)
                return;
            end

            sig = app.getDisplaySignal();
            viewStart = max(0, app.currentStartSec);
            viewEnd = min(app.data.time(end), app.currentStartSec + app.windowSec);

            idx = app.data.time >= viewStart & app.data.time <= viewEnd;
            t = app.data.time(idx);

            if isvector(sig)
                x = sig(idx);
            else
                x = sig(idx,:);
            end

            if isempty(t)
                return;
            end

            cla(app.UIAxes);
            hold(app.UIAxes, 'on');

            if strcmp(app.currentLoadMode, 'Single DAT')
                h = plot(app.UIAxes, t, x, 'LineWidth', 0.9);
                h.HitTest = 'off';
                ylabel(app.UIAxes, 'Amplitude');
                title(app.UIAxes, sprintf('%s | %s to %s', app.currentSession, app.formatClockTime(viewStart), app.formatClockTime(viewEnd)));
                xlim(app.UIAxes, [viewStart viewEnd]);

            elseif strcmp(app.ViewModeDropDown.Value, 'Single Channel')
                selectedChannel = app.ChannelDropDown.Value;
                if strcmp(selectedChannel, 'All')
                    ch = 1;
                else
                    ch = str2double(selectedChannel);
                end

                ych = x(:,ch);
                h = plot(app.UIAxes, t, ych, 'LineWidth', 0.9);
                h.HitTest = 'off';
                ylabel(app.UIAxes, 'Amplitude');
                title(app.UIAxes, sprintf('%s | Ch%d | %s to %s', app.currentSession, ch, app.formatClockTime(viewStart), app.formatClockTime(viewEnd)));
                xlim(app.UIAxes, [viewStart viewEnd]);

            else
                nCh = size(x,2);
                spread = median(std(x,0,1));
                if spread == 0 || isnan(spread)
                    spread = 1;
                end
                offsetStep = 5 * spread;

                colorMap = lines(max(nCh, 8));
                selectedDetectChannels = app.getDetectionChannels();
                rightPad = 0.06 * max((viewEnd - viewStart), eps);
                xlim(app.UIAxes, [viewStart, viewEnd + rightPad]);

                for ch = 1:nCh
                    offset = (nCh - ch) * offsetStep;
                    ych = x(:,ch) + offset;

                    isIncludedForDetection = ismember(ch, selectedDetectChannels);
                    if isIncludedForDetection
                        thisColor = colorMap(ch,:);
                        thisLW = 0.8;
                    else
                        thisColor = [0.75 0.75 0.75];
                        thisLW = 0.6;
                    end

                    h = plot(app.UIAxes, t, ych, 'LineWidth', thisLW, 'Color', thisColor);
                    h.HitTest = 'off';

                    xText = viewEnd + 0.03 * max((viewEnd - viewStart), eps);
                    idxTail = max(1, numel(ych) - 100);
                    yText = median(ych(idxTail:end));

                    ht = text(app.UIAxes, xText, yText, sprintf('Ch%d', ch), ...
                        'HorizontalAlignment', 'left', ...
                        'VerticalAlignment', 'middle', ...
                        'FontWeight', 'bold', ...
                        'FontSize', 10, ...
                        'Color', thisColor, ...
                        'BackgroundColor', [1 1 1], ...
                        'Margin', 2, ...
                        'Clipping', 'off');
                    ht.HitTest = 'off';
                end

                ylabel(app.UIAxes, 'Amplitude + offset');
                title(app.UIAxes, sprintf('%s | %s to %s', app.currentSession, app.formatClockTime(viewStart), app.formatClockTime(viewEnd)));
            end

            grid(app.UIAxes, 'on');
            app.applyTimeAxisFormatting(viewStart, viewEnd);
            yl = ylim(app.UIAxes);

            app.drawCandidatePatches(viewStart, viewEnd, yl);
            app.drawSavedAnnotationPatches(viewStart, viewEnd, yl);

            selStart = app.StartEditField.Value;
            selEnd = app.EndEditField.Value;
            if isfinite(selStart) && isfinite(selEnd) && selEnd > selStart
                xs = [max(selStart, viewStart) min(selEnd, viewEnd)];
                if xs(2) > xs(1)
                    patch(app.UIAxes, [xs(1) xs(2) xs(2) xs(1)], ...
                        [yl(1) yl(1) yl(2) yl(2)], ...
                        [0.85 0.85 0.95], ...
                        'FaceAlpha', 0.22, ...
                        'EdgeColor', [0.2 0.2 0.6], ...
                        'LineWidth', 1.2, ...
                        'HitTest', 'off');
                    xline(app.UIAxes, selStart, '-', 'Color', [0.1 0.1 0.5], 'LineWidth', 1.3);
                    xline(app.UIAxes, selEnd, '-', 'Color', [0.1 0.1 0.5], 'LineWidth', 1.3);
                end
            end

            hold(app.UIAxes, 'off');
        end

        function drawCandidatePatches(app, t0, t1, yl)
            if ~isfield(app.detectionResults, 'events') || isempty(app.detectionResults.events)
                return;
            end

            ev = app.detectionResults.events;
            currentCh = [];
            if strcmp(app.currentLoadMode, 'EDF / Session') && strcmp(app.ViewModeDropDown.Value, 'Single Channel')
                currentCh = str2double(app.ChannelDropDown.Value);
            end

            for i = 1:numel(ev)
                st = ev{i}.start_s;
                en = ev{i}.end_s;
                if en < t0 || st > t1
                    continue;
                end
                if ~isempty(currentCh) && ev{i}.channel ~= currentCh
                    continue;
                end

                if strcmpi(ev{i}.type, 'convulsive')
                    faceColor = [1.0 0.80 0.80];
                else
                    faceColor = [1.0 0.9 0.7];
                end

                xs = [max(st,t0) min(en,t1)];
                patch(app.UIAxes, [xs(1) xs(2) xs(2) xs(1)], ...
                    [yl(1) yl(1) yl(2) yl(2)], ...
                    faceColor, ...
                    'FaceAlpha', 0.08, ...
                    'EdgeColor', 'none', ...
                    'HitTest', 'off');
            end
        end

        function drawSavedAnnotationPatches(app, t0, t1, yl)
            if height(app.annotations) == 0
                return;
            end

            rows = strcmp(app.annotations.session_name, app.currentSession);
            ann = app.annotations(rows, :);

            currentCh = [];
            if strcmp(app.currentLoadMode, 'EDF / Session') && strcmp(app.ViewModeDropDown.Value, 'Single Channel')
                currentCh = str2double(app.ChannelDropDown.Value);
            end

            for i = 1:height(ann)
                st = ann.start_s(i);
                en = ann.end_s(i);
                if en < t0 || st > t1
                    continue;
                end

                annCh = ann.channel(i);
                if ~isempty(currentCh) && annCh ~= 0 && annCh ~= currentCh
                    continue;
                end

                labelName = string(ann.label{i});
                switch labelName
                    case "Seizure"
                        faceColor = [1.0 0.85 0.85];
                    case "False"
                        faceColor = [0.85 0.90 1.0];
                    case "Normal"
                        faceColor = [0.88 1.0 0.88];
                    otherwise
                        faceColor = [0.95 0.95 0.85];
                end

                xs = [max(st,t0) min(en,t1)];
                patch(app.UIAxes, [xs(1) xs(2) xs(2) xs(1)], ...
                    [yl(1) yl(1) yl(2) yl(2)], ...
                    faceColor, ...
                    'FaceAlpha', 0.14, ...
                    'EdgeColor', 'none', ...
                    'HitTest', 'off');
            end
        end

        function tf = selectedCandidateMatchesCurrentInterval(app, ch, t0, t1)
            tf = false;
            if isnan(app.selectedCandidateIdx) || ~isstruct(app.selectedCandidate) || isempty(fieldnames(app.selectedCandidate))
                return;
            end
            ev = app.selectedCandidate;
            req = {'start_s','end_s','channel'};
            for k = 1:numel(req)
                if ~isfield(ev, req{k})
                    return;
                end
            end
            if ch <= 0 || ev.channel ~= ch
                return;
            end
            overlap = min(t1, ev.end_s) - max(t0, ev.start_s);
            tf = overlap > 0;
        end

        function feat = computeIntervalFeatures(app, ch, t0, t1)
            feat = struct('candIdx', NaN, 'candType', 'manual', ...
                'candSpikeCount', NaN, 'candSpikeFreq', NaN, 'candPeakScore', NaN, ...
                'candMeanScore', NaN, 'candMeanLow', NaN, 'candMeanGamma', NaN, ...
                'candMeanBroad', NaN);

            if ch <= 0 || isempty(app.data) || ~isfield(app.data,'signal') || isempty(app.data.signal)
                return;
            end
            if ch > size(app.data.signal,2)
                return;
            end
            try
                sig = double(app.data.signal(:, ch))';
                det = detect_events_with_params(sig, app.data.fs, app.params);
            catch
                return;
            end
            if ~isfield(det,'time') || isempty(det.time)
                return;
            end
            mask = det.time >= t0 & det.time <= t1;
            if ~any(mask)
                return;
            end
            if isfield(det,'spike_locs') && ~isempty(det.spike_locs)
                spikeTimes = det.time(det.spike_locs);
                feat.candSpikeCount = sum(spikeTimes >= t0 & spikeTimes <= t1);
            else
                feat.candSpikeCount = 0;
            end
            dur = max(t1 - t0, eps);
            feat.candSpikeFreq = feat.candSpikeCount / dur;
            if isfield(det,'score') && ~isempty(det.score)
                feat.candPeakScore = max(det.score(mask));
                feat.candMeanScore = mean(det.score(mask));
            end
            if isfield(det,'low_z') && ~isempty(det.low_z)
                feat.candMeanLow = mean(det.low_z(mask));
            end
            if isfield(det,'gamma_z') && ~isempty(det.gamma_z)
                feat.candMeanGamma = mean(det.gamma_z(mask));
            end
            if isfield(det,'broad_z') && ~isempty(det.broad_z)
                feat.candMeanBroad = mean(det.broad_z(mask));
            end
            if isfield(det,'convulsive_threshold') && isfinite(det.convulsive_threshold) && isfinite(feat.candPeakScore)
                if feat.candPeakScore >= det.convulsive_threshold
                    feat.candType = 'convulsive';
                else
                    feat.candType = 'behavior';
                end
            end
        end

        function addAnnotation(app, labelName)
            if isempty(app.data) || ~isfield(app.data, 'time') || isempty(app.data.time)
                uialert(app.UIFigure, 'Load data first.', 'No Data');
                return;
            end

            app.readParamsFromUI();

            t0 = app.StartEditField.Value;
            t1 = app.EndEditField.Value;
            if t1 <= t0
                uialert(app.UIFigure, 'End time must be greater than start time.', 'Invalid Interval');
                return;
            end

            selectedChannel = app.ChannelDropDown.Value;
            if strcmp(selectedChannel, 'All')
                ch = 0;
            else
                ch = str2double(selectedChannel);
            end

            sessionIdx = 1;
            if ~isempty(app.sessions)
                tmp = find(strcmp(app.sessions, app.currentSession), 1);
                if ~isempty(tmp)
                    sessionIdx = tmp;
                end
            end

            dur = t1 - t0;

            candIdx = NaN;
            candType = '';
            candSpikeCount = NaN;
            candSpikeFreq = NaN;
            candPeakScore = NaN;
            candMeanScore = NaN;
            candMeanLow = NaN;
            candMeanGamma = NaN;
            candMeanBroad = NaN;

            if app.selectedCandidateMatchesCurrentInterval(ch, t0, t1)
                candIdx = app.selectedCandidateIdx;
                if isfield(app.selectedCandidate, 'type'),        candType = app.selectedCandidate.type; end
                if isfield(app.selectedCandidate, 'spike_count'), candSpikeCount = app.selectedCandidate.spike_count; end
                if isfield(app.selectedCandidate, 'spike_freq'),  candSpikeFreq = app.selectedCandidate.spike_freq; end
                if isfield(app.selectedCandidate, 'peak_score'),  candPeakScore = app.selectedCandidate.peak_score; end
                if isfield(app.selectedCandidate, 'mean_score'),  candMeanScore = app.selectedCandidate.mean_score; end
                if isfield(app.selectedCandidate, 'mean_low'),    candMeanLow = app.selectedCandidate.mean_low; end
                if isfield(app.selectedCandidate, 'mean_gamma'),  candMeanGamma = app.selectedCandidate.mean_gamma; end
                if isfield(app.selectedCandidate, 'mean_broad'),  candMeanBroad = app.selectedCandidate.mean_broad; end
            else
                feat = app.computeIntervalFeatures(ch, t0, t1);
                candIdx = feat.candIdx;
                candType = feat.candType;
                candSpikeCount = feat.candSpikeCount;
                candSpikeFreq = feat.candSpikeFreq;
                candPeakScore = feat.candPeakScore;
                candMeanScore = feat.candMeanScore;
                candMeanLow = feat.candMeanLow;
                candMeanGamma = feat.candMeanGamma;
                candMeanBroad = feat.candMeanBroad;
                app.selectedCandidateIdx = NaN;
                app.selectedCandidate = struct();
            end

            createdAt = datestr(now, 'yyyy-mm-dd HH:MM:SS');

            newRow = table(sessionIdx, {app.currentSession}, ch, t0, t1, dur, {labelName}, ...
                candIdx, {candType}, candSpikeCount, candSpikeFreq, candPeakScore, ...
                candMeanScore, candMeanLow, candMeanGamma, candMeanBroad, {createdAt}, ...
                'VariableNames', app.annotations.Properties.VariableNames);

            app.annotations = [app.annotations; newRow];
            app.pickMode = "";
            app.refreshAnnotationTable();
            app.plotCurrentWindow();

            if ch == 0
                chText = 'All channels';
            else
                chText = sprintf('Ch%d', ch);
            end
            app.updateStatus(sprintf('Added %s annotation: %s, %.2f-%.2f s', labelName, chText, t0, t1));
        end

        function onDeleteAnnotation(app)
            if height(app.annotations) == 0
                uialert(app.UIFigure, 'No annotations to delete.', 'Delete Error');
                return;
            end

            sel = app.AnnotationTable.Selection;
            if isempty(sel)
                uialert(app.UIFigure, 'Select a row in the annotation table first.', 'Delete Error');
                return;
            end

            rowIdx = sel(1);
            if rowIdx < 1
                uialert(app.UIFigure, 'Invalid row selection.', 'Delete Error');
                return;
            end

            if ~isempty(app.currentSession)
                rows = find(strcmp(app.annotations.session_name, app.currentSession));
                if ~isempty(rows) && rowIdx <= numel(rows)
                    app.annotations(rows(rowIdx), :) = [];
                else
                    app.annotations(rowIdx, :) = [];
                end
            else
                app.annotations(rowIdx, :) = [];
            end

            app.refreshAnnotationTable();
            app.plotCurrentWindow();
            app.updateStatus('Deleted selected annotation.');
        end

        function refreshAnnotationTable(app)
            T = app.annotations;
            if ~isempty(app.currentSession)
                rows = strcmp(T.session_name, app.currentSession);
                T = T(rows,:);
            end
            n = height(T);
            data = cell(n, 17);

            for i = 1:n
                data{i,1}  = T.session_idx(i);
                data{i,2}  = char(T.session_name{i});

                if T.channel(i) == 0
                    data{i,3} = 'All';
                else
                    data{i,3} = num2str(T.channel(i));
                end

                data{i,4}  = app.fmtTableTime(T.start_s(i));
                data{i,5}  = app.fmtTableTime(T.end_s(i));
                data{i,6}  = app.fmtTableNum(T.duration_s(i), '%.2f');
                data{i,7}  = char(T.label{i});
                data{i,8}  = app.fmtTableNum(T.candidate_idx(i), '%.0f');
                data{i,9}  = char(T.candidate_type{i});
                data{i,10} = app.fmtTableNum(T.candidate_spike_count(i), '%.0f');
                data{i,11} = app.fmtTableNum(T.candidate_spike_freq(i), '%.4f');
                data{i,12} = app.fmtTableNum(T.candidate_peak_score(i), '%.4f');
                data{i,13} = app.fmtTableNum(T.candidate_mean_score(i), '%.4f');
                data{i,14} = app.fmtTableNum(T.candidate_mean_low(i), '%.4f');
                data{i,15} = app.fmtTableNum(T.candidate_mean_gamma(i), '%.4f');
                data{i,16} = app.fmtTableNum(T.candidate_mean_broad(i), '%.4f');
                data{i,17} = char(T.created_at{i});
            end

            app.AnnotationTable.Data = data;
        end

        function refreshSavedAnnotationTable(app)
            app.refreshAnnotationTable();
        end

        function saveBase = getSaveBase(app)
            if ~isempty(app.folderPath)
                saveBase = app.folderPath;
            elseif ~isempty(app.singleDatFile)
                saveBase = fileparts(app.singleDatFile);
            else
                saveBase = '';
            end
        end

        function loadExistingAnnotations(app)
            app.annotations = app.emptyAnnotationTable();
            saveBase = app.getSaveBase();
            if isempty(saveBase)
                app.refreshAnnotationTable();
                return;
            end

            matPath = fullfile(saveBase, 'annotations.mat');
            csvPath = fullfile(saveBase, 'annotations.csv');
            xlsxPath = fullfile(saveBase, 'annotations.xlsx');

            if exist(matPath, 'file')
                S = load(matPath);
                if isfield(S, 'annotations')
                    app.annotations = app.upgradeAnnotationTable(S.annotations);
                end
            elseif exist(xlsxPath, 'file')
                T = readtable(xlsxPath, 'TextType', 'char');
                app.annotations = app.upgradeAnnotationTable(T);
            elseif exist(csvPath, 'file')
                T = readtable(csvPath, 'TextType', 'char');
                app.annotations = app.upgradeAnnotationTable(T);
            end

            app.refreshAnnotationTable();
        end

        function T = upgradeAnnotationTable(app, T0)
            T = T0;
            if ~istable(T)
                T = app.emptyAnnotationTable();
                return;
            end

            wanted = { ...
                'session_idx', ...
                'session_name', ...
                'channel', ...
                'start_s', ...
                'end_s', ...
                'duration_s', ...
                'label', ...
                'candidate_idx', ...
                'candidate_type', ...
                'candidate_spike_count', ...
                'candidate_spike_freq', ...
                'candidate_peak_score', ...
                'candidate_mean_score', ...
                'candidate_mean_low', ...
                'candidate_mean_gamma', ...
                'candidate_mean_broad', ...
                'created_at'};

            for k = 1:numel(wanted)
                vn = wanted{k};
                if ~ismember(vn, T.Properties.VariableNames)
                    switch vn
                        case {'session_name','label','candidate_type','created_at'}
                            T.(vn) = repmat({''}, height(T), 1);
                        otherwise
                            T.(vn) = nan(height(T),1);
                    end
                end
            end

            if any(strcmp('start_s', T.Properties.VariableNames)) && any(strcmp('end_s', T.Properties.VariableNames))
                badDur = ~isfinite(T.duration_s) | T.duration_s == 0;
                T.duration_s(badDur) = T.end_s(badDur) - T.start_s(badDur);
            end

            T = T(:, wanted);
            T.session_name = cellstr(string(T.session_name));
            T.label = cellstr(string(T.label));
            T.candidate_type = cellstr(string(T.candidate_type));
            T.created_at = cellstr(string(T.created_at));
        end

        function onSaveAnnotations(app)
            saveBase = app.getSaveBase();
            if isempty(saveBase)
                uialert(app.UIFigure, 'No source selected.', 'Save Error');
                return;
            end

            if height(app.annotations) == 0
                uialert(app.UIFigure, 'No annotations to save.', 'Save Error');
                return;
            end

            matPath = fullfile(saveBase, 'annotations.mat');
            xlsxPath = fullfile(saveBase, 'annotations.xlsx');
            csvPath = fullfile(saveBase, 'annotations.csv');

            try
                annotations = app.annotations; %#ok<NASGU>
                save(matPath, 'annotations');
                writetable(app.annotations, xlsxPath);
                writetable(app.annotations, csvPath);
                app.updateStatus('Annotations saved to MAT, XLSX, and CSV.');
            catch ME
                uialert(app.UIFigure, ME.message, 'Save Error');
            end
        end

        function updateStatus(app, msg)
            app.StatusLabel.Text = ['Status: ' msg];
            drawnow;
        end
    end
end