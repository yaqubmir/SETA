% SETA | Copyright (C) 2026 Mohd Yaqub Mir | SPDX-License-Identifier: GPL-3.0-only
clc;
clear;

scriptFolder = fileparts(mfilename('fullpath'));
cd(scriptFolder);
addpath(scriptFolder);

disp('Starting SETA Annotator...');

app = SETAAnnotatorApp;