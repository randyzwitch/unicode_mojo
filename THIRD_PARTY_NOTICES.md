# Third-party notices

The implementation was extracted from Randy Zwitch's MIT-licensed
`dataframe_mojo` project. Its copyright notice is preserved in `LICENSE`.

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
