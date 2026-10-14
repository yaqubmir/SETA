# SETA Python user manual

## Load a recording

Launch `python Runme.py` from the `python` folder after installing requirements.
Click **Open EDF / single DAT**. EDF files supply their own sampling rate and
amplitude calibration. The reader supports continuous 16-bit EDF and EDF+C.
EDF annotations are not imported as SETA labels. BDF, EDF+D and mixed-rate EEG
are explicitly rejected. EEG/Biopot/Ch-labelled signals are preferred; otherwise
non-annotation channels are used. Channels retain their order and names. The
channel number is the original EDF signal-column position, not inferred from
the text label. Verify identity before comparing animal/group results.

For DAT, enter sampling rate, numeric type, and scale. The supported encodings
are little-endian float32, int16 and float64. The single-DAT defaults are 1000 Hz,
float32, scale 1. Multiplying by a scale changes amplitudes; units cannot be
inferred from a binary DAT file. **Open DAT session** reads eight files named
`<prefix>_Ch1Biopot_1000Hz.dat` through Ch8. Its scale default is 0.001 to match the
original MATLAB grouped loader. Unequal channel lengths are rejected rather than
silently truncated. All files are loaded into memory.

## Inspect raw and filtered traces

Select one channel. Raw is displayed above filtered, on the same amplitude range.
Default display filtering is 5–80 Hz plus a 50 Hz notch (Q=35). **Display filter**
changes low/high/notch frequencies; set notch to 0 to disable it. Frequencies must
be below Nyquist. Display filtering includes two seconds of available context on
each side of the visible window; edge behavior can differ from full-record
filtering. It is separate from the detection parameters.

Use View start and Window, then Show, Previous or Next. Times are recording-relative
seconds. Each horizontal display pixel shows its sample bin's minimum and maximum,
so an overview is an amplitude envelope rather than every individual sample.
Zoom in with a shorter Window to inspect morphology. No simultaneous all-channel
plot is implemented; all channels can be detected and individually reviewed.

## Detect candidates

Click **Parameters** to edit the named JSON settings. Defaults match the source
MATLAB parameter file. Invalid frequency limits or negative settings are rejected.
Click **Detect channel** or **Detect all**. Detection runs on the complete loaded
recording, in a background thread; the status line reports completion or errors.
The Max candidate control defaults to 120 seconds. Longer candidates are not
added to the table. Adjusting settings does not rerun detection automatically.

Click a candidate to view its channel, interval and five seconds of surrounding
context. `convulsive` / `behavior` are original heuristic EEG tags. They are not
manual seizure labels and do not establish motor behavior. Review synchronized
video externally where required. The GUI requires PRESERVE_ORIGINAL_TIME=true
to keep candidate bounds aligned with the loaded trace.

## Annotate and save

Enter Start and End, or use Pick start / Pick end and click either plot. The
yellow region marks the selected interval. Choose **Mark Seizure**, **Mark False**
or **Mark Normal**. These exact labels are saved. Candidate features accompany
an unchanged candidate interval. If you change its channel or boundaries, the
Python app leaves candidate features blank rather than attaching features from
a different interval. The MATLAB edition recomputes some interval features.

**Save** writes `seta_annotations.json` in the recording's folder. It contains all
rows saved for that folder, stable annotation IDs, a revision identifier and the
current detector/display settings. Settings are recorded as provenance; reopening
does not automatically replace current UI settings. The previous file is kept as
`seta_annotations.json.bak`. A lock and revision check prevent concurrent saves
from silently overwriting each other. After a crash, an orphaned `.lock` can remain;
remove it only after verifying that no other SETA instance is saving this file.

Selecting an annotation shows its interval if it belongs to the loaded recording.
**Delete selected annotation** removes a row in memory. Click Save to persist the
deletion; an empty table can be saved. Switching recordings or closing prompts
to save unsaved edits. Data files themselves are never rewritten.

## Exchange annotations with MATLAB

Load the destination recording first. **Import MATLAB CSV** reads the original
17-column annotation table; exact session/channel/start/end/label duplicates are
skipped. Imported rows preserve labels and candidate columns. Click Save to persist
them in JSON. **Export CSV** writes the same 17-column schema (without the Python
annotation ID). Export is separate from Save.

Python does not directly read MATLAB tables stored in MAT or XLSX. MATLAB prefers
`annotations.mat`, then `.xlsx`, then `.csv`. To test a Python CSV in MATLAB, use a
disposable source folder without older annotation MAT/XLSX files and name the CSV
`annotations.csv`. Back up existing data first. Neither edition automatically
updates the other edition's native files.

## Limitations and scientific use

This is an annotation tool, not a validated clinical classifier. The Python port
has passed software tests on synthetic signals and files, but not paired MATLAB
equivalence testing or a real-recording accuracy study. Both libraries use their
own numerical filter and peak routines. Keep edition, version, parameters, channel
identity, units and review criteria with any research export.
