# unicode_mojo

Unicode normalization and alphabetic properties in pure Mojo, extracted from
`dataframe_mojo`. Runtime code depends only on the Mojo standard library.

- NFC, NFD, NFKC and NFKD use Unicode **17.0.0**.
- The `Alphabetic` property uses Unicode **15.0.0**, preserving the existing
  dataframe title-casing contract. It is not a general-category or ASCII-only
  letter test.
- Static normalization tables require no initialization or parsing at runtime.
- A reusable normalizer accepts borrowed UTF-8, retains decomposition scratch,
  and can append directly to a caller's output buffer.
- Canonical ordering uses bounded insertion for short combining runs and stable
  counting sort for long runs.

This is version 0.1.0. The public API may change.
Regex tables and dataframe storage/column behavior remain in `dataframe_mojo`.

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
reuse, long combining sequences and the Alphabetic version boundary.

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

## License and provenance

Source code is MIT licensed; see [LICENSE](LICENSE). Unicode-derived data uses
[Unicode License v3](scripts/vendor/unicode-LICENSE). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for provenance.
