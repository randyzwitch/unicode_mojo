# unicode_mojo

Unicode normalization, properties, case folding, and text primitives in pure Mojo, extracted from
`dataframe_mojo`. Runtime code depends only on the Mojo standard library.

- NFC, NFD, NFKC and NFKD use Unicode **17.0.0**.
- The `Alphabetic` property uses Unicode **15.0.0**, preserving the existing
  dataframe title-casing contract. It is not a general-category or ASCII-only
  letter test.
- General property lookup uses Unicode **16.0.0**; regex-style word/digit/space
  classes and simple folding preserve the frozen **Polars 1.44.2** snapshot.
- Static normalization tables require no initialization or parsing at runtime.
- A reusable normalizer accepts borrowed UTF-8, retains decomposition scratch,
  and can append directly to a caller's output buffer.
- Canonical ordering uses bounded insertion for short combining runs and stable
  counting sort for long runs.

This is version 0.1.0. The public API may change.
Regex matching, parser/NFA/DFA machinery, and dataframe storage/column behavior
remain in `dataframe_mojo`; the reusable Unicode data and algorithms live here.

## Use

```mojo
from unicode_mojo import Normalizer, QuickCheck, normalize


def main() raises:
    print(normalize("cafe\u0301"))  # café; NFC is the default
    print(normalize("ＫＡＤＯＫＡＷＡ ²", "NFKC"))  # KADOKAWA 2

    var normalizer = Normalizer("NFC")
    var output = List[UInt8]()
    normalizer.normalize_into("e\u0301", output)
    print(String(unsafe_from_utf8=output))
    print(normalizer.quick_check("plain ASCII") == QuickCheck.YES)
```

Forms are validated once when constructing `Normalizer`. The free functions
`normalize(text, form="NFC")` and `is_normalized(text, form="NFC")` are convenient
for single strings; reuse a normalizer for many rows. `quick_check()` returns
`QuickCheck.YES`, `NO` or `MAYBE`. `MAYBE` requires the full check and does not
mean the text is unnormalized. `Normalizer.is_normalized()` resolves it exactly.

`StringSpan` input is borrowed validated UTF-8. `normalize_into()` appends a
complete normalized value without clearing the output. Input must not alias
output. The existing output prefix is not part of normalization: concatenating
normalized fragments may require normalizing their boundary again. Use one
normalizer per worker; its scratch is mutable.

For alphabetic checks, construct the range table once and reuse it:

```mojo
from unicode_mojo import alphabetic_ranges, is_alphabetic


def main():
    var ranges = alphabetic_ranges()
    print(is_alphabetic(ranges, UInt32(0x0345)))  # True: Alphabetic combining mark
```

## Properties, ranges, and simple folding

```mojo
from unicode_mojo import property_ranges, CaseFolds
from unicode_mojo.ranges import contains


def main() raises:
    var greek = property_ranges("Script=Greek")
    print(contains(greek, UInt32(0x03B1)))
    var folds = CaseFolds()
    var caseless = folds.fold([UInt32(0x6B), UInt32(0x6B)])
    print(contains(caseless, UInt32(0x212A)))  # Kelvin sign
```

`property_ranges(name)` accepts binary properties, general categories, scripts,
script extensions, age, and grapheme/word/sentence break properties. Names use
loose ASCII matching and aliases; unknown names raise `Error`. Every call
returns an independent list of inclusive endpoint pairs. The `word_ranges()`,
`digit_ranges()` and `space_ranges()` constructors preserve regex-style sets.
`CaseFolds.fold(ranges)` closes a set under simple case folding; it does not
perform full string folding or expand sharp S into two characters.

The `ranges` module owns canonicalization, union, intersection, difference,
symmetric difference, complement, cardinality, and bounded membership.
Inputs must contain endpoint pairs in `0..0x10FFFF`; all operations except
`canonical()` require sorted, disjoint, nonadjacent pairs. Complement uses the
whole code-point domain, including surrogate code points. Property lookup
itself excludes surrogates and returns scalar-value sets.

## Title casing and UTF-8

