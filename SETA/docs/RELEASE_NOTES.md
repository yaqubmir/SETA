# SETA 1.0.0

Prepared for author review on 14 October 2026; not yet published.

## MATLAB edition

The seven-file dependency closure from the supplied annotator is included.
The main class is renamed from NEDNetAnnotatorApp to SETAAnnotatorApp; Runme
launches the renamed class. Branding and GPL notices were added. The original
detection and annotation logic is retained, with original and packaged hashes
in matlab/SOURCE_MANIFEST.json.

## Python edition

The Python desktop implementation includes EDF/DAT input, candidate detection,
manual interval labels, raw and filtered trace views, annotation persistence and
CSV interchange. It uses NumPy, SciPy and Tk. Its loader and save behavior are
deliberately documented separately; it is not a claim of exact MATLAB parity.

## Validation limits

Eleven Python automated tests pass on Windows/Python 3.12. MATLAB runtime testing
is pending because its licensing service did not initialize. Synthetic tests
verify software behavior, not seizure-detection accuracy. There is no included
trained model, video classifier or numerical MATLAB/Python equivalence result.

Research annotations and confirmed-event media are private and are excluded
from the public software release.
