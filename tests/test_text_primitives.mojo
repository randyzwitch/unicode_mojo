"""UTF-8 primitives against independent standard-library code-point iteration."""
from std.testing import TestSuite, assert_equal
from unicode_mojo import (
    count_codepoints,
    CodepointTrimSet,
    codepoint_slice_bounds,
    slice_codepoints,
    reverse_codepoints,
    reverse_codepoints_into,
)
from unicode_mojo.utf8 import (
    unsafe_next_codepoint_boundary,
    unsafe_previous_codepoint_boundary,
    unsafe_advance_codepoints,
)


def _parts(text: StringSpan) -> List[String]:
    var result = List[String]()
    for cp in text.codepoints():
        result.append(String(cp))
    return result^


def _join(parts: List[String], first: Int, last: Int) -> String:
    var result = String()
    for i in range(first, last):
        result += parts[i]
    return result^


def test_counts_across_vector_boundaries_and_borrowed_offsets() raises:
    var tokens: List[String] = ["a", "é", "中", "😀", "\x00", "\u0301"]
    var payload = String()
    for count in range(100):
        if count:
            payload += tokens[(count - 1) % len(tokens)]
        for offset in [0, 1, 7, 15, 31]:
            var owner = String("x") * offset + payload + "IGNORED😀"
            var text = StringSpan(
                unsafe_from_utf8=owner.as_bytes()[
                    offset : offset + payload.byte_length()
                ]
            )
            assert_equal(count_codepoints(text), count)
            assert_equal(count_codepoints(text), len(_parts(text)))
    for size in range(97):
        assert_equal(count_codepoints(String("a") * size + "é😀"), size + 2)
    assert_equal(count_codepoints(String("😀") * 64), 64)


def test_boundaries_and_clipped_advancement() raises:
    var owner = String("prefix:aé中😀\x00\u0301:excluded")
    var text = StringSpan(unsafe_from_utf8=owner.as_bytes()[7:20])
    var boundaries: List[Int] = [0, 1, 3, 6, 10, 11, 13]
    for i in range(len(boundaries) - 1):
        assert_equal(
            unsafe_next_codepoint_boundary(text, boundaries[i]),
            boundaries[i + 1],
        )
        assert_equal(
            unsafe_previous_codepoint_boundary(text, boundaries[i + 1]),
            boundaries[i],
        )
    for i in range(len(boundaries)):
        for count in range(-1, 10):
            var expected = boundaries[
                min(i + max(count, 0), len(boundaries) - 1)
            ]
            assert_equal(
                unsafe_advance_codepoints(text, boundaries[i], count), expected
            )
        assert_equal(
            unsafe_advance_codepoints(text, boundaries[i], Int.MAX), 13
        )
    assert_equal(unsafe_advance_codepoints("", 0, 100), 0)


def test_slice_bounds_and_values_match_codepoint_reference() raises:
    var inputs: List[String] = [
        "",
        "ASCII",
        "é中😀\x00a\u0301",
        "🇺🇸👩\u200D💻",
        String("xé😀") * 30,
    ]
    for input in inputs:
        var parts = _parts(input)
        for offset in range(-len(parts) - 3, len(parts) + 4):
            var first = min(offset, len(parts)) if offset >= 0 else max(
                len(parts) + offset, 0
            )
            for length in [
                -4,
                -1,
                0,
                1,
                2,
                len(parts),
                len(parts) + 2,
                Int.MAX,
            ]:
                var last = len(parts) if length < 0 else first + min(
                    length, len(parts) - first
                )
                var expected = _join(parts, first, last)
                var before = _join(parts, 0, first)
                var bounds = codepoint_slice_bounds(input, offset, length)
                assert_equal(bounds[0], before.byte_length())
                assert_equal(
                    bounds[1], before.byte_length() + expected.byte_length()
                )
                assert_equal(slice_codepoints(input, offset, length), expected)
    assert_equal(slice_codepoints("é中😀", Int.MIN, Int.MAX), "é中😀")
    assert_equal(slice_codepoints("é中😀", Int.MAX, Int.MAX), "")


