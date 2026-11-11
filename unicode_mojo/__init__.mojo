"""Unicode normalization and alphabetic properties in pure Mojo.

Normalization uses Unicode 17.0.0; Alphabetic preserves Unicode 15.0.0.
Property lookup uses Unicode 16.0.0; regex classes/folds preserve Polars 1.44.2.
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
from unicode_mojo.properties import (
    PROPERTY_UNICODE_VERSION,
    REGEX_CLASS_SOURCE,
    property_ranges,
    word_ranges,
    digit_ranges,
    space_ranges,
)
from unicode_mojo.casefold import CASE_FOLD_SOURCE, CaseFolds
from unicode_mojo.casing import AlphabeticTitleCaser, alphabetic_titlecase
