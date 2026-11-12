# Third-party notices

## Unicode data

`unicode_mojo/_normalization_tables.mojo` and
`tests/fixtures/normalization-17.0.0.txt` derive from Unicode 17.0.0 data at
<https://www.unicode.org/Public/17.0.0/ucd/>. Their original source checksums are
recorded in the generated files and enforced by `scripts/normalization_tables.py`.
Copyright 1991–2026 Unicode, Inc. The Unicode License v3 is included at
`scripts/vendor/unicode-LICENSE`.

`unicode_mojo/alphabetic.mojo` preserves the original Unicode 15.0 Alphabetic
ranges, originally generated through Perl's Unicode property support. The
ranges are unchanged in this extraction. They are kept at that version to
preserve existing title-casing behavior; updating them is a separate semantic
change. Their original generator and upstream file checksum were not retained
in dataframe, so this package does not claim reproducible regeneration of
that table yet.

## Rust regex property tables

`unicode_mojo/_property_tables.mojo` derives from the Unicode 16.0 property
and alias tables in Rust `regex-syntax` 1.12.2:
<https://github.com/rust-lang/regex/tree/1.12.2/regex-syntax/src/unicode_tables>.
The source is available under MIT or Apache-2.0. Both original license texts
are retained in `scripts/vendor/regex-LICENSE-MIT` and
`scripts/vendor/regex-LICENSE-APACHE`, and in the packaged `LICENSES` file.
The package uses the MIT option for this data. The generator is
`scripts/regex_property_tables.py`.

## Frozen regex character classes and simple folding

`unicode_mojo/_regex_tables.mojo` and the `unicode_perl_ranges.tsv` and
`unicode_folding.tsv` fixtures preserve dataframe's Polars 1.44.2 observations
of Rust regex behavior. Every inclusive endpoint and all 2,884 folding pairs
are unchanged. `scripts/regex_unicode_tables.py --from-fixtures --check`
reproduces the generated constructors from that snapshot without Polars.
Recomputing the snapshot requires exactly Polars 1.44.2 and also uses Python's
case maps to find folding candidates; the original Python Unicode version
was not recorded, so a fresh oracle run is not claimed to be reproducible
across Python versions.

## Title casing

The extracted title-casing algorithm preserves dataframe's Alphabetic-word
policy and immediate-neighbor final-sigma handling. Alphabetic uses the
Unicode 15.0 table above; full lower/upper mappings come from the pinned
Mojo standard library. It does not claim UAX #29 word-boundary semantics.
