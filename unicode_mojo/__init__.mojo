"""Unicode normalization and alphabetic properties in pure Mojo.

Normalization uses Unicode 17.0.0; Alphabetic preserves Unicode 15.0.0.
"""
from unicode_mojo.normalization import (
    UNICODE_VERSION,
    Normalizer,
    QuickCheck,
    normalize,
    is_normalized,
)
from unicode_mojo.alphabetic import (
    ALPHABETIC_UNICODE_VERSION,
    alphabetic_ranges,
    is_alphabetic,
)