def test_slices_and_reversal_respect_borrowed_window_and_prefix() raises:
    var payload = String("a\u0301😀\x00é")
    for offset in [0, 1, 7, 31]:
        var owner = String("x") * offset + payload + "EXCLUDED"
        var text = StringSpan(
            unsafe_from_utf8=owner.as_bytes()[
                offset : offset + payload.byte_length()
            ]
        )
        assert_equal(slice_codepoints(text, 1, 3), "\u0301😀\x00")
        assert_equal(slice_codepoints(text, -2), "\x00é")
        assert_equal(reverse_codepoints(text), "é\x00😀\u0301a")
        var output: List[UInt8] = [0xFF, 0, 0xFE]
        reverse_codepoints_into(text, output)
        reverse_codepoints_into("", output)
        assert_equal(output[0], UInt8(0xFF))
        assert_equal(output[1], UInt8(0))
        assert_equal(output[2], UInt8(0xFE))
        assert_equal(
            String(StringSpan(unsafe_from_utf8=Span(output)[3:])),
            "é\x00😀\u0301a",
        )
    assert_equal(reverse_codepoints(""), "")
    assert_equal(reverse_codepoints("a\u0301"), "\u0301a")


def test_reversal_matches_codepoint_reference() raises:
    for input in [
        String(""),
        String("ASCII"),
        String("😀中é\x00a\u0301"),
        String("🇺🇸👩\u200D💻"),
        String("xé😀") * 40,
    ]:
        var parts = _parts(input)
        var expected = String()
        for i in range(len(parts)):
            expected += parts[len(parts) - 1 - i]
        assert_equal(reverse_codepoints(input), expected)
        assert_equal(reverse_codepoints(reverse_codepoints(input)), input)


def test_trim_sets_are_explicit_owned_and_reusable() raises:
    var none = CodepointTrimSet("")
    assert_equal(none.trim(" \té\n "), " \té\n ")
    var whitespace = CodepointTrimSet(" \t\n\r\v\f")
    assert_equal(whitespace.trim(" \té\n "), "é")
    assert_equal(whitespace.trim(" \u00A0é\u2003 "), "\u00A0é\u2003")
    var characters = String("x😀\x00\u0301x😀")
    var trim = CodepointTrimSet(characters)
    characters = "replaced"
    assert_equal(characters, "replaced")
    assert_equal(trim.trim("x😀\x00é\u0301x"), "é")
    assert_equal(trim.trim("x😀\x00é\u0301x", trailing=False), "é\u0301x")
    assert_equal(trim.trim("x😀\x00é\u0301x", leading=False), "x😀\x00é")
    assert_equal(
        trim.trim("x😀\x00é\u0301x", leading=False, trailing=False),
        "x😀\x00é\u0301x",
    )
    assert_equal(trim.trim("x😀\x00\u0301"), "")
    assert_equal(trim.trim(""), "")
    assert_equal(trim.trim("unaffected"), "unaffected")


def _in_set(value: String, characters: List[String]) -> Bool:
    for character in characters:
        if value == character:
            return True
    return False


def test_trim_bounds_match_codepoint_reference_on_borrowed_windows() raises:
    for characters in [
        String(""),
        String("x"),
        String("x😀\u0301"),
        String("\x00é"),
        String("中 "),
    ]:
        var trim = CodepointTrimSet(characters)
        var removals = _parts(characters)
        for input in [
            String(""),
            String("x😀\u0301中é\x00x"),
            String("xx"),
            String("😀😀"),
            String(" a中 "),
        ]:
            var owner = String("prefix") + input + "suffix"
            var text = StringSpan(
                unsafe_from_utf8=owner.as_bytes()[6 : 6 + input.byte_length()]
            )
            var parts = _parts(text)
            for leading in [False, True]:
                for trailing in [False, True]:
                    var first = 0
                    var last = len(parts)
                    if leading:
                        while first < last and _in_set(parts[first], removals):
                            first += 1
                    if trailing:
                        while last > first and _in_set(
                            parts[last - 1], removals
                        ):
                            last -= 1
                    var expected = _join(parts, first, last)
                    var prefix = _join(parts, 0, first)
                    var bounds = trim.bounds(text, leading, trailing)
                    assert_equal(bounds[0], prefix.byte_length())
                    assert_equal(
                        bounds[1], prefix.byte_length() + expected.byte_length()
                    )
                    assert_equal(trim.trim(text, leading, trailing), expected)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
