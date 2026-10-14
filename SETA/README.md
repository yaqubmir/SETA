# SETA — Seizure Event Tagging and Annotation

**Mohd Yaqub Mir · Lund University**  
ORCID: https://orcid.org/0000-0002-6550-0255

SETA contains a MATLAB annotator and a Python desktop implementation for inspecting
EEG, detecting candidate intervals, and assigning **Seizure**, **False**, and
**Normal** labels. It is separate from the MIR NED trained-model pipeline.

## MATLAB

Open the `matlab` folder in MATLAB and run `Runme.m`. Keep its seven MATLAB files
together. See [the MATLAB manual](docs/MATLAB_USER_MANUAL.html). Candidate detection
requires the MATLAB signal-processing functions described there.

## Python

Use Python 3.10 or newer with Tk installed. On Windows, the standard python.org
installer includes Tk. A graphical desktop is required.

```sh
cd python
python -m venv .venv
```

Activate the environment:

```bat
:: Windows Command Prompt
.venv\Scripts\activate
```

```sh
# macOS / Linux
source .venv/bin/activate
```

Install dependencies and launch:

```sh
python -m pip install -r requirements.txt
python Runme.py
```

Alternatively, `python -m pip install .` inside `python` installs the `seta` launcher.
Linux may require its distribution's `python3-tk` package. Windows/Python 3.12 was
tested; macOS and Linux GUI operation have not yet been tested.

See [the Python manual](docs/PYTHON_USER_MANUAL.md). The Python view shows raw and
filtered traces together, preserves EDF channel order, rejects discontinuous or
mixed-rate EEG, and saves to `seta_annotations.json`. It does not overwrite the
MATLAB `annotations.mat` / `.xlsx` files. Use explicit CSV import/export to exchange
the original 17-column annotation schema.

## Interpretation and validation

Candidate tags `convulsive` and `behavior` reproduce the original threshold-based
tagging rule. They are not video-confirmed behavior. The manual annotation label
is a separate field. Neither edition contains a video player or model training.

The Python detector follows the supplied MATLAB algorithm's steps and defaults.
**Numerical equivalence to MATLAB is not yet established.** Filter implementation,
edge handling, and peak selection can differ. Do not combine outputs as if the
implementations were interchangeable without paired-data validation.

The Python automated tests cover synthetic detection, EDF timing/calibration,
DAT loading, annotation persistence, CSV interchange, and Tk application startup.
The MATLAB smoke test could not run because MathWorks Service Host licensing
failed during startup. See [validation](docs/VALIDATION.md) and
[implementation differences](docs/IMPLEMENTATION_DIFFERENCES.md).

## Data and citation

Research annotations, EEG recordings, images and videos are private and are not
included in this software repository or its Zenodo software deposit. The demo
generator and test fixtures create synthetic signals only.

Citation metadata is in `CITATION.cff`. The software uses **GPL-3.0-only**. This
license applies to the software; it does not grant access to the private data.

## Tests

```sh
cd python
python -m unittest discover -s tests -v
python make_demo.py
```

The demo is synthetic. Load its DAT at 1000 Hz, float32, scale 1. To exercise
detection on the short demo, set EDGE_TRIM_MIN=0, MIN_EPISODE_DURATION_SEC=2,
MIN_SPIKE_FREQ_HZ=1 and MIN_SPIKE_WIDTH_MS=1. These are test settings, not a
recommended research protocol.