`alphabetic_titlecase(text)` and the reusable `AlphabeticTitleCaser` preserve
dataframe's existing policy: lowercase, then uppercase characters at the start
or after non-Alphabetic characters. Full mappings come from the pinned Mojo
standard library; word decisions use Unicode 15 Alphabetic. Capital sigma
uses immediate Alphabetic neighbors, without skipping case-ignorable marks.
For example `ΣΑΣ. ǅ` becomes `Σας. Ǆ` and `ßa a_b` becomes `SSa A_B`.
This is not UAX #29 word-boundary title casing.

`AlphabeticTitleCaser.titlecase_into(text, output)` appends to a byte buffer,
independently of its prefix. Input is borrowed validated UTF-8 and must not
alias output. `titlecase(text)` returns an owned string.

The `utf8` module exposes `unsafe_append_codepoint(output, cp)` and
`unsafe_codepoint_width(lead)`. Callers must provide a valid Unicode scalar
(excluding surrogates) or a leading byte from validated UTF-8 respectively.
These primitives do not validate arbitrary bytes or code-point integers.

## Pixi dependency

Use Pixi **0.84.2**. In a consumer workspace, add:

```toml
[dependencies]
unicode_mojo = { git = "https://github.com/randyzwitch/unicode_mojo.git" }
mojo = "==1.3.0.dev2026111005"
```

Consumers using Pixi source builds also need `preview = ["pixi-build"]` and the
`https://prefix.dev/pixi-build-backends` channel. Compiled libraries must use
the exact compiler that built them. This package's build and runtime compiler
pins match the workspace. Add the dependency to a consuming package's host and
runtime dependencies as well as its development environment.

For reproducible builds, add `rev = "<full-commit-sha>"` to the Git dependency
and commit the consumer's `pixi.lock`. The repository is published at
<https://github.com/randyzwitch/unicode_mojo>.

For local development with a sibling checkout, replace the Git dependency with
`unicode_mojo = { path = "../unicode_mojo" }` in each dependency section.

## Development

```sh
pixi install --locked
pixi run check
pixi build
```

The standalone suite verifies all **20,034** official Unicode 17 normalization
vectors across all 20 form/input combinations (400,680 normalization checks),
plus exact normalizedness and quick-check guarantees. API tests cover bounded
borrowed spans, prefix preservation, invalid forms, embedded NULs, scratch
reuse, long combining sequences and the Alphabetic version boundary. Additional
suites cover all frozen regex endpoints and folding orbits, property aliases,
range algebra, title casing, and UTF-8 scalar boundaries.

Dataframe's integration tests separately cover nulls, Arrow layouts, chunking,
eager/lazy execution and unchanged-buffer reuse.

To regenerate or check normalization data, download `UnicodeData.txt`,
`DerivedNormalizationProps.txt` and `NormalizationTest.txt` from
<https://www.unicode.org/Public/17.0.0/ucd/> into a directory, then run:

```sh
pixi run python3 scripts/normalization_tables.py --ucd DIRECTORY --check
```

Omit `--check` to write the generated tables and fixture. The generator verifies
all three pinned SHA-256 hashes before accepting input. Tests and runtime use
the committed data and need no Unicode downloads or Python runtime interop.

The regex range/folding constructors can be checked offline from the frozen
fixtures with `pixi run tables-check`. Property tables can be regenerated or
checked from the pinned Rust regex 1.12.2 sources:

```sh
pixi run python3 scripts/regex_property_tables.py --check
```

Use `--source-dir DIRECTORY` with a local cache of its `unicode_tables/*.rs`
files to avoid downloads. Optional `--check-oracle` compares generated sets
with Polars and requires that external development dependency. The original
Polars observation generator is also retained; it requires exactly 1.44.2.
See the notices for the original snapshot's Python-version limitation.

## License and provenance

Source code is MIT licensed; see [LICENSE](LICENSE). Unicode-derived data uses
[Unicode License v3](scripts/vendor/unicode-LICENSE). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for provenance.

Rust regex property data is used under its MIT option; both upstream MIT and
Apache-2.0 license texts are preserved in `scripts/vendor/` and `LICENSES`.
