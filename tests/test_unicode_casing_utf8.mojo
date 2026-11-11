"""Standalone title-casing and UTF-8 append contracts."""
from std.testing import TestSuite, assert_equal
from unicode_mojo import AlphabeticTitleCaser, alphabetic_titlecase
from unicode_mojo.utf8 import unsafe_append_codepoint, unsafe_codepoint_width


def test_alphabetic_titlecase_preserves_existing_policy() raises:
    var values: List[String] = [
        "ΣΑΣ. ǅ",
        "中a 1st",
        "x\u0301yz",
        "ﬁx",
        "ΑΣ",
        "Σ",
        "ÉCOLE d'ÉTÉ",
        "ßa a_b",
        "a\x00b",
        "",
        "FOO\tBAR",
        "AΣ\u0301B",
        "AΣB",
    ]
    var expected: List[String] = [
        "Σας. Ǆ",
        "中a 1St",
        "X\u0301Yz",
        "FIx",
        "Ας",
        "Σ",
        "École D'Été",
        "SSa A_B",
        "A\x00B",
        "",
        "Foo\tBar",
        "Aς\u0301B",
        "Aσb",
    ]
    var caser = AlphabeticTitleCaser()
    for i in range(len(values)):
        assert_equal(caser.titlecase(values[i]), expected[i])
        assert_equal(alphabetic_titlecase(values[i]), expected[i])


def test_titlecase_borrowed_spans_and_independent_prefix() raises:
    var caser = AlphabeticTitleCaser()
    var payload = String("ßa AΣ\u0301B 𐐀ABC")
    for offset in [0, 1, 7, 16]:
        var owner = String("x") * offset + payload + "IGNORED"
        var text = StringSpan(
            unsafe_from_utf8=owner.as_bytes()[
                offset : offset + payload.byte_length()
            ]
        )
        var output = List[UInt8]()
        output.extend(StringSpan("prefix").as_bytes())
        caser.titlecase_into(text, output)
        assert_equal(
            String(unsafe_from_utf8=output), "prefixSSa Aς\u0301B 𐐀abc"
        )
        caser.titlecase_into("", output)
        caser.titlecase_into("x", output)
        assert_equal(
            String(unsafe_from_utf8=output), "prefixSSa Aς\u0301B 𐐀abcX"
        )


def test_utf8_scalar_boundaries_append_without_overwriting() raises:
    var points: List[Int] = [
        0,
        0x7F,
        0x80,
        0x7FF,
        0x800,
        0xD7FF,
        0xE000,
        0xFFFF,
        0x10000,
        0x10FFFF,
    ]
    var expected: List[UInt8] = [
        0xAA,
        0,
        0x7F,
        0xC2,
        0x80,
        0xDF,
        0xBF,
        0xE0,
        0xA0,
        0x80,
        0xED,
        0x9F,
        0xBF,
        0xEE,
        0x80,
        0x80,
        0xEF,
        0xBF,
        0xBF,
        0xF0,
        0x90,
        0x80,
        0x80,
        0xF4,
        0x8F,
        0xBF,
        0xBF,
    ]
    var output: List[UInt8] = [0xAA]
    for cp in points:
        var start = len(output)
        unsafe_append_codepoint(output, cp)
        assert_equal(unsafe_codepoint_width(output[start]), len(output) - start)
    assert_equal(output, expected)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
