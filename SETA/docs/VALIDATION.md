# Validation record

Prepared 14 October 2026.

Python: 11 automated tests passed on Windows, Python 3.12.14, NumPy 2.3.5 and
SciPy 1.16.2. Tests cover:

- EDF sample calibration, units, channel identity, timing, and rejection of truncated/discontinuous files.
- Single/grouped DAT encoding, scale, and unequal-length rejection.
- Centered moving-mean endpoints, flat traces, invalid input and a synthetic oscillatory burst.
- Preservation of original event times after edge trimming.
- 50 Hz display-notch attenuation.
- JSON annotation save/reopen, deletion-to-empty, backup and stale-revision rejection.
- Original-schema CSV import/export and duplicate avoidance.
- Tk window construction, synthetic recording display, marking, saving and reopening.

MATLAB: seven-file dependency closure and source-body preservation checked. No
MATLAB runtime tests completed because MathWorks Service Host failed to initialize
licensing. No experimental-data accuracy, MATLAB/Python numerical parity,
macOS/Linux GUI operation, or inter-rater agreement is established by these tests.

The tests are included under `python/tests`. The synthetic test data are not
biological observations. A successful software test does not confirm a seizure.
