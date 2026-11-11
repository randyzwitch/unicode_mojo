"""Standalone API contracts; no dataframe dependency."""
from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_false,
    assert_raises,
)
from unicode_mojo import (
    UNICODE_VERSION,
    ALPHABETIC_UNICODE_VERSION,
    Normalizer,
    QuickCheck,
    normalize,
    is_normalized,
    alphabetic_ranges,
    is_alphabetic,
)


def test_forms_and_hangul() raises:
    assert_equal(UNICODE_VERSION, "17.0.0")
    assert_equal(normalize("cafe\u0301"), "café")
    assert_equal(normalize("café", "NFD"), "cafe\u0301")
    assert_equal(normalize("ＫＡＤＯＫＡＷＡ ²", "NFKC"), "KADOKAWA 2")
    assert_equal(normalize("ﬁ é", "NFKD"), "fi e\u0301")
    assert_equal(normalize("\u1100\u1161\u11A8"), "각")
    assert_equal(normalize("각", "NFD"), "\u1100\u1161\u11A8")
    assert_equal(normalize("\u212B"), "Å")
    assert_equal(normalize("a\u0315\u0300"), "à\u0315")
    assert_equal(normalize(""), "")
    assert_equal(normalize("\x00e\u0301\x00"), "\x00é\x00")


def test_form_validation() raises:
    for form in [String(""), String("nfc"), String("NFC "), String("invalid")]:
        with assert_raises(contains="NFC"):
            _ = Normalizer(form)
        with assert_raises(contains="NFC"):
            _ = normalize("", form)


def test_quick_check_distinguishes_maybe_from_no() raises:
    var nfc = Normalizer()
    assert_true(nfc.quick_check("plain ASCII text") == QuickCheck.YES)
    assert_true(nfc.quick_check("é漢字각") == QuickCheck.YES)
    assert_true(nfc.quick_check("\u0300") == QuickCheck.MAYBE)
    assert_true(nfc.is_normalized("\u0300"))
    assert_true(nfc.quick_check("a\u0300") == QuickCheck.MAYBE)
    assert_false(nfc.is_normalized("a\u0300"))
    assert_true(nfc.quick_check("x\u0315\u0300") == QuickCheck.NO)
    assert_false(nfc.is_normalized("x\u0315\u0300"))
    var nfd = Normalizer("NFD")
    assert_true(nfd.quick_check("é") == QuickCheck.NO)
    assert_true(nfd.quick_check("e\u0301") == QuickCheck.YES)
    assert_true(is_normalized("e\u0301", "NFD"))
    assert_false(is_normalized("é", "NFD"))
    var nfkc = Normalizer("NFKC")
    assert_true(nfkc.quick_check("ﬁ") == QuickCheck.NO)


def test_borrowed_spans_and_append_output() raises:
    var normalizer = Normalizer()
    var payload = String("e\u0301\x00\u1100\u1161\u11A8")
    for offset in [0, 1, 7, 16]:
        var owner = String()
        for _ in range(offset):
            owner += "x"
        owner += payload
        owner += "DO NOT CONSUME"
        var text = StringSpan(
            unsafe_from_utf8=owner.as_bytes()[
                offset : offset + payload.byte_length()
            ]
        )
        var out = List[UInt8]()
        out.extend(StringSpan("prefix:").as_bytes())
        normalizer.normalize_into(text, out)
        assert_equal(String(unsafe_from_utf8=out), "prefix:é\x00각")
    # The prefix is an independent value, not a streaming normalization state.
    var out = List[UInt8]()
    out.extend(StringSpan("e").as_bytes())
    normalizer.normalize_into("\u0301", out)
    assert_equal(String(unsafe_from_utf8=out), "e\u0301")


def test_long_combining_runs_and_scratch_reuse() raises:
    var text = String("a")
    var expected = String("a")
    for _ in range(1000):
        text += "\u0315\u0300"
        expected += "\u0300"
    for _ in range(1000):
        expected += "\u0315"
    var normalizer = Normalizer("NFD")
    assert_equal(normalizer.normalize(text), expected)
    assert_equal(normalizer.normalize("é"), "e\u0301")
    assert_equal(normalizer.normalize("ascii"), "ascii")
    assert_equal(normalizer.normalize(""), "")
    assert_equal(normalizer.normalize("각"), "\u1100\u1161\u11A8")
    assert_equal(normalizer.normalize(text), expected)


def test_alphabetic_preserves_unicode15() raises:
    assert_equal(ALPHABETIC_UNICODE_VERSION, "15.0.0")
    var ranges = alphabetic_ranges()
    assert_equal(len(ranges) % 2, 0)
    for i in range(len(ranges) // 2):
        assert_true(ranges[2 * i] <= ranges[2 * i + 1])
        assert_true(is_alphabetic(ranges, ranges[2 * i]))
        assert_true(is_alphabetic(ranges, ranges[2 * i + 1]))
        if i > 0:
            assert_true(ranges[2 * i] > ranges[2 * i - 1])
    for cp in [0x41, 0x7A, 0x00DF, 0x0345, 0x2160, 0x4E00, 0x11F02]:
        assert_true(is_alphabetic(ranges, UInt32(cp)))
    for cp in [0, 0x30, 0x5F, 0x0300, 0xD800, 0x1F600, 0x1C89, 0x110000]:
        assert_false(is_alphabetic(ranges, UInt32(cp)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
