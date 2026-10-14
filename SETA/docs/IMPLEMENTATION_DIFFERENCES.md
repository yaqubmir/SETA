# MATLAB and Python implementation differences

| Behavior | Supplied MATLAB edition | Python edition |
|---|---|---|
| Main app | SETAAnnotatorApp.m, formerly NEDNetAnnotatorApp.m | seta/app.py |
| Detection | Original MATLAB code | SciPy/NumPy port of that code |
| Filter | designfilt + filtfilt | Butterworth SOS + sosfiltfilt |
| Spike peak rules | MATLAB findpeaks and returned widths | SciPy find_peaks and half-prominence widths |
| Display | Select Raw or Preprocessed; all/single-channel view | Raw and filtered together; one selected channel |
| Display filter extent | Entire recording | Window with two seconds of context |
| EDF loading | Heuristic channel-length selection/padding; 2000 Hz fallback | Preserve original EEG order; reject invalid timing, mixed rates, discontinuity |
| Grouped DAT | Eight channels, truncate unequal lengths | Eight channels, reject unequal lengths |
| Manual labels | Seizure, False, Normal | Same labels |
| Edited candidate interval features | Recomputed when possible | Left blank when original candidate no longer matches |
| Native save | annotations.mat, .xlsx, .csv | seta_annotations.json; explicit CSV export/import |
| Empty table save | Refused by original app | Supported |
| Save conflict handling | None | Revision check and exclusive lock |
| Trained classifier/video analysis | Not present | Not present |

No cross-language numerical equivalence is claimed. MATLAB syntax/runtime testing
remains blocked in the preparation environment by its licensing-service startup.
The older Batch 2 Python detector's parity test does not validate this port.
